extends Control
class_name Teardown
# ============================================================
#  Hands-on teardown. The camera moves in on the actual car in
#  the bay, the cursor comes free, and you manipulate real 3D
#  props sitting exactly where those fasteners live:
#
#    BOLT / CLAMP  grab it and turn the mouse ANTICLOCKWISE
#    PLUG          drag the connector straight out, steadily
#    CUT           drag back and forth across the cut line
#    PULL          drag the actual part off the car
#    PUMP          drag the jack handle down, then up
#
#  Every position comes from GameData.PARTS -- hinge bolts are
#  on the hinges, lug nuts on the hub, mounts down in the bay.
#  Fumble it and the part loses condition, which costs money.
# ============================================================

const PROP_LAYER := 1 << 8
const CHROME := Color(0.72, 0.74, 0.78)
const COPPER := Color(0.88, 0.56, 0.22)
## How far apart two wires sit once they are twisted together.
const PAIR_GAP := 0.075
const HOT := Color(1.0, 0.8, 0.2)

signal finished(success: bool, quality: float)

var active := false
var quality := 1.0

var _vehicle: Vehicle = null
var _part_id := ""
var _stages: Array = []
var _stage := 0
var _props: Array = []
var _rig: Node3D = null
var _cam: Camera3D = null
var _prev_cam: Camera3D = null
var _cam_local := Vector3.ZERO
var _look_local := Vector3.ZERO
var _cam_follow := false
var _done_cb: Callable
var _title := ""

# interaction
var _hover := -1
var _grabbed := -1

## Nothing on this car gets touched with bare hands if there is a tool for it.
## The tool hangs off your belt at the bottom of the shot, you carry it over to
## the fastener, and it stays wherever you put it down -- one bolt to the next,
## never snapping back to where it started.
const TOOL_META := -2
## How close the tool has to be dropped to a fastener before it takes.
const TOOL_SNAP := 0.45
## How far it sits off the work once it is on it.
## How far off the work the tool sits once it is on it. Fasteners on a door are
## a hand's width inside the skin, so a tool parked on the bolt itself ends up
## inside the panel where you can neither see it nor tell which one it is on.
const TOOL_STANDOFF := 0.28

var _tool: Node3D = null
var _tool_id := ""
## Index of the prop the tool is sat on, or -1 while it is loose in the air.
var _tool_on := -1
var _tool_drag := false
var _tool_depth := 1.0
var _tool_base := Basis.IDENTITY
var _pulse := 0.0
var _tool_ring: MeshInstance3D = null
## Set once the tool has been picked up at all, which retires its marker band.
var _tool_touched := false
## How long a key reader takes to answer, and how much hand-shake it forgives.
const SCAN_SECS := 2.6
const SCAN_WOBBLE := 14.0

## Seconds left on a stage that has a clock on it, or -1 for one that has not.
var _limit := -1.0
## Set while the driver model is hidden because a copy of them is in your hands.
var _hid_occupant := false
var _last_mouse := Vector2.ZERO
var _stroke_dir := 0
var _flash := 0.0

# 2d strip
var _title_label: Label
var _step_label: Label
var _hint_label: Label
var _qual_label: Label
var _bar_bg: ColorRect
var _bar: ColorRect

func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -138.0
	offset_bottom = -10.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_label = _label("", 22, HOT, 8)
	_step_label = _label("", 20, Color(1, 1, 1), 38)
	_hint_label = _label("", 16, Color(0.85, 0.85, 0.85), 66)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.15, 0.15, 0.18)
	_bar_bg.anchor_left = 0.5
	_bar_bg.anchor_right = 0.5
	_bar_bg.offset_left = -240
	_bar_bg.offset_right = 240
	_bar_bg.offset_top = 94
	_bar_bg.offset_bottom = 104
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.color = Color(0.3, 0.9, 0.4)
	_bar.size = Vector2(0, 10)
	_bar_bg.add_child(_bar)

	_qual_label = _label("", 15, Color(0.6, 1.0, 0.6), 108)

