## Kids skin — the toy box. Everything you press is a jelly candy (`GoStyleBoxJelly`): a chunky outline, a body light
## on top and deeper below, a white shine and a solid lip that sinks when pressed. Parts come in crayon colours, bars
## are jelly, badges are stickers, the joystick is a rainbow with a candy knob — and a window wears a ribbon behind its
## title, a round candy close button, and every button squishes like jelly under a finger.
##
## The engine-drawn controls (buttons, fields, tabs, sliders, panels) get their jelly from the theme
## (`tools/theme_kids.py`); this skin draws the parts gohud draws in code, and the window chrome and press feel
## (`title_plate_box`, `dress_close_button`, `press_feedback`).
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

## The white shine on a candy part (0–1).
const GLOSS := 0.6
## A press: how the button squashes (wide · flat) and how long it takes to squash and to spring back (s).
const SQUISH := Vector2(1.07, 0.9)
const SQUISH_DOWN := 0.06
const SQUISH_BACK := 0.32


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


## Is this the night look? (the sunny crayon turns mint there, as the theme's pills do)
func _night() -> bool:
	return GoUi.color(GoTheme.BACKGROUND).get_luminance() < 0.5


## Makes [param face] a jelly candy: an outline of [param edge] and a lip of [param lip] under it, both in [param ink],
## a two-tone body and a shine. The label moves up by half the lip (the content margins keep their sum, so the part
## keeps its size). [param keep_shadow] keeps the face's own shadow (a floating button).
func _jelly(face: StyleBoxFlat, ink: Color, lip := -1, edge := -1, keep_shadow := false,
		gloss := GLOSS) -> GoStyleBoxJelly:
	var bottom := toy_lip if lip < 0 else lip
	var side := toy_edge if edge < 0 else edge
	var candy := GoStyleBoxJelly.new()
	candy.bg_color = face.bg_color
	candy.border_color = ink
	candy.border_width = side
	candy.lip = bottom
	candy.radius = face.corner_radius_top_left
	candy.shine = gloss
	candy.draw_center = face.draw_center
	if keep_shadow and face.shadow_size > 0:
		candy.shadow_color = face.shadow_color
		candy.shadow_size = face.shadow_size
		candy.shadow_offset = face.shadow_offset
	var before := face.border_width_bottom
	var move := float(bottom - before) * 0.5
	for side_index: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		candy.set_content_margin(side_index, face.get_margin(side_index))
	if candy.content_margin_top >= move and candy.content_margin_bottom >= 0.0:
		candy.content_margin_top -= move
		candy.content_margin_bottom += move
	return candy


## A candy from three colours (a light top, the outline and lip), for the parts built here.
func _candy(top: Color, ink: Color, corner: float, lip := -1, edge := -1, gloss := GLOSS) -> GoStyleBoxJelly:
	var candy := GoStyleBoxJelly.new()
	candy.bg_color = top
	candy.border_color = ink
	candy.radius = corner
	candy.lip = toy_lip if lip < 0 else lip
	candy.border_width = toy_edge if edge < 0 else edge
	candy.shine = gloss
	return candy


# ── Chips, slots, badges ──────────────────────────────────────────────

## A chip is a bubble: a crayon-tinted jelly, a darker outline and a small lip.
## 🛑 Not a full pill radius — the cell audit reads a 999 radius as "the text needs 300dp of room" (the chips failed
##    the layout test on both kids looks). Half a chip's height rounds it just the same.
func chip_box(color: Color) -> StyleBox:
	var face := super(color) as StyleBoxFlat
	if face == null: return super(color)
	face.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(color, 1.0), crayon_tint)
	face.set_corner_radius_all(13)
	return _jelly(face, _darker(Color(color, 1.0), 0.12), 3, -1, false, 0.5)


