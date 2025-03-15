@tool
class_name SttTaskData
extends Resource

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
		emit_changed()

@export_multiline var details: String:
	get:
		return details
	set(text):
		details = text
		emit_changed()


@export var task_type: TaskTypes = TaskTypes.UNKNOWN:
	get:
		return task_type
	set(value):
		task_type = value
		emit_changed()

@export_range(1, 5) var priority: int = 1:
	get:
		return priority
	set(value):
		priority = value
		emit_changed()

@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		emit_changed()

@export_group("Debug")
@export var marker_data : SttTaskMarkerData = SttTaskMarkerData.new()

#:
	#get:
		#return marker_data
	#set(value):
		#emit_changed()
		#_disconnect_marker_changed()
		#marker_data.changed.connect(_on_marker_data_changed)
		
func _disconnect_marker_changed():
	if marker_data:
		if marker_data.changed.is_connected(_on_marker_data_changed):
			marker_data.changed.disconnect(_on_marker_data_changed)

func _on_marker_data_changed():
	emit_changed()
		
@export var task_uid : int = -1
		
func _validate_property(property):
	if property.name == "task_uid":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
	if property.name == "marker_data":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
