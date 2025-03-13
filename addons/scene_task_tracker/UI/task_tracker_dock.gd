@tool
extends Control

const BUG_MARKER = preload("res://addons/scene_task_tracker/task_marker.gd")
const ITEM = preload("res://addons/scene_task_tracker/UI/task_item_bt.gd")
const NODE_SELECTOR_R = preload("res://addons/scene_task_tracker/UI/node_selector.gd")
const REFRESH_PERIOD_MS = 500

var _item_resource = preload("res://addons/scene_task_tracker/UI/task_item_bt.tscn")
var _edited_root: Node
var _is_dirty: bool
var _next_refresh_time: int = 0
var _node_selector: NODE_SELECTOR_R

var _nodes_popup: PopupMenu
var _filter_popup: PopupMenu
var _selected_task_descr: String = ""

var resource_picker: EditorResourcePicker
var select_database_label: Label

var task_database_path: String
var task_database: SttTaskDatabase

const SETTINGS_FILE_PATH := "user://scene_task_tracker.json"
const DATABASE_PATH_SETTING = "database_file_path"

const SELECT_DATABASE_TEXT = "Load or create a task database file above to get started"
const SAVE_DATABASE_TEXT = "Now click the dropdown menu above and save the database to disk"

# TODO: delete me, replace with loading resource from path selected in GUI
#const database_resource = preload("res://tasks/task_database.tres")
@onready var top_bar = %TopBarHBoxContainer

const DEBUG_LOG := true
const REFRESH_DELAY_AFTER_DIRTY = 500

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

const COMPLETED_ICONS = {
	false: preload("res://addons/scene_task_tracker/icons/pending.svg"),
	true: preload("res://addons/scene_task_tracker/icons/checkmark.svg"),
}


func _enter_tree():
	_load_database_path()
	if ResourceLoader.exists(task_database_path):
		task_database = load(task_database_path)
	_node_selector = NODE_SELECTOR_R.new()
	_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS	
	_mark_dirty(&"tasks dock entered scene tree")
	
func _mark_dirty(reason: StringName):
	if not _is_dirty:
		_is_dirty = true
		#if Time.get_ticks_msec() > _next_refresh_time - REFRESH_DELAY_AFTER_DIRTY:
			#_next_refresh_time += REFRESH_DELAY_AFTER_DIRTY
		_next_refresh_time = max(_next_refresh_time, Time.get_ticks_msec() + REFRESH_DELAY_AFTER_DIRTY)
		if DEBUG_LOG:
			print("Task panel dirty: " + reason)
			
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
			#task_database.add_task(task_data)
	#ResourceSaver.save(task_database, task_database.resource_path)
	
#func _add_filter_button(name: String, check: bool, id: int, )

func _set_item_checked(id: int, value: bool = true):
	var index = _filter_popup.get_item_index(id)
	_filter_popup.set_item_checked(index, value)

func _ready():
	resource_picker = EditorResourcePicker.new()
	resource_picker.set_base_type("SttTaskDatabase")
	if task_database:
		resource_picker.edited_resource = task_database
	resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%TopBarHBoxContainer.add_child(resource_picker)
	resource_picker.connect("resource_changed", _on_database_changed)	
		
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
	
	#for i in range(0, _filter_popup.item_count):
		#var name = _filter_popup.get_item_text(i)
		#var id = _filter_popup.get_item_id(i)
		#print("Item " + str(i) + ": " + name + " - id: " + str(id))
		
	
	#var migrate_button := Button.new()
	#migrate_button.text = "MIG"
	#migrate_button.pressed.connect(_migrate_button_pressed)
	#%TopBarMainHBoxContainer.add_child(migrate_button)
	var has_database = task_database != null
	%TopBarMainHBoxContainer.visible = has_database
	%SetDatabaseLabel.visible = not has_database

	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var currently_edited_scene = get_tree().edited_scene_root
	if currently_edited_scene != _edited_root:
		_edited_root = currently_edited_scene
		if not _is_dirty:
			_mark_dirty(&"edited scene root changed")
	if _is_dirty and Time.get_ticks_msec() > _next_refresh_time:
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
		_refresh()

