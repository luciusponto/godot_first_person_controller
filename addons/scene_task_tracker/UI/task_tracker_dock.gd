@tool
extends Control

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
		return label + ": " + str(float(accum) / 1000)

const BUG_MARKER = preload("res://addons/scene_task_tracker/task_marker.gd")
const BUG_MARKER_SCENE = preload("res://addons/scene_task_tracker/task_marker.tscn")
const ITEM = preload("res://addons/scene_task_tracker/UI/task_item_bt.gd")
const NODE_SELECTOR_R = preload("res://addons/scene_task_tracker/UI/node_selector.gd")
const PLUGIN = preload("res://addons/scene_task_tracker/UI/task_tracker.gd")
const REFRESH_PERIOD_MS = 50

var _item_resource = preload("res://addons/scene_task_tracker/UI/task_item_bt.tscn")
var _edited_root: Node
var _edited_root_uid := 0
var _is_dirty: bool
var _update_scene_markers: bool = false
var _next_refresh_time: int = 0
var _node_selector: NODE_SELECTOR_R
var _marker_parent: Node

var _nodes_popup: PopupMenu
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

var _marker_root: Node3D
var _marker_cache: Array[BUG_MARKER] = []
var _scene_marker_map: Dictionary = {}

var _last_clicked_viewport_3d: Viewport = null

func _clear_marker_nodes():
	if _marker_root.get_parent():
		_marker_root.get_parent().remove_child(_marker_root)
	for child in _marker_root.get_children():
		_marker_root.remove_child(child)
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
	print("Enter tree")
	EditorInterface.get_editor_main_screen().gui_input.connect(_on_editor_gui_input)
	_script_name = get_script().get_path().get_file()
	_init_editor_settings()
	_load_editor_settings()
	var editor_settings := EditorInterface.get_editor_settings()
	editor_settings.settings_changed.connect(_on_editor_settings_changed)

	_settings = _load_settings()
	if (_settings):
		_task_database_path = _settings[SETTING_DATABASE_PATH]
	if _log_enabled:
		debug_log("Item cache size: " + str(_item_cache_size))		

	if ResourceLoader.exists(_task_database_path):
		_task_database = load(_task_database_path)
	_node_selector = NODE_SELECTOR_R.new()
	_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS	
	_mark_dirty(&"tasks dock entered scene tree")

func _exit_tree():
	if _marker_root:
		_marker_root.queue_free()
	var editor_settings = EditorInterface.get_editor_settings()
	if editor_settings.settings_changed.is_connected(_on_editor_settings_changed):
		editor_settings.settings_changed.disconnect(_on_editor_settings_changed)
		
	#for setting in DEFAULT_SETTING_VALUES.keys():
		#editor_settings.erase(setting)	
		
#	for child in _marker_parent.get_children():
#		_marker_parent.remove_child(child)
#		child.queue_free()
#	var viewport = EditorInterface.get_editor_viewport_3d(0)
#	viewport.remove_child(_marker_parent)
#	_marker_parent.queue_free()

func _mark_dirty(reason: StringName):
	if not _is_dirty:
		_is_dirty = true
		if _log_enabled:
			debug_log("Task panel dirty: " + reason)

func _on_editor_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var viewport_3d = _get_viewport_3d_under_mouse(event.position)
		if viewport_3d:
			_last_clicked_viewport_3d = viewport_3d			

func _get_viewport_3d_under_mouse(screen_position):
	# Iterate through all viewports in the scene tree.
	for i in range(0, 3):
		var viewport := EditorInterface.get_editor_viewport_3d(i)
		if viewport is Viewport and viewport.get_camera_3d() != null: # Check if it's a 3D viewport with a camera.
			var viewport_rect = viewport.get_screen_rect()
			if viewport_rect.has_point(screen_position):
				# Check if the mouse click is within the viewport's bounds.
				# Project the mouse position into the viewport's 3D space.
				var camera = viewport.get_camera_3d()
				if camera:
					var ray_origin = camera.project_ray_origin(viewport.get_mouse_position())
					var ray_end = ray_origin + camera.project_ray_normal(viewport.get_mouse_position()) * camera.far
					var space_state = viewport.world_3d.direct_space_state as PhysicsDirectSpaceState3D
					var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
					var result = space_state.intersect_ray(query)

					# If the ray hits something in the 3D viewport, it was clicked.
					if result:
						return viewport
	return null
	
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

