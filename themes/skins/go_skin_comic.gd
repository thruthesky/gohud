## Comic skin — the comic page. Every part is inked: a bold outline in the theme's `border` colour around the surface
## colour, and a hard, faint shadow dropped down and to the right of what stands off the page (`GoStyleBoxComic`).
## Chips are speech bubbles, a quick slot lights its ink in its colour while it cools down, a window's title sits in a
## yellow caption box, its close button is an inked disc, and the joystick is a ring of ink with an inked knob.
##
## The engine-drawn controls (buttons, fields, tabs, sliders, panels) get their ink from the theme
## (`tools/theme_comic.py`); this skin draws the parts gohud draws in code, and the window chrome.
##
## 🔑 The outline and the shadow are **not decided here**: every face this skin makes leaves them to
##    `GoConfig.comic_border_width`, `comic_shadow_size` and `comic_shadow`, so one setting restyles every part,
##    and `GoStyle.comic_shadow(node, on)` turns one widget's shadow on or off.
## 🛑 Sizes do not change: the outline is inside a part and the shadow outside it, and the padding is the base skin's.
##    Text colours are still pushed until they read on the face actually painted (`chip_ink`, `slot_ink`, `nav_ink`).
@tool
class_name GoSkinComic
extends GoSkin

@export_group("Comic dials")
## How much of its own colour fills a chip, a quick slot or a chosen pill (0–1) — the rest is the surface colour.
@export var comic_tint := 0.22
@export_group("")

## A small part takes this much of the outline and the shadow (a list row, a chip, a badge).
const SMALL := 0.67
## A panel floating over the game drops a deeper shadow.
const FLOAT_DROP := 1.5


## The ink — the theme's border colour, solid.
func ink() -> Color:
	return Color(GoUi.color(GoTheme.BORDER), 1.0)


## How faint a shadow is on a dark page, where it is drawn in the ink (`tools/theme_comic.py` `NIGHT_DROP`).
const NIGHT_DROP := 0.13


## The colour of a comic shadow: the theme's `shadow` on a light page; on a dark page the ink, faint.
## 🛑 A black block vanished on the near-black page (1.1:1). The theme's `shadow` itself stays dark — text shadows
##    (`GoStyle.text_shadow`) read it.
func drop_color() -> Color:
	var back := GoUi.color(GoTheme.BACKGROUND)
	if (back.r + back.g + back.b) / 3.0 < 0.5: return Color(ink(), NIGHT_DROP)
	return GoUi.color(GoTheme.SHADOW)


## A comic face from a fill and a corner: the ink outline (taking [param scale] of the setting) and the shadow (taking
## [param drop_scale], or never with [param shade] `OFF`).
func comic(fill: Color, corner: float, scale := 1.0, drop_scale := 1.0,
		shade := GoStyleBoxComic.Shadow.FOLLOW) -> GoStyleBoxComic:
	var face := GoStyleBoxComic.new()
	face.bg_color = fill
	face.border_color = ink()
	face.shadow_color = drop_color()
	face.radius = corner
	face.outline_scale = scale
	face.drop_scale = drop_scale
	face.shadow = shade
	return face


## A strip inked on [param sides] only (a heading's underline, a bar's edge) — square, flat on the page, and still
## following the setting as it is drawn (a `StyleBoxFlat` would keep the width it was built with).
func strip(fill: Color, sides: int, scale := 1.0) -> GoStyleBoxComic:
	var face := comic(fill, 0.0, scale, 1.0, GoStyleBoxComic.Shadow.OFF)
	face.sides = sides
	face.draw_center = fill.a > 0.0
	return face


