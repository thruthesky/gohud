## 🍩 **도넛 비중** — 피해량 분포, 인벤토리 무게, 보유 재화 비율, 파티 기여도.
##
## ```gdscript
## var share := GoDonut.make([
##     {"label": "물리", "value": 620, "color": Color("e05a4a")},
##     {"label": "마법", "value": 340, "color": Color("4a8fe0")},
##     {"label": "관통", "value": 90},          # 색을 안 주면 테마에서 돌려 쓴다
## ])
## share.center_text = "1050"                    # 가운데에 합계
## ```
##
## ## 🔑 조각은 다섯을 넘기지 않는다
## 여섯 조각부터는 작은 것들이 실처럼 보여 읽을 수 없다. 나머지는 **「기타」로 묶는 편**이 낫다 —
## `collapse_to` 를 주면 알아서 묶는다.
##
## ## 🛑 가운데를 비워 두지 않는다
## 도넛의 가운데는 게임에서 가장 값싼 자리다. 합계·비율·아이콘 중 하나를 넣는다.
##
## ## ♿ 색만으로 구별하지 않는다
## 조각 이름과 비율을 스크린리더 이름으로 준다. 눈으로 읽는 범례(`legend()`)도 **글자를 함께** 둔다 —
## 색 점만 있는 범례는 색각 이상인 사람에게 아무 정보가 아니다.
@tool
class_name GoDonut
extends Control

## 가운데에 쓸 글자(합계·비율). 비우면 안 쓴다.
@export var center_text := "":
	set(value):
		center_text = value
		queue_redraw()

## 가운데 글자 아래 작은 설명.
@export var center_hint := "":
	set(value):
		center_hint = value
		queue_redraw()

## 고리 두께 비율(0~1). 1 이면 원그래프(가운데가 없다).
@export_range(0.1, 1.0, 0.01) var thickness_ratio := 0.34:
	set(value):
		thickness_ratio = value
		queue_redraw()

## 이 개수를 넘으면 나머지를 **하나로 묶는다**. 0 이면 묶지 않는다.
@export var collapse_to := 5:
	set(value):
		collapse_to = maxi(0, value)
		queue_redraw()

## 묶은 조각의 이름(번역 키가 아니라 글자).
@export var collapse_label := "…"

var _slices: Array[Dictionary] = []


func _init() -> void:
	name = "Donut"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(140, 140)


func _ready() -> void:
	GoUi.watch(_on_ui_changed)
	_sync_accessibility()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 조각은 `{"label":…, "value":…, "color":…}` 다. `value` 는 **비율이 아니라 원래 값**이다 —
## 합을 맞출 필요가 없다(여기서 나눈다).
static func make(slices: Array) -> GoDonut:
	var node := GoDonut.new()
	node.set_slices(slices)
	return node


func set_slices(slices: Array) -> void:
	_slices.clear()
	for entry in slices:
		var row: Dictionary = entry if entry is Dictionary else {"value": float(entry)}
		_slices.append({
			"label": str(row.get("label", "")),
			"value": maxf(0.0, float(row.get("value", 0.0))),
			"color": row.get("color", Color.TRANSPARENT) as Color,
		})
	_sync_accessibility()
	queue_redraw()


func slices() -> Array[Dictionary]:
	return _slices


## 합계(원래 값의 합).
func total() -> float:
	var sum := 0.0
	for slice in _slices: sum += float(slice["value"])
	return sum


## 실제로 그릴 조각들 — 큰 것부터, 넘치면 묶어서.
func visible_slices() -> Array[Dictionary]:
	var sorted := _slices.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	if collapse_to <= 0 or sorted.size() <= collapse_to: return sorted
	var out := sorted.slice(0, collapse_to - 1)
	var rest := 0.0
	for slice in sorted.slice(collapse_to - 1): rest += float(slice["value"])
	out.append({"label": collapse_label, "value": rest, "color": GoUi.color(GoTheme.MUTED)})
	return out


