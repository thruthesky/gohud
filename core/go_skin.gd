## 🖌️ **The one sheet that decides the look.** Everything a theme cannot reach — the spots the code draws itself — is gathered here.
##
## ## Why a theme alone is not enough
## `Theme` only changes the look of **what the engine draws for you**. But gohud has spots the
## code draws on its own: the joystick circles, the quick-slot panel, the coach-mark ring and
## arrow, chips, skeletons, alert boxes. These are built as a `StyleBoxFlat` in code or painted
## in `_draw()`, so no matter which `.tres` you swap in, **round corners never turn angular.**
## Pulling every one of those decisions out into this resource is what the skin is.
##
## ```gdscript
## # To make your own look, extend this and override only what you need.
## class_name MySkin extends GoSkin
## func slot_box(accent: Color, lit: bool) -> StyleBox:
##     var box := GoStyleBoxCut.new()
##     box.bg_color = accent
##     return box
##
## # How to plug it in — one of three
## GoUi.config.skin = preload("res://ui/my_skin.tres")   # ① directly
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)            # ② bundled with a theme
## # ③ do nothing — this default skin draws gohud's original look.
## ```
##
## ## 🛑 The body of this class **is gohud's original look itself**
## The code here was scattered across `GoStyle`·`GoSlot`·`GoJoystick`·`GoCoachMark`·`GoNotice` and
## was moved over **without changing a single line**. So with no skin plugged in, the screen is
## identical to what it was, down to the pixel. The same holds for methods a child skin does not
## override — partial replacement is safe.
##
## ## 🛑 This file never references a widget
## It uses only `GoUi`'s token lookups (`color`·`metric`·`box`). Referencing a widget would close
## the cycle `GoUi → GoConfig → GoSkin → widget → GoStyle → GoUi`.
@tool
class_name GoSkin
extends Resource

## The name shown on screen (used by the pickers in the editor and the gallery). Empty means the resource name.
@export var skin_name := ""

# ── Dials — change nothing but the numbers, from a skin **resource (.tres)** ─
#
# 🔑 Numbers that used to be hard-coded were pulled out (2026-09-13 — a request for more freedom
#    per theme). Without extending `GoSkin` you can change the slot border width or the joystick
#    ring opacity through `skin.dials` in `themes/palettes/<id>.json`. 🛑 If you change a default,
#    change `tools/skin_dials.json` with it — a check compares the two (the scaffolding spells out
#    "what you can change" from that table).
@export_group("Dials")
# 🔑 One `##` line per dial — the site generator (`tools/make_site.py`) reads these lines to fill the
#    dial table and the glossary. Grouped into one line, the table can only tell `_lit` from `_idle` by their order (I-72).
## Opacity of the chip panel fill.
@export var chip_fill_alpha := 0.16
## Opacity of the chip panel border.
@export var chip_edge_alpha := 0.45
## How far the alert box panel is tinted toward the state color.
@export var alert_tint := 0.10
## How far a cooling-down quick-slot panel is tinted toward the accent color.
@export var slot_tint_lit := 0.24
## How far an idle quick-slot panel is tinted toward the accent color.
@export var slot_tint_idle := 0.08
## Border width of a cooling-down quick slot (dp).
@export var slot_border_lit := 2
## Border width of an idle quick slot (dp).
@export var slot_border_idle := 1
## Horizontal inner padding of the badge (quantity·remaining time) panel (dp).
@export var badge_pad_x := 5
## Vertical inner padding of the badge panel (dp).
@export var badge_pad_y := 1
## Opacity of the badge panel border.
@export var badge_edge_alpha := 0.6
## Opacity of the shadow under a floating card (coach mark·prompt card).
## 🛑 Too shallow (8dp·0.35) and "it floats" does not read once it sits on an info panel (2026-09-13 demo measurement, I-69).
@export var float_shadow_alpha := 0.45
## Blur of the floating card shadow (dp).
@export var float_shadow_size := 14
## How far the floating card shadow is pushed downward (dp).
@export var float_shadow_lift := 4
## Glow distance (dp) when a panel that uses a **glow** instead of a shadow — the cut panels (sci-fi) — is floating.
@export var float_glow_size := 10.0
## Opacity of the joystick base circle.
@export var joystick_base_alpha := 0.42
## Opacity of the joystick ring.
@export var joystick_ring_alpha := 0.45
## Width of the joystick ring (dp).
@export var joystick_ring_width := 2.0
@export_group("")


