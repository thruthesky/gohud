## 📋 **The readable-list lab** — one quest giver's five quests, built twice and shown side by side.
##
## ## Why this exists
## A game shipped a quest panel built with gohud that players found hard to read (2026-09-23): every gap was
## 4 dp, the panel title had shrunk to the size of the row titles, the same scroll badge sat on all five rows
## and four of the five rows carried a yellow warning. Nothing in it was a gohud bug — each choice was
## reasonable on its own — and that is exactly why a rule on paper was not enough. **Before** rebuilds that
## screen with gohud parts; **After** follows rule 15 of the gohud skill (`SKILL.md` §3, "Lists must scan").
## Under each panel is one line of numbers **measured from the nodes it drew** — change the code and the
## numbers follow, so the lab cannot drift from what it claims.
##
## ## How to use it
## ```gdscript
## var layer := CanvasLayer.new()
## layer.layer = 50
## add_child(layer)
## var lab := preload("res://addons/gohud/examples/gallery/list_lab.gd").new()
## lab.closed.connect(layer.queue_free)
## layer.add_child(lab)
## ```
##
## 🛑 **Keep it out of a `GoForm`.** `GoStyle.form()` sets the spacing of every box it meets to `GAP` (12), so
##    inside a form the 4 dp of Before would come out as 12 and the comparison would lie. The lab marks its own
##    boxes with `go_own_spacing` all the same, and the gallery opens it on a `CanvasLayer` of its own.
## 🛑 **Not inside a `GoSurface` either.** A surface that runs short of height drops its title to `body` (16) —
##    After's 22 dp heading would shrink and After would turn into Before.
## 🛑 It adds no global class to the add-on (no `class_name`) — used through `preload` only, like `opacity_lab.gd`.
extends Control

## The close button, Escape or Android Back was pressed. The owner removes the lab (it does not free itself).
signal closed

enum View { BEFORE, AFTER, BOTH }

const OpacityLab := preload("opacity_lab.gd")

## The panel's content, the same on both sides. `current` marks the one quest that can be done now.
const QUESTS := [
	{"title": "Recover a Broken Battery", "level": 1, "item": "Broken Battery", "have": 0, "need": 1, "current": true},
	{"title": "Collect Scrap Parts", "level": 5},
	{"title": "Recover Damaged Circuit Boards", "level": 30},
	{"title": "Secure a Data Fragment", "level": 60},
	{"title": "Assemble the Chrome Set", "level": 60},
]
const GIVER := "Ryen"
## A panel is never wider than this (dp) — a quest panel is a phone-width thing even on a desktop, and two of
## them fit side by side on a 1280 window.
const PANEL_MAX := 440.0
## Below this width (dp) a panel stops shrinking and the page scrolls sideways instead of crushing the text.
const PANEL_MIN := 300.0

## Which panels show. `BOTH` lays them side by side and stacks them when the window is too narrow for two.
var view := View.BOTH

var _before: VBoxContainer          ## Before's column — its panel, then its measured line
var _after: VBoxContainer           ## After's column
var _before_panel: PanelContainer
var _after_panel: PanelContainer
var _before_readout: Label
var _after_readout: Label
var _views: HBoxContainer           ## the Before / After / Both switch
var _stage: GridContainer           ## two columns when both panels fit, one when they do not
var _lessons_box: VBoxContainer     ## the "What changed" lines — held to the panels' width
var _backdrop: Control


