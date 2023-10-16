@tool
extends Node3D

@export_file("*.tscn") var scene: String
@export var radius: float = 3
@export var axis: Vector3 = Vector3.UP
@export var height: float = 15
@export var max_elem: int = 10
@export var element_offset: float = 0.5
@export var angle_step_deg: float = 30
@export var apply: bool = false:
	set(_value):
		_create_array()
		print(Time.get_time_string_from_system(), " - array applied")


func _create_array_old():
	for child in get_children():
		child.queue_free()
	var scene_res = load(scene)
	var pos: Vector3 = Vector3.RIGHT * radius
	var xform = Transform3D.IDENTITY
	var norm_axis: Vector3 = axis.normalized()
	var rot_step := Quaternion.from_euler(norm_axis * deg_to_rad(angle_step_deg))
	var total_height := 0.0
	var elem_count := 0
	while total_height < height and elem_count < max_elem:
		elem_count += 1
		total_height += element_offset
		var new_inst = scene_res.instantiate() as Node3D
		new_inst.name = "%04d" % elem_count
		add_child(new_inst)
		new_inst.owner = get_tree().edited_scene_root
		new_inst.global_position = global_position + pos
		new_inst.rotate_object_local(norm_axis, (elem_count - 1) * deg_to_rad(angle_step_deg))
		pos += norm_axis * element_offset
		pos = rot_step * pos

func _create_array():
	for child in get_children():
		child.queue_free()
	var scene_res = load(scene)
#	var pos: Vector3 = Vector3.RIGHT * radius
#	var xform = Transform3D.IDENTITY
#	var norm_axis: Vector3 = transform.orthonormalized().basis.y
	var right: Vector3 = basis.x
	var up: Vector3 = basis.y
#	var rot_step := Quaternion.from_euler(norm_axis * deg_to_rad(angle_step_deg))
	var total_height := 0.0
	var elem_count := 0
	while total_height < height and elem_count < max_elem:
		var xform = Transform3D.IDENTITY
		xform.origin = Vector3.RIGHT * radius + Vector3.UP * total_height
		xform = xform.rotated(Vector3.UP, (elem_count - 1) * deg_to_rad(angle_step_deg))
		elem_count += 1
		total_height += element_offset
		var new_inst = scene_res.instantiate() as Node3D
		new_inst.name = "%04d" % elem_count
		add_child(new_inst)
		new_inst.owner = get_tree().edited_scene_root
		new_inst.transform = xform
#		new_inst.position = up * total_height + right * radius
#		new_inst.global_rotate(up, (elem_count - 1) * deg_to_rad(angle_step_deg))
#		new_inst.rotate_object_local(up, (elem_count - 1) * deg_to_rad(angle_step_deg))
#		pos += norm_axis * element_offset
#		pos = rot_step * pos
