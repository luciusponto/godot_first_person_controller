extends CharacterBody3D
class_name LS_MovementController

const degrees_epsilon := 0.01

enum CoyoteTimeType {
	TIME,
	DISTANCE,
	BOTH,
	NONE
}

@export_group("Character Dimensions")    
@export var height: float = 1.8
@export var radius: float = 0.3
@export var head_offset: float = 0.25

@export_group("Basic Settings")    
@export var jump_height: float = 2
@export var speed := 10
@export var acceleration := 8
@export var deceleration := 10
@export var gravity_multiplier := 3.0
@export_range(0.0, 1.0, 0.05) var air_control := 0.3

@export_group("Stair Stepping")  
@export var stair_stepping_enabled: bool = true  
@export var min_step_height: float = 0.15
@export var max_step_height: float = 0.5
## Climb at most this number of steps on a single _physics_process() call. Larger numbers are more computationally expensive. The default of 1 is enough for human speeds and stairs with real-life depth, at the default physics update rate of 60Hz. Larger values may be needed for smooth stair climbing in case max_speed is very high or the shallowest steps are extremely shallow compared to real life ones.
@export_range(1, 5) var max_consecutive_steps: int = 1
## If a steep surface is detected where we expect to find a stair step, it could be because the collision hit the edge of the step and the normal reported is the front facing one, not the up facing one. In this case, we nudge the collision test forward by this small amount and test again.
@export_range(0, 0.05, 0.001) var max_step_floor_detection_nudge_distance = 0.01
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

var _physics_frame: int = 0

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

# Cached class instances. If GDScript gets structs, delete these and create a new struct instance every time these are needed - same if translating into C#
var _motion_test_param = PhysicsTestMotionParameters3D.new()
var _motion_test_res = PhysicsTestMotionResult3D.new()
var _step_traversal_result: StepTraversalResult = StepTraversalResult.new()
var _step_height_result := StepHeightCheckResult.new()

var _up_plane: Plane
var _right_plane: Plane

# to reflect crouching / standing status
var _effective_height: float

var _collision_exclusions: Array[RID]

var _debug_step_test_shape: Shape3D
var _debug_step_test_shape_height: float
var _debug_step_test_shape_radius: float
var _debug_step_test_shape_center: Vector3
var _debug_shape_stack: Array[ShapeInfo]
var _debug_step_sphere_pos_start: Vector3
var _debug_step_sphere_pos: Vector3
var _debug_step_sphere_norm_det_pos: Vector3
var _debug_step_pre_motion_pos: ShapeInfo
var _debug_step_wall_pos: ShapeInfo
var _debug_step_up_pos: ShapeInfo
var _debug_step_fwd_pos: ShapeInfo
var _debug_step_post_motion_pos: ShapeInfo

var _debug_step_message: String
var _debug_cheat_no_clip: bool = false
var _debug_cheat_auto_walk: bool = false


func _ready():
	_set_up_collision()
	_was_on_floor = false
	_effective_height = height
	_collision_exclusions.push_back(get_rid())
	
	if OS.is_debug_build():
		if not InputMap.has_action(&"noclip"):
			InputMap.add_action((&"noclip"))
			var key = InputEventKey.new()
			key.keycode = KEY_N
			InputMap.action_add_event(&"noclip", key)
		if not InputMap.has_action(&"auto_walk"):
			InputMap.add_action((&"auto_walk"))
			var key = InputEventKey.new()
			key.keycode = KEY_I
			InputMap.action_add_event(&"auto_walk", key)
	
	
