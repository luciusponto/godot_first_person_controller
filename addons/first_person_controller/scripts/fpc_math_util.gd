class_name FpcMathUtil
extends Object


static func smooth_damp_unclamped(from, to, smooth_time: float, time_step: float, result: SmoothDampResult):
	# Adapted from template in Game Programming Gems 4, chapter 1.10
	# Represents critically damped spring-mass system
	var velocity = result.velocity
	var omega = 2.0 / maxf(0.001, smooth_time)
	var x = omega * time_step
	
	var exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change = from - to
	var temp = (velocity + omega * change) * time_step
	velocity = (velocity - omega * temp) * exp
	var new_pos = to + (change + temp) * exp
	
	result.velocity = velocity
	result.new_pos = new_pos
	return new_pos


static func smooth_damp_float(from: float, to: float, smooth_time: float, time_step: float, result: SmoothDampFloatResult) -> float:
	var velocity: float = result.velocity
	var omega: float = 2.0 / maxf(0.001, smooth_time)
	var x: float = omega * time_step
	var exp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = from - to
	var temp: float = (velocity + omega * change) * time_step
	velocity = (velocity - omega * temp) * exp
	var new_pos: float = to + (change + temp) * exp
	
	var new_pos_clamped := new_pos
	var actual_move: float = new_pos - from
	var overshot: bool = actual_move > change
	if overshot:
		new_pos_clamped = to
		velocity = change / time_step
	
	result.velocity = velocity
	result.new_pos = new_pos_clamped
	return new_pos
	
	
static func smooth_damp_Vector3(from: Vector3, to: Vector3, smooth_time: float, time_step: float, result: SmoothDampVector3Result) -> Vector3:
	var velocity: Vector3 = result.velocity
	var omega: float = 2.0 / maxf(0.001, smooth_time)
	var x: float = omega * time_step
	var exp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector3 = from - to
	var temp: Vector3 = (velocity + omega * change) * time_step
	velocity = (velocity - omega * temp) * exp
	var new_pos: Vector3 = to + (change + temp) * exp
	
	var new_pos_clamped := new_pos
	var actual_move_sqr_mag: float = (new_pos - from).length_squared()
	var change_sqr_mag: float = change.length_squared()
	var overshot: bool = actual_move_sqr_mag > change_sqr_mag
	if overshot:
		new_pos_clamped = to
		velocity = change / time_step
	
	result.velocity = velocity
	result.new_pos = new_pos_clamped
	return new_pos
	

class SmoothDampResult:
	var new_pos
	var velocity
	
	
class SmoothDampFloatResult:
	var new_pos: float
	var velocity: float
	
	
class SmoothDampVector3Result:
	var new_pos: Vector3
	var velocity: Vector3
