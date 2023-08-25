class_name FpcPhysicsUtil
extends Object


static func smooth_damp_unclamped(from, to, smooth_time: float, time_step: float, result: SmoothDampResult):
	# Adapted from template in Game Programming Gems 4, chapter 1.10
	# Represents critically damped spring-mass system
	var velocity = result.velocity
	var omega = 2.0 / maxf(0.001, smooth_time)
	var x = omega * time_step
	
	var exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change = from - to
	var temp = (velocity + omega * change) * time_step
	velocity = (velocity - omega * temp) * exp
	var new_pos = to + (change + temp) * exp
	
	result.velocity = velocity
	result.new_pos = new_pos
	return new_pos


static func smooth_damp_float(from: float, to: float, smooth_time: float, time_step: float, result: SmoothDampFloatResult) -> float:
	var velocity: float = result.velocity
	var omega: float = 2.0 / maxf(0.001, smooth_time)
	var x: float = omega * time_step
	var exp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = from - to
	var temp: float = (velocity + omega * change) * time_step
	velocity = (velocity - omega * temp) * exp
	var new_pos: float = to + (change + temp) * exp
	
	var new_pos_clamped := new_pos
	var actual_move: float = new_pos - from
	var overshot: bool = actual_move > change
	if overshot:
		new_pos_clamped = to
		velocity = change / time_step
	
	result.velocity = velocity
	result.new_pos = new_pos_clamped
	return new_pos
	
static func smooth_damp_Vector3(from: Vector3, to: Vector3, smooth_time: float, time_step: float, result: SmoothDampVector3Result) -> Vector3:
	var velocity: Vector3 = result.velocity
	var omega: float = 2.0 / maxf(0.001, smooth_time)
	var x: float = omega * time_step
	var exp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector3 = from - to
	var temp: Vector3 = (velocity + omega * change) * time_step
	velocity = (velocity - omega * temp) * exp
	var new_pos: Vector3 = to + (change + temp) * exp
	
	var new_pos_clamped := new_pos
	var actual_move_sqr_mag: float = (new_pos - from).length_squared()
	var change_sqr_mag: float = change.length_squared()
	var overshot: bool = actual_move_sqr_mag > change_sqr_mag
	if overshot:
		new_pos_clamped = to
		velocity = change / time_step
	
	result.velocity = velocity
	result.new_pos = new_pos_clamped
	return new_pos
	
static func _print_debug(values: Array) -> void:
	var result := ""
	for i in range(0, len(values)):
		if i % 2 == 0:
			result = result + "; " + values[i] + ": "
		else:
			result = result + str(values[i])
	print(result)

static func raycast(requestor : Node3D, parameters : PhysicsRayQueryParameters3D) -> Dictionary:
	var space_state = requestor.get_world_3d().direct_space_state
	return space_state.intersect_ray(parameters)

static func raycast_from_to(requestor : Node3D, from : Vector3, to : Vector3, mask : int = 0xFFFFFFFF) -> Dictionary:
	var parameters = PhysicsRayQueryParameters3D.create(from, to, mask)
	return raycast(requestor, parameters)

static func raycast_forward(requestor : Node3D, distance : float = 100, mask : int = 0xFFFFFFFF) -> Dictionary:
	var global_forward = -requestor.global_transform.basis.z
	var from = requestor.global_position
	var to = from + global_forward * distance
	var parameters = PhysicsRayQueryParameters3D.create(from, to, mask)
	return raycast(requestor, parameters)

static func intersect_shape_2(requestor: Node3D, shape: Shape3D, position: Vector3, mask : int = 0xFFFFFFFF) -> Dictionary:
	var parameters = PhysicsShapeQueryParameters3D.new()	
	parameters.shape = shape
	var space_state = requestor.get_world_3d().direct_space_state
	return space_state.get_rest_info(parameters)

static func intersect_box(requestor: Node3D, pos: Vector3, size: Vector3, exclusions: Array[RID], collide_with_areas : bool = true, mask : int = 0xFFFFFFFF) -> Dictionary:
	var shape = BoxShape3D.new()
	shape.size = size
	var parameters := PhysicsShapeQueryParameters3D.new()	
	parameters.shape = shape
	parameters.transform = Transform3D.IDENTITY.translated(pos)
	parameters.collide_with_areas = collide_with_areas
	parameters.collision_mask = mask
	parameters.exclude = exclusions
	PhysicsServer3D
	var space_state = requestor.get_world_3d().direct_space_state
	return space_state.get_rest_info(parameters)	
	
static func intersect_shape(requestor: Node3D, collision: CollisionShape3D, collide_with_areas : bool = true, mask : int = 0xFFFFFFFF) -> Dictionary:
	var parameters := PhysicsShapeQueryParameters3D.new()	
	parameters.shape = collision.shape
	parameters.transform = collision.transform
	parameters.collide_with_areas = collide_with_areas
	parameters.collision_mask = mask
	parameters.margin = collision.shape.margin
	var space_state = requestor.get_world_3d().direct_space_state
	return space_state.get_rest_info(parameters)	
	var result: Array[Dictionary] = space_state.intersect_shape(parameters, 1)
	if not result.is_empty():
		return result[0]
	else:
		return {}
		

class SmoothDampResult:
	var new_pos
	var velocity
	
class SmoothDampFloatResult:
	var new_pos: float
	var velocity: float
	
class SmoothDampVector3Result:
	var new_pos: Vector3
	var velocity: Vector3
