extends Node

class_name PlayerStats

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal spirit_changed(current: int)
signal died
signal level_up(new_level: int)
signal stats_changed

# Base stats (these are the investable stats)
var health: int = 100
var mana: int = 50
var spirit: int = 0  # Spirit points for special attacks
var max_spirit: int = 10  # Maximum spirit points

# Gold system
var gold: int = 0  # Player's gold currency

# Calculated max stats (based on base stats + level bonuses)
var max_health: int = 100
var max_mana: int = 50

# Leveling system
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 0
var stat_points_available: int = 0
var stat_points_per_level: int = 5

# Experience curve constants
var base_exp_requirement: int = 50  # Level 1 to 2
var exp_scaling_factor: float = 1.4  # How much exp requirement increases per level
var exp_curve_exponent: float = 1.15  # Additional scaling for higher levels

# New combat stats
var speed: int = 1  # Determines turn order and action points
var strength: int = 1  # Increases melee damage
var intelligence: int = 1  # Increases spell power
var spell_power: int = 1  # Base spell power (can be increased by items)
var dexterity: int = 1  # Increases critical chance and dodge chance
var cunning: int = 1  # Increases spell crit chance, ranged damage, and parry chance
var armor: int = 0  # Base armor value (can be increased by equipment)

# Combat mechanics
var dodge_chance: float = 0.0  # Base dodge chance
var parry_chance: float = 0.0  # Base parry chance
var melee_crit_chance: float = 0.0  # Base melee critical chance
var spell_crit_chance: float = 0.0  # Base spell critical chance
var ranged_crit_chance: float = 0.0  # Base ranged critical chance

# Stat scaling constants for level 1-200 progression
const SPEED_SCALING = {
	"base_multiplier": 0.8,      # Base turn frequency multiplier
	"consecutive_threshold": 1.5, # Need 1.5x enemy speed for consecutive turns
	"max_consecutive": 3,         # Maximum consecutive turns possible
	"diminishing_returns": 0.95   # Diminishing returns after certain thresholds
}

const STRENGTH_SCALING = {
	"base_damage": 2.0,          # Base damage per strength point
	"scaling_factor": 1.15,      # Exponential scaling factor
	"soft_cap": 50,              # Soft cap where scaling slows
	"hard_cap": 100              # Hard cap for maximum effectiveness
}

const INTELLIGENCE_SCALING = {
	"base_mana": 3.0,            # Base mana per intelligence point
	"spell_power_bonus": 0.8,    # Spell power bonus per intelligence
	"scaling_factor": 1.12,      # Exponential scaling factor
	"soft_cap": 60,              # Soft cap where scaling slows
	"hard_cap": 120              # Hard cap for maximum effectiveness
}

const SPELL_POWER_SCALING = {
	"base_multiplier": 1.5,      # Base spell damage multiplier
	"scaling_factor": 1.08,      # Exponential scaling factor
	"soft_cap": 40,              # Soft cap where scaling slows
	"hard_cap": 80               # Hard cap for maximum effectiveness
}

const DEXTERITY_SCALING = {
	"base_dodge": 0.8,           # Base dodge chance per dexterity point
	"base_melee_crit": 0.6,      # Base melee crit chance per dexterity point
	"base_ranged_crit": 0.7,     # Base ranged crit chance per dexterity point
	"scaling_factor": 1.10,      # Exponential scaling factor
	"soft_cap": 45,              # Soft cap where scaling slows
	"hard_cap": 90               # Hard cap for maximum effectiveness
}

const CUNNING_SCALING = {
	"base_parry": 0.6,           # Base parry chance per cunning point
	"base_spell_crit": 0.8,      # Base spell crit chance per cunning point
	"base_ranged_damage": 1.2,   # Base ranged damage bonus per cunning point
	"scaling_factor": 1.09,      # Exponential scaling factor
	"soft_cap": 55,              # Soft cap where scaling slows
	"hard_cap": 110              # Hard cap for maximum effectiveness
}

