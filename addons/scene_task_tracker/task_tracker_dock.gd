@tool
extends Control

const BUG_MARKER = preload("res://addons/first_person_controller/examples/debug/bug_marker.gd")
const ITEM = preload("res://addons/scene_task_tracker/task_item_bt.gd")
const NODE_SELECTOR_R = preload("res://addons/scene_task_tracker/node_selector.gd")
const REFRESH_PERIOD_MS = 2000

var _item_resource = preload("res://addons/scene_task_tracker/task_item_bt.tscn")
var _edited_root: Node
var _is_dirty: bool
var _next_refresh_time: int = 0
var _node_selector: NODE_SELECTOR_R

var _show_bug: bool = true
var _show_feature: bool = true
var _show_pending: bool = true
var _show_done: bool = true
var _scene_hide_pending = false
var _scene_hide_completed = false
var _scene_popup: PopupMenu




func _enter_tree():
	_node_selector = NODE_SELECTOR_R.new()
	get_tree().tree_changed.connect(_on_tree_changed)
	_refresh()


func _exit_tree():
	get_tree().tree_changed.disconnect(_on_tree_changed)
	

func _ready():
	_scene_popup = (%SceneMenuButton as MenuButton).get_popup()
	_scene_popup.id_pressed.connect(_on_scene_popup_menu_id_pressed)
	(%ShowBugButton as Button).toggled.connect(_on_show_bug_button_toggled)
	(%ShowFeatureButton as Button).toggled.connect(_on_show_feature_button_toggled)
	(%ShowPendingButton as Button).toggled.connect(_on_show_pending_button_toggled)
	(%ShowDoneButton as Button).toggled.connect(_on_show_done_button_toggled)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if _is_dirty and Time.get_ticks_msec() > _next_refresh_time:
		_is_dirty = false
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
#		print(Time.get_time_string_from_system() + " - Checking for refresh...")
		if get_tree().edited_scene_root != _edited_root:
			_refresh()
	

func _on_tree_changed():
	_is_dirty = true
	
	
func _on_refresh_button_pressed():
	_refresh()
	
	
func _enabled_in_interface(marker: BUG_MARKER) -> bool:
	var result = true
	match marker.task_type:
		"BUG":
			result = result and %ShowBugButton.button_pressed
		"FEATURE":
			result = result and %ShowFeatureButton.button_pressed
		"TECHNICAL_IMPROVEMENT":
			result = result and %ShowFeatureButton.button_pressed
		"POLISH":
			result = result and %ShowFeatureButton.button_pressed
		_:
			result = false
	if marker.fixed:
		result = result and %ShowDoneButton.button_pressed
	else:
		result = result and %ShowPendingButton.button_pressed
	return result
	
	
func _refresh():
#	var start_time_us = Time.get_ticks_usec()
	print(Time.get_time_string_from_system() + " - Refreshing Tasks panel")
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
#	var time_taken_us = Time.get_ticks_usec() - start_time_us
#	print("Time taken to refresh Tasks panel: " + str(float(time_taken_us) / 1000) + " ms")

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
	
	
