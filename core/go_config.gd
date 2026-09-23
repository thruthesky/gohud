## ⚙️ gohud's **one settings sheet**. Theme, icons, metrics, behavior, feedback and localization are all decided here.
##
## ## Why a resource
## If the settings were code constants, the user would have to fork the addon to change them. Pulled
## out into a single `.tres`, **the project's settings survive an addon update** — as an asset, that is the most important property there is.
##
## ## How to attach it — one of three
## ```gdscript
## # ① Project settings (recommended) — put the path in Project Settings > General > Gohud > Config in the editor.
## #    Enabling the plugin creates that field, and gohud reads it automatically when it builds its first widget.
##
## # ② Straight from code — this works without an autoload or the plugin.
## GoUi.config = preload("res://ui/my_gohud.tres")
##
## # ③ Do nothing — it runs on the defaults. Which means it is usable the moment it is installed.
## ```
##
## ## 🛑 A field left empty *is* the "default"
## Leave `theme` empty and gohud's default theme is used; leave `icons` empty and gohud's default icon set is.
## So **fill in only the fields you want to change** — there is no need to fill them all.
@tool
class_name GoConfig
extends Resource

## Emitted when a value changes. `GoUi` picks it up and redraws the widgets that are open.
signal changed_settings


# ── Appearance ─────────────────────────────────────────────────────────

@export_group("Appearance")

## 🎁 **A look bundle** (`default_dark`·`default_light`·`scifi_dark`·`scifi_light`). Empty means the default bundle.
##
## Of `theme`·`skin`·`icons` below, **only the empty fields** are filled from this bundle — so you pick a
## preset and then override just `theme` with your own. From code, `GoUi.use_preset()` is easier.
@export var preset: StringName = &"":
	set(value):
		preset = value
		emit_changed()
		changed_settings.emit()

## The `Theme` the widgets use. Empty falls back to the `preset` above, and failing that to gohud's default (dark) theme.
##
## 🔑 **There is no need to swap the whole thing** — duplicate the default theme and change only the colors,
##    or drop in an entirely different theme and let the missing tokens come from the default theme (`token_fallback`).
@export var theme: Theme:
	set(value):
		theme = value
		emit_changed()
		changed_settings.emit()

## Whether to fill from the default theme when the `theme` above has no gohud token (`GoHud/colors/...`).
## 🛑 Turned off, a missing token comes out black·0. Turn it off only if you filled your own theme from end to end.
@export var token_fallback := true

## The look of **what the widgets draw themselves** (joystick·quick slot·coach mark·chip·alert box). Empty means gohud's default look.
##
## 🔑 Where `theme` decides the colors and the look of the engine's controls, this decides the look of
##    **the spots the code draws**. To pick the two as one bundle, use `GoUi.use_preset()`.
@export var skin: GoSkin:
	set(value):
		skin = value
		emit_changed()
		changed_settings.emit()

## The icon set. Empty means gohud's default set (84 hand-drawn icons · MIT).
@export var icons: GoIconSet:
	set(value):
		icons = value
		emit_changed()
		changed_settings.emit()

## 🧩 **More icon sets**, looked in after the one above (or the preset's) — for names it does not draw.
## `GoUi.use_preset()` leaves this list alone, so a preset's own drawings (the medieval engravings) stay on top and
## these only fill in the names it lacks. `GoUi.add_icons()` appends to it.
##
## ```gdscript
## GoUi.add_icons(GoIconLibrary.icon_set())   # 1,000 more names — plus the game set's 187, which it falls back to
## ```
## 🛑 Assign a new array (or call `GoUi.refresh()` after changing this one in place) — an in-place `append` has no
##    setter to tell the widgets on screen.
@export var extra_icons: Array[GoIconSet] = []:
	set(value):
		extra_icons = value
		emit_changed()
		changed_settings.emit()

## Individual color overrides — for when you want to change just `accent` without building a whole theme.
## The keys are token names such as `GoTheme.ACCENT`.
@export var color_overrides: Dictionary[StringName, Color] = {}

