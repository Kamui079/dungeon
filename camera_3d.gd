extends Camera3D

@onready var spring_arm: SpringArm3D = get_parent()  # Assuming parent is SpringArm3D

func _physics_process(delta):
	spring_arm.position = position  # Sync position with camera
	spring_arm.rotation = rotation  # Sync rotation
