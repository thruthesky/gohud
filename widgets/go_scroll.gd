## 📜 One vertical scroll box. Finger dragging, focus following and edge insets handled in one place.
##
## ## Put exactly one thing inside
## Keep the header and the button row **outside**. When the list grows long they must not leave the screen.
##
## ```gdscript
## var scroll := GoScroll.new()
## scroll.add_child(body_column)      # a single child
## card.add_child(scroll)
## ```
##
## ## 🔑 Keeping the scrollbar off the text
## Call `use_panel_edge()` and the scrollbar moves out into **the card's existing padding**, while the
## content keeps its original indent. When there is no scrollbar the content takes that space back.
@tool
class_name GoScroll
extends ScrollContainer

var _edge_frame: MarginContainer
var _content_inset: MarginContainer
var _edge_gutter := 0
## How far the scroll bounds are pushed outward so a glow has room to spread (dp).
var _bleed := 0
## The parent card's padding (dp) — the room the edge insets borrow.
var _panel_padding := 0
## How far the parent card's frame reaches into that padding, per side (left, top, right, bottom, dp).
var _panel_frame := Vector4.ZERO
## Bring a descendant into view when **keyboard or gamepad** focus lands on it. Use this instead of the
## engine's `follow_focus`, which stays off here (see `_init`).
@export var follow_keyboard_focus := true
## Children whose mouse was switched off for a finger drag, with the value to put back.
var _drag_muted := {}
## Branches that entered this frame (node → true) — the touch policy runs over them once more after the frame's code is done.
var _settling := {}
## 🔑 Set by `as_horizontal()`: a horizontal row is PASS **only while another scroll holds it**, so an up-and-down swipe
##    on the row reaches the sheet around it. Standing alone (a strip in a HUD over the game) it is STOP — otherwise a
##    press nothing takes runs on to `_unhandled_input` and reaches the world: on a card, in the gap between two chips,
##    even on a button (a `Button` does not accept the press). Decided each time the row enters the tree.
##    🛑 A `mouse_filter` the caller set after `as_horizontal()` wins — the row stops deciding (`_place_filter`).
var _filter_by_holder := false
## The filter `_place_filter` last gave — anything else in `mouse_filter` was the caller's choice.
var _holder_filter := Control.MOUSE_FILTER_PASS

## 🔑 Meta key a screen sets to `true` on a control that **owns a competing drag** inside a scroll (a pannable map,
## a drawing pad, a value scrubber of its own). `GoScroll` then leaves that control's `mouse_filter` alone.
## Say why next to the line — every other control inside a scroll lets the finger through.
const OWNS_GESTURE := &"go_scroll_owns_gesture"

## 🔑 Meta key a control sets when **its own drag is sideways** (a range slider, a swipe row of its own): it keeps its
## press like a slider, and an up-and-down swipe that starts on it still scrolls the list (`yields_vertical`).
## A `GoTabView` does not turn its page from a press that lands on it either.
const SIDEWAYS := &"go_scroll_sideways"

## A press held back until the finger shows which way it is going (`_arbitrate`) — see `_input`.
var _touch := {}
## True while a held press is handed back to the viewport — every scroll's and every `_Yield`'s `_input` lets it pass,
## so exactly one of them holds a press.
static var _replaying := false
## Meta that `scroll_through()` leaves on a control: whether the PASS it has now was set by that function.
const _THROUGH := &"go_scroll_through"


func _init() -> void:
	name = "Scroll"
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_AUTO
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 🛑 The engine's `follow_focus` also fires on the focus a **finger press** hands out — press a row half
	#    under the edge to start a drag and the list jumps to it before the finger has moved. `_on_focus_changed`
	#    follows keyboard and gamepad focus only.
	follow_focus = false
	scroll_started.connect(_on_drag_started)
	scroll_ended.connect(_on_drag_ended)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 🛑 The scroll **rail is always on the physical right** — in Arabic and Urdu as well.
	#    The children each decide the direction of their own content (`_prepare_branch` puts them back to LOCALE).
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	theme = GoUi.theme()
	scroll_deadzone = GoUi.metric(GoTheme.SCROLL_DEADZONE)
	child_entered_tree.connect(_on_branch_entered)
	for child in get_children(): _on_branch_entered(child)


