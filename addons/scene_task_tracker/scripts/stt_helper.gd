extends Node

class_name SttHelper

const EDITOR_3D_VIEWPORT_COUNT = 4

signal _drag_3d_preview_updated(enabled: bool, xform: Transform3D)
signal _drag_cursor_updated(enabled: bool, drop_allowed: bool)

static var _instance: SttHelper

static var drag_3d_preview_updated: Signal:
	get:
		return get_instance()._drag_3d_preview_updated

static var drag_cursor_updated: Signal:
	get:
		return get_instance()._drag_cursor_updated

static func get_instance():
	if _instance == null:
		_instance = SttHelper.new()
	return _instance

static func get_viewport_3d_index_under_mouse() -> int:
	for i in range(EDITOR_3D_VIEWPORT_COUNT):
		var viewport := EditorInterface.get_editor_viewport_3d(i)
		var mouse_pos_viewport := viewport.get_mouse_position()
		var rect := viewport.get_visible_rect()
		if mouse_pos_viewport.x > 0 and mouse_pos_viewport.x <= rect.size.x and mouse_pos_viewport.y > 0 and mouse_pos_viewport.y <= rect.size.y:
			return i
	return -1
	
static func get_viewport_3d_under_mouse() -> Viewport:
	var index = get_viewport_3d_index_under_mouse()
	if index >= 0:
		return EditorInterface.get_editor_viewport_3d(index)
	return null
