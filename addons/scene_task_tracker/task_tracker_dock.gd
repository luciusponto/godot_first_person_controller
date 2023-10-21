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


func _enter_tree():
	_node_selector = NODE_SELECTOR_R.new()
	get_tree().tree_changed.connect(_on_tree_changed)
	_refresh()


func _exit_tree():
	get_tree().tree_changed.disconnect(_on_tree_changed)


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
		_:
			result = false
	if marker.fixed:
		result = result and %ShowDoneButton.button_pressed
	return result
	
	
func _refresh():
#	var start_time_us = Time.get_ticks_usec()
	var scene_tree = get_tree()
	print(Time.get_time_string_from_system() + " - Refreshing Tasks panel")
	for child in %RootVBoxContainer.get_children():
		if child is ITEM:
			var item = child as ITEM
			item.select_requested.disconnect(_node_selector.on_selection_requested)
#		else:
#			print("child name: " + child.name + "; type: " + str(typeof(child)))
		child.queue_free()
	_edited_root = scene_tree.edited_scene_root
	var edited_tree = _edited_root.get_tree()
	var bug_markers = edited_tree.get_nodes_in_group("bug_marker")
	for marker in bug_markers:
		if _enabled_in_interface(marker):
			var item: ITEM = _item_resource.instantiate()
			item.setup(marker)
			item.select_requested.connect(_node_selector.on_selection_requested)
			%RootVBoxContainer.add_child(item)
			var separator := HSeparator.new()
			%RootVBoxContainer.add_child(separator)
	_is_dirty = false
#	var time_taken_us = Time.get_ticks_usec() - start_time_us
#	print("Time taken to refresh Tasks panel: " + str(float(time_taken_us) / 1000) + " ms")
	
