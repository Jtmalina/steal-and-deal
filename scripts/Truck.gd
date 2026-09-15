extends Vehicle
class_name Truck
# ============================================================
#  Your haulage. Parts go in the back one at a time, by hand.
#  With a tow hitch on, it will drag a whole junker to the yard.
# ============================================================

var cargo: Array = []            # [{part, name, value, size, from, visual}]
var towed: Vehicle = null
var _bed: Node3D
var _stack: Node3D

func _ready() -> void:
	super()
	remove_from_group("vehicle")
	add_to_group("truck")
	locked = false
	hotwired = true
	if _label:
		_label.visible = false

func capacity() -> int:
	return int(GameData.truck_by_level(GameState.truck_level).capacity)

func used() -> int:
	var n := 0
	for c in cargo:
		n += int(c.size)
	return n

func space_left() -> int:
	return capacity() - used()

# ------------------------------------------------------------
#  Body -- replaces the car mesh entirely
# ------------------------------------------------------------
func _build() -> void:
	var spec: Dictionary = GameData.truck_by_level(GameState.truck_level)
	var body: Color = spec.color
	var dark := body.darkened(0.35)
	var bed_len: float = float(spec.bed_len)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.5, 2.6 + bed_len)
	col.shape = box
	col.position = Vector3(0, 0.75, bed_len * 0.5 - 0.6)
	add_child(col)

	# A modelled truck brings its own body, wheels and cab with it. Everything
	# below this is the box-built stand-in for the levels that have no model.
	if data.has("model"):
		var size: Vector3 = data.get("body_size", Vector3(2.2, 1.5, 2.6 + bed_len))
		box.size = Vector3(size.x * 0.78, size.y * 0.62, size.z * 0.9)
		col.position = Vector3(0, size.y * 0.34, 0)
		_build_model_shell()
		for pid in (spec.get("wheels", {}) as Dictionary).keys():
			var nm := String(spec.wheels[pid])
			for n in _descendants(self):
				if String(n.name) == nm:
					# NOT registered as a part: a truck's parts list is empty,
					# and anything registered against an empty list gets hidden
					# on the next refresh -- which took the wheels off it
					_wheels.append(n)
					break
		_bed = Node3D.new()
		_bed.position = spec.get("bed_at", Vector3(0, 1.2, 1.3))
		add_child(_bed)
		_stack = Node3D.new()
		_bed.add_child(_stack)
		if GameState.has_shop_tool("hitch"):
			_add_box(Vector3(0.3, 0.18, 0.5), Vector3(0, 0.55, size.z * 0.5 + 0.3),
				Color(0.3, 0.3, 0.32))
		return

	# cab
	_add_box(Vector3(2.1, 0.8, 2.4), Vector3(0, 0.8, -1.2), body)
	_add_box(Vector3(1.8, 0.7, 1.3), Vector3(0, 1.55, -1.3), dark)
	_add_box(Vector3(1.6, 0.45, 0.08), Vector3(0, 1.55, -1.95), Color(0.3, 0.45, 0.55, 0.45))
	_add_box(Vector3(0.35, 0.2, 0.12), Vector3(0.7, 0.75, -2.44), Color(1, 0.95, 0.75))
	_add_box(Vector3(0.35, 0.2, 0.12), Vector3(-0.7, 0.75, -2.44), Color(1, 0.95, 0.75))

	# bed / box / trailer
	_bed = Node3D.new()
	add_child(_bed)
	_add_box(Vector3(2.1, 0.25, bed_len), Vector3(0, 0.72, bed_len * 0.5), dark)
	if int(spec.level) == 1:
		for sx in [-1.0, 1.0]:
			_add_box(Vector3(0.12, 0.55, bed_len), Vector3(sx, 1.05, bed_len * 0.5), body)
		_add_box(Vector3(2.1, 0.55, 0.12), Vector3(0, 1.05, bed_len), body)
	else:
		# a box body: walls and a roof, with the back left open
		for sx in [-1.0, 1.0]:
			_add_box(Vector3(0.1, 1.9, bed_len), Vector3(sx, 1.75, bed_len * 0.5), body)
		_add_box(Vector3(2.1, 1.9, 0.1), Vector3(0, 1.75, 0.05), body.darkened(0.15))
		_add_box(Vector3(2.2, 0.12, bed_len), Vector3(0, 2.72, bed_len * 0.5), dark)

	_stack = Node3D.new()
	_bed.add_child(_stack)

	if GameState.has_shop_tool("hitch"):
		_add_box(Vector3(0.3, 0.18, 0.5), Vector3(0, 0.55, bed_len + 0.3), Color(0.3, 0.3, 0.32))

	for x in [-0.95, 0.95]:
		for z in [-1.5, bed_len * 0.55]:
			_wheels.append(_add_wheel(Vector3(x, 0.42, z)))
		if int(spec.level) >= 3:
			_wheels.append(_add_wheel(Vector3(x, 0.42, bed_len * 0.55 + 1.0)))

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 44
	_label.pixel_size = 0.006
	_label.outline_size = 14
	_label.position = Vector3(0, 2.6, 0)
	add_child(_label)

