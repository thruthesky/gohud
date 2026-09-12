#!/usr/bin/env bash
# gohud 데모 실행.
#
#   bash run.sh                 # 창으로 실행  (= cd 여기 && godot)
#   bash run.sh --shot out.png  # 화면을 파일로 저장하고 끝낸다
#   bash run.sh --setup         # 애드온 링크만 만들고 끝낸다(에디터로 열기 전에 한 번)
#   GODOT_BIN=/path/to/godot bash run.sh
#
# 이 폴더는 애드온 **안**에 있는 별도 Godot 프로젝트다. Godot 은 res:// 밖을 못 보므로 `addons/gohud` 가
# 여기에도 있어야 하는데, 복사하면 원본과 어긋나고 그냥 두면 자기 자신을 품는 순환이 된다. 그래서
#   · `addons/gohud` 는 애드온 루트로 가는 **심볼릭 링크**(`../../..`)이고
#   · 링크를 타고 다시 들어오는 `addons/gohud/examples/demo/` 는 `.gdignore` 가 막는다
#     (루트의 `.gdignore` 는 자기 자신을 막지 않는다 — 2026-09-12 실측).
# 저장소를 clone 했으면 링크가 이미 있다. 스토어 ZIP 으로 받았으면(링크를 넣지 않는다) 이 스크립트가 만든다.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-$(command -v godot || true)}"

ensure_link() {
	mkdir -p "$HERE/addons"
	if [ ! -e "$HERE/addons/gohud/plugin.cfg" ]; then
		rm -rf "$HERE/addons/gohud"
		ln -s ../../.. "$HERE/addons/gohud"
		echo "🔗 addons/gohud → ../../.. (애드온 루트)"
	fi
}
ensure_link
[ "${1:-}" = "--setup" ] && { echo "준비 끝 — 이제 이 폴더를 Godot 에디터로 열거나 \`godot\` 을 치면 된다"; exit 0; }
[ -n "$GODOT" ] || { echo "🛑 godot 실행 파일이 없다 — GODOT_BIN 으로 지정한다" >&2; exit 2; }

# 🛑 새 그림(SVG)은 `.import` 파일만으로는 못 읽는다 — 실제 임포트를 한 번 돌린다(첫 실행·테마 재생성 뒤). 조용하고 빠르다.
"$GODOT" --headless --path "$HERE" --import > /dev/null 2>&1 || true

if [ "${1:-}" = "--shot" ]; then
	SHOT="${2:?저장 경로가 필요하다}"; shift 2
	SHOT_PATH="$SHOT" "$GODOT" --path "$HERE" --resolution 1680x1400 -s res://shot.gd "$@"
	echo "📷 $SHOT"
else
	"$GODOT" --path "$HERE" "$@"
fi
