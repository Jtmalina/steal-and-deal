extends Node3D
class_name PoliceDispatch
# ============================================================
#  Spawns / despawns pursuit units, runs the escape timer.
# ============================================================

# The parts list is not about stripping a cruiser -- it is what the car is
# built out of. Vehicle hides every panel that is not on this list, so an empty
# one is a car with no wheels, no doors, no hood and no boot driving down the
# road on its floor pan.
const COP_DATA := {
	"id": "cop", "name": "Cruiser", "tier": 2, "value": 0, "part_mult": 1.0,
	"zone": 0.2, "heat": 0, "top_speed": 27.0, "accel": 14.5,
	"color": Color(0.9, 0.9, 0.92), "requires": [], "fixed_paint": true,
	# A real marked car rather than a white box: the model comes with its own
	# bullbar, numberplates and lightbar on the roof.
	"model": "res://assets/Cars/PoliceCar/scene.gltf",
	"model_scale": 1.35, "model_yaw": PI * 0.5,
	"body_size": Vector3(2.83, 2.11, 7.04), "body_y": 1.05,
	"model_map": {
		"hood": ["Illinois90_Hood"],
		"trunk": ["Illinois90_Trunkdoor"],
		"wheel_fr": ["Illinois90_WheelStock_FR"],
		"wheel_fl": ["Illinois90_WheelStock_FL"],
		"wheel_rr": ["Illinois90_WheelStock_RR"],
		"wheel_rl": ["Illinois90_WheelStock_RL"],
		"door_r": ["Illinois90_Glass_Passenger"],
		"door_l": ["Illinois90_glass_Driver"],
	},
	"model_split": [
		{"node": "Illinois90_Body_Illinois90", "regions": {
			"door_r": AABB(Vector3(0.887, 0.527, -1.281), Vector3(0.717, 0.725, 1.720)),
			"door_l": AABB(Vector3(-1.603, 0.527, -1.281), Vector3(0.717, 0.725, 1.720)),
		}},
		{"node": "Illinois90_Interior", "regions": {
			"door_r": AABB(Vector3(0.887, 0.527, -1.281), Vector3(0.717, 0.725, 1.720)),
			"door_l": AABB(Vector3(-1.603, 0.527, -1.281), Vector3(0.717, 0.725, 1.720)),
			"seat_r": AABB(Vector3(0.047, 0.577, -0.801), Vector3(0.844, 1.094, 1.280)),
			"seat_l": AABB(Vector3(-0.890, 0.577, -0.801), Vector3(0.844, 1.094, 1.280)),
		}},
		{"node": "Illinois90_Bottom", "regions": {
			"mirror_r": AABB(Vector3(1.253, 1.252, -0.951), Vector3(0.350, 0.240, 0.400)),
			"mirror_l": AABB(Vector3(-1.603, 1.252, -0.951), Vector3(0.350, 0.240, 0.400)),
			"door_r": AABB(Vector3(0.887, 0.527, -1.281), Vector3(0.717, 0.725, 1.720)),
			"door_l": AABB(Vector3(-1.603, 0.527, -1.281), Vector3(0.717, 0.725, 1.720)),
			"engine": AABB(Vector3(-0.939, 0.386, -2.605), Vector3(1.877, 0.900, 1.319)),
		}},
	],
	"rig": {
		"car": {"scale": Vector3(1.220, 1.259, 1.463), "offset": Vector3(0.000, 0.000, -0.101)},
		"door": {"scale": Vector3(1.220, 1.186, 1.009), "offset": Vector3(0.040, -0.130, -0.161)},
		"jimmy": {"scale": Vector3(1.220, 1.291, 1.009), "offset": Vector3(0.040, 0.000, -0.283)},
		"wheel": {"scale": Vector3(1.000, 1.035, 1.330), "offset": Vector3(0.044, 0.000, -0.128)},
		"hood": {"scale": Vector3(1.360, 1.095, 1.009), "offset": Vector3(0.000, 0.274, -0.121)},
		"trunk": {"scale": Vector3(1.370, 1.095, 0.596), "offset": Vector3(0.000, 0.241, 1.805)},
		"seat": {"scale": Vector3(1.250, 0.599, 1.261), "offset": Vector3(0.000, 0.000, 0.000)},
		"mirror": {"scale": Vector3(1.220, 1.095, 1.009), "offset": Vector3(0.040, -0.044, 0.272)},
		"engine": {"scale": Vector3(1.290, 1.095, 1.328), "offset": Vector3(0.000, 0.055, 0.000)},
		"hotwire": {"scale": Vector3(1.000, 1.095, 1.009), "offset": Vector3(0.000, -0.230, -0.081)},
		"jack": {"scale": Vector3(1.150, 1.095, 1.362), "offset": Vector3(0.000, 0.000, 0.000)},
	},
	"parts": ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "hood", "trunk", "mirror_r", "mirror_l", "door_r", "door_l", "seat_r", "seat_l", "engine"],
}

