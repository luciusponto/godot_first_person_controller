@tool
extends Node3D

signal task_changed

enum TaskTypes {
	BUG,
	FEATURE,
	TECHNICAL_IMPROVEMENT,
	POLISH,
	REGRESSION_TEST,
	NONE
}

const BILLBOARDS = [
	preload("res://addons/scene_task_tracker/model/billboard/bug_marker_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/feature_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/tech_impr_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/polish_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/reg_test_billboard.tscn"),
]

const FIXED_BILLBOARD = preload("res://addons/scene_task_tracker/model/billboard/check_mark_billboard.tscn")

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
		
@export_enum("BUG", "FEATURE", "TECHNICAL_IMPROVEMENT", "POLISH", "REGRESSION_TEST") var task_type: String = "BUG":
	get:
		return task_type
	set(value):
		task_type = value
		task_changed.emit()
		_update_mesh()
		
@export var task_type_en: TaskTypes = TaskTypes.NONE:
	get:
		return task_type_en
	set(value):
		task_type_en = value
#		task_changed.emit()
#		_update_mesh()
		
@export_range(1, 5) var priority: int = 1:
	get:
		return priority
	set(value):
		priority = value
		task_changed.emit()
		
@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		_update_mesh()
		task_changed.emit()

@onready var label_3d = %Label3D
var _billboard: Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	if task_type_en == TaskTypes.NONE:
		match task_type:
			"BUG":
				task_type_en = TaskTypes.BUG
			"FEATURE":
				task_type_en = TaskTypes.FEATURE
			"TECHNICAL_IMPROVEMENT":
				task_type_en = TaskTypes.TECHNICAL_IMPROVEMENT
			"POLISH":
				task_type_en = TaskTypes.POLISH
			"REGRESSION_TEST":
				task_type_en = TaskTypes.REGRESSION_TEST
	call_deferred("_setup")
	
	
func _setup() -> void:
	_update_label()
	_update_mesh()


func _update_label():
	if label_3d:
		label_3d.text = description + "\n\n" + details
		

func _update_mesh():
	pass
#	if _billboard:
#		_billboard.queue_free
#	if fixed:
#		_billboard = FIXED_BILLBOARD.instantiate()
#		add_child(_billboard)
#	if bug_marker_mesh and check_mark_mesh:
#		bug_marker_mesh.visible = !fixed
#		check_mark_mesh.visible = fixed
		
