extends Control

@export var items_container: Control

var inventory_slots: Array = []
var player_inventory: Node

func _ready():
	# Wait for the PlayerInventory node to be ready
	await get_tree().process_frame
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	if player_inventory:
		player_inventory.connect("inventory_changed", _on_inventory_changed)
	else:
		printerr("InventoryUI could not find PlayerInventory!")
		return

	if not items_container:
		printerr("Items container not assigned in the editor for InventoryUI!")
		return

	# Find all item slots dynamically from the assigned container
	for i in range(items_container.get_child_count()):
		var slot = items_container.get_child(i)
		if slot is TextureRect:
			inventory_slots.append(slot)
			slot.set_meta("slot_index", i) # Store the index for later reference
			# Make sure the control's Mouse -> Filter is set to Pass or Stop in the editor
			slot.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot))

	_update_display()
	# Start hidden
	hide()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_I:
			toggle_panel()

func toggle_panel():
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_inventory_changed():
	_update_display()

func _update_display():
	if not player_inventory:
		return

	var bag = player_inventory.get_bag()
	for i in range(inventory_slots.size()):
		var slot_node = inventory_slots[i]

		# Assuming there's a child node for quantity text, e.g., named "QuantityLabel"
		var quantity_label = slot_node.get_node_or_null("QuantityLabel") as Label

		if bag.has(i):
			var item_data = bag[i]
			slot_node.texture = item_data.item.icon
			if quantity_label:
				if item_data.quantity > 1:
					quantity_label.text = str(item_data.quantity)
					quantity_label.show()
				else:
					quantity_label.hide()
		else:
			slot_node.texture = null
			if quantity_label:
				quantity_label.hide()

# --- Drag and Drop ---

func get_drag_data(from_slot_node):
	var slot_index = from_slot_node.get_meta("slot_index")
	if player_inventory.get_bag().has(slot_index):
		var item_data = player_inventory.get_bag()[slot_index]

		var drag_preview = TextureRect.new()
		drag_preview.texture = item_data.item.icon
		set_drag_preview(drag_preview)

		return { "source": "bag", "from_slot": slot_index }
	return null

func can_drop_data(_at_position, data, to_slot_node):
	return data is Dictionary and data.has("source")

func drop_data(_at_position, data, to_slot_node):
	var to_slot_index = to_slot_node.get_meta("slot_index")
	player_inventory.handle_drop_data(data, to_slot_index, "")

# --- Right Click ---

func _on_slot_gui_input(event: InputEvent, slot_node):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var slot_index = slot_node.get_meta("slot_index")
		if player_inventory.get_bag().has(slot_index):
			player_inventory.handle_right_click(slot_index, "")