## Individual metric overrides — `touch`·`padding`·`radius` and the rest. Same idea as `color_overrides` above.
@export var metric_overrides: Dictionary[StringName, int] = {}

## Body font size (dp). 0 keeps the theme's value.
@export_range(0, 48) var base_font_size := 0

## On a narrow screen, shrink the type by one step and nothing else (touch targets stay).
## 🛑 It does not shrink the touch size — a finger does not get smaller because the screen did.
@export var shrink_type_on_mobile := true


# ── Responsive ─────────────────────────────────────────────────────────

@export_group("Responsive")

## Whether `GoScale` should set up a **1 unit = 1dp coordinate space**.
##
## 🛑 The default is **off**. This changes the window's `content_scale_factor`, so it affects the
##    coordinate space of the whole project — never switch it on silently in someone else's project. The one turning it on decides.
@export var scale_enabled := false

## A short side at or below this many dp is the mobile breakpoint.
@export_range(240, 1200) var mobile_max_dp := 576.0

## A short side at or below this many dp is a tablet.
@export_range(480, 2000) var tablet_max_dp := 991.0

## Readability gain per breakpoint — the narrower it is, the more it grows. 1.0 is pure dp.
@export_range(1.0, 1.5, 0.01) var read_gain_mobile := 1.10
@export_range(1.0, 1.5, 0.01) var read_gain_tablet := 1.05
@export_range(1.0, 1.5, 0.01) var read_gain_desktop := 1.00

## Extra multiplier that enlarges the UI on desktop (correcting for the longer viewing distance). 1.0 means none.
@export_range(1.0, 1.6, 0.01) var desktop_ui_gain := 1.0

## Maximum content width of a form (a vertical list such as login·settings) in dp. 0 is no limit.
@export_range(0, 1200) var form_max_width_mobile := 0
@export_range(0, 1200) var form_max_width_tablet := 440
@export_range(0, 1200) var form_max_width_desktop := 480

## Whether to keep clear of the device safe area (notch·rounded corners). It only takes real effect on mobile.
@export var respect_safe_area := true


# ── Surfaces (popups·sheets·dialogs) ───────────────────────────────────

@export_group("Surface")

## Maximum card width (dp).
@export_range(200, 1600) var surface_max_width := 480.0

## Maximum card height (dp).
@export_range(200, 2000) var surface_max_height := 700.0

## Default share of the screen height a card takes.
@export_range(0.2, 1.0, 0.01) var surface_height_ratio := 0.68

## 🛑 The **ceiling** on the screen height a card may take. The screen behind has to show above and
##    below for it to read as "a floating window" — left at 1.0 it looks like a full-screen page.
@export_range(0.4, 1.0, 0.01) var surface_max_height_ratio := 0.72

## 🔑 **If the content needs more, it grows to here** (centered card · only when `fit_content`).
##
## Where `surface_max_height_ratio` above means "up to this much regardless of the content", this value
## means "stretch up to this much if that is what it takes for the content to fit". Kept as a single
## value it gave us **30% of the screen still free while the form's last input was pushed out of the
## scroll view** — the user never learns the field is there and submits it empty (measured 2026-09-16
## on the Laryen account-link form: at a logical 317×704 the card stopped at 457 and the third field was 0% visible).
##
## 🛑 Not used for sheets you drag to resize (`resizable`) or sheets that came up from the bottom
##    (`BOTTOM`) — that height was decided by the user.
@export_range(0.4, 1.0, 0.01) var surface_fit_max_height_ratio := 0.94

## Share of the width a card takes on a portrait screen.
@export_range(0.5, 1.0, 0.01) var surface_width_ratio_portrait := 0.94

## Share of the width a card takes on a landscape screen (narrower, since there is room to spare left and right).
@export_range(0.3, 1.0, 0.01) var surface_width_ratio_landscape := 0.72

