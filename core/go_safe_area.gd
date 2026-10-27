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
## 🧪 Under `GoRuntime.simulate()` it is the simulated device's insets instead (a handheld's only; an Android device given
##    only `cutouts` insets each hole's edge by its depth, as Android reports an immersive window).
## 📷 An edge-to-edge HUD asks `obstructions()` instead — the holes, the rounded corners and the home strip themselves.
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
		# An Android device given only its holes reports them as the insets (an immersive window's safe area).
		var holes: Array[Rect2] = []
		holes.assign(device.get("cutouts", []))
		var insets: Vector4 = device.get("insets", hole_insets(px, holes) if str(device.get("platform", "")) == "android" else Vector4.ZERO)
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


# ── 📷 Physical obstructions — for a HUD that runs edge to edge instead of keeping the whole safe area ──────────────
#
# The safe area is a rectangle: on a landscape iPhone it is a 59-pt gutter down BOTH long sides (the island is on one)
# plus the bottom; on an Android phone it is the camera hole's depth down a whole edge. A sheet or a form keeps it (its
# text under the ears is not worth the risk). An in-game HUD wants the glass instead, and to step off only what is
# physically in the way: the camera holes, the rounded corners and (iOS) the home-indicator strip. `obstructions()`
# names them; `corner_shift()` / `corner_keep()` are the corner geometry; `hole_insets()` is the depth of the holes on
# each edge (what Android reports as the safe area of an immersive window).


## The physical obstructions of [param view]'s screen, in its UI units (the same space as `usable_rect`):
## [codeblock]
## {
##     "holes": Array[Rect2],   # camera cutouts — no control or text over them
##     "corner_radius": float,  # the rounded display corners (0: square or unknown)
##     "gesture": Rect2,        # the iOS home-indicator strip along the bottom — no tap target in it; art may run under
##     "screen": Rect2,         # the whole screen, which the corners are measured from
##     "bars": Vector4,         # the safe-area insets that stay whole (left, top, right, bottom) — `bar_insets`
## }
## [/codeblock]
## · Android names its holes (`DisplayServer.get_display_cutouts`) and has no gesture strip in an immersive window; its
##   corner radius is `GoConfig.corner_radius_android` (dp) — Godot does not expose `WindowInsets.getRoundedCorner`.
## · iOS names none (Godot 4.7: `get_display_cutouts` is Android-only), so the holes are derived from the safe-area
##   insets (`ios_holes`): the notch / Dynamic Island centred on each inset edge but the bottom; the bottom inset is the
##   gesture strip; the radius is `GoConfig.corner_radius_ios` (pt; `corner_radius_ios_tablet` past the mobile
##   breakpoint). 🛑 In landscape the insets are symmetric and Godot 4.7 reports no interface orientation
##   (`screen_get_orientation` returns the requested one), so a real iPhone gets the island on BOTH long sides — a band
##   the island's length, not the inset's whole edge. A simulated device names the side (`notch_side`).
## · Under `GoRuntime.simulate()` / `GoScale.simulate()` the device's own keys: `platform` ("android" | "ios"),
##   `cutouts` (Array[Rect2], window pixels), `insets`, `corner_radius` (pixels), `screen_scale` (iOS pixels per point),
##   `notch_side` (`SIDE_LEFT` | `SIDE_RIGHT`), `dpi`.
## Empty (no holes, radius 0, no strip) off handhelds, in a SubViewport and with `GoConfig.respect_safe_area` off.
static func obstructions(view: Viewport) -> Dictionary:
	var holes: Array[Rect2] = []
	var out := {"holes": holes, "corner_radius": 0.0, "gesture": Rect2(), "screen": Rect2(), "bars": Vector4.ZERO}
	if view == null: return out
	var area := view.get_visible_rect()
	out["screen"] = area
	var window := view as Window
	if window == null or not GoUi.config.respect_safe_area: return out
	var device := GoScale.simulated()
	var platform := "ios" if OS.has_feature("ios") else ("android" if OS.has_feature("android") else "")
	var px := Vector2(DisplayServer.screen_get_size())
	var insets := Vector4.ZERO
	var holes_px: Array[Rect2] = []
	var scale := 1.0
	var dpi := float(DisplayServer.screen_get_dpi())
	var side := -1
	var radius_px := -1.0
	var to_units := window.get_final_transform().affine_inverse()
	if not device.is_empty():
		if not GoScale.is_handheld_screen(): return out
		platform = str(device.get("platform", platform))
		px = Vector2(device.get("size", window.size))
		holes_px.assign(device.get("cutouts", []))
		insets = device.get("insets", hole_insets(px, holes_px) if platform == "android" else Vector4.ZERO)
		scale = float(device.get("screen_scale", 1.0))
		dpi = float(device.get("dpi", 0.0))
		side = int(device.get("notch_side", -1))
		radius_px = float(device.get("corner_radius", -1.0))
		if px.x <= 0.0 or px.y <= 0.0: return out
		to_units = Transform2D(0.0, area.size / px, 0.0, area.position)
	else:
		if not GoUi.is_handheld_platform(): return out
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var origin := Vector2(DisplayServer.screen_get_position())
		insets = Vector4(safe.position.x - origin.x, safe.position.y - origin.y,
			origin.x + px.x - safe.end.x, origin.y + px.y - safe.end.y)
		if platform == "android":
			for r: Rect2 in DisplayServer.get_display_cutouts(): holes_px.append(r)
		else:
			scale = DisplayServer.screen_get_scale()
	if radius_px < 0.0 and platform == "ios" and scale > 0.0:
		var phone := GoScale.breakpoint_for_dp(minf(px.x, px.y) / scale) == GoScale.Bp.MOBILE
		radius_px = (GoUi.config.corner_radius_ios if phone else GoUi.config.corner_radius_ios_tablet) * scale
	elif radius_px < 0.0 and platform == "android":
		radius_px = GoUi.config.corner_radius_android * dpi / GoScale.HANDHELD_BASE_DPI
	# What explains each inset: an Android hole; an iPhone's cutout or (landscape) its mirror on the other long side — so
	# every qualifying iOS edge counts, whichever side the island is on.
	var explained := holes_px
	if platform == "ios":
		holes_px = ios_holes(px, insets, scale, side)
		explained = ios_holes(px, insets, scale)
		if insets.w > 0.0: out["gesture"] = to_units * Rect2(0.0, px.y - insets.w, px.x, insets.w)
	for r: Rect2 in holes_px: holes.append(to_units * r)
	var k := to_units.get_scale().abs()
	var per_edge := Vector4(k.x, k.y, k.x, k.y)
	out["bars"] = bar_insets(insets * per_edge, hole_insets(px, explained) * per_edge)
	out["corner_radius"] = maxf(0.0, radius_px) * absf(to_units.get_scale().x)
	return out


