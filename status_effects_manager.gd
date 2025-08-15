extends Node
class_name StatusEffectsManager

# Note: GIF files are not natively supported by Godot as textures.
# For better visual effects, consider converting GIFs to PNG or using animated sprites.
# This system will fall back to colored sprites if GIF loading fails.

# Status effect types
enum EFFECT_TYPE {
	POISON,
	IGNITE,
	BONE_BREAK,
	STUN,
	SLOW,
	BLEED,
	FREEZE,
	SHOCK
}

# Base status effect class
class StatusEffect:
	var type: EFFECT_TYPE
	var damage_per_tick: int
	var duration: int
	var remaining_duration: int
	var source: Node  # Who applied the effect
	var is_active: bool = true
	var visual_effect: Node = null  # Reference to the visual effect node
	
	func _init(effect_type: EFFECT_TYPE, damage: int, effect_duration: int, effect_source: Node):
		type = effect_type
		damage_per_tick = damage
		duration = effect_duration
		remaining_duration = effect_duration
		source = effect_source
	
	func tick() -> int:
		"""Process one tick of the effect, return damage dealt"""
		if not is_active or remaining_duration <= 0:
			return 0
		
		remaining_duration -= 1
		var damage_dealt = damage_per_tick
		
		if remaining_duration <= 0:
			is_active = false
		
		return damage_dealt
	
	func get_remaining_duration() -> int:
		return remaining_duration
	
	func is_expired() -> bool:
		return remaining_duration <= 0 or not is_active
	
	func set_visual_effect(effect_node: Node):
		visual_effect = effect_node
	
	func get_visual_effect() -> Node:
		return visual_effect

