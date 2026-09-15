# Platform — icons, languages, sound & haptics, accessibility, screens, Back

Source: `core/go_icon_set.gd`, `core/go_ui.gd`, `core/go_feedback.gd`, `core/go_safe_area.gd`,
`core/go_scale.gd`, `core/go_back_policy.gd`, `core/go_runtime.gd`, `i18n/gohud.csv`.

## Contents

1. [Icons](#1-icons)
2. [Localization and RTL](#2-localization-and-rtl)
3. [Sound and haptics](#3-sound-and-haptics)
4. [Accessibility and input](#4-accessibility-and-input)
5. [Safe area, keyboard, breakpoints, dp scale](#5-safe-area-keyboard-breakpoints-dp-scale)
6. [Back button and modality](#6-back-button-and-modality)

## 1. Icons

Widgets ask for icons **by name**; `GoUi.icons()` (a `GoIconSet`) decides what draws. Any name works if the set
defines it — the constants just prevent typos.

The 84 constants on `GoIconSet` (value = lowercase name):

| Group | Names |
|---|---|
| Navigation | `CLOSE` `BACK` `FORWARD` `UP` `DOWN` `CHEVRON_LEFT` `CHEVRON_RIGHT` `CHEVRON_UP` `CHEVRON_DOWN` `MENU` `MORE` `EXTERNAL` `EXPAND` `COLLAPSE` |
| Status | `CHECK` `INFO` `WARNING` `ERROR` `SUCCESS` `HELP` `BELL` `CLOCK` `HOURGLASS` |
| People | `USER` `USERS` `USER_PLUS` `CHAT` `HEART` `STAR` `CROWN` |
| Settings | `SETTINGS` `SLIDERS` `DISPLAY` `MOBILE` `VOLUME_HIGH` `VOLUME_LOW` `VOLUME_OFF` `EYE` `EYE_OFF` `SUN` `MOON` `GLOBE` |
| Actions | `PLUS` `MINUS` `TRASH` `EDIT` `SAVE` `REFRESH` `SEARCH` `FILTER` `SORT` `COPY` `DOWNLOAD` `UPLOAD` `PLAY` `PAUSE` `STOP` `POWER` `LOGOUT` `LOGIN` |
| Security | `LOCK` `UNLOCK` `SHIELD` `SHIELD_CHECK` `KEY` |
| Places & items | `HOME` `MAP` `LOCATION` `BAG` `BOX` `COIN` `GIFT` `BOOK` |
| Layout | `LIST` `GRID` `COLUMNS` `CHART` |
| Game | `SWORD` `BOLT` `TARGET` `FLAG` `POTION` `SKULL` `RUN` |

The medieval set (`res://addons/gohud/icons/gohud_icons_medieval.tres`) redraws `bag book box coin crown flag heart
key map potion shield star sword user` and adds `&"scroll"` and `&"seal"`; every other name falls back to default.

| API | Notes |
|---|---|
| `node(icon, size: int, ink := Color.TRANSPARENT) -> Control` | `TextureRect` (texture set) or `Label` (font set), exact square min size. Unknown name → empty box + debug warning |
| `texture(icon) -> Texture2D` · `glyph(icon) -> String` · `glyph_font(icon)` · `has_icon(icon)` · `icon_names()` | |
| fields | `set_name` · `attribution` · `textures: Dictionary[StringName, Texture2D]` · `font` · `codepoints: Dictionary[StringName, int]` · `font_size_ratio` · `fallback: GoIconSet` · `tint` |
| lookup order | `textures` → `codepoints` → `fallback` |
| on buttons | `GoStyle.apply_icon(button, GoIconSet.SAVE)` · `GoStyle.icon_button(...)` |

```gdscript
# Your own SVGs over the defaults (draw them white; import as DPITexture so they stay sharp)
var mine := GoIconSet.new()
mine.set_name = "Studio icons"
mine.fallback = GoUi.DEFAULT_ICONS
mine.textures = {GoIconSet.CLOSE: preload("res://ui/icons/close.svg"), &"quest": preload("res://ui/icons/quest.svg")}
GoUi.config.icons = mine

# An icon font (keep commercial fonts in your project, not in a gohud fork)
var font_set := GoIconSet.new()
font_set.font = preload("res://ui/fonts/fa-solid-900.otf")
font_set.codepoints = {GoIconSet.CLOSE: 0xf00d, GoIconSet.SETTINGS: 0xf013}
font_set.font_size_ratio = 0.9
font_set.fallback = GoUi.DEFAULT_ICONS
GoUi.config.icons = font_set
```

## 2. Localization and RTL

Widgets never hard-code display text. Text you pass (titles, labels, rows) is yours: literal with `label()` /
`button()`, a translation key with `label_key()` / `button_key()` / `*_key()` methods. gohud's own 16 strings:

| Name | English | Kind |
|---|---|---|
| `close` `back` `next` `done` `skip` `confirm` `cancel` `search` `loading` `empty` `retry` | Close, Back, … | words |
| `bar_fraction` · `bar_percent` · `coach_progress` · `slot_quantity` · `slot_unknown` | `{value} / {max}` · `{percent}%` · `{step} / {total}` · `×{count}` · `…` | formats (`{name}` placeholders) |

```gdscript
GoUi.config.text_overrides = {&"confirm": "Yes", &"cancel": "No"}   # literal, no translation table
GoUi.config.text_keys[&"confirm"] = "MY_DIALOG_YES"                  # or point at your own keys
GoUi.config.number_formatter = func(amount: float) -> String:        # CJK grouping: 만 / 억
	if absf(amount) >= 100_000_000.0: return "%.1f억" % (amount / 100_000_000.0)
	if absf(amount) >= 10_000.0: return "%.1f만" % (amount / 10_000.0)
	return str(roundi(amount))
TranslationServer.set_locale("ko")                                  # widgets re-translate themselves
```

- `GoUi.text(name)` returns translated text (override → key → name); `GoUi.text_key(name)` returns the key.
- Built-in translations (21 locales: en ko ja zh zh_TW es pt de fr it nl pl ru uk tr vi id th hi ar he) load
  automatically once the CSV is imported; turn off with `load_builtin_translations = false` if your keys collide.
- 🛑 Placeholders are filled only via `args` (`GoDialogs`, `GoNotice.show_key`, `GoPromptCard.set_title_key`);
  `tr()` alone leaves `{name}` visible.
- RTL (`ar`, `he`): give your root Control `layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE`.
  Numbers, joysticks, scroll rails, the safe area and HUD anchors stay physically left-to-right on purpose.
- 🛑 Fonts: only Cinzel (Latin, medieval headings) ships. CJK, Thai, Arabic, Hebrew, Devanagari need a font with
  those glyphs in your Theme — missing glyphs draw as empty boxes without any error.

## 3. Sound and haptics

gohud ships no audio. `GoFeedback` pairs a sound cue with a vibration (Android/iOS only).

| Call | Cue (`GoConfig.sound_cues`) | Vibration |
|---|---|---|
| `GoFeedback.opened()` | `ui_open` | light |
| `closed()` · `tapped()` · `canceled()` · `toggled()` | `ui_close` · `ui_click` · `ui_cancel` · `ui_click` | tap |
| `confirmed()` · `fanfare()` | `ui_confirm` · `ui_fanfare` | light |
| `failed()` | `ui_error` | medium |
| `play(&"opened")` | by name (`OPENED` `CLOSED` `TAPPED` `CONFIRMED` `CANCELED` `FAILED` `FANFARE`) | |

```gdscript
GoFeedback.sound_handler = func(cue: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://audio/ui/%s.ogg" % cue)
	player.finished.connect(player.queue_free)
	get_tree().root.add_child(player)
	player.play()
GoFeedback.haptic_handler = func(ms: int, amplitude: float) -> void: pass   # optional replacement
```

`GoDialogs` and `GoSheet` call `opened/confirmed/canceled/closed` themselves; call `GoFeedback.tapped()` in your
own button handlers for a consistent feel.

## 4. Accessibility and input

- `min_touch_size` (48 dp) is an input floor, not a visual size: icon buttons and slots look smaller but hit 48 dp.
  Side-by-side icon buttons/slots need `touch_peers` so the nearer centre wins.
- Icon-only buttons: pass a tooltip (`GoStyle.icon_button(icon, action, -1, &"Inventory")`) — it becomes
  `accessibility_name` for screen readers.
- Focus rings show for keyboard/gamepad users only (`suppress_pointer_focus_ring`). Surfaces trap focus while
  open and restore it on close; set `surface.initial_focus` for controller-first screens.
- Quick slots skip Tab by default; `slot.keyboard_focus = true` when a gamepad is the only input.
- `reduce_motion` stops fades, bar easing and coach-mark pulses; `autowrap_text` keeps long strings on screen.
- Irreversible actions: `GoStyle.Tone.DANGER_SOLID` / `dialogs.confirm(..., destructive = true)`.
- Gamepad/keyboard: `ui_cancel` closes the topmost surface, finishes a coach tour.

## 5. Safe area, keyboard, breakpoints, dp scale

| API | Notes |
|---|---|
| `GoSafeArea.usable_rect(window) -> Rect2` | Excludes notch/gesture bar on Android/iOS; full rect on desktop or when `respect_safe_area` is off |
| `GoSafeArea.usable_rect_with_keyboard(window, keyboard_px)` | Also removes the virtual keyboard |
| `GoSafeArea.new()` (a Control) | Positions itself over the safe area — a parent for content that must avoid the notch |
| `enum GoScale.Bp { MOBILE, TABLET, DESKTOP }` | Short side in dp: ≤ `mobile_max_dp` (576) mobile, ≤ `tablet_max_dp` (991) tablet |
| `GoScale.breakpoint_for_dp(dp)` · `form_width_for(bp)` · `gain_for(bp, handheld, portrait)` · `display_scale(raw_scale, dpi, screen_px)` · `breakpoint_name(bp)` | Pure functions |
| `GoRuntime` (plugin autoload) | `breakpoint_changed(bp)` · `viewport_resized(size)` · `keyboard_changed(px)` · `current_bp()` · `is_mobile()` · `short_dp()` |
| `GoUi.is_handheld_platform()` | Android or iOS (not "narrow window") |

`scale_enabled = true` makes 1 UI unit = 1 dp by setting `Window.content_scale_factor` — it changes the whole
project's 2D coordinates, so only turn it on in a project designed for it.

```gdscript
var runtime := GoUi.runtime()
if runtime:
	runtime.breakpoint_changed.connect(func(bp: GoScale.Bp) -> void: rebuild_for(bp))
```

## 6. Back button and modality

- `GoBackPolicy.acquire(tree)` / `release(tree)` / `owners()` — counts screens that own Android Back so
  `SceneTree.quit_on_go_back` is restored only when the last one closes. `GoSurface`, `GoForm` (with a
  `%BackButton`) and `GoCoachMark` already use it. Every `acquire` needs a `release`, including in `_exit_tree`.
- Your own screen handling Back:

```gdscript
func _enter_tree() -> void: GoBackPolicy.acquire(get_tree())
func _exit_tree() -> void: GoBackPolicy.release(get_tree())
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not GoSurface.is_any_open():
		go_back()
```

- Pause gameplay input while a window is up: `if GoSurface.is_any_open(): return` in `_unhandled_input`.
