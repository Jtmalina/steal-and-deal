extends Node3D
class_name Traffic
# ============================================================
#  Road network rules for the ambient cars.
#
#  The city is a grid, so we do not need a navmesh: every road
#  is a centreline at one of World.ROADS, and every car is on a
#  lane offset to the RIGHT of that line for the way it is
#  facing -- US rules, drive on the right. Junctions run on a
#  shared clock so cars can be told when to stop.
# ============================================================

## Half the gap between the two directions of travel.
const LANE := 3.2
## How far out a car starts thinking about the light. It has to be far enough
## back to pull up before the crossing from cruising speed.
const STOP_LINE := 22.0
## And where its NOSE has to stop: short of the crossing, never on it. Cars
## measure everything from their middle, so each one adds its own half-length.
const HOLD := World.PAVE + World.CROSS_HALF + 0.4
## Half the width of the carriageway, so: where the junction box begins.
const BOX := 6.8

## Long enough that somebody on foot can get over a crossing inside one phase.
const CYCLE := 24.0
const NS_GREEN := 10.5
const GAP := 1.5          # everything red while the junction clears

var _ns_lamps := []       # [[red, amber, green], ...] for each phase group
var _ew_lamps := []
var _last_state := ["", ""]
var _next_census := 4.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("traffic_control")
	_ns_lamps = [[], []]
	_ew_lamps = [[], []]
	_build_lights()
	_spawn_cars()
	_spawn_people()

# ------------------------------------------------------------
#  The clock
# ------------------------------------------------------------
static func now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## Which axis has a green at this junction: "NS", "EW", or "" for all-red.
## Neighbouring junctions run half a cycle apart, which gives the grid a
## rolling green rather than the whole city changing at once.
static func green_axis(ix: int, iz: int, t: float = -1.0) -> String:
	var time := t if t >= 0.0 else now()
	var offset := 0.0 if (ix + iz) % 2 == 0 else CYCLE * 0.5
	var phase := fmod(time + offset, CYCLE)
	if phase < NS_GREEN:
		return "NS"
	if phase < NS_GREEN + GAP:
		return ""
	if phase < CYCLE - GAP:
		return "EW"
	return ""

## Lamp to light for one axis: 0 red, 1 amber, 2 green. Amber shows only on
## the axis that is losing its green, the way a real head does.
static func lamp_for(axis: String, ix: int, iz: int, t: float = -1.0) -> int:
	var time := t if t >= 0.0 else now()
	var offset := 0.0 if (ix + iz) % 2 == 0 else CYCLE * 0.5
	var phase := fmod(time + offset, CYCLE)
	if phase < NS_GREEN:
		return 2 if axis == "NS" else 0
	if phase < NS_GREEN + GAP:
		return 1 if axis == "NS" else 0
	if phase < CYCLE - GAP:
		return 2 if axis == "EW" else 0
	return 1 if axis == "EW" else 0

## Seconds left of whatever this junction is doing now. Somebody on foot uses
## it to decide whether there is time to get across before it changes.
static func phase_left(ix: int, iz: int, t: float = -1.0) -> float:
	var time := t if t >= 0.0 else now()
	var offset := 0.0 if (ix + iz) % 2 == 0 else CYCLE * 0.5
	var phase := fmod(time + offset, CYCLE)
	if phase < NS_GREEN:
		return NS_GREEN - phase
	if phase < NS_GREEN + GAP:
		return NS_GREEN + GAP - phase
	if phase < CYCLE - GAP:
		return CYCLE - GAP - phase
	return CYCLE - phase

static func phase_group(ix: int, iz: int) -> int:
	return 0 if (ix + iz) % 2 == 0 else 1

