extends CharacterBody3D
class_name Goblin

# Enemy functionality will be added via composition
var enemy_behavior: Node = null

func _ready():
	# Create enemy behavior component
	enemy_behavior = preload("res://enemies/enemy.gd").new()
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
	enemy_behavior.enemy_level = 4
	
	# Enemy database integration
	enemy_behavior.enemy_id = "goblin"
	enemy_behavior.enemy_category = "humanoids"
	enemy_behavior.enemy_rarity = 1  # Common
	enemy_behavior.enemy_tags = ["goblin", "humanoid", "dungeon", "low_level"]
	
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
	enemy_behavior.strength_modifier = 2
	enemy_behavior.intelligence_modifier = 1
	enemy_behavior.spell_power_modifier = 0
	enemy_behavior.dexterity_modifier = 2
	enemy_behavior.cunning_modifier = 1
	enemy_behavior.speed_modifier = 1
	
	# Call enemy behavior's _ready to initialize stats
	enemy_behavior._ready()

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
	
	if enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("handle_player_damage"):
		enemy_behavior.combat_manager.handle_player_damage(damage, "basic attack")
	elif enemy_behavior.current_target.has_method("take_damage"):
		enemy_behavior.current_target.take_damage(damage)
	
	if enemy_behavior:
		enemy_behavior.gain_spirit(1)
	
	if enemy_behavior and enemy_behavior.combat_manager:
		enemy_behavior.combat_manager.end_current_turn()

func special_attack():
	if not enemy_behavior or not enemy_behavior.in_combat or not enemy_behavior.current_target:
		return
	
	if not can_use_special_attack():
		return
	
	# Spend spirit
	enemy_behavior.spend_spirit(get_special_attack_cost())
	
	# Performs special attack
	var damage = get_special_attack_damage()
	
	if enemy_behavior.combat_manager and enemy_behavior.combat_manager.has_method("handle_player_damage"):
		enemy_behavior.combat_manager.handle_player_damage(damage, "special attack")
	elif enemy_behavior.current_target.has_method("take_damage"):
		enemy_behavior.current_target.take_damage(damage)
	
	if enemy_behavior and enemy_behavior.combat_manager:
		enemy_behavior.combat_manager.end_current_turn()

# Status bar management
func _create_bar_textures():
	# Create health bar texture
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	health_bar.modulate = Color(1, 0, 0, 0.8)  # Red
	
	# Create mana bar texture
	var mana_bar = ProgressBar.new()
	mana_bar.name = "ManaBar"
	mana_bar.max_value = 100
	mana_bar.value = 100
	mana_bar.show_percentage = false
	mana_bar.modulate = Color(0, 0, 1, 0.8)  # Blue
	
	# Add bars to enemy behavior
	if enemy_behavior:
		enemy_behavior.add_child(health_bar)
		enemy_behavior.add_child(mana_bar)

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
func take_damage(amount: int):
	if enemy_behavior:
		enemy_behavior.take_damage(amount)
	else:
		# Fallback if enemy behavior not available
		print("Goblin took ", amount, " damage!")
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