func _ready() -> void:
	name = "ListLab"
	theme = GoUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The lab covers the gallery — presses must not fall through to the page underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "Background"
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# 🔬 Panels are 80% opaque — "over a game" is where a cramped list really falls apart, so the lab can lay
	#    the opacity lab's pattern behind both panels. Faint, like a real game background (see `Backdrop`).
	_backdrop = OpacityLab.Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.set(&"intensity", 0.3)
	_backdrop.visible = false
	add_child(_backdrop)

	var frame := GoStyle.padding(GoUi.metric(GoTheme.SCREEN_MARGIN))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	var outer := _box(GoStyle.column(GoUi.metric(GoTheme.GAP)))
	frame.add_child(outer)

	var top := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	var heading := GoStyle.label("Readable lists", GoTheme.ROLE_SUBTITLE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close_button := GoStyle.icon_button(GoIconSet.CLOSE, close, -1, &"Close")
	close_button.name = "Close"
	top.add_child(close_button)
	outer.add_child(top)
	outer.add_child(GoStyle.label("The same five quests, built twice. Before is how a real quest panel was built; "
		+ "After follows rule 15 of the gohud skill. The line under each panel is measured from what it drew.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))

	# A flow row is not a box — `GoStyle.form()` leaves its spacing alone.
	var switches := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	_views = GoStyle.segmented(["Before", "After", "Both"], view, _set_view)
	_views.name = "Views"
	switches.add_child(_views)
	var ground := GoStyle.segmented(["Plain", "In game"], 0, func(index: int) -> void: _backdrop.visible = index == 1)
	ground.name = "Ground"
	switches.add_child(ground)
	outer.add_child(switches)

	var scroll := GoScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var page := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_LARGE)))
	page.name = "Page"
	scroll.add_child(page)

	# 🛑 Not a `wrap_row()`: a flow row forces **everything inside it, all the way down**, to natural width with
	#    wrapping off (`GoStyle.natural_width`) — the panels' rows shrank to their text and every expanding title
	#    and right-aligned value collapsed (measured 2026-09-23). A grid lays the panels out and leaves them alone.
	_stage = GridContainer.new()
	_stage.name = "Stage"
	_stage.add_theme_constant_override(&"h_separation", GoUi.metric(GoTheme.GAP_LARGE))
	_stage.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP_LARGE))
	page.add_child(_stage)
	var stage := _stage
	_before_panel = _cramped_panel()
	_before_readout = _readout_label()
	_before = _specimen("Before — as shipped", _before_panel, _before_readout)
	_before.name = "Before"
	stage.add_child(_before)
	_after_panel = _readable_panel()
	_after_readout = _readout_label()
	_after = _specimen("After — rule 15", _after_panel, _after_readout)
	_after.name = "After"
	stage.add_child(_after)

	# 🔑 A line of prose is held to the width of the two panels — at full window width one sentence ran 150
	#    characters, the very thing a readability lab should not do.
	_lessons_box = _lessons()
	_lessons_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(_lessons_box)

	resized.connect(_fit)
	# One panel at a time when two do not fit — After first, it is the one to copy.
	var room := get_viewport_rect().size.x - 2.0 * GoUi.metric(GoTheme.SCREEN_MARGIN)
	_set_view(View.BOTH if room >= 2.0 * PANEL_MIN + GoUi.metric(GoTheme.GAP_LARGE) else View.AFTER)
	_fit.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	# Android Back closes the lab like Escape does — the owner of a full-screen layer owns its way out (rule 3).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		close()


## Asks the owner to remove the lab.
func close() -> void:
	closed.emit()


## Shows Before, After or both (`View`). Also what the switch at the top calls.
func show_view(which: int) -> void:
	_set_view(which)


## 📏 **What a panel drew, in numbers** — `side` is `View.BEFORE` or `View.AFTER`. Read from the nodes, never
## from constants: `row_gap` (space between rows), `row_inset` (a row's top padding), `header` / `title` /
## `meta` (font sizes of the panel title, a row title and a row's second line), `badges` (rows wearing a
## decorative badge), `warnings` (rows wearing a warning), `rows` and `height` (dp, once laid out).
func measure(side: int) -> Dictionary:
	var panel := _before_panel if side == View.BEFORE else _after_panel
	var list := panel.find_child("List", true, false) as BoxContainer
	var rows := panel.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node.has_meta(&"go_lab_row"))
	var first: Control = rows[0] as Control if not rows.is_empty() else null
	var inset := -1
	if list != null and list.get_child_count() > 0:
		var margins := list.get_child(0).find_children("*", "MarginContainer", true, false)
		if not margins.is_empty(): inset = (margins[0] as MarginContainer).get_theme_constant(&"margin_top")
	return {
		"row_gap": list.get_theme_constant(&"separation") if list != null else -1,
		"row_inset": inset,
		"header": _font_size(panel.find_child("Header", true, false)),
		"title": _font_size(first.find_child("RowTitle", true, false) if first != null else null),
		"meta": _font_size(first.find_child("RowMeta", true, false) if first != null else null),
		"badges": rows.filter(func(row: Node) -> bool: return row.has_meta(&"go_lab_badge")).size(),
		"warnings": rows.filter(func(row: Node) -> bool: return row.has_meta(&"go_lab_warning")).size(),
		"rows": rows.size(),
		"height": roundi(panel.size.y),
	}


