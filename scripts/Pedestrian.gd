extends CharacterBody3D
class_name Pedestrian
# ============================================================
#  Somebody with somewhere to be.
#
#  Their world is the four corners of every junction. From a
#  corner they either walk a pavement down to the next junction
#  or they take a crossing to the corner opposite -- and a
#  crossing only when the traffic coming over it has a red.
#  Nobody steps into the road anywhere else, which is what used
#  to leave them stranded in the middle of it.
# ============================================================

## How far out from the road centreline the pavement runs. Same line the
## crossings are painted on, because that is where the two meet.
const PAVE := World.PAVE
const WALK := 1.7
const GRAVITY := 26.0
## How far away somebody can be and still see you do something dreadful.
const WITNESS_RANGE := 32.0
## How close counts as having got there.
const ARRIVED := 1.0
## Nothing steps out with less than this much of the phase left to cross in.
const NEED_PHASE := 6.0

## Walking a pavement, stood at a kerb, or committed to a crossing.
enum { LEG, WAIT, CROSS }

var dir := Vector3(0, 0, -1)     # which way they are pointing, for the walk cycle
var walk_speed := WALK
## The junction they are walking to, and which of its four corners.
var jx := 0
var jz := 0
var cx := 1
var cz := 1
var _mode := LEG
var _goal := Vector3.ZERO
var _cross_axis := ""            # the axis that has to be green before we step out
var _stuck := 0.0
var _detour := Vector3.ZERO
var _detour_for := 0.0
var _detour_side := 1.0
var _was_at := Vector3.ZERO

var _body: Node3D
var _rig: PersonRig
var _rng := RandomNumberGenerator.new()
## Set this before adding the node to the tree. `_ready` runs on add_child,
## which is before whoever spawned us has had a chance to place us -- seeding
## off the position there gave every single person the same clothes.
var outfit_seed := 0
var health: int = 45
var down: bool = false
## Off their feet and rolling, after something with wheels found them.
var tumbling: bool = false
var _spin := Vector3.ZERO
var _up_in := 0.0
var _hit_lull := 0.0
var _layer := 1
var _was_walker := true
## Set when they have seen something and are getting away from it.
var panic_until: float = 0.0
var panic_from := Vector3.ZERO
## True while stood at a kerb letting something go past. Handy to watch.
var waiting := false

## Drop somebody on a pavement walking `heading` towards junction `to_index`.
## They aim for the near corner of it: the kerb, not the middle of the road.
func setup_route(heading: Vector3, road: int, _from_index: int, to_index: int) -> void:
	dir = heading
	if absf(heading.x) > 0.5:
		jx = to_index
		jz = road
		cx = -1 if heading.x > 0.0 else 1
		cz = 1 if heading.x > 0.0 else -1
	else:
		jx = road
		jz = to_index
		cz = -1 if heading.z > 0.0 else 1
		cx = -1 if heading.z > 0.0 else 1
	_mode = LEG
	_goal = corner(jx, jz, cx, cz)
	_rng.seed = int(global_position.x * 17.0 + global_position.z * 5.0) + 3

## Drop somebody straight onto a corner, already stood on it and heading off
## from there. Spawning them anywhere else and then pointing them at a corner
## sends them across whatever is in between, which is usually a road.
func place_at_corner(ix: int, iz: int, sx: int, sz: int) -> void:
	jx = clampi(ix, 0, World.ROADS.size() - 1)
	jz = clampi(iz, 0, World.ROADS.size() - 1)
	cx = 1 if sx > 0 else -1
	cz = 1 if sz > 0 else -1
	_mode = LEG
	_goal = corner(jx, jz, cx, cz)
	global_position = _goal + Vector3(0, 0.4, 0)
	dir = Vector3(0, 0, -1)
	_rng.seed = int(_goal.x * 17.0 + _goal.z * 5.0) + 3

## Where one corner of a junction is. The pavements meet here and nowhere else.
static func corner(ix: int, iz: int, sx: int, sz: int) -> Vector3:
	return Vector3(World.ROADS[ix] + float(sx) * PAVE, 0.0, World.ROADS[iz] + float(sz) * PAVE)

func _ready() -> void:
	add_to_group("pedestrian")
	add_to_group("shootable")
	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.32
	caps.height = 1.8
	col.shape = caps
	col.position.y = 0.9
	add_child(col)
	_body = Node3D.new()
	add_child(_body)
	_dress()
	_rig = PersonRig.new(_body)
	_layer = collision_layer

