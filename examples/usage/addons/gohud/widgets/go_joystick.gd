## 🕹️ **가상 조이스틱.** 손가락을 얹은 자리에서 시작해, 끈 방향과 세기를 알려 준다.
##
## ```gdscript
## var pad := GoJoystick.new()
## pad.moved.connect(func(v: Vector2) -> void: player.direction = v)
## pad.released.connect(func() -> void: player.direction = Vector2.ZERO)
## ```
##
## ## 🔑 세 가지 방식
## | `mode` | 동작 |
## |---|---|
## | `FIXED` | 늘 같은 자리. 위치를 기억하기 쉽다 |
## | `FOLLOW` | 처음 누른 자리에 나타난다. 큰 화면에서 손가락을 옮겨도 잡힌다 |
## | `RELATIVE` | 나타난 뒤 손가락을 계속 따라간다. 오래 끄는 이동에 편하다 |
##
## ## 🛑 값은 **정규화된 방향 × 세기**다
## `moved` 로 오는 `Vector2` 는 길이가 0~1 이다. 그대로 속도에 곱하면 된다. 화면 크기·DPI 에
## 따라 값이 달라지지 않는다 — 반지름으로 나누기 때문이다.
##
## 🛑 `dead_zone` 안에서는 `Vector2.ZERO` 를 낸다. 손가락을 얹기만 해도 캐릭터가 흐르는 것을 막는다.
@tool
class_name GoJoystick
extends Control

## 방향과 세기(길이 0~1). 손가락을 움직일 때마다 온다.
signal moved(vector: Vector2)
## 손가락을 뗐다.
signal released
## 손가락을 얹었다.
signal pressed_down

enum Mode { FIXED, FOLLOW, RELATIVE }

@export var mode := Mode.FOLLOW

## 바깥 원의 반지름(dp).
@export_range(24, 240) var radius := 72.0:
	set(value):
		radius = maxf(16.0, value)
		custom_minimum_size = Vector2.ONE * radius * 2.0
		queue_redraw()

## 손잡이(안쪽 원)의 반지름(dp).
@export_range(8, 120) var knob_radius := 28.0:
	set(value):
		knob_radius = maxf(6.0, value)
		queue_redraw()

## 이 비율 안에서는 0 을 낸다(0~1).
@export_range(0.0, 0.9, 0.01) var dead_zone := 0.12

## 색. 투명이면 테마의 `accent`.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## 손가락을 떼면 숨긴다(`FOLLOW`·`RELATIVE` 에서 자연스럽다).
@export var hide_when_idle := false:
	set(value):
		hide_when_idle = value
		queue_redraw()

var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _active := false
var _vector := Vector2.ZERO


func _init() -> void:
	name = "Joystick"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2.ONE * radius * 2.0
	# 🛑 조이스틱은 **물리적 방향**이다 — 아랍어라고 왼쪽이 오른쪽이 되지 않는다.
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	_center = size * 0.5
	_knob = _center
	resized.connect(func() -> void:
		if not _active:
			_center = size * 0.5
			_knob = _center
			queue_redraw())


## 지금 방향과 세기(길이 0~1). 매 프레임 폴링해도 된다.
func vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _active


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0:
			_touch_index = event.index
			_begin(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_end()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 데스크톱에서 개발·시험할 수 있게 마우스도 받는다.
		if event.pressed and _touch_index < 0:
			_touch_index = -2
			_begin(event.position)
			accept_event()
		elif not event.pressed and _touch_index == -2:
			_end()
			accept_event()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_drag(event.position)
		accept_event()


func _begin(point: Vector2) -> void:
	_active = true
	_center = point if mode != Mode.FIXED else size * 0.5
	_knob = _center
	_vector = Vector2.ZERO
	pressed_down.emit()
	queue_redraw()


func _drag(point: Vector2) -> void:
	if not _active: return
	var offset := point - _center
	var distance := offset.length()
	if distance > radius:
		if mode == Mode.RELATIVE:
			# 손가락을 따라 중심이 끌려간다 — 손가락과 손잡이가 어긋나지 않는다.
			_center += offset - offset.normalized() * radius
		offset = offset.normalized() * radius
		distance = radius
	_knob = _center + offset
	var strength := distance / radius
	_vector = Vector2.ZERO if strength < dead_zone else offset.normalized() * strength
	moved.emit(_vector)
	queue_redraw()


func _end() -> void:
	_touch_index = -1
	_active = false
	_vector = Vector2.ZERO
	_center = size * 0.5
	_knob = _center
	released.emit()
	moved.emit(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	if hide_when_idle and not _active: return
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)
	var base := GoUi.color(GoTheme.SURFACE)
	# 🔑 **그리는 것은 스킨**이다 — 자리·세기 계산은 여기, 모양은 거기. 테마를 바꾸면 육각 링이 될 수 있다.
	GoUi.skin().draw_joystick(self, _center, _knob, radius, knob_radius, color, base, _active)


## 넓은 조작 영역 — 보이는 원보다 조금 밖에서 시작해도 잡힌다.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)
