extends Node
class_name AnimationManager

# Animation types
enum ANIMATION_TYPE {
	FIRE_MAGIC,
	FROST_MAGIC,
	LIGHTNING_MAGIC,
	ICE_MAGIC,
	HOLY_MAGIC,
	PHYSICAL_ATTACK,
	THROW_ATTACK
}

# Animation durations (in seconds)
var animation_durations = {
	ANIMATION_TYPE.FIRE_MAGIC: 3.0,
	ANIMATION_TYPE.FROST_MAGIC: 4.0,
	ANIMATION_TYPE.LIGHTNING_MAGIC: 2.5,
	ANIMATION_TYPE.ICE_MAGIC: 3.5,
	ANIMATION_TYPE.HOLY_MAGIC: 3.5,
	ANIMATION_TYPE.PHYSICAL_ATTACK: 2.0,
	ANIMATION_TYPE.THROW_ATTACK: 2.5
}

# Animation signals
signal animation_started(animation_type: ANIMATION_TYPE, actor: Node)
signal animation_finished(animation_type: ANIMATION_TYPE, actor: Node)
signal animation_damage_ready(animation_type: ANIMATION_TYPE, actor: Node, target: Node, damage: int, damage_type: String)

# Currently playing animations
var active_animations: Dictionary = {}

func play_attack_animation(actor: Node, animation_type: ANIMATION_TYPE) -> void:
	"""Play an attack animation for the given actor"""
	if not actor or not is_instance_valid(actor):
		print("ERROR: Cannot play animation - invalid actor")
		return
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		print("ERROR: Cannot play animation - invalid actor instance ID")
		return
	
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("🎬 Playing ", _get_animation_name(animation_type), " animation for ", actor_name)
	
	# Emit animation started signal
	animation_started.emit(animation_type, actor)
	
	# Create a timer for the animation duration
	var animation_timer = Timer.new()
	animation_timer.name = "animation_timer_" + str(actor.get_instance_id())
	animation_timer.wait_time = animation_durations[animation_type]
	animation_timer.one_shot = true
	
	# Connect timer timeout to finish animation
	animation_timer.timeout.connect(func():
		print("🎬 Animation timer timeout for ", actor_name, ", calling _finish_animation")
		_finish_animation(actor, animation_type)
		animation_timer.queue_free()
	)
	
	# Store the timer reference
	active_animations[actor.get_instance_id()] = animation_timer
	
	# Add timer to scene and start
	add_child(animation_timer)
	print("🎬 Starting animation timer for ", actor_name, " with duration: ", animation_durations[animation_type], "s")
	print("🎬 Timer added to scene tree: ", animation_timer.is_inside_tree())
	animation_timer.start()
	print("🎬 Timer started, waiting for timeout...")
	
	# Play the actual animation effect
	_play_animation_effect(actor, animation_type)

func play_attack_animation_with_damage(actor: Node, animation_type: ANIMATION_TYPE, target: Node, damage: int, damage_type: String) -> void:
	"""Play an attack animation and emit damage signal when animation completes"""
	if not actor or not is_instance_valid(actor):
		print("ERROR: Cannot play animation - invalid actor")
		return
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		print("ERROR: Cannot play animation - invalid actor instance ID")
		return
	
	# Check if actor already has an animation playing
	if active_animations.has(actor_id):
		print("⚠️ Actor ", actor, " already has animation playing, stopping previous animation")
		stop_actor_animations(actor)
	
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("🎬 Playing ", _get_animation_name(animation_type), " animation for ", actor_name, " with damage: ", damage, " ", damage_type)
	
	# Emit animation started signal
	animation_started.emit(animation_type, actor)
	
	# Check if this will be a moving attack effect (which handles its own timing)
	var will_use_moving_effect = _will_use_moving_effect(actor, animation_type)
	
	if will_use_moving_effect:
		# For moving effects, don't create a timer - the visual animation will trigger damage when it completes
		print("🎬 Using moving attack effect - damage will trigger when animation completes")
		# Store the damage info for the moving effect to use, including the animation type
		actor.set_meta("pending_damage", {"damage": damage, "damage_type": damage_type, "target": target, "animation_type": animation_type})
	else:
		# For static effects, use the timer system as before
		print("🎬 Using static attack effect - creating timer for damage")
		# Create a timer for the animation duration
		var animation_timer = Timer.new()
		animation_timer.name = "animation_timer_" + str(actor.get_instance_id())
		animation_timer.wait_time = animation_durations[animation_type]
		animation_timer.one_shot = true
		
		# Connect timer timeout to emit damage signal
		animation_timer.timeout.connect(func():
			print("🎬 Animation completed, emitting damage signal for ", actor_name)
			
			# Only emit the signal - let the combat manager handle it
			# Don't call the combat manager directly to prevent double damage
			print("🎬 Emitting animation_damage_ready signal")
			animation_damage_ready.emit(animation_type, actor, target, damage, damage_type)
			
			_finish_animation(actor, animation_type)
			animation_timer.queue_free()
		)
		
		# Store the timer reference
		active_animations[actor.get_instance_id()] = animation_timer
		
		# Add timer to scene and start
		add_child(animation_timer)
		print("🎬 Starting animation timer for ", actor_name, " with duration: ", animation_durations[animation_type], "s")
		print("🎬 Timer added to scene tree: ", animation_timer.is_inside_tree())
		animation_timer.start()
		print("🎬 Timer started, waiting for timeout...")
	
	# Play the actual animation effect
	_play_animation_effect(actor, animation_type)

