## 📏 A **1 unit = 1dp** coordinate space and breakpoints. The narrower the screen's *short side*, the larger the UI is drawn.
##
## ## What it does
## ① It measures the screen's **short side in dp** to settle the breakpoint (mobile·tablet·desktop),
## ② lines the UI coordinate space up 1:1 with the **OS logical pixel (dp)**, and
## ③ multiplies in a little readability gain the narrower the screen is.
##
## So the numbers written into scenes and themes **are dp** — the recommended figures from Material, Apple HIG
## and the web can be used without converting. A body size of 16 shows as 17.6sp on a phone.
##
## ## 🛑 It is off by default
## This changes the window's `content_scale_factor` — it affects the coordinate space of the whole project.
## Switched on silently in someone else's project it throws their entire existing layout off. Whoever turns
## `GoConfig.scale_enabled` on decides. **Left off, the breakpoint decision and the pure functions below still work.**
##
## ## 🛑 What it does not do
## - It does not make type **proportional** to the screen size. Things like `font_size = base * (width / 1920)`
##   make the type smaller the narrower the screen gets, until it cannot be read.
## - It does not decide **in window pixels**. A phone's actual pixels run 1080~1440, so measured in pixels every
##   phone is judged a "desktop". It has to be measured in dp.
## - 3D is unaffected (the `canvas_items` stretch changes 2D only).
class_name GoScale
extends RefCounted

enum Bp { MOBILE, TABLET, DESKTOP }

## How `GoConfig.scale_enabled` sizes the UI. `DP`: 1 unit = 1 dp (with the readability gain), the coordinate space
## follows the window. `PER_INCH`: the project's base size stays (`canvas_items` stretch) and a handheld shrinks it to
## about `GoConfig.per_inch_units` units per physical inch, never below `GoConfig.per_inch_min_height` units tall —
## a fixed-layout game HUD that must look the same size in the hand on every phone.
enum Profile { DP, PER_INCH }

## Anything smaller than this diagonal in inches counts as **a handheld device**, because the base dpi of a logical pixel differs.
const HANDHELD_MAX_INCHES := 13.0

## The base dpi of a logical pixel — the Android dp (160) convention for handhelds, the CSS px (96) one for desktops.
## They differ because the viewing distance differs, and they cannot be merged into one.
const HANDHELD_BASE_DPI := 160.0
const DESKTOP_BASE_DPI := 96.0

## The device `GoRuntime.simulate()` stands in (empty: the real one).
static var _device: Dictionary = {}


# ── The device — real, or simulated for tests and screenshots ──

## 🧪 Stands [param device] in for the real one: `dpi` (float), `insets` (Vector4 — the safe area's left, top, right
## and bottom insets in window pixels), `handheld` (bool; the game's `mobile` is read too) and `size` (Vector2i, the
## window in pixels). A key left out reads the real device (no `insets`: none). Empty: the real device again.
## 🛑 This only stores it — `GoRuntime.simulate()` also resizes the window and re-applies the scale.
static func simulate(device: Dictionary) -> void:
	_device = device.duplicate()


## The simulated device (empty when it is the real one).
static func simulated() -> Dictionary:
	return _device


## Whether the screen is sized as a handheld's (`PER_INCH`) and keeps a safe area: a simulated device's `handheld`,
## else the Android or iOS app — and with `GoConfig.handheld_browsers` a phone or tablet browser.
static func is_handheld_screen() -> bool:
	if _device.has("handheld"): return bool(_device["handheld"])
	if _device.has("mobile"): return bool(_device["mobile"])
	return handheld_from(Callable(OS, &"has_feature"), GoUi.config.handheld_browsers)


## The rule of `is_handheld_screen()` over [param has_feature] (`(String) -> bool`, `OS.has_feature` or a stand-in):
## Android or iOS, and with [param browsers] `web_android` or `web_ios`.
static func handheld_from(has_feature: Callable, browsers := false) -> bool:
	if bool(has_feature.call("android")) or bool(has_feature.call("ios")): return true
	return browsers and (bool(has_feature.call("web_android")) or bool(has_feature.call("web_ios")))


## The screen's physical dpi for `PER_INCH`: a simulated device's `dpi`, else the screen's (a browser's rescaled by
## `web_dpi()`), and `GoConfig.fallback_dpi` when the screen reports none.
static func screen_dpi() -> float:
	if _device.has("dpi"): return float(_device["dpi"])
	return dpi_from(float(DisplayServer.screen_get_dpi()), OS.has_feature("web"), GoUi.config.fallback_dpi)


## The rule of `screen_dpi()` over a [param reported] dpi: [param fallback] when it is 0 or less, else on the
## [param web] rescaled by `web_dpi()`.
static func dpi_from(reported: float, web: bool, fallback := 0.0) -> float:
	if reported <= 0.0: return fallback
	return web_dpi(reported) if web else reported


## Short side in dp → breakpoint.
static func breakpoint_for_dp(dp: float) -> Bp:
	var settings := GoUi.config
	if dp <= settings.mobile_max_dp: return Bp.MOBILE
	if dp <= settings.tablet_max_dp: return Bp.TABLET
	return Bp.DESKTOP