func _ready():
	# Calculate base combat chances from stats
	_update_combat_chances()
	
	# Calculate initial experience requirement
	_calculate_exp_requirement()
	
	# Calculate initial max stats (only once during initialization)
	if not _initialized:
		_recalculate_max_stats()
		_initialized = true
	
	# Don't automatically set health/mana here - let the player controller do it
	# after all stats are properly initialized
	
	# Give starting stat points
	stat_points_available = stat_points_per_level

func _update_combat_chances():
	"""Update combat chances based on current stats with sophisticated scaling"""
	# Dodge chance with diminishing returns after soft cap
	dodge_chance = _calculate_scaled_chance(dexterity, DEXTERITY_SCALING.base_dodge, 
		DEXTERITY_SCALING.soft_cap, DEXTERITY_SCALING.hard_cap, DEXTERITY_SCALING.scaling_factor)
	
	# Parry chance with diminishing returns after soft cap
	parry_chance = _calculate_scaled_chance(cunning, CUNNING_SCALING.base_parry, 
		CUNNING_SCALING.soft_cap, CUNNING_SCALING.hard_cap, CUNNING_SCALING.scaling_factor)
	
	# Melee crit chance with diminishing returns after soft cap
	melee_crit_chance = _calculate_scaled_chance(dexterity, DEXTERITY_SCALING.base_melee_crit, 
		DEXTERITY_SCALING.soft_cap, DEXTERITY_SCALING.hard_cap, DEXTERITY_SCALING.scaling_factor)
	
	# Spell crit chance with diminishing returns after soft cap
	spell_crit_chance = _calculate_scaled_chance(cunning, CUNNING_SCALING.base_spell_crit, 
		CUNNING_SCALING.soft_cap, CUNNING_SCALING.hard_cap, CUNNING_SCALING.scaling_factor)
	
	# Ranged crit chance with diminishing returns after soft cap
	ranged_crit_chance = _calculate_scaled_chance(dexterity, DEXTERITY_SCALING.base_ranged_crit, 
		DEXTERITY_SCALING.soft_cap, DEXTERITY_SCALING.hard_cap, DEXTERITY_SCALING.scaling_factor)
	
	# Emit stats changed signal
	stats_changed.emit()

# Helper method for calculating scaled chances with diminishing returns
func _calculate_scaled_chance(stat_value: int, base_per_point: float, soft_cap: int, hard_cap: int, scaling_factor: float) -> float:
	"""Calculate a scaled chance value with diminishing returns after soft cap"""
	var base_chance = 5.0  # Base 5% chance
	
	if stat_value <= soft_cap:
		# Linear scaling up to soft cap
		return base_chance + (stat_value * base_per_point)
	elif stat_value <= hard_cap:
		# Diminishing returns between soft cap and hard cap
		var soft_cap_value = base_chance + (soft_cap * base_per_point)
		var remaining_points = stat_value - soft_cap
		var diminished_scaling = base_per_point * pow(scaling_factor, remaining_points)
		return soft_cap_value + (remaining_points * diminished_scaling)
	else:
		# Hard cap - no further increases
		var hard_cap_value = base_chance + (soft_cap * base_per_point)
		var remaining_points = hard_cap - soft_cap
		var diminished_scaling = base_per_point * pow(scaling_factor, remaining_points)
		return hard_cap_value + (remaining_points * diminished_scaling)

