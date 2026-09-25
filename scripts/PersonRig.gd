extends RefCounted
class_name PersonRig
# ============================================================
#  Puts a box person through the motions.
#
#  Legs and arms counter-swing at a cadence that follows how
#  fast they are actually moving, both hands come up when they
#  are pointing a gun at something, and a tire iron goes over
#  the shoulder and down through whatever is in front.
#
#  Everybody uses it: the player, the folk on the pavement and
#  the police, so a copper running at you moves like a person
#  rather than sliding along on a plinth.
# ============================================================

## Radians of leg swing at a walking pace, and how much a sprint adds.
const STRIDE := 0.52
const STRIDE_PER_SPEED := 0.055
## Steps per second standing still, and how many the speed adds.
const CADENCE := 2.4
const CADENCE_PER_SPEED := 0.62
## Arms swing the other way, and less than the legs do.
const ARM_RATIO := -0.68
## Both arms come up to here to point something. Negative is forwards: the
## limbs hang down the -Y of their pivot and everybody faces +Z.
const AIM_PITCH := -1.45
const AIM_SPREAD := 0.34
## Over the shoulder, then down and through.
const SWING_TIME := 0.42
const SWING_FROM := -2.5
const SWING_TO := -0.35

var body: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var hand: Node3D

var _phase := 0.0
var _amount := 0.0        # how big the current stride is, eased in and out
## Where whoever owns this rig has put the body. The walk bob rides on top of
## it rather than replacing it, so somebody sat down on a car seat stays there.
var _base_y := 0.0
var _aim := 0.0           # 0 arms swinging, 1 arms up
var _swing := -1.0        # seconds left of a melee swing, negative when idle

## `body_root` is whatever PersonMesh built into.
func _init(body_root: Node3D) -> void:
	body = body_root
	if body == null:
		return
	_base_y = body.position.y
	for n in ["LegL", "LegR"]:
		var leg := body.get_node_or_null(n) as Node3D
		if leg:
			legs.append(leg)
	for n in ["ArmL", "ArmR"]:
		var arm := body.get_node_or_null(n) as Node3D
		if arm:
			arms.append(arm)
	hand = body.get_node_or_null("ArmR/Hand") as Node3D

func ready() -> bool:
	return legs.size() == 2 and arms.size() == 2

## Take a swipe with whatever is in the right hand.
func swipe() -> void:
	_swing = SWING_TIME

## True while the arm is still coming round, so the hit can land on the way
## through rather than the moment the button goes down.
func swiping() -> bool:
	return _swing >= 0.0

## One frame. `speed` is how fast they are travelling over the ground.
func step(delta: float, speed: float, aiming: bool = false) -> void:
	if not ready():
		return
	var want := 0.0
	if speed > 0.15:
		_phase += delta * (CADENCE + speed * CADENCE_PER_SPEED)
		want = STRIDE + speed * STRIDE_PER_SPEED
	# ease the stride in and out so stopping does not snap the legs straight
	_amount = move_toward(_amount, want, delta * 4.0)
	_aim = move_toward(_aim, 1.0 if aiming else 0.0, delta * 7.0)

	var swing := sin(_phase) * _amount
	legs[0].rotation.x = swing
	legs[1].rotation.x = -swing

	# arms: swinging, up on aim, or mid-swipe
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		arms[i].rotation.x = lerpf(-swing * ARM_RATIO * side, AIM_PITCH, _aim)
		arms[i].rotation.z = lerpf(0.0, AIM_SPREAD * side, _aim)
	if _swing >= 0.0:
		_swing -= delta
		var t := 1.0 - clampf(_swing / SWING_TIME, 0.0, 1.0)
		# quick on the way down, which is the half that hits something
		arms[1].rotation.x = lerpf(SWING_FROM, SWING_TO, t * t * (3.0 - 2.0 * t))
		arms[1].rotation.z = lerpf(-0.45, 0.15, t)

	# a bob to go with it, biggest at a run
	body.position.y = _base_y + absf(sin(_phase)) * 0.05 * clampf(_amount / STRIDE, 0.0, 1.4)

## Sat in a car: thighs out, hands up on the wheel. Set once and left alone --
## nobody is animating the traffic.
func sit() -> void:
	if not ready():
		return
	for l in legs:
		l.rotation = Vector3(-1.35, 0.0, 0.0)
	for i in 2:
		arms[i].rotation = Vector3(-1.15, 0.0, (0.3 if i == 0 else -0.3))
	body.position.y = _base_y

## Busy with something where they stand, rather than going anywhere. `kind`:
## "type" at a keyboard, "serve" reaching over a counter now and then,
## "stock" arms up at a shelf, "sit" on a stool with their hands on the
## counter, anything else just stood about. `t` is their own clock, so two
## people at one bar are not in step.
func work(kind: String, t: float) -> void:
	if not ready():
		return
	var sat := kind == "sit"
	for l in legs:
		l.rotation = Vector3(-1.35 if sat else 0.0, 0.0, 0.0)
	body.position.y = _base_y + (-0.42 if sat else sin(t * 1.3) * 0.008)
	match kind:
		"type":
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				arms[i].rotation = Vector3(-0.95 + sin(t * 13.0 + side * 1.7) * 0.07, 0.0, side * 0.12)
		"serve":
			# mostly waiting, then over the counter with something, and back
			var reach := maxf(0.0, sin(t * 0.9)) ** 6.0
			arms[0].rotation = Vector3(-0.35, 0.0, 0.08)
			arms[1].rotation = Vector3(-0.35 - reach * 1.05, 0.0, -0.08)
		"stock":
			var lift := 0.5 + 0.5 * sin(t * 1.6)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				arms[i].rotation = Vector3(-1.1 - lift * 0.45, 0.0, side * 0.1)
		"sit":
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				arms[i].rotation = Vector3(-0.9 + (sin(t * 0.7) * 0.25 if i == 1 else 0.0), 0.0, side * 0.2)
		_:
			for i in 2:
				arms[i].rotation = Vector3(sin(t * 0.8 + float(i)) * 0.05, 0.0, 0.0)

## Drop everything back to standing, for somebody who is not on their feet.
func slump() -> void:
	if not ready():
		return
	for l in legs:
		l.rotation = Vector3.ZERO
	for a in arms:
		a.rotation = Vector3.ZERO
	body.position.y = _base_y
