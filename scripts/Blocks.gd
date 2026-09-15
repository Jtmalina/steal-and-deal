extends RefCounted
class_name Blocks
# ============================================================
#  What is inside a city block.
#
#  The roads and the pavements are the same everywhere -- the
#  traffic and the crossings ride on that grid and it has to
#  stay regular. Everything the grid encloses does not, so each
#  block gets built as one of a handful of places: houses round
#  a dead end, towers, a row of shops, a warehouse yard, a
#  parking lot, or a scrap of park.
#
#  Every builder stays inside HALF of the block centre. Beyond
#  that is pavement, and people walk there.
# ============================================================

## Usable half-width of a block. The pavements take the rest.
## Default half-width of a plot. The city no longer uses one block size, so
## every builder works off `half`, which the world hands in per plot; this is
## only the fallback for anything that does not.
const HALF := 9.0
static var half := 9.0
## Everything stands on the ground plane, which is what people and cars
## stand on too. A deck above it just buries their feet.
const DECK := 0.02

const WALLS := [
	Color(0.55, 0.35, 0.30), Color(0.45, 0.45, 0.50), Color(0.60, 0.55, 0.40),
	Color(0.35, 0.40, 0.45), Color(0.50, 0.42, 0.50), Color(0.62, 0.58, 0.52),
]
const ROOFS := [Color(0.30, 0.28, 0.28), Color(0.35, 0.25, 0.22), Color(0.26, 0.29, 0.32)]
## Houses are painted, not poured, so they get their own lighter set.
const HOUSES := [
	Color(0.80, 0.76, 0.66), Color(0.72, 0.60, 0.52), Color(0.62, 0.70, 0.68),
	Color(0.84, 0.70, 0.50), Color(0.66, 0.66, 0.74), Color(0.76, 0.66, 0.70),
]
const TARMAC := Color(0.20, 0.20, 0.22)
const PAINT := Color(0.85, 0.84, 0.78)
const GLASS := Color(0.35, 0.50, 0.62, 0.55)

## Build `kind` at `centre`. Returns the parking spots it made, each
## [position, yaw], for whoever wants to leave a car in them.
static func build(parent: Node3D, kind: String, centre: Vector3,
		rng: RandomNumberGenerator, plot: float = HALF) -> Array:
	half = maxf(6.0, plot)
	var root := Node3D.new()
	root.position = centre
	parent.add_child(root)
	match kind:
		"houses":
			return _houses(root, rng)
		"towers":
			_towers(root, rng)
		"shops":
			return _shops(root, rng)
		"warehouse":
			return _warehouse(root, rng)
		"lot":
			return _lot(root, rng)
		"park":
			_park(root, rng)
		"fuel":
			return _fuel(root, rng)
		"police":
			return _police(root, rng)
		"school":
			return _school(root, rng)
		"church":
			return _church(root, rng)
		"hotel":
			return _hotel(root, rng)
		"firehouse":
			return _firehouse(root, rng)
		"bar":
			return _bar(root, rng)
		"grocery":
			return _grocery(root, rng)
		"culdesac":
			return _culdesac(root, rng)
	return []

