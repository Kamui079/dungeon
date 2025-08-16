extends Panel
class_name EnemyStatusPanel

# UI References
@onready var enemy_name_label: Label = $VBoxContainer/EnemyNameLabel
@onready var health_bar: ProgressBar = $VBoxContainer/BarsContainer/HealthSection/HealthBar
@onready var health_value: Label = $VBoxContainer/BarsContainer/HealthSection/HealthValue
@onready var mana_bar: ProgressBar = $VBoxContainer/BarsContainer/ManaSection/ManaBar
@onready var mana_value: Label = $VBoxContainer/BarsContainer/ManaSection/ManaValue
@onready var status_effects_icons: HBoxContainer = $VBoxContainer/StatusEffectsContainer/StatusEffectsIcons

# Current enemy reference
var current_enemy: Node = null

# Status effect icon cache
var status_effect_icons: Dictionary = {}

func _ready():
	# Hide the panel initially
	hide()
	
	# Connect to status effects manager signals
	var status_manager = get_tree().get_first_node_in_group("StatusEffectsManager")
	if status_manager:
		# We'll connect to signals when we set an enemy
		pass

func set_enemy(enemy: Node):
	"""Set the enemy to display information for"""
	if not enemy or not is_instance_valid(enemy):
		hide()
		return
	
	current_enemy = enemy
	
	# Update enemy name
	enemy_name_label.text = enemy.name
	
	# Connect to enemy signals for updates
	if enemy.has_signal("health_changed"):
		enemy.health_changed.connect(_on_enemy_health_changed)
	if enemy.has_signal("mana_changed"):
		enemy.mana_changed.connect(_on_enemy_mana_changed)
	
	# Initial update
	update_health_display()
	update_mana_display()
	update_status_effects()
	
	# Show the panel
	show()

func clear_enemy():
	"""Clear the current enemy and hide the panel"""
	if current_enemy:
		# Disconnect signals
		if current_enemy.has_signal("health_changed"):
			current_enemy.health_changed.disconnect(_on_enemy_health_changed)
		if current_enemy.has_signal("mana_changed"):
			current_enemy.mana_changed.disconnect(_on_enemy_mana_changed)
		
		current_enemy = null
	
	# Clear status effects
	clear_status_effects()
	
	# Hide the panel
	hide()

func update_health_display():
	"""Update the health bar and value display"""
	if not current_enemy or not is_instance_valid(current_enemy):
		return
	
	var current_health = current_enemy.current_health
	var max_health = current_enemy.max_health
	
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
	
	var current_mana = current_enemy.current_mana
	var max_mana = current_enemy.max_mana
	
	# Update mana bar
	mana_bar.max_value = max_mana
	mana_bar.value = current_mana
	
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
