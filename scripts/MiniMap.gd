extends Control
class_name MiniMap
# ============================================================
#  The whole neighbourhood in a corner of the screen.
#
#  The grid is regular and small enough to draw all of it at
#  once, so there is no scrolling: the map is the map, and you
#  are the arrow moving about on it. Police show up as long as
#  they are anywhere near, which is the only thing on here you
#  actually need in a hurry.
# ============================================================

## Metres of world the window shows. The city is far too big to draw at once
## now, so the map is a window that travels with you rather than a picture of
## the whole place with a dot on it.
const SPAN := 150.0
## How far away a copper still counts as nearby.
const WATCH := 110.0

const BACK := Color(0.05, 0.06, 0.08, 0.78)
const EDGE := Color(0.55, 0.55, 0.6, 0.9)
const ROAD := Color(0.32, 0.33, 0.36)
const KERB := Color(0.22, 0.23, 0.26)

var player: Node3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# roads run off the edge of the world; the map does not
	clip_contents = true

func _process(_delta: float) -> void:
	queue_redraw()

## Where the window is centred -- on the player, clamped so it never runs past
## the edge of the world and shows a screenful of nothing.
func _eye() -> Vector3:
	if player == null or not is_instance_valid(player):
		return Vector3.ZERO
	var at := player.global_position
	var edge: float = World.ROADS[World.ROADS.size() - 1] + 30.0
	var lim: float = maxf(0.0, edge - SPAN * 0.5)
	return Vector3(clampf(at.x, -lim, lim), 0, clampf(at.z, -lim, lim))

## World metres onto the face of the map, relative to wherever it is looking.
func _at(world: Vector3) -> Vector2:
	var s := size.x / SPAN
	var eye := _eye()
	return Vector2((world.x - eye.x + SPAN * 0.5) * s, (world.z - eye.z + SPAN * 0.5) * s)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	var s := size.x / SPAN

	# the grid, kerb width under road width so it reads as a road. Only the
	# roads that fall inside the window are worth drawing.
	var eye := _eye()
	var reach: float = SPAN * 0.5 + 12.0
	var far: float = World.ROADS[World.ROADS.size() - 1] + 40.0
	for pass_i in 2:
		var w: float = (World.PAVE_BACK if pass_i == 0 else World.ROAD_HALF) * 2.0 * s
		var col: Color = KERB if pass_i == 0 else ROAD
		for c: float in World.ROADS:
			if absf(c - eye.z) < reach:
				draw_line(_at(Vector3(-far, 0, c)), _at(Vector3(far, 0, c)), col, w)
			if absf(c - eye.x) < reach:
				draw_line(_at(Vector3(c, 0, -far)), _at(Vector3(c, 0, far)), col, w)

	# the three places worth finding again -- and an arrow at the edge for the
	# ones that are off the window, so you still know which way they are
	_pin(World.GARAGE_POS, Color(0.4, 1.0, 0.5))
	_pin(World.SCRAP_POS, Color(1.0, 0.85, 0.3))
	_pin(World.IMPOUND_POS, Color(1.0, 0.4, 0.35))

	if player == null or not is_instance_valid(player):
		draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 2.0)
		return
	var here := player.global_position

	# anybody on the job, near enough to matter
	for group in ["police", "police_foot", "police_car"]:
		for n in get_tree().get_nodes_in_group(group):
			var body := n as Node3D
			if body == null or body.global_position.distance_to(here) > WATCH:
				continue
			draw_circle(_at(body.global_position), 3.0, Color(1.0, 0.3, 0.3))

	# your truck, so you always know where the load is
	var lorry := GameState.truck()
	if lorry:
		draw_circle(_at(lorry.global_position), 3.0, Color(0.45, 0.75, 1.0))

	# and you, pointing the way you are facing
	var facing: Vector3 = -player.global_transform.basis.z
	var ride = player.get("current_vehicle")
	if ride != null and is_instance_valid(ride):
		facing = -(ride as Node3D).global_transform.basis.z
	var dir := Vector2(facing.x, facing.z).normalized()
	if dir.length() < 0.1:
		dir = Vector2.UP
	var at := _at(here)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		at + dir * 6.0, at - dir * 3.5 + side * 3.5, at - dir * 3.5 - side * 3.5]),
		Color(1, 1, 1))

	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 2.0)

## A marker for somewhere. If it is off the window it gets pushed to the edge
## and drawn smaller, so the map still points at it from across the city.
func _pin(world: Vector3, colour: Color) -> void:
	var at := _at(world)
	var edge := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if edge.has_point(at):
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), colour)
		return
	var mid := size * 0.5
	var away := (at - mid)
	if away.length() < 0.01:
		return
	away = away.normalized() * (minf(size.x, size.y) * 0.5 - 6.0)
	draw_rect(Rect2(mid + away - Vector2(2, 2), Vector2(4, 4)),
		Color(colour.r, colour.g, colour.b, 0.55))