# ------------------------------------------------------------
#  Dead ends and interiors
# ------------------------------------------------------------
## A street that goes nowhere. Runs in off the road on one side, widens into a
## turning head, and has houses round the bulb. Traffic never routes down it --
## the router only knows the grid -- which is rather the point of a dead end.
static func _culdesac(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var mouth := -half - 1.0
	# the throat, from the kerb in to the middle
	_slab(root, Vector2(half * 1.4, 7.0), Vector3(-half * 0.28, 0, 0), TARMAC)
	# and the turning head it ends in
	_slab(root, Vector2(half * 0.8, half * 1.2), Vector3(half * 0.55, 0, 0), TARMAC)
	_paint(root, Vector2(0.3, 4.4), Vector3(mouth * 0.9, 0, 0))
	# NO EXIT, on a post at the mouth
	_box(root, Vector3(0.12, 2.4, 0.12), Vector3(mouth + 0.6, DECK + 1.2, 4.2), Color(0.5, 0.5, 0.52))
	_box(root, Vector3(0.1, 0.8, 1.5), Vector3(mouth + 0.6, DECK + 2.5, 4.2), Color(0.92, 0.90, 0.86))
	_sign(root, "NO EXIT", Vector3(mouth + 0.5, DECK + 2.5, 4.2), Color(0.2, 0.2, 0.25))
	# Houses down both sides with their backs to the block edge, and one more
	# across the head. They used to be set out on a ring round the bulb, which
	# put the far one three metres out over the pavement on every cul-de-sac in
	# the city: a house is nearly seven metres across and these blocks are
	# twenty deep, so there is no room for a circle of them.
	var back := half - 3.6
	var edge := half - 3.1
	var lay := [
		[Vector3(-half * 0.50, 0, -edge), 1.0],
		[Vector3(half * 0.22, 0, -edge), 1.0],
		[Vector3(-half * 0.50, 0, edge), -1.0],
		[Vector3(half * 0.22, 0, edge), -1.0],
		[Vector3(back, 0, 0), -1.0],
	]
	for row: Array in lay:
		var here: Vector3 = row[0]
		var facing: float = row[1]
		_slab(root, Vector2(7.4, 5.6), here, Color(0.31, 0.42, 0.27))
		_house(root, here, facing, HOUSES[rng.randi() % HOUSES.size()],
			ROOFS[rng.randi() % ROOFS.size()], rng)
	# a car left on the throat, which is where one would be
	spots.append([root.position + Vector3(-half * 0.55, 0.05, 2.2), PI * 0.5])
	return spots

## Four walls with a gap in the front one, a floor and a roof, all separate
## solids -- so you can walk in through the doorway instead of bouncing off a
## single box the size of the building.
static func _room(root: Node3D, at: Vector3, span: Vector3, wall: Color,
		door_w: float) -> void:
	var t := 0.3
	var hx: float = span.x * 0.5
	var hz: float = span.z * 0.5
	# floor and roof
	_box(root, Vector3(span.x, 0.12, span.z), at + Vector3(0, DECK + 0.06, 0), wall.darkened(0.35))
	_solid(root, Vector3(span.x + t, 0.3, span.z + t), at + Vector3(0, DECK + span.y, 0), wall.darkened(0.2))
	# back and two sides
	_solid(root, Vector3(span.x, span.y, t), at + Vector3(0, DECK + span.y * 0.5, hz), wall)
	_solid(root, Vector3(t, span.y, span.z), at + Vector3(-hx, DECK + span.y * 0.5, 0), wall)
	_solid(root, Vector3(t, span.y, span.z), at + Vector3(hx, DECK + span.y * 0.5, 0), wall)
	# the front, in two pieces with the doorway between them
	var side: float = (span.x - door_w) * 0.5
	for sx: float in [-1.0, 1.0]:
		_solid(root, Vector3(side, span.y, t),
			at + Vector3(sx * (hx - side * 0.5), DECK + span.y * 0.5, -hz), wall)
	# a lintel over the gap, so it reads as a doorway rather than a hole
	_box(root, Vector3(door_w, span.y - 2.6, t * 0.8),
		at + Vector3(0, DECK + span.y - (span.y - 2.6) * 0.5, -hz), wall.darkened(0.1))

# ------------------------------------------------------------
#  Civic buildings
# ------------------------------------------------------------
## The station. Marked bays down the near side, steps and a blue lamp at the
## front, a flag on a pole. Posting officers outside it is the world's job.
static func _police(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var stone := Color(0.55, 0.55, 0.58)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.34, 0.34, 0.36))
	_solid(root, Vector3(half * 1.1, 7.0, half * 0.95), Vector3(-half * 0.35, DECK + 3.5, half * 0.35), stone)
	_solid(root, Vector3(half * 0.7, 4.4, half * 0.7), Vector3(half * 0.5, DECK + 2.2, half * 0.5), stone.darkened(0.08))
	_box(root, Vector3(half * 1.16, 0.5, half * 1.0), Vector3(-half * 0.35, DECK + 7.1, half * 0.35), Color(0.28, 0.30, 0.36))
	for row in 2:
		for i in 4:
			_box(root, Vector3(1.5, 1.2, 0.12), Vector3(-half * 0.35 - 4.0 + 2.7 * float(i), DECK + 2.2 + 2.6 * float(row), half * 0.35 - half * 0.48), GLASS)
	_box(root, Vector3(4.0, 0.4, 1.6), Vector3(-half * 0.35, DECK + 0.2, half * 0.35 - half * 0.62), stone.lightened(0.1))
	_box(root, Vector3(2.2, 2.6, 0.16), Vector3(-half * 0.35, DECK + 1.5, half * 0.35 - half * 0.49), Color(0.24, 0.20, 0.16))
	_box(root, Vector3(0.5, 0.5, 0.5), Vector3(-half * 0.35, DECK + 3.2, half * 0.35 - half * 0.52), Color(0.2, 0.35, 0.9))
	_box(root, Vector3(0.16, 6.0, 0.16), Vector3(-half * 0.85, DECK + 3.0, -half * 0.2), Color(0.8, 0.8, 0.82))
	_box(root, Vector3(0.1, 1.0, 1.6), Vector3(-half * 0.85, DECK + 5.4, -half * 0.2 + 0.85), Color(0.55, 0.15, 0.18))
	_sign(root, "POLICE", Vector3(-half * 0.35, DECK + 5.6, half * 0.35 - half * 0.5), Color(0.65, 0.8, 1.0))
	for i in 3:
		var at := Vector3(-half + 3.4 + 4.6 * float(i), 0, -half + 4.2)
		_paint(root, Vector2(0.3, 5.6), at + Vector3(-2.2, 0, 0))
		spots.append([root.position + at + Vector3(0, 0.05, 0), 0.0])
	return spots

