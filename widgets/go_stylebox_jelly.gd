## 🍬 **A jelly candy face** — the toy box's buttons, panels and fields (the `kids_*` looks).
##
## A thick outline, a body light on top and deeper below (two tones), a white shine at the top left, and a solid
## lip under it in the outline's colour. Pressed, the lip goes and the body sinks into its place. A text field is
## the same jelly turned in (`sunken`): the deep band sits at the top like a shadow inside a well, with no lip or shine.
##
## ```gdscript
## var key := GoStyleBoxJelly.new()
## key.bg_color = Color("#8FE05A")           # the light top of the body
## key.border_color = Color("#22704A")       # outline + lip (transparent: a deep shade of bg_color)
## key.radius = 18.0
## key.lip = 5.0
## button.add_theme_stylebox_override(&"normal", key)
## var down := key.duplicate() as GoStyleBoxJelly
## down.pressed = true                       # the lip goes, the face sinks — the button keeps its size
## button.add_theme_stylebox_override(&"pressed", down)
## ```
##
## ## 🛑 Sizes never change
## The lip and the outline are drawn **inside** the rectangle, and nothing here adds to the minimum size. Padding is
## the built-in `content_margin_*` (`_get_style_margin()` is never called for a GDScript StyleBox — measured on 4.7);
## `keep_margins()` copies another face's padding so a control keeps its size when its face becomes jelly, and `pad()`
## lifts the label by half the lip so it sits in the middle of the body.
##
## 🛑 The field names **match `StyleBoxFlat`** (`bg_color`, `border_color`, `draw_center`, `shadow_*`) and
##    `GoStyleBoxMedieval` (`border_width`, `radius`) — `GoSkin.fade_box`, `box_background`, `_edge_fill` and
##    `GoStyle._flat_like` look those names up. Fading (`bg_color.a`) fades the body and the shine, never the outline
##    (a container fades its face only — rule 13 of the gohud skill).
## 🔑 Drawn from a handful of `StyleBoxFlat`s, only when the control redraws — no texture, no shader, no per-frame cost.
@tool
class_name GoStyleBoxJelly
extends StyleBox

## The light top of the body — the colour text is measured against (`GoSkin.box_background`).
@export var bg_color := Color("#8FE05A"):
	set(value):
		bg_color = value
		emit_changed()
## The deeper band under it. Transparent: `bg_color` leaning towards the outline (a deeper candy, never grey).
@export var shade_color := Color(0, 0, 0, 0):
	set(value):
		shade_color = value
		emit_changed()
## The outline and the lip. Transparent: `bg_color` much darker.
@export var border_color := Color(0, 0, 0, 0):
	set(value):
		border_color = value
		emit_changed()
## The outline on every side (dp).
@export var border_width := 3.0:
	set(value):
		border_width = value
		emit_changed()
## The lip under the outline (dp) — what makes it a key you press.
@export var lip := 4.0:
	set(value):
		lip = value
		emit_changed()
## Corner radius (dp). More than half the short side makes a pill or a disc.
@export var radius := 16.0:
	set(value):
		radius = value
		emit_changed()
## How much of the body the deeper band takes (0–0.9; 0 is one tone).
@export_range(0.0, 0.9) var band := 0.36:
	set(value):
		band = value
		emit_changed()
## The deepest the band may be (dp, 0 = no limit) — a tall window keeps a thin band instead of a stripe across its rows.
@export var band_max := 0.0:
	set(value):
		band_max = value
		emit_changed()
## The white shine at the top left (0 = none).
@export_range(0.0, 1.0) var shine := 0.6:
	set(value):
		shine = value
		emit_changed()
## A text field's well: the band at the top as a shadow inside, no lip, no shine.
@export var sunken := false:
	set(value):
		sunken = value
		emit_changed()
## Pressed: the body sinks by `sink` and the lip shrinks by as much (never below 1).
@export var pressed := false:
	set(value):
		pressed = value
		emit_changed()
## How far a pressed face sinks (dp). Negative: all of the lip but 1.
@export var sink := -1.0:
	set(value):
		sink = value
		emit_changed()
@export var draw_center := true:
	set(value):
		draw_center = value
		emit_changed()
## A thin line just inside the body — a window's second frame. Transparent: none.
@export var inner_line := Color(0, 0, 0, 0):
	set(value):
		inner_line = value
		emit_changed()
## The largest the candy is drawn (dp, 0 = the whole rectangle) — a small candy centred in a 48dp press area.
@export var max_size := Vector2.ZERO:
	set(value):
		max_size = value
		emit_changed()
