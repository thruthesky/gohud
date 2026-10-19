## 🖌 **A painted icon at its canvas size** — a theme icon (a slider's handle, a switch's pill) drawn from PNG art made
## at 3× for sharpness, the icon twin of `GoStyleBoxSprite`.
##
## A theme icon draws at its texture's pixel size, so a 108 px handle painted for phones would draw 108 units wide. This
## texture reports `draw_size` instead and draws the whole art squeezed into it — what Magnet Mayhem's `PaintedSlider`
## and `PaintedSwitch` do with `draw_texture_rect` — so the engine's own HSlider and CheckButton lay out, hit-test and
## draw the sprite at the game's size, crisp at any canvas scale.
##
## ```gdscript
## var handle := GoTextureSprite.new()
## handle.texture = preload("res://ui/painted/slider_handle.png")
## handle.draw_size = Vector2(36, 36)            # canvas units
## slider.add_theme_icon_override(&"grabber", handle)
## ```
##
## 🔑 `tint` multiplies the art (a disabled face reuses the sprite). The art is never cut: the whole texture is drawn
##    into the rect the engine asks for. A tiled draw repeats the art every `draw_size`, not every texture pixel.
## 🔑 **Whole units.** A texture's size is whole pixels, so `draw_size` is rounded to whole units (`get_size()`), and
##    it draws at exactly that size.
## 🛑 **Draw only.** It has no RID of its own, so anything that hands the texture to the renderer by RID —
##    `StyleBoxTexture`, `NinePatchRect`, `GoStyleBoxSprite`, a shader uniform, a `MeshInstance2D` — draws nothing. Use
##    it where a Control *draws* a theme icon (`draw_texture` / `draw_texture_rect`). `get_image()` gives the art
##    resized to `get_size()`, for code that reads pixels.
@tool
class_name GoTextureSprite
extends Texture2D

## Source art.
@export var texture: Texture2D:
	set(value):
		if texture == value: return
		if texture != null and texture.changed.is_connected(_art_changed): texture.changed.disconnect(_art_changed)
		texture = value
		if texture != null: texture.changed.connect(_art_changed)
		_art_changed()
## The size the icon takes and draws at (canvas units, rounded to whole units).
@export var draw_size := Vector2(16, 16):
	set(value):
		draw_size = value
		_art_changed()
## Multiplies the art's colours.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		emit_changed()

var _image: Image


func _get_width() -> int:
	return maxi(0, roundi(draw_size.x))


func _get_height() -> int:
	return maxi(0, roundi(draw_size.y))


func _has_alpha() -> bool:
	return true


## Art pixels per drawn unit, on each axis (zero when there is nothing to draw).
func art_scale() -> Vector2:
	var size := get_size()
	if texture == null or size.x <= 0.0 or size.y <= 0.0: return Vector2.ZERO
	return texture.get_size() / size


## [param src_rect] (in drawn units) on the art's pixels.
func source_rect(src_rect: Rect2) -> Rect2:
	var scale := art_scale()
	return Rect2(src_rect.position * scale, src_rect.size * scale)


## The colour the art is drawn with under [param modulate].
func draw_color(modulate: Color) -> Color:
	return modulate * tint


## A tiled draw of [param rect]: `[dest, source]` pairs, one per copy of the art, the last row and column cut to fit
## (the source in art pixels). With [param transpose] the art lies on its side, so a copy is `draw_size` swapped.
func tile_rects(rect: Rect2, transpose := false) -> Array[Array]:
	var out: Array[Array] = []
	var cell := get_size()
	if transpose: cell = Vector2(cell.y, cell.x)
	if cell.x <= 0.0 or cell.y <= 0.0 or texture == null: return out
	var area := rect.abs()
	var y := 0.0
	while y < area.size.y:
		var h := minf(cell.y, area.size.y - y)
		var x := 0.0
		while x < area.size.x:
			var w := minf(cell.x, area.size.x - x)
			var part := Vector2(w, h)
			var src := Vector2(h, w) if transpose else part
			out.append([Rect2(area.position + Vector2(x, y), part), source_rect(Rect2(Vector2.ZERO, src))])
			x += cell.x
		y += cell.y
	return out


## The art resized to `get_size()`, made once and kept until the art or the size changes.
func _get_image() -> Image:
	if _image == null and texture != null and _get_width() > 0 and _get_height() > 0:
		var art := texture.get_image()
		if art != null:
			art = art.duplicate() as Image
			if art.is_compressed(): art.decompress()
			art.resize(_get_width(), _get_height(), Image.INTERPOLATE_LANCZOS)
			_image = art
	return _image


## The art's own pixel under ([param x], [param y]) of the drawn size.
func _is_pixel_opaque(x: int, y: int) -> bool:
	var image := _get_image()
	if image == null: return texture != null
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): return false
	return image.get_pixel(x, y).a > 0.0


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(to_canvas_item, Rect2(pos, get_size()), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if texture == null: return
	if not tile:
		texture.draw_rect(to_canvas_item, rect, false, draw_color(modulate), transpose)
		return
	for pair: Array in tile_rects(rect, transpose):
		texture.draw_rect_region(to_canvas_item, pair[0], pair[1], draw_color(modulate), transpose, false)


## [param src_rect] is in drawn units; it is scaled onto the art's pixels.
func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool,
		clip_uv: bool) -> void:
	if art_scale() == Vector2.ZERO: return
	texture.draw_rect_region(to_canvas_item, rect, source_rect(src_rect), draw_color(modulate), transpose, clip_uv)


func _art_changed() -> void:
	_image = null
	emit_changed()
