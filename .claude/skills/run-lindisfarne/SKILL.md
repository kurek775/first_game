---
name: run-lindisfarne
description: Build, launch, drive, and screenshot the Lindisfarne Godot 4 game. Use when asked to run, start, play, test, or screenshot the game, to capture frames of the greybox level, or to verify that a movement, camera, collision, or scene change actually works in the running app rather than only on paper.
---

# Running Lindisfarne

A single-map Viking-raid greybox in **Godot 4.7.1**, GDScript. There is no
compile step and no package manager — Godot loads `.tscn`/`.tres`/`.gd` from
source. "Building" means running the importer once.

The game is driven by **`.claude/skills/run-lindisfarne/driver.gd`**, which
instantiates a game scene, runs a semicolon-separated command program against
it, saves PNGs, and dumps a JSON state log. Use it instead of launching the
window and staring at it — the state log is what tells you whether movement
and collision are actually correct.

All paths below are relative to the project root (the directory holding
`project.godot`).

## Prerequisites

`godot` on `PATH`. Verify:

```bash
godot --version   # 4.7.1.stable.official.a13da4feb
```

No system packages were needed on this machine — it has a live X11 display at
`:0`. Screenshots require a real display; see Gotchas for the headless case.

## Build

Required once after cloning, and after adding or renaming any script:

```bash
godot --headless --import
```

Skipping this does **not** produce a missing-file error. It produces
`Could not find type "CharacterMotor" in the current scope`, the player scripts
fail to load, and the game runs with a frozen character — see Troubleshooting.

## Run: agent path

### Canned traversal (start here)

Lands on the beach, sprints through the gate, crosses the court into the church
nave, descends the crypt stairs, then enters the side building:

```bash
DISPLAY=:0 .claude/skills/run-lindisfarne/smoke.sh /tmp/lindisfarne-shots
```

Writes `01_beach_spawn.png` … `10_side_inside.png` plus `log.json`. Read the
PNGs. Known-good signature for the current greybox:

```
01_beach_spawn       pos=(  -6.0,  0.00,  42.0) ground=True  speed=0.0
02_gate              pos=(   0.0,  0.00,  12.9) ground=True  speed=7.5  through the gate
03_courtyard         pos=(   0.0,  0.00,   0.2) ground=True  speed=7.5  crossing court
04_church_door       pos=(   0.0,  0.00,  -7.2) ground=True  speed=4.5  church doorway
05_nave              pos=(   0.0,  0.00, -13.5) ground=True  speed=4.5  inside the nave
06_stair_top         pos=(   9.0,  0.00,   9.0) ground=True  speed=0.0  stairwell mouth
07_on_stairs         pos=(   9.0, -1.79,   1.9) ground=True  speed=4.5  on the stairs
08_crypt             pos=(   9.0, -4.50,  -4.9) ground=True  speed=4.5  underground
09_side_door         pos=(  12.0,  0.00, -22.0) ground=True  speed=0.0  side building
10_side_inside       pos=(  18.6,  0.00, -22.0) ground=True  speed=4.5  inside side bldg
```

Re-extract that table from any run:

```bash
python3 -c "
import json
d=json.load(open('/tmp/lindisfarne-shots/log.json'))
for e in d:
    if e['cmd'].startswith('shot'):
        p=e['pos']
        print('%-20s pos=(%6.1f,%6.2f,%6.1f) ground=%-5s speed=%-4s %s' % (
            e['cmd'][5:], p[0],p[1],p[2], e['grounded'], e['speed'], e.get('note','')))
"
```

What the columns catch: `speed` pins walk/sprint tuning (4.5 / 7.5); the `y`
progression `0.00 → -1.79 → -4.50` proves the crypt stairs are walkable;
`ground=True` on every row proves nothing wedges on a doorway, gate or step;
and the `z` values prove the doorway and gate gaps are actually passable.

### Combat regression

```bash
DISPLAY=:0 .claude/skills/run-lindisfarne/combat.sh /tmp/lindisfarne-combat
```

