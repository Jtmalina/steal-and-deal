extends Pedestrian
class_name PoliceOfficer
# ============================================================
#  On foot. Either walking a beat, or out of a cruiser and
#  coming for you because you have stopped moving.
# ============================================================

enum Mode { BEAT, PURSUE, RETURN }

const RUN := 5.6
## A beat copper who gets this close to a wanted player joins in -- on foot,
## whether or not a car ever turns up.
const NOTICE := 38.0
## And this far, if they can actually see you at it.
const SIGHT := 30.0
## How wide their attention is, either side of the way they are facing.
const CONE := 1.1

var mode: int = Mode.BEAT
var target: Node3D = null
var car: PoliceCar = null
var _trigger: float = 0.0
var _down: bool = false
var _torch: SpotLight3D = null

func _ready() -> void:
	super()
	remove_from_group("pedestrian")
	add_to_group("police_foot")
	add_to_group("shootable")
	health = 60          # they take a bit more stopping than a passer-by
	_set_pursuing(false)

func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = outfit_seed
	PersonMesh.build_officer(_body, rng)
	walk_speed = WALK * 1.15

## Only officers actually after you count as police for getting collared.
func _set_pursuing(on: bool) -> void:
	if on and not is_in_group("police"):
		add_to_group("police")
	elif not on and is_in_group("police"):
		remove_from_group("police")

func deploy_from(from_car: PoliceCar, who: Node3D) -> void:
	car = from_car
	target = who
	mode = Mode.PURSUE
	_set_pursuing(true)

func recall() -> void:
	if mode == Mode.PURSUE:
		mode = Mode.RETURN
		_set_pursuing(false)

func _physics_process(delta: float) -> void:
	_check_torch()
	if tumbling:
		_tumble(delta)
		return
	if _down:
		return
	_trigger = maxf(0.0, _trigger - delta)
	match mode:
		Mode.BEAT:
			_beat(delta)
		Mode.PURSUE:
			_chase(delta, target)
		Mode.RETURN:
			_go_back(delta)

## Stood outside the station rather than wandering. They still look up and
## still give chase; they just do not drift off across town while doing it.
var post := Vector3.ZERO

func stand_post(at: Vector3) -> void:
	post = at
	mode = Mode.BEAT

## Walking the beat, until somebody wanted wanders past -- or until they
## look up and catch you with a jimmy down a door.
func _beat(delta: float) -> void:
	# posted officers keep near their spot; the rest walk wherever the
	# pedestrian code takes them
	if post != Vector3.ZERO and global_position.distance_to(post) > 4.0:
		var back := (post - global_position)
		back.y = 0.0
		velocity.x = back.normalized().x * 1.6
		velocity.z = back.normalized().z * 1.6
		move_and_slide()
	else:
		super._physics_process(delta)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var gap: float = global_position.distance_to((player as Node3D).global_position)

	if GameState.wanted > 0 and (gap < NOTICE * GameState.sight_scale() or can_see(player as Node3D)):
		_start_chasing(player, false)
	elif bool(player.get("stealing")) and gap < SIGHT and can_see(player as Node3D):
		_start_chasing(player, true)

func _start_chasing(who: Node, witnessed: bool) -> void:
	target = who as Node3D
	mode = Mode.PURSUE
	_set_pursuing(true)
	if not witnessed:
		return
	GameState.raise_wanted(1)
	get_tree().call_group("police_dispatch", "dispatch")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast("SEEN", "A copper on the corner was watching the whole thing.")

