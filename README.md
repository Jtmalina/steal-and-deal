# Steal and Deal — *Friend Slop Chop Shop* prototype

A playable Godot 4.7 vertical slice of the chop-shop loop:

> find a car → jimmy it → escape the cops → drive it home → strip it → sell the parts → buy better gear → steal better cars

Everything is generated in code with placeholder boxes. No art pipeline, no scene
spaghetti — open it and iterate.

## Run it

Open the folder in Godot 4.4+ and press F5, or:

```bash
godot --path . 
```

Headless check of the whole loop (steal → deliver → dismantle → sell → upgrade → police):

```bash
godot --headless --path . --quit-after 2000 -- --smoke
```

## Controls

| Key | Action |
|-----|--------|
| WASD | walk / drive (W accelerate, S brake then reverse) |
| Shift | sprint |
| Space | jump on foot (handbrake in a car) |
| Space | handbrake |
| G | put down the part you are carrying |
| Mouse | look |
| E | interact (break in, dismantle, workbench, sell) — also the timing key in the break-in bar |
| 1-6 / wheel | pick the belt loop, i.e. what is in your hand |
| LMB | grab and work a part during teardown; otherwise use whatever you are holding |
| R | reload |
| F | get out of the car |
| H | help |
| Esc | free the cursor / close a panel |

The compass line under the cash tells you where the GARAGE and the SCRAP YARD are.

## The loop

1. **Find** — parked cars line the kerbs, and 16 ambient cars drive the grid properly:
   right-hand lanes, junctions on a signal cycle, queueing behind each other. Any of them
   can be stolen — walk in front of one and the driver panics and stops.
2. **Jimmy the door** — a lever, not a timing bar. Hold LMB on the jimmy handle above the
   window seal and slide it along; the tip swings **the opposite way** down inside the
   door, because that is what a lever does. The lock rod runs along the door with one to
   three spots on it that will actually lift the lock. Get the tip onto a spot and **pull
   up** to hook it. Miss and the tool clatters about inside the door — a noise meter fills,
   and when it is full you give up and the street has heard the whole thing.

   Your theft skill and gear widen the slop you get on each spot; a nicer car narrows it
   and adds more spots. A junker is one catch with 19 cm of slop; a Chrome Land Yacht is
   three catches with 6 cm.
3. **Hotwire it** — the door being open is not the same as the car going anywhere. Four
   stages, all mouse-driven, from the driver seat with the door hanging open:
   1. **Rip the shroud** off the steering column.
   2. **Find the wires.** Six hang out of the loom; three matter. Red is battery, brown is
      ignition, yellow is starter — grab a wrong one and it bites you.
   3. **Scrape each one back.** Drag across the wire and the insulation slides down off it,
      baring the copper at the top — the end you are about to twist onto something.
   4. **Twist the ignition onto the battery** — drag it across and the gap closes; the two bared ends end up side by side
      with a copper twist wrapping them. Then **flash the starter across the pair** — you
      can see the pair you made sitting there, the starter sparks against it, and you take
      it off again, because you flash a starter, you do not leave it connected.

   The door pulls shut behind you once it is running. Bail out halfway and the door stays
   open — walk back and `[E]` picks up where you left off.
4. **Escape** — stealing rolls for a pursuit. Cruisers spawn ~40–55 m away and drive at
   you. Stay more than 55 m from every unit for 7 s to drop a star. Get cornered at low
   speed and you are busted: the car is impounded and you eat a $250 fine.

   Driving is arcade but modelled: a **five-speed box** with a torque curve, so pull is
   strongest just after a shift and tapers as the gear runs out, with a 0.18 s lull while
   the clutch is in. Acceleration is smooth and monotonic all the way to the rated top
   speed — the speedo and gear readout sit bottom-right so a shift reads as a shift.
   Steering bites once the car is rolling and calms down as it speeds up; the handbrake
   scrubs speed and tightens the turn. S brakes first and only reverses once you have
   stopped. Hitting a **wall** (and only a wall) costs speed and condition.

   A junker tops out around 61 km/h, a sedan 90, a sports car 126. Police cruisers run 97,
   so they will run down anything mid-tier and lose a sports car on a straight.

5. **Deliver** — drive into the garage (north-west). Cops on your tail? It refuses.
   Bays = garage tier, so 1 job at a time until you upgrade.
