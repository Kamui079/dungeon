extends Node

class_name CombatManager

signal combat_started
signal combat_ended
signal turn_changed(current_actor: Node, turn_type: String)
signal atb_bar_updated(player_progress: float, enemy_progress: float)

var in_combat: bool = false
var current_enemy: Node = null
var current_player: Node = null
var combat_ui: Node = null
var current_actor: Node = null  # Who's currently acting
var turn_type: String = "player"  # "player" or "enemy"
var player_defending: bool = false  # Track if player is defending

# ATB System variables
var player_atb_timer: Timer
var enemy_atb_timer: Timer
var player_atb_progress: float = 0.0
var enemy_atb_progress: float = 0.0
var player_turn_ready: bool = false
var enemy_turn_ready: bool = false
var action_in_progress: bool = false
var player_action_queued: bool = false
var queued_action: String = ""
var queued_action_data: Dictionary = {}
var player_atb_start_time: float = 0.0  # Individual start time for player
var enemy_atb_start_time: float = 0.0   # Individual start time for enemy
var player_atb_duration: float = 10.0
var enemy_atb_duration: float = 10.0
var atb_progress_timer: Timer = null  # Store reference to the progress timer

# Combat state
var combat_round: int = 1
var waiting_for_action: bool = false

# Safety system to prevent infinite loops
var safety_timer: Timer = null
var last_turn_time: float = 0.0
var max_turn_duration: float = 10.0  # Maximum 10 seconds per turn

# Add damage calculator for armor calculations
var damage_calculator: DamageCalculator

func _ready():
	# Add this node to the CombatManager group
	add_to_group("CombatManager")
	print("CombatManager ready - in_combat=false")
	damage_calculator = DamageCalculator.new()
	
	# Set up safety timer to prevent infinite loops
	safety_timer = Timer.new()
	add_child(safety_timer)
	safety_timer.wait_time = 1.0  # Check every second
	safety_timer.timeout.connect(_on_safety_timer_timeout)
	safety_timer.start()
	# CombatManager safety timer initialized

# Safety check function
func is_valid_3d_node(node: Node) -> bool:
	if not node:
		return false
	if node == self:
		return false
	if not node.get("global_position"):
		return false
	return true

func start_combat(enemy: Node, player: Node):
	"""Start a new combat encounter"""
	print("=== STARTING COMBAT ===")
	
	if in_combat or not enemy or not player:
		print("Combat already in progress or invalid participants!")
		return
	
	# Safety check: ensure we're not storing the combat manager itself
	if enemy == self:
		return
	if player == self:
		return
	
	# Safety check: ensure enemy is actually an Enemy class
	if not enemy.has_method("get_stats") or not enemy.has_method("take_damage"):
		print("ERROR: Enemy does not have required methods!")
		return
	
	in_combat = true
	current_enemy = enemy
	current_player = player
	combat_round = 1
	
	# Find combat UI for logging
	combat_ui = get_tree().get_first_node_in_group("CombatUI")
	print("Combat UI found: ", combat_ui)
	if combat_ui:
		print("Combat UI has add_combat_log_entry method: ", combat_ui.has_method("add_combat_log_entry"))
	else:
		print("WARNING: No CombatUI found in scene!")
	
	# Log combat start
	_log_combat_event("⚔️ Combat started! " + enemy.enemy_name + " vs " + player.name)
	
	# Reset player spirit at start of combat
	if current_player and current_player.has_method("get_stats") and current_player.get_stats():
		current_player.get_stats().reset_spirit()
	
	# Set combat targets
	if current_enemy and current_enemy.has_method("set_combat_target"):
		current_enemy.set_combat_target(current_player)
	
	# Call enemy's custom combat start behavior
	if current_enemy and current_enemy.has_method("on_combat_start"):
		current_enemy.on_combat_start()
	
	# Freeze both entities
	if current_player and current_player.has_method("set_physics_process_enabled"):
		current_player.set_physics_process_enabled(false)
	else:
		# Try alternative freezing methods
		if current_player and current_player.has_method("set_process_mode"):
			current_player.set_process_mode(Node.PROCESS_MODE_DISABLED)
		elif current_player and current_player.has_method("set_process"):
			current_player.set_process(false)
	
	if current_enemy and current_enemy.has_method("set_physics_process_enabled"):
		current_enemy.set_physics_process_enabled(false)
	else:
		# Try alternative freezing methods
		if current_enemy and current_enemy.has_method("set_process_mode"):
			current_enemy.set_process_mode(Node.PROCESS_MODE_DISABLED)
		elif current_enemy and current_player.has_method("set_process"):
			current_enemy.set_process(false)
	
	# Emit signal for UI to respond
	combat_started.emit()
	
	# Update UI with initial status
	_update_combat_ui_status()
	
	# Initialize ATB system
	_initialize_atb_system()
	
	# Start first turn based on speed
	_start_first_turn()

func _initialize_atb_system():
	"""Initialize the Active Time Battle system"""
	print("=== INITIALIZING ATB SYSTEM ===")
	
	# Reset ATB progress and state
	player_atb_progress = 0.0
	enemy_atb_progress = 0.0
	player_turn_ready = false
	enemy_turn_ready = false
	action_in_progress = false
	player_atb_start_time = 0.0
	enemy_atb_start_time = 0.0
	player_atb_duration = 10.0
	enemy_atb_duration = 10.0
	
	print("ATB System initialized!")

