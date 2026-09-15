extends Node
# ============================================================
#  Global run state. Autoloaded as "GameState".
# ============================================================

signal money_changed(amount: int)
signal truck_changed()
signal inventory_changed()
signal wanted_changed(stars: int)
signal health_changed(hp: int)
signal kit_changed()
signal skill_changed()
signal notify(title: String, body: String)

var money: int = 500
var theft_xp: int = 0
var theft_level: int = 1                       # widens the success zone
var owned_theft_tools := {"jimmy": 1}          # tool_id -> level
var owned_shop_tools := {}                     # tool_id -> true
var garage_level: int = 1
var truck_level: int = 1
var unlocked_buyers := ["scrap"]
var wanted: int = 0
var health: int = 100
## Caught behind the wheel of your own truck: it is in the pound, and nothing
## can be sold until it is back, because the load is in the back of it.
var truck_impounded: bool = false
var ammo: int = 0
## What you own that can be held, and what is actually on the belt.
## The wrench starts on the workbench rather than the belt: two loops, and you
## have to decide whether you are out stealing or in here stripping.
var owned_items := ["jimmy", "tire_iron", "socket_wrench"]
var hotbar := ["jimmy", "tire_iron"]
var selected: int = 0
var stats := {"stolen": 0, "delivered": 0, "parts": 0, "earned": 0, "busted": 0,
	"cops_shot": 0, "hospital": 0}

## Everything back to how a new game starts. Quitting to the front screen tears
## the world down, but this lives in an autoload and would otherwise carry the
## last run's money, heat and belt straight into the next one.
func reset() -> void:
	money = 500
	theft_xp = 0
	theft_level = 1
	owned_theft_tools = {"jimmy": 1}
	owned_shop_tools = {}
	garage_level = 1
	truck_level = 1
	unlocked_buyers = ["scrap"]
	wanted = 0
	health = 100
	truck_impounded = false
	ammo = 0
	owned_items = ["jimmy", "tire_iron", "socket_wrench"]
	hotbar = ["jimmy", "tire_iron"]
	selected = 0
	stats = {"stolen": 0, "delivered": 0, "parts": 0, "earned": 0, "busted": 0,
		"cops_shot": 0, "hospital": 0}
	minutes = 9.0 * 60.0

# ---------------- the board ----------------
## Standing orders. Refilled as they are taken or missed, so there is always
## something specific worth going out for.
var orders: Array = []
var _order_rng := RandomNumberGenerator.new()

func refresh_orders() -> void:
	if _order_rng.seed == 0:
		_order_rng.seed = int(Time.get_unix_time_from_system())
	orders = orders.filter(func(o): return not Orders.expired(o) and not Orders.done(o))
	while orders.size() < Orders.SLOTS:
		orders.append(Orders.make(_order_rng))

## A part just sold. If it fills a slot on the board, pay the premium on top.
## Returns the bonus paid, and 0 when nothing on the board wanted it.
func offer_to_board(part_id: String, from_car: String) -> int:
	for o: Dictionary in orders:
		if not Orders.wants(o, part_id, from_car):
			continue
		(o.filled as Array).append(part_id)
		if not Orders.done(o):
			notify.emit("ON THE ORDER", "%s still wants %d more." % [String(o.client),
				(o.parts as Array).size() - (o.filled as Array).size()])
			return 0
		var pay := int(o.pay)
		add_money(pay)
		notify.emit("ORDER FILLED", "%s paid $%d for the lot." % [String(o.client), pay])
		refresh_orders()
		return pay
	return 0

# ---------------- the clock ----------------
## Game minutes per real second. A full day runs about sixteen minutes, which
## is long enough for a night to feel like one and short enough to wait out.
const MINUTES_PER_SECOND := 1.5
## When it gets dark and when it gets light again, in hours.
const DUSK := 19.5
const NIGHT := 21.0
const DAWN := 5.0
const SUNUP := 7.0

## Minutes since midnight. Starts mid-morning, so the first job is in daylight.
var minutes: float = 9.0 * 60.0
## How lit the player is right now, worked out once a frame by the world and
## read by everybody who wants to know whether they can be seen.
var player_light: float = 1.0

func _ready() -> void:
	randomize()

func _process(delta: float) -> void:
	minutes = fmod(minutes + delta * MINUTES_PER_SECOND, 1440.0)

func hour() -> float:
	return minutes / 60.0

func clock_text() -> String:
	return "%02d:%02d" % [int(minutes / 60.0), int(fmod(minutes, 60.0))]

