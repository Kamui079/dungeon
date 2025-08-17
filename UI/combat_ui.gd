extends CanvasLayer

class_name CombatUI

@onready var basic_attack_button: Button = $CombatPanel/VBoxContainer/ActionsSection/BasicAttackButton
@onready var special_attacks_button: Button = $CombatPanel/VBoxContainer/SpecialAttacksButton
@onready var spells_button: Button = $CombatPanel/VBoxContainer/SpellsButton
@onready var defend_button: Button = $CombatPanel/VBoxContainer/ActionsSection/DefendButton
@onready var item_button: Button = $CombatPanel/VBoxContainer/ActionsSection/ItemButton
# @onready var target_button: Button = $CombatPanel/VBoxContainer/TargetButton # REMOVED

# Popup windows
@onready var special_attacks_popup: Panel = $SpecialAttacksPopup
@onready var spells_popup: Panel = $SpellsPopup
@onready var haymaker_button: Button = $SpecialAttacksPopup/VBoxContainer/ScrollContainer/VBoxContainer/HaymakerButton
@onready var fireball_button: Button = $SpellsPopup/VBoxContainer/ScrollContainer/VBoxContainer/FireballButton
@onready var special_attacks_close_button: Button = $SpecialAttacksPopup/VBoxContainer/CloseButton
@onready var spells_close_button: Button = $SpellsPopup/VBoxContainer/CloseButton

# Turn system display
@onready var turn_info_label: Label = $CombatPanel/VBoxContainer/TurnInfoSection/TurnInfoLabel

# ATB System elements
@onready var player_atb_bar: ProgressBar = $CombatPanel/VBoxContainer/ATBSection/PlayerATBBar

@onready var atb_status_label: Label = $CombatPanel/VBoxContainer/ATBSection/ATBStatusLabel

# Queued action indicator
@onready var queued_action_label: Label = $CombatPanel/VBoxContainer/QueuedActionSection/QueuedActionLabel

# Combat log
@onready var combat_log_text: TextEdit = $CombatLogPanel/VBoxContainer/CombatLogText

# Enemy status panel (new top-screen display)
# @onready var enemy_status_panel: Panel = $EnemyStatusPanel # REMOVED

# Multi-Enemy Panel System
# @onready var enemy_panels_container: HBoxContainer = $EnemyPanelsContainer # REMOVED

var combat_manager: Node = null

# Button state management
var button_states = {}

# Track which button corresponds to which action for highlighting
var action_button_map = {}
var currently_queued_action: String = ""

func _ready():
	print("=== COMBAT UI READY ===")
	# Add to CombatUI group for spirit updates
	add_to_group("CombatUI")
	
	# Initialize UI elements
	# enemy_status_panel = $EnemyStatusPanel
	# enemy_name_label = $EnemyStatusPanel/VBoxContainer/EnemyNameLabel
	# health_bar = $EnemyStatusPanel/VBoxContainer/HealthBar
	# health_value = $EnemyStatusPanel/VBoxContainer/HealthValue
	# mana_bar = $EnemyStatusPanel/VBoxContainer/ManaBar
	# mana_value = $EnemyStatusPanel/VBoxContainer/ManaValue
	
	# Connect to status effects manager for updates - TEMPORARILY DISABLED
	# var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	# if status_manager:
	# 	status_manager.effects_changed.connect(_on_effects_changed)
	# 	print("Combat UI: Connected to status effects manager")
	
	# Start hidden
	hide()
	
	# Hide enemy status panel initially
	# hide_enemy_status_panel() # REMOVED
	
	# Hide queued action indicator initially
	if queued_action_label:
		queued_action_label.hide()
		print("Queued action label hidden at startup")
	else:
		print("ERROR: Queued action label not found at startup!")
	
	# Force hide popups at startup
	if special_attacks_popup:
		special_attacks_popup.hide()
		print("Special attacks popup hidden at startup")
	else:
		print("ERROR: Special attacks popup not found at startup!")
		
	if spells_popup:
		spells_popup.hide()
		print("Spells popup hidden at startup")
	else:
		print("ERROR: Spells popup not found at startup!")
	
	# Debug: Check if all UI elements are properly loaded
	print("=== UI ELEMENTS DEBUG ===")
	print("Basic Attack Button: ", basic_attack_button)
	print("Special Attacks Button: ", special_attacks_button)
	print("Spells Button: ", spells_button)
	print("Defend Button: ", defend_button)
	print("Item Button: ", item_button)
	
	print("=== COMBAT LOG DEBUG ===")
	print("Combat Log Text: ", combat_log_text)
	if combat_log_text:
		print("Combat Log Text is valid: ", is_instance_valid(combat_log_text))
		print("Combat Log Text path: ", combat_log_text.get_path())
	else:
		print("ERROR: Combat Log Text not found!")
	
	print("=== ENEMY STATUS ELEMENTS ===")
	print("Enemy status now displayed above enemy head")
	
	# Connect button signals only if buttons exist
	if basic_attack_button:
		basic_attack_button.pressed.connect(_on_basic_attack_pressed)
		print("Basic attack button connected!")
	else:
		print("ERROR: Basic attack button not found!")
		
	if special_attacks_button:
		special_attacks_button.pressed.connect(_on_special_attacks_popup_pressed)
		print("Special attacks button connected!")
	else:
		print("ERROR: Special attacks button not found!")
		
	if spells_button:
		spells_button.pressed.connect(_on_spells_popup_pressed)
		print("Spells button connected!")
	else:
		print("ERROR: Spells button not found!")
	
	# Start updating button states
	update_button_states()
	
	# Connect popup buttons
	if haymaker_button:
		haymaker_button.pressed.connect(_on_haymaker_pressed)
		print("Haymaker button connected!")
	else:
		print("ERROR: Haymaker button not found!")
		
	if fireball_button:
		fireball_button.pressed.connect(_on_fireball_pressed)
		print("Fireball button connected!")
	else:
		print("ERROR: Fireball button not found!")
		
	# Connect close buttons
	if special_attacks_close_button:
		special_attacks_close_button.pressed.connect(_on_special_attacks_close_pressed)
		print("Special attacks close button connected!")
	else:
		print("ERROR: Special attacks close button not found!")
		
	if spells_close_button:
		spells_close_button.pressed.connect(_on_spells_close_pressed)
		print("Spells close button connected!")
	else:
		print("ERROR: Spells close button not found!")
		
	if defend_button:
		defend_button.pressed.connect(_on_defend_pressed)
		print("Defend button connected!")
	else:
		print("ERROR: Defend button not found!")
		
	if item_button:
		item_button.pressed.connect(_on_item_pressed)
		print("Item button connected!")
	else:
		print("ERROR: Item button not found!")
	
	# if target_button: # REMOVED
	# 	target_button.pressed.connect(_on_target_button_pressed) # REMOVED
	# 	print("Target button connected!") # REMOVED
	# else: # REMOVED
	# 	print("ERROR: Target button not found!") # REMOVED
	
	# Find combat manager
	combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager:
		print("Combat UI: Found combat manager!")
		combat_manager.combat_started.connect(_on_combat_started)
		combat_manager.combat_ended.connect(_on_combat_ended)
		combat_manager.turn_changed.connect(_on_turn_changed)
		combat_manager.atb_bar_updated.connect(_on_atb_bar_updated)
		combat_manager.action_queued.connect(_on_action_queued)
		combat_manager.action_dequeued.connect(_on_action_dequeued)
		
		# Connect to enemy damage events to refresh panels
		# if combat_manager.has_signal("enemy_damaged"): # REMOVED
		# 	combat_manager.enemy_damaged.connect(_on_enemy_damaged) # REMOVED
		# 	print("Combat UI: Connected to enemy damage signals!") # REMOVED
		
		print("Combat UI: Connected to combat manager signals!")
	else:
		print("WARNING: No combat manager found!")
	
	# Initialize action button mapping AFTER all buttons are connected
	call_deferred("_setup_action_button_mapping")
	
	# Add debug keyboard shortcut (F12 key)
	set_process_input(true)

