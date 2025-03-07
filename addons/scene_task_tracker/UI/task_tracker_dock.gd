@tool
extends Control

const BUG_MARKER = preload("res://addons/scene_task_tracker/task_marker.gd")
const ITEM = preload("res://addons/scene_task_tracker/UI/task_item_bt.gd")
const NODE_SELECTOR_R = preload("res://addons/scene_task_tracker/UI/node_selector.gd")
const REFRESH_PERIOD_MS = 2000

var _item_resource = preload("res://addons/scene_task_tracker/UI/task_item_bt.tscn")
var _edited_root: Node
var _is_dirty: bool
var _next_refresh_time: int = 0
var _node_selector: NODE_SELECTOR_R

var _nodes_popup: PopupMenu
var _filter_popup: PopupMenu
var _selected_task_descr: String = ""

# TODO: delete me, replace with loading resource from path selected in GUI
const database_resource = preload("res://tasks/task_database.tres")
@onready var top_bar = %TopBarHBoxContainer


func _enter_tree():
	_node_selector = NODE_SELECTOR_R.new()
	_refresh()
	
func _migrate_button_pressed():#
	print("migration logic executing...")
	var markers = _get_markers_from_scene()
	for marker in markers:
		var marker_data = marker as BUG_MARKER
		print("Marker " + marker_data.description)
		var task_data = SttTaskData.new()
		task_data.description = marker_data.description
		task_data.details = marker_data.details
		task_data.task_type = marker_data.task_type
		task_data.priority = marker_data.priority
		task_data.fixed = marker_data.fixed
		var task_marker_data = SttTaskMarkerData.new()
		var marker_node_3D = marker as Node3D
		task_marker_data.position = marker_node_3D.global_position
		task_marker_data.rotation = marker_node_3D.global_rotation_degrees
		task_data.marker_data = task_marker_data
		database_resource.add_task(task_data)

func _ready():
	#var migrate_button = Button.new()
	#migrate_button.text = "Mig"
	#migrate_button.pressed.connect(_migrate_button_pressed)
	#top_bar.add_child(migrate_button)
		
	%RefreshButton.pressed.connect(_refresh)
	%CopyDescriptionButton.pressed.connect(_on_copy_description_button_pressed)
	_nodes_popup = (%NodesMenuButton as MenuButton).get_popup()
	_nodes_popup.id_pressed.connect(_on_nodes_popup_menu_id_pressed)
	_nodes_popup.hide_on_item_selection = false
	_filter_popup = (%FilterMenuButton as MenuButton).get_popup()
	_filter_popup.hide_on_checkable_item_selection = false
	_filter_popup.hide_on_item_selection = false
	_filter_popup.id_pressed.connect(_on_filter_pressed)
	var editor_plugin := EditorPlugin.new()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	_is_dirty = _is_dirty or get_tree().edited_scene_root != _edited_root
	if _is_dirty and Time.get_ticks_msec() > _next_refresh_time:
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
		_refresh()


func _on_copy_description_button_pressed():
	DisplayServer.clipboard_set(_selected_task_descr)


func _on_filter_pressed(id: int):
	if id == 10 or id == 11: # All or Nones
		# Uncheck All or None checkbox
		_filter_popup.set_item_checked(_filter_popup.get_item_index(id), false)

		var checked = id == 10
		for target_id in range(0, 5): # Task types
			var index = _filter_popup.get_item_index(target_id)
			if (
				index > -1 and
				index < _filter_popup.item_count and
				_filter_popup.is_item_checkable(index)
				):
				_filter_popup.set_item_checked(index, checked)
	else:
		var index = _filter_popup.get_item_index(id)
		_filter_popup.toggle_item_checked(index)
	_is_dirty = true


func _on_refresh_button_pressed():
	_refresh()


func _enabled_in_interface(marker: BUG_MARKER) -> bool:
	var show_bug = _filter_popup.is_item_checked(_filter_popup.get_item_index(0))
	var show_feature = _filter_popup.is_item_checked(_filter_popup.get_item_index(1))
	var show_tech_impr = _filter_popup.is_item_checked(_filter_popup.get_item_index(2))
	var show_polish = _filter_popup.is_item_checked(_filter_popup.get_item_index(3))
	var show_regr_test = _filter_popup.is_item_checked(_filter_popup.get_item_index(4))
	var show_pending = _filter_popup.is_item_checked(_filter_popup.get_item_index(6))
	var show_completed = _filter_popup.is_item_checked(_filter_popup.get_item_index(7))
	var status_filter = show_completed if marker.fixed else show_pending
	match marker.task_type:
		BUG_MARKER.TaskTypes.BUG:
			return status_filter and show_bug
		BUG_MARKER.TaskTypes.FEATURE:
			return status_filter and show_feature
		BUG_MARKER.TaskTypes.TECHNICAL_IMPROVEMENT:
			return status_filter and show_tech_impr
		BUG_MARKER.TaskTypes.POLISH:
			return status_filter and show_polish
		BUG_MARKER.TaskTypes.REGRESSION_TEST:
			return status_filter and show_regr_test
		BUG_MARKER.TaskTypes.UNKNOWN:
			return status_filter
		_:
			return false


func _refresh():
	_is_dirty = false
	%CopyDescriptionButton.disabled = true
	if not _filter_popup:
#		print("Task panel not ready to refresh")
		return
	var start_time_us = Time.get_ticks_usec()
#	print(Time.get_time_string_from_system() + " - Refreshing Tasks panel")
	for child in %RootVBoxContainer.get_children():
		if child is ITEM:
			var item = child as ITEM
			item.select_requested.disconnect(_node_selector.on_selection_requested)
		child.queue_free()
	var bug_markers := _get_markers_from_scene()
	var items = []
	for marker in bug_markers:
		if _enabled_in_interface(marker):
			var item: ITEM = _item_resource.instantiate()
			item.setup(marker)
			item.select_requested.connect(_node_selector.on_selection_requested)
			item.select_requested.connect(_on_item_select_requested.bind(marker.description))
			items.append(item)
	items.sort_custom(func(a, b): return a.task_priority > b.task_priority)
	for item in items:
		%RootVBoxContainer.add_child(item)
		var separator := HSeparator.new()
		%RootVBoxContainer.add_child(separator)
	var time_taken_us = Time.get_ticks_usec() - start_time_us
	print(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(float(time_taken_us) / 1000) + " ms)")


func _on_item_select_requested(_inst_id, description):
	_selected_task_descr = description
	%CopyDescriptionButton.disabled = false


func _get_markers_from_scene() -> Array[BUG_MARKER]:
	var scene_tree = get_tree()
	_edited_root = scene_tree.edited_scene_root
	if _edited_root:
		var bug_markers : Array[BUG_MARKER] = [] as Array[BUG_MARKER]
		var edited_tree = _edited_root.get_tree()
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

		var markers: Array[BUG_MARKER] = _get_markers_from_scene()
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
