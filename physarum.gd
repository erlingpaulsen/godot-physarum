extends Node

# Environment parameters
var image_size : Vector2i = Vector2i(250, 250)
var population_percent : float = 20#randf_range(5, 40) # population as percentage of image area
var diffusion_kernel_size : int = 3
var k : int = (diffusion_kernel_size - 1) / 2
var decay_factor : float = 0.97#randf_range(0.9, 0.999) # Trail map diffusion decay factor
var max_occupancy : int = 3#randi_range(3, 10) # Maximum number of agents that can inhabit the same cell

# Agent parameters
var sensor_distance : float = 6#randf_range(3, 27) # sensor offset distance in pixels
#var sensor_width : int = 1 # sensor width in pixels
var sensor_angle : float = PI/4.0#randf_range(PI / 16.0, 15.0 * PI / 16.0) # sensor angle in degrees from forward position
var rotation_angle : float = PI/4.0#randf_range(PI / 16.0, 15.0 * PI / 16.0) # agent rotiation angle in degrees
var step_size : float = 1#randf_range(1, 3) # how far agent moves per step
var deposit_size : float = 5.0#randf_range(3, 15)
#var prob_change_dir : float = 0 # probability of a random change in direction
var n_agents : int

# Data structures
var agents : Array
var agent_map : Array
var agent_image : Image
var agent_texture : ImageTexture
@export var agent_sprite : TextureRect

var trail_map : Array
var trail_map_summed_area : Array
var trail_map_max : float
var trail_map_min : float
var trail_map_max_array : Array
var trail_map_min_array : Array
var trail_image : Image
var trail_texture : ImageTexture
@export var trail_sprite : TextureRect

# Control
var frame_time : float = 0.1
var frame_time_counter : float = 0.0
var step_counter : int = 0
var motor_thread : Thread
var motor_thread_2 : Thread
var motor_thread_3 : Thread
var sensory_thread : Thread
var sensory_thread_2 : Thread
var sensory_thread_3 : Thread
var diffusion_thread : Thread
var diffusion_thread_2 : Thread
var diffusion_thread_3 : Thread
var decay_thread : Thread
var decay_thread_2 : Thread
var decay_thread_3 : Thread
var image_thread : Thread
var image_thread_2 : Thread
var image_thread_3 : Thread

@export var agent_label : Label
@export var step_label : Label
@export var process_time_label : Label
@export var motor_time_label : Label
@export var sensor_time_label : Label
@export var diffusion_time_label : Label
@export var decay_time_label : Label
@export var image_time_label : Label

@export var population_percent_label : Label
@export var decay_factor_label : Label
@export var cell_occupancy_label : Label
@export var sensor_distance_label : Label
@export var sensor_angle_label : Label
@export var rotation_angle_label : Label
@export var step_size_label : Label
@export var deposit_size_label : Label

func _ready():
	n_agents = int(population_percent * image_size.x * image_size.y / 100.0)
	agent_label.text = str(n_agents)
	population_percent_label.text = String.num(population_percent, 1) + ' %'
	decay_factor_label.text = String.num(decay_factor, 3)
	cell_occupancy_label.text = str(max_occupancy)
	sensor_distance_label.text = String.num(sensor_distance, 2)
	sensor_angle_label.text = String.num(rad_to_deg(sensor_angle), 1) + ' deg'
	rotation_angle_label.text = String.num(rad_to_deg(rotation_angle), 1) + ' deg'
	step_size_label.text = String.num(step_size, 2)
	deposit_size_label.text = String.num(deposit_size, 2)
	
	_initialize_maps()
	_initialize_agents()
	_initialize_images()
	_update_image_data()
	step_counter += 1


func _process(_delta):
	var start_time = Time.get_ticks_usec()
	_process_motor_stage()
	_process_sensory_stage()
	_process_diffusion()
	_process_decay()
	_update_image_data()
	process_time_label.text = String.num((Time.get_ticks_usec() - start_time) / 1000.0, 1) + ' ms'
	step_counter += 1
	step_label.text = str(step_counter)


