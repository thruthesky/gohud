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

## Anything smaller than this diagonal in inches counts as **a handheld device**, because the base dpi of a logical pixel differs.
const HANDHELD_MAX_INCHES := 13.0

## The base dpi of a logical pixel — the Android dp (160) convention for handhelds, the CSS px (96) one for desktops.
## They differ because the viewing distance differs, and they cannot be merged into one.
const HANDHELD_BASE_DPI := 160.0
const DESKTOP_BASE_DPI := 96.0


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