func _ready():
	_last_clicked_viewport_3d = EditorInterface.get_editor_viewport_3d(0)
	print("ready")
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
	%TopBarHBoxContainer.add_child(_resource_picker)
	_resource_picker.connect("resource_changed", _on_database_changed)	
		
	%RefreshButton.pressed.connect(_refresh)
	%CopyDescriptionButton.pressed.connect(_on_copy_description_button_pressed)
	%MarkerButton.pressed.connect(_on_copy_description_button_pressed)
	_nodes_popup = (%NodesMenuButton as MenuButton).get_popup()
	_nodes_popup.id_pressed.connect(_on_nodes_popup_menu_id_pressed)
	_nodes_popup.hide_on_item_selection = false
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
		print("Creating _marker_root")

	var currently_edited_scene = get_tree().edited_scene_root
	var edited_scene_changed = currently_edited_scene != _edited_root
	
	if edited_scene_changed:
		_update_scene_markers = true
		if _scene_filter_active or not _edited_root:
			_mark_dirty(&"edited scene root changed")
		_edited_root = currently_edited_scene
		if _edited_root:
			_edited_root_uid = ResourceLoader.get_resource_uid(_edited_root.scene_file_path)
			if _log_enabled:
				debug_log("Edited root UID: " + str(_edited_root_uid))
		else:
			_edited_root_uid = -1
			if _log_enabled:
				debug_log("No edited root")
	if (_is_dirty or _update_scene_markers) and Time.get_ticks_msec() > _next_refresh_time:
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
		if _is_dirty:
			_refresh()
		elif _update_scene_markers:
			_display_curr_scene_markers()
		
func debug_log(message):
	prints(_script_name, ":", message)

func _on_database_changed(new_database):
	_task_database = new_database
	var has_database = _task_database != null
	if has_database:
		var database_saved = FileAccess.file_exists(_task_database.resource_path)
		if database_saved:
			%TopBarMainHBoxContainer.visible = true
			%SetDatabaseLabel.visible = false
			if _log_enabled:
				debug_log("Selected database: " + _task_database.resource_path)
			_settings[SETTING_DATABASE_PATH] = _task_database.resource_path
			_save_settings(_settings)
			_mark_dirty(&"database changed")
		else:
			%TopBarMainHBoxContainer.visible = false
			%SetDatabaseLabel.visible = true
			%SetDatabaseLabel.text = SAVE_DATABASE_TEXT
	else:
			%TopBarMainHBoxContainer.visible = false
			%SetDatabaseLabel.visible = true
			%SetDatabaseLabel.text = SELECT_DATABASE_TEXT
			if _log_enabled:
				debug_log("No database selected")

func _on_copy_description_button_pressed():
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


func _on_refresh_button_pressed():
	_refresh()
	
func _display_curr_scene_markers():
	var display_time = Stopwatch.new("total")
	var remove_root = Stopwatch.new("remove_root")
	var clear_root = Stopwatch.new("clear_root")
	var add_markers = Stopwatch.new("add_markers")
	var add_root = Stopwatch.new("add_root")
	display_time.start()
	_update_scene_markers = false
	remove_root.start()
	var root_parent = _marker_root.get_parent()
	if root_parent:
		root_parent.remove_child(_marker_root)
	remove_root.stop()
	clear_root.start()
	for child in _marker_root.get_children():
		_marker_root.remove_child(child)
		child.owner = null
	clear_root.stop()
	add_markers.start()
	var markers_to_display = []
	if _scene_marker_map.has(_edited_root_uid):
		markers_to_display = _scene_marker_map.get(_edited_root_uid)
		for marker in markers_to_display:
			_marker_root.add_child(marker)
			marker.owner = _marker_root
	add_markers.stop()
	add_root.start()
	if markers_to_display.size() > 0:
		_edited_root.add_child(_marker_root)
	add_root.stop()
	display_time.stop()
	if _log_enabled:
		var timings := [remove_root, clear_root, add_markers, add_root]
		timings.sort_custom(func(a, b): return a.accum > b.accum)
		debug_log(Time.get_time_string_from_system() + " - Updated task markers (" + str(display_time) + " ms) " + "/ ".join(timings))

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

func _filter(task: SttTaskData) -> bool:
	var type_approved = _is_filter_item_checked(TYPE_ID_MAP, task.task_type)
	var status_approved = _is_filter_item_checked(COMPLETED_ID_MAP, task.fixed)
	if type_approved and status_approved:
		return _filter_scene(task) # _filter_scene is expensive; do it last to allow it to be shortcut out
	return false
	