func _input(event):
	"""Handle input for debug functions"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			print("F12 pressed - Debugging ATB system...")
			debug_atb_status()
		elif event.keycode == KEY_F11:
			print("F11 pressed - Checking player turn readiness...")
			check_player_turn_readiness()
		elif event.keycode == KEY_TAB:
			print("Tab pressed - Cycling target...")
			if combat_manager:
				combat_manager.cycle_target()
				print("DEBUG: Target cycling completed")
			else:
				print("DEBUG: No combat manager found!")

func check_player_turn_readiness():
	"""Check if player can take actions right now"""
	if not combat_manager:
		add_combat_log_entry("❌ No combat manager found!")
		return
	
	var atb_status = combat_manager.get_atb_status()
	if not atb_status:
		add_combat_log_entry("❌ Could not get ATB status!")
		return
	
	var can_act = combat_manager.is_player_turn_ready()
	var status_text = "🔍 Player Turn Readiness Check:\n"
	status_text += "Can take actions: " + str(can_act) + "\n"
	status_text += "Player ATB: " + str(int(atb_status.player_atb_progress * 100)) + "%\n"
	status_text += "Player ready: " + str(atb_status.player_turn_ready) + "\n"
	status_text += "Action in progress: " + str(atb_status.action_in_progress) + "\n"
	status_text += "Turn type: " + str(atb_status.turn_type)
	
	add_combat_log_entry(status_text)
	print("Player Turn Readiness: ", status_text)

func _on_combat_started():
	print("Combat UI: Combat started!")
	show()
	
	# Ensure popups are hidden when combat starts
	special_attacks_popup.hide()
	spells_popup.hide()
	
	# Clear any previous button highlights
	_clear_all_button_highlights()
	
	# Clear previous combat log
	clear_combat_log()
	
	# Reset spirit display
	update_spirit_display(0)
	
	# Update turn display
	update_turn_display()
	
	# SIMPLIFIED: Create enemy panels
	# print("DEBUG: Creating enemy panels...") # REMOVED
	# clear_enemy_panels() # REMOVED
	
	# if combat_manager: # REMOVED
	# 	var enemies = combat_manager.get_combat_enemies() # REMOVED
	# 	print("DEBUG: Found ", enemies.size(), " enemies") # REMOVED
	# 	
	# 	for enemy in enemies: # REMOVED
	# 		print("DEBUG: Creating panel for: ", enemy.name) # REMOVED
	# 		create_and_add_enemy_panel(enemy) # REMOVED
	# 	
	# 	print("DEBUG: Total panels created: ", enemy_panels_container.get_child_count()) # REMOVED
	# 	
	# 	# Highlight the focused enemy # REMOVED
	# 	highlight_focused_enemy() # REMOVED
	# else: # REMOVED
	# 	print("ERROR: No combat manager found!") # REMOVED

func update_spirit_display(_spirit_points: int):
	"""Placeholder for spirit display update"""
	pass # No longer using a Label for spirit display

func update_enemy_status(_enemy: Node):
	"""Update enemy status display - now handled by floating bars above enemy head"""
	# Enemy status is now displayed above the enemy's head via floating health/mana bars
	pass

func update_player_status(_player: Node):
	"""Placeholder for player status update"""
	pass # No longer using ProgressBars for player status

func _on_combat_ended():
	print("Combat UI: Combat ended!")
	hide()
	# Hide enemy status panel
	# hide_enemy_status_panel() # REMOVED
	# Hide any open popups
	special_attacks_popup.hide()
	spells_popup.hide()
	# Clear any queued action highlighting
	if currently_queued_action != "":
		_restore_button_appearance(currently_queued_action)
		currently_queued_action = ""

func _on_basic_attack_pressed():
	if combat_manager:
		# Always call the combat manager - it will handle queuing if needed
		combat_manager.player_basic_attack()

func _on_special_attacks_popup_pressed():
	print("Special attacks button pressed!")
	print("Popup visibility before show: ", special_attacks_popup.visible)
	special_attacks_popup.show()
	print("Popup visibility after show: ", special_attacks_popup.visible)
	print("Popup position: ", special_attacks_popup.position)
	print("Popup size: ", special_attacks_popup.size)

func _on_spells_popup_pressed():
	print("Spells button pressed!")
	print("Popup visibility before show: ", spells_popup.visible)
	spells_popup.show()
	print("Popup visibility after show: ", spells_popup.visible)
	print("Popup position: ", spells_popup.position)
	print("Popup size: ", spells_popup.size)

func _on_haymaker_pressed():
	print("Haymaker button pressed!")
	if combat_manager:
		# Always call the combat manager - it will handle queuing if needed
		combat_manager.player_special_attack()
		special_attacks_popup.hide()  # Close popup after selection
	else:
		print("ERROR: No combat manager found!")

func _on_fireball_pressed():
	print("Fireball button pressed!")
	if combat_manager:
		# Always call the combat manager - it will handle queuing if needed
		combat_manager.player_cast_spell()
		spells_popup.hide()  # Close popup after selection
	else:
		print("ERROR: No combat manager found!")

func _on_special_attacks_close_pressed():
	print("Special attacks close button pressed!")
	special_attacks_popup.hide()

func _on_spells_close_pressed():
	print("Spells close button pressed!")
	spells_popup.hide()

func _on_defend_pressed():
	if combat_manager:
		# Always call the combat manager - it will handle queuing if needed
		combat_manager.player_defend()

func _on_item_pressed():
	if combat_manager:
		# Always show inventory - combat manager will handle queuing if needed
		var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
		if inventory_ui:
			if inventory_ui.visible:
				inventory_ui.hide()
				print("Inventory UI hidden!")
			else:
				inventory_ui.show()
				print("Inventory UI shown!")
		else:
			print("No inventory UI found in 'InventoryUI' group!")
			# Try alternative group names
			var alt_inventory = get_tree().get_first_node_in_group("PlayerInventory")
			if alt_inventory:
				print("Found inventory in 'PlayerInventory' group instead")
				if alt_inventory.visible:
					alt_inventory.hide()
					print("Inventory UI hidden!")
				else:
					alt_inventory.show()
					print("Inventory UI shown!")
			else:
				print("No inventory UI found in any known groups!")

# ATB System methods
func _on_atb_bar_updated(player_progress: float, enemy_progress: float):
	"""Update ATB bars when progress changes"""
	# Clear queued action when ATB resets (goes back to 0%)
	if player_progress < 0.1 and currently_queued_action != "":
		print("ATB reset detected - clearing queued action")
		_restore_button_appearance(currently_queued_action)
		currently_queued_action = ""
		if queued_action_label:
			queued_action_label.hide()
	
	if player_atb_bar:
		player_atb_bar.value = player_progress * 100  # Convert to percentage
		# Change color when ready
		if player_progress >= 1.0:
			player_atb_bar.modulate = Color.GREEN
			atb_status_label.text = "🎯 Your turn is ready!"
		else:
			player_atb_bar.modulate = Color.WHITE
			atb_status_label.text = "⏳ ATB bar filling... (" + str(int(player_progress * 100)) + "%)"
	


func _on_turn_changed(current_actor: Node, turn_type: String):
	"""Update turn system display when turn changes"""
	var actor_name = "unknown"
	if current_actor:
		actor_name = current_actor.name
	print("Combat UI: Turn changed to ", turn_type, " for ", actor_name)
	
	# Safety check: ensure combat manager is still valid
	if not combat_manager or not is_instance_valid(combat_manager):
		print("WARNING: Combat manager is no longer valid!")
		return
		
	update_turn_display()
	
	# Refresh enemy status panel when turn changes
	# refresh_enemy_status_panel()
	pass

func update_turn_display():
	"""Update the turn system display with current information"""
	if not combat_manager:
		return
	
	var turn_info = combat_manager.get_current_turn_info()
	if not turn_info:
		return
	
	# Update turn info
	if turn_info_label:
		var actor_name = "Unknown"
		if turn_info.current_actor:
			actor_name = turn_info.current_actor.name
		var turn_type_text = turn_info.turn_type
		if turn_type_text == "player":
			turn_type_text = "Player"
		elif turn_type_text == "enemy":
			turn_type_text = "Enemy"
		turn_info_label.text = "Turn: " + actor_name + " (" + turn_type_text + ")"

# Combat log methods
func add_combat_log_entry(message: String):
	"""Add a new entry to the combat log"""
	print("=== ADDING COMBAT LOG ENTRY ===")
	print("Message: ", message)
	print("Combat log text element: ", combat_log_text)
	
	if not combat_log_text:
		print("ERROR: Combat log text element not found!")
		return
	
	print("Combat log text element is valid: ", is_instance_valid(combat_log_text))
	
	# Get current time for timestamp
	var current_time = Time.get_datetime_string_from_system()
	var time_stamp = "00:00:00"  # Default fallback
	var time_parts = current_time.split(" ")
	if time_parts.size() > 1:
		time_stamp = time_parts[1]  # Get just the time part
	
	# Format the log entry with better visual separation
	var log_entry = "[" + time_stamp + "] " + message + "\n"
	
	# Add to the beginning of the log (newest entries at top)
	var current_text = combat_log_text.text
	combat_log_text.text = log_entry + current_text
	
	# Auto-scroll to top to show newest entry
	combat_log_text.scroll_vertical = 0
	
	# Force UI update to ensure the text is displayed immediately
	combat_log_text.queue_redraw()
	
	# Limit log size to prevent memory issues (keep last 100 entries)
	var lines = combat_log_text.text.split("\n")
	if lines.size() > 100:
		var trimmed_lines = lines.slice(0, 100)
		combat_log_text.text = "\n".join(trimmed_lines)
	
	print("Combat log entry added successfully!")

func clear_combat_log():
	"""Clear the combat log"""
	if combat_log_text:
		combat_log_text.text = ""

func add_combat_log_separator():
	"""Add a visual separator in the combat log"""
	add_combat_log_entry("--- Turn Separator ---")

func debug_atb_status():
	"""Debug function to check ATB system status"""
	if not combat_manager:
		add_combat_log_entry("❌ No combat manager found!")
		return
	
	var atb_status = combat_manager.get_atb_status()
	if not atb_status:
		add_combat_log_entry("❌ Could not get ATB status!")
		return
	
	var status_text = "🔍 ATB Debug Info:\n"
	status_text += "Player Progress: " + str(int(atb_status.player_atb_progress * 100)) + "%\n"

	status_text += "Player Ready: " + str(atb_status.player_turn_ready) + "\n"
	status_text += "Enemy Ready: " + str(atb_status.enemy_turn_ready) + "\n"
	status_text += "Action in Progress: " + str(atb_status.action_in_progress) + "\n"
	status_text += "Turn Type: " + str(atb_status.turn_type) + "\n"
	status_text += "Timer Active: " + str(atb_status.atb_progress_timer_active)
	
	add_combat_log_entry(status_text)
	print("ATB Debug Info: ", atb_status)

# Queued action handlers
func _on_action_queued(action: String, data: Dictionary):
	"""Handle when an action is queued"""
	print("🎯 Action queued: ", action, " with data: ", data)
	
	if not queued_action_label:
		print("ERROR: Queued action label not found!")
		return
	
	# Map action types to specific ability names for better clarity
	var action_name = _get_action_display_name(action)
	var action_text = "⏳ Queued: " + action_name
	
	# Add item name if it's an item use action
	if data.has("item_name"):
		action_text += " (" + data["item_name"] + ")"
	
	queued_action_label.text = action_text
	queued_action_label.show()
	print("✅ Queued action indicator shown: ", action_text)
	
	# Combat log entry is now handled by the combat manager with detailed messages
	_highlight_queued_action(action)

func _get_action_display_name(action: String) -> String:
	"""Convert action type to specific ability name for better display"""
	match action:
		"basic_attack":
			return "Basic Attack"
		"special_attack":
			return "Haymaker"
		"cast_spell":
			return "Fireball"
		"defend":
			return "Defend"
		"use_item":
			return "Use Item"
		_:
			# Fallback: capitalize and replace underscores
			return action.replace("_", " ").capitalize()

func _on_action_dequeued():
	"""Handle when a queued action is executed"""
	print("🎯 Action dequeued - hiding queued action indicator")
	
	if not queued_action_label:
		print("ERROR: Queued action label not found!")
		return
	
	# Hide the queued action indicator
	queued_action_label.hide()
	print("✅ Queued action indicator hidden")
	_restore_button_appearance(currently_queued_action)

func update_button_states():
	"""Update button states based on available resources"""
	if not combat_manager or not combat_manager.current_player:
		return
	
	var player = combat_manager.current_player
	var player_stats = player.get_stats() if player.has_method("get_stats") else null
	
	if not player_stats:
		return
	
	# Get current resources
	var current_spirit = player_stats.get_spirit() if player_stats.has_method("get_spirit") else 0
	var current_mana = player_stats.mana
	var current_health = player_stats.health
	
	# Update Haymaker button (costs 3 spirit)
	if haymaker_button:
		var haymaker_cost = 3
		var can_afford_haymaker = current_spirit >= haymaker_cost
		_set_button_state(haymaker_button, can_afford_haymaker, "Haymaker", haymaker_cost, current_spirit, "SP")
	
	# Update Fireball button (costs 15 mana)
	if fireball_button:
		var fireball_cost = 15
		var can_afford_fireball = current_mana >= fireball_cost
		_set_button_state(fireball_button, can_afford_fireball, "Fireball", fireball_cost, current_mana, "MP")
	
	# Update Basic Attack button (always available)
	if basic_attack_button:
		_set_button_state(basic_attack_button, true, "Basic Attack", 0, 0, "")
	
	# Update Defend button (always available)
	if defend_button:
		_set_button_state(defend_button, true, "Defend", 0, 0, "")
	
	# Update Item button (check if player has any usable items)
	if item_button:
		var has_usable_items = _check_if_player_has_usable_items(player)
		_set_button_state(item_button, has_usable_items, "Use Item", 0, 0, "")
	
	# Update Special Attacks button (menu opener - always available)
	if special_attacks_button:
		_set_button_state(special_attacks_button, true, "Special Attacks", 0, 0, "")
	
	# Update Spells button (menu opener - always available)
	if spells_button:
		_set_button_state(spells_button, true, "Spells", 0, 0, "")

func _check_if_player_has_usable_items(_player: Node) -> bool:
	"""Check if the player has any items they can use in combat"""
	# This is a placeholder - you can expand this based on your inventory system
	# For now, assume player always has some items
	return true

func _set_button_state(button: Button, can_afford: bool, ability_name: String, cost: int, current: int, resource_type: String):
	"""Set button visual state and tooltip based on affordability"""
	if not button:
		return
	
	# Don't change button appearance if it's currently highlighted green (queued)
	if currently_queued_action != "":
		var queued_button = action_button_map.get(currently_queued_action)
		if button == queued_button:
			return
	
	# Store original state if not already stored
	if not button_states.has(button):
		button_states[button] = {
			"original_modulate": button.modulate,
			"original_disabled": button.disabled,
			"original_tooltip": button.tooltip_text
		}
	
	if can_afford:
		# Enable button and restore original appearance
		button.disabled = false
		button.modulate = button_states[button]["original_modulate"]
		button.tooltip_text = button_states[button]["original_tooltip"]
	else:
		# Disable button and make it red to show it's not usable
		button.disabled = true
		button.modulate = Color(1.0, 0.3, 0.3, 0.8)  # Red with slight transparency
		button.tooltip_text = ability_name + " (Cost: " + str(cost) + " " + resource_type + ")\nYou have: " + str(current) + " " + resource_type + "\nNot enough resources!"

func _process(_delta):
	"""Update button states every frame during combat"""
	if visible and combat_manager:
		update_button_states()

func _setup_action_button_mapping():
	"""Set up mapping between action types and their corresponding buttons"""
	print("🔧 Setting up action button mapping...")
	print("🔧 Basic attack button: ", basic_attack_button)
	print("🔧 Haymaker button: ", haymaker_button)
	print("🔧 Fireball button: ", fireball_button)
	print("🔧 Defend button: ", defend_button)
	print("🔧 Item button: ", item_button)
	
	action_button_map = {
		"basic_attack": basic_attack_button,
		"special_attack": haymaker_button,
		"cast_spell": fireball_button,
		"defend": defend_button,
		"use_item": item_button
	}
	
	print("🔧 Action button mapping set up: ", action_button_map.keys())
	for action in action_button_map.keys():
		var button = action_button_map[action]
		var button_valid = "valid" if button and is_instance_valid(button) else "null"
		print("🔧 ", action, " -> ", button, " (", button_valid, ")")

func _highlight_queued_action(action: String):
	"""Highlight the button corresponding to the queued action in green"""
	print("🔍 Attempting to highlight action: ", action)
	print("🔍 Action button map: ", action_button_map)
	print("🔍 Available actions: ", action_button_map.keys())
	
	var button = action_button_map.get(action)
	if button:
		print("✅ Found button for action: ", action, " - Button: ", button)
		# Store original state if not already stored
		if not button_states.has(button):
			button_states[button] = {
				"original_modulate": button.modulate,
				"original_disabled": button.disabled,
				"original_tooltip": button.tooltip_text
			}
			print("✅ Stored original button state for: ", action)
		
		# Turn button green to show it's queued
		button.modulate = Color(0.2, 1.0, 0.2, 1.0)  # Bright green
		print("✅ Button highlighted green for queued action: ", action)
		currently_queued_action = action # Update the currently queued action
	else:
		print("⚠️ No button found for action: ", action)
		print("⚠️ Available actions in map: ", action_button_map.keys())
		print("⚠️ Requested action: ", action)

func _restore_button_appearance(action: String):
	"""Restore the button appearance when action is dequeued"""
	var button = action_button_map.get(action)
	if button and button_states.has(button):
		# Check if the button should actually be red (not usable)
		var should_be_red = _should_button_be_red(button, action)
		if should_be_red:
			# Button should be red because it's not usable
			button.modulate = Color(1.0, 0.3, 0.3, 0.8)
		else:
			# Restore original appearance
			button.modulate = button_states[button]["original_modulate"]
		print("✅ Button appearance restored for action: ", action)
	else:
		print("⚠️ Could not restore button appearance for action: ", action)

func _should_button_be_red(_button: Button, action: String) -> bool:
	"""Check if a button should be red based on current resource availability"""
	if not combat_manager or not combat_manager.current_player:
		return false
	
	var player = combat_manager.current_player
	var player_stats = player.get_stats() if player.has_method("get_stats") else null
	
	if not player_stats:
		return false
	
	var current_spirit = player_stats.get_spirit() if player_stats.has_method("get_spirit") else 0
	var current_mana = player_stats.mana
	
	# Check specific actions for resource requirements
	# Note: Menu opener buttons (Special Attacks, Spells) are never red
	match action:
		"special_attack":
			return current_spirit < 3  # Haymaker costs 3 spirit
		"cast_spell":
			return current_mana < 15  # Fireball costs 15 mana
		_:
			return false  # Other actions (including menu openers) are always available

func _clear_all_button_highlights():
	"""Clear all button highlights - useful for resetting state"""
	for action in action_button_map.keys():
		var button = action_button_map[action]
		if button and button_states.has(button):
			# Check if button should be red (not usable)
			var should_be_red = _should_button_be_red(button, action)
			if should_be_red:
				button.modulate = Color(1.0, 0.3, 0.3, 0.8)
			else:
				button.modulate = button_states[button]["original_modulate"]
	currently_queued_action = ""

# Enemy Status Panel Methods - REMOVED
# func show_enemy_status_panel(): # REMOVED
# 	"""Show the enemy status panel""" # REMOVED
# 	print("DEBUG: show_enemy_status_panel called") # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: Enemy panels container is null!") # REMOVED
# 		return # REMOVED
# 		
# 	print("DEBUG: Enemy panels container found, showing it...") # REMOVED
# 	enemy_panels_container.show() # REMOVED
# 	print("DEBUG: Enemy panels container shown, visible: ", enemy_panels_container.visible) # REMOVED
# 	print("DEBUG: Enemy panels container position: ", enemy_panels_container.position) # REMOVED
# 	print("DEBUG: Enemy panels container size: ", enemy_panels_container.size) # REMOVED
# 	print("DEBUG: Enemy panels container global position: ", enemy_panels_container.global_position) # REMOVED
# 	print("DEBUG: Enemy panels container has ", enemy_panels_container.get_child_count(), " children") # REMOVED
# 	print("Combat UI: Enemy panels container shown") # REMOVED

# func hide_enemy_status_panel(): # REMOVED
# 	"""Hide the enemy status panel""" # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: Enemy panels container is null!") # REMOVED
# 		return # REMOVED
# 		
# 	enemy_panels_container.hide() # REMOVED
# 	print("Combat UI: Enemy panels container hidden") # REMOVED

# Multi-Enemy Panel System - REMOVED
# func create_and_add_enemy_panel(enemy: Node): # REMOVED
# 	"""Create and add an enemy panel in one simple step""" # REMOVED
# 	print("DEBUG: === create_and_add_enemy_panel START ===") # REMOVED
# 	
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: No enemy panels container!") # REMOVED
# 		return # REMOVED
# 	
# 	# Create panel directly in code instead of using template # REMOVED
# 	var panel = Panel.new() # REMOVED
# 	panel.custom_minimum_size = Vector2(220, 90) # REMOVED
# 	panel.name = "EnemyPanel_" + enemy.name # REMOVED
# 	
# 	# Apply panel style # REMOVED
# 	panel.add_theme_stylebox_override("panel", create_panel_style()) # REMOVED
# 	
# 	# Create main container # REMOVED
# 	var vbox = VBoxContainer.new() # REMOVED
# 	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # REMOVED
# 	vbox.offset_left = 10 # REMOVED
# 	vbox.offset_top = 8 # REMOVED
# 	vbox.offset_right = -10 # REMOVED
# 	vbox.offset_bottom = -8 # REMOVED
# 	vbox.add_theme_constant_override("separation", 4) # REMOVED
# 	panel.add_child(vbox) # REMOVED
# 	
# 	# Create enemy name label # REMOVED
# 	var name_label = Label.new() # REMOVED
# 	name_label.text = enemy.name # REMOVED
# 	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # REMOVED
# 	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER # REMOVED
# 	name_label.custom_minimum_size = Vector2(0, 20) # REMOVED
# 	name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1)) # REMOVED
# 	name_label.add_theme_font_size_override("font_size", 14) # REMOVED
# 	vbox.add_child(name_label) # REMOVED
# 	
# 	# Create separator # REMOVED
# 	var separator = HSeparator.new() # REMOVED
# 	separator.custom_minimum_size = Vector2(0, 2) # REMOVED
# 	vbox.add_child(separator) # REMOVED
# 	
# 	# Create bars container # REMOVED
# 	var bars_container = VBoxContainer.new() # REMOVED
# 	bars_container.add_theme_constant_override("separation", 6) # REMOVED
# 	vbox.add_child(bars_container) # REMOVED
# 	
# 	# Create health section # REMOVED
# 	var health_section = VBoxContainer.new() # REMOVED
# 	health_section.add_theme_constant_override("separation", 2) # REMOVED
# 	bars_container.add_child(health_section) # REMOVED
# 	
# 	# Create health bar # REMOVED
# 	var health_bar = Panel.new() # REMOVED
# 	health_bar.custom_minimum_size = Vector2(0, 18) # REMOVED
# 	health_bar.add_theme_stylebox_override("panel", create_health_bar_style()) # REMOVED
# 	health_section.add_child(health_bar) # REMOVED
# 	
# 	# Create health fill # REMOVED
# 	var health_fill = Panel.new() # REMOVED
# 	health_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # REMOVED
# 	health_fill.offset_left = 1 # REMOVED
# 	health_fill.offset_top = 1 # REMOVED
# 	health_fill.offset_right = -1 # REMOVED
# 	health_fill.offset_bottom = -1 # REMOVED
# 	health_fill.add_theme_stylebox_override("panel", create_health_fill_style()) # REMOVED
# 	health_bar.add_child(health_fill) # REMOVED
# 	
# 	# Create health value label # REMOVED
# 	var health_value = Label.new() # REMOVED
# 	health_value.text = "100/100" # REMOVED
# 	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # REMOVED
# 	health_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER # REMOVED
# 	health_value.add_theme_color_override("font_color", Color(1, 1, 1, 1)) # REMOVED
# 	health_value.add_theme_font_size_override("font_size", 10) # REMOVED
# 	health_bar.add_child(health_value) # REMOVED
# 	
# 	# Create mana section # REMOVED
# 	var mana_section = VBoxContainer.new() # REMOVED
# 	mana_section.add_theme_constant_override("separation", 2) # REMOVED
# 	bars_container.add_child(mana_section) # REMOVED
# 	
# 	# Create mana bar # REMOVED
# 	var mana_bar = Panel.new() # REMOVED
# 	mana_bar.custom_minimum_size = Vector2(0, 18) # REMOVED
# 	mana_bar.add_theme_stylebox_override("panel", create_mana_bar_style()) # REMOVED
# 	mana_section.add_child(mana_bar) # REMOVED
# 	
# 	# Create mana fill # REMOVED
# 	var mana_fill = Panel.new() # REMOVED
# 	mana_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # REMOVED
# 	mana_fill.offset_left = 1 # REMOVED
# 	mana_fill.offset_top = 1 # REMOVED
# 	mana_fill.offset_right = -1 # REMOVED
# 	mana_fill.offset_bottom = -1 # REMOVED
# 	mana_fill.add_theme_stylebox_override("panel", create_mana_fill_style()) # REMOVED
# 	mana_bar.add_child(mana_fill) # REMOVED
# 	
# 	# Create mana value label # REMOVED
# 	var mana_value = Label.new() # REMOVED
# 	health_value.text = "50/50" # REMOVED
# 	mana_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # REMOVED
# 	mana_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER # REMOVED
# 	mana_value.add_theme_color_override("font_color", Color(1, 1, 1, 1)) # REMOVED
# 	mana_value.add_theme_font_size_override("font_size", 10) # REMOVED
# 	mana_bar.add_child(mana_value) # REMOVED
# 	
# 	# Store references to the nodes we need to update # REMOVED
# 	panel.set_meta("name_label", name_label) # REMOVED
# 	panel.set_meta("health_value", health_value) # REMOVED
# 	panel.set_meta("mana_value", mana_value) # REMOVED
# 	panel.set_meta("health_fill", health_fill) # REMOVED
# 	panel.set_meta("mana_fill", mana_fill) # REMOVED
# 	
# 	# Store enemy reference # REMOVED
# 	panel.set_meta("enemy", enemy) # REMOVED
# 	
# 	# Add to container # REMOVED
# 	enemy_panels_container.add_child(panel) # REMOVED
# 	
# 	# Update immediately # REMOVED
# 	update_enemy_panel(panel, enemy) # REMOVED
# 	
# 	print("DEBUG: Panel created and added for: ", enemy.name) # REMOVED
# 	print("DEBUG: Container now has ", enemy_panels_container.get_child_count(), " children") # REMOVED
# 	print("DEBUG: === create_and_add_enemy_panel COMPLETE ===") # REMOVED

# func create_panel_style() -> StyleBoxFlat: # REMOVED
# 	var style = StyleBoxFlat.new() # REMOVED
# 	style.bg_color = Color(0.2, 0.2, 0.25, 1.0) # REMOVED
# 	style.border_color = Color(0.4, 0.4, 0.5, 1.0) # REMOVED
# 	style.border_width_left = 1 # REMOVED
# 	style.border_width_right = 1 # REMOVED
# 	style.border_width_top = 1 # REMOVED
# 	style.border_width_bottom = 1 # REMOVED
# 	style.corner_radius_top_left = 3 # REMOVED
# 	style.corner_radius_top_right = 3 # REMOVED
# 	style.corner_radius_bottom_left = 3 # REMOVED
# 	style.corner_radius_bottom_right = 3 # REMOVED
# 	return style # REMOVED

# func create_health_bar_style() -> StyleBoxFlat: # REMOVED
# 	var style = StyleBoxFlat.new() # REMOVED
# 	style.bg_color = Color(0.2, 0.2, 0.25, 1.0) # REMOVED
# 	style.border_color = Color(0.4, 0.4, 0.5, 1.0) # REMOVED
# 	style.border_width_left = 1 # REMOVED
# 	style.border_width_right = 1 # REMOVED
# 	style.border_width_top = 1 # REMOVED
# 	style.border_width_bottom = 1 # REMOVED
# 	style.corner_radius_top_left = 3 # REMOVED
# 	style.corner_radius_top_right = 3 # REMOVED
# 	style.corner_radius_bottom_left = 3 # REMOVED
# 	style.corner_radius_bottom_right = 3 # REMOVED
# 	return style # REMOVED

# func create_health_fill_style() -> StyleBoxFlat: # REMOVED
# 	var style = StyleBoxFlat.new() # REMOVED
# 	style.bg_color = Color(1.0, 0.3, 0.3, 1.0)  # Red # REMOVED
# 	style.corner_radius_top_left = 2 # REMOVED
# 	style.corner_radius_top_right = 2 # REMOVED
# 	style.corner_radius_bottom_left = 2 # REMOVED
# 	style.corner_radius_bottom_right = 2 # REMOVED
# 	return style # REMOVED

# func create_mana_bar_style() -> StyleBoxFlat: # REMOVED
# 	var style = StyleBoxFlat.new() # REMOVED
# 	style.bg_color = Color(0.2, 0.2, 0.25, 1.0) # REMOVED
# 	style.border_color = Color(0.4, 0.4, 0.5, 1.0) # REMOVED
# 	style.border_width_left = 1 # REMOVED
# 	style.border_width_right = 1 # REMOVED
# 	style.border_width_top = 1 # REMOVED
# 	style.border_width_bottom = 1 # REMOVED
# 	style.corner_radius_top_left = 3 # REMOVED
# 	style.corner_radius_top_right = 3 # REMOVED
# 	style.corner_radius_bottom_left = 3 # REMOVED
# 	style.corner_radius_bottom_right = 3 # REMOVED
# 	return style # REMOVED

# func create_mana_fill_style() -> StyleBoxFlat: # REMOVED
# 	var style = StyleBoxFlat.new() # REMOVED
# 	style.bg_color = Color(0.3, 0.6, 1.0, 1.0)  # Blue # REMOVED
# 	style.corner_radius_top_left = 2 # REMOVED
# 	style.corner_radius_top_right = 2 # REMOVED
# 	style.corner_radius_bottom_left = 2 # REMOVED
# 	style.corner_radius_bottom_right = 2 # REMOVED
# 	return style # REMOVED

# func update_enemy_panel(panel: Control, enemy: Node): # REMOVED
# 	"""Update an individual enemy panel with current data""" # REMOVED
# 	print("DEBUG: Updating panel for enemy: ", enemy.name) # REMOVED
# 	
# 	if not panel or not enemy or not is_instance_valid(enemy): # REMOVED
# 		print("DEBUG: Invalid panel or enemy, returning") # REMOVED
# 		return # REMOVED
# 	
# 	# Get the nodes from metadata # REMOVED
# 	var name_label = panel.get_meta("name_label") # REMOVED
# 	var health_value = panel.get_meta("health_value") # REMOVED
# 	var mana_value = panel.get_meta("mana_value") # REMOVED
# 	var health_fill = panel.get_meta("health_fill") # REMOVED
# 	var mana_fill = panel.get_meta("mana_fill") # REMOVED
# 	
# 	# Check if all required nodes exist # REMOVED
# 	if not name_label or not health_value or not mana_value or not health_fill or not mana_fill: # REMOVED
# 		print("ERROR: Missing required nodes in panel!") # REMOVED
# 		return # REMOVED
# 	
# 	# Set enemy name # REMOVED
# 	name_label.text = enemy.name # REMOVED
# 	
# 	# Try to get enemy stats # REMOVED
# 	var enemy_stats = null # REMOVED
# 	if enemy.has_method("get_stats"): # REMOVED
# 		enemy_stats = enemy.get_stats() # REMOVED
# 	elif enemy.has_method("stats"): # REMOVED
# 		enemy_stats = enemy.stats # REMOVED
# 	
# 	if enemy_stats: # REMOVED
# 		# Update health # REMOVED
# 		var _current_health = enemy_stats.health if "health" in enemy_stats else 100 # REMOVED
# 		var max_health = enemy_stats.max_health if "max_health" in enemy_stats else 100 # REMOVED
# 		
# 		health_value.text = str(_current_health) + "/" + str(max_health) # REMOVED
# 		
# 		# Calculate health percentage and set alpha for visual effect # REMOVED
# 		var health_percent = float(_current_health) / float(max_health) # REMOVED
# 		health_fill.modulate.a = health_percent # REMOVED
# 		
# 		# Update mana # REMOVED
# 		var current_mana = enemy_stats.mana if "mana" in enemy_stats else 50 # REMOVED
# 		var max_mana = enemy_stats.max_mana if "max_mana" in enemy_stats else 50 # REMOVED
# 	
# 		mana_value.text = str(current_mana) + "/" + str(max_mana) # REMOVED
# 		
# 		# Calculate mana percentage and set alpha for visual effect # REMOVED
# 		var mana_percent = float(current_mana) / float(max_mana) # REMOVED
# 		mana_fill.modulate.a = mana_percent # REMOVED
# 		
# 		print("DEBUG: Panel updated successfully for: ", enemy.name) # REMOVED
# 	else: # REMOVED
# 		print("WARNING: No enemy stats found for: ", enemy.name) # REMOVED
# 		# Set default values # REMOVED
# 		health_value.text = "100/100" # REMOVED
# 		mana_value.text = "50/50" # REMOVED
# 		health_fill.modulate.a = 1.0 # REMOVED
# 		mana_fill.modulate.a = 1.0 # REMOVED

# func refresh_all_enemy_panels(): # REMOVED
# 	"""Refresh all enemy panels with current data - SIMPLIFIED""" # REMOVED
# 	print("DEBUG: refresh_all_enemy_panels called") # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: enemy_panels_container is null!") # REMOVED
# 		return # REMOVED
# 	
# 	print("DEBUG: Refreshing ", enemy_panels_container.get_child_count(), " enemy panels") # REMOVED
# 	
# 	for child in enemy_panels_container.get_children(): # REMOVED
# 		if child.has_meta("enemy"): # REMOVED
# 			var enemy = child.get_meta("enemy") # REMOVED
# 			if enemy and is_instance_valid(enemy): # REMOVED
# 				update_enemy_panel(child, enemy) # REMOVED
# 			else: # REMOVED
# 				print("DEBUG: Enemy is invalid, removing panel") # REMOVED
# 				child.queue_free() # REMOVED

# func clear_enemy_panels(): # REMOVED
# 	"""Clear all enemy panels from the container""" # REMOVED
# 	print("DEBUG: Clearing enemy panels...") # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: enemy_panels_container is null!") # REMOVED
# 		return # REMOVED
# 	
# 	for child in enemy_panels_container.get_children(): # REMOVED
# 		child.queue_free() # REMOVED
# 	print("DEBUG: All enemy panels cleared") # REMOVED

# func add_enemy_panel(enemy: Node): # REMOVED
# 	"""Add an enemy panel to the container - DEPRECATED, use create_and_add_enemy_panel instead""" # REMOVED
# 	print("WARNING: add_enemy_panel is deprecated, use create_and_add_enemy_panel instead") # REMOVED
# 	create_and_add_enemy_panel(enemy) # REMOVED

# func remove_enemy_panel(enemy: Node): # REMOVED
# 	"""Remove an enemy panel from the container""" # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: Enemy panels container is null!") # REMOVED
# 		return # REMOVED
# 		
# 	for child in enemy_panels_container.get_children(): # REMOVED
# 		if child.has_meta("enemy") and child.get_meta("enemy") == enemy: # REMOVED
# 			child.queue_free() # REMOVED
# 			print("Combat UI: Removed enemy panel for: ", enemy.name) # REMOVED
# 			break # REMOVED

# func highlight_focused_enemy(): # REMOVED
# 	"""Highlight the currently focused enemy panel""" # REMOVED
# 	if not enemy_panels_container or not combat_manager: # REMOVED
# 		print("DEBUG: Cannot highlight - container or combat manager missing") # REMOVED
# 		return # REMOVED
# 	
# 	var focused_enemy = combat_manager.get_focused_enemy() # REMOVED
# 	if not focused_enemy: # REMOVED
# 		print("DEBUG: No focused enemy to highlight") # REMOVED
# 		return # REMOVED
# 	
# 	print("DEBUG: Highlighting focused enemy: ", focused_enemy.name) # REMOVED
# 	print("DEBUG: Total enemy panels: ", enemy_panels_container.get_child_count()) # REMOVED
# 	
# 	# Reset all panels to normal appearance # REMOVED
# 	for child in enemy_panels_container.get_children(): # REMOVED
# 		if child.has_meta("enemy"): # REMOVED
# 			apply_focus_glow(child, false) # REMOVED
# 			print("DEBUG: Reset panel for: ", child.get_meta("enemy").name) # REMOVED
# 	
# 	# Highlight the focused enemy panel # REMOVED
# 	for child in enemy_panels_container.get_children(): # REMOVED
# 		if child.has_meta("enemy") and child.get_meta("enemy") == focused_enemy: # REMOVED
# 			apply_focus_glow(child, true) # REMOVED
# 			print("DEBUG: Focused panel for: ", focused_enemy.name) # REMOVED
# 			break # REMOVED

# func apply_focus_glow(panel: Control, is_focused: bool): # REMOVED
# 	"""Apply or remove focus glow effect to an enemy panel""" # REMOVED
# 	print("DEBUG: apply_focus_glow called for panel: ", panel.name, " focused: ", is_focused) # REMOVED
# 	
# 	if not panel: # REMOVED
# 		print("DEBUG: Panel is null, returning") # REMOVED
# 		return # REMOVED
# 	
# 	var style = panel.get_theme_stylebox("panel") # REMOVED
# 	if not style: # REMOVED
# 		print("DEBUG: No panel style found, creating new one") # REMOVED
# 	# Create a new style if none exists # REMOVED
# 	style = StyleBoxFlat.new() # REMOVED
# 	panel.add_theme_stylebox_override("panel", style) # REMOVED
# 	
# 	print("DEBUG: Style found, applying focus glow: ", is_focused) # REMOVED
# 	
# 	if is_focused: # REMOVED
# 		# Apply glowing blue border for focus # REMOVED
# 		style.border_color = Color(0.2, 0.8, 1.0, 1.0)  # Bright cyan # REMOVED
# 		style.border_width_left = 3 # REMOVED
# 		style.border_width_right = 3 # REMOVED
# 		style.border_width_top = 3 # REMOVED
# 		style.border_width_bottom = 3 # REMOVED
# 		# Add a subtle glow effect # REMOVED
# 		style.shadow_color = Color(0.2, 0.8, 1.0, 0.3) # REMOVED
# 		style.shadow_size = 4 # REMOVED
# 		style.shadow_offset = Vector2(0, 0) # REMOVED
# 		print("DEBUG: Applied focus glow - cyan border with shadow") # REMOVED
# 	else: # REMOVED
# 		# Reset to normal appearance # REMOVED
# 		style.border_color = Color(0.6, 0.6, 0.8, 1.0)  # Normal blue # REMOVED
# 		style.border_width_left = 2 # REMOVED
# 		style.border_width_right = 2 # REMOVED
# 		style.border_width_top = 2 # REMOVED
# 		style.border_width_bottom = 2 # REMOVED
# 		# Remove glow effect # REMOVED
# 		style.shadow_size = 0 # REMOVED
# 		print("DEBUG: Reset to normal appearance") # REMOVED
# 	
# 	# Force the style update # REMOVED
# 	panel.queue_redraw() # REMOVED
# 	print("DEBUG: Panel redraw queued") # REMOVED

# func on_enemy_joined_combat(enemy: Node): # REMOVED
# 	"""Called when an enemy joins ongoing combat""" # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: Enemy panels container is null!") # REMOVED
# 		return # REMOVED
# 	
# 	# Check if panel already exists for this enemy # REMOVED
# 	for child in enemy_panels_container.get_children(): # REMOVED
# 		if child.has_meta("enemy") and child.get_meta("enemy") == enemy: # REMOVED
# 			return  # Panel already exists # REMOVED
# 	
# 	# Add new panel for the enemy # REMOVED
# 	add_enemy_panel(enemy) # REMOVED
# 	# Refresh highlighting # REMOVED
# 	highlight_focused_enemy() # REMOVED

# func on_enemy_removed_from_combat(enemy: Node): # REMOVED
# 	"""Called when an enemy is removed from combat""" # REMOVED
# 	if not enemy_panels_container: # REMOVED
# 		print("ERROR: Enemy panels container is null!") # REMOVED
# 		return # REMOVED
# 		
# 	remove_enemy_panel(enemy) # REMOVED
# 	# Refresh highlighting # REMOVED
# 	highlight_focused_enemy() # REMOVED
