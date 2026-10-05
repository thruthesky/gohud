## Comic skin — the comic page. Every part is inked: a bold outline in the theme's `border` colour around the surface
## colour, and a hard, faint shadow dropped down and to the right of what stands off the page (`GoStyleBoxComic`).
## Chips are speech bubbles, quick slots are panels pressed in while they cool down, a window's title sits in a yellow
## caption box, its close button is an inked disc, and the joystick is a ring of ink with an inked knob.
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


## A comic face from a fill and a corner: the ink outline (taking [param scale] of the setting) and the shadow (taking
## [param drop_scale], or never with [param shade] `OFF`).
func comic(fill: Color, corner: float, scale := 1.0, drop_scale := 1.0,
		shade := GoStyleBoxComic.Shadow.FOLLOW) -> GoStyleBoxComic:
	var face := GoStyleBoxComic.new()
	face.bg_color = fill
	face.border_color = ink()
	face.shadow_color = GoUi.color(GoTheme.SHADOW)
	face.radius = corner
	face.outline_scale = scale
	face.drop_scale = drop_scale
	face.shadow = shade
	return face


## The outline a flat part draws (dp, whole) — a strip that has to be a `StyleBoxFlat` reads the setting when built.
func _line(scale := 1.0) -> int:
	return maxi(1, roundi(float(GoUi.config.comic_border_width) * scale))


## The crayon box — the theme's bright fill colours.
func chart_colors() -> Array[Color]:
	var out: Array[Color] = []
	for token in [GoTheme.ACCENT_FILL, GoTheme.DANGER_FILL, GoTheme.WARNING_FILL, GoTheme.SUCCESS_FILL,
			GoTheme.INFO_FILL]:
		out.append(GoUi.color(token))
	return out


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


## A quick slot is a little inked panel tinted with its colour; while it cools down it is pressed in.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var face := comic(GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 1.0), comic_tint * (1.6 if lit else 1.0)),
		GoUi.metric(GoTheme.RADIUS_SMALL))
	face.pressed = lit
	face.set_content_margin_all(0)
	return face


## A badge is a sticker on a slot's corner: the raised surface, a thin ink line, flat.
func badge_box(ink_color: Color) -> StyleBox:
	var face := comic(GoUi.color(GoTheme.SURFACE_HIGH), GoUi.metric(GoTheme.RADIUS_SMALL), 0.5, 1.0,
		GoStyleBoxComic.Shadow.OFF)
	face.border_color = ink().lerp(Color(ink_color, 1.0), 0.35)
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
	var face := StyleBoxFlat.new()
	face.draw_center = false
	face.border_color = ink()
	face.border_width_bottom = _line(SMALL)
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
## 🛑 Flat cells (`StyleBoxFlat`), not comic faces — a shadow under each cell would fall on the next one.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = GoUi.color(GoTheme.SURFACE)
	var base := super(index, count, state)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: flat.set_content_margin(side, base.get_margin(side))
	if state == &"pressed" or state == &"hover_pressed":
		flat.bg_color = GoUi.color(GoTheme.ACCENT)
	elif state == &"hover":
		flat.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	var radius := GoUi.metric(GoTheme.RADIUS_SMALL)
	flat.corner_radius_top_left = radius if index == 0 else 0
	flat.corner_radius_bottom_left = radius if index == 0 else 0
	flat.corner_radius_top_right = radius if index == count - 1 else 0
	flat.corner_radius_bottom_right = radius if index == count - 1 else 0
	flat.corner_detail = 8
	flat.border_color = ink()
	flat.set_border_width_all(_line(SMALL))
	flat.border_width_left = flat.border_width_left if index == 0 else 0
	return flat


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
	var flat := StyleBoxFlat.new()
	flat.bg_color = GoUi.color(GoTheme.SURFACE)
	flat.border_color = ink()
	if not vertical: flat.border_width_top = _line()
	flat.set_content_margin_all(0)
	return flat


## The chosen destination's pill is a bubble tinted with the accent.
func nav_indicator_box(selected: bool, state: StringName) -> StyleBox:
	if state == &"focus" or not selected: return super(selected, state)
	var face := comic(GoUi.color(GoTheme.SURFACE).lerp(GoUi.color(GoTheme.ACCENT), comic_tint * 1.4), 16.0, SMALL, 1.0,
		GoStyleBoxComic.Shadow.OFF)
	face.pressed = state == &"pressed"
	return face


## The app bar is a strip with an ink line under it; scrolled, the line drops its shadow on the content.
func app_bar_box(scrolled: bool) -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = GoUi.color(GoTheme.SURFACE)
	flat.border_color = ink()
	flat.border_width_bottom = _line()
	if scrolled and GoUi.config.comic_shadow:
		flat.shadow_color = GoUi.color(GoTheme.SHADOW)
		flat.shadow_size = 1
		flat.shadow_offset = Vector2(0, maxf(1.0, float(GoUi.config.comic_shadow_size) * 0.5))
	flat.set_content_margin_all(0)
	return flat


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


# ── Window chrome ─────────────────────────────────────────────────────

## A window's title sits in a comic caption box — yellow, inked, with a small shadow.
func title_plate_box() -> StyleBox:
	var face := comic(GoUi.color(GoTheme.WARNING_FILL).lerp(Color.WHITE, 0.45), 6.0, SMALL, 0.5)
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
		canvas.draw_circle(knob + Vector2(drop, drop), knob_radius, GoUi.color(GoTheme.SHADOW))
	canvas.draw_circle(knob, knob_radius, Color(GoUi.color(GoTheme.SURFACE), 0.94))
	canvas.draw_circle(knob, knob_radius * 0.3, Color(ink_color, strength))
	canvas.draw_arc(center, radius - width * 0.5, 0, TAU, 64, Color(line, clampf(joystick_ring_alpha + 0.4 * strength, 0.0, 1.0)),
		width, true)
	canvas.draw_arc(knob, knob_radius - width * 0.5, 0, TAU, 48, Color(line, strength), width, true)