func filter_chip_box(selected: bool, state: StringName) -> StyleBox:
	var face := super(selected, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	flat.set_corner_radius_all(13)
	var ink := _darker(flat.bg_color, 0.3) if selected else GoUi.color(GoTheme.BORDER)
	var candy := _jelly(flat, Color(ink, 1.0), 3, -1, false, 0.5)
	candy.pressed = state == &"pressed"
	return candy


## A quick slot is a candy block in its own colour; while it cools down it is pressed in.
## 🛑 Built here, not from the base: the base starts from the theme's HUD face, which is a jelly panel in this look.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var solid := Color(accent, 1.0)
	var candy := _candy(GoUi.color(GoTheme.SURFACE).lerp(solid, crayon_tint * (1.5 if lit else 1.0)), _darker(solid, 0.12),
		GoUi.metric(GoTheme.RADIUS_SMALL), toy_lip, -1, 0.7)
	candy.pressed = lit
	candy.sink = maxf(0.0, toy_lip - 2.0)
	candy.set_content_margin_all(0)
	return candy


## A badge is a sticker: a solid crayon face with a rim of the surface colour (built here — see `slot_box`).
func badge_box(ink: Color) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.content_margin_left = badge_pad_x
	face.content_margin_right = badge_pad_x
	face.content_margin_top = badge_pad_y
	face.content_margin_bottom = badge_pad_y
	face.bg_color = Color(ink, 1.0)
	face.border_color = GoUi.color(GoTheme.SURFACE)
	face.set_border_width_all(2)
	face.set_corner_radius_all(FULL_ROUND)
	face.corner_detail = 16
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


## An avatar or icon disc is a round candy, faintly filled with its colour (built here — see `slot_box`).
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var surface := GoUi.color(GoTheme.SURFACE)
	var candy := _candy(surface.lerp(Color(accent, 1.0), clampf(fill_alpha * 1.6, 0.0, 1.0)),
		surface.lerp(Color(accent, 1.0), clampf(edge_alpha + 0.3, 0.0, 1.0)), maxf(1.0, diameter * 0.5 - 1.0), 2, 2, 0.5)
	candy.set_content_margin_all(0)
	return candy


## [param box] as a `StyleBoxFlat` of the same colours, outline, corners and padding — for the parts that are shaped
## as flat cells (segments, the app bar) while the theme's panels are jelly.
func _flat_of(box: StyleBox) -> StyleBoxFlat:
	var flat := box as StyleBoxFlat
	if flat != null: return flat
	flat = StyleBoxFlat.new()
	var candy := box as GoStyleBoxJelly
	if candy != null:
		flat.bg_color = candy.bg_color
		flat.border_color = candy.edge()
		flat.set_border_width_all(int(candy.border_width))
		flat.border_width_bottom = int(candy.border_width + candy.lip)
		flat.set_corner_radius_all(int(minf(candy.radius, float(FULL_ROUND))))
		flat.corner_detail = 8
	elif box != null and &"bg_color" in box:
		flat.bg_color = box.get(&"bg_color")
	if box != null:
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: flat.set_content_margin(side, box.get_margin(side))
	return flat


# ── Panels ────────────────────────────────────────────────────────────

## A panel floating over the game is the theme's jelly panel with a soft shadow under it.
func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var candy := surface_box(variant, accent, alpha) as GoStyleBoxJelly
	if candy == null: return super(variant, accent, alpha)
	candy.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha)
	candy.shadow_size = float_shadow_size
	candy.shadow_offset = Vector2(0, float_shadow_lift)
	if accent.a > 0.0: candy.border_color = _rim(accent)
	return candy


## A notice or a snackbar keeps the jelly panel; its accent rim is solid (a see-through rim shows the game through it).
func notice_box(accent: Color, compact: bool, alpha := -1.0) -> StyleBox:
	var surface := super(accent, compact, alpha)
	var candy := surface as GoStyleBoxJelly
	if candy != null and accent.a > 0.0: candy.border_color = _rim(accent)
	return surface


