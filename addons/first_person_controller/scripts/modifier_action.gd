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
@export var is_toggle := false
@export var node_disabled := false

var _is_input_on := false
var _is_modifier_on := false


# Called every physics tick. 'delta' is constant
func _physics_process(_delta: float) -> void:
	if _is_modifier_on and (node_disabled or not _can_remain_enabled()):
		_disable_modifier()
		return
	if not is_toggle:
			_is_input_on = Input.is_action_pressed(action_name)
	# else, toggle input is handled in _unhandled_input
	if _is_modifier_on != _is_input_on:
		if _is_modifier_on and _can_disable_modifier():
			_disable_modifier()
			return
		if not _is_modifier_on and _can_enable_modifier():
			_enable_modifier()
			return


## Virtual method to be overriden by subclasses.
## Takes any actions needed when the modifier is switched on.
func _set_modifier_on():
	pass 


## Virtual method to be overriden by subclasses.
## Takes any actions needed when the modifier is switched off.
func _set_modifier_off():
	pass 


## Virtual method to be overriden by subclasses.
## Performs any checks needed before enabling the modifier.
## Returns true if the modifier can be enabled, false otherwise.
func _can_enable_modifier() -> bool:
	return false


## Virtual method to be overriden by subclasses.
## Performs any checks needed before enabling the modifier.
## Returns true if the modifier can be enabled, false otherwise.
func _can_disable_modifier() -> bool:
	return false
	
	
## Virtual method to be overriden by subclasses.
## Performs any checks needed to keep the modifier enabled.
## Returns true if the modifier can remain enabled, false otherwise.
func _can_remain_enabled() -> bool:
	return true
	
	
func _enable_modifier() -> void:
	_set_modifier_on()
	_is_modifier_on = true


func _disable_modifier() -> void:
	_set_modifier_off()
	_is_modifier_on = false


func _unhandled_input(event):
	if is_toggle and event.is_action_pressed(action_name):
		_is_input_on = not _is_input_on
