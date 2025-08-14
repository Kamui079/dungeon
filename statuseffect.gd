class_name StatusEffect
extends Resource

@export var effect_name: String
@export var icon: Texture2D
@export var duration: float
@export var is_positive: bool = true
@export var modifiers: Dictionary  # {"speed": 0.5, "defense": -10}

func apply(target):
	if target.has_method("add_status_effect"):
		target.add_status_effect(self)