## The crayon box — the theme's bright fill colours.
## 🛑 Of the warning and the info colour, the one further from the accent comes first: at night the accent is yellow
##    like the warning, by day blue like the info, and a four-slice chart could not tell the pair apart.
func chart_colors() -> Array[Color]:
	var out: Array[Color] = []
	for token in [GoTheme.ACCENT_FILL, GoTheme.DANGER_FILL, GoTheme.SUCCESS_FILL]:
		out.append(GoUi.color(token))
	var warning := GoUi.color(GoTheme.WARNING_FILL)
	var info := GoUi.color(GoTheme.INFO_FILL)
	if _distance(info, out[0]) >= _distance(warning, out[0]): out.append_array([info, warning])
	else: out.append_array([warning, info])
	return out


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


# ── Chips, slots, badges, discs ───────────────────────────────────────

## A chip is a speech bubble: the surface tinted with its colour, a thinner ink line and a small shadow.
func chip_box(color: Color) -> StyleBox:
	var base := super(color)
	var face := comic(GoUi.color(GoTheme.SURFACE).lerp(Color(color, 1.0), comic_tint), GoUi.metric(GoTheme.RADIUS_SMALL),
		SMALL, 0.5)
	return face.keep_margins(base)


func filter_chip_box(selected: bool, state: StringName) -> StyleBox:
	if state == &"focus": return super(selected, state)
	var face := chip_box(GoUi.color(GoTheme.ACCENT) if selected else GoUi.color(GoTheme.SECONDARY)) as GoStyleBoxComic
	if not selected: face.bg_color = GoUi.color(GoTheme.SURFACE)
	if state == &"hover": face.bg_color = face.bg_color.lerp(GoUi.color(GoTheme.TEXT), 0.06)
	elif state == &"disabled": face.bg_color = Color(face.bg_color, 0.5)
	face.pressed = state == &"pressed" or selected
	return face


## A quick slot is a little inked panel tinted with its colour; lit (cooling down, the cell being typed in, today) its
## ink takes its colour and the tint deepens.
## 🛑 Not pressed in: the same face marks a code input's current cell and a reward calendar's today, and a sunk cell
##    stood 2dp out of line with its row.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var face := comic(GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 1.0), comic_tint * (1.6 if lit else 1.0)),
		GoUi.metric(GoTheme.RADIUS_SMALL))
	if lit: face.border_color = _rim(accent)
	face.set_content_margin_all(0)
	return face


## A badge is a sticker on a slot's corner: the surface faintly tinted with its colour, a thin ink line, flat.
## 🛑 Not the raised surface: by day that is pale blue, and an error count sat on blue with a wine-coloured line.
func badge_box(ink_color: Color) -> StyleBox:
	var face := comic(GoUi.color(GoTheme.SURFACE).lerp(Color(ink_color, 1.0), 0.12), GoUi.metric(GoTheme.RADIUS_SMALL), 0.5,
		1.0, GoStyleBoxComic.Shadow.OFF)
	face.content_margin_left = badge_pad_x
	face.content_margin_right = badge_pad_x
	face.content_margin_top = badge_pad_y
	face.content_margin_bottom = badge_pad_y
	return face


## An avatar or icon disc: a round inked plate faintly filled with its colour. A ring asked for in full colour (the
## coach mark's) is drawn in that colour, not in ink.
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var face := comic(Color(accent, fill_alpha), maxf(1.0, diameter * 0.5 - 1.0), SMALL, 1.0, GoStyleBoxComic.Shadow.OFF)
	if edge_alpha >= 0.99: face.border_color = Color(accent, 1.0)
	face.set_content_margin_all(0)
	return face


## A section heading is underlined in ink. 🛑 A line under the whole heading, not a mark on one side — in a
## right-to-left language the text moves to the other end and a side mark would be left behind.
func section_box() -> StyleBox:
	var face := strip(Color.TRANSPARENT, GoStyleBoxComic.BOTTOM, SMALL)
	face.content_margin_bottom = 4
	return section_rhythm(face)


# ── Panels ────────────────────────────────────────────────────────────

