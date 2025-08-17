extends Node

# Enemy type constants
# These define the main categories of enemies in the game
const ENEMY_TYPE = {
	"CREATURE": "creature",      # Natural animals and beasts (rats, wolves, bears)
	"UNDEAD": "undead",          # Undead creatures (skeletons, zombies, ghosts)
	"HUMANOID": "humanoid",      # Human-like beings (goblins, orcs, humans)
	"DEMONIC": "demonic",        # Demons and infernal beings (imps, succubi, demon lords)
	"ELEMENTAL": "elemental",    # Pure elemental beings (fire spirits, ice wraiths)
	"CONSTRUCT": "construct"     # Artificial or magically created (golems, robots, enchanted armor)
}

# Enemy subtype constants
# These provide more specific categorization within each enemy type
const ENEMY_SUBTYPE = {
	"BEAST": "beast",                    # General animal subtype
	"SKELETON": "skeleton",              # Undead skeleton subtype
	"WARRIOR": "warrior",                # Combat-focused humanoid
	"DEMON": "demon",                    # General demon subtype
	"FIRE_ELEMENTAL": "fire_elemental",  # Fire-based elemental
	"ICE_ELEMENTAL": "ice_elemental",    # Ice-based elemental
	"LIGHTNING_ELEMENTAL": "lightning_elemental", # Lightning-based elemental
	"EARTH_ELEMENTAL": "earth_elemental", # Earth-based elemental
	"GOLEM": "golem",                    # Magical construct made of stone/earth
	"ROBOT": "robot",                    # Mechanical construct
	"ENCHANTED_ARMOR": "enchanted_armor" # Magically animated armor
}

# Base enemy properties
@export var enemy_name: String = "Enemy"
@export var display_name: String = ""  # Custom display name override
@export var move_speed: float = 2.5
@export var detection_range: float = 4.0
@export var combat_range: float = 2.0
@export var base_damage: int = 10
@export var base_health: int = 30
@export var base_mana: int = 10
@export var damage_range_min: int = 5  # Minimum damage
@export var damage_range_max: int = 8  # Maximum damage
@export var enemy_level: int = 1  # Enemy's level for experience rewards

# Enemy database integration
@export var enemy_id: String = ""  # Unique identifier for database lookup
@export var enemy_category: String = "basic"  # Category for database organization
@export var enemy_rarity: int = 1  # Rarity level (1=common, 2=uncommon, 3=rare, 4=epic, 5=legendary)
@export var enemy_tags: Array = []  # Tags for filtering and effects

# Enemy type system
# Use the constants above for consistent typing across the game
# Examples:
# - Big Rat: type="creature", subtype="beast"
# - Skeleton: type="undead", subtype="skeleton" 
# - Goblin: type="humanoid", subtype="warrior"
# - Fire Imp: type="demonic", subtype="demon"
# - Ice Wraith: type="elemental", subtype="ice_elemental"
# - Stone Golem: type="construct", subtype="golem"
@export var enemy_type: String = "creature"  # Main type: creature, undead, humanoid, demonic, elemental, construct, etc.
@export var enemy_subtype: String = ""  # Subtype: beast, skeleton, warrior, demon, fire_elemental, golem, etc.

# Global systems integration flags
@export var can_be_poisoned: bool = true
@export var can_be_ignited: bool = true
@export var can_be_stunned: bool = true
@export var can_be_slowed: bool = true
@export var can_be_frozen: bool = true
@export var can_be_shocked: bool = true
@export var can_be_bleeding: bool = true
@export var can_be_bone_broken: bool = true
@export var can_be_paralyzed: bool = true

# Loot and rewards
@export var base_gold_reward: int = 5
@export var gold_variance: int = 3  # +/- variance for gold drops
@export var guaranteed_loot: Array = []  # Items that always drop
@export var loot_table: Dictionary = {}  # Chance-based loot drops
@export var loot_chance_multiplier: float = 1.0  # Multiplier for loot drop chances

# Combat state
var player: Node3D = null
var in_combat: bool = false
var combat_manager: Node = null
var current_target: Node3D = null
var is_moving_to_target: bool = false
var target_position: Vector3 = Vector3.ZERO
var is_frozen: bool = false  # Flag to prevent movement during combat
var movement_attempts: int = 0  # Track movement attempts to prevent infinite loops

# Death system
var is_dead: bool = false
var death_animation_duration: float = 1.0  # Duration for death animation (placeholder)
var death_fade_timer: Timer = null
var has_given_rewards: bool = false  # Prevent double rewards
var is_processing_death: bool = false  # Track if death sequence is in progress

# Stats
@onready var stats: PlayerStats = PlayerStats.new()

# Spirit system (like players)
var spirit: int = 0
var max_spirit: int = 10

# Status bar management is now delegated to the parent (BigRat)

# Ignite system
var ignite_damage: int = 0
var ignite_duration: int = 0
var ignite_timer: Timer = null

# Bone break system
var bone_broken: bool = false
var bone_break_duration: int = 0
var bone_break_timer: Timer = null

# Status effects are now handled by the StatusEffectsManager
# Individual poison/ignite/etc. variables removed in favor of centralized system

# Focus indicator system
var focus_indicator: Node3D = null
var is_focused: bool = false

# Enemy-specific stat modifiers
@export var strength_modifier: int = 0
@export var intelligence_modifier: int = 0
@export var spell_power_modifier: int = 0
@export var dexterity_modifier: int = 0
@export var cunning_modifier: int = 0
@export var speed_modifier: int = 0

func _ready():
	# Ensure stats are properly initialized
	if not stats:
		stats = PlayerStats.new()
	
	add_child(stats)
	
	# Add to Enemy group for easy finding by combat systems
	add_to_group("Enemy")
	
	# Set the enemy's level first
	stats.set_level(enemy_level)
	
	# Set base stats (health and mana are now investable stats)
	# Convert base health to stat points (divide by 3 since each point gives 3 HP)
	var health_stat_points = int(base_health / 3.0)
	stats.set_health(health_stat_points)
	
	# Convert base mana to stat points (divide by 4 since each point gives 4 MP)
	var mana_stat_points = int(base_mana / 4.0)
	stats.set_mana(mana_stat_points)
	
	# Set combat stats with modifiers
	stats.set_strength(1 + strength_modifier)
	stats.set_intelligence(1 + intelligence_modifier)
	stats.set_spell_power(1 + spell_power_modifier)
	stats.set_dexterity(1 + dexterity_modifier)
	stats.set_cunning(1 + cunning_modifier)
	stats.set_speed(1 + speed_modifier)
	
	# Update combat chances and recalculate max stats
	stats._update_combat_chances()
	stats._recalculate_max_stats()
	
	# Start with full health and mana
	stats.health = stats.max_health
	stats.mana = stats.max_mana
	
	# Initialize floating status bars but keep them hidden initially
	update_status_bars()
	hide_status_bars()
	
	# Try to find CombatManager immediately
	_find_combat_manager()
	
	# Set up a timer as a fallback
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5  # Wait 0.5 seconds
	timer.one_shot = true
	timer.timeout.connect(_find_combat_manager)
	timer.start()
	
	# Set up ignite timer
	ignite_timer = Timer.new()
	add_child(ignite_timer)
	ignite_timer.wait_time = 1.0  # Check every second
	ignite_timer.timeout.connect(_on_ignite_tick)
	ignite_timer.start()
	
	# Set up bone break timer
	bone_break_timer = Timer.new()
	add_child(bone_break_timer)
	bone_break_timer.wait_time = 1.0  # Check every second
	bone_break_timer.timeout.connect(_on_bone_break_tick)
	bone_break_timer.start()

