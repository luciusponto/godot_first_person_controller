@tool
extends EditorPlugin
var _dock: SttTasksDock

var _dragging_marker: bool = true
var _valid_drop_pos: bool = true
var _new_task_button: SttMarkerButton
var _drag_overlay: Control
const DRAG_OVERLAY_PREFAB = preload("res://addons/scene_task_tracker/UI/drag_overlay_prefab.tscn")

func _on_drag_started():
	if is_instance_valid(_drag_overlay):
		_drag_overlay.queue_free()
	_dragging_marker = true
	_drag_overlay = DRAG_OVERLAY_PREFAB.instantiate()
	_drag_overlay.name = "DragOverlay"
	_drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't interfere with other input
	_drag_overlay.position = get_viewport().get_mouse_position()# - _drag_overlay.size / 2
	#var forbidden_icon = _drag_overlay.get_node("%ForbiddenIcon") as TextureRect
	#forbidden_icon.texture = forbidden_icon.get_theme_icon(&"ImportFail", &"EditorIcons")
	#DisplayServer.cursor_set_shape(DisplayServer.CURSOR_FORBIDDEN)
	#_drag_overlay.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	EditorInterface.get_base_control().add_child(_drag_overlay)
	set_process(true) # Start processing for updates

func _on_drag_ended(mouse_pos, task):
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	_dragging_marker = false
	if is_instance_valid(_drag_overlay):
		_drag_overlay.queue_free()
		_drag_overlay = null
	set_process(false)	

func _enter_tree():
	#set_force_draw_over_forwarding_enabled()
	_dragging_marker = true
	_dock = preload("UI/task_tracker_dock.tscn").instantiate() as SttTasksDock
	_dock.marker_drag_started.connect(_on_drag_started)
	_dock.marker_drag_ended.connect(_on_drag_ended)
	#_dock.marker_dra
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree():
	_dock.marker_drag_started.disconnect(_on_drag_started)
	_dock.marker_drag_ended.disconnect(_on_drag_ended)
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
		
func _process(_delta):
	if is_instance_valid(_drag_overlay):
		_drag_overlay.position = get_viewport().get_mouse_position()
		
#func _forward_canvas_force_draw_over_viewport(viewport_control):
	#EditorInterface.get_base_control().mouse_default_cursor_shape = Control.CURSOR_DRAG
