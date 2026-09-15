# Sounds

This folder is **not tracked in git**. It holds ~1.2 GB of third-party sound
libraries, which are neither ours to redistribute nor useful to version: they
are immutable inputs that would bloat every clone for no benefit.

`Sfx.gd` does not hardcode any path — it scans `res://Sounds` at load and builds
its banks from whatever it finds (see `const SOUNDS := "res://Sounds"`). So the
game runs without this folder; it is simply silent.

## Restoring it on a fresh clone

Drop the following packs back in, one directory each, keeping the names:

| Directory | Pack |
|---|---|
| `Electromagnetic_NOX_SOUND` | NOX_SOUND — Electromagnetic |
| `Footsteps_Essentials_NOX_SOUND` | NOX_SOUND — Footsteps Essentials |
| `Iceland_Packs_NOX_SOUND` | NOX_SOUND — Iceland Packs |
| `Nature_Essentials_NOX_SOUND` | NOX_SOUND — Nature Essentials |
| `Sao_Miguel_Flows_NOX_SOUND` | NOX_SOUND — São Miguel Flows |
| `Vehicle_Essentials_NOX_SOUND` | NOX_SOUND — Vehicle Essentials |
| `Voices_Essentials_NOX_SOUND` | NOX_SOUND — Voices Essentials |
| `Sample_A_Sound_Effect` | A Sound Effect — sampler |

Plus the loose `workshop - *.wav` files at the top level of this folder.

Sources: <https://www.asoundeffect.com/> — see the `.url` shortcut in
`Sample_A_Sound_Effect/`.

Godot will reimport everything on first open, which takes a few minutes.
