extends Node

class_name CombatManager

signal combat_started
signal combat_ended
signal turn_changed(current_actor: Node, turn_type: String)
signal atb_bar_updated(player_progress: float, enemy_progress: float)
signal action_queued(action: String, data: Dictionary)
signal action_dequeued()
signal enemy_damaged(enemy: Node, damage_type: String, amount: int)

var in_combat: bool = false
var current_enemies: Array[Node] = []  # Array to support multiple enemies
var current_enemy: Node = null  # Keep for backward compatibility
var current_player: Node = null
var focused_enemy_index: int = 0  # Index of currently focused enemy for targeting
var focused_enemy: Node = null  # Currently focused enemy for attacks
var combat_ui: Node = null
var hud: Node = null  # Reference to the HUD for spirit bar control
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

# Visual targeting indicator
var focus_indicators: Dictionary = {}  # Store focus circles for each enemy
var focus_circle_scene: PackedScene = null

func _ready():
	# Add this node to the CombatManager group
	add_to_group("CombatManager")
	damage_calculator = DamageCalculator.new()
	
	# Set up safety timer to prevent infinite loops
	safety_timer = Timer.new()
	add_child(safety_timer)
	safety_timer.wait_time = 1.0  # Check every second
	safety_timer.timeout.connect(_on_safety_timer_timeout)
	safety_timer.start()

# Safety check function
func is_valid_3d_node(node: Node) -> bool:
	if not node:
		return false
	if node == self:
		return false
	if not node is Node3D:
		return false
	return true

func start_combat(enemy: Node, player: Node):
	"""Start a new combat encounter"""
	if in_combat or not enemy or not player:
		return
	
	# Safety check: ensure we're not storing the combat manager itself
	if enemy == self:
		return
	if player == self:
		return
	
	# Safety check: ensure enemy is actually an Enemy class
	if not enemy.has_method("get_stats") or not enemy.has_method("take_damage"):
		return
	
	in_combat = true
	
	# Add enemy to the list and set as current
	if not current_enemies.has(enemy):
		current_enemies.append(enemy)
	current_enemy = enemy  # Maintain backward compatibility
	focused_enemy = enemy  # Set as focused target
	focused_enemy_index = 0  # First enemy is index 0
	
	# Show focus indicator on the first enemy
	if focused_enemy.has_method("show_focus_indicator"):
		focused_enemy.show_focus_indicator()
	
	# Highlight the focused enemy in the HUD
	if hud and hud.has_method("highlight_focused_enemy"):
		hud.highlight_focused_enemy(focused_enemy)
	
	current_player = player
	combat_round = 1
	
	# Find combat UI for logging
	combat_ui = get_tree().get_first_node_in_group("CombatUI")
	if combat_ui:
		combat_ui.add_combat_log_entry("Combat started!")
	
	# Find HUD for spirit bar control
	hud = get_tree().get_first_node_in_group("HUD")
	if not hud and current_player:
		# Try to find HUD as a child of the player
		for child in current_player.get_children():
			if child.has_method("show_spirit_bar"):
				hud = child
				break
	
	if hud and hud.has_method("show_spirit_bar"):
		print("CombatManager: Calling HUD.show_spirit_bar()")
		hud.show_spirit_bar()
		print("CombatManager: HUD.show_spirit_bar() completed")
		
		# Clear any existing enemy panels and create new ones
		if hud.has_method("clear_enemy_panels"):
			hud.clear_enemy_panels()
		if hud.has_method("create_enemy_panel"):
			for enemy_node in current_enemies:
				hud.create_enemy_panel(enemy_node)
	else:
		print("CombatManager: No HUD found or missing show_spirit_bar method!")
	
	# Log combat start
	var enemy_name = enemy.enemy_name if enemy.has_method("enemy_name") else enemy.name
	_log_combat_event("⚔️ Combat started! " + enemy_name + " vs " + player.name)
	
	# Reset player spirit at start of combat
	if current_player and current_player.has_method("get_stats") and current_player.get_stats():
		current_player.get_stats().reset_spirit()
	
	# Set combat targets
	if current_enemy and current_enemy.has_method("set_combat_target"):
		current_enemy.set_combat_target(current_player)
	
	# Call enemy's custom combat start behavior
	if current_enemy and current_enemy.has_method("on_combat_start"):
		current_enemy.on_combat_start()
	
	# Orient player and camera toward the enemy
	print("🎯 Combat starting - orienting camera...")
	_orient_player_toward_enemy()
	
	# Ensure camera is properly oriented even if player was looking away
	print("🎯 Combat starting - ensuring camera faces enemy...")
	_ensure_camera_faces_enemy()
	
	# Start periodic camera orientation checks during combat
	_start_camera_orientation_checks()
	
	# Check if player is grounded before starting combat
	if current_player and current_player is Node3D:
		if current_player.has_method("is_on_floor") and not current_player.is_on_floor():
			print("🎯 Player is in the air - delaying combat start until landing...")
			# Wait for player to land naturally before freezing
			var landing_check_timer = Timer.new()
			landing_check_timer.name = "combat_landing_check_timer"
			landing_check_timer.wait_time = 0.1  # Check every 0.1 seconds
			landing_check_timer.timeout.connect(func():
				_check_player_landing_and_freeze()
			)
			add_child(landing_check_timer)
			landing_check_timer.start()
			return  # Exit early, don't freeze yet
		else:
			print("🎯 Player is on ground - proceeding with combat freeze")
	
	# If we get here, player is grounded, so position at combat distance then freeze
	_position_enemy_at_combat_distance()

func _check_player_landing_and_freeze():
	"""Check if player has landed and then freeze entities"""
	if not current_player or not current_player is Node3D:
		# Player is gone, clean up and exit
		_cleanup_landing_timer()
		return
	
	# Check if player is now on the ground
	if current_player.has_method("is_on_floor") and current_player.is_on_floor():
		print("🎯 Player has landed - now positioning at proper combat distance")
		_cleanup_landing_timer()
		_position_enemy_at_combat_distance()
	else:
		# Player still in air, keep checking
		print("🎯 Player still in air, continuing to wait...")

func _cleanup_landing_timer():
	"""Clean up the landing check timer"""
	var landing_timer = get_node_or_null("combat_landing_check_timer")
	if landing_timer:
		landing_timer.stop()
		landing_timer.queue_free()
		print("🎯 Cleaned up landing check timer")

func _cleanup_positioning_timer():
	"""Clean up the positioning timer"""
	var positioning_timer = get_node_or_null("combat_positioning_timer")
	if positioning_timer:
		positioning_timer.stop()
		positioning_timer.queue_free()
		print("🎯 Cleaned up positioning timer")

