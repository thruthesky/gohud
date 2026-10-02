## 🧭 **Navigation bar** — the three to five destinations along the bottom of an app screen (Home, Search, Alerts,
## Profile). Turn on `vertical` and it is the **navigation rail** at the side of a tablet or a landscape screen.
##
## ```gdscript
## var nav := GoNavBar.make([
## 	{"icon": GoIconSet.HOME, "text": "Home"},
## 	{"icon": GoIconSet.SEARCH, "text": "Search"},
## 	{"icon": GoIconSet.BELL, "text": "Alerts", "badge": 3},
## 	{"icon": GoIconSet.USER, "text": "Profile"},
## ], 0, func(index: int) -> void: show_tab(index))
## column.add_child(nav)          # the last child of the screen's column — the page above it scrolls
## nav.set_badge(2, 0)            # read: the count goes, and with it the badge
## ```
##
## ## 🔑 A destination, not an action
## Each item **switches the whole page** under it. An action ("Compose", "Add to cart") belongs on a `GoFab` or in the
## top app bar instead. With more than five destinations the labels stop fitting a phone — move the rest into a drawer.
##
## ## 🔑 The chosen one carries a pill
## The active destination shows its icon on an indicator pill and its label in the accent colour — so the choice reads
## from shape as well as colour. The skin draws the pill (`GoSkin.nav_indicator_box`): an accent tint by default, the M3
## 56×32 `secondary-container` pill under Material.
##
## ## 🛑 It pads itself clear of the gesture bar
## With `safe_area` on (the default) a bottom bar grows by the screen's bottom inset (`GoSafeArea`), so the labels never
## sit under Android's gesture bar or the iPhone home indicator while the bar's colour still runs to the edge.
## A rail does not pad — place it inside your own safe-area margin.
@tool
class_name GoNavBar
extends PanelContainer

## A destination was chosen (by touch, click or keyboard — not by `set_selected`).
signal selected(index: int)

## Lay the destinations in a column — the navigation rail of a wide screen.
@export var vertical := false:
	set(value):
		vertical = value
		_rebuild()

## Grow a bottom bar by the screen's bottom inset (gesture bar, home indicator).
@export var safe_area := true:
	set(value):
		safe_area = value
		_pad_safe_area()

## Height of a bottom bar and width of a rail without the safe-area inset (dp) — M3: 64 and 96.
const BAR_EXTENT := 64.0
const RAIL_EXTENT := 96.0
## The active indicator pill (`_md-comp-nav-bar-item-vertical.scss`: 56×32).
const INDICATOR := Vector2(56, 32)

var _items: Array = []
var _selected := 0
var _action := Callable()
var _translate := false
var _group := ButtonGroup.new()
var _cells: Array[Button] = []
var _pad: MarginContainer


func _init() -> void:
	name = "NavBar"
	GoScroll.scroll_through(self)


func _ready() -> void:
	theme = GoUi.theme()
	_rebuild()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_pad_safe_area)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A navigation bar of [param items] — `{"icon": StringName, "text": String, "badge": int, "dot": bool}` each —
## with [param chosen] active. [param action] is called with the index when a destination is chosen.
## [param translate] treats the texts as translation keys.
static func make(items: Array, chosen := 0, action := Callable(), translate := false) -> GoNavBar:
	var node := GoNavBar.new()
	node._items = items.duplicate(true)
	node._selected = clampi(chosen, 0, maxi(0, items.size() - 1))
	node._action = action
	node._translate = translate
	return node


## The navigation rail — the same destinations in a column.
static func rail(items: Array, chosen := 0, action := Callable(), translate := false) -> GoNavBar:
	var node := make(items, chosen, action, translate)
	node.vertical = true
	return node


## The active destination's index.
func selected_index() -> int:
	return _selected


## Make [param index] active without emitting `selected` (reflecting a page the app opened by itself).
func set_selected(index: int) -> void:
	if index < 0 or index >= _cells.size():
		_selected = clampi(index, 0, maxi(0, _items.size() - 1))
		return
	_selected = index
	for at in _cells.size(): _cells[at].set_pressed_no_signal(at == index)
	_paint_all()


## Show [param count] on a destination's badge (0 hides it); [param words] instead of a number, or [param as_dot] for a dot.
func set_badge(index: int, count: int, words := "", as_dot := false) -> void:
	if index < 0 or index >= _items.size(): return
	_items[index]["badge"] = count
	_items[index]["badge_text"] = words
	_items[index]["dot"] = as_dot
	if index < _cells.size():
		var icon: Control = _cells[index].get_meta(&"go_nav_icon")
		if is_instance_valid(icon): GoBadge.attach(icon, count, words, as_dot)


## The cell (a `Button`) of one destination — for a tooltip, a test, or a coach mark to point at.
func cell(index: int) -> Button:
	return _cells[index] if index >= 0 and index < _cells.size() else null


func _rebuild() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cells.clear()
	add_theme_stylebox_override(&"panel", GoUi.skin().nav_bar_box(vertical))
	_pad = MarginContainer.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	var line: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY) if vertical else 0)
	if vertical: line.alignment = BoxContainer.ALIGNMENT_BEGIN
	_pad.add_child(line)
	for index in _items.size():
		line.add_child(_make_cell(index))
	if vertical:
		custom_minimum_size = Vector2(RAIL_EXTENT, 0)
		_pad.add_theme_constant_override(&"margin_top", GoUi.metric(GoTheme.GAP_LARGE))
	else:
		custom_minimum_size = Vector2(0, BAR_EXTENT)
	# 🔑 The end destinations keep clear of the bar's own edge — a cut (sci-fi) or framed (medieval) face needs room.
	var side := maxi(GoUi.metric(GoTheme.GAP_TINY), GoStyle.face_clearance(self))
	_pad.add_theme_constant_override(&"margin_left", side)
	_pad.add_theme_constant_override(&"margin_right", side)
	_pad_safe_area()
	_paint_all()


