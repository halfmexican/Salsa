extends CharacterBody3D

# Movement
@onready var body = $collision_shape
const MAX_VELOCITY_AIR = 0.6
const MAX_VELOCITY_GROUND = 6.0
const MAX_ACCELERATION = 10 * MAX_VELOCITY_GROUND
const GRAVITY = 15.34
const STOP_SPEED = 1.8
const JUMP_IMPULSE = sqrt(2 * GRAVITY * 0.85)
const PLAYER_WALKING_MULTIPLIER = 0.666

# Movement
var direction = Vector3()
var friction = 4
var wish_jump
var walking = false
var crouching = false

# Headbob
@export var BOB_FREQ = 2.0
@export var BOB_AMP = 0.04
@export var t_bob = 0.0

# Weapon Sway
var mouse_input : Vector2
@onready var hand = $head/viewmodel/viewmodel_arms/Skeleton3D/BoneAttachment3D
@export var weapon_sway_amount : float = 0.2
@export var weapon_rotation_amount : float = 0.6
@export var invert_weapon_sway : bool = false
# Camera
var sensitivity = 0.05
@onready var camera = $head/player_camera
const MAX_TILT_ANGLE = 0.02

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$head/head_ray.enabled = true
	
func _input(event):
	# Camera rotation
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation(event)
	
func _handle_camera_rotation(event: InputEvent):
	mouse_input = event.relative
	# Rotate the camera based on the mouse movement
	rotate_y(deg_to_rad(-event.relative.x * sensitivity))
	$head.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
	
	# Stop the head from rotating to far up or down
	$head.rotation.x = clamp($head.rotation.x, deg_to_rad(-80), deg_to_rad(90))
	
func _physics_process(delta):
	process_input()
	process_movement(delta)
	process_animation(delta)
	weapon_sway(delta)
	
