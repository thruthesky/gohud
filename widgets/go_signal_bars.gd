## 📶 **A signal meter** — a phone's signal bars: `max_bars` bars rising left to right, the first `bars` lit in the
## reading's tone and the rest dim, with an optional readout beside them. A match HUD's ping, a connection's quality.
##
## ```gdscript
## var ping := GoSignalBars.make(4, GoSignalBars.Tone.GOOD)
## ping.set_reading(2, GoSignalBars.Tone.FAIR, "180 ms")   # one call, one redraw
## ping.set_reading(0, GoSignalBars.Tone.NONE)              # no reading yet: every bar dim, no text
## ```
##
## The bars are drawn by the skin (`GoSkin.draw_signal_bars`): the arcade looks paint each one as a small key with the
## ink outline and a gloss (arcade_light: the game's green, gold and red over its ink), a plain look draws rounded
## bars. A lit bar takes the tone's fill token — `success_fill` (GOOD), `warning_fill` (FAIR), `danger_fill` (POOR) —
## and a dim one a faded `muted_fill`. The readout is the look's outlined HUD text (`GoOutlineLabel` in arcade_light,
## else the name plate's ink and edge), so it reads on the 3D scene with no board behind it; `panel` puts the meter on
## the theme's `GoHudPanel` board instead, with the board's own label ink.
##
## 🛑 Display only — the caller decides every value (the bars, the tone, the text). Nothing here measures or judges.
## 🛑 It ignores the mouse, so what is under it still takes the press. It never flips with the language: the short bar
##    is always the left one.
@tool
class_name GoSignalBars
extends PanelContainer

## The reading's colour. NONE is no reading yet: every bar dim, whatever `bars` says.
enum Tone { GOOD, FAIR, POOR, NONE }

## The theme type the meter's board takes when `panel` is on — the match HUD's board.
const VAR_PANEL := &"GoHudPanel"
## The theme type of the readout over the scene — the look's outlined HUD text.
const VAR_TEXT := &"GoOutlineLabel"
## How much of `muted_fill` a dim bar keeps.
const DIM_ALPHA := 0.55
## The shortest bar against the tallest; the bars between rise evenly.
const LOW_SHARE := 0.4
## One bar's width and the gap between two, against the tallest bar's height.
const WIDTH_SHARE := 0.4
const GAP_SHARE := 0.15
## The least clear space (dp) between the board's rim and the meter at the sides when `panel` is on.
const BOARD_ROOM := 6.0
## The readout's ink edge over the scene is at least this share of its font size — thick enough to read on any
## background, sky or ground.
const EDGE_SHARE := 0.4

## The lit bars. More than `max_bars` lights them all; under 0 counts as 0 (`lit()` is the shown count).
@export_range(0, 8) var bars := 0:
	set(value):
		if bars == maxi(0, value): return   # a HUD sets every field on each tick
		bars = maxi(0, value)
		_refresh()

## How many bars the meter holds.
@export_range(1, 8) var max_bars := 4:
	set(value):
		if max_bars == maxi(1, value): return
		max_bars = maxi(1, value)
		_refresh()

## The reading's colour (`Tone`).
@export var tone: Tone = Tone.NONE:
	set(value):
		if tone == value: return
		tone = value
		_refresh()

## The readout beside the bars ("48 ms"). Empty hides it.
@export var text := "":
	set(value):
		if text == value: return
		text = value
		_refresh()

## The tallest bar (dp), before `scale_factor`.
@export var bar_height := 24.0:
	set(value):
		if bar_height == maxf(4.0, value): return
		bar_height = maxf(4.0, value)
		_refresh()

## The readout's font size, before `scale_factor`.
@export_range(6, 64) var text_size := 20:
	set(value):
		if text_size == maxi(6, value): return
		text_size = maxi(6, value)
		_refresh()

## A fixed room for the readout (dp, before `scale_factor`) — the bars keep still when "48 ms" becomes "148 ms", and a
## longer text shrinks to fit (`GoStyle.fit_font_size`, never under its floor). 0: the text's own width.
@export var text_width := 0.0:
	set(value):
		if text_width == maxf(0.0, value): return
		text_width = maxf(0.0, value)
		_refresh()