func _enter_tree() -> void:
	var viewport := get_viewport()
	if not viewport.gui_focus_changed.is_connected(_on_focus_changed):
		viewport.gui_focus_changed.connect(_on_focus_changed)
	if _filter_by_holder: _place_filter()


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport.gui_focus_changed.is_connected(_on_focus_changed):
		viewport.gui_focus_changed.disconnect(_on_focus_changed)
	_on_drag_ended()


## A scroll that runs horizontally (a row of chips, a row of thumbnails).
static func horizontal() -> GoScroll:
	return as_horizontal(GoScroll.new())


## Just the settings `horizontal()` applies — for a subclass rebuilding the same factory with its own instance
## (`static func horizontal() -> Child: return GoScroll.as_horizontal(Child.new())`). A static function cannot know the subclass type.
static func as_horizontal(node: GoScroll) -> GoScroll:
	node.horizontal_scroll_mode = SCROLL_MODE_AUTO
	node.vertical_scroll_mode = SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_FILL
	# PASS until it enters the tree — `_place_filter` then turns a row that no scroll holds to STOP.
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node._holder_filter = Control.MOUSE_FILTER_PASS
	node._filter_by_holder = true
	return node


## PASS inside another scroll, STOP standing alone (see `_filter_by_holder`).
## 🔑 Re-run on every entry: `GoSurface` builds its body **before** it wraps the body in a scroll, so a row placed in
##    the body enters once alone, then again inside the scroll.
func _place_filter() -> void:
	if mouse_filter != _holder_filter:
		_filter_by_holder = false
		return
	_holder_filter = Control.MOUSE_FILTER_PASS if _held_by_scroll() else Control.MOUSE_FILTER_STOP
	mouse_filter = _holder_filter


## Is there a scroll above this one that a passed event can reach? GUI input climbs parent controls only, and stops
## at a `top_level` one.
func _held_by_scroll() -> bool:
	var ancestor := get_parent() as Control
	while ancestor != null:
		if ancestor is ScrollContainer: return true
		if ancestor.top_level: return false
		ancestor = ancestor.get_parent() as Control
	return false


## The `GoScroll` this node sits inside (null if there is none).
static func containing(node: Node) -> GoScroll:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is GoScroll: return ancestor
		ancestor = ancestor.get_parent()
	return null


## Move the scrollbar out into the parent's existing right padding, keeping the content's original indent.
## `parent_padding` is the padding the parent card uses (dp).
func use_panel_edge(parent_padding: int) -> void:
	if _edge_frame != null: return
	_panel_padding = parent_padding
	var parent := get_parent()
	if parent == null: return
	var index := get_index()
	_edge_frame = MarginContainer.new()
	_edge_frame.name = name + "Edge"
	_edge_frame.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_edge_frame.size_flags_horizontal = size_flags_horizontal
	_edge_frame.size_flags_vertical = size_flags_vertical
	_edge_frame.size_flags_stretch_ratio = size_flags_stretch_ratio
	# 🛑 **Leave breathing room so glows and shadows are not clipped.** A scroll clips at its own bounds,
	#    no exceptions — a full-width accent button had its left glow sheared off in a straight vertical line
	#    (measured 2026-09-13; the right side survived thanks to the rail gutter, so the two sides looked
	#    different). Borrow the parent padding to push the bounds outward, then give the same amount back on
	#    the inside so **the content does not move** — the same trick as the right-hand rail (`_apply_edge`).
	parent.add_child(_edge_frame)
	parent.move_child(_edge_frame, index)
	_reparent_keeping_owners(self, _edge_frame)
	var content := get_children()
	_content_inset = MarginContainer.new()
	_content_inset.name = "ContentInset"
	_content_inset.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_content_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content_inset)
	for child in content: _reparent_keeping_owners(child, _content_inset)
	var bar := get_v_scroll_bar()
	bar.visibility_changed.connect(_sync_edge_inset)
	bar.resized.connect(_sync_edge_inset)
	_apply_edge()