func _position_enemy_at_combat_distance():
	"""Position the enemy at the proper combat distance from the player"""
	if not current_player or not current_enemy or not current_player is Node3D or not current_enemy is Node3D:
		# Fallback to immediate freeze if positioning fails
		_freeze_entities()
		return
	
	# Calculate the direction from player to enemy
	var player_pos = current_player.global_position
	var enemy_pos = current_enemy.global_position
	var direction_to_enemy = (enemy_pos - player_pos).normalized()
	
	# Define the ideal combat distance (adjust this value as needed)
	var ideal_combat_distance = 3.0  # 3 units away from player
	
	# Calculate the ideal position for the enemy
	var ideal_enemy_pos = player_pos + (direction_to_enemy * ideal_combat_distance)
	
	# Keep the enemy's current Y position (ground level)
	ideal_enemy_pos.y = enemy_pos.y
	
	print("🎯 Positioning enemy at combat distance - Current: ", player_pos.distance_to(enemy_pos), " Ideal: ", ideal_combat_distance)
	
	# Check if enemy needs to be moved
	var current_distance = player_pos.distance_to(enemy_pos)
	if abs(current_distance - ideal_combat_distance) > 0.5:  # If more than 0.5 units off
		print("🎯 Moving enemy to proper combat distance...")
		
		# Create a timer to track positioning progress
		var positioning_timer = Timer.new()
		positioning_timer.name = "combat_positioning_timer"
		positioning_timer.wait_time = 0.4  # Slightly longer than the tween
		positioning_timer.one_shot = true
		positioning_timer.timeout.connect(func():
			# If timer expires, force freeze (safety measure)
			print("⚠️ Positioning timer expired - forcing freeze")
			_cleanup_positioning_timer()
			_freeze_entities()
		)
		add_child(positioning_timer)
		positioning_timer.start()
		
		# Move enemy to ideal position
		var move_tween = create_tween()
		move_tween.tween_property(current_enemy, "global_position", ideal_enemy_pos, 0.3)
		move_tween.tween_callback(func():
			print("✅ Enemy positioned at combat distance - now freezing")
			_cleanup_positioning_timer()
			_freeze_entities()
		)
	else:
		print("🎯 Enemy already at proper combat distance - freezing immediately")
		_freeze_entities()

func _freeze_entities():
	"""Freeze both player and enemy entities"""
	# Clean up any landing check timer that might still be running
	_cleanup_landing_timer()
	
	# Clean up the freeze timer since we're about to freeze
	var freeze_timer = get_node_or_null("combat_freeze_timer")
	if freeze_timer:
		freeze_timer.queue_free()
	
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
	
	# Start ATB timers immediately for both player and enemy
	_start_atb_timers()
	
	# Determine who goes first based on speed
	if player_speed >= enemy_speed:
		# Don't start player turn immediately - let ATB system handle it
		# Just set the initial turn type
		turn_type = "player"
		current_actor = current_player
	else:
		# Don't start enemy turn immediately - let ATB system handle it
		# Just set the initial turn type
		turn_type = "enemy"
		current_actor = current_enemy

func _start_player_turn():
	"""Start the player's turn"""
	turn_type = "player"
	current_actor = current_player
	waiting_for_action = true
	player_turn_ready = true
	
	# Passive spirit is now given in _on_player_atb_ready() to ensure it happens every turn
	
	# Check if there's a queued action to execute immediately
	if player_action_queued:
		_execute_queued_player_action()
		return
	
	_log_turn_start(current_player, "player")
	
	# Emit turn changed signal
	turn_changed.emit(current_player, turn_type)

func _start_enemy_turn():
	"""Start the enemy's turn"""
	turn_type = "enemy"
	current_actor = current_enemy
	waiting_for_action = false
	enemy_turn_ready = true
	
	# Give passive spirit regeneration (2 points per turn)
	if current_enemy and current_enemy.has_method("gain_spirit"):
		current_enemy.gain_spirit(2)
	
	_log_turn_start(current_enemy, "enemy")
	
	# Emit turn changed signal
	turn_changed.emit(current_enemy, turn_type)
	
	# Enemy takes action immediately
	_process_enemy_turn()

func _start_atb_timers():
	"""Start the ATB timers for both player and enemy"""
	if not current_player or not current_enemy:
		return
	
	var player_stats = current_player.get_stats()
	var enemy_stats = current_enemy.get_stats()
	
	if not player_stats or not enemy_stats:
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
	
	# Store ATB start times and duration for each entity
	player_atb_start_time = Time.get_ticks_msec() / 1000.0
	enemy_atb_start_time = Time.get_ticks_msec() / 1000.0
	player_atb_duration = player_atb_time
	enemy_atb_duration = enemy_atb_time
	
	# Reset progress
	player_atb_progress = 0.0
	enemy_atb_progress = 0.0
	
	# Start ATB progress updates
	_start_atb_progress_updates()

func _start_atb_progress_updates():
	"""Start updating ATB progress bars"""
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
	
	# Start the timer
	atb_progress_timer.start()
	
	# Store the start time for safety checks using meta
	set_meta("atb_timer_start_time", Time.get_ticks_msec() / 1000.0)

func _update_atb_progress():
	"""Update ATB progress bars"""
	if not in_combat:
		return
	
	# Safety check: ensure we have valid references
	if not current_player or not current_enemy:
		return
	
	# Safety check: prevent ATB from running indefinitely
	if atb_progress_timer and has_meta("atb_timer_start_time"):
		var timer_current_time = Time.get_ticks_msec() / 1000.0
		var timer_start_time = get_meta("atb_timer_start_time", 0.0)
		var timer_age = timer_current_time - timer_start_time
		
		# If timer has been running for more than 60 seconds, something is wrong
		if timer_age > 60.0:
			atb_progress_timer.stop()
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
			_on_enemy_atb_ready()
	else:
		# Keep enemy ATB at 100% while turn is ready
		enemy_atb_progress = 1.0
	
	# Emit signal for UI updates
	atb_bar_updated.emit(player_atb_progress, enemy_atb_progress)
	
	# Check if there are queued actions that should be executed now
	# Only check every few frames to prevent excessive calls
	if int(Time.get_ticks_msec() / 1000.0) % 3 == 0:  # Check every 3 seconds instead of every frame
		check_and_execute_queued_actions()

func _on_player_atb_ready():
	"""Called when player's ATB bar is full"""
	# Safety check: prevent multiple calls
	if player_turn_ready:
		print("⚠️ Player ATB already ready, ignoring duplicate call")
		return
		
	print("🎯 PLAYER ATB READY - Starting player turn!")
	player_turn_ready = true
	
	# ALWAYS give passive spirit when ATB is ready (this is the start of a turn)
	if current_player and current_player.has_method("get_stats") and current_player.get_stats():
		current_player.get_stats().gain_spirit(2)
		print("✨ Player gained 2 passive spirit points for turn start (ATB ready)")
	
	print("🔍 DEBUG: ATB ready - player_action_queued: ", player_action_queued, " queued_action: ", queued_action)
	
	# Check if there's a queued action to execute
	if player_action_queued:
		print("🎯 Executing queued action now that ATB is ready!")
		_execute_queued_player_action()
		return
	
	# Only start player turn if no action is in progress
	if not action_in_progress:
		print("✅ Starting player turn - no action in progress")
		_start_player_turn()
	else:
		print("⏸️ Player ATB ready but action in progress - turn will start when action finishes")
	
	# Also check for any queued actions that should execute now
	# Use the throttled version to prevent excessive calls
	check_and_execute_queued_actions()

