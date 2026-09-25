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
## A shopfront you can see through to whoever is inside.
const GLASS_CLEAR := Color(0.62, 0.74, 0.80, 0.28)

## Where the front door of the last thing built is, in the world, or INF if
## it did not say. People sent on errands go there.
static var door := Vector3.INF
## The ceiling lights in every room anybody can walk into. DayNight switches on
## the few nearest the player; the rest stay dark.
static var interior_lights: Array[OmniLight3D] = []

## The plot on each axis on its own. `half` is the smaller of the two, which
## is what most builders work to; a car park uses all of it.
static var plot_x := HALF
static var plot_z := HALF

## Build `kind` at `centre`. Returns the parking spots it made, each
## [position, yaw], for whoever wants to leave a car in them -- or
## [position, yaw, info] when the spot is a marked bay that says which way a
## car goes into it.
static func build(parent: Node3D, kind: String, centre: Vector3,
		rng: RandomNumberGenerator, plot: float = HALF, px: float = -1.0, pz: float = -1.0) -> Array:
	half = maxf(6.0, plot)
	plot_x = px if px > 0.0 else half
	plot_z = pz if pz > 0.0 else half
	door = Vector3.INF
	var root := Node3D.new()
	root.position = centre
	parent.add_child(root)
	match kind:
		"houses":
			return _houses(root, rng)
		"towers":
			return _towers(root, rng)
		"shops":
			return _shops(root, rng)
		"warehouse":
			return _warehouse(root, rng)
		"lot":
			return _lot(root)
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
##
## `front` with any alpha makes the front wall a shopfront: glass either side
## of the door, in a frame, so what goes on inside can be seen from the street.
## `skin` is what the other walls are drawn with (a facade, usually). A room is
## lit inside unless told otherwise.
static func _room(root: Node3D, at: Vector3, span: Vector3, wall: Color,
		door_w: float, front: Color = Color(0, 0, 0, 0), skin: Material = null,
		lit: bool = true) -> void:
	var t := 0.3
	var hx: float = span.x * 0.5
	var hz: float = span.z * 0.5
	# floor and roof
	_box(root, Vector3(span.x - t, 0.12, span.z - t), at + Vector3(0, DECK + 0.06, 0), wall.darkened(0.35))
	_solid(root, Vector3(span.x + t, 0.3, span.z + t), at + Vector3(0, DECK + span.y, 0), wall.darkened(0.2))
	# back and two sides
	_solid(root, Vector3(span.x, span.y, t), at + Vector3(0, DECK + span.y * 0.5, hz), wall, skin)
	_solid(root, Vector3(t, span.y, span.z), at + Vector3(-hx, DECK + span.y * 0.5, 0), wall, skin)
	_solid(root, Vector3(t, span.y, span.z), at + Vector3(hx, DECK + span.y * 0.5, 0), wall, skin)
	if skin != null:
		# the facade is on both faces of a wall, and from inside its windows read
		# as screens hung on the plaster: line the room in plain wall
		var y := DECK + span.y * 0.5
		_box(root, Vector3(span.x - t - 0.04, span.y - 0.25, 0.02), at + Vector3(0, y - 0.05, hz - t * 0.5 - 0.02), wall)
		for sx: float in [-1.0, 1.0]:
			_box(root, Vector3(0.02, span.y - 0.25, span.z - t - 0.04), at + Vector3(sx * (hx - t * 0.5 - 0.02), y - 0.05, 0), wall)
	# the front, in two pieces with the doorway between them
	var side: float = (span.x - door_w) * 0.5
	var head := minf(span.y, 2.7)
	var frame := wall.darkened(0.45)
	for sx: float in [-1.0, 1.0]:
		var mid := at + Vector3(sx * (hx - side * 0.5), 0, -hz)
		if front.a <= 0.0:
			_solid(root, Vector3(side, span.y, t), mid + Vector3(0, DECK + span.y * 0.5, 0), wall, skin)
			continue
		# glass to the height of the door, wall above it
		_solid(root, Vector3(side, head, 0.1), mid + Vector3(0, DECK + head * 0.5, 0), front)
		if span.y > head + 0.05:
			_solid(root, Vector3(side, span.y - head, t),
				mid + Vector3(0, DECK + head + (span.y - head) * 0.5, 0), wall, skin)
		# a sill, and mullions a couple of metres apart
		_box(root, Vector3(side, 0.35, 0.2), mid + Vector3(0, DECK + 0.175, 0), frame)
		_box(root, Vector3(side, 0.1, 0.2), mid + Vector3(0, DECK + head, 0), frame)
		var panes := maxi(1, int(round(side / 2.2)))
		for k in panes + 1:
			var x := -side * 0.5 + side * float(k) / float(panes)
			_box(root, Vector3(0.1, head, 0.18), mid + Vector3(x, DECK + head * 0.5, 0), frame)
	# a lintel over the gap, so it reads as a doorway rather than a hole
	if span.y > head + 0.05:
		_box(root, Vector3(door_w, span.y - head, t * 0.8),
			at + Vector3(0, DECK + head + (span.y - head) * 0.5, -hz), wall.darkened(0.1))
	if lit:
		_interior_light(root, at + Vector3(0, DECK + span.y - 0.2, 0), span)

## The inner faces of a room built with `_room` at `at`, `span`: where the back
## wall and the glass are, for putting furniture and people against them.
static func _inside(at: Vector3, span: Vector3) -> Dictionary:
	return {
		"back": at.z + span.z * 0.5 - 0.15,
		"front": at.z - span.z * 0.5 + 0.15,
		"left": at.x - span.x * 0.5 + 0.15,
		"right": at.x + span.x * 0.5 - 0.15,
	}

