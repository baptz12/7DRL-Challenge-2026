extends Node3D

const BASICROOM = preload("uid://dx5sqbdpi6kru")
const CAPS = preload("uid://b2lktgjf41lr3")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const DOOR_SCENE = preload("res://scenes/door.tscn") 

@export var room_to_create = 20
@export var rooms_size = Vector2(51, 51)
var virtual_grid = {}

@export var player_scenes: Array[PackedScene] # Tes différentes scènes (.tscn) de joueurs
var current_player_index: int = -1
@onready var current_player: Node3D = $Player1 # Le joueur de départ déjà dans la scène

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	create_grid()
	adress_room()
	place_rooms()
	place_doors_and_caps()

func _process(delta: float) -> void:
	pass

func place_room(coord_x : float, coord_y: float) -> void:
	var new_room = BASICROOM.instantiate()
	new_room.position = Vector3(coord_x, 0, coord_y)
	add_child(new_room)

func create_grid() -> void:
	virtual_grid.clear()
	
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	var pos = Vector2(0, 0)
	
	virtual_grid[pos] = "Room"
	# On a créé notre première salle, on commence à compter !
	var room_created = 1
	
	# 4. LA BOUCLE : Tant qu'on n'a pas atteint notre objectif de 15 salles...
	while room_created < room_to_create:
		
		var direction_choosed = directions.pick_random()
		
		pos += direction_choosed
		
		if not virtual_grid.has(pos):
			
			virtual_grid[pos] = "Room"
			
			room_created += 1
	
