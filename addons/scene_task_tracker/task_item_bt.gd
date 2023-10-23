@tool
extends Control

signal select_requested(node_instanceid: int)

const BUG_MARKER = preload("res://addons/first_person_controller/examples/debug/bug_marker.gd")

var bug_icon = preload("res://addons/first_person_controller/examples/debug/textures/bug.png")
var task_icon = preload("res://addons/first_person_controller/examples/debug/textures/task.png")
var task_instance_id: int
var task_priority: int

func setup(target_task):
	var task = target_task as BUG_MARKER
	task_instance_id = task.get_instance_id()
#	%DescriptionLabel.text = task.description
#	%DescriptionLabel.tooltip_text = task.description
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.description
	%TaskTypeIcon.texture = bug_icon if task.task_type == "BUG" else task_icon
	%TaskTypeIcon.modulate = Color.CORAL if task.task_type == "BUG" else Color.AQUAMARINE
	%FixedCheckBox.button_pressed = task.fixed
	%PriorityLabel.text = str(task.priority)
	task_priority = task.priority

func _on_description_button_pressed():
	select_requested.emit(task_instance_id)
