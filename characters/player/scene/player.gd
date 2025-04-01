extends CharacterBody3D

@export var head : Node3D
@export var camera : Camera3D
@export var rc_stairAhead : RayCast3D
@export var rc_stairBelow : RayCast3D
@export_group("camera")
@export var look_sensitivity := 0.006
@export var gamepad_look_sensitivity := 0.05
const HEADBOB_MOVE_AMOUNT := 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

## NOCLIP
var cam_aligned_wish_dir := Vector3.ZERO
var noclip_speed_mult := 3.0
var noclip := false

## CROUCH

const CROUCH_TRANSLATE = 0.7
const CROUCH_JUMP_ADD = CROUCH_TRANSLATE * 0.9 #o quanto vai subir quando agachar (o pulinho/ impulso de jogo tipo cs)
var is_crouched := false
@export_group("ground movement")
@export var jump_velocity := 6.0
@export var auto_bhop := true
@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0
var wish_dir := Vector3.ZERO
const MAX_STEP_HEIGHT := 0.5
var _snapped_to_stair_last_frame := false
var _last_frame_was_on_floor := -INF
@export_group("air movement")
@export var air_cap := 0.85 # conseguir surfar em rampas mais altas, quanto maior o valor mais facil de "grudar" nelas
@export var air_accel := 800.0 
@export var air_move_speed := 500.0


func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	
	## Prende o mouse na tela
	if event is InputEventMouseMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	## Se mexer o mouse, o corpo e a camera giram
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity) 
			camera.rotate_x(-event.relative.y * look_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_mult = min(100.0, noclip_speed_mult * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_mult = max(0.1, noclip_speed_mult * 0.9)

func _process(delta: float) -> void:
	_handle_controller_look_input(delta)

func _handle_air_physics(delta : float) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	## https://youtu.be/ZJr2qUrzEqg?t=1745
	var cur_speed_in_wish_dir := self.velocity.dot(wish_dir)
	# wish speed (if wish_dir > 0 lenght) capped to air_cap
	var capped_speed : float = min((air_move_speed * wish_dir).length(), air_cap)
	# How much to get to the speed the player wishes (in the new dir)
	# Notice this allows for infinite speed. If wish_dir is perpendicular, we always need to add velocity
	#  no matter how fast we're going. This is what allows for things like bhop in CSS & Quake.
	# Also happens to just give some very nice feeling movement & responsiveness when in the air.
	var add_speed_till_cap := capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed := air_accel * air_move_speed * delta # Usually is adding this one.
		accel_speed = min(accel_speed, add_speed_till_cap) # Works ok without this but sticking to the recipe
		self.velocity += accel_speed * wish_dir
	
	if is_on_wall():
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta) ## permite surfar
func _handle_ground_physics(delta : float) -> void:
	
	var cur_speed_in_wish_dir := self.velocity.dot(wish_dir)
	var add_speed_till_cap := get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0: 
		var accel_speed := ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir ## nao se move se nao mexer em nada (wish_dir)
		
	## aplicar fricção
	var control : float = max(self.velocity.length(), ground_decel)
	var drop := control * ground_friction * delta # o quanto de velocidade ele vai tirar todo frame
	var new_speed : float = max(self.velocity.length() - drop, 0.0) # pegando nossa velocidade e aplicando a fricção
	if self.velocity.length() > 0: # se não estivermos parado, aplicamos a fricção
		new_speed /= self.velocity.length() # um ratio do quanto sera a nova velocidade
	self.velocity *= new_speed # aqui realmente aplica e muda a velocidade
	
	_headbob_effect(delta)
func _physics_process(delta: float) -> void:
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	var input_dir := Input.get_vector("left","right","up","down").normalized()
	
	## Ele rotaciona o personagem na direção que a gente está indo
	## https://youtu.be/ZJr2qUrzEqg?t=779
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	cam_aligned_wish_dir = camera.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	_handle_crouch(delta)
	if not _handle_noclip(delta):
		if is_on_floor() or _snapped_to_stair_last_frame:
			if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
				self.velocity.y = jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)
		
		if not _snap_up_stairs_check(delta):
			# Because _snap_up_stairs_check moves the body manually, don't call move_and_slide
			# This should be fine since we ensure with the body_test_motion that it doesn't 
			# collide with anything except the stairs it's moving up to.
			#_push_away_rigid_bodies() # Call before move_and_slide()
			move_and_slide()
			_snap_down_to_stairs_check()
	_slide_camera_smooth_back_to_origin(delta)
		

func _handle_noclip(delta : float) -> bool:
	if Input.is_action_just_pressed('noclip') and OS.has_feature("debug"):
		noclip = !noclip
		noclip_speed_mult = 3.0
	$cs_player.disabled = noclip
	if not noclip:
		return false
	
	var speed := get_move_speed() * noclip_speed_mult
	if Input.is_action_just_pressed("sprint"):
		speed *= 6.0
	self.velocity = cam_aligned_wish_dir * speed #estilo do Gmod
	global_position += self.velocity * delta
	return true
	
