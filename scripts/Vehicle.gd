extends CharacterBody3D
class_name Vehicle
# ============================================================
#  A stealable / drivable / dismantle-able car.
#
#  The body is built from named pieces so that removing a part
#  actually takes it off the car: pull the hood and the engine
#  bay is open underneath, pull the doors and you can see the
#  seats, pull the wheels and it sits on its stands.
# ============================================================

const GRAVITY := 26.0
# Speed fraction at which each gear runs out, and how hard each one pulls.
const GEAR_TOPS := [0.0, 0.16, 0.34, 0.55, 0.78, 1.0]
const GEAR_PULL := [1.8, 1.35, 1.05, 0.85, 0.7]
const SHIFT_TIME := 0.18
const TURN_RATE := 2.4
const STEER_RATE := 4.5
## Near enough the radius of a wheel on any of these. Used to work out how
## fast one should be turning for the speed the car is doing, so they roll
## rather than skid along the road.
const WHEEL_RADIUS := 0.44
## How far the front wheels turn at full lock.
const MAX_LOCK := 0.52

var data: Dictionary = {}
var condition: float = 1.0
var locked: bool = true
var is_job: bool = false          # sitting in a garage bay, ready to strip
var stripped: bool = false
var driver: Node = null
var parts_remaining: Array[String] = []
var failed_attempts: int = 0
var lifted: bool = false
var hotwired: bool = false

var speed: float = 0.0
var gear: int = 0
## Knock from a smash: bleeds off over about a second, and shunts a parked car
## about even though nobody is driving it.
var shove := Vector3.ZERO
var spin: float = 0.0
var _crash_lull := 0.0
var _shift: float = 0.0
var _steer: float = 0.0
var _label: Label3D
var _wheels: Array[Node3D] = []
## Each wheel hangs off a pair of pivots built square to the car: the outer one
## turns with the steering, the inner one rolls. Doing it this way means the
## model's own idea of which way its wheel axes point never comes into it.
var _wheel_spin: Array[Node3D] = []
var _wheel_steer: Array[Node3D] = []
var _jack_stands: Array[Node3D] = []
## Worked out once from the model and kept -- it never moves.
## The colour it was built in, so a respray knows what it is replacing.
var _paint_base := Color(0.6, 0.6, 0.6)
var _seat_post := Vector3.ZERO
var _seat_looked := false
var _door_pivots := {}            # part_id -> the hinge these swing on
var _door_tweens := {}            # and whatever is currently swinging it
var _part_meshes := {}            # part_id -> Array[Node3D], hidden when pulled
var _guts: Node3D                 # holds the generated interior and underbody
var _split_pieces := {}           # part_id -> Array[MeshInstance3D] cut out of welded model meshes
var half_length := 2.2            # nose to centre, so bigger cars yield sooner
var half_width := 1.0             # centre to flank
## Whoever is sat behind the wheel of it. Ambient traffic has one; it is the
## person who ends up in the road when somebody takes the car off them.
var occupant: Node3D = null
var occupant_seed := 0
var passenger: Node3D = null

# ------------------------------------------------------------
#  Suspension
# ------------------------------------------------------------
## Everything that is bodywork hangs off this, and this hangs off the springs.
## The wheels, the collision box and the label stay on the car itself, so the
## wheels keep to the road while the body moves about above them.
var _sprung: Node3D = null
## One entry per wheel: {pid, pivot, base, g}. `base` is where its pivot sits
## on flat ground; `g` is how far the ground under it is above or below that.
var _corners: Array = []
var _heave := 0.0
var _heave_v := 0.0
var _pitch := 0.0
var _pitch_v := 0.0
var _roll := 0.0
var _roll_v := 0.0
var _last_speed := 0.0
var _last_yaw := 0.0
## Seconds left before a car nobody is driving stops working its springs out.
## A parked car that is not being touched costs nothing.
var _susp_awake := 1.0
var _sparks: CPUParticles3D = null
## Stiffness and damping of the body on its springs, per second squared and per
## second. About a hertz and a half and a third of critical: it dips, comes back
## up a touch past level, and settles, the way a tired saloon does.
const SPRING := 90.0
const DAMP := 7.0
## Nose-down per m/s^2 of braking, and lean per m/s^2 of cornering.
const DIVE := 0.0065
const LEAN := 0.0042
const MAX_TILT := 0.2
## Ground rays: from this far above the wheel to this far below it.
const RAY_UP := 0.9
const RAY_DOWN := 0.7
## What dragging a bare hub along the tarmac costs, per missing wheel, in m/s^2.
const SCRAPE_DRAG := 3.2
## How much of the car's top speed, and of its pull, is left with 0..4 wheels gone.
const LIMP_TOP := [1.0, 0.42, 0.12, 0.05, 0.0]
const LIMP_PULL := [1.0, 0.55, 0.25, 0.12, 0.0]
const WHEEL_IDS := ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]

# ------------------------------------------------------------
#  Dents
# ------------------------------------------------------------
## MeshInstance3D -> {mesh, prims, arrays, rest}. A mesh is only copied the first
## time it gets hit: every car of a make shares one until then.
var _dents := {}
## Deepest any bit of metal is ever pushed in from where it started, in metres.
const DENT_MAX := 0.3

func setup(vehicle_data: Dictionary) -> void:
	data = vehicle_data
	condition = randf_range(0.55, 0.98)
	parts_remaining.assign(data.parts)
	# off the line in whatever colour it left the factory. A marked car keeps
	# the paint it is supposed to have.
	if not bool(data.get("fixed_paint", false)):
		data["color"] = GameData.random_paint()
	_paint_base = data.get("color", Color(0.6, 0.6, 0.6))

func _ready() -> void:
	add_to_group("vehicle")
	add_to_group("interactable")
	add_to_group("shootable")
	_build()
	_rig_wheels()
	_mount_sprung()
	refresh_part_meshes()
	if data.has("model") and not bool(data.get("fixed_paint", false)):
		repaint(data.get("color", Color(0.6, 0.6, 0.6)))

# ------------------------------------------------------------
#  Construction
# ------------------------------------------------------------
func _build() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.get("body_size", Vector3(2.0, 1.3, 4.4)) as Vector3
	col.shape = box
	col.position.y = float(data.get("body_y", 0.65))
	half_length = box.size.z * 0.5
	half_width = box.size.x * 0.5
	add_child(col)

	if data.has("model"):
		_build_model_shell()
		# a bought model brings its own seats, dash and engine bay -- generating
		# boxes for those just puts a second interior inside the first one
		if bool(data.get("generate_internals", false)):
			_build_internals()
	else:
		_build_box_shell()
		_build_internals()

	_label = Label3D.new()
	_label.text = "%s\nT%d" % [data.get("name", "Car"), int(data.get("tier", 1))]
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 14
	_label.position = Vector3(0, 2.3, 0)
	add_child(_label)

## An imported car. The model is turned and scaled to sit in the same footprint
## the box cars use, so every teardown position stays roughly where it was, and
## its named meshes are mapped onto the part ids the teardown works in.
func _build_model_shell() -> void:
	var packed: PackedScene = load(String(data.model))
	if packed == null:
		push_warning("car model missing, falling back to boxes: %s" % data.model)
		_build_box_shell()
		return
	var shell := packed.instantiate()
	shell.name = "Shell"
	shell.scale = Vector3.ONE * float(data.get("model_scale", 1.0))
	shell.rotation.y = float(data.get("model_yaw", 0.0))
	shell.position = data.get("model_offset", Vector3.ZERO)
	add_child(shell)

	# cut welded meshes apart before mapping, so doors and the engine can be
	# mapped onto pieces that did not exist in the file
	for spec in data.get("model_split", []):
		_split_mesh(shell, spec)

	var mapping: Dictionary = data.get("model_map", {})
	var hide: Array = data.get("model_hide", [])
	for part_id in _split_pieces.keys():
		for piece in _split_pieces[part_id]:
			_register(String(part_id), piece)
			if String(part_id).begins_with("wheel"):
				_wheels.append(piece)

	for node in _descendants(shell):
		var nm := String(node.name)
		if hide.has(nm):
			node.visible = false
			continue
		for part_id in mapping.keys():
			if (mapping[part_id] as Array).has(nm):
				_register(String(part_id), node)
				if String(part_id).begins_with("wheel"):
					_wheels.append(node)

	_hang_doors()

## Put the cut-out doors on a hinge at their front edge, so they swing like the
## box cars' do: open to sit in it, open to get at the hinge bolts in the shop.
## Skin, trim card, frame and glass all move onto the hinge together.
func _hang_doors() -> void:
	for part_id in ["door_l", "door_r"]:
		var nodes: Array = _part_meshes.get(part_id, [])
		if nodes.is_empty() or _door_pivots.has(part_id):
			continue
		var box := part_bounds(part_id)
		if box.size == Vector3.ZERO:
			continue
		var hinge := Node3D.new()
		hinge.name = "Hinge_" + part_id
		hinge.position = Vector3(box.get_center().x, box.get_center().y, box.position.z + 0.06)
		add_child(hinge)
		for n in nodes:
			if not is_instance_valid(n):
				continue
			var keep: Transform3D = (n as Node3D).global_transform
			n.get_parent().remove_child(n)
			# readable names: skin, card and frame all arrive here called
			# "door_l", and left to itself Godot renames the second and third
			# to "@MeshInstance3D@22795". Everything that works out what a mesh
			# is from what it is called -- the respray above all -- then misses
			# them, and a resprayed car keeps two thirds of a white door.
			hinge.add_child(n, true)
			(n as Node3D).global_transform = keep
		_door_pivots[part_id] = hinge

