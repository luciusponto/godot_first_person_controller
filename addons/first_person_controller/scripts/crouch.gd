extends "res://addons/first_person_controller/scripts/modifier_action.gd"

@export_node_path("LS_MovementController") var controller_path := NodePath("../")
@export_node_path("Node3D") var head_path := NodePath("../Head")

@onready var _controller: LS_MovementController = get_node(controller_path)
@onready var _head = get_node(head_path)
@onready var _cam: Camera3D = get_node(head_path).cam

var on_time: int


## Takes any actions needed when the modifier is switched on.
# Override superclass method
func _set_modifier_on():
	print("crouch on")
	# TODO: implement crouch logic
	# gradually reduce collider size, as if pulling legs up towards torso.
	# i.e. character position goes up by desired increment, while
	# decreasing collider size in equal measure
	on_time = Time.get_ticks_msec()
	pass

## Takes any actions needed when the modifier is switched off.
# Override superclass method
func _set_modifier_off():
	print("crouch off")
	# TODO: implement crouch logic
	# gradually increase collider size, as if stretching legs
	# i.e. character position goes down by desired increment, while
	# increasing collider size in equal measure.
	# If character is grounded, the simulation might be more stable if just
	# incrementing the collider size without moving the character position
	pass


## Virtual method to be overriden by subclasses.
## Performs any checks needed before enabling the modifier.
## Returns true if the modifier can be enabled, false otherwise.
func _can_enable_modifier() -> bool:
	return true


## Virtual method to be overriden by subclasses.
## Performs any checks needed before enabling the modifier.
## Returns true if the modifier can be enabled, false otherwise.
func _can_disable_modifier() -> bool:
	# TODO: implement. Check if there is room to expand collider back to normal size
	return Time.get_ticks_msec() - on_time > 1000
#	return false
	
	
## Virtual method to be overriden by subclasses.
## Performs any checks needed before enabling the modifier.
## Returns true if the modifier can be enabled, false otherwise.
func _can_remain_enabled() -> bool:
	return true
		
