extends Node
# Headless loop check:  godot --headless --quit-after 3000 -- --smoke
# Walks the whole core loop by calling the same entry points the player uses.

var player: Player
var world: World
var hud: HUD
var step := 0
var t := 0.0
var car: Vehicle

# acceleration check
var drive_car: Vehicle
var driving := false
var drive_t := 0.0
var next_sample := 0.0
var samples := []

func _ready() -> void:
	# every other check assumes you can be seen, so the clock is held at midday
	# and only the day/night step is allowed to move it
	GameState.minutes = 12.0 * 60.0
	GameState.set_process(false)

func _process(delta: float) -> void:
	if driving or watching or busy:
		return
	t += delta
	if t < 0.25:
		return
	t = 0.0
	match step:
		0:
			hud.close_panel()
			car = _find_car()
			assert(car != null, "no stealable car spawned")
			print("[SMOKE] target: %s tier %d, %d lock spots, %.2fm slop" % [
				car.data.name, car.data.tier,
				GameState.jimmy_hotspots(car.data), GameState.jimmy_tolerance(car.data)])
			# difficulty has to move the right way with tier and with skill
			var junk := GameData.vehicle_by_id("rustbucket")
			var posh := GameData.vehicle_by_id("luxury")
			assert(GameState.jimmy_tolerance(junk) > GameState.jimmy_tolerance(posh),
				"a luxury car should be fiddlier than a junker")
			assert(GameState.jimmy_hotspots(posh) > GameState.jimmy_hotspots(junk),
				"nicer cars should need more catches")
			var before := GameState.jimmy_tolerance(posh)
			GameState.theft_level += 3
			assert(GameState.jimmy_tolerance(posh) > before, "skill should widen the slop")
			GameState.theft_level -= 3
		1:
			# jimmy the door, which hands over to the hotwire rig once the door
			# has had a moment to actually swing
			busy = true
			player._on_breakin_result(car, true)
			assert(not car.locked, "door did not open")
			await get_tree().create_timer(1.2).timeout
			busy = false
			# the swing is a tween, so it is only there once it has run
			assert(not car.has_door("door_l") or car.door_open("door_l"),
				"the driver door did not swing open when it came unlocked")
			assert(hud._teardown.active, "hotwire rig did not start after the door opened")
			var wires := 0
			var decoys := 0
			for st in GameData.HOTWIRE_STAGES:
				for pd in st.get("props", []):
					if String(st.type) == "WIRE":
						if bool(pd.get("decoy", false)):
							decoys += 1
						else:
							wires += 1
			assert(wires == 3 and decoys == 3, "expected 3 live wires and 3 decoys, got %d/%d" % [wires, decoys])
			print("[SMOKE] jimmied open. %d live wires, %d decoys to avoid." % [wires, decoys])
		2:
			# a car whose doors are part of its body shell has nothing to swing
			assert(not car.has_door("door_l") or car.door_open("door_l"),
				"jimmying should have swung the driver door open")
			hud._teardown.debug_finish_all()
			assert(car.hotwired, "car never started")
			assert(player.current_vehicle == car, "player did not end up driving it")
			print("[SMOKE] hotwired and driving. wanted=%d" % GameState.wanted)
		3:
			GameState.set_wanted(0)
			get_tree().call_group("police_dispatch", "clear_pursuit")
			# Rolling through the door is no longer enough: it has to be left
			# on a marked ramp with nobody in it.
			# just inside the door, short of the ramps
			car.global_position = World.GARAGE_POS + Vector3(0, 0.6, -6.0)
			world._on_garage_body_entered(car)
			assert(not car.is_job, "just driving inside handed the car over")
			assert(world.bay_at(car.global_position) < 0,
				"standing short of the ramps counts as being on one")
			car.global_position = world._bays[0] + Vector3(0, 0.6, 0)
			assert(world.bay_at(car.global_position) == 0, "that is not on bay 0")
			await get_tree().physics_frame
			player.exit_vehicle()
			assert(car.is_job, "car did not become a job after getting out on the ramp")
			assert(player.current_vehicle == null, "still behind the wheel")
			# and it is not a one-way trip: a whole car comes back off again
			assert(world.jobs.has(car), "the shop does not think it has it")
			assert(car.can_roll(), "a freshly delivered car is missing a wheel")
			assert(world.release_from_bay(car), "could not take it back off the ramp")
			assert(not car.is_job and not car.locked and car.hotwired,
				"off the ramp but not drivable")
			assert(not world.jobs.has(car), "still on the shop books after coming off")
			player.enter_vehicle(car)
			assert(player.current_vehicle == car, "could not get back into it")
			player.exit_vehicle()
			assert(car.is_job, "putting it back on the ramp did not take")
			# up on stands with a wheel off, it goes nowhere
			car.parts_remaining.erase("wheel_fr")
			assert(not car.can_roll(), "it thinks it can drive on three wheels")
			assert(not world.release_from_bay(car), "let us drive off a wheel short")
			assert(car.is_job, "a refused release took it off the books anyway")
			car.parts_remaining.append("wheel_fr")
			print("[SMOKE] a whole car comes back off the ramp; a wheel short, it stays put")
			print("[SMOKE] delivered. %d pieces, est $%d" % [car.parts_remaining.size(), car.estimated_value()])
		4:
			assert(not car.door_open("door_l"), "the door was left hanging open after hotwiring")

			var shell_before := car.shell_value()
			hud.open_dismantle(car)
			# nothing comes off with your bare hands: the wrench lives on the
			# bench and has to go on the belt in place of something else
			assert(hud._part_block_reason(car, "hood").contains("belt"),
				"the hood came off without a wrench: %s" % hud._part_block_reason(car, "hood"))
			assert(GameState.toggle_on_belt("jimmy") == "", "could not take the jimmy off")
			assert(GameState.toggle_on_belt("socket_wrench") == "", "could not put the wrench on")
			assert(hud._part_block_reason(car, "hood") == "",
				"the hood is still blocked with a wrench in hand: %s" % hud._part_block_reason(car, "hood"))
			print("[SMOKE] the wrench off the bench is what unbolts a hood")

			# drive the real 3D teardown rig once, to prove it builds and completes
			hud._start_part(car, "hood", false)
			assert(hud._teardown.active, "teardown rig did not start")
			hud._teardown.debug_finish_all()
			assert(not car.parts_remaining.has("hood"), "hood survived the teardown rig")
			assert(player.carrying != null, "the pulled part did not end up in the hands")
			player.drop_carried()
			GameState.owned_shop_tools["jack"] = true
			GameState.owned_shop_tools["lift"] = true
			GameState.owned_shop_tools["bench"] = true
			car.set_lifted(true)
			# keep sweeping until nothing else unlocks -- proves the teardown
			# order chains (hood -> battery -> engine, door -> seat) resolve
			var pulled := 1
			var progress := true
			while progress:
				progress = false
				for pid in car.parts_remaining.duplicate():
					if hud._part_block_reason(car, pid) != "":
						continue
					hud.debug_remove(car, pid)
					pulled += 1
					progress = true
			assert(car.parts_remaining.is_empty(), "stuck with parts left: %s" % str(car.parts_remaining))
			# job done: the wrench goes back on the bench and the jimmy back on
			# the belt, the way you would before going out again
			GameState.toggle_on_belt("socket_wrench")
			GameState.toggle_on_belt("jimmy")
			assert(car.shell_value() < shell_before, "crush price did not drop as parts came off")
			print("[SMOKE] stripped to %d pieces on the floor. crush price %d -> %d" % [pulled, shell_before, car.shell_value()])
		5:
			var truck := GameState.truck()
			assert(truck != null, "no truck parked at the shop")
			var loaded := 0
			var left := 0
			for n in get_tree().get_nodes_in_group("loose_part"):
				var item := n as PartItem
				if not truck.can_take(item):
					left += 1
					continue
				player.pick_up(item)
				assert(player.carrying == item, "part did not go into the hands")
				player.load_into_truck(truck)
				loaded += 1
			assert(loaded > 0, "nothing went into the truck")
			assert(truck.used() <= truck.capacity(), "overloaded the truck")
			print("[SMOKE] loaded %d parts (%d/%d units), %d left on the floor" % [
				loaded, truck.used(), truck.capacity(), left])
		6:
			var truck := GameState.truck()
			var before := GameState.money
			hud.open_scrapyard()          # too far away -- should refuse
			truck.global_position = World.SCRAP_POS + Vector3(0, 0.7, 5)
			hud.open_scrapyard()
			hud._sell_to("scrap")
			assert(GameState.money > before, "sold nothing at the yard")
			assert(truck.cargo.is_empty(), "cargo did not leave the truck")
			print("[SMOKE] hauled it over and sold for $%d, balance $%d" % [GameState.money - before, GameState.money])
		7:
			GameState.add_money(60000)
			for id in ["sawzall", "toolset", "impact", "hoist", "jimmy2", "garage2",
					"hitch", "truck2", "buyer_mechanic", "buyer_shady"]:
				var err := GameState.buy(GameData.upgrade_by_id(id))
				assert(err == "", "buy %s failed: %s" % [id, err])
			assert(GameState.truck_level == 2, "truck did not upgrade")
			var truck := GameState.truck()
			assert(truck.capacity() == 48, "capacity did not follow the upgrade: %d" % truck.capacity())
			print("[SMOKE] upgrades: truck %d (cap %d), buyers %s, %.2f turns per fastener" % [
				GameState.truck_level, truck.capacity(), str(GameState.unlocked_buyers), GameState.bolt_turns()])
		8:
			var truck := GameState.truck()
			truck.global_position = World.GARAGE_POS + World.TRUCK_SPACE + Vector3(0, 0.65, 0)
			var junker := _spawn_job("rustbucket")
			assert(truck.can_tow(junker), "hitch will not take a junker")
			truck.hitch(junker)
			assert(truck.towed == junker, "car did not hitch up")
			var sports := _spawn_job("sports")
			assert(not truck.can_tow(sports), "basic hitch should refuse a tier-3 car")
			sports.queue_free()
			world.jobs.erase(sports)
			var before := GameState.money
			var whole := junker.shell_value()
			GameState.add_money(whole)
			truck.unhitch()
			junker.queue_free()
			world.jobs.erase(junker)
			assert(GameState.money - before == whole, "whole-car sale did not pay out")
			print("[SMOKE] towed a junker in whole for $%d" % whole)
		9:
			_start_traffic_watch()
		10:
			_start_drive_test()
		11:
			hud.close_panel()
		12:
			_check_join()
		13:
			_check_street()
		14:
			_check_getting_out()
		15:
			_check_sight()
		16:
			_check_guns()
		17:
			_check_belt()
		18:
			_check_bystanders()
		19:
			_check_model_part()
		20:
			_check_road_rules()
		21:
			_check_carjack()
		22:
			_check_impound()
		23:
			_check_daynight()
		24:
			_check_save()
		25:
			await _check_tooling()
		26:
			await _check_nicked_mid_job()
		27:
			GameState.raise_wanted(2)
			get_tree().call_group("police_dispatch", "dispatch")
		28:
			await _check_aim_and_heat()

			# Every sound bank has to resolve to real files. A typo in a path
			# is silent -- literally -- so it would never show up otherwise.
			var quiet := []
			var takes := 0
			var banks: Array = Sfx.BANKS.keys()
			for kind in Sfx.VOICE_KINDS.keys():
				banks.append("voice_male_%s" % kind)
				banks.append("voice_female_%s" % kind)
			for b in banks:
				var n: int = Sfx._files(String(b)).size()
				takes += n
				if n == 0:
					quiet.append(String(b))
			assert(quiet.is_empty(), "sound banks with nothing in them: %s" % str(quiet))
			assert(Sfx._take("step_walk") != null, "a footstep bank loaded no audio")
			print("[SMOKE] %d sound banks, %d takes between them" % [banks.size(), takes])

			# the truck you start with is a real one, on wheels of its own
			var lorry := GameState.truck()
			assert(lorry != null, "no truck")
			assert(lorry._wheels.size() == 4,
				"the pickup rolls on %d wheels" % lorry._wheels.size())
			assert(lorry.sound_set() == "truck", "the pickup sounds like a saloon")
			print("[SMOKE] the pickup is a model with %d wheels on it" % lorry._wheels.size())

			# Whoever is behind the wheel has to be IN the cab: hips inside the
			# interior the model actually has, not at some fraction of the
			# vehicle's overall height -- which on a van includes the roof box
			# and on a pickup the tray, and put the driver in the load area.
			for def: Dictionary in GameData.VEHICLES:
				if not def.has("model"):
					continue
				var demo := Vehicle.new()
				demo.setup(def.duplicate(true))
				world.add_child(demo)
				await get_tree().physics_frame
				var post: Vector3 = demo._steering_post()
				assert(post != Vector3.ZERO,
					"%s has no steering wheel to seat anybody by" % String(def.name))
				var seat := demo.seat_point(true)
				var cab := demo.part_bounds("seat_l")
				assert(seat.x < 0.0, "%s seats the driver on the wrong side" % String(def.name))
				if cab.size != Vector3.ZERO:
					assert(absf(seat.x - cab.get_center().x) < 0.55,
						"%s: hips at x %.2f, its seat is at %.2f" % [
							String(def.name), seat.x, cab.get_center().x])
					assert(absf(seat.z - cab.get_center().z) < 0.9,
						"%s: hips at z %.2f, its seat is at %.2f" % [
							String(def.name), seat.z, cab.get_center().z])
				var fit := demo.occupant_scale()
				# seat_point IS the hip, so the head is one torso above it
				var head: float = seat.y + 1.25 * fit
				assert(head < demo._cabin_height() + 0.05,
					"%s: their head is %.2f, the roof is %.2f" % [
						String(def.name), head, demo._cabin_height()])
				assert(seat.y > 0.3, "%s seats the driver in the floor pan" % String(def.name))
				demo.queue_free()
			print("[SMOKE] every model seats its driver off its own steering wheel")

			# A patrol car carries a crew of two and is not a hole that cops
			# climb out of forever.
			var cruiser := PoliceCar.new()
			cruiser.setup(PoliceDispatch.COP_DATA.duplicate(true))
			world.add_child(cruiser)
			cruiser.global_position = player.global_position + Vector3(14, 0, 8)
			await get_tree().physics_frame
			assert(cruiser.has_occupant() and cruiser.passenger != null,
				"a cruiser turned up with nobody in it")
			var made := 0
			for _try in 8:
				cruiser._get_out()
				made = get_tree().get_nodes_in_group("police_foot").size()
			assert(cruiser._aboard == 0, "the car still thinks it has a crew aboard")
			assert(cruiser._out.size() == PoliceCar.CREW,
				"eight attempts put %d officers on the pavement" % cruiser._out.size())
			assert(not cruiser.occupant.visible and not cruiser.passenger.visible,
				"they are out of the car and still sat in it")
			cruiser.officer_aboard(cruiser._out[0])
			assert(cruiser._aboard == 1, "one got back in and the count did not move")
			assert(cruiser.occupant.visible, "back in the car and not in the seat")
			cruiser.queue_free()
			print("[SMOKE] a patrol car carries two, lets them out one at a time, and stops")

			# --- heat on the car, and what takes it off ---
			var hot := world.spawn_vehicle("sedan", player.global_position + Vector3(11, 0, 5))
			await get_tree().physics_frame
			assert(hot.heat_now() == 0.0, "a car nobody has touched is already hot")
			hot.mark_hot()
			var hot_new := hot.heat_now()
			assert(hot_new > 0.3, "taking a car off somebody did not make it hot")
			hot.repaint(GameData.PAINTS[3])
			var painted := hot.heat_now()
			assert(painted < hot_new - 0.01, "a respray took nothing off it")
			hot.panels_done = GameData.HEAT_PANELS_NEEDED
			assert(hot.heat_now() <= 0.001,
				"respray plus panels left %.2f on it" % hot.heat_now())
			# and it goes stale on its own given long enough
			hot.resprayed = false
			hot.panels_done = 0
			var was_min := GameState.minutes
			GameState.minutes += GameData.CAR_HEAT_DAYS * 24.0 * 60.0 + 10.0
			assert(hot.heat_now() == 0.0, "a fortnight later and it is still on the list")
			GameState.minutes = was_min

			# --- damage lands on the panel that took it, not the whole car ---
			hot.mark_hot()
			var door_was := hot.part_condition("door_l")
			var trunk_was := hot.part_condition("trunk")
			hot.hurt_from(hot.global_position + hot.global_transform.basis
				* hot.part_bounds("door_l").get_center(), 0.4)
			assert(hot.part_condition("door_l") < door_was - 0.2,
				"the door took the hit and did not mark")
			assert(hot.part_condition("trunk") > trunk_was - 0.15,
				"a hit on the door wrecked the boot lid too")
			var priced := GameData.part_value("door_l", float(hot.data.part_mult),
				hot.part_condition("door_l"))
			var priced_ok := GameData.part_value("door_l", float(hot.data.part_mult), door_was)
			assert(priced < priced_ok, "a bent door sells for the same as a straight one")
			hot.queue_free()
			print("[SMOKE] car heat clears by respray + panels, and damage is per panel")

			# --- every panel on a car wears the same paint ---
			for def2: Dictionary in GameData.VEHICLES:
				if not def2.has("model"):
					continue
				var painted_car := Vehicle.new()
				painted_car.setup(def2.duplicate(true))
				world.add_child(painted_car)
				await get_tree().physics_frame
				var want: Color = painted_car.data.get("color", Color.WHITE)
				for pid: String in Vehicle.PAINTED_PARTS:
					for n in painted_car._part_meshes.get(pid, []):
						var mi := n as MeshInstance3D
						if mi == null or mi.material_override == null:
							continue
						# a door carries its own window, and glass is not
						# meant to come out the colour of the bodywork
						if String(mi.name).to_lower().contains("glass"):
							continue
						var got: Color = (mi.material_override as StandardMaterial3D).albedo_color
						assert(got.is_equal_approx(want),
							"%s: the %s (%s) is %s, the car is %s" % [
								String(def2.name), pid, String(mi.name), str(got), str(want)])
				painted_car.queue_free()
			print("[SMOKE] every cut-out panel comes out the same colour as the car")

			# --- the truck kept its wheels ---
			var pickup := GameState.truck()
			assert(pickup != null and pickup._wheels.size() == 4,
				"the pickup is sat on %d wheels" % (pickup._wheels.size() if pickup else -1))
			for w in pickup._wheels:
				assert((w as Node3D).visible, "a truck wheel is there but not shown")
			print("[SMOKE] the truck has four wheels on it and all of them show")

			# --- the board always has work on it ---
			GameState.refresh_orders()
			assert(GameState.orders.size() == Orders.SLOTS,
				"the board has %d orders on it" % GameState.orders.size())
			var order: Dictionary = GameState.orders[0]
			assert(not (order.parts as Array).is_empty(), "an order that wants nothing")
			assert(int(order.pay) > 0, "an order that pays nothing")
			assert(Orders.days_left(order) > 0.0, "a fresh order is already late")
			var want_id := String((order.parts as Array)[0])
			assert(Orders.wants(order, want_id, String(order.car)), "the board will not take what it asked for")
			assert(not Orders.wants(order, want_id, "not_that_car"),
				"the board takes that part off any car at all")
			print("[SMOKE] board: %d orders, top one pays $%d" % [GameState.orders.size(), int(order.pay)])

			# --- the city got bigger and stopped being graph paper ---
			var gaps := []
			for i in range(World.ROADS.size() - 1):
				gaps.append(float(World.ROADS[i + 1]) - float(World.ROADS[i]))
			gaps.sort()
			assert(World.ROADS.size() >= 8, "the grid is still %d roads" % World.ROADS.size())
			assert(gaps[gaps.size() - 1] - gaps[0] > 6.0,
				"every block is the same size (%.0f to %.0f)" % [gaps[0], gaps[gaps.size() - 1]])
			assert(World.BLOCKS.size() == World.ROADS.size() - 1, "blocks do not fill the grid")
			assert(World.PLOTS.size() == World.BLOCKS.size(), "a block with no plot size")
			assert(world.station != Vector3.ZERO, "there is no police station anywhere")
			assert(world.doorways.size() > 6,
				"only %d front doors in the whole city" % world.doorways.size())
			# what the city handed out when it was built -- by now some of them
			# have been shot at, chased somebody, or been called away, and who
			# is still stood on their spot is the chase code's business
			var posted := world.station_posts.size()
			assert(posted >= 3, "%d officers posted at the station" % posted)
			for post: Vector3 in world.station_posts:
				assert(post.distance_to(world.station) < 12.0,
					"an officer was posted %.0fm from the station" % post.distance_to(world.station))
			print("[SMOKE] city: %d roads, blocks %.0f-%.0fm, %d front doors, %d posted at the station" % [
				World.ROADS.size(), gaps[0], gaps[gaps.size() - 1], world.doorways.size(), posted])

			# --- nothing built on a block may hang over the pavement ---
			# Measured against the plot the block was given. Flat markings on
			# the ground are exempt: a cul-de-sac mouth is meant to reach the
			# kerb. Anything with a collision box is not.
			var over := []
			for xi in World.BLOCKS.size():
				for zi in World.BLOCKS.size():
					var kind := String(World.DISTRICTS[xi][zi])
					if kind in ["scrap", "impound"]:
						continue
					var centre := Vector3(World.BLOCKS[xi], 0, World.BLOCKS[zi])
					var room: float = minf(World.PLOTS[xi], World.PLOTS[zi]) + 0.6
					var worst_over := 0.0
					var culprit := ""
					# Only what this block put down. The nearest thing the next
					# block along stands is 32m from here, so anything whose
					# origin is inside 30 belongs to this one -- reach any
					# further and every house is measured against its
					# neighbour's plot as well as its own.
					for n in _solids_near(centre, 30.0, ["Waterfront", "Yard", "Spur", "Ground"]):
						var box: AABB = n.global_transform * _shape_box(n)
						var dx: float = maxf(absf(box.position.x - centre.x),
							absf(box.end.x - centre.x))
						var dz: float = maxf(absf(box.position.z - centre.z),
							absf(box.end.z - centre.z))
						if maxf(dx, dz) - room > worst_over:
							worst_over = maxf(dx, dz) - room
							culprit = "%s %s %s" % [n.name, str(n.get_parent().name), str(box)]
					if worst_over > 0.01:
						over.append("%s at %d,%d by %.1fm (%s)" % [kind, xi, zi, worst_over, culprit])
			assert(over.is_empty(), "buildings hanging off their plot: %s" % str(over))
			print("[SMOKE] every block stays inside its own plot")

			# --- and nothing solid stands in a road or on a crossing ---
			# The dock used to run four sheds and five rows of containers
			# straight across the western avenues, and the avenue the shop is
			# on carried on under the shop itself. A road you cannot drive down
			# is not a road, and a crossing with a container on it is a wall.
			var in_the_way := []
			var all_solids := []
			_gather_solids(world, Vector3.ZERO, 1.0e9, all_solids)
			var checked := 0
			for n in all_solids:
				var box: AABB = n.global_transform * _shape_box(n)
				# tarmac, paint and kerbs all live below this; anything you
				# would actually hit stands above it
				if box.end.y < 0.35:
					continue
				checked += 1
				var where := ""
				for c: float in World.ROADS:
					if _on_patch(box, -World.GRID_END, World.GRID_END,
							c - World.ROAD_HALF, c + World.ROAD_HALF):
						where = "the road at z=%.0f" % c
					if _on_patch(box, c - World.ROAD_HALF, c + World.ROAD_HALF,
							-World.GRID_END, World.GRID_END):
						where = "the road at x=%.0f" % c
				# and the spur, which is the only carriageway off the grid
				if _on_patch(box, World.GARAGE_POS.x - World.ROAD_HALF,
						World.GARAGE_POS.x + World.ROAD_HALF, World.GRID_END,
						World.GARAGE_POS.z + World.YARD_OFF - World.YARD_D):
					where = "the spur to the yard"
				# the four crossings on every junction
				for cx: float in World.ROADS:
					for cz: float in World.ROADS:
						for side: float in [-1.0, 1.0]:
							var zx := cz + side * World.PAVE
							if _on_patch(box, cx - 6.2, cx + 6.2, zx - 1.4, zx + 1.4):
								where = "the crossing at %.0f,%.0f" % [cx, zx]
							var xx := cx + side * World.PAVE
							if _on_patch(box, xx - 1.4, xx + 1.4, cz - 6.2, cz + 6.2):
								where = "the crossing at %.0f,%.0f" % [xx, cz]
				if where != "":
					in_the_way.append("%s (%.0f,%.0f) on %s" % [
						n.name, box.get_center().x, box.get_center().z, where])
			assert(in_the_way.is_empty(), "%d solids standing in the road: %s" % [
				in_the_way.size(), str(in_the_way.slice(0, 6))])
			print("[SMOKE] %d solids checked, every road and crossing is clear" % checked)

			# --- and the shop faces the way you arrive at it ---
			var gate := World.GARAGE_POS + Vector3(0, 0, World.YARD_OFF - World.YARD_D)
			var spawn: Node3D = get_tree().get_first_node_in_group("garage_spawn")
			assert(spawn != null, "the shop has no forecourt to come back to")
			assert(spawn.global_position.distance_to(gate) < World.GARAGE_POS.distance_to(gate),
				"the shop doors face away from the gate")
			for b: Vector3 in world._bays:
				assert(b.distance_to(gate) > spawn.global_position.distance_to(gate),
					"a ramp is out on the forecourt rather than inside the shed")
			assert(gate.z > World.GRID_END, "the yard gate is inside the street grid")
			print("[SMOKE] the shop faces the gate, %.0fm up the spur" % (gate.z - World.GRID_END))

			# --- the industrial end keeps cheap cars in it ---
			assert(world.industrial(World.GARAGE_POS), "the shop is not in the industrial end")
			assert(not world.industrial(Vector3(World.BLOCKS[3], 0, World.BLOCKS[3])),
				"the middle of town counts as industrial")
			var dock_rng := RandomNumberGenerator.new()
			dock_rng.seed = 31337
			var worst := 1
			for i in 60:
				var def3 := world._pick_vehicle_def(dock_rng, World.GARAGE_POS + Vector3(6, 0, 22))
				worst = maxi(worst, int(def3.tier))
			assert(worst <= 2, "a tier-%d car parked itself down the docks" % worst)
			print("[SMOKE] the industrial end tops out at tier %d" % worst)

			# --- and the shop is behind a fence with a shed next to it ---
			var yard := world.get_node_or_null("Yard")
			assert(yard != null, "the shop has no yard round it")
			assert(world.get_node_or_null("Waterfront") != null, "the town does not reach the water")
			assert(world._bays.size() == GameState.garage_level,
				"%d bays for a tier-%d shop" % [world._bays.size(), GameState.garage_level])

			# Nothing drives about half-built. Vehicle hides any panel missing
			# from a definition's parts list, so a definition that leaves the
			# structural ones out puts a car on the road with no wheels.
			var defs: Array = GameData.VEHICLES.duplicate()
			defs.append(PoliceDispatch.COP_DATA)
			for def: Dictionary in defs:
				for must: String in ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl",
						"door_r", "door_l", "hood"]:
					assert((def.parts as Array).has(must),
						"a %s spawns with no %s on it" % [String(def.name), must])
			# and a car that has actually been built shows them
			var fresh := Vehicle.new()
			fresh.setup(PoliceDispatch.COP_DATA.duplicate(true))
			world.add_child(fresh)
			fresh.global_position = player.global_position + Vector3(9, 0, 6)
			await get_tree().physics_frame
			for must: String in ["wheel_fr", "door_l"]:
				assert(fresh.has_part_mesh(must), "a cruiser has no %s mesh at all" % must)
				var seen := false
				for n in fresh._part_meshes.get(must, []):
					if (n as Node3D).visible:
						seen = true
				assert(seen, "a freshly spawned cruiser is missing its %s" % must)
			fresh.queue_free()
			print("[SMOKE] every car spawns with its wheels, doors and hood on")

			# a marked car across town does not light up because you are wanted here,
			# and no civilian shape is ever wearing a bar
			var lit := 0
			var marked := 0
			for n in get_tree().get_nodes_in_group("vehicle"):
				var t := n as TrafficCar
				if t == null or not t.patrol:
					continue
				marked += 1
				assert(String(t.data.id) == "cop",
					"a %s is doing the rounds with a police bar on it" % String(t.data.name))
				if t.global_position.distance_to(player.global_position) > 70.0:
					for l in t._lightbar:
						if (l as MeshInstance3D).visible:
							lit += 1
			assert(lit == 0, "%d lightbars are blinking on cars nowhere near the player" % lit)
			print("[SMOKE] %d marked cars, all cruisers, none lit up from across town" % marked)
			print("[SMOKE] police units spawned: %d" % get_tree().get_nodes_in_group("police").size())
			print("[SMOKE] ALL GOOD")
			get_tree().quit()
	step += 1