## Move with `reparent()` while preserving the descendants' owners.
## 🛑 The engine's `reparent()` only restores the owner of descendants that share **the same owner** as the node
##    being moved. In a form assembled in code, where only a button is owned (`back.owner = form`) and the scroll
##    has no owner, moving the scroll into the edge frame wiped the button's owner, `%BackButton` was no longer
##    found and the Android back gesture silently stopped working (measured 2026-09-15, 4.7.2). It never shows up
##    in a `.tscn` where the scene root owns everything.
static func _reparent_keeping_owners(node: Node, new_parent: Node) -> void:
	var owners := {}
	if node.owner != null: owners[node] = node.owner
	for each in node.find_children("*", "", true, false):
		if each.owner != null: owners[each] = each.owner
	node.reparent(new_parent)
	for each: Node in owners:
		var keep: Node = owners[each]
		if each.owner != keep and is_instance_valid(keep) and keep.is_ancestor_of(each): each.owner = keep


## For when the card narrowed and the padding changed — fixes only the insets, without rebuilding the scroll and content ownership.
func set_panel_padding(padding: int) -> void:
	if _edge_frame == null: return
	_panel_padding = padding
	_apply_edge()


## 🔑 **Keep what scrolls under the card's frame.** [param frame] is how far the parent card draws its frame into the
## padding on each side (left, top, right, bottom, dp — `GoSkin.frame_margin` minus the card's own content margin).
## The edge insets borrow the padding only up to that frame, so a row scrolled past the edge is clipped at the frame's
## inner side and slides **under** the outline, inner line and lip instead of over them.
## 🛑 Found on the kids window (2026-10-07): a card with no content margin, a 12dp compact padding fully borrowed for
##    glows, and the clip landed on the card's outer edge — the menu rows crossed the jelly frame while scrolling.
## A frame thicker than the padding pulls the scroll inside it; the content moves in by the difference.
func set_panel_frame(frame: Vector4) -> void:
	_panel_frame = Vector4(maxf(0.0, frame.x), maxf(0.0, frame.y), maxf(0.0, frame.z), maxf(0.0, frame.w))
	_apply_edge()


## The edge insets from the padding and the frame. Left, top and bottom are pushed out by up to `gap` for glows (and
## the same given back inside); the right side holds the scrollbar `scroll_edge` from the card edge. Neither ever
## reaches into the frame — where the frame is thicker than the padding, the inset turns inward.
func _apply_edge() -> void:
	if _edge_frame == null: return
	var room := [_panel_padding - ceili(_panel_frame.x), _panel_padding - ceili(_panel_frame.y),
		_panel_padding - ceili(_panel_frame.z), _panel_padding - ceili(_panel_frame.w)]
	_edge_gutter = mini(maxi(0, _panel_padding - GoUi.metric(GoTheme.SCROLL_EDGE)), room[2])
	_edge_frame.add_theme_constant_override(&"margin_right", -_edge_gutter)
	_bleed = mini(GoUi.metric(GoTheme.GAP), _panel_padding)
	for pair: Array in [[&"margin_left", room[0]], [&"margin_top", room[1]], [&"margin_bottom", room[3]]]:
		var bleed := mini(_bleed, int(pair[1]))
		_edge_frame.add_theme_constant_override(pair[0], -bleed)
		_content_inset.add_theme_constant_override(pair[0], maxi(0, bleed))
	_sync_edge_inset()


