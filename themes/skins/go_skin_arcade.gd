## Arcade skin — the arcade cabinet. Every part is painted like the menus of a bright arcade game (`GoStyleBoxArcade`):
## a thick dark ink outline, a body that runs from light on top to deeper below, a deeper lip that sinks when pressed and
## a candy gloss (a sheen over the upper half, a glint round both top corners); panels are thick boards, a coloured
## frame round a pale well. A window's title sits on a gold ribbon with swallow tails, in white letters with an ink
## outline, its close button is a round red key, quick slots are key caps that light a gold rim while they cool down,
## the badge is a gold plate, a key hint (`GoKbd`) a keycap on a deep lip, a bar is split into chunks by ink ticks and
## the joystick is a glossy pad with four arrows.
##
## The engine-drawn controls (buttons, fields, tabs, sliders, panels) get their paint from the theme
## (`tools/theme_arcade.py`); this skin draws the parts gohud draws in code, and the window chrome.
##
## 🎨 The paints are the theme's bright fills, so the skin and the theme agree: `go()` (the success fill), `blue()`
##    (the accent fill), `red()` (the danger fill), `gold()` (the warning fill), `lavender()` (the secondary colour
##    lightened), `coral()`.
## 🛑 Sizes do not change: the outline, the lip and the frame are inside a part and the padding is the base skin's.
##    Text colours are still pushed until they read on the face actually painted (`chip_ink`, `slot_ink`, `nav_ink` read
##    these boxes) — which is why the faces under plain text are pale key caps, and the painted faces carry white text
##    with an ink outline (`dress_title`) or a dark ink (`fab_ink`).
@tool
class_name GoSkinArcade
extends GoSkin

@export_group("Arcade dials")
## The ink outline of a part this skin paints (dp).
@export var arcade_edge := 3
## The lip under a part you press (dp) — keys, chips, slots, the FAB; it goes when the part is pressed.
@export var arcade_lip := 4
## The white gloss stroke on a painted part (0–1).
@export var arcade_gloss := 0.85
## The swallow-tailed ends of a window's title banner (dp) — 0 draws a plain gold key.
@export var arcade_ribbon := 12.0
## How many chunks a bar is split into when it leaves that to the look (`GoBar.segments = -1`) — 0 for smooth bars.
@export var arcade_bar_ticks := 6
@export_group("")

## A press: how far the part shrinks and how long it takes to shrink and to spring back (s).
const POP := Vector2(0.94, 0.94)
const POP_DOWN := 0.05
const POP_BACK := 0.22
## The ink outline round a white title (the engine's `outline_size`).
const TITLE_OUTLINE := 6
## How faint the night ink is mixed: on a dark page the ink is the page, much deeper (`tools/theme_arcade.py` `ink()`).
const NIGHT_INK := 0.55
## The least saturation of the small keys' lavender (`tools/theme_arcade.py` `LAVENDER_SATURATION`).
const LAVENDER_SATURATION := 0.5
## The corner of a small key standing in a row — a segment, a tab (`tools/theme_arcade.py` `KEY_RADIUS_SMALL`).
const KEY_RADIUS_SMALL := 16.0
## The room between two keys standing in a row (dp): each is drawn this much in from its cell, so the row reads as
## separate keys without any size changing (`tools/theme_arcade.py` `ROW_GAP`).
const ROW_GAP := 4.0
## How far a ribbon's body stands above its tails (dp).
const RIBBON_DROP := 4.0


## Is this the night look?
func _night() -> bool:
	var back := GoUi.color(GoTheme.BACKGROUND)
	return (back.r + back.g + back.b) / 3.0 < 0.5


## The ink — the theme's border colour on a light page; on a dark one the page, much deeper.
func ink() -> Color:
	if _night(): return Color(GoUi.color(GoTheme.BACKGROUND).lerp(Color.BLACK, NIGHT_INK), 1.0)
	return Color(GoUi.color(GoTheme.BORDER), 1.0)