func _find_combat_manager():
	# Look for CombatManager by name in the current scene
	var scene = get_tree().current_scene
	if scene:
		combat_manager = scene.get_node_or_null("CombatManager")
	
	if not combat_manager:
		# Try alternative search methods
		var managers = get_tree().get_nodes_in_group("CombatManager")
		if managers.size() > 0:
			combat_manager = managers[0]

func _find_valid_player() -> Node3D:
	"""Safely find a valid Node3D player instance"""
	var found_player = get_tree().get_first_node_in_group("Player")
	if found_player and found_player is Node3D and is_instance_valid(found_player):
		return found_player
	return null

func _physics_process(delta):
	# If frozen (in combat), don't process movement
	if is_frozen:
		return
		
	if in_combat:
		# In combat mode, don't move normally
		return
		
	# Get the parent CharacterBody3D for movement
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
	
	# Additional safety check: ensure parent_body is a Node3D for global_position access
	if not parent_body is Node3D:
		print(enemy_name, " ERROR: Parent body is not a Node3D - cannot access global_position!")
		return
		
	# Basic gravity
	if not parent_body.is_on_floor():
		parent_body.velocity.y -= 20.0 * delta
	
	# Safety check: prevent extreme velocity values
	if parent_body.velocity.length() > 50.0:
		parent_body.velocity = Vector3.ZERO
	
	# Find player if not already found
	if player == null:
		player = _find_valid_player()
		if player == null:
			return
	
	# Safety check: ensure player is still valid
	if not is_instance_valid(player):
		player = null
		return
		
	# Check if player is in detection range
	if not player is Node3D:
		print(enemy_name, " ERROR: Player is not a Node3D - cannot access global_position!")
		return
	var distance_to_player = parent_body.global_position.distance_to(player.global_position)
	
	# Safety check: prevent extreme distance values
	if distance_to_player > 1000.0:
		distance_to_player = 999.0

	# If in combat and player moved too far, end combat
	if in_combat and distance_to_player > detection_range * 1.5:
		end_combat()
		return

	# Check if there's nearby combat we should join
	if not in_combat and combat_manager and combat_manager.in_combat:
		var nearby_combat = _check_for_nearby_combat()
		if nearby_combat:
			join_nearby_combat()
			return

	if distance_to_player <= detection_range and not in_combat:
		# Check if we should start combat
		if distance_to_player <= combat_range:
			start_combat()
		else:
			# Move towards player
			if not player is Node3D:
				print(enemy_name, " ERROR: Player is not a Node3D - cannot access global_position!")
				return
			var direction = (player.global_position - parent_body.global_position).normalized()
			parent_body.velocity.x = direction.x * move_speed
			parent_body.velocity.z = direction.z * move_speed
	else:
		# Stop moving if player is out of range
		parent_body.velocity.x = 0
		parent_body.velocity.z = 0
	
	# Apply movement
	parent_body.move_and_slide()

# Virtual functions that can be overridden by specific enemy types
func start_combat():
	if in_combat or not combat_manager:
		return
	
	# Ensure we have a player reference
	if not player:
		player = _find_valid_player()
		if not player:
			return
	

	
	# Face the player when combat starts
	face_target(player)
	
	# Show status bars when combat starts
	show_status_bars()
	

	
	# Safety check: ensure combat_manager is not self
	if combat_manager == self:

		return
	
	in_combat = true
	
	# Pass the parent node (CharacterBody3D) to the combat manager, not this behavior node
	var parent_body = get_parent()
	if parent_body and parent_body is CharacterBody3D:
		combat_manager.start_combat(parent_body, player)
	else:
		print(enemy_name, " ERROR: Cannot start combat - parent is not a CharacterBody3D!")
		return

func end_combat():
	in_combat = false
	
	# Hide status bars when combat ends
	hide_status_bars()
	
	# Notify combat manager if we have one
	if combat_manager and combat_manager.has_method("end_combat"):
		# Pass the parent node (CharacterBody3D) to the combat manager
		var parent_body = get_parent()
		if parent_body and parent_body is CharacterBody3D:
			combat_manager.end_combat()
		else:
			print(enemy_name, " ERROR: Cannot end combat - parent is not a CharacterBody3D!")

func take_damage(amount: int, damage_type: String = "physical"):
	"""Take damage and spawn damage numbers"""
	if is_dead or is_processing_death:
		return
	
	# Check for holy damage bonus against undead and demonic
	var final_amount = amount
	if damage_type == "holy":
		var effectiveness = get_type_effectiveness("holy")
		if effectiveness > 1.0:
			var bonus_multiplier = effectiveness - 1.0
			var holy_bonus = int(amount * bonus_multiplier)
			final_amount = amount + holy_bonus
			var enemy_type_name = get_effective_enemy_type()
			print("✨ Holy damage deals bonus damage to ", enemy_type_name, "! Base: ", amount, " + Bonus: ", holy_bonus, " = Total: ", final_amount)
	
	# Apply damage to stats
	if stats:
		stats.take_damage(final_amount)
		print(enemy_name, " took ", final_amount, " ", damage_type, " damage! Health: ", stats.health, "/", stats.max_health)
	
	# Spawn damage number
	_spawn_damage_number(amount, damage_type)
	
	# Update floating status bars
	update_status_bars()
	
	# Check if enemy is dead
	if stats and stats.health <= 0:
		print("💀 ", enemy_name, " DEFEATED! Calling die() function...")
		# Use the existing die() function
		die()
		return
	else:
		# Gain spirit from taking damage (like players do)
		gain_spirit(1)
	
	# Update combat UI with new status
	if combat_manager and combat_manager.has_method("_update_combat_ui_status"):
		# Pass the parent node (CharacterBody3D) to the combat manager
		var parent_body = get_parent()
		if parent_body and parent_body is CharacterBody3D:
			combat_manager._update_combat_ui_status()
		else:
			print(enemy_name, " ERROR: Cannot update combat UI - parent is not a CharacterBody3D!")

func _spawn_damage_number(amount: int, damage_type: String):
	"""Spawn a damage number above the enemy"""
	# Find the damage numbers system
	var damage_numbers = get_tree().get_first_node_in_group("DamageNumbers")
	if not damage_numbers:
		# Create a new damage numbers system if none exists
		damage_numbers = DamageNumbers.new()
		damage_numbers.name = "DamageNumbers"
		damage_numbers.add_to_group("DamageNumbers")
		get_tree().current_scene.add_child(damage_numbers)
	
	# Get the parent CharacterBody3D node for proper 3D positioning
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		print(enemy_name, " ERROR: Cannot spawn damage number - parent is not a CharacterBody3D!")
		return
	
	# Spawn the damage number
	if damage_numbers.has_method("spawn_damage_number"):
		damage_numbers.spawn_damage_number(amount, damage_type, parent_body)
	else:
		print("Warning: DamageNumbers system missing spawn_damage_number method")