## 🔑 **Bring this descendant into view** — for taking the user to the thing they have to fix, like the field behind 「Passwords do not match」.
##
## 🛑 Calling `ensure_control_visible()` right there misses — the error line has just appeared and the card height
##    is still changing, so the engine scrolls against the **old position** (measured 2026-09-16: only 54% was revealed).
##    Wait the two frames layout takes, then call it.
func reveal(control: Control) -> void:
	if not is_instance_valid(control) or not is_ancestor_of(control): return
	for i in 2:
		await get_tree().process_frame
		if not (is_inside_tree() and is_instance_valid(control) and is_ancestor_of(control)): return
	ensure_control_visible(control)


## Show and hide the whole scroll section together (the edge frame included).
func set_section_visible(value: bool) -> void:
	if _edge_frame != null: _edge_frame.visible = value
	visible = value


func _sync_edge_inset() -> void:
	if _content_inset == null: return
	var bar := get_v_scroll_bar()
	var reserved := 0
	if bar.visible:
		reserved = ceili(bar.get_combined_minimum_size().x) + get_theme_constant(&"scrollbar_h_separation")
	_content_inset.add_theme_constant_override(&"margin_right", maxi(0, _edge_gutter - reserved))


## 🔑 **The touch policy: a finger drag that starts on anything in the list reaches the scroll.**
## `ScrollContainer` starts a drag-to-scroll in its own `gui_input`, so it only sees the presses and motions its
## children pass up. Every `MOUSE_FILTER_STOP` control in between eats them — and STOP is the engine default for
## `PanelContainer`, `Panel`, `ColorRect`, `RichTextLabel` and `Button`, the very things cards, plates and text
## bodies are made of (measured 4.7.2). So inside a scroll every STOP becomes PASS, except where the control's own
## drag means something (`owns_gesture`). Once the drag passes the deadzone the engine cancels the button press
## for us (`NOTIFICATION_SCROLL_BEGIN`), and `_on_drag_started` mutes the rest.
## 🛑 Only inside a scroll. The scroll itself stays STOP, so a pass never reaches the world behind the sheet —
##    a HUD control floating over the world is never a scroll descendant and keeps its STOP.
## 🛑 The policy runs when a branch enters **and once more after that frame** (`_settle`) — a caller that adds a
##    card and then sets `mouse_filter = STOP` on it, or a widget whose `_ready` sets STOP, would otherwise win.
func _prepare_branch(node: Node) -> void:
	if node is ScrollBar or node is ScrollContainer: return
	if node is Control and node.get_parent() == self and node.layout_direction == Control.LAYOUT_DIRECTION_INHERITED:
		node.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE  # the 4.4+ name — `LOCALE` is a deprecated alias
	_let_finger_through(node)
	if not node.child_entered_tree.is_connected(_on_branch_entered):
		node.child_entered_tree.connect(_on_branch_entered)
	for child in node.get_children(): _prepare_branch(child)


func _on_branch_entered(node: Node) -> void:
	_prepare_branch(node)
	if _settling.is_empty(): _settle.call_deferred()
	_settling[node] = true


func _let_finger_through(node: Node) -> void:
	var control := node as Control
	if control == null or owns_gesture(control): return
	# Buttons keep their old rule: PASS even when set IGNORE, so a row stays pressable.
	if control is Button or control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func _settle() -> void:
	var branches := _settling
	_settling = {}
	# 🛑 Untyped loop variable — a row freed in the frame it entered is still a key here, and assigning a freed
	#    instance to `branch: Node` is a script error that ends the pass, leaving every row after it STOP
	#    (Laryen's inventory rebuilds its rows in place, 2026-10-02).
	for key: Variant in branches:
		if not is_instance_valid(key): continue
		var branch := key as Node
		if not is_ancestor_of(branch): continue
		# A branch inside another queued branch is walked with it — walk each node once.
		var outer := branch.get_parent()
		while outer != self and not branches.has(outer): outer = outer.get_parent()
		if outer == self: _settle_branch(branch)