func clip_velocity(normal : Vector3, overbounce: float, delta: float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce ## deslizar em rampas e paredes (surfar)
	if backoff >= 0: return
	var change := normal * backoff 
	self.velocity -= change
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

## ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS ESCADAS 
func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	# Modified slightly from tutorial. I don't notice any visual difference but I think this is correct.
	# Since it is called after move_and_slide, _last_frame_was_on_floor should still be current frame number.
	# After move_and_slide off top of stairs, on floor should then be false. Update raycast incase it's not already.
	%rc_stairBelow.force_raycast_update()
	var floor_below : bool = %rc_stairBelow.is_colliding() and not is_surface_too_steep(%rc_stairBelow.get_collision_normal())
	var was_on_floor_last_frame := Engine.get_physics_frames() == _last_frame_was_on_floor
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stair_last_frame) and floor_below:
		var body_test_result := KinematicCollision3D.new()
		if self.test_move(self.global_transform, Vector3(0,-MAX_STEP_HEIGHT,0), body_test_result):
			_save_camera_pos_for_smoothing()
			var translate_y := body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stair_last_frame = did_snap
func _snap_up_stairs_check(delta : float) -> bool:
	if not is_on_floor() and not _snapped_to_stair_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
 

	var expected_move_motion := self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance := self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	#  We give some clearance above to ensure there's ample room for the player.
	#  If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	#  along with their intended motion forward.
	var down_check_result := KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height := ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y 
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%rc_stairAhead.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		%rc_stairAhead.force_raycast_update()
		if %rc_stairAhead.is_colliding() and not is_surface_too_steep(%rc_stairAhead.get_collision_normal()):
			_save_camera_pos_for_smoothing()
			self.global_position = (step_pos_with_clearance.origin) + (down_check_result.get_travel())
			apply_floor_snap()
			_snapped_to_stair_last_frame = true
			return true
	return false
	
var _saved_camera_global_pos := Vector3(0,0,0)
func _save_camera_pos_for_smoothing() -> void:
	if _saved_camera_global_pos == Vector3(0,0,0):
		_saved_camera_global_pos = %cameraSmooth.global_position
func _slide_camera_smooth_back_to_origin(delta : float) -> void:
	if _saved_camera_global_pos == null: return
	%cameraSmooth.global_position.y = _saved_camera_global_pos.y
	%cameraSmooth.position.y = clampf(camera.position.y, -CROUCH_TRANSLATE, CROUCH_TRANSLATE) # Clamp incase teleported
	var move_amount : float = max(self.velocity.length() * delta, walk_speed/2 * delta)
	%cameraSmooth.position.y = move_toward(%cameraSmooth.position.y, 0.0, move_amount)
	_saved_camera_global_pos = %cameraSmooth.global_position
	if %cameraSmooth.position.y == 0:
		_saved_camera_global_pos = Vector3(0,0,0) # Stop smoothing camera
func _run_body_test_motion(from : Transform3D, motion : Vector3, result : PhysicsTestMotionResult3D) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

func get_move_speed() -> float:
	if is_crouched:
		return walk_speed * 0.8
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _headbob_effect(delta : float) -> void:
	headbob_time += delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		cos(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0,
	)

## AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR AGACHAR 
@onready var _original_capsule_height : float = $cs_player.shape.height
func _handle_crouch(delta : float) -> void:
	var was_crouched_last_frame := is_crouched
	if Input.is_action_pressed("crouch"):
		is_crouched = true
	elif is_crouched and not self.test_move(self.transform, Vector3(0,CROUCH_TRANSLATE,0)):
		is_crouched = false
	
	# permite que quando agacha vc da um pulinho extra
	var translate_y_if_possible := 0.0
	if was_crouched_last_frame != is_crouched and not is_on_floor() and not _snapped_to_stair_last_frame:
		translate_y_if_possible = CROUCH_JUMP_ADD if is_crouched else -CROUCH_JUMP_ADD
	# se certifica q a cabeça do player nao seja inficada no teto
	if translate_y_if_possible != 0.0:
		var result := KinematicCollision3D.new()
		self.test_move(self.global_transform, Vector3(0,translate_y_if_possible, 0), result)
		self.position.y += result.get_travel().y
		head.position.y -= result.get_travel().y 
		head.position.y = clampf(head.position.y, -CROUCH_TRANSLATE, 0)
		
	head.position.y = move_toward(head.position.y, -CROUCH_TRANSLATE if is_crouched else 0, 7.0 * delta)
	$cs_player.shape.height = _original_capsule_height - CROUCH_TRANSLATE if is_crouched else _original_capsule_height
	$cs_player.position.y = $cs_player.shape.height / 2


var _cur_gamepad_look := Vector2()
func _handle_controller_look_input(delta: float) -> void:
	
	var target_look := Input.get_vector("gamepad_look_left","gamepad_look_right","gamepad_look_up","gamepad_look_down").normalized()
	if target_look.length() < _cur_gamepad_look.length():
		_cur_gamepad_look = target_look
	else:
		_cur_gamepad_look = _cur_gamepad_look.lerp(target_look, 5.0 * delta)
		
	rotate_y(-_cur_gamepad_look.x * gamepad_look_sensitivity) # esquerda e direita
	camera.rotate_x(-_cur_gamepad_look.y * gamepad_look_sensitivity) #cima e baixo
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
