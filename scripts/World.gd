extends Node3D
class_name World
# ============================================================
#  Procedurally-assembled grimy neighbourhood.
# ============================================================

# The street grid. Deliberately NOT evenly spaced: the gaps run from 42m to
# 56m, so the blocks between them come out different sizes and the place stops
# reading as graph paper. Both axes share the list, which is what lets traffic
# and the pedestrian corner graph keep indexing it as one thing.
const ROADS := [-170.0, -128.0, -84.0, -30.0, 16.0, 62.0, 118.0, 170.0]
## Where the grid stops. Every road used to be 700m long and ran 180m out
## past the last junction into open ground -- which is how the avenue ended
## up running straight through the chop shop. They end just past the outer
## kerb now, and the only thing that carries on is the spur to the yard.
const GRID_END := 180.0
## The middle of the shop floor. The shed sits at the back of its own lot,
## doors facing back up the spur at the town: you drive in at it, not past it.
const GARAGE_POS := Vector3(-128, 0, 254)
const SCRAP_POS := Vector3(-149, 0, 144)
## Where the city puts your truck when they catch you in it.
const IMPOUND_POS := Vector3(90, 0, -149)
## The bay inside the pound the truck ends up in.
const IMPOUND_BAY := Vector3(90, 0.05, -146)
## The truck's own space in the yard, out of the way of the shed doors.
const TRUCK_SPACE := Vector3(-24.0, 0.05, 0.0)

## The lot, measured out from the middle of the shop floor. The shed sits at
## the back of it and the gate is at the front, on the town side, so the whole
## plot reads one way: in off the spur, through the gate, up the drive, and in
## at the doors.
const YARD_HW := 34.0
const YARD_D := 30.0
## The lot is not centred on the shed -- it is nearly all in front of it, which
## is where the room to swing a car about actually needs to be.
const YARD_OFF := -10.0
## Half the shed, so the yard and the shop agree on where the doors are.
const SHED_HW := 13.0
const SHED_HD := 9.0

## Pavements run this far out from the middle of a road, and the crossings sit
## on the same line: the only place the two ever meet. It has to clear the
## parked cars, or people squeeze round them and end up in the carriageway.
const PAVE := 10.4
## Nothing parks at the roadside at all. The pavement runs unbroken from the
## kerb to the buildings, and every car that is not moving is in a lot, a yard
## or on a drive -- somewhere it belongs.
## Half the depth of a crossing, and half the width of the carriageway.
const CROSS_HALF := 1.1

## No two parked cars closer than this. A car is 2.8m wide and 6.9m long, and
## you need room to stand at the driver's door of one and work on it.
const PARK_CLEAR := 4.4
const ROAD_HALF := 6.5
## The paved strip either side of a road, from the kerb out to the back of it.
const PAVE_BACK := 11.0

## What is inside each block of the grid, laid out by hand rather than rolled,
## so the place has a shape to it: houses in the west, a warehouse yard along
## the east, towers in the middle and the shops facing them. Indexed [x][z]
## over the four blocks between the five roads.
# Seven by seven now. Neighbourhoods cluster rather than alternate, so you can
# drive through three streets of housing and know you are in a housing estate.
const DISTRICTS := [
	["culdesac","houses",   "school",    "park",      "houses",   "culdesac",  "scrap"],
	["houses",  "houses",   "shops",     "culdesac",  "towers",   "hotel",     "houses"],
	["lot",     "grocery",  "towers",    "police",    "towers",   "shops",     "park"],
	["houses",  "church",   "towers",    "park",      "towers",   "bar",       "fuel"],
	["park",    "culdesac", "shops",     "firehouse", "towers",   "houses",    "culdesac"],
	["impound", "warehouse","warehouse", "lot",       "grocery",  "houses",    "houses"],
	["lot",     "warehouse","fuel",      "warehouse", "culdesac", "park",      "bar"],
]
## Where the middle of each of those blocks is.
const BLOCKS := [-149.0, -106.0, -57.0, -7.0, 39.0, 90.0, 144.0]
## Half-width of each of those, so a builder knows how much room it has.
const PLOTS := [10.0, 11.0, 16.0, 12.0, 12.0, 17.0, 15.0]

## Buildings people go in and out of, and where the front door is.
const DOORWAY_KINDS := ["shops", "grocery", "school", "church", "hotel", "bar", "towers"]
var doorways: Array[Vector3] = []
## The middle of the police station block, once one has been built.
var station := Vector3.ZERO

var jobs: Array[Vehicle] = []
## Marked bays and driveways the districts left behind, for parking cars in.
var _off_street: Array = []
var _garage_root: Node3D
var _bays: Array[Vector3] = []
## The station's own bays, filled before anybody else parks: a cruiser and a
## civilian handed the same space end up shoving each other into the ground.
var _station_bays: Array[Vector3] = []
## Where the officers on duty were posted when the city was built. Who is
## still stood on one an hour later is a question for the chase code.
var station_posts: Array[Vector3] = []
var _last_garage_level: int = 1
var _stash_label: Label3D
var _next_tally := 0.0

func _ready() -> void:
	add_to_group("world")
	_build_ground()
	_build_roads()
	_build_blocks()
	_build_waterfront()
	_build_spur()
	_build_yard()
	_build_garage()
	_build_scrapyard()
	_build_impound()
	# the station takes its bays first, then everybody else parks round it
	_post_the_station()
	_spawn_parked_cars()
	_spawn_traffic()
	_spawn_truck()
	GameState.truck_changed.connect(_on_truck_changed)

func _process(_d: float) -> void:
	if GameState.garage_level != _last_garage_level:
		_last_garage_level = GameState.garage_level
		_build_garage()
	var who := get_tree().get_first_node_in_group("player") as Node3D
	if who:
		GameState.player_light = light_at(who.global_position)
	_next_tally -= _d
	if _next_tally <= 0.0:
		_next_tally = 1.0
		_tally_stash()

## Count what is on the shop floor, for the board on the wall. Only what is
## actually in here counts -- a door dropped across town is not stock.
func _tally_stash() -> void:
	if _stash_label == null or not is_instance_valid(_stash_label):
		return
	var count := 0
	var worth := 0
	for n in get_tree().get_nodes_in_group("loose_part"):
		var item := n as PartItem
		if item == null or item.carried or item.damaged:
			continue
		if item.global_position.distance_to(GARAGE_POS) > 16.0:
			continue
		count += 1
		worth += item.value
	_stash_label.text = "nothing on the floor" if count == 0 else "%d part%s  -  $%d" % [
		count, "" if count == 1 else "s", worth]

## How lit a spot is, 0 to 1: the sky first, then any street lamp stood
## over it, then anybody shining a torch at it. What the police can see is
## worked out off this, so standing under a lamp at 3am is a decision.
func light_at(at: Vector3) -> float:
	var lit := GameState.daylight()
	if lit > 0.9:
		return 1.0
	for lamp: Vector3 in StreetKit.lamps:
		# a lamp throws a pool on the ground, so what counts is how far you are
		# from the foot of it, not from the head five metres up
		var d := Vector2(at.x - lamp.x, at.z - lamp.z).length()
		if d < 11.0:
			lit = maxf(lit, 0.9 * (1.0 - d / 11.0))
	for n in get_tree().get_nodes_in_group("torch"):
		var holder := n as Node3D
		var to: Vector3 = at - holder.global_position
		var reach := float(holder.get_meta("torch_reach", 16.0))
		if to.length() > reach or to.length() < 0.01:
			continue
		# a beam, not a bulb: it has to be pointed at you
		var facing: Vector3 = holder.get_meta("torch_dir", -holder.global_transform.basis.z)
		if facing.normalized().dot(to.normalized()) > 0.72:
			lit = maxf(lit, 0.95)
	return clampf(lit, 0.0, 1.0)