# Status effects manager for a single entity (player or enemy)
class EntityStatusEffects:
	var entity: Node
	var effects: Array[StatusEffect] = []
	var effect_timer: Timer
	var visual_effects_container: Node3D  # Container for visual effects above the entity
	
	func _init(target_entity: Node):
		entity = target_entity
		effect_timer = Timer.new()
		effect_timer.wait_time = 1.0  # 1 second per tick
		effect_timer.timeout.connect(_on_effect_tick)
		entity.add_child(effect_timer)
		effect_timer.start()
		
		# Create visual effects container above the entity
		_create_visual_effects_container()
	
	func _create_visual_effects_container():
		"""Create a container for visual effects above the entity"""
		visual_effects_container = Node3D.new()
		visual_effects_container.name = "StatusEffectsContainer"
		entity.add_child(visual_effects_container)
		
		# Position the container above the entity's head
		visual_effects_container.position = Vector3(0, 2.5, 0)  # Adjust height as needed
		
		print("Visual effects container created for ", entity.name)
		print("  - Container position: ", visual_effects_container.global_position)
		print("  - Container parent: ", visual_effects_container.get_parent().name)
	
	func add_effect(effect_type: EFFECT_TYPE, damage: int, duration: int, source: Node):
		"""Add a new status effect"""
		# Check if effect already exists and refresh it
		for effect in effects:
			if effect.type == effect_type and effect.is_active:
				# Refresh existing effect
				effect.remaining_duration = duration
				effect.damage_per_tick = damage
				print(entity.name, " status effect refreshed: ", effect_type)
				return
		
		# Create new effect
		var new_effect = StatusEffect.new(effect_type, damage, duration, source)
		effects.append(new_effect)
		
		# Create and display visual effect
		_create_visual_effect(new_effect)
		
		print(entity.name, " gained status effect: ", effect_type, " for ", duration, " turns")
		
		# Log to combat log if in combat
		_log_effect_applied(effect_type, duration)
	
	func _create_visual_effect(effect: StatusEffect):
		"""Create a visual effect for the status effect"""
		# Safety check: ensure entity is valid
		if not entity or not is_instance_valid(entity):
			print("⚠️ Cannot create visual effect: entity is invalid")
			return
		
		# Safety check: ensure we have a visual effects container
		if not visual_effects_container or not is_instance_valid(visual_effects_container):
			print("⚠️ Cannot create visual effect: no visual effects container")
			return
		
		match effect.type:
			EFFECT_TYPE.POISON:
				_create_poison_effect(effect)
			EFFECT_TYPE.IGNITE:
				_create_ignite_effect(effect)
			EFFECT_TYPE.BONE_BREAK:
				_create_bone_break_effect(effect)
			EFFECT_TYPE.STUN:
				_create_stun_effect(effect)
			EFFECT_TYPE.SLOW:
				_create_slow_effect(effect)
			EFFECT_TYPE.BLEED:
				_create_bleed_effect(effect)
			EFFECT_TYPE.FREEZE:
				_create_freeze_effect(effect)
			EFFECT_TYPE.SHOCK:
				_create_shock_effect(effect)
	
	func _create_poison_effect(effect: StatusEffect):
		"""Create a poison visual effect"""
		# Safety check: ensure entity is still valid
		if not entity or not is_instance_valid(entity):
			print("⚠️ Cannot create poison effect: entity is invalid")
			return
			
		print("Creating poison visual effect for ", entity.name)
		
		# Create a Sprite3D to display the poison effect
		var poison_sprite = Sprite3D.new()
		poison_sprite.name = "PoisonEffect"
		
		# Try to load the poison GIF texture, but fall back to a colored sprite if it fails
		var poison_texture = null
		# Note: GIF files are not natively supported in Godot, so we'll use a fallback approach
		print("⚠️ GIF files not supported in Godot, creating fallback poison effect")
		
		# Try to create a simple colored sprite using a default texture
		# First try to load a basic texture, then fall back to just color
		var fallback_texture = null
		if ResourceLoader.exists("res://icon.svg"):
			fallback_texture = load("res://icon.svg")
		
		if fallback_texture:
			poison_sprite.texture = fallback_texture
			poison_sprite.modulate = Color(0.2, 1.0, 0.2, 0.8)  # Green with transparency
		else:
			# No texture available, just use color
			poison_sprite.modulate = Color(0.2, 1.0, 0.2, 0.8)  # Green with transparency
		
		poison_sprite.pixel_size = 0.15  # Slightly larger for visibility
		poison_sprite.billboard = true  # Always face the camera
		
		# Add some animation with a limited number of loops to prevent infinite loops
		var tween = null
		if entity.has_method("create_tween"):
			tween = entity.create_tween()
			if tween:
				tween.set_loops(3)  # Loop 3 times then stop
				tween.tween_property(poison_sprite, "position:y", poison_sprite.position.y + 0.2, 1.0)
				tween.tween_property(poison_sprite, "position:y", poison_sprite.position.y, 1.0)
		else:
			print("⚠️ Entity has no create_tween method, skipping animation")
		
		# Store reference to the visual effect
		effect.set_visual_effect(poison_sprite)
		
		# Add to visual effects container with safety check
		if visual_effects_container and is_instance_valid(visual_effects_container):
			visual_effects_container.add_child(poison_sprite)
			print("✅ Poison visual effect created successfully for ", entity.name)
			print("  - Sprite3D added to container: ", visual_effects_container.has_node("PoisonEffect"))
			print("  - Visual effect reference stored: ", effect.get_visual_effect() != null)
		else:
			print("⚠️ Visual effects container not available, effect created but not displayed")
	
	func _create_ignite_effect(effect: StatusEffect):
		"""Create an ignite visual effect"""
		# Placeholder for future ignite effects
		pass
	
	func _create_bone_break_effect(effect: StatusEffect):
		"""Create a bone break visual effect"""
		# Placeholder for future bone break effects
		pass
	
	func _create_stun_effect(effect: StatusEffect):
		"""Create a stun visual effect"""
		# Placeholder for future stun effects
		pass
	
	func _create_slow_effect(effect: StatusEffect):
		"""Create a slow visual effect"""
		# Placeholder for future slow effects
		pass
	
	func _create_bleed_effect(effect: StatusEffect):
		"""Create a bleed visual effect"""
		# Placeholder for future bleed effects
		pass
	
	func _create_freeze_effect(effect: StatusEffect):
		"""Create a freeze visual effect"""
		# Placeholder for future freeze effects
		pass
	
	func _create_shock_effect(_effect: StatusEffect):
		"""Create a shock visual effect"""
		# Placeholder for future shock effects
		pass
	
	func remove_effect(effect_type: EFFECT_TYPE):
		"""Remove a specific status effect"""
		for i in range(effects.size()):
			if effects[i].type == effect_type:
				var effect = effects[i]
				# Remove visual effect
				if effect.visual_effect and is_instance_valid(effect.visual_effect):
					effect.visual_effect.queue_free()
				
				effect.is_active = false
				effects.remove_at(i)
				print(entity.name, " status effect removed: ", effect_type)
				break
	
	func clear_all_effects():
		"""Clear all status effects"""
		for effect in effects:
			# Remove visual effects
			if effect.visual_effect and is_instance_valid(effect.visual_effect):
				effect.visual_effect.queue_free()
			
			effect.is_active = false
		effects.clear()
		print(entity.name, " all status effects cleared")
	
	func has_effect(effect_type: EFFECT_TYPE) -> bool:
		"""Check if entity has a specific effect"""
		for effect in effects:
			if effect.type == effect_type and effect.is_active:
				return true
		return false
	
	func get_effect_duration(effect_type: EFFECT_TYPE) -> int:
		"""Get remaining duration of a specific effect"""
		for effect in effects:
			if effect.type == effect_type and effect.is_active:
				return effect.remaining_duration
		return 0
	
	func _on_effect_tick():
		"""Process all active effects"""
		var total_damage = 0
		var effects_to_remove: Array[int] = []
		
		for i in range(effects.size()):
			var effect = effects[i]
			if effect.is_expired():
				# Remove visual effect when effect expires
				if effect.visual_effect and is_instance_valid(effect.visual_effect):
					effect.visual_effect.queue_free()
				
				effects_to_remove.append(i)
				continue
			
			var damage = effect.tick()
			if damage > 0:
				total_damage += damage
				_log_effect_damage(effect.type, damage)
		
		# Remove expired effects
		for i in range(effects_to_remove.size() - 1, -1, -1):
			effects.remove_at(effects_to_remove[i])
		
		# Apply total damage
		if total_damage > 0 and entity.has_method("take_damage"):
			entity.take_damage(total_damage)
			print(entity.name, " takes ", total_damage, " total status effect damage!")
	
	func _log_effect_applied(effect_type: EFFECT_TYPE, duration: int):
		"""Log when an effect is applied"""
		var effect_name = _get_effect_display_name(effect_type)
		var message = "☠️ " + entity.name + " is affected by " + effect_name + " (" + str(duration) + " turns)"
		_log_to_combat(message)
	
	func _log_effect_damage(effect_type: EFFECT_TYPE, damage: int):
		"""Log when an effect deals damage"""
		var effect_name = _get_effect_display_name(effect_type)
		var message = "☠️ " + entity.name + " takes " + str(damage) + " " + effect_name + " damage!"
		_log_to_combat(message)
	
	func _log_to_combat(message: String):
		"""Log message to combat log if available"""
		# Try to find combat manager
		var combat_manager = _find_combat_manager()
		if combat_manager and combat_manager.has_method("_log_combat_event"):
			combat_manager._log_combat_event(message)
	
	func _find_combat_manager() -> Node:
		"""Find the combat manager in the scene"""
		var tree = entity.get_tree()
		if tree:
			return tree.get_first_node_in_group("CombatManager")
		return null
	
	func _get_effect_display_name(effect_type: EFFECT_TYPE) -> String:
		"""Get display name for effect type"""
		match effect_type:
			EFFECT_TYPE.POISON:
				return "Poison"
			EFFECT_TYPE.IGNITE:
				return "Ignite"
			EFFECT_TYPE.BONE_BREAK:
				return "Bone Break"
			EFFECT_TYPE.STUN:
				return "Stun"
			EFFECT_TYPE.SLOW:
				return "Slow"
			EFFECT_TYPE.BLEED:
				return "Bleed"
			EFFECT_TYPE.FREEZE:
				return "Freeze"
			EFFECT_TYPE.SHOCK:
				return "Shock"
			_:
				return "Unknown Effect"

