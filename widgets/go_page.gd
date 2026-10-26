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
##
## ## 🧭 Sub-pages — one place, one level deeper, back retraces the path
## A row with more to show does not open a second window over the page: it **pushes a sub-page inside it**.
## ```gdscript
## about_row.pressed.connect(func() -> void:
##     page.push("About", func(box: VBoxContainer) -> void: box.add_child(GoStyle.label("Version 1.2"))))
## if await page.confirm("Log out", "Log out now?", "Log out", "", "", {}, true):
##     log_out()
## ```
## - `push(title, build)` / `push_key(title_key, build)` hide the current level and show a new one in the content area
##   with its own title, a scrolling body (returned, and handed to `build`) and a pinned row `sub_footer()`. `build`
##   runs **on push** — nothing of a sub-page exists before it is opened, and a popped level is freed.
## - The header's back button shows from depth 1. **Escape, the Android back gesture and the back button pop one
##   level** (`GoSurface.back_before_close`); only at depth 0 do they close the page. The close button closes the whole
##   page. `pop()` · `pop_to(depth)` · `depth()` · `depth_changed`.
## - While a sub-page is up the tab rail and the root's pinned footer step away (a deeper level is not a tab, and the
##   root's actions belong to the root's content); the toolbar and the preview stay. Focus returns to the control that
##   pushed when the level pops.
## - A sub-page has its own pinned status row (`set_status_text` / `set_status_key` / `clear_status`).
## - `hold(true)` holds the top sub-page while it must not be left (a form mid-send): back, Escape, the gesture and
##   the ✕ do nothing until `hold(false)` or a code `pop()`.
## - `confirm()` / `confirm_key()` ask inside the page — a pushed sub-page with the question and [cancel] [confirm] in
##   its pinned row (`await` → `true` on confirm; back, Escape or closing the page answer `false`).
## - `hand_over(action)` — for a row that opens a window the page cannot hold (a shop, another screen): the page steps
##   aside in the same frame that window opens and comes back, on the same tab and row, when it closes.
@tool
class_name GoPage
extends CanvasLayer

signal closed
## A sub-page was pushed or popped — [param depth] is the new depth (0: the page's own content).
signal depth_changed(depth: int)
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
var _content_edge_padding := -1
## Sub-pages, bottom to top: {root, scroll, body, footer, focus: WeakRef, under_title, under_mode, answer}.
var _levels: Array[Dictionary] = []
## What the first push hid, to give back on the last pop: the content area's own parts ([node, was visible]), the
## pinned footer and the rail.
var _root_parts: Array = []
var _footer_was := false
var _rail_was := false
## The host's own back action for the page's first level (`set_back`) — the sub-pages put theirs over it.
var _root_back := Callable()
## Whether the root's pinned status row showed when the first sub-page went up.
var _status_was := false
## `surface.close_enabled` as it was before a `hold` turned the ✕ off.
var _close_was := true
## A hand-over in progress (`hand_over`): {at, held, asks, serial, until, focus, aside, window}. Empty when none.
var _hand := {}
## How long a hand-over waits, at most, for the window its action opens — `GoSurface.HAND_OVER_SECONDS`.
const HAND_OVER_SECONDS := GoSurface.HAND_OVER_SECONDS


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
	surface.back_before_close = true
	surface.alpha = 1.0 if opaque else -1.0
	surface.close_requested.connect(close)
	add_child(surface)
	_build_frame()


func _ready() -> void:
	if layer == 1: layer = 10
	set_process(false)


func _notification(what: int) -> void:
	# A page freed while it stood aside gives its place on the path back (`GoSurface.set_aside`).
	if what == NOTIFICATION_EXIT_TREE and not _hand.is_empty() and bool(_hand.get("aside", false)):
		_hand = {}
		GoSurface.set_aside(false)


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
	# 🔑 The shared panel edge (as `GoSurface`'s own body scroll): the scrollbar sits in the card's padding, four units in
	#    from the card's right edge, and glows near the column's sides are not clipped. The padding follows the look and
	#    the density on each layout (`_sync_content_edge`).
	_content_scroll.use_panel_edge(GoUi.metric(GoTheme.PADDING))