# ------------------------------------------------------------
#  Primitives
# ------------------------------------------------------------
## One material per colour, shared. The city is thousands of boxes in a
## handful of shades, and a fresh material on each of them is a fresh
## draw call on each of them.
static var _mat_cache := {}

## One cube, scaled per box, for the same reason.
static var _cube: BoxMesh

static func _unit_cube() -> BoxMesh:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	return _cube

func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key := "%d|%.2f" % [color.to_rgba32(), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m

func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		root = sb
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_cube()
	mi.scale = size
	mi.material_override = _mat(color)
	root.add_child(mi)
	root.position = pos
	parent.add_child(root)
	return root

func _sign_label(parent: Node, text: String, pos: Vector3, color: Color = Color(1, 0.85, 0.2)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.012
	l.modulate = color
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 2
	l.outline_render_priority = 1
	l.position = pos
	parent.add_child(l)
	return l

# ------------------------------------------------------------
#  City
# ------------------------------------------------------------
func _build_ground() -> void:
	_box(self, Vector3(900, 2, 900), Vector3(0, -1, 0), Color(0.22, 0.25, 0.2)).name = "Ground"

func _build_roads() -> void:
	for c: float in ROADS:
		# tops sit just clear of the ground plane: cars and people stand on
		# that plane, so a road drawn above it has them sunk into the tarmac
		_box(self, Vector3(GRID_END * 2.0, 0.4, 13), Vector3(0, -0.19, c),
			Color(0.16, 0.16, 0.18), false)
		_box(self, Vector3(13, 0.4, GRID_END * 2.0), Vector3(c, -0.185, 0),
			Color(0.16, 0.16, 0.18), false)
	# Centre lines stop at the crossing, the way they do on a real road: the
	# junction and everything inside the crossings is left bare.
	for c: float in ROADS:
		for i in range(-34, 35):
			var along := float(i) * 10.0
			if absf(along) > GRID_END - 4.0 or _inside_junction(along):
				continue
			_box(self, Vector3(3.5, 0.42, 0.4), Vector3(along, -0.16, c), Color(0.8, 0.75, 0.4), false)
			_box(self, Vector3(0.4, 0.42, 3.5), Vector3(c, -0.16, along), Color(0.8, 0.75, 0.4), false)
	_build_pavements()
	_build_crossings()
	# and everything that stands on a pavement: shelters, benches, bins, name
	# plates on the corners. Kept clear of the three places you actually go.
	var kit := RandomNumberGenerator.new()
	kit.seed = 90210
	StreetKit.dress(self, ROADS, [GARAGE_POS, SCRAP_POS, IMPOUND_POS], kit)

## The paved strip either side of every road, with a kerb along the edge of it.
## People walk down the middle of these -- it is the same line the crossings
## are painted on -- so they run the length of the map and the junctions are
## simply left as tarmac.
func _build_pavements() -> void:
	var slab := Color(0.42, 0.42, 0.44)
	var kerb := Color(0.58, 0.58, 0.56)
	var width := PAVE_BACK - ROAD_HALF
	var middle := (PAVE_BACK + ROAD_HALF) * 0.5
	# Paving and kerb both stop dead at the kerb line of every road that
	# crosses them. Drawn as one long strip they run out over the carriageway
	# and straight through the crossing painted on it, which is not what a
	# junction looks like: the corner is where the footway ends.
	var runs := _between_roads()
	for c: float in ROADS:
		for side: float in [-1.0, 1.0]:
			for run: Array in runs:
				var length: float = run[1] - run[0]
				var mid: float = (run[0] + run[1]) * 0.5
				# along Z, either side of a road that runs along X
				_box(self, Vector3(length, 0.42, width), Vector3(mid, -0.18, c + side * middle), slab, false)
				_box(self, Vector3(length, 0.5, 0.5),
					Vector3(mid, -0.12, c + side * (ROAD_HALF + 0.25)), kerb, false)
				# and the same for the roads running the other way
				_box(self, Vector3(width, 0.42, length), Vector3(c + side * middle, -0.175, mid), slab, false)
				_box(self, Vector3(0.5, 0.5, length),
					Vector3(c + side * (ROAD_HALF + 0.25), -0.115, mid), kerb, false)

## The stretches of a road between the carriageways that cross it, as
## [from, to] pairs. Anything that runs alongside a road is built in these and
## is therefore never on top of another road.
func _between_roads() -> Array:
	var edges: Array = ROADS.duplicate()
	edges.sort()
	var runs := []
	var from := -GRID_END
	for c: float in edges:
		if c - ROAD_HALF > from + 0.5:
			runs.append([from, c - ROAD_HALF])
		from = maxf(from, c + ROAD_HALF)
	if from < GRID_END - 0.5:
		runs.append([from, GRID_END])
	return runs

## Is this far along a road close enough to a junction that road markings would
## run over the crossing?
func _inside_junction(along: float) -> bool:
	for c: float in ROADS:
		if absf(along - c) < PAVE + CROSS_HALF + 0.8:
			return true
	return false

## Four crossings on every junction, one on each approach, on the same line the
## pavements run on. Stripes lie along the way the traffic goes, and a stop bar
## sits in the approaching lane just short of each one.
func _build_crossings() -> void:
	var paint := Color(0.88, 0.88, 0.84)
	for cx: float in ROADS:
		for cz: float in ROADS:
			for side: float in [-1.0, 1.0]:
				# across the north-south road, on the approach `side` of it
				_zebra(Vector3(cx, 0.0, cz + side * PAVE), true, paint)
				_stop_bar(Vector3(cx, 0.0, cz + side * PAVE), true, side, paint)
				# and across the east-west one
				_zebra(Vector3(cx + side * PAVE, 0.0, cz), false, paint)
				_stop_bar(Vector3(cx + side * PAVE, 0.0, cz), false, side, paint)

## `across_x` means people walk over it along X, so the traffic runs along Z
## and the stripes lie that way too.
func _zebra(at: Vector3, across_x: bool, paint: Color) -> void:
	var bars := 9
	for i in bars:
		var off := (float(i) - float(bars - 1) * 0.5) * 1.35
		if across_x:
			_box(self, Vector3(0.55, 0.42, CROSS_HALF * 2.0),
				Vector3(at.x + off, -0.15, at.z), paint, false)
		else:
			_box(self, Vector3(CROSS_HALF * 2.0, 0.42, 0.55),
				Vector3(at.x, -0.15, at.z + off), paint, false)

## The line the traffic pulls up on, in the approaching lane only.
func _stop_bar(at: Vector3, across_x: bool, side: float, paint: Color) -> void:
	var back := CROSS_HALF + 1.0            # clear of the crossing itself
	var lane := ROAD_HALF * 0.5 - 0.2       # the near half of the carriageway
	if across_x:
		# traffic on this approach comes in along -side * Z, so the lane it
		# pulls up in is the half of the road to its right: +side on X
		_box(self, Vector3(lane * 2.0, 0.42, 0.4),
			Vector3(at.x + side * (ROAD_HALF * 0.5), -0.15, at.z + side * back), paint, false)
	else:
		_box(self, Vector3(0.4, 0.42, lane * 2.0),
			Vector3(at.x + side * back, -0.15, at.z - side * (ROAD_HALF * 0.5)), paint, false)

func _build_blocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260830
	_off_street.clear()
	doorways.clear()
	for xi in BLOCKS.size():
		for zi in BLOCKS.size():
			var kind := String(DISTRICTS[xi][zi])
			# the garage, the yard and the pound build themselves
			if kind in ["garage", "scrap", "impound"]:
				continue
			var centre := Vector3(BLOCKS[xi], 0, BLOCKS[zi])
			_off_street.append_array(Blocks.build(self, kind, centre, rng,
				minf(PLOTS[xi], PLOTS[zi])))
			# somewhere for people to be coming out of, and for a copper to
			# stand about outside
			if kind in DOORWAY_KINDS:
				doorways.append(centre + Vector3(0, 0, -minf(PLOTS[xi], PLOTS[zi]) * 0.35))
			if kind == "police":
				station = centre

## Officers stood about outside the station, and a couple of cruisers in the
## yard. They are not on a call: they are at work, which is the point -- the
## station should feel occupied whether or not anybody is after you.
func _post_the_station() -> void:
	if station == Vector3.ZERO:
		return
	station_posts.clear()
	for i in 3:
		var cop := PoliceOfficer.new()
		add_child(cop)
		cop.global_position = station + Vector3(-3.0 + 3.0 * float(i), 0.2, 4.0)
		if cop.has_method("stand_post"):
			cop.stand_post(cop.global_position)
			station_posts.append(cop.global_position)
	# two marked cars in the bays the block left for them
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var parked := 0
	_station_bays.clear()
	for spot in _off_street:
		if parked >= 2:
			break
		var at: Vector3 = spot[0]
		if at.distance_to(station) > 26.0:
			continue
		_station_bays.append(at)
		var car := TrafficCar.new()
		car.setup(TrafficCar.patrol_data())
		add_child(car)
		car.global_position = at
		car.rotation.y = float(spot[1])
		car.make_patrol()
		car.set_process(false)
		car.set_physics_process(false)
		parked += 1

## The town stops at the water. A river runs along the far west side, past the
## industrial end, with a quay, gantry cranes, a couple of barges and rows of
## containers stacked behind them. The shop sits a street back from all of it,
## which is the reason that corner of the map feels like somewhere to hide.
func _build_waterfront() -> void:
	var root := Node3D.new()
	root.name = "Waterfront"
	add_child(root)
	# Everything down here has to finish west of this line. The dock used to
	# start 44m out from the first avenue, which is not enough room for a quay,
	# a container yard AND four sheds -- the back half of it was standing on the
	# western streets, with sheds across the carriageway and stacks of
	# containers sat on the crossings. It gets the room it actually needs now.
	var back := float(ROADS[0]) - PAVE_BACK - 6.0   # nothing dockside goes east of here
	var edge := back - 104.0                        # the quay wall
	var reach := 260.0                        # how far up and down it runs

	# the water: a big flat slab, a shade darker than the sky
	_box(root, Vector3(190.0, 0.6, reach * 2.0), Vector3(edge - 95.0, -0.55, 0),
		Color(0.16, 0.26, 0.32), false)
	# the quay wall and the concrete apron behind it
	_box(root, Vector3(3.0, 2.4, reach * 2.0), Vector3(edge, -0.4, 0), Color(0.38, 0.38, 0.36))
	_box(root, Vector3(40.0, 0.3, reach * 2.0), Vector3(edge + 20.0, -0.12, 0),
		Color(0.31, 0.31, 0.32), false)
	# bollards along the edge
	for i in 22:
		_box(root, Vector3(0.6, 0.9, 0.6), Vector3(edge + 2.4, 0.45, -reach + 24.0 * float(i)),
			Color(0.24, 0.24, 0.26))

	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	var crate := [Color(0.55, 0.25, 0.20), Color(0.20, 0.38, 0.50), Color(0.35, 0.45, 0.28),
		Color(0.62, 0.55, 0.22), Color(0.45, 0.45, 0.48)]

	# three gantry cranes on the quay
	for i in 3:
		_crane(root, Vector3(edge + 14.0, 0, -150.0 + 150.0 * float(i)))

	# stacks of containers behind them, in rows -- three rows, ending well
	# short of the sheds, which in turn end short of `back`
	for row in 3:
		for i in 9:
			var at := Vector3(edge + 36.0 + 15.0 * float(row), 0,
				-reach + 30.0 + 52.0 * float(i))
			_container(root, at, crate[rng.randi() % crate.size()], PI * 0.5)
			if rng.randf() < 0.55:
				_container(root, at + Vector3(0, 2.7, 0), crate[rng.randi() % crate.size()], PI * 0.5)
			if rng.randf() < 0.25:
				_container(root, at + Vector3(0, 5.4, 0), crate[rng.randi() % crate.size()], PI * 0.5)

	# a couple of barges tied up alongside
	for i in 2:
		_barge(root, Vector3(edge - 22.0, 0, -90.0 + 170.0 * float(i)),
			Color(0.40, 0.20, 0.18) if i == 0 else Color(0.22, 0.30, 0.38))

	# big sheds along the landward side, so it reads as a working dock
	for i in 4:
		var sw := 34.0
		var sd := 24.0
		var sx := back - sw * 0.5
		var sz := -reach + 60.0 + 130.0 * float(i)
		var sh := 9.0
		var col := Color(0.44, 0.43, 0.40) if i % 2 == 0 else Color(0.40, 0.42, 0.44)
		_box(root, Vector3(sw, sh, sd), Vector3(sx, sh * 0.5, sz), col)
		_box(root, Vector3(sw + 1.0, 0.6, sd + 1.0), Vector3(sx, sh + 0.3, sz), col.darkened(0.3), false)
		for r in 3:
			_box(root, Vector3(0.3, 5.0, 5.0), Vector3(sx - sw * 0.5 - 0.1, 2.5, sz - 7.0 + 7.0 * float(r)),
				Color(0.36, 0.35, 0.33))

## A gantry crane: two legs, a boom out over the water, and a cab.
func _crane(root: Node3D, at: Vector3) -> void:
	var frame := Node3D.new()
	frame.position = at
	root.add_child(frame)
	var steel := Color(0.72, 0.55, 0.16)
	for sz: float in [-7.0, 7.0]:
		for sx: float in [-5.0, 5.0]:
			_box(frame, Vector3(0.9, 24.0, 0.9), Vector3(sx, 12.0, sz), steel)
	# the top beam and the boom reaching out over the quay
	_box(frame, Vector3(12.0, 1.4, 16.0), Vector3(0, 24.4, 0), steel.darkened(0.1))
	_box(frame, Vector3(2.0, 1.2, 40.0), Vector3(0, 25.6, -22.0), steel)
	_box(frame, Vector3(2.0, 1.2, 14.0), Vector3(0, 25.6, 12.0), steel)
	# the cab, and the block hanging off the boom
	_box(frame, Vector3(3.0, 2.6, 3.4), Vector3(0, 22.0, -6.0), Color(0.22, 0.24, 0.28))
	_box(frame, Vector3(0.2, 9.0, 0.2), Vector3(0, 20.6, -30.0), Color(0.3, 0.3, 0.32))
	_box(frame, Vector3(2.6, 1.2, 2.6), Vector3(0, 15.8, -30.0), Color(0.30, 0.30, 0.33))

## A barge tied up at the quay: hull, a low house at the stern, some deck cargo.
func _barge(root: Node3D, at: Vector3, hull: Color) -> void:
	var boat := Node3D.new()
	boat.position = at
	root.add_child(boat)
	_box(boat, Vector3(18.0, 3.2, 62.0), Vector3(0, 0.9, 0), hull)
	_box(boat, Vector3(16.4, 0.4, 60.0), Vector3(0, 2.5, 0), hull.darkened(0.3), false)
	# the wheelhouse aft, stacked
	_box(boat, Vector3(11.0, 4.0, 10.0), Vector3(0, 4.5, 24.0), Color(0.80, 0.79, 0.76))
	_box(boat, Vector3(8.0, 3.0, 7.0), Vector3(0, 8.0, 24.0), Color(0.86, 0.85, 0.82))
	_box(boat, Vector3(7.2, 1.4, 6.2), Vector3(0, 10.2, 24.0), Color(0.30, 0.42, 0.50, 0.7))
	_box(boat, Vector3(0.3, 7.0, 0.3), Vector3(0, 14.0, 24.0), Color(0.9, 0.9, 0.9))
	# containers on the deck
	for i in 3:
		_container(boat, Vector3(0, 2.7, -18.0 + 12.6 * float(i)),
			Color(0.55, 0.25, 0.20) if i % 2 == 0 else Color(0.20, 0.38, 0.50), 0.0)

## The lot the shop sits on. Chain-link the whole way round with one gap in it,
## our shed on one side and a second shed next to it with its doors shut. The
## point is cover: you pull off the road, through the gate, and what you do
## after that is nobody's business.
## The shop is off the grid now, so something has to lead to it: a spur south
## off the western avenue, down to the gate -- and it STOPS at the gate. What
## carries on from there is the yard's own drive, which is a different surface
## and goes where the yard says, not straight on through the shed.
func _build_spur() -> void:
	var root := Node3D.new()
	root.name = "Spur"
	add_child(root)
	var x := GARAGE_POS.x
	var from := GRID_END
	var to := GARAGE_POS.z + YARD_OFF - YARD_D
	var mid := (from + to) * 0.5
	_box(root, Vector3(13.0, 0.4, to - from), Vector3(x, -0.19, mid), Color(0.16, 0.16, 0.18), false)
	# a kerb each side and a centre line down it
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(1.4, 0.5, to - from), Vector3(x + side * 7.2, -0.16, mid),
			Color(0.55, 0.54, 0.5), false)
	var n := int((to - from) / 10.0)
	for i in n:
		_box(root, Vector3(0.4, 0.42, 3.5), Vector3(x, -0.16, from + 5.0 + 10.0 * float(i)),
			Color(0.8, 0.75, 0.4), false)
	# and a plate at the mouth of it, so it reads as somewhere that goes
	# somewhere rather than a road the map forgot to finish
	_box(root, Vector3(0.14, 2.4, 0.14), Vector3(x + 8.6, 1.2, from + 6.0), Color(0.5, 0.5, 0.52))
	_sign_label(root, "WHARF ROAD", Vector3(x + 8.6, 2.8, from + 6.0), Color(0.85, 0.85, 0.9))

func _build_yard() -> void:
	var root := Node3D.new()
	root.name = "Yard"
	add_child(root)
	root.position = GARAGE_POS
	var hw := YARD_HW
	var hd := YARD_D
	var off := YARD_OFF
	var front := off - hd                 # the fence the gate is in, town side
	var rear := off + hd                  # the back fence, behind the shed
	var post := Color(0.42, 0.43, 0.45)
	var mesh := Color(0.55, 0.58, 0.60, 0.35)

	# Hardstanding under the whole lot. It sits at the same height the roads
	# do -- a slab whose top came out under y=0 is inside the ground box, and
	# the yard read as a field with a fence round it.
	_box(root, Vector3(hw * 2.0, 0.4, hd * 2.0), Vector3(0, -0.19, off),
		Color(0.235, 0.235, 0.245), false)

	# The drive: the spur stops dead at the gate, and this is what takes over
	# from there. It runs from the gate up to the shed doors and STOPS at them
	# -- a road that carries on under a building is what was wrong with the
	# place. It widens into an apron in front of the doors so a car can be
	# swung round and lined up on a ramp rather than backed in from the road.
	var tar := Color(0.19, 0.19, 0.21)
	var drive_end := -SHED_HD - 0.5
	_box(root, Vector3(13.0, 0.42, drive_end - front), Vector3(0, -0.175, (front + drive_end) * 0.5),
		tar, false)
	_box(root, Vector3(SHED_HW * 2.0, 0.42, 9.0), Vector3(0, -0.175, drive_end - 4.5), tar, false)
	# a dashed line up the middle of it, stopping short of the apron
	var marks := int((drive_end - 5.0 - front) / 6.0)
	for i in marks:
		_box(root, Vector3(0.3, 0.44, 2.6), Vector3(0, -0.16, front + 4.0 + 6.0 * float(i)),
			Color(0.72, 0.70, 0.5), false)

	# the fence: four runs, with a gate gap in the front one. The gap has to be
	# wider than the carriageway coming into it, or the gate posts stand in the
	# road you are meant to drive through them on.
	var gate_w := 15.0
	for side: float in [-1.0, 1.0]:
		_fence_run(root, Vector3(side * hw, 0, off), Vector3(0, 0, 1), hd, post, mesh)
	_fence_run(root, Vector3(0, 0, rear), Vector3(1, 0, 0), hw, post, mesh)
	# the road side, in two pieces either side of the gate
	for side: float in [-1.0, 1.0]:
		var run := (hw * 2.0 - gate_w) * 0.5
		_fence_run(root, Vector3(side * (gate_w * 0.5 + run * 0.5), 0, front),
			Vector3(1, 0, 0), run * 0.5, post, mesh)
	# gate posts, taller, with a sign on one
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.5, 4.4, 0.5), Vector3(side * gate_w * 0.5, 2.2, front), post)
	_box(root, Vector3(3.0, 1.1, 0.14), Vector3(-gate_w * 0.5 - 1.8, 3.0, front),
		Color(0.80, 0.72, 0.20))
	_sign_label(root, "PRIVATE - NO THROUGH ROAD", Vector3(-gate_w * 0.5 - 1.8, 3.0, front - 0.2),
		Color(0.2, 0.2, 0.22))

	# The neighbour's shed, doors down, sat alongside ours and facing the same
	# way. It has to fit INSIDE the fence: it used to be wide enough to stand
	# with seven metres of itself out through the east run.
	var nw := 18.0
	var nd := 17.0
	var nh := 7.0
	var nx := SHED_HW + 2.0 + nw * 0.5    # clear of our wall, clear of the fence
	var nwall := Color(0.46, 0.45, 0.42)
	_box(root, Vector3(nw, 0.3, nd), Vector3(nx, -0.1, 0), Color(0.27, 0.27, 0.28), false)
	_box(root, Vector3(nw, nh, 0.6), Vector3(nx, nh * 0.5, nd * 0.5), nwall)
	_box(root, Vector3(0.6, nh, nd), Vector3(nx - nw * 0.5, nh * 0.5, 0), nwall)
	_box(root, Vector3(0.6, nh, nd), Vector3(nx + nw * 0.5, nh * 0.5, 0), nwall)
	_box(root, Vector3(nw, nh, 0.6), Vector3(nx, nh * 0.5, -nd * 0.5), nwall)
	_box(root, Vector3(nw + 0.8, 0.5, nd + 0.8), Vector3(nx, nh + 0.2, 0), nwall.darkened(0.35), false)
	# two shut roller doors on it, ribbed, on the yard side like ours
	for i in 2:
		var dx: float = nx - 4.5 + 9.0 * float(i)
		_box(root, Vector3(5.4, 5.0, 0.22), Vector3(dx, 2.5, -nd * 0.5 - 0.2), Color(0.44, 0.43, 0.41))
		for r in 6:
			_box(root, Vector3(5.2, 0.1, 0.06), Vector3(dx, 0.6 + 0.8 * float(r), -nd * 0.5 - 0.33),
				Color(0.36, 0.35, 0.34))
	_sign_label(root, "UNIT 2 - TO LET", Vector3(nx, nh + 1.2, -nd * 0.5), Color(0.75, 0.75, 0.8))

	# the truck has a space of its own, marked, off to one side of the drive
	# and well clear of the shed doors
	_box(root, Vector3(4.2, 0.05, 9.0), TRUCK_SPACE - Vector3(0, 0.03, 0),
		Color(0.5, 0.45, 0.15), false)
	_sign_label(root, "TRUCK", TRUCK_SPACE + Vector3(0, 2.4, 0), Color(0.9, 0.85, 0.4))

	# The yard itself: containers along the back fence, a skip, pallets. They
	# are 12m long, and they used to be set out 11m apart -- every one of them
	# stood a metre inside the next. Set out on their own length now, behind
	# the sheds where they are not in the way of anything.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7788
	var crate := [Color(0.55, 0.25, 0.20), Color(0.20, 0.38, 0.50), Color(0.35, 0.45, 0.28),
		Color(0.62, 0.55, 0.22)]
	var cz := rear - 4.0
	for i in 4:
		var cx := -20.25 + 13.5 * float(i)
		_container(root, Vector3(cx, 0, cz), crate[rng.randi() % crate.size()], 0.0)
		if i % 2 == 0:
			_container(root, Vector3(cx, 2.7, cz), crate[rng.randi() % crate.size()], 0.0)
	_box(root, Vector3(5.0, 1.8, 2.4), Vector3(-hw + 8.0, 0.9, 12.0), Color(0.45, 0.30, 0.16))
	for i in 3:
		_box(root, Vector3(1.4, 0.5, 1.2), Vector3(-hw + 15.0 + 2.0 * float(i), 0.25, 10.5),
			Color(0.52, 0.42, 0.28))

