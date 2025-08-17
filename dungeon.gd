extends Node3D

@export var chest: Area3D  # Reference to your chest node
@export var player: CharacterBody3D  # Reference to your player

# Enemy spawning configuration
@export var big_rat_scene: PackedScene
@export var enemy_spawn_positions: Array[Vector3] = [
	Vector3(-2, -1.2, 0),  # Left spawn position
	Vector3(2, -1.2, 0)    # Right spawn position
]

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
	
	# Spawn enemies dynamically
	_spawn_enemies()
	
	# Check all nodes
	print("All dungeon children:")
	for child in get_children():
		if child.has_method("global_position"):
			print("  - ", child.name, " (", child.get_class(), ") at ", child.global_position)
		else:
			print("  - ", child.name, " (", child.get_class(), ") - no position")
	
	print("=== END DUNGEON DEBUG ===")

func _spawn_enemies():
	"""Dynamically spawn enemies at configured positions"""
	print("🎯 Spawning enemies dynamically...")
	
	# Get the enemy spawner node
	var spawner = get_node_or_null("EnemySpawner")
	if not spawner:
		print("❌ EnemySpawner node not found!")
		return
	
	# Load the big rat scene if not already loaded
	if not big_rat_scene:
		big_rat_scene = preload("res://enemies/big_rat.tscn")
		print("🎯 Loaded big_rat.tscn scene")
	
	# Spawn enemies at each position
	for i in range(enemy_spawn_positions.size()):
		var spawn_pos = enemy_spawn_positions[i]
		var enemy_instance = big_rat_scene.instantiate()
		
		# Don't override the enemy's display name - let the enemy system handle it
		# The enemy will use its proper name from enemy_behavior.enemy_name
		# Just set a unique internal name for the node that won't interfere with display
		enemy_instance.name = "Enemy" + str(i + 1)
		
		# Set position
		enemy_instance.global_position = spawn_pos
		
		# Add to spawner
		spawner.add_child(enemy_instance)
		
		print("🎯 Spawned enemy at position ", spawn_pos, " with internal name: ", enemy_instance.name)
	
	print("🎯 Enemy spawning completed!")

func _process(_delta):
	pass

func _try_interact_with_chest():
	pass

func _on_area_3d_chest_body_entered(_body):
	pass

func _on_area_3d_chest_body_exited(_body):
	pass
