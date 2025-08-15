# TooltipManager.gd
extends CanvasLayer

var tooltip_panel: Panel
var item_name_label: Label
var item_type_label: Label
var item_rarity_label: Label
var item_level_label: Label
var item_stats_label: Label
var item_description_label: Label
var show_timer: Timer
var hide_timer: Timer
var current_item: Item = null
var tooltip_visible: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var position_update_threshold: float = 15.0  # Increased threshold for better performance
var last_cleanup_time: int = 0  # Track last cleanup to prevent rapid cycles (in milliseconds)
var cleanup_cooldown: int = 100  # Minimum time between cleanups (100ms)

func _ready():
	# Get references to UI elements
	tooltip_panel = $TooltipPanel
	item_name_label = $TooltipPanel/VBoxContainer/ItemNameLabel
	item_type_label = $TooltipPanel/VBoxContainer/ItemTypeLabel
	item_rarity_label = $TooltipPanel/VBoxContainer/ItemRarityLabel
	item_level_label = $TooltipPanel/VBoxContainer/ItemLevelLabel
	item_stats_label = $TooltipPanel/VBoxContainer/ItemStatsLabel
	item_description_label = $TooltipPanel/VBoxContainer/ItemDescriptionLabel
	
	# Set up timers
	show_timer = $ShowTimer
	show_timer.wait_time = 0.2  # Very fast show delay
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	
	hide_timer = $HideTimer
	hide_timer.wait_time = 0.05  # Very fast hide delay
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	
	# Set up the tooltip panel
	tooltip_panel.visible = false
	tooltip_panel.modulate.a = 0.0  # Start transparent for fade-in effect
	layer = 1000
	
	# Initialize all labels to be hidden and empty
	_initialize_tooltip_labels()

func _initialize_tooltip_labels():
	"""Initialize all tooltip labels to be hidden and empty"""
	if item_name_label:
		item_name_label.text = ""
		item_name_label.visible = false
	if item_type_label:
		item_type_label.text = ""
		item_type_label.visible = false
	if item_rarity_label:
		item_rarity_label.text = ""
		item_rarity_label.visible = false
	if item_level_label:
		item_level_label.text = ""
		item_level_label.visible = false
	if item_stats_label:
		item_stats_label.text = ""
		item_stats_label.visible = false
	if item_description_label:
		item_description_label.text = ""
		item_description_label.visible = false


