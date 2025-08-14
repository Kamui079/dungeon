# TooltipManager.gd
extends CanvasLayer

var tooltip_panel: Panel
var item_name_label: Label
var item_type_label: Label
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
	layer = 1000

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
	
	# Ensure tooltip stays within viewport bounds
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = mouse_pos.x - tooltip_size.x - 20
	
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = mouse_pos.y - tooltip_size.y - 20
	
	# Ensure tooltip doesn't go off the left or top edges
	tooltip_pos.x = max(0, tooltip_pos.x)
	tooltip_pos.y = max(0, tooltip_pos.y)
	
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
	
	# Set item information
	item_name_label.text = current_item.name
	item_type_label.text = str(current_item.item_type)
	
	# Show the tooltip
	tooltip_panel.visible = true
	tooltip_visible = true
	
	# Initialize position
	var mouse_pos = get_viewport().get_mouse_position()
	last_mouse_pos = mouse_pos
	_update_tooltip_position(mouse_pos)

func _hide_tooltip():
	tooltip_panel.visible = false
	tooltip_visible = false
	current_item = null
