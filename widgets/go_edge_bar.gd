## 📐 **A layout that lines items up along a screen edge** — the top, the bottom, the left or the right; one, two or
## three slots, and nothing drawn. `GoTopBar`, `GoBottomBar`, `GoLeftSideBar` and `GoRightSideBar` are this with
## the edge set; use them.
##
## ```gdscript
## var bar := GoTopBar.make(3)
## bar.add_start(GoStyle.icon_button(GoIconSet.MENU, open_menu, -1, &"menu"))
## bar.add_center(GoStyle.label("Stage 3"))
## bar.add_end(GoStyle.chip("1,250"))
## bar.add_end(GoStyle.icon_button(GoIconSet.SETTINGS, open_settings, -1, &"settings"))
## screen.add_child(bar)      # not a container → it pins itself to the top edge, full width
## ```
##
## ## 🔑 One rule for every edge: the main axis and the cross axis
## Items line up along the **main axis** — across for a top or bottom bar, down for a side bar. The bar's size on the
## other, **cross** axis is its thickness: as thick as its items (never under the `touch` token), or `thickness`.
## `Slot.START` is the start of the main axis (the left of a top bar in a left-to-right layout, the top of a side bar),
## `END` its far end.
##
## ## 🔑 Three slots, the middle one in the middle
## `columns = 3`: the start slot at the start, the end slot at the far end, and the centre slot centred on **the area
## inside the margins and the safe-area padding** — not on the room left between the other two — as long as
## `max(start, end) + separation` fits in half of what the centre leaves. Past that the centre slot moves only as far
## as it must not to overlap a side; when the three cannot fit at all the bar asks for their total length rather than
## cut anything. `columns = 2` has the start and end slots (centre items follow the start ones). `columns = 1` is one
## run of every item in child order, placed by `justify` — at the start, in the centre, at the end, or `SPACE_BETWEEN`:
## the first and last items at the ends and the same gap between every pair (never less than `separation`). In one
## column an item marked `set_meta(GoEdgeBar.GROW, true)` takes the room left (the value is its share) — a search field
## filling a top bar; two and three columns keep every item at its own length. Size flags do not make an item grow
## along the bar — `GoStyle.label()` and `GoStyle.button()` come with `SIZE_EXPAND_FILL` and still keep their length.
##
## ## 🔑 Pinned, or in the flow
## `pin_to_edge = AUTO`: under a container (a screen's column) it is laid out like any child; under anything else it
## pins itself to its edge — full width for a top or bottom bar, full height for a side bar. `ALWAYS` pins it even
## inside a container (it leaves the container's layout and holds the screen edge); `NEVER` leaves its anchors alone.
## `dock(host)` moves it under a non-container control and pins it there (unless `pin_to_edge` is `NEVER`).
## A pinned side bar runs the whole height, corners included; `clear_of([top_bar, bottom_bar])` keeps it between them,
## following their thickness (`extent()`). Use `extent()` the same way to keep a page clear of a pinned bar.
## 🛑 In the flow, "always at the bottom" holds only when the bar is a sibling of the page that scrolls — the last
##    child of a column whose scroll expands (as `GoAppBar` and `GoNavBar` sit). Inside the scrolling page it scrolls
##    away with it; use `ALWAYS` there.
## With `safe_area` on, the bar pads by **the part of the notch, status bar or gesture bar it actually covers** —
## measured against its own rectangle, pinned or in the flow, so a bar already clear of them pads nothing and the inset
## is never added twice (a bar inside a scrolling page is left alone, so it does not grow as it scrolls under a notch).
## `avoid_keyboard` (off by default) lifts a bottom bar's items clear of the virtual keyboard (`GoRuntime`).
##
## ## 🔑 Directions
## A top or bottom bar follows the layout direction: `START` is the left in a left-to-right layout and the right in a
## right-to-left one, and the items inside a slot reverse with it. A game HUD keeps physical left and right in Arabic
## and Hebrew too — give the bar `layout_direction = Control.LAYOUT_DIRECTION_LTR`. A side bar stays on the physical
## side it names, and its slots keep top-to-bottom order in every language; `follow_text_direction` swaps the side in
## a right-to-left language (as `GoDrawer` does).
##
## 🛑 The bar itself draws nothing and takes no input (`MOUSE_FILTER_IGNORE`) — a press on its empty space reaches what
##    is behind. Its items keep their own `mouse_filter`, `focus_mode` and size flags. Put it in a panel for a face. Over
##    gameplay, turn keyboard focus off on the buttons (`GoIconButton.keyboard_focus`) or use `GoHudAnchor.keyboard_focus`.
## 🛑 Text keeps one line: a label or a button that enters has wrapping turned off (`go_no_wrap`), down through the item
##    — a wrapping label asks for 1dp and would fold to a column of letters. A panel whose text should wrap (a quest
##    note in a side bar) is marked `set_meta(GoEdgeBar.KEEP_WRAP, true)` before it is added: nothing under it is
##    touched, so give it a width — `thickness` on a side bar and `SIZE_EXPAND_FILL` across. An item with `SIZE_EXPAND`
##    on the cross axis fills the bar's thickness; any other sits on the bar's middle line at its own size.
##    Side-by-side icon buttons and slots are told about each other (`touch_peers`), so their 48dp touch areas never
##    press a neighbour.
@tool
class_name GoEdgeBar
extends Container

