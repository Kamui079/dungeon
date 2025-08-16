extends Node
class_name StatusEffectsManager

# Signal emitted when effects change for an entity
signal effects_changed(entity: Node)

# Configuration for visual quality
const USE_CLEAN_FALLBACK_EFFECTS = false  # Set to false to use full PNG animation with quality settings



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
		
		# Position the container at the base level - individual effects will position themselves above
		visual_effects_container.position = Vector3(0, 0, 0)

	
	func add_effect(effect_type: EFFECT_TYPE, damage: int, duration: int, source: Node):
		"""Add a new status effect"""
		# Check if effect already exists and refresh it
		for effect in effects:
			if effect.type == effect_type and effect.is_active:
				# Refresh existing effect
				effect.remaining_duration = duration
				effect.damage_per_tick = damage
		
				return
		
		# Create new effect
		var new_effect = StatusEffect.new(effect_type, damage, duration, source)
		effects.append(new_effect)
		
		# Create and display visual effect
		_create_visual_effect(new_effect)
		

		
		# Log to combat log if in combat
		_log_effect_applied(effect_type, duration)
	
	func _create_visual_effect(effect: StatusEffect):
		"""Create a visual effect for the status effect"""
		# Safety check: ensure entity is valid
		if not entity or not is_instance_valid(entity):
	
			return
		
		# Safety check: ensure we have a visual effects container
		if not visual_effects_container or not is_instance_valid(visual_effects_container):
	
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
			return
		
		# Create a Sprite3D to display the poison effect
		var poison_sprite = Sprite3D.new()
		poison_sprite.name = "PoisonEffect"
		
		# Try to load a proper poison effect texture first
		var poison_texture = null
		var texture_paths = [
			"res://status_effects/PoisonEffect-export1.png",
			"res://status_effects/PoisonEffect-export2.png",
			"res://status_effects/PoisonEffect-export3.png"
		]
		
		# Try to load one of the poison effect textures
		for path in texture_paths:
			if ResourceLoader.exists(path):
				poison_texture = load(path)
				break
		
		if poison_texture:
			# Use the actual poison effect texture
			poison_sprite.texture = poison_texture
			poison_sprite.modulate = Color(1.0, 1.0, 1.0, 0.8)  # White with transparency to preserve original colors
		else:
			# Create a simple colored circle effect without using the problematic icon.svg
			# We'll create a small, simple visual effect
			poison_sprite.modulate = Color(0.2, 1.0, 0.2, 0.6)  # Green with transparency
		
		# Set appropriate size - much smaller for a subtle status indicator
		poison_sprite.pixel_size = 0.008  # Much smaller size for status effect
		poison_sprite.billboard = true  # Always face the camera
		
		# Improve sprite rendering quality to reduce artifacts
		poison_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR  # Smooth filtering
		
		# Set alpha properties only if they exist to avoid crashes
		if "alpha_cut" in poison_sprite:
			poison_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # Clean alpha handling
		
		# Note: Some advanced alpha properties may not be available in this Godot version
		
		# Advanced quality settings for latest Godot versions
		# Note: Some advanced properties may not be available in all Godot 4.x versions
		# We'll use safe property access to avoid errors
		
		# Store reference to the visual effect
		effect.set_visual_effect(poison_sprite)
		
		# Add to visual effects container with safety check
		if visual_effects_container and is_instance_valid(visual_effects_container):
			visual_effects_container.add_child(poison_sprite)
			
			# Automatically position the sprite above the enemy based on their actual dimensions
			_auto_position_status_effect(poison_sprite, entity)
			
			# Create the 9-frame animation system
			_create_poison_frame_animation(poison_sprite)
	
	func _create_poison_frame_animation(poison_sprite: Sprite3D):
		"""Create a 9-frame animation system for the poison effect"""
		# Check if we should use clean fallback effects to avoid texture artifacts
		if USE_CLEAN_FALLBACK_EFFECTS:
			print("Using clean fallback poison effect (texture artifacts disabled)")
			_create_clean_fallback_poison_effect(poison_sprite)
			return
		
		# Load all 9 poison effect frames
		var frames: Array[Texture2D] = []
		var frame_paths = [
			"res://status_effects/PoisonEffect-export1.png",
			"res://status_effects/PoisonEffect-export2.png",
			"res://status_effects/PoisonEffect-export3.png",
			"res://status_effects/PoisonEffect-export4.png",
			"res://status_effects/PoisonEffect-export5.png",
			"res://status_effects/PoisonEffect-export6.png",
			"res://status_effects/PoisonEffect-export7.png",
			"res://status_effects/PoisonEffect-export8.png",
			"res://status_effects/PoisonEffect-export9.png"
		]
		
		# Load all available frames with quality improvements
		for path in frame_paths:
			if ResourceLoader.exists(path):
				var texture = load(path)
				if texture:
					# Apply quality improvements to reduce artifacts
					if texture is Texture2D:
						# Note: filter property may not be directly settable on CompressedTexture2D
						# We'll rely on the sprite's texture_filter setting instead
						pass
					frames.append(texture)
		
		if frames.size() == 0:
			print("Warning: No poison effect frames found, using fallback")
			# Create a simple, clean visual effect without texture artifacts
			_create_clean_fallback_poison_effect(poison_sprite)
			return
		
		print("Poison effect: Loaded ", frames.size(), " animation frames")
		
		# Create a timer to cycle through frames
		var frame_timer = Timer.new()
		frame_timer.name = "PoisonFrameTimer"
		frame_timer.wait_time = 0.12  # ~8.3 frames per second for smooth but not too fast animation
		frame_timer.timeout.connect(func(): _update_poison_frame(poison_sprite, frames, frame_timer))
		poison_sprite.add_child(frame_timer)
		frame_timer.start()
		
		# Set initial frame
		poison_sprite.texture = frames[0]
		
		# Store frame data in the sprite for the update function
		poison_sprite.set_meta("poison_frames", frames)
		poison_sprite.set_meta("current_frame", 0)
	
	func _auto_position_status_effect(sprite: Sprite3D, target_entity: Node):
		"""Automatically position status effect above the enemy based on their dimensions"""
		if not target_entity or not is_instance_valid(target_entity):
			return
		
		var effect_height = 0.0
		
		# Try to find the enemy's visual representation (CharacterBody3D, CollisionShape3D, etc.)
		var entity_root = target_entity
		if target_entity.get_parent() and target_entity.get_parent() is CharacterBody3D:
			entity_root = target_entity.get_parent()
		
		# Method 0: Check if entity has a custom height property
		if entity_root.has_method("get_status_effect_height"):
			effect_height = entity_root.get_status_effect_height()
		elif "status_effect_height" in entity_root:
			effect_height = entity_root.status_effect_height
		
		# Method 1: Check if entity has a CollisionShape3D to get dimensions
		if effect_height == 0.0:
			var collision_shape = _find_collision_shape(entity_root)
			if collision_shape:
				var shape = collision_shape.shape
				if shape is BoxShape3D:
					effect_height = shape.size.y
				elif shape is CapsuleShape3D:
					effect_height = shape.radius * 2 + shape.height
				elif shape is SphereShape3D:
					effect_height = shape.radius * 2
				elif shape is CylinderShape3D:
					effect_height = shape.height
		
		# Method 2: Check if entity has a Sprite3D or MeshInstance3D to get visual bounds
		if effect_height == 0.0:
			effect_height = _get_visual_bounds_height(entity_root)
		
		# Method 3: Fallback to a reasonable default based on entity type
		if effect_height == 0.0:
			effect_height = _get_default_entity_height(entity_root)
		
		# Position the effect above the enemy with some padding
		var padding = 0.2  # Small gap between enemy and effect
		sprite.position.y = effect_height + padding
		
		print("Auto-positioned status effect at height: ", effect_height + padding, " (entity height: ", effect_height, ")")
	
	func _find_collision_shape(target_entity: Node) -> CollisionShape3D:
		"""Find the CollisionShape3D node in the entity hierarchy"""
		if target_entity is CollisionShape3D:
			return target_entity
		
		# Search children recursively
		for child in target_entity.get_children():
			if child is CollisionShape3D:
				return child
			var result = _find_collision_shape(child)
			if result:
				return result
		
		return null
	
	func _get_visual_bounds_height(target_entity: Node) -> float:
		"""Get the height of visual elements (Sprite3D, MeshInstance3D, etc.)"""
		var max_height = 0.0
		
		# Check for Sprite3D
		if target_entity is Sprite3D:
			max_height = max(max_height, target_entity.pixel_size * 64.0)  # Approximate height
		
		# Check for MeshInstance3D
		if target_entity is MeshInstance3D and target_entity.mesh:
			var aabb = target_entity.mesh.get_aabb()
			max_height = max(max_height, aabb.size.y)
		
		# Check for AnimatedSprite3D
		if target_entity is AnimatedSprite3D:
			max_height = max(max_height, target_entity.pixel_size * 64.0)  # Approximate height
		
		# Search children recursively
		for child in target_entity.get_children():
			max_height = max(max_height, _get_visual_bounds_height(child))
		
		return max_height
	
	func _get_default_entity_height(target_entity: Node) -> float:
		"""Get a reasonable default height based on entity type/name"""
		var entity_name = target_entity.name.to_lower()
		
		# Common enemy types and their approximate heights
		if "rat" in entity_name or "mouse" in entity_name or "small" in entity_name:
			return 0.5
		elif "goblin" in entity_name or "humanoid" in entity_name or "medium" in entity_name:
			return 1.8
		elif "troll" in entity_name or "giant" in entity_name or "large" in entity_name:
			return 3.0
		elif "dragon" in entity_name or "huge" in entity_name or "massive" in entity_name:
			return 4.0
		elif "boss" in entity_name:
			return 2.5  # Boss enemies are typically larger
		else:
			return 1.5  # Default human-sized height
	
	func _create_clean_fallback_poison_effect(poison_sprite: Sprite3D):
		"""Create a clean, simple poison effect without texture artifacts"""
		# Remove any existing texture to avoid artifacts
		poison_sprite.texture = null
		
		# Create a simple colored effect with clean edges
		poison_sprite.modulate = Color(0.2, 1.0, 0.2, 0.7)  # Green with transparency
		
		# Use a simple shape instead of texture for cleaner appearance
		# Note: Sprite3D uses BaseMaterial3D.TextureFilter, not CanvasItem.TextureFilter
		poison_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Sharp pixels
		
		# Set alpha properties only if they exist to avoid crashes
		if "alpha_cut" in poison_sprite:
			poison_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		
		print("Created clean fallback poison effect")
	
	func _update_poison_frame(poison_sprite: Sprite3D, frames: Array[Texture2D], timer: Timer):
		"""Update to the next frame in the poison animation"""
		if not is_instance_valid(poison_sprite) or not is_instance_valid(timer):
			return
		
		var current_frame = poison_sprite.get_meta("current_frame", 0)
		current_frame = (current_frame + 1) % frames.size()
		
		poison_sprite.texture = frames[current_frame]
		poison_sprite.set_meta("current_frame", current_frame)
	
	func _create_ignite_effect(_effect: StatusEffect):
		"""Create an ignite visual effect"""
		# Placeholder for future ignite effects
		pass
	
	func _create_bone_break_effect(_effect: StatusEffect):
		"""Create a bone break visual effect"""
		# Placeholder for future bone break effects
		pass
	
	func _create_stun_effect(_effect: StatusEffect):
		"""Create a stun visual effect"""
		# Placeholder for future stun effects
		pass
	
	func _create_slow_effect(_effect: StatusEffect):
		"""Create a slow visual effect"""
		# Placeholder for future slow effects
		pass
	
	func _create_bleed_effect(_effect: StatusEffect):
		"""Create a bleed visual effect"""
		# Placeholder for future bleed effects
		pass
	
	func _create_freeze_effect(_effect: StatusEffect):
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
		
				break
	
	func clear_all_effects():
		"""Clear all status effects"""
		for effect in effects:
			# Remove visual effects
			if effect.visual_effect and is_instance_valid(effect.visual_effect):
				effect.visual_effect.queue_free()
			
			effect.is_active = false
		effects.clear()

	
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

# End of EntityStatusEffects class

# Global status effects manager
var entity_effects: Dictionary = {}  # entity -> EntityStatusEffects

func _ready():
	add_to_group("StatusEffectsManager")
	
	# Version check for debugging
	print("StatusEffectsManager: Godot version check")
	var version_info = Engine.get_version_info()
	print("  - Engine version: ", version_info.get("version_string", "Unknown"))
	print("  - Engine version hash: ", version_info.get("hash", "Unknown"))

func get_entity_effects(entity: Node) -> EntityStatusEffects:
	"""Get or create status effects for an entity"""
	if not entity_effects.has(entity):
		entity_effects[entity] = EntityStatusEffects.new(entity)
	return entity_effects[entity]

func apply_effect(entity: Node, effect_type: EFFECT_TYPE, damage: int, duration: int, source: Node):
	"""Apply a status effect to an entity"""
	var effects = get_entity_effects(entity)
	effects.add_effect(effect_type, damage, duration, source)
	
	# Emit signal for UI updates
	effects_changed.emit(entity)

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
