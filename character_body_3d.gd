extends CharacterBody3D

# Input Configuration
@export var move_speed := 5.0
@export var jump_force := 6.0
@export var mouse_sensitivity := 0.002
@export var camera_height := 1.6

# Inventory System
var _inventory: Node = null

# Movement Vars
var _gravity := 20.0
var _y_velocity := 0.0
var _can_interact := false
var is_frozen: bool = false
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var stats: PlayerStats = PlayerStats.new()

func _ready():
	# Player Stats and Data Setup
	add_child(stats)
	_inventory = PlayerInventory.new()
	_inventory.name = "PlayerInventory"
	add_child(_inventory)
	
	# Your stat initialization code
	stats.set_health(3); stats.set_mana(1); stats.set_strength(1); stats.set_intelligence(1)
	stats.set_spell_power(0); stats.set_dexterity(2); stats.set_cunning(0); stats.set_speed(1)
	stats._update_combat_chances(); stats._recalculate_max_stats()
	stats.health = int(stats.max_health * 0.9); stats.mana = int(stats.max_mana * 0.9)
	stats.emit_signal("health_changed", stats.health, stats.max_health)
	stats.emit_signal("mana_changed", stats.mana, stats.max_mana)
	
	if not is_in_group("Player"):
		add_to_group("Player")
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# HUD Setup
	var hud_scene: PackedScene = preload("res://UI/HUD.tscn")
	var hud: HUD = hud_scene.instantiate()
	add_child(hud)
	stats.health_changed.connect(hud.set_health); stats.mana_changed.connect(hud.set_mana)
	stats.spirit_changed.connect(hud.set_spirit); hud.set_health(stats.health, stats.max_health)
	hud.set_mana(stats.mana, stats.max_mana); hud.set_spirit(stats.spirit, 10)
	stats.spirit_changed.connect(_on_spirit_changed)
	
	# --- THIS IS THE CORRECTED UI SETUP ---
	
	# 1. Instance the Normal Inventory UI
	var inventory_ui_scene: PackedScene = preload("res://Consumables/Inventory_UI.tscn") #<-- CHECK THIS PATH
	var inventory_ui_instance = inventory_ui_scene.instantiate()
	add_child(inventory_ui_instance)
	
	# --- THIS IS THE FIX ---
	# First, we get the correct child node that has the script...
	# !! IMPORTANT: Make sure your node is named "InventoryUIRoot" !!
	var inventory_ui_control = inventory_ui_instance.get_node("InventoryUIRoot")
	# ...then we set the variable on that node.
	if _inventory and inventory_ui_control:
		inventory_ui_control.player_inventory = _inventory

	# 2. Instance the Equipment UI
	var equipment_ui_scene: PackedScene = preload("res://UI/EquipmentUI.tscn")
	var equipment_ui_instance = equipment_ui_scene.instantiate()
	add_child(equipment_ui_instance)
	
	# This part was already correct: it gets the child node "EquipmentRoot" first.
	if _inventory:
		var equipment_ui_control = equipment_ui_instance.get_node("EquipmentRoot")
		if equipment_ui_control:
			equipment_ui_control.player_inventory = _inventory
	
	# Add starter equipment for testing
	_add_starter_equipment()

# --- Getter Methods ---
func get_stats() -> PlayerStats:
	if not stats:
		stats = PlayerStats.new(); add_child(stats)
		stats.set_health(1); stats.set_mana(1); stats.set_strength(1); stats.set_intelligence(1)
		stats.set_spell_power(0); stats.set_dexterity(0); stats.set_cunning(0); stats.set_speed(1)
		stats._update_combat_chances(); stats._recalculate_max_stats()
		stats.health = stats.max_health; stats.mana = stats.max_mana
	return stats

func get_spirit() -> int:
	if has_method("get_stats") and get_stats(): return get_stats().spirit
	return 0

# --- Movement and Input Processing ---
func _physics_process(delta):
	if is_frozen: return
	handle_movement(delta)
	
	var interact_pressed: bool = Input.is_action_just_pressed("ui_accept")
	if !interact_pressed and InputMap.has_action("interact"):
		interact_pressed = Input.is_action_just_pressed("interact")
	if interact_pressed: try_interact()

