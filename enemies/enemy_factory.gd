extends Node
class_name EnemyFactory

# Enemy factory for creating new enemies with proper inheritance
# This ensures all enemies automatically get global systems like status effects, XP rewards, etc.

# Predefined enemy templates
var enemy_templates = {
	"basic": {
		"can_be_poisoned": true,
		"can_be_ignited": true,
		"can_be_stunned": true,
		"can_be_slowed": true,
		"can_be_frozen": true,
		"can_be_shocked": true,
		"can_be_bleeding": true,
		"can_be_bone_broken": true,
		"base_gold_reward": 5,
		"gold_variance": 3,
		"loot_chance_multiplier": 1.0
	},
	"resistant": {
		"can_be_poisoned": false,
		"can_be_ignited": false,
		"can_be_stunned": true,
		"can_be_slowed": true,
		"can_be_frozen": false,
		"can_be_shocked": false,
		"can_be_bleeding": true,
		"can_be_bone_broken": true,
		"base_gold_reward": 8,
		"gold_variance": 4,
		"loot_chance_multiplier": 1.2
	},
	"elite": {
		"can_be_poisoned": true,
		"can_be_ignited": true,
		"can_be_stunned": false,
		"can_be_slowed": false,
		"can_be_frozen": true,
		"can_be_shocked": true,
		"can_be_bleeding": true,
		"can_be_bone_broken": false,
		"base_gold_reward": 15,
		"gold_variance": 8,
		"loot_chance_multiplier": 1.5
	},
	"boss": {
		"can_be_poisoned": true,
		"can_be_ignited": true,
		"can_be_stunned": false,
		"can_be_slowed": false,
		"can_be_frozen": false,
		"can_be_shocked": false,
		"can_be_bleeding": true,
		"can_be_bone_broken": false,
		"base_gold_reward": 50,
		"gold_variance": 25,
		"loot_chance_multiplier": 2.0
	}
}

# Enemy categories with default properties
var enemy_categories = {
	"beasts": {
		"template": "basic",
		"tags": ["beast", "dungeon"],
		"stat_bonuses": {"strength": 1, "speed": 1},
		"guaranteed_loot": ["beast_fang", "beast_hide"],
		"loot_table": {
			"beast_claw": {"chance": 0.3, "item": "beast_claw"},
			"beast_essence": {"chance": 0.1, "item": "beast_essence"}
		}
	},
	"humanoids": {
		"template": "basic",
		"tags": ["humanoid", "dungeon"],
		"stat_bonuses": {"intelligence": 1, "dexterity": 1},
		"guaranteed_loot": ["cloth_scraps"],
		"loot_table": {
			"copper_coin": {"chance": 0.8, "item": "copper_coin"},
			"silver_coin": {"chance": 0.2, "item": "silver_coin"}
		}
	},
	"undead": {
		"template": "resistant",
		"tags": ["undead", "dungeon"],
		"stat_bonuses": {"intelligence": 1, "spell_power": 1},
		"guaranteed_loot": ["bone_fragment"],
		"loot_table": {
			"soul_shard": {"chance": 0.4, "item": "soul_shard"},
			"dark_essence": {"chance": 0.15, "item": "dark_essence"}
		}
	},
	"elementals": {
		"template": "elite",
		"tags": ["elemental", "magical"],
		"stat_bonuses": {"spell_power": 2, "intelligence": 1},
		"guaranteed_loot": ["elemental_core"],
		"loot_table": {
			"magic_crystal": {"chance": 0.6, "item": "magic_crystal"},
			"essence_orb": {"chance": 0.3, "item": "essence_orb"}
		}
	},
	"dragons": {
		"template": "boss",
		"tags": ["dragon", "legendary"],
		"stat_bonuses": {"strength": 3, "spell_power": 2, "intelligence": 2},
		"guaranteed_loot": ["dragon_scale", "dragon_fang"],
		"loot_table": {
			"dragon_heart": {"chance": 0.8, "item": "dragon_heart"},
			"legendary_gem": {"chance": 0.4, "item": "legendary_gem"}
		}
	}
}

