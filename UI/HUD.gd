extends CanvasLayer

class_name HUD

@onready var health_bar: ProgressBar = $Margin/VBox/HBoxHealth/HealthBar
@onready var mana_bar: ProgressBar = $Margin/VBox/HBoxMana/ManaBar
@onready var spirit_bar: ProgressBar = $Margin/VBox/HBoxSpirit/SpiritBar
@onready var health_label: Label = $Margin/VBox/HBoxHealth/Label
@onready var mana_label: Label = $Margin/VBox/HBoxMana/Label
@onready var spirit_label: Label = $Margin/VBox/HBoxSpirit/Label

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

func flash_damage() -> void:
    # Placeholder for effects
    pass


