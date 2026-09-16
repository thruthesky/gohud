## 🛸 **The sci-fi shapes.** Rounded becomes chamfered, circles become hexagons and diamonds, the ring becomes a reticle.
##
## ## What it overrides
## The theme (`gohud_scifi_*.tres`) has already turned the buttons, cards and input fields into chamfered
## panels. But **the places code draws itself** are out of the theme's reach — the joystick's circle, the
## quick slot's panel, the coach mark's ring, the chip, the skeleton, the avatar. Only those are redrawn
## here. Anything not overridden keeps `GoSkin`'s default shape.
##
## 🛑 `GoSkin`'s default implementation **passes a custom StyleBox from the theme straight through.** So
##    things like `surface_box()` need no override — the chamfered panel already arrives intact.
@tool
class_name GoSkinSciFi
extends GoSkin

# ── Sci-fi dials — change only the numbers, from the skin resource (.tres) ───
# 🛑 If you change a default, change `tools/skin_dials.json` with it — a check compares the two.
@export_group("Sci-fi dials")
# 🔑 One `##` line per dial — the site generator fills the dial table and the glossary from these lines.
## Size of the chamfered corner on a chip panel (dp).
@export var cut_chip := 7.0
## Size of the chamfered corner on a skeleton panel (dp).
@export var cut_skeleton := 5.0
## Size of the chamfered corner on an alert panel (dp).
@export var cut_alert := 8.0
## Size of the chamfered corner on a segmented control panel (dp).
@export var cut_segment := 8.0
## Size of the chamfered corner on a quick slot panel (dp).
@export var cut_slot := 6.0
## Chamfer on an avatar or disc = diameter × this ratio.
@export var cut_disc_ratio := 0.24
## Opacity of the glow on a slot running a cooldown.
@export var slot_glow_alpha := 0.45
## Reach of the glow on a slot running a cooldown (dp).
@export var slot_glow_size := 6.0
## Arm length of the coach mark reticle (dp).
@export var bracket_arm := 12.0
## Line thickness of the coach mark reticle (dp).
@export var bracket_thickness := 2.0
@export_group("")


# ── Surfaces ───────────────────────────────────────────────────────────

## When an accent is given, take not just the border but **the accent edge** into that colour — that one line is the identity of a chamfered panel.
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var style := super(variant, accent, alpha)
	var cut := style as GoStyleBoxCut
	if cut != null and accent.a > 0 and cut.edge_color.a > 0:
		cut.edge_color = Color(accent, cut.edge_color.a)
	return style


## **A slanted sliver** instead of a pill. Chamfering two of the four corners gives it a direction.
func chip_box(color: Color) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = Color(color, chip_fill_alpha)
	box.border_color = Color(color, chip_edge_alpha)
	box.border_width = 1.0
	box.cut = cut_chip
	box.cut_corners = GoStyleBoxCut.DIAGONAL
	box.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	box.content_margin_right = GoUi.metric(GoTheme.GAP_SMALL)
	box.content_margin_top = GoUi.metric(GoTheme.GAP_TINY)
	box.content_margin_bottom = GoUi.metric(GoTheme.GAP_TINY)
	return box


func skeleton_box() -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	box.border_color = Color(GoUi.color(GoTheme.ACCENT), 0.22)
	box.border_width = 1.0
	box.cut = cut_skeleton
	return box


## A chamfered badge instead of a circle — used for the icon spot on avatars and prompt cards.
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = Color(accent, fill_alpha)
	box.border_color = Color(accent, edge_alpha)
	box.border_width = 1.0
	box.cut = maxf(2.0, diameter * cut_disc_ratio)
	box.cut_corners = GoStyleBoxCut.ALL
	return box


## An alert box with a thick bar standing on its left — in a list the eye catches that bar first.
func alert_box(ink: Color, alpha := -1.0) -> StyleBox:
	var box := GoStyleBoxCut.new()
	# 🛑 The panel is built from scratch here — so the opacity is applied here too (there is no parent panel to apply it).
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_CARD)
	box.bg_color = GoUi.color(GoTheme.SURFACE).lerp(ink, 0.12)
	box.border_color = Color(ink, 0.5)
	box.border_width = 1.0
	box.cut = cut_alert
	box.edge_color = ink
	box.edge_width = 3.0
	box.edge_side = SIDE_LEFT
	box.set_content_margin_all(GoUi.metric(GoTheme.GAP))
	return fade_box(box, opacity)


