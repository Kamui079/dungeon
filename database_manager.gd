extends Node
class_name DatabaseManager

# Comprehensive database manager for all game systems
# This provides easy access to weapons, armor, consumables, enemies, spells, and abilities

# Database references
var weapons_database: Resource
var armor_database: Resource
var consumables_database: Resource
var enemies_database: Resource
var spells_database: Resource
var abilities_database: Resource

# Cached data for performance
var _weapons_cache: Dictionary = {}
var _armor_cache: Dictionary = {}
var _consumables_cache: Dictionary = {}
var _enemies_cache: Dictionary = {}
var _spells_cache: Dictionary = {}
var _abilities_cache: Dictionary = {}

# Database paths
const DATABASE_PATHS = {
	"weapons": "res://WeaponsDatabase.gddb",
	"armor": "res://ArmorDatabase.gddb",
	"consumables": "res://ConsumablesDatabase.gddb",
	"enemies": "res://EnemiesDatabase.gddb",
	"spells": "res://SpellsDatabase.gddb",
	"abilities": "res://SpecialAbilitiesDatabase.gddb"
}

func _ready():
	add_to_group("DatabaseManager")
	_load_all_databases()
	print("DatabaseManager: All databases loaded successfully!")

func _load_all_databases():
	"""Load all database files"""
	print("DatabaseManager: Starting database load...")
	
	for db_name in DATABASE_PATHS:
		var db_path = DATABASE_PATHS[db_name]
		print("DatabaseManager: Attempting to load ", db_name, " from ", db_path)
		
		# Check if file exists first
		if not FileAccess.file_exists(db_path):
			print("DatabaseManager: WARNING - File does not exist: ", db_path)
			continue
		
		var db_resource = load(db_path)
		
		if db_resource:
			match db_name:
				"weapons":
					weapons_database = db_resource
					_cache_database_data(db_resource, _weapons_cache)
				"armor":
					armor_database = db_resource
					_cache_database_data(db_resource, _armor_cache)
				"consumables":
					consumables_database = db_resource
					_cache_database_data(db_resource, _consumables_cache)
				"enemies":
					enemies_database = db_resource
					_cache_database_data(db_resource, _enemies_cache)
				"spells":
					spells_database = db_resource
					_cache_database_data(db_resource, _spells_cache)
				"abilities":
					abilities_database = db_resource
					_cache_database_data(db_resource, _abilities_cache)
			
			print("DatabaseManager: Successfully loaded ", db_name, " database")
		else:
			print("DatabaseManager: ERROR - Failed to load ", db_name, " database from ", db_path)
			print("DatabaseManager: This usually means the database needs to be imported by Godot first.")
			print("DatabaseManager: Try opening the project in the editor to trigger import.")
	
	# Check how many databases loaded successfully
	var loaded_count = 0
	if weapons_database: loaded_count += 1
	if armor_database: loaded_count += 1
	if consumables_database: loaded_count += 1
	if enemies_database: loaded_count += 1
	if spells_database: loaded_count += 1
	if abilities_database: loaded_count += 1
	
	if loaded_count == 0:
		print("DatabaseManager: CRITICAL - No databases loaded! The game will work but without database features.")
		print("DatabaseManager: To fix this, open the project in Godot editor to trigger database imports.")
	else:
		print("DatabaseManager: ", loaded_count, " out of 6 databases loaded successfully!")
		print("DatabaseManager: Database system is ready with limited functionality.")

func _cache_database_data(database: Resource, cache: Dictionary):
	"""Cache database data for faster access"""
	if not database or not database.has_method("get_collections_data"):
		return
	
	var collections = database.get_collections_data()
	for collection_name in collections:
		var collection = collections[collection_name]
		cache[collection_name] = collection

# ===== WEAPONS DATABASE METHODS =====

