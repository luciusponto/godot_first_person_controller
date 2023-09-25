extends CharacterBody3D
class_name LS_MovementController

const DEGREES_EPSILON := 0.01

const LOG = preload("res://addons/first_person_controller/scripts/fpc_log_util.gd")

enum CoyoteTimeType {
	TIME,		## Allow jumping until a certain amount of time going over the platform edge
	DISTANCE,	## Allow jumping until a certain distance after going over the platform edge
	BOTH,		## Allow jumping if either TIME or DISTANCE are satisfied
	NONE,		## No help when jumping from platform edges
}

@export_group("Character Dimensions")    
@export var height: float = 1.8
@export var radius: float = 0.3
@export var head_offset: float = 0.25

@export_group("Movement")    
@export var speed: float = 10.0
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity_multiplier: float = 3.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3

@export_group("Jump")
@export var jump_height: float = 2.0
@export var jump_timeout_sec: float = 0.5
## Keep jumping while jump key held down
@export var jump_repeat := false
## Maximum wall angle in degrees against which jumps are possible. If less than 90, will jump while sliding down a steep slope, but not against vertical or overhanging walls.
@export_range(0, 180) var jump_max_wall_angle_deg: float = 89.0
## Max angle in degrees between vertical/overhanging wall and forward vector of character that allows a wall jump. Lower values require the character to better face the wall against which they wish to jump.
@export_range(0, 180) var vert_wall_jump_max_facing_angle: float = 120.0
## If true, the character velocity will be set to zero before adding the jump velocity.
@export var wall_jump_reset_velocity := true
## Blend velocity direction between world up (-gravity direction) and wall normal. 0 is full up, 1 is full wall normal. 
@export_range(0, 1, 0.001) var wall_jump_normal_influence: float = 1.0

@export_group("Crouch")
## When crouching, character height will be multiplied by this
@export var crouch_height_fraction: float = 0.5
@export var crouch_is_toggle: bool = false

@export_group("Coyote Time")
## Jump assist type when characte is just starting to fall
@export var coyote_time_type := CoyoteTimeType.NONE
## time in milliseconds when coyote_time_type is TIME. 
@export var coyote_time_millisec: int = 100
## distance in meters when coyote_time_type is DISTANCE. A value like the character radius can be a good starting point.
@export var coyote_time_meters: float = 0.3

@export_group("Stair Stepping")  
## Enables stair stepping mechanic
@export var stair_stepping_enabled := true
## Size of the highest step desired. If the character cannot climb a step of this exact height, increase this value just a little (like 1-5%) and try again.
@export var max_step_height: float = 0.5

@export_subgroup("Fine tuning")
## Minimum step height needed to execute a down stepping motion. Making this too low could lead to walking being treated as a step down.
@export var min_step_down_height: float = 0.15
## Minimum step height needed to execute an up stepping motion
@export var min_step_up_height: float = 0.0
## Minimum step depth that needs to be detected in order to allow stepping up. If too low, the system might try to step up over a vertical wall
@export var min_step_up_depth: float = 0.1
## Climb at most this number of steps on a single _physics_process() call. Larger numbers are more computationally expensive. The default of 1 is enough for human speeds and stairs with real-life depth, at the default physics update rate of 60Hz. Larger values may be needed for smooth stair climbing in case max_speed is very high or the shallowest steps are extremely shallow compared to real life ones.
@export_range(1, 5) var max_consecutive_steps: int = 1
## Max surface angle in degrees that is considered a step surface
@export var max_step_normal_to_up_degrees: float = 1.0

@export_subgroup("Corner case settings")
## If a steep surface is detected where we expect to find a stair step, it could be because the collision hit the edge of the step and the normal reported is the front facing one, not the up facing one. In this case, we nudge the collision test forward by this small amount and test again.
@export_range(0, 0.05, 0.001) var max_step_floor_detection_nudge_distance: float = 0.01
## Offset wall detection motion test this distance up to guard against case of climbing up a ramp, the test hitting the corner between ramp and step and returning the ramp normal instead of step front normal
@export var wall_detection_up_offset: float = 0.03
## Make forward component of step length at least this value. Otherwise, if speed is very slow, the character could move forward so little that float rounding will make it effectively zero and character will fall right back just before the step
@export var min_step_forward_translation: float = 0.001

