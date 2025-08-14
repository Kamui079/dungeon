class_name PlayerInventory
extends Node

# Signal emitted when the bag or equipment changes
signal inventory_changed

# The player's main inventory
# Dictionary format: { slot_index: { "item": ItemResource, "quantity": int } }
var bag: Dictionary = {}

# The player's equipped items
# Dictionary format: { "slot_name": { "item": ItemResource, "quantity": 1 } }
var equipment: Dictionary = {
	"helmet": {},
	"necklace": {},
	"cloak": {},
	"chest": {},
	"gloves": {},
	"boots": {},
	"ring1": {},
	"ring2": {}
}

const MAX_BAG_SLOTS = 20

func _ready():
	add_to_group("PlayerInventory")
	print("PlayerInventory is ready.")

# --- Public API ---

func get_bag() -> Dictionary:
	return bag

func get_equipment() -> Dictionary:
	return equipment

func add_item_to_bag(item: Resource, quantity: int = 1) -> int:
	var remaining_quantity = quantity

	# First, try to stack with existing items
	if item.max_stack > 1:
		for slot_index in bag:
			var slot_data = bag[slot_index]
			if slot_data.item.resource_path == item.resource_path:
				var can_add = item.max_stack - slot_data.quantity
				if can_add > 0:
					var amount_to_add = min(remaining_quantity, can_add)
					slot_data.quantity += amount_to_add
					remaining_quantity -= amount_to_add
					if remaining_quantity <= 0:
						break

	# If there's still quantity left, find empty slots
	if remaining_quantity > 0:
		var stack_to_add = item.max_stack
		while remaining_quantity > 0:
			var found_slot = false
			for i in range(MAX_BAG_SLOTS):
				if not bag.has(i):
					var amount_in_new_stack = min(remaining_quantity, stack_to_add)
					bag[i] = { "item": item, "quantity": amount_in_new_stack }
					remaining_quantity -= amount_in_new_stack
					found_slot = true
					break
			if not found_slot:
				# No more empty slots
				break

	inventory_changed.emit()
	return remaining_quantity

# --- UI Interaction Handlers ---

func handle_drop_data(data: Dictionary, to_bag_slot: int, to_equipment_slot: String):
	var source = data.source

	if source == "bag":
		var from_bag_slot = data.from_slot
		if to_bag_slot != -1:
			_move_item_in_bag(from_bag_slot, to_bag_slot)
		elif to_equipment_slot != "":
			_swap_bag_and_equipment(from_bag_slot, to_equipment_slot)

	elif source == "equipment":
		var from_equipment_slot = data.from_slot
		if to_bag_slot != -1:
			_unequip_item_to_bag(from_equipment_slot, to_bag_slot)
		elif to_equipment_slot != "":
			_swap_equipment_slots(from_equipment_slot, to_equipment_slot)

func handle_right_click(bag_slot: int, equipment_slot: String):
	if bag_slot != -1:
		_equip_item_from_bag(bag_slot)
	elif equipment_slot != "":
		for i in range(MAX_BAG_SLOTS):
			if not bag.has(i):
				_unequip_item_to_bag(equipment_slot, i)
				break

# --- Internal Logic ---

func _get_item_slot_name(item: Resource) -> String:
	if item.has_method("get_slot_name"):
		return item.get_slot_name()
	if item.equipment_slot != "":
		return item.equipment_slot
	return ""

func _move_item_in_bag(from_slot: int, to_slot: int):
	if from_slot == to_slot or not bag.has(from_slot):
		return

	var item_to_move = bag[from_slot]
	if bag.has(to_slot):
		var other_item = bag[to_slot]
		bag[to_slot] = item_to_move
		bag[from_slot] = other_item
	else:
		bag[to_slot] = item_to_move
		bag.erase(from_slot)

	inventory_changed.emit()

func _equip_item_from_bag(bag_slot: int):
	if not bag.has(bag_slot):
		return

	var item_to_equip_data = bag[bag_slot]
	var equipment_slot_name = _get_item_slot_name(item_to_equip_data.item)

	if equipment.has(equipment_slot_name):
		_swap_bag_and_equipment(bag_slot, equipment_slot_name)

func _unequip_item_to_bag(equipment_slot_name: String, bag_slot: int):
	if not equipment.has(equipment_slot_name) or equipment[equipment_slot_name].is_empty():
		return

	var equipped_item_data = equipment[equipment_slot_name]

	if bag.has(bag_slot):
		var item_in_bag_data = bag[bag_slot]
		if _get_item_slot_name(item_in_bag_data.item) == equipment_slot_name:
			bag[bag_slot] = equipped_item_data
			equipment[equipment_slot_name] = item_in_bag_data
		# else: can't swap, so do nothing.
	else:
		bag[bag_slot] = equipped_item_data
		equipment[equipment_slot_name] = {}

	inventory_changed.emit()

func _swap_bag_and_equipment(bag_slot: int, equipment_slot_name: String):
	if not bag.has(bag_slot) or not equipment.has(equipment_slot_name):
		return

	var item_in_bag_data = bag[bag_slot]
	var equipped_item_data = equipment[equipment_slot_name]

	if _get_item_slot_name(item_in_bag_data.item) == equipment_slot_name:
		equipment[equipment_slot_name] = item_in_bag_data
		if equipped_item_data.is_empty():
			bag.erase(bag_slot)
		else:
			bag[bag_slot] = equipped_item_data

		inventory_changed.emit()

func _swap_equipment_slots(from_slot: String, to_slot: String):
	if not equipment.has(from_slot) or not equipment.has(to_slot):
		return

	var item1_data = equipment[from_slot]
	var item2_data = equipment[to_slot]

	# Check if the items can be swapped (e.g. rings)
	if not item1_data.is_empty() and _get_item_slot_name(item1_data.item) != to_slot:
		return
	if not item2_data.is_empty() and _get_item_slot_name(item2_data.item) != from_slot:
		return

	equipment[to_slot] = item1_data
	equipment[from_slot] = item2_data
	inventory_changed.emit()
