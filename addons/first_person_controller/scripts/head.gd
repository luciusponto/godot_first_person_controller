extends Node3D


@export_node_path("Camera3D") var cam_path := NodePath("Camera")

@export var mouse_sensitivity := 2.0
@export var y_limit := 90.0
@export_range(0.0, 1.0, 0.05) var fov_tween_time: float = 0.15
@export var fov_tween_ease := Tween.EASE_IN_OUT
@export var fov_tween_trans := Tween.TRANS_CUBIC
@export_range(0.0, 1.0, 0.01) var step_tween_time: float = 0.25

var mouse_axis := Vector2()
var rot := Vector3()
var fov_tween: Tween
var step_tween: Tween

@onready var cam: Camera3D = get_node(cam_path)
@onready var _normal_fov := cam.fov
var _step_smooth_data: FpcMathUtil.SmoothDampVector3Result = FpcMathUtil.SmoothDampVector3Result.new()
var _target_position = Vector3.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_sensitivity = mouse_sensitivity / 1000
	y_limit = deg_to_rad(y_limit)
	_step_smooth_data.velocity = Vector3.ZERO
	_target_position = position

# Called when there is an input event
func _input(event: InputEvent) -> void:
	# Mouse look (only if the mouse is captured).
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_axis = event.relative
		camera_rotation()


# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var joystick_axis := Input.get_vector(&"look_left", &"look_right",
			&"look_down", &"look_up")
	
	if joystick_axis != Vector2.ZERO:
		mouse_axis = joystick_axis * 1000.0 * delta
		camera_rotation()
		
		
func _process(delta):
	if (position - _target_position).length_squared() > 0.00001:
		position = FpcMathUtil.smooth_damp_Vector3(position, _target_position, step_tween_time, delta, _step_smooth_data)
	
	
func set_fov(new_fov: float) -> void:
	if fov_tween and fov_tween.is_running():
		fov_tween.kill()
	fov_tween = create_tween()
	fov_tween.tween_property(cam, "fov", new_fov, fov_tween_time).set_ease(fov_tween_ease).set_trans(fov_tween_trans)


func reset_fov() -> void:
	set_fov(_normal_fov)
	

func set_target_position
(target_local_pos: Vector3) -> void:
	_target_position = target_local_pos


func camera_rotation() -> void:
	# Horizontal mouse look.
	rot.y -= mouse_axis.x * mouse_sensitivity
	# Vertical mouse look.
	rot.x = clamp(rot.x - mouse_axis.y * mouse_sensitivity, -y_limit, y_limit)
	
	get_owner().rotation.y = rot.y
	rotation.x = rot.x
