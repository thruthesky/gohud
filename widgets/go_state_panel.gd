## 🪧 **A state panel** — the big pale card a board shows instead of its rows: nothing yet ("No times yet — be the
## first!" over a stopwatch, with a PLAY button), an error ("Can't reach the server" with TRY AGAIN), or loading (a
## ring of blue dashes turning, "LOADING..."). An optional blue header strip (icon, title, a pill on the right) makes
## it a whole window, as the weekly board's.
##
## ```gdscript
## var empty := GoStatePanel.new()
## empty.illustration = GoUi.skin().widget_art(&"illus_stopwatch")
## empty.heading = tr("NO TIMES YET")
## empty.body = tr("Be the first to set a time on this stage!")
## empty.button_text = tr("PLAY")
## empty.button_pressed.connect(_play)
##
## var error := GoStatePanel.new()
## error.heading = tr("CAN'T CONNECT")
## error.button_text = tr("TRY AGAIN")
## error.button_variation = &"GoPillBlue"
## error.button_glyph = &""                  # no glyph: the words alone
## error.loading = true                       # while asking again: the ring instead of the picture
## ```
##
## The card is the theme's `GoStatePanel`, the header `GoStateHeader` (its title a `GoBoardTitle` label, its pill a
## `GoBoardPill`), the heading `GoStateHeading`, the body `GoStateBody`, the button a `GoGlyphButton` in
## [member button_variation] (`GoPillGreen` by default). The ring's colour is the skin's `loading_ring_color()`.
## 🛑 The panel shows what it is told: the caller decides which state the board is in (from what the server answered).
## 🔤 Heading, header title and button shrink to fit (`GoStyle.fit_font_size`, never under `GoConfig.fit_min_scale`);
##    the body wraps.
## 🔑 Loading hides the button: there is nothing to press while waiting. With `GoUi.config.reduce_motion` the ring
##    stands still.
@tool
class_name GoStatePanel
extends PanelContainer

## The button was pressed (PLAY, TRY AGAIN…).
signal button_pressed

const VAR_PANEL := &"GoStatePanel"
const VAR_HEADER := &"GoStateHeader"
const VAR_HEADING := &"GoStateHeading"
const VAR_BODY := &"GoStateBody"
const VAR_TITLE := &"GoBoardTitle"
const VAR_PILL := &"GoBoardPill"
const VAR_PILL_LABEL := &"GoBoardPillLabel"
## The heading's size while loading, as a share of its size otherwise ("LOADING..." is a caption, not a headline).
const LOADING_HEADING_SHARE := 0.6
## The header title's size as a share of the board title's, and the header icon's height as a share of the title's.
const HEADER_TITLE_SHARE := 0.75
const HEADER_ICON_SHARE := 1.2
## The button's words as a share of its height (they shrink from there to fit).
const BUTTON_FONT_SHARE := 0.42

## The picture in the middle. Null: none (the heading moves up).
@export var illustration: Texture2D:
	set(value):
		illustration = value
		_sync()

## The big words under the picture.
@export var heading := "":
	set(value):
		heading = value
		_sync()

## The heading's look: `GoStateHeading` (navy) or `GoBoardTitle` (white in a thick ink outline, as on the weekly
## board).
@export var heading_variation: StringName = VAR_HEADING:
	set(value):
		heading_variation = value
		_sync()

## The line under the heading. Empty: none.
@export var body := "":
	set(value):
		body = value
		_sync()

## The button's words. Empty: no button.
@export var button_text := "":
	set(value):
		button_text = value
		_sync()

## The button's look (`GoPillGreen`, `GoPillBlue`, `GoPillRed`: the gloss pills in bold outlined words; any button
## variation works).
@export var button_variation: StringName = &"GoPillGreen":
	set(value):
		button_variation = value
		_sync()

## The icon-set glyph before the button's words (`GoIconSet.PLAY`…). Empty: words alone.
@export var button_glyph: StringName = GoIconSet.PLAY:
	set(value):
		button_glyph = value
		_sync()

## Waiting: the turning ring instead of the picture, and no button.
@export var loading := false:
	set(value):
		loading = value
		_sync()

## The picture's (and the ring's) height, dp.
@export var illustration_size := 260.0:
	set(value):
		illustration_size = value
		_sync()

