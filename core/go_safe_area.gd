## 📐 **The safe area** — the rectangle you can actually draw in, clear of the notch, the rounded corners and the gesture bar.
##
## ## Why it exists separately
## `get_visible_rect()` is the whole screen. On a phone the top 40dp of that is covered by the camera cutout.
## Pushing the whole window inward shrinks the background too and leaves black bands, so **the background fills
## the whole screen and only the content stays inside this rectangle.**
##
## ```gdscript
## var area := GoSafeArea.usable_rect(get_viewport())
## card.position = area.position + ...
## ```
##
## 🛑 On desktop it hands the whole screen straight back — there is no such thing as a safe area there.
## 🛑 Turn `GoConfig.respect_safe_area` off and it is the whole screen everywhere.
## 🧪 Under `GoRuntime.simulate()` it is the simulated device's insets instead (a handheld's only).
class_name GoSafeArea
extends Control


func _init() -> void:
	name = "SafeArea"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# 🛑 The safe area itself is **physical direction** — the notch does not move to the other side for Arabic or Urdu.
	#    The left-right direction of the content is each child's own decision.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	get_viewport().size_changed.connect(_layout)
	# A 180° turn or a simulated device moves the safe area with no resize.
	var runtime := GoUi.runtime()
	if runtime != null and runtime.has_signal(&"safe_area_changed"): runtime.connect(&"safe_area_changed", _on_safe_area)
	_layout()


## The rectangle actually usable in this window (units = the UI coordinate space). [param view] is the viewport the
## node is drawn in (`get_viewport()`): a `SubViewport` — a preview, a render-to-texture — is its own whole rect, with
## no safe area (the notch is the screen's, not the texture's). 🛑 Passing `get_window()` from inside a SubViewport
## gave the main window's rect, so a window there sized and centred itself for the wrong screen.
static func usable_rect(view: Viewport) -> Rect2:
	if view == null: return Rect2()
	var area := view.get_visible_rect()
	var window := view as Window
	if window == null: return area
	if not GoUi.config.respect_safe_area: return area
	var device := GoScale.simulated()
	if not device.is_empty():
		if not GoScale.is_handheld_screen(): return area
		var px := Vector2(window.size)
		if device.has("size"): px = Vector2(device["size"])
		var insets: Vector4 = device.get("insets", Vector4.ZERO)
		return inset_rect(area, insets, px)
	if not GoUi.is_handheld_platform(): return area
	return clip_to_safe(area, Rect2(DisplayServer.get_display_safe_area()), window.get_final_transform())


## The safe margins of [param view] — left, top, right, bottom in UI units, what `usable_rect()` keeps off each edge.
static func margins(view: Viewport) -> Vector4:
	if view == null: return Vector4.ZERO
	var area := view.get_visible_rect()
	var safe := usable_rect(view)
	return Vector4(safe.position.x - area.position.x, safe.position.y - area.position.y,
		area.end.x - safe.end.x, area.end.y - safe.end.y)


## `usable_rect()` with the left and right insets capped at [param side_max] units (negative:
## `GoConfig.hud_side_inset_max`; that negative too, no cap) — the rect an edge-hugging HUD keeps to, which
## `GoHudAnchor` uses. The top and bottom insets stay whole.
static func hud_rect(view: Viewport, side_max := -1.0) -> Rect2:
	var cap := side_max if side_max >= 0.0 else GoUi.config.hud_side_inset_max
	var safe := usable_rect(view)
	if cap < 0.0 or view == null: return safe
	var area := view.get_visible_rect()
	var edges := GoScale.cap_sides(margins(view), cap)
	return Rect2(area.position + Vector2(edges.x, edges.y), area.size - Vector2(edges.x + edges.z, edges.y + edges.w))


## `area` (UI units, the whole window) less [param insets_px] — left, top, right, bottom in pixels of a window
## [param window_px] big, each scaled by the window's units per pixel. The safe area a simulated device gives; the
## same numbers as Magnet Mayhem's `UiScale` (`inset × canvas / pixels`).
static func inset_rect(area: Rect2, insets_px: Vector4, window_px: Vector2) -> Rect2:
	if window_px.x <= 0.0 or window_px.y <= 0.0: return area
	var k := area.size / window_px
	var lead := Vector2(maxf(0.0, insets_px.x) * k.x, maxf(0.0, insets_px.y) * k.y)
	var trail := Vector2(maxf(0.0, insets_px.z) * k.x, maxf(0.0, insets_px.w) * k.y)
	var result := Rect2(area.position + lead, area.size - lead - trail)
	return result if result.size.x > 1.0 and result.size.y > 1.0 else area


## `area` (UI units) cut down to the safe area `safe_px` (**screen pixels**). `to_screen` is the window's final
## transform — UI units to screen pixels, the project's stretch and `content_scale_factor` together.
## 🛑 Dividing by `content_scale_factor` alone is right only while the stretch ratio is 1 (GoScale on). Under the plain
##    `canvas_items` stretch the setup guide recommends, a Galaxy A12 (720×1600 on a 390×844 base) got its 45px cutout
##    as 45 units instead of 24, and lost the bottom and right insets outright — the screen's pixels run past the UI's
##    edge, so the intersection never cut them (measured 2026-10-03).
static func clip_to_safe(area: Rect2, safe_px: Rect2, to_screen: Transform2D) -> Rect2:
	if safe_px.size.x <= 0.0 or safe_px.size.y <= 0.0: return area
	if is_zero_approx(to_screen.determinant()): return area
	var result := area.intersection(to_screen.affine_inverse() * safe_px)
	# If the intersection comes out empty (the first frame, before the scale is settled) fall back to the whole screen — never build a zero-sized card.
	return result if result.size.x > 1.0 and result.size.y > 1.0 else area


## The rectangle with the height covered by the virtual keyboard taken off. With no keyboard it is the same as above.
static func usable_rect_with_keyboard(window: Viewport, keyboard_px: int) -> Rect2:
	var area := usable_rect(window)
	if keyboard_px <= 0 or window == null: return area
	var keyboard := px_to_units(window, keyboard_px)
	var bottom := window.get_visible_rect().size.y - keyboard
	area.size.y = maxf(0.0, minf(area.end.y, bottom) - area.position.y)
	return area


## A height in screen pixels (the virtual keyboard's) in this window's UI units — by the same final transform as above.
## Never larger than the pixels: a window drawn below 1:1 (a headless run) keeps the figure as it is.
static func px_to_units(window: Viewport, px: float) -> float:
	if window == null: return px
	return px / maxf(1.0, absf(window.get_final_transform().get_scale().y))


func _on_safe_area(_margins: Vector4) -> void:
	_layout()


func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var area := usable_rect(get_viewport())
	position = area.position
	size = area.size
