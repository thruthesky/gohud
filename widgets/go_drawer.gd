## 📂 **A drawer that slides in from the side** — the bag, friend list or chat on a tablet or PC landscape screen.
##
## ```gdscript
## var bag := GoDrawer.new()
## add_child(bag)
## bag.open("Bag")
## bag.body.add_child(inventory_grid)
##
## bag.side = GoDrawer.Side.RIGHT     # from the right
## ```
##
## ## 🔑 How it differs from `GoSheet`
## `GoSheet` rises **from the bottom** — close to the thumb on a phone in portrait, using the full width.
## A drawer comes **from the side** — on a wide screen it opens a list without covering the whole game view.
## On a phone in portrait a drawer covers almost the entire screen, so a sheet is the better choice there.
##
## ## 🛑 The side is a screen side, not a text side
## `LEFT` is the left of the screen in Arabic too. To follow the text direction, turn on `follow_text_direction` —
## that flips it in RTL (for places where "the start side" carries meaning, such as a menu drawer).
##
## ## 🛑 It does not intrude on the safe area
## On a device with a notch or rounded corners, a drawer that runs to the screen edge has its content clipped
## at the corners. The background fills all the way out, but **the content stays inside the safe area**.
@tool
class_name GoDrawer
extends CanvasLayer

## It closed.
signal closed
## It opened.
signal opened

enum Side {
	LEFT,   ## From the left of the screen
	RIGHT,  ## From the right of the screen
}

## Which side it comes in from.
@export var side := Side.LEFT:
	set(value):
		side = value
		_relayout()

## Whether to flip sides with the text direction (RTL). 🔑 Turn it on where "the start side" carries meaning, such as a menu drawer.
@export var follow_text_direction := false:
	set(value):
		follow_text_direction = value
		_relayout()

## Fraction of the screen **width** it takes up. On a narrow screen `max_width` binds first.
@export_range(0.2, 1.0, 0.01) var width_ratio := 0.42:
	set(value):
		width_ratio = value
		_relayout()

## Maximum width (dp). Keeps the drawer from growing without limit on a wide monitor.
@export var max_width := 420.0:
	set(value):
		max_width = value
		_relayout()

## 🪟 **Opacity** of the drawer panel's ground (0.0~1.0). **Negative uses the card value the theme and settings decide** (default).
## 🛑 Only the ground thins out — text, icons and buttons stay crisp.
@export_range(-1.0, 1.0, 0.01) var alpha := -1.0:
	set(value):
		alpha = value
		if panel != null: _restyle()

## Whether tapping outside (the scrim) closes it.
@export var dismissable := true

## How long the slide-in takes (seconds). Ignored under `reduce_motion`.
@export var motion_seconds := 0.2

## The body (scrolls).
var body: VBoxContainer
## The header row.
var header: HBoxContainer
## The title.
var title_label: Label
## The panel being wrapped — reach for it directly when you need fine control.
var panel: PanelContainer

var _scrim: ColorRect
var _root: Control
var _scroll: GoScroll
var _tween: Tween
var _open := false


func _init() -> void:
	layer = 80
	visible = false

	_root = Control.new()
	_root.name = "DrawerRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_scrim_input)
	_root.add_child(_scrim)

	panel = PanelContainer.new()
	panel.name = "Drawer"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var pad := GoStyle.padding()
	panel.add_child(pad)
	var column := GoStyle.column()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(column)

	header = GoStyle.row()
	header.name = "Header"
	column.add_child(header)
	title_label = GoStyle.label("", GoTheme.ROLE_TITLE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button := GoIconButton.new()
	close_button.icon_name = &"close"
	close_button.tooltip_text_name = &"close"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_scroll = GoScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	body = GoStyle.column()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)


func _ready() -> void:
	_restyle()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	# 🛑 Release the back-gesture claim — hold on to back after the drawer is gone and that screen cannot be left.
	# 🛑 **Clear `_open` along with it.** Leave it set and the claim is released while the state still says
	#    "open", so putting this back in the tree and calling `close()` sends `release` **a second time** and
	#    eats another window's claim (after which that window no longer closes on back).
	if _open:
		GoBackPolicy.release(get_tree())
		_open = false
		visible = false


## Open the drawer. A `title`, if given, goes in the header row. The body is **not emptied** — whatever was put in stays.
func open(title := "") -> void:
	if not title.is_empty(): set_title(title)
	if _open: return
	_open = true
	visible = true
	_relayout()
	_animate(true)
	GoBackPolicy.acquire(get_tree())
	GoFeedback.opened()
	opened.emit()


func close() -> void:
	if not _open: return
	_open = false
	_animate(false)
	GoBackPolicy.release(get_tree())
	GoFeedback.closed()
	closed.emit()


