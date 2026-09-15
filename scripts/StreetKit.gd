extends RefCounted
class_name StreetKit
# ============================================================
#  The stuff that stands on a pavement.
#
#  Bus shelters, name plates on the corners, benches, bins,
#  hydrants, post boxes, planters and lamp posts. None of it
#  does anything -- it is there so a street looks like one.
#
#  It all sits in the band between the parked cars and the line
#  people walk down, and none of it is solid: the gap between a
#  parked car and a bin is exactly wide enough to wedge somebody
#  in for good, and a bin is not worth that.
# ============================================================

## The strip of pavement furniture is allowed to use, out from the road
## centreline. Parked cars reach 8.4 and walkers hold a line at World.PAVE.
const NEAR := 9.0
const FAR := 9.9
## Roughly one thing every this many metres of clear pavement, and how far
## from a junction the pavement stops counting as clear.
const PER_ITEM := 7.5
const CLEAR_OF_JUNCTION := 12.5

const POST := Color(0.34, 0.34, 0.36)
const STEEL := Color(0.55, 0.57, 0.58)

## Where every lamp head ended up. The night lighting borrows these rather
## than putting a real light on all two hundred of them.
static var lamps: Array[Vector3] = []

## Street names, so the corners can say where you are.
const NAMES_X := ["FIRST AVE", "SECOND AVE", "THIRD AVE", "FOURTH AVE", "FIFTH AVE",
	"SIXTH AVE", "SEVENTH AVE", "EIGHTH AVE"]
const NAMES_Z := ["MAIN ST", "OAK ST", "PINE ST", "ELM ST", "VINE ST",
	"CEDAR ST", "ALDER ST", "BIRCH ST"]

