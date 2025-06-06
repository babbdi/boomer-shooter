class_name WeaponResource
extends Resource

@export var name : String
@export var icon : Texture2D

@export_range(1,9) var slot : int = 1
@export_range(1,10) var slot_priority : int = 1

@export_category('scenes')
## Used for the first person perspective, when holding the gun. Will include hand models
@export var model : PackedScene
## Used for when the weapon is in the player's hand or on the ground
@export var world_model : PackedScene

@export var uses_muzzle := false
@export var muzzle_flash : PackedScene
@export var bullet_tracer : PackedScene

@export_category('vectors')
@export var model_pos : Vector3
@export var model_rot : Vector3
@export var model_scale := Vector3(1,1,1)



### Which animation style the player model will use when the gun is equipped (viewed by other players/mirrors)
#enum CharacterHoldStyle {
	#PISTOL, SMG, BAZOOKA, KNIFE, GRENADE
#}
#@export var hold_style : CharacterHoldStyle
@export_category('animation')
@export var idle_anim : String
@export var equip_anim : String
@export var shoot_anim : String
@export var reload_anim : String

## Sounds

@export_category('sounds')
@export var shoot_sound : AudioStream
@export var reload_sound : AudioStream
@export var unholster_sound : AudioStream

## Weapon logic

@export_category('damage & info')
@export var damage := 10

@export var current_ammo := INF
@export var magazine_capacity := INF
@export var reserve_ammo := INF
@export var max_reserve_ammo := INF

@export var auto_fire : bool = true
@export var max_fire_rate_ms : float = 50

@export var spray_pattern : Curve2D

@export_enum('none','fire','acid') var elemental = 'none'

const RAYCAST_DIST : float = 9999 # Too far seems to break it

var weapon_manager : WeaponManager

var trigger_down := false :
	set(v):
		if trigger_down != v:
			trigger_down = v
			if trigger_down:
				on_trigger_down()
			else:
				on_trigger_up()

var is_equipped := false :
	set(v):
		if is_equipped != v:
			is_equipped = v
			if is_equipped:
				on_equip()
			else:
				on_unequip()

var last_fire_time := -999999

func on_process(delta : float) -> void:
	if trigger_down and auto_fire and Time.get_ticks_msec() - last_fire_time >= max_fire_rate_ms:
		if current_ammo > 0:
			fire_shot()
		else:
			reload_pressed()


func on_trigger_down() -> void:
	if Time.get_ticks_msec() - last_fire_time >= max_fire_rate_ms and current_ammo > 0:
		fire_shot()
	elif current_ammo == 0:
		reload_pressed()

func on_trigger_up() -> void:
	pass

func on_equip() -> void:
	weapon_manager.play_sound(unholster_sound)
	weapon_manager.play_anim(equip_anim)
	weapon_manager.queue_anim(idle_anim)

func on_unequip() -> void:
	pass

func get_amount_can_reload() -> int:
	var wish_reload := magazine_capacity - current_ammo
	var can_reload : int = min(wish_reload, reserve_ammo)
	return can_reload

func reload_pressed() -> void:
	if reload_anim and weapon_manager.get_anim() == reload_anim:
		#print("mesma animação de reload")
		return
	if get_amount_can_reload() <= 0:
		print("não precisa recarregar - reload_pressed")
		return
	var cancel_cb := (func() -> void:
		weapon_manager.stop_sounds())
	weapon_manager.play_anim(reload_anim, reload, cancel_cb)
	weapon_manager.queue_anim(idle_anim)
	weapon_manager.play_sound(reload_sound)

func reload() -> void:
	var can_reload := get_amount_can_reload()
	if can_reload < 0:
		print("não precisa recarregar - reload")
		return
	elif magazine_capacity == INF or current_ammo == INF:
		print("munição infinita")
		current_ammo = magazine_capacity
	else:
		print("recarregando")
		current_ammo += can_reload
		reserve_ammo -= can_reload

var num_shots_fired : int = 0
func fire_shot() -> void:
	weapon_manager.play_anim(shoot_anim)
	weapon_manager.play_sound(shoot_sound)
	weapon_manager.queue_anim(idle_anim)
	
	var raycast := weapon_manager.bullet_raycast
	raycast.rotation.x = weapon_manager.get_current_recoil().x 
	raycast.rotation.y = weapon_manager.get_current_recoil().y
	raycast.target_position = Vector3(0,0,-abs(RAYCAST_DIST))
	raycast.force_raycast_update()
	
	var bullet_target_pos := raycast.global_transform * raycast.target_position
	if raycast.is_colliding():
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
			obj.take_damage(attack)
	
	weapon_manager.show_muzzle_flash()
	#if num_shots_fired % 2 == 0:
	weapon_manager.make_bullet_trail(bullet_target_pos)
	weapon_manager.apply_recoil()
	
	last_fire_time = Time.get_ticks_msec()
	current_ammo -= 1
	num_shots_fired += 1
