extends Node3D
class_name PartItem
# ============================================================
#  A part that is off the car and lying about. You carry these
#  one at a time, drop them where you like, and load them into
#  the truck by hand.
# ============================================================

var part_id := ""
var part_name := ""
var value := 0
var size := 1
var from_name := ""
## Which vehicle definition it came off, so the order board can tell a sedan
## door from a coupe door.
var from_id := ""
var carried := false
## Knocked off a car in a smash rather than taken off properly: it went across
## the road end over end, and it is worth nothing to anybody now.
var damaged := false
var _fly := Vector3.ZERO
var _tumble := Vector3.ZERO
var _mesh_root: Node3D
## Seconds until a wrecked part is cleared away. Negative for one you took off
## yourself -- those stay put until you do something with them.
var _life := -1.0

var _label: Label3D

## `visual` is the real mesh off the car when it had one; without it the part
## falls back to a generic shape.
static func create(pid: String, val: int, from: String, body: Color, visual: Node3D = null,
		from_id: String = "") -> PartItem:
	var item := PartItem.new()
	item.part_id = pid
	item.part_name = String(GameData.PARTS[pid].name)
	item.value = val
	item.size = int(GameData.PARTS[pid].get("size", 1))
	item.from_name = from
	item.from_id = from_id
	item._body_color = body
	item._visual = visual
	return item

var _body_color := Color(0.6, 0.6, 0.6)
var _visual: Node3D = null

func _ready() -> void:
	add_to_group("loose_part")
	add_to_group("interactable")
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	if _visual != null:
		_mesh_root.add_child(_visual)
	else:
		PartMesh.build(_mesh_root, part_id, _body_color)

	_label = Label3D.new()
	_label.text = "%s\n$%d" % [part_name, value]
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 12
	_label.position = Vector3(0, 0.7, 0)
	add_child(_label)

## Hands the real mesh over to whoever is taking this part off you. The truck
## keeps showing it in the back long after the loose part itself is gone.
func take_visual() -> Node3D:
	if _visual == null or not is_instance_valid(_visual):
		return null
	if _visual.get_parent() != null:
		_visual.get_parent().remove_child(_visual)
	var out := _visual
	_visual = null
	return out

## Thrown clear of a crash: it flies, it tumbles, it lands, and it is scrap.
## Nobody is buying a door that has been down the road on its own.
func fling(launch: Vector3) -> void:
	damaged = true
	value = 0
	_fly = launch
	_tumble = Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
	_life = 62.0
	remove_from_group("interactable")
	if _label:
		_label.text = "%s
(wrecked)" % part_name
		_label.modulate = Color(0.9, 0.5, 0.45)

func _physics_process(delta: float) -> void:
	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
			tw.tween_callback(queue_free)
	if _fly == Vector3.ZERO or carried:
		return
	_fly.y -= 24.0 * delta
	global_position += _fly * delta
	if _mesh_root:
		_mesh_root.rotation += _tumble * delta
	# the ground, near enough: bounce once or twice and give up
	if global_position.y <= 0.3:
		global_position.y = 0.3
		if _fly.length() < 2.5:
			_fly = Vector3.ZERO
			_tumble = Vector3.ZERO
		else:
			_fly.y = absf(_fly.y) * 0.35
			_fly.x *= 0.6
			_fly.z *= 0.6
			_tumble *= 0.5

## A number stamped on it at the factory, still there. Grinding it off is what
## the sander is for, and a fence pays a great deal more for a panel that
## cannot be walked back to a stolen car.
var vin_gone := false

func has_vin() -> bool:
	return not vin_gone and not damaged and GameData.VIN_PARTS.has(part_id)

func sand_off_vin() -> int:
	if not has_vin():
		return 0
	vin_gone = true
	var was := value
	value = int(round(float(value) * (1.0 + GameData.VIN_BONUS)))
	_refresh_label()
	return value - was

func _refresh_label() -> void:
	if _label == null:
		return
	_label.text = "%s
$%d%s" % [part_name, value, "  (no number)" if vin_gone else ""]

func get_prompt() -> String:
	if damaged:
		return "%s -- wrecked, no good to anyone" % part_name
	# whatever is in your hand decides what [E] does to it
	if GameState.held() == "sander" and has_vin():
		return "[E] Grind the number off the %s  ($%d -> $%d)" % [
			part_name, value, int(round(float(value) * (1.0 + GameData.VIN_BONUS)))]
	return "[E] Pick up %s  ($%d)%s" % [part_name, value, "  (no number)" if vin_gone else ""]

func interact(player: Node) -> void:
	if GameState.held() == "sander" and has_vin():
		var gained := sand_off_vin()
		Sfx.play("car_handbrake", global_position, -6.0)
		player.hud.toast("NUMBER GONE", "%s is worth $%d more with nothing to trace it by." % [
			part_name, gained])
		return
	player.pick_up(self)

## Held in the hands: no longer something you can walk up to and grab.
func set_carried(on: bool) -> void:
	carried = on
	_label.visible = not on
	if on:
		remove_from_group("interactable")
	elif not damaged and not is_in_group("interactable"):
		add_to_group("interactable")