## 1 in broad daylight, 0 in the dead of night, and a ramp either side.
func daylight() -> float:
	var h := hour()
	if h >= SUNUP and h <= DUSK:
		return 1.0
	if h >= NIGHT or h < DAWN:
		return 0.0
	if h > DUSK:
		return 1.0 - (h - DUSK) / (NIGHT - DUSK)
	return (h - DAWN) / (SUNUP - DAWN)

## How far somebody can see the player doing something, given how lit the
## player is. Never nothing -- you can still be heard and half seen.
func sight_scale() -> float:
	return 0.34 + 0.66 * player_light

func is_dark() -> bool:
	return daylight() < 0.35

# ---------------- money ----------------
func add_money(amount: int) -> void:
	money += amount
	if amount > 0:
		stats.earned += amount
	money_changed.emit(money)

func can_afford(price: int) -> bool:
	return money >= price

# ---------------- theft skill ----------------
func add_theft_xp(amount: int) -> void:
	theft_xp += amount
	while theft_xp >= xp_for_next() and theft_level < 10:
		theft_xp -= xp_for_next()
		theft_level += 1
		notify.emit("THEFT SKILL UP", "You are now a Level %d degenerate." % theft_level)
	skill_changed.emit()

func xp_for_next() -> int:
	return 3 + theft_level * 2

## How much slop you get when hooking the lock rod, in metres along the door.
## Skill and better gear widen it; a fancier car narrows it.
func jimmy_tolerance(vehicle: Dictionary) -> float:
	var t := 0.17
	t += 0.022 * float(theft_level - 1)
	t += 0.02 * float(best_tool_level_for(vehicle))
	for tool_id in owned_theft_tools.keys():
		t += float(GameData.THEFT_TOOLS[tool_id].zone_bonus) * 0.25
	t -= 0.028 * float(int(vehicle.get("tier", 1)) - 1)
	return clampf(t, 0.055, 0.34)

## How many catches the lock needs. Nicer cars have more linkage in the way.
func jimmy_hotspots(vehicle: Dictionary) -> int:
	return clampi(int(vehicle.get("tier", 1)), 1, 3)

func best_tool_level_for(vehicle: Dictionary) -> int:
	var best := 0
	for req in vehicle.requires:
		var tool_id: String = req[0]
		if owned_theft_tools.has(tool_id):
			best = maxi(best, int(owned_theft_tools[tool_id]))
	return best

## Can we even attempt this car with current gear?
func can_attempt(vehicle: Dictionary) -> bool:
	for req in vehicle.requires:
		if owned_theft_tools.get(req[0], 0) >= req[1]:
			return true
	return false

## Which key tools will beat this one's immobiliser. Empty means there is
## nothing in the way but the person holding the wheel.
func carjack_key(vehicle: Dictionary) -> Array:
	return GameData.CARJACK_KEYS.get(int(vehicle.get("tier", 1)), [])

## Can we take this one off its driver? A junker is just a fight; anything
## dearer wants the fob read first or the car dies at the end of the street.
func can_carjack(vehicle: Dictionary) -> bool:
	var need := carjack_key(vehicle)
	if need.is_empty():
		return true
	for req in need:
		if owned_theft_tools.get(req[0], 0) >= int(req[1]):
			return true
	return false

func carjack_key_text(vehicle: Dictionary) -> String:
	var opts := []
	for req in carjack_key(vehicle):
		opts.append("%s Lv%d" % [GameData.THEFT_TOOLS[req[0]].name, int(req[1])])
	return " OR ".join(opts)

func requirement_text(vehicle: Dictionary) -> String:
	var opts := []
	for req in vehicle.requires:
		opts.append("%s Lv%d" % [GameData.THEFT_TOOLS[req[0]].name, req[1]])
	return " OR ".join(opts)

# ---------------- shop tools ----------------
func has_shop_tool(id: String) -> bool:
	return owned_shop_tools.has(id)

## Full turns of the wrench needed to back one fastener out.
## Power tools mean fewer cranks of the mouse, not fewer bolts on the car.
func bolt_turns() -> float:
	# whatever is on the belt does the work, so the good driver only helps if
	# you actually brought it
	var best := 3.0
	for id in hotbar:
		var item: Dictionary = GameData.ITEMS.get(String(id), {})
		if item.has("turns"):
			best = minf(best, float(item.turns))
	if has_shop_tool("toolset"):
		best *= 0.8
	return maxf(best, 1.0)

