extends RefCounted
class_name RideSurface
# ============================================================
#  Things a wheel feels and a car does not stop at.
#
#  A kerb is thirteen centimetres of stone. Built as a wall, it
#  stops a car dead; built as paint, it is not there at all.
#  Everything on this layer is a shape only the wheels look for
#  -- their ground rays are cast against it and nothing else --
#  so the car rides up over it, the body pitches, and it drives
#  on. The ground itself is on it too, so a ray always lands.
# ============================================================

## Physics layer 5. Car bodies, people and the camera never collide with it.
const LAYER := 1 << 4

## Everything built here hangs off one node, so anything that goes looking for
## solid scenery can step round the lot of it by name.
static var root: Node3D = null

static func begin(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "RideSurface"
	parent.add_child(root)

## A box a wheel can roll over, in world space. Nothing is drawn: whoever calls
## this has already drawn the kerb or the hump.
static func add(size: Vector3, at: Vector3, yaw: float = 0.0) -> void:
	if root == null or not is_instance_valid(root):
		return
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	body.rotation.y = yaw
	root.add_child(body)

## A speed hump across a drive: painted, and felt. `at` is where it crosses,
## `across` is the way it runs, in world space.
static func hump(parent: Node3D, at_world: Vector3, length: float, yaw: float) -> void:
	var node := Node3D.new()
	parent.add_child(node)
	node.global_position = at_world
	node.rotation.y = yaw
	var mat_a := _mat(Color(0.86, 0.72, 0.16))
	var mat_b := _mat(Color(0.14, 0.14, 0.15))
	# yellow and black blocks along it, the way they are painted
	var n := maxi(2, int(length / 0.9))
	for i in n:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(length / float(n), 0.1, 0.55)
		mi.mesh = m
		mi.position = Vector3(-length * 0.5 + (float(i) + 0.5) * length / float(n), 0.05, 0)
		mi.material_override = mat_a if i % 2 == 0 else mat_b
		node.add_child(mi)
	add(Vector3(length, 0.1, 0.55), at_world + Vector3(0, 0.05, 0), yaw)

static var _mats := {}

static func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_rgba32()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]
