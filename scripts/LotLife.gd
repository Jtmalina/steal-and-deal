extends Node
class_name LotLife
# ============================================================
#  Somebody using the car parks.
#
#  Every so often, at whichever car park is nearest the player,
#  one of two things happens. A car coming up the road outside
#  turns in at the gate, finds a free bay, noses into it, and
#  whoever was driving gets out and walks off. Or somebody walks
#  in off the pavement to a car already parked, gets in, backs it
#  out and leaves by the other gate.
#
#  Either way the parked car is a real parked car: the one that
#  just pulled in can be stolen, and one you were eyeing up a
#  minute ago can be driven away from under you -- although not
#  one you are stood next to.
# ============================================================

## Seconds between goings-on, at the nearest lot.
const EVERY := Vector2(12.0, 26.0)
## Only a lot the player might see is worth the bother.
const NEAR := 150.0
## Nobody drives off in a car the player is this close to: it may well be the
## one they came for.
const MINE := 14.0
## Whatever is happening at a lot is over after this long, whether or not the
## car or the person in it is still about to say so.
const BUSY_FOR := 70.0

var world: World
## The smoke test turns the dice off and makes things happen when it wants.
var enabled := true
var pulled_in := 0
var pulled_out := 0

var _next := 5.0
var _rng := RandomNumberGenerator.new()
var _busy := {}          # lot centre -> seconds it stays busy

func _ready() -> void:
	_rng.seed = 8080
	world = get_parent() as World

func _process(delta: float) -> void:
	for k in _busy.keys():
		_busy[k] = float(_busy[k]) - delta
		if float(_busy[k]) <= 0.0:
			_busy.erase(k)
	if not enabled or world == null:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = _rng.randf_range(EVERY.x, EVERY.y)
	var plan := _nearest_lot()
	if plan.is_empty():
		return
	if _rng.randf() < 0.5:
		if not pull_in(plan):
			pull_out(plan)
	elif not pull_out(plan):
		pull_in(plan)

func busy(plan: Dictionary) -> bool:
	return _busy.has(str(plan.centre))

func _nearest_lot() -> Dictionary:
	var who := get_tree().get_first_node_in_group("player") as Node3D
	if who == null:
		return {}
	var best := {}
	var near := NEAR
	for plan: Dictionary in world.lots:
		var d := who.global_position.distance_to(plan.centre)
		if d < near and not busy(plan):
			near = d
			best = plan
	return best

# ------------------------------------------------------------
#  In
# ------------------------------------------------------------
## A car in the lane outside turns in and parks. `car` makes it that one
## rather than whichever is coming. False if there is no bay or nobody coming.
func pull_in(plan: Dictionary, car: TrafficCar = null) -> bool:
	if busy(plan):
		return false
	var free := free_bays(plan)
	if free.is_empty():
		return false
	if car == null:
		car = _car_coming(plan)
	if car == null:
		return false
	# the bay nearest the gate is the one anybody takes, give or take
	var e: Vector3 = plan.entry
	free.sort_custom(func(a: Dictionary, b: Dictionary):
		return (a.at as Vector3).distance_to(e) < (b.at as Vector3).distance_to(e))
	var bay: Dictionary = free[mini(_rng.randi_range(0, 1), free.size() - 1)]
	_busy[str(plan.centre)] = BUSY_FOR
	car.follow_path(_in_path(plan, bay), _parked.bind(car, plan, bay))
	return true

## Bays with nothing in them.
func free_bays(plan: Dictionary) -> Array:
	var out := []
	for bay: Dictionary in plan.bays:
		var taken := false
		for n in get_tree().get_nodes_in_group("vehicle"):
			if (n as Node3D).global_position.distance_to(bay.at) < 2.6:
				taken = true
				break
		if not taken:
			out.append(bay)
	return out

## Somebody on the west road, in the lane by the gate, still short of it.
func _car_coming(plan: Dictionary) -> TrafficCar:
	var e: Vector3 = plan.entry
	for n in get_tree().get_nodes_in_group("vehicle"):
		var c := n as TrafficCar
		if c == null or c.patrol or c.manoeuvring() or c.fleeing > 0.0 or c.driver != null or not c.locked:
			continue
		if c.dir.z > -0.5 or c.road_i != int(plan.xi):
			continue
		if absf(c.global_position.x - float(plan.entry_lane)) > 1.6:
			continue
		var short := c.global_position.z - e.z
		if short > 12.0 and short < 45.0:
			return c
	return null

