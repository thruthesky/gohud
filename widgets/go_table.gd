## 📊 **A selectable, sortable table** — rankings, guild members, achievements, trade logs.
##
## ```gdscript
## var board := GoTable.make(
##     [{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}],
##     rows)                                   # rows = [[1, "Alice", 91240], …]
## board.row_selected.connect(func(index: int) -> void: show_profile(rows[index]))
## board.sort_by(2, false)                     # score, descending
## ```
##
## ## 🔑 How it differs from `GoStyle.table()`
## That one is **a read-only table** (it lays text out in a grid). This one **sorts when a header is pressed** and lets
## you **pick a row** to move on to the next screen. Wherever "press it for the profile" applies, such as a ranking, this is the one.
##
## ## 🛑 Numeric columns are right-aligned and sorted as numbers
## Compared as text, `"9124"` is greater than `"91240"`. The moment scores, gold or damage of differing digit counts are
## mixed in, the whole ranking turns upside down — give it `numeric: true` and they are compared as numbers.
##
## ## 🛑 On mobile, never more than four columns
## Five columns across a phone width either clip the text or make the table scroll sideways. If they really are needed,
## pressing a row to raise the details in a `GoSheet` is better — a table you push sideways is hard to use with a finger.
@tool
class_name GoTable
extends VBoxContainer

## A row was picked. `index` is the index in the original data, not **the position it is shown at**.
signal row_selected(index: int)

## The sort changed.
signal sorted(column: int, ascending: bool)

## The header row (the sort buttons).
var head: HBoxContainer
## The container the rows stack in.
var rows_box: VBoxContainer
## 🔑 The header sits behind the same side padding as the rows' content, so every column lines up with its header.
var _head_inset: MarginContainer

var _columns: Array[Dictionary] = []
var _rows: Array = []
var _order: Array[int] = []
var _sort_column := -1
var _ascending := true
var _selected := -1
var _selectable := true


func _init() -> void:
	name = "Table"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	head = GoStyle.row(GoUi.metric(GoTheme.GAP))
	head.name = "Head"
	_head_inset = GoStyle.padding(_side_padding(), 0)
	_head_inset.name = "HeadInset"
	_head_inset.add_child(head)
	add_child(_head_inset)
	add_child(GoStyle.divider())
	rows_box = GoStyle.column(0)
	rows_box.name = "Rows"
	add_child(rows_box)


func _ready() -> void:
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Builds one table.
##
## Each entry of `columns`:
## | Key | Meaning | Default |
## |---|---|---|
## | `text` | The header label | `""` |
## | `width` | Fixed width (dp). Without it, the leftover width is shared out | none |
## | `numeric` | Sorted as a number and **right-aligned** | `false` |
## | `sortable` | The header can be pressed to sort | `true` |
## | `translate` | Takes the header label as a translation key | `false` |
static func make(columns: Array, rows: Array, selectable := true) -> GoTable:
	var table := GoTable.new()
	table._selectable = selectable
	table.set_columns(columns)
	table.set_rows(rows)
	return table


func set_columns(columns: Array) -> void:
	_columns.clear()
	for entry in columns:
		var col: Dictionary = entry if entry is Dictionary else {"text": str(entry)}
		_columns.append({
			"text": str(col.get("text", "")),
			"width": float(col.get("width", 0.0)),
			"numeric": bool(col.get("numeric", false)),
			"sortable": bool(col.get("sortable", true)),
			"translate": bool(col.get("translate", false)),
		})
	_build_head()


## The row data. Each row holds as many values as there are columns (text, numbers or a `Control`).
## 🔑 Hand over a `Control` and **ownership stays with the caller** — on a sort or a theme swap the table only moves it,
##    it never frees the node. To throw it away together with the table, call `queue_free()` yourself.
func set_rows(rows: Array) -> void:
	_detach_borrowed()
	_rows = rows.duplicate()
	_order.clear()
	for index in _rows.size(): _order.append(index)
	_selected = -1
	if _sort_column >= 0: _apply_sort()
	else: _build_rows()


func rows() -> Array:
	return _rows


## The **original index** of the row currently picked (-1 for none).
func selected() -> int:
	return _selected


