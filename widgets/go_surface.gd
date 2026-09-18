## 🪟 **The shell of a floating window.** Popups, sheets and dropdowns all use this one node.
##
## Safe area, virtual keyboard, pinned header/footer, scrolling body, topmost-window test, focus restore,
## back-navigation ownership and drag-to-resize are all handled in one place.
##
## ```gdscript
## var surface := GoSurface.new()
## surface.set_title("Settings")
## surface.body.add_child(GoStyle.label("Content"))
## surface.close_requested.connect(surface.queue_free)
## canvas_layer.add_child(surface)
## ```
##
## ## Three placements
## | `placement` | Looks like | Used for |
## |---|---|---|
## | `CENTER` | A card in the middle of the screen | Confirmations, settings |
## | `BOTTOM` | A sheet that rises from the bottom | Lists, management pages |
## | `ANCHOR` | A card attached beside a given control | Dropdowns, context menus |
##
## ## 🛑 This node never dismisses itself
## Taking `close_requested` and hiding or freeing the node is up to the **screen that owns it**. The shell
## cannot know why the window is closing (save and close vs. discard and close).
@tool
class_name GoSurface
extends Control

signal close_requested
signal back_requested
signal height_changed(ratio: float)

enum Placement { CENTER, BOTTOM, ANCHOR }

## Threshold for falling back from dense to normal density — padding returns only once this much room is free (stops flicker).
const RELAX := 0.85

## How many surfaces are open right now. Used to decide whether to pause game input.
static var _open_count := 0
## Was the last input from a keyboard or gamepad? 🛑 A window opened with a pointer gets **no focus ring** —
##    when a menu was merely opened by touch and only the close button glows, it reads as "press here".
static var _pointer_navigation := true

## Is any surface open at all?
static func is_any_open() -> bool:
	return _open_count > 0


# ── Placement ──────────────────────────────────────────────────────────

var placement := Placement.CENTER
var max_width := 0.0            ## 0 means `GoConfig.surface_max_width`
var max_height := 0.0           ## 0 means `GoConfig.surface_max_height`
var height_ratio := 0.0         ## 0 means `GoConfig.surface_height_ratio`
## 🔑 **This surface's ceiling on `height_ratio`.** 0 means `GoConfig.surface_max_height_ratio` (0.72).
## 🛑 Without it a `height_ratio` above the global ceiling is cut back to it — ask for 0.86 and get 0.72. That ceiling
##    exists so a window still reads as floating over the game; raise it here for the one surface that needs the room
##    (an inventory grid, a long list) instead of for every surface in `GoConfig`. A debug build warns once when a
##    requested ratio is cut.
var max_height_ratio := 0.0
## Short content makes a short card. Turn it off to always take up `height_ratio`.
var fit_content := true
## Drops padding and text one step on narrow screens.
var compact := false
## Can pressing the backdrop close it? Defaults to the config value.
var dismiss_on_scrim := false
## Make the scrim transparent — for a dropdown over the game screen, where what is behind must stay visible.
var scrim_transparent := false
## 🪟 **Opacity of the card background** (0.0~1.0) — for this one window only. Negative means the value the theme
## and config decide (`GoUi.surface_alpha(GoTheme.BOX_PANEL)` · 80% in the default theme).
##
## ```gdscript
## surface.alpha = 0.6    # 60% for this window only — a confirmation where the fight behind must show
## surface.alpha = 1.0    # fully opaque for this window only — a window for reading long text
## ```
##
## 🛑 **Only the card background** thins out. Title, body, buttons and icons stay crisp — if the content faded too,
##    the window would be unreadable, and that is not a transparent window but a broken one (use `modulate` for that).
## 🛑 The scrim (the veil behind) is separate — it is decided by the theme's `scrim` color and `scrim_transparent`.
var alpha := -1.0:
	set(value):
		alpha = value
		_restyle()
## Fade the card in when it opens.
var fade_in := false
## Can the height be changed by dragging (sheets)?
var resizable := false
var show_header := true
var scroll_body := true
var close_enabled := true
## Control to focus when opened. Without one, pointer input leaves focus nowhere.
var initial_focus: Control

