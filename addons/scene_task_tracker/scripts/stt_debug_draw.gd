@tool
## Draws simple shapes in 3D, mainly to provide visual debug information at runtime

# Modified from example at https://github.com/godotengine/godot-docs/issues/5901#issuecomment-1172923676
extends MeshInstance3D

var _depth_test_mat: StandardMaterial3D = StandardMaterial3D.new()
var _no_depth_test_mat: StandardMaterial3D = StandardMaterial3D.new()


func _ready():
	mesh = ImmediateMesh.new()
	_depth_test_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_depth_test_mat.vertex_color_use_as_albedo = true
	_depth_test_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_no_depth_test_mat.no_depth_test = true
	_no_depth_test_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_no_depth_test_mat.vertex_color_use_as_albedo = true
	_no_depth_test_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	StandardMaterial3D.new()

func _process(_delta):
	mesh.clear_surfaces()


## Draw a line without depth test (on top of all opaque geometry)
func overlay_line(begin_pos: Vector3, end_pos: Vector3, color: Color = Color.RED, draw_in_production: bool = false) -> void:
	draw_line(begin_pos, end_pos, color, draw_in_production, true)	


## Draw a line
func draw_line(begin_pos: Vector3, end_pos: Vector3, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	if _begin_surface(Mesh.PRIMITIVE_LINES, draw_in_production, no_depth_test):
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(begin_pos)
		mesh.surface_add_vertex(end_pos)
		mesh.surface_end()


## Draw a sphere without depth test (on top of all opaque geometry)
func overlay_sphere(center: Vector3, radius: float, color: Color = Color.RED, draw_in_production: bool = false) -> void:
	draw_sphere(center, radius, color, draw_in_production, true)	


## Draw a sphere
func draw_sphere(center: Vector3, radius: float = 1.0, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	if not _begin_surface(Mesh.PRIMITIVE_LINE_STRIP, draw_in_production, no_depth_test):
		return
	var step: int = 15
	var sppi: float = 2 * PI / step
	var axes = [
		[Vector3.UP, Vector3.RIGHT],
		[Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.FORWARD, Vector3.UP]
	]
	mesh.surface_set_color(color)
	for axis in axes:
		for i in range(step + 1):
			mesh.surface_add_vertex(center + (axis[0] * radius)
				.rotated(axis[1], sppi * (i % step)))
	mesh.surface_end()
	
func draw_shape(shape: Shape3D, global_tr: Transform3D, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
		if shape is BoxShape3D:
			draw_box_shape(shape as BoxShape3D, global_tr, color, draw_in_production, no_depth_test)
		elif shape is CylinderShape3D:
			draw_cylinder_shape(shape as CylinderShape3D, global_tr, color, draw_in_production, no_depth_test)
		elif shape is CapsuleShape3D:
			draw_capsule_shape(shape as CapsuleShape3D, global_tr, color, draw_in_production, no_depth_test)
			
			
			
func draw_cylinder_shape(shape: CylinderShape3D, global_tr: Transform3D, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	draw_cylinder_xform(shape.radius, shape.height, global_tr, color, draw_in_production, no_depth_test)
	
	
func draw_capsule_shape(shape: CapsuleShape3D, global_tr: Transform3D, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	draw_capsule_xform(shape.radius, shape.height, global_tr, color, draw_in_production, no_depth_test)	
	
func draw_box_shape(box_shape: BoxShape3D, global_tr: Transform3D, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	var ext: Vector3 = box_shape.size * 0.5
	if not _begin_surface(Mesh.PRIMITIVE_LINE_STRIP, draw_in_production, no_depth_test):
		return
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(global_tr * Vector3(-ext.x, ext.y, ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(ext.x, ext.y, ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(ext.x, ext.y, -ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(-ext.x, ext.y, -ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(-ext.x, ext.y, ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(-ext.x, -ext.y, ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(ext.x, -ext.y, ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(ext.x, -ext.y, -ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(-ext.x, -ext.y, -ext.z))
	mesh.surface_add_vertex(global_tr * Vector3(-ext.x, -ext.y, ext.z))
	mesh.surface_end()
	draw_line(global_tr * Vector3(ext.x, ext.y, -ext.z), global_tr * Vector3(ext.x, -ext.y, -ext.z), color, draw_in_production, no_depth_test)
	draw_line(global_tr * Vector3(-ext.x, ext.y, -ext.z), global_tr * Vector3(-ext.x, -ext.y, -ext.z), color, draw_in_production, no_depth_test)
	draw_line(global_tr * Vector3(ext.x, ext.y, ext.z), global_tr * Vector3(ext.x, -ext.y, ext.z), color, draw_in_production, no_depth_test)
	
func draw_box(pos: Vector3, size: Vector3, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	var ext: Vector3 = size * 0.5
	if not _begin_surface(Mesh.PRIMITIVE_LINE_STRIP, draw_in_production, no_depth_test):
		return
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(pos + Vector3(-ext.x, ext.y, ext.z))
	mesh.surface_add_vertex(pos + Vector3(ext.x, ext.y, ext.z))
	mesh.surface_add_vertex(pos + Vector3(ext.x, ext.y, -ext.z))
	mesh.surface_add_vertex(pos + Vector3(-ext.x, ext.y, -ext.z))
	mesh.surface_add_vertex(pos + Vector3(-ext.x, ext.y, ext.z))
	mesh.surface_add_vertex(pos + Vector3(-ext.x, -ext.y, ext.z))
	mesh.surface_add_vertex(pos + Vector3(ext.x, -ext.y, ext.z))
	mesh.surface_add_vertex(pos + Vector3(ext.x, -ext.y, -ext.z))
	mesh.surface_add_vertex(pos + Vector3(-ext.x, -ext.y, -ext.z))
	mesh.surface_add_vertex(pos + Vector3(-ext.x, -ext.y, ext.z))
	mesh.surface_end()
	draw_line(pos + Vector3(ext.x, ext.y, -ext.z), pos + Vector3(ext.x, -ext.y, -ext.z), color, draw_in_production, no_depth_test)
	draw_line(pos + Vector3(-ext.x, ext.y, -ext.z), pos + Vector3(-ext.x, -ext.y, -ext.z), color, draw_in_production, no_depth_test)
	draw_line(pos + Vector3(ext.x, ext.y, ext.z), pos + Vector3(ext.x, -ext.y, ext.z), color, draw_in_production, no_depth_test)
	
	
	
	
	
## Draw a capsule
func draw_capsule(center: Vector3, radius: float = 1.0, height: float = 2.0, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	const steps: int = 15
	const half_disc_steps: int = floori(steps * 0.5)
	var top_center = center + Vector3.UP * ((height - radius) * 0.5)
	var bottom_center = center - Vector3.UP * ((height - radius) * 0.5)
	_draw_disc(steps, 2 * PI, top_center, radius, Vector3.FORWARD, Vector3.UP, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, top_center, radius, Vector3.FORWARD, Vector3.RIGHT, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, top_center, radius, Vector3.RIGHT, -Vector3.FORWARD, color, draw_in_production, no_depth_test)	
	_draw_disc(steps, 2 * PI, bottom_center, radius, Vector3.FORWARD, Vector3.UP, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, bottom_center, radius, Vector3.FORWARD, -Vector3.RIGHT, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, bottom_center, radius, Vector3.RIGHT, Vector3.FORWARD, color, draw_in_production, no_depth_test)
	var vert_lines = 4
	var vert_line_angle_step = PI * 0.5
	for i in range(vert_lines):
		var start = (top_center + (Vector3.FORWARD * radius)
			.rotated(Vector3.UP, i * vert_line_angle_step))
		var end = (bottom_center + (Vector3.FORWARD * radius)
			.rotated(Vector3.UP, i * vert_line_angle_step))
		draw_line(start, end, color, draw_in_production, no_depth_test)
	
	
## Draw a capsule
func draw_capsule_xform(radius: float = 1.0, height: float = 2.0, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	const steps: int = 15
	const half_disc_steps: int = floori(steps * 0.5)
	var xform_rot: Quaternion = xform.basis.get_rotation_quaternion().normalized()
	var up: Vector3 = xform_rot * Vector3.UP
	var forward: Vector3 = xform_rot * Vector3.FORWARD
	var right: Vector3 = xform_rot * Vector3.RIGHT
	var center: Vector3 = xform.origin
	var top_center:Vector3 = center + up * ((height - radius) * 0.5)
	var bottom_center = center - up * ((height - radius) * 0.5)
	_draw_disc(steps, 2 * PI, top_center, radius, forward, up, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, top_center, radius, forward, right, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, top_center, radius, right, -forward, color, draw_in_production, no_depth_test)	
	_draw_disc(steps, 2 * PI, bottom_center, radius, forward, up, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, bottom_center, radius, forward, -right, color, draw_in_production, no_depth_test)	
	_draw_disc(half_disc_steps, PI, bottom_center, radius, right, forward, color, draw_in_production, no_depth_test)
	var vert_lines = 4
	var vert_line_angle_step = PI * 0.5
	for i in range(vert_lines):
		var start = (top_center + (forward * radius)
			.rotated(up, i * vert_line_angle_step))
		var end = (bottom_center + (forward * radius)
			.rotated(up, i * vert_line_angle_step))
		draw_line(start, end, color, draw_in_production, no_depth_test)
	
	
## Draw a cylinder
func draw_cylinder(center: Vector3, radius: float = 1.0, height: float = 2.0, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	const steps: int = 15
	var top_center = center + Vector3.UP * (height * 0.5)
	var bottom_center = center - Vector3.UP * (height * 0.5)
	_draw_disc(steps, 2 * PI, top_center, radius, Vector3.FORWARD, Vector3.UP, color, draw_in_production, no_depth_test)	
	_draw_disc(steps, 2 * PI, bottom_center, radius, Vector3.FORWARD, Vector3.UP, color, draw_in_production, no_depth_test)	
	var vert_lines = 4
	var vert_line_angle_step = PI * 0.5
	for i in range(vert_lines):
		var start = (top_center + (Vector3.FORWARD * radius)
			.rotated(Vector3.UP, i * vert_line_angle_step))
		var end = (bottom_center + (Vector3.FORWARD * radius)
			.rotated(Vector3.UP, i * vert_line_angle_step))
		draw_line(start, end, color, draw_in_production, no_depth_test)

	
## Draw a cylinder
func draw_cylinder_xform(radius: float = 1.0, height: float = 2.0, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	const steps: int = 15
	var xform_rot: Quaternion = xform.basis.get_rotation_quaternion().normalized()
	var forward: Vector3 = xform_rot * Vector3.FORWARD
	var up: Vector3 = xform_rot * Vector3.UP
	var center: Vector3 = xform.origin
	var top_center: Vector3 = center + up * (height * 0.5)
	var bottom_center: Vector3 = center -up * (height * 0.5)
	_draw_disc(steps, 2 * PI, top_center, radius, forward, up, color, draw_in_production, no_depth_test)	
	_draw_disc(steps, 2 * PI, bottom_center, radius, forward, up, color, draw_in_production, no_depth_test)	
	var vert_lines = 4
	var vert_line_angle_step = PI * 0.5
	for i in range(vert_lines):
		var start = (top_center + (forward * radius)
			.rotated(up, i * vert_line_angle_step))
		var end = (bottom_center + (forward * radius)
			.rotated(up, i * vert_line_angle_step))
		draw_line(start, end, color, draw_in_production, no_depth_test)
	
	
func _draw_disc(steps: int, arc_angle: float, center: Vector3, radius: float, origin_axis: Vector3, rotation_axis: Vector3, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	if not _begin_surface(Mesh.PRIMITIVE_LINE_STRIP, draw_in_production, no_depth_test):
		return
	mesh.surface_set_color(color)
	var sppi: float = arc_angle / steps
	for i in range(steps + 1):
		mesh.surface_add_vertex(center + (origin_axis * radius)
			.rotated(rotation_axis, sppi * i))
	mesh.surface_end()
	
	
func draw_capsule_simple(center: Vector3, radius: float = 1.0, height: float = 2.0, color: Color = Color.RED, draw_in_production: bool = false, no_depth_test: bool = false) -> void:
	var sphere_center: Vector3 = center + Vector3.UP * ((height - radius) * 0.5)
	draw_sphere(sphere_center, radius, color, draw_in_production, no_depth_test)
	sphere_center = center - Vector3.UP * ((height - radius) * 0.5)
	draw_sphere(sphere_center, radius, color, draw_in_production, no_depth_test)
	

func _get_material(no_depth_test: bool) -> Material:
	if (no_depth_test):
		return _no_depth_test_mat
	return _depth_test_mat
	
	
func _begin_surface(primitive_type: Mesh.PrimitiveType, draw_in_production: bool = false, no_depth_test: bool = false) -> bool:
	if _skip_draw(draw_in_production):
		return false
	mesh.surface_begin(primitive_type, _get_material(no_depth_test))
	return true
	
	
func _skip_draw(draw_in_production: bool) -> bool:
	return not (OS.is_debug_build() or draw_in_production)
