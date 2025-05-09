@tool
extends Control

class_name SttTasksDock

class Stopwatch extends RefCounted:
	var accum: int
	var start_us: int
	var label: String
	
	func _init(label: String):
		self.label = label
	
	func start():
		start_us = Time.get_ticks_usec()
		
	func stop():
		accum = Time.get_ticks_usec() - start_us
	
	func stop_accum():
		accum += Time.get_ticks_usec() - start_us
	
	func reset():
		accum = 0
		
	func _to_string():
		return "%s: %.2f" % [label, float(accum) / 1000]

const BUG_MARKER = preload("res://addons/scene_task_tracker/scripts/task_presentation.gd")
const BUG_MARKER_SCENE = preload("res://addons/scene_task_tracker/scenes/task_presentation.tscn")
const ITEM = preload("res://addons/scene_task_tracker/UI/task_item_bt.gd")
var ITEM_SCENE = preload("res://addons/scene_task_tracker/UI/task_item_bt.tscn")
const REFRESH_PERIOD_MS = 50

var _edited_root: Node
var _edited_root_uid := 0
var _filter_pending: bool
var _sort_pending: bool
var _scene_markers_dirty: bool = false
var _next_refresh_time: int = 0

#var _popup_inspector_window: WindowDialog

var _filter_popup: PopupMenu
var _selected_task_descr: String = ""

var _resource_picker: EditorResourcePicker

var _task_database_path: String
var _task_database: SttTaskDatabase

# per project settings
const PROJ_SETTINGS_PATH := "user://scene_task_tracker.json"
const SETTING_DATABASE_PATH = "database_file_path"

# editor settings
const SETTING_LOG_ENABLED := "plugin/scene_task_tracker/debug_logs_enabled"
const SETTING_ITEM_CACHE_SIZE := "plugin/scene_task_tracker/list_item_cache_size"
const SETTING_TOOLTIP_WRAP_LENGTH := "plugin/scene_task_tracker/SETTING_TOOLTIP_WRAP_LENGTH"