func get_weapon_by_id(weapon_id: String) -> Resource:
	"""Get a weapon resource by its ID"""
	if not weapons_database:
		print("DatabaseManager: WARNING - Weapons database not loaded!")
		return null
		
	if _weapons_cache.has("weapons"):
		var weapons = _weapons_cache.weapons
		if weapons.strings_to_ints.has(weapon_id):
			var index = weapons.strings_to_ints[weapon_id]
			if weapons.ints_to_locators.has(index):
				var path = weapons.ints_to_locators[index]
				return load(path)
	return null

func get_weapons_by_category(category: String) -> Array:
	"""Get all weapons in a specific category"""
	var weapons = []
	if not weapons_database:
		print("DatabaseManager: WARNING - Weapons database not loaded!")
		return weapons
		
	if _weapons_cache.has("weapons"):
		var weapons_data = _weapons_cache.weapons
		if weapons_data.categories_to_ints.has(category):
			var category_data = weapons_data.categories_to_ints[category]
			for index in category_data:
				if weapons_data.ints_to_locators.has(index):
					var path = weapons_data.ints_to_locators[index]
					var weapon = load(path)
					if weapon:
						weapons.append(weapon)
	return weapons

func get_all_weapons() -> Array:
	"""Get all weapons in the database"""
	var weapons = []
	if not weapons_database:
		print("DatabaseManager: WARNING - Weapons database not loaded!")
		return weapons
		
	if _weapons_cache.has("weapons"):
		var weapons_data = _weapons_cache.weapons
		for index in weapons_data.ints_to_locators:
			var path = weapons_data.ints_to_locators[index]
			var weapon = load(path)
			if weapon:
				weapons.append(weapon)
	return weapons

# ===== ARMOR DATABASE METHODS =====

func get_armor_by_id(armor_id: String) -> Resource:
	"""Get an armor resource by its ID"""
	if not armor_database:
		print("DatabaseManager: WARNING - Armor database not loaded!")
		return null
		
	if _armor_cache.has("armor"):
		var armor_data = _armor_cache.armor
		if armor_data.strings_to_ints.has(armor_id):
			var index = armor_data.strings_to_ints[armor_id]
			if armor_data.ints_to_locators.has(index):
				var path = armor_data.ints_to_locators[index]
				return load(path)
	return null

func get_armor_by_category(category: String) -> Array:
	"""Get all armor in a specific category"""
	var armor_pieces = []
	if not armor_database:
		print("DatabaseManager: WARNING - Armor database not loaded!")
		return armor_pieces
		
	if _armor_cache.has("armor"):
		var armor_data = _armor_cache.armor
		if armor_data.categories_to_ints.has(category):
			var category_data = armor_data.categories_to_ints[category]
			for index in category_data:
				if armor_data.ints_to_locators.has(index):
					var path = armor_data.ints_to_locators[index]
					var armor = load(path)
					if armor:
						armor_pieces.append(armor)
	return armor_pieces

func get_armor_by_slot(slot: String) -> Array:
	"""Get armor by equipment slot (head, chest, hands, feet, etc.)"""
	match slot.to_lower():
		"head", "helmet":
			return get_armor_by_category("head")
		"chest", "vest", "body":
			return get_armor_by_category("chest")
		"light":
			return get_armor_by_category("light")
		"starter":
			return get_armor_by_category("starter")
		_:
			return []

# ===== CONSUMABLES DATABASE METHODS =====

func get_consumable_by_id(consumable_id: String) -> Resource:
	"""Get a consumable resource by its ID"""
	if not consumables_database:
		print("DatabaseManager: WARNING - Consumables database not loaded!")
		return null
		
	if _consumables_cache.has("all_consumables"):
		var consumables = _consumables_cache.all_consumables
		if consumables.strings_to_ints.has(consumable_id):
			var index = consumables.strings_to_ints[consumable_id]
			if consumables.ints_to_locators.has(index):
				var path = consumables.ints_to_locators[index]
				return load(path)
	return null

