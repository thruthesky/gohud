## 🖼️ **A picture that fills its box** — CSS `object-fit: cover`: the texture is scaled until it covers the
## whole rect, keeping its proportions, and the overflow is cut off. [member focus] picks which part stays.
##
## ```gdscript
## var shot := GoCoverImage.make(preload("res://art/level_3.png"), Vector2(0.5, 0.3))   # keep the upper middle
## shot.custom_minimum_size = Vector2(74, 74)
## ```
##
## 🛑 Nothing is drawn outside the rect — only the visible part of the texture is sampled, so it needs no
##    `clip_contents` on the parent. It ignores the mouse, so a card or button under it still takes the press.
@tool
class_name GoCoverImage
extends Control

## The picture.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Which point of the picture stays in view, 0..1 on each axis — (0.5, 0.5) keeps the centre, (0.5, 0) the top.
@export var focus := Vector2(0.5, 0.5):
	set(value):
		focus = value.clamp(Vector2.ZERO, Vector2.ONE)
		queue_redraw()


func _init() -> void:
	name = "CoverImage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func make(picture: Texture2D, keep := Vector2(0.5, 0.5)) -> GoCoverImage:
	var node := GoCoverImage.new()
	node.texture = picture
	node.focus = keep
	return node


## 🔑 Where a [param tex_size] picture lands when it covers [param area] — scaled by the larger of the two ratios,
## then slid so [param keep] lines up. The rect is in the area's own space and may reach past it.
static func cover_rect(area: Vector2, tex_size: Vector2, keep := Vector2(0.5, 0.5)) -> Rect2:
	if area.x <= 0.0 or area.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0: return Rect2(Vector2.ZERO, area)
	var sx := area.x / tex_size.x
	var sy := area.y / tex_size.y
	var drawn := Vector2(area.x, tex_size.y * sx) if sx >= sy else Vector2(tex_size.x * sy, area.y)
	return Rect2(-(drawn - area) * keep, drawn)


func _draw() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0: return
	var tex_size := texture.get_size()
	var drawn := cover_rect(size, tex_size, focus)
	# Sample only the part inside the rect: the visible window, mapped back to texture pixels.
	var ratio := tex_size / drawn.size
	var source := Rect2(-drawn.position * ratio, size * ratio)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), source)
