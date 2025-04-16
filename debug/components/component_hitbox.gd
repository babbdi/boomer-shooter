class_name component_hitbox
extends Area3D

@export_category('BASIC INFO')
@export var use_parent_hitbox : bool = false
@export var critical_spot : bool = false
@export var critical_multiplier : float = 2.0

## ELEMENTAL
@export_category('ELEMENTAL DAMAGE')
@export var flammable := false
@export var flame_multiplier := 1.0

func _ready() -> void:
	if use_parent_hitbox:
		for i in get_parent().get_children():
			if i is CollisionShape3D:
				var new_hitbox = i.duplicate()
				self.add_child(new_hitbox)
				new_hitbox.scale = Vector3(1.05,1.05,1.05)
				new_hitbox.position = Vector3(0,0,0)

var last_attack_damage := 0
var last_attack_hit_location = Vector3(0,0,0)
var last_attack_crit := false
var last_elemental_attack := ''
func take_damage(attack: Attack):
	for i in get_parent().get_children():
		if i is component_health:
			
			print("OLD HEALTH: ", i.current_health)
			print("ATTACK DAMAGE: ", attack.attack_damage, '\n',"CURRENT HEALTH: ", i.current_health, '\n')

			## CCRITICAL DAMAGE
			if critical_spot:
				attack.attack_damage *= critical_multiplier
			## ELEMENTAL DAMAGE
			if attack.elemental != 'none':
				if flammable && attack.elemental == 'fire':
					$timer_elemental_damage.paused = false
					$timer_elemental_damage.start(1 - (flame_multiplier * 0.1))
					elemental_timer_time = 1 * flame_multiplier
					last_elemental_attack = 'fire'
				last_attack_damage = attack.attack_damage
				last_attack_crit = attack.attack_crit
				last_attack_hit_location = attack.attack_hit_location
			## APPLY ELEMENTAL DAMAGE
			#while is_burning:
				#$timer_elemental_damage.autostart
				#
			i.current_health -= attack.attack_damage
			
			FloatingText.spawn_floating_text(attack.attack_hit_location, str(attack.attack_damage), self, attack.attack_crit)
			
			

var elemental_timer_time := 1.0
func _on_timer_elemental_damage_timeout() -> void:
	if elemental_timer_time < 0: 
		
		$timer_elemental_damage.paused = true
		$component_elemental_fire.emitting = false
		
	else:
		for i in get_parent().get_children():
			if i is component_health:
				if last_elemental_attack == 'fire':
					$component_elemental_fire.emitting = true
					
				i.current_health -= last_attack_damage * flame_multiplier
				FloatingText.spawn_floating_text(last_attack_hit_location, str(last_attack_damage * flame_multiplier), self, true)
				elemental_timer_time -= 1
				#print('oUCH')