func tint_notice(box: StyleBox, accent: Color) -> void:
	var candy := box as GoStyleBoxJelly
	if candy != null and accent.a > 0.0:
		candy.border_color = _rim(accent)
		return
	super(box, accent)


## An accent rim on a jelly panel — opaque, half way between the accent and the surface.
func _rim(accent: Color) -> Color:
	return Color(GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 1.0), 0.75), 1.0)


## A choice cell (a choice grid, a card you pick) is a jelly tile; the chosen one sinks with an accent rim.
func choice_box(state: StringName) -> StyleBox:
	var face := super(state)
	if state == &"focus" or not (face is GoStyleBoxJelly): return face
	var candy := face as GoStyleBoxJelly
	candy.radius = GoUi.metric(GoTheme.RADIUS_SMALL)
	if state == &"pressed" or state == &"hover_pressed":
		candy.border_color = GoUi.color(GoTheme.ACCENT)
		candy.border_width = CHOICE_RING
		candy.pressed = true
	elif state == &"hover":
		candy.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	elif state == &"disabled":
		candy.bg_color = Color(candy.bg_color, candy.bg_color.a * 0.5)
		candy.shine = 0.0
	return candy


# ── Bars and loading ──────────────────────────────────────────────────

## A bar's fill is jelly: round, two tones and a shine (the theme's fill is a `GoStyleBoxJelly`; the base tints its
## `bg_color` and the band follows). 🛑 A fill the base outlined because it is too pale for its track (`_edge_fill`)
## keeps that outline.
func progress_fill_box(ink: Color) -> StyleBox:
	var face := super(ink)
	var flat := face as StyleBoxFlat
	if flat == null: return face
	flat.set_corner_radius_all(FULL_ROUND)
	flat.corner_detail = 16
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
	flat.bg_color = GoUi.color(GoTheme.SURFACE_HIGH) if _night() else GoUi.color(GoTheme.SURFACE).lerp(accent, 0.3)
	var pill := _jelly(flat, accent.lerp(GoUi.color(GoTheme.SURFACE), 0.35), 3, 0)
	# 🛑 Half the pill's height, not a 999 radius — the cell audit reads 999 as "the label needs 300dp of room".
	pill.radius = 16.0
	return pill


## The floating action button is the biggest candy on the screen — a lip under it, sunk when pressed.
func fab_box(extent: float, state: StringName) -> StyleBox:
	var face := super(extent, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	var candy := _jelly(flat, _darker(flat.bg_color, 0.38), 5, 2, true)
	candy.pressed = state == &"pressed"
	return candy


## The picked day is a candy on its lip; today keeps its ring, a little thicker.
func date_cell_box(kind: StringName, state: StringName) -> StyleBox:
	var face := super(kind, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	if kind == &"selected":
		var candy := _jelly(flat, _darker(flat.bg_color, 0.35), 3, 0)
		candy.pressed = state == &"pressed"
		return candy
	if kind == &"today":
		flat.set_border_width_all(2)
	return flat


## The app bar is a strip of tape: a thick rim along its bottom edge (a flat strip, square corners — the base's bar
## built from a flat card, since the theme's card is jelly).
func app_bar_box(scrolled: bool) -> StyleBox:
	var flat := _flat_of(surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0))
	flat.set_corner_radius_all(0)
	flat.set_border_width_all(0)
	flat.shadow_size = 0
	if scrolled:
		flat.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha * 0.5)
		flat.shadow_size = maxi(2, roundi(float_shadow_size * 0.5))
		flat.shadow_offset = Vector2(0, 2)
	flat.border_color = GoUi.color(GoTheme.BORDER)
	flat.border_width_bottom = 3
	flat.set_content_margin_all(0)
	return flat