# ── Opening and closing ────────────────────────────────────────────────

## Opens full screen with [param title] (already translated). Resets the back button; keeps tabs, preview and body.
## Opens on the page's own level — sub-pages left from before are popped (and a hand-over in progress is dropped).
func open(title: String) -> void:
	_drop_hand_over()
	pop_to(0)
	if not visible: GoFeedback.opened()
	surface.set_title(title)
	set_back(Callable())
	visible = true
	surface.relayout()


## Opens with a translation key as the title — the engine redraws it when the language changes.
func open_key(title_key: String) -> void:
	open("")
	surface.set_title_key(title_key)


## Changes only the title of the level shown (a sub-page carries its own title — `push`).
func set_title(value: String) -> void:
	surface.set_title(value)


## The same by translation key — the engine redraws it when the language changes.
func set_title_key(key: String) -> void:
	surface.set_title_key(key)


## The page's **own** title, whatever level shows: at depth 0 it is the title shown; under a sub-page it is the title
## the last pop brings back (a page that re-titles itself as its data changes must not re-title a sub-page).
func set_page_title(value: String) -> void:
	_set_page_title(value, false)


## The same by translation key.
func set_page_title_key(key: String) -> void:
	_set_page_title(key, true)


func _set_page_title(value: String, translate: bool) -> void:
	if _levels.is_empty():
		if translate: surface.set_title_key(value)
		else: surface.set_title(value)
		return
	_levels[0].under_title = value
	_levels[0].under_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED


## Closes the whole page (from any depth): the sub-pages are popped and freed, so it opens on its own level next time.
## A page that stood aside for a window (`hand_over`) stays closed — it does not come back.
func close() -> void:
	if not _hand.is_empty() and bool(_hand.get("aside", false)):
		_give_up_hand_over()
		return
	_hand = {}
	if not visible: return
	GoFeedback.closed()
	visible = false
	pop_to(0)
	closed.emit()


func is_open() -> bool:
	return visible


## The back button of the page's own level (like `GoSheet.set_back`). An empty `Callable` hides it. 🔑 Escape and the
## Android back run it too (`GoSurface.back_before_close`). A sub-page's back is the page's own (`pop`).
func set_back(action: Callable) -> void:
	_root_back = action
	if _levels.is_empty(): surface.set_back(action)


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
		# The edge frame puts the scroll's content in an inset (`GoScroll.use_panel_edge`) — the body goes back there.
		body.reparent(_content_scroll._content_inset if _content_scroll._content_inset != null else _content_scroll, false)
		body.size_flags_vertical = Control.SIZE_FILL
		_content_scroll.set_section_visible(true)
	else:
		body.reparent(_content_holder, false)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_scroll.set_section_visible(false)


# ── Sub-pages ──────────────────────────────────────────────────────────

## Pushes a sub-page titled [param title] (already translated) and returns its body — a column that scrolls like a tab
## body. [param build], when given, is called with that body right away (`build.call(body)`): build the sub-page there,
## on push — never up front. Escape, the Android back and the header's back pop it (`pop`).
func push(title: String, build := Callable()) -> VBoxContainer:
	return _push(title, false, build)


## The same with a translation key as the title — the engine redraws it when the language changes.
func push_key(title_key: String, build := Callable()) -> VBoxContainer:
	return _push(title_key, true, build)


## Pops the top sub-page (freed) and shows the level under it, its title and back, focus on the control that pushed.
## `false` at depth 0 — there is nothing to pop (the page itself closes with `close()`).
func pop() -> bool:
	if _levels.is_empty(): return false
	_pop_level(true)
	depth_changed.emit(_levels.size())
	return true


## Pops down to [param level_depth] at once (0: the page's own level) — no focus moves, `depth_changed` fires once.
func pop_to(level_depth: int) -> void:
	var target := maxi(0, level_depth)
	if _levels.size() <= target: return
	while _levels.size() > target: _pop_level(false)
	depth_changed.emit(_levels.size())


## How many sub-pages are up (0: the page's own content shows).
func depth() -> int:
	return _levels.size()