func _process(_delta):
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Check if mouse is outside inventory/equipment UI bounds - force cleanup if so
	if tooltip_visible and current_item:
		if not _is_mouse_over_ui():
			force_cleanup()
			return
	
	# Additional cleanup: validate slot mouse states every frame
	if tooltip_visible and current_item:
		var any_valid_mouse_inside = false
		
		# Check if any slot actually has the mouse inside
		var inventory_slots = get_tree().get_nodes_in_group("InventorySlot")
		for slot in inventory_slots:
			if slot.mouse_inside:
				any_valid_mouse_inside = true
				break
		
		var equipment_slots = get_tree().get_nodes_in_group("EquipmentSlot")
		for slot in equipment_slots:
			if slot.mouse_inside:
				any_valid_mouse_inside = true
				break
		
		# If no slots have valid mouse inside, hide tooltip immediately
		if not any_valid_mouse_inside:
			force_cleanup()
			return
	
	if tooltip_visible and current_item:
		# Validate current tooltip item periodically (not every frame)
		if Engine.get_process_frames() % 30 == 0:  # Every 30 frames (about twice per second)
			if not validate_current_tooltip():
				return  # Exit early if validation failed
		
		# Only update position if mouse moved significantly
		if (mouse_pos - last_mouse_pos).length() > position_update_threshold:
			_update_tooltip_position(mouse_pos)
			last_mouse_pos = mouse_pos
		
		# Immediate cleanup: check if mouse is over the SPECIFIC item being shown
		var mouse_over_correct_item = false
		
		# Check inventory slots
		var inventory_slots = get_tree().get_nodes_in_group("InventorySlot")
		for slot in inventory_slots:
			if slot.mouse_inside:
				if slot.player_inventory and slot.player_inventory.bag.has(slot.slot_index):
					var bag_item = slot.player_inventory.bag[slot.slot_index]
					if bag_item and bag_item.item and bag_item.item == current_item:
						mouse_over_correct_item = true
						break
		
		# Check equipment slots
		var equipment_slots = get_tree().get_nodes_in_group("EquipmentSlot")
		for slot in equipment_slots:
			if slot.mouse_inside:
				if slot.player_inventory and slot.player_inventory.get_equipment().has(slot.slot_name):
					var equipment = slot.player_inventory.get_equipment()
					var item = equipment[slot.slot_name]
					if item and item == current_item and not slot.is_being_dragged_from:
						mouse_over_correct_item = true
						break
		
		# If mouse is not over the correct item, hide tooltip immediately
		if not mouse_over_correct_item:
			_hide_tooltip()
			return
		
		# Additional cleanup: if mouse moved significantly and we're not over the correct item, hide tooltip
		var mouse_movement = (mouse_pos - last_mouse_pos).length()
		if mouse_movement > 50.0:  # If mouse moved more than 50 pixels
			var still_over_correct_item = false
			
			# Quick check if we're still over the correct item
			for slot in inventory_slots:
				if slot.mouse_inside:
					if slot.player_inventory and slot.player_inventory.bag.has(slot.slot_index):
						var bag_item = slot.player_inventory.bag[slot.slot_index]
						if bag_item and bag_item.item and bag_item.item == current_item:
							still_over_correct_item = true
							break
			
			for slot in equipment_slots:
				if slot.mouse_inside:
					if slot.player_inventory and slot.player_inventory.get_equipment().has(slot.slot_name):
						var equipment = slot.player_inventory.get_equipment()
						var item = equipment[slot.slot_name]
						if item and item == current_item and not slot.is_being_dragged_from:
							still_over_correct_item = true
							break
			
			if not still_over_correct_item:
				_hide_tooltip()
				# Reset all slot states when mouse moves significantly
				reset_all_slot_states()
				return
		
		# Fallback: if mouse moves too far from the tooltip, hide it immediately
		# Use a more generous distance that accounts for tooltip size
		var tooltip_center = tooltip_panel.position + tooltip_panel.size / 2
		var distance_from_tooltip = (mouse_pos - tooltip_center).length()
		var max_distance = max(tooltip_panel.size.x, tooltip_panel.size.y) * 1.5  # 1.5x the larger dimension
		
		if distance_from_tooltip > max_distance:
			_hide_tooltip()  # Hide immediately instead of starting timer
			return  # Exit early to prevent further processing
	
	# Periodic cleanup: every 120 frames (about 2 seconds), check if tooltip should be hidden
	if Engine.get_process_frames() % 120 == 0:
		if tooltip_visible and current_item:
			# Check if mouse is still over the correct item
			var should_hide = true
			
			# Look for inventory slots
			var inventory_slots = get_tree().get_nodes_in_group("InventorySlot")
			for slot in inventory_slots:
				if slot.mouse_inside:
					# Check if this slot actually has the correct item
					if slot.player_inventory and slot.player_inventory.bag.has(slot.slot_index):
						var bag_item = slot.player_inventory.bag[slot.slot_index]
						if bag_item and bag_item.item and bag_item.item == current_item:
							should_hide = false
							break
			
			# Look for equipment slots
			var equipment_slots = get_tree().get_nodes_in_group("EquipmentSlot")
			for slot in equipment_slots:
				if slot.mouse_inside:
					# Check if this slot actually has the correct item
					if slot.player_inventory and slot.player_inventory.get_equipment().has(slot.slot_name):
						var equipment = slot.player_inventory.get_equipment()
						var item = equipment[slot.slot_name]
						if item and item == current_item and not slot.is_being_dragged_from:
							should_hide = false
							break
			
			if should_hide:
				_hide_tooltip()
	
	# Additional safety check: verify current item still exists in inventory
	if Engine.get_process_frames() % 60 == 0:  # Every 60 frames (about once per second)
		if tooltip_visible and current_item:
			var item_still_exists = false
			
			# Check if item exists in inventory
			var inventory_slots = get_tree().get_nodes_in_group("InventorySlot")
			for slot in inventory_slots:
				if slot.player_inventory and slot.player_inventory.bag.has(slot.slot_index):
					var bag_item = slot.player_inventory.bag[slot.slot_index]
					if bag_item and bag_item.item and bag_item.item == current_item:
						item_still_exists = true
						break
			
			# Check if item exists in equipment
			if not item_still_exists:
				var equipment_slots = get_tree().get_nodes_in_group("EquipmentSlot")
				for slot in equipment_slots:
					if slot.player_inventory and slot.player_inventory.get_equipment().has(slot.slot_name):
						var equipment = slot.player_inventory.get_equipment()
						var item = equipment[slot.slot_name]
						if item and item == current_item:
							item_still_exists = true
							break
			
			# If item no longer exists, hide tooltip
			if not item_still_exists:
				_hide_tooltip()
				return

