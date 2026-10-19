## ⏱️ **The optional autoload**. It tracks the window size, the breakpoint, the safe area and the virtual keyboard in
## one place, and stands in another device for tests and screenshots (`simulate()`).
##
## ## It is not required
## Without it every widget works exactly as before and only these go missing.
##   · the notice when the breakpoint changes (`breakpoint_changed`)
##   · the dp coordinate space of `GoConfig.scale_enabled`
##   · virtual keyboard height tracking (so an input is not hidden behind the keyboard)
##   · the safe area followed through a 180° turn (`safe_area_changed`), and the device simulation (`simulate()`)
##
## ## How to turn it on
## Enabling the plugin registers it automatically under the name `GoRuntime`. To do it by hand, add
## `res://addons/gohud/core/go_runtime.gd` to Project Settings > Autoload under the name `GoRuntime`.
##
## 🛑 The name **must be `GoRuntime`** — `GoUi.runtime()` looks it up by that name.
@tool
extends Node

## The breakpoint changed. Forms and HUDs pick it up and lay their padding and sizes out again.
signal breakpoint_changed(bp: GoScale.Bp)

## The window size changed (it arrives even when the breakpoint stayed the same).
signal viewport_resized(size: Vector2)

## The virtual keyboard height changed (physical pixels).
signal keyboard_changed(height_px: int)

## The safe margins changed (left, top, right, bottom in UI units — `GoSafeArea.margins()`): a resize, a 180° turn
## found by the poll (`GoConfig.safe_area_poll_seconds`), or a simulated device.
signal safe_area_changed(margins: Vector4)

var _bp := GoScale.Bp.DESKTOP
var _short_dp := 0.0
var _keyboard := 0
var _last_px := Vector2i.ZERO
var _applying := false
var _margins := Vector4.ZERO
var _safe_px := Rect2i()
var _poll_left := 0.0
## The window before the first `simulate()` with a `size` (zero: not resized), put back by `clear_simulation()`.
var _real_size := Vector2i.ZERO
var _real_min_size := Vector2i.ZERO


func _ready() -> void:
	if Engine.is_editor_hint(): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(true)
	get_tree().root.size_changed.connect(_on_size_changed)


## 🔤 A `TranslationServer.set_locale()` from anywhere puts the new language's CJK font first (`GoUi.set_font_locale`,
## which does nothing when the order is already right) — the engine has no locale signal, but every node in the tree
## hears this notification. It also registers the new language's built-in translation (`GoUi.add_locale_translations`:
## only the current language's is loaded) — this autoload sits above the game's screens, so it is in before they
## re-translate.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not Engine.is_editor_hint():
		GoUi.add_locale_translations(TranslationServer.get_locale())
		GoUi.set_font_locale(TranslationServer.get_locale())


## The current breakpoint.
func current_bp() -> GoScale.Bp:
	return _bp


func is_mobile() -> bool:
	return _bp == GoScale.Bp.MOBILE


## The short side of the current screen (dp).
func short_dp() -> float:
	return _short_dp


## How many dp one unit is (= the current readability gain).
func dp_per_unit() -> float:
	return GoScale.gain_for(_bp, GoUi.is_handheld_platform(), _last_px.x < _last_px.y)


## The maximum form width of the current breakpoint (dp). 0 is no limit.
func form_max_width() -> int:
	return GoScale.form_width_for(_bp)


## The height the virtual keyboard covers (physical pixels). 0 when there is none.
func keyboard_height() -> int:
	return _keyboard


## The safe margins now (left, top, right, bottom in UI units) — what `safe_area_changed` last said.
func safe_margins() -> Vector4:
	return _margins


## 🧪 **Stands another device in** for tests and screenshots — `{dpi, insets, handheld, size}` as in
## `GoScale.simulate()` (Magnet Mayhem's device profiles can be passed as they are: `mobile` reads as `handheld`).
## The `PER_INCH` scale and `GoSafeArea` read it, the window takes its `size` (not in a headless run, which has no
## window to resize: the scale is still worked out for that size), and the scale is applied again at once.
##
## ```gdscript
## GoRuntime.simulate({"size": Vector2i(2532, 1170), "dpi": 460.0, "insets": Vector4(141, 0, 141, 63), "handheld": true})
## GoRuntime.clear_simulation()
## ```
func simulate(device: Dictionary) -> void:
	if Engine.is_editor_hint() or not is_inside_tree(): return
	GoScale.simulate(device)
	var window := get_tree().root
	if DisplayServer.get_name() != "headless":
		if device.has("size"):
			if _real_size == Vector2i.ZERO:
				_real_size = window.size
				_real_min_size = window.min_size
			window.min_size = Vector2i.ZERO
			window.size = device["size"]
		elif _real_size != Vector2i.ZERO:
			window.min_size = _real_min_size
			window.size = _real_size
			_real_size = Vector2i.ZERO
	_apply(true)