## ANCHOR placement — attaches right below this control (above it when there is no room).
var anchor_control: Control
var anchor_width := 320.0
var anchor_min_width := 210.0
var anchor_max_height := 520.0

# ── Children ───────────────────────────────────────────────────────────

var card: PanelContainer
var header: HBoxContainer
var title_label: Label
var close_button: GoIconButton
var back_button: Button
var scroll: GoScroll
## The scrolling body. Most content goes in here.
var body: VBoxContainer
## A **pinned row** below the header and above the body (a search field, say). Hidden by default.
## 🛑 Put here what must not scroll away — inside the body it gets pushed out of sight when the sheet shrinks.
var toolbar: VBoxContainer
## A **pinned footer row** (confirm, cancel). Hidden by default. Inside the body it scrolls off screen on long lists.
var footer: VBoxContainer
## A **pinned status row** between the body and the footer — the **one line that must not be missed**, like "Passwords do not match".
## Hidden by default; turn it on with `set_status_*()`.
## 🛑 Do not put this row in the body — when an error in a long form lands outside the scroll, the screen looks as if
##    **nothing happened at all**, and the user waits, wondering "why is it not working" (measured 2026-09-16, Laryen account linking).
var status: VBoxContainer
## The label of the pinned status row. 🛑 **Created on first use** — screens that never use it grow no extra node.
var status_label: Label

var _scrim: ColorRect
var _column: VBoxContainer
var _margin: MarginContainer
var _content_padding := 0
## Are we at dense density right now (a narrow screen, or content that overflows).
var _dense := false
var _active := false
var _previous_focus: WeakRef
var _dragging := false
var _touch_index := -1
var _keyboard_px := 0
var _scrim_pressed := false
var _scrim_origin := Vector2.ZERO
var _holds_back := false
## A cut `height_ratio` has been reported (debug builds) — once per surface, since `relayout` runs every frame while content settles.
var _warned_height_cap := false
var _fade: Tween
var _runtime: Node


func _init() -> void:
	# The name is set in `_init` — setting it in `_ready` would overwrite a name the caller changed right after `new()`.
	name = "Surface"
	# 🛑 Config defaults are taken **here** — merging them in `_ready` as `dismiss_on_scrim or config` would let the
	#    config's `true` override an explicit `false` given right after `new()` (a trade sheet that must not close on a mistap).
	dismiss_on_scrim = GoUi.config.dismiss_on_scrim
	fade_in = GoUi.config.surface_fade_in
	_build()


## 🛑 Children are built **in `_init`** — calling `set_title()` or `body.add_child()` *before* the node is added to
##    the tree is perfectly natural usage, and building them in `_ready` leaves `title_label` still `null` at that
##    point, which dies with "Invalid assignment … on a base object of type 'Nil'" (measured 2026-09-12).
func _build() -> void:
	theme = GoUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Children scroll first. Unused wheel events stop at this window's edge — they never leak through to what is
	# behind: not at the end of a list, not over the chrome, not when content is too short to scroll at all.
	mouse_force_pass_scroll_events = false
	add_to_group(&"go_surfaces")

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = GoUi.color(GoTheme.SCRIM)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_scrim_input)
	add_child(_scrim)

	card = PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = GoTheme.VAR_PANEL
	card.clip_contents = true
	add_child(card)

	_margin = GoStyle.padding()
	card.add_child(_margin)
	_column = GoStyle.column()
	_margin.add_child(_column)

	header = GoStyle.row()
	header.name = "Header"
	_column.add_child(header)

	back_button = GoStyle.button_key(GoUi.text_key(&"back"), func() -> void: back_requested.emit(), GoStyle.Tone.COMPACT)
	back_button.name = "BackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 🛑 Wrapping is turned off — wrapping drops the minimum **width** to nearly 0, and under `SHRINK_BEGIN` that
	#    minimum width becomes the real width. All that is left is the capsule, with the label clipped away entirely.
	back_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	back_button.set_meta(&"go_no_wrap", true)
	back_button.visible = false
	header.add_child(back_button)

	title_label = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	title_label.name = "Title"
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	close_button = _make_close_button()
	close_button.name = "CloseButton"
	close_button.visual_size = GoUi.config.close_button_visual
	close_button.icon_name = GoIconSet.CLOSE
	close_button.tooltip_text_name = &"close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(request_close)
	header.add_child(close_button)

	toolbar = GoStyle.column()
	toolbar.name = "Toolbar"
	toolbar.visible = false
	_column.add_child(toolbar)

	body = GoStyle.column()
	body.name = "Body"
	_column.add_child(body)

	status = GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	# 🛑 Not a common name (`Status`) — when a host screen looks its own status row up by name, this one is found
	#    **first** and the wrong node comes back (that is how the Laryen profile screen test broke, 2026-09-16).
	status.name = "StatusLine"
	status.visible = false
	_column.add_child(status)

	footer = GoStyle.column()
	footer.name = "Footer"
	footer.visible = false
	_column.add_child(footer)


