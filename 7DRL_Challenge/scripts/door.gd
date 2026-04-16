extends Node3D

@onready var mesh = $CSGBox3D10          # Le visuel
@onready var static_body = $StaticBody3D # Le corps physique (mur invisible)

var is_locked: bool = true
var is_open: bool = false

# Appelée par la Salle quand la pièce est clean
func unlock():
	is_locked = false
	# On met la porte en VERT pour montrer qu'elle est ouverte
	if mesh.material_override:
		mesh.material_override.albedo_color = Color.GREEN
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.GREEN
		mesh.material_override = mat

func open_door():
	if is_open: return 
	is_open = true
	
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# CORRECTION : On monte à 8.0 au lieu de 3.0 pour dégager complètement le passage
	# (La porte fait ~7.6m de haut, donc à 3.0 elle bloque encore le sol)
	tween.tween_property(mesh, "position:y", 8.0, 0.5)
	tween.tween_property(static_body, "position:y", 8.0, 0.5)

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Si la porte est verrouillée ou déjà ouverte, on ne fait rien
	if is_locked or is_open: return
	
	if body.is_in_group("player"):
		open_door()
