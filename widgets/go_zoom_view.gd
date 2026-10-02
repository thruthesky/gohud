## 🔎 **A view you pinch to zoom and drag to pan** — a world map, a big picture, a skill tree, a floor plan
## (Flutter's `InteractiveViewer`). Two fingers zoom around the point between them; one finger pans once zoomed;
## a double tap zooms in on the spot (and back out).
##
## ```gdscript
## var map := GoZoomView.wrap(TextureRect.new(), 4.0)    # up to 4×
## (map.content as TextureRect).texture = preload("res://world_map.png")
## map.custom_minimum_size.y = 320
## page.add_child(map)
## map.zoom_changed.connect(func(zoom: float) -> void: legend.visible = zoom < 2.0)
## ```
##
## ## 🔑 The content
## The content fills the view at 1× (or keeps its own minimum size when that is bigger) and is scaled from there; it
## never slides out of the view. A mouse wheel and a trackpad pinch zoom around the pointer; `zoom_to()` and
## `reset()` do it from code.
##
## Buttons inside still take taps. A drag that starts on one pans the view only when it lets presses through
## (`MOUSE_FILTER_PASS`) — a `MOUSE_FILTER_STOP` control keeps its drag.
##
## ## 🔑 Inside a scrolling page
## A drag that starts on the view is the view's (`GoScroll.OWNS_GESTURE`), as in Flutter — give it a fixed height in a
## page that scrolls, so there is page left to scroll by.
##
## ## ♿ Keys
## Focused, `+` and `-` zoom, the arrow keys pan, `0` goes back to 1×.
@tool
class_name GoZoomView
extends Control

## The zoom changed (by a gesture, a key or code).
signal zoom_changed(zoom: float)

## The smallest zoom.
@export var min_zoom := 1.0
## The largest zoom.
@export var max_zoom := 4.0
## Where a double tap zooms to (it zooms back out when already zoomed).
@export var double_tap_zoom := 2.5
## How far one wheel notch zooms (a factor).
@export var wheel_step := 1.15

## What is zoomed.
var content: Control

var _zoom := 1.0
var _pan := Vector2.ZERO
var _touches := {}
var _pinch := Vector2.ZERO
var _pinch_span := 0.0
var _dragging := false
var _tween: Tween


func _init() -> void:
	name = "ZoomView"
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 🔑 Panning is this view's own drag — a scroll around it does not take it.
	set_meta(GoScroll.OWNS_GESTURE, true)


## A zoom view around [param inside], up to [param most] times.
static func wrap(inside: Control, most := 4.0) -> GoZoomView:
	var node := GoZoomView.new()
	node.max_zoom = most
	node.set_content(inside)
	return node


## Puts [param inside] in the view (the old content is freed).
func set_content(inside: Control) -> void:
	if is_instance_valid(content) and content != inside:
		remove_child(content)
		content.queue_free()
	content = inside
	if inside.get_parent() != self: add_child(inside)
	# The content lets presses through to the view, so a drag anywhere on it pans.
	if inside.mouse_filter == Control.MOUSE_FILTER_STOP: inside.mouse_filter = Control.MOUSE_FILTER_PASS
	_fit()


## The zoom now (1 = the content fills the view).
func get_zoom() -> float:
	return _zoom


## Zooms to [param zoom] around [param around] (local; the middle when left out), gliding when [param animate].
func zoom_to(zoom: float, around := Vector2.INF, animate := true) -> void:
	var point := size * 0.5 if not around.is_finite() else around
	zoom = clampf(zoom, min_zoom, max_zoom)
	if _tween != null: _tween.kill()
	if not animate or not is_inside_tree():
		_zoom_around(zoom / _zoom, point)
		return
	var start := _zoom
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: _zoom_around(value / _zoom, point), start, zoom, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Back to 1× with the content in place.
func reset(animate := true) -> void:
	zoom_to(min_zoom, size * 0.5, animate)


func _get_minimum_size() -> Vector2:
	return Vector2(GoUi.metric(GoTheme.TOUCH), GoUi.metric(GoTheme.TOUCH))


func _notification(what: int) -> void:
	# A size set before the view entered the tree sends no resize — fit again once it is in.
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY: _fit()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT: queue_redraw()


