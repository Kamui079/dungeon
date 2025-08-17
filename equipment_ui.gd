# EquipmentUI.gd (Clean version, only for equipment)
extends Control

@export_group("Slot References")
@export var helmet_slot: Panel
@export var necklace_slot: Panel
@export var cloak_slot: Panel
@export var chest_slot: Panel
@export var gloves_slot: Panel
@export var boots_slot: Panel
@export var ring1_slot: Panel
@export var ring2_slot: Panel

@export_group("Stats Display")
@export var stats_list: VBoxContainer

var player_inventory: Node
var player_stats: Node
var slot_nodes: Dictionary = {}
var stat_labels: Dictionary = {}

# Experience bar elements (created programmatically)
var experience_section: VBoxContainer
var experience_bar: ProgressBar
var experience_text: Label
var experience_bar_created: bool = false



func _ready():
	# Find and connect to PlayerInventory using group lookup
	var inventory_node = get_tree().get_first_node_in_group("PlayerInventory")
	if inventory_node:
		player_inventory = inventory_node
		inventory_node.inventory_changed.connect(_on_inventory_changed)
		print("EquipmentUI: Found PlayerInventory via group lookup and connected signal")
	else:
		printerr("EquipmentUI: Could not find PlayerInventory!")
	
	# Find and connect to PlayerStats using group lookup
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_stats"):
		player_stats = player.get_stats()
		print("EquipmentUI: Found PlayerStats via player.get_stats()")
	else:
		# Try alternative path - look for PlayerStats in PlayerInventory group
		var alt_inventory = get_tree().get_first_node_in_group("PlayerInventory")
		if alt_inventory and alt_inventory.has_method("get_stats"):
			player_stats = alt_inventory.get_stats()
			print("EquipmentUI: Found PlayerStats via inventory.get_stats()")
		else:
			printerr("EquipmentUI: Could not find PlayerStats!")
	
	# Initialize equipment slots
	_initialize_equipment_slots()
	
	# Defer display update to ensure nodes are properly initialized
	call_deferred("_deferred_initialization")
	
	# Connect player stats signals and create experience bar
	if player_stats:
		call_deferred("_connect_player_stats_signals")
		# Use a timer to ensure the experience bar is only created once
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = 0.1
		timer.one_shot = true
		timer.timeout.connect(_create_experience_bar)
		timer.start()

func _deferred_initialization():
	"""Initialize display after all nodes are properly set up"""
	if player_inventory:
		_update_display()
		print("EquipmentUI: Deferred initialization completed successfully")
	else:
		printerr("EquipmentUI: Deferred initialization failed - no player_inventory")






func _initialize_equipment_slots():
	"""Initialize equipment slots and their references"""
	# Get references to all equipment slot nodes using the existing properties
	slot_nodes = {
		"helmet": helmet_slot,
		"necklace": necklace_slot,
		"cloak": cloak_slot,
		"chest": chest_slot,
		"gloves": gloves_slot,
		"boots": boots_slot,
		"ring1": ring1_slot,
		"ring2": ring2_slot
	}
	
	# Initialize stats display
	_initialize_stats_display()
	
	# Set up equipment slots
	for slot_name in slot_nodes:
		var slot_node = slot_nodes[slot_name]
		if slot_node:
			slot_node.set_meta("slot_name", slot_name)
			slot_node.set_meta("player_inventory", player_inventory)
			
			# Use the working equipment_slot.gd script (working approach)
			slot_node.set_script(load("res://equipment_slot.gd"))
			slot_node.slot_name = slot_name
			slot_node.player_inventory = player_inventory
			
			# Manually call the setup that would normally happen in _ready()
			if slot_node.has_method("set_player_inventory"):
				slot_node.set_player_inventory(player_inventory)
			
			# Manually add to group since _ready() won't be called when setting script dynamically
			slot_node.add_to_group("EquipmentSlot")
			
			# Resize the slot to better fit the 64x64 icons
			slot_node.size = Vector2(80, 80)  # 64 + 16 padding
		else:
			printerr("Equipment slot '", slot_name, "' is not assigned in the editor!")
	
	# Add to group and hide initially
	add_to_group("EquipmentUI")
	hide()

func _input(event):
	if Input.is_action_just_pressed("character_screen"):
		toggle_panel()
		# Consume this input event so it doesn't interfere with other systems
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("ui_cancel"):
		# Handle ESC key to close the panel
		if visible:
			hide()
			_update_cursor_mode()
			# Consume this input event
			get_viewport().set_input_as_handled()

