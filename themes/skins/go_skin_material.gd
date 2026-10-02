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
## - The pill laid over the screen is the M3 **floating toolbar** (`surface-container`, level 3, no outline); the small
##   segmented control inside it keeps its pill cells.
## - Skeletons take `surface-container-highest`; a drawer is the M3 modal side sheet (`surface-container-low`, 16dp on
##   the inner edge only); an icon button's glyph is 24dp on its 36dp node; a chip's icon is 18dp.
## - The app components — navigation bar and rail, top app bar, FAB, search bar, filter chips, toolbar, split button,
##   loading indicator — follow their `_md-comp-*` tokens (see each method).
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
## The plate height of a chip (`_md-comp-filter-chip.scss` container-height) inside the 48dp touch target.
const CHIP_PLATE := 32.0
## The chip face's padding above and below its 20dp line.
const CHIP_PAD_Y := 6
## md.sys.shape.corner.large — the inner edge of a side sheet, a FAB's corner.
const CORNER_LARGE := 16
## md.sys.state layer opacities.
const HOVER := 0.08
const PRESSED := 0.10
## md.sys.elevation levels as one StyleBoxFlat shadow: shadow opacity, blur, drop — the values `tools/theme_material.py`
## writes into the theme's boxes (level 4 for a hovered FAB).
const ELEVATION := {1: Vector3(0.15, 2, 1), 2: Vector3(0.18, 4, 2), 3: Vector3(0.22, 8, 3), 4: Vector3(0.26, 10, 4)}


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


## An M3 assist chip — no fill, a 1dp `outline-variant` edge, 8dp corners, 32dp tall (`chip_height`) with a 14sp
## label-large line and an 18dp icon beside it (`chip_text_role`, `chip_glyph_size`).
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
	# 🔑 6dp above and below the line or the 18dp icon; `chip_height` holds the chip at 32dp.
	face.content_margin_top = CHIP_PAD_Y
	face.content_margin_bottom = CHIP_PAD_Y
	return face


## A chip's label is label-large — 14sp on a 20dp line (`_md-comp-assist-chip.scss` label-text).
func chip_text_role() -> StringName:
	return GoTheme.ROLE_CAPTION


## Every chip is 32dp tall (`container-height`) — a single line measures 17dp, an icon 18dp, so the padding alone
## cannot hold the height for both.
func chip_height() -> float:
	return CHIP_PLATE


## A pressable chip gets the M3 state layer: `on-surface-variant` at 8% on hover, 10% pressed.
func chip_state_box(face: StyleBox, state: StringName) -> StyleBox:
	var flat := face as StyleBoxFlat
	if flat == null or (state != &"hover" and state != &"pressed" and state != &"hover_pressed"): return face
	var layer := role(&"md_on_surface_variant", GoUi.color(GoTheme.SECONDARY))
	var amount := HOVER if state == &"hover" else PRESSED
	var lit := flat.duplicate() as StyleBoxFlat
	lit.bg_color = GoSkin.blend(Color(layer, amount), flat.bg_color) if flat.bg_color.a > 0.0 else Color(layer, amount)
	return lit


## A choice cell keeps gohud's rule — the chosen one is ringed, never filled (a filled cell mixes into a colour swatch) —
## with the M3 card corner (corner.medium) and an `on-surface` state layer on hover instead of the raised colour.
func choice_box(state: StringName) -> StyleBox:
	var face := super.choice_box(state)
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS))
	if state == &"hover":
		var rest := super.choice_box(&"normal") as StyleBoxFlat
		if rest != null: flat.bg_color = rest.bg_color.lerp(role(&"md_on_surface", GoUi.color(GoTheme.TEXT)), HOVER)
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


# ── Parts of existing widgets ──────────────────────────────────────────