func _draw() -> void:
	if has_focus():
		var ring := get_theme_stylebox(&"focus", &"Button")
		if ring != null: draw_style_box(ring, Rect2(Vector2.ZERO, size))


## The content's size at 1× — the view, or the content's own minimum when bigger.
func _base() -> Vector2:
	if not is_instance_valid(content): return size
	return size.max(content.get_combined_minimum_size())


func _fit() -> void:
	if not is_instance_valid(content): return
	content.position = Vector2.ZERO
	content.size = _base()
	content.pivot_offset = Vector2.ZERO
	_apply()


## Scales by [param factor] keeping the content point under [param point] (local) where it is.
func _zoom_around(factor: float, point: Vector2) -> void:
	var zoom := clampf(_zoom * factor, min_zoom, max_zoom)
	var spot := (point - _pan) / _zoom
	var changed := not is_equal_approx(zoom, _zoom)
	_zoom = zoom
	_pan = point - spot * _zoom
	_apply()
	if changed: zoom_changed.emit(_zoom)


## Keeps the content covering the view (centred where it is smaller) and moves it there.
func _apply() -> void:
	if not is_instance_valid(content): return
	var shown := _base() * _zoom
	for axis in 2:
		if shown[axis] <= size[axis]: _pan[axis] = (size[axis] - shown[axis]) * 0.5
		else: _pan[axis] = clampf(_pan[axis], size[axis] - shown[axis], 0.0)
	content.scale = Vector2.ONE * _zoom
	content.position = _pan


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed: _touches[touch.index] = touch.position
		else: _touches.erase(touch.index)
		_start_pinch()
		accept_event()
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var pair := _pair()
			var middle := (pair[0] + pair[1]) * 0.5
			var span := pair[0].distance_to(pair[1])
			if _pinch_span > 1.0:
				_pan += middle - _pinch
				_zoom_around(span / _pinch_span, middle)
			_pinch = middle
			_pinch_span = span
		elif not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
			# No mouse stream made from touch — one finger pans from the touch itself.
			_pan += drag.relative
			_apply()
		accept_event()
		return
	var click := event as InputEventMouseButton
	if click != null:
		if click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var step := wheel_step if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / wheel_step
			_zoom_around(pow(step, maxf(click.factor, 1.0)), click.position)
			accept_event()
		elif click.button_index == MOUSE_BUTTON_LEFT:
			_dragging = click.pressed
			if click.pressed and click.double_click:
				zoom_to(min_zoom if _zoom > min_zoom * 1.05 else double_tap_zoom, click.position)
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		# One finger pans; while two are down the pinch moves the content instead.
		if _touches.size() < 2:
			_pan += motion.relative
			_apply()
		accept_event()
		return
	var magnify := event as InputEventMagnifyGesture
	if magnify != null:
		_zoom_around(magnify.factor, magnify.position)
		accept_event()
		return
	var swipe := event as InputEventPanGesture
	if swipe != null:
		_pan -= swipe.delta * 16.0
		_apply()
		accept_event()
		return
	_keys(event)


func _keys(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed:
		match key.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				zoom_to(_zoom * 1.5)
				accept_event()
				return
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_to(_zoom / 1.5)
				accept_event()
				return
			KEY_0, KEY_KP_0:
				reset()
				accept_event()
				return
	var nudge := Vector2.ZERO
	if event.is_action_pressed(&"ui_left", true): nudge.x = 1.0
	elif event.is_action_pressed(&"ui_right", true): nudge.x = -1.0
	elif event.is_action_pressed(&"ui_up", true): nudge.y = 1.0
	elif event.is_action_pressed(&"ui_down", true): nudge.y = -1.0
	if nudge != Vector2.ZERO and _zoom > min_zoom:
		_pan += nudge * float(GoUi.metric(GoTheme.TOUCH))
		_apply()
		accept_event()


## The first two fingers down.
func _pair() -> Array[Vector2]:
	var keys := _touches.keys()
	keys.sort()
	return [_touches[keys[0]] as Vector2, _touches[keys[1]] as Vector2]


## A second finger came or went — the pinch starts over from where the fingers are.
func _start_pinch() -> void:
	_pinch_span = 0.0
	if _touches.size() >= 2:
		var pair := _pair()
		_pinch = (pair[0] + pair[1]) * 0.5
		_pinch_span = pair[0].distance_to(pair[1])
