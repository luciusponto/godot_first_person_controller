extends CPUParticles3D

@export var area_3d: Area3D
@export var controller: LS_MovementController
@export var model_root: Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	area_3d.body_entered.connect(_on_hit_head)
	
func _physics_process(_delta):
	area_3d.position = Vector3(0, controller._effective_height, 0)
	
func _on_hit_head(_body) -> void:
	rotation = model_root.rotation
	restart()
