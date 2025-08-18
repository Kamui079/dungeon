extends CharacterBody3D
class_name BigRat

# Import AnimationManager for type safety
const AnimationManagerScript = preload("res://animation_manager.gd")

# Test if AnimationManager is accessible
func _test_animation_manager_access():
	print("🎯 Big Rat - Testing AnimationManager access")
	print("🎯 Big Rat - AnimationManagerScript constant: ", AnimationManagerScript)
	print("🎯 Big Rat - AnimationManagerScript.ANIMATION_TYPE.PHYSICAL_ATTACK: ", AnimationManagerScript.ANIMATION_TYPE.PHYSICAL_ATTACK)

# Enemy functionality will be added via composition
var enemy_behavior: Node = null

# Custom display name override (optional)
func get_custom_display_name() -> String:
	return "Big Rat"

# Status effects are now handled by the StatusEffectsManager
# Individual poison variables removed in favor of centralized system

func _ready():
	# Add to Enemy group for easy finding by combat systems
	add_to_group("Enemy")
	
	# Create enemy behavior component
	enemy_behavior = load("res://enemies/enemy.gd").new()
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
	enemy_behavior.enemy_level = 1
	
	# Note: Display name is now handled automatically by the base class
	
	# Enemy database integration
	enemy_behavior.enemy_id = "big_rat"
	enemy_behavior.enemy_category = "beasts"
	enemy_behavior.enemy_rarity = 1  # Common
	enemy_behavior.enemy_tags = ["rodent", "dungeon", "low_level"]
	
	# Enemy type system
	enemy_behavior.enemy_type = enemy_behavior.ENEMY_TYPE.CREATURE
	enemy_behavior.enemy_subtype = enemy_behavior.ENEMY_SUBTYPE.BEAST
	
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
	
	# Test AnimationManager access
	_test_animation_manager_access()

# Override virtual functions - these are inherited from Enemy class
# Custom behavior can be added here if needed

# Getter method for enemy name (used by combat system)
func enemy_name() -> String:
	if enemy_behavior:
		return enemy_behavior.enemy_name
	return "Big Rat"  # Fallback name

# Setter method for initial combat position (used by combat system)
func set_initial_combat_position(combat_pos: Vector3):
	if enemy_behavior:
		enemy_behavior.initial_combat_position = combat_pos

# Getter method for initial combat position (used by combat system)
func get_initial_combat_position() -> Vector3:
	if enemy_behavior:
		return enemy_behavior.initial_combat_position
	return Vector3.ZERO

# Override return_to_initial_position to work with BigRat's structure
func return_to_initial_position():
	if enemy_behavior:
		enemy_behavior.return_to_initial_position()

# Note: Most methods are already defined earlier in the file
# Only adding the missing ones that combat system needs

# Note: Physics process methods are already defined earlier in the file

# Properties that combat system checks
func get_movement_attempts() -> int:
	if enemy_behavior:
		return enemy_behavior.movement_attempts
	return 0

func set_movement_attempts(attempts: int):
	if enemy_behavior:
		enemy_behavior.movement_attempts = attempts