func _label(text: String, sz: int, col: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = y
	l.offset_bottom = y + sz + 10
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

# ------------------------------------------------------------
#  Lifecycle
# ------------------------------------------------------------
func begin(vehicle: Vehicle, title: String, stages: Array, on_done: Callable,
		start_quality: float = 1.0, part_id: String = "") -> void:
	_vehicle = vehicle
	_part_id = part_id
	_title = title
	_stages = stages
	_stage = 0
	quality = start_quality
	_done_cb = on_done
	active = true
	visible = true

	_rig = Node3D.new()
	vehicle.add_child(_rig)

	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 58.0
	get_tree().current_scene.add_child(_cam)
	if _prev_cam:
		_cam.global_transform = _prev_cam.global_transform
	_cam.current = true
	_cam_follow = false

	# a door is worked on hanging open, the same as it would be in a real shop
	if _part_id.begins_with("door") and vehicle.has_door(_part_id):
		vehicle.open_door(_part_id)
	vehicle.set_label_visible(false)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.get("body_mesh") != null:
		pl.body_mesh.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_stage()

func abort() -> void:
	if not active:
		return
	_end()
	if _done_cb.is_valid():
		_done_cb.call(false, quality)

## Pulled off the job by something that is not the job -- an arrest, mostly.
## Puts the camera, the doors and the driver back the way _end always does, but
## tells nobody it succeeded or failed, because neither happened. Hands back
## the car it had hold of so the caller can decide what becomes of it.
func cancel() -> Vehicle:
	if not active:
		return null
	var was := _vehicle
	_end()
	return was

func _complete() -> void:
	# a numbered panel off the car is one less thing a check can match
	if is_instance_valid(_vehicle) and GameData.VIN_PARTS.has(_part_id):
		_vehicle.panels_done += 1
	_end()
	if _done_cb.is_valid():
		_done_cb.call(true, quality)

func _end() -> void:
	active = false
	visible = false
	_limit = -1.0
	_grabbed = -1
	_hover = -1
	_props.clear()
	_drop_tool_node()
	if is_instance_valid(_rig):
		_rig.queue_free()
	_rig = null
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if is_instance_valid(_vehicle):
		# anything still bolted on comes back; anything pulled stays gone
		_vehicle.refresh_part_meshes()
		if _hid_occupant:
			_vehicle.set_occupant_visible(true)
		# and a door that survived gets pushed shut again on the way out
		if _part_id.begins_with("door") and _vehicle.parts_remaining.has(_part_id):
			_vehicle.close_door(_part_id)
		_vehicle.set_label_visible(true)
	_hid_occupant = false
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.get("body_mesh") != null and pl.get("current_vehicle") == null:
		pl.body_mesh.visible = true
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true

# ------------------------------------------------------------
#  Building a stage of props on the car
# ------------------------------------------------------------
## On to the next one, doing whatever the stage just finished asked for on the
## way out -- hauling a door open, mostly, so the next stage looks into it.
func _next_stage() -> void:
	if _stage < _stages.size():
		var opens := String((_stages[_stage] as Dictionary).get("opens", ""))
		if opens != "" and is_instance_valid(_vehicle):
			_vehicle.open_door(opens)
	_stage += 1
	_build_stage()

func _build_stage() -> void:
	for p in _props:
		if is_instance_valid(p.node):
			p.node.queue_free()
	_props.clear()
	if _stage >= _stages.size():
		_complete()
		return

	var st: Dictionary = _stages[_stage]
	var dir: Vector3 = Vector3(st.get("dir", Vector3(0, 1, 0))).normalized()
	var per_prop: Array = st.get("props", [])
	# every position below is written against the box cars; this car decides
	# where that lands on its own body
	var key := String(st.get("rig", _part_id))
	var positions: Array = []
	if st.has("at"):
		for v in st.at:
			positions.append(_vehicle.rig_prop(v, key))
	else:
		var origin: Vector3 = _vehicle.rig_prop(st.get("origin", Vector3(0, 1.1, -1.6)), key)
		for off in _layout(String(st.get("pattern", "single")), int(st.get("count", 1)), dir, float(st.get("radius", 0.3))):
			positions.append(origin + off)
	# a PULL prop is the part itself, so it belongs where the part actually
	# sits rather than where the box cars keep theirs
	if String(st.type) == "PULL" and positions.size() == 1:
		if String(st.get("mesh", "")) == "driver" and _vehicle.has_occupant():
			positions[0] = _vehicle.occupant_centre()
		else:
			positions[0] = _vehicle.part_centre(String(st.get("mesh", _part_id)), positions[0])

	var centroid := Vector3.ZERO
	for i in positions.size():
		var pd: Dictionary = per_prop[i] if i < per_prop.size() else {}
		_props.append(_make_prop(st, positions[i], dir, pd))
		centroid += positions[i]
	centroid /= float(maxi(1, positions.size()))

	_limit = float(st.get("limit", -1.0))
	_cam.fov = float(st.get("fov", 58.0))
	_move_camera(_vehicle.rig_cam(st.get("cam", Vector3(2.6, 1.8, -1.0))), centroid)
	# the jimmy, the reader and the jack are not sitting on the car waiting for
	# you -- they are on your belt, and there is nothing to see at the work
	# until you have carried them over
	for p in _props:
		if GameData.PROP_IS_TOOL.has(String(p.type)):
			(p.mesh as Node3D).visible = false
	_stage_tool(st)
	_mark_spots()
	_refresh_strip()

## Fallback layout for stages that give a pattern instead of exact spots.
func _layout(pattern: String, count: int, normal: Vector3, radius: float) -> Array:
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var ax := normal.cross(up).normalized()
	var ay := ax.cross(normal).normalized()
	var out := []
	for i in count:
		match pattern:
			"circle":
				var a := TAU * float(i) / float(count)
				out.append((ax * cos(a) + ay * sin(a)) * radius)
			"row":
				out.append(ax * (float(i) - float(count - 1) * 0.5) * 0.46)
			"col":
				out.append(ay * (float(i) - float(count - 1) * 0.5) * 0.44)
			_:
				out.append(Vector3.ZERO)
	return out

func _make_prop(st: Dictionary, pos: Vector3, dir: Vector3, pd: Dictionary = {}) -> Dictionary:
	var type := String(st.type)
	var node := Node3D.new()
	node.position = pos
	_rig.add_child(node)

	var mesh_root := Node3D.new()
	node.add_child(mesh_root)

	# fastener-ish props point their +Z along the direction they back out;
	# a whole part keeps the car's own orientation so it reads as that part.
	var base_basis := Basis.IDENTITY
	if type != "PULL":
		base_basis = Basis.looking_at(-dir, Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD)
		mesh_root.basis = base_basis

	var size := 0.22
	var glow := 0.45
	match type:
		"BOLT":
			# a door bolt goes through a hinge leaf, and you can see the barrel
			# it all swings on -- the pair share one, so only the first draws it
			if bool(pd.get("hinge", false)):
				# the knuckle the door swings on sits at the FRONT edge. The
				# frame here is built by looking_at, which flips local X from
				# one flank to the other, so a fixed offset puts the knuckle
				# forward on one door and backwards on the other -- hence the
				# hand, which keeps it on the pivot side of both.
				# which flank we are on, taken from where the bolt is rather
				# than which way it faces -- the fasteners point fore-and-aft
				# now, so the direction says nothing about the side
				var hand := signf(pos.x) if absf(pos.x) > 0.01 else -1.0
				_box(mesh_root, Vector3(0.34, 0.30, 0.05), Color(0.36, 0.36, 0.4),
					Vector3(0, -0.09, 0.012))
				_cyl(mesh_root, 0.055, 0.42, Color(0.55, 0.56, 0.6),
					Vector3(0.19 * hand, -0.09, 0.02), Vector3.ZERO)
				size = 0.24
			_cyl(mesh_root, 0.085, 0.09, CHROME, Vector3(0, 0, 0.05))
			_cyl(mesh_root, 0.042, 0.17, Color(0.42, 0.42, 0.46), Vector3(0, 0, -0.04))
		"CLAMP":
			var col := Color(0.85, 0.12, 0.12) if String(st.get("color", "red")) == "red" else Color(0.12, 0.12, 0.14)
			_box(mesh_root, Vector3(0.16, 0.12, 0.1), col, Vector3(0, 0, 0.05))
			_cyl(mesh_root, 0.055, 0.1, CHROME, Vector3(0, 0, 0.13))
			size = 0.24
		"PLUG":
			_box(mesh_root, Vector3(0.19, 0.14, 0.16), Color(0.14, 0.14, 0.17), Vector3(0, 0, 0.08))
			_box(mesh_root, Vector3(0.08, 0.04, 0.06), Color(0.9, 0.7, 0.1), Vector3(0, 0.09, 0.08))
			size = 0.24
		"CUT":
			_cyl(mesh_root, 0.075, 0.6, Color(0.34, 0.3, 0.27), Vector3.ZERO, Vector3(0, 0, 90))
			_box(mesh_root, Vector3(0.08, 0.22, 0.22), Color(0.9, 0.35, 0.1), Vector3.ZERO)
			size = 0.3
		"PULL":
			if String(st.get("swing", "")) != "":
				# the thing you take hold of is the car's own door, so there is
				# nothing to draw -- just somewhere to put your hand
				size = 0.5
			else:
				size = _part_mesh(mesh_root, String(st.get("mesh", _part_id)))
			glow = 0.18   # a whole panel does not need to shine like a bolt
			for mi in _meshes_under(mesh_root) if String(st.get("swing", "")) == "" else []:
				var m := mi.material_override as StandardMaterial3D
				if m:
					m.emission_energy_multiplier = glow
		"JIMMY":
			size = _build_jimmy(mesh_root)
			glow = 0.5
		"WIRE":
			size = _wire_mesh(mesh_root, pd)
		"JOIN":
			size = _wire_mesh(mesh_root, pd)
			size = 0.17
		"SCAN":
			# the key tool itself, held flat against the door skin: a slab with
			# a stub aerial and a lamp on the back that you are watching
			_box(mesh_root, Vector3(0.16, 0.26, 0.05), Color(0.11, 0.12, 0.15), Vector3(0, 0, 0.04))
			_cyl(mesh_root, 0.012, 0.14, Color(0.5, 0.5, 0.55), Vector3(0.05, 0.18, 0.04))
			_box(mesh_root, Vector3(0.06, 0.03, 0.02), Color(0.2, 1.0, 0.5), Vector3(0, 0.07, 0.07))
			size = 0.26
		"PUMP":
			_cyl(mesh_root, 0.06, 0.7, Color(0.9, 0.55, 0.1), Vector3(0, 0.28, 0.06))
			_box(mesh_root, Vector3(0.4, 0.22, 0.4), Color(0.4, 0.4, 0.45), Vector3(0, -0.14, 0))
			size = 0.45

	var area := Area3D.new()
	area.collision_layer = PROP_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = size
	cs.shape = sph
	area.add_child(cs)
	node.add_child(area)
	area.set_meta("prop", _props.size())

	return {
		"type": type, "node": node, "mesh": mesh_root, "area": area, "st": st, "pd": pd,
		"progress": 0.0, "spin": 0.0, "heat": 0.0, "lock": 0.0, "phase": 0,
		"done": bool(pd.get("scenery", false)),
		"dir": dir, "base": base_basis, "glow": glow,
		"decoy": bool(pd.get("decoy", false)) or bool(pd.get("scenery", false)),
		"angle": 0.0, "lift": 0.0, "sink": 0.0, "size": size, "ghost": null,
		"spots": [], "caught": [], "tip": null, "rod": null, "noise": 0.0,
	}

# ------------------------------------------------------------
#  The part you are actually pulling off
# ------------------------------------------------------------
## The part you are pulling is the same shape it will be when it is lying
## on the garage floor. Hides the car copy so you drag the thing you see.
func _part_mesh(root: Node3D, id: String) -> float:
	var body: Color = _vehicle.data.get("color", Color(0.6, 0.6, 0.6)) if _vehicle else Color(0.6, 0.6, 0.6)
	# the person you are dragging out is the person who was sitting there, not
	# a stand-in: the real one is hidden while you have hold of the copy
	if id == "driver" and _vehicle and _vehicle.has_occupant():
		var who := _vehicle.make_occupant_visual()
		if who != null:
			_vehicle.set_occupant_visible(false)
			_hid_occupant = true
			root.add_child(who)
			return 0.55
	if _vehicle and _vehicle.has_part_mesh(id):
		_vehicle.set_part_mesh_visible(id, false)
		# drag the actual part off the car, not a stand-in box
		var real: Node3D = _vehicle.make_part_visual(id)
		if real != null:
			root.add_child(real)
			return 0.45
	return PartMesh.build(root, id, body)

## Handle above the window seal, tip down inside the door, and a ghosted
## view of the lock rod so you can see what you are feeling for.
func _build_jimmy(root: Node3D) -> float:
	var count := GameState.jimmy_hotspots(_vehicle.data) if _vehicle else 1
	var tol := GameState.jimmy_tolerance(_vehicle.data) if _vehicle else 0.2

	# This prop is built in a frame where local X runs ALONG the door, local Y
	# is up and local Z points out of it. Everything below stays in the plane
	# of the door -- the tool must never swing out towards the camera.
	var line := _box(root, Vector3(1.5, 0.06, 0.05), Color(0.85, 0.87, 0.92), Vector3.ZERO)
	line.material_override.emission_energy_multiplier = 1.0
	_jimmy_line = line
	_jimmy_spots.clear()
	_jimmy_marks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_vehicle.data.get("value", 1)) + count * 7

	# Nothing catches where the tool went in. The tip starts at nought and the
	# slop on a junker is wide enough that a catch anywhere near the middle is
	# already under it -- you shove the jimmy down and the door is open, and
	# the two steps run together into one. So the catches are kept a full
	# tool-width clear of the entry, and clear of each other.
	var gap: float = minf(tol + 0.10, REACH - 0.08)
	var pool := []
	var at := -REACH + 0.04
	while at <= REACH - 0.04:
		if absf(at) >= gap:
			pool.append(at)
		at += 0.04
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for cand: float in pool:
		if _jimmy_spots.size() >= count:
			break
		var clear := true
		for c: float in _jimmy_spots:
			if absf(cand - c) < tol * 2.0 + 0.05:
				clear = false
				break
		if clear:
			_jimmy_spots.append(cand)
	if _jimmy_spots.is_empty():
		_jimmy_spots.append(gap * (1.0 if rng.randf() < 0.5 else -1.0))
	for spot: float in _jimmy_spots:
		var mark := _box(root, Vector3(tol * 2.0, 0.2, 0.07), Color(0.95, 0.72, 0.15),
			Vector3(spot, 0, 0))
		mark.material_override.emission_energy_multiplier = 1.0
		_jimmy_marks.append(mark)

	# the tool: pivots on the window seal above, tip reaches down to the rod
	_jimmy_rod = Node3D.new()
	_jimmy_rod.position = Vector3(0, PIVOT, 0)
	root.add_child(_jimmy_rod)
	_box(_jimmy_rod, Vector3(0.04, PIVOT + 0.4, 0.04), Color(0.82, 0.84, 0.88), Vector3(0, (0.4 - PIVOT) * 0.5, 0))
	_box(_jimmy_rod, Vector3(0.26, 0.14, 0.1), Color(0.2, 0.2, 0.24), Vector3(0, 0.33, 0))
	_jimmy_tip = _box(_jimmy_rod, Vector3(0.12, 0.12, 0.08), Color(0.75, 0.78, 0.8), Vector3(0, -PIVOT, 0))
	_jimmy_tip.material_override.emission_energy_multiplier = 0.5

	# it starts sat on the seal with the tip still outside the door, and there
	# is nothing to see down there until you have worked it in: the rod and the
	# catches on it are hidden behind sheet metal, same as they would be
	_jimmy_rod.position.y = PIVOT + DROP
	_jimmy_line.visible = false
	for m in _jimmy_marks:
		(m as Node3D).visible = false
	return 0.85