6. **Chop it** — `[E]` on the car in the bay. Two ways to make money off it:
   - **Crush it whole** — the default, always available. The crusher pays bare metal by
     weight and nothing for what the parts are actually worth. This is the floor price,
     and it *drops as you pull parts off*, because the shell gets lighter.
   - **Part it out** — worth roughly 4x the crush price, but you have to do the work.
     The camera moves in on the actual car, the cursor comes free, and you take the part
     off with the **mouse**. No abstract bars:

     | Prop | What you do | How it goes wrong |
     |---|---|---|
     | **Bolt / lug nut** | hold LMB on it and **turn the mouse anticlockwise** — lefty loosey | turning the wrong way gets you told off; flailing rounds the head, −4% |
     | **Battery clamp** | same, but black terminal first — the stages enforce it | — |
     | **Connector** | hold LMB and **ease it straight out**, slowly | yank it and the clip **snaps**, −11% |
     | **Cut line** | hold LMB and **drag back and forth** across the pipe | the blade heats up; cook it and it binds, −7% |
     | **Freed part** | hold LMB and **drag it off the car** | heavy parts need a much longer drag without a hoist |
     | **Jack handle** | hold LMB and drag **down, then up**. Again. And again. | — |

     **Every fastener sits where it actually is on that car.** The hood has four hinge
     bolts along its back edge by the windscreen; the door has two bolts per hinge down
     its front pillar plus the harness boot beside them; five lug nuts ring the hub;
     six engine mounts are spread round the block down in the bay; the heat-shield bolts
     and the two pipe cuts run along the exhaust under the floor. The camera frames
     whatever cluster you are working on.

     **And you drag the actual part off.** The pull stage is the real thing in the real
     place — the hood is a body-coloured panel, the door is a panel with its window, the
     wheel is a tyre on a rim, the engine is a block with a head and a pulley, the cat is
     a can on a pipe. The car hides its own copy while you have hold of it, so what you
     drag is what comes off, and it stays gone afterwards.

     Better tools mean **fewer turns of the mouse per fastener** (2.5 → 1.75 → 1.0), not
     fewer bolts on the car.
7. **Order of operations matters**, the way it does in a real teardown. The car is built
   from separate pieces, so pulling one opens up the next:
   - The **hood comes off first** — underneath is a real recessed engine bay with the
     block and the battery sitting in it. Until then there is nothing to reach.
   - Then the **battery**: negative terminal, positive terminal, hold-down clamp, lift it
     out. The engine will not let you start until it is gone.
   - The **doors** come off before the **seats** — the greenhouse is a roof on pillars, so
     with a door gone you can see and reach the seat rails through the aperture.
   - **Wheels and the transmission need the car in the air**: own a jack (or a lift), then
     actually pump the handle. The car rises onto orange stands.
   - The **catalytic converter needs the lift**, and the pipe wants a reciprocating saw.
     Without one you are on a hacksaw at half speed.
   - **Hood and doors** unbolt properly, or — if you own the saw — you can cut the hinges
     instead: much faster, and the part sells for ~60% of book.
   - **Engine and transmission** come out on the hoist. Without one it is the same drag at
     nearly twice the distance.

8. **Carry and load** — every part you pull lands **in your hands**, as a real object.
   `[G]` puts it down anywhere; parts you drop stay on the garage floor. To turn them into
   money you carry them to your truck one at a time and `[E]` to load. The starting **Rusty
   Pickup** holds 20 units and a stripped junker is 22, so the first car will not quite fit —
   that is the point. Parts are sized honestly: an engine is 4 units, a wheel is 1.
9. **Haul and sell** — drive the truck to the yard and sell what is in the back. Nothing on
   your garage floor is worth anything until it has been driven over. With a **tow hitch**
   you can instead drag a whole junker over and weigh it in as-is — no teardown, no money
   either. Buyers pay differently:

   | Buyer | Unlock | Pays |
   |---|---|---|
   | Gordo Scrap Yard | free | flat rate, buys anything |
   | Ferret the Mechanic | $2,500 | +50% engines and boxes, +30% cats and wheels, −10% the rest |
   | Deniz, Discreet Electronics | $3,500 | +90% electronics, +40% batteries, −15% the rest |
   | The Collector | $9,000 | +35% on everything |

   Trucks: **Rusty Pickup** (20) → **Box Truck** $6,000 (48) → **Semi and Trailer** $18,000 (110).

10. **Upgrade** — the **computer** in the garage orders theft tools, teardown equipment,
   garage tiers, trucks, the tow hitch, belts and buyer contacts. The **workbench** beside it
   is storage: whatever you own but are not carrying sits there.

Starting cash is $500. A junker crushed whole pays about **$175**; the same junker parted
out is roughly **$620–740**, and a family sedan runs to **$1,600**. So the lazy option is
always there and always the worst one — the first Reinforced Jimmy ($750) is one properly
stripped car away, or four crushed ones.