## Grows the drawn face past the control's edges, or shrinks it (negative) — `StyleBoxFlat`'s names, so a widget that
## sets them on a skin's face (`GoDatePicker`'s round day inside its 48dp cell) works on a jelly face too.
@export var expand_margin_left := 0.0:
	set(value):
		expand_margin_left = value
		emit_changed()
@export var expand_margin_top := 0.0:
	set(value):
		expand_margin_top = value
		emit_changed()
@export var expand_margin_right := 0.0:
	set(value):
		expand_margin_right = value
		emit_changed()
@export var expand_margin_bottom := 0.0:
	set(value):
		expand_margin_bottom = value
		emit_changed()
@export var shadow_color := Color(0, 0, 0, 0):
	set(value):
		shadow_color = value
		emit_changed()
@export var shadow_size := 0:
	set(value):
		shadow_size = value
		emit_changed()
@export var shadow_offset := Vector2(0, 3):
	set(value):
		shadow_offset = value
		emit_changed()

var _flat := StyleBoxFlat.new()


func _init() -> void:
	_flat.anti_aliasing = true


## The outline colour actually drawn.
func edge() -> Color:
	return border_color if border_color.a > 0.0 else Color(bg_color.darkened(0.48), 1.0)


## The band colour actually drawn. 🛑 Not `darkened()`: towards black a white key's band turns grey and a peach row's
## turns brown — towards its own outline the band stays the candy's colour.
func shade() -> Color:
	return shade_color if shade_color.a > 0.0 else Color(bg_color.lerp(edge(), 0.22), 1.0)


## `StyleBoxFlat`'s name — this face has one outline width for every side (the lip is `lip`).
func set_border_width_all(width: int) -> void:
	border_width = width


func set_corner_radius_all(value: int) -> void:
	radius = value


## Copies [param source]'s padding — the control keeps its size when its face becomes jelly.
func keep_margins(source: StyleBox) -> GoStyleBoxJelly:
	if source != null:
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			set_content_margin(side, source.get_margin(side))
	return self


## Sets the padding, lifting the label by half the lip so it sits in the middle of the body (the sum is kept).
func pad(horizontal: float, vertical: float) -> GoStyleBoxJelly:
	var rise := (maxf(0.0, lip) if not sunken else 0.0) * 0.5
	content_margin_left = horizontal
	content_margin_right = horizontal
	content_margin_top = maxf(0.0, vertical - rise)
	content_margin_bottom = vertical + rise
	return self