## Up the lane, a right turn over the pavement and in at the gate, down the
## aisle, and a swing into the bay nose first.
func _in_path(plan: Dictionary, bay: Dictionary) -> Array:
	var e: Vector3 = plan.entry
	var ac: float = plan.aisle
	var lane: float = plan.entry_lane
	var at: Vector3 = bay.at
	var r: float = bay.row
	var steps := [
		[Vector3(lane, 0, ac + 6.0), false, 5.0],
		[Vector3(e.x - 1.5, 0, ac + 0.4), false, 3.2],
		[Vector3(e.x + 3.0, 0, ac), false, 3.2],
	]
	if at.x - 4.5 > e.x + 4.0:
		steps.append([Vector3(at.x - 4.5, 0, ac - r * 1.0), false, 3.2])
	steps.append([Vector3(at.x, 0, at.z - r * 4.2), false, 2.2])
	steps.append([at, false, 1.5])
	return steps

## In the bay. The car that drove in becomes the car that is parked there --
## same make, same paint, same knocks -- and the driver gets out and goes.
func _parked(car: TrafficCar, plan: Dictionary, bay: Dictionary) -> void:
	_busy.erase(str(plan.centre))
	if not is_instance_valid(car) or car.driver != null:
		return
	var v := Vehicle.new()
	_same_car(car, v)
	world.add_child(v)
	v.global_position = bay.at
	v.rotation.y = float(bay.yaw)
	v.set_meta("lot_bay", {"lot": plan.centre, "bay": (plan.bays as Array).find(bay), "fixed": true})
	var seed := car.occupant_seed
	car.queue_free()
	pulled_in += 1

	# out of the driver's door, down between the cars, and off up the aisle
	var door := v.global_transform * Vector3(-2.2, 0, -0.3)
	var who := Pedestrian.new()
	who.outfit_seed = seed
	world.add_child(who)
	who.global_position = door + Vector3(0, 0.3, 0)
	var e: Vector3 = plan.entry
	var r: float = bay.row
	var pave := Vector3(e.x - (World.PAVE_BACK - World.PAVE), 0, e.z)
	who.walk_via([
		Vector3(door.x, 0, (bay.at as Vector3).z - r * 4.4),
		Vector3(e.x + 2.0, 0, e.z),
		pave,
	])
	_onto_the_pavement(who, plan)

## Whoever just came out of a car park walks on to one end of that pavement
## or the other, and from there wherever anybody goes.
func _onto_the_pavement(who: Pedestrian, plan: Dictionary) -> void:
	var north := _rng.randf() < 0.5
	who.head_for_corner(int(plan.xi), int(plan.zi) + (0 if north else 1), 1, 1 if north else -1)

# ------------------------------------------------------------
#  Out
# ------------------------------------------------------------
## Somebody walks in off the pavement to a parked car and drives it away. `v`
## makes it that car. False if there is nothing here anybody would take.
func pull_out(plan: Dictionary, v: Vehicle = null) -> bool:
	if busy(plan):
		return false
	if v == null:
		var can := leavers(plan)
		if can.is_empty():
			return false
		v = can[_rng.randi() % can.size()]
	var info: Dictionary = v.get_meta("lot_bay", {})
	var i := int(info.get("bay", -1))
	if i < 0 or i >= (plan.bays as Array).size():
		return false
	var bay: Dictionary = plan.bays[i]
	# they come along the pavement from whichever corner is further from the
	# player, so nobody is seen appearing out of nothing
	var e: Vector3 = plan.entry
	var north := Pedestrian.corner(int(plan.xi), int(plan.zi), 1, 1)
	var south := Pedestrian.corner(int(plan.xi), int(plan.zi) + 1, 1, -1)
	var from := north
	var who_p := get_tree().get_first_node_in_group("player") as Node3D
	if who_p and who_p.global_position.distance_to(south) > who_p.global_position.distance_to(north):
		from = south
	_busy[str(plan.centre)] = BUSY_FOR
	v.set_meta("lot_booked", true)
	var who := Pedestrian.new()
	who.outfit_seed = _rng.randi()
	world.add_child(who)
	who.global_position = from + Vector3(0, 0.3, 0)
	var r: float = bay.row
	var door := v.global_transform * Vector3(-2.2, 0, -0.3)
	who.walk_via([
		Vector3(e.x - (World.PAVE_BACK - World.PAVE), 0, e.z),
		Vector3(e.x + 2.0, 0, e.z),
		Vector3(door.x, 0, (bay.at as Vector3).z - r * 4.4),
		door,
	], _drive_off.bind(v, who, plan, bay))
	return true

