extends Node

# Base enemy properties
@export var enemy_name: String = "Enemy"
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

# Global systems integration flags
@export var can_be_poisoned: bool = true
@export var can_be_ignited: bool = true
@export var can_be_stunned: bool = true
@export var can_be_slowed: bool = true
@export var can_be_frozen: bool = true
@export var can_be_shocked: bool = true
@export var can_be_bleeding: bool = true
@export var can_be_bone_broken: bool = true

# Loot and rewards
@export var base_gold_reward: int = 5
@export var gold_variance: int = 3  # +/- variance for gold drops
@export var guaranteed_loot: Array = []  # Items that always drop
@export var loot_table: Dictionary = {}  # Chance-based loot drops
@export var loot_chance_multiplier: float = 1.0  # Multiplier for loot drop chances

# Combat state
var player: Node = null
var in_combat: bool = false
var combat_manager: Node = null
var current_target: Node = null
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

# Enemy-specific stat modifiers
@export var strength_modifier: int = 0
@export var intelligence_modifier: int = 0
@export var spell_power_modifier: int = 0
@export var dexterity_modifier: int = 0
@export var cunning_modifier: int = 0
@export var speed_modifier: int = 0

func _ready():
	print(enemy_name, " _ready() starting...")
	
	# Ensure stats are properly initialized
	if not stats:
		print(enemy_name, " DEBUG: Creating new stats instance")
		stats = PlayerStats.new()
	
	print(enemy_name, " DEBUG: stats variable before add_child: ", stats)
	
	add_child(stats)
	print(enemy_name, " DEBUG: stats variable after add_child: ", stats)
	
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
	
	print(enemy_name, " spawned at level ", enemy_level, " with stats:")
	print("  Strength: ", stats.strength, " Intelligence: ", stats.intelligence)
	print("  Spell Power: ", stats.spell_power, " Dexterity: ", stats.dexterity)
	print("  Cunning: ", stats.cunning, " Speed: ", stats.speed)
	
	# Update combat chances and recalculate max stats
	stats._update_combat_chances()
	stats._recalculate_max_stats()
	
	# Start with full health and mana
	stats.health = stats.max_health
	stats.mana = stats.max_mana
	
	# Initialize floating status bars but keep them hidden initially
	update_status_bars()
	hide_status_bars()
	
	# Final debug check
	print(enemy_name, " DEBUG: Final stats check - stats: ", stats, " class: ", stats.get_class() if stats else "null")
	
	# Debug: Check if this enemy somehow got chest properties
	print(enemy_name, " DEBUG: Checking for chest properties...")
	print(enemy_name, " Groups: ", get_groups())
	print(enemy_name, " Has give_item_to_player method: ", has_method("give_item_to_player"))
	print(enemy_name, " Parent: ", str(get_parent().name) if get_parent() else "None")
	print(enemy_name, " Parent groups: ", str(get_parent().get_groups()) if get_parent() else "None")
	
	print(enemy_name, " _ready() called")
	
	# Try to find CombatManager immediately
	print(enemy_name, ": Trying immediate CombatManager lookup...")
	_find_combat_manager()
	
	# Set up a timer as a fallback
	print(enemy_name, ": Setting up timer fallback...")
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5  # Wait 0.5 seconds
	timer.one_shot = true
	timer.timeout.connect(_find_combat_manager)
	timer.start()
	print(enemy_name, ": Timer fallback set up (0.5s)")
	
	print(enemy_name, " spawned with ", stats.health, "/", stats.max_health, " HP")
	
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
	
	print(enemy_name, " _ready() completed successfully!")

func _find_combat_manager():
	print(enemy_name, ": _find_combat_manager() called")
	# Look for CombatManager by name in the current scene
	var scene = get_tree().current_scene
	if scene:
		print(enemy_name, ": Found scene: ", scene.name)
		combat_manager = scene.get_node_or_null("CombatManager")
		print(enemy_name, ": Looked for 'CombatManager' node in scene")
	else:
		print(enemy_name, ": No current scene found!")
	
	if not combat_manager:
		print("WARNING: ", enemy_name, " could not find CombatManager!")
		# Try alternative search methods
		print(enemy_name, ": Trying to find by group...")
		var managers = get_tree().get_nodes_in_group("CombatManager")
		print(enemy_name, ": Found ", managers.size(), " nodes in CombatManager group")
		for manager in managers:
			print(enemy_name, ": Group member: ", manager.name, " (", manager.get_class(), ")")
		if managers.size() > 0:
			combat_manager = managers[0]
			print(enemy_name, ": Using first group member as combat manager: ", combat_manager.name)
	else:
		print(enemy_name, " found CombatManager: ", combat_manager.name)

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
		
	# Basic gravity
	if not parent_body.is_on_floor():
		parent_body.velocity.y -= 20.0 * delta
	
	# Safety check: prevent extreme velocity values
	if parent_body.velocity.length() > 50.0:
		parent_body.velocity = Vector3.ZERO
	
	# Find player if not already found
	if player == null:
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return
	
	# Safety check: ensure player is still valid
	if not is_instance_valid(player):
		player = null
		return
		
	# Check if player is in detection range
	var distance_to_player = parent_body.global_position.distance_to(player.global_position)
	
	# Safety check: prevent extreme distance values
	if distance_to_player > 1000.0:
		distance_to_player = 999.0

	# If in combat and player moved too far, end combat
	if in_combat and distance_to_player > detection_range * 1.5:
		end_combat()
		return

	if distance_to_player <= detection_range and not in_combat:
		# Check if we should start combat
		if distance_to_player <= combat_range:
			start_combat()
		else:
			# Move towards player
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
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			print("ERROR: ", enemy_name, " cannot start combat - no player found!")
			return
	
	print(enemy_name, " enters combat!")
	
	# Face the player when combat starts
	face_target(player)
	
	# Show status bars when combat starts
	show_status_bars()
	
	print(enemy_name, " calling combat_manager.start_combat with:")
	print("  - enemy (self): ", self.name, " (", self.get_class(), ")")
	print("  - player: ", player.name, " (", player.get_class(), ")")
	print("  - combat_manager: ", combat_manager.name, " (", combat_manager.get_class(), ")")
	
	# Safety check: ensure combat_manager is not self
	if combat_manager == self:
		print("ERROR: CombatManager cannot be the same as enemy!")
		return
	
	in_combat = true
	
	print("About to call combat_manager.start_combat...")
	print("combat_manager type: ", typeof(combat_manager))
	print("combat_manager class: ", combat_manager.get_class())
	combat_manager.start_combat(self, player)
	print("combat_manager.start_combat call completed")

