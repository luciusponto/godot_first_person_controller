class_name FpcPhysicsUtil
extends Object

#float SmoothCD(float from, 
#float to, 
#float &vel, 
#float smoothTime) 
#
#{ 
#
#float omega = 2.f/smoothTime; 
#float x = omega*timeDelta; 
#
#float exp = 1 .f/(1 ,f+x+0.48f*x*x+0.235f*x*x*x); 
#float change = from - to; 
#float temp = (vel+omega*change)*timeDelta; 
#vel = (vel - omega*temp)*exp; // Equation 5 
#return to + (change+temp)*exp; // Equation 4 
#
#} 

# Adapted from Game Programming Gems 4, chapter 1.10
static func smooth_damp(from, to, smooth_time: float, time_step: float, result: SmoothDampResult):
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

static func smooth_damp_Vector3(from: Vector3, to: Vector3, smooth_time: float, time_step: float, result: SmoothDampVector3Result) -> Vector3:
	var velocity_x: float = result.velocity.x
	var velocity_y: float = result.velocity.y
	var velocity_z: float = result.velocity.z
	var omega: float = 2.0 / maxf(0.001, smooth_time)
	var x: float = omega * time_step
	
	var exp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector3 = from - to
	var change_x: float = change.x
	var change_y: float = change.y
	var change_z: float = change.z
#	var temp = (velocity + omega * change) * time_step
	var temp_x: float = (velocity_x + omega * change_x) * time_step
	var temp_y: float = (velocity_y + omega * change_y) * time_step
	var temp_z: float = (velocity_z + omega * change_z) * time_step
#	velocity = (velocity - omega * temp) * exp
	velocity_x = (velocity_x - omega * temp_x) * exp
	velocity_y = (velocity_y - omega * temp_y) * exp
	velocity_z = (velocity_z - omega * temp_z) * exp
#	var new_pos = to + (change + temp) * exp
	var new_pos_x: float = to.x + (change_x + temp_x) * exp
	var new_pos_y: float = to.y + (change_y + temp_y) * exp
	var new_pos_z: float = to.z + (change_z + temp_z) * exp
	
	var new_pos := Vector3(new_pos_x, new_pos_y, new_pos_z)
	var new_pos_clamped := new_pos
	var actual_move_sqr_mag: float = (new_pos - from).length_squared()
	var change_sqr_mag: float = change.length_squared()
	var velocity := Vector3(velocity_x, velocity_y, velocity_z)
	var clamped := false
	if actual_move_sqr_mag > change_sqr_mag:
		new_pos_clamped = to
		velocity = change / time_step
		clamped = true
	
	var temp = Vector3(temp_x, temp_y, temp_z)
#	_print_debug(["from", from, "to", to, "new pos", new_pos, "vel", velocity, "change", change, "temp", temp, "time step", time_step, "smooth time", smooth_time, "omega", omega, "x", x, "exp", exp, "clamped", clamped])
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
	
class SmoothDampVector3Result:
	var new_pos: Vector3
	var velocity: Vector3
