#!/usr/bin/env bash
# Muster regression: alarm, escalating waves, and the rider's clock penalty.
#
#   DISPLAY=:0 .claude/skills/run-lindisfarne/muster.sh [SHOTS_DIR]
#
# Compresses the shipping schedule (14s + 34s + 28s...) down to seconds via the
# driver's `set` command, so wave 7 is reachable inside a test rather than three
# minutes in. It does NOT change what ships.
#
# Expected: waves climb 1..7, levy_alive climbs to the max_alive cap of 14, and
# when the rider gets out the clock loses 90s ON TOP of elapsed time.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS="${1:-/tmp/lindisfarne-muster}"
rm -rf "$SHOTS"; mkdir -p "$SHOTS"
cd "$PROJECT_DIR"
godot --headless --import >/dev/null 2>&1
exec godot .claude/skills/run-lindisfarne/driver.tscn \
  --resolution 1280x720 --position 40,40 -- \
  --shots="$SHOTS" --log="$SHOTS/log.json" \
  --do="
    wait 0.8; yaw 0; tp -30 0.5 20;
    set MusterDirector first_wave_delay 2.0;
    set MusterDirector wave_interval 6.0;
    set MusterDirector min_interval 4.0;
    note before the bell;  wait 1.0; shot 01_quiet;
    note bell rung;        alarm; wait 3.5; shot 02_wave1;
    note escalating;       wait 6.5; shot 03_wave2;
    note escalating;       wait 6.5; shot 04_wave3;
    note cap holds;        wait 8.0; shot 05_capped;
    note rider gets away;  wait 6.0; shot 06_rider_away
  "