func _on_database_changed(new_database):
	task_database = new_database
	var has_database = task_database != null
	if has_database:
		var database_saved = FileAccess.file_exists(task_database.resource_path)
		if database_saved:
			%TopBarMainHBoxContainer.visible = true
			%SetDatabaseLabel.visible = false
			if DEBUG_LOG:
				print("Selected database: " + task_database.resource_path)
			_save_database_path()
			_mark_dirty(&"database changed")
		else:
			%TopBarMainHBoxContainer.visible = false
			%SetDatabaseLabel.visible = true
			%SetDatabaseLabel.text = SAVE_DATABASE_TEXT
	else:
			%TopBarMainHBoxContainer.visible = false
			%SetDatabaseLabel.visible = true
			%SetDatabaseLabel.text = SELECT_DATABASE_TEXT
			if DEBUG_LOG:
				print("No database selected")

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
	_mark_dirty(&"filter pressed")


func _on_refresh_button_pressed():
	if DEBUG_LOG:
		print("Refresh button pressed")
	_refresh()


#func _enabled_in_interface(marker: BUG_MARKER) -> bool:
	#var show_bug = _filter_popup.is_item_checked(_filter_popup.get_item_index(0))
	#var show_feature = _filter_popup.is_item_checked(_filter_popup.get_item_index(1))
	#var show_tech_impr = _filter_popup.is_item_checked(_filter_popup.get_item_index(2))
	#var show_polish = _filter_popup.is_item_checked(_filter_popup.get_item_index(3))
	#var show_regr_test = _filter_popup.is_item_checked(_filter_popup.get_item_index(4))
	#var show_pending = _filter_popup.is_item_checked(_filter_popup.get_item_index(6))
	#var show_completed = _filter_popup.is_item_checked(_filter_popup.get_item_index(7))
	#var status_filter = show_completed if marker.fixed else show_pending
	#match marker.task_type:
		#BUG_MARKER.TaskTypes.BUG:
			#return status_filter and show_bug
		#BUG_MARKER.TaskTypes.FEATURE:
			#return status_filter and show_feature
		#BUG_MARKER.TaskTypes.TECHNICAL_IMPROVEMENT:
			#return status_filter and show_tech_impr
		#BUG_MARKER.TaskTypes.POLISH:
			#return status_filter and show_polish
		#BUG_MARKER.TaskTypes.REGRESSION_TEST:
			#return status_filter and show_regr_test
		#BUG_MARKER.TaskTypes.UNKNOWN:
			#return status_filter
		#_:
			#return false
			
func _is_filter_item_checked(map: Dictionary, key):
	if map.has(key):
		var id = map[key]
		var index = _filter_popup.get_item_index(id)
		if index > -1:
			var checked = _filter_popup.is_item_checked(index)
			#print("Item " + str(key) + ", id: " + str(id) + ", index: " + str(index) + ", checked: " + str(checked))
			return checked
		else:
			#print("Item " + str(key) + ", id: " + str(id) + ", index: " + str(index) + " has invalid index")
			return false
	#print("Item " + str(key) + " has no entry in map " + str(map))
	return false

func _filter(task: SttTaskData) -> bool:
	var show_type = _is_filter_item_checked(TYPE_ID_MAP, task.task_type)
	var show_status = _is_filter_item_checked(COMPLETED_ID_MAP, task.fixed)
	#var show_pending = _is_filter_item_checked(COMPLETED_ID_MAP, false)
	#var show_completed = _is_filter_item_checked(COMPLETED_ID_MAP, true)
	#var status_filter = show_completed if task.fixed else show_pending
	var result = show_type and show_status
	return result

#func _refresh_old():
	#_is_dirty = false
	#%CopyDescriptionButton.disabled = true
	#if not _filter_popup:
##		print("Task panel not ready to refresh")
		#return
	#var start_time_us = Time.get_ticks_usec()
##	print(Time.get_time_string_from_system() + " - Refreshing Tasks panel")
	#for child in %RootVBoxContainer.get_children():
		#if child is ITEM:
			#var item = child as ITEM
			#item.select_requested.disconnect(_node_selector.on_selection_requested)
		#child.queue_free()
	#var bug_markers := _get_markers_from_scene()
	#var items = []
	#for marker in bug_markers:
		#if _enabled_in_interface(marker):
			#var item: ITEM = _item_resource.instantiate()
			#item.setup(marker)
			#item.select_requested.connect(_node_selector.on_selection_requested)
			#item.select_requested.connect(_on_item_select_requested.bind(marker.description))
			#items.append(item)
	#items.sort_custom(func(a, b): return a.task_priority > b.task_priority)
	#for item in items:
		#%RootVBoxContainer.add_child(item)
		#var separator := HSeparator.new()
		#%RootVBoxContainer.add_child(separator)
	#var total_tasks := 0
	#var pending_tasks = 0
	#if task_database:
		#total_tasks = len(task_database.tasks)
		#pending_tasks = _get_pending_count(task_database.tasks)
	#var pending_in_scene = _get_pending_count(bug_markers)
	#%TotalTasksLabel.text = str(total_tasks)
	#%PendingTasksLabel.text = str(pending_tasks)
	#%TasksInSceneLabel.text = str(len(bug_markers))
	#%PendingTasksInSceneLabel.text = str(pending_in_scene)
	#%ListedTasks.text = str(len(items))
	#var time_taken_us = Time.get_ticks_usec() - start_time_us
	#print(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(float(time_taken_us) / 1000) + " ms)")


