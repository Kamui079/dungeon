# InventoryUI.gd
extends Control

@export var items_container: GridContainer

var player_inventory: Node

func _ready():
	# We need to wait a frame for player_inventory to be set by the player.
	await get_tree().process_frame
	
	if player_inventory:
		player_inventory.inventory_changed.connect(update_display)
	else:
		printerr("InventoryUI ERROR: 'player_inventory' was not set by the player script!")
		return

	if not items_container:
		printerr("Items container not assigned in the editor for InventoryUI!")
		return

	update_display()
	hide()
	
	# Add to group for cursor coordination
	add_to_group("InventoryUI")

func _input(_event):
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_panel()

func toggle_panel():
	visible = not visible
	_update_cursor_mode()

func _update_cursor_mode():
	"""Update cursor mode based on whether any UI panels are visible"""
	var any_ui_visible = visible
	
	# Check if equipment UI is also visible
	var equipment_ui = get_tree().get_first_node_in_group("EquipmentUI")
	if equipment_ui and equipment_ui.visible:
		any_ui_visible = true
	
	# Set cursor mode based on whether any UI is visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if any_ui_visible else Input.MOUSE_MODE_CAPTURED

func update_display():
	if not player_inventory or not items_container: return
	
	var bag = player_inventory.get_bag()
	for i in range(items_container.get_child_count()):
		var slot_node = items_container.get_child(i)
		var icon_rect := slot_node.find_child("Icon") as TextureRect
		var quantity_label := slot_node.find_child("QuantityLabel") as Label
		if not icon_rect or not quantity_label: continue

		if bag.has(i):
			var item_data = bag[i]
			icon_rect.texture = item_data.item.icon
			# Check if this slot is currently being dragged
			var is_dragging = false
			if slot_node.has_method("get") and slot_node.get("is_dragging") != null:
				is_dragging = slot_node.is_dragging
			icon_rect.visible = not is_dragging
			if item_data.quantity > 1:
				quantity_label.text = str(item_data.quantity)
				quantity_label.visible = not is_dragging
			else:
				quantity_label.visible = false
		else:
			icon_rect.visible = false
			quantity_label.visible = false