func go() -> Color: return Color(GoUi.color(GoTheme.SUCCESS_FILL), 1.0)
func blue() -> Color: return Color(GoUi.color(GoTheme.ACCENT_FILL), 1.0)
func red() -> Color: return Color(GoUi.color(GoTheme.DANGER_FILL), 1.0)
func gold() -> Color: return Color(GoUi.color(GoTheme.WARNING_FILL), 1.0)
## The small keys' lavender: the secondary colour lightened by day; at night, where it is already pale, leaned towards
## the page — and saturated to at least `LAVENDER_SATURATION`, or the key reads grey (`tools/theme_arcade.py`
## `lavender_of()`).
func lavender() -> Color:
	var secondary := Color(GoUi.color(GoTheme.SECONDARY), 1.0)
	var mixed := secondary.lerp(Color(GoUi.color(GoTheme.BACKGROUND), 1.0), 0.3) if _night() \
		else secondary.lerp(Color.WHITE, 0.42)
	return Color.from_hsv(mixed.h, maxf(mixed.s, LAVENDER_SATURATION), mixed.v)


## The bright fill of a status colour (the danger red, the info blue…) — the colours tuned for text are deep; a bar, a
## frame or a badge wants the fill. Any other colour comes back as it is.
func vivid(colour: Color) -> Color:
	for pair: Array in [[GoTheme.DANGER, GoTheme.DANGER_FILL], [GoTheme.INFO, GoTheme.INFO_FILL],
			[GoTheme.SUCCESS, GoTheme.SUCCESS_FILL], [GoTheme.WARNING, GoTheme.WARNING_FILL],
			[GoTheme.ACCENT, GoTheme.ACCENT_FILL]]:
		var token := GoUi.color(pair[0])
		if Vector3(token.r, token.g, token.b).distance_to(Vector3(colour.r, colour.g, colour.b)) < 0.01:
			return Color(GoUi.color(pair[1]), colour.a)
	return colour
func coral() -> Color: return red().lerp(Color.WHITE, 0.32)


## A key painted [param colour]: the ink outline, the gradient, a lip of [param lip] (the dial when negative) and the
## gloss.
func key(colour: Color, corner: float, lip := -1, edge := -1, gloss := -1.0) -> GoStyleBoxArcade:
	var face := GoStyleBoxArcade.new()
	face.paint(colour)
	face.border_color = ink()
	face.border_width = arcade_edge if edge < 0 else edge
	face.lip = arcade_lip if lip < 0 else lip
	face.radius = corner
	face.shine = arcade_gloss if gloss < 0.0 else gloss
	face.band = 0.0
	return face


## A key cap — what plain text sits on (a slot, a cell, a row) — tinted [param tint] of [param colour]. Pale by day
## (dark text on it); 🛑 at night the raised surface, not a pale one — a pale cap under the night look's light text and
## icons read grey and washed out (`tools/theme_arcade.py` `cap`, the theme's rows, is the same rule).
func cap(corner: float, colour := Color.TRANSPARENT, tint := 0.0, lip := -1, edge := 2) -> GoStyleBoxArcade:
	var surface := Color(GoUi.color(GoTheme.SURFACE), 1.0)
	var high := Color(GoUi.color(GoTheme.SURFACE_HIGH), 1.0)
	var top := high.lerp(Color.WHITE, 0.06) if _night() else surface.lerp(Color.WHITE, 0.5)
	var bottom := surface.lerp(high, 0.5) if _night() else surface.lerp(high, 0.55)
	if colour.a > 0.0:
		top = top.lerp(Color(colour, 1.0), tint)
		bottom = bottom.lerp(Color(colour, 1.0), tint * 0.8)
	var face := key(top, corner, lip, edge, arcade_gloss * 0.7)
	face.bg_color = top
	face.bottom_color = bottom
	face.shade_color = Color(face.bottom_color.lerp(ink(), 0.3), 1.0)
	return face


## A chart's slices take the paints, the accent first.
func chart_colors() -> Array[Color]:
	return [blue(), red(), go(), gold(), lavender()]


# ── Chips, slots, badges, discs ───────────────────────────────────────

