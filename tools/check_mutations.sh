#!/bin/bash
# 🧬 Measure **what the checks actually catch**. Break the code on purpose, one spot at a time, and see whether a check notices.
#
#   GOHUD_PROJECT=/path/to/verify bash addons/gohud/tools/check_mutations.sh
#
# ## Why it is needed
# **A check that passes may only have been built to pass.** That really happened — the `skin contrast`
# check was **green whatever it measured, for seven rounds**, because of value capture in a GDScript lambda (2026-09-13).
# The number of checks is no ground for trust. You only know by breaking things.
#
# ## How to read it
# | Result | Meaning |
# |---|---|
# | `caught` | a check guarding that rule is **alive** |
# | `🛑 missed` | **nobody guards** that rule — add a check, or admit it was never a rule |
#
# 🛑 The original is never touched. Mutations go only into the **copy** in the verification project, and are reverted every time.
set -u

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${GOHUD_PROJECT:-}"
[ -n "$PROJECT" ] || { echo "🛑 point GOHUD_PROJECT at the verification project" >&2; exit 2; }
COPY="$PROJECT/addons/gohud"
[ -d "$COPY" ] || { echo "🛑 $COPY does not exist" >&2; exit 2; }

CAUGHT=0
MISSED=0
SKIPPED=0
MISSES=""

# mutate <file> <find> <replace with> <what it guards> [env]
#   A fifth argument of `env` means **not catching it is normal in this environment**.
#   For example the safe area is the whole screen on desktop, so honoring it or not gives the same result — it only shows on a real device.
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
    printf "   ⚠️  %-46s mutation site not found (the code changed)\n" "$rule"
    cp "$backup" "$path"; rm -f "$backup"
    return
  fi

  # 🛑 Do not judge by the output — even a failure reads `gohud tests: 267/271 passed`, which contains "passed".
  #    (On the very first day this tool was used it fell into that trap and reported a false "all 10 missed".)
  #    Use the exit code.
  if GOHUD_PROJECT="$PROJECT" bash "$ADDON/tools/run_tests.sh" > /dev/null 2>&1; then
    if [ "$expect" = "env" ]; then
      printf "   ·  %-46s cannot be verified here (real device only)\n" "$rule"
      SKIPPED=$((SKIPPED + 1))
    else
      printf "   🛑 %-46s missed\n" "$rule"
      MISSED=$((MISSED + 1))
      MISSES="$MISSES\n     · $rule"
    fi
  else
    printf "      %-46s caught\n" "$rule"
    CAUGHT=$((CAUGHT + 1))
  fi
  cp "$backup" "$path"; rm -f "$backup"
}

echo "🧬 breaking the checks on purpose — only in the copy under $PROJECT, never the original"
echo "   viewport: ${GOHUD_VIEWPORT:-390x844 (default)}"
printf "\n\033[1m── touch & input\033[0m\n"
mutate "widgets/go_icon_button.gd" \
  "var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)" \
  "var reach := 0.0" \
  "icon button is tappable beyond its node"
mutate "widgets/go_slot.gd" \
  "var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)" \
  "var reach := 0.0" \
  "a slot forced small is still tappable up to 48dp"
mutate "widgets/go_notice.gd" \
  "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED" \
  "mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED" \
  "the snackbar does not steal input"

printf "\n\033[1m── layout\033[0m\n"
mutate "widgets/go_style.gd" \
  "if child is Control: (child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL)" \
  "if child is Control: pass)" \
  "grid cells share the leftover width"
# 🛑 This one line appears **three times** in the file (label, button, input). A mutation replaces
#    only the first match, so the target is pinned **together with the line above it** — otherwise you change the label and conclude "there is no button check".
mutate "widgets/go_style.gd" \
  "	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if GoUi.config.autowrap_text: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART" \
  "	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS" \
  "label text wraps"
# 🛑 The `fit_words(node)` line exists in **two places**, button and toggle — pin the following line too so only the target changes.
mutate "widgets/go_style.gd" \
  "	if GoUi.config.autowrap_text: fit_words(node)
	if tone == Tone.BARE:" \
  "	if tone == Tone.BARE:" \
  "button text wraps by word"
mutate "widgets/go_style.gd" \
  "	if GoUi.config.autowrap_text: fit_words(node)   # the same word rule as buttons" \
  "	pass" \
  "toggle text wraps by word"
