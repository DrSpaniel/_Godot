extends CharacterBody3D

# Player nodes
@onready var neck: Node3D = $neck
@onready var head: Node3D = $neck/head
@onready var eyes: Node3D = $neck/head/eyes
@onready var standing_collision: CollisionShape3D = $standing_collision
@onready var crouched_collision: CollisionShape3D = $crouched_collision
@onready var crouchjump_collision: CollisionShape3D = $crouchjump_collision
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var camera_3d: Camera3D = $neck/head/eyes/Camera3D
@onready var animation_player: AnimationPlayer = $neck/head/eyes/AnimationPlayer
@onready var interactcast: RayCast3D = $neck/head/eyes/interactcast



# Debug States

var debug_enabled = false

var jump_enabled = true
var slide_enabled = true
var wallrun_enabled = true
var wallkick_enabled = true



# States
var walking := false
var sprinting := false
var crouched := false
var freelook := false
var sliding := false
var was_in_air = false

# Slide vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 15

# Jump vars
var last_velocity = Vector3.ZERO
var horizontal_velocity = Vector2(velocity.x, velocity.z)
@export var jump_velocity = 5
var crouch_counter = 0.0
@export var min_crouch_counter = 8.0
@export var max_crouch_counter = 15.0
var is_charging = false

# Wall system vars - SIMPLIFIED
enum WallState {
	NONE,
	WALLRUNNING
}

var wall_state = WallState.NONE
var wallrun_timer = 0.0
var max_wallrun_time = 3.0
var wallrun_velocity_set = false

# Wallkick vars
@export var wall_kick_strength_horiz = 4  # How far away?
@export var wall_kick_strength_vert = 5 # How high?

# Headbob vars
const headbob_sprint_speed = 22
const headbob_walk_speed = 14
const headbob_crouch_speed = 10
const headbob_sprint_intensity = 0.05
const headbob_walk_intensity = 0.05
const headbob_crouch_intensity = 0.05

var headbob_vector = Vector2.ZERO
var headbob_index = 0
var headbob_intensity = 0

# Speed vars
var current_speed = 5.0
const walking_speed = 5.0
const sprint_speed = 8.0
const crouch_speed = 3.0
var wallrun_speed = 20.0

# Movement vars
var crouch_depth = -0.5
var lerp_speed = 10.0
var air_lerp = 3
var freelook_angle = 8

# Air movement vars
@export var air_control_force = 10.0  # adjust to how responsive air movement is
@export var max_air_speed = 7.5  # Maximum horizontal speed in the air

# Input vars
var direction = Vector3.ZERO
const mouse_sens = 0.25
var mouseinput := true

# Interaction stuff
var lastInteraction



















func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	
	# Feature enablers
	
	if event.is_action_pressed("debug_abilities"):
		debug_enabled = !debug_enabled
		
		if debug_enabled:
			jump_enabled = false
			slide_enabled = false
			wallrun_enabled = false
			wallkick_enabled = false
			print("debug time!")
		else:
			jump_enabled = true
			slide_enabled = true
			wallrun_enabled = true
			wallkick_enabled = true
			print("Bye bye debug!")
	
	
	if event.is_action_pressed("jump_enable") and debug_enabled:
		jump_enabled = true
		print("jump enabled!")
		
	if event.is_action_pressed("slide_enable") and debug_enabled:
		slide_enabled = true
		print("slide enabled!")
		
	if event.is_action_pressed("wallrun_enable") and debug_enabled:
		wallrun_enabled = true
		print("wallrun enabled!")
		
	if event.is_action_pressed("wallkick_enable") and debug_enabled:
		wallkick_enabled = true
		print("wallkick enabled!")
	
	
	
	# Mouse move logic
	if event.is_action_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouseinput = false
		
	if event.is_action_pressed("click"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		mouseinput = true
		
	if mouseinput == true:
		if event is InputEventMouseMotion:
			if freelook:
				neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
				neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-80), deg_to_rad(80))
			else:
				rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:	
	# Handle wall system timers
	#handle_wall_timers(delta)
	
	# Getting movement input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	horizontal_velocity = Vector2(velocity.x, velocity.z)
	
	if Input.is_action_just_pressed("debug"):
		print("-------DEBUG-------")
		print("wall_state:", WallState.keys()[wall_state])
		print("walking:", walking)
		print("sprinting:", sprinting)
		print("velocity.y:", velocity.y)
		print("horiz velocity", horizontal_velocity.length())
	
	if Input.is_action_just_pressed("reset"):
		global_position = Vector3.ZERO
		velocity = Vector3.ZERO
		rotation = Vector3.ZERO
		head.rotation = Vector3.ZERO
		reset_wall_state()
	
	# Handle movement states (crouching, sprinting, etc.)
	handle_movement_states(delta, input_dir)
	
	# Handle freelook
	handle_freelook(delta)
	
	# Handle sliding
	handle_sliding(delta)
	
	# Handle headbob
	handle_headbob(delta, input_dir)
	
	# Handle player movement
	handle_player_movement(delta, input_dir)
	
	# Handle wall system
	handle_wall_system(delta, input_dir)
	
	# Handle gravity
	handle_gravity(delta)
	
	var was_airborne = not is_on_floor()
	
	last_velocity = velocity
	move_and_slide()
	# Check for air-to-ground transition slide
	handle_air_to_slide_transition(was_airborne)
	
	was_in_air = was_airborne
	
	# Handle interactions
	handle_interactions_raycast()
	
	

