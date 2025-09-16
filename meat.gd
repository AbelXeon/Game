# Meat.gd
extends Area2D

# This is a placeholder for now. The player will call this function.
func collect():
	print("Meat collected!")
	queue_free() # The meat disappears after being collected.
