extends CharacterBody3D

# Movement
@onready var body = $CollisionShape
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
const BOB_FREQ = 2.0
const BOB_AMP = 0.04
var t_bob = 0.0

# Camera
var sensitivity = 0.05
@onready var camera = $Head/Camera
const MAX_TILT_ANGLE = 0.02

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$Head/head_ray.enabled = true
	
func _input(event):
	# Camera rotation
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation(event)
	
func _handle_camera_rotation(event: InputEvent):
	# Rotate the camera based on the mouse movement
	rotate_y(deg_to_rad(-event.relative.x * sensitivity))
	$Head.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
	
	# Stop the head from rotating to far up or down
	$Head.rotation.x = clamp($Head.rotation.x, deg_to_rad(-80), deg_to_rad(90))
	
func _physics_process(delta):
	process_input()
	process_movement(delta)
	process_animation(delta)
	
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
	
	# Move the player once velocity has been calculated
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	return pos

func is_moving ():
	return direction.length() > 0

func is_head_colliding():
	# Check if the RayCast node is colliding
	return $Head/head_ray.is_colliding()

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
	$Head/Camera.rotation.z = lerp($Head/Camera.rotation.z, tilt, 0.2) 

func process_animation(delta):
	_tilt_camera_based_on_input()
	# var is_actually_moving = is_moving() and is_on_floor()
	var target_head_position = $Head.position.y
	# If crouching, we lerp the head's position downward.
	if crouching:
		target_head_position = 0.4 # Adjust this value to set how low the head should go.
		# Lerp the head's Y position to crouch.
		$Head.position.y = lerp($Head.position.y, target_head_position, 10 * delta)
		body.scale.y = lerp(body.scale.y, 0.50, 10 * delta)
	else:
		# Reset the head's position if not crouching.
		target_head_position = 0.6 # Original Y position of the head.
		$Head.position.y = lerp($Head.position.y, target_head_position, 10 * delta)
		
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