## Nothing on the car is touched with bare hands. The wrench comes off the belt,
## gets carried to a bolt, and stays where it was put down between them.
func _check_tooling() -> void:
	busy = true
	GameState.add_money(4000)
	if not GameState.carrying_item("socket_wrench"):
		GameState.toggle_on_belt("socket_wrench")
	var car := world.spawn_job("rustbucket")
	await get_tree().physics_frame
	hud._start_part(car, "door_r", false)
	var td := hud._teardown
	assert(td.active, "the teardown rig would not start")
	td._stage = 1                       # the hinge bolts
	td._build_stage()
	assert(String(td._props[0].type) == "BOLT", "stage 1 is not the bolts")
	assert(is_instance_valid(td._tool), "no wrench turned up for a stage full of bolts")
	assert(td._tool_id == "socket_wrench" or td._tool_id == "impact_drill",
		"a stage full of bolts put a %s in our hand" % td._tool_id)
	assert(td._tool_on < 0, "the wrench started already sat on a bolt")
	# it hangs off the belt, down out of the way of the work
	var belt := (td._tool as Node3D).global_position
	for p in td._props:
		assert(belt.distance_to((p.node as Node3D).global_position) > 0.4,
			"the wrench spawned on top of the bolts instead of on your belt")

	# bare hands get you nowhere
	td._press(0)
	assert(td._grabbed < 0, "a bolt came undone by hand with a wrench sat on the belt")

	# carry it over and it takes
	td._tool.global_position = (td._props[0].node as Node3D).global_position
	td._tool_drag = true
	td._drop_tool()
	assert(td._tool_on == 0, "dropping the wrench on a bolt did not seat it")
	td._press(Teardown.TOOL_META)
	assert(td._grabbed == 0, "grabbing the seated wrench did not take hold of the bolt")

	# undo it, and the wrench stays at that bolt rather than pinging back
	var was := (td._tool as Node3D).global_position
	td._finish_prop(td._props[0], 0.1)
	assert(td._props[0].done, "the bolt did not come out")
	assert(td._tool_on < 0, "the wrench is still on a bolt that is gone")
	assert((td._tool as Node3D).global_position.distance_to(was) < 0.01,
		"the wrench reset itself instead of staying where it was left")
	assert((td._tool as Node3D).global_position.distance_to(belt) > 0.4,
		"the wrench went back to the belt between bolts")

	# and on to the next one
	td._tool.global_position = (td._props[1].node as Node3D).global_position
	td._tool_drag = true
	td._drop_tool()
	assert(td._tool_on == 1, "the wrench would not move on to the second bolt")
	print("[SMOKE] tools: wrench off the belt, onto bolt 1, stays put, then onto bolt 2")

	# the jimmy is not lying on the window waiting for you -- you bring it
	td.abort()
	var mark := _find_car()
	if mark != null and mark.locked:
		if not GameState.carrying_item("jimmy"):
			GameState.toggle_on_belt("jimmy")
		player.begin_breakin(mark)
		var jt := hud._teardown
		if jt.active:
			var jp: Dictionary = jt._props[0]
			if String(jp.type) == "JIMMY":
				assert(not (jp.mesh as Node3D).visible,
					"the jimmy was already at the window before we carried it there")
				assert(is_instance_valid(jt._tool) and jt._tool_id == "jimmy",
					"no jimmy on the belt to carry over")
				jt._tool.global_position = (jp.node as Node3D).global_position
				jt._tool_drag = true
				jt._drop_tool()
				assert(jt._tool_on == 0 and (jp.mesh as Node3D).visible,
					"carrying the jimmy to the window did not start the job")
				# it goes in on the seal first, with the rod out of sight
				assert(int(jp.phase) == 0, "the jimmy is in the door before it was shoved in")
				assert(not jt._jimmy_line.visible, "the lock rod is on show before the tool is in")
				# and nothing catches where it went in, or step two is already
				# solved the moment step one finishes
				var tol: float = GameState.jimmy_tolerance(mark.data)
				assert(not jt._jimmy_spots.is_empty(), "no catches on the rod at all")
				for spot: float in jt._jimmy_spots:
					assert(absf(spot) > tol,
						"a catch at %.2f is already under the tip at nought (slop %.2f)" % [spot, tol])
				print("[SMOKE] tools: jimmy goes in at the seal first, and no catch sits where it lands")
			jt.abort()
	hud.close_panel()
	if is_instance_valid(car):
		car.queue_free()
	busy = false

