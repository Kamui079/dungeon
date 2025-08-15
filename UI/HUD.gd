extends CanvasLayer

class_name HUD

@onready var health_bar: ProgressBar = $Margin/VBox/HBoxHealth/HealthBar
@onready var mana_bar: ProgressBar = $Margin/VBox/HBoxMana/ManaBar
@onready var spirit_bar: ProgressBar = $Margin/VBox/HBoxSpirit/SpiritBar
@onready var health_label: Label = $Margin/VBox/HBoxHealth/Label
@onready var mana_label: Label = $Margin/VBox/HBoxMana/Label
@onready var spirit_label: Label = $Margin/VBox/HBoxSpirit/Label
@onready var spirit_container: HBoxContainer = $Margin/VBox/HBoxSpirit

func _ready():
	# Add to HUD group for easy access
	add_to_group("HUD")
	
	# Hide spirit bar by default (only show during combat)
	hide_spirit_bar()

func set_health(current: int, maximum: int) -> void:
	health_bar.max_value = max(1, maximum)
	health_bar.value = clamp(current, 0, maximum)
	health_label.text = "Health: " + str(current) + "/" + str(maximum)

func set_mana(current: int, maximum: int) -> void:
	mana_bar.max_value = max(1, maximum)
	mana_bar.value = clamp(current, 0, maximum)
	mana_label.text = "Mana: " + str(current) + "/" + str(maximum)

func set_spirit(current: int, maximum: int = 10) -> void:
	spirit_bar.max_value = max(1, maximum)
	spirit_bar.value = clamp(current, 0, maximum)
	spirit_label.text = "Spirit: " + str(current) + "/" + str(maximum)

func show_spirit_bar() -> void:
	"""Show the spirit bar (called when combat starts)"""
	spirit_container.visible = true

func hide_spirit_bar() -> void:
	"""Hide the spirit bar (called when combat ends)"""
	spirit_container.visible = false

func flash_damage() -> void:
	# Placeholder for effects
	pass