func _process(_delta):
	if draw_debug_gizmos and _debug_draw != null:
		_debug_queue_collider_draw()		
		_draw_debug_lines()	
		
	if OS.is_debug_build():
		if Input.is_action_just_pressed(&"noclip"):
			_debug_cheat_no_clip = not _debug_cheat_no_clip
			_collision_n.disabled = _debug_cheat_no_clip
		if Input.is_action_just_pressed(&"auto_walk"):
			_debug_cheat_auto_walk = not _debug_cheat_auto_walk
		
	
	# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	if _no_clip_move(delta):
		return
	
	var is_flying: bool = false
	_step_traversal_result.reset()
	_physics_frame += 1
	up_dir = -gravity_dir
	_up_plane = Plane(up_dir)
	_right_plane = Plane(get_right_dir())
	input_axis = Input.get_vector(&"move_back", &"move_forward",
			&"move_left", &"move_right")
	if _debug_cheat_auto_walk:
#		input_axis.x = randf_range(0.3, 1)
		input_axis.x = 1
	
	# TODO: replace below line with having extra node as head parent, placed where equation below shows
	# then, when climbing stairs smooth the head child
	# But still have the logic below enabled to move the head parent. It will be needed when crouch is implemented.
	_head_local_pos = Vector3(0, height - head_offset, 0)
			
	_direction_input(is_flying)
	
	var now: int = Time.get_ticks_msec()
	
	# Record start time of latest fall for coyote time
	var on_floor_now: bool = is_on_floor()
	if on_floor_now:
		_was_on_floor = true
	elif _was_on_floor:
		_was_on_floor = false
		_fall_start_position = global_position
		_fall_start_time_ms = now

	# Apply jump velocity
	var starting_jump: bool = _jump_input() and _try_jump(now, on_floor_now)
	if not on_floor_now and not starting_jump:
		velocity -= up_dir * (gravity * delta)
	
	_accelerate(delta)

	var expected_motion := velocity * delta
	var excluded_bodies: Array[RID] = []
	var hor_vel: Vector3 = _up_plane.project(velocity)
	var is_walking: bool = on_floor_now and not starting_jump and hor_vel.length_squared() > 0.0000001
	var target_local_head_pos: Vector3 = _head_local_pos
	
	var initial_velocity: Vector3 = velocity
		
	var is_wall_ahead: bool = _wall_ahead(expected_motion, _motion_test_res, excluded_bodies)
	var step_transl: Vector3 = _motion_test_res.get_travel()
	var step_rem_motion: Vector3 = _motion_test_res.get_remainder()
	
	if is_wall_ahead and not on_floor_now:
		var wall_normal: Vector3 = _motion_test_res.get_collision_normal()
		var wall_plane: Plane = Plane(wall_normal)
		velocity = wall_plane.project(velocity)
	
#    _debug_step_message = ""
	
	var step_detected: bool = (is_walking and
		_detect_step(is_wall_ahead, step_transl, step_rem_motion, _motion_test_res, _step_traversal_result, excluded_bodies))
	if step_detected:
		var previous_head_pos = head.global_position
		# teleport character to step position...
		var step_position: Vector3 = _step_traversal_result.target_position
		var step_displacement: Vector3 = step_position - global_position
		global_position = step_position
		# ...but keep head in place so it can be smoothed into position
		head.global_position = previous_head_pos
		# adjust velocity to prevent stair boosting
		var hor_displ = _up_plane.project(step_displacement)
		var adjusted_velocity = velocity - hor_displ / delta
		if adjusted_velocity.dot(velocity) < 0:
			velocity = Vector3.ZERO
		else:
			velocity = adjusted_velocity
			
	var collided = move_and_slide()
	
#	if collided and abs(get_last_slide_collision().get_normal().dot(up_dir)) < 0.2:
#		print(_physics_frame, " - Collided during move and slide.\n", _debug_step_message, "\n", "; airborne: ", (not on_floor_now), "; is walking: ", is_walking)
	
	if step_detected:
		# after move_and_slide, reinstate velocity previous to stair boost prevention
		velocity = initial_velocity
	
	head.set_target_position(target_local_head_pos)


