extends MeshInstance3D

var width: float = 1024.0
var cheese_scene = preload("res://cheese.tscn")  # Ensure it's a PackedScene
var cheeses = []  # Store references to spawned objects

@export var terrain: MeshInstance3D  # Reference to the terrain node
@export var item_scene: PackedScene  # Scene of the object to spawn
@export var num_items: int = 50
@export var spawn_area_size: float = 500.0  # Adjust based on terrain size

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for n in range(num_items):  # Use range() instead of iterating over an int
		var nx = randf_range(-width / 2, width / 2)
		var nz = randf_range(-width / 2, width / 2)
		var ny = randf_range(40, 200)
		
		var tre = cheese_scene.instantiate()
		tre.position = Vector3(nx, ny, nz)
		tre.rotate_y(randf_range(0, TAU))
		
		get_parent().add_child.call_deferred(tre)  # Add the object to the scene

		cheeses.append(tre)  # Store reference to spawned objects

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for obj in cheeses:
		obj.rotate_y(delta)

func _on_body_entered(body):
	print("Body entered: ", body.name)
	if body.is_in_group("player"):  # Ensure the player is in the correct group
		print("Collision with player detected")
		body.scale *= 1.2  # Increase player size
		
		# Find the cheese object and remove it
		var parent = get_parent()
		if parent:
			parent.queue_free()