const EDITOR_SETTINGS := [
	{"property_info": {"name": SETTING_LOG_ENABLED, "type": TYPE_BOOL}, "default": false},
	{"property_info": {"name": SETTING_ITEM_CACHE_SIZE, "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,500,10,or_greater"}, "default": 100},
	{"property_info": {"name": SETTING_TOOLTIP_WRAP_LENGTH, "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "20,200,1,or_greater"}, "default": 100},
]

const SELECT_DATABASE_TEXT = "Load or create a task database file above to get started"
const SAVE_DATABASE_TEXT = "Now click the dropdown menu above and save the database to disk"

@onready var _top_bar = %TopBarHBoxContainer

const DEFAULT_LOG_ENABLED := false
var _log_enabled := DEFAULT_LOG_ENABLED
var _freelook_fix_direction: int = 1

const TYPE_ID_MAP = {
	SttTaskData.TaskTypes.BUG: 0,
	SttTaskData.TaskTypes.FEATURE: 1,
	SttTaskData.TaskTypes.TECHNICAL_IMPROVEMENT: 2,
	SttTaskData.TaskTypes.POLISH: 3,
	SttTaskData.TaskTypes.REGRESSION_TEST: 4,
	SttTaskData.TaskTypes.UNKNOWN: 12,
	SttTaskData.TaskTypes.NOTE: 13,
	SttTaskData.TaskTypes.GENERIC: 14,
}

const TYPE_ICON_MAP = {
	SttTaskData.TaskTypes.BUG: preload("res://addons/scene_task_tracker/icons/bug.svg"),
	SttTaskData.TaskTypes.FEATURE: preload("res://addons/scene_task_tracker/icons/feature.svg"),
	SttTaskData.TaskTypes.TECHNICAL_IMPROVEMENT: preload("res://addons/scene_task_tracker/icons/tech_improvement.svg"),
	SttTaskData.TaskTypes.POLISH: preload("res://addons/scene_task_tracker/icons/polish.svg"),
	SttTaskData.TaskTypes.REGRESSION_TEST: preload("res://addons/scene_task_tracker/icons/regression_test.svg"),
	SttTaskData.TaskTypes.UNKNOWN: preload("res://addons/scene_task_tracker/icons/unkown.svg"),
	SttTaskData.TaskTypes.NOTE: preload("res://addons/scene_task_tracker/icons/note.svg"),
	SttTaskData.TaskTypes.GENERIC: preload("res://addons/scene_task_tracker/icons/generic_task.svg"),
}

const COMPLETED_ID_MAP = {
	false: 6,
	true: 7
}

const CURRENT_SCENE_FILTER_ID := 30

const COMPLETED_ICONS = {
	false: preload("res://addons/scene_task_tracker/icons/pending.svg"),
	true: preload("res://addons/scene_task_tracker/icons/checkmark.svg"),
}

var _scene_filter_active := false
var _item_cache_size := 0
var _settings

var _script_name;

var _tasks_cache: Array[SttTaskData]
var _filtered_tasks_cache: Array[SttTaskData]
var _tasks_to_edit: Array[SttTaskData]

var _marker_root: Node3D
var _marker_cache: Array[BUG_MARKER] = []
var _scene_marker_map: Dictionary = {}

var _last_clicked_viewport_3d: Viewport = null

var _update_stats: Array[Stopwatch]

var _is_dragging_marker: bool = false
var _dragging_marker_task: SttTaskData


enum SortingCriteria {
	PRIORITY,
	TYPE,
	STATUS,
}

enum SortingDirection {
	ASCENDING,
	DESCENDING
}

const SORTING_CRITERIA_INFO = {
	SortingCriteria.PRIORITY: {
		"display_name": "Priority",
		"prop_name": "priority",
		},
	SortingCriteria.TYPE: {
		"display_name": "Type",
		 "prop_name": "task_type",
		},
	SortingCriteria.STATUS: {
		"display_name": "Status",
		 "prop_name": "fixed",
		},
}

const DEFAULT_SORT_DIR := SortingDirection.ASCENDING

const DEFAULT_SORT_DIR_OVERRIDES: Dictionary = {
	SortingCriteria.PRIORITY: SortingDirection.DESCENDING,
}

var _sorting_order: Array
var _sorting_directions: Dictionary

func _clear_marker_nodes():
	for node in _marker_cache:
		if node:
			node.queue_free()
	_marker_cache.clear()
	_scene_marker_map.clear()
			
func _clear_item_cache():
	var child_count = %RootVBoxContainer.get_child_count()
	for i in range(child_count - 1, -1, -1):
		var child = %RootVBoxContainer.get_child(i) as Node
		%RootVBoxContainer.remove_child(child)
		child.queue_free()

func _load_editor_settings():
	var editor_settings := EditorInterface.get_editor_settings()
	_log_enabled = editor_settings.get_setting(SETTING_LOG_ENABLED)
	_item_cache_size = max(0, editor_settings.get_setting(SETTING_ITEM_CACHE_SIZE))
	var task_item_tooltip_wrap_length = max(0, editor_settings.get_setting(SETTING_TOOLTIP_WRAP_LENGTH))
	if SttTaskData.max_line_length != task_item_tooltip_wrap_length:
		SttTaskData.max_line_length = task_item_tooltip_wrap_length
		_clear_item_cache()
		_mark_dirty(&"task item tooltip wrap length setting changed")

func _on_editor_settings_changed():
	_load_editor_settings()

func _init_editor_settings():
	var editor_settings = EditorInterface.get_editor_settings()
	for setting in EDITOR_SETTINGS:
		var default_value = setting["default"]
		var prop_info = setting["property_info"]
		var setting_name = prop_info["name"]
		if not editor_settings.has_setting(setting_name):
			editor_settings.set_setting(setting_name, default_value)
		editor_settings.add_property_info(prop_info)

func _enter_tree():
	_tasks_to_edit = []
	
	_script_name = get_script().get_path().get_file()
	_init_editor_settings()
	_load_editor_settings()
	var editor_settings := EditorInterface.get_editor_settings()
	editor_settings.settings_changed.connect(_on_editor_settings_changed)
	
	var new_task_button = %NewTaskButton as SttMarkerButton
	new_task_button.dropped_marker.connect(_on_add_new_task_with_marker)
	
	(%DeleteTaskConfirmationDialog as ConfirmationDialog).confirmed.connect(_on_delete_task_confirmed)
	_settings = _load_settings()
	if (_settings):
		_task_database_path = _settings[SETTING_DATABASE_PATH]
	if _log_enabled:
		debug_log("Item cache size: " + str(_item_cache_size))		

	if ResourceLoader.exists(_task_database_path):
		_task_database = load(_task_database_path)
	_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS	
	_mark_dirty(&"tasks dock entered scene tree")

func _exit_tree():
	if _marker_root:
		_marker_root.queue_free()
	var editor_settings = EditorInterface.get_editor_settings()
	_disconnect(%SelectAllCheckBox.toggled, _on_select_all_toggled)
	_disconnect(editor_settings.settings_changed, _on_editor_settings_changed)	
	var conf_dialog = %DeleteTaskConfirmationDialog as ConfirmationDialog
	_disconnect(conf_dialog.confirmed, _on_delete_task_confirmed)
	var new_task_button = %NewTaskButton as SttMarkerButton
	_disconnect(new_task_button.dropped_marker, _on_add_new_task_with_marker)
	
func _disconnect(target_signal: Signal, target_callable: Callable):
	if target_signal.is_connected(target_callable):
		target_signal.disconnect(target_callable)
			
func _input(event):
	if event is InputEventMouseButton and (event.is_pressed() or event.is_released()):
		var clicked_viewport := SttHelper.get_viewport_3d_under_mouse()
		if clicked_viewport:
			_last_clicked_viewport_3d = clicked_viewport
		
func _mark_dirty(reason: StringName):
	if not _filter_pending:
		_filter_pending = true
		if _log_enabled:
			debug_log("Task panel dirty: " + reason)
			
func _on_viewport_input(event: InputEvent, viewport: Viewport):
	print("Input event detected in " + viewport.name)
	if event is not InputEventMouseButton:
		return
	print("Mouse button event detected in " + viewport.name)
	var mouse_button_event = event as InputEventMouseButton
	if mouse_button_event.pressed:
		_last_clicked_viewport_3d = viewport

## TODO Delete me
#func _migrate_button_pressed():#
	#print("migration logic executing...")
	#
	#var scene_root = EditorInterface.get_edited_scene_root()
	#var scene_uid := -1
	#if scene_root:
		#var scene_path : String = scene_root.scene_file_path
#
		#if not scene_path.is_empty():
			#scene_uid = ResourceLoader.get_resource_uid(scene_path)
#
			#if scene_uid != -1:
				#print("Edited scene UID:", scene_uid)
				#print("Text UID: " + ResourceUID.id_to_text(scene_uid))
			#else:
				#print("Edited scene UID not found.")
				#return
		#else:
			#print("Scene path empty")
	#else:
		#print("Scene root not found")
#
	#_edited_root.get_instance_id()
	#var markers = _get_markers_from_scene()
	#
	#print("Found " + str(len(markers)) + " markers")
	#
	#for marker in markers:
			#var marker_data = marker as BUG_MARKER
			#print("Marker " + marker_data.description)
			#var task_data = SttTaskData.new()
			#task_data.description = marker_data.description
			#task_data.details = marker_data.details
			#task_data.task_type = marker_data.task_type
			#task_data.priority = marker_data.priority
			#task_data.fixed = marker_data.fixed
			#var task_marker_data = SttTaskMarkerData.new()
			#var marker_node_3D = marker as Node3D
			#task_marker_data.position = marker_node_3D.global_position
			#task_marker_data.rotation = marker_node_3D.global_rotation_degrees
			#task_marker_data.host_scene_uid = scene_uid
			#task_data.marker_data = task_marker_data
			#_task_database.add_task(task_data)
	#ResourceSaver.save(_task_database, _task_database.resource_path)
	
func _set_item_checked(id: int, value: bool = true):
	var index = _filter_popup.get_item_index(id)
	_filter_popup.set_item_checked(index, value)
	
func _on_add_new_task_with_marker(xform: Transform3D, task: SttTaskData):
	if _edited_root_uid < 0:
		push_warning("Currently edited scene is not saved and has no uid. Cannot add task marker. Aborting.")
		return
	if is_instance_valid(task):
		push_warning("Unexpected: new task button should not have an existing valid task. Aborting.")
		return
	%NewTaskButton.release_focus()
	var edited_name = _edited_root.name
	debug_log("Dropping marker on scene: %s; UID: %d" % [edited_name, _edited_root_uid])
	var marker := SttTaskMarkerData.new()
	marker.position = xform.origin
	marker.rotation = xform.basis.get_euler()
	marker.host_scene_uid = _edited_root_uid
	var new_task := SttTaskData.new()
	new_task.description = "New empty task"
	new_task.marker_data = marker
	_task_database.add_task(new_task)
	_mark_dirty(&"New task created")
	
func _on_sort_clicked(id: int, sort_popup: PopupMenu):
	var index = sort_popup.get_item_index(id)
	for i in range(sort_popup.item_count):
		sort_popup.set_item_checked(i, i == index)
	var criterium = id / 2
	var direction = id % 2
	_sorting_order.erase(criterium)
	_sorting_order.append(criterium)
	_sorting_directions[criterium] = direction
	_sort_pending = true

func _ready():
	_last_clicked_viewport_3d = EditorInterface.get_editor_viewport_3d(0)
	# TODO: create whole UI in code for easier modification
	# add fuzzy search button. Opens popup panel where user can type, with a dropdown to choose between filtered tasks or all tasks. Tasks sorted with score based on typed info. Displayed list of tasks updated in regular intervals. Tasks with scores of 0 or less are hidden.
	# add edit button that will open inspector with selected task in it
	# add add / remove marker button, that will add a marker where the last selected viewport is pointing
	# add add task button that will create a new task in the db, select it in the tasks panel, then immediately open it for editing as if edit button had been clicked
	# modify copy button behaviour to open pop up menu with options to copy description, details or everything (desc, type, severity, details, status) to clipboard
	# add context menu to tasks in task list with the options to edit, add / remove marker, copy info to clipboard, 
	_resource_picker = EditorResourcePicker.new()
	_resource_picker.set_base_type("SttTaskDatabase")
	if _task_database:
		_resource_picker.edited_resource = _task_database
	_resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%DatabaseHBoxContainer.add_child(_resource_picker)
	_resource_picker.connect("resource_changed", _on_database_changed)	
		
	%CopyDescriptionButton.pressed.connect(_on_copy_description_button_pressed)
	%CopyDescriptionButton.icon = _get_editor_icon(&"ActionCopy")
	%NewTaskButton.icon = _get_editor_icon(&"Add")
	%NewTaskButton.tooltip_text = "New task"
	%EditTasksButton.icon = _get_editor_icon(&"Edit")
	%EditTasksButton.tooltip_text = "Edit selected tasks"
	%EditTasksButton.disabled = true
	%DropDownMenuButton.icon = _get_editor_icon(&"GuiTabMenuHl")
	%DropDownMenuButton.tooltip_text = "More commands..."
	%SearchHBoxContainer.visible = false
	%SearchButton.icon = _get_editor_icon(&"Search")
	%SearchButton.tooltip_text = "Search task from list"
	%SearchButton.flat = true
	%SearchButton.pressed.connect(_on_open_search_pressed)
	%SelectAllCheckBox.tooltip_text = "Select All"
	%SelectAllCheckBox.disabled = true
	%SelectAllCheckBox.toggled.connect(_on_select_all_toggled)
	(%SetDatabaseLabel as Label).visible = false
	%CloseSearchButton.icon = _get_editor_icon(&"Close")
	%CloseSearchButton.pressed.connect(_on_close_search_pressed)
	var sort_button = (%SortMenuButton as MenuButton)
	sort_button.tooltip_text = "Sort task list"
	_sorting_order = SortingCriteria.values()
	_sorting_order.reverse()
	for criterium in SortingCriteria.values():
		var sort_dir = DEFAULT_SORT_DIR_OVERRIDES.get(criterium, DEFAULT_SORT_DIR)
		_sorting_directions.set(criterium, sort_dir)
	var sort_popup := sort_button.get_popup()
	var sep_id = 100
	var sort_id = 0
	for criterium in SortingCriteria.values():
		for dir in SortingDirection.values():
			var crit_name = SORTING_CRITERIA_INFO[criterium]["display_name"]
			var dir_name = "Ascending" if dir == SortingDirection.ASCENDING else "Descending"
			sort_popup.add_radio_check_item("%s %s" % [crit_name, dir_name], sort_id)
			sort_id += 1
		sort_popup.add_separator("", sep_id)
		sep_id += 1
	sort_popup.remove_item(sort_popup.get_item_index(sep_id - 1))
	sort_popup.id_pressed.connect(_on_sort_clicked.bind(sort_popup))
	var default_sorting_id = SortingCriteria.PRIORITY + SortingDirection.DESCENDING
	sort_popup.id_pressed.emit(default_sorting_id)
	
	
	sort_button.icon = _get_editor_icon(&"Sort")
	#%FilterMenuButton.icon = _get_editor_icon(&"AnimationFilter", &"EditorIcons")
	_filter_popup = (%FilterMenuButton as MenuButton).get_popup()
	_filter_popup.hide_on_checkable_item_selection = false
	_filter_popup.hide_on_item_selection = false
	_filter_popup.id_pressed.connect(_on_filter_pressed)

	_filter_popup.item_count = 0
	
	_filter_popup.add_separator("Type")
	_filter_popup.add_item("All", 10)
	_filter_popup.add_item("None", 11)
	for type in SttTaskData.TaskTypes.values():
		var name := (SttTaskData.TaskTypes.keys()[type] as String).capitalize()
		if TYPE_ID_MAP.has(type):
			var icon = TYPE_ICON_MAP[type]
			var id = TYPE_ID_MAP[type]
			_filter_popup.add_icon_check_item(icon, name, id)
			var index = _filter_popup.get_item_index(id)
			_filter_popup.set_item_checked(index, true)
		else:
			push_warning(SttTaskData.TaskTypes.keys()[type] + " task type could not be added to filter list")
	
	_set_item_checked(TYPE_ID_MAP[SttTaskData.TaskTypes.REGRESSION_TEST], false)
		
	_filter_popup.add_separator("Status")
	for completed_status in [false, true]:
		var name = "Completed" if completed_status else "Pending"
		var id = COMPLETED_ID_MAP[completed_status]
		var icon = COMPLETED_ICONS[completed_status]
		_filter_popup.add_icon_check_item(icon, name, id)
	var completed_filter_index = _filter_popup.get_item_index(COMPLETED_ID_MAP[false])
	_filter_popup.set_item_checked(completed_filter_index, true) # only pending tasks show by default
	
	_filter_popup.add_separator("")
	_filter_popup.add_check_item("Current Scene Only", CURRENT_SCENE_FILTER_ID)
	var curr_scene_filter_index = _filter_popup.get_item_index(CURRENT_SCENE_FILTER_ID)
	_filter_popup.set_item_tooltip(curr_scene_filter_index, "Only display tasks that have a marker in the currently edited scene")
	_filter_popup.set_item_checked(curr_scene_filter_index, false) # only pending tasks show by default
	
	var edit_task_button = %EditTasksButton as Button
	edit_task_button.pressed.connect(_on_edit_task_button_pressed)
	
	var remove_task_button = %RemoveTaskButton as Button
	remove_task_button.icon = _get_editor_icon(&"Remove")
	remove_task_button.tooltip_text = "Remove selected task"
	remove_task_button.pressed.connect(_on_remove_task_button_pressed)
	remove_task_button.disabled = true
	
	#var migrate_button := Button.new()
	#migrate_button.text = "MIG"
	#migrate_button.pressed.connect(_migrate_button_pressed)
	#%TopBarMainHBoxContainer.add_child(migrate_button)
	
	var has_database = _task_database != null
	%TopBarMainHBoxContainer.visible = has_database
	%SetDatabaseLabel.visible = not has_database

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	#EditorInterface.get_editor_viewport_3d(0)
	if not _marker_root:
		_marker_root = Node3D.new()
		_marker_root.name = "Task Markers"

	var currently_edited_scene = get_tree().edited_scene_root
	var edited_scene_changed = currently_edited_scene != _edited_root
	
	if edited_scene_changed:
		_scene_markers_dirty = true
		if _scene_filter_active or not _edited_root:
			_mark_dirty(&"edited scene root changed")
		_edited_root = currently_edited_scene
		if _edited_root:
			_edited_root_uid = ResourceLoader.get_resource_uid(_edited_root.scene_file_path)
			if _log_enabled:
				var edited_name = _edited_root.name
				debug_log("Edited scene changed: %s; UID: %d" % [edited_name, _edited_root_uid])
		else:
			_edited_root_uid = -1
			if _log_enabled:
				debug_log("No edited root")
				
	var refresh_pending = _filter_pending or _sort_pending or _scene_markers_dirty
	if refresh_pending and Time.get_ticks_msec() > _next_refresh_time:
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
		_refresh()
		
func _refresh():
	_update_stats = []
	var total_time = Stopwatch.new("total")
	total_time.start()
	var select_all_checkbox := %SelectAllCheckBox as CheckBox
	if select_all_checkbox.button_pressed:
		select_all_checkbox.button_pressed = false
	else:
		select_all_checkbox.toggled.emit(false)
	if _filter_pending:
		_filter_pending = false
		var filter_time = Stopwatch.new("filter")
		filter_time.start()
		_update_stats.append(filter_time)
		var filtered_tasks_changed = _update_filtered_tasks()
		filter_time.stop()
		if filtered_tasks_changed:
			_scene_markers_dirty = true
			_refresh_tasks_ui()
			%SelectAllCheckBox.disabled = _filtered_tasks_cache.size() == 0
	if _sort_pending:
		_sort_pending = false
		_refresh_tasks_ui()
	if _scene_markers_dirty:
		_scene_markers_dirty = false
		_update_scene_markers()
		%TasksInSceneLabel.text = "Markers: " + str(_marker_cache.size())
	total_time.stop()
	_log_update_stats(total_time.accum)

func debug_log(message):
	prints(_script_name, ":", message)

func _on_database_changed(new_database):
	_task_database = new_database
	var has_database = _task_database != null
	if has_database:
		var database_saved = FileAccess.file_exists(_task_database.resource_path)
		if database_saved:
			%TopBarMainHBoxContainer.visible = true
			%ScrollContainerTaskList.visible = true
			%SetDatabaseLabel.visible = false
			if _log_enabled:
				debug_log("Selected database: " + _task_database.resource_path)
			_settings[SETTING_DATABASE_PATH] = _task_database.resource_path
			_save_settings(_settings)
			_mark_dirty(&"database changed")
		else:
			%TopBarMainHBoxContainer.visible = false
			%ScrollContainerTaskList.visible = false
			%SetDatabaseLabel.visible = true
			%SetDatabaseLabel.text = SAVE_DATABASE_TEXT
	else:
			%TopBarMainHBoxContainer.visible = false
			%ScrollContainerTaskList.visible = false
			%SetDatabaseLabel.visible = true
			%SetDatabaseLabel.text = SELECT_DATABASE_TEXT
			if _log_enabled:
				debug_log("No database selected")

#func _get_selected_tasks() -> Array:
	#var displayed_items = %RootVBoxContainer.get_children() as Array
	#var filtered_items := displayed_items.filter(func(x: ITEM): return x.is_selected())
	#return filtered_items.map(func(x: ITEM): return x.task)
	
func _on_delete_task_confirmed():
	for task in _tasks_to_edit:
		#print("About to remove task: " + task.description)
		_task_database.remove_task(task)
	_mark_dirty(&"Task removed")
	
func _on_open_search_pressed():
	%SearchHBoxContainer.visible = true
	%SearchLineEdit.grab_focus()
	
func _on_close_search_pressed():
	%SearchHBoxContainer.visible = false

func _get_editor_icon(name: StringName) -> Texture2D:
	return get_theme_icon(name, &"EditorIcons")

func _get_tab_container(initial_node: Node) -> TabContainer:
	const MAX_IT = 30
	var it = 0
	var node = initial_node
	while node and it < MAX_IT:
		it += 1
		node = node.get_parent()
		if node is TabContainer:
			return node as TabContainer
	return null
	
func _display_main_inspector():
	var inspector_dock := EditorInterface.get_inspector()
	var tab_container := _get_tab_container(inspector_dock)

	if tab_container:
		var tab_count = tab_container.get_tab_count()
		for i in range(tab_count):
			var tab = tab_container.get_tab_control(i)
			if tab.name == "Inspector":
				tab_container.current_tab = i
				return
	else:
		EditorInterface.get_editor_toaster().push_toast("The Inspector tab is closed. Open it with Editor->Editor Docks->Inspector.", EditorToaster.SEVERITY_WARNING)

func _edit_task(task: SttTaskData):
	EditorInterface.edit_resource(task)
	_display_main_inspector()
	
func _on_edit_task_button_pressed():
	%EditTasksButton.release_focus()
	#var selected_tasks := _get_selected_tasks()
	if (_tasks_to_edit.size() == 1):
		var task := _tasks_to_edit[0] as SttTaskData
		_edit_task(task)
	else:
		push_warning("Editing multiple tasks is not supported")
	
func _on_remove_task_button_pressed():
	%RemoveTaskButton.release_focus()
	if (_tasks_to_edit.size() == 1):
		var task := _tasks_to_edit[0] as SttTaskData
		var conf_dialog = %DeleteTaskConfirmationDialog as ConfirmationDialog
		conf_dialog.dialog_text = "The following task will be removed:\n\n%s" % [task.description]
		conf_dialog.show()
	else:
		push_warning("Deleting multiple tasks is not supported")

func _on_copy_description_button_pressed():
	%CopyDescriptionButton.release_focus()
	DisplayServer.clipboard_set(_selected_task_descr)

func _on_marker_button_pressed():
	push_warning("Marker button not yet implemented")
	
func _on_filter_pressed(id: int):
	if id == 10 or id == 11: # All or Nones
		# Uncheck All or None checkbox
		_filter_popup.set_item_checked(_filter_popup.get_item_index(id), false)

		var checked = id == 10
		for task_type in SttTaskData.TaskTypes.values():
			if TYPE_ID_MAP.has(task_type):
				var target_id = TYPE_ID_MAP[task_type]
				var index = _filter_popup.get_item_index(target_id)
				if index > -1:
					_filter_popup.set_item_checked(index, checked)
	else:
		var index = _filter_popup.get_item_index(id)
		_filter_popup.toggle_item_checked(index)
	if id == CURRENT_SCENE_FILTER_ID:
		_scene_filter_active = _filter_popup.is_item_checked(_filter_popup.get_item_index(id))
	_mark_dirty(&"filter pressed")
	
func _update_scene_markers():
	var remove_root_time = Stopwatch.new("mark_rem_root")
	var clear_root_time = Stopwatch.new("mark_clear_root")
	var add_markers_time = Stopwatch.new("mark_add")
	var add_root_time = Stopwatch.new("mark_add_root")
	var inst_time = Stopwatch.new("mark_inst")
	var setup_time = Stopwatch.new("mark_steup")
	_update_stats.append_array([remove_root_time, clear_root_time, add_markers_time, add_root_time, inst_time])
	remove_root_time.start()
	var root_parent = _marker_root.get_parent()
	if root_parent:
		root_parent.remove_child(_marker_root)
	remove_root_time.stop()
	clear_root_time.start()
	for child in _marker_root.get_children():
		_marker_root.remove_child(child)
		child.owner = null
	_clear_marker_nodes()
	clear_root_time.stop()
	
	var displayed_task_count = _filtered_tasks_cache.size()
	_marker_cache.resize(displayed_task_count)
	
	inst_time.start()
	for i in range(displayed_task_count):
		var task = _filtered_tasks_cache[i]

		var marker: BUG_MARKER = BUG_MARKER_SCENE.instantiate()
		setup_time.start()
		marker.setup(task)
		_marker_cache[i] = marker
		var scene_uid = task.marker_data.host_scene_uid
		var scene_markers: Array 
		if _scene_marker_map.has(scene_uid):
			scene_markers = _scene_marker_map.get(scene_uid)
		else:
			scene_markers = []
			_scene_marker_map[scene_uid] = scene_markers
		scene_markers.append(marker)
		setup_time.stop_accum()
	inst_time.stop()
	
	add_markers_time.start()
	var markers_to_display = []
	if _scene_marker_map.has(_edited_root_uid):
		markers_to_display = _scene_marker_map.get(_edited_root_uid)
		for marker in markers_to_display:
			_marker_root.add_child(marker)
			marker.owner = _marker_root
	add_markers_time.stop()
	add_root_time.start()
	if markers_to_display.size() > 0:
		_edited_root.add_child(_marker_root)
	add_root_time.stop()

func _is_filter_item_checked(map: Dictionary, key):
	if map.has(key):
		var id = map[key]
		var index = _filter_popup.get_item_index(id)
		if index > -1:
			var checked = _filter_popup.is_item_checked(index)
			return checked
		else:
			return false
	return false
	
func _filter_scene(task: SttTaskData) -> bool:
	if not _scene_filter_active:
		return true
	if task.marker_data:
		return task.marker_data.host_scene_uid == _edited_root_uid
	return false

func _filter_task(task: SttTaskData) -> bool:
	var type_approved = _is_filter_item_checked(TYPE_ID_MAP, task.task_type)
	var status_approved = _is_filter_item_checked(COMPLETED_ID_MAP, task.fixed)
	if type_approved and status_approved:
		return _filter_scene(task) # _filter_scene is expensive; do it last to allow it to be shortcut out
	return false
	
func sum_stopwatch(accum: int, sw: Stopwatch):
	return accum + sw.accum
	
func _log_update_stats(total_time):
	if _log_enabled:
		var total_step_count = _update_stats.size()
		var total_time_from_stats = _update_stats.reduce(sum_stopwatch, 0)
		var accounted = total_time_from_stats * 100.0 / total_time
		const MAX_DETAIL_SIZE = 4
		# filter out steps taking less than 10 microseconds
		var slowest = _update_stats.filter(func(a): return a.accum >= 10)
		slowest.sort_custom(func(a, b): return a.accum > b.accum)
		if slowest.size() > MAX_DETAIL_SIZE:
			slowest.resize(MAX_DETAIL_SIZE)
		var step_count = _update_stats.size()
		var total_slowest = slowest.reduce(sum_stopwatch, 0) * 100.0 / total_time
		var curr_time_st = Time.get_time_string_from_system()
		const DET_FORM = "\nSlowest steps (%.1f%% of total): "
		var details = DET_FORM % [total_slowest]  + " ms / ".join(slowest) + " ms"
		var total_time_ms = float(total_time) / 1000
		var stats = [curr_time_st, total_time_ms, details]
		const MAIN_FORM = "%s - Updated Tasks plugin in %.1f ms%s\n"
		debug_log(MAIN_FORM % stats)
	
func _update_filtered_tasks() -> bool:
	var filtered_tasks_changed = false
	if not _tasks_cache:
		_tasks_cache = []
	var all_tasks: Array[SttTaskData]
	if _task_database:
		all_tasks = _task_database.tasks
		if _tasks_cache != all_tasks:
			_tasks_cache = all_tasks.duplicate()
	else:
		all_tasks = []
	var filtered_tasks = all_tasks.filter(_filter_task)
	if _filtered_tasks_cache != filtered_tasks:
		_filtered_tasks_cache = filtered_tasks
		filtered_tasks_changed = true
	return filtered_tasks_changed

func _sort_tasks():
	var tasks: Array[SttTaskData] = []
	# Sort a copy of _filtered_tasks_cache. The original should keep its order so we can test
	# elsewhere if the filtered tasks have changed.
	tasks.append_array(_filtered_tasks_cache)
	
	tasks.sort_custom(func(a:SttTaskData, b:SttTaskData):
		var score = 0
		for criterium in SortingCriteria.values():
			
			# ASCENDING => -1; DESCENDING => 1
			var dir = _sorting_directions[criterium] * 2 - 1
			
			var mult = pow(10, _sorting_order.find(criterium)) * dir
			var prop_name = SORTING_CRITERIA_INFO[criterium]["prop_name"]
			var val_a = int(a.get(prop_name))
			var val_b = int(b.get(prop_name))
			var increment = sign(val_a - val_b) * mult
			score += increment
			#print("a:%d, b%d - mult: %d - incr: %d" % [val_a, val_b, mult, increment])
				
		return score > 0
	)
	return tasks	
	
func _refresh_tasks_ui():
	var sort_item_time = Stopwatch.new("ui_sort")
	var inst_item_time = Stopwatch.new("ui_inst")
	var setup_item_time = Stopwatch.new("ui_setup")
	var remove_item_time = Stopwatch.new("ui_remove")
	
	_update_stats.append_array([sort_item_time, inst_item_time, setup_item_time, remove_item_time])

	%CopyDescriptionButton.disabled = true
	if not _filter_popup:
		return # Task panel not ready to refresh

	var items = []
	var total_tasks := _tasks_cache.size()
	var displayed_task_count := _filtered_tasks_cache.size()
		
	var vbox = %RootVBoxContainer as VBoxContainer

	var current_items = vbox.get_children()
		
	inst_item_time.start()
	for i in range(displayed_task_count - len(current_items)):
		var node = ITEM_SCENE.instantiate()
		vbox.add_child(node)
	inst_item_time.stop()
	
	sort_item_time.start()
	var displayed_tasks: Array[SttTaskData] = _sort_tasks()
	sort_item_time.stop()
	
	setup_item_time.start()
	for i in range(displayed_task_count):
		var task = displayed_tasks[i]
		var item = vbox.get_child(i) as ITEM
		if item.task != task:
			item.setup(task)
			for target_signal in [item.show_marker_requested, item.select_for_edit_toggled]:
				for connection in target_signal.get_connections():
					target_signal.disconnect(connection["callable"])
			item.show_marker_requested.connect(_on_display_marker_requested)
			item.select_for_edit_toggled.connect(_on_item_selected_for_edit)
		if not item.visible:
			item.show()
		item.set_selected(false)
	setup_item_time.stop()

		
	remove_item_time.start()
	var cached_node_count = max(0, vbox.get_child_count() - displayed_task_count)
	var excess_cache_count = cached_node_count - _item_cache_size
	var last_index_to_prune = vbox.get_child_count() - excess_cache_count
	
	for i in range(vbox.get_child_count() - 1, displayed_task_count - 1, -1):
		var node = vbox.get_child(i) as ITEM
		# VBoxContainer's remove_child() and especially add_child() methods
		# are slow, but show() and hide() are faster.
		# Therefore we keep a setting for a cache size and only remove 
		# hidden nodes that exceed it.
		if i >= last_index_to_prune:
			vbox.remove_child(node)
			node.queue_free()
		else:
			if node.visible:
				node.hide()
	remove_item_time.stop()
		
	%StatsLabel.text = "Tasks: " + str(displayed_task_count) + " / " + str(total_tasks)
	

func _marker_view_sort_score(view_dir: Vector3, node_fwd: Vector3) -> float:
	var dot: float = -view_dir.dot(node_fwd)
	const shallow_angle = 60 * (2 * PI / 360) # 60 degrees from head on
	const back_facing_penalty = 0.1
	const shallow_angle_penalty = 0.01
	if abs(dot) < cos(shallow_angle):
		dot *= shallow_angle_penalty
	if dot < 0:
		dot *= back_facing_penalty
	return abs(dot)
	
func _on_select_all_toggled(toggled_on: bool):
	_set_selected_all_items(toggled_on)
	
func _set_selected_all_items(is_selected: bool):
	var items = %RootVBoxContainer.get_children()
	for item: ITEM in items:
		item.set_selected(is_selected)
		
func _on_item_selected_for_edit(toggle_on: bool, task:SttTaskData):
	if toggle_on:
		if not _tasks_to_edit.has(task):
			_tasks_to_edit.append(task)
	else:
		if _tasks_to_edit.has(task):
			_tasks_to_edit.erase(task)
	
	%EditTasksButton.disabled = _tasks_to_edit.size() == 0
	%RemoveTaskButton.disabled = _tasks_to_edit.size() != 1
	%CopyDescriptionButton.disabled = _tasks_to_edit.size() != 1
	
func _focus_viewport_on_marker(marker_data):
	# TODO Only works in GODOT 4.4 or higher (https://github.com/godotengine/godot/pull/93503)
	# For compatibility with older versions, need to hack moving mouse over 3d viewport and then send F keypress (https://github.com/godotengine/godot-proposals/issues/3287)
	
	# TODO camera position is offset in view direction by Cursor.distance (see node_3d_editor_plugin.cpp)
	# need to fix in Godot source 
	# _apply_camera_transform_to_cursor() should have:
	
	# if (orthogonal) {
	#	cursor.pos = camera_transform.origin;
	#} else {
	#	cursor.eye_pos = camera_transform.origin;
	#	Transform3D offset_cam_transf = camera_transform.translated_local(Vector3(0, 0, -cursor.distance));
	#	cursor.pos = offset_cam_transf.origin;
	#}
	
	var currently_edited_root = get_tree().edited_scene_root
	var camera = _last_clicked_viewport_3d.get_camera_3d() as Camera3D
	var vert_offset := Vector3(0, 1.75, 0)
	var node_global_transform := Transform3D(Basis.from_euler(marker_data.rotation), marker_data.position)
	var offset_node_pos: Vector3 = marker_data.position + vert_offset
	const camera_distance := 1.2
	var hor_offset_dirs: Array[Vector3] = []
	const ray_count = 12
	var node_forward = -node_global_transform.basis.z;
	for i in range(0, ray_count):
		var offset_dir = node_forward.rotated(Vector3.UP, 2 * PI * float(i) / ray_count)
		hor_offset_dirs.append(offset_dir)
		
	#const bias = -0.01 # slightly skew dot product value so that a vector facing node_forward scores higher than a vector facing away from node_forward
	hor_offset_dirs.sort_custom(func(a,b): return _marker_view_sort_score(a, node_forward) > _marker_view_sort_score(b, node_forward))

	# workaround for bug: jitter camera distance. If the camera is moved to the same position twice, freelook gets stuck until camera is moved elsewhere
	# TODO: investigate proper fix in node_3d_editor_plugin.cpp, then remove this workaround
	var camera_distance_with_fix = camera_distance + _freelook_fix_direction * 0.001
	_freelook_fix_direction *= -1

	var world3d = camera.get_world_3d()
	var unobstructed_direction: Vector3 = hor_offset_dirs[0]
	var space = world3d.direct_space_state;
	for i in range(0, len(hor_offset_dirs)):
		var hor_offset_dir := hor_offset_dirs[i]
		var potential_cam_pos = offset_node_pos + hor_offset_dir * camera_distance_with_fix
		var ray := PhysicsRayQueryParameters3D.create(potential_cam_pos, offset_node_pos)
		ray.hit_back_faces = true
		ray.hit_from_inside = true
		var raycast_result = world3d.direct_space_state.intersect_ray(ray)
		if len(raycast_result) == 0:
			unobstructed_direction = hor_offset_dir
			break
	
	var target_cam_pos: Vector3 = offset_node_pos + unobstructed_direction * camera_distance_with_fix

	# deferred to ensure it works in case we had to open the host scene for editing
	camera.look_at_from_position.call_deferred(target_cam_pos, offset_node_pos)
	
func _on_display_marker_requested(task: SttTaskData):
	_selected_task_descr = task.description
	var marker_data = task.marker_data
	if not _edited_root or not marker_data:
		return
	if marker_data.host_scene_uid != _edited_root_uid:
		var host_scene_path = ResourceUID.get_id_path(marker_data.host_scene_uid)
		if ResourceLoader.exists(host_scene_path):
			EditorInterface.open_scene_from_path(host_scene_path)
		else:
			return
	EditorInterface.set_main_screen_editor.call_deferred("3D")
	_focus_viewport_on_marker.call_deferred(marker_data)

func _get_markers_from_scene(scene: Node) -> Array[BUG_MARKER]:
	if scene:
		var bug_markers : Array[BUG_MARKER] = [] as Array[BUG_MARKER]
		var edited_tree = scene.get_tree()
		var marker_nodes = edited_tree.get_nodes_in_group("bug_marker")
		for marker_node in marker_nodes:
			if marker_node is BUG_MARKER:
				bug_markers.append(marker_node as BUG_MARKER)
		return bug_markers
	else:
		return []

func _init_setting(name, default):
	if not _settings:
		_load_settings()
	if not typeof(_settings) == TYPE_DICTIONARY:
		return default
	if _has_setting(name):
		return _get_setting(name, default)
	else:
		_set_setting(name, default)
		_save_settings(_settings)
	return default		

func _has_setting(name):
	if not typeof(_settings) == TYPE_DICTIONARY:
		return
	var settings_dic = _settings as Dictionary
	return settings_dic.has(name)
	
func _get_setting(name, default):
	if not typeof(_settings) == TYPE_DICTIONARY:
		return
	var settings_dic = _settings as Dictionary
	if settings_dic.has(name):
		return settings_dic[name]
	return default
	
func _set_setting(name, value):
	if not typeof(_settings) == TYPE_DICTIONARY:
		return
	var settings_dic = _settings as Dictionary
	settings_dic[name] = value	

func _load_settings():
	if FileAccess.file_exists(PROJ_SETTINGS_PATH):
		var file = FileAccess.open(PROJ_SETTINGS_PATH, FileAccess.ModeFlags.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_string)
			if typeof(data) == TYPE_DICTIONARY:
				return data
		else:
			push_error("Could not open settings file " + PROJ_SETTINGS_PATH + "for reading")
	return null
	
func _save_settings(settings_dictionary):
	if _log_enabled:
		debug_log("Saving Scene Task Tracker settings...")
	var file = FileAccess.open(PROJ_SETTINGS_PATH, FileAccess.ModeFlags.WRITE)
	if file:
		var json_string = JSON.stringify(settings_dictionary, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("Could not open settings file " + PROJ_SETTINGS_PATH + " for writing")
