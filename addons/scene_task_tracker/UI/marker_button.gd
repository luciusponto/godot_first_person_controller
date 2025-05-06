@tool

class_name SttMarkerButton
extends Button

signal drag_started
signal drag_ended(mouse_pos: Vector2, task: SttTaskData)

var task: SttTaskData

var _dragging: bool = false
var _pressed: bool = false
var _global_mouse_pos: Vector2

func _enter_tree():
	mouse_exited.connect(_on_mouse_exited)
	
func _on_mouse_exited():
	if _pressed and not _dragging:
		_start_drag()

func _start_drag():
	EditorInterface
	print("Started drag")
	_dragging = true
	drag_started.emit()

func _finish_drag(global_mouse_pos):
	#print("Finished drag at pos %s" % [global_mouse_pos])
	_dragging = false
	drag_ended.emit(global_mouse_pos, task)
	
func _input(event):
	if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
		):
			_pressed = event.pressed
			if _dragging and not _pressed:
				_finish_drag(event.global_position)
