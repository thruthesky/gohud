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
##    into the rect the engine asks for.
@tool
class_name GoTextureSprite
extends Texture2D

## Source art.
@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
## The size the icon takes and draws at (canvas units).
@export var draw_size := Vector2(16, 16):
	set(value):
		draw_size = value
		emit_changed()
## Multiplies the art's colours.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		emit_changed()


func _get_width() -> int:
	return int(draw_size.x)


func _get_height() -> int:
	return int(draw_size.y)


func _has_alpha() -> bool:
	return true


## The art's own pixel under ([param x], [param y]) of the drawn size.
func _is_pixel_opaque(x: int, y: int) -> bool:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0: return false
	var image := texture.get_image()
	if image == null: return true
	var px := clampi(int(x * image.get_width() / draw_size.x), 0, image.get_width() - 1)
	var py := clampi(int(y * image.get_height() / draw_size.y), 0, image.get_height() - 1)
	return image.get_pixel(px, py).a > 0.0


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(to_canvas_item, Rect2(pos, draw_size), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if texture == null: return
	texture.draw_rect(to_canvas_item, rect, tile, modulate * tint, transpose)


## [param src_rect] is in drawn units; it is scaled onto the art's pixels.
func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool,
		clip_uv: bool) -> void:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0: return
	var scale := texture.get_size() / draw_size
	var source := Rect2(src_rect.position * scale, src_rect.size * scale)
	texture.draw_rect_region(to_canvas_item, rect, source, modulate * tint, transpose, clip_uv)
