extends Control

@export var items_container: Control

var inventory_slots: Array[Control] = []
var player_inventory: Node

func _ready():
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

	for i in range(items_container.get_child_count()):
		var slot_node = items_container.get_child(i)
		if slot_node is Control:
			inventory_slots.append(slot_node)
			slot_node.set_meta("slot_index", i)
			slot_node.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot_node))

	_update_display()
	hide()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_I:
			toggle_panel()

func toggle_panel():
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _on_inventory_changed():
	_update_display()

func _update_display():
	if not player_inventory: return

	var bag = player_inventory.get_bag()
	for i in range(inventory_slots.size()):
		var slot_node = inventory_slots[i]
		var icon_rect = _get_or_create_icon_rect(slot_node)
		# NOTE: Quantity Label logic is complex to add without seeing the scene.
		# This version focuses on getting the icons correct first.

		if bag.has(i):
			var item_data = bag[i]
			icon_rect.texture = item_data.item.icon
		else:
			icon_rect.texture = null

func _get_or_create_icon_rect(slot_node: Control) -> TextureRect:
	var icon_rect = slot_node.get_node_or_null("Icon") as TextureRect
	if not icon_rect:
		icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_node.add_child(icon_rect)
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return icon_rect

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

func can_drop_data(_at_position, data, _to_slot_node):
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