func adress_room() -> void :
	virtual_grid[Vector2(0, 0)] = "Start"
	
	# 2. La salle du Boss est la toute dernière qu'on a dessinée
	# keys() récupère toutes les adresses, et back() prend la toute dernière !
	var boss = virtual_grid.keys().back()
	virtual_grid[boss] = "Boss"
	
	# 3. Trouver une salle au trésor (un "cul-de-sac")
	# On va chercher une salle qui n'a qu'un seul voisin
	var directions =[Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for adress in virtual_grid.keys():
		# On ignore le Départ et le Boss qu'on vient de définir
		if virtual_grid[adress] != "Room":
			continue 
			
		# On compte les voisins
		var neighbors = 0
		for dir in directions:
			if virtual_grid.has(adress + dir):
				neighbors += 1
				
		# Si c'est un cul-de-sac (1 seul voisin), ça devient le trésor !
		if neighbors == 1:
			virtual_grid[adress] = "Treasure"
			break # On a trouvé notre trésor, on arrête de chercher (on sort de la boucle)
			
func place_rooms() -> void:
	for adress in virtual_grid.keys():
		var role = virtual_grid[adress]
		var new_room = BASICROOM.instantiate()
		
		# --- CORRECTION ICI : On donne le rôle à la salle ---
		new_room.room_role = role
		
		var calculated_position_2d = adress * rooms_size
		new_room.position = Vector3(calculated_position_2d.x, 0, calculated_position_2d.y)
		add_child(new_room)
		virtual_grid[adress] = new_room
		
		var detector = new_room.get_node_or_null("RoomDetector")
		if detector:
			if role == "Start":
				detector.queue_free()
				new_room.room_cleared() 
			else:
				detector.body_entered.connect(_on_room_entered.bind(detector, new_room, adress, role))

func spawn_enemies(room_node: Node3D, adress: Vector2, role: String) -> void:
	# 1. Calcul de la difficulté selon la distance
	var map_keys = virtual_grid.keys()
	var room_index = map_keys.find(adress) # Numéro de la salle
	var total_rooms = map_keys.size()
	
	# Plus on s'approche de la fin, plus le ratio s'approche de 1.0
	var difficulty_ratio = float(room_index) / float(total_rooms)
	var nb_enemies = 1 + int(difficulty_ratio * 4.0) 
	if role == "Boss": nb_enemies += 4
	
	var root = get_tree().root
	var diff_mult = 1
	if root.has_meta("difficulty_multiplier"):
		diff_mult = root.get_meta("difficulty_multiplier")
		
	nb_enemies *= diff_mult
	
	if nb_enemies <= 0:
		if room_node.has_method("room_cleared"):
			room_node.room_cleared()
		return # On arrête là, pas besoin de boucle
	
	for i in range(nb_enemies):
		var enemy = ENEMY_SCENE.instantiate()
		room_node.add_child(enemy)
		var rand_x = randf_range(-7.0, 7.0)
		var rand_z = randf_range(-7.0, 7.0)
		enemy.position = Vector3(rand_x, 1.5, rand_z)
		
		# AJOUT : On enregistre l'ennemi dans la salle pour le comptage
		if room_node.has_method("register_enemy"):
			room_node.register_enemy(enemy)

func _on_room_entered(body: Node3D, detector: Area3D, room_node: Node3D, adress: Vector2, role: String) -> void:
	# On vérifie si c'est bien le joueur (grâce au groupe ajouté à l'étape 1)
	if body.is_in_group("player"):
		# On détruit le détecteur pour que le perso ne re-change pas si on repasse dans cette même salle
		detector.queue_free()
		
		spawn_enemies(room_node, adress, role)
		body.remove_from_group("player")
		# On demande le changement de joueur en "différé" (sécurité Godot pour la physique)
		call_deferred("swap_player", body)

func swap_player(old_player: Node3D) -> void:
	if player_scenes.size() <= 1:
		return
		
	# 1. Choisir le nouveau joueur
	var new_index = current_player_index
	while new_index == current_player_index:
		new_index = randi() % player_scenes.size()
		
	current_player_index = new_index
	
	var new_player_instance = player_scenes[new_index].instantiate()
	
	# 2. SAUVEGARDE DES DONNÉES DE L'ANCIEN JOUEUR
	var old_pos = old_player.global_position
	var old_rot = old_player.global_rotation
	var old_vel = old_player.get("velocity") if "velocity" in old_player else Vector3.ZERO
	
	var old_hp = old_player.hp 
	var old_cam = old_player.get_node_or_null("CameraMount")
	var old_cam_rot = old_cam.rotation if old_cam else Vector3.ZERO
	
	# 3. /!\ AJOUTER LE NOEUD À LA SCÈNE D'ABORD /!\
	add_child(new_player_instance)
	
	# 4. APPLIQUER LA POSITION SEULEMENT APRÈS
	new_player_instance.global_position = old_pos
	new_player_instance.global_rotation = old_rot
	new_player_instance.hp = old_hp
	
	if "velocity" in new_player_instance:
		new_player_instance.velocity = old_vel # Transfère l'élan/la vitesse
	
	var new_cam = new_player_instance.get_node_or_null("CameraMount")
	if new_cam:
		new_cam.rotation = old_cam_rot
	
	# 5. On supprime définitivement l'ancien
	old_player.queue_free()
	current_player = new_player_instance

# Dans res://scripts/world.gd

func place_doors_and_caps() -> void:
	for adress in virtual_grid.keys():
		var room = virtual_grid[adress]
		
		var verifs = {
			Vector2.UP: ["WallNorth", "NorthMarker"],
			Vector2.DOWN: ["WallSouth", "SouthMarker"],
			Vector2.RIGHT: ["WallEast", "EastMarker"],
			Vector2.LEFT: ["WallWest", "WestMarker"]
		}
		
		for direction in verifs.keys():
			var wall_name = verifs[direction][0]
			var marker_name = verifs[direction][1]
			var next_adress = adress + direction
			
			# Si on a un voisin à cette adresse
			if virtual_grid.has(next_adress):
				var wall_node = room.get_node_or_null(wall_name)
				var marker_node = room.get_node_or_null(marker_name)
			
				if virtual_grid.has(next_adress):
					# ... (suppression du mur et gestion des marqueurs) ...
					
					if wall_node:
						wall_node.queue_free()
						
					if marker_node:
						# Si on est dans le cas où on ne crée PAS la porte (UP ou LEFT), on continue
						if direction == Vector2.UP or direction == Vector2.LEFT:
							continue

						# Création de la porte
						var door_instance = DOOR_SCENE.instantiate()
						room.add_child(door_instance)
						door_instance.global_transform = marker_node.global_transform
						
						if direction == Vector2.UP or direction == Vector2.DOWN:
								door_instance.rotation_degrees.y = 90
						
						# 1. On enregistre la porte dans la salle COURANTE (comme avant)
						if room.has_method("register_door"):
							room.register_door(door_instance)
						
						# --- CORRECTION ICI ---
						# 2. On récupère la salle VOISINE et on lui donne AUSSI la porte
						var neighbor_room = virtual_grid[next_adress]
						if neighbor_room.has_method("register_door"):
							neighbor_room.register_door(door_instance)
