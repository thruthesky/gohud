#!/bin/bash
# gohud 배포 ZIP — Godot Asset Store(store.godotengine.org)에 올리는 파일을 만든다.
#
#   bash addons/gohud/tools/package.sh                           # patch +1 → builds/<버전>/gohud-<버전>.zip
#   bash addons/gohud/tools/package.sh --increase-minor-version  # minor +1, patch = 0
#   bash addons/gohud/tools/package.sh --out DIR                 # 저장 위치를 바꾼다 (버전도 올라간다)
# Python 3 필요. 성공한 경우에만 plugin.cfg · GoUi.VERSION · CHANGELOG.md 를 함께 갱신한다.
#
# ZIP 안의 경로는 언제나 `addons/gohud/...` 다 — 받는 사람은 **프로젝트 루트**에 풀면 그대로 설치된다.
#
# 🛑 최상위를 `addons/` 로 두는 것은 취향이 아니라 요구사항이다.
#    Godot 의 에셋 설치기는 ZIP 의 공통 최상위 폴더를 벗겨내는데, `addons/` 만 예외로 남긴다:
#        skip_toplevel = p_autoskip_toplevel && toplevel_prefix != "addons/";
#        (godot/editor/asset_library/editor_asset_installer.cpp)
#    그래서 최상위를 `gohud/` 로 만들면 에디터가 그걸 벗겨
#    core/·widgets/·icons/ 가 남의 프로젝트 루트에 흩어진다.
#
# 🛑 게이트 — 하나라도 걸리면 ZIP 을 만들지 않는다
#   ① plugin.cfg 의 version 과 GoUi.VERSION 이 같다
#   ② LICENSE · README.md · THIRD_PARTY_NOTICES.md · CHANGELOG.md 가 있다
#   ③ 새 버전 항목을 만들고 Unreleased 내역을 옮긴다 — 이미 있는 버전이면 중단한다
#   ④ 코드·씬·리소스가 애드온 **밖**의 `res://` 를 가리키지 않는다 — 가리키면 남의 프로젝트에서 깨진다
#   ⑤ ZIP 안에 비밀(.env·API 키)이 없다
#   ⑥ ZIP 안의 모든 항목이 `addons/gohud/` 아래에 있다
#   ⑦ ZIP 에 심볼릭 링크가 없다 — 설치한 곳에서 깨진 링크가 된다
#   ⑧ 스토어 필수 파일(LICENSE · plugin.cfg)이 ZIP 안에 있다
#   ⑨ 씬·리소스가 가리키는 res:// 가 ZIP 안에 실제로 있다 — 없으면 설치한 곳에서 씬이 열리지 않는다
#   ⑩ ZIP 안에 project.godot 이 없다 — 있으면 설치한 사람의 에디터가 경고를 낸다
set -eu

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
FULL=0
OUT=""
INCREASE="patch"
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1 ;;                       # tools/ 까지 넣는다(내부 배포용 — 스토어에는 쓰지 않는다)
    --increase-minor-version) INCREASE="minor" ;;
    --out)
      [ $# -ge 2 ] && [ -n "$2" ] && [[ "$2" != --* ]] || { echo "--out 에 저장 폴더가 필요하다" >&2; exit 2; }
      shift; OUT="$1" ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "🛑 $*" >&2; exit 1; }

# 직렬화: 같은 체크아웃에서 동시에 실행해 같은 다음 버전을 만들지 않는다.
mkdir -p "$ADDON/builds"
LOCK="$ADDON/builds/.package-lock"
mkdir "$LOCK" 2>/dev/null || fail "다른 패키징이 진행 중이다 ($LOCK)"
STAGE=""
cleanup() {
  [ -z "$STAGE" ] || rm -rf "$STAGE"
  rmdir "$LOCK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ── ① 버전 ──────────────────────────────────────────────────────────────
VERSION="$(sed -n 's/^version="\(.*\)"$/\1/p' "$ADDON/plugin.cfg")"
[ -n "$VERSION" ] || fail "plugin.cfg 에서 version 을 읽지 못했다"
CODE_VERSION="$(sed -n 's/^const VERSION := "\(.*\)"$/\1/p' "$ADDON/core/go_ui.gd")"
[ "$VERSION" = "$CODE_VERSION" ] || fail "버전 불일치 — plugin.cfg=$VERSION · GoUi.VERSION=$CODE_VERSION"

# ── ② 문서 ──────────────────────────────────────────────────────────────
for doc in LICENSE README.md THIRD_PARTY_NOTICES.md CHANGELOG.md; do
  [ -f "$ADDON/$doc" ] || fail "$doc 가 없다"
done

# ── ④ 애드온 밖 참조 ────────────────────────────────────────────────────
# 주석 줄(`#`)은 사용 예시라 뺀다. `tests/`·`tools/` 는 검사 파일 자체가
# `res://addons/gohud` 를 문자열로 들고 있어 오탐이 난다 — 배포본에도 없는 폴더다.
# `examples/demo/` 는 자체 project.godot 을 가진 별도 프로젝트라 그 안의 `res://` 는 데모 루트를 가리킨다.
# `examples/usage/` 는 애드온 사본을 설치해 사용하는 프로젝트이며 배포본에서 제외한다.
# `skills/` 는 AI 에이전트 스킬(Claude Code 플러그인)이다 — 템플릿이 호스트 프로젝트의 `res://ui/…` 를 예로 든다. 배포본에도 없다.
LEAKS="$(grep -rnE 'res://' "$ADDON" --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.cfg' \
  | grep -vE '/(tests|tools|skills)/|/examples/(demo|usage)/' \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
  | grep -oE '^[^:]+:[0-9]+:|res://[A-Za-z0-9_./%-]+' \
  | awk 'index($0, "res://") == 1 { if (index($0, "res://addons/gohud") != 1) print prev $0; next } { prev = $0 }' || true)"