# ── Making it readable ─────────────────────────────────────────────────
#
# 🛑 **Same-color text on a same-color tint** looks pretty and does not read. Chips (`accent` text on
#    an `accent` 16% panel) and the remaining time on a cooling-down slot are exactly that — the panel
#    brightens toward the text and the luminance gap disappears. On the theme side the generator
#    precomputes it, but **the colors a skin makes at runtime** get pushed here.

## WCAG relative luminance. 🛑 Do not use `Color.get_luminance()` — it does not undo gamma, so it
## differs from the WCAG value, and it is off by a lot on dark colors in particular.
static func luminance(color: Color) -> float:
	var parts := [color.r, color.g, color.b]
	var linear := []
	for value in parts:
		linear.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


## Contrast ratio between two colors (1~21).
static func contrast_ratio(front: Color, back: Color) -> float:
	var a := luminance(front)
	var b := luminance(back)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## Lay a translucent color over what is beneath it to get **the color actually seen**.
static func blend(top: Color, bottom: Color) -> Color:
	if top.a >= 1.0: return top
	return Color(
		top.r * top.a + bottom.r * (1.0 - top.a),
		top.g * top.a + bottom.g * (1.0 - top.a),
		top.b * top.a + bottom.b * (1.0 - top.a), 1.0)


## 🔑 Push `ink` until it reads on `back` — **keep the hue, move only the brightness**.
##
## It goes darker on a bright background and brighter on a dark one. A color whose brightness is
## already at the end of the road (pure cyan and the like) is brightened further by dropping
## saturation. If 60 pushes still do not clear the bar it stops there — bolting to black or white
## wipes out the character of the palette wholesale, and that is a failure regardless of readability.
static func readable_on(ink: Color, back: Color, need := 4.5) -> Color:
	var flat := blend(ink, back)
	if contrast_ratio(flat, back) >= need: return ink
	var darker := luminance(back) > 0.22
	var out := Color(flat.r, flat.g, flat.b, 1.0)
	for _step in 60:
		if darker:
			out = Color.from_hsv(out.h, out.s, maxf(0.0, out.v - 0.02), 1.0)
		elif out.v >= 0.999:
			out = Color.from_hsv(out.h, maxf(0.0, out.s - 0.035), 1.0, 1.0)
		else:
			out = Color.from_hsv(out.h, out.s, minf(1.0, out.v + 0.02), 1.0)
		if contrast_ratio(out, back) >= need: return out
	return out


## 🪟 Lower **only the panel background's opacity** — borders, shadows, glow and texture are untouched.
##
## ## Why only the background
## A translucent panel reads like glass only when **its outline stays crisp**. If the border thins
## out with it you cannot tell where the panel ends, and you get a "blurry screen" that looks broken
## rather than transparent. Text and icons are untouched for the same reason — those are `modulate`'s
## job, and being readable comes first.
##
## ## 🛑 It **multiplies**, it does not overwrite
## Some panels the theme already decided to make translucent (the HUD panel of the default theme is
## 0.92). Overwriting would erase that decision, so it multiplies as a ratio — 0.92 × 0.80 = 0.736.
## Which means **calling it twice thins it twice**: apply alpha to a panel in **exactly one place**
## (`surface_box` is that place).
##
## A negative [param alpha] does nothing — it is the value that passes "not decided" straight through.
static func fade_box(box: StyleBox, alpha: float) -> StyleBox:
	if box == null or alpha < 0.0 or alpha >= 1.0: return box
	if not (&"bg_color" in box): return box
	var fill: Color = box.get(&"bg_color")
	# An already transparent panel (one that draws only an outline) is left alone — multiplying by 0 is still 0, but this says so plainly.
	if fill.a <= 0.0: return box
	box.set(&"bg_color", Color(fill, fill.a * alpha))
	return box


## The StyleBox background color (transparent if it has none). Custom StyleBoxes use the `bg_color` field too.
static func box_background(box: StyleBox) -> Color:
	if box == null: return Color.TRANSPARENT
	if not (&"bg_color" in box): return Color.TRANSPARENT
	var value = box.get(&"bg_color")
	return value if value is Color else Color.TRANSPARENT


# ── Surfaces ───────────────────────────────────────────────────────────

