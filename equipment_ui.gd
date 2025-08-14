extends Control

var player_inventory: Node

# Map equipment slot types to the button nodes
@onready var slot_buttons := {
	"helmet": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#HelmetSlot",
	"necklace": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#NecklaceSlot",
	"cloak": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#CloakSlot",
	"chest": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#ChestSlot",
	"gloves": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#GlovesSlot",
	"boots": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#BootsSlot",
	"ring1": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay_RingSlots#Ring1Slot",
	"ring2": $"EquipmentPanel/EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay_RingSlots#Ring2Slot"
}

func _ready():
	add_to_group("EquipmentUI") # Keep group for easy access if needed

	# Wait for the PlayerInventory node
	await get_tree().process_frame
	player_inventory = get_tree().get_first_node_in_group("PlayerInventory")
	if player_inventory:
		player_inventory.connect("inventory_changed", _on_inventory_changed)
	else:
		print("ERROR: EquipmentUI could not find PlayerInventory!")
		return

	# Connect signals for each slot
	for slot_name in slot_buttons:
		var slot_node = slot_buttons[slot_name]
		if slot_node:
			slot_node.set_meta("slot_name", slot_name)
			slot_node.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot_node))
			# Connect drag/drop signals here if not done in the editor
		else:
			print("ERROR: Equipment slot node not found for: ", slot_name)

	_update_display()

func _on_inventory_changed():
	_update_display()

func _update_display():
	if not player_inventory:
		return

	var equipment = player_inventory.get_equipment()
	for slot_name in slot_buttons:
		var slot_node = slot_buttons[slot_name]
		var icon_node = slot_node.get_node_or_null("Icon") # Assuming icons are named "Icon"

		if not icon_node: # Create icon if it doesn't exist
			icon_node = TextureRect.new()
			icon_node.name = "Icon"
			icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot_node.add_child(icon_node)
			icon_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		if equipment.has(slot_name) and not equipment[slot_name].is_empty():
			var item_data = equipment[slot_name]
			icon_node.texture = item_data.item.icon
			# You could add tooltip logic here
		else:
			icon_node.texture = null
			# Clear tooltip

func toggle_equipment_panel():
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			toggle_equipment_panel()

# --- Drag and Drop ---

func _on_get_drag_data(slot):
	var slot_name = slot.get_meta("slot_name")
	if player_inventory.get_equipment().has(slot_name) and not player_inventory.get_equipment()[slot_name].is_empty():
		var item_data = player_inventory.get_equipment()[slot_name]
		
		var drag_preview = TextureRect.new()
		drag_preview.texture = item_data.item.icon
		set_drag_preview(drag_preview)

		return {
			"source": "equipment",
			"from_slot": slot_name
		}
	return null

func _on_slot_can_drop_data(slot, data):
	# Allow the drop. PlayerInventory will validate it.
	return data is Dictionary and data.has("source")

func _on_slot_drop_data(slot, data):
	var to_slot_name = slot.get_meta("slot_name")
	player_inventory.handle_drop_data(data, -1, to_slot_name)


# --- Right Click ---

func _on_slot_gui_input(event: InputEvent, slot):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var slot_name = slot.get_meta("slot_name")
		if player_inventory.get_equipment().has(slot_name) and not player_inventory.get_equipment()[slot_name].is_empty():
			player_inventory.handle_right_click(-1, slot_name)
