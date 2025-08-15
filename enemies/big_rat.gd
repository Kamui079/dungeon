extends CharacterBody3D
class_name BigRat

# Enemy functionality will be added via composition
var enemy_behavior: Node = null

# Status effects are now handled by the StatusEffectsManager
# Individual poison variables removed in favor of centralized system

func _ready():
	# Create enemy behavior component
	enemy_behavior = preload("res://enemies/enemy.gd").new()
	add_child(enemy_behavior)
	
	# Set rat-specific properties
	enemy_behavior.enemy_name = "Big Rat"
	enemy_behavior.move_speed = 2.5
	enemy_behavior.detection_range = 4.0
	enemy_behavior.combat_range = 2.0
	enemy_behavior.base_damage = 12
	enemy_behavior.base_health = 35
	enemy_behavior.base_mana = 10
	enemy_behavior.damage_range_min = 5
	enemy_behavior.damage_range_max = 8
	enemy_behavior.enemy_level = 3
	
	# Enemy database integration
	enemy_behavior.enemy_id = "big_rat"
	enemy_behavior.enemy_category = "beasts"
	enemy_behavior.enemy_rarity = 1  # Common
	enemy_behavior.enemy_tags = ["rodent", "dungeon", "low_level"]
	
	# Global systems integration - Big Rats are vulnerable to most effects
	enemy_behavior.can_be_poisoned = true
	enemy_behavior.can_be_ignited = true
	enemy_behavior.can_be_stunned = true
	enemy_behavior.can_be_slowed = true
	enemy_behavior.can_be_frozen = true
	enemy_behavior.can_be_shocked = true
	enemy_behavior.can_be_bleeding = true
	enemy_behavior.can_be_bone_broken = true
	
	# Loot and rewards
	enemy_behavior.base_gold_reward = 3
	enemy_behavior.gold_variance = 2
	enemy_behavior.guaranteed_loot = []
	enemy_behavior.loot_table = {
		"rat_fang": {"chance": 0.15, "item": null},  # 15% chance for rat fang
		"rat_pelt": {"chance": 0.25, "item": null},  # 25% chance for rat pelt
		"small_healing_potion": {"chance": 0.10, "item": null}  # 10% chance for healing potion
	}
	enemy_behavior.loot_chance_multiplier = 1.0
	
	# Stat modifiers (6 speed, 2 strength, 2 dexterity)
	enemy_behavior.strength_modifier = 1
	enemy_behavior.intelligence_modifier = 0
	enemy_behavior.spell_power_modifier = 0
	enemy_behavior.dexterity_modifier = 1
	enemy_behavior.cunning_modifier = 0
	enemy_behavior.speed_modifier = 5
	
	# Call enemy behavior's _ready to initialize stats
	enemy_behavior._ready()
	
	# Initialize status bars
	_create_bar_textures()
	hide_status_bars()

# Override virtual functions - these are inherited from Enemy class
# Custom behavior can be added here if needed

# Attack functions
func get_basic_attack_damage() -> int:
	var damage = randi_range(4, 6)  # Reduced from 8-12 to 4-6
	if enemy_behavior and enemy_behavior.stats:
		var multiplier = enemy_behavior.stats.get_melee_damage_multiplier()
		return int(damage * multiplier)
	return damage

func get_basic_attack_damage_type() -> String:
	return "blunt"

func get_special_attack_damage() -> int:
	var damage = randi_range(6, 10)  # Reduced from 15-20 to 6-10
	if enemy_behavior and enemy_behavior.stats:
		var multiplier = enemy_behavior.stats.get_melee_damage_multiplier()
		return int(damage * multiplier)
	return damage

func get_special_attack_damage_type() -> String:
	return "piercing"

func get_special_attack_name() -> String:
	return "Bite"

func get_special_attack_cost() -> int:
	return 2

func can_use_special_attack() -> bool:
	if enemy_behavior:
		return enemy_behavior.spirit >= get_special_attack_cost()
	return false

