extends "res://addons/first_person_controller/scripts/modifier_action.gd"

@export_node_path("LS_MovementController") var controller_path := NodePath("../")
@export_node_path("Node3D") var head_path := NodePath("../Head")

@onready var _controller: LS_MovementController = get_node(controller_path)
@onready var _head = get_node(head_path)
@onready var _cam: Camera3D = get_node(head_path).cam


## Takes any actions needed when the modifier is switched on.
# Override superclass method
func _set_modifier_on():
	# TODO: implement crouch logic
	# gradually reduce collider size, as if pulling legs up towards torso.
	# i.e. character position goes up by desired increment, while
	# decreasing collider size in equal measure
	pass

## Takes any actions needed when the modifier is switched off.
# Override superclass method
func _set_modifier_off():
	# TODO: implement crouch logic
	# gradually increase collider size, as if stretching legs
	# i.e. character position goes down by desired increment, while
	# increasing collider size in equal measure.
	# If character is grounded, the simulation might be more stable if just
	# incrementing the collider size without moving the character position
	pass


## Performs any checks needed for the modifier to become or remain active.
## Returns true if the modifier can be active, false otherwise.
# Override superclass methods
func _can_apply_modifier() -> bool:
	if _is_modifier_on:
		return _can_disable_modifier()
	else:
		return _can_enable_modifier()
		
func _can_disable_modifier() -> bool:
	# TODO: implement. Check if there is room to expand collider back to normal size
	return false
	
func _can_enable_modifier() -> bool:
	return true