func _on_enemy_atb_ready():
	"""Called when enemy's ATB bar is full"""
	# Safety check: prevent multiple calls
	if enemy_turn_ready:
		print("⚠️ Enemy ATB already ready, ignoring duplicate call")
		return
		
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
	
	# Set turn type to enemy for proper ATB state management
	turn_type = "enemy"
	current_actor = current_enemy
	
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
	
	# Check if player has queued actions that should execute now
	check_and_execute_queued_actions()

# Private method for internal use
func _end_enemy_turn():
	"""Private method to end enemy turn - use end_enemy_turn() instead"""
	# This was causing a recursive loop - just call the public method directly
	# end_enemy_turn()  # REMOVED to prevent recursion
	pass

func _end_player_turn():
	"""End the player's turn"""
	print("Player turn ended")
	action_in_progress = false
	player_turn_ready = false
	
	# Check if there's a queued action to execute immediately
	if player_action_queued:
		print("🎯 Executing queued action after turn ended!")
		_execute_queued_player_action()
		return
	
	# Reset player ATB progress and start new timer
	player_atb_progress = 0.0
	
	# Start a new ATB cycle for the player only
	player_atb_start_time = Time.get_ticks_msec() / 1000.0
	print("Player turn ended - starting new ATB cycle at: ", player_atb_start_time, "s")
	
	# Check if there are more queued actions to execute
	check_and_execute_queued_actions()

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
	
	# Stop and clean up camera orientation timer
	var orientation_timer = get_node_or_null("camera_orientation_timer")
	if orientation_timer:
		orientation_timer.stop()
		orientation_timer.queue_free()
		print("🎥 Stopped camera orientation checks")
	
	# Stop and clean up any freeze timers
	var freeze_timer = get_node_or_null("combat_freeze_timer")
	if freeze_timer:
		freeze_timer.stop()
		freeze_timer.queue_free()
		print("🎯 Cleaned up combat freeze timer")
	
	# Stop and clean up any landing check timers
	var landing_timer = get_node_or_null("combat_landing_check_timer")
	if landing_timer:
		landing_timer.stop()
		landing_timer.queue_free()
		print("🎯 Cleaned up landing check timer")
	
	# Stop and clean up any positioning timers
	var positioning_timer = get_node_or_null("combat_positioning_timer")
	if positioning_timer:
		positioning_timer.stop()
		positioning_timer.queue_free()
		print("🎯 Cleaned up positioning timer")
	
	# Unfreeze both entities
	if current_player and current_player.has_method("set_physics_process_enabled"):
		current_player.set_physics_process_enabled(true)
	else:
		# Try alternative unfreezing methods
		if current_player and current_player.has_method("set_process_mode"):
			current_player.set_process_mode(Node.PROCESS_MODE_INHERIT)
		elif current_player and current_player.has_method("set_process"):
			current_player.set_process(true)
	
	# Unfreeze all enemies
	for enemy in current_enemies:
		if enemy and enemy.has_method("set_physics_process_enabled"):
			enemy.set_physics_process_enabled(true)
		elif enemy and enemy.has_method("set_process_mode"):
			enemy.set_process_mode(Node.PROCESS_MODE_INHERIT)
		elif enemy and enemy.has_method("set_process"):
			enemy.set_process(true)
		
		# Hide focus indicators on all enemies
		if enemy.has_method("hide_focus_indicator"):
			enemy.hide_focus_indicator()
			
	# Clear references
	current_enemies.clear()
	current_enemy = null
	current_player = null
	
	# Emit signal for UI to respond
	combat_ended.emit()
	
	# Clear enemy status panel when combat ends - TEMPORARILY DISABLED
	# if combat_ui and combat_ui.has_method("clear_enemy_status_panel"):
	# 	combat_ui.clear_enemy_status_panel()
	# 	print("Enemy status panel cleared")
	
	# Reset camera control to player when combat ends
	if current_player and current_player.has_method("reset_camera_control"):
		current_player.reset_camera_control()
		print("🎥 Camera control returned to player")
	
	# Hide spirit bar when combat ends
	if hud and hud.has_method("hide_spirit_bar"):
		print("CombatManager: Calling HUD.hide_spirit_bar()")
		hud.hide_spirit_bar()
		print("CombatManager: HUD.hide_spirit_bar() completed")
	else:
		print("CombatManager: No HUD found or missing hide_spirit_bar method!")

# Player action methods with action queuing
func player_basic_attack():
	"""Player performs a basic attack"""
	if not in_combat or not current_player or not current_enemy:
		return
	
	# Check if player's turn is ready
	if not player_turn_ready:
		print("Player turn not ready yet! Queuing basic attack...")
		_queue_player_action("basic_attack", {})
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing basic attack...")
		_queue_player_action("basic_attack", {})
		return
	
	# If we get here, the action can be executed immediately
	# Check if there are any queued actions that should go first
	if player_action_queued:
		print("🎯 Executing queued action first, then basic attack!")
		_execute_queued_player_action()
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
		
		# Emit signal for UI updates
		enemy_damaged.emit(current_enemy, "basic_attack", final_damage)
	
	# Gain spirit from basic attack
	if player_stats.has_method("gain_spirit"):
		player_stats.gain_spirit(1)
		print("⚔️ Player gained 1 spirit point from basic attack")
	
	# End player turn
	_end_player_turn()

func player_special_attack():
	print("DEBUG: player_special_attack() called")
	print("=== player_special_attack called ===")
	
	# Check spirit points FIRST, before any ATB or queuing logic
	var haymaker_cost = 3
	var current_spirit = current_player.get_spirit()
	print("DEBUG: player_special_attack - Checking spirit FIRST - Need: ", haymaker_cost, " SP, Have: ", current_spirit, " SP")
	if current_spirit < haymaker_cost:
		print("Not enough spirit! Need ", haymaker_cost, " SP, have ", current_spirit, " SP")
		return
	
	if not in_combat or not current_enemy or not current_player:
		print("Cannot perform special attack: in_combat=", in_combat, " current_enemy=", current_enemy, " current_player=", current_player)
		return
	
	# Check if player's turn is ready (ATB system)
	if not player_turn_ready:
		print("Player turn not ready yet! Queuing special attack...")
		_queue_player_action("special_attack", {})
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing special attack...")
		_queue_player_action("special_attack", {})
		return
	
	# If we get here, the action can be executed immediately
	# Check if there are any queued actions that should go first
	if player_action_queued:
		print("🎯 Executing queued action first, then special attack!")
		_execute_queued_player_action()
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER SPECIAL ATTACK ===")
	_log_player_action("special_attack")
	
	# Spirit check already done at the beginning of the function
	
	# For ATB system, skip movement checks and perform attack directly
	# Perform haymaker special attack
	var base_damage = current_player.get_special_attack_damage()
	var damage_type = current_player.get_special_attack_damage_type()
	var final_damage = _process_haymaker_attack(base_damage, damage_type)
	
	# Spend spirit cost
	current_player.get_stats().spend_spirit(haymaker_cost)
	
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
		# Remove the defeated enemy and continue combat if there are others
		remove_enemy_from_combat(current_enemy)
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
		print("Player turn not ready yet! Queuing spell...")
		_queue_player_action("cast_spell", {})
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing spell...")
		_queue_player_action("cast_spell", {})
		return
	
	# If we get here, the action can be executed immediately
	# Check if there are any queued actions that should go first
	if player_action_queued:
		print("🎯 Executing queued action first, then spell!")
		_execute_queued_player_action()
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
		# Remove the defeated enemy and continue combat if there are others
		remove_enemy_from_combat(current_enemy)
		return
	
	# End turn after spell
	_end_player_turn()

