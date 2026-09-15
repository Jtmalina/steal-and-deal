extends RefCounted
class_name PartMesh
# ============================================================
#  One place that knows what every part looks like. Used by the
#  teardown rig, by loose parts lying about the garage, and by
#  whatever is stacked in the back of the truck.
# ============================================================

## Builds `id` under `root` and returns a sensible grab radius.
static func build(root: Node3D, id: String, body: Color = Color(0.6, 0.6, 0.6)) -> float:
	var glass := Color(0.3, 0.45, 0.55)
	match kind(id):
		"hood":
			_box(root, Vector3(1.96, 0.07, 1.03), body.lightened(0.05), Vector3.ZERO)
			return 0.75
		"trunk":
			_box(root, Vector3(1.96, 0.07, 1.26), body.lightened(0.05), Vector3.ZERO)
			return 0.8
		"door":
			_box(root, Vector3(0.08, 0.95, 1.7), body.darkened(0.08), Vector3.ZERO)
			_box(root, Vector3(0.06, 0.42, 1.5), glass, Vector3(0.01, 0.35, 0.05))
			return 0.75
		"wheel":
			_cyl(root, 0.42, 0.32, Color(0.12, 0.12, 0.14), Vector3.ZERO, Vector3(0, 0, 90))
			_cyl(root, 0.21, 0.34, Color(0.6, 0.6, 0.65), Vector3.ZERO, Vector3(0, 0, 90))
			return 0.45
		"battery":
			_box(root, Vector3(0.3, 0.26, 0.22), Color(0.12, 0.12, 0.14), Vector3.ZERO)
			_cyl(root, 0.035, 0.06, Color(0.8, 0.1, 0.1), Vector3(0.09, 0.16, 0))
			_cyl(root, 0.035, 0.06, Color(0.15, 0.15, 0.15), Vector3(-0.09, 0.16, 0))
			return 0.3
		"engine":
			_box(root, Vector3(0.8, 0.4, 0.82), Color(0.3, 0.3, 0.33), Vector3.ZERO)
			_box(root, Vector3(0.55, 0.16, 0.6), Color(0.38, 0.38, 0.4), Vector3(0, 0.26, 0.02))
			_cyl(root, 0.16, 0.1, Color(0.25, 0.25, 0.28), Vector3(0, -0.05, -0.45), Vector3(90, 0, 0))
			return 0.55
		"transmission":
			_box(root, Vector3(0.5, 0.42, 0.5), Color(0.35, 0.35, 0.38), Vector3.ZERO)
			_cyl(root, 0.09, 0.7, Color(0.3, 0.3, 0.32), Vector3(0, -0.02, 0.55), Vector3(90, 0, 0))
			return 0.4
		"catalytic":
			_box(root, Vector3(0.26, 0.18, 0.42), Color(0.55, 0.5, 0.45), Vector3.ZERO)
			_cyl(root, 0.06, 0.9, Color(0.4, 0.38, 0.36), Vector3(0, 0, 0.1), Vector3(90, 0, 0))
			return 0.34
		"seat":
			_box(root, Vector3(0.5, 0.14, 0.5), body.darkened(0.5), Vector3.ZERO)
			_box(root, Vector3(0.5, 0.55, 0.14), body.darkened(0.5), Vector3(0, 0.3, 0.28))
			return 0.42
		"electronics":
			_box(root, Vector3(0.3, 0.12, 0.24), Color(0.2, 0.25, 0.3), Vector3.ZERO)
			_box(root, Vector3(0.1, 0.08, 0.06), Color(0.9, 0.7, 0.1), Vector3(0, 0, -0.15))
			return 0.26
		"mirror":
			_box(root, Vector3(0.1, 0.16, 0.28), body.darkened(0.1), Vector3(-0.12, 0, 0))
			_box(root, Vector3(0.14, 0.22, 0.1), body.darkened(0.1), Vector3(0, 0.02, 0))
			_box(root, Vector3(0.02, 0.17, 0.05), Color(0.72, 0.78, 0.82), Vector3(0.08, 0.02, 0))
			return 0.22
		"dash_trim":
			_box(root, Vector3(0.85, 0.06, 0.32), body.darkened(0.4), Vector3.ZERO)
			return 0.4
		"door_handle":
			_box(root, Vector3(0.08, 0.09, 0.42), body.lightened(0.25), Vector3.ZERO)
			_box(root, Vector3(0.05, 0.16, 0.5), body.darkened(0.3), Vector3(-0.05, -0.02, 0))
			return 0.34
		"driver":
			# a shoulder and an arm: enough to read as somebody being pulled
			_box(root, Vector3(0.34, 0.5, 0.3), Color(0.55, 0.4, 0.35), Vector3.ZERO)
			_box(root, Vector3(0.2, 0.2, 0.2), Color(0.86, 0.71, 0.56), Vector3(0, 0.34, 0))
			_box(root, Vector3(0.14, 0.4, 0.16), Color(0.86, 0.71, 0.56), Vector3(-0.2, -0.06, 0.05))
			return 0.42
		"stands":
			_box(root, Vector3(0.4, 0.5, 0.4), Color(0.85, 0.55, 0.1), Vector3(0, 0, -0.3))
			_box(root, Vector3(0.4, 0.5, 0.4), Color(0.85, 0.55, 0.1), Vector3(0, 0, 0.3))
			return 0.45
	_box(root, Vector3(0.4, 0.4, 0.14), Color(0.9, 0.65, 0.15), Vector3.ZERO)
	return 0.35

## Collapses the per-corner / per-side ids onto one shape.
static func kind(id: String) -> String:
	if id.begins_with("wheel"):
		return "wheel"
	# the two doors only: "door_handle" is its own thing and is not a door
	if id == "door_l" or id == "door_r":
		return "door"
	if id.begins_with("seat"):
		return "seat"
	if id.begins_with("mirror"):
		return "mirror"
	return id

static func _box(parent: Node, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node, r: float, h: float, color: Color, pos: Vector3, rot: Vector3 = Vector3(90, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi

static func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.2
	return m
