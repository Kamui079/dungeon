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
	SHOCK,
	PARALYSIS,
	FROSTBITE,
	BLESSING,
	PETRIFY,
	RECAST_SPELL,
	CORRUPTION,
	MAGIC_VULNERABILITY,
	WATERLOGGED
}

# Base status effect class
class StatusEffect:
	var type: EFFECT_TYPE
	var effect_category: String = "status" # "buff", "debuff", or "status"
	var damage_per_tick: int
	var duration: int
	var remaining_duration: int
	var source: Node  # Who applied the effect
	var entity: Node  # Who the effect is applied to
	var is_active: bool = true
	var visual_effect: Node = null  # Reference to the visual effect node
	var effect_value: float = 0.0 # Generic value for effects like Petrify's slow % or Waterlogged stacks
	var is_petrified: bool = false # For Petrify effect
	var recast_data: Dictionary = {} # For RECAST_SPELL effect
	
	func _init(effect_type: EFFECT_TYPE, damage: int, effect_duration: int, effect_source: Node, effect_entity: Node):
		type = effect_type
		damage_per_tick = damage
		duration = effect_duration
		remaining_duration = effect_duration
		source = effect_source
		entity = effect_entity
	
	func tick() -> int:
		"""Process one tick of the effect, return damage dealt"""
		if not is_active or remaining_duration <= 0:
			return 0
		
		remaining_duration -= 1
		var damage_dealt = damage_per_tick
		
		# Apply damage directly with proper damage type for damage numbers
		if damage_dealt > 0:
			var damage_type = _get_damage_type_for_effect()
			# Try to find the correct node to call take_damage on
			var target_node = _find_take_damage_target()
			if target_node and target_node.has_method("take_damage"):
				target_node.take_damage(damage_dealt, damage_type)
				

		
		if remaining_duration <= 0:
			is_active = false
		
		return damage_dealt
	
	func _find_take_damage_target() -> Node:
		"""Find the correct node to call take_damage on"""
		# First try the entity itself
		if entity and entity.has_method("take_damage"):
			return entity
		
		# If entity doesn't have take_damage, look for enemy_behavior child
		if entity:
			for child in entity.get_children():
				if child.has_method("take_damage"):
					return child
		
		return null
	
	func _get_damage_type_for_effect() -> String:
		"""Get the damage type string for this status effect"""
		match type:
			EFFECT_TYPE.POISON:
				return "poison"
			EFFECT_TYPE.IGNITE:
				return "ignite"
			EFFECT_TYPE.BLEED:
				return "bleed"
			EFFECT_TYPE.FREEZE:
				return "freeze"
			EFFECT_TYPE.SHOCK:
				return "shock"
			EFFECT_TYPE.BLESSING:
				return "holy"
			EFFECT_TYPE.PARALYSIS:
				return "lightning"  # Paralysis is lightning-based
			EFFECT_TYPE.FROSTBITE:
				return "ice"  # Frostbite is ice damage
			EFFECT_TYPE.BONE_BREAK:
				return "physical"  # Bone break is physical damage
			EFFECT_TYPE.STUN:
				return "physical"  # Stun is physical damage
			EFFECT_TYPE.SLOW:
				return "physical"  # Slow is physical damage
			_:
				return "physical"  # Default fallback
	
	func get_remaining_duration() -> int:
		return remaining_duration
	
	func is_expired() -> bool:
		return remaining_duration <= 0 or not is_active
	
	func set_visual_effect(effect_node: Node):
		visual_effect = effect_node
	
	func get_visual_effect() -> Node:
		return visual_effect
	
	func _get_effect_name(effect_type: EFFECT_TYPE) -> String:
		"""Get the display name for a status effect type"""
		match effect_type:
			EFFECT_TYPE.POISON:
				return "poison"
			EFFECT_TYPE.IGNITE:
				return "ignite"
			EFFECT_TYPE.BLEED:
				return "bleed"
			EFFECT_TYPE.FREEZE:
				return "freeze"
			EFFECT_TYPE.SHOCK:
				return "shock"
			EFFECT_TYPE.PARALYSIS:
				return "paralysis"
			EFFECT_TYPE.BONE_BREAK:
				return "bone break"
			EFFECT_TYPE.STUN:
				return "stun"
			EFFECT_TYPE.SLOW:
				return "slow"
			_:
				return "unknown effect"
	


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

	
	func add_effect(effect_type: EFFECT_TYPE, category: String, damage: int, duration: int, source: Node):
		"""Add a new status effect"""
		# Check if effect already exists and refresh it
		for effect in effects:
			if effect.type == effect_type and effect.is_active:
				# Refresh existing effect
				effect.remaining_duration = duration
				effect.damage_per_tick = damage
				effect.effect_category = category
				return
		
		# Create new effect
		var new_effect = StatusEffect.new(effect_type, damage, duration, source, entity)
		new_effect.effect_category = category
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
			EFFECT_TYPE.PARALYSIS:
				_create_paralysis_effect(effect)
	
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
		var padding = -0.1  # Reduced padding to make effect spawn lower (was 0.2)
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
	
	func _create_paralysis_effect(_effect: StatusEffect):
		"""Create a paralysis visual effect with lightning/electrical theme"""
		# Create a Sprite3D to display the paralysis effect
		var paralysis_sprite = Sprite3D.new()
		paralysis_sprite.name = "ParalysisEffect"
		
		# Create a simple lightning/electrical effect
		paralysis_sprite.modulate = Color(1.0, 1.0, 0.3, 0.8)  # Bright yellow with transparency
		
		# Position the effect above the entity
		var effect_height = _get_visual_bounds_height(entity) + 0.5
		paralysis_sprite.position = Vector3(0, effect_height, 0)
		
		# Add to visual effects container
		visual_effects_container.add_child(paralysis_sprite)
		
		# Store reference to visual effect
		_effect.set_visual_effect(paralysis_sprite)
		
		# Create a pulsing animation effect using the entity's create_tween
		if entity.has_method("create_tween"):
			var tween = entity.create_tween()
			tween.set_loops()  # Loop indefinitely
			tween.tween_property(paralysis_sprite, "modulate:a", 0.3, 0.5)
			tween.tween_property(paralysis_sprite, "modulate:a", 0.8, 0.5)
		else:
			# Fallback: just set a static alpha value if tweening isn't available
			paralysis_sprite.modulate.a = 0.6
		
		print("⚡ Created paralysis visual effect for ", entity.name)
	
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
		var effects_to_remove: Array[int] = []
		
		for i in range(effects.size()):
			var effect = effects[i]
			if effect.is_expired():
				# Remove visual effect when effect expires
				if effect.visual_effect and is_instance_valid(effect.visual_effect):
					effect.visual_effect.queue_free()
				
				effects_to_remove.append(i)
				continue
			
			# Process the effect (damage is now handled directly by each effect)
			var damage = effect.tick()
			if damage > 0:
				_log_effect_damage(effect.type, damage)

			# Handle special tick effects
			if effect.type == EFFECT_TYPE.CORRUPTION:
				if randf() < 0.25: # 25% chance
					_apply_random_debuff_from_corruption(effect)
		
		# Remove expired effects
		for i in range(effects_to_remove.size() - 1, -1, -1):
			effects.remove_at(effects_to_remove[i])
	
	func _apply_random_debuff_from_corruption(corruption_effect: StatusEffect):
		"""Apply a random debuff, called from the Corruption effect's tick."""
		var status_manager = entity.get_tree().get_first_node_in_group("StatusEffectsManager")
		if not status_manager: return

		var debuffs = [
			EFFECT_TYPE.POISON, EFFECT_TYPE.IGNITE, EFFECT_TYPE.BONE_BREAK,
			EFFECT_TYPE.STUN, EFFECT_TYPE.SLOW, EFFECT_TYPE.BLEED,
			EFFECT_TYPE.FREEZE, EFFECT_TYPE.SHOCK, EFFECT_TYPE.PARALYSIS,
			EFFECT_TYPE.FROSTBITE, EFFECT_TYPE.PETRIFY
		]
		var random_debuff = debuffs[randi() % debuffs.size()]

		# The source of the new debuff is the original source of the corruption
		var source = corruption_effect.source

		# Petrify has a unique application function
		if random_debuff == EFFECT_TYPE.PETRIFY:
			status_manager.apply_petrify(entity, source)
		else:
			# Apply other debuffs with a standard damage/duration
			var random_damage = 5
			var random_duration = 2
			status_manager.apply_effect(entity, random_debuff, "debuff", random_damage, random_duration, source)

		_log_to_combat("⚫ Corruption spreads! " + entity.name + " is now " + _get_effect_display_name(random_debuff) + "ed!")

	
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
	
	func _get_damage_type_for_effect(effect_type: EFFECT_TYPE) -> String:
		"""Get the damage type string for a status effect"""
		match effect_type:
			EFFECT_TYPE.POISON:
				return "poison"
			EFFECT_TYPE.IGNITE:
				return "ignite"
			EFFECT_TYPE.BLEED:
				return "bleed"
			EFFECT_TYPE.FREEZE:
				return "freeze"
			EFFECT_TYPE.SHOCK:
				return "shock"
			EFFECT_TYPE.BONE_BREAK:
				return "physical"  # Bone break is physical damage
			EFFECT_TYPE.STUN:
				return "physical"  # Stun is physical damage
			EFFECT_TYPE.SLOW:
				return "physical"  # Slow is physical damage
			_:
				return "physical"  # Default fallback

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