## What this part needs on your belt that is not on it. "" when you are ready.
func missing_kit_for_part(part_id: String) -> String:
	for st in GameData.PARTS[part_id].stages:
		var want: Array = GameData.tools_for_stage(st, part_id)
		if want.is_empty():
			continue
		var have := false
		for id in want:
			if carrying_item(String(id)):
				have = true
				break
		if not have:
			return GameData.tool_names(want)
	return ""

## Anything that can get a car off the ground.
func can_lift() -> bool:
	return has_shop_tool("jack") or has_shop_tool("lift")

func part_price_mult() -> float:
	match garage_level:
		2: return 1.10
		3: return 1.25
	return 1.0

## "" when removable, otherwise the name of the missing equipment.
func missing_tool_for_part(part_id: String) -> String:
	var needs: String = GameData.PARTS[part_id].needs
	if needs == "" or has_shop_tool(needs):
		return ""
	if needs == "jack" and can_lift():
		return ""   # a full lift does the jack's job
	var up := GameData.upgrade_by_id(needs)
	return up.get("name", needs)

# ---------------- the pound ----------------
## What the city wants to give it back. Bigger truck, bigger bill.
func impound_fee() -> int:
	return 450 * truck_level + 50 * int(stats.busted)

## Pay up and have it dropped back at the shop. "" on success.
func recover_truck() -> String:
	if not truck_impounded:
		return "It is not in the pound."
	var fee := impound_fee()
	if not can_afford(fee):
		return "You cannot cover the fee. Steal it back, then."
	add_money(-fee)
	release_truck()
	var t := truck()
	if t:
		t.global_position = World.GARAGE_POS + World.TRUCK_SPACE
		t.rotation.y = PI
	notify.emit("RELEASED", "They took $%d and gave it back." % fee)
	return ""

## Out of the pound, however you managed it.
func release_truck() -> void:
	if not truck_impounded:
		return
	truck_impounded = false
	var t := truck()
	if t:
		t.locked = false
		t.hotwired = true
	inventory_changed.emit()

# ---------------- haulage ----------------
## Highest car tier the hitch can drag.
func tow_tier() -> int:
	var best := 0
	for id in GameData.TOW_TIERS.keys():
		if has_shop_tool(id):
			best = maxi(best, int(GameData.TOW_TIERS[id]))
	return best

func truck() -> Truck:
	return get_tree().get_first_node_in_group("truck") as Truck

func cargo_value(buyer_id: String) -> int:
	var t := truck()
	if t == null:
		return 0
	var total := 0.0
	for c in t.cargo:
		total += float(c.value) * GameData.buyer_mult(buyer_id, String(c.part))
	return int(round(total * part_price_mult()))

func note_part_pulled() -> void:
	stats.parts += 1
	inventory_changed.emit()

# ---------------- the belt ----------------
## How many loops the belt has. Buying a bigger one never loses you anything.
func belt_slots() -> int:
	var best: int = int(GameData.BELTS[""])
	for id in GameData.BELTS.keys():
		if id != "" and has_shop_tool(id):
			best = maxi(best, int(GameData.BELTS[id]))
	return best

## Grow or shrink the belt to match, keeping whatever was already on it.
func sync_belt() -> void:
	var want := belt_slots()
	var before := hotbar.size()
	var was := selected
	while hotbar.size() < want:
		hotbar.append("")
	while hotbar.size() > want:
		hotbar.pop_back()
	selected = clampi(selected, 0, maxi(0, hotbar.size() - 1))
	# only when something actually moved: this runs off `held()`, which is
	# asked several times a frame, and anything that reads the belt from the
	# signal would end up straight back in here
	if hotbar.size() != before or selected != was:
		kit_changed.emit()

func held() -> String:
	sync_belt()
	if selected < 0 or selected >= hotbar.size():
		return ""
	return String(hotbar[selected])

func held_item() -> Dictionary:
	var id := held()
	return GameData.ITEMS.get(id, {})

## The weapon behind whatever is in your hand, or {} if it is not a gun.
func held_weapon() -> Dictionary:
	var item := held_item()
	if String(item.get("kind", "")) != "gun":
		return {}
	return GameData.WEAPONS.get(String(item.get("weapon", "")), {})

## Guns hold different numbers of rounds, so switching to one you have not
## fired yet hands you a full clip rather than the last gun's leftovers.
func on_weapon_swapped() -> void:
	var gun := held_weapon()
	if gun.is_empty():
		return
	ammo = mini(ammo, int(gun.clip))
	if ammo <= 0:
		ammo = int(gun.clip)

