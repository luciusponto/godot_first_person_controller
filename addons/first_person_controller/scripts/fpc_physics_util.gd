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
		
		
static func get_position(collisionResults: Dictionary):
	return collisionResults["position"]
	
static func get_normal(collisionResults: Dictionary):
	return collisionResults["normal"]