## Puts the meter on the theme's `GoHudPanel` board (a theme without one: its PanelContainer panel). Off, the meter
## stands on the scene with nothing behind it.
@export var panel := false:
	set(value):
		if panel == value: return
		panel = value
		_refresh()

## Every size is multiplied by this (1 = the design size).
@export var scale_factor := 1.0:
	set(value):
		if scale_factor == maxf(0.1, value): return
		scale_factor = maxf(0.1, value)
		_refresh()

## The node the bars are drawn on (the skin draws them in its `draw` signal).
var meter: Control
## The readout.
var label: Label

var _row: HBoxContainer
var _built := false
## While `set_reading` sets several fields, the setters hold their refresh back.
var _holding := false
## How many times the meter has been rebuilt — the checks count that a setter with nothing new skips it.
var _refreshes := 0
## The board `panel` shows: [the theme's box, the room, the padded copy].
var _board: Array = []


func _init() -> void:
	name = "SignalBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)
	meter = Control.new()
	meter.name = "Bars"
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.draw.connect(_draw_bars)
	_row.add_child(meter)
	label = GoStyle.one_line(Label.new())   # one line, even inside a GoForm (which wraps every other label)
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text_direction = Control.TEXT_DIRECTION_LTR   # "48 ms" reads the same in every language
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(label)
	_built = true
	_refresh()


static func make(p_bars := 0, p_tone := Tone.NONE) -> GoSignalBars:
	var node := GoSignalBars.new()
	node.set_reading(p_bars, p_tone)
	return node


## Shows a reading in one go — the bars, the tone and the readout — with one rebuild and one redraw.
func set_reading(p_bars: int, p_tone: Tone, p_text := "") -> void:
	var before := [bars, tone, text]
	_holding = true
	bars = p_bars
	tone = p_tone
	text = p_text
	_holding = false
	if before != [bars, tone, text]: _refresh()


## The bars shown lit: `bars` held to `0..max_bars`, and none while the tone is NONE.
func lit() -> int:
	return 0 if tone == Tone.NONE else clampi(bars, 0, max_bars)


## Is the bar at [param index] (0 = the short left one) lit.
func is_lit(index: int) -> bool:
	return index >= 0 and index < lit()


## The colour a lit bar takes in this tone: the tone's fill token. NONE gives the dim colour.
func tone_color() -> Color:
	match tone:
		Tone.GOOD: return GoUi.color(GoTheme.SUCCESS_FILL)
		Tone.FAIR: return GoUi.color(GoTheme.WARNING_FILL)
		Tone.POOR: return GoUi.color(GoTheme.DANGER_FILL)
	return dim_color()


## The colour of a bar that is not lit — `muted_fill`, faded to `DIM_ALPHA`.
func dim_color() -> Color:
	var ink := GoUi.color(GoTheme.MUTED_FILL)
	return Color(ink, ink.a * DIM_ALPHA)


## The tallest bar in pixels, `bar_height` × `scale_factor`.
func bar_side() -> float:
	return roundf(bar_height * scale_factor)


## Each bar's rect inside `meter`, left to right — the short one first, the tallest last, standing on one line.
func bar_rects() -> Array[Rect2]:
	var tall := bar_side()
	var width := maxf(2.0, roundf(tall * WIDTH_SHARE))
	var gap := maxf(1.0, roundf(tall * GAP_SHARE))
	var rects: Array[Rect2] = []
	for i in max_bars:
		var share := 1.0 if max_bars == 1 else lerpf(LOW_SHARE, 1.0, float(i) / float(max_bars - 1))
		var high := roundf(tall * share)
		rects.append(Rect2(float(i) * (width + gap), tall - high, width, high))
	return rects


## The bars' width and height — what `meter` asks of the row.
func meter_size() -> Vector2:
	var rects := bar_rects()
	return Vector2(rects[-1].end.x if not rects.is_empty() else 0.0, bar_side())


## Rebuilds the meter now (the setters already do).
func refresh() -> void:
	_refresh()


func _enter_tree() -> void:
	GoUi.watch(_refresh)
	if is_node_ready(): _refresh()


func _exit_tree() -> void:
	GoUi.unwatch(_refresh)