## A chip is a small key cap tinted with its colour, a thin ink line and a small lip.
## 🛑 Not a full pill radius — the cell audit reads a 999 radius as "the text needs 300dp of room". Half a chip's height
##    rounds it just the same.
func chip_box(color: Color) -> StyleBox:
	var base := super(color)
	var face := cap(13.0, color, 0.3, 2)
	return face.keep_margins(base)


func filter_chip_box(selected: bool, state: StringName) -> StyleBox:
	if state == &"focus": return super(selected, state)
	var face := cap(13.0, blue() if selected else Color.TRANSPARENT, 0.32 if selected else 0.0, 2)
	face.keep_margins(super(selected, &"normal"))
	if state == &"hover": face.bg_color = face.bg_color.lerp(Color.WHITE, 0.35)
	elif state == &"disabled":
		face.bg_color = Color(face.bg_color, 0.5)
		face.shine = 0.0
	face.pressed = state == &"pressed"
	return face


## A quick slot is a key cap tinted with its colour; lit (cooling down, the cell being typed in, today) it lights a
## gold rim inside its ink.
## 🛑 Not pressed in: the same face marks a code input's current cell and a reward calendar's today, and a sunk cell
##    stood out of line with its row.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var face := cap(GoUi.metric(GoTheme.RADIUS_SMALL), accent, 0.2 if lit else 0.12, 3)
	# A softer gloss: the slot's number sits in its top-left corner, right where the stroke runs.
	face.shine = 0.35
	if lit:
		face.frame = 3.0
		face.frame_color = gold().lerp(Color.WHITE, 0.15)
		face.frame_bottom = gold()
		face.shade_color = Color(gold().lerp(ink(), 0.35), 1.0)
	face.set_content_margin_all(0)
	return face


## A badge is a small plate painted a light tone of its colour, outlined in ink — the "PLAYER" plate of an arcade HUD.
## Light, so its count (pushed until it reads on the plate, `GoBadge`) stays a deep tone of the colour.
func badge_box(ink_color: Color) -> StyleBox:
	var face := key(vivid(Color(ink_color, 1.0)).lerp(Color.WHITE, 0.5), GoUi.metric(GoTheme.RADIUS_SMALL), 0, 2, 0.6)
	face.content_margin_left = badge_pad_x
	face.content_margin_right = badge_pad_x
	face.content_margin_top = badge_pad_y
	face.content_margin_bottom = badge_pad_y
	return face


## An avatar or icon disc: a round key cap faintly tinted with its colour. A ring asked for in full colour (the coach
## mark's) is drawn in that colour.
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var face := cap(maxf(1.0, diameter * 0.5 - 1.0), accent, clampf(fill_alpha * 1.6, 0.0, 1.0), 0, 2)
	if fill_alpha <= 0.0:
		face.draw_center = false
	if edge_alpha >= 0.99:
		face.border_color = Color(accent, 1.0)
		face.border_width = 3.0
	face.set_content_margin_all(0)
	return face


## A section heading is underlined with a thick ink rule. 🛑 Under the whole heading, not a mark on one side — in a
## right-to-left language the text moves to the other end and a side mark would be left behind.
func section_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.draw_center = false
	face.border_color = ink()
	face.border_width_bottom = 3
	face.set_corner_radius_all(2)
	face.content_margin_bottom = 5
	return section_rhythm(face)


# ── Boards ────────────────────────────────────────────────────────────

## A board floating over the game is the theme's board with a soft shadow under it.
func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var face := surface_box(variant, accent, alpha) as GoStyleBoxArcade
	if face == null: return super(variant, accent, alpha)
	face.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha)
	face.shadow_size = float_shadow_size
	face.shadow_offset = Vector2(0, float_shadow_lift)
	return face


## A card or panel keeps its board — an accent asked for paints the frame.
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var face := super(variant, accent, alpha)
	var board := face as GoStyleBoxArcade
	if board != null:
		board.border_color = ink()
		if accent.a > 0.0 and board.frame > 0.0: _frame(board, accent)
	return face