## Where an item goes when the bar has two or three slots.
enum Slot { START, CENTER, END }
## How the single run of a one-slot bar is placed along the main axis.
enum Justify { START, CENTER, END, SPACE_BETWEEN }
## The screen edge the bar belongs to. 🛑 New values go at the end — scenes store the number.
enum Edge { TOP, BOTTOM, LEFT, RIGHT }
## When the bar pins itself to its edge.
enum Pin { AUTO, ALWAYS, NEVER }

## The meta key holding an item's `Slot`.
const SLOT_META := &"go_edge_bar_slot"
## Set this meta to `true` on an item whose text should keep wrapping (a panel of prose) — the bar leaves its whole
## subtree alone.
const KEEP_WRAP := &"go_edge_bar_keep_wrap"
## Set this meta on an item of a one-slot bar to have it take the room left along the bar — a search field filling a
## top bar. The value is its share: `true` (or 1.0) for one share, 2.0 for twice another's.
const GROW := &"go_edge_bar_grow"
## The touch peers the bar added to an item, so they can be taken away again when either leaves.
const PEERS_META := &"go_auto_touch_peers"

## 1, 2 or 3 slots along the main axis (the tiers of a side bar).
@export_range(1, 3) var columns := 3:
	set(value):
		columns = clampi(value, 1, 3)
		_on_ui_changed()
## How a one-slot bar places its items along the main axis. Ignored with two or three slots.
@export var justify := Justify.START:
	set(value):
		justify = value
		_on_ui_changed()
## Gap between items and between slots (dp). Negative → the `gap` token.
@export var separation := -1:
	set(value):
		separation = value
		_on_ui_changed()
## Space kept clear on every side of the items (dp). Negative → the `screen_margin` token; 0 inside a card that pads.
@export var edge_margin := -1:
	set(value):
		edge_margin = value
		_on_ui_changed()
## The bar's size across its main axis — the height of a top or bottom bar, the width of a side bar — margins included,
## safe-area padding not (dp). 0 → as thick as its items. Items never get cut: a thicker item makes a thicker bar.
@export var thickness := 0.0:
	set(value):
		thickness = maxf(0.0, value)
		_on_ui_changed()
## Pad by the part of the screen's unsafe band (notch, status bar, gesture bar) the bar covers.
@export var safe_area := true:
	set(value):
		safe_area = value
		_on_ui_changed()
## A bottom bar lifts its items clear of the virtual keyboard (needs the `GoRuntime` autoload).
@export var avoid_keyboard := false:
	set(value):
		avoid_keyboard = value
		_on_ui_changed()
## `AUTO` pins to the edge under a non-container parent, `ALWAYS` even inside a container, `NEVER` not at all —
## `NEVER` leaves the anchors as they are, including the ones an earlier pin set.
@export var pin_to_edge := Pin.AUTO:
	set(value):
		pin_to_edge = value
		_pin.call_deferred()
## The edge this bar belongs to — `GoTopBar`, `GoBottomBar`, `GoLeftSideBar` and `GoRightSideBar` set it.
@export var edge := Edge.TOP:
	set(value):
		edge = value
		_on_ui_changed()
		_pin.call_deferred()
## A side bar trades sides in a right-to-left language (LEFT goes right). Off: it stays on the physical side it names.
@export var follow_text_direction := false:
	set(value):
		follow_text_direction = value
		_on_ui_changed()
		_pin.call_deferred()