func _draw() -> void:
	var parts := visible_slices()
	var sum := 0.0
	for slice in parts: sum += float(slice["value"])
	var box := minf(size.x, size.y)
	var outer := box * 0.5
	var width := outer * clampf(thickness_ratio, 0.1, 1.0)
	var radius := outer - width * 0.5
	if radius <= 1.0: return
	var center := size * 0.5

	# 값이 하나도 없으면 빈 고리만 — 🛑 아무것도 안 그리면 "불러오는 중" 과 구별되지 않는다.
	if sum <= 0.0:
		draw_arc(center, radius, 0.0, TAU, 64, GoUi.color(GoTheme.TRACK), width, true)
		_draw_center()
		return

	var angle := -PI * 0.5   # 12시부터 시계방향 — 사람이 비중을 읽는 관습이다
	for index in parts.size():
		var slice := parts[index]
		var portion := float(slice["value"]) / sum
		if portion <= 0.0: continue
		var sweep := TAU * portion
		var color: Color = slice["color"]
		if color.a <= 0.0: color = _palette(index)
		draw_arc(center, radius, angle, angle + sweep, maxi(8, roundi(64.0 * portion)), color, width, true)
		angle += sweep
	_draw_center()


func _draw_center() -> void:
	if center_text.is_empty() and center_hint.is_empty(): return
	var font := get_theme_font(&"font")
	if font == null: return
	var center := size * 0.5
	var big := GoUi.font_size(GoTheme.ROLE_SUBTITLE)
	var small := GoUi.font_size(GoTheme.ROLE_MICRO)
	if not center_text.is_empty():
		var measured := font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		var at := center - Vector2(measured.x * 0.5, 0.0)
		if not center_hint.is_empty(): at.y -= small * 0.4
		draw_string(font, at, center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, GoUi.color(GoTheme.TEXT))
	if center_hint.is_empty(): return
	var hint_size := font.get_string_size(center_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
	draw_string(font, center + Vector2(-hint_size.x * 0.5, small * 1.4), center_hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, small, GoUi.color(GoTheme.MUTED))


## 색을 안 준 조각에 돌려 쓸 색. 🔑 테마 토큰에서만 고른다 — 팔레트를 박아 두면 스킨을 바꿔도 안 따라온다.
func _palette(index: int) -> Color:
	var wheel := [GoTheme.ACCENT, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.INFO, GoTheme.DANGER]
	return GoUi.color(wheel[index % wheel.size()])


## 눈으로 읽는 범례. 🛑 **색 점만 두지 않는다** — 이름과 비율을 글자로 함께 둔다.
func legend() -> Control:
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	column.name = "Legend"
	var parts := visible_slices()
	var sum := 0.0
	for slice in parts: sum += float(slice["value"])
	for index in parts.size():
		var slice := parts[index]
		var color: Color = slice["color"]
		if color.a <= 0.0: color = _palette(index)
		var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2.ONE * float(GoUi.font_size(GoTheme.ROLE_MICRO))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override(&"panel", GoUi.skin().badge_box(color))
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var name := GoStyle.label(str(slice["label"]), GoTheme.ROLE_COMPACT)
		name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var portion := 0.0 if sum <= 0.0 else float(slice["value"]) / sum * 100.0
		var share := GoStyle.label(GoUi.text(&"bar_percent").format({"percent": roundi(portion)}),
			GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED))
		share.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		share.text_direction = Control.TEXT_DIRECTION_LTR
		row.add_child(share)
		column.add_child(row)
	return column


func _sync_accessibility() -> void:
	var parts := visible_slices()
	var sum := 0.0
	for slice in parts: sum += float(slice["value"])
	var spoken: Array[String] = []
	for slice in parts:
		var portion := 0.0 if sum <= 0.0 else float(slice["value"]) / sum * 100.0
		spoken.append("%s %d%%" % [str(slice["label"]), roundi(portion)])
	accessibility_name = ", ".join(spoken)


func _on_ui_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: queue_redraw()
