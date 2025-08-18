extends Node3D
class_name TargetingRing

# Visual ring that appears under the currently targeted enemy
@export var ring_color: Color = Color(1.0, 0.0, 0.0, 1.0)  # Bright red for visibility
@export var ring_size: float = 2.0  # Bigger diameter for visibility
@export var ring_height: float = 0.2  # Thicker ring for visibility
@export var pulse_speed: float = 1.0  # Faster pulse for visibility
@export var pulse_intensity: float = 0.8  # More intense pulse for visibility

var ring_mesh: MeshInstance3D
var ring_material: StandardMaterial3D
var pulse_tween: Tween
var current_target: Node3D = null

func _ready():
	print("🎯 DEBUG: TargetingRing _ready() called")
	_create_ring_mesh()
	_create_ring_material()
	_apply_material()
	_start_pulse_animation()
	
	# Start hidden
	hide()
	print("🎯 DEBUG: TargetingRing initialization complete")
	print("🎯 DEBUG: Ring mesh created: ", ring_mesh != null)
	print("🎯 DEBUG: Ring material created: ", ring_material != null)
	print("🎯 DEBUG: Ring mesh visible: ", ring_mesh.visible if ring_mesh else "No mesh")

func _create_ring_mesh():
	"""Create a ring mesh using a torus"""
	# Create a torus mesh for the ring
	var torus_mesh = TorusMesh.new()
	torus_mesh.outer_radius = ring_size / 2.0
	torus_mesh.inner_radius = ring_size / 2.0 - ring_height
	torus_mesh.rings = 16
	torus_mesh.ring_segments = 16
	
	# Create mesh instance
	ring_mesh = MeshInstance3D.new()
	ring_mesh.mesh = torus_mesh
	ring_mesh.name = "TargetingRingMesh"
	
	# Position the ring mesh itself at ground level
	ring_mesh.position.y = -0.5  # Move the mesh down so the ring appears at ground level
	
	add_child(ring_mesh)

func _create_ring_material():
	"""Create the material for the targeting ring"""
	ring_material = StandardMaterial3D.new()
	ring_material.albedo_color = ring_color
	ring_material.emission_enabled = true
	ring_material.emission = ring_color * 1.0  # Brighter emission
	ring_material.emission_energy_multiplier = 2.0  # Much brighter
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # No transparency
	ring_material.flags_transparent = false
	ring_material.flags_unshaded = true  # Make it glow without lighting
	ring_material.flags_disable_ambient_light = true

func _apply_material():
	"""Apply the material to the ring mesh"""
	if ring_mesh:
		ring_mesh.material_override = ring_material

func _start_pulse_animation():
	"""Start the pulsing animation for the ring"""
	pulse_tween = create_tween()
	pulse_tween.set_loops(0)  # Loop forever (0 = infinite)
	
	# Pulse the emission intensity
	pulse_tween.tween_property(ring_material, "emission_energy_multiplier", 
		1.0 + pulse_intensity, pulse_speed / 2.0)
	pulse_tween.tween_property(ring_material, "emission_energy_multiplier", 
		1.0, pulse_speed / 2.0)

func set_target(enemy: Node3D):
	"""Set the targeting ring to follow a specific enemy - works with any enemy type"""
	print("🎯 DEBUG: set_target called with enemy: ", enemy)
	
	if not enemy:
		print("⚠️ Warning: Cannot set target - enemy is null")
		hide()
		return
	
	# Validate that this is a valid 3D node
	if not enemy is Node3D:
		print("⚠️ Warning: Cannot set target - enemy is not a Node3D")
		hide()
		return
	
	# Check if enemy has the required properties for positioning
	if not enemy.has_method("global_position") and not "global_position" in enemy:
		print("⚠️ Warning: Enemy missing global_position property")
		hide()
		return
	
	print("🎯 DEBUG: Enemy validation passed, setting target")
	current_target = enemy
	show()
	
	# Position the ring under the enemy at ground level
	# Only use enemy's X and Z position, force Y to be at ground level
	global_position.x = enemy.global_position.x
	global_position.z = enemy.global_position.z
	global_position.y = -0.5  # Much lower - at ground level, never at enemy height
	
	print("🎯 DEBUG: Ring positioned at: ", global_position)
	print("🎯 DEBUG: Ring visible: ", visible)
	print("🎯 DEBUG: Ring mesh visible: ", ring_mesh.visible if ring_mesh else "No mesh")
	print("🎯 Targeting ring set to enemy at position: ", global_position)

