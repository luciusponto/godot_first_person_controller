class_name SttTaskItem
extends Resource

#signal task_changed
#
#enum TaskTypes {
#	BUG,
#	FEATURE,
#	TECHNICAL_IMPROVEMENT,
#	POLISH,
#	REGRESSION_TEST,
#	UNKNOWN,
#}

@export var id : int = -1

#@export_multiline var description: String = "Task description here":
#	get:
#		return description
#	set(text):
#		description = text
#		task_changed.emit()
#
#@export_multiline var details: String:
#	get:
#		return details
#	set(text):
#		details = text
#		task_changed.emit()
#
#
#@export var task_type: TaskTypes = TaskTypes.UNKNOWN:
#	get:
#		return task_type
#	set(value):
#		task_type = value
#		task_changed.emit()
#
#
#@export_range(1, 5) var priority: int = 1:
#	get:
#		return priority
#	set(value):
#		priority = value
#		task_changed.emit()
#
#@export var fixed: bool = false:
#	get:
#		return fixed
#	set(value):
#		fixed = value
#		task_changed.emit()
		
func _validate_property(property):
	print("Validating " + property.name)
	if property.name == "id":
		property.usage = PROPERTY_USAGE_READ_ONLY
		

