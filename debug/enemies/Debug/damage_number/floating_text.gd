class_name FloatingText
extends MeshInstance3D

static func spawn_floating_text(global_pos : Vector3, text : String, parent : Node3D):
	var floating_text : Node3D = preload("res://debug/enemies/Debug/damage_number/floating_text.tscn").instantiate()
	floating_text.mesh.text = text
	parent.add_child(floating_text)
	#var tween = Tween.new()
	
	print("oi")