## Getting collared halfway through a job. The rig has to come down on its own,
## you have to end up back at the shop, and the car has to be gone -- not left
## running with a camera pointed at a vehicle nobody is holding any more.
func _check_nicked_mid_job() -> void:
	busy = true
	hud.close_panel()
	var mark := world.spawn_vehicle("rustbucket", player.global_position + Vector3(6, 0, 2))
	await get_tree().physics_frame
	mark.add_occupant(23)
	await get_tree().physics_frame
	player.begin_carjack(mark)
	assert(hud._teardown.active, "the carjack rig would not start")
	assert(player.stealing, "we are not marked as busy stealing")
	# the arrest bar builds rather than snapping straight to a bust. They have
	# to have hold of you for that, so stand one right next to us -- an officer
	# across the road is no longer close enough to nick anybody.
	GameState.raise_wanted(1)
	var collar := Node3D.new()
	collar.add_to_group("police")
	get_tree().current_scene.add_child(collar)
	collar.global_position = player.global_position + Vector3(1.0, 0, 0)
	player._busted_timer = 0.0
	player._check_busted(1.0)
	assert(hud._arrest_box.visible, "no sign they were arresting us")
	assert(hud._teardown.active, "one second of being grabbed ended the job on its own")
	# and then they get you
	player._busted_timer = Player.ARREST_SECS
	player._check_busted(0.2)
	assert(not hud._teardown.active, "the rig is still running after a bust")
	assert(not hud._arrest_box.visible, "the arrest bar is still up")
	assert(not player.stealing, "still marked as stealing after being nicked")
	assert(not is_instance_valid(mark) or mark.is_queued_for_deletion(),
		"the car we were caught in is still sat there")
	var garage: Node3D = get_tree().get_first_node_in_group("garage_spawn")
	if garage:
		assert(player.global_position.distance_to(garage.global_position) < 2.0,
			"we did not end up back at the shop")
	assert(GameState.wanted == 0, "still wanted after being taken in")
	collar.queue_free()
	print("[SMOKE] nicked mid-job: rig comes down, car is gone, back at the shop")
	busy = false

## Widest the visible geometry under a node gets, in world metres.
func _visual_span(root: Node3D) -> float:
	var box := AABB()
	var first := true
	for n in _all_under(root):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return 0.0 if first else maxf(box.size.x, maxf(box.size.y, box.size.z))

func _all_under(root: Node) -> Array:
	var out := []
	for c in root.get_children():
		out.append(c)
		out.append_array(_all_under(c))
	return out

## Sights and the heat readout. Held in its own step, with `busy` set, or
## the awaits in it let _process back in every frame and it runs on top of
## itself -- which is exactly what it did.
func _check_aim_and_heat() -> void:
	busy = true
	player.aiming_down = false
	for _f in 30:
		await get_tree().physics_frame
	# sights up: the shot comes in over the shoulder and goes back out
	var rest := player.arm.spring_length
	player.aiming_down = true
	for _f in 30:
		await get_tree().physics_frame
	assert(player.arm.spring_length < rest - 2.0,
		"aiming did not pull the camera in (%.1f)" % player.arm.spring_length)
	assert(player.arm.position.x > 0.4, "the camera did not step off the shoulder")
	var cam := player.arm.get_node_or_null("Camera3D") as Camera3D
	assert(cam != null and cam.fov < Player.HIP_FOV - 8.0,
		"the view did not narrow when aiming")
	player.aiming_down = false
	for _f in 40:
		await get_tree().physics_frame
	assert(player.arm.spring_length > rest - 0.6, "the camera never came back out")
	assert(cam.fov > Player.HIP_FOV - 2.0, "the view stayed zoomed")
	print("[SMOKE] aiming pulls the shot in over the shoulder and lets it back out")

	# the heat readout only shows when there is heat to show, so give it some
	GameState.set_wanted(2)
	hud.refresh_heat()
	assert(hud._heat_box.visible, "wanted, and nothing on screen says so")
	var before_stars := 0
	for st: ColorRect in hud._heat_stars:
		if st.color.r > 0.9 and st.color.g > 0.6:
			before_stars += 1
	assert(before_stars == GameState.wanted,
		"%d stars lit for a %d-star tail" % [before_stars, GameState.wanted])
	print("[SMOKE] heat: %d of 3 stars lit" % before_stars)
	GameState.set_wanted(0)
	busy = false

## Every StaticBody3D whose collision sits within `reach` of a point, which is
## what "a building on this block" means for the plot audit.
## Everything the city built that you can walk into. `skip` names top-level
## subtrees to leave out -- the dock, the yard and the spur are not blocks and
## are not measured against anybody's plot.
func _solids_near(at: Vector3, reach: float, skip: Array = []) -> Array:
	var out := []
	_gather_solids(world, at, reach, out, skip)
	return out