## One entry of `model_split`: {"node": mesh name, "regions": {piece: AABB}}.
## Regions are written in metres in the car's own space -- z back to front, x
## across, y up -- and converted into whatever space the imported mesh happens
## to use. One part can be cut out of several meshes: a door is an outer skin
## in the body, an inner card in the interior and a frame in the underbody, and
## it needs all three or you can see straight into it once it is off.
func _split_mesh(shell: Node, spec: Dictionary) -> void:
	var want := String(spec.node)
	for n in _descendants(shell):
		var mi := n as MeshInstance3D
		if mi == null or not String(mi.name).begins_with(want) or mi.mesh == null:
			continue
		var to_mesh := mi.global_transform.affine_inverse() * global_transform
		var local := {}
		for key in spec.regions.keys():
			local[key] = to_mesh * (spec.regions[key] as AABB)
		var made := MeshSplit.apply(mi, local)
		for key in made.keys():
			if not _split_pieces.has(key):
				_split_pieces[String(key)] = []
			_split_pieces[String(key)].append(made[key])
		return
	push_warning("nothing called %s to split" % want)

## A copy of what this part looks like on this car, for the loose part you
## carry about and for the thing you drag off during a teardown. Without it
## every pulled part is a generic box, which looks daft next to a real model.
func make_part_visual(part_id: String) -> Node3D:
	if not data.has("model"):
		return null
	# measured with the door shut, or a door pulled while it is hanging open
	# would come away with that swing baked into it
	var hinge: Node3D = _door_pivots.get(part_id)
	var swung := 0.0
	if hinge != null and is_instance_valid(hinge):
		swung = hinge.rotation.y
		hinge.rotation.y = 0.0
	var out := _build_part_visual(part_id)
	if hinge != null and is_instance_valid(hinge):
		hinge.rotation.y = swung
	return out

func _build_part_visual(part_id: String) -> Node3D:
	var inv := global_transform.affine_inverse()
	var holder := Node3D.new()
	# centred on the geometry, not on the node origins: an imported mesh keeps
	# every piece of the car on one shared origin off in the footwell, so
	# averaging those would hand you a door held two metres to your left
	var centre := part_bounds(part_id).get_center()
	for mi in _part_mesh_instances(part_id):
		var dup := mi.duplicate() as MeshInstance3D
		dup.visible = true
		# its own copy of the material, so highlighting the loose part does not
		# light up the same part still bolted to every other car of this model
		if dup.material_override == null and dup.mesh != null and dup.mesh.get_surface_count() > 0:
			var src := dup.mesh.surface_get_material(0)
			if src != null:
				dup.material_override = src.duplicate()
		var rel: Transform3D = inv * mi.global_transform
		rel.origin -= centre
		dup.transform = rel
		holder.add_child(dup)
	if holder.get_child_count() == 0:
		holder.free()
		return null
	return holder

## The box this part fills on the car, in the car's own space. Zero-sized when
## nothing is mapped onto that id.
func part_bounds(part_id: String) -> AABB:
	# a door hanging open is still the same door: measure it shut
	var hinge: Node3D = _door_pivots.get(part_id)
	var swung := 0.0
	if hinge != null and is_instance_valid(hinge):
		swung = hinge.rotation.y
		hinge.rotation.y = 0.0
	var inv := global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in _part_mesh_instances(part_id):
		var b: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	if hinge != null and is_instance_valid(hinge):
		hinge.rotation.y = swung
	return out

## Where the loose copy of a part ends up being drawn, so the teardown can put
## the drag-it-off prop exactly where the part is rather than where the box
## cars keep theirs. Falls back for anything this car has no real mesh for.
func part_centre(part_id: String, fallback: Vector3) -> Vector3:
	if not data.has("model"):
		return fallback
	var b := part_bounds(part_id)
	return fallback if b.size == Vector3.ZERO else b.get_center()

## Every drawable mesh under a part, including the ones hanging off a wrapper
## node -- an imported hood or window is a plain Node3D with the mesh beneath.
func _part_mesh_instances(part_id: String) -> Array:
	var out := []
	for n in _part_meshes.get(part_id, []):
		if not is_instance_valid(n):
			continue
		for node in [n] + _descendants(n):
			var mi := node as MeshInstance3D
			if mi != null and mi.mesh != null:
				out.append(mi)
	return out

# ------------------------------------------------------------
#  Fitting the teardown onto this body
# ------------------------------------------------------------
## Every teardown prop position is written against the box cars: 4.4m long,
## 2.0m wide, doors on the flanks at x = +-1.0. A bought model is a different
## size and keeps its parts somewhere else, so it carries a `rig` map that
## takes a box-car position onto the same spot on its own body -- otherwise
## the hinge bolts and the jimmy end up buried inside the door.
func rig_prop(p: Vector3, key: String) -> Vector3:
	var rig: Dictionary = data.get("rig", {})
	return _rig_apply(p, rig.get(key, rig.get(PartMesh.kind(key), rig.get("car", {}))))

## The camera watches from outside the whole car, so it always uses the
## car-sized map -- run through a part-sized one it would end up in the panel.
func rig_cam(p: Vector3) -> Vector3:
	return _rig_apply(p, (data.get("rig", {}) as Dictionary).get("car", {}))

func _rig_apply(p: Vector3, m: Dictionary) -> Vector3:
	if m.is_empty():
		return p
	var s: Vector3 = m.get("scale", Vector3.ONE)
	var o: Vector3 = m.get("offset", Vector3.ZERO)
	# x is mirrored about the centre line so one entry serves both flanks
	return Vector3(signf(p.x) * (absf(p.x) * s.x + o.x), p.y * s.y + o.y, p.z * s.z + o.z)

func _descendants(root: Node) -> Array:
	var out := []
	for c in root.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out

func _build_box_shell() -> void:
	var base: Color = data.get("color", Color(0.6, 0.6, 0.6))
	var dark := base.darkened(0.3)
	# see-through, or there is no point sitting anybody behind it
	var glass := Color(0.3, 0.45, 0.55, 0.45)

	# rear two thirds: floor pan, boot, cabin base
	_add_box(Vector3(2.0, 0.7, 3.35), Vector3(0, 0.7, 0.525), base)
	# front third is a recess -- the engine bay, with the hood as its lid
	_add_box(Vector3(2.0, 0.4, 1.05), Vector3(0, 0.55, -1.675), base)
	_add_box(Vector3(0.12, 0.42, 1.05), Vector3(-0.94, 0.94, -1.675), base)
	_add_box(Vector3(0.12, 0.42, 1.05), Vector3(0.94, 0.94, -1.675), base)
	_add_box(Vector3(2.0, 0.42, 0.12), Vector3(0, 0.94, -2.14), base)

	# greenhouse: roof on pillars, so the interior is actually visible
	_add_box(Vector3(1.7, 0.1, 2.0), Vector3(0, 1.63, -0.15), dark)
	for sx in [-0.79, 0.79]:
		for sz in [-1.08, 0.78]:
			_add_box(Vector3(0.12, 0.56, 0.12), Vector3(sx, 1.32, sz), dark)
	_add_box(Vector3(1.5, 0.5, 0.08), Vector3(0, 1.33, -1.13), glass)
	_add_box(Vector3(1.5, 0.5, 0.08), Vector3(0, 1.33, 0.84), glass)

	# removable panels
	_register("hood", _add_box(Vector3(1.96, 0.07, 1.03), Vector3(0, 1.02, -1.675), base.lightened(0.05)))
	_register("trunk", _add_box(Vector3(1.96, 0.07, 1.26), Vector3(0, 1.08, 1.5), base.lightened(0.05)))
	for sx in [-1.0, 1.0]:
		var did := "door_r" if sx > 0.0 else "door_l"
		# hung on a hinge at the front edge so they can actually open
		var hinge := Node3D.new()
		hinge.position = Vector3(sx, 0.98, -1.1)
		add_child(hinge)
		_door_pivots[did] = hinge
		_register(did, hinge)
		_panel(hinge, Vector3(0.08, 0.95, 1.7), Vector3(0, 0, 0.85), base.darkened(0.08))
		_panel(hinge, Vector3(0.06, 0.42, 1.5), Vector3(sx * 0.01, 0.35, 0.9), glass)

	# lights
	_add_box(Vector3(0.35, 0.2, 0.12), Vector3(0.65, 0.6, -2.24), Color(1, 0.95, 0.75))
	_add_box(Vector3(0.35, 0.2, 0.12), Vector3(-0.65, 0.6, -2.24), Color(1, 0.95, 0.75))
	_add_box(Vector3(0.35, 0.2, 0.12), Vector3(0.65, 0.85, 2.24), Color(0.8, 0.1, 0.1))
	_add_box(Vector3(0.35, 0.2, 0.12), Vector3(-0.65, 0.85, 2.24), Color(0.8, 0.1, 0.1))
	if int(data.get("tier", 1)) >= 3:
		_add_box(Vector3(2.1, 0.12, 0.4), Vector3(0, 1.4, 2.0), dark)

	for x in [-1.0, 1.0]:
		for z in [-1.45, 1.45]:
			var w := _add_wheel(Vector3(x, 0.42, z))
			_wheels.append(w)
			_register(("wheel_f" if z < 0.0 else "wheel_r") + ("r" if x > 0.0 else "l"), w)

