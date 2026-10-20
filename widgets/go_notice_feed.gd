## 📰 **A notice feed** — a short column of one-line notices that stack, newest at the bottom, fade in and go on their
## own: a match's kill feed ("RED knocked out BLUE"), pickups, joins. The player's own lines stand out.
##
## ```gdscript
## var feed := GoNoticeFeed.new()
## hud.add_child(feed)                               # place it: top centre is usual
## feed.push(tr("KO_BY") % [hitter, target])         # the server said who knocked out whom
## feed.push(tr("KO_BY") % ["YOU", target], true)    # the player's own line
##
## # A kill feed: [killer] [picture] [victim] — the names in their team colours, long names shrunk to fit.
## feed.max_row_width = 320.0
## feed.row_alignment = HORIZONTAL_ALIGNMENT_RIGHT
## var magnet := GoUi.icons().texture(GoIconSet.MAGNET_ARROW)
## feed.push_versus(hitter, magnet, target, false, Color.RED, Color.BLUE)
## feed.push_versus("", GoUi.icons().texture(GoIconSet.FALL), target)   # fell on their own: [picture] [name]
## ```
##
## Every row is built up front (`max_items` of them) and only filled and shown by `push`, so a burst of notices builds
## no controls; when all are showing, the oldest is reused. Rows use the theme's `GoNotice` / `GoNoticeGold` panels
## when it has them, else `GoSkin.notice_box()`. 🛑 Display only: it shows the lines it is given, in the order given.
@tool
class_name GoNoticeFeed
extends VBoxContainer

## How many rows show at once (built up front).
@export_range(1, 32) var max_items := 4:
	set(value):
		max_items = value
		if is_node_ready(): _build_pool()

## How long a row stays (s).
@export_range(0.1, 60.0) var seconds := 2.0

## How long a row takes to fade in (s). `GoConfig.reduce_motion` shows it at once.
@export_range(0.0, 5.0) var fade_in := 0.2

## The icon at the start of each row — a name in the icon set. Empty shows none.
@export var icon_name := &"skull"

## The icon's side (dp).
@export_range(0, 128) var icon_size := 22

## Room between rows (dp).
@export_range(0, 64) var gap := 6:
	set(value):
		gap = value
		add_theme_constant_override(&"separation", gap)

## Room between the icon and the text (dp).
@export_range(0, 64) var icon_gap := 8

## The row text's size (dp). 0 takes the theme's notice size.
@export_range(0, 128) var font_size := 0:
	set(value):
		font_size = value
		_refit_all()

## 📏 The widest a row may be (dp, panel included). A longer row shrinks its text — both names of a
## [method push_versus] row by one shared scale — until it fits, down to [member fit_min_scale]; the icon keeps its
## size. Short rows stay as wide as their content. 0: no limit.
@export_range(0.0, 4096.0) var max_row_width := 0.0:
	set(value):
		max_row_width = value
		_refit_all()

## The smallest share of the text size [member max_row_width] shrinks to. Negative: `GoUi.config.fit_min_scale`.
## 🛑 Text that still does not fit at the floor runs over the limit.
@export_range(-1.0, 1.0) var fit_min_scale := -1.0:
	set(value):
		fit_min_scale = value
		_refit_all()

## Where rows stand across the feed: left, centre or right (each row is as wide as its content).
@export var row_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER:
	set(value):
		row_alignment = value
		for entry: Dictionary in _pool: (entry.row as Control).size_flags_horizontal = _row_flags()

## 🔔 What a new row says through `GoFeedback` (`GoFeedback.NOTICED`: a small pop, no buzz). Empty: silent.
@export var feedback: StringName = GoFeedback.NOTICED

## Runs the clock in `_process`. Turn it off to drive it with `advance(delta)`.
@export var auto_advance := true:
	set(value):
		auto_advance = value
		set_process(value)

# The pool, in child order; each entry is {row, left, label, icon, time, own}.
var _pool: Array[Dictionary] = []
# The showing entries, oldest first.
var _showing: Array[Dictionary] = []


func _init() -> void:
	name = "NoticeFeed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override(&"separation", gap)


func _ready() -> void:
	theme = GoUi.theme()
	if _pool.is_empty(): _build_pool()
	else: _restyle()
	set_process(auto_advance)


