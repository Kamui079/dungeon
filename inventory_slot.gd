extends Panel

var slot_index: int = -1
var player_inventory: Node
var is_dragging: bool = false

func _ready():
	slot_index = get_index()
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	mouse_filter = MOUSE_FILTER_STOP

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

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed == false:
		# Check if this was a drag that was cancelled (mouse released without dropping)
		if is_dragging and not player_inventory.get_is_dragging_from_bag():
			# Show the icon again if drag was cancelled
			var icon_rect = find_child("Icon") as TextureRect
			if icon_rect:
				icon_rect.visible = true
			is_dragging = false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if player_inventory and player_inventory.bag.has(slot_index):
			player_inventory.handle_right_click(slot_index, "")
			get_viewport().set_input_as_handled()
