extends CanvasLayer
class_name HUD
# ============================================================
#  All UI, built in code. Readable > pretty.
# ============================================================

const CASH := Color(0.55, 1.0, 0.55)
const BAD := Color(1.0, 0.35, 0.3)
const GOLD := Color(1.0, 0.8, 0.2)

var player: Player = null
var world: World = null

var _root: Control
var _money_label: Label
var _info_label: Label
var _wanted_label: Label
var _prompt_label: Label
var _toast_box: VBoxContainer
var _compass: Compass
var _speed_label: Label
var _carry_label: Label
var _ammo_label: Label
var _health_bg: ColorRect
var _health_bar: ColorRect
var _crosshair: Control
var _belt: HBoxContainer
var _gear_label: Label
var _clock_label: Label
var _health_label: Label
var _map: MiniMap
var _arrest_box: Control
var _heat_box: Control
var _heat_stars: Array[ColorRect] = []
var _heat_bar: ColorRect
var _heat_note: Label
var _car_heat: Label
var _car_heat_bar: ColorRect
var _car_tag: Label3D = null
var _arrest_bar: ColorRect


# panels
var _panel: PanelContainer = null
var _panel_body: VBoxContainer = null
var _panel_kind := ""

# dismantle state
var _dis_vehicle: Vehicle = null
var _teardown: Teardown = null
var _focus: ColorRect = null

func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_money_label = _mk_label("$500", 34, CASH)
	_root.add_child(_money_label)
	_place(_money_label, 0, 0, 20, 14, 400, 40)

	_info_label = _mk_label("", 18, Color(0.85, 0.85, 0.85))
	_root.add_child(_info_label)
	_place(_info_label, 0, 0, 20, 56, 560, 50)

	_wanted_label = _mk_label("", 30, BAD)
	_wanted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_wanted_label)
	_place(_wanted_label, 0.5, 0, -180, 12, 360, 40)

	_prompt_label = _mk_label("", 22, Color(1, 1, 1))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt_label)
	_place(_prompt_label, 0.5, 1, -450, -156, 900, 40)

	_compass = Compass.new()
	_compass.player = player
	_root.add_child(_compass)
	_place(_compass, 0.5, 0, -230, 8, 460, 34)


	var hint := _mk_label("[WASD] move  [Shift] run  [Space] jump / handbrake  [E] interact  [F] exit car  [1-6] belt  [LMB] use  [R] reload  [H] help", 15, Color(0.7, 0.7, 0.7))
	_root.add_child(hint)
	_place(hint, 0, 1, 210, -30, 820, 24)

	_carry_label = _mk_label("", 19, Color(0.6, 1.0, 0.7))
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_carry_label)
	_place(_carry_label, 0.5, 1, -450, -124, 900, 28)

	_speed_label = _mk_label("", 40, Color(1, 1, 1))
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_speed_label)
	_place(_speed_label, 1, 1, -260, -112, 240, 48)

	_gear_label = _mk_label("", 18, Color(1, 0.85, 0.45))
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_gear_label)
	_place(_gear_label, 1, 1, -260, -66, 240, 26)

	_ammo_label = _mk_label("", 18, Color(1, 0.85, 0.45))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_ammo_label)
	_place(_ammo_label, 1, 1, -260, -44, 240, 26)

	_health_bg = ColorRect.new()
	_health_bg.color = Color(0.12, 0.05, 0.05, 0.85)
	_health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_health_bg)
	_place(_health_bg, 0, 1, 16, -224, 180, 18)
	_health_bar = ColorRect.new()
	_health_bar.color = Color(0.8, 0.25, 0.25)
	_health_bar.size = Vector2(180, 18)
	_health_bg.add_child(_health_bar)
	_health_label = _mk_label("", 13, Color(1, 1, 1))
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_health_label)
	_place(_health_label, 0, 1, 16, -224, 180, 18)

	# What the law thinks of you, under the money. Three stars, and a bar that
	# creeps across while nobody can see you -- fill it and a star drops off.
	_heat_box = Control.new()
	_heat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_box.visible = false
	_root.add_child(_heat_box)
	_place(_heat_box, 0, 0, 16, 96, 260, 46)
	var hl := _mk_label("WANTED", 15, Color(1, 0.45, 0.4))
	hl.size = Vector2(90, 20)
	_heat_box.add_child(hl)
	for i in 3:
		var star := ColorRect.new()
		star.size = Vector2(18, 18)
		star.position = Vector2(84 + 23 * float(i), 1)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heat_box.add_child(star)
		_heat_stars.append(star)
	var hbg := ColorRect.new()
	hbg.color = Color(0.22, 0.09, 0.09, 0.9)
	hbg.size = Vector2(154, 6)
	hbg.position = Vector2(0, 24)
	hbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_box.add_child(hbg)
	_heat_bar = ColorRect.new()
	_heat_bar.color = Color(0.5, 0.85, 1.0)
	_heat_bar.size = Vector2(0, 6)
	hbg.add_child(_heat_bar)
	_heat_note = _mk_label("", 12, Color(0.75, 0.78, 0.82))
	_heat_note.size = Vector2(240, 18)
	_heat_note.position = Vector2(0, 30)
	_heat_box.add_child(_heat_note)

	# and the same again for whatever you are sat in, because a car is on the
	# list whether or not you are
	_car_heat = _mk_label("", 15, Color(1.0, 0.65, 0.3))
	_root.add_child(_car_heat)
	_place(_car_heat, 0, 0, 16, 146, 380, 20)
	var chbg := ColorRect.new()
	chbg.color = Color(0.24, 0.14, 0.05, 0.9)
	chbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(chbg)
	_place(chbg, 0, 0, 16, 166, 154, 5)
	_car_heat_bar = ColorRect.new()
	_car_heat_bar.color = Color(1.0, 0.6, 0.2)
	_car_heat_bar.size = Vector2(0, 5)
	chbg.add_child(_car_heat_bar)
	_car_heat.visible = false
	chbg.visible = false
	_car_heat.set_meta("bg", chbg)

	# they do not just touch you and you are gone -- it takes them a moment,
	# and you can see it happening and still run for it
	_arrest_box = Control.new()
	_arrest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrest_box.visible = false
	_root.add_child(_arrest_box)
	_place(_arrest_box, 0.5, 0.5, -190, 110, 380, 46)
	var abg := ColorRect.new()
	abg.color = Color(0.10, 0.03, 0.03, 0.86)
	abg.size = Vector2(380, 46)
	abg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrest_box.add_child(abg)
	var alab := _mk_label("ARRESTING", 19, Color(1, 0.55, 0.45))
	alab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alab.size = Vector2(380, 24)
	alab.position = Vector2(0, 3)
	_arrest_box.add_child(alab)
	var abar_bg := ColorRect.new()
	abar_bg.color = Color(0.25, 0.1, 0.1, 0.9)
	abar_bg.size = Vector2(348, 10)
	abar_bg.position = Vector2(16, 29)
	abar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrest_box.add_child(abar_bg)
	_arrest_bar = ColorRect.new()
	_arrest_bar.color = Color(1.0, 0.4, 0.3)
	_arrest_bar.size = Vector2(0, 10)
	abar_bg.add_child(_arrest_bar)

	# and the neighbourhood underneath it
	_map = MiniMap.new()
	_map.player = player
	_root.add_child(_map)
	_place(_map, 0, 1, 16, -200, 180, 180)

	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	_root.add_child(_crosshair)
	_place(_crosshair, 0.5, 0.5, -11, -11, 22, 22)
	for spec in [[0, 8, 2, 6], [0, -14, 2, 6], [8, 0, 6, 2], [-14, 0, 6, 2]]:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.8)
		tick.position = Vector2(11 + spec[0], 11 + spec[1])
		tick.size = Vector2(spec[2], spec[3])
		_crosshair.add_child(tick)

	_belt = HBoxContainer.new()
	_belt.add_theme_constant_override("separation", 6)
	_belt.alignment = BoxContainer.ALIGNMENT_CENTER
	_belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_belt)
	_place(_belt, 0.5, 1, -300, -96, 600, 58)

	_clock_label = _mk_label("", 30, Color(0.95, 0.93, 0.8))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_clock_label)
	_place(_clock_label, 1, 0, -180, 12, 164, 40)

	_toast_box = VBoxContainer.new()
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)
	_place(_toast_box, 1, 0, -440, 60, 420, 320)

	_focus = _make_focus_blur()
	_root.add_child(_focus)

	_teardown = Teardown.new()
	_root.add_child(_teardown)

	GameState.money_changed.connect(func(_m): _refresh_top())
	GameState.wanted_changed.connect(func(_w): _refresh_top())
	GameState.skill_changed.connect(_refresh_top)
	GameState.inventory_changed.connect(_refresh_top)
	GameState.health_changed.connect(func(_h): _refresh_vitals())
	GameState.kit_changed.connect(_refresh_belt)
	GameState.notify.connect(func(t, b): toast(t, b))
	_refresh_top()
	_refresh_vitals()
	GameState.sync_belt()
	_refresh_belt()
	call_deferred("open_help")