## The body of the level shown — the top sub-page's, or `body` at depth 0.
func sub_body() -> VBoxContainer:
	return _levels.back().body if not _levels.is_empty() else body


## The pinned row under the top sub-page's body (confirm buttons, [Send]) — it shows once something is put in it. At
## depth 0 the page's own `footer()`.
func sub_footer() -> VBoxContainer:
	return _levels.back().footer if not _levels.is_empty() else surface.footer


func _push(title: String, translate: bool, build: Callable) -> VBoxContainer:
	var view := get_viewport() if is_inside_tree() else null
	var focus: Control = view.gui_get_focus_owner() if view != null else null
	if focus != null and not surface.is_ancestor_of(focus): focus = null
	var level := {focus = weakref(focus) if focus != null else null, under_title = surface.title_label.text,
		under_mode = surface.title_label.auto_translate_mode}
	if _levels.is_empty():
		# 🔑 The first level hides the page's own content (every part of the content area, whatever `set_scrolls` made
		#    of it), the root's pinned footer and the rail — and remembers each, so the last pop gives back exactly that.
		_root_parts.clear()
		for part in _content_holder.get_children():
			_root_parts.append([part, (part as CanvasItem).visible])
			(part as CanvasItem).visible = false
		_footer_was = surface.footer.visible
		surface.footer.visible = false
		_status_was = surface.status.visible
		surface.status.visible = false
		_rail_was = _rail_scroll.visible
		_rail_scroll.visible = false
	else:
		(_levels.back().root as Control).visible = false
	var root := GoStyle.column(0)
	root.name = "SubPage%d" % (_levels.size() + 1)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_holder.add_child(root)
	var scroll := GoScroll.new()
	scroll.name = "SubPageScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var column := GoStyle.column()
	column.name = "SubPageBody"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	# The shared panel edge, as the tab body (`_build_frame`) — in the tree first: the edge frame wraps the scroll there.
	scroll.use_panel_edge(GoUi.metric(GoTheme.PADDING))
	# The level's own pinned status row, between its body and its footer — as the surface's (`set_status_text`).
	var status_row := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	status_row.name = "SubPageStatus"
	status_row.visible = false
	root.add_child(status_row)
	var foot := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	foot.name = "SubPageFooter"
	foot.visible = false
	foot.child_entered_tree.connect(func(_child: Node) -> void: foot.visible = true)
	root.add_child(foot)
	level.root = root
	level.scroll = scroll
	level.body = column
	level.footer = foot
	level.status = status_row
	_levels.append(level)
	if translate: surface.set_title_key(title)
	else: surface.set_title(title)
	surface.set_back(_back_one)
	_sync_content_edge()
	if build.is_valid(): build.call(column)
	if visible and is_inside_tree():
		GoFeedback.opened()
		_focus_level.call_deferred(root)
	depth_changed.emit(_levels.size())
	return column


## The pinned status row of the level shown — the one line that must not be missed ("Passwords do not match"), between
## the sub-page's body and its pinned row, as `GoSurface.set_status_text` (which it is at depth 0). An empty text hides it.
func set_status_text(text: String, tone := StringName()) -> void:
	_set_level_status(text, tone, false)


## By translation key — the engine redraws it when the language changes.
func set_status_key(key: String, tone := StringName()) -> void:
	_set_level_status(key, tone, true)


## Hides the status row of the level shown.
func clear_status() -> void:
	_set_level_status("", StringName(), false)


func _set_level_status(text: String, tone: StringName, translate: bool) -> void:
	if _levels.is_empty():
		surface._set_status(text, tone, translate)
		return
	var row: VBoxContainer = _levels.back().status
	GoSurface._fill_status_row(row, row.get_node_or_null(^"StatusLineText") as Label, text, tone, translate)


## Holds the top sub-page while it must not be left — a form mid-send, whose answer has nowhere to show once its
## sub-page is gone: back, Escape, the back gesture and the page's ✕ do nothing until `hold(false)`. A code `pop()` /
## `close()` still works. The hold is the level's own: it ends when that level is popped.
func hold(on: bool) -> void:
	if _levels.is_empty() or bool(_levels.back().get("held", false)) == on: return
	_levels.back().held = on
	if on: _close_was = surface.close_enabled
	_apply_hold(on)


