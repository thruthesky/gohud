## 🕘 **Time picker** — the clock dial: tap the hour, then the minutes, around a dial (Flutter's `showTimePicker`,
## Material's time picker). A reminder, a booking slot, an alarm.
##
## ```gdscript
## var when := GoTimePicker.make(9, 30, func(hour: int, minute: int) -> void: alarm.set_time(hour, minute))
## sheet.body.add_child(when)
## when.use_24h = true                    # 00–23 on two rings instead of 1–12 with AM / PM
## ```
##
## ## 🔑 Hour first, then minutes
## The two boxes at the top say the time and which part the dial sets. A tap (or a drag) on the dial picks the hour,
## and the dial turns to the minutes by itself; tap the hour box to go back. Minutes snap to the minute under the
## finger; the labels show every five.
##
## ## 🔑 12 or 24 hours
## With `use_24h` off the hour dial is 1–12 with AM and PM beside the boxes; on, the outer ring is 1–12 and the inner
## ring 13–00. AM, PM and the box names come from gohud's translations. `hour` is always 0–23.
##
## ## 🔑 The look
## The skin draws the boxes (`GoSkin.time_selector_box`) and colours the dial (`GoSkin.dial_colors`) — the accent hand
## on a soft disc by default; under Material the M3 time picker's `primary-container` boxes and `primary` hand.
##
## ## ♿ Keys
## Focus the hour or the minute box and Up / Down turn it by one; the boxes and AM / PM take Tab and Enter like buttons.
@tool
class_name GoTimePicker
extends Container

## The time changed — `hour` 0–23, `minute` 0–59.
signal picked(hour: int, minute: int)

## A 24-hour dial (two rings) instead of 1–12 with AM and PM.
@export var use_24h := false:
	set(value):
		use_24h = value
		_rebuild()

## Side of the dial (dp) at full size, and of the hour and minute boxes — `_md-comp-time-picker.scss`.
const DIAL := 256.0
const BOX := Vector2(96, 80)
const PERIOD := Vector2(52, 80)

var hour := 9
var minute := 0
## Which part the dial sets: 0 hour, 1 minute.
var _part := 0
var _action := Callable()
var _column: VBoxContainer
var _hour_box: Button
var _minute_box: Button
var _am: Button
var _pm: Button
var _dial: _Dial


func _init() -> void:
	name = "TimePicker"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 24)
	add_child(_column)
	_column.minimum_size_changed.connect(func() -> void:
		update_minimum_size()
		queue_sort())


func _ready() -> void:
	_rebuild()
	GoUi.watch(_rebuild)


func _exit_tree() -> void:
	GoUi.unwatch(_rebuild)


## A picker at [param at_hour]:[param at_minute] (0–23, 0–59; negative takes the current time); [param action] gets each
## change.
static func make(at_hour := -1, at_minute := -1, action := Callable(), twenty_four := false) -> GoTimePicker:
	var node := GoTimePicker.new()
	var now := Time.get_time_dict_from_system()
	node.hour = clampi(at_hour if at_hour >= 0 else int(now.hour), 0, 23)
	node.minute = clampi(at_minute if at_minute >= 0 else int(now.minute), 0, 59)
	node._action = action
	node.use_24h = twenty_four
	return node


## The chosen time as `{"hour", "minute"}`.
func get_time() -> Dictionary:
	return {"hour": hour, "minute": minute}


## Sets the time without emitting `picked`.
func set_time(at_hour: int, at_minute: int) -> void:
	hour = clampi(at_hour, 0, 23)
	minute = clampi(at_minute, 0, 59)
	_refresh()


## Shows the hour dial (0) or the minute dial (1).
func show_part(part: int) -> void:
	_part = clampi(part, 0, 1)
	_refresh()


func current_part() -> int:
	return _part


func _get_minimum_size() -> Vector2:
	var tall := _column.get_combined_minimum_size().y if _column != null else 0.0
	return Vector2(240.0, tall)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and _column != null:
		_fit_head(size.x)
		var wide := clampf(size.x, 0.0, maxf(DIAL, _column.get_combined_minimum_size().x))
		fit_child_in_rect(_column, Rect2(Vector2((size.x - wide) * 0.5, 0.0), Vector2(wide, _column.get_combined_minimum_size().y)))
		if _dial != null:
			var side := clampf(size.x, 200.0, DIAL)
			if not is_equal_approx(_dial.custom_minimum_size.x, side): _dial.custom_minimum_size = Vector2.ONE * side