## Distance from the window seal down to the lock rod -- the tool lever arm.
const PIVOT := 0.55
## How far the tool has to be shoved past the seal before it is in the door.
const DROP := 0.30
## How far along the lock rod the tip can reach either side of centre.
const REACH := 0.5

var _jimmy_spots := []
var _jimmy_marks := []
var _jimmy_rod: Node3D = null
var _jimmy_line: MeshInstance3D = null
var _jimmy_tip: MeshInstance3D = null

## A wire: copper core with an insulation sleeve over it. `bare` draws it
## already scraped, `joined` draws it as a pair twisted together.
func _wire_mesh(root: Node3D, pd: Dictionary) -> float:
	var wc: Color = pd.get("colour", Color(0.6, 0.6, 0.6))
	_cyl(root, 0.02, 0.3, COPPER, Vector3.ZERO, Vector3.ZERO)
	var sleeve := _cyl(root, 0.034, 0.3, wc, Vector3.ZERO, Vector3.ZERO)
	if bool(pd.get("bare", false)):
		_strip_sleeve(sleeve, 1.0)
	if bool(pd.get("joined", false)):
		# the wire it is already twisted onto, plus the joint itself
		var other: Color = pd.get("colour2", Color(0.6, 0.6, 0.6))
		_cyl(root, 0.02, 0.3, COPPER, Vector3(PAIR_GAP, 0, 0), Vector3.ZERO)
		var s2 := _cyl(root, 0.034, 0.3, other, Vector3(PAIR_GAP, 0, 0), Vector3.ZERO)
		_strip_sleeve(s2, 1.0)
		_joint_band(root, Vector3(PAIR_GAP * 0.5, 0.12, 0))
	return 0.16

## The insulation slides DOWN off the wire, baring the top end -- the end you
## are going to twist onto something.
func _strip_sleeve(sleeve: MeshInstance3D, amount: float) -> void:
	sleeve.scale.y = lerpf(1.0, 0.3, amount)
	sleeve.position.y = lerpf(0.0, -0.105, amount)

