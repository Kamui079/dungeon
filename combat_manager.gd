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
var player_atb_progress: float = 0.0
var player_turn_ready: bool = false
var action_in_progress: bool = false
var player_action_queued: bool = false
var queued_action: String = ""
var queued_action_data: Dictionary = {}
var player_atb_start_time: float = 0.0  # Individual start time for player
var player_atb_duration: float = 10.0
var atb_progress_timer: Timer = null  # Store reference to the progress timer

# Multi-Enemy ATB System
var enemy_atb_data: Dictionary = {}  # Store ATB data for each enemy
# Note: enemy_turn_queue removed - now using dynamic turn_queue system
# Note: enemy_turn_ready removed - now using dynamic turn system
var current_enemy_acting: Node = null  # Which enemy is currently acting

# Turn order system
var turn_queue: Array = []  # Array of entities waiting for their turn in order of ATB completion
var current_turn_entity: Node = null  # Who is currently allowed to act
var turn_in_progress: bool = false  # Whether someone is currently taking their turn
var atb_completion_order: Array = []  # Track the order entities complete their ATB

# Combat state
var combat_round: int = 1
var waiting_for_action: bool = false

# Safety system to prevent infinite loops
var safety_timer: Timer = null
var last_turn_time: float = 0.0
var max_turn_duration: float = 10.0  # Maximum 10 seconds per turn

# Add damage calculator for armor calculations
var damage_calculator: DamageCalculator

# Animation manager reference
var animation_manager: AnimationManager = null

# Getter method to expose animation_manager to external scripts
func get_animation_manager() -> AnimationManager:
	return animation_manager

# Camera target management for enemy turns
var player_current_target: Node = null  # The enemy the player has targeted
var camera_restore_target: Node = null  # Where to restore camera after enemy turn
var camera_restore_timer: Timer = null  # Timer to restore camera after animation

# Visual targeting indicator
var focus_indicators: Dictionary = {}  # Store focus circles for each enemy
var focus_circle_scene: PackedScene = null

func _ready():
	# Add this node to the CombatManager group
	add_to_group("CombatManager")
	damage_calculator = DamageCalculator.new()
	
	# Initialize animation manager
	animation_manager = AnimationManager.new()
	add_child(animation_manager)
	print("🎬 Animation manager initialized")
	
	# Test the animation system
	if animation_manager:
		animation_manager.test_animation_system()
		# Connect to animation damage ready signal
		print("🔌 Connecting to animation_damage_ready signal...")
		animation_manager.animation_damage_ready.connect(_on_animation_damage_ready)
		print("🔌 Signal connection successful!")
		
		# Test if the connection is working
		print("🔌 Testing signal connection...")
		print("🔌 Animation manager has signal: ", animation_manager.has_signal("animation_damage_ready"))
		print("🔌 Signal connections count: ", animation_manager.get_signal_connection_list("animation_damage_ready").size())
	else:
		print("⚠️ Animation manager is null after initialization!")
	
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




func _get_entity_name(entity: Node) -> String:
	"""Get a readable name for an entity"""
	if not entity:
		return "Unknown"
	
	# For enemies, try to get the display name from enemy behavior
	if entity.has_method("enemy_name"):
		return entity.enemy_name()
	elif entity.has_method("get_name"):
		return entity.get_name()
	elif entity.name:
		return entity.name
	else:
		return str(entity)

func _can_entity_act(entity: Node) -> bool:
	"""Check if an entity is allowed to act right now"""
	if not entity:
		print("❌ Entity is null")
		return false
	
	# No turn should be in progress
	if turn_in_progress:
		print("❌ Turn already in progress")
		return false
	
	# This entity must be at the front of the turn queue
	if turn_queue.size() > 0 and turn_queue[0] != entity:
		print("❌ Entity not at front of queue. Front: ", _get_entity_name(turn_queue[0]), " Requested: ", _get_entity_name(entity))
		return false
	
	# Allow entity to act even if an action is in progress
	# action_in_progress tracks animations, not turns
	# The turn queue system handles turn order independently
	print("✅ Entity can act: ", _get_entity_name(entity))
	return true



