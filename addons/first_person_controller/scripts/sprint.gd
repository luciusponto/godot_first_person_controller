extends Node

@export_node_path("MovementController") var controller_path := NodePath("../")

@export_node_path("Node3D") var head_path := NodePath("../Head")

@export var sprint_speed_mult := 1.6
@export var fov_multiplier := 1.05
@export var toggle_sprint = false

var _sprint_on = false

@onready var _controller: MovementController = get_node(controller_path)
@onready var _cam: Camera3D = get_node(head_path).cam
@onready var _normal_speed: int = _controller.speed
@onready var _normal_fov: float = _cam.fov
@onready var _sprint_speed = _normal_speed * sprint_speed_mult

# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	if _can_sprint():
		_controller.speed = floor(_sprint_speed)
		_cam.set_fov(lerp(_cam.fov, _normal_fov * fov_multiplier, delta * 8))
	else:
		_controller.speed = _normal_speed
		_cam.set_fov(lerp(_cam.fov, _normal_fov, delta * 8))


func _unhandled_input(event):
	if toggle_sprint and event.is_action_pressed("sprint"):
		_sprint_on = not _sprint_on


func _can_sprint() -> bool:
	return (_controller.is_on_floor() and (Input.is_action_pressed(&"sprint") or _sprint_on)
			and _controller.input_axis.x >= 0.5)
