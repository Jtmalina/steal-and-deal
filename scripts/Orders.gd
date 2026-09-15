extends RefCounted
class_name Orders
# ============================================================
#  The board in the back of the shop. Somebody wants specific
#  things by a specific day and will pay over the odds for them.
#
#  An order is a car, a short list of parts off it, and a
#  deadline. Filling one is the difference between stripping
#  whatever turns up and going out to look for something.
# ============================================================

## How many are on the board at once, and how long each one runs.
const SLOTS := 3
const DAYS_MIN := 2.0
const DAYS_MAX := 5.0
## What the premium looks like against selling the parts loose.
const PAY_MIN := 1.7
const PAY_MAX := 2.6

## Who is asking. Flavour, but it is also who you annoy by missing one.
const CLIENTS := [
	"Marta at the yard", "the Kirby brothers", "a man who calls himself Vaughn",
	"the body shop on Fourth", "somebody's cousin", "the fence on Alder",
]

## Build a fresh order. Seeded so a save reloads the same board.
static func make(rng: RandomNumberGenerator) -> Dictionary:
	var cars: Array = GameData.VEHICLES
	var car: Dictionary = cars[rng.randi() % cars.size()]
	var pool: Array = (car.parts as Array).duplicate()
	# nobody orders a catalytic converter and a wing mirror together; the
	# wanted list is the big stuff, and only what this car actually has
	var want := []
	var tries := 0
	while want.size() < rng.randi_range(2, 3) and tries < 40:
		tries += 1
		var pid := String(pool[rng.randi() % pool.size()])
		if not want.has(pid) and int(GameData.PARTS[pid].base_value) >= 40:
			want.append(pid)
	if want.is_empty():
		want.append(String(pool[0]))
	var pay := 0
	for pid: String in want:
		pay += GameData.part_value(pid, float(car.part_mult), 0.9)
	var mult := rng.randf_range(PAY_MIN, PAY_MAX)
	return {
		"client": CLIENTS[rng.randi() % CLIENTS.size()],
		"car": String(car.id),
		"car_name": String(car.name),
		"parts": want,
		"pay": int(round(float(pay) * mult)),
		"due": GameState.minutes + rng.randf_range(DAYS_MIN, DAYS_MAX) * 24.0 * 60.0,
		"filled": [],
	}

## Days left, negative once it has been missed.
static func days_left(order: Dictionary) -> float:
	return (float(order.due) - GameState.minutes) / (24.0 * 60.0)

static func expired(order: Dictionary) -> bool:
	return days_left(order) <= 0.0

static func done(order: Dictionary) -> bool:
	return (order.filled as Array).size() >= (order.parts as Array).size()

## Does this loose part count towards this order? It has to be the right part
## off the right model, and one they have not already had.
static func wants(order: Dictionary, part_id: String, from_car: String) -> bool:
	if expired(order) or done(order):
		return false
	if String(from_car) != String(order.car):
		return false
	return (order.parts as Array).has(part_id) and not (order.filled as Array).has(part_id)

static func describe(order: Dictionary) -> String:
	var names := []
	for pid: String in order.parts:
		names.append(String(GameData.PARTS[pid].name) + (" [done]" if (order.filled as Array).has(pid) else ""))
	return "%s off a %s: %s" % [String(order.client), String(order.car_name), ", ".join(names)]
