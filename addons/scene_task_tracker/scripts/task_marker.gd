@tool
extends Node3D

# TODO: move these into plugin editor settings
const SURFACE_OFFSET: float = 1
const Y_ANGLE_SNAP_DEGREES = 90
const WALL_ANGLE = 45

var marker: Node3D

func _enter_tree():
	var top_level = not is_instance_valid(owner)
	if top_level:
		print("Instanced task marker")
	else:
		print("Task marker added to scene with owner %s" % [owner])
 
func _ready():
	_setup.call_deferred()

func _setup():
	var top_level = not is_instance_valid(owner)
	if top_level:
		print("Editing task marker")
	else:
		_create_marker.call_deferred()
		_self_delete.call_deferred()

func _self_delete():
	queue_free.call_deferred()
	
func _create_marker():
	marker = Node3D.new()
	add_child(marker)
	marker.global_position = global_position
	marker.global_rotation = global_rotation
	marker.reparent(get_parent())
	marker.owner = owner
	marker.name = "TaskMarker_000000"
	marker.add_to_group("task_markers", true)
	_try_to_position(marker)

	
func _get_viewport_3d_under_mouse() -> SubViewport:
	for i in range(4):
		var viewport := EditorInterface.get_editor_viewport_3d(i)
		var mouse_pos_viewport := viewport.get_mouse_position()
		var rect := viewport.get_visible_rect()
		if mouse_pos_viewport.x > 0 and mouse_pos_viewport.x <= rect.size.x and mouse_pos_viewport.y > 0 and mouse_pos_viewport.y <= rect.size.y:
			return viewport
	return null	
	
func _try_to_position(marker: Node3D):
	var viewport := _get_viewport_3d_under_mouse()
	if not is_instance_valid(viewport):
		return
	var world := viewport.find_world_3d()
	if not is_instance_valid(world):
		return
	var space_state := world.direct_space_state
	var mouse_pos = viewport.get_mouse_position()
	var camera = viewport.get_camera_3d()
	if not is_instance_valid(camera):
		return
	var from = camera.project_ray_origin(mouse_pos)
	const RAY_LENGTH = 100
	var to = from + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var ray := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [])
	ray.from = from
	ray.to = to
	var raycast_result := space_state.intersect_ray(ray)
	if raycast_result.size() == 0:
		return
	var pos: Vector3 = raycast_result["position"]
	var normal: Vector3 = raycast_result["normal"]
	var is_wall = abs(normal.dot(Vector3.UP)) <= cos(45)
	var offset_pos: Vector3 = pos + normal * SURFACE_OFFSET
	marker.global_position = offset_pos
	marker.look_at(camera.global_position, Vector3.UP, true)
	var marker_y = marker.global_rotation_degrees.y
	var snapped_marker_y = round(marker_y / 90) * 90
	print("Y: %f1; Snapped: %f2" % [marker_y, snapped_marker_y])
	marker.global_rotation_degrees = Vector3(0, snapped_marker_y, 0)
	
	
