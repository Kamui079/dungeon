extends RefCounted
class_name DamageCalculator

# Damage reduction cap (80% = 0.8)
const MAX_DAMAGE_REDUCTION = 0.8

# Base armor effectiveness (how much 1 armor point reduces damage)
const BASE_ARMOR_EFFECTIVENESS = 0.02  # 2% per armor point

# Armor scaling factor (armor becomes less effective at higher levels)
const ARMOR_SCALING_FACTOR = 0.95

# Level scaling factor (higher levels make armor less effective)
const LEVEL_SCALING_FACTOR = 0.98

func calculate_damage_with_armor(base_damage: int, armor_value: int, attacker_level: int, defender_level: int) -> int:
	"""
	Calculate final damage after armor reduction
	
	Parameters:
	- base_damage: The raw damage before armor
	- armor_value: Total armor value from equipped items
	- attacker_level: Level of the attacking entity
	- defender_level: Level of the defending entity
	
	Returns:
	- Final damage after armor reduction
	"""
	
	# Calculate effective armor (armor becomes less effective at higher levels)
	var effective_armor = calculate_effective_armor(armor_value, defender_level)
	
	# Calculate damage reduction percentage
	var damage_reduction = calculate_damage_reduction(effective_armor, attacker_level, defender_level)
	
	# Apply damage reduction cap
	damage_reduction = min(damage_reduction, MAX_DAMAGE_REDUCTION)
	
	# Calculate final damage
	var damage_multiplier = 1.0 - damage_reduction
	var final_damage = int(base_damage * damage_multiplier)
	
	# Ensure minimum damage of 1
	final_damage = max(final_damage, 1)
	
	print("Damage calculation: Base: ", base_damage, " Armor: ", armor_value, " Reduction: ", (damage_reduction * 100), "% Final: ", final_damage)
	
	return final_damage

func calculate_effective_armor(armor_value: int, defender_level: int) -> float:
	"""
	Calculate effective armor value considering level scaling
	Higher levels make armor less effective
	"""
	var effective_armor = float(armor_value)
	
	# Apply level scaling (armor becomes less effective at higher levels)
	if defender_level > 1:
		var level_multiplier = pow(LEVEL_SCALING_FACTOR, defender_level - 1)
		effective_armor *= level_multiplier
	
	return effective_armor

func calculate_damage_reduction(effective_armor: float, attacker_level: int, _defender_level: int) -> float:
	"""
	Calculate damage reduction percentage from armor
	"""
	var base_reduction = effective_armor * BASE_ARMOR_EFFECTIVENESS
	
	# Apply attacker level scaling (higher level attackers are less affected by armor)
	var attacker_scaling = 1.0
	if attacker_level > 1:
		attacker_scaling = pow(ARMOR_SCALING_FACTOR, attacker_level - 1)
	
	var final_reduction = base_reduction * attacker_scaling
	
	return final_reduction

func get_armor_effectiveness_info(armor_value: int, player_level: int) -> Dictionary:
	"""
	Get information about armor effectiveness for display purposes
	"""
	var effective_armor = calculate_effective_armor(armor_value, player_level)
	var damage_reduction = calculate_damage_reduction(effective_armor, 1, player_level)
	
	return {
		"armor_value": armor_value,
		"effective_armor": effective_armor,
		"damage_reduction_percent": damage_reduction * 100,
		"damage_reduction_capped": min(damage_reduction, MAX_DAMAGE_REDUCTION) * 100
	}

# Example usage and testing
func test_damage_calculations():
	"""Test various damage calculation scenarios"""
	print("=== DAMAGE CALCULATION TESTS ===")
	
	# Test 1: Low level player with basic armor
	var damage1 = calculate_damage_with_armor(50, 12, 1, 1)
	print("Level 1 vs Level 1, 50 damage, 12 armor: ", damage1)
	
	# Test 2: High level player with same armor
	var damage2 = calculate_damage_with_armor(500, 12, 100, 100)
	print("Level 100 vs Level 100, 500 damage, 12 armor: ", damage2)
	
	# Test 3: High level player with high armor
	var damage3 = calculate_damage_with_armor(1000, 100, 200, 200)
	print("Level 200 vs Level 200, 1000 damage, 100 armor: ", damage3)
	
	# Test 4: Damage reduction cap test
	var damage4 = calculate_damage_with_armor(100, 1000, 1, 1)
	print("Level 1 vs Level 1, 100 damage, 1000 armor (cap test): ", damage4)
	
	print("=== END TESTS ===")
