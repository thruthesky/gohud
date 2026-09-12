## 📊 **값 막대** — 체력·마나·경험치처럼 "얼마나 남았나" 를 보여 주는 한 줄.
##
## ```gdscript
## var hp := GoBar.new()
## hp.label_text = "HP"
## hp.ink = GoUi.color(GoTheme.DANGER)
## hp.set_values(320, 500)      # "320 / 500"
## ```
##
## ## 🔑 숫자를 어떻게 보여 줄지 고른다
## | `readout` | 보이는 것 |
## |---|---|
## | `NONE` | 막대만 |
## | `VALUE` | `320` |
## | `FRACTION` | `320 / 500` |
## | `PERCENT` | `64%` |
##
## ## 🛑 값 변화는 부드럽게, 단 껐다 켤 수 있게
## 체력이 뚝뚝 끊겨 움직이면 얼마나 맞았는지 읽히지 않는다. 그래서 기본으로 0.18초 보간한다.
## `GoConfig.reduce_motion` 이면 즉시 바뀐다.
@tool
class_name GoBar
extends Control

enum Readout { NONE, VALUE, FRACTION, PERCENT }

## 막대 왼쪽의 이름. 비우면 숨긴다.
@export var label_text := "":
	set(value):
		label_text = value
		if is_instance_valid(_name_label):
			_name_label.text = value
			_name_label.visible = not value.is_empty()

## 막대 색. 투명이면 테마의 `accent`.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		_restyle()

## 숫자 표시 방식.
@export var readout := Readout.FRACTION:
	set(value):
		readout = value
		_refresh_text()

## 막대의 두께(dp).
@export_range(2, 48) var thickness := 8:
	set(value):
		thickness = value
		if is_instance_valid(_bar): _bar.custom_minimum_size.y = value

## 값이 바뀔 때 부드럽게 움직일 시간(초). 0 이면 즉시.
@export_range(0.0, 1.0, 0.01) var ease_seconds := 0.18

var _name_label: Label
var _value_label: Label
var _bar: ProgressBar
var _value := 0.0
var _maximum := 1.0
var _tween: Tween


func _init() -> void:
	name = "Bar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	column.name = "Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)

	_name_label = GoStyle.label(label_text, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	_name_label.name = "Name"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label.visible = not label_text.is_empty()
	head.add_child(_name_label)

	_value_label = GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	_value_label.name = "Value"
	_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 🛑 숫자는 **언제나 왼쪽에서 오른쪽**이다 — 아랍어에서도 `320 / 500` 의 순서는 그대로다.
	_value_label.text_direction = Control.TEXT_DIRECTION_LTR
	head.add_child(_value_label)

	_bar = GoStyle.progress()
	_bar.name = "Fill"
	_bar.custom_minimum_size.y = thickness
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0001
	column.add_child(_bar)
	# 🛑 `Control` 은 자식 컨테이너의 최소 높이를 **물려받지 않는다** — 그대로 두면 세로로 쌓았을 때
	#    막대 하나가 두께(8dp)만 차지한다고 잡혀 이름 줄과 아래 막대가 겹쳐 그려진다
	#    (2026-09-12 스크린샷 실측: HP/MP/XP 세 줄이 서로 겹쳤다).
	GoStyle.fit_content_height(self, column)


func _ready() -> void:
	_restyle()
	_refresh_text()


## 값과 최대값을 정한다. 최대값이 0 이하면 막대는 비어 있는 것으로 본다.
func set_values(value: float, maximum: float, animate := true) -> void:
	_value = maxf(0.0, value)
	_maximum = maximum
	var ratio := clampf(_value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_refresh_text()
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	if not animate or GoUi.config.reduce_motion or ease_seconds <= 0.0 or not is_inside_tree():
		_bar.value = ratio
		return
	_tween = create_tween()
	_tween.tween_property(_bar, "value", ratio, ease_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## 0~1 비율만 직접 정할 때(최대값을 모르는 경우).
func set_ratio(ratio: float, animate := true) -> void:
	set_values(clampf(ratio, 0.0, 1.0), 1.0, animate)


func value() -> float:
	return _value


func maximum() -> float:
	return _maximum


func _restyle() -> void:
	if not is_instance_valid(_bar): return
	GoStyle.tint_progress(_bar, ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT))


func _refresh_text() -> void:
	if not is_instance_valid(_value_label): return
	match readout:
		Readout.NONE:
			_value_label.visible = false
		Readout.VALUE:
			_value_label.visible = true
			_value_label.text = _format(_value)
		Readout.FRACTION:
			_value_label.visible = true
			_value_label.text = "%s / %s" % [_format(_value), _format(_maximum)]
		Readout.PERCENT:
			_value_label.visible = true
			var pct := (_value / _maximum * 100.0) if _maximum > 0.0 else 0.0
			_value_label.text = "%d%%" % roundi(pct)


## 큰 수를 짧게 — `12.3k`·`4.5m`. 자릿수가 늘어나도 막대 폭이 흔들리지 않게 한다.
static func abbreviate(amount: float) -> String:
	var size := absf(amount)
	if size >= 1_000_000.0: return "%.1fm" % (amount / 1_000_000.0)
	if size >= 10_000.0: return "%.1fk" % (amount / 1000.0)
	return str(roundi(amount))


func _format(amount: float) -> String:
	return abbreviate(amount)