## 🪟 **Opacity** of the panel (container) background (0.0~1.0) — applied to the whole project at once.
## At 0.8, 20% of what is behind the panel bleeds through. **Negative keeps the theme's value** (the default).
##
## 🛑 Text·icons·buttons do not follow this value. Only the panel background thins out; the content on it stays crisp.
## 🔑 **It is a ratio** — the opacity handled in code and in the inspector is the 0.0~1.0 of `Color.a`·`modulate.a`.
##    Integer percentages live **only in the theme's constant layer** (a `Theme` can hold nothing but integers · `GoTheme.PANEL_ALPHA`).
##
## ```gdscript
## GoUi.config.container_alpha = 0.7     # every panel at 70%
## GoUi.refresh()                        # 🛑 call this to redraw the widgets already on screen too
## ```
@export_range(-1.0, 1.0, 0.01) var container_alpha := -1.0

## 🪟 Opacity **per panel variant** (0.0~1.0) — it **takes precedence** over `container_alpha` above.
## The keys are panel variants (`GoTheme.BOX_PANEL`·`BOX_CARD`·`BOX_HUD`·`BOX_NOTICE`·`BOX_POPUP`), and a
## negative value counts as "not decided" and is handed down to the layer below.
##
## 🔑 It exists because the demands differ per variant — a dialog may let the background show through, but
##    a HUD panel laid straight over the game picture has to be fuller for the text to read.
##
## ```gdscript
## GoUi.config.container_alpha_overrides = {
##     GoTheme.BOX_PANEL: 0.7,   # dialogs·sheets can be airy
##     GoTheme.BOX_HUD: 0.95,    # the HUD nearly solid — it has to read over the world
## }
## GoUi.refresh()
## ```
@export var container_alpha_overrides: Dictionary[StringName, float] = {}

## Default for whether pressing the background (scrim) closes it. Each surface can decide for itself.
@export var dismiss_on_scrim := false

## Whether to fade the card in when a surface opens.
@export var surface_fade_in := false

## Fade duration (seconds).
@export_range(0.0, 1.0, 0.01) var fade_seconds := 0.14

## The **visible** size of the close button (dp). The touch area widens out past the node, up to the `touch` token below.
@export_range(16, 96) var close_button_visual := 36

## Do not raise a focus ring on a window opened with a pointer (mouse·finger).
## 🛑 When all that happened was opening a menu by touch and the close button alone lights up, it reads as a "press here" signal.
@export var suppress_pointer_focus_ring := true

## Close the topmost surface on Escape / the Android back gesture.
@export var close_on_back := true


# ── Feedback (sound·haptics) ───────────────────────────────────────────

@export_group("Feedback")

## Whether to use haptics (it only really buzzes on Android·iOS).
@export var haptics_enabled := true

## Duration (ms) and strength of the three haptic steps. The shorter it is, the lighter it feels.
@export_range(0, 200) var haptic_tap_ms := 10
@export_range(0.0, 1.0, 0.01) var haptic_tap_amplitude := 0.35
@export_range(0, 200) var haptic_light_ms := 20
@export_range(0.0, 1.0, 0.01) var haptic_light_amplitude := 0.5
@export_range(0, 400) var haptic_medium_ms := 40
@export_range(0.0, 1.0, 0.01) var haptic_medium_amplitude := 0.8

## Sound signal name → the project's audio cue name.
## 🛑 gohud **ships no audio.** Making the sound is the project's job —
##    plug a single Callable into `GoFeedback.sound_handler` and these names are handed straight over.
@export var sound_cues: Dictionary[StringName, String] = {
	&"opened": "ui_open",
	&"closed": "ui_close",
	&"tapped": "ui_click",
	&"confirmed": "ui_confirm",
	&"canceled": "ui_cancel",
	&"failed": "ui_error",
	&"fanfare": "ui_fanfare",
}


# ── Localization ───────────────────────────────────────────────────────

@export_group("Localization")