## The button's size, dp.
@export var button_size := Vector2(300, 96):
	set(value):
		button_size = value
		_sync()

## The space between the card's rim and its content, dp.
@export var padding := 32.0:
	set(value):
		padding = value
		_sync()

var header: PanelContainer
var header_icon: TextureRect
var header_title: Label
var header_pill: PanelContainer
var header_pill_icon: TextureRect
var header_pill_label: Label
var picture: TextureRect
var ring: Ring
var heading_label: Label
var body_label: Label
var button: GoGlyphButton
var _content: MarginContainer
var _fit_queued := false


## 🌀 The loading ring: [constant DASHES] rounded dashes round a circle, the lead one solid and the rest fading,
## stepping round [constant STEPS_PER_SECOND] times a second.
class Ring extends Control:
	const DASHES := 12
	const STEPS_PER_SECOND := 12.0
	## The dash's length and width as shares of the ring's radius; where it starts (share of the radius).
	const DASH_LENGTH := 0.42
	const DASH_WIDTH := 0.17
	const DASH_INNER := 0.52
	## The faintest dash's opacity.
	const TAIL_ALPHA := 0.18
	var lead := 0
	var _clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visibility_changed.connect(_sync_process)

	func _enter_tree() -> void:
		_sync_process()

	func _sync_process() -> void:
		set_process(is_visible_in_tree() and not Engine.is_editor_hint())

	func _process(delta: float) -> void:
		if GoUi.config.reduce_motion: return
		_clock += delta
		var step := int(_clock * STEPS_PER_SECOND) % DASHES
		if step != lead:
			lead = step
			queue_redraw()

	func _draw() -> void:
		var radius := minf(size.x, size.y) * 0.5
		var centre := size * 0.5
		var colour := GoUi.skin().loading_ring_color()
		var width := radius * DASH_WIDTH
		for index in DASHES:
			var age := posmod(lead - index, DASHES)
			var angle := TAU * index / DASHES - PI * 0.5
			var way := Vector2.from_angle(angle)
			var tint := colour
			tint.a *= lerpf(1.0, TAIL_ALPHA, float(age) / (DASHES - 1))
			var inner := centre + way * (radius * DASH_INNER + width * 0.5)
			var outer := centre + way * (radius * (DASH_INNER + DASH_LENGTH) - width * 0.5)
			# One capsule polygon per dash: a see-through dash built of overlapping parts would darken where they meet.
			draw_colored_polygon(_capsule(inner, outer, width * 0.5), tint)

	static func _capsule(from: Vector2, to: Vector2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var angle := (to - from).angle()
		const ARC := 8
		for step in ARC + 1:
			points.append(to + Vector2.from_angle(angle - PI * 0.5 + PI * step / ARC) * radius)
		for step in ARC + 1:
			points.append(from + Vector2.from_angle(angle + PI * 0.5 + PI * step / ARC) * radius)
		return points


func _init() -> void:
	theme_type_variation = VAR_PANEL
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	header = _make_header()
	column.add_child(header)
	_content = MarginContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_content)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(stack)
	picture = TextureRect.new()
	picture.name = "Illustration"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(picture)
	ring = Ring.new()
	ring.name = "Ring"
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(ring)
	heading_label = _label("Heading", VAR_HEADING)
	stack.add_child(heading_label)
	body_label = _label("Body", VAR_BODY)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body_label)
	button = GoGlyphButton.new()
	button.name = "Button"
	button.fit_label = true
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(button_pressed.emit)
	var room := Control.new()
	room.name = "ButtonGap"
	room.custom_minimum_size.y = 12
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(room)
	stack.add_child(button)
	_sync()


## 🗂 Shows the blue header strip: [param icon] (null: none) and [param title] on the left, a navy pill with the
## skin's clock (`icon_clock`) and [param pill_text] on the right (empty: no pill).
func set_header(icon: Texture2D, title: String, pill_text: String) -> void:
	header_icon.texture = icon
	header_icon.visible = icon != null
	header_title.text = title
	header_pill_label.text = pill_text
	header_pill.visible = not pill_text.is_empty()
	header_pill_icon.texture = GoUi.skin().widget_art(&"icon_clock")
	header_pill_icon.visible = header_pill_icon.texture != null
	header.visible = true
	_queue_fit()


