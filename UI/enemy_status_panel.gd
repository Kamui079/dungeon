extends Panel
class_name EnemyStatusPanel

# UI References
var enemy_name_label: Label
var level_label: Label
var type_label: Label
var health_bar: ProgressBar
var health_value: Label
var mana_bar: ProgressBar
var mana_value: Label
var status_effects_icons: HBoxContainer

# Current enemy reference
var current_enemy: Node = null

# Status effect icon cache
var status_effect_icons: Dictionary = {}

func _ready():
	# Hide the panel initially
	hide()
	
	# Wait for the scene tree to be ready before accessing child nodes
	call_deferred("_initialize_ui_elements")
	
	# Connect to status effects manager signals
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if status_manager:
		# We'll connect to signals when we set an enemy
		pass

func _initialize_ui_elements():
	"""Initialize UI elements after the scene tree is ready"""
	print("DEBUG: EnemyStatusPanel _initialize_ui_elements() called")
	
	# Debug: Check the scene tree structure
	print("DEBUG: Scene tree structure:")
	print("DEBUG: Self node: ", self)
	print("DEBUG: Self name: ", name)
	print("DEBUG: Self type: ", get_class())
	print("DEBUG: Child count: ", get_child_count())
	print("DEBUG: All children:")
	for i in range(get_child_count()):
		var child = get_child(i)
		print("DEBUG:   Child ", i, ": ", child.name, " (", child.get_class(), ")")
		if child.get_child_count() > 0:
			for j in range(child.get_child_count()):
				var grandchild = child.get_child(j)
				print("DEBUG:     Grandchild ", j, ": ", grandchild.name, " (", grandchild.get_class(), ")")
	
	# Manually find and assign UI elements using direct child access
	# Based on the debug output, the nodes are at specific indices
	if get_child_count() >= 18:
		enemy_name_label = get_child(2)  # EnemyStatusPanel_VBoxContainer_InfoContainer#EnemyNameLabel
		level_label = get_child(3)       # EnemyStatusPanel_VBoxContainer_InfoContainer#LevelLabel
		type_label = get_child(4)        # EnemyStatusPanel_VBoxContainer_InfoContainer#TypeLabel
		health_bar = get_child(9)        # EnemyStatusPanel_VBoxContainer_BarsContainer_HealthSection#HealthBar
		health_value = get_child(10)     # EnemyStatusPanel_VBoxContainer_BarsContainer_HealthSection#HealthValue
		mana_bar = get_child(13)         # EnemyStatusPanel_VBoxContainer_BarsContainer_ManaSection#ManaBar
		mana_value = get_child(14)       # EnemyStatusPanel_VBoxContainer_BarsContainer_ManaSection#ManaValue
		status_effects_icons = get_child(17) # EnemyStatusPanel_VBoxContainer_StatusEffectsContainer#StatusEffectsIcons
		
		# Verify the types are correct
		if not enemy_name_label is Label or not level_label is Label or not type_label is Label:
			print("ERROR: Label nodes not found at expected indices!")
		if not health_bar is ProgressBar or not mana_bar is ProgressBar:
			print("ERROR: ProgressBar nodes not found at expected indices!")
	else:
		print("ERROR: Not enough children found! Expected 18, got ", get_child_count())
	
	# Debug: Check if UI elements are properly initialized
	print("DEBUG: UI elements found:")
	print("DEBUG: enemy_name_label: ", enemy_name_label)
	print("DEBUG: level_label: ", level_label)
	print("DEBUG: type_label: ", type_label)
	print("DEBUG: health_bar: ", health_bar)
	print("DEBUG: health_value: ", health_value)
	print("DEBUG: mana_bar: ", mana_bar)
	print("DEBUG: mana_value: ", mana_value)
	print("DEBUG: status_effects_icons: ", status_effects_icons)
	
	# Check if any elements are still null
	if not enemy_name_label or not level_label or not type_label or not health_bar or not health_value or not mana_bar or not mana_value:
		print("ERROR: Some UI elements are still null after manual initialization!")
		print("DEBUG: Checking node paths...")
		print("DEBUG: VBoxContainer exists: ", get_node_or_null("VBoxContainer"))
		print("DEBUG: InfoContainer exists: ", get_node_or_null("VBoxContainer/InfoContainer"))
		print("DEBUG: BarsContainer exists: ", get_node_or_null("VBoxContainer/BarsContainer"))
	else:
		print("DEBUG: All UI elements initialized successfully!")