## One straight run of chain-link, centred on `at`, `axis` along it.
func _fence_run(root: Node3D, at: Vector3, axis: Vector3, half_len: float,
		post: Color, mesh: Color) -> void:
	var span := axis * half_len * 2.0
	_box(root, Vector3(maxf(0.12, absf(span.x)), 2.6, maxf(0.12, absf(span.z))),
		at + Vector3(0, 1.3, 0), mesh, false)
	# posts every four metres, and a rail along the top
	var n := int(half_len * 2.0 / 4.0) + 1
	for i in n + 1:
		var t := -half_len + 4.0 * float(i)
		if absf(t) > half_len:
			continue
		_box(root, Vector3(0.16, 2.8, 0.16), at + axis * t + Vector3(0, 1.4, 0), post)
	_box(root, Vector3(maxf(0.16, absf(span.x)), 0.12, maxf(0.16, absf(span.z))),
		at + Vector3(0, 2.7, 0), post, false)

## A shipping container.
func _container(root: Node3D, at: Vector3, colour: Color, yaw: float) -> void:
	var box := Node3D.new()
	box.position = at
	box.rotation.y = yaw
	root.add_child(box)
	_box(box, Vector3(12.0, 2.6, 2.9), Vector3(0, 1.3, 0), colour)
	_box(box, Vector3(12.1, 0.16, 3.0), Vector3(0, 2.6, 0), colour.darkened(0.25))
	# corrugations, and the doors at one end
	for i in 9:
		_box(box, Vector3(0.1, 2.4, 3.02), Vector3(-5.4 + 1.35 * float(i), 1.3, 0),
			colour.darkened(0.12))
	_box(box, Vector3(0.14, 2.3, 2.7), Vector3(6.0, 1.25, 0), colour.lightened(0.12))

