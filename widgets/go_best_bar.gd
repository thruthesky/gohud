## 🥇 **The player's best, pinned under a leaderboard** — a glossy bar: "YOUR BEST", an inset pill with the player's
## rank, name and value spread across it (or "—  NO RECORD YET  —"), and a big green PLAY key with a play glyph.
##
## ```gdscript
## var best := GoBestBar.new()
## best.set_entry("#4", "YOU", "00:39.30")
## best.set_empty("NO RECORD YET")                 # no personal record: drawn as "—  NO RECORD YET  —"
## best.play_pressed.connect(_start_stage)
## best.entry_pressed.connect(_show_around_me)     # the pill is a tap target (jump to the player's own rank)
## best.play_button.visible = false                 # nothing to play right now
## ```
##
## The looks are the theme's: `GoBestBar` (the bar), `GoBestBarLabel` (its "YOUR BEST" and the pill's lettering),
## `GoBestBarEntry` (the pill, a `Button`) and the primary key (`GoTheme.VAR_PRIMARY_BUTTON`, arcade_light: the green
## painted pill) for PLAY. A look without them falls back to plain panels, labels and buttons.
## 🛑 Display only — the rank, name and value are the caller's (the server's), shown as given.
## 🔑 The pill's texts shrink together to fit it (`GoStyle.fit_font_size`, down to `GoConfig.fit_min_scale`); a name
##    still too long ends in an ellipsis. The PLAY label shrinks to fit its key (`GoGlyphButton.fit_label`).
@tool
class_name GoBestBar
extends PanelContainer

## The PLAY key was pressed.
signal play_pressed
## The pill (the player's own entry) was pressed.
signal entry_pressed

const VAR_BAR := &"GoBestBar"
const VAR_LABEL := &"GoBestBarLabel"
const VAR_ENTRY := &"GoBestBarEntry"
## The dash either side of the empty text.
const DASH := "—"
## The pill's three spots as shares of its width: rank, name, value — and, empty, dash, text, dash.
const ENTRY_SHARES: Array[float] = [0.25, 0.32, 0.43]
const EMPTY_SHARES: Array[float] = [0.26, 0.48, 0.26]
## The room kept clear inside the pill's sides for each text (dp).
const ENTRY_TEXT_PAD := 6.0

## The caption before the pill.
@export var label_text := "YOUR BEST":
	set(value):
		label_text = value
		if is_instance_valid(label): label.text = value
		_queue_fit()

## The PLAY key's label.
@export var play_text := "PLAY":
	set(value):
		play_text = value
		if is_instance_valid(play_button): play_button.text = value

## The PLAY key's size (dp).
@export var play_size := Vector2(295.0, 74.0):
	set(value):
		play_size = value
		if is_instance_valid(play_button): play_button.custom_minimum_size = value

## The PLAY label's size before it shrinks to fit. 0: the theme's.
@export_range(0, 128) var play_font_size := 40:
	set(value):
		play_font_size = value
		if is_instance_valid(play_button): play_button.fit_base_size = value

## The pill's height (dp).
@export_range(16.0, 200.0, 1.0) var entry_height := 44.0:
	set(value):
		entry_height = value
		if is_instance_valid(entry_button): entry_button.custom_minimum_size.y = value

## The space between the caption, the pill and the key (dp).
@export_range(0, 96) var gap := 18:
	set(value):
		gap = value
		if is_instance_valid(_row): _row.add_theme_constant_override(&"separation", value)

## The caption ("YOUR BEST").
var label: Label
## The pill: the player's own entry — a tap target (`entry_pressed`).
var entry_button: Button
## The green PLAY key (`play_pressed`).
var play_button: GoGlyphButton

var _row: HBoxContainer
var _entry_row: HBoxContainer
var _entry_labels: Array[Label] = []
var _empty := true
var _fit_queued := false