## Schoolhouse, a yard with a court marked on it, and a rack of bikes.
static func _school(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var brick := Color(0.62, 0.38, 0.30)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.33, 0.42, 0.29))
	_slab(root, Vector2(half * 1.4, half * 0.9), Vector3(0, 0, -half * 0.5), Color(0.30, 0.30, 0.32))
	_solid(root, Vector3(half * 1.5, 6.0, half * 0.8), Vector3(0, DECK + 3.0, half * 0.55), brick)
	_box(root, Vector3(half * 1.56, 0.45, half * 0.86), Vector3(0, DECK + 6.2, half * 0.55), Color(0.30, 0.28, 0.28))
	for i in 6:
		_box(root, Vector3(1.4, 1.6, 0.12), Vector3(-half * 0.62 + half * 0.25 * float(i), DECK + 3.2, half * 0.55 - half * 0.42), GLASS)
	_box(root, Vector3(2.4, 2.8, 0.16), Vector3(0, DECK + 1.4, half * 0.55 - half * 0.42), Color(0.30, 0.22, 0.16))
	_sign(root, "SCHOOL", Vector3(0, DECK + 5.0, half * 0.55 - half * 0.44), Color(1, 0.95, 0.8))
	_paint(root, Vector2(half * 1.1, 0.25), Vector3(0, 0, -half * 0.5))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.16, 3.0, 0.16), Vector3(side * half * 0.62, DECK + 1.5, -half * 0.5), Color(0.55, 0.55, 0.58))
		_box(root, Vector3(0.1, 0.7, 1.1), Vector3(side * half * 0.62, DECK + 3.1, -half * 0.5), Color(0.9, 0.9, 0.9))
	for i in 4:
		_box(root, Vector3(0.1, 0.7, 1.2), Vector3(-half * 0.8 + 0.5 * float(i), DECK + 0.35, -half * 0.9), Color(0.3, 0.32, 0.36))
	return []

## Nave, a tower with a spire on it, and a few headstones out the side.
static func _church(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var stone := Color(0.68, 0.66, 0.60)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.34, 0.43, 0.30))
	_slab(root, Vector2(4.0, half * 1.6), Vector3(0, 0, -half * 0.2), Color(0.45, 0.44, 0.42))
	_solid(root, Vector3(half * 0.8, 7.0, half * 1.2), Vector3(0, DECK + 3.5, half * 0.35), stone)
	for side: float in [-1.0, 1.0]:
		var slope := _box(root, Vector3(half * 0.52, 0.35, half * 1.24), Vector3(side * half * 0.2, DECK + 7.6, half * 0.35), Color(0.34, 0.26, 0.24))
		slope.rotation.z = side * -0.5
	_solid(root, Vector3(half * 0.45, 12.0, half * 0.45), Vector3(0, DECK + 6.0, half * 0.35 - half * 0.75), stone.darkened(0.05))
	_box(root, Vector3(half * 0.3, 3.0, half * 0.3), Vector3(0, DECK + 13.4, half * 0.35 - half * 0.75), Color(0.32, 0.30, 0.34))
	_box(root, Vector3(0.14, 1.6, 0.14), Vector3(0, DECK + 15.6, half * 0.35 - half * 0.75), Color(0.85, 0.82, 0.6))
	_box(root, Vector3(0.9, 0.14, 0.14), Vector3(0, DECK + 15.4, half * 0.35 - half * 0.75), Color(0.85, 0.82, 0.6))
	for side: float in [-1.0, 1.0]:
		for i in 3:
			_box(root, Vector3(0.12, 2.6, 1.0), Vector3(side * half * 0.4, DECK + 3.4, half * 0.1 + 2.2 * float(i)), GLASS)
	_box(root, Vector3(1.8, 2.8, 0.16), Vector3(0, DECK + 1.4, half * 0.35 - half * 0.98), Color(0.28, 0.20, 0.14))
	for i in 6:
		_box(root, Vector3(0.5, 0.8, 0.16), Vector3(-half * 0.75 + 0.1 * float(i % 2), DECK + 0.4, -half * 0.75 + 1.5 * float(i)), Color(0.6, 0.6, 0.58))
	return []

