extends CharacterBody3D
class_name LS_MovementController

const degrees_epsilon := 0.01

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
@export var jump_on_just_pressed := true
## Maximum wall angle in degrees against which jumps are possible. If less than 90, will jump while sliding down a steep slope, but not against vertical or overhanging walls.
@export_range(0, 180) var jump_max_wall_angle_deg = 89.0
## Max angle in degrees between vertical/overhanging wall and forward vector of character that allows a wall jump. Lower values require the character to better face the wall against which they wish to jump.
@export_range(0, 180) var vert_wall_jump_max_facing_angle = 120
## If true, the character velocity will be set to zero before adding the jump velocity.
@export var wall_jump_reset_velocity := true

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
@onready var head := get_node("ModelRoot/Head")
@onready var model_root: Node3D = get_node("ModelRoot")
@onready var _debug_draw := get_node_or_null("/root/LSDebugDraw") as LSDebugDraw
@onready var _next_jump_time: float = Time.get_ticks_msec()
@onready var _collision_n := get_node("Collision") as CollisionShape3D

var last_jump_pos: Vector3
var last_jump_initial_v: Vector3
var last_jump_dir: Vector3
var last_jump_proj_v: Vector3
var last_jump_remaining_v: Vector3
var last_jump_added_v: Vector3
var can_walk: bool = true

var _motion_test_param = PhysicsTestMotionParameters3D.new()
var _motion_test_res = PhysicsTestMotionResult3D.new()
var _step_result: WalkableStepData = WalkableStepData.new()
var _step_traversal_result: StepTraversalResult = StepTraversalResult.new()

# to reflect crouching / standing status
var _effective_height: float

var _collision_exclusions: Array[RID]

var _debug_step_test_shape: Shape3D
var _debug_step_test_shape_height: float
var _debug_step_test_shape_radius: float
var _debug_step_test_shape_center: Vector3
var _debug_shape_stack: Array[ShapeInfo]
var _debug_step_sphere_pos: Vector3
var _debug_step_sphere_norm_det_pos: Vector3
var _debug_last_up_fwd: ShapeInfo
var _debug_last_up_fwd_down: ShapeInfo
var _debug_step_pre_motion_pos: ShapeInfo
var _debug_step_post_motion_pos: ShapeInfo

var _debug_physics_frame: int


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
	_debug_physics_frame += 1
	_step_traversal_result.reset()
	input_axis = Input.get_vector(&"move_back", &"move_forward",
			&"move_left", &"move_right")
	
	# TODO: replace below line with having extra node as head parent, placed where equation below shows
	# then, when climbing stairs smooth the head child
	# But still have the logic below enabled to move the head parent. It will be needed when crouch is implemented.
	_head_local_pos = Vector3(0, height - head_offset, 0)
			
	_direction_input()
	
	var now: int = Time.get_ticks_msec()
	
	var on_floor_now: bool = is_on_floor()
	
	if on_floor_now:
		_was_on_floor = true
	elif _was_on_floor:
		_was_on_floor = false
		_fall_start_position = global_position
		_fall_start_time_ms = now

	var starting_jump: bool = _jump_input() and _try_jump(now, on_floor_now)
	if not on_floor_now and not starting_jump:
		velocity -= up_dir * (gravity * delta)
	
	_accelerate(delta)

	var expected_motion := velocity * delta
	var excluded_bodies: Array[RID] = []
	var up_plane: Plane = Plane(up_dir)
	var hor_vel: Vector3 = up_plane.project(velocity)
	var is_walking: bool = on_floor_now and hor_vel.length_squared() > 0.001
	var target_local_head_pos: Vector3 = _head_local_pos
	var rem_motion: Vector3 = expected_motion
	
	var initial_velocity: Vector3 = velocity
		
	var is_wall_ahead: bool = _wall_ahead(expected_motion, _motion_test_res, excluded_bodies)
	
	if is_wall_ahead:
		if not on_floor_now:
			var wall_normal: Vector3 = _motion_test_res.get_collision_normal()
			var wall_plane: Plane = Plane(wall_normal)
			velocity = wall_plane.project(velocity)
#			print("Collided with wall while airborne. Removing velocity component against wall normal")
	
		elif is_walking:
	#		print("wall ahead")
			if _walk_up_steps(expected_motion, _motion_test_res, _step_traversal_result, excluded_bodies):
				var hor_displ = up_plane.project(_step_traversal_result.displacement)
				var adjusted_velocity = velocity - hor_displ / delta
				if adjusted_velocity.dot(velocity) < 0:
					velocity = Vector3.ZERO
				else:
					velocity = adjusted_velocity
				
	var collided = move_and_slide()
	if _step_traversal_result.traversed:
		velocity = initial_velocity
	
	head.set_target_position(target_local_head_pos)


