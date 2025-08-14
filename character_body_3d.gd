extends CharacterBody3D

class_name PlayerController

# Input Configuration
@export var move_speed := 5.0
@export var jump_force := 6.0
@export var mouse_sensitivity := 0.002
@export var camera_height := 1.6

# Inventory System
@export var inventory_node: NodePath
var _inventory: Node = null

# Movement Vars
var _gravity := 20.0
var _y_velocity := 0.0
var _can_interact := false
var is_frozen: bool = false  # Flag to prevent movement during combat
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var stats: PlayerStats = PlayerStats.new()

func _ready():
	# Set up player components
	add_child(stats)

	# Create and add the PlayerInventory node
	# This node holds all data for the player's bag and equipment
	_inventory = PlayerInventory.new()
	_inventory.name = "PlayerInventory" # Set a name for easier debugging
	add_child(_inventory)
	
	# Player starts at level 1 with base stats
	# Level 1 = 5 stat points to distribute
	# Player gets: 3 health, 1 mana, 1 strength, 1 intelligence, 1 speed (balanced build)
	stats.set_health(3)      # Increased survivability (was 1)
	stats.set_mana(1)        # Basic spell casting
	stats.set_strength(1)    # Basic melee damage
	stats.set_intelligence(1) # Basic spell power
	stats.set_spell_power(0) # No bonus spell power
	stats.set_dexterity(2)   # Increased dodge/crit chance (was 0)
	stats.set_cunning(0)     # No bonus spell crit/parry
	stats.set_speed(1)       # Basic speed
	
	# Update combat chances and recalculate max stats
	stats._update_combat_chances()
	stats._recalculate_max_stats()
	
	# Start with full health and mana
	stats.health = stats.max_health
	stats.mana = stats.max_mana
	
	# Emit signals to update UI
	stats.emit_signal("health_changed", stats.health, stats.max_health)
	stats.emit_signal("mana_changed", stats.mana, stats.max_mana)
	# Ensure player group membership for interaction scripts
	if not is_in_group("Player"):
		add_to_group("Player")
	
	# Input setup
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Add HUD and connect
	var hud_scene: PackedScene = preload("res://UI/HUD.tscn")
	var hud: HUD = hud_scene.instantiate()
	add_child(hud)
	stats.health_changed.connect(hud.set_health)
	stats.mana_changed.connect(hud.set_mana)
	stats.spirit_changed.connect(hud.set_spirit)
	# initialize bars
	hud.set_health(stats.health, stats.max_health)
	hud.set_mana(stats.mana, stats.max_mana)
	hud.set_spirit(stats.spirit, 10)
	
	# Connect spirit changes to combat UI if it exists
	stats.spirit_changed.connect(_on_spirit_changed)
	
	# Ensure an Inventory UI exists and is connected
	var existing_ui: Node = get_tree().get_first_node_in_group("InventoryUI")
	print("DEBUG: Looking for existing InventoryUI...")
	print("DEBUG: Found existing UI: ", existing_ui)
	if existing_ui == null:
		print("DEBUG: Creating new InventoryUI...")
		var ui_scene: PackedScene = preload("res://Consumables/Inventory_UI.tscn")
		var ui: CanvasLayer = ui_scene.instantiate()
		add_child(ui)
		print("DEBUG: InventoryUI added to player, path: ", ui.get_path())
		# If the UI supports an inventory_node, wire it to our PlayerInventory (path from UI's perspective)
		if _inventory != null:
			ui.set("inventory_node", ui.get_path_to(_inventory))
	else:
		print("Inventory UI already exists!")
	
	# Add Equipment UI
	var equipment_ui_scene: PackedScene = preload("res://UI/EquipmentUI.tscn")
	var equipment_ui_root: CanvasLayer = equipment_ui_scene.instantiate()
	add_child(equipment_ui_root)
	
	# Get the Control child that has the script
	var equipment_ui: Control = equipment_ui_root.get_node("EquipmentRoot")
	if equipment_ui:
		print("Equipment UI added to player!")
		# Store reference to equipment UI for later use
		equipment_ui_root.set_meta("equipment_ui", equipment_ui)
	else:
		print("ERROR: Could not find EquipmentRoot in EquipmentUI!")