## The camera cutouts an iPhone's safe-area insets stand for (pixels of a [param size_px] screen): on each inset edge but
## the bottom one at least as deep as a cutout (`GoConfig.ios_cutout_lengths`), a rect centred along that edge, the
## table's length long and the inset deep. [param scale] = pixels per point; [param side] (`SIDE_LEFT` / `SIDE_RIGHT`,
## -1 unknown) keeps only that long side's in landscape — the island is on one side, the insets on both.
static func ios_holes(size_px: Vector2, insets_px: Vector4, scale: float, side := -1) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if scale <= 0.0: return out
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT]:
		var depth := insets_px.y if edge == SIDE_TOP else (insets_px.x if edge == SIDE_LEFT else insets_px.z)
		if edge != SIDE_TOP and side >= 0 and edge != side: continue
		var length := _cutout_length(depth / scale) * scale
		if length <= 0.0: continue
		if edge == SIDE_TOP: out.append(Rect2((size_px.x - length) * 0.5, 0.0, length, depth))
		else: out.append(Rect2(0.0 if edge == SIDE_LEFT else size_px.x - depth, (size_px.y - length) * 0.5, depth, length))
	return out


static func _cutout_length(depth_pt: float) -> float:
	for row: Vector2 in GoUi.config.ios_cutout_lengths:
		if depth_pt >= row.x: return row.y
	return 0.0


## The safe-area insets an edge-to-edge HUD keeps whole — left, top, right, bottom, in the units of [param insets]: an
## edge whose inset is no deeper than what explains it ([param explained] — the holes' depth on that edge, `hole_insets`)
## + [param tolerance] is only those holes and is released (0); a deeper one is a bar and stays — a status or
## navigation bar (a non-immersive Android window), the iOS home strip (no cutout explains the bottom inset), an iPad's
## status bar. HF-1's rule: the Realme's 29-unit waterdrop gutter is released, a 40-unit bar over a 22-unit hole stays.
static func bar_insets(insets: Vector4, explained: Vector4, tolerance := 1.0) -> Vector4:
	var out := Vector4.ZERO
	for i in 4:
		if insets[i] > explained[i] + tolerance: out[i] = insets[i]
	return out


