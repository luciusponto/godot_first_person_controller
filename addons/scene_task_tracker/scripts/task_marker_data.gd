class_name SttTaskMarkerData
extends Resource

@export var host_scene_uid : int = -1
@export var position := Vector3.ZERO
@export var rotation := Vector3.ZERO

func _validate_property(property):
	if property.name == "position" or property.name == "rotation" or property.name == "host_scene_uid":
		property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
