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
`Could not find type "PlayerMotor" in the current scope`, the player scripts
fail to load, and the game runs with a frozen character — see Troubleshooting.

## Run: agent path

### Canned traversal (start here)

Walks flat ground, sprints up the ramp, crosses the platform, falls off it,
lands, then jams the camera into a wall:

```bash
DISPLAY=:0 .claude/skills/run-lindisfarne/smoke.sh /tmp/lindisfarne-shots
```

Writes `01_spawn.png` … `08_look_down.png` plus `log.json`. Read the PNGs.
Known-good signature for the current greybox:

```
shot 01_spawn          y=-0.01  ground=True  speed=0.0   arm=5.0   vis=True
shot 02_walk_flat      y=0.0    ground=True  speed=4.5   arm=5.0   vis=True
shot 03_on_ramp        y=2.7    ground=True  speed=7.5   arm=5.0   vis=True
shot 04_on_platform    y=3.43   ground=True  speed=7.5   arm=5.0   vis=True
shot 05_falling        y=2.09   ground=False speed=4.5   arm=5.0   vis=True
shot 06_landed         y=0.0    ground=True  speed=0.0   arm=2.21  vis=True
shot 07_camera_vs_wall y=0.0    ground=True  speed=0.0   arm=1.46  vis=False
shot 08_look_down      y=0.0    ground=True  speed=0.0   arm=1.66  vis=False
```

Re-extract that table from any run:

```bash
python3 -c "
import json
d=json.load(open('/tmp/lindisfarne-shots/log.json'))
for e in d:
    if e['cmd'].startswith('shot'):
        print('%-22s y=%-6s ground=%-5s speed=%-5s arm=%-5s vis=%s' % (
            e['cmd'], e['pos'][1], e['grounded'], e['speed'], e['arm_length'], e['visual_visible']))
"
```

What the columns catch: `speed` pins walk/sprint tuning (4.5 / 7.5),
`y` pins ramp and platform heights, `ground=False` proves the fall actually
happened, `arm` proves the SpringArm3D collided, `vis=False` proves the
occlusion-hide fired.

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
DISPLAY=:0 godot
```

Opens the window, captures the mouse, WASD + Shift, **Esc** releases the
cursor. Useless without a display, and you cannot script it — prefer the
driver.

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
- The driver's `yaw`/`pitch` set rotations directly and do **not** go through
  `camera_rig.gd`. A later `mouse` command will fight them, because the rig
  keeps its own pitch accumulator. Use `mouse` when testing camera code.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Could not find type "PlayerMotor" in the current scope`, character frozen | Global class cache missing. Run `godot --headless --import`. |
| Driver hangs forever, no output, needs `timeout` to kill | A `shot` under `--headless` on a build without the headless guard. Drop `--headless` and set `DISPLAY=:0`. |
| `driver: no CharacterBody3D named 'Player' inside ...` | `--scene` points at a scene with no `Player` node. |
| HUD reads `DebugHud: no player assigned` | The `node_paths=` gotcha above. |
| Camera snaps in close for no visible reason | SpringArm3D sphere clipping the ground. Raise the arm pivot or shrink the shape; `arm_length` in the log shows the collapse. |
| Screenshot is a wall of brown capsule | Camera inside the player. `occlusion_distance` on `CameraRig` is too low. |