func _settle_branch(node: Node) -> void:
	if node is ScrollBar or node is ScrollContainer: return
	_let_finger_through(node)
	for child in node.get_children(): _settle_branch(child)


## 🔑 **Does this control's own drag mean something?** Then it keeps its press (STOP) — and only if that drag is
## sideways or a tap (`yields_vertical`) does an up-and-down swipe that starts on it still scroll the list.
## - text fields: a press places the caret and a drag selects (`LineEdit`, `TextEdit`),
## - a text body the player may select and copy (`RichTextLabel.selection_enabled`),
## - value controls whose drag *is* the value: `Slider`, `ScrollBar`, `SpinBox` (a `ProgressBar` takes no input),
## - `OptionButton` — its popup opens on the press,
## - lists with their own scroll and selection: `ItemList`, `Tree`, `GraphEdit`,
## - anything a screen marked with [constant OWNS_GESTURE] (a pannable map, a drawing pad).
## 🛑 A plain `RichTextLabel` is not one — link (`meta`) taps still work through PASS, and a swipe that ends on a
##    link does not open it (`_on_drag_started` turns the rows' mouse off until the scroll stops).
static func owns_gesture(control: Control) -> bool:
	if control.has_meta(OWNS_GESTURE): return bool(control.get_meta(OWNS_GESTURE))
	if control.has_meta(SIDEWAYS): return true
	if control is LineEdit or control is TextEdit or control is OptionButton: return true
	if control is RichTextLabel: return (control as RichTextLabel).selection_enabled
	if control is Range: return not (control is ProgressBar or control is TextureProgressBar)
	return control is ItemList or control is Tree or control is GraphEdit


## 🔑 **Is this gesture owner's own gesture sideways or a tap?** Then an up-and-down swipe that starts on it scrolls the
## list (`_input`) — it has no up-and-down of its own to lose:
## - a single-line field (`LineEdit`, also the hidden one under `GoCodeInput` and the one in a `GoField`),
## - a horizontal slider (`HSlider`),
## - a multi-line field whose text still fits (`TextEdit` with no vertical scrollbar showing),
## - anything that acts **on the press** rather than the release — a dropdown (`OptionButton`, `MenuButton`, any button
##   with `ACTION_MODE_BUTTON_PRESS`) and a tab row (`TabBar` switches on the press). A button that acts on the release
##   needs none of this: the engine cancels its press when the list starts to move. These cannot wait for that — a
##   swipe that started on a tab switched the tab (seen on a Galaxy A17, 2026-10-02).
## A control that moves up and down itself keeps the whole gesture: a vertical slider, a scrollbar, a spin box (an
## up-and-down drag changes its value), a `TextEdit` that scrolls, `ItemList`·`Tree`·`GraphEdit`, and anything a screen
## marked with [constant OWNS_GESTURE].
static func yields_vertical(control: Control) -> bool:
	if control.has_meta(OWNS_GESTURE): return false
	if control.has_meta(SIDEWAYS): return true
	if control is LineEdit: return not (control.get_parent() is SpinBox)
	if control is HSlider or control is TabBar: return true
	if control is BaseButton: return (control as BaseButton).action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS
	if control is TextEdit: return not (control as TextEdit).get_v_scroll_bar().visible
	return false


## 🔑 **A gohud part that takes no drag of its own lets a finger swipe through to the scroll that holds it** — any
## scroll: this one, or the engine's plain `ScrollContainer`, which runs none of the touch policy above.
## STOP is the engine default for a tab row, a progress bar and a panel, and inside a plain scroll it ate every swipe
## that started on one (2026-10-02). The part turns PASS when it enters a tree under a `ScrollContainer` and keeps its
## own filter anywhere else — standing over the game, a press on it must still stop there. Returns [param control].
## 🛑 Only a filter still at STOP is changed, and a PASS this function set is put back when the part leaves the scroll.
static func scroll_through(control: Control) -> Control:
	if control == null or control.has_meta(_THROUGH): return control
	control.set_meta(_THROUGH, false)
	control.tree_entered.connect(_place_through.bind(control))
	return control