func _initialize_maps() -> void:
	# Initialize two-dimensional array for agent and trail maps with zero values
	trail_map = []
	trail_map.resize(image_size.x)
	trail_map_summed_area = []
	trail_map_summed_area.resize(image_size.x)
	agent_map = []
	agent_map.resize(image_size.x)
	for i in range(image_size.x):
		trail_map[i] = []
		trail_map[i].resize(image_size.y)
		trail_map[i].fill(0)
		trail_map_summed_area[i] = []
		trail_map_summed_area[i].resize(image_size.y)
		trail_map_summed_area[i].fill(0)
		agent_map[i] = []
		agent_map[i].resize(image_size.y)
		agent_map[i].fill(0)


func _initialize_agents() -> void:
	agents = []
	agents.resize(n_agents)
	var cell_occupied = true
	var x : float
	var y : float
	var rot : float
	for i in range(n_agents):
		agents[i] = {}
		cell_occupied = true
		while cell_occupied:
			x = _bound_float(randfn(image_size.x / 2.0, image_size.x / randf_range(4.0, 6.0)))
			y = _bound_float(randfn(image_size.y / 2.0, image_size.y / randf_range(4.0, 6.0)))
			if agent_map[int(x)][int(y)] < max_occupancy:
				cell_occupied = false
				agent_map[int(x)][int(y)] += 1
		rot = randf_range(0, 2*PI)
		agents[i]['position'] = Vector2(x,y)
		agents[i]['rotation'] = rot


func _initialize_images() -> void:
	agent_image = Image.new()
	agent_image.create(image_size.x, image_size.y, false, Image.FORMAT_R8)
	agent_texture = ImageTexture.new()
	trail_image = Image.new()
	trail_image.create(image_size.x, image_size.y, false, Image.FORMAT_R8)
	trail_texture = ImageTexture.new()


func _update_image_data() -> void:
	var start_time = Time.get_ticks_usec()
	image_thread = Thread.new()
	image_thread_2 = Thread.new()
	image_thread_3 = Thread.new()
	var image_callable = Callable(self, '_update_image_data_thread')
	image_thread.start(image_callable.bind([0, image_size.x / 2, 0, image_size.y / 2]))
	image_thread_2.start(image_callable.bind([image_size.x / 2, image_size.x, 0, image_size.y / 2]))
	image_thread_3.start(image_callable.bind([0, image_size.x / 2, image_size.y / 2, image_size.y]))
	_update_image_data_thread([image_size.x / 2, image_size.x, image_size.y / 2, image_size.y])
	image_thread.wait_to_finish()
	image_thread_2.wait_to_finish()
	image_thread_3.wait_to_finish()
#	for x in range(image_size.x):
#		for y in range(image_size.y):
#			agent_image.set_pixel(x, y, float(agent_map[x][y]) * Color.RED)
#			trail_image.set_pixel(x, y, (trail_map[x][y] - trail_map_min) / (trail_map_max - trail_map_min) * Color.RED)
	agent_sprite.texture = agent_texture.create_from_image(agent_image)
	trail_sprite.texture = trail_texture.create_from_image(trail_image)
	image_time_label.text = String.num((Time.get_ticks_usec() - start_time) / 1000.0, 1) + ' ms'


func _update_image_data_thread(data) -> void:
	var v : float = 1.0 / max_occupancy
	for x in range(data[0], data[1]):
		for y in range(data[2], data[3]):
			agent_image.set_pixel(x, y, float(agent_map[x][y]) * Color(v, v, v))
			trail_image.set_pixel(x, y, (trail_map[x][y] - trail_map_min) / (trail_map_max - trail_map_min) * Color.RED)


func _process_motor_stage() -> void:
	var start_time = Time.get_ticks_usec()
	agents.shuffle()
	motor_thread = Thread.new()
	motor_thread_2 = Thread.new()
	motor_thread_3 = Thread.new()
	var motor_callable = Callable(self, '_process_motor_stage_thread')
	motor_thread.start(motor_callable.bind([0, n_agents / 4]))
	motor_thread_2.start(motor_callable.bind([n_agents / 4, n_agents / 2]))
	motor_thread_3.start(motor_callable.bind([n_agents / 2, 3 * n_agents / 4]))
	_process_motor_stage_thread([3 * n_agents / 4, n_agents])
	motor_thread.wait_to_finish()
	motor_thread_2.wait_to_finish()
	motor_thread_3.wait_to_finish()
