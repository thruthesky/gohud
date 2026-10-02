## 📐 **A layout that lines items up along the top or bottom edge** — one, two or three slots, and nothing drawn.
## `GoTopBar` and `GoBottomBar` are this with the edge set; use them.
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
## ## 🔑 Three slots, the middle one in the middle
## `columns = 3`: the start slot sits at the start edge, the end slot at the far edge, and the centre slot is centred on
## **the bar** — not on the room left between the other two — as long as `max(start, end) + separation` fits in half
## of what the centre leaves. Past that the centre slot moves only as far as it must not to overlap a side, and when
## the three cannot fit at all the bar asks for their total width rather than cut anything. `columns = 2` has the
## start and end slots (centre items follow the start ones). `columns = 1` is one run of every item in child order,
## placed by `justify` — at the start, in the centre, at the end, or `SPACE_BETWEEN`: the first and last items at the
## edges and the same gap between every pair (never less than `separation`).
##
## ## 🔑 Pinned, or in the flow
## `pin_to_edge = AUTO`: under a container (a screen's column) it is laid out like any child; under anything else it
## pins itself to the top or bottom edge, full width, as tall as its items. `ALWAYS` pins it even inside a container
## (it leaves the container's layout and holds the screen edge); `NEVER` leaves its anchors alone. `dock(host)` moves
## it under a non-container control and pins it there.
## 🛑 In the flow, "always at the bottom" holds only when the bar is a sibling of the page that scrolls — the last
##    child of a column whose scroll expands (as `GoAppBar` and `GoNavBar` sit). Inside the scrolling page it scrolls
##    away with it; use `ALWAYS` there.
## Pinned, with `safe_area` on, it pads by **the part of the notch, status bar or gesture bar it actually covers** —
## measured against its own rectangle, so a bar already clear of them pads nothing and the inset is never added twice.
##
## ## 🔑 Start and end follow the layout direction
## `START` is the left in a left-to-right layout and the right in a right-to-left one (`is_layout_rtl()`), and the
## items inside a slot reverse with it. A game HUD keeps physical left and right in Arabic and Hebrew too — give the
## bar `layout_direction = Control.LAYOUT_DIRECTION_LTR` (or put it under a `GoSafeArea`, which is LTR).
##
## 🛑 The bar itself draws nothing and takes no input (`MOUSE_FILTER_IGNORE`) — a press on its empty space reaches what
##    is behind. Its items keep their own `mouse_filter` and `focus_mode`. Put it in a panel for a face. Over gameplay,
##    turn keyboard focus off on the buttons (`GoIconButton.keyboard_focus`) or use `GoHudAnchor.keyboard_focus`.
## 🛑 Items keep their **natural width**: wrapping is turned off on whatever enters, as in `GoStyle.wrap_row` — a
##    wrapping label asks for 1dp and would fold to a column of letters. So put buttons, chips, icons and short text in
##    a bar, not a card or a row with an expanding title. Each item sits on the bar's middle line at its own height; an
##    item with `SIZE_EXPAND` vertically fills the bar's height. Side-by-side icon buttons and slots are told about
##    each other (`touch_peers`), so their 48dp touch areas never press a neighbour.
@tool
class_name GoEdgeBar
extends Container

## Where an item goes when the bar has two or three columns.
enum Slot { START, CENTER, END }
## How the single run of a one-column bar is placed.
enum Justify { START, CENTER, END, SPACE_BETWEEN }
## The screen edge the bar belongs to.
enum Edge { TOP, BOTTOM }
## When the bar pins itself to its edge.
enum Pin { AUTO, ALWAYS, NEVER }

## The meta key holding an item's `Slot`.
const SLOT_META := &"go_edge_bar_slot"

## 1, 2 or 3 columns.
@export_range(1, 3) var columns := 3:
	set(value):
		columns = clampi(value, 1, 3)
		_on_ui_changed()
## How a one-column bar places its items. Ignored with two or three columns.
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
## While pinned, pad by the part of the screen's unsafe band (notch, status bar, gesture bar) the bar covers.
@export var safe_area := true:
	set(value):
		safe_area = value
		_on_ui_changed()
## `AUTO` pins to the edge under a non-container parent, `ALWAYS` even inside a container, `NEVER` not at all.
@export var pin_to_edge := Pin.AUTO:
	set(value):
		pin_to_edge = value
		_pin.call_deferred()
## The edge this bar belongs to — `GoTopBar` and `GoBottomBar` set it.
@export var edge := Edge.TOP:
	set(value):
		edge = value
		_on_ui_changed()
		_pin.call_deferred()

