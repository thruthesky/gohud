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
## ## 🖥 Desktop: the viewing distance (opt in — `GoConfig.reference_short_side`)
## Pure dp makes a desktop UI a fixed number of OS points: on a 27" 4K monitor at 100 % that is half the size a 1080p
## monitor shows at the same distance. With a reference short side (1080 for a 1920×1080 design) a desktop window taller
## than it draws the same canvas larger — the UI keeps its share of the screen, the OS scale stays a floor and the
## breakpoint stays the OS-dp one. Handhelds never take this term: their dp is already the physical size in the hand.
## The whole decision is one function, `curve()`, and `GoRuntime` and any app that owns its own scale call it.
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

## The display servers (`DisplayServer.get_name()`) whose `screen_get_scale()` is the OS display scale of a desktop window.
## Everywhere else the engine returns a constant 1.0 (Windows, X11 — it is not implemented there), so the scale is read
## from the dpi instead (`display_scale` with a raw scale of 0): Windows reports its effective dpi, 96 × the scale the user
## picked. Android and iOS are left out on purpose — there it is no UI scale (a phone at density 300 reports 0.90), and a
## handheld is sized by its dpi anyway.
const SCALE_REPORTING_SERVERS: Array[String] = ["macOS", "Wayland", "web"]

## The device `GoRuntime.simulate()` stands in (empty: the real one).
static var _device: Dictionary = {}
## How many times `simulate()` has run — a scale owner compares one int per frame to notice a new simulated device.
static var _serial := 0


# ── The device — real, or simulated for tests and screenshots ──

## 🧪 Stands [param device] in for the real one: `dpi` (float), `insets` (Vector4 — the safe area's left, top, right
## and bottom insets in window pixels), `handheld` (bool; the game's `mobile` is read too) and `size` (Vector2i, the
## window in pixels). A key left out reads the real device (no `insets`: none). Empty: the real device again.
## The physical obstructions (`GoSafeArea.obstructions`) read `platform` ("android" | "ios"), `cutouts` (Array[Rect2],
## window pixels — an Android device given only these gets them as its insets too), `corner_radius` (pixels; left out:
## the platform's `GoConfig` default), `screen_scale` (pixels per point: iOS's UIKit scale, and on a desktop the OS
## display scale — 2.0 for "200 %" or a retina screen) and `notch_side` (`SIDE_LEFT` | `SIDE_RIGHT` — which long side a
## landscape iPhone's island is on).
## The scale curve (`device_inputs`, `curve`) reads `size`, `dpi`, `handheld` and `screen_scale`; a simulated window
## stands for its whole screen. A 4K desktop monitor at 200 %:
## `{"size": Vector2i(3840, 2160), "handheld": false, "screen_scale": 2.0}`.
## 🛑 This only stores it — `GoRuntime.simulate()` also resizes the window and re-applies the scale.
static func simulate(device: Dictionary) -> void:
	_device = device.duplicate()
	_serial += 1


## The simulated device (empty when it is the real one).
static func simulated() -> Dictionary:
	return _device


## Bumped by every `simulate()` call: a scale owner that polls compares this one int instead of the dictionary.
static func simulation_serial() -> int:
	return _serial


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
## 🛑 On desktop it is the other way round: `screen_get_scale()` is accurate where the engine implements it (macOS
##    retina 2.0, Wayland, the web — `SCALE_REPORTING_SERVERS`). On Windows and X11 the engine returns a constant 1.0, so
##    a caller passes [param raw_scale] through `reported_scale()` first: 0 there, and the scale comes from the dpi (Windows'
##    effective dpi is 96 × the OS scale).
## [param native] (an Android or iOS app) is a handheld whatever its diagonal — a 14.6" Android tablet is sized by its
## dpi too, never by the engine's Android `screen_get_scale()`.
static func display_scale(raw_scale: float, dpi: int, screen_px := Vector2i.ZERO, native := false) -> float:
	if native or is_handheld_size(screen_px, dpi): return maxf(1.0, float(dpi) / HANDHELD_BASE_DPI)
	if raw_scale > 0.0: return raw_scale
	if dpi > 0: return maxf(1.0, float(dpi) / DESKTOP_BASE_DPI)
	return 1.0


## [param raw_scale] (`screen_get_scale()`) where [param server] (`DisplayServer.get_name()`) reports the OS scale
## (`SCALE_REPORTING_SERVERS`), else 0 — "unknown, read the dpi" for `display_scale`.
static func reported_scale(server: String, raw_scale: float) -> float:
	return raw_scale if server in SCALE_REPORTING_SERVERS else 0.0


# ── The scale curve — one function from what the device reports to the content scale factor ──

