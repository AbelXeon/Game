# deer.gd
extends CharacterBody2D

@export_category("Movement")
@export var walk_speed: float = 40.0
@export var run_speed: float = 150.0

@export_category("Wandering Behavior")
@export var wander_wait_time_min: float = 4.0
@export var wander_wait_time_max: float = 8.0
@export var wander_walk_time_min: float = 2.0
@export var wander_walk_time_max: float = 5.0

@export_category("Stamina")
@export var max_stamina: float = 5.0 # How many seconds the deer can sprint
@export var stamina_drain_rate: float = 1.0 # Drains 1 stamina per second
@export var stamina_regen_rate: float = 0.8 # Recovers 0.8 stamina per second

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wander_timer: Timer = $WanderTimer

enum State { WANDERING, ALERT, FLEEING, EXHAUSTED, DEAD }
var current_state: State = State.WANDERING

enum WanderState { IDLE, WALKING }
var current_wander_state: WanderState = WanderState.IDLE

var move_direction = Vector2.ZERO
var threat_target: Node2D = null
var last_direction_string: String = "se"
var stamina: float

const MEAT_SCENE = preload("res://Scene/meat.tscn") # Make sure this path is correct

func _ready() -> void:
	stamina = max_stamina
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	start_wandering()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Handle stamina regeneration when not sprinting
	if current_state != State.FLEEING:
		stamina = min(stamina + stamina_regen_rate * delta, max_stamina)

	match current_state:
		State.WANDERING:
			velocity = move_direction * walk_speed
		State.ALERT:
			velocity = Vector2.ZERO
		State.FLEEING:
			# Drain stamina while fleeing
			stamina -= stamina_drain_rate * delta
			if is_instance_valid(threat_target):
				var direction_away = global_position.direction_to(threat_target.global_position).rotated(PI)
				velocity = direction_away * run_speed
				if stamina <= 0:
					change_state(State.EXHAUSTED) # Become tired
			else:
				change_state(State.ALERT)
		State.EXHAUSTED:
			# Still flee, but slower, while recovering stamina
			if is_instance_valid(threat_target):
				var direction_away = global_position.direction_to(threat_target.global_position).rotated(PI)
				velocity = direction_away * walk_speed # Use walk speed
				if stamina >= max_stamina:
					change_state(State.FLEEING) # Fully recovered, sprint again
			else:
				change_state(State.ALERT)

	move_and_slide()
	play_correct_animation()

# --- STATE MANAGEMENT & AI ---

func change_state(new_state: State):
	if current_state == State.DEAD: return
	current_state = new_state
	
	match current_state:
		State.WANDERING:
			wander_timer.start()
		State.ALERT, State.FLEEING, State.EXHAUSTED, State.DEAD:
			wander_timer.stop()

func start_wandering():
	change_state(State.WANDERING)
	current_wander_state = WanderState.IDLE
	_on_wander_timer_timeout()

func _on_wander_timer_timeout():
	if current_state != State.WANDERING: return
	if current_wander_state == WanderState.IDLE:
		current_wander_state = WanderState.WALKING
		move_direction = get_random_diagonal_direction()
		wander_timer.wait_time = randf_range(wander_walk_time_min, wander_walk_time_max)
	else:
		current_wander_state = WanderState.IDLE
		move_direction = Vector2.ZERO
		wander_timer.wait_time = randf_range(wander_wait_time_min, wander_wait_time_max)
	wander_timer.start()

# --- DETECTION ---

func _on_alert_area_body_entered(body: Node2D) -> void:
	if current_state == State.DEAD: return
	if body.is_in_group("player") or body.is_in_group("allies"):
		if current_state == State.WANDERING:
			change_state(State.ALERT)

func _on_alert_area_body_exited(body: Node2D) -> void:
	if current_state == State.DEAD: return
	if body.is_in_group("player") or body.is_in_group("allies"):
		if current_state == State.ALERT:
			start_wandering()

func _on_freak_out_area_body_entered(body: Node2D) -> void:
	if current_state == State.DEAD: return
	if body.is_in_group("player") or body.is_in_group("allies"):
		threat_target = body
		change_state(State.FLEEING)

func _on_freak_out_area_body_exited(body: Node2D) -> void:
	if current_state == State.DEAD: return
	if body == threat_target:
		threat_target = null
		change_state(State.ALERT)

# --- HEALTH AND DEATH ---

# This is the NEW deer function. Note the "amount: int".
func take_damage(amount: int):
	if current_state == State.DEAD: return
	
	# We don't need to use the "amount" variable, but the function needs to accept it.
	change_state(State.DEAD)
	velocity = Vector2.ZERO
	animated_sprite.play("death")
	$CollisionShape2D.set_deferred("disabled", true)

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "death":
		var meat = MEAT_SCENE.instantiate()
		meat.global_position = global_position
		get_parent().add_child(meat)
		queue_free()

# --- ANIMATION LOGIC ---

func play_correct_animation():
	if current_state == State.DEAD: return

	var anim_prefix = "se"
	var anim_suffix = "_idle"

	if current_state == State.FLEEING:
		anim_suffix = "_run"
	# --- NEW: Use WALK animation when exhausted ---
	elif current_state == State.EXHAUSTED:
		anim_suffix = "_walk"
	elif current_state == State.WANDERING and current_wander_state == WanderState.WALKING:
		anim_suffix = "_walk"
	else:
		anim_suffix = "_idle"

	if velocity.length() > 1:
		anim_prefix = get_direction_string_from_velocity(velocity)
		last_direction_string = anim_prefix
	else:
		anim_prefix = last_direction_string

	var anim_name = anim_prefix + anim_suffix
	if animated_sprite.animation != anim_name:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)

func get_direction_string_from_velocity(vel: Vector2) -> String:
	var angle = rad_to_deg(vel.angle()) + 45
	if angle < 0: angle += 360
	if angle >= 0 and angle < 90: return "se"
	if angle >= 90 and angle < 180: return "sw"
	if angle >= 180 and angle < 270: return "nw"
	return "ne"

func get_random_diagonal_direction() -> Vector2:
	var directions = [
		Vector2(-1, -1).normalized(), # NW
		Vector2(1, -1).normalized(),  # NE
		Vector2(-1, 1).normalized(),  # SW
		Vector2(1, 1).normalized()    # SE
	]
	return directions.pick_random()