func _gather_solids(from: Node, at: Vector3, reach: float, out: Array,
		skip: Array = []) -> void:
	for c in from.get_children():
		if String(c.name) in skip:
			continue
		var body := c as StaticBody3D
		if body != null and body.global_position.distance_to(at) < reach:
			out.append(body)
		_gather_solids(c, at, reach, out, skip)

## Does a solid's footprint sit over this patch of ground?
func _on_patch(box: AABB, x0: float, x1: float, z0: float, z1: float) -> bool:
	return box.position.x < x1 and box.end.x > x0 and box.position.z < z1 and box.end.z > z0

## The box a StaticBody3D is standing on, in its own space.
func _shape_box(body: StaticBody3D) -> AABB:
	for c in body.get_children():
		var cs := c as CollisionShape3D
		var shape := cs.shape as BoxShape3D if cs != null else null
		if shape != null:
			return AABB(cs.position - shape.size * 0.5, shape.size)
	return AABB()

func _find_car() -> Vehicle:
	for n in get_tree().get_nodes_in_group("vehicle"):
		var v := n as Vehicle
		# an empty one at the kerb: a car with somebody in it is a different job
		if v and v.locked and not v.is_job and not v.has_occupant() and GameState.can_attempt(v.data):
			return v
	return null

func _spawn_job(id: String) -> Vehicle:
	var v := Vehicle.new()
	v.setup(GameData.vehicle_by_id(id).duplicate(true))
	world.add_child(v)
	v.global_position = World.GARAGE_POS + Vector3(0, 0.6, -6)
	v.set_as_job()
	world.jobs.append(v)
	return v

# ------------------------------------------------------------
#  Acceleration check: flat out from a standstill on open road.
#  Catches the class of bug where something quietly brakes the car
#  every frame -- the curve has to climb and reach the rated top speed.
# ------------------------------------------------------------
func _start_drive_test() -> void:
	drive_car = Vehicle.new()
	drive_car.setup(GameData.vehicle_by_id("sedan").duplicate(true))
	world.add_child(drive_car)
	# well outside the grid: the city reaches +/-170 now, and 150 is a high street
	drive_car.global_position = Vector3(300, 0.6, 300)
	drive_car.unlock()
	drive_car.driver = self
	drive_t = 0.0
	next_sample = 0.0
	samples = []
	driving = true

func _physics_process(delta: float) -> void:
	if watching:
		_watch_traffic(delta)
		return
	if not driving:
		return
	drive_t += delta
	drive_car.drive(1.0, 0.0, delta)
	if drive_t >= next_sample:
		samples.append(drive_car.speed)
		next_sample += 1.0
	if drive_t < 9.0:
		return
	driving = false

	var top: float = float(drive_car.data.top_speed)
	var line := []
	for v in samples:
		line.append("%.1f" % v)
	print("[SMOKE] sedan m/s each second: %s  (top %.0f)" % [", ".join(line), top])

	for i in range(1, samples.size()):
		assert(samples[i] >= samples[i - 1] - 0.01,
			"speed dropped at full throttle: %.2f -> %.2f" % [samples[i - 1], samples[i]])
	assert(drive_car.speed > top * 0.97, "never reached top speed: %.1f of %.1f" % [drive_car.speed, top])
	assert(drive_car.condition > 0.5, "condition got chewed up just driving in a straight line")
	assert(drive_car.gear >= 4, "gearbox never reached top gear (gear %d)" % drive_car.gear)
	print("[SMOKE] acceleration is monotonic, top gear %d, condition intact" % drive_car.gear)
	drive_car.queue_free()


# ------------------------------------------------------------
#  Traffic watch: let the ambient cars run and check they behave.
#  Lane discipline, no piling into each other, and the lights cycle.
# ------------------------------------------------------------
var watching := false
var _blocker := ""
## Held while a check that takes real seconds is running, so the step counter
## does not run off and quit the game out from under it.
var busy := false
var watch_t := 0.0
var worst_lane := 0.0
var worst_note := ""
var worst_wrong := 0.0
var closest := 999.0
var overlap := 0.0
var blocked_box := 0
var box_why := {}
var overlap_note := ""
var kerb_waits := 0
var near_miss := 999.0
var stopped_at_red := false
var start_positions := {}
var moved := 0.0

func _start_traffic_watch() -> void:
	watch_t = 0.0
	worst_lane = 0.0
	worst_wrong = 0.0
	closest = 999.0
	overlap = 0.0
	blocked_box = 0
	box_why = {}
	near_miss = 999.0
	kerb_waits = 0
	stopped_at_red = false
	moved = 0.0
	start_positions.clear()
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is TrafficCar:
			start_positions[n] = (n as TrafficCar).global_position
	watching = true

func _watch_traffic(delta: float) -> void:
	watch_t += delta
	var cars := []
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is TrafficCar and (n as TrafficCar).locked:
			cars.append(n as TrafficCar)

	for c in cars:
		var to_j: float = (c._junction() - c.global_position).dot(c.dir)
		var seg: float = absf(World.ROADS[c.to_i] - World.ROADS[c.from_i])
		# the whole road between the two junction boxes -- including the stretch
		# right after a turn, which is where a car swings wide
		if to_j > Traffic.BOX and (seg - to_j) > Traffic.BOX:
			var lane: Vector3 = c._lane_target()
			var off: Vector3 = c.global_position - lane
			var lateral: float = absf(off.z) if c._along_x() else absf(off.x)
			worst_lane = maxf(worst_lane, lateral)
			# the one that really matters: how far over the centre line, into
			# the lane coming the other way
			var right := Vector3(-c.dir.z, 0, c.dir.x)
			var centre: Vector3 = lane - right * Traffic.LANE
			var side: float = (c.global_position - centre).dot(right)
			if -side > worst_wrong:
				worst_wrong = -side
				worst_note = "dir%s next%s road=%d from=%d to=%d pos=(%.1f,%.1f) lane=(%.1f,%.1f) toJ=%.1f spd=%.1f" % [
					str(c.dir), str(c._next_dir), c.road_i, c.from_i, c.to_i,
					c.global_position.x, c.global_position.z, lane.x, lane.z, to_j, c.speed]
		if c.speed < 0.4 and to_j < Traffic.STOP_LINE and to_j > Traffic.BOX:
			stopped_at_red = true
		# Sat still inside the box for a reason -- that is what blocks a
		# junction. Merely crawling through is not: a long car legitimately
		# takes a while to cross, and counting that just measures car length.
		if c.speed < 0.5 and c.stop_reason != "" and to_j < Traffic.BOX and to_j > -Traffic.BOX:
			blocked_box += 1
			box_why[c.stop_reason] = int(box_why.get(c.stop_reason, 0)) + 1

	for n in get_tree().get_nodes_in_group("pedestrian"):
		var walker := n as Node3D
		if (n as Pedestrian).waiting:
			kerb_waits += 1
		for c in cars:
			# clearance, not centre distance: a wider car has less of it at the
			# same separation, and centre distance quietly hides a graze
			near_miss = minf(near_miss, walker.global_position.distance_to(c.global_position)
				- c.half_width - 0.35)

	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var d: float = cars[i].global_position.distance_to(cars[j].global_position)
			closest = minf(closest, d)
			# do the two footprints actually intersect? centre distance alone
			# says nothing when one car is sat at an angle in a junction
			var pen: float = _footprint_overlap(cars[i], cars[j])
			if pen > overlap:
				overlap = pen
				var ta: float = (cars[i]._junction() - cars[i].global_position).dot(cars[i].dir)
				var tb: float = (cars[j]._junction() - cars[j].global_position).dot(cars[j].dir)
				overlap_note = "d=%.1f toJ=%.0f/%.0f spd=%.1f/%.1f why=%s/%s" % [
					d, ta, tb, cars[i].speed, cars[j].speed,
					cars[i].stop_reason, cars[j].stop_reason]

	if watch_t < 25.0:
		return
	watching = false

	for c in cars:
		if start_positions.has(c):
			moved += start_positions[c].distance_to(c.global_position)
	var avg := moved / float(maxi(1, cars.size()))

	print("[SMOKE] traffic: %d cars, avg %.0fm travelled, lane drift %.1fm, over the centre line %.1fm, closest pair %.1fm, worst overlap %.2fm" % [
		cars.size(), avg, worst_lane, worst_wrong, closest, overlap])
	print("[SMOKE] junctions: %d frames stalled inside a box, clearance to the nearest walker %.2fm, %d frames waiting at kerbs  %s" % [
		blocked_box, near_miss, kerb_waits, str(box_why)])
	assert(cars.size() >= 6, "traffic did not spawn: %d" % cars.size())
	assert(avg > 25.0, "traffic barely moved: %.1fm average" % avg)
	assert(worst_lane < 4.0, "cars wandered %.1fm off their lane (%s)" % [worst_lane, worst_note])
	assert(worst_wrong < 1.5, "car drove %.1fm into the oncoming lane (%s)" % [worst_wrong, worst_note])

	assert(overlap < 0.25, "two cars overlapped by %.2fm (%s)" % [overlap, overlap_note])
	assert(stopped_at_red, "nobody ever stopped at a junction")
	# a little is fine and correct: it is cars yielding to somebody crossing.
	assert(blocked_box < 200, "cars are stalling inside junctions: %d frames" % blocked_box)
	assert(kerb_waits > 0, "nobody ever waited at a kerb for traffic")
	assert(near_miss > -0.15, "a car came %.2fm inside somebody on foot" % -near_miss)

	# the signals have to actually alternate and share an all-red gap
	var seen := {}
	for i in 40:
		seen[Traffic.green_axis(0, 0, float(i) * 0.5)] = true
	assert(seen.has("NS") and seen.has("EW") and seen.has(""),
		"light cycle is missing a phase: %s" % str(seen.keys()))
	assert(Traffic.green_axis(0, 0, 0.0) != Traffic.green_axis(1, 0, 0.0),
		"neighbouring junctions are not offset")
	print("[SMOKE] lights cycle NS / all-red / EW, neighbours offset")


# ------------------------------------------------------------
#  Joining wires has to bring them TOGETHER. The offset is worked out in
#  the car's own frame; doing it in world space sent the wire off sideways
#  on any car not sitting square to the world, which is most of them.
# ------------------------------------------------------------
func _check_join() -> void:
	var v := Vehicle.new()
	v.setup(GameData.vehicle_by_id("sedan").duplicate(true))
	world.add_child(v)
	v.global_position = Vector3(120, 0.2, 120)
	v.rotation.y = PI * 0.37          # deliberately not axis aligned
	v.unlock()
	hud.start_hotwire(v, func(_a, _b): pass)
	var td := hud._teardown
	td._stage = 2
	td._build_stage()

	var jp: Dictionary = td._props[1]
	assert(not jp.decoy, "the draggable wire should not be scenery")
	var target: Vector3 = v.to_global(jp.pd.target)
	var gaps := []
	for step_i in [0.0, 0.34, 0.67, 1.0]:
		jp.progress = step_i
		td._join_place(jp)
		gaps.append(jp.mesh.global_position.distance_to(target))
	for i in range(1, gaps.size()):
		assert(gaps[i] < gaps[i - 1] - 0.005,
			"the wires moved apart instead of together: %.2fm -> %.2fm" % [gaps[i - 1], gaps[i]])
	assert(gaps[gaps.size() - 1] < 0.12,
		"the ends never met, %.2fm apart at the end" % gaps[gaps.size() - 1])
	print("[SMOKE] join closes the gap on a turned car: %.2f -> %.2fm" % [gaps[0], gaps[gaps.size() - 1]])
	td.abort()
	v.queue_free()


# ------------------------------------------------------------
#  Who is out on the street
# ------------------------------------------------------------
func _check_street() -> void:
	var walkers := get_tree().get_nodes_in_group("pedestrian").size()
	var beat := 0
	for n in get_tree().get_nodes_in_group("police_foot"):
		if (n as PoliceOfficer).mode == PoliceOfficer.Mode.BEAT:
			beat += 1
	var patrols := 0
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is TrafficCar and (n as TrafficCar).patrol:
			patrols += 1
	print("[SMOKE] street: %d pedestrians, %d coppers on the beat, %d patrol cars in traffic" % [
		walkers, beat, patrols])
	var shirts := {}
	for n in get_tree().get_nodes_in_group("pedestrian"):
		shirts[str((n as Pedestrian)._body.get_meta("shirt", Color.BLACK))] = true
	print("[SMOKE] %d different shirts on the street" % shirts.size())
	assert(shirts.size() >= 5, "everybody is dressed the same: %d colours" % shirts.size())
	assert(walkers >= 8, "not enough people about: %d" % walkers)
	assert(beat >= 1, "nobody walking a beat")
	assert(patrols >= 1, "no patrol cars mixed into the traffic")