# ------------------------------------------------------------
#  Chop shop
# ------------------------------------------------------------
func _build_garage() -> void:
	if _garage_root:
		_garage_root.queue_free()
	_garage_root = Node3D.new()
	add_child(_garage_root)
	_garage_root.position = GARAGE_POS

	var lvl := GameState.garage_level
	# A shed with two roller doors in the front, whatever tier it is. The bays
	# line up with the doors, and tier 1 only fills the left one -- the empty
	# half is the upgrade, sat there in plain sight.
	# The doors face -Z: back up the drive, at the gate, at the town. The shed
	# used to face the other way, out into open ground with its back to
	# everything, which is why you drove past the whole place to get to it.
	var w := SHED_HW * 2.0
	var d := SHED_HD * 2.0
	var h := 6.4
	var wall := Color(0.42, 0.36, 0.3)
	if lvl == 2:
		wall = Color(0.5, 0.5, 0.55)
	elif lvl >= 3:
		wall = Color(0.35, 0.45, 0.55)

	_box(_garage_root, Vector3(w, 0.3, d), Vector3(0, -0.11, 0), Color(0.28, 0.28, 0.29), false)
	_box(_garage_root, Vector3(w, h, 0.6), Vector3(0, h * 0.5, d * 0.5), wall)
	_box(_garage_root, Vector3(0.6, h, d), Vector3(-w * 0.5, h * 0.5, 0), wall)
	_box(_garage_root, Vector3(0.6, h, d), Vector3(w * 0.5, h * 0.5, 0), wall)
	_box(_garage_root, Vector3(w, 0.4, d), Vector3(0, h, 0), wall.darkened(0.35), false)

	# the front wall, in three pieces with two door openings between them
	var door_w := 6.6
	var pier := (w - door_w * 2.0) / 3.0
	for i in 3:
		var px := -w * 0.5 + pier * 0.5 + float(i) * (pier + door_w)
		_box(_garage_root, Vector3(pier, h, 0.6), Vector3(px, h * 0.5, -d * 0.5), wall)
	# lintel over both openings
	_box(_garage_root, Vector3(w, 1.1, 0.6), Vector3(0, h - 0.55, -d * 0.5), wall.darkened(0.2))
	# roller shutters: the left one is up, the right one is up once you have
	# bought the second bay
	for i in 2:
		var dx := -w * 0.5 + pier + door_w * 0.5 + float(i) * (pier + door_w)
		# the guide rails either side of each opening
		for sx: float in [-1.0, 1.0]:
			_box(_garage_root, Vector3(0.25, h - 1.1, 0.25),
				Vector3(dx + sx * door_w * 0.5, (h - 1.1) * 0.5, -d * 0.5 - 0.35),
				Color(0.32, 0.32, 0.34))
		if i < lvl:
			# rolled up: a fat drum under the lintel
			_box(_garage_root, Vector3(door_w, 0.7, 0.5), Vector3(dx, h - 1.5, -d * 0.5 - 0.2),
				Color(0.55, 0.55, 0.58))
		else:
			# shut, with the ribs of a roller door on it
			_box(_garage_root, Vector3(door_w, h - 1.1, 0.22),
				Vector3(dx, (h - 1.1) * 0.5, -d * 0.5 - 0.2), Color(0.48, 0.47, 0.45))
			for r in 7:
				_box(_garage_root, Vector3(door_w - 0.2, 0.1, 0.06),
					Vector3(dx, 0.5 + 0.72 * float(r), -d * 0.5 - 0.33), Color(0.38, 0.37, 0.36))

	var names := ["GARBAGE GARAGE", "SMALL CHOP SHOP", "PROFESSIONAL OPERATION"]
	_sign_label(_garage_root, "%s\n(Tier %d)" % [names[lvl - 1], lvl], Vector3(0, h + 1.6, -d * 0.5), Color(1, 0.75, 0.15))

	for i in lvl:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 16.0
		lamp.light_energy = 1.4 if lvl > 1 else 1.0
		lamp.light_color = Color(1.0, 0.9, 0.7) if lvl > 1 else Color(0.9, 0.75, 0.5)
		lamp.position = Vector3(-w * 0.5 + pier + door_w * 0.5 + float(i) * (pier + door_w), h - 0.8, 2.0)
		_garage_root.add_child(lamp)

	_bays.clear()
	# one bay per roller door, so a car drives straight in through its own
	# opening instead of being shuffled sideways once it is inside
	for i in lvl:
		var bx := -w * 0.5 + pier + door_w * 0.5 + float(i) * (pier + door_w)
		_bays.append(GARAGE_POS + Vector3(bx, 0.05, 2.0))
		_box(_garage_root, Vector3(3.2, 0.05, 6.4), Vector3(bx, 0.045, 2.0), Color(0.5, 0.45, 0.15), false)

	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(w - 1.0, 4.0, d - 1.0)
	acs.shape = abox
	area.add_child(acs)
	area.position = Vector3(0, 2.0, 0)
	area.body_entered.connect(_on_garage_body_entered)
	_garage_root.add_child(area)

	# the computer: a beige box that orders things in
	var pc := Interactable.new()
	pc.prompt = "[E] Computer - order tools, contacts and upgrades"
	pc.action = func(p): p.hud.open_shop()
	pc.position = Vector3(-w * 0.5 + 2.5, 1.0, d * 0.5 - 2.0)
	_garage_root.add_child(pc)
	_box(pc, Vector3(1.8, 0.9, 1.0), Vector3.ZERO, Color(0.4, 0.35, 0.3), false)
	_box(pc, Vector3(0.7, 0.55, 0.12), Vector3(0, 0.72, -0.15), Color(0.82, 0.8, 0.72), false)
	_box(pc, Vector3(0.6, 0.42, 0.02), Vector3(0, 0.74, -0.22), Color(0.25, 0.6, 0.35), false)
	_box(pc, Vector3(0.62, 0.06, 0.3), Vector3(0, 0.48, 0.2), Color(0.75, 0.73, 0.66), false)
	_sign_label(pc, "COMPUTER", Vector3(0, 1.5, 0), Color(0.6, 1.0, 0.7))

	# the workbench: where everything you are not carrying ends up
	var bench := Interactable.new()
	bench.prompt = "[E] Workbench - stow and pick up your kit"
	bench.action = func(p): p.hud.open_bench()
	bench.position = Vector3(-w * 0.5 + 1.6, 1.0, d * 0.5 - 6.5)
	_garage_root.add_child(bench)
	_box(bench, Vector3(1.4, 1.0, 3.0), Vector3.ZERO, Color(0.55, 0.4, 0.25), false)
	_box(bench, Vector3(0.3, 0.4, 0.35), Vector3(0, 0.7, -1.1), Color(0.35, 0.35, 0.4), false)
	_box(bench, Vector3(0.5, 0.1, 0.9), Vector3(0, 0.55, 0.5), Color(0.5, 0.5, 0.55), false)
	_box(bench, Vector3(0.12, 0.5, 0.12), Vector3(-0.3, 0.75, 0.9), Color(0.7, 0.6, 0.2), false)
	_sign_label(bench, "WORKBENCH", Vector3(0, 1.6, 0), Color(0.95, 0.85, 0.5))

	# The order board: pinned notes from people who want particular things
	var jobs_board := Interactable.new()
	jobs_board.prompt = "[E] The board - who wants what, and by when"
	jobs_board.action = func(p): p.hud.open_board()
	jobs_board.position = Vector3(-w * 0.5 + 0.35, 1.7, d * 0.5 - 3.6)
	_garage_root.add_child(jobs_board)
	_box(jobs_board, Vector3(0.1, 1.1, 1.6), Vector3.ZERO, Color(0.35, 0.26, 0.18), false)
	for i in 5:
		_box(jobs_board, Vector3(0.02, 0.26, 0.2),
			Vector3(0.07, 0.28 - 0.28 * float(i % 3), -0.5 + 0.34 * float(i)),
			Color(0.9, 0.88, 0.8), false)
	_sign_label(jobs_board, "THE BOARD", Vector3(0, 0.85, 0), Color(1.0, 0.9, 0.6))

	# The arms dealer. He works out of the back of the shop for now, but he is
	# written as somebody with his own stock rather than another shelf of yours,
	# because the plan is to put him in a van and move him round the town.
	var arms := Interactable.new()
	arms.prompt = "[E] Talk to the dealer - guns, cash only"
	arms.action = func(p): p.hud.open_arms()
	arms.position = Vector3(w * 0.5 - 2.2, 1.0, d * 0.5 - 3.4)
	_garage_root.add_child(arms)
	_box(arms, Vector3(1.5, 0.55, 0.8), Vector3(0, -0.4, 0), Color(0.22, 0.24, 0.28), false)
	_box(arms, Vector3(1.5, 0.12, 0.8), Vector3(0, -0.06, 0), Color(0.32, 0.30, 0.26), false)
	_box(arms, Vector3(0.5, 0.1, 0.16), Vector3(-0.35, 0.06, 0), Color(0.18, 0.18, 0.2), false)
	_box(arms, Vector3(0.42, 0.08, 0.14), Vector3(0.3, 0.06, -0.1), Color(0.35, 0.25, 0.15), false)
	_sign_label(arms, "THE DEALER", Vector3(0, 1.3, 0), Color(1.0, 0.55, 0.45))

	var board := Interactable.new()
	board.prompt = "[E] Check the parts stash"
	board.action = func(p): p.hud.open_stash()
	board.position = Vector3(w * 0.5 - 1.5, 1.6, d * 0.5 - 2.0)
	_garage_root.add_child(board)
	_box(board, Vector3(2.6, 1.6, 0.3), Vector3.ZERO, Color(0.2, 0.22, 0.2), false)
	_sign_label(board, "PARTS STASH", Vector3(0, 1.3, 0), Color(0.6, 1.0, 0.6))
	# the tally of what is lying about in here, where you can see the pile
	_stash_label = _sign_label(board, "", Vector3(0, 0.75, 0), Color(0.85, 1.0, 0.85))
	_stash_label.font_size = 40

	var spawn := Node3D.new()
	spawn.add_to_group("garage_spawn")
	spawn.position = Vector3(0, 1.2, -d * 0.5 - 4.0)
	_garage_root.add_child(spawn)

	jobs = jobs.filter(func(j): return is_instance_valid(j))
	for i in jobs.size():
		if i < _bays.size():
			jobs[i].global_position = _bays[i]

