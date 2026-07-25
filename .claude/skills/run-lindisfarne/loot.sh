#!/usr/bin/env bash
# Loot regression: weight, speed penalty, and the two-hand attack gate.
#
#   DISPLAY=:0 .claude/skills/run-lindisfarne/loot.sh [SHOTS_DIR]
#
# The attack-gate shots fire 0.12s after pressing, ON PURPOSE. A whole swing is
# 0.65s, so sampling later reads "idle" whether the swing was blocked or simply
# finished, and the test proves nothing.
#
# Expected: light -> windup, heavy -> idle, after dropping -> windup.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS="${1:-/tmp/lindisfarne-loot}"
rm -rf "$SHOTS"; mkdir -p "$SHOTS"
cd "$PROJECT_DIR"
godot --headless --import >/dev/null 2>&1
exec godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots="$SHOTS" --log="$SHOTS/log.json" \
  --do="
    wait 0.8; yaw 0;
    note empty;              tp -4 0.5 -16.5; wait 0.6; shot 01_empty;
    note candlestick 6kg;    tap interact 0.06; wait 0.6; shot 02_light;
    note light: swing works; press attack; wait 0.12; shot 03_swing_ok; release attack; wait 0.9;
    note reliquary +34kg;    tp 0 1.9 -30.5; wait 0.6; tap interact 0.06; wait 0.6; shot 04_heavy;
    note heavy: swing gated; press attack; wait 0.12; shot 05_gated; release attack; wait 0.7;
    note laden movement;     press move_back; wait 1.2; shot 06_laden; release move_back;
    note drop one;           tap drop 0.06; wait 0.6;
    press attack; wait 0.12; shot 07_swing_restored; release attack
  "
