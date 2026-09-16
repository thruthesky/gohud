## ⌐ **Corner brackets.** Instead of running the whole border it draws short strokes at the corners — the mark from a scope or a tactical display.
##
## ## Why use it
## A border all the way around reads as a "box", and it catches the eye before the content inside does. Leave only the
## corners and **what is being pointed at** stays clear while the content is not covered. So it is used for focus rings,
## selection marks, and the targeting mark of a coach mark.
##
## ```gdscript
## var mark := GoStyleBoxBracket.new()
## mark.color = Color("#00E5FF")
## mark.arm = 10.0          # how far it reaches out from the corner
## button.add_theme_stylebox_override(&"focus", mark)
## ```
##
## 🛑 Padding goes through `content_margin_*` — `_get_style_margin()` is never called when you inherit in GDScript.
@tool
class_name GoStyleBoxBracket
extends StyleBox

## The color of the mark.
@export var color := Color(0.0, 0.9, 1.0, 1.0):
	set(value):
		color = value
		emit_changed()

## How far it reaches from the corner in each direction (dp).
@export_range(2.0, 48.0, 1.0) var arm := 10.0:
	set(value):
		arm = value
		emit_changed()

## The line thickness.
@export_range(0.5, 8.0, 0.5) var thickness := 2.0:
	set(value):
		thickness = value
		emit_changed()

## How far to inset the drawing into the panel. Keeps it off the target instead of hugging it.
@export_range(-16.0, 16.0, 0.5) var inset := 0.0:
	set(value):
		inset = value
		emit_changed()

## A faint background color to lay underneath. Transparent paints nothing (usually transparent).
@export var bg_color := Color.TRANSPARENT:
	set(value):
		bg_color = value
		emit_changed()

## Only the **two diagonal corners** (top-left, bottom-right) instead of all four. A lighter way to point.
@export var diagonal_only := false:
	set(value):
		diagonal_only = value
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var area := rect.grow(-inset)
	if area.size.x <= 0.0 or area.size.y <= 0.0: return
	if bg_color.a > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, area, bg_color)
	if color.a <= 0.0 or thickness <= 0.0: return
	# 🛑 If an arm passes half an edge the two arms meet and the border closes all the way around — the point of a corner mark is gone.
	var reach := minf(arm, minf(area.size.x, area.size.y) * 0.5)
	var p := area.position
	var s := area.size
	var tint := PackedColorArray([color])
	var corners := [
		[Vector2(p.x, p.y + reach), p, Vector2(p.x + reach, p.y)],                                              # top-left
		[Vector2(p.x + s.x - reach, p.y), Vector2(p.x + s.x, p.y), Vector2(p.x + s.x, p.y + reach)],            # top-right
		[Vector2(p.x + s.x, p.y + s.y - reach), p + s, Vector2(p.x + s.x - reach, p.y + s.y)],                  # bottom-right
		[Vector2(p.x + reach, p.y + s.y), Vector2(p.x, p.y + s.y), Vector2(p.x, p.y + s.y - reach)],            # bottom-left
	]
	for index in corners.size():
		if diagonal_only and index % 2 == 1: continue
		RenderingServer.canvas_item_add_polyline(to_canvas_item, PackedVector2Array(corners[index]), tint, thickness, true)


## Inner padding on all four sides at once.
func set_content_margin_all(value: float) -> void:
	content_margin_left = value
	content_margin_top = value
	content_margin_right = value
	content_margin_bottom = value
