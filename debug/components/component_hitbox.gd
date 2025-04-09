class_name component_hitbox
extends Area3D

@export var use_parent_hitbox : bool = false
@export var critical_spot : bool = false
@export var critical_multiplier : float = 2.0
func _ready() -> void:
	if use_parent_hitbox:
		for i in get_parent().get_children():
			if i is CollisionShape3D:
				var new_hitbox = i.duplicate()
				self.add_child(new_hitbox)
				new_hitbox.scale = Vector3(1.05,1.05,1.05)

func take_damage(attack: Attack):
	for i in get_parent().get_children():
		if i is component_health:
			
			print("OLD HEALTH: ", i.current_health)
			print("ATTACK DAMAGE: ", attack.attack_damage, '\n',"CURRENT HEALTH: ", i.current_health, '\n')
			
			if critical_spot:
				attack.attack_damage *= critical_multiplier
			i.current_health -= attack.attack_damage
			
			FloatingText.spawn_floating_text(attack.attack_hit_location, str(attack.attack_damage), self, attack.attack_crit)
			
			