## Rebuilds after a truck upgrade, keeping whatever is in the back.
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_wheels.clear()
	_build()
	_rig_wheels()
	_restack()

# ------------------------------------------------------------
#  Loading
# ------------------------------------------------------------
func can_take(item: PartItem) -> bool:
	return not item.damaged and space_left() >= item.size

func load_part(item: PartItem) -> bool:
	if not can_take(item):
		return false
	# the real mesh off the car comes with it, so a door in the back is that
	# door and not a placeholder block. It is held outside the tree until the
	# stack is drawn, and freed when the load is sold.
	cargo.append({"part": item.part_id, "name": item.part_name, "value": item.value,
		"size": item.size, "from": item.from_name, "from_id": item.from_id,
		"visual": item.take_visual()})
	item.queue_free()
	_restack()
	return true

func unload_all() -> Array:
	var out := cargo.duplicate()
	for c in cargo:
		var vis: Node3D = c.get("visual")
		if vis != null and is_instance_valid(vis):
			vis.free()
		c.erase("visual")
	cargo.clear()
	_restack()
	return out

## Show what is actually in the back, up to a sensible pile.
func _restack() -> void:
	if _stack == null or not is_instance_valid(_stack):
		return
	for c in _stack.get_children():
		c.queue_free()
	var spec: Dictionary = GameData.truck_by_level(GameState.truck_level)
	var bed_len: float = float(spec.bed_len)
	# Full size, laid flat and piled up the way panels actually go in the back
	# of a truck. Nothing is scaled down: a door in the bed is the same door
	# that came off the car.
	# a modelled truck has a real tray, so the pile is laid out inside it; the
	# box-built ones keep the offsets they were drawn around
	var span: Vector3 = spec.get("bed_span", Vector3.ZERO)
	var modelled := span != Vector3.ZERO
	var shown: int = mini(cargo.size(), 8)
	for i in shown:
		var holder := Node3D.new()
		var row := i / 2
		if modelled:
			holder.position = Vector3(
				-span.x * 0.25 + span.x * 0.5 * float(i % 2),
				0.13 * float(row),
				-span.z * 0.5 + 0.2 + minf(span.z - 0.4, 0.75 * float(row)))
		else:
			holder.position = Vector3(-0.42 + 0.84 * float(i % 2), 0.95 + 0.13 * float(row),
				0.9 + minf(bed_len - 1.6, 0.7 * float(row)))
		holder.scale = Vector3.ONE
		# on its side, so height across the bed and length down it
		holder.rotation = Vector3(0, randf_range(-0.25, 0.25), PI * 0.5)
		_stack.add_child(holder)
		var vis: Node3D = cargo[i].get("visual")
		if vis != null and is_instance_valid(vis):
			holder.add_child(vis.duplicate())
		else:
			PartMesh.build(holder, String(cargo[i].part), data.get("color", Color(0.6, 0.6, 0.6)))
	if _label:
		_label.text = "%s  %d/%d" % [spec.name, used(), capacity()]
	GameState.inventory_changed.emit()

# ------------------------------------------------------------
#  Towing
# ------------------------------------------------------------
func can_tow(v: Vehicle) -> bool:
	return GameState.has_shop_tool("hitch") and towed == null and int(v.data.tier) <= GameState.tow_tier()

func hitch(v: Vehicle) -> void:
	towed = v
	v.driver = self          # stops it running its own gravity step
	v.set_lifted(false)

func unhitch() -> void:
	if towed and is_instance_valid(towed):
		towed.driver = null
	towed = null

func _physics_process(delta: float) -> void:
	super(delta)
	if towed == null or not is_instance_valid(towed):
		return
	var spec: Dictionary = GameData.truck_by_level(GameState.truck_level)
	var behind := global_position + global_transform.basis.z * (float(spec.bed_len) + 3.4)
	behind.y = towed.global_position.y
	towed.global_position = towed.global_position.lerp(behind, clampf(delta * 6.0, 0.0, 1.0))
	var flat := Vector3(global_position.x, towed.global_position.y, global_position.z)
	if flat.distance_to(towed.global_position) > 0.2:
		towed.look_at(flat, Vector3.UP)

# ------------------------------------------------------------
#  Interaction
# ------------------------------------------------------------
func get_prompt() -> String:
	var spec: Dictionary = GameData.truck_by_level(GameState.truck_level)
	if locked:
		return "[E] Jimmy the %s open -- the pound is not going to hand it over" % spec.name
	if not hotwired:
		return "[E] Hotwire the %s and get it out of here" % spec.name
	var player := get_tree().get_first_node_in_group("player")
	if player and player.carrying:
		if can_take(player.carrying):
			return "[E] Load %s into the %s   (%d/%d)" % [player.carrying.part_name, spec.name, used(), capacity()]
		return "%s is full (%d/%d)" % [spec.name, used(), capacity()]
	var tow := "  towing %s" % towed.data.name if towed else ""
	return "[E] Drive the %s   (cargo %d/%d)%s" % [spec.name, used(), capacity(), tow]

func interact(player: Node) -> void:
	if locked or not hotwired:
		super.interact(player)          # jimmy it and wire it, like anything else
	elif player.carrying:
		player.load_into_truck(self)
	else:
		player.enter_vehicle(self)
