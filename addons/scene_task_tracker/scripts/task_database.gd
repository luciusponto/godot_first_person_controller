@tool
class_name SttTaskDatabase
extends Resource

const Log = preload("res://addons/scene_task_tracker/scripts/log_util.gd")

static var _static_instance = SttTaskDatabase.new()

@export var tasks : Array[SttTaskData] = []

func _to_dict() -> Dictionary:
	var dict := {}
	dict["class_name"] = "SttTaskDatabase"
	var json_tasks = []
	for task in tasks:
		var task_dict := task.to_dict()
		json_tasks.append(task_dict)
	dict["tasks"] = json_tasks
	return dict

static func _from_dict(dict: Dictionary) -> SttTaskDatabase:
	if not dict.get("class_name", "") == "SttTaskDatabase":
		Log.warn(_static_instance, "Invalid task database file contents")
		return null
	if not dict.has("tasks"):
		Log.warn(_static_instance, "Database has no tasks array")
		return null
	var result := SttTaskDatabase.new()
	var task_dict_array = dict["tasks"]
	for task_dict in task_dict_array:
		var task = SttTaskData.from_dict(task_dict)
		result.tasks.append(task)
	return result
		
static func from_json_file(path: String) -> SttTaskDatabase:
	var json_string := _load_from_file(path)
	var dict = JSON.parse_string(json_string)
	if typeof(dict) == TYPE_DICTIONARY:
		var result := _from_dict(dict)
		if result:
			Log.info(_static_instance, "Task database successfully loaded [%s]" % [path.get_file()])
			return result
	# could not parse database file
	Log.warn(_static_instance, "Invalid database file: %s" % [path])
	return null

static func _save_to_file(content, path: String) -> bool:
	var success = false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		success = file.store_string(content)
		file.flush()
		file.close()
	else:
		Log.warn(_static_instance, "Could not open %s for writing" % [path])
	if success:
		Log.info(_static_instance, "Successfully saved task database [%s]" % [path.get_file()])
	else:
		Log.warn(_static_instance, "Could not save task database [%s]" % [path])
	return success

static func _load_from_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	else:
		Log.warn(_static_instance, "Could not open %s for reading" % [path])
		return ""

func add_task(task : SttTaskData):
	Log.info(self, "Adding new task to db...")
	tasks.append(task)
	notify_property_list_changed()
	emit_changed()

func remove_task(task : SttTaskData):
	Log.info(self, "Removing task from db...")
	tasks.erase(task)
	notify_property_list_changed()
	emit_changed()

func save(json_path: String) -> bool:
	var success = false
	var json_string := JSON.stringify(_to_dict(), "\t", false)
	success = _save_to_file(json_string, json_path)
	return success
