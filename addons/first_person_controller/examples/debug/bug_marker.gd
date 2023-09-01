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

@export var label: Label3D


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_label()


func _update_label():
	if label:
		label.text = description + "\n\n" + details
