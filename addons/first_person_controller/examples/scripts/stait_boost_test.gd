extends Node3D

@export var start_gate: Area3D
@export var finish_gate: Area3D
var start_time_ms: int


func _on_start_gate_body_entered(body):
	start_time_ms = Time.get_ticks_msec()
#	print("Test start time: " + str(float(start_time_ms)/1000))


func _on_finish_gate_body_entered(body):
	var total_time: int = Time.get_ticks_msec() - start_time_ms
	print("Time taken: " + str(float(total_time)/1000))