func player_defend():
	"""Player defends, reducing damage taken"""
	if not in_combat or not current_player:
		return
	
	# Check if player's turn is ready
	if not player_turn_ready:
		print("Player turn not ready yet! Queuing defend...")
		_queue_player_action("defend", {})
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing defend...")
		_queue_player_action("defend", {})
		return
	
	# If we get here, the action can be executed immediately
	# Check if there are any queued actions that should go first
	if player_action_queued:
		print("🎯 Executing queued action first, then defend!")
		_execute_queued_player_action()
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
		print("Player turn not ready yet! Queuing item use...")
		_queue_player_action("use_item", {"item_name": item_name})
		return
	
	# Check if an action is already in progress
	if action_in_progress:
		print("Action in progress, queuing item use...")
		_queue_player_action("use_item", {"item_name": item_name})
		return
	
	# If we get here, the action can be executed immediately
	# Check if there are any queued actions that should go first
	if player_action_queued:
		print("🎯 Executing queued action first, then item use!")
		_execute_queued_player_action()
		return
	
	# Mark action as in progress
	action_in_progress = true
	player_turn_ready = false
	
	print("=== PLAYER USE ITEM: ", item_name, " ===")
	_log_player_action("use_item", {"item_name": item_name})
	
	# Find the item in inventory to get its properties
	var player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	var item_resource = null
	if player_inventory:
		var bag = player_inventory.get_bag()
		for slot in bag:
			if bag[slot].item.name == item_name:
				item_resource = bag[slot].item
				break
	
	# Use the item directly on the player
	if item_resource and item_resource.has_method("use"):
		item_resource.use(current_player)
	
	# Handle special item effects (like throwable weapons)
	if item_resource and item_resource.custom_effect == "throw_damage":
		_handle_combat_item_use(item_resource)
	
	# Consume the item from inventory
	if player_inventory and item_resource:
		var bag = player_inventory.get_bag()
		for slot in bag:
			if bag[slot].item.name == item_name:
				bag[slot].quantity -= 1
				if bag[slot].quantity <= 0:
					bag.erase(slot)
				player_inventory.inventory_changed.emit()
				break
	
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
	
	# Update enemy status panel - TEMPORARILY DISABLED
	# if combat_ui and combat_ui.has_method("set_enemy_for_status_panel") and current_enemy:
	# 	combat_ui.set_enemy_for_status_panel(current_enemy)

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
	
	if enemy_stats and enemy_stats.has_method("get_armor_value"):
		armor_reduction = enemy_stats.get_armor_value()
	
	# Calculate final damage (armor reduces damage by 1 per point)
	var final_damage = max(1, damage - armor_reduction)
	
	# Apply damage
	current_enemy.take_damage(final_damage)
	
	# Emit signal for UI updates
	enemy_damaged.emit(current_enemy, "attack", final_damage)
	
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
	print("Player action queued: ", action, " with data: ", data)
	
	# Emit signal for UI to show queued action
	action_queued.emit(action, data)
	
	# Log the queued action to the combat UI
	if combat_ui and combat_ui.has_method("add_combat_log_entry"):
		var action_display = action.replace("_", " ").capitalize()
		var message = "⏳ " + action_display + " queued - waiting for ATB bar to fill"
		if data.has("item_name"):
			message += " (" + data["item_name"] + ")"
		combat_ui.add_combat_log_entry(message)
	
	# Debug: Print the current state after queuing
	print("🔍 DEBUG: After queuing - player_action_queued: ", player_action_queued, " queued_action: ", queued_action)

func _execute_queued_player_action():
	"""Execute the queued player action"""
	print("🚀 _execute_queued_player_action called!")
	
	if not player_action_queued:
		print("❌ No queued action to execute!")
		return
	
	var action = queued_action
	var data = queued_action_data
	
	print("🎯 Executing queued action: ", action, " with data: ", data)
	
	# Clear the queue
	player_action_queued = false
	queued_action = ""
	queued_action_data = {}
	
	# Emit signal for UI to hide queued action
	action_dequeued.emit()
	
	# Execute the action
	print("🎯 About to execute queued action: ", action)
	match action:
		"basic_attack":
			print("🎯 Executing queued basic attack")
			_execute_basic_attack_directly()
		"special_attack":
			print("🎯 Executing queued special attack")
			_execute_special_attack_directly()
		"cast_spell":
			print("🎯 Executing queued spell")
			_execute_spell_directly()
		"defend":
			print("🎯 Executing queued defend")
			_execute_defend_directly()
		"use_item":
			print("🎯 Executing queued item use")
			if data.has("item_name"):
				_execute_item_use_directly(data["item_name"])
		_:
			print("Unknown queued action: ", action)

# Direct execution functions for queued actions (bypass queuing logic)
func _execute_basic_attack_directly():
	"""Execute basic attack directly without queuing checks"""
	print("=== EXECUTING QUEUED BASIC ATTACK ===")
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
		
		# Emit signal for UI updates
		enemy_damaged.emit(current_enemy, "basic_attack", final_damage)
	
	# Gain spirit from basic attack
	if player_stats.has_method("gain_spirit"):
		player_stats.gain_spirit(1)
		print("⚔️ Player gained 1 spirit point from basic attack")
	
	# End player turn
	_end_player_turn()

func _execute_special_attack_directly():
	print("DEBUG: _execute_special_attack_directly() called")
	"""Execute special attack directly without queuing checks"""
	print("=== EXECUTING QUEUED SPECIAL ATTACK ===")
	_log_player_action("special_attack")
	
	print("DEBUG: About to check spirit in _execute_special_attack_directly")
	# Check if player has enough spirit (haymaker costs 3 SP)
	var haymaker_cost = 3
	var current_spirit = current_player.get_spirit()
	print("DEBUG: _execute_special_attack_directly - Need: ", haymaker_cost, " SP, Have: ", current_spirit, " SP")
	if current_spirit < haymaker_cost:
		print("Not enough spirit! Need ", haymaker_cost, " SP, have ", current_player.get_spirit(), " SP")
		_end_player_turn()
		return
	
	# Perform haymaker special attack
	var base_damage = current_player.get_special_attack_damage()
	var damage_type = current_player.get_special_attack_damage_type()
	var final_damage = _process_haymaker_attack(base_damage, damage_type)
	
	# Spend spirit cost
	current_player.get_stats().spend_spirit(haymaker_cost)
	
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
		# Remove the defeated enemy and continue combat if there are others
		remove_enemy_from_combat(current_enemy)
		return
	
	# End turn after special attack
	_end_player_turn()

