extends Node

const raycast_down_distance_multiplier := 1.1

@export_node_path("MovementController") var controller_path := NodePath("../")
@export_node_path("Node3D") var head_path := NodePath("../Head")

@export var walk_speed_mult := 0.25
@export var fall_protection_enabled := true
@export var fall_protection_accel_mult := 10
@export var fov_multiplier := 1.05
@export var toggle_walk := false
## Magnitude in meters of vertical offset added to character _controller position to determine the raycast "from" position
@export var raycast_up_offset_dist := 0.1
## Magnitude in meters of horizontal offset added to character _controller position to determine the raycast "from" position in the fallback ground test
@export var raycast_forward_offset_dist := 0.5

var _walk_on = false
var _raycast_down_distance: float
var _intended_move_direction: Vector3

@onready var _controller: LS_MovementController = get_node(controller_path)
@onready var _cam: Camera3D = get_node(head_path).cam
@onready var _normal_speed: int = _controller.speed
@onready var _normal_accel: int = _controller.acceleration
@onready var _normal_fov: float = _cam.fov
@onready var _walk_speed := _normal_speed * walk_speed_mult
@onready var _fall_protection_accel := _normal_accel * fall_protection_accel_mult

func _ready():
	var max_vert_slope_distance = cos(_controller.floor_max_angle) * raycast_forward_offset_dist
	_raycast_down_distance = max_vert_slope_distance * raycast_down_distance_multiplier

# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	_intended_move_direction = _controller.direction.normalized()
	if _is_walking_enabled():
		_cam.set_fov(_normal_fov)
		if fall_protection_enabled and _about_to_fall():
			_controller.speed = 0
			_controller.acceleration = _fall_protection_accel
		else:
			_controller.speed = floor(_walk_speed)
			_controller.acceleration = _normal_accel
	else:
		_controller.speed = _normal_speed
		_controller.acceleration = _normal_accel

func _unhandled_input(event):
	if toggle_walk and event.is_action_pressed(&"walk"):
		_walk_on = not _walk_on

func _is_walking_enabled() -> bool:
	const min_move_speed_sq = 0.1 * 0.1
	return (_controller.is_on_floor() and (Input.is_action_pressed(&"walk") or _walk_on)
			and _controller.direction.length_squared() >= min_move_speed_sq)

func _is_ground_ahead(fwd_offset: Vector3, up_dir: Vector3) -> bool:
	var from: Vector3 = _controller.global_position + fwd_offset + up_dir * raycast_up_offset_dist
	var to: Vector3 = from - up_dir * (raycast_up_offset_dist + _raycast_down_distance)
	var result := FpcPhysicsUtil.raycast_from_to(_controller, from, to, false, _controller.collision_mask)
	if result.is_empty():
		return false
	var normal: Vector3 = result["normal"]
	var up_angle: Vector3 = -_controller.gravity_dir
	if normal.angle_to(up_dir) >= _controller.floor_max_angle * 0.99:
		return false
	return true

func _about_to_fall() -> bool:
	var up_dir: Vector3 = -_controller.gravity_dir
	
	# First test, raycasting from character position
	var fwd_offset := Vector3.ZERO
	if _is_ground_ahead(fwd_offset, up_dir):
		return false
		
	# Second test, raycasting a little bit in front of character, in case
	# character is dangling over edge with its center beyond the edge but its
	# its front pointed towards firm ground
	var fwd_dir: Vector3 = _controller.direction.normalized()
	fwd_offset = fwd_dir * raycast_forward_offset_dist
	if _is_ground_ahead(fwd_offset, up_dir):
		return false
		
	return true
	
