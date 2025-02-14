extends Node3D

var velocity = Vector3(0.0, 0.0, 0.0)
var move_speed = 40
var change_fac = 40
var mouse_sensitivity = 0.005

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	set_process(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(Input.is_key_pressed(KEY_W)):
		move_speed -= change_fac * delta
	if(Input.is_key_pressed(KEY_S)):
		move_speed += change_fac * delta
	velocity = -transform.basis.z * move_speed * delta
	position += velocity * delta

func _input(event):
	if event is InputEventMouseMotion:
		rotation.y = rotation.y - event.get_relative().x * mouse_sensitivity
		rotation.x = clamp(rotation.x - event.get_relative().y * mouse_sensitivity, -PI/2, PI/2)
			
			