## Builds the close button. 🔑 A host that wants a `GoIconButton` subclass (its own art and size) overrides this in a
## subclass — the surface only uses the `GoIconButton` API.
func _make_close_button() -> GoIconButton:
	return GoIconButton.new()


## Builds the body scroll. 🔑 A host project that wants a `GoScroll` subclass (old type-hint compatibility, say) overrides
## this in a subclass — the surface only uses the `GoScroll` API.
func _make_scroll() -> GoScroll:
	return GoScroll.new()


func _ready() -> void:
	# Options that may have changed **between** `new()` and `add_child()` are applied here.
	_scrim.color = Color(0, 0, 0, 0) if scrim_transparent else GoUi.color(GoTheme.SCRIM)
	header.visible = show_header
	if resizable: attach_resize_handle(title_label)
	if scroll_body and scroll == null:
		# 🛑 The scroll is inserted here — `use_panel_edge()` can only push the scrollbar out into the card padding once
		#    the parent is known. Children already placed in the body come along unchanged.
		var slot := body.get_index()
		scroll = _make_scroll()
		_column.add_child(scroll)
		_column.move_child(scroll, slot)
		body.reparent(scroll)
		scroll.use_panel_edge(GoUi.metric(GoTheme.PADDING))
	elif not scroll_body:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_runtime = GoUi.runtime()
	if _runtime != null:
		if _runtime.has_signal(&"keyboard_changed"): _runtime.keyboard_changed.connect(_on_keyboard)
		if _runtime.has_signal(&"breakpoint_changed"): _runtime.breakpoint_changed.connect(func(_bp) -> void: relayout())
	get_viewport().size_changed.connect(relayout)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	visibility_changed.connect(_sync_active)
	# 🛑 Register `_on_ui_changed`, not the layout pass — when the config changes, **the panel opacity** has to be
	#    reapplied too. Relaying out alone leaves a window whose theme was swapped still wearing the old panel.
	GoUi.watch(_on_ui_changed)
	_restyle()
	relayout()
	_sync_active()


## Reapplies the card panel — this is where opacity is decided.
## 🛑 **Not called every frame** (`relayout` runs every frame on fit-content windows). It duplicates the stylebox, so it
##    costs more than a layout pass, and only needs doing on change — a config change, an `alpha` assignment, opening.
func _restyle() -> void:
	if card == null or not is_inside_tree(): return
	GoStyle.fade_panel(card, alpha, &"panel", GoTheme.BOX_PANEL)


## Config or theme changed. 🛑 **Forget** the remembered "original panel" and take it again — swapping the look
##    changes the panel itself, so putting the new opacity on the old panel leaves a card from the old theme.
func _on_ui_changed() -> void:
	GoStyle.forget_face(card)
	_restyle()
	relayout()


# ── Title ──────────────────────────────────────────────────────────────

## A translation key as the title — the engine redraws it when the language changes.
func set_title_key(key: String) -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	title_label.text = key


## An already-translated phrase or a person's name as the title.
func set_title(value: String) -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.text = value


