extends CharacterBody3D
class_name Player
# ============================================================
#  On-foot controller + "ride" the car when driving.
# ============================================================

const WALK := 6.0
const RUN := 9.5
const GRAVITY := 26.0
const JUMP := 8.0
const INTERACT_RANGE := 5.5

var current_vehicle: Vehicle = null
var carrying: PartItem = null
## True while jimmying or hotwiring: something anyone can see you doing.
var stealing: bool = false
var input_locked: bool = false
var hud: Node = null
var _target: Node = null
var _mouse_sens := 0.0032
var _yaw := 0.0
var _pitch := -0.25
var _busted_timer := 0.0
var _cooldown := 0.0
var _reloading := 0.0
var _hurt_lull := 0.0
var _jumping := false
var _rig: PersonRig
## A shove that is not yours -- thrown clear of a car door, mostly. It bleeds
## off over about a second; without it the walk code wipes it the same frame.
var _shoved := Vector3.ZERO
var _torch: SpotLight3D = null
## Metres walked since the last footstep, and the engine of whatever we drive.
var _stride := 0.0
var _engine: AudioStreamPlayer3D = null

## Held right button: the camera comes in over the shoulder and the view
## narrows. Eased rather than snapped, or every shot starts with a lurch.
var aiming_down := false
const HIP_ARM := 6.5
const AIM_ARM := 2.3
const HIP_FOV := 74.0
const AIM_FOV := 52.0
const AIM_SHOULDER := 0.75

@onready var pivot: Node3D = $CamPivot
@onready var arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var body_mesh: Node3D = $Body
@onready var hold: Node3D = $CamPivot/Hold

func _ready() -> void:
	add_to_group("player")
	add_to_group("shootable")
	_rig = PersonRig.new(body_mesh)
	GameState.kit_changed.connect(_show_held)
	_show_held()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Put whatever is off the belt into the model hand, so the tool you are
## about to use is the one everybody can see you holding.
func _show_held() -> void:
	if _rig:
		PersonMesh.hold_item(_rig.hand, GameState.held())
	_refresh_torch()

## The flashlight, if that is what is in your hand. It goes in the "torch"
## group, which is how the world knows the beam lights whatever is in it --
## including you, to anybody looking.
func _refresh_torch() -> void:
	var want := String(GameState.held_item().get("kind", "")) == "torch"
	if want and _torch == null:
		_torch = SpotLight3D.new()
		_torch.spot_range = 22.0
		_torch.spot_angle = 32.0
		_torch.light_energy = 3.0
		_torch.light_color = Color(1.0, 0.96, 0.85)
		_torch.position = Vector3(0.3, 1.4, 0)
		add_child(_torch)
		add_to_group("torch")
		set_meta("torch_reach", 22.0)
	elif not want and _torch != null:
		_torch.queue_free()
		_torch = null
		remove_from_group("torch")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * _mouse_sens
		_pitch = clampf(_pitch - event.relative.y * _mouse_sens, -1.2, 0.5)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# shoulder the gun: the shot pulls in tight and off to one side so you
		# can actually see what you are pointing at
		aiming_down = event.pressed and not input_locked and current_vehicle == null
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not input_locked:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not input_locked:
			_use_held()
	elif event is InputEventKey and event.pressed and not event.echo:
		if input_locked:
			return
		match event.keycode:
			KEY_E:
				_try_interact()
			KEY_F:
				if current_vehicle:
					exit_vehicle()
			KEY_G:
				drop_carried()
			KEY_R:
				_reload()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				GameState.select_slot(event.keycode - KEY_1)
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	pivot.rotation.y = _yaw
	arm.rotation.x = _pitch
	_ease_aim(delta)
	if _torch:
		# points where you are looking, and the world reads the same direction
		var aim: Vector3 = -arm.global_transform.basis.z
		_torch.look_at(_torch.global_position + aim, Vector3.UP)
		set_meta("torch_dir", aim)

	if current_vehicle:
		_drive(delta)
		_engine_note()
	else:
		_walk(delta)
		_feet(delta)

	if not input_locked:
		_scan_target()
	_check_busted(delta)
	_tick_gun(delta)

## The shot slides between hip and shoulder rather than cutting, and the arm
## shifts sideways so the player's own back is not in the middle of the sights.
func _ease_aim(delta: float) -> void:
	var want := aiming_down and current_vehicle == null and not input_locked
	var t := clampf(delta * 9.0, 0.0, 1.0)
	arm.spring_length = lerpf(arm.spring_length, AIM_ARM if want else HIP_ARM, t)
	arm.position.x = lerpf(arm.position.x, AIM_SHOULDER if want else 0.0, t)
	var cam := arm.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.fov = lerpf(cam.fov, AIM_FOV if want else HIP_FOV, t)
	if hud:
		hud.set_aiming(want)

