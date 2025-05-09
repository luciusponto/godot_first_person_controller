@tool
extends EditorPlugin

class_name SttPlugin

const DRAG_OVERLAY_PREFAB = preload("res://addons/scene_task_tracker/UI/drag_overlay_prefab.tscn")

var _dock: SttTasksDock
var _drag_overlay: Control

func _enter_tree():
	_dock = preload("UI/task_tracker_dock.tscn").instantiate() as SttTasksDock
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_drag_overlay = DRAG_OVERLAY_PREFAB.instantiate()
	_drag_overlay.name = "DragOverlay"
	_drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't interfere with other input
	_drag_overlay.get_node("%ForbiddenIcon").visible = true
	_drag_overlay.get_node("%AllowedIcon").visible = false
	_drag_overlay.visible = false
	EditorInterface.get_base_control().add_child(_drag_overlay)
	SttHelper.drag_cursor_updated.connect(_on_drag_cursor_updated)

func _exit_tree():
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if is_instance_valid(_drag_overlay):
		EditorInterface.get_base_control().remove_child(_drag_overlay)
		_drag_overlay.queue_free()
		_drag_overlay = null
	SttHelper.drag_cursor_updated.disconnect(_on_drag_cursor_updated)
	
func _on_drag_cursor_updated(enabled: bool, drop_allowed: bool):
	_drag_overlay.visible = enabled
	_drag_overlay.position = get_viewport().get_mouse_position()
	_drag_overlay.get_node("%ForbiddenIcon").visible = not drop_allowed
	_drag_overlay.get_node("%AllowedIcon").visible = drop_allowed
	
func _apply_changes():
	_dock.save_current_database()