## Narrower boxes on a narrow phone — the row of boxes is 280dp at full size, 244dp tight.
func _fit_head(width: float) -> void:
	if _hour_box == null: return
	var tight := width < 280.0
	var box := Vector2(80, BOX.y) if tight else BOX
	if not _hour_box.custom_minimum_size.is_equal_approx(box):
		_hour_box.custom_minimum_size = box
		_minute_box.custom_minimum_size = box
		if _am != null:
			# Narrower on a narrow phone, but never under a finger's width.
			_am.custom_minimum_size.x = float(GoUi.metric(GoTheme.TOUCH)) if tight else PERIOD.x
			_pm.custom_minimum_size.x = _am.custom_minimum_size.x


func _rebuild() -> void:
	if not is_inside_tree() or _column == null: return
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override(&"separation", 0)
	_column.add_child(head)
	_hour_box = _selector(GoUi.text(&"hour"), func() -> void: show_part(0), 0)
	head.add_child(_hour_box)
	var colon := GoStyle.label(":", GoTheme.ROLE_TITLE)
	colon.custom_minimum_size = Vector2(24, BOX.y)
	colon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	colon.autowrap_mode = TextServer.AUTOWRAP_OFF
	colon.set_meta(&"go_no_wrap", true)
	colon.add_theme_font_size_override(&"font_size", 48)
	colon.layout_direction = Control.LAYOUT_DIRECTION_LTR
	head.add_child(colon)
	_minute_box = _selector(GoUi.text(&"minute"), func() -> void: show_part(1), 1)
	head.add_child(_minute_box)
	head.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_am = null
	_pm = null
	if not use_24h:
		var gap := Control.new()
		gap.custom_minimum_size.x = 12
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(gap)
		var periods := VBoxContainer.new()
		# 🔑 Apart, not touching — two edges side by side read as one thick line (2026-10-03 review).
		periods.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))
		periods.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(periods)
		_am = _period(GoUi.text(&"am"), func() -> void: _set_hour(hour % 12))
		_pm = _period(GoUi.text(&"pm"), func() -> void: _set_hour(hour % 12 + 12))
		periods.add_child(_am)
		periods.add_child(_pm)
	_dial = _Dial.new()
	_dial.picker = self
	_dial.custom_minimum_size = Vector2.ONE * DIAL
	_dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_dial)
	_refresh()


func _selector(name_words: String, action: Callable, part: int) -> Button:
	var box := Button.new()
	box.gui_input.connect(_nudge.bind(box, part))
	box.custom_minimum_size = BOX
	box.focus_mode = Control.FOCUS_ALL
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_theme_font_size_override(&"font_size", 48)
	box.set_meta(&"go_part_name", name_words)
	box.pressed.connect(action)
	return box


## ♿ Up and Down on a focused hour or minute box turn its value by one — the dial needs a pointer, this does not.
func _nudge(event: InputEvent, box: Button, part: int) -> void:
	var up := event.is_action_pressed(&"ui_up", true)
	if not up and not event.is_action_pressed(&"ui_down", true): return
	var way := 1 if up else -1
	if part == 0:
		if use_24h: _set_hour(posmod(hour + way, 24))
		else: _set_hour(posmod(hour % 12 + way, 12) + (12 if hour >= 12 else 0))
	else:
		minute = posmod(minute + way, 60)
		_refresh()
		_emit()
	box.accept_event()


func _period(words: String, action: Callable) -> Button:
	var box := Button.new()
	box.text = words
	# 🔑 Each a full touch target tall — M3's 52×80 selector gives each half 40dp, too little for a finger (the layout
	#    audit flagged it); the hour and minute boxes grow to the column's height so the row stays even.
	box.custom_minimum_size = Vector2(PERIOD.x, maxf(PERIOD.y * 0.5, float(GoUi.metric(GoTheme.TOUCH))))
	box.focus_mode = Control.FOCUS_ALL
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_theme_font_size_override(&"font_size", GoUi.font_size(GoTheme.ROLE_BUTTON))
	box.pressed.connect(action)
	return box


## Puts the time and the chosen part on the boxes and redraws the dial.
func _refresh() -> void:
	if _hour_box == null: return
	var shown_hour := hour if use_24h else (12 if hour % 12 == 0 else hour % 12)
	_hour_box.text = str(shown_hour).pad_zeros(2) if use_24h else str(shown_hour)
	_minute_box.text = str(minute).pad_zeros(2)
	for pair in [[_hour_box, _part == 0], [_minute_box, _part == 1]]:
		_dress(pair[0], bool(pair[1]), false)
	(_hour_box as Button).accessibility_name = GoUi.spoken([str(_hour_box.get_meta(&"go_part_name")), _hour_box.text])
	(_minute_box as Button).accessibility_name = GoUi.spoken([str(_minute_box.get_meta(&"go_part_name")), _minute_box.text])
	if _am != null:
		_dress(_am, hour < 12, true)
		_dress(_pm, hour >= 12, true)
	if _dial != null: _dial.queue_redraw()


