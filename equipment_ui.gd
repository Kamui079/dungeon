extends Control

@export var inventory_ui: Control

# Map equipment slot types to scene node names
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
	# Add to group for other scripts to find
	add_to_group("EquipmentUI")
	
	print("DEBUG: EquipmentUI _ready() called")
	print("DEBUG: Current node path: ", get_path())
	print("DEBUG: Current node name: ", name)
	
	# Debug: List all children to see what's available
	print("DEBUG: All children of EquipmentRoot:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	# Connect close button
	var close_button = $"EquipmentPanel/EquipmentPanel_VBoxContainer#CloseButton"
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		print("DEBUG: Close button connected")
	else:
		print("ERROR: Close button not found!")
	
	# Connect all equipment slots to drag and drop system
	for slot_type in slot_buttons.keys():
		var slot = slot_buttons[slot_type]
		if slot:
			slot.set_meta("slot_type", slot_type)
			slot.connect("gui_input", Callable(self, "_on_slot_gui_input").bind(slot))
			slot.connect("can_drop_data", Callable(self, "_on_slot_can_drop_data").bind(slot))
			slot.connect("drop_data", Callable(self, "_on_slot_drop_data").bind(slot))
			slot.connect("get_drag_data", Callable(self, "_on_get_drag_data").bind(slot))
			print("Connected equipment slot: ", slot_type)
		else:
			print("ERROR: Equipment slot not found: ", slot_type)
			print("DEBUG: Tried to find: ", $"EquipmentPanel_VBoxContainer_MainContainer_CharacterContainer_CharacterDisplay#HelmetSlot")
	
	_update_all_slots()
	
	# Add some starting equipment for testing
	add_starting_equipment()

func _update_all_slots():
	"""Update all equipment slot displays"""
	for slot_type in slot_buttons.keys():
		var slot = slot_buttons[slot_type]
		if slot:
			_update_slot(slot)


# -----------------------
# DRAG/DROP
# -----------------------
func _on_get_drag_data(slot):
	var item_data = slot.get_meta("item_data")
	if not item_data:
		return null

	# For Control nodes, the drag preview is handled automatically
	# We just return the data and let Godot handle the visual feedback

	return {
		"source": "equipment",
		"slot": slot,
		"item_data": item_data
	}

func _on_slot_can_drop_data(slot, data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("item_data"):
		return false
	
	var target_type = slot.get_meta("slot_type")
	var dragged_item = data["item_data"]["item"]
	
	# Check if the dragged item can be equipped in this slot
	if dragged_item.has_method("can_equip_in_slot"):
		return dragged_item.can_equip_in_slot(target_type)
	elif dragged_item.get("slot") != null:
		# Convert EQUIP_SLOT enum to slot name for comparison
		var slot_enum = dragged_item.get("slot")
		match slot_enum:
			Equipment.EQUIP_SLOT.HEAD: return target_type == "helmet"
			Equipment.EQUIP_SLOT.CHEST: return target_type == "chest"
			Equipment.EQUIP_SLOT.HANDS: return target_type == "gloves"
			Equipment.EQUIP_SLOT.FEET: return target_type == "boots"
			Equipment.EQUIP_SLOT.WEAPON: return target_type == "weapon"
			Equipment.EQUIP_SLOT.LEGS: return target_type == "legs"
			Equipment.EQUIP_SLOT.ACCESSORY: return target_type == "necklace"
			Equipment.EQUIP_SLOT.SHIELD: return target_type == "shield"
			Equipment.EQUIP_SLOT.RING1: return target_type == "ring1"
			Equipment.EQUIP_SLOT.RING2: return target_type == "ring2"
			Equipment.EQUIP_SLOT.NECKLACE: return target_type == "necklace"
			Equipment.EQUIP_SLOT.CLOAK: return target_type == "cloak"
			Equipment.EQUIP_SLOT.BELT: return target_type == "belt"
	
	return false

func _on_slot_drop_data(slot, data):
	if not _on_slot_can_drop_data(slot, data):
		return
	
	var new_item = data["item_data"]
	var old_item = slot.get_meta("item_data")
	var player = get_tree().get_first_node_in_group("Player")

	# Unequip old item if it exists
	if old_item and old_item.has("item") and player:
		var old_item_obj = old_item["item"]
		if old_item_obj.has_method("on_unequip"):
			old_item_obj.on_unequip(player)

	# Equip new item
	if new_item and new_item.has("item") and player:
		var new_item_obj = new_item["item"]
		if new_item_obj.has_method("on_equip"):
			new_item_obj.on_equip(player)

	# Clear origin slot if dragging from inventory
	if data["source"] == "inventory":
		var from_slot = data["slot"]
		if old_item:
			from_slot.set_meta("item_data", old_item)
		else:
			from_slot.set_meta("item_data", null)
		# Update the inventory slot display
		if inventory_ui.has_method("_update_slot"):
			inventory_ui._update_slot(from_slot)
		elif inventory_ui.has_method("update_display"):
			inventory_ui.update_display(inventory_ui._get_inventory_items())
	elif data["source"] == "equipment":
		var from_slot = data["slot"]
		if old_item:
			from_slot.set_meta("item_data", old_item)
		else:
			from_slot.set_meta("item_data", null)
		_update_slot(from_slot)

	slot.set_meta("item_data", new_item)
	_update_slot(slot)
	
	print("Item equipped to slot: ", slot.get_meta("slot_type"))


# -----------------------
# RIGHT CLICK
# -----------------------
func _on_slot_gui_input(event: InputEvent, slot):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var item_data = slot.get_meta("item_data")
		if not item_data:
			return
		
		var player = get_tree().get_first_node_in_group("Player")
		
		# Unequip the item
		if item_data.has("item") and player:
			var item_obj = item_data["item"]
			if item_obj.has_method("on_unequip"):
				item_obj.on_unequip(player)
		
		# Send to inventory
		if inventory_ui.has_method("add_item"):
			var item = item_data.get("item", null)
			var quantity = item_data.get("quantity", 1)
			if item:
				inventory_ui.add_item(item, quantity)
				slot.set_meta("item_data", null)
				_update_slot(slot)
				print("Item unequipped and sent to inventory: ", item.name)
		else:
			print("ERROR: Inventory UI doesn't have add_item method")


# -----------------------
# UPDATE SLOTS
# -----------------------

func _update_slot(slot):
	var item_data = slot.get_meta("item_data")
	
	# Find the icon TextureRect in this slot
	var icon = slot.get_node_or_null("Icon")
	if not icon:
		# Create icon if it doesn't exist
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -32
		icon.offset_top = -32
		icon.offset_right = 32
		icon.offset_bottom = 32
		slot.add_child(icon)
	
	if item_data and item_data.has("item") and item_data["item"].icon:
		icon.texture = item_data["item"].icon
		icon.tooltip_text = _create_item_tooltip(item_data["item"])
	else:
		icon.texture = null
		icon.tooltip_text = ""

func _create_item_tooltip(item: Resource) -> String:
	"""Create a tooltip for an equipment item"""
	var tooltip = ""
	
	if item.get("name") != null:
		tooltip += item.name + "\n"
	if item.get("description") != null:
		tooltip += item.description + "\n"
	
	# Add equipment stats if available
	if item.get("armor_value") != null and item.armor_value > 0:
		tooltip += "Armor: " + str(item.armor_value) + "\n"
	if item.get("damage_value") != null and item.damage_value > 0:
		tooltip += "Damage: " + str(item.damage_value) + "\n"
	if item.get("stat_bonuses") != null:
		for stat_name in item.stat_bonuses:
			var bonus = item.stat_bonuses[stat_name]
			tooltip += stat_name.capitalize() + ": +" + str(bonus) + "\n"
	
	return tooltip

# Function to be called from inventory UI for right-click auto-equip
func handle_inventory_right_click_equip(item_data: Dictionary) -> void:
	"""Handle right-click auto-equip from inventory"""
	print("Inventory right-click auto-equip requested")
	auto_equip_from_inventory(item_data)

func auto_equip_from_inventory(item_data: Dictionary) -> void:
	"""Auto-equip an item from inventory to the appropriate slot"""
	var item = item_data.get("item", null)
	if not item:
		return
	
	# Find the appropriate slot for this item
	var target_slot_name = ""
	if item.has_method("get_slot_name"):
		target_slot_name = item.get_slot_name()
	elif item.get("slot") != null:
		# Convert EQUIP_SLOT enum to slot name
		var slot_enum = item.get("slot")
		match slot_enum:
			Equipment.EQUIP_SLOT.HEAD: target_slot_name = "helmet"
			Equipment.EQUIP_SLOT.CHEST: target_slot_name = "chest"
			Equipment.EQUIP_SLOT.HANDS: target_slot_name = "gloves"
			Equipment.EQUIP_SLOT.FEET: target_slot_name = "boots"
			Equipment.EQUIP_SLOT.WEAPON: target_slot_name = "weapon"
			Equipment.EQUIP_SLOT.LEGS: target_slot_name = "legs"
			Equipment.EQUIP_SLOT.ACCESSORY: target_slot_name = "necklace"
			Equipment.EQUIP_SLOT.SHIELD: target_slot_name = "shield"
			Equipment.EQUIP_SLOT.RING1: target_slot_name = "ring1"
			Equipment.EQUIP_SLOT.RING2: target_slot_name = "ring2"
			Equipment.EQUIP_SLOT.NECKLACE: target_slot_name = "necklace"
			Equipment.EQUIP_SLOT.CLOAK: target_slot_name = "cloak"
			Equipment.EQUIP_SLOT.BELT: target_slot_name = "belt"
	
	if target_slot_name == "":
		print("Cannot determine slot for item: ", item.name if item.get("name") != null else "Unknown")
		return
	
	# Find the target slot by name
	var target_slot = slot_buttons.get(target_slot_name)
	if target_slot:
		# Check if slot is occupied
		var current_item_data = target_slot.get_meta("item_data", {})
		if current_item_data.size() > 0:
			# Slot is occupied - swap items
			print("Swapping items in slot: ", target_slot_name)
			# Send current item back to inventory
			if inventory_ui.has_method("add_item"):
				var current_item = current_item_data.get("item", null)
				var current_quantity = current_item_data.get("quantity", 1)
				if current_item:
					inventory_ui.add_item(current_item, current_quantity)
		
		# Equip the new item
		target_slot.set_meta("item_data", item_data)
		_update_slot(target_slot)
		
		# Apply equipment stats to player
		var player = get_tree().get_first_node_in_group("Player")
		if player and item.has_method("on_equip"):
			item.on_equip(player)
		
		print("Auto-equipped item to slot: ", target_slot_name)
	else:
		print("Target slot not found: ", target_slot_name)

func _on_close_pressed():
	"""Handle close button press"""
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func process_pending_inventory_items():
	"""Process any items that were unequipped while inventory was closed"""
	# This function can be expanded later to handle pending items
	pass

func toggle_equipment_panel() -> void:
	"""Toggle the equipment panel visibility"""
	if visible:
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func add_starting_equipment():
	"""Add some basic starting equipment to the slots for testing"""
	print("Adding starting equipment...")
	
	# Create a basic helmet
	var helmet = Equipment.new()
	helmet.name = "Light Helm"
	helmet.description = "A simple light helmet that provides basic protection."
	helmet.item_type = Item.ITEM_TYPE.EQUIPMENT
	helmet.slot = Equipment.EQUIP_SLOT.HEAD
	helmet.armor_value = 2
	helmet.stat_bonuses = {"strength": 1}
	helmet.icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/delapouite/light-helm.png")
	
	# Create a basic chest piece
	var chest = Equipment.new()
	chest.name = "Leather Armor"
	chest.description = "A basic leather armor for protection."
	chest.item_type = Item.ITEM_TYPE.EQUIPMENT
	chest.slot = Equipment.EQUIP_SLOT.CHEST
	chest.armor_value = 3
	chest.stat_bonuses = {"strength": 2}
	chest.icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/delapouite/leather-armor.png")
	
	# Create basic gloves
	var gloves = Equipment.new()
	gloves.name = "Leather Gloves"
	gloves.description = "Simple leather gloves."
	gloves.item_type = Item.ITEM_TYPE.EQUIPMENT
	gloves.slot = Equipment.EQUIP_SLOT.HANDS
	gloves.armor_value = 1
	gloves.stat_bonuses = {"dexterity": 1}
	gloves.icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/delapouite/gloves.png")
	
	# Create basic boots
	var boots = Equipment.new()
	boots.name = "Metal Boots"
	boots.description = "Basic metal boots for walking."
	boots.item_type = Item.ITEM_TYPE.EQUIPMENT
	boots.slot = Equipment.EQUIP_SLOT.FEET
	boots.armor_value = 1
	boots.stat_bonuses = {"speed": 1}
	boots.icon = preload("res://Models/armor.png/icons/ffffff/transparent/1x1/delapouite/metal-boot.png")
	
	# Equip the items
	var helmet_data = {"item": helmet, "quantity": 1}
	var chest_data = {"item": chest, "quantity": 1}
	var gloves_data = {"item": gloves, "quantity": 1}
	var boots_data = {"item": boots, "quantity": 1}
	
	# Find the appropriate slots and equip
	var helmet_slot = slot_buttons.get("helmet")
	var chest_slot = slot_buttons.get("chest")
	var gloves_slot = slot_buttons.get("gloves")
	var boots_slot = slot_buttons.get("boots")
	
	if helmet_slot:
		helmet_slot.set_meta("item_data", helmet_data)
		_update_slot(helmet_slot)
	if chest_slot:
		chest_slot.set_meta("item_data", chest_data)
		_update_slot(chest_slot)
	if gloves_slot:
		gloves_slot.set_meta("item_data", gloves_data)
		_update_slot(gloves_slot)
	if boots_slot:
		boots_slot.set_meta("item_data", boots_data)
		_update_slot(boots_slot)
	
	print("Starting equipment added!")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			toggle_equipment_panel()
		elif event.keycode == KEY_ESCAPE:
			hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
