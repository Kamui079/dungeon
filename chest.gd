extends Node3D

class_name Chest

# Item pool configuration - each chest can have different items
@export var item_pool: Array[Resource] = []
@export var ensure_at_least_one: bool = true  # Always drop at least one item
@export var destroy_after_open: bool = false  # Optional: destroy chest after opening

# Visual feedback
var _has_been_opened: bool = false

func _ready():
	print("=== CHEST SCRIPT LOADED ===")
	print("Chest name: ", name)
	print("Chest position: ", global_position)
	print("Item pool size: ", item_pool.size())
	print("Ensure at least one: ", ensure_at_least_one)
	print("Destroy after open: ", destroy_after_open)
	print("=== CHEST SCRIPT READY ===")

# This function is called by the player controller when they interact with the chest
# It replaces the old global input handling
func interact_with_player(player: Node) -> void:
	print("=== CHEST INTERACTION STARTED ===")
	print("Chest name: ", name)
	print("Chest position: ", global_position)
	print("Player position: ", player.global_position)
	print("Distance to player: ", global_position.distance_to(player.global_position))
	
	# Prevent multiple uses - chest can only be opened once
	if _has_been_opened:
		print("Chest has already been opened, ignoring interaction")
		return
		
	print("Player interacting with chest! Testing item giving...")
	# Try to give items from the pool
	if player.has_method("receive_item"):
		print("Player has receive_item method!")
		give_items_to_player(player)
	else:
		print("Player does NOT have receive_item method!")

# Main function to give items to player based on drop chances
func give_items_to_player(player: Node) -> void:
	print("=== GIVE_ITEMS_TO_PLAYER CALLED ===")
	print("Player: ", player.name)
	print("Item pool size: ", item_pool.size())
	
	# Mark chest as opened immediately
	_has_been_opened = true
	
	if item_pool.is_empty():
		print("ERROR: Item pool is empty!")
		return
	
	# Calculate which items should drop based on drop chances
	var items_to_give = _calculate_drops()
	print("Items that rolled to drop: ", items_to_give.size())
	
	# Ensure at least one item drops if configured
	if ensure_at_least_one and items_to_give.is_empty():
		print("No items rolled to drop, ensuring minimum drop...")
		var random_item = item_pool[randi() % item_pool.size()]
		items_to_give.append(random_item)
		print("Guaranteed drop: ", random_item.name)
	
	# Give all the items to the player
	for item in items_to_give:
		print("Giving item: ", item.name)
		if player.has_method("receive_item"):
			var success = player.receive_item(item)
			if success:
				print("Successfully gave ", item.name, " to player")
			else:
				print("Failed to give ", item.name, " to player")
		else:
			print("ERROR: Player doesn't have receive_item method!")
	
	print("Total items given: ", items_to_give.size())
	
	# Show visual feedback for items received
	_show_item_acquired_feedback(items_to_give)
	
	print("=== GIVE_ITEMS_TO_PLAYER FINISHED ===")
	
	# Optional: destroy chest after opening
	if destroy_after_open:
		print("Destroying chest after opening...")
		queue_free()

# Show visual feedback when items are acquired
func _show_item_acquired_feedback(items: Array[Resource]) -> void:
	if items.is_empty():
		return
	
	print("=== SHOWING ITEM ACQUIRED FEEDBACK ===")
	
	# Create floating item icons above the chest
	for i in range(items.size()):
		var item = items[i]
		if item == null:
			continue
			
		# Create floating item icon
		_create_floating_item_icon(item, i, items.size())
		
		# Show item name on screen
		_show_item_name_notification(item.name)
		
		print("Created feedback for item: ", item.name)
	
	print("=== ITEM FEEDBACK COMPLETE ===")

# Create a floating item icon that rises from the chest
func _create_floating_item_icon(item: Resource, index: int, total_items: int) -> void:
	print("=== CREATING FLOATING ICON ===")
	if item:
		print("Item: ", item.name)
	else:
		print("Item: null")
	
	# Create a Sprite3D for the actual item icon
	var sprite = Sprite3D.new()
	var icon_texture = item.get("icon") if item.get("icon") != null else null
	sprite.texture = icon_texture
	sprite.billboard = true  # Always face the camera
	sprite.pixel_size = 0.0005  # Half the current size for appropriately sized item icons
	sprite.modulate.a = 0.0  # Start transparent
	
	print("Sprite created - texture: ", icon_texture)
	print("Texture is null: ", icon_texture == null)
	print("Texture type: ", typeof(icon_texture))
	if icon_texture != null:
		print("Texture resource path: ", icon_texture.resource_path)
		print("Texture width: ", icon_texture.get_width())
		print("Texture height: ", icon_texture.get_height())
	print("Sprite pixel_size: ", sprite.pixel_size)
	
	# If texture failed to load, create a colored fallback
	if icon_texture == null or icon_texture.get_width() == 0:
		print("Texture failed to load, creating colored fallback")
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.BLUE  # Blue for fallback
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sprite.material_override = material
		print("Created blue fallback material")
	
	# Add as child of the chest
	add_child(sprite)
	
	# Position the sprite above and in front of the chest using local coordinates
	# Since the chest is rotated 90 degrees, front is along the X-axis
	# First position centered in front, then apply offset for multiple items
	sprite.position = Vector3(-1.0, 3.0, 0.5)  # Closer to chest center, more to the left
	var offset = Vector3(0, 0, (index - total_items / 2.0) * 1.0)  # Wider spacing along Z-axis
	sprite.position += offset  # Apply offset after positioning
	
	print("Chest position: ", global_position)
	print("Sprite local position: ", sprite.position)
	print("Sprite global position: ", sprite.global_position)
	print("Offset: ", offset)
	print("Sprite is in tree: ", sprite.is_inside_tree())
	print("Sprite parent: ", sprite.get_parent())
	
	# Create animation for the floating effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in and rise up
	tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	tween.tween_property(sprite, "position:y", sprite.position.y + 0.5, 1.0)  # Rise much faster and less high
	
	# After rising, fade out and remove
	tween.tween_callback(func():
		var fade_tween = create_tween()
		fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		fade_tween.tween_callback(sprite.queue_free)
	).set_delay(2.0)  # Much shorter delay to cut total time in half
	
	print("=== FLOATING ICON CREATED ===")

