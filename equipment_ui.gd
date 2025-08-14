extends Control

@export_group("Slot References")
@export var helmet_slot: Panel
@export var necklace_slot: Panel
@export var cloak_slot: Panel
@export var chest_slot: Panel
@export var gloves_slot: Panel
@export var boots_slot: Panel
@export var ring1_slot: Panel
@export var ring2_slot: Panel

var player_inventory: Node
var slot_nodes: Dictionary = {}

func _ready():
	# Wait for the next frame to ensure all nodes are properly initialized
	await get_tree().process_frame
	
	slot_nodes = {
		"helmet": helmet_slot, "necklace": necklace_slot, "cloak": cloak_slot,
		"chest": chest_slot, "gloves": gloves_slot, "boots": boots_slot,
		"ring1": ring1_slot, "ring2": ring2_slot,
	}

	add_to_group("EquipmentUI")

	# Wait another frame to ensure the export variables are properly assigned
	await get_tree().process_frame
	
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	if player_inventory:
		player_inventory.connect("inventory_changed", _on_inventory_changed)
	else:
		printerr("EquipmentUI could not find PlayerInventory!")
		return

	for slot_name in slot_nodes:
		var slot_node = slot_nodes[slot_name]
		if slot_node:
			slot_node.set_meta("slot_name", slot_name)
			slot_node.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot_node))
		else:
			printerr("Equipment slot '", slot_name, "' is not assigned in the editor!")

	_update_display()
	hide()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_C:
			toggle_panel()

func toggle_panel():
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _on_inventory_changed():
	_update_display()

func _update_display():
	if not player_inventory: return

	var equipment = player_inventory.get_equipment()
	for slot_name in slot_nodes:
		var slot_node = slot_nodes[slot_name]
		if not slot_node: continue

		var icon_rect = _get_or_create_icon_rect(slot_node)

		if equipment.has(slot_name) and not equipment[slot_name].is_empty():
			var item_data = equipment[slot_name]
			icon_rect.texture = item_data.item.icon
		else:
			icon_rect.texture = null

func _get_or_create_icon_rect(slot_node: Panel) -> TextureRect:
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
	var slot_name = from_slot_node.get_meta("slot_name")
	if player_inventory.get_equipment().has(slot_name) and not player_inventory.get_equipment()[slot_name].is_empty():
		var item_data = player_inventory.get_equipment()[slot_name]
		
		var drag_preview = TextureRect.new()
		drag_preview.texture = item_data.item.icon
		set_drag_preview(drag_preview)

		return { "source": "equipment", "from_slot": slot_name }
	return null

func can_drop_data(_at_position, data, to_slot_node):
	return data is Dictionary and data.has("source")

func drop_data(_at_position, data, to_slot_node):
	var to_slot_name = to_slot_node.get_meta("slot_name")
	player_inventory.handle_drop_data(data, -1, to_slot_name)

# --- Right Click ---

func _on_slot_gui_input(event: InputEvent, slot_node):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var slot_name = slot_node.get_meta("slot_name")
		if player_inventory.get_equipment().has(slot_name) and not player_inventory.get_equipment()[slot_name].is_empty():
			player_inventory.handle_right_click(-1, slot_name)
