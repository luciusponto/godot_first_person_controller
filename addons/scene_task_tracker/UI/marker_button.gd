@tool
extends Button

class_name SttMarkerButton

signal dropped_marker(xform: Transform3D, task: SttTaskData)

const RAY_LENGTH: float = 100
const INITIAL_SURFACE_OFFSET: float = 0.01
const MAX_REL_SURF_OFFSET: float = 1.0
const SURFACE_OFFSET_STEP_SIZE: float = 0.25
const MAX_SURFACE_OFFSET_STEPS: float = 5
const Y_ANGLE_SNAP_RAD = deg_to_rad(90)
const WALL_ANGLE = 45
const MARKER_SIZE := Vector3(0.75, 1.5, 0.25)

const XFORM_KEY_VALID = "valid"
const XFORM_KEY_XFORM = "xform"

const INVALID_XFORM = {XFORM_KEY_VALID: false, XFORM_KEY_XFORM: null}

var task: SttTaskData

var _dragging: bool = false
var _pressed: bool = false

class ShapeInfo:
	var shape: Shape3D
	var xform: Transform3D
	var fit: bool
	
	func _init(new_shape: Shape3D, new_xform: Transform3D, new_fit: bool):
		shape = new_shape
		xform = new_xform
		fit = new_fit

const SHOW_DEBUG_STEPS := false
const SttDebugDraw = preload("res://addons/scene_task_tracker/scripts/stt_debug_draw.gd")
static var _debug_draw: SttDebugDraw
static var _debug_shapes: Array[ShapeInfo] = []

func _enter_tree():
	if not is_instance_valid(_debug_draw):
		_debug_draw = SttDebugDraw.new()
	mouse_exited.connect(_on_mouse_exited)
	
func _ready():
	set_process(false)
	
func _on_mouse_exited():
	if button_pressed and not _dragging:
		_start_drag()

func _draw_debug():
	if is_instance_valid(_debug_draw):
		if _debug_shapes.size() == 0:
			return
		var marker_fits = _debug_shapes[-1].fit
		var final_color := Color.GREEN if marker_fits else Color.RED
		var initial_color := Color.YELLOW
		var middle_color := Color.CYAN
		var final_shape: ShapeInfo
		var steps_range_start = 0 if marker_fits else 1
		var steps_range_end = _debug_shapes.size() - 1 if marker_fits else _debug_shapes.size()
		if SHOW_DEBUG_STEPS:
			for i in range(steps_range_start, steps_range_end):
				var sh = _debug_shapes[i]
				var t = float(i) / _debug_shapes.size()
				var color := initial_color.lerp(final_color, t)
				color.a = 0.1
				_debug_draw.draw_box_shape(sh.shape, sh.xform, color, false, true)
		final_shape = _debug_shapes[-1] if marker_fits else _debug_shapes[0]
		_debug_draw.draw_box_shape(final_shape.shape, final_shape.xform, final_color)
			
func _process(_delta):
	_draw_debug()
		
func _udpate_drag_overlay(enabled: bool, drop_allowed: bool):
	SttHelper.drag_cursor_updated.emit(enabled, drop_allowed)

func _start_drag():
	_dragging = true
	set_process(true)
	var root = EditorInterface.get_edited_scene_root()
	root.add_child(_debug_draw)
	EditorInterface.set_main_screen_editor("3D")
	_udpate_drag_overlay(true, false)

func _finish_drag(global_mouse_pos):
	var root = EditorInterface.get_edited_scene_root()
	root.remove_child(_debug_draw)
	set_process(false)
	_udpate_drag_overlay(false, false)
	_dragging = false
	SttHelper.drag_3d_preview_updated.emit(Transform3D.IDENTITY, false)
	var viewport := SttHelper.get_viewport_3d_under_mouse()
	var marker_xform_res := _find_marker_xform()
	if marker_xform_res[XFORM_KEY_VALID]:
		var marker_xform := marker_xform_res[XFORM_KEY_XFORM] as Transform3D
		var scene = EditorInterface.get_edited_scene_root().name
		dropped_marker.emit(marker_xform, task)
		
func _snap_to_axis(vector: Vector3) -> Vector3:
	var min_angle = 1000
	var result: Vector3

	# In case of 45 degree angles in XY or YZ planes, favour horizontal axes
	# by evaluating them first
	const dirs := [
		Vector3.LEFT,
		Vector3.RIGHT,
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.UP,
		Vector3.DOWN,
	]
	
	for dir in dirs:
		var angle = vector.angle_to(dir)
		
		const shortcut_angle = deg_to_rad(1)
		if angle < shortcut_angle:
			return dir
			
		if angle < min_angle:
			min_angle = angle
			result = dir
	return result