## Paints a board's frame [param colour] (its top, bottom and lip).
func _frame(board: GoStyleBoxArcade, colour: Color) -> void:
	var three := GoStyleBoxArcade.tones(colour)
	board.frame_color = three[0]
	board.frame_bottom = three[1]
	board.shade_color = three[2]


## A notice or a snackbar keeps the board; its accent paints the frame.
func tint_notice(box: StyleBox, accent: Color) -> void:
	var board := box as GoStyleBoxArcade
	if board == null:
		super(box, accent)
		return
	if accent.a > 0.0 and board.frame > 0.0: _frame(board, accent)


## An alert is a small board: its frame painted in its colour round a well faintly tinted with it.
func alert_box(ink_color: Color, alpha := -1.0) -> StyleBox:
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_CARD)
	var base := super(ink_color, alpha)
	var face := cap(GoUi.metric(GoTheme.RADIUS), Color.TRANSPARENT, 0.0, 3, arcade_edge)
	var well := GoUi.color(GoTheme.SURFACE).lerp(Color(ink_color, 1.0), alert_tint)
	face.bg_color = Color(well, opacity)
	face.bottom_color = well.lerp(Color(ink_color, 1.0), 0.06)
	face.frame = 3.0
	_frame(face, vivid(Color(ink_color, 1.0)))
	face.inner_line = ink()
	face.line_width = 1.5
	face.shine = 0.6
	return face.keep_margins(base)


## A choice cell (a choice grid, a card you pick) is a key cap; the chosen one lights a gold rim round a green tint —
## the stage you are about to play.
func choice_box(state: StringName) -> StyleBox:
	if state == &"focus": return super(state)
	var base := super(state)
	var chosen := state == &"pressed" or state == &"hover_pressed"
	var face := cap(GoUi.metric(GoTheme.RADIUS_SMALL), go() if chosen else Color.TRANSPARENT, 0.22 if chosen else 0.0, 3)
	if chosen:
		face.frame = 3.0
		face.frame_color = gold().lerp(Color.WHITE, 0.15)
		face.frame_bottom = gold()
		face.shade_color = Color(gold().lerp(ink(), 0.35), 1.0)
	elif state == &"hover":
		face.bg_color = face.bg_color.lerp(GoUi.color(GoTheme.SURFACE_HIGH), 0.6)
	elif state == &"disabled":
		face.bg_color = Color(face.bg_color, 0.5)
		face.shine = 0.0
	return face.keep_margins(base)


## One cell of a segmented control: a painted key — the chosen one blue, the others lavender, like the tabs.
## 🔑 Each cell keeps its own outline and corners: the cells are separate keys standing in a row.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var base := super(index, count, state)
	if state == &"focus": return base
	var chosen := state == &"pressed" or state == &"hover_pressed"
	var face := key(blue() if chosen else lavender(), KEY_RADIUS_SMALL, 3, 2)
	if state == &"hover": face.paint(lavender().lerp(Color.WHITE, 0.15))
	face.pressed = chosen
	_stand_apart(face)
	return face.keep_margins(base)


## Draws [param face] `ROW_GAP` / 2 in from each side of its cell — keys in a row stand apart, no size changes.
static func _stand_apart(face: StyleBox) -> void:
	face.expand_margin_left = -ROW_GAP * 0.5
	face.expand_margin_right = -ROW_GAP * 0.5


# ── Bars ──────────────────────────────────────────────────────────────

## A bar's fill is a painted tube in the bright fill of its colour, with an ink line and a gloss — the gradient
## follows the colour asked for. 🛑 The bright fill, not the colour tuned for text: a health bar in the deep red the
## text uses read as a dried stripe.
func progress_fill_box(ink_color: Color) -> StyleBox:
	var face := super(vivid(ink_color))
	var tube := face as GoStyleBoxArcade
	if tube != null:
		tube.bottom_color = Color(0, 0, 0, 0)
		tube.shade_color = Color(0, 0, 0, 0)
		tube.border_color = ink()
		tube.border_width = maxf(2.0, tube.border_width)
	return face