## The unsafe-band padding in force — left, top, right, bottom (dp).
var _insets := Vector4.ZERO
## Room kept clear at the two ends of the main axis for other bars (`clear_of`).
var _clear := Vector2.ZERO
var _clear_of: Array[GoEdgeBar] = []
var _keyboard_px := 0
## The bar holds its edge right now (anchors set by `_pin`).
var _pinned := false
## `_pin` lifted it out of its container's layout (`ALWAYS` under a container) — put back when that ends.
var _lifted := false
var _warned_center := false
var _warned_overflow := false


func _init() -> void:
	name = "EdgeBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimum_size_changed.connect(_pin)
	item_rect_changed.connect(queue_sort)
	child_entered_tree.connect(_on_item_entered)
	child_exiting_tree.connect(_on_item_exiting)


## 🔑 Watched on every entry, not once in `_ready` — `dock()` and `reparent()` take the bar out and back, and a watch
##    set only in `_ready` was dropped by the first `_exit_tree` for good (2026-10-02).
func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if Engine.is_editor_hint(): return
	var viewport := get_viewport()
	if not viewport.size_changed.is_connected(queue_sort): viewport.size_changed.connect(queue_sort)
	var runtime := GoUi.runtime()
	if runtime != null and runtime.has_signal(&"keyboard_changed") and not runtime.keyboard_changed.is_connected(_on_keyboard):
		runtime.keyboard_changed.connect(_on_keyboard)


func _ready() -> void:
	_pin()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(queue_sort): viewport.size_changed.disconnect(queue_sort)
	var runtime := GoUi.runtime()
	if runtime != null and runtime.has_signal(&"keyboard_changed") and runtime.keyboard_changed.is_connected(_on_keyboard):
		runtime.keyboard_changed.disconnect(_on_keyboard)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN: _sort()
		NOTIFICATION_PARENTED: _pin.call_deferred()
		NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			queue_sort()
			_pin.call_deferred()


## Puts [param node] in the start slot (the run of a one-slot bar) and returns it.
func add_start(node: Control) -> Control:
	return _add(node, Slot.START)


## Puts [param node] in the centre slot (three slots) and returns it.
func add_center(node: Control) -> Control:
	return _add(node, Slot.CENTER)


## Puts [param node] in the end slot and returns it.
func add_end(node: Control) -> Control:
	return _add(node, Slot.END)


## Moves an item already in the bar to another slot.
func set_slot(node: Control, slot: Slot) -> void:
	node.set_meta(SLOT_META, slot)
	_on_ui_changed()


## The slot [param node] belongs to (a child added with plain `add_child` is in `START`).
func slot_of(node: Control) -> Slot:
	return int(node.get_meta(SLOT_META, Slot.START)) as Slot


## The visible items of [param slot], in child order.
func items(slot: Slot) -> Array[Control]:
	var found: Array[Control] = []
	for child in _laid_out():
		if slot_of(child) == slot: found.append(child)
	return found


## Moves the bar under [param host] — a non-container control, the screen's full-rect root — and pins it to its edge
## (unless `pin_to_edge` is `NEVER`).
func dock(host: Control) -> void:
	if host is Container:
		push_error("gohud: dock() needs a host that is not a container — a container lays its children out itself")
		return
	if get_parent() != host:
		if get_parent() == null: host.add_child(self)
		else: reparent(host, false)
	_pin()


## How far the bar reaches in from its edge while pinned — its thickness with the safe-area padding (dp). 0 while it is
## not pinned or hidden. 🛑 A reading, not a reservation: nothing moves out of the way by itself. Keep a page that far
## from the edge (`page.offset_top = bar.extent()`), or another bar with `clear_of`.
func extent() -> float:
	if not _pinned or not is_visible_in_tree(): return 0.0
	return size.y if not _is_side() else size.x


## Keeps both ends of this bar's main axis clear of [param bars] — a side bar between a top and a bottom bar — and
## follows them as they change. Pass an empty array to run edge to edge again.
## 🛑 One way only: only bars across this one count, and a bar that already clears this one is skipped with a warning.
##    A bar's thickness never depends on what it clears, so one-way following cannot loop (`GoHudAnchor` once traded
##    relayouts forever between two boxes that watched each other).
func clear_of(bars: Array[GoEdgeBar]) -> void:
	for old in _clear_of:
		if is_instance_valid(old) and old.item_rect_changed.is_connected(_refresh_clear):
			old.item_rect_changed.disconnect(_refresh_clear)
			old.visibility_changed.disconnect(_refresh_clear)
	_clear_of.clear()
	for bar in bars:
		if bar == null or bar == self or bar._is_side() == _is_side(): continue
		if bar._clear_of.has(self):
			push_warning("gohud: %s and %s would each clear the other — %s is skipped" % [name, bar.name, bar.name])
			continue
		_clear_of.append(bar)
		bar.item_rect_changed.connect(_refresh_clear)
		bar.visibility_changed.connect(_refresh_clear)
	_refresh_clear()