func _start_first_turn():
	"""Start the first turn based on speed stats"""
	if not current_player or not current_enemy:
		return
	
	var player_stats = current_player.get_stats()
	var enemy_stats = current_enemy.get_stats()
	
	if not player_stats or not enemy_stats:
		return
	
	var player_speed = player_stats.speed
	var enemy_speed = enemy_stats.speed
	
	print("=== FIRST TURN DETERMINATION ===")
	print("Player speed: ", player_speed)
	print("Enemy speed: ", enemy_speed)
	
	# Start ATB timers immediately for both player and enemy
	_start_atb_timers()
	
	# Determine who goes first based on speed
	if player_speed >= enemy_speed:
		print("Player goes first (higher or equal speed)")
		# Don't start player turn immediately - let ATB system handle it
		# Just set the initial turn type
		turn_type = "player"
		current_actor = current_player
	else:
		print("Enemy goes first (higher speed)")
		# Don't start enemy turn immediately - let ATB system handle it
		# Just set the initial turn type
		turn_type = "enemy"
		current_actor = current_enemy
	
	print("Initial turn type set to: ", turn_type)
	print("ATB system will automatically start the first turn when ready")

func _start_player_turn():
	"""Start the player's turn"""
	print("🚀 STARTING PLAYER TURN")
	turn_type = "player"
	current_actor = current_player
	waiting_for_action = true
	player_turn_ready = true
	
	print("=== PLAYER TURN STARTED ===")
	_log_turn_start(current_player, "player")
	
	# Emit turn changed signal
	turn_changed.emit(current_player, turn_type)

func _start_enemy_turn():
	"""Start the enemy's turn"""
	print("🚀 STARTING ENEMY TURN")
	turn_type = "enemy"
	current_actor = current_enemy
	waiting_for_action = false
	enemy_turn_ready = true
	
	print("=== ENEMY TURN STARTED ===")
	_log_turn_start(current_enemy, "enemy")
	
	# Emit turn changed signal
	turn_changed.emit(current_enemy, turn_type)
	
	# Enemy takes action immediately
	_process_enemy_turn()

func _start_atb_timers():
	"""Start the ATB timers for both player and enemy"""
	print("=== STARTING ATB TIMERS ===")
	
	if not current_player or not current_enemy:
		print("ERROR: No current player or enemy!")
		return
	
	var player_stats = current_player.get_stats()
	var enemy_stats = current_enemy.get_stats()
	
	if not player_stats or not enemy_stats:
		print("ERROR: No player or enemy stats!")
		return
	
	# Calculate ATB fill time based on speed (faster = shorter time)
	var base_atb_time = 5.0  # Base 5 seconds to fill (doubled speed from 10s)
	var player_speed = max(1, player_stats.speed)
	var enemy_speed = max(1, enemy_stats.speed)
	
	# Each point of speed increases fill speed by 1% (doubled from 0.5%)
	# So 10 speed = 10% faster = 90% of base time
	var player_speed_multiplier = 1.0 - (player_speed * 0.01)
	var enemy_speed_multiplier = 1.0 - (enemy_speed * 0.01)
	
	# Ensure minimum multiplier (can't go below 50% of base time)
	player_speed_multiplier = max(0.5, player_speed_multiplier)
	enemy_speed_multiplier = max(0.5, enemy_speed_multiplier)
	
	var player_atb_time = base_atb_time * player_speed_multiplier
	var enemy_atb_time = base_atb_time * enemy_speed_multiplier
	
	print("ATB Times - Base: ", base_atb_time, "s")
	print("Player speed: ", player_speed, " (", (1.0 - player_speed_multiplier) * 100, "% faster)")
	print("Enemy speed: ", enemy_speed, " (", (1.0 - enemy_speed_multiplier) * 100, "% faster)")
	print("Player ATB time: ", player_atb_time, "s")
	print("Enemy ATB time: ", enemy_atb_time, "s")
	
	# Store ATB start times and duration for each entity
	player_atb_start_time = Time.get_ticks_msec() / 1000.0
	enemy_atb_start_time = Time.get_ticks_msec() / 1000.0
	player_atb_duration = player_atb_time
	enemy_atb_duration = enemy_atb_time
	
	print("Player ATB start time: ", player_atb_start_time, "s")
	print("Enemy ATB start time: ", enemy_atb_start_time, "s")
	print("Player ATB duration: ", player_atb_duration, "s")
	print("Enemy ATB duration: ", enemy_atb_duration, "s")
	
	# Reset progress
	player_atb_progress = 0.0
	enemy_atb_progress = 0.0
	
	# Start ATB progress updates
	_start_atb_progress_updates()

func _start_atb_progress_updates():
	"""Start updating ATB progress bars"""
	print("=== STARTING ATB PROGRESS UPDATES ===")
	
	# Clean up any existing timer first
	if atb_progress_timer and is_instance_valid(atb_progress_timer):
		atb_progress_timer.queue_free()
		atb_progress_timer = null
	
	# Create a new timer for progress updates
	atb_progress_timer = Timer.new()
	atb_progress_timer.name = "atb_progress_timer"
	add_child(atb_progress_timer)
	atb_progress_timer.wait_time = 0.033  # ~30 FPS for smooth progress updates
	atb_progress_timer.timeout.connect(_update_atb_progress)
	print("Created new ATB progress timer")
	
	# Start the timer
	atb_progress_timer.start()
	print("ATB progress timer started with wait time: ", atb_progress_timer.wait_time, "s")