func _refresh():
	var start_time_us = Time.get_ticks_usec()
	_is_dirty = false
	%CopyDescriptionButton.disabled = true
	%MarkerButton.disabled = true
	if not _filter_popup:
#		print("Task panel not ready to refresh")
		return
	for child in %RootVBoxContainer.get_children():
		if child is ITEM:
			var item = child as ITEM
			if item.select_requested.is_connected(_node_selector.on_selection_requested):
				item.select_requested.disconnect(_node_selector.on_selection_requested)
		child.queue_free()
	var bug_markers = []
	var items = []
	#var tasks = []
	if task_database:
		for task in task_database.tasks:
			if _filter(task):
				#tasks.append(task)
				var item: ITEM = _item_resource.instantiate()
				item.setup(task)
				item.select_requested.connect(_node_selector.on_selection_requested)
				item.select_requested.connect(_on_item_select_requested.bind(task.description))
				items.append(item)
				
	#for marker in bug_markers:
		#if _enabled_in_interface(marker):
			#var item: ITEM = _item_resource.instantiate()
			#item.setup(marker)
			#item.select_requested.connect(_node_selector.on_selection_requested)
			#item.select_requested.connect(_on_item_select_requested.bind(marker.description))
			#items.append(item)
	#items.sort_custom(func(a, b): return a.task_priority > b.task_priority)
	items.sort_custom(func(a, b):
		var scores = {a.task: 0, b.task: 0}
		for task_to_sort in [a.task, b.task]:
			var score = 0
			if task_to_sort.fixed:
				score -= 10
			score += task_to_sort.priority
			scores[task_to_sort] = score
		return scores[a.task] > scores[b.task])	
	for item in items:
		%RootVBoxContainer.add_child(item)
		#var separator := HSeparator.new()
		#%RootVBoxContainer.add_child(separator)
	var total_tasks := 0
	#var pending_tasks = 0
	if task_database:
		total_tasks = len(task_database.tasks)
		#pending_tasks = _get_pending_count(task_database.tasks)
	%StatsLabel.text = "Tasks: " + str(len(items)) + " / " + str(total_tasks) #+ " (" + str(pending_tasks) + " + " + str(total_tasks - pending_tasks) + ")"
	%TasksInSceneLabel.text = "Markers: " + str(len(bug_markers))
	var time_taken_us = Time.get_ticks_usec() - start_time_us
	if DEBUG_LOG:
		print(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(float(time_taken_us) / 1000) + " ms)")

func _get_pending_count(tasks) -> int:
	var count = 0
	for task in tasks:
		if not (task as SttTaskData).fixed:
			count += 1
	return count
func _on_item_select_requested(_inst_id, description):
	_selected_task_descr = description
	%CopyDescriptionButton.disabled = false
	%MarkerButton.disabled = false

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
					return not a.fixed and not a.task_type == BUG_MARKER.TaskTypes.REGRESSION_TEST
			3: # COMPLETED
				filter = func(a):
					return a.fixed and not a.task_type == BUG_MARKER.TaskTypes.REGRESSION_TEST
			4: # REGRESSION TEST
				filter = func(a):
					return a.task_type == BUG_MARKER.TaskTypes.REGRESSION_TEST

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


func _load_database_path():
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.ModeFlags.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_string)
			if typeof(data) == TYPE_DICTIONARY:
				task_database_path = data[DATABASE_PATH_SETTING]
		else:
			push_error("Could not open settings file " + SETTINGS_FILE_PATH + "for reading")
	
func _save_database_path():
	if DEBUG_LOG:
		print("Saving Scene Task Tracker settings...")
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.ModeFlags.WRITE)
	if file:
		var data = {DATABASE_PATH_SETTING: task_database.resource_path}
		var json_string = JSON.stringify(data)
		file.store_string(json_string)
		file.close()
	else:
		push_error("Could not open settings file " + SETTINGS_FILE_PATH + " for writing")
