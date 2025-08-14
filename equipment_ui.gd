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
var slot_nodes: Dictionary = {}
var stat_labels: Dictionary = {}

func _ready():
	"""Initialize the equipment UI"""
	print("EquipmentUI: _ready() called")
	
	# Find the player inventory
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	if player_inventory:
		print("EquipmentUI: Found PlayerInventory, connecting signals...")
		player_inventory.inventory_changed.connect(_on_inventory_changed)
		print("EquipmentUI: Signal connected successfully")
	else:
		printerr("EquipmentUI: Could not find PlayerInventory!")
		return
	
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
	
	# Debug: Check slot node references
	print("=== SLOT NODE INIT DEBUG ===")
	for slot_name in slot_nodes:
		var slot_node = slot_nodes[slot_name]
		if slot_node:
			print("Slot ", slot_name, " found: ", slot_node, " - Valid: ", is_instance_valid(slot_node))
			if is_instance_valid(slot_node):
				print("  - Parent: ", slot_node.get_parent())
				print("  - Scene: ", slot_node.get_scene_file_path())
				print("  - Children count: ", slot_node.get_child_count())
		else:
			print("Slot ", slot_name, " is null!")
	print("=== END SLOT NODE INIT DEBUG ===")
	
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
			
			# Resize the slot to better fit the 64x64 icons
			slot_node.size = Vector2(80, 80)  # 64 + 16 padding
		else:
			printerr("Equipment slot '", slot_name, "' is not assigned in the editor!")
	
	# Initial display update
	_update_display()
	
	# Add to group and hide initially
	add_to_group("EquipmentUI")
	hide()

# --- MODIFIED: This function is now fixed ---

func _input(_event):
	if Input.is_action_just_pressed("character_screen"):
		toggle_panel()

func toggle_panel():
	visible = not visible
	_update_cursor_mode()

func _update_cursor_mode():
	"""Update cursor mode based on whether any UI panels are visible"""
	var any_ui_visible = visible
	
	# Check if inventory UI is also visible
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and inventory_ui.visible:
		any_ui_visible = true
	
	# Set cursor mode based on whether any UI is visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if any_ui_visible else Input.MOUSE_MODE_CAPTURED

func _on_inventory_changed():
	"""Called when the player's inventory changes"""
	_update_display()
	_update_stats_display()

func _update_display():
	"""Update the visual display of equipment slots"""
	if not player_inventory: 
		return
	
	var equipment = player_inventory.get_equipment()
	
	# Debug: Check what equipment data we're working with
	print("=== UPDATE DISPLAY DEBUG ===")
	print("Equipment data: ", equipment)
	print("Equipment keys: ", equipment.keys())
	for key in equipment:
		if equipment[key] != null:
			print("  ", key, ": ", equipment[key].name if equipment[key].has_method("get") else equipment[key])
		else:
			print("  ", key, ": null")
	print("=== END UPDATE DISPLAY DEBUG ===")
	
	# Process each slot
	print("Processing slots: ", slot_nodes.keys())
	for slot_name in slot_nodes:
		var slot_node = slot_nodes[slot_name]
		if not slot_node: 
			print("Slot ", slot_name, " node is null, skipping")
			continue
		
		# Get or create the icon TextureRect
		var icon_rect = _get_or_create_icon_rect(slot_node)
		
		# Check if the slot has an item
		var has_item = equipment.has(slot_name) and equipment[slot_name] != null
		if has_item:
			var equipment_item = equipment[slot_name]
			if equipment_item is Equipment and equipment_item.icon != null:
				icon_rect.texture = equipment_item.icon
				icon_rect.visible = true
			else:
				icon_rect.texture = null
				icon_rect.visible = false
		else:
			icon_rect.texture = null
			icon_rect.visible = false
		
		# Hide/show the slot label based on whether there's a visible icon
		var should_hide = icon_rect.visible and icon_rect.texture != null
		_hide_slot_label(slot_node, should_hide)
		
		# Debug output for all slots
		print("Slot ", slot_name, ": has_item=", has_item, ", texture=", icon_rect.texture != null, ", icon_visible=", icon_rect.visible, ", should_hide=", should_hide)
		if has_item:
			var equipment_item = equipment[slot_name]
			print("  - Equipment item: ", equipment_item.name if equipment_item else "null")
			print("  - Equipment icon: ", equipment_item.icon if equipment_item else "null")
			print("  - Equipment class: ", equipment_item.get_class() if equipment_item else "null")
	
	# Update stats display
	_update_stats_display()

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
	
	# Debug output for helmet slot only
	if slot_node.name == "HelmetSlot":
		print("HelmetSlot labels found: ", labels_found, " - should_hide: ", should_hide)

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
