extends Control

var viewport : Viewport
var viewport_width : int
var viewport_height : int

@export var physarum : Node2D

# Control
@export var vbox_container : VBoxContainer

@export var agent_label : Label
@export var step_label : Label
@export var process_time_label : Label
@export var motor_sensory_time_label : Label
@export var diffusion_decay_time_label : Label
@export var buffer_read_time_label : Label
@export var buffer_update_time_label : Label
@export var texture_time_label : Label

@export var population_percent_label : Label
@export var decay_factor_label : Label
@export var kernel_label : Label
@export var sensor_distance_label : Label
@export var sensor_angle_label : Label
@export var rotation_angle_label : Label
@export var step_size_label : Label
@export var deposit_size_label : Label

@export var population_percent_slider : HSlider
@export var decay_factor_slider : HSlider
@export var kernel_slider : HSlider
@export var sensor_distance_slider : HSlider
@export var sensor_angle_slider : HSlider
@export var rotation_angle_slider : HSlider
@export var step_size_slider : HSlider
@export var deposit_size_slider : HSlider

@export var start_pause_button : Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	viewport = get_tree().get_root()
	viewport.size_changed.connect(_on_Viewport_size_changed)
	viewport_width = ProjectSettings.get_setting('display/window/size/viewport_width')
	viewport_height = ProjectSettings.get_setting('display/window/size/viewport_height')
	vbox_container.size = Vector2(viewport_width, viewport_height)

func _process(_delta: float) -> void:
	pass

func _on_Viewport_size_changed() -> void:
	viewport_width = viewport.size.x
	viewport_height = viewport.size.y
	vbox_container.size = Vector2(viewport_width, viewport_height)


func _on_physarum_buffer_read_time_updated(buffer_read_time: float) -> void:
	buffer_read_time_label.text = String.num(buffer_read_time, 1) + ' ms'


func _on_physarum_buffer_update_time_updated(buffer_update_time: float) -> void:
	buffer_update_time_label.text = String.num(buffer_update_time, 1) + ' ms'


func _on_physarum_diffusion_decay_time_updated(diffusion_decay_time: float) -> void:
	diffusion_decay_time_label.text = String.num(diffusion_decay_time, 1) + ' ms'


func _on_physarum_motor_sensory_time_updated(motor_sensory_time: float) -> void:
	motor_sensory_time_label.text = String.num(motor_sensory_time, 1) + ' ms'


func _on_physarum_process_time_updated(process_time: float) -> void:
	process_time_label.text = String.num(process_time, 1) + ' ms'


func _on_physarum_step_count_updated(step_count: int) -> void:
	step_label.text = str(step_count)


func _on_physarum_texture_time_updated(texture_time: float) -> void:
	texture_time_label.text = String.num(texture_time, 1) + ' ms'


func _on_start_button_toggled(button_pressed: bool) -> void:
	if button_pressed:
		start_pause_button.text = "Pause"
		get_tree().paused = false
	else:
		start_pause_button.text = "Resume"
		get_tree().paused = true


func _on_physarum_ready() -> void:
	agent_label.text = str(physarum.n_agents)
	population_percent_label.text = String.num(physarum.population_percent, 1) + ' %'
	decay_factor_label.text = String.num(physarum.decay_factor, 3)
	kernel_label.text = str(physarum.diffusion_kernel_size)
	sensor_distance_label.text = String.num(physarum.sensor_distance, 2)
	sensor_angle_label.text = String.num(rad_to_deg(physarum.sensor_angle), 1) + ' deg'
	rotation_angle_label.text = String.num(rad_to_deg(physarum.rotation_angle), 1) + ' deg'
	step_size_label.text = String.num(physarum.step_size, 2)
	deposit_size_label.text = String.num(physarum.deposit_size, 2)
	
	population_percent_slider.value = physarum.population_percent
	decay_factor_slider.value = physarum.decay_factor
	kernel_slider.value = physarum.diffusion_kernel_size
	sensor_distance_slider.value = physarum.sensor_distance
	sensor_angle_slider.value = physarum.sensor_angle
	rotation_angle_slider.value = physarum.rotation_angle
	step_size_slider.value = physarum.step_size
	deposit_size_slider.value = physarum.deposit_size


func _on_restart_button_pressed() -> void:
	physarum.population_percent = population_percent_slider.value
	physarum.decay_factor = decay_factor_slider.value
	physarum.diffusion_kernel_size = kernel_slider.value
	physarum.sensor_distance = sensor_distance_slider.value
	physarum.sensor_angle = sensor_angle_slider.value
	physarum.rotation_angle = rotation_angle_slider.value
	physarum.step_size = step_size_slider.value
	physarum.deposit_size = deposit_size_slider.value
	
	texture_time_label.text = ' '
	step_label.text = ' '
	process_time_label.text = ' '
	motor_sensory_time_label.text = ' '
	diffusion_decay_time_label.text = ' '
	buffer_update_time_label.text = ' '
	buffer_read_time_label.text = ' '
	
	physarum.restart_simulation()
	
	agent_label.text = str(physarum.n_agents)
	population_percent_label.text = String.num(physarum.population_percent, 1) + ' %'
	decay_factor_label.text = String.num(physarum.decay_factor, 3)
	kernel_label.text = str(physarum.diffusion_kernel_size)
	sensor_distance_label.text = String.num(physarum.sensor_distance, 2)
	sensor_angle_label.text = String.num(rad_to_deg(physarum.sensor_angle), 1) + ' deg'
	rotation_angle_label.text = String.num(rad_to_deg(physarum.rotation_angle), 1) + ' deg'
	step_size_label.text = String.num(physarum.step_size, 2)
	deposit_size_label.text = String.num(physarum.deposit_size, 2)


func _on_population_percent_slider_value_changed(value: float) -> void:
	pass # Replace with function body.
	

func _on_decay_slider_value_changed(value: float) -> void:
	physarum.decay_factor = value
	decay_factor_label.text = String.num(value, 3)


func _on_kernel_size_slider_value_changed(value: int) -> void:
	physarum.diffusion_kernel_size = value
	kernel_label.text = str(value)


func _on_sensor_distance_slider_value_changed(value: float) -> void:
	physarum.sensor_distance = value
	sensor_distance_label.text = String.num(value, 2)


func _on_sensor_angle_slider_value_changed(value: float) -> void:
	physarum.sensor_angle = value
	sensor_angle_label.text = String.num(rad_to_deg(value), 1) + ' deg'


func _on_rotation_angle_slider_value_changed(value: float) -> void:
	physarum.rotation_angle = value
	rotation_angle_label.text = String.num(rad_to_deg(value), 1) + ' deg'


func _on_step_size_slider_value_changed(value: float) -> void:
	physarum.step_size = value
	step_size_label.text = String.num(value, 2)


func _on_deposit_size_slider_value_changed(value: float) -> void:
	physarum.deposit_size = value
	deposit_size_label.text = String.num(value, 2)