## A panel floating over the game is the theme's comic panel with a deeper shadow.
func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var face := surface_box(variant, accent, alpha) as GoStyleBoxComic
	if face == null: return super(variant, accent, alpha)
	face.drop_scale = FLOAT_DROP
	face.border_color = _rim(accent)
	return face


## A card or panel keeps its ink — an accent asked for tints the ink rather than replacing it.
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var face := super(variant, accent, alpha)
	var inked := face as GoStyleBoxComic
	if inked != null: inked.border_color = _rim(accent)
	return face


## A notice or a snackbar keeps the comic panel; its accent tints the ink.
func tint_notice(box: StyleBox, accent: Color) -> void:
	var face := box as GoStyleBoxComic
	if face == null:
		super(box, accent)
		return
	face.border_color = _rim(accent)


## The ink, leaning towards [param accent] when one is given — still dark (or light) enough to read as a line.
func _rim(accent: Color) -> Color:
	if accent.a <= 0.0: return ink()
	return ink().lerp(Color(accent, 1.0), 0.6)


## An alert is a caption box tinted with its colour, flat on the page.
func alert_box(ink_color: Color, alpha := -1.0) -> StyleBox:
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_CARD)
	var base := super(ink_color, alpha)
	var face := comic(Color(GoUi.color(GoTheme.SURFACE).lerp(ink_color, alert_tint), opacity), GoUi.metric(GoTheme.RADIUS),
		1.0, 1.0, GoStyleBoxComic.Shadow.OFF)
	face.border_color = _rim(ink_color)
	return face.keep_margins(base)


## A choice cell (a choice grid, a card you pick) is an inked tile; the chosen one is pressed in with an accent rim.
func choice_box(state: StringName) -> StyleBox:
	var face := super(state)
	var inked := face as GoStyleBoxComic
	if state == &"focus" or inked == null: return face
	inked.radius = GoUi.metric(GoTheme.RADIUS_SMALL)
	inked.drop_scale = 0.5
	match state:
		&"pressed", &"hover_pressed":
			inked.border_color = GoUi.color(GoTheme.ACCENT)
			inked.pressed = true
		&"hover":
			inked.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
		&"disabled":
			inked.bg_color = Color(inked.bg_color, inked.bg_color.a * 0.5)
			inked.shadow = GoStyleBoxComic.Shadow.OFF
	return inked


## One cell of a segmented control: an inked row whose cells share their inner lines; the chosen cell is filled.
## 🔑 Every cell drops the shadow: each one is opaque and drawn after the one before it, so a cell's shadow hides under
##    its neighbour and the row reads as one block with one shadow. The chosen cell is not pushed in — its shadow
##    would leave a gap in the row's.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var fill := GoUi.color(GoTheme.SURFACE)
	if state == &"pressed" or state == &"hover_pressed": fill = GoUi.color(GoTheme.ACCENT)
	elif state == &"hover": fill = GoUi.color(GoTheme.SURFACE_HIGH)
	var face := comic(fill, GoUi.metric(GoTheme.RADIUS_SMALL), SMALL)
	face.keep_margins(super(index, count, state))
	var corners := 0
	if index == 0: corners |= GoStyleBoxComic.TOP_LEFT | GoStyleBoxComic.BOTTOM_LEFT
	if index == count - 1: corners |= GoStyleBoxComic.TOP_RIGHT | GoStyleBoxComic.BOTTOM_RIGHT
	face.corners = corners
	if index > 0: face.sides = GoStyleBoxComic.ALL & ~GoStyleBoxComic.LEFT
	if state == &"disabled": face.shadow = GoStyleBoxComic.Shadow.OFF
	return face


# ── Bars ──────────────────────────────────────────────────────────────

## A bar's fill is an inked tube in its colour — the outline stays ink however pale the colour.
func progress_fill_box(ink_color: Color) -> StyleBox:
	var face := super(ink_color)
	var inked := face as GoStyleBoxComic
	if inked != null: inked.border_color = ink()
	return face