func play_queued_player_animation(actor: Node, animation_type: ANIMATION_TYPE, target: Node, damage: int, damage_type: String) -> void:
	"""Play a queued player animation and emit damage signal when animation completes"""
	if not actor or not is_instance_valid(actor):
		print("ERROR: Cannot play animation - invalid actor")
		return
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		print("ERROR: Cannot play animation - invalid actor instance ID")
		return
	
	# Check if actor already has an animation playing
	if active_animations.has(actor_id):
		print("⚠️ Actor ", actor, " already has animation playing, stopping previous animation")
		stop_actor_animations(actor)
	
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("🎬 Playing ", _get_animation_name(animation_type), " animation for ", actor_name, " with damage: ", damage, " ", damage_type)
	
	# Emit animation started signal
	animation_started.emit(animation_type, actor)
	
	# Create a timer for the animation duration
	var animation_timer = Timer.new()
	animation_timer.name = "animation_timer_" + str(actor.get_instance_id())
	animation_timer.wait_time = animation_durations[animation_type]
	animation_timer.one_shot = true
	
	# Connect timer timeout to emit damage signal
	animation_timer.timeout.connect(func():
		print("🎬 Animation completed, emitting damage signal for ", actor_name)
		
		# Only emit the signal - let the combat manager handle it
		# Don't call the combat manager directly to prevent double damage
		print("🎬 Emitting animation_damage_ready signal")
		animation_damage_ready.emit(animation_type, actor, target, damage, damage_type)
		
		_finish_animation(actor, animation_type)
		animation_timer.queue_free()
	)
	
	# Store the timer reference
	active_animations[actor.get_instance_id()] = animation_timer
	
	# Add timer to scene and start
	add_child(animation_timer)
	print("🎬 Starting animation timer for ", actor_name, " with duration: ", animation_durations[animation_type], "s")
	print("🎬 Timer added to scene tree: ", animation_timer.is_inside_tree())
	animation_timer.start()
	print("🎬 Timer started, waiting for timeout...")
	
	# Play the actual animation effect
	_play_animation_effect(actor, animation_type)

func _play_animation_effect(actor: Node, animation_type: ANIMATION_TYPE) -> void:
	"""Play the visual effect for the animation"""
	if not actor or not is_instance_valid(actor):
		return
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		return
	
	match animation_type:
		ANIMATION_TYPE.FIRE_MAGIC:
			_play_fire_magic_effect(actor, "🔥 FIRE MAGIC", "fire")
		ANIMATION_TYPE.FROST_MAGIC:
			_play_frost_magic_effect(actor, "❄️ FROST MAGIC", "ice")
		ANIMATION_TYPE.LIGHTNING_MAGIC:
			_play_lightning_magic_effect(actor, "⚡ LIGHTNING MAGIC", "lightning")
		ANIMATION_TYPE.ICE_MAGIC:
			_play_ice_magic_effect(actor, "❄️ ICE MAGIC", "ice")
		ANIMATION_TYPE.HOLY_MAGIC:
			_play_holy_magic_effect(actor, "✨ HOLY MAGIC", "holy")
		ANIMATION_TYPE.PHYSICAL_ATTACK:
			_play_physical_attack_effect(actor, "⚔️ PHYSICAL ATTACK", "physical")
		ANIMATION_TYPE.THROW_ATTACK:
			_play_throw_attack_effect(actor, "🎯 THROW ATTACK", "magic")

