extends RefCounted
class_name Gunplay
# ============================================================
#  Everything that goes bang. One raycast, one tracer, one
#  interface: anything in the "shootable" group with a
#  take_damage(amount, from) method can be hit.
# ============================================================

const SHOT_LAYER := 0xFFFFFFFF

## Fire one round. Returns the node hit, or null.
## `origin` is where the shot is traced from -- for the player that is the
## camera, so the round goes where the crosshair is. `muzzle` is where it is
## drawn from, which is the gun. Drawing from the camera puts a tracer across
## the whole screen.
static func fire(shooter: Node3D, origin: Vector3, dir: Vector3, weapon: Dictionary,
		spread: float = 0.0, ignore: Array = [], muzzle: Vector3 = Vector3.INF) -> Node:
	var aim := dir.normalized()
	if spread > 0.0:
		aim = aim.rotated(Vector3.UP, randf_range(-spread, spread))
		aim = aim.rotated(shooter.global_transform.basis.x, randf_range(-spread, spread) * 0.6)
	var reach: float = float(weapon.range)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + aim * reach)
	q.exclude = _rids(shooter, ignore)
	q.collide_with_areas = false
	var hit := shooter.get_world_3d().direct_space_state.intersect_ray(q)

	var landed: Vector3 = hit.position if hit.has("position") else origin + aim * reach
	_tracer(shooter, muzzle if muzzle.is_finite() else origin, landed)

	if hit.is_empty():
		return null
	var who := hit.collider as Node
	# walk up for the case where the collider is a child body
	while who != null and not who.is_in_group("shootable"):
		who = who.get_parent()
	if who == null or not who.has_method("take_damage"):
		return null
	who.take_damage(int(weapon.damage), shooter)
	return who

## A line in the air where the round went, gone in a blink.
static func _tracer(host: Node3D, from: Vector3, to: Vector3) -> void:
	var span := from.distance_to(to)
	if span < 0.2:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.035, span)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(mi.queue_free)

## Muzzle flash at the end of the barrel.
static func flash(host: Node3D, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.omni_range = 5.0
	light.light_energy = 3.0
	light.light_color = Color(1.0, 0.85, 0.5)
	host.get_tree().current_scene.add_child(light)
	light.global_position = at
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.09)
	tw.tween_callback(light.queue_free)

## Can `from` see `to` well enough to shoot at them?
static func clear_shot(from: Node3D, to: Node3D, head: float = 1.5, ignore: Array = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		from.global_position + Vector3.UP * head, to.global_position + Vector3.UP * 1.0)
	q.exclude = _rids(from, [to] + ignore)
	return from.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Whatever the shot should pass straight through. A driver sitting in a car is
## still a target -- without this the round stops on their own bodywork and the
## police can never fire on somebody who will not pull over.
static func _rids(shooter: Node3D, ignore: Array) -> Array:
	var out := [shooter.get_rid()]
	for n in ignore:
		if n != null and is_instance_valid(n) and n is CollisionObject3D:
			out.append((n as CollisionObject3D).get_rid())
	return out

## The car somebody is sitting in, if any.
static func ride_of(who: Node) -> Node:
	if who == null:
		return null
	var v = who.get("current_vehicle")
	return v if v != null and is_instance_valid(v) else null
