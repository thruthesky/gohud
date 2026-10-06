## 📅 **Date picker** — a month of days to tap: a delivery date, a booking, a birthday, a "from" date for a filter.
##
## ```gdscript
## var picker := GoDatePicker.make({"year": 2026, "month": 10, "day": 2}, func(date: Dictionary) -> void:
## 	delivery_label.text = "%d-%02d-%02d" % [date.year, date.month, date.day])
## picker.min_date = GoDatePicker.today()     # nothing in the past
## var sheet := GoSheet.open(&"Delivery date")  # or any container — it is a plain control
## sheet.body.add_child(picker)
## ```
##
## ## 🔑 What it shows
## The month and year with arrows to the month before and after, the days of the week (from `first_weekday`), and the
## days: today ringed, the picked day filled, days outside `min_date` … `max_date` dimmed and unpressable.
## Month and weekday names come from gohud's translations (`gohud_month_*`, `gohud_weekday_*`), so they follow the
## game's language; Sunday-first or Monday-first is yours to set (`first_weekday`).
##
## ## 🔑 The look
## The skin draws each day (`GoSkin.date_cell_box`): a round 40dp cell in a 48dp touch target, filled with the accent
## when picked and ringed when it is today — under Material the M3 date picker's `primary` cell.
@tool
class_name GoDatePicker
extends Container

## A day was picked — `{"year": int, "month": int, "day": int}`.
signal picked(date: Dictionary)
## In `range_mode`, both ends of a range were picked (the earlier one first).
signal range_picked(start: Dictionary, end: Dictionary)

## 🔑 Pick a range — check-in to check-out, a report's from and to (Flutter's `showDateRangePicker`). The first tap
## sets the start, the second the end (an earlier day starts over); the days between are marked. Turning it on
## clears the picked day (the month shown stays) — `set_range()` shows a range picked before.
@export var range_mode := false:
	set(value):
		if value and not range_mode: _selected = {}
		range_mode = value
		_end = {}
		_rebuild()

## The first column's weekday: 0 Sunday … 6 Saturday (1 for a Monday-first calendar).
@export_range(0, 6) var first_weekday := 0:
	set(value):
		first_weekday = clampi(value, 0, 6)
		_rebuild()

## The earliest day that can be picked (`{"year", "month", "day"}`); empty for no limit.
var min_date := {}:
	set(value):
		min_date = value
		_rebuild()

## The latest day that can be picked; empty for no limit.
var max_date := {}:
	set(value):
		max_date = value
		_rebuild()

## Side of a day's touch target and of the round cell drawn in it (dp) — `_md-comp-date-picker-modal.scss`.
const CELL := 48.0
const DATE := 40.0
## The narrowest a day gets (dp) when seven of them must fit a narrow phone — it stays 48dp tall.
const CELL_MIN := 36.0

var _year := 2026
var _month := 1
var _selected := {}
## The range's end (`range_mode`); `_selected` is its start.
var _end := {}
var _action := Callable()
var _title: Label
var _grid: GridContainer
var _week: HBoxContainer
var _prev: GoIconButton
var _next: GoIconButton
## The column that holds the month row, the weekdays and the days — laid out by this container (`_notification`).
var _column: VBoxContainer
## The side of a day now — `CELL`, or less when seven of them do not fit the width given (`_fit`).
var _cell := 40.0


func _init() -> void:
	name = "DatePicker"
	mouse_filter = Control.MOUSE_FILTER_PASS
	# 🔑 It takes the row's width and fits seven days into it — 48dp each where there is room, down to 36dp on a 320dp
	#    phone, so the month never pushes the page wider than the screen. It asks only for seven narrow days
	#    (`_get_minimum_size`); a box container would ask for the days as they are drawn now, and once drawn wide on a
	#    wide window it could never shrink back.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 0)
	add_child(_column)
	_column.minimum_size_changed.connect(func() -> void:
		update_minimum_size()
		queue_sort())
	var now := today()
	_year = int(now.year)
	_month = int(now.month)