func end_combat():
	print(enemy_name, " end_combat() called!")
	in_combat = false
	print(enemy_name, " exits combat!")
	
	# Hide status bars when combat ends
	hide_status_bars()
	
	# Notify combat manager if we have one
	if combat_manager and combat_manager.has_method("end_combat"):
		print(enemy_name, " notifying combat manager to end combat")
		combat_manager.end_combat()

func take_damage(amount: int):
	stats.take_damage(amount)
	print(enemy_name, " took ", amount, " damage! Health: ", stats.health, "/", stats.max_health)
	
	# Update floating status bars
	update_status_bars()
	
	# Spirit gain from taking damage removed - only actions give spirit now
	
	# Update combat UI with new status
	if combat_manager and combat_manager.has_method("_update_combat_ui_status"):
		combat_manager._update_combat_ui_status()
	
	if stats.health <= 0:
		print("💀 ", enemy_name, " DEFEATED! Calling die() function...")
		# Use the new death system
		die()
		return

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
		combat_manager.handle_player_damage(damage, "basic attack")
	else:
		# Fallback: direct damage if no combat manager
		if current_target.has_method("take_damage"):
			current_target.take_damage(damage)
	
	# Gain spirit from attacking (like players do)
	gain_spirit(1)
	
	# End turn - use ATB system
	if combat_manager:
		print(enemy_name, " ending turn via combat manager")
		# Reset movement attempts for next turn
		movement_attempts = 0
		# In ATB system, we need to call the enemy turn end function
		if combat_manager.has_method("end_enemy_turn"):
			combat_manager.end_enemy_turn()
		else:
			# Fallback to old method if ATB method doesn't exist
			combat_manager.end_current_turn()
	else:
		print(enemy_name, " WARNING: No combat manager to end turn!")

func move_to_target(target: Node):
	print(enemy_name, " DEBUG: BASE ENEMY move_to_target() called!")
	
	if not target:
		print(enemy_name, " ERROR: No target for movement!")
		return
		
	# Get the parent CharacterBody3D for positioning
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
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
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			print("⚠️ ", enemy_name, " still cannot find player - skipping rewards!")
			return
	
	# Additional safety: ensure player is still valid
	if not is_instance_valid(player):
		print("⚠️ ", enemy_name, " player reference is no longer valid!")
		# Try to find player from scene again
		player = get_tree().get_first_node_in_group("Player")
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
	if not player or not player.has_method("receive_item"):
		print("⚠️ No player to receive loot!")
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
	if not player or not player.has_method("receive_gold"):
		print("⚠️ No player to receive gold!")
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
			combat_manager.remove_enemy_from_combat(self)
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
		take_damage(ignite_damage)
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
	
	# Get the parent CharacterBody3D for positioning
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
	
	# Calculate direction to target
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
	"""Show the status bars above the enemy's head"""
	# Delegate to parent if it has the function
	if get_parent() and get_parent().has_method("show_status_bars"):
		get_parent().show_status_bars()
		return

func hide_status_bars():
	"""Hide the status bars"""
	# Delegate to parent if it has the function
	if get_parent() and get_parent().has_method("hide_status_bars"):
		get_parent().hide_status_bars()
		return

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
		target_player = combat_manager.current_player
	
	# Third try: find player in scene
	else:
		target_player = get_tree().get_first_node_in_group("Player")
		if target_player and is_instance_valid(target_player):
			pass
	
	# Final check: ensure we have a valid player
	if not target_player:
		print(enemy_name, " cannot award XP - no valid player found anywhere")
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
		combat_manager._log_combat_event("🎉 " + enemy_name + " awarded " + str(exp_reward) + " XP!")

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