## Rolling through the door is not the same as delivering it. Say what still
## has to happen and leave the car where it is.
func _on_garage_body_entered(body: Node3D) -> void:
	if not (body is Vehicle):
		return
	var v := body as Vehicle
	if v.is_job or v.locked or v.driver == null:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if GameState.wanted > 0:
		hud.toast("NOT WITH THAT TAIL", "Lose the cops before you pull in.")
		return
	jobs = jobs.filter(func(j): return is_instance_valid(j))
	if jobs.size() >= _bays.size():
		hud.toast("NO ROOM", "All %d bay(s) full. Strip something first." % _bays.size())
		return
	hud.toast("PULL IT ONTO A RAMP", "Line it up on a marked bay and get out. [F]")

## Which marked bay a point is standing on, or -1 for none. The pads are 3m by
## 6m, so this is the pad's own footprint with a little slack for parking that
## is not quite square.
func bay_at(at: Vector3) -> int:
	for i in _bays.size():
		var b: Vector3 = _bays[i]
		if absf(at.x - b.x) < 1.7 and absf(at.z - b.z) < 3.2:
			return i
	return -1

## Is a car already sat on that pad?
func bay_taken(i: int) -> bool:
	for j in jobs:
		if is_instance_valid(j) and bay_at((j as Node3D).global_position) == i:
			return true
	return false