func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = outfit_seed
	var kit := PersonMesh.random_civvies(rng)
	PersonMesh.build(_body, kit[0], kit[1], kit[2], kit[3], kit[4])
	walk_speed = WALK * rng.randf_range(0.75, 1.25)

func _physics_process(delta: float) -> void:
	if tumbling:
		_tumble(delta)
		return
	if down:
		return
	_hit_lull = maxf(0.0, _hit_lull - delta)
	# an errand takes priority over the corner graph until it is done
	if errand_until > 0.0 and panic_until <= 0.0:
		errand_until -= delta
		var to := errand - global_position
		to.y = 0.0
		if to.length() > 1.2:
			velocity.x = to.normalized().x * 1.5
			velocity.z = to.normalized().z * 1.5
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 0.2)
			move_and_slide()
			_rig.step(delta, 1.5)
			return
		errand_until = minf(errand_until, 0.8)   # a moment at the door, then off
	# somebody committed to a crossing keeps going: stopping halfway over is
	# how you end up under something
	if _mode != CROSS:
		_dodge_traffic()
		if panic_until > 0.0:
			panic_until -= delta
			_flee(delta)
			return

	var to: Vector3 = _goal - global_position
	to.y = 0.0
	if to.length() < ARRIVED:
		_choose()
		to = _goal - global_position
		to.y = 0.0

	# nobody strolls over a crossing -- they have one phase to get over it
	var pace := maxf(walk_speed * 1.9, 3.6) if _mode == CROSS else walk_speed
	var want := to.normalized() * pace
	if _mode == WAIT:
		want = Vector3.ZERO if not _may_cross() else want
	elif _mode == LEG:
		want *= _pace()
	want = _around_obstacles(want, delta)

	velocity.x = want.x
	velocity.z = want.z
	velocity.y = -2.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if want.length() > 0.1:
		dir = want.normalized()
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(want.x, want.z), 0.15)
	_rig.step(delta, Vector2(velocity.x, velocity.z).length())

# ------------------------------------------------------------
#  Getting about
# ------------------------------------------------------------
## Arrived. Either carry on down a pavement to the next junction, or step off
## the kerb and cross one of the two roads that meet here.
func _choose() -> void:
	if _mode == WAIT:
		return              # still stood at the kerb, the goal is already set
	if _mode == CROSS:
		_mode = LEG         # over the road and onto the far corner
	var moves := []
	var weights := []
	if jx + cx >= 0 and jx + cx < World.ROADS.size():
		moves.append("leg_x")
		weights.append(0.34)
	if jz + cz >= 0 and jz + cz < World.ROADS.size():
		moves.append("leg_z")
		weights.append(0.34)
	# crossing over puts them on the corner opposite, which is how anybody
	# carries straight on past a junction
	moves.append("cross_x")
	weights.append(0.16)
	moves.append("cross_z")
	weights.append(0.16)

	var total := 0.0
	for w in weights:
		total += w
	var roll := _rng.randf() * total
	var pick := String(moves[moves.size() - 1])
	var acc := 0.0
	for i in moves.size():
		acc += weights[i]
		if roll <= acc:
			pick = String(moves[i])
			break

	match pick:
		"leg_x":
			jx += cx
			cx = -cx
			_mode = LEG
		"leg_z":
			jz += cz
			cz = -cz
			_mode = LEG
		"cross_x":
			# walking across X means crossing the road that runs along Z, so
			# the traffic on it -- north-south -- has to be the one stopped
			cx = -cx
			_cross_axis = "EW"
			_mode = WAIT
		"cross_z":
			cz = -cz
			_cross_axis = "NS"
			_mode = WAIT
	_goal = corner(jx, jz, cx, cz)
	waiting = _mode == WAIT

## Is the crossing ours yet? The lights have to be with us, with enough of the
## phase left to get over, and nothing still coming through on the tail of it.
func _may_cross() -> bool:
	if Traffic.green_axis(jx, jz) != _cross_axis:
		return _hold()
	if Traffic.phase_left(jx, jz) < NEED_PHASE:
		return _hold()
	for group in ["vehicle", "police", "truck"]:
		for n in get_tree().get_nodes_in_group(group):
			var car := n as Vehicle
			if car == null or absf(car.speed) < 2.0:
				continue
			var to_us: Vector3 = global_position - car.global_position
			if to_us.length() > 14.0:
				continue
			if (-car.global_transform.basis.z).dot(to_us.normalized()) > 0.7:
				return _hold()      # somebody is jumping it, let them
	waiting = false
	_mode = CROSS
	return true

