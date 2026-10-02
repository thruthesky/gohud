## 🔝 **Top app bar** — the screen's title with a back (or menu) button before it and a few actions after it.
## Material's small top app bar: 64dp, and it lifts off the page once the list under it scrolls.
##
## ```gdscript
## var bar := GoAppBar.make("Inbox", GoIconSet.MENU, open_drawer)
## bar.add_action(GoIconSet.SEARCH, &"search", open_search)
## bar.add_action(GoIconSet.MORE, &"More", open_menu)
## column.add_child(bar)          # the first child of the screen's column
## column.add_child(list_scroll)  # …and the scrolling page under it
## bar.follow(list_scroll)        # flat at the top, lifted once the page scrolls
## ```
##
## ## 🔑 The bar tells you the page has moved
## At rest the bar has the page's own colour, so the screen reads as one sheet. Once the content scrolls beneath it,
## the bar takes its scrolled face (`GoSkin.app_bar_box`) — under Material `surface-container` with a level-2 shadow —
## and the content passing underneath no longer runs into the title.
##
## ## 🔑 Actions are icons, and few
## Two or three icon actions fit beside a title on a phone. Put the rest behind a `GoIconSet.MORE` button that opens a
## menu (`GoContextMenu`). Every action needs its tooltip name — it is the only name a screen reader has.
##
## ## 🛑 It pads itself clear of the status bar
## With `safe_area` on (the default) the bar grows by the screen's top inset (`GoSafeArea`), so a notch or the status bar
## never covers the title while the bar's colour still runs to the top edge.
@tool
class_name GoAppBar
extends PanelContainer

## The leading button (back, menu) was pressed.
signal navigated

## Centre the title (Material's center-aligned top app bar) instead of starting it after the leading button.
@export var centered := false:
	set(value):
		centered = value
		_layout_title()

## Grow the bar by the screen's top inset (status bar, notch).
@export var safe_area := true:
	set(value):
		safe_area = value
		_pad_safe_area()

## Whether the content under the bar has scrolled — the bar then takes its lifted face. `follow()` keeps it up to date.
var scrolled := false:
	set(value):
		if scrolled == value: return
		scrolled = value
		_restyle()

## Height of the bar without the safe-area inset (dp) — `_md-comp-top-app-bar-small.scss` container-height.
const EXTENT := 64.0

var title_label: Label
## The leading icon button, or `null` when the bar has none.
var leading_button: GoIconButton
## The row the action buttons go into.
var actions: HBoxContainer

var _pad: MarginContainer
var _start: HBoxContainer
var _followed: ScrollContainer


func _init() -> void:
	name = "AppBar"
	custom_minimum_size.y = EXTENT
	GoScroll.scroll_through(self)
	_pad = MarginContainer.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 0)
	_pad.add_child(line)
	_start = HBoxContainer.new()
	_start.name = "Leading"
	_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_start)
	title_label = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	title_label.name = "Title"
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.set_meta(&"go_no_wrap", true)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(title_label)
	actions = HBoxContainer.new()
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override(&"separation", 0)
	line.add_child(actions)