# ------------------------------------------------------------
#  Signals on posts
# ------------------------------------------------------------
func _build_lights() -> void:
	for ix in World.ROADS.size():
		for iz in World.ROADS.size():
			var centre := Vector3(World.ROADS[ix], 0, World.ROADS[iz])
			var group := phase_group(ix, iz)
			# one head for each axis of approach, on opposite corners
			# just off the back of the pavement, clear of the parked cars
			var post := World.PAVE + 1.5
			_ns_lamps[group].append(_pole(centre + Vector3(post, 0, post), PI * 0.5))
			_ew_lamps[group].append(_pole(centre + Vector3(-post, 0, post), 0.0))

## Post plus a three-lamp head. Returns [red, amber, green].
func _pole(pos: Vector3, yaw: float) -> Array:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	_box(root, Vector3(0.18, 4.2, 0.18), Vector3(0, 2.1, 0), Color(0.25, 0.25, 0.27))
	_box(root, Vector3(0.5, 1.35, 0.35), Vector3(0, 4.35, 0), Color(0.15, 0.15, 0.16))
	var lamps := []
	var cols := [Color(0.8, 0.12, 0.1), Color(0.9, 0.7, 0.1), Color(0.15, 0.85, 0.25)]
	for i in 3:
		lamps.append(_box(root, Vector3(0.28, 0.28, 0.12), Vector3(0, 4.78 - 0.42 * float(i), 0.2), cols[i]))
	return lamps

func _box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.15
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## How many people should be out at this hour, and how many of them are on the
## job. The pavements empty after dark and the beat gets heavier.
func _wanted_walkers() -> int:
	return int(round(lerpf(7.0, 22.0, GameState.daylight())))

func _wanted_officers() -> int:
	return int(round(lerpf(7.0, 3.0, GameState.daylight())))

## Keep the street population near those numbers without ever doing it in front
## of the player: anybody removed is the furthest away, anybody added arrives
## somewhere they cannot be seen appearing.
func _repopulate() -> void:
	var who := get_tree().get_first_node_in_group("player") as Node3D
	if who == null:
		return
	_top_up(get_tree().get_nodes_in_group("pedestrian"), _wanted_walkers(), false, who)
	_top_up(get_tree().get_nodes_in_group("police_foot"), _wanted_officers(), true, who)

func _top_up(crowd: Array, want: int, officer: bool, who: Node3D) -> void:
	if crowd.size() > want:
		var worst: Node3D = null
		var far := 0.0
		for n in crowd:
			var body := n as Node3D
			if body == null or (body as Pedestrian).down:
				continue
			var d := body.global_position.distance_to(who.global_position)
			if d > far and d > 90.0:
				far = d
				worst = body
		if worst:
			worst.queue_free()
		return
	if crowd.size() >= want:
		return
	var world := get_parent() as World
	if world == null:
		return
	# a corner a long way off, so nobody watches them turn up
	for attempt in 8:
		var at := Pedestrian.corner(_rng.randi_range(0, World.ROADS.size() - 1),
			_rng.randi_range(0, World.ROADS.size() - 1),
			1 if _rng.randf() < 0.5 else -1, 1 if _rng.randf() < 0.5 else -1)
		if at.distance_to(who.global_position) < 85.0:
			continue
		world.spawn_walker(at, officer)
		return

func _process(delta: float) -> void:
	_next_census -= delta
	if _next_census <= 0.0:
		_next_census = 3.0
		_repopulate()
	var t := now()
	for group in 2:
		var ix := 0 if group == 0 else 1
		var ns := lamp_for("NS", ix, 0, t)
		var ew := lamp_for("EW", ix, 0, t)
		var state := "%d%d" % [ns, ew]
		if state == _last_state[group]:
			continue
		_last_state[group] = state
		_light(_ns_lamps[group], ns)
		_light(_ew_lamps[group], ew)

func _light(poles: Array, on: int) -> void:
	for lamps in poles:
		for i in 3:
			var mat: StandardMaterial3D = lamps[i].material_override
			mat.emission_energy_multiplier = 1.6 if i == (2 - on) else 0.06

