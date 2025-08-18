class_name DamageTypes

# Damage type definitions with colors and properties
enum DAMAGE_TYPE {
	PHYSICAL,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
	ACID,
	ARCANE,
	DARK,
	HOLY,
	EARTH,
	WATER,
	BLEED,
	IGNITE,
	FREEZE,
	SHOCK,
	STUN,
	SLOW,
	SPELL_DAMAGE
}

# Color mapping for damage numbers
const DAMAGE_COLORS = {
	DAMAGE_TYPE.PHYSICAL: Color.WHITE,
	DAMAGE_TYPE.FIRE: Color.ORANGE,
	DAMAGE_TYPE.ICE: Color.CYAN,
	DAMAGE_TYPE.LIGHTNING: Color.YELLOW,
	DAMAGE_TYPE.POISON: Color.GREEN,
	DAMAGE_TYPE.ACID: Color.LIME,
	DAMAGE_TYPE.ARCANE: Color.MAGENTA,
	DAMAGE_TYPE.DARK: Color.PURPLE,
	DAMAGE_TYPE.HOLY: Color.GOLD,
	DAMAGE_TYPE.EARTH: Color.BROWN,
	DAMAGE_TYPE.WATER: Color.BLUE,
	DAMAGE_TYPE.BLEED: Color.RED,
	DAMAGE_TYPE.IGNITE: Color.DARK_ORANGE,
	DAMAGE_TYPE.FREEZE: Color.LIGHT_BLUE,
	DAMAGE_TYPE.SHOCK: Color.YELLOW,
	DAMAGE_TYPE.STUN: Color.GRAY,
	DAMAGE_TYPE.SLOW: Color.BLUE,
	DAMAGE_TYPE.SPELL_DAMAGE: Color.MAGENTA
}

# Damage type names for display
const DAMAGE_NAMES = {
	DAMAGE_TYPE.PHYSICAL: "Physical",
	DAMAGE_TYPE.FIRE: "Fire",
	DAMAGE_TYPE.ICE: "Ice",
	DAMAGE_TYPE.LIGHTNING: "Lightning",
	DAMAGE_TYPE.POISON: "Poison",
	DAMAGE_TYPE.ACID: "Acid",
	DAMAGE_TYPE.ARCANE: "Arcane",
	DAMAGE_TYPE.DARK: "Dark",
	DAMAGE_TYPE.HOLY: "Holy",
	DAMAGE_TYPE.EARTH: "Earth",
	DAMAGE_TYPE.WATER: "Water",
	DAMAGE_TYPE.BLEED: "Bleed",
	DAMAGE_TYPE.IGNITE: "Ignite",
	DAMAGE_TYPE.FREEZE: "Freeze",
	DAMAGE_TYPE.SHOCK: "Shock",
	DAMAGE_TYPE.STUN: "Stun",
	DAMAGE_TYPE.SLOW: "Slow",
	DAMAGE_TYPE.SPELL_DAMAGE: "Spell"
}

# Convert string damage type to enum
static func get_damage_type_enum(damage_type_string: String) -> DAMAGE_TYPE:
	var lower_string = damage_type_string.to_lower()
	
	match lower_string:
		"physical", "blunt", "slash", "pierce":
			return DAMAGE_TYPE.PHYSICAL
		"fire", "flame", "burn":
			return DAMAGE_TYPE.FIRE
		"ice", "frost", "cold":
			return DAMAGE_TYPE.ICE
		"lightning", "electric", "thunder":
			return DAMAGE_TYPE.LIGHTNING
		"poison", "toxic", "venom":
			return DAMAGE_TYPE.POISON
		"acid", "corrosive":
			return DAMAGE_TYPE.ACID
		"arcane", "magic", "spell":
			return DAMAGE_TYPE.ARCANE
		"dark", "shadow", "void":
			return DAMAGE_TYPE.DARK
		"holy", "divine", "light":
			return DAMAGE_TYPE.HOLY
		"earth", "stone", "nature":
			return DAMAGE_TYPE.EARTH
		"water", "aqua", "wet":
			return DAMAGE_TYPE.WATER
		"bleed", "blood":
			return DAMAGE_TYPE.BLEED
		"ignite", "burning":
			return DAMAGE_TYPE.IGNITE
		"freeze", "frozen":
			return DAMAGE_TYPE.FREEZE
		"shock", "electrified":
			return DAMAGE_TYPE.SHOCK
		"stun", "stunned":
			return DAMAGE_TYPE.STUN
		"slow", "slowed":
			return DAMAGE_TYPE.SLOW
		"spell_damage", "spell":
			return DAMAGE_TYPE.SPELL_DAMAGE
		_:
			return DAMAGE_TYPE.PHYSICAL  # Default fallback

# Get color for a damage type
static func get_damage_color(damage_type: DAMAGE_TYPE) -> Color:
	return DAMAGE_COLORS.get(damage_type, Color.WHITE)

# Get color for a string damage type
static func get_damage_color_from_string(damage_type_string: String) -> Color:
	var damage_enum = get_damage_type_enum(damage_type_string)
	return get_damage_color(damage_enum)

# Get name for a damage type
static func get_damage_name(damage_type: DAMAGE_TYPE) -> String:
	return DAMAGE_NAMES.get(damage_type, "Unknown")

# Get name for a string damage type
static func get_damage_name_from_string(damage_type_string: String) -> String:
	var damage_enum = get_damage_type_enum(damage_type_string)
	return get_damage_name(damage_enum)