## Whether the top sub-page is held (`hold`).
func is_held() -> bool:
	return not _levels.is_empty() and bool(_levels.back().get("held", false))


func _apply_hold(on: bool) -> void:
	surface.close_enabled = _close_was if not on else false
	if is_instance_valid(surface.back_button): surface.back_button.disabled = on


func _back_one() -> void:
	if is_held(): return
	pop()


func _pop_level(restore_focus: bool) -> void:
	var level: Dictionary = _levels.pop_back()
	if bool(level.get("held", false)): _apply_hold(false)
	var root: Control = level.root
	if is_instance_valid(root):
		_content_holder.remove_child(root)
		root.queue_free()
	if _levels.is_empty():
		for part: Array in _root_parts:
			if is_instance_valid(part[0]): (part[0] as CanvasItem).visible = part[1]
		_root_parts.clear()
		surface.footer.visible = _footer_was
		surface.status.visible = _status_was
		_rail_scroll.visible = _rail_was
		surface.set_back(_root_back)
		_content_edge_padding = -1   # the root's column comes back — measure its edge again
	else:
		(_levels.back().root as Control).visible = true
	if int(level.under_mode) == Node.AUTO_TRANSLATE_MODE_ALWAYS: surface.set_title_key(str(level.under_title))
	else: surface.set_title(str(level.under_title))
	_sync_content_edge()
	# A question popped by back / Escape / close is answered "no" — deferred, so the asker never resumes mid-pop.
	var answer: _Answer = level.get("answer")
	if answer != null: answer.give.call_deferred(false)
	if restore_focus and visible and is_inside_tree():
		GoFeedback.closed()
		_restore_focus_to.call_deferred(level.focus)


