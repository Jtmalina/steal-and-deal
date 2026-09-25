extends Node
class_name ShotTour
# ============================================================
#  A look round town for whoever is changing how it looks.
#
#    godot --path . -- --shots [--shots-dir=C:/somewhere] [--shot=name]
#
#  Flies a camera to a list of places at a list of hours, waits
#  for everything to settle, and saves what it sees as PNGs. Then
#  quits. Needs a window: headless has nothing to take a picture of.
# ============================================================

## name, hour, where the camera stands, what it looks at
const SHOTS := [
	["street_noon", 13.0, Vector3(19.5, 1.7, 52.0), Vector3(16.0, 5.0, -40.0)],
	["block_noon", 13.0, Vector3(62.0, 14.0, 70.0), Vector3(39.0, 4.0, 39.0)],
	["overhead_noon", 13.0, Vector3(70.0, 70.0, 110.0), Vector3(0.0, 0.0, 0.0)],
	["tower_noon", 15.0, Vector3(-30.0, 6.0, -92.0), Vector3(-57.0, 18.0, -57.0)],
	["tower_lobby", 15.0, Vector3(-60.0, 1.7, -69.0), Vector3(-61.0, 2.0, -52.0)],
	["hotel_lobby", 11.0, Vector3(-104.0, 1.7, 82.0), Vector3(-106.0, 1.4, 93.0)],
	["bar_inside", 22.0, Vector3(-6.4, 1.7, 91.5), Vector3(-10.0, 1.2, 98.5)],
	["grocery_inside", 12.0, Vector3(-53.0, 1.7, -103.0), Vector3(-61.0, 1.0, -99.0)],
	["houses_noon", 10.0, Vector3(-133.0, 4.0, -163.0), Vector3(-149.0, 3.0, -149.0)],
	# a lot: stood off the first one there is, looking down the aisle from the gate
	["lot_noon", 11.0, Vector3(-30.0, 14.0, 6.0), Vector3(0.0, 0.0, -2.0)],
	["dawn_east", 6.4, Vector3(16.0, 1.7, 30.0), Vector3(120.0, 18.0, 20.0)],
	["dusk_west", 20.1, Vector3(19.5, 1.7, 30.0), Vector3(-120.0, 16.0, 10.0)],
	["night_street", 1.0, Vector3(19.5, 1.7, 52.0), Vector3(16.0, 6.0, -40.0)],
	["night_towers", 23.0, Vector3(-20.0, 3.0, -100.0), Vector3(-57.0, 20.0, -57.0)],
	["night_sky", 1.0, Vector3(19.5, 1.7, 30.0), Vector3(-40.0, 60.0, -30.0)],
]

var _cam: Camera3D
var _dir := "user://shots"
var _only := ""
var _at := 0
var _wait := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			_dir = a.trim_prefix("--shots-dir=")
		elif a.begins_with("--shot="):
			_only = a.trim_prefix("--shot=")
	DirAccess.make_dir_recursive_absolute(_dir)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 900.0
	add_child(_cam)
	_wait = 90

func _process(_d: float) -> void:
	for n in get_parent().get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	if _at >= SHOTS.size():
		get_tree().quit()
		return
	var shot: Array = SHOTS[_at]
	if _only != "" and shot[0] != _only:
		_at += 1
		return
	# hold the clock still on the hour we want
	GameState.minutes = float(shot[1]) * 60.0
	var from: Vector3 = shot[2]
	var to: Vector3 = shot[3]
	# the lot shot is put where the lot is, whichever block that turned out to be
	var world := get_tree().get_first_node_in_group("world") as World
	if String(shot[0]).begins_with("lot") and world != null and not world.lots.is_empty():
		var c: Vector3 = world.lots[0].centre
		from += c
		to += c
	# a camera straight down cannot use up as its up
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD
	_cam.global_position = from
	_cam.look_at(to, up)
	_cam.make_current()
	if _wait > 0:
		_wait -= 1
		return
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot[0]]
	img.save_png(path)
	print("[SHOT] ", ProjectSettings.globalize_path(path))
	_at += 1
	_wait = 20