## Dress every pavement on the grid. `avoid` is a list of world positions that
## want keeping clear -- the garage forecourt, the yard gate, the pound.
static func dress(parent: Node3D, roads: Array, avoid: Array, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "StreetKit"
	parent.add_child(root)
	lamps.clear()
	for i in roads.size():
		var c: float = roads[i]
		for side: float in [-1.0, 1.0]:
			# the pavement of the road running along X, and of the one along Z
			_run(root, true, c, side, roads, avoid, rng)
			_run(root, false, c, side, roads, avoid, rng)
	_corners(root, roads)

## One pavement, block by block. Walking the whole length at a fixed stride and
## throwing away whatever lands near a junction leaves almost nothing standing:
## the clear window between two junctions is barely wider than the stride. So
## each stretch of pavement is filled on its own terms instead.
static func _run(root: Node3D, along_x: bool, c: float, side: float,
		roads: Array, avoid: Array, rng: RandomNumberGenerator) -> void:
	var out := side * ((NEAR + FAR) * 0.5)
	var edges := [-110.0]
	for r: float in roads:
		edges.append(r)
	edges.append(110.0)
	for i in range(edges.size() - 1):
		var lo: float = float(edges[i]) + CLEAR_OF_JUNCTION
		var hi: float = float(edges[i + 1]) - CLEAR_OF_JUNCTION
		if hi - lo < 3.0:
			continue
		var count := maxi(1, int((hi - lo) / PER_ITEM))
		for k in count:
			var t := (float(k) + rng.randf_range(0.25, 0.75)) / float(count)
			var at: float = lerpf(lo, hi, t)
			var here := Vector3(at, 0, c + out) if along_x else Vector3(c + out, 0, at)
			var skip := false
			for keep in avoid:
				if here.distance_to(keep) < 20.0:
					skip = true
					break
			if skip:
				continue
			# facing the road, so benches and shelters look the right way
			var yaw := (0.0 if side < 0.0 else PI) if along_x else (PI * 0.5 if side < 0.0 else -PI * 0.5)
			_one(root, here, yaw, rng)

## Too close to a junction to stand something there: that end of the pavement
## is the crossing, and the corner has to stay walkable.
static func _near_junction(along: float, roads: Array) -> bool:
	for c: float in roads:
		if absf(along - c) < CLEAR_OF_JUNCTION:
			return true
	return false

## Roll for something to stand there.
static func _one(root: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var spot := Node3D.new()
	spot.position = at
	spot.rotation.y = yaw
	root.add_child(spot)
	var roll := rng.randf()
	if roll < 0.12:
		_shelter(spot)
	elif roll < 0.28:
		_bench(spot)
	elif roll < 0.46:
		_bin(spot, rng)
	elif roll < 0.58:
		_hydrant(spot)
	elif roll < 0.68:
		_postbox(spot)
	elif roll < 0.80:
		_planter(spot, rng)
	else:
		_lamp(spot)
		lamps.append(at + Vector3(0, 5.0, 0))

## A name plate on each arm of every junction.
static func _corners(root: Node3D, roads: Array) -> void:
	for ix in roads.size():
		for iz in roads.size():
			var at := Vector3(roads[ix] + 9.4, 0, roads[iz] + 9.4)
			var post := Node3D.new()
			post.position = at
			root.add_child(post)
			_box(post, Vector3(0.14, 4.0, 0.14), Vector3(0, 2.0, 0), POST)
			# one arm along each street, each readable from both sides
			# the city outgrew the name lists, so they wrap round
			_plate(post, String(NAMES_Z[iz % NAMES_Z.size()]), Vector3(0, 3.7, 0), 0.0)
			_plate(post, String(NAMES_X[ix % NAMES_X.size()]), Vector3(0, 3.25, 0), PI * 0.5)

# ------------------------------------------------------------
#  The furniture
# ------------------------------------------------------------
## A bus shelter: three legs, a roof, a bench and a flag on a pole.
static func _shelter(root: Node3D) -> void:
	var glass := Color(0.55, 0.66, 0.70, 0.5)
	_box(root, Vector3(3.6, 0.14, 1.2), Vector3(0, 2.5, -0.2), Color(0.3, 0.32, 0.34))
	for sx in [-1.7, 1.7]:
		_box(root, Vector3(0.12, 2.5, 0.12), Vector3(sx, 1.25, -0.7), POST)
		_box(root, Vector3(0.12, 2.5, 0.12), Vector3(sx, 1.25, 0.3), POST)
	_box(root, Vector3(3.4, 2.2, 0.08), Vector3(0, 1.35, 0.32), glass)
	_box(root, Vector3(0.08, 2.2, 0.9), Vector3(-1.72, 1.35, -0.2), glass)
	_box(root, Vector3(2.6, 0.12, 0.5), Vector3(0, 0.6, 0.05), Color(0.45, 0.33, 0.2))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.1, 0.6, 0.4), Vector3(sx, 0.3, 0.05), POST)
	_box(root, Vector3(0.12, 3.2, 0.12), Vector3(2.2, 1.6, -0.2), POST)
	_box(root, Vector3(0.7, 0.5, 0.08), Vector3(2.2, 3.2, -0.2), Color(0.2, 0.35, 0.6))
	_label(root, "BUS", Vector3(2.2, 3.2, -0.24), Color(0.9, 0.95, 1.0), 26)

## A bench facing the road.
static func _bench(root: Node3D) -> void:
	_box(root, Vector3(1.9, 0.12, 0.55), Vector3(0, 0.55, 0), Color(0.45, 0.33, 0.2))
	_box(root, Vector3(1.9, 0.5, 0.1), Vector3(0, 0.82, 0.24), Color(0.45, 0.33, 0.2))
	for sx in [-0.8, 0.8]:
		_box(root, Vector3(0.1, 0.55, 0.5), Vector3(sx, 0.28, 0), POST)

## A bin, and about half the time a bag beside it that never got collected.
static func _bin(root: Node3D, rng: RandomNumberGenerator) -> void:
	_box(root, Vector3(0.62, 0.95, 0.62), Vector3(0, 0.62, 0), Color(0.28, 0.32, 0.3))
	_box(root, Vector3(0.7, 0.1, 0.7), Vector3(0, 1.14, 0), Color(0.2, 0.22, 0.22))
	if rng.randf() < 0.5:
		_box(root, Vector3(0.55, 0.5, 0.5), Vector3(0.7, 0.4, 0.1), Color(0.16, 0.16, 0.18))

## A hydrant, because every street has one.
static func _hydrant(root: Node3D) -> void:
	var red := Color(0.72, 0.18, 0.14)
	_box(root, Vector3(0.34, 0.62, 0.34), Vector3(0, 0.46, 0), red)
	_box(root, Vector3(0.16, 0.2, 0.16), Vector3(0, 0.86, 0), red.lightened(0.15))
	for sx in [-0.26, 0.26]:
		_box(root, Vector3(0.14, 0.16, 0.16), Vector3(sx, 0.6, 0), red.darkened(0.15))

