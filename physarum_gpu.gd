extends Node

signal step_count_updated(step_count)
signal process_time_updated(process_time)
signal texture_time_updated(texture_time)
signal buffer_update_time_updated(buffer_time)
signal motor_sensory_time_updated(motor_sensory_time)
signal diffusion_decay_time_updated(diffusion_decay_time)
signal buffer_read_time_updated(buffer_read_time)

# Environment parameters
var step_counter : int = 0
var process_time_elapsed : float = 0
var viewport : Viewport
var viewport_width : int
var viewport_height : int
var image_size : Vector2i = Vector2i(512, 512)
var n_pixels : int = image_size.x * image_size.y
var population_percent : float = 150
var population_initial_spread : float = 1.0
var diffusion_kernel_size : int = 3
var decay_factor : float = 0.8
var max_occupancy : int = 3

# Agent parameters
var sensor_distance : float = 5
#var sensor_width : int = 1 # sensor width in pixels
var sensor_angle : float = PI/4.0
var rotation_angle : float = PI/4.0
var step_size : float = 1
var deposit_size : float = 5.0
#var prob_change_dir : float = 0 # probability of a random change in direction
var n_agents : int

# Data structures
var agents_x : Array
var agents_y : Array
var agents_rot : Array
var agent_image : Image
var agent_texture : ImageTexture
@export var agent_sprite : TextureRect

var trail_image : Image
var trail_texture : ImageTexture
@export var trail_sprite : TextureRect

# Compute shader variables
var rd : RenderingDevice
var shader : RID
var work_group_size : int = 64
enum stage {MOTOR_SENSORY = 0, DIFFUSION_DECAY = 1}

var agents_x_buffer : RID
var agents_y_buffer : RID
var agents_rot_buffer : RID
var agent_map_buffer : RID
var agent_map_out_buffer : RID
var trail_map_buffer : RID
var trail_map_out_buffer : RID

var uniform_set : RID
var pipeline : RID
var bindings : Array = []

var dispatch_size_motor_sensory : int
var dispatch_size_diffusion_decay : int


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	n_agents = int(population_percent * image_size.x * image_size.y / 100.0)
	dispatch_size_motor_sensory = ceili(float(n_agents) / float(work_group_size))
	dispatch_size_diffusion_decay = ceili((float(n_pixels))/ float(work_group_size))
	
	agent_sprite.material.set_shader_parameter('max_value', population_percent / 1)
	trail_sprite.material.set_shader_parameter('max_value', population_percent / 18)
	
	
	print('Dispatch size motor sensory: ', dispatch_size_motor_sensory)
	print('Dispatch size diffusion decay: ', dispatch_size_diffusion_decay)
	
	_initialize_images()
	_initialize_agents()
	_update_textures()
	_setup_compute_shader()
	
	step_counter += 1
	emit_signal('step_count_updated', step_counter)
	get_tree().paused = true


func _print_maps() -> void:
	print('Agent map:')
	print(agent_image.get_data().to_float32_array())
	print('')
	print('Trail map:')
	print(trail_image.get_data().to_float32_array())
	print('')

func _process(delta):
	RenderingServer.global_shader_parameter_set('process_time', process_time_elapsed)
	var start_time = Time.get_ticks_usec()

	_process_compute_shader(stage.MOTOR_SENSORY)
	_read_image_buffers(stage.MOTOR_SENSORY)
	_update_compute_shader_buffers(stage.DIFFUSION_DECAY)

	_process_compute_shader(stage.DIFFUSION_DECAY)
	_read_image_buffers(stage.DIFFUSION_DECAY)
	_update_compute_shader_buffers(stage.MOTOR_SENSORY)

	_update_textures()
	
	step_counter += 1
	process_time_elapsed += delta
	emit_signal('step_count_updated', step_counter)
	emit_signal('process_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)


func _initialize_images() -> void:
	agent_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RF)
	agent_texture = ImageTexture.create_from_image(agent_image)
	agent_sprite.texture = agent_texture
	
	trail_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RF)
	trail_texture = ImageTexture.create_from_image(trail_image)
	trail_sprite.texture = trail_texture