## After dark they work with a torch out. It lights whatever they are facing,
## which is how somebody standing in the beam gets recognised.
func _check_torch() -> void:
	var want: bool = GameState.is_dark() and not _down
	if want and _torch == null:
		_torch = SpotLight3D.new()
		_torch.spot_range = 20.0
		_torch.spot_angle = 30.0
		_torch.light_energy = 2.6
		_torch.light_color = Color(1.0, 0.95, 0.82)
		_torch.position = Vector3(0, 1.45, 0)
		add_child(_torch)
		add_to_group("torch")
		set_meta("torch_reach", 20.0)
	elif not want and _torch != null:
		_torch.queue_free()
		_torch = null
		remove_from_group("torch")
	if _torch and _body:
		var aim: Vector3 = _body.global_transform.basis.z
		_torch.look_at(_torch.global_position + aim, Vector3.UP)
		set_meta("torch_dir", aim)

## Are they in front of us, close enough, and not behind a wall?
func can_see(who: Node3D) -> bool:
	var to: Vector3 = who.global_position - global_position
	to.y = 0.0
	# harder to make out what somebody is doing in the dark
	if to.length() > SIGHT * GameState.sight_scale():
		return false
	var facing: Vector3 = _body.global_transform.basis.z if _body else Vector3.FORWARD
	facing.y = 0.0
	if facing.length() < 0.01 or facing.normalized().angle_to(to.normalized()) > CONE:
		return false
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.6, who.global_position + Vector3.UP * 1.2)
	q.exclude = [get_rid(), who.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _chase(delta: float, who: Node3D) -> void:
	if who == null or not is_instance_valid(who) or GameState.wanted <= 0:
		mode = Mode.RETURN if car else Mode.BEAT
		_set_pursuing(false)
		return
	_take_a_shot(who)
	_run_at(who.global_position, RUN, delta)

## Two stars and up, they will draw. Below that it is still an arrest.
func _take_a_shot(who: Node3D) -> void:
	if GameState.wanted < GameData.SHOOTING_STARS or _trigger > 0.0:
		return
	var gun: Dictionary = GameData.WEAPONS.police_pistol
	var gap := global_position.distance_to(who.global_position)
	if gap > float(gun.range) or gap < 2.0:
		return
	var through := [Gunplay.ride_of(who)]
	if not Gunplay.clear_shot(self, who, 1.5, through):
		return
	_trigger = float(gun.rate)
	var muzzle := global_position + Vector3.UP * 1.4
	var aim: Vector3 = (who.global_position + Vector3.UP * 1.0) - muzzle
	Gunplay.flash(self, muzzle + aim.normalized() * 0.4)
	Gunplay.fire(self, muzzle, aim, gun, float(gun.spread))

## They go over a bonnet the same as anybody, they just keep their own books.
func _come_to_rest() -> void:
	if _down:
		_settle()
	else:
		_get_back_up()

func take_damage(amount: int, from: Node) -> void:
	if _down:
		return
	health -= amount
	if health > 0 and mode == Mode.BEAT and from != null and from.is_in_group("player"):
		_start_chasing(from, true)      # hit a copper and he takes it personally
	if from and from.is_in_group("player"):
		GameState.note_shot_a_copper()
	if health > 0:
		return
	_down = true
	_rig.slump()
	_set_pursuing(false)
	remove_from_group("shootable")
	remove_from_group("police_foot")
	if car and is_instance_valid(car):
		car.officer_aboard(self)
	if not tumbling:
		_settle()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast("OFFICER DOWN", "That is not going to be forgotten.")

## Back to the cruiser, and back in it.
func _go_back(delta: float) -> void:
	if car == null or not is_instance_valid(car):
		mode = Mode.BEAT
		return
	if global_position.distance_to(car.global_position) < 3.0:
		car.officer_aboard(self)
		queue_free()
		return
	_run_at(car.global_position, RUN, delta)

func _run_at(pos: Vector3, speed: float, delta: float) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length() > 0.6:
		var want := to.normalized() * speed
		velocity.x = want.x
		velocity.z = want.z
		if _body:
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(want.x, want.z), 0.25)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -2.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	# arms up when they are drawing on you, swinging otherwise
	_rig.step(delta, Vector2(velocity.x, velocity.z).length(),
		mode == Mode.PURSUE and GameState.wanted >= GameData.SHOOTING_STARS)