func _physics_process(delta):
	# If frozen (in combat), don't process movement
	if is_frozen:
		return
		
	handle_movement(delta)
	
	# Interaction (support default ui_accept and optional interact if present)
	var interact_pressed: bool = Input.is_action_just_pressed("ui_accept")
	if !interact_pressed and InputMap.has_action("interact"):
		interact_pressed = Input.is_action_just_pressed("interact")
	if interact_pressed:
		print("Interact pressed (Frame ", Engine.get_frames_drawn(), ")")
		try_interact()

func _input(event):
	# If frozen (in combat), don't process input
	if is_frozen:
		return
		
	# Quit on ESC
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()
		return
		
	# Toggle inventory with TAB
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		toggle_inventory()
		return
		
	# Toggle equipment UI with C
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		toggle_equipment()
		return
		
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if is_instance_valid(camera):
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, -PI/4, PI/4)
			camera.rotation.y = 0.0
			camera.rotation.z = 0.0

func handle_movement(delta):
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_backwards", "move_forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	
	# Safety check: prevent extreme movement values
	if direction.length() > 10.0:
		print("WARNING: Extreme movement direction detected! Resetting...")
		direction = Vector3.ZERO
	
	# Gravity
	if is_on_floor():
		if _y_velocity < 0.0:
			_y_velocity = 0.0
	else:
		_y_velocity -= _gravity * delta
	
	# Safety check: prevent extreme velocity values
	if _y_velocity > 100.0 or _y_velocity < -100.0:
		print("WARNING: Extreme Y velocity detected! Resetting...")
		_y_velocity = 0.0
	
	# Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_y_velocity = jump_force
		print("Jump pressed")
	
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = _y_velocity
	
	# Safety check: prevent extreme velocity values
	if velocity.length() > 50.0:
		print("WARNING: Extreme velocity detected! Resetting...")
		velocity = Vector3.ZERO
	
	move_and_slide()

func toggle_inventory():
	var ui: Node = get_tree().get_first_node_in_group("InventoryUI")
	print("DEBUG: Looking for InventoryUI group...")
	print("DEBUG: Found UI: ", ui)
	if ui != null:
		print("DEBUG: UI visible before toggle: ", ui.visible)
		if ui.visible:
			ui.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			ui.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			# Refresh inventory display
			if _inventory != null and ui.has_method("update_display"):
				ui.update_display(_inventory.items)
		print("Inventory UI toggled: ", ui.visible)
		print("DEBUG: UI visible after toggle: ", ui.visible)
	else:
		print("ERROR: No Inventory UI found!")
		print("DEBUG: All nodes in InventoryUI group: ", get_tree().get_nodes_in_group("InventoryUI"))

func toggle_equipment():
	"""Toggle the equipment UI visibility"""
	print("DEBUG: toggle_equipment() called")
	var equipment_ui_root = get_node_or_null("EquipmentUI")
	print("DEBUG: EquipmentUI root found: ", equipment_ui_root)
	if equipment_ui_root:
		var equipment_ui = equipment_ui_root.get_node_or_null("EquipmentRoot")
		print("DEBUG: EquipmentRoot found: ", equipment_ui)
		if equipment_ui:
			print("DEBUG: EquipmentRoot visible before toggle: ", equipment_ui.visible)
			if equipment_ui.visible:
				equipment_ui.hide()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				equipment_ui.show()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("Equipment UI toggled: ", equipment_ui.visible)
			print("DEBUG: EquipmentRoot visible after toggle: ", equipment_ui.visible)
		else:
			print("ERROR: EquipmentRoot not found!")
	else:
		print("ERROR: EquipmentUI not found!")