func _refresh_clear() -> void:
	var next := Vector2.ZERO
	var side := _is_side()
	for bar in _clear_of:
		if not is_instance_valid(bar) or bar._is_side() == side: continue
		var at := bar._resolved_edge()
		if at == Edge.TOP or at == Edge.LEFT: next.x = maxf(next.x, bar.extent())
		else: next.y = maxf(next.y, bar.extent())
	if next.is_equal_approx(_clear): return
	_clear = next
	_on_ui_changed()


func _add(node: Control, slot: Slot) -> Control:
	node.set_meta(SLOT_META, slot)
	if node.get_parent() == null: add_child(node)
	elif node.get_parent() != self: node.reparent(self)
	else: _on_ui_changed()
	return node


## Tokens or a setting changed — re-measure and re-place. The items are never rebuilt (connections, state, focus stay).
func _on_ui_changed() -> void:
	update_minimum_size()
	queue_sort()


func _on_keyboard(height_px: int) -> void:
	if height_px == _keyboard_px: return
	_keyboard_px = height_px
	if avoid_keyboard: queue_sort()


func _on_item_entered(node: Node) -> void:
	# 🛑 Not in the editor — the scene would save the changed wrapping of every child.
	if Engine.is_editor_hint(): return
	_one_line(node)
	_link_touch_peers.call_deferred()


## Wrapping off on the labels and buttons of an item, down through it — never its size flags, and never under a
## `KEEP_WRAP` panel. (`GoStyle.natural_width` also forces `SIZE_SHRINK_BEGIN`, which took away an item's `SIZE_EXPAND`.)
static func _one_line(node: Node) -> void:
	if node.get_meta(KEEP_WRAP, false): return
	if node is Label:
		GoStyle.one_line(node as Label)
	elif node is Button:
		(node as Button).autowrap_mode = TextServer.AUTOWRAP_OFF
		node.set_meta(&"go_no_wrap", true)
	for child in node.get_children(): _one_line(child)


func _on_item_exiting(node: Node) -> void:
	# The peers this bar gave the leaving item go, and it leaves the peers of those that stay.
	if node is Control and &"touch_peers" in node:
		var added: Array = node.get_meta(PEERS_META, [])
		var peers: Array[Control] = node.get(&"touch_peers")
		for other in added: peers.erase(other)
		node.set(&"touch_peers", peers)
		node.remove_meta(PEERS_META)
		for child in get_children():
			if child == node or not (child is Control and &"touch_peers" in child): continue
			var theirs: Array = child.get_meta(PEERS_META, [])
			if not theirs.has(node): continue
			theirs.erase(node)
			child.set_meta(PEERS_META, theirs)
			var list: Array[Control] = child.get(&"touch_peers")
			list.erase(node)
			child.set(&"touch_peers", list)
	_on_ui_changed()


## Icon buttons and slots widen their touch area past the node to 48dp; side by side, each must know the others so the
## nearer one takes a press (`GoIconButton._has_point`). Peers the caller set stay; the ones added here are recorded.
func _link_touch_peers() -> void:
	if not is_inside_tree(): return
	var widened: Array[Control] = []
	for child in get_children():
		if child is Control and &"touch_peers" in child and not child.is_queued_for_deletion(): widened.append(child)
	for item in widened:
		var peers: Array[Control] = item.get(&"touch_peers")
		var added: Array = item.get_meta(PEERS_META, [])
		for other in widened:
			if other == item or peers.has(other): continue
			peers.append(other)
			added.append(other)
		item.set(&"touch_peers", peers)
		item.set_meta(PEERS_META, added)


func _gap() -> float:
	return float(GoUi.metric(GoTheme.GAP) if separation < 0 else separation)


func _margin() -> float:
	return float(GoUi.metric(GoTheme.SCREEN_MARGIN) if edge_margin < 0 else edge_margin)