# ── Before — the screen as it was built ───────────────────────────────

## Built the way the shipped panel was: a surface gone dense (padding 8, title at `body`), a header line that
## repeats the first row, rows 4 dp apart with 4 dp inside, the same round badge on every row, a warning on
## every level gate and "Now" at body size.
func _cramped_panel() -> PanelContainer:
	var pad := GoUi.metric(GoTheme.GAP_SMALL)
	var panel := _panel()
	var inset := GoStyle.padding(pad)
	panel.add_child(inset)
	var body := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	inset.add_child(body)

	var head := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	head.add_child(GoStyle.button("Back", Callable(), GoStyle.Tone.COMPACT))
	head.add_child(_glyph(GoIconSet.BOOK, GoUi.color(GoTheme.ACCENT), GoUi.metric(GoTheme.ICON_SIZE) + 4))
	var title := GoStyle.label(GIVER, GoTheme.ROLE_BODY)
	title.name = "Header"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_glyph(GoIconSet.CLOSE, GoUi.color(GoTheme.MUTED), GoUi.metric(GoTheme.ICON_SIZE)))
	body.add_child(head)
	body.add_child(GoStyle.label("Current quest: " + QUESTS[0].title, GoTheme.ROLE_BODY))

	var list := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_TINY)))
	list.name = "List"
	for quest: Dictionary in QUESTS:
		list.add_child(_cramped_row(quest))
	body.add_child(list)
	return panel


func _cramped_row(quest: Dictionary) -> Button:
	var row := Button.new()
	row.name = "Row"
	row.theme = GoUi.theme()
	row.theme_type_variation = GoTheme.VAR_LIST_BUTTON
	row.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_meta(&"go_lab_row", true)
	row.set_meta(&"go_lab_badge", true)
	# The shipped row: 8 at the sides, 4 above and below.
	var inset := GoStyle.padding(GoUi.metric(GoTheme.GAP_SMALL), GoUi.metric(GoTheme.GAP_TINY))
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inset)
	var line := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(line)

	var badge := GoStyle.disc_panel(32.0, GoUi.color(GoTheme.SECONDARY))
	badge.add_child(_glyph(GoIconSet.BOOK, GoUi.color(GoTheme.SECONDARY), GoUi.metric(GoTheme.LIST_GLYPH)))
	line.add_child(badge)

	var stack := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_TINY)))
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(stack)
	var head := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(head)
	var title := GoStyle.label(quest.title, GoTheme.ROLE_BODY)
	title.name = "RowTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var meta := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_TINY)))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(meta)
	var note: Label
	if quest.get("current", false):
		var now := GoStyle.label("Now", GoTheme.ROLE_BODY, GoUi.color(GoTheme.SUCCESS))
		now.autowrap_mode = TextServer.AUTOWRAP_OFF
		now.size_flags_horizontal = Control.SIZE_SHRINK_END
		head.add_child(now)
		meta.add_child(_glyph(GoIconSet.WARNING, GoUi.color(GoTheme.DANGER), GoUi.metric(GoTheme.LIST_GLYPH)))
		meta.add_child(_glyph(GoIconSet.BOX, GoUi.color(GoTheme.MUTED), GoUi.metric(GoTheme.LIST_GLYPH)))
		note = GoStyle.label(quest.item, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
		row.set_meta(&"go_lab_warning", true)
	else:
		meta.add_child(_glyph(GoIconSet.WARNING, GoUi.color(GoTheme.WARNING), GoUi.metric(GoTheme.LIST_GLYPH)))
		note = GoStyle.label("Requires Lv %d" % quest.level, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.WARNING))
		row.set_meta(&"go_lab_warning", true)
	note.name = "RowMeta"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(note)
	if quest.get("current", false):
		var count := GoStyle.label("%d / %d" % [quest.have, quest.need], GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.DANGER))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		meta.add_child(count)
	line.add_child(_glyph(GoIconSet.CHEVRON_DOWN, GoUi.color(GoTheme.MUTED), GoUi.metric(GoTheme.LIST_GLYPH)))
	GoStyle.fit_content_height(row, inset)
	return row


# ── After — rule 15 ───────────────────────────────────────────────────

