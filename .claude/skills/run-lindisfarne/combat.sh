#!/usr/bin/env bash
# Combat regression: melee damage, knockback, blocking, and the frontal block
# arc. Every phase teleports the player back into reach first, because
# knockback pushes you out of range and the dummy cannot chase (that is
# stage 4's job).
#
#   DISPLAY=:0 .claude/skills/run-lindisfarne/combat.sh [SHOTS_DIR]
#
# Expected, against DummyPassive (120hp) and DummyAggressive (12 dmg/swing):
#   swings   25.0 damage each, dummy pushed ~2.45m per hit
#   phase A  12.0 taken  (no guard)
#   phase B   1.8 taken  (guard up, frontal -- 15% chip)
#   phase C  12.0 taken  (guard up but facing away -- arc refuses it)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS="${1:-/tmp/lindisfarne-combat}"

rm -rf "$SHOTS"
mkdir -p "$SHOTS"
cd "$PROJECT_DIR"
godot --headless --import >/dev/null 2>&1

exec godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots="$SHOTS" \
  --log="$SHOTS/log.json" \
  --do="
    wait 0.6; yaw 0;
    note reach the passive dummy; tp -11 0.5 38; wait 0.5; shot 01_before;
    note swing 1;  tap attack 0.05; wait 0.9; shot 02_swing1;
    note close in; press move_forward; wait 0.7; release move_forward; wait 0.2;
    note swing 2;  tap attack 0.05; wait 0.9; shot 03_swing2;
    note close in; press move_forward; wait 0.7; release move_forward; wait 0.2;
    note swing 3;  tap attack 0.05; wait 0.9; shot 04_swing3;

    note A unguarded;          tp -3 0.5 36.0; wait 4.0; shot 05_unguarded;
    note B guard frontal;      press block; tp -3 0.5 36.0; wait 4.0; shot 06_blocked;
    note C guard facing away;  yaw 180; tp -3 0.5 36.0; wait 4.0; shot 07_back_turned;
    release block
  "
