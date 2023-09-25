extends Area3D

@export var target: Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	if target:
		print("Target: ", target.name)
		_connect_signals.call_deferred()


func _connect_signals() -> void:
	print("Connecting signal")
	body_entered.connect(_on_body_entered)
	pass


func _on_body_entered(body):
	body.global_position = target.global_position	