# Helper method for calculating scaled multipliers with diminishing returns
func _calculate_scaled_multiplier(stat_value: int, base_per_point: float, soft_cap: int, hard_cap: int, scaling_factor: float) -> float:
	"""Calculate a scaled multiplier value with diminishing returns after soft cap"""
	var base_multiplier = 1.0  # Base 1.0x multiplier
	
	if stat_value <= soft_cap:
		# Linear scaling up to soft cap
		return base_multiplier + (stat_value * base_per_point)
	elif stat_value <= hard_cap:
		# Diminishing returns between soft cap and hard cap
		var soft_cap_value = base_multiplier + (soft_cap * base_per_point)
		var remaining_points = stat_value - soft_cap
		var diminished_scaling = base_per_point * pow(scaling_factor, remaining_points)
		return soft_cap_value + (remaining_points * diminished_scaling)
	else:
		# Hard cap - no further increases
		var soft_cap_value = base_multiplier + (soft_cap * base_per_point)
		var remaining_points = hard_cap - soft_cap
		var diminished_scaling = base_per_point * pow(scaling_factor, remaining_points)
		return soft_cap_value + (remaining_points * diminished_scaling)

# Stat recalculation methods
var _recalculating_stats: bool = false  # Guard against recursive calls
var _initialized: bool = false  # Guard against multiple initializations
var _setting_initial_values: bool = false  # Guard against triggering recalculation when setting initial values

func _recalculate_max_stats():
	"""Recalculate max health and mana based on current stats"""
	if _recalculating_stats:
		return  # Prevent recursive calls
	
	_recalculating_stats = true
	
	var base_health = 100 + (level * 10)  # Base health from level
	var base_mana = 50 + (level * 5)      # Base mana from level
	
	# Health scales with both base health stat and strength
	var health_bonus = health * 3          # 3 HP per health stat point
	var strength_bonus = strength * 5      # 5 HP per strength point
	
	# Mana scales with both base mana stat and intelligence
	var mana_bonus = mana * 4              # 4 MP per mana stat point
	var intelligence_bonus = intelligence * 8  # 8 MP per intelligence point
	
	max_health = base_health + health_bonus + strength_bonus
	max_mana = base_mana + mana_bonus + intelligence_bonus
	
	# Ensure current values don't exceed new maximums
	if not _setting_initial_values:
		health = min(health, max_health)
		mana = min(mana, max_mana)
	
	# Set health and mana to 90% for testing potions (after max stats are calculated)
	if level == 1 and not _initialized:  # Only set on first load
		_setting_initial_values = true
		health = int(max_health * 0.9)
		mana = int(max_mana * 0.9)
		_setting_initial_values = false
		# Don't set _initialized here as it's used for the _ready() function
	
	print("Stats recalculated - Max HP: ", max_health, " Max MP: ", max_mana)
	
	_recalculating_stats = false

# Leveling methods
func _calculate_exp_requirement():
	"""Calculate experience required for the next level"""
	# Formula: base_exp * (scaling_factor ^ (level - 1)) * (curve_exponent ^ (level / 10))
	# This creates a curve where early levels are quick but higher levels require much more exp
	var level_factor = pow(exp_scaling_factor, level - 1)
	var curve_factor = pow(exp_curve_exponent, level / 10.0)
	experience_to_next_level = int(base_exp_requirement * level_factor * curve_factor)
	
	print("Level ", level, " requires ", experience_to_next_level, " experience to reach level ", level + 1)

func gain_experience(amount: int):
	"""Gain experience and check for level up"""
	experience += amount
	print("Gained ", amount, " experience! Total: ", experience, "/", experience_to_next_level)
	
	# Check for level up
	while experience >= experience_to_next_level:
		_level_up()

func _level_up():
	"""Level up the character"""
	level += 1
	experience -= experience_to_next_level
	
	# Give stat points for this level
	stat_points_available += stat_points_per_level
	
	# Recalculate max stats based on current stat investments
	_recalculate_max_stats()
	health = max_health  # Restore health on level up
	mana = max_mana      # Restore mana on level up
	
	print("🎉 LEVEL UP! Now level ", level, "! Stat points available: ", stat_points_available)
	print("Max HP: ", max_health, " Max MP: ", max_mana)
	
	# Calculate new experience requirement
	_calculate_exp_requirement()
	
	# Emit signals
	level_up.emit(level)
	emit_signal("health_changed", health, max_health)
	emit_signal("mana_changed", mana, max_mana)