## Got out of it on a ramp: that, and only that, hands the car over to the shop.
## Returns true if it took it. Says why not otherwise, because a car sat on the
## pad doing nothing with no explanation is worse than the old teleport.
func take_in_from_bay(v: Vehicle) -> bool:
	if v == null or not is_instance_valid(v) or v.is_job:
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	var bay := bay_at(v.global_position)
	if bay < 0:
		return false
	if GameState.wanted > 0:
		if hud:
			hud.toast("NOT WITH THAT TAIL", "Lose the cops before you leave it here.")
		return false
	jobs = jobs.filter(func(j): return is_instance_valid(j))
	if jobs.size() >= _bays.size() or bay_taken(bay):
		if hud:
			hud.toast("NO ROOM", "All %d bay(s) full. Strip something first." % _bays.size())
		return false
	jobs.append(v)
	v.set_as_job()
	# square it up on the pad it was left on rather than snapping it elsewhere
	v.global_position = _bays[bay]
	v.rotation.y = 0.0
	v.velocity = Vector3.ZERO
	v.speed = 0.0
	GameState.stats.delivered += 1
	if hud:
		hud.toast("UP ON THE RAMP", "%s - est. $%d - condition %d%%" % [
			v.data.name, v.estimated_value(), int(v.condition * 100.0)])
	return true