func _check_for_nearby_combat() -> bool:
	"""Check if there's combat happening nearby that this enemy should join"""
	if not combat_manager or not combat_manager.in_combat:
		return false
	
	# Check if we're close enough to the combat area
	var parent_body = get_parent()
	if not parent_body or not parent_body is Node3D:
		return false
	
	# Get the current player position from combat manager
	var current_player = combat_manager.current_player
	if not current_player or not current_player is Node3D:
		return false
	
	var distance_to_combat = parent_body.global_position.distance_to(current_player.global_position)
	return distance_to_combat <= detection_range * 1.5  # Slightly larger range to join combat

func join_nearby_combat():
	"""Join an ongoing combat encounter"""
	if in_combat or not combat_manager or not combat_manager.in_combat:
		return
	
	print(enemy_name, " joining nearby combat!")
	
	# Get the parent body for the combat manager
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
	
	# Join the combat
	combat_manager.join_combat(parent_body)
	
	# Set combat state
	in_combat = true
	
	# Face the player
	var current_player = combat_manager.current_player
	if current_player:
		face_target(current_player)
	
	# Show status bars
	show_status_bars()

# Spirit management methods
func gain_spirit(amount: int):
	spirit = min(max_spirit, spirit + amount)
	print(enemy_name, " gained ", amount, " spirit! Total: ", spirit, "/", max_spirit)

func spend_spirit(cost: int) -> bool:
	if spirit < cost:
		return false
	spirit -= cost
	print(enemy_name, " spent ", cost, " spirit! Remaining: ", spirit, "/", max_spirit)
	return true

func _is_undead() -> bool:
	"""Check if this enemy is undead (skeleton, zombie, etc.)"""
	# Check the enemy type first
	if enemy_type == "undead":
		return true
	
	# Check enemy tags for undead-related tags
	for tag in enemy_tags:
		if tag.to_lower() in ["undead", "skeleton", "zombie", "ghost", "specter", "wraith"]:
			return true
	
	# Fallback: check if the enemy name contains undead keywords
	var enemy_name_lower = enemy_name.to_lower()
	return enemy_name_lower.contains("skeleton") or enemy_name_lower.contains("zombie") or enemy_name_lower.contains("ghost") or enemy_name_lower.contains("undead")

func is_enemy_type(check_type: String) -> bool:
	"""Check if this enemy is of a specific type"""
	return enemy_type == check_type

func has_enemy_tag(check_tag: String) -> bool:
	"""Check if this enemy has a specific tag"""
	for tag in enemy_tags:
		if tag.to_lower() == check_tag.to_lower():
			return true
	return false

func get_enemy_type_info() -> Dictionary:
	"""Get comprehensive enemy type information"""
	return {
		"type": enemy_type,
		"subtype": enemy_subtype,
		"tags": enemy_tags,
		"rarity": enemy_rarity,
		"category": enemy_category
	}

func is_demonic() -> bool:
	"""Check if this enemy is demonic"""
	return enemy_type == ENEMY_TYPE.DEMONIC or has_enemy_tag("demon") or has_enemy_tag("demonic")

func is_elemental() -> bool:
	"""Check if this enemy is elemental"""
	return enemy_type == ENEMY_TYPE.ELEMENTAL or has_enemy_tag("elemental") or has_enemy_tag("fire") or has_enemy_tag("ice") or has_enemy_tag("lightning") or has_enemy_tag("earth")

func is_undead() -> bool:
	"""Check if this enemy is undead (skeleton, zombie, ghost, etc.)"""
	return enemy_type == ENEMY_TYPE.UNDEAD or has_enemy_tag("undead") or has_enemy_tag("skeleton") or has_enemy_tag("zombie") or has_enemy_tag("ghost")

func is_construct() -> bool:
	"""Check if this enemy is a construct (golem, robot, enchanted armor, etc.)"""
	return enemy_type == ENEMY_TYPE.CONSTRUCT or has_enemy_tag("construct") or has_enemy_tag("golem") or has_enemy_tag("robot") or has_enemy_tag("enchanted") or has_enemy_tag("artificial")

func get_effective_enemy_type() -> String:
	"""Get the effective enemy type, considering both type and tags"""
	if is_undead():
		return ENEMY_TYPE.UNDEAD
	elif is_demonic():
		return ENEMY_TYPE.DEMONIC
	elif is_elemental():
		return ENEMY_TYPE.ELEMENTAL
	elif is_construct():
		return ENEMY_TYPE.CONSTRUCT
	elif is_enemy_type(ENEMY_TYPE.HUMANOID):
		return ENEMY_TYPE.HUMANOID
	else:
		return enemy_type

func get_type_effectiveness(damage_type: String) -> float:
	"""Get damage effectiveness multiplier based on enemy type vs damage type"""
	# This can be expanded for future type-based damage systems
	match damage_type.to_lower():
		"holy":
			if is_undead():
				return 1.5  # Holy damage is 50% more effective against undead
			elif is_demonic():
				return 1.3  # Holy damage is 30% more effective against demons
			else:
				return 1.0  # Normal effectiveness
		"lightning":
			if is_construct():
				return 1.4  # Lightning is 40% more effective against constructs
			elif is_elemental() and enemy_subtype.find("water") >= 0:
				return 1.6  # Lightning is 60% more effective against water elementals
			else:
				return 1.0  # Normal effectiveness
		"fire":
			if is_elemental() and enemy_subtype.find("ice") >= 0:
				return 1.5  # Fire is 50% more effective against ice elementals
			else:
				return 1.0  # Normal effectiveness
		"ice":
			if is_elemental() and enemy_subtype.find("fire") >= 0:
				return 1.5  # Ice is 50% more effective against fire elementals
			else:
				return 1.0  # Normal effectiveness
		_:
			return 1.0  # Default effectiveness for other damage types

func can_use_special_attack() -> bool:
	# Override in specific enemy types to check spirit cost
	return true