static func _place_through(control: Control) -> void:
	var inside := false
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			inside = true
			break
		node = node.get_parent()
	if inside and control.mouse_filter == Control.MOUSE_FILTER_STOP and not owns_gesture(control):
		control.mouse_filter = Control.MOUSE_FILTER_PASS
		control.set_meta(_THROUGH, true)
	elif not inside and bool(control.get_meta(_THROUGH, false)) and control.mouse_filter == Control.MOUSE_FILTER_PASS:
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		control.set_meta(_THROUGH, false)


## 🔑 **An up-and-down swipe scrolls the list even when it starts on a slider, a text field or a dropdown.**
## Those keep their press (`owns_gesture`) — a slider moves sideways, a field places its caret, a dropdown opens on the
## press — but none of them scrolls up and down (`yields_vertical`). So a finger that lands on one is held back here,
## before the GUI sees it, until it shows where it is going:
## - up or down past the deadzone → the press goes to the list instead (the control is skipped for that one press),
##   and the list follows the finger as it does from any other row;
## - sideways past the deadzone, or a lift without moving → the press goes to the control as if it had just arrived,
##   so a slider drags, a tap places the caret, a dropdown opens.
## Android's ScrollView treats a SeekBar or an EditText the same way.
## 🛑 Touch only — with a mouse the list does not drag-scroll (`DisplayServer.is_touchscreen_available()` is false),
##    so a press goes straight to the control as before.
## 🛑 The innermost scroll decides (`containing()`); a press on a control in a row inside this list is that row's to hold.
func _input(event: InputEvent) -> void:
	if _replaying or Engine.is_editor_hint() or not is_visible_in_tree(): return
	_arbitrate(event, _touch, _held_target, float(scroll_deadzone), get_viewport())


func _held_target(point: Vector2) -> Control:
	var target := control_at(self, point)
	return target if target != null and yields_vertical(target) and containing(target) == self else null


## 🔑 **The arbiter shared by every scroll and every `_Yield`.** [param state] keeps the held press between events,
## [param find] maps a press point to the control to hold (or `null`: the press goes on untouched).
## 🛑 A real finger arrives twice — as `InputEventScreenTouch`/`ScreenDrag` and as the mouse events the engine makes from
##    them — and a control may answer either: holding only the mouse press, a dropdown still opened on the touch (measured
##    on a Galaxy A17, 2026-10-02). So both presses of the first finger are held, and handed on together.
static func _arbitrate(event: InputEvent, state: Dictionary, find: Callable, deadzone: float, viewport: Viewport) -> void:
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if (touch != null and touch.index != 0) or (click != null and click.button_index != MOUSE_BUTTON_LEFT): return
	if touch != null or click != null:
		var pressed := touch.pressed if touch != null else click.pressed
		var point: Vector2 = touch.position if touch != null else click.position
		if pressed:
			if state.is_empty():
				if not DisplayServer.is_touchscreen_available(): return
				var target: Control = find.call(point)
				if target == null: return
				state.merge({"control": target, "presses": [], "start": point, "way": &""})
			elif state["way"] != &"" or point.distance_to(state["start"]) > 1.0:
				return
			(state["presses"] as Array).append(event.duplicate())
			viewport.set_input_as_handled()
		elif not state.is_empty():
			# A tap: the control gets its presses now, and this release right after them.
			if state["way"] == &"": _replay_all(viewport, state["presses"])
			state.clear()
		return
	var drag := event as InputEventScreenDrag
	var motion := event as InputEventMouseMotion
	if (drag == null and motion == null) or (drag != null and drag.index != 0): return
	if state.is_empty() or state["way"] != &"": return
	# 🔑 The direction is read from **one stream** — the mouse one the GUI itself follows. The touch drags of the same
	#    finger are held while the press is, then let through. (Touch made from a mouse, as the headless checks make it,
	#    carries drag positions in another space: read from them, every sideways drag came out vertical.)
	#    Only a project that turned the mouse-from-touch emulation off has no mouse stream to read — then the touch decides.
	if drag != null and ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		viewport.set_input_as_handled()
		return
	var at: Vector2 = drag.position if drag != null else motion.position
	var step: Vector2 = drag.relative if drag != null else motion.relative
	var travelled: Vector2 = at - state["start"]
	if travelled.length() < maxf(deadzone, 8.0):
		viewport.set_input_as_handled()
		return
	var control: Control = state["control"] if is_instance_valid(state["control"]) else null
	if control != null and absf(travelled.y) > absf(travelled.x):
		state["way"] = &"vertical"
		# The presses land on what lies under the control — the list — and the GUI keeps sending this finger there.
		var filter := control.mouse_filter
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay_all(viewport, state["presses"])
		control.mouse_filter = filter
		# Catch the list up with the distance already travelled; this motion then carries on as usual.
		var catch_up := event.duplicate()
		catch_up.set(&"relative", travelled - step)
		catch_up.set(&"position", at - step)
		_replay(viewport, catch_up)
	else:
		state["way"] = &"sideways"
		_replay_all(viewport, state["presses"])