## A ground floor you can walk into, with a desk across the back of it and
## somebody behind the desk: the lobby under a tower, a hotel reception, a
## police front counter. Returns the room's inner faces.
static func _lobby(root: Node3D, at: Vector3, span: Vector3, wall: Color,
		skin: Material, desk_col: Color, job: String, glass: bool = true) -> Dictionary:
	_room(root, at, span, wall, 2.4, GLASS_CLEAR if glass else Color(0, 0, 0, 0), skin)
	var room := _inside(at, span)
	var back: float = room.back
	var front: float = room.front
	# the desk, with a lighter top and a panel down the front
	var desk_z := back - 2.5
	var desk_w := minf(span.x * 0.34, 4.2)
	_solid(root, Vector3(desk_w, 1.08, 0.75), Vector3(at.x, DECK + 0.54, desk_z), desk_col)
	_box(root, Vector3(desk_w + 0.1, 0.06, 0.85), Vector3(at.x, DECK + 1.11, desk_z), desk_col.lightened(0.35))
	_box(root, Vector3(0.5, 0.35, 0.05), Vector3(at.x - 0.6, DECK + 1.32, desk_z + 0.1), Color(0.12, 0.12, 0.14))
	_box(root, Vector3(0.5, 0.35, 0.05), Vector3(at.x + 0.9, DECK + 1.32, desk_z + 0.1), Color(0.12, 0.12, 0.14))
	# filing and a pair of lift doors on the back wall
	_box(root, Vector3(1.2, 1.8, 0.5), Vector3(at.x - desk_w * 0.5 - 0.6, DECK + 0.9, back - 0.3), Color(0.42, 0.42, 0.44))
	for k in 2:
		var lx: float = room.right - 1.4 - float(k) * 1.7
		_box(root, Vector3(1.3, 2.3, 0.06), Vector3(lx, DECK + 1.15, back - 0.03), Color(0.62, 0.63, 0.66))
		_box(root, Vector3(0.02, 2.3, 0.08), Vector3(lx, DECK + 1.15, back - 0.04), Color(0.3, 0.3, 0.32))
	# somewhere to wait: two chairs and a plant by the glass
	var wait_x: float = room.left + 1.4
	for k in 2:
		_box(root, Vector3(0.9, 0.45, 0.9), Vector3(wait_x, DECK + 0.22, front + 2.0 + float(k) * 1.4), Color(0.32, 0.30, 0.36))
		_box(root, Vector3(0.2, 0.9, 0.9), Vector3(wait_x - 0.45, DECK + 0.45, front + 2.0 + float(k) * 1.4), Color(0.30, 0.28, 0.34))
	_box(root, Vector3(0.6, 0.6, 0.6), Vector3(room.right - 0.7, DECK + 0.3, front + 0.9), Color(0.5, 0.42, 0.34))
	_box(root, Vector3(0.9, 1.1, 0.9), Vector3(room.right - 0.7, DECK + 1.1, front + 0.9), Color(0.22, 0.42, 0.24))

	# who works here
	var staff_z := back - 1.55
	var n := _staff_seed(root)
	Staff.hire(root, job, [
		[Vector3(at.x - 0.6, 0, staff_z), PI, "type", Vector2(10.0, 22.0)],
		[Vector3(at.x - desk_w * 0.5 - 0.6, 0, back - 0.95), 0.0, "stock", Vector2(3.0, 6.0)],
		[Vector3(at.x - 1.5, 0, staff_z), PI, "serve", Vector2(5.0, 10.0)],
	], n)
	if span.x > 11.0:
		Staff.hire(root, job, [
			[Vector3(at.x + 0.9, 0, staff_z), PI, "type", Vector2(8.0, 18.0)],
			[Vector3(at.x + 0.2, 0, staff_z), PI, "serve", Vector2(4.0, 9.0)],
		], n + 1)
	# and somebody waiting
	Staff.hire(root, "patron", [
		[Vector3(wait_x + 0.1, 0, front + 2.0), PI * 0.5, "sit", Vector2(30.0, 60.0)],
	], n + 2)
	return room

# ------------------------------------------------------------
#  Civic buildings
# ------------------------------------------------------------
## The station. A front counter you can walk up to with the desk sergeant
## behind it, offices over the top, marked bays down the near side, a blue lamp
## at the door and a flag on a pole. Posting officers outside it is the world's
## job; this says where the door is.
static func _police(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var stone := Color(0.55, 0.55, 0.58)
	var skin := _facade(stone, {"storey": 3.0, "bay": 2.6, "first_floor": 0.9,
		"win_w": 0.5, "win_h": 0.5, "glass": Color(0.2, 0.24, 0.3)})
	var upper := _facade(stone, {"storey": 2.6, "bay": 2.6, "first_floor": 0.35,
		"parapet": 0.4, "win_w": 0.5, "win_h": 0.55, "glass": Color(0.2, 0.24, 0.3), "seed": 3.0})
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.34, 0.34, 0.36))
	var at := Vector3(-half * 0.35, 0, half * 0.35)
	var span := Vector3(half * 1.1, 4.0, half * 0.95)
	var room := _inside(at, span)
	_room(root, at, span, stone, 1.8, Color(0, 0, 0, 0), skin)
	# offices upstairs, and a cornice
	_solid(root, Vector3(span.x, 3.4, span.z), at + Vector3(0, DECK + 4.15 + 1.7, 0), stone, upper)
	_box(root, Vector3(span.x + 0.4, 0.45, span.z + 0.4), at + Vector3(0, DECK + 7.7, 0), Color(0.28, 0.30, 0.36))
	# the garage round the side
	var garage := _facade(stone.darkened(0.08), {"windows_z": 0.0, "first_floor": 1.4, "storey": 2.0})
	_solid(root, Vector3(half * 0.7, 4.4, half * 0.7), Vector3(half * 0.56, DECK + 2.2, half * 0.5), stone.darkened(0.08), garage)
	# the front counter, the sergeant behind it, and a bench to wait on
	var counter_z: float = room.front + 2.6
	_solid(root, Vector3(span.x * 0.6, 1.15, 0.6), Vector3(at.x, DECK + 0.575, counter_z), Color(0.36, 0.30, 0.24))
	_box(root, Vector3(span.x * 0.6, 0.6, 0.06), Vector3(at.x, DECK + 1.5, counter_z), Color(0.7, 0.8, 0.85, 0.35))
	_box(root, Vector3(2.4, 0.45, 0.5), Vector3(room.left + 1.6, DECK + 0.22, room.front + 0.5), Color(0.3, 0.3, 0.34))
	_box(root, Vector3(1.6, 1.0, 0.05), Vector3(room.right - 1.4, DECK + 1.6, room.back - 0.03), Color(0.6, 0.52, 0.36))
	for k in 2:
		_box(root, Vector3(1.4, 0.75, 0.8), Vector3(at.x - 2.0 + float(k) * 4.0, DECK + 0.38, room.back - 1.2), Color(0.4, 0.36, 0.3))
	var n := _staff_seed(root)
	Staff.hire(root, "police", [
		[Vector3(at.x - 0.8, 0, counter_z + 0.95), PI, "type", Vector2(10.0, 24.0)],
		[Vector3(at.x + 1.2, 0, counter_z + 0.95), PI, "serve", Vector2(4.0, 9.0)],
		[Vector3(room.right - 1.4, 0, room.back - 0.7), 0.0, "stand", Vector2(4.0, 8.0)],
	], n)
	Staff.hire(root, "police", [
		[Vector3(at.x - 2.0, 0, room.back - 1.95), 0.0, "type", Vector2(20.0, 40.0)],
	], n + 1)
	Staff.hire(root, "patron", [
		[Vector3(room.left + 1.2, 0, room.front + 0.95), PI, "sit", Vector2(30.0, 60.0)],
	], n + 2)
	# steps, the blue lamp, a flag
	_box(root, Vector3(4.0, 0.3, 1.2), Vector3(at.x, DECK + 0.15, room.front - 0.8), stone.lightened(0.1))
	_box(root, Vector3(0.5, 0.5, 0.5), Vector3(at.x, DECK + 3.2, room.front - 0.45), Color(0.2, 0.35, 0.9))
	_box(root, Vector3(0.16, 6.0, 0.16), Vector3(-half * 0.85, DECK + 3.0, -half * 0.2), Color(0.8, 0.8, 0.82))
	_box(root, Vector3(0.1, 1.0, 1.6), Vector3(-half * 0.85, DECK + 5.4, -half * 0.2 + 0.85), Color(0.55, 0.15, 0.18))
	_sign(root, "POLICE", Vector3(at.x, DECK + 5.4, room.front - 0.5), Color(0.65, 0.8, 1.0))
	door = root.position + Vector3(at.x, 0, room.front - 1.2)
	for i in 3:
		var bay := Vector3(-half + 3.4 + 4.6 * float(i), 0, -half + 4.2)
		_paint(root, Vector2(0.3, 5.6), bay + Vector3(-2.2, 0, 0))
		spots.append([root.position + bay + Vector3(0, 0.05, 0), 0.0])
	return spots