## Sorts by this column. Give the same column again and the direction flips.
func sort_by(column: int, ascending := true) -> void:
	if column < 0 or column >= _columns.size(): return
	if not bool(_columns[column]["sortable"]): return
	_sort_column = column
	_ascending = ascending
	_apply_sort()
	_build_head()
	sorted.emit(column, ascending)


func _apply_sort() -> void:
	var column := _sort_column
	var numeric: bool = _columns[column]["numeric"] if column < _columns.size() else false
	var rows := _rows
	var ascending := _ascending
	_order.sort_custom(func(a: int, b: int) -> bool:
		var left := GoTable._cell_key(rows, a, column, numeric)
		var right := GoTable._cell_key(rows, b, column, numeric)
		if left == right: return a < b   # 🔑 equal values keep the original order — so the ranking does not wobble frame to frame
		return left < right if ascending else left > right)
	_build_rows()


## The value used for sorting. 🛑 A numeric column **must go as a number** — compared as text, "9124" > "91240".
static func _cell_key(rows: Array, row: int, column: int, numeric: bool) -> Variant:
	if row < 0 or row >= rows.size(): return 0 if numeric else ""
	var cells: Array = rows[row]
	if column < 0 or column >= cells.size(): return 0 if numeric else ""
	var value: Variant = cells[column]
	if value is Control:
		# With a node inside, its text is what is compared — an icon-only cell is not something to sort by.
		value = (value as Control).get(&"text") if &"text" in value else ""
	if numeric: return float(str(value).replace(",", "").strip_edges())
	return str(value).to_lower()


## Detaches the borrowed cells (the `Control`s the host handed over) before anything is freed.
## 🔑 Ownership belongs to **whoever handed them over** — the table only lends them a place.
func _detach_borrowed() -> void:
	for cells in _rows:
		if not (cells is Array): continue
		for value in cells:
			# 🛑 `as Control` on a number or a string **prints an `Invalid cast` error** (it does not come out null).
			#    Table cells are mostly numbers and strings, so `is` filters them out first.
			if not (value is Control): continue
			var node: Control = value
			if not is_instance_valid(node): continue
			var parent := node.get_parent()
			if parent != null: parent.remove_child(node)