## The M3 floating toolbar (`_md-comp-toolbar-floating.scss`): `surface-container`, level 3, no outline. The corner is
## corner.extra-large — a full pill on a single row, and no stadium on a taller panel (the console uses this face too).
func overlay_box(h_margin := -1, v_margin := -1, fill_alpha := -1.0) -> StyleBox:
	var face := StyleBoxFlat.new()
	var opacity := fill_alpha if fill_alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_HUD)
	face.bg_color = Color(role(&"md_surface_container", GoUi.color(GoTheme.SURFACE)), opacity)
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_LARGE))
	face.corner_detail = 16
	_lift(face, 3)
	var h := float(GoUi.metric(GoTheme.COMPACT_PADDING_X) if h_margin < 0 else h_margin)
	var v := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y) if v_margin < 0 else v_margin)
	face.content_margin_left = h
	face.content_margin_right = h
	face.content_margin_top = v
	face.content_margin_bottom = v
	return face


## A placeholder in `surface-container-highest` — the M3 colour for content that has not arrived.
func skeleton_box() -> StyleBox:
	var face := super.skeleton_box()
	var flat := face as StyleBoxFlat
	if flat != null: flat.bg_color = role(&"md_surface_container_highest", flat.bg_color)
	return face


## The M3 modal side sheet (`_md-comp-sheet-side.scss`, `_md-comp-navigation-drawer.scss`): `surface-container-low`,
## level 1, corner.large on the inner edge only — the outer edge runs into the screen's edge.
func drawer_box(at_left: bool, alpha := -1.0) -> StyleBox:
	var face := super.drawer_box(at_left, alpha)
	var flat := face as StyleBoxFlat
	if flat == null: return face
	flat.bg_color = Color(role(&"md_surface_container_low", flat.bg_color), flat.bg_color.a)
	flat.set_border_width_all(0)
	flat.set_corner_radius_all(0)
	if at_left:
		flat.corner_radius_top_right = CORNER_LARGE
		flat.corner_radius_bottom_right = CORNER_LARGE
	else:
		flat.corner_radius_top_left = CORNER_LARGE
		flat.corner_radius_bottom_left = CORNER_LARGE
	flat.corner_detail = 12
	_lift(flat, 1)
	return flat


## The small segmented control keeps the connected group's pill cells inside its floating toolbar.
func compact_segment_box(face: StyleBox, state: StringName) -> StyleBox:
	var cell := super.compact_segment_box(face, state)
	var flat := cell as StyleBoxFlat
	if flat != null and state != &"normal":
		flat.set_corner_radius_all(FULL)
		flat.corner_detail = 16
	return cell


## A 24dp icon on the 36dp icon button (`_md-comp-icon-button-small.scss` icon-size) — two thirds of the square.
func icon_button_glyph(visual_size: float) -> int:
	return maxi(8, roundi(visual_size * 2.0 / 3.0))


## A chip's leading icon is 18dp (`with-icon-icon-size`).
func chip_glyph_size() -> int:
	return 18


# ── App components ─────────────────────────────────────────────────────

