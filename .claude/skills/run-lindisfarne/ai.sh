#!/usr/bin/env bash
# Enemy AI regression: the full state machine plus navmesh pathing.
#
#   DISPLAY=:0 .claude/skills/run-lindisfarne/ai.sh [SHOTS_DIR]
#
# Covers Idle -> Alert -> Chase -> Attack -> Dead, that Chase paths AROUND the
# church rather than through it, and that give_up_time returns it to Idle.
#
# The repeated `tpnear` before each swing is not laziness: knockback pushes the
# spearman out of reach and staggers cancel the player's swing, so without
# re-anchoring you measure the knockback, not the damage.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS="${1:-/tmp/lindisfarne-ai}"

rm -rf "$SHOTS"
mkdir -p "$SHOTS"
cd "$PROJECT_DIR"
godot --headless --import >/dev/null 2>&1

exec godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots="$SHOTS" \
  --log="$SHOTS/log.json" \
  --do="
    wait 1.0; yaw 0;
    note out of sight;      tp 20 0.5 22;   wait 1.0; shot 01_idle;
    note spotted, reacting; tp 20 0.5 10;   wait 0.35; shot 02_alert;
    note committed;                         wait 1.5; shot 03_chase;
    note break line of sight behind church; tp -20 0.5 -22; wait 2.5; shot 04_pathing;
    note still routing round;               wait 3.0; shot 05_pathing;
    note lost you, gives up;                wait 5.0; shot 06_gave_up;

    note re-engage;         tpnear Spearman 2.0; wait 1.2; shot 07_attack;
    tpnear Spearman 2.0; tap attack 0.05; wait 1.1;
    tpnear Spearman 2.0; tap attack 0.05; wait 1.1;
    tpnear Spearman 2.0; tap attack 0.05; wait 1.1;
    tpnear Spearman 2.0; tap attack 0.05; wait 1.1;
    tpnear Spearman 2.0; tap attack 0.05; wait 1.6; shot 08_killed;
    note corpse must stay inert; tpnear Spearman 2.0; tap attack 0.05; wait 1.8; shot 09_corpse
  "