func _refresh():
	var total_time = Stopwatch.new("total")
	var filter_time = Stopwatch.new("filter")
	var reuse_item_time = Stopwatch.new("reuse_item")
	var reuse_marker_time = Stopwatch.new("reuse_marker")
	var inst_item_time = Stopwatch.new("inst_item")
	var inst_marker_time = Stopwatch.new("inst_marker")
	var setup_item_time = Stopwatch.new("setup_item")
	var setup_marker_time = Stopwatch.new("setup_marker")
	var marker_clear_parent_time = Stopwatch.new("marker_parent")
	var marker_add_child_time = Stopwatch.new("display_markers")
	var remove_item_time = Stopwatch.new("remove_item")
	var remove_marker_time = Stopwatch.new("remove_marker")
	var root_clear_parent = Stopwatch.new("root_clear")
	var root_add = Stopwatch.new("root_add")
	
	total_time.start()
	_is_dirty = false
	%CopyDescriptionButton.disabled = true
	%MarkerButton.disabled = true
	if not _filter_popup:
		return # Task panel not ready to refresh
	#var bug_markers = []

	var displayed_tasks: Array[SttTaskData] = []
	var items = []
	var total_tasks := 0
	var displayed_task_count := 0
	
	if _task_database:
		total_tasks = len(_task_database.tasks)
		
		filter_time.start()
		for task in _task_database.tasks:
			if _filter(task):
				task._generate_description_details()
				displayed_tasks.append(task)
				
		filter_time.stop()
		
		var vbox = %RootVBoxContainer as VBoxContainer
	
		var current_items = vbox.get_children()
			
		displayed_task_count = len(displayed_tasks)

		inst_item_time.start()
		for i in range(displayed_task_count - len(current_items)):
			var node = _item_resource.instantiate()
			vbox.add_child(node)
			#node.owner = self
		inst_item_time.stop()
		
		displayed_tasks.sort_custom(func(a, b):
			var scores = {a: 0, b: 0}
			for task_to_sort in [a, b]:
				var score = 0
				if task_to_sort.fixed:
					score -= 10
				score += task_to_sort.priority
				scores[task_to_sort] = score
			return scores[a] > scores[b])	
		
		root_clear_parent.start()
		_clear_marker_nodes()
		root_clear_parent.stop()
		
		_marker_cache.resize(displayed_task_count)
		
		for i in range(displayed_task_count):
			var task = displayed_tasks[i]

			var marker: BUG_MARKER = BUG_MARKER_SCENE.instantiate()
			setup_marker_time.start()
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
			setup_marker_time.stop_accum()
			
			setup_item_time.start()
			var item = vbox.get_child(i) as ITEM
			if item.task != task:
				item.setup(task)
				for connection in item.select_requested.get_connections():
					item.select_requested.disconnect(connection["callable"])
				item.select_requested.connect(_on_item_select_requested.bind(task))
			if not item.visible:
				item.show()
			setup_item_time.stop_accum()
		
		marker_add_child_time.start()
		_display_curr_scene_markers()
		marker_add_child_time.stop()
		
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
	%TasksInSceneLabel.text = "Markers: " + str(_marker_cache.size())
	
	if _log_enabled:
		total_time.stop()
		var timings := [filter_time, inst_item_time, setup_item_time, remove_item_time, inst_marker_time, setup_marker_time, marker_clear_parent_time, marker_add_child_time, remove_marker_time, root_clear_parent, root_add]
		timings.sort_custom(func(a, b): return a.accum > b.accum)
		debug_log(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(total_time) + " ms) " + "/ ".join(timings))

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

func _on_item_select_requested(task: SttTaskData):
	_selected_task_descr = task.description
	%CopyDescriptionButton.disabled = false
	%MarkerButton.disabled = false
	var marker_data = task.marker_data
	if not _edited_root or not marker_data:
		return
	if marker_data.host_scene_uid != _edited_root_uid:
		var host_scene_path = ResourceUID.get_id_path(marker_data.host_scene_uid)
		if ResourceLoader.exists(host_scene_path):
			EditorInterface.open_scene_from_path(host_scene_path)
		else:
			return


	# TODO From here on, only works in GODOT 4.4 or higher (https://github.com/godotengine/godot/pull/93503)
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

func _on_nodes_popup_menu_id_pressed(id):
	var ed_sc_root = get_tree().edited_scene_root
	if not ed_sc_root:
		return

	if id >= 0 and id <= 5:
		var filter = func(a):
			return false
		match id:
			0: # ALL
				filter = func(a):
					return true
			1: # NONE
				filter = func(a):
					return false
			2: # PENDING
				filter = func(a):
					return not a.fixed and not a.task_type == SttTaskData.TaskTypes.REGRESSION_TEST
			3: # COMPLETED
				filter = func(a):
					return a.fixed and not a.task_type == SttTaskData.TaskTypes.REGRESSION_TEST
			4: # REGRESSION TEST
				filter = func(a):
					return a.task_type == SttTaskData.TaskTypes.REGRESSION_TEST

		var markers: Array[BUG_MARKER] = _get_markers_from_scene(ed_sc_root)
		var selected_nodes: Array[Node] = [] as Array[Node]
		for marker in markers:
			var marker_script = marker as BUG_MARKER
			if filter.call(marker_script) and marker.owner == _edited_root:
				selected_nodes.append(marker)
		_node_selector.set_selection(selected_nodes)

	elif id == 15:
		_node_selector.hide_selected()
	elif id == 16:
		_node_selector.show_selected()
		
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
