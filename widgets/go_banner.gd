## 📣 **A banner** — an important message at the top of a page that stays until it is dealt with: "You're offline —
## Retry", "Your card expires soon — Update" (Flutter's `MaterialBanner`). Unlike a snackbar it does not time out.
##
## ```gdscript
## var offline := GoBanner.make("You're offline. Showing saved posts.", [
## 	{"text": "Dismiss"}, {"text": "Retry", "action": reconnect}], GoIconSet.WARNING)
## page.add_child(offline)            # at the top of the page, above the content
## page.move_child(offline, 0)
## ```
##
## ## 🔑 One or two actions
## Each action is `{"text", "action"}`; pressing one runs it and folds the banner away (`"keep": true` leaves it up).
## With no actions the banner has a close button. A banner that keeps coming back is noise — one per screen.
@tool
class_name GoBanner
extends PanelContainer

## The banner folded away (an action was pressed, or `dismiss()`).
signal closed

var _row: HBoxContainer
var _words: Label
var _actions: HBoxContainer
var _icon := &""


func _init() -> void:
	name = "Banner"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GoScroll.scroll_through(self)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override(&"separation", 16)
	column.add_child(_row)
	_words = GoStyle.label("", GoTheme.ROLE_CAPTION)
	_words.name = "Message"
	_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_words)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.alignment = BoxContainer.ALIGNMENT_END
	_actions.add_theme_constant_override(&"separation", 8)
	column.add_child(_actions)
	# Dressed now as well as in `_ready`, so it measures with gohud's face before it enters the tree (`GoSearchBar`).
	_restyle()


func _ready() -> void:
	_restyle()
	GoUi.watch(_restyle)


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## A banner saying [param message] with [param actions] (`{"text", "action", "keep"}`) and an optional [param icon].
static func make(message: String, actions := [], icon: StringName = &"", translate := false) -> GoBanner:
	var node := GoBanner.new()
	node._words.text = message
	node._words.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	node._icon = icon
	if actions.is_empty():
		var close := GoIconButton.new()
		close.icon_name = GoIconSet.CLOSE
		close.tooltip_text_name = &"close"
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close.pressed.connect(node.dismiss)
		node._row.add_child(close)
		node._actions.visible = false
	for spec: Dictionary in actions:
		var run: Callable = spec.get("action", Callable())
		var keep := bool(spec.get("keep", false))
		var text := str(spec.get("text", ""))
		var button := GoStyle.button_key(text, Callable(), GoStyle.Tone.BARE) if translate \
			else GoStyle.button(text, Callable(), GoStyle.Tone.BARE)
		button.pressed.connect(func() -> void:
			if run.is_valid(): run.call()
			if not keep: node.dismiss())
		node._actions.add_child(button)
	return node


## The message shown.
func message() -> String:
	return _words.text


## Folds the banner away and frees it.
func dismiss() -> void:
	if is_queued_for_deletion(): return
	visible = false
	closed.emit()
	queue_free()


func _restyle() -> void:
	add_theme_stylebox_override(&"panel", GoUi.skin().banner_box())
	_words.add_theme_color_override(&"font_color", GoUi.color(GoTheme.TEXT))
	var old := _row.get_node_or_null(^"Icon")
	if old != null:
		_row.remove_child(old)
		old.queue_free()
	if not _icon.is_empty():
		var glyph := GoUi.icons().node(_icon, GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.ACCENT))
		glyph.name = "Icon"
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(glyph)
		_row.move_child(glyph, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