## An outlined button is a white key cap — the paint is what tells it from the painted keys — with the accent label.
func outlined_button_box(face: StyleBox, state: StringName) -> StyleBox:
	if state == &"focus" or not (face is GoStyleBoxArcade): return super(face, state)
	var key_cap := cap((face as GoStyleBoxArcade).radius, Color.TRANSPARENT, 0.0, arcade_lip, arcade_edge)
	key_cap.keep_margins(face)
	if state == &"hover": key_cap.bg_color = key_cap.bg_color.lerp(GoUi.color(GoTheme.SURFACE_HIGH), 0.5)
	elif state == &"disabled":
		key_cap.bg_color = Color(key_cap.bg_color, 0.55)
		key_cap.shine = 0.0
	key_cap.pressed = state == &"pressed" or state == &"hover_pressed"
	return key_cap


## The outlined button's label: the accent, pushed until it reads on the page and on the key cap.
func outlined_button_ink() -> Color:
	var on_page := readable_on(GoUi.color(GoTheme.ACCENT), GoUi.color(GoTheme.BACKGROUND))
	return readable_on(on_page, cap(10.0).bg_color)


## The loading shape in the accent on a gold disc.
## 🛑 The accent is pushed until it stands off the disc over the page — the sky-blue accent on gold sat under 3:1
##    (found 2026-10-06, once the arcade looks joined `GoThemePresets.BUILTIN` and every per-preset check).
func loading_colors(contained: bool) -> Array[Color]:
	var accent := GoUi.color(GoTheme.ACCENT)
	if not contained: return [accent, Color.TRANSPARENT]
	var disc := Color(gold(), 0.35)
	return [readable_on(accent, blend(disc, GoUi.color(GoTheme.BACKGROUND)), 3.0), disc]


# ── App parts ─────────────────────────────────────────────────────────

## The navigation bar is a board strip with an ink rule along the side facing the page (square — it runs into the edge).
func nav_bar_box(vertical: bool) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = GoUi.color(GoTheme.SURFACE)
	face.border_color = ink()
	if not vertical: face.border_width_top = 3
	face.set_content_margin_all(0)
	return face


## The chosen destination's pill is a pale sky key cap.
func nav_indicator_box(selected: bool, state: StringName) -> StyleBox:
	if state == &"focus" or not selected: return super(selected, state)
	var face := cap(16.0, blue(), 0.3, 2)
	face.pressed = state == &"pressed"
	return face


## The app bar is a board strip with an ink rule under it.
func app_bar_box(scrolled: bool) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = GoUi.color(GoTheme.SURFACE)
	face.border_color = ink()
	face.border_width_bottom = 3
	if scrolled:
		face.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha * 0.5)
		face.shadow_size = maxi(2, roundi(float_shadow_size * 0.5))
		face.shadow_offset = Vector2(0, 2)
	face.set_content_margin_all(0)
	return face


## The floating action button is a big gold key — the coin button — with a lip under it, sunk when pressed.
func fab_box(extent: float, state: StringName) -> StyleBox:
	var base := super(extent, state)
	if state == &"focus": return base
	var face := key(gold(), roundf(extent * 0.3), 5)
	if state == &"hover": face.paint(gold().lerp(Color.WHITE, 0.12))
	elif state == &"disabled":
		face.paint(GoUi.color(GoTheme.SURFACE_HIGH))
		face.shine = 0.0
	face.pressed = state == &"pressed"
	face.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha)
	face.shadow_size = float_shadow_size
	face.shadow_offset = Vector2(0, float_shadow_lift)
	return face.keep_margins(base)


## The ink on the gold coin button — the ink itself, which reads on gold at a glance.
func fab_ink() -> Color:
	return readable_on(ink(), GoStyleBoxArcade.tones(gold())[0])


