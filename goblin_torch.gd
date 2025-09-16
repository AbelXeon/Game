# goblin.gd
extends CharacterBody2D

@export_category("Goblin Stats")
@export var wander_speed: float = 40.0
@export var chase_speed: float = 100.0
@export var health: int = 50
@export var attack_damage: int = 10
@export var attack_range: float = 45.0 # How close the goblin needs to be to attack

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var wander_timer: Timer = $WanderTimer
@onready var hitbox_shape = $Hurtbox/CollisionShape2D

enum State { WANDERING, CHASING, ATTACKING, DEAD }
var current_state: State = State.WANDERING

var target: CharacterBody2D = null
var wander_direction = Vector2.ZERO

func _ready():
	add_to_group("enemy")
	# You can connect signals in the editor, no need for code here if you've done that.
	# This is just here as a backup.
	if not wander_timer.timeout.is_connected(_on_wander_timer_timeout):
		wander_timer.timeout.connect(_on_wander_timer_timeout)
	
	pick_new_wander_direction()

func _physics_process(delta: float):
	match current_state:
		State.WANDERING:
			velocity = wander_direction * wander_speed
			if velocity.length() > 0:
				animated_sprite.play("run")
			else:
				animated_sprite.play("idel")

		State.CHASING:
			# --- NEW CHASING LOGIC ---
			if is_instance_valid(target):
				var distance_to_target = global_position.distance_to(target.global_position)

				if distance_to_target > attack_range:
					# If we are too far, move closer.
					var direction = global_position.direction_to(target.global_position)
					velocity = direction * chase_speed
					animated_sprite.play("run")
				else:
					# If we are in range, stop moving and try to attack.
					velocity = Vector2.ZERO
					attack() # This will handle cooldowns itself.
			else:
				# Target is gone, go back to wandering
				change_state(State.WANDERING)
		
		State.ATTACKING:
			velocity = Vector2.ZERO
		
		State.DEAD:
			velocity = Vector2.ZERO
			return

	# Sprite flipping logic
	if current_state != State.ATTACKING:
		if velocity.x < 0:
			animated_sprite.flip_h = true
		elif velocity.x > 0:
			animated_sprite.flip_h = false

	move_and_slide()

# --- STATE MANAGEMENT & AI ---

func change_state(new_state: State):
	if current_state == State.DEAD: return
	current_state = new_state

func _on_wander_timer_timeout():
	pick_new_wander_direction()

func pick_new_wander_direction():
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.ZERO]
	wander_direction = directions.pick_random()

# --- DETECTION ---

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("pet"):
		if current_state != State.CHASING:
			target = body
			change_state(State.CHASING)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		change_state(State.WANDERING)

# --- COMBAT ---

func attack():
	# We can only start an attack if we are ready (not on cooldown) and are currently chasing.
	if current_state != State.CHASING or not attack_cooldown.is_stopped():
		return

	change_state(State.ATTACKING)
	
	if is_instance_valid(target):
		# Face the target when attacking
		if target.global_position.x < global_position.x:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false

		# Play attack animation
		# Note: This example simplifies to one attack animation. Add your directional logic back if needed.
		animated_sprite.play("attack_side")
			
		# --- DAMAGE LOGIC ---
		hitbox_shape.disabled = false
		var bodies_to_damage = $Hitbox.get_overlapping_bodies()
		for body in bodies_to_damage:
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
		# We use call_deferred to wait one physics frame before disabling,
		# which is safer and less likely to miss a fast-moving target.
		hitbox_shape.call_deferred("set", "disabled", true)

func _on_animation_finished():
	# When the attack animation finishes, go back to chasing the target
	# and start the attack cooldown.
	if current_state == State.ATTACKING:
		attack_cooldown.start()
		change_state(State.CHASING)

# --- HEALTH AND DEATH ---

func take_damage(amount: int):
	if current_state == State.DEAD: return
	
	health -= amount
	if health <= 0:
		die()

func die():
	change_state(State.DEAD)
	animated_sprite.play("death") # Make sure you have a "death" animation
	$CollisionShape2D.set_deferred("disabled", true)
	self.remove_from_group("enemy")
	$DetectionArea/CollisionShape2D.disabled = true
	# You can also disable your AttackRangeArea's collision shape here