## One step every so many metres, faster and louder at a run. Driven off
## distance rather than a timer, so it stays in step at any speed.
func _feet(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or moving < 0.6:
		_stride = 1.2
		return
	var running := moving > 5.0
	_stride -= moving * delta
	if _stride > 0.0:
		return
	_stride = 1.05 if running else 1.35
	Sfx.play("step_run" if running else "step_walk",
		global_position - Vector3(0, 1.1, 0), -10.0 if running else -14.0)

func _walk(delta: float) -> void:
	var dir := Vector3.ZERO
	if not input_locked:
		var iy := Input.get_axis("ui_up", "ui_down")
		var ix := Input.get_axis("ui_left", "ui_right")
		if Input.is_key_pressed(KEY_W): iy -= 1.0
		if Input.is_key_pressed(KEY_S): iy += 1.0
		if Input.is_key_pressed(KEY_A): ix -= 1.0
		if Input.is_key_pressed(KEY_D): ix += 1.0
		dir = (pivot.transform.basis * Vector3(ix, 0, iy))
		dir.y = 0.0
		dir = dir.normalized()
	# space is a jump on foot and the handbrake behind a wheel
	if Input.is_key_pressed(KEY_SPACE) and not input_locked and is_on_floor():
		velocity.y = JUMP
		_jumping = true
	var spd := RUN if Input.is_key_pressed(KEY_SHIFT) and not input_locked else WALK
	velocity.x = dir.x * spd + _shoved.x
	velocity.z = dir.z * spd + _shoved.z
	_shoved = _shoved.move_toward(Vector3.ZERO, delta * 13.0)
	if is_on_floor() and not _jumping:
		velocity.y = -2.0
	else:
		velocity.y -= GRAVITY * delta
		if is_on_floor() and velocity.y < 0.0:
			_jumping = false
	move_and_slide()
	# lining up a shot turns you to face the way the camera is looking, so the
	# model points the gun at whatever the crosshair is on
	var aiming: bool = not input_locked and (aiming_down
		or String(GameState.held_item().get("kind", "")) == "gun")
	if aiming:
		body_mesh.rotation.y = lerp_angle(body_mesh.rotation.y, _yaw + PI, 0.3)
	elif dir.length() > 0.1:
		body_mesh.rotation.y = lerp_angle(body_mesh.rotation.y, atan2(dir.x, dir.z), 0.25)
	_rig.step(delta, Vector2(velocity.x, velocity.z).length(), aiming)

func _drive(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	if not input_locked:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): throttle += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): throttle -= 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): steer -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): steer += 1.0
	var handbrake := Input.is_key_pressed(KEY_SPACE) and not input_locked
	current_vehicle.drive(throttle, steer, delta, handbrake)
	global_position = current_vehicle.global_position + Vector3.UP * 0.4
	_seat_body()
	# lazily swing the camera behind the car
	var car_yaw := current_vehicle.rotation.y
	if absf(current_vehicle.speed) > 2.0:
		_yaw = lerp_angle(_yaw, car_yaw, 0.035)

## Sit the model in the driver's seat of whatever it is riding in. The player
## node itself rides on the car's origin, so this is the offset from there.
func _seat_body() -> void:
	if current_vehicle == null or not is_instance_valid(current_vehicle):
		return
	var fit: float = current_vehicle.occupant_scale()
	var hips: Vector3 = current_vehicle.seat_point(true) - Vector3(0, PersonMesh.HIP * fit, 0)
	body_mesh.position = (current_vehicle.global_transform.basis * hips) - Vector3(0, 0.4, 0)
	body_mesh.rotation.y = current_vehicle.rotation.y + PI
	body_mesh.scale = Vector3.ONE * fit

