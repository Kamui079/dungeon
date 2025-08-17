extends Control

class_name HUD

@onready var health_bar: ProgressBar = $Margin/HBox/VBox/HBoxHealth/HealthBar
@onready var mana_bar: ProgressBar = $Margin/HBox/VBox/HBoxMana/ManaBar
@onready var spirit_bar: ProgressBar = $Margin/HBox/VBox/HBoxSpirit/SpiritBar
@onready var health_value: Label = $Margin/HBox/VBox/HBoxHealth/HealthBar/HealthValue
@onready var mana_value: Label = $Margin/HBox/VBox/HBoxMana/ManaBar/ManaValue
@onready var spirit_value: Label = $Margin/HBox/VBox/HBoxSpirit/SpiritBar/SpiritValue
@onready var spirit_container: HBoxContainer = $Margin/HBox/VBox/HBoxSpirit
@onready var enemy_panels_container: HBoxContainer = $Margin/HBox/EnemyPanelsContainer

func _ready():
	# Add to HUD group for easy access
	add_to_group("HUD")
	
	# Hide spirit bar by default (only show during combat)
	hide_spirit_bar()
	
	# Connect to combat manager signals for enemy panel updates
	call_deferred("_connect_combat_signals")

func set_health(current: int, maximum: int) -> void:
	if not health_bar:
		print("HUD: Health bar is null, cannot set health")
		return
		
	health_bar.max_value = max(1, maximum)
	health_bar.value = clamp(current, 0, maximum)
	health_value.text = str(current) + "/" + str(maximum)
	
	# Debug: Check if size changes
	var current_size = health_bar.size
	var current_min_size = health_bar.custom_minimum_size
	print("HUD: Health bar size: ", current_size, " min_size: ", current_min_size)

func set_mana(current: int, maximum: int) -> void:
	if not mana_bar:
		print("HUD: Mana bar is null, cannot set mana")
		return
		
	mana_bar.max_value = max(1, maximum)
	mana_bar.value = clamp(current, 0, maximum)
	mana_value.text = str(current) + "/" + str(maximum)
	
	# Debug: Check if size changes
	var current_size = mana_bar.size
	var current_min_size = mana_bar.custom_minimum_size
	print("HUD: Mana bar size: ", current_size, " min_size: ", current_min_size)



func set_spirit(current: int, maximum: int = 10) -> void:
	if not spirit_bar:
		print("HUD: Spirit bar is null, cannot set spirit")
		return
		
	spirit_bar.max_value = max(1, maximum)
	spirit_bar.value = clamp(current, 0, maximum)
	spirit_value.text = str(current) + "/" + str(maximum)

func show_spirit_bar() -> void:
	"""Show the spirit bar (called when combat starts)"""
	spirit_container.visible = true
	
	# Debug: Check bar sizes when combat starts
	_check_bar_sizes("Combat started")
	
	# Set up a timer to check sizes again after a short delay
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func(): _check_bar_sizes("Combat started + 0.1s"))
	
	# Set up another timer to check sizes after a longer delay
	var timer2 = get_tree().create_timer(1.0)
	timer2.timeout.connect(func(): _check_bar_sizes("Combat started + 1.0s"))

func hide_spirit_bar() -> void:
	"""Hide the spirit bar (called when combat ends)"""
	spirit_container.visible = false
	
	# Debug: Check bar sizes when combat ends
	_check_bar_sizes("Combat ended")

func _check_bar_sizes(context: String) -> void:
	"""Debug function to check the current sizes of health and mana bars"""
	if health_bar:
		print("HUD: ", context, " - Health bar size: ", health_bar.size, " min_size: ", health_bar.custom_minimum_size)
		print("HUD: ", context, " - Health bar position: ", health_bar.position, " global_position: ", health_bar.global_position)
	else:
		print("HUD: ", context, " - Health bar is null")
	
	if mana_bar:
		print("HUD: ", context, " - Mana bar size: ", mana_bar.size, " min_size: ", mana_bar.custom_minimum_size)
		print("HUD: ", context, " - Mana bar position: ", mana_bar.position, " global_position: ", mana_bar.global_position)
	else:
		print("HUD: ", context, " - Mana bar is null")