func _draw(canvas: RID, rect: Rect2) -> void:
	rect = rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0: return
	if max_size.x > 0.0 and rect.size.x > max_size.x:
		rect = Rect2(rect.position.x + (rect.size.x - max_size.x) * 0.5, rect.position.y, max_size.x, rect.size.y)
	if max_size.y > 0.0 and rect.size.y > max_size.y:
		rect = Rect2(rect.position.x, rect.position.y + (rect.size.y - max_size.y) * 0.5, rect.size.x, max_size.y)
	var outline := maxf(0.0, border_width)
	var base := maxf(0.0, lip) if not sunken else 0.0
	var outer := rect
	if pressed and base > 1.0:
		var drop := minf(base - 1.0, sink) if sink >= 0.0 else base - 1.0
		outer.position.y += drop
		outer.size.y -= drop
		base -= drop
	var corner := minf(radius, minf(outer.size.x, outer.size.y) * 0.5)
	var alpha := bg_color.a
	if not draw_center:
		_box(canvas, outer, Color.TRANSPARENT, corner, edge(), outline, base)
		return
	var face := Rect2(outer.position + Vector2(outline, outline), outer.size - Vector2(outline * 2.0, outline * 2.0 + base))
	var inner := maxf(0.0, corner - outline)
	# The outline and the lip. An opaque body is laid on one face of the outline colour (with the shadow of a floating
	# panel); 🛑 a see-through body (a danger key's tint, a faded HUD panel) would show that colour through it, so it
	# gets a ring instead, and its lower corners follow the ring's thicker bottom.
	var solid := alpha >= 0.999
	var low_corner := inner if solid else maxf(0.0, corner - outline - base)
	if outline > 0.0 or base > 0.0:
		if solid: _box(canvas, outer, edge(), corner, Color.TRANSPARENT, 0.0, 0.0, true)
		else: _box(canvas, outer, Color.TRANSPARENT, corner, edge(), outline, base, true)
	if face.size.x <= 1.0 or face.size.y <= 1.0: return
	if sunken:
		# A well: the deep band shows at the top as the shadow inside, the light body below it.
		_body(canvas, face, Color(shade(), alpha), inner, low_corner)
		var dip := clampf(face.size.y * 0.14, 2.0, 5.0)
		_body(canvas, Rect2(face.position + Vector2(0.0, dip), face.size - Vector2(0.0, dip)), Color(bg_color, alpha),
			inner, low_corner)
	else:
		if band > 0.0:
			# Two tones: the deep band underneath, the light top over it — its lower corners round too, so it reads as jelly.
			_body(canvas, face, Color(shade(), alpha), inner, low_corner)
			var low := face.size.y * band
			if band_max > 0.0: low = minf(low, band_max)
			var upper := Rect2(face.position, Vector2(face.size.x, face.size.y - low))
			_flat.bg_color = Color(bg_color, alpha)
			_flat.draw_center = true
			_flat.set_border_width_all(0)
			_flat.corner_radius_top_left = int(inner)
			_flat.corner_radius_top_right = int(inner)
			_flat.corner_radius_bottom_left = int(minf(inner, upper.size.y * 0.5))
			_flat.corner_radius_bottom_right = int(minf(inner, upper.size.y * 0.5))
			_flat.corner_detail = _detail(inner)
			_flat.shadow_size = 0
			_flat.draw(canvas, upper)
		else:
			_body(canvas, face, Color(bg_color, alpha), inner, low_corner)
		# The shine: a white pill at the top left, and a dot after it on a wide face.
		if shine > 0.0 and face.size.y >= 12.0 and face.size.x >= 12.0:
			var tall := clampf(face.size.y * 0.15, 2.5, 8.0)
			var start := face.position + Vector2(maxf(inner * 0.55, 4.0), maxf(2.0, face.size.y * 0.1))
			var spot := Rect2(start, Vector2(minf(clampf(face.size.x * 0.3, tall * 1.8, 96.0), face.end.x - start.x - 4.0), tall))
			if spot.size.x > tall:
				_box(canvas, spot, Color(1, 1, 1, shine * 0.7 * alpha), tall * 0.5)
				if face.size.x > face.size.y * 1.6:
					var dot := Rect2(Vector2(spot.end.x + tall * 0.7, start.y), Vector2(tall, tall))
					if dot.end.x < face.end.x - inner * 0.5:
						_box(canvas, dot, Color(1, 1, 1, shine * 0.6 * alpha), tall * 0.5)
	if inner_line.a > 0.0 and face.size.x > 40.0 and face.size.y > 40.0:
		_box(canvas, face.grow(-4.0), Color.TRANSPARENT, maxf(0.0, inner - 4.0), Color(inner_line, inner_line.a * alpha), 2.0)


## One rounded box: [param fill], an outline of [param width] in [param ink] with [param bottom] more under it.
func _box(canvas: RID, at: Rect2, fill: Color, corner: float, ink := Color.TRANSPARENT, width := 0.0,
		bottom := 0.0, with_shadow := false) -> void:
	_flat.bg_color = fill
	_flat.draw_center = fill.a > 0.0
	_flat.border_color = ink
	var side := int(width) if ink.a > 0.0 else 0
	_flat.border_width_left = side
	_flat.border_width_top = side
	_flat.border_width_right = side
	_flat.border_width_bottom = side + int(bottom) if ink.a > 0.0 else 0
	_flat.set_corner_radius_all(int(corner))
	_flat.corner_detail = _detail(corner)
	if with_shadow and shadow_size > 0 and shadow_color.a > 0.0:
		_flat.shadow_color = shadow_color
		_flat.shadow_size = shadow_size
		_flat.shadow_offset = shadow_offset
	else:
		_flat.shadow_size = 0
	_flat.draw(canvas, at)


## The body: [param top] corners above, [param bottom] below.
func _body(canvas: RID, at: Rect2, fill: Color, top: float, bottom: float) -> void:
	_flat.bg_color = fill
	_flat.draw_center = true
	_flat.set_border_width_all(0)
	_flat.corner_radius_top_left = int(top)
	_flat.corner_radius_top_right = int(top)
	_flat.corner_radius_bottom_left = int(bottom)
	_flat.corner_radius_bottom_right = int(bottom)
	_flat.corner_detail = _detail(top)
	_flat.shadow_size = 0
	_flat.draw(canvas, at)


## A big corner is drawn smooth, a small one saves vertices.
static func _detail(corner: float) -> int:
	return clampi(int(corner * 0.5), 3, 16)


func _get_draw_rect(rect: Rect2) -> Rect2:
	rect = rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	if shadow_size <= 0 or shadow_color.a <= 0.0: return rect
	var spread := float(shadow_size)
	return rect.grow(spread).merge(Rect2(rect.position + shadow_offset, rect.size).grow(spread))