## Take one back off the ramp. It stops being shop stock and goes back to being
## a car sitting in your garage that you can get into and drive away.
func release_from_bay(v: Vehicle) -> bool:
	if v == null or not is_instance_valid(v) or not v.is_job:
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	if not v.can_roll():
		if hud:
			hud.toast("IT IS ON STANDS", "Put the wheels back on before you drive it anywhere.")
		return false
	jobs.erase(v)
	v.release_job()
	if hud:
		hud.toast("OFF THE RAMP", "%s is yours to drive again." % v.data.name)
	return true

## Crush what is left. Pays bare-metal weight -- the floor price.
func scrap_carcass(v: Vehicle) -> int:
	var paid := v.shell_value()
	jobs.erase(v)
	v.queue_free()
	GameState.add_money(paid)
	for i in jobs.size():
		if is_instance_valid(jobs[i]) and i < _bays.size():
			jobs[i].global_position = _bays[i]
	return paid

func _spawn_truck() -> void:
	var truck := Truck.new()
	truck.setup(GameData.truck_data(GameState.truck_level))
	add_child(truck)
	truck.global_position = GARAGE_POS + TRUCK_SPACE
	truck.rotation.y = PI

func _on_truck_changed() -> void:
	var t := GameState.truck()
	if t == null:
		return
	t.setup(GameData.truck_data(GameState.truck_level))
	t.rebuild()

# ------------------------------------------------------------
#  Scrap yard
# ------------------------------------------------------------
func _build_scrapyard() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = SCRAP_POS
	# The block it stands on is only 20m across between the pavements, so the
	# yard is 20m across. It used to be 26 and stood on both footways.
	_box(root, Vector3(20, 0.3, 26), Vector3(0, -0.11, 0), Color(0.3, 0.28, 0.24), false)
	for i in range(14):
		var s := randf_range(1.0, 3.0)
		_box(root, Vector3(s, s, s), Vector3(randf_range(-8, 8), s * 0.5, randf_range(-11, -2)),
			Color(randf_range(0.3, 0.6), randf_range(0.25, 0.45), randf_range(0.2, 0.35)), false)
	_box(root, Vector3(8, 4, 5), Vector3(0, 2, -9), Color(0.45, 0.42, 0.35))
	_sign_label(root, "GORDOS SCRAP YARD\nWE BUY ANYTHING, NO QUESTIONS", Vector3(0, 6.5, -9), Color(0.4, 1.0, 0.5))

	var counter := Interactable.new()
	counter.prompt = "[E] Sell parts to Gordo"
	counter.action = func(p): p.hud.open_scrapyard()
	counter.position = Vector3(0, 1.0, -5.0)
	root.add_child(counter)
	_box(counter, Vector3(4.0, 1.1, 1.2), Vector3.ZERO, Color(0.6, 0.5, 0.3), false)
	_sign_label(counter, "[E] SELL", Vector3(0, 1.4, 0), Color(1, 1, 0.6))