# ------------------------------------------------------------
#  Interaction targeting: nearest thing roughly in front of you
# ------------------------------------------------------------
func _scan_target() -> void:
	var best: Node = null
	var best_score := 999.0
	var cam_fwd := -arm.global_transform.basis.z
	cam_fwd.y = 0
	cam_fwd = cam_fwd.normalized()
	for n in get_tree().get_nodes_in_group("interactable"):
		if n == current_vehicle:
			continue
		if n is Vehicle and n.driver != null:
			continue
		var to: Vector3 = (n as Node3D).global_position - global_position
		var dist := to.length()
		if dist > INTERACT_RANGE:
			continue
		to.y = 0
		var ang := cam_fwd.angle_to(to.normalized()) if to.length() > 0.01 else 0.0
		if ang > 1.4:
			continue
		var score := dist * 0.3 + ang
		if score < best_score:
			best_score = score
			best = n
	_target = best
	if hud:
		hud.set_prompt(best.get_prompt() if best else "")

func _try_interact() -> void:
	if current_vehicle:
		return
	if _target and _target.has_method("interact"):
		_target.interact(self)

# ------------------------------------------------------------
#  Vehicles
# ------------------------------------------------------------
func begin_breakin(v: Vehicle) -> void:
	if not GameState.carrying_item("jimmy"):
		hud.toast("NOT ON YOU", "The jimmy is back at the shop. Put it on your belt.")
		return
	if not GameState.can_attempt(v.data):
		hud.toast("TOO FANCY", "You need %s." % GameState.requirement_text(v.data))
		return
	stealing = true
	hud.start_breakin(v, Callable(self, "_on_breakin_result"))

func _on_breakin_result(v: Vehicle, success: bool) -> void:
	stealing = false
	if not success:
		v.failed_attempts += 1
		hud.toast("GAVE UP ON IT", "The whole street heard that.")
		_breakin_noise(v)
		return
	v.unlock()
	v.mark_hot()
	GameState.add_theft_xp(1 + int(v.data.tier))
	hud.toast("DOOR OPEN", "Now get it started.")
	# let the door actually swing before the shot drops inside to the column
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(v):
		begin_hotwire(v)

# ------------------------------------------------------------
#  Taking one off the driver
# ------------------------------------------------------------
## No lock to pick and no column to wire: the only thing between you and the
## car is the person holding onto it.
func begin_carjack(v: Vehicle) -> void:
	if not GameState.can_carjack(v.data):
		hud.toast("IMMOBILISED", "The %s wants %s before the driver is worth your time." % [
			v.data.name, GameState.carjack_key_text(v.data)])
		return
	if carrying:
		hud.toast("BOTH HANDS FULL", "Put the %s down first. [G]" % carrying.part_name)
		return
	stealing = true
	hud.start_carjack(v, Callable(self, "_on_carjack_result"))

func _on_carjack_result(v: Vehicle, success: bool) -> void:
	stealing = false
	if not is_instance_valid(v):
		return
	if not success:
		# they got the door back, and they are not waiting about
		var away: Vector3 = global_position - v.global_position
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3.FORWARD
		_shoved = away.normalized() * 9.0
		velocity.y = 4.5
		_jumping = true
		v.close_door("door_l")
		if v.has_method("bolt"):
			v.bolt()
		hud.toast("THEY FLOORED IT", "Dumped on the tarmac while they went through the lights.")
		_carjack_seen(v, true)
		return
	var thrown := v.eject_occupant()
	v.mark_hot()
	v.locked = false
	v.hotwired = true
	v.close_door("door_l")           # pulled shut behind you
	GameState.add_theft_xp(2 + int(v.data.tier))
	GameState.stats.stolen += 1
	hud.toast("OUT YOU GET", "%s - est. $%d" % [v.data.name, v.estimated_value()])
	# everybody on the pavement saw that and would rather be somewhere else
	for n in get_tree().get_nodes_in_group("pedestrian"):
		if n != thrown and (n as Node3D).global_position.distance_to(global_position) < 22.0:
			(n as Pedestrian)._scatter(global_position, 7.0)
	_carjack_seen(v, false)
	enter_vehicle(v)

## Doing that in the open is the loudest thing on the street. A copper who can
## see it calls it straight in; otherwise it depends who was about.
func _carjack_seen(v: Vehicle, failed: bool) -> void:
	for group in ["police_foot", "police"]:
		for n in get_tree().get_nodes_in_group(group):
			if (n as Node3D).global_position.distance_to(global_position) > 45.0:
				continue
			if not Gunplay.clear_shot(n as Node3D, self, 1.5):
				continue
			GameState.raise_wanted(1 if failed else 2)
			get_tree().call_group("police_dispatch", "dispatch")
			hud.toast("SEEN", "A copper watched you do that.")
			return
	if not failed and randf() < 0.5:
		GameState.raise_wanted(1)
		get_tree().call_group("police_dispatch", "dispatch")

