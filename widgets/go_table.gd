## 📊 **고를 수 있고 정렬되는 표** — 랭킹, 길드원, 업적, 거래 기록.
##
## ```gdscript
## var board := GoTable.make(
##     [{"text": "순위", "width": 56}, {"text": "이름"}, {"text": "점수", "numeric": true}],
##     rows)                                   # rows = [[1, "가나다", 91240], …]
## board.row_selected.connect(func(index: int) -> void: show_profile(rows[index]))
## board.sort_by(2, false)                     # 점수 내림차순
## ```
##
## ## 🔑 `GoStyle.table()` 과 무엇이 다른가
## 저것은 **읽기만 하는 표**다(격자에 글자를 늘어놓는다). 이것은 **머리를 눌러 정렬**하고
## **줄을 골라** 다음 화면으로 갈 수 있다. 랭킹처럼 "누르면 프로필" 인 자리는 이쪽이다.
##
## ## 🛑 숫자 칸은 오른쪽 정렬이고 숫자로 정렬한다
## `"91240"` 과 `"9124"` 를 글자로 견주면 `"9124"` 가 더 크다. 자릿수가 다른 점수·골드·피해량이
## 섞이는 순간 순위가 통째로 뒤집힌다 — `numeric: true` 를 주면 수로 견준다.
##
## ## 🛑 모바일에서는 칸을 네 개 넘기지 않는다
## 폰 가로 폭에 다섯 칸을 넣으면 글자가 잘리거나 표가 옆으로 스크롤된다. 정말 필요하면 줄을
## 눌러 `GoSheet` 로 상세를 띄우는 편이 낫다 — 표를 옆으로 미는 UI 는 손가락으로 쓰기 어렵다.
@tool
class_name GoTable
extends VBoxContainer

## 줄을 골랐다. `index` 는 **지금 보이는 차례**가 아니라 원래 데이터의 번호다.
signal row_selected(index: int)

## 정렬이 바뀌었다.
signal sorted(column: int, ascending: bool)

## 머리 줄(정렬 버튼).
var head: HBoxContainer
## 줄들이 쌓이는 칸.
var rows_box: VBoxContainer

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
	add_child(head)
	add_child(GoStyle.divider())
	rows_box = GoStyle.column(0)
	rows_box.name = "Rows"
	add_child(rows_box)


func _ready() -> void:
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 표 하나를 만든다.
##
## `columns` 의 각 칸:
## | 칸 | 뜻 | 기본 |
## |---|---|---|
## | `text` | 머리 글자 | `""` |
## | `width` | 고정 폭(dp). 없으면 남는 폭을 나눠 가진다 | 없음 |
## | `numeric` | 수로 정렬하고 **오른쪽 정렬** | `false` |
## | `sortable` | 머리를 눌러 정렬할 수 있다 | `true` |
## | `translate` | 머리 글자를 번역 키로 | `false` |
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


## 줄 데이터. 각 줄은 칸 개수만큼의 값(글자·수·`Control`)이다.
func set_rows(rows: Array) -> void:
	_rows = rows.duplicate()
	_order.clear()
	for index in _rows.size(): _order.append(index)
	_selected = -1
	if _sort_column >= 0: _apply_sort()
	else: _build_rows()


func rows() -> Array:
	return _rows


## 지금 고른 줄의 **원래 번호**(-1 이면 없음).
func selected() -> int:
	return _selected


## 이 칸으로 정렬한다. 같은 칸을 다시 주면 방향이 뒤집힌다.
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
		if left == right: return a < b   # 🔑 값이 같으면 원래 차례를 지킨다 — 순위가 프레임마다 흔들리지 않게
		return left < right if ascending else left > right)
	_build_rows()


## 정렬에 쓰는 값. 🛑 수 칸은 **반드시 수로** — 글자로 견주면 "9124" > "91240" 이 된다.
static func _cell_key(rows: Array, row: int, column: int, numeric: bool) -> Variant:
	if row < 0 or row >= rows.size(): return 0 if numeric else ""
	var cells: Array = rows[row]
	if column < 0 or column >= cells.size(): return 0 if numeric else ""
	var value: Variant = cells[column]
	if value is Control:
		# 노드가 들어 있으면 그 안의 글자로 견준다 — 아이콘만 있는 칸은 정렬 대상이 아니다.
		value = (value as Control).get(&"text") if &"text" in value else ""
	if numeric: return float(str(value).replace(",", "").strip_edges())
	return str(value).to_lower()


