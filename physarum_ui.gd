extends Control

var viewport : Viewport
var viewport_width : int
var viewport_height : int

@export var physarum : Node2D

@export_group('Containers')
@export var vbox_container : VBoxContainer
@export_group('Runtime labels')
@export var agent_label : Label
@export var step_label : Label
@export var process_time_label : Label
@export var motor_sensory_time_label : Label
@export var diffusion_decay_time_label : Label
@export var buffer_read_time_label : Label
@export var buffer_update_time_label : Label
@export var texture_time_label : Label
@export var restart_label : Label

@export_group('Parameter labels')
@export var population_percent_label : Label
@export var population_spread_label : Label
@export var decay_factor_label : Label
@export var kernel_label : Label
@export var sensor_distance_label : Label
@export var sensor_angle_label : Label
@export var rotation_angle_label : Label
@export var step_size_label : Label
@export var deposit_size_label : Label

@export_group('Sliders')
@export var population_percent_slider : HSlider
@export var population_spread_slider : HSlider
@export var decay_factor_slider : HSlider
@export var kernel_slider : HSlider
@export var sensor_distance_slider : HSlider
@export var sensor_angle_slider : HSlider
@export var rotation_angle_slider : HSlider
@export var step_size_slider : HSlider
@export var deposit_size_slider : HSlider

@export_group('Buttons')
@export var start_pause_button : Button
@export var save_button : Button

@export_group('Dialogs')
@export var file_dialog : FileDialog

@export_group('Viewports')
@export var agent_map_viewport : SubViewport
@export var trail_map_viewport : SubViewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	file_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	
	viewport = get_tree().get_root()
	viewport.size_changed.connect(_on_Viewport_size_changed)
	viewport_width = ProjectSettings.get_setting('display/window/size/viewport_width')
	viewport_height = ProjectSettings.get_setting('display/window/size/viewport_height')
	vbox_container.size = Vector2(viewport_width, viewport_height)
	
#	file_dialog.size = Vector2(viewport_width / 2, viewport_height / 2)
#	file_dialog.position = Vector2(viewport_width / 4, viewport_height / 4)
	
	restart_label.text = ''

func _process(_delta: float) -> void:
	pass

func _update_all_parameter_labels() -> void:
	agent_label.text = str(physarum.n_agents)
	population_percent_label.text = String.num(physarum.population_percent, 1) + ' %'
	population_spread_label.text = String.num(physarum.population_initial_spread, 1)
	decay_factor_label.text = String.num(physarum.decay_factor, 3)
	kernel_label.text = str(physarum.diffusion_kernel_size)
	sensor_distance_label.text = String.num(physarum.sensor_distance, 2)
	sensor_angle_label.text = String.num(rad_to_deg(physarum.sensor_angle), 1) + '°'
	rotation_angle_label.text = String.num(rad_to_deg(physarum.rotation_angle), 1) + '°'
	step_size_label.text = String.num(physarum.step_size, 2)
	deposit_size_label.text = String.num(physarum.deposit_size, 2)
	

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
	_update_all_parameter_labels()
	
	population_percent_slider.value = physarum.population_percent
	population_spread_slider.value = physarum.population_initial_spread
	decay_factor_slider.value = physarum.decay_factor
	kernel_slider.value = physarum.diffusion_kernel_size
	sensor_distance_slider.value = physarum.sensor_distance
	sensor_angle_slider.value = physarum.sensor_angle
	rotation_angle_slider.value = physarum.rotation_angle
	step_size_slider.value = physarum.step_size
	deposit_size_slider.value = physarum.deposit_size


func _on_restart_button_pressed() -> void:
	get_tree().paused = true
	start_pause_button.button_pressed = false
	start_pause_button.text = 'Start'
	restart_label.text = ''
	physarum.restart_simulation()
	_update_all_parameter_labels()


func _on_population_percent_slider_value_changed(value: float) -> void:
	physarum.population_percent = value
	population_percent_label.text = String.num(value, 1)
	restart_label.text = 'Restart required'


func _on_population_spread_slider_value_changed(value):
	physarum.population_initial_spread = value
	population_spread_label.text = String.num(value, 1)
	restart_label.text = 'Restart required'


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
	sensor_angle_label.text = String.num(rad_to_deg(value), 1) + '°'


func _on_rotation_angle_slider_value_changed(value: float) -> void:
	physarum.rotation_angle = value
	rotation_angle_label.text = String.num(rad_to_deg(value), 1) + '°'


func _on_step_size_slider_value_changed(value: float) -> void:
	physarum.step_size = value
	step_size_label.text = String.num(value, 2)


func _on_deposit_size_slider_value_changed(value: float) -> void:
	physarum.deposit_size = value
	deposit_size_label.text = String.num(value, 2)


func _on_save_button_pressed():
	get_tree().paused = true
	start_pause_button.button_pressed = true
	start_pause_button.text = 'Resume'
	file_dialog.popup_centered_ratio(0.5)


func _on_file_dialog_dir_selected(dir):
	var ts_dict := Time.get_datetime_dict_from_system()
	var agent_filename := '{dir}/physarum_agent_map_{year}{month}{day}T{hour}{minute}{second}.png'.format({
		'dir': dir,
		'year': ts_dict['year'],
		'month': ts_dict['month'],
		'day': ts_dict['day'],
		'hour': ts_dict['hour'],
		'minute': ts_dict['minute'],
		'second': ts_dict['second']
	})
	var trail_filename := '{dir}/physarum_trail_map_{year}{month}{day}T{hour}{minute}{second}.png'.format({
		'dir': dir,
		'year': ts_dict['year'],
		'month': ts_dict['month'],
		'day': ts_dict['day'],
		'hour': ts_dict['hour'],
		'minute': ts_dict['minute'],
		'second': ts_dict['second']
	})
	agent_map_viewport.get_texture().get_image().save_png(agent_filename)
	trail_map_viewport.get_texture().get_image().save_png(trail_filename)