func _update_tooltip_position(mouse_pos: Vector2):
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = tooltip_panel.size
	
	# Calculate position (offset by 20 pixels from mouse)
	var tooltip_pos = mouse_pos + Vector2(20, 20)
	
	# Ensure tooltip stays within viewport bounds with better edge detection
	if tooltip_pos.x + tooltip_size.x > viewport_size.x - 20:
		tooltip_pos.x = mouse_pos.x - tooltip_size.x - 20
	
	if tooltip_pos.y + tooltip_size.y > viewport_size.y - 20:
		tooltip_pos.y = mouse_pos.y - tooltip_size.y - 20
	
	# Ensure tooltip doesn't go off the left or top edges
	tooltip_pos.x = max(20, tooltip_pos.x)
	tooltip_pos.y = max(20, tooltip_pos.y)
	
	# Direct positioning - no animations for snappy feel
	tooltip_panel.position = tooltip_pos

func show_tooltip(item: Item):
	# Cancel any existing timers
	show_timer.stop()
	hide_timer.stop()
	
	# If we're already showing a tooltip for this item, don't restart
	if tooltip_visible and current_item == item:
		return
	
	# If we're showing a different item, hide the current one immediately
	if tooltip_visible and current_item != item:
		_hide_tooltip()
	
	current_item = item
	show_timer.start()

func hide_tooltip():
	# Cancel any existing timers
	show_timer.stop()
	hide_timer.stop()
	
	# Hide immediately instead of using timer
	_hide_tooltip()

func force_cleanup():
	"""Force cleanup of tooltip state - use when UI is closed"""
	# Check cooldown to prevent rapid cleanup cycles
	var current_time = Time.get_ticks_msec()
	var time_since_last_cleanup = current_time - last_cleanup_time
	if time_since_last_cleanup < cleanup_cooldown:
		return  # Skip cleanup if too soon
	
	last_cleanup_time = current_time
	show_timer.stop()
	hide_timer.stop()
	_hide_tooltip()

func force_cleanup_on_inventory_change():
	"""Force cleanup when inventory changes - this prevents stuck tooltips"""
	if tooltip_visible and current_item:
		force_cleanup()

func validate_current_tooltip():
	"""Validate that the current tooltip item still exists and is valid"""
	if not tooltip_visible or not current_item:
		return true  # Nothing to validate
	
	var item_still_exists = false
	
	# Check if item exists in inventory
	var inventory_slots = get_tree().get_nodes_in_group("InventorySlot")
	for slot in inventory_slots:
		if slot.player_inventory and slot.player_inventory.bag.has(slot.slot_index):
			var bag_item = slot.player_inventory.bag[slot.slot_index]
			if bag_item and bag_item.item and bag_item.item == current_item:
				item_still_exists = true
				break
	
	# Check if item exists in equipment
	if not item_still_exists:
		var equipment_slots = get_tree().get_nodes_in_group("EquipmentSlot")
		for slot in equipment_slots:
			if slot.player_inventory and slot.player_inventory.get_equipment().has(slot.slot_name):
				var equipment = slot.player_inventory.get_equipment()
				var item = equipment[slot.slot_name]
				if item and item == current_item:
					item_still_exists = true
					break
	
	# If item no longer exists, force cleanup
	if not item_still_exists:
		force_cleanup()
		return false
	
	return true

