## 🖼 **A framed face** — a flat fill cut as a chamfered polygon, with a transparent painted 9-slice frame over it.
##
## Painted frames (bevels, energy hairlines, corner studs) look best as art, but a painted body cannot change colour
## per state and stretches its gradients. So the body is a **flat colour** drawn in code — a polygon inset from the
## rectangle with every corner cut on the diagonal (radius 0) — and the art is only the **frame**: a transparent PNG
## drawn on top in nine slices, exactly as `GoStyleBoxSprite` draws it (it is a `GoStyleBoxSprite`). One frame PNG then
## serves every state: the states differ by fill colour, frame tint or another frame.
##
## ```gdscript
## var face := GoStyleBoxFrame.new()
## face.texture = preload("res://ui/frames/button_primary.png")  # transparent, 180 × 180 at 3×
## face.edge = Vector4(30, 30, 30, 30)        # texture px: left, top, right, bottom
## face.pixels_per_unit = 3.0                 # the art is drawn at a third of its size → 10 units of frame
## face.bg_color = Color("#0C7A99")           # the flat body under the frame
## face.fill_inset = 3.0                      # the body starts 3 units inside the rectangle…
## face.fill_cut = 7.0                        # …with 7-unit diagonal corners
## face.set_content_margin_all(12.0)
## GoStyle.style_frame(button, GoStyle.frame_states(face))   # normal · hover · pressed · focus · disabled
## ```
##
## ## 🛑 Padding is the built-in `content_margin_*`
## `_get_style_margin()` is never called for a GDScript StyleBox (measured on 4.7) — set `content_margin_*` per use.
## `frame_margin(side)` (inherited) reports how far the painted frame reaches, so a scroll inside clips under it.
## 🛑 The colour names **match `StyleBoxFlat`** (`bg_color`, `draw_center`, `shadow_color`, `shadow_size`,
##    `shadow_offset`) — `GoStyle._flat_like`, `GoSkin.box_background` and the brand-button code look those names up.
##    `bg_color` also becomes `face_color`, the colour contrast checks measure text against.
## 🔑 Cost: one polygon for the body, up to four for the shadow and nine texture rects — drawn only when the control
##    redraws. No shader. The art is a texture: import it without mipmaps unless it is drawn far smaller than its pixels.
@tool
class_name GoStyleBoxFrame
extends GoStyleBoxSprite

## The flat body drawn under the frame. Transparent draws no body (a frame only — a focus ring over another face).
@export var bg_color := Color(0.04, 0.11, 0.17, 1.0):
	set(value):
		bg_color = value
		face_color = value
		emit_changed()
## How far inside the rectangle the body starts (canvas units) — it hides under the frame's outer border.
@export_range(0.0, 32.0, 0.5) var fill_inset := 3.0:
	set(value):
		fill_inset = value
		emit_changed()
## The diagonal cut on each corner of the body (canvas units). 0 = square corners.
@export_range(0.0, 48.0, 0.5) var fill_cut := 7.0:
	set(value):
		fill_cut = value
		emit_changed()
## The drop shadow's colour. Transparent draws none.
@export var shadow_color := Color(0, 0, 0, 0):
	set(value):
		shadow_color = value
		emit_changed()
## How far the shadow spreads past the body (canvas units) — a soft edge made of a few fading copies.
@export_range(0.0, 24.0, 0.5) var shadow_size := 0.0:
	set(value):
		shadow_size = value
		emit_changed()
## Where the shadow sits, relative to the body (canvas units).
@export var shadow_offset := Vector2.ZERO:
	set(value):
		shadow_offset = value
		emit_changed()


func _init() -> void:
	face_color = bg_color


## The body outline for [param rect]: inset by `fill_inset`, every corner cut by `fill_cut` (clockwise from the top left).
func fill_outline(rect: Rect2) -> PackedVector2Array:
	var body := rect.grow(-fill_inset)
	var out := PackedVector2Array()
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		return out
	# 🛑 A cut longer than half an edge tangles the outline — small chips and thin bars do get that small.
	var c := minf(fill_cut, minf(body.size.x, body.size.y) * 0.5)
	var p := body.position
	var e := body.end
	if c <= 0.0:
		out.append_array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)])
		return out
	out.append_array([
		Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c),
	])
	return out


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if shadow_color.a > 0.0:
		_draw_shadow(to_canvas_item, rect)
	if draw_center and bg_color.a > 0.0:
		var body := fill_outline(rect)
		if body.size() >= 3:
			RenderingServer.canvas_item_add_polygon(to_canvas_item, body, PackedColorArray([bg_color]))
	super._draw(to_canvas_item, rect)


## A soft shadow from a few copies of the body, each a little larger and fainter (falling off with the square, so the
## edge does not read as bands — the same rule as `GoStyleBoxCut`'s glow).
func _draw_shadow(to_canvas_item: RID, rect: Rect2) -> void:
	var base := rect.grow(-fill_inset)
	base.position += shadow_offset
	var steps := clampi(int(ceilf(shadow_size / 2.0)), 1, 4)
	# Each copy carries an even share of the alpha, so the middle (where every copy overlaps) lands near `shadow_color.a`
	# whatever the step count; the outer copies fade with the square of their distance.
	var share := 1.0 - pow(1.0 - shadow_color.a, 1.0 / float(steps))
	for step in range(steps, 0, -1):
		var spread := shadow_size * float(step) / float(steps)
		var falloff := 1.0 - float(step - 1) / float(steps)
		var tint := Color(shadow_color, share * falloff * falloff)
		var shape := fill_outline(base.grow(spread + fill_inset))
		if shape.size() >= 3:
			RenderingServer.canvas_item_add_polygon(to_canvas_item, shape, PackedColorArray([tint]))


## The shadow reaches outside the rectangle — widen the rect the engine lets this box draw in.
func _get_draw_rect(rect: Rect2) -> Rect2:
	if shadow_color.a <= 0.0 or (shadow_size <= 0.0 and shadow_offset == Vector2.ZERO):
		return rect
	var grown := rect.grow(shadow_size)
	return grown.merge(Rect2(grown.position + shadow_offset, grown.size))


## Inner padding on all four sides at once — the same convenience as `StyleBoxFlat.set_content_margin_all()`.
func set_content_margin_all(value: float) -> void:
	content_margin_left = value
	content_margin_top = value
	content_margin_right = value
	content_margin_bottom = value