## Second half: rip the column open and wire it up.
func begin_hotwire(v: Vehicle) -> void:
	if v.locked:
		return
	stealing = true
	hud.start_hotwire(v, Callable(self, "_on_hotwire_result"))

func _on_hotwire_result(v: Vehicle, success: bool) -> void:
	stealing = false
	if not success:
		hud.toast("IT WILL NOT CATCH", "The door is open at least. Try again.")
		return
	v.hotwire()
	GameState.add_theft_xp(1 + int(v.data.tier))
	GameState.stats.stolen += 1
	hud.toast("VEHICLE ACQUIRED", "%s - est. $%d - condition %d%%" % [
		v.data.name, v.estimated_value(), int(v.condition * 100.0)])
	enter_vehicle(v)
	var chance: float = 0.35 + 0.18 * float(v.data.tier)
	if randf() < chance:
		GameState.set_wanted(maxi(1, int(v.data.heat) - 1))
		get_tree().call_group("police_dispatch", "dispatch")

func _breakin_noise(v: Vehicle) -> void:
	if v.failed_attempts >= 2 or randf() < 0.3:
		GameState.raise_wanted(1)
		get_tree().call_group("police_dispatch", "dispatch")

func enter_vehicle(v: Vehicle) -> void:
	if v.locked or v.is_job:
		return
	if not v.hotwired:
		hud.toast("NO KEYS", "It is open, but it will not start. Hotwire it. [E]")
		return
	if carrying:
		hud.toast("BOTH HANDS FULL", "Put the %s down first. [G]" % carrying.part_name)
		return
	if v is Truck and GameState.truck_impounded:
		GameState.release_truck()
		hud.toast("OUT OF THE POUND", "Drive it off before anybody looks up.")
	current_vehicle = v
	# the engine you can hear from the driver's seat, kept alive on the car and
	# pitched by how hard it is working
	if _engine != null and is_instance_valid(_engine):
		_engine.queue_free()
	_engine = Sfx.loop_on(v.sound_set() + "_drive", v, -14.0)
	v.driver = self
	# you stay visible: sat behind the wheel of it, where anybody outside can
	# see exactly who is driving
	_rig.sit()
	_seat_body()
	$Collider.disabled = true
	hud.set_prompt("[F] Get out   [W/A/S/D] Drive   [Space] Handbrake")

## The engine you are sat behind, rising and falling with the throttle.
func _engine_note() -> void:
	if _engine == null or not is_instance_valid(_engine) or current_vehicle == null:
		return
	var top: float = maxf(1.0, float(current_vehicle.data.get("top_speed", 20.0)))
	var t: float = clampf(absf(current_vehicle.speed) / top, 0.0, 1.0)
	_engine.pitch_scale = 0.72 + 0.75 * t
	_engine.volume_db = lerpf(-16.0, -4.0, t)

func exit_vehicle() -> void:
	aiming_down = false
	if _engine != null and is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	if current_vehicle != null:
		Sfx.play("car_stop", current_vehicle.global_position, -3.0)
	if current_vehicle == null:
		return
	var v := current_vehicle
	v.driver = null
	v.speed = 0.0
	current_vehicle = null
	body_mesh.position = Vector3.ZERO
	body_mesh.scale = Vector3.ONE
	body_mesh.visible = true
	$Collider.disabled = false
	# out of the driver's door, which is on the left
	global_position = v.global_position - v.global_transform.basis.x * 2.2 + Vector3.UP * 1.0
	# left on a ramp in your own shop, this is where it becomes a job
	var w := get_tree().get_first_node_in_group("world") as World
	if w != null and not v.is_job and not v.locked:
		w.take_in_from_bay(v)

func open_dismantle(v: Vehicle) -> void:
	hud.open_dismantle(v)

# ------------------------------------------------------------
#  Getting caught
# ------------------------------------------------------------
## They have to get their hands on you first, and then it takes them a moment.
## Close enough to be grabbed is arm's length, not across the road, and the bar
## runs down again if you get away from them before it fills.
const ARREST_RANGE := 2.2
const ARREST_SECS := 2.5

func _check_busted(delta: float) -> void:
	if GameState.wanted == 0:
		if _busted_timer > 0.0:
			hud.show_arrest(-1.0)
		_busted_timer = 0.0
		return
	var close := false
	for p in get_tree().get_nodes_in_group("police"):
		if global_position.distance_to((p as Node3D).global_position) < ARREST_RANGE:
			close = true
			break
	if close and (current_vehicle == null or absf(current_vehicle.speed) < 4.0):
		_busted_timer += delta
		if _busted_timer > ARREST_SECS:
			_busted_timer = 0.0
			hud.show_arrest(-1.0)
			_get_busted()
			return
	else:
		_busted_timer = maxf(0.0, _busted_timer - delta * 1.6)
	hud.show_arrest(_busted_timer / ARREST_SECS if _busted_timer > 0.01 else -1.0)

