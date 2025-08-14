extends Panel

var slot_index: int = -1
var player_inventory: Node
var is_dragging: bool = false
var drag_start_slot: int = -1

func _ready():
	# Set slot_index based on position in GridContainer
	var grid_container = get_parent()
	if grid_container and grid_container is GridContainer:
		slot_index = get_index()
		print("Auto-set slot_index to ", slot_index, " for ", name)
	else:
		print("Could not find GridContainer parent for ", name)
	
	print("Inventory slot ", slot_index, " _ready() called")
	
	# Get the player inventory reference
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	print("Player inventory found: ", player_inventory != null)
	
	# Connect to gui_input for input events
	connect("gui_input", Callable(self, "_on_gui_input"))
	print("Connected gui_input signal for slot ", slot_index)
	
	# Enable mouse filtering for this panel to receive input events
	mouse_filter = Control.MOUSE_FILTER_STOP
	print("Set mouse_filter to MOUSE_FILTER_STOP for slot ", slot_index)

func _on_gui_input(event: InputEvent):
	print("Slot ", slot_index, " received input event: ", event)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Right-click to consume items
		print("Right-click on slot ", slot_index)
		if player_inventory and slot_index >= 0:
			player_inventory.handle_right_click(slot_index, "")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Left-click to start drag
		print("Left-click on slot ", slot_index)
		if player_inventory and slot_index >= 0:
			var bag = player_inventory.get_bag()
			if bag.has(slot_index):
				var item_data = bag[slot_index]
				if item_data and item_data.item:
					is_dragging = true
					drag_start_slot = slot_index
					print("Starting drag from slot ", slot_index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Left-click release to end drag
		print("Left-click release on slot ", slot_index)
		if is_dragging and drag_start_slot != slot_index:
			# Move item from drag_start_slot to current slot
			if player_inventory and drag_start_slot >= 0 and slot_index >= 0:
				var drag_data = { "source": "bag", "from_slot": drag_start_slot }
				player_inventory.handle_drop_data(drag_data, slot_index, "")
				print("Dropped item from slot ", drag_start_slot, " to slot ", slot_index)
		
		is_dragging = false
		drag_start_slot = -1
