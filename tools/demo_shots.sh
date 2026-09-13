#!/usr/bin/env bash
# 📸 데모의 위젯 화면을 섹션마다 찍는다. 심링크·임포트는 run.sh 와 같은 방식으로 준비한다.
#   bash addons/gohud/tools/demo_shots.sh /tmp/demo_shots
set -euo pipefail
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="$ADDON/examples/demo"
OUT="${1:-/tmp/gohud_demo_shots}"
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "Godot 을 못 찾았다 — GODOT_BIN" >&2; exit 2; }
[ -f "$DEMO/project.godot" ] || cp "$DEMO/project.godot.demo" "$DEMO/project.godot"
mkdir -p "$DEMO/addons"
[ -e "$DEMO/addons/gohud/plugin.cfg" ] || ln -s ../../.. "$DEMO/addons/gohud"
"$GODOT" --headless --path "$DEMO" --import > /dev/null 2>&1 || true
# 뒤에 오는 인자는 그대로 넘긴다: --play · --only=coach,states · --sizes=desktop
shift $(( $# > 0 ? 1 : 0 ))
"$GODOT" --path "$DEMO" -s res://addons/gohud/tests/demo_shots.gd -- --out="$OUT" "$@"
