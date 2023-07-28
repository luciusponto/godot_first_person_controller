extends Node

@export_node_path("MovementController") var controller_path := NodePath("../")
@export var allow_grounded_mantle : bool = false
@export var arm_reach: float = 1
@export var max_mantling_height: float = 2
@onready var controller: MovementController = get_node(controller_path)
@onready var head = get_node("../Head")

const height_check_epsilon: float = 0.01

var next_mantle_time: int = 0
@export var redundant_jump_height: float = 0.05
@export var redundant_collider_radius: float = 0.05
@export var timeout: int = 500
@export_flags_3d_physics var collision_mask = 0xFFFFFFFF

## Emitted on succesfully starting to mantle
signal starting_mantle(surface_point : Vector3, surface_normal : Vector3)

## Emitted when a surface is found but is too steep to mantle
signal steep_surface_detected(surface_point : Vector3, surface_normal : Vector3)

## Emitted when no surface is found
signal surface_not_found()

class SurfaceCheckResult:
	var surface_found: bool
	var steep: bool
	var hit_point : Vector3
	var normal : Vector3
	var jump_height : float

# Called every physics tick. 'delta' is constant
func _physics_process(_delta: float) -> void:
	var curr_time = Time.get_ticks_msec()
	if curr_time > next_mantle_time and can_mantle():
			next_mantle_time = curr_time + timeout
			var mantle_surface = check_surface()
			if (mantle_surface.steep):
				steep_surface_detected.emit(mantle_surface.hit_point, mantle_surface.normal)
			elif (mantle_surface.surface_found):
				var jump_height = mantle_surface.jump_height
				controller.add_jump_velocity(jump_height + redundant_jump_height)
				starting_mantle.emit(mantle_surface.hit_point, mantle_surface.normal)

func can_mantle() -> bool:
	var airborne = not controller.is_on_floor()
	return (
			Input.is_action_pressed(&"mantle")
			and (airborne or allow_grounded_mantle)
	)

func check_surface() -> SurfaceCheckResult:
	var check_result := SurfaceCheckResult.new()
	check_result.surface_found = false
	var foot_pos = controller.get_foot_pos()
	var controller_global_basis = controller.global_transform.basis
	var controller_forward = -controller_global_basis.z
	var controller_up = controller_global_basis.y
	var ray_origin_above_head = foot_pos + controller_up * (max_mantling_height + height_check_epsilon)
	var ray_origin = ray_origin_above_head + controller_forward * (controller.radius + arm_reach)
	var ray_end = Vector3(ray_origin.x, foot_pos.y, ray_origin.z)
	var raycast_result = FPC_Physics_Util.RaycastFromTo(controller, ray_origin, ray_end, collision_mask)
	var has_hit = run_check(ray_origin, ray_end, check_result, foot_pos)
	if not has_hit:	
		ray_origin = ray_origin_above_head + controller_forward * (controller.radius + redundant_collider_radius)
		has_hit = run_check(ray_origin, ray_end, check_result, foot_pos)
	return check_result

func run_check(from : Vector3, to : Vector3, check_result : SurfaceCheckResult, foot_pos : Vector3) -> bool:
	var raycast_result = FPC_Physics_Util.RaycastFromTo(controller, from, to, collision_mask)
	if raycast_result:
		check_result.surface_found = true
		check_result.steep = is_steep_surface(raycast_result.normal)
			# TODO: check if path to surface is blocked
		check_result.hit_point = raycast_result.position
		check_result.normal = raycast_result.normal
		check_result.jump_height = raycast_result.position.y - foot_pos.y
		return true
	return false
	
func is_steep_surface(normal : Vector3) -> bool:
	var gravity = PhysicsServer3D.area_get_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR)
	return normal.angle_to(-gravity) >= controller.floor_max_angle
	