## The M3 filter chip (`_md-comp-filter-chip.scss`, flat): off — no fill, a 1dp `outline-variant` edge; on —
## `secondary-container` with no edge; a state layer on hover and press; corner.small; a 32dp plate in the 48dp target.
func filter_chip_box(selected: bool, state: StringName) -> StyleBox:
	var face := StyleBoxFlat.new()
	var radius := GoUi.metric(GoTheme.RADIUS_SMALL)
	face.set_corner_radius_all(radius)
	face.corner_detail = 8
	face.content_margin_left = GoUi.metric(GoTheme.COMPACT_PADDING_X)
	face.content_margin_right = GoUi.metric(GoTheme.COMPACT_PADDING_X)
	face.content_margin_top = GoUi.metric(GoTheme.GAP_TINY)
	face.content_margin_bottom = GoUi.metric(GoTheme.GAP_TINY)
	var edge := maxf(0.0, (float(GoUi.metric(GoTheme.TOUCH)) - CHIP_PLATE) * 0.5)
	face.expand_margin_top = -edge
	face.expand_margin_bottom = -edge
	var container := role(&"md_secondary_container", GoUi.color(GoTheme.SURFACE_SOFT))
	var on_container := role(&"md_on_secondary_container", GoUi.color(GoTheme.TEXT))
	var on_variant := role(&"md_on_surface_variant", GoUi.color(GoTheme.SECONDARY))
	if state == &"focus":
		# md.sys.state.focus-indicator: 3dp `secondary`, 2dp outside the plate.
		face.draw_center = false
		face.border_color = role(&"md_secondary", GoUi.color(GoTheme.ACCENT))
		face.set_border_width_all(3)
		face.set_corner_radius_all(radius + 5)
		face.expand_margin_left = 5.0
		face.expand_margin_right = 5.0
		face.expand_margin_top = 5.0 - edge
		face.expand_margin_bottom = 5.0 - edge
		return face
	if selected:
		face.bg_color = container
		if state == &"hover": face.bg_color = container.lerp(on_container, HOVER)
		elif state == &"pressed": face.bg_color = container.lerp(on_container, PRESSED)
		elif state == &"disabled": face.bg_color = Color(role(&"md_on_surface", GoUi.color(GoTheme.TEXT)), 0.12)
		return face
	face.border_color = role(&"md_outline_variant", GoUi.color(GoTheme.BORDER))
	face.set_border_width_all(1)
	face.bg_color = Color(on_variant, 0.0)
	if state == &"hover": face.bg_color = Color(on_variant, HOVER)
	elif state == &"pressed": face.bg_color = Color(on_variant, PRESSED)
	elif state == &"disabled": face.border_color = Color(role(&"md_on_surface", GoUi.color(GoTheme.TEXT)), 0.12)
	return face


## Off: `on-surface-variant`; on: `on-secondary-container`.
func filter_chip_ink(selected: bool) -> Color:
	if selected: return role(&"md_on_secondary_container", super.filter_chip_ink(true))
	return role(&"md_on_surface_variant", super.filter_chip_ink(false))


## The M3 navigation bar (`_md-comp-nav-bar.scss`): `surface-container`, square, no outline. The navigation rail
## (`_md-comp-nav-rail-collapsed.scss`) is `surface`.
func nav_bar_box(vertical: bool) -> StyleBox:
	var face := StyleBoxFlat.new()
	if vertical: face.bg_color = role(&"md_surface", GoUi.color(GoTheme.BACKGROUND))
	else: face.bg_color = role(&"md_surface_container", GoUi.color(GoTheme.SURFACE))
	face.set_content_margin_all(0)
	return face


## The active indicator: a 56×32 pill in `secondary-container`; the state layer is `on-secondary-container`.
func nav_indicator_box(selected: bool, state: StringName) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.set_corner_radius_all(FULL)
	face.corner_detail = 16
	if state == &"focus":
		face.draw_center = false
		face.border_color = role(&"md_secondary", GoUi.color(GoTheme.ACCENT))
		face.set_border_width_all(3)
		return face
	var container := role(&"md_secondary_container", GoUi.color(GoTheme.SURFACE_SOFT))
	var layer := role(&"md_on_secondary_container", GoUi.color(GoTheme.TEXT))
	var amount := 0.0
	if state == &"hover": amount = HOVER
	elif state == &"pressed": amount = PRESSED
	face.bg_color = container.lerp(layer, amount) if selected else Color(layer, amount)
	return face


## Chosen: the icon in `on-secondary-container`, the label in `secondary`; the rest in `on-surface-variant`.
func nav_ink(selected: bool, label: bool) -> Color:
	if not selected: return role(&"md_on_surface_variant", super.nav_ink(false, label))
	if label: return role(&"md_secondary", super.nav_ink(true, true))
	return role(&"md_on_secondary_container", super.nav_ink(true, false))


## The M3 top app bar (`_md-comp-top-app-bar-small.scss`): `surface` at rest, `surface-container` at level 2 once
## the content beneath it has scrolled.
func app_bar_box(scrolled: bool) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.set_content_margin_all(0)
	if scrolled:
		face.bg_color = role(&"md_surface_container", GoUi.color(GoTheme.SURFACE))
		_lift(face, 2)
	else:
		face.bg_color = role(&"md_surface", GoUi.color(GoTheme.BACKGROUND))
	return face


