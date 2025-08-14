extends SpringArm3D

# Reference to the Camera3D node
var camera : Camera3D

# Called when the node enters the scene tree for the first time
func _ready():
	# Get the Camera3D node as a child of this SpringArm3D node
	camera = $Camera3D  # This assumes Camera3D is a child of SpringArm3D