# Combat functions
func melee_attack():
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		return
	
	if enemy_behavior.current_target.has_method("get_stats"):
		var target_stats = enemy_behavior.current_target.get_stats()
		if target_stats and target_stats.health <= 0:
			if enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
	# Performs Tail Slap attack
	var damage = get_basic_attack_damage()
	
	if enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("handle_player_damage"):
		enemy_behavior.combat_manager.handle_player_damage(damage, "basic attack")
	elif enemy_behavior.current_target.has_method("take_damage"):
		enemy_behavior.current_target.take_damage(damage)
	
	if enemy_behavior:
		enemy_behavior.gain_spirit(1)
	
	if enemy_behavior and enemy_behavior.combat_manager:
		enemy_behavior.combat_manager.end_current_turn()

func bite_attack():
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		return
	
	if enemy_behavior.current_target.has_method("get_stats"):
		var target_stats = enemy_behavior.current_target.get_stats()
		if target_stats and target_stats.health <= 0:
			if enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
	if not can_use_special_attack():
		melee_attack()
		return
	
	# Performs Bite attack
	if enemy_behavior:
		enemy_behavior.spend_spirit(get_special_attack_cost())
	var damage = get_special_attack_damage()
	
	if enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("handle_player_damage"):
		enemy_behavior.combat_manager.handle_player_damage(damage, "bite")
	elif enemy_behavior.current_target.has_method("take_damage"):
		enemy_behavior.current_target.take_damage(damage)
	
	if enemy_behavior and enemy_behavior.combat_manager:
		enemy_behavior.combat_manager.end_current_turn()

# AI logic
func choose_attack() -> String:
	if not can_use_special_attack():
		return "basic"
	
	if randf() <= 0.7:
		return "basic"
	else:
		return "special"

# Movement and turn logic
func move_to_target_for_attack(target: Node):
	if not target or not is_instance_valid(target):
		return
	
	if target.has_method("get_stats"):
		var target_stats = target.get_stats()
		if target_stats and target_stats.health <= 0:
			if enemy_behavior and enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
	var direction = (target.global_position - global_position).normalized()
	var attack_position = target.global_position - (direction * 1.5)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", attack_position, 1.0)
	tween.tween_callback(perform_delayed_attack)

func perform_delayed_attack():
	if not enemy_behavior or not enemy_behavior.current_target or not is_instance_valid(enemy_behavior.current_target):
		if enemy_behavior and enemy_behavior.combat_manager:
			enemy_behavior.combat_manager.end_current_turn()
		return
	
	if enemy_behavior.current_target.has_method("get_stats"):
		var target_stats = enemy_behavior.current_target.get_stats()
		if target_stats and target_stats.health <= 0:
			if enemy_behavior and enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
	var attack_choice = choose_attack()
	if attack_choice == "basic":
		melee_attack()
	elif attack_choice == "special":
		bite_attack()
	else:
		melee_attack()

func take_turn():
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		if enemy_behavior and enemy_behavior.combat_manager:
			enemy_behavior.combat_manager.end_current_turn()
		return
	
	if enemy_behavior.current_target.has_method("get_stats"):
		var target_stats = enemy_behavior.current_target.get_stats()
		if target_stats and target_stats.health <= 0:
			if enemy_behavior and enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
	if not is_instance_valid(enemy_behavior.current_target):
		if enemy_behavior and enemy_behavior.combat_manager:
			enemy_behavior.combat_manager.end_current_turn()
		return
	
	var distance_to_target = global_position.distance_to(enemy_behavior.current_target.global_position)
	if distance_to_target > 1.5:
		move_to_target_for_attack(enemy_behavior.current_target)
		return
	
	var attack_choice = choose_attack()
	if attack_choice == "basic":
		melee_attack()
	elif attack_choice == "special":
		bite_attack()
	else:
		melee_attack()

# Proxy functions to maintain compatibility with combat system
func get_stats():
	if enemy_behavior:
		return enemy_behavior.get_stats()
	return null

func take_damage(amount: int):
	if enemy_behavior:
		enemy_behavior.take_damage(amount)