func _refresh() -> void:
	if not _built or _holding: return
	_refreshes += 1
	theme = GoUi.theme()   # a HUD layer has no theme of its own; follows the look when it changes
	_dress_panel()
	_row.add_theme_constant_override(&"separation", roundi(maxf(4.0, bar_height * 0.3) * scale_factor))
	meter.custom_minimum_size = meter_size()
	_dress_label()
	accessibility_name = "%d/%d %s" % [lit(), max_bars, text] if not text.is_empty() else "%d/%d" % [lit(), max_bars]
	meter.queue_redraw()


## Off: nothing behind the meter. On: the theme's `GoHudPanel` board, its clear space at least `BOARD_ROOM` past the
## face's rim at the sides (a plain look's panel carries none, and the readout would touch the border). The padded
## copy is kept while the theme's board and the room stay the same.
func _dress_panel() -> void:
	if not panel:
		theme_type_variation = &""
		_board = []
		if not has_theme_stylebox_override(&"panel") or not get_theme_stylebox(&"panel") is StyleBoxEmpty:
			add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		return
	theme_type_variation = VAR_PANEL
	var room := roundf(BOARD_ROOM * scale_factor)
	var box := _theme_board()
	if box != null and not _board.is_empty() and _board[0] == box and _board[1] == room \
			and has_theme_stylebox_override(&"panel") and get_theme_stylebox(&"panel") == _board[2]: return
	if box == null:
		_board = []
		return
	var copy := box.duplicate() as StyleBox
	add_theme_stylebox_override(&"panel", box)   # the clearance is the board's own rim and corners
	var side_room := float(GoStyle.face_clearance(self, true)) + room
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		copy.set_content_margin(side, maxf(box.get_content_margin(side), side_room))
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		copy.set_content_margin(side, maxf(box.get_content_margin(side), room * 0.5))
	_board = [box, room, copy]
	add_theme_stylebox_override(&"panel", copy)


## The theme's own `GoHudPanel` board, past this node's override (an override wins over every theme type).
func _theme_board() -> StyleBox:
	var look := theme if theme != null else GoUi.theme()
	if look != null and look.has_stylebox(&"panel", VAR_PANEL): return look.get_stylebox(&"panel", VAR_PANEL)
	if look != null and look.has_stylebox(&"panel", &"PanelContainer"): return look.get_stylebox(&"panel", &"PanelContainer")
	return ThemeDB.get_project_theme().get_stylebox(&"panel", &"PanelContainer") if ThemeDB.get_project_theme() != null \
		else ThemeDB.get_default_theme().get_stylebox(&"panel", &"PanelContainer")


## The readout: over the scene the look's outlined HUD text (or the name plate's ink and edge when the look has none),
## on the board the board's label ink. The outline grows with `scale_factor`, as the text does.
func _dress_label() -> void:
	label.text = text
	label.visible = not text.is_empty()
	var size := roundi(text_size * scale_factor)
	var room := text_width * scale_factor
	for key: StringName in [&"font_color", &"font_outline_color"]: label.remove_theme_color_override(key)
	label.remove_theme_constant_override(&"outline_size")
	var look := GoUi.theme()
	var outlined := look != null and look.get_type_variation_base(VAR_TEXT) == &"Label"
	label.theme_type_variation = VAR_TEXT if outlined and not panel else &""
	if not panel:
		var skin := GoUi.skin()
		var edge := float(look.get_constant(&"outline_size", VAR_TEXT)) if outlined else float(skin.nameplate_outline(false))
		if not outlined:
			label.add_theme_color_override(&"font_color", skin.nameplate_ink(false))
			label.add_theme_color_override(&"font_outline_color", skin.nameplate_outline_ink())
		label.add_theme_constant_override(&"outline_size", maxi(roundi(edge * scale_factor), roundi(size * EDGE_SHARE)))
	if room > 0.0 and not text.is_empty():
		size = GoStyle.fit_font_size(PackedStringArray([text]), size, room, label.get_theme_font(&"font"))
	label.add_theme_font_size_override(&"font_size", size)
	label.custom_minimum_size.x = room
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _draw_bars() -> void:
	var rects := bar_rects()
	if rects.is_empty(): return
	GoUi.skin().draw_signal_bars(meter, rects, lit(), tone_color(), dim_color())