## Everything you only ever see close up during a teardown: the engine bay, the
## seats, the dash, and what is slung under the floor. Generated either way --
## no bought car model has a removable catalytic converter in it.
func _build_internals() -> void:
	var base: Color = data.get("color", Color(0.6, 0.6, 0.6))
	var dark := base.darkened(0.3)
	# An imported car is a different shape from the box cars these positions
	# were written for, so it can squash them to fit inside its own cabin.
	_guts = Node3D.new()
	_guts.scale = data.get("internals_scale", Vector3.ONE)
	_guts.position = data.get("internals_offset", Vector3.ZERO)
	add_child(_guts)

	var block := _gut_box(Vector3(0.8, 0.4, 0.82), Vector3(0.02, 0.78, -1.7), Color(0.3, 0.3, 0.33))
	_register("engine", block)
	_register("engine", _gut_box(Vector3(0.55, 0.16, 0.6), Vector3(0.02, 1.0, -1.68), Color(0.38, 0.38, 0.4)))
	_register("battery", _gut_box(Vector3(0.3, 0.26, 0.22), Vector3(-0.66, 0.83, -1.36), Color(0.12, 0.12, 0.14)))

	for sx in [-0.42, 0.42]:
		var sid := "seat_r" if sx > 0.0 else "seat_l"
		_register(sid, _gut_box(Vector3(0.5, 0.14, 0.5), Vector3(sx, 1.12, 0.0), dark.darkened(0.2)))
		_register(sid, _gut_box(Vector3(0.5, 0.55, 0.14), Vector3(sx, 1.42, 0.28), dark.darkened(0.2)))
	_gut_box(Vector3(1.6, 0.22, 0.35), Vector3(0, 1.16, -0.95), dark.darkened(0.3))
	_register("electronics", _gut_box(Vector3(0.3, 0.12, 0.24), Vector3(0.45, 1.22, -0.98), Color(0.2, 0.25, 0.3)))

	_register("catalytic", _gut_box(Vector3(0.26, 0.18, 0.42), Vector3(0.25, 0.26, 0.3), Color(0.55, 0.5, 0.45)))
	_register("catalytic", _gut_box(Vector3(0.12, 0.12, 1.6), Vector3(0.25, 0.26, 1.1), Color(0.4, 0.38, 0.36)))
	_register("transmission", _gut_box(Vector3(0.5, 0.42, 0.5), Vector3(0.05, 0.32, -0.7), Color(0.35, 0.35, 0.38)))

## A mesh parented to something other than the car body (a door hinge).
func _panel(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _surface(color)
	parent.add_child(mi)
	return mi

## Swing a door open on its hinge. Lets you see the dash to hotwire it.
func open_door(part_id: String = "door_r") -> void:
	var hinge: Node3D = _door_pivots.get(part_id)
	if hinge == null or not is_instance_valid(hinge):
		return
	# the panel hangs behind the hinge, so a positive turn on the right side
	# swings the trailing edge away from the car -- outwards, like a door
	var swing := 1.05 if part_id == "door_r" else -1.05
	Sfx.play(sound_set() + "_door_open", global_position)
	_swing(part_id, hinge, swing, 0.5, Tween.TRANS_BACK)

## Hold a door at some fraction of open, under whoever is hauling on it. No
## tween: this is dragged by hand, a frame at a time, so anything animating it
## has to get out of the way first.
func set_door_angle(part_id: String, t: float) -> void:
	var hinge: Node3D = _door_pivots.get(part_id)
	if hinge == null or not is_instance_valid(hinge):
		return
	var running: Tween = _door_tweens.get(part_id)
	if running and running.is_valid():
		running.kill()
	var swing := 1.05 if part_id == "door_r" else -1.05
	hinge.rotation.y = swing * clampf(t, 0.0, 1.0)

## Where a light bar sits on this particular roof. The box cars and the imported
## ones are different heights, and a bar pinned at one fixed height ends up
## either floating over the box cars or sunk into a model's roof.
func roof_light_point() -> Vector3:
	var size: Vector3 = data.get("body_size", Vector3(2.0, 1.9, 4.4))
	return Vector3(0.35, size.y * 0.95, 0.45 if data.has("model") else -0.2)

## Does this car have a door that can actually swing? A bought model whose
## doors are welded into the body shell does not.
func has_door(part_id: String = "door_r") -> bool:
	return _door_pivots.has(part_id)

## Is that door hanging open?
func door_open(part_id: String = "door_r") -> bool:
	var hinge: Node3D = _door_pivots.get(part_id)
	return hinge != null and is_instance_valid(hinge) and absf(hinge.rotation.y) > 0.15

## Pull it shut behind you.
func close_door(part_id: String = "door_r") -> void:
	var hinge: Node3D = _door_pivots.get(part_id)
	if hinge == null or not is_instance_valid(hinge):
		return
	Sfx.play(sound_set() + "_door_close", global_position)
	_swing(part_id, hinge, 0.0, 0.4, Tween.TRANS_QUAD)

## One tween per door at a time. Hotwiring a car seconds after opening it used
## to leave the open and shut tweens fighting over the same hinge.
func _swing(part_id: String, hinge: Node3D, to: float, secs: float, trans: int) -> void:
	var running: Tween = _door_tweens.get(part_id)
	if running and running.is_valid():
		running.kill()
	var tw := create_tween()
	tw.tween_property(hinge, "rotation:y", to, secs).set_trans(trans)
	_door_tweens[part_id] = tw

## A generated interior piece, parented to the squashable wrapper.
func _gut_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _surface(color)
	_guts.add_child(mi)
	return mi

func _register(part_id: String, node: Node3D) -> void:
	if not _part_meshes.has(part_id):
		_part_meshes[part_id] = []
	_part_meshes[part_id].append(node)

func _add_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	# anything big enough to be a panel gets some vertices across it, or a dent
	# in the middle of a door can only move its four corners
	if size.x > 0.9 or size.z > 0.9:
		mesh.subdivide_width = clampi(int(size.x / 0.35), 1, 8)
		mesh.subdivide_depth = clampi(int(size.z / 0.35), 1, 10)
		mesh.subdivide_height = clampi(int(size.y / 0.35), 1, 4)
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _surface(color)
	_body_root().add_child(mi)
	return mi

## Where bodywork goes: on the springs once they exist, on the car until then.
func _body_root() -> Node3D:
	return _sprung if _sprung != null and is_instance_valid(_sprung) else self

## Paint. Anything with an alpha on it is glass, and gets treated like it.
func _surface(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _add_wheel(pos: Vector3) -> Node3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.32
	mi.mesh = cyl
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 0, 90)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mi.material_override = mat
	add_child(mi)
	return mi

# ------------------------------------------------------------
#  Who is sitting in it
# ------------------------------------------------------------
## Where somebody sitting in this car has their hips. Across and along the car
## that is wherever the seat is; the height comes off the cabin, because the
## seat meshes are decorative and sit far too high to put a person on.
## Where the hips go. Every one of these models has a steering wheel in it, and
## a driver sits a little behind and below it -- which beats a fraction of the
## vehicle's overall height, because that number includes the roof box on a van
## and the tray on a pickup and puts the driver somewhere over the engine.
const SEAT_BACK := 0.34      # behind the rim
const SEAT_DROP := 0.24      # below it

func seat_point(left: bool = true) -> Vector3:
	var post := _steering_post()
	if post != Vector3.ZERO:
		return Vector3(post.x if left else -post.x, post.y - SEAT_DROP, post.z + SEAT_BACK)
	var box := part_bounds("seat_l" if left else "seat_r")
	var across := -0.42 if left else 0.42
	var along := 0.0
	if box.size != Vector3.ZERO:
		across = box.get_center().x
		along = box.get_center().z
	return Vector3(across, _cabin_height() * 0.42, along)

## The middle of the steering wheel, in this vehicle's own space. Zero when
## there is nothing in the model to go on.
func _steering_post() -> Vector3:
	if _seat_post != Vector3.ZERO or _seat_looked:
		return _seat_post
	_seat_looked = true
	if not data.has("model"):
		return Vector3.ZERO
	var inv := global_transform.affine_inverse()
	for n in _descendants(self):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).to_lower().contains("steering"):
			continue
		var box: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		_seat_post = box.get_center()
		return _seat_post
	return Vector3.ZERO

## Floor to roof. A bought model's collision box is its real height; the box
## cars have a greenhouse we built ourselves that stands well above theirs.
func _cabin_height() -> float:
	if data.has("model"):
		return float((data.get("body_size", Vector3(2.0, 1.3, 4.4)) as Vector3).y)
	return 1.68

