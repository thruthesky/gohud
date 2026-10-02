## 📜 **A long list that only builds the rows on screen** — a feed, a chat history, a catalogue of thousands of items.
## Flutter's `ListView.builder` with an `itemExtent`: you give the count, the height of one row and a function that
## builds row `i`; the list makes only the rows in view (plus a few either side) and frees the rest as you scroll.
##
## ```gdscript
## var feed := GoListView.make(posts.size(), 88.0, func(index: int) -> Control:
## 	return GoStyle.list_row(Button.new(), GoIconSet.USER, posts[index].title))
## page.add_child(feed)                      # it scrolls itself — give it the room (SIZE_EXPAND_FILL)
## feed.end_reached.connect(load_next_page)  # near the bottom: fetch more, then feed.set_count(posts.size())
## ```
##
## ## 🔑 Rows of one height
## Every row is `item_extent` dp tall — that is what lets the list place row 5,000 without building the 4,999 before
## it. Rows of different heights belong in a `GoScroll` with a column, or a list of a few hundred.
##
## ## 🔑 Recycling, when building is costly
## `GoListView.recycle(count, extent, create, bind)` keeps the rows it built and hands them back to `bind(row, index)`
## with a new index instead of freeing them — no node is created while the list scrolls.
##
## ## 🛑 It is the scroll
## It is a `GoScroll` (touch scrolling, the vertical-swipe rules, the scrollbar in the panel edge), so it is not put
## inside another vertical scroll. A header goes above it, outside.
@tool
class_name GoListView
extends GoScroll

## The list came within `end_threshold` rows of its last row — time to load more (fires once per count).
signal end_reached
## A row came into view and was built (`index`), for analytics or prefetching.
signal row_shown(index: int)

## How many rows the list holds.
@export var count := 0:
	set(value):
		count = maxi(0, value)
		_end_fired = false
		_resize_strip()
		_fill.call_deferred()

## Height of one row (dp), and the space between rows (dp).
@export var item_extent := 56.0:
	set(value):
		item_extent = maxf(1.0, value)
		_resize_strip()
		_rebuild_all()
@export var spacing := 0.0:
	set(value):
		spacing = maxf(0.0, value)
		_resize_strip()
		_rebuild_all()

## Rows built beyond each edge of the view, so a fast swipe does not show blank space.
@export var overscan := 3
## `end_reached` fires when the last row built is within this many rows of the end.
@export var end_threshold := 5

var _build := Callable()
var _create := Callable()
var _bind := Callable()
var _strip: Control
## Index → the row on screen.
var _live := {}
## Rows set aside for reuse (recycling mode).
var _spare: Array[Control] = []
var _end_fired := false


func _init() -> void:
	super()
	name = "ListView"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_strip = Control.new()
	_strip.name = "Rows"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_strip)
	get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _fill())
	resized.connect(_fill)


## A list of [param rows] rows, each [param extent] dp tall; [param build] makes row `i` (`func(index) -> Control`).
static func make(rows: int, extent: float, build: Callable) -> GoListView:
	var node := GoListView.new()
	node._build = build
	node.item_extent = extent
	node.count = rows
	return node


## The recycling list: [param create] makes an empty row (`func() -> Control`), [param bind] fills it for an index
## (`func(row: Control, index: int)`). Rows that leave the view are kept and bound again for the next index.
static func recycle(rows: int, extent: float, create: Callable, bind: Callable) -> GoListView:
	var node := GoListView.new()
	node._create = create
	node._bind = bind
	node.item_extent = extent
	node.count = rows
	return node


## Changes the row count (after more rows arrived) and keeps the view where it is.
func set_count(rows: int) -> void:
	count = rows


## Builds every row in view again — after the data behind them changed.
func refresh() -> void:
	_rebuild_all()


## Scrolls so row [param index] is at the top of the view.
func scroll_to_index(index: int) -> void:
	scroll_vertical = int(clampi(index, 0, maxi(0, count - 1)) * _pitch())


## The row on screen for [param index], or `null` when it is not built.
func row(index: int) -> Control:
	return _live.get(index)


## The indexes built right now, in order.
func built_indexes() -> Array[int]:
	var out: Array[int] = []
	for key: int in _live: out.append(key)
	out.sort()
	return out


func _pitch() -> float:
	return item_extent + spacing


func _resize_strip() -> void:
	if _strip == null: return
	_strip.custom_minimum_size.y = maxf(0.0, count * _pitch() - spacing)


func _rebuild_all() -> void:
	for index: int in _live.keys(): _release(index)
	_fill.call_deferred()


## Builds the rows that are (or are about to be) in view and lets go of the rest.
func _fill() -> void:
	if not is_inside_tree() or _strip == null: return
	var top := float(scroll_vertical)
	var view := size.y
	var first := maxi(0, floori(top / _pitch()) - overscan)
	var last := mini(count - 1, ceili((top + view) / _pitch()) + overscan)
	for index: int in _live.keys():
		if index < first or index > last: _release(index)
	for index in range(first, last + 1):
		if not _live.has(index): _place(index)
	if count > 0 and last >= count - 1 - end_threshold and not _end_fired:
		_end_fired = true
		end_reached.emit()


func _place(index: int) -> void:
	var node: Control = null
	if _bind.is_valid():
		node = _spare.pop_back() if not _spare.is_empty() else (_create.call() as Control)
		if node == null: return
		if node.get_parent() == null: _strip.add_child(node)
		node.visible = true
		_bind.call(node, index)
	elif _build.is_valid():
		node = _build.call(index) as Control
		if node == null: return
		_strip.add_child(node)
	else:
		return
	node.position = Vector2(0.0, index * _pitch())
	node.size = Vector2(_strip.size.x, item_extent)
	node.custom_minimum_size.y = item_extent
	_live[index] = node
	row_shown.emit(index)


func _release(index: int) -> void:
	var node: Control = _live.get(index)
	_live.erase(index)
	if not is_instance_valid(node): return
	if _bind.is_valid():
		node.visible = false
		_spare.append(node)
	else:
		_strip.remove_child(node)
		node.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and _strip != null:
		# Rows are placed by hand inside the strip — keep their width with the strip's.
		for node: Control in _live.values():
			if is_instance_valid(node): node.size.x = _strip.size.x
