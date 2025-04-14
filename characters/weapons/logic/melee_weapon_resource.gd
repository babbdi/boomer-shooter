class_name MeleeWeaponResource
extends WeaponResource

@export var max_hit_dist := 2.3

@export var miss_sound : AudioStream

func fire_shot() -> void:
	weapon_manager.play_anim(shoot_anim)
	weapon_manager.queue_anim(idle_anim)
	
	var raycast := weapon_manager.bullet_raycast
	raycast.target_position = Vector3(0,0,-abs(max_hit_dist))
	raycast.force_raycast_update()
	
	var bullet_target_pos := raycast.global_transform * raycast.target_position
	if raycast.is_colliding():
		weapon_manager.play_sound(shoot_sound)
		var obj := raycast.get_collider()
		var nrml := raycast.get_collision_normal()
		var pt := raycast.get_collision_point()
		
		var attack := Attack.new()
		attack.attack_damage = damage
		attack.attack_hit_location = pt
		bullet_target_pos = pt
		BulletDecalPool.spawn_bullet_decal(pt, nrml, obj, raycast.global_basis)
		if obj is RigidBody3D:
			obj.apply_impulse(-nrml * 5.0 / obj.mass, pt - obj.global_position)
		if obj.has_method("take_damage"):
			if obj is component_hitbox:
				if obj.critical_spot:
					attack.attack_crit = true
			if weapon_manager.current_weapon.name == "cigarette":
				weapon_manager.current_weapon_view_model.condition -= 1
				if weapon_manager.current_weapon_view_model.condition == -1:
					weapon_manager.current_weapon_view_model.spawn_cigarrete_bottom()
					weapon_manager.current_weapon = preload("res://characters/weapons/emptyHand/emptyHand.tres")

			obj.take_damage(attack)
	else:
		weapon_manager.play_sound(miss_sound)
	
	last_fire_time = Time.get_ticks_msec()