# Combat methods - can be overridden by specific enemy types
func melee_attack():
	print("=== BASE ENEMY melee_attack() CALLED ===")
	print(enemy_name, " DEBUG: BASE ENEMY melee_attack() called!")
	
	# Check if enemy is dead or dying
	if is_dead or is_processing_death:
		print("💀 ", enemy_name, " cannot perform melee attack - is dead or dying")
		return
	
	if not in_combat or not current_target:
		print(enemy_name, " ERROR: Cannot perform melee attack - not in combat or no target")
		return
	
	# Safety check: ensure target is still valid
	if not is_instance_valid(current_target):
		print(enemy_name, " ERROR: Target is no longer valid!")
		if combat_manager:
			combat_manager.end_current_turn()
		return
		
	print(enemy_name, " performs melee attack!")
	
	# Check if we need to move to target first
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
	
	# Additional safety check: ensure parent_body is a Node3D for global_position access
	if not parent_body is Node3D:
		print(enemy_name, " ERROR: Parent body is not a Node3D - cannot access global_position!")
		return
		
	if not current_target is Node3D:
		print(enemy_name, " ERROR: Current target is not a Node3D - cannot access global_position!")
		return
	var distance_to_target = parent_body.global_position.distance_to(current_target.global_position)
	if distance_to_target > 2.0:  # Need to get closer (increased from 1.5 to 2.0)
		# Safety check: prevent infinite movement loops
		if movement_attempts >= 3:
			print(enemy_name, " DEBUG: Too many movement attempts (", movement_attempts, "), attacking from current position")
			movement_attempts = 0  # Reset for next turn
		else:
			print(enemy_name, " DEBUG: Too far (", distance_to_target, " > 2.0), calling move_to_target (attempt ", movement_attempts + 1, ")")
			movement_attempts += 1
			move_to_target(current_target)
			return
	
	# Perform attack
	print(enemy_name, " DEBUG: Calling get_attack_damage()")
	var damage = get_attack_damage()
	print(enemy_name, " deals ", damage, " damage!")
	
	# Use combat manager's damage handler to apply defense
	if combat_manager and combat_manager.has_method("handle_player_damage"):
		# Pass the parent node (CharacterBody3D) to the combat manager
		if parent_body and parent_body is CharacterBody3D:
			combat_manager.handle_player_damage(damage, "basic attack")
		else:
			print(enemy_name, " ERROR: Cannot handle player damage - parent is not a CharacterBody3D!")
	else:
		# Fallback: direct damage if no combat manager
		if current_target.has_method("take_damage"):
			current_target.take_damage(damage, "physical")  # Enemy attacks are physical damage
	
	# Gain spirit from attacking (like players do)
	gain_spirit(1)
	
	# Wait for animation to complete before ending turn
	if combat_manager and combat_manager.has_method("wait_for_animation_then_end_turn"):
		print(enemy_name, " waiting for animation to complete before ending turn")
		combat_manager.wait_for_animation_then_end_turn(self)
	else:
		# Fallback: end turn immediately if animation system not available
		print(enemy_name, " ending turn immediately (no animation system)")
		if combat_manager:
			if combat_manager.has_method("end_enemy_turn"):
				combat_manager.end_enemy_turn()
			else:
				combat_manager.end_current_turn()
		else:
			print(enemy_name, " WARNING: No combat manager to end turn!")

# Lightning paralysis methods for enemies
func get_lightning_paralysis_chance() -> float: return 25.0
func is_lightning_attack(attack_type: String) -> bool:
	match attack_type:
		"lightning_bolt", "lightning_weapon_basic", "lightning_weapon_special": return true
		_: return false

func move_to_target(target: Node):
	print(enemy_name, " DEBUG: BASE ENEMY move_to_target() called!")
	
	if not target:
		print(enemy_name, " ERROR: No target for movement!")
		return
	
	if not target is Node3D:
		print(enemy_name, " ERROR: Target must be a Node3D to access global_position!")
		return
		
	# Get the parent CharacterBody3D for positioning
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
	
	# Additional safety check: ensure parent_body is a Node3D for global_position access
	if not parent_body is Node3D:
		print(enemy_name, " ERROR: Parent body is not a Node3D - cannot access global_position!")
		return
		
	print(enemy_name, " moving to target...")
	current_target = target
	is_moving_to_target = true
	
	# Calculate position in front of target
	var direction = (target.global_position - parent_body.global_position).normalized()
	target_position = target.global_position - (direction * 1.5)  # Stop 1.5 units in front
	
	print(enemy_name, " DEBUG: Current position: ", parent_body.global_position)
	print(enemy_name, " DEBUG: Target position: ", target.global_position)
	print(enemy_name, " DEBUG: Moving to: ", target_position)
	print(enemy_name, " DEBUG: Distance to target: ", parent_body.global_position.distance_to(target.global_position))
	print(enemy_name, " DEBUG: Distance to target position: ", parent_body.global_position.distance_to(target_position))
	
	# Move towards target position
	var tween = create_tween()
	tween.tween_property(parent_body, "global_position", target_position, 1.0)
	tween.tween_callback(_on_move_to_target_complete)

func get_target_name(target: Node) -> String:
	"""Safely get the name of a target"""
	if not target:
		return "null"
	
	if not target is Node3D:
		return "non-spatial-node"
	
	if target.has_method("get_name"):
		return target.get_name()
	elif target.has_method("name"):
		return target.name
	else:
		return str(target)

func set_combat_target(target: Node):
	"""Set the target for combat"""
	if not target:
		print(enemy_name, " ERROR: Cannot set combat target to null!")
		return
	
	if not target is Node3D:
		print(enemy_name, " ERROR: Target must be a Node3D to access global_position!")
		return
	
	var target_name: String = "Unknown"
	if target.has_method("get_name"):
		target_name = target.get_name()
	elif target.has_method("name"):
		target_name = target.name
	else:
		target_name = str(target)
	
	print(enemy_name, " set_combat_target called with: ", target_name)
	current_target = target
	var current_target_name: String = "Unknown"
	if current_target:
		if current_target.has_method("get_name"):
			current_target_name = current_target.get_name()
		elif current_target.has_method("name"):
			current_target_name = current_target.name
		else:
			current_target_name = str(current_target)
	else:
		current_target_name = "null"
	print(enemy_name, " current_target set to: ", current_target_name)

func _on_move_to_target_complete():
	print(enemy_name, " DEBUG: BASE ENEMY _on_move_to_target_complete() called!")
	is_moving_to_target = false
	
	# Debug: Check final positions
	var parent_body = get_parent()
	if parent_body and current_target:
		if not current_target is Node3D:
			print(enemy_name, " ERROR: Current target is not a Node3D - cannot access global_position!")
			return
		print(enemy_name, " DEBUG: Final position: ", parent_body.global_position)
		print(enemy_name, " DEBUG: Target position: ", current_target.global_position)
		print(enemy_name, " DEBUG: Final distance to target: ", parent_body.global_position.distance_to(current_target.global_position))
	
	# Now perform the attack
	print(enemy_name, " DEBUG: Calling melee_attack() after movement")
	melee_attack()

# Virtual function for custom behavior - can be overridden
func on_combat_start():
	# Override in specific enemy types for custom behavior
	# Show status bars when combat starts
	show_status_bars()

func on_combat_end():
	# Override in specific enemy types for custom behavior
	# Hide status bars when combat ends
	hide_status_bars()

func on_death():
	# Override in specific enemy types for custom death behavior
	pass

func die():
	"""Handle enemy death - disappear, give rewards, and clean up"""
	if is_dead:
		print("⚠️ ", enemy_name, " is already dead!")
		return
	
	if is_processing_death:
		print("⚠️ ", enemy_name, " is already processing death!")
		return
	
	print("💀 ", enemy_name, " is dying!")
	is_dead = true
	is_processing_death = true
	
	# Immediately stop all movement and combat
	stop_movement()
	leave_combat()
	
	# Immediately disable all enemy actions
	disable_all_actions()
	
	# Give rewards (XP and loot)
	_give_death_rewards()
	
	# Start death sequence (disappear with fade effect)
	_start_death_sequence()
	
	# Call custom death behavior
	on_death()

