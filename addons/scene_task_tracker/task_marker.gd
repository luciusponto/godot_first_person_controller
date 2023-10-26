@tool
extends Node3D

signal task_changed

enum TaskTypes {
	BUG,
	FEATURE,
	TECHNICAL_IMPROVEMENT,
	POLISH,
	REGRESSION_TEST,
}

const BILLBOARDS = [
	preload("res://addons/scene_task_tracker/model/billboard/bug_marker_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/feature_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/tech_impr_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/polish_billboard.tscn"),
	preload("res://addons/scene_task_tracker/model/billboard/reg_test_billboard.tscn"),
]

const ICONS = [
	preload("res://addons/scene_task_tracker/icons/bug.svg"),
	preload("res://addons/scene_task_tracker/icons/feature.svg"),
	preload("res://addons/scene_task_tracker/icons/tech_improvement.svg"),
	preload("res://addons/scene_task_tracker/icons/polish.svg"),
	preload("res://addons/scene_task_tracker/icons/regression_test.svg"),
]

const COLORS = [
	Color.CORAL,
	Color.AQUAMARINE,
	Color.GOLD,
	Color.MEDIUM_AQUAMARINE,
	Color.SILVER,
]

const DEFAULT_BILLBOARD = preload("res://addons/scene_task_tracker/model/billboard/bug_marker_billboard.tscn")
const DEFAULT_ICON = preload("res://addons/scene_task_tracker/icons/pending.svg")
const DEFAULT_COLOR = Color.MAGENTA

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

@export var task_type_en: TaskTypes = TaskTypes.BUG:
	get:
		return task_type_en
	set(value):
		task_type_en = value
		task_changed.emit()
		_update_mesh()

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
		task_changed

#@export var test_change_type: bool = false:
#	get:
#		return test_change_type
#	set(value):
#		for i in range(0, 100000):
#			if i % 2 == 0:
#				task_type_en = TaskTypes.BUG
#			else:
#				task_type_en = TaskTypes.FEATURE
				
@onready var label_3d = %Label3D

var _billboard: Node3D
var _initialized := false


# Called when the node enters the scene tree for the first time.
func _ready():
	if not _initialized:
		call_deferred("_setup")
		_initialized = true


func get_color() -> Color:
	if task_type_en > len(COLORS) - 1:
		return DEFAULT_COLOR
	return COLORS[task_type_en]


func get_icon() -> Resource:
	if task_type_en > len(ICONS) - 1:
		return DEFAULT_ICON
	return ICONS[task_type_en]


func _setup() -> void:
	_update_label()
	_update_mesh()


func _update_label():
	if label_3d:
		label_3d.text = description + "\n\n" + details
		

func _update_mesh():
#	print("Updating mesh for " + name)
	if _billboard:
		_billboard.free()
	var _billboard_res
	if fixed:
		_billboard_res = FIXED_BILLBOARD
	else:
		_billboard_res = BILLBOARDS[task_type_en]
	_billboard = _billboard_res.instantiate()
	add_child(_billboard)