func _ready() -> void:
	_rebuild()
	GoUi.watch(_rebuild)


func _exit_tree() -> void:
	GoUi.unwatch(_rebuild)


## A picker with [param selected] picked (empty: nothing yet — it opens on this month). [param action] gets the date.
static func make(selected := {}, action := Callable()) -> GoDatePicker:
	var node := GoDatePicker.new()
	node._action = action
	if not selected.is_empty():
		node._selected = _clean(selected)
		node._year = int(node._selected.year)
		node._month = int(node._selected.month)
	return node


## Today on this device, as `{"year", "month", "day"}`.
static func today() -> Dictionary:
	return _clean(Time.get_date_dict_from_system())


## The picked date (empty when nothing is picked).
func get_date() -> Dictionary:
	return _selected.duplicate()


## Picks [param date] and shows its month, without emitting `picked`.
func set_date(date: Dictionary) -> void:
	_selected = _clean(date) if not date.is_empty() else {}
	if not _selected.is_empty():
		_year = int(_selected.year)
		_month = int(_selected.month)
	_rebuild()


## Shows [param month] (1 … 12) of [param year].
func show_month(year: int, month: int) -> void:
	_year = year + floori((month - 1) / 12.0)
	_month = posmod(month - 1, 12) + 1
	_rebuild()


## The shown month and year.
func shown_month() -> Vector2i:
	return Vector2i(_year, _month)


func _rebuild() -> void:
	if not is_inside_tree(): return
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var skin := GoUi.skin()
	# ── The month row: "October 2026"  ‹ ›
	var head := HBoxContainer.new()
	head.name = "Month"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size.y = _cell
	# 36dp arrows that take presses 48dp wide — 12dp apart, their touch areas meet.
	head.add_theme_constant_override(&"separation", 12)
	_column.add_child(head)
	_title = GoStyle.label(_month_title(), GoTheme.ROLE_BUTTON)
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.set_meta(&"go_no_wrap", true)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var title_pad := MarginContainer.new()
	title_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_pad.add_theme_constant_override(&"margin_left", GoUi.metric(GoTheme.GAP))
	title_pad.add_child(_title)
	head.add_child(title_pad)
	var rtl := is_layout_rtl()
	_prev = _arrow(GoIconSet.CHEVRON_RIGHT if rtl else GoIconSet.CHEVRON_LEFT, &"previous_month", -1)
	_next = _arrow(GoIconSet.CHEVRON_LEFT if rtl else GoIconSet.CHEVRON_RIGHT, &"next_month", 1)
	_prev.touch_peers = [_prev, _next]
	_next.touch_peers = [_prev, _next]
	head.add_child(_prev)
	head.add_child(_next)
	# ── The weekday row
	_week = HBoxContainer.new()
	_week.name = "Weekdays"
	_week.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_week.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_week.add_theme_constant_override(&"separation", 0)
	_column.add_child(_week)
	for column in 7:
		var weekday := (first_weekday + column) % 7
		var mark := GoStyle.label(GoUi.text(StringName("weekday_%d" % weekday)), GoTheme.ROLE_COMPACT)
		mark.custom_minimum_size = Vector2(_cell, 32.0)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mark.autowrap_mode = TextServer.AUTOWRAP_OFF
		mark.set_meta(&"go_no_wrap", true)
		# 🛑 A weekday mark is one letter or two — clipped to its cell so a long translation never widens the month.
		mark.clip_text = true
		_week.add_child(mark)
	# ── The days
	_grid = GridContainer.new()
	_grid.name = "Days"
	_grid.columns = 7
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override(&"h_separation", 0)
	_grid.add_theme_constant_override(&"v_separation", 0)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_grid)
	var first := _weekday_of(_year, _month, 1)
	var lead := posmod(first - first_weekday, 7)
	var count := _days_in(_year, _month)
	var now := today()
	for slot in 42:
		var day := slot - lead + 1
		if day < 1 or day > count:
			var blank := Control.new()
			blank.custom_minimum_size = Vector2(_cell, CELL)
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid.add_child(blank)
			continue
		var date := {"year": _year, "month": _month, "day": day}
		var kind := &"day"
		if _same(date, _selected) or _same(date, _end): kind = &"selected"
		elif range_mode and not _end.is_empty() and _order(date, _selected) > 0 and _order(date, _end) < 0: kind = &"in_range"
		elif _same(date, now): kind = &"today"
		var cell := _day_cell(date, kind, skin)
		# The ends of a range: the band runs on under their circles toward the days between.
		if kind == &"selected" and range_mode and not _end.is_empty():
			cell.set_meta(&"go_range_side", 1 if _same(date, _selected) else -1)
		_grid.add_child(cell)
	if range_mode and not _end.is_empty():
		_grid.draw.connect(_draw_band.bind(_grid))
		# 🛑 Drawn again once the days are laid out — drawn before, the halves landed on the first cell (2026-10-02).
		_grid.sort_children.connect(_grid.queue_redraw)
	# Six rows always — a month that needs five keeps the picker the same height, so nothing below it jumps.


