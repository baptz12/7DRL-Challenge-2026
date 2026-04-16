# res://scripts/room.gd
extends Node3D

var enemies_count: int = 0
var doors: Array = [] # Liste des portes de cette salle
var is_cleared: bool = false
@onready var next_level_sound: AudioStreamPlayer3D = $NextLevelSound

var room_role: String = "Room"

# Fonction appelée par le World quand il fait spawn un ennemi
func register_enemy(enemy: Node3D):
	enemies_count += 1
	# On écoute le signal "tree_exited" (quand l'ennemi est queue_free/mort)
	enemy.tree_exited.connect(_on_enemy_killed)

# Fonction appelée par le World pour ajouter une porte à la liste
func register_door(door_node: Node3D):
	doors.append(door_node)
	# --- CORRECTION ---
	# Si la salle est DÉJÀ considérée comme clean (ex: Start), on ouvre la porte tout de suite !
	if is_cleared:
		door_node.unlock()

func _on_enemy_killed():
	enemies_count -= 1
	
	if enemies_count <= 0:
		room_cleared()

func room_cleared():
	if is_cleared: return
	is_cleared = true
	
	for door in doors:
		if is_instance_valid(door):
			door.unlock()
	if room_role == "Boss":
		victory()

func victory():
	next_level_sound.play()
	var root = get_tree().root
	var current_diff = 1
	if root.has_meta("difficulty_multiplier"):
		current_diff = root.get_meta("difficulty_multiplier")
		
	root.set_meta("difficulty_multiplier", current_diff + 1)
	
	# Optionnel : Tu peux ralentir le temps pour un effet stylé
	Engine.time_scale = 0.3 
	
	# Pour relancer le jeu au bout de 2 secondes (vrai temps) :
	await get_tree().create_timer(2.0, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().reload_current_scene() # Recommence la partie
