## 🕹️ **A virtual joystick.** It starts where the finger lands, and reports the direction and strength of the drag.
##
## ```gdscript
## var pad := GoJoystick.new()
## pad.moved.connect(func(v: Vector2) -> void: player.direction = v)
## pad.released.connect(func() -> void: player.direction = Vector2.ZERO)
## ```
##
## ## 🔑 Three modes
## | `mode` | Behavior |
## |---|---|
## | `FIXED` | always in the same place; easy to remember where it is |
## | `FOLLOW` | appears wherever you first press; still catches the finger on a big screen |
## | `RELATIVE` | once it appears it keeps following the finger; comfortable for long drags |
##
## ## 🛑 The value is **a normalized direction × strength**
## The `Vector2` that arrives with `moved` has a length of 0~1. Multiply it straight into a speed. The value does not
## shift with screen size or DPI — because it is divided by the radius.
##
## 🛑 Inside `dead_zone` it emits `Vector2.ZERO`. That stops the character from drifting when a finger merely rests on it.
@tool
class_name GoJoystick
extends Control

## Direction and strength (length 0~1). Emitted every time the finger moves.
signal moved(vector: Vector2)
## The finger was lifted.
signal released
## A finger landed.
signal pressed_down

enum Mode { FIXED, FOLLOW, RELATIVE }

@export var mode := Mode.FOLLOW

## Radius of the outer circle (dp).
@export_range(24, 240) var radius := 72.0:
	set(value):
		radius = maxf(16.0, value)
		custom_minimum_size = Vector2.ONE * radius * 2.0
		queue_redraw()

## Radius of the knob, the inner circle (dp).
@export_range(8, 120) var knob_radius := 28.0:
	set(value):
		knob_radius = maxf(6.0, value)
		queue_redraw()

## Within this fraction it emits 0 (0~1).
@export_range(0.0, 0.9, 0.01) var dead_zone := 0.12

## The color. Transparent means the theme's `accent`.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## Hide once the finger lifts (natural with `FOLLOW` and `RELATIVE`).
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
	# 🛑 A joystick is a **physical direction** — left does not become right just because the language is Arabic.
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	_center = size * 0.5
	_knob = _center
	resized.connect(func() -> void:
		if not _active:
			_center = size * 0.5
			_knob = _center
			queue_redraw())
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 🎨 The whole look changed — `GoUi.use_preset()` and `GoUi.refresh()` call this.
## 🛑 Without it **the widgets already on screen are the only ones left on the old theme.** They sit next to freshly
##    built ones and one screen ends up wearing two looks (measured 2026-09-16: after switching presets the HP bar
##    kept the old accent color and the quick-slot panel its old color — the values had changed, but nobody re-read them).
## 🔑 The joystick reads its colors and skin **on the spot** inside `_draw()` — telling it to redraw is all it takes.
func _on_ui_changed() -> void:
	queue_redraw()


## The current direction and strength (length 0~1). Polling it every frame is fine.
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
		# The mouse is taken as well, so you can develop and test on desktop.
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
			# The center is dragged along with the finger — finger and knob never come apart.
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
	# 🔑 **The skin does the drawing** — position and strength are computed here, the shape lives there. Change the theme and it can become a hex ring.
	GoUi.skin().draw_joystick(self, _center, _knob, radius, knob_radius, color, base, _active)


## A generous input area — a press that starts a little outside the visible circle is still caught.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)