## Half a cell of the range band under the start and the end circle, on the side of the days between — drawn by the
## grid under its days, so the band reaches the circles instead of stopping a gap short of them.
func _draw_band(grid: GridContainer) -> void:
	var face := GoUi.skin().date_cell_box(&"in_range", &"normal")
	var lift := (CELL - minf(DATE, _cell)) * 0.5
	var ahead := -1.0 if grid.is_layout_rtl() else 1.0
	for child in grid.get_children():
		if not child.has_meta(&"go_range_side"): continue
		var cell := child as Control
		var half := cell.size.x * 0.5
		var toward := float(child.get_meta(&"go_range_side")) * ahead
		var x := cell.position.x + (half if toward > 0.0 else 0.0)
		grid.draw_style_box(face, Rect2(x, cell.position.y + lift, half, cell.size.y - lift * 2.0))


func _get_minimum_size() -> Vector2:
	var tall := _column.get_combined_minimum_size().y if _column != null else 0.0
	return Vector2(7.0 * CELL_MIN, tall)


## Seven days across the width given — each `CELL` at most and `CELL_MIN` at least — centred in it.
func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or _column == null: return
	var cell := clampf(floorf(size.x / 7.0), CELL_MIN, CELL)
	if not is_equal_approx(cell, _cell):
		_cell = cell
		_rebuild.call_deferred()
	var wide := minf(size.x, maxf(7.0 * _cell, _column.get_combined_minimum_size().x))
	fit_child_in_rect(_column, Rect2(Vector2((size.x - wide) * 0.5, 0.0), Vector2(wide, _column.get_combined_minimum_size().y)))


func _arrow(icon: StringName, tooltip: StringName, step: int) -> GoIconButton:
	var button := GoIconButton.new()
	button.icon_name = icon
	button.tooltip_text_name = tooltip
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: show_month(_year, _month + step))
	return button