## The M3 FAB (`_md-comp-fab-primary-container.scss` and the size files): `primary-container`, level 3 (4 on hover),
## corner.medium on the 40dp FAB, large on 56, large-increased on 80, extra-large on 96; the focus ring 3dp `secondary`.
func fab_box(extent: float, state: StringName) -> StyleBox:
	var face := StyleBoxFlat.new()
	var corner := 28
	if extent < 48.0: corner = 12
	elif extent < 72.0: corner = CORNER_LARGE
	elif extent < 88.0: corner = 20
	face.set_corner_radius_all(corner)
	face.corner_detail = 12
	if state == &"focus":
		face.draw_center = false
		face.border_color = role(&"md_secondary", GoUi.color(GoTheme.ACCENT))
		face.set_border_width_all(3)
		face.set_corner_radius_all(corner + 5)
		face.expand_margin_left = 5.0
		face.expand_margin_top = 5.0
		face.expand_margin_right = 5.0
		face.expand_margin_bottom = 5.0
		return face
	var container := role(&"md_primary_container", GoUi.color(GoTheme.ACCENT))
	var layer := fab_ink()
	match state:
		&"hover":
			face.bg_color = container.lerp(layer, HOVER)
			_lift(face, 4)
		&"pressed":
			face.bg_color = container.lerp(layer, PRESSED)
			_lift(face, 3)
		&"disabled":
			face.bg_color = Color(role(&"md_on_surface", GoUi.color(GoTheme.TEXT)), 0.12)
		_:
			face.bg_color = container
			_lift(face, 3)
	return face


## `on-primary-container`.
func fab_ink() -> Color:
	return role(&"md_on_primary_container", super.fab_ink())


## The M3 search bar (`_md-comp-search-bar.scss`): a 56dp `surface-container-high` pill with an `on-surface` state
## layer on hover. No shadow at rest — the bar sits in the page; the lift belongs to an expanded search view.
func search_bar_box(state: StringName) -> StyleBox:
	var face := StyleBoxFlat.new()
	var container := role(&"md_surface_container_high", GoUi.color(GoTheme.SURFACE))
	face.bg_color = container
	if state == &"hover": face.bg_color = container.lerp(role(&"md_on_surface", GoUi.color(GoTheme.TEXT)), HOVER)
	face.set_corner_radius_all(FULL)
	face.corner_detail = 16
	face.set_content_margin_all(0)
	return face


## The M3 floating toolbar (`_md-comp-toolbar-floating.scss`): `surface-container`, a full pill, level 3, 64dp tall.
## 🔑 14dp inside: the icon button node is 36dp and draws its 40dp state circle 2dp past it, so the circle lands 12dp
##    from the edge — where M3 puts it (8dp to a 48dp button whose 40dp circle sits 4dp in).
func toolbar_box(_vertical: bool) -> StyleBox:
	var face := overlay_box(14, 14, 1.0) as StyleBoxFlat
	face.set_corner_radius_all(FULL)
	return face


## The M3 split button (`_md-comp-split-button-small.scss`): the outer side keeps the pill, the inner corner is
## corner.extra-small (4dp) — corner.medium (12dp) while hovered or pressed — and the trailing half becomes a full pill
## while its menu is open (`trailing-button-inner-corner-selected-corner-size: 50%`).
## 🛑 The pill end is half the plate, not `FULL`: StyleBoxFlat shrinks every corner by one ratio once two corners add up
##    past a side, and a 999 end would squash the 4dp inner corner to nothing (the same trap as `segment_box`).
func split_button_box(face: StyleBox, leading: bool, state: StringName, open: bool) -> StyleBox:
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	var pill := int(PLATE * 0.5)
	var inner := 12 if state == &"hover" or state == &"pressed" else 4
	if not leading and open: inner = pill
	flat.set_corner_radius_all(pill)
	if leading:
		flat.corner_radius_top_right = inner
		flat.corner_radius_bottom_right = inner
	else:
		flat.corner_radius_top_left = inner
		flat.corner_radius_bottom_left = inner
	flat.corner_detail = 16
	return flat