@export_group("Debug Options")
## Draw gizmos to visualize values at runtime. Only works in debug builds.
@export var draw_debug_gizmos := false
## Fly around the scene with collisions disabled. Only works in debug builds. You can also toggle this in game with the action "no_clip". If no input is mapped, the default key 'N' will be used to toggle it.
@export var cheat_no_clip: bool = false
## Automatically walk forward, as if 'W' key was held down. Only works in debug builds. You can also toggle this in game with the action "auto_walk". If no input is mapped, the default key 'I' will be used to toggle it.
@export var cheat_auto_walk: bool = false

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
@onready var head: Node3D = get_node("ModelRoot/Head") as Node3D
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

var _direct_body_state: PhysicsDirectBodyState3D
var _up_plane: Plane
var _right_plane: Plane

var _crouch_requested: bool = false
var _is_crouching: bool = false

# to reflect crouching / standing status
var _effective_height: float

var _collision_exclusions: Array[RID]

var _debug_shape_stack: Array[ShapeInfo]
var _debug_step_sphere_pos_start: Vector3
var _debug_step_sphere_pos: Vector3
var _debug_step_sphere_norm_det_pos: Vector3
var _debug_step_sphere_env_coll_check: Vector3
var _debug_step_sphere_wall_det_pos: Vector3
var _debug_step_sphere_wall_det_pos_2: Vector3
var _debug_step_pre_motion_pos: ShapeInfo
var _debug_step_wall_pos: ShapeInfo
var _debug_step_up_pos: ShapeInfo
var _debug_step_fwd_pos: ShapeInfo
var _debug_step_env_check: ShapeInfo
var _debug_step_post_motion_pos: ShapeInfo


func _ready():
	_direct_body_state = PhysicsServer3D.body_get_direct_state(get_rid())
	_effective_height = height
	_set_up_collision()
	_was_on_floor = false
	_collision_exclusions.push_back(get_rid())
	
	if OS.is_debug_build():
		if not InputMap.has_action(&"no_clip"):
			InputMap.add_action((&"no_clip"))
			var key = InputEventKey.new()
			key.keycode = KEY_N
			InputMap.action_add_event(&"no_clip", key)
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
		if Input.is_action_just_pressed(&"no_clip"):
			cheat_no_clip = not cheat_no_clip
			_collision_n.disabled = cheat_no_clip
		if Input.is_action_just_pressed(&"auto_walk"):
			cheat_auto_walk = not cheat_auto_walk
		
	
	# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var total_gravity: Vector3 = _direct_body_state.total_gravity
	up_direction = Vector3.UP if (total_gravity.length_squared() < 0.001) else -total_gravity.normalized()
	if _no_clip_move(delta):
		return
		
	_handle_crouch()
	
	var is_flying: bool = false
	_step_traversal_result.reset()
	_physics_frame += 1
	_up_plane = Plane(up_direction)
	_right_plane = Plane(get_right_dir())
	input_axis = Input.get_vector(&"move_back", &"move_forward",
			&"move_left", &"move_right")
	if cheat_auto_walk:
		input_axis.x = 1
	
	# TODO: replace below line with having extra node as head parent, placed where equation below shows
	# then, when climbing stairs smooth the head child
	# But still have the logic below enabled to move the head parent. It will be needed when crouch is implemented.
	var head_height: float = _effective_height - head_offset
	_head_local_pos = Vector3(0, head_height, 0)
			
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
		velocity += total_gravity * gravity_multiplier * delta
	
	_accelerate(delta)

	var expected_motion := velocity * delta
	var excluded_bodies: Array[RID] = []
	var hor_vel: Vector3 = _up_plane.project(velocity)
	var is_walking: bool = on_floor_now and not starting_jump and hor_vel.length_squared() > 0.00001 * 0.00001
	var target_local_head_pos: Vector3 = _head_local_pos
	
	var initial_velocity: Vector3 = velocity
		
	var is_obstacle_ahead: bool = false
	var is_wall_ahead: bool = false
	var step_detected: bool = false
	if is_walking:
		# nudge motion test position up a tiny bit to improve wall detection while walking up a ramp
		var up_nudge: Vector3 = up_direction * wall_detection_up_offset
		is_obstacle_ahead = _motion_collided(global_transform.translated(up_nudge), expected_motion, _motion_test_res, excluded_bodies, 16)
		is_wall_ahead = _is_wall_collision(_motion_test_res)
		if is_obstacle_ahead:
			_debug_step_sphere_wall_det_pos = _motion_test_res.get_collision_point()
				
		var step_transl: Vector3 = _motion_test_res.get_travel()
		var step_rem_motion: Vector3 = _motion_test_res.get_remainder()
	
		step_detected = (
				stair_stepping_enabled
				and	_detect_step(is_obstacle_ahead, is_wall_ahead, step_transl, step_rem_motion, _motion_test_res, _step_traversal_result, excluded_bodies)
		)
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
			
	var _collided = move_and_slide()
	
	# after move_and_slide, reinstate velocity previous to stair boost prevention
	if step_detected:
		velocity = initial_velocity
	
	head.set_target_position(target_local_head_pos)
	

