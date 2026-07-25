# Lindisfarne

A single-map Viking raid in Godot 4. One eight-minute run: land on the beach,
raid an undefended monastery, grab loot, and get back to the longship before the
local levy musters and kills you.

The tension is greed against survival on a timer. Loot is physical and heavy —
carrying more slows you down, and the longer you stay, the more defenders
arrive.

Greybox only: `BoxMesh`, `CapsuleMesh`, `CylinderMesh` and flat
`StandardMaterial3D` colours. No imported models, textures or audio.

## Running it

```bash
./play.sh          # play
./play.sh edit     # open the Godot editor
```

Requires `godot` (4.7.x) on `PATH`. The script runs the import step first and
defaults `DISPLAY` to `:0` when unset.

| Input | Action |
|---|---|
| `WASD` | move, relative to the camera |
| `Shift` | sprint |
| Mouse | look |
| `LMB` | attack |
| `RMB` | raise guard |
| `E` / `G` | take loot / drop the last thing you took |
| `Enter` | raid again, on the summary screen |
| `Esc` | release the mouse cursor |

## Layout

```
scenes/
  main.tscn              game root: environment, sun, navigation, player, HUD
  player/player.tscn
  enemies/               training_dummy.tscn, levy_spearman.tscn
  world/                 terrain.tscn, monastery.tscn, longship.tscn
scripts/
  player/                player.gd, camera_rig.gd
  motion/                character_motor.gd   (player AND enemies)
  combat/                health, hitbox, hurtbox, melee_attack, blocker,
                         hit_reaction, hit_info
  ai/                    state_machine.gd, state.gd, perception.gd, states/
  enemies/               enemy.gd, dummy_brain.gd
  loot/                  loot_item.gd, carrier.gd
  muster/                alarm_bell.gd, muster_director.gd
  extraction/            extraction_zone.gd
  globals/               event_bus.gd (Events), run_state.gd (Run)
  juice/                 juice.gd (Juice), camera_shake.gd, damage_flash.gd
  ui/                    debug_hud.gd, health_label.gd
resources/
  materials/             flat greybox colours
  navigation/            island_navmesh.tres (baked, committed)
tools/
  bake_navmesh.gd        re-bake navigation after collision changes
```

## How it is put together

**Composition over god-scripts.** No script owns more than one job. The player
is a thin root that reads input and delegates: `CharacterMotor` owns how
movement feels, `CameraRig` owns mouse look, and every combat rule lives in a
component under `scripts/combat/`.

**The same components run the enemies.** `Health`, `Hitbox`, `Hurtbox`,
`MeleeAttack`, `HitReaction` and `CharacterMotor` are shared by the player, the
training dummy and the levy spearman, with no special cases anywhere. If an
enemy had needed a branch, those components would just be player code in
disguise.

**Each component reduces only what it applies.** `Blocker` owns the damage
reduction because it decides a block happened; `HitReaction` owns the knockback
reduction because it applies knockback. Neither has to ask the other anything.

**Three autoloads, and only three.** `Events` is a global signal bus, `Run`
holds the clock and tally, and `Juice` owns hit-stop and shake requests. Everything else uses direct `@export` node links,
which is right for things in the same scene. The muster is the first system
where the sender genuinely cannot know the receiver — a spearman's eyes do not
know a bell exists — and that is the bar for putting something on the bus.

**Signals point outward, references point down.** Components announce what
happened (`sprint_changed`, `landed`, `hit_taken`, `died`) and never reach up
the tree. `Player` and `Enemy` re-emit their children's signals so outside code
only has to know about the facade. Wiring uses `@export` node links set in the
editor — not `get_parent().get_parent()`.

**The bodies never rotate.** A `Visual` child turns to face travel, so camera
yaw stays independent of facing and hitboxes hang off a stable frame.

**Enemy behaviour is a tree of nodes.** States live under `$StateMachine` as
child nodes rather than as enum values, so each gets its own `@export` tuning
knobs and stage 6's rider can reuse `Chase` and `Dead` untouched. The machine
itself owns no behaviour — every transition rule lives in the state that wants
to leave. For five states and one enemy an enum plus a `match` would be
simpler; this shape is a bet on more enemy types.

## Build stages

| | Stage | Status |
|---|---|---|
| 1 | Third-person controller | done |
| 2 | Greybox monastery, beach, longship | done |
| 3 | Melee, blocking, health, knockback | done |
| 4 | Enemy: navmesh pathing + state machine | done |
| 5 | Loot with weight | done |
| 6 | The muster: alarm, waves, the rider | done |
| 7 | Extraction and run summary | done |
| 8 | Juice pass | done |

## Testing

There is an agent-facing harness under `.claude/skills/run-lindisfarne/` that
drives the game programmatically and dumps a JSON state log, so behaviour is
checked with numbers rather than by squinting at the window:

```bash
DISPLAY=:0 .claude/skills/run-lindisfarne/smoke.sh    # traversal
DISPLAY=:0 .claude/skills/run-lindisfarne/combat.sh   # damage, blocking, arc
DISPLAY=:0 .claude/skills/run-lindisfarne/ai.sh       # the state machine
DISPLAY=:0 .claude/skills/run-lindisfarne/loot.sh     # weight, speed, attack gate
DISPLAY=:0 .claude/skills/run-lindisfarne/muster.sh   # alarm, waves, the rider
DISPLAY=:0 .claude/skills/run-lindisfarne/extraction.sh  # win and death paths
```

## Things that will bite you

- **`Transform3D(...)` in `.tscn` is row-major** —
  `(x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, ox, oy, oz)`. Writing it
  column-major silently produces the *inverse* rotation. Round-trip it through
  Godot rather than hand-deriving one.
- **Node-typed `@export` needs `node_paths=PackedStringArray("prop")`** on the
  node header in the `.tscn`, or the property stays null with no error at all.
- **Run `godot --headless --import` after adding a script.** Without the global
  class cache, `class_name` types fail to resolve and scripts silently do not
  load. `play.sh` does this for you.
- **Re-bake the navmesh after changing level collision:**
  `godot --headless --script tools/bake_navmesh.gd`. It parses static colliders,
  not meshes — the crypt stairs are a smooth ramp with decorative step meshes on
  top, and parsing meshes would bake ledges nothing can climb.
- **AI ranges must sit inside the hitbox's real reach** (2.45 m). Set them
  larger and an enemy parks just out of range swinging at air, which looks
  exactly like your blocking working perfectly.
- **`_ready` propagates children-first.** A child's `_ready` runs before its
  parent's, so the parent's `@onready` vars are still null — which is why
  `StateMachine` has an explicit `start()`.
- **`Input.action_press()` never produces an `InputEvent`.** An
  `_unhandled_input` handler cannot see programmatic input at all, and
  `Input.is_action_just_pressed()` is unreliable for it too — it compares
  against the engine's process-frame counter, so the key reads as held forever
  but never as just-pressed. Poll and track the rising edge by hand.
- **Navigation queries do not work under `godot --script`.** They return zero
  even with a good navmesh. Verify pathing by driving the real game.