# ------------------------------------------------------------
#  Populating the roads
# ------------------------------------------------------------
func _spawn_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var dirs := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	var placed := []
	var world := get_parent() as World

	for attempt in 120:
		if placed.size() >= 16:
			break
		var dir: Vector3 = dirs[rng.randi() % 4]
		var along := absf(dir.x) > 0.5
		# pick the road we sit on, and which junction we are heading to
		var road_i := rng.randi_range(0, World.ROADS.size() - 1)
		var from_i := rng.randi_range(0, World.ROADS.size() - 2)
		var step := 1 if (dir.x > 0.0 or dir.z > 0.0) else -1
		var to_i := from_i + step
		if to_i < 0 or to_i >= World.ROADS.size():
			continue

		var right := Vector3(-dir.z, 0, dir.x)
		var base: Vector3
		if along:
			base = Vector3(World.ROADS[from_i], 0, World.ROADS[road_i])
		else:
			base = Vector3(World.ROADS[road_i], 0, World.ROADS[from_i])
		var pos := base + dir * rng.randf_range(6.0, 30.0) + right * LANE
		pos.y = 0.7

		if pos.distance_to(World.GARAGE_POS) < 24.0:
			continue
		var clear := true
		for other in placed:
			if pos.distance_to(other) < 16.0:
				clear = false
				break
		if not clear:
			continue
		placed.append(pos)

		# roughly one car in five is a marked patrol doing its rounds, and it
		# turns up in a cruiser rather than in somebody's saloon
		var on_patrol := rng.randf() < 0.2
		var car := TrafficCar.new()
		car.setup(TrafficCar.patrol_data() if on_patrol
			else world._pick_vehicle_def(rng, pos).duplicate(true))
		add_child(car)
		car.global_position = pos
		car.look_at(pos + dir, Vector3.UP)
		car.set_route(dir, road_i, from_i, to_i)
		if on_patrol:
			car.make_patrol()


## People on the pavements, including a few coppers walking a beat.
func _spawn_people() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181
	# a stream of its own for clothes: drawing them from `rng` would shift who
	# comes out a copper, and seeding off a counter makes everyone dress alike
	var wardrobe := RandomNumberGenerator.new()
	wardrobe.seed = 5150
	var dirs := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	var placed := 0
	for attempt in 160:
		if placed >= 22:
			break
		var dir: Vector3 = dirs[rng.randi() % 4]
		var road_i := rng.randi_range(0, World.ROADS.size() - 1)
		var from_i := rng.randi_range(0, World.ROADS.size() - 2)
		var step := 1 if (dir.x > 0.0 or dir.z > 0.0) else -1
		var to_i := from_i + step
		if to_i < 0 or to_i >= World.ROADS.size():
			continue

		var right := Vector3(-dir.z, 0, dir.x)
		var base: Vector3
		if absf(dir.x) > 0.5:
			base = Vector3(World.ROADS[from_i], 0, World.ROADS[road_i])
		else:
			base = Vector3(World.ROADS[road_i], 0, World.ROADS[from_i])
		var pos := base + dir * rng.randf_range(12.0, 34.0) + right * Pedestrian.PAVE
		pos.y = 0.2
		if pos.distance_to(World.GARAGE_POS) < 20.0:
			continue

		# one in five on the pavement is on the job
		var who: Pedestrian = PoliceOfficer.new() if rng.randf() < 0.16 else Pedestrian.new()
		# a seed of its own, so picking outfits does not shuffle who is a copper
		who.outfit_seed = wardrobe.randi()     # before add_child: _ready dresses them
		add_child(who)
		who.global_position = pos
		who.setup_route(dir, road_i, from_i, to_i)
		# roughly one in five is on their way somewhere rather than nowhere:
		# to a shop door, the school gate, the pub
		var w := get_tree().get_first_node_in_group("world") as World
		if w != null and not w.doorways.is_empty() and rng.randf() < 0.22:
			var door: Vector3 = w.doorways[rng.randi() % w.doorways.size()]
			if door.distance_to(pos) < 70.0:
				who.run_errand(door, rng.randf_range(6.0, 16.0))
		placed += 1