# Note: get_enemy_name() is now inherited from the base enemy class

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
	print("🎯 Big Rat melee_attack() called!")
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		print("❌ Big Rat melee_attack() - Invalid conditions")
		return
	
	if enemy_behavior.current_target.has_method("get_stats"):
		var target_stats = enemy_behavior.current_target.get_stats()
		if target_stats and target_stats.health <= 0:
			if enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
		# Performs Tail Slap attack
	var damage = get_basic_attack_damage()
	
	# Play animation with damage - damage will be applied when animation completes
	print("🎯 Big Rat melee_attack() - About to play animation")
	
	# Try to get animation manager from multiple sources
	var animation_manager = null
	var combat_manager = null
	
	# First try: through enemy_behavior.combat_manager
	if enemy_behavior and enemy_behavior.combat_manager:
		combat_manager = enemy_behavior.combat_manager
		if combat_manager.has_method("get_animation_manager"):
			animation_manager = combat_manager.get_animation_manager()
			print("🎯 Big Rat melee_attack() - Found animation manager through enemy_behavior: ", animation_manager)
	
	# Second try: through scene tree lookup
	if not animation_manager:
		var managers = get_tree().get_nodes_in_group("CombatManager")
		print("🎯 Big Rat melee_attack() - Scene tree lookup found ", managers.size(), " CombatManager nodes")
		if managers.size() > 0:
			combat_manager = managers[0]
			print("🎯 Big Rat melee_attack() - First CombatManager: ", combat_manager)
			if combat_manager.has_method("get_animation_manager"):
				animation_manager = combat_manager.get_animation_manager()
				print("🎯 Big Rat melee_attack() - Found animation manager through scene tree: ", animation_manager)
			else:
				print("🎯 Big Rat melee_attack() - CombatManager missing get_animation_manager method")
		else:
			print("🎯 Big Rat melee_attack() - No CombatManager nodes found in group")
	
	# Third try: direct scene lookup
	if not animation_manager:
		var scene = get_tree().current_scene
		print("🎯 Big Rat melee_attack() - Current scene: ", scene)
		if scene:
			var cm = scene.get_node_or_null("CombatManager")
			print("🎯 Big Rat melee_attack() - Direct scene lookup found: ", cm)
			if cm and cm.has_method("get_animation_manager"):
				combat_manager = cm
				animation_manager = cm.get_animation_manager()
				print("🎯 Big Rat melee_attack() - Found animation manager through direct lookup: ", animation_manager)
			else:
				print("🎯 Big Rat melee_attack() - Direct scene lookup CombatManager missing get_animation_manager method")
		else:
			print("🎯 Big Rat melee_attack() - No current scene found")
	
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎯 Big Rat melee_attack() - Playing animation with damage: ", damage)
		animation_manager.play_attack_animation_with_damage(
			self, 
			AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK, 
			enemy_behavior.current_target, 
			damage, 
			"physical"
		)
		print("🎯 Big Rat melee_attack() - Animation started, turn will end when animation completes")
	else:
		# Fallback to old system
		print("🎯 Big Rat melee_attack() - No animation manager available, using fallback")
		if enemy_behavior.current_target.has_method("take_damage"):
			enemy_behavior.current_target.take_damage(damage, "physical")
		# End turn immediately if no animation system
		if combat_manager and combat_manager.has_method("end_current_turn"):
			combat_manager.end_current_turn()
		elif enemy_behavior and enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("end_current_turn"):
			enemy_behavior.combat_manager.end_current_turn()
	
	if enemy_behavior:
		enemy_behavior.gain_spirit(1)
	