## The readouts that change on their own rather than on a signal: the clock,
## the health bar, the compass, what is in your hands and how fast you are
## going. Without this they only ever updated when something else happened.
func _process(_delta: float) -> void:
	_refresh_vitals()
	_update_carry()
	_update_speedo()
	refresh_heat()
	refresh_car_heat()


## Explicit anchor + offset placement. Setting `position` on an anchored Control
## behaves differently for plain Controls and containers -- this does not.
## The close-up work happens in the middle of the screen, so everything else
## goes soft: a full-screen pass that blurs and dims outwards from the centre.
## It sits under the rest of the HUD, so the labels stay sharp.
func _make_focus_blur() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
// how much of the middle stays sharp, and how far the fade to soft runs
uniform float clear_to : hint_range(0.0, 1.0) = 0.30;
uniform float feather : hint_range(0.01, 1.0) = 0.34;
uniform float spread : hint_range(0.0, 0.05) = 0.007;
uniform float dim : hint_range(0.0, 1.0) = 0.42;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// squashed on Y so the sharp patch is a circle on a wide screen
	vec2 off = (SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.6);
	float m = smoothstep(clear_to, clear_to + feather, length(off) * 2.0) * amount;
	vec3 sharp = texture(screen, SCREEN_UV).rgb;
	if (m < 0.004) {
		COLOR = vec4(sharp, 1.0);
	} else {
		vec2 taps[8] = {vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
			vec2(0.7, 0.7), vec2(-0.7, 0.7), vec2(0.7, -0.7), vec2(-0.7, -0.7)};
		vec3 soft = sharp;
		float r = spread * m;
		for (int i = 0; i < 8; i++) {
			soft += texture(screen, SCREEN_UV + taps[i] * r).rgb;
			soft += texture(screen, SCREEN_UV + taps[i] * r * 0.5).rgb;
		}
		soft /= 17.0;
		COLOR = vec4(mix(sharp, soft * (1.0 - dim * m), m), 1.0);
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	return rect

## Fade the surround in or out. Called either side of any close-up job.
func set_focus_blur(on: bool) -> void:
	if _focus == null:
		return
	var mat := _focus.material as ShaderMaterial
	if on:
		_focus.visible = true
		mat.set_shader_parameter("amount", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("amount", v),
		0.0 if on else 1.0, 1.0 if on else 0.0, 0.35)
	if not on:
		tw.tween_callback(func(): _focus.visible = false)

func _place(c: Control, ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox + w
	c.offset_top = oy
	c.offset_bottom = oy + h

# ------------------------------------------------------------
#  Widgets
# ------------------------------------------------------------
func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _refresh_top() -> void:
	_money_label.text = "$%s" % _comma(GameState.money)
	# what is in the truck and what is on the garage floor are both things you
	# find out by going and looking at them
	_info_label.text = "Skill Lv%d (%d/%d xp)
Garage T%d" % [
		GameState.theft_level, GameState.theft_xp, GameState.xp_for_next(),
		GameState.garage_level]
	if GameState.wanted > 0:
		var stars := ""
		for i in 3:
			stars += "*" if i < GameState.wanted else "-"
		_wanted_label.text = "POLICE ALERT  %s" % stars
	else:
		_wanted_label.text = ""

## The belt across the bottom of the screen. One box per loop, the one in your
## hand picked out, numbered for the keys that select them.
func _refresh_belt() -> void:
	for c in _belt.get_children():
		c.queue_free()
	for i in GameState.hotbar.size():
		var id := String(GameState.hotbar[i])
		var item: Dictionary = GameData.ITEMS.get(id, {})
		var mine: bool = i == GameState.selected

		var slot := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.09, 0.11, 0.9) if not mine else Color(0.18, 0.15, 0.06, 0.95)
		sb.border_color = GOLD if mine else Color(0.35, 0.35, 0.38)
		sb.set_border_width_all(3 if mine else 2)
		sb.set_content_margin_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		slot.custom_minimum_size = Vector2(92, 46)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var top := _mk_label("%d" % (i + 1), 12, Color(0.65, 0.65, 0.68))
		col.add_child(top)
		var name_col: Color = item.get("colour", Color(0.4, 0.4, 0.42))
		if not item.is_empty():
			name_col = name_col.lightened(0.35)
		var lab := _mk_label(String(item.get("name", "-")), 15, name_col)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lab)
		slot.add_child(col)
		_belt.add_child(slot)

