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

# Combat state
var player: Node = null
var in_combat: bool = false
var combat_manager: Node = null
var current_target: Node = null
var is_moving_to_target: bool = false
var target_position: Vector3 = Vector3.ZERO
var is_frozen: bool = false  # Flag to prevent movement during combat

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
	if in_combat or not combat_manager or not player:
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
	print(enemy_name, " DEBUG: Calling update_status_bars() after taking damage")
	update_status_bars()
	
	# Gain spirit from taking damage (like players)
	gain_spirit(2)
	
	# Update combat UI with new status
	if combat_manager and combat_manager.has_method("_update_combat_ui_status"):
		combat_manager._update_combat_ui_status()
	
	if stats.health <= 0:
		print(enemy_name, " defeated!")
		if combat_manager:
			combat_manager.end_combat()
		queue_free()

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
	
	if not in_combat or not current_target:
		print(enemy_name, " ERROR: Cannot perform melee attack - not in combat or no target")
		return
		
	print(enemy_name, " performs melee attack!")
	
	# Check if we need to move to target first
	var parent_body = get_parent()
	if not parent_body or not parent_body is CharacterBody3D:
		return
		
	var distance_to_target = parent_body.global_position.distance_to(current_target.global_position)
	if distance_to_target > 1.5:  # Need to get closer
		print(enemy_name, " DEBUG: Too far, calling move_to_target")
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
	gain_spirit(2)
	
	# End turn - use ATB system
	if combat_manager:
		print(enemy_name, " ending turn via combat manager")
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