func _build_head() -> void:
	for child in head.get_children(): child.queue_free()
	for index in _columns.size():
		var col := _columns[index]
		var words := str(col["text"])
		var mark := ""
		# 🔑 지금 어느 칸으로, 어느 방향으로 정렬돼 있는지 **글자로** 보인다 — 색이나 굵기만으로
		#    구별하면 색각 이상인 사람에게는 아무 표시가 없는 것과 같다.
		if index == _sort_column: mark = " ▲" if _ascending else " ▼"
		var node: Control
		if bool(col["sortable"]):
			var button := GoStyle.button(words + mark, sort_by.bind(index, index != _sort_column or not _ascending),
				GoStyle.Tone.BARE)
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if bool(col["translate"]) \
				else Node.AUTO_TRANSLATE_MODE_DISABLED
			button.alignment = HORIZONTAL_ALIGNMENT_RIGHT if bool(col["numeric"]) else HORIZONTAL_ALIGNMENT_LEFT
			node = button
		else:
			var text := GoStyle.label(words, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if bool(col["numeric"]) else HORIZONTAL_ALIGNMENT_LEFT
			text.autowrap_mode = TextServer.AUTOWRAP_OFF
			text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			node = text
		_size_cell(node, col)
		head.add_child(node)


func _build_rows() -> void:
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
		if value is Control:
			node = value
		else:
			var text := GoStyle.label(str(value))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if bool(col["numeric"]) else HORIZONTAL_ALIGNMENT_LEFT
			# 🛑 숫자는 언어를 따라 좌우가 뒤집히지 않는다.
			if bool(col["numeric"]): text.text_direction = Control.TEXT_DIRECTION_LTR
			# 🛑 **표의 칸은 줄바꿈하지 않는다.** 줄마다 높이가 달라지면 격자가 어긋나고, 무엇보다
			#    이 줄은 `Button`(컨테이너가 아니다) 안에 앵커로 들어가서 **첫 배치 때 폭이 0** 이다.
			#    그때 줄바꿈 라벨의 최소 높이가 1dp 로 잡혀 그대로 굳었고, 화면에는 판만 남고 글자가
			#    통째로 사라졌다(2026-09-16 가상 모니터 촬영에서 발견 — 헤드리스 검사 120개는 전부 통과했다).
			text.autowrap_mode = TextServer.AUTOWRAP_OFF
			text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			text.size_flags_vertical = Control.SIZE_FILL
			text.clip_text = true
			text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			node = text
		_size_cell(node, col)
		line.add_child(node)

	if not _selectable: return line
	# 🔑 줄 전체가 버튼이다 — 손가락으로 칸 하나를 정확히 짚게 하지 않는다.
	var button := Button.new()
	button.name = "Pick%d" % source
	button.theme = GoUi.theme()
	button.theme_type_variation = GoTheme.VAR_LIST_BUTTON
	button.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	button.toggle_mode = true
	button.button_pressed = source == _selected
	# 얼룩 줄 — 칸이 많은 표에서 눈이 줄을 놓치지 않게.
	if position % 2 == 1: button.modulate = Color(1, 1, 1, 0.97)
	button.pressed.connect(func() -> void:
		_selected = source
		GoFeedback.tapped()
		row_selected.emit(source)
		for other in rows_box.get_children():
			var node := other as Button
			if node != null: node.button_pressed = node == button)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in line.get_children(): (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ♿ 스크린리더는 줄 하나를 한 덩어리로 읽는다 — 칸 값을 이어 붙여 준다.
	var spoken: Array[String] = []
	for value in cells: spoken.append(str(value) if not (value is Control) else "")
	button.accessibility_name = GoUi.spoken(spoken)
	return button


## 고정 폭이 있으면 그만큼, 없으면 남는 폭을 나눠 가진다.
func _size_cell(node: Control, col: Dictionary) -> void:
	var fixed := float(col["width"])
	if fixed > 0.0:
		node.custom_minimum_size.x = fixed
		node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_build_head()
	_build_rows()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _build_head()
