## 📋 **A leaderboard table** — a white card holding a blue head bar (RANK | PLAYER | the value's name, with thin
## rules between the columns) over glossy rows: the first place gold, the second and third with a small ribbon medal
## left of their rank, and the player's own row light cyan in a cyan rim.
##
## ```gdscript
## var table := GoScoreTable.new()
## table.set_columns("RANK", "PLAYER", "CLEAR TIME")
## table.add_row(1, "MagnetQueen", "00:31.20")
## table.add_row(2, "Bolt", "00:33.90")
## table.add_row(4, "YOU", "00:39.30", true)          # the player's own row
## table.scroll.get_v_scroll_bar().value_changed.connect(_maybe_load_next_page)
## table.clear_rows()                                 # a new board: empty it, then add its rows
## ```
##
## 🔑 **The table owns its scroll**: `rows` (a `VBoxContainer`) sits in `scroll` (a `GoScroll`, vertical only) under
##    the head bar, which stays put. Give the table a height (a container's share or `custom_minimum_size`); rows past
##    it scroll. Add rows with `add_row` — anything else put in `rows` is drawn but not sized by the table.
## The looks are the theme's: `GoScoreTable` (the card), `GoScoreTableHead` (the bar; its `separator_color` the column
## rules), `GoScoreTableHeadLabel`, `GoScoreTableRow` / `GoScoreTableRowGold` / `GoScoreTableRowOwn` and
## `GoScoreTableLabel`. A look without them falls back to plain panels and labels. The medals are the skin's
## `medal_row_1` … `medal_row_3` (`widget_art`); a look without them shows the rank alone.
## 🛑 Display only — every rank, name and value is the caller's (the server's), shown as given.
## 🔑 Texts shrink to fit their column (`GoStyle.fit_font_size`, down to `GoConfig.fit_min_scale`); a name still too
##    long ends in an ellipsis.
@tool
class_name GoScoreTable
extends PanelContainer

const VAR_TABLE := &"GoScoreTable"
const VAR_HEAD := &"GoScoreTableHead"
const VAR_HEAD_LABEL := &"GoScoreTableHeadLabel"
const VAR_ROW := &"GoScoreTableRow"
const VAR_ROW_GOLD := &"GoScoreTableRowGold"
const VAR_ROW_OWN := &"GoScoreTableRowOwn"
const VAR_LABEL := &"GoScoreTableLabel"
## The columns' shares of the width: rank, player, value — the head's titles and every row use the same, so a title
## stands over its column's texts (the name centred on the row).
const COLUMN_SHARES: Array[float] = [0.26, 0.49, 0.25]
## Where the head bar's two column rules stand, as shares of its width.
const RULE_SHARES: Array[float] = [0.2, 0.77]
## The rank column: room before the medal, then the medal, then the gap to the "#n" (dp, at the base sizes).
const MEDAL_LEAD := 22.0
const MEDAL_GAP := 28.0
## The column rules' width (dp) and how far they stop short of the bar's top and bottom.
const RULE_WIDTH := 2.0
const RULE_INSET := 0.0

## A row's height (dp).
@export_range(16.0, 200.0, 1.0) var row_height := 44.0:
	set(value):
		row_height = value
		_restyle_rows()

## The head bar's height (dp).
@export_range(16.0, 200.0, 1.0) var head_height := 37.0:
	set(value):
		head_height = value
		if is_instance_valid(header): header.custom_minimum_size.y = head_height

## The space between two rows (dp).
@export_range(0, 64) var row_gap := 4:
	set(value):
		row_gap = value
		if is_instance_valid(rows): rows.add_theme_constant_override(&"separation", row_gap)

## The rows' font size. 0: the theme's (`GoScoreTableLabel`).
@export_range(0, 128) var font_size := 0:
	set(value):
		font_size = value
		_restyle_rows()

## The head bar's font size. 0: the theme's (`GoScoreTableHeadLabel`).
@export_range(0, 128) var head_font_size := 0:
	set(value):
		head_font_size = value
		_queue_fit()

## The medal's width in a row (dp); its height is the row's.
@export_range(0.0, 200.0, 1.0) var medal_size := 40.0:
	set(value):
		medal_size = value
		_restyle_rows()

