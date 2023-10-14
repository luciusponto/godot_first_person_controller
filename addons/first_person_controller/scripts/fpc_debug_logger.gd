extends Node

@export var enabled = false

func _ready():
	$"../Mantle".connect("surface_not_found", on_mantle_surface_not_found)
	$"../Mantle".connect("steep_surface_detected", on_mantle_surface_steep)
	$"../Mantle".connect("starting_mantle", on_mantle_started)
	$"../Mantle".connect("max_fall_speed_exceeded", on_mantle_max_fall_speed_exceeded)
	$"../Mantle".connect("no_space_overhead", on_mantle_no_space_overhead)

func on_mantle_surface_not_found():
	log_message("Mantle: could not find surface")
	
func on_mantle_max_fall_speed_exceeded():
	log_message("Mantle: max fall speed exceeded")
	
func on_mantle_no_space_overhead(pos: Vector3):
	log_message("Mantle: obstacle overhead at position " + str(pos))
	
func on_mantle_surface_steep(point, normal):
	log_message("Mantle: surface too steep at pos: " + str(point) + ", normal: " + str(normal))
	
func on_mantle_started(point, normal, height):
	log_message(Time.get_time_string_from_system() + " - Mantle: starting at pos: " + str(point) + ", normal: " + str(normal) + ", jump height: " + str(height))
	
func log_message(message : String):
	if (enabled):
		print(message)
	