static func _replay_all(viewport: Viewport, events: Array) -> void:
	for event: InputEvent in events: _replay(viewport, event)


static func _replay(viewport: Viewport, event: InputEvent) -> void:
	_replaying = true
	viewport.push_input(event, true)
	_replaying = false


## 🔑 **A gohud field, dropdown or slider brings the same arbiter into a plain `ScrollContainer`** — a scroll that is not
## a `GoScroll` has no `_input` of its own to hold the press, so the control carries a small `_Yield` node that does.
## Inside a `GoScroll` that node stands aside: the scroll already holds the press. Returns [param control].
static func yield_vertical(control: Control) -> Control:
	if control == null or control.has_node(^"GoScrollYield"): return control
	var helper := _Yield.new()
	helper.name = "GoScrollYield"
	control.add_child(helper, false, Node.INTERNAL_MODE_BACK)
	return control


## The arbiter a gohud field, dropdown or slider carries into a plain `ScrollContainer` (`yield_vertical`).
class _Yield extends Node:
	var _touch := {}

	func _input(event: InputEvent) -> void:
		var control := get_parent() as Control
		if GoScroll._replaying or Engine.is_editor_hint() or control == null or not control.is_visible_in_tree(): return
		var scroll := _plain_scroll(control)
		if scroll == null: return
		GoScroll._arbitrate(event, _touch, _target.bind(control, scroll), float(scroll.scroll_deadzone), get_viewport())

	## The plain scroll around the control — `null` inside a `GoScroll` (it holds the press itself) or outside any scroll.
	static func _plain_scroll(control: Control) -> ScrollContainer:
		var node := control.get_parent()
		while node != null:
			if node is GoScroll: return null
			if node is ScrollContainer: return node
			node = node.get_parent()
		return null

	static func _target(point: Vector2, control: Control, scroll: ScrollContainer) -> Control:
		return control if GoScroll.yields_vertical(control) and GoScroll.control_at(scroll, point) == control else null