# ------------------------------------------------------------
#  Cornered: they get out. Moving again: they get back in.
# ------------------------------------------------------------
func _check_getting_out() -> void:
	var ride := Vehicle.new()
	ride.setup(GameData.vehicle_by_id("sedan").duplicate(true))
	world.add_child(ride)
	ride.global_position = Vector3(100, 0.4, 100)
	ride.unlock()
	ride.hotwire()
	player.global_position = ride.global_position
	player.enter_vehicle(ride)
	ride.speed = 0.0
	GameState.set_wanted(1)

	var cop := PoliceCar.new()
	cop.setup(PoliceDispatch.COP_DATA.duplicate(true))
	world.add_child(cop)
	cop.global_position = ride.global_position + Vector3(6, 0.4, 0)
	cop.target = player

	# boxed in and going nowhere -- they should not sit there for long
	for i in 20:
		cop._consider_getting_out(0.1)
	assert(cop.officer != null, "nobody got out of the car")
	assert(cop.officer.is_in_group("police"), "the officer on foot does not count as police")
	assert(cop.officer.mode == PoliceOfficer.Mode.PURSUE, "the officer is not chasing")
	print("[SMOKE] cornered with the engine idling: an officer got out")

	# and away we go
	ride.speed = 12.0
	cop._consider_getting_out(0.1)
	assert(cop.officer == null or cop.officer.mode == PoliceOfficer.Mode.RETURN,
		"the car did not recall its officer")
	var out := get_tree().get_nodes_in_group("police_foot")
	var returning := 0
	for n in out:
		if (n as PoliceOfficer).mode == PoliceOfficer.Mode.RETURN:
			returning += 1
	assert(returning == 1, "the officer is not heading back to the car")
	print("[SMOKE] player drove off: the officer is running back to the cruiser")

	player.exit_vehicle()
	GameState.set_wanted(0)
	get_tree().call_group("police_dispatch", "clear_pursuit")
	cop.queue_free()
	ride.queue_free()


# ------------------------------------------------------------
#  A copper has to actually be looking at you, and not through a wall.
# ------------------------------------------------------------
func _check_sight() -> void:
	GameState.set_wanted(0)
	player.global_position = Vector3(60, 1.0, -140)      # bare ground, nothing to hide behind
	player.stealing = true

	var facing := _plant_officer(player.global_position + Vector3(0, 0, -12), Vector3(0, 0, 1))
	var away := _plant_officer(player.global_position + Vector3(0, 0, 12), Vector3(0, 0, 1))
	var far := _plant_officer(player.global_position + Vector3(0, 0, -60), Vector3(0, 0, 1))
	await get_tree().physics_frame

	assert(facing.can_see(player), "an officer looking straight at it saw nothing")
	assert(not away.can_see(player), "an officer facing the other way still spotted it")
	assert(not far.can_see(player), "an officer 60m off spotted it")

	# and a wall between the two of them stops it
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 6, 1)
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 2, -6)
	await get_tree().physics_frame
	assert(not facing.can_see(player), "they saw straight through a wall")
	print("[SMOKE] sight: in front yes, behind no, too far no, through a wall no")

	# being seen at it puts you on the board
	wall.queue_free()
	await get_tree().physics_frame
	facing._beat(0.05)
	assert(GameState.wanted > 0, "getting seen mid-steal did not raise the alarm")
	assert(facing.mode == PoliceOfficer.Mode.PURSUE, "the witness did not give chase")
	print("[SMOKE] caught in the act: wanted %d, the witness is chasing" % GameState.wanted)

	# and every other copper nearby should be running too, car or no car
	var bystander := _plant_officer(player.global_position + Vector3(0, 0, 26), Vector3(0, 0, 1))
	await get_tree().physics_frame
	bystander._beat(0.05)
	assert(bystander.mode == PoliceOfficer.Mode.PURSUE,
		"a copper 26m away ignored a wanted player")
	assert(bystander.is_in_group("police"), "the second officer is not actually chasing")
	print("[SMOKE] a copper facing away 26m off joined the chase on foot too")
	bystander.queue_free()

	player.stealing = false
	GameState.set_wanted(0)
	for o in [facing, away, far]:
		o.queue_free()

func _plant_officer(at: Vector3, facing: Vector3) -> PoliceOfficer:
	var o := PoliceOfficer.new()
	world.add_child(o)
	o.global_position = at
	o._body.rotation.y = atan2(facing.x, facing.z)
	return o


# ------------------------------------------------------------
#  Do two cars actually overlap? Separating axis theorem on the two
#  footprints, which is the only honest answer -- two cars 3m apart are
#  fine side by side and inside one another nose to tail.
# ------------------------------------------------------------
const HALF_W := 1.0
const HALF_L := 2.2

func _footprint_overlap(a: Node3D, b: Node3D) -> float:
	var ax := _flat(a.global_transform.basis.x)
	var az := _flat(a.global_transform.basis.z)
	var bx := _flat(b.global_transform.basis.x)
	var bz := _flat(b.global_transform.basis.z)
	var d := Vector2(b.global_position.x - a.global_position.x,
		b.global_position.z - a.global_position.z)
	var worst := 1e9
	for axis in [ax, az, bx, bz]:
		var ra: float = HALF_W * absf(axis.dot(ax)) + HALF_L * absf(axis.dot(az))
		var rb: float = HALF_W * absf(axis.dot(bx)) + HALF_L * absf(axis.dot(bz))
		var sep: float = absf(d.dot(axis)) - (ra + rb)
		if sep > 0.0:
			return 0.0            # a gap on this axis: they are apart
		worst = minf(worst, -sep)
	return worst

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z).normalized()


# ------------------------------------------------------------
#  Gunplay: who can shoot, when, and what it costs
# ------------------------------------------------------------
func _check_guns() -> void:
	GameState.set_wanted(0)
	GameState.set_health(100)
	player.global_position = Vector3(-140, 1.0, 60)      # open ground
	player.current_vehicle = null

	# unarmed until you have bought one
	assert(not GameState.armed(), "the player started out armed")
	GameState.add_money(2000)
	assert(GameState.buy(GameData.upgrade_by_id("pistol")) == "", "could not buy the pistol")
	GameState.ammo = int(GameData.WEAPONS.pistol.clip)
	assert(GameState.armed(), "buying the pistol did not arm anyone")

	# --- they hold fire at one star ---
	var cop := PoliceOfficer.new()
	world.add_child(cop)
	cop.global_position = player.global_position + Vector3(0, 0, 10)
	cop.deploy_from(null, player)
	await get_tree().physics_frame
	GameState.set_wanted(1)
	cop._trigger = 0.0
	cop._take_a_shot(player)
	assert(GameState.health == 100, "they opened fire at one star")

	# --- and draw at two ---
	GameState.set_wanted(2)
	var shots := 0
	cop.global_position = player.global_position + Vector3(0, 0, 6)
	await get_tree().physics_frame
	for i in 40:
		cop._trigger = 0.0
		cop._take_a_shot(player)
		if GameState.health < 100:
			shots += 1
			break
		await get_tree().physics_frame
	assert(GameState.health < 100, "nobody fired at two stars in forty tries")
	print("[SMOKE] one star: they hold fire. two stars: they shoot (hp %d)" % GameState.health)

	# --- shooting a copper is worth three stars on its own ---
	GameState.set_wanted(1)
	var before_hp := cop.health
	cop.take_damage(int(GameData.WEAPONS.pistol.damage), player)
	assert(cop.health < before_hp, "the officer shrugged off a bullet")
	assert(GameState.wanted == 3, "shooting a copper did not go straight to three stars")
	print("[SMOKE] shot a copper: wanted jumped to %d" % GameState.wanted)

	# --- and enough of them puts him down ---
	for i in 4:
		cop.take_damage(int(GameData.WEAPONS.pistol.damage), player)
	assert(cop._down, "the officer would not go down")
	assert(not cop.is_in_group("shootable"), "a downed officer is still a target")
	print("[SMOKE] officer down after %d rounds" % ceili(60.0 / float(GameData.WEAPONS.pistol.damage)))

	# --- a cruiser only shoots at somebody who will not pull over ---
	var ride := Vehicle.new()
	ride.setup(GameData.vehicle_by_id("sedan").duplicate(true))
	world.add_child(ride)
	ride.global_position = player.global_position
	ride.unlock()
	ride.hotwire()
	player.enter_vehicle(ride)
	var car := PoliceCar.new()
	car.setup(PoliceDispatch.COP_DATA.duplicate(true))
	world.add_child(car)
	car.global_position = player.global_position + Vector3(0, 0, 9)
	car.target = player
	GameState.set_wanted(2)
	GameState.set_health(100)
	await get_tree().physics_frame

	ride.speed = 0.0                       # pulled over
	for i in 6:
		car._trigger = 0.0
		car._shoot_from_the_window(0.1)
	assert(GameState.health == 100, "they shot at somebody who had pulled over")

	ride.speed = 14.0                      # not stopping
	var hit := false
	for i in 14:
		car._trigger = 0.0
		car._shoot_from_the_window(0.1)
		if GameState.health < 100:
			hit = true
			break
		await get_tree().physics_frame
	assert(hit, "the cruiser never fired at a car that would not stop")
	print("[SMOKE] cruiser: holds fire when you pull over, shoots when you run (hp %d)" % GameState.health)

	# --- and you can shoot the cruiser back out of the chase ---
	for i in 10:
		car.take_damage(25, player)
	assert(car._wrecked, "the cruiser would not stop")
	print("[SMOKE] cruiser shot up and out of the chase")

	player.exit_vehicle()
	ride.queue_free()
	car.queue_free()
	cop.queue_free()
	GameState.set_wanted(0)
	GameState.set_health(100)
	get_tree().call_group("police_dispatch", "clear_pursuit")


# ------------------------------------------------------------
#  The belt: two loops to start, and belts that add more
# ------------------------------------------------------------
func _check_belt() -> void:
	GameState.sync_belt()
	assert(GameState.belt_slots() == 2, "should start with two loops, got %d" % GameState.belt_slots())
	assert(GameState.hotbar.size() == 2, "the belt is not two loops wide")
	assert(GameState.carrying_item("jimmy"), "the jimmy should start on the belt")
	assert(GameState.carrying_item("tire_iron"), "the tire iron should start on the belt")
	print("[SMOKE] belt starts at %d loops: %s" % [GameState.belt_slots(), str(GameState.hotbar)])

	# what is in your hand decides what the left button does
	GameState.select_slot(GameState.hotbar.find("tire_iron"))
	assert(String(GameState.held_item().kind) == "melee", "the tire iron is not a melee weapon")
	GameState.select_slot(GameState.hotbar.find("jimmy"))
	assert(String(GameState.held_item().kind) == "theft", "the jimmy is not a theft tool")

	# the pistol was bought in the gun check: with two loops full it has to wait
	assert(GameState.owned_items.has("pistol"), "the pistol was never bought")
	assert(not GameState.carrying_item("pistol"), "a third thing fitted on a two-loop belt")
	assert(GameState.toggle_on_belt("pistol") != "", "it let a third item onto a full belt")
	print("[SMOKE] two loops are full, so the pistol will not go on")

	# take the tire iron off and it fits
	assert(GameState.toggle_on_belt("tire_iron") == "", "could not take the tire iron off")
	assert(GameState.toggle_on_belt("pistol") == "", "could not put the pistol on the freed loop")
	assert(GameState.carrying_item("pistol"), "the pistol did not go on")

	# without the jimmy on you, you cannot jimmy anything
	var swap := GameState.hotbar.find("jimmy")
	GameState.hotbar[swap] = ""
	assert(not GameState.carrying_item("jimmy"), "the jimmy is still on the belt")
	var victim := _find_car()
	if victim:
		player.begin_breakin(victim)
		assert(not hud._teardown.active, "jimmied a door without the jimmy on the belt")
	print("[SMOKE] no jimmy on the belt, no break-in")

	# belts add loops, and never lose what was already on
	GameState.add_money(6000)
	assert(GameState.buy(GameData.upgrade_by_id("belt_large")) != "",
		"the big belt sold without the ordinary one")
	assert(GameState.buy(GameData.upgrade_by_id("belt")) == "", "could not buy the tool belt")
	GameState.sync_belt()
	assert(GameState.belt_slots() == 4, "the tool belt did not make it four")
	assert(GameState.carrying_item("pistol"), "the belt upgrade dropped what was on it")
	assert(GameState.buy(GameData.upgrade_by_id("belt_large")) == "", "could not buy the rigger belt")
	GameState.sync_belt()
	assert(GameState.belt_slots() == 6, "the rigger belt did not make it six")
	assert(GameState.hotbar.size() == 6, "the belt did not grow to six loops")
	print("[SMOKE] belts: 2 -> 4 -> 6 loops, nothing dropped on the way")

	# buying the belts should have pulled everything back out of the bench
	assert(GameState.carrying_item("jimmy") and GameState.carrying_item("tire_iron"),
		"the new loops were not filled from the bench: %s" % str(GameState.hotbar))
	GameState.select_slot(0)

	# --- the bench holds what you are not carrying ---
	assert(GameState.stored_items().is_empty(),
		"six loops and three items, nothing should be on the bench: %s" % str(GameState.stored_items()))
	GameState.toggle_on_belt("pistol")
	assert(GameState.stored_items().has("pistol"), "stowing the pistol did not leave it on the bench")
	assert(not GameState.carrying_item("pistol"), "it is still on the belt")
	hud.open_bench()
	assert(hud._panel != null, "the workbench panel did not open")
	hud._bench_move("pistol")
	assert(GameState.carrying_item("pistol"), "could not take it back off the bench")
	hud.close_panel()
	print("[SMOKE] bench: stow and pick up work, %d loops used" % [
		GameState.hotbar.size() - GameState.hotbar.count("")])

	# --- ordering something with a full belt leaves it on the bench ---
	while GameState.hotbar.count("") > 0:
		GameState.hotbar[GameState.hotbar.find("")] = "jimmy"   # jam every loop
	GameState.owned_items.append("spare_test")
	GameState.acquire_item("spare_test")
	assert(GameState.stored_items().has("spare_test"),
		"a new tool with no room on the belt did not go to the bench")
	GameState.owned_items.erase("spare_test")
	for i in GameState.hotbar.size():
		GameState.hotbar[i] = ""
	GameState.hotbar[0] = "jimmy"
	GameState.hotbar[1] = "tire_iron"
	GameState.hotbar[2] = "pistol"
	GameState.kit_changed.emit()
	print("[SMOKE] a tool you cannot carry goes to the bench")