func _hold() -> bool:
	waiting = true
	return false

## How much of a stride they can take with somebody in the way. Never zero:
## two people walking into each other used to both stop dead and stand there
## for good, because each of them was the thing in front of the other.
func _pace() -> float:
	for n in get_tree().get_nodes_in_group("pedestrian"):
		if n == self:
			continue
		var to: Vector3 = (n as Node3D).global_position - global_position
		if to.length() < 1.3 and to.normalized().dot(dir) > 0.5:
			return 0.22          # a shuffle, and the sidestep takes it from there
	return 1.0

## Walking into something and getting nowhere. Pick a side and go round it.
func _around_obstacles(want: Vector3, delta: float) -> Vector3:
	var moved := global_position.distance_to(_was_at)
	_was_at = global_position
	if want.length() > 0.1 and moved < delta * walk_speed * 0.35:
		_stuck += delta
	else:
		_stuck = maxf(0.0, _stuck - delta * 2.0)
	if _stuck > 0.6 and _detour_for <= 0.0:
		var side := Vector3(-want.z, 0.0, want.x).normalized()
		# alternate, so somebody who is properly wedged tries the other way
		# next time instead of leaning into the same wall again
		_detour_side = -_detour_side
		_detour = side * _detour_side
		_detour_for = 1.3
		_stuck = 0.0
	if _detour_for > 0.0:
		_detour_for -= delta
		# mostly sideways, still leaning the way they were going, and at a
		# proper walk rather than whatever crawl got them stuck
		return (want.normalized() * 0.45 + _detour).normalized() * walk_speed
	return want

## Get away from whatever that was.
func _flee(delta: float) -> void:
	var away := global_position - panic_from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3.FORWARD
	var want := away.normalized() * walk_speed * 2.6
	# somebody running blind still has to get round what they run into, or they
	# spend the whole panic pressed against the side of a parked car
	want = _around_obstacles(want, delta)
	velocity.x = want.x
	velocity.z = want.z
	velocity.y = -2.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if _body:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(want.x, want.z), 0.25)
	_rig.step(delta, Vector2(velocity.x, velocity.z).length())

# ------------------------------------------------------------
#  Getting hit by a car
# ------------------------------------------------------------
## A car coming at us that we can see. Rather than stand there and take it,
## jump sideways out of its path -- which is a panic run across its line.
func _dodge_traffic() -> void:
	if panic_until > 1.2:
		return
	for group in ["vehicle", "police", "truck"]:
		for n in get_tree().get_nodes_in_group(group):
			var car := n as Vehicle
			if car == null or absf(car.speed) < 4.0:
				continue
			var fwd := -car.global_transform.basis.z
			var to_us: Vector3 = global_position - car.global_position
			to_us.y = 0.0
			var ahead := to_us.dot(fwd)
			# only what is bearing down on us: roughly a second and a half of
			# its travel, and near enough its own width to actually connect
			if ahead < 0.5 or ahead > absf(car.speed) * 1.5 + 3.0:
				continue
			var side := to_us.dot(car.global_transform.basis.x)
			if absf(side) > car.half_width + 1.1:
				continue
			# run away from a spot just to one side of us, so the flee goes
			# across the car's path instead of down it
			var away := car.global_transform.basis.x * (1.0 if side < 0.0 else -1.0)
			_scatter(global_position + away * 2.0, 2.2)
			return

## Clipped by something on wheels. How fast it was going decides whether that
## is a limp and a fright or the end of them.
func run_over(car: Vehicle, blame: Node) -> void:
	if down or tumbling or _hit_lull > 0.0:
		return
	_hit_lull = 1.0
	var pace := absf(car.speed)
	var fwd := -car.global_transform.basis.z
	# over the bonnet, not through it: a fast car throws them properly
	knock_down(fwd * (2.2 + pace * 0.6) + Vector3.UP * (2.2 + pace * 0.3))
	take_damage(int(round(pace * 5.5 + randf_range(-3.0, 7.0))), blame)