## A post box on a stand.
static func _postbox(root: Node3D) -> void:
	_box(root, Vector3(0.6, 0.75, 0.5), Vector3(0, 0.85, 0), Color(0.25, 0.32, 0.55))
	_box(root, Vector3(0.62, 0.14, 0.52), Vector3(0, 1.28, 0), Color(0.2, 0.26, 0.45))
	_box(root, Vector3(0.14, 0.5, 0.14), Vector3(0, 0.4, 0), POST)

## A planter with something half alive in it.
static func _planter(root: Node3D, rng: RandomNumberGenerator) -> void:
	_box(root, Vector3(1.1, 0.6, 1.1), Vector3(0, 0.4, 0), Color(0.5, 0.47, 0.42))
	var h := rng.randf_range(0.7, 1.4)
	_box(root, Vector3(0.18, h, 0.18), Vector3(0, 0.7 + h * 0.5, 0), Color(0.32, 0.24, 0.18))
	_box(root, Vector3(0.9, 0.8, 0.9), Vector3(0, 0.8 + h, 0),
		Color(0.24, rng.randf_range(0.34, 0.48), 0.22))

## A lamp post leaning out over the kerb. The head glows on its own so the
## street reads as lit from a distance; the light itself is hung on it by
## DayNight, and only for the few nearest the player.
static func _lamp(root: Node3D) -> void:
	_box(root, Vector3(0.18, 5.2, 0.18), Vector3(0, 2.7, 0), POST)
	_box(root, Vector3(0.14, 0.14, 1.4), Vector3(0, 5.2, -0.7), POST)
	var head := _box(root, Vector3(0.5, 0.18, 0.8), Vector3(0, 5.05, -1.3), Color(0.95, 0.92, 0.76))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.98, 0.95, 0.80)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.92, 0.68)
	glow.emission_energy_multiplier = 1.6
	head.material_override = glow

## A skip in the alley behind the shops. Placed by whoever built the alley.
static func dumpster(parent: Node3D, at: Vector3, yaw: float, colour: Color) -> void:
	var skip := Node3D.new()
	skip.position = at
	skip.rotation.y = yaw
	parent.add_child(skip)
	_solid(skip, Vector3(2.4, 1.3, 1.3), Vector3(0, 0.8, 0), colour)
	_box(skip, Vector3(2.5, 0.12, 1.4), Vector3(0, 1.5, 0), colour.darkened(0.35))
	for sx in [-1.0, 1.0]:
		_box(skip, Vector3(0.2, 0.3, 0.2), Vector3(sx, 0.3, 0.7), Color(0.2, 0.2, 0.2))

# ------------------------------------------------------------
#  Bits
# ------------------------------------------------------------
## A name plate on an arm, hung flat and lettered on both faces. Billboarding
## it would spin the words off the sign the moment you looked from the side.
static func _plate(parent: Node3D, text: String, at: Vector3, yaw: float) -> void:
	var arm := Node3D.new()
	arm.position = at
	arm.rotation.y = yaw
	parent.add_child(arm)
	_box(arm, Vector3(1.7, 0.34, 0.06), Vector3.ZERO, Color(0.18, 0.36, 0.24))
	for face: float in [0.0, PI]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 22
		l.pixel_size = 0.008
		l.modulate = Color(0.92, 0.95, 0.9)
		l.outline_size = 5
		l.position = Vector3(0, 0, 0.045 if face == 0.0 else -0.045)
		l.rotation.y = face
		arm.add_child(l)

static func _label(parent: Node3D, text: String, at: Vector3, colour: Color, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.modulate = colour
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	parent.add_child(l)

## Something you bump into.
static func _solid(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	parent.add_child(body)
	_box(body, size, Vector3.ZERO, colour)

## One material per colour, shared across everything built here.
static var _mats := {}

## One cube, scaled per box. Thousands of separate BoxMesh resources is
## thousands of things the renderer cannot put together.
static var _cube: BoxMesh

static func _unit_cube() -> BoxMesh:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	return _cube

static func _mat(colour: Color) -> StandardMaterial3D:
	var key := colour.to_rgba32()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func _box(parent: Node, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_cube()
	mi.scale = size
	mi.position = at
	mi.material_override = _mat(colour)
	parent.add_child(mi)
	return mi
