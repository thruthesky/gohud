## 🗂️ **A full-screen page** — settings, a bag, a character screen: a title with back and close, a category rail
## (left in landscape, tabs along the top in portrait), an optional preview beside the content (a character model,
## a map), and the content area. It holds its own `CanvasLayer`, like `GoSheet`, so it comes up above the HUD.
##
## ```gdscript
## var page := GoPage.new()
## add_child(page)
## page.tab_changed.connect(func(id: StringName) -> void:
##     page.clear()
##     page.body.add_child(GoStyle.label("Tab %s" % id)))
## page.open("Settings")
## page.set_tabs([{id = &"sound", label = "Sound", icon = GoIconSet.VOLUME_HIGH},
##     {id = &"display", label = "Display", icon = GoIconSet.DISPLAY, badge = "3"}])
## ```
##
## ## 🔑 What it inherits instead of re-inventing
## The chrome is a `GoSurface` that fills the safe area, so the page holds the Android back gesture
## (`GoBackPolicy`) exactly like a sheet does, Escape and the back gesture close **only the topmost** window
## (`GoSurface.is_top()`), and focus goes back where it was on close. The ground behind fills the whole screen;
## only the content keeps out of the notch and the gesture bar (`GoSafeArea`).
##
## ## 🔑 Tabs are data
## `set_tabs()` takes `{id, label, icon, badge}` dictionaries (`label` already translated or a translation key — it is
## shown through the engine's auto-translate; `icon` a `GoIconSet` name or `&""`; `badge` text such as a count, or
## `""`). Add `alert = true` for a red dot. The page never builds tab content itself: build each tab's body on
## `tab_changed`, or up front and toggle visibility there. `body` is kept between tabs and between opens — call
## `clear()` when a tab should start empty.
##
## ## 🛑 Opaque by default
## A full-screen page covers the screen; drawing the world behind a covered page is wasted work. `opaque` keeps the
## panel and the ground behind it fully opaque, so a host may stop drawing what is underneath while it is open.
## Turn it off only for a page that must show something through (and then do not hide the world).
@tool
class_name GoPage
extends CanvasLayer

signal closed
## The shown tab changed — by a tap on its tab, `select_tab()`, or `set_tabs()` choosing the first one.
signal tab_changed(id: StringName)

## The content area of the current tab — a column inside a scroll unless `set_scrolls(false)`.
var body: VBoxContainer
## The full-area surface being wrapped — header, back, close, toolbar, footer and status row live on it.
var surface: GoSurface

## Opaque panel and ground (see the header). Changing it while open applies at once.
var opaque := true:
	set(value):
		opaque = value
		if is_instance_valid(surface):
			surface.alpha = 1.0 if value else -1.0
			surface._dress_scrim()

## Width of the left rail in landscape, as a fraction of the page width — clamped to `rail_min_width..rail_max_width`.
var rail_ratio := 0.22
var rail_min_width := 150.0
var rail_max_width := 260.0
## Width (landscape) or height (portrait) of the preview, as a fraction of the page.
var preview_ratio_landscape := 0.34
var preview_ratio_portrait := 0.32

var _frame: BoxContainer
var _rail_scroll: GoScroll
var _rail: BoxContainer
var _preview_slot: MarginContainer
var _preview: Control
var _content_scroll: GoScroll
var _content_holder: VBoxContainer
var _scrolls := true
var _tabs: Array[Dictionary] = []
var _tab_buttons := {}
var _current := &""
var _landscape := false
var _arranged := false


## 🛑 Built in `_init` — `page.open()` and `page.body` before adding the page to the tree is natural use (as `GoSheet`).
func _init() -> void:
	visible = false
	var chrome := _PageSurface.new()
	chrome.page = weakref(self)
	surface = chrome
	surface.placement = GoSurface.Placement.CENTER
	surface.fit_content = false
	surface.resizable = false
	surface.scroll_body = false
	surface.dismiss_on_scrim = false
	surface.alpha = 1.0 if opaque else -1.0
	surface.close_requested.connect(close)
	add_child(surface)
	_build_frame()


func _ready() -> void:
	if layer == 1: layer = 10


func _build_frame() -> void:
	_frame = BoxContainer.new()
	_frame.name = "PageFrame"
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	surface.body.add_child(_frame)

	_rail_scroll = GoScroll.new()
	_rail_scroll.name = "Rail"
	_rail_scroll.visible = false
	_frame.add_child(_rail_scroll)
	_rail = BoxContainer.new()
	_rail.name = "Tabs"
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_rail_scroll.add_child(_rail)

	_preview_slot = MarginContainer.new()
	_preview_slot.name = "Preview"
	_preview_slot.visible = false
	_preview_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	_frame.add_child(_preview_slot)

	_content_holder = GoStyle.column(0)
	_content_holder.name = "ContentArea"
	_content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(_content_holder)
	_content_scroll = GoScroll.new()
	_content_scroll.name = "Content"
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_holder.add_child(_content_scroll)
	body = GoStyle.column()
	body.name = "PageBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(body)


