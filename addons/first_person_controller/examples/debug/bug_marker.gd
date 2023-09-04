@tool
extends Node3D

@export_multiline var description: String = "Task description here":
	get:
		return description
	set(text):
		description = text
		_update_label()

@export_multiline var details: String = "Details here":
	get:
		return details
	set(text):
		details = text
		_update_label()
		
@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		_update_mesh()

@export var label: Label3D
@export var _bug_marker_mesh: Node3D
@export var _check_mark_mesh: Node3D
	
	
# Called when the node enters the scene tree for the first time.
func _ready():
	_update_label()
	call_deferred("_update_mesh")


func _update_label():
	if label:
		label.text = description + "\n\n" + details
		

func _update_mesh():
	_bug_marker_mesh.visible = !fixed
	_check_mark_mesh.visible = fixed
		