## Health bar, ammo, and a crosshair once you are carrying something to aim.
func _refresh_vitals() -> void:
	var kind := String(GameState.held_item().get("kind", ""))
	# the health bar never goes away: it is the one thing worth a glance
	_health_bar.size.x = 180.0 * clampf(float(GameState.health) / 100.0, 0.0, 1.0)
	_health_label.text = "%d" % GameState.health
	_clock_label.text = GameState.clock_text()
	_clock_label.add_theme_color_override("font_color",
		Color(0.55, 0.62, 0.95) if GameState.is_dark() else Color(0.95, 0.93, 0.8))
	_health_bar.color = Color(0.8, 0.25, 0.25) if GameState.health > 35 else Color(1.0, 0.45, 0.15)
	var gun := GameState.held_weapon()
	_ammo_label.text = ("%s  %d / %d" % [String(gun.get("name", "GUN")).to_upper(),
		GameState.ammo, int(gun.get("clip", 0))]) if not gun.is_empty() else ""
	_crosshair.visible = kind in ["gun", "melee"] and player != null and not input_blocked()

## Is something already in front of the player that owns [Esc]? A teardown rig
## walks away on it and an open panel closes on it, so the pause menu only gets
## the key when neither of those is up.
func busy_with_panel() -> bool:
	return _panel != null or (_teardown != null and _teardown.active)

func input_blocked() -> bool:
	return _panel != null or (_teardown != null and _teardown.active) or (player != null and player.input_locked)

func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

func set_prompt(text: String) -> void:
	if (_teardown and _teardown.active) or _panel:
		return
	_prompt_label.text = text

func toast(title: String, body: String) -> void:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.88)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_child(_mk_label(title, 20, GOLD))
	if body != "":
		var b := _mk_label(body, 16, Color(0.9, 0.9, 0.9))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 380
		v.add_child(b)
	box.add_child(v)
	_toast_box.add_child(box)
	if _toast_box.get_child_count() > 5:
		_toast_box.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)

# ------------------------------------------------------------
#  Breaking in: the jimmy, then the hotwire. Both run on the same
#  hands-on rig as the teardown does.
# ------------------------------------------------------------
func start_breakin(v: Vehicle, cb: Callable) -> void:
	_begin_teardown(v, "JIMMYING THE %s" % String(v.data.name).to_upper(),
		GameData.JIMMY_STAGES, func(ok: bool, _q: float): cb.call(v, ok))

## Stars lit, and how close you are to shaking one off. `cooling` is 0..1.
func refresh_heat() -> void:
	if _heat_box == null:
		return
	var stars := GameState.wanted
	_heat_box.visible = stars > 0
	if stars <= 0:
		return
	for i in _heat_stars.size():
		_heat_stars[i].color = (Color(1.0, 0.75, 0.2) if i < stars
			else Color(0.28, 0.24, 0.22, 0.8))
	var cooling := 0.0
	var seen := false
	for d in get_tree().get_nodes_in_group("police_dispatch"):
		cooling = float(d.cooling())
		seen = bool(d.in_sight())
	_heat_bar.size.x = 154.0 * clampf(cooling, 0.0, 1.0)
	_heat_bar.color = Color(1.0, 0.45, 0.35) if seen else Color(0.5, 0.85, 1.0)
	_heat_note.text = ("they can see you" if seen
		else "out of sight - keep going and a star drops")

## How hot the car under you is, and a tag over the nearest hot car when you
## are stood outside it -- so you can tell which one on the ramp is the problem.
func refresh_car_heat() -> void:
	if _car_heat == null or player == null or not is_instance_valid(player):
		return
	var bg := _car_heat.get_meta("bg") as ColorRect
	var ride := player.current_vehicle as Vehicle
	var show: Vehicle = ride
	if show == null:
		# nothing under you: flag the nearest hot car instead
		var best := 14.0
		for n in get_tree().get_nodes_in_group("vehicle"):
			var v := n as Vehicle
			if v == null or v.heat_now() <= 0.01:
				continue
			var d := v.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				show = v
	var hot: float = show.heat_now() if show != null else 0.0
	_car_heat.visible = hot > 0.01
	bg.visible = hot > 0.01
	if hot > 0.01:
		_car_heat.text = "%s IS HOT - %s" % [String(show.data.get("name", "CAR")).to_upper(),
			show.heat_advice()]
		_car_heat_bar.size.x = 154.0 * clampf(hot, 0.0, 1.0)
		_car_heat_bar.color = Color(1.0, 0.35, 0.2) if hot > 0.55 else Color(1.0, 0.7, 0.25)
	_tag_hot_car(show if ride == null else null)

## A marker floating over a hot car you are stood next to.
func _tag_hot_car(v: Vehicle) -> void:
	if v == null or v.heat_now() <= 0.01:
		if _car_tag != null and is_instance_valid(_car_tag):
			_car_tag.queue_free()
		_car_tag = null
		return
	if _car_tag == null or not is_instance_valid(_car_tag):
		_car_tag = Label3D.new()
		_car_tag.font_size = 46
		_car_tag.pixel_size = 0.004
		_car_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_car_tag.no_depth_test = true
		_car_tag.outline_size = 14
		get_tree().current_scene.add_child(_car_tag)
	if _car_tag.get_parent() != v:
		_car_tag.reparent(v, false)
	_car_tag.position = Vector3(0, float((v.data.get("body_size", Vector3(2, 1.9, 4.4)) as Vector3).y) + 0.5, 0)
	_car_tag.modulate = Color(1.0, 0.35, 0.2) if v.heat_now() > 0.55 else Color(1.0, 0.72, 0.25)
	_car_tag.text = "HOT  %d%%" % int(round(v.heat_now() * 100.0))

## Sights up: hide the clutter that is in the way of them.
func set_aiming(on: bool) -> void:
	if _crosshair:
		_crosshair.visible = on or String(GameState.held_item().get("kind", "")) == "gun"

## How far along they are with putting you in the car. -1 to take it away.
func show_arrest(progress: float) -> void:
	if _arrest_box == null:
		return
	if progress < 0.0:
		_arrest_box.visible = false
		return
	_arrest_box.visible = true
	_arrest_bar.size.x = 348.0 * clampf(progress, 0.0, 1.0)

## Whatever rig is up, pulled down without telling it whether it went well --
## because it did not go either way, it was interrupted. Returns the car it
## had hold of, if any.
func cancel_minigame() -> Vehicle:
	if _teardown == null or not _teardown.active:
		return null
	return _teardown.cancel()

## Taking one off whoever is driving it. No tools, no lock, just them.
func start_carjack(v: Vehicle, cb: Callable) -> void:
	_begin_teardown(v, "PULLING THEM OUT OF THE %s" % String(v.data.name).to_upper(),
		GameData.carjack_stages(v.data), func(ok: bool, _q: float): cb.call(v, ok), 1.0, "carjack")

