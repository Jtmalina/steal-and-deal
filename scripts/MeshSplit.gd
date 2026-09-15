extends RefCounted
class_name MeshSplit
# ============================================================
#  Cuts an imported mesh into named pieces.
#
#  Bought car models weld things together: both doors live in
#  the body shell, both seats in the interior, the engine in
#  the underbody. This takes such a mesh and cuts its triangles
#  on the boundary of a named region, so each piece becomes its
#  own MeshInstance3D that the teardown can hide and hand over.
#
#  Triangles that straddle the boundary are cut, not sorted:
#  sorting whole triangles by where their centre lands leaves a
#  sawtooth edge, and a door is meant to come off with a
#  straight one. Cut faces are left open -- there is no
#  geometry inside a car door. At this art style that reads
#  fine; the alternative is doing it by hand in Blender.
# ============================================================

## Anything the clipper has to work out a value for at a new vertex. Whatever
## the source surface does not carry is left out of the pieces as well.
const LERPED := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
	Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
## Slop on the cutting planes, in metres. Vertices this close to a plane count
## as being on it, which keeps the cut from shedding hairline slivers.
const EPS := 0.00001

## Cutting one model is a few hundred thousand float operations and every car
## of the same make wants the identical result, so the first one pays for all
## of them. Keyed on the source mesh and the regions asked for.
static var _cache := {}

## Cut `src` into pieces. `regions` maps a name onto an AABB in the mesh's own
## local space; a triangle inside one goes to that piece, one that crosses the
## boundary is cut on it, and everything else stays in "".
## Returns {name: ArrayMesh}, only for regions that got any geometry.
static func by_regions(src: Mesh, regions: Dictionary) -> Dictionary:
	var key := "%d|%s" % [src.get_instance_id(), str(regions)]
	if _cache.has(key):
		return _cache[key]

	var out := {}
	for surface in src.get_surface_count():
		var arrays := src.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(verts.size()))
		# which attributes this surface actually carries
		var slots := []
		for slot in LERPED:
			if arrays[slot] != null:
				slots.append(slot)

		# one growing pile of loose triangles per bucket
		var piles := {"": []}
		for name in regions.keys():
			piles[name] = []

		var t := 0
		while t + 2 < idx.size():
			var poly := [_vertex(arrays, slots, idx[t]),
						 _vertex(arrays, slots, idx[t + 1]),
						 _vertex(arrays, slots, idx[t + 2])]
			var loose := [poly]
			for name in regions.keys():
				if loose.is_empty():
					break
				var box: AABB = regions[name]
				var carry := []
				for p in loose:
					var span := _span(p)
					# the cheap tests first: almost every triangle in a car body
					# is nowhere near the door being cut out of it
					if not box.intersects(span):
						carry.append(p)
					elif box.encloses(span):
						piles[name].append(p)
					else:
						var cut := _clip_box(p, box)
						if (cut[0] as Array).size() >= 3:
							piles[name].append(cut[0])
						carry.append_array(cut[1])
				loose = carry
			for p in loose:
				piles[""].append(p)
			t += 3

		for name in piles.keys():
			var pile: Array = piles[name]
			if pile.is_empty():
				continue
			var piece: ArrayMesh = out.get(name)
			if piece == null:
				piece = ArrayMesh.new()
				out[name] = piece
			piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _build(pile, slots))
			piece.surface_set_material(piece.get_surface_count() - 1,
				src.surface_get_material(surface))

	_cache[key] = out
	return out

## Cut the mesh on `holder` in place: the holder keeps the leftovers and gains
## one child MeshInstance3D per named region. Returns {name: node}.
static func apply(holder: MeshInstance3D, regions: Dictionary) -> Dictionary:
	var pieces := by_regions(holder.mesh, regions)
	var made := {}
	for key in pieces.keys():
		if key == "":
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(key)
		mi.mesh = pieces[key]
		# force_readable_name, because the piece has to keep the name of the
		# part it became. Left to itself Godot hands a clashing name back as
		# "@MeshInstance3D@22795", and everything downstream that works out
		# what a mesh is from what it is called -- the respray, most of all --
		# then treats a door as some anonymous lump of the bodyshell.
		holder.add_sibling(mi, true)
		mi.transform = holder.transform
		made[key] = mi
	holder.mesh = pieces.get("", null)
	return made