## Tall, a canopy over the door, and a sign up the corner.
static func _hotel(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var wall := Color(0.52, 0.45, 0.40)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.32, 0.32, 0.34))
	_solid(root, Vector3(half * 1.3, 18.0, half * 1.1), Vector3(0, DECK + 9.0, half * 0.3), wall)
	_box(root, Vector3(half * 1.36, 0.5, half * 1.16), Vector3(0, DECK + 18.2, half * 0.3), Color(0.30, 0.28, 0.30))
	for row in 5:
		for i in 5:
			_box(root, Vector3(1.2, 1.4, 0.12), Vector3(-half * 0.5 + half * 0.25 * float(i), DECK + 3.0 + 3.1 * float(row), half * 0.3 - half * 0.57), GLASS)
	_box(root, Vector3(half * 0.7, 0.3, 2.6), Vector3(0, DECK + 3.4, half * 0.3 - half * 0.75), Color(0.65, 0.18, 0.20))
	for side: float in [-0.6, 0.6]:
		_box(root, Vector3(0.16, 3.2, 0.16), Vector3(side * half * 0.3, DECK + 1.6, half * 0.3 - half * 0.86), Color(0.75, 0.72, 0.6))
	_box(root, Vector3(2.8, 2.8, 0.16), Vector3(0, DECK + 1.4, half * 0.3 - half * 0.58), Color(0.35, 0.45, 0.5, 0.7))
	_box(root, Vector3(0.3, 7.0, 1.4), Vector3(-half * 0.68, DECK + 8.0, half * 0.3 - half * 0.6), Color(0.65, 0.18, 0.20))
	_sign(root, "HOTEL", Vector3(-half * 0.68, DECK + 8.0, half * 0.3 - half * 0.72), Color(1.0, 0.9, 0.6))
	for i in 2:
		spots.append([root.position + Vector3(-half * 0.5 + half * 1.0 * float(i), 0.05, -half * 0.55), PI * 0.5])
	return spots

## Three bays with red doors and a tower they hang the hoses in.
static func _firehouse(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var brick := Color(0.58, 0.30, 0.26)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.31, 0.31, 0.33))
	_solid(root, Vector3(half * 1.5, 8.0, half * 0.9), Vector3(0, DECK + 4.0, half * 0.45), brick)
	_box(root, Vector3(half * 1.56, 0.45, half * 0.96), Vector3(0, DECK + 8.2, half * 0.45), Color(0.28, 0.26, 0.26))
	for i in 3:
		_box(root, Vector3(half * 0.38, 4.6, 0.18), Vector3(-half * 0.5 + half * 0.5 * float(i), DECK + 2.3, half * 0.45 - half * 0.47), Color(0.80, 0.22, 0.18))
		_paint(root, Vector2(half * 0.38, half * 1.0), Vector3(-half * 0.5 + half * 0.5 * float(i), 0, -half * 0.35))
	_solid(root, Vector3(half * 0.3, 12.0, half * 0.3), Vector3(half * 0.72, DECK + 6.0, half * 0.45), brick.darkened(0.1))
	_box(root, Vector3(half * 0.34, 0.4, half * 0.34), Vector3(half * 0.72, DECK + 12.3, half * 0.45), Color(0.26, 0.24, 0.24))
	_sign(root, "FIRE", Vector3(0, DECK + 6.4, half * 0.45 - half * 0.48), Color(1.0, 0.85, 0.5))
	return []

## A corner bar: low, dark, a neon sign, bins round the side.
static func _bar(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var wall := Color(0.34, 0.28, 0.26)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.32, 0.32, 0.34))
	# walls rather than one solid block, so the door is a way in
	_room(root, Vector3(-half * 0.2, 0, half * 0.4), Vector3(half * 1.0, 4.6, half * 0.85), wall, 1.8)
	# the bar itself, some stools, and a light over it
	_box(root, Vector3(half * 0.62, 1.1, 0.7), Vector3(-half * 0.2, DECK + 0.62, half * 0.68), Color(0.28, 0.18, 0.12))
	_box(root, Vector3(half * 0.62, 1.9, 0.25), Vector3(-half * 0.2, DECK + 1.6, half * 0.78), Color(0.20, 0.14, 0.10))
	for i in 4:
		_box(root, Vector3(0.4, 0.9, 0.4), Vector3(-half * 0.5 + half * 0.2 * float(i), DECK + 0.45, half * 0.42), Color(0.32, 0.22, 0.16))
	for i in 2:
		_box(root, Vector3(1.4, 0.7, 1.4), Vector3(-half * 0.62 + half * 0.8 * float(i), DECK + 0.35, half * 0.05), Color(0.26, 0.20, 0.18))
	for i in 2:
		_box(root, Vector3(2.2, 1.4, 0.12), Vector3(-half * 0.6 + half * 0.55 * float(i), DECK + 2.6, half * 0.4 - half * 0.44), Color(0.55, 0.50, 0.32, 0.6))
	_box(root, Vector3(1.6, 2.6, 0.16), Vector3(half * 0.22, DECK + 1.3, half * 0.4 - half * 0.44), Color(0.22, 0.16, 0.12))
	_box(root, Vector3(2.8, 0.9, 0.16), Vector3(-half * 0.2, DECK + 3.9, half * 0.4 - half * 0.46), Color(0.85, 0.25, 0.45))
	_sign(root, "BAR", Vector3(-half * 0.2, DECK + 3.9, half * 0.4 - half * 0.55), Color(1.0, 0.5, 0.7))
	for i in 3:
		_box(root, Vector3(0.9, 1.1, 0.9), Vector3(half * 0.7, DECK + 0.55, -half * 0.1 + 1.1 * float(i)), Color(0.25, 0.32, 0.26))
	return []

