# EquipmentSlot.gd
# A custom Panel class that handles drag and drop for equipment slots
extends Panel

var slot_name: String = ""
var player_inventory: Node
var tooltip: Control = null

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	
	# Find or create tooltip (delayed to avoid setup conflicts)
	call_deferred("_find_or_create_tooltip")

func _find_or_create_tooltip():
	"""Find existing tooltip or create a new one"""
	# Look for existing tooltip in the scene tree
	tooltip = get_tree().get_first_node_in_group("ItemTooltip")
	
	# If no tooltip exists, create one
	if not tooltip:
		var tooltip_scene = load("res://UI/item_tooltip.tscn")
		if tooltip_scene:
			tooltip = tooltip_scene.instantiate()
			tooltip.add_to_group("ItemTooltip")
			# Use call_deferred to avoid the "Parent node is busy" error
			get_tree().root.add_child.call_deferred(tooltip)
			print("Created new tooltip instance for equipment slot")

func _get_drag_data(_at_position: Vector2) -> Variant:
	if player_inventory and player_inventory.get_equipment().has(slot_name):
		var equipment = player_inventory.get_equipment()
		var item = equipment[slot_name]
		if item != null:
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
						print("Dropping ", bag_item.name, " from bag to ", slot_name, " slot")
						player_inventory._swap_bag_and_equipment(from_slot, slot_name)
					else:
						print("Cannot equip ", bag_item.name, " to ", slot_name, " slot (requires ", required_slot, ")")
		
		elif source == "equipment":
			# Dropping from equipment to equipment (swap)
			if from_slot != slot_name:
				print("Swapping equipment from ", from_slot, " to ", slot_name)
				_swap_equipment_slots(from_slot, slot_name)

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
			print("Cannot equip ", from_item.name, " to ", to_slot, " slot (requires ", from_slot_type, ")")
			return
	
	if to_item != null and to_item.has_method("get_slot_name"):
		var to_slot_type = to_item.get_slot_name()
		if to_slot_type != from_slot:
			print("Cannot equip ", to_item.name, " to ", from_slot, " slot (requires ", to_slot_type, ")")
			return
	
	# If both slots are empty, nothing to swap
	if from_item == null and to_item == null:
		print("Both slots are empty - nothing to swap")
		return
	
	# If one slot is empty, just move the item
	if from_item == null:
		print("Moving ", to_item.name, " from ", to_slot, " to ", from_slot)
		equipment[from_slot] = to_item
		equipment[to_slot] = null
		player_inventory.inventory_changed.emit()
		return
	
	if to_item == null:
		print("Moving ", from_item.name, " from ", from_slot, " to ", to_slot)
		equipment[from_slot] = null
		equipment[to_slot] = from_item
		player_inventory.inventory_changed.emit()
		return
	
	# Both slots have items - swap them
	print("Swapping ", from_item.name, " and ", to_item.name, " between ", from_slot, " and ", to_slot)
	
	# Use a simple swap approach
	var temp = equipment[from_slot]
	equipment[from_slot] = equipment[to_slot]
	equipment[to_slot] = temp
	
	print("Successfully swapped items between ", from_slot, " and ", to_slot)
	# Emit signal to update display
	player_inventory.inventory_changed.emit()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if player_inventory and player_inventory.get_equipment().has(slot_name):
			var equipment = player_inventory.get_equipment()
			if equipment[slot_name] != null:
				player_inventory.handle_right_click(-1, slot_name)
				get_viewport().set_input_as_handled()

func _mouse_entered():
	"""Show tooltip when mouse enters the slot"""
	if tooltip and player_inventory and player_inventory.get_equipment().has(slot_name):
		var equipment = player_inventory.get_equipment()
		var item = equipment[slot_name]
		if item != null:
			tooltip.show_tooltip(item)

func _mouse_exited():
	"""Hide tooltip when mouse exits the slot"""
	if tooltip:
		tooltip.hide_tooltip()
