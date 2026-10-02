## ▦ **A grid layout with columns of exactly equal width** — a fixed column count, or as many columns as fit a minimum
## cell width. It draws nothing and takes no input.
##
## ```gdscript
## var grid := GoGrid.make(3)             # three columns, always
## var cards := GoGrid.make(1, 160.0)     # as many 160dp-or-wider columns as fit, recounted on every resize
## for item in items: cards.add_child(GoStyle.item_card(item))
## ```
##
## ## 🔑 Equal columns whatever the children ask
## `GridContainer` hands spare width only to children flagged `SIZE_EXPAND` — leave a card at the default `SIZE_FILL`
## and it folds to its content's minimum, 25px for a wrapping label (`GoStyle.responsive_grid`). This grid gives every
## column `(width - gaps) / columns` itself, whatever flags the children carry, rounding so no two columns differ by
## more than 1px. A short last row keeps the same column width.
##
## ## 🔑 It can always shrink back
## A responsive grid asks for one column's width only, so it narrows with its parent again after a wide window. Each
## row is as tall as its tallest cell. **The cell rectangles are equal; only inside its cell** is a child fitted by its
## own size flags — `SIZE_FILL` fills it, a `SHRINK` child stays small at its start, and the column keeps its width.
## A child wider than `min_cell_width` widens the cells, so fewer columns fit — a 250dp card is never squeezed into a
## 187dp column. With every child at or under `min_cell_width` the count matches `GoStyle.responsive_grid()`.
##
## 🛑 `GoSlotGrid` is the inventory of `GoSlot`s, and `GoStyle.responsive_grid()` stays for code that wants a
##    `GridContainer`. This is the plain layout for any controls.
@tool
class_name GoGrid
extends Container

## The column count when `min_cell_width` is 0.
@export_range(1, 64) var columns := 2:
	set(value):
		columns = maxi(1, value)
		_on_ui_changed()
## Above 0, the column count is recounted from the width — `floor((width + gap) / (cell + gap))` with `cell` the larger
## of this and the widest child, the count `GoStyle.responsive_grid()` makes — and `columns` is not used.
@export var min_cell_width := 0.0:
	set(value):
		min_cell_width = maxf(0.0, value)
		_on_ui_changed()
## Gap between columns (dp). Negative → the `gap` token.
@export var spacing := -1:
	set(value):
		spacing = value
		_on_ui_changed()
## Gap between rows (dp). Negative → the same as `spacing`.
@export var row_spacing := -1:
	set(value):
		row_spacing = value
		_on_ui_changed()

var _columns_drawn := 0


func _init() -> void:
	name = "Grid"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## 🔑 Watched on every entry — a watch set only in `_ready` was dropped for good by the first move (`reparent`).
func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN: _sort()
		NOTIFICATION_LAYOUT_DIRECTION_CHANGED: queue_sort()


## A grid of [param count] equal columns — or, with [param min_cell] above 0, as many columns at least that wide as
## the width allows. [param gap] negative → the `gap` token. Add the cells with `add_child()`.
static func make(count := 2, min_cell := -1.0, gap := -1) -> GoGrid:
	var grid := GoGrid.new()
	grid.columns = count
	grid.min_cell_width = maxf(0.0, min_cell)
	grid.spacing = gap
	return grid


## The column count in force at the current width.
func columns_in_use() -> int:
	if min_cell_width <= 0.0: return columns
	var gap := _gap()
	return maxi(1, int(floor((size.x + gap) / maxf(1.0, _cell_width(_cells()) + gap))))


## The narrowest a responsive cell may be — `min_cell_width`, or the widest child if that is wider.
func _cell_width(cells: Array[Control]) -> float:
	var widest := min_cell_width
	for cell in cells: widest = maxf(widest, cell.get_combined_minimum_size().x)
	return widest


## Tokens or a setting changed — re-measure and re-place; the cells are never rebuilt.
func _on_ui_changed() -> void:
	update_minimum_size()
	queue_sort()


func _gap() -> float:
	return float(GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)


func _row_gap() -> float:
	return _gap() if row_spacing < 0 else float(row_spacing)


func _cells() -> Array[Control]:
	var found: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible or control.top_level: continue
		found.append(control)
	return found


## Each row's height at [param count] columns.
func _row_heights(cells: Array[Control], count: int) -> Array[float]:
	var heights: Array[float] = []
	for index in cells.size():
		var row := index / count
		if row >= heights.size(): heights.append(0.0)
		heights[row] = maxf(heights[row], cells[index].get_combined_minimum_size().y)
	return heights


func _get_minimum_size() -> Vector2:
	var cells := _cells()
	if cells.is_empty(): return Vector2.ZERO
	var widest := 0.0
	for cell in cells: widest = maxf(widest, cell.get_combined_minimum_size().x)
	var gap := _gap()
	# 🛑 A responsive grid asks for one column only — asking for the columns it draws now would hold it wide after a
	#    wide window, the trap `GoDatePicker` documents.
	var wide := _cell_width(cells) if min_cell_width > 0.0 else widest * columns + gap * (columns - 1)
	var count := columns_in_use()
	var tall := 0.0
	var heights := _row_heights(cells, count)
	for height in heights: tall += height
	tall += _row_gap() * float(maxi(0, heights.size() - 1))
	return Vector2(wide, tall)


func _sort() -> void:
	var cells := _cells()
	var count := columns_in_use()
	if count != _columns_drawn:
		# The row count, and with it the height asked for, follows the column count.
		_columns_drawn = count
		update_minimum_size()
	if cells.is_empty(): return
	var gap := _gap()
	var heights := _row_heights(cells, count)
	var rtl := is_layout_rtl()
	var pitch := (size.x + gap) / float(count)
	var y := 0.0
	for index in cells.size():
		var column := index % count
		var row := index / count
		if column == 0 and row > 0: y += heights[row - 1] + _row_gap()
		# 🔑 Edges are rounded, not widths — columns differ by 1px at most and the gaps stay exact.
		var left := roundf(pitch * column)
		var right := roundf(pitch * (column + 1) - gap)
		if rtl:
			var mirrored := size.x - right
			right = size.x - left
			left = mirrored
		fit_child_in_rect(cells[index], Rect2(left, roundf(y), maxf(0.0, right - left), heights[row]))