## One long shed, a strip of glass, trolleys and a row of spaces.
static func _grocery(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.30, 0.30, 0.32))
	_room(root, Vector3(0, 0, half * 0.55), Vector3(half * 1.7, 6.4, half * 0.75), Color(0.74, 0.72, 0.66), 3.4)
	# aisles inside, which is the whole reason to be able to get in
	for i in 4:
		_box(root, Vector3(0.9, 1.9, half * 0.5), Vector3(-half * 0.6 + half * 0.4 * float(i), DECK + 0.95, half * 0.6), Color(0.58, 0.56, 0.52))
	_box(root, Vector3(half * 1.2, 1.0, 0.7), Vector3(0, DECK + 0.5, half * 0.28), Color(0.45, 0.44, 0.42))
	_box(root, Vector3(half * 1.4, 2.6, 0.14), Vector3(0, DECK + 1.9, half * 0.55 - half * 0.4), GLASS)
	_box(root, Vector3(half * 1.5, 0.5, 1.8), Vector3(0, DECK + 3.6, half * 0.55 - half * 0.55), Color(0.20, 0.55, 0.35))
	_sign(root, "GROCERY", Vector3(0, DECK + 5.2, half * 0.55 - half * 0.42), Color(1, 1, 0.9))
	for i in 5:
		_box(root, Vector3(0.5, 0.9, 0.7), Vector3(half * 0.9, DECK + 0.45, -half * 0.05 + 0.28 * float(i)), Color(0.62, 0.63, 0.66))
	for i in 4:
		var at := Vector3(-half * 0.9 + half * 0.6 * float(i), 0, -half * 0.55)
		_paint(root, Vector2(0.28, 5.4), at + Vector3(-half * 0.3, 0, 0))
		spots.append([root.position + at + Vector3(0, 0.05, 0), 0.0])
	return spots

# ------------------------------------------------------------
#  Districts
# ------------------------------------------------------------
## Four houses round a dead end off the road, with cars on the drives.
static func _houses(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	# the cul-de-sac: in off the road on the west side, bulb at the far end
	_slab(root, Vector2(20.0, 7.0), Vector3(-4.0, 0, 0), TARMAC)
	_slab(root, Vector2(11.0, 11.0), Vector3(4.5, 0, 0), TARMAC)
	_paint(root, Vector2(0.35, 5.0), Vector3(-11.0, 0, 0))

	for i in 4:
		var side := 1.0 if i % 2 == 0 else -1.0
		var along := -6.0 if i < 2 else 3.0
		var here := Vector3(along, 0, side * 5.6)
		_slab(root, Vector2(8.6, 6.4), here + Vector3(0, 0, side * 0.6), Color(0.31, 0.42, 0.27))
		_house(root, here, side, HOUSES[rng.randi() % HOUSES.size()],
			ROOFS[rng.randi() % ROOFS.size()], rng)
		# a drive, but nothing parks on it: these blocks are eighteen metres
		# across and a car is seven long, so anything left here ends up in
		# somebody's front room
		_slab(root, Vector2(3.2, 3.2), here + Vector3(0, 0, -side * 3.0), Color(0.4, 0.4, 0.42))
	return spots

static func _house(root: Node3D, at: Vector3, side: float, wall: Color,
		roof: Color, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(5.8, 6.8)
	var d := rng.randf_range(4.8, 5.6)
	var h := rng.randf_range(3.2, 4.2)
	_solid(root, Vector3(w, h, d), at + Vector3(0, DECK + h * 0.5, 0), wall)
	_box(root, Vector3(w + 0.7, 0.45, d + 0.7), at + Vector3(0, DECK + h + 0.22, 0), roof)
	_box(root, Vector3(w * 0.55, 0.5, d * 0.55), at + Vector3(0, DECK + h + 0.6, 0), roof.darkened(0.15))
	# a door and a window facing the street
	var face := -side * (d * 0.5 + 0.06)
	_box(root, Vector3(1.0, 2.0, 0.12), at + Vector3(-w * 0.22, DECK + 1.0, face), roof.darkened(0.3))
	_box(root, Vector3(1.6, 1.1, 0.12), at + Vector3(w * 0.25, DECK + 2.0, face), GLASS)
	# a low fence round the front
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.12, 0.9, d * 0.8), at + Vector3(sx * (w * 0.5 + 1.1), DECK + 0.45, -side * 0.6),
			Color(0.62, 0.6, 0.55))
	# a step up to the door, a porch light beside it, and a chimney
	_box(root, Vector3(1.6, 0.18, 0.9), at + Vector3(-w * 0.22, DECK + 0.09, face - side * 0.45),
		wall.darkened(0.25))
	_box(root, Vector3(0.18, 0.28, 0.18), at + Vector3(-w * 0.22 + 0.75, DECK + 2.15, face),
		Color(0.95, 0.88, 0.62))
	_box(root, Vector3(0.7, 1.5, 0.7), at + Vector3(w * 0.3, DECK + h + 0.8, d * 0.18),
		wall.darkened(0.18))
	_box(root, Vector3(0.85, 0.2, 0.85), at + Vector3(w * 0.3, DECK + h + 1.6, d * 0.18),
		Color(0.28, 0.26, 0.26))
	# an upstairs window, and a number by the door
	_box(root, Vector3(1.0, 0.8, 0.12), at + Vector3(-w * 0.2, DECK + h - 0.6, face), GLASS)
	_box(root, Vector3(0.9, 0.7, 0.12), at + Vector3(w * 0.25, DECK + h - 0.6, face), GLASS)
	# a bin at the kerb side of the drive
	_box(root, Vector3(0.6, 0.9, 0.6), at + Vector3(w * 0.5 + 0.4, DECK + 0.45, -side * (d * 0.5 + 0.9)),
		Color(0.25, 0.32, 0.26))

