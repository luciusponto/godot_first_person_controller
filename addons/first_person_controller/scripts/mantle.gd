extends Node

## Emitted on succesfully starting to mantle
signal starting_mantle(surface_point : Vector3, surface_normal : Vector3)

## Emitted when a surface is found but is too steep to mantle
signal steep_surface_detected(surface_point : Vector3, surface_normal : Vector3)

## Emitted when no surface is found
signal surface_not_found()

signal max_fall_speed_exceeded()

signal no_space_overhead(position: Vector3)

const height_check_epsilon: float = 0.01

@export var enabled: bool = true
@export_node_path("MovementController") var controller_path := NodePath("../")
@export var allow_grounded_mantle : bool = true
@export var arm_reach: float = 1
## Vertical shoulder distance from top of the head
@export var shoulder_dist: float = 0.45
## Depth of smallest climbable platform in the game. For a game made of 0.5m cubes, this would be 0.5.
@export var min_platform_depth: float = 0.5

## If falling faster than this, character will fail to grab ledge
@export var max_fall_speed: float = 15

## Max rays cast to find mantling surface. Should be roughly: 1 + idiv(arm_reach, min_platform_depth). E.g. arm_reach = 1, game made of 0.5m cubes, set this to 3
@export_range(1, 10) var max_surf_detection_rays: int = 2
## Rays cast to refine surface edge detection. If you want the edge detected with precision "p" (e.g. 0.05m), steps = ceil(log2(arm_reach/p))
@export_range(0, 20) var edge_detection_rays: int = 2

# now automatically calculated from shoulder position and arm length
#@export var max_mantling_height: float = 2

## TODO: Should be set higher than max step height. Future implementation could have higher level component automatically setting this from step height
@export var min_mantle_height: float = 0.45
@export var redundant_jump_height: float = 0.05
@export var redundant_collider_radius: float = 0.05
## Input repeat rate in milliseconds
@export var timeout_ms: int = 1000
@export_flags_3d_physics var collision_mask = 0xFFFFFFFF

@export var place_hit_point_debug_sphere: bool = false
@export var handsShape: CollisionShape3D

var _next_mantle_time: int = 0
var _surf_check_result = SurfaceCheckResult.new()
var _debug_mesh_hit_point_scene = preload("res://addons/first_person_controller/scenes/debug_ray_hit_point.tscn")
var _debug_mesh_hit_point_scene_discarded = preload("res://addons/first_person_controller/scenes/debug_ray_hit_point_red.tscn")
var _debug_mesh_hit_point_instance: Node3D
var _debug_spheres_discarded_points := []
var _debug_from: Vector3
var _debug_to: Vector3

@onready var _debug_draw = get_node_or_null("/root/LSDebugDraw") as LSDebugDraw
@onready var _controller: LS_MovementController = get_node(controller_path)
@onready var _head = get_node("../Head")
@onready var _body: CharacterBody3D = $".."
@onready var _body_RID: RID
var _motion_test_param := PhysicsTestMotionParameters3D.new()
var _motion_test_result := PhysicsTestMotionResult3D.new()

func _ready():
	place_hit_point_debug_sphere = place_hit_point_debug_sphere and OS.is_debug_build()
	if (_body):
		_body_RID = _body.get_rid()
		_motion_test_param.exclude_bodies = [_body_RID]
	else:
		printerr("mantle.gd: could not get character body rid")

# Called every physics tick. 'delta' is constant
func _physics_process(_delta: float) -> void:
	if enabled:
		var curr_time = Time.get_ticks_msec()
		if curr_time > _next_mantle_time and _can_mantle():
				var mantle_surface = _check_surface()
				if (mantle_surface.surface_found):
					_try_perform_mantle(mantle_surface, curr_time)
	
	
func _process(_delta):
	if enabled:
		if OS.is_debug_build() and _debug_draw:
			_debug_draw.draw_line(_debug_from, _debug_to, Color.BLUE, false, true)
			
	
