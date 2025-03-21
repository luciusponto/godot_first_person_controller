@tool
extends Node3D

var task: SttTaskData

@onready var label_3d: Label3D = %Label3D
var _billboard: Node3D

func _on_task_changed():
	setup(task)

func setup(new_task) -> void:
	if task:
		if task.changed.is_connected(_on_task_changed):
			task.changed.disconnect(_on_task_changed)
	task = new_task
	task.changed.connect(_on_task_changed)
	_update_label()
	_update_mesh()
	position = task.marker_data.position
	rotation = task.marker_data.rotation

func _update_label():
	if label_3d:
		label_3d.text = task.get_wrapped_description_details()

func _update_mesh():
	if _billboard:
		_billboard.queue_free()
	var _billboard_res
	if task.fixed:
		_billboard_res = SttTaskGraphics.FIXED_BILLBOARD
	else:
		_billboard_res = SttTaskGraphics.get_model(task)
	_billboard = _billboard_res.instantiate()
	add_child(_billboard)
