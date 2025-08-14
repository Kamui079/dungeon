extends Node3D

@export var chest: Area3D  # Reference to your chest node
@export var player: CharacterBody3D  # Reference to your player

# Chest handling moved into chest.gd to avoid duplication.
# Keep empty methods to satisfy scene connections.

func _ready():
	print("=== DUNGEON DEBUG ===")
	print("Dungeon script _ready() called")
	
	# Check if chest exists
	var chest_node = get_node_or_null("Chest")
	if chest_node:
		print("Chest found in dungeon: ", chest_node.name)
		print("Chest position: ", chest_node.global_position)
		print("Chest groups: ", chest_node.get_groups())
		print("Chest script: ", chest_node.script)
	else:
		print("ERROR: No chest found in dungeon!")
	
	# Check all nodes
	print("All dungeon children:")
	for child in get_children():
		if child.has_method("global_position"):
			print("  - ", child.name, " (", child.get_class(), ") at ", child.global_position)
		else:
			print("  - ", child.name, " (", child.get_class(), ") - no position")
	
	print("=== END DUNGEON DEBUG ===")

func _process(_delta):
	pass

func _try_interact_with_chest():
	pass

func _on_area_3d_chest_body_entered(_body):
	pass

func _on_area_3d_chest_body_exited(_body):
	pass
