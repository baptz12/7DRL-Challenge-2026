extends CharacterBody3D

const SPEED = 12.0
const JUMP_VELOCITY = 4.5
const SENSIVITY = 0.003

const BOB_FREQ = 2.5  # La vitesse des pas (plus c'est haut, plus le perso semble faire de petits pas rapides)
const BOB_AMP = 0.15  # La force du balancement (plus c'est haut, plus ça secoue)
var t_bob = 0.0

@onready var camera_mount: Node3D = $CameraMount
@onready var visuals: Node3D = $Visuals
@onready var animation_player: AnimationPlayer = $"Visuals/Root Scene/AnimationPlayer"
@onready var camera_3d: Camera3D = $CameraMount/Camera3D
@onready var portrait_anim: AnimationPlayer = get_node_or_null("HUD/MarginContainer/Ancor/SubViewportContainer/PortraitModel/Root Scene/AnimationPlayer")
@onready var weapon_anim: AnimationPlayer = get_node_or_null("Weapon/WeaponAnim")
@onready var hitbox: Area3D = get_node_or_null("Weapon/Hitbox")

var mouse_captured = false
@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5
@export var turn_speed: float = 10.0
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.15 # Très court pour que ça soit "sec" et nerveux
@export var dash_cooldown: float = 1.0

var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var normal_fov: float = 90.0

func _ready():
	capture_mouse()
	
	if camera_3d:
		normal_fov = camera_3d.fov 
	
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _unhandled_input(event: InputEvent):
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSIVITY)
		
		# 2. On tourne UNIQUEMENT la caméra de haut en bas
		camera_mount.rotate_x(-event.relative.y * SENSIVITY)
		
		# On bloque la tête pour ne pas faire un salto arrière avec la caméra
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_captured = true
		else :
			attack()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if dash_time_left > 0:
		dash_time_left -= delta
		if dash_time_left <= 0:
			is_dashing = false # Fin du dash
	if dash_cooldown_left > 0:
		dash_cooldown_left -= delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	

	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0 and not is_dashing:
		is_dashing = true
		dash_time_left = dash_duration
		dash_cooldown_left = dash_cooldown
		
		# On dash dans la direction où on appuie. Si on n'appuie sur rien, on dash tout droit !
		if direction != Vector3.ZERO:
			dash_direction = direction
		else:
			dash_direction = -transform.basis.z
			
	if is_dashing:
		# Vitesse MAX forcée
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		
		camera_3d.fov = lerp(camera_3d.fov, normal_fov + 30.0, delta * 20.0)
			
		var tilt_amount = -15.0 * input_dir.x
		camera_mount.rotation.z = lerp(camera_mount.rotation.z, deg_to_rad(tilt_amount), delta * 15.0)
	else:
		if direction:
			animation_player.play("CharacterArmature|Walk")
			#if portrait_anim:
				#portrait_anim.play("CharacterArmature|Walk")
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			if is_on_floor():
				t_bob += delta * velocity.length() * float(is_on_floor())
				var bob_y = sin(t_bob * BOB_FREQ) * BOB_AMP
				var bob_x = cos(t_bob * BOB_FREQ / 2.0) * BOB_AMP
				camera_3d.transform.origin = Vector3(bob_x, bob_y, 0)
		else:
			animation_player.play("CharacterArmature|Idle")
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
			camera_3d.transform.origin = camera_3d.transform.origin.lerp(Vector3.ZERO, delta * 10.0)
			
		var dynamic_fov = normal_fov + (velocity.length() * 0.5)
		camera_3d.fov = lerp(camera_3d.fov, dynamic_fov, delta * 10.0)
		camera_mount.rotation.z = lerp(camera_mount.rotation.z, 0.0, delta * 10.0)

	if portrait_anim:
		portrait_anim.play("CharacterArmature|Idle")

	move_and_slide()


func _on_hitbox_body_entered(body: Node3D) -> void:
	# C'est ici qu'on fera les dégâts plus tard !
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(10)
	
func attack():
	# S'il a une arme et qu'elle n'est pas DÉJÀ en train d'attaquer
	if weapon_anim and not weapon_anim.is_playing():
		weapon_anim.play("attack")
	
func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
