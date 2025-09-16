# PlayerHUD.gd
# This script controls the Player's HUD display.
extends CanvasLayer # Or 'extends Control' if that is your root node type

# --- UI NODE REFERENCES ---
# IMPORTANT: Make sure these paths exactly match the nodes in your UI scene tree.
@onready var health_bar: ProgressBar = $playerinfo/HealthBar
@onready var playername: Label = $playerinfo/playername

# _ready() is called once when the node enters the scene tree.
func _ready() -> void:
	# Step 1: Find the player in the game using its group.
	# Remember to add your player to the "player" group in the Node tab.
	var player = get_tree().get_first_node_in_group("player")
	
	# Step 2: If the player is found, connect to its signal.
	if player:
		# The only job in _ready() is to connect the listener.
		# The player will emit a signal right away to give us the starting health.
		player.health_updated.connect(_on_player_health_updated)
		
		# Set the player name on the label.
		playername.text = player.name
	else:
		# If no player is found, print a helpful error message.
		print("ERROR: PlayerHUD could not find a node in the 'player' group.")


# --- SIGNAL HANDLER ---
# This function is called automatically whenever the player's "health_updated" signal is emitted.
# It handles both the initial health display and all future updates.
func _on_player_health_updated(new_health: float, max_health_value: float) -> void:
	# Update the visual bar's maximum and current values.
	health_bar.max_value = max_health_value
	health_bar.value = new_health
