extends Node

const debug_menu_path = "res://addons/debug_menu/debug_menu.tscn"
const debug_menu_autoload_name = &"DebugMenu"

const ls_debug_draw_path = "res://addons/ls_debug_draw/ls_debug_draw.tscn"
const ls_debug_draw_autoload_name = &"LSDebugDraw"

const root_path = "/root/"

@export_file var example_scene_path : String

# Called when the node enters the scene tree for the first time.
func _ready():
	if ResourceLoader.exists(example_scene_path):
		_load_if_needed(debug_menu_path, debug_menu_autoload_name)
		_load_if_needed(ls_debug_draw_path, ls_debug_draw_autoload_name)
		var example_scene = _load_scene(example_scene_path, root_path)
	else:
		push_error(example_scene_path + " not found")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _load_if_needed(path : String, autoload_name : StringName):
	var autoload_node = get_node_or_null(root_path + autoload_name)
	if not autoload_node:
		_load_scene(path, root_path, autoload_name)
			
func _load_scene(scene_resource_path : String, parent_path : String, new_name := ""):
	if not ResourceLoader.exists(scene_resource_path):
		push_error("Resource not found: " + scene_resource_path)
		return
	var scene_resource = load(scene_resource_path)
	var scene_instance = scene_resource.instantiate() as Node
	if (new_name.length() > 0):
		scene_instance.name = new_name
	var parent = get_node(parent_path)
	parent.add_child.call_deferred(scene_instance)

	