## People are built to one size and cars are not. Somebody sitting in a small
## one is scaled to fit under its roof rather than through it.
func occupant_scale() -> float:
	# hips to the top of the head, which is what has to fit between where they
	# are actually sat and the roof -- worked from the same seat point rather
	# than a second guess at it, or the two drift apart
	const TORSO := 1.25
	var headroom := _cabin_height() - seat_point(true).y - 0.06   # less a bit for hair
	return clampf(headroom / TORSO, 0.62, 1.0)

## Put a driver in it. `uniform` dresses them as police, which is what a marked
## car wants -- a cruiser with somebody's dad at the wheel reads as a bug.
func add_occupant(dress_seed: int, uniform: bool = false) -> Node3D:
	if occupant != null and is_instance_valid(occupant):
		return occupant
	occupant_seed = dress_seed
	occupant = _seat_body(dress_seed, uniform, true)
	return occupant

## Somebody in the other front seat. Kept apart from `occupant` because the
## driver is the one a carjacking drags out; this one is just along for it.
func add_passenger(dress_seed: int, uniform: bool = false) -> Node3D:
	if passenger != null and is_instance_valid(passenger):
		return passenger
	passenger = _seat_body(dress_seed, uniform, false)
	return passenger

func set_passenger_visible(on: bool) -> void:
	if passenger != null and is_instance_valid(passenger):
		passenger.visible = on

func _seat_body(dress_seed: int, uniform: bool, left: bool) -> Node3D:
	var who := Node3D.new()
	who.name = "Occupant" if left else "Passenger"
	# the model is built standing with its feet on the floor, so it hangs from
	# where the hips need to be
	var fit := occupant_scale()
	who.position = seat_point(left) - Vector3(0, PersonMesh.HIP * fit, 0)
	who.scale = Vector3.ONE * fit
	who.rotation.y = PI          # everybody is built facing +Z, cars face -Z
	_body_root().add_child(who)
	var rng := RandomNumberGenerator.new()
	rng.seed = dress_seed
	if uniform:
		PersonMesh.build(who, Color(0.13, 0.16, 0.30), Color(0.10, 0.11, 0.16),
			PersonMesh.SKIN[dress_seed % PersonMesh.SKIN.size()],
			PersonMesh.HAIR[dress_seed % PersonMesh.HAIR.size()], PersonMesh.SHOES[0])
	else:
		var kit := PersonMesh.random_civvies(rng)
		PersonMesh.build(who, kit[0], kit[1], kit[2], kit[3], kit[4])
	PersonRig.new(who).sit()
	return who

func has_occupant() -> bool:
	return occupant != null and is_instance_valid(occupant)

## Where whoever is sitting in it has their shoulders, in the car's own space.
## That is what somebody reaching in takes hold of.
func occupant_centre() -> Vector3:
	if not has_occupant():
		return seat_point(true)
	return occupant.position + Vector3(0, PersonMesh.SHOULDER * occupant_scale(), 0)

## A copy of them, hung off their own shoulders so it sits where it is put.
## Used for the thing you actually drag out of the door.
func make_occupant_visual() -> Node3D:
	if not has_occupant():
		return null
	var dup := occupant.duplicate() as Node3D
	dup.position = Vector3(0, -PersonMesh.SHOULDER * occupant_scale(), 0)
	return dup

## Hide the real one while a copy of them is being hauled about.
func set_occupant_visible(on: bool) -> void:
	if has_occupant():
		occupant.visible = on

## Out they get. Returns a real pedestrian, dressed the same, stood in the road
## beside the driver door and about to leave at speed.
func eject_occupant() -> Pedestrian:
	if not has_occupant():
		return null
	occupant.queue_free()
	occupant = null
	var world := get_tree().get_first_node_in_group("world") as World
	if world == null:
		return null
	var out := global_position - global_transform.basis.x * (half_width + 0.9)
	var who := world.spawn_walker(out, false, occupant_seed)
	if who == null:
		return null
	who._scatter(global_position, 9.0)
	return who

# ------------------------------------------------------------
#  Part meshes
# ------------------------------------------------------------
## Show every piece that is still bolted on, hide the ones that are gone.
func refresh_part_meshes() -> void:
	for part_id in _part_meshes.keys():
		set_part_mesh_visible(part_id, parts_remaining.has(part_id))

func set_part_mesh_visible(part_id: String, on: bool) -> void:
	for n in _part_meshes.get(part_id, []):
		if is_instance_valid(n):
			n.visible = on

func has_part_mesh(part_id: String) -> bool:
	return _part_meshes.has(part_id)

func set_label_visible(on: bool) -> void:
	if _label:
		_label.visible = on and (is_job or locked)

# ------------------------------------------------------------
#  Driving
# ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if driver != null:
		return
	# nobody at the wheel, but it still falls, and it still gets shunted when
	# somebody puts one into the side of it
	if shove.length() > 0.05 or spin != 0.0 or not is_on_floor():
		velocity.x = shove.x
		velocity.z = shove.z
		velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
		rotate_y(spin * delta)
		move_and_slide()
		_check_impacts()
		_susp_awake = maxf(_susp_awake, 1.5)
	_settle_shove(delta)
	if _susp_awake > 0.0:
		_susp_awake -= delta
		_suspend(delta)

## Knocks decay quickly -- this is a shunt, not a launch. A car short of a wheel
## has a hub dug into the road, and does not slide nearly as far.
func _settle_shove(delta: float) -> void:
	var dig := 1.0 + float(missing_wheels()) * 1.5
	shove = shove.move_toward(Vector3.ZERO, delta * 18.0 * dig)
	spin = move_toward(spin, 0.0, delta * 3.5 * dig)
	_crash_lull = maxf(0.0, _crash_lull - delta)