func create_enemy(enemy_data: Dictionary) -> Node:
	"""Create a new enemy with the given data"""
			var enemy = preload("enemy.gd").new()
	
	# Apply basic properties
	if enemy_data.has("name"):
		enemy.enemy_name = enemy_data.name
	if enemy_data.has("level"):
		enemy.enemy_level = enemy_data.level
	if enemy_data.has("category"):
		enemy.enemy_category = enemy_data.category
	if enemy_data.has("rarity"):
		enemy.enemy_rarity = enemy_data.rarity
	
	# Apply stats
	if enemy_data.has("base_health"):
		enemy.base_health = enemy_data.base_health
	if enemy_data.has("base_mana"):
		enemy.base_mana = enemy_data.base_mana
	if enemy_data.has("base_damage"):
		enemy.base_damage = enemy_data.base_damage
	if enemy_data.has("damage_range"):
		enemy.damage_range_min = enemy_data.damage_range[0]
		enemy.damage_range_max = enemy_data.damage_range[1]
	
	# Apply movement properties
	if enemy_data.has("move_speed"):
		enemy.move_speed = enemy_data.move_speed
	if enemy_data.has("detection_range"):
		enemy.detection_range = enemy_data.detection_range
	if enemy_data.has("combat_range"):
		enemy.combat_range = enemy_data.combat_range
	
	# Apply category-based template
	var category = enemy_data.get("category", "basic")
	if enemy_categories.has(category):
		var cat_data = enemy_categories[category]
		var template_name = cat_data.get("template", "basic")
		var template = enemy_templates.get(template_name, enemy_templates.basic)
		
		# Apply template properties
		for property in template:
			enemy.set(property, template[property])
		
		# Apply category tags
		if cat_data.has("tags"):
			enemy.enemy_tags = cat_data.tags.duplicate()
		
		# Apply stat bonuses
		if cat_data.has("stat_bonuses"):
			var bonuses = cat_data.stat_bonuses
			if bonuses.has("strength"):
				enemy.strength_modifier = bonuses.strength
			if bonuses.has("intelligence"):
				enemy.intelligence_modifier = bonuses.intelligence
			if bonuses.has("spell_power"):
				enemy.spell_power_modifier = bonuses.spell_power
			if bonuses.has("dexterity"):
				enemy.dexterity_modifier = bonuses.dexterity
			if bonuses.has("cunning"):
				enemy.cunning_modifier = bonuses.cunning
			if bonuses.has("speed"):
				enemy.speed_modifier = bonuses.speed
	
	# Apply custom properties
	if enemy_data.has("can_be_poisoned"):
		enemy.can_be_poisoned = enemy_data.can_be_poisoned
	if enemy_data.has("can_be_ignited"):
		enemy.can_be_ignited = enemy_data.can_be_ignited
	if enemy_data.has("can_be_stunned"):
		enemy.can_be_stunned = enemy_data.can_be_stunned
	if enemy_data.has("can_be_slowed"):
		enemy.can_be_slowed = enemy_data.can_be_slowed
	if enemy_data.has("can_be_frozen"):
		enemy.can_be_frozen = enemy_data.can_be_frozen
	if enemy_data.has("can_be_shocked"):
		enemy.can_be_shocked = enemy_data.can_be_shocked
	if enemy_data.has("can_be_bleeding"):
		enemy.can_be_bleeding = enemy_data.can_be_bleeding
	if enemy_data.has("can_be_bone_broken"):
		enemy.can_be_bone_broken = enemy_data.can_be_bone_broken
	
	# Apply loot and rewards
	if enemy_data.has("base_gold_reward"):
		enemy.base_gold_reward = enemy_data.base_gold_reward
	if enemy_data.has("gold_variance"):
		enemy.gold_variance = enemy_data.gold_variance
	if enemy_data.has("guaranteed_loot"):
		# Handle array assignment carefully
		enemy.guaranteed_loot.clear()
		for item in enemy_data.guaranteed_loot:
			enemy.guaranteed_loot.append(item)
	if enemy_data.has("loot_table"):
		enemy.loot_table = enemy_data.loot_table
	if enemy_data.has("loot_chance_multiplier"):
		enemy.loot_chance_multiplier = enemy_data.loot_chance_multiplier
	
	# Apply custom tags - handle array assignment carefully
	if enemy_data.has("tags"):
		# Clear existing tags first
		enemy.enemy_tags.clear()
		# Add new tags one by one
		for tag in enemy_data.tags:
			enemy.enemy_tags.append(tag)
	
	# Generate unique ID if not provided
	if not enemy_data.has("id") or enemy_data.id.is_empty():
		enemy.enemy_id = _generate_enemy_id(enemy_data.name)
	
	return enemy

