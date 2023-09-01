extends CharacterBody3D
class_name LS_MovementController

const degrees_epsilon = 0.01

enum CoyoteTimeType {
	TIME,
	DISTANCE,
	BOTH,
	NONE
}
	

@export var gravity_multiplier := 3.0
@export var speed := 10
@export var acceleration := 8
@export var deceleration := 10
@export_range(0.0, 1.0, 0.05) var air_control := 0.3
@export var jump_height: float = 2
@export var max_step_height: float = 0.3
## reach max_step_height with this number of increments. 1 for max efficiency, higher numbers to increase chance of finding a step if headroom is very small.
@export var step_height_calc_steps: int = 1
@export var max_step_normal_to_up_degrees: float = 1.0
@export var step_detection_raycast_offset: float = 0.1
@export var jump_timeout_sec: float = 0.5

## Only jump when just pressed if true. If false, keep jumping while jump key held down.
@export var jump_on_just_pressed = true
## Maximum wall angle in degrees against which jumps are possible. If less than 90, will jump while sliding down a steep slope, but not against vertical or overhanging walls.
@export_range(0, 180) var jump_max_wall_angle_deg = 89.0
## Max angle in degrees between vertical/overhanging wall and forward vector of character that allows a wall jump. Lower values require the character to better face the wall against which they wish to jump.
@export_range(0, 180) var vert_wall_jump_max_facing_angle = 120
## If true, the character velocity will be set to zero before adding the jump velocity.
@export var wall_jump_reset_velocity = true

## Blend velocity direction between world up (-gravity direction) and wall normal. 0 is full up, 1 is full wall normal. 
@export_range(0, 1, 0.001) var wall_jump_normal_influence = 1.0
@export var height: float = 1.8
@export var radius: float = 0.3
@export var head_offset: float = 0.25
## Jump assist type when characte is just starting to fall
@export var coyote_time_type := CoyoteTimeType.NONE
## time in milliseconds when coyote_time_type is TIME. 
@export var coyote_time_millisec: int = 100
## distance in meters when coyote_time_type is DISTANCE. A value like the character radius can be a good starting point.
@export var coyote_time_meters: float = 0.3
@export var draw_debug_gizmos = false

var direction := Vector3()
var input_axis := Vector2()

var _was_on_floor := false
var _fall_start_position: Vector3
var _fall_start_time_ms: int
var _head_local_pos: Vector3

# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
@onready var gravity: float = (ProjectSettings.get_setting("physics/3d/default_gravity") 
		* gravity_multiplier)
@onready var foot_offset: float = height / 2
@onready var gravity_dir: Vector3 = (ProjectSettings.get_setting("physics/3d/default_gravity_vector"))
@onready var up_dir: Vector3 = -gravity_dir
@onready var head := get_node("Head")
@onready var _debug_draw = get_node_or_null("/root/LSDebugDraw") as LSDebugDraw
@onready var _next_jump_time: float = Time.get_ticks_msec()
@onready var _collision_n = get_node("Collision") as CollisionShape3D


var collision_shape: CollisionShape3D


var last_jump_pos: Vector3
var last_jump_initial_v: Vector3
var last_jump_dir: Vector3
var last_jump_proj_v: Vector3
var last_jump_remaining_v: Vector3
var last_jump_added_v: Vector3
var can_walk: bool = true

# to reflect crouching / standing status
var _effective_height

var _collision_exclusions: Array[RID]

var _debug_step_test_shape: Shape3D
var _debug_step_test_shape_height: float
var _debug_step_test_shape_radius: float
var _debug_step_test_shape_center: Vector3
var _debug_box_shape_stack: Array[BoxShapeInfo]
#var _debug_box_stack: Array[BoxInfo]


func _ready():
	_set_up_collision()
	_was_on_floor = false
	_effective_height = height
	_collision_exclusions.push_back(get_rid())
	
	