func _try_perform_mantle(surface: SurfaceCheckResult, curr_time: int):
	_next_mantle_time = curr_time + timeout_ms
	var up: Vector3 = _controller.up_dir
	var vel: Vector3 = _controller.velocity
	var down_dot_vel: float = -up.dot(vel)
	print("Fall speed: " + str(down_dot_vel))
	if (down_dot_vel > 0 and down_dot_vel > max_fall_speed):
		max_fall_speed_exceeded.emit()
		print("Max fall speed exceeded: " + str(down_dot_vel))
	elif (surface.steep):
		# for animation, sound, vfx purposes
		steep_surface_detected.emit(surface.hit_point, surface.normal)
		print("Tried to mantle up steep surface")
	else:
		var max_slope_height: float = _controller.radius * tan(_controller.floor_max_angle)
		var slope_extra_height: float = max_slope_height * 1.1
		var jump_height = surface.jump_height + slope_extra_height
		var clamped_fall_speed = max(0, down_dot_vel)
		_controller.add_velocity(up * clamped_fall_speed)
		_controller.add_jump_velocity(jump_height + redundant_jump_height)
		starting_mantle.emit(surface.hit_point, surface.normal)
	_place_debug_sphere(surface.hit_point)
		
		
func _place_debug_sphere(position: Vector3, discarded: bool = false, scale: float = 1):
	if place_hit_point_debug_sphere:
		if discarded:
			var mesh = _debug_mesh_hit_point_scene_discarded.instantiate()
			get_tree().root.add_child(mesh)
			mesh.global_position = position
			_debug_spheres_discarded_points.append(mesh)
			(mesh as Node3D).scale = Vector3.ONE * scale
		else:
			if _debug_mesh_hit_point_instance == null:
				if _debug_mesh_hit_point_scene:
					_debug_mesh_hit_point_instance = _debug_mesh_hit_point_scene.instantiate()
					get_tree().root.add_child(_debug_mesh_hit_point_instance)
				else:
					print("debug sphere scene _debug_mesh_hit_point_scene not found")
					return
			_debug_mesh_hit_point_instance.global_position = position


func _can_mantle() -> bool:
	var airborne = not _controller.is_on_floor()
	var result = (
			Input.is_action_pressed(&"mantle")
			and (airborne or allow_grounded_mantle)
	)
	return result


func _check_surface() -> SurfaceCheckResult:
	# 0 - Optionally, to keep this cheaper, first test a shape intersection forward to see if there is even any surface in front of player at all, even if it is vertical with no ledge.
	# 	if not, fire a notification and return
	# Updated strategy: change to:
	# 1 - test collision shape motion up until it has reached the height corresponding to extended hands.
	#		if hit, stop and fire "overhead obstacle detected" signal.
	# 2 - Raycast to find surface as doing now.
	# 		if not hit, stop and send "no surface detected" signal
	# 3 - move smaller, "hands" collision shape, for arms up pos, to arms up and above surface
	#		treat as #1
	# 4 - perform another motion test down, to find jump height.
	# 5 - optionally, raycast or test shape for each hand to find better IK hand placement positions. 
	# TODO: the resulting jump height can be too small if the target surface is inclined in relation to the character facing direction. Solution is to use shape motion simulation to find the jump height.
	# TODO: algorythm is flimsy.
	# Should ensure that there is space for hands to reach ledge.
	# Should return closest position on top of ledge so IK hand placement looks good.
	# Change to:
	# 1 - Create shape to represent hands. E.g. cube[.3, .2, .2]
	# 2 - Simulate moving shape up from head height to max mantle height, stop when hit, then forward to max mantle distance, stop when hit, then down to lowest mantle height
	# 3 - If last simulated move hit, generate return data
	_surf_check_result.reset()
	for sphere in _debug_spheres_discarded_points:
		sphere.queue_free()
	_debug_spheres_discarded_points.clear()
	var foot_pos: Vector3 = _controller.get_foot_pos()
	var top_pos: Vector3 = _controller.get_top_pos()
	var controller_global_basis: Basis = _controller.global_transform.basis
	var controller_forward: Vector3 = -controller_global_basis.z
	var controller_up: Vector3 = controller_global_basis.y
	var shoulder_pos: Vector3 = top_pos - controller_up * shoulder_dist
	var top_reach: Vector3 = shoulder_pos + controller_up * arm_reach
	var initial_surface_detection_pos: Vector3 = top_reach + controller_forward * _controller.radius
	#var final_surface_detection_pos:Vector3 = initial_surface_detection_pos + controller_forward * arm_reach
	var lowest_mantle_pos: Vector3 = _controller.get_foot_pos() + controller_up * min_mantle_height
	const epsilon: float = 0.02
	var surf_detect_ray_length: float = (top_reach - lowest_mantle_pos).length() + epsilon
	const dont_hit_from_inside := false
	const hit_from_inside := true
	# try to find surface to mantle to
	for i in range(0, max_surf_detection_rays):
		var ray_origin: Vector3 = initial_surface_detection_pos + controller_forward * (float(i+1) / max_surf_detection_rays) * arm_reach
		var ray_end: Vector3 = ray_origin - controller_up * surf_detect_ray_length
		var raycast_result: Dictionary = FpcPhysicsUtil.raycast_from_to(_controller, ray_origin, ray_end, dont_hit_from_inside, collision_mask)
		if raycast_result:
			# check for overhead space
			var ray_param := PhysicsRayQueryParameters3D.new()
			ray_param.exclude = [_body_RID]
			ray_param.from = top_pos
			ray_param.to = top_reach
			ray_param.hit_from_inside = true
			ray_param.hit_back_faces = true
			var space_state: PhysicsDirectSpaceState3D = _controller.get_world_3d().direct_space_state
			var overhead_blocked_result: Dictionary = space_state.intersect_ray(ray_param)
			if overhead_blocked_result:
				no_space_overhead.emit(overhead_blocked_result["position"])
				print("Mantle: hand access blocked raycast")
				return _surf_check_result
			_motion_test_param.from = _body.transform
			_motion_test_param.motion = top_reach - top_pos
			var overhead_blocked: bool = PhysicsServer3D.body_test_motion(_body_RID, _motion_test_param, _motion_test_result)
			if overhead_blocked:
				no_space_overhead.emit(_motion_test_result.get_collision_point())
				print("Mantle: hand access blocked")
				return _surf_check_result