## A few towers with a setback, glazed at street level.
static func _towers(root: Node3D, rng: RandomNumberGenerator) -> void:
	var slots := [Vector3(-5.0, 0, -5.0), Vector3(5.0, 0, 4.0), Vector3(-4.0, 0, 6.0)]
	for at in slots:
		var w := rng.randf_range(7.0, 9.0)
		var d := rng.randf_range(7.0, 9.0)
		var h := rng.randf_range(16.0, 30.0)
		var col: Color = WALLS[rng.randi() % WALLS.size()]
		_solid(root, Vector3(w, h, d), at + Vector3(0, DECK + h * 0.5, 0), col)
		_box(root, Vector3(w * 0.72, 4.0, d * 0.72), at + Vector3(0, DECK + h + 2.0, 0), col.darkened(0.15))
		_box(root, Vector3(w + 0.5, 0.5, d + 0.5), at + Vector3(0, DECK + h + 0.25, 0), col.darkened(0.45))
		# glazing bands, so they are not just slabs
		for level in range(2, int(h / 4.0)):
			_box(root, Vector3(w + 0.08, 1.6, d + 0.08),
				at + Vector3(0, DECK + float(level) * 4.0, 0), GLASS)

## A terrace of shopfronts facing the street, with an alley and a delivery bay.
static func _shops(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var names := ["LAUNDRY", "PAWN", "GROCER", "LIQUOR", "TYRES", "DINER", "PHONES"]
	names.shuffle()
	var run := -half + 1.0
	var i := 0
	while run < half - 3.4 and i < names.size():
		var w: float = rng.randf_range(3.4, 4.6)
		var h: float = rng.randf_range(4.5, 7.0)
		var col: Color = WALLS[rng.randi() % WALLS.size()]
		var at := Vector3(run + w * 0.5, 0, -4.0)
		_solid(root, Vector3(w, h, 9.0), at + Vector3(0, DECK + h * 0.5, 0), col)
		_box(root, Vector3(w - 0.5, 2.4, 0.14), at + Vector3(0, DECK + 1.3, -4.6), GLASS)
		# an awning over the glass, striped by alternating the colour
		_box(root, Vector3(w - 0.2, 0.16, 1.5), at + Vector3(0, DECK + 2.8, -5.3),
			col.lightened(0.25) if i % 2 == 0 else col.darkened(0.25))
		# a door beside the window, and a board on the pavement
		_box(root, Vector3(0.9, 2.1, 0.12), at + Vector3(w * 0.32, DECK + 1.05, -4.62),
			col.darkened(0.4))
		if i % 2 == 0:
			_box(root, Vector3(0.7, 0.9, 0.5), at + Vector3(-w * 0.2, DECK + 0.45, -6.4),
				Color(0.35, 0.30, 0.24))
		_box(root, Vector3(w - 0.2, 0.5, 1.6), at + Vector3(0, DECK + 3.0, -5.2), col.darkened(0.4))
		_sign(root, String(names[i]), at + Vector3(0, DECK + 3.9, -4.9))
		run += w + 0.4
		i += 1
	# service road along the back, with the skips on it and room to park
	_slab(root, Vector2(half * 2.0, 6.0), Vector3(0, 0, 5.0), TARMAC)
	for k in 2:
		StreetKit.dumpster(root, Vector3(-7.0 + float(k) * 4.0, DECK, 7.6), 0.0,
			Color(0.24, 0.36, 0.3) if k == 0 else Color(0.42, 0.3, 0.24))
	# two spaces, not three: a car is seven metres long and parking them four
	# and a half apart puts one through the other
	for sx: float in [-4.5, 4.5]:
		spots.append([root.position + Vector3(sx, 0.05, 4.6), PI * 0.5])
	return spots

## A shed, a yard, containers, and a fence you can see through the gate of.
static func _warehouse(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.24, 0.24, 0.25))
	var col := Color(0.66, 0.67, 0.68)
	_solid(root, Vector3(16.0, 7.0, 9.0), Vector3(0, DECK + 3.5, 3.5), col)
	_box(root, Vector3(16.6, 0.5, 9.6), Vector3(0, DECK + 7.2, 3.5), col.darkened(0.4))
	# roller doors along the loading side
	for k in 3:
		var x := -5.0 + float(k) * 5.0
		_box(root, Vector3(3.4, 3.6, 0.16), Vector3(x, DECK + 1.8, -1.1), Color(0.7, 0.68, 0.62))
		_box(root, Vector3(4.2, 0.5, 1.4), Vector3(x, DECK + 4.0, -1.6), col.darkened(0.3))
	_sign(root, "PALLETS & FREIGHT", Vector3(0, DECK + 8.4, -1.0), Color(0.9, 0.8, 0.4))
	# containers stacked in the yard
	for k in 4:
		var cx := -7.0 + float(k) * 4.6
		var stack := 1 if rng.randf() < 0.6 else 2
		for level in stack:
			_solid(root, Vector3(3.4, 2.6, 7.2),
				Vector3(cx, DECK + 1.3 + float(level) * 2.65, -6.0),
				Color(rng.randf_range(0.25, 0.7), rng.randf_range(0.25, 0.5), rng.randf_range(0.2, 0.4)))
	# fence down the open sides with a gap to drive in through
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.2, 2.4, half * 2.0), Vector3(sx * half, DECK + 1.2, 0), Color(0.58, 0.6, 0.58))
	_box(root, Vector3(6.0, 2.4, 0.2), Vector3(-half + 3.0, DECK + 1.2, -half), Color(0.58, 0.6, 0.58))
	# the yard is containers end to end, so the only room left is behind the
	# shed where the fence does not run
	spots.append([root.position + Vector3(0.0, 0.05, 8.0), PI * 0.5])
	return spots