## Off their feet with `toss` as the velocity they leave at. They keep rolling
## until they stop, and then either get up or they do not.
## Which voice this body speaks with -- tied to the seed that dressed them, so
## the same person always sounds like themselves.
func say(what: String, db: float = -2.0) -> void:
	Sfx.play("voice_%s_%s" % [Sfx.voice_sex(outfit_seed), what], global_position, db)

func knock_down(toss: Vector3) -> void:
	if tumbling:
		return
	say("hit", 0.0)
	tumbling = true
	velocity = toss
	_spin = Vector3(randf_range(-8.0, 8.0), randf_range(-5.0, 5.0), randf_range(-8.0, 8.0))
	_up_in = randf_range(1.4, 2.8)
	_rig.slump()
	# nothing should queue up behind a body in the road, and the car that hit
	# them should carry on over rather than shunt them down the street
	_was_walker = is_in_group("pedestrian")
	remove_from_group("pedestrian")
	collision_layer = 0
	waiting = false

func _tumble(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_body.rotation += _spin * delta
	if not is_on_floor():
		return
	velocity.x = move_toward(velocity.x, 0.0, delta * 16.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 16.0)
	_spin = _spin.move_toward(Vector3.ZERO, delta * 22.0)
	_up_in -= delta
	if _up_in <= 0.0 and Vector2(velocity.x, velocity.z).length() < 0.7:
		_come_to_rest()

## Which way that ended. Split out so a copper can use their own bookkeeping.
func _come_to_rest() -> void:
	if down:
		_settle()
	else:
		_get_back_up()

## Winded, frightened, and off home the other way.
func _get_back_up() -> void:
	tumbling = false
	collision_layer = _layer
	if _was_walker and not is_in_group("pedestrian"):
		add_to_group("pedestrian")
	_body.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	health = maxi(health, 15)
	_scatter(global_position - Vector3(_spin.x, 0, _spin.z), 7.0)

## Face down in the road, and gone a while later.
func _settle() -> void:
	tumbling = false
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(_body, "rotation", Vector3(-PI * 0.5, _body.rotation.y, 0), 0.4)
	tw.tween_interval(8.0)
	tw.tween_callback(queue_free)

func take_damage(amount: int, from: Node) -> void:
	if down:
		return
	health -= amount
	if health > 0:
		say("pain")
		if not tumbling:
			_scatter(global_position if from == null else (from as Node3D).global_position, 6.0)
		return
	say("pain", 2.0)
	down = true
	_rig.slump()
	remove_from_group("shootable")
	remove_from_group("pedestrian")
	if from != null and from.is_in_group("player"):
		_witnessed(from as Node3D)
	# somebody still rolling settles when they stop, not halfway through
	if not tumbling:
		_settle()

## Anybody still on their feet who could see that goes to pieces, and if one of
## them is a copper -- or one of them can find a phone -- the police hear about it.
func _witnessed(killer: Node3D) -> void:
	var seen := false
	for group in ["pedestrian", "police_foot"]:
		for n in get_tree().get_nodes_in_group(group):
			if n == self or not (n is Node3D):
				continue
			var who := n as Node3D
			if who.global_position.distance_to(global_position) > WITNESS_RANGE * GameState.sight_scale():
				continue
			if not Gunplay.clear_shot(who, self, 1.5):
				continue
			seen = true
			if n is Pedestrian:
				(n as Pedestrian)._scatter(global_position, 9.0)
	if not seen:
		return
	GameState.set_wanted(maxi(GameState.wanted + 1, 2))
	get_tree().call_group("police_dispatch", "dispatch")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast("SOMEBODY SAW THAT", "It has been called in.")

## Sent to a front door, in or out of it. Not a real interior -- they walk to
## the doorway, stand a moment, and go back to the pavement -- but from the
## street it reads as people using the buildings rather than circling them.
var errand := Vector3.ZERO
var errand_until := 0.0

func run_errand(door: Vector3, secs: float) -> void:
	if down or tumbling:
		return
	errand = door
	errand_until = secs

func _scatter(from_pos: Vector3, secs: float) -> void:
	if down:
		return
	# only worth a shout if this is news to them
	if panic_until <= 0.0:
		say("shocked", -1.0)
	panic_from = from_pos
	panic_until = maxf(panic_until, secs)