func try_interact():
	print("=== TRY_INTERACT CALLED ===")
	
	var space_state = get_world_3d().direct_space_state
	if !is_instance_valid(camera):
		print("ERROR: Camera not valid!")
		return
	
	# Use sphere query to detect chests within range instead of forward raycast
	var interaction_radius = 3.0
	var player_pos = global_position
	
	# Create a sphere query to find all objects within range
	var sphere_query = PhysicsShapeQueryParameters3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = interaction_radius
	sphere_query.shape = sphere_shape
	sphere_query.transform = Transform3D(Basis(), player_pos)
	sphere_query.collision_mask = 2  # Only detect layer 2 (chest)
	
	var sphere_results = space_state.intersect_shape(sphere_query)
	
	print("=== SPHERE QUERY DEBUG ===")
	print("Found ", sphere_results.size(), " objects within ", interaction_radius, " units")
	
	# Check each object found within range
	for result in sphere_results:
		var collider = result.collider
		print("Checking collider: ", collider.name, " (", collider.get_class(), ")")
		print("Collider groups: ", collider.get_groups())
		
		# Find the actual chest node (could be the collider itself or its parent)
		var chest_node = collider
		
		# If the collider is an Area3D or StaticBody3D, look for the parent chest
		if collider is Area3D or collider is StaticBody3D:
			# Look up the hierarchy to find the chest node
			while chest_node != null and not chest_node.has_method("interact_with_player"):
				chest_node = chest_node.get_parent()
				if chest_node == null:
					break
		
		# Check if we found a valid chest node
		if chest_node and chest_node.has_method("interact_with_player"):
			# Check distance to the chest
			var distance_to_chest = global_position.distance_to(chest_node.global_position)
			if distance_to_chest <= interaction_radius:
				print("Found chest: ", chest_node.name, " at distance: ", distance_to_chest)
				chest_node.interact_with_player(self)
				return
			else:
				print("Chest too far away! Distance: ", distance_to_chest, " (max: ", interaction_radius, ")")
		else:
			print("No valid chest node found with interact_with_player method")
	
	print("No chests found within range or no valid chest nodes")
	print("=== END INTERACTION DEBUG ===")

func receive_item(item: Resource) -> bool:
	if _inventory and _inventory.has_method("add_item_to_bag"):
		var remaining_quantity = _inventory.add_item_to_bag(item, 1)
		if remaining_quantity == 0:
			print("Item added to inventory: ", item.name)
			# The inventory will emit a signal, so no need to call refresh here directly
			return true
		else:
			print("Could not add item to inventory (full?): ", item.name)
			return false
	else:
		printerr("Player has no valid inventory to receive items.")
		return false


# Combat methods
func take_damage(amount: int):
	if not stats:
		return
	stats.take_damage(amount)
	
	# Update combat UI with new status if in combat
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager and combat_manager.has_method("_update_combat_ui_status"):
		combat_manager._update_combat_ui_status()
	
	if stats.health <= 0:
		# End combat if player dies
		if combat_manager and combat_manager.has_method("end_combat"):
			combat_manager.end_combat()
		else:
			# Fallback: respawn at full health if no combat manager
			stats.health = stats.max_health

func get_basic_attack_damage() -> int:
	# Basic attack damage: weapon damage or 1-3 (punch) + strength bonus
	# TODO: Check if weapon equipped and return weapon damage
	# For now, return base punch damage with strength multiplier
	if not stats:
		return 1
	var base_damage = randi_range(1, 3)
	var final_damage = int(base_damage * stats.get_melee_damage_multiplier())
	return final_damage

func get_basic_attack_damage_type() -> String:
	# Basic attack damage type: weapon type or "blunt" (punch)
	# TODO: Check if weapon equipped and return weapon damage type
	# For now, return blunt for punch
	return "blunt"

func get_spell_damage_type() -> String:
	# Spell damage type: always "fire" for fireball
	return "fire"

func get_special_attack_damage() -> int:
	# Haymaker damage: 8-12 (more powerful than basic) + strength bonus
	var base_damage = randi_range(8, 12)
	var final_damage = int(base_damage * stats.get_melee_damage_multiplier())
	return final_damage

func get_special_attack_damage_type() -> String:
	# Haymaker damage type: always "blunt"
	return "blunt"

