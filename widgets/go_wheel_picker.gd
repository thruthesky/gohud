## 🎡 **A wheel of choices** — a short list that spins and settles one item on the band in the middle: a quantity, a
## level, a server, the parts of a birthday (Flutter's `CupertinoPicker` and `ListWheelScrollView`).
##
## ```gdscript
## var amount := GoWheelPicker.make(["1", "5", "10", "50", "100"], 2, func(index: int) -> void: buy(index))
## row.add_child(amount)
## # Three wheels side by side make a date or a time, as on iOS:
## var day := GoWheelPicker.make(days, 0)
## var month := GoWheelPicker.make(months, 0, Callable(), true)    # month names are translation keys
## ```
##
## ## 🔑 How it moves
## Drag it up and down and let go — it keeps spinning for a moment and settles on the nearest item. A tap on an item
## above or below the band brings it there; so does the mouse wheel. `changed` fires once it has settled on a
## different item, not on every item passing by.
##
## ## 🔑 Inside a scrolling page
## A drag that starts on the wheel turns the wheel (`GoScroll.OWNS_GESTURE`), as on iOS.
##
## ## ♿ Keys
## Focused, Up and Down move one item; the screen reader hears the item on the band.
@tool
class_name GoWheelPicker
extends Control

## The wheel settled on a new item.
signal changed(index: int)

## The height of one item (dp).
@export var item_height := 40.0:
	set(value):
		item_height = maxf(value, 16.0)
		update_minimum_size()
		queue_redraw()
## How many items show at once (odd keeps the band in the middle).
@export var visible_items := 5:
	set(value):
		visible_items = maxi(value, 1)
		update_minimum_size()
		queue_redraw()
## Treat the items as translation keys.
@export var translate := false:
	set(value):
		translate = value
		update_minimum_size()
		queue_redraw()

## The choices, in order.
var items := PackedStringArray()

var _selected := 0
## Where the wheel is now, in items (0 = the first item on the band).
var _at := 0.0
var _dragging := false
var _velocity := 0.0
var _last_move := 0
var _pressed_at := Vector2.INF
var _moved := false
var _tween: Tween
var _action := Callable()


func _init() -> void:
	name = "WheelPicker"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# 🔑 Turning the wheel is this control's own drag — the page around it does not take it.
	set_meta(GoScroll.OWNS_GESTURE, true)


func _ready() -> void:
	theme = GoUi.theme()
	_name_it()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A wheel of [param choices] with [param selected] on the band. [param action] is called with the index each time it
## settles on a new one. [param as_keys] treats the choices as translation keys.
static func make(choices: Array, selected := 0, action := Callable(), as_keys := false) -> GoWheelPicker:
	var node := GoWheelPicker.new()
	node.translate = as_keys
	node._action = action
	node.set_items(choices, selected)
	return node


## Replaces the choices and puts [param selected] on the band (without emitting).
func set_items(choices: Array, selected := 0) -> void:
	items = PackedStringArray()
	for each in choices: items.append(str(each))
	_selected = clampi(selected, 0, maxi(0, items.size() - 1))
	_at = float(_selected)
	update_minimum_size()
	_name_it()
	queue_redraw()


## The index on the band.
func get_selected() -> int:
	return _selected


## The item on the band (translated when `translate` is on).
func get_text() -> String:
	if items.is_empty(): return ""
	return _shown(items[_selected])


## Spins to [param index] (gliding when [param animate]) — `changed` fires if it is a new item.
func select(index: int, animate := true) -> void:
	if items.is_empty(): return
	index = clampi(index, 0, items.size() - 1)
	if _tween != null: _tween.kill()
	if not animate or not is_inside_tree():
		_at = float(index)
		_settle()
		return
	var travel := absf(index - _at)
	_tween = create_tween()
	_tween.tween_method(_turn_to, _at, float(index), clampf(0.12 + travel * 0.05, 0.12, 0.5)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_settle)


func _shown(item: String) -> String:
	return tr(item) if translate else item


func _get_minimum_size() -> Vector2:
	var font := get_theme_font(&"font", &"Label")
	var widest := 0.0
	if font != null:
		for item in items:
			widest = maxf(widest, font.get_string_size(_shown(item), HORIZONTAL_ALIGNMENT_LEFT, -1,
				GoUi.font_size(GoTheme.ROLE_SUBTITLE)).x)
	return Vector2(maxf(widest + 32.0, float(GoUi.metric(GoTheme.TOUCH))), item_height * visible_items)