# ── App parts ─────────────────────────────────────────────────────────

## The navigation bar is a strip with an ink line along the side facing the page (square — it runs into the edge).
func nav_bar_box(vertical: bool) -> StyleBox:
	var face := strip(GoUi.color(GoTheme.SURFACE), 0 if vertical else GoStyleBoxComic.TOP)
	face.set_content_margin_all(0)
	return face


## The chosen destination's pill is a bubble tinted with the accent.
func nav_indicator_box(selected: bool, state: StringName) -> StyleBox:
	if state == &"focus" or not selected: return super(selected, state)
	var face := comic(GoUi.color(GoTheme.SURFACE).lerp(GoUi.color(GoTheme.ACCENT), comic_tint * 1.4), 16.0, SMALL, 1.0,
		GoStyleBoxComic.Shadow.OFF)
	face.pressed = state == &"pressed"
	return face


## The app bar is a strip with an ink line under it; scrolled, the line drops its shadow on the content.
func app_bar_box(scrolled: bool) -> StyleBox:
	var face := strip(GoUi.color(GoTheme.SURFACE), GoStyleBoxComic.BOTTOM)
	if scrolled:
		face.shadow = GoStyleBoxComic.Shadow.FOLLOW
		face.drop_scale = 0.5
	face.set_content_margin_all(0)
	return face


## The floating action button is the theme's inked primary key, rounder, with a deeper shadow.
func fab_box(extent: float, state: StringName) -> StyleBox:
	var face := super(extent, state)
	var inked := face as GoStyleBoxComic
	if inked == null or state == &"focus": return face
	inked.radius = roundf(extent * 0.28)
	inked.drop_scale = 1.25
	return inked


