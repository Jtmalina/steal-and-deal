extends Pedestrian
class_name Staff
# ============================================================
#  Somebody at work. The receptionist behind the hotel desk, the
#  barman, the girl on the till, the lad stacking shelves, the
#  regular on his stool.
#
#  They have a few posts inside the building and move between
#  them -- the till, the shelves, the back -- doing whatever that
#  post is for when they get there. They are people like anybody
#  on the pavement: they see what you do, they run from gunfire,
#  and they can be hurt. What they are not is part of the street:
#  the traffic neither counts them nor clears them away.
# ============================================================

## What they wear for it: shirt and trousers. Anybody not listed is in their
## own clothes, which is what a customer is.
const UNIFORMS := {
	"reception": [Color(0.46, 0.10, 0.15), Color(0.12, 0.12, 0.14)],
	"office": [Color(0.86, 0.87, 0.90), Color(0.18, 0.20, 0.27)],
	"guard": [Color(0.22, 0.24, 0.30), Color(0.14, 0.15, 0.18)],
	"bar": [Color(0.10, 0.10, 0.11), Color(0.13, 0.13, 0.14)],
	"shop": [Color(0.20, 0.50, 0.32), Color(0.20, 0.20, 0.24)],
	"diner": [Color(0.93, 0.93, 0.90), Color(0.26, 0.26, 0.32)],
	"fuel": [Color(0.80, 0.30, 0.22), Color(0.18, 0.18, 0.22)],
}
## Nobody works for an audience that is not there: past this they hold still.
const IDLE_BEYOND := 75.0
const PACE := 1.2

## Which uniform, or "patron", or "police" for the desk sergeant.
var trade := "shop"
## Each post is {at: Vector3 (world), face: float (yaw), act: String,
## stay: Vector2 (seconds, least and most)}. They start on the first.
var posts: Array = []
var _post := 0
var _stay := 0.0
var _clock := 0.0
var _asleep := false
var _check := 0.0
var _en_route := 0.0

## Put somebody to work in `parent` (a block, built already). Posts come in
## that block's own space and go out in the world's.
static func hire(parent: Node3D, job: String, local_posts: Array, seed_from: int) -> Staff:
	var s := Staff.new()
	s.trade = job
	s.outfit_seed = seed_from
	for p: Array in local_posts:
		s.posts.append({
			"at": parent.to_global(p[0]),
			"face": parent.global_rotation.y + float(p[1]),
			"act": String(p[2]),
			"stay": p[3] if p.size() > 3 else Vector2(6.0, 14.0),
		})
	parent.add_child(s)
	if not s.posts.is_empty():
		s.global_position = s.posts[0].at
		s._body.rotation.y = s.posts[0].face
	return s

func _ready() -> void:
	super()
	remove_from_group("pedestrian")
	add_to_group("staff")
	_rng.seed = outfit_seed
	_clock = _rng.randf() * 100.0
	_stay = _rng.randf_range(3.0, 12.0)

func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = outfit_seed
	if trade == "police":
		PersonMesh.build_officer(_body, rng)
	elif UNIFORMS.has(trade):
		var kit := PersonMesh.random_civvies(rng)
		var uni: Array = UNIFORMS[trade]
		PersonMesh.build(_body, uni[0], uni[1], kit[2], kit[3], kit[4])
	else:
		var kit := PersonMesh.random_civvies(rng)
		PersonMesh.build(_body, kit[0], kit[1], kit[2], kit[3], kit[4])
	walk_speed = PACE

## Whatever post they are on right now, or "" if they are between them.
func doing() -> String:
	if posts.is_empty() or _walking_to_post():
		return ""
	return String(posts[_post].act)

func _walking_to_post() -> bool:
	if posts.is_empty():
		return false
	var to: Vector3 = posts[_post].at - global_position
	to.y = 0.0
	return to.length() > 0.3

func _physics_process(delta: float) -> void:
	if tumbling:
		_tumble(delta)
		return
	if down:
		return
	_hit_lull = maxf(0.0, _hit_lull - delta)
	if panic_until > 0.0:
		panic_until -= delta
		_rig.slump()
		_flee(delta)
		return
	if posts.is_empty():
		return

	# nobody about to see: stay put and cost nothing
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		var who := get_tree().get_first_node_in_group("player") as Node3D
		_asleep = who != null and who.global_position.distance_to(global_position) > IDLE_BEYOND
	if _asleep:
		return
	_clock += delta

	var post: Dictionary = posts[_post]
	var to: Vector3 = post.at - global_position
	to.y = 0.0
	if to.length() > 0.3:
		# over to the next post, round anything in the way -- and anybody wedged
		# behind a counter for this long is there, near enough
		_en_route += delta
		if _en_route > 8.0:
			global_position = Vector3(post.at.x, global_position.y, post.at.z)
			return
		var want := _around_obstacles(to.normalized() * walk_speed, delta)
		velocity.x = want.x
		velocity.z = want.z
		velocity.y = -2.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		if want.length() > 0.1:
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(want.x, want.z), 0.2)
		_rig.step(delta, Vector2(velocity.x, velocity.z).length())
		return

	# there: face the work and get on with it
	_en_route = 0.0
	velocity = Vector3.ZERO
	_body.rotation.y = lerp_angle(_body.rotation.y, float(post.face), 0.15)
	_rig.work(String(post.act), _clock)
	_stay -= delta
	if _stay <= 0.0 and posts.size() > 1:
		var next := _rng.randi_range(0, posts.size() - 2)
		_post = next if next < _post else next + 1
		var stay: Vector2 = posts[_post].stay
		_stay = _rng.randf_range(stay.x, stay.y)
		_rig.slump()
	elif _stay <= 0.0:
		_stay = 10.0
