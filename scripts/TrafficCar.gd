extends Vehicle
class_name TrafficCar
# ============================================================
#  An ambient driver. Keeps to the right-hand lane, aims at the
#  junction ahead, stops for red lights and for whatever is in
#  front of it, then picks a new direction and carries on.
#  No pathfinding -- the city is a grid, so following it is
#  three integers and a heading.
# ============================================================

## Ambient traffic runs at a flat speed rather than a fraction of whatever
## it happens to be, so a sports car does not rocket round a housing grid.
const CRUISE_SPEED := 11.0
## Corners are taken slowly. Taking them at cruise throws the car wide across
## the oncoming lane, which is exactly what we are trying not to do.
const TURN_SPEED := 4.0
## Where we aim to come out of a turn: this far down the new lane, measured
## from the middle of the junction.
const EXIT_AHEAD := 5.5
## How far ahead it looks for something to queue behind.
const SCAN := 15.0
## Anything wider than this is in another lane and none of our business.
## Wide enough to still see a car ahead that is sitting at an angle coming out
## of a turn; the oncoming lane is 6.4m away so it stays out of this.
const LANE_WIDTH := 3.0
## Pure-pursuit lookahead. Aiming at the junction itself is too far away to
## correct a lane error with -- the steering angle comes out near zero.
const LOOKAHEAD := 8.0
## Hard brake if anything at all gets this close in front, whatever lane.
const PANIC := 5.5

var dir := Vector3(0, 0, -1)   # cardinal heading
var road_i := 0                # index of the road we are driving along
var from_i := 0                # junction behind us
var to_i := 0                  # junction ahead of us
var _committed := false        # already into the junction, do not stop now
var _next_dir := Vector3.ZERO  # decided on the approach so we can yield first
var stop_reason := ""          # diagnostics: why we are not moving
var patrol := false            # a marked car doing its rounds
var _lightbar: Array[MeshInstance3D] = []
var _blink := 0.0
var _rng := RandomNumberGenerator.new()
## Seconds of driving like somebody just tried to pull them out of it.
var fleeing := 0.0
## Who is at the wheel, when it has to be somebody in particular -- the person
## who just walked up to it and got in. -1 is whoever.
var dress_seed := -1

## A manoeuvre off the grid: in through a gate, into a bay, back out of one.
## Each step is [point, reverse, speed, gate]; `gate`, if valid, has to say yes
## before the car sets off on that step (a gap in the traffic, say).
var _path: Array = []
var _path_then := Callable()
var _path_time := 0.0
## However a manoeuvre goes, it is over after this long: whatever was stuck
## gets put where it was going.
const PATH_GIVE_UP := 45.0

func _ready() -> void:
	super()
	# somebody is driving it, which is what makes it worth taking off them
	# whoever is at the wheel of a marked car is wearing the uniform that goes
	# with it -- a cruiser driven by somebody in a t-shirt reads as a bug
	var who := dress_seed if dress_seed >= 0 else int(global_position.x * 13.0 + global_position.z * 7.0) + 11
	add_occupant(who, patrol)

## Off the lanes and onto a list of points, until the last one, then `then`.
func follow_path(steps: Array, then: Callable = Callable()) -> void:
	_path = steps.duplicate()
	_path_then = then
	_path_time = 0.0
	_next_dir = Vector3.ZERO
	_committed = false

## In a car park or on the way in or out of one, rather than in a lane.
func manoeuvring() -> bool:
	return not _path.is_empty()