func _is_mouse_over_ui() -> bool:
	"""Check if mouse is over any inventory or equipment UI"""
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Check inventory UI
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and inventory_ui.visible:
		var inventory_rect = Rect2(inventory_ui.global_position, inventory_ui.size)
		if inventory_rect.has_point(mouse_pos):
			return true
	
	# Check equipment UI
	var equipment_ui = get_tree().get_first_node_in_group("EquipmentUI")
	if equipment_ui and equipment_ui.visible:
		var equipment_rect = Rect2(equipment_ui.global_position, equipment_ui.size)
		if equipment_rect.has_point(mouse_pos):
			return true
	
	return false

func reset_all_slot_states():
	"""Reset all slot mouse states - use when mouse moves significantly"""
	var inventory_slots = get_tree().get_nodes_in_group("InventorySlot")
	for slot in inventory_slots:
		if slot.mouse_inside:
			slot.mouse_inside = false
	
	var equipment_slots = get_tree().get_nodes_in_group("EquipmentSlot")
	for slot in equipment_slots:
		if slot.mouse_inside:
			slot.mouse_inside = false

func _on_show_timer_timeout():
	if current_item:
		_show_tooltip()

func _on_hide_timer_timeout():
	_hide_tooltip()

func _show_tooltip():
	if not current_item:
		return
	
	# Clear all sections first
	_clear_tooltip_sections()
	
	# Build tooltip using structured sections
	_build_tooltip_content()
	
	# Auto-resize the tooltip panel to fit content
	_auto_resize_tooltip()
	
	# Show the tooltip immediately - no fade for snappy feel
	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 1.0  # Ensure full opacity
	tooltip_visible = true
	
	# Initialize position
	var mouse_pos = get_viewport().get_mouse_position()
	last_mouse_pos = mouse_pos
	_update_tooltip_position(mouse_pos)

func _clear_tooltip_sections():
	"""Clear all tooltip sections to prepare for new content"""
	item_name_label.text = ""
	item_type_label.text = ""
	item_rarity_label.text = ""
	item_level_label.text = ""
	item_stats_label.text = ""
	item_description_label.text = ""

func _build_tooltip_content():
	"""Build tooltip content using structured sections"""
	
	# SECTION 1: Item Name (controlled by inspector)
	if current_item.has_method("should_show_tooltip_name") and current_item.should_show_tooltip_name():
		var name_text = current_item.name
		if current_item.has_method("get_tooltip_name"):
			name_text = current_item.get_tooltip_name()
		item_name_label.text = name_text
		item_name_label.visible = true
	else:
		item_name_label.visible = false
	
	# SECTION 2: Item Type (controlled by inspector)
	if current_item.has_method("should_show_tooltip_type") and current_item.should_show_tooltip_type():
		var type_text = "Item"
		if current_item.has_method("get_tooltip_type"):
			type_text = current_item.get_tooltip_type()
		item_type_label.text = type_text
		item_type_label.visible = true
	else:
		item_type_label.visible = false
	
	# SECTION 3: Rarity (controlled by inspector)
	if current_item.has_method("should_show_tooltip_rarity") and current_item.should_show_tooltip_rarity():
		var rarity_text = "Rarity: "
		if current_item.has_method("get_tooltip_rarity"):
			rarity_text += current_item.get_tooltip_rarity()
		else:
			rarity_text += "Common"
		item_rarity_label.text = rarity_text
		item_rarity_label.visible = true
		
		# ALWAYS set rarity color when rarity is displayed
		_set_rarity_color(current_item)
	else:
		item_rarity_label.visible = false
	
	# SECTION 4: Level Requirement (controlled by inspector)
	if current_item.has_method("should_show_tooltip_level_requirement") and current_item.should_show_tooltip_level_requirement():
		var level_req = 1
		if current_item.has_method("get_tooltip_level_requirement"):
			level_req = current_item.get_tooltip_level_requirement()
		if level_req > 1:
			item_level_label.text = "Required Level: " + str(level_req)
			item_level_label.visible = true
		else:
			item_level_label.visible = false
	else:
		item_level_label.visible = false
	
	# SECTION 5: Stats (controlled by inspector)
	if current_item.has_method("should_show_tooltip_stats") and current_item.should_show_tooltip_stats():
		var stats_text = _build_stats_section()
		if stats_text != "":
			item_stats_label.text = stats_text
			item_stats_label.visible = true
		else:
			item_stats_label.visible = false
	else:
		item_stats_label.visible = false
	
	# SECTION 6: Description (controlled by inspector)
	if current_item.has_method("should_show_tooltip_description") and current_item.should_show_tooltip_description():
		var desc_text = "A mysterious item with unknown properties."
		if current_item.has_method("get_tooltip_description"):
			desc_text = current_item.get_tooltip_description()
		elif current_item.has_method("description"):
			desc_text = current_item.description
		
		# Format description for readability
		desc_text = _format_description(desc_text)
		item_description_label.text = desc_text
		item_description_label.visible = true
	else:
		item_description_label.visible = false

