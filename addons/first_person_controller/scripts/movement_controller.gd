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
@onready var head := get_node("ModelRoot/Head")
@onready var model_root: Node3D = get_node("ModelRoot")
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

var _motion_test_param = PhysicsTestMotionParameters3D.new()
var _motion_test_res = PhysicsTestMotionResult3D.new()
var _step_result = WalkableStepData.new()

# to reflect crouching / standing status
var _effective_height

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

	var expected_motion := velocity * delta
	var excluded_bodies: Array[RID] = []
	var is_moving: bool = velocity.length_squared() > 0.001
	var target_local_head_pos = _head_local_pos
	var rem_motion: Vector3 = expected_motion
	var slides: int = 0
	
	
	
	while rem_motion.length_squared() > 0.001 and slides < max_slides:
		slides += 1
		# move and collide
		# if step ahead, teleport up
		# else, slide
		# continue with next iteration
		
		
		if on_floor_now and is_moving and _obstacle_detected(global_transform, expected_motion, excluded_bodies, _motion_test_res):
			var collided_with_wall: bool = false
			for i in range(0, _motion_test_res.get_collision_count()):
				var collision_normal = _motion_test_res.get_collision_normal(i)
				var collision_angle = collision_normal.angle_to(up_dir)
				collided_with_wall = collision_angle > floor_max_angle
				if (collided_with_wall):
	#				print("step det coll with wall")
					break
			
			var max_slope_extra_height = radius * tan(floor_max_angle)
			if collided_with_wall and _is_walkable_step(expected_motion, max_step_height, max_slope_extra_height, step_height_calc_steps, _step_result):
				# TODO: add extra height to compensate for inclined steps as in mantle, then test on sloped step
				var motion_test_step_height: float = _step_result.height
				var surf_normal: Vector3 = _step_result.normal
				var angle_normal_right: float = surf_normal.angle_to(model_root.global_transform.basis.x)
				var adj_angle: float = angle_normal_right
				if angle_normal_right > PI * 0.5:
					adj_angle = PI - angle_normal_right
				var angle_slope_right = PI * 0.5 - adj_angle
				var slope_extra_height: float = radius * tan(angle_slope_right)
	#			print("ang norm right: " + str(rad_to_deg(angle_normal_right)) + ";adj " + str(rad_to_deg(adj_angle)) + "; slope: " + str(rad_to_deg(angle_slope_right)) + "; extra height: " + str(slope_extra_height))
				var displacement = _step_result.travel
	#			var displacement = up_dir * (motion_test_step_height + slope_extra_height)
	#			var displacement = up_dir * motion_test_step_height
	#			print("Step surf normal: " + str(surf_normal) + "; height: " + str(step_height) + "; slope extra height: " + str(slope_extra_height))
				global_position = global_position + displacement
				head.position = head.position - displacement
	#			var prev_vel: Vector3 = velocity
	#			velocity = velocity - displacement / delta
	#			velocity = velocity - displacement
	#			print("Displ: " + str(displacement) + "; delta: " + str(delta) + "; displ/delta: " + str(displacement/delta) + "; prev v: " + str(prev_vel) + "; " + " v: " + str(velocity))
				
				
	move_and_slide()
	
	
	head.set_target_position(target_local_head_pos)


func get_right_dir() -> Vector3:
	return model_root.global_transform.basis.x


func get_forward_dir() -> Vector3:
	return -model_root.global_transform.basis.z


func get_up_dir() -> Vector3:
	return up_dir


func add_y_rotation(amount: float) -> void:
	model_root.rotation.y = model_root.rotation.y + amount
	

func _debug_queue_collider_draw() -> void:
	_debug_shape_stack.clear()
	if (_debug_last_up_fwd):
		_debug_shape_stack.push_back(_debug_last_up_fwd)
		_debug_shape_stack.push_back(_debug_last_up_fwd_down)
		_debug_shape_stack.push_back(_debug_step_pre_motion_pos)
		_debug_shape_stack.push_back(_debug_step_post_motion_pos)
	var rotated_collider = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.BLUE)
	_debug_shape_stack.push_back(rotated_collider)
#	var axis_aligned = ShapeInfo.new(_collision_n.shape, Transform3D.IDENTITY.translated(_collision_n.global_position), Color.RED)
#	_debug_shape_stack.push_back(axis_aligned)


func _is_walkable_step(motion: Vector3, max_step_height: float, max_slope_extra_height:float, calc_steps: int = 1, result: WalkableStepData = null) -> bool:
	const epsilon: float = 0.001