#			var blocked_access_test: Dictionary = FpcPhysicsUtil.raycast_from_to(_controller, top_reach, ray_origin, hit_from_inside, collision_mask)
#			_debug_from = top_reach
#			_debug_to = ray_origin
#			if blocked_access_test:
#				print("Mantle: hand access blocked")
#				return _surf_check_result
			var closest_hit: Dictionary = raycast_result
			var gap_length: float = (initial_surface_detection_pos - ray_origin).length()
			var interval_start: float = 0
			var interval_end: float = gap_length
			const min_debug_scale = 0.2
			_place_debug_sphere(raycast_result["position"], true, min_debug_scale)
			for j in range(0, edge_detection_rays):
				# binary search edge
				gap_length = gap_length * 0.5
				ray_origin = initial_surface_detection_pos + controller_forward * gap_length
				ray_end = ray_origin - controller_up * surf_detect_ray_length
				raycast_result = FpcPhysicsUtil.raycast_from_to(_controller, ray_origin, ray_end, dont_hit_from_inside, collision_mask)
				if raycast_result:
					var debug_scale = lerp(min_debug_scale, 1.0, float(j + 1)/edge_detection_rays)
					_place_debug_sphere(raycast_result["position"], true, debug_scale)
					print("j: " + str(j) + "; debug_scale: " + str(debug_scale))
					closest_hit = raycast_result
					interval_end = interval_end - gap_length
				else:
					interval_start = interval_start + gap_length
			_get_surf_data(closest_hit, _surf_check_result, foot_pos)
#			var shape_query_param = PhysicsShapeQueryParameters3D.new()
#			shape_query_param.
#			space_state.cast_motion()
			break
	return _surf_check_result
	
	
#func _run_check(from : Vector3, to : Vector3, check_result : SurfaceCheckResult, foot_pos : Vector3) -> bool:
#	var raycast_result = FpcPhysicsUtil.raycast_from_to(_controller, from, to, collision_mask)
#	if raycast_result:
#		_get_surf_data(raycast_result, check_result, foot_pos)
#		return true
#	return false


func _get_surf_data(raycast_result: Dictionary, check_result : SurfaceCheckResult, foot_pos : Vector3) -> void:
	if raycast_result:
		check_result.surface_found = true
		check_result.steep = _is_steep_surface(raycast_result.normal)
			# TODO: check if path to surface is blocked
		check_result.hit_point = raycast_result.position
		check_result.normal = raycast_result.normal
		check_result.jump_height = raycast_result.position.y - foot_pos.y

	
func _is_steep_surface(normal : Vector3) -> bool:
	var gravity = PhysicsServer3D.area_get_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR)
	return normal.angle_to(-gravity) >= _controller.floor_max_angle


class SurfaceCheckResult:
	var surface_found: bool
	var steep: bool
	var hit_point : Vector3
	var normal : Vector3
	var jump_height : float
	
	func reset():
		surface_found = false
	
	func _to_string():
		var result = ""
		for property in self.get_property_list():
			var name = property["name"]
			var value = self.get(name)
			result = result + name + ": " + str(value) + "; "
		return result
		