# Remove _unhandled_input since _input is already handling the character_screen action
# Having both causes the key to be processed twice, toggling the panel twice

func toggle_panel():
	# Simple toggle behavior - just flip visibility
	visible = not visible
	print("EquipmentUI: Panel visibility toggled to: ", visible)
	print("EquipmentUI: Current group membership: ", get_groups())
	
	# Force cleanup tooltips when hiding equipment panel
	if not visible:
		var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
		if tooltip_manager:
			tooltip_manager.force_cleanup()
	else:
		# Update display when showing the panel
		_update_display()
		
		# Ensure experience bar is visible and update data
		if experience_section:
			experience_section.visible = true
			call_deferred("_update_experience_display")
		elif not experience_bar_created:
			# Experience bar doesn't exist and hasn't been created yet, create it
			call_deferred("_create_experience_bar")
		
		# Additional check: ensure experience bar is properly restored
		call_deferred("_ensure_experience_bar_restored")
	
	_update_cursor_mode()

func _update_cursor_mode():
	"""Update cursor mode based on whether any UI panels are visible"""
	var any_ui_visible = visible
	
	# Check if inventory UI is also visible
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and inventory_ui.visible:
		any_ui_visible = true
	
	# Change cursor mode based on UI visibility
	if any_ui_visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("EquipmentUI: Set mouse mode to VISIBLE (UI open)")
	else:
		# Restore camera mode when no UI is visible
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("EquipmentUI: Set mouse mode to CAPTURED (UI closed, camera mode)")

func _on_inventory_changed():
	"""Called when the player's inventory changes"""
	print("EquipmentUI: Inventory changed signal received!")
	
	# Force cleanup tooltips when inventory changes to prevent stuck tooltips
	var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
	if tooltip_manager:
		tooltip_manager.force_cleanup_on_inventory_change()
	
	_update_display()
	_update_stats_display()

func _update_display():
	"""Update the visual display of equipment slots"""
	if not player_inventory: 
		print("EquipmentUI: _update_display called but player_inventory is null")
		return
	
	var equipment = player_inventory.get_equipment()
	print("EquipmentUI: Updating display with equipment: ", equipment)
	
	# Process each slot
	for slot_name in slot_nodes:
		var slot_node = slot_nodes[slot_name]
		if not slot_node: 
			continue
		
		# Call the slot's own _update_display method if it exists
		if slot_node.has_method("_update_display"):
			print("EquipmentUI: Calling _update_display on slot: ", slot_name)
			slot_node._update_display()
		else:
			print("EquipmentUI: Slot ", slot_name, " doesn't have _update_display, using fallback")
			# Fallback to the old method if the slot doesn't have _update_display
			# Get or create the icon TextureRect
			var icon_rect = _get_or_create_icon_rect(slot_node)
			
			# Check if the slot has an item
			var has_item = equipment.has(slot_name) and equipment[slot_name] != null
			if has_item:
				var equipment_item = equipment[slot_name]
				if equipment_item is Equipment and equipment_item.icon != null:
					icon_rect.texture = equipment_item.icon
					icon_rect.visible = true
					print("EquipmentUI: Set icon for ", slot_name, " to ", equipment_item.icon)
				else:
					icon_rect.texture = null
					icon_rect.visible = false
					print("EquipmentUI: No icon for ", slot_name, " - item: ", equipment_item, " icon: ", equipment_item.icon if equipment_item else "null")
			else:
				icon_rect.texture = null
				icon_rect.visible = false
				print("EquipmentUI: No item in slot ", slot_name)
			
			# Hide/show the slot label based on whether there's a visible icon
			var should_hide = icon_rect.visible and icon_rect.texture != null
			_hide_slot_label(slot_node, should_hide)
	
	# Update stats display
	_update_stats_display()
	
	# Update experience display
	_update_experience_display()

func get_total_armor_value() -> int:
	"""Get the total armor value from all equipped items"""
	if not player_inventory:
		return 0
	
	var total_armor = 0
	var equipment = player_inventory.get_equipment()
	
	for slot_name in equipment:
		var item = equipment[slot_name]
		if item != null and item is Equipment:
			total_armor += item.armor_value
	
	return total_armor