func _draw() -> void:
	var skin := GoUi.skin()
	var middle := size.y * 0.5
	var band := Rect2(0.0, middle - item_height * 0.5, size.x, item_height)
	var face := skin.wheel_band_box()
	if face != null: draw_style_box(face, band)
	if has_focus():
		var ring := get_theme_stylebox(&"focus", &"Button")
		if ring != null: draw_style_box(ring, band)
	var font := get_theme_font(&"font", &"Label")
	if font == null or items.is_empty(): return
	var font_size := GoUi.font_size(GoTheme.ROLE_SUBTITLE)
	var chosen := skin.wheel_ink(true)
	var other := skin.wheel_ink(false)
	# 🔑 The items sit on a drum: one item's height is one step of turn, so the rows bunch up toward the top and the
	#    bottom and fade as they turn away.
	var radius := size.y * 0.5
	var step := item_height / radius
	var reach := int(ceil(PI * 0.5 / step))
	var centre := int(round(_at))
	for index in range(centre - reach, centre + reach + 1):
		if index < 0 or index >= items.size(): continue
		var turn := (index - _at) * step
		if absf(turn) >= PI * 0.5: continue
		var y := middle + sin(turn) * radius
		var squash := cos(turn)
		var near := clampf(1.0 - absf(index - _at), 0.0, 1.0)
		var ink := other.lerp(chosen, near)
		ink.a *= lerpf(0.25, 1.0, squash)
		var words := _shown(items[index])
		var box := font.get_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var ascent := font.get_ascent(font_size)
		draw_set_transform(Vector2(0.0, y), 0.0, Vector2(1.0, squash))
		draw_string(font, Vector2((size.x - box.x) * 0.5, ascent - box.y * 0.5), words, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size, ink)
	draw_set_transform(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null:
		if click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			select(_selected + (1 if click.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			accept_event()
		elif click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				grab_focus()
				if _tween != null: _tween.kill()
				_dragging = true
				_moved = false
				_velocity = 0.0
				_pressed_at = click.position
				_last_move = Time.get_ticks_msec()
			elif _dragging:
				_dragging = false
				if not _moved: _tap(click.position)
				else: _fling()
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _moved and motion.position.distance_to(_pressed_at) < 6.0: return
		_moved = true
		var now := Time.get_ticks_msec()
		var turn := -motion.relative.y / item_height
		var seconds := maxf(0.001, (now - _last_move) / 1000.0)
		_velocity = lerpf(_velocity, turn / seconds, 0.6)
		_last_move = now
		_turn_to(clampf(_at + turn, -0.4, items.size() - 0.6))
		accept_event()
		return
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"ui_down", true):
		select(_selected + (1 if event.is_action_pressed(&"ui_down", true) else -1))
		accept_event()


## A tap above or below the band brings that item to it.
func _tap(at: Vector2) -> void:
	var radius := size.y * 0.5
	var offset := clampf((at.y - size.y * 0.5) / radius, -1.0, 1.0)
	var steps := roundi(asin(offset) / (item_height / radius))
	# From where the wheel is — a tap that caught it mid-turn also lands it.
	select(roundi(_at) + steps)


## Let go while moving: keeps turning a little, then lands on an item.
func _fling() -> void:
	# A finger that stopped before letting go does not throw the wheel.
	if Time.get_ticks_msec() - _last_move > 80: _velocity = 0.0
	var land := clampi(roundi(_at + _velocity * 0.25), 0, items.size() - 1)
	select(land)


func _turn_to(value: float) -> void:
	_at = value
	queue_redraw()


func _settle() -> void:
	var index := clampi(roundi(_at), 0, maxi(0, items.size() - 1))
	_at = float(index)
	queue_redraw()
	if index == _selected: return
	_selected = index
	_name_it()
	changed.emit(index)
	if _action.is_valid(): _action.call(index)


## ♿ Says the item on the band.
func _name_it() -> void:
	accessibility_name = get_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and translate:
		_name_it()
		update_minimum_size()
		queue_redraw()


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	update_minimum_size()
	queue_redraw()
