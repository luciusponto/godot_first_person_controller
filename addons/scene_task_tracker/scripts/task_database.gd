class_name SttTaskDatabase
extends Resource

@export var tasks : Array[SttTaskItem] = []

@export var last_id : int = -1

#func _validate_property(property):
#	print("validating properties of SttTaskDatabase")
#	if property.name == "last_id":
#		property.usage |= PROPERTY_USAGE_