func _follow_path(delta: float) -> void:
	_path_time += delta
	if _path_time > PATH_GIVE_UP:
		# wedged somewhere: be where it was going and get on with it
		var last: Array = _path[_path.size() - 1]
		global_position = Vector3((last[0] as Vector3).x, global_position.y, (last[0] as Vector3).z)
		_end_path()
		return
	var step: Array = _path[0]
	var goal: Vector3 = step[0]
	var back: bool = step[1]
	var want: float = step[2] if step.size() > 2 else 3.0
	var gate: Callable = step[3] if step.size() > 3 else Callable()
	stop_reason = "manoeuvre"
	if gate.is_valid() and not bool(gate.call()):
		stop_reason = "gap"
		drive(-1.0 if absf(speed) > 0.4 else 0.0, 0.0, delta, absf(speed) <= 0.4)
		return
	# once it has set off on a step the gate has had its say
	if gate.is_valid():
		step.resize(3)
	var local := global_transform.basis.inverse() * (goal - global_position)
	local.y = 0.0
	var last_step := _path.size() == 1
	if local.length() < (0.7 if last_step else 1.8):
		_path.pop_front()
		if _path.is_empty():
			_end_path()
		return
	# reversing, the tail is what is aimed: point it the way the goal is
	var steer: float
	if back:
		steer = clampf(atan2(local.x, local.z) * 1.8, -1.0, 1.0)
	else:
		steer = clampf(atan2(local.x, -local.z) * 1.8, -1.0, 1.0)
	if last_step:
		want = minf(want, maxf(0.9, local.length() * 0.9))
	# somebody walking through the car park has right of way, and so does
	# anybody stood behind a car that is backing out
	var blocked := not back and (_anything_close() < half_length + 1.2
		or _walker_ahead() < half_length + 1.6)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.get("current_vehicle") == null:
		var to_player := global_transform.basis.inverse() * (player.global_position - global_position)
		if absf(to_player.x) < 2.2 and (to_player.z < 0.0) != back \
				and absf(to_player.z) < half_length + 2.0:
			blocked = true
	if blocked:
		stop_reason = "walker"
		drive(-1.0 if speed > 0.4 else 0.0, steer, delta, speed <= 0.4)
		return
	if back:
		drive(-1.0 if speed > -want else 0.0, steer, delta)
	else:
		drive(_throttle_for(want) if speed < want else 0.0, steer, delta)

func _end_path() -> void:
	_path.clear()
	speed = 0.0
	var then := _path_then
	_path_then = Callable()
	if then.is_valid():
		then.call()

## A carjacking that did not come off. They are through the next set of lights
## whatever colour they are, round anybody in the way, and gone.
func bolt() -> void:
	fleeing = 14.0
	_committed = true

## What a marked car is. A lightbar bolted to whatever civilian shape came out
## of the pool reads as a bug rather than as police, so a patrol car is its own
## vehicle: the same cruiser the dispatcher sends, in the same white.
static func patrol_data() -> Dictionary:
	return PoliceDispatch.COP_DATA.duplicate(true)

## Turn this one into a patrol car: lightbar on the roof, and it will join a
## chase if one comes past.
func make_patrol() -> void:
	patrol = true
	# _ready already put somebody in civvies behind the wheel, because at that
	# point this was just another car. Now that it is a marked one, they change.
	if occupant != null and is_instance_valid(occupant):
		var was := occupant_seed
		occupant.queue_free()
		occupant = null
		add_occupant(was, true)
	var bar := roof_light_point()
	_lightbar.append(_add_box(Vector3(0.5, 0.18, 0.3), Vector3(-bar.x, bar.y, bar.z), Color(1, 0.1, 0.1)))
	_lightbar.append(_add_box(Vector3(0.5, 0.18, 0.3), bar, Color(0.1, 0.3, 1)))
	for l in _lightbar:
		l.visible = false
	if not data.has("model"):
		# a box car needs telling apart; a real cruiser already has its markings
		_add_box(Vector3(1.4, 0.3, 0.06), Vector3(1.02, 0.85, 0.2), Color(0.9, 0.9, 0.92))

func set_route(heading: Vector3, road: int, from_index: int, to_index: int) -> void:
	dir = heading
	road_i = road
	from_i = from_index
	to_i = to_index
	_rng.seed = int(global_position.x * 31.0 + global_position.z * 7.0) + 1

## Is any part of this car sitting on a crossing? Crossings run across every
## road, one pavement's width either side of every junction on it.
func _over_a_crossing() -> bool:
	var reach := half_length + World.CROSS_HALF
	var p := global_position
	for cx: float in World.ROADS:
		for cz: float in World.ROADS:
			if absf(p.x - cx) < World.ROAD_HALF + 1.0 and absf(absf(p.z - cz) - World.PAVE) < reach:
				return true
			if absf(p.z - cz) < World.ROAD_HALF + 1.0 and absf(absf(p.x - cx) - World.PAVE) < reach:
				return true
	return false

