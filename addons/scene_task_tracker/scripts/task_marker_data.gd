@tool
class_name SttTaskMarkerData
extends Resource

@export var host_scene : String = "":
	set(value):
		host_scene = value
		emit_changed()
		
@export var position := Vector3.ZERO:
	set(value):
		position = value
		emit_changed()
		
@export var rotation := Vector3.ZERO:
	set(value):
		rotation = value
		emit_changed()
		
static func vector3_from_dict(dict, key):
	return str_to_var("Vector3" + JSON.parse_string(dict[key]))
		
static func from_dict(dict: Dictionary) -> SttTaskMarkerData:
	if (
		not dict.has("host_scene") or
		not dict.has("position") or
		not dict.has("rotation")
	):
		push_warning("Missing marker data values")
		return null
	var result = SttTaskMarkerData.new()
	result.host_scene = dict["host_scene"]
	result.position = vector3_from_dict(dict, "position")
	result.rotation = vector3_from_dict(dict, "rotation")
	return result

func to_dict() -> Dictionary:
	var dict := {}
	dict["host_scene"] = host_scene
	dict["position"] = JSON.stringify(position)
	dict["rotation"] = JSON.stringify(rotation)
	return dict		

func _validate_property(property):
	if property.name == "position" or property.name == "rotation" or property.name == "host_scene":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