## An alert is a sticker note: a jelly tinted with its own colour, an opaque rim of it and a lip.
func alert_box(ink: Color, alpha := -1.0) -> StyleBox:
	var face := super(ink, alpha)
	var flat := face as StyleBoxFlat
	if flat != null: return _jelly(flat, Color(ink, 0.7), 3, -1, false, 0.45)
	var candy := face as GoStyleBoxJelly
	if candy != null:
		var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_CARD)
		candy.bg_color = Color(GoUi.color(GoTheme.SURFACE).lerp(ink, alert_tint), opacity)
		candy.border_color = _rim(ink)
		candy.lip = 3.0
		candy.band = 0.22
	return face


## One cell of a segmented control: the row sits on one lip; the chosen cell is pressed in. The cells stay flat and
## square inside so the row reads as one block — the base's cell, built from a flat card (the theme's card is jelly).
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var flat := _flat_of(surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0))
	flat.shadow_size = 0
	if state == &"pressed" or state == &"hover_pressed":
		flat.bg_color = GoUi.color(GoTheme.ACCENT)
	elif state == &"hover":
		flat.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	var radius := GoUi.metric(GoTheme.RADIUS_SMALL)
	flat.corner_radius_top_left = radius if index == 0 else 0
	flat.corner_radius_bottom_left = radius if index == 0 else 0
	flat.corner_radius_top_right = radius if index == count - 1 else 0
	flat.corner_radius_bottom_right = radius if index == count - 1 else 0
	var pressed := state == &"pressed" or state == &"hover_pressed"
	flat.border_width_top = toy_edge
	flat.border_width_right = toy_edge
	flat.border_width_left = toy_edge if index == 0 else 0
	flat.border_width_bottom = 2 if pressed else 3
	if pressed: flat.border_color = _darker(flat.bg_color, 0.3)
	return flat


# ── Window chrome and the feel of a press ─────────────────────────────

## A window title sits on a sunny ribbon (mint at night, as the pills are).
func title_plate_box() -> StyleBox:
	var sweet := GoUi.color(GoTheme.SUCCESS_FILL if _night() else GoTheme.WARNING_FILL)
	var ribbon := _candy(sweet.lerp(Color.WHITE, 0.25), _darker(sweet, 0.45), 18.0, 3, 2)
	ribbon.shade_color = sweet
	return ribbon.pad(10.0, 4.0)


## The title's colour on the ribbon — pushed until it reads on the ribbon's light top.
func title_plate_ink() -> Color:
	var plate := title_plate_box() as GoStyleBoxJelly
	return readable_on(GoUi.color(GoTheme.TEXT), plate.bg_color if plate != null else GoUi.color(GoTheme.SURFACE))


## A window's close button is a round candy in the danger crayon with a white cross.
func dress_close_button(button: GoIconButton) -> void:
	var berry := GoUi.color(GoTheme.DANGER_FILL)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var top := berry.lerp(Color.WHITE, 0.32 if state == &"hover" else 0.18)
		if state == &"disabled": top = GoUi.color(GoTheme.SURFACE_SOFT)
		var candy := _candy(top, _darker(berry, 0.42), FULL_ROUND, 3, 2)
		candy.shade_color = berry if state != &"disabled" else Color(0, 0, 0, 0)
		candy.pressed = state == &"pressed" or state == &"hover_pressed"
		candy.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, candy)
	button.icon_tint = Color.WHITE


## A press squishes the part like jelly — wide and flat for a moment, then it springs back. Only `scale` changes
## (around the centre), so the layout and the press area stay put; `reduce_motion` and headless runs skip it (a test
## that measures a part right after tapping it should read its real rectangle).
func press_feedback(control: Control) -> void:
	if GoUi.config.reduce_motion or DisplayServer.get_name() == "headless": return
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	var running: Variant = control.get_meta(&"go_squish", null)
	if running is Tween and (running as Tween).is_valid(): (running as Tween).kill()
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, ^"scale", SQUISH, SQUISH_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, ^"scale", Vector2.ONE, SQUISH_BACK).set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
	control.set_meta(&"go_squish", tween)


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
