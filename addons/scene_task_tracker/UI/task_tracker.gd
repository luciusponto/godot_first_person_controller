@tool
extends EditorPlugin
var dock
var task_data_inspector_plugin

func _enter_tree():
	dock = preload("./task_tracker_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	#task_data_inspector_plugin = preload("res://addons/scene_task_tracker/scripts/task_inspector.gd").new()
	#add_inspector_plugin(task_data_inspector_plugin)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	#remove_inspector_plugin(task_data_inspector_plugin)