## Called every physics frame by whoever is driving (player or police AI).
## throttle: -1 brake/reverse .. +1 flat out (police use >1 for a bit more shove)
## steer:    -1 left .. +1 right
func drive(throttle: float, steer: float, delta: float, handbrake: bool = false) -> void:
	var top: float = float(data.get("top_speed", 16.0))
	var base: float = float(data.get("accel", 9.0))
	# A wheel short and it is a different car: most of the top end and most of
	# the pull gone, a hub grinding on the road the whole time, and the steering
	# going with whichever front corner is not there. Lose a whole axle and it is
	# not going anywhere under its own power -- it drags itself a few inches.
	var gone := missing_wheels()
	var gone_front := _missing_on(true)
	if gone > 0:
		var limp: float = LIMP_TOP[mini(gone, 4)]
		if gone_front >= 2 or _missing_on(false) >= 2:
			limp = minf(limp, 0.05)
		top = maxf(top * limp, 0.8)
		base *= LIMP_PULL[mini(gone, 4)]
		# the gearbox still reads the healthy car's speed range, so the gears it
		# shows are the gears it would be in
		_update_gear(absf(speed) / maxf(float(data.get("top_speed", 16.0)), 0.001), delta)
	else:
		_update_gear(absf(speed) / maxf(top, 0.001), delta)
	# smooth the steering input so keyboard taps are not on/off
	_steer = move_toward(_steer, clampf(steer, -1.0, 1.0), delta * STEER_RATE)

	if handbrake:
		speed = move_toward(speed, 0.0, base * 3.2 * delta)
	elif throttle > 0.05:
		# pull is strongest just after a shift and tapers as the gear runs out,
		# so acceleration is smooth and predictable instead of a flat ramp
		var lo: float = GEAR_TOPS[gear] * top
		var hi: float = GEAR_TOPS[gear + 1] * top
		var rev := clampf((absf(speed) - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
		var torque: float = base * GEAR_PULL[gear] * lerpf(1.0, 0.6, rev) * clampf(throttle, 0.0, 1.35)
		if _shift > 0.0:
			torque = 0.0        # clutch is in
		speed = move_toward(speed, top * clampf(throttle, 0.0, 1.0), torque * delta)
	elif throttle < -0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, base * 2.6 * delta)              # brakes
		else:
			speed = move_toward(speed, -top * 0.35, base * 0.9 * delta)      # reverse
	else:
		speed = move_toward(speed, 0.0, base * 0.45 * delta)                 # coasting

	if gone > 0:
		# the bare hub, dragging whatever the throttle is doing
		speed = move_toward(speed, 0.0, SCRAPE_DRAG * float(gone) * delta)

	# steering: bites once the car is rolling, calms down as it speeds up
	if absf(speed) > 0.25:
		var ratio := clampf(absf(speed) / maxf(float(data.get("top_speed", 16.0)), 0.001), 0.0, 1.0)
		var turn := TURN_RATE * (1.0 - 0.5 * ratio) * (1.6 if handbrake else 1.0)
		# no tyre on a front corner, nothing much to steer with
		turn *= [1.0, 0.55, 0.1][mini(gone_front, 2)]
		var ramp := clampf(absf(speed) / 3.5, 0.0, 1.0)
		rotate_y(-_steer * turn * ramp * delta * signf(speed))
		# and the corner that is on the floor hauls the car round towards it
		var pull := _drag_pull()
		if pull != 0.0:
			rotate_y(pull * clampf(absf(speed) / 6.0, 0.0, 1.0) * delta * signf(speed))

	var forward := -transform.basis.z
	velocity.x = forward.x * speed + shove.x
	velocity.z = forward.z * speed + shove.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	rotate_y(spin * delta)
	move_and_slide()
	_settle_shove(delta)
	_roll_wheels(delta)

	_check_impacts()
	_susp_awake = 2.0
	_suspend(delta)

# ------------------------------------------------------------
#  Wheels on the ground, and the body on its springs
# ------------------------------------------------------------
## Is that wheel still bolted on? A wheel the car was never given as a part --
## a truck's -- is always there.
func has_wheel(pid: String) -> bool:
	if pid == "" or not (data.get("parts", []) as Array).has(pid):
		return true
	return parts_remaining.has(pid)

func missing_wheels() -> int:
	var n := 0
	for pid in WHEEL_IDS:
		if not has_wheel(pid):
			n += 1
	return n

func _missing_on(front: bool) -> int:
	var n := 0
	for pid in (["wheel_fl", "wheel_fr"] if front else ["wheel_rl", "wheel_rr"]):
		if not has_wheel(pid):
			n += 1
	return n

## Which way the missing corners drag the nose, in radians a second. A corner
## on the right digs in and swings the car right; one on each side cancels.
func _drag_pull() -> float:
	var pull := 0.0
	for pid: String in WHEEL_IDS:
		if has_wheel(pid):
			continue
		var right := pid.ends_with("r")
		var front := pid.begins_with("wheel_f")
		pull += (-1.0 if right else 1.0) * (0.45 if front else 0.25)
	return pull

## One step of the springs. Each wheel finds the ground under it; the body fits
## a plane to where the wheels are holding it up, leans for how hard the car is
## braking and turning, and chases all of that on a damped spring -- so a kerb
## kicks the nose up and it bobs, a hard stop dips it, and a wheel that is not
## there leaves that corner on the floor.
func _suspend(delta: float) -> void:
	if _sprung == null or not is_instance_valid(_sprung) or delta <= 0.0:
		return
	# on the ramp or up on stands the body is held square: the teardown puts
	# every bolt where it is on a level car, and a car that sagged would move them
	if is_job or lifted:
		_heave = 0.0
		_pitch = 0.0
		_roll = 0.0
		_heave_v = 0.0
		_pitch_v = 0.0
		_roll_v = 0.0
		_sprung.transform = Transform3D.IDENTITY
		for c in _corners:
			if is_instance_valid(c.pivot):
				(c.pivot as Node3D).position = c.base
		return

	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var pts := []                   # [x, z, height the body is held at, weight]
	var gone_any := false
	for c in _corners:
		var pivot := c.pivot as Node3D
		if not is_instance_valid(pivot):
			continue
		var base: Vector3 = c.base
		var g := 0.0
		if space != null:
			var from := global_transform * (base + Vector3(0, RAY_UP, 0))
			var to := global_transform * (base - Vector3(0, RAY_DOWN, 0))
			var q := PhysicsRayQueryParameters3D.create(from, to, RideSurface.LAYER)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				g = clampf((hit.position as Vector3).y - global_position.y, -0.35, 0.45)
		c.g = g
		var there := has_wheel(String(c.pid))
		if there:
			# the wheel itself rides the ground, whatever the body is doing
			pivot.position = base + Vector3(0, g, 0)
			pts.append([base.x, base.z, g, 1.0])
		else:
			# nothing under that corner but the hub: it sits down on it
			gone_any = true
			var drop := clampf(base.y - 0.18, 0.15, 0.42)
			pts.append([base.x, base.z, g - drop, 6.0])

	var fit := _fit_plane(pts)
	var want_heave: float = fit[0]
	var want_pitch: float = -atan(fit[1])
	var want_roll: float = atan(fit[2])

	# weight moving about: braking dips the nose, pulling away squats it, and
	# cornering leans the body out of the turn
	var accel := (speed - _last_speed) / delta
	_last_speed = speed
	var yaw_rate := wrapf(rotation.y - _last_yaw, -PI, PI) / delta
	_last_yaw = rotation.y
	if absf(yaw_rate) > 8.0:
		yaw_rate = 0.0          # teleported or placed, not turning
	if driver != null or absf(speed) > 0.2:
		want_pitch += clampf(accel * DIVE, -0.06, 0.05)
		want_roll += clampf(-yaw_rate * speed * LEAN, -0.07, 0.07)

	var k := SPRING
	var c_damp := DAMP
	_heave_v += (k * (want_heave - _heave) - c_damp * _heave_v) * delta
	_pitch_v += (k * (want_pitch - _pitch) - c_damp * _pitch_v) * delta
	_roll_v += (k * (want_roll - _roll) - c_damp * _roll_v) * delta
	_heave += _heave_v * delta
	_pitch += _pitch_v * delta
	_roll += _roll_v * delta
	_heave = clampf(_heave, -0.5, 0.4)
	_pitch = clampf(_pitch, -MAX_TILT, MAX_TILT)
	_roll = clampf(_roll, -MAX_TILT, MAX_TILT)
	_sprung.transform = Transform3D(Basis.from_euler(Vector3(_pitch, 0.0, _roll)),
		Vector3(0, _heave, 0))

	# a car with a corner on the floor throws sparks off it while it moves
	_scrape_sparks(gone_any and absf(speed) > 1.0)

	# nobody driving and nothing left to settle: stop paying for the rays
	if driver == null and absf(speed) < 0.05 and shove.length() < 0.05 		and absf(_heave_v) + absf(_pitch_v) + absf(_roll_v) < 0.01 		and absf(want_heave - _heave) + absf(want_pitch - _pitch) + absf(want_roll - _roll) < 0.004:
		_susp_awake = 0.0

## Least-squares plane y = h + a*z + b*x through the points, weighted. Returns
## [h, a, b]. Four wheels on a rectangle is the usual case, but a truck has six.
static func _fit_plane(pts: Array) -> Array:
	if pts.is_empty():
		return [0.0, 0.0, 0.0]
	# normal equations for [1, z, x] . [h, a, b] = y
	var s := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var r := [0.0, 0.0, 0.0]
	for p in pts:
		var row := [1.0, float(p[1]), float(p[0])]
		var w := float(p[3])
		for i in 3:
			r[i] += w * row[i] * float(p[2])
			for j in 3:
				s[i][j] += w * row[i] * row[j]
	var det := _det3(s)
	if absf(det) < 1e-6:
		var mean := 0.0
		var wsum := 0.0
		for p in pts:
			mean += float(p[2]) * float(p[3])
			wsum += float(p[3])
		return [mean / maxf(wsum, 0.001), 0.0, 0.0]
	var out := [0.0, 0.0, 0.0]
	for col in 3:
		var m := [s[0].duplicate(), s[1].duplicate(), s[2].duplicate()]
		for i in 3:
			m[i][col] = r[i]
		out[col] = _det3(m) / det
	return out

static func _det3(m: Array) -> float:
	return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) 		- m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) 		+ m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])

## A knock through the springs: a shunt from the side rocks the body over, one
## from the front pitches it back. `from_local` points from the car towards
## whatever hit it, in the car's own space.
func jolt(from_local: Vector3, strength: float) -> void:
	var s := clampf(strength, 0.0, 3.0)
	var flat := Vector3(from_local.x, 0.0, from_local.z)
	if flat.length() > 0.01:
		flat = flat.normalized()
	# pushed away from the hit: struck on the right, the body rolls left
	_roll_v += -flat.x * s * 0.9
	_pitch_v += flat.z * s * 0.7
	_heave_v += s * 0.35
	_susp_awake = maxf(_susp_awake, 2.5)

func _scrape_sparks(on: bool) -> void:
	if not on:
		if _sparks != null and is_instance_valid(_sparks):
			_sparks.emitting = false
		return
	if _sparks == null or not is_instance_valid(_sparks):
		_sparks = CPUParticles3D.new()
		_sparks.amount = 36
		_sparks.lifetime = 0.35
		_sparks.direction = Vector3(0, 0.6, 1)
		_sparks.spread = 50.0
		_sparks.initial_velocity_min = 3.0
		_sparks.initial_velocity_max = 6.5
		_sparks.gravity = Vector3(0, -14, 0)
		_sparks.scale_amount_min = 0.04
		_sparks.scale_amount_max = 0.08
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.75, 0.3)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = mat
		_sparks.mesh = quad
		add_child(_sparks)
	# at whichever corner is on the road
	for c in _corners:
		if not has_wheel(String(c.pid)):
			_sparks.position = Vector3((c.base as Vector3).x, 0.05, (c.base as Vector3).z)
			break
	# thrown out behind the way it is going
	_sparks.direction = Vector3(0, 0.6, 1.0 if speed > 0.0 else -1.0)
	_sparks.emitting = true

## Which gear the speed puts us in, and the little lull while it changes.
func _update_gear(frac: float, delta: float) -> void:
	if _shift > 0.0:
		_shift -= delta
	var want := 0
	for i in GEAR_PULL.size():
		if frac >= GEAR_TOPS[i]:
			want = i
	if speed < 0.0:
		want = 0
	if want != gear:
		if want > gear:
			_shift = SHIFT_TIME
		gear = want