## StyleBox for cards and panels. If `accent` is set, the border takes that color.
##
## 🔑 If the theme handed over a **custom StyleBox** (a cut panel and the like) it comes back as is — that is the road to a different shape.
## 🛑 `0.5` — this value is the norm of the game gohud grew out of. It was written as 0.55 once, and the delegation comparison check caught it (2026-09-12).
## [param alpha] is the **panel background's opacity** (0.0~1.0). Negative uses the value the theme and
## config decided (`GoUi.surface_alpha(variant)`) — per-variant tokens, project settings and individual overrides are merged there.
## 🛑 **This is the one place opacity is applied.** The panels that call it (`floating_box`·`notice_box` …)
##    do not apply alpha themselves but pass it in through this argument — applied twice, it thins twice (see `fade_box`).
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var style := GoUi.box(variant)
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(variant)
	var flat := style as StyleBoxFlat
	if flat == null:
			# The theme handed over something that is not a StyleBoxFlat. If it is an empty box, build a
			# fresh flat one as before; if it is a custom box that actually draws, keep it.
		if style != null and not (style is StyleBoxEmpty):
			if accent.a > 0 and &"border_color" in style: style.set(&"border_color", Color(accent, 0.5))
			return fade_box(style, opacity)
		flat = StyleBoxFlat.new()
		flat.bg_color = GoUi.color(GoTheme.SURFACE)
	if accent.a > 0: flat.border_color = Color(accent, 0.5)
	return fade_box(flat, opacity)


## A surface **floating** over the game screen — the same card with a shallow shadow added.
## [param alpha] works as in `surface_box` (negative uses the theme·config value).
func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	var style := surface_box(variant, accent, alpha)
	var flat := style as StyleBoxFlat
	if flat == null:
			# 🛑 A cut panel cannot draw a shadow — it says "floating" by **growing the glow** instead. A panel with no glow (color 0) is left as is.
		if &"glow_size" in style and &"glow_color" in style and (style.get(&"glow_color") as Color).a > 0.0:
			style.set(&"glow_size", maxf(float(style.get(&"glow_size")), float_glow_size))
		return style
	flat.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha)
	flat.shadow_size = float_shadow_size
	flat.shadow_offset = Vector2(0, float_shadow_lift)
	return flat


## A **pill panel laid over** the game screen (map·world) — filled dark with the background color and thinly bordered so the text reads over whatever picture is behind it.
## `h_margin`·`v_margin` are the panel's inner padding (dp) — negative uses the compact button padding token. `fill_alpha` is the background opacity.
## 🔑 **Never put a panel inside a panel** — keep the buttons in this pill as `GoBareButton` or `segmented()` cells
##    so the borders do not stack into a double outline.
func overlay_box(h_margin := -1, v_margin := -1, fill_alpha := -1.0) -> StyleBox:
	# 🛑 The background is **overwritten below**, so alpha is not left to `surface_box` (left there, it gets multiplied twice).
	var style := surface_box(GoTheme.BOX_HUD, Color.TRANSPARENT, 1.0)
	var opacity := fill_alpha if fill_alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_HUD)
	var flat := style as StyleBoxFlat
	if flat != null:
		flat.bg_color = Color(GoUi.color(GoTheme.BACKGROUND), opacity)
		flat.border_color = Color(GoUi.color(GoTheme.BORDER), 0.9)
		flat.set_border_width_all(1)
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS))
		flat.shadow_size = 0
	else:
		# Custom panels (cut·medieval) do not take the branch above — apply the same opacity to their background.
		fade_box(style, opacity)
	var h := float(GoUi.metric(GoTheme.COMPACT_PADDING_X) if h_margin < 0 else h_margin)
	var v := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y) if v_margin < 0 else v_margin)
	style.content_margin_left = h
	style.content_margin_right = h
	style.content_margin_top = v
	style.content_margin_bottom = v
	return style


## Round badge·avatar border — faintly filled with accent and ringed in the same color.
## 🛑 It does not follow the panel opacity (`GoTheme.HUD_ALPHA`) — a disc is a **marker** and already carries its own `fill_alpha`.
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var style := surface_box(GoTheme.BOX_HUD, accent, 1.0)
	var flat := style as StyleBoxFlat
	if flat == null: return style
	flat.bg_color = Color(accent, fill_alpha)
	flat.border_color = Color(accent, edge_alpha)
	flat.set_border_width_all(1)
	# 🛑 With a radius exactly half the side (31+31=62) a seam shows where the top and bottom corners meet.
	#    Drop it by just 1 and raise the corner detail and it is gone — to the eye it is still a circle.
	flat.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
	flat.corner_detail = 16
	flat.set_content_margin_all(0)
	flat.shadow_size = 0
	return flat


