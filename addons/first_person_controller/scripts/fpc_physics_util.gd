extends Object

class_name FPC_Physics_Util

static func Raycast(requestor : Node3D, parameters : PhysicsRayQueryParameters3D) -> Dictionary:
	var space_state = requestor.get_world_3d().direct_space_state
	return space_state.intersect_ray(parameters)

static func RaycastFromTo(requestor : Node3D, from : Vector3, to : Vector3, mask : int = 0xFFFFFFFF) -> Dictionary:
	var parameters = PhysicsRayQueryParameters3D.create(from, to, mask)
	return Raycast(requestor, parameters)

static func RaycastForward(requestor : Node3D, distance : float = 100, mask : int = 0xFFFFFFFF) -> Dictionary:
	var global_forward = -requestor.global_transform.basis.z
	var from = requestor.global_position
	var to = from + global_forward * distance
	var parameters = PhysicsRayQueryParameters3D.create(from, to, mask)
	return Raycast(requestor, parameters)

