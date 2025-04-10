extends WeaponResource

func on_process(delta : float) -> void:
	if trigger_down and auto_fire and Time.get_ticks_msec() - last_fire_time >= max_fire_rate_ms:
		if current_ammo > 0:
			fire_shot()
		else:
			reload_pressed()

	