func _give_death_rewards():
	"""Give XP and loot rewards when enemy dies"""
	if has_given_rewards:
		print("⚠️ ", enemy_name, " already gave rewards!")
		return
	
	has_given_rewards = true
	
	# Safety check: ensure we have a valid player reference
	if not player:
		print("⚠️ ", enemy_name, " has no player reference for rewards!")
		# Try to find player from scene
		player = _find_valid_player()
		if not player:
			print("⚠️ ", enemy_name, " still cannot find player - skipping rewards!")
			return
	
	# Additional safety: ensure player is still valid
	if not is_instance_valid(player):
		print("⚠️ ", enemy_name, " player reference is no longer valid!")
		# Try to find player from scene again
		player = _find_valid_player()
		if not player or not is_instance_valid(player):
			print("⚠️ ", enemy_name, " still cannot find valid player - skipping rewards!")
			return
	
	# Give XP to player
	_award_experience_on_death()
	
	# Drop loot
	_drop_loot()
	
	# Drop gold
	_drop_gold()

func _drop_loot():
	"""Drop loot items when enemy dies"""
	if not player or not player is Node3D or not player.has_method("receive_item"):
		print("⚠️ No valid Node3D player to receive loot!")
		return
	
	print("📦 ", enemy_name, " dropping loot...")
	print("🔍 Debug - loot_table type: ", typeof(loot_table), " content: ", loot_table)
	
	# Safety check: ensure loot_table is actually a Dictionary
	if not loot_table is Dictionary:
		print("⚠️ Loot table is not a Dictionary! Type: ", typeof(loot_table))
		return
	
	# Drop guaranteed loot
	for loot_item in guaranteed_loot:
		if loot_item:
			print("🎯 Guaranteed loot: ", loot_item.name)
			player.receive_item(loot_item)
	
	# Drop chance-based loot
	for loot_key in loot_table:
		var loot_data = loot_table[loot_key]
		
		# Safety check: ensure loot_data is a Dictionary
		if not loot_data is Dictionary:
			print("⚠️ Invalid loot data format for key: ", loot_key, " (expected Dictionary, got: ", typeof(loot_data), ")")
			continue
		
		var drop_chance = loot_data.get("chance", 0.0) * loot_chance_multiplier
		
		if randf() <= drop_chance:
			var loot_item = loot_data.get("item")
			if loot_item:
				print("🎲 Lucky loot drop: ", loot_item.name, " (", drop_chance * 100, "% chance)")
				player.receive_item(loot_item)

func _drop_gold():
	"""Drop gold when enemy dies"""
	if not player or not player is Node3D or not player.has_method("receive_gold"):
		print("⚠️ No valid Node3D player to receive gold!")
		return
	
	var gold_amount = base_gold_reward
	if gold_variance > 0:
		gold_amount += randi_range(-gold_variance, gold_variance)
	
	gold_amount = max(1, gold_amount)  # Minimum 1 gold
	print("💰 ", enemy_name, " dropped ", gold_amount, " gold!")
	player.receive_gold(gold_amount)

func _start_death_sequence():
	"""Start the death sequence - fade out and disappear"""
	# Create fade timer
	death_fade_timer = Timer.new()
	add_child(death_fade_timer)
	death_fade_timer.wait_time = death_animation_duration
	death_fade_timer.one_shot = true
	death_fade_timer.timeout.connect(_on_death_fade_complete)
	
	# Start fade effect (placeholder - will be replaced with proper animation)
	_start_fade_effect()
	
	# Start the timer
	death_fade_timer.start()
	
	# Add a safety timer to ensure enemy is removed even if fade effect fails
	var safety_timer = Timer.new()
	add_child(safety_timer)
	safety_timer.wait_time = death_animation_duration + 2.0  # Give extra time
	safety_timer.one_shot = true
	safety_timer.timeout.connect(_on_safety_timer_timeout)
	safety_timer.start()

func _start_fade_effect():
	"""Start the fade out effect (placeholder for death animation)"""
	# This is a placeholder - later we'll replace this with proper death animations
	# For now, just make the enemy semi-transparent
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		# Create a tween to fade out
		var tween = create_tween()
		tween.tween_property(mesh_instance, "transparency", 0.8, death_animation_duration)
	else:
		# Fallback: try to apply fade effect to the parent if it's a Node3D
		var parent_body = get_parent()
		if parent_body and parent_body is Node3D:
			var tween = create_tween()
			tween.tween_property(parent_body, "transparency", 0.8, death_animation_duration)

func _find_mesh_instance():
	"""Find the mesh instance for visual effects"""
	# Look for MeshInstance3D in the enemy hierarchy
	var mesh_instance = null
	
	# Try to find by type
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
		elif child is Node3D:
			# Recursively search children
			mesh_instance = _find_mesh_instance_recursive(child)
			if mesh_instance:
				break
	
	return mesh_instance

func _find_mesh_instance_recursive(node: Node3D):
	"""Recursively search for MeshInstance3D"""
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		elif child is Node3D:
			var result = _find_mesh_instance_recursive(child)
			if result:
				return result
	return null

func _on_death_fade_complete():
	"""Called when death fade effect completes"""
	print("💀 ", enemy_name, " death sequence complete - removing from scene")
	
	# Reset death processing flag
	is_processing_death = false
	
	# Try to remove from combat system if still in combat, but don't fail if it doesn't work
	if combat_manager and combat_manager.has_method("remove_enemy_from_combat"):
		# Check if combat is still active before trying to remove
		if combat_manager.in_combat:
			# Pass the parent node (CharacterBody3D) to the combat manager
			var parent_body = get_parent()
			if parent_body and parent_body is CharacterBody3D:
				combat_manager.remove_enemy_from_combat(parent_body)
			else:
				print("💀 ERROR: Cannot remove from combat - parent is not a CharacterBody3D!")
		else:
			print("💀 Combat already ended, enemy will be removed directly")
	
	# Remove the parent node (the actual enemy character) instead of just this behavior component
	# This ensures the entire enemy disappears from the scene
	var parent_node = get_parent()
	if parent_node:
		print("💀 Removing parent node: ", parent_node.name)
		parent_node.queue_free()
	else:
		print("💀 No parent node found, removing self")
		queue_free()
	
	print("✅ ", enemy_name, " successfully removed from scene")

func _on_safety_timer_timeout():
	"""Safety fallback to ensure enemy is removed if death sequence fails"""
	if not is_processing_death:
		return  # Already processed
		
	print("⚠️ Safety timer triggered for ", enemy_name, " - forcing removal")
	is_processing_death = false
	
	# Remove the parent node (the actual enemy character) instead of just this behavior component
	var parent_node = get_parent()
	if parent_node:
		print("💀 Safety timer removing parent node: ", parent_node.name)
		parent_node.queue_free()
	else:
		print("💀 Safety timer: No parent node found, removing self")
		queue_free()
	
	print("✅ ", enemy_name, " forcibly removed by safety timer")

func stop_movement():
	"""Stop all movement"""
	is_moving_to_target = false
	target_position = Vector3.ZERO
	movement_attempts = 0
	
	# Stop any movement timers or tweens
	if death_fade_timer and is_instance_valid(death_fade_timer):
		death_fade_timer.stop()

