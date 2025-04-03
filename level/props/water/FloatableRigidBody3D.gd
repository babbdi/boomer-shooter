class_name FloatableRigidBody3d
extends RigidBody3D

var time_floating := 500
func _process(delta: float) -> void:
	_handle_water_physics(delta)
func _handle_water_physics(delta : float) -> bool:
	if get_tree().get_nodes_in_group("water_area").all(func(area : Node3D) -> bool: return !area.overlaps_body(self)):
		return false
	if time_floating >= 0:
		apply_impulse(Vector3(0,0.250 / mass,0))
		time_floating -= 1
	else:
		return false
	return true
	#velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * 0.1 * delta