func _init() -> void:
	name = "BestBar"
	theme_type_variation = VAR_BAR
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override(&"separation", gap)
	add_child(_row)
	label = Label.new()
	label.name = "Caption"
	label.theme_type_variation = VAR_LABEL
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(label)
	entry_button = Button.new()
	entry_button.name = "Entry"
	entry_button.theme_type_variation = VAR_ENTRY
	entry_button.focus_mode = Control.FOCUS_NONE
	entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry_button.custom_minimum_size = Vector2(120.0, entry_height)
	entry_button.pressed.connect(func() -> void: entry_pressed.emit())
	_row.add_child(entry_button)
	_entry_row = HBoxContainer.new()
	_entry_row.name = "Texts"
	_entry_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_entry_row.add_theme_constant_override(&"separation", 0)
	entry_button.add_child(_entry_row)
	for spot in 3:
		var text := Label.new()
		text.name = ["Rank", "Name", "Value"][spot]
		text.theme_type_variation = VAR_LABEL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_FILL
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		text.custom_minimum_size.x = 1.0
		_entry_row.add_child(text)
		_entry_labels.append(text)
	_entry_labels[0].text_direction = Control.TEXT_DIRECTION_LTR
	_entry_labels[2].text_direction = Control.TEXT_DIRECTION_LTR
	play_button = GoGlyphButton.make(play_text, GoIconSet.PLAY, GoTheme.VAR_PRIMARY_BUTTON)
	play_button.name = "Play"
	play_button.custom_minimum_size = play_size
	play_button.fit_label = true
	play_button.fit_base_size = play_font_size
	play_button.feedback = GoFeedback.CONFIRMED
	play_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	_row.add_child(play_button)
	set_empty("NO RECORD YET")
	entry_button.resized.connect(_queue_fit)
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
	_queue_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_TRANSLATION_CHANGED: _queue_fit()


## Shows the player's own entry: [param rank_text] ("#4"), [param player_name] and [param value] spread across the pill.
func set_entry(rank_text: String, player_name: String, value: String) -> void:
	_empty = false
	_set_texts([rank_text, player_name, value], ENTRY_SHARES)
	entry_button.tooltip_text = str(rank_text, " ", player_name, " ", value)


## No personal record: the pill reads "—  [param text]  —".
func set_empty(text: String) -> void:
	_empty = true
	_set_texts([DASH, text, DASH], EMPTY_SHARES)
	entry_button.tooltip_text = text


## Whether the pill shows no record (`set_empty`) rather than an entry.
func is_empty() -> bool:
	return _empty


## The pill's three texts: [rank, name, value] — or, empty, [dash, text, dash].
func entry_texts() -> PackedStringArray:
	return PackedStringArray([_entry_labels[0].text, _entry_labels[1].text, _entry_labels[2].text])


## The pill's labels: [rank, name, value].
func entry_labels() -> Array[Label]:
	return _entry_labels.duplicate()


func _set_texts(texts: Array, shares: Array[float]) -> void:
	for spot in 3:
		_entry_labels[spot].text = texts[spot]
		_entry_labels[spot].size_flags_stretch_ratio = shares[spot]
	_queue_fit()


func _queue_fit() -> void:
	if _fit_queued or _entry_labels.is_empty(): return
	_fit_queued = true
	_fit.call_deferred()


## The pill's texts shrink together until each fits its spot; the caption fits its own width.
func _fit() -> void:
	_fit_queued = false
	if _entry_labels.is_empty(): return
	var box := entry_button.get_theme_stylebox(&"normal")
	var inner := entry_button.size.x - (box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box != null else 0.0)
	_entry_row.offset_left = box.get_margin(SIDE_LEFT) if box != null else 0.0
	_entry_row.offset_right = -(box.get_margin(SIDE_RIGHT) if box != null else 0.0)
	if inner <= 0.0: return
	var base := entry_button.get_theme_font_size(&"font_size")
	var size_now := base
	var font := _entry_labels[0].get_theme_font(&"font")
	for spot in 3:
		var share: float = _entry_labels[spot].size_flags_stretch_ratio
		var room := maxf(1.0, inner * share - ENTRY_TEXT_PAD * 2.0)
		size_now = mini(size_now, GoStyle.fit_font_size(PackedStringArray([_entry_labels[spot].text]), base, room, font))
	for text in _entry_labels:
		text.add_theme_font_size_override(&"font_size", size_now)
