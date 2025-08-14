extends Area3D

@export var item: Resource = preload("res://item.tres")  # Make sure the path is correct

var chest_in_range = false  # Track if the player is near the chest
var chest: Node = null      # Reference to the chest node

# Called when the body enters the Area3D
func _on_Chests_Area3D_body_entered(body):
	print("Body entered: ", body)  # Debugging line to check if the signal is triggered
	if body.is_in_group("player"):
		print("Player is near the chest!")  # Debugging line
		chest_in_range = true
		chest = body  # Set the chest reference when player is near

# Called when the body exits the Area3D
func _on_Chests_Area3D_body_exited(body):
	if body.is_in_group("player"):
		print("Player exited the chest area.")  # Debugging line
		chest_in_range = false
		chest = null  # Remove the chest reference when player exits

# Called every frame to check for interaction
func _process(delta):
	if chest_in_range and Input.is_action_just_pressed("ui_accept"):  # Check for 'E' key press
		print("Player received: ", item.name)  # Debugging line to confirm item transfer
		if chest:  # Ensure the chest exists and the player is in range
			# Assuming the player script has a function to add the item to inventory
			var player_script = chest.get_parent()  # Assuming the player is the parent node
			if player_script and player_script.has_method("add_item_to_inventory"):
				player_script.add_item_to_inventory(item)  # Add the item to the player's inventory
