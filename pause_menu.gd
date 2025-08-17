extends CanvasLayer
class_name PauseMenu

@onready var pause_panel: Panel = $PausePanel
@onready var restart_button: Button = $PausePanel/VBoxContainer/RestartButton
@onready var quit_button: Button = $PausePanel/VBoxContainer/QuitButton

var is_paused: bool = false

func _ready():
	print("PauseMenu: _ready() called")
	
	# Debug: Check if nodes are found
	if not pause_panel:
		printerr("PauseMenu: pause_panel not found!")
		return
	if not restart_button:
		printerr("PauseMenu: restart_button not found!")
		return
	if not quit_button:
		printerr("PauseMenu: quit_button not found!")
		return
	
	print("PauseMenu: All nodes found successfully")
	
	# Hide the pause menu initially and ensure it's hidden
	pause_panel.visible = false
	pause_panel.modulate.a = 1.0  # Ensure full opacity
	print("PauseMenu: Pause panel hidden on startup")
	
	# Connect button signals
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Debug: Confirm connections
	print("PauseMenu: Buttons connected successfully")
	
	# Ensure this node can process input always, even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add to group for easy finding
	add_to_group("PauseMenu")
	
	# Debug: Print process mode to confirm
	print("PauseMenu: Process mode set to: ", process_mode)
	print("PauseMenu: _ready() completed successfully")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("PauseMenu: ESC key detected!")
		_handle_escape_press()
	else:
		# Debug: print all input events to see what's happening
		if event is InputEventKey:
			print("PauseMenu: Key event - ", event.keycode, " pressed: ", event.pressed)

func _handle_escape_press():
	"""Handle ESC key press - close open windows or show pause menu"""
	print("PauseMenu: _handle_escape_press() called")
	
	# Check if we're in combat - if so, allow pause menu to show
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	var in_combat = false
	if combat_manager and combat_manager.has_method("is_combat_active"):
		in_combat = combat_manager.is_combat_active()
	
	print("PauseMenu: In combat: ", in_combat)
	
	# Check if any UI windows are open
	var any_ui_open = _check_for_open_ui()
	print("PauseMenu: Any UI open: ", any_ui_open)
	
	if any_ui_open and not in_combat:
		# Close the open UI window and STOP HERE - don't show pause menu
		# But if we're in combat, allow pause menu to show even with UI open
		print("PauseMenu: Closing open UI...")
		_close_open_ui()
		# Don't proceed to pause menu - just close the UI and return
		return
	else:
		# No UI open OR we're in combat - toggle pause menu
		print("PauseMenu: No UI open or in combat, toggling pause menu...")
		_toggle_pause_menu()

func _check_for_open_ui() -> bool:
	"""Check if any UI windows are currently open"""
	print("PauseMenu: Checking for open UI windows...")
	
	# Check equipment UI
	var equipment_uis = get_tree().get_nodes_in_group("EquipmentUI")
	print("PauseMenu: Equipment UIs found: ", equipment_uis.size())
	for i in range(equipment_uis.size()):
		var ui = equipment_uis[i]
		print("PauseMenu: Equipment UI ", i, " - name: ", ui.name, " visible: ", ui.visible, " parent: ", ui.get_parent().name if ui.get_parent() else "no parent")
		# Check if ANY equipment UI is visible
		if ui.visible:
			print("PauseMenu: Equipment UI ", i, " is open")
			return true
	
	# Check inventory UI
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	print("PauseMenu: Inventory UI found: ", inventory_ui != null)
	if inventory_ui:
		print("PauseMenu: Inventory UI visible: ", inventory_ui.visible)
		print("PauseMenu: Inventory UI name: ", inventory_ui.name)
		if inventory_ui.visible:
			print("PauseMenu: Inventory UI is open")
			return true
	
	# Check combat UI
	var combat_ui = get_tree().get_first_node_in_group("CombatUI")
	print("PauseMenu: Combat UI found: ", combat_ui != null)
	if combat_ui:
		print("PauseMenu: Combat UI visible: ", combat_ui.visible)
		if combat_ui.visible:
			print("PauseMenu: Combat UI is open")
			return true
	
	# Check tooltip manager
	var tooltip_manager = get_tree().get_first_node_in_group("TooltipManager")
	print("PauseMenu: Tooltip manager found: ", tooltip_manager != null)
	if tooltip_manager:
		print("PauseMenu: Tooltip manager visible: ", tooltip_manager.tooltip_visible)
		if tooltip_manager.tooltip_visible:
			print("PauseMenu: Tooltip manager is open")
			return true
	
	print("PauseMenu: No UI windows are open")
	return false

