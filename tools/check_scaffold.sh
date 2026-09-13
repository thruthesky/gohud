#!/bin/bash
# 🎨 **테마를 파일 하나로 더할 수 있는가** — 스캐폴딩 → 생성 → 대비 검사 → 되돌리기를 한 번에.
#
#   bash addons/gohud/tools/check_scaffold.sh
#
# 왜 필요한가
#   "테마를 더 들일 예정" 이라는 요청(2026-09-13)에 대한 약속이 이것이다: `new_theme.py` 한 줄이면
#   팔레트 JSON 과 프리셋이 생기고, `make_theme.py` 가 나머지를 만들며, 그 결과가 **가독성 검사를
#   그대로 통과**한다. 넷 중 하나라도 깨지면 새 테마를 넣는 사람이 첫걸음에서 막힌다.
#
# 🛑 원본에 임시 테마를 만들었다가 지운다 — 중간에 죽어도 지우도록 trap 을 건다.
set -u
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
ID="zz_scaffold_probe"
cleanup() { python3 "$ADDON/tools/new_theme.py" --remove "$ID" > /dev/null 2>&1; }
trap cleanup EXIT
FAILED=0

# 🛑 다이얼 표는 생성물이다 — 스킨 스크립트의 `@export` 기본값을 고치고 생성기를 안 돌리면 낡는다.
BEFORE_TABLE="$(cat "$ADDON/tools/skin_dials.json")"
python3 -c "import sys; sys.path.insert(0, '$ADDON/tools'); import make_theme; make_theme.write_skin_dials_table()"
[ "$BEFORE_TABLE" = "$(cat "$ADDON/tools/skin_dials.json")" ] \
  && echo "   다이얼 표가 스킨 스크립트와 일치" || { echo "🛑 다이얼 표가 낡아 있었다 — 방금 다시 만들었으니 커밋한다"; FAILED=1; }
DIAL_COUNT=$(python3 -c "import json;t=json.load(open('$ADDON/tools/skin_dials.json'));print(len(t['default'])+len(t['scifi']))")
[ "$DIAL_COUNT" -ge 20 ] && echo "   다이얼 $DIAL_COUNT 개를 파싱했다" || { echo "🛑 다이얼 파싱이 $DIAL_COUNT 개뿐 — 파서가 깨졌다"; FAILED=1; }

python3 "$ADDON/tools/new_theme.py" "$ID" --from scifi_light --title "Probe" > /dev/null || { echo "🛑 스캐폴딩 실패"; exit 1; }
[ -f "$ADDON/themes/palettes/$ID.json" ] && [ -f "$ADDON/themes/presets/$ID.tres" ] \
  && echo "   팔레트 JSON · 프리셋 리소스 생김" || { echo "🛑 파일이 안 생겼다"; FAILED=1; }

# 팔레트를 실제로 **바꿔 본다** — 물려받기만 되는 게 아니라 덮어쓰기가 먹는지.
python3 - "$ADDON/themes/palettes/$ID.json" <<'PY'
import json, sys
p = sys.argv[1]; spec = json.load(open(p, encoding="utf-8"))
spec["palette"]["accent"] = "#C77DFF"
spec["shape"]["radius"] = 4
spec["skin"]["dials"]["slot_border_lit"] = 3     # 스킨 숫자도 JSON 에서 바꾼다
json.dump(spec, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
python3 "$ADDON/tools/make_theme.py" "$ID" > /tmp/gohud_scaffold.log 2>&1 || { echo "🛑 생성 실패:"; tail -5 /tmp/gohud_scaffold.log; FAILED=1; }
grep -q "gohud_$ID.tres" /tmp/gohud_scaffold.log && echo "   테마 .tres 생성됨" || FAILED=1
grep -q '^GoHud/constants/radius = 4$' "$ADDON/themes/gohud_$ID.tres" \
  && echo "   형태의 radius=4 가 토큰까지 내려갔다" || { echo "🛑 형태 덮어쓰기가 토큰에 안 닿았다"; FAILED=1; }
# 🛑 적힌 색 그대로를 찾지 않는다 — 생성기가 읽히는 자리까지 **밀기** 때문에 파일에는 보정된 값이 있다.
#    "부모 테마의 강조색과 달라졌는가" 로 본다.
if [ "$(grep '^GoHud/colors/accent = ' "$ADDON/themes/gohud_$ID.tres")" != "$(grep '^GoHud/colors/accent = ' "$ADDON/themes/gohud_scifi_light.tres")" ]; then
  echo "   팔레트의 accent 가 반영됐다(보정을 거쳐)"
else
  echo "🛑 팔레트 덮어쓰기가 안 먹었다"; FAILED=1
fi
[ -d "$ADDON/assets/$ID" ] && echo "   컨트롤 그림 폴더 생김" || { echo "🛑 그림 폴더가 없다"; FAILED=1; }
grep -q '^slot_border_lit = 3$' "$ADDON/themes/skins/gohud_skin_$ID.tres" 2>/dev/null \
  && echo "   스킨 다이얼이 스킨 리소스에 내려갔다" || { echo "🛑 스킨 다이얼이 리소스에 안 닿았다"; FAILED=1; }
grep -q 'gohud_skin_'"$ID"'.tres' "$ADDON/themes/presets/$ID.tres" \
  && echo "   프리셋이 자기 스킨 리소스를 가리킨다" || { echo "🛑 프리셋이 스킨을 안 가리킨다"; FAILED=1; }

# 새 테마가 **가독성 검사를 그대로 통과**해야 한다 — 물려받은 값이 보정을 거치므로 통과가 정상이다.
if python3 "$ADDON/tools/check_contrast.py" --quiet 2>&1 | grep -A 12 "gohud_$ID.tres" | grep -q "🛑"; then
  echo "🛑 새 테마가 대비 검사에 걸린다"; FAILED=1
else
  echo "   새 테마가 대비 검사를 통과한다"
fi

if [ "$FAILED" -eq 0 ]; then echo "✅ 테마 스캐폴딩 — 파일 하나로 테마가 생긴다"; else echo "🛑 스캐폴딩이 깨져 있다"; fi
exit "$FAILED"