func process_input():
	direction = Vector3()
	# Movement directions
	if Input.is_action_pressed("forward"):
		direction -= transform.basis.z
	elif Input.is_action_pressed("backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("left"):
		direction -= transform.basis.x
	elif Input.is_action_pressed("right"):
		direction += transform.basis.x
		
	# Jumping
	wish_jump = Input.is_action_just_pressed("jump")
	
	# Walking
	walking = Input.is_action_pressed("walk")
	
	# Crouching
	crouching = Input.is_action_pressed("crouch") or is_head_colliding()
	
func process_movement(delta):
	# Get the normalized input direction so that we don't move faster on diagonals
	var wish_dir = direction.normalized()

	if is_on_floor():
		# If wish_jump is true then we won't apply any friction and allow the 
		# player to jump instantly, this gives us a single frame where we can 
		# perfectly bunny hop
		if wish_jump:
			velocity.y = JUMP_IMPULSE
			# Update velocity as if we are in the air
			velocity = update_velocity_air(wish_dir, delta)
			wish_jump = false
		else:
			if walking:
				velocity.x *= PLAYER_WALKING_MULTIPLIER
				velocity.z *= PLAYER_WALKING_MULTIPLIER
			
			if crouching:
				velocity.x *= PLAYER_WALKING_MULTIPLIER
				velocity.z *= PLAYER_WALKING_MULTIPLIER
				
			velocity = update_velocity_ground(wish_dir, delta)
	else:
		# Only apply gravity while in the air
		velocity.y -= GRAVITY * delta
		velocity = update_velocity_air(wish_dir, delta)
		
	# Headbob
	t_bob += delta * velocity.length()
	camera.transform.origin = _headbob(t_bob) * float(is_on_floor())
	
	# Move the player once velocity has been calculatedif invert_weapon_sway else 1
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	return pos



func weapon_sway(delta):
	const ORIGINAL_ROT_X = deg_to_rad(70.3)
	#const ORIGINAL_ROT_Y = deg_to_rad(-33.5)
	const ORIGINAL_ROT_Z = deg_to_rad(-31.6)
	# Define maximum rotation angles (example values)
	const MAX_SWAY_ROT_Z = deg_to_rad(10)  # Max sway for X-axis in radians
	const MAX_SWAY_ROT_X = deg_to_rad(10)  # Max sway for Y-axis in radians

	# Interpolate mouse input towards zwero for smooth stopping
	mouse_input = lerp(mouse_input, Vector2.ZERO, delta)
	# Calculate target rotation based on mouse input
	var target_rot_x = clamp(ORIGINAL_ROT_X + mouse_input.y * weapon_rotation_amount, ORIGINAL_ROT_X - MAX_SWAY_ROT_Z, ORIGINAL_ROT_X + MAX_SWAY_ROT_X)
	var target_rot_z = clamp(ORIGINAL_ROT_Z + mouse_input.x * weapon_rotation_amount, ORIGINAL_ROT_Z - MAX_SWAY_ROT_X, ORIGINAL_ROT_Z+ MAX_SWAY_ROT_Z)
	# Lerp current rotation towards target rotation
	hand.rotation.x = lerp(hand.rotation.x, target_rot_x, 10 * delta)
	hand.rotation.z = lerp(hand.rotation.z, target_rot_z, 10 * delta)
	# Assuming Z rotation should also return to its original position
	hand.rotation.x = lerp(hand.rotation.x, ORIGINAL_ROT_X, 10 * delta)
	hand.rotation.z = lerp(hand.rotation.z, ORIGINAL_ROT_Z, 10 * delta)


	
func is_moving ():
	return direction.length() > 0

func is_head_colliding():
	# Check if the RayCast node is colliding
	return $head/head_ray.is_colliding()

func _tilt_camera_based_on_input():
	var tilt = 0.0
	# Check for left and right movement inputs
	if Input.is_action_pressed("left"):
		tilt = MAX_TILT_ANGLE
	elif Input.is_action_pressed("right"):
		tilt = -MAX_TILT_ANGLE
	else : 
		tilt = 0.0

	# Apply the tilt to the camera's rotation
	$head/player_camera.rotation.z = lerp($head/player_camera.rotation.z, tilt, 0.2) 

func process_animation(delta):
	_tilt_camera_based_on_input()
	# var is_actually_moving = is_moving() and is_on_floor()
	var target_head_position = $head.position.y
	# If crouching, we lerp the head's position downward.
	if crouching:
		target_head_position = 0.4 # Adjust this value to set how low the head should go.
		# Lerp the head's Y position to crouch.
		$head.position.y = lerp($head.position.y, target_head_position, 10 * delta)
		body.scale.y = lerp(body.scale.y, 0.50, 10 * delta)
	else:
		# Reset the head's position if not crouching.
		target_head_position = 0.6 # Original Y position of the head.
		$head.position.y = lerp($head.position.y, target_head_position, 10 * delta)
		
		# Reset the body scale if not crouching.
		body.scale.y = lerp(body.scale.y, 1.0, 10 * delta)
	

func accelerate(wish_dir: Vector3, max_speed: float, delta):
	# Get our current speed as a projection of velocity onto the wish_dir
	var current_speed = velocity.dot(wish_dir)
	# How much we accelerate is the difference between the max speed and the current speed
	# clamped to be between 0 and MAX_ACCELERATION which is intended to stop you from going too fast
	var add_speed = clamp(max_speed - current_speed, 0, MAX_ACCELERATION * delta)
	
	return velocity + add_speed * wish_dir
	
func update_velocity_ground(wish_dir: Vector3, delta):
	# Apply friction when on the ground and then accelerate
	var speed = velocity.length()
	
	if speed != 0:
		var control = max(STOP_SPEED, speed)
		var drop = control * friction * delta
		
		# Scale the velocity based on friction
		velocity *= max(speed - drop, 0) / speed
	
	return accelerate(wish_dir, MAX_VELOCITY_GROUND, delta)
	
func update_velocity_air(wish_dir: Vector3, delta):
	# Do not apply any friction
	return accelerate(wish_dir, MAX_VELOCITY_AIR, delta)
