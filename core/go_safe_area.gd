## 📐 **The safe area** — the rectangle you can actually draw in, clear of the notch, the rounded corners and the gesture bar.
##
## ## Why it exists separately
## `get_visible_rect()` is the whole screen. On a phone the top 40dp of that is covered by the camera cutout.
## Pushing the whole window inward shrinks the background too and leaves black bands, so **the background fills
## the whole screen and only the content stays inside this rectangle.**
##
## ```gdscript
## var area := GoSafeArea.usable_rect(get_window())
## card.position = area.position + ...
## ```
##
## 🛑 On desktop it hands the whole screen straight back — there is no such thing as a safe area there.
## 🛑 Turn `GoConfig.respect_safe_area` off and it is the whole screen everywhere.
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
	_layout()


## The rectangle actually usable in this window (units = the UI coordinate space).
static func usable_rect(window: Window) -> Rect2:
	if window == null: return Rect2()
	var area := window.get_visible_rect()
	if not GoUi.config.respect_safe_area: return area
	if not GoUi.is_handheld_platform(): return area
	return clip_to_safe(area, Rect2(DisplayServer.get_display_safe_area()), window.get_final_transform())


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
static func usable_rect_with_keyboard(window: Window, keyboard_px: int) -> Rect2:
	var area := usable_rect(window)
	if keyboard_px <= 0 or window == null: return area
	var keyboard := px_to_units(window, keyboard_px)
	var bottom := window.get_visible_rect().size.y - keyboard
	area.size.y = maxf(0.0, minf(area.end.y, bottom) - area.position.y)
	return area


## A height in screen pixels (the virtual keyboard's) in this window's UI units — by the same final transform as above.
## Never larger than the pixels: a window drawn below 1:1 (a headless run) keeps the figure as it is.
static func px_to_units(window: Window, px: float) -> float:
	if window == null: return px
	return px / maxf(1.0, absf(window.get_final_transform().get_scale().y))


func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var area := usable_rect(get_window())
	position = area.position
	size = area.size
