class_name Item
extends Resource

enum ITEM_TYPE { CONSUMABLE, EQUIPMENT, JUNK }
enum CONSUMABLE_TYPE { HEALTH, MANA, BUFF, CUSTOM }
enum RARITY { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }  # New enum

# Core Properties
@export var icon: Texture2D
@export var name: String = "Unnamed Item"
@export_multiline var description: String
@export var item_type: ITEM_TYPE
@export var max_stack: int = 1
@export_range(0.0, 100.0, 0.1) var drop_chance: float = 100.0
@export var rarity: RARITY = RARITY.COMMON  # New property

# Rarity weights (class-level constant)
const RARITY_WEIGHTS := {
	RARITY.COMMON: 60,
	RARITY.UNCOMMON: 25,
	RARITY.RARE: 10,
	RARITY.EPIC: 4,
	RARITY.LEGENDARY: 1
}

# Consumable Properties
@export var consumable_type: CONSUMABLE_TYPE
@export var amount: int = 0
@export var custom_effect: String

# Equipment Properties
@export var equipment_slot: String
@export var stats: Dictionary = {}

# Returns the weight for probability calculations
func get_rarity_weight() -> int:
	return RARITY_WEIGHTS.get(rarity, 1)  # Default to 1 if rarity missing

func should_drop() -> bool:
	return randf_range(0.0, 100.0) <= drop_chance

# Use method for consumables
func use(user) -> bool:
	if item_type != ITEM_TYPE.CONSUMABLE:
		return false
	
	match consumable_type:
		CONSUMABLE_TYPE.HEALTH:
			if user.has_method("heal"):
				user.heal(amount)
				return true
			elif user.get("stats") != null and user.stats.has_method("heal"):
				user.stats.heal(amount)
				return true
		CONSUMABLE_TYPE.MANA:
			if user.has_method("restore_mana"):
				user.restore_mana(amount)
				return true
			elif user.get("stats") != null and user.stats.has_method("restore_mana"):
				user.stats.restore_mana(amount)
				return true
		CONSUMABLE_TYPE.BUFF:
			# Handle buff effects
			return true
		CONSUMABLE_TYPE.CUSTOM:
			# Handle custom effects
			return true
	
	return false