func _update_textures() -> void:
	var start_time = Time.get_ticks_usec()
	agent_texture.update(agent_image)
	trail_texture.update(trail_image)
	emit_signal('texture_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)


func _initialize_agents() -> void:
	var x : float
	var y : float
	var agent_image_v : float
	for i in range(n_agents):
		x = fposmod(randfn(image_size.x / 2.0, image_size.x / (randf_range(16.0, 24.0) / population_initial_spread)), float(image_size.x))
		y = fposmod(randfn(image_size.y / 2.0, image_size.y / (randf_range(16.0, 24.0) / population_initial_spread)), float(image_size.y))
		agent_image_v = agent_image.get_pixel(int(x), int(y)).r
		agent_image.set_pixel(int(x), int(y), Color(agent_image_v + 1.0, 0, 0, 0))
		agents_x.append(x)
		agents_y.append(y)
		agents_rot.append(randf_range(0, 2*PI))


func _setup_compute_shader() -> void:
	# Create a local rendering device.
	rd = RenderingServer.create_local_rendering_device()
	
	# Load GLSL shader
	var shader_file := load("res://physarum_compute_shader.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	# Particle position and rotation buffers
	var agents_x_buffer_bytes := PackedFloat32Array(agents_x).to_byte_array()
	var agents_y_buffer_bytes := PackedFloat32Array(agents_y).to_byte_array()
	var agents_rot_buffer_bytes := PackedFloat32Array(agents_rot).to_byte_array()
	agents_x_buffer = rd.storage_buffer_create(agents_x_buffer_bytes.size(), agents_x_buffer_bytes)
	agents_y_buffer = rd.storage_buffer_create(agents_y_buffer_bytes.size(), agents_y_buffer_bytes)
	agents_rot_buffer = rd.storage_buffer_create(agents_rot_buffer_bytes.size(), agents_rot_buffer_bytes)
	
	var agents_x_uniform := RDUniform.new()
	var agents_y_uniform := RDUniform.new()
	var agents_rot_uniform := RDUniform.new()
	
	agents_x_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	agents_x_uniform.binding = 0
	agents_x_uniform.add_id(agents_x_buffer)
	
	agents_y_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	agents_y_uniform.binding = 1
	agents_y_uniform.add_id(agents_y_buffer)
	
	agents_rot_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	agents_rot_uniform.binding = 2
	agents_rot_uniform.add_id(agents_rot_buffer)
	
	# Parameter buffer
	var params : PackedByteArray = PackedFloat32Array(
		[stage.MOTOR_SENSORY, image_size.x, image_size.y, n_agents, sensor_distance, sensor_angle, rotation_angle, step_size, deposit_size, decay_factor, diffusion_kernel_size]
	).to_byte_array()
	var params_buffer = rd.storage_buffer_create(params.size(), params)
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 3
	params_uniform.add_id(params_buffer)
	
	# Agent map buffer
	var fmt := RDTextureFormat.new()
	fmt.width = image_size.x
	fmt.height = image_size.y
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var view := RDTextureView.new()
	agent_map_buffer = rd.texture_create(fmt, view, [agent_image.get_data()])
	var agent_map_uniform := RDUniform.new()
	agent_map_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	agent_map_uniform.binding = 4
	agent_map_uniform.add_id(agent_map_buffer)
	
	# Agent map output buffer
	agent_map_out_buffer = rd.texture_create(fmt, view, [agent_image.get_data()])
	var agent_map_out_uniform := RDUniform.new()
	agent_map_out_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	agent_map_out_uniform.binding = 5
	agent_map_out_uniform.add_id(agent_map_out_buffer)
	
	# Trail map buffer
	trail_map_buffer = rd.texture_create(fmt, view, [trail_image.get_data()])
	var trail_map_uniform := RDUniform.new()
	trail_map_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	trail_map_uniform.binding = 6
	trail_map_uniform.add_id(trail_map_buffer)
	
	# Trail map output buffer
	trail_map_out_buffer = rd.texture_create(fmt, view, [trail_image.get_data()])
	var trail_map_out_uniform := RDUniform.new()
	trail_map_out_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	trail_map_out_uniform.binding = 7
	trail_map_out_uniform.add_id(trail_map_out_buffer)
	
	bindings = [agents_x_uniform, agents_y_uniform, agents_rot_uniform, params_uniform, agent_map_uniform, agent_map_out_uniform, trail_map_uniform, trail_map_out_uniform]
	uniform_set = rd.uniform_set_create(bindings, shader, 0)


func _update_compute_shader_buffers(compute_stage: int) -> void:
	var start_time = Time.get_ticks_usec()
	# Parameter buffer
	var params : PackedByteArray = PackedFloat32Array(
		[float(compute_stage), float(image_size.x), float(image_size.y), float(n_agents), sensor_distance, sensor_angle, rotation_angle, step_size, deposit_size, decay_factor, float(diffusion_kernel_size)]
	).to_byte_array()
	var params_buffer = rd.storage_buffer_create(params.size(), params)
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 3
	params_uniform.add_id(params_buffer)
	
	# Update agent map buffer with zero values
	var fmt := RDTextureFormat.new()
	fmt.width = image_size.x
	fmt.height = image_size.y
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var view := RDTextureView.new()
	
	agent_map_buffer = rd.texture_create(fmt, view, [agent_image.get_data()])
	var agent_map_uniform := RDUniform.new()
	agent_map_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	agent_map_uniform.binding = 4
	agent_map_uniform.add_id(agent_map_buffer)
	
	var temp_image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RF)
	agent_map_out_buffer = rd.texture_create(fmt, view, [temp_image.get_data()])
	var agent_map_out_uniform := RDUniform.new()
	agent_map_out_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	agent_map_out_uniform.binding = 5
	agent_map_out_uniform.add_id(agent_map_out_buffer)
	
	# Update trail map buffer with previous output
	trail_map_buffer = rd.texture_create(fmt, view, [trail_image.get_data()])
	var trail_map_uniform := RDUniform.new()
	trail_map_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	trail_map_uniform.binding = 6
	trail_map_uniform.add_id(trail_map_buffer)
	
	bindings[3] = params_uniform
	bindings[4] = agent_map_uniform
	bindings[5] = agent_map_out_uniform
	bindings[6] = trail_map_uniform
	uniform_set = rd.uniform_set_create(bindings, shader, 0)
	emit_signal('buffer_update_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)

func _process_compute_shader(compute_stage: int) -> void:
	if compute_stage == stage.MOTOR_SENSORY:
		var start_time = Time.get_ticks_usec()
		pipeline = rd.compute_pipeline_create(shader)
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_dispatch(compute_list, dispatch_size_motor_sensory, 1, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		emit_signal('motor_sensory_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)
	elif compute_stage == stage.DIFFUSION_DECAY:
		var start_time = Time.get_ticks_usec()
		pipeline = rd.compute_pipeline_create(shader)
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_dispatch(compute_list, dispatch_size_diffusion_decay, 1, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		emit_signal('diffusion_decay_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)


func _read_image_buffers(compute_stage: int) -> void:
	var start_time = Time.get_ticks_usec()
	if (compute_stage == stage.MOTOR_SENSORY):
		var agent_image_data := rd.texture_get_data(agent_map_out_buffer, 0)
		agent_image = Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RF, agent_image_data)
	var trail_image_data := rd.texture_get_data(trail_map_out_buffer, 0)
	trail_image = Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RF, trail_image_data)
	emit_signal('buffer_read_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)

func restart_simulation() -> void:
	
	step_counter = 0
	process_time_elapsed = 0
	n_agents = int(population_percent * image_size.x * image_size.y / 100.0)
	dispatch_size_motor_sensory = ceili(float(n_agents) / float(work_group_size))
	dispatch_size_diffusion_decay = ceili((float(n_pixels))/ float(work_group_size))
	
	agent_sprite.material.set_shader_parameter('max_value', population_percent / 1)
	trail_sprite.material.set_shader_parameter('max_value', population_percent / 18)
	
	agents_x = []
	agents_y = []
	agents_rot = []
	
	_initialize_images()
	_initialize_agents()
	_update_textures()
	_setup_compute_shader()
	
	step_counter += 1
	emit_signal('step_count_updated', step_counter)
	get_tree().paused = true