func _input(event):
	if is_frozen: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if is_instance_valid(camera):
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, -PI/4, PI/4)
			camera.rotation.y = 0.0; camera.rotation.z = 0.0

func handle_movement(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_backwards", "move_forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	
	if is_on_floor():
		if _y_velocity < 0.0: _y_velocity = 0.0
	else: _y_velocity -= _gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor(): _y_velocity = jump_force
	
	velocity.x = direction.x * move_speed; velocity.z = direction.z * move_speed; velocity.y = _y_velocity
	move_and_slide()

func try_interact():
	var space_state = get_world_3d().direct_space_state
	if !is_instance_valid(camera): return
	var interaction_radius = 3.0; var player_pos = global_position
	var sphere_query = PhysicsShapeQueryParameters3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = interaction_radius
	sphere_query.shape = sphere_shape
	sphere_query.transform = Transform3D(Basis(), player_pos)
	sphere_query.collision_mask = 2
	var sphere_results = space_state.intersect_shape(sphere_query)
	for result in sphere_results:
		var collider = result.collider; var chest_node = collider
		while chest_node != null and not chest_node.has_method("interact_with_player"):
			chest_node = chest_node.get_parent()
			if chest_node == null: break
		if chest_node and chest_node.has_method("interact_with_player"):
			if global_position.distance_to(chest_node.global_position) <= interaction_radius:
				chest_node.interact_with_player(self); return

func receive_item(item: Resource) -> bool:
	if _inventory and _inventory.has_method("add_item_to_bag"):
		var remaining_quantity = _inventory.add_item_to_bag(item, 1)
		return remaining_quantity == 0
	printerr("Player has no valid inventory to receive items.")
	return false

func receive_gold(amount: int):
	"""Receive gold from enemy drops or other sources"""
	if stats and stats.has_method("add_gold"):
		stats.add_gold(amount)
	else:
		pass

func heal(amount: int):
	if stats: stats.heal(amount)
func restore_mana(amount: int):
	if stats: stats.restore_mana(amount)

# --- Combat Methods ---
func take_damage(amount: int):
	if not stats: return
	stats.take_damage(amount)
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager and combat_manager.has_method("_update_combat_ui_status"):
		combat_manager._update_combat_ui_status()
	if stats.health <= 0:
		if combat_manager and combat_manager.has_method("end_combat"):
			combat_manager.end_combat()
		else: stats.health = stats.max_health
func get_basic_attack_damage() -> int:
	if not stats: return 1
	var base_damage = randi_range(1, 3)
	return int(base_damage * stats.get_melee_damage_multiplier())
func get_basic_attack_damage_type() -> String: return "blunt"
func get_spell_damage_type() -> String: return "fire"
func get_special_attack_damage() -> int:
	var base_damage = randi_range(8, 12)
	return int(base_damage * stats.get_melee_damage_multiplier())
func get_special_attack_damage_type() -> String: return "blunt"
func get_special_attack_name() -> String: return "Haymaker"
func get_special_attack_cost() -> int: return 3
func can_use_special_attack() -> bool: return get_spirit() >= get_special_attack_cost()
func get_spell_damage() -> int:
	var base_damage = randi_range(13, 18)
	return int(base_damage * stats.get_spell_damage_multiplier())
func get_fire_ignite_chance() -> float: return 35.0
func is_fire_attack(attack_type: String) -> bool:
	match attack_type:
		"fireball", "fire_weapon_basic", "fire_weapon_special": return true
		_: return false
func is_defending() -> bool: return false
func set_physics_process_enabled(enabled: bool):
	set_physics_process_internal(enabled)
	is_frozen = not enabled
	set_process_input(enabled)
	if enabled: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		face_nearest_enemy()

# --- Signal Connections & Helpers ---
func _on_chest_detected(): _can_interact = true
func _on_chest_lost(): _can_interact = false
func _on_interaction_area_body_entered(body):
	if body.is_in_group("Interactable"): _can_interact = true
func _on_interaction_area_body_exited(body):
	if body.is_in_group("Interactable"): _can_interact = false
func _on_spirit_changed(spirit_points: int):
	var combat_ui = get_tree().get_first_node_in_group("CombatUI")
	if combat_ui and combat_ui.has_method("update_spirit_display"):
		combat_ui.update_spirit_display(spirit_points)
func face_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("Enemy")
	if enemies.is_empty(): return
	var nearest_enemy = null; var nearest_distance = INF
	for enemy in enemies:
		if enemy.has_method("get_stats") and enemy.get_stats().health > 0:
			# Get enemy position - check if it's a Node3D or has a parent with global_position
			var enemy_pos = Vector3.ZERO
			if enemy is Node3D:
				enemy_pos = enemy.global_position
			elif enemy.get_parent() and enemy.get_parent() is Node3D:
				enemy_pos = enemy.get_parent().global_position
			else:
				continue  # Skip enemies without valid positions
			
			var distance = global_position.distance_to(enemy_pos)
			if distance < nearest_distance:
				nearest_distance = distance; nearest_enemy = enemy
	if nearest_enemy: face_target(nearest_enemy)
func face_target(target: Node):
	if not target: return
	
	# Get target position - check if it's a Node3D or has a parent with global_position
	var target_pos = Vector3.ZERO
	if target is Node3D:
		target_pos = target.global_position
	elif target.get_parent() and target.get_parent() is Node3D:
		target_pos = target.get_parent().global_position
	else:
		return
	
	var direction = (target_pos - global_position).normalized()
	direction.y = 0
	if direction.is_normalized():
		var target_rotation = atan2(direction.x, direction.z)
		var tween = create_tween()
		tween.tween_property(self, "rotation:y", target_rotation, 0.3)

func orient_camera_toward(target: Node):
	"""Orient the camera toward a target (used for combat orientation)"""
	if not target or not camera:
		return
	

	
	# Get the direction from player to target
	var target_pos = Vector3.ZERO
	if target is Node3D:
		target_pos = target.global_position
	elif target.get_parent() and target.get_parent() is Node3D:
		target_pos = target.get_parent().global_position
	else:
		return
	
	var direction = (target_pos - global_position).normalized()
	direction.y = 0  # Keep camera level
	
	if direction.is_normalized():
		# Calculate target rotation for the camera
		var target_rotation = atan2(direction.x, direction.z)
		
		# Smoothly rotate the camera to face the target
		var tween = create_tween()
		tween.tween_property(camera, "rotation:y", target_rotation, 0.5)


func get_camera() -> Camera3D:
	"""Get the camera reference for external control"""
	return camera

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		pass

func _add_starter_equipment():
	"""Add starter equipment items to the player's inventory for testing"""
	if not _inventory:
		printerr("No inventory available for starter equipment")
		return
	
	# Create starter helmet
	var helmet = Equipment.new()
	helmet.name = "Leather Cap"
	helmet.description = "A simple leather cap that provides basic protection."
	helmet.item_type = Item.ITEM_TYPE.EQUIPMENT
	helmet.equipment_slot = "helmet"
	helmet.slot = Equipment.EQUIP_SLOT.HEAD
	helmet.armor_value = 2
	helmet.stat_bonuses = {}  # No stat bonuses - just armor
	helmet.rarity = Item.RARITY.COMMON
	helmet.max_stack = 1
	# Load helmet icon
	var helmet_icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/lorc/crested-helmet.png")
	helmet.icon = helmet_icon
	
	# Create starter chest armor
	var chest_armor = Equipment.new()
	chest_armor.name = "Leather Vest"
	chest_armor.description = "A basic leather vest offering modest protection."
	chest_armor.item_type = Item.ITEM_TYPE.EQUIPMENT
	chest_armor.equipment_slot = "chest"
	chest_armor.slot = Equipment.EQUIP_SLOT.CHEST
	chest_armor.armor_value = 3
	chest_armor.stat_bonuses = {}  # No stat bonuses - just armor
	chest_armor.rarity = Item.RARITY.COMMON
	chest_armor.max_stack = 1
	# Load chest armor icon
	var chest_icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/lorc/leather-vest.png")
	chest_armor.icon = chest_icon
	
	# Create starter gloves
	var gloves = Equipment.new()
	gloves.name = "Leather Gloves"
	gloves.description = "Simple leather gloves for hand protection."
	gloves.item_type = Item.ITEM_TYPE.EQUIPMENT
	gloves.equipment_slot = "gloves"
	gloves.slot = Equipment.EQUIP_SLOT.HANDS
	gloves.armor_value = 1
	gloves.stat_bonuses = {"dexterity": 2, "spell_power": 1}
	gloves.rarity = Item.RARITY.COMMON
	gloves.max_stack = 1
	# Load gloves icon
	var gloves_icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/lorc/mailed-fist.png")
	gloves.icon = gloves_icon
	
	# Create starter boots
	var boots = Equipment.new()
	boots.name = "Leather Boots"
	boots.description = "Basic leather boots for foot protection."
	boots.item_type = Item.ITEM_TYPE.EQUIPMENT
	boots.equipment_slot = "boots"
	boots.slot = Equipment.EQUIP_SLOT.FEET
	boots.armor_value = 1
	boots.stat_bonuses = {"speed": 2, "dexterity": 1}
	boots.rarity = Item.RARITY.COMMON
	boots.max_stack = 1
	# Load boots icon
	var boots_icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/lorc/boots.png")
	boots.icon = boots_icon
	
	# Create acid flask for testing throwable weapons
	var acid_flask = Consumable.new()
	acid_flask.name = "Acid Flask"
	acid_flask.description = "A fragile glass vial filled with corrosive acid. Throw it at enemies to deal damage over time."
	acid_flask.item_type = Item.ITEM_TYPE.CONSUMABLE
	acid_flask.consumable_type = Item.CONSUMABLE_TYPE.CUSTOM
	acid_flask.custom_effect = "throw_damage"
	acid_flask.custom_stats = {
		"damage": 25,
		"damage_type": "acid",
		"duration": 3,
		"armor_penetration": 5,
		"poison_chance": 60.0,
		"poison_damage": 8
	}
	acid_flask.rarity = Item.RARITY.UNCOMMON
	acid_flask.max_stack = 5
	acid_flask.drop_chance = 75.0
	acid_flask.amount = 1  # Set amount to 1 to avoid showing "0"
	acid_flask.show_stats = true  # Enable stats display in tooltip
	# Load acid flask icon
	var acid_flask_icon = preload("res://Consumables/acidflask.png")
	acid_flask.icon = acid_flask_icon
	
	# Create venom dart for testing status effects
	var venom_dart = Consumable.new()
	venom_dart.name = "Venom Dart"
	venom_dart.description = "A small dart coated with deadly venom. Throws quickly and applies poison damage over time."
	venom_dart.item_type = Item.ITEM_TYPE.CONSUMABLE
	venom_dart.consumable_type = Item.CONSUMABLE_TYPE.CUSTOM
	venom_dart.custom_effect = "throw_damage"
	venom_dart.custom_stats = {
		"damage": 15,
		"damage_type": "piercing",
		"duration": 4,
		"armor_penetration": 3,
		"poison_chance": 100.0,
		"poison_damage": 6
	}
	venom_dart.rarity = Item.RARITY.RARE
	venom_dart.max_stack = 10
	venom_dart.drop_chance = 60.0
	venom_dart.amount = 1  # Set amount to 1 to avoid showing "0"
	venom_dart.show_stats = true  # Enable stats display in tooltip
	# Load venom dart icon
	var venom_dart_icon = preload("res://Consumables/poisondart.webp")
	venom_dart.icon = venom_dart_icon
	
	# Add all equipment to inventory
	_inventory.add_item_to_bag(helmet, 1)
	_inventory.add_item_to_bag(chest_armor, 1)
	_inventory.add_item_to_bag(gloves, 1)
	_inventory.add_item_to_bag(boots, 1)
	_inventory.add_item_to_bag(acid_flask, 3)  # Give 3 acid flasks
	_inventory.add_item_to_bag(venom_dart, 5)  # Give 5 venom darts
