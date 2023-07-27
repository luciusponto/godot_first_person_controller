extends Node

@export_node_path("MovementController") var controller_path := NodePath("../")
@export var max_distance = 500
@export var collision_mask : int = 0xFFFFFFFF
@export var height_offset = 2.0

@onready var controller: MovementController = get_node(controller_path)
@onready var head : Node3D = get_node("../Head")
var action_mapped = false

func _ready():
	action_mapped = is_action_mapped()
	print("Teleport mapped: " + str(action_mapped))
	
func is_action_mapped() -> bool:
	return InputMap.has_action(&"teleport")

# Called every physics tick. 'delta' is constant
func _physics_process(_delta: float) -> void:
	if is_action_mapped() and Input.is_action_just_pressed(&"teleport"):
		var raycast_result = FPC_Physics_Util.RaycastForward(head, max_distance, collision_mask)
		if (raycast_result):
			controller.velocity = Vector3.ZERO
			var hit_pos = raycast_result.get("position")
			var hit_normal = raycast_result.get("normal")
			var controller_global_basis = controller.global_transform.basis
			controller.global_position = hit_pos + controller_global_basis.y * height_offset # + hit_normal * controller.radius * 1.05
			