## Where the middle of this car has to come to rest for its nose to be short
## of the crossing. A long car has to start pulling up further back.
func _hold_line() -> float:
	return Traffic.HOLD + half_length

## True when we are driving along the X axis.
func _along_x() -> bool:
	return absf(dir.x) > 0.5

## Middle of the junction we are heading for.
func _junction() -> Vector3:
	if _along_x():
		return Vector3(World.ROADS[to_i], 0, World.ROADS[road_i])
	return Vector3(World.ROADS[road_i], 0, World.ROADS[to_i])

## Indices of that junction, for asking its light.
func _junction_index() -> Array:
	if _along_x():
		return [to_i, road_i]
	return [road_i, to_i]

## Our lane: the junction, shifted to the right of the centreline.
func _lane_target() -> Vector3:
	var right := Vector3(-dir.z, 0, dir.x)
	return _junction() + right * Traffic.LANE

## How far we are from our own lane line, sideways.
func _lateral_error() -> float:
	var lane := _lane_target()
	var off: Vector3 = global_position - lane
	return absf(off.z) if _along_x() else absf(off.x)

## Throttle that will settle at roughly this speed.
func _throttle_for(target_speed: float) -> float:
	return clampf(target_speed / maxf(float(data.get("top_speed", 16.0)), 1.0), 0.0, 1.0)

## Where we want to be when we come out of this turn: on the new lane, a few
## metres down the new road.
func _exit_point() -> Vector3:
	var nd := _next_dir
	var nr := Vector3(-nd.z, 0, nd.x)
	return _junction() + nd * EXIT_AHEAD + nr * Traffic.LANE

## Point to actually steer at: the nearest spot on our lane line, a short way
## ahead. Near a junction it collapses onto the junction so we arrive centred.
##
## Turning is different. Chasing a point down the new lane from where we are
## makes the car drive at it in a straight line and sail across the far side of
## the road before hauling itself back. Instead we aim at the exit of the turn
## the whole way through, which draws an arc that lands in the right lane.
func _steer_target() -> Vector3:
	var turning: bool = _next_dir != Vector3.ZERO and _next_dir != dir
	if turning and (_junction() - global_position).dot(dir) < Traffic.BOX:
		return _exit_point()
	var lane := _lane_target()
	var to_junction: float = (_junction() - global_position).dot(dir)
	var on_lane: Vector3 = lane - dir * to_junction     # our position, projected onto the lane
	# Aim closer in when we are well off line, so a car coming out of a turn
	# tucks back into its own lane instead of drifting across the centre.
	var look := clampf(LOOKAHEAD - _lateral_error() * 2.2, 3.6, LOOKAHEAD)
	return on_lane + dir * minf(look, maxf(to_junction, 0.0))