## The blue head bar.
var header: PanelContainer
## The rows, top to bottom — inside [member scroll].
var rows: VBoxContainer
## The scroll the rows sit in (vertical only).
var scroll: GoScroll

var _head_labels: Array[Label] = []
var _head_cells: HBoxContainer
var _body: VBoxContainer
var _fit_queued := false


func _init() -> void:
	name = "ScoreTable"
	theme_type_variation = VAR_TABLE
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override(&"separation", 4)
	add_child(_body)
	header = PanelContainer.new()
	header.name = "Header"
	header.theme_type_variation = VAR_HEAD
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.custom_minimum_size.y = head_height
	header.draw.connect(_draw_rules)
	_body.add_child(header)
	_head_cells = HBoxContainer.new()
	_head_cells.name = "Cells"
	_head_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head_cells.add_theme_constant_override(&"separation", 0)
	header.add_child(_head_cells)
	for column in 3:
		var label := _label("Column%d" % column, VAR_HEAD_LABEL)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = COLUMN_SHARES[column]
		_head_cells.add_child(label)
		_head_labels.append(label)
	scroll = GoScroll.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", row_gap)
	scroll.add_child(rows)
	set_columns("RANK", "PLAYER", "SCORE")
	resized.connect(_queue_fit)


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _ready() -> void:
	theme = GoUi.theme()
	_queue_fit()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_restyle_rows()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_TRANSLATION_CHANGED: _queue_fit()


## The head bar's three titles: the rank column, the player column and the value column ("CLEAR TIME", "WINS").
func set_columns(rank: String, player: String, value: String) -> void:
	_head_labels[0].text = rank
	_head_labels[1].text = player
	_head_labels[2].text = value
	_queue_fit()


## The head bar's title of column [param index] (0 rank, 1 player, 2 value).
func column_title(index: int) -> String:
	return _head_labels[index].text


## Adds a row at the bottom and returns it (a `PanelContainer`): [param rank] shows as "#n" — 1 on the gold row,
## 1 to 3 with the skin's ribbon medal — then [param player_name] and [param value]. [param own]: the player's own row
## (cyan; it wins over the gold of a first place, so the player always finds themself).
func add_row(rank: int, player_name: String, value: String, own := false) -> Control:
	var row := PanelContainer.new()
	row.name = "Row%d" % (rows.get_child_count() + 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"rank", rank)
	row.set_meta(&"own", own)
	row.theme_type_variation = row_variation(rank, own)
	var cells := HBoxContainer.new()
	cells.name = "Cells"
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.add_theme_constant_override(&"separation", 0)
	row.add_child(cells)
	var rank_cell := HBoxContainer.new()
	rank_cell.name = "RankCell"
	rank_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_cell.size_flags_stretch_ratio = COLUMN_SHARES[0]
	rank_cell.add_theme_constant_override(&"separation", 0)
	cells.add_child(rank_cell)
	var lead := Control.new()
	lead.name = "Lead"
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_cell.add_child(lead)
	var medal := TextureRect.new()
	medal.name = "Medal"
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal.texture = medal_art(rank)
	rank_cell.add_child(medal)
	var gap := Control.new()
	gap.name = "Gap"
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_cell.add_child(gap)
	var rank_label := _label("Rank", VAR_LABEL)
	rank_label.text = str("#", rank)
	rank_label.text_direction = Control.TEXT_DIRECTION_LTR
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_cell.add_child(rank_label)
	var name_label := _label("Name", VAR_LABEL)
	name_label.text = player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_stretch_ratio = COLUMN_SHARES[1]
	cells.add_child(name_label)
	var value_label := _label("Value", VAR_LABEL)
	value_label.text = value
	value_label.text_direction = Control.TEXT_DIRECTION_LTR
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_stretch_ratio = COLUMN_SHARES[2]
	cells.add_child(value_label)
	rows.add_child(row)
	_style_row(row)
	_queue_fit()
	return row


## Removes every row (they are freed).
func clear_rows() -> void:
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()


## How many rows the table holds.
func row_count() -> int:
	return rows.get_child_count()


