## 🟣 **The Material 3 shapes for the parts code draws.** The theme (`gohud_material_*.tres`) has already turned buttons,
## fields, menus and dialogs into M3 components; this redraws only what a theme cannot reach.
##
## ## What it overrides
## - The segmented control becomes the M3 Expressive **connected button group** (`button-group-connected-small`): pill
##   ends, small inner corners, a gap between the cells, tonal cells (`secondary-container`) and the chosen cell a full
##   pill in `secondary` (the tonal button's selected colours).
## - Chips are M3 assist chips: no fill, a 1dp `outline-variant` edge, 8dp corners, 32dp tall; the status colour
##   stays in the label.
## - Dividers take `outline-variant`, the M3 divider colour, not the stronger `outline`.
## - Badges are the M3 badge: a pill filled with the badge colour (`error` unless told otherwise), with no outline.
## Anything not overridden keeps `GoSkin`'s default shape.
##
## 🔑 The M3 colour roles it uses are the theme's optional `md_*` tokens. A theme without them (somebody else's, plugged
##    in with this skin) falls back to gohud's own tokens, so the skin never draws magenta.
@tool
class_name GoSkinMaterial
extends GoSkin

# ── Material dials — change only the numbers, from the skin resource (.tres) ───
# 🛑 If you change a default, change `tools/skin_dials.json` with it — a check compares the two.
@export_group("Material dials")
# 🔑 One `##` line per dial — the site generator fills the dial table and the glossary from these lines.
## Space between the cells of a connected button group (dp).
@export var segment_gap := 2.0
## Corner radius (dp) where two cells of a connected button group meet.
@export var segment_inner_radius := 8
@export_group("")

## Taller than any plate, so StyleBoxFlat rounds both ends into a pill (md.sys.shape.corner.full).
const FULL := 999
## The plate height of a small M3 button, drawn inside the 48dp touch target (button-small container-height).
const PLATE := 40.0


## One cell of the connected button group. The cell control keeps the 48dp touch height; its plate is drawn 40dp tall.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var face := StyleBoxFlat.new()
	var chosen := state == &"pressed" or state == &"hover_pressed"
	var picked := role(&"md_secondary", GoUi.color(GoTheme.ACCENT))
	var ground := role(&"md_secondary_container", GoUi.color(GoTheme.SURFACE_SOFT))
	var ink := role(&"md_on_secondary_container", GoUi.color(GoTheme.TEXT))
	if state == &"focus":
		face.draw_center = false
		face.border_color = picked
		face.set_border_width_all(3)
	elif chosen:
		# 🛑 `GoStyle.segmented` writes the chosen label in `ON_ACCENT` — it reads on `secondary` in both Material presets.
		face.bg_color = picked.lerp(GoUi.color(GoTheme.ON_ACCENT), 0.08) if state == &"hover_pressed" else picked
	else:
		face.bg_color = ground.lerp(ink, 0.08) if state == &"hover" else ground
	# 🔑 Pill ends, small inner corners — and the chosen cell rounds all four (selected inner corner 50%).
	# 🛑 The pill end is **half the plate**, not `FULL`: StyleBoxFlat shrinks every corner by the same ratio once two of
	#    them add up past a side, so a 999 end would squash the 8dp inner corner to nothing.
	var first := index == 0 or chosen
	var last := index == count - 1 or chosen
	var pill := int(PLATE * 0.5)
	var inner := segment_inner_radius
	face.corner_radius_top_left = pill if first else inner
	face.corner_radius_bottom_left = pill if first else inner
	face.corner_radius_top_right = pill if last else inner
	face.corner_radius_bottom_right = pill if last else inner
	face.corner_detail = 16
	# The plate sits inside the touch target, and half the gap is taken off each side that meets a neighbour.
	var edge := (float(GoUi.metric(GoTheme.TOUCH)) - PLATE) * 0.5
	var half := segment_gap * 0.5
	face.expand_margin_top = -edge
	face.expand_margin_bottom = -edge
	face.expand_margin_left = -half if index > 0 else 0.0
	face.expand_margin_right = -half if index < count - 1 else 0.0
	if state == &"focus":
		# The focus ring stands 2dp outside the plate (md.sys.state.focus-indicator outer-offset).
		face.expand_margin_top += 5.0
		face.expand_margin_bottom += 5.0
		face.expand_margin_left += 5.0
		face.expand_margin_right += 5.0
	# 🛑 The same padding in every state — a cell that changes padding when pressed shifts its width.
	face.content_margin_left = GoUi.metric(GoTheme.COMPACT_PADDING_X)
	face.content_margin_right = GoUi.metric(GoTheme.COMPACT_PADDING_X)
	return face


## An M3 assist chip — no fill, a 1dp `outline-variant` edge, 8dp corners, 32dp tall with a 12sp label.
## The status colour stays in the label (`chip_ink` makes it readable on whatever lies under the chip).
func chip_box(color: Color) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = Color(color, 0.0)
	face.border_color = role(&"md_outline_variant", GoUi.color(GoTheme.BORDER))
	face.set_border_width_all(1)
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	face.corner_detail = 8
	face.content_margin_left = GoUi.metric(GoTheme.COMPACT_PADDING_X)
	face.content_margin_right = GoUi.metric(GoTheme.COMPACT_PADDING_X)
	face.content_margin_top = GoUi.metric(GoTheme.GAP_SMALL)
	face.content_margin_bottom = GoUi.metric(GoTheme.GAP_SMALL)
	return face


## The M3 divider colour.
func divider_color() -> Color:
	return role(&"md_outline_variant", GoUi.color(GoTheme.BORDER))


## The M3 badge — a pill filled with the badge colour. The label colour is chosen against this face by the badge itself.
func badge_box(ink: Color) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = Color(ink, 1.0)
	face.set_corner_radius_all(FULL)
	face.corner_detail = 8
	face.content_margin_left = badge_pad_x
	face.content_margin_right = badge_pad_x
	face.content_margin_top = badge_pad_y
	face.content_margin_bottom = badge_pad_y
	return face


## An M3 colour role from the theme's optional `md_*` tokens, or [param otherwise] when the theme has none.
static func role(key: StringName, otherwise: Color) -> Color:
	var found := GoUi.color(key)
	return otherwise if found == Color.MAGENTA else found
