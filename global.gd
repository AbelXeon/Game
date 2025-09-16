# Inventory.gd
# This script manages all items in the game. It is designed to be a global script.
extends Node

## A signal that is emitted whenever the inventory changes. 
## The UI will listen for this to know when it needs to update its visuals.
signal inventory_updated

## This is the core of our inventory. It's a Dictionary.
## It will store items like this: {"meat": 5, "wood": 20, "goblin_ear": 12}
var items: Dictionary = {}


## Adds a certain quantity of an item to the inventory.
func add_item(item_name: String, quantity: int):
	# First, check if we already have some of this item.
	if items.has(item_name):
		# If we do, just add to the existing amount.
		items[item_name] += quantity
	else:
		# If we don't, create a new entry for it.
		items[item_name] = quantity
	
	# IMPORTANT: Emit the signal to notify the UI or other game systems.
	inventory_updated.emit()
	
	# Print a message to the console for debugging, using standard string concatenation.
	print("Added " + str(quantity) + " " + item_name + ". Inventory is now: " + str(items))


## Removes a certain quantity of an item from the inventory. Returns true if successful.
func remove_item(item_name: String, quantity: int) -> bool:
	# First, check if we even have this item and if we have enough.
	if has_item(item_name) and items[item_name] >= quantity:
		# If we do, subtract the amount.
		items[item_name] -= quantity
		
		# If the quantity has dropped to zero, remove the item from our dictionary completely.
		if items[item_name] <= 0:
			items.erase(item_name)
			
		# IMPORTANT: Emit the signal to notify the UI.
		inventory_updated.emit()
		print("Removed " + str(quantity) + " " + item_name + ". Inventory is now: " + str(items))
		return true
	else:
		# If we don't have enough, print an error and return false.
		print("Failed to remove " + str(quantity) + " " + item_name + ". Not enough in inventory.")
		return false


## Checks if an item exists in the inventory.
func has_item(item_name: String) -> bool:
	return items.has(item_name)


## Returns the current count of a specific item. Returns 0 if we don't have it.
func get_item_count(item_name: String) -> int:
	if has_item(item_name):
		return items[item_name]
	return 0
