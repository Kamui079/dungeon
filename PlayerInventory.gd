class_name PlayerInventory
extends Node

signal inventory_changed

var bag: Dictionary = {}
var equipment: Dictionary = { "helmet": null, "necklace": null, "cloak": null, "chest": null, "gloves": null, "boots": null, "ring1": null, "ring2": null }
const MAX_BAG_SLOTS = 24

# Bag dragging support
var is_dragging_from_bag: bool = false
var dragged_bag_item: Resource = null
var dragged_bag_slot: int = -1

func _ready():
	add_to_group("PlayerInventory")

func get_bag() -> Dictionary: return bag
func get_equipment() -> Dictionary: return equipment

func add_item_to_bag(item: Resource, quantity: int = 1) -> int:
	print("add_item_to_bag: Adding ", quantity, "x ", item.name, " (max_stack: ", item.max_stack, ")")
	var remaining_quantity = quantity
	
	# Try to stack with existing items of the same type
	if item.max_stack > 1:
		print("add_item_to_bag: Attempting to stack with existing items...")
		for i in range(MAX_BAG_SLOTS):
			if bag.has(i):
				var existing_item = bag[i].item
				print("add_item_to_bag: Checking slot ", i, " for stacking with ", existing_item.name)
				# Check if items are the same type by comparing name and properties
				if _are_items_same_type(existing_item, item):
					var can_add = item.max_stack - bag[i].quantity
					print("add_item_to_bag: Items are same type, can add ", can_add, " more")
					if can_add > 0:
						var amount_to_add = min(remaining_quantity, can_add)
						bag[i].quantity += amount_to_add
						remaining_quantity -= amount_to_add
						print("add_item_to_bag: Added ", amount_to_add, " to slot ", i, ", remaining: ", remaining_quantity)
						if remaining_quantity <= 0: break
	
	# Add remaining quantity to new slots
	if remaining_quantity > 0:
		print("add_item_to_bag: Adding ", remaining_quantity, " to new slots...")
		for i in range(MAX_BAG_SLOTS):
			if not bag.has(i):
				var amount_in_new_stack = min(remaining_quantity, item.max_stack)
				bag[i] = { "item": item, "quantity": amount_in_new_stack }
				remaining_quantity -= amount_in_new_stack
				print("add_item_to_bag: Created new stack in slot ", i, " with ", amount_in_new_stack, " items")
				print("add_item_to_bag: Slot ", i, " now contains: ", bag[i])
				if remaining_quantity <= 0: break
	
	print("add_item_to_bag: Final remaining quantity: ", remaining_quantity)
	inventory_changed.emit()
	return remaining_quantity

func _are_items_same_type(item1: Resource, item2: Resource) -> bool:
	"""Check if two items are the same type for stacking purposes"""
	if not item1 or not item2:
		print("_are_items_same_type: One or both items are null")
		return false
	
	# If both have resource paths, compare them
	if item1.resource_path and item2.resource_path:
		var same = item1.resource_path == item2.resource_path
		print("_are_items_same_type: Comparing resource paths - ", item1.name, " vs ", item2.name, " = ", same)
		return same
	
	# For dynamically created items, compare by name and type
	if item1.name == item2.name and item1.item_type == item2.item_type:
		# For equipment, also check the slot
		if item1.item_type == Item.ITEM_TYPE.EQUIPMENT:
			var same = item1.slot == item2.slot
			print("_are_items_same_type: Equipment comparison - ", item1.name, " vs ", item2.name, " = ", same)
			return same
		# For consumables, check if they're the same type
		elif item1.item_type == Item.ITEM_TYPE.CONSUMABLE:
			var same = item1.consumable_type == item2.consumable_type
			print("_are_items_same_type: Consumable comparison - ", item1.name, " vs ", item2.name, " = ", same)
			return same
	
	print("_are_items_same_type: Items are different - ", item1.name, " vs ", item2.name)
	return false

func handle_right_click(bag_slot: int, equipment_slot: String):
	if bag_slot != -1 and bag.has(bag_slot):
		var item_resource = bag[bag_slot].item
		if item_resource.item_type == Item.ITEM_TYPE.CONSUMABLE: _consume_item(bag_slot)
		else: _equip_item_from_bag(bag_slot)
	elif equipment_slot != "" and equipment.has(equipment_slot) and equipment[equipment_slot] != null:
		for i in range(MAX_BAG_SLOTS):
			if not bag.has(i):
				_unequip_item_to_bag(equipment_slot, i)
				break
func handle_drop_data(data: Dictionary, to_bag_slot: int, to_equipment_slot: String):
	var source = data.get("source"); var from_slot = data.get("from_slot")
	if source == "bag" and to_bag_slot != -1: _move_item_in_bag(from_slot, to_bag_slot)
	elif source == "bag" and to_equipment_slot != "": _swap_bag_and_equipment(from_slot, to_equipment_slot)
	elif source == "equipment" and to_bag_slot != -1: _unequip_item_to_bag(from_slot, to_bag_slot)
	elif source == "equipment" and to_equipment_slot != "": _swap_equipment_slots(from_slot, to_equipment_slot)