## Schoolhouse, a yard with a court marked on it, and a rack of bikes.
static func _school(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var brick := Color(0.62, 0.38, 0.30)
	var skin := _facade(brick, {"storey": 3.0, "bay": 2.4, "first_floor": 0.6, "parapet": 0.6,
		"win_w": 0.66, "win_h": 0.6, "trim": Color(0.86, 0.84, 0.78), "glass": Color(0.22, 0.28, 0.34)})
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.33, 0.42, 0.29))
	_slab(root, Vector2(half * 1.4, half * 0.9), Vector3(0, 0, -half * 0.5), Color(0.30, 0.30, 0.32))
	_solid(root, Vector3(half * 1.5, 7.2, half * 0.8), Vector3(0, DECK + 3.6, half * 0.55), brick, skin)
	_pitched(root, Vector3(half * 1.56, 2.2, half * 0.86), Vector3(0, DECK + 7.2, half * 0.55), Color(0.30, 0.28, 0.28))
	_box(root, Vector3(2.4, 2.8, 0.16), Vector3(0, DECK + 1.4, half * 0.55 - half * 0.42), Color(0.30, 0.22, 0.16))
	_sign(root, "SCHOOL", Vector3(0, DECK + 3.6, half * 0.55 - half * 0.44), Color(1, 0.95, 0.8))
	_paint(root, Vector2(half * 1.1, 0.25), Vector3(0, 0, -half * 0.5))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.16, 3.0, 0.16), Vector3(side * half * 0.62, DECK + 1.5, -half * 0.5), Color(0.55, 0.55, 0.58))
		_box(root, Vector3(0.1, 0.7, 1.1), Vector3(side * half * 0.62, DECK + 3.1, -half * 0.5), Color(0.9, 0.9, 0.9))
	for i in 4:
		_box(root, Vector3(0.1, 0.7, 1.2), Vector3(-half * 0.8 + 0.5 * float(i), DECK + 0.35, -half * 0.9), Color(0.3, 0.32, 0.36))
	door = root.position + Vector3(0, 0, half * 0.55 - half * 0.42 - 1.0)
	return []

## Nave under a proper pitched roof, a tower with a spire on it, and a few
## headstones out the side.
static func _church(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var stone := Color(0.68, 0.66, 0.60)
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.34, 0.43, 0.30))
	_slab(root, Vector2(4.0, half * 1.6), Vector3(0, 0, -half * 0.2), Color(0.45, 0.44, 0.42))
	_solid(root, Vector3(half * 0.8, 7.0, half * 1.2), Vector3(0, DECK + 3.5, half * 0.35), stone)
	_pitched(root, Vector3(half * 0.9, 4.2, half * 1.26), Vector3(0, DECK + 7.0, half * 0.35), Color(0.34, 0.26, 0.24), false)
	_solid(root, Vector3(half * 0.45, 12.0, half * 0.45), Vector3(0, DECK + 6.0, half * 0.35 - half * 0.75), stone.darkened(0.05))
	_box(root, Vector3(half * 0.3, 3.0, half * 0.3), Vector3(0, DECK + 13.4, half * 0.35 - half * 0.75), Color(0.32, 0.30, 0.34))
	_pitched(root, Vector3(half * 0.34, 5.0, half * 0.34), Vector3(0, DECK + 14.9, half * 0.35 - half * 0.75), Color(0.30, 0.32, 0.36), false)
	_box(root, Vector3(0.14, 1.6, 0.14), Vector3(0, DECK + 20.6, half * 0.35 - half * 0.75), Color(0.85, 0.82, 0.6))
	_box(root, Vector3(0.9, 0.14, 0.14), Vector3(0, DECK + 20.4, half * 0.35 - half * 0.75), Color(0.85, 0.82, 0.6))
	for side: float in [-1.0, 1.0]:
		for i in 3:
			_box(root, Vector3(0.12, 2.6, 1.0), Vector3(side * half * 0.4, DECK + 3.4, half * 0.1 + 2.2 * float(i)), Color(0.45, 0.35, 0.6, 0.8))
	_box(root, Vector3(1.8, 2.8, 0.16), Vector3(0, DECK + 1.4, half * 0.35 - half * 0.98), Color(0.28, 0.20, 0.14))
	for i in 6:
		_box(root, Vector3(0.5, 0.8, 0.16), Vector3(-half * 0.75 + 0.1 * float(i % 2), DECK + 0.4, -half * 0.75 + 1.5 * float(i)), Color(0.6, 0.6, 0.58))
	door = root.position + Vector3(0, 0, half * 0.35 - half * 0.98 - 1.0)
	return []

## A proper hotel: a tall block over a glass-fronted lobby, reception staffed,
## a canopy over the door and a sign up the corner.
static func _hotel(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var wall := Color(0.52, 0.45, 0.40)
	var skin := _facade(wall, {"storey": 3.1, "bay": 2.6, "win_w": 0.55, "win_h": 0.55,
		"parapet": 1.0, "lit_share": 0.6, "trim": Color(0.84, 0.8, 0.7), "glass": Color(0.18, 0.2, 0.26)})
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.32, 0.32, 0.34))
	var at := Vector3(0, 0, half * 0.3)
	var span := Vector3(half * 1.3, 5.0, half * 1.1)
	var room := _lobby(root, at, span, wall.darkened(0.1), skin, Color(0.42, 0.24, 0.16), "reception")
	var tall := rng.randf_range(22.0, 30.0)
	_solid(root, Vector3(span.x, tall - 5.15, span.z), at + Vector3(0, DECK + 5.15 + (tall - 5.15) * 0.5, 0), wall, skin)
	_box(root, Vector3(span.x + 0.5, 0.6, span.z + 0.5), at + Vector3(0, DECK + tall + 0.3, 0), Color(0.30, 0.28, 0.30))
	_roof_kit(root, at + Vector3(0, DECK + tall + 0.6, 0), Vector2(span.x, span.z), rng)
	# canopy out over the pavement side of the door, on two brass posts
	_box(root, Vector3(half * 0.55, 0.3, 2.6), Vector3(0, DECK + 3.4, room.front - 1.3), Color(0.65, 0.18, 0.20))
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(0.14, 3.3, 0.14), Vector3(sx * 1.6, DECK + 1.65, room.front - 2.4), Color(0.78, 0.66, 0.36))
	_box(root, Vector3(0.3, 7.0, 1.4), Vector3(-span.x * 0.5 - 0.15, DECK + 9.0, room.front + 1.0), Color(0.65, 0.18, 0.20))
	_sign(root, "HOTEL", Vector3(-span.x * 0.5 - 0.4, DECK + 9.0, room.front + 1.0), Color(1.0, 0.9, 0.6))
	door = root.position + Vector3(0, 0, room.front - 1.2)
	for i in 2:
		spots.append([root.position + Vector3(-half * 0.5 + half * 1.0 * float(i), 0.05, -half * 0.55), PI * 0.5])
	return spots