## The screen edge the bar really holds — a side bar trades sides in a right-to-left language only with
## `follow_text_direction`.
func _resolved_edge() -> Edge:
	if follow_text_direction and _is_side() and is_inside_tree() and is_layout_rtl():
		return Edge.RIGHT if edge == Edge.LEFT else Edge.LEFT
	return edge


func _is_side() -> bool:
	return edge == Edge.LEFT or edge == Edge.RIGHT


## The main-axis component of [param value] (x across a top or bottom bar, y down a side bar).
func _main(value: Vector2) -> float:
	return value.y if _is_side() else value.x


func _cross(value: Vector2) -> float:
	return value.x if _is_side() else value.y


## The children this bar places — visible controls that are not top level.
func _laid_out() -> Array[Control]:
	var found: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible or control.top_level: continue
		found.append(control)
	return found


## The runs in logical order — one for one slot, start/end for two, start/centre/end for three.
func _runs() -> Array:
	var all := _laid_out()
	if columns == 1: return [all]
	var start: Array[Control] = []
	var center: Array[Control] = []
	var end: Array[Control] = []
	for item in all:
		match slot_of(item):
			Slot.CENTER: center.append(item)
			Slot.END: end.append(item)
			_: start.append(item)
	if columns == 2:
		# Two slots have no middle — centre items line up after the start ones rather than vanish.
		if not center.is_empty() and not _warned_center and OS.is_debug_build() and not Engine.is_editor_hint():
			_warned_center = true
			push_warning("gohud: %s has centre items but columns = 2 — they follow the start items" % name)
		start.append_array(center)
		return [start, end]
	return [start, center, end]


func _run_length(run: Array) -> float:
	if run.is_empty(): return 0.0
	var total := _gap() * float(run.size() - 1)
	for item: Control in run: total += _main(item.get_combined_minimum_size())
	return total


func _get_minimum_size() -> Vector2:
	var length := 0.0
	var used := 0
	var thick := 0.0
	for run: Array in _runs():
		if run.is_empty(): continue
		length += _run_length(run)
		used += 1
		for item: Control in run: thick = maxf(thick, _cross(item.get_combined_minimum_size()))
	length += _gap() * float(maxi(0, used - 1))
	var margin := _margin()
	# 🔑 Never under the touch height — an empty bar, or one holding a 16dp label, keeps a row a finger can use.
	var across := maxf(maxf(thick + margin * 2.0, thickness), float(GoUi.metric(GoTheme.TOUCH)))
	var along := length + margin * 2.0 + _clear.x + _clear.y
	var wanted := Vector2(across, along) if _is_side() else Vector2(along, across)
	return wanted + Vector2(_insets.x + _insets.z, _insets.y + _insets.w)


func _sort() -> void:
	_refresh_insets()
	var margin := _margin()
	var inner := Rect2(margin + _insets.x, margin + _insets.y,
		maxf(0.0, size.x - margin * 2.0 - _insets.x - _insets.z),
		maxf(0.0, size.y - margin * 2.0 - _insets.y - _insets.w))
	# The room other bars hold at the two ends of the main axis (`clear_of`).
	if _is_side():
		inner.position.y += _clear.x
		inner.size.y = maxf(0.0, inner.size.y - _clear.x - _clear.y)
	else:
		inner.position.x += _clear.x
		inner.size.x = maxf(0.0, inner.size.x - _clear.x - _clear.y)
	var gap := _gap()
	var runs := _runs()
	if columns == 1:
		_place_single(runs[0], inner, gap)
		return
	var length := _main(inner.size)
	var start: Array = runs[0]
	var end: Array = runs[runs.size() - 1]
	var start_length := _run_length(start)
	var end_length := _run_length(end)
	_place_run(start, 0.0, inner, gap)
	_place_run(end, length - end_length, inner, gap)
	if columns == 3:
		var center: Array = runs[1]
		var center_length := _run_length(center)
		# Centred while the sides allow it; crowded, it moves only as far as it must not to overlap one.
		var low := start_length + gap if not start.is_empty() else 0.0
		var high := length - center_length - (end_length + gap if not end.is_empty() else 0.0)
		var at := (length - center_length) * 0.5
		at = clampf(at, low, high) if low <= high else low
		_place_run(center, at, inner, gap)