func _update_atb_progress():
	"""Update ATB progress bars"""
	if not in_combat:
		return
	
	# Calculate progress based on elapsed time since each entity's ATB started
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Calculate player progress - only if not already ready
	if not player_turn_ready:
		var player_elapsed_time = current_time - player_atb_start_time
		player_atb_progress = min(1.0, player_elapsed_time / player_atb_duration)
		
		# Check if player ATB is ready
		if player_atb_progress >= 1.0:
			player_atb_progress = 1.0
			print("🎯 PLAYER ATB READY - Starting player turn!")
			_on_player_atb_ready()
	else:
		# Keep player ATB at 100% while turn is ready
		player_atb_progress = 1.0
	
	# Calculate enemy progress - only if not already ready
	if not enemy_turn_ready:
		var enemy_elapsed_time = current_time - enemy_atb_start_time
		enemy_atb_progress = min(1.0, enemy_elapsed_time / enemy_atb_duration)
		
		# Check if enemy ATB is ready
		if enemy_atb_progress >= 1.0:
			enemy_atb_progress = 1.0
			print("🎯 ENEMY ATB READY - Starting enemy turn!")
			_on_enemy_atb_ready()
	else:
		# Keep enemy ATB at 100% while turn is ready
		enemy_atb_progress = 1.0
	
	# Debug output (reduced frequency to avoid spam)
	if int(Time.get_ticks_msec() / 1000.0) % 2 == 0:  # Only log every 2 seconds
		print("ATB Progress - Player: ", int(player_atb_progress * 100), "%, Enemy: ", int(enemy_atb_progress * 100), "%")
		print("  Player ready: ", player_turn_ready, " Enemy ready: ", enemy_turn_ready, " Action in progress: ", action_in_progress)
	
	# Emit signal for UI updates
	atb_bar_updated.emit(player_atb_progress, enemy_atb_progress)

func _on_player_atb_ready():
	"""Called when player's ATB bar is full"""
	print("🎯 PLAYER ATB READY - Starting player turn!")
	player_turn_ready = true
	
	# Only start player turn if no action is in progress
	if not action_in_progress:
		print("✅ Starting player turn - no action in progress")
		_start_player_turn()
	else:
		print("⏸️ Player ATB ready but action in progress - turn will start when action finishes")

func _on_enemy_atb_ready():
	"""Called when enemy's ATB bar is full"""
	print("🎯 ENEMY ATB READY - Starting enemy turn!")
	enemy_turn_ready = true
	
	# Only start enemy turn if no action is in progress
	if not action_in_progress:
		print("✅ Starting enemy turn - no action in progress")
		_start_enemy_turn()
	else:
		print("⏸️ Enemy ATB ready but action in progress - turn will start when action finishes")

func _process_enemy_turn():
	"""Process the enemy's turn"""
	if not enemy_turn_ready or action_in_progress:
		return
	
	# Mark action as in progress
	action_in_progress = true
	enemy_turn_ready = false
	
	print("Enemy taking turn...")
	
	# Use enemy's AI logic if available, otherwise fall back to basic attack
	if current_actor.has_method("take_turn"):
		current_actor.take_turn()
	elif current_actor.has_method("melee_attack"):
		current_actor.melee_attack()
	else:
		# If enemy has no valid actions, end turn immediately
		_end_enemy_turn()
		return
	
	# Don't automatically end the enemy's turn here
	# The enemy's action (like take_turn or melee_attack) should handle
	# calling _end_enemy_turn() when the action is actually complete
	# This prevents the enemy from taking multiple turns rapidly

func end_enemy_turn():
	"""End the enemy's turn"""
	print("Enemy turn ended")
	action_in_progress = false
	enemy_turn_ready = false
	
	# Reset enemy ATB progress and start new timer
	enemy_atb_progress = 0.0
	
	# Start a new ATB cycle for the enemy only
	enemy_atb_start_time = Time.get_ticks_msec() / 1000.0
	print("Enemy turn ended - starting new ATB cycle at: ", enemy_atb_start_time, "s")

# Private method for internal use
func _end_enemy_turn():
	"""Private method to end enemy turn - use end_enemy_turn() instead"""
	end_enemy_turn()

func _end_player_turn():
	"""End the player's turn"""
	print("Player turn ended")
	action_in_progress = false
	player_turn_ready = false
	
	# Reset player ATB progress and start new timer
	player_atb_progress = 0.0
	
	# Start a new ATB cycle for the player only
	player_atb_start_time = Time.get_ticks_msec() / 1000.0
	print("Player turn ended - starting new ATB cycle at: ", player_atb_start_time, "s")