func _no_clip_move(delta: float) -> bool:
	if _debug_cheat_no_clip:
		input_axis = Input.get_vector(&"move_back", &"move_forward",
		&"move_left", &"move_right")
		const FLY: bool = true
		_direction_input(FLY)
		var target: Vector3 = direction * speed
		var temp_vel := velocity
		var temp_accel: float
		if direction.dot(temp_vel) > 0:
			temp_accel = acceleration
		else:
			temp_accel = deceleration
		temp_vel = temp_vel.lerp(target, temp_accel * delta)
		velocity.x = temp_vel.x
		velocity.y = temp_vel.y
		velocity.z = temp_vel.z
		move_and_collide(velocity * delta)
		return true
	return false
	

func get_foot_pos() -> Vector3:
	return global_position
	
	
func get_top_pos() -> Vector3:
	return get_foot_pos() + Vector3(0, _effective_height, 0)
	

func get_right_dir() -> Vector3:
	return model_root.global_transform.basis.x.normalized()


func get_forward_dir() -> Vector3:
	return -model_root.global_transform.basis.z.normalized()


func get_up_dir() -> Vector3:
	return up_dir


func add_y_rotation(amount: float) -> void:
	model_root.rotation.y = model_root.rotation.y + amount
	

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
	
	
func _wall_ahead(expected_motion: Vector3, _motion_test_res: PhysicsTestMotionResult3D, excluded_bodies: Array[RID] = []) -> bool:
	var wall_ahead: bool = false
	if _motion_collided(global_transform, expected_motion, _motion_test_res, excluded_bodies):
		var collided_with_wall: bool = false
		for i in range(0, _motion_test_res.get_collision_count()):
			var collision_normal: Vector3 = _motion_test_res.get_collision_normal(i)
			wall_ahead = not _is_floor(collision_normal)
	return wall_ahead
	
	
func _is_floor(normal: Vector3):
	return normal.angle_to(up_dir) <= floor_max_angle
	

func _is_ramp(normal: Vector3):
	var normal_to_up_angle: float = normal.angle_to(up_dir)
	return normal_to_up_angle <= floor_max_angle and rad_to_deg(normal_to_up_angle) > max_step_normal_to_up_degrees
	

func _detect_step(wall_ahead: bool, init_transl: Vector3, motion: Vector3, _motion_test_res: PhysicsTestMotionResult3D, result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	if not wall_ahead:
		return _detect_step_down(init_transl, motion, _motion_test_res, result, excluded_bodies)
	else:
		return _detect_step_up(init_transl, motion, _motion_test_res, result, excluded_bodies)


func _detect_step_down(init_transl: Vector3, motion: Vector3, _motion_test_res: PhysicsTestMotionResult3D, result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	var down_step_motion: Vector3 = -up_dir * max_step_height
	var from: Transform3D = global_transform.translated(init_transl)
	if _motion_collided(from, down_step_motion, _motion_test_res):
		var step_found = _check_step_angle(_motion_test_res)
		var step_height_sq: float = _motion_test_res.get_travel().length_squared()
		if step_found and step_height_sq >= min_step_height * min_step_height:
			var collision_point: Vector3 = _motion_test_res.get_collision_point()
			var target_pos: Vector3 = from.origin + _motion_test_res.get_travel()
			result.target_position = target_pos
			result.traversed = true
			if _debug_draw:
				_debug_step_pre_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.GREEN)
				_debug_step_wall_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl), Color.CYAN)
				_debug_step_up_pos = ShapeInfo.new(_collision_n.shape, from, Color.TRANSPARENT)
				_debug_step_fwd_pos = ShapeInfo.new(_collision_n.shape, from, Color.TRANSPARENT)
				var translation: Vector3 = target_pos - global_position
				_debug_step_post_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(translation), Color.BLUE)
				_debug_step_sphere_pos = collision_point
				_debug_step_sphere_norm_det_pos = collision_point
			return true
	return false
	

