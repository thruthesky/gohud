#!/bin/bash
# gohud 헤드리스 검사 실행기.
#
#   bash addons/gohud/tools/run_tests.sh
#   GOHUD_PROJECT=/path/to/project bash .../run_tests.sh        # 호스트 프로젝트를 직접 지정
#   GOHUD_TEST_SCRIPT=res://somewhere/gohud_test.gd bash ...     # 검사 스크립트 위치를 바꾼다(스토어 ZIP 검증용)
#   GODOT_BIN=/path/to/godot bash ...
#
# 🛑 왜 godot 을 그냥 부르지 않나
#   gohud 스크립트나 검사 파일에 **파싱 오류**가 나면 `_initialize` 에 닿지 못해 출력이 0줄이고,
#   `await` 가 영영 돌아오지 않아 프로세스가 끝나지 않는다 — 실패가 아니라 "멈춤" 으로 보인다
#   (2026-09-12 실측). 그래서 벽시계로 끊고, `SCRIPT ERROR` 가 gohud 파일을 가리키면 실패로 센다.
#   파이프(`| tail`)로 받으면 출력이 버퍼에 갇혀 원인도 안 보이므로 파일로 받는다.
set -u

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${GOHUD_PROJECT:-}"
if [ -z "$PROJECT" ]; then
  dir="$ADDON"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/project.godot" ]; then PROJECT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi
[ -n "$PROJECT" ] || { echo "🛑 project.godot 을 찾지 못했다 — GOHUD_PROJECT 로 지정한다" >&2; exit 2; }
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "🛑 godot 실행 파일이 없다 — GODOT_BIN 으로 지정한다" >&2; exit 2; }

# 🛑 애드온이 그 프로젝트 **안**에 있을 때만 상대 경로를 만든다 — `GOHUD_PROJECT` 로 다른
#    프로젝트(빈 검증 프로젝트 등)를 가리키면 접두사 제거가 실패해 절대 경로가 `res://` 에
#    붙어 "File not found" 가 난다(2026-09-12 실측). 그때는 그쪽의 애드온 경로를 쓴다.
case "$ADDON" in
  "$PROJECT"/*) REL="${ADDON#"$PROJECT"/}" ;;
  *) REL="addons/gohud" ;;
esac
SCRIPT="${GOHUD_TEST_SCRIPT:-res://$REL/tests/gohud_test.gd}"
LIMIT="${GOHUD_TEST_TIMEOUT:-240}"
LOG="$(mktemp)"

echo "gohud 검사 — 프로젝트 $PROJECT · $SCRIPT"
"$GODOT" --headless --path "$PROJECT" -s "$SCRIPT" > "$LOG" 2>&1 &
PID=$!
waited=0
while kill -0 "$PID" 2>/dev/null; do
  if [ "$waited" -ge "$LIMIT" ]; then
    kill -9 "$PID" 2>/dev/null
    echo "🛑 ${LIMIT}초 안에 끝나지 않았다 — 파싱 오류로 스크립트가 죽으면 이렇게 보인다" >&2
    grep -A3 "SCRIPT ERROR" "$LOG" | head -30 >&2
    rm -f "$LOG"
    exit 1
  fi
  sleep 1
  waited=$((waited + 1))
done
wait "$PID"
CODE=$?

grep -E "^  (ok  |FAIL|viewport) |^FAIL |^gohud tests:" "$LOG"
if grep -A3 "SCRIPT ERROR" "$LOG" | grep -q "addons/gohud\|gohud_test"; then
  echo "🛑 gohud 스크립트 오류:" >&2
  grep -A3 "SCRIPT ERROR" "$LOG" | head -30 >&2
  CODE=1
fi
if ! grep -q "^gohud tests:" "$LOG"; then
  echo "🛑 요약 줄이 없다 — 검사가 끝까지 돌지 않았다" >&2
  tail -20 "$LOG" >&2
  CODE=1
fi
rm -f "$LOG"
[ "$CODE" -eq 0 ] && echo "✅ 통과 (${waited}초)" || echo "🛑 실패 (종료 코드 $CODE)"
exit "$CODE"