# ------------------------------------------------------------
#  The pound
# ------------------------------------------------------------
## A wire compound with one way in. Get caught driving your own truck and this
## is where it ends up, load still in the back.
func _build_impound() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = IMPOUND_POS
	var wire := Color(0.55, 0.57, 0.55)
	# 24 across and 20 deep: the plot is wide but shallow, and a square
	# compound put the wire out over the pavement at both ends.
	_box(root, Vector3(24, 0.3, 20), Vector3(0, -0.11, 0), Color(0.26, 0.26, 0.28), false)
	# fence: solid on three sides, a gap on the north one to drive out through
	_box(root, Vector3(24, 2.6, 0.25), Vector3(0, 1.3, 10), wire)
	_box(root, Vector3(0.25, 2.6, 20), Vector3(-12, 1.3, 0), wire)
	_box(root, Vector3(0.25, 2.6, 20), Vector3(12, 1.3, 0), wire)
	_box(root, Vector3(8.0, 2.6, 0.25), Vector3(-8, 1.3, -10), wire)
	_box(root, Vector3(8.0, 2.6, 0.25), Vector3(8, 1.3, -10), wire)
	for x: float in [-12.0, -4.0, 4.0, 12.0]:
		_box(root, Vector3(0.4, 3.0, 0.4), Vector3(x, 1.5, -10), wire.darkened(0.3))
	# a hut nobody is ever in
	_box(root, Vector3(4, 3, 4), Vector3(-9, 1.5, -6), Color(0.45, 0.44, 0.4))
	_sign_label(root, "CITY IMPOUND
RECOVERY BY APPOINTMENT ONLY", Vector3(0, 4.4, -10), Color(1, 0.4, 0.35))
	_box(root, Vector3(3.2, 0.05, 7.0), Vector3(0, 0.045, 3.0), Color(0.55, 0.5, 0.15), false)

## Off to the pound with it, load and all. It comes back locked and dead, so
## getting it out is either a fee at the computer or the same job as any car.
func impound_truck(t: Truck) -> void:
	if t == null or not is_instance_valid(t):
		return
	t.unhitch()
	t.driver = null
	t.speed = 0.0
	t.velocity = Vector3.ZERO
	t.shove = Vector3.ZERO
	t.global_position = IMPOUND_BAY
	t.rotation.y = PI
	t.locked = true
	t.hotwired = false
	GameState.truck_impounded = true
	GameState.inventory_changed.emit()

# ------------------------------------------------------------
#  Cars
# ------------------------------------------------------------
func _spawn_parked_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# Nothing is left at a kerb, and there are no roadside bays either: a car
	# stood on the line blocks the carriageway and the footway at once. What is
	# parked is parked properly -- lots, yards, service roads and driveways.
	# Shuffled off the seeded generator rather than Array.shuffle(), which
	# borrows the global one: which car ends up where should be the same every
	# run, or a car parked inside something only shows up some of the time.
	var lots: Array = _off_street.duplicate()
	for i in range(lots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = lots[i]
		lots[i] = lots[j]
		lots[j] = swap
	# the station's cruisers are already stood in theirs
	var taken: Array[Vector3] = _station_bays.duplicate()
	for spot in lots:
		if taken.size() >= 30:
			break
		# never two abreast: you have to be able to get to a driver's door with
		# a jimmy, and a car parked a wing's width away makes that impossible
		var too_close := false
		for used in taken:
			if used.distance_to(spot[0] as Vector3) < PARK_CLEAR:
				too_close = true
				break
		if too_close:
			continue
		if _park_a_car(spot[0], float(spot[1]), rng):
			taken.append(spot[0])

## One car left where it was parked, facing either way down the space. False if
## the space was no good and nothing went in it.
func _park_a_car(at: Vector3, yaw: float, rng: RandomNumberGenerator) -> bool:
	if at.distance_to(GARAGE_POS) < 20.0:
		return false
	var v := Vehicle.new()
	v.setup(_pick_vehicle_def(rng, at).duplicate(true))
	add_child(v)
	v.global_position = at
	v.rotation.y = yaw + (PI if rng.randf() < 0.5 else 0.0)
	return true


## What kind of car turns up. The spot biases it: nothing worth much is parked in
## the industrial end for long, so those streets are junkers and vans. Better
## cars can still drive through -- traffic is routed, not filtered -- they just
## do not live there.
func _pick_vehicle_def(rng: RandomNumberGenerator, at: Vector3 = Vector3.ZERO) -> Dictionary:
	var roll := rng.randf()
	var tier := 1
	if industrial(at):
		# T1 mostly, T2 sometimes, and nothing above it
		if roll > 0.62:
			tier = 2
	elif roll > 0.94:
		tier = 4
	elif roll > 0.80:
		tier = 3
	elif roll > 0.50:
		tier = 2
	var pool := []
	for v in GameData.VEHICLES:
		if int(v.tier) == tier:
			pool.append(v)
	if pool.is_empty():
		pool = GameData.VEHICLES
	return pool[rng.randi() % pool.size()]

## Is this the working end of town? The warehouse blocks, the yard, the pound
## and everything out towards the water.
func industrial(at: Vector3) -> bool:
	if at == Vector3.ZERO:
		return false
	if at.x < float(ROADS[0]):
		return true                 # the docks
	if at.distance_to(GARAGE_POS) < 90.0:
		return true                 # the yard and the estate round it
	if at.z > float(ROADS[ROADS.size() - 1]):
		return true                 # the strip south of the grid
	for xi in BLOCKS.size():
		for zi in BLOCKS.size():
			if not (String(DISTRICTS[xi][zi]) in ["warehouse", "scrap", "impound", "garage", "lot"]):
				continue
			if absf(at.x - float(BLOCKS[xi])) < PLOTS[xi] + PAVE_BACK 					and absf(at.z - float(BLOCKS[zi])) < PLOTS[zi] + PAVE_BACK:
				return true
	return false

# ------------------------------------------------------------
#  Debug spawning
# ------------------------------------------------------------
## Drop a car of `id` on the ground, locked, the way a kerbside one is.
func spawn_vehicle(id: String, at: Vector3) -> Vehicle:
	var def: Dictionary = GameData.vehicle_by_id(id)
	if def.is_empty():
		return null
	var v := Vehicle.new()
	v.setup(def.duplicate(true))
	add_child(v)
	v.global_position = at + Vector3(0, 0.7, 0)
	return v

## Or straight into a garage bay, ready to be taken apart.
func spawn_job(id: String) -> Vehicle:
	jobs = jobs.filter(func(j): return is_instance_valid(j))
	if jobs.size() >= _bays.size():
		return null
	var v := spawn_vehicle(id, _bays[jobs.size()])
	if v == null:
		return null
	jobs.append(v)
	v.set_as_job()
	v.global_position = _bays[jobs.size() - 1]
	v.rotation.y = 0.0
	return v

## Somebody on foot, walking to the nearest corner from wherever they land.
## `dress_seed` of -1 picks their clothes at random; pass one to get a
## particular person back, which is how somebody dragged out of a car ends up
## stood in the road wearing what they were wearing at the wheel.
func spawn_walker(at: Vector3, officer: bool = false, dress_seed: int = -1) -> Pedestrian:
	var who: Pedestrian = PoliceOfficer.new() if officer else Pedestrian.new()
	who.outfit_seed = randi() if dress_seed < 0 else dress_seed
	add_child(who)
	# onto the nearest corner, whichever one they landed closest to
	var ix := _nearest_road(at.x)
	var iz := _nearest_road(at.z)
	who.place_at_corner(ix, iz, 1 if at.x >= ROADS[ix] else -1, 1 if at.z >= ROADS[iz] else -1)
	return who

func _nearest_road(v: float) -> int:
	var best := 0
	for i in ROADS.size():
		if absf(ROADS[i] - v) < absf(ROADS[best] - v):
			best = i
	return best

func _spawn_traffic() -> void:
	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