# ------------------------------------------------------------
#  Anyone can be killed. Being seen doing it is the problem.
# ------------------------------------------------------------
func _check_bystanders() -> void:
	GameState.set_wanted(0)
	player.global_position = Vector3(300, 1.0, -300)      # outside the city entirely

	# nobody about: no witnesses, no alarm
	var alone := Pedestrian.new()
	alone.outfit_seed = 3
	world.add_child(alone)
	alone.global_position = player.global_position + Vector3(2, 0, 0)
	await get_tree().physics_frame
	assert(alone.is_in_group("shootable"), "a passer-by is not something you can hit")
	for i in 3:
		alone.take_damage(25, player)
	assert(alone.down, "a passer-by would not go down")
	assert(GameState.wanted == 0, "an unwitnessed killing raised the alarm")
	print("[SMOKE] killed with nobody watching: still %d stars" % GameState.wanted)

	# now with somebody stood right there
	var victim := Pedestrian.new()
	victim.outfit_seed = 4
	world.add_child(victim)
	victim.global_position = player.global_position + Vector3(2, 0, 4)
	var watcher := Pedestrian.new()
	watcher.outfit_seed = 5
	world.add_child(watcher)
	watcher.global_position = player.global_position + Vector3(8, 0, 4)
	await get_tree().physics_frame
	for i in 3:
		victim.take_damage(25, player)
	assert(victim.down, "the second one would not go down")
	assert(GameState.wanted >= 2, "a witnessed killing did not bring the police: %d" % GameState.wanted)
	assert(watcher.panic_until > 0.0, "the witness carried on as if nothing had happened")
	print("[SMOKE] killed in front of a witness: %d stars, and they ran" % GameState.wanted)

	GameState.set_wanted(0)
	get_tree().call_group("police_dispatch", "clear_pursuit")
	alone.queue_free()
	victim.queue_free()
	watcher.queue_free()


# ------------------------------------------------------------
#  Pulling a part off an imported car. The real mesh comes off as a holder
#  node with meshes inside it, not a flat list of MeshInstance3D, and casting
#  that holder straight to MeshInstance3D used to crash the rig.
# ------------------------------------------------------------
# ------------------------------------------------------------
#  Road rules: crossings, and what happens when they are ignored
# ------------------------------------------------------------
## Is this spot painted with a crossing?
func _on_a_crossing(p: Vector3) -> bool:
	var band: float = World.CROSS_HALF + 1.4
	for cx: float in World.ROADS:
		for cz: float in World.ROADS:
			if absf(p.x - cx) < 7.2 and absf(absf(p.z - cz) - World.PAVE) < band:
				return true
			if absf(p.z - cz) < 7.2 and absf(absf(p.x - cx) - World.PAVE) < band:
				return true
	return false

## Is it on a carriageway at all? Measured a body's half-width in from the
## kerb: somebody walking the pavement whose centre grazes the kerb line has
## not stepped into the road, and counting them as though they had turns this
## into a test of how tightly the pavement crowds rather than of the rule.
func _on_the_road(p: Vector3) -> bool:
	var edge: float = World.ROAD_HALF - 0.35
	for c: float in World.ROADS:
		if absf(p.x - c) < edge or absf(p.z - c) < edge:
			return true
	return false

func _check_road_rules() -> void:
	busy = true
	# Nobody LIVES in the road: somebody knocked over or running from a gun has
	# to be able to walk back out of it, so what matters is how long they are
	# out there off a crossing, not whether they are ever there at all.
	var stray_run := {}
	var park_run := {}
	var worst := 0
	var worst_at := Vector3.ZERO
	var blocked := 0
	for frame in 600:
		await get_tree().physics_frame
		for n in get_tree().get_nodes_in_group("pedestrian"):
			var who := n as Pedestrian
			if who == null:
				continue
			var id := who.get_instance_id()
			# somebody running for their life is allowed to be anywhere
			if who.down or who.tumbling or who.panic_until > 0.0 					or not _on_the_road(who.global_position) or _on_a_crossing(who.global_position):
				stray_run[id] = 0
				continue
			stray_run[id] = int(stray_run.get(id, 0)) + 1
			if stray_run[id] > worst:
				worst = stray_run[id]
				worst_at = who.global_position
		# a car rolling over a crossing is fine; one sat still on it is not, so
		# this counts how long any single car stays parked on the stripes
		for n in get_tree().get_nodes_in_group("vehicle"):
			var car := n as TrafficCar
			if car == null:
				continue
			var id := car.get_instance_id()
			if absf(car.speed) > 0.15 or not _on_a_crossing(car.global_position):
				park_run[id] = 0
				continue
			park_run[id] = int(park_run.get(id, 0)) + 1
			if park_run[id] > blocked:
				blocked = park_run[id]
				_blocker = "%s at %s, stopped because %s, %.1fm to the thing in front" % [
					car.data.name, str(car.global_position), car.stop_reason, car._gap_ahead()]
	assert(worst < 200, "somebody stood in the road off a crossing for %d frames, at %s" % [
		worst, str(worst_at)])
	assert(blocked < 120, "a car sat on a crossing for %d frames: %s" % [blocked, _blocker])
	print("[SMOKE] crossings: longest anybody spent in the road off one is %d frames, longest a car sat on one is %d" % [
		worst, blocked])

	# nothing is parked inside anything. A box the size of each parked car,
	# swept where it stands, should touch nothing but the ground it is on.
	var space := world.get_world_3d().direct_space_state
	var buried := ""
	for n in get_tree().get_nodes_in_group("vehicle"):
		var car := n as Vehicle
		if car == null or car is TrafficCar or car.driver != null or car.is_job:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(car.half_width * 2.0 - 0.4, 1.1, car.half_length * 2.0 - 0.4)
		query.shape = box
		query.transform = Transform3D(car.global_transform.basis,
			car.global_position + Vector3(0, 0.85, 0))
		query.exclude = [car.get_rid()]
		query.collide_with_areas = false
		var hits := space.intersect_shape(query, 4)
		if not hits.is_empty():
			buried = "%s at %s is inside %s" % [car.data.name, str(car.global_position),
				str((hits[0].collider as Node).get_parent().name)]
			break
	assert(buried == "", "a parked car is in the scenery: %s" % buried)

	# and they sit on the road rather than in it. Anything on a ramp or up on
	# stands is meant to be off the ground, so it does not count.
	for n in get_tree().get_nodes_in_group("vehicle"):
		var car := n as Vehicle
		if car == null or car.driver != null or car.is_job or car.lifted:
			continue
		assert(absf(car.global_position.y) < 0.25,
			"%s is riding at y %.2f, at %s" % [car.data.name,
				car.global_position.y, str(car.global_position)])

	# the wheels turn for the ground covered
	var roller := world.spawn_vehicle("rustbucket", Vector3(0, 0, 60))
	await get_tree().physics_frame
	assert(roller._wheel_spin.size() == 4, "%d wheels rigged, not four" % roller._wheel_spin.size())
	assert(roller._wheel_steer.size() == 2, "%d wheels steer, not two" % roller._wheel_steer.size())
	var wheel := roller._wheel_spin[0] as Node3D
	var still := wheel.quaternion
	roller.speed = 9.0
	for f in 6:
		roller.drive(1.0, 0.0, 1.0 / 60.0)
	assert(wheel.quaternion.angle_to(still) > 0.2,
		"the wheels did not turn: %.3f rad" % wheel.quaternion.angle_to(still))
	var rolled := wheel.quaternion
	roller.speed = 0.0
	roller.drive(0.0, 0.0, 1.0 / 60.0)
	assert(wheel.quaternion.angle_to(rolled) < 0.001, "the wheels turn while it is stood still")
	# and the front pair point where the steering does
	roller.drive(0.0, 1.0, 0.4)
	assert(absf(roller._wheel_steer[0].rotation.y) > 0.05,
		"the front wheels do not turn with the steering")
	roller.queue_free()

	# and never two abreast: a car parked a wing's width from the next one
	# cannot be got at, because you cannot stand at its driver's door
	var still_ones := []
	for n in get_tree().get_nodes_in_group("vehicle"):
		var v := n as Vehicle
		if v == null or v is TrafficCar or v is PoliceCar or v.is_job or not v.locked:
			continue
		still_ones.append(v.global_position)
	var tightest := 999.0
	for a in still_ones.size():
		for b in range(a + 1, still_ones.size()):
			tightest = minf(tightest, (still_ones[a] as Vector3).distance_to(still_ones[b]))
	assert(tightest >= World.PARK_CLEAR,
		"two parked cars are %.1fm apart -- no room to work on either" % tightest)

	# paving and kerbs are built in the gaps between carriageways, so neither
	# can run out over a road or over the crossing painted on it
	for run: Array in world._between_roads():
		for c: float in World.ROADS:
			assert(run[1] <= c - World.ROAD_HALF + 0.01 or run[0] >= c + World.ROAD_HALF - 0.01,
				"a pavement run %s crosses the road at %.0f" % [str(run), c])
	print("[SMOKE] parked cars are clear of the scenery and of each other (closest %.1fm), pavements stop at the kerb" % tightest)

	# and what a bonnet does to somebody who is on one at the wrong moment
	var lane := Vector3(World.ROADS[2] + 3.2, 0.2, 30.0)
	var victim := Pedestrian.new()
	victim.outfit_seed = 42
	world.add_child(victim)
	victim.global_position = lane
	victim.setup_route(Vector3(0, 0, -1), 2, 3, 2)
	var runner := Vehicle.new()
	runner.setup(GameData.vehicle_by_id("beater").duplicate(true))
	world.add_child(runner)
	runner.global_position = lane - Vector3(0, 0, 4.0)
	await get_tree().physics_frame

	var before := victim.health
	runner.speed = 3.0
	victim.run_over(runner, runner)
	var gentle := before - victim.health
	assert(victim.tumbling, "a clip from a car did not take them off their feet")
	assert(gentle > 0 and victim.health > 0, "walking pace should hurt, not kill: %d" % gentle)
	assert(victim.velocity.length() > 3.0, "they were not thrown anywhere")

	var second := Pedestrian.new()
	second.outfit_seed = 43
	world.add_child(second)
	second.global_position = lane + Vector3(2.0, 0, 0)
	second.setup_route(Vector3(0, 0, -1), 2, 3, 2)
	await get_tree().physics_frame
	runner.speed = 16.0
	second.run_over(runner, runner)
	assert(second.health <= 0, "16 m/s should have finished them, %d left" % second.health)
	print("[SMOKE] run over: %d damage at walking pace, dead at 16 m/s, both bodies thrown" % gentle)

	# two cars, and the shunt one gives the other
	var parked := Vehicle.new()
	parked.setup(GameData.vehicle_by_id("sedan").duplicate(true))
	world.add_child(parked)
	parked.global_position = lane + Vector3(14.0, 0.5, 0)
	await get_tree().physics_frame
	var panels := parked.parts_remaining.size()
	var health_before := parked.condition
	parked.take_shunt(Vector3(0, 0, -9.0), runner)
	# a smash only sheds a panel about half the time, so keep hitting it until
	# one lets go rather than letting the run turn on a coin flip
	for _swing in 40:
		parked._shed_a_part(Vector3(0, 0, -1))
		if parked.parts_remaining.size() < panels:
			break
	assert(parked.shove.length() > 1.0, "a shunt did not move it")
	assert(parked.condition < health_before, "a shunt did not mark it")
	assert(parked.parts_remaining.size() <= panels, "a smash should not add parts")

	# whatever came off went across the road and is scrap now
	var thrown_part: PartItem = null
	for n in get_tree().get_nodes_in_group("loose_part"):
		if (n as PartItem).damaged:
			thrown_part = n
	assert(thrown_part != null, "the smash did not throw a part off")
	assert(thrown_part.value == 0, "a wrecked part is still worth $%d" % thrown_part.value)
	assert(not thrown_part.is_in_group("interactable"), "you can still pick the wreckage up")
	assert(not GameState.truck().can_take(thrown_part), "the truck would take wreckage")
	var flung_from := thrown_part.global_position
	for f in 20:
		await get_tree().physics_frame
	assert(flung_from.distance_to(thrown_part.global_position) > 1.5,
		"the part just dropped where it was instead of being thrown clear")
	print("[SMOKE] a panel knocked off lands %.1fm away, wrecked and worthless" % 
		flung_from.distance_to(thrown_part.global_position))
	print("[SMOKE] crash: knocked back %.1fm/s, condition %d%% -> %d%%, %d panels left" % [
		parked.shove.length(), int(health_before * 100.0), int(parked.condition * 100.0),
		parked.parts_remaining.size()])
	for n in [victim, second, runner, parked]:
		n.queue_free()
	busy = false

