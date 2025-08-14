extends Control

var inventory_slots: Array = []
var player_inventory: Node

func _ready():
	# Wait for the PlayerInventory node to be ready
	await get_tree().process_frame
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	if player_inventory:
		player_inventory.connect("inventory_changed", _on_inventory_changed)
	else:
		print("ERROR: PlayerInventory node not found!")
		return

	# Find all item slots dynamically
	var items_container = $Panel/MarginContainer/VBoxContainer/Items
	for i in range(items_container.get_child_count()):
		var slot = items_container.get_child(i)
		if slot is TextureRect:
			inventory_slots.append(slot)
			slot.set_meta("slot_index", i) # Store the index for later reference
			slot.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot))
			# Drag and drop signals are connected in the editor or should be, but can be done here too
			# Make sure the control has "Mouse -> Filter" set to "Pass" or "Stop" to receive input

	_update_display()


func _on_inventory_changed():
	_update_display()

func _update_display():
	if not player_inventory:
		return

	var bag = player_inventory.get_bag()
	for i in range(inventory_slots.size()):
		var slot_node = inventory_slots[i]
		if bag.has(i):
			var item_data = bag[i]
			slot_node.texture = item_data.item.icon
			# You would also update a quantity label here if you have one
		else:
			slot_node.texture = null
			# Clear quantity label

# --- Drag and Drop ---

func _on_get_drag_data(slot):
	var slot_index = slot.get_meta("slot_index")
	if player_inventory.get_bag().has(slot_index):
		var item_data = player_inventory.get_bag()[slot_index]

		var drag_preview = TextureRect.new()
		drag_preview.texture = item_data.item.icon
		set_drag_preview(drag_preview)

		return {
			"source": "bag",
			"from_slot": slot_index
		}
	return null

func _on_slot_can_drop_data(slot, data):
	# We allow the drop conceptually. The PlayerInventory will decide if it's valid.
	return data is Dictionary and data.has("source")

func _on_drop_data(slot, data):
	var to_slot_index = slot.get_meta("slot_index")
	player_inventory.handle_drop_data(data, to_slot_index, "")

# --- Right Click ---

func _on_slot_gui_input(event: InputEvent, slot):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var slot_index = slot.get_meta("slot_index")
		if player_inventory.get_bag().has(slot_index):
			player_inventory.handle_right_click(slot_index, "")
