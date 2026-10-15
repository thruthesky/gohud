## 📰 **A notice feed** — a short column of one-line notices that stack, newest at the bottom, fade in and go on their
## own: a match's kill feed ("RED knocked out BLUE"), pickups, joins. The player's own lines stand out.
##
## ```gdscript
## var feed := GoNoticeFeed.new()
## hud.add_child(feed)                               # place it: top centre is usual
## feed.push(tr("KO_BY") % [hitter, target])         # the server said who knocked out whom
## feed.push(tr("KO_BY") % ["YOU", target], true)    # the player's own line
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

## Runs the clock in `_process`. Turn it off to drive it with `advance(delta)`.
@export var auto_advance := true:
	set(value):
		auto_advance = value
		set_process(value)

# The pool, in child order; each entry is {row, label, icon, time, own}.
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
	GoUi.watch(_restyle)


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
	(entry.label as Label).text = text
	var icon := entry.icon as TextureRect
	icon.texture = picture if picture != null else _icon()
	icon.visible = icon.texture != null and icon_size > 0
	entry.time = seconds
	var row := entry.row as Control
	# Out of the tree (built and filled before it is shown) nothing would fade it in yet: it shows at once.
	row.modulate.a = 0.0 if is_inside_tree() and fade_in > 0.0 and not GoUi.config.reduce_motion else 1.0
	move_child(row, get_child_count() - 1)
	row.visible = true
	_showing.append(entry)


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
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.visible = false
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override(&"separation", icon_gap)
		row.add_child(line)
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
		var entry := {row = row, label = label, icon = icon, time = 0.0, own = false}
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