## Hang every wheel off a steering pivot and a rolling pivot, both square to
## the car and both centred on the wheel itself. Whatever orientation the model
## keeps its wheels in comes along for the ride underneath.
func _rig_wheels() -> void:
	_wheel_spin.clear()
	_wheel_steer.clear()
	_corners.clear()
	for w in _wheels:
		if not is_instance_valid(w):
			continue
		var box := _node_bounds(w)
		if box.size == Vector3.ZERO:
			continue
		var steer := Node3D.new()
		steer.name = "WheelSteer"
		steer.position = box.get_center()
		add_child(steer)
		var spin := Node3D.new()
		spin.name = "WheelSpin"
		steer.add_child(spin)
		var keep: Transform3D = w.global_transform
		w.get_parent().remove_child(w)
		spin.add_child(w)
		w.global_transform = keep
		_wheel_spin.append(spin)
		# a car faces -Z, so anything ahead of the middle is a front wheel
		if box.get_center().z < 0.0:
			_wheel_steer.append(steer)
		# which part this is, so the springs know when it has gone. A truck's
		# wheels are not parts at all, and are never missing.
		var pid := ""
		for key in _part_meshes.keys():
			if String(key).begins_with("wheel") and (_part_meshes[key] as Array).has(w):
				pid = String(key)
				break
		_corners.append({"pid": pid, "pivot": steer, "base": steer.position, "g": 0.0,
			"radius": maxf(0.2, box.size.y * 0.5)})

## Lift the bodywork off the car and onto the springs. Called once the shell,
## the doors and the wheel pivots all exist, so everything that is not a wheel,
## the collision box or the label goes across in one go.
func _mount_sprung() -> void:
	_sprung = Node3D.new()
	_sprung.name = "Sprung"
	add_child(_sprung)
	var pivots := []
	for c in _corners:
		pivots.append(c.pivot)
	for child in get_children():
		if child == _sprung or child is CollisionShape3D or child is Label3D or pivots.has(child):
			continue
		var keep: Transform3D = (child as Node3D).transform if child is Node3D else Transform3D()
		remove_child(child)
		_sprung.add_child(child, true)
		if child is Node3D:
			(child as Node3D).transform = keep
	_heave = 0.0
	_pitch = 0.0
	_roll = 0.0
	_heave_v = 0.0
	_pitch_v = 0.0
	_roll_v = 0.0

## The box a node's meshes fill, in the car's own space.
func _node_bounds(node: Node3D) -> AABB:
	var inv := global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for n in [node] + _descendants(node):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

## Roll the wheels for the ground covered, and point the front pair where the
## steering is pointing them.
func _roll_wheels(delta: float) -> void:
	for steer in _wheel_steer:
		if is_instance_valid(steer):
			steer.rotation.y = -_steer * MAX_LOCK
	if absf(speed) < 0.05:
		return
	var turn := -speed * delta / WHEEL_RADIUS
	for spin in _wheel_spin:
		if is_instance_valid(spin):
			spin.rotate_object_local(Vector3.RIGHT, turn)

## Whatever the car has just run into. Somebody on foot goes over the bonnet,
## another car and you both feel it, and a wall just costs you paint. The floor
## under the wheels is not a crash -- checking the collision count alone used
## to brake the car every single frame.
func _check_impacts() -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var who := hit.get_collider()
		if who is Pedestrian:
			var p := who as Pedestrian
			if absf(speed) > 7.0 and not p.tumbling and not p.down:
				# somebody over the bonnet leaves a mark in it
				var nose := global_transform * Vector3(0, _body_size().y * 0.62, -half_length * 0.7)
				dent_at(nose, Vector3.DOWN * 0.6 + global_transform.basis.z * 0.4, absf(speed) * 0.03)
			p.run_over(self, driver if driver != null else self)
		elif who is Vehicle:
			_crash_into(who as Vehicle, hit.get_normal())
		elif absf(hit.get_normal().y) < 0.5 and absf(speed) >= 3.0 and _crash_lull <= 0.0:
			# a wall. The metal takes it where it met the wall, square on
			var hard := absf(speed)
			_crash_lull = 0.25
			dent_at(hit.get_position(), hit.get_normal(), hard / 14.0)
			jolt(global_transform.basis.inverse() * -hit.get_normal(), hard / 7.0)
			if hard >= 6.0:
				condition = maxf(0.15, condition - 0.02)
				hurt_from(hit.get_position(), clampf(hard * 0.012, 0.02, 0.3))
				speed *= 0.45

## Two cars. Both get knocked off their line, both lose paint, and a hard
## enough one leaves a piece of somebody's car in the road.
func _crash_into(other: Vehicle, normal: Vector3) -> void:
	if _crash_lull > 0.0:
		return
	var closing := absf(speed - other.speed * (-transform.basis.z).dot(-other.transform.basis.z))
	if closing < 3.0:
		return
	# both cars see the same bump from their own side; one of them handling it
	# is enough, or they trade shunts back and forth until they shake apart
	_crash_lull = 0.4
	other._crash_lull = 0.4
	var into := Vector3(-normal.x, 0.0, -normal.z).normalized()
	if into.length() < 0.1:
		return
	# the one doing the hitting keeps most of its speed, the one being hit gets
	# pushed off its line -- rough, but it reads as a shunt rather than a wall
	other.take_shunt(into * closing * 0.55, self)
	shove -= into * closing * 0.2
	speed *= 0.55
	condition = maxf(0.1, condition - closing * 0.006)
	# our end of it: the panel facing them goes in, and the body rocks back
	dent_at(_skin_towards(other.global_position), -into, closing / 13.0)
	jolt(global_transform.basis.inverse() * into, closing / 6.0)
	if closing > 9.0:
		_shed_a_part(into)
		other._shed_a_part(-into)

## Being on the receiving end of one.
func take_shunt(push: Vector3, from: Node3D) -> void:
	shove += push
	# clipped off centre, so it slews round rather than sliding square
	var offset: Vector3 = global_transform.basis.inverse() * (global_position - from.global_position)
	spin += clampf(signf(offset.x) * offset.z * push.length() * 0.05, -2.0, 2.0)
	condition = maxf(0.1, condition - push.length() * 0.003)
	# and the panel that actually took it takes most of it
	hurt_from(from.global_position, clampf(push.length() * 0.05, 0.02, 0.5))
	# pushed in where they struck, and rocked on the springs by it
	var push_dir := push.normalized() if push.length() > 0.01 else Vector3.ZERO
	dent_at(_skin_towards(from.global_position), push_dir, push.length() / 7.0)
	jolt(global_transform.basis.inverse() * -push_dir, push.length() / 3.5)
	speed *= 0.7
	if is_job:
		refresh_label()

## Knock whichever panel took the hit into the road. Worth a fraction of what
## it was, but it is lying there and it can still be picked up and sold.
## A shunt marks the metal where it landed.
func bruise(where: Vector3, amount: float) -> void:
	hurt_from(where, amount)

func _shed_a_part(from_dir: Vector3) -> void:
	if parts_remaining.is_empty() or randf() > 0.55:
		return
	var local := global_transform.basis.inverse() * from_dir
	var order := []
	if absf(local.z) > absf(local.x):
		order = ["hood", "wheel_fl", "wheel_fr"] if local.z < 0.0 else ["trunk", "wheel_rl", "wheel_rr"]
	else:
		order = ["mirror_r", "door_r", "wheel_fr"] if local.x > 0.0 else ["mirror_l", "door_l", "wheel_fl"]
	for pid in order:
		if parts_remaining.has(pid) and has_part_mesh(pid):
			_throw_part_clear(String(pid), from_dir)
			return

## Off it goes, the way the hit was going. It lands somewhere down the road in
## pieces and is worth nothing -- taking a part off properly is the only way to
## get paid for one.
func _throw_part_clear(part_id: String, away: Vector3) -> void:
	var visual := make_part_visual(part_id)
	remove_part(part_id, 0.45)
	var item := PartItem.create(part_id, 0, String(data.get("name", "Car")),
		data.get("color", Color(0.6, 0.6, 0.6)), visual)
	get_tree().current_scene.add_child(item)
	var out := Vector3(away.x, 0.0, away.z).normalized()
	if out.length() < 0.1:
		out = -global_transform.basis.z
	item.global_position = global_position + Vector3.UP * 1.0 + out * 1.2
	item.fling(out * randf_range(6.0, 11.0) + Vector3.UP * randf_range(4.0, 7.0)
		+ Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))

## Rounds that hit a car with somebody in it hurt the person, not the panel.
## The bodywork takes some of it out, and the car is worth less afterwards.
func take_damage(amount: int, from: Node) -> void:
	condition = maxf(0.1, condition - float(amount) * 0.002)
	if from is Node3D:
		hurt_from((from as Node3D).global_position, float(amount) * 0.004)
	if is_job:
		refresh_label()
	if driver != null and is_instance_valid(driver) and driver.has_method("take_damage"):
		driver.take_damage(int(round(float(amount) * 0.7)), from)