func get_total_stat_bonuses() -> Dictionary:
	"""Get all stat bonuses from equipped items"""
	if not player_inventory:
		return {}
	
	var total_bonuses = {
		"strength": 0,
		"dexterity": 0,
		"intelligence": 0,
		"speed": 0,
		"cunning": 0,
		"spell_power": 0,
		"armor": 0
	}
	
	var equipment = player_inventory.get_equipment()
	
	for slot_name in equipment:
		var item = equipment[slot_name]
		if item != null and item is Equipment:
			# Add stat bonuses
			for stat_name in item.stat_bonuses:
				if total_bonuses.has(stat_name):
					total_bonuses[stat_name] += item.stat_bonuses[stat_name]
			
			# Add armor value
			total_bonuses["armor"] += item.armor_value
	
	return total_bonuses

func _update_stats_display():
	"""Update the stats display with current equipment bonuses"""
	if not stats_list or not player_inventory:
		return
	
	# Calculate total bonuses from all equipped items
	var total_bonuses = {
		"strength": 0,
		"dexterity": 0,
		"intelligence": 0,
		"speed": 0,
		"cunning": 0,
		"spell_power": 0,
		"armor": 0
	}
	
	var equipment = player_inventory.get_equipment()
	
	for slot_name in equipment:
		var item = equipment[slot_name]
		if item != null and item is Equipment:
			# Add stat bonuses
			for stat_name in item.stat_bonuses:
				if total_bonuses.has(stat_name):
					total_bonuses[stat_name] += item.stat_bonuses[stat_name]
			
			# Add armor value
			total_bonuses["armor"] += item.armor_value
	
	# Update the stat labels
	for stat_name in total_bonuses:
		if stat_labels.has(stat_name):
			var label = stat_labels[stat_name]
			var bonus = total_bonuses[stat_name]
			
			if stat_name == "armor":
				label.text = "Armor: " + str(bonus)
			else:
				# Capitalize first letter for display
				var display_name = stat_name.capitalize()
				if bonus > 0:
					label.text = display_name + ": +" + str(bonus)
				elif bonus < 0:
					label.text = display_name + ": " + str(bonus)
				else:
					label.text = display_name + ": +0"

func _get_or_create_icon_rect(slot_node: Panel) -> TextureRect:
	# First try to find an existing icon with the exact name "Icon"
	var icon_rect = slot_node.get_node_or_null("Icon") as TextureRect
	if not icon_rect:
		# If no icon exists, create a new one
		icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(64, 64)  # Set fixed size for icons
		slot_node.add_child(icon_rect)
		
		# Use the known slot dimensions from the scene file
		# Slots are 80x100, icon is 64x64
		var center_x = float(80 - 64) / 2.0  # 8 pixels from left
		var center_y = float(100 - 64) / 2.0  # 18 pixels from top
		icon_rect.position = Vector2(center_x, center_y)
		icon_rect.size = Vector2(64, 64)
		
		# Ensure the icon is properly positioned and visible
		icon_rect.visible = true  # Make it visible by default
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	else:
		# Ensure existing icon has proper settings
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return icon_rect

func _hide_slot_label(slot_node: Panel, should_hide: bool):
	"""Hide or show the slot label to prevent collision with icons"""
	var labels_found = []
	
	# Look for common label names in the slot
	var label_names = ["Label", "SlotLabel", "NameLabel", "Text"]
	
	for label_name in label_names:
		var label = slot_node.get_node_or_null(label_name) as Label
		if label:
			label.visible = not should_hide
			labels_found.append(label_name)
			break
	
	# Also check for any Label child, but be more specific
	for child in slot_node.get_children():
		if child is Label:
			# Only hide/show if it's not the icon and contains text (not empty)
			if child.text != "" and not child.name.begins_with("Icon"):
				child.visible = not should_hide
				labels_found.append(child.name)
	
	# Additional check: look for labels that end with "Label" (like HelmetLabel, NecklaceLabel)
	for child in slot_node.get_children():
		if child is Label and child.name.ends_with("Label"):
			child.visible = not should_hide
			labels_found.append(child.name)

