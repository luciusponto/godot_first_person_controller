@tool
class_name SttTaskDatabase
extends Resource

#const Task = preload("task.gd")

@export var add_new_task := false:
	set(value):
		value = false
		var task = SttTaskItem.new()
		add_task(task)

@export var tasks : Array[SttTaskItem] = []

@export_group("Debug")
@export_storage var last_id : int = -1
@export_storage var previous_tasks_len = 0

func _get_new_task_id() -> int:
	last_id += 1
	return last_id

func add_task(task : SttTaskItem):
	task.id = _get_new_task_id()
	print("adding new task with id " + str(last_id))
	tasks.append(task)
	notify_property_list_changed()
	
func _validate_property(property):
	print("Validating property " + property.name)
	if property.name == "last_id":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