func _build_head() -> void:
	for child in head.get_children(): child.queue_free()
	for index in _columns.size():
		var col := _columns[index]
		var words := str(col["text"])
		var mark := ""
		# 🔑 Which column is sorted, and in which direction, is shown **as a character** — told apart by color or weight
		#    alone, it amounts to no indication at all for someone with color vision deficiency.
		if index == _sort_column: mark = " ▲" if _ascending else " ▼"
		var node: Control
		if bool(col["sortable"]):
			# 🛑 **Never concatenate the arrow onto a translation key.** With `translate` on, the engine looks up
			#    `"rank ▲"` whole, fails, and the key shows on screen as it is.
			#    The translation is finished here (`tr`), and the mark is appended **after** it.
			var translate: bool = col["translate"]
			var shown := (tr(words) if translate else words) + mark
			var button := GoStyle.button(shown, sort_by.bind(index, index != _sort_column or not _ascending),
				GoStyle.Tone.BARE)
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			# 🛑 `Tone.BARE` has no minimum height — this is a header row that gets pressed, so it is given one directly.
			button.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
			button.alignment = HORIZONTAL_ALIGNMENT_RIGHT if bool(col["numeric"]) else HORIZONTAL_ALIGNMENT_LEFT
			node = button
		else:
			var text := GoStyle.label(tr(words) if bool(col["translate"]) else words,
				GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if bool(col["numeric"]) else HORIZONTAL_ALIGNMENT_LEFT
			text.autowrap_mode = TextServer.AUTOWRAP_OFF
			text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			node = text
		_size_cell(node, col)
		head.add_child(node)


func _build_rows() -> void:
	# 🛑 **The `Control` cells the host handed over are not killed.** Freeing a whole row takes its descendant cells
	#    with it, and on the next sort `_make_row` tries to attach **an already dead node** — the cell comes up empty
	#    or a dead instance is touched (measured 2026-09-16: `is_instance_valid` false after a single sort).
	#    Detaching them before the free leaves only what we built to disappear.
	_detach_borrowed()
	for child in rows_box.get_children(): child.queue_free()
	for position in _order.size():
		var source: int = _order[position]
		rows_box.add_child(_make_row(source, position))


func _make_row(source: int, position: int) -> Control:
	var cells: Array = _rows[source] if source < _rows.size() else []
	var line := GoStyle.row(GoUi.metric(GoTheme.GAP))
	line.name = "Row%d" % source
	for index in _columns.size():
		var col := _columns[index]
		var value: Variant = cells[index] if index < cells.size() else ""
		var node: Control
		if value is Control and is_instance_valid(value):
			node = value
			# 🛑 **Detached from the old parent right before it is attached.** When the rows are rebuilt this node is still
			#    hanging on the old row, which is in the middle of being freed — `add_child` as is gets refused by Godot with
			#    "already has a parent", the cell comes up empty, and this node dies with the old row when it really is freed.
			var previous := node.get_parent()
			if previous != null: previous.remove_child(node)
		else:
			var text := GoStyle.label(str(value))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if bool(col["numeric"]) else HORIZONTAL_ALIGNMENT_LEFT
			# 🛑 Numbers do not flip left to right with the language.
			if bool(col["numeric"]): text.text_direction = Control.TEXT_DIRECTION_LTR
			# 🛑 **Table cells do not wrap.** Differing heights per row throw the grid off, and above all this row goes into a
			#    `Button` (not a container) by anchors, so **its width is 0 on the first layout**. The minimum height of a
			#    wrapping label was taken as 1dp there and set that way, leaving nothing but the panel on screen with the text
			#    gone entirely (found in a virtual-monitor capture 2026-09-16 — all 120 headless tests had passed).
			text.autowrap_mode = TextServer.AUTOWRAP_OFF
			text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			text.size_flags_vertical = Control.SIZE_FILL
			text.clip_text = true
			text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			node = text
		_size_cell(node, col)
		line.add_child(node)

	if not _selectable:
		# No face to keep off, but the columns still line up with the header and the selectable rows.
		var plain := GoStyle.padding(_side_padding(), 0)
		plain.name = "Row%d" % source
		line.name = "Cells"
		plain.add_child(line)
		return plain
	# 🔑 The whole row is the button — a finger is never asked to hit one cell precisely.
	var button := Button.new()
	button.name = "Pick%d" % source
	button.theme = GoUi.theme()
	button.theme_type_variation = GoTheme.VAR_LIST_BUTTON
	button.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	button.toggle_mode = true
	button.button_pressed = source == _selected
	# Zebra striping — so the eye does not lose the row in a table with many columns.
	# 🔑 Instead of cutting the brightness, **one more panel is laid underneath** — `modulate` would dim the text along with it and cost contrast.
	if position % 2 == 1:
		var stripe := StyleBoxFlat.new()
		stripe.bg_color = Color(GoUi.color(GoTheme.SURFACE_SOFT), 0.5)
		button.add_theme_stylebox_override(&"normal", stripe)
	button.pressed.connect(func() -> void:
		_selected = source
		GoFeedback.tapped()
		row_selected.emit(source)
		for other in rows_box.get_children():
			var node := other as Button
			if node != null: node.button_pressed = node == button)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in line.get_children(): (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 A `Button` does not pad or grow for a child — laid straight over the row, the first and last cells sat on the
	#    face's edges (`1` and `91240` touching the row, 2026-09-23). The row is padded and sized to its cells.
	line.name = "Cells"
	GoStyle.cell_inset(button, line, _side_padding(), GoUi.metric(GoTheme.GAP_TINY))
	# ♿ A screen reader reads the row as one chunk — the cell values are joined for it.
	var spoken: Array[String] = []
	for value in cells: spoken.append(str(value) if not (value is Control) else "")
	button.accessibility_name = GoUi.spoken(spoken)
	return button


## A fixed width if there is one; otherwise the leftover width is shared out.
func _size_cell(node: Control, col: Dictionary) -> void:
	var fixed := float(col["width"])
	if fixed > 0.0:
		node.custom_minimum_size.x = fixed
		node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	GoStyle.insets(_head_inset, _side_padding(), 0)
	_build_head()
	_build_rows()


## Room between a row's edge and its first and last cell (dp) — the header uses the same so columns line up.
static func _side_padding() -> int:
	return GoUi.metric(GoTheme.GAP_SMALL)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _build_head()