## The back button used by sub-screens inside the same surface. An empty `Callable` hides it.
func set_back(action: Callable) -> void:
	for existing in back_requested.get_connections():
		back_requested.disconnect(existing.callable)
	if action.is_valid(): back_requested.connect(action)
	back_button.visible = action.is_valid()


# ── Pinned status row ──────────────────────────────────────────────────

## Pins an already-translated line above the footer row. An empty string hides the row.
## `tone` is a color token (`GoTheme.DANGER`·`WARNING`·`SUCCESS`·`MUTED` …) — leave it out for the body color.
func set_status_text(text: String, tone := StringName()) -> void:
	_set_status(text, tone, false)


## By translation key — the engine redraws it when the language changes.
func set_status_key(key: String, tone := StringName()) -> void:
	_set_status(key, tone, true)


## Hides the status row.
func clear_status() -> void:
	_set_status("", StringName(), false)


func _set_status(text: String, tone: StringName, translate: bool) -> void:
	if text.is_empty():
		if status_label != null: status_label.text = ""
		status.visible = false
		return
	if status_label == null:
		status_label = GoStyle.label("", GoTheme.ROLE_CAPTION)
		status_label.name = "StatusLineText"
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_child(status_label)
	status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	status_label.text = text
	GoStyle.typography(status_label, GoTheme.ROLE_CAPTION,
		GoUi.color(tone) if tone != StringName() else Color.TRANSPARENT)
	status.visible = true


## Empties the body.
func clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if scroll != null: scroll.scroll_vertical = 0


func request_close() -> void:
	if close_enabled and is_top(): close_requested.emit()


# ── Topmost test ───────────────────────────────────────────────────────

## Is this surface the topmost one — decided by the real draw order, nested `CanvasLayer`s included.
## 🛑 Without this, one Escape closes both windows when two of them overlap.
func is_top() -> bool:
	if not is_inside_tree() or not is_visible_in_tree(): return false
	var winner: GoSurface = self
	for node in get_tree().get_nodes_in_group(&"go_surfaces"):
		# 🛑 Narrow `node` to `GoSurface` first — the `for` variable is a `Node`, and calling `_layer_order()` on it
		#    directly leaves the return type un-inferable, which kills the whole script **at parse time**
		#    (the symptom is "Nonexistent function 'new' in base 'GDScript'" on `GoSurface.new()`).
		var candidate := node as GoSurface
		if candidate == null or not candidate.is_visible_in_tree(): continue
		var mine := winner._layer_order()
		var theirs := candidate._layer_order()
		if theirs > mine or (theirs == mine and candidate.is_greater_than(winner)): winner = candidate
	return winner == self


func _layer_order() -> int:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CanvasLayer: return ancestor.layer
		ancestor = ancestor.get_parent()
	return 0


# ── Lifetime and focus ─────────────────────────────────────────────────

func _sync_active() -> void:
	var next := is_visible_in_tree()
	if next == _active: return
	_active = next
	_dragging = false
	_touch_index = -1
	_scrim_pressed = false
	if next:
		if not _holds_back:
			GoBackPolicy.acquire(get_tree())
			_open_count += 1
			_holds_back = true
		var focus := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus) if focus != null and not is_ancestor_of(focus) else null
		if scroll != null: scroll.scroll_vertical = 0
		relayout()
		if fade_in: _fade = GoStyle.fade(card, _fade, true)
		_focus_default.call_deferred()
	else:
		_release_back()
		_restore_focus()


func _release_back() -> void:
	if not _holds_back: return
	_holds_back = false
	_open_count = maxi(0, _open_count - 1)
	GoBackPolicy.release(get_tree())


func _focus_default() -> void:
	if not is_top(): return
	if is_instance_valid(initial_focus) and initial_focus.is_visible_in_tree():
		initial_focus.grab_focus()
		return
	if GoUi.config.suppress_pointer_focus_ring and _pointer_navigation:
		# Opened with a pointer — no ring. Focus arrives the moment Tab is pressed.
		# 🛑 Make the screen behind drop its focus — left alone, Enter presses a button back there while the
		#    window is up. `_restore_focus` puts it back where it was on close.
		var outside := get_viewport().gui_get_focus_owner()
		if outside != null and not is_ancestor_of(outside): outside.release_focus()
		return
	if close_button.visible and not close_button.disabled:
		close_button.grab_focus()
		return
	var target := find_next_valid_focus()
	if target != null and is_ancestor_of(target): target.grab_focus()


