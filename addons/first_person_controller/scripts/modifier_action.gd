## Abstract class intended to implement controller modifiers, like sprint, crouch, etc
##
## This class handles input including optional toggle logic and calls the
## appropriate response methods.
## To use it, subclass it and override all of the following virtual methods:
##		_set_modifier_on()
##		_set_modifier_off()
##		_can_apply_modifier()

extends Node

@export var action_name: StringName
@export var is_toggle = false

var _is_input_on := false
var _is_modifier_on := false


# TODO: review logic
# _can_apply_modifier does not work for crouch.
# a check also needs to be run to deactivate modifier (room for larger collider)
# change the code below to call _can_enable_modifier() or can_disable_modifier()
# depending on current state
# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var prev_state := _is_modifier_on
	if not is_toggle:
			_is_input_on = Input.is_action_pressed(action_name)
	_is_modifier_on = _is_input_on and _can_apply_modifier()
	if (prev_state != _is_modifier_on):
		if _is_modifier_on:
			print("Setting modifier on: " + action_name)
			_set_modifier_on()
		else:
			print("Setting modifier off: " + action_name)
			_set_modifier_off()


func _unhandled_input(event):
	if is_toggle and event.is_action_pressed(action_name):
		_is_input_on = not _is_input_on


## Virtual method to be overriden by subclasses.
## Takes any actions needed when the modifier is switched on.
func _set_modifier_on():
	pass 


## Virtual method to be overriden by subclasses.
## Takes any actions needed when the modifier is switched off.
func _set_modifier_off():
	pass 


## Virtual method to be overriden by subclasses.
## Performs any checks needed for the modifier to become or remain active.
## Returns true if the modifier can be active, false otherwise.
func _can_apply_modifier() -> bool:
	return false
