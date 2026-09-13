#!/bin/bash
# 🧬 **검사가 실제로 무엇을 잡는지** 잰다. 코드를 하나씩 일부러 망가뜨리고, 검사가 그것을 잡는지 본다.
#
#   GOHUD_PROJECT=/path/to/verify bash addons/gohud/tools/check_mutations.sh
#
# ## 왜 필요한가
# **통과하는 검사는 통과하도록 만들어졌을 뿐일 수 있다.** 실제로 그런 일이 있었다 — `skin contrast`
# 검사는 GDScript 람다의 값 캡처 때문에 **일곱 반복 동안 무엇을 재든 초록불**이었다(2026-09-13).
# 검사 개수는 신뢰의 근거가 되지 못한다. 깨뜨려 봐야 안다.
#
# ## 읽는 법
# | 결과 | 뜻 |
# |---|---|
# | `잡음` | 그 규칙을 지키는 검사가 **살아 있다** |
# | `🛑 놓침` | 그 규칙은 **아무도 지키지 않는다** — 검사를 더하거나, 규칙이 아니었던 것이다 |
#
# 🛑 원본은 건드리지 않는다. 검증 프로젝트 **사본**에만 변이를 넣고 매번 되돌린다.
set -u

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${GOHUD_PROJECT:-}"
[ -n "$PROJECT" ] || { echo "🛑 GOHUD_PROJECT 로 검증 프로젝트를 지정한다" >&2; exit 2; }
COPY="$PROJECT/addons/gohud"
[ -d "$COPY" ] || { echo "🛑 $COPY 가 없다" >&2; exit 2; }

CAUGHT=0
MISSED=0
SKIPPED=0
MISSES=""

# mutate <파일> <찾을 것> <바꿀 것> <무엇을 지키는가> [env]
#   다섯째 인자에 `env` 를 주면 **이 환경에서는 못 잡는 것이 정상**이라는 뜻이다.
#   예: 안전영역은 데스크톱에서 화면 전체라, 지키든 안 지키든 결과가 같다 — 실기기에서만 드러난다.
mutate() {
  local file="$1" from="$2" to="$3" rule="$4" expect="${5:-caught}"
  local path="$COPY/$file"
  local backup
  backup="$(mktemp)"
  cp "$path" "$backup"

  if ! python3 - "$path" "$from" "$to" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding="utf-8").read()
if old not in s:
    sys.exit(3)
open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
  then
    printf "   ⚠️  %-46s 변이 자리를 못 찾았다(코드가 바뀌었다)\n" "$rule"
    cp "$backup" "$path"; rm -f "$backup"
    return
  fi

  # 🛑 출력으로 판정하지 않는다 — 실패해도 `gohud tests: 267/271 passed` 라 "passed" 가 들어 있다.
  #    (이 도구를 처음 쓴 날 바로 이 함정에 걸려 "10개 전부 놓침" 이라는 거짓 결과가 나왔다.)
  #    종료 코드를 쓴다.
  if GOHUD_PROJECT="$PROJECT" bash "$ADDON/tools/run_tests.sh" > /dev/null 2>&1; then
    if [ "$expect" = "env" ]; then
      printf "   ·  %-46s 이 환경에서는 검증 불가(실기기 전용)\n" "$rule"
      SKIPPED=$((SKIPPED + 1))
    else
      printf "   🛑 %-46s 놓침\n" "$rule"
      MISSED=$((MISSED + 1))
      MISSES="$MISSES\n     · $rule"
    fi
  else
    printf "      %-46s 잡음\n" "$rule"
    CAUGHT=$((CAUGHT + 1))
  fi
  cp "$backup" "$path"; rm -f "$backup"
}

echo "🧬 검사를 깨뜨려 본다 — 원본이 아니라 $PROJECT 의 사본에만 넣는다"
echo "   뷰포트: ${GOHUD_VIEWPORT:-390x844(기본)}"
printf "\n\033[1m── 터치·입력\033[0m\n"
mutate "widgets/go_icon_button.gd" \
  "var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)" \
  "var reach := 0.0" \
  "아이콘 버튼이 노드 밖까지 눌린다"
mutate "widgets/go_slot.gd" \
  "var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)" \
  "var reach := 0.0" \
  "작게 강제된 슬롯도 48dp 까지 눌린다"
mutate "widgets/go_notice.gd" \
  "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED" \
  "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED" \
  "스낵바가 입력을 가로채지 않는다"

printf "\n\033[1m── 배치\033[0m\n"
mutate "widgets/go_style.gd" \
  "if child is Control: (child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL)" \
  "if child is Control: pass)" \
  "격자 칸이 남는 폭을 나눠 가진다"
# 🛑 이 한 줄은 파일에 **세 번** 나온다(라벨·버튼·입력칸). 변이는 첫 일치만 바꾸므로
#    겨냥한 곳을 **앞줄과 함께** 집는다 — 안 그러면 라벨을 바꿔 놓고 "버튼 검사가 없다" 고 오판한다.
mutate "widgets/go_style.gd" \
  "	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if GoUi.config.autowrap_text: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART" \
  "	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS" \
  "라벨 글자가 줄바꿈한다"