func end_combat():
	if not in_combat:
		return
	
	# Log combat end
	if current_player and current_enemy:
		var player_stats = current_player.get_stats() if current_player.has_method("get_stats") else null
		var enemy_stats = current_enemy.get_stats() if current_enemy.has_method("get_stats") else null
		
		if player_stats and enemy_stats:
			if player_stats.health <= 0:
				_log_combat_end(current_enemy, current_player)  # Enemy wins
			elif enemy_stats.health <= 0:
				_log_combat_end(current_player, current_enemy)  # Player wins
			else:
				_log_combat_event("🏁 Combat ended unexpectedly!")
		else:
			_log_combat_event("🏁 Combat ended unexpectedly!")
	
	# Combat ended
	
	# Call enemy's custom combat end behavior
	if current_enemy and current_enemy.has_method("on_combat_end"):
		current_enemy.on_combat_end()
	
	# Reset all combat state
	in_combat = false
	turn_type = "player"
	current_actor = null
	waiting_for_action = false
	player_turn_ready = false
	enemy_turn_ready = false
	action_in_progress = false
	
	# Stop ATB timers
	if player_atb_timer:
		player_atb_timer.stop()
	if enemy_atb_timer:
		enemy_atb_timer.stop()
	
	# Stop and clean up ATB progress timer
	if atb_progress_timer and is_instance_valid(atb_progress_timer):
		atb_progress_timer.stop()
		atb_progress_timer.queue_free()
		atb_progress_timer = null
	
	# Unfreeze both entities
	if current_player and current_player.has_method("set_physics_process_enabled"):
		current_player.set_physics_process_enabled(true)
	else:
		# Try alternative unfreezing methods
		if current_player and current_player.has_method("set_process_mode"):
			current_player.set_process_mode(Node.PROCESS_MODE_INHERIT)
		elif current_player and current_player.has_method("set_process"):
			current_player.set_process(true)
			
	if current_enemy and current_enemy.has_method("set_physics_process_enabled"):
		current_enemy.set_physics_process_enabled(true)
	else:
		# Try alternative unfreezing methods
		if current_enemy and current_enemy.has_method("set_process_mode"):
			current_enemy.set_process_mode(Node.PROCESS_MODE_INHERIT)
		elif current_enemy and current_player.has_method("set_process"):
			current_enemy.set_process(true)
	
	# Clear references
	current_enemy = null
	current_player = null
	
	# Emit signal for UI to respond
	combat_ended.emit()

# Player action methods with action queuing
func player_basic_attack():
	"""Player performs a basic attack"""
	if not in_combat or not current_player or not current_enemy:
		return
	
	# Check if player's turn is ready
	if not player_turn_ready:
		print("Player turn not ready yet!")
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing basic attack...")
		_queue_player_action("basic_attack", {})
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER BASIC ATTACK ===")
	_log_player_action("basic_attack")
	
	# Get player stats
	var player_stats = current_player.get_stats()
	if not player_stats:
		_end_player_turn()
		return
	
	# Calculate damage using PlayerStats methods
	var base_damage = 10  # Base damage
	var strength_multiplier = player_stats.get_melee_damage_multiplier()
	var final_damage = int(base_damage * strength_multiplier)
	
	print("Player attack - Base: ", base_damage, " Strength multiplier: ", strength_multiplier, " Final: ", final_damage)
	
	# Apply damage to enemy
	if current_enemy and current_enemy.has_method("take_damage"):
		current_enemy.take_damage(final_damage)
		_log_damage_dealt(current_player, current_enemy, final_damage)
	
	# End player turn
	_end_player_turn()

func player_special_attack():
	print("=== player_special_attack called ===")
	if not in_combat or not current_enemy or not current_player:
		print("Cannot perform special attack: in_combat=", in_combat, " current_enemy=", current_enemy, " current_player=", current_player)
		return
	
	# Check if player's turn is ready (ATB system)
	if not player_turn_ready:
		print("Player turn not ready yet!")
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing special attack...")
		_queue_player_action("special_attack", {})
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER SPECIAL ATTACK ===")
	_log_player_action("special_attack")
	
	# Check if player has enough spirit
	if not current_player.can_use_special_attack():
		print("Not enough spirit! Need ", current_player.get_special_attack_cost(), " SP, have ", current_player.get_spirit(), " SP")
		_end_player_turn()
		return
	
	# For ATB system, skip movement checks and perform attack directly
	# Perform haymaker special attack
	var base_damage = current_player.get_special_attack_damage()
	var damage_type = current_player.get_special_attack_damage_type()
	var final_damage = _process_haymaker_attack(base_damage, damage_type)
	
	# Spend spirit cost
	current_player.get_stats().spend_spirit(current_player.get_special_attack_cost())
	
	print("Player performs Haymaker! Deals ", final_damage, " damage!")
	
	# Apply damage and get armor reduction information
	var damage_result = _apply_damage_to_enemy(final_damage)
	var actual_damage = damage_result.final_damage
	var armor_reduction = damage_result.armor_reduction
	
	# Log the special attack with armor reduction information
	_log_attack(current_player, current_enemy, actual_damage, "special attack", armor_reduction)
	
	# Apply self-damage (5% of damage dealt)
	var self_damage = int(final_damage * 0.05)
	if self_damage > 0:
		print("💥 Haymaker backlash! Player takes ", self_damage, " damage!")
		_apply_damage_to_player(self_damage)
	
	# Check if enemy is defeated
	if current_enemy.get_stats().health <= 0:
		print("Enemy defeated!")
		end_combat()
		return
	
	# End turn after special attack
	_end_player_turn()

