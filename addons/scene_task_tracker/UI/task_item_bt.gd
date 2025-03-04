@tool
extends Control

signal select_requested(node_instanceid: int)

const BUG_MARKER = preload("res://addons/scene_task_tracker/task_marker.gd")

var task_instance_id: int
var task_priority: int

func _format_text(text: String, max_line_len := 80) -> String:
	text = text.replace(". ", ".\n")
	return ""

func setup(target_task):
	var task = target_task as BUG_MARKER
	task_instance_id = task.get_instance_id()
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.description + ("\n\nDetails:\n" + (task.details as String).replace(". ", ".\n") if len(task.details) > 0 else "")
	%TaskTypeIcon.texture = task.get_icon()
	%TaskTypeIcon.modulate = task.get_color()
	%TaskTypeIcon.tooltip_text = (BUG_MARKER.TaskTypes.keys()[task.task_type] as String).capitalize()
	%FixedCheckBox.button_pressed = task.fixed
	%FixedCheckBox.tooltip_text = "Completed" if task.fixed else "Not completed"
	%PriorityLabel.text = str(task.priority)
	%PriorityLabel.tooltip_text = "Priority: " + str(task.priority)
	task_priority = task.priority

func _on_description_button_pressed():
	select_requested.emit(task_instance_id)