func _focus_changed(target: Control) -> void:
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return
	# Never leave focus outside the window — Enter must not press a button on the screen behind.
	if GoUi.config.suppress_pointer_focus_ring and _pointer_navigation and not is_instance_valid(initial_focus):
		target.release_focus.call_deferred()
	else:
		_focus_default.call_deferred()


func _restore_focus() -> void:
	if _previous_focus == null: return
	var previous := _previous_focus.get_ref() as Control
	_previous_focus = null
	if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
		previous.grab_focus.call_deferred()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	_release_back()
	_restore_focus()


# ── Layout math ────────────────────────────────────────────────────────

## The ceiling on `height_ratio` in force for this surface — its own `max_height_ratio`, or the config's.
func height_ratio_cap() -> float:
	return max_height_ratio if max_height_ratio > 0.0 else GoUi.config.surface_max_height_ratio


## 🛑 A ratio that is silently cut costs an afternoon ("I asked for 0.86 and got 0.72") — say so once, in debug builds.
func _warn_height_cap(ratio: float, ratio_cap: float) -> void:
	if _warned_height_cap or not OS.is_debug_build() or Engine.is_editor_hint(): return
	_warned_height_cap = true
	push_warning("gohud: %s asks for height_ratio %.2f but is capped at %.2f — set max_height_ratio on this surface (or GoConfig.surface_max_height_ratio for all)."
		% [String(get_path()) if is_inside_tree() else String(name), ratio, ratio_cap])


func relayout() -> void:
	if card == null or not is_inside_tree(): return
	var settings := GoUi.config
	var area := GoSafeArea.usable_rect_with_keyboard(get_window(), _keyboard_px)
	if placement == Placement.ANCHOR and is_instance_valid(anchor_control) and anchor_control.is_inside_tree():
		_update_density()
		_relayout_anchor(area)
		return
	# Keeps at least this much off the screen edge — on very narrow screens it shrinks proportionally.
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN))
	area = area.grow(-minf(edge, minf(area.size.x, area.size.y) * 0.1))
	var landscape := area.size.x > area.size.y
	var width_ratio := settings.surface_width_ratio_landscape if landscape else settings.surface_width_ratio_portrait
	var cap_width := max_width if max_width > 0.0 else settings.surface_max_width
	var cap_height := max_height if max_height > 0.0 else settings.surface_max_height
	var ratio := height_ratio if height_ratio > 0.0 else settings.surface_height_ratio
	var ratio_cap := height_ratio_cap()
	if ratio > ratio_cap + 0.001: _warn_height_cap(ratio, ratio_cap)
	var width := maxf(1.0, minf(cap_width, area.size.x * width_ratio))
	var height := maxf(1.0, minf(cap_height, area.size.y * minf(ratio, ratio_cap)))
	if fit_content:
		# 🔑 Short content shrinks it, and **long content grows it as far as the screen allows.** Scrolling while screen
		#    space is left over makes users who never noticed the scroll submit with unseen fields empty (`surface_fit_max_height_ratio`).
		#    🛑 Drag-resizable sheets and bottom sheets are not grown — their height is the user's own choice.
		var room := height
		if placement == Placement.CENTER and not resizable:
			room = maxf(room, minf(cap_height, area.size.y * settings.surface_fit_max_height_ratio))
		# If it looks like overflowing, try one step less padding and gap — then measure again.
		_update_density(room)
		height = clampf(_desired_height(), 1.0, room)
	else:
		_update_density()
	# 🛑 Size and position are given as integers — at a fractional position (centered · logical width 349.09) the size is
	#    stored as "position + size" and 184 becomes 183.99997, the card's inner padding (MarginContainer) floors child
	#    sizes to integers, and the body came out 1px short — a scrollbar appeared beside the one-line body of the first
	#    confirmation (measured 2026-09-15 on a Laryen phone in portrait · does not reproduce at headless logical sizes).
	card.size = Vector2(width, height).round()
	var y := area.position.y + (area.size.y - card.size.y) * (1.0 if placement == Placement.BOTTOM else 0.5)
	card.position = Vector2(area.position.x + (area.size.x - card.size.x) * 0.5, y).round()