[ -z "$LEAKS" ] || { echo "$LEAKS" >&2; fail "애드온 밖을 가리키는 res:// 참조가 있다"; }

# ── 스테이징 ────────────────────────────────────────────────────────────
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/addons/gohud"

# 🛑 `builds/` 는 점 폴더가 아니라 Godot 가 임포트한다 — `.gdignore` 로 스캔을 막는다.
[ -f "$ADDON/builds/.gdignore" ] || {
  mkdir -p "$ADDON/builds"
  printf '# 배포 ZIP 보관함이다 — Godot 가 스캔할 것이 없다.\n' > "$ADDON/builds/.gdignore"
}

# 제외 목록 — 설치본에 들어갈 이유가 없는 것들.
#   🛑 `.env`     스토어 API 키가 든다. 무슨 일이 있어도 나가면 안 된다.
#   🛑 `.git*`    .git · .gitignore · .gitattributes · .github — 저장소 살림이다.
#                 (`.gdignore` 는 `.gd` 로 시작해 이 패턴에 걸리지 않는다 — 설치 후 동작에 필요하므로 남긴다.)
#   🛑 `.claude`  에이전트 작업 설정.
#   🛑 `.review`  스토어 제출용 홍보 이미지 보관함. 넣으면 ZIP 이 20배가 된다.
#   🛑 `www`      GitHub Pages 사이트(836KB). 애드온을 쓰는 데 필요 없다.
#   🛑 `docs`     사이트 편집·배포 안내와 작업 기록. 애드온을 쓰는 데 필요 없다.
#   🛑 `tests`    검사 전용. 쓰는 사람에게 필요 없다.
#   🛑 `.godot`   임포트 캐시. 남의 프로젝트에서 유효하지 않다.
#   🛑 `examples/demo/addons` 는 애드온 루트로 가는 **심볼릭 링크**다 — 설치한 곳에서 깨진 링크가 된다.
set -- \
  --exclude='.env' \
  --exclude='.git*' \
  --exclude='.claude' \
  --exclude='/.claude-plugin/' \
  --exclude='/skills/' \
  --exclude='.review' \
  --exclude='.playwright-mcp' \
  --exclude='docs' \
  --exclude='/www/' \
  --exclude='review' \
  --exclude='.godot' \
  --exclude='.dist' \
  --exclude='builds' \
  --exclude='.DS_Store' \
  --exclude='tests' \
  --exclude='tests/_*' \
  --exclude='*.tmp' \
  --exclude='*.zip' \
  --exclude='*.py[co]' \
  --exclude='__pycache__' \
  --exclude='/examples/usage/' \
  --exclude='examples/demo/addons'
# 🛑 `docs/` 는 **홈페이지**다 — GitHub Pages 로 배포되는 것이지 애셋에 딸려 갈 것이 아니다.
#    넣으면 ① 스크린샷 수백 KB 가 애셋 크기에 얹히고 ② 그 안의 명령 예시(`res://…/tests/…`)가
#    스토어 ZIP 에 없는 `tests/` 를 가리켜 **깨진 참조 게이트에 걸린다**(2026-09-13 실측).
if [ "$FULL" -eq 0 ]; then set -- "$@" --exclude='tools' --exclude='docs'; fi

rsync -a --no-links "$@" "$ADDON/" "$STAGE/addons/gohud/"

