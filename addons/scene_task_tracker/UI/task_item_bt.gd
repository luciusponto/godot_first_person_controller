@tool
extends Control

signal show_marker_requested(task: SttTaskData)
signal select_for_edit_toggled(toggled_on: bool, task: SttTaskData)
signal delete_task_requested(task: SttTaskData)
signal edit_task_requested(task: SttTaskData)

static var _popup: PopupMenu

const POPUP_ITEMS: Array[Dictionary] = [
	{"label": "Edit...", "icon": "Edit", "id": 1, "callback": "_on_edit_pressed", "sep": false},
	{"label": "Delete...", "icon": "Remove", "id": 2, "callback": "_on_delete_pressed", "sep": false},
	{"sep": true},
	{"label": "Copy description", "icon": "ActionCopy", "id": 3, "callback": "_on_copy_desc_pressed", "sep": false},
]

var task: SttTaskData

static func _static_init():
	_popup = PopupMenu.new()

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
	var descr_det = "
Click to see marker in scene.
Drag into scene to reposition marker.
Right-click for options.
-------------------------------------\n"
	descr_det += task.get_wrapped_description_details()
	%DescriptionButton.tooltip_text = descr_det
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
	
func connect_description_button(callback: Callable, target_task):
	var button = %DescriptionButton as SttMarkerButton
	button.task = target_task	
	for connection in button.dropped_marker.get_connections():
		button.dropped_marker.disconnect(connection["callable"])
	button.dropped_marker.connect(callback)	

func set_selected(toggled_on: bool):
	(%SelectCheckBox as CheckBox).button_pressed = toggled_on
	
func is_selected():
	return (%SelectCheckBox as CheckBox).button_pressed

func _on_description_button_pressed():
	show_marker_requested.emit(task)

func _on_edit_pressed():
	edit_task_requested.emit()
	#_edit_task(task)
	
func _on_delete_pressed():
	delete_task_requested.emit()
	
func _on_copy_desc_pressed():
	DisplayServer.clipboard_set(task.description)
	
#func _get_tab_container(initial_node: Node) -> TabContainer:
	#const MAX_IT = 30
	#var it = 0
	#var node = initial_node
	#while node and it < MAX_IT:
		#it += 1
		#node = node.get_parent()
		#if node is TabContainer:
			#return node as TabContainer
	#return null
	
#func _display_main_inspector():
	#var inspector_dock := EditorInterface.get_inspector()
	#var tab_container := _get_tab_container(inspector_dock)
#
	#if tab_container:
		#var tab_count = tab_container.get_tab_count()
		#for i in range(tab_count):
			#var tab = tab_container.get_tab_control(i)
			#if tab.name == "Inspector":
				#tab_container.current_tab = i
				#return
	#else:
		#EditorInterface.get_editor_toaster().push_toast("The Inspector tab is closed. Open it with Editor->Editor Docks->Inspector.", EditorToaster.SEVERITY_WARNING)
#
#func _edit_task(task: SttTaskData):
	#EditorInterface.edit_resource(task)
	#_display_main_inspector()
	
func _on_popup_index_pressed(index):
	call(_popup.get_item_metadata(index))
	
	
func _show_popup_menu():
	if not _popup:
		_popup = PopupMenu.new()
	if _popup.get_parent():
		_popup.get_parent().remove_child(_popup)
	add_child(_popup)
	_popup.clear()
	for connection in _popup.index_pressed.get_connections():
		_popup.index_pressed.disconnect(connection["callable"])
	_popup.index_pressed.connect(_on_popup_index_pressed)
	for item in POPUP_ITEMS:
		if item.get("sep", false):
			_popup.add_separator()
			continue
		var label = item["label"]
		var id = item["id"]
		var icon_name = item["icon"]
		var icon = get_theme_icon(icon_name, "EditorIcons")
		var callback = item["callback"]
		_popup.add_icon_item(icon, label, id)
		var index = _popup.get_item_index(id)
		_popup.set_item_metadata(index, callback)
	var mouse_position = get_local_mouse_position()
	_popup.popup(Rect2(get_global_mouse_position(), Vector2i.ZERO))
	
func _gui_input(event):
	if event is InputEventMouseButton:
		var mb_event = event as InputEventMouseButton
		if mb_event.pressed and mb_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_popup_menu()