func _handle_crouch() -> void:
	if crouch_is_toggle:
		if Input.is_action_just_pressed(&"crouch"):
			_crouch_requested = not _crouch_requested
	else:
		_crouch_requested = Input.is_action_pressed(&"crouch")
		
	if _crouch_requested:
		if not _is_crouching:
			_effective_height = height * crouch_height_fraction
			_set_up_collision()
			var height_loss: float = height * (1 - crouch_height_fraction)
			var displacement: Vector3 = up_direction * height_loss
			var head_pos = head.global_position
			global_position += displacement
			head.global_position = head_pos
			_is_crouching = true
	elif _is_crouching:
		var _up_motion_dist: float = 0
		var test_motion: Vector3 = -up_direction * (height * (1 - crouch_height_fraction))
		var displacement: Vector3 = Vector3.ZERO
		var has_space: bool = true
		if _motion_collided(global_transform, test_motion, _motion_test_res, []):
			test_motion = -_motion_test_res.get_remainder()
			displacement = _motion_test_res.get_travel()
			if _motion_collided(global_transform, test_motion, _motion_test_res, []):
				has_space = false
		if has_space:
			var head_pos = head.global_position
			global_position += displacement
			head.global_position = head_pos
			_effective_height = height
			_set_up_collision()
			_is_crouching = false
		

func _no_clip_move(delta: float) -> bool:
	if cheat_no_clip:
		
		input_axis = Input.get_vector(&"move_back", &"move_forward",
		&"move_left", &"move_right")
		_direction_input(true)
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
	return up_direction


func add_y_rotation(amount: float) -> void:
	model_root.rotation.y = model_root.rotation.y + amount
	

func add_velocity(to_add: Vector3) -> void:
	velocity = velocity + to_add
	
	
func add_jump_velocity(target_jump_height: float, is_wall_jump: bool = false) -> void:
	var initial_v : Vector3 = get_real_velocity()
	var v : Vector3 = initial_v
	var jump_dir = up_direction
	var jump_speed = sqrt(2 * target_jump_height * gravity)
	
	if (is_wall_jump):
		if (wall_jump_reset_velocity):
			v = Vector3.ZERO
		var wall_normal = get_wall_normal()
		jump_dir = up_direction.lerp(wall_normal, wall_jump_normal_influence)
		
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
		
		
func _is_wall_collision(motion_test_result: PhysicsTestMotionResult3D) -> bool:
	for i in range(0, motion_test_result.get_collision_count()):
			var collision_normal: Vector3 = motion_test_result.get_collision_normal(i)
			if not _is_floor(collision_normal):
				return true
	return false
	
	
func _is_floor(normal: Vector3) -> bool:
	return normal.angle_to(up_direction) <= floor_max_angle
	

func _is_ramp(normal: Vector3) -> bool:
	var normal_to_up_angle: float = normal.angle_to(up_direction)
	return normal_to_up_angle <= floor_max_angle and rad_to_deg(normal_to_up_angle) > max_step_normal_to_up_degrees
	