## Writing the shop down and reading it back onto a different shop.
func _check_save() -> void:
	busy = true
	SaveGame.wipe()
	assert(not SaveGame.exists(), "the save file would not go away")

	# a shop worth saving: money, a levelled belt, a car on the ramp, a load
	GameState.money = 4321
	GameState.add_theft_xp(2)
	var job := world.spawn_job("sedan")
	assert(job != null, "no bay free to put a car on")
	var jobs_was := world.jobs.size()
	job.condition = 0.66
	var before_parts := job.parts_remaining.size()
	job.remove_part("hood")
	var lorry := GameState.truck()
	var goods := PartItem.create("battery", 45, "test", Color.WHITE, null)
	get_tree().current_scene.add_child(goods)
	await get_tree().process_frame
	lorry.load_part(goods)
	var cargo_was := lorry.cargo.size()
	player.global_position = Vector3(12, 1.5, -34)
	await get_tree().physics_frame

	assert(SaveGame.write(world, player) == "", "the save would not write")
	assert(SaveGame.exists(), "nothing on disk after saving")
	assert(SaveGame.stamp() != "", "the save has no date on it")

	# now wreck all of it, and put it back
	GameState.money = 11
	GameState.theft_level = 1
	lorry.unload_all()
	for j in world.jobs.duplicate():
		if is_instance_valid(j):
			j.queue_free()
	world.jobs.clear()
	player.global_position = Vector3(-70, 1.5, 70)
	await get_tree().physics_frame

	assert(SaveGame.read_into(world, player) == "", "the save would not load")
	await get_tree().physics_frame
	assert(GameState.money == 4321, "the money came back as %d" % GameState.money)
	assert(world.jobs.size() == jobs_was, "%d cars back on the ramps, not %d" % [
		world.jobs.size(), jobs_was])
	var back: Vehicle = null
	for j in world.jobs:
		if String(j.data.id) == "sedan":
			back = j
	assert(back != null, "the sedan did not come back off the save")
	assert(back.parts_remaining.size() == before_parts - 1,
		"the hood grew back: %d parts" % back.parts_remaining.size())
	assert(absf(back.condition - 0.66) < 0.01, "condition came back as %.2f" % back.condition)
	assert(GameState.truck().cargo.size() == cargo_was, "the load did not come back")
	assert(player.global_position.distance_to(Vector3(12, 1.5, -34)) < 1.0,
		"put back in the wrong place: %s" % str(player.global_position))
	print("[SMOKE] save/load: $%d, a %s on the ramp with %d parts, %d in the truck" % [
		GameState.money, back.data.name, back.parts_remaining.size(),
		GameState.truck().cargo.size()])

	SaveGame.wipe()
	for j in world.jobs.duplicate():
		if is_instance_valid(j):
			j.queue_free()
	world.jobs.clear()
	busy = false

## The clock, what the dark does to what people can see, and who is out in it.
func _check_daynight() -> void:
	busy = true
	GameState.set_process(true)
	var was := GameState.minutes
	await get_tree().create_timer(0.5).timeout
	assert(GameState.minutes > was, "the clock is not running")

	# the curve: light in the afternoon, dark in the small hours, ramps between
	GameState.minutes = 13.0 * 60.0
	assert(GameState.daylight() > 0.99 and not GameState.is_dark(), "1pm is not daylight")
	GameState.minutes = 2.0 * 60.0
	assert(GameState.daylight() < 0.01 and GameState.is_dark(), "2am is not dark")
	GameState.minutes = 20.0 * 60.0
	var dusk := GameState.daylight()
	assert(dusk > 0.0 and dusk < 1.0, "8pm should be halfway, got %.2f" % dusk)
	assert(GameState.clock_text() == "20:00", "the clock reads %s" % GameState.clock_text())

	# and what that does to being seen
	GameState.player_light = 1.0
	var bright := GameState.sight_scale()
	GameState.player_light = 0.0
	var dim := GameState.sight_scale()
	assert(dim < bright * 0.55, "the dark barely helps: %.2f vs %.2f" % [dim, bright])

	# a lamp overhead is worth being seen by
	assert(not StreetKit.lamps.is_empty(), "no street lamps went up")
	var under: Vector3 = StreetKit.lamps[0]
	GameState.minutes = 2.0 * 60.0
	assert(world.light_at(under - Vector3(0, 5.0, 0)) > 0.5,
		"a lamp lights nothing at 2am")
	assert(world.light_at(Vector3(0, 0, 200.0)) < 0.1, "the middle of nowhere is lit at 2am")

	# the streets thin out overnight and the beat gets heavier
	var traffic := world.get_node("Traffic") as Traffic
	GameState.minutes = 13.0 * 60.0
	var day_walkers := traffic._wanted_walkers()
	var day_cops := traffic._wanted_officers()
	GameState.minutes = 2.0 * 60.0
	assert(traffic._wanted_walkers() < day_walkers * 0.6,
		"the pavements are as busy at 2am: %d vs %d" % [traffic._wanted_walkers(), day_walkers])
	assert(traffic._wanted_officers() > day_cops, "no extra police overnight")
	print("[SMOKE] day/night: %s, %d out by day and %d at night, %d cops up from %d" % [
		GameState.clock_text(), day_walkers, traffic._wanted_walkers(),
		traffic._wanted_officers(), day_cops])

	# a torch lights whoever it is pointed at, which is the trade. Stand
	# somewhere the street lighting does not reach first -- where the lamps
	# land is down to the seed, and a fixed spot is dark until it is not.
	var dark := Vector3.ZERO
	for xi in World.BLOCKS.size():
		for zi in World.BLOCKS.size():
			var c := Vector3(World.BLOCKS[xi], 0, World.BLOCKS[zi])
			var near := 1.0e9
			for lamp: Vector3 in StreetKit.lamps:
				near = minf(near, Vector2(c.x - lamp.x, c.z - lamp.z).length())
				near = minf(near, Vector2(c.x - lamp.x, c.z - 6.0 - lamp.z).length())
			if near > 13.0:
				dark = c
				break
		if dark != Vector3.ZERO:
			break
	assert(dark != Vector3.ZERO, "every block in the city is under a street lamp")
	player.global_position = dark
	var mark := dark + Vector3(0, 0, -6)
	assert(world.light_at(mark) < 0.2, "already lit before the torch")
	player.add_to_group("torch")
	player.set_meta("torch_reach", 20.0)
	player.set_meta("torch_dir", Vector3(0, 0, -1))
	assert(world.light_at(mark) > 0.8, "the torch lights nothing in front of it")
	assert(world.light_at(dark + Vector3(0, 0, 6)) < 0.2, "the torch lights what is behind it")
	player.remove_from_group("torch")
	print("[SMOKE] a torch lights what it points at and nothing behind it")
	GameState.minutes = 12.0 * 60.0
	GameState.set_process(false)
	busy = false

## Getting collared in your own truck, and the two ways of getting it back.
func _check_impound() -> void:
	busy = true
	GameState.set_wanted(0)
	get_tree().call_group("police_dispatch", "clear_pursuit")
	var lorry := GameState.truck()
	assert(lorry != null, "no truck to lose")
	assert(not GameState.truck_impounded, "it started the day in the pound")

	# something in the back, so there is a reason to want it back
	var goods := PartItem.create("wheel_fr", 25, "test", Color.WHITE, null)
	get_tree().current_scene.add_child(goods)
	await get_tree().process_frame
	assert(lorry.load_part(goods), "could not load the truck")
	var carried := lorry.cargo.size()

	# caught behind the wheel of it
	lorry.global_position = player.global_position + Vector3(3, 0.7, 0)
	lorry.locked = false
	lorry.hotwired = true
	player.enter_vehicle(lorry)
	assert(player.current_vehicle == lorry, "never got in the truck")
	player._get_busted()
	assert(is_instance_valid(lorry), "the truck was crushed instead of impounded")
	assert(GameState.truck_impounded, "they did not put it in the pound")
	assert(lorry.global_position.distance_to(World.IMPOUND_BAY) < 3.0,
		"it is not in the pound, it is at %s" % str(lorry.global_position))
	assert(lorry.locked and not lorry.hotwired, "they left it open with the keys in")
	assert(lorry.cargo.size() == carried, "the load did not go in with it")
	assert(lorry.get_prompt().contains("Jimmy"), "no way to break into it: %s" % lorry.get_prompt())

	# and nothing sells while it is in there
	assert(GameState.truck().global_position.distance_to(World.SCRAP_POS) > 26.0,
		"the pound is somehow on the weighbridge")

	# take it back the same way you take anything
	lorry.unlock()
	lorry.hotwire()
	player.global_position = lorry.global_position + Vector3(3, 0, 0)
	player.enter_vehicle(lorry)
	assert(not GameState.truck_impounded, "driving it out did not get it off the books")
	assert(lorry.cargo.size() == carried, "the load did not survive the trip")
	player.exit_vehicle()
	print("[SMOKE] impound: caught in the truck, %d part(s) still aboard, stole it back" % carried)

	# or pay for it
	var world_node := get_tree().get_first_node_in_group("world") as World
	world_node.impound_truck(lorry)
	assert(GameState.truck_impounded, "it did not go back in")
	var fee := GameState.impound_fee()
	GameState.add_money(fee)
	var before := GameState.money
	assert(GameState.recover_truck() == "", "the fee would not go through")
	assert(not GameState.truck_impounded, "paid and it is still in there")
	assert(GameState.money == before - fee, "the fee did not come out")
	assert(lorry.global_position.distance_to(World.GARAGE_POS + World.TRUCK_SPACE) < 3.0,
		"it was not dropped off in its own space")
	assert(not lorry.locked and lorry.hotwired, "they gave it back locked")
	print("[SMOKE] impound: $%d fee puts it back outside the shop" % fee)

	# a car that was never yours is still gone for good
	var borrowed := world.spawn_vehicle("beater", player.global_position + Vector3(4, 0, 0))
	await get_tree().physics_frame
	borrowed.locked = false
	borrowed.hotwired = true
	player.enter_vehicle(borrowed)
	player._get_busted()
	assert(not is_instance_valid(borrowed) or borrowed.is_queued_for_deletion(),
		"somebody else's car went to the pound as well")
	busy = false