# Global status effects manager
var entity_effects: Dictionary = {}  # entity -> EntityStatusEffects

func _ready():
	add_to_group("StatusEffectsManager")

func get_entity_effects(entity: Node) -> EntityStatusEffects:
	"""Get or create status effects for an entity"""
	if not entity_effects.has(entity):
		entity_effects[entity] = EntityStatusEffects.new(entity)
	return entity_effects[entity]

func apply_effect(entity: Node, effect_type: EFFECT_TYPE, damage: int, duration: int, source: Node):
	"""Apply a status effect to an entity"""
	var effects = get_entity_effects(entity)
	effects.add_effect(effect_type, damage, duration, source)

func remove_effect(entity: Node, effect_type: EFFECT_TYPE):
	"""Remove a specific effect from an entity"""
	if entity_effects.has(entity):
		entity_effects[entity].remove_effect(effect_type)

func clear_entity_effects(entity: Node):
	"""Clear all effects from an entity"""
	if entity_effects.has(entity):
		entity_effects[entity].clear_all_effects()

func has_effect(entity: Node, effect_type: EFFECT_TYPE) -> bool:
	"""Check if entity has a specific effect"""
	if entity_effects.has(entity):
		return entity_effects[entity].has_effect(effect_type)
	return false

func get_effect_duration(entity: Node, effect_type: EFFECT_TYPE) -> int:
	"""Get remaining duration of a specific effect"""
	if entity_effects.has(entity):
		return entity_effects[entity].get_effect_duration(effect_type)
	return 0