func apply_effect(entity: Node, effect_type: EFFECT_TYPE, category: String, damage: int, duration: int, source: Node):
	"""Apply a status effect to an entity"""
	# Check for Waterlogged backfire before applying any buffs
	if category == "buff":
		var waterlogged_effect = get_effect(entity, EFFECT_TYPE.WATERLOGGED)
		if waterlogged_effect:
			var stacks = waterlogged_effect.effect_value
			# Exponential damage: 10 * (1.5 ^ (stacks - 1))
			var backfire_damage = int(10 * pow(1.5, stacks - 1))

			# The entity takes damage instead of getting the buff
			if entity.has_method("take_damage"):
				entity.take_damage(backfire_damage, "water")

			# Log the backfire
			var combat_manager = get_tree().get_first_node_in_group("CombatManager")
			if combat_manager:
				combat_manager._log_combat_event("💧 " + entity.name + "'s buff backfired due to being Waterlogged, causing " + str(backfire_damage) + " damage!")

			# Remove the waterlogged effect
			remove_effect(entity, EFFECT_TYPE.WATERLOGGED)

			# Stop the buff from being applied
			return

	var effects = get_entity_effects(entity)
	effects.add_effect(effect_type, category, damage, duration, source)
	
	# Log status effect to combat log
	var entity_name = "Unknown"
	if entity.has_method("enemy_name"):
		entity_name = entity.enemy_name()
	elif entity.has_method("get_name"):
		entity_name = entity.get_name()
	elif "name" in entity:
		var name_property = entity.name
		entity_name = name_property if name_property is String else str(name_property)
	
	var effect_name = ""
	match effect_type:
			EFFECT_TYPE.POISON:
				effect_name = "poisoned"
			EFFECT_TYPE.IGNITE:
				effect_name = "ignited"
			EFFECT_TYPE.BONE_BREAK:
				effect_name = "bone broken"
			EFFECT_TYPE.STUN:
				effect_name = "stunned"
			EFFECT_TYPE.SLOW:
				effect_name = "slowed"
			EFFECT_TYPE.FREEZE:
				effect_name = "frozen"
			EFFECT_TYPE.FROSTBITE:
				effect_name = "frostbitten"
			EFFECT_TYPE.BLESSING:
				effect_name = "blessed"
			_:
				effect_name = "affected by status effect"
	
	# Try to log to combat manager if available
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager and combat_manager.has_method("_log_combat_event"):
		combat_manager._log_combat_event("☠️ " + entity_name + " is " + effect_name + "! (" + str(duration) + " turns)")
	
	# Emit signal for UI updates
	effects_changed.emit(entity)