func start_hotwire(v: Vehicle, cb: Callable) -> void:
	_begin_teardown(v, "HOTWIRING THE %s" % String(v.data.name).to_upper(),
		GameData.HOTWIRE_STAGES, func(ok: bool, _q: float): cb.call(v, ok))

## Speed and gear, so a shift reads as a shift rather than a stutter.
## What is in your hands right now.
func _update_carry() -> void:
	if player == null or player.carrying == null:
		if _carry_label:
			_carry_label.text = ""
		return
	_carry_label.text = "CARRYING: %s ($%d)     [G] put it down" % [
		player.carrying.part_name, player.carrying.value]

func _update_speedo() -> void:
	var v: Vehicle = player.current_vehicle if player else null
	if v == null or not is_instance_valid(v):
		_speed_label.text = ""
		_gear_label.text = ""
		return
	_speed_label.text = "%d km/h" % int(round(absf(v.speed) * 3.6))
	if v.speed < -0.5:
		_gear_label.text = "REVERSE"
	else:
		_gear_label.text = "GEAR %d  of %d" % [v.gear + 1, Vehicle.GEAR_PULL.size()]

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if _teardown and _teardown.active:
		return
	if key == KEY_ESCAPE and _panel:
		close_panel()
		get_viewport().set_input_as_handled()
	elif key == KEY_H and _panel == null:
		open_help()
	elif key == KEY_H and _panel_kind == "help":
		close_panel()
	elif key == KEY_F1:
		if _panel_kind == "debug":
			close_panel()
		else:
			open_debug()

# ------------------------------------------------------------
#  Panels
# ------------------------------------------------------------
func _open_panel(title: String, kind: String, width: float = 620.0) -> VBoxContainer:
	close_panel()
	_panel_kind = kind
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.96)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	_place(_panel, 0.5, 0.5, -width * 0.5, -310, width, 620)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, 560)
	_panel.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size.x = width - 24
	scroll.add_child(outer)

	var head := _mk_label(title, 30, GOLD)
	outer.add_child(head)
	var sub := _mk_label("[Esc] close", 14, Color(0.6, 0.6, 0.6))
	outer.add_child(sub)
	outer.add_child(HSeparator.new())

	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 6)
	outer.add_child(_panel_body)

	if player:
		player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prompt_label.text = ""
	return _panel_body

func close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	_panel_body = null
	_panel_kind = ""
	if player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _row(left: String, right: String, color: Color = Color(0.9, 0.9, 0.9)) -> HBoxContainer:
	var h := HBoxContainer.new()
	var a := _mk_label(left, 18, color)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_mk_label(right, 18, color))
	_panel_body.add_child(h)
	return h

func _button(text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	return b

# ---------------- the cheat drawer ----------------
## Everything you would otherwise have to play for. [F1], and it is only ever
## meant for trying things out: spawn a car to strip, a crowd to drive into, or
## the police, and hand yourself whatever money and skill the test needs.
func open_debug() -> void:
	var v := _open_panel("DEBUG", "debug", 760)
	_row("Cash $%s" % _comma(GameState.money),
		"Theft level %d (%d xp)" % [GameState.theft_level, GameState.theft_xp], GOLD)

	var money_row := HBoxContainer.new()
	for amount in [500, 5000, 50000]:
		money_row.add_child(_button("+$%s" % _comma(amount), func():
			GameState.add_money(amount)
			open_debug()))
	money_row.add_child(_button("+5 theft xp", func():
		GameState.add_theft_xp(5)
		open_debug()))
	v.add_child(money_row)

	v.add_child(HSeparator.new())
	v.add_child(_mk_label("SPAWN A CAR   (in front of you, locked)", 18, CASH))
	var grid := GridContainer.new()
	grid.columns = 3
	for def in GameData.VEHICLES:
		var id := String(def.id)
		grid.add_child(_button("%s (T%d)" % [def.name, int(def.tier)], func(): _debug_car(id, false)))
	v.add_child(grid)

	v.add_child(_mk_label("...or straight into a garage bay to strip", 18, CASH))
	var bays := GridContainer.new()
	bays.columns = 3
	for def in GameData.VEHICLES:
		var id := String(def.id)
		bays.add_child(_button("%s -> bay" % def.name, func(): _debug_car(id, true)))
	v.add_child(bays)

	v.add_child(HSeparator.new())
	v.add_child(_mk_label("PEOPLE", 18, CASH))
	var folk := HBoxContainer.new()
	folk.add_child(_button("1 pedestrian", func(): _debug_walkers(1, false)))
	folk.add_child(_button("6 pedestrians", func(): _debug_walkers(6, false)))
	folk.add_child(_button("1 officer on foot", func(): _debug_walkers(1, true)))
	folk.add_child(_button("Send a patrol car", func():
		GameState.raise_wanted(1)
		get_tree().call_group("police_dispatch", "dispatch")
		toast("DISPATCHED", "Somebody is on the way.")))
	v.add_child(folk)

	var stars := HBoxContainer.new()
	stars.add_child(_mk_label("Wanted %d   " % GameState.wanted, 18, BAD))
	stars.add_child(_button("+1 star", func():
		GameState.raise_wanted(1)
		open_debug()))
	stars.add_child(_button("Clear", func():
		GameState.set_wanted(0)
		get_tree().call_group("police_dispatch", "clear_pursuit")
		open_debug()))
	v.add_child(stars)

## Somewhere clear in front of the player to put a spawned thing.
func _debug_spot(out: float) -> Vector3:
	if player == null:
		return Vector3(0, 0, 0)
	var ahead: Vector3 = -player.pivot.global_transform.basis.z
	ahead.y = 0.0
	return player.global_position + ahead.normalized() * out

func _debug_car(id: String, to_bay: bool) -> void:
	if world == null:
		return
	var v: Vehicle = world.spawn_job(id) if to_bay else world.spawn_vehicle(id, _debug_spot(7.0))
	if v == null:
		toast("NO ROOM", "Every bay is full. Crush something.")
		return
	close_panel()
	toast("SPAWNED", "%s%s." % [v.data.name, " in the garage" if to_bay else " in front of you"])

func _debug_walkers(count: int, officer: bool) -> void:
	if world == null:
		return
	for i in count:
		var at := _debug_spot(6.0 + float(i) * 1.4)
		world.spawn_walker(at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), officer)
	close_panel()
	toast("SPAWNED", "%d %s." % [count, "officer(s)" if officer else "passer(s)-by"])