func _physics_process(delta: float) -> void:
	if driver != null or is_job or not locked:
		return                       # somebody stole it, or it is on the ramp
	if not _path.is_empty():
		_follow_path(delta)
		return

	if patrol and _join_the_chase(delta):
		return
	fleeing = maxf(0.0, fleeing - delta)

	var to_junction: float = (_junction() - global_position).dot(dir)

	# decide the turn early, so a left-turner knows to look for oncoming
	if to_junction < 16.0 and _next_dir == Vector3.ZERO:
		_next_dir = _choose_turn()

	# The arc above does the steering; this moves the route on once we get
	# where we were aiming. Going straight that is the middle of the junction.
	# Mid-turn it is the exit -- testing against the junction centre never
	# fires, because the arc curves away from it, and the car orbits forever.
	var turning_now: bool = _next_dir != Vector3.ZERO and _next_dir != dir
	var arrived: bool = global_position.distance_to(_exit_point()) < 2.6 if turning_now 		else to_junction < 1.0
	if arrived:
		_pick_next()
		to_junction = (_junction() - global_position).dot(dir)

	var local := global_transform.basis.inverse() * (_steer_target() - global_position)
	var steer := clampf(atan2(local.x, -local.z) * 1.6, -1.0, 1.0)

	# --- reasons to slow down ---
	var stopping := false
	stop_reason = ""
	var in_box: bool = to_junction < Traffic.BOX and to_junction > -Traffic.BOX

	# The light. Decide at the stop line and stick to it: a car that brakes
	# because the light changed while it was already in the box just blocks
	# the junction for everybody. Once over the line, keep going.
	if to_junction < Traffic.STOP_LINE and to_junction > 0.0:
		if not _committed and fleeing <= 0.0:
			var idx := _junction_index()
			var axis := Traffic.green_axis(idx[0], idx[1])
			var our_turn: bool = axis == ("EW" if _along_x() else "NS")
			# no room left to pull up short of the crossing, so it is going
			# through either way -- better than stamping on it over the stripes
			var cannot_stop: bool = to_junction - _hold_line() < speed * 0.3
			if not our_turn and not cannot_stop:
				stopping = true
				stop_reason = "light"
			# room to get all the way out the far side. A long car needs more of
			# it -- this used to be a flat 13m, tuned when every car was 4.4m.
			elif our_turn and not cannot_stop and _gap_ahead() < half_length + 10.8:
				# green, but the far side is full -- wait at the line rather
				# than pull into the box and strand everybody
				stopping = true
				stop_reason = "no_room"
			else:
				_committed = true
	else:
		_committed = false
	# turning left means crossing the oncoming lane -- wait for a gap
	if _is_left_turn() and to_junction < 7.0 and to_junction > 0.0 and not _committed:
		if _oncoming_blocking(_junction()):
			stopping = true
			stop_reason = "oncoming"

	var ahead := _gap_ahead()

	# Somebody crossing in front of us. The crossing sits just beyond the
	# junction, so inside the box we only stop for one who is right there.
	# measured from the middle of the car, so a longer car has to start
	# further out or its nose gets there first
	if _walker_ahead() < half_length + (1.8 if in_box else 5.3):
		if fleeing > 0.0:
			# not stopping for anybody: swerve round them if there is room
			steer = clampf(steer + _swerve_around_walkers(), -1.0, 1.0)
		else:
			stopping = true
			stop_reason = "walker"

	# something in our lane in front of us
	if ahead < half_length + 4.3 and not in_box:
		stopping = true
		stop_reason = "queue"
	# and a blanket stop for anything close in front, lane or not -- covers
	# cars swinging through a turn and the player wandering about
	# In the box, only an actual imminent bump stops us -- anything else and we
	# would be sitting across everyone else's green.
	if _anything_close() < (2.8 if in_box else PANIC):
		stopping = true
		stop_reason = "panic"

	# slow down for the corner, and stay slow until we have settled back
	# into the new lane rather than powering out across it
	var want := CRUISE_SPEED * (1.8 if fleeing > 0.0 else 1.0)
	if _next_dir != Vector3.ZERO and _next_dir != dir and to_junction < 20.0:
		want = TURN_SPEED
	if _lateral_error() > 1.5:
		want = minf(want, TURN_SPEED + 1.0)
	# Inside the junction we do not stop for a queue, but we do not run into
	# the back of anybody either -- crawl out of the box instead.
	if in_box and (ahead < 9.0 or _anything_close() < 9.0):
		want = minf(want, 2.6)

	# Never come to rest on the stripes. Pulling up for a light happens behind
	# them, but a queue or somebody stepping out can catch a car halfway over
	# one -- in that case keep crawling until it is clear, so long as there is
	# not something solid immediately in front.
	var clearing := false
	if stopping and stop_reason != "panic" and _over_a_crossing() 			and _anything_close() > half_length + 1.6:
		stopping = false
		clearing = true
		want = minf(want, 3.5)

	var throttle := _throttle_for(want)
	# easing off for the queue ahead is what leaves a car creeping across the
	# stripes for seconds at a time -- while it is clearing one it goes at the
	# pace above, and the close-in check keeps it off the car in front
	if ahead < SCAN and not clearing:
		throttle *= clampf((ahead - 6.0) / (SCAN - 6.0), 0.0, 1.0)

	# somebody standing in the road
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.get("current_vehicle") == null and global_position.distance_to(player.global_position) < 7.0:
		stopping = true

	if stopping:
		# Pull up behind the crossing, never on it, and pull up AT it rather
		# than wherever the brakes happened to bite -- a car that stands still
		# ten metres short of a red light looks broken down, not stopped.
		var room := to_junction - _hold_line()
		if room > 0.5 and stop_reason in ["light", "no_room"]:
			var creep := minf(CRUISE_SPEED, room * 1.5)
			drive(_throttle_for(creep) if speed < creep else -1.0, steer, delta)
		else:
			if room > -2.0 and to_junction > 0.0:
				speed = clampf(speed, -1.0, maxf(0.0, room) * 2.2)
			drive(-1.0 if speed > 1.0 else 0.0, steer, delta)
	else:
		drive(throttle, steer, delta)