func remove_effect(entity: Node, effect_type: EFFECT_TYPE):
	"""Remove a specific effect from an entity"""
	if entity_effects.has(entity):
		entity_effects[entity].remove_effect(effect_type)
		
		# Log status effect removal to combat log
		var entity_name = "Unknown"
		if entity.has_method("enemy_name"):
			entity_name = entity.enemy_name()
		elif entity.has_method("get_name"):
			entity_name = entity.get_name()
		elif "name" in entity:
			var name_property = entity.name
			entity_name = name_property if name_property is String else str(name_property)
		
		var effect_name = ""
		match effect_type:
			EFFECT_TYPE.POISON:
				effect_name = "poison"
			EFFECT_TYPE.IGNITE:
				effect_name = "ignite"
			EFFECT_TYPE.BONE_BREAK:
				effect_name = "bone break"
			EFFECT_TYPE.STUN:
				effect_name = "stun"
			EFFECT_TYPE.SLOW:
				effect_name = "slow"
			EFFECT_TYPE.FREEZE:
				effect_name = "freeze"
			EFFECT_TYPE.PARALYSIS:
				effect_name = "paralysis"
			EFFECT_TYPE.FROSTBITE:
				effect_name = "frostbite"
			EFFECT_TYPE.BLESSING:
				effect_name = "blessing"
			_:
				effect_name = "status effect"
		
		# Try to log to combat manager if available
		var combat_manager = get_tree().get_first_node_in_group("CombatManager")
		if combat_manager and combat_manager.has_method("_log_combat_event"):
			combat_manager._log_combat_event("✨ " + entity_name + " is no longer " + effect_name + "ed!")

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
		"entity_name": str(entity.name),
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
	apply_effect(entity, EFFECT_TYPE.POISON, "debuff", damage, duration, source)

