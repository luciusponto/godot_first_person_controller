class_name SttTaskData
extends Resource

signal task_changed

enum TaskTypes {
	BUG,
	FEATURE,
	TECHNICAL_IMPROVEMENT,
	POLISH,
	REGRESSION_TEST,
	UNKNOWN,
	NOTE,
	GENERIC,
}

@export_multiline var description: String = "Task description here":
	get:
		return description
	set(text):
		description = text
		task_changed.emit()

@export_multiline var details: String:
	get:
		return details
	set(text):
		details = text
		task_changed.emit()


@export var task_type: TaskTypes = TaskTypes.UNKNOWN:
	get:
		return task_type
	set(value):
		task_type = value
		task_changed.emit()

@export_range(1, 5) var priority: int = 1:
	get:
		return priority
	set(value):
		priority = value
		task_changed.emit()

@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		task_changed.emit()

@export_group("Debug")
@export var marker_data : SttTaskMarkerData = SttTaskMarkerData.new()
@export var task_uid : int = -1
		
func _validate_property(property):
	if property.name == "task_uid":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
	if property.name == "marker_data":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