func _find_marker_xform() -> Dictionary:
	_debug_shapes.clear()
	var valid_marker_position = false
	var viewport := SttHelper.get_viewport_3d_under_mouse()
	if not is_instance_valid(viewport):
		return INVALID_XFORM
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	var mouse_pos := viewport.get_mouse_position()
	var camera := viewport.get_camera_3d()
	var raycast_result = _raycast(camera, mouse_pos)
	valid_marker_position = raycast_result.size() > 0
	if not valid_marker_position:
		var shape = BoxShape3D.new()
		shape.size = MARKER_SIZE
		var shape_xform = Transform3D.IDENTITY
		var shape_origin = camera.project_ray_origin(mouse_pos) + camera.project_ray_normal(mouse_pos) * 10 + Vector3(0, MARKER_SIZE.y * 0.5, 0)
		shape_xform.origin = shape_origin
		_debug_shapes.append(ShapeInfo.new(shape, shape_xform, false))
		return INVALID_XFORM
	var pos: Vector3 = raycast_result["position"]
	var normal: Vector3 = raycast_result["normal"]
	var half_marker_size = MARKER_SIZE * 0.5
	var snapped_normal = _snap_to_axis(normal)
	var offset_pos: Vector3 = pos + snapped_normal * half_marker_size + snapped_normal * INITIAL_SURFACE_OFFSET
	
	var marker_xform := Transform3D(Basis.IDENTITY, offset_pos)
	marker_xform = marker_xform.looking_at(camera.global_position, Vector3.UP, true)
	var marker_y := marker_xform.basis.get_euler().y
	var snapped_marker_y: float = round(marker_y / Y_ANGLE_SNAP_RAD) * Y_ANGLE_SNAP_RAD
	marker_xform.basis = Basis.from_euler(Vector3(0, snapped_marker_y, 0))
	
	var marker_xform_data = _find_marker_pos(camera.get_world_3d(), marker_xform, snapped_normal)
	if marker_xform_data[XFORM_KEY_VALID] == false:
		return INVALID_XFORM

	marker_xform = marker_xform_data[XFORM_KEY_XFORM] as Transform3D

	# correct origin position: maker prefab has origin at bottom, BoxShape3D at center
	var marker_origin_offset = Vector3(0, -MARKER_SIZE.y * 0.5, 0)
	
	marker_xform.origin = marker_xform.origin + marker_origin_offset
	return {XFORM_KEY_VALID: true, XFORM_KEY_XFORM: marker_xform}

func _raycast(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var world3d = camera.get_world_3d()
	if not is_instance_valid(world3d):
		return {}
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var space = world3d.direct_space_state;
	var ray := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray.hit_back_faces = false
	ray.hit_from_inside = false
	var raycast_result = world3d.direct_space_state.intersect_ray(ray)
	return raycast_result
	
func _find_marker_pos(world3d: World3D, original_xform: Transform3D, offset_dir: Vector3) -> Dictionary:
	if not is_instance_valid(world3d):
		return {}
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = MARKER_SIZE
	params.shape = shape
	var xform := Transform3D(original_xform)
	
	params.transform = xform
	
	# 1 step for initial test, other steps for testing again after each offset
	var iterations = 1 + MAX_SURFACE_OFFSET_STEPS
	
	var half_marker_size := MARKER_SIZE * 0.5
	for i in range(iterations): 
		var collisions = world3d.direct_space_state.intersect_shape(params, 1)
		var shape_info := ShapeInfo.new(shape, Transform3D(xform), false)
		_debug_shapes.append(shape_info)
		if collisions.size() == 0:
			# Found suitable space for marker
			shape_info.fit = true
			return {XFORM_KEY_VALID: true, XFORM_KEY_XFORM: xform}
		var next_iter_offset = offset_dir * SURFACE_OFFSET_STEP_SIZE
		var ray = PhysicsRayQueryParameters3D.new()
		ray.from = xform.origin - offset_dir * half_marker_size
		ray.to = xform.origin + offset_dir * half_marker_size + next_iter_offset
		var ray_res := world3d.direct_space_state.intersect_ray(ray)
		var is_wedged = ray_res.size() > 0
		if is_wedged:
			# marker could end up hidden inside another 3D object
			break
		xform.origin += next_iter_offset
		params.transform = xform
	# Could not find empty space for marker
	return INVALID_XFORM

func _input(event):
	if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
		):
			_pressed = event.pressed
			if _dragging and not _pressed:
				_finish_drag(event.global_position)
	elif (_dragging and event is InputEventMouseMotion):
		var marker_xform_res := INVALID_XFORM
		var _viewport_3d_under_mouse := SttHelper.get_viewport_3d_index_under_mouse()
		if _viewport_3d_under_mouse >= 0:
			marker_xform_res = _find_marker_xform()
		var valid_drop: bool = marker_xform_res[XFORM_KEY_VALID]
		var marker_xform = marker_xform_res[XFORM_KEY_XFORM]
		SttHelper.drag_3d_preview_updated.emit(valid_drop, marker_xform)
		_udpate_drag_overlay(true, valid_drop)