## The theme variation a row with [param rank] takes: the player's own, the gold first place or a plain row.
static func row_variation(rank: int, own: bool) -> StringName:
	if own: return VAR_ROW_OWN
	return VAR_ROW_GOLD if rank == 1 else VAR_ROW


## The skin's ribbon medal for [param rank] (1 to 3), or null — a rank past three, or a look without the art.
static func medal_art(rank: int) -> Texture2D:
	if rank < 1 or rank > 3: return null
	var skin := GoUi.skin()
	return skin.widget_art(StringName("medal_row_%d" % rank)) if skin != null else null


## The row's labels: [rank, name, value].
static func row_labels(row: Control) -> Array[Label]:
	var cells := row.get_node(^"Cells")
	return [cells.get_node(^"RankCell/Rank") as Label, cells.get_node(^"Name") as Label,
			cells.get_node(^"Value") as Label]


func _label(node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.custom_minimum_size.x = 1.0
	return label


func _style_row(row: Control) -> void:
	row.custom_minimum_size.y = row_height
	var rank := int(row.get_meta(&"rank", 0))
	var medal := row.get_node(^"Cells/RankCell/Medal") as TextureRect
	medal.texture = medal_art(rank)
	medal.custom_minimum_size = Vector2(medal_size, 0.0)
	(row.get_node(^"Cells/RankCell/Lead") as Control).custom_minimum_size.x = MEDAL_LEAD
	(row.get_node(^"Cells/RankCell/Gap") as Control).custom_minimum_size.x = MEDAL_GAP


func _restyle_rows() -> void:
	if not is_instance_valid(rows): return
	for row in rows.get_children():
		if row is Control and row.has_meta(&"rank"): _style_row(row)
	_queue_fit()


func _queue_fit() -> void:
	if _fit_queued or not is_instance_valid(rows): return
	_fit_queued = true
	_fit.call_deferred()


## Shrinks every text to its column's room — measured from the table's width, so it holds before the first layout.
func _fit() -> void:
	_fit_queued = false
	if not is_instance_valid(rows): return
	var inner := size.x - _side_padding(self) - _side_padding(header)
	var row_inner := size.x - _side_padding(self)
	if inner <= 0.0: return
	for column in 3:
		var label := _head_labels[column]
		label.remove_theme_font_size_override(&"font_size")
		var base := head_font_size if head_font_size > 0 else label.get_theme_font_size(&"font_size")
		label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(PackedStringArray([label.text]), base,
				inner * COLUMN_SHARES[column] - 8.0, label.get_theme_font(&"font")))
	for row in rows.get_children():
		if not (row is PanelContainer and row.has_meta(&"rank")): continue
		var cells := row_inner - _side_padding(row as Control)
		var labels := row_labels(row)
		var rooms: Array[float] = [cells * COLUMN_SHARES[0] - MEDAL_LEAD - medal_size - MEDAL_GAP,
				cells * COLUMN_SHARES[1] - 8.0, cells * COLUMN_SHARES[2] - 8.0]
		for column in 3:
			var label := labels[column]
			label.remove_theme_font_size_override(&"font_size")
			var base := font_size if font_size > 0 else label.get_theme_font_size(&"font_size")
			label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(PackedStringArray([label.text]),
					base, maxf(1.0, rooms[column]), label.get_theme_font(&"font")))
	header.queue_redraw()


static func _side_padding(node: Control) -> float:
	var box := node.get_theme_stylebox(&"panel")
	return box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box != null else 0.0


## The thin rules between the head bar's columns.
func _draw_rules() -> void:
	var box := header.get_theme_stylebox(&"panel")
	var left := box.get_margin(SIDE_LEFT) if box != null else 0.0
	var wide := header.size.x - _side_padding(header)
	var ink := header.get_theme_color(&"separator_color", VAR_HEAD) if header.has_theme_color(&"separator_color", VAR_HEAD) \
			else Color(GoUi.color(GoTheme.ON_ACCENT), 0.4)
	for share in RULE_SHARES:
		var x := left + wide * share
		header.draw_line(Vector2(x, RULE_INSET), Vector2(x, header.size.y - RULE_INSET), ink, RULE_WIDTH)