func flash_damage() -> void:
	# Placeholder for effects
	pass

func _connect_combat_signals():
	"""Connect to combat manager signals for enemy panel updates"""
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager:
		# Connect to enemy damaged signal to update panels
		if combat_manager.has_signal("enemy_damaged"):
			combat_manager.enemy_damaged.connect(_on_enemy_damaged)
			print("HUD: Connected to enemy_damaged signal")
		else:
			print("HUD: CombatManager missing enemy_damaged signal")
	else:
		print("HUD: No CombatManager found for signal connection")

func _on_enemy_damaged(enemy: Node, attack_type: String, damage: int):
	"""Called when an enemy takes damage - update their panel"""
	if enemy and is_instance_valid(enemy):
		var panel = get_enemy_panel(enemy)
		if panel:
			update_enemy_panel(panel, enemy)
			var enemy_display_name = "Unknown Enemy"
			if enemy.has_method("enemy_name"):
				enemy_display_name = enemy.enemy_name()
			elif enemy.name:
				enemy_display_name = enemy.name
			print("HUD: Updated enemy panel for ", enemy_display_name, " after taking ", damage, " damage")
		else:
			var enemy_display_name = "Unknown Enemy"
			if enemy.has_method("enemy_name"):
				enemy_display_name = enemy.enemy_name()
			elif enemy.name:
				enemy_display_name = enemy.name
			print("HUD: No panel found for enemy ", enemy_display_name)

