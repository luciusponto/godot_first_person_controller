@tool
class_name SttTaskDatabase
extends Resource

# TODO: remove
@export_tool_button("Export json")
var export_json = _on_export_json_button

# TODO: remove
@export_tool_button("Load json")
var load_json = _on_load_json_button

@export var tasks : Array[SttTaskData] = []

#@export_group("Debug")
#@export_storage var last_task_uid : int = -1

# TODO: remove
const json_path := "res://tasks/task_database.json"

func _to_dict() -> Dictionary:
	var dict := {}
	dict["class_name"] = "SttTaskDatabase"
	#dict["last_task_uid"] = last_task_uid
	
	var json_tasks = []
	for task in tasks:
		var task_dict := task.to_dict()
		json_tasks.append(task_dict)
	dict["tasks"] = json_tasks
	return dict

static func _from_dict(dict: Dictionary) -> SttTaskDatabase:
	if not dict:
		push_warning("Null database dictionary")
		return null
	if not dict.get("class_name", "") == "SttTaskDatabase":
		push_warning("Invalid task database file contents")
		return null
	#if not dict.has("last_task_uid") or not dict.has("tasks"):
	if not dict.has("tasks"):
		push_warning("Database has no tasks array")
		return null
	var result := SttTaskDatabase.new()
	#result.last_task_uid = dict["last_task_uid"]
	var task_dict_array = dict["tasks"]
	for task_dict in task_dict_array:
		var task = SttTaskData.from_dict(task_dict)
		result.tasks.append(task)
	return result
		
# TODO: Remove
func _on_export_json_button():
	save(json_path)

# TODO: Remove
static func _on_load_json_button():
	load(json_path)

static func from_json_file(json_path) -> SttTaskDatabase:
	var json_string := _load_from_file(json_path)
	var dict: Dictionary = JSON.parse_string(json_string)
	var result = _from_dict(dict)
	if result:
		print("SttTaskDatabas loaded")
	else:
		push_warning("Could not parse %s" % [json_path])
	return result

static func _save_to_file(content, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		print("Saving...")
		file.store_string(content)
		file.flush()
		file.close()
	else:
		push_warning("Could not open %s for writing" % [path])

static func _load_from_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	else:
		push_warning("Could not open %s for reading" % [path])
		return ""

#func _get_new_task_id() -> int:
	#last_task_uid += 1
	#return last_task_uid

func add_task(task : SttTaskData):
	print("Adding new task to db")
	#task.task_uid = _get_new_task_id()
	tasks.append(task)
	notify_property_list_changed()
	emit_changed()
	# save() # TODO: move this call into task tracker dock
		
func remove_task(task : SttTaskData):
	print("Removing task from db")
	tasks.erase(task)
	notify_property_list_changed()
	emit_changed()
	# save() # TODO: move this call into task tracker dock

func save(json_path: String):
	var json_string := JSON.stringify(_to_dict(), "\t", false)
	_save_to_file(json_string, json_path)	
	#return
	#if resource_path:
		#ResourceSaver.save(self, resource_path)
	#else:
		#push_warning(resource_name + " task database resource has no file path. Cannot save.")
	
#func _validate_property(property):
	#if property.name == "last_task_uid":
		#property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
		