# Stat point spending methods
func spend_stat_point(stat_name: String) -> bool:
	"""Spend a stat point to increase a specific stat"""
	if stat_points_available <= 0:
		print("No stat points available!")
		return false
	
	match stat_name.to_lower():
		"health":
			health += 1
			_recalculate_max_stats()
			print("Health increased to ", health, "!")
		"mana":
			mana += 1
			_recalculate_max_stats()
			print("Mana increased to ", mana, "!")
		"speed":
			speed += 1
			print("Speed increased to ", speed, "!")
		"strength":
			strength += 1
			print("Strength increased to ", strength, "!")
		"intelligence":
			intelligence += 1
			print("Intelligence increased to ", intelligence, "!")
		"spell_power":
			spell_power += 1
			print("Spell Power increased to ", spell_power, "!")
		"dexterity":
			dexterity += 1
			print("Dexterity increased to ", dexterity, "!")
		"cunning":
			cunning += 1
			print("Cunning increased to ", cunning, "!")
		_:
			print("Unknown stat: ", stat_name)
			return false
	
	stat_points_available -= 1
	_update_combat_chances()
	print("Stat point spent! Remaining: ", stat_points_available)
	return true

# Level-based stat setting (for enemies)
func set_level(new_level: int):
	"""Set the character's level and calculate total stat points"""
	if new_level < 1:
		new_level = 1
	
	level = new_level
	var total_stat_points = (level - 1) * stat_points_per_level
	stat_points_available = total_stat_points
	
	# Calculate experience requirement for this level
	_calculate_exp_requirement()
	
	print("Level set to ", level, " with ", total_stat_points, " stat points to distribute")

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)
	if health <= 0:
		died.emit()

func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	emit_signal("health_changed", health, max_health)

func spend_mana(cost: int) -> bool:
	if mana < cost:
		return false
	mana -= cost
	emit_signal("mana_changed", mana, max_mana)
	return true

func restore_mana(amount: int) -> void:
	mana = min(max_mana, mana + amount)
	emit_signal("mana_changed", mana, max_mana)

func gain_spirit(amount: int) -> void:
	spirit += amount
	emit_signal("spirit_changed", spirit)

func spend_spirit(cost: int) -> bool:
	if spirit < cost:
		return false
	spirit -= cost
	emit_signal("spirit_changed", spirit)
	return true

func reset_spirit() -> void:
	spirit = 0
	emit_signal("spirit_changed", spirit)

func get_spirit() -> int:
	"""Get current spirit points"""
	return spirit

func get_gold() -> int:
	"""Get current gold amount"""
	return gold

func add_gold(amount: int):
	"""Add gold to player's currency"""
	gold += amount
	print("💰 Gold gained: +", amount, " (Total: ", gold, ")")

func spend_gold(amount: int) -> bool:
	"""Spend gold if player has enough"""
	if gold >= amount:
		gold -= amount
		print("💰 Gold spent: -", amount, " (Total: ", gold, ")")
		return true
	else:
		print("⚠️ Not enough gold! Need: ", amount, ", Have: ", gold)
		return false

func has_gold(amount: int) -> bool:
	"""Check if player has enough gold"""
	return gold >= amount

# Combat mechanics
func roll_dodge() -> bool:
	"""Roll for dodge - returns true if attack is dodged"""
	var roll = randf() * 100.0
	return roll <= dodge_chance

func roll_parry() -> bool:
	"""Roll for parry - returns true if attack is parried"""
	var roll = randf() * 100.0
	return roll <= parry_chance

func roll_melee_crit() -> bool:
	"""Roll for melee critical hit"""
	var roll = randf() * 100.0
	return roll <= melee_crit_chance

func roll_spell_crit() -> bool:
	"""Roll for spell critical hit"""
	var roll = randf() * 100.0
	return roll <= spell_crit_chance