## Drops padding and title size one step when space runs short — making room for content on small screens.
##
## Pass `room` (greater than 0) to drop a step **when the content overflows that height** as well — a form with the
## virtual keyboard covering half the screen, say: not much room, yet everything has to be visible.
## 🛑 Coming back needs slack (`RELAX`) — measuring right at the boundary makes the padding shrink and grow, flickering.
func _update_density(room := 0.0) -> void:
	var small := compact or get_viewport_rect().size.y < 420
	if not small and room > 0.0:
		small = _desired_height() > (room * RELAX if _dense else room)
	_dense = small
	var token := GoTheme.PADDING_COMPACT if small else GoTheme.PADDING
	var next := GoUi.metric(token)
	if _content_padding != next:
		_content_padding = next
		GoStyle.insets(_margin, next)
		GoStyle.gap(_column, GoTheme.GAP_SMALL if small else GoTheme.GAP)
		if scroll != null: scroll.set_panel_padding(next)
	var role := GoTheme.ROLE_BODY if small else GoTheme.ROLE_SUBTITLE
	if title_label.get_meta(&"go_text_role", &"") != role: GoStyle.typography(title_label, role)


## The card's inner padding (dp) — one step smaller on narrow screens. 🔑 Decided after `relayout`.
func content_inset() -> int:
	return _content_padding


## The **actually applied** gap (dp) between header, pinned rows, body and footer — one step smaller on narrow screens.
func section_gap() -> int:
	return _column.get_theme_constant(&"separation")


## The card height the content asks for (padding + header + pinned rows + body + footer).
## 🛑 Leave `toolbar` out and a sheet with its search field on comes up exactly that much shorter, clipping the last row of the list.
## 🛑 Section gaps are counted from the **value actually applied** — hard-coding the `gap` token grew the card by that difference
##    at every section on narrow screens (where the gap is `gap_small`), opening a hole between body and buttons in short confirmations.
func _desired_height() -> float:
	var desired := float(_content_padding * 2)
	var gap := float(section_gap())
	if header.visible: desired += header.get_combined_minimum_size().y + gap
	if toolbar.visible: desired += toolbar.get_combined_minimum_size().y + gap
	desired += body.get_combined_minimum_size().y
	if status.visible: desired += status.get_combined_minimum_size().y + gap
	if footer.visible: desired += footer.get_combined_minimum_size().y + gap
	return desired


## Attaches beside the given control — to the right if the minimum width fits there, otherwise to the wider side, and if
## neither fits, pulled inside the screen. Opens upward when there is less room below than above.
func _relayout_anchor(area: Rect2) -> void:
	var anchor := anchor_control.get_global_rect()
	var edge := 8.0
	var gap := 7.0
	var space_right := area.end.x - anchor.position.x - edge
	var space_left := anchor.end.x - area.position.x - edge
	var width := anchor_width
	var x := anchor.position.x
	if space_right < anchor_min_width and space_left < anchor_min_width:
		width = clampf(area.size.x - edge * 2, 1, anchor_width)
		x = area.position.x + edge
	elif space_right >= anchor_min_width or space_right >= space_left:
		width = clampf(space_right, anchor_min_width, anchor_width)
	else:
		width = clampf(space_left, anchor_min_width, anchor_width)
		x = anchor.end.x - width
	var below := area.end.y - anchor.end.y - gap - edge
	var above := anchor.position.y - area.position.y - gap - edge
	var opens_up := below < above
	var cap := minf(anchor_max_height, area.size.y * height_ratio_cap())
	var height := clampf(above if opens_up else below, 0, cap)
	if fit_content: height = minf(height, _desired_height())
	card.size = Vector2(maxf(1, width), maxf(1, height)).round()
	# When the pinned header and footer are bigger than the room left, the card grows to its minimum size — then it is pushed inside the screen.
	var y := anchor.position.y - gap - card.size.y if opens_up else anchor.end.y + gap
	y = clampf(y, area.position.y + edge, maxf(area.position.y + edge, area.end.y - edge - card.size.y))
	x = clampf(x, area.position.x + edge, maxf(area.position.x + edge, area.end.x - edge - card.size.x))
	# 🛑 Integers — a fractional position makes the size 183.99997 and the body loses 1px (see the `relayout` comment).
	card.position = Vector2(x, y).round()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_sync_active()
	if not _active: return
	close_button.disabled = not close_enabled
	# Without the autoload the keyboard is polled here (with it, it arrives as a signal).
	if _runtime == null and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_on_keyboard(DisplayServer.virtual_keyboard_get_height())
	if fit_content: relayout()


