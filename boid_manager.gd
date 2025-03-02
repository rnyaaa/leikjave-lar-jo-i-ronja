extends Node3D
const boid = preload("res://boid.tscn")

const COHESION_WEIGHT:   float = 0.4
const SEPARATION_WEIGHT: float = 1.0
const ALIGNMENT_WEIGHT:  float = 0.2
const SEPARATION_DISTANCE: float = 18
const VISUAL_RANGE:        float = 100.0

const SPAWN_DISTANCE:      float = 50.0
const MAX_VIEW_DISTANCE:   float = 100.0

var boid_groups: int = 5
var num_boids: int = 20

var team_counts: Array = [0, 0, 0, 0, 0]
var boids: Array = []
var to_kill: Array = []
var death_timers: Array = []
var player_node: CharacterBody3D
var player_nearby: Array = [0, 0]

func _ready() -> void:
	player_node = $"../Player"
	initialize_boids()

func _process(delta: float) -> void:
	for boid in boids:
		boid.nbors = []
		boid.to_player = boid.position - player_node.position
		calculate_neighbors(boid)
		apply_boid_forces(boid)
		cleanup_boids(boid)
	for boid in boids:
		if boid.dead:
			respawn(boid)

func initialize_boids() -> void:
	for i in boid_groups:
		for j in num_boids:
			var inst = boid.instantiate()
			inst.index = i
			inst.set_position(spawn_outside_view(true))
			add_child(inst)
			inst.nbors = []
			boids.append(inst)

func process_death_timers(delta: float) -> void:
	var new_death_timers = []
	var new_to_kill = []
	for i in death_timers.size():
		death_timers[i] -= delta
		if death_timers[i] < 0.0:
			boids[to_kill[i]].dead = true
		else:
			new_to_kill.append(to_kill[i])
			new_death_timers.append(death_timers[i])
	to_kill = new_to_kill
	death_timers = new_death_timers

func calculate_neighbors(boid) -> void:
	boid.nbors = []
	for i in boids.size():
		if boids[i] != boid and boid.pos.distance_to(boids[i].pos) < VISUAL_RANGE:
			boid.nbors.append(boids[i])

func apply_boid_forces(boid) -> void:
		var cohesion_force = calculate_cohesion(boid)
		var separation_force = calculate_separation(boid)
		var alignment_force = calculate_alignment(boid)
		
		boid.acceleration += separation_force * SEPARATION_WEIGHT
		boid.acceleration += cohesion_force * COHESION_WEIGHT
		boid.acceleration += alignment_force * ALIGNMENT_WEIGHT
		

func cleanup_boids(boid) -> void:
	var player_pos = player_node.position
	var killed = false
	if boid.to_player.length() > MAX_VIEW_DISTANCE:
		killed = true
	if killed:
		to_kill.append(boid.index)
		death_timers.append(0.2)

func calculate_cohesion(boid) -> Vector3:
	var center = Vector3.ZERO
	var count = 0
	for nbor in boid.nbors:
		if nbor.team == boid.team:
			center += nbor.pos
			count += 1
	if count > 0:
		center /= count
		var desired = center - boid.pos
		if desired.length() > 0:
			desired = desired.normalized() * boid.max_speed
			return (desired - boid.velocity).limit_length(boid.max_force)
	var player_pos = player_node.position
	center = (center + Vector3(player_pos.x, player_pos.y, player_node.scale.x)) / 2.0
	return Vector3.ZERO

func calculate_separation(boid) -> Vector3:
	var steering = Vector3.ZERO
	var count = 0
	for nbor in boid.nbors:
		var distance = boid.pos.distance_to(nbor.pos)
		if distance < SEPARATION_DISTANCE:
			var diff = (boid.pos - nbor.pos).normalized()
			diff /= distance  # Weight by distance
			steering += diff
			count += 1
	if count > 0:
		steering /= count
		if steering.length() > 0:
			steering = steering.normalized() * boid.max_speed
			return (steering - boid.velocity).limit_length(boid.max_force)
	return Vector3.ZERO

func calculate_alignment(boid) -> Vector3:
	var average = Vector3.ZERO
	var count = 0
	for nbor in boid.nbors:
		average += nbor.velocity
		count += 1
	if count > 0:
		average /= count
		var player_vel = player_node.velocity
		average = (average + Vector3(player_vel.x, player_vel.y, 0.0)) / 2.0
		if average.length() > 0:
			average = average.normalized() * boid.max_speed
			return (average - boid.velocity).limit_length(boid.max_force)
	return Vector3.ZERO
	
func spawn_outside_view(is_boid) -> Vector3:
	var ppos = player_node.position
	var spawn_dir = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var spawn_dist = randf_range(MAX_VIEW_DISTANCE * 1.1, SPAWN_DISTANCE)
	var spawnx = ppos.x + spawn_dir.x * spawn_dist
	var spawny = ppos.y + spawn_dir.y * spawn_dist
	var spawnz = ppos.z + spawn_dir.z * spawn_dist
	return Vector3(spawnx, spawny, spawnz)

func count_player_nearby(boid):
	var new_player_nearby = [0, 0]
	if boid.to_player.length() < VISUAL_RANGE:
		if boid.team == 0:
			new_player_nearby[0] += 1
		else:
			new_player_nearby[1] += 1
	player_nearby = new_player_nearby
	
func respawn(deadboid):
	var index = deadboid.index
	boids[index].queue_free()
	var inst = boid.instantiate()
	inst.index = index
	inst.set_position(spawn_outside_view(true))
	inst.nbors = []
	boids[index] = inst
	add_child(inst)