# 🛑 `fit_words(node)` 줄은 버튼과 토글 **두 곳**에 있다 — 뒷줄까지 집어 겨냥한 곳만 바꾼다.
mutate "widgets/go_style.gd" \
  "	if GoUi.config.autowrap_text: fit_words(node)
	if tone == Tone.BARE:" \
  "	if tone == Tone.BARE:" \
  "버튼 글자가 낱말 단위로 접힌다"
mutate "widgets/go_style.gd" \
  "	if GoUi.config.autowrap_text: fit_words(node)   # 버튼과 같은 낱말 규칙" \
  "	pass" \
  "토글 글자가 낱말 단위로 접힌다"
mutate "widgets/go_style.gd" \
  "	if words.size() <= 1:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		return" \
  "	if false:
		return" \
  "한 낱말 버튼은 접지 않는다"
mutate "widgets/go_style.gd" \
  "	var shown := node.atr(node.text) if node.is_inside_tree() else node.text" \
  "	var shown := node.text" \
  "낱말 규칙은 번역 키가 아니라 보이는 글자를 본다"
mutate "widgets/go_form.gd" \
  "	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and not Engine.is_editor_hint():" \
  "	if false:" \
  "언어가 바뀌면 폼이 낱말 규칙을 다시 입힌다"
mutate "widgets/go_bar.gd" \
  "GoStyle.fit_content_height(self, column)" \
  "pass" \
  "막대가 이름 줄과 겹치지 않는다"

printf "\n\033[1m── 색·대비\033[0m\n"
mutate "widgets/go_slot.gd" \
  "GoUi.skin().readable_on(" \
  "Color(" \
  "슬롯 글자가 판 위에서 읽힌다"
mutate "widgets/go_slot.gd" \
  "		_icon.modulate = GoUi.skin().readable_on(
			GoUi.color(GoTheme.MUTED) if faded else GoUi.color(GoTheme.TEXT), on_face)" \
  "		_icon.modulate = Color.WHITE" \
  "슬롯 아이콘이 판 위에서 읽힌다"
mutate "widgets/go_icon_button.gd" \
  "	_glyph = icon_set.node(icon_name, glyph_size, glyph_ink)" \
  "	_glyph = icon_set.node(icon_name, glyph_size, icon_tint)" \
  "자식 라벨 글리프도 테마 색을 받는다"
mutate "core/go_skin.gd" \
  "	if &\"border_color\" in box: box.set(&\"border_color\", pick)" \
  "	if false: box.set(&\"border_color\", pick)" \
  "바탕에 녹는 채움에 윤곽을 두른다"
mutate "widgets/go_style.gd" \
  "var ink_on_chip := GoUi.skin().chip_ink(color)" \
  "var ink_on_chip := color" \
  "칩 글자가 칩 판 위에서 읽힌다"

printf "\n\033[1m── 토큰·설정\033[0m\n"
mutate "core/go_ui.gd" \
  "if key == GoTheme.TOUCH: return config.min_touch_size" \
  "if false: return config.min_touch_size" \
  "min_touch_size 가 touch 토큰이 된다"
mutate "core/go_ui.gd" \
  "if overrides.has(key): return overrides[key]" \
  "if false: return overrides[key]" \
  "color_overrides 가 테마보다 우선한다"

printf "\n\033[1m── 화면 적응\033[0m\n"
mutate "widgets/go_hud_anchor.gd" \
  "var area := GoSafeArea.usable_rect(window) if use_safe_area else window.get_visible_rect()" \
  "var area := window.get_visible_rect()" \
  "HUD 가 안전영역을 지킨다" env
mutate "core/go_safe_area.gd" \
  "	if not GoUi.config.respect_safe_area: return area" \
  "	if false: return area" \
  "respect_safe_area 설정을 존중한다" env
mutate "widgets/go_form.gd" \
  "if cap > 0 and area.size.x > float(cap): side = maxf(side, (area.size.x - float(cap)) * 0.5)" \
  "if false: side = maxf(side, (area.size.x - float(cap)) * 0.5)" \
  "폼이 브레이크포인트별 최대 폭을 지킨다"
mutate "widgets/go_form.gd" \
  "	_hud_pad = _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)) if avoid_hud else Vector4.ZERO" \
  "	_hud_pad = Vector4.ZERO" \
  "폼이 떠 있는 HUD 자리를 비운다"
mutate "widgets/go_form.gd" \
  "	_hud_pad = _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)) if avoid_hud else Vector4.ZERO" \
  "	_hud_pad = _hud_insets(area) if avoid_hud else Vector4.ZERO" \
  "넓은 화면에서 폼을 헛되이 밀지 않는다"
mutate "services/go_dialogs.gd" \
  "	GoStyle.style_button(_ok, GoStyle.Tone.DANGER_SOLID if destructive else GoStyle.Tone.PRIMARY)" \
  "	GoStyle.style_button(_ok, GoStyle.Tone.PRIMARY)" \
  "위험 동작의 확인 버튼이 위험색이다"
