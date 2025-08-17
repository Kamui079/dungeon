extends CharacterBody3D
class_name Goblin

# Import AnimationManager for type safety
const AnimationManager = preload("res://animation_manager.gd")

# Enemy functionality will be added via composition
var enemy_behavior: Node = null

# Custom display name override (optional)
func get_custom_display_name() -> String:
	return "Goblin"

func _ready():
	# Create enemy behavior component
	enemy_behavior = preload("enemy.gd").new()
	add_child(enemy_behavior)
	
	# Set goblin-specific properties
	enemy_behavior.enemy_name = "Goblin"
	enemy_behavior.move_speed = 3.0
	enemy_behavior.detection_range = 5.0
	enemy_behavior.combat_range = 2.5
	enemy_behavior.base_damage = 15
	enemy_behavior.base_health = 40
	enemy_behavior.base_mana = 20
	enemy_behavior.damage_range_min = 8
	enemy_behavior.damage_range_max = 12
	enemy_behavior.enemy_level = 1
	
	# Note: Display name is now handled automatically by the base class
	
	# Enemy database integration
	enemy_behavior.enemy_id = "goblin"
	enemy_behavior.enemy_category = "humanoids"
	enemy_behavior.enemy_rarity = 1  # Common
	enemy_behavior.enemy_tags = ["goblin", "humanoid", "dungeon", "low_level"]
	
	# Enemy type system
	enemy_behavior.enemy_type = enemy_behavior.ENEMY_TYPE.HUMANOID
	enemy_behavior.enemy_subtype = enemy_behavior.ENEMY_SUBTYPE.WARRIOR
	
	# Global systems integration - Goblins are vulnerable to most effects
	enemy_behavior.can_be_poisoned = true
	enemy_behavior.can_be_ignited = true
	enemy_behavior.can_be_stunned = true
	enemy_behavior.can_be_slowed = true
	enemy_behavior.can_be_frozen = true
	enemy_behavior.can_be_shocked = true
	enemy_behavior.can_be_bleeding = true
	enemy_behavior.can_be_bone_broken = true
	
	# Loot and rewards
	enemy_behavior.base_gold_reward = 8
	enemy_behavior.gold_variance = 4
	enemy_behavior.guaranteed_loot = []
	enemy_behavior.loot_table = {
		"goblin_ear": {"chance": 0.20, "item": null},  # 20% chance for goblin ear
		"crude_weapon": {"chance": 0.15, "item": null},  # 15% chance for crude weapon
		"small_healing_potion": {"chance": 0.15, "item": null},  # 15% chance for healing potion
		"small_mana_potion": {"chance": 0.10, "item": null}  # 10% chance for mana potion
	}
	enemy_behavior.loot_chance_multiplier = 1.0
	
	# Stat modifiers (balanced humanoid stats)
	enemy_behavior.strength_modifier = 1
	enemy_behavior.intelligence_modifier = 1
	enemy_behavior.spell_power_modifier = 0
	enemy_behavior.dexterity_modifier = 1
	enemy_behavior.cunning_modifier = 1
	enemy_behavior.speed_modifier = 1
	
	# Call enemy behavior's _ready to initialize stats
	enemy_behavior._ready()
	
	# Initialize status bars
	_create_bar_textures()
	hide_status_bars()

# Getter method for enemy name (used by combat system)
func enemy_name() -> String:
	if enemy_behavior:
		return enemy_behavior.enemy_name
	return "Goblin"  # Fallback name

# Note: get_enemy_name() is now inherited from the base enemy class

# Override virtual functions - these are inherited from Enemy class
# Custom behavior can be added here if needed

# Attack functions
func get_basic_attack_damage() -> int:
	var damage = randi_range(8, 12)
	if enemy_behavior and enemy_behavior.stats:
		var multiplier = enemy_behavior.stats.get_melee_damage_multiplier()
		return int(damage * multiplier)
	return damage

func get_basic_attack_damage_type() -> String:
	return "slashing"

func get_special_attack_damage() -> int:
	var damage = randi_range(12, 18)
	if enemy_behavior and enemy_behavior.stats:
		var multiplier = enemy_behavior.stats.get_melee_damage_multiplier()
		return int(damage * multiplier)
	return damage

func get_special_attack_damage_type() -> String:
	return "piercing"

func get_special_attack_name() -> String:
	return "Goblin Rush"

