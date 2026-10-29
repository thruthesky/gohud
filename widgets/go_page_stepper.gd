## 📄 **A page stepper** — a page's name on a cream plate between two square arrow keys, a row of page dots under the
## name (the current one dark): STAGE 4 of five, say, on a leaderboard that shows one stage at a time.
##
## ```gdscript
## var stage := GoPageStepper.new()
## stage.text = "STAGE 4"
## stage.page_count = 5
## stage.page_index = 3
## stage.previous_pressed.connect(func(): _show_stage(current - 1))
## stage.next_pressed.connect(func(): _show_stage(current + 1))
## stage.next_disabled = current == last          # the arrow at the last page is off
## ```
##
## The keys are `GoGlyphButton`s in the theme's `GoArrowButton` (square blue gloss in arcade_light; a theme without it
## falls back to its `Button`) with the icon set's play glyph (mirrored for the left key); the plate is the theme's
## `GoPagePlate` (or the skin's painted `page_plate_art`, `stage_plate`), the name `GoPageLabel`, the dots the skin's
## `page_dot_colors`.
## 🛑 The stepper keeps no page of its own: the keys only say they were pressed, and the caller sets `text`,
##    `page_index` and the disabled ends from what it loaded — a stage that is not there yet is never shown as current.
## 🔤 The name shrinks to fit the plate (`GoStyle.fit_font_size`, never under `GoConfig.fit_min_scale`).
## 🔑 Right to left, the keys swap sides (the box mirrors) and the glyphs point the other way, so "previous" still
##    points back.
@tool
class_name GoPageStepper
extends HBoxContainer

## A key was pressed (the caller moves the page). Never emitted while that key is disabled.
signal previous_pressed
signal next_pressed

## The page dots' diameter and the space from one dot's centre to the next, as shares of the name's font size.
const DOT_SHARE := 0.3
const DOT_STEP := 0.61
## The gap between each key and the plate, as a share of [member key_size].
const KEY_GAP_SHARE := 0.07
## The glyph's height on a key, as a share of the key's height.
const KEY_GLYPH_SHARE := 0.5
const VAR_KEY := &"GoArrowButton"
const VAR_PLATE := &"GoPagePlate"
const VAR_LABEL := &"GoPageLabel"

## The page's name ("STAGE 4").
@export var text := "":
	set(value):
		text = value
		if label != null: label.text = value
		_queue_fit()

## How many dots stand under the name. Under 2: no dots.
@export_range(0, 99) var page_count := 0:
	set(value):
		page_count = maxi(0, value)
		_update_dots()

## Which dot is dark (0-based; out of range: none).
@export var page_index := 0:
	set(value):
		page_index = value
		if dots != null: dots.queue_redraw()

## The previous key is off (the first page).
@export var previous_disabled := false:
	set(value):
		previous_disabled = value
		if previous_button != null: previous_button.disabled = value

## The next key is off (the last page).
@export var next_disabled := false:
	set(value):
		next_disabled = value
		if next_button != null: next_button.disabled = value

## The keys' side (dp): they are square.
@export var key_size := 80.0:
	set(value):
		key_size = value
		_size_keys()

var previous_button: GoGlyphButton
var next_button: GoGlyphButton
## The cream plate between the keys, its name and its dots.
var plate: PanelContainer
var label: Label
var dots: Control
var _fit_queued := false


func _init() -> void:
	add_theme_constant_override(&"separation", 0)
	previous_button = _key(true)
	add_child(previous_button)
	plate = PanelContainer.new()
	plate.name = "Plate"
	plate.theme_type_variation = VAR_PLATE
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical = Control.SIZE_FILL
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	label = Label.new()
	label.name = "Name"
	label.theme_type_variation = VAR_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	dots = Control.new()
	dots.name = "Dots"
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(_draw_dots)
	column.add_child(dots)
	next_button = _key(false)
	add_child(next_button)
	previous_button.pressed.connect(func() -> void: if not previous_button.disabled: previous_pressed.emit())
	next_button.pressed.connect(func() -> void: if not next_button.disabled: next_pressed.emit())
	plate.resized.connect(_queue_fit)
	_size_keys()
	_update_dots()


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	_on_ui_changed()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	var painted := GoUi.skin().page_plate_art()
	if painted != null:
		var face := plate.get_theme_stylebox(&"panel")
		if face != null and not plate.has_theme_stylebox_override(&"panel"):
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: painted.set_content_margin(side, face.get_margin(side))
		plate.add_theme_stylebox_override(&"panel", painted)
	elif plate.has_theme_stylebox_override(&"panel"):
		plate.remove_theme_stylebox_override(&"panel")
	previous_button.accessibility_name = GoUi.text(&"back")
	next_button.accessibility_name = GoUi.text(&"next")
	_point_keys()
	_update_dots()
	_queue_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED: _queue_fit()
	elif what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED: _point_keys()


## The glyphs point outwards: left on the leading key, right on the trailing one (swapped right to left).
func _point_keys() -> void:
	var rtl := is_layout_rtl()
	previous_button.glyph_flip_h = not rtl
	next_button.glyph_flip_h = rtl


## Fits the name to the plate now instead of at the end of the frame.
func fit_now() -> void:
	_fit_queued = false
	if not is_inside_tree(): return
	if label.has_theme_font_size_override(&"font_size"): label.remove_theme_font_size_override(&"font_size")
	var base := label.get_theme_font_size(&"font_size")
	var face := plate.get_theme_stylebox(&"panel")
	var room := plate.size.x - (face.get_minimum_size().x if face != null else 0.0)
	if room <= 0.0: return
	label.add_theme_font_size_override(&"font_size",
			GoStyle.fit_font_size(PackedStringArray([atr(text)]), base, room, label.get_theme_font(&"font")))
	_update_dots()


func _queue_fit() -> void:
	if _fit_queued: return
	_fit_queued = true
	fit_now.call_deferred()


## Where dot [param index] stands, in the dots row's space.
func dot_center(index: int) -> Vector2:
	var step := _font_size() * DOT_STEP
	var first := dots.size.x * 0.5 - step * (page_count - 1) * 0.5
	return Vector2(first + step * index, dots.size.y * 0.5)


func _font_size() -> float:
	return float(label.get_theme_font_size(&"font_size")) if label != null else 24.0


func _update_dots() -> void:
	if dots == null: return
	dots.visible = page_count >= 2
	dots.custom_minimum_size = Vector2(_font_size() * DOT_STEP * page_count, _font_size() * DOT_SHARE * 1.4)
	dots.queue_redraw()


func _draw_dots() -> void:
	var colors := GoUi.skin().page_dot_colors()
	var radius := _font_size() * DOT_SHARE * 0.5
	for index in page_count:
		dots.draw_circle(dot_center(index), radius, colors[0] if index == page_index else colors[1], true, -1.0, true)


func _size_keys() -> void:
	add_theme_constant_override(&"separation", roundi(key_size * KEY_GAP_SHARE))
	for key in [previous_button, next_button]:
		if key != null: key.custom_minimum_size = Vector2.ONE * key_size


func _key(back: bool) -> GoGlyphButton:
	var key := GoGlyphButton.make("", GoIconSet.PLAY, VAR_KEY)
	key.name = "Previous" if back else "Next"
	key.glyph_share = KEY_GLYPH_SHARE
	key.glyph_flip_h = back
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return key