#func handle_wall_timers(delta: float):


func handle_wall_system(delta: float, _input_dir: Vector2):
	"""Centralized wall system handling"""
	var touching_wall = is_on_wall_only()
	
	if touching_wall and wallrun_enabled and wall_state == WallState.NONE:
		# Start wallrunning
		wall_state = WallState.WALLRUNNING
		wallrun_timer = 0.0
		wallrun_velocity_set = false
		print("Started wallrunning")
	
	elif wall_state == WallState.WALLRUNNING:
		if not touching_wall:
			# Left the wall
			reset_wall_state()
			print("Left wall, ending wallrun")
		else:
			# Continue wallrunning
			wallrun_timer += delta
			if wallrun_timer >= max_wallrun_time:
				reset_wall_state()
				print("Wallrun time expired")
			elif Input.is_action_just_pressed("jump") and wallkick_enabled:
				# Perform wallkick - just apply force and end wallrunning
				perform_wallkick()
				reset_wall_state()  # End wallrunning immediately

func perform_wallkick():
	"""Execute a wallkick - just apply force, no state management"""
	var collision = get_last_slide_collision()
	if collision:
		var wall_normal = collision.get_normal()
		print("WALLKICK! Normal:", wall_normal)
		
		# Apply strong force away from wall
		velocity += wall_normal * wall_kick_strength_horiz
		velocity.y = wall_kick_strength_vert
		#direction = Vector3.ZERO #this just halts
		
func reset_wall_state():
	"""Reset all wall-related state"""
	wall_state = WallState.NONE
	wallrun_timer = 0.0
	wallrun_velocity_set = false

func is_wallrunning() -> bool:
	return wall_state == WallState.WALLRUNNING

func handle_movement_states(delta: float, input_dir: Vector2):
	"""Handle crouching, sprinting, walking states"""
	# Crouching
	if is_on_floor() and jump_enabled and Input.is_action_pressed("crouch") or sliding:
		
		# Do crouch stuff
		
		current_speed = lerp(current_speed, crouch_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouch_depth, delta * lerp_speed)
		standing_collision.disabled = true
		crouched_collision.disabled = false
		
		# If touching floor, charge jump to  be used later
		
		if is_on_floor():
			is_charging = true
			crouch_counter += delta * 10.0
			crouch_counter = clamp(crouch_counter, min_crouch_counter, max_crouch_counter)
		
		# Slide begin logic
		if (horizontal_velocity.length() > 7 and sprinting and input_dir != Vector2.ZERO and slide_enabled and is_on_floor()):
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			freelook = true
			print("slide begin")
			
		walking = false
		sprinting = false
		crouched = true
		
	elif ray_cast_3d.is_colliding():	# If im under something!
		crouch_counter = 0.0
	elif !ray_cast_3d.is_colliding():	# If nothing above me
		# Uncrouching / Standing
		standing_collision.disabled = false
		crouched_collision.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if Input.is_action_just_released("crouch") and jump_enabled and is_on_floor():
			do_jump(crouch_counter)
		elif Input.is_action_pressed("sprint"):
			# Sprinting
			if is_on_floor():
				current_speed = lerp(current_speed, sprint_speed, delta * lerp_speed/4)
				if horizontal_velocity.length() > 7:
					walking = false
					sprinting = true
					crouched = false
		else:
			# Walking
			current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
			walking = true
			sprinting = false
			crouched = true

func handle_freelook(delta: float):
	"""Handle freelook camera behavior"""
	if Input.is_action_pressed("freelook") or sliding:
		freelook = true
		if sliding:
			eyes.rotation.z = lerp(camera_3d.rotation.z, -deg_to_rad(8), delta * lerp_speed)
		else: 
			eyes.rotation.z = deg_to_rad(-neck.rotation.y * freelook_angle)
	else:
		freelook = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * lerp_speed * 2.6)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed * 2.6)

func handle_sliding(delta: float):
	"""Handle sliding mechanics"""
	if sliding:		
		slide_timer -= delta
		if slide_timer <= 0:
			print("slide end via timer")
			sliding = false
			freelook = false
		elif Input.is_action_just_released("crouch"):
			print("slide end via jump release")
			freelook = false
			do_jump(crouch_counter)

func handle_headbob(delta: float, input_dir: Vector2):
	"""Handle camera headbob"""
	if sprinting:
		headbob_intensity = headbob_sprint_intensity
		headbob_index += headbob_sprint_speed * delta
	elif walking:
		headbob_intensity = headbob_walk_intensity
		headbob_index += headbob_walk_speed * delta
	elif crouched:
		headbob_intensity = headbob_crouch_intensity
		headbob_index += headbob_crouch_speed * delta
	
	if is_on_floor() and !sliding and input_dir != Vector2.ZERO:
		headbob_vector.y = sin(headbob_index)
		headbob_vector.x = sin(headbob_index/2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, headbob_vector.y * (headbob_intensity/2), delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x, headbob_vector.x * (headbob_intensity), delta*lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta*lerp_speed)

