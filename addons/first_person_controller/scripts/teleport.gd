extends Node

@export_node_path("MovementController") var controller_path := NodePath("../")
@export var max_distance = 500
@export var collision_mask : int = 0xFFFFFFFF
@export var height_offset = 2.0

var _action_mapped = false

@onready var _controller: LS_MovementController = get_node(controller_path)
@onready var _head : Node3D = get_node("../Head")

func _ready():
	_action_mapped = _is_action_mapped()
	if not OS.is_debug_build():
		call_deferred("queue_free")


# Called every physics tick. 'delta' is constant
func _physics_process(_delta: float) -> void:
	if _is_action_mapped() and Input.is_action_just_pressed(&"teleport"):
		const dont_hit_from_inside := false
		var raycast_result = FpcPhysicsUtil.raycast_forward(_head, max_distance, dont_hit_from_inside, collision_mask)
		if (raycast_result):
			_controller.velocity = Vector3.ZERO
			var hit_pos = raycast_result.get("position")
			var hit_normal = raycast_result.get("normal")
			var controller_global_basis = _controller.global_transform.basis
			_controller.global_position = hit_pos + controller_global_basis.y * height_offset # + hit_normal * _controller.radius * 1.05
			
	
func _is_action_mapped() -> bool:
	return InputMap.has_action(&"teleport")
