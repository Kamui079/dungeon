class_name Equipment
extends Item

enum EQUIP_SLOT { 
	WEAPON, 
	HEAD, 
	CHEST, 
	HANDS, 
	LEGS, 
	FEET, 
	ACCESSORY,
	SHIELD,
	RING1,
	RING2,
	NECKLACE,
	CLOAK,
	BELT
}

@export var slot: EQUIP_SLOT
@export var required_level: int = 1
@export var armor_value: int = 0
@export var damage_value: int = 0

# Stats that this equipment provides when equipped
@export var stat_bonuses: Dictionary = {}

# Elemental damage bonuses (e.g., {"fire": 5.0} for +5% fire damage)
@export var elemental_bonuses: Dictionary = {}

func on_equip(user: Node) -> void:
	"""Apply equipment stats to the user when equipped"""
	if user.has_method("modify_stats"):
		for stat_name in stat_bonuses:
			var bonus_value = stat_bonuses[stat_name]
			user.modify_stats(stat_name, bonus_value)
	elif user.get("stats") != null and user.stats.has_method("modify_stats"):
		# Try to access stats through a stats property
		for stat_name in stat_bonuses:
			var bonus_value = stat_bonuses[stat_name]
			user.stats.modify_stats(stat_name, bonus_value)
	
	# Apply armor/damage bonuses if the user has those systems
	if armor_value > 0 and user.has_method("add_armor"):
		user.add_armor(armor_value)
	if damage_value > 0 and user.has_method("add_damage"):
		user.add_damage(damage_value)
	
	# Apply elemental damage bonuses
	if user.has_method("add_elemental_damage_bonus"):
		for element in elemental_bonuses:
			var bonus_value = elemental_bonuses[element]
			user.add_elemental_damage_bonus(element, bonus_value)
	elif user.get("stats") != null and user.stats.has_method("add_elemental_damage_bonus"):
		# Try to access stats through a stats property
		for element in elemental_bonuses:
			var bonus_value = elemental_bonuses[element]
			user.stats.add_elemental_damage_bonus(element, bonus_value)

func on_unequip(user: Node) -> void:
	"""Remove equipment stats from the user when unequipped"""
	if user.has_method("modify_stats"):
		for stat_name in stat_bonuses:
			var bonus_value = stat_bonuses[stat_name]
			user.modify_stats(stat_name, -bonus_value)
	elif user.get("stats") != null and user.stats.has_method("modify_stats"):
		# Try to access stats through a stats property
		for stat_name in stat_bonuses:
			var bonus_value = stat_bonuses[stat_name]
			user.stats.modify_stats(stat_name, -bonus_value)
	
	# Remove armor/damage bonuses if the user has those systems
	if armor_value > 0 and user.has_method("remove_armor"):
		user.remove_armor(armor_value)
	if damage_value > 0 and user.has_method("remove_damage"):
		user.remove_damage(damage_value)
	
	# Remove elemental damage bonuses
	if user.has_method("remove_elemental_damage_bonus"):
		for element in elemental_bonuses:
			var bonus_value = elemental_bonuses[element]
			user.remove_elemental_damage_bonus(element, bonus_value)
	elif user.get("stats") != null and user.stats.has_method("remove_elemental_damage_bonus"):
		# Try to access stats through a stats property
		for element in elemental_bonuses:
			var bonus_value = elemental_bonuses[element]
			user.stats.remove_elemental_damage_bonus(element, bonus_value)

func get_slot_name() -> String:
	"""Get the human-readable slot name for this equipment"""
	match slot:
		EQUIP_SLOT.WEAPON: return "weapon"
		EQUIP_SLOT.HEAD: return "helmet"
		EQUIP_SLOT.CHEST: return "chest"
		EQUIP_SLOT.HANDS: return "gloves"
		EQUIP_SLOT.LEGS: return "legs"
		EQUIP_SLOT.FEET: return "boots"
		EQUIP_SLOT.ACCESSORY: return "accessory"
		EQUIP_SLOT.SHIELD: return "shield"
		EQUIP_SLOT.RING1: return "ring1"
		EQUIP_SLOT.RING2: return "ring2"
		EQUIP_SLOT.NECKLACE: return "necklace"
		EQUIP_SLOT.CLOAK: return "cloak"
		EQUIP_SLOT.BELT: return "belt"
		_: return "unknown"

func can_equip_in_slot(slot_name: String) -> bool:
	"""Check if this equipment can be equipped in a specific slot"""
	var this_equipment_slot = get_slot_name()
	return this_equipment_slot == slot_name

func get_stats() -> Dictionary:
	"""Get stats for tooltip display"""
	var equipment_stats = {}
	
	# Add armor if present
	if armor_value > 0:
		equipment_stats["armor"] = armor_value
	
	# Add damage if present
	if damage_value > 0:
		equipment_stats["damage"] = damage_value
	
	# Add stat bonuses
	for stat_name in stat_bonuses:
		equipment_stats[stat_name] = stat_bonuses[stat_name]
	
	# Add elemental bonuses
	for element in elemental_bonuses:
		var bonus_value = elemental_bonuses[element]
		equipment_stats[element + "_damage_bonus"] = bonus_value
	
	return equipment_stats

func get_rarity() -> String:
	"""Get rarity as string for tooltip display"""
	match rarity:
		RARITY.COMMON: return "Common"
		RARITY.UNCOMMON: return "Uncommon"
		RARITY.RARE: return "Rare"
		RARITY.EPIC: return "Epic"
		RARITY.LEGENDARY: return "Legendary"
		_: return "Common"

func get_level_requirement() -> int:
	"""Get level requirement for tooltip display"""
	return required_level