func roll_ranged_crit() -> bool:
	"""Roll for ranged critical hit"""
	var roll = randf() * 100.0
	return roll <= ranged_crit_chance

# Stat getters for combat calculations with sophisticated scaling
func get_melee_damage_multiplier() -> float:
	"""Get melee damage multiplier based on strength with diminishing returns"""
	return _calculate_scaled_multiplier(strength, STRENGTH_SCALING.base_damage, 
		STRENGTH_SCALING.soft_cap, STRENGTH_SCALING.hard_cap, STRENGTH_SCALING.scaling_factor)

func get_spell_damage_multiplier() -> float:
	"""Get spell damage multiplier based on intelligence and spell power with diminishing returns"""
	var int_multiplier = _calculate_scaled_multiplier(intelligence, INTELLIGENCE_SCALING.spell_power_bonus, 
		INTELLIGENCE_SCALING.soft_cap, INTELLIGENCE_SCALING.hard_cap, INTELLIGENCE_SCALING.scaling_factor)
	var spell_multiplier = _calculate_scaled_multiplier(spell_power, SPELL_POWER_SCALING.base_multiplier, 
		SPELL_POWER_SCALING.soft_cap, SPELL_POWER_SCALING.hard_cap, SPELL_POWER_SCALING.scaling_factor)
	return int_multiplier + spell_multiplier

func get_ranged_damage_multiplier() -> float:
	"""Get ranged damage multiplier based on cunning with diminishing returns"""
	return _calculate_scaled_multiplier(cunning, CUNNING_SCALING.base_ranged_damage, 
		CUNNING_SCALING.soft_cap, CUNNING_SCALING.hard_cap, CUNNING_SCALING.scaling_factor)

# Stat modification methods (for direct setting)
func set_strength(value: int):
	strength = value
	_update_combat_chances()
	_recalculate_max_stats()

func set_intelligence(value: int):
	intelligence = value
	_update_combat_chances()
	_recalculate_max_stats()

func set_spell_power(value: int):
	spell_power = value
	_update_combat_chances()

func set_dexterity(value: int):
	dexterity = value
	_update_combat_chances()

func set_cunning(value: int):
	cunning = value
	_update_combat_chances()

func set_speed(value: int):
	speed = value
	_update_combat_chances()

func set_health(value: int):
	"""Set the health stat and recalculate max health"""
	health = value
	# Only recalculate if we're not in the middle of initialization
	if not _recalculating_stats:
		_recalculate_max_stats()
	stats_changed.emit()

func set_mana(value: int):
	"""Set the mana stat and recalculate max mana"""
	mana = value
	# Only recalculate if we're not in the middle of initialization
	if not _recalculating_stats:
		_recalculate_max_stats()
	stats_changed.emit()

# Legacy methods for backward compatibility
func add_strength(amount: int):
	strength += amount
	_update_combat_chances()

func add_intelligence(amount: int):
	intelligence += amount
	_update_combat_chances()

func add_spell_power(amount: int):
	spell_power += amount
	_update_combat_chances()

func add_dexterity(amount: int):
	dexterity += amount
	_update_combat_chances()

func add_cunning(amount: int):
	cunning += amount
	_update_combat_chances()

func add_speed(amount: int):
	speed += amount

# Experience calculation for enemies
func calculate_enemy_exp_reward(enemy_level: int) -> int:
	"""Calculate experience reward for defeating an enemy of given level"""
	# Base formula: enemy_level * 15 + (enemy_level - player_level) * 5
	# This gives more exp for higher level enemies and bonus for enemies above player level
	var base_exp = enemy_level * 15
	var level_difference = enemy_level - level
	var bonus_exp = level_difference * 5
	
	# Ensure minimum exp reward
	var total_exp = max(10, base_exp + bonus_exp)
	
	print("Enemy level ", enemy_level, " gives ", total_exp, " experience (base: ", base_exp, ", bonus: ", bonus_exp, ")")
	return total_exp