func _consume_item(bag_slot: int):
	var item_resource = bag[bag_slot].item; var player_node = get_parent()
	
	# Check if we're in combat
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager and combat_manager.in_combat:
		# Queue the item usage for combat
		print("In combat - queuing item usage: ", item_resource.name)
		combat_manager.queue_item_usage(item_resource.name)
		return
	
	# Not in combat - use item immediately
	if item_resource.use(player_node):
		bag[bag_slot].quantity -= 1
		if bag[bag_slot].quantity <= 0: bag.erase(bag_slot)
		inventory_changed.emit()

func has_item(item_name: String) -> bool:
	"""Check if the player has a specific item in their bag"""
	for slot in bag:
		if bag[slot].item.name == item_name:
			return true
	return false
func _move_item_in_bag(from_slot: int, to_slot: int):
	if from_slot == to_slot or not bag.has(from_slot): return
	var from_item = bag[from_slot]
	if bag.has(to_slot):
		var to_item = bag[to_slot]; bag[to_slot] = from_item; bag[from_slot] = to_item
	else:
		bag.erase(from_slot); bag[to_slot] = from_item
	inventory_changed.emit()
func _get_item_slot_name(item: Resource) -> String:
	if item and item.has_method("get_slot_name"):
		return item.get_slot_name()
	elif item and item.has("equipment_slot"):
		return item.equipment_slot
	return ""
func _equip_item_from_bag(bag_slot: int):
	if not bag.has(bag_slot): return
	var item_to_equip_data = bag[bag_slot]
	var equipment_slot_name = _get_item_slot_name(item_to_equip_data.item)
	if equipment.has(equipment_slot_name): _swap_bag_and_equipment(bag_slot, equipment_slot_name)
func _unequip_item_to_bag(equipment_slot_name: String, to_bag_slot: int):
	if not equipment.has(equipment_slot_name) or equipment[equipment_slot_name] == null: return
	if bag.has(to_bag_slot): return
	var item_to_unequip = equipment[equipment_slot_name]
	equipment[equipment_slot_name] = null; bag[to_bag_slot] = { "item": item_to_unequip, "quantity": 1 }
	inventory_changed.emit()
func _swap_bag_and_equipment(bag_slot: int, equipment_slot_name: String):
	if not bag.has(bag_slot): return
	var item_in_bag = bag[bag_slot]
	var slot_name = _get_item_slot_name(item_in_bag.item)
	print("Attempting to equip item from bag slot ", bag_slot, " to equipment slot ", equipment_slot_name)
	print("Item slot name: ", slot_name)
	print("Target equipment slot: ", equipment_slot_name)
	if slot_name != equipment_slot_name: 
		print("Slot mismatch! Cannot equip ", slot_name, " in ", equipment_slot_name, " slot")
		return
	var item_in_equipment = equipment[equipment_slot_name]
	equipment[equipment_slot_name] = item_in_bag.item
	if item_in_equipment == null: bag.erase(bag_slot)
	else: bag[bag_slot] = { "item": item_in_equipment, "quantity": 1 }
	print("Successfully equipped item to ", equipment_slot_name, " slot")
	inventory_changed.emit()
func _swap_equipment_slots(from_slot: String, to_slot: String):
	if not equipment.has(from_slot) or not equipment.has(to_slot): return
	var from_item = equipment[from_slot]; var to_item = equipment[to_slot]
	equipment[from_slot] = to_item; equipment[to_slot] = from_item
	inventory_changed.emit()

# Bag dragging methods
func start_bag_drag(bag_slot: int):
	if bag.has(bag_slot):
		is_dragging_from_bag = true
		dragged_bag_item = bag[bag_slot].item
		dragged_bag_slot = bag_slot
		print("Started dragging ", dragged_bag_item.name, " from bag slot ", bag_slot)

func clear_bag_drag():
	is_dragging_from_bag = false
	dragged_bag_item = null
	dragged_bag_slot = -1

func get_is_dragging_from_bag() -> bool:
	return is_dragging_from_bag

func get_dragged_bag_item() -> Resource:
	return dragged_bag_item

func get_dragged_bag_slot() -> int:
	return dragged_bag_slot

func equip_item_from_bag(item: Resource, equipment_slot: String):
	"""Equip an item directly from bag drag to equipment slot"""
	if not equipment.has(equipment_slot):
		print("Invalid equipment slot: ", equipment_slot)
		return
	
	# Remove item from bag
	if dragged_bag_slot != -1 and bag.has(dragged_bag_slot):
		bag.erase(dragged_bag_slot)
	
	# Equip item
	equipment[equipment_slot] = item
	print("Equipped ", item.name, " to ", equipment_slot, " slot")
	
	# Clear drag state
	clear_bag_drag()
	
	# Emit signal
	inventory_changed.emit()

func _move_equipment_item(from_slot: String, to_slot: String):
	"""Move an equipment item from one slot to another"""
	if not equipment.has(from_slot) or not equipment.has(to_slot):
		return
	
	var item = equipment[from_slot]
	if item == null:
		return
	
	# Check if the target slot can accept this item
	if item.has_method("get_slot_name"):
		var required_slot = item.get_slot_name()
		if required_slot != to_slot:
			print("Cannot move ", item.name, " to ", to_slot, " slot (requires ", required_slot, ")")
			return
	
	# Move the item
	equipment[from_slot] = null
	equipment[to_slot] = item
	print("Moved ", item.name, " from ", from_slot, " to ", to_slot)
	
	# Emit signal
	inventory_changed.emit()
