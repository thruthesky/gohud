#!/bin/bash
# 🧼 Put **only** gohud into an empty Godot project — then import → test → (optionally) export.
#
# "it works in our game" and "it works in another project" are different verifications. There are
# dependencies that only surface where the host project's autoloads, theme and translations are absent. Always run this before a store submission.
#
#   bash addons/gohud/tools/new_project_check.sh                         # copy the source folder and test that
#   bash addons/gohud/tools/new_project_check.sh --zip .dist/gohud-1.0.0.zip   # test the very ZIP to be submitted
#   bash addons/gohud/tools/new_project_check.sh --with-runtime          # also with the GoRuntime autoload on
#   bash addons/gohud/tools/new_project_check.sh --export                # go as far as a Web export (needs templates)
#   bash addons/gohud/tools/new_project_check.sh --dir /tmp/gohud-clean  # name the working folder (it is kept)
#
# 🛑 The store ZIP in `--zip` mode has no tests/ — the test files are copied **outside** the ZIP
#    (res://gohud_check/) and run from there. Only then does the addon folder hold nothing but the ZIP,
#    which is what makes it a verification of "exactly what was submitted".
set -eu

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
WORK=""
ZIP=""
EXPORT=0
RUNTIME=0
while [ $# -gt 0 ]; do
  case "$1" in
    --zip) shift; ZIP="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")" ;;
    --dir) shift; WORK="$1" ;;
    --export) EXPORT=1 ;;
    --with-runtime) RUNTIME=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "🛑 no godot executable" >&2; exit 2; }
[ -n "$WORK" ] || WORK="$(mktemp -d)/gohud-clean"
rm -rf "$WORK"
mkdir -p "$WORK/addons"

# The window is phone portrait (390x844 logical). No stretch is used, so 1 unit = 1 px and the layout is seen as it is.
cat > "$WORK/project.godot" <<'EOF'
; gohud empty-project verification — nothing here but gohud.
config_version=5

[application]

config/name="gohud clean check"
run/main_scene="res://addons/gohud/examples/gallery/gallery.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")

[display]

window/size/viewport_width=390
window/size/viewport_height=844

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF
if [ "$RUNTIME" -eq 1 ]; then
  printf '\n[autoload]\n\nGoRuntime="*res://addons/gohud/core/go_runtime.gd"\n' >> "$WORK/project.godot"
fi

TEST_SCRIPT="res://addons/gohud/tests/gohud_test.gd"
if [ -n "$ZIP" ]; then
  ( cd "$WORK" && unzip -q "$ZIP" )
  mkdir -p "$WORK/gohud_check"
  cp "$ADDON/tests/gohud_test.gd" "$WORK/gohud_check/"
  cp "$ADDON/tools/skin_dials.json" "$WORK/gohud_check/"
  TEST_SCRIPT="res://gohud_check/gohud_test.gd"
  echo "① ZIP installed — $(basename "$ZIP")"
else
  rsync -a --exclude .dist --exclude '.godot' --exclude 'tests/_*' \
    --exclude '.git*' --exclude '.env*' --exclude '.claude' --exclude '.review' \
    --exclude 'builds' --exclude 'docs' --exclude '/www/' --exclude 'examples/demo' \
    "$ADDON/" "$WORK/addons/gohud/"
  echo "① source copied — $ADDON"
fi
echo "   working folder: $WORK · GoRuntime autoload: $([ "$RUNTIME" -eq 1 ] && echo on || echo off)"

echo "② import (one editor pass)"
"$GODOT" --headless --path "$WORK" --editor --quit > "$WORK/import.log" 2>&1 || true
if grep -A3 "SCRIPT ERROR" "$WORK/import.log" | grep -q "gohud"; then
  echo "🛑 gohud script error during import" >&2
  grep -A3 "SCRIPT ERROR" "$WORK/import.log" | head -30 >&2
  exit 1
fi
DPI="$(grep -l 'type="DPITexture"' "$WORK"/addons/gohud/icons/default/*.svg.import 2>/dev/null | wc -l | tr -d ' ')"
echo "   DPITexture icons imported: $DPI"

echo "③ tests"
GOHUD_PROJECT="$WORK" GOHUD_TEST_SCRIPT="$TEST_SCRIPT" GODOT_BIN="$GODOT" bash "$ADDON/tools/run_tests.sh"

if [ "$EXPORT" -eq 1 ]; then
  VERSION_DIR="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z0-9]+).*/\1/')"
  TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION_DIR"
  [ -d "$TEMPLATES" ] || TEMPLATES="$HOME/.local/share/godot/export_templates/$VERSION_DIR"
  if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
    echo "④ export skipped — no Web templates ($TEMPLATES)"
  else
    echo "④ Web export"
    cat > "$WORK/export_presets.cfg" <<'EOF'
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="gohud_check/*"
export_path="build/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
EOF
    mkdir -p "$WORK/build"
    "$GODOT" --headless --path "$WORK" --export-release "Web" "$WORK/build/index.html" > "$WORK/export.log" 2>&1 || true
    if [ -f "$WORK/build/index.pck" ] && ! grep -q "SCRIPT ERROR" "$WORK/export.log"; then
      echo "   ✅ export succeeded — index.pck $(du -h "$WORK/build/index.pck" | cut -f1 | tr -d ' ')"
    else
      echo "🛑 export failed" >&2
      tail -20 "$WORK/export.log" >&2
      exit 1
    fi
  fi
fi
echo "✅ empty-project verification done — $WORK"