# Dynamic Turn Queue Functions
func _add_to_turn_queue_dynamic(entity: Node) -> void:
	"""Add an entity to the turn queue based on ATB completion order"""
	if entity in turn_queue:
		print("⚠️ Entity already in turn queue: ", _get_entity_name(entity))
		return
	
	# Debug the queue state before adding
	print("🔍 Queue state before adding entity:")
	print("  - Queue size: ", turn_queue.size())
	print("  - Queue contents: ", _get_queue_names())
	print("  - Turn in progress: ", turn_in_progress)
	print("  - Current turn entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
	
	# Add to completion order tracking
	atb_completion_order.append(entity)
	
	# Add to turn queue
	turn_queue.append(entity)
	print("🎯 ", _get_entity_name(entity), " added to turn queue. Queue: ", _get_queue_names())
	print("🎯 ATB completion order: ", _get_entity_names(atb_completion_order))
	
	# Only execute immediately if this is the first entity and no turn is in progress
	if turn_queue.size() == 1 and not turn_in_progress and not action_in_progress:
		print("🎯 First entity in queue with no conflicts - allowing to act immediately")
		_allow_entity_to_act(entity)
	else:
		print("🎯 Entity added to queue - waiting for turn")
		print("  - Queue size: ", turn_queue.size())
		print("  - Turn in progress: ", turn_in_progress)
		print("  - Action in progress: ", action_in_progress)

func _get_queue_names() -> String:
	"""Get a readable string of entities in the turn queue"""
	var names = []
	for entity in turn_queue:
		names.append(_get_entity_name(entity))
	return " → ".join(names)

func _get_entity_names(entities: Array) -> String:
	"""Get a readable string of entity names"""
	var names = []
	for entity in entities:
		names.append(_get_entity_name(entity))
	return " → ".join(names)

func _allow_entity_to_act(entity: Node) -> void:
	"""Allow an entity to act"""
	print("🎯 _allow_entity_to_act called for: ", _get_entity_name(entity))
	print("🔍 DEBUG: _allow_entity_to_act details:")
	print("  - Entity: ", _get_entity_name(entity))
	print("  - Is player: ", entity == current_player)
	print("  - Has take_turn method: ", entity.has_method("take_turn"))
	print("  - Turn in progress: ", turn_in_progress)
	print("  - Action in progress: ", action_in_progress)
	print("  - Current turn entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
	
	if not _can_entity_act(entity):
		print("⚠️ Cannot allow entity to act: ", _get_entity_name(entity))
		return
	
	print("🎯 Allowing ", _get_entity_name(entity), " to act")
	print("🔍 Entity details:")
	print("  - Entity: ", _get_entity_name(entity))
	print("  - Is player: ", entity == current_player)
	print("  - Has take_turn method: ", entity.has_method("take_turn"))
	
	current_turn_entity = entity
	turn_in_progress = true
	
	print("🎯 Turn state updated:")
	print("  - Current turn entity: ", _get_entity_name(current_turn_entity))
	print("  - Turn in progress: ", turn_in_progress)
	
	# If this is the player, trigger their turn logic
	if entity == current_player:
		print("🎯 Starting player turn")
		_start_player_turn()
	# If this is an enemy, trigger their turn logic
	elif entity.has_method("take_turn"):
		print("🎯 Starting enemy turn")
		_start_enemy_turn_dynamic(entity)
	else:
		print("⚠️ Entity has no valid turn logic!")

func _start_enemy_turn_dynamic(enemy: Node) -> void:
	"""Start turn for an enemy using the dynamic system"""
	if not enemy or not is_instance_valid(enemy):
		return
	
	# Safety check: make sure enemy is still alive
	if enemy.has_method("get_stats") and enemy.get_stats().health <= 0:
		var enemy_name = _get_entity_name(enemy)
		print("🎯 Enemy ", enemy_name, " is dead, skipping turn")
		_end_enemy_turn_for(enemy)
		return
	
	# Check if enemy is stunned
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if status_manager and status_manager.has_method("has_effect"):
		if status_manager.has_effect(enemy, status_manager.EFFECT_TYPE.STUN):
			var enemy_name = _get_entity_name(enemy)
			_log_combat_event("😵 " + enemy_name + " is stunned and cannot act!")
			_end_enemy_turn_for(enemy)
			return
	
	# Mark action as in progress
	action_in_progress = true
	
	# Set turn type to enemy for proper ATB state management
	turn_type = "enemy"
	current_actor = enemy
	
	# Get enemy name for logging (declare at function level for scope)
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
	
	print("Enemy ", enemy_name, " taking turn...")
	
	# Log enemy turn start to combat log
	var timestamp = Time.get_ticks_msec()
	print("🎯 Starting enemy turn for ", enemy_name, " at timestamp: ", timestamp)
	_log_combat_event("🎯 " + enemy_name + "'s turn begins!")
	
	# Switch camera to attacking enemy for better visibility
	_switch_camera_to_attacking_enemy(enemy)
	
	# Set up a safety timer to force turn end if something goes wrong
	var safety_timer = Timer.new()
	safety_timer.name = "enemy_turn_safety_timer_" + str(enemy.get_instance_id())
	safety_timer.wait_time = 10.0  # 10 second timeout
	safety_timer.one_shot = true
	safety_timer.timeout.connect(func():
		print("⚠️ Safety timeout for ", enemy_name, " - forcing turn end")
		_end_enemy_turn_for(enemy)
		safety_timer.queue_free()
	)
	add_child(safety_timer)
	safety_timer.start()
	
	# Use enemy's AI logic if available, otherwise fall back to basic attack
	if enemy.has_method("take_turn"):
		enemy.take_turn()
	elif enemy.has_method("melee_attack"):
		enemy.melee_attack()
	else:
		# If enemy has no valid actions, end turn immediately
		_end_enemy_turn_for(enemy)
		return

func _finish_entity_turn(entity: Node) -> void:
	"""Mark an entity's turn as finished and move to the next"""
	if entity != current_turn_entity:
		print("⚠️ Trying to finish turn for wrong entity: ", _get_entity_name(entity))
		return
	
	print("🎯 Finishing turn for: ", _get_entity_name(entity))
	
	# Debug the queue state before modification
	print("🔍 Queue state before finishing turn:")
	print("  - Queue size: ", turn_queue.size())
	print("  - Queue contents: ", _get_queue_names())
	print("  - Current turn entity: ", _get_entity_name(current_turn_entity))
	print("  - Turn in progress: ", turn_in_progress)
	print("  - Action in progress: ", action_in_progress)
	
	# Remove this entity from the queue (should always be at front, but check anyway)
	if turn_queue.size() > 0:
		if turn_queue[0] == entity:
			turn_queue.pop_front()
			print("🎯 Removed ", _get_entity_name(entity), " from front of queue")
		else:
			# Entity not at front, remove them from wherever they are
			var index = turn_queue.find(entity)
			if index >= 0:
				turn_queue.remove_at(index)
				print("🎯 Removed ", _get_entity_name(entity), " from queue at index ", index)
			else:
				print("⚠️ Entity ", _get_entity_name(entity), " not found in queue!")
	else:
		print("⚠️ Turn queue is empty!")
	
	# Mark turn as finished but don't reset action_in_progress
	# action_in_progress will be reset when the animation completes
	turn_in_progress = false
	current_turn_entity = null
	
	# Debug the queue state after modification
	print("🔍 Queue state after finishing turn:")
	print("  - Queue size: ", turn_queue.size())
	print("  - Queue contents: ", _get_queue_names())
	print("  - Turn in progress: ", turn_in_progress)
	print("  - Action in progress: ", action_in_progress)
	
	# If there are more entities waiting, let the next one act
	if turn_queue.size() > 0:
		var next_entity = turn_queue[0]
		print("🎯 Allowing next entity to act: ", _get_entity_name(next_entity))
		print("🔍 DEBUG: Next entity details:")
		print("  - Entity: ", _get_entity_name(next_entity))
		print("  - Is player: ", next_entity == current_player)
		print("  - Has take_turn method: ", next_entity.has_method("take_turn"))
		print("  - Turn in progress: ", turn_in_progress)
		print("  - Action in progress: ", action_in_progress)
		print("  - Current turn entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
		
		# If the next entity is the player and they have no action queued, check if they should be skipped
		if next_entity == current_player and not player_action_queued:
			print("🎯 Next entity is player with no action - checking if they should be skipped")
			_check_and_skip_player_if_no_action()
		else:
			# Allow the entity to act normally
			print("🎯 Allowing next entity to act immediately: ", _get_entity_name(next_entity))
			_allow_entity_to_act(next_entity)
	else:
		print("�� Turn queue empty - checking if any enemies are ready to act immediately")
		# Check if any enemies are ready to act right now
		var ready_enemy = _find_ready_enemy()
		if ready_enemy:
			print("🎯 Found ready enemy: ", _get_entity_name(ready_enemy), " - adding to queue immediately")
			_add_to_turn_queue_dynamic(ready_enemy)
		else:
			print("🎯 No enemies ready - waiting for ATB bars to fill")

# Multi-Enemy ATB Management Functions
func initialize_enemy_atb(enemy: Node) -> void:
	"""Initialize ATB data for a new enemy"""
	if not enemy:
		return
	
	var enemy_id = enemy.get_instance_id()
	var base_atb_time = 6.0  # Same base time as player for consistency
	
	# Get enemy speed from stats if available
	var enemy_speed = 1.0
	if enemy.has_method("get_stats"):
		var stats = enemy.get_stats()
		if stats and stats.has_method("get_speed"):
			enemy_speed = stats.get_speed()
	
	# Calculate ATB duration using same formula as player (1% per speed point)
	var enemy_speed_multiplier = 1.0 - (enemy_speed * 0.01)
	enemy_speed_multiplier = max(0.5, enemy_speed_multiplier)  # Minimum 50% of base time
	var atb_duration = base_atb_time * enemy_speed_multiplier
	
	enemy_atb_data[enemy_id] = {
		"enemy": enemy,
		"atb_progress": 0.0,
		"atb_start_time": Time.get_ticks_msec() / 1000.0,
		"atb_duration": atb_duration,
		"turn_ready": false,
		"speed": enemy_speed
	}
	
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
	
	print("🎯 Initialized ATB for ", enemy_name, " - Speed: ", enemy_speed, " ATB Duration: ", atb_duration, "s")

func remove_enemy_atb(enemy: Node) -> void:
	"""Remove ATB data when enemy is defeated"""
	if not enemy:
		return
	
	var enemy_id = enemy.get_instance_id()
	if enemy_atb_data.has(enemy_id):
		enemy_atb_data.erase(enemy_id)
		var enemy_name = "Unknown Enemy"
		if enemy.has_method("enemy_name"):
			enemy_name = enemy.enemy_name()
		elif enemy.name:
			enemy_name = enemy.name
		else:
			enemy_name = str(enemy)
		
		print("🎯 Removed ATB data for ", enemy_name)

func update_enemy_atb_progress() -> void:
	"""Update ATB progress for all enemies and check for ready turns"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for enemy_id in enemy_atb_data.keys():
		var data = enemy_atb_data[enemy_id]
		var enemy = data.enemy
		
		# Skip if enemy is no longer valid
		if not is_instance_valid(enemy):
			enemy_atb_data.erase(enemy_id)
			continue
		
		# Skip if enemy is dead
		if enemy.has_method("get_stats") and enemy.get_stats().health <= 0:
			enemy_atb_data.erase(enemy_id)
			continue
		
		# Skip if enemy turn is already ready
		if data.turn_ready:
			continue
		
		# Calculate ATB progress
		var elapsed_time = current_time - data.atb_start_time
		data.atb_progress = min(1.0, elapsed_time / data.atb_duration)
		
		# Check if ATB is ready
		if data.atb_progress >= 1.0:
			data.atb_progress = 1.0
			data.turn_ready = true
			
			var enemy_name = "Unknown Enemy"
			if enemy.has_method("enemy_name"):
				enemy_name = enemy.enemy_name()
			elif enemy.name:
				enemy_name = enemy.name
			else:
				enemy_name = str(enemy)
			
			print("🎯 Enemy ", enemy_name, " ATB ready!")
			
			# Check if enemy is already in the queue to prevent duplicates
			if enemy in turn_queue:
				print("🎯 Enemy ", enemy_name, " already in queue, skipping duplicate add")
				# Still check if player should be skipped
				_check_and_skip_player_if_no_action()
				return
			
			# Check if we can execute immediately or need to queue
			var can_execute_immediately = not action_in_progress and not turn_in_progress
			
			# Also check if any other entity has full ATB (they should go first)
			for other_enemy_id in enemy_atb_data.keys():
				if other_enemy_id != enemy_id and enemy_atb_data[other_enemy_id].turn_ready:
					can_execute_immediately = false
					break
			
			if can_execute_immediately:
				print("🎯 Enemy ", enemy_name, " can act immediately - no conflicts")
				_add_to_turn_queue_dynamic(enemy)
			else:
				print("🎯 Enemy ", enemy_name, " must wait - adding to queue")
				_add_to_turn_queue_dynamic(enemy)
			
			# Check if player should be skipped now that this enemy is ready
			_check_and_skip_player_if_no_action()









func _end_enemy_turn_for(enemy: Node) -> void:
	"""End turn for a specific enemy and reset their ATB"""
	if not enemy or not is_instance_valid(enemy):
		return
	
	var enemy_id = enemy.get_instance_id()
	if not enemy_atb_data.has(enemy_id):
		return
	
	# Get enemy name for logging (declare at function level for scope)
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
	
	# Check if enemy is still alive - if not, don't reset ATB
	if enemy.has_method("get_stats") and enemy.get_stats().health <= 0:
		print("🎯 Enemy ", enemy_name, " is dead, not resetting ATB")
		# Remove ATB data for dead enemy
		remove_enemy_atb(enemy)
	else:
		# Reset this enemy's ATB for next turn
		var data = enemy_atb_data[enemy_id]
		data.atb_progress = 0.0
		data.turn_ready = false
		data.atb_start_time = Time.get_ticks_msec() / 1000.0
		
		print("🎯 Enemy ", enemy_name, " turn ended - ATB reset for next turn")
		
		var timestamp = Time.get_ticks_msec()
		print("🏁 Ending enemy turn for ", enemy_name, " at timestamp: ", timestamp)
		_log_combat_event("🏁 " + enemy_name + " ends turn")
	
	# Always finish the entity turn if this enemy is in the turn queue
	# This ensures the turn queue system works properly
	if enemy in turn_queue:
		print("🎯 Finishing entity turn for ", enemy_name, " (enemy in turn queue)")
		_finish_entity_turn(enemy)
	else:
		print("🎯 Enemy ", enemy_name, " not in turn queue, turn already finished")
	
	# Restore camera to player's target after enemy turn ends
	_restore_camera_to_player_target()

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
		# Initialize ATB for new enemy
		initialize_enemy_atb(enemy)
	current_enemy = enemy  # Maintain backward compatibility
	focused_enemy = enemy  # Set as focused target
	focused_enemy_index = 0  # First enemy is index 0
	
	# Set initial player target for camera management
	player_current_target = enemy
	camera_restore_target = enemy
	
	# Show focus indicator on the first enemy
	if focused_enemy.has_method("show_focus_indicator"):
		focused_enemy.show_focus_indicator()
	
	# Note: Highlighting will happen after enemy panels are created
	
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
			
			# Now highlight the focused enemy after panels are created
			if hud.has_method("highlight_focused_enemy"):
				hud.highlight_focused_enemy(focused_enemy)
				var enemy_name = "Unknown Enemy"
				if focused_enemy.has_method("enemy_name"):
					enemy_name = focused_enemy.enemy_name()
				elif focused_enemy.name:
					enemy_name = focused_enemy.name
				else:
					enemy_name = str(focused_enemy)
				
				print("CombatManager: Highlighted initial focused enemy: ", enemy_name)
	else:
		print("CombatManager: No HUD found or missing show_spirit_bar method!")
	
	# Log combat start
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
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
	
	# Start ATB system
	_start_atb_timers()

func add_enemy_to_combat(enemy: Node):
	"""Add an additional enemy to an existing combat encounter"""
	if not in_combat or not enemy:
		return
	
	# Safety check: ensure we're not adding the combat manager itself
	if enemy == self:
		return
	
	# Safety check: ensure enemy is actually an Enemy class
	if not enemy.has_method("get_stats") or not enemy.has_method("take_damage"):
		return
	
	# Get enemy name for logging (declare at function level for scope)
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
	
	# Add enemy to the list if not already there
	if not current_enemies.has(enemy):
		current_enemies.append(enemy)
		# Initialize ATB for new enemy
		initialize_enemy_atb(enemy)
		
		print("🎯 Added enemy to combat: ", enemy_name, " - Total enemies: ", current_enemies.size())
		
		# Log enemy joining combat
		
		_log_combat_event("🆕 " + enemy_name + " joins the fight!")
		
		# Create HUD panel for the new enemy
		if hud and hud.has_method("create_enemy_panel"):
			hud.create_enemy_panel(enemy)
		
		# Set combat target for the new enemy
		if enemy.has_method("set_combat_target"):
			enemy.set_combat_target(current_player)
		
		# Call enemy's custom combat start behavior
		if enemy.has_method("on_combat_start"):
			enemy.on_combat_start()
	else:
		print("⚠️ Enemy already in combat: ", enemy_name)
	
	# Disable automatic enemy facing to prevent conflicts
	if current_player and current_player.has_method("set_auto_facing_enabled"):
		current_player.set_auto_facing_enabled(false)
		print("🎯 Disabled automatic enemy facing for combat")
	
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
	player_turn_ready = false
	action_in_progress = false
	player_atb_start_time = 0.0
	player_atb_duration = 10.0
	
	# Enemy ATB is now handled by the multi-enemy system
	# Each enemy gets their own ATB initialized when they join combat

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

func _start_player_turn() -> void:
	"""Start the player's turn"""
	if not current_player:
		print("❌ No current player for turn start")
		return
	
	print("🎯 Starting player turn")
	
	# Log turn start to combat log
	_log_combat_event("🎯 Player's turn (player)")
	
	# Update combat UI to show it's the player's turn
	var combat_ui = get_tree().get_first_node_in_group("CombatUI")
	if combat_ui and combat_ui.has_method("set_turn"):
		combat_ui.set_turn("player", current_player)
	
	# Check if player has a queued action
	if player_action_queued and queued_action != "":
		print("🎯 Player has queued action, executing immediately")
		_execute_queued_player_action()
	else:
		print("🎯 Player turn started - waiting for player input")
		# Add a small delay to prevent rapid-fire skip checks
		# This allows the player a moment to queue an action if they want
		var skip_check_timer = Timer.new()
		skip_check_timer.name = "skip_check_timer"
		skip_check_timer.wait_time = 0.1  # 100ms delay
		skip_check_timer.one_shot = true
		skip_check_timer.timeout.connect(func():
			# Only check for skip if player still has no action queued
			if not player_action_queued:
				print("⏰ Delayed skip check - player still has no action")
				_check_and_skip_player_if_no_action()
			else:
				print("⏰ Player queued action during delay, no skip needed")
			skip_check_timer.queue_free()
		)
		add_child(skip_check_timer)
		skip_check_timer.start()



func _start_atb_timers():
	"""Start the ATB timer for player only - enemy ATB is now handled by multi-enemy system"""
	if not current_player:
		return
	
	var player_stats = current_player.get_stats()
	
	if not player_stats:
		return
	
	# Calculate ATB fill time based on speed (faster = shorter time)
	var base_atb_time = 6.0  # Same base time as enemy for consistency
	var player_speed = max(1, player_stats.speed)

	
	# Each point of speed increases fill speed by 1% (doubled from 0.5%)
	# So 10 speed = 10% faster = 90% of base time
	var player_speed_multiplier = 1.0 - (player_speed * 0.01)

	
	# Ensure minimum multiplier (can't go below 50% of base time)
	player_speed_multiplier = max(0.5, player_speed_multiplier)

	
	var player_atb_time = base_atb_time * player_speed_multiplier
	# Store ATB start time and duration for player
	player_atb_start_time = Time.get_ticks_msec() / 1000.0
	player_atb_duration = player_atb_time
	
	# Reset player progress
	player_atb_progress = 0.0
	
	# Enemy ATB is now handled by the multi-enemy system
	# Each enemy gets their own ATB initialized when they join combat
	
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
	if not current_player or current_enemies.is_empty():
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
	
	# Update multi-enemy ATB progress
	update_enemy_atb_progress()
	
	# Check if any enemy is ready to act
	# Note: Enemy turns are now handled by the dynamic turn queue system
	
	# Emit signal for UI updates (only player progress now)
	atb_bar_updated.emit(player_atb_progress, 0.0)  # Enemy ATB is now hidden
	
	# Check if there are queued actions that should be executed now
	# Only check every few frames to prevent excessive calls
	if int(Time.get_ticks_msec() / 1000.0) % 3 == 0:  # Check every 3 seconds instead of every frame
		check_and_execute_queued_actions()
	
	# Player skip checking is now handled by the cooldown system in _check_and_skip_player_if_no_action

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
	
	# Check if we can execute immediately or need to queue
	var can_execute_immediately = not action_in_progress and not turn_in_progress
	
	# Also check if any enemy has full ATB (they should go first)
	for enemy_id in enemy_atb_data.keys():
		if enemy_atb_data[enemy_id].turn_ready:
			can_execute_immediately = false
			break
	
	if can_execute_immediately:
		print("🎯 Player can act immediately - no conflicts")
		_add_to_turn_queue_dynamic(current_player)
	else:
		print("🎯 Player must wait - adding to queue")
		_add_to_turn_queue_dynamic(current_player)
	
	# Check if player should be skipped immediately (ATB urgency system)
	_check_and_skip_player_if_no_action()
	
	# Note: Queued actions will be executed when it's the player's turn in the queue





func end_enemy_turn():
	"""End the enemy's turn"""
	print("Enemy turn ended")
	action_in_progress = false
	
	# Enemy ATB is now handled by the multi-enemy system
	# Each enemy gets their own ATB cycle when their turn ends
	
	# Check if player has queued actions that should execute now
	check_and_execute_queued_actions()

# Private method for internal use
func _end_enemy_turn():
	"""Private method to end enemy turn - now works with multi-enemy system"""
	# This function is deprecated - use _end_enemy_turn_for(enemy) instead
	# For backward compatibility, end the current enemy's turn
	if current_enemy_acting:
		_end_enemy_turn_for(current_enemy_acting)
	else:
		# Fallback: just mark action as not in progress
		action_in_progress = false

func _end_player_turn():
	"""End the player's turn"""
	print("Player turn ended")
	action_in_progress = false
	player_turn_ready = false
	
	# Always finish the entity turn if the player is in the turn queue
	# This ensures the turn queue system works properly
	if current_player in turn_queue:
		print("🎯 Finishing entity turn for player (player in turn queue)")
		_finish_entity_turn(current_player)
	else:
		print("🎯 Player not in turn queue, turn already finished")
	
	# Note: Queued actions will be executed when it's the player's turn again
	
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
	action_in_progress = false
	
	# Clear turn order system
	turn_queue.clear()
	current_turn_entity = null
	turn_in_progress = false
	atb_completion_order.clear()
	
	# Stop ATB timers
	if player_atb_timer:
		player_atb_timer.stop()
	# Enemy ATB is now handled by the multi-enemy system
	
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
	
	# Re-enable automatic enemy facing after combat ends
	if current_player and current_player.has_method("set_auto_facing_enabled"):
		current_player.set_auto_facing_enabled(true)
		print("🎯 Re-enabled automatic enemy facing after combat")
	
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
	
# Camera management for enemy turns
func _switch_camera_to_attacking_enemy(attacking_enemy: Node):
	"""Switch camera to focus on the attacking enemy during their turn"""
	if not current_player or not attacking_enemy:
		return
	
	# Store where to restore camera after the turn
	if player_current_target:
		camera_restore_target = player_current_target
		print("🎥 Storing camera restore target: ", _get_entity_name(player_current_target))
	
	# Switch camera to attacking enemy
	if current_player.has_method("orient_camera_toward"):
		print("🎥 Switching camera to attacking enemy: ", _get_entity_name(attacking_enemy))
		current_player.orient_camera_toward(attacking_enemy)
	else:
		print("⚠️ Player missing orient_camera_toward method")

func _restore_camera_to_player_target():
	"""Restore camera to the player's current target after enemy turn"""
	if not current_player or not camera_restore_target:
		print("🎥 Cannot restore camera - missing player or restore target")
		return
	
	print("🎥 Attempting to restore camera to player target: ", _get_entity_name(camera_restore_target))
	
	# Always restore camera after enemy turn (don't check current_turn_entity)
	# Add a small delay for smoother transition
	var restore_timer = Timer.new()
	restore_timer.name = "camera_restore_timer"
	restore_timer.wait_time = 0.5  # 0.5 second delay
	restore_timer.one_shot = true
	restore_timer.timeout.connect(func():
		if current_player and current_player.has_method("orient_camera_toward"):
			current_player.orient_camera_toward(camera_restore_target)
			print("🎥 Camera restored to player target after delay")
		else:
			print("⚠️ Cannot restore camera - player missing orient_camera_toward method")
		restore_timer.queue_free()
	)
	add_child(restore_timer)
	restore_timer.start()

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
	
	# Play physical attack animation
	if animation_manager:
		print("🎬 Playing player physical attack animation")
		animation_manager.play_attack_animation(current_player, AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK)
	else:
		print("⚠️ No animation manager available for player attack")
	
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
		current_enemy.take_damage(final_damage, "physical")  # Basic attack is physical damage
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
	
	# Play physical attack animation for haymaker
	if animation_manager:
		print("🎬 Playing player special attack animation")
		animation_manager.play_attack_animation(current_player, AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK)
	else:
		print("⚠️ No animation manager available for player special attack")
	
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
	
	# Play fire magic animation for fireball
	if animation_manager:
		print("🎬 Playing player fire magic animation")
		animation_manager.play_attack_animation(current_player, AnimationManager.ANIMATION_TYPE.FIRE_MAGIC)
	else:
		print("⚠️ No animation manager available for player spell")
	
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
	var base_damage = 25
	var mana_cost = 10
	var damage_type = current_player.get_spell_damage_type()
	var final_damage = _process_attack_damage(base_damage, damage_type, "fireball")
	
	# Apply damage to enemy
	current_enemy.take_damage(final_damage, damage_type)
	_log_attack(current_player, current_enemy, final_damage, "fireball")
	print("Player casts Fireball! Deals ", final_damage, " damage! Costs ", mana_cost, " MP!")
	
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
	var timestamp = Time.get_ticks_msec()
	print("COMBAT LOG [", timestamp, "]: ", message)
	print("Combat UI reference: ", combat_ui)
	if combat_ui:
		print("Combat UI is valid: ", is_instance_valid(combat_ui))
		print("Combat UI has add_combat_log_entry method: ", combat_ui.has_method("add_combat_log_entry"))
		if combat_ui.has_method("add_combat_log_entry"):
			combat_ui.add_combat_log_entry(message)
			print("Combat log entry added successfully at timestamp: ", timestamp)
		else:
			print("WARNING: Combat UI missing add_combat_log_entry method!")
	else:
		print("WARNING: No combat UI reference!")

func _log_turn_start(actor: Node, turn_type_name: String):
	"""Log the start of a turn"""
	var actor_name: String = "Unknown"
	if actor:
		# Try to get enemy name first (most enemies have this method)
		if actor.has_method("enemy_name"):
			actor_name = actor.enemy_name()
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
		# Try to get enemy name first (most enemies have this method)
		if target.has_method("enemy_name"):
			target_name = target.enemy_name()
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
		# Try to get enemy name first (most enemies have this method)
		if winner.has_method("enemy_name"):
			winner_name = winner.enemy_name()
		elif winner.has_method("get_name"):
			winner_name = winner.get_name()
		elif winner.has_method("name"):
			winner_name = winner.name
		else:
			winner_name = str(winner)
	
	# Get loser name
	if loser:
		# Try to get enemy name first (most enemies have this method)
		if loser.has_method("enemy_name"):
			loser_name = loser.enemy_name()
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
	
	# Update enemy status panels in the HUD
	if hud and hud.has_method("update_enemy_panel"):
		for enemy in current_enemies:
			if enemy and is_instance_valid(enemy):
				var panel = hud.get_enemy_panel(enemy)
				if panel:
					hud.update_enemy_panel(panel, enemy)

# ATB System helper methods
func get_player_atb_progress() -> float:
	"""Get the current player ATB progress (0.0 to 1.0)"""
	return player_atb_progress

func get_enemy_atb_progress() -> float:
	"""Get the current enemy ATB progress (0.0 to 1.0) - DEPRECATED: Use multi-enemy system"""
	# This function is deprecated - enemy ATB is now handled per-enemy
	# Return 0.0 to maintain compatibility
	return 0.0

func is_player_turn_ready() -> bool:
	"""Check if the player's turn is ready (ATB bar is full)"""
	var turn_ready = player_turn_ready and not action_in_progress
	print("🔍 Player turn ready check: ATB ready=", player_turn_ready, " Action in progress=", action_in_progress, " Result=", turn_ready)
	return turn_ready



func get_current_turn_type() -> String:
	"""Get the current turn type"""
	return turn_type

func get_current_actor() -> Node:
	"""Get the current actor"""
	return current_actor

# Damage calculation methods (simplified for ATB system)
func _process_attack_damage(base_damage: int, _damage_type: String, _attack_type: String) -> int:
	"""Process attack damage with various modifiers"""
	var final_damage = base_damage
	
	# Apply elemental damage bonuses if the attack is elemental
	if current_player and current_player.has_method("apply_elemental_damage_bonus"):
		final_damage = current_player.apply_elemental_damage_bonus(base_damage, _damage_type)
	
	# Apply other damage modifiers here (critical hits, etc.)
	# For now, just return the elemental-modified damage
	
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
	current_enemy.take_damage(final_damage, "physical")  # Basic attack is physical damage
	
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
	
	# Play animation with damage - damage will be applied when animation completes
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎬 Playing queued player physical attack animation with damage")
		animation_manager.play_attack_animation_with_damage(
			current_player, 
			AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK, 
			current_enemy, 
			final_damage, 
			"physical"
		)
	else:
		# Fallback to old system
		print("⚠️ No animation manager available for queued player attack")
		# Apply damage immediately
		if current_enemy and current_enemy.has_method("take_damage"):
			current_enemy.take_damage(final_damage, "physical")
			_log_damage_dealt(current_player, current_enemy, final_damage)
			enemy_damaged.emit(current_enemy, "basic_attack", final_damage)
		# End player turn immediately
		_end_player_turn()
		return
	
	# Gain spirit from basic attack
	if player_stats.has_method("gain_spirit"):
		player_stats.gain_spirit(1)
		print("⚔️ Player gained 1 spirit point from basic attack")
	
	# Note: Turn will end automatically when animation completes and damage is applied

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
	
	# Play animation with damage - damage will be applied when animation completes
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎬 Playing queued player special attack animation with damage")
		animation_manager.play_attack_animation_with_damage(
			current_player, 
			AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK, 
			current_enemy, 
			actual_damage, 
			"physical"
		)
	else:
		# Fallback to old system
		print("⚠️ No animation manager available for queued player special attack")
		# End turn immediately
		_end_player_turn()
		return
	
	# Note: Turn will end automatically when animation completes and damage is applied

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
	var base_damage = 25
	var mana_cost = 10
	var damage_type = current_player.get_spell_damage_type()
	var final_damage = _process_attack_damage(base_damage, damage_type, "fireball")
	
	# Spend mana
	player_stats.mana -= mana_cost
	
	print("Player casts Fireball! Deals ", final_damage, " damage! Costs ", mana_cost, " MP!")
	
	# Check for fire ignite
	if current_player.has_method("is_fire_attack") and current_player.is_fire_attack("fireball"):
		_check_fire_ignite(final_damage, "fireball")
	
	# Check if enemy is defeated
	if current_enemy.get_stats().health <= 0:
		print("Enemy defeated!")
		# Remove the defeated enemy and continue combat if there are others
		remove_enemy_from_combat(current_enemy)
		return
	
	# Play animation with damage - damage will be applied when animation completes
	if animation_manager and animation_manager.has_method("play_attack_animation_with_damage"):
		print("🎬 Playing queued player fire magic animation with damage")
		animation_manager.play_attack_animation_with_damage(
			current_player, 
			AnimationManager.ANIMATION_TYPE.FIRE_MAGIC, 
			current_enemy, 
			final_damage, 
			damage_type
		)
	else:
		# Fallback to old system
		print("⚠️ No animation manager available for queued player spell")
		# Apply damage immediately
		current_enemy.take_damage(final_damage, damage_type)
		_log_attack(current_player, current_enemy, final_damage, "fireball")
		# End turn immediately
		_end_player_turn()
		return
	
	# Note: Turn will end automatically when animation completes and damage is applied

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
		current_enemy.take_damage(final_damage, damage_type)  # Pass the actual damage type
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
		var enemy_name = "Unknown Enemy"
		if current_enemy.has_method("enemy_name"):
			enemy_name = current_enemy.enemy_name()
		elif current_enemy.name:
			enemy_name = current_enemy.name
		else:
			enemy_name = str(current_enemy)
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
			var enemy_name = "Unknown Enemy"
			if current_enemy.has_method("enemy_name"):
				enemy_name = current_enemy.enemy_name()
			elif current_enemy.name:
				enemy_name = current_enemy.name
			else:
				enemy_name = str(current_enemy)
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
		# Try to get enemy name first (most enemies have this method)
		if target.has_method("enemy_name"):
			target_name = target.enemy_name()
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
	"""Process haymaker attack damage with elemental bonuses"""
	var final_damage = base_damage
	
	# Apply elemental damage bonuses if the attack is elemental
	if current_player and current_player.has_method("apply_elemental_damage_bonus"):
		final_damage = current_player.apply_elemental_damage_bonus(base_damage, _damage_type)
	
	# Haymaker is a special attack, so apply the special attack multiplier
	final_damage = int(final_damage * 1.5)
	
	return final_damage

func _check_fire_ignite(_initial_damage: int, _attack_type: String):
	"""Check if fire attack should ignite the target"""
	if not current_enemy:
		return
	
	# Check if enemy can be ignited through the enemy behavior system
	if not current_enemy.has_method("can_receive_status_effect"):
		return
	
	if not current_enemy.can_receive_status_effect("ignite"):
		return
	
	var ignite_chance = 25.0  # Base 25% chance
	if current_player and current_player.has_method("get_fire_ignite_chance"):
		ignite_chance = current_player.get_fire_ignite_chance()
	
	var roll = randf() * 100.0
	print("Fire ignite check: ", roll, " vs ", ignite_chance, "% chance")
	
	if roll <= ignite_chance:
		print("Fire attack ignited target!")
		# Apply ignite status effect
		var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
		if status_manager:
			status_manager.apply_ignite(current_enemy, int(_initial_damage * 0.2), 3, current_player)
	else:
		print("Fire attack did not ignite target")

func _check_ice_freeze(_initial_damage: int, _attack_type: String):
	"""Check if ice attack should freeze the target"""
	if not current_enemy:
		return
	
	# Check if enemy can be frozen through the enemy behavior system
	if not current_enemy.has_method("can_receive_status_effect"):
		return
	
	if not current_enemy.can_receive_status_effect("freeze"):
		return
	
	var freeze_chance = 20.0  # Base 20% chance
	if current_player and current_player.has_method("get_ice_freeze_chance"):
		freeze_chance = current_player.get_ice_freeze_chance()
	
	var roll = randf() * 100.0
	print("Ice freeze check: ", roll, " vs ", freeze_chance, "% chance")
	
	if roll <= freeze_chance:
		print("Ice attack froze target!")
		# Apply freeze status effect
		var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
		if status_manager:
			status_manager.apply_effect(current_enemy, status_manager.EFFECT_TYPE.FREEZE, int(_initial_damage * 0.15), 2, current_player)
	else:
		print("Ice attack did not freeze target")

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
		current_player.take_damage(final_damage, "physical")  # Enemy attacks are physical damage
		
		# Log damage dealt to combat log
		var attacker_name = "Unknown Enemy"
		if current_enemy_acting and current_enemy_acting.has_method("enemy_name"):
			attacker_name = current_enemy_acting.enemy_name
		elif current_enemy_acting:
			attacker_name = current_enemy_acting.name
		
		var timestamp = Time.get_ticks_msec()
		print("💥 Logging damage: ", attacker_name, " deals ", final_damage, " damage to ", current_player.name, " at timestamp: ", timestamp)
		_log_combat_event("💥 " + attacker_name + " deals " + str(final_damage) + " damage to " + current_player.name + "!")
	
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
	
	# Log enemy attack to combat log
	var attacker_name = "Unknown Enemy"
	if current_enemy_acting and current_enemy_acting.has_method("enemy_name"):
		attacker_name = current_enemy_acting.enemy_name
	elif current_enemy_acting:
		attacker_name = current_enemy_acting.name
	
	var timestamp = Time.get_ticks_msec()
	print("⚔️ Logging enemy attack: ", attacker_name, " performs ", attack_type, " at timestamp: ", timestamp)
	_log_combat_event("⚔️ " + attacker_name + " performs " + attack_type + "!")
	
	# Play attack animation based on attack type
	if animation_manager:
		var animation_type = _get_animation_type_for_attack(attack_type)
		print("🎬 Playing enemy animation: ", animation_type, " for attack type: ", attack_type)
		print("🎬 Current enemy acting: ", current_enemy_acting.name if current_enemy_acting else "null")
		animation_manager.play_attack_animation(current_enemy_acting, animation_type)
	else:
		print("⚠️ No animation manager available for enemy attack")
	
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
		var enemy_name = "Unknown Enemy"
		if current_enemy.has_method("enemy_name"):
			enemy_name = current_enemy.enemy_name()
		elif current_enemy.name:
			enemy_name = current_enemy.name
		else:
			enemy_name = str(current_enemy)
		
		print("Testing status effects on ", enemy_name)
		
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
		
		# Debug the turn queue state
		print("🔍 Turn queue debug:")
		print("  - Queue size: ", turn_queue.size())
		print("  - Queue contents: ", _get_queue_names())
		print("  - Current turn entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
		print("  - Turn in progress: ", turn_in_progress)
		
		# Only execute queued actions when it's the player's turn in the queue
		if player_turn_ready and not action_in_progress and turn_queue.size() > 0 and turn_queue[0] == current_player:
			print("🎯 All conditions met - executing queued action now!")
			_execute_queued_player_action()
		else:
			print("⏸️ Queued action exists but conditions not met:")
			print("  - Player queued: ", player_action_queued)
			print("  - Turn ready: ", player_turn_ready)
			print("  - Action in progress: ", action_in_progress)
			print("  - Player at front of queue: ", turn_queue.size() > 0 and turn_queue[0] == current_player)


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
	
	print("🎯 end_current_turn() called for ", _get_entity_name(current_actor) if current_actor else "Unknown")
	print("  Current turn entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
	print("  Turn type: ", turn_type)
	print("  Turn in progress: ", turn_in_progress)
	print("  Action in progress: ", action_in_progress)
	
	# Use the new turn queue system instead of the legacy ATB system
	if current_turn_entity:
		print("🎯 Ending turn for current turn entity: ", _get_entity_name(current_turn_entity))
		
		# Check if this is an enemy or player
		if current_turn_entity.has_method("enemy_name"):  # This is an enemy
			print("🎯 Ending enemy turn through turn queue system")
			_end_enemy_turn_for(current_turn_entity)
		elif current_turn_entity == current_player:  # This is the player
			print("🎯 Ending player turn through turn queue system")
			_end_player_turn()
		else:
			print("⚠️ Unknown entity type, cannot end turn")
	else:
		print("⚠️ No current turn entity to end turn for")
	
	# Note: The turn queue system will automatically handle moving to the next entity
	# No need to manually reset ATB or start new cycles

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
		"action_in_progress": action_in_progress,
		"turn_type": turn_type,
		"atb_progress_timer_active": atb_progress_timer != null and atb_progress_timer.timeout.is_connected(_update_atb_progress),
		"enemy_atb_data": enemy_atb_data.size(),
		"turn_queue": turn_queue.size()
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
	
	print("🎥 DEBUG: Camera height before orientation: ", camera.rotation.x, " (", rad_to_deg(camera.rotation.x), " degrees)")
	
	# Quick smooth reset of camera height to level for combat
	var height_tween = create_tween()
	height_tween.tween_property(camera, "rotation:x", 0.0, 0.2)
	print("🎥 DEBUG: Camera height tween started from ", camera.rotation.x, " to 0.0")
	
	# Safety check: ensure both player and enemy are Node3D
	if not current_player is Node3D or not target_enemy is Node3D:
		print("⚠️ Cannot orient camera - player or enemy is not a Node3D")
		return
	
	# Get the direction from player to enemy
	var player_pos = current_player.global_position
	var enemy_pos = target_enemy.global_position
	var direction = (enemy_pos - player_pos)
	direction.y = 0  # Keep it level
	direction = direction.normalized()  # Normalize after setting Y to 0
	
	# Calculate the target rotation for the player (not the camera)
	# Calculate the target rotation for the player (not the camera)
	var target_rotation = atan2(direction.x, direction.z)
	
	# Try flipping the rotation 180 degrees to fix the orientation issue
	target_rotation += PI
	
	print("🎥 DEBUG: Starting camera height reset from ", camera.rotation.x, " to 0.0")
	var camera_tween = create_tween()
	camera_tween.parallel().tween_property(camera, "rotation:y", 0.0, 0.8)  # Face forward
	camera_tween.parallel().tween_property(camera, "rotation:x", 0.0, 0.8)  # Reset to level height
	camera_tween.tween_callback(func():
		print("🎥 DEBUG: Camera height after orientation: ", camera.rotation.x, " (", rad_to_deg(camera.rotation.x), " degrees)")
	)
	
	# Rotate the player to face the enemy
	var player_tween = create_tween()
	player_tween.tween_property(current_player, "rotation:y", target_rotation, 0.8)
	
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
	var direction = (enemy_pos - player_pos)
	direction.y = 0  # Keep it level
	direction = direction.normalized()  # Normalize after setting Y to 0
	
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

# This duplicate function has been removed - use the one defined earlier in the file

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
		var enemy_display_name = "Unknown Enemy"
		if enemy.has_method("enemy_name"):
			enemy_display_name = enemy.enemy_name()
		elif enemy.name:
			enemy_display_name = enemy.name
		else:
			enemy_display_name = str(enemy)
		print("💀 Enemy removed from combat: ", enemy_display_name)
		
		# Log enemy defeat to combat log
		var enemy_name = "Unknown Enemy"
		if enemy.has_method("enemy_name"):
			enemy_name = enemy.enemy_name()
		else:
			enemy_name = enemy.name
		
		_log_combat_event("💀 " + enemy_name + " has been defeated!")
		
		# Remove ATB data for the defeated enemy
		remove_enemy_atb(enemy)
		
		# Remove HUD panel for the defeated enemy
		if hud and hud.has_method("remove_enemy_panel"):
			hud.remove_enemy_panel(enemy)
			print("CombatManager: Removed HUD panel for defeated enemy: ", enemy_name)
		
		# If this was the current enemy, update current_enemy
		if current_enemy == enemy:
			if current_enemies.size() > 0:
				# Set the first remaining enemy as current
				current_enemy = current_enemies[0]
				var current_enemy_display_name = "Unknown Enemy"
				if current_enemy.has_method("enemy_name"):
					current_enemy_display_name = current_enemy.enemy_name()
				elif current_enemy.name:
					current_enemy_display_name = current_enemy.name
				else:
					current_enemy_display_name = str(current_enemy)
				print("🔄 Current enemy updated to: ", current_enemy_display_name)
				
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
		var enemy_name = "Unknown Enemy"
		if enemy.has_method("enemy_name"):
			enemy_name = enemy.enemy_name()
		elif enemy.name:
			enemy_name = enemy.name
		else:
			enemy_name = str(enemy)
		
		print("⚠️ Enemy not found in combat list: ", enemy_name)

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
	
	# Update player's current target for camera management
	player_current_target = focused_enemy
	camera_restore_target = focused_enemy
	
	# Force camera movement to the new target
	_force_camera_movement_to_enemy(focused_enemy)
	
	# Update UI elements
	if combat_ui and combat_ui.has_method("update_enemy_status_panel"):
		combat_ui.update_enemy_status_panel(focused_enemy)
	
	# Highlight the focused enemy in the HUD
	if hud and hud.has_method("highlight_focused_enemy"):
		hud.highlight_focused_enemy(focused_enemy)
	
	var focused_enemy_display_name = "Unknown Enemy"
	if focused_enemy.has_method("enemy_name"):
		focused_enemy_display_name = focused_enemy.enemy_name()
	elif focused_enemy.name:
		focused_enemy_display_name = focused_enemy.name
	else:
		focused_enemy_display_name = str(focused_enemy)
	print("🎯 Target changed to: ", focused_enemy_display_name)

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
	
	# Update player's current target for camera management
	player_current_target = focused_enemy
	camera_restore_target = focused_enemy
	
	# Force camera movement to the new target
	_force_camera_movement_to_enemy(focused_enemy)
	
	# Update UI elements
	if combat_ui and combat_ui.has_method("update_enemy_status_panel"):
		combat_ui.update_enemy_status_panel(focused_enemy)
	
	# Highlight the focused enemy in the HUD
	if hud and hud.has_method("highlight_focused_enemy"):
		hud.highlight_focused_enemy(focused_enemy)
	
	var focused_enemy_display_name = "Unknown Enemy"
	if focused_enemy.has_method("enemy_name"):
		focused_enemy_display_name = focused_enemy.enemy_name()
	elif focused_enemy.name:
		focused_enemy_display_name = focused_enemy.name
	else:
		focused_enemy_display_name = str(focused_enemy)
	print("🎯 Target set to: ", focused_enemy_display_name)

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
	
	var enemy_name = "Unknown Enemy"
	if target_enemy.has_method("enemy_name"):
		enemy_name = target_enemy.enemy_name()
	elif target_enemy.name:
		enemy_name = target_enemy.name
	else:
		enemy_name = str(target_enemy)
	
	print("🎯 Forcing camera movement to enemy: ", enemy_name)
	
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
	# Capture enemy_name for the lambda function
	var captured_enemy_name = enemy_name
	tween1.tween_callback(func():
		var tween2 = create_tween()
		tween2.tween_property(current_player, "rotation:y", target_rotation, 0.5)
		print("🎯 Camera movement completed to target: ", captured_enemy_name)
	)

func on_enemy_damaged(enemy: Node, damage_type: String, amount: int):
	"""Called when an enemy takes damage"""
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
	
	print("CombatManager: Enemy ", enemy_name, " damaged by ", amount, " (", damage_type, ")")
	
	# Update HUD enemy panel if it exists
	if hud and hud.has_method("update_enemy_panel"):
		# Find the enemy panel and update it
		if hud.has_method("get_enemy_panel"):
			var panel = hud.get_enemy_panel(enemy)
			if panel:
				hud.update_enemy_panel(panel, enemy)
	
	# Emit signal for other systems
	enemy_damaged.emit(enemy, damage_type, amount)

func wait_for_animation_then_end_turn(enemy: Node) -> void:
	"""Wait for an enemy's animation to complete, then end their turn"""
	if not enemy or not is_instance_valid(enemy):
		print("⚠️ Cannot wait for animation - invalid enemy")
		return
	
	var enemy_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_name = enemy.enemy_name()
	elif enemy.name:
		enemy_name = enemy.name
	else:
		enemy_name = str(enemy)
	
	if animation_manager and animation_manager.is_animation_playing(enemy):
		print("🎬 Waiting for animation to complete for ", enemy_name)
		# Connect to animation finished signal
		# Capture enemy_name for the lambda function
		var captured_enemy_name = enemy_name
		animation_manager.animation_finished.connect(func(_anim_type, actor):
			if actor == enemy:
				print("🎬 Animation finished for ", captured_enemy_name, ", ending turn")
				# Reset movement attempts for next turn
				if enemy.has_method("movement_attempts"):
					enemy.movement_attempts = 0
				# End the enemy turn
				_end_enemy_turn_for(enemy)
		, CONNECT_ONE_SHOT)
		
		# Add a safety timeout here too
		var safety_timer = Timer.new()
		safety_timer.name = "turn_end_safety_timer_" + str(enemy.get_instance_id())
		safety_timer.wait_time = 8.0  # 8 second timeout for turn ending
		safety_timer.one_shot = true
		safety_timer.timeout.connect(func():
			print("⚠️ Turn end safety timeout for ", captured_enemy_name, ", forcing turn end")
			# Reset movement attempts for next turn
			if enemy.has_method("movement_attempts"):
				enemy.movement_attempts = 0
			# End the enemy turn
			_end_enemy_turn_for(enemy)
			safety_timer.queue_free()
		)
		add_child(safety_timer)
		safety_timer.start()
	else:
		print("🎬 No animation playing for ", enemy_name, ", ending turn immediately")
		# Reset movement attempts for next turn
		if enemy.has_method("movement_attempts"):
			enemy.movement_attempts = 0
		# End the enemy turn immediately
		_end_enemy_turn_for(enemy)

func _get_animation_type_for_attack(attack_type: String) -> AnimationManager.ANIMATION_TYPE:
	"""Determine the appropriate animation type for an attack"""
	match attack_type:
		"fire_attack", "fireball", "fire_magic":
			return AnimationManager.ANIMATION_TYPE.FIRE_MAGIC
		"frost_attack", "ice_attack", "frost_magic", "ice_magic":
			return AnimationManager.ANIMATION_TYPE.FROST_MAGIC
		"throw", "throw_attack", "ranged_attack":
			return AnimationManager.ANIMATION_TYPE.THROW_ATTACK
		"basic attack", "melee_attack", "physical_attack", "bite", "special attack":
		# Default to physical attack for most enemy attacks
			return AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK
		_:
			return AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK

func _on_animation_damage_ready(_animation_type: AnimationManager.ANIMATION_TYPE, actor: Node, target: Node, damage: int, damage_type: String) -> void:
	"""Handle damage and hitflash when animation completes"""
	print("🎯 _on_animation_damage_ready called!")
	print("🎯 Animation type: ", _animation_type)
	print("🎯 Actor: ", _get_entity_name(actor))
	print("🎯 Target: ", _get_entity_name(target))
	print("🎯 Damage: ", damage, " ", damage_type)
	
	if not actor or not target or not is_instance_valid(actor) or not is_instance_valid(target):
		print("⚠️ Invalid actor or target for animation damage")
		return
	
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	var target_name = "Unknown"
	if target.has_method("get_name"):
		target_name = target.get_name()
	elif target.name:
		target_name = target.name
	else:
		target_name = str(target)
	
	print("💥 Animation completed for ", actor_name, " - applying damage and hitflash to ", target_name)
	
	# Apply damage to target
	if target.has_method("take_damage"):
		target.take_damage(damage, damage_type)
		print("💥 ", target_name, " took ", damage, " ", damage_type, " damage!")
	
	# Note: Hitflash is now handled by the moving attack effect animation
	
	# Log the damage to combat log
	if actor.has_method("enemy_name"):  # This is an enemy
		# Log specific enemy action details
		var action_name = "attacks"
		if _animation_type == AnimationManager.ANIMATION_TYPE.PHYSICAL_ATTACK:
			action_name = "attacks"
		elif _animation_type == AnimationManager.ANIMATION_TYPE.FIRE_MAGIC:
			action_name = "casts fire magic"
		elif _animation_type == AnimationManager.ANIMATION_TYPE.FROST_MAGIC:
			action_name = "casts frost magic"
		elif _animation_type == AnimationManager.ANIMATION_TYPE.THROW_ATTACK:
			action_name = "throws"
		
		_log_combat_event("⚔️ " + actor_name + " " + action_name + " " + target_name + " for " + str(damage) + " " + damage_type + " damage!")
	else:  # This is the player
		_log_combat_event("💥 " + actor_name + " deals " + str(damage) + " damage to " + target_name + "!")
	
	# End the actor's turn after damage is applied
	if actor.has_method("enemy_name"):  # This is an enemy
		print("🎯 Enemy ", actor_name, " animation completed, ending turn")
		
		# Reset action_in_progress to allow next entity to act
		action_in_progress = false
		print("🎯 Action in progress reset to false")
		
		_end_enemy_turn_for(actor)
		
		# Restore camera to player's target after enemy turn
		_restore_camera_to_player_target()
	else:  # This is the player
		print("🎯 Player animation completed, ending turn")
		
		# Reset action_in_progress to allow next entity to act
		action_in_progress = false
		print("🎯 Action in progress reset to false")
		
		_end_player_turn()

# End of CombatManager class

func is_combat_active() -> bool:
	"""Check if combat is currently active"""
	return in_combat

func _check_and_skip_player_if_no_action():
	"""Check if player should be skipped due to no queued action, and implement skip and re-queue logic"""
	if not current_player or not player_turn_ready:
		return
	
	# Check if player is at the front of the queue but has no action
	if turn_queue.size() > 0 and turn_queue[0] == current_player and not player_action_queued:
		print("⏰ Player has no queued action - checking if they should be skipped")
		
		# Check if any other entity is ready to act
		var other_entity_ready = false
		var next_ready_entity = null
		
		# Check enemies with full ATB - use the actual enemy nodes, not IDs
		for enemy in get_tree().get_nodes_in_group("Enemy"):
			if enemy and is_instance_valid(enemy) and enemy != current_player:
				# Check if this enemy has full ATB by looking at their data
				var enemy_id = enemy.get_instance_id()
				if enemy_atb_data.has(enemy_id) and enemy_atb_data[enemy_id].turn_ready:
					if enemy in turn_queue:
						other_entity_ready = true
						next_ready_entity = enemy
						break
		
		# If another entity is ready, skip the player and re-queue them after that entity
		if other_entity_ready and next_ready_entity:
			print("⏰ Skipping player - ", _get_entity_name(next_ready_entity), " is ready to act")
			print("⏰ DEBUG: Before skip - turn_in_progress: ", turn_in_progress, " current_turn_entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
			
			# First, end the player's current turn since we're skipping them
			if turn_in_progress and current_turn_entity == current_player:
				print("⏰ Ending player's skipped turn")
				turn_in_progress = false
				current_turn_entity = null
				action_in_progress = false
			
			print("⏰ DEBUG: After ending turn - turn_in_progress: ", turn_in_progress, " current_turn_entity: ", _get_entity_name(current_turn_entity) if current_turn_entity else "None")
			
			# Remove player from front of queue
			turn_queue.pop_front()
			print("⏰ DEBUG: After removing player - queue: ", _get_queue_names())
			
			# Find the next ready entity in the queue
			var next_entity_index = turn_queue.find(next_ready_entity)
			if next_entity_index != -1:
				# Insert player right after the next ready entity
				turn_queue.insert(next_entity_index + 1, current_player)
				print("⏰ Player re-queued after ", _get_entity_name(next_ready_entity))
			else:
				# Fallback: add player to back of queue
				turn_queue.append(current_player)
				print("⏰ Player added to back of queue (fallback)")
			
			print("⏰ DEBUG: After re-queuing player - queue: ", _get_queue_names())
			
			# Log the skip
			_log_combat_event("⏰ Player's turn skipped - no action queued!")
			
			# Allow the next ready entity to act
			if turn_queue.size() > 0:
				var next_entity = turn_queue[0]
				if next_entity != current_player:
					print("⏰ Allowing ", _get_entity_name(next_entity), " to act (skipped player)")
					print("⏰ DEBUG: About to call _allow_entity_to_act for ", _get_entity_name(next_entity))
					_allow_entity_to_act(next_entity)
				else:
					print("⏰ Player is next in queue after skip")
			else:
				print("⏰ Queue is empty after skip")
		else:
			print("⏰ No other entities ready - player keeps their turn and waits")
			# Player keeps their turn - they'll either queue an action or get skipped
			# when another entity becomes ready (handled in enemy ATB ready logic)

func _find_ready_enemy() -> Node:
	"""Find an enemy that is ready to act (has full ATB bar)"""
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy and is_instance_valid(enemy) and enemy != current_player:
			var enemy_id = enemy.get_instance_id()
			if enemy_atb_data.has(enemy_id):
				var data = enemy_atb_data[enemy_id]
				if data.get("turn_ready", false):
					print("🎯 Found ready enemy: ", _get_entity_name(enemy))
					return enemy
	return null
