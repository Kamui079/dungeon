extends Node3D

class_name Chest

# Item pool configuration - each chest can have different items
@export var item_pool: Array[Resource] = []
@export var ensure_at_least_one: bool = true  # Always drop at least one item
@export var destroy_after_open: bool = false  # Optional: destroy chest after opening

# Visual feedback
var _has_been_opened: bool = false

func _ready():
	# Add to chest group for easy finding
	add_to_group("Chest")

# This function is called by the player controller when they interact with the chest
# It replaces the old global input handling
func interact_with_player(player: Node) -> void:
	print("=== CHEST INTERACTION STARTED ===")
	print("Chest name: ", name)
	# Prevent multiple uses - chest can only be opened once
	if _has_been_opened:
		return
		
	# Try to give items from the pool
	if player.has_method("receive_item"):
		give_items_to_player(player)

# Main function to give items to player based on drop chances
func give_items_to_player(player: Node) -> void:
	# Mark chest as opened immediately
	_has_been_opened = true
	
	if item_pool.is_empty():
		return
	
	# Calculate which items should drop based on drop chances
	var items_to_give = _calculate_drops()
	
	# Ensure at least one item drops if configured
	if ensure_at_least_one and items_to_give.is_empty():
		var random_item = item_pool[randi() % item_pool.size()]
		items_to_give.append(random_item)
	
	# Give all the items to the player
	for item in items_to_give:
		if player.has_method("receive_item"):
			player.receive_item(item)
	
	# Show visual feedback for items received
	_show_item_acquired_feedback(items_to_give)
	
	# Optional: destroy chest after opening
	if destroy_after_open:
		queue_free()

# Show visual feedback when items are acquired
func _show_item_acquired_feedback(items: Array[Resource]) -> void:
	if items.is_empty():
		return
	
	# Create floating item icons above the chest
	for i in range(items.size()):
		var item = items[i]
		if item == null:
			continue
			
		# Create floating item icon
		_create_floating_item_icon(item, i, items.size())
		
		# Show item name on screen
		_show_item_name_notification(item.name)

# Create a floating item icon that rises from the chest
func _create_floating_item_icon(item: Resource, index: int, total_items: int) -> void:
	# Create a Sprite3D for the actual item icon
	var sprite = Sprite3D.new()
	var icon_texture = item.get("icon") if item.get("icon") != null else null
	sprite.texture = icon_texture
	sprite.billboard = true  # Always face the camera
	sprite.pixel_size = 0.0005  # Half the current size for appropriately sized item icons
	sprite.modulate.a = 0.0  # Start transparent
	
	# If texture failed to load, create a colored fallback
	if icon_texture == null or icon_texture.get_width() == 0:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.BLUE  # Blue for fallback
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sprite.material_override = material
	
	# Add as child of the chest
	add_child(sprite)
	
	# Position the sprite above and in front of the chest using local coordinates
	# Since the chest is rotated 90 degrees, front is along the X-axis
	# First position centered in front, then apply offset for multiple items
	sprite.position = Vector3(-1.0, 3.0, 0.5)  # Closer to chest center, more to the left
	var offset = Vector3(0, 0, (index - total_items / 2.0) * 1.0)  # Wider spacing along Z-axis
	sprite.position += offset  # Apply offset after positioning
	

	
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
	
	for i in range(item_pool.size()):
		var item = item_pool[i]
		if item == null:
			continue
			
		# Get drop chance from item (default to 100% if not set)
		var drop_chance: float = 100.0
		if item.get("drop_chance") != null:
			drop_chance = item.get("drop_chance")
		
		# Roll for this item
		var roll = randf_range(0.0, 100.0)
		
		# Safety check: if drop chance is 100% or higher, always drop
		if drop_chance >= 100.0:
			drops.append(item)
		elif roll <= drop_chance:
			drops.append(item)
	
	return drops

# Helper method to set up a chest with a specific item pool
func setup_chest(new_item_pool: Array[Resource], min_drops: bool = true, destroy_after: bool = false) -> void:
	item_pool = new_item_pool
	ensure_at_least_one = min_drops
	destroy_after_open = destroy_after


# Helper method to add items to the pool
func add_item_to_pool(item: Resource) -> void:
	if item != null:
		item_pool.append(item)


# Helper method to remove items from the pool
func remove_item_from_pool(item: Resource) -> void:
	if item != null and item_pool.has(item):
		item_pool.erase(item)


# Legacy function for compatibility (calls the new system)
func give_item_to_player(player: Node):
	give_items_to_player(player)
