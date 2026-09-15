extends RefCounted
class_name SaveGame
# ============================================================
#  Writing the shop down and reading it back.
#
#  What gets saved is the stuff you earned: money, skill, the
#  kit on your belt and in the shop, the clock, the cars on the
#  ramps and everything still in the back of the truck.
#
#  What does not is the traffic and the parked cars. Those are
#  generated from fixed seeds, so they come back the same on
#  their own, and writing sixty vehicles into a file to get the
#  same sixty vehicles out again is not worth the paper.
# ============================================================

const PATH := "user://steal_and_deal.save"
const VERSION := 1

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

## When it was written, for the menu to show. "" if there is no save.
static func stamp() -> String:
	if not exists():
		return ""
	var data := _read()
	return String(data.get("saved_at", "")) if not data.is_empty() else ""

static func wipe() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)

## Everything worth keeping, as one dictionary.
static func write(world: World, player: Player) -> String:
	var jobs := []
	for j in world.jobs:
		if not is_instance_valid(j):
			continue
		jobs.append({
			"id": String(j.data.id),
			"condition": j.condition,
			"lifted": j.lifted,
			"parts": Array(j.parts_remaining),
		})
	var cargo := []
	var lorry := GameState.truck()
	if lorry:
		for c in lorry.cargo:
			cargo.append({"part": String(c.part), "name": String(c.name),
				"value": int(c.value), "size": int(c.size), "from": String(c.from)})
	var loose := []
	for n in world.get_tree().get_nodes_in_group("loose_part"):
		var item := n as PartItem
		# wrecked parts are litter and clear themselves up; they do not save
		if item == null or item.carried or item.damaged:
			continue
		loose.append({"part": item.part_id, "value": item.value, "from": item.from_name,
			"at": [item.global_position.x, item.global_position.y, item.global_position.z]})

	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(true, true),
		"money": GameState.money,
		"theft_xp": GameState.theft_xp,
		"theft_level": GameState.theft_level,
		"theft_tools": GameState.owned_theft_tools.duplicate(),
		"shop_tools": GameState.owned_shop_tools.duplicate(),
		"garage_level": GameState.garage_level,
		"truck_level": GameState.truck_level,
		"buyers": GameState.unlocked_buyers.duplicate(),
		"owned_items": GameState.owned_items.duplicate(),
		"hotbar": GameState.hotbar.duplicate(),
		"selected": GameState.selected,
		"health": GameState.health,
		"ammo": GameState.ammo,
		"minutes": GameState.minutes,
		"impounded": GameState.truck_impounded,
		"stats": GameState.stats.duplicate(),
		"jobs": jobs,
		"cargo": cargo,
		"loose": loose,
		"player_at": [player.global_position.x, player.global_position.y, player.global_position.z],
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return "Could not write the save file."
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return ""

## Put a saved shop back. The world must already be built.
static func read_into(world: World, player: Player) -> String:
	var data := _read()
	if data.is_empty():
		return "No save to load."
	if int(data.get("version", 0)) != VERSION:
		return "That save is from a different build."

	GameState.money = int(data.get("money", 500))
	GameState.theft_xp = int(data.get("theft_xp", 0))
	GameState.theft_level = int(data.get("theft_level", 1))
	GameState.owned_theft_tools = (data.get("theft_tools", {}) as Dictionary).duplicate()
	GameState.owned_shop_tools = (data.get("shop_tools", {}) as Dictionary).duplicate()
	GameState.garage_level = int(data.get("garage_level", 1))
	GameState.truck_level = int(data.get("truck_level", 1))
	GameState.unlocked_buyers = (data.get("buyers", ["scrap"]) as Array).duplicate()
	GameState.owned_items = (data.get("owned_items", []) as Array).duplicate()
	GameState.hotbar = (data.get("hotbar", []) as Array).duplicate()
	GameState.selected = int(data.get("selected", 0))
	GameState.health = int(data.get("health", 100))
	GameState.ammo = int(data.get("ammo", 0))
	GameState.minutes = float(data.get("minutes", 540.0))
	GameState.truck_impounded = bool(data.get("impounded", false))
	for k in (data.get("stats", {}) as Dictionary).keys():
		GameState.stats[k] = int(data["stats"][k])

	# the shop itself: bays, whatever is on them, and the load in the truck
	for j in world.jobs:
		if is_instance_valid(j):
			j.queue_free()
	world.jobs.clear()
	for entry in data.get("jobs", []):
		var car := world.spawn_job(String(entry.id))
		if car == null:
			continue
		car.condition = float(entry.condition)
		car.parts_remaining.assign(entry.parts)
		car.stripped = car.parts_remaining.is_empty()
		car.refresh_part_meshes()
		if bool(entry.lifted):
			car.set_lifted(true)
		car.refresh_label()

	var lorry := GameState.truck()
	if lorry:
		lorry.unload_all()
		for c in data.get("cargo", []):
			lorry.cargo.append({"part": String(c.part), "name": String(c.name),
				"value": int(c.value), "size": int(c.size), "from": String(c.from)})
		lorry._restack()
		if GameState.truck_impounded:
			world.impound_truck(lorry)

	for n in world.get_tree().get_nodes_in_group("loose_part"):
		(n as Node).queue_free()
	for entry in data.get("loose", []):
		var at: Array = entry.at
		var item := PartItem.create(String(entry.part), int(entry.value), String(entry.from),
			Color(0.6, 0.6, 0.6), null)
		world.get_tree().current_scene.add_child(item)
		item.global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))

	var pat: Array = data.get("player_at", [0, 1.5, 0])
	player.global_position = Vector3(float(pat[0]), float(pat[1]), float(pat[2]))
	GameState.sync_belt()
	GameState.kit_changed.emit()
	GameState.money_changed.emit(GameState.money)
	GameState.skill_changed.emit()
	GameState.inventory_changed.emit()
	GameState.health_changed.emit(GameState.health)
	return ""

static func _read() -> Dictionary:
	if not exists():
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