## Panel for a small pill marker (state·tag·quantity).
func chip_box(color: Color) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, chip_fill_alpha)
	style.border_color = Color(color, chip_edge_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	style.corner_detail = 8
	style.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	style.content_margin_right = GoUi.metric(GoTheme.GAP_SMALL)
	style.content_margin_top = GoUi.metric(GoTheme.GAP_TINY)
	style.content_margin_bottom = GoUi.metric(GoTheme.GAP_TINY)
	return style


## Chip **text color** — the value pushed until it reads on the chip panel. 🛑 A chip is the textbook
## spot for same-color text on a same-color tint (it fell to 3.5:1 on the light theme — measured 2026-09-13).
func chip_ink(color: Color) -> Color:
	var back := blend(box_background(chip_box(color)), GoUi.color(GoTheme.SURFACE_SOFT))
	return readable_on(color, back)


## Text color laid over the quick-slot panel (remaining time and the like).
func slot_ink(accent: Color, lit: bool) -> Color:
	var back := blend(box_background(slot_box(accent, lit)), GoUi.color(GoTheme.SURFACE_SOFT))
	return readable_on(accent, back)


## Panel for a section heading (`GoStyle.section()`). 🛑 By default it **draws nothing** — the original
## look is a single dim line of text, and drawing anything here would be changing that default look.
## A skin that wants a marker overrides it.
func section_box() -> StyleBox:
	return StyleBoxEmpty.new()


## Color of a single divider line. This is where the rhythm of the screen comes from.
func divider_color() -> Color:
	return GoUi.color(GoTheme.BORDER)


## Thickness of the divider (dp).
func divider_thickness() -> float:
	return 1.0


## A faint panel holding the place of content that has not arrived yet.
func skeleton_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	return face


## Panel for an alert box fixed inside the screen. `ink` is the tone color.
## [param alpha] is the panel background opacity (negative uses the card value) — an alert box is **a container placed inside a card**.
func alert_box(ink: Color, alpha := -1.0) -> StyleBox:
	# 🛑 The background is **overwritten** by tinting toward the tone color, so alpha goes on after that (applied first, it gets erased).
	var style := surface_box(GoTheme.BOX_CARD, ink, 1.0)
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_CARD)
	var flat := style as StyleBoxFlat
	if flat == null: return fade_box(style, opacity)
	flat.bg_color = GoUi.color(GoTheme.SURFACE).lerp(ink, alert_tint)
	flat.set_border_width_all(1)
	return fade_box(flat, opacity)


## One cell of a segmented control. Round at the two ends and square in the middle — it reads as a single block.
## `state` is `&"normal"`·`&"hover"`·`&"pressed"`·`&"hover_pressed"`·`&"focus"`.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	# 🛑 It does not follow the panel opacity — a segmented control is **something you press**, and a thinned-out button stops showing its state.
	var style := surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0)
	var face := style as StyleBoxFlat
	if face == null: return style
	if state == &"pressed" or state == &"hover_pressed":
		face.bg_color = GoUi.color(GoTheme.ACCENT)
	elif state == &"hover":
		face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	var radius := GoUi.metric(GoTheme.RADIUS_SMALL)
	face.corner_radius_top_left = radius if index == 0 else 0
	face.corner_radius_bottom_left = radius if index == 0 else 0
	face.corner_radius_top_right = radius if index == count - 1 else 0
	face.corner_radius_bottom_right = radius if index == count - 1 else 0
	face.border_width_left = 0 if index > 0 else face.border_width_left
	return face


