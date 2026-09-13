## ⌐ **네 모서리 표식.** 변을 다 두르지 않고 모서리만 짧게 긋는다 — 조준경·전술 화면의 그 표시다.
##
## ## 왜 쓰나
## 테두리를 통째로 두르면 "상자" 로 읽히고, 안의 내용보다 테두리가 먼저 눈에 든다. 모서리만
## 남기면 **무엇을 가리키는지**는 분명한데 내용은 가리지 않는다. 그래서 포커스 링·선택 표시·
## 코치마크의 조준 표시에 쓴다.
##
## ```gdscript
## var mark := GoStyleBoxBracket.new()
## mark.color = Color("#00E5FF")
## mark.arm = 10.0          # 모서리에서 뻗는 길이
## button.add_theme_stylebox_override(&"focus", mark)
## ```
##
## 🛑 여백은 `content_margin_*` 으로 준다 — `_get_style_margin()` 은 GDScript 상속에서 불리지 않는다.
@tool
class_name GoStyleBoxBracket
extends StyleBox

## 표식의 색.
@export var color := Color(0.0, 0.9, 1.0, 1.0):
	set(value):
		color = value
		emit_changed()

## 모서리에서 각 방향으로 뻗는 길이(dp).
@export_range(2.0, 48.0, 1.0) var arm := 10.0:
	set(value):
		arm = value
		emit_changed()

## 선의 두께.
@export_range(0.5, 8.0, 0.5) var thickness := 2.0:
	set(value):
		thickness = value
		emit_changed()

## 판 안쪽으로 들여 그릴 거리. 대상에 딱 붙지 않게 띄운다.
@export_range(-16.0, 16.0, 0.5) var inset := 0.0:
	set(value):
		inset = value
		emit_changed()

## 옅게 깔 바탕색. 투명이면 칠하지 않는다(보통 투명).
@export var bg_color := Color.TRANSPARENT:
	set(value):
		bg_color = value
		emit_changed()

## 네 모서리 대신 **대각선 두 모서리**만(좌상·우하). 더 가볍게 가리킨다.
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
	# 🛑 팔이 변의 절반을 넘으면 양쪽 팔이 만나 테두리가 통째로 둘러진다 — 모서리 표식의 뜻이 사라진다.
	var reach := minf(arm, minf(area.size.x, area.size.y) * 0.5)
	var p := area.position
	var s := area.size
	var tint := PackedColorArray([color])
	var corners := [
		[Vector2(p.x, p.y + reach), p, Vector2(p.x + reach, p.y)],                                              # 좌상
		[Vector2(p.x + s.x - reach, p.y), Vector2(p.x + s.x, p.y), Vector2(p.x + s.x, p.y + reach)],            # 우상
		[Vector2(p.x + s.x, p.y + s.y - reach), p + s, Vector2(p.x + s.x - reach, p.y + s.y)],                  # 우하
		[Vector2(p.x + reach, p.y + s.y), Vector2(p.x, p.y + s.y), Vector2(p.x, p.y + s.y - reach)],            # 좌하
	]
	for index in corners.size():
		if diagonal_only and index % 2 == 1: continue
		RenderingServer.canvas_item_add_polyline(to_canvas_item, PackedVector2Array(corners[index]), tint, thickness, true)


## 네 변의 안쪽 여백을 한 번에.
func set_content_margin_all(value: float) -> void:
	content_margin_left = value
	content_margin_top = value
	content_margin_right = value
	content_margin_bottom = value