## The picked day is an inked disc; today keeps its ring, a little thicker.
func date_cell_box(kind: StringName, state: StringName) -> StyleBox:
	var face := super(kind, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	if kind == &"selected":
		var disc := comic(flat.bg_color, float(flat.corner_radius_top_left), SMALL, 0.5)
		disc.keep_margins(flat)
		disc.pressed = state == &"pressed"
		return disc
	if kind == &"today": flat.set_border_width_all(2)
	return flat


## The raised disc a pull-to-refresh indicator rides on — an inked disc with a small hard shadow, not a soft blur.
func refresh_disc_box() -> StyleBox:
	var face := comic(GoUi.color(GoTheme.SURFACE), FULL_ROUND, SMALL, 0.5)
	face.set_content_margin_all(6)
	return face


## A half of a split button: the button's inked face, squared where the halves meet (round again on the trailing half
## while its menu is open).
func split_button_box(face: StyleBox, leading: bool, state: StringName, open: bool) -> StyleBox:
	var inked := face as GoStyleBoxComic
	if inked == null or state == &"focus": return super(face, leading, state, open)
	if leading: inked.corners = GoStyleBoxComic.TOP_LEFT | GoStyleBoxComic.BOTTOM_LEFT
	elif not open: inked.corners = GoStyleBoxComic.TOP_RIGHT | GoStyleBoxComic.BOTTOM_RIGHT
	return inked


## A time picker's hour, minute and AM/PM boxes are inked tiles; the part being set is tinted with the accent and a
## press pushes the tile in. The fills are the base skin's, so `time_ink()` still reads on them.
func time_selector_box(selected: bool, state: StringName, period := false) -> StyleBox:
	if state == &"focus": return super(selected, state, period)
	var base := super(selected, state, period) as StyleBoxFlat
	var fill := GoUi.color(GoTheme.SURFACE).blend(base.bg_color) if base != null else GoUi.color(GoTheme.SURFACE)
	var face := comic(fill, GoUi.metric(GoTheme.RADIUS_SMALL), SMALL, 0.5)
	face.pressed = state == &"pressed" or state == &"hover_pressed"
	face.set_content_margin_all(0)
	return face


## The band behind a wheel picker's chosen item: an inked band, flat — the items roll under it.
func wheel_band_box() -> StyleBox:
	var base := super()
	var fill := GoUi.color(GoTheme.SURFACE_SOFT)
	if base is StyleBoxFlat: fill = (base as StyleBoxFlat).bg_color
	return comic(fill, GoUi.metric(GoTheme.RADIUS_SMALL), SMALL, 1.0, GoStyleBoxComic.Shadow.OFF).keep_margins(base)


# ── Window chrome ─────────────────────────────────────────────────────

## A window's title sits in a comic caption box — yellow, inked, with a small shadow.
## 🛑 At night the ink is cream, which vanished on the pale yellow — the box takes the page's dark colour as its line.
func title_plate_box() -> StyleBox:
	var face := comic(GoUi.color(GoTheme.WARNING_FILL).lerp(Color.WHITE, 0.45), 6.0, SMALL, 0.5)
	if contrast_ratio(face.border_color, face.bg_color) < 3.0:
		face.border_color = Color(GoUi.color(GoTheme.BACKGROUND), 1.0)
	face.content_margin_left = 12
	face.content_margin_right = 12
	face.content_margin_top = 4
	face.content_margin_bottom = 4
	return face


## The title's colour in the caption box — whichever of the text, the page and the ink reads best there.
## 🛑 Not the text colour pushed until it passes: on the night look that is a light ink, and pushed onto the yellow box
##    it turned a dull grey (4.5:1, measured) where the page's navy reads at 12:1.
func title_plate_ink() -> Color:
	var plate := title_plate_box() as GoStyleBoxComic
	var back := plate.bg_color if plate != null else GoUi.color(GoTheme.SURFACE)
	var best := GoUi.color(GoTheme.TEXT)
	for candidate: Color in [GoUi.color(GoTheme.BACKGROUND), ink()]:
		if contrast_ratio(candidate, back) > contrast_ratio(best, back): best = Color(candidate, 1.0)
	return readable_on(best, back)


## A window's close button is an inked disc with a small shadow; pressed, it is pushed in.
func dress_close_button(button: GoIconButton) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var fill := GoUi.color(GoTheme.SURFACE)
		if state == &"hover": fill = fill.lerp(GoUi.color(GoTheme.TEXT), 0.08)
		elif state == &"disabled": fill = GoUi.color(GoTheme.SURFACE_SOFT)
		var disc := comic(fill, FULL_ROUND, SMALL, 0.5)
		disc.pressed = state == &"pressed" or state == &"hover_pressed"
		if state == &"disabled": disc.shadow = GoStyleBoxComic.Shadow.OFF
		disc.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, disc)
	button.icon_tint = GoUi.color(GoTheme.TEXT)


# ── Direct drawing ────────────────────────────────────────────────────

## The joystick: a faint pad with a ring of ink, and an inked knob that drops its shadow (when shadows are on).
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink_color: Color, base: Color, active: bool) -> void:
	var line := ink()
	var width := maxf(2.0, float(GoUi.config.comic_border_width))
	var strength := 1.0 if active else 0.8
	canvas.draw_circle(center, radius, Color(base, joystick_base_alpha))
	if GoUi.config.comic_shadow:
		var drop := float(GoUi.config.comic_shadow_size)
		canvas.draw_circle(knob + Vector2(drop, drop), knob_radius, drop_color())
	canvas.draw_circle(knob, knob_radius, Color(GoUi.color(GoTheme.SURFACE), 0.94))
	canvas.draw_circle(knob, knob_radius * 0.3, Color(ink_color, strength))
	canvas.draw_arc(center, radius - width * 0.5, 0, TAU, 64, Color(line, clampf(joystick_ring_alpha + 0.4 * strength, 0.0, 1.0)),
		width, true)
	canvas.draw_arc(knob, knob_radius - width * 0.5, 0, TAU, 48, Color(line, strength), width, true)