func _execute_spell_directly():
	"""Execute spell directly without queuing checks"""
	print("=== EXECUTING QUEUED SPELL ===")
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
		# Remove the defeated enemy and continue combat if there are others
		remove_enemy_from_combat(current_enemy)
		return
	
	# End turn after spell
	_end_player_turn()

func _execute_defend_directly():
	"""Execute defend directly without queuing checks"""
	print("=== EXECUTING QUEUED DEFEND ===")
	_log_player_action("defend")
	
	# Set defending state
	player_defending = true
	
	# End player turn
	_end_player_turn()

func _execute_item_use_directly(item_name: String):
	"""Execute item use directly without queuing checks"""
	print("=== EXECUTING QUEUED ITEM USE: ", item_name, " ===")
	_log_player_action("use_item", {"item_name": item_name})
	
	# Find the item in inventory to get its properties
	var player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	var item_resource = null
	if player_inventory:
		var bag = player_inventory.get_bag()
		for slot in bag:
			if bag[slot].item.name == item_name:
				item_resource = bag[slot].item
				break
	
	# Use the item directly on the player
	if item_resource and item_resource.has_method("use"):
		item_resource.use(current_player)
	
	# Handle special item effects (like throwable weapons)
	if item_resource and item_resource.custom_effect == "throw_damage":
		_handle_combat_item_use(item_resource)
	
	# Consume the item from inventory
	if player_inventory and item_resource:
		var bag = player_inventory.get_bag()
		for slot in bag:
			if bag[slot].item.name == item_name:
				bag[slot].quantity -= 1
				if bag[slot].quantity <= 0:
					bag.erase(slot)
				player_inventory.inventory_changed.emit()
				break
	
	# End player turn
	_end_player_turn()

func _handle_combat_item_use(item: Resource):
	"""Handle special combat items like throwable weapons"""
	if not item or not current_enemy:
		return
	
	# Check if it's a throwable weapon
	if item.custom_effect == "throw_damage":
		_handle_throwable_weapon_combat(item)
	else:
		# Handle other item types
		print("Item used: ", item.name, " (no special combat effect)")

func _handle_throwable_weapon_combat(item: Resource):
	"""Handle throwable weapon combat effects"""
	print("🎯 Throwable weapon combat: ", item.name)
	
	# Get item properties
	var damage = item.custom_stats.get("damage", 0)
	var damage_type = item.custom_stats.get("damage_type", "physical")
	var armor_penetration = item.custom_stats.get("armor_penetration", 0)
	var _duration = item.custom_stats.get("duration", 0)  # Unused but kept for future use
	
	# Apply armor penetration
	var final_damage = damage
	if armor_penetration > 0:
		var enemy_armor = 0
		if current_enemy.has_method("get_stats") and current_enemy.get_stats():
			enemy_armor = current_enemy.get_stats().get_armor_value()
		final_damage = max(1, damage + armor_penetration - enemy_armor)
		print("Armor penetration applied: Base damage ", damage, " + Pen ", armor_penetration, " - Enemy armor ", enemy_armor, " = Final ", final_damage)
	
	# Apply damage to enemy
	if current_enemy and current_enemy.has_method("take_damage"):
		current_enemy.take_damage(final_damage)
		_log_attack(current_player, current_enemy, final_damage, "throwable weapon (" + damage_type + ")")
		
		# Emit signal for UI updates
		enemy_damaged.emit(current_enemy, "throwable_weapon", final_damage)
		
		# Handle special effects based on damage type
		if damage_type == "acid":
			_handle_acid_effects(item)
		elif damage_type == "piercing":
			_handle_piercing_effects(item)
		
		# Check if enemy is defeated
		if current_enemy.get_stats().health <= 0:
			print("Enemy defeated by throwable weapon!")
			# Don't end combat immediately - let the enemy handle its death
			# The enemy will call remove_enemy_from_combat when it's ready
			return
	else:
		print("ERROR: Enemy cannot take damage!")

func _handle_acid_effects(item: Resource):
	"""Handle acid-specific effects like poisoning"""
	print("🧪 Processing acid effects...")
	
	# Get acid properties
	var poison_chance = item.custom_stats.get("poison_chance", 35.0)  # Default 35% chance
	var poison_damage = item.custom_stats.get("poison_damage", 5)    # Default 5 damage per tick
	var poison_duration = item.custom_stats.get("duration", 3)       # Default 3 turns
	
	# Roll for poison application
	var roll = randf() * 100.0
	print("Acid poison check: ", roll, " vs ", poison_chance, "% chance")
	
	if roll <= poison_chance:
		print("☠️ Enemy poisoned by acid! Duration: ", poison_duration, " turns, Damage per tick: ", poison_damage)
		
		# Use the new status effects system
		var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
		if status_manager:
			status_manager.apply_poison(current_enemy, poison_damage, poison_duration, current_player)
		else:
			# Fallback: manually track poison if status manager not available
			_apply_manual_poison(poison_damage, poison_duration)
		
		# Log the poison effect
		var enemy_name = current_enemy.enemy_name if current_enemy.has_method("enemy_name") else current_enemy.name
		_log_combat_event("☠️ " + enemy_name + " is poisoned by acid! (" + str(poison_duration) + " turns)")
	else:
		print("Acid did not poison the enemy")

func _handle_piercing_effects(item: Resource):
	"""Handle piercing weapon effects like poison darts"""
	print("🎯 Processing piercing effects...")
	
	# Get piercing weapon properties
	var poison_chance = item.custom_stats.get("poison_chance", 0.0)  # Default 0% chance
	var poison_damage = item.custom_stats.get("poison_damage", 0)    # Default 0 damage per tick
	var poison_duration = item.custom_stats.get("duration", 0)       # Default 0 turns
	
	# Check if this weapon has poison properties
	if poison_chance > 0 and poison_damage > 0 and poison_duration > 0:
		# Roll for poison application
		var roll = randf() * 100.0
		print("Piercing poison check: ", roll, " vs ", poison_chance, "% chance")
		
		if roll <= poison_chance:
			print("☠️ Enemy poisoned by piercing weapon! Duration: ", poison_duration, " turns, Damage per tick: ", poison_damage)
			
			# Use the new status effects system
			var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
			if status_manager:
				status_manager.apply_poison(current_enemy, poison_damage, poison_duration, current_player)
			else:
				# Fallback: manually track poison if status manager not available
				_apply_manual_poison(poison_damage, poison_duration)
			
			# Log the poison effect
			var enemy_name = current_enemy.enemy_name if current_enemy.has_method("enemy_name") else current_enemy.name
			_log_combat_event("☠️ " + enemy_name + " is poisoned by " + item.name + "! (" + str(poison_duration) + " turns)")
		else:
			print("Piercing weapon did not poison the enemy")
	else:
		print("Piercing weapon has no poison properties")

func _apply_manual_poison(damage_per_tick: int, duration: int):
	"""Apply poison manually if status effects system not available"""
	print("⚠️ Status effects system not available - using manual poison tracking")
	
	# For now, just log that poison was applied
	# In a full implementation, you'd want to track this in the enemy's stats
	# or create a status effect system
	print("Manual poison applied: ", damage_per_tick, " damage per tick for ", duration, " turns")

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
	"""Gain spirit when taking damage - REMOVED: only defense gives spirit now"""
	# Spirit gain removed - only successful defense gives spirit points
	pass