# ── Opening and closing ────────────────────────────────────────────────

## Opens full screen with [param title] (already translated). Resets the back button; keeps tabs, preview and body.
func open(title: String) -> void:
	if not visible: GoFeedback.opened()
	surface.set_title(title)
	set_back(Callable())
	visible = true
	surface.relayout()


## Opens with a translation key as the title — the engine redraws it when the language changes.
func open_key(title_key: String) -> void:
	open("")
	surface.set_title_key(title_key)


## Changes only the title (a sub-page inside the same page carries its own title).
func set_title(value: String) -> void:
	surface.set_title(value)


func close() -> void:
	if not visible: return
	GoFeedback.closed()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## A sub-page's back button (like `GoSheet.set_back`). An empty `Callable` hides it.
func set_back(action: Callable) -> void:
	surface.set_back(action)


## Empties the content area (the current tab's body).
func clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_content_scroll.scroll_vertical = 0


## The pinned row under the header (search field, a server line). The caller switches `visible = true` on.
func toolbar() -> VBoxContainer:
	return surface.toolbar


## The pinned footer row — confirm buttons that must stay visible while the content scrolls.
func footer() -> VBoxContainer:
	return surface.footer


## Whether the content area scrolls. 🔑 Off for a page whose content scrolls by itself (a grid with its own
## `GoScroll`, a list view) — two nested vertical scrolls fight over the finger.
func set_scrolls(on: bool) -> void:
	if on == _scrolls: return
	_scrolls = on
	if on:
		body.reparent(_content_scroll, false)
		body.size_flags_vertical = Control.SIZE_FILL
		_content_scroll.visible = true
	else:
		body.reparent(_content_holder, false)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_scroll.visible = false


# ── Tabs ───────────────────────────────────────────────────────────────

## The tab list (see the header). [param selected] is shown first (the first tab when empty or unknown); `tab_changed`
## fires for it, so a host that builds on `tab_changed` gets its first body. An empty list hides the rail.
func set_tabs(tabs: Array[Dictionary], selected: StringName = &"") -> void:
	for child in _rail.get_children():
		_rail.remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	_tabs = tabs.duplicate()
	for tab in _tabs:
		var id := StringName(tab.get("id", &""))
		var button := GoStyle.list_button(StringName(tab.get("icon", &"")), str(tab.get("label", id)),
			select_tab.bind(id))
		button.name = "Tab_%s" % id
		button.set_meta(&"go_page_tab", id)
		var badge := str(tab.get("badge", ""))
		var line := _row_of(button)
		if line != null and not badge.is_empty():
			var count := GoBadge.make(0, badge, false, GoUi.color(GoTheme.SECONDARY))
			count.name = "Badge"
			count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(count)
		if bool(tab.get("alert", false)):
			GoBadge.attach(button, 0, "", true)
		_rail.add_child(button)
		_tab_buttons[id] = button
		_fit_tab(button)
	_rail_scroll.visible = _tabs.size() > 1
	_current = &""
	if _tabs.is_empty(): return
	var first := StringName(_tabs[0].get("id", &""))
	select_tab(selected if _tab_buttons.has(selected) else first)


## Shows tab [param id] and fires `tab_changed` when it is a different tab. An unknown id does nothing.
func select_tab(id: StringName) -> void:
	if not _tab_buttons.has(id) or id == _current: return
	_current = id
	for key in _tab_buttons:
		GoStyle.restyle_list_row(_tab_buttons[key], key == id)
	_content_scroll.scroll_vertical = 0
	tab_changed.emit(id)


func current_tab() -> StringName:
	return _current


## The rail button of tab [param id] (for a host that wants to move focus to it, or a test). Null when unknown.
func tab_button(id: StringName) -> Button:
	return _tab_buttons.get(id) as Button


## The row inside a `GoStyle.list_button` (padding → row) — where a count badge joins the label.
func _row_of(button: Button) -> HBoxContainer:
	if button.get_child_count() == 0: return null
	var inset := button.get_child(0)
	return inset.get_child(0) as HBoxContainer if inset.get_child_count() > 0 else null


# ── Preview ────────────────────────────────────────────────────────────

## The side preview — left of the content in landscape, a band above it in portrait. `null` hides it.
## 🛑 The page never frees a preview it was handed: replacing it or passing `null` only detaches it (a 3D stage is
##    expensive to rebuild). One still attached is freed with the page.
func set_preview(node: Control) -> void:
	if is_instance_valid(_preview) and _preview != node and _preview.get_parent() == _preview_slot:
		_preview_slot.remove_child(_preview)
	_preview = node
	if node != null and node.get_parent() != _preview_slot:
		if node.get_parent() != null: node.get_parent().remove_child(node)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview_slot.add_child(node)
	_preview_slot.visible = node != null
	_arrange(true)


## The preview handed to `set_preview()`, or null.
func preview() -> Control:
	return _preview


## True while the page lays out for landscape (rail on the left, preview beside the content).
func is_landscape() -> bool:
	return _landscape


# ── Layout ─────────────────────────────────────────────────────────────

