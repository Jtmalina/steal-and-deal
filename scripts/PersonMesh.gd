extends RefCounted
class_name PersonMesh
# ============================================================
#  One box person, built the same way everywhere: the player,
#  the folk on the pavement, and the police.
#
#  Big head, T-shirt with bare arms, jeans that flare a little
#  at the ankle, brown shoes. Everyone faces +Z -- that is the
#  way the walk code turns them -- so faces go on the +Z side.
#
#  Arms and legs hang off named pivot nodes (LegL, LegR, ArmL,
#  ArmR) at the hip and the shoulder, so PersonRig can swing
#  them. Anything held goes in ArmR/Hand.
# ============================================================

const SKIN := [Color(0.86, 0.71, 0.56), Color(0.68, 0.5, 0.36), Color(0.45, 0.32, 0.24), Color(0.93, 0.8, 0.68)]
const SHIRTS := [
	Color(0.82, 0.22, 0.20),   # red
	Color(0.25, 0.60, 0.32),   # green
	Color(0.90, 0.75, 0.20),   # yellow
	Color(0.90, 0.50, 0.15),   # orange
	Color(0.35, 0.62, 0.80),   # pale blue
	Color(0.62, 0.35, 0.68),   # purple
	Color(0.88, 0.88, 0.85),   # white
	Color(0.20, 0.62, 0.60),   # teal
	Color(0.85, 0.55, 0.62),   # pink
	Color(0.45, 0.38, 0.28),   # brown
]
const TROUSERS := [
	Color(0.16, 0.20, 0.34), Color(0.22, 0.24, 0.30), Color(0.38, 0.32, 0.26),
	Color(0.13, 0.15, 0.22), Color(0.48, 0.44, 0.38),
]
const HAIR := [
	Color(0.30, 0.19, 0.10), Color(0.12, 0.10, 0.09), Color(0.52, 0.36, 0.16),
	Color(0.62, 0.55, 0.42), Color(0.44, 0.22, 0.12),
]
const SHOES := [Color(0.34, 0.20, 0.11), Color(0.14, 0.13, 0.13), Color(0.28, 0.26, 0.24)]

const EYE_WHITE := Color(0.93, 0.93, 0.92)
const DARK := Color(0.10, 0.09, 0.09)

## Where the limbs hinge. Everything below them is drawn hanging down from
## there, so a rotation about X swings the whole limb from the joint.
const HIP := 0.95
const SHOULDER := 1.38

static func build(root: Node3D, shirt: Color, trousers: Color,
		skin: Color = SKIN[0], hair: Color = HAIR[0], shoes: Color = SHOES[0]) -> void:
	# what they are wearing, so it can be read back without guessing which
	# child index the shirt happens to be this week
	root.set_meta("shirt", shirt)
	root.set_meta("trousers", trousers)
	root.set_meta("skin", skin)

	# --- legs, on a hip pivot: straight thigh, flared at the ankle, toe out ---
	for side in 2:
		var sx := -0.16 if side == 0 else 0.16
		var leg := _pivot(root, "LegL" if side == 0 else "LegR", Vector3(sx, HIP, 0))
		_box(leg, Vector3(0.27, 0.46, 0.27), Vector3(0, -0.23, 0), trousers)
		_box(leg, Vector3(0.31, 0.38, 0.30), Vector3(0, -0.63, 0.01), trousers)
		_box(leg, Vector3(0.30, 0.15, 0.44), Vector3(0, -0.875, 0.06), shoes)

	# --- T-shirt, hanging over the hips ---
	_box(root, Vector3(0.62, 0.70, 0.36), Vector3(0, 1.29, 0), shirt)
	for sx in [-0.39, 0.39]:
		_box(root, Vector3(0.20, 0.26, 0.34), Vector3(sx, 1.50, 0), shirt)

	# --- bare arms out of the sleeves, on a shoulder pivot ---
	for side in 2:
		var sx := -0.40 if side == 0 else 0.40
		var arm := _pivot(root, "ArmL" if side == 0 else "ArmR", Vector3(sx, SHOULDER, 0))
		_box(arm, Vector3(0.16, 0.44, 0.18), Vector3(0, -0.23, 0), skin)
		_box(arm, Vector3(0.18, 0.15, 0.20), Vector3(0, -0.51, 0), skin)
		if side == 1:
			# whatever they are holding hangs off the far end of this one
			_pivot(arm, "Hand", Vector3(0, -0.58, 0.08))

	# --- neck and head ---
	_box(root, Vector3(0.18, 0.10, 0.18), Vector3(0, 1.68, 0), skin)
	_box(root, Vector3(0.42, 0.36, 0.38), Vector3(0, 1.90, 0), skin)

	# --- hair: a cap over the top with a bit down the back ---
	_box(root, Vector3(0.44, 0.13, 0.40), Vector3(0, 2.10, 0), hair)
	_box(root, Vector3(0.44, 0.20, 0.10), Vector3(0, 1.98, -0.16), hair)

	# --- face, on the +Z side ---
	for sx in [-0.10, 0.10]:
		_box(root, Vector3(0.11, 0.13, 0.04), Vector3(sx, 1.94, 0.19), EYE_WHITE)
		_box(root, Vector3(0.05, 0.07, 0.02), Vector3(sx, 1.93, 0.21), DARK)
		_box(root, Vector3(0.13, 0.035, 0.03), Vector3(sx, 2.03, 0.19), hair.darkened(0.2))
	_box(root, Vector3(0.13, 0.03, 0.03), Vector3(0, 1.79, 0.19), DARK)

