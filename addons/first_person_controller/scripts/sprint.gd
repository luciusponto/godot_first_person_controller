extends "res://addons/first_person_controller/scripts/modifier_action.gd"

@export_node_path("LS_MovementController") var controller_path := NodePath("../")

@export_node_path("Node3D") var head_path := NodePath("../Head")

@export var sprint_speed_mult := 1.6
@export var fov_multiplier := 1.05


@onready var _controller: LS_MovementController = get_node(controller_path)
@onready var _head = get_node(head_path)
@onready var _cam: Camera3D = get_node(head_path).cam
@onready var _normal_speed: int = _controller.speed
@onready var _normal_fov: float = _cam.fov
@onready var _sprint_speed = _normal_speed * sprint_speed_mult


## Takes any actions needed when the modifier is switched on.
# Override superclass method
func _set_modifier_on():
	_controller.speed = floor(_sprint_speed)
	_head.set_fov(_normal_fov * fov_multiplier)


## Takes any actions needed when the modifier is switched off.
# Override superclass method
func _set_modifier_off():
	_controller.speed = _normal_speed
	_head.reset_fov()


## Performs any checks needed for the modifier to become or remain active.
## Returns true if the modifier can be active, false otherwise.
# Override superclass methods
func _can_apply_modifier() -> bool:
	return (_controller.is_on_floor()
		and _controller.input_axis.x >= 0.5)