func handle_player_movement(delta: float, input_dir: Vector2):
	"""Handle player movement with proper air control"""
	
	if is_on_floor():
		# Ground movement - direct velocity control (existing behavior)
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerp_speed)
		
		if sliding:
			direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
			current_speed = (slide_timer + 0.1) * slide_speed
		
		# Apply movement - replace velocity on ground
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
	
	else:
		# Air movement - additive control (preserve existing momentum)
		if input_dir != Vector2.ZERO:
			var input_vector = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			
			
			# Add steering force to existing velocity instead of replacing it
			velocity.x += input_vector.x * air_control_force * delta
			velocity.z += input_vector.z * air_control_force * delta
			
			# Optional: Cap maximum horizontal speed to prevent infinite acceleration
			var horizontal_vel = Vector2(velocity.x, velocity.z)
			
			if horizontal_vel.length() > max_air_speed:
				horizontal_vel = horizontal_vel.normalized() * max_air_speed
				velocity.x = horizontal_vel.x
				velocity.z = horizontal_vel.y

func handle_gravity(delta: float):
	"""Handle gravity and wallrun physics"""
	if not is_on_floor():
		if not is_wallrunning():
			velocity += get_gravity() * delta
		else:
			# Wallrunning physics
			if wallrun_timer < 2.2:
				if not wallrun_velocity_set:
					velocity.y = 0.0  # Stop vertical movement
				wallrun_velocity_set = true
				current_speed = lerp(current_speed, wallrun_speed, delta * lerp_speed)
			else:
				print("beginning descent")
				velocity += get_gravity()/3 * delta

func do_jump(charge):
	"""Execute a jump with charge"""
	print("crouch:", int(charge))
	velocity.y = jump_velocity * charge/10
	sliding = false
	is_charging = false
	animation_player.play("jumping")
	crouch_counter = 0.0
	
func handle_air_to_slide_transition(was_airborne: bool):
	"""Handle sliding when landing from air with speed and crouch held"""
	if was_airborne and slide_enabled and is_on_floor():  # Just landed
		var horizontal_speed = Vector2(velocity.x, velocity.z).length()
		
		# If moving fast enough, holding crouch, and have horizontal momentum
		if horizontal_speed >= sprint_speed/2 and Input.is_action_pressed("crouch"):
			print("=== AIR-TO-SLIDE TRANSITION ===")
			print("Landing speed:", horizontal_speed)

			
			# Convert velocity to local space slide vector (matching coordinate system)
			var world_velocity_normalized = Vector3(velocity.x, 0, velocity.z).normalized()
			var local_velocity = transform.basis.inverse() * world_velocity_normalized
			slide_vector = Vector2(local_velocity.x, local_velocity.z)
			
			# Start sliding
			sliding = true
			slide_timer = slide_timer_max
			
			# Enable freelook for slide
			freelook = true
			
			# Set appropriate collision and states
			standing_collision.disabled = true
			crouched_collision.disabled = false
			crouched = true
			walking = false
			sprinting = false
			
			
			

func handle_interactions_raycast():
	#if interactcast.is_colliding():
		#var collider = interactcast.get_collider()
		#print(collider.name)
		#if collider and collider.name == "InteractBox" and Input.is_action_just_pressed("use"):
			#toggle_interactbox(collider)
			
	if interactcast.is_colliding():
		
		var hit = interactcast.get_collider()
		
		
		print(hit.name)		#print the name of the thing colliding
		print(is_floor(hit))#is it a floor??
		if lastInteraction:
			print("last interactable object:", lastInteraction.name)
		if hit and hit.name == "InteractBox" and Input.is_action_just_pressed("use"):
			lastInteraction = hit
			toggle_interactbox(lastInteraction)
			
		elif lastInteraction and lastInteraction.name == "InteractBox" and is_floor(hit) and Input.is_action_just_pressed("use"):
			print("box should move here!")
			
			move_interactbox_to_floor(interactcast.get_collision_point(), lastInteraction)
			lastInteraction = null
	
func toggle_interactbox(box: Node) -> bool:
	var is_visible = box.visible
	box.visible = !is_visible

	var shape = box.get_node_or_null("CollisionShape3D")
	if shape:
		shape.disabled = is_visible
	if is_visible:
		return true
	else: return false

func is_floor(collider: Object) -> bool:
	# Option 1: use node name
	if collider.name.begins_with("floor"):
		return true
	else: return false

func move_interactbox_to_floor(point: Vector3, box: Node):	
	var new_position = box.global_position
	new_position.x = point.x
	new_position.z = point.z
	# Optionally snap Y to ground height
	box.global_position = new_position
	
	toggle_interactbox(box)  # Make it reappear