## Parked cars in this lot that nobody would mind somebody driving off in:
## locked, whole, nobody in or at them, and not the one the player is next to.
func leavers(plan: Dictionary) -> Array:
	var out := []
	var who := get_tree().get_first_node_in_group("player") as Node3D
	for n in get_tree().get_nodes_in_group("vehicle"):
		var v := n as Vehicle
		if v == null or v is TrafficCar or not v.has_meta("lot_bay"):
			continue
		if (v.get_meta("lot_bay") as Dictionary).get("lot") != plan.centre:
			continue
		if v.driver != null or v.is_job or v.lifted or not v.locked or v.hotwired:
			continue
		if v.has_meta("lot_booked") or not v._dents.is_empty():
			continue
		if v.parts_remaining.size() < (v.data.get("parts", []) as Array).size():
			continue
		if who and v.global_position.distance_to(who.global_position) < MINE:
			continue
		out.append(v)
	return out

## At the door. If the car is still there and still theirs to take, they get
## in: the parked car becomes a driven one with them at the wheel, which backs
## out, goes down the aisle and out of the far gate into the traffic.
func _drive_off(v: Vehicle, who: Pedestrian, plan: Dictionary, bay: Dictionary) -> void:
	var still := is_instance_valid(v) and v.driver == null and v.locked and not v.hotwired \
		and not v.is_job and not v.lifted
	if not is_instance_valid(who) or who.down:
		still = false
	if not still:
		# somebody got there first. Off they go again.
		_busy.erase(str(plan.centre))
		if is_instance_valid(v):
			v.remove_meta("lot_booked")
		if is_instance_valid(who) and not who.down:
			_onto_the_pavement(who, plan)
		return
	var car := TrafficCar.new()
	_same_car(v, car)
	car.dress_seed = who.outfit_seed
	var at := v.global_transform
	v.queue_free()
	who.queue_free()
	world.add_child(car)
	car.global_transform = at
	if car.has_door("door_l"):
		car.open_door("door_l")
		get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(car):
				car.close_door("door_l"))
	# where it goes once it is out: up the road past the east gate
	car.set_route(Vector3(0, 0, 1), int(plan.xi) + 1, int(plan.zi), int(plan.zi) + 1)
	car.follow_path(_out_path(plan, bay, car), _gone.bind(plan))

## Straight back out of the bay, swinging the tail west so the nose comes round
## east, down the aisle, out of the gate, a wait at the kerb for a gap, and a
## right turn into the lane.
func _out_path(plan: Dictionary, bay: Dictionary, car: TrafficCar) -> Array:
	var at: Vector3 = bay.at
	var r: float = bay.row
	var ac: float = plan.aisle
	var x: Vector3 = plan.exit
	var lane: float = plan.exit_lane
	return [
		# a moment to get settled in before anything moves
		[at, false, 0.5, _after.bind(Time.get_ticks_msec() + 1800)],
		[Vector3(at.x, 0, at.z - r * 3.0), true, 1.8],
		[Vector3(at.x - 3.2, 0, at.z - r * 7.2), true, 1.8],
		[Vector3(at.x + 5.0, 0, ac), false, 3.0],
		[Vector3(x.x - 2.5, 0, ac), false, 3.0],
		[Vector3(x.x + 3.2, 0, ac), false, 2.0],
		[Vector3(lane, 0, ac + 6.0), false, 4.0, _gap.bind(plan, car)],
		[Vector3(lane, 0, ac + 10.0), false, 7.0],
	]

func _after(when: int) -> bool:
	return Time.get_ticks_msec() >= when

## Nothing coming up the lane it is about to pull out into.
func _gap(plan: Dictionary, car: TrafficCar) -> bool:
	var lane: float = plan.exit_lane
	var ac: float = plan.aisle
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n == car:
			continue
		var p := (n as Node3D).global_position
		if absf(p.x - lane) < 2.6 and p.z > ac - 28.0 and p.z < ac + 9.0:
			return false
	return true

func _gone(plan: Dictionary) -> void:
	_busy.erase(str(plan.centre))
	pulled_out += 1

## Make `to` the same car as `from`: the make, the paint, the wear.
static func _same_car(from: Vehicle, to: Vehicle) -> void:
	var paint: Color = from.data.get("color", from._paint_base)
	to.setup(from.data.duplicate(true))
	to.data["color"] = paint
	to._paint_base = paint
	to.condition = from.condition