func is_open() -> bool:
	return _open


## Empty the body (for swapping pages).
func clear() -> void:
	for child in body.get_children(): child.queue_free()


func set_title(value: String) -> void:
	title_label.text = value
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.visible = not value.is_empty()


func set_title_key(key: String) -> void:
	title_label.text = key
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	header.visible = not key.is_empty()


## The side the drawer actually attaches to on the current screen (it can differ from `side`, since it may follow the text direction).
## 🛑 Write the return type as `GoDrawer.Side` — write just `Side` and GDScript dies **at parse time** saying it
##    "cannot return `GoDrawer.Side` as `Side`" (measured on 4.7).
func effective_side() -> GoDrawer.Side:
	if not follow_text_direction: return side
	# 🛑 `get_tool_locale()` is **the editor's** language — it stays put when the player switches the game to
	#    Arabic, and the drawer never flipped (2026-09-16). The language at run time is `get_locale()`.
	var locale := TranslationServer.get_locale()
	var rtl := locale.begins_with("ar") or locale.begins_with("he") \
		or locale.begins_with("fa") or locale.begins_with("ur")
	if not rtl: return side
	return Side.RIGHT if side == Side.LEFT else Side.LEFT


func _relayout() -> void:
	if panel == null or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	# 🛑 The background (the panel) runs **all the way** to the screen edge while the content stays inside the
	#    safe area — pull the panel inward and a band of page colour appears at the edge, making the drawer look like it floats.
	var full := window.get_visible_rect()
	var area := GoSafeArea.usable_rect(window)
	var width := minf(full.size.x * width_ratio, max_width) if max_width > 0.0 else full.size.x * width_ratio
	width = maxf(width, 160.0)
	panel.size = Vector2(width, full.size.y)
	var at_left := effective_side() == Side.LEFT
	panel.position = Vector2(0.0 if at_left else full.size.x - width, 0.0).round()

	# Only the content moves inside the safe area — clear of the notch and the gesture bar.
	var pad := panel.get_child(0) as MarginContainer
	if pad != null:
		var base := GoUi.metric(GoTheme.PADDING)
		pad.add_theme_constant_override(&"margin_top", base + roundi(maxf(0.0, area.position.y - full.position.y)))
		pad.add_theme_constant_override(&"margin_bottom", base + roundi(maxf(0.0, full.end.y - area.end.y)))
		pad.add_theme_constant_override(&"margin_left",
			base + (roundi(maxf(0.0, area.position.x - full.position.x)) if at_left else 0))
		pad.add_theme_constant_override(&"margin_right",
			base + (0 if at_left else roundi(maxf(0.0, full.end.x - area.end.x))))

	if not _open: return
	if is_instance_valid(_tween) and _tween.is_valid(): return
	panel.position.x = 0.0 if at_left else full.size.x - width


func _animate(shown: bool) -> void:
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	var window := get_window()
	var full := window.get_visible_rect() if window != null else Rect2()
	var at_left := effective_side() == Side.LEFT
	var rest := 0.0 if at_left else full.size.x - panel.size.x
	var away := -panel.size.x if at_left else full.size.x

	if GoUi.config.reduce_motion or motion_seconds <= 0.0 or not is_inside_tree():
		panel.position.x = rest if shown else away
		_scrim.color = _scrim_color(shown)
		if not shown: visible = false
		return

	_tween = create_tween().set_parallel(true)
	if shown:
		panel.position.x = away
		_scrim.color = _scrim_color(false)
		_tween.tween_property(panel, "position:x", rest, motion_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_scrim, "color", _scrim_color(true), motion_seconds)
	else:
		_tween.tween_property(panel, "position:x", away, motion_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_scrim, "color", _scrim_color(false), motion_seconds)
		_tween.chain().tween_callback(func() -> void: visible = false)


func _scrim_color(shown: bool) -> Color:
	var base := GoUi.color(GoTheme.SCRIM)
	return base if shown else Color(base, 0.0)


func _scrim_input(event: InputEvent) -> void:
	if not dismissable or not _open: return
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not tapped: return
	_scrim.accept_event()
	close()


func _restyle() -> void:
	panel.add_theme_stylebox_override(&"panel", GoUi.skin().surface_box(
		GoTheme.BOX_CARD, Color.TRANSPARENT, alpha))
	_scrim.color = _scrim_color(_open)


func _on_ui_changed() -> void:
	_restyle()
	_relayout()


func _notification(what: int) -> void:
	# Back (Android) and Escape close it — a drawer is a screen that "has to be leavable".
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _open and not GoSurface.is_any_open():
		close.call_deferred()