## Whatever you were driving when they got you. Somebody else's car is gone for
## good; your own truck goes to the pound with the load still in the back, and
## you can pay the fee or go and take it back.
func _lose_ride() -> String:
	if current_vehicle == null:
		return ""
	var v := current_vehicle
	var name := String(v.data.get("name", "car"))
	exit_vehicle()
	if v is Truck:
		var w := get_tree().get_first_node_in_group("world") as World
		if w:
			w.impound_truck(v as Truck)
			return "%s -- it is in the city pound now" % name
	v.queue_free()
	return name

func _get_busted() -> void:
	# Whatever you were in the middle of is over. The rig has a camera of its
	# own and a hold on a car that is about to be towed away, and leaving it
	# running strands you in a minigame with no way out of it.
	var caught_at: Vehicle = hud.cancel_minigame()
	stealing = false
	hud.close_panel()
	var fine := int(min(GameState.money, 250))
	var lost := _lose_ride()
	# the car you were halfway into goes with them, unless it is one of yours
	# sat on a ramp in your own shop
	if caught_at != null and is_instance_valid(caught_at) and not caught_at.is_job:
		if lost == "":
			lost = String(caught_at.data.get("name", "car"))
		caught_at.queue_free()
	GameState.add_money(-fine)
	GameState.stats.busted += 1
	GameState.set_wanted(0)
	get_tree().call_group("police_dispatch", "clear_pursuit")
	var garage: Node3D = get_tree().get_first_node_in_group("garage_spawn")
	if garage:
		global_position = garage.global_position
	hud.toast("BUSTED", ("They took the %s. " % lost if lost != "" else "") + "Fine: $%d." % fine)


# ------------------------------------------------------------
#  Carrying parts around the yard
# ------------------------------------------------------------
func pick_up(item: PartItem) -> void:
	if item.damaged:
		hud.toast("NOT WORTH IT", "The %s is wrecked. Leave it." % item.part_name)
		return
	if carrying:
		hud.toast("ONE AT A TIME", "You are already lugging the %s about." % carrying.part_name)
		return
	carrying = item
	item.set_carried(true)
	item.get_parent().remove_child(item)
	hold.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	# the size it came off the car. A door shrunk to a third looks like a toy
	# of a door, and you are meant to be lugging the real thing about.
	item.scale = Vector3.ONE

## Take whatever is in hand and put it on the ground in front of you.
func drop_carried() -> void:
	if carrying == null:
		return
	var item := carrying
	carrying = null
	var here := global_position - pivot.global_transform.basis.z * 1.6
	hold.remove_child(item)
	get_tree().current_scene.add_child(item)
	item.scale = Vector3.ONE
	item.global_position = Vector3(here.x, _ground_y(here) + 0.35, here.z)
	item.rotation = Vector3(0, _yaw, 0)
	item.set_carried(false)

func load_into_truck(truck: Truck) -> void:
	if carrying == null:
		return
	var name := carrying.part_name
	if not truck.can_take(carrying):
		hud.toast("NO ROOM", "The %s will not take the %s." % [truck.data.name, name])
		return
	var item := carrying
	carrying = null
	hold.remove_child(item)
	truck.load_part(item)
	hud.toast("LOADED", "%s in the back. %d/%d" % [name, truck.used(), truck.capacity()])

func _ground_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at - Vector3.DOWN * -6.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if hit.has("position") else 0.0


