@tool
extends Control

signal select_requested(node_instanceid: int)
const TASK_GRAPHICS = preload("res://addons/scene_task_tracker/scripts/task_graphics.gd")

#const BUG_MARKER = preload("res://addons/scene_task_tracker/task_marker.gd")

var task_instance_id: int
var task_priority: int

func _format_text(text: String, max_line_len := 80) -> String:
	text = text.replace(". ", ".\n")
	return ""

func setup(target_task):
	var task = target_task as SttTaskData
	#task_instance_id = task.get_instance_id()
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.description + ("\n\nDetails:\n" + (task.details as String).replace(". ", ".\n") if len(task.details) > 0 else "")
	%TaskTypeIcon3.texture = TASK_GRAPHICS.get_icon(task)
	#%TaskTypeIcon.tooltip_text = (SttTaskData.TaskTypes.keys()[task.task_type] as String).capitalize()
	%TaskTypeIcon3.modulate = TASK_GRAPHICS.get_color(task)
	#%FixedCheckBox.button_pressed = task.fixed
	#%FixedCheckBox.tooltip_text = "Completed" if task.fixed else "Not completed"
	%PriorityLabel.text = "c" if task.fixed else str(task.priority)
	#%PriorityLabel.tooltip_text = "Priority: " + str(task.priority)
	var icons_tooltip: String
	var task_type_str = (SttTaskData.TaskTypes.keys()[task.task_type] as String).capitalize()
	if task.fixed:
		icons_tooltip = task_type_str + ", completed"
	else:
		icons_tooltip = task_type_str + ", priority: " + str(task.priority)
	%IconsMarginContainer.tooltip_text =icons_tooltip
	task_priority = task.priority

func _on_description_button_pressed():
	select_requested.emit(task_instance_id)
