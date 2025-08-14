# EquipmentSlot.gd
# A custom Panel class that handles drag and drop for equipment slots
extends Panel
class_name EquipmentSlot

@export var slot_name: String = ""
@export var player_inventory: PlayerInventory

var is_being_dragged_from: bool = false
var mouse_inside: bool = false
var last_tooltip_update_time: int = 0  # Track last tooltip update (in milliseconds)
var tooltip_update_cooldown: int = 50  # 50ms cooldown between tooltip updates

func _ready():
	# Add to group for tooltip cleanup system
	add_to_group("EquipmentSlot")
	
	# Set mouse filter to pass to receive input events
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Try to get player_inventory from scene tree if not set
	if not player_inventory:
		player_inventory = get_tree().get_first_node_in_group("PlayerInventory")

func set_player_inventory(inv: PlayerInventory):
	"""Set the player_inventory reference for this slot"""
	player_inventory = inv

func _update_display():
	"""Update the visual display of this equipment slot"""
	if not player_inventory:
		return
	
	var equipment = player_inventory.get_equipment()
	if not equipment.has(slot_name):
		return
	
	var item = equipment[slot_name]
	
	# Clear any existing children (icons, etc.)
	for child in get_children():
		if child is TextureRect or child.name == "Icon":
			child.queue_free()
	
	# If there's an item and we're not being dragged from, show its icon
	if item != null and item.icon != null and not is_being_dragged_from:
		var icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.texture = item.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(64, 64)
		icon_rect.position = (size - icon_rect.size) / 2  # Center the icon
		add_child(icon_rect)
		
		# Hide slot labels when item is equipped
		_hide_slot_labels(true)
	else:
		# Show slot labels when no item or when being dragged from
		_hide_slot_labels(false)

func _hide_slot_labels(should_hide: bool):
	"""Hide or show the slot labels to prevent collision with icons"""
	var labels_found = []
	
	# Look for common label names in the slot
	var label_names = ["Label", "SlotLabel", "NameLabel", "Text"]
	
	for label_name in label_names:
		var label = get_node_or_null(label_name) as Label
		if label:
			label.visible = not should_hide
			labels_found.append(label_name)
			break
	
	# Also check for any Label child, but be more specific
	for child in get_children():
		if child is Label:
			# Only hide/show if it's not the icon and contains text (not empty)
			if child.text != "" and not child.name.begins_with("Icon"):
				child.visible = not should_hide
				labels_found.append(child.name)
	
	# Additional check: look for labels that end with "Label" (like HelmetLabel, NecklaceLabel)
	for child in get_children():
		if child is Label and child.name.ends_with("Label"):
			child.visible = not should_hide
			labels_found.append(child.name)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if player_inventory and player_inventory.get_equipment().has(slot_name):
		var equipment = player_inventory.get_equipment()
		var item = equipment[slot_name]
		if item != null:
			# Mark that we're being dragged from
			is_being_dragged_from = true
			
			# Update display to hide the icon
			_update_display()
			
			var preview = TextureRect.new()
			preview.texture = item.icon
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.size = Vector2(64, 64)
			
			# Fix the drag preview positioning
			preview.pivot_offset = preview.size / 2.0
			
			# Create a control node to properly position the preview
			var preview_container = Control.new()
			preview_container.size = preview.size
			preview_container.add_child(preview)
			
			# Position the preview with negative offset to compensate for Godot's default positioning
			# This makes the item appear exactly on the cursor
			preview.position = Vector2(-32, -32)  # Half the size to center on cursor
			
			set_drag_preview(preview_container)
			return { "source": "equipment", "from_slot": slot_name }
		
	return null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source")

func _drop_data(_at_position: Vector2, data: Variant):
	if data.has("source") and data.has("from_slot"):
		var source = data["source"]
		var from_slot = data["from_slot"]
		
		if source == "bag":
			# Dropping from bag to equipment
			if player_inventory.bag.has(from_slot):
				var bag_item = player_inventory.bag[from_slot].item
				if bag_item.has_method("get_slot_name"):
					var required_slot = bag_item.get_slot_name()
					if required_slot == slot_name:
						player_inventory._swap_bag_and_equipment(from_slot, slot_name)
		
		elif source == "equipment":
			# Dropping from equipment to equipment (swap)
			if from_slot != slot_name:
				_swap_equipment_slots(from_slot, slot_name)
		
		# Reset drag state
		is_being_dragged_from = false
		_update_display()

