#!/usr/bin/env bash
# Launch Lindisfarne. Run from anywhere:
#
#   ./play.sh              play the game
#   ./play.sh edit         open the Godot editor instead
#   ./play.sh -- <args>    pass extra args straight to godot
#
# WASD move, Shift sprint, Esc releases the mouse.
set -euo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

if ! command -v godot >/dev/null 2>&1; then
  echo "play.sh: 'godot' is not on PATH." >&2
  echo "         Install Godot 4 and make sure the binary is called 'godot'," >&2
  echo "         or symlink it: ln -s /path/to/Godot_v4.x ~/.local/bin/godot" >&2
  exit 1
fi

# A headless shell (ssh, cron) has no display, and Godot's error for that is
# not obvious. Default to :0 and say what we assumed.
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  export DISPLAY=:0
  echo "play.sh: no DISPLAY set, assuming :0"
fi

# Godot builds its global class cache during import. Without it, every
# 'class_name' type fails to resolve ("Could not find type PlayerMotor in the
# current scope") and the player scripts silently don't load. Cheap to redo, so
# just always do it -- it is a no-op once nothing has changed.
godot --headless --import >/dev/null 2>&1 || true

case "${1:-play}" in
  edit)  shift || true; exec godot -e "$@" ;;
  --)    shift;         exec godot "$@" ;;
  play)  shift || true; exec godot "$@" ;;
  *)                    exec godot "$@" ;;
esac