## The M3 loading indicator (`_md-comp-loading-indicator.scss`): `primary` on its own, `on-primary-container` on a
## `primary-container` disc when contained.
func loading_colors(contained: bool) -> Array[Color]:
	if not contained: return [role(&"md_primary", GoUi.color(GoTheme.ACCENT)), Color.TRANSPARENT]
	return [role(&"md_on_primary_container", GoUi.color(GoTheme.ON_ACCENT)),
		role(&"md_primary_container", GoUi.color(GoTheme.ACCENT))]


## The M3 refresh indicator's disc: `surface-container-high` at level 1 (Flutter's M3 `RefreshIndicator`).
func refresh_disc_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = role(&"md_surface_container_high", GoUi.color(GoTheme.SURFACE))
	face.set_corner_radius_all(FULL)
	face.corner_detail = 16
	_lift(face, 1)
	face.set_content_margin_all(6)
	return face


## A banner on `surface-container-low`, square, with an `outline-variant` divider below.
func banner_box() -> StyleBox:
	var face := super.banner_box() as StyleBoxFlat
	if face == null: return super.banner_box()
	face.bg_color = role(&"md_surface_container_low", face.bg_color)
	face.border_color = role(&"md_outline_variant", face.border_color)
	return face


## The M3 outlined button (`_md-comp-button-outlined.scss`): no container, a 1dp `outline` edge, the `primary` label
## and a `primary` state layer on hover (8%) and press (10%). The pill and the 40dp plate stay the tonal button's.
func outlined_button_box(face: StyleBox, state: StringName) -> StyleBox:
	var flat := face as StyleBoxFlat
	if flat == null or state == &"focus": return face
	var primary := role(&"md_primary", GoUi.color(GoTheme.ACCENT))
	flat.bg_color = Color(primary, 0.0)
	if state == &"hover": flat.bg_color = Color(primary, HOVER)
	elif state == &"pressed" or state == &"hover_pressed": flat.bg_color = Color(primary, PRESSED)
	var edge := role(&"md_outline", GoUi.color(GoTheme.BORDER))
	flat.border_color = edge if state != &"disabled" else Color(role(&"md_on_surface", GoUi.color(GoTheme.TEXT)), 0.12)
	flat.set_border_width_all(1)
	flat.shadow_size = 0
	return flat


## `primary`.
func outlined_button_ink() -> Color:
	return role(&"md_primary", super.outlined_button_ink())


## The M3 date range picker (`_md-comp-date-picker-modal.scss`): the days between the two ends sit on a
## `secondary-container` band; the ends stay the `primary` circle.
func date_cell_box(kind: StringName, state: StringName) -> StyleBox:
	var face := super.date_cell_box(kind, state) as StyleBoxFlat
	if face == null or kind != &"in_range" or state == &"focus": return super.date_cell_box(kind, state)
	var band := role(&"md_secondary_container", face.bg_color)
	var layer := role(&"md_on_secondary_container", GoUi.color(GoTheme.TEXT))
	face.bg_color = band
	if state == &"hover": face.bg_color = band.lerp(layer, HOVER)
	elif state == &"pressed": face.bg_color = band.lerp(layer, PRESSED)
	return face


## `on-secondary-container` on the range band.
func date_ink(kind: StringName) -> Color:
	if kind == &"in_range": return role(&"md_on_secondary_container", super.date_ink(kind))
	return super.date_ink(kind)


## Flutter's M3 `Stepper`: `primary` discs with `on-primary` numbers, an `outline` ring for steps ahead, `error` for a
## step that went wrong.
func step_marker_box(state: StringName) -> StyleBox:
	var face := super.step_marker_box(state) as StyleBoxFlat
	if face == null: return super.step_marker_box(state)
	match state:
		&"error": face.bg_color = role(&"md_error", face.bg_color)
		&"todo": face.border_color = role(&"md_outline", face.border_color)
		_: face.bg_color = role(&"md_primary", face.bg_color)
	return face


func step_marker_ink(state: StringName) -> Color:
	match state:
		&"error": return role(&"md_on_error", super.step_marker_ink(state))
		&"todo": return role(&"md_on_surface_variant", super.step_marker_ink(state))
	return role(&"md_on_primary", super.step_marker_ink(state))


