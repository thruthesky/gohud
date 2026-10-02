## 🔍 **Search bar** — the rounded field at the top of a feed, a shop or a contact list: a search icon, the text, a
## clear button once something is typed, and room for an action or two at the end (a filter, the profile picture).
##
## ```gdscript
## var search := GoSearchBar.make("Search products", func(query: String) -> void: load_results(query))
## search.add_action(GoIconSet.FILTER, &"Filter", open_filters)
## column.add_child(search)
## search.text_changed.connect(func(query: String) -> void: suggest(query))   # live suggestions as you type
## ```
##
## ## 🔑 What it is not
## A search bar is the entry point; a long list of suggestions or results belongs to the page under it (or a
## `GoCombobox` when the choices are a fixed list). The bar never opens a popup of its own.
##
## ## 🔑 The look
## The skin draws the container (`GoSkin.search_bar_box`): each theme's own text field rounded into a pill by default,
## Material's 56dp `surface-container-high` pill under Material. The field inside has no face of its own.
@tool
class_name GoSearchBar
extends PanelContainer

## Enter was pressed (or the keyboard's search key) with this text.
signal submitted(query: String)
## The text changed — for suggestions while typing.
signal text_changed(query: String)

## Height of the bar (dp) — `_md-comp-search-bar.scss` container-height.
const EXTENT := 56.0

## The text field inside the bar.
var field: LineEdit
## The row the trailing action buttons go into.
var actions: HBoxContainer

var _clear: GoIconButton
var _glyph: Control
var _hovered := false
var _action := Callable()


func _init() -> void:
	name = "SearchBar"
	custom_minimum_size.y = EXTENT
	mouse_filter = Control.MOUSE_FILTER_PASS
	GoScroll.scroll_through(self)
	var pad := MarginContainer.new()
	pad.name = "Pad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override(&"margin_left", 16)
	pad.add_theme_constant_override(&"margin_right", 10)
	add_child(pad)
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 0)
	pad.add_child(line)
	var lead := MarginContainer.new()
	lead.name = "Leading"
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lead.add_theme_constant_override(&"margin_right", 16)
	line.add_child(lead)
	field = GoStyle.line_edit()
	field.name = "Field"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.custom_minimum_size.y = 0.0
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	field.select_all_on_focus = false
	line.add_child(field)
	actions = HBoxContainer.new()
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🔑 36dp icon buttons that take presses 48dp wide — 12dp apart, their touch areas meet instead of overlapping.
	actions.add_theme_constant_override(&"separation", 12)
	line.add_child(actions)
	_clear = GoIconButton.new()
	_clear.name = "Clear"
	_clear.icon_name = GoIconSet.CLOSE
	_clear.tooltip_text_name = &"clear"
	_clear.visible = false
	_clear.pressed.connect(func() -> void:
		field.clear()
		_on_text(""))
	actions.add_child(_clear)
	field.text_changed.connect(_on_text)
	field.text_submitted.connect(func(query: String) -> void:
		submitted.emit(query)
		if _action.is_valid(): _action.call(query))
	field.focus_entered.connect(_restyle)
	field.focus_exited.connect(_restyle)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_restyle())
	mouse_exited.connect(func() -> void:
		_hovered = false
		_restyle())
	# Dressed now as well as in `_ready`, so it measures with its own faces as early as it can (see `_ready`).
	theme = GoUi.theme()
	_dress()


func _ready() -> void:
	theme = GoUi.theme()
	_dress()
	# 🛑 Out of the tree the engine measures the field with the project's own font: in laryen3d the bar came out 63–67dp
	#    tall, a size set before `add_child` was stretched to that, and it stayed there once the minimum fell back to
	#    56dp (reported by the layouts session, 2026-10-02). A container lays the bar out again by itself; anywhere
	#    else it goes back to its own height here.
	if not (get_parent() is Container): size.y = get_combined_minimum_size().y
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A search bar showing [param placeholder] while empty — the gohud "Search" text when left empty. [param action] is
## called with the text on Enter. [param translate] treats the placeholder as a translation key.
static func make(placeholder := "", action := Callable(), translate := false) -> GoSearchBar:
	var node := GoSearchBar.new()
	node._action = action
	node.field.placeholder_text = placeholder if not placeholder.is_empty() else GoUi.text(&"search")
	if translate: node.field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	return node


## Adds an icon button at the end of the bar (a filter, a microphone). [param tooltip] is its name for a screen reader.
func add_action(icon: StringName, tooltip: StringName, action := Callable()) -> GoIconButton:
	var button := GoIconButton.new()
	button.icon_name = icon
	button.tooltip_text_name = tooltip
	if action.is_valid(): button.pressed.connect(action)
	actions.add_child(button)
	var peers: Array[Control] = []
	for child in actions.get_children(): peers.append(child)
	for peer in peers: (peer as GoIconButton).touch_peers = peers
	return button


## The text in the bar.
func get_text() -> String:
	return field.text


## Puts [param query] in the bar without emitting `text_changed`.
func set_text(query: String) -> void:
	field.text = query
	_clear.visible = not query.is_empty()


func _on_text(query: String) -> void:
	_clear.visible = not query.is_empty()
	text_changed.emit(query)


## The container's face for the state it is in (rest, hover, typing).
func _restyle() -> void:
	if field == null: return
	var state := &"normal"
	if field.has_focus(): state = &"focus"
	elif _hovered: state = &"hover"
	add_theme_stylebox_override(&"panel", GoUi.skin().search_bar_box(state))


## Everything that follows the look: the face, the bare field, the text size and the search glyph.
func _dress() -> void:
	_restyle()
	# 🔑 The field draws no face of its own — the bar is the field.
	for key in [&"normal", &"focus", &"read_only"]:
		var bare := StyleBoxEmpty.new()
		field.add_theme_stylebox_override(key, bare)
	field.add_theme_font_size_override(&"font_size", GoUi.font_size(GoTheme.ROLE_BODY))
	field.add_theme_color_override(&"font_placeholder_color", GoUi.color(GoTheme.MUTED))
	var lead := field.get_parent().get_node(^"Leading") as MarginContainer
	if is_instance_valid(_glyph): _glyph.queue_free()
	_glyph = GoUi.icons().node(GoIconSet.SEARCH, GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.TEXT))
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lead.add_child(_glyph)


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	field.theme = GoUi.theme()
	_dress()