func _swap_equipment_slots(from_slot: String, to_slot: String):
	"""Swap items between two equipment slots"""
	if not player_inventory:
		return
	
	var equipment = player_inventory.get_equipment()
	if not equipment.has(from_slot) or not equipment.has(to_slot):
		return
	
	var from_item = equipment[from_slot]
	var to_item = equipment[to_slot]
	
	# Check if items can be equipped to their target slots
	if from_item != null and from_item.has_method("get_slot_name"):
		var from_slot_type = from_item.get_slot_name()
		if from_slot_type != to_slot:
			return
	
	if to_item != null and to_item.has_method("get_slot_name"):
		var to_slot_type = to_item.get_slot_name()
		if to_slot_type != from_slot:
			return
	
	# If both slots are empty, nothing to swap
	if from_item == null and to_item == null:
		return
	
	# If one slot is empty, just move the item
	if from_item == null:
		equipment[from_slot] = to_item
		equipment[to_slot] = null
		player_inventory.inventory_changed.emit()
		return
	
	if to_item == null:
		equipment[from_slot] = null
		equipment[to_slot] = from_item
		player_inventory.inventory_changed.emit()
		return
	
	# Both slots have items - swap them
	# Use a simple swap approach
	var temp = equipment[from_slot]
	equipment[from_slot] = equipment[to_slot]
	equipment[to_slot] = temp
	
	# Emit signal to update display
	player_inventory.inventory_changed.emit()

func _gui_input(event: InputEvent):
	# Handle mouse motion for custom tooltip detection
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	
	# Only handle mouse button events for right-click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if player_inventory and player_inventory.get_equipment().has(slot_name):
				var equipment = player_inventory.get_equipment()
				if equipment[slot_name] != null:
					player_inventory.handle_right_click(-1, slot_name)
					get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion):
	"""Custom mouse motion handling for tooltip detection"""
	var mouse_pos = event.position
	
	# Use a smaller buffer zone for more precise mouse entry/exit
	var buffered_rect = Rect2(Vector2(-5, -5), size + Vector2(10, 10))
	
	# Check if mouse is inside the slot (with smaller buffer)
	if buffered_rect.has_point(mouse_pos):
		if not mouse_inside:
			mouse_inside = true
			_show_tooltip()
	else:
		if mouse_inside:
			mouse_inside = false
			_hide_tooltip()
			return  # Exit early to prevent further processing
	
	# Additional safety: check if mouse is actually within the visual slot bounds
	if mouse_inside:
		var visual_rect = Rect2(Vector2.ZERO, size)
		if not visual_rect.has_point(mouse_pos):
			mouse_inside = false
			_hide_tooltip()
			return
	
	# Force tooltip update if we're inside and have an item
	# This ensures tooltips switch properly between slots
	if mouse_inside and player_inventory and player_inventory.get_equipment().has(slot_name):
		var equipment = player_inventory.get_equipment()
		var item = equipment[slot_name]
		if item != null and not is_being_dragged_from:
			# Check if we need to update the tooltip
			var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
			if tooltip_manager and tooltip_manager.current_item != item:
				# Check cooldown to prevent frequent updates
				var current_time = Time.get_ticks_msec()
				if current_time - last_tooltip_update_time >= tooltip_update_cooldown:
					last_tooltip_update_time = current_time
					_show_tooltip()
		else: # No item in this slot, hide tooltip
			var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
			if tooltip_manager and tooltip_manager.tooltip_visible:
				_hide_tooltip()
	
	# More aggressive safety: if mouse is far from slot center, force cleanup
	if mouse_inside:
		var slot_center = size / 2
		var distance_from_center = (mouse_pos - slot_center).length()
		var max_distance = max(size.x, size.y) * 0.4  # 40% of slot size (very aggressive)
		
		if distance_from_center > max_distance:
			mouse_inside = false
			_hide_tooltip()

func _show_tooltip():
	"""Show tooltip when mouse enters the slot"""
	# Check if equipment UI is visible
	var equipment_ui = get_tree().get_first_node_in_group("EquipmentUI")
	if equipment_ui and not equipment_ui.visible:
		return
	
	# Check if we have an item and are not being dragged from
	if player_inventory and player_inventory.get_equipment().has(slot_name) and not is_being_dragged_from:
		var equipment = player_inventory.get_equipment()
		var item = equipment[slot_name]
		if item != null:
			# Use the tooltip manager from the scene
			var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
			if tooltip_manager:
				tooltip_manager.show_tooltip(item)

func _hide_tooltip():
	"""Hide tooltip when mouse exits the slot"""
	# Use the tooltip manager from the scene
	var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
	if tooltip_manager:
		tooltip_manager.hide_tooltip()

func force_cleanup_tooltip():
	"""Force cleanup tooltip when slot item changes"""
	if mouse_inside:
		var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
		if tooltip_manager and tooltip_manager.tooltip_visible:
			tooltip_manager.force_cleanup()
			mouse_inside = false  # Reset mouse state
