## 📑 **Paging** — mailbox, shop listings, friend lists, leaderboards.
##
## ```gdscript
## var pager := GoPagination.make(1, 12, func(page: int) -> void: load_mail(page))
## sheet.add_footer(pager)
## pager.set_page(3)
##
## # The "load more" row that suits mobile
## var more := GoPagination.more(func() -> void: append_next_page())
## list.add_child(more)
## more.set_busy(true)          # while waiting on the server — it cannot be pressed twice
## ```
##
## ## 🔑 On a phone "load more" is the better one
## Page numbers are a UI you point at precisely with a mouse. A thumb has trouble telling 1, 2 and 3 apart, and
## scrolling to the bottom of a list to hunt for a number breaks the flow too. **`more()` on a phone, `make()` on
## a tablet or PC** is usually the right call.
##
## ## 🛑 The page count may be unknown
## For lists where the server gives no total (infinite scroll) leave `total` at 0. The numbers then give way to
## just the back and forward buttons — **never pretend to know what you don't.**
##
## ## 🔑 It fits the width it is given
## Numbers take a 48dp touch cell each, so `window` is the **most** it shows. On a narrower row it shows fewer, and
## when not even three fit it folds to `‹ 5 / 12 ›`. It never pushes the page wider than the screen.
##
## ## 🛑 Lock it once it has been pressed
## Press next twice during a server round trip and you skip two pages or the responses arrive interleaved. Lock
## with `set_busy(true)`, and release when the result arrives.
@tool
class_name GoPagination
extends HBoxContainer

## The page changed (1-based).
signal page_changed(page: int)

## "Load more" was pressed.
signal more_requested

## The most number buttons to lay out. Beyond that they fold into `…` — and fewer fit on a narrow row (see above).
@export var window := 5:
	set(value):
		window = maxi(3, value)
		_rebuild()

var _page := 1
var _total := 0
var _more_mode := false
var _busy := false
var _action := Callable()
## The frame the numbers are laid in. A plain `Control`: its minimum width is the **narrowest** layout, so the pager
## never pushes its parent wider; its width comes from above and decides how many numbers fit.
var _frame: Control
## The row inside the frame — back, numbers, forward.
var _row: HBoxContainer
## How many numbers the row holds now. 0 is the compact `‹ 5 / 12 ›` form.
var _fitted := -1


func _init() -> void:
	name = "Pagination"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))


func _ready() -> void:
	_rebuild()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A pager with numbers. A `total` of 0 means the page count is unknown, so only back and forward are shown.
static func make(page: int, total: int, action := Callable()) -> GoPagination:
	var node := GoPagination.new()
	node._action = action
	node._total = maxi(0, total)
	node._page = maxi(1, page)
	return node


## A single "load more" row. Put it at the **bottom** of the list.
static func more(action := Callable()) -> GoPagination:
	var node := GoPagination.new()
	node._more_mode = true
	node._action = action
	return node


## The current page (1-based).
func page() -> int:
	return _page


func total() -> int:
	return _total


## Moves to a page. Values out of range clamp to the ends. Turn `notify` off and neither the signal nor the callback fires
## (used when **reflecting back** a page number the server sent — otherwise you get a reload loop).
func set_page(value: int, notify := true) -> void:
	var limit := _total if _total > 0 else value
	var next := clampi(value, 1, maxi(1, limit))
	if next == _page and not _more_mode: return
	_page = next
	_rebuild()
	if not notify: return
	page_changed.emit(_page)
	if _action.is_valid(): _action.call(_page)


## Changes the total page count (after the list was fetched again).
func set_total(value: int) -> void:
	_total = maxi(0, value)
	if _total > 0: _page = clampi(_page, 1, _total)
	_rebuild()


## Locks while waiting on the server — the button turns into a spinner and stops taking presses.
func set_busy(waiting: bool) -> void:
	_busy = waiting
	_rebuild()


func is_busy() -> bool:
	return _busy


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_frame = null
	_row = null
	_fitted = -1
	if _more_mode:
		var button := GoStyle.button(GoUi.text(&"next"), func() -> void:
			if _busy: return
			more_requested.emit()
			if _action.is_valid(): _action.call())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(button)
		if _busy: GoSpinner.busy.call_deferred(button, true)
		return

	# 🛑 **The numbers sit in a frame, not straight in this row.** A row's minimum width is the sum of its buttons, and a
	#    12-page pager needed 457dp — wider than a 390dp phone, so the whole gallery page ran 121dp off the screen
	#    (measured 2026-09-23). The frame reports the narrowest layout and learns the real width from its parent.
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_row = GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	_row.name = "Row"
	_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_row.set_meta(&"go_own_spacing", true)
	_frame.add_child(_row)
	_frame.resized.connect(_fit)
	_row.minimum_size_changed.connect(_place_row, CONNECT_DEFERRED)
	_fill(_fit_window(_frame.size.x))


## Lays out the row for [param count] numbers — 0 is the compact form.
func _fill(count: int) -> void:
	if _row == null: return
	_fitted = count
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_row.add_child(_step(&"back", _page - 1, _page > 1))
	if _total > 0:
		if count <= 0:
			_row.add_child(_where())
		else:
			for number in _numbers_for(count):
				_row.add_child(_gap() if number < 0 else _number(number))
	_row.add_child(_step(&"forward", _page + 1, _total <= 0 or _page < _total))
	_place_row()