## What is on the belt right now, for reading back in a panel.
func belt_summary() -> String:
	var names := []
	for id in hotbar:
		if String(id) != "":
			names.append(String(GameData.ITEMS.get(String(id), {}).get("name", id)))
	return ", ".join(names) if not names.is_empty() else "nothing"

func carrying_item(id: String) -> bool:
	return hotbar.has(id)

func select_slot(i: int) -> void:
	sync_belt()
	if i >= 0 and i < hotbar.size():
		selected = i
		on_weapon_swapped()
		kit_changed.emit()

func cycle_slot(step: int) -> void:
	sync_belt()
	if hotbar.is_empty():
		return
	selected = wrapi(selected + step, 0, hotbar.size())
	kit_changed.emit()

## Put an owned item on the belt, or take it off again.
func toggle_on_belt(id: String) -> String:
	sync_belt()
	if not owned_items.has(id):
		return "You do not own one."
	var at := hotbar.find(id)
	if at >= 0:
		hotbar[at] = ""
		kit_changed.emit()
		return ""
	var free := hotbar.find("")
	if free < 0:
		return "No room on the belt. Take something off, or buy a bigger one."
	hotbar[free] = id
	kit_changed.emit()
	return ""

## After the belt grows, put anything you own but were not carrying into the
## new loops. Buying a belt and still not having your pistol on you is just a
## puzzle nobody asked for.
func fill_free_loops() -> void:
	sync_belt()
	for id in owned_items:
		if hotbar.has(id):
			continue
		var free := hotbar.find("")
		if free < 0:
			break
		hotbar[free] = id
	kit_changed.emit()

## Everything you own that is not on you. It lives on the workbench.
func stored_items() -> Array:
	var out := []
	for id in owned_items:
		if not hotbar.has(id):
			out.append(id)
	return out

## Called when a new holdable is bought.
func acquire_item(id: String) -> void:
	if not owned_items.has(id):
		owned_items.append(id)
	sync_belt()
	var free := hotbar.find("")
	if free >= 0 and not hotbar.has(id):
		hotbar[free] = id
	kit_changed.emit()

# ---------------- shooting ----------------
func armed() -> bool:
	return has_shop_tool("pistol")

func set_health(hp: int) -> void:
	health = clampi(hp, 0, 100)
	health_changed.emit(health)

## Anyone taking a shot at the police is no longer a car thief, they are a
## much bigger problem. Straight to three stars.
func note_shot_a_copper() -> void:
	stats.cops_shot += 1
	set_wanted(3)

# ---------------- wanted ----------------
func set_wanted(stars: int) -> void:
	stars = clampi(stars, 0, 3)
	if stars == wanted:
		return
	wanted = stars
	wanted_changed.emit(wanted)

func raise_wanted(amount: int = 1) -> void:
	set_wanted(wanted + amount)

# ---------------- purchasing ----------------
func is_owned(up: Dictionary) -> bool:
	match up.kind:
		"theft_tool":
			return owned_theft_tools.get(up.tool, 0) >= up.level
		"shop_tool":
			return owned_shop_tools.has(up.tool)
		"garage":
			return garage_level >= up.level
		"truck":
			return truck_level >= up.level
		"buyer":
			return unlocked_buyers.has(up.buyer)
	return false

## Returns "" on success, otherwise the reason it failed.
func buy(up: Dictionary) -> String:
	if is_owned(up):
		return "Already owned."
	if not can_afford(up.price):
		return "Not enough cash."
	if up.kind == "garage" and garage_level != int(up.level) - 1:
		return "Upgrade the previous tier first."
	if up.kind == "truck" and truck_level != int(up.level) - 1:
		return "Buy the previous truck first."
	if up.id == "hitch2" and not has_shop_tool("hitch"):
		return "Get a basic tow hitch first."
	if up.id == "belt_large" and not has_shop_tool("belt"):
		return "Buy the ordinary tool belt first."
	add_money(-int(up.price))
	match up.kind:
		"theft_tool":
			owned_theft_tools[up.tool] = maxi(owned_theft_tools.get(up.tool, 0), int(up.level))
			skill_changed.emit()
		"shop_tool":
			owned_shop_tools[up.tool] = true
			if GameData.ITEMS.has(String(up.tool)):
				acquire_item(String(up.tool))
			sync_belt()
			if String(up.tool).begins_with("belt"):
				fill_free_loops()
		"garage":
			garage_level = int(up.level)
		"truck":
			truck_level = int(up.level)
			truck_changed.emit()
		"buyer":
			unlocked_buyers.append(String(up.buyer))
	notify.emit("PURCHASED", up.name)
	return ""