func _detect_step(obstacle_ahead:bool, wall_ahead: bool, init_transl: Vector3, motion: Vector3, motion_result: PhysicsTestMotionResult3D, step_result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	if wall_ahead:
		return _detect_step_up(init_transl, motion, motion_result, step_result, excluded_bodies)
	elif obstacle_ahead:
		return false
	else:
		return _detect_step_down(init_transl, motion_result, step_result, excluded_bodies)


func _detect_step_down(vel_motion: Vector3, motion_result: PhysicsTestMotionResult3D, step_result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	var from: Transform3D = global_transform.translated(vel_motion)
	var down_step_motion: Vector3 = -up_direction * max_step_height
	motion_result = PhysicsTestMotionResult3D.new()
	if _motion_collided(from, down_step_motion, motion_result, excluded_bodies):
		var step_found = _check_step_angle(motion_result)
		var step_height_sq: float = motion_result.get_travel().length_squared()
		
		if step_found and step_height_sq >= min_step_down_height * min_step_down_height:
#			LOG.print_timed(["Step down found: ", step_found, "; height: ", sqrt(step_height_sq)])
			var target_pos: Vector3 = from.origin + motion_result.get_travel()
			var shape_translation: Vector3 = target_pos - global_position
			var test_shape: Shape3D = _collision_n.shape
			var test_xform: Transform3D = _collision_n.global_transform.translated(shape_translation)
			if _has_env_collision(test_shape, test_xform):
#				LOG.print_timed(["Step down failed double-checks"])
				return false
			
			var collision_point: Vector3 = motion_result.get_collision_point()
			step_result.target_position = target_pos
			step_result.traversed = true
			if _debug_draw:
				_debug_step_pre_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.GREEN)
				_debug_step_wall_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(vel_motion), Color.CYAN)
				_debug_step_up_pos = ShapeInfo.new(_collision_n.shape, from, Color.TRANSPARENT)
				_debug_step_fwd_pos = ShapeInfo.new(_collision_n.shape, from, Color.TRANSPARENT)
				var translation: Vector3 = target_pos - global_position
				_debug_step_post_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(translation), Color.BLUE)
				_debug_step_sphere_pos = collision_point
				_debug_step_sphere_norm_det_pos = collision_point
			return true
	return false
	
	
func _has_env_collision(shape: Shape3D, xform: Transform3D) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.transform = xform
	params.shape = shape
	params.exclude = [get_rid()]
	var space = get_world_3d().direct_space_state
	var result = space.collide_shape(params, 1)
	if len(result) > 0:
		_debug_step_sphere_env_coll_check = result[1]		
		_debug_step_env_check = ShapeInfo.new(shape, xform, Color.DARK_ORANGE)
		return true
	return false
	

func _get_rest_info(shape: Shape3D, xform: Transform3D) -> Dictionary:
	var params := PhysicsShapeQueryParameters3D.new()
	params.transform = xform
	params.shape = shape
	params.exclude = [get_rid()]
	var space = get_world_3d().direct_space_state
	return space.get_rest_info(params)
	

func _detect_step_up(init_transl: Vector3, motion: Vector3, motion_result: PhysicsTestMotionResult3D, step_result: StepTraversalResult, excluded_bodies: Array[RID]) -> bool:
	const MOTION_EPSILON: float = 0.00001
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
	
	while (
			iterations == 0 # searching for first step
			or (
					steps_found_count == iterations # found a step in previous iteration
					and iterations < max_consecutive_steps # haven't used all iterations
					and rem_fwd_motion.length_squared() >= MOTION_EPSILON_SQ # there's some motion left to test
				)
	):
		from = from.translated(init_transl)
		var up_from: Transform3D = from
		iterations += 1
		
		# find how far up we can go to climb a step
		# by casting up by max step height plus extra to account for ramp side height
		var up_motion: Vector3 = up_direction * max_test_height
		_motion_collided(up_from, up_motion, motion_result, excluded_bodies)
		var fwd_from: Transform3D = up_from.translated(motion_result.get_travel())