var units: Array[PoliceCar] = []
## How long out of their sight it takes to shake a star off.
const ESCAPE_SECS := 7.0
var _escape_timer: float = 0.0
var _in_sight := false
var _spawn_cd: float = 0.0

func _ready() -> void:
	add_to_group("police_dispatch")
	GameState.wanted_changed.connect(_on_wanted_changed)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	units = units.filter(func(u): return is_instance_valid(u))

	if GameState.wanted == 0:
		if not units.is_empty():
			clear_pursuit()
		return

	_spawn_cd -= delta
	var wanted_units := GameState.wanted
	if units.size() < wanted_units and _spawn_cd <= 0.0:
		_spawn_unit(player)
		_spawn_cd = 3.0

	# escape: nobody within detection range long enough -> drop a star
	var nearest := 9999.0
	for u in units:
		nearest = minf(nearest, u.global_position.distance_to(player.global_position))
	_in_sight = nearest <= 55.0
	if not _in_sight:
		_escape_timer += delta
		if _escape_timer > ESCAPE_SECS:
			_escape_timer = 0.0
			GameState.set_wanted(GameState.wanted - 1)
			var hud := get_tree().get_first_node_in_group("hud")
			if hud:
				if GameState.wanted == 0:
					hud.toast("YOU LOST THEM", "Get that thing to the shop.")
				else:
					hud.toast("HEAT DROPPING", "Keep moving.")
	else:
		_escape_timer = maxf(0.0, _escape_timer - delta * 2.0)

## How far along the escape is, 0..1. Fills while nobody can see you and a
## star comes off when it tops out.
func cooling() -> float:
	return clampf(_escape_timer / ESCAPE_SECS, 0.0, 1.0)

## Has any unit got eyes on the player right now?
func in_sight() -> bool:
	return _in_sight

## Called when the player does something loud.
func dispatch() -> void:
	_spawn_cd = 0.0

## A patrol car already on the road joins the pursuit, so units can arrive
## from traffic rather than appearing out of nowhere behind you.
func adopt(where: Transform3D) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	units = units.filter(func(u): return is_instance_valid(u))
	if player == null or units.size() >= GameState.wanted:
		return false
	var cop := PoliceCar.new()
	cop.setup(COP_DATA.duplicate(true))
	get_parent().add_child(cop)
	cop.global_transform = where
	cop.target = player
	cop.aggression = 1.0 + 0.12 * float(GameState.wanted)
	units.append(cop)
	return true

func clear_pursuit() -> void:
	for u in units:
		if is_instance_valid(u):
			u.queue_free()
	units.clear()
	for o in get_tree().get_nodes_in_group("police_foot"):
		var officer := o as PoliceOfficer
		if officer and officer.car != null:
			officer.queue_free()
	_escape_timer = 0.0

func _on_wanted_changed(stars: int) -> void:
	for u in units:
		if is_instance_valid(u):
			u.aggression = 1.0 + 0.12 * float(stars)
	if stars > 0:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.toast("POLICE ALERT", "Wanted level %d." % stars)

func _spawn_unit(player: Node3D) -> void:
	var cop := PoliceCar.new()
	cop.setup(COP_DATA.duplicate(true))
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0, sin(angle)) * randf_range(38.0, 55.0)
	get_parent().add_child(cop)
	cop.global_position = player.global_position + offset + Vector3.UP * 0.6
	cop.target = player
	cop.aggression = 1.0 + 0.12 * float(GameState.wanted)
	units.append(cop)
