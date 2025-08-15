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

# Tooltip Section Controls
@export_group("Tooltip Sections")
@export var show_name: bool = true
@export var show_type: bool = true
@export var show_rarity: bool = true
@export var show_level_requirement: bool = false
@export var show_stats: bool = false
@export var show_description: bool = true

# Tooltip Content
@export_group("Tooltip Content")
@export var custom_name: String = ""
@export var custom_type: String = ""
@export var custom_description: String = ""
@export var level_requirement: int = 1
@export var custom_stats: Dictionary = {}

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

# Tooltip Methods
func get_tooltip_name() -> String:
	"""Get the name to display in tooltip"""
	if custom_name != "":
		return custom_name
	return name

func get_tooltip_type() -> String:
	"""Get the type to display in tooltip"""
	if custom_type != "":
		return custom_type
	
	# Provide human-readable defaults instead of enum numbers
	match item_type:
		ITEM_TYPE.CONSUMABLE: return "Consumable"
		ITEM_TYPE.EQUIPMENT: return "Equipment"
		ITEM_TYPE.JUNK: return "Junk"
		_: return "Item"

func get_tooltip_rarity() -> String:
	"""Get the rarity to display in tooltip"""
	match rarity:
		RARITY.COMMON: return "Common"
		RARITY.UNCOMMON: return "Uncommon"
		RARITY.RARE: return "Rare"
		RARITY.EPIC: return "Epic"
		RARITY.LEGENDARY: return "Legendary"
		_: return "Common"

func get_tooltip_level_requirement() -> int:
	"""Get the level requirement to display in tooltip"""
	return level_requirement

func get_tooltip_stats() -> Dictionary:
	"""Get the stats to display in tooltip"""
	return custom_stats

func get_tooltip_description() -> String:
	"""Get the description to display in tooltip"""
	if custom_description != "":
		return custom_description
	return description

# Tooltip Section Visibility
func should_show_tooltip_name() -> bool:
	return show_name

func should_show_tooltip_type() -> bool:
	return show_type

func should_show_tooltip_rarity() -> bool:
	return show_rarity

func should_show_tooltip_level_requirement() -> bool:
	return show_level_requirement

func should_show_tooltip_stats() -> bool:
	return show_stats

func should_show_tooltip_description() -> bool:
	return show_description

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