func get_active_effects_count(entity: Node) -> int:
	"""Get the number of active effects on an entity"""
	if entity_effects.has(entity):
		var count = 0
		for effect in entity_effects[entity].effects:
			if effect.is_active:
				count += 1
		return count
	return 0

func get_effects_debug_info(entity: Node) -> Dictionary:
	"""Get debug information about all effects on an entity"""
	if not entity_effects.has(entity):
		return {"error": "No effects found for entity"}
	
	var info = {
		"entity_name": entity.name,
		"total_effects": entity_effects[entity].effects.size(),
		"active_effects": []
	}
	
	for effect in entity_effects[entity].effects:
		if effect.is_active:
			info["active_effects"].append({
				"type": effect.type,
				"duration": effect.remaining_duration,
				"damage_per_tick": effect.damage_per_tick,
				"has_visual": effect.visual_effect != null
			})
	
	return info

# Convenience methods for common effects
func apply_poison(entity: Node, damage: int, duration: int, source: Node):
	"""Apply poison effect"""
	apply_effect(entity, EFFECT_TYPE.POISON, damage, duration, source)

func apply_ignite(entity: Node, damage: int, duration: int, source: Node):
	"""Apply ignite effect"""
	apply_effect(entity, EFFECT_TYPE.IGNITE, damage, duration, source)

func apply_bone_break(entity: Node, damage: int, duration: int, source: Node):
	"""Apply bone break effect"""
	apply_effect(entity, EFFECT_TYPE.BONE_BREAK, damage, duration, source)

func apply_stun(entity: Node, duration: int, source: Node):
	"""Apply stun effect (no damage, just duration)"""
	apply_effect(entity, EFFECT_TYPE.STUN, 0, duration, source)

func apply_slow(entity: Node, duration: int, source: Node):
	"""Apply slow effect (no damage, just duration)"""
	apply_effect(entity, EFFECT_TYPE.SLOW, 0, duration, source)

func refresh_visual_effects(entity: Node):
	"""Manually refresh visual effects for an entity (useful for debugging)"""
	if entity_effects.has(entity):
		var effects = entity_effects[entity]
		for effect in effects.effects:
			if effect.is_active and effect.visual_effect == null:
				# Recreate visual effect if it's missing
				effects._create_visual_effect(effect)
				print("Recreated visual effect for ", entity.name, " - ", effect.type)