func _place_single(run: Array, inner: Rect2, gap: float) -> void:
	if run.is_empty(): return
	var length := _main(inner.size)
	var total := 0.0
	var stretch := 0.0
	for item: Control in run:
		total += _main(item.get_combined_minimum_size())
		stretch += _share(item)
	var packed := total + gap * float(run.size() - 1)
	if stretch > 0.0 and length > packed:
		# 🔑 Growing items share the room left by their `GROW` share — `justify` has nothing left to place.
		var extra := {}
		for item: Control in run:
			if _share(item) > 0.0: extra[item] = (length - packed) * _share(item) / stretch
		_place_run(run, 0.0, inner, gap, extra)
		return
	match justify:
		Justify.END: _place_run(run, length - packed, inner, gap)
		Justify.CENTER: _place_run(run, (length - packed) * 0.5, inner, gap)
		Justify.SPACE_BETWEEN:
			# One item has no pair to spread over — it stays at the start, as in CSS. Never closer than `separation`.
			var step := gap if run.size() < 2 else maxf(gap, (length - total) / float(run.size() - 1))
			_place_run(run, 0.0, inner, step)
		_: _place_run(run, 0.0, inner, gap)


## The share of the room left that [param item] takes along the main axis — its `GROW` meta (`true` = 1), 0 without.
## 🛑 Not `SIZE_EXPAND`: `GoStyle.label()` and `GoStyle.button()` come with `SIZE_EXPAND_FILL` for columns, and read as
##    "grow" here they swallowed every one-slot bar's `justify` — a label and a button set to CENTER filled the whole
##    bar instead (measured 2026-10-03, a draft of this rule).
func _share(item: Control) -> float:
	return maxf(0.0, float(item.get_meta(GROW, 0.0)))


## Lays [param run] out from [param from] (logical position on the main axis inside [param inner]), [param step] apart.
## [param extra] adds main-axis length to expanding items.
func _place_run(run: Array, from: float, inner: Rect2, step: float, extra := {}) -> void:
	var side := _is_side()
	# A side bar keeps top-to-bottom order in every language; a top or bottom bar mirrors with the layout.
	var mirror := not side and is_layout_rtl()
	var length := _main(inner.size)
	var across := _cross(inner.size)
	var at := from
	for item: Control in run:
		var wanted := item.get_combined_minimum_size()
		var along := _main(wanted) + float(extra.get(item, 0.0))
		var cross_flags := item.size_flags_horizontal if side else item.size_flags_vertical
		var thick := across if cross_flags & Control.SIZE_EXPAND else minf(_cross(wanted), across)
		var main_at := length - at - along if mirror else at
		var cross_at := (across - thick) * 0.5
		var rect := Rect2(cross_at, main_at, thick, along) if side else Rect2(main_at, cross_at, along, thick)
		rect.position += inner.position
		# 🛑 Whole units — a fractional position blurs text and leaves 1px seams (see `GoSurface.relayout`).
		fit_child_in_rect(item, Rect2(rect.position.round(), rect.size.round()))
		at += along + step


## The padding for the unsafe band the bar covers. Re-measured on every sort; a change re-asks for size.
## 🛑 Not for a bar in the flow of a scrolling page: it would grow as the page scrolls it under the notch.
func _refresh_insets() -> void:
	var next := Vector4.ZERO
	if safe_area and is_inside_tree() and not Engine.is_editor_hint() and (_pinned or not _in_scroll()):
		var window := get_window()
		var at := _resolved_edge()
		var usable := GoSafeArea.usable_rect(window)
		if avoid_keyboard and at == Edge.BOTTOM: usable = GoSafeArea.usable_rect_with_keyboard(window, _keyboard_px)
		next = edge_insets(get_global_rect(), usable, window.get_visible_rect(), at)
	if next.is_equal_approx(_insets): return
	_insets = next
	update_minimum_size()
	queue_sort.call_deferred()


func _in_scroll() -> bool:
	var above := get_parent()
	while above != null:
		if above is ScrollContainer: return true
		above = above.get_parent()
	return false


