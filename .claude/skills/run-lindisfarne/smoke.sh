#!/usr/bin/env bash
# Canonical raid traversal: land on the beach, sprint through the gate, into
# the church nave, down the crypt stairs, then into the side building.
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
    wait 0.6; shot 01_beach_spawn;
    tp 0 0.5 26; yaw 0; wait 0.4;
    note through the gate;  press move_forward; press sprint; wait 1.8; shot 02_gate;
    note crossing court;                                      wait 1.7; shot 03_courtyard;
    note church doorway;    release sprint;                   wait 1.6; shot 04_church_door;
    note inside the nave;                                     wait 1.4; shot 05_nave;
    release move_forward;
    note stairwell mouth;   tp 9 0.5 9; yaw 0; wait 0.6;                shot 06_stair_top;
    note on the stairs;     press move_forward;               wait 1.6; shot 07_on_stairs;
    note underground;                                         wait 1.5; shot 08_crypt;
    release move_forward;
    note side building;     tp 12 0.5 -22; yaw -90; wait 0.6;           shot 09_side_door;
    note inside side bldg;  press move_forward;               wait 1.5; shot 10_side_inside;
    release move_forward
  "