# Enemy Panel Management
func create_enemy_panel(enemy: Node) -> void:
	"""Create a simple enemy info panel"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 80)
	
	# Use proper enemy name for panel identification, not internal node name
	var enemy_display_name = "Unknown Enemy"
	if enemy.has_method("enemy_name"):
		enemy_display_name = enemy.enemy_name()
	elif enemy.name:
		enemy_display_name = enemy.name
	
	panel.name = "EnemyPanel_" + enemy_display_name
	
	# Create panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	
	# Create container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 6
	vbox.offset_right = -8
	vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Enemy name
	var name_label = Label.new()
	name_label.text = enemy_display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)
	
	# Health bar
	var enemy_health_bar = ProgressBar.new()
	enemy_health_bar.custom_minimum_size = Vector2(0, 16)
	enemy_health_bar.max_value = 100
	enemy_health_bar.value = 100
	enemy_health_bar.show_percentage = false
	enemy_health_bar.add_theme_stylebox_override("fill", create_health_fill_style())
	vbox.add_child(enemy_health_bar)
	
	# Health value
	var enemy_health_value = Label.new()
	enemy_health_value.text = "100/100"
	enemy_health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_health_value.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	enemy_health_value.add_theme_font_size_override("font_size", 10)
	enemy_health_bar.add_child(enemy_health_value)
	
	# Mana bar
	var enemy_mana_bar = ProgressBar.new()
	enemy_mana_bar.custom_minimum_size = Vector2(0, 16)
	enemy_mana_bar.max_value = 50
	enemy_mana_bar.value = 50
	enemy_mana_bar.show_percentage = false
	enemy_mana_bar.add_theme_stylebox_override("fill", create_mana_fill_style())
	vbox.add_child(enemy_mana_bar)
	
	# Mana value
	var enemy_mana_value = Label.new()
	enemy_mana_value.text = "50/50"
	enemy_mana_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_mana_value.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	enemy_mana_value.add_theme_font_size_override("font_size", 10)
	enemy_mana_bar.add_child(enemy_mana_value)
	
	# Store references
	panel.set_meta("enemy", enemy)
	panel.set_meta("health_bar", enemy_health_bar)
	panel.set_meta("mana_bar", enemy_mana_bar)
	panel.set_meta("health_value", enemy_health_value)
	panel.set_meta("mana_value", enemy_mana_value)
	
	enemy_panels_container.add_child(panel)
	update_enemy_panel(panel, enemy)

func update_enemy_panel(panel: Control, enemy: Node) -> void:
	"""Update enemy panel with current stats"""
	if not panel or not enemy:
		return
	
	var enemy_health_bar = panel.get_meta("health_bar")
	var enemy_mana_bar = panel.get_meta("mana_bar")
	var enemy_health_value = panel.get_meta("health_value")
	var enemy_mana_value = panel.get_meta("mana_value")
	
	if not enemy_health_bar or not enemy_mana_bar or not enemy_health_value or not enemy_mana_value:
		return
	
	# Try to get enemy stats
	var enemy_stats = null
	if enemy.has_method("get_stats"):
		enemy_stats = enemy.get_stats()
	elif enemy.has_method("stats"):
		enemy_stats = enemy.stats
	
	if enemy_stats:
		# Update health
		var current_health = enemy_stats.health if "health" in enemy_stats else 100
		var max_health = enemy_stats.max_health if "max_health" in enemy_stats else 100
		enemy_health_bar.max_value = max_health
		enemy_health_bar.value = current_health
		enemy_health_value.text = str(current_health) + "/" + str(max_health)
		
		# Update mana
		var current_mana = enemy_stats.mana if "mana" in enemy_stats else 50
		var max_mana = enemy_stats.max_mana if "max_mana" in enemy_stats else 50
		enemy_mana_bar.max_value = max_mana
		enemy_mana_bar.value = current_mana
		enemy_mana_value.text = str(current_mana) + "/" + str(max_mana)

func remove_enemy_panel(enemy: Node) -> void:
	"""Remove enemy panel when enemy is defeated"""
	for child in enemy_panels_container.get_children():
		if child.has_meta("enemy") and child.get_meta("enemy") == enemy:
			child.queue_free()
			break

func clear_enemy_panels() -> void:
	"""Clear all enemy panels"""
	for child in enemy_panels_container.get_children():
		child.queue_free()

func get_enemy_panel(enemy: Node) -> Control:
	"""Get the panel for a specific enemy"""
	for child in enemy_panels_container.get_children():
		if child.has_meta("enemy") and child.get_meta("enemy") == enemy:
			return child
	return null

func highlight_focused_enemy(enemy: Node) -> void:
	"""Highlight the panel of the currently focused enemy"""
	# Reset all panels to normal appearance
	for child in enemy_panels_container.get_children():
		_apply_panel_glow(child, false)
	
	# Highlight the focused enemy's panel
	var focused_panel = get_enemy_panel(enemy)
	if focused_panel:
		_apply_panel_glow(focused_panel, true)
		
		# Get proper enemy display name for logging
		var enemy_display_name = "Unknown Enemy"
		if enemy.has_method("enemy_name"):
			enemy_display_name = enemy.enemy_name()
		elif enemy.name:
			enemy_display_name = enemy.name
		
		print("HUD: Highlighted focused enemy panel: ", enemy_display_name)

func _apply_panel_glow(panel: Control, is_focused: bool) -> void:
	"""Apply or remove glow effect to an enemy panel"""
	if not panel:
		return
	
	var style = panel.get_theme_stylebox("panel")
	if not style:
		return
	
	if is_focused:
		# Apply glowing blue border for focus
		style.border_color = Color(0.2, 0.8, 1.0, 1.0)  # Bright cyan
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		# Add a subtle glow effect
		style.shadow_color = Color(0.2, 0.8, 1.0, 0.3)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 0)
	else:
		# Reset to normal appearance
		style.border_color = Color(0.4, 0.4, 0.5, 1.0)  # Normal blue
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		# Remove glow effect
		style.shadow_size = 0
	
	# Force the style update
	panel.queue_redraw()

# Helper functions for creating styles
func create_health_fill_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.3, 0.3, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

func create_mana_fill_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 1.0, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
