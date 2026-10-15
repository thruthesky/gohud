## 📋 **A task card** — a lesson's card in a tutorial played through the game: a step line, a title, what to do, one
## chip per part that ticks off as it is done, a hint when the player is stuck and a short footer. It has no buttons
## and never takes input. On a phone it folds to one `compact` row (step, title, chips) once it has been read.
##
## ```gdscript
## var card := GoTaskCard.new()
## hud.add_child(card)
## card.custom_minimum_size.x = 440
## card.caption = tr("STEP_LABEL").format({"n": 1, "total": 12})   # "TRAINING · STEP 1/12"
## card.short_caption = "1/12"                                    # what the compact row starts with
## card.title = tr("TITLE_MOVE")
## card.body = tr("BODY_MOVE")
## card.footer = tr("FOOTER_PAUSE")
## card.set_parts(["W", "A", "S", "D"])
## card.mark_part(0, true)                                        # the game said the part is done
## card.hint = tr("HINT_RING_OUT")                                # "" hides it
## ```
##
## The board is the theme's `GoHudPanel` (arcade_light: the game's blue-rimmed board) padded by `padding`; the chips
## are `GoSkin.kbd_box()` caps, a done one `GoSkin.kbd_done_box()` with "✓ " before its word. The title is in
## `GoSkin.task_title_ink()` and shrinks to stay on one line; the hint is in `GoSkin.task_hint_ink()`. Pair it with a
## `GoSpotlight` to point at what the lesson is about. 🛑 Display only: what is done comes from the caller.
@tool
class_name GoTaskCard
extends PanelContainer

const VAR_PANEL := &"GoHudPanel"
## The step line and the footer are the label ink at this opacity.
const CAPTION_ALPHA := 0.75
## What a done chip's word starts with.
const DONE_MARK := "✓ "

## The step line ("TRAINING · STEP 1/12").
@export var caption := "":
	set(value):
		caption = value
		_sync()

## The compact row's step counter ("1/12").
@export var short_caption := "":
	set(value):
		short_caption = value
		_sync()

## The lesson's name — one line, shrunk to fit.
@export var title := "":
	set(value):
		title = value
		_sync()

## What to do. Wraps.
@export_multiline var body := "":
	set(value):
		body = value
		_sync()

## What to try when stuck. Empty hides the row.
@export var hint := "":
	set(value):
		hint = value
		_sync()

## A short line at the end of the chip row (how to pause, say).
@export var footer := "":
	set(value):
		footer = value
		_sync()

## One row: the short caption, the title and the chips (a phone, once the card has been read).
@export var compact := false:
	set(value):
		compact = value
		_sync()

## Clear space inside the board's rim (dp). Negative keeps the theme's.
@export var padding := 20.0:
	set(value):
		padding = value
		_restyle()

## Room between the rows (dp).
@export_range(0, 64) var row_gap := 4:
	set(value):
		row_gap = value
		_restyle()

@export_range(6, 96) var title_size := 22:
	set(value):
		title_size = value
		_fit_title()

@export_range(6, 64) var body_size := 15:
	set(value):
		body_size = value
		_restyle()

@export_range(6, 64) var hint_size := 14:
	set(value):
		hint_size = value
		_restyle()

@export_range(6, 64) var caption_size := 12:
	set(value):
		caption_size = value
		_restyle()

@export_range(6, 64) var chip_size := 16:
	set(value):
		chip_size = value
		_sync()

## The compact row's font size (its words and chips).
@export_range(6, 64) var strip_size := 13:
	set(value):
		strip_size = value
		_sync()

var caption_label: Label
var title_label: Label
var body_label: Label
var hint_label: Label
var footer_label: Label
var strip_label: Label
## The compact row.
var strip_row: HBoxContainer
## The full card's last row: the chips, then the footer pushed right.
var chip_row: HBoxContainer

var _box: VBoxContainer
var _chip_flow: HFlowContainer
var _chips: Array[PanelContainer] = []
var _word_font: FontVariation
var _words: PackedStringArray = []
var _done: Array[bool] = []
var _fit_for := ""
var _fit_room := -1.0


