#!/bin/bash
# The gohud headless test runner.
#
#   bash addons/gohud/tools/run_tests.sh
#   GOHUD_PROJECT=/path/to/project bash .../run_tests.sh        # name the host project explicitly
#   GOHUD_TEST_SCRIPT=res://somewhere/gohud_test.gd bash ...     # move the test script (for verifying the store ZIP)
#   GODOT_BIN=/path/to/godot bash ...
#
# 🛑 Why not just call godot
#   A **parse error** in a gohud script or a test file never reaches `_initialize`, so there are 0 lines of
#   output, the `await` never returns and the process never ends — it looks like a "hang", not a failure
#   (measured 2026-09-12). So it is cut off by wall clock, and a `SCRIPT ERROR` pointing at a gohud file counts as failure.
#   Piping (`| tail`) traps the output in a buffer and hides the cause, so it is captured to a file.
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
[ -n "$PROJECT" ] || { echo "🛑 could not find project.godot — name it with GOHUD_PROJECT" >&2; exit 2; }
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "🛑 no godot executable — name it with GODOT_BIN" >&2; exit 2; }

# 🛑 Build a relative path only when the addon is **inside** that project — pointing `GOHUD_PROJECT` at
#    another project (an empty verification project, say) fails to strip the prefix, so an absolute path
#    gets glued to `res://` and you get "File not found" (measured 2026-09-12). In that case use the addon path over there.
case "$ADDON" in
  "$PROJECT"/*) REL="${ADDON#"$PROJECT"/}" ;;
  *) REL="addons/gohud" ;;
esac
SCRIPT="${GOHUD_TEST_SCRIPT:-res://$REL/tests/gohud_test.gd}"
LIMIT="${GOHUD_TEST_TIMEOUT:-240}"
LOG="$(mktemp)"

echo "gohud tests — project $PROJECT · $SCRIPT"
"$GODOT" --headless --path "$PROJECT" -s "$SCRIPT" > "$LOG" 2>&1 &
PID=$!
waited=0
while kill -0 "$PID" 2>/dev/null; do
  if [ "$waited" -ge "$LIMIT" ]; then
    kill -9 "$PID" 2>/dev/null
    echo "🛑 did not finish within ${LIMIT}s — this is what a script killed by a parse error looks like" >&2
    grep -A3 "SCRIPT ERROR" "$LOG" | head -30 >&2
    rm -f "$LOG"
    exit 1
  fi
  sleep 1
  waited=$((waited + 1))
done
wait "$PID"
CODE=$?

# 🔑 There is more than one test file (`gohud tests:`, `gohud extra tests:`) — capture **both** summary lines.
grep -E "^  (ok  |\.\.\.\.|FAIL|viewport) |^FAIL |^gohud( [a-z]+)* tests:" "$LOG"
# 🛑 Right after new artwork (SVG) is made, skipping the actual import leaves the whole theme unreadable and the tests die or hang instantly (2026-09-12).
if grep -qE "referenced non-existent resource|Failed loading resource: res://addons/gohud" "$LOG" 2>/dev/null; then
  echo "🛑 a resource could not be read — the new SVGs were not imported. First run:  godot --headless --path \"$PROJECT\" --import" >&2
fi
if grep -A3 "SCRIPT ERROR" "$LOG" | grep -q "addons/gohud\|gohud_test"; then
  echo "🛑 gohud script error:" >&2
  grep -A3 "SCRIPT ERROR" "$LOG" | head -30 >&2
  CODE=1
fi
if ! grep -qE "^gohud( [a-z]+)* tests:" "$LOG"; then
  echo "🛑 no summary line — the tests did not run to the end" >&2
  tail -20 "$LOG" >&2
  CODE=1
fi
rm -f "$LOG"
[ "$CODE" -eq 0 ] && echo "✅ passed (${waited}s)" || echo "🛑 failed (exit code $CODE)"
exit "$CODE"