func player_cast_spell():
	print("=== player_cast_spell called ===")
	if not in_combat or not current_enemy or not current_player:
		print("Cannot cast spell: in_combat=", in_combat, " current_enemy=", current_enemy, " current_player=", current_player)
		return
	
	# Check if player's turn is ready (ATB system)
	if not player_turn_ready:
		print("Player turn not ready yet!")
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing spell...")
		_queue_player_action("cast_spell", {})
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER CAST SPELL ===")
	_log_player_action("cast_spell")
	
	# Check if player has enough mana
	if not current_player or not current_player.has_method("get_stats") or not current_player.get_stats():
		print("ERROR: Player has no stats!")
		_end_player_turn()
		return
	
	var player_stats = current_player.get_stats()
	if player_stats.mana < 10:  # Basic spell cost
		print("Not enough mana! Need 10 MP, have ", player_stats.mana, " MP")
		_end_player_turn()
		return
	
	# Cast fireball (no movement needed for ranged attacks)
	var base_damage = current_player.get_spell_damage()
	var damage_type = current_player.get_spell_damage_type()
	var final_damage = _process_attack_damage(base_damage, damage_type, "fireball")
	var mana_cost = 10
	
	print("Player casts Fireball! Deals ", final_damage, " damage! Costs ", mana_cost, " MP!")
	player_stats.mana -= mana_cost
	
	# Apply damage and get armor reduction information
	var damage_result = _apply_damage_to_enemy(final_damage)
	var actual_damage = damage_result.final_damage
	var armor_reduction = damage_result.armor_reduction
	
	# Log the spell attack with armor reduction information
	_log_attack(current_player, current_enemy, actual_damage, "spell", armor_reduction)
	
	# Check for fire ignite
	if current_player.has_method("is_fire_attack") and current_player.is_fire_attack("fireball"):
		_check_fire_ignite(final_damage, "fireball")
	
	# Check if enemy is defeated
	if current_enemy.get_stats().health <= 0:
		print("Enemy defeated!")
		end_combat()
		return
	
	# End turn after spell
	_end_player_turn()

func player_defend():
	"""Player defends, reducing damage taken"""
	if not in_combat or not current_player:
		return
	
	# Check if player's turn is ready
	if not player_turn_ready:
		print("Player turn not ready yet!")
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing defend...")
		_queue_player_action("defend", {})
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER DEFEND ===")
	_log_player_action("defend")
	
	# Set defending state
	player_defending = true
	
	# End player turn
	_end_player_turn()

func player_use_item(item_name: String):
	"""Player uses an item"""
	if not in_combat or not current_player:
		return
	
	# Check if player's turn is ready
	if not player_turn_ready:
		print("Player turn not ready yet!")
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing item use...")
		_queue_player_action("use_item", {"item_name": item_name})
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER USE ITEM: ", item_name, " ===")
	_log_player_action("use_item", {"item_name": item_name})
	
	# Use the item
	if current_player.has_method("use_item"):
		current_player.use_item(item_name)
	
	# End player turn
	_end_player_turn()

# Helper methods
func _log_combat_event(message: String):
	"""Log a combat event to the combat UI"""
	print("COMBAT LOG: ", message)
	print("Combat UI reference: ", combat_ui)
	if combat_ui:
		print("Combat UI is valid: ", is_instance_valid(combat_ui))
		print("Combat UI has add_combat_log_entry method: ", combat_ui.has_method("add_combat_log_entry"))
		if combat_ui.has_method("add_combat_log_entry"):
			combat_ui.add_combat_log_entry(message)
			print("Combat log entry added successfully!")
		else:
			print("WARNING: Combat UI missing add_combat_log_entry method!")
	else:
		print("WARNING: No combat UI reference!")

func _log_turn_start(actor: Node, turn_type_name: String):
	"""Log the start of a turn"""
	var actor_name: String = "Unknown"
	if actor:
		# Try to get enemy name first (most enemies have this property)
		if "enemy_name" in actor:
			actor_name = actor.enemy_name
		elif actor.has_method("get_name"):
			actor_name = actor.get_name()
		elif actor.has_method("name"):
			actor_name = actor.name
		else:
			actor_name = str(actor)
	_log_combat_event("🎯 " + actor_name + "'s turn (" + turn_type_name + ")")

func _log_player_action(action: String, data: Dictionary = {}):
	"""Log a player action"""
	var message = "⚔️ Player performs " + action
	if data.has("item_name"):
		message += ": " + data["item_name"]
	_log_combat_event(message)

func _log_damage_dealt(attacker: Node, target: Node, damage: int):
	"""Log damage dealt"""
	var attacker_name: String = "Unknown"
	var target_name: String = "Unknown"
	
	# Get attacker name
	if attacker:
		if attacker.has_method("get_name"):
			attacker_name = attacker.get_name()
		elif attacker.has_method("name"):
			attacker_name = attacker.name
		else:
			attacker_name = str(attacker)
	
	# Get target name - check if it's an enemy first
	if target:
		# Try to get enemy name first (most enemies have this property)
		if "enemy_name" in target:
			target_name = target.enemy_name
		elif target.has_method("get_name"):
			target_name = target.get_name()
		elif target.has_method("name"):
			target_name = target.name
		else:
			target_name = str(target)
	
	_log_combat_event("💥 " + attacker_name + " deals " + str(damage) + " damage to " + target_name)

