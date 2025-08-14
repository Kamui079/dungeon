class_name Inventory
extends Node

signal inventory_updated

@export var max_size: int = 20
var items: Array[Dictionary] = []  # { "item": Resource, "quantity": int }

func _ready():
	print("=== INVENTORY SCRIPT LOADED ===")
	print("Inventory node: ", name)
	print("Items array initialized: ", items)
	print("Items array size: ", items.size())
	print("=== INVENTORY SCRIPT READY ===")

func add_item(item: Resource, quantity: int = 1) -> int:
	print("=== ADD_ITEM DEBUG ===")
	print("Adding item: ", item.name)
	print("Quantity: ", quantity)
	print("Current items count: ", items.size())
	print("Max size: ", max_size)
	
	# Test item properties safely
	print("Testing item properties...")
	print("Item type: ", item.get_class())
	print("Item is null: ", item == null)
	print("Item is valid: ", is_instance_valid(item))
	
	# Test basic item access
	print("Item name: ", item.name)
	print("Item description: ", item.description)
	
	# Try to get max_stack safely
	var max_stack = 1  # Default value
	print("Attempting to get max_stack property...")
	
	# Use get() method instead of has() since the item might not be the expected class
	if item.get("max_stack") != null:
		max_stack = item.get("max_stack")
		print("Item max_stack value: ", max_stack)
	else:
		print("Item does not have max_stack property, using default 1")
	
	print("Final max_stack value: ", max_stack)
	
	if max_stack > 1:
		# Stack existing items
		for inv_item in items:
			if inv_item["item"].resource_path == item.resource_path and inv_item["quantity"] < max_stack:
				var can_add = min(max_stack - inv_item["quantity"], quantity)
				inv_item["quantity"] += can_add
				quantity -= can_add
				if quantity <= 0:
					inventory_updated.emit()
					print("Item stacked successfully")
					return 0
	
	# Add new stacks
	while quantity > 0 and items.size() < max_size:
		var new_stack = min(quantity, max_stack)
		items.append({"item": item, "quantity": new_stack})
		quantity -= new_stack
		print("Added new stack: ", new_stack)
	
	inventory_updated.emit()
	print("Add item completed, remaining quantity: ", quantity)
	print("=== END ADD_ITEM DEBUG ===")
	return quantity

func remove_item(item: Resource, quantity: int = 1) -> bool:
	for i in range(items.size() - 1, -1, -1):
		if items[i]["item"] == item:
			var to_remove = min(quantity, items[i]["quantity"])
			items[i]["quantity"] -= to_remove
			if items[i]["quantity"] <= 0:
				items.remove_at(i)
			quantity -= to_remove
			if quantity <= 0:
				inventory_updated.emit()
				return true
	return false

func use_item(index: int, user) -> bool:
	if index < 0 or index >= items.size():
		return false
	
	var item_data = items[index]
	if item_data["item"].has_method("use") and item_data["item"].use(user):
		return remove_item(item_data["item"], 1)
	return false

func get_items() -> Array:
	return items

func set_items(new_items: Array) -> void:
	items = new_items
	inventory_updated.emit()
