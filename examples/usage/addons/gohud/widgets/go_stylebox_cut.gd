## ⬡ **A panel with its corners cut on the diagonal.** It gives the angular look that rounded corners (`StyleBoxFlat`) cannot.
##
## ## Why a new StyleBox
## The corners of `StyleBoxFlat` are **rounded and nothing else**. A radius of 0 is a right angle, and there is nothing in between.
## Corners cut on the diagonal, a single emphasized edge, a glow bleeding outwards — the engine draws none of it.
## So we draw them ourselves — and this goes into a `Theme` as it is and saves as a `.tres`.
##
## ```gdscript
## var box := GoStyleBoxCut.new()
## box.bg_color = Color("#0B121C")
## box.border_color = Color("#2A6F8F")
## box.cut = 10.0                                  # size of the cut
## box.cut_corners = GoStyleBoxCut.DIAGONAL        # top-left and bottom-right only
## box.edge_color = Color("#00E5FF")               # the emphasized top edge
## panel.add_theme_stylebox_override(&"panel", box)
## ```
##
## ## 🛑 Padding goes through `content_margin_*`
## `_get_style_margin()` is never called when you inherit in GDScript (measured on 4.7). If you need inner padding,
## fill in the **built-in fields** such as `content_margin_left` — leave them empty and the content sticks to the border.
##
## 🛑 The color property names **deliberately match** `StyleBoxFlat` (`bg_color`, `border_color`). gohud's skins do
##    "tint the border with the accent color" by looking those names up, so a different name silently does nothing.
@tool
class_name GoStyleBoxCut
extends StyleBox

## Which corners to cut (a bitmask). `DIAGONAL` is the sci-fi default.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_RIGHT := 4
const BOTTOM_LEFT := 8
## Top-left + bottom-right — it reads as flowing in one direction.
const DIAGONAL := TOP_LEFT | BOTTOM_RIGHT
## All four corners.
const ALL := TOP_LEFT | TOP_RIGHT | BOTTOM_RIGHT | BOTTOM_LEFT

## The panel's background color.
@export var bg_color := Color(0.06, 0.09, 0.13, 1.0):
	set(value):
		bg_color = value
		emit_changed()

## Whether to paint the background. Off leaves only the border (a focus ring).
@export var draw_center := true:
	set(value):
		draw_center = value
		emit_changed()

## The border color.
@export var border_color := Color(0.16, 0.43, 0.56, 1.0):
	set(value):
		border_color = value
		emit_changed()

## Border width (0 draws no border).
@export_range(0.0, 8.0, 0.5) var border_width := 1.0:
	set(value):
		border_width = value
		emit_changed()

## The size of the corner cut (dp).
@export_range(0.0, 48.0, 0.5) var cut := 8.0:
	set(value):
		cut = value
		emit_changed()

## Which corners to cut. A combination of the constants above.
@export_flags("Top left:1", "Top right:2", "Bottom right:4", "Bottom left:8") var cut_corners := DIAGONAL:
	set(value):
		cut_corners = value
		emit_changed()

## Color of the **emphasized edge**, the one side drawn thicker. Transparent draws none.
@export var edge_color := Color.TRANSPARENT:
	set(value):
		edge_color = value
		emit_changed()

## Thickness of the emphasized edge.
@export_range(0.0, 8.0, 0.5) var edge_width := 2.0:
	set(value):
		edge_width = value
		emit_changed()

## Which side the emphasized edge goes on (`SIDE_TOP`, …).
@export_enum("Left:0", "Top:1", "Right:2", "Bottom:3") var edge_side := 1:
	set(value):
		edge_side = value
		emit_changed()

## Color of the glow bleeding outside the panel. Transparent means none.
@export var glow_color := Color.TRANSPARENT:
	set(value):
		glow_color = value
		emit_changed()

