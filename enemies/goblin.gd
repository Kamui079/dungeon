extends CharacterBody3D

class_name Goblin

@export var move_speed: float = 3.0
@export var detection_range: float = 5.0

var player: Node = null

# Stats
@onready var stats: PlayerStats = PlayerStats.new()

func _ready():
	add_child(stats)
	# Set goblin stats
	stats.max_health = 30
	stats.health = 30
	stats.max_mana = 20
	stats.mana = 20

func _physics_process(delta):
	# Basic gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	# Find player if not already found
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	
	# Check if player is in detection range
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= detection_range:
		# Move towards player
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		# Stop moving if player is out of range
		velocity.x = 0
		velocity.z = 0
	
	# Apply movement
	move_and_slide()

func take_damage(amount: int):
	stats.take_damage(amount)
	print("Goblin took ", amount, " damage! Health: ", stats.health, "/", stats.max_health)
	
	if stats.health <= 0:
		print("Goblin defeated!")
		queue_free()


