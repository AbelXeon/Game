extends CharacterBody2D

@export var speed: float = 30
@export var run_speed_multiplier: float = 2.0
@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 5.0
@export var min_run_time: float = 1.0
@export var max_run_time: float = 3.0
@export var howl_chance: float = 0.1  # 10% chance to howl each idle

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum WolfState { IDLE, RUNNING, HOWL }
var current_state: WolfState = WolfState.IDLE
var target_direction: Vector2 = Vector2.ZERO
var current_movement_vector: Vector2 = Vector2.ZERO
var last_direction_string: String = "se"
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	play_animation(current_movement_vector, WolfState.IDLE)
	set_new_idle_timer()

func _physics_process(delta: float) -> void:
	var current_speed = speed
	if current_state == WolfState.RUNNING:
		current_speed *= run_speed_multiplier
		current_movement_vector = target_direction.normalized() * current_speed
	else:
		current_movement_vector = Vector2.ZERO

	velocity = current_movement_vector
	move_and_slide()

	# Ensure the animation matches current state
	play_animation(current_movement_vector, current_state)

# --- Timers ---
func set_new_idle_timer() -> void:
	current_state = WolfState.IDLE
	if rng.randf() < howl_chance:
		current_state = WolfState.HOWL
		print("Wolf is howling!")
	var idle_time = rng.randf_range(min_idle_time, max_idle_time)
	
	if has_node("MovementTimer"):
		get_node("MovementTimer").queue_free()
	
	var timer = Timer.new()
	timer.name = "MovementTimer"
	add_child(timer)
	timer.wait_time = idle_time
	timer.one_shot = true
	if current_state == WolfState.HOWL:
		timer.timeout.connect(on_howl_timeout)
	else:
		timer.timeout.connect(on_idle_timeout)
	timer.start()

func on_idle_timeout() -> void:
	set_new_run_timer()

func on_howl_timeout() -> void:
	set_new_run_timer()

func set_new_run_timer() -> void:
	current_state = WolfState.RUNNING
	target_direction = pick_random_direction()
	var run_time = rng.randf_range(min_run_time, max_run_time)

	if has_node("MovementTimer"):
		get_node("MovementTimer").queue_free()
	
	var timer = Timer.new()
	timer.name = "MovementTimer"
	add_child(timer)
	timer.wait_time = run_time
	timer.one_shot = true
	timer.timeout.connect(on_run_timeout)
	timer.start()

func on_run_timeout() -> void:
	set_new_idle_timer()

# --- Animation Logic ---
func pick_random_direction() -> Vector2:
	var directions = [
		(Vector2.UP + Vector2.LEFT).normalized(),  # NW
		(Vector2.UP + Vector2.RIGHT).normalized(), # NE
		(Vector2.DOWN + Vector2.LEFT).normalized(), # SW
		(Vector2.DOWN + Vector2.RIGHT).normalized() # SE
	]
	return directions[rng.randi_range(0, directions.size() - 1)]

func play_animation(movement: Vector2, state: WolfState) -> void:
	if not animated_sprite:
		return

	var anim_suffix = ""
	var dir_string = last_direction_string

	match state:
		WolfState.IDLE:
			anim_suffix = "_idle"
		WolfState.RUNNING:
			anim_suffix = "_run"
			dir_string = get_direction_string(movement)
		WolfState.HOWL:
			anim_suffix = "_howl"
			dir_string = get_direction_string(movement)

	last_direction_string = dir_string
	var anim_name = dir_string + anim_suffix
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

# --- Fixed Direction Function ---
func get_direction_string(direction_vector: Vector2) -> String:
	if direction_vector == Vector2.ZERO:
		return last_direction_string

	var horizontal = ""
	var vertical = ""

	if direction_vector.y < 0:
		vertical = "n"  # up
	elif direction_vector.y > 0:
		vertical = "s"  # down

	if direction_vector.x > 0:
		horizontal = "e"  # right
	elif direction_vector.x < 0:
		horizontal = "w"  # left

	# Combine for diagonal
	if vertical != "" and horizontal != "":
		last_direction_string = vertical + horizontal
	elif vertical != "":
		last_direction_string = vertical + "e" if horizontal == "" else vertical + horizontal
	elif horizontal != "":
		last_direction_string = "s" + horizontal if vertical == "" else vertical + horizontal

	return last_direction_string