func _gain_spirit_from_defense():
	"""Gain spirit when successfully defending"""
	if current_player and current_player.has_method("get_stats") and current_player.get_stats():
		current_player.get_stats().gain_spirit(2)
		print("🛡️ Player gained 2 spirit points from successful defense")

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
	
	# Get player's armor value from stats
	var total_armor = 0
	if player_stats.has_method("get_armor_value"):
		total_armor = player_stats.get_armor_value()
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

# Public method for inventory UI to call
func queue_item_usage(item_name: String):
	"""Queue an item to be used when the player's turn is ready"""
	if not in_combat:
		print("Cannot queue item usage: not in combat")
		return
	
	print("Item usage queued: ", item_name)
	_queue_player_action("use_item", {"item_name": item_name})
	
	# If player's turn is already ready, execute the action immediately
	if player_turn_ready and not action_in_progress:
		print("🎯 Player turn ready - executing queued action immediately!")
		_execute_queued_player_action()

# Status effects convenience methods
func apply_status_effect(target: Node, effect_type: String, damage: int, duration: int, source: Node):
	"""Apply a status effect using the StatusEffectsManager"""
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if status_manager:
		match effect_type:
			"poison":
				status_manager.apply_poison(target, damage, duration, source)
			"ignite":
				status_manager.apply_ignite(target, damage, duration, source)
			"bone_break":
				status_manager.apply_bone_break(target, damage, duration, source)
			"stun":
				status_manager.apply_stun(target, duration, source)
			"slow":
				status_manager.apply_slow(target, duration, source)
			_:
				print("Unknown effect type: ", effect_type)
	else:
		print("StatusEffectsManager not found!")

# Test method for status effects
func test_status_effects():
	"""Test method to apply various status effects for debugging"""
	if not in_combat or not current_enemy:
		print("Cannot test status effects: not in combat or no enemy")
		return
	
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if status_manager:
		print("Testing status effects on ", current_enemy.name)
		
		# Test poison effect
		status_manager.apply_poison(current_enemy, 5, 3, current_player)
		
		# Get debug info
		var debug_info = status_manager.get_effects_debug_info(current_enemy)
		print("Status effects debug info: ", debug_info)
	else:
		print("StatusEffectsManager not found!")

# Helper function to check and execute queued actions
func check_and_execute_queued_actions():
	"""Check if there are queued actions that should be executed immediately"""
	# Safety check: prevent excessive calls
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Use a class variable instead of static local variable
	if not has_method("_get_last_check_time"):
		# Initialize the last check time if it doesn't exist
		set_meta("last_check_time", 0.0)
	
	var last_check_time = get_meta("last_check_time", 0.0)
	
	# Only allow checking every 0.5 seconds to prevent rapid-fire execution
	if current_time - last_check_time < 0.5:
		return
	
	# Update the last check time using meta
	set_meta("last_check_time", current_time)
	
	# Only log when there are actually queued actions to check
	if player_action_queued:
		print("🔍 Checking queued actions - Player queued: ", player_action_queued, " Turn ready: ", player_turn_ready, " Action in progress: ", action_in_progress)
		
		if player_turn_ready and not action_in_progress:
			print("🎯 All conditions met - executing queued action now!")
			_execute_queued_player_action()
		else:
			print("⏸️ Queued action exists but conditions not met:")
			print("  - Player queued: ", player_action_queued)
			print("  - Turn ready: ", player_turn_ready)
			print("  - Action in progress: ", action_in_progress)

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
	
	# In ATB system, we need to reset the appropriate turn ready state
	# and start a new ATB cycle for the entity that just finished their turn
	if turn_type == "enemy":
		# Reset enemy turn ready state and start new ATB cycle
		enemy_turn_ready = false
		enemy_atb_progress = 0.0
		enemy_atb_start_time = Time.get_ticks_msec() / 1000.0
		print("Enemy turn ended - starting new ATB cycle at: ", enemy_atb_start_time, "s")
	elif turn_type == "player":
		# Reset player turn ready state and start new ATB cycle
		player_turn_ready = false
		player_atb_progress = 0.0
		player_atb_start_time = Time.get_ticks_msec() / 1000.0
		print("Player turn ended - starting new ATB cycle at: ", player_atb_start_time, "s")
	
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

func get_queued_action_info() -> Dictionary:
	"""Get information about the currently queued action"""
	if player_action_queued:
		return {
			"action": queued_action,
			"data": queued_action_data
		}
	return {}

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

func _orient_player_toward_enemy(target_enemy: Node = null):
	"""Orient the player and camera toward the enemy when combat starts"""
	var enemy_to_face = target_enemy if target_enemy else current_enemy
	
	if not current_player or not enemy_to_face:
		print("⚠️ Cannot orient: missing player or enemy")
		return
	
	print("🎯 Orienting player and camera toward enemy: ", enemy_to_face.enemy_name if enemy_to_face.has_method("enemy_name") else enemy_to_face.name)
	print("🎯 Player position: ", current_player.global_position, " Enemy position: ", enemy_to_face.global_position)
	
	# Make player face the enemy
	if current_player.has_method("face_target"):
		print("🎯 Calling player.face_target()...")
		current_player.face_target(enemy_to_face)
		print("✅ Player oriented toward enemy")
	else:
		print("⚠️ Player has no face_target method")
	
	# Orient camera toward enemy (if player has camera control methods)
	if current_player.has_method("orient_camera_toward"):
		print("🎯 Calling player.orient_camera_toward()...")
		current_player.orient_camera_toward(enemy_to_face)
		print("✅ Camera oriented toward enemy")
	elif current_player.has_method("get_camera"):
		# Alternative: get camera and orient it directly
		var camera = current_player.get_camera()
		if camera:
			print("🎯 Using direct camera orientation...")
			_orient_camera_toward_enemy(camera, enemy_to_face)
			print("✅ Camera oriented toward enemy (direct method)")
		else:
			print("⚠️ Player.get_camera() returned null")
	else:
		print("⚠️ Player has no camera orientation methods")

func _orient_camera_toward_enemy(camera: Camera3D, target_enemy: Node):
	"""Helper function to orient a camera toward the enemy"""
	if not target_enemy or not camera or not current_player:
		return
	
	# Safety check: ensure both player and enemy are Node3D
	if not current_player is Node3D or not target_enemy is Node3D:
		print("⚠️ Cannot orient camera - player or enemy is not a Node3D")
		return
	
	# Get the direction from player to enemy
	var player_pos = current_player.global_position
	var enemy_pos = target_enemy.global_position
	var direction = (enemy_pos - player_pos).normalized()
	
	# Calculate the target rotation for the player (not the camera)
	# Use the standard atan2 approach but with better debugging
	var target_rotation = atan2(direction.x, direction.z)
	
	# Debug the direction and rotation
	print("🎯 Direction vector: ", direction, " Target rotation: ", target_rotation)
	print("🎯 Player current rotation: ", current_player.rotation.y)
	print("🎯 Expected forward direction: ", Vector3(sin(target_rotation), 0, cos(target_rotation)))
	
	# Try flipping the rotation 180 degrees to fix the orientation issue
	target_rotation += PI
	
	# Rotate the PLAYER to face the enemy (this will rotate the entire camera system)
	var player_tween = create_tween()
	player_tween.tween_property(current_player, "rotation:y", target_rotation, 0.8)
	
	# Also reset the camera's local rotation to look forward
	var camera_tween = create_tween()
	camera_tween.tween_property(camera, "rotation:y", 0.0, 0.8)
	
	print("🎥 Camera system oriented toward enemy (player rotation: ", target_rotation, ")")