# ------------------------------------------------------------
#  Interaction
# ------------------------------------------------------------
func get_prompt() -> String:
	if is_job:
		if stripped:
			return "[E] Bare shell - crush it for $%d" % shell_value()
		return "[E] Work on %s  (parts $%d / crush whole $%d)" % [data.name, estimated_value(), shell_value()]
	if has_occupant():
		if not GameState.can_carjack(data):
			return "%s (T%d) - driver's door is LOCKED DOWN: needs %s" % [
				data.name, int(data.tier), GameState.carjack_key_text(data)]
		return "[E] Drag the driver out of the %s (T%d)" % [data.name, int(data.tier)]
	if locked:
		if not GameState.can_attempt(data):
			return "%s (T%d) - LOCKED: needs %s" % [data.name, int(data.tier), GameState.requirement_text(data)]
		return "[E] Jimmy the driver door of the %s (T%d)" % [data.name, int(data.tier)]
	if not hotwired:
		return "[E] Hotwire the %s" % data.name
	return "[E] Drive %s" % data.name

func interact(player: Node) -> void:
	if is_job:
		player.open_dismantle(self)
	elif has_occupant():
		# somebody is sat in it: this is not a lock problem
		player.begin_carjack(self)
	elif locked:
		player.begin_breakin(self)
	elif not hotwired:
		player.begin_hotwire(self)
	else:
		player.enter_vehicle(self)

## The door is open. The car still will not go anywhere.
func unlock() -> void:
	locked = false
	open_door("door_l")          # the driver's one, which is the left one
	if _label:
		_label.visible = false

# ------------------------------------------------------------
#  Damage, panel by panel
# ------------------------------------------------------------
## part_id -> 0..1. A panel that has been hit is worth less than one that has
## not, and the car as a whole is worth what is still good on it rather than
## one number smeared across everything.
var part_wear := {}

func part_condition(part_id: String) -> float:
	return clampf(condition * float(part_wear.get(part_id, 1.0)), 0.05, 1.0)

## Something hit this part. `amount` is how badly, 0..1.
func hurt_part(part_id: String, amount: float) -> void:
	if not parts_remaining.has(part_id):
		return
	part_wear[part_id] = clampf(float(part_wear.get(part_id, 1.0)) - amount, 0.05, 1.0)
	refresh_label()

## The size of the car's collision box, which is also near enough its body.
func _body_size() -> Vector3:
	return data.get("body_size", Vector3(2.0, 1.3, 4.4)) as Vector3

## The point on the outside of the car nearest something at `other`, in world
## space, at about bumper-to-waist height. A crash only knows where the two cars
## were, not where they touched, and this is where they touched.
func _skin_towards(other: Vector3) -> Vector3:
	var local := global_transform.affine_inverse() * other
	var flat := Vector2(local.x, local.z)
	if flat.length() < 0.01:
		flat = Vector2(0, -1)
	var size := _body_size()
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	# out from the middle along that line until it meets a side of the box
	var t := minf(hx / maxf(absf(flat.x), 0.0001), hz / maxf(absf(flat.y), 0.0001))
	var edge := flat * t
	return global_transform * Vector3(edge.x, size.y * 0.42, edge.y)

## Push the metal in. `at` is where it was hit and `push` which way it was
## shoved, both in world space; `strength` is roughly 0 for a tap and 1 for a
## proper smash. Every mesh on the body near the hit moves -- skin, trim, glass,
## a door on its hinge -- by the same amount at the same place, so the panels
## stay joined up. Wheels are on their own pivots and are left round.
func dent_at(at: Vector3, push: Vector3, strength: float) -> void:
	if _sprung == null or not is_instance_valid(_sprung) or strength < 0.04:
		return
	if push.length() < 0.001:
		return
	var s := clampf(strength, 0.0, 1.6)
	var body_inv := _sprung.global_transform.affine_inverse()
	var p_body: Vector3 = body_inv * at
	var d_body: Vector3 = (body_inv.basis * push).normalized()
	var radius := clampf(0.55 + s * 0.9, 0.5, 1.8)
	var depth := clampf(s * 0.16, 0.02, 0.24)
	for n in _descendants(_sprung):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		if _is_person(mi):
			continue
		_dent_mesh(mi, p_body, d_body, radius, depth)

## Anybody sat in the car is not bodywork.
func _is_person(n: Node) -> bool:
	var at := n
	while at != null and at != _sprung:
		if at == occupant or at == passenger:
			return true
		at = at.get_parent()
	return false

func _dent_mesh(mi: MeshInstance3D, p_body: Vector3, d_body: Vector3,
		radius: float, depth: float) -> void:
	# from the body's space into this mesh's own, which on an imported car is
	# scaled and turned a quarter
	var to_mesh: Transform3D = mi.global_transform.affine_inverse() * _sprung.global_transform
	var p := to_mesh * p_body
	var d := (to_mesh.basis * d_body)
	var per_metre := d.length()
	if per_metre < 0.0001:
		return
	d = d.normalized()
	var r := radius * per_metre
	var deep := depth * per_metre
	var most := DENT_MAX * per_metre
	var box := mi.mesh.get_aabb().grow(r)
	if not box.has_point(p):
		return

	var state: Dictionary = _dents.get(mi, {})
	if state.is_empty():
		state = _dent_state(mi)
		if state.is_empty():
			return

	var r2 := r * r
	var moved_any := false
	var arrays_list: Array = state.arrays
	for si in arrays_list.size():
		var arrays: Array = arrays_list[si]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var rest: PackedVector3Array = state.rest[si]
		var moved := false
		for vi in verts.size():
			var v := verts[vi]
			var off := v - p
			var dist2 := off.length_squared()
			if dist2 >= r2:
				continue
			var f := 1.0 - sqrt(dist2) / r
			f = f * f * (3.0 - 2.0 * f)
			# a little crumple, the same for every copy of a point so the seams
			# between panels and cut pieces stay closed
			var crumple := sin(rest[vi].x * 37.0 + rest[vi].y * 17.0) * cos(rest[vi].z * 23.0) * 0.25
			var nv := v + d * deep * f * (1.0 + crumple)
			var from_rest := nv - rest[vi]
			if from_rest.length() > most:
				nv = rest[vi] + from_rest.normalized() * most
			verts[vi] = nv
			moved = true
		if moved:
			arrays[Mesh.ARRAY_VERTEX] = verts
			_renormal(arrays)
			moved_any = true
	if not moved_any:
		return
	# only a mesh that really bent is on the books, and it is on its own copy
	_dents[mi] = state
	var mesh: ArrayMesh = state.mesh
	mesh.clear_surfaces()
	for si in arrays_list.size():
		mesh.add_surface_from_arrays(state.prims[si], arrays_list[si])
		if state.mats[si] != null:
			mesh.surface_set_material(si, state.mats[si])
	mi.mesh = mesh

