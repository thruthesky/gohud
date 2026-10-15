## 🔘 **An on/off switch drawn the painted way** — a CheckButton whose pill stands centred in its box and carries a
## caption ("ON" / "OFF") in the half the knob is not on, the way Magnet Mayhem's settings switches draw. Toggling,
## `button_pressed`, `toggled` and the touch target are the stock CheckButton's; only the drawing is replaced.
##
## The pills are the theme's own CheckButton icons (`checked`, `unchecked` and their `_disabled` and `_mirrored`
## forms), so every preset draws its own switch.
##
## ```gdscript
## var vibration := GoSwitch.make(true)
## vibration.set_texts(tr("ON"), tr("OFF"))
## vibration.toggled.connect(func(on: bool) -> void: Settings.vibration = on)
## ```
##
## ## 🔑 How it draws
## - With no `text` the pill stands centred in the box, on whole pixels. With a `text` the label is the engine's and the
##   pill stands where the engine puts the check icon (the far end; the near end in RTL).
## - The caption sits in the pill's free part — left of the knob when on, right of it when off — centred in
##   `caption_room()` (the pill less `KNOB_SHARE` of its height and two `TEXT_EDGE`s). It is white with a `TEXT_OUTLINE`
##   outline in the CheckButton's `font_color` (the ink on arcade_light).
## - `set_texts()` shrinks the caption (`GoStyle.fit_font_size`, never under `GoConfig.fit_min_scale`) so both fit.
##
## The engine's own drawing is blanked with overrides (see-through icons as wide as the pill, empty boxes), so the
## layout and the press area stay the engine's; the theme's pills are read again when the theme or variation changes.
@tool
class_name GoSwitch
extends CheckButton

## The caption's font size before it is shrunk to fit.
const TEXT_SIZE := 12
## The knob takes this share of the pill's height; the caption has the rest.
const KNOB_SHARE := 0.86
## The caption's distance from the pill's end and from the knob.
const TEXT_EDGE := 9.0
## The caption's outline width.
const TEXT_OUTLINE := 3
## The room round the pill in the least width.
const SIDE_ROOM := 8.0

const _ICONS: Array[StringName] = [&"checked", &"unchecked", &"checked_disabled", &"unchecked_disabled",
	&"checked_mirrored", &"unchecked_mirrored", &"checked_disabled_mirrored", &"unchecked_disabled_mirrored"]
const _BOXES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]

## The caption while on.
@export var on_text := "":
	set(value):
		on_text = value
		queue_redraw()
## The caption while off.
@export var off_text := "":
	set(value):
		off_text = value
		queue_redraw()

## The theme's pills, read before the blanks went on.
var _parts: Dictionary[StringName, Texture2D] = {}
var _reading := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	# The engine's CheckButton measures its least size from the blanks (1 px tall), so the floor is the custom minimum —
	# set here, as the game's PaintedSwitch does, so a screen that sets its own still wins.
	custom_minimum_size = Vector2(0.0, float(GoUi.metric(GoTheme.TOUCH)))


## A switch, on or off.
static func make(on := false) -> GoSwitch:
	var flip := GoSwitch.new()
	flip.button_pressed = on
	return flip


func _ready() -> void:
	_read_parts()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Sets both captions; the font shrinks (never under `GoConfig.fit_min_scale`) so the longer one fits.
func set_texts(on: String, off: String) -> void:
	on_text = on
	off_text = off


## The theme's pill [param item] (`checked`, `unchecked_disabled`, …), or null when the look has none.
func part(item: StringName) -> Texture2D:
	return _parts.get(item)


## The pill drawn now: on or off, disabled, mirrored in RTL — each falling back to the plain on or off pill.
func pill_texture() -> Texture2D:
	var item := "checked" if button_pressed else "unchecked"
	var names: Array[String] = []
	if disabled and is_layout_rtl(): names.append(item + "_disabled_mirrored")
	if disabled: names.append(item + "_disabled")
	if is_layout_rtl(): names.append(item + "_mirrored")
	names.append(item)
	for name_it in names:
		var found := part(StringName(name_it))
		if found != null: return found
	return null


