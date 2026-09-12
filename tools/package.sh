#!/bin/bash
# gohud 배포 ZIP — Godot Asset Store · GitHub/GitLab Releases 에 올리는 파일을 만든다.
#
#   bash addons/gohud/tools/package.sh              # <애드온>/.dist/gohud-<버전>.zip (스토어용: tests·tools 제외)
#   bash addons/gohud/tools/package.sh --full       # tests·tools 까지 포함(내부 배포용)
#   bash addons/gohud/tools/package.sh --out DIR    # 저장 위치를 바꾼다
#
# ZIP 안의 경로는 언제나 `addons/gohud/...` 다 — 사용자가 프로젝트 루트에 풀면 그대로 설치된다.
# 저장소 루트가 곧 애드온인 경우(서브모듈)와 호스트 프로젝트 안에 있는 경우 모두 같은 결과가 나온다.
#
# 🛑 게이트 — 하나라도 걸리면 ZIP 을 만들지 않는다
#   ① plugin.cfg 의 version 과 GoUi.VERSION 이 같다
#   ② LICENSE · README.md · THIRD_PARTY_NOTICES.md · CHANGELOG.md 가 있다
#   ③ CHANGELOG.md 에 이 버전 항목(`## [x.y.z]`)이 있다
#   ④ 코드·씬·리소스가 애드온 **밖**의 `res://` 를 가리키지 않는다 — 가리키면 남의 프로젝트에서 깨진다
#
# 🛑 `.dist/` 는 점으로 시작해 Godot 가 임포트하지 않는다(에디터가 점 폴더를 건너뛴다).
set -eu

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
FULL=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1 ;;
    --out) shift; OUT="${1:-}" ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "🛑 $*" >&2; exit 1; }

# ① 버전
VERSION="$(sed -n 's/^version="\(.*\)"$/\1/p' "$ADDON/plugin.cfg")"
[ -n "$VERSION" ] || fail "plugin.cfg 에서 version 을 읽지 못했다"
CODE_VERSION="$(sed -n 's/^const VERSION := "\(.*\)"$/\1/p' "$ADDON/core/go_ui.gd")"
[ "$VERSION" = "$CODE_VERSION" ] || fail "버전 불일치 — plugin.cfg=$VERSION · GoUi.VERSION=$CODE_VERSION"

# ② 문서
for doc in LICENSE README.md THIRD_PARTY_NOTICES.md CHANGELOG.md; do
  [ -f "$ADDON/$doc" ] || fail "$doc 가 없다"
done

# ③ 변경 이력
grep -q "^## \[$VERSION\]" "$ADDON/CHANGELOG.md" || fail "CHANGELOG.md 에 [$VERSION] 항목이 없다"

# ④ 애드온 밖 참조 — 주석 줄(`#`)은 사용 예시라 뺀다
# 🛑 `tests/`·`tools/` 는 뺀다 — 검사 파일 자체가 `res://addons/gohud` 를 문자열로 들고 있어
#    오탐이 난다(2026-09-12). 스토어 ZIP 에도 들어가지 않는 폴더다.
# 🛑 `examples/demo/` 도 뺀다 — 자체 project.godot 을 가진 **별도 프로젝트**라
#    그 안의 `res://` 는 애드온이 아니라 데모 루트를 가리킨다.
LEAKS="$(grep -rnE 'res://' "$ADDON" --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.cfg' \
  | grep -vE '/(tests|tools)/|/examples/demo/' \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
  | grep -oE '^[^:]+:[0-9]+:|res://[A-Za-z0-9_./%-]+' \
  | awk 'index($0, "res://") == 1 { if (index($0, "res://addons/gohud") != 1) print prev $0; next } { prev = $0 }' || true)"
[ -z "$LEAKS" ] || { echo "$LEAKS" >&2; fail "애드온 밖을 가리키는 res:// 참조가 있다"; }

DIST="${OUT:-$ADDON/.dist}"
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
ZIP="$DIST/gohud-$VERSION.zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/addons/gohud"

# 🛑 `review/` 는 스토어 제출용 홍보 이미지 보관함이다 — 설치본에 들어갈 이유가 없다(ZIP 이 20배가 된다).
# 🛑 `examples/demo/addons` 는 애드온 루트로 가는 **심볼릭 링크**다 — ZIP 에 넣으면 설치한 곳에서 깨진 링크가 된다.
#    데모의 `run.sh` 가 없으면 다시 만든다.
set -- --exclude=.git --exclude=.godot --exclude=.dist --exclude=.DS_Store --exclude='tests/_*' --exclude='*.tmp' --exclude=review --exclude=examples/demo/addons
if [ "$FULL" -eq 0 ]; then set -- "$@" --exclude=tests --exclude=tools; fi
rsync -a "$@" "$ADDON/" "$STAGE/addons/gohud/"

rm -f "$ZIP"
( cd "$STAGE" && zip -qrX "$ZIP" addons )

BAD="$(unzip -Z1 "$ZIP" | grep -v '^addons/gohud/' | grep -v '^addons/$' || true)"
[ -z "$BAD" ] || fail "ZIP 안에 addons/gohud/ 밖의 항목이 있다: $BAD"

COUNT="$(unzip -Z1 "$ZIP" | grep -vc '/$')"
SIZE="$(du -h "$ZIP" | cut -f1 | tr -d ' ')"
echo "✅ $ZIP"
echo "   버전 $VERSION · 파일 $COUNT 개 · $SIZE · $([ "$FULL" -eq 1 ] && echo '전체(tests·tools 포함)' || echo '스토어용')"