mutate "widgets/go_style.gd" \
  "	if words.size() <= 1:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		return" \
  "	if false:
		return" \
  "a one-word button never wraps"
mutate "widgets/go_style.gd" \
  "	var shown := node.atr(node.text) if node.is_inside_tree() else node.text" \
  "	var shown := node.text" \
  "the word rule looks at the shown text, not the translation key"
mutate "widgets/go_form.gd" \
  "	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and not Engine.is_editor_hint():" \
  "	if false:" \
  "the form reapplies the word rule when the language changes"
mutate "widgets/go_bar.gd" \
  "GoStyle.fit_content_height(self, column)" \
  "pass" \
  "the bar does not overlap its name row"

printf "\n\033[1m── color & contrast\033[0m\n"
mutate "widgets/go_slot.gd" \
  "GoUi.skin().readable_on(" \
  "Color(" \
  "slot text is readable on its plate"
mutate "widgets/go_slot.gd" \
  "		_icon.modulate = GoUi.skin().readable_on(
			GoUi.color(GoTheme.MUTED) if faded else GoUi.color(GoTheme.TEXT), on_face)" \
  "		_icon.modulate = Color.WHITE" \
  "slot icon is readable on its plate"
mutate "widgets/go_icon_button.gd" \
  "	_glyph = icon_set.node(icon_name, glyph_size, glyph_ink)" \
  "	_glyph = icon_set.node(icon_name, glyph_size, icon_tint)" \
  "a child label glyph gets the theme color too"
mutate "core/go_skin.gd" \
  "	if &\"border_color\" in box: box.set(&\"border_color\", pick)" \
  "	if false: box.set(&\"border_color\", pick)" \
  "a fill that melts into the backdrop gets an outline"
mutate "widgets/go_style.gd" \
  "var ink_on_chip := GoUi.skin().chip_ink(color)" \
  "var ink_on_chip := color" \
  "chip text is readable on the chip plate"

printf "\n\033[1m── tokens & config\033[0m\n"
mutate "core/go_ui.gd" \
  "if key == GoTheme.TOUCH: return config.min_touch_size" \
  "if false: return config.min_touch_size" \
  "min_touch_size becomes the touch token"
mutate "core/go_ui.gd" \
  "if overrides.has(key): return overrides[key]" \
  "if false: return overrides[key]" \
  "color_overrides win over the theme"

printf "\n\033[1m── screen adaptation\033[0m\n"
mutate "widgets/go_hud_anchor.gd" \
  "var area := GoSafeArea.usable_rect(window) if use_safe_area else window.get_visible_rect()" \
  "var area := window.get_visible_rect()" \
  "the HUD respects the safe area" env
mutate "core/go_safe_area.gd" \
  "	if not GoUi.config.respect_safe_area: return area" \
  "	if false: return area" \
  "the respect_safe_area setting is honored" env
mutate "widgets/go_form.gd" \
  "if cap > 0 and area.size.x > float(cap): side = maxf(side, (area.size.x - float(cap)) * 0.5)" \
  "if false: side = maxf(side, (area.size.x - float(cap)) * 0.5)" \
  "the form honors the max width per breakpoint"
mutate "widgets/go_form.gd" \
  "	_hud_pad = _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)) if avoid_hud else Vector4.ZERO" \
  "	_hud_pad = Vector4.ZERO" \
  "the form leaves room for floating HUDs"
mutate "widgets/go_form.gd" \
  "	_hud_pad = _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)) if avoid_hud else Vector4.ZERO" \
  "	_hud_pad = _hud_insets(area) if avoid_hud else Vector4.ZERO" \
  "on a wide screen the form is not pushed needlessly"
mutate "services/go_dialogs.gd" \
  "	GoStyle.style_button(_ok, GoStyle.Tone.DANGER_SOLID if destructive else GoStyle.Tone.PRIMARY)" \
  "	GoStyle.style_button(_ok, GoStyle.Tone.PRIMARY)" \
  "the confirm button of a destructive action is danger-colored"
mutate "widgets/go_form.gd" \
  "		if hud == null or not hud.reserve_space: continue" \
  "		if hud == null: continue" \
  "a slot with reserve_space off takes no room"
mutate "widgets/go_form.gd" \
  "roundi(maxf(view.y - area.end.y + _hud_pad.w, keyboard))" \
  "roundi(view.y - area.end.y + _hud_pad.w)" \
  "the form avoids the on-screen keyboard"
