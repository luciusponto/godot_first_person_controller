extends Node

const change_cam_action = &"change_cam"

@export var cameras: Array[Camera3D]
@export var active_camera_index: int = 0

func _ready():
	cameras[active_camera_index].current = true
	if not InputMap.has_action(change_cam_action):
		InputMap.add_action(change_cam_action)
		var event = InputEventKey.new()
		event.keycode = KEY_C
		InputMap.action_add_event(change_cam_action, event)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed(change_cam_action):
		active_camera_index = wrapi(active_camera_index + 1, 0, len(cameras))
		cameras[active_camera_index].current = true
		