func _dress(box: Button, selected: bool, period: bool) -> void:
	var skin := GoUi.skin()
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		box.add_theme_stylebox_override(state, skin.time_selector_box(selected, state, period))
	var ink := skin.time_ink(selected, period)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		box.add_theme_color_override(key, ink)


func _set_hour(value: int) -> void:
	if value == hour: return
	hour = value
	_refresh()
	_emit()


func _emit() -> void:
	picked.emit(hour, minute)
	if _action.is_valid(): _action.call(hour, minute)


## The dial's answer for a point: an hour 0–23 (its ring decides in 24-hour mode) or a minute 0–59.
func _value_at(local: Vector2, center: Vector2, radius: float) -> int:
	var offset := local - center
	# 12 o'clock is up; the clock turns clockwise.
	var turn := fposmod(atan2(offset.x, -offset.y), TAU) / TAU
	if _part == 1: return roundi(turn * 60.0) % 60
	var slot := roundi(turn * 12.0) % 12
	if use_24h:
		var inner := offset.length() < radius * 0.62
		if inner: return 0 if slot == 0 else slot + 12
		return 12 if slot == 0 else slot
	var twelve := 12 if slot == 0 else slot
	var afternoon := hour >= 12
	return (twelve % 12) + (12 if afternoon else 0)


## The dial: the disc, the numbers, the hand.
class _Dial extends Control:
	var picker: GoTimePicker
	var _dragging := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		# A drag on the dial turns the hand — it owns its gesture inside a list.
		set_meta(GoScroll.OWNS_GESTURE, true)

	func _gui_input(event: InputEvent) -> void:
		var press := event as InputEventMouseButton
		if press != null and press.button_index == MOUSE_BUTTON_LEFT:
			if press.pressed:
				_dragging = true
				_take(press.position)
			elif _dragging:
				_dragging = false
				_take(press.position)
				# 🔑 After the hour, the dial turns to the minutes by itself.
				if picker._part == 0:
					GoFeedback.tapped()
					picker.show_part(1)
			accept_event()
			return
		var motion := event as InputEventMouseMotion
		if motion != null and _dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_take(motion.position)
			accept_event()

	func _take(at: Vector2) -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		var value := picker._value_at(at, center, radius)
		if picker._part == 0:
			picker._set_hour(value)
		elif value != picker.minute:
			picker.minute = value
			picker._refresh()
			picker._emit()

	func _draw() -> void:
		var colors := GoUi.skin().dial_colors()
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		draw_circle(center, radius, colors[0], true, -1.0, true)
		var font := get_theme_font(&"font", &"Label")
		var font_size := GoUi.font_size(GoTheme.ROLE_BODY)
		var knob := 24.0 * radius / (DIAL * 0.5)
		var outer := radius - knob - 4.0
		var inner := outer * 0.62
		# Where the hand points.
		var hand_turn := 0.0
		var hand_radius := outer
		if picker._part == 1:
			hand_turn = picker.minute / 60.0
		else:
			var h := picker.hour
			hand_turn = (h % 12) / 12.0
			if picker.use_24h and (h == 0 or h > 12): hand_radius = inner
		var tip := center + Vector2(sin(hand_turn * TAU), -cos(hand_turn * TAU)) * hand_radius
		draw_line(center, tip, colors[1], 2.0, true)
		draw_circle(center, 4.0, colors[1], true, -1.0, true)
		draw_circle(tip, knob, colors[1], true, -1.0, true)
		# The numbers.
		var labels: Array = []
		if picker._part == 1:
			for i in 12: labels.append([i * 5, "%02d" % (i * 5), outer, i / 12.0])
		else:
			for i in 12:
				var twelve := 12 if i == 0 else i
				labels.append([twelve, str(twelve), outer, i / 12.0])
				if picker.use_24h:
					var night := 0 if i == 0 else i + 12
					labels.append([night, "%02d" % night, inner, i / 12.0])
		for each in labels:
			var spot: Vector2 = center + Vector2(sin(each[3] * TAU), -cos(each[3] * TAU)) * float(each[2])
			var words: String = each[1]
			var on_hand := spot.distance_to(tip) < knob * 0.6
			var ink: Color = colors[3] if on_hand else colors[2]
			var small := font_size if float(each[2]) == outer else maxi(10, font_size - 3)
			var box := font.get_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, -1, small)
			draw_string(font, spot + Vector2(-box.x * 0.5, box.y * 0.3), words, HORIZONTAL_ALIGNMENT_CENTER, -1,
				small, ink)
		# A minute between the labels still shows on the hand's knob.
		if picker._part == 1 and picker.minute % 5 != 0:
			draw_circle(tip, 3.0, colors[3], true, -1.0, true)
