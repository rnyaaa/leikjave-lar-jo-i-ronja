extends Node3D

var noise_texture: NoiseTexture2D
var noise: FastNoiseLite
const HEIGHT_SCALE = 7.5
const SPAWNGRIDSIZE = 512
const MAX_HEIGHT = 5.0
const MIN_HEIGHT = 0.0
var spawn_noise = FastNoiseLite.new()
var trees = []
const tree = preload("res://blender_meshes/tree1.fbx")
@onready var terrain = $"../terrain"

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	var mat: Material = terrain.get_surface_override_material(0)  # Get the material from the mesh
	if mat == null:
		mat = terrain.mesh.surface_get_material(0)
	noise_texture = mat.get_shader_parameter("noise")
	noise = noise_texture.noise
	for i in SPAWNGRIDSIZE:
		for j in SPAWNGRIDSIZE:
			var range = SPAWNGRIDSIZE / 2.0
			var itpos = Vector2(terrain.position.x - range + i, terrain.position.z - range + j)
			var height = get_height(itpos)
			var chance = spawn_noise.get_noise_2d(itpos.x * 20.0, itpos.y * 20.0) / 2.0 + 0.5
			#if(chance > 0.4):
				#print("... AT POSITION:")
				#print(itpos)
				#print("... AT HEIGHT:")
				#print(height)
				#print("SUCCESS?  ", height > MIN_HEIGHT and height < MAX_HEIGHT and chance > 0.4)
			if height > MIN_HEIGHT and height < MAX_HEIGHT and chance > 0.8:
				spawn_tree(Vector3(itpos.x, height, itpos.y))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	#for tree in trees:
		#print(tree.position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func get_height(pos: Vector2) -> float:
	var local_pos = terrain.global_transform.affine_inverse() * Vector3(pos.x, 0, pos.y)
	var world_pos = Vector2(local_pos.x, local_pos.z) * 0.001
	# Ensure noise_texture is correctly assigned
	if noise_texture == null:
		#print("Error: Noise texture not assigned!")
		return 0.0
	var uv = Vector2(world_pos.x, world_pos.y) * noise_texture.width
	var h = noise_texture.noise.get_noise_2d(uv.x, uv.y)
	h = h / 2.0 + 0.5  # Convert range from [-1,1] to [0,1]

	var magic = 1.2 * h * 1.1 * h * 1.6 * h * HEIGHT_SCALE * h * HEIGHT_SCALE
	var epsilon = 0.0001
	if abs(magic) > epsilon:
		magic = magic - (1.0 / magic)


	h *= magic
	return h - 2.5


func spawn_tree(pos: Vector3) -> void:
	var inst = tree.instantiate()
	inst.set_position(pos)
	add_child(inst)
	trees.append(inst)