# Show item name notification on screen
func _show_item_name_notification(item_name: String) -> void:
	# Create a label that appears on screen
	var label = Label.new()
	label.text = "Acquired: " + item_name
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Position in the center of the screen with offset based on item index
	# This prevents text from stacking on top of itself
	var current_scene = get_tree().current_scene
	var existing_labels = current_scene.get_tree().get_nodes_in_group("item_notifications")
	var label_count = existing_labels.size()
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -100
	label.offset_top = -20 + (label_count * 40)  # Stack vertically with spacing
	label.offset_right = 100
	label.offset_bottom = 20 + (label_count * 40)
	
	# Add to a group for tracking
	label.add_to_group("item_notifications")
	
	# Add to the current scene's UI layer
	if current_scene:
		current_scene.add_child(label)
		
		# Animate the label
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Start transparent and scale up
		label.modulate.a = 0.0
		label.scale = Vector2(0.5, 0.5)
		
		# Fade in and scale to normal
		tween.tween_property(label, "modulate:a", 1.0, 0.3)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)
		
		# Hold for a moment, then fade out and remove from group
		tween.tween_callback(func():
			var fade_tween = create_tween()
			fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
			fade_tween.tween_callback(func():
				label.remove_from_group("item_notifications")
				label.queue_free()
			)
		).set_delay(1.5)

# Calculate which items should drop based on their drop chances
func _calculate_drops() -> Array[Resource]:
	var drops: Array[Resource] = []
	
	print("=== CALCULATING DROPS ===")
	print("Item pool size: ", item_pool.size())
	print("Ensure at least one: ", ensure_at_least_one)
	
	for i in range(item_pool.size()):
		var item = item_pool[i]
		if item == null:
			print("WARNING: Item ", i, " is null, skipping...")
			continue
			
		print("Checking item ", i, ": ", item.name)
		
		# Get drop chance from item (default to 100% if not set)
		var drop_chance: float = 100.0
		if item.get("drop_chance") != null:
			drop_chance = item.get("drop_chance")
		
		print("  Drop chance: ", drop_chance, "%")
		print("  Drop chance type: ", typeof(drop_chance))
		print("  Drop chance raw value: ", item.get("drop_chance"))
		print("  Drop chance raw type: ", typeof(item.get("drop_chance")))
		
		# Roll for this item
		var roll = randf_range(0.0, 100.0)
		print("  Roll: ", roll, " vs ", drop_chance)
		print("  Roll <= drop_chance: ", roll, " <= ", drop_chance, " = ", roll <= drop_chance)
		
		# Safety check: if drop chance is 100% or higher, always drop
		if drop_chance >= 100.0:
			print("  ✓ 100% drop chance, guaranteed drop!")
			drops.append(item)
		elif roll <= drop_chance:
			print("  ✓ Item will drop!")
			drops.append(item)
		else:
			print("  ✗ Item will not drop")
	
	print("Final drops: ", drops.size(), " items")
	print("=== END DROP CALCULATION ===")
	
	return drops

# Helper method to set up a chest with a specific item pool
func setup_chest(new_item_pool: Array[Resource], min_drops: bool = true, destroy_after: bool = false) -> void:
	item_pool = new_item_pool
	ensure_at_least_one = min_drops
	destroy_after_open = destroy_after
	print("Chest configured with ", item_pool.size(), " items, min_drops=", min_drops, ", destroy_after=", destroy_after)

# Helper method to add items to the pool
func add_item_to_pool(item: Resource) -> void:
	if item != null:
		item_pool.append(item)
		print("Added ", item.name, " to chest pool. Pool size: ", item_pool.size())

# Helper method to remove items from the pool
func remove_item_from_pool(item: Resource) -> void:
	if item != null and item_pool.has(item):
		item_pool.erase(item)
		print("Removed ", item.name, " from chest pool. Pool size: ", item_pool.size())

# Legacy function for compatibility (calls the new system)
func give_item_to_player(player: Node):
	print("=== give_item_to_player called (legacy) ===")
	give_items_to_player(player)
	print("=== give_item_to_player finished (legacy) ===")