## Files

| File | What it is |
|------|-----------|
| `scripts/GameData.gd` | **All tuning data**: parts, theft tools, vehicles, shop catalogue. Start here. |
| `scripts/GameState.gd` | Autoload: money, skill, owned gear, stash, wanted level. |
| `scripts/Main.gd` | Boots environment, world, player, HUD, police dispatch. |
| `scripts/World.gd` | Procedural city, garage (rebuilt on upgrade), scrap yard, car spawning. |
| `scripts/Player.gd` | On-foot controller, camera rig, interaction targeting, ride-the-car driving. |
| `scripts/Vehicle.gd` | Gearbox and arcade handling; car built from named removable pieces (hood, doors, wheels, seats, engine, cat...), arcade driving, break-in state, part removal. |
| `scripts/PoliceCar.gd` / `PoliceDispatch.gd` | Pursuit AI and the wanted/escape timer. |
| `scripts/Teardown.gd` | The 3D hands-on rig — break-in, hotwire and teardown all run through it: prop spawning, close-up camera, mouse interaction, quality penalties. |
| `scripts/HUD.gd` | Every piece of UI, built in code. |
| `scripts/PartItem.gd` | A pulled part as a real object: carried, dropped, loaded. |
| `scripts/Truck.gd` | Haulage: cargo, the visible pile in the bed, towing. |
| `scripts/Traffic.gd` | Lane geometry, the signal clock, traffic light posts, spawning cars and people. |
| `scripts/Pedestrian.gd` | Somebody walking the pavement grid. |
| `scripts/PoliceOfficer.gd` | On foot: walking a beat, chasing you, or heading back to the car. |
| `scripts/Gunplay.gd` | One raycast, one tracer, one `take_damage` interface for everything shootable. |
| `scripts/PersonMesh.gd` | One box person, used by the player, the public and the police. |
| `scripts/TrafficCar.gd` | An ambient driver: lane keeping, lights, queueing, yielding. |
| `scripts/PartMesh.gd` | One place that knows what every part looks like. |
| `scripts/Interactable.gd` | Generic `[E]` prop — prompt + callable. |
| `scripts/SmokeTest.gd` | Headless run-through of the whole loop. |

## Extending it

- **New car**: add a dict to `GameData.VEHICLES`. Nothing else to touch.
- **New part**: add to `GameData.PARTS` with its `mass` and its `stages`. A stage is a
  prop `type` (BOLT / CLAMP / PLUG / CUT / PULL / PUMP), a `count`, an `anchor` naming
  where on the car it lives, and a `pattern` (circle / row / col / rect) for the layout.
  Add `needs` for a tool gate, `lifted: true` if the car has to be in the air, `after: [...]`
  for teardown-order prerequisites, and an optional `alt` fast-and-dirty route.
- **Placing fasteners**: a stage carries `at` (a list of exact vehicle-local positions),
  `dir` (which way it backs out) and `cam` (where the camera watches from). Omit `at` and
  it falls back to `origin` + a `pattern` (used for the lug-nut and bellhousing rings).
- **New part shape**: add a case to `PartMesh.build` and register the matching
  meshes on the car with `_register(part_id, node)` in `Vehicle._build`, so the car loses
  that piece when the part comes off.
- **New teardown verb**: a mesh case in `_make_prop` and a `_drag_*` handler in
  `Teardown.gd`, then use its name as a stage `type`.
- **New theft tool**: it is already declared in `GameData.THEFT_TOOLS` (lockpick, key
  scanner, reader, duplicator, electronic bypass, ECU kit). Add a shop entry with
  `kind: "theft_tool"` and set a vehicle's `requires` to `[["bypass", 1]]` — the
  requirement system is OR-of-options, so old routes keep working.
- **New buyer** (mechanic / shady dealer / specialty): copy the scrap-yard
  `Interactable` in `World._build_scrapyard()` and give it a per-part-category
  multiplier when pricing `GameState.inventory`.

## What you carry

A **belt** runs along the bottom of the screen. `[1]`-`[6]` or the mouse wheel pick the loop,
and whatever is in that loop is in your hand — which is what decides what `[LMB]` does.

You start with **two loops**, holding a **Jimmy** and a **Tire Iron** (a melee weapon: 35
damage, short reach, and no noise). Two loops is not many on purpose — buy a pistol and you
have to leave something behind until you widen the belt:

| Belt | Price | Loops |
|---|---|---|
| — | — | 2 |
| Tool Belt | $900 | 4 |
| Rigger Belt | $2,600 | 6 |