func _ensure_camera_faces_enemy():
	"""Double-check that the camera is properly facing the enemy"""
	if not current_player or not current_enemy or not current_player.has_method("get_camera"):
		return
	
	var camera = current_player.get_camera()
	if not camera:
		return
	
	# Safety check: ensure both player and enemy are Node3D
	if not current_player is Node3D or not current_enemy is Node3D:
		print("⚠️ Cannot ensure camera faces enemy - player or enemy is not a Node3D")
		return
	
	# Get the direction from player to enemy
	var player_pos = current_player.global_position
	var enemy_pos = current_enemy.global_position
	var direction = (enemy_pos - player_pos).normalized()
	
	# Calculate the target rotation for the player
	# Use a more reliable method to calculate the angle
	var target_rotation = atan2(direction.x, direction.z)
	
	# Get current player rotation first
	var current_rotation = current_player.rotation.y
	
	# Debug the direction and rotation
	print("🎯 Direction vector: ", direction, " Target rotation: ", target_rotation)
	print("🎯 Player current rotation: ", current_rotation)
	
	# Try flipping the rotation 180 degrees to fix the orientation issue
	target_rotation += PI
	
	# Check if player is already facing the right direction (within 0.1 radians)
	var rotation_diff = abs(current_rotation - target_rotation)
	
	# Normalize rotation difference to handle wrapping around 2π
	if rotation_diff > PI:
		rotation_diff = 2 * PI - rotation_diff
	
	if rotation_diff > 0.1:  # If player is not facing enemy (within ~6 degrees)
		print("🔄 Player not facing enemy, correcting orientation...")
		# Use smooth tweening instead of immediate orientation
		var player_tween = create_tween()
		player_tween.tween_property(current_player, "rotation:y", target_rotation, 0.8)
		
		# Also smoothly reset camera to look forward
		var camera_tween = create_tween()
		camera_tween.tween_property(camera, "rotation:y", 0.0, 0.8)
		print("✅ Player orientation smoothly corrected to face enemy")

func _start_camera_orientation_checks():
	"""Start periodic checks to ensure camera stays oriented toward enemy during combat"""
	if not in_combat or not current_player or not current_enemy:
		return
	
	# Create a timer to check camera orientation every 0.5 seconds during combat
	var orientation_timer = Timer.new()
	orientation_timer.name = "camera_orientation_timer"
	orientation_timer.wait_time = 0.5
	orientation_timer.timeout.connect(_check_camera_orientation)
	add_child(orientation_timer)
	orientation_timer.start()
	
	print("🎥 Started periodic camera orientation checks")

func _check_camera_orientation():
	"""Check if camera is still properly oriented toward enemy"""
	if not in_combat or not current_player or not current_enemy:
		# Stop the timer if combat ended
		var timer = get_node_or_null("camera_orientation_timer")
		if timer:
			timer.queue_free()
		return
	
	# Only check if player has a camera
	if not current_player.has_method("get_camera"):
		return
	
	var camera = current_player.get_camera()
	if not camera:
		return
	
	# Safety check: ensure both player and enemy are Node3D
	if not current_player is Node3D or not current_enemy is Node3D:
		return
	
	# Get the direction from player to enemy
	var player_pos = current_player.global_position
	var enemy_pos = current_enemy.global_position
	var direction = (enemy_pos - player_pos).normalized()
	
	# Calculate the target rotation for the player
	var target_rotation = atan2(direction.x, direction.z)
	
	# Check if player is facing the right direction (within 0.2 radians for periodic checks)
	var current_rotation = current_player.rotation.y
	var rotation_diff = abs(current_rotation - target_rotation)
	
	# Normalize rotation difference to handle wrapping around 2π
	if rotation_diff > PI:
		rotation_diff = 2 * PI - rotation_diff
	
	if rotation_diff > 0.2:  # If player is not facing enemy (within ~11 degrees)
		print("🔄 Periodic check: Player not facing enemy, correcting...")
		# Use the player's orientation methods to smoothly correct
		if current_player.has_method("orient_camera_toward"):
			current_player.orient_camera_toward(current_enemy)
		else:
			# Fallback: force immediate correction
			current_player.rotation.y = target_rotation
			camera.rotation.y = 0.0

func add_enemy_to_combat(enemy: Node):
	"""Add an enemy to an ongoing combat encounter"""
	if not in_combat or not enemy or not current_player:
		print("Cannot add enemy: combat not active or invalid enemy")
		return
	
	# Safety check: ensure enemy is actually an Enemy class
	if not enemy.has_method("get_stats") or not enemy.has_method("take_damage"):
		print("ERROR: Enemy does not have required methods!")
		return
	
	# Add enemy to the list
	if not current_enemies.has(enemy):
		current_enemies.append(enemy)
		print("➕ Enemy added to combat: ", enemy.enemy_name if enemy.has_method("enemy_name") else enemy.name)
		
		# Create HUD panel for the new enemy
		if hud and hud.has_method("create_enemy_panel"):
			hud.create_enemy_panel(enemy)
			print("CombatManager: Created HUD panel for new enemy: ", enemy.name)
		
		# Reorient player and camera toward the new enemy
		_orient_player_toward_enemy(enemy)
		
		# Log the new enemy joining
		_log_combat_event("🆕 " + (enemy.enemy_name if enemy.has_method("enemy_name") else enemy.name) + " joins the fight!")
	else:
		print("⚠️ Enemy already in combat: ", enemy.name)