## Taking a car off whoever is driving it, and what happens if it goes wrong.
func _check_carjack() -> void:
	busy = true
	var driven: TrafficCar = null
	for n in get_tree().get_nodes_in_group("vehicle"):
		if n is TrafficCar and (n as TrafficCar).has_occupant():
			driven = n
			break
	assert(driven != null, "no ambient car has anybody driving it")
	assert(driven.locked, "a car in traffic should not be sat there unlocked")
	# whatever tier it is, the prompt is about the person in it, not the lock
	assert(not driven.get_prompt().contains("Jimmy the"),
		"the prompt still offers to jimmy an occupied car: %s" % driven.get_prompt())
	var fit := driven.occupant_scale()
	var seat := driven.seat_point(true) - Vector3(0, PersonMesh.HIP * fit, 0)
	assert(driven.occupant.position.distance_to(seat) < 0.01, "the driver is not sat on the seat")
	# and small enough to be inside the car rather than wearing it
	assert(seat.y + PersonMesh.HIP * fit + 1.25 * fit < driven._cabin_height() + 0.05,
		"their head is through the roof")

	# out they get, dressed exactly as they were at the wheel
	var was_seed := driven.occupant_seed
	var walkers := get_tree().get_nodes_in_group("pedestrian").size()
	var thrown := driven.eject_occupant()
	assert(thrown != null, "nobody got out")
	assert(not driven.has_occupant(), "they are still in there")
	assert(thrown.outfit_seed == was_seed, "the person in the road is not the one who was driving")
	assert(get_tree().get_nodes_in_group("pedestrian").size() == walkers + 1,
		"the driver did not join the street")
	assert(thrown.panic_until > 0.0, "they took it rather well")

	# and the version where they keep the car
	var runaway: TrafficCar = null
	for n in get_tree().get_nodes_in_group("vehicle"):
		# the cruisers stood in the station yard are TrafficCars too, and they
		# are switched off: one of those cannot bolt anywhere
		if n is TrafficCar and n != driven and (n as TrafficCar).is_physics_processing():
			runaway = n
			break
	assert(runaway != null, "no second car in traffic")
	runaway.bolt()
	assert(runaway.fleeing > 0.0, "a failed jacking left them idling at the lights")
	var before := runaway.global_position
	for f in 240:
		await get_tree().physics_frame
	assert(before.distance_to(runaway.global_position) > 12.0,
		"they only got %.1fm away" % before.distance_to(runaway.global_position))
	print("[SMOKE] carjack: driver dragged out and legging it, a failed one got %.0fm clear" % [
		before.distance_to(runaway.global_position)])

	# anything past a junker is immobilised: you get nowhere near the driver
	# without a key tool, and with one the reader comes out before they do
	var had := GameState.owned_theft_tools.duplicate()
	GameState.owned_theft_tools.erase("scanner")
	GameState.owned_theft_tools.erase("duplicator")
	var posh := world.spawn_vehicle("sedan", player.global_position + Vector3(8, 0, 2))
	await get_tree().physics_frame
	posh.add_occupant(41)
	await get_tree().physics_frame
	assert(not GameState.can_carjack(posh.data), "a tier-2 car rolled over without a key tool")
	assert(GameState.can_carjack(GameData.VEHICLES[0]), "a junker wants a key tool it should not")
	assert(posh.get_prompt().contains("LOCKED DOWN"), "no sign it is immobilised: %s" % posh.get_prompt())
	player.begin_carjack(posh)
	assert(not hud._teardown.active, "it let us start on a car we cannot finish")
	# buy the reader and the job grows a stage on the front of it
	GameState.owned_theft_tools["scanner"] = 1
	assert(GameState.can_carjack(posh.data), "the scanner did not open it up")
	assert(posh.get_prompt().contains("[E] Drag the driver"), "still locked with the scanner in hand")
	player.begin_carjack(posh)
	var jack := hud._teardown
	assert(jack.active, "the carjack rig would not start with the scanner")
	assert(String((jack._stages[0] as Dictionary).type) == "SCAN",
		"the reader is not the first thing that happens")
	assert(jack._stages.size() == GameData.CARJACK_STAGES.size() + 1,
		"the scan stage replaced something instead of going in front")
	jack.abort()
	posh.queue_free()
	GameState.owned_theft_tools = had
	print("[SMOKE] carjack: a tier-2 car is locked down until the scanner is bought, then it scans first")

	# the door comes open as part of hauling on it, and the thing you drag out
	# after that is the person who was sitting there
	var mark := world.spawn_vehicle("rustbucket", player.global_position + Vector3(5, 0, 2))
	await get_tree().physics_frame
	mark.add_occupant(99)
	await get_tree().physics_frame
	player.begin_carjack(mark)
	var td := hud._teardown
	assert(td.active, "the carjack rig would not start")
	assert(not mark.door_open("door_l"), "the door was hanging open before we touched it")
	# the first stage IS the door: hauling on it swings the car's own hinge,
	# rather than a stand-in coming away and an animation playing afterwards
	var haul: Dictionary = td._props[0]
	assert(String(haul.st.get("swing", "")) == "door_l", "stage one is not the door itself")
	# there is nothing drawn for it -- it is the car's own door -- so a ring on
	# the handle is the only thing saying where to take hold
	assert(haul.ghost != null and (haul.ghost as Node3D).visible,
		"no mark on the door telling us to grab it")
	var pull := td._screen_dir(haul)
	for _tug in 40:
		if haul.done:
			break
		td._drag_pull(haul, pull * 45.0)
	assert(mark.door_open("door_l"), "hauling on the door did not open it")
	await get_tree().create_timer(0.7).timeout
	assert(String((td._stages[td._stage] as Dictionary).get("mesh", "")) == "driver",
		"the second stage is not the driver")
	assert(not mark.occupant.visible, "they are sat there and in your hands at the same time")
	td.abort()
	assert(mark.occupant.visible, "the driver never came back after walking away from it")
	mark.queue_free()
	print("[SMOKE] carjack: the door opens on the first pull, the driver is the second")

	# and the player is visible behind the wheel of whatever they drive
	var ride := world.spawn_vehicle("beater", player.global_position + Vector3(4, 0, 0))
	await get_tree().physics_frame
	ride.locked = false
	ride.hotwired = true
	player.enter_vehicle(ride)
	await get_tree().physics_frame
	assert(player.current_vehicle == ride, "did not get in")
	assert(player.body_mesh.visible, "the driver seat is empty from outside")
	assert(player.body_mesh.global_position.distance_to(ride.global_position) < 2.0,
		"the model is not in the car it is driving")
	player.exit_vehicle()
	ride.queue_free()
	print("[SMOKE] the player rides in the seat, not on top of it")
	busy = false

func _check_model_part() -> void:
	var car := Vehicle.new()
	car.setup(GameData.vehicle_by_id("rustbucket").duplicate(true))
	world.add_child(car)
	car.global_position = Vector3(120, 0.2, -120)
	car.set_as_job()
	world.jobs.append(car)
	await get_tree().physics_frame

	assert(car.data.has("model"), "the junker is not using a model any more")
	for piece in ["door_r", "door_l", "seat_r", "seat_l", "engine"]:
		assert(car._split_pieces.has(piece), "the splitter did not produce %s" % piece)
	# the whole door, not just the outer skin: it is cut out of the body, the
	# interior and the underbody, and all three pieces have to come away
	assert(car._split_pieces.door_r.size() >= 3,
		"the door came off in %d piece(s) -- it should bring its skin, its card and its frame"
			% car._split_pieces.door_r.size())
	# cut on the boundary rather than sorted by centre: nothing in the door may
	# hang past the region it came out of, or it tears off with a ragged edge
	var cut: AABB = car.data.model_split[0].regions.door_r
	var inv := car.global_transform.affine_inverse()
	for piece in car._split_pieces.door_r:
		var b: AABB = (inv * (piece as MeshInstance3D).global_transform) * piece.mesh.get_aabb()
		assert(cut.grow(0.02).encloses(b),
			"a door piece overhangs the cut: %s is not inside %s" % [str(b), str(cut)])
	print("[SMOKE] model split into %s" % str(car._split_pieces.keys()))

	# the real door, not a stand-in box, and it takes its window with it
	var visual := car.make_part_visual("door_r")
	assert(visual != null, "no real mesh handed over for the door")
	assert(visual.get_child_count() > car._split_pieces.door_r.size(),
		"the door visual left its glass behind")
	var vis_box := AABB()
	for i in visual.get_child_count():
		var mi := visual.get_child(i) as MeshInstance3D
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		vis_box = b if i == 0 else vis_box.merge(b)
	assert(vis_box.get_center().length() < 0.5,
		"the loose door is drawn %.2fm away from itself" % vis_box.get_center().length())
	visual.queue_free()

	# the door stops at the front of the door and not somewhere over the wing:
	# cut it too far forward and taking it off opens the engine bay with it
	var door_box := car.part_bounds("door_r")
	var bay := car.part_bounds("engine")
	assert(door_box.position.z > bay.end.z,
		"the door cut reaches into the engine bay: door starts at %.2f, the bay ends at %.2f" % [
			door_box.position.z, bay.end.z])

	# The door is hauled open before any of this starts, so every fastener has
	# to land on the hinge pillar it is actually bolted to -- on the hinge line
	# in z, and inboard of the skin rather than hanging in the air where the
	# door used to be. They face aft as well: you unscrew them stood in the
	# doorway, not reaching round the outside of the car.
	var hinge_z: float = door_box.position.z + 0.06
	for st in GameData.PARTS.door_r.stages:
		if String(st.type) == "PULL":
			continue
		assert(absf((st.dir as Vector3).z) > 0.9,
			"a door fastener faces %s -- it should face out of the shut line" % str(st.dir))
		for at in st.at:
			var p: Vector3 = car.rig_prop(at, "door_r")
			assert(absf(p.z - hinge_z) < 0.3,
				"a door fastener at %s is not on the hinge line (z %.2f)" % [str(p), hinge_z])
			assert(p.x < door_box.end.x and p.x > door_box.position.x - 0.25,
				"a door fastener at %s is not on the pillar (door spans x %.2f..%.2f)" % [
					str(p), door_box.position.x, door_box.end.x])
	var lug: Vector3 = car.rig_prop(GameData.PARTS.wheel_fr.stages[0].origin, "wheel_fr")
	var hub := car.part_bounds("wheel_fr").get_center()
	assert(absf(lug.y - hub.y) < 0.2 and absf(lug.z - hub.z) < 0.25,
		"the lug nuts at %s are not on the hub at %s" % [str(lug), str(hub)])
	print("[SMOKE] door fasteners out at x %.2f, lug nuts on the hub" % car.rig_prop(
		GameData.PARTS.door_r.stages[1].at[0], "door_r").x)

	# and the rig can build the stage that drags it off
	hud._start_part(car, "door_r", false)
	var td := hud._teardown
	assert(td.active, "the teardown rig would not start on the model car")
	td._stage = GameData.PARTS.door_r.stages.size() - 1     # the PULL
	td._build_stage()
	assert(td._props.size() > 0, "the pull stage built nothing")
	assert(String(td._props[0].type) == "PULL", "expected the pull stage")
	assert(td._props[0].node.position.distance_to(door_box.get_center()) < 0.1,
		"the door being dragged off is not where the door is")
	print("[SMOKE] pulled the real door off the model without falling over")
	td.abort()
	hud.close_panel()

	# and it is still that door in the back of the truck, not a stand-in block
	var truck := GameState.truck()
	var item := PartItem.create("door_r", 40, String(car.data.name),
		car.data.get("color", Color(0.6, 0.6, 0.6)), car.make_part_visual("door_r"))
	get_tree().current_scene.add_child(item)
	await get_tree().process_frame
	var slot := truck.cargo.size()
	assert(truck.load_part(item), "the truck would not take the door")
	assert(truck.cargo[slot].get("visual") != null,
		"the door lost its real mesh on the way into the truck")
	assert(truck._stack.get_child(slot).get_child_count() > 0, "nothing stacked in the bed")
	print("[SMOKE] the door in the back of the truck is the door")

	# carried and stacked at full size: a door you are lugging about is the
	# same size as the hole it came out of
	var loose := PartItem.create("door_r", 40, "test", Color(0.6, 0.6, 0.6),
		car.make_part_visual("door_r"))
	get_tree().current_scene.add_child(loose)
	await get_tree().physics_frame
	loose.global_position = player.global_position + Vector3(2, 0, 0)
	player.pick_up(loose)
	assert(loose.scale.is_equal_approx(Vector3.ONE),
		"a carried door is scaled to %s" % str(loose.scale))
	var held := (loose as Node3D).get_child(0) as Node3D
	var span := _visual_span(held)
	assert(span > 1.0, "the door in your hands is only %.2fm across" % span)
	player.drop_carried()
	assert(loose.scale.is_equal_approx(Vector3.ONE), "putting it down rescaled it")
	print("[SMOKE] a carried door is %.2fm across, the same as it was on the car" % span)
	loose.queue_free()
	truck.unload_all()

	world.jobs.erase(car)
	car.queue_free()
