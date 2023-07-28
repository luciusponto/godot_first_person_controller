extends Node

@export var enabled = false

func _ready():
	$"../Mantle".connect("surface_not_found", on_mantle_surface_not_found)
	$"../Mantle".connect("steep_surface_detected", on_mantle_surface_steep)
	$"../Mantle".connect("starting_mantle", on_mantle_started)

func on_mantle_surface_not_found():
	log_message("Mantle: could not find surface")
	
func on_mantle_surface_steep(point, normal):
	log_message("Mantle: surface too steep at pos: " + str(point) + ", normal: " + str(normal))
	
func on_mantle_started(point, normal):
	log_message("Mantle: starting at pos: " + str(point) + ", normal: " + str(normal))
	
func log_message(message : String):
	if (enabled):
		print(message)
	