func _enter_tree() -> void:
	GoUi.watch(_restyle)
	if is_node_ready(): _restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## How many rows are showing.
var count: int:
	get:
		return _showing.size()


## The showing rows, oldest first.
func rows() -> Array[Control]:
	var out: Array[Control] = []
	for entry: Dictionary in _showing: out.append(entry.row)
	return out


## Shows [param text] at the bottom — [param own] for the player's own line, [param picture] in place of the icon.
func push(text: String, own := false, picture: Texture2D = null) -> void:
	var entry := _take(own)
	(entry.left as Label).visible = false
	_paint(entry.label as Label, text, Color(0, 0, 0, 0))
	var icon := entry.icon as TextureRect
	icon.texture = picture if picture != null else _icon()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.visible = icon.texture != null and icon_size > 0
	_show(entry)


## ⚔️ Shows a "who did it to whom" row at the bottom: [param left] [param picture] [param right] — a kill feed's
## killer, how, and victim. An empty [param left] leaves only [param picture] [param right] (fell on their own).
## A colour with alpha 0 keeps the theme's text colour; any other colours that name. [param own] as in [method push].
## A wide picture keeps its shape: [member icon_size] high, as wide as it needs.
func push_versus(left: String, picture: Texture2D, right: String, own := false, left_color := Color(0, 0, 0, 0),
		right_color := Color(0, 0, 0, 0)) -> void:
	var entry := _take(own)
	var left_label := entry.left as Label
	left_label.visible = not left.is_empty()
	_paint(left_label, left, left_color)
	_paint(entry.label as Label, right, right_color)
	var icon := entry.icon as TextureRect
	icon.texture = picture if picture != null else _icon()
	var aspect := 1.0
	if icon.texture != null and icon.texture.get_height() > 0:
		aspect = maxf(1.0, float(icon.texture.get_width()) / icon.texture.get_height())
	icon.custom_minimum_size = Vector2(roundf(icon_size * aspect), icon_size)
	icon.visible = icon.texture != null and icon_size > 0
	_show(entry)


# A free row, or the oldest showing one, styled for [param own].
func _take(own: bool) -> Dictionary:
	if _pool.is_empty(): _build_pool()
	var entry: Dictionary = {}
	for candidate: Dictionary in _pool:
		if not (candidate.row as Control).visible:
			entry = candidate
			break
	if entry.is_empty():
		entry = _showing.pop_front()
	entry.own = own
	_style_row(entry)
	return entry


func _paint(label: Label, text: String, color: Color) -> void:
	label.text = text
	if color.a > 0.0: label.add_theme_color_override(&"font_color", color)
	else: label.remove_theme_color_override(&"font_color")


# Fits, times and shows a filled row as the newest.
func _show(entry: Dictionary) -> void:
	_fit(entry)
	entry.time = seconds
	var row := entry.row as Control
	# Out of the tree (built and filled before it is shown) nothing would fade it in yet: it shows at once.
	row.modulate.a = 0.0 if is_inside_tree() and fade_in > 0.0 and not GoUi.config.reduce_motion else 1.0
	move_child(row, get_child_count() - 1)
	row.visible = true
	_showing.append(entry)
	if not Engine.is_editor_hint(): GoFeedback.play(feedback)


## Moves the clock on [param delta] seconds: fades rows in and hides the ones whose time is up.
func advance(delta: float) -> void:
	for index in range(_showing.size() - 1, -1, -1):
		var entry: Dictionary = _showing[index]
		entry.time -= delta
		var row := entry.row as Control
		if entry.time <= 0.0:
			row.visible = false
			_showing.remove_at(index)
		elif row.modulate.a < 1.0:
			row.modulate.a = minf(1.0, (seconds - entry.time) / fade_in) if fade_in > 0.0 else 1.0


## Hides every row (they stay built).
func clear() -> void:
	for entry: Dictionary in _showing: (entry.row as Control).visible = false
	_showing.clear()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint(): advance(delta)


func _icon() -> Texture2D:
	if icon_name.is_empty(): return null
	var icons := GoUi.icons()
	return icons.texture(icon_name) if icons != null and icons.has_icon(icon_name) else null