# Debug function to show experience curve
func debug_experience_curve(max_level: int = 10):
	"""Debug function to show experience requirements for first few levels"""
	print("=== EXPERIENCE CURVE DEBUG ===")
	var original_level = level
	var original_exp = experience
	var original_exp_to_next = experience_to_next_level
	
	for i in range(1, max_level + 1):
		level = i
		_calculate_exp_requirement()
		print("Level ", i, " to ", i + 1, ": ", experience_to_next_level, " exp required")
	
	# Restore original values
	level = original_level
	experience = original_exp
	experience_to_next_level = original_exp_to_next
	print("=== END EXPERIENCE CURVE DEBUG ===")

# Debug function to show stat scaling
func debug_stat_scaling(max_level: int = 50):
	"""Debug function to show how stats scale throughout the game"""
	print("=== STAT SCALING DEBUG ===")
	print("This shows how stats scale from level 1 to ", max_level)
	print("Assumes 5 stat points per level invested in each stat")
	print()
	
	var test_levels = [1, 10, 25, 50, 75, 100, 150, 200]
	
	for test_level in test_levels:
		if test_level > max_level:
			continue
			
		var stat_points = (test_level - 1) * 5  # 5 points per level
		var test_health = 1 + stat_points
		var test_mana = 1 + stat_points
		var test_strength = 1 + stat_points
		var test_intelligence = 1 + stat_points
		var test_dexterity = 1 + stat_points
		var test_cunning = 1 + stat_points
		var test_speed = 1 + stat_points
		print("Level ", test_level, " (", stat_points, " stat points invested):")
		print("  Health: ", test_health, " → Max HP: ", 100 + (test_level * 10) + (test_health * 3) + (test_strength * 5))
		print("  Mana: ", test_mana, " → Max MP: ", 50 + (test_level * 5) + (test_mana * 4) + (test_intelligence * 8))
		print("  Strength: ", test_strength, " → Melee Multiplier: ", _calculate_scaled_multiplier(test_strength, STRENGTH_SCALING.base_damage, STRENGTH_SCALING.soft_cap, STRENGTH_SCALING.hard_cap, STRENGTH_SCALING.scaling_factor))
		print("  Intelligence: ", test_intelligence, " → Mana Bonus: ", test_intelligence * INTELLIGENCE_SCALING.base_mana)
		print("  Dexterity: ", test_dexterity, " → Dodge: ", _calculate_scaled_chance(test_dexterity, DEXTERITY_SCALING.base_dodge, DEXTERITY_SCALING.soft_cap, DEXTERITY_SCALING.hard_cap, DEXTERITY_SCALING.scaling_factor), "%")
		print("  Cunning: ", test_cunning, " → Parry: ", _calculate_scaled_chance(test_cunning, CUNNING_SCALING.base_parry, CUNNING_SCALING.soft_cap, CUNNING_SCALING.hard_cap, CUNNING_SCALING.scaling_factor), "%")
		print("  Speed: ", test_speed, " → Turn Advantage: ", _calculate_speed_advantage(test_speed, 1), "x")
		print()
	
	print("=== END STAT SCALING DEBUG ===")

func _calculate_speed_advantage(actor_speed: int, opponent_speed: int) -> float:
	"""Calculate speed advantage multiplier for turn system"""
	var speed_ratio = float(actor_speed) / float(opponent_speed)
	return speed_ratio

func get_stat_summary() -> Dictionary:
	"""Get a summary of all current stats and their effects"""
	return {
		"health": {
			"current": health,
			"max": max_health,
			"base_stat": health,
			"strength_bonus": strength * 5,
			"level_bonus": level * 10
		},
		"mana": {
			"current": mana,
			"max": max_mana,
			"base_stat": mana,
			"intelligence_bonus": intelligence * 8,
			"level_bonus": level * 5
		},
		"combat_stats": {
			"strength": strength,
			"intelligence": intelligence,
			"spell_power": spell_power,
			"dexterity": dexterity,
			"cunning": cunning,
			"speed": speed,
			"armor": armor
		},
		"combat_chances": {
			"dodge": dodge_chance,
			"parry": parry_chance,
			"melee_crit": melee_crit_chance,
			"spell_crit": spell_crit_chance,
			"ranged_crit": ranged_crit_chance
		},
		"stat_points_available": stat_points_available
	}