## Distance to the nearest thing sitting in our lane ahead. Big number if clear.
func _gap_ahead() -> float:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var best := 999.0
	for group in ["vehicle", "police", "truck"]:
		for n in get_tree().get_nodes_in_group(group):
			if n == self or not (n is Node3D):
				continue
			var to: Vector3 = (n as Node3D).global_position - global_position
			var f := to.dot(forward)
			if f <= 0.0 or f > SCAN:
				continue
			if absf(to.dot(right)) > LANE_WIDTH:
				continue          # different lane, not our problem
			best = minf(best, f)
	return best

## Which way to lean to miss whoever is in front. Positive is right.
func _swerve_around_walkers() -> float:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var push := 0.0
	for group in ["pedestrian", "police_foot"]:
		for n in get_tree().get_nodes_in_group(group):
			var to: Vector3 = (n as Node3D).global_position - global_position
			var f := to.dot(forward)
			if f <= 0.0 or f > 12.0:
				continue
			var side := to.dot(right)
			if absf(side) > half_width + 1.4:
				continue
			# go the way there is more room, harder the closer they are
			push += (-1.0 if side > 0.0 else 1.0) * clampf((12.0 - f) / 12.0, 0.0, 1.0)
	return clampf(push, -0.8, 0.8)

## Nearest thing in front of us at all, ignoring lanes.
func _anything_close() -> float:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var best := 999.0
	for group in ["vehicle", "police", "truck"]:
		for n in get_tree().get_nodes_in_group(group):
			if n == self or not (n is Node3D):
				continue
			var to: Vector3 = (n as Node3D).global_position - global_position
			var d := to.length()
			if d > PANIC * 2.0:
				continue
			# straight in front of us, not merely somewhere ahead: a car
			# crossing a junction passes close by and is none of our business
			if to.dot(forward) <= 0.0 or absf(to.dot(right)) > 2.2:
				continue
			best = minf(best, d)
	return best

## Nearest person on foot in our path. They are narrower than a car and we
## want to see them sooner, so they get their own scan.
func _walker_ahead() -> float:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var best := 999.0
	for group in ["pedestrian", "police_foot"]:
		for n in get_tree().get_nodes_in_group(group):
			var to: Vector3 = (n as Node3D).global_position - global_position
			var f := to.dot(forward)
			if f <= 0.0 or f > 13.0:
				continue
			if absf(to.dot(right)) > half_width + 0.9:
				continue
			best = minf(best, f)
	return best

## Is the turn we are about to take a left one, across the oncoming lane?
func _is_left_turn() -> bool:
	if _next_dir == Vector3.ZERO:
		return false
	var left := -Vector3(-dir.z, 0, dir.x)
	return _next_dir.dot(left) > 0.9

