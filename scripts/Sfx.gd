extends Node
# ============================================================
#  Sound. One autoload, a pool of players, and a table of banks.
#
#  A "bank" is a folder of interchangeable takes -- eight
#  footsteps on rock, six pained grunts -- and playing one picks
#  a take at random and nudges the pitch, so the same event
#  twice running does not sound like a tape loop.
#
#  Files are found by scanning the folder once at startup and
#  keeping the paths. Nothing is loaded until the bank is first
#  played, and then it stays loaded.
# ============================================================

## How many one-shot voices can overlap before the oldest is reused.
const POOL := 24
const SOUNDS := "res://Sounds"

## A bank is a folder plus a piece of filename to look for inside it. The pack
## keeps footsteps and voices in a folder each, but files every vehicle sound
## into one drawer, so matching on a fragment covers both.
const CAR := "Vehicle_Essentials_NOX_SOUND/Vehicle_Essential_Car"
const LORRY := "Vehicle_Essentials_NOX_SOUND/Vehicle_Essential_Truck"
const FEET := "Footsteps_Essentials_NOX_SOUND/Footsteps_Rock"

const BANKS := {
	# --- feet: the whole game is on pavement, so rock it is ---
	"step_walk":   [FEET + "/Footsteps_Rock_Walk", ""],
	"step_run":    [FEET + "/Footsteps_Rock_Run", ""],
	"jump":        [FEET + "/Footsteps_Rock_Jump", "Jump_Start"],
	"land":        [FEET + "/Footsteps_Rock_Jump", "Jump_Land"],
	# --- cars ---
	"car_door_open":  [CAR, "Door_Opening_Exterior"],
	"car_door_close": [CAR, "Door_Closing_Exterior"],
	"car_start":      [CAR, "Start_Engine_Exterior"],
	"car_stop":       [CAR, "Stop_Engine_Exterior"],
	"car_idle":       [CAR, "Engine_Idle_Exterior_Loop"],
	"car_drive":      [CAR, "Drive_Exterior_Loop"],
	"car_rev":        [CAR, "Engine_2000_RPM_Front_Exterior_Loop"],
	"car_horn":       [CAR, "Horn_Exterior"],
	"car_keys":       [CAR, "Car_Keys"],
	"car_handbrake":  [CAR, "Hand_Brake"],
	"trunk_open":     [CAR, "Trunk_Open_Mono"],
	"trunk_close":    [CAR, "Trunk_Close_Mono"],
	"siren":          [CAR, "olice_siren"],
	# --- trucks ---
	"truck_door_open":  [LORRY, "Truck_Door_Opening_Exterior"],
	"truck_door_close": [LORRY, "Truck_Door_Closing_Exterior"],
	"truck_drive":      [LORRY, "Truck_Drive_Exterior_Loop"],
	"truck_idle":       [LORRY, "Truck_Idle_Exterior_Front_Loop"],
	"truck_trunk_open": [LORRY, "Truck_Trunk_Opening_Mono"],
	"truck_trunk_close":[LORRY, "Truck_Trunk_Closing_Mono"],
}

## Voices are picked by who is speaking: voice_<sex>_<what>. Each sex has a
## folder per category, and the fragment sorts out which take inside it.
const VOICE_ROOT := "Voices_Essentials_NOX_SOUND"
const VOICE_KINDS := {
	"pain":    ["Pain", "_Pain_"],
	"hit":     ["Hit", "_Hit_"],
	"effort":  ["Effort", "_Effort_"],
	"shocked": ["Breath", "_Breath_Shocked_"],
	"gasp":    ["Breath", "_Breath_Gasp_"],
	"attack":  ["Attack", "_Attack_"],
	"jump":    ["Jump_Land", "_Jump_"],
	"land":    ["Jump_Land", "_Land_"],
	"cough":   ["Cough", "_Cough_"],
}

var _paths := {}                      # bank -> [file paths]
var _loaded := {}                     # bank -> [AudioStream]
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _flat: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 46.0
		p.unit_size = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)
	_flat = AudioStreamPlayer.new()
	add_child(_flat)

## Every take in a bank, found once and remembered.
func _files(bank: String) -> Array:
	if _paths.has(bank):
		return _paths[bank]
	var spec: Array = BANKS.get(bank, [])
	if spec.is_empty() and bank.begins_with("voice_"):
		spec = _voice_spec(bank)
	var out := []
	if not spec.is_empty():
		var dir := String(spec[0])
		var want := String(spec[1]).to_lower()
		var d := DirAccess.open("%s/%s" % [SOUNDS, dir])
		if d != null:
			for f in d.get_files():
				# the editor leaves a .import beside each one; the sound is the wav
				if not f.ends_with(".wav"):
					continue
				if want != "" and not f.to_lower().contains(want):
					continue
				out.append("%s/%s/%s" % [SOUNDS, dir, f])
	out.sort()
	_paths[bank] = out
	if out.is_empty():
		push_warning("no sound in bank %s" % bank)
	return out

## voice_male_pain -> where the male pain takes live, and what to look for
func _voice_spec(bank: String) -> Array:
	var bits := bank.split("_")
	if bits.size() < 3:
		return []
	var sex := String(bits[1]).capitalize()
	var kind: Array = VOICE_KINDS.get("_".join(bits.slice(2)), [])
	if kind.is_empty():
		return []
	return ["%s/Voice_Essential_%s/Voice_%s_%s" % [VOICE_ROOT, sex, sex, String(kind[0])],
		String(kind[1])]

func _streams(bank: String) -> Array:
	if _loaded.has(bank):
		return _loaded[bank]
	var out := []
	for path in _files(bank):
		var st := load(path)
		if st != null:
			out.append(st)
	_loaded[bank] = out
	return out

func _take(bank: String) -> AudioStream:
	var st := _streams(bank)
	return null if st.is_empty() else st[randi() % st.size()]

## One shot, out in the world. Returns the player so a caller can stop it.
func play(bank: String, at: Vector3, db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var stream := _take(bank)
	if stream == null or _pool.is_empty():
		return null
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.global_position = at
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()
	return p

## One shot with no position -- menus, and anything the player does to himself.
func play_flat(bank: String, db: float = 0.0) -> void:
	var stream := _take(bank)
	if stream == null:
		return
	_flat.stream = stream
	_flat.volume_db = db
	_flat.play()

## A player of its own, parented to something that moves, set to loop. The
## caller owns it: keep it, change its pitch, free it when it is done.
func loop_on(bank: String, host: Node3D, db: float = -6.0) -> AudioStreamPlayer3D:
	var stream := _take(bank)
	if stream == null or host == null:
		return null
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = (stream as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / (4 if w.stereo else 2)
		stream = w
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = 60.0
	p.unit_size = 8.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	host.add_child(p)
	p.play()
	return p

## Which set of voices this person uses. Seeded off whatever makes them look
## the way they look, so the same body always sounds like itself.
static func voice_sex(seed_value: int) -> String:
	return "female" if seed_value % 2 == 0 else "male"