func disable_all_actions():
	"""Disable all enemy actions when dying"""
	print("🚫 ", enemy_name, " disabling all actions due to death")
	
	# Stop all movement
	stop_movement()
	
	# Clear all targets and combat state
	current_target = null
	in_combat = false
	
	# Disable physics processing to prevent any further updates
	set_physics_process_enabled(false)
	
	# Stop any active timers
	if death_fade_timer and is_instance_valid(death_fade_timer):
		death_fade_timer.stop()
	
	print("✅ ", enemy_name, " all actions disabled")

func leave_combat():
	"""Leave combat when dying"""
	# Don't call remove_enemy_from_combat here - it will be called in _on_death_fade_complete
	# This prevents double removal which could cause issues
	
	in_combat = false
	current_target = null

func set_physics_process_enabled(enabled: bool):
	if enabled:
		set_physics_process_internal(true)
		is_frozen = false
	else:
		set_physics_process_internal(false)
		is_frozen = true
	
	# Also control input processing
	set_process_input(enabled)
	
	# Control movement during combat
	if not enabled:
		# When disabled, stop all movement
		var parent_body = get_parent()
		if parent_body and parent_body is CharacterBody3D:
			parent_body.velocity = Vector3.ZERO

func get_stats() -> PlayerStats:
	"""Return the enemy's stats for the combat system"""
	if not stats or not is_instance_valid(stats):
		# Create stats if they don't exist
		stats = PlayerStats.new()
		add_child(stats)
		
		# Re-initialize stats using the new system
		stats.set_level(enemy_level)
		
		# Convert base health/mana to stat points
		var health_stat_points = int(base_health / 3.0)
		var mana_stat_points = int(base_mana / 4.0)
		stats.set_health(health_stat_points)
		stats.set_mana(mana_stat_points)
		
		# Set combat stats with modifiers
		stats.set_strength(1 + strength_modifier)
		stats.set_intelligence(1 + intelligence_modifier)
		stats.set_spell_power(1 + spell_power_modifier)
		stats.set_dexterity(1 + dexterity_modifier)
		stats.set_cunning(1 + cunning_modifier)
		stats.set_speed(1 + speed_modifier)
		
		# Update combat chances and recalculate max stats
		stats._update_combat_chances()
		stats._recalculate_max_stats()
		
		# Start with full health and mana
		stats.health = stats.max_health
		stats.mana = stats.max_mana
	
	return stats



func get_camera() -> Camera3D:
	"""Get the camera from the enemy's parent body for combat orientation"""
	var parent_body = get_parent()
	if parent_body and parent_body is CharacterBody3D:
		# Look for camera in the parent's children
		var camera = parent_body.get_node_or_null("SpringArm3D/Camera3D")
		if camera:
			return camera
		# Fallback: look for any camera
		camera = parent_body.get_node_or_null("Camera3D")
		if camera:
			return camera
	return null

func get_enemy_name() -> String:
	"""Get the enemy's display name - automatically derived from custom override or fallback"""
	# Check if there's a custom display name set
	if has_method("get_custom_display_name"):
		var custom_name = get_custom_display_name()
		if custom_name and custom_name != "":
			return custom_name
	
	# Check if display_name property is set
	if display_name != "":
		return display_name
	
	# Fallback to the enemy_name property
	return enemy_name

func get_custom_display_name() -> String:
	"""Override this method in subclasses to provide custom display names"""
	return ""

func get_experience_reward() -> int:
	"""Get the experience reward for defeating this enemy"""
	# Base experience reward based on enemy level
	var base_exp = enemy_level * 15
	
	# Bonus for higher level enemies
	var bonus_exp = max(0, enemy_level - 1) * 5
	
	var total_exp = base_exp + bonus_exp
	print(enemy_name, " (Level ", enemy_level, ") gives ", total_exp, " experience when defeated")
	return total_exp

func get_attack_damage() -> int:
	# Return random damage within the enemy's damage range + strength bonus
	var attack_damage = randi_range(damage_range_min, damage_range_max)
	
	if not stats:
		return attack_damage
	
	var multiplier = stats.get_melee_damage_multiplier()
	var final_damage = int(attack_damage * multiplier)
	
	return final_damage

func apply_ignite(initial_damage: int, duration: int = 3):
	# Apply or refresh ignite effect
	ignite_damage = int(initial_damage * 0.2)  # 20% of initial damage
	ignite_duration = duration
	print(enemy_name, " is ignited! Will take ", ignite_damage, " damage per turn for ", ignite_duration, " turns!")

func _on_ignite_tick():
	if ignite_duration > 0:
		# Take ignite damage
		take_damage(ignite_damage, "ignite")
		ignite_duration -= 1
		print(enemy_name, " takes ", ignite_damage, " ignite damage! Duration remaining: ", ignite_duration, " turns")
		
		if ignite_duration <= 0:
			print(enemy_name, " is no longer ignited!")
			ignite_damage = 0

func apply_bone_break(duration: int = 3):
	# Apply bone break effect
	bone_broken = true
	bone_break_duration = duration
	print(enemy_name, " has a broken bone! Will take increased damage for ", bone_break_duration, " turns!")

func _on_bone_break_tick():
	if bone_break_duration > 0:
		bone_break_duration -= 1
		print(enemy_name, " bone break duration remaining: ", bone_break_duration, " turns")
		
		if bone_break_duration <= 0:
			print(enemy_name, " bone has healed!")
			bone_broken = false

# Default turn behavior - can be overridden by specific enemy types
func take_turn():
	print("=== BASE ENEMY take_turn() CALLED ===")
	print(enemy_name, " DEBUG: BASE ENEMY take_turn() called!")
	print(enemy_name, " take_turn() called!")
	
	# Check if enemy is dead or dying
	if is_dead or is_processing_death:
		print("💀 ", enemy_name, " cannot take turn - is dead or dying")
		return
	
	print("  in_combat: ", in_combat)
	print("  current_target: ", current_target)
	print("  combat_manager: ", combat_manager)
	
	if not in_combat:
		print("  ERROR: Not in combat!")
		return
	
	if not current_target:
		print("  ERROR: No current target!")
		return
	
	# Safety check: ensure target is still valid
	if not is_instance_valid(current_target):
		print("  ERROR: Target is no longer valid!")
		return
	
	print("  Taking turn against target: ", get_target_name(current_target))
	
	# Face the target before taking action
	face_target(current_target)
	
	# Default behavior: use basic melee attack
	print(enemy_name, " DEBUG: Calling melee_attack() from base take_turn")
	melee_attack()

# Combat facing methods
func face_target(target: Node):
	print(enemy_name, " DEBUG: BASE ENEMY face_target() called!")
	
	if not target:
		print(enemy_name, " ERROR: No target for facing!")
		return
	
	if not target is Node3D:
		print(enemy_name, " ERROR: Target must be a Node3D to access global_position!")
		return
	
	# Get the parent CharacterBody3D for positioning
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
	
	# Calculate direction to target
	if not target is Node3D:
		print(enemy_name, " ERROR: Target is not a Node3D - cannot access global_position!")
		return
	var direction = (target.global_position - parent_body.global_position).normalized()
	
	# Only rotate around Y axis (don't tilt up/down)
	direction.y = 0
	direction = direction.normalized()
	
	if direction != Vector3.ZERO:
		# Calculate rotation to face target
		var target_rotation = atan2(direction.x, direction.z)
		
		# Smoothly rotate to face target
		var tween = create_tween()
		tween.tween_property(parent_body, "rotation:y", target_rotation, 0.3)
		
		print(enemy_name, " facing target at rotation: ", target_rotation)

