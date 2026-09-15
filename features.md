# Steal and Deal — feature planning

Design notes for things that are not built yet. Anything already in the game is
described in `README.md`; the story sits in `story.md`.

---

## Placed cars and gated spawns

**The problem with ambient traffic:** every car is interchangeable. If a
specific car matters to the story or to a job, it cannot come out of the same
random pool as everything else, or the player will find one by accident and the
moment is gone.

**The rule:** a car is either *ambient* (generated, endless, forgettable) or
*placed* (one instance, a known spot, spawned by something happening). Placed
cars never appear in traffic and never appear in a car park.

**How it should work**

- A placed car has an id, a spawn point, and a **condition that has to be true
  before it exists at all**. Until then it is not in the world — not parked,
  not driving, nowhere.
- Conditions are things the game already tracks or could: a story beat reached,
  a skill level, a contact unlocked, a total earned, a day of the week, an
  hour of the night.
- Once spawned it stays where it was put until taken. If the player wrecks it
  or loses it, that is the outcome — it does not quietly respawn. (Possible
  exception: a story-critical car re-places itself after a few days with a
  line about it turning up somewhere else. Decide per car.)
- Taking one should feel different: it is the only one, and somebody will
  notice it is gone. Placed cars start hotter than ambient ones.

**The first one is the beige beater in Act 0.** One beater, east side, exists
from the moment the game starts and never respawns. It is also the reason the
Beige Beater should probably come *out* of the ambient pool entirely — the
first car you ever steal should not be a model you have already seen forty of
on the way to work.

**Data shape, roughly**

```
{ "id": "beater_tutorial", "car": "beater", "at": Vector3(...), "yaw": ...,
  "needs": {"story": "day_one"}, "heat": 0.6, "respawn_days": -1 }
```

---

## Contacts and gigs

Separate from the order board. The board is *volume* — anonymous, repeatable,
always there, pays by the part. Contacts are *authored* — a named person, a
specific car, a reason, and they only talk to you once you are worth talking
to.

**How you get them**

Contacts unlock on some mix of:

- **Skill level** — you are visibly competent now.
- **Money earned to date** — not money held; a lifetime figure, so spending
  does not lock you out.
- **Story progress** — a beat in `story.md` opens a door.
- **Standing with a faction** — see territory, below.

A contact should arrive as an *event*, not a menu unlock: a note under the
shutter, a number written on the board, somebody waiting by the truck when you
get back. The player should be able to point at the moment they got it.

**What a contact gives you**

A **gig**: one job, hand-written, with a fixed reward and usually a
complication. Unlike a board order, a gig can:

- name a **specific placed car** that only exists because the gig exists
- require the car **whole** rather than parted out
- require it **undamaged** (a real constraint now that damage is per panel)
- require it **cold** — resprayed and with the numbered panels off, which is
  what the laundering systems are for
- happen in a **window** — a car that is only in that car park on Thursday
  nights
- go **wrong on purpose** as a story beat

**Progression sketch**

| Tier | Unlocks around | Contact | What they want |
|------|----------------|---------|----------------|
| 1 | the start | the brother | the beater, three parts off it |
| 2 | skill 3 / first debt paid | Marta at the yard | tidy cars, whole, no damage |
| 3 | a district opened | the body shop on Fourth | matched pairs — two of the same model |
| 4 | notoriety | the fence on Alder | tier-3 cars, cold, no numbers on anything |
| 5 | story | the one who set him up | the job that gets you to the end |

**Why it is not the board**

The board should stay dumb and reliable — it is the thing you do when you do
not know what to do. Gigs are the thing you *plan around*. Keeping them apart
means the board never has to carry story weight and gigs never have to be
repeatable.

---

## Gang territory

Districts get an owner and a difficulty. Sketch:

- Better cars spawn in a gang's district — tier 3 and 4 weighted heavily.
- Lookouts on corners: your sight penalty is worse there, so you are noticed
  faster.
- A theft in their territory calls **them**, not the police. Faster cars, more
  aggressive, no arrest — they shoot, and if they get the car back it is gone.
- Wanted stars do not clear at the district line; you have to be two blocks out.
- **Standing** per gang: sell to their fence and it rises, which buys you quiet
  passage — and makes the rival gang hostile. Territory becomes a choice about
  who you work for rather than a difficulty slider.

Depends on: districts (built), heat (built), buyers (built), a faction table
(not built).

---

## Staff and automation

Later. Wants garage tier and a work queue first.

- Hire a stripper: slowly pulls parts off whatever is on a ramp while you are
  out. Costs a daily wage.
- Hire a driver: takes a full truck to a buyer on its own, and can get pulled
  over.
- The point is a money sink that converts cash into time, and a reason to care
  about garage tier beyond bay count.

---

## Smaller things worth doing

- **Plate swapping** as a third laundering step alongside respray and panels.
- **Checkpoints** when the truck is hot — a reason to launder before a run.
- **Weight affecting handling** on the truck, so a full load is a decision.
- **Dents visible on the model** — the per-panel damage exists in data now but
  nothing shows it.
- **A phone/contacts screen** once there is more than one contact to hold.