# ---------------- help ----------------
func open_help() -> void:
	var v := _open_panel("STEAL AND DEAL", "help", 700)
	var lines := [
		"You run a chop shop. It is not a good one. Yet.",
		"[F1] opens the debug drawer: spawn cars, people and police, and hand yourself money.",
		"",
		"0. Your BELT is along the bottom. [1]-[6] or the mouse wheel pick what is in your hand,",
		"   and that decides what [LMB] does. You start with two loops: a jimmy and a tire iron.",
		"   The COMPUTER in the garage orders new kit; the WORKBENCH is where you stow what you",
		"   are not carrying. Anything you order that will not fit on your belt is left on the bench.",
		"1. WALK the neighbourhood and find a parked car. Higher tier = more money, more heat.",
		"2. [E] to jimmy the door. Hold [LMB] on the jimmy handle, slide it along to swing the tip",
		"   the other way inside the door, and pull UP when the tip lights up green on a lock spot.",
		"   Miss and it clatters. And mind who is watching -- a copper on the pavement who can see",
		"   you at it will call it in himself.",
		"   clatters -- enough noise and you give up and the street has heard you.",
		"3. The door being open is not the same as it going anywhere. [E] again to HOTWIRE it: rip",
		"   the column shroud off, pull out the red, brown and yellow wires (the others will bite),",
		"   scrape each one back, twist ignition onto battery, then flash the starter across them.",
		"4. DRIVE it home. If the cops turn up, break line of sight and stay away until the stars drop.",
		"5. PULL INTO THE GARAGE (the yellow bay, north-west of the map) to turn the car into a job.",
		"6. [E] on the car in the bay. CRUSH IT WHOLE for bare-metal weight (fast, worst price,",
		"   and the price drops as parts come off) -- or PART IT OUT for about four times as much.",
		"7. Parting out is hands-on. The camera moves in on the car and you work with the MOUSE:",
		"   hold [LMB] on a bolt and turn the mouse ANTICLOCKWISE to wind it out; drag a connector",
		"   straight out slowly or the clip snaps; drag back and forth to saw; drag a freed part off",
		"   the car; drag the jack handle down and up to lift it.",
		"   Order matters: the hood comes off before you can reach the bay, the battery before the",
		"   engine, a door before the seat behind it. Wheels come off one corner at a time.",
		"8. Every part you pull lands IN YOUR HANDS. [G] puts it down anywhere in the yard.",
		"   Carry it to your truck and [E] to load it. The pickup holds most of one car, not all of it.",
		"9. DRIVE THE TRUCK to the yard (south-east) and sell what is in the back. Nobody buys",
		"   parts that are still sitting on your floor. With a tow hitch you can drag a whole junker",
		"   over and weigh it in as-is.",
		"10. There is a PISTOL on the computer. [LMB] fires, [R] reloads. The police draw at TWO",
		"   stars and above -- from the car if you will not pull over, on foot if you run. Shoot",
		"   one of them and you are on three stars immediately, and they do not forget it.",
		"   Anyone can be killed, not just police -- but if a single person sees you do it, it is",
		"   called in and you are on at least two stars. Check who is watching first.",
		"11. Spend the money at the COMPUTER: better jimmies, real tools, a bigger garage, a bigger",
		"   truck, and contacts who pay over the odds for what you specialise in.",
		"",
		"Controls: WASD move / drive, Shift sprint, E interact, F exit vehicle, H help, Esc free cursor.",
	]
	for l in lines:
		var lab := _mk_label(l, 18, Color(0.9, 0.9, 0.9))
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size.x = 650
		v.add_child(lab)
	v.add_child(_button("LET ME AT IT", close_panel))

# ---------------- stash ----------------
func open_stash() -> void:
	_open_panel("PARTS STASH", "stash")
	var loose := get_tree().get_nodes_in_group("loose_part").filter(
		func(n): return not (n as PartItem).damaged)
	var t := GameState.truck()

	if GameState.truck_impounded:
		_row("The truck is in the pound", "release fee $%s" % _comma(GameState.impound_fee()), BAD)
		_panel_body.add_child(HSeparator.new())
	_row("On the garage floor", "%d parts" % loose.size())
	if not loose.is_empty():
		var counts := {}
		var worth := 0
		for n in loose:
			var item := n as PartItem
			if item == null or item.damaged:
				continue
			counts[item.part_name] = int(counts.get(item.part_name, 0)) + 1
			worth += item.value
		for k in counts.keys():
			_row("   %s x%d" % [k, counts[k]], "")
		_row("   worth, roughly", "$%s" % _comma(worth), CASH)
	_panel_body.add_child(HSeparator.new())

	if t:
		_row("In the %s" % t.data.name, "%d / %d units" % [t.used(), t.capacity()])
		var cc := {}
		for c in t.cargo:
			cc[c.name] = int(cc.get(c.name, 0)) + 1
		for k in cc.keys():
			_row("   %s x%d" % [k, cc[k]], "")
		_row("   worth at the yard", "$%s" % _comma(GameState.cargo_value("scrap")), CASH)
		if t.towed:
			_row("   towing", "%s ($%s whole)" % [t.towed.data.name, _comma(t.towed.shell_value())], CASH)
	_panel_body.add_child(HSeparator.new())
	_row("Cars stolen", str(GameState.stats.stolen))
	_row("Cars delivered", str(GameState.stats.delivered))
	_row("Parts pulled", str(GameState.stats.parts))
	_row("Times busted", str(GameState.stats.busted))
	_row("Lifetime earnings", "$%s" % _comma(GameState.stats.earned))

# ---------------- scrap yard ----------------
func open_scrapyard() -> void:
	_open_panel("THE YARD", "scrap", 720)
	var t := GameState.truck()
	if t == null or t.global_position.distance_to(World.SCRAP_POS) > 26.0:
		_row("No truck on the weighbridge.", "", BAD)
		var why := "Load the parts into the truck back at the shop and drive them over. Nobody here is walking to your garage."
		if GameState.truck_impounded:
			why = "Your truck is in the city pound with the load still in it. Pay the fee on the computer, or go and take it back."
		var note := _mk_label(why, 15, Color(0.75, 0.75, 0.75))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 660
		_panel_body.add_child(note)
		_panel_body.add_child(_button("Leave", close_panel))
		return

	if t.cargo.is_empty() and t.towed == null:
		_row("The truck is empty. So is the conversation.", "")
		_panel_body.add_child(_button("Leave", close_panel))
		return

	if not t.cargo.is_empty():
		var counts := {}
		for c in t.cargo:
			counts[c.name] = int(counts.get(c.name, 0)) + 1
		for k in counts.keys():
			_row("%s x%d" % [k, counts[k]], "")
		_panel_body.add_child(HSeparator.new())
		for b in GameData.BUYERS:
			if not GameState.unlocked_buyers.has(b.id):
				continue
			var total := GameState.cargo_value(String(b.id))
			var box := VBoxContainer.new()
			var h := HBoxContainer.new()
			var n := _mk_label(String(b.name), 20, Color(1, 1, 1))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(_button("SELL  $%s" % _comma(total), _sell_to.bind(String(b.id))))
			box.add_child(h)
			var d := _mk_label(String(b.desc), 15, Color(0.72, 0.72, 0.72))
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 660
			box.add_child(d)
			box.add_child(HSeparator.new())
			_panel_body.add_child(box)
		var locked := []
		for b in GameData.BUYERS:
			if not GameState.unlocked_buyers.has(b.id):
				locked.append(String(b.name))
		if not locked.is_empty():
			var lk := _mk_label("Not on speaking terms yet: %s" % ", ".join(locked), 15, Color(0.65, 0.6, 0.55))
			lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lk.custom_minimum_size.x = 660
			_panel_body.add_child(lk)

	if t.towed and is_instance_valid(t.towed):
		_panel_body.add_child(HSeparator.new())
		var car := t.towed
		_row("On the hook", "%s" % car.data.name)
		_panel_body.add_child(_button("WEIGH THE WHOLE CAR IN  ->  $%s" % _comma(car.shell_value()), func():
			var paid := car.shell_value()
			t.unhitch()
			car.queue_free()
			if world:
				world.jobs.erase(car)
			GameState.add_money(paid)
			toast("WEIGHED IN", "The whole %s, gone, for $%s." % [car.data.name, _comma(paid)])
			close_panel()))
	_panel_body.add_child(_button("Leave", close_panel))