mutate "widgets/go_form.gd" \
  "		if hud == null or not hud.reserve_space: continue" \
  "		if hud == null: continue" \
  "reserve_space 를 끈 칸은 자리를 안 먹는다"
mutate "widgets/go_form.gd" \
  "roundi(maxf(view.y - area.end.y + _hud_pad.w, keyboard))" \
  "roundi(view.y - area.end.y + _hud_pad.w)" \
  "폼이 가상 키보드를 피한다"
mutate "widgets/go_hud_anchor.gd" \
  "	if avoid_peers: _dodge_peers(area, line)" \
  "	pass" \
  "알림이 붙박이 HUD 를 피해 비킨다"
mutate "widgets/go_hud_anchor.gd" \
  "	if not avoid_peers and now != _last_rect:
		_last_rect = now
		_wake_dodgers()" \
  "	_last_rect = now" \
  "붙박이가 커지면 비키는 칸도 따라간다"
mutate "widgets/go_hud_anchor.gd" \
  "	area = area.grow(-margin)" \
  "	pass" \
  "HUD 가 화면 가장자리 여백을 둔다"

printf "\n\033[1m── 가로 화면\033[0m\n"
mutate "widgets/go_hud_anchor.gd" \
  "	if landscape_spot >= 0 and view.x > view.y: return landscape_spot as Spot" \
  "	if false: return landscape_spot as Spot" \
  "가로에서 HUD 가 지정한 자리로 옮겨 간다"
mutate "widgets/go_surface.gd" \
  "	var width_ratio := settings.surface_width_ratio_landscape if landscape else settings.surface_width_ratio_portrait" \
  "	var width_ratio := settings.surface_width_ratio_portrait" \
  "가로에서 창이 더 좁아진다"

printf "\n\033[1m── 키보드로만 쓰는 사람\033[0m\n"
mutate "widgets/go_surface.gd" \
  "func _focus_changed(target: Control) -> void:
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return" \
  "func _focus_changed(target: Control) -> void:
	if true: return
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return" \
  "창 밖으로 새어 나간 포커스를 되돌린다"

printf "\n\033[1m── 코치마크\033[0m\n"
mutate "widgets/go_coach_mark.gd" \
  "	global = _dodge_fixtures(Rect2(global, card.size), area, target).position" \
  "	pass" \
  "코치마크 카드가 붙박이·keep_clear 를 피한다"
mutate "widgets/go_coach_mark.gd" \
  "		y = target.position.y" \
  "		y = area.position.y" \
  "가로에서 카드는 대상과 같은 높이에"

printf "\n\033[1m── 창·뒤로가기\033[0m\n"
mutate "widgets/go_surface.gd" \
  "	return _open_count > 0" \
  "	return false" \
  "열린 창이 있는지 판정한다"

printf "\n\033[1m── RTL(거울 배치)\033[0m\n"
mutate "widgets/go_scroll.gd" \
  "	layout_direction = Control.LAYOUT_DIRECTION_LTR" \
  "	layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE" \
  "스크롤 레일은 RTL 에서도 오른쪽"
mutate "widgets/go_bar.gd" \
  "	_value_label.text_direction = Control.TEXT_DIRECTION_LTR" \
  "	_value_label.text_direction = Control.TEXT_DIRECTION_AUTO" \
  "막대 숫자는 RTL 에서도 왼→오"
mutate "widgets/go_joystick.gd" \
  "	layout_direction = Control.LAYOUT_DIRECTION_LTR" \
  "	layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE" \
  "조이스틱 방향은 언어를 안 따른다"
mutate "widgets/go_style.gd" \
  "	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE" \
  "	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.layout_direction = Control.LAYOUT_DIRECTION_LTR" \
  "목록 줄이 RTL 에서 거울처럼 뒤집힌다"

printf "\n\033[1m── 아이콘·문구\033[0m\n"
mutate "core/go_icon_set.gd" \
  "	if fallback != null: return fallback._resolve(icon, seen)" \
  "	if false: return fallback._resolve(icon, seen)" \
  "아이콘 세트가 fallback 으로 내려간다"
mutate "core/go_ui.gd" \
  "	if overrides.has(name): return overrides[name]" \
  "	if false: return overrides[name]" \
  "text_overrides 가 번역보다 우선한다"

printf "\n"
TOTAL=$((CAUGHT + MISSED + SKIPPED))
if [ "$MISSED" -eq 0 ]; then
  echo "✅ 변이 $TOTAL 개 중 $CAUGHT 개 잡힘 · $SKIPPED 개는 이 환경에서 검증 불가 — 놓친 것 없음"
else
  echo "🛑 변이 $TOTAL 개 중 $MISSED 개를 놓쳤다:"
  printf "%b\n" "$MISSES"
  echo "   → 검사를 더하거나, 그것이 규칙이 아니었음을 인정한다"
fi
exit 0