## 🧪 What `curve()` reads, from the simulated device where it names a value (`simulate`), else the real one:
## `window` (Vector2i, px — a simulated `size`, else [param window_px]), `screen` (Vector2i, px — a simulated window stands
## for its whole screen), `dpi` (float), `raw_scale` (float — the OS scale as reported: a simulated `screen_scale`, else
## `reported_scale()` of the engine's; 0 = not reported, read the dpi), `server` (`DisplayServer.get_name()`, for logs) and
## `native` (bool — a simulated `handheld`/`mobile`, else an Android or iOS app), and `desktop` (bool — an explicit
## desktop platform/device, whose effective OS DPI must never be mistaken for physical panel DPI).
## [param window_px] is the real window (the caller knows its fallback for a run with no window).
static func device_inputs(window_px: Vector2i) -> Dictionary:
	var d := _device
	var window: Vector2i = d.get("size", window_px)
	var inputs := {
		"window": window,
		"screen": window if d.has("size") else DisplayServer.screen_get_size(),
		"dpi": float(d.get("dpi", DisplayServer.screen_get_dpi())),
		"raw_scale": reported_scale(DisplayServer.get_name(), DisplayServer.screen_get_scale()),
		"server": DisplayServer.get_name(),
		"native": GoUi.is_handheld_platform(),
		"desktop": OS.has_feature("pc"),
	}
	if d.has("screen_scale"):
		inputs["raw_scale"] = float(d["screen_scale"])
	elif d.has("dpi"):
		# A simulated dpi with no scale is a Windows-style report: the scale is read from the dpi.
		inputs["raw_scale"] = 0.0
	if d.has("handheld"):
		inputs["native"] = bool(d["handheld"])
		inputs["desktop"] = not bool(d["handheld"])
	elif d.has("mobile"):
		inputs["native"] = bool(d["mobile"])
		inputs["desktop"] = not bool(d["mobile"])
	return inputs


## 🖥 The viewing-distance term of a desktop window: its short side over `GoConfig.reference_short_side` (px), never below
## 1 and never above `GoConfig.max_window_scale`. 1 when the reference is 0 (off — pure dp, the default).
##
## Unity's CanvasScaler "Scale With Screen Size" (match the short side), Unreal's DPI curve on the short side: a window
## twice the reference's height shows the UI twice as many pixels tall, so the UI keeps its share of the screen — a 27"
## 4K monitor at arm's length shows the HUD the size a 1080p one does, instead of half of it.
static func window_scale_for(short_px: float) -> float:
	var settings := GoUi.config
	if settings.reference_short_side <= 0.0 or short_px <= 0.0: return 1.0
	return clampf(short_px / settings.reference_short_side, 1.0, maxf(1.0, settings.max_window_scale))


## 📏 **The scale curve** — the whole decision, from [param inputs] (`device_inputs()`: `window`, `screen`, `dpi`,
## `raw_scale` — the REPORTED OS scale, 0 when the platform reports none — `native`, and optionally `desktop`) to the
## content scale factor. Returns `os_scale` (px per dp), `short_dp`, `bp`,
## `handheld`, `gain`, `window_scale`, `user_scale`, `factor` (`Window.content_scale_factor`, with `content_scale_size` =
## the window), `logical` (Vector2, the canvas in units), `dp_per_unit` (= factor ÷ os_scale) and `clamp` ("" or which
## limit set the factor: "max_window", "min_canvas", "dp_floor").
##
##   handheld (native, or unknown device under 13")  factor = dpi/160 × gain × user        — dp: the size in the hand
##   desktop / laptop / TV                            factor = max(OS scale, window short side ÷ reference) × gain × user
##
## · The breakpoint is decided in **OS dp** (the window's short side ÷ the OS scale) before the viewing-distance term, so a
##   bigger monitor never changes the layout class — only how large the same canvas is drawn.
## · The OS scale is a floor, not a multiplier: a user who picked 200 % on a 4K screen gets at least the size they asked
##   for, and the window term gets them at least the reference look.
## · `GoConfig.user_scale` (the player's UI size) multiplies the result, inside the same limits.
## · Limits, in order: the canvas short side never below `GoConfig.min_canvas_short` units (the narrowest layout the app
##   supports); then one unit never below one OS dp (`gain × user ≥ 1` — a 48-unit button stays a 48 dp touch target),
##   which wins over the first.
static func curve(inputs: Dictionary) -> Dictionary:
	var settings := GoUi.config
	var window: Vector2i = inputs.get("window", Vector2i.ZERO)
	var screen: Vector2i = inputs.get("screen", window)
	var dpi := roundi(float(inputs.get("dpi", 0.0)))
	var native := bool(inputs.get("native", false))
	var raw := float(inputs.get("raw_scale", 0.0))
	# Windows' dpi is effective OS DPI, not panel ppi: a 15.6-inch laptop at 200% can look <13 inches by this math.
	# Explicit desktop identity wins over the diagonal heuristic; unknown devices retain the historical fallback.
	var desktop := bool(inputs.get("desktop", false)) and not native
	var density_screen := Vector2i.ZERO if desktop else screen
	var handheld := native or (not desktop and is_handheld_size(screen, dpi))
	var os_scale := display_scale(raw, dpi, density_screen, native)
	var short_px := float(maxi(1, mini(window.x, window.y)))
	var short_dp := short_px / os_scale
	var bp := breakpoint_for_dp(short_dp)
	var gain := gain_for(bp, native, window.x < window.y)
	var user := maxf(0.01, settings.user_scale)
	var window_scale := 1.0 if handheld else window_scale_for(short_px)
	var limit := ""
	if not handheld and settings.reference_short_side > 0.0 \
			and short_px / settings.reference_short_side > maxf(1.0, settings.max_window_scale):
		limit = "max_window"
	var factor := maxf(os_scale, window_scale) * gain * user
	if settings.min_canvas_short > 0.0 and short_px / factor < settings.min_canvas_short:
		factor = short_px / settings.min_canvas_short
		limit = "min_canvas"
	if factor < os_scale:
		factor = os_scale
		limit = "dp_floor"
	return {"os_scale": os_scale, "short_dp": short_dp, "bp": bp, "handheld": handheld, "gain": gain,
		"window_scale": window_scale, "user_scale": user, "factor": factor, "logical": Vector2(window) / factor,
		"dp_per_unit": factor / os_scale, "clamp": limit}


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