func _init() -> void:
	name = "TaskCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = VAR_PANEL
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	strip_row = _row("Strip")
	_box.add_child(strip_row)
	strip_label = _label("StripText", false)
	strip_row.add_child(strip_label)
	caption_label = _label("Caption")
	title_label = _label("Title")
	body_label = _label("Body")
	hint_label = _label("Hint")
	for label: Label in [caption_label, title_label, body_label, hint_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(label)
	chip_row = _row("Parts")
	_box.add_child(chip_row)
	_chip_flow = HFlowContainer.new()
	_chip_flow.name = "Chips"
	_chip_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_flow.add_theme_constant_override(&"h_separation", 6)
	_chip_flow.add_theme_constant_override(&"v_separation", 4)
	_chip_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_row.add_child(_chip_flow)
	footer_label = _label("Footer", false)
	footer_label.size_flags_vertical = Control.SIZE_SHRINK_END
	chip_row.add_child(footer_label)


func _ready() -> void:
	theme = GoUi.theme()
	_restyle()


func _enter_tree() -> void:
	GoUi.watch(_restyle)
	if is_node_ready(): _restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _fit_title()


## Sets the parts — one chip each — and which are done (missing entries are not done).
func set_parts(words: PackedStringArray, done: Array = []) -> void:
	_words = words
	_done.clear()
	for index in words.size(): _done.append(index < done.size() and bool(done[index]))
	for chip in _chips:
		chip.get_parent().remove_child(chip)
		chip.queue_free()
	_chips.clear()
	for index in words.size():
		var chip := PanelContainer.new()
		chip.name = "Chip%d" % index
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var word := Label.new()
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.add_child(word)
		_chip_flow.add_child(chip)
		_chips.append(chip)
	_sync()


## Ticks part [param index] done (or not).
func mark_part(index: int, done := true) -> void:
	if index < 0 or index >= _done.size(): return
	_done[index] = done
	_sync()


func part_done(index: int) -> bool:
	return index >= 0 and index < _done.size() and _done[index]


## The chips, in order.
func chips() -> Array[PanelContainer]:
	return _chips.duplicate()


## The word on chip [param index] as shown ("✓ W" once done).
func chip_text(index: int) -> String:
	return (_chips[index].get_child(0) as Label).text if index >= 0 and index < _chips.size() else ""


func _row(row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	return row


func _label(label_name: String, wrap := true) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# SMART: exports lack ICU break data, and only SMART still wraps ja/zh there.
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _sync() -> void:
	if not is_instance_valid(_box): return
	caption_label.text = caption
	title_label.text = title
	body_label.text = body
	hint_label.text = hint
	footer_label.text = footer
	strip_label.text = (short_caption + "  " + title) if not short_caption.is_empty() else title
	var full := not compact
	caption_label.visible = full
	title_label.visible = full
	body_label.visible = full
	footer_label.visible = full
	chip_row.visible = full
	hint_label.visible = full and not hint.is_empty()
	strip_row.visible = not full
	var holder: Control = chip_row if full else strip_row
	if _chip_flow.get_parent() != holder:
		_chip_flow.get_parent().remove_child(_chip_flow)
		holder.add_child(_chip_flow)
		if full: chip_row.move_child(_chip_flow, 0)
	var chip_font := chip_size if full else strip_size
	strip_label.add_theme_font_size_override(&"font_size", strip_size)
	var skin := GoUi.skin() if is_inside_tree() else null
	for index in _chips.size():
		var word := _chips[index].get_child(0) as Label
		word.text = (DONE_MARK + _words[index]) if _done[index] else _words[index]
		word.add_theme_font_size_override(&"font_size", chip_font)
		if skin != null:
			_chips[index].add_theme_stylebox_override(&"panel", skin.kbd_done_box() if _done[index] else skin.kbd_box())
			word.add_theme_color_override(&"font_color", skin.kbd_done_ink() if _done[index] else skin.kbd_ink())
		var font := _chip_word_font(skin)
		if font != null: word.add_theme_font_override(&"font", font)
		else: word.remove_theme_font_override(&"font")
	_fit_for = ""
	_fit_title()


## The theme's text font with the look's symbol font under it (so the ✓ draws), or null when the look names none.
func _chip_word_font(skin: GoSkin) -> Font:
	var symbols: Font = skin.symbol_font() if skin != null else null
	if symbols == null: return null
	var base := get_theme_font(&"font", &"Label")
	if _word_font == null or _word_font.base_font != base or not _word_font.fallbacks.has(symbols):
		_word_font = FontVariation.new()
		_word_font.base_font = base
		var fallbacks: Array[Font] = [symbols]
		if base != null: fallbacks.append_array(base.fallbacks)
		_word_font.fallbacks = fallbacks
	return _word_font


func _restyle() -> void:
	theme = GoUi.theme()
	if not is_instance_valid(_box) or not is_inside_tree(): return
	var skin := GoUi.skin()
	remove_theme_stylebox_override(&"panel")
	var themed := GoUi.theme()
	if themed == null or not themed.has_stylebox(&"panel", VAR_PANEL):
		theme_type_variation = &""
		add_theme_stylebox_override(&"panel", GoHudCard._padded(skin.floating_box(GoTheme.BOX_CARD,
			GoUi.color(GoTheme.ACCENT), -1.0), padding))
	else:
		theme_type_variation = VAR_PANEL
		if padding >= 0.0:
			add_theme_stylebox_override(&"panel", GoHudCard._padded(get_theme_stylebox(&"panel", VAR_PANEL), padding))
	_box.add_theme_constant_override(&"separation", row_gap)
	var ink := get_theme_color(&"font_color", &"Label")
	for label: Label in [caption_label, footer_label]:
		label.add_theme_font_size_override(&"font_size", caption_size)
		label.add_theme_color_override(&"font_color", Color(ink, ink.a * CAPTION_ALPHA))
	title_label.add_theme_color_override(&"font_color", skin.task_title_ink())
	strip_label.add_theme_color_override(&"font_color", skin.task_title_ink())
	body_label.add_theme_font_size_override(&"font_size", body_size)
	hint_label.add_theme_font_size_override(&"font_size", hint_size)
	hint_label.add_theme_color_override(&"font_color", skin.task_hint_ink())
	_sync()


## Shrinks the title until it fits one line of the card. Only measures when the title or the room changed.
func _fit_title() -> void:
	if not is_instance_valid(title_label) or not is_inside_tree(): return
	var box := get_theme_stylebox(&"panel")
	var room := maxf(size.x, custom_minimum_size.x) - (box.get_minimum_size().x if box != null else 0.0)
	if title == _fit_for and is_equal_approx(room, _fit_room): return
	_fit_for = title
	_fit_room = room
	title_label.add_theme_font_size_override(&"font_size",
		GoStyle.fit_font_size(PackedStringArray([title]), title_size, room, title_label.get_theme_font(&"font")))