func _play_physical_attack_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play physical attack visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("⚔️ Playing physical attack effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _play_fire_magic_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play fire magic visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("🔥 Playing fire magic effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _play_frost_magic_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play frost magic visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.name
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("❄️ Playing frost magic effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _play_lightning_magic_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play lightning magic visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("⚡ Playing lightning magic effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _play_ice_magic_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play ice magic visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("❄️ Playing ice magic effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _play_holy_magic_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play holy magic visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("✨ Playing holy magic effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _play_throw_attack_effect(actor: Node, attack_name: String, attack_type: String):
	"""Play throw attack visual effect"""
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.name
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("🎯 Playing throw attack effect for ", actor_name)
	
	# Get the target for this attack
	var target = _get_target_for_actor(actor)
	if target:
		# Create moving attack effect that flies to target
		_create_moving_attack_effect(actor, attack_name, attack_type, target)
	else:
		# Fallback to static effect if no target found
		_create_attack_effect(actor, attack_name, attack_type)

func _create_attack_effect(actor: Node, text: String, attack_type: String = "") -> void:
	"""Create an attack effect with color coding based on attack type"""
	if not actor or not is_instance_valid(actor):
		return
	
	print("🎬 DEBUG: _create_attack_effect called with:")
	print("🎬 DEBUG: - actor: ", actor.name if actor.name else "unnamed")
	print("🎬 DEBUG: - actor class: ", actor.get_class())
	print("🎬 DEBUG: - actor parent: ", actor.get_parent().name if actor.get_parent() else "no parent")
	print("🎬 DEBUG: - text: ", text)
	print("🎬 DEBUG: - attack_type: ", attack_type)
	
	# Get the color based on attack type using the existing damage types system
	var color = DamageTypes.get_damage_color_from_string(attack_type)
	
	# Create the effect with the appropriate color
	var effect = _create_placeholder_effect(text, color)
	
	# Ensure the text starts with full opacity
	var label_3d = effect.get_child(0)
	if label_3d and label_3d is Label3D:
		label_3d.modulate.a = 1.0
	
	# Attach the effect to the actor
	_attach_effect_to_actor(actor, effect)
	
	print("🎬 Created colored attack effect: ", text, " (", attack_type, ") with color: ", color)

func _create_damage_effect(actor: Node, damage: int, is_critical: bool = false, damage_type: String = "") -> void:
	"""Create a damage effect with color coding based on damage type"""
	if not actor or not is_instance_valid(actor):
		return
	
	var text = str(damage)
	if is_critical:
		text = "CRIT " + text
	
	# Get the color based on damage type using the existing damage types system
	var color = DamageTypes.get_damage_color_from_string(damage_type)
	
	# Create the effect with the appropriate color
	var effect = _create_placeholder_effect(text, color)
	
	# Ensure the text starts with full opacity
	var label_3d = effect.get_child(0)
	if label_3d and label_3d is Label3D:
		label_3d.modulate.a = 1.0
	
	# Attach the effect to the actor
	_attach_effect_to_actor(actor, effect)
	
	print("🎬 Created damage effect: ", text, " (", damage_type, ") with color: ", color)

func _create_placeholder_effect(text: String, color: Color) -> Node3D:
	"""Create a placeholder effect with the given text and color"""
	var effect = Node3D.new()
	
	# Create a Label3D for the text
	var label = Label3D.new()
	label.text = text
	label.font_size = 24  # Much smaller font size
	label.billboard = true  # Always face the camera
	label.fixed_size = true  # Keep consistent size regardless of distance
	label.shaded = false  # Unshaded for better visibility
	label.double_sided = true  # Visible from both sides
	label.modulate = color
	
	# Set a much smaller scale for the label
	label.pixel_size = 0.01  # Much smaller pixel size for 3D text
	
	effect.add_child(label)
	
	# Set the effect to a much smaller initial scale
	effect.scale = Vector3(0.5, 0.5, 0.5)  # Start at half size
	
	return effect

func _attach_effect_to_actor(actor: Node, effect: Node3D) -> void:
	"""Attach an effect to an actor"""
	if not actor or not is_instance_valid(actor):
		return
	
	print("🎬 DEBUG: _attach_effect_to_actor called with:")
	print("🎬 DEBUG: - actor: ", actor.name if actor.name else "unnamed")
	print("🎬 DEBUG: - actor class: ", actor.get_class())
	print("🎬 DEBUG: - actor parent: ", actor.get_parent().name if actor.get_parent() else "no parent")
	print("🎬 DEBUG: - effect: ", effect.name if effect.name else "unnamed")
	print("🎬 DEBUG: - effect class: ", effect.get_class())
	print("🎬 DEBUG: - effect parent: ", effect.get_parent().name if effect.get_parent() else "no parent")
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		return
	
	# Attach directly to the actor - no parent searching
	var target_node = actor
	
	# Safety check: ensure target node is valid
	if not target_node or not is_instance_valid(target_node):
		print("⚠️ Cannot attach effect - invalid target node")
		return
	
	print("🎬 DEBUG: About to attach effect to target_node: ", target_node.name if target_node.name else "unnamed")
	print("🎬 DEBUG: target_node class: ", target_node.get_class())
	print("🎬 DEBUG: target_node global position: ", target_node.global_position)
	
	# Position the effect above the actor
	effect.position = Vector3(0, 0.8, 0)  # 0.8 units above
	target_node.add_child(effect)
	
	print("🎬 DEBUG: Effect attached! Effect global position: ", effect.global_position)
	print("🎬 Attached animation effect to ", _get_actor_name(target_node), " at position: ", effect.global_position)
	
	# Make the effect much more visible by starting with full opacity on the label
	var label_3d = effect.get_child(0)  # Get the Label3D child
	if label_3d and label_3d is Label3D:
		label_3d.modulate.a = 1.0
	
	# Animate the effect with better timing and positioning
	var tween = effect.create_tween()
	# Start with a small scale and grow slightly, then float up and fade out
	tween.tween_property(effect, "scale", Vector3(0.8, 0.8, 0.8), 0.3)  # Grow to 0.8x size (much smaller)
	tween.parallel().tween_property(effect, "position:y", effect.position.y + 0.5, 1.5)  # Float up only 0.5 units over 1.5 seconds
	
	# Fade out the text label
	if label_3d and label_3d is Label3D:
		tween.parallel().tween_property(label_3d, "modulate:a", 0.0, 1.5)  # Fade out over 1.5 seconds
	
	tween.tween_callback(effect.queue_free)
	
	print("🎬 Started effect animation for ", _get_actor_name(target_node))

func _finish_animation(actor: Node, animation_type: ANIMATION_TYPE) -> void:
	"""Finish an animation"""
	if not actor or not is_instance_valid(actor):
		print("🎬 Animation finished for invalid actor")
		return
	
	var actor_name = "Unknown"
	if actor.has_method("enemy_name"):
		actor_name = actor.enemy_name()
	elif actor.name:
		actor_name = actor.name
	else:
		actor_name = str(actor)
	
	print("🎬 Finished ", _get_animation_name(animation_type), " animation for ", actor_name)
	
	# Remove from active animations
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		print("⚠️ Cannot remove animation - invalid actor instance ID")
		return
	
	if active_animations.has(actor_id):
		active_animations.erase(actor_id)
	
	# Emit animation finished signal
	print("🎬 About to emit animation_finished signal for ", actor_name)
	animation_finished.emit(animation_type, actor)
	print("🎬 Animation finished signal emitted for ", actor_name)

func is_animation_playing(actor: Node) -> bool:
	"""Check if an actor has an animation playing"""
	if not actor or not is_instance_valid(actor):
		return false
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		return false
	
	return active_animations.has(actor_id)

func stop_actor_animations(actor: Node) -> void:
	"""Stop all animations for a specific actor"""
	if not actor or not is_instance_valid(actor):
		return
	
	var actor_id = actor.get_instance_id()
	if actor_id == 0:  # Invalid instance ID
		return
	
	if active_animations.has(actor_id):
		var timer = active_animations[actor_id]
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		active_animations.erase(actor_id)

func _get_animation_name(animation_type: ANIMATION_TYPE) -> String:
	"""Get the display name for an animation type"""
	match animation_type:
		ANIMATION_TYPE.FIRE_MAGIC:
			return "Fire Magic"
		ANIMATION_TYPE.FROST_MAGIC:
			return "Frost Magic"
		ANIMATION_TYPE.LIGHTNING_MAGIC:
			return "Lightning Magic"
		ANIMATION_TYPE.ICE_MAGIC:
			return "Ice Magic"
		ANIMATION_TYPE.HOLY_MAGIC:
			return "Holy Magic"
		ANIMATION_TYPE.PHYSICAL_ATTACK:
			return "Physical Attack"
		ANIMATION_TYPE.THROW_ATTACK:
			return "Throw Attack"
		_:
			return "Unknown Animation"

func _get_actor_name(actor: Node) -> String:
	"""Get a readable name for an actor"""
	if actor.has_method("enemy_name"):
		return actor.enemy_name()
	elif actor.has_method("get_name"):
		return actor.get_name()
	elif actor.name:
		return actor.name
	else:
		return str(actor)

func test_animation_system() -> void:
	"""Test function to verify the animation system is working"""
	print("🎬 Testing animation system...")
	print("🎬 Active animations count: ", active_animations.size())
	print("🎬 Is inside scene tree: ", is_inside_tree())
	print("🎬 Animation durations: ", animation_durations)

func play_hitflash(target: Node) -> void:
	"""Play a hitflash effect on the target to show they were damaged"""
	if not target or not is_instance_valid(target):
		return
	
	# Create a simple "HIT!" text effect
	var hitflash_effect = _create_placeholder_effect("💥 HIT!", Color.WHITE)
	
	# Position the effect above the target
	hitflash_effect.position = Vector3(0, 0.8, 0)
	target.add_child(hitflash_effect)
	
	print("💥 Added hitflash effect to target at position: ", hitflash_effect.global_position)
	
	# Animate the hitflash: appear, stay visible briefly, then fade out
	var tween = hitflash_effect.create_tween()
	
	# Make it appear with a small scale and grow
	tween.tween_property(hitflash_effect, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
	
	# Fade out and shrink after a brief pause (using a longer tween duration to simulate delay)
	tween.parallel().tween_property(hitflash_effect, "scale", Vector3(0.8, 0.8, 0.8), 0.5)
	tween.parallel().tween_property(hitflash_effect.get_child(0), "modulate:a", 0.0, 0.5)
	
	# Remove the effect
	tween.tween_callback(hitflash_effect.queue_free)

func _get_target_for_actor(actor: Node) -> Node:
	"""Get the target for an actor's attack"""
	if not actor or not is_instance_valid(actor):
		return null
	
	# Try to find the combat manager to get the current enemy
	var combat_manager = _find_combat_manager()
	if combat_manager and combat_manager.has_method("get_current_enemy"):
		var current_enemy = combat_manager.get_current_enemy()
		if current_enemy and is_instance_valid(current_enemy):
			return current_enemy
	
	# Fallback: look for enemies in the scene
	var enemies = get_tree().get_nodes_in_group("Enemy")
	if enemies.size() > 0:
		return enemies[0]
	
	return null

func _create_moving_attack_effect(actor: Node, text: String, attack_type: String, target: Node) -> void:
	"""Create a moving attack effect that flies from actor to target"""
	if not actor or not target or not is_instance_valid(actor) or not is_instance_valid(target):
		return
	
	print("🎬 Creating moving attack effect from ", _get_actor_name(actor), " to ", _get_actor_name(target))
	
	# Get the color based on attack type
	var color = DamageTypes.get_damage_color_from_string(attack_type)
	
	# Create the effect
	var effect = _create_placeholder_effect(text, color)
	
	# Ensure the text starts with full opacity
	var label_3d = effect.get_child(0)
	if label_3d and label_3d is Label3D:
		label_3d.modulate.a = 1.0
	
	# Position the effect at the actor (above them)
	effect.position = Vector3(0, 0.8, 0)
	actor.add_child(effect)
	
	print("🎬 Moving attack effect created at actor position: ", effect.global_position)
	
	# Animate the effect flying to the target
	var tween = effect.create_tween()
	
	# Calculate the direction vector from actor to target
	var start_pos = actor.global_position + Vector3(0, 0.8, 0)
	var end_pos = target.global_position + Vector3(0, 0.8, 0)
	var direction_vector = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	
	# Move the effect in the direction of the target over 1.0 seconds
	# Use a curved path that goes slightly up and then down
	var mid_point = start_pos + direction_vector * (distance * 0.5) + Vector3(0, 1.0, 0)
	
	# Create a curved path: start -> mid_point -> end
	tween.tween_property(effect, "global_position", mid_point, 0.5)
	tween.tween_property(effect, "global_position", end_pos, 0.5)
	
	# When the effect reaches the target, show hitflash, trigger damage, and remove the attack effect
	tween.tween_callback(func():
		print("🎬 Attack effect reached target, showing hitflash and triggering damage")
		# Show hitflash on the target
		play_hitflash(target)
		# Remove the attack effect
		effect.queue_free()
		
		# Get the stored damage info and emit the damage signal immediately
		if actor.has_meta("pending_damage"):
			var damage_info = actor.get_meta("pending_damage")
			var damage = damage_info.get("damage", 0)
			var damage_type = damage_info.get("damage_type", "")
			var damage_target = damage_info.get("target", target)
			var animation_type = damage_info.get("animation_type", ANIMATION_TYPE.PHYSICAL_ATTACK)
			
			print("🎬 Emitting damage signal immediately for moving attack effect")
			animation_damage_ready.emit(animation_type, actor, damage_target, damage, damage_type)
			
			# Clean up the stored damage info
			actor.remove_meta("pending_damage")
			
			# Finish the animation with the correct animation type
			_finish_animation(actor, animation_type)
		elif actor.has_meta("pending_spell_damage"):
			# Handle spell damage (this will be processed by the combat manager)
			var spell_info = actor.get_meta("pending_spell_damage")
			var damage = spell_info.get("elemental_damage", 0) + spell_info.get("spell_damage", 0)
			var damage_type = spell_info.get("elemental_type", "physical")
			var spell_id = spell_info.get("spell_id", "unknown")
			
			print("🎬 Emitting damage signal immediately for moving spell effect: ", spell_id)
			# Use the animation type from the stored pending damage if available
			var animation_type = spell_info.get("animation_type", ANIMATION_TYPE.FIRE_MAGIC)
			animation_damage_ready.emit(animation_type, actor, target, damage, damage_type)
			
			# Clean up the stored spell data
			actor.remove_meta("pending_spell_damage")
			
			# Finish the animation with the correct animation type
			_finish_animation(actor, animation_type)
		else:
			print("⚠️ No pending damage info found for moving attack effect")
	)
	
	print("🎬 Started moving attack effect animation")

func _will_use_moving_effect(actor: Node, _animation_type: ANIMATION_TYPE) -> bool:
	"""Check if this animation will use a moving attack effect"""
	# Check if there's a target available for this actor
	var target = _get_target_for_actor(actor)
	return target != null

func _find_combat_manager() -> Node:
	"""Find the combat manager in the scene"""
	# Try multiple methods to find the combat manager
	var combat_manager = null
	
	# Method 1: Look for nodes in the CombatManager group
	var managers = get_tree().get_nodes_in_group("CombatManager")
	if managers.size() > 0:
		combat_manager = managers[0]
		print("🎬 Found combat manager through group lookup: ", combat_manager)
		return combat_manager
	
	# Method 2: Look for a node named CombatManager
	var scene = get_tree().current_scene
	if scene:
		combat_manager = scene.get_node_or_null("CombatManager")
		if combat_manager:
			print("🎬 Found combat manager through scene lookup: ", combat_manager)
			return combat_manager
	
	# Method 3: Look for a node with the CombatManager class
	var all_nodes = get_tree().get_nodes_in_group("")
	for node in all_nodes:
		if node.get_class() == "CombatManager":
			combat_manager = node
			print("🎬 Found combat manager through class lookup: ", combat_manager)
			return combat_manager
	
	print("🎬 Could not find combat manager")
	return null