#	var max_test_height: float = max_step_height + max_slope_extra_height
	var max_test_height: float = max_step_height
	for i in range(calc_steps, 0, -1):
		var step_height := max_test_height * (float(i) / calc_steps)
		var from: Transform3D = global_transform
		var up_motion: Vector3 = up_dir * step_height
		# if character can go up without hitting head
		if not _obstacle_detected(from, up_motion):
#			print("step attempt has enough headroom")
			var up_from = from.translated(up_motion)
			# if character can then execute the motion without hitting anything
#			var motion_length: float = motion.length()
#			var motion_dir: Vector3 = motion / motion_length
#			var forward_motion_length: float = max(motion_length, radius)
#			var forward_motion: Vector3 = motion_dir * forward_motion_length
			var forward_motion: Vector3 = motion
			
			if _obstacle_detected(up_from, forward_motion):
				# TODO: check if what was hit was the wall of the next step up, not the one you are trying to climb right now. If yes, cast up and forward again. May need to do this in recursive fashion.
				pass	
			else:
#				print("step det can go forward")
				var up_fwd_from = up_from.translated(forward_motion)
				var down_motion = -up_dir * step_height
				
				# if there is a step underneath character after teleporting up and executing motion
				if _obstacle_detected(up_fwd_from, down_motion, [], _motion_test_res):
					# TODO: multiple short steps no longer working. Player gets teleported higher than needed.
					# TODO: one last motion test from body at the newly discovered step height to from + forward_motion
					# if it hits, teleport so that collider matches hit position
					# else, teleport only up by the step height
					# TODO: when teleporting, counteract the velocity added by the teleport by subtracting teleport vector / delta from character velocity
					
					_debug_last_up_fwd = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(up_motion + forward_motion), Color.YELLOW)
					_debug_last_up_fwd_down = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(up_motion + forward_motion + down_motion), Color.RED)
					_debug_step_pre_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform, Color.GREEN)
					
#					print("step det hit surf")
					# TODO: get better quality normal. When climbing ramp side at an angle, the collision is detected at the ramp edge and a wrong normal is returned, that is neither the ramp surface normal, nor the ramp side normal.
					var normal: Vector3 = _motion_test_res.get_collision_normal()
#					var highest_coll_index = 0
#					var highest_coll_remainder = 0
#					for i in range(0, _motion_test_res.get_collision_count()):
#						var rem = _motion_test_res.get_travel()
					var motion_test_collision_point: Vector3 = _motion_test_res.get_collision_point()
					_debug_step_sphere_norm_det_pos = motion_test_collision_point
#					var step_pos_ray_from: Vector3 = global_position + up_dir * (step_height + radius) + motion - model_root.global_transform.basis.z * (radius * 2)
#					var step_pos_ray_to: Vector3 = step_pos_ray_from - up_dir * (step_height * 1.1)
#					var step_pos_ray_to: Vector3 = global_position + forward_motion
#					var norm_raycast: Dictionary = FpcPhysicsUtil.raycast_from_to(self, up_fwd_from, step_pos_ray_to, false)
#					if norm_raycast:
#						print("Step pos ray hit")
#						normal = norm_raycast["normal"]
#						_debug_step_sphere_norm_det_pos = norm_raycast["position"]
#					else:
#						print("Step pos ray did not hit")
#						normal = _motion_test_res.get_collision_normal()
					var angle_rad := normal.angle_to(up_dir)
					const angle_epsilon: float = 1
					var angle_ok: bool = angle_rad <= floor_max_angle + angle_epsilon
#					var angle_ok: bool = angle_rad <= angle_epsilon
					var motion_safe_fraction: float = _motion_test_res.get_collision_safe_fraction()
					const SAFE_FRACTION_EPSILON: float = 0.1
					var rounded_safe_fact = max(0, motion_safe_fraction - SAFE_FRACTION_EPSILON)
					var motion_test_step_height: float = down_motion.length() * (1 - rounded_safe_fact)
					var remainder = _motion_test_res.get_remainder()
					var final_step_height: float = remainder.length()
					var travel: Vector3 = _motion_test_res.get_travel()
					var total_travel: Vector3 = -remainder
#					var total_travel: Vector3 = up_motion + forward_motion + travel
#					var total_travel: Vector3 = up_motion + forward_motion + rounded_safe_fact * down_motion
					_debug_step_post_motion_pos = ShapeInfo.new(_collision_n.shape, _collision_n.global_transform.translated(total_travel), Color.BLUE)
#					print("Safe fract: " + str(motion_safe_fraction) + "; rounded fract: " + str(rounded_safe_fact) + "; motion len: " + str(down_motion.length()) + "; fract based step height: " + str(motion_test_step_height) + "; final step height: " + str(final_step_height))
					if angle_ok:
						if result:
							result.normal = normal
							result.height = final_step_height
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
