extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	if object is SttTaskData:
		print("Editing task data")
		return true
	return false
	
func _parse_begin(object):
	var apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_custom_control(apply_button)
	apply_button.pressed.connect(_on_apply_changes.bind(object))
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_custom_control(cancel_button)

func _on_apply_changes(resource: SttTaskData):
	var saved = resource.save()
	if saved == OK:
		print("Custom resource changes applied and saved.")
	else:
		printerr("Error applying and saving custom resource changes.")
