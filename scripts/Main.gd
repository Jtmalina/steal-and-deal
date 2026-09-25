extends Node3D
# ============================================================
#  Boots the prototype: environment, world, player, HUD, cops.
# ============================================================

## Skipped straight past for the smoke test and the benchmark, which have their
## own idea of what should happen when the game starts.
var _menu: MainMenu = null
var _pause: PauseMenu = null
var _player: Player = null
var _world: World = null
var _hud: HUD = null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke") or args.has("--bench") or args.has("--shots"):
		_begin("new")
		return
	_menu = MainMenu.new()
	_menu.chose.connect(_on_menu_choice)
	add_child(_menu)

func _on_menu_choice(what: String) -> void:
	if what == "exit":
		get_tree().quit()
		return
	if _menu:
		_menu.queue_free()
		_menu = null
	_begin(what)

## Build the whole thing, and put a saved shop back on top of it if asked.
func _begin(what: String) -> void:
	_build_environment()

	var world := World.new()
	_world = world
	world.name = "World"
	add_child(world)

	var player := _make_player()
	_player = player
	add_child(player)
	player.global_position = World.GARAGE_POS + Vector3(0, 1.5, -14.0)

	var hud := HUD.new()
	_hud = hud
	hud.name = "HUD"
	hud.player = player
	hud.world = world
	add_child(hud)
	player.hud = hud

	var dispatch := PoliceDispatch.new()
	dispatch.name = "PoliceDispatch"
	add_child(dispatch)

	if what == "load":
		var err := SaveGame.read_into(world, player)
		if err != "":
			hud.toast("COULD NOT LOAD", err)
		else:
			hud.toast("LOADED", "Back where you left off.")

	if OS.get_cmdline_user_args().has("--shots"):
		var tour := ShotTour.new()
		tour.name = "ShotTour"
		add_child(tour)

	if OS.get_cmdline_user_args().has("--smoke"):
		var smoke: Node = (load("res://scripts/SmokeTest.gd") as Script).new()
		smoke.player = player
		smoke.world = world
		smoke.hud = hud
		add_child(smoke)

func _toggle_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		_close_pause()
		return
	_pause = PauseMenu.new()
	_pause.chose.connect(_on_pause_choice)
	add_child(_pause)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_pause_choice(what: String) -> void:
	match what:
		"resume":
			_close_pause()
		"save":
			var err := SaveGame.write(_world, _player)
			_close_pause()
			if _hud != null and is_instance_valid(_hud):
				if err != "":
					_hud.toast("NOT SAVED", err)
				else:
					_hud.toast("SAVED", "The shop, the truck and everything on the ramps.")
		"menu":
			_close_pause()
			_tear_down()
		"desktop":
			get_tree().paused = false
			get_tree().quit()

## Everything the run built, taken back down so the front screen starts clean.
func _tear_down() -> void:
	for n in [_hud, _player, _world, get_node_or_null("PoliceDispatch"),
			get_node_or_null("WorldEnvironment"), get_node_or_null("DayNight"),
			get_node_or_null("Sun")]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_hud = null
	_player = null
	_world = null
	GameState.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu = MainMenu.new()
	_menu.chose.connect(_on_menu_choice)
	add_child(_menu)

var _bench_frames := 0
var _fps_sum := 0.0
var _prim_sum := 0.0
var _draw_sum := 0.0

## The game opens full screen. [F11] puts it back in a window and takes it out
## again, because being stuck full screen with no way back is worse than the
## small box was.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE and _player != null and is_instance_valid(_player):
		# Esc belongs to whatever is in front of it first: a teardown rig walks
		# away, an open panel closes, and only a plain Esc out in the world
		# stops the game.
		if _hud != null and is_instance_valid(_hud) and _hud.busy_with_panel():
			return
		get_viewport().set_input_as_handled()
		_toggle_pause()
		return
	if key != KEY_F11:
		return
	get_viewport().set_input_as_handled()
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(_d: float) -> void:
	if not OS.get_cmdline_user_args().has("--bench"):
		set_process(false)
		return
	_bench_frames += 1
	if _bench_frames == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var p := get_node_or_null("Player") as Player
		var h := get_node_or_null("HUD") as HUD
		h.close_panel()
		# stand on a main road looking down it: about as much on screen as it gets
		p.global_position = Vector3(3.0, 1.5, 30.0)
		p._yaw = 0.0
		p._pitch = -0.05
	if _bench_frames < 90:
		return
	_fps_sum += Performance.get_monitor(Performance.TIME_FPS)
	_prim_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if _bench_frames < 330:
		return
	var n := float(_bench_frames - 90)
	var cars := get_tree().get_nodes_in_group("vehicle").size()
	print("[BENCH] %.0f fps | %.0f triangles | %.0f draw calls | %d cars, %d people in world" % [
		_fps_sum / n, _prim_sum / n, _draw_sum / n,
		cars, get_tree().get_nodes_in_group("pedestrian").size()])
	get_tree().quit()

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	# the sky is only looked at; the light it would give off is set by hand
	# in DayNight, so its radiance map can stay tiny
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.42, 0.48)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color(0.60, 0.67, 0.76)
	env.fog_density = 0.004
	# a little haze on the sky, not so much the stars drown in it
	env.fog_sky_affect = 0.3
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -125, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	add_child(sun)

	# and the thing that swings all of it round over the day
	var clock := DayNight.new()
	clock.name = "DayNight"
	clock.sun = sun
	clock.env = env
	clock.sky = sky_mat
	add_child(clock)

func _make_player() -> Player:
	var p := Player.new()
	p.name = "Player"

	var col := CollisionShape3D.new()
	col.name = "Collider"
	var caps := CapsuleShape3D.new()
	caps.radius = 0.4
	caps.height = 1.8
	col.shape = caps
	col.position.y = 0.9
	p.add_child(col)

	var body := Node3D.new()
	body.name = "Body"
	p.add_child(body)
	PersonMesh.build(body, Color(0.75, 0.25, 0.25), Color(0.16, 0.20, 0.34),
		PersonMesh.SKIN[0], PersonMesh.HAIR[0], PersonMesh.SHOES[0])

	var pivot := Node3D.new()
	pivot.name = "CamPivot"
	pivot.position.y = 1.5
	p.add_child(pivot)

	var held := Node3D.new()
	held.name = "Hold"
	# down at the hip and out to the side: a full-size door carried at chest
	# height would be through your own head
	held.position = Vector3(0.62, -0.62, -1.25)
	pivot.add_child(held)

	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 6.5
	arm.margin = 0.3
	pivot.add_child(arm)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 74.0
	cam.current = true
	arm.add_child(cam)
	return p
