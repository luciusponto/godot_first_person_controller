@tool
extends Control

signal select_requested(node_instanceid: int)
const TASK_GRAPHICS = preload("res://addons/scene_task_tracker/scripts/task_graphics.gd")

#var task_instance_id: int
var marker_instance_id: int
var task: SttTaskData

func _format_text(text: String, max_line_len := 80) -> String:
	text = text.replace(". ", ".\n")
	return ""
	
func _disconnect_task_changed():
	if task:
		if task.changed.is_connected(_on_task_data_changed):
			task.changed.disconnect(_on_task_data_changed)
		
func _exit_tree():
	_disconnect_task_changed()
	
func _on_task_data_changed():
	setup(task)

func setup(target_task):
	if target_task != task:
		_disconnect_task_changed()
		task = target_task as SttTaskData
		task.changed.connect(_on_task_data_changed)
	#task_instance_id = task.get_instance_id()
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.get_wrapped_description_details()
	%TaskTypeIcon3.texture = TASK_GRAPHICS.get_icon(task)
	#%TaskTypeIcon.tooltip_text = (SttTaskData.TaskTypes.keys()[task.task_type] as String).capitalize()
	%TaskTypeIcon3.modulate = TASK_GRAPHICS.get_color(task)
	#%PriorityLabel.text = "c" if task.fixed else str(task.priority)
	%PriorityLabel.text = str(task.priority)
	var task_type_str = (SttTaskData.TaskTypes.keys()[task.task_type] as String).capitalize()
	var icons_tooltip: String 
	var priority_text_color = %PriorityLabel.modulate
	if task.fixed:
		%TaskTypeIcon3.modulate = Color.hex(%TaskTypeIcon3.modulate.to_rgba32() & 0xffffff99)
		%PriorityLabel.modulate = Color.hex(%PriorityLabel.modulate.to_rgba32() & 0xffffff99)
		icons_tooltip = task_type_str + ", completed, priority: "
	else:
		%TaskTypeIcon3.modulate = Color.hex(%TaskTypeIcon3.modulate.to_rgba32() | 0x000000ff)
		%PriorityLabel.modulate = Color.hex(%PriorityLabel.modulate.to_rgba32() | 0x000000ff)
		icons_tooltip = task_type_str + ", priority: "
	icons_tooltip += str(task.priority)
	%IconsMarginContainer.tooltip_text = icons_tooltip

func _on_description_button_pressed():
	# TODO: see next line
	push_warning("marker_instance_id needs initialization in setup function")
	select_requested.emit(marker_instance_id)
