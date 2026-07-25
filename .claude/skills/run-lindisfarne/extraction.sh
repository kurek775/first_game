#!/usr/bin/env bash
# Extraction + run summary regression: the win path and the death path.
#
#   DISPLAY=:0 .claude/skills/run-lindisfarne/extraction.sh [SHOTS_DIR]
#
# `paused=True` in the log is the signal that a run ended: ending pauses the
# tree, which also freezes the clock. Watch `clock` stop advancing.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS="${1:-/tmp/lindisfarne-extraction}"
rm -rf "$SHOTS"; mkdir -p "$SHOTS"
cd "$PROJECT_DIR"
godot --headless --import >/dev/null 2>&1
exec godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots="$SHOTS" --log="$SHOTS/log.json" \
  --do="
    wait 0.8; yaw 0;
    note take the reliquary; tp 0 1.9 -30.5; wait 0.6; tap interact 0.06; wait 0.6;
    note and the hoard;      tp 7 -3.7 -14.5; wait 0.8; tap interact 0.06; wait 0.6; shot 01_laden;
    note onto the deck;      tp 0 3.2 38; wait 1.5; shot 02_extracted;
    note summary shown;      wait 1.0; shot 03_summary
  "
