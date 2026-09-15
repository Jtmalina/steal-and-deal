extends Node3D
class_name DayNight
# ============================================================
#  The sun going round, and what that costs you.
#
#  Drives the light, the sky and the fog off GameState's clock,
#  and turns the street lamps on when it gets dark. Only the
#  handful of lamps nearest the player are ever real lights --
#  there are a couple of hundred of them out there and the
#  renderer will not thank you for all of them at once.
# ============================================================

## How many street lamps are lit at once, and how often we work out which.
const POOL := 14
const RESHUFFLE := 0.6
const LAMP_RANGE := 19.0

var sun: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial

var _lamps: Array[OmniLight3D] = []
var _next_shuffle := 0.0

const DAY_SUN := Color(1.0, 0.94, 0.82)
const DUSK_SUN := Color(1.0, 0.62, 0.38)
const NIGHT_SUN := Color(0.42, 0.52, 0.78)
const DAY_TOP := Color(0.25, 0.30, 0.42)
const NIGHT_TOP := Color(0.03, 0.04, 0.09)
const DAY_HORIZON := Color(0.55, 0.50, 0.45)
const NIGHT_HORIZON := Color(0.09, 0.10, 0.16)

func _ready() -> void:
	add_to_group("daynight")
	for i in POOL:
		var lamp := OmniLight3D.new()
		lamp.omni_range = LAMP_RANGE
		lamp.light_energy = 0.0
		lamp.light_color = Color(1.0, 0.88, 0.62)
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)

func _process(delta: float) -> void:
	var t := GameState.daylight()
	# the sun swings from low in the east to low in the west and then goes out
	sun.rotation_degrees.x = lerpf(-6.0, -62.0, sin(t * PI * 0.5))
	sun.rotation_degrees.y = lerpf(-160.0, -70.0, GameState.hour() / 24.0)
	sun.light_energy = maxf(0.06, t * 1.05)
	sun.light_color = NIGHT_SUN.lerp(DUSK_SUN, clampf(t * 2.5, 0.0, 1.0)).lerp(DAY_SUN, t)
	sun.shadow_enabled = t > 0.25

	env.ambient_light_energy = lerpf(0.10, 0.6, t)
	env.fog_light_color = Color(0.10, 0.11, 0.17).lerp(Color(0.55, 0.55, 0.6), t)
	env.fog_density = lerpf(0.010, 0.004, t)
	sky.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, t)
	sky.sky_horizon_color = NIGHT_HORIZON.lerp(DAY_HORIZON, t)
	sky.ground_horizon_color = NIGHT_HORIZON.lerp(Color(0.4, 0.38, 0.34), t)
	sky.ground_bottom_color = NIGHT_TOP.lerp(Color(0.15, 0.15, 0.14), t)

	_next_shuffle -= delta
	if _next_shuffle <= 0.0:
		_next_shuffle = RESHUFFLE
		_relight(t)

## Put the pool on whichever lamps are nearest to whoever is looking.
func _relight(daylight: float) -> void:
	var lit := 1.0 - clampf(daylight * 2.0, 0.0, 1.0)
	if lit <= 0.01 or StreetKit.lamps.is_empty():
		for lamp in _lamps:
			lamp.visible = false
		return
	var who := get_tree().get_first_node_in_group("player") as Node3D
	if who == null:
		return
	var here := who.global_position
	var near := StreetKit.lamps.duplicate()
	near.sort_custom(func(a: Vector3, b: Vector3):
		return a.distance_squared_to(here) < b.distance_squared_to(here))
	for i in _lamps.size():
		if i < near.size() and (near[i] as Vector3).distance_to(here) < 70.0:
			_lamps[i].global_position = near[i]
			_lamps[i].light_energy = 4.2 * lit
			_lamps[i].visible = true
		else:
			_lamps[i].visible = false