## Panel for one cell of a choice grid (`GoStyle.choice_grid`). `state` is `&"normal"`·`&"hover"`·`&"pressed"`·
## `&"hover_pressed"`·`&"focus"`·`&"disabled"`.
## 🛑 The chosen cell is **not filled** with the accent — the accent mixes into the swatch and it looks like a different color. Give it a thicker border instead.
## 🛑 The inner padding has to be the same in every state or the cell shifts when you press it.
func choice_box(state: StringName) -> StyleBox:
	if state == &"focus":
		var ring := GoUi.box(GoTheme.BOX_FOCUS_SOFT)
		_choice_insets(ring)
		return ring
	# 🛑 It does not follow the panel opacity — a choice cell is a button (same reason as `segment_box`).
	var style := surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0)
	_choice_insets(style)
	var face := style as StyleBoxFlat
	if face == null:
		if (state == &"pressed" or state == &"hover_pressed") and &"border_color" in style:
			style.set(&"border_color", GoUi.color(GoTheme.ACCENT))
		return style
	face.shadow_size = 0
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	match state:
		&"pressed", &"hover_pressed":
			face.border_color = GoUi.color(GoTheme.ACCENT)
			face.set_border_width_all(CHOICE_RING)
		&"hover":
			face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
		&"disabled":
			face.bg_color = Color(face.bg_color, face.bg_color.a * 0.5)
	return face


## Border width of the chosen cell in a choice grid (dp). It has to be clearly thicker than the default panel border (1) to be seen at a glance.
const CHOICE_RING := 3


func _choice_insets(box: StyleBox) -> void:
	if box == null: return
	var inset := float(GoUi.metric(GoTheme.GAP_SMALL))
	box.content_margin_left = inset
	box.content_margin_right = inset
	box.content_margin_top = inset
	box.content_margin_bottom = inset


## Panel for a color swatch disc. Filled with **the exact color from the game data**, and bordered so the disc's edge shows against any background.
func swatch_box(diameter: float, color: Color) -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = color
	flat.border_color = GoUi.color(GoTheme.BORDER)
	flat.set_border_width_all(1)
	# 🛑 A radius of exactly half the side shows a seam (same reason as `disc_box`).
	flat.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
	flat.corner_detail = 16
	flat.set_content_margin_all(0)
	return flat


## The **fill** of a value bar. 🛑 Duplicate the theme's `ProgressBar/fill` and edit that — borrowing
##    the card style drags its inner padding (12dp) along and turns a thin bar into a fat block.
func progress_fill_box(ink: Color) -> StyleBox:
	var source: StyleBox = null
	for candidate in [GoUi.theme(), GoUi.DEFAULT_THEME]:
		if candidate != null and candidate.has_stylebox(&"fill", &"ProgressBar"):
			source = candidate.get_stylebox(&"fill", &"ProgressBar")
			break
	var copied := source.duplicate() as StyleBox if source != null else null
	var flat := copied as StyleBoxFlat
	if flat == null:
		if copied != null and not (copied is StyleBoxEmpty):
			if &"bg_color" in copied: copied.set(&"bg_color", ink)
				# 🛑 If there is a glow, **its color follows the fill too** — pinned, a red health bar glows cyan.
			if &"glow_color" in copied:
				var glow: Color = copied.get(&"glow_color")
				if glow.a > 0.0: copied.set(&"glow_color", Color(ink, glow.a))
			_edge_fill(copied, ink)
			return copied
		flat = StyleBoxFlat.new()
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	flat.bg_color = ink
	_edge_fill(flat, ink)
	return flat


## 🛑 **A fill that melts into the track tells you nothing about how full it is.** The light theme's
##    yellow is exactly that — its luminance is high to begin with, so it never reaches 3:1 over any
##    gray track, and pushing it darker to meet the bar turns the experience bar **brown**
##    (measured 2026-09-13: `#A05000`). Instead of killing the color, **draw the boundary with an
##    outline** — the fill stays vivid and the border carries the contrast.
func _edge_fill(box: StyleBox, ink: Color) -> void:
	if box == null: return
	var track := blend(GoUi.color(GoTheme.TRACK), GoUi.color(GoTheme.SURFACE))
	if contrast_ratio(blend(ink, track), track) >= 3.0: return
	# Push toward whichever of darker·lighter **opens the bigger gap** from the track, until it clears the bar.
	var pick := ink
	for step in range(1, 11):
		var amount := 0.1 * float(step)
		var dark := ink.darkened(amount)
		var light := ink.lightened(amount)
		pick = dark if contrast_ratio(dark, track) >= contrast_ratio(light, track) else light
		if contrast_ratio(pick, track) >= 3.0: break
	if &"border_color" in box: box.set(&"border_color", pick)
	# 🛑 A custom StyleBox has **one** border-width field, while `StyleBoxFlat` has four separate sides.
	#    The sci-fi fill is custom, and leaving this branch out left the outline undrawn entirely (measured).
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		flat.set_border_width_all(1)
		flat.draw_center = true
	elif &"border_width" in box:
		box.set(&"border_width", maxf(1.0, float(box.get(&"border_width"))))