The Rigger Belt needs the ordinary one first. Buying either fills the new loops with
anything you own but were not carrying. Sort the belt out at the **workbench** in the garage:
it lists every loop and everything sat on the bench, and you move things between the two.
Anything you order that will not fit on your belt is left on the bench for you.

The belt is not decoration: **the jimmy has to be on you to break into a car.** Leave it at
the shop and `[E]` tells you so.

## Guns

There is a **Battered Pistol** at the workbench for $600 — twelve rounds, `[LMB]` to fire,
`[R]` to reload. The shot is traced from the camera so it lands on the crosshair, and drawn
from your hand so the tracer comes off the gun rather than out of your eyeballs.

The police have rules about when they will draw:

- **One star is a chase.** They will run you down and arrest you, and nobody produces a gun.
- **Two stars and above, they shoot.** From the cruiser window if you are close and clearly
  not pulling over — stop the car and they put it away and come to arrest you instead. On
  foot, any officer chasing you will fire once they are inside 45 m with a clear shot.
- **Shoot at a copper and you are on three stars immediately**, whether you hit or not.
- **Anyone can be killed, not just police.** If a single person within 32 m has a clear view
  of it, it gets called in and you are on at least two stars — and everyone who saw it
  panics and runs. Do it down an alley with nobody about and nothing happens at all.

Rounds that hit a car with somebody in it hurt the person rather than the panel — the
bodywork takes about 30% out of it, and the car is worth less afterwards. An officer goes
down in three pistol rounds; a cruiser takes about eight and is then out of the chase for
good. You have 100 health, patch up slowly once nothing has hit you for six seconds, and if
you run out you wake up in a hospital corridor minus the car and $400.

## The street

Alongside the traffic there are **22 people on the pavements**, walking the same road grid
one lane further out and turning at junctions, each in their own shirt out of ten colours so
the street reads as a street. Everyone in the game — you, the public and the police — is
built by `PersonMesh.build`: big head, hair, eyes and brows, a T-shirt with bare arms out of
the sleeves, jeans that flare at the ankle, and shoes. About one in six is a **copper walking a beat**, and they are worth avoiding for two reasons:

- Once you are wanted, **any copper you walk past joins in on foot** — within 38 m, or at
  any range if they can see you. They chase whether or not a car ever turns up.
- One who **actually sees you at it** — you jimmying or hotwiring a car, within **30 m**, inside
  a 63-degree cone of where they are facing, with nothing solid in between — raises the alarm
  themselves and gives chase. Park the car you are working on between you and them, or pick a
  door they are walking away from.

A marked patrol car that drives past within 34 m while you are at it will call it in too.

About **one traffic car in five is a marked patrol**. Its lightbar is dark until you are
wanted; then it lights up, and if you come within 70 m it hands itself to the dispatcher and
becomes a pursuit unit. Units arrive out of the traffic that was already there rather than
appearing behind you.

### Getting out of the car

A cruiser that has you within 15 m while your car is doing less than 1.8 m/s waits about a
second and then **an officer gets out and comes over on foot**. The cruiser stays parked
while its driver is out. Get the car moving again (over 5 m/s) or open up more than 34 m and
the officer is **recalled** — they run back to the cruiser, get in, and the chase resumes on
wheels. An officer on foot counts as police for getting collared; one walking a beat does
not, until they decide to join in.

## Traffic

The city is a grid, so the ambient drivers need no navmesh — a heading plus three
indices is a whole route. `Traffic.gd` owns the rules, `TrafficCar.gd` drives to them.

- **Lanes.** Every car sits `Traffic.LANE` (3.2 m) to the **right** of the road
  centreline for the way it is facing — US rules. It steers at a pure-pursuit point
  8 m ahead on that lane line, not at the junction 40 m away, which is what actually
  keeps it straight.
- **Signals.** Every junction has two heads on a shared 15 s clock: north-south green,
  amber, all-red, east-west green, amber. Neighbouring junctions run half a cycle apart,
  so the grid has a rolling green rather than the whole city changing at once. Cars stop
  at the line unless they are already committed into the box.
- **Queueing.** Each car looks 15 m up its own lane, eases off as the gap closes and
  stops at 6.5 m. A second, lane-agnostic check hard-stops anything within 5.5 m in front,
  which covers cars swinging through a turn and you wandering into the road.
- **Turns.** Straight 60%, right 30%, left 10%, and the choice is only ever made between
  directions that stay on the map. Cars slow to 4 m/s for a corner, and from the edge of the
  junction they steer at the **exit of the turn** — a fixed point on the new lane a few
  metres down the new road. Chasing a point down the new lane from wherever the car happens
  to be makes it drive at that point in a straight line and sail across the far side of the
  road before hauling itself back; aiming at the exit draws an arc that lands in lane. The
  turn is finished when the car reaches that exit, not when it reaches the middle of the
  junction, which it never does once it is curving. A left-turner waits for a gap in
  oncoming traffic.