func set_enemy(enemy: Node):
	"""Set the enemy to display information for"""
	if not enemy or not is_instance_valid(enemy):
		hide()
		return
	
	# Check if UI elements are ready
	if not enemy_name_label or not level_label or not type_label or not health_bar or not health_value or not mana_bar or not mana_value:
		print("ERROR: Cannot set enemy - UI elements not initialized yet!")
		return
	
	current_enemy = enemy
	
	# Update enemy name
	update_enemy_info(enemy)
	
	# Connect to enemy signals for updates
	if enemy.has_signal("health_changed"):
		enemy.health_changed.connect(_on_enemy_health_changed)
	if enemy.has_signal("mana_changed"):
		enemy.mana_changed.connect(_on_enemy_mana_changed)
	
	# Also try to connect to enemy behavior component signals if they exist
	var enemy_behavior = _get_enemy_behavior_component()
	if enemy_behavior and enemy_behavior != enemy:
		if enemy_behavior.has_signal("health_changed"):
			enemy_behavior.health_changed.connect(_on_enemy_health_changed)
		if enemy_behavior.has_signal("mana_changed"):
			enemy_behavior.mana_changed.connect(_on_enemy_mana_changed)
	
	# Initial update
	update_health_display()
	update_mana_display()
	update_status_effects()
	
	# Show the panel
	show()

func clear_enemy():
	"""Clear the current enemy and hide the panel"""
	if current_enemy:
		# Disconnect signals from main enemy
		if current_enemy.has_signal("health_changed"):
			current_enemy.health_changed.disconnect(_on_enemy_health_changed)
		if current_enemy.has_signal("mana_changed"):
			current_enemy.mana_changed.disconnect(_on_enemy_mana_changed)
		
		# Also disconnect from enemy behavior component if it exists
		var enemy_behavior = _get_enemy_behavior_component()
		if enemy_behavior and enemy_behavior != current_enemy:
			if enemy_behavior.has_signal("health_changed"):
				enemy_behavior.health_changed.disconnect(_on_enemy_health_changed)
			if enemy_behavior.has_signal("mana_changed"):
				enemy_behavior.mana_changed.disconnect(_on_enemy_mana_changed)
		
		current_enemy = null
	
	# Clear status effects
	clear_status_effects()
	
	# Hide the panel
	hide()

func update_health_display():
	"""Update the health bar and value display"""
	if not current_enemy or not is_instance_valid(current_enemy):
		return
	
	# Safety check for UI elements
	if not health_bar or not health_value:
		return
	
	# Try to find the enemy behavior component for stats
	var enemy_behavior = _get_enemy_behavior_component()
	if not enemy_behavior:
		return
	
	# Safety check for stats
	if not enemy_behavior.has_method("get") or not enemy_behavior.get("stats"):
		return
	
	var current_health = enemy_behavior.stats.health
	var max_health = enemy_behavior.stats.max_health
	
	# Update health bar
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Update health value text
	health_value.text = str(current_health) + "/" + str(max_health)
	
	# Update health bar color based on percentage
	var health_percent = float(current_health) / float(max_health)
	if health_percent > 0.6:
		health_bar.modulate = Color(0.3, 1.0, 0.3)  # Green
	elif health_percent > 0.3:
		health_bar.modulate = Color(1.0, 1.0, 0.3)  # Yellow
	else:
		health_bar.modulate = Color(1.0, 0.3, 0.3)  # Red

func update_mana_display():
	"""Update the mana bar and value display"""
	if not current_enemy or not is_instance_valid(current_enemy):
		return
	
	# Safety check for UI elements
	if not mana_bar or not mana_value:
		return
	
	# Try to find the enemy behavior component for stats
	var enemy_behavior = _get_enemy_behavior_component()
	if not enemy_behavior:
		return
	
	# Safety check for stats
	if not enemy_behavior.has_method("get") or not enemy_behavior.get("stats"):
		return
	
	var current_mana = enemy_behavior.stats.mana
	var max_mana = enemy_behavior.stats.max_mana
	
	# Update mana bar
	mana_bar.value = current_mana
	mana_bar.max_value = max_mana
	
	# Update mana value text
	mana_value.text = str(current_mana) + "/" + str(max_mana)

func update_status_effects():
	"""Update the status effects icons display"""
	if not current_enemy or not is_instance_valid(current_enemy):
		return
	
	# Clear existing status effect icons
	clear_status_effects()
	
	# Get status effects from the status effects manager
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if not status_manager:
		return
	
	# Get active effects for this enemy
	var effects_info = status_manager.get_effects_debug_info(current_enemy)
	if effects_info.has("error"):
		return
	
	var active_effects = effects_info.get("active_effects", [])
	
	# Create icons for each active effect
	for effect_data in active_effects:
		create_status_effect_icon(effect_data)