func _log_combat_round_start(round_num: int):
	"""Log the start of a combat round"""
	_log_combat_event("🔄 Round " + str(round_num) + " begins!")

func _log_combat_end(winner: Node, loser: Node):
	"""Log the end of combat"""
	var winner_name: String = "Unknown"
	var loser_name: String = "Unknown"
	
	# Get winner name
	if winner:
		# Try to get enemy name first (most enemies have this property)
		if "enemy_name" in winner:
			winner_name = winner.enemy_name
		elif winner.has_method("get_name"):
			winner_name = winner.get_name()
		elif winner.has_method("name"):
			winner_name = winner.name
		else:
			winner_name = str(winner)
	
	# Get loser name
	if loser:
		# Try to get enemy name first (most enemies have this property)
		if "enemy_name" in loser:
			loser_name = loser.enemy_name
		elif loser.has_method("get_name"):
			loser_name = loser.get_name()
		elif loser.has_method("name"):
			loser_name = loser.name
		else:
			loser_name = str(loser)
	
	_log_combat_event("🏆 " + winner_name + " defeats " + loser_name + "!")

func _update_combat_ui_status():
	"""Update the combat UI with current status"""
	if combat_ui and combat_ui.has_method("update_status"):
		combat_ui.update_status()

# ATB System helper methods
func get_player_atb_progress() -> float:
	"""Get the current player ATB progress (0.0 to 1.0)"""
	return player_atb_progress

func get_enemy_atb_progress() -> float:
	"""Get the current enemy ATB progress (0.0 to 1.0)"""
	return enemy_atb_progress

func is_player_turn_ready() -> bool:
	"""Check if the player's turn is ready (ATB bar is full)"""
	var turn_ready = player_turn_ready and not action_in_progress
	print("🔍 Player turn ready check: ATB ready=", player_turn_ready, " Action in progress=", action_in_progress, " Result=", turn_ready)
	return turn_ready

func is_enemy_turn_ready() -> bool:
	"""Check if the enemy can take their turn"""
	return enemy_turn_ready and not action_in_progress

func get_current_turn_type() -> String:
	"""Get the current turn type"""
	return turn_type

func get_current_actor() -> Node:
	"""Get the current actor"""
	return current_actor

# Damage calculation methods (simplified for ATB system)
func _process_attack_damage(base_damage: int, _damage_type: String, attack_type: String) -> int:
	"""Process attack damage with type and attack modifiers"""
	var final_damage = base_damage
	
	# Apply attack type modifiers
	match attack_type:
		"basic":
			final_damage = int(final_damage * 1.0)  # Basic attacks are standard
		"special":
			final_damage = int(final_damage * 1.5)  # Special attacks are stronger
		"critical":
			final_damage = int(final_damage * 2.0)  # Critical hits are very strong
	
	return final_damage

func _apply_damage_to_enemy(damage: int) -> Dictionary:
	"""Apply damage to enemy with armor calculations"""
	if not current_enemy or not current_enemy.has_method("take_damage"):
		return {"final_damage": 0, "armor_reduction": 0}
	
	# Get enemy stats for armor calculation
	var enemy_stats = current_enemy.get_stats()
	var armor_reduction = 0
	
	if enemy_stats and enemy_stats.has_method("get_armor"):
		armor_reduction = enemy_stats.get_armor()
	
	# Calculate final damage (armor reduces damage by 1 per point)
	var final_damage = max(1, damage - armor_reduction)
	
	# Apply damage
	current_enemy.take_damage(final_damage)
	
	return {"final_damage": final_damage, "armor_reduction": armor_reduction}

# Movement methods (simplified for ATB system)
func move_player_to_target(target: Node, action_type: String):
	"""Move player to target for melee actions"""
	if not current_player or not target:
		return
	
	# For ATB system, we'll skip movement and just perform the action
	# This can be enhanced later with proper movement
	print("Player moving to target for ", action_type)
	
	# Simulate movement completion
	call_deferred("_on_player_movement_complete", action_type)

func _on_player_movement_complete(action_type: String):
	"""Called when player movement is complete"""
	match action_type:
		"basic":
			# Re-call basic attack now that movement is complete
			player_basic_attack()
		"special":
			# Re-call special attack now that movement is complete
			player_special_attack()

# Action queuing system
func _queue_player_action(action: String, data: Dictionary):
	"""Queue a player action to be executed when current action finishes"""
	player_action_queued = true
	queued_action = action
	queued_action_data = data
	print("Player action queued: ", action)

func _execute_queued_player_action():
	"""Execute the queued player action"""
	if not player_action_queued:
		return
	
	var action = queued_action
	var data = queued_action_data
	
	# Clear the queue
	player_action_queued = false
	queued_action = ""
	queued_action_data = {}
	
	# Execute the action
	match action:
		"basic_attack":
			player_basic_attack()
		"defend":
			player_defend()
		"use_item":
			if data.has("item_name"):
				player_use_item(data["item_name"])
		_:
			print("Unknown queued action: ", action)