#	var new_position : Vector2
#	var new_position_int : Vector2i
#	for i in range(n_agents):
#		new_position = _bound_vector(agents[i]['position'] + Vector2(step_size, 0).rotated(agents[i]['rotation']))
#		new_position_int = Vector2i(new_position)
#		if agent_map[new_position_int.x][new_position_int.y] < max_occupancy:
#			agent_map[int(agents[i]['position'].x)][int(agents[i]['position'].y)] -= 1
#			agent_map[new_position_int.x][new_position_int.y] += 1
#			trail_map[new_position_int.x][new_position_int.y] += deposit_size
#			agents[i]['position'] = new_position
#		else:
#			agents[i]['rotation'] = randf_range(0, 2*PI)
	motor_time_label.text = String.num((Time.get_ticks_usec() - start_time) / 1000.0, 1) + ' ms'

func _process_motor_stage_thread(data):
	var new_position : Vector2
	var new_position_int : Vector2i
	for i in range(data[0], data[1]):
		new_position = _bound_vector(agents[i]['position'] + Vector2(step_size, 0).rotated(agents[i]['rotation']))
		new_position_int = Vector2i(new_position)
		if agent_map[new_position_int.x][new_position_int.y] < max_occupancy:
			agent_map[int(agents[i]['position'].x)][int(agents[i]['position'].y)] -= 1
			agent_map[new_position_int.x][new_position_int.y] += 1
			trail_map[new_position_int.x][new_position_int.y] += deposit_size
			agents[i]['position'] = new_position
		else:
			agents[i]['rotation'] = randf_range(0, 2*PI)

func _process_sensory_stage() -> void:
	var start_time = Time.get_ticks_usec()
	agents.shuffle()
	sensory_thread = Thread.new()
	sensory_thread_2 = Thread.new()
	sensory_thread_3 = Thread.new()
	var sensory_callable = Callable(self, '_process_sensory_stage_thread')
	sensory_thread.start(sensory_callable.bind([0, n_agents / 4]))
	sensory_thread_2.start(sensory_callable.bind([n_agents / 4, n_agents / 2]))
	sensory_thread_3.start(sensory_callable.bind([n_agents / 2, 3 * n_agents / 4]))
	_process_sensory_stage_thread([3 * n_agents / 4, n_agents])
	sensory_thread.wait_to_finish()
	sensory_thread_2.wait_to_finish()
	sensory_thread_3.wait_to_finish()
#	var front_sensor : Vector2
#	var left_sensor : Vector2
#	var right_sensor : Vector2
#	var front_sensor_int : Vector2i
#	var left_sensor_int : Vector2i
#	var right_sensor_int : Vector2i
#	var front_sensor_value : float
#	var right_sensor_value : float
#	var left_sensor_value : float
#	for i in range(n_agents):
#		front_sensor = _bound_vector(agents[i]['position'] + Vector2(sensor_distance, 0).rotated(agents[i]['rotation']))
#		left_sensor = _bound_vector(agents[i]['position'] + Vector2(sensor_distance, 0).rotated(agents[i]['rotation'] + sensor_angle))
#		right_sensor = _bound_vector(agents[i]['position'] + Vector2(sensor_distance, 0).rotated(agents[i]['rotation'] - sensor_angle))
#		front_sensor_int = Vector2i(front_sensor)
#		left_sensor_int = Vector2i(left_sensor)
#		right_sensor_int = Vector2i(right_sensor)
#		front_sensor_value = trail_map[front_sensor_int.x][front_sensor_int.y]
#		left_sensor_value = trail_map[left_sensor_int.x][left_sensor_int.y]
#		right_sensor_value = trail_map[right_sensor_int.x][right_sensor_int.y]
#		if (front_sensor_value > left_sensor_value) and (front_sensor_value > right_sensor_value):
#			continue
#		elif (front_sensor_value < left_sensor_value) and (front_sensor_value < right_sensor_value):
#			if randf() < 0.5:
#				agents[i]['rotation'] += rotation_angle
#			else:
#				agents[i]['rotation'] -= rotation_angle
#		elif (left_sensor_value < right_sensor_value):
#			agents[i]['rotation'] -= rotation_angle
#		elif (right_sensor_value < left_sensor_value):
#			agents[i]['rotation'] += rotation_angle
	sensor_time_label.text = String.num((Time.get_ticks_usec() - start_time) / 1000.0, 1) + ' ms'

