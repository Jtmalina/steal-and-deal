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
#
#  The sky itself is shaders/sky.gdshader. This works out where
#  the sun and the moon are and hands it over.
# ============================================================

## How many street lamps are lit at once, and how often we work out which.
const POOL := 14
const RESHUFFLE := 0.6
const LAMP_RANGE := 19.0

## When the sun clears the rooftops and when it goes down behind them. The
## gameplay's idea of dark (GameState.daylight) runs a little behind, the way
## it stays light for a while after sunset.
const SUNRISE := 6.0
const SUNSET := 20.25
## How far south the sun leans, which sets how high it gets at noon.
const TILT := deg_to_rad(34.0)

const DAY_SUN := Color(1.0, 0.94, 0.82)
const DUSK_SUN := Color(1.0, 0.58, 0.32)
const MOON := Color(0.52, 0.62, 0.9)
const DAY_AMBIENT := Color(0.40, 0.42, 0.48)
const DUSK_AMBIENT := Color(0.34, 0.27, 0.27)
const NIGHT_AMBIENT := Color(0.085, 0.095, 0.15)
const DAY_FOG := Color(0.60, 0.67, 0.76)
const DUSK_FOG := Color(0.58, 0.43, 0.36)
const NIGHT_FOG := Color(0.07, 0.075, 0.11)

var sun: DirectionalLight3D
var env: Environment
var sky: ShaderMaterial

var _lamps: Array[OmniLight3D] = []
var _next_shuffle := 0.0
var _lit_from := Vector3.INF
var _drift := 0.0

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

## Which way the sun is from anywhere in the city at this hour: up out of the
## east, over the south, down into the west, and round under the ground all
## night.
static func sun_towards(hour: float) -> Vector3:
	var day_len := SUNSET - SUNRISE
	var turn: float
	var h := fposmod(hour - SUNRISE, 24.0)
	if h <= day_len:
		turn = h / day_len * PI
	else:
		turn = PI + (h - day_len) / (24.0 - day_len) * PI
	return Vector3(cos(turn), sin(turn) * cos(TILT), sin(turn) * sin(TILT)).normalized()

## The moon keeps roughly opposite hours, a little off so it is not a mirror.
static func moon_towards(hour: float) -> Vector3:
	var m := sun_towards(hour + 12.6)
	return Vector3(m.x, m.y, -m.z * 0.6).normalized()

func _process(delta: float) -> void:
	var t := GameState.daylight()
	var hour := GameState.hour()
	var to_sun := sun_towards(hour)
	var to_moon := moon_towards(hour)

	# the sky: lit by how high the sun is, reddened while it is low
	var lift := to_sun.y
	var day := smoothstep(-0.12, 0.25, lift)
	var dusk := clampf(1.0 - absf(lift - 0.02) / 0.22, 0.0, 1.0)
	var night := 1.0 - smoothstep(-0.18, 0.02, lift)
	_drift += delta * (0.004 + 0.0015 * sin(hour * 0.7))

	if sky != null:
		sky.set_shader_parameter("sun_dir", to_sun)
		sky.set_shader_parameter("moon_dir", to_moon)
		sky.set_shader_parameter("day", day)
		sky.set_shader_parameter("dusk", dusk)
		sky.set_shader_parameter("night", night)
		sky.set_shader_parameter("drift", _drift)
		sky.set_shader_parameter("star_turn", hour / 24.0 * TAU)

	# one light does both jobs: the sun while it is up, the moon once it is not.
	# The swap happens with both of them on the horizon and nearly out, so it
	# never shows.
	var by_sun := lift > -0.03
	var from := to_sun if by_sun else to_moon
	sun.global_basis = Basis.looking_at(-from, Vector3.UP)
	if by_sun:
		var sun_up := smoothstep(-0.03, 0.12, lift)
		sun.light_energy = maxf(0.02, sun_up * maxf(t, 0.35) * 1.1)
		sun.light_color = DUSK_SUN.lerp(DAY_SUN, smoothstep(0.05, 0.4, lift))
	else:
		# a low moon throws long silly shadows; keep it up and faint
		var moon_up := smoothstep(0.0, 0.25, to_moon.y) * smoothstep(-0.03, -0.12, lift)
		sun.light_energy = 0.02 + moon_up * 0.17
		sun.light_color = MOON
	# no shadows off the moon: too faint to see, and at its angle the glass
	# on the towers comes out in acne
	sun.shadow_enabled = by_sun and sun.light_energy > 0.12

	env.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, t).lerp(DUSK_AMBIENT, dusk * 0.35 * t)
	env.ambient_light_energy = 1.0
	env.fog_light_color = NIGHT_FOG.lerp(DAY_FOG, day).lerp(DUSK_FOG, dusk * 0.5)
	env.fog_density = lerpf(0.009, 0.0035, t)

	# the windows in town come on as it gets dark
	RenderingServer.global_shader_parameter_set("city_night", 1.0 - clampf(t * 1.6, 0.0, 1.0))

	_next_shuffle -= delta
	# and straight away if the view has jumped -- a respawn, a camera cut --
	# rather than leave it in the dark until the next go round
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_squared_to(_lit_from) > 400.0:
		_next_shuffle = 0.0
	if _next_shuffle <= 0.0:
		if cam != null:
			_lit_from = cam.global_position
		_next_shuffle = RESHUFFLE
		_relight(t)

## The rooms people work in are lit day and night -- but only the few nearest
## the player are real lights. From further off the panel in the ceiling and
## the glass are enough.
const ROOMS_LIT := 5
const ROOM_RANGE := 55.0

func _light_rooms() -> void:
	# the rooms nearest whatever is looking, which is the player but for a
	# camera flown off somewhere on its own
	var cam := get_viewport().get_camera_3d()
	var rooms := Blocks.interior_lights
	if cam == null or rooms.is_empty():
		return
	var here := cam.global_position
	var near: Array[OmniLight3D] = []
	for l in rooms:
		if is_instance_valid(l):
			near.append(l)
	near.sort_custom(func(a: OmniLight3D, b: OmniLight3D):
		return a.global_position.distance_squared_to(here) < b.global_position.distance_squared_to(here))
	for i in near.size():
		near[i].visible = i < ROOMS_LIT and near[i].global_position.distance_to(here) < ROOM_RANGE

## Put the pool on whichever lamps are nearest to whoever is looking.
func _relight(daylight: float) -> void:
	_light_rooms()
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