# Missing helper functions
func _log_attack(attacker: Node, target: Node, damage: int, attack_type: String = "attack", armor_reduction: int = 0):
	"""Log an attack action"""
	var attacker_name: String = "Unknown"
	var target_name: String = "Unknown"
	
	# Get attacker name
	if attacker:
		if attacker.has_method("get_name"):
			attacker_name = attacker.get_name()
		elif attacker.has_method("name"):
			attacker_name = attacker.name
		else:
			attacker_name = str(attacker)
	
	# Get target name - check if it's an enemy first
	if target:
		# Try to get enemy name first (most enemies have this property)
		if "enemy_name" in target:
			target_name = target.enemy_name
		elif target.has_method("get_name"):
			target_name = target.get_name()
		elif target.has_method("name"):
			target_name = target.name
		else:
			target_name = str(target)
	
	# Format attack type for better readability
	var attack_display = attack_type
	if attack_type == "basic attack":
		attack_display = "⚔️ Basic Attack"
	elif attack_type == "special attack":
		attack_display = "💥 Special Attack"
	elif attack_type == "spell":
		attack_display = "🔮 Spell"
	elif attack_type == "bite":
		attack_display = "🦷 Bite Attack"
	
	# Build the damage message with optional armor reduction
	var damage_message = attacker_name + " uses " + attack_display + " on " + target_name + " for " + str(damage) + " damage"
	if armor_reduction > 0:
		damage_message += " (armor reduced " + str(armor_reduction) + ")"
	damage_message += "!"
	
	_log_combat_event(damage_message)

func _process_haymaker_attack(base_damage: int, _damage_type: String) -> int:
	"""Process haymaker special attack damage"""
	print("=== _process_haymaker_attack called with base_damage: ", base_damage, " ===")
	var final_damage = base_damage
	var critical_multiplier = 1.0 + (randf_range(1.0, 1.4))  # 100-140% extra damage
	
	final_damage = int(base_damage * critical_multiplier)
	
	print("Haymaker damage: Base: ", base_damage, " Critical multiplier: ", critical_multiplier, " Final: ", final_damage)
	
	return final_damage

func _check_fire_ignite(initial_damage: int, _attack_type: String):
	"""Check if fire attack should ignite the target"""
	if not current_enemy or not current_enemy.has_method("apply_ignite"):
		return
	
	# Get ignite chance from player
	var ignite_chance = 35.0  # Base 35%
	if current_player and current_player.has_method("get_fire_ignite_chance"):
		ignite_chance = current_player.get_fire_ignite_chance()
	
	# Roll for ignite
	var roll = randf() * 100.0
	print("Fire ignite check: ", roll, " vs ", ignite_chance, "% chance")
	
	if roll <= ignite_chance:
		print("🔥 TARGET IGNITED! 🔥")
		current_enemy.apply_ignite(initial_damage, 3)
	else:
		print("Fire attack did not ignite target")

func _gain_spirit_from_damage(_amount: int):
	"""Gain spirit when taking damage"""
	if current_player and current_player.has_method("get_stats") and current_player.get_stats():
		current_player.get_stats().gain_spirit(2)

func _gain_spirit_from_defense():
	"""Gain spirit when successfully defending"""
	if current_player and current_player.has_method("get_stats") and current_player.get_stats():
		var spirit_gain = randi_range(3, 4)
		current_player.get_stats().gain_spirit(spirit_gain)

# Missing damage functions
func _apply_damage_to_player(damage: int):
	"""Apply damage to player with proper combat mechanics"""
	if not current_player:
		return
	
	# Apply defense if player is defending
	var final_damage = damage
	if player_defending:
		final_damage = int(damage / 2.0)  # Explicit float division then convert to int
		print("Player defends! Damage reduced from ", damage, " to ", final_damage)
		player_defending = false  # Reset defense after use
		# Gain spirit from successful defense
		_gain_spirit_from_defense()
	else:
		# Apply armor reduction before other mechanics
		var damage_reduction_result = _handle_player_damage_taken(damage, current_enemy)
		final_damage = damage_reduction_result.final_damage
		print("Player takes ", final_damage, " damage!")
		# Gain spirit from taking damage
		_gain_spirit_from_damage(final_damage)
	
	# Check for dodge
	if current_player.get_stats().roll_dodge():
		print("🎯 Player dodged the attack!")
		return
	
	# Check for parry (only against melee attacks)
	if current_player.get_stats().roll_parry():
		print("🛡️ Player parried the attack!")
		# Reflect 25% damage back at attacker
		var reflected_damage = int(damage * 0.25)
		if reflected_damage > 0:
			print("Player reflects ", reflected_damage, " damage back!")
			_apply_damage_to_enemy(reflected_damage)
		return
	
	# Apply damage to player
	if current_player and current_player.has_method("take_damage"):
		current_player.take_damage(final_damage)
	
	# Update UI status after player takes damage
	_update_combat_ui_status()

