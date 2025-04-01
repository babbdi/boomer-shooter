extends CharacterBody3D

@export var head : Node3D
@export var camera : Camera3D

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

@export_group("ground movement")
@export var jump_velocity := 6.0
@export var auto_bhop := true
@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0
var wish_dir := Vector3.ZERO

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
	var input_dir := Input.get_vector("left","right","up","down").normalized()
	
	## Ele rotaciona o personagem na direção que a gente está indo
	## https://youtu.be/ZJr2qUrzEqg?t=779
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	cam_aligned_wish_dir = camera.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	if not _handle_noclip(delta):
		if is_on_floor():
			if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
				self.velocity.y += jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)
	
		move_and_slide()

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
	var max_slope_ang_dot := Vector3(0,1,0).rotated(Vector3(1.0,0,0), self.floor_max_angle).dot(Vector3(0,1,0))
	if normal.dot(Vector3(0,1,0)) < max_slope_ang_dot:
		return true
	else:
		return false

func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _headbob_effect(delta : float) -> void:
	headbob_time += delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		cos(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0,
	)

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