func _close_open_ui():
	"""Close any currently open UI windows"""
	print("PauseMenu: _close_open_ui() called")
	
	# Close equipment UI
	var equipment_uis = get_tree().get_nodes_in_group("EquipmentUI")
	for ui in equipment_uis:
		if ui.visible:
			print("PauseMenu: Closing equipment UI: ", ui.name)
			ui.visible = false
			if ui.has_method("_update_cursor_mode"):
				ui._update_cursor_mode()
			return
	
	# Close inventory UI
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and inventory_ui.visible:
		print("PauseMenu: Closing inventory UI")
		inventory_ui.visible = false
		inventory_ui._update_cursor_mode()
		return
	
	# Close combat UI
	var combat_ui = get_tree().get_first_node_in_group("CombatUI")
	if combat_ui and combat_ui.visible:
		print("PauseMenu: Combat UI is open but won't be closed during combat")
		# Don't close combat UI during combat - just return
		return
	
	# Close tooltip
	var tooltip_manager = get_tree().get_first_node_in_group("TooltipManager")
	if tooltip_manager and tooltip_manager.tooltip_visible:
		print("PauseMenu: Closing tooltip manager")
		tooltip_manager.force_cleanup()
		return

func _toggle_pause_menu():
	"""Toggle the pause menu on/off"""
	# Safety check
	if not pause_panel:
		printerr("PauseMenu: Cannot toggle menu - pause_panel is null!")
		return
		
	is_paused = !is_paused
	
	if is_paused:
		_show_pause_menu()
	else:
		_hide_pause_menu()

func _show_pause_menu():
	"""Show the pause menu and pause the game"""
	if not pause_panel:
		printerr("PauseMenu: Cannot show menu - pause_panel is null!")
		return
		
	pause_panel.visible = true
	
	# Pause the game
	get_tree().paused = true
	
	# Show cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Focus the restart button (with safety check)
	if restart_button:
		restart_button.grab_focus()
	else:
		printerr("PauseMenu: Cannot focus restart button - button is null!")

func _hide_pause_menu():
	"""Hide the pause menu and resume the game"""
	if not pause_panel:
		printerr("PauseMenu: Cannot hide menu - pause_panel is null!")
		return
		
	pause_panel.visible = false
	
	# Resume the game
	get_tree().paused = false
	
	# Restore appropriate cursor mode based on game state
	var should_show_cursor = false
	
	# Check if we're in combat - if so, keep cursor visible for UI interaction
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager and combat_manager.has_method("is_combat_active"):
		if combat_manager.is_combat_active():
			should_show_cursor = true
			print("PauseMenu: Combat active - keeping cursor visible")
	
	# Check if any UI windows are open that need cursor
	if not should_show_cursor:
		var equipment_uis = get_tree().get_nodes_in_group("EquipmentUI")
		for ui in equipment_uis:
			if ui.visible:
				should_show_cursor = true
				print("PauseMenu: Equipment UI open - keeping cursor visible")
				break
		
		var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
		if inventory_ui and inventory_ui.visible:
			should_show_cursor = true
			print("PauseMenu: Inventory UI open - keeping cursor visible")
	
	# Set cursor mode
	if should_show_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("PauseMenu: Restored cursor to VISIBLE mode")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("PauseMenu: Restored cursor to CAPTURED mode")

func _on_restart_pressed():
	"""Restart the game"""
	print("PauseMenu: Restart button pressed!")
	# Unpause first
	get_tree().paused = false
	
	# Reload the current scene
	get_tree().reload_current_scene()

func _on_quit_pressed():
	"""Quit the game"""
	print("PauseMenu: Quit button pressed!")
	get_tree().quit()

func force_hide():
	"""Force hide the pause menu (called by other systems)"""
	_hide_pause_menu()