## How far the glow spreads (dp). 🛑 A big value means that much overdraw — keep it small where many of these stack up, such as a HUD.
@export_range(0.0, 24.0, 1.0) var glow_size := 0.0:
	set(value):
		glow_size = value
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# The outer glow first — the body is drawn over it.
	if glow_color.a > 0.0 and glow_size > 0.0:
		var steps := clampi(int(glow_size / 2.0), 2, 7)
		for step in range(steps, 0, -1):
			var spread := glow_size * float(step) / float(steps)
			# 🛑 Fainter the further out — falling off with the square. Linear falloff makes the edge look **cut into bands**.
			var falloff := 1.0 - float(step - 1) / float(steps)
			var tint := Color(glow_color, glow_color.a * falloff * falloff)
			RenderingServer.canvas_item_add_polygon(to_canvas_item, outline(rect.grow(spread)), PackedColorArray([tint]))

	var points := outline(rect)
	if draw_center and bg_color.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([bg_color]))

	if border_width > 0.0 and border_color.a > 0.0:
		var loop := points.duplicate()
		loop.append(points[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([border_color]), border_width, true)

	if edge_color.a > 0.0 and edge_width > 0.0:
		var line := _edge_line(rect)
		RenderingServer.canvas_item_add_polyline(to_canvas_item, line, PackedColorArray([edge_color]), edge_width, true)


## The glow goes outside the panel, so the rect it may draw in is widened.
func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(glow_size) if glow_size > 0.0 else rect


## The outline with the cut corners applied (clockwise). Skins also use it to draw something on top in the same shape.
func outline(rect: Rect2) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	# 🛑 Cut away more than half an edge and the outline tangles with itself — which does happen on small chips and thin bars.
	var c := minf(cut, minf(s.x, s.y) * 0.5)
	var out := PackedVector2Array()
	if c <= 0.0 or cut_corners == 0:
		out.append(p)
		out.append(Vector2(p.x + s.x, p.y))
		out.append(p + s)
		out.append(Vector2(p.x, p.y + s.y))
		return out
	if cut_corners & TOP_LEFT: out.append(Vector2(p.x + c, p.y))
	else: out.append(p)
	if cut_corners & TOP_RIGHT:
		out.append(Vector2(p.x + s.x - c, p.y))
		out.append(Vector2(p.x + s.x, p.y + c))
	else:
		out.append(Vector2(p.x + s.x, p.y))
	if cut_corners & BOTTOM_RIGHT:
		out.append(Vector2(p.x + s.x, p.y + s.y - c))
		out.append(Vector2(p.x + s.x - c, p.y + s.y))
	else:
		out.append(p + s)
	if cut_corners & BOTTOM_LEFT:
		out.append(Vector2(p.x + c, p.y + s.y))
		out.append(Vector2(p.x, p.y + s.y - c))
	else:
		out.append(Vector2(p.x, p.y + s.y))
	if cut_corners & TOP_LEFT: out.append(Vector2(p.x, p.y + c))
	return out


func _edge_line(rect: Rect2) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	var c := minf(cut, minf(s.x, s.y) * 0.5)
	var half := edge_width * 0.5
	match edge_side:
		SIDE_LEFT:
			var top := c if cut_corners & TOP_LEFT else 0.0
			var bottom := c if cut_corners & BOTTOM_LEFT else 0.0
			return PackedVector2Array([Vector2(p.x + half, p.y + top), Vector2(p.x + half, p.y + s.y - bottom)])
		SIDE_RIGHT:
			var top := c if cut_corners & TOP_RIGHT else 0.0
			var bottom := c if cut_corners & BOTTOM_RIGHT else 0.0
			return PackedVector2Array([Vector2(p.x + s.x - half, p.y + top), Vector2(p.x + s.x - half, p.y + s.y - bottom)])
		SIDE_BOTTOM:
			var left := c if cut_corners & BOTTOM_LEFT else 0.0
			var right := c if cut_corners & BOTTOM_RIGHT else 0.0
			return PackedVector2Array([Vector2(p.x + left, p.y + s.y - half), Vector2(p.x + s.x - right, p.y + s.y - half)])
		_:
			var left := c if cut_corners & TOP_LEFT else 0.0
			var right := c if cut_corners & TOP_RIGHT else 0.0
			return PackedVector2Array([Vector2(p.x + left, p.y + half), Vector2(p.x + s.x - right, p.y + half)])


## Inner padding on all four sides at once — the same convenience function as `StyleBoxFlat.set_content_margin_all()`.
func set_content_margin_all(value: float) -> void:
	content_margin_left = value
	content_margin_top = value
	content_margin_right = value
	content_margin_bottom = value
