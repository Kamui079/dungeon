extends CanvasLayer

class_name CombatUI

@onready var basic_attack_button: Button = $CombatPanel/VBoxContainer/ActionsSection/BasicAttackButton
@onready var special_attacks_button: Button = $CombatPanel/VBoxContainer/SpecialAttacksButton
@onready var spells_button: Button = $CombatPanel/VBoxContainer/SpellsButton
@onready var defend_button: Button = $CombatPanel/VBoxContainer/ActionsSection/DefendButton
@onready var item_button: Button = $CombatPanel/VBoxContainer/ActionsSection/ItemButton

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
@onready var enemy_atb_bar: ProgressBar = $CombatPanel/VBoxContainer/ATBSection/EnemyATBBar
@onready var atb_status_label: Label = $CombatPanel/VBoxContainer/ATBSection/ATBStatusLabel

# Combat log
@onready var combat_log_text: TextEdit = $CombatLogPanel/VBoxContainer/CombatLogText

# Enemy status elements - removed from UI, now displayed above enemy head
# @onready var enemy_name_label: Label = $CombatPanel/VBoxContainer/EnemyStatusSection/EnemyNameLabel

var combat_manager: Node = null

func _ready():
	print("=== COMBAT UI READY ===")
	# Add to CombatUI group for spirit updates
	add_to_group("CombatUI")
	
	# Start hidden
	hide()
	
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
	
	# Find combat manager
	combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager:
		print("Combat UI: Found combat manager!")
		combat_manager.combat_started.connect(_on_combat_started)
		combat_manager.combat_ended.connect(_on_combat_ended)
		combat_manager.turn_changed.connect(_on_turn_changed)
		combat_manager.atb_bar_updated.connect(_on_atb_bar_updated)
		print("Combat UI: Connected to combat manager signals!")
	else:
		print("WARNING: No combat manager found!")
	
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
	# Clear previous combat log
	clear_combat_log()
	# Reset spirit display
	update_spirit_display(0)
	# Update turn display
	update_turn_display()

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
	# Hide any open popups
	special_attacks_popup.hide()
	spells_popup.hide()

func _on_basic_attack_pressed():
	if combat_manager:
		# Check if player's turn is ready
		if combat_manager.is_player_turn_ready():
			combat_manager.player_basic_attack()
		else:
			print("Player turn not ready yet! ATB bar still filling...")
			add_combat_log_entry("⚠️ Wait for your ATB bar to fill up!")

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
		# Check if player's turn is ready
		if combat_manager.is_player_turn_ready():
			combat_manager.player_special_attack()
			special_attacks_popup.hide()  # Close popup after selection
		else:
			print("Player turn not ready yet! ATB bar still filling...")
			add_combat_log_entry("⚠️ Wait for your ATB bar to fill up!")
			special_attacks_popup.hide()
	else:
		print("ERROR: No combat manager found!")

func _on_fireball_pressed():
	print("Fireball button pressed!")
	if combat_manager:
		# Check if player's turn is ready
		if combat_manager.is_player_turn_ready():
			combat_manager.player_cast_spell()
			spells_popup.hide()  # Close popup after selection
		else:
			print("Player turn not ready yet! ATB bar still filling...")
			add_combat_log_entry("⚠️ Wait for your ATB bar to fill up!")
			spells_popup.hide()
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
		# Check if player's turn is ready
		if combat_manager.is_player_turn_ready():
			combat_manager.player_defend()
		else:
			print("Player turn not ready yet! ATB bar still filling...")
			add_combat_log_entry("⚠️ Wait for your ATB bar to fill up!")

func _on_item_pressed():
	if combat_manager:
		# Check if player's turn is ready
		if combat_manager.is_player_turn_ready():
			# Toggle the inventory UI
			var inventory_ui = get_tree().get_first_node_in_group("InventoryUIGroup")
			if inventory_ui:
				if inventory_ui.visible:
					inventory_ui.hide()
					print("Inventory UI hidden!")
				else:
					inventory_ui.show()
					print("Inventory UI shown!")
			else:
				print("No inventory UI found!")
		else:
			print("Player turn not ready yet! ATB bar still filling...")
			add_combat_log_entry("⚠️ Wait for your ATB bar to fill up!")

# ATB System methods
func _on_atb_bar_updated(player_progress: float, enemy_progress: float):
	"""Update ATB bars when progress changes"""
	print("ATB Update - Player: ", int(player_progress * 100), "%, Enemy: ", int(enemy_progress * 100), "%")
	
	if player_atb_bar:
		player_atb_bar.value = player_progress * 100  # Convert to percentage
		# Change color when ready
		if player_progress >= 1.0:
			player_atb_bar.modulate = Color.GREEN
			atb_status_label.text = "🎯 Your turn is ready!"
		else:
			player_atb_bar.modulate = Color.WHITE
			atb_status_label.text = "⏳ ATB bar filling... (" + str(int(player_progress * 100)) + "%)"
	
	if enemy_atb_bar:
		enemy_atb_bar.value = enemy_progress * 100  # Convert to percentage
		# Change color when ready
		if enemy_progress >= 1.0:
			enemy_atb_bar.modulate = Color.RED
		else:
			enemy_atb_bar.modulate = Color.WHITE

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
	
	print("Turn display updated!")

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
	status_text += "Enemy Progress: " + str(int(atb_status.enemy_atb_progress * 100)) + "%\n"
	status_text += "Player Ready: " + str(atb_status.player_turn_ready) + "\n"
	status_text += "Enemy Ready: " + str(atb_status.enemy_turn_ready) + "\n"
	status_text += "Action in Progress: " + str(atb_status.action_in_progress) + "\n"
	status_text += "Turn Type: " + str(atb_status.turn_type) + "\n"
	status_text += "Timer Active: " + str(atb_status.atb_progress_timer_active)
	
	add_combat_log_entry(status_text)
	print("ATB Debug Info: ", atb_status)
