## 🎚️ **A slider drawn the painted way** — an HSlider whose fill runs a little past the handle's centre and whose
## handle grows while it is held, the way Magnet Mayhem's settings sliders draw. Values, steps, signals, keys and the
## touch behaviour are the stock HSlider's; only the drawing is replaced.
##
## The parts are the theme's own HSlider parts — the `slider` track, the `grabber_area` fill and the `grabber` handle
## — so a `theme_type_variation` picks the fill (`GoSliderGreen`, `GoSliderCyan` on arcade_light) and every preset
## draws its own look.
##
## ```gdscript
## var music := GoSlider.make(0.0, 1.0, 0.01)
## music.theme_type_variation = &"GoSliderGreen"
## music.value_changed.connect(func(v: float) -> void: Audio.set_music(v))
## ```
##
## ## 🔑 How it draws
## - The track is as tall as the theme's `slider` box asks (16 on arcade_light), centred, the whole width.
## - The handle's edge touches each end at the minimum and the maximum, as the engine maps a press to a value.
## - The fill ends `FILL_PAST` past the handle's centre, and is never shorter than the track is tall (no sliver at
##   the minimum).
## - A held handle is drawn `HELD_SCALE` larger about its centre. A disabled one uses `grabber_disabled`.
##
## The engine's own drawing is blanked with overrides (a see-through grabber as wide as the handle, so a press still
## maps to the value under the finger); the theme's parts are read again whenever the theme or variation changes.
@tool
class_name GoSlider
extends HSlider

## How far the fill runs past the handle's centre, so no gap shows at the handle's rim.
const FILL_PAST := 2.0
## How much larger the handle is drawn while it is held.
const HELD_SCALE := 1.12
## The least width: room for the handle to travel.
const MIN_WIDTH := 120.0

const _ICONS: Array[StringName] = [&"grabber", &"grabber_highlight", &"grabber_disabled"]
const _BOXES: Array[StringName] = [&"slider", &"grabber_area", &"grabber_area_highlight"]

## The theme's parts, read before the blanks went on: StyleBox for the boxes, Texture2D for the icons.
var _parts: Dictionary[StringName, Resource] = {}
var _held := false
var _hovered := false
var _reading := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## A slider from [param minimum] to [param maximum] snapping to [param snap].
static func make(minimum := 0.0, maximum := 1.0, snap := 0.01) -> GoSlider:
	var slider := GoSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = snap
	return slider


func _ready() -> void:
	_read_parts()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## The theme's part [param item] as it draws it (`slider`, `grabber_area`, `grabber_area_highlight`, `grabber`,
## `grabber_highlight`, `grabber_disabled`), or null when the look has none.
func part(item: StringName) -> Resource:
	return _parts.get(item)


## The handle's size, from the theme's grabber (16 × 16 when the look has none).
func handle_size() -> Vector2:
	var grab := part(&"grabber") as Texture2D
	return grab.get_size() if grab != null else Vector2(16.0, 16.0)


## X of the handle's centre: its edge touches each end of the control at the minimum and the maximum.
func handle_center_x() -> float:
	var side := handle_size().x
	return side * 0.5 + get_as_ratio() * maxf(0.0, size.x - side)


## Where the track is drawn: the whole width, as tall as the theme's `slider` box asks, centred.
func bar_rect() -> Rect2:
	var track := part(&"slider") as StyleBox
	var height := maxf(track.get_minimum_size().y if track != null else 4.0, 2.0)
	return Rect2(0.0, (size.y - height) * 0.5, size.x, height)


## Where the fill is drawn: from the start to `FILL_PAST` past the handle's centre, at least a track's height long.
func fill_rect() -> Rect2:
	var bar := bar_rect()
	var reach := maxf(handle_center_x() + FILL_PAST, bar.size.y)
	return Rect2(bar.position, Vector2(minf(reach, size.x), bar.size.y))


## Where the handle is drawn: centred on the track, `HELD_SCALE` larger while held.
func handle_rect() -> Rect2:
	var side := handle_size() * (HELD_SCALE if _held else 1.0)
	return Rect2(Vector2(handle_center_x(), size.y * 0.5) - side * 0.5, side)


func _get_minimum_size() -> Vector2:
	var side := handle_size()
	return Vector2(maxf(MIN_WIDTH, side.x * 3.0), maxf(float(GoUi.metric(GoTheme.TOUCH)), side.y))


## Reads the theme's parts with the blanks off, then puts the blanks back on (the engine draws nothing itself).
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
	for item in _BOXES:
		if has_theme_stylebox(item): _parts[item] = get_theme_stylebox(item)
	var side := handle_size()
	var blank := ImageTexture.create_from_image(
		Image.create_empty(maxi(int(side.x), 1), 1, false, Image.FORMAT_RGBA8))
	begin_bulk_theme_override()
	for item in _ICONS: add_theme_icon_override(item, blank)
	for item in _BOXES: add_theme_stylebox_override(item, StyleBoxEmpty.new())
	end_bulk_theme_override()
	_reading = false
	update_minimum_size()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		_held = press.pressed and editable
		queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			if is_inside_tree(): _read_parts()
		NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT:
			_hovered = what == NOTIFICATION_MOUSE_ENTER
			queue_redraw()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_RESIZED:
			queue_redraw()


func _draw() -> void:
	var track := part(&"slider") as StyleBox
	if track != null: draw_style_box(track, bar_rect())
	var lit := has_focus() or _held
	var fill := part(&"grabber_area_highlight" if lit else &"grabber_area") as StyleBox
	if fill == null: fill = part(&"grabber_area") as StyleBox
	if fill != null: draw_style_box(fill, fill_rect())
	var state := &"grabber_disabled" if not editable else (&"grabber_highlight" if lit or _hovered else &"grabber")
	var grab := part(state) as Texture2D
	if grab == null: grab = part(&"grabber") as Texture2D
	var at := handle_rect()
	if grab != null: draw_texture_rect(grab, at, false)
	else: draw_circle(at.get_center(), at.size.x * 0.5, GoUi.color(GoTheme.ACCENT), true, -1.0, true)


func _on_ui_changed() -> void:
	_read_parts()