# 버전과 변경 이력은 사본에서 준비한다. 원본은 모든 ZIP 검사가 끝나야 갱신한다.
PREVIOUS_VERSION="$VERSION"
VERSION="$(python3 "$ADDON/tools/package_version.py" prepare "$STAGE" "$INCREASE")"
DIST="${OUT:-$ADDON/builds/$VERSION}"
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
DESTINATION="$DIST/gohud-$VERSION.zip"
[ ! -e "$DESTINATION" ] || fail "같은 버전의 ZIP 이 이미 있다: $DESTINATION"
ZIP="$STAGE/package.zip"

# 🛑 중첩 project.godot 은 설치한 사람의 에디터에 경고를 띄운다:
#      WARNING: Detected another project.godot at res://addons/gohud/examples/demo
#    데모를 별도 프로젝트로 여는 데 꼭 필요한 파일이라 빼지는 않고, 이름만 바꿔 재워 둔다.
#    `bash examples/demo/run.sh` 가 되살린다.
DEMO="$STAGE/addons/gohud/examples/demo"
[ ! -f "$DEMO/project.godot" ] || mv "$DEMO/project.godot" "$DEMO/project.godot.demo"

# ── ⑨ 깨진 참조 ─────────────────────────────────────────────────────────
# 🛑 파일을 옮기고 씬의 참조를 안 고치면, 설치한 사람에게 이렇게 보인다:
#      Error loading: gallery.tscn — Load failed due to missing dependencies
#    게이트 ④ 는 애드온 **밖**을 가리키는 참조만 본다. 여기서는 애드온 **안**인데
#    ZIP 에 실제로 없는 파일을 가리키는 경우를 잡는다.
BROKEN="$(grep -rhoE 'res://addons/gohud/[A-Za-z0-9_./%-]+' "$STAGE" 2>/dev/null | sort -u \
  | while read -r ref; do [ -e "$STAGE/addons/gohud/${ref#res://addons/gohud/}" ] || echo "  $ref"; done)"
[ -z "$BROKEN" ] || { echo "$BROKEN" >&2; fail "ZIP 안에 없는 파일을 가리키는 res:// 참조가 있다"; }

# ── ⑤ 비밀 ──────────────────────────────────────────────────────────────
SECRETS="$(find "$STAGE" \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.p8' \) -print || true)"
[ -z "$SECRETS" ] || { echo "$SECRETS" >&2; fail "비밀 파일이 스테이징에 들어갔다"; }
KEYS="$(grep -rlE 'GD_STORE_|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----' "$STAGE" || true)"
[ -z "$KEYS" ] || { echo "$KEYS" >&2; fail "API 키·비밀키로 보이는 문자열이 들어갔다"; }

# ── ⑦ 심볼릭 링크 ───────────────────────────────────────────────────────
LINKS="$(find "$STAGE" -type l -print || true)"
[ -z "$LINKS" ] || { echo "$LINKS" >&2; fail "심볼릭 링크가 들어갔다"; }

# ── 압축 ────────────────────────────────────────────────────────────────
( cd "$STAGE" && zip -qrX "$ZIP" addons )

# ── ⑥ 경로 ──────────────────────────────────────────────────────────────
BAD="$(unzip -Z1 "$ZIP" | grep -v '^addons/gohud/' | grep -v '^addons/$' || true)"
[ -z "$BAD" ] || fail "ZIP 안에 addons/gohud/ 밖의 항목이 있다: $BAD"

# ── ⑩ 중첩 프로젝트 ─────────────────────────────────────────────────────
NESTED="$(unzip -Z1 "$ZIP" | grep -E '/project\.godot$' || true)"
[ -z "$NESTED" ] || { echo "$NESTED" >&2; fail "ZIP 안에 project.godot 이 있다 — 설치한 에디터가 경고를 낸다"; }

# ── ⑧ 스토어 필수 파일 ──────────────────────────────────────────────────
# 스토어 업로드 폼: "Assets must be uploaded as .zip and must contain a license file."
for need in addons/gohud/LICENSE addons/gohud/plugin.cfg addons/gohud/README.md; do
  unzip -Z1 "$ZIP" | grep -qx "$need" || fail "ZIP 에 $need 가 없다"
done

COUNT="$(unzip -Z1 "$ZIP" | grep -vc '/$')"
SIZE="$(du -h "$ZIP" | cut -f1 | tr -d ' ')"
python3 "$ADDON/tools/package_version.py" publish "$ADDON" "$STAGE" "$DESTINATION"
echo "✅ $DESTINATION"
echo "   버전 자동 갱신: $PREVIOUS_VERSION → $VERSION"
echo "   버전 $VERSION · 파일 $COUNT 개 · $SIZE · $([ "$FULL" -eq 1 ] && echo '전체(tools 포함)' || echo '스토어용')"
