## 🏗️ **The frame of an app screen** — top app bar, the page that scrolls under it, a bottom bar, a floating action
## button and a drawer, wired to each other (Flutter's `Scaffold`).
##
## ```gdscript
## var screen := GoScaffold.new()
## screen.set_app_bar(GoAppBar.make("Inbox", GoIconSet.MENU))
## screen.set_body(page)                       # a column of rows — it goes in a GoScroll for you
## screen.set_bottom_bar(GoNavBar.make(destinations, 0, show_tab))
## screen.set_fab(GoFab.make(GoIconSet.EDIT, "Compose", compose))
## screen.set_drawer(menu_drawer)              # the app bar's menu button opens it
## add_child(screen)                           # it fills its parent
## snackbar.margin = screen.snackbar_margin()  # snackbars float above the bottom bar
## ```
##
## ## 🔑 What it wires for you
## - The app bar lifts when the page scrolls (`GoAppBar.follow`), and an extended FAB folds while it scrolls down.
## - The FAB floats in the bottom end corner **above** the bottom bar, and moves when the bar grows (gesture-bar
##   inset, rotation) — mirrored in a right-to-left language.
## - The app bar's leading menu button opens the drawer, unless you gave that button an action of your own.
## - The screen's background is the theme's backdrop.
##
## ## 🔑 A body that scrolls itself
## A `GoListView`, a `GoTabView` or any `ScrollContainer` is placed as it is (`set_body(list, false)` is not needed);
## anything else goes into a `GoScroll`. Pass `scrolls = false` for a body that must not scroll (a map, a camera).
@tool
class_name GoScaffold
extends Control

## The page's scroll (the one the app bar follows), or `null` when the body scrolls itself or does not scroll.
var scroll: ScrollContainer
var app_bar: GoAppBar
var body: Control
var bottom_bar: Control
var fab: GoFab
var drawer: GoDrawer

var _back: ColorRect
var _column: VBoxContainer
var _top: MarginContainer
var _middle: MarginContainer
var _bottom: MarginContainer


func _init() -> void:
	name = "Scaffold"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = ColorRect.new()
	_back.name = "Backdrop"
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_back)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_column.add_theme_constant_override(&"separation", 0)
	add_child(_column)
	for slot in ["Top", "Middle", "Bottom"]:
		var holder := MarginContainer.new()
		holder.name = slot
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_column.add_child(holder)
	_top = _column.get_node(^"Top")
	_middle = _column.get_node(^"Middle")
	_middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom = _column.get_node(^"Bottom")
	_bottom.resized.connect(_float_fab)
	resized.connect(_float_fab)


func _ready() -> void:
	_restyle()
	GoUi.watch(_restyle)


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## A scaffold with an app bar titled [param title] (and a menu button when [param menu]) over [param page].
static func make(title := "", page: Control = null, menu := false) -> GoScaffold:
	var node := GoScaffold.new()
	if not title.is_empty() or menu: node.set_app_bar(GoAppBar.make(title, GoIconSet.MENU if menu else &""))
	if page != null: node.set_body(page)
	return node


## Puts [param bar] at the top. It follows the page's scroll.
func set_app_bar(bar: GoAppBar) -> void:
	_swap(_top, app_bar, bar)
	app_bar = bar
	_wire()


## Puts [param page] in the middle — inside a `GoScroll` unless it scrolls itself or [param scrolls] is false.
func set_body(page: Control, scrolls := true) -> void:
	if is_instance_valid(body) and body != page:
		var old := body.get_parent()
		if old is GoScroll and old != page: old.queue_free()
		elif is_instance_valid(old): old.remove_child(body)
	body = page
	scroll = null
	for child in _middle.get_children():
		_middle.remove_child(child)
		if child != page: child.queue_free()
	if page == null: return
	if page is ScrollContainer:
		scroll = page
		_middle.add_child(page)
	elif page is GoTabView or not scrolls:
		_middle.add_child(page)
	else:
		var holder := GoScroll.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(page)
		_middle.add_child(holder)
		scroll = holder
	_wire()


## Puts [param bar] at the bottom (a `GoNavBar`, or a bottom app bar from `GoStyle.bottom_app_bar`).
func set_bottom_bar(bar: Control) -> void:
	_swap(_bottom, bottom_bar, bar)
	bottom_bar = bar
	_float_fab.call_deferred()


## Floats [param button] in the bottom end corner, above the bottom bar.
func set_fab(button: GoFab) -> void:
	if is_instance_valid(fab) and fab != button: fab.queue_free()
	fab = button
	if fab == null: return
	if fab.get_parent() != self:
		if fab.get_parent() != null: fab.get_parent().remove_child(fab)
		add_child(fab)
	_wire()
	_float_fab.call_deferred()


## Attaches [param panel]; the app bar's menu button opens it unless that button already has an action.
func set_drawer(panel: GoDrawer) -> void:
	if is_instance_valid(drawer) and drawer != panel: drawer.queue_free()
	drawer = panel
	if drawer != null and drawer.get_parent() == null: add_child(drawer)
	_wire()


## Opens the drawer, if there is one.
func open_drawer() -> void:
	if is_instance_valid(drawer): drawer.open()


## How far (dp) from the screen's bottom a snackbar should keep — above the bottom bar. Give it to `GoSnackbar.margin`.
func snackbar_margin() -> float:
	var bar := _bottom.size.y if is_instance_valid(bottom_bar) and bottom_bar.visible else 0.0
	return bar + float(GoUi.metric(GoTheme.SCREEN_MARGIN))


func _swap(holder: Control, old: Control, new: Control) -> void:
	if is_instance_valid(old) and old != new:
		holder.remove_child(old)
		old.queue_free()
	if new != null and new.get_parent() != holder:
		if new.get_parent() != null: new.get_parent().remove_child(new)
		holder.add_child(new)


## Connects what knows about what: the app bar and the FAB follow the scroll; the menu button opens the drawer.
func _wire() -> void:
	if is_instance_valid(app_bar):
		if scroll != null: app_bar.follow(scroll)
		var lead := app_bar.leading_button
		if is_instance_valid(lead) and is_instance_valid(drawer) and lead.icon_name == GoIconSet.MENU \
				and not app_bar.leading_action.is_valid() and not app_bar.navigated.is_connected(open_drawer):
			app_bar.navigated.connect(open_drawer)
	if is_instance_valid(fab) and scroll != null: fab.follow(scroll)


func _float_fab() -> void:
	if not is_instance_valid(fab) or not is_inside_tree(): return
	var above := _bottom.size.y if is_instance_valid(bottom_bar) and bottom_bar.visible else 0.0
	fab.float_in(self, above)


func _restyle() -> void:
	_back.color = GoUi.color(GoTheme.BACKGROUND)