## Keeps the frame as tall as the row and the row centered in it — a plain `Control` does not take its child's size.
func _place_row() -> void:
	if _frame == null or _row == null: return
	var need := _row.get_combined_minimum_size()
	var floor_size := Vector2(_row_width([]), need.y)
	if not _frame.custom_minimum_size.is_equal_approx(floor_size): _frame.custom_minimum_size = floor_size
	_row.size = need
	_row.position = Vector2(roundf((_frame.size.x - need.x) * 0.5), 0.0)


func _fit() -> void:
	if _frame == null: return
	var room := _frame.size.x
	var count := _fit_window(room)
	if count != _fitted: _fill(count)
	# The estimate is close, not exact — each skin pads the current page's face its own way. Step down until the real row fits.
	while _fitted != 0 and room > 0.0 and _row.get_combined_minimum_size().x > room + 0.5:
		_fill(_fitted - 1 if _fitted > 3 else 0)
	_place_row()


## The most numbers — `window` down to 3 — whose row fits [param room]; 0 when not even three do.
## Before the frame has a width it lays out `window` (the width arrives a frame later and the row is refitted).
func _fit_window(room: float) -> int:
	if _total <= 0 or room <= 0.0: return window
	for count in range(window, 2, -1):
		if _row_width(_numbers_for(count)) <= room + 0.5: return count
	return 0


## The width a row with these numbers needs (an empty list is the compact form).
func _row_width(numbers: Array[int]) -> float:
	var spacing := float(GoUi.metric(GoTheme.GAP_TINY))
	var arrows := float(GoUi.metric(GoTheme.TOUCH) - 12) * 2.0
	var font := get_theme_font(&"font", &"Label")
	var body := GoUi.font_size(GoTheme.ROLE_BODY)
	if numbers.is_empty():
		var shown := GoUi.text(&"bar_fraction").format({"value": _total, "max": _total})
		var words := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, body).x
		return arrows + ceilf(words) + float(GoUi.metric(GoTheme.GAP_SMALL)) * 2.0 + spacing * 2.0
	var width := arrows + spacing * float(numbers.size() + 1)
	var touch := float(GoUi.metric(GoTheme.TOUCH))
	var dots := ceilf(font.get_string_size("…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body).x)
	for number in numbers:
		width += dots if number < 0 else maxf(touch, ceilf(font.get_string_size(str(number), HORIZONTAL_ALIGNMENT_LEFT, -1.0, body).x) + 24.0)
	return width


## The `…` between folded numbers — one line, as wide as itself.
func _gap() -> Control:
	var gap := GoStyle.label("…", GoTheme.ROLE_BODY, GoUi.color(GoTheme.MUTED))
	gap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return GoStyle.one_line(gap)


## The compact form's `5 / 12` — where you are, when the numbers do not fit.
func _where() -> Control:
	var where := GoStyle.label(GoUi.text(&"bar_fraction").format({"value": _page, "max": _total}), GoTheme.ROLE_BODY)
	where.name = "Where"
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	where.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GoStyle.one_line(where)
	var room := float(GoUi.metric(GoTheme.GAP_SMALL))
	where.custom_minimum_size.x = ceilf(where.get_combined_minimum_size().x) + room * 2.0
	return where


## The back and forward buttons.
func _step(icon: StringName, target: int, enabled: bool) -> Control:
	var button := GoIconButton.new()
	button.icon_name = icon
	# 🔑 Icon names and text keys are **two separate lists** — the picture is `forward`, the word read out is `next`.
	button.tooltip_text_name = &"back" if icon == &"back" else &"next"
	button.disabled = not enabled or _busy
	button.pressed.connect(func() -> void: set_page(target))
	return button


## One number button.
func _number(value: int) -> Control:
	var button := GoStyle.button(str(value), func() -> void: set_page(value),
		GoStyle.Tone.PRIMARY if value == _page else GoStyle.Tone.BARE)
	# 🛑 Numbers are never translated — a page number must not turn into different characters.
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# 🛑 The touch minimum is about **height** as much as width. Numbers other than the current page use `Tone.BARE`,
	#    and that tone sets no minimum height — so the very thing you **press** ends up below the minimum (measured 2026-09-16).
	button.custom_minimum_size = Vector2.ONE * float(GoUi.metric(GoTheme.TOUCH))
	button.disabled = _busy
	# ♿ "3" on its own does not say 3 of what. 🔑 The "n / m" format goes through a text key.
	button.accessibility_name = GoUi.text(&"bar_fraction").format({"value": value, "max": _total})
	return button


## The numbers to lay out. `-1` marks a `…` slot.
## 🔑 The window slides so the current page is always in the **middle** — fold only at the edges and pressing next on
##    page 9 replaces the whole row of numbers at once, losing track of where you were.
func _numbers() -> Array[int]:
	return _numbers_for(_fitted if _fitted > 0 else (window if _fitted < 0 else 0))


## The numbers for a window of [param count] (0 = none, the compact form).
func _numbers_for(count: int) -> Array[int]:
	var out: Array[int] = []
	if count <= 0: return out
	if _total <= count:
		for i in range(1, _total + 1): out.append(i)
		return out
	var half := count / 2
	var first := clampi(_page - half, 1, maxi(1, _total - count + 1))
	var last := mini(_total, first + count - 1)
	if first > 1:
		out.append(1)
		if first > 2: out.append(-1)
	for i in range(first, last + 1): out.append(i)
	if last < _total:
		if last < _total - 1: out.append(-1)
		out.append(_total)
	return out


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _rebuild()
