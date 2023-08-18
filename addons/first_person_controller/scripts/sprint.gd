extends Node

@export_node_path("MovementController") var controller_path := NodePath("../")

@export_node_path("Node3D") var head_path := NodePath("../Head")

@export var sprint_speed_mult := 1.6
@export var fov_multiplier := 1.05
@export var toggle_sprint = false

var _sprint_input_on := false
var _is_sprinting := false

@onready var _controller: MovementController = get_node(controller_path)
@onready var _head = get_node(head_path)
@onready var _cam: Camera3D = get_node(head_path).cam
@onready var _normal_speed: int = _controller.speed
@onready var _normal_fov: float = _cam.fov
@onready var _sprint_speed = _normal_speed * sprint_speed_mult

# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var prev_state := _is_sprinting
	_is_sprinting = _can_sprint()
	if (prev_state != _is_sprinting):
		_handle_state_change()


func _handle_state_change():
	if _is_sprinting:
		_controller.speed = floor(_sprint_speed)
		_head.set_fov(_normal_fov * fov_multiplier)
	else:
		_controller.speed = _normal_speed
		_head.reset_fov()
	

func _unhandled_input(event):
	if toggle_sprint and event.is_action_pressed(&"sprint"):
		_sprint_input_on = not _sprint_input_on


func _can_sprint() -> bool:
	return (_controller.is_on_floor()
		and (Input.is_action_pressed(&"sprint") or _sprint_input_on)
		and _controller.input_axis.x >= 0.5)