func _sell_to(buyer_id: String) -> void:
	var t := GameState.truck()
	if t == null:
		return
	var total := GameState.cargo_value(buyer_id)
	# anything on the board gets offered to whoever ordered it first, and they
	# pay their premium on top of what the yard gives you for the rest
	var bonus := 0
	for c in t.cargo:
		bonus += GameState.offer_to_board(String(c.part), String(c.get("from_id", "")))
	t.unload_all()
	GameState.add_money(total)
	toast("SOLD", "%s hands over $%s.%s" % [GameData.buyer_by_id(buyer_id).name,
		_comma(total), "  Orders paid another $%s." % _comma(bonus) if bonus > 0 else ""])
	close_panel()

## The board in the back of the shop: who wants what, off which car, by when.
func open_board() -> void:
	GameState.refresh_orders()
	_open_panel("THE BOARD", "board", 740)
	var hint := _mk_label("Standing orders. Bring the parts back in the truck and sell them anywhere -- whoever asked for them pays their share on top.", 14, Color(0.72, 0.72, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 680
	_panel_body.add_child(hint)
	_panel_body.add_child(HSeparator.new())
	for o: Dictionary in GameState.orders:
		var days := Orders.days_left(o)
		var head := _mk_label("$%s   -   %s" % [_comma(int(o.pay)), String(o.client)], 19, CASH)
		_panel_body.add_child(head)
		var what := _mk_label(Orders.describe(o), 15, Color(0.85, 0.85, 0.85))
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.custom_minimum_size.x = 680
		_panel_body.add_child(what)
		_panel_body.add_child(_mk_label("%.1f days left" % days, 14,
			Color(1.0, 0.5, 0.4) if days < 1.0 else Color(0.7, 0.7, 0.7)))
		_panel_body.add_child(HSeparator.new())

# ---------------- workbench / shop ----------------
## The dealer's stock. Kept separate from the shop panel because it is his
## list, not yours -- when he moves into a van this comes with him.
func open_arms() -> void:
	_open_panel("THE DEALER", "arms", 720)
	_row("Cash on hand", "$%s" % _comma(GameState.money), CASH)
	var hint := _mk_label("He does not take cards, he does not do refunds, and he has never seen you before.", 14, Color(0.72, 0.72, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 660
	_panel_body.add_child(hint)
	_panel_body.add_child(HSeparator.new())
	for gun: Dictionary in GameData.ARMS:
		var owned: bool = GameState.owned_items.has(String(gun.item))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var head := _mk_label("%s   -   $%s%s" % [String(gun.name), _comma(int(gun.price)),
			"   (bought)" if owned else ""], 18, Color(0.75, 0.78, 0.82) if owned else CASH)
		row.add_child(head)
		var note := _mk_label(String(gun.desc), 14, Color(0.7, 0.7, 0.7))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 660
		row.add_child(note)
		_panel_body.add_child(row)
		if not owned:
			_panel_body.add_child(_button("BUY THE %s" % String(gun.name).to_upper(),
				func():
					if not GameState.can_afford(int(gun.price)):
						toast("NOT ENOUGH", "He is not interested in an IOU.")
						return
					GameState.add_money(-int(gun.price))
					GameState.owned_items.append(String(gun.item))
					GameState.inventory_changed.emit()
					toast("BOUGHT", "%s. It is on the workbench." % String(gun.name))
					open_arms(),
				GameState.can_afford(int(gun.price))))
		_panel_body.add_child(HSeparator.new())

func open_shop() -> void:
	_open_panel("ORDERS", "shop", 760)
	_row("Cash on hand", "$%s" % _comma(GameState.money), CASH)
	var hint := _mk_label("Anything you order that will not fit on your belt is left on the workbench.", 14, Color(0.72, 0.72, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 700
	_panel_body.add_child(hint)
	_panel_body.add_child(HSeparator.new())

	# --- the truck is in the pound: nothing sells until it is not ---
	if GameState.truck_impounded:
		_panel_body.add_child(_mk_label("YOUR TRUCK IS IN THE CITY POUND", 20, BAD))
		var pound := _mk_label("Everything you have not sold is still in the back of it. Pay the fee and they will drop it off, or go and take it back the way you take anything else.", 15, Color(0.8, 0.75, 0.75))
		pound.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pound.custom_minimum_size.x = 700
		_panel_body.add_child(pound)
		_panel_body.add_child(_button("PAY THE RELEASE FEE  ->  $%s" % _comma(GameState.impound_fee()),
			func():
				var err := GameState.recover_truck()
				if err != "":
					toast("NO", err)
				else:
					toast("RELEASED", "It is back outside the shop.")
				open_shop(),
			GameState.can_afford(GameState.impound_fee())))
		_panel_body.add_child(HSeparator.new())

	# the day's work, written down
	_panel_body.add_child(_button("SAVE THE GAME", func():
		var err := SaveGame.write(world, player)
		if err != "":
			toast("NOT SAVED", err)
		else:
			toast("SAVED", "The shop, the truck and everything on the ramps.")))
	var stamp := SaveGame.stamp()
	if stamp != "":
		_row("Last save", stamp, Color(0.6, 0.6, 0.6))
	_panel_body.add_child(HSeparator.new())

	for up in GameData.UPGRADES:
		var owned := GameState.is_owned(up)
		var v := VBoxContainer.new()
		var h := HBoxContainer.new()
		var name_col := Color(0.5, 0.5, 0.5) if owned else Color(1, 1, 1)
		var n := _mk_label(up.name, 20, name_col)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		if owned:
			h.add_child(_mk_label("OWNED", 18, Color(0.5, 0.8, 0.5)))
		else:
			var afford := GameState.can_afford(int(up.price))
			h.add_child(_button("$%s" % _comma(int(up.price)), _buy.bind(up), afford))
		v.add_child(h)
		var d := _mk_label(up.desc, 15, Color(0.75, 0.75, 0.75))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 700
		v.add_child(d)
		v.add_child(HSeparator.new())
		_panel_body.add_child(v)

## The workbench: what is on you, and what is sat on the bench waiting.
func open_bench() -> void:
	_open_panel("WORKBENCH", "bench", 720)
	GameState.sync_belt()
	var used: int = GameState.hotbar.size() - GameState.hotbar.count("")
	_row("On your belt", "%d of %d loops" % [used, GameState.hotbar.size()], GOLD)
	var note := _mk_label("Whatever is in the loop you have selected is what is in your hand. Anything you are not carrying sits here until you want it.", 14, Color(0.72, 0.72, 0.72))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 660
	_panel_body.add_child(note)
	_panel_body.add_child(HSeparator.new())

	for i in GameState.hotbar.size():
		var id := String(GameState.hotbar[i])
		var h := HBoxContainer.new()
		if id == "":
			var e := _mk_label("%d.  (empty loop)" % (i + 1), 17, Color(0.55, 0.55, 0.58))
			e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(e)
		else:
			var item: Dictionary = GameData.ITEMS[id]
			var n := _mk_label("%d.  %s" % [i + 1, String(item.name)], 18, Color(1, 1, 1))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(_mk_label(String(item.blurb) + "   ", 14, Color(0.6, 0.6, 0.63)))
			h.add_child(_button("STOW", _bench_move.bind(id)))
		_panel_body.add_child(h)

	_panel_body.add_child(HSeparator.new())
	var stored := GameState.stored_items()
	_row("On the bench", "%d item(s)" % stored.size(), GOLD)
	if stored.is_empty():
		_row("   Nothing here. It is all on you.", "")
	for id in stored:
		var item: Dictionary = GameData.ITEMS[id]
		var h := HBoxContainer.new()
		var n := _mk_label(String(item.name), 18, Color(0.8, 0.8, 0.83))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(_mk_label(String(item.blurb) + "   ", 14, Color(0.6, 0.6, 0.63)))
		var room: bool = GameState.hotbar.has("")
		h.add_child(_button("PICK UP" if room else "belt full", _bench_move.bind(String(id)), room))
		_panel_body.add_child(h)
	_panel_body.add_child(_button("Close", close_panel))

func _bench_move(id: String) -> void:
	var err := GameState.toggle_on_belt(id)
	if err != "":
		toast("NO ROOM", err)
	open_bench()

func _buy(up: Dictionary) -> void:
	var err := GameState.buy(up)
	if err != "":
		toast("NO DEAL", err)
		return
	if String(up.id) == "pistol":
		GameState.ammo = int(GameData.WEAPONS.pistol.clip)
		toast("LOADED", "Twelve rounds. [LMB] fires, [R] reloads.")
	if GameData.ITEMS.has(String(up.get("tool", ""))):
		var id := String(up.tool)
		if GameState.carrying_item(id):
			toast("ON YOUR BELT", String(GameData.ITEMS[id].name))
		else:
			toast("LEFT ON THE BENCH", "No room on your belt. It is on the workbench.")
	if String(up.id).begins_with("belt"):
		toast("MORE LOOPS", "Belt is up to %d." % GameState.belt_slots())
	open_shop()

# ---------------- dismantle ----------------
func open_dismantle(v: Vehicle) -> void:
	_open_panel("CHOP SHOP - %s" % String(v.data.name).to_upper(), "dismantle", 760)
	_dis_vehicle = v
	_row("Condition", "%d%% overall" % int(v.average_condition() * 100.0))
	if v.heat_now() > 0.01:
		_row("Heat on this car", "%d%%  -  %s" % [int(v.heat_now() * 100.0), v.heat_advice()],
			Color(1.0, 0.6, 0.3))
	_row("Parts still on it", "%d  (worth $%s parted out)" % [v.parts_remaining.size(), _comma(v.estimated_value())], CASH)
	_row("On stands", "yes" if v.lifted else "no")
	_row("On your belt", GameState.belt_summary())
	_panel_body.add_child(HSeparator.new())

	# --- whatever is in your hands has to go somewhere before the next one ---
	if player and player.carrying:
		var held: PartItem = player.carrying
		_row("In your hands", "%s  ($%s)" % [held.part_name, _comma(held.value)], GOLD)
		var hands := HBoxContainer.new()
		hands.add_child(_button("Put it down here", func():
			player.drop_carried()
			open_dismantle(v)))
		var lorry := GameState.truck()
		var near: bool = lorry != null and lorry.global_position.distance_to(player.global_position) < 14.0
		hands.add_child(_button("Load it into the %s" % (lorry.data.name if lorry else "truck"), func():
			player.load_into_truck(lorry)
			open_dismantle(v)), near and lorry != null and lorry.can_take(held))
		_panel_body.add_child(hands)
		if not near:
			_row("", "the truck is too far off to load from here", BAD)
		_panel_body.add_child(HSeparator.new())

	# --- the lazy default: weigh it in whole ---
	var shell := v.shell_value()
	var lazy := _mk_label("SCRAP THE WHOLE CAR - bare metal, by weight (%d kg)" % int(v.mass_remaining()), 19, Color(1, 0.75, 0.4))
	_panel_body.add_child(lazy)
	var lazy_note := _mk_label("The crusher pays the least of anyone. Every part you pull first is worth more on its own, but the shell gets lighter and this price drops with it.", 14, Color(0.7, 0.7, 0.7))
	lazy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lazy_note.custom_minimum_size.x = 700
	_panel_body.add_child(lazy_note)
	_panel_body.add_child(_button("CRUSH IT NOW  ->  $%s" % _comma(shell), func():
		var paid := 0
		if world:
			paid = world.scrap_carcass(v)
		toast("WEIGHED IN", "The whole thing, gone, for $%s. Bay is free." % _comma(paid))
		close_panel()))
	_panel_body.add_child(HSeparator.new())

	# --- a respray, if there is a gun in the shop to do it with ---
	if GameState.has_shop_tool("spray_gun"):
		_panel_body.add_child(_mk_label("RESPRAY IT - a different colour is a different car", 19, Color(0.5, 0.8, 1.0)))
		var paint_note := _mk_label("Anybody looking for the car you took is looking for the colour it was. Worth a little on the sale, and it takes some of the heat off the job.", 14, Color(0.7, 0.7, 0.7))
		paint_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paint_note.custom_minimum_size.x = 700
		_panel_body.add_child(paint_note)
		var swatches := HBoxContainer.new()
		for colour: Color in GameData.PAINTS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(46, 34)
			var style := StyleBoxFlat.new()
			style.bg_color = colour
			b.add_theme_stylebox_override("normal", style)
			b.add_theme_stylebox_override("hover", style)
			b.pressed.connect(func():
				if v.data.get("color", Color.BLACK) == colour:
					toast("IT IS THAT COLOUR", "Pick a different one.")
					return
				v.repaint(colour)
				v.condition = minf(1.0, v.condition + 0.03)
				GameState.set_wanted(maxi(0, GameState.wanted - 1))
				Sfx.play("car_handbrake", v.global_position, -4.0)
				toast("RESPRAYED", "It is not the car anybody is looking for any more.")
				open_dismantle(v))
			swatches.add_child(b)
		_panel_body.add_child(swatches)
		_panel_body.add_child(HSeparator.new())

	# --- changed your mind: it is still a car, and it still drives ---
	var rolls := v.can_roll()
	_panel_body.add_child(_button("TAKE IT BACK OFF THE RAMP AND DRIVE IT" if rolls
		else "TAKE IT BACK OFF THE RAMP  (needs all four wheels on)", func():
			if world == null or not world.release_from_bay(v):
				return
			close_panel()
			if player != null and is_instance_valid(player):
				player.enter_vehicle(v)), rolls)
	_panel_body.add_child(HSeparator.new())

	# --- or just drag the whole thing to the yard ---
	var truck := GameState.truck()
	if truck and truck.can_tow(v) and truck.global_position.distance_to(v.global_position) < 22.0:
		_panel_body.add_child(_button("HITCH IT TO THE TRUCK AND HAUL IT WHOLE  (~$%s)" % _comma(v.shell_value()), func():
			truck.hitch(v)
			toast("ON THE HOOK", "Drive it to the yard and weigh the whole thing in.")
			close_panel()))
		_panel_body.add_child(HSeparator.new())
	elif GameState.has_shop_tool("hitch") and truck and int(v.data.tier) > GameState.tow_tier():
		_row("Too heavy to tow", "hitch handles tier %d and under" % GameState.tow_tier(), BAD)
		_panel_body.add_child(HSeparator.new())

	# --- get it in the air ---
	if not v.lifted:
		if GameState.can_lift():
			_panel_body.add_child(_button("JACK THE CAR UP (needed for wheels and the transmission)", _start_jack.bind(v)))
		else:
			_row("No jack, no lift", "wheels and transmission stay bolted on", BAD)
		_panel_body.add_child(HSeparator.new())

	# --- part by part ---
	if v.parts_remaining.is_empty():
		_row("Stripped to a bare shell.", "")
	for pid in v.parts_remaining:
		var pd: Dictionary = GameData.PARTS[pid]
		var value := GameData.part_value(pid, float(v.data.part_mult), v.part_condition(pid))
		var reason := _part_block_reason(v, pid)
		var box := VBoxContainer.new()
		var h := HBoxContainer.new()
		var n := _mk_label(pd.name, 19, Color(1, 1, 1) if reason == "" else Color(0.62, 0.55, 0.55))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(_mk_label("$%s  " % _comma(value), 18, CASH))
		if reason == "":
			h.add_child(_button("[Do it properly]", _start_part.bind(v, pid, false)))
			if pd.has("alt") and GameState.has_shop_tool(String(pd.alt.tool)):
				h.add_child(_button(String(pd.alt.button), _start_part.bind(v, pid, true)))
		else:
			h.add_child(_mk_label(reason, 15, BAD))
		box.add_child(h)
		var sm := _mk_label(GameData.stages_summary(pid), 14, Color(0.65, 0.65, 0.65))
		sm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sm.custom_minimum_size.x = 700
		box.add_child(sm)
		box.add_child(HSeparator.new())
		_panel_body.add_child(box)
	_panel_body.add_child(_button("Close", close_panel))

## "" when you can start on it, otherwise why not.
func _part_block_reason(v: Vehicle, pid: String) -> String:
	var pd: Dictionary = GameData.PARTS[pid]
	var missing := GameState.missing_tool_for_part(pid)
	if missing != "":
		return "needs %s" % missing
	var kit := GameState.missing_kit_for_part(pid)
	if kit != "":
		return "needs %s on your belt" % kit
	if bool(pd.lifted) and not v.lifted:
		return "get it up on stands first"
	for req in pd.after:
		if v.parts_remaining.has(req):
			return "pull the %s out first" % String(GameData.PARTS[req].name).to_lower()
	return ""

func _start_jack(v: Vehicle) -> void:
	_begin_teardown(v, "JACKING IT UP", GameData.JACK_STAGES,
		func(ok: bool, _q: float):
			if ok:
				v.set_lifted(true)
				toast("UP ON STANDS", "Wheels and the underbody are reachable now.")
			open_dismantle(v))

func _start_part(v: Vehicle, pid: String, use_alt: bool) -> void:
	var pd: Dictionary = GameData.PARTS[pid]
	var stages: Array = pd.stages
	var quality := 1.0
	if use_alt and pd.has("alt"):
		stages = pd.alt.stages
		quality = float(pd.alt.quality)
	_begin_teardown(v, String(pd.name).to_upper(), stages,
		func(ok: bool, q: float):
			if ok:
				var value := v.remove_part(pid, q)
				GameState.note_part_pulled()
				_hand_over(pid, value, v)
				var note := "In your hands. $%s" % _comma(value)
				if q < 0.95:
					note += "  (roughed up -- %d%% of book)" % int(round(q * 100.0))
				toast("%s OUT" % String(pd.name).to_upper(), note)
			else:
				toast("LEFT HALF-DONE", "%s is still bolted on." % pd.name)
			open_dismantle(v), quality, pid)

func _begin_teardown(v: Vehicle, title: String, stages: Array, cb: Callable, quality: float = 1.0, part_id: String = "") -> void:
	close_panel()
	_prompt_label.text = ""
	if player:
		player.input_locked = true
	set_focus_blur(true)
	_teardown.begin(v, title, stages, func(ok: bool, q: float):
		if player:
			player.input_locked = false
		set_focus_blur(false)
		cb.call(ok, q), quality, part_id)

## The part comes off the car and lands in the player hands. If they are
## already carrying something it goes on the floor at their feet instead.
func _hand_over(pid: String, value: int, v: Vehicle) -> PartItem:
	var item := PartItem.create(pid, value, String(v.data.name),
		v.data.get("color", Color(0.6, 0.6, 0.6)), v.make_part_visual(pid), String(v.data.id))
	get_tree().current_scene.add_child(item)
	item.global_position = v.global_position + Vector3(0, 0.4, 0) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(1.5, 2.5))
	if player and player.carrying == null:
		player.pick_up(item)
	return item

## Used by the headless smoke test only.
func debug_remove(v: Vehicle, pid: String) -> int:
	var value := v.remove_part(pid, 1.0)
	GameState.note_part_pulled()
	var item := _hand_over(pid, value, v)
	if player and player.carrying == item:
		player.drop_carried()
	return value
