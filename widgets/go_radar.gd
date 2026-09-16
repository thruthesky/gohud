## 🕸 **스탯 육각형** — 캐릭터의 힘·민첩·지능·체력·행운을 한 그림으로.
##
## ```gdscript
## var stats := GoRadar.make({"힘": 0.8, "민첩": 0.5, "지능": 0.3, "체력": 0.7, "행운": 0.4})
## card.add_child(stats)
##
## # 장비를 바꾸면 어떻게 되는지 겹쳐 본다
## stats.set_compare({"힘": 0.9, "민첩": 0.4, "지능": 0.3, "체력": 0.7, "행운": 0.4})
## ```
##
## ## 🔑 범용 차트가 아니다
## 게임에서 쓰는 방사형 그림은 **캐릭터·장비 비교** 한 가지다. 축 눈금·범례·툴팁이 붙은 차트
## 라이브러리를 들이면 그 대부분이 쓰이지 않는다. 여기 있는 것은 축 이름, 0~1 값, 그리고
## **겹쳐 보기** 뿐이다.
##
## ## 🛑 값은 0~1 로 정규화해 넘긴다
## 힘 120 과 지능 45 를 그대로 그리면 축마다 기준이 달라 모양이 거짓말을 한다. 무엇을 1 로 볼지는
## 게임이 정한다(그 직업의 상한? 서버 1위?) — 그 판단을 위젯이 대신할 수 없다.
##
## ## ♿ 그림만으로는 읽히지 않는다
## 값을 축 이름과 함께 스크린리더 이름으로 준다. 색각 이상인 사람을 위해 비교선은 **색만이 아니라
## 점선**으로도 구별된다.
@tool
class_name GoRadar
extends Control

## 축 이름 → 값(0~1).
var values: Dictionary = {}
## 겹쳐 그릴 값(장비 비교). 비어 있으면 안 그린다.
var compare: Dictionary = {}

## 면을 채우는 색. 비우면 테마 강조색.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## 비교선 색. 비우면 테마 경고색.
@export var compare_ink := Color.TRANSPARENT:
	set(value):
		compare_ink = value
		queue_redraw()

## 축 이름을 그릴 것인가. 🛑 작은 칸(60dp 아래)에서는 글자가 겹치므로 끈다.
@export var show_labels := true:
	set(value):
		show_labels = value
		queue_redraw()

## 안쪽 거미줄을 몇 겹 그릴 것인가.
@export var rings := 3:
	set(value):
		rings = maxi(1, value)
		queue_redraw()


func _init() -> void:
	name = "Radar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 160)


func _ready() -> void:
	GoUi.watch(_on_ui_changed)
	_sync_accessibility()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


static func make(stats: Dictionary, compare_with := {}) -> GoRadar:
	var node := GoRadar.new()
	node.values = stats.duplicate()
	node.compare = compare_with.duplicate()
	return node


func set_values(stats: Dictionary) -> void:
	values = stats.duplicate()
	_sync_accessibility()
	queue_redraw()


func set_compare(stats: Dictionary) -> void:
	compare = stats.duplicate()
	_sync_accessibility()
	queue_redraw()


func _draw() -> void:
	var axes := values.keys()
	# 🛑 축이 셋보다 적으면 면이 되지 않는다 — 선 하나·점 하나를 그려 놓고 "그래프" 라고 하지 않는다.
	if axes.size() < 3: return
	var box := minf(size.x, size.y)
	var pad := float(GoUi.font_size(GoTheme.ROLE_MICRO)) * 2.2 if show_labels else 4.0
	var radius := box * 0.5 - pad
	if radius <= 4.0: return
	var center := size * 0.5
	var web := Color(GoUi.color(GoTheme.BORDER), 0.55)

	# 거미줄 — 값을 눈대중으로 읽을 수 있게 하는 격자다.
	for ring in range(1, rings + 1):
		var r := radius * float(ring) / float(rings)
		var points := PackedVector2Array()
		for i in axes.size(): points.append(center + _spoke(i, axes.size()) * r)
		points.append(points[0])
		draw_polyline(points, web, 1.0, true)
	for i in axes.size():
		draw_line(center, center + _spoke(i, axes.size()) * radius, web, 1.0, true)

	# 값 면
	var fill := ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)
	_draw_shape(center, radius, axes, values, fill, true, false)

	# 비교선 — 🔑 **점선**으로 그린다. 색만 다르면 색각 이상인 사람에게는 두 줄이 겹쳐 보인다.
	if not compare.is_empty():
		var other := compare_ink if compare_ink.a > 0 else GoUi.color(GoTheme.WARNING)
		_draw_shape(center, radius, axes, compare, other, false, true)

	if not show_labels: return
	var font := get_theme_font(&"font")
	if font == null: return
	var font_size := GoUi.font_size(GoTheme.ROLE_MICRO)
	var text_ink := GoUi.color(GoTheme.SECONDARY)
	for i in axes.size():
		var name := str(axes[i])
		var dir := _spoke(i, axes.size())
		var at := center + dir * (radius + font_size * 0.9)
		var measured := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		# 축이 어느 쪽을 보느냐에 따라 글자를 당겨 붙인다 — 안 하면 왼쪽 축 이름이 그림에 겹친다.
		at.x -= measured.x * (0.5 + dir.x * 0.5)
		at.y += measured.y * 0.35
		draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_ink)


## 값 하나를 면(또는 선)으로 그린다.
func _draw_shape(center: Vector2, radius: float, axes: Array, source: Dictionary,
		color: Color, filled: bool, dashed: bool) -> void:
	var points := PackedVector2Array()
	for i in axes.size():
		var value := clampf(float(source.get(axes[i], 0.0)), 0.0, 1.0)
		points.append(center + _spoke(i, axes.size()) * radius * value)
	if points.size() < 3: return
	if filled:
		var face := PackedColorArray()
		for _i in points.size(): face.append(Color(color, 0.22))
		draw_polygon(points, face)
	var outline := points.duplicate()
	outline.append(points[0])
	if not dashed:
		draw_polyline(outline, color, 2.0, true)
		return
	# 점선 — 각 변을 조각내어 한 칸 띄어 그린다.
	for i in outline.size() - 1:
		var from := outline[i]
		var to := outline[i + 1]
		var length := from.distance_to(to)
		var step := maxf(4.0, length / 8.0)
		var walked := 0.0
		while walked < length:
			var a := from.lerp(to, walked / length)
			var b := from.lerp(to, minf(1.0, (walked + step * 0.55) / length))
			draw_line(a, b, color, 2.0, true)
			walked += step


## `index` 번째 축이 가리키는 방향. 🔑 첫 축이 **위**를 보게 한다 — 그러지 않으면 그림이 기울어 보인다.
func _spoke(index: int, total: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / float(total)
	return Vector2(cos(angle), sin(angle))


## ♿ 그림을 못 보는 사람에게 값을 말로 준다.
func _sync_accessibility() -> void:
	var parts: Array[String] = []
	for key in values: parts.append("%s %d%%" % [str(key), roundi(float(values[key]) * 100.0)])
	accessibility_name = ", ".join(parts)


func _on_ui_changed() -> void:
	queue_redraw()