func _set_rarity_color(item: Item):
	"""Set the appropriate color for the rarity label"""
	
	if item.has_method("get_rarity"):
		var rarity = item.get_rarity().to_lower()
		match rarity:
			"common":
				item_rarity_label.modulate = Color(0.9, 0.9, 0.9, 1)  # White
			"uncommon":
				item_rarity_label.modulate = Color(0.2, 1.0, 0.2, 1)  # Green
			"rare":
				item_rarity_label.modulate = Color(0.2, 0.4, 1.0, 1)  # Blue
			"epic":
				item_rarity_label.modulate = Color(0.8, 0.2, 1.0, 1)  # Purple
			"legendary":
				item_rarity_label.modulate = Color(1.0, 0.5, 0.0, 1)  # Orange
			_:
				item_rarity_label.modulate = Color(0.9, 0.9, 0.9, 1)  # Default white
	else:
		item_rarity_label.modulate = Color(0.9, 0.9, 0.9, 1)  # Default white

func _build_stats_section() -> String:
	"""Build the stats section text"""
	var stats_text = ""
	
	# Special handling for consumable items to show damage and effects
	if current_item.item_type == Item.ITEM_TYPE.CONSUMABLE:
		stats_text = _build_consumable_stats()
		if stats_text != "":
			return stats_text
	
	# First try to get custom stats from inspector
	if current_item.has_method("get_tooltip_stats"):
		var custom_stats = current_item.get_tooltip_stats()
		if custom_stats and custom_stats.size() > 0:
			for stat_name in custom_stats:
				var stat_value = custom_stats[stat_name]
				if stat_value > 0:
					stats_text += "+" + str(stat_value) + " " + stat_name.capitalize() + "\n"
				elif stat_value < 0:
					stats_text += str(stat_value) + " " + stat_name.capitalize() + "\n"
				else:
					stats_text += stat_name.capitalize() + ": " + str(stat_value) + "\n"
			return stats_text
	
	# Fallback to legacy get_stats method if no custom stats
	if current_item.has_method("get_stats"):
		var stats = current_item.get_stats()
		if stats and stats.size() > 0:
			# Format stats like Diablo 2: "+5 Strength", "+3 Dexterity", etc.
			for stat_name in stats:
				var stat_value = stats[stat_name]
				if stat_value > 0:
					stats_text += "+" + str(stat_value) + " " + stat_name.capitalize() + "\n"
				elif stat_value < 0:
					stats_text += str(stat_value) + " " + stat_name.capitalize() + "\n"
				else:
					stats_text += stat_name.capitalize() + ": " + str(stat_value) + "\n"
	
	return stats_text

