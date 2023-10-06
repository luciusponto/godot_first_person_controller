extends Control

@export_group("Settings")
@export
var start_visible: bool = false
@export_range(3, 10, 1)
## Total padding digits for float formatting
var float_total_digits: int = 7
@export_range(0, 10, 1)
## Decimal places for float formatting
var float_decimal_places: int = 3

@export_group("Node setup")
@export
var values_panel: Control
@export
var values_vbox: Control

var _float_format: String
var _vector3_format: String
var _item_values: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready():
	values_panel.visible = start_visible
	if float_total_digits < float_decimal_places + 3:
		float_total_digits = float_decimal_places + 3
	_float_format = "%" + str(float_total_digits) + "." + str(float_decimal_places) + "f"
	_vector3_format = "(" + _float_format + ", " + _float_format + ", " + _float_format + ")"
	if not OS.is_debug_build():
		queue_free.call_deferred()
	else:
		var player = get_parent() as LS_MovementController
		player.velocity_updated.connect(_update_value.bind("Velocity"))
		player.is_grounded_updated.connect(_update_value.bind("Grounded"))
		player.speed_updated.connect(_update_value.bind("Max Speed"))
		
		
func _input(event):
	if event is InputEventKey and event.is_pressed():
		if (event as InputEventKey).keycode == KEY_F1:
			values_panel.visible = not values_panel.visible


func set_value(item_name: String, value: String) -> void:
	if not _item_values.has(item_name):
		_add_item(item_name)
	var label = _item_values[item_name]
	label.text = value
	
	
func _update_value(value, item_name: String) -> void:
	var str_value: String
	if value is Vector3:
		str_value = _vector3_format % [value.x, value.y, value.z]
	elif value is float:
		str_value = _float_format % value
	else:
		str_value = str(value)
	set_value(item_name, str_value)


func _add_item(item_name: String) -> void:
	if _item_values.has(item_name):
		return
	var item = HBoxContainer.new()
	values_vbox.add_child(item)
	var title = Label.new()
	item.add_child(title)
	title.owner = get_tree().root
	title.text = item_name + ":"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_stretch_ratio = 1
	title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var value = Label.new()
	item.add_child(value)
	value.owner = get_tree().root
	value.size_flags_stretch_ratio = 2
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_item_values[item_name] = value