func _process(_delta):
	if draw_debug_gizmos and _debug_draw != null:
		_debug_queue_collider_draw()		
		_draw_debug_lines()	
	
	
	# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	input_axis = Input.get_vector(&"move_back", &"move_forward",
			&"move_left", &"move_right")
	
	# TODO: replace below line with having extra node as head parent, placed where equation below shows
	# then, when climbing stairs smooth the head child
	# But still have the logic below enabled to move the head parent. It will be needed when crouch is implemented.
	_head_local_pos = Vector3(0, height - head_offset, 0)
			
	_direction_input()
	
	var now = Time.get_ticks_msec()
	
	var on_floor_now = is_on_floor()
	
	if on_floor_now:
		_was_on_floor = true
	elif _was_on_floor:
		_was_on_floor = false
		_fall_start_position = global_position
		_fall_start_time_ms = now

	var starting_jump = _jump_input() and _try_jump(now, on_floor_now)
	if not on_floor_now and not starting_jump:
		velocity.y -= gravity * delta
	
	_accelerate(delta)

	# TODO: refactor below into its own function
	# TODO: disable automatic snapping and implement custom one with camera tweening
	var expected_motion := velocity * delta
	var excluded_bodies: Array[RID] = []
	var is_moving: bool = velocity.length_squared() > 0.001
	var target_local_head_pos = _head_local_pos
	if on_floor_now and is_moving and _obstacle_detected(global_transform, expected_motion, excluded_bodies, null):
		# Collision about to happen. Determining if it is a step
		var step_result := WalkableStepData.new()
		if _is_walkable_step(expected_motion, max_step_height, step_height_calc_steps, step_result):
			var step_height: float = step_result.height
			var displacement = up_dir * step_height
			global_position = global_position + displacement
			head.position = head.position - displacement
	head.set_target_position(target_local_head_pos)
			
	move_and_slide()
	

func _debug_queue_collider_draw() -> void:
	_debug_box_shape_stack.clear()
	var axis_aligned = BoxShapeInfo.new(_collision_n.shape as BoxShape3D, _collision_n.global_transform, Color.BLUE)
	_debug_box_shape_stack.push_back(axis_aligned)
	axis_aligned = BoxShapeInfo.new(_collision_n.shape as BoxShape3D, Transform3D.IDENTITY.translated(_collision_n.global_position), Color.RED)
	_debug_box_shape_stack.push_back(axis_aligned)


func _is_walkable_step(motion: Vector3, max_step_height: float, calc_steps: int = 1, result: WalkableStepData = null) -> bool:
	const epsilon: float = 0.001
	for i in range(calc_steps, 0, -1):
		var step_height := max_step_height * (float(i) / calc_steps)
		var from: Transform3D = global_transform
		var up_motion: Vector3 = up_dir * step_height
		# if character can go up without hitting head
		if not _obstacle_detected(from, up_motion):
			step_height = max_step_height * (float(i) / calc_steps)
			from = global_transform.translated(up_motion)
			# if character can then execute the motion without hitting anything
			if not _obstacle_detected(from, motion):
				var high_from = from.translated(motion)
				var down_motion = -up_dir * step_height
				var res := PhysicsTestMotionResult3D.new()
				# if there is a step underneath character after teleporting up and executing motion
				if _obstacle_detected(high_from, down_motion, [], res):
					var normal := res.get_collision_normal()
					var angle := rad_to_deg(normal.angle_to(up_dir))
					var angle_ok: bool = angle <= max_step_normal_to_up_degrees
					var remainder = res.get_remainder()
					if angle_ok:
						if result:
							result.normal = normal
							result.height = remainder.length()
						return true
	return false


func _obstacle_detected(from: Transform3D, motion: Vector3, excl_bodies: Array[RID] = [], results: PhysicsTestMotionResult3D = null) -> bool:
	var param = PhysicsTestMotionParameters3D.new()
	param.from = from
	param.motion = motion
	param.exclude_bodies = excl_bodies
	return PhysicsServer3D.body_test_motion(get_rid(), param, results)


func _set_up_collision() -> void:
	var collision = get_node("Collision")
	if collision is CollisionShape3D:
		var shape = collision.shape
		if shape is CapsuleShape3D:
			var capsule = shape as CapsuleShape3D
			capsule.height = height
			capsule.radius = radius
			collision.position = Vector3(0, height / 2, 0)
	else:
		push_error("Could not find Collision node with a capsule shape")


func _is_coyote_time(now: int) -> bool:
	var time_diff = now - _fall_start_time_ms
	var result = time_diff <= coyote_time_millisec
	return result
	
	
func _is_coyote_distance() -> bool:
	var result = _fall_start_position.distance_squared_to(global_position) <= coyote_time_meters * coyote_time_meters
	return result
	
	
func _is_on_floor_coyote(now: int, on_floor_now: bool) -> bool:
	if on_floor_now:
		return true
	match coyote_time_type:
		CoyoteTimeType.TIME:
			return _is_coyote_time(now)
		CoyoteTimeType.DISTANCE:
			return _is_coyote_distance()
		CoyoteTimeType.BOTH:
			return _is_coyote_time(now) or _is_coyote_distance()
		CoyoteTimeType.NONE:
			pass
	return false
	
func _jump_input() -> bool:
	var pressed = false
	if jump_on_just_pressed:
		if Input.is_action_just_pressed(&"jump"):
			pressed = true
	elif Input.is_action_pressed(&"jump"):
		pressed = true
	var now = Time.get_ticks_msec()
	if now >= _next_jump_time and pressed:
		return true
	return false