func get_special_attack_name() -> String:
	# Special attack name: "Haymaker"
	return "Haymaker"

func get_special_attack_cost() -> int:
	# Haymaker spirit cost: 3
	return 3

func get_spirit() -> int:
	# Get current spirit points
	if has_method("get_stats") and get_stats():
		return get_stats().spirit
	return 0

func can_use_special_attack() -> bool:
	# Check if player has enough spirit for special attack
	return get_spirit() >= get_special_attack_cost()

func get_spell_damage() -> int:
	# Fireball damage: 13-18 (ranged magical attack) + intelligence/spell power bonus
	var base_damage = randi_range(13, 18)
	var final_damage = int(base_damage * stats.get_spell_damage_multiplier())
	return final_damage

func get_fire_ignite_chance() -> float:
	# Base 35% chance for fire attacks to ignite
	return 35.0

func is_fire_attack(attack_type: String) -> bool:
	# Check if this attack type is fire-based
	match attack_type:
		"fireball", "fire_weapon_basic", "fire_weapon_special":
			return true
		_:
			return false

func is_defending() -> bool:
	# Check if player is currently defending
	return false  # Will be set by combat system

func set_physics_process_enabled(enabled: bool):
	# Player set_physics_process_enabled called
	if enabled:
		set_physics_process_internal(true)
		is_frozen = false
		# Player physics process ENABLED, unfrozen
	else:
		set_physics_process_internal(false)
		is_frozen = true
		# Player physics process DISABLED, frozen
		
		# When entering combat, face the nearest enemy
		face_nearest_enemy()
	
	# Also control input processing
	set_process_input(enabled)
	# Player input processing
	
	# Control mouse mode for combat
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Mouse mode: CAPTURED (normal gameplay)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Mouse mode: VISIBLE (combat mode)

func _on_chest_detected():
	_can_interact = true
	# Chest detected - can interact!

func _on_chest_lost():
	_can_interact = false
	# Chest lost - cannot interact

func _on_interaction_area_body_entered(body):
	if body.is_in_group("Interactable"):
		_can_interact = true
		# Can interact with body

func _on_interaction_area_body_exited(body):
	if body.is_in_group("Interactable"):
		_can_interact = false
		# Left interaction range

func get_stats() -> PlayerStats:
	if not stats:
		# Creating new stats
		stats = PlayerStats.new()
		add_child(stats)
		# Re-initialize with default values
		stats.set_health(1)
		stats.set_mana(1)
		stats.set_strength(1)
		stats.set_intelligence(1)
		stats.set_spell_power(0)
		stats.set_dexterity(0)
		stats.set_cunning(0)
		stats.set_speed(1)
		stats._update_combat_chances()
		stats._recalculate_max_stats()
		stats.health = stats.max_health
		stats.mana = stats.max_mana
		# Player stats recreated
	return stats

func _on_spirit_changed(spirit_points: int):
	# Update combat UI spirit display if it exists
	var combat_ui = get_tree().get_first_node_in_group("CombatUI")
	if combat_ui and combat_ui.has_method("update_spirit_display"):
		combat_ui.update_spirit_display(spirit_points)

# Combat facing methods
func face_nearest_enemy():
	# Find all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("Enemy")
	if enemies.size() == 0:
		return
	
	# Find the closest enemy
	var nearest_enemy = null
	var nearest_distance = 999999.0
	
	for enemy in enemies:
		if enemy.has_method("get_stats") and enemy.get_stats().health > 0:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	if nearest_enemy:
		face_target(nearest_enemy)

func face_target(target: Node):
	if not target:
		return
	
	# Calculate direction to target
	var direction = (target.global_position - global_position).normalized()
	
	# Only rotate around Y axis (don't tilt up/down)
	direction.y = 0
	direction = direction.normalized()
	
	if direction != Vector3.ZERO:
		# Calculate rotation to face target
		var target_rotation = atan2(direction.x, direction.z)
		
		# Smoothly rotate to face target
		var tween = create_tween()
		tween.tween_property(self, "rotation:y", target_rotation, 0.3)
		
		# Player facing target at rotation