## The same content by the rules: padding 20; a heading one size above the row titles; the current quest said
## once, in one card; the rest grouped under a heading that says why they wait, rows 8 apart with 8 inside;
## a lock and muted text for a level gate instead of a warning; no badge repeated on every row.
func _readable_panel() -> PanelContainer:
	var panel := _panel()
	var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING))
	panel.add_child(inset)
	# Groups sit a large gap apart; inside a group things sit closer — the eye reads the groups first.
	var body := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_LARGE)))
	inset.add_child(body)

	var head := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	head.add_child(GoStyle.icon_button(GoIconSet.CHEVRON_LEFT, Callable(), -1, &"Back"))
	var names := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_TINY)))
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := GoStyle.label(GIVER, GoTheme.ROLE_SUBTITLE)
	title.name = "Header"
	names.add_child(title)
	var waiting := QUESTS.size() - 1
	names.add_child(GoStyle.label("Quest giver · 1 quest open · %d unlock later" % waiting,
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	head.add_child(names)
	head.add_child(GoStyle.icon_button(GoIconSet.CLOSE, Callable(), -1, &"Close"))
	body.add_child(head)

	var now_group := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	now_group.add_child(GoStyle.section("Current quest", false))
	now_group.add_child(_current_card(QUESTS[0]))
	body.add_child(now_group)

	var later := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	later.add_child(GoStyle.section("Unlocks with level", false))
	var list := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	list.name = "List"
	for quest: Dictionary in QUESTS.slice(1):
		# 🔑 The library's own row: sides 12, 8 above and below on two lines, title `body`, second line `caption`
		#    in `MUTED`. The lock repeats on every row and that is fine — it says something about each row.
		var gate := "Requires level %d" % quest.level
		var row := GoStyle.list_button(GoIconSet.LOCK, quest.title, Callable(), Color.TRANSPARENT, gate, false)
		row.name = "Row"
		row.set_meta(&"go_lab_row", true)
		# 🛑 Found by text, not by order — a font icon set draws the lock as a Label too.
		for label: Label in row.find_children("*", "Label", true, false):
			if label.text == quest.title: label.name = "RowTitle"
			elif label.text == gate: label.name = "RowMeta"
		list.add_child(row)
	later.add_child(list)
	body.add_child(later)
	return panel


## The one quest that can be done now: title and a "Now" chip on one line, what to do under it, and the
## progress as plain numbers — 0 of 1 is not a failure yet, so it is not red.
func _current_card(quest: Dictionary) -> PanelContainer:
	var card := GoStyle.card(GoUi.color(GoTheme.ACCENT))
	card.name = "Current"
	card.set_meta(&"go_lab_row", true)
	# 🛑 The card's face already has padding — put the column straight in, never another `padding()` around it.
	var column := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	card.add_child(column)
	var top := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	var title := GoStyle.label(quest.title, GoTheme.ROLE_BODY)
	title.name = "RowTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var now := GoStyle.chip("Now", GoUi.color(GoTheme.ACCENT))
	now.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(now)
	column.add_child(top)
	var ask := GoStyle.label("Bring %d %s back to %s." % [quest.need, quest.item, GIVER],
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	ask.name = "RowMeta"
	column.add_child(ask)
	var progress := _box(GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)))
	progress.add_child(_glyph(GoIconSet.BOX, GoUi.color(GoTheme.SECONDARY), GoUi.metric(GoTheme.LIST_GLYPH)))
	var item := GoStyle.label(quest.item, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.add_child(item)
	var count := GoStyle.label("%d / %d" % [quest.have, quest.need], GoTheme.ROLE_BODY)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 🔑 A value at the row's end is `SHRINK_END` — a label expands by default and would split the width with the name.
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	progress.add_child(count)
	column.add_child(progress)
	return card


# ── Pieces ────────────────────────────────────────────────────────────

## One side of the comparison: its name, its panel, and the line of numbers measured from that panel.
func _specimen(caption: String, panel: PanelContainer, readout: Label) -> VBoxContainer:
	var column := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(GoStyle.section(caption, false))
	column.add_child(panel)
	column.add_child(readout)
	return column


## The panel face both sides share — the face is the same, so only the content is being compared.
func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var face := GoStyle.surface(GoTheme.BOX_PANEL).duplicate() as StyleBox
	# Padding comes from the content (8 on one side, 20 on the other) — the face adds none of its own.
	GoStyle.face_padding(face, 0.0, 0.0)
	GoStyle.style_panel(panel, face)
	return panel


func _readout_label() -> Label:
	var line := GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED))
	line.name = "Readout"
	return line