## Three bays with red doors and a tower they hang the hoses in.
static func _firehouse(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var brick := Color(0.58, 0.30, 0.26)
	var skin := _facade(brick, {"storey": 2.0, "bay": 2.4, "first_floor": 5.4, "parapet": 0.8,
		"win_w": 0.55, "win_h": 0.6, "trim": Color(0.82, 0.8, 0.74)})
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.31, 0.31, 0.33))
	_solid(root, Vector3(half * 1.5, 8.0, half * 0.9), Vector3(0, DECK + 4.0, half * 0.45), brick, skin)
	_box(root, Vector3(half * 1.56, 0.45, half * 0.96), Vector3(0, DECK + 8.2, half * 0.45), Color(0.28, 0.26, 0.26))
	for i in 3:
		_box(root, Vector3(half * 0.38, 4.6, 0.18), Vector3(-half * 0.5 + half * 0.5 * float(i), DECK + 2.3, half * 0.45 - half * 0.47), Color(0.80, 0.22, 0.18))
		for k in 4:
			_box(root, Vector3(half * 0.38, 0.05, 0.2), Vector3(-half * 0.5 + half * 0.5 * float(i), DECK + 0.8 + float(k) * 1.1, half * 0.45 - half * 0.47), Color(0.62, 0.16, 0.14))
		_paint(root, Vector2(half * 0.38, half * 1.0), Vector3(-half * 0.5 + half * 0.5 * float(i), 0, -half * 0.35))
	var tower := _facade(brick.darkened(0.1), {"storey": 3.0, "bay": 1.6, "first_floor": 3.0, "win_w": 0.5, "win_h": 0.5})
	_solid(root, Vector3(half * 0.3, 12.0, half * 0.3), Vector3(half * 0.72, DECK + 6.0, half * 0.45), brick.darkened(0.1), tower)
	_box(root, Vector3(half * 0.34, 0.4, half * 0.34), Vector3(half * 0.72, DECK + 12.3, half * 0.45), Color(0.26, 0.24, 0.26))
	_sign(root, "FIRE", Vector3(0, DECK + 6.4, half * 0.45 - half * 0.48), Color(1.0, 0.85, 0.5))
	return []

## A corner bar: low, dark, a neon sign. Inside, a counter with the barman
## working behind it, a couple of regulars on stools and one at a table.
static func _bar(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var wall := Color(0.34, 0.28, 0.26)
	var skin := _facade(wall, {"windows_z": 0.0, "first_floor": 1.2, "storey": 2.2, "bay": 3.0, "lit_share": 0.8})
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.32, 0.32, 0.34))
	var at := Vector3(-half * 0.2, 0, half * 0.4)
	var span := Vector3(half * 1.0, 4.6, half * 0.85)
	_room(root, at, span, wall, 1.8, Color(0.55, 0.50, 0.32, 0.45), skin)
	var room := _inside(at, span)
	var back: float = room.back
	# the back bar with its bottles, the counter, and stools along it
	var run := span.x * 0.62
	_box(root, Vector3(run, 1.9, 0.4), Vector3(at.x, DECK + 1.3, back - 0.2), Color(0.20, 0.14, 0.10))
	_box(root, Vector3(run * 0.9, 0.05, 0.3), Vector3(at.x, DECK + 1.5, back - 0.55), Color(0.36, 0.25, 0.16))
	for k in 8:
		_box(root, Vector3(0.12, 0.34, 0.12), Vector3(at.x - run * 0.4 + run * 0.8 * float(k) / 7.0, DECK + 1.695, back - 0.55),
			[Color(0.3, 0.55, 0.3), Color(0.6, 0.4, 0.15), Color(0.7, 0.7, 0.75)][k % 3])
	var counter_z := back - 2.2
	_solid(root, Vector3(run, 1.1, 0.7), Vector3(at.x, DECK + 0.55, counter_z), Color(0.28, 0.18, 0.12))
	_box(root, Vector3(run + 0.1, 0.06, 0.8), Vector3(at.x, DECK + 1.12, counter_z), Color(0.45, 0.30, 0.18))
	for i in 4:
		_box(root, Vector3(0.4, 0.62, 0.4), Vector3(at.x - run * 0.36 + run * 0.24 * float(i), DECK + 0.31, counter_z - 0.85), Color(0.32, 0.22, 0.16))
	# a table by the window
	_box(root, Vector3(1.2, 0.75, 1.2), Vector3(room.left + 1.3, DECK + 0.38, room.front + 1.6), Color(0.26, 0.20, 0.18))
	_box(root, Vector3(0.5, 0.45, 0.5), Vector3(room.left + 1.3, DECK + 0.22, room.front + 2.7), Color(0.26, 0.20, 0.18))
	var n := _staff_seed(root)
	var lane := back - 1.3
	Staff.hire(root, "bar", [
		[Vector3(at.x - run * 0.2, 0, lane), PI, "serve", Vector2(4.0, 9.0)],
		[Vector3(at.x + run * 0.25, 0, lane), PI, "serve", Vector2(4.0, 9.0)],
		[Vector3(at.x, 0, back - 0.95), 0.0, "stock", Vector2(2.0, 5.0)],
	], n)
	for i in [0, 2]:
		Staff.hire(root, "patron", [
			[Vector3(at.x - run * 0.36 + run * 0.24 * float(i), 0, counter_z - 0.95), 0.0, "sit", Vector2(40.0, 90.0)],
		], n + 1 + i)
	Staff.hire(root, "patron", [
		[Vector3(room.left + 1.3, 0, room.front + 2.75), PI, "sit", Vector2(40.0, 90.0)],
	], n + 5)
	_box(root, Vector3(2.8, 0.9, 0.16), Vector3(at.x, DECK + 3.4, room.front - 0.3), Color(0.85, 0.25, 0.45))
	_sign(root, "BAR", Vector3(at.x, DECK + 3.4, room.front - 0.45), Color(1.0, 0.5, 0.7))
	door = root.position + Vector3(at.x, 0, room.front - 1.0)
	for i in 3:
		_box(root, Vector3(0.9, 1.1, 0.9), Vector3(half * 0.7, DECK + 0.55, -half * 0.1 + 1.1 * float(i)), Color(0.25, 0.32, 0.26))
	return []