func _make_cell(index: int) -> Button:
	var spec: Dictionary = _items[index]
	var button := Button.new()
	button.name = "Destination%d" % index
	button.toggle_mode = true
	button.button_group = _group
	button.button_pressed = index == _selected
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	GoScroll.scroll_through(button)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not vertical else Control.SIZE_FILL
	button.custom_minimum_size = Vector2(GoUi.metric(GoTheme.TOUCH), BAR_EXTENT)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var text := str(spec.get("text", ""))
	button.accessibility_name = tr(text) if _translate else text
	button.tooltip_text = ""
	# The column inside: the indicator pill holding the icon, and the label under it.
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 4)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(stack)
	var pill := PanelContainer.new()
	pill.name = "Indicator"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size = INDICATOR
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(pill)
	var ring := Panel.new()
	ring.name = "FocusRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	pill.add_child(ring)
	var icon := GoUi.icons().node(StringName(spec.get("icon", &"")), GoUi.metric(GoTheme.ICON_SIZE))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_child(icon)
	var words := GoStyle.label_key(text, GoTheme.ROLE_COMPACT) if _translate else GoStyle.label(text, GoTheme.ROLE_COMPACT)
	words.name = "Label"
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.set_meta(&"go_no_wrap", true)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 🛑 Fill the cell's width, centred — a label that may trim (`…`) and shrinks to its minimum is 1px wide and draws
	#    nothing (seen on every preset, 2026-10-02). It trims only when the cell really is narrower than the word.
	words.size_flags_horizontal = Control.SIZE_FILL
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.visible = not text.is_empty()
	stack.add_child(words)
	button.set_meta(&"go_nav_icon", icon)
	button.set_meta(&"go_nav_pill", pill)
	button.set_meta(&"go_nav_label", words)
	button.set_meta(&"go_nav_ring", ring)
	button.set_meta(&"go_nav_held", false)
	button.toggled.connect(func(on: bool) -> void:
		_paint_all()
		if not on: return
		_selected = index
		selected.emit(index)
		if _action.is_valid(): _action.call(index))
	for signal_name in [&"mouse_entered", &"mouse_exited", &"focus_entered", &"focus_exited"]:
		button.connect(signal_name, _paint.bind(button))
	button.button_down.connect(func() -> void:
		button.set_meta(&"go_nav_held", true)
		_paint(button))
	button.button_up.connect(func() -> void:
		button.set_meta(&"go_nav_held", false)
		_paint(button))
	if int(spec.get("badge", 0)) > 0 or bool(spec.get("dot", false)) or not str(spec.get("badge_text", "")).is_empty():
		GoBadge.attach.call_deferred(icon, int(spec.get("badge", 0)), str(spec.get("badge_text", "")),
			bool(spec.get("dot", false)))
	_cells.append(button)
	return button


func _paint_all() -> void:
	for button in _cells: _paint(button)


## Puts the state on one destination: the indicator pill, the icon and label colours, and the keyboard focus ring.
func _paint(button: Button) -> void:
	if not is_instance_valid(button) or not button.has_meta(&"go_nav_pill"): return
	var skin := GoUi.skin()
	var chosen := button.button_pressed
	var state := &"normal"
	if bool(button.get_meta(&"go_nav_held")): state = &"pressed"
	elif button.is_hovered(): state = &"hover"
	(button.get_meta(&"go_nav_pill") as PanelContainer).add_theme_stylebox_override(&"panel",
		skin.nav_indicator_box(chosen, state))
	var ring: Panel = button.get_meta(&"go_nav_ring")
	# 🛑 Only keyboard and gamepad focus shows the ring — the focus a tap hands out is hidden (`has_focus(true)`).
	ring.visible = button.has_focus(true)
	if ring.visible:
		ring.add_theme_stylebox_override(&"panel", skin.nav_indicator_box(chosen, &"focus"))
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon: Control = button.get_meta(&"go_nav_icon")
	var ink := skin.nav_ink(chosen, false)
	# 🛑 `self_modulate`, not `modulate` — the destination's badge hangs on this icon, and a modulate tints its children:
	#    the red badge came out near-black under a dark icon colour, its count unreadable (A17, 2026-10-02).
	if icon is TextureRect:
		icon.modulate = Color.WHITE
		icon.self_modulate = ink
	elif icon is Label: icon.add_theme_color_override(&"font_color", ink)
	(button.get_meta(&"go_nav_label") as Label).add_theme_color_override(&"font_color", skin.nav_ink(chosen, true))


## A bottom bar grows by the bottom inset so its labels clear the gesture bar.
func _pad_safe_area() -> void:
	if _pad == null or not is_inside_tree(): return
	var inset := 0
	var window := get_window()
	if safe_area and not vertical and window != null and not Engine.is_editor_hint():
		var full := window.get_visible_rect()
		inset = roundi(maxf(0.0, full.end.y - GoSafeArea.usable_rect(window).end.y))
	_pad.add_theme_constant_override(&"margin_bottom", inset)


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_rebuild()