## Called by the surface after it filled the safe area — decides rail vs top tabs, and the preview's share.
func _layout_to(area: Vector2) -> void:
	var landscape := area.x > area.y
	if landscape != _landscape or not _arranged:
		_landscape = landscape
		_arrange(true)
	_size_parts(area)


func _arrange(force := false) -> void:
	if _frame == null: return
	if not force and _arranged: return
	_arranged = true
	_frame.vertical = not _landscape
	_rail.vertical = _landscape
	if _landscape:
		_rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_rail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_rail_scroll.size_flags_horizontal = Control.SIZE_FILL
		_preview_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview_slot.size_flags_horizontal = Control.SIZE_FILL
	else:
		_rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_rail_scroll.size_flags_vertical = Control.SIZE_FILL
		_rail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preview_slot.size_flags_vertical = Control.SIZE_FILL
		_preview_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for button in _tab_buttons.values():
		_fit_tab(button)


## Down the rail a long label wraps inside the rail's width; along the top it keeps one line, so every tab is as wide as
## its words and the strip scrolls sideways when they do not all fit. 🛑 A wrapping label asks for almost no width —
## left on along the top, every tab shrank to its icon.
func _fit_tab(button: Control) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for words in button.find_children("*", "Label", true, false):
		if words.get_parent() is GoBadge: continue   # a count keeps its own one-line shape
		(words as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _landscape else TextServer.AUTOWRAP_OFF
	var inset := button.get_child(0) as Control if button.get_child_count() > 0 else null
	if inset != null and not inset.has_meta(&"go_page_hug"):
		inset.set_meta(&"go_page_hug", true)
		inset.minimum_size_changed.connect(_hug_tab.bind(button), CONNECT_DEFERRED)
	_hug_tab(button)


## 🛑 A `Button` does not lay out its children — the list row's label sits in a full-rect inset, so the button's own
##    minimum ignores the words (measured: six one-line tabs squeezed to 75 dp each, "Graphics" drawn over "Sound").
##    The tab takes its inset's minimum: its words' width along the top (the strip then scrolls), and the wrapped
##    height down the rail (a two-line label never spills out of a 48 dp row).
func _hug_tab(button: Control) -> void:
	if not is_instance_valid(button) or button.get_child_count() == 0: return
	var need := (button.get_child(0) as Control).get_combined_minimum_size()
	button.custom_minimum_size = Vector2(0.0 if _landscape else ceilf(need.x),
		maxf(float(GoUi.metric(GoTheme.TOUCH)), ceilf(need.y)))


func _size_parts(area: Vector2) -> void:
	var touch := float(GoUi.metric(GoTheme.TOUCH))
	if _landscape:
		_rail_scroll.custom_minimum_size = Vector2(clampf(area.x * rail_ratio, rail_min_width, rail_max_width), 0.0)
		_preview_slot.custom_minimum_size = Vector2(roundf(area.x * preview_ratio_landscape), 0.0)
	else:
		_rail_scroll.custom_minimum_size = Vector2(0.0, touch)
		_preview_slot.custom_minimum_size = Vector2(0.0, roundf(area.y * preview_ratio_portrait))


## 🔑 The chrome: a `GoSurface` whose card fills the safe area. Everything else (back ownership, Escape, the back
## gesture, `is_top()`, focus) is the surface's own — this only replaces where the card goes and how the ground looks.
class _PageSurface extends GoSurface:
	var page: WeakRef
	var _laid_out := Rect2()

	func relayout() -> void:
		_layout_dirty = false
		_resize_pending = false
		if card == null or not is_inside_tree(): return
		_update_density()
		var area := GoSafeArea.usable_rect_with_keyboard(get_window(), _keyboard_px)
		_laid_out = area
		# 🛑 The page sizes its parts first: the card cannot shrink below its content's minimum, and the parts still
		#    carried the other orientation's minimums (a portrait preview band kept a landscape card 32dp too tall).
		var owner_page: GoPage = page.get_ref() if page != null else null
		if owner_page != null: owner_page._layout_to(area.size)
		card.position = area.position.round()
		card.size = area.size.round()

	## 🛑 The window can change size without `size_changed` reaching this surface in the same frame (a stretch change, a
	##    rotation settling over two frames — measured: the card kept the portrait width after a turn). An open page
	##    compares the rectangle it laid out for with the current one each frame; the comparison costs nothing.
	func _process(delta: float) -> void:
		super._process(delta)
		if _active and is_inside_tree() \
				and GoSafeArea.usable_rect_with_keyboard(get_window(), _keyboard_px) != _laid_out:
			relayout()

	## The ground behind the card — the theme's background, opaque, for an opaque page (no world showing in the
	## notch bands); the usual scrim otherwise.
	func _dress_scrim() -> void:
		if not is_instance_valid(_scrim): return
		var owner_page: GoPage = page.get_ref() if page != null else null
		if owner_page != null and owner_page.opaque:
			_scrim.color = Color(GoUi.color(GoTheme.BACKGROUND), 1.0)
			_scrim.material = null
			return
		super._dress_scrim()