## The control a press at [param point] (viewport coordinates) reaches under [param node] — the topmost visible one that
## takes the mouse, found the way the GUI finds it. `null` when nothing there takes the press.
## 🛑 A clipping control (a scroll, a row with `clip_contents`) hides what lies outside it — its subtree is skipped there.
static func control_at(node: Node, point: Vector2) -> Control:
	var control := node as Control
	if control != null:
		var local := control.get_global_transform_with_canvas().affine_inverse() * point
		var inside := Rect2(Vector2.ZERO, control.size).has_point(local)
		if not inside and (control.clip_contents or control is Container): return null
		for index in range(node.get_child_count() - 1, -1, -1):
			var child := node.get_child(index)
			if not child is Control or not (child as Control).visible or (child as Control).top_level: continue
			var found := control_at(child, point)
			if found != null: return found
		return control if inside and control.mouse_filter != Control.MOUSE_FILTER_IGNORE else null
	return null


## 🧪 **What under [param root] can swallow a finger drag** — one line per problem, empty when clean.
## Reports a `MOUSE_FILTER_STOP` control inside a `GoScroll` that does not own a gesture (something turned it STOP
## after the policy ran), and a plain `ScrollContainer` that is not a `GoScroll` (it gets none of this).
## For screen tests: open a sheet, then `check(GoScroll.audit_touch(sheet).is_empty(), ...)`.
static func audit_touch(root: Node) -> Array[String]:
	var problems: Array[String] = []
	_audit_touch(root, root is GoScroll, root, problems)
	return problems


static func _audit_touch(node: Node, inside: bool, root: Node, problems: Array[String]) -> void:
	var where := str(root.get_path_to(node)) if root != node else str(node.name)
	if node is ScrollContainer and not node is GoScroll:
		problems.append("%s: a plain ScrollContainer — use GoScroll so a finger swipe scrolls it" % where)
	var control := node as Control
	if inside and control != null and node != root and control.mouse_filter == Control.MOUSE_FILTER_STOP \
			and not node is ScrollBar and not owns_gesture(control):
		problems.append("%s: %s is STOP inside a scroll — a finger drag that starts on it never reaches the scroll" % [
			where, control.get_class()])
	if node is ScrollBar: return
	for child in node.get_children(): _audit_touch(child, inside or node is GoScroll, root, problems)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _content_inset != null:
		# When the language changes the children flip left-to-right — fit them back inside our physical right inset.
		_content_inset.queue_sort.call_deferred()


## Keyboard and gamepad focus scrolls into view; the focus a pointer press hands out does not.
## 🛑 Asking `has_focus(true)` is not enough — with `gui/common/show_focus_state_on_pointer_event` set to
##    Always a click's focus is not hidden either. A held left button (a finger arrives as one) is the tell.
func _on_focus_changed(control: Control) -> void:
	if not follow_keyboard_focus or control == null or not is_ancestor_of(control): return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
	ensure_control_visible(control)


## 🔑 **A finger drag scrolls the list, and nothing inside it reacts.** The engine already cancels the press
## the drag started on; this takes away the rest of what made the rows look like they were being dragged:
## - the focus that press handed out is dropped (it was never a choice),
## - the rows stop taking the mouse until the scroll stops, so the hover highlight neither sticks to the row
##   under the finger nor hops from row to row as the finger passes over them.
## 🛑 `mouse_behavior_recursive` rather than each row's `mouse_filter` — the motion still travels up to this
##    scroll (an ignored control is skipped, not a dead end), and the rows' own filters are never touched.
func _on_drag_started() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused): focused.release_focus()
	for child in get_children():
		if child is Control and not _drag_muted.has(child):
			_drag_muted[child] = child.mouse_behavior_recursive
			child.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED


## The scroll came to rest (the finger lifted without a fling, the fling ran out, or a tap stopped it).
func _on_drag_ended() -> void:
	# 🛑 Untyped — a row freed mid-drag (a list rebuilt while the finger moves) is still a key. Assigning it to a
	#    `Control` variable is a script error that skipped `clear()`, and the stale key broke every later drag's
	#    restore, leaving the new rows deaf to the mouse.
	for child: Variant in _drag_muted:
		if is_instance_valid(child): (child as Control).mouse_behavior_recursive = _drag_muted[child]
	_drag_muted.clear()
