extends Node

func _unhandled_input(event):
#	if event is InputEventMouseButton:
#		var mouse_button_event := event as InputEventMouseButton
#		if mouse_button_event.is_pressed() and mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
#			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F1 and key_event.shift_pressed and key_event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_VISIBLE
