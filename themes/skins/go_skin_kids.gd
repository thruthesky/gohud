## Kids skin — the toy box. Everything you press sits on a solid lip and sinks when pressed, parts come in crayon
## colours, bars carry a jelly shine, badges are stickers, and the joystick is a rainbow with a candy knob.
##
## The engine-drawn controls (buttons, fields, tabs, sliders, panels) get their toy shapes from the theme
## (`tools/theme_kids.py`); this skin draws the parts gohud draws in code. Made for `themes/palettes/kids_*.json`.
##
## 🛑 Sizes do not change: a lip lives inside the part's rectangle and the content margins keep their sum — a host
##    that pins its sizes (laryen3d's SSOT §9) measures the same parts. Text colours are still pushed until they read
##    on the face actually painted (`chip_ink`, `slot_ink`, `nav_ink` read these boxes).
@tool
class_name GoSkinKids
extends GoSkin

@export_group("Kids dials")
## The outline of a toy part (dp).
@export var toy_edge := 2
## The lip under a toy part you press (dp) — chips, slots, the FAB, the navigation pill, alerts.
@export var toy_lip := 4
## How much crayon colour fills a slot or a chip face (0–1) — the rest is the surface colour.
@export var crayon_tint := 0.28
@export_group("")


## The crayon box — the theme's bright fill colours, in the order a row of parts takes them.
func crayons() -> Array[Color]:
	var out: Array[Color] = []
	for token in [GoTheme.ACCENT_FILL, GoTheme.DANGER_FILL, GoTheme.WARNING_FILL, GoTheme.SUCCESS_FILL,
			GoTheme.INFO_FILL]:
		out.append(GoUi.color(token))
	return out


## A chart's slices take the crayons, not the darker text colours of the status tokens.
func chart_colors() -> Array[Color]:
	return crayons()


## [param c] towards black by [param t], keeping its alpha — the lip under a face.
func _darker(c: Color, t := 0.3) -> Color:
	return Color(c.lerp(Color.BLACK, t), c.a)


## Makes [param face] a toy part: an outline of [param edge] and a lip of [param lip] under it, both in [param ink].
## The label moves up by half the lip (the content margins keep their sum, so the part keeps its size).
func _toy(face: StyleBoxFlat, ink: Color, lip := -1, edge := -1, keep_shadow := false) -> StyleBoxFlat:
	var bottom := toy_lip if lip < 0 else lip
	var side := toy_edge if edge < 0 else edge
	face.border_color = ink
	face.border_width_left = side
	face.border_width_top = side
	face.border_width_right = side
	var before := face.border_width_bottom
	face.border_width_bottom = bottom
	if not keep_shadow: face.shadow_size = 0
	var move := float(bottom - before) * 0.5
	if face.content_margin_top >= move and face.content_margin_bottom >= 0.0:
		face.content_margin_top -= move
		face.content_margin_bottom += move
	return face


func _round(face: StyleBoxFlat) -> void:
	face.set_corner_radius_all(FULL_ROUND)
	face.corner_detail = 16


# ── Chips, slots, badges ──────────────────────────────────────────────

## A chip is a bubble: a crayon-tinted face, a darker outline and a small lip.
func chip_box(color: Color) -> StyleBox:
	var face := super(color) as StyleBoxFlat
	if face == null: return super(color)
	face.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(color, 1.0), crayon_tint)
	_round(face)
	_toy(face, _darker(Color(color, 1.0), 0.12), 3)
	return face