func get_consumables_by_category(category: String) -> Array:
	"""Get all consumables in a specific category"""
	var consumables = []
	if not consumables_database:
		print("DatabaseManager: WARNING - Consumables database not loaded!")
		return consumables
		
	if _consumables_cache.has("all_consumables"):
		var consumables_data = _consumables_cache.all_consumables
		if consumables_data.categories_to_ints.has(category):
			var category_data = consumables_data.categories_to_ints[category]
			for index in category_data:
				if consumables_data.ints_to_locators.has(index):
					var path = consumables_data.ints_to_locators[index]
					var consumable = load(path)
					if consumable:
						consumables.append(consumable)
	return consumables

func get_throwables() -> Array:
	"""Get all throwable consumables"""
	return get_consumables_by_category("throwable")

func get_healing_items() -> Array:
	"""Get all healing consumables"""
	return get_consumables_by_category("healing")

func get_mana_items() -> Array:
	"""Get all mana consumables"""
	return get_consumables_by_category("mana")

# ===== ENEMIES DATABASE METHODS =====

func get_enemy_by_id(enemy_id: String) -> Resource:
	"""Get an enemy resource by its ID"""
	if not enemies_database:
		print("DatabaseManager: WARNING - Enemies database not loaded!")
		return null
		
	if _enemies_cache.has("enemies"):
		var enemies = _enemies_cache.enemies
		if enemies.strings_to_ints.has(enemy_id):
			var index = enemies.strings_to_ints[enemy_id]
			if enemies.ints_to_locators.has(index):
				var path = enemies.ints_to_locators[index]
				return load(path)
	return null

func get_enemies_by_category(category: String) -> Array:
	"""Get all enemies in a specific category"""
	var enemies = []
	if not enemies_database:
		print("DatabaseManager: WARNING - Enemies database not loaded!")
		return enemies
		
	if _enemies_cache.has("enemies"):
		var enemies_data = _enemies_cache.enemies
		if enemies_data.categories_to_ints.has(category):
			var category_data = enemies_data.categories_to_ints[category]
			for index in category_data:
				if enemies_data.ints_to_locators.has(index):
					var path = enemies_data.ints_to_locators[index]
					var enemy = load(path)
					if enemy:
						enemies.append(enemy)
	return enemies

func get_enemies_by_tag(tag: String) -> Array:
	"""Get enemies by tag (low_level, dungeon, etc.)"""
	return get_enemies_by_category(tag)

# ===== SPELLS DATABASE METHODS =====

func get_spells_by_category(category: String) -> Array:
	"""Get all spells in a specific category"""
	var spells = []
	if not spells_database:
		print("DatabaseManager: WARNING - Spells database not loaded!")
		return spells
		
	if _spells_cache.has("spells"):
		var spells_data = _spells_cache.spells
		if spells_data.categories_to_ints.has(category):
			var category_data = spells_data.categories_to_ints[category]
			for index in category_data:
				if spells_data.ints_to_locators.has(index):
					var path = spells_data.ints_to_locators[index]
					var spell = load(path)
					if spell:
						spells.append(spell)
	return spells

# ===== ABILITIES DATABASE METHODS =====

func get_abilities_by_category(category: String) -> Array:
	"""Get all abilities in a specific category"""
	var abilities = []
	if not abilities_database:
		print("DatabaseManager: WARNING - Abilities database not loaded!")
		return abilities
		
	if _abilities_cache.has("abilities"):
		var abilities_data = _abilities_cache.abilities
		if abilities_data.categories_to_ints.has(category):
			var category_data = abilities_data.categories_to_ints[category]
			for index in category_data:
				if abilities_data.ints_to_locators.has(index):
					var path = abilities_data.ints_to_locators[index]
					var ability = load(path)
					if ability:
						abilities.append(ability)
	return abilities

# ===== UTILITY METHODS =====

func get_random_item_by_category(database_type: String, category: String) -> Resource:
	"""Get a random item from a specific database and category"""
	var items = []
	
	match database_type.to_lower():
		"weapons":
			items = get_weapons_by_category(category)
		"armor":
			items = get_armor_by_category(category)
		"consumables":
			items = get_consumables_by_category(category)
		"enemies":
			items = get_enemies_by_category(category)
		"spells":
			items = get_spells_by_category(category)
		"abilities":
			items = get_abilities_by_category(category)
	
	if items.size() > 0:
		return items[randi() % items.size()]
	return null

