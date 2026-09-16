#!/usr/bin/env bash
# 📸 Photograph the demo's widget screens section by section. The symlink and import are prepared the same way as in run.sh.
#   bash addons/gohud/tools/demo_shots.sh /tmp/demo_shots
set -euo pipefail
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="$ADDON/examples/demo"
OUT="${1:-/tmp/gohud_demo_shots}"
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "could not find Godot — GODOT_BIN" >&2; exit 2; }
[ -f "$DEMO/project.godot" ] || cp "$DEMO/project.godot.demo" "$DEMO/project.godot"
mkdir -p "$DEMO/addons"
[ -e "$DEMO/addons/gohud/plugin.cfg" ] || ln -s ../../.. "$DEMO/addons/gohud"
"$GODOT" --headless --path "$DEMO" --import > /dev/null 2>&1 || true
# Trailing arguments are passed straight through: --play · --only=coach,states · --sizes=desktop
shift $(( $# > 0 ? 1 : 0 ))
"$GODOT" --path "$DEMO" -s res://addons/gohud/tests/demo_shots.gd -- --out="$OUT" "$@"