func _handle_player_damage_taken(base_damage: int, attacker: Node) -> Dictionary:
	"""Apply armor reduction to damage taken by player"""
	if not current_player or not current_player.has_method("get_stats"):
		return {"final_damage": base_damage, "armor_reduction": 0}
	
	var player_stats = current_player.get_stats()
	if not player_stats:
		return {"final_damage": base_damage, "armor_reduction": 0}
	
	# Get player's equipment for armor calculation
	var equipment_ui = get_tree().get_first_node_in_group("EquipmentUI")
	if not equipment_ui:
		return {"final_damage": base_damage, "armor_reduction": 0}
	
	var total_armor = equipment_ui.get_total_armor_value()
	var attacker_level = 1  # Default level if we can't determine
	
	# Try to get attacker level
	if attacker and attacker.has_method("get_stats"):
		var attacker_stats = attacker.get_stats()
		if attacker_stats and attacker_stats.has_method("get_level"):
			attacker_level = attacker_stats.get_level()
	
	# Get player level
	var player_level = 1  # Default level
	if player_stats.has_method("get_level"):
		player_level = player_stats.get_level()
	
	# Calculate final damage with armor reduction
	var final_damage = damage_calculator.calculate_damage_with_armor(
		base_damage, total_armor, attacker_level, player_level
	)
	
	# Calculate armor reduction
	var armor_reduction = base_damage - final_damage
	
	return {"final_damage": final_damage, "armor_reduction": armor_reduction}

# Public method for enemies to call
func handle_player_damage(damage: int, attack_type: String = "attack"):
	"""Handle damage dealt to the player by enemies"""
	if not current_player or not in_combat:
		return
	
	print("Enemy deals ", damage, " damage to player (", attack_type, ")")
	
	# Apply damage to player using the existing damage handling system
	_apply_damage_to_player(damage)

func _handle_enemy_damage_taken(base_damage: int, attacker: Node) -> Dictionary:
	"""Apply armor reduction to damage taken by enemy"""
	print("=== _handle_enemy_damage_taken called with base_damage: ", base_damage, " ===")
	if not current_enemy or not current_enemy.has_method("get_stats"):
		print("ERROR: No current enemy or enemy has no get_stats method!")
		return {"final_damage": base_damage, "armor_reduction": 0}
	
	var enemy_stats = current_enemy.get_stats()
	if not enemy_stats:
		print("ERROR: Enemy stats is null!")
		return {"final_damage": base_damage, "armor_reduction": 0}
	
	# Get enemy's armor value (enemies don't have equipment UI, so use base armor)
	var enemy_armor = 0
	if enemy_stats.has_method("get_armor_value"):
		enemy_armor = enemy_stats.get_armor_value()
		print("Enemy armor value: ", enemy_armor)
	else:
		print("Enemy has no get_armor_value method!")
	
	var attacker_level = 1  # Default level if we can't determine
	
	# Try to get attacker level
	if attacker and attacker.has_method("get_stats"):
		var attacker_stats = attacker.get_stats()
		if attacker_stats and attacker_stats.has_method("get_level"):
			attacker_level = attacker_stats.get_level()
	
	# Get enemy level
	var enemy_level = 1  # Default level
	if enemy_stats.has_method("get_level"):
		enemy_level = enemy_stats.get_level()
	
	print("Attacker level: ", attacker_level, " Enemy level: ", enemy_level)
	
	# Calculate final damage with armor reduction
	var final_damage = damage_calculator.calculate_damage_with_armor(
		base_damage, enemy_armor, attacker_level, enemy_level
	)
	
	# Calculate armor reduction
	var armor_reduction = base_damage - final_damage
	
	print("Base damage: ", base_damage, " Final damage: ", final_damage, " Armor reduction: ", armor_reduction)
	
	return {"final_damage": final_damage, "armor_reduction": armor_reduction}

# Missing turn management functions
func end_current_turn():
	"""End the current turn and move to the next"""
	if not in_combat:
		return
	
	print("Ending turn for ", current_actor.name)
	print("  Current turn index: ", current_actor)
	print("  Turn type: ", turn_type)
	
	# Mark action as in progress
	action_in_progress = false
	
	# In ATB system, we don't automatically start the next turn
	# The ATB system will naturally progress and call the appropriate
	# turn start functions when the bars are ready

# Getter methods for UI
func get_current_turn_info() -> Dictionary:
	"""Get information about the current turn for UI display"""
	return {
		"current_actor": current_actor,
		"turn_type": turn_type,
		"combat_round": combat_round,
		"waiting_for_action": waiting_for_action
	}

func get_atb_status() -> Dictionary:
	"""Get current ATB system status for debugging"""
	return {
		"player_atb_progress": player_atb_progress,
		"enemy_atb_progress": enemy_atb_progress,
		"player_turn_ready": player_turn_ready,
		"enemy_turn_ready": enemy_turn_ready,
		"action_in_progress": action_in_progress,
		"turn_type": turn_type,
		"atb_progress_timer_active": atb_progress_timer != null and atb_progress_timer.timeout.is_connected(_update_atb_progress)
	}

# Safety timer function
func _on_safety_timer_timeout():
	"""Safety check to prevent infinite loops"""
	if not in_combat:
		return
	
	# Simple safety check - just log that we're still running
	# The actual turn duration checking can be implemented later if needed
	print("Safety timer check - combat still active")
	
	# For now, we'll just ensure the safety timer keeps running
	# This prevents the function from causing crashes
