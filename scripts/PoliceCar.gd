extends Vehicle
class_name PoliceCar
# ============================================================
#  Dumb but persistent pursuit AI. Drives at you. That's it.
# ============================================================

var target: Node3D = null
var aggression: float = 1.0
var _stuck_time: float = 0.0
var _reverse_time: float = 0.0
var _lightbar: Array[MeshInstance3D] = []
var _blink: float = 0.0
## Two to a car, and that is all there ever is. The car carries a crew; it is
## not a hole that officers climb out of forever. When they are both out and
## the chase needs more bodies, dispatch sends another car.
const CREW := 2
var officer: PoliceOfficer = null       # the one currently on foot, if any
var _out: Array[PoliceOfficer] = []
var _aboard := CREW
var _cornered: float = 0.0
var health: int = 200
var _trigger: float = 0.0
var _wrecked: bool = false
var _siren: AudioStreamPlayer3D = null

func _ready() -> void:
	super()
	remove_from_group("interactable")
	remove_from_group("vehicle")
	add_to_group("police")
	add_to_group("shootable")
	locked = false
	hotwired = true
	if _label:
		_label.text = "PIG WAGON"
	var bar := roof_light_point()
	_lightbar.append(_add_box(Vector3(0.5, 0.18, 0.3), Vector3(-bar.x, bar.y, bar.z), Color(1, 0.1, 0.1)))
	_lightbar.append(_add_box(Vector3(0.5, 0.18, 0.3), bar, Color(0.1, 0.3, 1)))
	# every unit that gets sent has its siren on, and it is the thing that
	# tells you where they are when you cannot see them
	_siren = Sfx.loop_on("siren", self, -9.0)
	# both of them sat in it, in uniform, before either gets out
	var seed_at := int(global_position.x * 17.0 + global_position.z * 5.0)
	add_occupant(seed_at + 3, true)
	add_passenger(seed_at + 8, true)

func _physics_process(delta: float) -> void:
	_blink += delta
	var on := int(_blink * 6.0) % 2 == 0
	if _lightbar.size() == 2:
		_lightbar[0].visible = on
		_lightbar[1].visible = not on

	if target == null or not is_instance_valid(target):
		drive(0.0, 0.0, delta)
		return

	_trigger = maxf(0.0, _trigger - delta)
	_shoot_from_the_window(delta)
	_consider_getting_out(delta)
	if officer != null and is_instance_valid(officer):
		drive(0.0, 0.0, delta)      # parked while its driver is out
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var local := global_transform.basis.inverse() * to
	var steer := clampf(atan2(local.x, -local.z) * 1.6, -1.0, 1.0)
	var throttle := 1.0
	if dist < 6.0:
		throttle = 0.25

	if absf(speed) < 1.0 and dist > 8.0:
		_stuck_time += delta
		if _stuck_time > 1.2:
			_reverse_time = 0.9
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0

	if _reverse_time > 0.0:
		_reverse_time -= delta
		throttle = -1.0
		steer = -steer

	drive(throttle * aggression, steer, delta)


# ------------------------------------------------------------
#  Getting out and getting back in
# ------------------------------------------------------------
## How close we have to be before anyone thinks about opening a door.
const CORNER_RANGE := 15.0
## Their car is doing less than this, so they are not going anywhere.
const STALLED := 1.8
## And this is them getting away again.
const BOLTED := 5.0

func _consider_getting_out(delta: float) -> void:
	var player := target as Node
	var their_car = player.get("current_vehicle") if player else null
	var speed_now: float = absf(their_car.speed) if their_car else 0.0
	var gap := global_position.distance_to((target as Node3D).global_position)

	_out = _out.filter(func(o): return is_instance_valid(o))
	officer = _out[0] if not _out.is_empty() else null
	if not _out.is_empty():
		# moving again, or a gap opened up -- everybody back in the car
		if speed_now > BOLTED or gap > 34.0 or GameState.wanted <= 0:
			for o in _out:
				o.recall()
		return

	var boxed_in := gap < CORNER_RANGE and speed_now < STALLED and GameState.wanted > 0
	if not boxed_in:
		_cornered = 0.0
		return
	_cornered += delta
	if _cornered > 1.1:
		_cornered = 0.0
		_get_out()

## One of them gets out. The other stays put for a beat, so it reads as two
## people making up their minds rather than a door disgorging a crowd.
func _get_out() -> void:
	if _aboard <= 0:
		return
	var driver := _aboard == CREW
	var o := PoliceOfficer.new()
	get_parent().add_child(o)
	var side: float = 1.6 if driver else -1.6
	o.global_position = global_position + global_transform.basis.x * side + Vector3.UP * 0.2
	o.deploy_from(self, target)
	_out.append(o)
	officer = o
	_aboard -= 1
	# the seat they were in is empty now
	if driver:
		set_occupant_visible(false)
	else:
		set_passenger_visible(false)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and _aboard == CREW - 1:
		hud.toast("ON FOOT", "They are out of the car and coming over.")

## One of them made it back to the door and climbed in.
func officer_aboard(who: PoliceOfficer = null) -> void:
	if who != null:
		_out.erase(who)
	elif not _out.is_empty():
		who = _out.pop_front()
	_aboard = mini(CREW, _aboard + 1)
	if _aboard >= CREW:
		set_occupant_visible(true)
		set_passenger_visible(true)
	elif _aboard == CREW - 1:
		set_occupant_visible(true)
	officer = _out[0] if not _out.is_empty() else null

func _exit_tree() -> void:
	for o in _out:
		if is_instance_valid(o):
			o.queue_free()


## They will lean out and fire if you are close and clearly not stopping.
## Pull over and they put it away and come to arrest you instead.
func _shoot_from_the_window(_delta: float) -> void:
	if _wrecked or GameState.wanted < GameData.SHOOTING_STARS or _trigger > 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	var their_car = target.get("current_vehicle")
	var running: bool = their_car == null or absf(their_car.speed) > 2.5
	if not running:
		return                      # pulling over: this is an arrest, not a shooting
	var gap := global_position.distance_to((target as Node3D).global_position)
	if gap > 24.0 or gap < 3.0:
		return
	var through := [Gunplay.ride_of(target)]
	if not Gunplay.clear_shot(self, target as Node3D, 1.2, through):
		return
	var gun: Dictionary = GameData.WEAPONS.police_pistol
	_trigger = float(gun.rate) * 1.3
	var muzzle := global_position + global_transform.basis.x * 1.1 + Vector3.UP * 1.2
	var aim: Vector3 = ((target as Node3D).global_position + Vector3.UP * 0.9) - muzzle
	Gunplay.flash(self, muzzle + aim.normalized() * 0.4)
	Gunplay.fire(self, muzzle, aim, gun, float(gun.spread) * 1.4)

func take_damage(amount: int, from: Node) -> void:
	if _wrecked:
		return
	health -= amount
	if from and from.is_in_group("player"):
		GameState.note_shot_a_copper()
	if health > 0:
		return
	_wrecked = true
	target = null
	remove_from_group("shootable")
	remove_from_group("police")
	speed = 0.0
	if officer != null and is_instance_valid(officer):
		officer.recall()
		officer = null
	var smoke := _add_box(Vector3(0.9, 0.5, 0.9), Vector3(0, 1.5, -1.6), Color(0.25, 0.25, 0.27))
	smoke.material_override.emission_enabled = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast("CRUISER DOWN", "It is not going anywhere. Neither are you, probably.")
