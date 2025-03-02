extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add the object to the "pickup" group
	add_to_group("pickup")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