func filter_chip_box(selected: bool, state: StringName) -> StyleBox:
	var face := super(selected, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	_round(flat)
	var ink := _darker(flat.bg_color, 0.3) if selected else GoUi.color(GoTheme.BORDER)
	_toy(flat, Color(ink, 1.0), 2 if state == &"pressed" else 3)
	return flat


## A quick slot is a candy block in its own colour; while it cools down it is pressed in.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var face := super(accent, lit) as StyleBoxFlat
	if face == null: return super(accent, lit)
	var solid := Color(accent, 1.0)
	face.bg_color = GoUi.color(GoTheme.SURFACE).lerp(solid, crayon_tint * (1.5 if lit else 1.0))
	_toy(face, _darker(solid, 0.12), 2 if lit else toy_lip)
	face.set_content_margin_all(0)
	return face


## A badge is a sticker: a solid crayon face with a rim of the surface colour.
func badge_box(ink: Color) -> StyleBox:
	var face := super(ink) as StyleBoxFlat
	if face == null: return super(ink)
	face.bg_color = Color(ink, 1.0)
	face.border_color = GoUi.color(GoTheme.SURFACE)
	face.set_border_width_all(2)
	_round(face)
	return face


## A section heading is underlined in sunshine. 🛑 Not a mark on one side: in a right-to-left language the text moves to
## the other end and the mark would be left behind; a line under the whole heading reads the same both ways.
func section_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.draw_center = false
	face.border_color = GoUi.color(GoTheme.WARNING_FILL)
	face.border_width_bottom = 3
	face.set_corner_radius_all(2)
	face.content_margin_bottom = 5
	return section_rhythm(face)


# ── Bars and loading ──────────────────────────────────────────────────

## A bar's fill is jelly: round, with a light shine along its top. 🛑 A fill the base outlined because it is too pale
## for its track (`_edge_fill`) keeps that outline — the shine would take the edge that makes it visible.
func progress_fill_box(ink: Color) -> StyleBox:
	var face := super(ink)
	var flat := face as StyleBoxFlat
	if flat == null: return face
	_round(flat)
	if flat.border_width_left == 0 and flat.border_width_top == 0 and flat.border_width_right == 0 \
			and flat.border_width_bottom == 0:
		flat.border_color = Color(ink, 1.0).lerp(Color.WHITE, 0.55)
		flat.border_width_top = 2
	return flat


## The loading shape in the accent on a sunny disc.
func loading_colors(contained: bool) -> Array[Color]:
	var accent := GoUi.color(GoTheme.ACCENT)
	if not contained: return [accent, Color.TRANSPARENT]
	return [accent, Color(GoUi.color(GoTheme.WARNING_FILL), 0.35)]


# ── App parts ─────────────────────────────────────────────────────────

## The navigation pill of the chosen destination sits on a lip.
func nav_indicator_box(selected: bool, state: StringName) -> StyleBox:
	var face := super(selected, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus" or not selected: return face
	var accent := GoUi.color(GoTheme.ACCENT)
	# 🛑 At night a sunny accent mixed into the navy surface turns brown — the pill takes the blue cell colour there.
	var night := GoUi.color(GoTheme.BACKGROUND).get_luminance() < 0.5
	flat.bg_color = GoUi.color(GoTheme.SURFACE_HIGH) if night else GoUi.color(GoTheme.SURFACE).lerp(accent, 0.3)
	_toy(flat, accent.lerp(GoUi.color(GoTheme.SURFACE), 0.35), 3, 0)
	return flat


## The floating action button is the biggest candy on the screen — a lip under it, sunk when pressed.
func fab_box(extent: float, state: StringName) -> StyleBox:
	var face := super(extent, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	_toy(flat, _darker(flat.bg_color, 0.38), 2 if state == &"pressed" else 5, 2, true)
	return flat


## The picked day is a candy on its lip; today keeps its ring, a little thicker.
func date_cell_box(kind: StringName, state: StringName) -> StyleBox:
	var face := super(kind, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	if kind == &"selected":
		_toy(flat, _darker(flat.bg_color, 0.35), 2 if state == &"pressed" else 3, 0)
	elif kind == &"today":
		flat.set_border_width_all(2)
	return flat


## The app bar is a strip of tape: a thick rim along its bottom edge.
func app_bar_box(scrolled: bool) -> StyleBox:
	var face := super(scrolled)
	var flat := face as StyleBoxFlat
	if flat == null: return face
	flat.border_color = GoUi.color(GoTheme.BORDER)
	flat.border_width_bottom = 3
	return flat


## An alert is a sticker note in its own colour.
func alert_box(ink: Color, alpha := -1.0) -> StyleBox:
	var face := super(ink, alpha)
	var flat := face as StyleBoxFlat
	if flat == null: return face
	_toy(flat, Color(ink, 0.7), 3)
	return flat


## One cell of a segmented control: the row sits on one lip; the chosen cell is pressed in.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var face := super(index, count, state)
	var flat := face as StyleBoxFlat
	if flat == null: return face
	var pressed := state == &"pressed" or state == &"hover_pressed"
	flat.border_width_top = toy_edge
	flat.border_width_right = toy_edge
	flat.border_width_left = toy_edge if index == 0 else 0
	flat.border_width_bottom = 2 if pressed else 3
	if pressed: flat.border_color = _darker(flat.bg_color, 0.3)
	return flat


# ── Direct drawing ────────────────────────────────────────────────────

## The joystick: a rainbow rim (one crayon per arc) and a candy knob on its lip with a shine.
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	canvas.draw_circle(center, radius, Color(base, joystick_base_alpha))
	var colours := crayons()
	var parts := colours.size() * 2
	var width := maxf(2.0, joystick_ring_width * 2.0)
	var strength := 0.95 if active else 0.75
	for index in parts:
		var start := TAU * float(index) / float(parts) - PI * 0.5
		canvas.draw_arc(center, radius - width * 0.5, start + 0.07, start + TAU / float(parts) - 0.07, 10,
			Color(colours[index % colours.size()], strength), width, true)
	var solid := Color(ink, 1.0)
	canvas.draw_circle(knob + Vector2(0, knob_radius * 0.14), knob_radius, Color(_darker(solid, 0.35), strength))
	canvas.draw_circle(knob, knob_radius * 0.92, Color(solid, strength))
	canvas.draw_circle(knob + Vector2(-knob_radius * 0.32, -knob_radius * 0.36), knob_radius * 0.24,
		Color(1, 1, 1, 0.6 if active else 0.45))
