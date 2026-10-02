## ↔️ **A slider with two handles** — a price range, an age range, a time window (Flutter's `RangeSlider`).
## Drawn with the theme's own slider track, active part and handle, so it matches `GoStyle.slider()` on every preset.
##
## ```gdscript
## var price := GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0)
## price.changed.connect(func(low: float, high: float) -> void: label.text = "$%d – $%d" % [low, high])
## price.change_ended.connect(func(low: float, high: float) -> void: refilter(low, high))
## ```
##
## ## 🔑 Which handle moves
## A press moves the handle nearer to it (when both sit on the same spot, the way the finger goes decides). The
## handles never cross; `min_gap` keeps them apart. Left and right arrows move the handle that moved last.
##
## ## 🔑 Inside a list
## Its own drag is sideways, so it keeps its press like a slider — and an up-and-down swipe that starts on it still
## scrolls the list (`GoScroll.SIDEWAYS`).
@tool
class_name GoRangeSlider
extends Control

## A handle moved (while dragging, too).
signal changed(low: float, high: float)
## The finger let go, or a key moved a handle — the time to refilter or ask the server.
signal change_ended(low: float, high: float)

@export var min_value := 0.0:
	set(value):
		min_value = value
		_clamp()
@export var max_value := 100.0:
	set(value):
		max_value = value
		_clamp()
## The step values snap to (0 = continuous).
@export var step := 1.0
## The least distance between the two values.
@export var min_gap := 0.0

## The lower value.
var low := 20.0:
	set(value):
		low = value
		if not _hold: _clamp()
## The higher value.
var high := 80.0:
	set(value):
		high = value
		if not _hold: _clamp()

## True while both values are being set together (`set_range`) — they are checked once, after both.
var _hold := false

## Which handle moves: 0 low, 1 high, -1 none.
var _active := -1
var _last := 1
var _from := Vector2.INF


func _init() -> void:
	name = "RangeSlider"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 🔑 Its drag is sideways: it keeps its press inside a list, and an up-and-down swipe from it scrolls the list.
	set_meta(GoScroll.SIDEWAYS, true)
	GoScroll.yield_vertical(self)


func _ready() -> void:
	theme = GoUi.theme()
	_name_it()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A range slider from [param minimum] to [param maximum] with [param from] … [param to] chosen.
static func make(minimum: float, maximum: float, from: float, to: float, snap := 1.0) -> GoRangeSlider:
	var node := GoRangeSlider.new()
	node.step = snap
	node.min_value = minimum
	node.max_value = maximum
	node.set_range(from, to)
	return node


## Sets both values at once (without emitting).
func set_range(from: float, to: float) -> void:
	_hold = true
	low = from
	high = to
	_hold = false
	_clamp()


func _get_minimum_size() -> Vector2:
	var grab := _grabber()
	var side := grab.get_size() if grab != null else Vector2(16, 16)
	return Vector2(side.x * 3.0, maxf(float(GoUi.metric(GoTheme.TOUCH)), side.y))


func _grabber(state := &"grabber") -> Texture2D:
	return get_theme_icon(state, &"HSlider") if has_theme_icon(state, &"HSlider") else null


func _snap(value: float) -> float:
	var out := clampf(value, min_value, max_value)
	if step > 0.0: out = clampf(min_value + roundf((out - min_value) / step) * step, min_value, max_value)
	return out


func _clamp() -> void:
	var lo := _snap(minf(low, high))
	var hi := _snap(maxf(low, high))
	if hi - lo < min_gap:
		hi = minf(max_value, lo + min_gap)
		lo = maxf(min_value, hi - min_gap)
	if lo != low or hi != high:
		_hold = true
		low = lo
		high = hi
		_hold = false
	_name_it()
	queue_redraw()


## The horizontal span the handles travel (their centres), in local coordinates.
func _span() -> Vector2:
	var grab := _grabber()
	var half: float = (grab.get_width() if grab != null else 16.0) * 0.5
	return Vector2(half, maxf(half, size.x - half))


func _x_of(value: float) -> float:
	var span := _span()
	var ratio := 0.0 if is_equal_approx(max_value, min_value) else (value - min_value) / (max_value - min_value)
	if is_layout_rtl(): ratio = 1.0 - ratio
	return lerpf(span.x, span.y, ratio)


func _value_at(x: float) -> float:
	var span := _span()
	var ratio := clampf((x - span.x) / maxf(1.0, span.y - span.x), 0.0, 1.0)
	if is_layout_rtl(): ratio = 1.0 - ratio
	return lerpf(min_value, max_value, ratio)


func _draw() -> void:
	var track := get_theme_stylebox(&"slider", &"HSlider")
	var fill := get_theme_stylebox(&"grabber_area_highlight" if has_focus() else &"grabber_area", &"HSlider")
	var mid := size.y * 0.5
	var height := track.get_minimum_size().y if track != null else 4.0
	height = maxf(height, 2.0)
	if track != null: draw_style_box(track, Rect2(0.0, mid - height * 0.5, size.x, height))
	var a := _x_of(low)
	var b := _x_of(high)
	if fill != null:
		var left := minf(a, b)
		draw_style_box(fill, Rect2(left, mid - height * 0.5, absf(b - a), height))
	for at: int in [0, 1]:
		var lit: bool = (_active == at) or (has_focus() and _last == at)
		var grab := _grabber(&"grabber_highlight" if lit else &"grabber")
		var x := a if at == 0 else b
		if grab != null:
			draw_texture(grab, Vector2(x, mid) - grab.get_size() * 0.5)
		else:
			draw_circle(Vector2(x, mid), 8.0, GoUi.color(GoTheme.ACCENT), true, -1.0, true)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed:
			grab_focus()
			_from = press.position
			var to_low := absf(press.position.x - _x_of(low))
			var to_high := absf(press.position.x - _x_of(high))
			# Both on one spot — wait for the finger to say which way.
			_active = -2 if absf(to_low - to_high) < 1.0 else (0 if to_low < to_high else 1)
			if _active >= 0: _move(_active, press.position.x)
		else:
			if _active != -1: change_ended.emit(low, high)
			_active = -1
			queue_redraw()
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _active != -1 and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _active == -2:
			var rightward := motion.position.x > _from.x
			if is_layout_rtl(): rightward = not rightward
			_active = 1 if rightward else 0
		_move(_active, motion.position.x)
		accept_event()
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		var way := 1.0 if event.is_action_pressed(&"ui_right") else -1.0
		if is_layout_rtl(): way = -way
		var by := step if step > 0.0 else (max_value - min_value) / 20.0
		if _last == 0: low = minf(low + way * by, high - min_gap)
		else: high = maxf(high + way * by, low + min_gap)
		changed.emit(low, high)
		change_ended.emit(low, high)
		accept_event()


func _move(handle: int, x: float) -> void:
	_last = handle
	var value := _snap(_value_at(x))
	if handle == 0: low = minf(value, high - min_gap)
	else: high = maxf(value, low + min_gap)
	changed.emit(low, high)
	queue_redraw()


## ♿ Says the two values — the range is the thing chosen.
func _name_it() -> void:
	accessibility_name = "%s – %s" % [_number(low), _number(high)]


static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	update_minimum_size()
	queue_redraw()