func _detect_step_up(init_transl: Vector3, motion: Vector3, _motion_test_res: PhysicsTestMotionResult3D, result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	const MOTION_EPSILON: float = 0.0001
	const MOTION_EPSILON_SQ: float = MOTION_EPSILON * MOTION_EPSILON
	const SQRT_2: float = sqrt(2)
	
	# adjust max step height to allow stepping over the side of a ramp
	var max_collider_radius: float = radius
	var shape = _collision_n.shape
	if shape is BoxShape3D:
		max_collider_radius *= SQRT_2
	var max_test_height_unclamped: float = max_step_height + tan(floor_max_angle) * max_collider_radius
	var max_test_height: float = clampf(max_test_height_unclamped, max_step_height, max_step_height * 1.75)
	
	var from: Transform3D = global_transform
	var hor_motion: Vector3 = _up_plane.project(motion)
	var rem_fwd_motion: Vector3 = hor_motion
	var iterations: int = 0
	var steps_found_count: int = 0
	
	while iterations < max_consecutive_steps and rem_fwd_motion.length_squared() > MOTION_EPSILON_SQ:
		from = from.translated(init_transl)
		var up_from: Transform3D = from
		iterations += 1
		
		# find how far up we can go to climb a step
		# by casting up by max step height plus extra to account for ramp side height
		var up_motion: Vector3 = up_dir * max_test_height
		var hit: bool = _motion_collided(up_from, up_motion, _motion_test_res)
		var fwd_from: Transform3D = up_from.translated(_motion_test_res.get_travel())

		var step_found: bool = false

		# find how far forward we can go
		var fwd_motion: Vector3 = rem_fwd_motion
		var fwd_hit: bool = _motion_collided(fwd_from, fwd_motion, _motion_test_res)
		var forward_travel: Vector3 = _motion_test_res.get_travel()
		var forward_travel_dist_sq: float = forward_travel.length_squared()
		
		if forward_travel_dist_sq < MOTION_EPSILON_SQ:
			# couldn't go forward at all. We are facing a regular wall, not a step
			return steps_found_count > 0
			
		rem_fwd_motion -= forward_travel
		if fwd_hit:
			print(_physics_frame, " - step up fwd test hit")
		var down_from: Transform3D = fwd_from.translated(forward_travel)
		var down_motion: Vector3 = -up_dir * (max_test_height + 0.01)	

		var target_pos: Vector3
		var displacement: Vector3
		var step_height_valid: bool = false
		
		# see if we can find a step below
		for i in range(0, 2):
			if _motion_collided(down_from, down_motion, _motion_test_res):
				step_found = _check_step_angle(_motion_test_res)
				target_pos = down_from.origin + _motion_test_res.get_travel()
				displacement = target_pos - from.origin
				var coll_pos: Vector3 = _motion_test_res.get_collision_point()
				step_height_valid = _check_step_height(displacement, target_pos, coll_pos, _step_height_result)
				if step_found and step_height_valid:
					break
				# The collision could have hit the corner of the step
				# and reported the front facing normal, not the up facing one.
				# Or it could instead have hit the corner between the current floor and the step,
				# reporting the step height as zero.
				# Nudge the test position forward slightly and try again.
				# This fixes a bug due to which sometimes the character momentarily
				# 	slows down while climbing stairs.
				var forward_dir: Vector3 = hor_motion.normalized()
				var old_down_from: Transform3D = down_from
				down_from = down_from.translated(forward_dir * max_step_floor_detection_nudge_distance)
				print("old down from: ", old_down_from.origin, "; new down from: ", down_from.origin)
			
		if step_found:
			if not step_height_valid:
				print(_physics_frame, " - Step invalid height: ", _step_height_result.height, " (min: ", min_step_height, ",", max_step_height, ")")
				_debug_step_sphere_pos_start = global_position
				_debug_step_sphere_pos = target_pos
				_debug_step_sphere_norm_det_pos = _motion_test_res.get_collision_point()
				
				return steps_found_count > 0

			var collision_point: Vector3 = _motion_test_res.get_collision_point()
			
			steps_found_count += 1
			result.traversed = true
			result.target_position = target_pos
			init_transl = displacement
			if _debug_draw:
				var translation: Vector3 = target_pos - global_position
				_debug_step_pre_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.GREEN)
				_debug_step_wall_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl), Color.CYAN)
				_debug_step_up_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl + up_motion), Color.YELLOW)
				_debug_step_fwd_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl + up_motion + fwd_motion), Color.RED)
				_debug_step_post_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(translation), Color.BLUE)