func get_right_dir() -> Vector3:
	return model_root.global_transform.basis.x


func get_forward_dir() -> Vector3:
	return -model_root.global_transform.basis.z


func get_up_dir() -> Vector3:
	return up_dir


func add_y_rotation(amount: float) -> void:
	model_root.rotation.y = model_root.rotation.y + amount
	
	
func _wall_ahead(expected_motion: Vector3, _motion_test_res: PhysicsTestMotionResult3D, excluded_bodies: Array[RID] = []) -> bool:
	if _obstacle_detected(global_transform, expected_motion, excluded_bodies, _motion_test_res):
		var collided_with_wall: bool = false
		for i in range(0, _motion_test_res.get_collision_count()):
			var collision_normal: Vector3 = _motion_test_res.get_collision_normal(i)
			var collision_angle: float = collision_normal.angle_to(up_dir)
			collided_with_wall = collision_angle > floor_max_angle
			if collided_with_wall:
				return true
	return false
	
	
func _is_floor(normal: Vector3):
	return normal.angle_to(up_dir) <= floor_max_angle
	

func _is_ramp(normal: Vector3):
	var normal_to_up_angle: float = normal.angle_to(up_dir)
	return normal_to_up_angle <= floor_max_angle and rad_to_deg(normal_to_up_angle) > max_step_normal_to_up_degrees
	

func _walk_up_steps(expected_motion: Vector3, _motion_test_res: PhysicsTestMotionResult3D, _step_traversal_result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	const NINETY_DEG_IN_RAD = deg_to_rad(90)
	var wall_normal: Vector3 = _motion_test_res.get_collision_normal()
	var wall_norm_to_up_angle: float = min(NINETY_DEG_IN_RAD, wall_normal.angle_to(up_dir))
	var min_step_length: float = max_step_height * tan(90 - wall_norm_to_up_angle)
	var max_slope_extra_height = radius * tan(floor_max_angle)
	if _is_walkable_step(expected_motion, max_step_height, min_step_length, max_slope_extra_height, step_height_calc_steps, _step_result):
		var displacement: Vector3 = _step_result.travel
		var vert_plane = Plane(global_transform.basis.x)
		var motion_test_step_height: float = vert_plane.project(displacement).length()
		var surf_normal: Vector3 = _step_result.normal
		var angle_normal_right: float = surf_normal.angle_to(model_root.global_transform.basis.x)
		var adj_angle: float = angle_normal_right
		if angle_normal_right > PI * 0.5:
			adj_angle = PI - angle_normal_right
		var angle_slope_right = PI * 0.5 - adj_angle
		var slope_extra_height: float = radius * tan(angle_slope_right)
#		print("ang norm right: " + str(rad_to_deg(angle_normal_right)) + ";adj " + str(rad_to_deg(adj_angle)) + "; slope: " + str(rad_to_deg(angle_slope_right)) + "; extra height: " + str(slope_extra_height))
#		print("Step surf normal: " + str(surf_normal) + "; height: " + str(motion_test_step_height) + "; slope extra height: " + str(slope_extra_height))
		global_position = global_position + displacement
		head.global_position = head.global_position - displacement
		_step_traversal_result.traversed = true
		_step_traversal_result.displacement = displacement
		return true
	return false

func _debug_queue_collider_draw() -> void:
	_debug_shape_stack.clear()
	if (_debug_last_up_fwd):
		_debug_shape_stack.push_back(_debug_last_up_fwd)
		_debug_shape_stack.push_back(_debug_last_up_fwd_down)
		_debug_shape_stack.push_back(_debug_step_pre_motion_pos)
		_debug_shape_stack.push_back(_debug_step_post_motion_pos)
#	var rotated_collider = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.BLUE)
#	_debug_shape_stack.push_back(rotated_collider)
#	var axis_aligned = ShapeInfo.new(_collision_n.shape, Transform3D.IDENTITY.translated(_collision_n.global_position), Color.RED)
#	_debug_shape_stack.push_back(axis_aligned)


func _is_walkable_step(motion: Vector3, max_step_height: float,  min_step_length: float, max_slope_extra_height:float, calc_steps: int = 1, result: WalkableStepData = null) -> bool:
	const epsilon: float = 0.001
	const SQRT_2 = sqrt(2)
	var max_collider_radius: float = radius
	if _collision_n.shape is BoxShape3D:
		max_collider_radius *= SQRT_2
	var max_test_height: float = min(max_step_height * 1.75, max_step_height + tan(floor_max_angle) * max_collider_radius)
	for i in range(calc_steps, 0, -1):
		var step_height := max_test_height * (float(i) / calc_steps)
		var from: Transform3D = global_transform
		var up_motion: Vector3 = up_dir * step_height
		# if character can go up without hitting head
		if not _obstacle_detected(from, up_motion):
#			print("step attempt has enough headroom")
			var up_from = from.translated(up_motion)
			# if character can then execute the motion without hitting anything
			var up_plane = Plane(up_dir)
			var hor_motion = up_plane.project(motion)
			var hor_motion_dir = hor_motion.normalized()
			var hor_motion_length: float = hor_motion.length()
			var forward_motion_length: float = min_step_length
			var forward_motion: Vector3 = hor_motion_dir * forward_motion_length
			
			if _obstacle_detected(up_from, forward_motion):
				# TODO: check if what was hit was the wall of the next step up, not the one you are trying to climb right now. If yes, cast up and forward again. May need to do this in recursive fashion.
				pass	
			else:
#				print("step det can go forward")
				var up_fwd_from = up_from.translated(forward_motion)
				var down_motion = -up_dir * step_height
				
				# if there is a step underneath character after teleporting up and executing motion
				if _obstacle_detected(up_fwd_from, down_motion, [], _motion_test_res):
					
					_debug_last_up_fwd = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(up_motion + forward_motion), Color.YELLOW)
					_debug_last_up_fwd_down = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(up_motion + forward_motion + down_motion), Color.RED)
					_debug_step_pre_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.GREEN)
					