func _initialize_stats_display():
	"""Initialize the stats display labels"""
	# Try to find the stats list automatically if not assigned
	if not stats_list:
		# Search for the stats list more broadly
		var possible_paths = [
			"EquipmentRoot/Panel/VBoxContainer/MainContainer/StatsContainer/StatsList",
			"EquipmentRoot/Panel/VBoxContainer/MainContainer/StatsContainer/StatsList",
			"EquipmentRoot/Panel/StatsContainer/StatsList",
			"EquipmentRoot/StatsContainer/StatsList",
			"Panel/VBoxContainer/MainContainer/StatsContainer/StatsList",
			"Panel/StatsContainer/StatsList"
		]
		
		for path in possible_paths:
			var stats_container = get_node_or_null(path)
			if stats_container:
				stats_list = stats_container
				break
		
		# If still not found, search recursively
		if not stats_list:
			stats_list = _find_stats_list_recursively(self)
		
		if not stats_list:
			printerr("Could not find stats list automatically!")
			return
	
	# Find all stat labels
	for child in stats_list.get_children():
		if child is Label:
			var text = child.text
			if "Strength" in text:
				stat_labels["strength"] = child
			elif "Dexterity" in text:
				stat_labels["dexterity"] = child
			elif "Intelligence" in text:
				stat_labels["intelligence"] = child
			elif "Speed" in text:
				stat_labels["speed"] = child
			elif "Cunning" in text:
				stat_labels["cunning"] = child
			elif "Spell Power" in text:
				stat_labels["spell_power"] = child
			elif "Armor" in text:
				stat_labels["armor"] = child
		# End of _initialize_stats_display function

func _find_stats_list_recursively(node: Node) -> VBoxContainer:
	"""Recursively search for a VBoxContainer that contains stat labels"""
	if node is VBoxContainer:
		# Check if this VBoxContainer contains stat labels
		for child in node.get_children():
			if child is Label and ("Strength" in child.text or "Dexterity" in child.text):
				return node
	
	# Search children recursively
	for child in node.get_children():
		var result = _find_stats_list_recursively(child)
		if result:
			return result
	
	return null

func _create_experience_bar():
	"""Create the experience bar elements programmatically"""
	# Check if experience section already exists and is valid
	if experience_section and is_instance_valid(experience_section) and experience_section.get_parent():
		return
	
	# If experience section exists but is invalid or orphaned, clean it up
	if experience_section and (not is_instance_valid(experience_section) or not experience_section.get_parent()):
		experience_section = null
		experience_bar = null
		experience_text = null
		experience_bar_created = false
	
	# Find the stats container to add the experience section to
	var stats_container = get_node_or_null("EquipmentRoot/Panel/VBoxContainer/MainContainer/StatsContainer")
	if not stats_container:
		# Try alternative paths
		var possible_paths = [
			"Panel/VBoxContainer/MainContainer/StatsContainer",
			"VBoxContainer/MainContainer/StatsContainer",
			"MainContainer/StatsContainer",
			"StatsContainer"
		]
		for path in possible_paths:
			stats_container = get_node_or_null(path)
			if stats_container:
				break
	
	if not stats_container:
		# Try to find it recursively
		stats_container = _find_stats_container_recursively(self)
		if not stats_container:
			printerr("EquipmentUI: Could not find stats container to add experience bar!")
			return
	
	# Create experience section
	experience_section = VBoxContainer.new()
	experience_section.name = "ExperienceSection"
	experience_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_section.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	experience_section.add_theme_constant_override("separation", 8)
	
	# Add some spacing above the experience section
	experience_section.add_theme_constant_override("separation", 15)
	
	# Create a subtle background for the experience section
	var section_style = StyleBoxFlat.new()
	section_style.bg_color = Color(0.08, 0.1, 0.12, 0.8)  # Less transparent background
	section_style.border_width_left = 1
	section_style.border_width_top = 1
	section_style.border_width_right = 1
	section_style.border_width_bottom = 1
	section_style.border_color = Color(0.3, 0.4, 0.5, 0.8)  # Subtle blue-gray border
	section_style.corner_radius_top_left = 8
	section_style.corner_radius_top_right = 8
	section_style.corner_radius_bottom_right = 8
	section_style.corner_radius_bottom_left = 8
	experience_section.add_theme_stylebox_override("panel", section_style)
	
	# Create experience label
	var exp_label = Label.new()
	exp_label.text = "EXPERIENCE"
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Make the label more visible
	exp_label.add_theme_font_size_override("font_size", 16)
	exp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_section.add_child(exp_label)
	
	# Create experience bar
	experience_bar = ProgressBar.new()
	experience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_bar.custom_minimum_size = Vector2(0, 25)  # Make it taller
	experience_bar.show_percentage = false
	
	# Set initial values based on real player data if available
	if player_stats:
		var level_progress = player_stats.get_level_progress()
		experience_bar.max_value = level_progress.experience_to_next_level
		experience_bar.value = level_progress.experience
	else:
		# Fallback to reasonable defaults
		experience_bar.max_value = 50
		experience_bar.value = 0
	
	# Style the experience bar with more visible colors
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Darker background
	style_bg.border_width_left = 2
	style_bg.border_width_top = 2
	style_bg.border_width_right = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0.6, 0.6, 0.6, 1.0)  # Brighter border
	style_bg.corner_radius_top_left = 6
	style_bg.corner_radius_top_right = 6
	style_bg.corner_radius_bottom_right = 6
	style_bg.corner_radius_bottom_left = 6
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.3, 1.0, 0.4, 1.0)  # Brighter green
	style_fill.corner_radius_top_left = 6
	style_fill.corner_radius_top_right = 6
	style_fill.corner_radius_bottom_right = 6
	style_fill.corner_radius_bottom_left = 6
	
	experience_bar.add_theme_stylebox_override("background", style_bg)
	experience_bar.add_theme_stylebox_override("fill", style_fill)
	
	experience_section.add_child(experience_bar)
	
	# Create experience text
	experience_text = Label.new()
	
	# Set initial text based on real player data if available
	if player_stats:
		var level_progress = player_stats.get_level_progress()
		experience_text.text = "Level " + str(level_progress.level) + ": " + str(level_progress.experience) + " / " + str(level_progress.experience_to_next_level) + " XP"
	else:
		# Fallback to reasonable defaults
		experience_text.text = "Level 1: 0 / 50 XP"
	
	experience_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Make the text more visible
	experience_text.add_theme_font_size_override("font_size", 14)
	experience_text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	experience_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_section.add_child(experience_text)
	
	# Insert the experience section after the stats list
	var stats_list_node = stats_container.get_node_or_null("StatsList")
	if stats_list_node:
		# Insert after StatsList (at the end)
		stats_container.add_child(experience_section)
		# Move to the end (after StatsList)
		stats_container.move_child(experience_section, stats_container.get_child_count() - 1)
	else:
		stats_container.add_child(experience_section)
	
	# Ensure the experience section is properly visible and sized
	experience_section.visible = true
	experience_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_section.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Set custom minimum size to ensure visibility
	experience_section.custom_minimum_size = Vector2(0, 80)  # Force minimum height
	
	# Add some spacing above the experience section
	experience_section.add_theme_constant_override("separation", 15)
	
	# Mark as created to prevent duplicates
	experience_bar_created = true
	
	# Force layout update to ensure proper sizing
	experience_section.force_update_transform()
	stats_container.force_update_transform()
	
	# Force the parent to recalculate layout
	if stats_container.get_parent():
		stats_container.get_parent().force_update_transform()
	
	# Try to update the display immediately with real player data
	call_deferred("_update_experience_display")



