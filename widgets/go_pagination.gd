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

## How many number buttons to lay out. Beyond that they fold into `…`.
@export var window := 5:
	set(value):
		window = maxi(3, value)
		_rebuild()

var _page := 1
var _total := 0
var _more_mode := false
var _busy := false
var _action := Callable()


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
	for child in get_children(): child.queue_free()
	if _more_mode:
		var button := GoStyle.button(GoUi.text(&"next"), func() -> void:
			if _busy: return
			more_requested.emit()
			if _action.is_valid(): _action.call())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(button)
		if _busy: GoSpinner.busy.call_deferred(button, true)
		return

	add_child(_step(&"back", _page - 1, _page > 1))
	if _total > 0:
		for number in _numbers():
			if number < 0:
				var gap := GoStyle.label("…", GoTheme.ROLE_BODY, GoUi.color(GoTheme.MUTED))
				gap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				add_child(gap)
				continue
			add_child(_number(number))
	# 🛑 An icon name has to be one that **actually exists in the set** — otherwise an empty box is drawn and all you get is a warning.
	#    In the default set, back and forward are `back`/`forward` (`next` is a text key, not an icon name).
	add_child(_step(&"forward", _page + 1, _total <= 0 or _page < _total))


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
	var out: Array[int] = []
	if _total <= window:
		for i in range(1, _total + 1): out.append(i)
		return out
	var half := window / 2
	var first := clampi(_page - half, 1, maxi(1, _total - window + 1))
	var last := mini(_total, first + window - 1)
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