func _build_consumable_stats() -> String:
	"""Build stats specifically for consumable items"""
	var stats_text = ""
	
	# Get custom stats for consumables
	if current_item.has_method("get_tooltip_stats"):
		var custom_stats = current_item.get_tooltip_stats()
		if custom_stats and custom_stats.size() > 0:
			# Show damage and damage type prominently
			if custom_stats.has("damage") and custom_stats.damage > 0:
				var damage_type = custom_stats.get("damage_type", "physical")
				stats_text += "⚔️ " + str(custom_stats.damage) + " " + damage_type.capitalize() + " Damage\n"
			
			# Show armor penetration if present
			if custom_stats.has("armor_penetration") and custom_stats.armor_penetration > 0:
				stats_text += "🛡️ " + str(custom_stats.armor_penetration) + " Armor Penetration\n"
			
			# Show duration if present
			if custom_stats.has("duration") and custom_stats.duration > 0:
				stats_text += "⏱️ " + str(custom_stats.duration) + " Turn Duration\n"
			
			# Show poison chance and damage if present
			if custom_stats.has("poison_chance") and custom_stats.poison_chance > 0:
				stats_text += "☠️ " + str(custom_stats.poison_chance) + "% Poison Chance\n"
				if custom_stats.has("poison_damage") and custom_stats.poison_damage > 0:
					stats_text += "  " + str(custom_stats.poison_damage) + " Poison Damage/Turn\n"
			
			# Show other custom stats
			for stat_name in custom_stats:
				var stat_value = custom_stats[stat_name]
				# Skip stats we've already handled specially
				if stat_name in ["damage", "damage_type", "armor_penetration", "duration", "poison_chance", "poison_damage"]:
					continue
				if stat_value > 0:
					stats_text += "+" + str(stat_value) + " " + stat_name.capitalize() + "\n"
				elif stat_value < 0:
					stats_text += str(stat_value) + " " + stat_name.capitalize() + "\n"
	
	return stats_text

func _format_description(desc_text: String) -> String:
	"""Format description text for better readability"""
	if desc_text.length() > 60:
		# Add line breaks for readability
		var words = desc_text.split(" ")
		var formatted_desc = ""
		var current_line = ""
		for word in words:
			if (current_line + word).length() > 30:
				formatted_desc += current_line + "\n"
				current_line = word + " "
			else:
				current_line += word + " "
		formatted_desc += current_line
		return formatted_desc
	
	return desc_text

func _auto_resize_tooltip():
	"""Automatically resize the tooltip panel to fit its content"""
	# Wait a frame for all labels to update their sizes
	await get_tree().process_frame
	
	# Calculate the total height needed
	var total_height = 0
	var vbox = $TooltipPanel/VBoxContainer
	
	# Add up the height of all visible children
	for child in vbox.get_children():
		if child.visible and child is Control:
			total_height += child.size.y
	
	# Add spacing between elements
	var spacing = vbox.get_theme_constant("separation")
	var visible_children = 0
	for child in vbox.get_children():
		if child.visible:
			visible_children += 1
	
	if visible_children > 1:
		total_height += spacing * (visible_children - 1)
	
	# Add top and bottom margins
	total_height += 24  # 12px top + 12px bottom
	
	# Set minimum and maximum sizes
	var min_height = 120  # Minimum tooltip height
	var max_height = 400  # Maximum tooltip height
	
	# Apply the calculated height with constraints
	var new_height = clamp(total_height, min_height, max_height)
	tooltip_panel.size.y = new_height
	
	# Update the background highlight to match
	var highlight = $TooltipPanel/BackgroundHighlight
	if highlight:
		highlight.size = tooltip_panel.size

func _hide_tooltip():
	# Hide immediately - no fade for snappy feel
	tooltip_panel.visible = false
	tooltip_visible = false
	current_item = null
	
	# Clear all label text to prevent any leftover text from showing
	_clear_all_label_text()

func _clear_all_label_text():
	"""Clear all label text to prevent leftover text from showing"""
	if item_name_label:
		item_name_label.text = ""
	if item_type_label:
		item_type_label.text = ""
	if item_rarity_label:
		item_rarity_label.text = ""
	if item_level_label:
		item_level_label.text = ""
	if item_stats_label:
		item_stats_label.text = ""
	if item_description_label:
		item_description_label.text = ""
