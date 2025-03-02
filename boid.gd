extends Node3D

var acceleration: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var pos: Vector3 = Vector3.ZERO
var max_speed: float = 70
var max_force: float = 70

var index: int = 0
var team: int = 1
var dead: bool = false
var health: int = 100
var nbors: Array = [] 
var to_player: Vector3 = Vector3.ZERO

@onready var mesh: Node3D = $rocket
var previous_velocity: Vector3 = Vector3.ZERO
var bank_amount: float = 0.2
var bank_speed: float = 0.1

func _ready() -> void:
	initialize_position_and_velocity()

func initialize_position_and_velocity() -> void:
	pos = global_position
	velocity = Vector3(
		randf_range(-5, 5),
		randf_range(-5, 5),
		randf_range(-5, 5)
	)

func _process(delta: float) -> void:
	update_position(delta)
	update_rotation(delta)
	reset_acceleration()

func update_position(delta: float) -> void:
	# Update position vector
	pos = global_position
	
	if(position.y < 5.0):
		velocity += Vector3.UP * 2.0
	if(position.y > 100.0):
		velocity += Vector3.DOWN * 2.0
		
	velocity += (acceleration / 2.0).limit_length(max_speed) * delta
	velocity = velocity.limit_length(max_speed)
	
	# Move the boid
	pos += velocity * delta
	global_position = pos

func update_rotation(delta: float) -> void:
	if velocity.length_squared() > 0.01:
		# Face the movement direction
		look_at(global_position + velocity, Vector3.UP)

		# Calculate banking
		var turn_input = velocity.cross(previous_velocity).y  # Bank based on velocity change
		bank_amount = lerpf(bank_amount, -turn_input * 0.5, bank_speed * delta)  # Smooth banking

		# Apply banking to the mesh
		mesh.rotation.z = bank_amount

	previous_velocity = velocity

func reset_acceleration() -> void:
	acceleration = Vector3.ZERO
