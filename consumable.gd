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
			# Handle custom effects based on custom_effect property
			match custom_effect:
				"throw_damage":
					return _handle_throwable_weapon(user)
				"level_up":
					return _handle_level_up(user)
				_:
					return true
	
	return false

func _handle_throwable_weapon(user) -> bool:
	"""Handle throwable weapons like acid flasks"""
	if not user.has_method("get_stats"):
		print("User has no stats for throwable weapon!")
		return false
	
	var user_stats = user.get_stats()
	if not user_stats:
		print("User stats is null!")
		return false
	
	# Get the damage and other properties from custom_stats
	var damage = custom_stats.get("damage", 0)
	var damage_type = custom_stats.get("damage_type", "physical")
	var duration = custom_stats.get("duration", 0)
	var armor_penetration = custom_stats.get("armor_penetration", 0)
	
	print("🎯 Throwable weapon used: ", name)
	print("  Damage: ", damage, " Type: ", damage_type)
	print("  Duration: ", duration, " Armor Pen: ", armor_penetration)
	
	# For now, just return true to indicate successful use
	# The actual damage application will be handled by the combat system
	return true

func _handle_level_up(user) -> bool:
	"""Handle level up potion effect"""
	print("🎯 Level Up Potion used!")
	
	# Try to find player stats
	var player_stats = null
	if user.has_method("get_stats"):
		player_stats = user.get_stats()
	elif user.has_method("get_player_stats"):
		player_stats = user.get_player_stats()
	elif user.has("stats"):
		player_stats = user.stats
	
	if not player_stats:
		print("ERROR: Could not find player stats for level up!")
		return false
	
	# Try experience method first, then fall back to force level up
	if player_stats.has_method("gain_experience"):
		# Grant enough experience to level up
		var current_exp = player_stats.experience
		var exp_needed = player_stats.experience_to_next_level
		
		# Give exactly the amount needed to level up
		var exp_to_give = exp_needed - current_exp
		if exp_to_give > 0:
			player_stats.gain_experience(exp_to_give)
			print("🎉 Level Up Potion granted ", exp_to_give, " experience!")
			return true
		else:
			print("Player already has enough experience to level up!")
			return true
	elif player_stats.has_method("force_level_up"):
		# Fall back to direct level up
		player_stats.force_level_up()
		print("🎉 Level Up Potion used force_level_up method!")
		return true
	else:
		print("ERROR: Player stats missing both gain_experience and force_level_up methods!")
		return false
