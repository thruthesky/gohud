## Forged frames with restrained rivets, corner engraving and material grain.
## Decorations stay inside the frame; content margins remain ordinary Godot margins.
@tool
class_name GoStyleBoxMedieval
extends StyleBox

## Base surface colour, also used by the shared contrast and tint helpers.
@export var bg_color := Color("#211b18"):
	set(value):
		bg_color = value
		emit_changed()
@export var border_color := Color("#aa8750"):
	set(value):
		border_color = value
		emit_changed()
@export var border_width := 1.0:
	set(value):
		border_width = value
		emit_changed()
@export var draw_center := true:
	set(value):
		draw_center = value
		emit_changed()
@export var radius := 4.0:
	set(value):
		radius = value
		emit_changed()
## 0: plain iron; 1: leather; 2: parchment. Only surface marks change.
@export_enum("Iron", "Leather", "Parchment") var material := 1:
	set(value):
		material = value
		emit_changed()
## 0: quiet HUD frame; 1: rivets; 2: engraved menu corners.
@export_enum("Quiet", "Rivets", "Engraved") var ornament := 1:
	set(value):
		ornament = value
		emit_changed()
@export var ornament_scale := 1.0:
	set(value):
		ornament_scale = value
		emit_changed()
@export var grain_alpha := 0.035:
	set(value):
		grain_alpha = value
		emit_changed()
@export var bevel_strength := 0.18:
	set(value):
		bevel_strength = value
		emit_changed()
@export var shadow_color := Color(0, 0, 0, 0.45):
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

var _face := StyleBoxFlat.new()


func _draw(canvas: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0: return
	_face.bg_color = bg_color
	_face.border_color = border_color
	_face.draw_center = draw_center
	_face.set_border_width_all(maxi(0, roundi(border_width)))
	_face.set_corner_radius_all(maxi(0, mini(roundi(radius), int(minf(rect.size.x, rect.size.y) * 0.5))))
	_face.corner_detail = 6
	_face.shadow_color = shadow_color
	_face.shadow_size = maxi(0, shadow_size)
	_face.shadow_offset = shadow_offset
	_face.draw(canvas, rect)
	if not draw_center: return
	var inner := rect.grow(-maxf(2.0, border_width + 1.0))
	if inner.size.x < 4.0 or inner.size.y < 4.0: return
	# A highlight and a recessed lower edge give metal depth without glow or animation.
	var highlight := Color(border_color.lightened(0.4), bevel_strength * bg_color.a)
	var shade := Color(0, 0, 0, bevel_strength * bg_color.a)
	_line(canvas, [inner.position + Vector2(2, 0), Vector2(inner.end.x - 2, inner.position.y)], highlight)
	_line(canvas, [Vector2(inner.position.x + 2, inner.end.y), inner.end - Vector2(2, 0)], shade)
	if minf(inner.size.x, inner.size.y) < 24.0: return
	if grain_alpha > 0.0: _grain(canvas, inner.grow(-3.0))
	if ornament <= 0: return
	var inset := minf(6.0 * ornament_scale, minf(rect.size.x, rect.size.y) * 0.2)
	var corners := rect.grow(-inset)
	var stud := clampf(1.4 * ornament_scale, 0.5, 2.5)
	for point in [corners.position, Vector2(corners.end.x, corners.position.y),
			corners.end, Vector2(corners.position.x, corners.end.y)]:
		RenderingServer.canvas_item_add_circle(canvas, point + Vector2(0, 1), stud + 0.5, shade)
		RenderingServer.canvas_item_add_circle(canvas, point, stud, border_color)
		RenderingServer.canvas_item_add_circle(canvas, point - Vector2(0.4, 0.4), stud * 0.35, highlight)
	if ornament < 2 or rect.size.x < 80.0 or rect.size.y < 48.0: return
	# Small interlaced corners live in the gutter, never behind body text.
	var arm := minf(11.0 * ornament_scale, minf(rect.size.x, rect.size.y) * 0.18)
	for side in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var origin := Vector2(corners.position.x if side.x > 0 else corners.end.x,
			corners.position.y if side.y > 0 else corners.end.y)
		var path := PackedVector2Array()
		for point in [Vector2(arm, 0), Vector2(arm * 0.55, 0), Vector2(arm * 0.55, arm * 0.35),
				Vector2(arm * 0.35, arm * 0.55), Vector2(0, arm * 0.55), Vector2(0, arm)]:
			path.append(origin + point * side)
		RenderingServer.canvas_item_add_polyline(canvas, path, PackedColorArray([Color(border_color, 0.7)]), 1.0, true)


func _grain(canvas: RID, rect: Rect2) -> void:
	# Fixed, bounded marks: no random state, textures, per-pixel shaders or frame updates.
	var marks := clampi(int(rect.size.y / 7.0), 2, 24)
	var tint := Color(border_color if material != 2 else Color("#462e1b"), grain_alpha * bg_color.a)
	for index in marks:
		var y := rect.position.y + (float(index) + 0.5) * rect.size.y / float(marks)
		var start := rect.position.x + fmod(float(index * 37), maxf(1.0, rect.size.x * 0.3))
		var span := minf(rect.end.x - start, rect.size.x * (0.25 if material == 1 else 0.6))
		_line(canvas, [Vector2(start, y), Vector2(start + span * 0.6, y + 0.6), Vector2(start + span, y)], tint)


func _line(canvas: RID, points: Array, tint: Color) -> void:
	RenderingServer.canvas_item_add_polyline(canvas, PackedVector2Array(points), PackedColorArray([tint]), 1.0, true)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(float(maxi(0, shadow_size)) + shadow_offset.length()) if shadow_size > 0 else rect


func set_content_margin_all(value: float) -> void:
	content_margin_left = value
	content_margin_top = value
	content_margin_right = value
	content_margin_bottom = value