- **The junction box.** A car decides at the stop line and sticks to it. Red or amber and
  it can still pull up: it waits at the line. Green but the far side is full: it also waits
  at the line, rather than pulling into the box and stranding everybody. Once it is over
  the line it is going through — a light changing while it is in the junction does not make
  it stop there, and neither does a queue building up ahead; it crawls out instead.
- **People crossing.** Cars yield to anyone on foot in front of them, and pedestrians wait
  at the kerb for anything moving that is heading their way. Neither deadlocks the other:
  a car that has stopped is no longer "coming", so the pedestrian goes.

The smoke test runs the traffic for 25 s and asserts the numbers rather than trusting the
look of it. Overlap is a real separating-axis test on the two car footprints, because
centre-to-centre distance tells you nothing when one car is sat at an angle in a junction.
Lane drift is sampled over the **whole road between the two junction boxes**, including the
stretch right after a turn -- an earlier version skipped the first 16 m after a junction and
so reported a spotless 0.0 m while cars were visibly swinging into the oncoming lane.
A representative run:

```
16 cars, avg 110m travelled, lane drift 3.1m, over the centre line 0.0m, worst overlap 0.02m
junctions: 0 frames stalled inside a box, closest a car came to a walker 2.1m, 651 frames waiting at kerbs
lights cycle NS / all-red / EW, neighbours offset
```

It asserts: nobody over a centre line by more than 1.5 m, no two footprints overlapping by
more than 0.25 m, fewer than 15 frames of anyone stalled inside a junction, no car within
1.6 m of somebody on foot, somebody waited at a kerb, and somebody stopped at a red.

## Tuning dials

| Want | Change |
|---|---|
| Faster / slower cars | `top_speed` and `accel` per vehicle in `GameData.VEHICLES` |
| Gear feel | `GEAR_TOPS`, `GEAR_PULL`, `SHIFT_TIME` in `Vehicle.gd` |
| Steering | `TURN_RATE`, `STEER_RATE` in `Vehicle.gd` |
| Wrench tedium | `GameState.bolt_turns()` |
| Lock difficulty | `GameState.jimmy_tolerance()` and `jimmy_hotspots()` |
| Jimmy lever feel | `Teardown.PIVOT` and `MAX_SWING` |
| Where the garage stations sit | `World._build_garage` |
| Which wires are live | `GameData.HOTWIRE_STAGES` (the `decoy` flags) |
| How close joined ends sit | `Teardown.PAIR_GAP` |
| Crush vs part-out ratio | `GameData.SCRAP_RATE` and `SHELL_MASS` |
| Truck capacity / part bulk | `GameData.TRUCKS[].capacity` and each part's `size` |
| Who pays what | `GameData.BUYERS[].mults` |
| What the hitch can drag | `GameData.TOW_TIERS` |
| Traffic density | the cap in `Traffic._spawn_cars` |
| How busy the pavements are | the cap in `Traffic._spawn_people` |
| How often they get out of the car | `PoliceCar.CORNER_RANGE`, `STALLED`, `BOLTED` |
| What you can hold | `GameData.ITEMS` |
| Belt sizes | `GameData.BELTS` |
| When the police draw | `GameData.SHOOTING_STARS` |
| Weapon damage and accuracy | `GameData.WEAPONS` |
| How sharp-eyed the police are | `PoliceOfficer.SIGHT`, `CONE`, `NOTICE` |
| Who is on the pavement | the officer share in `Traffic._spawn_people`, `PersonMesh.SHIRTS` |
| Signal timing | `Traffic.CYCLE`, `NS_GREEN`, `GAP` |
| How traffic drives | `TrafficCar.CRUISE_SPEED`, `TURN_SPEED`, `LOOKAHEAD`, `SCAN` |
| Junction box size | `Traffic.BOX` and `STOP_LINE` |

## Known prototype edges

- No save/load — it is a single session.
- Police pursue and will get out on foot, but they do not ram, set up blocks, or obey lights.
- Pedestrians walk, queue behind each other and wait at kerbs, but they will not leap out
  of the way if you drive at them deliberately.
- Ambient traffic yields and queues but does not react to the player driving badly beyond
  stopping for whatever is in front of it.
- Car handling is deliberately arcade (`CharacterBody3D`, not a physics vehicle) so it
  stays predictable while iterating.
