class_name DamageNumbers
extends Node

# Damage number configuration
const DAMAGE_NUMBER_LIFETIME = 2.0  # How long the number stays visible
const DAMAGE_NUMBER_FADE_TIME = 0.5  # How long it takes to fade out
const DAMAGE_NUMBER_FLOAT_DISTANCE = 1.5  # How far up the number floats
const DAMAGE_NUMBER_FLOAT_TIME = 1.5  # How long it takes to float up
const DAMAGE_NUMBER_SPREAD = 0.3  # Random horizontal spread

# Preload the damage number scene
var damage_number_scene: PackedScene

func _ready():
	# Add to group for easy access
	add_to_group("DamageNumbers")
	
	# Try to load the damage number scene if it exists
	if ResourceLoader.exists("res://damage_number.tscn"):
		damage_number_scene = load("res://damage_number.tscn")

# Spawn a damage number above an enemy
func spawn_damage_number(damage: int, damage_type: String, target: Node, position_offset: Vector3 = Vector3.ZERO) -> void:
	if not target or not is_instance_valid(target):
		print("DamageNumbers: Invalid target for damage number")
		return
	
	print("DamageNumbers: Spawning ", damage, " ", damage_type, " damage number for ", target.name)
	
	# Create the damage number node
	var damage_number = _create_damage_number(damage, damage_type)
	if not damage_number:
		print("DamageNumbers: Failed to create damage number node")
		return
	
	# Add to the UI layer (CanvasLayer) instead of the enemy
	var ui_layer = _find_ui_layer()
	if ui_layer:
		print("DamageNumbers: Adding damage number to UI layer: ", ui_layer.name)
		ui_layer.add_child(damage_number)
	else:
		# Fallback: add to target if no UI layer found
		print("DamageNumbers: No UI layer found, adding to target as fallback")
		target.add_child(damage_number)
	
	# Position the damage number above the enemy
	_position_damage_number(damage_number, target, position_offset)
	
	# Start the animation
	_animate_damage_number(damage_number)

# Create a damage number node
func _create_damage_number(damage: int, damage_type: String) -> Control:
	# Try to use the scene if available
	if damage_number_scene:
		var instance = damage_number_scene.instantiate()
		if instance.has_method("setup"):
			instance.setup(damage, damage_type)
		return instance
	
	# Fallback: create programmatically
	return _create_programmatic_damage_number(damage, damage_type)

# Create a damage number programmatically if no scene is available
func _create_programmatic_damage_number(damage: int, damage_type: String) -> Control:
	var container = Control.new()
	container.name = "DamageNumber"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create the damage label
	var label = Label.new()
	label.text = str(damage)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set the color based on damage type
	var damage_color = DamageTypes.get_damage_color_from_string(damage_type)
	label.add_theme_color_override("font_color", damage_color)
	
	# Make the text larger and bold
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Add the label to the container
	container.add_child(label)
	
	# Set the container size to match the label
	label.size = label.get_minimum_size()
	container.size = label.size
	
	# Center the label in the container
	label.position = Vector2.ZERO
	
	return container

# Position the damage number above the enemy
func _position_damage_number(damage_number: Control, target: Node, position_offset: Vector3) -> void:
	if not target is Node3D:
		print("DamageNumbers: Target is not Node3D, cannot position damage number")
		return
	
	var target_pos = target.global_position
	print("DamageNumbers: Target position: ", target_pos)
	
	# Calculate the spawn position above the enemy
	var spawn_height = _get_enemy_height(target)
	var spawn_pos = target_pos + Vector3(0, spawn_height + 0.2, 0) + position_offset  # Reduced from 0.5 to 0.2
	print("DamageNumbers: Spawn position (3D): ", spawn_pos)
	
	# Add some random horizontal spread
	spawn_pos.x += randf_range(-DAMAGE_NUMBER_SPREAD, DAMAGE_NUMBER_SPREAD)
	spawn_pos.z += randf_range(-DAMAGE_NUMBER_SPREAD, DAMAGE_NUMBER_SPREAD)
	
	# Convert 3D position to 2D screen position
	var camera = _get_active_camera()
	if camera:
		var screen_pos = camera.unproject_position(spawn_pos)
		print("DamageNumbers: Screen position (2D): ", screen_pos)
		damage_number.global_position = screen_pos
	else:
		# Fallback: just position it at the target
		print("DamageNumbers: No camera found, using fallback positioning")
		damage_number.global_position = target_pos

# Get the height of an enemy for positioning
func _get_enemy_height(enemy: Node) -> float:
	# Try to get height from collision shape
	var collision_shape = _find_collision_shape(enemy)
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape
		if shape is BoxShape3D:
			return shape.size.y
		elif shape is CapsuleShape3D:
			return shape.radius * 2 + shape.height
		elif shape is SphereShape3D:
			return shape.radius * 2
	
	# Fallback heights based on enemy type
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name().to_lower()
	elif enemy.name:
		enemy_name = enemy.name.to_lower()
	
	if "rat" in enemy_name or "small" in enemy_name:
		return 0.5
	elif "goblin" in enemy_name or "medium" in enemy_name:
		return 1.8
	elif "troll" in enemy_name or "large" in enemy_name:
		return 3.0
	else:
		return 1.5

# Find collision shape in enemy hierarchy
func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		return node
	
	for child in node.get_children():
		var result = _find_collision_shape(child)
		if result:
			return result
	
	return null

# Get the active camera
func _get_active_camera() -> Camera3D:
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_3d()
		if camera:
			print("DamageNumbers: Found active camera: ", camera.name)
		else:
			print("DamageNumbers: No active camera found in viewport")
		return camera
	else:
		print("DamageNumbers: No viewport found")
	return null

# Find the UI layer (CanvasLayer) for damage numbers
func _find_ui_layer() -> CanvasLayer:
	# Look for the HUD specifically (it's a CanvasLayer)
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud is CanvasLayer:
		print("DamageNumbers: Found HUD CanvasLayer for damage numbers")
		return hud
	
	# Fallback: look for any CanvasLayer
	var tree = get_tree()
	if tree:
		var root = tree.root
		if root:
			for child in root.get_children():
				if child is CanvasLayer:
					print("DamageNumbers: Found fallback CanvasLayer: ", child.name)
					return child
	
	print("DamageNumbers: No suitable UI layer found")
	return null

# Animate the damage number
func _animate_damage_number(damage_number: Control) -> void:
	# Start position
	var start_pos = damage_number.global_position
	var end_pos = start_pos + Vector2(0, -DAMAGE_NUMBER_FLOAT_DISTANCE * 50)  # Convert to screen space
	
	# Create the animation tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float upward
	tween.tween_property(damage_number, "global_position", end_pos, DAMAGE_NUMBER_FLOAT_TIME)
	
	# Fade out after a delay
	tween.tween_property(damage_number, "modulate:a", 0.0, DAMAGE_NUMBER_FADE_TIME).set_delay(DAMAGE_NUMBER_LIFETIME - DAMAGE_NUMBER_FADE_TIME)
	
	# Scale up slightly then down
	tween.tween_property(damage_number, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(damage_number, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)
	tween.tween_property(damage_number, "scale", Vector2(0.8, 0.8), DAMAGE_NUMBER_FADE_TIME).set_delay(DAMAGE_NUMBER_LIFETIME - DAMAGE_NUMBER_FADE_TIME)
	
	# Clean up after animation
	tween.tween_callback(func():
		if is_instance_valid(damage_number):
			damage_number.queue_free()
	).set_delay(DAMAGE_NUMBER_LIFETIME)