func create_enemy_from_database(enemy_id: String) -> Node:
	"""Create an enemy from the database using its ID"""
	# This would integrate with your existing database system
	# For now, return null - you can implement this based on your needs
	print("Creating enemy from database: ", enemy_id)
	return null

func _generate_enemy_id(enemy_name: String) -> String:
	"""Generate a unique ID for an enemy"""
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 1000
	return enemy_name.to_lower().replace(" ", "_") + "_" + str(timestamp) + "_" + str(random_suffix)

# Predefined enemy creation functions for common types
func create_goblin(level: int = 4) -> Node:
	"""Create a standard goblin enemy"""
	return create_enemy({
		"name": "Goblin",
		"level": level,
		"category": "humanoids",
		"rarity": 1,
		"base_health": 40,
		"base_mana": 20,
		"base_damage": 15,
		"damage_range": [8, 12],
		"move_speed": 3.0,
		"detection_range": 5.0,
		"combat_range": 2.5,
		"base_gold_reward": 8,
		"gold_variance": 4,
		"tags": ["goblin", "low_level"],
		"loot_table": {
			"goblin_ear": 0.20,
			"crude_weapon": 0.15,
			"small_healing_potion": 0.15,
			"small_mana_potion": 0.10
		}
	})

func create_big_rat(level: int = 3) -> Node:
	"""Create a standard big rat enemy"""
	return create_enemy({
		"name": "Big Rat",
		"level": level,
		"category": "beasts",
		"rarity": 1,
		"base_health": 35,
		"base_mana": 10,
		"base_damage": 12,
		"damage_range": [5, 8],
		"move_speed": 2.5,
		"detection_range": 4.0,
		"combat_range": 2.0,
		"base_gold_reward": 3,
		"gold_variance": 2,
		"tags": ["rodent", "low_level"],
		"loot_table": {
			"rat_fang": 0.15,
			"rat_pelt": 0.25,
			"small_healing_potion": 0.10
		}
	})

func create_skeleton(level: int = 5) -> Node:
	"""Create a skeleton enemy (undead category)"""
	return create_enemy({
		"name": "Skeleton",
		"level": level,
		"category": "undead",
		"rarity": 2,
		"base_health": 45,
		"base_mana": 15,
		"base_damage": 18,
		"damage_range": [10, 15],
		"move_speed": 2.0,
		"detection_range": 6.0,
		"combat_range": 2.0,
		"base_gold_reward": 12,
		"gold_variance": 6,
		"tags": ["skeleton", "undead", "medium_level"],
		"loot_table": {
			"bone_fragment": 0.30,
			"rusty_sword": 0.20,
			"small_healing_potion": 0.20
		}
	})

func create_fire_elemental(level: int = 8) -> Node:
	"""Create a fire elemental enemy (elemental category)"""
	return create_enemy({
		"name": "Fire Elemental",
		"level": level,
		"category": "elementals",
		"rarity": 3,
		"base_health": 80,
		"base_mana": 60,
		"base_damage": 25,
		"damage_range": [18, 30],
		"move_speed": 1.5,
		"detection_range": 8.0,
		"combat_range": 3.0,
		"base_gold_reward": 25,
		"gold_variance": 12,
		"tags": ["fire", "elemental", "high_level"],
		"loot_table": {
			"fire_essence": 0.40,
			"magic_gem": 0.25,
			"medium_mana_potion": 0.30
		}
	})