## The readability gain of a breakpoint.
##
## `portrait` is whether the screen is portrait — a desktop window narrowed to phone proportions does not get the
## desktop enlargement. That would wrap the top bar and make a narrow screen narrower still.
static func gain_for(bp: Bp, handheld: bool, portrait := false) -> float:
	var settings := GoUi.config
	var base := settings.read_gain_desktop
	match bp:
		Bp.MOBILE: base = settings.read_gain_mobile
		Bp.TABLET: base = settings.read_gain_tablet
	var phone_layout := bp == Bp.MOBILE and portrait
	return base * (1.0 if handheld or phone_layout else settings.desktop_ui_gain)


## The maximum form width of a breakpoint (dp). 0 is no limit.
static func form_width_for(bp: Bp) -> int:
	var settings := GoUi.config
	match bp:
		Bp.MOBILE: return settings.form_max_width_mobile
		Bp.TABLET: return settings.form_max_width_tablet
		_: return settings.form_max_width_desktop


# ── Pure functions — kept static so the checks can verify the same formulas with no window ──

## Is the screen a handheld size — judged by the diagonal in inches. `screen_px` is **the whole screen**, not the window.
static func is_handheld_size(screen_px: Vector2i, dpi: int) -> bool:
	if dpi <= 0 or screen_px.x <= 0 or screen_px.y <= 0: return false
	var diagonal := sqrt(float(screen_px.x) ** 2 + float(screen_px.y) ** 2)
	return diagonal / float(dpi) < HANDHELD_MAX_INCHES


## The OS display scale — physical pixels divided by logical pixels (the web's `devicePixelRatio` slot).
##
## 🛑 **Do not use `screen_get_scale()` on Android** — it is not a UI scale. The engine's Android implementation
##    picks **the smaller** of "the largest supportable scale" and the screen density, so a phone at density 300
##    reports 0.90 (expected 1.875). Use that value and a 384dp phone is judged an 800dp tablet, shrinking body
##    text down to 8sp. So handhelds are computed **from DPI alone**.
##
## 🛑 On desktop it is the other way round: `screen_get_scale()` is accurate (macOS retina 2.0). Windows·X11 have
##    it unimplemented and return 0, and only then does it fall back to DPI.
static func display_scale(raw_scale: float, dpi: int, screen_px := Vector2i.ZERO) -> float:
	if is_handheld_size(screen_px, dpi): return maxf(1.0, float(dpi) / HANDHELD_BASE_DPI)
	if raw_scale > 0.0: return raw_scale
	if dpi > 0: return maxf(1.0, float(dpi) / DESKTOP_BASE_DPI)
	return 1.0


## The scale that lines the UI coordinate space up with dp. Feed it straight into `Window.content_scale_factor`.
static func scale_factor_for(display_scale_value: float, gain: float) -> float:
	return maxf(0.01, display_scale_value * gain)


## How many units the logical viewport becomes at that scale — used by the checks to verify with no window.
static func logical_size_for(window_px: Vector2i, display_scale_value: float, gain: float) -> Vector2:
	var factor := scale_factor_for(display_scale_value, gain)
	return Vector2(float(window_px.x) / factor, float(window_px.y) / factor)


## The breakpoint name — for logs and check output.
static func breakpoint_name(bp: Bp) -> String:
	return ["MOBILE", "TABLET", "DESKTOP"][int(bp)]


## `PER_INCH`: the `content_scale_factor` for a [param window_px] window at [param dpi] over a project base size of
## [param base] (`canvas_items` stretch, `expand` aspect). The canvas is about [param units_per_inch] units per inch
## (160 ≈ one iOS point), clamped to [[param min_height], the canvas height at factor 1]; never below 1. Off a
## [param handheld] it is 1.
static func per_inch_factor(window_px: Vector2, dpi: float, base: Vector2, units_per_inch := 160.0,
		min_height := 440.0, handheld := true) -> float:
	if not handheld or window_px.x <= 0.0 or window_px.y <= 0.0 or dpi <= 0.0: return 1.0
	var tall := base.y * maxf(1.0, (base.x / base.y) / (window_px.x / window_px.y))
	# A base shorter than min_height would make the clamp's bounds cross and return min_height: cap the floor at tall.
	return tall / clampf(window_px.y / dpi * units_per_inch, minf(min_height, tall), tall)


## `PER_INCH`: the canvas size (units) a [param window_px] window shows at [param factor] over [param base].
static func per_inch_canvas(window_px: Vector2, base: Vector2, factor: float) -> Vector2:
	return window_px / (minf(window_px.x / base.x, window_px.y / base.y) * factor)


## A phone browser's physical dpi from Godot's web dpi (devicePixelRatio × 96, CSS's 96 px per inch).
static func web_dpi(reported: float, css_px_per_inch := 160.0) -> float:
	return reported * css_px_per_inch / 96.0


## Safe-area margins (left, top, right, bottom) with the sides capped at [param side_max] — for a HUD that hugs the
## edges, where a landscape notch's whole inset would push it too far in.
static func cap_sides(margins: Vector4, side_max: float) -> Vector4:
	return Vector4(minf(margins.x, side_max), margins.y, minf(margins.z, side_max), margins.w)