func _build_pool() -> void:
	clear()
	for entry: Dictionary in _pool: (entry.row as Node).free()
	_pool.clear()
	for index in max_items:
		var row := PanelContainer.new()
		row.name = "Row%d" % index
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = _row_flags()
		row.visible = false
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override(&"separation", icon_gap)
		row.add_child(line)
		var left := Label.new()
		left.name = "Left"
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		left.visible = false
		line.add_child(left)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		line.add_child(icon)
		var label := Label.new()
		label.name = "Text"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		line.add_child(label)
		add_child(row)
		var entry := {row = row, left = left, label = label, icon = icon, time = 0.0, own = false}
		_style_row(entry)
		_pool.append(entry)


func _style_row(entry: Dictionary) -> void:
	var row := entry.row as PanelContainer
	var variation := &"GoNoticeGold" if entry.own else &"GoNotice"
	var themed := GoUi.theme()
	if themed != null and themed.has_stylebox(&"panel", variation):
		row.remove_theme_stylebox_override(&"panel")
		if row.theme_type_variation != variation: row.theme_type_variation = variation
	else:
		row.theme_type_variation = &""
		var accent := GoUi.color(GoTheme.WARNING) if entry.own else Color.TRANSPARENT
		row.add_theme_stylebox_override(&"panel", GoUi.skin().notice_box(accent, true, -1.0))


func _restyle() -> void:
	theme = GoUi.theme()
	for entry: Dictionary in _pool: _style_row(entry)
	_refit_all()


func _row_flags() -> int:
	match row_alignment:
		HORIZONTAL_ALIGNMENT_LEFT: return Control.SIZE_SHRINK_BEGIN
		HORIZONTAL_ALIGNMENT_RIGHT: return Control.SIZE_SHRINK_END
	return Control.SIZE_SHRINK_CENTER


func _refit_all() -> void:
	for entry: Dictionary in _showing: _fit(entry)


# The row's text size: font_size (or the theme's), shrunk with one shared scale while the row is wider than
# max_row_width, never under the fit_min_scale floor. Measured from the labels themselves, so it matches the layout.
func _fit(entry: Dictionary) -> void:
	var left := entry.left as Label
	var right := entry.label as Label
	var labels: Array[Label] = [right]
	if left.visible: labels.push_front(left)
	left.remove_theme_font_size_override(&"font_size")
	right.remove_theme_font_size_override(&"font_size")
	var base := font_size if font_size > 0 else right.get_theme_font_size(&"font_size")
	if font_size > 0 or max_row_width > 0.0: _set_text_size(entry, base)
	if max_row_width <= 0.0: return
	var texts := PackedStringArray()
	for label: Label in labels: texts.append(label.text)
	var face := right.get_theme_font(&"font")
	var fixed := _row_width(entry, labels) - GoStyle.row_width(face, texts, base)
	# 0 is a real floor here (as small as it gets); only a negative value means the config's.
	var floor_scale := fit_min_scale if fit_min_scale < 0.0 else maxf(fit_min_scale, 0.0001)
	var floor_size := GoStyle.fit_floor(base, floor_scale)
	# A first guess from the font, then the labels' own measure decides.
	var size := GoStyle.fit_font_size(texts, base, max_row_width - fixed, face, floor_scale)
	_set_text_size(entry, size)
	while size > floor_size and _row_width(entry, labels) > max_row_width:
		size -= 1
		_set_text_size(entry, size)


func _set_text_size(entry: Dictionary, size: int) -> void:
	(entry.left as Label).add_theme_font_size_override(&"font_size", size)
	(entry.label as Label).add_theme_font_size_override(&"font_size", size)


# How wide a row lays out: the panel's margins, the shown labels and icon, the gaps between them.
func _row_width(entry: Dictionary, labels: Array[Label]) -> float:
	var parts := 0
	var width := 0.0
	for label: Label in labels:
		width += label.get_minimum_size().x
		parts += 1
	var icon := entry.icon as TextureRect
	if icon.visible:
		width += icon.custom_minimum_size.x
		parts += 1
	width += icon_gap * maxi(0, parts - 1)
	var box := (entry.row as PanelContainer).get_theme_stylebox(&"panel")
	if box != null: width += box.get_minimum_size().x
	return width