func get_level() -> int:
	"""Get the current enemy level"""
	return enemy_level

func get_armor_value() -> int:
	"""Get the enemy's armor value for damage reduction calculations"""
	# Base armor value - can be overridden by specific enemy types
	return 0

func update_health_bar():
	"""Update the floating health bar above the enemy's head"""
	# Delegate to parent if it has the function
	if get_parent() and get_parent().has_method("update_status_bars"):
		get_parent().update_status_bars()
		return

func update_mana_bar():
	"""Update the floating mana bar above the enemy's head"""
	# Delegate to parent if it has the function
	if get_parent() and get_parent().has_method("update_status_bars"):
		get_parent().update_status_bars()
		return

func update_status_bars():
	"""Update both health and mana bars"""
	print(enemy_name, " DEBUG: update_status_bars() called in enemy.gd")
	if get_parent() and get_parent().has_method("update_status_bars"):
		print(enemy_name, " DEBUG: Delegating to parent's update_status_bars()")
		get_parent().update_status_bars()
	else:
		print(enemy_name, " ERROR: Parent does not have update_status_bars method!")

func show_status_bars():
	"""Show the status bars above the enemy's head - DISABLED, now shown in top panel"""
	# Status bars are now displayed in the top enemy status panel
	# This function is kept for compatibility but does nothing
	print(enemy_name, ": show_status_bars() called - Status bars now displayed in top panel")

func hide_status_bars():
	"""Hide the status bars - DISABLED, now handled by top panel"""
	# Status bars are now handled by the top enemy status panel
	# This function is kept for compatibility but does nothing
	print(enemy_name, ": hide_status_bars() called - Status bars now handled by top panel")

# Note: Health and mana bars are 2D UI elements positioned above the enemy
# They automatically face the camera due to their 2D nature
# No need for manual rotation handling

# Status effects are now handled by the StatusEffectsManager
# Individual poison methods removed in favor of centralized system

func _award_experience_on_death():
	"""Award experience to the player when this enemy dies"""
	# Try multiple ways to find the player
	var target_player = null
	
	# First try: use our stored player reference
	if player and is_instance_valid(player):
		target_player = player
	
	# Second try: use combat manager's current player
	elif combat_manager and combat_manager.current_player and is_instance_valid(combat_manager.current_player):
		if combat_manager.current_player is Node3D:
			target_player = combat_manager.current_player
	
	# Third try: find player in scene
	else:
		target_player = _find_valid_player()
	
	# Final check: ensure we have a valid player
	if not target_player:
		print(enemy_name, " cannot award XP - no valid player found anywhere")
		return
	
	if not target_player is Node3D:
		print(enemy_name, " ERROR: Target player is not a Node3D!")
		return
	
	if not target_player.has_method("get_stats"):
		print(enemy_name, " cannot award XP - player has no stats")
		return
	
	var player_stats = target_player.get_stats()
	if not player_stats:
		print(enemy_name, " cannot award XP - player stats is null")
		return
	
	var exp_reward = get_experience_reward()
	player_stats.gain_experience(exp_reward)
	print("🎉 ", enemy_name, " awarded ", exp_reward, " XP to player!")
	
	# Log the XP gain in combat UI if available
	if combat_manager and combat_manager.has_method("_log_combat_event"):
		# Pass the parent node (CharacterBody3D) to the combat manager
		var parent_body = get_parent()
		if parent_body and parent_body is CharacterBody3D:
			combat_manager._log_combat_event("🎉 " + enemy_name + " awarded " + str(exp_reward) + " XP!")
		else:
			print(enemy_name, " ERROR: Cannot log combat event - parent is not a CharacterBody3D!")

# Global systems integration methods
func can_receive_status_effect(effect_type: String) -> bool:
	"""Check if this enemy can receive a specific status effect"""
	match effect_type:
		"poison":
			return can_be_poisoned
		"ignite":
			return can_be_ignited
		"stun":
			return can_be_stunned
		"slow":
			return can_be_slowed
		"freeze":
			return can_be_frozen
		"shock":
			return can_be_shocked
		"bleed":
			return can_be_bleeding
		"bone_break":
			return can_be_bone_broken
		"paralysis":
			return can_be_paralyzed
		_:
			return true  # Default to allowing unknown effects

func get_status_effect_resistance(effect_type: String) -> float:
	"""Get resistance multiplier for a specific status effect (0.0 = immune, 1.0 = no resistance)"""
	# Base resistance based on enemy level and stats
	var base_resistance = 1.0 - (enemy_level * 0.02)  # Higher level enemies have slight resistance
	
	# Apply stat-based resistances
	if stats:
		match effect_type:
			"poison":
				base_resistance *= (1.0 - (stats.cunning * 0.01))  # Cunning reduces poison effectiveness
			"ignite":
				base_resistance *= (1.0 - (stats.intelligence * 0.01))  # Intelligence reduces fire effectiveness
			"stun":
				base_resistance *= (1.0 - (stats.strength * 0.01))  # Strength reduces stun effectiveness
			"slow":
				base_resistance *= (1.0 - (stats.speed * 0.01))  # Speed reduces slow effectiveness
	
	return max(0.0, min(1.0, base_resistance))  # Clamp between 0.0 and 1.0

func apply_status_effect(effect_type: String, damage: int, duration: int, source: Node) -> bool:
	"""Apply a status effect if the enemy can receive it"""
	if not can_receive_status_effect(effect_type):
		print(enemy_name, " is immune to ", effect_type, " effects!")
		return false
	
	var resistance = get_status_effect_resistance(effect_type)
	if resistance <= 0.0:
		print(enemy_name, " is completely immune to ", effect_type, " effects!")
		return false
	
	# Apply resistance to effect
	var adjusted_damage = int(damage * resistance)
	var adjusted_duration = int(duration * resistance)
	
	print(enemy_name, " receives ", effect_type, " effect with ", resistance * 100, "% resistance!")
	print("  Adjusted damage: ", adjusted_damage, " (was ", damage, ")")
	print("  Adjusted duration: ", adjusted_duration, " (was ", duration, ")")
	
	# Use the status effects manager
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if status_manager:
		match effect_type:
			"poison":
				status_manager.apply_poison(self, adjusted_damage, adjusted_duration, source)
			"ignite":
				status_manager.apply_ignite(self, adjusted_damage, adjusted_duration, source)
			"paralysis":
				status_manager.apply_paralysis(self, adjusted_duration, source)
			"stun":
				status_manager.apply_stun(self, adjusted_duration, source)
			"slow":
				status_manager.apply_slow(self, adjusted_duration, source)
			"freeze":
				status_manager.apply_effect(self, status_manager.EFFECT_TYPE.FREEZE, adjusted_damage, adjusted_duration, source)
			"shock":
				status_manager.apply_effect(self, status_manager.EFFECT_TYPE.SHOCK, adjusted_damage, adjusted_duration, source)
			"bleed":
				status_manager.apply_effect(self, status_manager.EFFECT_TYPE.BLEED, adjusted_damage, adjusted_duration, source)
			"bone_break":
				status_manager.apply_bone_break(self, adjusted_duration, source)
		return true
	else:
		print("WARNING: StatusEffectsManager not found! Cannot apply ", effect_type, " effect.")
		return false