func get_special_attack_cost() -> int:
	return 3

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
	
	# Performs basic attack
	var damage = get_basic_attack_damage()
	
	# Play animation with damage - damage will be applied when animation completes
	print("🎯 Goblin melee_attack() - About to play animation")
	
	# Try to get animation manager from multiple sources
	var animation_manager = null
	var combat_manager = null
	
	# First try: through enemy_behavior.combat_manager
	if enemy_behavior and enemy_behavior.combat_manager:
		combat_manager = enemy_behavior.combat_manager
		if combat_manager.has_method("get_animation_manager"):
			animation_manager = combat_manager.get_animation_manager()
			print("🎯 Goblin melee_attack() - Found animation manager through enemy_behavior: ", animation_manager)
	
	# Second try: through scene tree lookup
	if not animation_manager:
		var managers = get_tree().get_nodes_in_group("CombatManager")
		if managers.size() > 0:
			combat_manager = managers[0]
			if combat_manager.has_method("get_animation_manager"):
				animation_manager = combat_manager.get_animation_manager()
				print("🎯 Goblin melee_attack() - Found animation manager through scene tree: ", animation_manager)
	
	# Third try: direct scene lookup
	if not animation_manager:
		var scene = get_tree().current_scene
		if scene:
			var cm = scene.get_node_or_null("CombatManager")
			if cm and cm.has_method("get_animation_manager"):
				combat_manager = cm
				animation_manager = cm.get_animation_manager()
				print("🎯 Goblin melee_attack() - Found animation manager through direct lookup: ", animation_manager)
	
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎯 Goblin melee_attack() - Playing animation with damage: ", damage)
		animation_manager.play_attack_animation_with_damage(
			self, 
			AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK, 
			enemy_behavior.current_target, 
			damage, 
			"physical"
		)
		print("🎯 Goblin melee_attack() - Playing animation with damage: ", damage)
	else:
		# Fallback to old system
		print("🎯 Goblin melee_attack() - No animation manager available, using fallback")
		if enemy_behavior.current_target.has_method("take_damage"):
			enemy_behavior.current_target.take_damage(damage, "physical")
		# End turn immediately if no animation system
		if combat_manager and combat_manager.has_method("end_current_turn"):
			combat_manager.end_current_turn()
		elif enemy_behavior and enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("end_current_turn"):
			enemy_behavior.combat_manager.end_current_turn()
	
	if enemy_behavior:
		enemy_behavior.gain_spirit(1)

func special_attack():
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		return
	
	if not can_use_special_attack():
		return
	
	# Spend spirit
	enemy_behavior.spend_spirit(get_special_attack_cost())
	
	# Performs special attack
	var damage = get_special_attack_damage()
	
	# Play animation with damage - damage will be applied when animation completes
	print("🎯 Goblin special_attack() - About to play animation")
	
	# Try to get animation manager from multiple sources
	var animation_manager = null
	var combat_manager = null
	
	# First try: through enemy_behavior.combat_manager
	if enemy_behavior and enemy_behavior.combat_manager:
		combat_manager = enemy_behavior.combat_manager
		if combat_manager.has_method("get_animation_manager"):
			animation_manager = combat_manager.get_animation_manager()
			print("🎯 Goblin special_attack() - Found animation manager through enemy_behavior: ", animation_manager)
	
	# Second try: through scene tree lookup
	if not animation_manager:
		var managers = get_nodes_in_group("CombatManager")
		if managers.size() > 0:
			combat_manager = managers[0]
			if combat_manager.has_method("get_animation_manager"):
				animation_manager = combat_manager.get_animation_manager()
				print("🎯 Goblin special_attack() - Found animation manager through scene tree: ", animation_manager)
	
	# Third try: direct scene lookup
	if not animation_manager:
		var scene = get_tree().current_scene
		if scene:
			var cm = scene.get_node_or_null("CombatManager")
			if cm and cm.has_method("get_animation_manager"):
				combat_manager = cm
				animation_manager = cm.get_animation_manager()
				print("🎯 Goblin special_attack() - Found animation manager through direct lookup: ", animation_manager)
	
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎯 Goblin special_attack() - Playing animation with damage: ", damage)
		animation_manager.play_attack_animation_with_damage(
			self, 
			AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK, 
			enemy_behavior.current_target, 
			damage, 
			"piercing"
		)
		print("🎯 Goblin special_attack() - Animation started, turn will end when animation completes")
	else:
		# Fallback to old system
		print("🎯 Goblin special_attack() - No animation manager available, using fallback")
		if enemy_behavior.current_target.has_method("take_damage"):
			enemy_behavior.current_target.take_damage(damage, "piercing")
		# End turn immediately if no animation system
		if combat_manager and combat_manager.has_method("end_current_turn"):
			combat_manager.end_current_turn()
		elif enemy_behavior and enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("end_current_turn"):
			enemy_behavior.combat_manager.end_current_turn()

# Status bar management - REMOVED (now handled by top panel)
func _create_bar_textures():
	"""Status bars removed - now displayed in top enemy status panel"""
	pass

func show_status_bars():
	if enemy_behavior:
		enemy_behavior.show_status_bars()

func hide_status_bars():
	if enemy_behavior:
		enemy_behavior.hide_status_bars()

func update_status_bars():
	if enemy_behavior:
		enemy_behavior.update_status_bars()

# Override take_damage to use enemy behavior
func take_damage(amount: int, damage_type: String = "physical"):
	if enemy_behavior:
		enemy_behavior.take_damage(amount, damage_type)
	else:
		# Fallback if enemy behavior not available
		print("Goblin took ", amount, " ", damage_type, " damage!")
		queue_free()

# Override on_combat_end to use enemy behavior
func on_combat_end():
	if enemy_behavior:
		enemy_behavior.on_combat_end()

# Override get_stats to use enemy behavior
func get_stats():
	if enemy_behavior:
		return enemy_behavior.get_stats()
	return null