## The bright twist where two bared ends are wrapped together.
func _joint_band(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var band := _cyl(parent, 0.05, 0.075, Color(0.95, 0.7, 0.35), pos, Vector3(0, 0, 90))
	band.material_override.emission_energy_multiplier = 1.3
	return band

func _box(parent: Node, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node, r: float, h: float, color: Color, pos: Vector3, rot: Vector3 = Vector3(90, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.45
	return m

func _move_camera(cam_local: Vector3, look_local: Vector3) -> void:
	if _cam == null or not is_instance_valid(_vehicle):
		return
	_cam_local = cam_local
	_look_local = look_local
	_cam_follow = true

## Where the camera belongs right now, in world space. Recomputed every frame
## once the move is done -- the car settles on its springs, gets jacked up, or
## gets nudged, and the shot has to stay on the job either way.
func _rig_camera() -> Transform3D:
	var pos: Vector3 = _vehicle.to_global(_cam_local)
	var look: Vector3 = _vehicle.to_global(_look_local)
	var t := Transform3D().looking_at(look - pos, Vector3.UP)
	t.origin = pos
	return t

# ------------------------------------------------------------
#  Feedback
# ------------------------------------------------------------
func _refresh_strip() -> void:
	if _stage >= _stages.size():
		return
	var st: Dictionary = _stages[_stage]
	_title_label.text = "%s   -   stage %d of %d" % [_title, _stage + 1, _stages.size()]
	if float(st.get("limit", -1.0)) > 0.0:
		_title_label.text += "   [%.1fs]" % maxf(_limit, 0.0)
	_step_label.text = String(st.label)
	if is_instance_valid(_tool) and _tool_on < 0:
		var what := GameData.hold_name(_tool_id)
		_hint_label.text = ("Grab the %s in front of you and drag it onto the marked spot."
			% what) if _open_spots() < 2 else (
			"Grab the %s in front of you and drag it onto one of the marked bolts. [RMB] takes it back off."
			% what)
		_hint_label.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	else:
		_hint_label.text = _hint_for(String(st.type), st)
		_hint_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_update_bar()

func _hint_for(type: String, st: Dictionary) -> String:
	var slow := String(st.get("slow_without", ""))
	var slog := slow != "" and not GameState.has_shop_tool(slow)
	match type:
		"BOLT", "CLAMP":
			return "Hold [LMB] on a fastener and turn the mouse ANTICLOCKWISE. Lefty loosey."
		"PLUG":
			return "Hold [LMB] and ease it straight out. Yank it and the clip snaps."
		"CUT":
			return "Hold [LMB] and drag back and forth across the cut." + ("   (hacksaw - this will take a while)" if slog else "")
		"PULL":
			if String(st.get("swing", "")) != "":
				return "Grab the door on the green mark and drag it OPEN. They are pulling the other way."
			return "Hold [LMB] and drag it off the car." + ("   (no hoist - by hand, then)" if slog else "")
		"PUMP":
			return "Hold [LMB] on the handle and drag down, then up. Again. And again."
		"JIMMY":
			if _tool_on >= 0 and _tool_on < _props.size() and int(_props[_tool_on].phase) == 0:
				return "Hold [LMB] on the handle and drag DOWN to work it past the window seal."
			return "Hold [LMB] on the handle. Slide it along to move the tip, then push the handle DOWN -- it levers the tip up onto the rod."
		"WIRE":
			return "Click a wire to pull it out, then drag across it to scrape the insulation."
		"JOIN":
			return "Hold [LMB] and drag the end onto the other one."
		"SCAN":
			return "Hold [LMB] on the reader and keep the mouse STILL. Move it and the handshake drops."
	return ""

func _update_bar() -> void:
	var total := float(maxi(1, _props.size()))
	var done := 0.0
	for p in _props:
		done += 1.0 if p.done else clampf(p.progress, 0.0, 1.0)
	_bar.size.x = 480.0 * clampf(done / total, 0.0, 1.0)
	var pct := int(round(quality * 100.0))
	var col := Color(0.6, 1.0, 0.6)
	if quality < 0.9:
		col = Color(1, 0.85, 0.4)
	if quality < 0.7:
		col = Color(1, 0.45, 0.35)
	_qual_label.add_theme_color_override("font_color", col)
	_qual_label.text = "PART CONDITION %d%%     [Esc] walk away" % pct

func _penalise(amount: float, msg: String) -> void:
	quality = maxf(0.4, quality - amount)
	_flash = 0.4
	_hint_label.text = msg
	_hint_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35))

# ------------------------------------------------------------
#  Per-frame
# ------------------------------------------------------------
func _process(delta: float) -> void:
	if not active:
		return
	# a stage with a clock on it: run out of time and the whole job is off
	if _limit > 0.0:
		_limit -= delta
		_title_label.text = "%s   -   stage %d of %d   [%.1fs]" % [
			_title, _stage + 1, _stages.size(), maxf(_limit, 0.0)]
		if _limit <= 0.0:
			_limit = -1.0
			_end()
			if _done_cb.is_valid():
				_done_cb.call(false, quality)
			return
	# glide onto the job and then stay locked to it -- the car settles on its
	# springs, gets jacked up, gets nudged, and the shot has to follow
	if _cam_follow and is_instance_valid(_cam) and is_instance_valid(_vehicle):
		_cam.global_transform = _cam.global_transform.interpolate_with(
			_rig_camera(), clampf(delta * 7.0, 0.0, 1.0))
	if _flash > 0.0:
		_flash -= delta
	# the loose tool and the spots it can go on breathe together
	if _tool_on < 0 and (is_instance_valid(_tool) or _swing_stage()):
		_pulse += delta
		var beat := absf(sin(_pulse * 2.6))
		if is_instance_valid(_tool_ring) and _tool_ring.visible:
			var tm := _tool_ring.material_override as StandardMaterial3D
			if tm:
				tm.albedo_color.a = 0.65 + 0.35 * beat
		for i in _props.size():
			var p: Dictionary = _props[i]
			if i == _tool_on or p.ghost == null or not is_instance_valid(p.ghost):
				continue
			if not (p.ghost as Node3D).visible:
				continue
			var gm := (p.ghost as MeshInstance3D).material_override as StandardMaterial3D
			if gm:
				gm.albedo_color.a = 0.6 + 0.4 * beat
	for p in _props:
		if p.lock > 0.0:
			p.lock -= delta
		if p.type == "CUT" and not p.done and p.mesh.get_child_count() > 1:
			var blade := p.mesh.get_child(1) as MeshInstance3D
			if blade:
				blade.material_override = _mat(Color(0.9, 0.35, 0.1).lerp(Color(1, 0.12, 0.1), p.heat))
			p.heat = maxf(0.0, p.heat - 0.55 * delta)
	# the reader does its own work: hold it where it is and wait for the answer
	if _grabbed >= 0 and _grabbed < _props.size():
		var g: Dictionary = _props[_grabbed]
		if String(g.type) == "SCAN" and not g.done:
			g.progress = clampf(g.progress + delta / SCAN_SECS, 0.0, 1.0)
			var lamp := _meshes_under(g.mesh)
			if lamp.size() >= 3 and lamp[2].material_override is StandardMaterial3D:
				var lit: StandardMaterial3D = lamp[2].material_override
				lit.emission_energy_multiplier = 0.4 + 2.4 * absf(sin(g.progress * 18.0))
			if g.progress >= 1.0:
				_finish_prop(g, 0.0)
	if _grabbed < 0:
		_update_hover()
	_update_bar()

func _update_hover() -> void:
	var was := _hover
	# while the tool is in the air the thing worth lighting up is the fastener
	# you are holding it over, not the tool filling the cursor
	_hover = _prop_under(get_viewport().get_mouse_position()) if _tool_drag else _pick()
	if was == _hover:
		return
	for i in _props.size():
		var p: Dictionary = _props[i]
		if p.done:
			continue
		var lit := i == _hover
		var tint: bool = p.type == "BOLT" or p.type == "CLAMP" or p.type == "PLUG"
		var glow: float = float(p.glow)
		for mi in _meshes_under(p.mesh):
			if mi.material_override is StandardMaterial3D:
				var m: StandardMaterial3D = mi.material_override
				m.emission_enabled = true
				m.emission = Color(1.0, 0.9, 0.4) if (lit and tint) else m.albedo_color
				m.emission_energy_multiplier = (glow + 0.45) if lit else glow

func _pick() -> int:
	if _cam == null or not is_instance_valid(_cam):
		return -1
	var mp := get_viewport().get_mouse_position()
	var from := _cam.project_ray_origin(mp)
	var to := from + _cam.project_ray_normal(mp) * 30.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = PROP_LAYER
	var hit := _cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1
	var area := hit.collider as Area3D
	if area == null or not area.has_meta("prop"):
		return -1
	var i := int(area.get_meta("prop"))
	if i == TOOL_META:
		return TOOL_META
	if i >= 0 and i < _props.size() and not _props[i].done:
		return i
	return -1

# ------------------------------------------------------------
#  The thing in your hand
# ------------------------------------------------------------
## Which of the tools this stage accepts is actually on your belt. Falls back
## to the first one it asks for, so the shot still reads if you turned up
## without it and the stage let you through anyway.
func _tool_for(st: Dictionary) -> String:
	var want: Array = GameData.tools_for_stage(st, _part_id)
	for id in want:
		if GameState.carrying_item(String(id)):
			return String(id)
	if not want.is_empty():
		return String(want[0])
	# a cut is made with whatever is in the shop: the saw if it was bought, and
	# a hacksaw and a long afternoon if it was not
	if String(st.get("type", "")) == "CUT":
		return "sawzall" if GameState.has_shop_tool("sawzall") else "hacksaw"
	return GameData.hold_for_stage(st, _part_id)

## Set the stage up with whatever it needs in hand. A stage that wants the same
## tool as the last one leaves it exactly where you put it down -- the wrench
## does not teleport back to your hip between bolts.
func _stage_tool(st: Dictionary) -> void:
	var want := _tool_for(st)
	if want == _tool_id and is_instance_valid(_tool):
		# same tool as the last stage, so it stays exactly where it was put
		# down -- but the new stage's spots still want marking
		_tool_on = -1
		_tool.visible = true
		_tool_glow(true)
		_mark_spots()
		return
	_drop_tool_node()
	_tool_id = want
	if _tool_id == "":
		return
	_tool = Node3D.new()
	var holder := Node3D.new()
	_tool.add_child(holder)
	_build_tool(holder, _tool_id)
	# the band that marks it out, sat round the working end
	_tool_ring = MeshInstance3D.new()
	var band := TorusMesh.new()
	band.outer_radius = 0.085
	band.inner_radius = 0.062
	_tool_ring.mesh = band
	var bandm := StandardMaterial3D.new()
	bandm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bandm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bandm.albedo_color = Color(1.0, 0.85, 0.3)
	_tool_ring.material_override = bandm
	_tool_ring.basis = Basis(Vector3.RIGHT, PI * 0.5)
	_tool_ring.position = Vector3(0, 0, 0.13)
	holder.add_child(_tool_ring)
	var area := Area3D.new()
	area.collision_layer = PROP_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	cs.shape = sph
	area.add_child(cs)
	_tool.add_child(area)
	area.set_meta("prop", TOOL_META)
	# a lamp on it, so the thing you are being told to pick up is the brightest
	# object in the shot instead of one more grey shape on a grey car
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.3)
	lamp.light_energy = 0.85
	lamp.omni_range = 1.25
	lamp.shadow_enabled = false
	_tool.add_child(lamp)
	_rig.add_child(_tool)
	_tool.position = _belt_spot()
	_tool_base = Basis.IDENTITY
	_tool_on = -1
	_tool_glow(true)
	_mark_spots()