## This mesh's own copy of its geometry, taken the first time it is hit, so the
## other forty cars of the same model are not bent along with it.
func _dent_state(mi: MeshInstance3D) -> Dictionary:
	var src := mi.mesh
	var arrays_list := []
	var rest := []
	var prims := []
	var mats := []
	for si in src.get_surface_count():
		var prim := Mesh.PRIMITIVE_TRIANGLES
		if src is ArrayMesh:
			prim = (src as ArrayMesh).surface_get_primitive_type(si)
		if prim != Mesh.PRIMITIVE_TRIANGLES:
			return {}
		var arrays := src.surface_get_arrays(si)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			return {}
		# nothing skinned or morphing goes through this
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		# custom channels need their format flags passed back in to survive a
		# rebuild; nothing on a car shader reads them, so they go
		for ch in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[ch] = null
		arrays_list.append(arrays)
		rest.append((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
		prims.append(prim)
		mats.append(src.surface_get_material(si))
	if arrays_list.is_empty():
		return {}
	return {"mesh": ArrayMesh.new(), "arrays": arrays_list, "rest": rest,
		"prims": prims, "mats": mats}

## Normals worked out again from the bent triangles, so a dent catches the light.
## Vertices the model shares between faces get the average of them; ones it
## keeps separate for a hard edge keep their hard edge.
static func _renormal(arrays: Array) -> void:
	if arrays[Mesh.ARRAY_NORMAL] == null:
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var idx = arrays[Mesh.ARRAY_INDEX]
	var tri: PackedInt32Array
	if idx == null or (idx as PackedInt32Array).is_empty():
		tri = PackedInt32Array(range(verts.size()))
	else:
		tri = idx
	var t := 0
	while t + 2 < tri.size():
		var a := tri[t]
		var b := tri[t + 1]
		var c := tri[t + 2]
		# Godot winds clockwise, so this is the outward face
		var fn := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		normals[a] += fn
		normals[b] += fn
		normals[c] += fn
		t += 3
	var old: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# whichever way round the model was wound, agree with the normals it came
	# with rather than turning the whole panel inside out
	var agree := 0.0
	for i in normals.size():
		agree += normals[i].dot(old[i])
	var flip := -1.0 if agree < 0.0 else 1.0
	for i in normals.size():
		var n := normals[i] * flip
		normals[i] = n.normalized() if n.length_squared() > 1e-12 else old[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	# tangents describe the old surface; the renderer will manage without
	arrays[Mesh.ARRAY_TANGENT] = null

## Whatever was nearest the impact takes the worst of it, and the rest of the
## car takes a little. A shunt in the front should not devalue the boot lid.
func hurt_from(where: Vector3, amount: float) -> void:
	var local := global_transform.affine_inverse() * where
	var nearest := ""
	var best := 1e9
	for pid in parts_remaining:
		var box := part_bounds(pid)
		if box.size == Vector3.ZERO:
			continue
		var d := box.get_center().distance_to(local)
		if d < best:
			best = d
			nearest = pid
	if nearest != "":
		hurt_part(nearest, amount)
	for pid in parts_remaining:
		if pid != nearest:
			part_wear[pid] = clampf(float(part_wear.get(pid, 1.0)) - amount * 0.15, 0.05, 1.0)
	refresh_label()

# ------------------------------------------------------------
#  Heat on the car itself
# ------------------------------------------------------------
## 0 = nobody is looking for this car. 1 = every patrol in the city has the
## description. Runs down on its own over a fortnight, and comes off faster if
## you do something about it.
var heat := 0.0
## The game-minute the clock started, so it ages with the world rather than
## with how long the game has been open.
var heat_at := 0.0
var resprayed := false
## How many numbered panels have been swapped or ground since it was taken.
var panels_done := 0

## Taken off somebody. From here it is on a list.
func mark_hot(amount: float = -1.0) -> void:
	heat = maxf(heat, GameData.heat_for_theft(int(data.get("tier", 1))) if amount < 0.0 else amount)
	heat_at = GameState.minutes
	resprayed = false
	panels_done = 0

## What is left of it, after the time that has passed.
func heat_now() -> float:
	if heat <= 0.0:
		return 0.0
	var days := (GameState.minutes - heat_at) / (24.0 * 60.0)
	var left := heat * (1.0 - clampf(days / GameData.CAR_HEAT_DAYS, 0.0, 1.0))
	return maxf(0.0, left - _laundered())

## How much of it you have taken off by working on the car.
func _laundered() -> float:
	var off := 0.0
	if resprayed:
		off += GameData.HEAT_RESPRAY
	if panels_done >= GameData.HEAT_PANELS_NEEDED:
		off += GameData.HEAT_PANELS
		if resprayed:
			off += GameData.HEAT_BOTH_BONUS
	return off * heat

## Days left before it cools off on its own, for the readout.
func heat_days_left() -> float:
	if heat_now() <= 0.0:
		return 0.0
	var gone := (GameState.minutes - heat_at) / (24.0 * 60.0)
	return maxf(0.0, GameData.CAR_HEAT_DAYS - gone)

## What it would take to finish clearing it.
func heat_advice() -> String:
	if heat_now() <= 0.0:
		return ""
	var want := []
	if not resprayed:
		want.append("a respray")
	if panels_done < GameData.HEAT_PANELS_NEEDED:
		want.append("%d numbered panels off it" % (GameData.HEAT_PANELS_NEEDED - panels_done))
	if want.is_empty():
		return "%.0f days until the description goes stale" % heat_days_left()
	return "needs " + " and ".join(want)

## A different colour. On a model that means the body panels; on a box car it
## means every box that was built in the old colour. Glass, badges, tyres and
## lights are left alone -- nobody resprays those.
## Panels that were cut out of the bodyshell and now stand on their own. They
## are named after the part, not after the mesh they came from.
const PAINTED_PARTS := ["door_l", "door_r", "hood", "trunk", "mirror_l", "mirror_r"]

## A door is cut out of three meshes -- skin, trim card and frame -- so the
## scene ends up with door_l, door_l2 and door_l3. An exact name match only
## ever caught the first of them, which is why one panel came out the colour
## the model shipped in.
static func _is_painted_part(lower_name: String) -> bool:
	for pid: String in PAINTED_PARTS:
		if lower_name.begins_with(pid):
			return true
	return false

func repaint(colour: Color) -> void:
	var was := _paint_base
	data["color"] = colour
	_paint_base = colour
	resprayed = true
	for n in _descendants(self):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name).to_lower()
		if nm.contains("glass") or nm.contains("badge") or nm.contains("light") 				or nm.contains("wheel") or nm.contains("tire") or nm.contains("numberplate"):
			continue
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			var src := mi.mesh.surface_get_material(0)
			if src is StandardMaterial3D:
				m = (src as StandardMaterial3D).duplicate()
				mi.material_override = m
		if m == null:
			continue
		# on a model, the body material is the one to change; on a box car it
		# is whatever was painted in the old colour
		# The panels cut out of the shell are named after the part they became
		# -- "door_l", "hood" -- so none of the model's own naming applies to
		# them, and they were the ones coming out the wrong colour.
		var body_mat := nm.contains("bodymat") or nm.contains("_body_") 			or nm.contains("hood") or nm.contains("trunkdoor") or nm.contains("bumper") 			or nm.contains("_kit_") or nm.contains("spoiler") or _is_painted_part(nm)
		if body_mat or m.albedo_color.is_equal_approx(was):
			m.albedo_color = colour
	refresh_label()

## Which set of vehicle sounds this thing uses. A van the size of a house does
## not shut its door like a saloon.
func sound_set() -> String:
	var size: Vector3 = data.get("body_size", Vector3(2.0, 1.9, 4.4))
	return "truck" if size.y > 2.4 or size.z > 7.2 else "car"

## Running. Now it will.
func hotwire() -> void:
	hotwired = true
	Sfx.play("car_keys", global_position, -4.0)
	Sfx.play("car_start", global_position)
	close_door("door_l")

func set_as_job() -> void:
	is_job = true
	locked = true
	driver = null
	speed = 0.0
	_suspend(1.0 / 60.0)         # square on the ramp
	_label.visible = true
	refresh_label()

## Back off the ramp and onto the road. A car you delivered is one you own the
## keys to as far as the game is concerned, so it starts -- what stops you is
## whether it still has the wheels to roll on.
func release_job() -> void:
	is_job = false
	locked = false
	hotwired = true
	_susp_awake = 2.0
	if lifted:
		set_lifted(false)
	refresh_label()

## Has it still got all four corners on it? Nothing drives off a ramp on three
## wheels and a brake disc.
func can_roll() -> bool:
	for w in ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl"]:
		if not parts_remaining.has(w):
			return false
	return true

func refresh_label() -> void:
	# a truck builds its own body and never makes one of these
	if _label == null or not is_instance_valid(_label):
		return
	if stripped:
		_label.text = "%s\nBARE SHELL - crush for $%d" % [data.name, shell_value()]
	else:
		_label.text = "%s\nparts $%d / crush $%d - %d%%" % [data.name, estimated_value(), shell_value(), int(condition * 100.0)]

func estimated_value() -> int:
	var total := 0
	for p in parts_remaining:
		total += GameData.part_value(p, float(data.part_mult), part_condition(p))
	return total

## Weight still bolted to the shell. Drives the bare-metal price.
func mass_remaining() -> float:
	var m := GameData.SHELL_MASS
	for p in parts_remaining:
		m += float(GameData.PARTS[p].mass)
	return m

## What the crusher pays for the whole thing as-is. Drops as you strip it,
## and is always well under what the same car is worth parted out.
## The crusher pays by weight, but a shell full of straight panels is worth
## more than the same weight of bent ones -- so what is still good on it moves
## the price either way.
func shell_value() -> int:
	var raw := mass_remaining() * GameData.SCRAP_RATE * GameState.part_price_mult()
	return int(round(raw * lerpf(0.7, 1.2, average_condition())))

## Mean condition of everything still bolted on, weighted by nothing clever.
func average_condition() -> float:
	if parts_remaining.is_empty():
		return condition
	var total := 0.0
	for p in parts_remaining:
		total += part_condition(p)
	return clampf(total / float(parts_remaining.size()), 0.05, 1.0)

## True once the car is up on the jack / lift -- gate for wheels and underbody.
func set_lifted(on: bool) -> void:
	if lifted == on:
		return
	lifted = on
	_susp_awake = maxf(_susp_awake, 2.0)
	_suspend(1.0 / 60.0)
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + (0.55 if on else -0.55), 0.6)
	if on:
		for x in [-1.0, 1.0]:
			for z in [-1.6, 1.6]:
				# on the car, not on the springs: stands do not bob
				var stand := _add_box(Vector3(0.45, 0.55, 0.45), Vector3(x, 0.0, z), Color(0.85, 0.55, 0.1))
				stand.reparent(self, false)
				_jack_stands.append(stand)
	else:
		for st in _jack_stands:
			st.queue_free()
		_jack_stands.clear()
	refresh_label()

func remove_part(part_id: String, quality: float = 1.0) -> int:
	parts_remaining.erase(part_id)
	var value := int(round(float(GameData.part_value(part_id, float(data.part_mult), part_condition(part_id))) * clampf(quality, 0.4, 1.0)))
	set_part_mesh_visible(part_id, false)
	if parts_remaining.is_empty():
		stripped = true
	# a wheel gone and that corner is about to go down on its hub
	_susp_awake = maxf(_susp_awake, 3.0)
	refresh_label()
	return value