## Anything coming the other way that has not cleared the junction yet.
func _oncoming_blocking(junction: Vector3) -> bool:
	for group in ["vehicle", "police", "truck"]:
		for n in get_tree().get_nodes_in_group(group):
			if n == self or not (n is Node3D):
				continue
			var other := n as Node3D
			var to_j: Vector3 = junction - other.global_position
			if to_j.length() > 24.0:
				continue
			var ofwd: Vector3 = -other.global_transform.basis.z
			if ofwd.dot(dir) > -0.7:
				continue              # not coming at us
			if to_j.dot(ofwd) < -2.0:
				continue              # already through
			if n is Vehicle and (n as Vehicle).speed < 0.3 and to_j.length() > 12.0:
				continue              # parked or stopped well back
			return true
	return false

## Mostly carry straight on. Rights are cheap, lefts are rarer because they
## cost everybody time. Never a U-turn, and never off the edge of the map --
## the choice has to be legal here, because the car starts arcing towards the
## exit of this turn well before the route bookkeeping catches up.
func _choose_turn() -> Vector3:
	var right := Vector3(-dir.z, 0, dir.x)
	var options := [dir, right, -right]
	var weights := [0.6, 0.3, 0.1]
	var here_x: int = to_i if _along_x() else road_i
	var here_z: int = road_i if _along_x() else to_i

	var legal := []
	var legal_weight := []
	for i in options.size():
		var d: Vector3 = options[i]
		var nx := here_x + int(d.x)
		var nz := here_z + int(d.z)
		if nx >= 0 and nx < World.ROADS.size() and nz >= 0 and nz < World.ROADS.size():
			legal.append(d)
			legal_weight.append(weights[i])
	if legal.is_empty():
		return -dir            # dead end: the only way out is back

	var total := 0.0
	for wgt in legal_weight:
		total += wgt
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in legal.size():
		acc += legal_weight[i]
		if roll <= acc:
			return legal[i]
	return legal[0]

## Apply the decided turn and work out the next junction along.
func _pick_next() -> void:
	var choice: Vector3 = _next_dir if _next_dir != Vector3.ZERO else _choose_turn()
	_next_dir = Vector3.ZERO

	# the junction we just arrived at becomes where we came from
	var here_x: int = to_i if _along_x() else road_i
	var here_z: int = road_i if _along_x() else to_i
	var nx := here_x + int(choice.x)
	var nz := here_z + int(choice.z)
	if nx < 0 or nx >= World.ROADS.size() or nz < 0 or nz >= World.ROADS.size():
		choice = -dir                 # should not happen, but do not drive off the map
		nx = here_x + int(choice.x)
		nz = here_z + int(choice.z)
		if nx < 0 or nx >= World.ROADS.size() or nz < 0 or nz >= World.ROADS.size():
			return

	dir = choice
	if absf(dir.x) > 0.5:
		road_i = here_z
		from_i = here_x
		to_i = nx
	else:
		road_i = here_x
		from_i = here_z
		to_i = nz
	_committed = false

## A patrol car that finds itself near a wanted player stops being scenery.
func _join_the_chase(delta: float) -> bool:
	_blink += delta
	var player := get_tree().get_first_node_in_group("player")
	# caught in the act by a car on its rounds
	if GameState.wanted <= 0:
		for l in _lightbar:
			l.visible = false
		if player != null and bool(player.get("stealing")) 				and global_position.distance_to((player as Node3D).global_position) < 34.0 * GameState.sight_scale():
			GameState.raise_wanted(1)
			var hud := get_tree().get_first_node_in_group("hud")
			if hud:
				hud.toast("SEEN", "A patrol car went past at exactly the wrong moment.")
		return false
	# Only a car that is actually responding lights up. Blinking every marked
	# car on the map the moment you are wanted somewhere across town put a
	# police bar on the roof of what looks, from the pavement, like an ordinary
	# car minding its own business.
	var near: bool = player != null and global_position.distance_to(
		(player as Node3D).global_position) < 70.0
	var on := int(_blink * 6.0) % 2 == 0
	if _lightbar.size() == 2:
		_lightbar[0].visible = near and on
		_lightbar[1].visible = near and not on
	if not near:
		return false
	for d in get_tree().get_nodes_in_group("police_dispatch"):
		if d.adopt(global_transform):
			queue_free()
			return true
	return false