## Steering by keyboard: focus moves into the new level (its first control, else the back button). By pointer nothing
## takes focus — no ring on a page opened by a tap (`GoSurface._focus_default`'s rule).
func _focus_level(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_visible_in_tree(): return
	if GoUi.config.suppress_pointer_focus_ring and GoSurface._pointer_navigation: return
	var target := root.find_next_valid_focus()
	if target == null or not root.is_ancestor_of(target): target = surface.back_button
	if is_instance_valid(target) and target.is_visible_in_tree(): target.grab_focus()


## Focus back on [param ref]'s control — without its ring when the player steers by pointer.
func _restore_focus_to(ref: WeakRef) -> void:
	var target := ref.get_ref() as Control if ref != null else null
	if not is_instance_valid(target) or not target.is_visible_in_tree(): return
	target.grab_focus(GoUi.config.suppress_pointer_focus_ring and GoSurface._pointer_navigation)


# ── Asking inside the page ─────────────────────────────────────────────

## Asks yes or no **inside the page** — a pushed sub-page titled [param title] with [param body_text] (and [param extra]
## under it), [cancel] and [confirm] in its pinned row; `true` on confirm. Back, Escape, the back gesture and closing the
## page answer `false`. [param args] fill `{name}` placeholders in the title and body. [param destructive] paints the
## confirm button in the danger colour. Texts are already translated (`confirm_key` takes keys) — the same shape as
## `GoDialogs.confirm`, so a call site moves over by changing its receiver.
func confirm(title: String, body_text: String, ok_text := "", cancel_text := "", extra := "", args := {},
		destructive := false) -> bool:
	return await _ask(false, title, body_text, ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"),
		cancel_text if not cancel_text.is_empty() else GoUi.text(&"cancel"), extra, args, destructive)


## Asks by translation key (`confirm`). Without [param args] the title and body follow a language switch.
func confirm_key(title_key: String, body_key: String, ok_key := "", cancel_key := "", extra := "", args := {},
		destructive := false) -> bool:
	return await _ask(true, title_key, body_key, ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"),
		cancel_key if not cancel_key.is_empty() else GoUi.text_key(&"cancel"), extra, args, destructive)


func _ask(translate: bool, title: String, body_text: String, ok_text: String, cancel_text: String, extra: String,
		args: Dictionary, destructive: bool) -> bool:
	var answer := _Answer.new()
	var keyed := translate and args.is_empty()
	var box := _push(title if keyed else (tr(title) if translate else title).format(args), keyed, Callable())
	_levels.back().answer = answer
	var question := GoStyle.label_key(body_text) if keyed \
		else GoStyle.label((tr(body_text) if translate else body_text).format(args))
	question.name = "ConfirmBody"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(question)
	if not extra.is_empty():
		var more := GoStyle.label(extra, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		more.name = "ConfirmExtra"
		more.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(more)
	var level_depth := _levels.size()
	var reply := func(yes: bool) -> void:
		# Off the stack first, then the answer — the asker resumes on the level it asked from.
		if _levels.size() >= level_depth: pop_to(level_depth - 1)
		if yes: GoFeedback.confirmed()
		else: GoFeedback.canceled()
		answer.give(yes)
	var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	row.name = "ConfirmActions"
	var cancel := GoStyle.button_key(cancel_text, reply.bind(false)) if translate \
		else GoStyle.button(cancel_text, reply.bind(false))
	cancel.name = "Cancel"
	var ok := GoStyle.button_key(ok_text, reply.bind(true), GoStyle.Tone.PRIMARY) if translate \
		else GoStyle.button(ok_text, reply.bind(true), GoStyle.Tone.PRIMARY)
	ok.name = "Confirm"
	if destructive: GoStyle.style_button(ok, GoStyle.Tone.DANGER_SOLID)
	for button: Button in [cancel, ok]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(button)
	sub_footer().add_child(row)
	var yes: bool = await answer.done
	return yes


## One question's answer — its own signal, so two askers never get each other's reply (`GoDialogs.Ticket`).
class _Answer extends RefCounted:
	signal done(yes: bool)
	var _given := false

	func give(yes: bool) -> void:
		if _given: return
		_given = true
		done.emit(yes)


# ── Handing the screen to another window ───────────────────────────────

## Runs [param action] — a row that opens a window this page cannot hold (a shop, a screen of the game's own). When a
## window opens (in the action, or later within [param wait_seconds] — the window's own open, `GoSurface.open_serial`),
## the page **steps aside in that same frame** — hidden, its tab, body,
## sub-pages and scroll kept, not `closed` — and comes back when that window and anything it opened in turn have
## closed, focus on the row that handed over. One transition each way, and back retraces the path. Nothing opened: the
## page simply stays. A drawer or other held window opening while it is away means the player moved on: the page
## closes for good (`closed`) — and so does a window that closed **itself** (no `GoSurface.close_requests` since the
## hand-over: its job is done, the player stays where it put them). `recall()` brings it back early.
func hand_over(action: Callable, wait_seconds := HAND_OVER_SECONDS) -> void:
	_drop_hand_over()
	if not visible or not is_inside_tree():
		if action.is_valid(): action.call()
		return
	var focus := get_viewport().gui_get_focus_owner()
	_hand = {at = GoSurface.path_count(), held = GoSurface.held_count(), asks = GoSurface.close_requests(),
		serial = GoSurface.open_serial(), until = Time.get_ticks_msec() + int(maxf(0.0, wait_seconds) * 1000.0),
		focus = weakref(focus) if focus != null and surface.is_ancestor_of(focus) else null, aside = false}
	if action.is_valid(): action.call()
	_watch_hand_over()
	set_process(not _hand.is_empty())


## Is the page standing aside for a window it handed the screen to?
func is_handing_over() -> bool:
	return not _hand.is_empty() and bool(_hand.get("aside", false))


func _process(_delta: float) -> void:
	if _hand.is_empty():
		set_process(false)
		return
	_watch_hand_over()


func _watch_hand_over() -> void:
	if _hand.is_empty(): return
	if not bool(_hand.aside):
		if not visible:
			_hand = {}   # the action closed the page itself
		elif GoSurface.open_serial() != int(_hand.serial) and GoSurface.path_count() > int(_hand.at):
			_hand.aside = true
			_hand.window = weakref(GoSurface.last_opened())
			GoSurface.set_aside(true)
			visible = false   # the surface lets go of the back gesture; it takes it again on the way back
		elif Time.get_ticks_msec() >= int(_hand.until):
			_hand = {}   # nothing opened in time: the page simply stays
		return
	if GoSurface.held_count() > int(_hand.held):
		_give_up_hand_over()
	elif GoSurface.path_count() <= int(_hand.at):
		# Closed by itself, not by the player (`GoSurface.close_requests`): its job is done — stay closed.
		if GoSurface.close_requests() == int(_hand.asks):
			_give_up_hand_over()
			return
		_come_back()


## Back as it stood (tab, sub-page, scroll), focus on the row that handed over — the window it stood aside for closed.
func _come_back() -> void:
	var focus: WeakRef = _hand.focus
	_hand = {}
	GoSurface.set_aside(false)
	visible = true
	surface.relayout()
	_restore_focus_to.call_deferred(focus)


## Asks for the page back while it stands aside (the host's own way in — its menu key pressed again): the window it
## handed the screen to is asked to close as the player would (`GoSurface.request_close` — that window's own guards
## still hold, e.g. a purchase in flight keeps it up), and the page returns as that window closes. `false` when the page
## is not standing aside, or that window is not the top one (something the player opened over it answers first).
func recall() -> bool:
	if not is_handing_over(): return false
	var ref: WeakRef = _hand.get("window")
	var window := ref.get_ref() as GoSurface if ref != null else null
	if window == null or not window.is_top(): return false
	window.request_close()
	return true


func _drop_hand_over() -> void:
	if _hand.is_empty(): return
	if bool(_hand.get("aside", false)): GoSurface.set_aside(false)
	_hand = {}


func _give_up_hand_over() -> void:
	_drop_hand_over()
	pop_to(0)
	closed.emit()


# ── Tabs ───────────────────────────────────────────────────────────────

## The tab list (see the header). [param selected] is shown first (the first tab when empty or unknown); `tab_changed`
## fires for it, so a host that builds on `tab_changed` gets its first body. An empty list hides the rail.
func set_tabs(tabs: Array[Dictionary], selected: StringName = &"") -> void:
	pop_to(0)
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
		_dress_tab(button, str(tab.get("badge", "")), bool(tab.get("alert", false)))
		_rail.add_child(button)
		_tab_buttons[id] = button
		_fit_tab(button)
	_rail_scroll.visible = _tabs.size() > 1
	_current = &""
	if _tabs.is_empty(): return
	var first := StringName(_tabs[0].get("id", &""))
	select_tab(selected if _tab_buttons.has(selected) else first)


## Changes tab [param id]'s count [param badge] (`""` removes it) and red dot ([param alert]) in place — the tabs are
## not rebuilt, so the shown tab, its body and the focus stay (a count that changes while the page is up: unspent points,
## unread mail). An unknown id does nothing.
func set_tab_badge(id: StringName, badge := "", alert := false) -> void:
	var button := _tab_buttons.get(id) as Button
	if button == null: return
	for tab in _tabs:
		if StringName(tab.get("id", &"")) == id:
			tab["badge"] = badge
			tab["alert"] = alert
	_dress_tab(button, badge, alert)
	_fit_tab(button)


## The tab button's count badge (in its row, after the label) and red dot (on its corner) — `set_tabs` / `set_tab_badge`.
func _dress_tab(button: Button, badge: String, alert: bool) -> void:
	var line := _row_of(button)
	var count: GoBadge = line.get_node_or_null(^"Badge") as GoBadge if line != null else null
	if badge.is_empty():
		if count != null:
			line.remove_child(count)
			count.queue_free()
	elif count != null:
		count.label_text = badge
	elif line != null:
		count = GoBadge.make(0, badge, false, GoUi.color(GoTheme.SECONDARY))
		count.name = "Badge"
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(count)
	if alert: GoBadge.attach(button, 0, "", true)
	else: GoBadge.detach(button)


## Shows tab [param id] and fires `tab_changed` when it is a different tab. An unknown id does nothing. A tab is the
## page's own level: sub-pages up are popped first.
func select_tab(id: StringName) -> void:
	if not _tab_buttons.has(id): return
	pop_to(0)
	if id == _current: return
	_current = id
	for key in _tab_buttons:
		GoStyle.restyle_list_row(_tab_buttons[key], key == id)
	_content_scroll.scroll_vertical = 0
	# The chosen tab scrolls into the strip (a portrait strip wider than the screen cut it at the edge — measured).
	if is_inside_tree(): _rail_scroll.ensure_control_visible.call_deferred(_tab_buttons[id])
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
	_sync_content_edge()


## The content column borrows the card's right padding for its scrollbar only where it meets that edge: always left
## to right, and in portrait (one column) right to left too. A right-to-left landscape page has the rail on the right —
## there the content column's right side borders the rail and there is no padding to borrow.
## A sub-page's scroll follows the same rule; while it is up the rail is away, so its column meets the edge unless a
## right-to-left landscape preview stands there.
func _sync_content_edge() -> void:
	var right_taken := _landscape and surface.is_layout_rtl() and (_rail_scroll.visible or _preview_slot.visible)
	var padding: int = surface._content_padding if not right_taken else 0
	for level in _levels:
		# Only on a change — re-applying the same insets still re-emits minimum sizes, and the page relayouts on those.
		if int(level.get("pad", -1)) != padding:
			level["pad"] = padding
			(level.scroll as GoScroll).set_panel_padding(padding)
		_sync_level_gap(level)
	if not _levels.is_empty(): return   # the root's column is hidden — it catches up on the last pop
	if padding == _content_edge_padding: return
	_content_edge_padding = padding
	_content_scroll.set_panel_padding(padding)


## The gap between a sub-page's scroll and its pinned rows (status, footer): the surface's own section gap, never less
## than the bottom bleed the scroll borrows for glows (`GoScroll.edge_bleed_bottom`). That bleed is meant for padding;
## a pinned row right under the scroll is not padding — with no gap the body's last line was drawn under the
## sub-page's footer (12dp at 360×800, measured 2026-10-26). The column's separation only applies between visible
## children, so a level without status or footer is unchanged.
func _sync_level_gap(level: Dictionary) -> void:
	var gap := maxi(surface.section_gap(), (level.scroll as GoScroll).edge_bleed_bottom())
	var column := level.root as BoxContainer
	if column.get_theme_constant(&"separation") != gap: column.add_theme_constant_override(&"separation", gap)


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
		# 🛑 A glyph icon is a Label too (`GoIconSet.node`) and carries `go_no_wrap`: wrapped down the rail it grew taller
		#    than its row and drew above the words (Sound / Display tabs in a landscape settings page, 2026-10-16).
		if words.has_meta(&"go_no_wrap"): continue
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
		# Whole pixels, inside the area: rounding the size up put the card's last row 0.3 px past an 800×450 window's
		# 355.7 logical px (key_bindings_ui "MoveArrows outside the window", 2026-10-19).
		var top_left := area.position.ceil()
		card.position = top_left
		card.size = area.end.floor() - top_left

	## 🛑 The window can change size without `size_changed` reaching this surface in the same frame (a stretch change, a
	##    rotation settling over two frames — measured: the card kept the portrait width after a turn). An open page
	##    compares the rectangle it laid out for with the current one each frame; the comparison costs nothing.
	##    And the card fits again when its content's minimum drops: the engine grows a card whose minimum passes its size
	##    and nothing shrinks it back (measured: a page first shown at 320×640 kept an 796–1073 dp card from the frame
	##    before its tabs were arranged). The sections' `minimum_size_changed` marks `_layout_dirty` (GoSurface).
	func _process(delta: float) -> void:
		super._process(delta)
		if _active and is_inside_tree() and (_layout_dirty
				or GoSafeArea.usable_rect_with_keyboard(get_window(), _keyboard_px) != _laid_out):
			relayout()

	## A language switch can flip the direction without a resize — the content scroll's edge follows it.
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			var owner_page: GoPage = page.get_ref() if page != null else null
			if owner_page != null: owner_page._sync_content_edge.call_deferred()

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