## The picked day is a blue key; today keeps its ring, a little thicker.
func date_cell_box(kind: StringName, state: StringName) -> StyleBox:
	var face := super(kind, state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	if kind == &"selected":
		var day := key(flat.bg_color, float(flat.corner_radius_top_left), 2, 2, 0.6)
		day.bg_color = flat.bg_color
		day.bottom_color = flat.bg_color.lerp(Color.BLACK, 0.08)
		day.keep_margins(flat)
		day.pressed = state == &"pressed"
		return day
	if kind == &"today": flat.set_border_width_all(2)
	return flat


## The raised disc a pull-to-refresh indicator rides on — a round key cap.
func refresh_disc_box() -> StyleBox:
	var face := cap(FULL_ROUND, Color.TRANSPARENT, 0.0, 0, 2)
	face.set_content_margin_all(6)
	return face


## A time picker's hour, minute and AM/PM boxes are key caps; the part being set is tinted blue. The fills are the base
## skin's, so `time_ink()` still reads on them.
func time_selector_box(selected: bool, state: StringName, period := false) -> StyleBox:
	if state == &"focus": return super(selected, state, period)
	var base := super(selected, state, period) as StyleBoxFlat
	var fill := GoUi.color(GoTheme.SURFACE).blend(base.bg_color) if base != null else GoUi.color(GoTheme.SURFACE)
	var face := cap(GoUi.metric(GoTheme.RADIUS_SMALL), Color.TRANSPARENT, 0.0, 3)
	face.bg_color = fill
	face.bottom_color = fill.lerp(Color.BLACK, 0.05)
	face.pressed = state == &"pressed" or state == &"hover_pressed"
	face.set_content_margin_all(0)
	return face


## The band behind a wheel picker's chosen item: a key cap band, flat — the items roll under it.
func wheel_band_box() -> StyleBox:
	var base := super()
	var face := cap(GoUi.metric(GoTheme.RADIUS_SMALL), Color.TRANSPARENT, 0.0, 0)
	if base is StyleBoxFlat:
		face.bg_color = (base as StyleBoxFlat).bg_color
		face.bottom_color = face.bg_color
	return face.keep_margins(base)


## A `GoKbd` key is a keycap — a pale key on a deep lip, outlined in ink, the word in ink on it.
func kbd_box() -> StyleBox:
	var base := super()
	var face := cap(6.0, Color.TRANSPARENT, 0.0, 3, 2)
	face.keep_margins(base)
	# The word sits on the key's face, above its lip (the sum, the size, stays).
	var rise := minf(1.5, face.content_margin_top)
	face.content_margin_top -= rise
	face.content_margin_bottom += rise
	return face


## The word on the keycap — the text colour, which reads on the cap by day and by night.
func kbd_ink() -> Color:
	return readable_on(GoUi.color(GoTheme.TEXT), box_background(kbd_box()))


func bar_ticks() -> int:
	return maxi(0, arcade_bar_ticks)


## A bar's chunks are cut by thick ink ticks across the groove and the fill — the segmented gauge of an arcade HUD.
func draw_bar_ticks(canvas: CanvasItem, rect: Rect2, count: int) -> void:
	if count < 2 or rect.size.x < float(count) * 6.0: return
	var line := Color(ink(), 0.9)
	var width := clampf(rect.size.y * 0.24, 1.5, 3.0)
	for index in range(1, count):
		var x := roundf(rect.position.x + rect.size.x * float(index) / float(count))
		canvas.draw_line(Vector2(x, rect.position.y + 1.0), Vector2(x, rect.end.y - 1.0), line, width, true)


# ── Window chrome and the feel of a press ─────────────────────────────

## A window's title sits on a gold banner — a painted key with its lip and gloss, its ends folded back into swallow
## tails (`arcade_ribbon`), like the banner over an arcade game's menu.
func title_plate_box() -> StyleBox:
	var face := key(gold(), 18.0, 3, arcade_edge)
	var tail := maxf(0.0, float(arcade_ribbon))
	face.tails = tail
	face.tail_drop = RIBBON_DROP if tail > 0.0 else 0.0
	# Room at the ends for the tails, the round corners and the gloss — the title stays clear of all three.
	face.pad(20.0 + tail, 6.0)
	# The body stands `tail_drop` above the tails: the text moves up with it (the sum, the size, stays).
	var rise := minf(face.tail_drop * 0.5, face.content_margin_top)
	face.content_margin_top -= rise
	face.content_margin_bottom += rise
	return face


## The title on the banner is white — `dress_title` gives it the ink outline it reads through.
func title_plate_ink() -> Color:
	return Color.WHITE


## The title's ink outline — the white letters of an arcade banner read through it on the gold.
func dress_title(label: Label) -> void:
	label.add_theme_color_override(&"font_outline_color", ink())
	label.add_theme_constant_override(&"outline_size", TITLE_OUTLINE)


## A window's close button is a round red key with a white cross.
func dress_close_button(button: GoIconButton) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var colour := red()
		if state == &"hover": colour = colour.lerp(Color.WHITE, 0.12)
		elif state == &"disabled": colour = GoUi.color(GoTheme.SURFACE_HIGH)
		var face := key(colour, FULL_ROUND, 3, 2, 0.8 if state != &"disabled" else 0.0)
		face.pressed = state == &"pressed" or state == &"hover_pressed"
		face.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, face)
	button.icon_tint = Color.WHITE