func create_status_effect_icon(effect_data: Dictionary):
	"""Create a small icon for a status effect"""
	var effect_type = effect_data.get("type", "")
	var duration = effect_data.get("duration", 0)
	
	# Create a container for the effect icon
	var effect_container = VBoxContainer.new()
	effect_container.custom_minimum_size = Vector2(32, 32)
	
	# Create the effect icon (using a colored rectangle for now)
	var effect_icon = ColorRect.new()
	effect_icon.custom_minimum_size = Vector2(24, 24)
	effect_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	effect_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Set color based on effect type
	match effect_type:
		"POISON":
			effect_icon.color = Color(0.2, 1.0, 0.2, 0.8)  # Green
		"IGNITE":
			effect_icon.color = Color(1.0, 0.3, 0.0, 0.8)  # Orange
		"STUN":
			effect_icon.color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow
		"SLOW":
			effect_icon.color = Color(0.5, 0.5, 1.0, 0.8)  # Blue
		"BLEED":
			effect_icon.color = Color(1.0, 0.0, 0.0, 0.8)  # Red
		"FREEZE":
			effect_icon.color = Color(0.7, 0.9, 1.0, 0.8)  # Light Blue
		_:
			effect_icon.color = Color(0.8, 0.8, 0.8, 0.8)  # Gray
	
	# Create duration label
	var duration_label = Label.new()
	duration_label.text = str(duration)
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	duration_label.custom_minimum_size = Vector2(32, 16)
	duration_label.add_theme_font_size_override("font_size", 10)
	duration_label.modulate = Color(1, 1, 1, 0.9)
	
	# Add icon and duration to container
	effect_container.add_child(effect_icon)
	effect_container.add_child(duration_label)
	
	# Add to status effects container
	status_effects_icons.add_child(effect_container)
	
	# Store reference for cleanup
	status_effect_icons[effect_type] = effect_container

func clear_status_effects():
	"""Clear all status effect icons"""
	for icon in status_effect_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	status_effect_icons.clear()

# Signal handlers
func _on_enemy_health_changed():
	update_health_display()

func _on_enemy_mana_changed():
	update_mana_display()

# Public methods for external updates
func refresh_display():
	"""Refresh all displays (called from combat manager)"""
	if current_enemy and is_instance_valid(current_enemy):
		update_health_display()
		update_mana_display()
		update_status_effects()

func _get_enemy_behavior_component() -> Node:
	"""Get the enemy behavior component that contains stats and methods"""
	if not current_enemy:
		return null
	
	# Try to find the enemy behavior component (for composed enemies like BigRat)
	var enemy_behavior = null
	if current_enemy.has_method("get_level") and current_enemy.has_method("get_effective_enemy_type"):
		# Enemy has the methods directly
		enemy_behavior = current_enemy
	else:
		# Look for enemy behavior component in children
		for child in current_enemy.get_children():
			if child.has_method("get_level") and child.has_method("get_effective_enemy_type"):
				enemy_behavior = child
				break
	
	return enemy_behavior

func update_enemy_info(enemy: Node) -> void:
	"""Update the panel with current enemy information"""
	if not enemy:
		return
	
	# Safety check for UI elements
	if not enemy_name_label or not level_label or not type_label:
		print("ERROR: UI labels not initialized!")
		return
	
	# Get proper enemy display name
	var enemy_display_name = "Unknown Enemy"
	if enemy.has_method("get_enemy_name"):
		enemy_display_name = enemy.get_enemy_name()
	elif enemy.has_method("enemy_name"):
		enemy_display_name = enemy.enemy_name()
	elif enemy.name:
		enemy_display_name = enemy.name
	
	enemy_name_label.text = enemy_display_name

	# Update level and type using the helper function
	var enemy_behavior = _get_enemy_behavior_component()
	
	var level = "Lvl. ?"
	if enemy_behavior and enemy_behavior.has_method("get_level"):
		var level_value = enemy_behavior.get_level()
		level = "Lvl. " + str(level_value)
	level_label.text = level

	var type = "(Unknown)"
	if enemy_behavior and enemy_behavior.has_method("get_effective_enemy_type"):
		var type_value = enemy_behavior.get_effective_enemy_type()
		type = "(" + type_value.capitalize() + ")"
		print("DEBUG: Got type: ", type_value, " - Setting type label to: ", type)
	type_label.text = type
	
	print("DEBUG: Final enemy info - Name: ", enemy_display_name, ", Level: ", level, ", Type: ", type)
