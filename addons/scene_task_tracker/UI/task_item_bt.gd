@tool
extends Control

signal show_marker_requested(task: SttTaskData)
signal select_for_edit_toggled(toggled_on: bool, task: SttTaskData)

var task: SttTaskData

func _format_text(text: String, max_line_len := 80) -> String:
	text = text.replace(". ", ".\n")
	return ""
	
func _disconnect_task_changed():
	if task:
		if task.changed.is_connected(_on_task_data_changed):
			task.changed.disconnect(_on_task_data_changed)
			
func _on_select_checkbox_toggled(toggled_on):
	select_for_edit_toggled.emit(toggled_on, task)
		
func _exit_tree():
	_disconnect_task_changed()
	
func _on_task_data_changed():
	setup(task)

func setup(target_task):
	if target_task != task:
		_disconnect_task_changed()
		task = target_task as SttTaskData
		task.changed.connect(_on_task_data_changed)
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.get_wrapped_description_details()
	%TaskTypeIcon3.texture = SttTaskGraphics.get_icon(task)
	%TaskTypeIcon3.modulate = SttTaskGraphics.get_color(task)
	%PriorityLabel.text = str(task.priority)
	var select_checkbox := %SelectCheckBox as CheckBox
	if select_checkbox.toggled.is_connected(_on_select_checkbox_toggled):
		select_checkbox.toggled.disconnect(_on_select_checkbox_toggled)
	select_checkbox.toggled.connect(_on_select_checkbox_toggled)
	var task_type_str = (SttTaskData.TaskTypes.keys()[task.task_type] as String).capitalize()
	var icons_tooltip: String 
	var priority_text_color = %PriorityLabel.modulate
	if task.fixed:
		%TaskTypeIcon3.modulate = Color.hex(%TaskTypeIcon3.modulate.to_rgba32() & 0xffffff99)
		%PriorityLabel.modulate = Color.hex(%PriorityLabel.modulate.to_rgba32() & 0xffffff99)
		icons_tooltip = task_type_str + ", completed, priority: "
	else:
		%TaskTypeIcon3.modulate = Color.hex(%TaskTypeIcon3.modulate.to_rgba32() | 0x000000ff)
		%PriorityLabel.modulate = Color.hex(%PriorityLabel.modulate.to_rgba32() | 0x000000ff)
		icons_tooltip = task_type_str + ", priority: "
	icons_tooltip += str(task.priority)
	%IconsMarginContainer.tooltip_text = icons_tooltip
	
func set_selected(toggled_on: bool):
	%SelectCheckBox.button_pressed = toggled_on

func _on_description_button_pressed():
	show_marker_requested.emit(task)
