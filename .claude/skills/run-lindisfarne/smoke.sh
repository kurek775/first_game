#!/usr/bin/env bash
# Canonical stage-1 traversal: walk, sprint, climb the ramp, cross the
# platform, fall off it, land, then jam the camera into a wall.
#
#   DISPLAY=:0 .claude/skills/run-lindisfarne/smoke.sh [SHOTS_DIR]
#
# Writes PNGs + log.json to SHOTS_DIR (default /tmp/lindisfarne-shots).
# Add --headless to the godot line below for a state-only run (no PNGs).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS="${1:-/tmp/lindisfarne-shots}"

rm -rf "$SHOTS"
mkdir -p "$SHOTS"
cd "$PROJECT_DIR"

# Required before the first run: without it, class_name types don't resolve.
godot --headless --import >/dev/null 2>&1

exec godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots="$SHOTS" \
  --log="$SHOTS/log.json" \
  --do="
    wait 0.6; shot 01_spawn;
    tp 10 0.5 4; yaw 0; wait 0.4;
    note flat ground;    press move_forward; wait 1.2; shot 02_walk_flat;
    note 20-degree ramp; press sprint;       wait 1.4; shot 03_on_ramp;
    note platform top;                       wait 1.3; shot 04_on_platform;
    note off the edge;   release sprint;     wait 0.9; shot 05_falling;
    note back on ground; release move_forward; wait 1.4; shot 06_landed;
    note arm vs wall;    tp -12 1 -4; yaw 180; wait 1.0; shot 07_camera_vs_wall;
    note pitched down;   mouse 0 -400;        wait 0.3; shot 08_look_down
  "