## One long shed with a glass front: aisles inside, a till by the door with
## somebody on it, somebody stacking shelves, somebody shopping.
static func _grocery(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var wall := Color(0.74, 0.72, 0.66)
	var skin := _facade(wall, {"windows_x": 0.0, "windows_z": 0.0})
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.30, 0.30, 0.32))
	var at := Vector3(0, 0, half * 0.55)
	var span := Vector3(half * 1.7, 6.4, half * 0.75)
	_room(root, at, span, wall, 3.4, GLASS_CLEAR, skin)
	var room := _inside(at, span)
	# aisles, with goods on them in a few colours
	var aisle_z: float = (room.front + room.back) * 0.5 + 0.8
	var aisle_d: float = (room.back - room.front) - 4.4
	for i in 4:
		var x := -half * 0.45 + half * 0.3 * float(i)
		_solid(root, Vector3(0.9, 1.9, aisle_d), Vector3(x, DECK + 0.95, aisle_z), Color(0.58, 0.56, 0.52))
		for k in 3:
			_box(root, Vector3(0.96, 0.22, aisle_d - 0.2), Vector3(x, DECK + 0.45 + float(k) * 0.55, aisle_z),
				[Color(0.8, 0.3, 0.25), Color(0.9, 0.8, 0.3), Color(0.3, 0.55, 0.7)][(i + k) % 3])
	# the till, side-on to the door
	var till := Vector3(-half * 0.62, 0, room.front + 1.8)
	_solid(root, Vector3(0.8, 1.0, 2.0), till + Vector3(0, DECK + 0.5, 0), Color(0.45, 0.44, 0.42))
	_box(root, Vector3(0.3, 0.3, 0.3), till + Vector3(0.1, DECK + 1.15, -0.5), Color(0.15, 0.15, 0.17))
	_box(root, Vector3(half * 1.5, 0.5, 1.8), Vector3(0, DECK + 3.2, room.front - 1.05), Color(0.20, 0.55, 0.35))
	_sign(root, "GROCERY", Vector3(0, DECK + 4.6, room.front - 0.2), Color(1, 1, 0.9))
	var n := _staff_seed(root)
	Staff.hire(root, "shop", [
		[till + Vector3(-0.85, 0, 0), PI * 0.5, "serve", Vector2(20.0, 40.0)],
	], n)
	var gap_z := aisle_z
	Staff.hire(root, "shop", [
		[Vector3(-half * 0.3, 0, gap_z), -PI * 0.5, "stock", Vector2(6.0, 12.0)],
		[Vector3(0.0, 0, gap_z + 1.0), PI * 0.5, "stock", Vector2(6.0, 12.0)],
		[Vector3(half * 0.3, 0, gap_z - 1.0), -PI * 0.5, "stock", Vector2(6.0, 12.0)],
	], n + 1)
	Staff.hire(root, "patron", [
		[Vector3(-half * 0.3, 0, gap_z - 1.5), PI * 0.5, "stand", Vector2(5.0, 10.0)],
		[Vector3(half * 0.3, 0, gap_z + 1.2), -PI * 0.5, "stand", Vector2(5.0, 10.0)],
		[till + Vector3(0.9, 0, 0.2), -PI * 0.5, "stand", Vector2(4.0, 8.0)],
	], n + 2)
	door = root.position + Vector3(0, 0, room.front - 1.2)
	for i in 5:
		_box(root, Vector3(0.5, 0.9, 0.7), Vector3(half * 0.9, DECK + 0.45, -half * 0.05 + 0.28 * float(i)), Color(0.62, 0.63, 0.66))
	for i in 4:
		var bay := Vector3(-half * 0.9 + half * 0.6 * float(i), 0, -half * 0.55)
		_paint(root, Vector2(0.28, 5.4), bay + Vector3(-half * 0.3, 0, 0))
		spots.append([root.position + bay + Vector3(0, 0.05, 0), 0.0])
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

## Two storeys under a pitched roof, the door in the middle of the front with
## a window either side of it and two over, a chimney, a fence, a bin.
static func _house(root: Node3D, at: Vector3, side: float, wall: Color,
		roof: Color, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(5.8, 6.8)
	var d := rng.randf_range(4.8, 5.6)
	var h := rng.randf_range(5.9, 6.3)
	var skin := _facade(wall, {"storey": 2.7, "bay": 2.4, "first_floor": 0.45, "parapet": 0.3,
		"win_w": 0.48, "win_h": 0.5, "trim": Color(0.93, 0.92, 0.88), "glass": Color(0.2, 0.25, 0.3),
		"lit_share": 0.5, "seed": float(rng.randi() % 8)})
	_solid(root, Vector3(w, h, d), at + Vector3(0, DECK + h * 0.5, 0), wall, skin)
	# the roof, ridge along the street, and a fascia board under the eaves
	_pitched(root, Vector3(w + 0.7, 2.2, d + 0.9), at + Vector3(0, DECK + h, 0), roof)
	_box(root, Vector3(w + 0.7, 0.18, d + 0.9), at + Vector3(0, DECK + h + 0.02, 0), Color(0.93, 0.92, 0.88))
	# the front door, a step up to it, and a light beside it
	var face := -side * (d * 0.5 + 0.06)
	_box(root, Vector3(1.0, 2.1, 0.12), at + Vector3(0, DECK + 1.05, face), roof.darkened(0.3))
	_box(root, Vector3(1.2, 0.12, 0.3), at + Vector3(0, DECK + 2.25, face - side * 0.1), Color(0.93, 0.92, 0.88))
	_box(root, Vector3(1.6, 0.18, 0.9), at + Vector3(0, DECK + 0.09, face - side * 0.45),
		wall.darkened(0.25))
	_box(root, Vector3(0.18, 0.28, 0.18), at + Vector3(0.75, DECK + 2.0, face),
		Color(0.95, 0.88, 0.62))
	# a low fence round the front
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.12, 0.9, d * 0.8), at + Vector3(sx * (w * 0.5 + 1.1), DECK + 0.45, -side * 0.6),
			Color(0.62, 0.6, 0.55))
	# the chimney, coming up through the roof at one end
	_box(root, Vector3(0.7, 3.2, 0.7), at + Vector3(w * 0.32, DECK + h + 1.0, d * 0.12),
		wall.darkened(0.18))
	_box(root, Vector3(0.85, 0.2, 0.85), at + Vector3(w * 0.32, DECK + h + 2.65, d * 0.12),
		Color(0.28, 0.26, 0.26))
	# a bin at the kerb side of the drive
	_box(root, Vector3(0.6, 0.9, 0.6), at + Vector3(w * 0.5 + 0.4, DECK + 0.45, -side * (d * 0.5 + 0.9)),
		Color(0.25, 0.32, 0.26))