#		FPCLogUtil.print_timed(["Step up - up travel: ", motion_result.get_travel()])

		var step_found: bool = false

		# find how far forward we can go
		var fwd_motion: Vector3 = rem_fwd_motion
		var _fwd_hit: bool = _motion_collided(fwd_from, fwd_motion, motion_result, excluded_bodies)
		var fwd_travel: Vector3 = motion_result.get_travel()
		var fwd_travel_dist_sq: float = fwd_travel.length_squared()
#		FPCLogUtil.print_timed(["Step up - forward travel: ", forward_travel])

		if fwd_travel_dist_sq < MOTION_EPSILON_SQ:
			# couldn't go forward at all. We are facing a regular wall, not a step
			FPCLogUtil.print_timed(["Step up detection could not go forward. Found wall."])
			return steps_found_count > 0
#		else:
#			FPCLogUtil.print_timed(["Step up detection forward travel: ", fwd_travel_dist_sq])
			
		rem_fwd_motion -= fwd_travel
		var down_from: Transform3D = fwd_from.translated(fwd_travel)
		var down_motion: Vector3 = -up_direction * (max_test_height + 0.01)	

		var target_pos: Vector3
		var displacement: Vector3
		var step_height_valid: bool = false
		
		# see if we can find a step below
		for i in range(0, 2):
			if _motion_collided(down_from, down_motion, motion_result, excluded_bodies):
				step_found = _check_step_angle(motion_result)
				target_pos = down_from.origin + motion_result.get_travel()
				displacement = target_pos - from.origin
				step_height_valid = _check_step_height(displacement, _step_height_result)
#				FPCLogUtil.print_timed(["Step up - down travel: ", motion_result.get_travel()])
				if step_found and step_height_valid:
					if i == 1:
						FPCLogUtil.print_timed(["Found step below at second attempt"])
					break
				# The collision could have hit the corner of the step
				# and reported the front facing normal, not the up facing one.
				# Or it could instead have hit the corner between the current floor and the step,
				# reporting the step height as zero.
				# Nudge the test position forward slightly and try again.
				# This fixes a bug due to which sometimes the character momentarily
				# 	slows down while climbing stairs.
				var forward_dir: Vector3 = hor_motion.normalized()
				down_from = down_from.translated(forward_dir * max_step_floor_detection_nudge_distance)
			
		if step_found:
			if not step_height_valid:
				_debug_step_sphere_pos_start = global_position
				_debug_step_sphere_pos = target_pos
				_debug_step_sphere_norm_det_pos = motion_result.get_collision_point()
#				FPCLogUtil.print_timed(["Step up - invalid height"])
				
				return steps_found_count > 0

#			FPCLogUtil.print_timed(["Step up found"])
			
			steps_found_count += 1
			step_result.traversed = true
			var translation: Vector3 = target_pos - global_position
			var fwd_translation: Vector3 = _up_plane.project(translation)
			if fwd_translation.length_squared() < min_step_forward_translation * min_step_forward_translation:
				var new_fwd_translation: Vector3 = hor_motion.normalized() * min_step_forward_translation
#				FPCLogUtil.print_timed(["enforced min step forward dist: ", min_step_forward_translation])
				var vert_transl: Vector3 = translation - fwd_translation
				translation = vert_transl + new_fwd_translation
				step_result.target_position = global_position + translation
			else:
				step_result.target_position = target_pos
			
			init_transl = displacement
			
			if _debug_draw:
#				var translation: Vector3 = target_pos - global_position
				_debug_step_pre_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.GREEN)
				_debug_step_wall_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl), Color.CYAN)
				_debug_step_up_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl + up_motion), Color.YELLOW)
				_debug_step_fwd_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(init_transl + up_motion + fwd_motion), Color.RED)
				_debug_step_post_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(translation), Color.BLUE)
#				_debug_step_sphere_pos_start = global_position
#				_debug_step_sphere_pos = target_pos
#				_debug_step_sphere_norm_det_pos = motion_result.get_collision_point()
	if steps_found_count > 1:
		FPCLogUtil.print_timed(["Climbed multiple steps at once: ", steps_found_count])
	return steps_found_count > 0
	
	
