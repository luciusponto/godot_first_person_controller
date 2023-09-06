extends Node

## Doom 2016 style simple mantle

@export var timeout: float = 0.5
@export var enabled: bool = false
@onready var _controller: CharacterBody3D = $".." as CharacterBody3D
var _timeout_time: int

# Called when the node enters the scene tree for the first time.
func _ready():
	_reset_timeout()


func _physics_process(delta):
	if enabled and _controller.is_on_wall_only() and Input.is_action_pressed(&"mantle") and Time.get_ticks_msec() > _timeout_time:
		# check for surface
		pass


func _reset_timeout():
	_timeout_time = Time.get_ticks_msec() + timeout * 1000