## The unsafe-band padding in force — left, top, right, bottom (dp).
var _insets := Vector4.ZERO
## The bar holds its edge right now (anchors set by `_pin`).
var _pinned := false
## `_pin` lifted it out of its container's layout (`ALWAYS` under a container) — put back when that ends.
var _lifted := false
var _warned_center := false


func _init() -> void:
	name = "EdgeBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimum_size_changed.connect(_pin)
	item_rect_changed.connect(queue_sort)
	child_entered_tree.connect(_on_item_entered)
	child_exiting_tree.connect(func(_node: Node) -> void: _link_touch_peers.call_deferred())


func _ready() -> void:
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(queue_sort)
	GoUi.watch(_on_ui_changed)
	_pin()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN: _sort()
		NOTIFICATION_PARENTED: _pin.call_deferred()
		NOTIFICATION_LAYOUT_DIRECTION_CHANGED: queue_sort()


## Puts [param node] in the start slot (the run of a one-column bar) and returns it.
func add_start(node: Control) -> Control:
	return _add(node, Slot.START)


## Puts [param node] in the centre slot (three columns) and returns it.
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


## Moves the bar under [param host] — a non-container control, the screen's full-rect root — and pins it to its edge.
func dock(host: Control) -> void:
	if host is Container:
		push_error("gohud: dock() needs a host that is not a container — a container lays its children out itself")
		return
	if get_parent() != host:
		if get_parent() == null: host.add_child(self)
		else: reparent(host, false)
	_pin()


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


func _on_item_entered(node: Node) -> void:
	GoStyle.natural_width(node)
	_link_touch_peers.call_deferred()


## Icon buttons and slots widen their touch area past the node to 48dp; side by side, each must know the others so the
## nearer one takes a press (`GoIconButton._has_point`). Peers the caller set stay.
func _link_touch_peers() -> void:
	if not is_inside_tree(): return
	var widened: Array[Control] = []
	for child in get_children():
		if child is Control and &"touch_peers" in child: widened.append(child)
	for item in widened:
		var peers: Array[Control] = item.get(&"touch_peers")
		for other in widened:
			if other != item and not peers.has(other): peers.append(other)
		item.set(&"touch_peers", peers)


func _gap() -> float:
	return float(GoUi.metric(GoTheme.GAP) if separation < 0 else separation)


func _margin() -> float:
	return float(GoUi.metric(GoTheme.SCREEN_MARGIN) if edge_margin < 0 else edge_margin)


## The children this bar places — visible controls that are not top level.
func _laid_out() -> Array[Control]:
	var found: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible or control.top_level: continue
		found.append(control)
	return found


## The runs in logical order — one for one column, start/end for two, start/centre/end for three.
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
		# Two columns have no middle — centre items line up after the start ones rather than vanish.
		if not center.is_empty() and not _warned_center and OS.is_debug_build() and not Engine.is_editor_hint():
			_warned_center = true
			push_warning("gohud: %s has centre items but columns = 2 — they follow the start items" % name)
		start.append_array(center)
		return [start, end]
	return [start, center, end]


func _run_width(run: Array) -> float:
	if run.is_empty(): return 0.0
	var total := _gap() * float(run.size() - 1)
	for item: Control in run: total += item.get_combined_minimum_size().x
	return total


func _get_minimum_size() -> Vector2:
	var width := 0.0
	var used := 0
	var tall := 0.0
	for run: Array in _runs():
		if run.is_empty(): continue
		width += _run_width(run)
		used += 1
		for item: Control in run: tall = maxf(tall, item.get_combined_minimum_size().y)
	width += _gap() * float(maxi(0, used - 1))
	var margin := _margin()
	# 🔑 Never under the touch height — an empty bar, or one holding a 16dp label, keeps a row a finger can use.
	var high := maxf(tall + margin * 2.0, float(GoUi.metric(GoTheme.TOUCH)))
	return Vector2(width + margin * 2.0 + _insets.x + _insets.z, high + _insets.y + _insets.w)


func _sort() -> void:
	_refresh_insets()
	var margin := _margin()
	var inner := Rect2(margin + _insets.x, margin + _insets.y,
		maxf(0.0, size.x - margin * 2.0 - _insets.x - _insets.z),
		maxf(0.0, size.y - margin * 2.0 - _insets.y - _insets.w))
	var gap := _gap()
	var runs := _runs()
	if columns == 1:
		_place_single(runs[0], inner, gap)
		return
	var start: Array = runs[0]
	var end: Array = runs[runs.size() - 1]
	var start_width := _run_width(start)
	var end_width := _run_width(end)
	_place_run(start, 0.0, inner, gap)
	_place_run(end, inner.size.x - end_width, inner, gap)
	if columns == 3:
		var center: Array = runs[1]
		var center_width := _run_width(center)
		# Centred on the bar while the sides allow it; crowded, it moves only as far as it must not to overlap one.
		var low := start_width + gap if not start.is_empty() else 0.0
		var high := inner.size.x - center_width - (end_width + gap if not end.is_empty() else 0.0)
		var x := (inner.size.x - center_width) * 0.5
		x = clampf(x, low, high) if low <= high else low
		_place_run(center, x, inner, gap)