# ------------------------------------------------------------
#  The pistol
# ------------------------------------------------------------
func _tick_gun(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_hurt_lull = maxf(0.0, _hurt_lull - delta)
	if _reloading > 0.0:
		_reloading -= delta
		if _reloading <= 0.0:
			GameState.ammo = int(GameState.held_weapon().get("clip", 0))
			hud.toast("RELOADED", "%d in the clip." % GameState.ammo)
	# you patch yourself up once nobody has hit you for a while
	if _hurt_lull <= 0.0 and GameState.health < 100:
		GameState.set_health(GameState.health + int(ceil(delta * 4.0)))

## Whatever is in your hand decides what the left button does.
func _use_held() -> void:
	match String(GameState.held_item().get("kind", "")):
		"gun":
			_shoot()
		"melee":
			_swing()
		"theft":
			hud.set_prompt("Find a car and press [E].")
		"tool":
			hud.set_prompt("Something to strip a car with, not to wave about.")
		"torch":
			hud.set_prompt("It is already on. That is rather the problem with it.")

## The tire iron. Short reach, no noise, and it still counts as going for them.
func _swing() -> void:
	if _cooldown > 0.0:
		return
	var item: Dictionary = GameState.held_item()
	_cooldown = float(item.rate)
	_rig.swipe()
	# swinging turns you into it, or you end up hitting things behind your back
	body_mesh.rotation.y = _yaw + PI
	var cam := arm.get_child(0) as Camera3D
	var aim: Vector3 = -cam.global_transform.basis.z
	var best: Node = null
	var best_d := float(item.range)
	for n in get_tree().get_nodes_in_group("shootable"):
		if n == self or not (n is Node3D):
			continue
		var to: Vector3 = (n as Node3D).global_position - global_position
		var d := to.length()
		if d > best_d or to.normalized().dot(aim) < 0.5:
			continue
		best_d = d
		best = n
	if best == null:
		return
	if best.has_method("take_damage"):
		best.take_damage(int(item.damage), self)
	# a car takes it in the panel you hit, and whoever is sat in it does not
	# hang about to see what you do next
	var car := best as Vehicle
	if car != null and is_instance_valid(car):
		car.hurt_from(global_position, float(item.damage) * 0.006)
		Sfx.play("car_door_close", car.global_position, -2.0)
		if car.has_occupant():
			if car.has_method("bolt"):
				car.bolt()
			hud.toast("THEY PANICKED", "%s is gone, and everybody saw that."
				% String(car.data.get("name", "The car")))
			GameState.raise_wanted(1)
	if best is Node3D and best is CharacterBody3D:
		var shove: Vector3 = ((best as Node3D).global_position - global_position).normalized()
		(best as Node3D).global_position += shove * 0.35

func _shoot() -> void:
	var gun := GameState.held_weapon()
	if gun.is_empty() or _cooldown > 0.0 or _reloading > 0.0:
		return
	if GameState.ammo <= 0:
		hud.set_prompt("Empty. [R] to reload.")
		return
	GameState.ammo -= 1
	_cooldown = float(gun.rate)
	var cam := arm.get_child(0) as Camera3D
	var origin: Vector3 = cam.global_position
	var aim: Vector3 = -cam.global_transform.basis.z
	# traced from the camera so it lands on the crosshair, but drawn from the
	# hand so the tracer comes off the gun rather than out of your eyeballs
	var muzzle := global_position + Vector3.UP * 1.25 + aim * 0.7
	Gunplay.flash(self, muzzle)
	# your own bonnet should not stop your own bullets
	# a sawn-off throws a handful of pellets, everything else throws one round
	var hit: Node = null
	for _p in maxi(1, int(gun.get("pellets", 1))):
		var one := Gunplay.fire(self, origin, aim, gun, float(gun.spread), [current_vehicle], muzzle)
		if one != null:
			hit = one
	if hit and (hit.is_in_group("police") or hit.is_in_group("police_foot")):
		GameState.note_shot_a_copper()
		get_tree().call_group("police_dispatch", "dispatch")
	GameState.health_changed.emit(GameState.health)

func _reload() -> void:
	var gun := GameState.held_weapon()
	if gun.is_empty() or _reloading > 0.0:
		return
	if GameState.ammo >= int(gun.clip):
		return
	_reloading = float(gun.reload)
	hud.set_prompt("Reloading...")

# ------------------------------------------------------------
#  Taking one
# ------------------------------------------------------------
func take_damage(amount: int, _from: Node) -> void:
	GameState.set_health(GameState.health - amount)
	_hurt_lull = 6.0
	if GameState.health <= 0:
		_go_down()

func _go_down() -> void:
	var fine := int(min(GameState.money, 400))
	var lost := _lose_ride()
	GameState.add_money(-fine)
	GameState.stats.hospital += 1
	GameState.set_health(100)
	GameState.set_wanted(0)
	get_tree().call_group("police_dispatch", "clear_pursuit")
	var garage: Node3D = get_tree().get_first_node_in_group("garage_spawn")
	if garage:
		global_position = garage.global_position
	hud.toast("YOU WAKE UP IN A CORRIDOR",
		("They kept the %s. " % lost if lost != "" else "") + "Medical bill: $%d." % fine)
