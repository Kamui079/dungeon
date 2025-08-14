class_name Consumable
extends Item

# Note: consumable_type, amount, and other properties are already defined in the base Item class
# This script just adds consumable-specific functionality

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