## Asphalt, painted bays, a low wall, and a light on a post.
static func _lot(root: Node3D, _rng: RandomNumberGenerator) -> Array:
	var spots := []
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, TARMAC)
	# Four lines, three spaces, and the spaces are wide. A car is 2.8m across
	# and you have to be able to stand at the driver's door of one with another
	# beside it -- three-metre bays put the next car's wing where your elbow
	# needs to be and nothing in the middle of the row can be worked on.
	for row in 2:
		var z := -4.6 + float(row) * 9.2
		for bay in 4:
			var x := -7.2 + float(bay) * 4.8
			_paint(root, Vector2(0.2, 5.0), Vector3(x, 0, z))
			if bay < 3:
				spots.append([root.position + Vector3(x + 2.4, 0.05, z), 0.0])
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.4, 1.0, half * 2.0), Vector3(sx * half, DECK + 0.5, 0), Color(0.6, 0.58, 0.54))
	_box(root, Vector3(0.3, 6.0, 0.3), Vector3(0, DECK + 3.0, 0), Color(0.3, 0.3, 0.32))
	_box(root, Vector3(1.6, 0.3, 0.5), Vector3(0, DECK + 6.0, 0), Color(0.9, 0.88, 0.7))
	return spots

## A filling station: canopy, pumps, a kiosk and a price board. Nothing here
## works yet -- it is somewhere to drive past and somewhere to leave a car.
static func _fuel(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.30, 0.30, 0.31))
	# the canopy, up on four legs
	var canopy := Color(0.86, 0.84, 0.80)
	_box(root, Vector3(half * 1.9, 0.7, 11.0), Vector3(0, DECK + 5.4, -2.5), canopy)
	_box(root, Vector3(half * 1.94, 0.4, 11.2), Vector3(0, DECK + 5.85, -2.5), Color(0.80, 0.30, 0.22))
	for sx: float in [-half * 0.85, half * 0.85]:
		for sz: float in [-7.4, 2.4]:
			_solid(root, Vector3(0.5, 5.4, 0.5), Vector3(sx, DECK + 2.7, sz), Color(0.7, 0.7, 0.68))
	# two islands with a pump on each
	for sx: float in [-7.5, -2.5, 2.5, 7.5]:
		_box(root, Vector3(3.4, 0.3, 3.0), Vector3(sx, DECK + 0.15, -2.5), Color(0.62, 0.6, 0.56))
		_solid(root, Vector3(0.9, 1.9, 0.7), Vector3(sx, DECK + 1.25, -2.5), Color(0.86, 0.82, 0.78))
		_box(root, Vector3(0.7, 0.6, 0.1), Vector3(sx, DECK + 1.7, -2.9), Color(0.15, 0.2, 0.25))
		_box(root, Vector3(0.16, 0.5, 0.16), Vector3(sx + 0.55, DECK + 1.5, -2.5), Color(0.3, 0.3, 0.32))
	# the kiosk behind it
	_solid(root, Vector3(half * 1.0, 3.6, 5.0), Vector3(0, DECK + 1.8, half * 0.62), Color(0.72, 0.70, 0.64))
	_box(root, Vector3(half * 1.04, 0.4, 5.4), Vector3(0, DECK + 3.8, half * 0.62), Color(0.80, 0.30, 0.22))
	_box(root, Vector3(half * 0.75, 2.0, 0.14), Vector3(0, DECK + 1.6, half * 0.62 - 2.55), GLASS)
	_sign(root, "GAS", Vector3(0, DECK + 4.6, half * 0.62), Color(1.0, 0.85, 0.4))
	# price board out by the pavement
	_box(root, Vector3(0.4, 4.0, 0.4), Vector3(-7.5, DECK + 2.0, -8.0), Color(0.4, 0.4, 0.42))
	_box(root, Vector3(2.6, 1.8, 0.3), Vector3(-7.5, DECK + 4.4, -8.0), Color(0.80, 0.30, 0.22))
	_sign(root, "SELF SERVE
$4.19", Vector3(-7.5, DECK + 4.5, -8.2), Color(1, 1, 0.85))
	# pulled up alongside the pumps, not parked on top of one
	# a car at each pump, and the forecourt is open both sides so you can get
	# in off either street rather than threading a gap
	for sx: float in [-7.5, -2.5, 2.5, 7.5]:
		spots.append([root.position + Vector3(sx, 0.05, -5.6), 0.0])
	return spots

## Grass, a path across it, and some trees.
static func _park(root: Node3D, rng: RandomNumberGenerator) -> void:
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.30, 0.42, 0.26))
	_slab(root, Vector2(half * 2.0, 2.4), Vector3.ZERO, Color(0.55, 0.52, 0.45))
	for i in 7:
		var at := Vector3(rng.randf_range(-7.5, 7.5), 0, rng.randf_range(-7.5, 7.5))
		if absf(at.z) < 2.2:
			continue
		var h := rng.randf_range(3.0, 5.0)
		_box(root, Vector3(0.5, h, 0.5), at + Vector3(0, DECK + h * 0.5, 0), Color(0.32, 0.24, 0.18))
		var c := rng.randf_range(2.4, 3.6)
		_box(root, Vector3(c, c * 0.8, c), at + Vector3(0, DECK + h + c * 0.3, 0),
			Color(0.22, rng.randf_range(0.36, 0.5), 0.2))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(1.8, 0.15, 0.6), Vector3(sx * 3.0, DECK + 0.45, 1.8), Color(0.45, 0.32, 0.2))
		_box(root, Vector3(1.8, 0.5, 0.15), Vector3(sx * 3.0, DECK + 0.7, 2.05), Color(0.45, 0.32, 0.2))

# ------------------------------------------------------------
#  Bits and pieces
# ------------------------------------------------------------
## A flat surface laid on the deck: tarmac, grass, a driveway.
static func _slab(parent: Node3D, size: Vector2, at: Vector3, colour: Color) -> void:
	_box(parent, Vector3(size.x, 0.12, size.y), at + Vector3(0, DECK - 0.055, 0), colour)

## A painted line on one of those.
static func _paint(parent: Node3D, size: Vector2, at: Vector3) -> void:
	_box(parent, Vector3(size.x, 0.12, size.y), at + Vector3(0, DECK - 0.035, 0), PAINT)

static func _sign(parent: Node3D, text: String, at: Vector3,
		colour: Color = Color(0.95, 0.9, 0.75)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 42
	l.pixel_size = 0.011
	l.modulate = colour
	l.outline_size = 12
	# turned to whoever is reading it, the same as every other sign in the
	# place: hung flat it comes out mirrored from one side of the street
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	parent.add_child(l)

## Something you can walk into.
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

## Something you cannot.
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