func _check_step_height(displacement: Vector3, result: StepHeightCheckResult) -> bool:
	const HEIGHT_EPSILON: float = 0.0001
	
	var step_height: float = displacement.project(up_direction).length()
	var valid_height: bool = (
			step_height < max_step_height + HEIGHT_EPSILON
			and step_height >= min_step_up_height + HEIGHT_EPSILON
	)
	result.height = step_height								
	return valid_height
	

func _check_step_angle(motion_test_res: PhysicsTestMotionResult3D):
	var collision_normal: Vector3 = motion_test_res.get_collision_normal()
	return _is_floor(collision_normal)
	
	
func _motion_collided(from: Transform3D, motion: Vector3, results: PhysicsTestMotionResult3D, excl_bodies: Array[RID] = [], max_collisions: int = 1) -> bool:
	_motion_test_param.from = from
	_motion_test_param.motion = motion
	_motion_test_param.exclude_bodies = excl_bodies
	_motion_test_param.max_collisions = max_collisions
	return PhysicsServer3D.body_test_motion(get_rid(), _motion_test_param, results)


func _set_up_collision() -> void:
	var collision_vert_offset: float = _effective_height / 2
	var coll_pos := Vector3(0, collision_vert_offset, 0)
	_collision_n.position = coll_pos
	var shape = _collision_n.shape
	if shape is CapsuleShape3D:
		var capsule = shape as CapsuleShape3D
		capsule.height = _effective_height
		capsule.radius = radius
		return
	elif shape is CylinderShape3D:
		var cylinder = shape as CylinderShape3D
		cylinder.height = _effective_height
		cylinder.radius = radius
		return
	elif shape is BoxShape3D:
		var box = shape as BoxShape3D
		var diameter = radius * 2
		box.size = Vector3(diameter, _effective_height, diameter)
		_collision_n.shape = box
		print("New collider height: ", (_collision_n.shape as BoxShape3D).size.y)
		return
		

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
	var pressed = (Input.is_action_just_pressed(&"jump") or
					(jump_repeat and Input.is_action_pressed(&"jump")))
	var now = Time.get_ticks_msec()
	return now >= _next_jump_time and pressed


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
	var wall_angle = wall_normal.angle_to(up_direction)
	var wall_angle_deg = rad_to_deg(wall_angle)
	var angle_allowed = wall_angle_deg < (jump_max_wall_angle_deg + DEGREES_EPSILON)
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


func _debug_queue_collider_draw() -> void:
	_debug_shape_stack.clear()
	if (_debug_step_pre_motion_pos):
		_debug_shape_stack.push_back(_debug_step_pre_motion_pos)
		_debug_shape_stack.push_back(_debug_step_wall_pos)
		_debug_shape_stack.push_back(_debug_step_up_pos)
		_debug_shape_stack.push_back(_debug_step_fwd_pos)
		_debug_shape_stack.push_back(_debug_step_post_motion_pos)
		_debug_shape_stack.push_back(_debug_step_env_check)

	
func _draw_debug_lines():
	const SCALE = 0.1
	const POS_OFFSET_PER_ITER = Vector3(0.02, 0, 0.02)
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
		_debug_draw.overlay_line(pos, pos + offset * SCALE, color)
		pos = pos + POS_OFFSET_PER_ITER
	for shape_info in _debug_shape_stack:
		if shape_info:	
			_debug_draw.draw_shape(shape_info.shape, shape_info.transf3d, shape_info.color, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_pos_start, 0.025, Color.BLUE, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_pos, 0.025, Color.GREEN, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_norm_det_pos, 0.02, Color.RED, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_env_coll_check, 0.02, Color.MAGENTA, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_wall_det_pos, 0.02, Color.BISQUE, false, false)
	_debug_draw.draw_sphere(_debug_step_sphere_wall_det_pos_2, 0.015, Color.BLACK, false, false)


class ShapeInfo:
	var shape: Shape3D	
	var transf3d: Transform3D
	var color: Color
	
	func _init(new_shape: Shape3D, xform_3d: Transform3D, new_color: Color) -> void:
		self.shape = new_shape
		self.transf3d = xform_3d
		self.color = new_color

	
class StepTraversalResult:
	var traversed: bool
	var target_position: Vector3
	
	func reset() -> void:
		traversed = false

	
class StepHeightCheckResult:
	var height: float