## Segmented control — chamfer only the two ends and butt the middle segments together square.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var box := GoStyleBoxCut.new()
	var accent := GoUi.color(GoTheme.ACCENT)
	if state == &"pressed" or state == &"hover_pressed":
		box.bg_color = accent
	elif state == &"hover":
		box.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	else:
		box.bg_color = GoUi.color(GoTheme.SURFACE_SOFT)
	box.border_color = Color(GoUi.color(GoTheme.BORDER), 0.9)
	box.border_width = 0.0 if index > 0 else 1.0
	box.cut = cut_segment
	var mask := 0
	if index == 0: mask |= GoStyleBoxCut.TOP_LEFT | GoStyleBoxCut.BOTTOM_LEFT
	if index == count - 1: mask |= GoStyleBoxCut.TOP_RIGHT | GoStyleBoxCut.BOTTOM_RIGHT
	box.cut_corners = mask
	return box


## An accent bar to the left of a section heading — it makes the screen read as divided into blocks.
func section_box() -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.draw_center = false
	box.border_width = 0.0
	box.cut = 0.0
	box.edge_color = GoUi.color(GoTheme.ACCENT)
	box.edge_width = 3.0
	box.edge_side = SIDE_LEFT
	box.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	return box


## Dividers in the accent colour — they read like the lines of an instrument panel parcelling out the screen.
func divider_color() -> Color:
	return Color(GoUi.color(GoTheme.ACCENT), 0.55)


# ── HUD ────────────────────────────────────────────────────────────────

## Quick slot — a chamfered panel with an instrument line along the top. A glow joins it while a cooldown runs.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 0.8), slot_tint_lit if lit else slot_tint_idle)
	box.border_color = Color(accent, 0.95 if lit else 0.5)
	box.border_width = 2.0 if lit else 1.0
	box.cut = cut_slot
	box.edge_color = Color(accent, 0.9 if lit else 0.45)
	box.edge_width = 2.0
	box.edge_side = SIDE_TOP
	# 🛑 Glow only while lit — slots are laid out several at a time, so leaving it always on multiplies the draw cost by that many.
	if lit:
		box.glow_color = Color(accent, slot_glow_alpha)
		box.glow_size = slot_glow_size
	return box


## The mark a coach mark puts around its target — no border all the way round, just **the four corners**.
func coach_ring_box(accent: Color) -> StyleBox:
	var mark := GoStyleBoxBracket.new()
	mark.color = accent
	mark.arm = bracket_arm
	mark.thickness = bracket_thickness
	mark.bg_color = Color(accent, 0.06)
	return mark


# ── Drawn directly ─────────────────────────────────────────────────────

## Joystick — a hexagonal ring, eight-way ticks, a diamond knob and a centre cross.
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	var ring := _hexagon(center, radius)
	canvas.draw_colored_polygon(ring, Color(base, 0.40))
	var loop := ring.duplicate()
	loop.append(ring[0])
	canvas.draw_polyline(loop, Color(ink, 0.5), 2.0, true)
	# Eight-way ticks — which way you are pushing only reads if there are ticks to read it against.
	for step in 8:
		var heading := Vector2.RIGHT.rotated(TAU * float(step) / 8.0)
		canvas.draw_line(center + heading * (radius - 9.0), center + heading * (radius - 3.0),
			Color(ink, 0.30), 1.5, true)
	canvas.draw_colored_polygon(_diamond(knob, knob_radius), Color(ink, 0.85 if active else 0.5))
	canvas.draw_line(center - Vector2(5, 0), center + Vector2(5, 0), Color(ink, 0.55), 1.0, true)
	canvas.draw_line(center - Vector2(0, 5), center + Vector2(0, 5), Color(ink, 0.55), 1.0, true)


## The coach mark's pointer — dashes instead of a continuous line. It looks like a leader line on an instrument panel.
func draw_coach_pointer(canvas: CanvasItem, start: Vector2, tip: Vector2,
		direction: Vector2, ink: Color) -> void:
	var span := start.distance_to(tip)
	var dashes := clampi(int(span / 7.0), 1, 64)
	for step in dashes:
		# 🛑 Draw every other span — draw them all and it is simply a solid line.
		if step % 2 == 1: continue
		var from := start.lerp(tip, float(step) / float(dashes))
		var to := start.lerp(tip, minf(float(step + 1) / float(dashes), 1.0))
		canvas.draw_line(from, to, Color(ink, 0.9), 2.0, true)
	var wing := direction.orthogonal() * 5.0
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, tip - direction * 9.0 + wing, tip - direction * 9.0 - wing]), ink)


# ── Shapes ─────────────────────────────────────────────────────────────

func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for step in 6:
		out.append(center + Vector2.RIGHT.rotated(TAU * float(step) / 6.0) * radius)
	return out


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0)])