## How deep the holes reach into each edge of a [param size] screen — left, top, right, bottom (0 where none), each hole
## counted on its nearest edge. What Android reports as the safe-area insets of an immersive window.
static func hole_insets(size: Vector2, holes: Array[Rect2]) -> Vector4:
	var out := Vector4.ZERO
	for h: Rect2 in holes:
		match nearest_edge(h, size):
			SIDE_LEFT: out.x = maxf(out.x, h.end.x)
			SIDE_TOP: out.y = maxf(out.y, h.end.y)
			SIDE_RIGHT: out.z = maxf(out.z, size.x - h.position.x)
			SIDE_BOTTOM: out.w = maxf(out.w, size.y - h.position.y)
	return out


## The edge of a [param size] screen that [param rect] is nearest (`SIDE_LEFT` / `SIDE_TOP` / `SIDE_RIGHT` /
## `SIDE_BOTTOM`; a tie goes to the first in that order).
static func nearest_edge(rect: Rect2, size: Vector2) -> int:
	var gaps: Array[float] = [rect.position.x, rect.position.y, size.x - rect.end.x, size.y - rect.end.y]
	var best := 0
	for i in range(1, 4):
		if gaps[i] < gaps[best]: best = i
	return best    # 0 1 2 3 = SIDE_LEFT SIDE_TOP SIDE_RIGHT SIDE_BOTTOM


## How far [param shape] must move — diagonally, toward the inside of [param screen] — to sit wholly inside the
## screen's rounded corners of [param radius] (zero when it already does). [param circle]: the shape is the circle
## inscribed in the rect (a round button's touch), which needs less. The diagonal is the shortest way out of a corner's
## arc for a shape flush on both edges (0.29 × the radius each way, against the whole radius along one edge).
## [param along] (`Vector2.AXIS_X` / `AXIS_Y`) moves along that axis only — a row whose other edge is its anchor; a shape
## too deep in the corner for that axis alone moves the whole radius-deep step.
static func corner_shift(shape: Rect2, screen: Rect2, radius: float, circle := false, along := -1) -> Vector2:
	var shift := Vector2.ZERO
	if radius <= 0.0: return shift
	var r := minf(shape.size.x, shape.size.y) * 0.5 if circle else 0.0
	var room := radius - r
	if room <= 0.0: return shift
	for corner in 4:
		var inward := Vector2(1.0 if corner in [0, 3] else -1.0, 1.0 if corner < 2 else -1.0)
		var screen_corner := Vector2(screen.position.x if corner in [0, 3] else screen.end.x,
			screen.position.y if corner < 2 else screen.end.y)
		var arc := screen_corner + inward * radius
		# The shape's point deepest into this corner: its rect corner, or its circle's centre (then `room` is what is left).
		var point := shape.get_center() if circle else Vector2(
			shape.position.x if corner in [0, 3] else shape.end.x, shape.position.y if corner < 2 else shape.end.y)
		var u := (arc.x - point.x) * inward.x
		var v := (arc.y - point.y) * inward.y
		if u <= 0.0 or v <= 0.0 or u * u + v * v <= room * room: continue
		if along == Vector2.AXIS_X or along == Vector2.AXIS_Y:
			# One axis: (u − t)² + v² = room² (or u² + (v − t)²) for the smallest t ≥ 0.
			var other := v if along == Vector2.AXIS_X else u
			var own := u if along == Vector2.AXIS_X else v
			var step := own - sqrt(room * room - other * other) if other < room else own
			shift[along] += inward[along] * step
			continue
		# Solve (u − t)² + (v − t)² = room² for the smallest t ≥ 0.
		var disc := 2.0 * room * room - (u - v) * (u - v)
		var t := ((u + v) - sqrt(disc)) * 0.5 if disc >= 0.0 else maxf(u, v)
		shift += inward * t
	return shift


## Rects that keep a floating layout off the rounded corners of [param screen]: at each corner an L of two bars
## [param radius] long and `radius × (1 − 1/√2)` thick. A rect that touches none of them sits inside the corners'
## arcs; it is the rect form of `corner_shift` for layouts that already avoid a list of rects. Empty for radius ≤ 0.
static func corner_keep(screen: Rect2, radius: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if radius <= 0.0: return out
	var thick := radius * (1.0 - sqrt(0.5))
	for corner in 4:
		var x := screen.position.x if corner in [0, 3] else screen.end.x - radius
		var y := screen.position.y if corner < 2 else screen.end.y - radius
		var thin_x := screen.position.x if corner in [0, 3] else screen.end.x - thick
		var thin_y := screen.position.y if corner < 2 else screen.end.y - thick
		out.append(Rect2(x, thin_y, radius, thick))
		out.append(Rect2(thin_x, y, thick, radius))
	return out


func _on_safe_area(_margins: Vector4) -> void:
	_layout()


func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var area := usable_rect(get_viewport())
	position = area.position
	size = area.size