func bite_attack():
	print("🎯 Big Rat bite_attack() called!")
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		print("❌ Big Rat bite_attack() - Invalid conditions")
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
	
	# Play animation with damage - damage will be applied when animation completes
	print("🎯 Big Rat bite_attack() - About to play animation")
	
	# Try to get animation manager from multiple sources
	var animation_manager = null
	var combat_manager = null
	
	# First try: through enemy_behavior.combat_manager
	if enemy_behavior and enemy_behavior.combat_manager:
		combat_manager = enemy_behavior.combat_manager
		if combat_manager.has_method("get_animation_manager"):
			animation_manager = combat_manager.get_animation_manager()
			print("🎯 Big Rat bite_attack() - Found animation manager through enemy_behavior: ", animation_manager)
	
	# Second try: through scene tree lookup
	if not animation_manager:
		var managers = get_tree().get_nodes_in_group("CombatManager")
		print("🎯 Big Rat bite_attack() - Scene tree lookup found ", managers.size(), " CombatManager nodes")
		if managers.size() > 0:
			combat_manager = managers[0]
			print("🎯 Big Rat bite_attack() - First CombatManager: ", combat_manager)
			if combat_manager.has_method("get_animation_manager"):
				animation_manager = combat_manager.get_animation_manager()
				print("🎯 Big Rat bite_attack() - Found animation manager through scene tree: ", animation_manager)
			else:
				print("🎯 Big Rat bite_attack() - CombatManager missing get_animation_manager method")
		else:
			print("🎯 Big Rat bite_attack() - No CombatManager nodes found in group")
	
	# Third try: direct scene lookup
	if not animation_manager:
		var scene = get_tree().current_scene
		print("🎯 Big Rat bite_attack() - Current scene: ", scene)
		if scene:
			var cm = scene.get_node_or_null("CombatManager")
			print("🎯 Big Rat bite_attack() - Direct scene lookup found: ", cm)
			if cm and cm.has_method("get_animation_manager"):
				combat_manager = cm
				animation_manager = cm.get_animation_manager()
				print("🎯 Big Rat bite_attack() - Found animation manager through direct lookup: ", animation_manager)
			else:
				print("🎯 Big Rat bite_attack() - Direct scene lookup CombatManager missing get_animation_manager method")
		else:
			print("🎯 Big Rat bite_attack() - No current scene found")
	
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎯 Big Rat bite_attack() - Playing animation with damage: ", damage)
		animation_manager.play_attack_animation_with_damage(
			self, 
			AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK, 
			enemy_behavior.current_target, 
			damage, 
			"physical"
		)
		print("🎯 Big Rat bite_attack() - Animation started, turn will end when animation completes")
	else:
		# Fallback to old system
		print("🎯 Big Rat bite_attack() - No animation manager available, using fallback")
		if enemy_behavior.current_target.has_method("take_damage"):
			enemy_behavior.current_target.take_damage(damage, "physical")
		# End turn immediately if no animation system
		if combat_manager and combat_manager.has_method("end_current_turn"):
			combat_manager.end_current_turn()
		elif enemy_behavior and enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("end_current_turn"):
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
	
	if not self is Node3D:
		print("Big Rat ERROR: Self is not a Node3D - cannot access global_position!")
		return
	if not target is Node3D:
		print("Big Rat ERROR: Target is not a Node3D - cannot access global_position!")
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
	print("🎯 Big Rat take_turn() called!")
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		print("❌ Big Rat take_turn() - Invalid enemy_behavior or not in combat or no target")
		if enemy_behavior and enemy_behavior.combat_manager:
			enemy_behavior.combat_manager.end_current_turn()
		return
	
	if enemy_behavior.current_target.has_method("get_stats"):
		var target_stats = enemy_behavior.current_target.get_stats()
		if target_stats and target_stats.health <= 0:
			print("❌ Big Rat take_turn() - Target is dead")
			if enemy_behavior and enemy_behavior.combat_manager:
				enemy_behavior.combat_manager.end_current_turn()
			return
	
	if not is_instance_valid(enemy_behavior.current_target):
		print("❌ Big Rat take_turn() - Target is not valid")
		if enemy_behavior and enemy_behavior.combat_manager:
			enemy_behavior.combat_manager.end_current_turn()
		return
	
	if not self is Node3D:
		print("Big Rat ERROR: Self is not a Node3D - cannot access global_position!")
		return
	if not enemy_behavior.current_target is Node3D:
		print("Big Rat ERROR: Target is not a Node3D - cannot access global_position!")
		return
	var distance_to_target = global_position.distance_to(enemy_behavior.current_target.global_position)
	print("🎯 Big Rat distance to target: ", distance_to_target)
	if distance_to_target > 1.5:
		print("🎯 Big Rat moving to target for attack")
		move_to_target_for_attack(enemy_behavior.current_target)
		return
	
	var attack_choice = choose_attack()
	print("🎯 Big Rat chose attack: ", attack_choice)
	if attack_choice == "basic":
		print("🎯 Big Rat calling melee_attack()")
		melee_attack()
	elif attack_choice == "special":
		print("🎯 Big Rat calling bite_attack()")
		bite_attack()
	else:
		print("🎯 Big Rat fallback to melee_attack()")
		melee_attack()
	
	# Safety check: if no attack was performed, end turn manually
	print("🎯 Big Rat take_turn() completed")
	return

# Proxy functions to maintain compatibility with combat system
func get_stats():
	if enemy_behavior:
		return enemy_behavior.get_stats()
	return null

func take_damage(amount: int, damage_type: String = "physical"):
	if enemy_behavior:
		return enemy_behavior.take_damage(amount, damage_type)
	return

func set_combat_target(target: Node):
	if enemy_behavior:
		return enemy_behavior.set_combat_target(target)
	return

func on_combat_start():
	if enemy_behavior:
		return enemy_behavior.on_combat_start()
	return

func on_combat_end():
	if enemy_behavior:
		return enemy_behavior.on_combat_end()
	return

func set_physics_process_enabled(enabled: bool):
	if enemy_behavior:
		return enemy_behavior.set_physics_process_enabled(enabled)
	return

# Status bar management functions - REMOVED (now handled by top panel)
func _create_bar_textures():
	"""Status bars removed - now displayed in top enemy status panel"""
	pass

func update_status_bars():
	"""Status bars removed - now displayed in top enemy status panel"""
	pass

func show_status_bars():
	"""Show the status bars above the enemy's head - DISABLED, now shown in top panel"""
	print("BigRat: show_status_bars() called - Status bars now displayed in top panel")
	# Status bars are now displayed in the top enemy status panel
	# This function is kept for compatibility but does nothing

func hide_status_bars():
	"""Hide the status bars - DISABLED, now handled by top panel"""
	print("BigRat: hide_status_bars() called - Status bars now handled by top panel")
	# Status bars are now handled by the top enemy status panel
	# This function is kept for compatibility but does nothing
