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
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0: return area
	# The safe area arrives in **physical pixels** — bring it down to the UI coordinate space by dividing by the stretch ratio.
	var factor := maxf(1.0, window.content_scale_factor)
	var scaled := Rect2(Vector2(safe.position) / factor, Vector2(safe.size) / factor)
	var result := area.intersection(scaled)
	# If the intersection comes out empty (the first frame, before the scale is settled) fall back to the whole screen — never build a zero-sized card.
	return result if result.size.x > 1.0 and result.size.y > 1.0 else area


## The rectangle with the height covered by the virtual keyboard taken off. With no keyboard it is the same as above.
static func usable_rect_with_keyboard(window: Window, keyboard_px: int) -> Rect2:
	var area := usable_rect(window)
	if keyboard_px <= 0 or window == null: return area
	var keyboard := float(keyboard_px) / maxf(1.0, window.content_scale_factor)
	var bottom := window.get_visible_rect().size.y - keyboard
	area.size.y = maxf(0.0, minf(area.end.y, bottom) - area.position.y)
	return area


func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var area := usable_rect(get_window())
	position = area.position
	size = area.size