## Hides the header strip again.
func clear_header() -> void:
	header.visible = false


func _enter_tree() -> void:
	GoUi.watch(_queue_fit)
	_queue_fit()


func _exit_tree() -> void:
	GoUi.unwatch(_queue_fit)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_THEME_CHANGED: _queue_fit()


func _sync() -> void:
	if picture == null: return
	picture.texture = illustration
	picture.visible = not loading and illustration != null
	picture.custom_minimum_size = Vector2(0, illustration_size)
	ring.visible = loading
	ring.custom_minimum_size = Vector2.ONE * illustration_size * 0.62
	heading_label.text = heading
	heading_label.theme_type_variation = heading_variation
	heading_label.visible = not heading.is_empty()
	body_label.text = body
	body_label.visible = not body.is_empty()
	button.text = button_text
	button.theme_type_variation = button_variation
	button.glyph_icon = button_glyph
	button.custom_minimum_size = button_size
	button.fit_base_size = int(button_size.y * BUTTON_FONT_SHARE)
	button.visible = not loading and not button_text.is_empty()
	button.get_parent().get_child(button.get_index() - 1).visible = button.visible
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_content.add_theme_constant_override(side, int(padding))
	_queue_fit()


func _queue_fit() -> void:
	if _fit_queued: return
	_fit_queued = true
	fit_now.call_deferred()


## Fits the heading and the header now instead of at the end of the frame.
func fit_now() -> void:
	_fit_queued = false
	if not is_inside_tree() or size.x <= 0.0: return
	var face := get_theme_stylebox(&"panel")
	var inner := size.x - (face.get_minimum_size().x if face != null else 0.0)
	var base := float(_base_size(heading_label)) * (LOADING_HEADING_SHARE if loading else 1.0)
	_fit_to(heading_label, int(base), inner - padding * 2.0)
	if not header.visible: return
	var title_base := int(_base_size(header_title) * HEADER_TITLE_SHARE)
	var strip := header.get_theme_stylebox(&"panel")
	var room := inner - (strip.get_minimum_size().x if strip != null else 0.0)
	if header_icon.visible: room -= title_base * (HEADER_ICON_SHARE + 0.2)
	if header_pill.visible: room -= header_pill.get_combined_minimum_size().x + 16
	_fit_to(header_title, title_base, room)
	header_icon.custom_minimum_size = Vector2.ONE * header_title.get_theme_font_size(&"font_size") * HEADER_ICON_SHARE
	var pill_size := header_pill_label.get_theme_font_size(&"font_size")
	header_pill_icon.custom_minimum_size = Vector2.ONE * pill_size * 1.1


func _base_size(label: Label) -> int:
	if label.has_theme_font_size_override(&"font_size"): label.remove_theme_font_size_override(&"font_size")
	return label.get_theme_font_size(&"font_size")


func _fit_to(label: Label, base: int, room: float) -> void:
	_base_size(label)
	if room <= 0.0 or label.text.is_empty():
		label.add_theme_font_size_override(&"font_size", base)
		return
	var lines := PackedStringArray([atr(label.text)])
	label.add_theme_font_size_override(&"font_size",
			GoStyle.fit_font_size(lines, base, room, label.get_theme_font(&"font")))


func _label(id: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = id
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_header() -> PanelContainer:
	var strip := PanelContainer.new()
	strip.name = "Header"
	strip.theme_type_variation = VAR_HEADER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	header_icon = TextureRect.new()
	header_icon.name = "Icon"
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_icon.visible = false
	row.add_child(header_icon)
	header_title = Label.new()
	header_title.name = "Title"
	header_title.theme_type_variation = VAR_TITLE
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(header_title)
	header_pill = PanelContainer.new()
	header_pill.name = "Pill"
	header_pill.theme_type_variation = VAR_PILL
	header_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(header_pill)
	var pill_row := HBoxContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_pill.add_child(pill_row)
	header_pill_icon = TextureRect.new()
	header_pill_icon.name = "PillIcon"
	header_pill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_pill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_pill_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_pill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(header_pill_icon)
	header_pill_label = Label.new()
	header_pill_label.name = "PillLabel"
	header_pill_label.theme_type_variation = VAR_PILL_LABEL
	header_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(header_pill_label)
	return strip
