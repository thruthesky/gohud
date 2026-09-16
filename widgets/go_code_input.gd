## 🎟 **Coupon / gift code field** — split into cells, and a paste scatters itself across them.
##
## ```gdscript
## var coupon := GoCodeInput.make(12, 4)          # 12 characters, grouped by 4
## coupon.completed.connect(func(code: String) -> void: server.redeem(code))
## sheet.body.add_child(coupon)
##
## coupon.set_error("That code has already been used")
## ```
##
## ## 🔑 In a game this is not two-factor authentication
## Far more often it is a **coupon, pre-registration or gift code** than a 6-digit OTP. So the default is 12 characters,
## it takes uppercase letters and digits, and lowercase typing is **folded to uppercase** — codes are printed in uppercase.
##
## ## 🛑 Pasting has to work
## Nobody types a code by hand — they **copy it out of KakaoTalk or an email**. Cells that each take a single character
## truncate the paste at the first cell — here the pasted text is scattered across the cells instead.
##
## ## 🛑 Do not build many fields
## Twelve `LineEdit`s mean handling focus movement, deletion and pasting by hand, and characters vanish
## between the cells once a Korean IME is in the loop. Here **one invisible field** takes the text and the
## cells are **drawn** — an IME problem cannot arise at all.
@tool
class_name GoCodeInput
extends VBoxContainer

## The code is full.
signal completed(code: String)

## At least one character changed.
signal changed(code: String)

## How many characters.
@export var length := 12:
	set(value):
		length = maxi(1, value)
		_rebuild()

## Show a break every this many characters. 0 means no breaks.
@export var group := 4:
	set(value):
		group = maxi(0, value)
		_rebuild()

## Characters that are accepted. Anything not listed here is dropped.
@export var allowed := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## Whether lowercase is folded to uppercase.
@export var uppercase := true

## Minimum width of one cell (dp). Negative derives it from the font size.
@export var cell_width := -1.0

## The **invisible** field that actually holds the code.
var edit: LineEdit
## The row the cells are drawn in.
var cells_row: HBoxContainer
## The error line.
var error_label: Label

var _cells: Array[PanelContainer] = []
## Stacks the cell row and the hidden field on top of each other (a `Control`, not a container, so the two share the same spot).
var _stack: Control
var _error := ""


func _init() -> void:
	name = "CodeInput"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))

	# 🛑 The box that **stacks** the cell row and the hidden field. Put the field straight into an `HBoxContainer`
	#    and the container **pushes** it into a column of its own instead of over the cells — then tapping a cell
	#    never takes focus and the virtual keyboard never opens (measured 2026-09-16: edit sat in the last column at x=456).
	# 🛑 A `Control` **does not inherit** its children's minimum size — left alone this box measures 0 and the
	#    cell row and the field shrink away together. Tie its height to the cell row's; width comes from the parent.
	_stack = Control.new()
	_stack.name = "Stack"
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_stack)

	cells_row = GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	cells_row.name = "Cells"
	cells_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# 🛑 A code is a **physical sequence** — it fills from the left even in Arabic.
	cells_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	cells_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(cells_row)
	GoStyle.fit_content_height(_stack, cells_row)

	# 🔑 This single field takes the real input. It is invisible but **still occupies size** — otherwise tab
	#    never reaches it and the virtual keyboard never opens. It covers the cells, so any tap focuses it.
	edit = LineEdit.new()
	edit.name = "Hidden"
	edit.max_length = length
	edit.flat = true
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	edit.add_theme_color_override(&"font_selected_color", Color(0, 0, 0, 0))
	edit.add_theme_color_override(&"caret_color", Color(0, 0, 0, 0))
	edit.text_changed.connect(_on_text)
	# Cover the cell row **on top** — a tap anywhere brings focus here.
	edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(edit)

	error_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.DANGER))
	error_label.name = "Error"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.visible = false
	add_child(error_label)


func _ready() -> void:
	_rebuild()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


static func make(digits := 12, group_size := 4) -> GoCodeInput:
	var node := GoCodeInput.new()
	node.length = digits
	node.group = group_size
	return node


## The code as it stands (empty cells simply absent).
func code() -> String:
	return edit.text


## Fill the code in (for pre-filling a code that arrived through a deep link).
func set_code(value: String) -> void:
	edit.text = _clean(value)
	_paint()


func clear() -> void:
	edit.text = ""
	_paint()


## Is it full.
func is_complete() -> bool:
	return edit.text.length() >= length