func _process_sensory_stage_thread(data) -> void:
	var front_sensor : Vector2
	var left_sensor : Vector2
	var right_sensor : Vector2
	var front_sensor_int : Vector2i
	var left_sensor_int : Vector2i
	var right_sensor_int : Vector2i
	var front_sensor_value : float
	var right_sensor_value : float
	var left_sensor_value : float
	for i in range(data[0], data[1]):
		front_sensor = _bound_vector(agents[i]['position'] + Vector2(sensor_distance, 0).rotated(agents[i]['rotation']))
		left_sensor = _bound_vector(agents[i]['position'] + Vector2(sensor_distance, 0).rotated(agents[i]['rotation'] + sensor_angle))
		right_sensor = _bound_vector(agents[i]['position'] + Vector2(sensor_distance, 0).rotated(agents[i]['rotation'] - sensor_angle))
		front_sensor_int = Vector2i(front_sensor)
		left_sensor_int = Vector2i(left_sensor)
		right_sensor_int = Vector2i(right_sensor)
		front_sensor_value = trail_map[front_sensor_int.x][front_sensor_int.y]
		left_sensor_value = trail_map[left_sensor_int.x][left_sensor_int.y]
		right_sensor_value = trail_map[right_sensor_int.x][right_sensor_int.y]
		if (front_sensor_value > left_sensor_value) and (front_sensor_value > right_sensor_value):
			continue
		elif (front_sensor_value < left_sensor_value) and (front_sensor_value < right_sensor_value):
			if randf() < 0.5:
				agents[i]['rotation'] += rotation_angle
			else:
				agents[i]['rotation'] -= rotation_angle
		elif (left_sensor_value < right_sensor_value):
			agents[i]['rotation'] -= rotation_angle
		elif (right_sensor_value < left_sensor_value):
			agents[i]['rotation'] += rotation_angle

func _bound_vector(v: Vector2) -> Vector2:
	if int(v.x) > image_size.x - 1:
		v.x -= image_size.x
	if int(v.y) > image_size.y - 1:
		v.y -= image_size.y
	if int(v.x) < 0:
		v.x += image_size.x
	if int(v.y) < 0:
		v.y += image_size.y
	return v


func _bound_float(n: float) -> float:
	if int(n) > image_size.x - 1:
		return n - image_size.x
	if int(n) < 0:
		return n + image_size.x
	return n


func _compute_summed_area_table() -> void:
	for x in range(image_size.x):
		for y in range(image_size.y):
			if x == 0 and y == 0:
				trail_map_summed_area[x][y] = trail_map[x][y]
			elif x == 0 and y != 0:
				trail_map_summed_area[x][y] = trail_map_summed_area[x][y - 1] + trail_map[x][y]
			elif x != 0 and y == 0:
				trail_map_summed_area[x][y] = trail_map_summed_area[x - 1][y] + trail_map[x][y]
			else:
				trail_map_summed_area[x][y] = trail_map_summed_area[x][y - 1] + trail_map_summed_area[x - 1][y] - trail_map_summed_area[x - 1][y - 1] + trail_map[x][y]


func _process_diffusion() -> void:
	var start_time = Time.get_ticks_usec()
	_compute_summed_area_table()
	# Diffusion kernel
	diffusion_thread = Thread.new()
	diffusion_thread_2 = Thread.new()
	diffusion_thread_3 = Thread.new()
	var diffusion_callable = Callable(self, '_process_diffusion_thread')
	diffusion_thread.start(diffusion_callable.bind([k + 1, (image_size.x - k) / 2, k + 1, (image_size.y - k) / 2]))
	diffusion_thread_2.start(diffusion_callable.bind([(image_size.x - k) / 2, image_size.x - k, k + 1, (image_size.y - k) / 2]))
	diffusion_thread_3.start(diffusion_callable.bind([k + 1, (image_size.x - k) / 2, (image_size.y - k) / 2, image_size.y - k]))
	_process_diffusion_thread([(image_size.x - k) / 2, image_size.x - k, (image_size.y - k) / 2, image_size.y - k])
	diffusion_thread.wait_to_finish()
	diffusion_thread_2.wait_to_finish()
	diffusion_thread_3.wait_to_finish()
