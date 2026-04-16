extends CharacterBody3D

# --- STATS DE L'ENNEMI ---
const SPEED = 8.0 # Un peu plus lent que le joueur, mais rapide quand même !
const GRAVITY = 25.0
const ATTACK_RANGE = 4.0
const DAMAGE_COOLDOWN = 1.0 # Le joueur perd 1 HP par seconde s'il reste collé
var last_damage_time = 0.0

# --- VARIABLES DU JUICE ---
const BOB_FREQ = 4.0 # Fréquence des pas (très rapide = nerveux)
const BOB_AMP = 0.25 # Hauteur du rebond
var t_bob = 0.0
@export var hp: int = 10

@onready var visuals = $Visuals
@onready var anim_player = $"Visuals/Root Scene/AnimationPlayer"

var target: Node3D = null

func _ready():
	# Pour être sûr qu'il prenne les coups
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	# 1. CHERCHER LE JOUEUR
	if not target or not is_instance_valid(target):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]

	# 2. GRAVITÉ
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var direction = Vector3.ZERO

	# 3. POURSUITE FRÉNÉTIQUE
	if target and is_on_floor():
		# On calcule la direction vers le joueur (en ignorant la hauteur pour ne pas voler)
		var target_pos = target.global_position
		target_pos.y = global_position.y 
		
		direction = global_position.direction_to(target_pos)
		
		# Application de la vitesse
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# Jouer l'animation de marche/course si elle existe
		if anim_player and anim_player.has_animation("CharacterArmature|Walk"):
			anim_player.play("CharacterArmature|Walk")
	else:
		# S'il n'a pas de cible, il freine
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if anim_player:
			anim_player.play("CharacterArmature|Idle")

	# 4. LE "JUICE" VISUEL DE L'ENNEMI
	if velocity.length() > 1.0 and is_on_floor():
		# A) Rotation fluide vers le joueur
		# On utilise atan2 pour trouver l'angle vers lequel il doit regarder
		var target_angle = atan2(velocity.x, velocity.z)
		# lerp_angle permet de tourner de façon "smooth" (organique)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, delta * 12.0)
		
		# B) Inclinaison agressive (Lean)
		# Il penche la tête en avant quand il te fonce dessus
		visuals.rotation.x = lerp(visuals.rotation.x, deg_to_rad(20.0), delta * 8.0)
		
		# C) Le Rebond (Bobbing nerveux)
		t_bob += delta * velocity.length()
		# abs(sin) donne un effet de "sautillement" continu
		visuals.position.y = abs(sin(t_bob * BOB_FREQ)) * BOB_AMP
		
	else:
		# Retour au calme s'il s'arrête
		visuals.rotation.x = lerp(visuals.rotation.x, 0.0, delta * 10.0)
		visuals.position.y = lerp(visuals.position.y, 0.0, delta * 10.0)

	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		
		if dist <= ATTACK_RANGE:
			attempt_attack()
	move_and_slide()
	

# Fonction pour plus tard quand on donnera des coups d'épée !
func take_damage(amount: int):
	hp -= amount
	# Petit effet de recul (Knockback) quand il prend un coup
	velocity = -global_transform.basis.z * 15.0
	velocity.y = 5.0 # Le fait légèrement sauter en arrière
	
	if hp <= 0:
		die()
		
func die() -> void:
	queue_free()
	
func attempt_attack():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_damage_time >= DAMAGE_COOLDOWN:
		if target.has_method("take_damage"):
			target.take_damage(1) # Inflige 1 point de dégât
			last_damage_time = current_time