func _try_jump(now: int, on_floor_now: bool) -> bool:
	if _is_on_floor_coyote(now, on_floor_now):
		add_jump_velocity(jump_height)
	elif is_on_wall() and _wall_jumpable():
		add_jump_velocity(jump_height, true)
	else:
		return false
	_next_jump_time = now + jump_timeout_sec * 1000
	return true
	
	
func add_velocity(to_add: Vector3) -> void:
	velocity = velocity + to_add
	
	
func add_jump_velocity(jump_height: float, is_wall_jump: bool = false) -> void:
	var initial_v : Vector3 = get_real_velocity()
	var v : Vector3 = initial_v
	var jump_dir = up_dir
	var jump_speed = sqrt(2 * jump_height * gravity)
	
	if (is_wall_jump):
		if (wall_jump_reset_velocity):
			v = Vector3.ZERO
		var wall_normal = get_wall_normal()
		jump_dir = up_dir.lerp(wall_normal, wall_jump_normal_influence)
		
	var proj_v = v.project(jump_dir)
	var non_jump_dir_v = v - proj_v
	var jump_vel = 	jump_speed * jump_dir
	v = non_jump_dir_v + jump_vel
	velocity = v
	
	# debug info
	if draw_debug_gizmos:
		last_jump_pos = global_position
		last_jump_dir = jump_dir
		last_jump_initial_v = initial_v
		last_jump_remaining_v = non_jump_dir_v
		last_jump_proj_v = proj_v
		last_jump_added_v = jump_vel
	
	
func _wall_jumpable():
	# true if wall not too steep and, if wall is overhanging, facing angle not too big
	var wall_normal = get_wall_normal()
	var wall_angle = wall_normal.angle_to(up_dir)
	var wall_angle_deg = rad_to_deg(wall_angle)
	var angle_allowed = wall_angle_deg < (jump_max_wall_angle_deg + degrees_epsilon)
	var not_overhanging = wall_angle <= 89.9
	var facing_angle_allowed = (not_overhanging or _wall_facing_angle(wall_normal) <= vert_wall_jump_max_facing_angle)
	var jumpable = angle_allowed and facing_angle_allowed
	return jumpable


func _wall_facing_angle(wall_normal_vector : Vector3) -> float:
	var facing_away_dir = global_transform.basis.z
	return wall_normal_vector.angle_to(facing_away_dir)


func _direction_input() -> void:
	direction = Vector3()
	var aim: Basis = get_global_transform().basis
	direction = aim.z * -input_axis.x + aim.x * input_axis.y


func _accelerate(delta: float) -> void:
	if not can_walk:
		velocity.x = 0
		velocity.z = 0
		return
	
	# Using only the horizontal velocity, interpolate towards the input.
	var temp_vel := velocity
	temp_vel.y = 0
	
	var temp_accel: float
	var target: Vector3 = direction * speed
	
	if direction.dot(temp_vel) > 0:
		temp_accel = acceleration
	else:
		temp_accel = deceleration
	
	if not is_on_floor():
		temp_accel *= air_control
	
	temp_vel = temp_vel.lerp(target, temp_accel * delta)
	
	velocity.x = temp_vel.x
	velocity.z = temp_vel.z
	
	
func get_foot_pos() -> Vector3:
	return global_position
	
	
func get_top_pos() -> Vector3:
	return get_foot_pos() + Vector3(0, _effective_height, 0)
	
	
func _draw_debug_lines():
	const scale = 0.1
	const pos_offset_per_iter = Vector3(0.02, 0, 0.02)
	var lines = ([
					[last_jump_initial_v, Color.MAGENTA],
					[last_jump_remaining_v, Color.GREEN_YELLOW],
					[last_jump_added_v, Color.AQUA],
					[last_jump_proj_v, Color.FIREBRICK]
				])
	var pos = last_jump_pos
	for line in lines:
		var offset = line[0]
		var color = line[1]
		_debug_draw.overlay_line(pos, pos + offset * scale, color)
		pos = pos + pos_offset_per_iter
	for box in _debug_box_shape_stack:	
		_debug_draw.draw_box_shape(box.shape, box.transf3d, box.color, false, false)

class BoxShapeInfo:
	var shape: BoxShape3D	
	var transf3d: Transform3D
	var color: Color
	
	func _init(shape: BoxShape3D, transf3d: Transform3D, color: Color) -> void:
		self.shape = shape
		self.transf3d = transf3d
		self.color = color
	
class BoxInfo:
	var size: Vector3	
	var pos: Vector3
	var color: Color
	
	func _init(pos: Vector3, size: Vector3, color: Color) -> void:
		self.pos = pos
		self.size = size
		self.color = color
	
class WalkableStepData:
	var normal: Vector3
	var height: float
