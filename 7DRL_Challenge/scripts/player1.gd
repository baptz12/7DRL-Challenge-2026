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
@onready var laser_pivot: Node3D = get_node_or_null("Weapon/LaserPivot")
@onready var laser_mesh: MeshInstance3D = get_node_or_null("Weapon/LaserPivot/LaserMesh")
@onready var gunshot: AudioStreamPlayer3D = get_node_or_null("Gunshot")
@onready var damage_overlay: ColorRect = get_node_or_null("HUD/DamageOverlay")
@onready var weapon: Node3D = get_node_or_null("Weapon")


var mouse_captured = false
@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5
@export var turn_speed: float = 10.0
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0
@export var shoot_cooldown: float = 0.2
var last_shot_time: float = 0.0

@export var max_hp: int = 10
var hp: int = 10
var invulnerable_time: float = 0.0

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

	if invulnerable_time > 0:
		invulnerable_time -= delta

	move_and_slide()


func _on_hitbox_body_entered(body: Node3D) -> void:
	# C'est ici qu'on fera les dégâts plus tard !
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(10)
	

func shoot_laser():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < shoot_cooldown:
		return 
	last_shot_time = current_time

	# 1. Tir du Raycast
	var space_state = get_world_3d().direct_space_state
	var screen_center = get_viewport().size / 2.0
	var origin = camera_3d.project_ray_origin(screen_center)
	var end = origin + camera_3d.project_ray_normal(screen_center) * 100.0 
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self] 
	var result = space_state.intersect_ray(query)
	var hit_position = end
	
	# 2. Gestion de l'impact
	if result:
		hit_position = result.position
		if result.collider.is_in_group("enemy"):
			if result.collider.has_method("take_damage"):
				result.collider.take_damage(5) 
	
	# 3. Affichage OPTIMISÉ du rayon (Zéro lag)
	if laser_pivot and laser_mesh:
		laser_pivot.visible = true
		
		# Le pivot tourne pour regarder la zone d'impact
		laser_pivot.look_at(hit_position, Vector3.UP)
		
		# On étire le laser en fonction de la distance
		var distance = laser_pivot.global_position.distance_to(hit_position)
		laser_mesh.scale.y = distance
		laser_mesh.position.z = -(distance / 2.0)
		
		# On cache le laser au bout de 0.05 seconde
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(laser_pivot):
			laser_pivot.visible = false

func attack():
	# S'il a une arme et qu'elle n'est pas DÉJÀ en train d'attaquer
	gunshot.play()
	if weapon_anim and not weapon_anim.is_playing():
		weapon_anim.play("attack")
	# Si on a une Arme mais pas de Hitbox (le Fusil)
	elif get_node_or_null("Weapon"):
		shoot_laser()
	#if !weapon_anim.is_playing("attack"):
		#weapon_anim.
	
func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
	
func take_damage(amount: int):
	# Si le joueur vient de se faire toucher, on le protège un court instant
	if invulnerable_time > 0: return 
	
	hp -= amount
	print("PV restants : ", hp)
	
	# On donne 1 seconde d'invulnérabilité
	invulnerable_time = 1.0 
	
	if damage_overlay:
		var tween = create_tween()
		# On fait apparaître le rouge rapidement (0.3 d'opacité)
		tween.tween_property(damage_overlay, "color:a", 0.4, 0.1)
		# On le fait disparaître lentement
		tween.tween_property(damage_overlay, "color:a", 0.0, 0.5)
	
	# Petit effet d'impact sur la caméra pour donner de la force au coup
	if camera_mount:
		camera_mount.rotation.x += deg_to_rad(5.0)
	
	if hp <= 0:
		die()

func die():
	# On réinitialise la difficulté à x1
	var root = get_tree().root
	root.set_meta("difficulty_multiplier", 1)
	
	# On recommence la partie
	get_tree().reload_current_scene()