func clear_target():
	"""Clear the current target and hide the ring"""
	current_target = null
	hide()
	print("🎯 Targeting ring cleared")

func update_position():
	"""Update the ring position to follow the current target"""
	if current_target and current_target is Node3D:
		global_position.x = current_target.global_position.x
		global_position.z = current_target.global_position.z
		global_position.y = -0.5  # Much lower - at ground level

func _process(_delta):
	"""Update ring position every frame to follow the target - works with any enemy type"""
	if current_target and current_target is Node3D:
		# Safety check: ensure target is still valid
		if not is_instance_valid(current_target):
			print("⚠️ Warning: Target is no longer valid, clearing target")
			clear_target()
			return
		
		# Check if target still has required properties
		if not current_target.has_method("global_position") and not "global_position" in current_target:
			print("⚠️ Warning: Target missing global_position property, clearing target")
			clear_target()
			return
		
		# Only use the enemy's X and Z position, force Y to always be at ground level
		global_position.x = current_target.global_position.x
		global_position.z = current_target.global_position.z
		global_position.y = -0.5  # Much lower - at ground level, never at enemy height

func set_ring_color(new_color: Color):
	"""Change the ring color"""
	ring_color = new_color
	if ring_material:
		ring_material.albedo_color = ring_color
		ring_material.emission = ring_color * 0.5

func set_ring_size(new_size: float):
	"""Change the ring size"""
	ring_size = new_size
	if ring_mesh and ring_mesh.mesh is TorusMesh:
		var torus = ring_mesh.mesh as TorusMesh
		torus.outer_radius = ring_size / 2.0
		torus.inner_radius = ring_size / 2.0 - ring_height

func auto_adjust_ring_size_for_enemy(enemy: Node3D):
	"""Automatically adjust ring size based on enemy type and size - future-proof for any enemy"""
	if not enemy or not enemy is Node3D:
		return
	
	# Try to get enemy size information from various possible sources
	var enemy_size = 1.5  # Default size
	
	# Method 1: Check if enemy has a size property
	if enemy.has_method("get_size"):
		enemy_size = enemy.get_size()
	elif enemy.has_method("size"):
		enemy_size = enemy.size()
	
	# Method 2: Check if enemy has a scale property
	elif enemy.has_method("get_scale"):
		var enemy_scale = enemy.get_scale()
		enemy_size = max(enemy_scale.x, enemy_scale.z) * 1.5  # Use largest scale dimension
	elif enemy.has_method("scale"):
		var enemy_scale = enemy.scale
		enemy_size = max(enemy_scale.x, enemy_scale.z) * 1.5
	
	# Method 3: Check if enemy has a collision shape we can measure
	elif enemy.has_child("CollisionShape3D"):
		var collision = enemy.get_node("CollisionShape3D")
		if collision and collision.shape:
			var shape = collision.shape
			if shape.has_method("get_radius"):
				enemy_size = shape.get_radius() * 2.0
			elif shape.has_method("get_size"):
				var shape_size = shape.get_size()
				enemy_size = max(shape_size.x, shape_size.z)
	
	# Method 4: Check if enemy has a mesh we can measure
	elif enemy.has_child("MeshInstance3D"):
		var mesh_instance = enemy.get_node("MeshInstance3D")
		if mesh_instance and mesh_instance.mesh:
			var mesh = mesh_instance.mesh
			if mesh.has_method("get_aabb"):
				var aabb = mesh.get_aabb()
				enemy_size = max(aabb.size.x, aabb.size.z)
	
	# Apply the calculated size with some padding
	var adjusted_size = enemy_size * 1.2  # 20% padding
	set_ring_size(adjusted_size)
	
	print("🎯 Auto-adjusted ring size to ", adjusted_size, " for enemy type: ", enemy.name)