func _place_single(run: Array, inner: Rect2, gap: float) -> void:
	if run.is_empty(): return
	var total := 0.0
	for item: Control in run: total += item.get_combined_minimum_size().x
	var packed := total + gap * float(run.size() - 1)
	match justify:
		Justify.END: _place_run(run, inner.size.x - packed, inner, gap)
		Justify.CENTER: _place_run(run, (inner.size.x - packed) * 0.5, inner, gap)
		Justify.SPACE_BETWEEN:
			# One item has no pair to spread over — it stays at the start, as in CSS. Never closer than `separation`.
			var step := gap if run.size() < 2 else maxf(gap, (inner.size.x - total) / float(run.size() - 1))
			_place_run(run, 0.0, inner, step)
		_: _place_run(run, 0.0, inner, gap)


## Lays [param run] out from [param from] (logical x inside [param inner]), [param step] apart.
func _place_run(run: Array, from: float, inner: Rect2, step: float) -> void:
	var rtl := is_layout_rtl()
	var x := from
	for item: Control in run:
		var wanted := item.get_combined_minimum_size()
		var tall := inner.size.y if item.size_flags_vertical & Control.SIZE_EXPAND else minf(wanted.y, inner.size.y)
		var left := inner.size.x - x - wanted.x if rtl else x
		var y := (inner.size.y - tall) * 0.5
		# 🛑 Whole units — a fractional position blurs text and leaves 1px seams (see `GoSurface.relayout`).
		fit_child_in_rect(item, Rect2(Vector2(inner.position.x + left, inner.position.y + y).round(),
			Vector2(wanted.x, tall).round()))
		x += wanted.x + step


## The padding for the unsafe band the bar covers while pinned. Re-measured on every sort; a change re-asks for size.
func _refresh_insets() -> void:
	var next := Vector4.ZERO
	if _pinned and safe_area and is_inside_tree() and not Engine.is_editor_hint():
		var window := get_window()
		next = edge_insets(get_global_rect(), GoSafeArea.usable_rect(window), window.get_visible_rect(), edge)
	if next.is_equal_approx(_insets): return
	_insets = next
	update_minimum_size()
	queue_sort.call_deferred()


## How far [param rect] reaches into the unsafe band between [param usable] and [param screen] — left, top, right,
## bottom: the intersection of the bar and the band, so a bar already inside the safe area gets 0. Only the bar's own
## edge counts vertically — a top bar pads for the notch above it, never for the gesture bar.
## 🛑 Measured only up to the screen's edge. A bar wider than the screen once padded by its whole overflow, which made
##    it wider still — 2,200,000px within a few frames (2026-10-02, a draft of this class).
static func edge_insets(rect: Rect2, usable: Rect2, screen: Rect2, at: Edge) -> Vector4:
	var left := clampf(usable.position.x - maxf(rect.position.x, screen.position.x), 0.0, rect.size.x)
	var right := clampf(minf(rect.end.x, screen.end.x) - usable.end.x, 0.0, rect.size.x)
	var top := maxf(0.0, usable.position.y - maxf(rect.position.y, screen.position.y)) if at == Edge.TOP else 0.0
	var bottom := maxf(0.0, minf(rect.end.y, screen.end.y) - usable.end.y) if at == Edge.BOTTOM else 0.0
	return Vector4(left, top, right, bottom).round()


## Holds the bar at its edge, full width, as tall as it asks — or lets go, per `pin_to_edge`.
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
	var tall := get_combined_minimum_size().y
	anchor_left = 0.0
	anchor_right = 1.0
	offset_left = 0.0
	offset_right = 0.0
	if edge == Edge.TOP:
		anchor_top = 0.0
		anchor_bottom = 0.0
		offset_top = 0.0
		offset_bottom = tall
		grow_vertical = Control.GROW_DIRECTION_END
	else:
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_top = -tall
		offset_bottom = 0.0
		grow_vertical = Control.GROW_DIRECTION_BEGIN
	if not was_pinned: queue_sort()
