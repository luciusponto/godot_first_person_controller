@tool
extends Control

const BUG_MARKER = preload("res://addons/scene_task_tracker/task_marker.gd")
const ITEM = preload("res://addons/scene_task_tracker/UI/task_item_bt.gd")
const NODE_SELECTOR_R = preload("res://addons/scene_task_tracker/UI/node_selector.gd")
const REFRESH_PERIOD_MS = 2000

var _item_resource = preload("res://addons/scene_task_tracker/UI/task_item_bt.tscn")
var _edited_root: Node
var _is_dirty: bool
var _scene_changed: bool
var _filters_changed: bool
var _next_refresh_time: int = 0
var _node_selector: NODE_SELECTOR_R

var _show_bug: bool = true
var _show_feature: bool = true
var _show_pending: bool = true
var _show_done: bool = true
var _scene_hide_pending = false
var _scene_hide_completed = false
var _scene_popup: PopupMenu
var _filter_popup: PopupMenu


func _enter_tree():
	_node_selector = NODE_SELECTOR_R.new()
	get_tree().tree_changed.connect(_on_tree_changed)
	_refresh()


func _exit_tree():
	get_tree().tree_changed.disconnect(_on_tree_changed)
	

func _ready():
	_scene_popup = (%SceneMenuButton as MenuButton).get_popup()
	_scene_popup.id_pressed.connect(_on_scene_popup_menu_id_pressed)
	_filter_popup = (%FilterMenuButton as MenuButton).get_popup()
	_filter_popup.hide_on_checkable_item_selection = false
	_filter_popup.hide_on_item_selection = false
	_filter_popup.id_pressed.connect(_on_filter_pressed)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var _is_dirty = (
			_scene_changed and
			get_tree().edited_scene_root != _edited_root or
			_filters_changed
		)
	if _is_dirty and Time.get_ticks_msec() > _next_refresh_time:
		_is_dirty = false
		_scene_changed = false
		_filters_changed = false
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
#		print(Time.get_time_string_from_system() + " - Checking for refresh...")
		_refresh()
	

func _on_tree_changed():
	_scene_changed = true
	
	
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
	_filters_changed = true
	
	
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
		"BUG":
			return status_filter and show_bug
		"FEATURE":
			return status_filter and show_feature
		"TECHNICAL_IMPROVEMENT":
			return status_filter and show_tech_impr
		"POLISH":
			return status_filter and show_polish
		"REGRESSION_TEST":
			return status_filter and show_regr_test
		_:
			return false
		
func _refresh():
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
	var bug_markers = _get_markers_from_scene()
	var items = []
	for marker in bug_markers:
		if _enabled_in_interface(marker):
			var item: ITEM = _item_resource.instantiate()
			item.setup(marker)
			item.select_requested.connect(_node_selector.on_selection_requested)
			items.append(item)
	items.sort_custom(func(a, b): return a.task_priority > b.task_priority)
	for item in items:
		%RootVBoxContainer.add_child(item)
		var separator := HSeparator.new()
		%RootVBoxContainer.add_child(separator)
	_is_dirty = false
	var time_taken_us = Time.get_ticks_usec() - start_time_us
	print(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(float(time_taken_us) / 1000) + " ms)")

func _get_markers_from_scene() -> Array:
	var scene_tree = get_tree()
	_edited_root = scene_tree.edited_scene_root
	if _edited_root:
		var edited_tree = _edited_root.get_tree()
		var bug_markers = edited_tree.get_nodes_in_group("bug_marker")
		return bug_markers
	else:
		return []


func _on_scene_popup_menu_id_pressed(id):
	var filter
	if id == 0 or id == 1: # PENDING
		filter = func(a):
			return not a.fixed and not a.task_type == "REGRESSION_TEST"
	elif id == 3 or id == 4: # COMPLETED
		filter = func(a):
			return a.fixed and not a.task_type == "REGRESSION_TEST"
	elif id == 5 or id == 6: # ALL
		filter = func(a):
			return true
	elif id == 9 or id == 10: # REGRESSION_TEST
		filter = func(a):
			return a.task_type == "REGRESSION_TEST"
	else:
		return
	var visible_value: bool = id == 1 or id == 4 or id == 6 or id == 10
	var markers = _get_markers_from_scene()

	for marker in markers:
		var marker_script = marker as BUG_MARKER
		_set_marker_visible(marker, marker_script, filter, visible_value)


func _set_marker_visible(marker: Node3D, marker_script: BUG_MARKER, filter: Callable, is_visible: bool) -> void:
	if filter.call(marker_script):
		marker.visible = is_visible


func _on_show_bug_button_toggled(button_pressed):
	_show_bug = button_pressed
	_refresh()
	
	
func _on_show_feature_button_toggled(button_pressed):
	_show_feature = button_pressed
	_refresh()
	
	
func _on_show_pending_button_toggled(button_pressed):
	_show_pending = button_pressed
	_refresh()
	
	
func _on_show_done_button_toggled(button_pressed):
	_show_done = button_pressed
	_refresh()
	
	