func _on_keyboard(height_px: int) -> void:
	if height_px == _keyboard_px: return
	_keyboard_px = height_px
	relayout()
	# 🛑 Out of the tree (a scene change removes it before freeing it) `get_viewport()` is null — see `GoForm._on_keyboard`.
	if scroll == null or not is_inside_tree(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and scroll.is_ancestor_of(focus): scroll.ensure_control_visible.call_deferred(focus)


# ── Input ──────────────────────────────────────────────────────────────

func _scrim_input(event: InputEvent) -> void:
	if not dismiss_on_scrim or not is_top(): return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT): return
	if event.pressed:
		_scrim_pressed = true
		_scrim_origin = event.position
	else:
		# 🛑 Closes **only when the press did not drag** — a drag that started inside the card and ended outside
		#    must not close the window.
		if _scrim_pressed and _scrim_origin.distance_to(event.position) < GoUi.metric(GoTheme.SCROLL_DEADZONE):
			request_close()
		_scrim_pressed = false


func _gui_input(event: InputEvent) -> void:
	# `MOUSE_FILTER_STOP` does not swallow zoom and pan gestures in Godot.
	# Nested controls see them first, so only what is left over is stopped here.
	if event is InputEventGesture: accept_event()


## Drag to resize — grab the sheet's header and move it up or down.
func attach_resize_handle(handle: Control) -> void:
	resizable = true
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	if not handle.gui_input.is_connected(_resize_input): handle.gui_input.connect(_resize_input)
	handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE


func _resize_input(event: InputEvent) -> void:
	if not resizable or not is_top(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_touch_index = event.index if event.pressed else -1


func _input(event: InputEvent) -> void:
	_track_device(event)
	if not is_top():
		_dragging = false
		return
	if GoUi.config.close_on_back and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		request_close()
		get_viewport().set_input_as_handled()
		return
	if not _dragging: return
	var dy := 0.0
	if event is InputEventScreenDrag and event.index == _touch_index: dy = event.relative.y
	elif event is InputEventMouseMotion and _touch_index < 0: dy = event.relative.y
	elif (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		_dragging = false
		_touch_index = -1
	if not is_zero_approx(dy):
		var area := GoSafeArea.usable_rect(get_window())
		var current := height_ratio if height_ratio > 0.0 else GoUi.config.surface_height_ratio
		# 🛑 The same ceiling the layout uses — clamped to 0.95 here while the layout stopped at 0.72, a drag past the
		#    ceiling moved nothing, `height_changed` reported a height that was never drawn, and dragging back down did
		#    nothing until the finger had undone the invisible part.
		height_ratio = clampf(current - dy / maxf(1.0, area.size.y), minf(0.3, height_ratio_cap()), height_ratio_cap())
		relayout()
		height_changed.emit(height_ratio)
	get_viewport().set_input_as_handled()


## Records which device is in use. Events arrive while the window is in the tree even when it is hidden, so
## **the input right before the window opened** (a button tap or the Tab key) is what counts.
func _track_device(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_pointer_navigation = true
	elif event is InputEventJoypadButton or (event is InputEventKey and event.pressed and not event.is_echo()):
		_pointer_navigation = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and GoUi.config.close_on_back and is_top():
		# Deferred so that one OS notification does not close several stacked windows.
		request_close.call_deferred()
