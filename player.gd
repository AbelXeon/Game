# player.gd
extends CharacterBody2D

# --- HEALTH AND STATS ---
@export var max_health: float = 100.0
@export var attack_damage: int = 25 # NEW: Add damage for the player's attack
var current_health: float:
	set(new_value):
		current_health = clamp(new_value, 0, max_health)
		health_updated.emit(current_health, max_health)
signal health_updated(health, max_health)
# --- END HEALTH SECTION ---

@export var speed = 200
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var combo_timer: Timer = $ComboTimer
@onready var attack_area: Area2D = $AttackArea
@onready var sword_slash_1: AudioStreamPlayer = $sword_slash1

var last_direction: String = "down"
var is_attacking: bool = false
var is_dead: bool = false
var combo_step: int = 0

func _ready():
	self.current_health = max_health
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	combo_timer.timeout.connect(_on_combo_timer_timeout)

func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		return
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		get_input_and_move()

	if Input.is_action_just_pressed("ui_accept") and not is_attacking:
		handle_attack()

	if not is_attacking:
		update_movement_animation()

func get_input_and_move():
	velocity = Vector2.ZERO
	if Input.is_action_pressed("right"):
		velocity.x += 1
		last_direction = "right"
	elif Input.is_action_pressed("left"):
		velocity.x -= 1
		last_direction = "left"
	if Input.is_action_pressed("down"):
		velocity.y += 1
		last_direction = "down"
	elif Input.is_action_pressed("up"):
		velocity.y -= 1
		last_direction = "up"
	velocity = velocity.normalized() * speed
	self.velocity = velocity
	move_and_slide()

func handle_attack():
	sword_slash_1.play()
	is_attacking = true
	combo_timer.start()
	
	if combo_step == 0:
		combo_step = 1
		match last_direction:
			"up": animated_sprite_2d.play("attack_up")
			"down": animated_sprite_2d.play("attack_down")
			"left": animated_sprite_2d.play("attack_left")
			"right": animated_sprite_2d.play("attack_right")
	elif combo_step == 1:
		combo_step = 0
		match last_direction:
			"up": animated_sprite_2d.play("attack2_up")
			"down": animated_sprite_2d.play("attack2_down")
			"left": animated_sprite_2d.play("attack2_left")
			"right": animated_sprite_2d.play("attack2_right")

	# --- CORRECTED: Check for hits with the hitbox ---
	attack_area.get_child(0).disabled = false
	
	var bodies_to_hit = attack_area.get_overlapping_bodies()
	for body in bodies_to_hit:
		if body.has_method("take_damage"):
			# NOW we pass the player's damage value to the enemy
			body.take_damage(attack_damage)
			
	attack_area.get_child(0).disabled = true

func update_movement_animation():
	if is_dead:
		return
	if velocity == Vector2.ZERO:
		match last_direction:
			"up": animated_sprite_2d.play("idel_up")
			"down": animated_sprite_2d.play("idel_down")
			"left": animated_sprite_2d.play("idel_left")
			"right": animated_sprite_2d.play("idel_right")
	else:
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0: animated_sprite_2d.play("run_right")
			else: animated_sprite_2d.play("run_left")
		else:
			if velocity.y > 0: animated_sprite_2d.play("run_down")
			else: animated_sprite_2d.play("run_up")

func _on_animation_finished():
	if is_dead:
		return
	if animated_sprite_2d.animation.begins_with("attack"):
		is_attacking = false
		update_movement_animation()

func _on_combo_timer_timeout():
	combo_step = 0

func take_damage(amount: float): # This stays as float to be safe
	if is_dead:
		return
	self.current_health -= amount
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	print("Player has died!")
	animated_sprite_2d.play("death")
