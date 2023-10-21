@tool
extends Node3D

signal task_changed

@export_multiline var description: String = "Task description here":
	get:
		return description
	set(text):
		description = text
		_update_label()
		task_changed.emit()

@export_multiline var details: String:
	get:
		return details
	set(text):
		details = text
		_update_label()
		task_changed.emit()
		
@export_enum("BUG", "FEATURE") var task_type: String = "BUG":
	get:
		return task_type
	set(value):
		task_type = value
		task_changed.emit()
		
@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		_update_mesh()
		task_changed.emit()

@onready var label_3d = %Label3D
@onready var bug_marker_mesh = %BugMarkerMesh
@onready var check_mark_mesh = %CheckMarkMesh


# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("_setup")
	
	
func _setup() -> void:
	_update_label()
	_update_mesh()


func _update_label():
	if label_3d:
		label_3d.text = description + "\n\n" + details
		

func _update_mesh():
	if bug_marker_mesh and check_mark_mesh:
		bug_marker_mesh.visible = !fixed
		check_mark_mesh.visible = fixed
		
