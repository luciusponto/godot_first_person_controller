class_name FpcPhysicsUtil
extends Object


static func raycast(requestor : Node3D, parameters : PhysicsRayQueryParameters3D) -> Dictionary:
	var space_state = requestor.get_world_3d().direct_space_state
	return space_state.intersect_ray(parameters)


static func raycast_from_to(requestor : Node3D, from : Vector3, to : Vector3, hit_from_inside: bool = false, mask : int = 0xFFFFFFFF) -> Dictionary:
	var parameters = _create_param(from, to, hit_from_inside, mask)
	return raycast(requestor, parameters)


static func raycast_forward(requestor : Node3D, distance : float = 100, hit_from_inside: bool = false, mask : int = 0xFFFFFFFF) -> Dictionary:
	var global_forward = -requestor.global_transform.basis.z
	var from = requestor.global_position
	var to = from + global_forward * distance
	var parameters = _create_param(from, to, hit_from_inside, mask)
	return raycast(requestor, parameters)
	

static func _create_param(from: Vector3, to: Vector3, hit_from_inside: bool, mask: int) -> PhysicsRayQueryParameters3D:
	var param = PhysicsRayQueryParameters3D.new()
	param.from = from
	param.to = to
	param.collision_mask = mask
	param.hit_from_inside = hit_from_inside
	param.hit_back_faces = hit_from_inside
	return param




