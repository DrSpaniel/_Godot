extends CharacterBody3D

# Player nodes

@onready var neck: Node3D = $neck
@onready var head: Node3D = $neck/head
@onready var eyes: Node3D = $neck/head/eyes
@onready var standing_collision: CollisionShape3D = $standing_collision
@onready var crouched_collision: CollisionShape3D = $crouched_collision
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var camera_3d: Camera3D = $neck/head/eyes/Camera3D
@onready var animation_player: AnimationPlayer = $neck/head/eyes/AnimationPlayer



# States

var walking := false
var sprinting := false
var crouched := false
var freelook := false
var sliding := false

# Slide vars

var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 15

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





#Speed vars

var current_speed = 5.0

const walking_speed = 5.0
const sprint_speed = 8.0
const crouch_speed = 3.0

# Movement vars

var crouch_depth = -0.5
const jump_velocity = 4.5
var lerp_speed = 10.0
var air_lerp = 3
var freelook_angle = 8

var last_velocity = Vector3.ZERO


# Input vars

var direction = Vector3.ZERO
const mouse_sens = 0.25



#used to track mouse. maybe add a pause menu!
var mouseinput := true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	
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
	#getting movement input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	
	
	if Input.is_action_just_pressed("debug"):
		print("-------DEBUG-------")
		print("walking:", walking)
		print("sprinting:", sprinting)
		print("crouched:", crouched)
		print("freelooking:", freelook)
		print("sliding:", sliding)
		
		
	#print(crouched_collision.position.y)
		
		
	# Handling movement states
	
	# Crouching
	if Input.is_action_pressed("crouch") or sliding:
		current_speed = lerp(current_speed, crouch_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouch_depth, delta * lerp_speed)
		
		standing_collision.disabled = true
		crouched_collision.disabled = false
		
		#slide begin logic
		
		if sprinting and input_dir != Vector2.ZERO and is_on_floor():
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			freelook = true
			print("slide begin")
			
		
		walking = false
		sprinting = false
		crouched = true
		
	elif !ray_cast_3d.is_colliding():
		# Uncrouching / Standing
		
		standing_collision.disabled = false
		crouched_collision.disabled = true
		
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if Input.is_action_pressed("sprint"):
			# Sprinting
			current_speed = lerp(current_speed, sprint_speed, delta * lerp_speed)
			
			walking = false
			sprinting = true
			crouched = true
			
		else:
			# Walking
			current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
			
			walking = true
			sprinting = false
			crouched = true
			
	
	# Freelook handler
	
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
	
	# Sliding
	
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0 or Input.is_action_just_pressed("jump"):
			sliding = false
			print("slide end")
			freelook = false
	
	# Handle headbob
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
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() :		#disables normal jump when crouch is pressed. idk why im doing this but i wanna see if i can make a crouch jump
		velocity.y = jump_velocity
		sliding = false
		animation_player.play("jumping")
		
	# Handle landing animations
	if is_on_floor():
		if last_velocity.y < 0.0:
			print(last_velocity.y)		#when landing shows how hard we just landed. can be used to determine how the screenshake is.
			if last_velocity.y < -10.0:	#when velocity goes past -10
				print("roll")
				animation_player.play("roll")
			elif last_velocity.y < -7.0:
				print("hard fall")
				animation_player.play("hardlanding")
			elif last_velocity.y < -4.0:
				print("regular fall")
				animation_player.play("softlanding")
			
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	
	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*air_lerp)
	
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	last_velocity = velocity
	
	move_and_slide()
