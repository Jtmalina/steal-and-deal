extends Control
class_name Compass
# ============================================================
#  A strip across the top of the screen with the cardinals on
#  it and a pip for each place worth driving to.
#
#  The pips are coloured the same as they are on the map in the
#  corner -- green shop, yellow yard, red pound, blue truck --
#  so neither of them needs any words on it.
# ============================================================

## How much of the world the strip covers, left edge to right edge.
const SPREAD := deg_to_rad(140.0)

const BACK := Color(0.05, 0.06, 0.08, 0.6)
const TICK := Color(0.75, 0.75, 0.78, 0.8)
const CARDINAL := Color(1.0, 0.95, 0.85)

var player: Node3D = null
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	queue_redraw()

## Compass bearing of a direction: north is -Z, east is +X, like the map.
static func bearing(dir: Vector3) -> float:
	return atan2(dir.x, -dir.z)

## Where a bearing lands on the strip, or -1 if it is behind you.
func _column(from_view: float) -> float:
	var off := wrapf(from_view, -PI, PI)
	if absf(off) > SPREAD * 0.5:
		return -1.0
	return size.x * 0.5 + off / SPREAD * size.x

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	if player == null or not is_instance_valid(player):
		return
	var eye: Node3D = player
	var ride = player.get("current_vehicle")
	if ride != null and is_instance_valid(ride):
		eye = ride
	var fwd: Vector3 = -eye.global_transform.basis.z
	# on foot it is the camera you are steering by, not the body
	var arm = player.get("arm")
	if ride == null and arm != null and is_instance_valid(arm):
		fwd = -(arm as Node3D).global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	var view := bearing(fwd)

	# every 15 degrees a tick, every 90 a letter
	var marks := {0.0: "N", 90.0: "E", 180.0: "S", 270.0: "W"}
	for step in range(0, 360, 15):
		var col := _column(deg_to_rad(float(step)) - view)
		if col < 0.0:
			continue
		var name := String(marks.get(float(step), ""))
		if name == "":
			draw_line(Vector2(col, size.y - 7.0), Vector2(col, size.y - 1.0), TICK, 1.0)
		else:
			draw_line(Vector2(col, size.y - 10.0), Vector2(col, size.y - 1.0), CARDINAL, 2.0)
			draw_string(_font, Vector2(col - 6.0, size.y - 13.0), name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CARDINAL)

	# and the places, as pips at their own bearing
	var here := (eye as Node3D).global_position
	_pip(here, view, World.GARAGE_POS, Color(0.4, 1.0, 0.5))
	_pip(here, view, World.SCRAP_POS, Color(1.0, 0.85, 0.3))
	if GameState.truck_impounded:
		_pip(here, view, World.IMPOUND_POS, Color(1.0, 0.4, 0.35))
	var lorry := GameState.truck()
	if lorry and here.distance_to(lorry.global_position) > 12.0:
		_pip(here, view, lorry.global_position, Color(0.45, 0.75, 1.0))

func _pip(here: Vector3, view: float, target: Vector3, colour: Color) -> void:
	var to := target - here
	to.y = 0.0
	if to.length() < 1.0:
		return
	var col := _column(bearing(to) - view)
	if col < 0.0:
		return
	# a downward arrow, brighter the closer you are to it
	var fade: float = clampf(1.2 - to.length() / 220.0, 0.45, 1.0)
	var tip := Vector2(col, size.y - 12.0)
	draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-5.0, -8.0), tip + Vector2(5.0, -8.0)]),
		Color(colour.r, colour.g, colour.b, fade))