func apply_ignite(entity: Node, damage: int, duration: int, source: Node):
	"""Apply ignite effect"""
	apply_effect(entity, EFFECT_TYPE.IGNITE, "debuff", damage, duration, source)

func apply_bone_break(entity: Node, damage: int, duration: int, source: Node):
	"""Apply bone break effect"""
	apply_effect(entity, EFFECT_TYPE.BONE_BREAK, "debuff", damage, duration, source)

func apply_stun(entity: Node, duration: int, source: Node):
	"""Apply stun effect (no damage, just duration)"""
	apply_effect(entity, EFFECT_TYPE.STUN, "debuff", 0, duration, source)

func apply_slow(entity: Node, duration: int, source: Node):
	"""Apply slow effect (no damage, just duration)"""
	apply_effect(entity, EFFECT_TYPE.SLOW, "debuff", 0, duration, source)

func apply_paralysis(entity: Node, duration: int, source: Node):
	"""Apply paralysis effect with overload mechanic"""
	# Check if entity already has paralysis from lightning
	if has_effect(entity, EFFECT_TYPE.PARALYSIS):
		# Trigger overload - lightning explosion in radius
		_trigger_lightning_overload(entity, source)
		# Remove the existing paralysis effect
		remove_effect(entity, EFFECT_TYPE.PARALYSIS)
		return
	
	# Apply normal paralysis effect
	apply_effect(entity, EFFECT_TYPE.PARALYSIS, "debuff", 0, duration, source)

func apply_freeze(entity: Node, duration: int, source: Node):
	"""Apply freeze effect (no damage, just duration)"""
	apply_effect(entity, EFFECT_TYPE.FREEZE, "debuff", 0, duration, source)

func apply_frostbite(entity: Node, damage_per_action: int, duration: int, source: Node):
	"""Apply frostbite effect - deals damage when entity takes actions"""
	apply_effect(entity, EFFECT_TYPE.FROSTBITE, "debuff", damage_per_action, duration, source)

func apply_blessing(entity: Node, duration: int, source: Node):
	"""Apply blessing effect - provides random buffs"""
	apply_effect(entity, EFFECT_TYPE.BLESSING, "buff", 0, duration, source)

func apply_petrify(entity: Node, source: Node):
	"""Apply or stack the petrify effect."""
	var effects_manager = get_entity_effects(entity)
	var petrify_effect = null
	for effect in effects_manager.effects:
		if effect.type == EFFECT_TYPE.PETRIFY:
			petrify_effect = effect
			break

	if petrify_effect:
		# If already petrified, do nothing here. Shatter logic is handled in combat manager.
		if petrify_effect.is_petrified:
			return

		# Effect exists, increment it
		petrify_effect.effect_value = min(100.0, petrify_effect.effect_value + 25.0)
		petrify_effect.remaining_duration = 99 # Refresh duration so it doesn't expire while stacking

		if petrify_effect.effect_value >= 100.0:
			petrify_effect.is_petrified = true
			petrify_effect.remaining_duration = 3 # Petrified for 2 turns (3 ticks: turn start, end of turn 1, end of turn 2)
			_log_to_combat("🗿 " + entity.name + " has been turned to stone!")
	else:
		# Effect does not exist, create it
		petrify_effect = StatusEffect.new(EFFECT_TYPE.PETRIFY, 0, 99, source, entity)
		petrify_effect.effect_value = 25.0
		effects_manager.effects.append(petrify_effect)

	# Log and emit signal
	print(entity.name + " petrify at " + str(petrify_effect.effect_value) + "%")
	effects_changed.emit(entity)

func is_petrified(entity: Node) -> bool:
	"""Check if an entity is currently petrified."""
	if entity_effects.has(entity):
		for effect in entity_effects[entity].effects:
			if effect.type == EFFECT_TYPE.PETRIFY and effect.is_petrified:
				return true
	return false

func get_effect(entity: Node, effect_type: EFFECT_TYPE) -> StatusEffect:
	"""Get a specific status effect instance from an entity, if it exists."""
	if entity_effects.has(entity):
		for effect in entity_effects[entity].effects:
			if effect.type == effect_type and effect.is_active:
				return effect
	return null

