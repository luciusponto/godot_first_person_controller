@tool
extends Control
const BUG_MARKER = preload("res://addons/first_person_controller/examples/debug/bug_marker.gd")

var bug_icon = preload("res://addons/first_person_controller/examples/debug/textures/bug.png")
var task_icon = preload("res://addons/first_person_controller/examples/debug/textures/task.png")

func setup(target_task):
	var task = target_task as BUG_MARKER
	%DescriptionLabel.text = task.description
	%DescriptionLabel.tooltip_text = task.description
	%TaskTypeIcon.texture = bug_icon if task.task_type == "BUG" else task_icon
	%FixedCheckBox.button_pressed = task.fixed