func remove_enemy_from_combat(enemy: Node):
	"""Remove an enemy from combat when they die"""
	if not in_combat or not enemy:
		print("Cannot remove enemy: combat not active or invalid enemy")
		return
	
	# Check if enemy is already dead to prevent double removal
	if enemy.has_method("get_stats") and enemy.get_stats().health <= 0:
		# Check if enemy is already processing death
		if enemy.has_method("is_processing_death") and enemy.is_processing_death:
			return
		
		# If enemy is already dead, just ensure it's removed from lists
		if current_enemies.has(enemy):
			current_enemies.erase(enemy)
		
		# Update current_enemy if this was the current one
		if current_enemy == enemy:
			if current_enemies.size() > 0:
				current_enemy = current_enemies[0]
				_orient_player_toward_enemy(current_enemy)
			else:
				current_enemy = null
				print("🏁 No more enemies - ending combat")
				end_combat()
		return
	
	# Remove enemy from the list
	if current_enemies.has(enemy):
		current_enemies.erase(enemy)
		print("💀 Enemy removed from combat: ", enemy.enemy_name if enemy.has_method("enemy_name") else enemy.name)
		
		# Remove HUD panel for the defeated enemy
		if hud and hud.has_method("remove_enemy_panel"):
			hud.remove_enemy_panel(enemy)
			print("CombatManager: Removed HUD panel for defeated enemy: ", enemy.name)
		
		# If this was the current enemy, update current_enemy
		if current_enemy == enemy:
			if current_enemies.size() > 0:
				# Set the first remaining enemy as current
				current_enemy = current_enemies[0]
				print("🔄 Current enemy updated to: ", current_enemy.enemy_name if current_enemy.has_method("enemy_name") else current_enemy.name)
				
				# Reorient player and camera toward the new current enemy
				_orient_player_toward_enemy(current_enemy)
			else:
				# No more enemies, end combat
				current_enemy = null
				print("🏁 No more enemies - ending combat")
				end_combat()
		else:
			# Reorient toward the current enemy (if any)
			if current_enemy and current_enemy.has_method("get_stats") and current_enemy.get_stats().health > 0:
				_orient_player_toward_enemy(current_enemy)
			elif current_enemies.size() > 0:
				# Find a living enemy to orient toward
				for living_enemy in current_enemies:
					if living_enemy.has_method("get_stats") and living_enemy.get_stats().health > 0:
						current_enemy = living_enemy
						_orient_player_toward_enemy(current_enemy)
						break
	else:
		print("⚠️ Enemy not found in combat list: ", enemy.name)

func get_nearest_living_enemy() -> Node:
	"""Get the nearest living enemy for automatic targeting"""
	if current_enemies.is_empty():
		return null
	
	# Safety check: ensure current_player is Node3D
	if not current_player is Node3D:
		print("⚠️ Cannot get nearest enemy - player is not a Node3D")
		return null
	
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in current_enemies:
		if enemy.has_method("get_stats") and enemy.get_stats().health > 0:
			# Safety check: ensure enemy is Node3D
			if enemy is Node3D:
				var distance = current_player.global_position.distance_to(enemy.global_position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_enemy = enemy
			else:
				print("⚠️ Enemy is not a Node3D - skipping distance calculation")
	
	return nearest_enemy

func auto_reorient_to_nearest_enemy():
	"""Automatically reorient player and camera toward the nearest living enemy"""
	var nearest = get_nearest_living_enemy()
	if nearest:
		print("🔄 Auto-reorienting toward nearest enemy: ", nearest.enemy_name if nearest.has_method("enemy_name") else nearest.name)
		_orient_player_toward_enemy(nearest)
		return true
	else:
		print("⚠️ No living enemies found for reorientation")
		return false

func join_combat(enemy: Node):
	"""Public method for enemies to join ongoing combat"""
	if not in_combat:
		print("⚠️ Cannot join combat: no combat in progress")
		return false
	
	add_enemy_to_combat(enemy)
	return true

func cycle_target():
	"""Cycle to the next enemy target"""
	if current_enemies.size() <= 1:
		return  # No need to cycle if there's only one enemy
	
	# Move to next enemy
	focused_enemy_index = (focused_enemy_index + 1) % current_enemies.size()
	focused_enemy = current_enemies[focused_enemy_index]
	
	# Update current enemy for backward compatibility
	current_enemy = focused_enemy
	
	# Force camera movement to the new target
	_force_camera_movement_to_enemy(focused_enemy)
	
	# Update UI elements
	if combat_ui and combat_ui.has_method("update_enemy_status_panel"):
		combat_ui.update_enemy_status_panel(focused_enemy)
	
	# Highlight the focused enemy in the HUD
	if hud and hud.has_method("highlight_focused_enemy"):
		hud.highlight_focused_enemy(focused_enemy)
	
	print("🎯 Target changed to: ", focused_enemy.enemy_name if focused_enemy.has_method("enemy_name") else focused_enemy.name)

func get_focused_enemy() -> Node:
	"""Get the currently focused enemy for targeting"""
	return focused_enemy

func set_focused_enemy(enemy: Node):
	"""Set a specific enemy as the focused target"""
	if not enemy or not current_enemies.has(enemy):
		print("Cannot set focused enemy: enemy not in combat")
		return
	
	# Update focused enemy
	focused_enemy_index = current_enemies.find(enemy)
	focused_enemy = enemy
	
	# Update current enemy for backward compatibility
	current_enemy = focused_enemy
	
	# Force camera movement to the new target
	_force_camera_movement_to_enemy(focused_enemy)
	
	# Update UI elements
	if combat_ui and combat_ui.has_method("update_enemy_status_panel"):
		combat_ui.update_enemy_status_panel(focused_enemy)
	
	# Highlight the focused enemy in the HUD
	if hud and hud.has_method("highlight_focused_enemy"):
		hud.highlight_focused_enemy(focused_enemy)
	
	print("🎯 Target set to: ", focused_enemy.enemy_name if focused_enemy.has_method("enemy_name") else focused_enemy.name)

func get_combat_enemies() -> Array[Node]:
	"""Get all enemies currently in combat"""
	return current_enemies.duplicate()

func get_combat_enemy_count() -> int:
	"""Get the number of enemies currently in combat"""
	return current_enemies.size()

func _force_camera_movement_to_enemy(target_enemy: Node):
	"""Force camera movement to make target switching more noticeable"""
	if not current_player or not target_enemy:
		return
	
	print("🎯 Forcing camera movement to enemy: ", target_enemy.name)
	
	# Hide focus indicators on all enemies first
	for enemy in current_enemies:
		if enemy.has_method("hide_focus_indicator"):
			enemy.hide_focus_indicator()
	
	# Show focus indicator on the target enemy
	if target_enemy.has_method("show_focus_indicator"):
		target_enemy.show_focus_indicator()
	
	# Get the direction from player to enemy
	var player_pos = current_player.global_position
	var enemy_pos = target_enemy.global_position
	var direction = (enemy_pos - player_pos).normalized()
	
	# Calculate target rotation
	var target_rotation = atan2(direction.x, direction.z) + PI
	
	# Create a dramatic camera movement: look slightly away first, then to the target
	var look_away_rotation = target_rotation + 0.5  # Look 0.5 radians (about 28 degrees) away
	
	# First, look away from the target
	var tween1 = create_tween()
	tween1.tween_property(current_player, "rotation:y", look_away_rotation, 0.3)
	
	# Then, look back to the target
	tween1.tween_callback(func():
		var tween2 = create_tween()
		tween2.tween_property(current_player, "rotation:y", target_rotation, 0.5)
		print("🎯 Camera movement completed to target: ", target_enemy.name)
	)

func on_enemy_damaged(enemy: Node, damage_type: String, amount: int):
	"""Called when an enemy takes damage"""
	print("CombatManager: Enemy ", enemy.name, " damaged by ", amount, " (", damage_type, ")")
	
	# Update HUD enemy panel if it exists
	if hud and hud.has_method("update_enemy_panel"):
		# Find the enemy panel and update it
		if hud.has_method("get_enemy_panel"):
			var panel = hud.get_enemy_panel(enemy)
			if panel:
				hud.update_enemy_panel(panel, enemy)
	
	# Emit signal for other systems
	enemy_damaged.emit(enemy, damage_type, amount)

# End of CombatManager class
