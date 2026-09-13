#!/usr/bin/env bash
# Run the standalone demo; import assets and register script classes first.
# bash run.sh                            Interactive Start screen
# bash run.sh --shot /tmp/start.png       Capture the Start screen
# bash run.sh --languages                 Check all built-in languages render (headless)
# bash run.sh --shot-languages /tmp/l.png Capture the language card
# bash run.sh --record /tmp/demo.avi      Record the full tour at 1080p / 60 fps
# bash run.sh -- --auto --cinema --exit   Preview the recording layout
# bash run.sh -- --explore=hud             Open one widget in explore mode (hands-on, no bot)
# GODOT_BIN=/path/to/godot bash run.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
# ZIP 설치본은 project.godot 을 `project.godot.demo` 로 담고 있다 — 설치한 게임 프로젝트에서
# 중첩 project.godot 이 에디터 경고를 내기 때문이다. 데모를 돌리려면 여기서 되살린다.
if [ ! -f "$HERE/project.godot" ] && [ -f "$HERE/project.godot.demo" ]; then
  cp "$HERE/project.godot.demo" "$HERE/project.godot"
fi
mkdir -p "$HERE/addons"
if [ ! -e "$HERE/addons/gohud/plugin.cfg" ]; then
  if [ -L "$HERE/addons/gohud" ]; then
    rm "$HERE/addons/gohud"
  elif [ -e "$HERE/addons/gohud" ]; then
    echo "Cannot set up the demo: addons/gohud exists but is not a valid add-on." >&2
    exit 2
  fi
  ln -s ../../.. "$HERE/addons/gohud"
fi
if [ "${1:-}" = "--setup" ]; then
  echo "Ready. Open this folder in Godot, or run bash run.sh."
  exit 0
fi
[ -n "$GODOT" ] || { echo "Godot was not found. Set GODOT_BIN to its executable." >&2; exit 2; }
IMPORT_LOG="$(mktemp)"
trap 'rm -f "$IMPORT_LOG"' EXIT
if ! "$GODOT" --headless --path "$HERE" --import > "$IMPORT_LOG" 2>&1 || \
    grep -qE 'SCRIPT ERROR:|^ERROR:' "$IMPORT_LOG"; then
  cat "$IMPORT_LOG" >&2
  exit 1
fi

case "${1:-}" in
  --shot)
    SHOT="${2:?Provide a PNG output path}"; shift 2
    SHOT_PATH="$SHOT" "$GODOT" --path "$HERE" --resolution 2560x1600 -s res://shot.gd "$@"
    echo "Screenshot: $SHOT"
    ;;
  --languages)
    shift
    "$GODOT" --headless --path "$HERE" -s res://verify_languages.gd "$@"
    ;;
  --shot-languages)
    SHOT="${2:?Provide a PNG output path}"; shift 2
    SHOT_PATH="$SHOT" "$GODOT" --path "$HERE" --resolution 2560x1600 -s res://shot_languages.gd "$@"
    echo "Screenshot: $SHOT"
    ;;
  --record)
    MOVIE="${2:?Provide an AVI or OGV output path}"; shift 2
    case "$MOVIE" in *.avi|*.ogv) ;; *) echo "Use an .avi or .ogv output path." >&2; exit 2 ;; esac
    mkdir -p "$(dirname "$MOVIE")"
    MOVIE="$(cd "$(dirname "$MOVIE")" && pwd)/$(basename "$MOVIE")"
    "$GODOT" --path "$HERE" --resolution 1920x1080 --fixed-fps "${DEMO_FPS:-60}" \
      --write-movie "$MOVIE" "$@" -- --auto --cinema --exit
    echo "Movie: $MOVIE"
    ;;
  *) "$GODOT" --path "$HERE" "$@" ;;
esac