func search_items(query: String, database_type: String = "all") -> Array:
	"""Search for items across databases"""
	var results = []
	query = query.to_lower()
	
	if database_type == "all" or database_type == "weapons":
		var weapons = get_all_weapons()
		for weapon in weapons:
			if query in weapon.name.to_lower() or query in weapon.description.to_lower():
				results.append(weapon)
	
	if database_type == "all" or database_type == "armor":
		var armor = get_armor_by_category("all")
		for piece in armor:
			if query in piece.name.to_lower() or query in piece.description.to_lower():
				results.append(piece)
	
	if database_type == "all" or database_type == "consumables":
		var consumables = get_consumables_by_category("all")
		for consumable in consumables:
			if query in consumable.name.to_lower() or query in consumable.description.to_lower():
				results.append(consumable)
	
	return results

func get_database_stats() -> Dictionary:
	"""Get statistics about all databases"""
	var stats = {
		"weapons": {"total": 0, "categories": {}},
		"armor": {"total": 0, "categories": {}},
		"consumables": {"total": 0, "categories": {}},
		"enemies": {"total": 0, "categories": {}},
		"spells": {"total": 0, "categories": {}},
		"abilities": {"total": 0, "categories": {}}
	}
	
	# Count weapons
	if _weapons_cache.has("weapons"):
		stats.weapons.total = _weapons_cache.weapons.ints_to_locators.size()
		stats.weapons.categories = _weapons_cache.weapons.categories_to_ints
	
	# Count armor
	if _armor_cache.has("armor"):
		stats.armor.total = _armor_cache.armor.ints_to_locators.size()
		stats.armor.categories = _armor_cache.armor.categories_to_ints
	
	# Count consumables
	if _consumables_cache.has("all_consumables"):
		stats.consumables.total = _consumables_cache.all_consumables.ints_to_locators.size()
		stats.consumables.categories = _consumables_cache.all_consumables.categories_to_ints
	
	# Count enemies
	if _enemies_cache.has("enemies"):
		stats.enemies.total = _enemies_cache.enemies.ints_to_locators.size()
		stats.enemies.categories = _enemies_cache.enemies.categories_to_ints
	
	# Count spells
	if _spells_cache.has("spells"):
		stats.spells.total = _spells_cache.spells.ints_to_locators.size()
		stats.spells.categories = _spells_cache.spells.categories_to_ints
	
	# Count abilities
	if _abilities_cache.has("abilities"):
		stats.abilities.total = _abilities_cache.abilities.ints_to_locators.size()
		stats.abilities.categories = _abilities_cache.abilities.categories_to_ints
	
	return stats

func is_database_system_ready() -> bool:
	"""Check if the database system is fully functional"""
	return weapons_database != null and armor_database != null and consumables_database != null and enemies_database != null and spells_database != null and abilities_database != null

func get_database_status() -> Dictionary:
	"""Get detailed status of all databases"""
	return {
		"weapons": weapons_database != null,
		"armor": armor_database != null,
		"consumables": consumables_database != null,
		"enemies": enemies_database != null,
		"spells": spells_database != null,
		"abilities": abilities_database != null,
		"fully_ready": is_database_system_ready()
	}

func retry_database_load():
	"""Retry loading databases (useful if they were imported after game start)"""
	print("DatabaseManager: Retrying database load...")
	_load_all_databases()

func reload_databases():
	"""Reload all databases (useful for development)"""
	print("DatabaseManager: Reloading all databases...")
	_weapons_cache.clear()
	_armor_cache.clear()
	_consumables_cache.clear()
	_enemies_cache.clear()
	_spells_cache.clear()
	_abilities_cache.clear()
	
	_load_all_databases()
	print("DatabaseManager: All databases reloaded!")