func apply_recast_spell(entity: Node, source: Node, duration: int, data: Dictionary):
	"""Apply an effect that will re-cast a spell later."""
	var effects_manager = get_entity_effects(entity)
	var recast_effect = StatusEffect.new(EFFECT_TYPE.RECAST_SPELL, 0, duration, source, entity)
	recast_effect.effect_category = "status"
	recast_effect.recast_data = data
	effects_manager.effects.append(recast_effect)
	effects_changed.emit(entity)

func apply_magic_vulnerability(entity: Node, duration: int, source: Node):
	"""Apply magic vulnerability effect. The magnitude (10%) is stored in the damage field."""
	apply_effect(entity, EFFECT_TYPE.MAGIC_VULNERABILITY, "debuff", 10, duration, source)

func apply_corruption(entity: Node, damage: int, duration: int, source: Node):
	"""Apply corruption effect, a DoT that can apply other debuffs."""
	apply_effect(entity, EFFECT_TYPE.CORRUPTION, "debuff", damage, duration, source)

func apply_waterlogged(entity: Node, source: Node, stacks: int):
	"""Apply or stack the waterlogged effect."""
	var effects_manager = get_entity_effects(entity)
	var waterlogged_effect = null
	for effect in effects_manager.effects:
		if effect.type == EFFECT_TYPE.WATERLOGGED:
			waterlogged_effect = effect
			break

	if waterlogged_effect:
		waterlogged_effect.effect_value += stacks
	else:
		waterlogged_effect = StatusEffect.new(EFFECT_TYPE.WATERLOGGED, 0, 99, source, entity)
		waterlogged_effect.effect_category = "debuff"
		waterlogged_effect.effect_value = stacks
		effects_manager.effects.append(waterlogged_effect)

	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager:
		combat_manager._log_combat_event("💧 " + entity.name + " is Waterlogged! (Stacks: " + str(waterlogged_effect.effect_value) + ")")
	effects_changed.emit(entity)

func _trigger_lightning_overload(entity: Node, source: Node):
	"""Trigger lightning overload explosion when paralysis is applied again"""
	var entity_name = str(entity.name)
	print("⚡ Lightning overload triggered on ", entity_name, "!")
	
	# Calculate overload damage (based on source's lightning damage or fixed value)
	var overload_damage = 25  # Base overload damage
	if source and source.has_method("get_lightning_damage"):
		overload_damage = source.get_lightning_damage()
	
	# Find entities in radius for area damage
	var radius = 3.0  # 3 unit radius
	var entities_in_radius = _find_entities_in_radius(entity.global_position, radius)
	
	# Apply lightning damage to all entities in radius (including the source of overload)
	for target_entity in entities_in_radius:
		if target_entity.has_method("take_damage"):
			target_entity.take_damage(overload_damage, "lightning")
			var target_name = str(target_entity.name)
			print("⚡ Overload hit ", target_name, " for ", overload_damage, " lightning damage!")
	
	# Log to combat manager if available
	var combat_manager = get_tree().get_first_node_in_group("CombatManager")
	if combat_manager and combat_manager.has_method("_log_combat_event"):
		var overload_entity_name = str(entity.name)
		combat_manager._log_combat_event("⚡ " + overload_entity_name + " overloaded with lightning, dealing " + str(overload_damage) + " damage to nearby targets!")

func _find_entities_in_radius(center_position: Vector3, radius: float) -> Array:
	"""Find all entities within a radius of the given position"""
	var entities = []
	
	# Get all nodes in the scene
	var scene_tree = get_tree()
	if not scene_tree:
		return entities
	
	# Look for entities with take_damage method (players, enemies, etc.)
	var all_nodes = scene_tree.get_nodes_in_group("Player")
	all_nodes.append_array(scene_tree.get_nodes_in_group("Enemy"))
	
	for node in all_nodes:
		if node.has_method("take_damage") and is_instance_valid(node):
			var distance = center_position.distance_to(node.global_position)
			if distance <= radius:
				entities.append(node)
	
	return entities

func refresh_visual_effects(entity: Node):
	"""Manually refresh visual effects for an entity (useful for debugging)"""
	if entity_effects.has(entity):
		var effects = entity_effects[entity]
		for effect in effects.effects:
			if effect.is_active and effect.visual_effect == null:
				# Recreate visual effect if it's missing
				effects._create_visual_effect(effect)