Known-good. Note each phase teleports the player back into reach first —
knockback pushes you out of range and the dummy cannot chase (stage 4's job):

```
01_before      player_hp=100.0  dummy_hp=120.0  dist=2.00
02_swing1      player_hp=100.0  dummy_hp= 95.0  (-25.0)  dist=4.46
03_swing2      player_hp=100.0  dummy_hp= 70.0  (-25.0)  dist=3.71
04_swing3      player_hp=100.0  dummy_hp= 45.0  (-25.0)  dist=2.89
05_unguarded   player_hp= 88.0  (-12.0)   no guard
06_blocked     player_hp= 84.4  (-1.8/hit) guard up, frontal — 15% chip
07_back_turned player_hp= 72.4  (-12.0)   guard up but facing away
```

Read it with:

```bash
python3 -c "
import json
d=json.load(open('/tmp/lindisfarne-combat/log.json'))
prev_p=100.0; prev_f=120.0
for e in d:
    if not e['cmd'].startswith('shot'): continue
    hp=e.get('hp'); f=[x for x in e.get('foes',[]) if 'Passive' in x['name']][0]
    print('%-14s player_hp=%-6s (-%4.1f)  dummy_hp=%-6s (-%4.1f)  dist=%5.2f  %s' % (
        e['cmd'][5:], hp, prev_p-hp, f['hp'], prev_f-f['hp'], f['dist'], e.get('note','')))
    prev_p=hp; prev_f=f['hp']
"
```

The three block phases are the load-bearing ones: 12.0 / 1.8 / 12.0 proves the
guard reduces damage *and* that the frontal arc refuses hits from behind. If
all three read the same, blocking has silently become a no-op or an always-op.

### Enemy AI regression

```bash
DISPLAY=:0 .claude/skills/run-lindisfarne/ai.sh /tmp/lindisfarne-ai
```

Known-good — the whole state machine plus navmesh pathing:

```
01_idle    state=Idle   enemy=( 20.0, -6.0)  out of sight
02_alert   state=Alert  enemy=( 20.0, -6.0)  spotted, 0.5s reaction beat
03_chase   state=Chase  enemy=( 20.0, -1.0)  committed
04_pathing state=Chase  enemy=( 12.7,  5.5)  routing AROUND the church
05_pathing state=Chase  enemy=(  3.2,  2.5)  still routing
06_gave_up state=Idle   enemy=(  1.7,  1.1)  6s without sight, gives up
07_attack  state=Idle   dist=2.0             re-engaged
08_killed  state=Dead   enemy_hp=0.0
09_corpse  state=Dead   enemy_hp=0.0         corpse stays inert
```

Shots 04/05 are the load-bearing ones: the x coordinate must *move* (20 -> 12.7
-> 3.2). If the spearman walks a straight line to the player it is not using
the navmesh at all, which usually means the bake is stale or empty.

### Re-baking the navmesh

Run after ANY change to level collision:

```bash
godot --headless --script tools/bake_navmesh.gd
```

Prints `baked <n> polygons`. 255 for the current island. Zero polygons means
the world is not parented under the `Navigation` node.

### Geometry check without playing

Raycasts every key surface and compares against expected heights — much faster
than eyeballing screenshots when you move level geometry. Note `collision_mask
= 1`, or the ray hits the player's own capsule:

```bash
cat > /tmp/geom.gd <<'EOF'
extends SceneTree
func _init():
    root.add_child(load("res://scenes/main.tscn").instantiate())
    await physics_frame
    await physics_frame
    var space := root.world_3d.direct_space_state
    for p in [["grass", Vector3(0,40,0), 0.0], ["crypt floor", Vector3(7,-2,-14), -4.5],
              ["church roof", Vector3(0,40,-23), 7.8], ["gate gap", Vector3(0,40,14.3), 0.0]]:
        var from: Vector3 = p[1]
        var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0,-60,0))
        q.collision_mask = 1
        var hit := space.intersect_ray(q)
        var y: float = hit.position.y if hit else NAN
        print("%-14s expect %6.2f got %6.2f via %s" % [p[0], p[2], y, hit.collider.name if hit else "-"])
    quit()
EOF
godot --headless --script /tmp/geom.gd
```

### Custom scenario

```bash
DISPLAY=:0 godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots=/tmp/shots --log=/tmp/shots/log.json \
  --do="wait 0.6; shot spawn; mouse 300 0; wait 0.2; shot turned"
```

Driver flags (all after the bare `--`):

| Flag | Meaning |
|---|---|
| `--do="..."` | `;`-separated command program |
| `--shots=DIR` | PNG output dir (default `user://shots`) |
| `--log=PATH` | JSON state log |
| `--scene=res://...` | scene to drive (default `res://scenes/main.tscn`) |
| `--capture-mouse` | grab the real cursor (off by default — a human may be at this display) |

Commands:

| Command | Effect |
|---|---|
| `wait <sec>` | let the game run |
| `shot <name>` | save `<shots>/<name>.png` |
| `press` / `release <action>` | hold/release `move_forward`, `move_back`, `move_left`, `move_right`, `sprint` |
| `tap <action> <sec>` | press, wait, release |
| `tp <x> <y> <z>` | teleport player, zero velocity |
| `tpnear <name> <m>` | stand that far from a named enemy, facing it — use this instead of hardcoded coordinates, which go stale the moment an enemy can walk |
| `yaw <deg>` / `pitch <deg>` | set camera rotation **directly**, bypassing `camera_rig.gd` |
| `mouse <dx> <dy>` | inject motion **through** `camera_rig.gd._unhandled_input` — use this to test mouse-look itself |
| `note <text>` | label the next log entry |

Every command appends a state entry to stdout (`DRIVER <cmd> {json}`) and to
`--log`, so you get telemetry even from commands that take no screenshot.

### Direct inspection without running the game

To check what a `.tscn` actually deserialises to — invaluable for transforms
and exported node references, see Gotchas:

```bash
cat > /tmp/probe.gd <<'EOF'
extends SceneTree
func _init():
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    var ramp: Node3D = scene.get_node("Obstacles/Ramp")
    print("RAMP euler=", ramp.transform.basis.get_euler())
    print("HUD player=", scene.get_node("DebugHud").get("player"))
    quit()
EOF
godot --headless --script /tmp/probe.gd
```

## Run: human path

```bash
./play.sh          # play
./play.sh edit     # open the editor instead
```

Works from any working directory, runs the import step first, and defaults
`DISPLAY` to `:0` when it is unset. Opens the window and captures the mouse:
WASD + Shift, **Esc** releases the cursor.

You cannot script it — prefer the driver above for anything you need to verify.

Tuning knobs are `@export`s on `Player/Motor`. With the game running, use the
editor's **Remote** scene tab to change them live.

## Gotchas

- **`Transform3D(...)` in `.tscn` is ROW-major.** The order is
  `(x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, ox, oy, oz)` — the transpose
  of the basis vectors laid end to end. Writing it column-major silently
  produces the *inverse* rotation: it cost a ramp tilted the wrong way, a
  camera pitched up instead of down, and a sun aimed at the sky. Never
  hand-derive one; round-trip it with the `--script` probe above.
- **Node-typed `@export` needs a `node_paths=` declaration on the node
  header**, or it stays `null` with no error and no warning:
  ```
  [node name="DebugHud" type="CanvasLayer" parent="." node_paths=PackedStringArray("player")]
  player = NodePath("../Player")
  ```
  The path is relative to the *node*, not the scene root.
- **`--headless` cannot screenshot.** The dummy renderer never draws, so
  `RenderingServer.frame_post_draw` never fires. The driver detects
  `DisplayServer.get_name() == "headless"` and skips shots with a warning —
  without that guard it hangs until killed. Headless runs are still useful:
  the state log is fully populated, so physics and movement regressions are
  checkable without a display.
- **Xvfb is not installed here**, so headless *rendering* is unverified. On a
  display-less box, use `--headless` for state-only runs.
- **Godot's importer skips dot-directories**, so this driver gets no `.uid`
  sidecar — but `load("res://.claude/...")` resolves fine, which is why the
  driver can live inside the skill directory. Scripts and scenes need no
  import; only assets do.
- **Godot rewrites `project.godot` on editor open**, including
  `config/features`. Opening a project written for 4.4 in 4.7 silently bumps
  it to `PackedStringArray("4.7", "Forward Plus")`.
- **`.gd.uid` sidecars are generated on import and should be committed** —
  they keep script references stable across renames. `.godot/` should not be.
- **Navigation does not work under `godot --script`.** `map_get_closest_point`
  and `map_get_path` return `Vector3.ZERO` / empty even with a correctly baked
  mesh and an active map, because NavigationServer3D never iterates in that
  context — `map_force_update()` does not save you. Verify pathing by driving
  the real game (`ai.sh`) and watching enemy positions change, never with a
  `--script` probe. Physics raycasts *do* work there, which makes this
  especially easy to trip over.
- **The navmesh bakes from STATIC COLLIDERS, not mesh instances**
  (`geometry_parsed_geometry_type = 1`). The crypt stairs are a smooth ramp for
  physics with nine collision-free step meshes on top; parsing meshes would
  bake nine 0.5m ledges no agent can climb.
- **AI ranges must sit inside the hitbox's real reach.** Hitbox front face is
  2.0m from body centre, target hurtbox radius is 0.45, so contact needs
  <= 2.45m. An `attack_range` above that makes an enemy park just out of reach
  and swing at air forever, which reads exactly like "blocking works".
- **`_ready` propagates children-first.** A child StateMachine's `_ready` runs
  BEFORE its parent's, so every `@onready` on the parent is still null. The
  machine therefore has an explicit `start()` the owner calls from its own
  `_ready`.
- The driver's `yaw`/`pitch` set rotations directly and do **not** go through
  `camera_rig.gd`. A later `mouse` command will fight them, because the rig
  keeps its own pitch accumulator. Use `mouse` when testing camera code.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Could not find type "CharacterMotor" in the current scope`, character frozen | Global class cache missing. Run `godot --headless --import`. |
| Driver hangs forever, no output, needs `timeout` to kill | A `shot` under `--headless` on a build without the headless guard. Drop `--headless` and set `DISPLAY=:0`. |
| `driver: no CharacterBody3D named 'Player' inside ...` | `--scene` points at a scene with no `Player` node. |
| HUD reads `DebugHud: no player assigned` | The `node_paths=` gotcha above. |
| Camera snaps in close for no visible reason | SpringArm3D sphere clipping the ground. Raise the arm pivot or shrink the shape; `arm_length` in the log shows the collapse. |
| Screenshot is a wall of brown capsule | Camera inside the player. `occlusion_distance` on `CameraRig` is too low. |