func _day_cell(date: Dictionary, kind: StringName, skin: GoSkin) -> Button:
	var button := Button.new()
	button.name = "Day%d" % int(date.day)
	button.text = str(int(date.day))
	# 🔑 Always 48dp tall; as wide as seven columns allow, down to `CELL_MIN` on a 320dp phone (M3 narrows the same way).
	#    `go_touch_floor` tells the layout audit that this width is the calendar's floor, not a mistake.
	button.custom_minimum_size = Vector2(_cell, CELL)
	button.set_meta(&"go_touch_floor", CELL_MIN)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	GoScroll.scroll_through(button)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.add_theme_font_size_override(&"font_size", GoUi.font_size(GoTheme.ROLE_CAPTION))
	# The round cell: 40dp, or the column's width when that is narrower — a circle either way.
	var side := minf(DATE, _cell)
	var inset := Vector2((_cell - side) * 0.5, (CELL - side) * 0.5)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var shown: StringName = &"pressed" if state == &"hover_pressed" else state
		if shown == &"disabled": shown = &"normal"
		var face := skin.date_cell_box(kind, shown)
		# 🔑 The round cell is 40dp inside the 48dp touch target (the focus ring stands outside it).
		var shrink := inset - Vector2.ONE * (3.0 if state == &"focus" else 0.0)
		# A day inside a range is a strip from edge to edge, so the marked days join into one band.
		if kind == &"in_range" and state != &"focus": shrink.x = 0.0
		face.expand_margin_left = -shrink.x
		face.expand_margin_top = -shrink.y
		face.expand_margin_right = -shrink.x
		face.expand_margin_bottom = -shrink.y
		button.add_theme_stylebox_override(state, face)
	var ink := skin.date_ink(kind)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(key, ink)
	button.add_theme_color_override(&"font_disabled_color", Color(ink, ink.a * 0.38))
	# Its own ink on its own face, so plain letters: a look's label outline (the arcade keys' ink round a white label)
	# would blur dark letters into a blot.
	button.add_theme_constant_override(&"outline_size", 0)
	var allowed := (min_date.is_empty() or _order(date, _clean(min_date)) >= 0) \
		and (max_date.is_empty() or _order(date, _clean(max_date)) <= 0)
	button.disabled = not allowed
	button.accessibility_name = GoUi.spoken([_month_title(), str(int(date.day))])
	button.pressed.connect(_pick.bind(date))
	return button


func _pick(date: Dictionary) -> void:
	if range_mode:
		# The first tap starts a range; the second ends it — or starts over when it is not after the start.
		if _selected.is_empty() or not _end.is_empty() or _order(date, _selected) <= 0:
			_selected = date.duplicate()
			_end = {}
		else:
			_end = date.duplicate()
	else:
		_selected = date.duplicate()
	_rebuild()
	picked.emit(date.duplicate())
	if _action.is_valid(): _action.call(date.duplicate())
	if range_mode and not _end.is_empty(): range_picked.emit(_selected.duplicate(), _end.duplicate())


## The picked range as `[start, end]` (`range_mode`); empty until both ends are picked.
func get_range() -> Array:
	return [] if _selected.is_empty() or _end.is_empty() else [_selected.duplicate(), _end.duplicate()]


## Sets the range without emitting (`range_mode`).
func set_range(start: Dictionary, end: Dictionary) -> void:
	var a := _clean(start)
	var b := _clean(end)
	if _order(a, b) > 0:
		var swap := a
		a = b
		b = swap
	_selected = a
	_end = b
	_year = int(a.year)
	_month = int(a.month)
	_rebuild()


## "October 2026" in the game's language (`gohud_date_month_year` with `gohud_month_10`).
func _month_title() -> String:
	return GoUi.text(&"date_month_year").format({
		"month": GoUi.text(StringName("month_%d" % _month)), "year": str(_year)})


static func _clean(date: Dictionary) -> Dictionary:
	return {"year": int(date.get("year", 1970)), "month": clampi(int(date.get("month", 1)), 1, 12),
		"day": clampi(int(date.get("day", 1)), 1, 31)}


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and _order(a, b) == 0


## -1, 0 or 1 as [param a] comes before, on or after [param b].
static func _order(a: Dictionary, b: Dictionary) -> int:
	var left := int(a.year) * 10000 + int(a.month) * 100 + int(a.day)
	var right := int(b.year) * 10000 + int(b.month) * 100 + int(b.day)
	return signi(left - right)


static func _days_in(year: int, month: int) -> int:
	if month == 2:
		var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


## 0 Sunday … 6 Saturday.
static func _weekday_of(year: int, month: int, day: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12})
	return int(Time.get_datetime_dict_from_unix_time(unix).weekday)