#				_debug_step_sphere_pos_start = global_position
#				_debug_step_sphere_pos = target_pos
#				_debug_step_sphere_norm_det_pos = collision_point
			
	return steps_found_count > 0
	
	
func _check_step_height(displacement: Vector3, target_pos: Vector3, collision_pos: Vector3, result: StepHeightCheckResult) -> bool:
	const HEIGHT_EPSILON: float = 0.01
	
	var step_height: float = displacement.project(up_dir).length()
	var valid_height: bool = (step_height < max_step_height + HEIGHT_EPSILON and 
								step_height >= min_step_height - HEIGHT_EPSILON)
	result.height = step_height								
	return valid_height
	

func _check_step_angle(motion_test_res: PhysicsTestMotionResult3D):
	var collision_normal: Vector3 = motion_test_res.get_collision_normal()
	return _is_floor(collision_normal)


func _debug_queue_collider_draw() -> void:
	_debug_shape_stack.clear()
	if (_debug_step_pre_motion_pos):
		_debug_shape_stack.push_back(_debug_step_pre_motion_pos)
		_debug_shape_stack.push_back(_debug_step_wall_pos)
		_debug_shape_stack.push_back(_debug_step_up_pos)
		_debug_shape_stack.push_back(_debug_step_fwd_pos)
		_debug_shape_stack.push_back(_debug_step_post_motion_pos)
#	var rotated_collider = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.BLUE)
#	_debug_shape_stack.push_back(rotated_collider)
#	var axis_aligned = ShapeInfo.new(_collision_n.shape, Transform3D.IDENTITY.translated(_collision_n.global_position), Color.RED)
#	_debug_shape_stack.push_back(axis_aligned)


func _motion_collided(from: Transform3D, motion: Vector3, results: PhysicsTestMotionResult3D, excl_bodies: Array[RID] = [], max_collisions: int = 1) -> bool:
	_motion_test_param.from = from
	_motion_test_param.motion = motion
	_motion_test_param.exclude_bodies = excl_bodies
	_motion_test_param.max_collisions = max_collisions
	return PhysicsServer3D.body_test_motion(get_rid(), _motion_test_param, results)


func _set_up_collision() -> void:
	var collision = get_node("Collision")
	if collision is CollisionShape3D:
		var shape = collision.shape
		var coll_pos := Vector3(0, height / 2, 0)
		if shape is CapsuleShape3D:
			var capsule = shape as CapsuleShape3D
			capsule.height = height
			capsule.radius = radius
			collision.position = coll_pos
			return
		elif shape is CylinderShape3D:
			var cylinder = shape as CylinderShape3D
			cylinder.height = height
			cylinder.radius = radius
			collision.position = coll_pos
			return
		elif shape is BoxShape3D:
			var box = shape as BoxShape3D
			var diameter = radius * 2
			box.size = Vector3(diameter, height, diameter)
			collision.position = coll_pos
			return
	push_error("Could not find \"Collision\" child node of type CapsuleShape3D, CylinderShape3D or BoxShape3D")
		

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


func _direction_input(fly: bool = false) -> void:
	var source_node: Node3D
	if fly:
		source_node = head
	else:
		source_node = model_root
	var aim: Basis = source_node.global_transform.basis
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
	_debug_draw.draw_sphere(_debug_step_sphere_pos_start, 0.025, Color.BLUE, false, false)
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

	
class StepTraversalResult:
	var traversed: bool
	var target_position: Vector3
	
	func reset() -> void:
		traversed = false

	
class StepHeightCheckResult:
	var height: float
