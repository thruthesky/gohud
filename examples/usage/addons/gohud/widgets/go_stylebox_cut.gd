## ⬡ **모서리를 사선으로 자른 판.** 둥근 모서리(`StyleBoxFlat`)로는 만들 수 없는 각진 생김새를 낸다.
##
## ## 왜 새 StyleBox 인가
## `StyleBoxFlat` 의 모서리는 **둥근 것뿐**이다. 반경을 0 으로 두면 직각이고, 그 사이는 없다.
## 사선으로 잘린 모서리·한쪽만 강조된 변·바깥으로 번지는 발광은 엔진이 그려 주지 않는다.
## 그래서 직접 그린다 — 그리고 이것은 `Theme` 안에 그대로 담겨 `.tres` 로 저장된다.
##
## ```gdscript
## var box := GoStyleBoxCut.new()
## box.bg_color = Color("#0B121C")
## box.border_color = Color("#2A6F8F")
## box.cut = 10.0                                  # 자르는 크기
## box.cut_corners = GoStyleBoxCut.DIAGONAL        # 좌상·우하만
## box.edge_color = Color("#00E5FF")               # 위쪽 강조 변
## panel.add_theme_stylebox_override(&"panel", box)
## ```
##
## ## 🛑 여백은 `content_margin_*` 으로 준다
## `_get_style_margin()` 은 GDScript 상속에서 불리지 않는다(4.7 실측). 안쪽 여백이 필요하면
## `content_margin_left` 같은 **내장 칸**을 채운다 — 비워 두면 내용이 테두리에 붙는다.
##
## 🛑 색 칸 이름을 `StyleBoxFlat` 과 **일부러 맞췄다**(`bg_color`·`border_color`). gohud 의 스킨은
##    "테두리에 강조색을 입힌다" 를 이름으로 찾아 하므로, 이름이 다르면 조용히 아무 일도 안 한다.
@tool
class_name GoStyleBoxCut
extends StyleBox

## 자를 모서리(비트마스크). `DIAGONAL` 이 sci-fi 의 기본이다.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_RIGHT := 4
const BOTTOM_LEFT := 8
## 좌상 + 우하 — 한쪽으로 흐르는 느낌이 난다.
const DIAGONAL := TOP_LEFT | BOTTOM_RIGHT
## 네 모서리 전부.
const ALL := TOP_LEFT | TOP_RIGHT | BOTTOM_RIGHT | BOTTOM_LEFT

## 판의 바탕색.
@export var bg_color := Color(0.06, 0.09, 0.13, 1.0):
	set(value):
		bg_color = value
		emit_changed()

## 바탕을 칠할 것인가. 끄면 테두리만 남는다(포커스 링).
@export var draw_center := true:
	set(value):
		draw_center = value
		emit_changed()

## 테두리 색.
@export var border_color := Color(0.16, 0.43, 0.56, 1.0):
	set(value):
		border_color = value
		emit_changed()

## 테두리 두께(0 이면 그리지 않는다).
@export_range(0.0, 8.0, 0.5) var border_width := 1.0:
	set(value):
		border_width = value
		emit_changed()

## 모서리를 자르는 크기(dp).
@export_range(0.0, 48.0, 0.5) var cut := 8.0:
	set(value):
		cut = value
		emit_changed()

## 자를 모서리. 위 상수의 조합.
@export_flags("Top left:1", "Top right:2", "Bottom right:4", "Bottom left:8") var cut_corners := DIAGONAL:
	set(value):
		cut_corners = value
		emit_changed()

## 한 변만 굵게 긋는 **강조 변**의 색. 투명이면 긋지 않는다.
@export var edge_color := Color.TRANSPARENT:
	set(value):
		edge_color = value
		emit_changed()

## 강조 변의 두께.
@export_range(0.0, 8.0, 0.5) var edge_width := 2.0:
	set(value):
		edge_width = value
		emit_changed()

## 강조 변을 그을 자리(`SIDE_TOP` 등).
@export_enum("Left:0", "Top:1", "Right:2", "Bottom:3") var edge_side := 1:
	set(value):
		edge_side = value
		emit_changed()

## 판 바깥으로 번지는 발광의 색. 투명이면 없음.
@export var glow_color := Color.TRANSPARENT:
	set(value):
		glow_color = value
		emit_changed()

## 발광이 번지는 거리(dp). 🛑 크게 주면 그만큼 겹쳐 그린다 — HUD 처럼 여러 개가 깔리는 곳은 작게.
@export_range(0.0, 24.0, 1.0) var glow_size := 0.0:
	set(value):
		glow_size = value
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# 바깥 발광 먼저 — 본체가 그 위에 덮인다.
	if glow_color.a > 0.0 and glow_size > 0.0:
		var steps := clampi(int(glow_size / 2.0), 2, 7)
		for step in range(steps, 0, -1):
			var spread := glow_size * float(step) / float(steps)
			# 🛑 바깥일수록 옅게 — 제곱으로 떨어뜨린다. 선형으로 하면 가장자리가 **띠처럼 잘려 보인다**.
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


## 발광이 판 밖으로 나가므로 그릴 수 있는 범위를 넓혀 준다.
func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(glow_size) if glow_size > 0.0 else rect


## 잘린 모서리를 반영한 윤곽선(시계 방향). 스킨이 같은 모양으로 무언가를 덧그릴 때도 쓴다.
func outline(rect: Rect2) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	# 🛑 변의 절반을 넘게 자르면 윤곽이 스스로 꼬인다 — 작은 칩·얇은 막대에서 실제로 일어난다.
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


## 네 변의 안쪽 여백을 한 번에 — `StyleBoxFlat.set_content_margin_all()` 과 같은 편의 함수다.
func set_content_margin_all(value: float) -> void:
	content_margin_left = value
	content_margin_top = value
	content_margin_right = value
	content_margin_bottom = value