# Loot and rewards methods
func get_gold_reward() -> int:
	"""Get the gold reward for defeating this enemy"""
	var variance = randi_range(-gold_variance, gold_variance)
	var total_gold = base_gold_reward + variance
	return max(0, total_gold)  # Ensure non-negative gold

func get_loot_drops() -> Array:
	"""Get loot drops based on loot table and guaranteed items"""
	var drops = []
	
	# Add guaranteed loot
	for item_id in guaranteed_loot:
		drops.append(item_id)
	
	# Check chance-based loot
	for item_id in loot_table:
		var drop_chance = loot_table[item_id] * loot_chance_multiplier
		if randf() <= drop_chance:
			drops.append(item_id)
	
	return drops

# Database integration methods
func get_database_entry() -> Dictionary:
	"""Get a database entry for this enemy"""
	return {
		"id": enemy_id,
		"name": enemy_name,
		"level": enemy_level,
		"category": enemy_category,
		"rarity": enemy_rarity,
		"tags": enemy_tags,
		"base_stats": {
			"health": base_health,
			"mana": base_mana,
			"damage": base_damage,
			"damage_range": [damage_range_min, damage_range_max]
		},
		"status_effects": {
			"can_be_poisoned": can_be_poisoned,
			"can_be_ignited": can_be_ignited,
			"can_be_stunned": can_be_stunned,
			"can_be_slowed": can_be_slowed,
			"can_be_frozen": can_be_frozen,
			"can_be_shocked": can_be_shocked,
			"can_be_bleeding": can_be_bleeding,
			"can_be_bone_broken": can_be_bone_broken
		},
		"rewards": {
			"base_gold": base_gold_reward,
			"gold_variance": gold_variance,
			"guaranteed_loot": guaranteed_loot,
			"loot_table": loot_table
		}
	}

func load_from_database_entry(entry: Dictionary):
	"""Load enemy properties from a database entry"""
	if entry.has("id"):
		enemy_id = entry.id
	if entry.has("name"):
		enemy_name = entry.name
	if entry.has("level"):
		enemy_level = entry.level
	if entry.has("category"):
		enemy_category = entry.category
	if entry.has("rarity"):
		enemy_rarity = entry.rarity
	if entry.has("tags"):
		enemy_tags.clear()
		for tag in entry.tags:
			enemy_tags.append(tag)
	
	# Load base stats
	if entry.has("base_stats"):
		var base_stats_data = entry.base_stats
		if base_stats_data.has("health"):
			base_health = base_stats_data.health
		if base_stats_data.has("mana"):
			base_mana = base_stats_data.mana
		if base_stats_data.has("damage"):
			base_damage = base_stats_data.damage
		if base_stats_data.has("damage_range") and base_stats_data.damage_range.size() >= 2:
			damage_range_min = base_stats_data.damage_range[0]
			damage_range_max = base_stats_data.damage_range[1]
	
	# Load status effect flags
	if entry.has("status_effects"):
		var effects = entry.status_effects
		if effects.has("can_be_poisoned"):
			can_be_poisoned = effects.can_be_poisoned
		if effects.has("can_be_ignited"):
			can_be_ignited = effects.can_be_ignited
		if effects.has("can_be_stunned"):
			can_be_stunned = effects.can_be_stunned
		if effects.has("can_be_slowed"):
			can_be_slowed = effects.can_be_slowed
		if effects.has("can_be_frozen"):
			can_be_frozen = effects.can_be_frozen
		if effects.has("can_be_shocked"):
			can_be_shocked = effects.can_be_shocked
		if effects.has("can_be_bleeding"):
			can_be_bleeding = effects.can_be_bleeding
		if effects.has("can_be_bone_broken"):
			can_be_bone_broken = effects.can_be_bone_broken
	
	# Load rewards
	if entry.has("rewards"):
		var rewards = entry.rewards
		if rewards.has("base_gold"):
			base_gold_reward = rewards.base_gold
		if rewards.has("gold_variance"):
			gold_variance = rewards.gold_variance
		if rewards.has("guaranteed_loot"):
			# Handle array assignment carefully
			guaranteed_loot.clear()
			for item in rewards.guaranteed_loot:
				guaranteed_loot.append(item)
		if rewards.has("loot_table"):
			loot_table = rewards.loot_table

# Focus indicator methods
func create_focus_indicator():
	"""Create a visual indicator showing this enemy is focused"""
	print("🎯 create_focus_indicator() called for: ", enemy_name)
	
	if focus_indicator:
		print("🎯 Focus indicator already exists for: ", enemy_name)
		return  # Already exists
	
	print("🎯 Creating focus indicator for: ", enemy_name)
	
	# Create a simple, highly visible focus indicator
	focus_indicator = Node3D.new()
	focus_indicator.name = "FocusIndicator"
	
	# Create a mesh instance for the glowing edge
	var mesh_instance = MeshInstance3D.new()
	var edge_mesh = CylinderMesh.new()
	edge_mesh.radius = 1.5  # Larger radius for visibility
	edge_mesh.height = 0.1  # Thicker for visibility
	mesh_instance.mesh = edge_mesh
	
	# Position it at ground level
	mesh_instance.position.y = 0.05
	
	# Create material for the glowing edge - make it very bright and visible
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 1.0, 1.0, 1.0)  # Bright cyan
	material.emission_enabled = true
	material.emission = Color(0.0, 1.0, 1.0, 1.0)  # Bright cyan glow
	material.emission_energy = 3.0  # Very strong glow
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	
	focus_indicator.add_child(mesh_instance)
	add_child(focus_indicator)
	
	print("🎯 Focus indicator created and added to scene for: ", enemy_name)
	print("🎯 Focus indicator node: ", focus_indicator)
	print("🎯 Focus indicator parent: ", focus_indicator.get_parent())
	print("🎯 Focus indicator visible: ", focus_indicator.visible)
	
	# Test: make it visible immediately
	focus_indicator.show()
	print("🎯 Focus indicator forced to show for testing")

func show_focus_indicator():
	"""Show the focus indicator"""
	if not focus_indicator:
		create_focus_indicator()
	
	focus_indicator.show()
	is_focused = true
	print("🎯 Focus indicator shown for: ", enemy_name)

func hide_focus_indicator():
	"""Hide the focus indicator"""
	if focus_indicator:
		focus_indicator.hide()
		is_focused = false
		print("🎯 Focus indicator hidden for: ", enemy_name)

func remove_focus_indicator():
	"""Remove the focus indicator completely"""
	if focus_indicator:
		focus_indicator.queue_free()
		focus_indicator = null
		is_focused = false
		print("🎯 Focus indicator removed for: ", enemy_name)
