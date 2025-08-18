# InventoryUI.gd
extends Control

@export var items_container: GridContainer

var player_inventory: Node
var player_stats: Node

# Regular inventory UI - no stat allocation here

func _ready():
	# We need to wait a frame for player_inventory to be set by the player.
	await get_tree().process_frame
	
	if player_inventory:
		player_inventory.inventory_changed.connect(update_display)
		# Initialize all inventory slots with the player_inventory reference
		_initialize_inventory_slots()
	else:
		printerr("InventoryUI ERROR: 'player_inventory' was not set by the player script!")
		return

	if not items_container:
		printerr("Items container not assigned in the editor for InventoryUI!")
		return

	update_display()
	hide()
	
	# Add to group for cursor coordination
	add_to_group("InventoryUI")

func _initialize_inventory_slots():
	"""Initialize all inventory slots with the player_inventory reference"""
	if not items_container:
		return
		
	for i in range(items_container.get_child_count()):
		var slot_node = items_container.get_child(i)
		if slot_node.has_method("set_player_inventory"):
			slot_node.set_player_inventory(player_inventory)
		elif slot_node.has_method("set_meta"):
			# Alternative method for older versions
			slot_node.set_meta("player_inventory", player_inventory)
		
		# Also set the slot_index if the method exists
		if slot_node.has_method("set_slot_index"):
			slot_node.set_slot_index(i)

# Stat allocation moved to equipment UI

func _input(_event):
	if Input.is_action_just_pressed("toggle_inventory"):
		# Check if we're in combat mode - if so, don't allow inventory toggle
		var combat_manager = get_tree().get_first_node_in_group("CombatManager")
		if combat_manager and combat_manager.in_combat:
			# In combat mode - don't toggle inventory
			return
		
		toggle_panel()

func toggle_panel():
	visible = not visible
	
	# Force cleanup tooltips when hiding inventory
	if not visible:
		var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
		if tooltip_manager:
			tooltip_manager.force_cleanup()
	
	_update_cursor_mode()

func _update_cursor_mode():
	"""Update cursor mode based on whether any UI panels are visible"""
	var any_ui_visible = visible
	
	# Check if equipment UI is also visible
	var equipment_ui = get_tree().get_first_node_in_group("EquipmentUI")
	if equipment_ui and equipment_ui.visible:
		any_ui_visible = true
	
	# Set cursor mode based on whether any UI is visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if any_ui_visible else Input.MOUSE_MODE_CAPTURED

func update_display():
	if not player_inventory or not items_container: return
	
	# Force cleanup tooltips when inventory changes to prevent stuck tooltips
	var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
	if tooltip_manager:
		tooltip_manager.force_cleanup_on_inventory_change()
	
	var bag = player_inventory.get_bag()
	for i in range(items_container.get_child_count()):
		var slot_node = items_container.get_child(i)
		var icon_rect := slot_node.find_child("Icon") as TextureRect
		var quantity_label := slot_node.find_child("QuantityLabel") as Label
		if not icon_rect or not quantity_label: continue
		
		# Debug: Check what we're working with


		if bag.has(i):
			var item_data = bag[i]
			icon_rect.texture = item_data.item.icon
			# Always show icons for items in bag - dragging is handled by the slot itself
			icon_rect.visible = true
			
			# Debug: Print item data to see what's happening

			
			# Scale up small consumable icons for better visibility
			if item_data.item.item_type == Item.ITEM_TYPE.CONSUMABLE:
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				# Scale up consumable icons but keep them within slot bounds
				icon_rect.custom_minimum_size = Vector2(52, 52)  # Slightly larger but still within 64x64 slot
			else:
				# Reset to default for equipment
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = Vector2(64, 64)
			
			
			if item_data.quantity > 1:
				quantity_label.text = str(item_data.quantity)
				quantity_label.visible = true
				quantity_label.modulate.a = 1.0  # Ensure fully visible
				# Unlock quantity label for stacks
				if slot_node.has_method("_unlock_quantity_label_for_stack"):
					slot_node._unlock_quantity_label_for_stack()

			else:
				# Never show quantity labels for single items or empty slots
				quantity_label.text = ""
				quantity_label.visible = false
				quantity_label.modulate.a = 0.0  # Force completely invisible
				# Lock down quantity label for single items
				if slot_node.has_method("_lock_quantity_label_for_single_item"):
					slot_node._lock_quantity_label_for_single_item()

			

		else:
			icon_rect.visible = false
			quantity_label.visible = false
			quantity_label.text = ""
			quantity_label.modulate.a = 0.0  # Force completely invisible
			# Lock down quantity label for empty slots
			if slot_node.has_method("_lock_quantity_label_for_single_item"):
				slot_node._lock_quantity_label_for_single_item()
			# Reset icon scaling when slot is empty
			icon_rect.custom_minimum_size = Vector2(64, 64)

	
	# Final safety check: ensure single items never show quantity labels
	await get_tree().process_frame  # Wait a frame for any other scripts to run
	for i in range(items_container.get_child_count()):
		var slot_node = items_container.get_child(i)
		var quantity_label := slot_node.find_child("QuantityLabel") as Label
		if quantity_label and bag.has(i):
			var item_data = bag[i]
			if item_data.quantity <= 1:
				quantity_label.text = ""
				quantity_label.visible = false
				quantity_label.modulate.a = 0.0

# Stat allocation functions moved to equipment UI
