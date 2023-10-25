@tool
extends Control

signal select_requested(node_instanceid: int)

const BUG_MARKER = preload("res://addons/first_person_controller/examples/debug/bug_marker.gd")

var bug_icon = preload("res://addons/scene_task_tracker/icons/bug.svg")
var feature_icon = preload("res://addons/scene_task_tracker/icons/feature.svg")
var tech_improv_icon = preload("res://addons/scene_task_tracker/icons/tech_improvement.svg")
var polish_icon = preload("res://addons/scene_task_tracker/icons/polish.svg")
var regr_test_icon = preload("res://addons/scene_task_tracker/icons/regression_test.svg")
var task_instance_id: int
var task_priority: int

func setup(target_task):
	var task = target_task as BUG_MARKER
	task_instance_id = task.get_instance_id()
#	%DescriptionLabel.text = task.description
#	%DescriptionLabel.tooltip_text = task.description
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.description
	match task.task_type:
		"BUG":
			%TaskTypeIcon.texture = bug_icon
			%TaskTypeIcon.modulate = Color.CORAL
		"FEATURE":
			%TaskTypeIcon.texture = feature_icon
			%TaskTypeIcon.modulate = Color.AQUAMARINE
		"TECHNICAL_IMPROVEMENT":
			%TaskTypeIcon.texture = tech_improv_icon
			%TaskTypeIcon.modulate = Color.GOLD
		"POLISH":
			%TaskTypeIcon.texture = polish_icon
			%TaskTypeIcon.modulate = Color.MEDIUM_AQUAMARINE
		"REGRESSION_TEST":
			%TaskTypeIcon.texture = regr_test_icon
			%TaskTypeIcon.modulate = Color.SILVER
		_:
			%TaskTypeIcon.texture = bug_icon
			%TaskTypeIcon.modulate = Color.CORAL
	%FixedCheckBox.button_pressed = task.fixed
	%PriorityLabel.text = str(task.priority)
	task_priority = task.priority

func _on_description_button_pressed():
	select_requested.emit(task_instance_id)
