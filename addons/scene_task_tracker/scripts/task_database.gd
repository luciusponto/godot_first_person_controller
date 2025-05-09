@tool
@icon("res://addons/scene_task_tracker/icons/marker.svg") 
class_name SttTaskDatabase
extends Resource

@export var tasks : Array[SttTaskData] = []

@export_group("Debug")
@export_storage var last_task_uid : int = -1

func _get_new_task_id() -> int:
	last_task_uid += 1
	return last_task_uid

func add_task(task : SttTaskData):
	print("Adding new task to db")
	task.task_uid = _get_new_task_id()
	tasks.append(task)
	notify_property_list_changed()
	_save()
		
func remove_task(task : SttTaskData):
	print("Removing task from db")
	tasks.erase(task)
	notify_property_list_changed()
	_save()

func _save():
	if resource_path:
		ResourceSaver.save(self, resource_path)
	else:
		push_warning(resource_name + " task database resource has no file path. Cannot save.")
	
func _validate_property(property):
	if property.name == "last_task_uid":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
		