## An office tower on a staffed, glass-fronted lobby, with a lower block beside
## it and a paved forecourt with planters out front. Proportioned to the plot
## rather than three pencils stood in a corner of it.
static func _towers(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var col: Color = WALLS[rng.randi() % WALLS.size()]
	var glass: Color = [Color(0.16, 0.22, 0.30), Color(0.16, 0.26, 0.26), Color(0.26, 0.22, 0.18)][rng.randi() % 3]
	var skin := _facade(col, {"storey": 3.4, "bay": 3.0, "win_w": 0.72, "win_h": 0.62,
		"parapet": 1.2, "trim": col.darkened(0.4), "glass": glass, "lit_share": 0.4,
		"seed": float(rng.randi() % 8)})
	# a forecourt in paving, the rest in grass
	_slab(root, Vector2(half * 2.0, half * 2.0), Vector3.ZERO, Color(0.31, 0.40, 0.28))
	_slab(root, Vector2(half * 2.0, half * 0.8), Vector3(0, 0, -half * 0.6), Color(0.58, 0.56, 0.52))

	var at := Vector3(-half * 0.25, 0, half * 0.25)
	var span := Vector3(half * 1.25, 5.0, half * 1.0)
	_lobby(root, at, span, col.darkened(0.15), skin, Color(0.24, 0.24, 0.27), "office")
	var tall := rng.randf_range(28.0, 46.0)
	var body := tall - 5.15
	_solid(root, Vector3(span.x, body, span.z), at + Vector3(0, DECK + 5.15 + body * 0.5, 0), col, skin)
	# a setback crown: the top few floors pulled in, with a cap on each step
	_box(root, Vector3(span.x + 0.4, 0.5, span.z + 0.4), at + Vector3(0, DECK + tall + 0.25, 0), col.darkened(0.45))
	var crown := Vector2(span.x * 0.72, span.z * 0.72)
	_box(root, Vector3(crown.x, 6.8, crown.y), at + Vector3(0, DECK + tall + 3.9, 0), col.darkened(0.08)).material_override = skin
	_box(root, Vector3(crown.x + 0.3, 0.4, crown.y + 0.3), at + Vector3(0, DECK + tall + 7.4, 0), col.darkened(0.45))
	_roof_kit(root, at + Vector3(0, DECK + tall + 7.6, 0), crown, rng)

	# the lower block alongside: offices over shops, four or five floors
	var low := Vector3(half * 0.46, rng.randf_range(12.0, 17.0), half * 0.9)
	var low_at := Vector3(half * 0.7, 0, half * 0.3)
	var low_col: Color = WALLS[rng.randi() % WALLS.size()]
	var low_skin := _facade(low_col, {"storey": 3.2, "bay": 2.6, "first_floor": 0.8, "win_w": 0.55,
		"win_h": 0.55, "trim": low_col.darkened(0.4), "seed": float(rng.randi() % 8)})
	_solid(root, low, low_at + Vector3(0, DECK + low.y * 0.5, 0), low_col, low_skin)
	_box(root, Vector3(low.x + 0.4, 0.45, low.z + 0.4), low_at + Vector3(0, DECK + low.y + 0.22, 0), low_col.darkened(0.45))
	_roof_kit(root, low_at + Vector3(0, DECK + low.y + 0.45, 0), Vector2(low.x, low.z), rng)

	# planters on the forecourt with a tree in each, and a bench between
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(at.x + sx * span.x * 0.32, 0, -half * 0.62)
		_solid(root, Vector3(2.0, 0.6, 2.0), p + Vector3(0, DECK + 0.3, 0), Color(0.5, 0.48, 0.44))
		_box(root, Vector3(0.3, 2.4, 0.3), p + Vector3(0, DECK + 1.8, 0), Color(0.32, 0.24, 0.18))
		_box(root, Vector3(2.0, 1.6, 2.0), p + Vector3(0, DECK + 3.4, 0), Color(0.24, 0.44, 0.24))
	_box(root, Vector3(1.8, 0.45, 0.6), Vector3(at.x, DECK + 0.22, -half * 0.75), Color(0.45, 0.32, 0.2))
	door = root.position + Vector3(at.x, 0, _inside(at, span).front - 1.2)
	return []

## Tanks, plant, a mast with a light on it: what the top of a building has.
static func _roof_kit(root: Node3D, at: Vector3, room: Vector2, rng: RandomNumberGenerator) -> void:
	var grey := Color(0.5, 0.5, 0.52)
	_box(root, Vector3(room.x * 0.3, 1.6, room.y * 0.25), at + Vector3(-room.x * 0.2, 0.8, room.y * 0.2), grey)
	for k in 3:
		_box(root, Vector3(0.8, 0.5, 0.8), at + Vector3(-room.x * 0.3 + float(k) * 1.1, 1.85, room.y * 0.2), grey.darkened(0.25))
	if rng.randf() < 0.6:
		# a water tank up on legs
		var tank := at + Vector3(room.x * 0.25, 0, -room.y * 0.2)
		for sx: float in [-0.7, 0.7]:
			for sz: float in [-0.7, 0.7]:
				_box(root, Vector3(0.14, 1.4, 0.14), tank + Vector3(sx, 0.7, sz), Color(0.3, 0.26, 0.22))
		_box(root, Vector3(2.0, 2.2, 2.0), tank + Vector3(0, 2.5, 0), Color(0.46, 0.36, 0.28))
		_pitched(root, Vector3(2.1, 0.7, 2.1), tank + Vector3(0, 3.6, 0), Color(0.3, 0.26, 0.22), false)
	if rng.randf() < 0.5:
		_box(root, Vector3(0.14, 6.0, 0.14), at + Vector3(room.x * 0.3, 3.0, room.y * 0.3), Color(0.7, 0.7, 0.72))
		_box(root, Vector3(0.3, 0.3, 0.3), at + Vector3(room.x * 0.3, 6.1, room.y * 0.3), Color(1.0, 0.15, 0.1)).material_override = _lit(Color(1.0, 0.15, 0.1))

## A terrace of two-storey shops facing the street -- shopfront below, flat
## above -- with one of them open to walk into, an alley and a delivery bay.
static func _shops(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var spots := []
	var names := ["LAUNDRY", "PAWN", "GROCER", "LIQUOR", "TYRES", "DINER", "PHONES"]
	# off the block's own dice: Array.shuffle rolls the global ones, and the
	# high street came out different every time the game started
	for k in range(names.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var swap: String = names[k]
		names[k] = names[j]
		names[j] = swap
	var run := -half + 0.8
	var i := 0
	var units := []
	while run < half - 4.8 and i < names.size():
		var w: float = minf(rng.randf_range(5.0, 7.0), half - 0.8 - run)
		units.append([run, w])
		run += w + 0.3
		i += 1
	# the widest unit is the one with its door open
	var open_i := 0
	for k in units.size():
		if float(units[k][1]) > float(units[open_i][1]):
			open_i = k
	for k in units.size():
		var x0: float = units[k][0]
		var w: float = units[k][1]
		var h: float = rng.randf_range(7.4, 9.6)
		var col: Color = WALLS[rng.randi() % WALLS.size()]
		var skin := _facade(col, {"storey": 2.9, "bay": 2.2, "first_floor": 3.9, "parapet": 0.8,
			"win_w": 0.55, "win_h": 0.58, "trim": col.lightened(0.3), "seed": float(k)})
		var at := Vector3(x0 + w * 0.5, 0, -4.0)
		var front := at.z - 4.5
		var shop_name := String(names[k])
		if k == open_i:
			_room(root, at, Vector3(w, 3.7, 9.0), col, 1.4, GLASS_CLEAR, skin)
			_solid(root, Vector3(w, h - 3.85, 9.0), at + Vector3(0, DECK + 3.85 + (h - 3.85) * 0.5, 0), col, skin)
			# a counter across the shop, somebody behind it, a customer at it
			var counter_z := at.z + 1.2
			_solid(root, Vector3(w - 2.2, 1.05, 0.7), Vector3(at.x - 0.6, DECK + 0.52, counter_z), col.darkened(0.35))
			_box(root, Vector3(w - 1.0, 1.6, 0.4), Vector3(at.x, DECK + 1.2, at.z + 4.0), col.darkened(0.5))
			var job := "diner" if shop_name == "DINER" else "shop"
			var n := _staff_seed(root)
			Staff.hire(root, job, [
				[Vector3(at.x - 1.0, 0, counter_z + 1.0), PI, "serve", Vector2(6.0, 14.0)],
				[Vector3(at.x + 0.2, 0, at.z + 3.25), 0.0, "stock", Vector2(3.0, 7.0)],
			], n)
			Staff.hire(root, "patron", [
				[Vector3(at.x - 1.2, 0, counter_z - 0.85), 0.0, "stand", Vector2(8.0, 20.0)],
				[Vector3(at.x + w * 0.3, 0, front + 1.4), 0.0, "stand", Vector2(5.0, 10.0)],
			], n + 1)
			door = root.position + Vector3(at.x, 0, front - 1.0)
		else:
			_solid(root, Vector3(w, h, 9.0), at + Vector3(0, DECK + h * 0.5, 0), col, skin)
			_box(root, Vector3(w - 1.4, 2.4, 0.14), at + Vector3(-0.35, DECK + 1.4, -4.56), GLASS)
			_box(root, Vector3(0.9, 2.1, 0.12), at + Vector3(w * 0.5 - 0.8, DECK + 1.05, -4.56), col.darkened(0.4))
		# fascia with the name on it, an awning under it, a cornice on top
		_box(root, Vector3(w - 0.1, 0.7, 0.2), at + Vector3(0, DECK + 3.35, -4.6), col.darkened(0.45))
		_sign(root, shop_name, at + Vector3(0, DECK + 3.35, -4.85))
		_box(root, Vector3(w - 0.3, 0.14, 1.4), at + Vector3(0, DECK + 2.85, -5.25),
			col.lightened(0.25) if k % 2 == 0 else Color(0.62, 0.2, 0.18))
		_box(root, Vector3(w + 0.1, 0.35, 9.3), at + Vector3(0, DECK + h + 0.17, 0), col.darkened(0.35))
		if k % 2 == 0:
			_box(root, Vector3(0.7, 0.9, 0.5), at + Vector3(-w * 0.2, DECK + 0.45, -6.4),
				Color(0.35, 0.30, 0.24))
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

## How a car park at `centre` lays out on a plot `px` by `pz`: an aisle along
## X, a row of bays either side of it (or one row, on a shallow plot), in off
## the street on the west side and out on the east. Traffic keeps right, so a
## car coming up the west road is in the lane nearest the gate and turns right
## into it, and one leaving turns right into the lane nearest the east gate.
##
## The world asks for this before it lays the pavements, so the kerb can be
## dropped where the drives cross it; the lot builder draws from the same plan
## and the lot life drives from it.
static func lot_plan(centre: Vector3, px: float, pz: float) -> Dictionary:
	var two_rows := pz >= 11.5
	# a car is 6.9m long: its middle this far in from the wall leaves its
	# nose a hand's width short of it
	var row_z := pz - 4.0
	var aisle_lo := -row_z + 3.6 if two_rows else -pz + 0.6
	var aisle_hi := row_z - 3.6
	var ac := (aisle_lo + aisle_hi) * 0.5
	var n := int((2.0 * px - 12.0) / LOT_BAY)
	var bays := []
	for row: float in ([-1.0, 1.0] if two_rows else [1.0]):
		for i in n:
			var x := (float(i) - float(n - 1) * 0.5) * LOT_BAY
			bays.append({
				"at": centre + Vector3(x, 0.05, row * row_z),
				# nose in, towards the wall
				"yaw": PI if row > 0.0 else 0.0,
				"row": row,
			})
	return {
		"centre": centre, "px": px, "pz": pz, "aisle": ac,
		"aisle_lo": aisle_lo, "aisle_hi": aisle_hi, "bays": bays,
		# the two gates, on the lot's edge
		"entry": centre + Vector3(-px, 0, ac),
		"exit": centre + Vector3(px, 0, ac),
		# and the lanes the traffic comes in from and goes out onto
		"entry_lane": centre.x - px - World.PAVE_BACK + Traffic.LANE,
		"exit_lane": centre.x + px + World.PAVE_BACK - Traffic.LANE,
	}

## Bays are this far apart, middle to middle. A car is 2.8m across and there
## has to be room for a door and somebody at it between two of them.
const LOT_BAY := 4.8
## How wide the gates, and the drives through the pavement to them, are.
const LOT_GATE := 6.4

## Tarmac, marked bays nose-in to a low wall, an aisle down the middle with a
## hump in it, and gates in and out with the kerb dropped for each.
static func _lot(root: Node3D) -> Array:
	var spots := []
	var px := plot_x
	var pz := plot_z
	var plan := lot_plan(root.position, px, pz)
	var ac: float = plan.aisle
	_slab(root, Vector2(px * 2.0, pz * 2.0), Vector3.ZERO, TARMAC)
	# the bays: a line either side of each, and a stop block at the head
	var k := 0
	for bay: Dictionary in plan.bays:
		var local: Vector3 = (bay.at as Vector3) - root.position
		var row: float = bay.row
		for sx: float in [-0.5, 0.5]:
			_paint(root, Vector2(0.18, 7.0), Vector3(local.x + sx * LOT_BAY, 0, local.z))
		_box(root, Vector3(1.8, 0.14, 0.25), Vector3(local.x, DECK + 0.07, local.z + row * 3.15), Color(0.8, 0.78, 0.2))
		spots.append([bay.at, bay.yaw, {"lot": plan.centre, "bay": k, "fixed": true}])
		k += 1
	# arrows down the aisle, west to east -- the one way it runs
	for x: float in [-px * 0.55, px * 0.1, px * 0.6]:
		_paint(root, Vector2(2.2, 0.28), Vector3(x, 0, ac))
		for s: float in [-1.0, 1.0]:
			var head := _box(root, Vector3(1.1, 0.12, 0.26), Vector3(x + 1.05, DECK - 0.035, ac + s * 0.36), PAINT)
			head.rotation.y = s * 0.7
	# a hump halfway down, so nobody takes it at speed
	RideSurface.hump(root, root.to_global(Vector3(-px * 0.25, 0, ac)),
		plan.aisle_hi - plan.aisle_lo - 0.6, PI * 0.5)

	# the low wall round it, with the two gates left open
	var wall := Color(0.6, 0.58, 0.54)
	var gate := LOT_GATE * 0.5
	for sz: float in [-1.0, 1.0]:
		_solid(root, Vector3(px * 2.0, 0.9, 0.3), Vector3(0, DECK + 0.45, sz * (pz - 0.15)), wall)
	for sx: float in [-1.0, 1.0]:
		var lo := -pz + 0.3
		var hi := pz - 0.3
		# either side of the gate
		var a := [lo, ac - gate]
		var b := [ac + gate, hi]
		for piece: Array in [a, b]:
			var length: float = float(piece[1]) - float(piece[0])
			if length > 0.2:
				_solid(root, Vector3(0.3, 0.9, length),
					Vector3(sx * (px - 0.15), DECK + 0.45, (float(piece[0]) + float(piece[1])) * 0.5), wall)
		# gate posts, a sign on each, and at the way in a barrier arm stood up
		for sz: float in [-1.0, 1.0]:
			_box(root, Vector3(0.35, 1.5, 0.35), Vector3(sx * (px - 0.15), DECK + 0.75, ac + sz * gate), wall.darkened(0.15))
		var word := "IN" if sx < 0.0 else "OUT"
		var sign_col := Color(0.2, 0.55, 0.25) if sx < 0.0 else Color(0.7, 0.2, 0.18)
		_box(root, Vector3(0.12, 2.6, 0.12), Vector3(sx * (px - 0.15), DECK + 1.3, ac - gate - 0.5), Color(0.5, 0.5, 0.52))
		_box(root, Vector3(0.1, 0.7, 1.3), Vector3(sx * (px - 0.15), DECK + 2.7, ac - gate - 0.5), sign_col)
		_sign(root, word, Vector3(sx * (px - 0.4), DECK + 2.7, ac - gate - 0.5), Color(1, 1, 1))
	_box(root, Vector3(0.5, 1.1, 0.5), Vector3(-px + 1.0, DECK + 0.55, ac - gate - 0.2), Color(0.85, 0.7, 0.2))
	var arm := _box(root, Vector3(0.12, 3.8, 0.12), Vector3(-px + 1.0, DECK + 2.9, ac - gate - 0.2),
		Color(0.9, 0.2, 0.2))
	arm.rotation.z = 0.12
	_sign(root, "PARKING", Vector3(-px - 0.2, DECK + 3.4, ac + gate + 1.2), Color(0.8, 0.9, 1.0))
	# lights on posts in the corners, where no car goes
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * (px - 0.8), 0, sz * (pz - 0.8))
			_box(root, Vector3(0.25, 6.0, 0.25), at + Vector3(0, DECK + 3.0, 0), Color(0.3, 0.3, 0.32))
			_box(root, Vector3(1.2, 0.25, 0.45), at + Vector3(-sx * 0.4, DECK + 6.0, -sz * 0.4), Color(0.9, 0.88, 0.7))
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
	# the kiosk behind it: glass across the front, a counter, somebody on it
	var kiosk := Vector3(0, 0, half * 0.62)
	var kspan := Vector3(half * 1.0, 3.6, 5.0)
	_room(root, kiosk, kspan, Color(0.72, 0.70, 0.64), 1.4, GLASS_CLEAR)
	_box(root, Vector3(half * 1.04, 0.4, 5.4), kiosk + Vector3(0, DECK + 3.8, 0), Color(0.80, 0.30, 0.22))
	_sign(root, "GAS", kiosk + Vector3(0, DECK + 4.6, 0), Color(1.0, 0.85, 0.4))
	var kin := _inside(kiosk, kspan)
	_solid(root, Vector3(half * 0.45, 1.05, 0.7), Vector3(-half * 0.2, DECK + 0.52, kiosk.z + 0.4), Color(0.42, 0.40, 0.38))
	_box(root, Vector3(half * 0.6, 1.8, 0.4), Vector3(-half * 0.1, DECK + 1.1, kin.back - 0.2), Color(0.55, 0.3, 0.25))
	_box(root, Vector3(0.9, 1.9, 0.7), Vector3(kin.right - 0.6, DECK + 0.95, kin.back - 0.4), Color(0.8, 0.85, 0.9))
	var n := _staff_seed(root)
	Staff.hire(root, "fuel", [
		[Vector3(-half * 0.2, 0, kiosk.z + 1.3), PI, "serve", Vector2(10.0, 30.0)],
		[Vector3(-half * 0.1, 0, kin.back - 0.75), 0.0, "stock", Vector2(3.0, 6.0)],
	], n)
	door = root.position + Vector3(0, 0, kin.front - 1.0)
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

## Something you can walk into. `skin` draws it with that instead of the
## flat colour -- a facade, for anything with windows.
static func _solid(parent: Node3D, size: Vector3, at: Vector3, colour: Color,
		skin: Material = null) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	parent.add_child(body)
	var mi := _box(body, size, Vector3.ZERO, colour)
	if skin != null:
		mi.material_override = skin

## The outside of a building in `colour`, windows and all (shaders/facade).
## `opts` sets the shader's own parameters: storey, bay, first_floor, glass,
## trim... One material per distinct look, shared by everything wearing it.
static var _facades := {}
static var _facade_shader: Shader

static func _facade(colour: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var key := "%d %s" % [colour.to_rgba32(), str(opts)]
	if _facades.has(key):
		return _facades[key]
	if _facade_shader == null:
		_facade_shader = load("res://shaders/facade.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _facade_shader
	m.set_shader_parameter("wall", colour)
	m.set_shader_parameter("trim", colour.darkened(0.45))
	for k in opts:
		m.set_shader_parameter(String(k), opts[k])
	_facades[key] = m
	return m

## A pitched roof sat on eaves at `at` (the middle of the eaves, not the
## ridge). The ridge runs along X unless told otherwise, with the gables at the
## ends; `span.y` is how far it rises.
static var _prism: PrismMesh

static func _pitched(parent: Node3D, span: Vector3, at: Vector3, colour: Color,
		ridge_x: bool = true) -> MeshInstance3D:
	if _prism == null:
		_prism = PrismMesh.new()
		_prism.size = Vector3.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _prism
	mi.material_override = _mat(colour)
	if ridge_x:
		mi.rotation.y = PI * 0.5
		mi.scale = Vector3(span.z, span.y, span.x)
	else:
		mi.scale = span
	mi.position = at + Vector3(0, span.y * 0.5, 0)
	parent.add_child(mi)
	return mi

## Something that gives off its own light -- a lamp panel, a warning light.
static var _lits := {}

static func _lit(colour: Color) -> StandardMaterial3D:
	var key := colour.to_rgba32()
	if _lits.has(key):
		return _lits[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 2.0
	_lits[key] = m
	return m

## A panel in the ceiling, and a light under it that DayNight can switch on
## when the player is near enough to see in.
static var _panel_mat: StandardMaterial3D

static func _interior_light(root: Node3D, at: Vector3, span: Vector3) -> void:
	var panel := _box(root, Vector3(minf(span.x * 0.45, 3.0), 0.06, minf(span.z * 0.3, 1.2)), at,
		Color(1.0, 0.95, 0.85))
	# softer than a warning lamp: at full glow it burns out to a white hole in
	# the ceiling of a room you are standing in
	if _panel_mat == null:
		_panel_mat = StandardMaterial3D.new()
		_panel_mat.albedo_color = Color(1.0, 0.95, 0.85)
		_panel_mat.emission_enabled = true
		_panel_mat.emission = Color(1.0, 0.93, 0.8)
		_panel_mat.emission_energy_multiplier = 0.7
	panel.material_override = _panel_mat
	var l := OmniLight3D.new()
	l.omni_range = clampf(maxf(span.x, span.z) * 0.9, 6.0, 12.0)
	l.light_energy = 1.9
	l.light_color = Color(1.0, 0.93, 0.8)
	l.shadow_enabled = false
	l.position = at - Vector3(0, 0.4, 0)
	l.visible = false
	root.add_child(l)
	interior_lights.append(l)

## A seed for whoever works on this block: from where it is, so the same
## people are at the same desks every game and nothing else's dice move.
static func _staff_seed(root: Node3D) -> int:
	return int(absf(root.position.x) * 131.0 + absf(root.position.z) * 71.0) * 10 + 7

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