## Show an error. An empty string clears it.
## 🛑 **Tint the cells too** — if only the line underneath turns red it goes unseen on a scrolled screen.
func set_error(message: String) -> void:
	_error = message
	error_label.text = message
	error_label.visible = not message.is_empty()
	_paint()


func has_error() -> bool:
	return not _error.is_empty()


func focus() -> void:
	edit.grab_focus()


func _on_text(raw: String) -> void:
	var cleaned := _clean(raw)
	if cleaned != raw:
		# 🛑 Put the caret back at the end — otherwise it slips back by the number of filtered-out characters.
		edit.text = cleaned
		edit.caret_column = cleaned.length()
	if not _error.is_empty(): set_error("")
	_paint()
	changed.emit(cleaned)
	if cleaned.length() >= length:
		edit.release_focus()
		GoFeedback.confirmed()
		completed.emit(cleaned)


## Keep only the accepted characters. 🔑 The hyphens and spaces of a pasted `ABCD-EFGH-IJKL` fall away here.
func _clean(raw: String) -> String:
	var out := ""
	var source := raw.to_upper() if uppercase else raw
	for index in source.length():
		if out.length() >= length: break
		var glyph := source[index]
		if allowed.is_empty() or allowed.contains(glyph): out += glyph
	return out


func _rebuild() -> void:
	if cells_row == null: return
	# 🛑 Clearing only `_cells` leaves the **gap** spacers at the break positions behind, and they pile up
	#    every time the length changes (measured 2026-09-16: grew from 19 to 22). Empty the whole row.
	for child in cells_row.get_children(): child.queue_free()
	_cells.clear()
	edit.max_length = length
	var side := cell_width if cell_width > 0.0 else float(GoUi.font_size(GoTheme.ROLE_SUBTITLE)) * 1.7
	for index in length:
		# Open a gap at the break — `ABCD EFGH IJKL` reads far better than twelve characters in one lump.
		if group > 0 and index > 0 and index % group == 0:
			var gap := Control.new()
			gap.name = "Gap%d" % index
			gap.custom_minimum_size.x = GoUi.metric(GoTheme.GAP_SMALL)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cells_row.add_child(gap)
		var cell := PanelContainer.new()
		cell.name = "Cell%d" % index
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 🛑 **Claim only a minimum width and share out what is left.** Give 12 cells a fixed width and they
		#    come to 669dp on a 720dp phone — with the side margins added the cells were clipped off the
		#    screen (captured 2026-09-16). Cells narrowing along with the screen beats cells being clipped.
		cell.custom_minimum_size = Vector2(minf(side, 28.0), side * 1.25)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := GoStyle.label("", GoTheme.ROLE_SUBTITLE)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		glyph.text_direction = Control.TEXT_DIRECTION_LTR
		# It is a single character — there is nothing to wrap, and leaving it on makes the height jump in a narrow cell.
		glyph.autowrap_mode = TextServer.AUTOWRAP_OFF
		# 🛑 **Do not let the glyph decide the cell width.** With `clip_text` on, the label's minimum width is 0,
		#    so a filled cell stays as wide as an empty one (captured 2026-09-16: the leading cells were wider and ragged).
		glyph.clip_text = true
		glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(glyph)
		_cells.append(cell)
		cells_row.add_child(cell)
	_paint()


func _paint() -> void:
	var value := edit.text
	for index in _cells.size():
		var cell := _cells[index]
		var glyph := cell.get_child(0) as Label
		if glyph != null: glyph.text = value[index] if index < value.length() else ""
		var filled := index < value.length()
		var here := index == value.length()
		var accent := GoUi.color(GoTheme.DANGER) if has_error() \
			else GoUi.color(GoTheme.ACCENT if here or filled else GoTheme.BORDER)
		cell.add_theme_stylebox_override(&"panel", GoUi.skin().slot_box(accent, here))
	# ♿ "n of m characters" — the drawn cells are information for the eyes only. 🔑 The 「n / m」 form already has
	#    a string key (Turkish and French write this form differently — hard-code it and it reads oddly there).
	# 🛑 Saying `search` here would make a coupon field read as "search 0 / 12" — the caller knows what goes in
	#    the field. The label comes from `GoField` or the line above; here we state **progress only**.
	var progress := GoUi.text(&"bar_fraction").format({"value": value.length(), "max": length})
	edit.accessibility_name = GoUi.spoken([_error, progress])


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _paint()