func set_combat_target(target: Node):
	if enemy_behavior:
		enemy_behavior.set_combat_target(target)

func on_combat_start():
	if enemy_behavior:
		enemy_behavior.on_combat_start()

func on_combat_end():
	if enemy_behavior:
		enemy_behavior.on_combat_end()

func set_physics_process_enabled(enabled: bool):
	if enemy_behavior:
		enemy_behavior.set_physics_process_enabled(enabled)

# Status bar management functions
func _create_bar_textures():
	"""Create simple white textures for the health and mana bars"""
	var health_bar = get_node_or_null("HealthBar")
	var mana_bar = get_node_or_null("ManaBar")
	var enemy_name_label = get_node_or_null("EnemyNameLabel")
	
	if health_bar:
		# Create a simple white texture for the health bar
		var image = Image.create(64, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var texture = ImageTexture.create_from_image(image)
		health_bar.texture = texture
	
	if mana_bar:
		# Create a simple white texture for the mana bar
		var image = Image.create(64, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var texture = ImageTexture.create_from_image(image)
		mana_bar.texture = texture
	
	# Set enemy name label text
	if enemy_name_label:
		enemy_name_label.text = "Big Rat"

func update_status_bars():
	"""Update both health and mana bars"""
	print("BigRat: update_status_bars() called")
	if not enemy_behavior or not enemy_behavior.stats:
		print("BigRat: Cannot update status bars - enemy_behavior or stats is null")
		return
		
	var health_bar = get_node_or_null("HealthBar")
	var mana_bar = get_node_or_null("ManaBar")
	
	print("BigRat: health_bar found: ", health_bar != null, " mana_bar found: ", mana_bar != null)
	print("BigRat: Current health: ", enemy_behavior.stats.health, "/", enemy_behavior.stats.max_health)
	print("BigRat: Current mana: ", enemy_behavior.stats.mana, "/", enemy_behavior.stats.max_mana)
	
	if health_bar:
		# Scale the health bar based on current health percentage
		var health_percent = float(enemy_behavior.stats.health) / float(enemy_behavior.stats.max_health)
		health_bar.scale.x = health_percent
		print("BigRat: Health bar scaled to: ", health_percent)
		# Change color based on health level
		if health_percent > 0.6:
			health_bar.modulate = Color(0.2, 0.8, 0.2, 1.0)  # Green
		elif health_percent > 0.3:
			health_bar.modulate = Color(0.8, 0.8, 0.2, 1.0)  # Yellow
		else:
			health_bar.modulate = Color(0.8, 0.2, 0.2, 1.0)  # Red
	
	if mana_bar:
		# Scale the mana bar based on current mana percentage
		var mana_percent = float(enemy_behavior.stats.mana) / float(enemy_behavior.stats.max_mana)
		mana_bar.scale.x = mana_percent
		print("BigRat: Mana bar scaled to: ", mana_percent)

func show_status_bars():
	"""Show the status bars above the enemy's head"""
	print("BigRat: show_status_bars() called")
	var health_bar = get_node_or_null("HealthBar")
	var mana_bar = get_node_or_null("ManaBar")
	var enemy_name_label = get_node_or_null("EnemyNameLabel")
	
	print("BigRat: health_bar found: ", health_bar != null, " mana_bar found: ", mana_bar != null, " enemy_name_label found: ", enemy_name_label != null)
	
	if health_bar:
		health_bar.visible = true
		print("BigRat: Health bar made visible")
	if mana_bar:
		mana_bar.visible = true
		print("BigRat: Mana bar made visible")
	if enemy_name_label:
		enemy_name_label.visible = true
		print("BigRat: Enemy name label made visible")

func hide_status_bars():
	"""Hide the status bars"""
	var health_bar = get_node_or_null("HealthBar")
	var mana_bar = get_node_or_null("ManaBar")
	var enemy_name_label = get_node_or_null("EnemyNameLabel")
	
	if health_bar:
		health_bar.visible = false
	if mana_bar:
		mana_bar.visible = false
	if enemy_name_label:
		enemy_name_label.visible = false