func debug_stat_allocation():
	"""Debug function to show how to allocate stat points"""
	print("=== STAT ALLOCATION GUIDE ===")
	print("Available stat points: ", stat_points_available)
	print()
	print("Health: ", health, " (each point gives +3 HP + strength bonus)")
	print("Mana: ", mana, " (each point gives +4 MP + intelligence bonus)")
	print("Strength: ", strength, " (each point gives +5 HP + melee damage)")
	print("Intelligence: ", mana, " (each point gives +8 MP + spell power)")
	print("Spell Power: ", spell_power, " (each point gives +spell damage)")
	print("Dexterity: ", dexterity, " (each point gives +dodge +crit chance)")
	print("Cunning: ", cunning, " (each point gives +parry +spell crit)")
	print("Speed: ", speed, " (each point gives +turn advantage)")
	print("Armor: ", armor, " (base armor value + equipment bonuses)")
	print()
	print("Example allocations:")
	print("  Tank build: Health + Strength + Dexterity")
	print("  Mage build: Mana + Intelligence + Spell Power")
	print("  Rogue build: Speed + Dexterity + Cunning")
	print("  Balanced: Mix of all stats")
	print("=== END STAT ALLOCATION GUIDE ===")

# Utility functions for UI
func get_level_progress() -> Dictionary:
	"""Get level progress information for UI display"""
	return {
		"level": level,
		"experience": experience,
		"experience_to_next_level": experience_to_next_level,
		"progress_percentage": float(experience) / float(experience_to_next_level) * 100.0
	}

func get_level() -> int:
	"""Get the current player level"""
	return level

# Equipment stat modification methods
func modify_stats(stat_name: String, value: int):
	"""Modify a stat by the given value (used by equipment)"""
	match stat_name:
		"health":
			health += value
			max_health += value
			health = clamp(health, 0, max_health)
			emit_signal("health_changed", health, max_health)
		"mana":
			mana += value
			max_mana += value
			mana = clamp(mana, 0, max_mana)
			emit_signal("mana_changed", mana, max_mana)
		"strength":
			strength += value
			_recalculate_max_stats()
		"intelligence":
			intelligence += value
			_recalculate_max_stats()
		"spell_power":
			spell_power += value
		"dexterity":
			dexterity += value
			_update_combat_chances()
		"cunning":
			cunning += value
			_update_combat_chances()
		"speed":
			speed += value
			_update_combat_chances()
		"armor":
			armor += value
			# Ensure armor doesn't go negative
			armor = max(0, armor)
	
	emit_signal("stats_changed")

func add_armor(amount: int):
	"""Add armor value to the player's armor stat"""
	armor += amount
	# Ensure armor doesn't go negative
	armor = max(0, armor)
	print("Armor added: ", amount, " (Total: ", armor, ")")

func remove_armor(amount: int):
	"""Remove armor value from the player's armor stat"""
	armor -= amount
	# Ensure armor doesn't go negative
	armor = max(0, armor)
	print("Armor removed: ", amount, " (Total: ", armor, ")")

func add_damage(amount: int):
	"""Add damage value (placeholder for future damage system)"""
	# This is a placeholder - you can implement actual damage mechanics later
	print("Damage added: ", amount)

func remove_damage(amount: int):
	"""Remove damage value (placeholder for future damage system)"""
	# This is a placeholder - you can implement actual damage mechanics later
	print("Damage removed: ", amount)

func get_armor_value() -> int:
	"""Get the current armor value (base + equipment bonuses)"""
	return armor
