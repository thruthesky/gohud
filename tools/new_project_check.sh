#!/bin/bash
# 🧼 빈 Godot 프로젝트에 gohud **만** 넣고 — 임포트 → 검사 → (선택) 내보내기까지 확인한다.
#
# "우리 게임에서 잘 된다" 와 "남의 프로젝트에서 잘 된다" 는 다른 검증이다. 호스트 프로젝트의
# 오토로드·테마·번역이 빠진 곳에서만 드러나는 의존이 있다. 스토어 제출 전 반드시 돌린다.
#
#   bash addons/gohud/tools/new_project_check.sh                         # 소스 폴더를 복사해 검사
#   bash addons/gohud/tools/new_project_check.sh --zip .dist/gohud-1.0.0.zip   # 제출할 ZIP 자체를 검사
#   bash addons/gohud/tools/new_project_check.sh --with-runtime          # GoRuntime 오토로드를 켠 상태로도
#   bash addons/gohud/tools/new_project_check.sh --export                # Web 내보내기까지(템플릿 필요)
#   bash addons/gohud/tools/new_project_check.sh --dir /tmp/gohud-clean  # 작업 폴더 지정(남겨 둔다)
#
# 🛑 `--zip` 모드의 스토어 ZIP 에는 tests/ 가 없다 — 검사 파일은 ZIP **밖**(res://gohud_check/)에
#    따로 복사해 돌린다. 애드온 폴더에는 ZIP 내용만 있어야 "제출한 그대로" 를 검증한 것이 된다.
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
    *) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
  shift
done

GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "🛑 godot 실행 파일이 없다" >&2; exit 2; }
[ -n "$WORK" ] || WORK="$(mktemp -d)/gohud-clean"
rm -rf "$WORK"
mkdir -p "$WORK/addons"

# 창 크기는 폰 세로(390×844 논리). 스트레치를 쓰지 않아 1 unit = 1 px 로 레이아웃을 그대로 본다.
cat > "$WORK/project.godot" <<'EOF'
; gohud 빈 프로젝트 검증 — gohud 외에는 아무것도 없다.
config_version=5

[application]

config/name="gohud clean check"
run/main_scene="res://addons/gohud/examples/gallery/gallery.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

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
  TEST_SCRIPT="res://gohud_check/gohud_test.gd"
  echo "① ZIP 설치 — $(basename "$ZIP")"
else
  rsync -a --exclude .dist --exclude '.godot' --exclude 'tests/_*' "$ADDON/" "$WORK/addons/gohud/"
  echo "① 소스 복사 — $ADDON"
fi
echo "   작업 폴더: $WORK · GoRuntime 오토로드: $([ "$RUNTIME" -eq 1 ] && echo 켬 || echo 끔)"

echo "② 임포트(에디터 한 번)"
"$GODOT" --headless --path "$WORK" --editor --quit > "$WORK/import.log" 2>&1 || true
if grep -A3 "SCRIPT ERROR" "$WORK/import.log" | grep -q "gohud"; then
  echo "🛑 임포트 중 gohud 스크립트 오류" >&2
  grep -A3 "SCRIPT ERROR" "$WORK/import.log" | head -30 >&2
  exit 1
fi
DPI="$(grep -l 'type="DPITexture"' "$WORK"/addons/gohud/icons/default/*.svg.import 2>/dev/null | wc -l | tr -d ' ')"
echo "   DPITexture 아이콘 임포트: $DPI 개"

echo "③ 검사"
GOHUD_PROJECT="$WORK" GOHUD_TEST_SCRIPT="$TEST_SCRIPT" GODOT_BIN="$GODOT" bash "$ADDON/tools/run_tests.sh"

if [ "$EXPORT" -eq 1 ]; then
  VERSION_DIR="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z0-9]+).*/\1/')"
  TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION_DIR"
  [ -d "$TEMPLATES" ] || TEMPLATES="$HOME/.local/share/godot/export_templates/$VERSION_DIR"
  if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
    echo "④ 내보내기 건너뜀 — Web 템플릿이 없다($TEMPLATES)"
  else
    echo "④ Web 내보내기"
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
      echo "   ✅ 내보내기 성공 — index.pck $(du -h "$WORK/build/index.pck" | cut -f1 | tr -d ' ')"
    else
      echo "🛑 내보내기 실패" >&2
      tail -20 "$WORK/export.log" >&2
      exit 1
    fi
  fi
fi
echo "✅ 빈 프로젝트 검증 끝 — $WORK"
