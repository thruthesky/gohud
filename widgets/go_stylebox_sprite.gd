## 🖌 **A painted 9-slice box** — a face drawn from PNG art, the way `arcade_light` draws its painted plates.
##
## `StyleBoxTexture` draws its corners at texture pixels, so art made at 3× for sharpness on phones would draw three
## times too big. This box divides every edge by `pixels_per_unit`, so the same sprite is crisp at any canvas scale.
## The nine pieces are cut from the art at `edge` and stretched into the rectangle; the corners keep their size.
##
## ```gdscript
## var plate := GoStyleBoxSprite.new()
## plate.texture = preload("res://ui/painted/gloss_green.png")
## plate.edge = Vector4(48, 42, 48, 54)          # texture px: left, top, right, bottom
## plate.pixels_per_unit = 3.0                   # the art is drawn at a third of its size
## plate.face_color = Color("#7BE36A")           # what contrast checks measure text against (never drawn)
## button.add_theme_stylebox_override(&"normal", plate)
## var down := plate.duplicate() as GoStyleBoxSprite
## down.tint = Color(0.85, 0.85, 0.85)           # pressed and hover shades reuse one sprite
## button.add_theme_stylebox_override(&"pressed", down)
## ```
##
## ## 🛑 Same pixels as the game's `SpriteBox`
## `dest_rects`, `source_rects` and `_draw` are the Magnet Mayhem `SpriteBox` line for line — the same maths in the same
## order and the same `canvas_item_add_texture_rect_region` call — so a screen moved onto gohud draws exactly what it
## drew before. Change them only together with that reference.
## 🔑 A texture has no `bg_color`, so `face_color` carries the plate's nominal colour for the contrast checks.
## 🔑 Padding is the built-in `content_margin_*` (set it per use); `frame_margin()` reports the painted edge so a
##    scroll inside clips under the frame (`GoSkin.frame_margin`).
@tool
class_name GoStyleBoxSprite
extends StyleBox

## Source art.
@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
## Fixed border widths in texture pixels: x = left, y = top, z = right, w = bottom.
@export var edge := Vector4.ZERO:
	set(value):
		edge = value
		emit_changed()
## Texture pixels per canvas unit (3 = the art is drawn at a third of its size).
@export var pixels_per_unit := 1.0:
	set(value):
		pixels_per_unit = value
		emit_changed()
## Multiplies the sprite's colours (pressed / hover shades reuse one sprite).
@export var tint := Color.WHITE:
	set(value):
		tint = value
		emit_changed()
## False leaves the middle empty (a frame only).
@export var draw_center := true:
	set(value):
		draw_center = value
		emit_changed()
## The plate's nominal colour — what contrast checks read, since a texture has no `bg_color`. Never drawn.
@export var face_color := Color(0, 0, 0, 0):
	set(value):
		face_color = value
		emit_changed()


## The nine destination rects (row by row) for `rect`. Edges shrink together when the rect is smaller than they are.
func dest_rects(rect: Rect2) -> Array[Rect2]:
	var l: float = edge.x / pixels_per_unit
	var t: float = edge.y / pixels_per_unit
	var r: float = edge.z / pixels_per_unit
	var b: float = edge.w / pixels_per_unit
	if l + r > rect.size.x:
		var k: float = rect.size.x / (l + r)
		l *= k
		r *= k
	if t + b > rect.size.y:
		var k: float = rect.size.y / (t + b)
		t *= k
		b *= k
	var xs: Array[float] = [rect.position.x, rect.position.x + l, rect.end.x - r, rect.end.x]
	var ys: Array[float] = [rect.position.y, rect.position.y + t, rect.end.y - b, rect.end.y]
	var out: Array[Rect2] = []
	for row: int in 3:
		for col: int in 3:
			out.append(Rect2(xs[col], ys[row], xs[col + 1] - xs[col], ys[row + 1] - ys[row]))
	return out


## The nine source rects (texture pixels), in the same order.
func source_rects() -> Array[Rect2]:
	var size: Vector2 = texture.get_size() if texture != null else Vector2.ZERO
	var xs: Array[float] = [0.0, edge.x, size.x - edge.z, size.x]
	var ys: Array[float] = [0.0, edge.y, size.y - edge.w, size.y]
	var out: Array[Rect2] = []
	for row: int in 3:
		for col: int in 3:
			out.append(Rect2(xs[col], ys[row], xs[col + 1] - xs[col], ys[row + 1] - ys[row]))
	return out


## How far in from [param side] the painted frame reaches (canvas units) — read by `GoSkin.frame_margin`.
func frame_margin(side: Side) -> float:
	return edge[side] / pixels_per_unit


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	_draw_nine(to_canvas_item, rect, tint)


## Draws the nine slices multiplied by [param modulate] (`_draw` passes `tint`; a subclass may pass a faded copy).
func _draw_nine(to_canvas_item: RID, rect: Rect2, modulate: Color) -> void:
	if texture == null or modulate.a <= 0.0:
		return
	var dst: Array[Rect2] = dest_rects(rect)
	var src: Array[Rect2] = source_rects()
	for i: int in 9:
		if i == 4 and not draw_center:
			continue
		if dst[i].size.x <= 0.0 or dst[i].size.y <= 0.0:
			continue
		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, dst[i], texture.get_rid(), src[i], modulate)
