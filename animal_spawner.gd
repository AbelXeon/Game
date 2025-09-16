# AnimalSpawner.gd
extends Node2D

@export_category("Spawner Settings")
## An array of animal scenes this spawner can create (e.g., deer.tscn, wolf.tscn).
@export var scenes_to_spawn: Array[PackedScene]

## The maximum number of creatures this spawner can have alive at one time.
@export var max_population: int = 5

## The minimum time between spawn attempts (in seconds).
@export var spawn_interval_min: float = 10.0
## The maximum time between spawn attempts (in seconds).
@export var spawn_interval_max: float = 20.0

@onready var spawn_area_shape = $SpawnArea/CollisionShape2D
@onready var spawn_timer = $SpawnTimer

# An array to keep track of the creatures we've spawned.
var spawned_creatures = []

func _ready():
	# Connect the timer's timeout signal to our spawning function.
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# Start the first timer cycle.
	set_new_spawn_time()

func set_new_spawn_time():
	var wait_time = randf_range(spawn_interval_min, spawn_interval_max)
	spawn_timer.wait_time = wait_time
	spawn_timer.start()

func _on_spawn_timer_timeout():
	# Before spawning, always set the timer for the next attempt.
	set_new_spawn_time()
	
	# 1. Check if we can spawn more.
	if spawned_creatures.size() >= max_population:
		return # We've hit our population cap, do nothing.

	# 2. Pick a random animal scene and a random position.
	if scenes_to_spawn.is_empty():
		return # Nothing to spawn.
		
	var random_scene = scenes_to_spawn.pick_random()
	var random_position = get_random_point_in_area()

	# 3. Create the animal instance.
	var creature = random_scene.instantiate()
	creature.global_position = random_position
	
	# 4. Add it to the main world scene.
	# We add it as a sibling to the spawner itself.
	get_parent().add_child(creature)
	
	# 5. Keep track of it and connect to its death signal.
	spawned_creatures.append(creature)
	creature.died.connect(_on_creature_died)

func get_random_point_in_area() -> Vector2:
	var rect_extents = spawn_area_shape.shape.size / 2.0
	var random_offset = Vector2(
		randf_range(-rect_extents.x, rect_extents.x),
		randf_range(-rect_extents.y, rect_extents.y)
	)
	# The final position is the center of our spawner plus the random offset.
	return spawn_area_shape.global_position + random_offset

# This function is called when an animal we spawned has died.
func _on_creature_died(creature_that_died):
	var index = spawned_creatures.find(creature_that_died)
	if index != -1:
		spawned_creatures.remove_at(index)
		print("A creature died. Current population: ", spawned_creatures.size())