## A marker on every spot this tool can go. Drawn with the depth test off, so a
## bolt buried a hand's width inside a door panel is still somewhere you can
## see and aim at rather than a place you are guessing about.
## Does this one want a ring on it? Anything a tool goes on does, and so does
## anything you take hold of bare handed that is not a prop you can see -- the
## door on a carjacking is the car's own door, so without a ring there is
## nothing telling you where to grab it.
func _wants_marker(p: Dictionary) -> bool:
	return is_instance_valid(_tool) or String(p.st.get("swing", "")) != ""

## Is this stage one where you haul on the car's own door?
func _swing_stage() -> bool:
	for p in _props:
		if not p.done and String(p.st.get("swing", "")) != "":
			return true
	return false

func _mark_spots() -> void:
	for p in _props:
		if p.done or p.decoy or p.ghost != null or not _wants_marker(p):
			continue
		# a thin ring round the rim of the head, sat just off it. A solid block
		# over the whole fastener tells you where it is and hides what it is,
		# which is worse than nothing on a stage with four of them in a row.
		var g := MeshInstance3D.new()
		var ring := TorusMesh.new()
		var r: float = clampf(float(p.size) * 0.26, 0.045, 0.15)
		ring.outer_radius = r
		ring.inner_radius = r * 0.76
		g.mesh = ring
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# green means take hold of it; yellow means the tool goes here
		m.albedo_color = (Color(0.35, 1.0, 0.5, 0.9) if String(p.st.get("swing", "")) != ""
			else Color(1.0, 0.85, 0.25, 0.85))
		m.no_depth_test = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		g.material_override = m
		g.sorting_offset = 2.0
		# the ring lies in the face of the fastener, round the edge of the head
		var facing: Vector3 = p.dir
		g.basis = Basis.looking_at(-facing,
			Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
		g.position = facing * 0.07
		if String(p.type) == "JIMMY":
			# the rod is down inside the door; the seal is where you put it
			g.position += Vector3(0, 0.24, 0)
		(p.node as Node3D).add_child(g)
		p.ghost = g
	_show_spots()

## How many spots on this stage are still waiting for the tool.
func _open_spots() -> int:
	var n := 0
	for p in _props:
		if not p.done and not p.decoy:
			n += 1
	return n

## Every spot still wanting the tool stays marked -- including while you are
## turning one of the others, because the whole point is being able to see
## where the wrench goes next without hunting for it.
func _show_spots() -> void:
	for i in _props.size():
		var p: Dictionary = _props[i]
		if p.ghost == null or not is_instance_valid(p.ghost):
			continue
		# the one the tool is sat on hides its own ring -- the tool is there and
		# you can see it; everything still queued keeps one
		(p.ghost as MeshInstance3D).visible = _wants_marker(p) and not p.done and i != _tool_on

## A lit band round the tool, not a lit tool. Setting emission on every surface
## of it turns a wrench into a torch: you lose the shape of the thing you are
## holding, which is the one bit of information that matters.
func _tool_glow(loose: bool) -> void:
	if not is_instance_valid(_tool) or not is_instance_valid(_tool_ring):
		return
	# the band is there to help you find it the first time and for nothing
	# else. Once it has been in your hand you know what a wrench looks like.
	_tool_ring.visible = loose and not _tool_touched
	for lamp in _tool.get_children():
		if lamp is OmniLight3D:
			# enough to pick it out and light the fastener it is on, not
			# enough to blow the whole panel out to a yellow smear
			(lamp as OmniLight3D).light_energy = 0.5 if loose else 0.75
			(lamp as OmniLight3D).omni_range = 1.1 if loose else 1.4

## Held up in front of you, middle of the shot and a little low -- not down in
## the corner where the hint text sits on top of it. Worked off where the camera
## is going to settle rather than where it is this frame, because it is still
## gliding onto the job when the stage is built.
func _belt_spot() -> Vector3:
	if _rig == null or not is_instance_valid(_vehicle):
		return Vector3.ZERO
	var t := _rig_camera()
	return _rig.to_local(t.origin + t.basis * Vector3(0.0, -0.24, -1.65))

func _drop_tool_node() -> void:
	if is_instance_valid(_tool):
		_tool.queue_free()
	_tool = null
	_tool_ring = null
	_tool_touched = false
	_tool_id = ""
	_tool_on = -1
	_tool_drag = false

## Carrying it about: it tracks the cursor across the plane it is already on,
## and it stays there when you let go.
##
## Once it is off the hook the tool lives on the plane of the work and nowhere
## else. It is picked up about a metre from the eye and the job is better than
## two out, and anything that eases between the two reads as the tool sliding
## towards you and away again while you are trying to aim it. So: no easing.
## Move the mouse, the tool moves across the work. That is all it does.
func _carry_tool(mp: Vector2) -> void:
	if not is_instance_valid(_tool) or _cam == null:
		return
	var over := _prop_under(mp)
	_tool_depth = _work_depth(mp)
	var at := _cam.project_ray_origin(mp) + _cam.project_ray_normal(mp) * _tool_depth
	_tool.position = _rig.to_local(at)
	_tool.basis = Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, -0.35)
	_hint_label.text = ("Let go -- it goes on that one." if over >= 0
		else "Hold it over one of the marked spots.")
	_hint_label.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if over >= 0 else Color(0.85, 0.85, 0.85))

## How far out the work is. The fastener under the cursor if there is one, and
## otherwise the middle of everything this stage wants doing, so the tool sits
## on the job's own plane rather than somewhere between it and your chest.
func _work_depth(mp: Vector2) -> float:
	if _cam == null or not is_instance_valid(_cam):
		return _tool_depth
	var eye := _cam.global_position
	var over := _prop_under(mp)
	if over >= 0:
		return eye.distance_to((_props[over].node as Node3D).global_position)
	var total := 0.0
	var n := 0
	for p in _props:
		if p.done or p.decoy:
			continue
		total += eye.distance_to((p.node as Node3D).global_position)
		n += 1
	return total / float(n) if n > 0 else _tool_depth