func auto_adjust_ring_color_for_enemy(enemy: Node3D):
	"""Automatically adjust ring color based on enemy type - future-proof for any enemy"""
	if not enemy or not enemy is Node3D:
		return
	
	# Default to golden color
	var new_color = Color(1.0, 0.8, 0.0, 0.8)
	
	# Try to get enemy type information from various possible sources
	var enemy_type = ""
	
	# Method 1: Check if enemy has an enemy_type property
	if enemy.has_method("get_enemy_type"):
		enemy_type = enemy.get_enemy_type()
	elif enemy.has_method("enemy_type"):
		enemy_type = enemy.enemy_type()
	
	# Method 2: Check if enemy has a type property
	elif enemy.has_method("get_type"):
		enemy_type = enemy.get_type()
	elif enemy.has_method("type"):
		enemy_type = enemy.type()
	
	# Method 3: Check if enemy has a category property
	elif enemy.has_method("get_category"):
		enemy_type = enemy.get_category()
	elif enemy.has_method("category"):
		enemy_type = enemy.category()
	
	# Method 4: Check enemy name for type hints
	elif enemy.name:
		var enemy_name = enemy.name.to_lower()
		if "fire" in enemy_name or "flame" in enemy_name or "burn" in enemy_name:
			enemy_type = "fire"
		elif "ice" in enemy_name or "frost" in enemy_name or "cold" in enemy_name:
			enemy_type = "ice"
		elif "lightning" in enemy_name or "thunder" in enemy_name or "electric" in enemy_name:
			enemy_type = "lightning"
		elif "undead" in enemy_name or "skeleton" in enemy_name or "zombie" in enemy_name:
			enemy_type = "undead"
		elif "demon" in enemy_name or "devil" in enemy_name or "infernal" in enemy_name:
			enemy_type = "demonic"
		elif "dragon" in enemy_name or "wyrm" in enemy_name:
			enemy_type = "dragon"
	
	# Apply color based on enemy type
	match enemy_type.to_lower():
		"fire", "flame", "burn":
			new_color = Color(1.0, 0.3, 0.0, 0.8)  # Red-orange for fire
		"ice", "frost", "cold":
			new_color = Color(0.5, 0.8, 1.0, 0.8)  # Light blue for ice
		"lightning", "thunder", "electric":
			new_color = Color(1.0, 1.0, 0.0, 0.8)  # Bright yellow for lightning
		"undead", "skeleton", "zombie":
			new_color = Color(0.5, 0.0, 0.5, 0.8)  # Purple for undead
		"demonic", "demon", "devil", "infernal":
			new_color = Color(0.8, 0.0, 0.0, 0.8)  # Dark red for demons
		"dragon", "wyrm":
			new_color = Color(1.0, 0.0, 0.0, 0.8)  # Bright red for dragons
		_:
			new_color = Color(1.0, 0.8, 0.0, 0.8)  # Default golden
	
	# Apply the new color
	set_ring_color(new_color)
	
	print("🎯 Auto-adjusted ring color to ", new_color, " for enemy type: ", enemy_type)

func auto_adjust_ring_height_for_enemy(enemy: Node3D):
	"""Automatically adjust ring height based on enemy size and ground level - future-proof for any enemy"""
	if not enemy or not enemy is Node3D:
		return
	
	# Default height offset
	var height_offset = 0.05
	
	# Try to determine if enemy is flying or ground-based
	var is_flying = false
	
	# Method 1: Check if enemy has a flying property
	if enemy.has_method("is_flying"):
		is_flying = enemy.is_flying()
	elif enemy.has_method("get_is_flying"):
		is_flying = enemy.get_is_flying()
	
	# Method 2: Check enemy name for flying hints
	elif enemy.name:
		var enemy_name = enemy.name.to_lower()
		if "bird" in enemy_name or "eagle" in enemy_name or "hawk" in enemy_name or "dragon" in enemy_name:
			is_flying = true
	
	# Method 3: Check if enemy has a ground_offset property
	if enemy.has_method("get_ground_offset"):
		height_offset = enemy.get_ground_offset()
	elif enemy.has_method("ground_offset"):
		height_offset = enemy.ground_offset()
	
	# Adjust height based on enemy type
	if is_flying:
		height_offset = 0.0  # Ring appears at enemy's level for flying enemies
	else:
		height_offset = 0.05  # Ring appears slightly above ground for ground enemies
	
	print("🎯 Auto-adjusted ring height to ", height_offset, " for enemy (flying: ", is_flying, ")")
	
	return height_offset