## A copper: navy from head to boot, peaked cap, badge on the chest.
static func build_officer(root: Node3D, rng: RandomNumberGenerator) -> void:
	var navy := Color(0.16, 0.2, 0.35)
	build(root, navy, navy.darkened(0.25), SKIN[rng.randi() % SKIN.size()],
		Color(0.12, 0.11, 0.12), Color(0.10, 0.10, 0.12))
	# cap sits over the hair, with a peak out front
	_box(root, Vector3(0.46, 0.15, 0.42), Vector3(0, 2.12, 0), Color(0.11, 0.13, 0.22))
	_box(root, Vector3(0.44, 0.05, 0.16), Vector3(0, 2.06, 0.26), Color(0.08, 0.09, 0.16))
	_box(root, Vector3(0.14, 0.14, 0.06), Vector3(0.18, 1.40, 0.19), Color(0.9, 0.8, 0.25))

static func random_civvies(rng: RandomNumberGenerator) -> Array:
	return [
		SHIRTS[rng.randi() % SHIRTS.size()],
		TROUSERS[rng.randi() % TROUSERS.size()],
		SKIN[rng.randi() % SKIN.size()],
		HAIR[rng.randi() % HAIR.size()],
		SHOES[rng.randi() % SHOES.size()],
	]

## What somebody is holding, drawn in their right hand. Clears whatever was
## there: the belt changes as often as they pick a different tool.
static func hold_item(hand: Node3D, id: String) -> void:
	if hand == null:
		return
	for c in hand.get_children():
		c.queue_free()
	var item: Dictionary = GameData.ITEMS.get(id, {})
	if item.is_empty():
		return
	var col: Color = item.get("colour", Color(0.6, 0.6, 0.6))
	match String(item.get("kind", "")):
		"gun":
			_box(hand, Vector3(0.07, 0.13, 0.10), Vector3(0, -0.02, 0.0), col)
			_box(hand, Vector3(0.06, 0.07, 0.26), Vector3(0, 0.07, 0.14), col.lightened(0.1))
		"melee":
			_box(hand, Vector3(0.05, 0.05, 0.62), Vector3(0, 0.0, 0.18), col)
			_box(hand, Vector3(0.05, 0.11, 0.09), Vector3(0, -0.03, 0.47), col.darkened(0.2))
		"torch":
			_box(hand, Vector3(0.06, 0.06, 0.26), Vector3(0, 0, 0.12), col.darkened(0.3))
			_box(hand, Vector3(0.09, 0.09, 0.09), Vector3(0, 0, 0.29), col)
		"tool":
			# a stubby body with a socket on the end, and a trigger if it has one
			_box(hand, Vector3(0.07, 0.09, 0.30), Vector3(0, 0.0, 0.12), col)
			_box(hand, Vector3(0.10, 0.10, 0.09), Vector3(0, 0.0, 0.30), col.darkened(0.25))
			if id == "impact_drill":
				_box(hand, Vector3(0.06, 0.16, 0.09), Vector3(0, -0.11, 0.05), col.darkened(0.4))
		_:
			_box(hand, Vector3(0.04, 0.04, 0.52), Vector3(0, 0.0, 0.14), col)
			_box(hand, Vector3(0.04, 0.10, 0.06), Vector3(0, -0.03, 0.38), col.darkened(0.15))

## A bare joint: no mesh of its own, just something to rotate.
static func _pivot(parent: Node, pivot_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n

static func _box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi
