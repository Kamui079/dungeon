# InventorySlot.gd
# A custom Panel class that handles drag and drop for inventory slots
extends Panel
class_name InventorySlot

@export var slot_index: int = 0
@export var player_inventory: PlayerInventory

var is_dragging: bool = false
var mouse_inside: bool = false
var last_tooltip_update_time: int = 0  # Track last tooltip update (in milliseconds)
var tooltip_update_cooldown: int = 50  # 50ms cooldown between tooltip updates

func _ready():
	# Add to group for tooltip cleanup system
	add_to_group("InventorySlot")
	
	# Set mouse filter to pass to receive input events
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Try to get slot_index from parent container if not set
	if slot_index == 0 and get_parent():
		var parent_container = get_parent()
		if parent_container is GridContainer:
			slot_index = get_index()
		elif parent_container.has_method("get_child_index"):
			slot_index = parent_container.get_child_index(self)
	
	# Try to get player_inventory from scene tree if not set
	if not player_inventory:
		player_inventory = get_tree().get_first_node_in_group("PlayerInventory")

func _gui_input(event: InputEvent):
	# Handle mouse motion for custom tooltip detection
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	
	# Handle right-click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if player_inventory and player_inventory.bag.has(slot_index):
				var bag_item = player_inventory.bag[slot_index]
				if bag_item and bag_item.item:
					player_inventory.handle_right_click(slot_index, "")  # bag_slot, empty equipment_slot
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
	if mouse_inside and player_inventory and player_inventory.bag.has(slot_index):
		var bag_item = player_inventory.bag[slot_index]
		if bag_item and bag_item.item:
			var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
			if tooltip_manager and tooltip_manager.current_item != bag_item.item:
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
	# Check if inventory is visible before showing tooltip
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and not inventory_ui.visible:
		return
	
	# Check if we have an item and are not dragging
	if player_inventory and player_inventory.bag.has(slot_index) and not is_dragging:
		var bag_item = player_inventory.bag[slot_index]
		if bag_item and bag_item.item:
			# Use the tooltip manager from the scene
			var tooltip_manager = get_node_or_null("/root/Dungeon/TooltipManager")
			if tooltip_manager:
				tooltip_manager.show_tooltip(bag_item.item)

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

func set_player_inventory(inv: PlayerInventory):
	"""Set the player_inventory reference for this slot"""
	player_inventory = inv

func set_slot_index(index: int):
	"""Set the slot_index for this slot"""
	slot_index = index

func _get_drag_data(_at_position: Vector2) -> Variant:
	if player_inventory and player_inventory.bag.has(slot_index):
		var item_data = player_inventory.bag[slot_index]
		
		# Hide the original icon when dragging starts
		var icon_rect = find_child("Icon") as TextureRect
		if icon_rect:
			icon_rect.visible = false
			is_dragging = true
		
		var preview = TextureRect.new()
		preview.texture = item_data.item.icon
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.size = Vector2(64, 64)
		
		# Fix the drag preview positioning
		# Set the pivot to the center of the preview
		preview.pivot_offset = preview.size / 2.0
		
		# Create a control node to properly position the preview
		var preview_container = Control.new()
		preview_container.size = preview.size
		preview_container.add_child(preview)
		
		# Position the preview with negative offset to compensate for Godot's default positioning
		# This makes the item appear exactly on the cursor
		preview.position = Vector2(-32, -32)  # Half the size to center on cursor
		
		set_drag_preview(preview_container)
		return { "source": "bag", "from_slot": slot_index }
		
	return null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source")

func _drop_data(_at_position: Vector2, data: Variant):
	player_inventory.handle_drop_data(data, slot_index, "")
	# Reset dragging state after drop
	is_dragging = false
