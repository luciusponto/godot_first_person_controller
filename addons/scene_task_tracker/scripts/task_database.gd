@tool
class_name SttTaskDatabase
extends Resource

@export var add_new_task := false:
	set(value):
		value = false
		var task = SttTaskData.new()
		add_task(task)

@export var tasks : Array[SttTaskData] = []

@export_group("Debug")
@export_storage var last_task_uid : int = -1

func _get_new_task_id() -> int:
	last_task_uid += 1
	return last_task_uid

func add_task(task : SttTaskData):
	task.task_uid = _get_new_task_id()
	print("adding new task with id " + str(last_task_uid))
	tasks.append(task)
	notify_property_list_changed()
	
func _validate_property(property):
	print("Validating property " + property.name)
	if property.name == "last_task_uid":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