#	for x in range(k + 1, image_size.x - k):
#		for y in range(k + 1, image_size.y - k):
#			trail_map[x][y] = (trail_map_summed_area[x - k - 1][y - k - 1] + trail_map_summed_area[x + k][y + k] - trail_map_summed_area[x + k][y - k - 1] - trail_map_summed_area[x - k - 1][y + k]) / pow(diffusion_kernel_size, 2)
	# Border conditions (fill in copy of next pixel)
	for x in range(image_size.x):
		for y in range(0, k + 1):
			trail_map[x][y] = trail_map[x][k + 1]
		for y in range(image_size.y - k, image_size.y):
			trail_map[x][y] = trail_map[x][image_size.y - k - 1]
	for y in range(image_size.y):
		for x in range(0, k + 1):
			trail_map[x][y] = trail_map[k + 1][y]
		for x in range(image_size.x - k, image_size.x):
			trail_map[x][y] = trail_map[image_size.x - k - 1][y]
	diffusion_time_label.text = String.num((Time.get_ticks_usec() - start_time) / 1000.0, 1) + ' ms'


func _process_diffusion_thread(data):
	for x in range(data[0], data[1]):
		for y in range(data[2], data[3]):
			trail_map[x][y] = (trail_map_summed_area[x - k - 1][y - k - 1] + trail_map_summed_area[x + k][y + k] - trail_map_summed_area[x + k][y - k - 1] - trail_map_summed_area[x - k - 1][y + k]) / pow(diffusion_kernel_size, 2)
	


func _process_decay() -> void:
	var start_time = Time.get_ticks_usec()
	trail_map_max_array = [0.0, 0.0, 0.0, 0.0]
	trail_map_min_array = [9999.9, 9999.9, 9999.9, 9999.9]
	decay_thread = Thread.new()
	decay_thread_2 = Thread.new()
	decay_thread_3 = Thread.new()
	var decay_callable = Callable(self, '_process_decay_thread')
	decay_thread.start(decay_callable.bind([0, image_size.x / 2, 0, image_size.y / 2, 0]))
	decay_thread_2.start(decay_callable.bind([image_size.x / 2, image_size.x, 0, image_size.y / 2, 1]))
	decay_thread_3.start(decay_callable.bind([0, image_size.x / 2, image_size.y / 2, image_size.y, 2]))
	_process_decay_thread([image_size.x / 2, image_size.x, image_size.y / 2, image_size.y, 3])
	decay_thread.wait_to_finish()
	decay_thread_2.wait_to_finish()
	decay_thread_3.wait_to_finish()
	trail_map_max = trail_map_max_array.max()
	trail_map_min = trail_map_min_array.min()
#	trail_map_max = 0.0
#	trail_map_min = 9999.9
#	for x in range(image_size.x):
#		for y in range(image_size.y):
#			trail_map[x][y] *= decay_factor
#			if trail_map[x][y] > trail_map_max:
#				trail_map_max = trail_map[x][y]
#			elif trail_map[x][y] < trail_map_min:
#				trail_map_min = trail_map[x][y]
	decay_time_label.text = String.num((Time.get_ticks_usec() - start_time) / 1000.0, 1) + ' ms'

func _process_decay_thread(data):
	for x in range(data[0], data[1]):
		for y in range(data[2], data[3]):
			trail_map[x][y] *= decay_factor
			if trail_map[x][y] > trail_map_max_array[data[4]]:
				trail_map_max_array[data[4]] = trail_map[x][y]
			elif trail_map[x][y] < trail_map_min_array[data[4]]:
				trail_map_min_array[data[4]] = trail_map[x][y]
