#!/usr/bin/env bash
# The YouTube reel: every gohud theme, nine widgets each, at 1920×1080.
# bash run.sh                           Watch it in a 1920×1080 window (loops)
# bash run.sh --record /tmp/reel.avi    Record it at 1920×1080 / 60 fps, then quit (.avi or .ogv)
# GODOT_BIN=/path/to/godot bash run.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
mkdir -p "$HERE/addons"
if [ ! -e "$HERE/addons/gohud/plugin.cfg" ]; then
  [ -L "$HERE/addons/gohud" ] && rm "$HERE/addons/gohud"
  [ -e "$HERE/addons/gohud" ] && { echo "addons/gohud exists but is not a valid add-on." >&2; exit 2; }
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
    grep -qE 'SCRIPT ERROR:' "$IMPORT_LOG"; then
  cat "$IMPORT_LOG" >&2
  exit 1
fi

case "${1:-}" in
  --record)
    MOVIE="${2:?Provide an AVI or OGV output path}"; shift 2
    case "$MOVIE" in *.avi|*.ogv) ;; *) echo "Use an .avi or .ogv output path." >&2; exit 2 ;; esac
    mkdir -p "$(dirname "$MOVIE")"
    MOVIE="$(cd "$(dirname "$MOVIE")" && pwd)/$(basename "$MOVIE")"
    "$GODOT" --path "$HERE" --resolution 1920x1080 --fixed-fps "${REEL_FPS:-60}" \
      --write-movie "$MOVIE" "$@" -- --exit
    echo "Movie: $MOVIE"
    ;;
  *) "$GODOT" --path "$HERE" --resolution 1920x1080 "$@" ;;
esac
