extends Sprite3D

var camera = null
var frame_cell_size = Vector2(64, 64)
var frame_counter = 0
var walking_animation_frames = 4  # Assuming each angle of walking animation has 4 frames
var frame_time = 0.0 
var animation_speed = 2.0 
# Define the row for each angle (assuming the top row is 0 and sprite sheet has 5 rows)
var angle_to_row = {
	"front": 0,
	"front_left": 1,
	"left": 2,
	"back_left": 3,
	"back": 4
}

func _ready():
	pass  # Initial setup

func set_camera(c):
	camera = c

func _process(delta):
	if camera == null:
		print("Camera not set")
		return
	
	frame_time += delta
	
	if frame_time >= 1.0 / animation_speed:
		frame_counter += 1
		frame_time -= 1.0 / animation_speed  # Subtract the frame duration to maintain any extra time accumulated
		
	# If the frame counter exceeds the number of frames, reset it
	if frame_counter >= walking_animation_frames:
		frame_counter = 0

	var player_forward = -camera.global_transform.basis.z
	var sprite_forward = global_transform.basis.z
	var sprite_left = global_transform.basis.x

	var left_dot = sprite_left.dot(player_forward)
	var forward_dot = sprite_forward.dot(player_forward)

	var angle = "front"  # Default angle
	var should_flip_h = false  # This will be used to determine if we need to flip the sprite

	# Determine the angle based on dot products
	if forward_dot < -0.85:
		angle = "front"
	elif forward_dot > 0.85:
		angle = "back"
	else:
		should_flip_h = left_dot > 0  # Flip if character is facing right
		if abs(forward_dot) < 0.3:
			angle = "left"
		elif forward_dot < 0.0:
			angle = "front_left"
		else:
			angle = "back_left"

	var row = angle_to_row[angle]
	var local_frame_coords = Vector2(frame_counter, row)
	if should_flip_h != flip_h:
		flip_h = should_flip_h  # Flip the sprite horizontally if needed

	set_frame_coords(local_frame_coords)  # Set the frame using frame coordinates
	local_frame_coords.x = 1 if left_dot > 0 else 0