func _find_stats_container_recursively(node: Node) -> VBoxContainer:
	"""Recursively search for the stats container"""
	if node is VBoxContainer and node.name == "StatsContainer":
		return node
	
	for child in node.get_children():
		var result = _find_stats_container_recursively(child)
		if result:
			return result
	
	return null

func _ensure_experience_bar_restored():
	"""Ensure the experience bar is properly restored and visible"""
	if not experience_section:
		return
	
	# Make sure the experience section is visible
	experience_section.visible = true
	
	# Don't move things around unnecessarily - just ensure visibility and update data
	# The experience section should already be in the right place from initial creation
	
	# Update the experience display with real data
	call_deferred("_update_experience_display")

func _update_experience_display():
	"""Update the experience bar and text with current player progress"""
	if not experience_bar or not experience_text or not player_stats:
		return
	
	var level_progress = player_stats.get_level_progress()
	
	# Update the progress bar with real player data
	experience_bar.max_value = level_progress.experience_to_next_level
	experience_bar.value = level_progress.experience
	
	# Update the text with real player data
	experience_text.text = "Level " + str(level_progress.level) + ": " + str(level_progress.experience) + " / " + str(level_progress.experience_to_next_level) + " XP"

func _on_player_level_up(new_level: int):
	"""Called when the player levels up"""
	_update_experience_display()

func _on_player_stats_changed():
	"""Called when player stats change"""
	_update_experience_display()

func _connect_player_stats_signals():
	"""Connect signals from player_stats node"""
	if player_stats:
		player_stats.level_up.connect(_on_player_level_up)
		player_stats.stats_changed.connect(_on_player_stats_changed)
	else:
		printerr("EquipmentUI: Could not connect PlayerStats signals, player_stats is null!")