mutate "widgets/go_hud_anchor.gd" \
  "	if avoid_peers: _dodge_peers(area, line)" \
  "	pass" \
  "a notice dodges fixed HUDs"
mutate "widgets/go_hud_anchor.gd" \
  "	if not avoid_peers and now != _last_rect:
		_last_rect = now
		_wake_dodgers()" \
  "	_last_rect = now" \
  "when a fixture grows, the dodging slots follow"
mutate "widgets/go_hud_anchor.gd" \
  "	area = area.grow(-margin)" \
  "	pass" \
  "the HUD keeps a margin from the screen edge"

printf "\n\033[1m── landscape\033[0m\n"
mutate "widgets/go_hud_anchor.gd" \
  "	if landscape_spot >= 0 and view.x > view.y: return landscape_spot as Spot" \
  "	if false: return landscape_spot as Spot" \
  "in landscape the HUD moves to its assigned spot"
mutate "widgets/go_surface.gd" \
  "	var width_ratio := settings.surface_width_ratio_landscape if landscape else settings.surface_width_ratio_portrait" \
  "	var width_ratio := settings.surface_width_ratio_portrait" \
  "in landscape the surface gets narrower"

printf "\n\033[1m── keyboard-only users\033[0m\n"
mutate "widgets/go_surface.gd" \
  "func _focus_changed(target: Control) -> void:
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return" \
  "func _focus_changed(target: Control) -> void:
	if true: return
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return" \
  "focus that leaked outside the surface is pulled back"

printf "\n\033[1m── floating plates\033[0m\n"
mutate "core/go_skin.gd" \
  "	flat.shadow_size = float_shadow_size" \
  "	flat.shadow_size = GoUi.metric(GoTheme.GAP_SMALL)" \
  "a floating card shadow follows the dial"

printf "\n\033[1m── coach marks\033[0m\n"
mutate "widgets/go_coach_mark.gd" \
  "	global = _dodge_fixtures(Rect2(global, card.size), area, target).position" \
  "	pass" \
  "the coach-mark card avoids fixtures and keep_clear"
mutate "widgets/go_coach_mark.gd" \
  "		y = target.position.y" \
  "		y = area.position.y" \
  "in landscape the card sits level with its target"

printf "\n\033[1m── surfaces & back\033[0m\n"
mutate "widgets/go_surface.gd" \
  "	return _open_count > 0" \
  "	return false" \
  "tells whether any surface is open"

printf "\n\033[1m── RTL (mirrored layout)\033[0m\n"
mutate "widgets/go_scroll.gd" \
  "	layout_direction = Control.LAYOUT_DIRECTION_LTR" \
  "	layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE" \
  "the scroll rail stays on the right even in RTL"
mutate "widgets/go_bar.gd" \
  "	_value_label.text_direction = Control.TEXT_DIRECTION_LTR" \
  "	_value_label.text_direction = Control.TEXT_DIRECTION_AUTO" \
  "bar numbers read left-to-right even in RTL"
mutate "widgets/go_joystick.gd" \
  "	layout_direction = Control.LAYOUT_DIRECTION_LTR" \
  "	layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE" \
  "joystick directions do not follow the language"
mutate "widgets/go_style.gd" \
  "	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE" \
  "	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.layout_direction = Control.LAYOUT_DIRECTION_LTR" \
  "list rows mirror in RTL"

printf "\n\033[1m── icons & text\033[0m\n"
mutate "core/go_icon_set.gd" \
  "	if fallback != null: return fallback._resolve(icon, seen)" \
  "	if false: return fallback._resolve(icon, seen)" \
  "the icon set falls through to its fallback"
mutate "core/go_ui.gd" \
  "	if overrides.has(name): return overrides[name]" \
  "	if false: return overrides[name]" \
  "text_overrides win over the translation"

printf "\n"
TOTAL=$((CAUGHT + MISSED + SKIPPED))
if [ "$MISSED" -eq 0 ]; then
  echo "✅ $CAUGHT of $TOTAL mutations caught · $SKIPPED cannot be verified here — none missed"
else
  echo "🛑 $MISSED of $TOTAL mutations were missed:"
  printf "%b\n" "$MISSES"
  echo "   → add a check, or admit it was never a rule"
fi
exit 0