## Translation keys for the strings gohud uses. If the project already has keys with the same meaning, swap them in here.
## 🛑 If a value is **not** in the translation table, `tr()` hands the key back and the key shows on screen.
##    When that happens, put the literal text straight in through `text_overrides` below.
@export var text_keys: Dictionary[StringName, String] = {
	&"close": "gohud_close",
	&"back": "gohud_back",
	&"next": "gohud_next",
	&"done": "gohud_done",
	&"skip": "gohud_skip",
	&"confirm": "gohud_confirm",
	&"cancel": "gohud_cancel",
	&"search": "gohud_search",
	&"loading": "gohud_loading",
	&"empty": "gohud_empty",
	&"retry": "gohud_retry",
	# 🔑 **The format that wraps a number is a string too.** If a widget hard-codes `"%d / %d"`, that one
	#    line stays in English convention forever — Turkish puts the percent sign in **front** (%50) and
	#    French spaces the number and the sign apart. So even format strings are pulled out as translation keys.
	# 🛑 Placeholders are `{name}` (`String.format`). With `%s`, a translator who drops a placeholder
	#    kills the screen with "not all arguments converted".
	&"bar_fraction": "gohud_bar_fraction",      # {value} / {max}
	&"bar_percent": "gohud_bar_percent",        # {percent}%
	&"coach_progress": "gohud_coach_progress",  # {step} / {total}
	&"slot_quantity": "gohud_slot_quantity",    # ×{count}
	&"slot_unknown": "gohud_slot_unknown",      # …
}

## Text used **as is**, without going through translation. An escape hatch for projects that do not use a translation table.
## A name present here takes precedence over `text_keys` above.
@export var text_overrides: Dictionary[StringName, String] = {}

## How to write big numbers short. Left empty, the built-in rule (`12.3k` · `4.5m`) applies.
## 🛑 Pulled out as a hook because it is **something a format string cannot fix** — Korean·Chinese·Japanese
##    break at 10,000 (man/wan) and 100,000,000 (eok/yi), not at thousands/millions. Where the number breaks
##    differs, so the value calculation itself has to differ.
##
## ```gdscript
## GoUi.config.number_formatter = func(amount: float) -> String:
##     if absf(amount) >= 100_000_000.0: return "%.1f億" % (amount / 100_000_000.0)
##     if absf(amount) >= 10_000.0: return "%.1f萬" % (amount / 10_000.0)
##     return str(roundi(amount))
## ```
## ```
@export var number_formatter := Callable()

## Whether to attach gohud's built-in translations (16 strings × 21 languages) to the `TranslationServer`.
## 🛑 Turn it off if the project already holds the same keys — whichever attaches last wins.
@export var load_builtin_translations := true


# ── Accessibility ──────────────────────────────────────────────────────

@export_group("Accessibility")

## Minimum side of a touch target (dp). Material 48 · Apple HIG 44 are the basis.
## 🛑 It is the floor for **hit testing**, not for visual size — a widget may look smaller than this,
##    but the area you can press keeps to this value.
@export_range(24, 96) var min_touch_size := 48

## Reduce motion — turns off fades and the coach-mark pulse.
@export var reduce_motion := false

## Wrap long text. 🛑 Turned off, a line stretches out and the minimum width can run past the screen.
@export var autowrap_text := true


func _init() -> void:
	# Catch every path that calls `emit_changed()` (the theme·icon setters and so on) in one place.
	# 🛑 **Changing a plain field from code sends no signal** — `config.surface_max_width = 600` just changes
	#    the value quietly. To redraw the widgets already on screen, call `GoUi.refresh()` after the change.
	if not changed.is_connected(_on_changed): changed.connect(_on_changed)


func _on_changed() -> void:
	changed_settings.emit()


## A copy of this config — for when one screen alone should differ at runtime.
## 🛑 Plain `duplicate()` leaves the Dictionaries **shared**, so an edit on one side bleeds into the other.
func copy() -> GoConfig:
	var clone: GoConfig = duplicate(true)
	clone.color_overrides = color_overrides.duplicate(true)
	clone.metric_overrides = metric_overrides.duplicate(true)
	clone.container_alpha_overrides = container_alpha_overrides.duplicate(true)
	clone.sound_cues = sound_cues.duplicate(true)
	clone.text_keys = text_keys.duplicate(true)
	clone.text_overrides = text_overrides.duplicate(true)
	return clone
