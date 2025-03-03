extends CharacterBody3D

var min_flight_speed = 12
var max_flight_speed = 100
var turn_speed = 0.75
var pitch_speed = 0.5
var level_speed = 3.0
var throttle_delta = 50
var acceleration = 6.0

var forward_speed = 0
var target_speed = 0
var grounded = false

var turn_input = 0
var pitch_input = 0

@onready var mesh = $rat
@onready var terrain = $"../terrain"
@onready var water = $"../water"

func get_input(delta):
	water.position = Vector3(position.x, terrain.position.y, position.z)
	
	terrain.position = Vector3(position.x, terrain.position.y, position.z)
	if Input.is_action_pressed("throttle_up"):
		target_speed = min(forward_speed + throttle_delta * delta, max_flight_speed)
	if Input.is_action_pressed("throttle_down"):
		var limit = 0 if grounded else min_flight_speed
		target_speed = max(forward_speed - throttle_delta * delta, limit)


	turn_input = Input.get_axis("roll_right", "roll_left")
	if forward_speed <= 0.5:
		turn_input = 0

	pitch_input =  Input.get_axis("pitch_down", "pitch_up")
	if not grounded:
		pitch_input -= Input.get_action_strength("pitch_down")
	if forward_speed >= min_flight_speed:
		pitch_input += Input.get_action_strength("pitch_up")

func _physics_process(delta):
	get_input(delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(Vector3.UP, turn_input * turn_speed * delta)

	
	if grounded:
		mesh.rotation.z = 0
	else:
		mesh.rotation.z = lerpf(mesh.rotation.z, -turn_input, level_speed * delta)

	forward_speed = lerpf(forward_speed, target_speed, acceleration * delta)

	velocity = -transform.basis.z * forward_speed

	if is_on_floor():
		if not grounded:
			rotation.x = 0
		grounded = true
	else:
		grounded = false
	move_and_slide()