func _ready() -> void:
	theme = GoUi.theme()
	_restyle()
	_layout_title()
	_pad_safe_area()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_pad_safe_area)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A bar titled [param title]. [param leading] is the icon before it (`GoIconSet.BACK`, `GoIconSet.MENU`; empty for
## none), [param action] what pressing it does. [param translate] treats the title as a translation key.
static func make(title: String, leading: StringName = &"", action := Callable(), translate := false) -> GoAppBar:
	var node := GoAppBar.new()
	node.set_title(title, translate)
	if not leading.is_empty(): node.set_leading(leading, action)
	return node


## Changes the title. [param translate] treats it as a translation key.
func set_title(text: String, translate := false) -> void:
	title_label.text = text
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED


## Sets the leading icon button ([param icon] empty removes it). Its tooltip is "Back" for `GoIconSet.BACK` and
## "Menu" otherwise (gohud's translated strings) — set `leading_button.tooltip_text_name` for your own.
func set_leading(icon: StringName, action := Callable()) -> void:
	if is_instance_valid(leading_button):
		leading_button.queue_free()
		leading_button = null
	if icon.is_empty():
		_layout_title()
		return
	leading_button = _icon_button(icon, &"back" if icon == GoIconSet.BACK else &"menu")
	leading_button.name = "LeadingButton"
	leading_button.pressed.connect(func() -> void:
		navigated.emit()
		if action.is_valid(): action.call())
	_start.add_child(leading_button)
	_layout_title()


## Adds an action icon button at the end of the bar. [param tooltip] is a gohud string name, your translation key or
## plain words — it is the button's only name for a screen reader, so give one.
func add_action(icon: StringName, tooltip: StringName, action := Callable()) -> GoIconButton:
	var button := _icon_button(icon, tooltip)
	if action.is_valid(): button.pressed.connect(action)
	actions.add_child(button)
	var peers: Array[Control] = []
	for child in actions.get_children(): peers.append(child)
	if is_instance_valid(leading_button): peers.append(leading_button)
	for child in peers: (child as GoIconButton).touch_peers = peers
	_layout_title()
	return button


## Keeps `scrolled` in step with [param scroll] — flat while it is at the top, lifted once it has moved.
func follow(scroll: ScrollContainer) -> void:
	if is_instance_valid(_followed) and _followed.get_v_scroll_bar().value_changed.is_connected(_on_scroll):
		_followed.get_v_scroll_bar().value_changed.disconnect(_on_scroll)
	_followed = scroll
	if scroll == null: return
	scroll.get_v_scroll_bar().value_changed.connect(_on_scroll)
	_on_scroll(scroll.get_v_scroll_bar().value)


func _on_scroll(value: float) -> void:
	scrolled = value > 0.5


func _icon_button(icon: StringName, tooltip: StringName) -> GoIconButton:
	var button := GoIconButton.new()
	button.icon_name = icon
	button.tooltip_text_name = tooltip
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


func _restyle() -> void:
	add_theme_stylebox_override(&"panel", GoUi.skin().app_bar_box(scrolled))


## The title starts 16dp in without a leading button and right after it with one; centred, both sides take the width
## of the wider one so the title sits in the middle of the bar.
## 🔑 The icon buttons are 36dp nodes that take presses 48dp wide (`GoIconButton`): 4dp from the edge to the touch
##    area (`_md-comp-top-app-bar-small.scss` leading space) puts the node 10dp in, and the buttons sit 12dp apart so
##    their touch areas meet instead of overlapping.
func _layout_title() -> void:
	if title_label == null: return
	var slack := roundi(maxf(0.0, float(GoUi.config.min_touch_size) - 36.0) * 0.5)
	var edge := GoUi.metric(GoTheme.GAP_TINY) + slack
	var lead := is_instance_valid(leading_button) and not leading_button.is_queued_for_deletion()
	_pad.add_theme_constant_override(&"margin_left", edge if lead else GoUi.metric(GoTheme.GAP))
	_pad.add_theme_constant_override(&"margin_right", edge if actions.get_child_count() > 0 else GoUi.metric(GoTheme.GAP))
	actions.add_theme_constant_override(&"separation", slack * 2)
	_start.add_theme_constant_override(&"separation", slack * 2)
	title_label.get_parent().add_theme_constant_override(&"separation", slack * 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	_start.custom_minimum_size.x = 0.0
	actions.custom_minimum_size.x = 0.0
	if centered:
		var side := maxf(_start.get_combined_minimum_size().x, actions.get_combined_minimum_size().x)
		_start.custom_minimum_size.x = side
		actions.custom_minimum_size.x = side


## The bar grows by the top inset so its title clears the status bar.
func _pad_safe_area() -> void:
	if _pad == null or not is_inside_tree(): return
	var inset := 0
	var window := get_window()
	if safe_area and window != null and not Engine.is_editor_hint():
		inset = roundi(maxf(0.0, GoSafeArea.usable_rect(window).position.y - window.get_visible_rect().position.y))
	_pad.add_theme_constant_override(&"margin_top", inset)
	custom_minimum_size.y = EXTENT + inset


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_restyle()
	_layout_title()
