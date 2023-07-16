# Add to Project -> Project Settings -> Autoload tab to have the default
# controls work without having to configure the Input Map

extends Node

var controls_keyboard = {
	"jump": [KEY_SPACE],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"mantle": [KEY_E],
	"use": [KEY_F],
	"change_mouse_input": [ModifiedKey.new(KEY_F1, true, false, false)]
}
				
var controls_joypad_motion = {
	"look_up": JoypadMotion.new(3, 1.0),
	"look_down": JoypadMotion.new(3, -1.0),
	"look_left": JoypadMotion.new(2, -1.0),
	"look_right": JoypadMotion.new(2, 1.0)
}

func _ready():
	add_inputs()
	
func add_inputs():
	for action in controls_keyboard:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in controls_keyboard[action]:
				var ev = InputEventKey.new()
				if key is ModifiedKey:
					ev.keycode = key.keycode
					ev.shift_pressed = key.is_shift_pressed
					ev.alt_pressed = key.is_alt_pressed
					ev.ctrl_pressed = key.is_control_pressed
				else:
					ev.keycode = key
				InputMap.action_add_event(action, ev)

	for action in controls_joypad_motion:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key = controls_joypad_motion[action] as JoypadMotion
			var ev = InputEventJoypadMotion.new()
			ev.axis = key.axis
			ev.axis_value = key.axis_value
			InputMap.action_add_event(action, ev)
	
class ModifiedKey:
	var keycode
	var is_shift_pressed := false
	var is_alt_pressed := false
	var is_control_pressed := false
	
	func _init(keycode, is_shift_pressed, is_alt_pressed, is_control_pressed):
		self.keycode = keycode
		self.is_shift_pressed = is_shift_pressed
		self.is_alt_pressed = is_alt_pressed
		self.is_control_pressed = is_control_pressed
		
class JoypadMotion:
	var axis : int
	var axis_value = 1
	
	func _init(axis, axis_value):
		self.axis = axis
		self.axis_value = axis_value
	