#					print("step det hit surf")
					# TODO: get better quality normal. When climbing ramp side at an angle, the collision is detected at the ramp edge and a wrong normal is returned, that is neither the ramp surface normal, nor the ramp side normal.
					var normal: Vector3 = _motion_test_res.get_collision_normal()
					var motion_test_collision_point: Vector3 = _motion_test_res.get_collision_point()
					_debug_step_sphere_norm_det_pos = motion_test_collision_point

					var angle_rad := normal.angle_to(up_dir)
					const angle_epsilon: float = 1
					var angle_ok: bool = angle_rad <= floor_max_angle + angle_epsilon
					var motion_safe_fraction: float = _motion_test_res.get_collision_safe_fraction()
					var travel: Vector3 = _motion_test_res.get_travel()
					var safe_point: Vector3 = up_fwd_from.origin + down_motion * motion_safe_fraction
					var total_travel: Vector3 = safe_point - global_position
					_debug_step_post_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(total_travel), Color.BLUE)
#					print("Safe fract: " + str(motion_safe_fraction) + "; rounded fract: " + str(rounded_safe_fact) + "; motion len: " + str(down_motion.length()) + "; fract based step height: " + str(motion_test_step_height) + "; final step height: " + str(final_step_height))
					if angle_ok:
						if result:
							result.normal = normal
							result.travel = total_travel
#							print("step det surf ok")
							_debug_step_sphere_pos = motion_test_collision_point
							
#						print("Step pos: " + str(motion_test_collision_point) + "; remainder: " + str(remainder) + "; rem len: " + str(remainder.length()) + "; char pos: " + str(global_position))
						return true
#					print("step det - N: " + str(normal) + "; angle deg: " + str(rad_to_deg(angle_rad)) + "; angle ok: " + str(angle_ok))
	return false


func _obstacle_detected(from: Transform3D, motion: Vector3, excl_bodies: Array[RID] = [], results: PhysicsTestMotionResult3D = null, max_collisions: int = 1) -> bool:
	_motion_test_param.from = from
	_motion_test_param.motion = motion
	_motion_test_param.exclude_bodies = excl_bodies
	_motion_test_param.max_collisions = max_collisions
	return PhysicsServer3D.body_test_motion(get_rid(), _motion_test_param, results)


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
	var facing_away_dir = model_root.global_transform.basis.z
	return wall_normal_vector.angle_to(facing_away_dir)


func _direction_input() -> void:
	direction = Vector3()
	var aim: Basis = model_root.global_transform.basis
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
	for shape_info in _debug_shape_stack:	
		_debug_draw.draw_shape(shape_info.shape, shape_info.transf3d, shape_info.color, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_pos, 0.025, Color.GREEN, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_norm_det_pos, 0.02, Color.RED, false, false)

class ShapeInfo:
	var shape: Shape3D	
	var transf3d: Transform3D
	var color: Color
	
	func _init(shape: Shape3D, transf3d: Transform3D, color: Color) -> void:
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
	var travel: Vector3


class StepTraversalResult:
	var traversed: bool
	var displacement: Vector3
	
	func reset() -> void:
		traversed = false
		
		
class UpFwdDownResult:
	var up_hit: bool
	var fwd_hit: bool
	var down_hit: bool
	var hit_pos: Vector3
	var hit_normal: Vector3
	
