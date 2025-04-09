class_name FloatingText
extends MeshInstance3D

static func spawn_floating_text(global_pos : Vector3, text : String, parent : Node3D, crit : bool):
	var floating_text : Node3D = preload("res://debug/enemies/Debug/damage_number/floating_text.tscn").instantiate()
	
	var floating_text_label = floating_text.find_child("Label")
	floating_text_label.mesh.text = text
	if crit:
		floating_text_label.mesh.surface_get_material(0).set("shader_parameter/albedo", Vector3(1.0, 0.0, 0.0))
	else:
		floating_text_label.mesh.surface_get_material(0).set("shader_parameter/albedo", Vector3(1.0, 1.0, 1.0))
	#floating_text.get_active_material(0)
	parent.add_child(floating_text)
	floating_text.global_position = global_pos
	print(floating_text.global_position)
	#var tween = Tween.new()
	
	#print("oi")
