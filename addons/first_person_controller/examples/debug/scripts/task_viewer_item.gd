extends HBoxContainer

const BUG_MARKER = preload("res://addons/first_person_controller/examples/debug/bug_marker.gd")

var task

var bug_texture = preload("res://addons/first_person_controller/examples/debug/textures/bug.png")
var task_texture = preload("res://addons/first_person_controller/examples/debug/textures/task.png")
var active_texture = preload("res://addons/first_person_controller/examples/debug/textures/active.png")
var done_texture = preload("res://addons/first_person_controller/examples/debug/textures/done.png")

func setup(target_task):
	task = target_task
	_apply_values()
	
func _apply_values():
	var _task_type_icon: TextureRect = %TaskTypeIcon
	var _status_icon: TextureRect  = %StatusIcon
	var _task_descr_label: Label = %TaskDescrLabel

	_task_descr_label.text = task.description
	
	var task_type: String = task.task_type
	match task_type:
		"BUG":
			_task_type_icon.texture = bug_texture
			_task_type_icon.modulate = Color.CORAL
		"TASK":
			_task_type_icon.texture = task_texture
			_task_type_icon.modulate = Color.AQUAMARINE
	
	if task.fixed:
		_status_icon.texture = done_texture
		_status_icon.modulate = Color.MEDIUM_SEA_GREEN
	else:
		_status_icon.texture = active_texture
		_status_icon.modulate = Color.DARK_KHAKI