# ── HUD ────────────────────────────────────────────────────────────────

## Panel for the **small badge** (quantity·shortcut) laid on a slot corner. Hanging it over the corner
## instead of stacking icon and text vertically leaves the icon large and centered (2026-09-13 — stacked
## vertically it was cramped). The panel shape comes from `surface_box`, so on sci-fi it turns into an angular badge by itself.
func badge_box(ink: Color) -> StyleBox:
	# 🛑 It does not follow the panel opacity — a badge is a **marker** that has to keep two characters readable, and it lies on top of the panel below.
	var style := surface_box(GoTheme.BOX_HUD, ink, 1.0)
	style.content_margin_left = badge_pad_x
	style.content_margin_right = badge_pad_x
	style.content_margin_top = badge_pad_y
	style.content_margin_bottom = badge_pad_y
	if &"bg_color" in style: style.set(&"bg_color", GoUi.color(GoTheme.SURFACE_HIGH))
	if &"border_color" in style: style.set(&"border_color", Color(ink, badge_edge_alpha))
	var flat := style as StyleBoxFlat
	if flat != null:
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
		flat.set_border_width_all(1)
		flat.shadow_size = 0
	elif &"glow_size" in style:
		style.set(&"glow_size", 0)
	return style


## Panel for one quick slot. `lit` means a cooldown·remaining time is running.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	# 🛑 It does not follow the panel opacity — a quick slot is **a cell you press** and speaks its state through the cooldown tint.
	var style := surface_box(GoTheme.BOX_HUD, accent, 1.0)
	var flat := style as StyleBoxFlat
	if flat == null: return style
	flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	flat.set_content_margin_all(0)
	flat.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 0.8), slot_tint_lit if lit else slot_tint_idle)
	flat.border_color = Color(accent, 0.95 if lit else 0.45)
	flat.set_border_width_all(slot_border_lit if lit else slot_border_idle)
	# 🛑 Do not use `shadow_size` — a StyleBoxFlat shadow draws one more rectangle separate from the body.
	#    Slots are laid out several at a time on screen, so that drawing cost is multiplied by as many.
	flat.shadow_size = 0
	return flat


## Panel for a snackbar. `compact` gives it tighter padding.
## [param alpha] is the panel background opacity (negative uses `GoTheme.NOTICE_ALPHA`).
func notice_box(accent: Color, compact: bool, alpha := -1.0) -> StyleBox:
	var surface := surface_box(GoTheme.BOX_NOTICE, accent, alpha)
	if compact: surface.set_content_margin_all(GoUi.metric(GoTheme.PADDING_COMPACT))
	return surface


## Change **only the accent color** of a snackbar panel already in place — no new surface is built.
func tint_notice(box: StyleBox, accent: Color) -> void:
	if box == null or accent.a <= 0: return
	if &"border_color" in box: box.set(&"border_color", Color(accent, 0.55))


## The ring a coach mark draws around its target control.
func coach_ring_box(accent: Color) -> StyleBox:
	var ring := disc_box(48, accent, 0.0, 1.0)
	if &"border_width_left" in ring:
		ring.set(&"border_width_left", 2)
		ring.set(&"border_width_top", 2)
		ring.set(&"border_width_right", 2)
		ring.set(&"border_width_bottom", 2)
	return ring


# ── Direct drawing ─────────────────────────────────────────────────────

## The virtual joystick. Coordinates and state are computed by the widget and passed in — this **only draws**.
## 🛑 Draw shapes of the same kind together — the canvas breaks the draw call every time the command type changes.
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	canvas.draw_circle(center, radius, Color(base, joystick_base_alpha))
	canvas.draw_circle(knob, knob_radius, Color(ink, 0.85 if active else 0.55))
	canvas.draw_arc(center, radius, 0, TAU, 48, Color(ink, joystick_ring_alpha), joystick_ring_width, true)


## The arrow reaching from the coach-mark card to its target.
func draw_coach_pointer(canvas: CanvasItem, start: Vector2, tip: Vector2,
		direction: Vector2, ink: Color) -> void:
	canvas.draw_line(start, tip, ink, 2.0, true)
	var wing := direction.orthogonal() * 4.0
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, tip - direction * 8.0 + wing, tip - direction * 8.0 - wing]), ink)
