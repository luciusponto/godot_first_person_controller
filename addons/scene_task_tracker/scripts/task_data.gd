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

const PLUGIN = preload("res://addons/scene_task_tracker/scene_task_tracker.gd")

var _wrapped_description_details: String
var _wrapped_description: String
var _desc_det_initialized := false

static var max_line_length := 60

@export_multiline var description: String = "Task description here":
	get:
		return description
	set(text):
		description = text
		_generate_description_details()
		emit_changed()

@export_multiline var details: String:
	get:
		return details
	set(text):
		details = text
		_generate_description_details()
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
@export var marker_data : SttTaskMarkerData = SttTaskMarkerData.new():
	set(value):
		_disconnect_marker_changed()
		marker_data = value
		marker_data.changed.connect(_on_marker_data_changed)

func _disconnect_marker_changed():
	if marker_data:
		if marker_data.changed.is_connected(_on_marker_data_changed):
			marker_data.changed.disconnect(_on_marker_data_changed)

func _on_marker_data_changed():
	emit_changed()
	
func _wrap(text: String):
#	return text
	if len(text) <= max_line_length:
		return text
	var result = ""
	var start := 0
	var end := -1
	const MAX_IT := 100
	var it := 0
	var max_index = len(text) - 1
	while end < max_index and it < MAX_IT:
		it += 1
		if it == MAX_IT:
			push_warning("max iterations reached: " + description)
		start = end + 1
		end = start + max_line_length
		if end >= max_index:
			end = max_index
			break	
		var pos = text.rfind("\n", end)
		if pos >= start:
			end = pos
			result += text.substr(start, end - start + 1)
			continue
		else:
			pos = text.rfind(" ", end)
			if pos >= start:
				end = pos
				result += text.substr(start, end - start + 1) + "\n"
				continue
		push_warning("bug: this line shouldn't be reachable")
	#end = max(0, min(end, len(text) - 1))
	result += text.substr(start, end - start + 1)
	return result
	
func _generate_description_details():
	_wrapped_description = _wrap(description)
	_wrapped_description_details = 	_wrapped_description
	if not details.is_empty():
		_wrapped_description_details += "\n\nDetails:\n" + _wrap(details)

func _init_desc_det():
	if not _desc_det_initialized:
		_desc_det_initialized = true
		_generate_description_details()
		
func get_wrapped_description():
	_init_desc_det()
	return _wrapped_description
		
func get_wrapped_description_details():
	_init_desc_det()
	return _wrapped_description_details
		
@export var task_uid : int = -1
		
func _validate_property(property):
	if property.name == "task_uid":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
	if property.name == "marker_data":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