## A press pops the key in for a moment and springs it back. Only `scale` changes (round the centre), so the layout and
## the press area stay put; `reduce_motion` and headless runs skip it (a test that measures a part right after tapping
## it should read its real rectangle).
func press_feedback(control: Control) -> void:
	if GoUi.config.reduce_motion or DisplayServer.get_name() == "headless": return
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	var running: Variant = control.get_meta(&"go_pop") if control.has_meta(&"go_pop") else null
	if running is Tween and (running as Tween).is_valid(): (running as Tween).kill()
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, ^"scale", POP, POP_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, ^"scale", Vector2.ONE, POP_BACK).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	control.set_meta(&"go_pop", tween)


# ── Direct drawing ────────────────────────────────────────────────────

## The joystick: a glossy pad in an ink ring with four arrows, and a knob that is a round key cap with a gloss.
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink_color: Color, base: Color, active: bool) -> void:
	var line := ink()
	var strength := 1.0 if active else 0.85
	var pad := Color(ink_color, 1.0).lerp(Color.WHITE, 0.55)
	var width := maxf(2.0, joystick_ring_width)
	canvas.draw_circle(center, radius, Color(base.lerp(pad, 0.6), joystick_base_alpha))
	canvas.draw_circle(center, radius * 0.86, Color(pad, joystick_base_alpha * 0.6))
	canvas.draw_arc(center, radius - width * 0.5, 0, TAU, 64, Color(line, clampf(joystick_ring_alpha + 0.35, 0.0, 1.0)),
		width, true)
	canvas.draw_arc(center, radius * 0.72, PI * 1.05, PI * 1.45, 16, Color(1, 1, 1, 0.55 * strength), width * 0.8, true)
	var arrow := Color(1, 1, 1, 0.75 * strength)
	var size := radius * 0.13
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip := center + direction * radius * 0.8
		var back := tip - direction * size * 1.4
		var side := direction.orthogonal() * size
		canvas.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), arrow)
	var cap_top := GoUi.color(GoTheme.SURFACE).lerp(Color.WHITE, 0.6)
	canvas.draw_circle(knob + Vector2(0, knob_radius * 0.12), knob_radius, Color(line, strength))
	canvas.draw_circle(knob, knob_radius - width, Color(cap_top.lerp(GoUi.color(GoTheme.SURFACE_HIGH), 0.6), strength))
	canvas.draw_circle(knob - Vector2(0, knob_radius * 0.1), knob_radius * 0.72, Color(cap_top, strength))
	canvas.draw_arc(knob, knob_radius * 0.62, PI * 1.08, PI * 1.42, 12, Color(1, 1, 1, 0.85 * strength),
		maxf(1.5, knob_radius * 0.1), true)
	canvas.draw_arc(knob, knob_radius - width * 0.5, 0, TAU, 48, Color(line, strength), width, true)