## What the reader should take away — each line names the number it changed.
func _lessons() -> VBoxContainer:
	var column := _box(GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL)))
	column.name = "Lessons"
	column.add_child(GoStyle.section("What changed", false))
	for line: String in [
		"Rows sit 8 apart with 8 inside, and a row's two lines 4 apart. Before used 4 for all three, so the rows ran together.",
		"The panel title is a size above the row titles — 22 against 16. A GoSurface short of height drops its title to 16, so put the heading players read first in the body.",
		"The current quest is said once, in one card. Before also printed it in a header line.",
		"A warning only where something is wrong. A level gate is a lock and muted text, not a yellow triangle on four rows out of five.",
		"No badge that repeats on every row: five identical scrolls said nothing and took 32 dp from each row.",
		"Padding 20 around the content, not 8, and progress 0 / 1 in plain text — it is not a failure yet.",
	]:
		column.add_child(GoStyle.label(line, GoTheme.ROLE_BODY, GoUi.color(GoTheme.SECONDARY)))
	return column


func _glyph(icon: StringName, ink: Color, size: int) -> Control:
	var node := GoUi.icons().node(icon, size, ink)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 🛑 Marks a box as keeping its own spacing, so a `GoForm` it may end up in leaves it alone (`GoStyle.form()`).
func _box(node: BoxContainer) -> BoxContainer:
	node.set_meta(&"go_own_spacing", true)
	return node


func _font_size(node: Node) -> int:
	return (node as Control).get_theme_font_size(&"font_size") if node is Control else -1


func _set_view(which: int) -> void:
	view = which as View
	if _before == null: return
	_before.visible = view != View.AFTER
	_after.visible = view != View.BEFORE
	var group: ButtonGroup = _views.get_meta(&"group") if _views != null and _views.has_meta(&"group") else null
	if group != null:
		var cells := group.get_buttons()
		# 🛑 `button_pressed`, not `set_pressed_no_signal()` — the quiet setter skips the group, and the cell that was
		#    chosen before stays lit next to the new one (seen on the 390 dp capture: After and Both both lit).
		#    The switch listens to `pressed`, which a script setting never emits, so this does not loop.
		if view < cells.size(): cells[view].button_pressed = true
	_fit.call_deferred()


## Sizes both panels to the window — as wide as `PANEL_MAX`, never narrower than `PANEL_MIN` — then measures.
func _fit() -> void:
	if _before == null: return
	var room := size.x - 2.0 * GoUi.metric(GoTheme.SCREEN_MARGIN)
	var width := clampf(room, PANEL_MIN, PANEL_MAX)
	var side_by_side := view == View.BOTH and room >= 2.0 * PANEL_MIN + GoUi.metric(GoTheme.GAP_LARGE)
	if side_by_side:
		width = clampf((room - GoUi.metric(GoTheme.GAP_LARGE)) * 0.5, PANEL_MIN, PANEL_MAX)
	_stage.columns = 2 if side_by_side else 1
	_lessons_box.custom_minimum_size.x = minf(room, 2.0 * PANEL_MAX + GoUi.metric(GoTheme.GAP_LARGE))
	for column: Control in [_before, _after]:
		column.custom_minimum_size.x = width
		(column.get_child(1) as Control).custom_minimum_size.x = width
	_refresh_readouts.call_deferred()


func _refresh_readouts() -> void:
	if not is_inside_tree(): return
	# Wait for the layout to settle so `height` is the drawn height, not the height before the width changed.
	await get_tree().process_frame
	if not is_inside_tree(): return
	_before_readout.text = _readout(measure(View.BEFORE))
	_after_readout.text = _readout(measure(View.AFTER))


func _readout(numbers: Dictionary) -> String:
	return "rows %d apart · %d inside · text %d / %d / %d · same badge %d of %d · warnings %d of %d · %d dp tall" % [
		numbers.row_gap, numbers.row_inset, numbers.header, numbers.title, numbers.meta,
		numbers.badges, numbers.rows, numbers.warnings, numbers.rows, numbers.height]