## Whichever fastener the cursor is over, measured on the screen. How far the
## tool is from one in metres says nothing about whether you are pointing at
## it, because the tool is being slid about on a flat plane.
func _prop_under(mp: Vector2) -> int:
	if _cam == null or not is_instance_valid(_cam):
		return -1
	var reach: float = maxf(30.0, get_viewport().get_visible_rect().size.y * 0.05)
	var best := -1
	var best_d := reach
	for i in _props.size():
		var p: Dictionary = _props[i]
		if p.done or p.decoy:
			continue
		var world: Vector3 = (p.node as Node3D).global_position
		if _cam.is_position_behind(world):
			continue
		var d := mp.distance_to(_cam.unproject_position(world))
		if d < best_d:
			best_d = d
			best = i
	return best

## What the tool would go onto if it were let go now: whatever the cursor is
## over, or failing that whatever it is actually sitting on.
func _nearest_prop() -> int:
	var pick := _prop_under(get_viewport().get_mouse_position())
	if pick >= 0:
		return pick
	if not is_instance_valid(_tool):
		return -1
	var here := _tool.global_position
	var best := -1
	var best_d := TOOL_SNAP
	for i in _props.size():
		var p: Dictionary = _props[i]
		if p.done or p.decoy:
			continue
		var d := here.distance_to((p.node as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = i
	return best

func _drop_tool() -> void:
	_tool_drag = false
	var near := _nearest_prop()
	if near < 0:
		_refresh_strip()
		return
	_seat_tool(near)

## On it, square to the work, ready to be turned.
func _seat_tool(i: int) -> void:
	var p: Dictionary = _props[i]
	_tool_on = i
	var dir: Vector3 = p.dir
	_tool_base = Basis.looking_at(-dir, Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD)
	_tool.position = (p.node as Node3D).position + dir * TOOL_STANDOFF
	_tool.basis = _tool_base
	# for the jobs where the tool IS the job, the prop was not there to look at
	# until you carried it over. Now it is, and the tool goes in your other hand.
	if GameData.PROP_IS_TOOL.has(String(p.type)):
		(p.mesh as Node3D).visible = true
		_tool.visible = false
	_tool_glow(false)
	_show_spots()
	_refresh_strip()

## Back off the fastener without finishing it, so it can go somewhere else.
func _unseat_tool() -> void:
	if _tool_on >= 0 and _tool_on < _props.size():
		var p: Dictionary = _props[_tool_on]
		if GameData.PROP_IS_TOOL.has(String(p.type)) and not p.done:
			(p.mesh as Node3D).visible = false
	_tool_on = -1
	_grabbed = -1
	if is_instance_valid(_tool):
		_tool.visible = true
	_tool_glow(true)
	_show_spots()
	_refresh_strip()

## Turning the fastener turns the thing on it.
func _spin_tool(angle: float) -> void:
	if is_instance_valid(_tool) and _tool_on >= 0 and _tool.visible:
		_tool.basis = Basis(_props[_tool_on].dir, angle) * _tool_base

## What each one looks like. All of them point their business end down -Z, the
## same way a fastener prop faces, so seating one is a straight basis swap.
func _build_tool(root: Node3D, id: String) -> void:
	match id:
		"socket_wrench":
			_box(root, Vector3(0.07, 0.06, 0.46), Color(0.62, 0.64, 0.7), Vector3(0, 0, 0.29))
			_box(root, Vector3(0.085, 0.075, 0.18), Color(0.2, 0.2, 0.24), Vector3(0, 0, 0.44))
			_cyl(root, 0.085, 0.09, CHROME, Vector3(0, 0, 0.055))
			_cyl(root, 0.058, 0.07, Color(0.3, 0.3, 0.34), Vector3(0, 0, 0.008))
		"impact_drill":
			_box(root, Vector3(0.13, 0.15, 0.2), Color(0.9, 0.55, 0.15), Vector3(0, 0, 0.17))
			_box(root, Vector3(0.09, 0.24, 0.11), Color(0.2, 0.2, 0.23), Vector3(0, -0.17, 0.22))
			_cyl(root, 0.05, 0.13, CHROME, Vector3(0, 0, 0.06))
		"tire_iron":
			_cyl(root, 0.022, 0.5, Color(0.45, 0.45, 0.5), Vector3(0, 0, 0.28), Vector3(90, 0, 0))
			_cyl(root, 0.022, 0.34, Color(0.45, 0.45, 0.5), Vector3(0, 0, 0.2), Vector3(0, 90, 0))
			_cyl(root, 0.04, 0.07, CHROME, Vector3(0, 0, 0.04))
		"jimmy":
			_box(root, Vector3(0.035, 0.02, 0.66), Color(0.78, 0.8, 0.85), Vector3(0, 0, 0.33))
			_box(root, Vector3(0.035, 0.09, 0.02), Color(0.78, 0.8, 0.85), Vector3(0, -0.04, 0.02))
			_box(root, Vector3(0.05, 0.05, 0.14), Color(0.2, 0.2, 0.24), Vector3(0, 0, 0.6))
		"scanner":
			_box(root, Vector3(0.16, 0.26, 0.05), Color(0.11, 0.12, 0.15), Vector3(0, 0, 0.05))
			_cyl(root, 0.012, 0.14, Color(0.5, 0.5, 0.55), Vector3(0.05, 0.18, 0.05))
			_box(root, Vector3(0.06, 0.03, 0.02), Color(0.2, 1.0, 0.5), Vector3(0, 0.07, 0.08))
		"sawzall":
			_box(root, Vector3(0.11, 0.14, 0.28), Color(0.85, 0.35, 0.12), Vector3(0, 0, 0.26))
			_box(root, Vector3(0.02, 0.05, 0.24), Color(0.7, 0.72, 0.76), Vector3(0, 0, 0.05))
		"hacksaw":
			_box(root, Vector3(0.02, 0.19, 0.34), Color(0.3, 0.31, 0.35), Vector3(0, 0.11, 0.2))
			_box(root, Vector3(0.02, 0.03, 0.34), Color(0.72, 0.74, 0.78), Vector3(0, 0, 0.2))
			_box(root, Vector3(0.05, 0.06, 0.12), Color(0.5, 0.28, 0.14), Vector3(0, 0.03, 0.42))
		"jack":
			_box(root, Vector3(0.34, 0.16, 0.34), Color(0.4, 0.4, 0.45), Vector3(0, -0.05, 0.16))
			_cyl(root, 0.05, 0.5, Color(0.9, 0.55, 0.1), Vector3(0, 0.2, 0.3), Vector3(70, 0, 0))
		_:
			_box(root, Vector3(0.1, 0.1, 0.3), Color(0.6, 0.62, 0.68), Vector3(0, 0, 0.18))

# ------------------------------------------------------------
#  Input
# ------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		abort()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# take it back off the fastener without finishing it
		if event.pressed and _tool_on >= 0:
			get_viewport().set_input_as_handled()
			_unseat_tool()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_last_mouse = get_viewport().get_mouse_position()
			_stroke_dir = 0
			_press(_pick())
		elif _tool_drag:
			_drop_tool()
		elif _grabbed >= 0 and _grabbed < _props.size():
			_on_release(_props[_grabbed])
			_grabbed = -1
	elif event is InputEventMouseMotion:
		if _tool_drag:
			get_viewport().set_input_as_handled()
			_carry_tool(event.position)
		elif _grabbed >= 0 and _grabbed < _props.size():
			get_viewport().set_input_as_handled()
			_drag(_props[_grabbed], event.relative)

## What a click lands on. With a tool in the stage nothing is worked by hand:
## either you have hold of the tool, or you are being told to go and get it.
func _press(hit: int) -> void:
	_grabbed = -1
	if hit == TOOL_META:
		# on a fastener already? then this grab is the turn, not a carry
		if _tool_on >= 0 and _tool_on < _props.size() and not _props[_tool_on].done:
			_grabbed = _tool_on
			_on_grab(_props[_grabbed])
		else:
			_tool_drag = true
			_tool_touched = true
			if is_instance_valid(_tool_ring):
				_tool_ring.visible = false
			# out to the job in one go rather than creeping there while you aim
			_carry_tool(get_viewport().get_mouse_position())
		return
	if hit < 0:
		return
	if _tool != null and _tool_on != hit:
		_hint_label.text = "Not with your hands. Bring the %s over to it." % GameData.hold_name(_tool_id)
		_hint_label.add_theme_color_override("font_color", Color(1, 0.75, 0.35))
		return
	_grabbed = hit
	_on_grab(_props[_grabbed])

func _on_grab(p: Dictionary) -> void:
	if p.type != "WIRE" or p.phase != 0:
		return
	if p.decoy:
		_grabbed = -1
		_penalise(0.0, "ZAP. Wrong wire. That is the %s one." % String(p.pd.get("name", "wrong")))
		return
	p.phase = 1
	p.mesh.position = Vector3(0, -0.1, 0.12)   # pulled clear of the loom
	_hint_label.text = "Now scrape it: drag across the wire, back and forth."

func _on_release(p: Dictionary) -> void:
	if p.done:
		return
	match p.type:
		"PLUG", "PULL":
			p.progress = 0.0
			p.mesh.position = Vector3.ZERO
		"PUMP":
			p.phase = 0
		"SCAN":
			p.progress = 0.0
		"JOIN":
			p.progress = 0.0
			p.mesh.position = Vector3.ZERO

func _drag(p: Dictionary, rel: Vector2) -> void:
	if p.done or p.lock > 0.0:
		return
	var mp := get_viewport().get_mouse_position()
	match p.type:
		"BOLT", "CLAMP":
			_drag_turn(p, mp)
		"PLUG":
			_drag_plug(p, rel)
		"PULL":
			_drag_pull(p, rel)
		"CUT":
			_drag_cut(p, rel)
		"PUMP":
			_drag_pump(p, rel)
		"JIMMY":
			_drag_jimmy(p, rel)
		"WIRE":
			_drag_wire(p, rel)
		"JOIN":
			_drag_join(p, rel)
		"SCAN":
			_drag_scan(p, rel)
	_last_mouse = mp

# --- turning a fastener: crank the mouse around it ---
func _drag_turn(p: Dictionary, mp: Vector2) -> void:
	var centre := _cam.unproject_position(p.node.global_position)
	var a := _last_mouse - centre
	var b := mp - centre
	if a.length() < 26.0 or b.length() < 26.0:
		return
	var d := a.angle_to(b)
	if absf(d) > 0.9:
		_penalise(0.04, "Steady on. You nearly rounded the head off.")
		return
	# screen y points down, so a visually anticlockwise turn reads as negative
	p.spin += -d
	if p.spin < -0.9:
		_hint_label.text = "Other way. Anticlockwise loosens."
		p.spin = maxf(p.spin, -1.2)
	p.progress = clampf(p.spin / (GameState.bolt_turns() * TAU), 0.0, 1.0)
	p.mesh.basis = Basis(p.dir, p.spin) * p.base
	p.mesh.position = p.dir * (p.progress * 0.14)
	_spin_tool(p.spin)
	if p.progress >= 1.0:
		_finish_prop(p, 0.35)

# --- holding a key reader on the lock: still hands, or it starts over ---
func _drag_scan(p: Dictionary, rel: Vector2) -> void:
	if rel.length() > SCAN_WOBBLE:
		p.progress = 0.0
		_penalise(0.0, "Handshake dropped. Hold it still against the lock.")

# --- easing a connector out ---
func _drag_plug(p: Dictionary, rel: Vector2) -> void:
	var speed := rel.length() / maxf(get_process_delta_time(), 0.001)
	if speed > 1500.0:
		p.progress = 0.0
		p.mesh.position = Vector3.ZERO
		_penalise(0.11, "SNAP. You yanked it. That clip is gone.")
		return
	p.progress = clampf(p.progress + rel.dot(_screen_dir(p)) / 190.0, 0.0, 1.0)
	p.mesh.position = p.dir * (p.progress * 0.24)
	if p.progress >= 1.0:
		_finish_prop(p, 0.3)

# --- dragging a freed part off the car ---
func _drag_pull(p: Dictionary, rel: Vector2) -> void:
	var need := 420.0 if bool(p.st.get("heavy", false)) else 260.0
	var slow := String(p.st.get("slow_without", ""))
	if slow != "" and not GameState.has_shop_tool(slow):
		need *= 1.9
	p.progress = clampf(p.progress + rel.dot(_screen_dir(p)) / need, 0.0, 1.0)
	# some pulls are not a part coming off in your hands, they are the car's
	# own door opening under them -- so haul on the hinge itself rather than
	# dragging a stand-in about in front of it
	var swings := String(p.st.get("swing", ""))
	if swings != "" and is_instance_valid(_vehicle):
		_vehicle.set_door_angle(swings, p.progress)
	else:
		p.mesh.position = p.dir * (p.progress * 0.75)
	if p.progress >= 1.0:
		_finish_prop(p, 0.0 if swings != "" else 0.9)

# --- sawing: back, forth, back, forth ---
func _drag_cut(p: Dictionary, rel: Vector2) -> void:
	var along := rel.dot(_screen_tangent(p))
	if absf(along) < 6.0:
		return
	var dir := 1 if along > 0.0 else -1
	if dir == _stroke_dir:
		return
	_stroke_dir = dir
	var slow := String(p.st.get("slow_without", ""))
	var gain := 0.075 if (slow == "" or GameState.has_shop_tool(slow)) else 0.038
	p.progress = clampf(p.progress + gain, 0.0, 1.0)
	p.heat = minf(1.2, p.heat + 0.1)
	if p.mesh.get_child_count() > 1:
		(p.mesh.get_child(1) as Node3D).position = Vector3(lerpf(-0.22, 0.22, p.progress), 0, 0)
	if p.heat >= 1.0:
		p.heat = 0.4
		p.lock = 0.6
		_penalise(0.07, "Blade bound up in the cut. Let it cool.")
	if p.progress >= 1.0:
		_finish_prop(p, 0.25)

# --- pumping the jack ---
func _drag_pump(p: Dictionary, rel: Vector2) -> void:
	if rel.y > 4.0 and p.phase == 0:
		p.phase = 1
		p.mesh.rotation.x = 0.5
	elif rel.y < -4.0 and p.phase == 1:
		p.phase = 0
		p.mesh.rotation.x = 0.0
		var slow := String(p.st.get("slow_without", ""))
		var gain := 0.2 if (slow == "" or GameState.has_shop_tool(slow)) else 0.11
		p.progress = clampf(p.progress + gain, 0.0, 1.0)
		if p.progress >= 1.0:
			_finish_prop(p, 0.2)

# --- the jimmy: swing the handle, lift when the tip is on a spot ---
func _drag_jimmy(p: Dictionary, rel: Vector2) -> void:
	# screen direction of "along the door" -- the only way the tool can move
	var door_axis := _project_dir(p.node.global_position,
		_vehicle.global_transform.basis * (p.base * Vector3(1, 0, 0)))
	var up_axis := _project_dir(p.node.global_position,
		_vehicle.global_transform.basis * (p.base * Vector3(0, 1, 0)))

	# Step one: it is stood on the seal and has to go down inside the door
	# before any of the rest of it means anything. Only once it is in do the
	# rod and the catches on it become something you can feel for.
	if int(p.phase) == 0:
		p.sink = clampf(p.sink - rel.dot(up_axis) * 0.0042, 0.0, 1.0)
		if _jimmy_rod:
			_jimmy_rod.position.y = PIVOT + DROP * (1.0 - float(p.sink))
		if p.sink < 1.0:
			_hint_label.text = "Working it past the seal... %d%%" % int(float(p.sink) * 100.0)
			return
		p.phase = 1
		if _jimmy_line:
			_jimmy_line.visible = true
		for m in _jimmy_marks:
			(m as Node3D).visible = true
		_hint_label.text = "It is in. Now slide it along and feel for the rod."
		return

	# Drag the handle along the door; it pivots on the seal so the tip below
	# swings the other way. `angle` holds where the tip is, in metres along the
	# rod -- the tool slides in and out of the seal as it angles, the way a real
	# one does, which keeps the tip on the lock rod instead of arcing off it.
	p.angle = clampf(p.angle - rel.dot(door_axis) * 0.0028, -REACH, REACH)
	var tip_x: float = p.angle
	var reach := sqrt(PIVOT * PIVOT + tip_x * tip_x)
	if _jimmy_rod:
		_jimmy_rod.rotation.z = atan2(tip_x, PIVOT)
		_jimmy_rod.scale = Vector3(1, reach / PIVOT, 1)

	# light the tip up when it is on an uncaught spot, so you know when to lift
	var on_spot := false
	var tol_now: float = GameState.jimmy_tolerance(_vehicle.data)
	for i in _jimmy_spots.size():
		if not p.caught.has(i) and absf(tip_x - float(_jimmy_spots[i])) < tol_now:
			on_spot = true
			break
	if _jimmy_tip:
		var tm: StandardMaterial3D = _jimmy_tip.material_override
		tm.albedo_color = Color(0.35, 1.0, 0.45) if on_spot else Color(0.75, 0.78, 0.8)
		tm.emission = tm.albedo_color
		tm.emission_energy_multiplier = 1.6 if on_spot else 0.5

	# a deliberate lift on the handle is the attempt to hook the rod
	p.lift = maxf(0.0, p.lift - rel.dot(up_axis) * 0.012)
	if p.lift < 1.0:
		return
	p.lift = 0.0

	var tol: float = GameState.jimmy_tolerance(_vehicle.data)
	for i in _jimmy_spots.size():
		if p.caught.has(i):
			continue
		if absf(tip_x - float(_jimmy_spots[i])) < tol:
			p.caught.append(i)
			var mark := _jimmy_marks[i] as MeshInstance3D
			mark.material_override.albedo_color = Color(0.3, 1.0, 0.4)
			mark.material_override.emission = Color(0.3, 1.0, 0.4)
			_hint_label.text = "Got one. %d of %d." % [p.caught.size(), _jimmy_spots.size()]
			p.progress = float(p.caught.size()) / float(_jimmy_spots.size())
			if p.caught.size() >= _jimmy_spots.size():
				_finish_prop(p, 0.2)
			return

	# missed: the tool clatters about inside the door and somebody hears it
	p.noise += 0.34
	_penalise(0.0, "Clatter. Nothing there. (%d%% noise)" % int(p.noise * 100.0))
	if p.noise >= 1.0:
		_hint_label.text = "Too much noise."
		abort()

# --- wires: grab the right one, then scrape it back ---
func _drag_wire(p: Dictionary, rel: Vector2) -> void:
	if p.phase == 0:
		return
	# scrape side to side on screen -- no projection to get confused by
	if absf(rel.x) < 4.0:
		return
	var d := 1 if rel.x > 0.0 else -1
	if d == _stroke_dir:
		return
	_stroke_dir = d
	p.progress = clampf(p.progress + 0.12, 0.0, 1.0)
	# the insulation visibly slides down off the copper
	var sleeve := p.mesh.get_child(1) as MeshInstance3D
	if sleeve:
		_strip_sleeve(sleeve, p.progress)
	_hint_label.text = "Scraping... %d%%" % int(p.progress * 100.0)
	if p.progress >= 1.0:
		_hint_label.text = "%s wire is bare. Next." % String(p.pd.get("name", "That")).capitalize()
		p.done = true
		p.area.set_meta("prop", -1)
		_grabbed = -1
		for other in _props:
			if not other.done and not other.decoy:
				_refresh_strip()
				return
		await get_tree().create_timer(0.35).timeout
		if active:
			_next_stage()

# --- joining: drag one end onto the other ---
func _drag_join(p: Dictionary, rel: Vector2) -> void:
	# `mesh.position` lives in the car's own frame, so the offset to the other
	# wire has to be worked out there too. Doing this in world space meant the
	# wire slid off in some unrelated direction on any car that was not sitting
	# square to the world -- which is most of them.
	var offset := _join_offset(p)
	var span := offset.length()
	if span < 0.01:
		return
	var to_screen := _project_dir(p.node.global_position, _vehicle.global_transform.basis * offset)
	p.progress = clampf(p.progress + rel.dot(to_screen) / 210.0, 0.0, 1.0)
	_join_place(p)
	if p.progress >= 1.0:
		_make_joint(p)

## Slide the wire toward the one it is joining, stopping a wire width short so
## the two bared ends sit side by side with room for the twist between them.
func _join_place(p: Dictionary) -> void:
	var offset := _join_offset(p)
	var span := offset.length()
	if span < 0.01:
		return
	p.mesh.position = offset.normalized() * (p.progress * maxf(span - PAIR_GAP, 0.0))

## Where the wire we are joining to sits, relative to this one, in car space.
func _join_offset(p: Dictionary) -> Vector3:
	# the wire we are reaching for was placed through the same map this one was
	var target: Vector3 = _vehicle.rig_prop(p.pd.get("target", Vector3.ZERO),
		String((p.st as Dictionary).get("rig", _part_id)))
	return target - p.node.position

## Snap the ends together, wrap the joint, and react to it.
func _make_joint(p: Dictionary) -> void:
	p.done = true
	p.area.set_meta("prop", -1)
	_grabbed = -1
	# the band is parented to the mesh, which carries its own rotation
	var toward: Vector3 = p.base.inverse() * _join_offset(p).normalized()
	var band := _joint_band(p.mesh, toward * (PAIR_GAP * 0.5) + Vector3(0, 0.12, 0))
	if bool(p.pd.get("spark", false)):
		_hint_label.text = "It turns over, catches, and settles into a rattle."
		band.material_override.albedo_color = Color(1, 1, 0.8)
		band.material_override.emission = Color(1, 1, 0.8)
		band.material_override.emission_energy_multiplier = 3.0
		# you flash a starter across the pair, you do not leave it wired on
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func(): _hint_label.text = "Running. Take the starter back off.")
		tw.tween_property(p.mesh, "position", p.mesh.position * 0.3, 0.35)
	else:
		_hint_label.text = "Twisted on. The dash lights come up."
	await get_tree().create_timer(0.9).timeout
	if active:
		_next_stage()

func _finish_prop(p: Dictionary, fly: float) -> void:
	p.done = true
	p.progress = 1.0
	p.area.set_meta("prop", -1)
	_grabbed = -1
	# whatever was on it comes off with it -- and stays right there, waiting to
	# be carried to the next one rather than snapping back to your hip
	if p.ghost != null and is_instance_valid(p.ghost):
		(p.ghost as Node3D).queue_free()
		p.ghost = null
	if _tool_on >= 0 and _tool_on < _props.size() and _props[_tool_on].done:
		_tool_on = -1
		if is_instance_valid(_tool):
			_tool.visible = true
		_tool_glow(true)
	_show_spots()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p.mesh, "position", p.dir * fly + Vector3(0, -0.4, 0), 0.4)
	tw.tween_property(p.mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	for other in _props:
		if not other.done and not other.decoy:
			_refresh_strip()
			return
	await get_tree().create_timer(0.45).timeout
	if active:
		_next_stage()

## Every MeshInstance3D under a node. A generated prop is a flat list of them;
## a real part cut off an imported model is a holder with meshes inside it, and
## casting the holder straight to MeshInstance3D is how this used to crash.
func _meshes_under(root: Node) -> Array:
	var out := []
	for c in root.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes_under(c))
	return out

## Screen-space direction the part comes off in.
func _screen_dir(p: Dictionary) -> Vector2:
	return _project_dir(p.node.global_position, _vehicle.global_transform.basis * p.dir)

## Screen-space direction along the cut.
func _screen_tangent(p: Dictionary) -> Vector2:
	return _project_dir(p.node.global_position, _vehicle.global_transform.basis * (p.base.x))

func _project_dir(world_pos: Vector3, world_dir: Vector3) -> Vector2:
	var a := _cam.unproject_position(world_pos)
	var b := _cam.unproject_position(world_pos + world_dir.normalized() * 0.5)
	var d := b - a
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT

## Headless smoke-test hook: complete the current job without a mouse.
func debug_finish_all() -> void:
	while active and _stage < _stages.size():
		for p in _props:
			p.done = true
			p.progress = 1.0
		_next_stage()