# ------------------------------------------------------------
#  Clipping
# ------------------------------------------------------------
## One vertex, as the values the pieces need to carry over. Index 0 is always
## the position; the rest follow `slots` in order.
static func _vertex(arrays: Array, slots: Array, at: int) -> Array:
	var v := []
	for slot in slots:
		match slot:
			Mesh.ARRAY_TANGENT:
				# four loose floats per vertex rather than one value
				var src: PackedFloat32Array = arrays[slot]
				v.append(PackedFloat32Array([src[at * 4], src[at * 4 + 1],
					src[at * 4 + 2], src[at * 4 + 3]]))
			_:
				v.append(arrays[slot][at])
	return v

## The box a polygon fills, for deciding whether it is worth cutting at all.
static func _span(poly: Array) -> AABB:
	var box := AABB(poly[0][0], Vector3.ZERO)
	for i in range(1, poly.size()):
		box = box.expand(poly[i][0])
	return box

## Cut a convex polygon on the six faces of `box`. Returns [inside, outside],
## where inside is the single convex piece within the box and outside is the
## list of convex pieces that make up the rest of it.
static func _clip_box(poly: Array, box: AABB) -> Array:
	var lo := box.position
	var hi := box.end
	var planes := [
		[Vector3.LEFT, -lo.x], [Vector3.RIGHT, hi.x],
		[Vector3.DOWN, -lo.y], [Vector3.UP, hi.y],
		[Vector3.FORWARD, -lo.z], [Vector3.BACK, hi.z],
	]
	var outside := []
	var inside := poly
	for plane in planes:
		if inside.size() < 3:
			inside = []
			break
		var cut := _clip_half(inside, plane[0], plane[1])
		inside = cut[0]
		if (cut[1] as Array).size() >= 3:
			outside.append(cut[1])
	return [inside, outside]

## Cut a convex polygon on the plane n.v = d, keeping both halves. The new
## vertices along the cut are shared, so the two halves stay watertight
## against each other.
static func _clip_half(poly: Array, n: Vector3, d: float) -> Array:
	var under := []
	var over := []
	var count := poly.size()
	for i in count:
		var cur: Array = poly[i]
		var nxt: Array = poly[(i + 1) % count]
		var sc: float = n.dot(cur[0]) - d
		var sn: float = n.dot(nxt[0]) - d
		if sc <= EPS:
			under.append(cur)
		if sc >= -EPS:
			over.append(cur)
		if (sc < -EPS and sn > EPS) or (sc > EPS and sn < -EPS):
			var mid := _mix(cur, nxt, sc / (sc - sn))
			under.append(mid)
			over.append(mid)
	return [under, over]

## A vertex `t` of the way from `a` to `b`.
static func _mix(a: Array, b: Array, t: float) -> Array:
	var v := []
	for i in a.size():
		var av = a[i]
		var bv = b[i]
		if av is PackedFloat32Array:
			var mixed := PackedFloat32Array()
			for k in av.size():
				mixed.append(lerpf(av[k], bv[k], t))
			v.append(mixed)
		elif av is Color:
			v.append((av as Color).lerp(bv, t))
		elif av is Vector2:
			v.append((av as Vector2).lerp(bv, t))
		else:
			v.append((av as Vector3).lerp(bv, t))
	return v

## Fan the convex polygons out into a triangle soup Godot will take. One pass
## per attribute, so nothing has to reach back into a half-built array.
static func _build(pile: Array, slots: Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	for c in slots.size():
		var slot: int = slots[c]
		match slot:
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
				var col := PackedVector3Array()
				for v in _fan(pile):
					col.append(v[c])
				arrays[slot] = col
			Mesh.ARRAY_TANGENT:
				var col := PackedFloat32Array()
				for v in _fan(pile):
					col.append_array(v[c])
				arrays[slot] = col
			Mesh.ARRAY_COLOR:
				var col := PackedColorArray()
				for v in _fan(pile):
					col.append(v[c])
				arrays[slot] = col
			_:
				var col := PackedVector2Array()
				for v in _fan(pile):
					col.append(v[c])
				arrays[slot] = col
	return arrays

## Every polygon in the pile, fanned out three vertices at a time.
static func _fan(pile: Array) -> Array:
	var out := []
	for poly in pile:
		for i in range(1, poly.size() - 1):
			out.append(poly[0])
			out.append(poly[i])
			out.append(poly[i + 1])
	return out