## The pill's size, from the theme's `unchecked` icon.
func pill_size() -> Vector2:
	var pill := part(&"unchecked")
	if pill == null: pill = part(&"checked")
	return pill.get_size() if pill != null else Vector2(40.0, 20.0)


## Where the pill is drawn: centred with no label, where the engine puts the check icon with one.
func switch_rect() -> Rect2:
	var pill := pill_size()
	if text.is_empty():
		return Rect2(((size - pill) * 0.5).floor(), pill)
	var x := 0.0 if is_layout_rtl() else size.x - pill.x
	return Rect2(Vector2(x, (size.y - pill.y) * 0.5), pill)


## The caption shown now (`on_text` or `off_text`).
func caption() -> String:
	return on_text if button_pressed else off_text


## The width the caption has: the pill less the knob and an edge on each side.
func caption_room() -> float:
	var pill := pill_size()
	return pill.x - pill.y * KNOB_SHARE - 2.0 * TEXT_EDGE


## The caption's font size: `TEXT_SIZE`, shrunk so both captions fit `caption_room()`.
func caption_font_size() -> int:
	var font := _font()
	var room := caption_room()
	var fitted := TEXT_SIZE
	for words in [on_text, off_text]:
		if not words.is_empty():
			fitted = mini(fitted, GoStyle.fit_font_size(PackedStringArray([words]), TEXT_SIZE, room, font))
	return fitted


## How wide the caption shown now is drawn.
func caption_width() -> float:
	return _font().get_string_size(caption(), HORIZONTAL_ALIGNMENT_LEFT, -1, caption_font_size()).x


## The caption's baseline start: centred in the part of the pill the knob is not on.
func caption_position() -> Vector2:
	var at := switch_rect()
	var size_now := caption_font_size()
	var left := at.position.x + TEXT_EDGE
	if not button_pressed: left += at.size.y * KNOB_SHARE
	return Vector2(left + (caption_room() - caption_width()) * 0.5, at.position.y + at.size.y * 0.5 + size_now * 0.36)


func _font() -> Font:
	return get_theme_font(&"font")


## Reads the theme's pills with the blanks off, then puts see-through spacers as wide as the pill back on.
func _read_parts() -> void:
	if _reading: return
	_reading = true
	begin_bulk_theme_override()
	for item in _ICONS: remove_theme_icon_override(item)
	for item in _BOXES: remove_theme_stylebox_override(item)
	end_bulk_theme_override()
	_parts.clear()
	for item in _ICONS:
		if has_theme_icon(item): _parts[item] = get_theme_icon(item)
	var blank := ImageTexture.create_from_image(
		Image.create_empty(maxi(int(pill_size().x), 1), 1, false, Image.FORMAT_RGBA8))
	begin_bulk_theme_override()
	for item in _ICONS: add_theme_icon_override(item, blank)
	for item in _BOXES: add_theme_stylebox_override(item, StyleBoxEmpty.new())
	end_bulk_theme_override()
	_reading = false
	# Room for the pill and a little round it (the height floor is set once, in _init).
	custom_minimum_size.x = maxf(custom_minimum_size.x, pill_size().x + SIDE_ROOM)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
		_read_parts()


func _draw() -> void:
	var pill := pill_texture()
	if pill != null: draw_texture_rect(pill, switch_rect(), false)
	var words := caption()
	if words.is_empty() or caption_room() <= 0.0: return
	var font := _font()
	var font_size := caption_font_size()
	var at := caption_position()
	var ink := get_theme_color(&"font_color")
	var fill := Color.WHITE
	if ink.get_luminance() > 0.5:
		# A dark look's light text colour: it fills the caption, and the page's colour rims it.
		fill = ink
		ink = GoUi.color(GoTheme.BACKGROUND)
	draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_OUTLINE, Color(ink, 1.0))
	draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)


func _on_ui_changed() -> void:
	_read_parts()