## The real device again (and the window's own size back).
func clear_simulation() -> void:
	simulate({})


## The device `simulate()` stands in; empty for the real one.
func simulation() -> Dictionary:
	return GoScale.simulated()


## Applies the scale settings again now (after `GoConfig.scale_profile` or `scale_enabled` changed), instead of at the
## next resize.
func reapply() -> void:
	if Engine.is_editor_hint() or not is_inside_tree(): return
	_apply(true)


func _on_size_changed() -> void:
	if _applying: return
	_apply(false)


## 🛑 Do not trust `size_changed` alone — change the window with `DisplayServer.window_set_size()` and there are
##    cases where no signal arrives (measured on a macOS `-s` run). The coordinate space then stays stale.
##    It is two integers compared, so the cost is negligible, and when the values match it ends right there.
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _window_px() != _last_px: _apply(false)
	_poll_keyboard()
	_poll_safe_area(delta)


## 🛑 A 180° turn in landscape keeps the window size — no resize arrives, yet the notch is now on the other side. So a
##    phone reads the safe area again a few times a second (a rect compared; nothing allocated).
func _poll_safe_area(delta: float) -> void:
	var every := GoUi.config.safe_area_poll_seconds
	if every <= 0.0 or not OS.has_feature("mobile") or not GoScale.simulated().is_empty(): return
	_poll_left -= delta
	if _poll_left > 0.0: return
	_poll_left = every
	var safe := DisplayServer.get_display_safe_area()
	if safe == _safe_px: return
	_safe_px = safe
	_check_safe_area()


func _check_safe_area() -> void:
	var now := GoSafeArea.margins(get_tree().root)
	if now == _margins: return
	_margins = now
	safe_area_changed.emit(now)


## The window in pixels: a simulated device's `size`, else the window's (a run with no window: the project's base).
func _window_px() -> Vector2i:
	var device := GoScale.simulated()
	if device.has("size"): return device["size"]
	var px := DisplayServer.window_get_size()
	if px.x <= 0 or px.y <= 0: px = get_tree().root.content_scale_size
	if px.x <= 0 or px.y <= 0: px = Vector2i(1152, 648)
	return px


func _poll_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return
	var height := DisplayServer.virtual_keyboard_get_height()
	if height == _keyboard: return
	_keyboard = height
	keyboard_changed.emit(height)


func _apply(force: bool) -> void:
	var window := get_tree().root
	# A run with no window, headless and the like — the project's base resolution is used.
	var px := _window_px()
	var scale := GoScale.display_scale(
		DisplayServer.screen_get_scale(), DisplayServer.screen_get_dpi(), DisplayServer.screen_get_size())
	# A simulated device's dpi decides its breakpoint too, its window standing for the whole screen.
	var device := GoScale.simulated()
	if device.has("dpi"): scale = GoScale.display_scale(0.0, roundi(float(device["dpi"])), px)
	var resized := px != _last_px
	_short_dp = float(mini(px.x, px.y)) / scale
	_last_px = px
	var bp := GoScale.breakpoint_for_dp(_short_dp)
	var changed := bp != _bp
	_bp = bp
	GoUi.set_mobile_type(bp == GoScale.Bp.MOBILE)

	if GoUi.config.scale_enabled and GoUi.config.scale_profile == GoScale.Profile.PER_INCH:
		var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
			ProjectSettings.get_setting("display/window/size/viewport_height", 648))
		# The dpi and the handheld test are the simulated device's when there is one; a browser and a missing dpi
		# follow `GoConfig.handheld_browsers` and `fallback_dpi`.
		var per_inch := GoScale.per_inch_factor(Vector2(px), GoScale.screen_dpi(), base, GoUi.config.per_inch_units,
			GoUi.config.per_inch_min_height, GoScale.is_handheld_screen())
		if force or not is_equal_approx(window.content_scale_factor, per_inch) or window.content_scale_size != Vector2i(base):
			_applying = true
			window.content_scale_size = Vector2i(base)
			window.content_scale_factor = per_inch
			_applying = false
	elif GoUi.config.scale_enabled:
		var gain := GoScale.gain_for(bp, GoUi.is_handheld_platform(), px.x < px.y)
		var factor := GoScale.scale_factor_for(scale, gain)
			# No boundary crossed and the window size unchanged: leave it alone — the font atlas gets re-baked every time.
		if force or changed or px != window.content_scale_size:
			_applying = true
				# Keeping base equal to the window pixels makes the stretch ratio 1, so the shrinking is left to factor alone.
			window.content_scale_size = px
			window.content_scale_factor = factor
			_applying = false

	if resized or force: viewport_resized.emit(window.get_visible_rect().size)
	if changed or force: breakpoint_changed.emit(bp)
	_check_safe_area()