## The M3 time picker (`_md-comp-time-picker.scss`): the hour and minute boxes are `primary-container` while chosen
## and `surface-container-highest` otherwise; the AM/PM boxes carry a 1dp `outline` and turn `tertiary-container` when
## chosen. corner.small (8dp) all round.
func time_selector_box(selected: bool, state: StringName, period := false) -> StyleBox:
	var face := super.time_selector_box(selected, state, period) as StyleBoxFlat
	if face == null or state == &"focus": return super.time_selector_box(selected, state, period)
	face.set_corner_radius_all(8)
	var base: Color
	if period:
		base = role(&"md_tertiary_container", face.bg_color) if selected else Color(face.bg_color, 0.0)
		face.border_color = role(&"md_outline", face.border_color)
	else:
		base = role(&"md_primary_container", face.bg_color) if selected \
			else role(&"md_surface_container_highest", face.bg_color)
	var layer := time_ink(selected, period)
	face.bg_color = base
	if state == &"hover": face.bg_color = _layered(base, layer, HOVER)
	elif state == &"pressed" or state == &"hover_pressed": face.bg_color = _layered(base, layer, PRESSED)
	return face


func time_ink(selected: bool, period := false) -> Color:
	if period:
		return role(&"md_on_tertiary_container", super.time_ink(selected, period)) if selected \
			else role(&"md_on_surface_variant", super.time_ink(selected, period))
	return role(&"md_on_primary_container", super.time_ink(selected, period)) if selected \
		else role(&"md_on_surface", super.time_ink(selected, period))


## The M3 clock dial: `surface-container-highest`, a `primary` hand, `on-surface` numbers, `on-primary` under the hand.
func dial_colors() -> Array[Color]:
	var colors := super.dial_colors()
	return [role(&"md_surface_container_highest", colors[0]), role(&"md_primary", colors[1]),
		role(&"md_on_surface", colors[2]), role(&"md_on_primary", colors[3])]


## The dragged row of a reorder list rides on `surface-container-high` at level 3 with corner.medium (12dp).
func reorder_lift_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = role(&"md_surface_container_high", GoUi.color(GoTheme.SURFACE))
	face.set_corner_radius_all(12)
	face.corner_detail = 12
	_lift(face, 3)
	face.set_content_margin_all(0)
	return face


## `on-surface-variant`, as an M3 drag handle.
func reorder_grip_ink() -> Color:
	return role(&"md_on_surface_variant", super.reorder_grip_ink())


## The band of a wheel on `surface-container-highest`, corner.small.
func wheel_band_box() -> StyleBox:
	var face := super.wheel_band_box() as StyleBoxFlat
	if face == null: return super.wheel_band_box()
	face.bg_color = role(&"md_surface_container_highest", face.bg_color)
	face.set_corner_radius_all(8)
	return face


## `on-surface` on the band, `on-surface-variant` around it.
func wheel_ink(chosen: bool) -> Color:
	return role(&"md_on_surface", super.wheel_ink(chosen)) if chosen \
		else role(&"md_on_surface_variant", super.wheel_ink(chosen))


## A state layer of [param layer] at [param amount] over [param base]; a see-through base gets the layer alone.
static func _layered(base: Color, layer: Color, amount: float) -> Color:
	if base.a <= 0.0: return Color(layer, amount)
	return base.lerp(layer, amount)


## Lays M3 elevation [param level] on a face as its shadow.
static func _lift(face: StyleBoxFlat, level: int) -> void:
	var step: Vector3 = ELEVATION[level]
	face.shadow_color = Color(role(&"md_shadow", GoUi.color(GoTheme.SHADOW)), step.x)
	face.shadow_size = int(step.y)
	face.shadow_offset = Vector2(0, step.z)


## An M3 colour role from the theme's optional `md_*` tokens, or [param otherwise] when the theme has none.
static func role(key: StringName, otherwise: Color) -> Color:
	var found := GoUi.color(key)
	return otherwise if found == Color.MAGENTA else found