## The padding [param rect] needs to keep its content out of the unsafe band between [param usable] and
## [param screen] — left, top, right, bottom. Along the bar's main axis it is the part of the band the bar covers
## (0 for a bar already inside the safe area, so nothing is added twice); on the bar's own edge it is the **clearance**
## its content needs from that edge, measured from the screen's edge — a top bar pinned at y 0 under a 40dp notch gets
## 40 whatever its height now, and so does a rectangle above the screen.
## 🛑 Measured only up to the screen's edge. A bar wider than the screen once padded by its whole overflow, which made
##    it wider still — 2,200,000px within a few frames (2026-10-02, a draft of this class).
static func edge_insets(rect: Rect2, usable: Rect2, screen: Rect2, at: Edge) -> Vector4:
	if at == Edge.LEFT or at == Edge.RIGHT:
		var above := clampf(usable.position.y - maxf(rect.position.y, screen.position.y), 0.0, rect.size.y)
		var below := clampf(minf(rect.end.y, screen.end.y) - usable.end.y, 0.0, rect.size.y)
		var start := maxf(0.0, usable.position.x - maxf(rect.position.x, screen.position.x)) if at == Edge.LEFT else 0.0
		var finish := maxf(0.0, minf(rect.end.x, screen.end.x) - usable.end.x) if at == Edge.RIGHT else 0.0
		return Vector4(start, above, finish, below).round()
	var left := clampf(usable.position.x - maxf(rect.position.x, screen.position.x), 0.0, rect.size.x)
	var right := clampf(minf(rect.end.x, screen.end.x) - usable.end.x, 0.0, rect.size.x)
	var top := maxf(0.0, usable.position.y - maxf(rect.position.y, screen.position.y)) if at == Edge.TOP else 0.0
	var bottom := maxf(0.0, minf(rect.end.y, screen.end.y) - usable.end.y) if at == Edge.BOTTOM else 0.0
	return Vector4(left, top, right, bottom).round()


## Holds the bar at its edge — full width for a top or bottom bar, full height for a side bar, as thick as it asks — or
## lets go, per `pin_to_edge`.
func _pin() -> void:
	if not is_inside_tree(): return
	var in_container := get_parent() is Container
	var hold := pin_to_edge == Pin.ALWAYS or (pin_to_edge == Pin.AUTO and not in_container)
	var lift := hold and in_container
	if _lifted and not lift:
		top_level = false
		_lifted = false
	if not hold:
		if _pinned:
			_pinned = false
			_on_ui_changed()
		return
	if lift and not top_level:
		# 🔑 Out of the container's layout: a top-level control is skipped by its container and anchors to the screen.
		top_level = true
		_lifted = true
	var was_pinned := _pinned
	_pinned = true
	var wanted := get_combined_minimum_size()
	# 🛑 Godot mirrors a right-to-left control's anchors: a bar anchored left is drawn on the right (measured 4.7.2). To
	#    hold the physical side it names, an RTL side bar is anchored to the other side and mirrored back.
	var held := _resolved_edge()
	if _is_side() and is_layout_rtl(): held = Edge.LEFT if held == Edge.RIGHT else Edge.RIGHT
	match held:
		Edge.TOP: _anchor(Vector4(0, 0, 1, 0), Vector4(0, 0, 0, wanted.y))
		Edge.BOTTOM: _anchor(Vector4(0, 1, 1, 1), Vector4(0, -wanted.y, 0, 0))
		Edge.LEFT: _anchor(Vector4(0, 0, 0, 1), Vector4(0, 0, wanted.x, 0))
		Edge.RIGHT: _anchor(Vector4(1, 0, 1, 1), Vector4(-wanted.x, 0, 0, 0))
	grow_horizontal = Control.GROW_DIRECTION_BEGIN if held == Edge.RIGHT else Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN if held == Edge.BOTTOM else Control.GROW_DIRECTION_END
	if not was_pinned: queue_sort()
	_warn_overflow()


## A pinned bar longer than its edge runs off it (its items are never cut). Said once in a debug build — a side bar in a
## 390dp landscape screen is the usual case: put a long tier in a `GoScroll`, or use fewer tiers.
func _warn_overflow() -> void:
	if _warned_overflow or not OS.is_debug_build() or Engine.is_editor_hint() or not is_inside_tree(): return
	var room := get_parent_area_size()
	var need := get_combined_minimum_size()
	if _main(need) <= _main(room) + 0.5: return
	_warned_overflow = true
	push_warning("gohud: %s needs %.0f along its edge but has %.0f — it runs off the screen" % [name, _main(need), _main(room)])


## Anchors and offsets as left, top, right, bottom.
func _anchor(anchors: Vector4, offsets: Vector4) -> void:
	anchor_left = anchors.x
	anchor_top = anchors.y
	anchor_right = anchors.z
	anchor_bottom = anchors.w
	offset_left = offsets.x
	offset_top = offsets.y
	offset_right = offsets.z
	offset_bottom = offsets.w
