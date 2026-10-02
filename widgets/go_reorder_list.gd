## ↕️ **A list you put in order by dragging** — a playlist, the order of quick slots, a priority list (Flutter's
## `ReorderableListView`). Drag a row by its grip; the others step aside, and it drops into the gap.
##
## ```gdscript
## var queue := GoReorderList.make([song_row("Intro"), song_row("Theme"), song_row("Boss")])
## queue.reordered.connect(func(from: int, to: int) -> void: songs.insert(to, songs.pop_at(from)))
## page.add_child(queue)
## ```
##
## ## 🔑 Grip or long press
## With `grips` on (the default) each row gets a grip at its end, and a drag that starts there moves the row at once.
## With `grips` off the whole row is the handle: hold it for `hold_ms`, then drag — the phone way. Either way an
## up-and-down swipe that does not start a drag still scrolls the page around the list.
##
## ## 🔑 What `to` means
## `reordered(from, to)` gives the row's index before and after the move, so `items.insert(to, items.pop_at(from))`
## keeps your data in the same order (no off-by-one to correct, unlike Flutter's `onReorder`).
##
## ## ♿ Without dragging
## A grip takes focus; Up and Down move its row by one. `move_row()` does the same from code.
@tool
class_name GoReorderList
extends Container

## A row moved from [param from] to [param to] (both are indexes in the list, before and after the move).
signal reordered(from: int, to: int)

## Space between the rows (dp).
@export var spacing := 0.0:
	set(value):
		spacing = value
		queue_sort()
## Show a grip on every row (true) or drag a row by holding it anywhere (false).
@export var grips := true:
	set(value):
		grips = value
		for slot in _slots(): (slot.get_node(^"Grip") as Control).visible = value
## How long a row is held before it lifts, when there are no grips (ms).
@export var hold_ms := 450

## The width of a grip's touch area (dp).
const GRIP := 48.0
## How far a finger may drift while holding before the hold counts as a scroll instead (dp).
const HOLD_SLOP := 10.0
## The band at the top and bottom of the scrolling page where a dragged row scrolls it (dp).
const EDGE := 48.0

## The row being dragged (its slot), or null.
var _lifted: Control
var _from := -1
var _target := -1
## Where the finger is (viewport coordinates) and how far below the slot's top it took hold.
var _finger := Vector2.ZERO
var _grab := 0.0
## A press that may become a long-press drag.
var _held: Control
var _held_at := Vector2.INF
var _held_ms := 0
## Where each slot is drawn now and where it is going (local y) — the rows glide into place.
var _shown := {}
var _goal := {}


func _init() -> void:
	name = "ReorderList"
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_process(false)


func _ready() -> void:
	theme = GoUi.theme()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A reorder list holding [param rows] in that order. [param with_grips] as in `grips`.
static func make(rows: Array, with_grips := true) -> GoReorderList:
	var node := GoReorderList.new()
	node.grips = with_grips
	for row: Control in rows: node.add_row(row)
	return node


## Adds [param row] at the end of the list.
func add_row(row: Control) -> void:
	var slot := PanelContainer.new()
	slot.name = "Slot%d" % get_child_count()
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 0)
	slot.add_child(line)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(row)
	var grip := _Grip.new()
	grip.list = self
	grip.visible = grips
	line.add_child(grip)
	slot.set_meta(&"go_row", row)
	add_child(slot)


## Takes [param row] out of the list (it is not freed).
func remove_row(row: Control) -> void:
	for slot in _slots():
		if slot.get_meta(&"go_row") == row:
			(slot.get_node(^"Line") as Node).remove_child(row)
			remove_child(slot)
			slot.queue_free()
			return


## The rows, in the order shown.
func rows() -> Array[Control]:
	var out: Array[Control] = []
	for slot in _slots(): out.append(slot.get_meta(&"go_row") as Control)
	return out


## Moves the row at [param from] to [param to] and says so through `reordered`.
func move_row(from: int, to: int) -> void:
	var slots := _slots()
	if from < 0 or from >= slots.size(): return
	to = clampi(to, 0, slots.size() - 1)
	if from == to: return
	move_child(slots[from], to)
	queue_sort()
	reordered.emit(from, to)


## True while a row is being dragged.
func is_dragging() -> bool:
	return _lifted != null


func _slots() -> Array[Control]:
	var out: Array[Control] = []
	for child in get_children():
		if child is Control and not (child as Control).is_queued_for_deletion(): out.append(child as Control)
	return out


func _get_minimum_size() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for slot in _slots():
		if not slot.visible: continue
		var need := slot.get_combined_minimum_size()
		total.x = maxf(total.x, need.x)
		total.y += need.y
		count += 1
	total.y += spacing * maxi(0, count - 1)
	return total


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_lay_out(false)


## Works out where each row belongs — with a gap where the lifted row would land — and puts it there (or starts it
## gliding there when [param glide]).
func _lay_out(glide: bool) -> void:
	var y := 0.0
	var order := 0
	var gap := 0.0
	if _lifted != null: gap = _lifted.get_combined_minimum_size().y + spacing
	for slot in _slots():
		if not slot.visible: continue
		var height := slot.get_combined_minimum_size().y
		if slot == _lifted:
			_place(slot, _lifted_top(), height)
			continue
		if _lifted != null and order == _target: y += gap
		_goal[slot] = y
		if not glide or not _shown.has(slot): _shown[slot] = y
		_place(slot, float(_shown[slot]), height)
		y += height + spacing
		order += 1


func _place(slot: Control, top: float, height: float) -> void:
	fit_child_in_rect(slot, Rect2(0.0, top, size.x, height))


## The lifted row's top — under the finger, kept inside the list.
func _lifted_top() -> float:
	var local := get_global_transform_with_canvas().affine_inverse() * _finger
	var height := _lifted.get_combined_minimum_size().y
	return clampf(local.y - _grab, 0.0, maxf(0.0, size.y - height))


## Starts dragging [param slot]; the finger is at [param at] (viewport coordinates).
func _lift(slot: Control, at: Vector2) -> void:
	_lifted = slot
	_from = _slots().find(slot)
	_target = _from
	_finger = at
	_grab = (get_global_transform_with_canvas().affine_inverse() * at).y - slot.position.y
	slot.z_index = 1
	slot.add_theme_stylebox_override(&"panel", GoUi.skin().reorder_lift_box())
	# The press on the row is cancelled the way a scroll cancels it — lifting a row is not tapping it.
	slot.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	set_process(true)


## Drops the lifted row into the gap.
func _drop() -> void:
	var slot := _lifted
	_lifted = null
	slot.z_index = 0
	slot.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_shown[slot] = slot.position.y
	var to := _target
	if to != _from:
		move_child(slot, to)
		reordered.emit(_from, to)
	_from = -1
	_target = -1
	_lay_out(true)
	set_process(true)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree(): return
	var press := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (press != null and press.button_index == MOUSE_BUTTON_LEFT) or (touch != null and touch.index == 0):
		var down: bool = press.pressed if press != null else touch.pressed
		var at: Vector2 = press.position if press != null else touch.position
		if down:
			if _lifted != null:
				get_viewport().set_input_as_handled()
				return
			var slot := _slot_at(at)
			if slot == null: return
			if grips and _on_grip(slot, at):
				_lift(slot, at)
				get_viewport().set_input_as_handled()
			elif not grips:
				_held = slot
				_held_at = at
				_held_ms = Time.get_ticks_msec()
				set_process(true)
		else:
			_held = null
			if _lifted != null:
				get_viewport().set_input_as_handled()
				_drop()
		return
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	if motion == null and (drag == null or drag.index != 0): return
	var to: Vector2 = motion.position if motion != null else drag.position
	if _lifted != null:
		get_viewport().set_input_as_handled()
		# 🔑 Follow one stream: the mouse one the engine makes from touch (unless the project turned that off).
		if motion != null or not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
			_finger = to
			_follow()
		return
	# A finger that wanders while holding is scrolling the page, not lifting the row.
	if _held != null and to.distance_to(_held_at) > HOLD_SLOP: _held = null


func _process(delta: float) -> void:
	if _held != null and _lifted == null and Time.get_ticks_msec() - _held_ms >= hold_ms:
		var slot := _held
		_held = null
		_lift(slot, _held_at)
	if _lifted != null:
		_scroll_near_edge(delta)
		_follow()
	# Glide every row toward its place.
	var moving := false
	var blend := 1.0 - exp(-delta * 18.0)
	for slot in _slots():
		if slot == _lifted or not _goal.has(slot): continue
		var now := float(_shown.get(slot, _goal[slot]))
		var goal := float(_goal[slot])
		if absf(now - goal) > 0.5:
			now = lerpf(now, goal, blend)
			moving = true
		else:
			now = goal
		_shown[slot] = now
		_place(slot, now, slot.get_combined_minimum_size().y)
	if not moving and _lifted == null and _held == null: set_process(false)


## The lifted row follows the finger, and the gap moves to where it is: a row steps aside once the lifted row has
## passed half of it.
func _follow() -> void:
	if _lifted == null: return
	var height := _lifted.get_combined_minimum_size().y
	var top := _lifted_top()
	# Count the rows whose middle is above the lifted row's top, laid out as if the lifted row were gone.
	var target := 0
	var y := 0.0
	for slot in _slots():
		if slot == _lifted or not slot.visible: continue
		var own := slot.get_combined_minimum_size().y
		if y + own * 0.5 < top: target += 1
		y += own + spacing
	if target != _target:
		_target = target
		_lay_out(true)
	else:
		_place(_lifted, top, height)


## Near the top or bottom edge of the page that scrolls the list, the page scrolls toward that edge.
func _scroll_near_edge(delta: float) -> void:
	var page := _page()
	if page == null: return
	var rect := page.get_global_rect()
	var speed := 0.0
	if _finger.y < rect.position.y + EDGE: speed = -1.0 + (_finger.y - rect.position.y) / EDGE
	elif _finger.y > rect.end.y - EDGE: speed = 1.0 - (rect.end.y - _finger.y) / EDGE
	if speed != 0.0: page.scroll_vertical += roundi(clampf(speed, -1.0, 1.0) * 600.0 * delta)


func _page() -> ScrollContainer:
	var node := get_parent()
	while node != null:
		if node is ScrollContainer: return node as ScrollContainer
		node = node.get_parent()
	return null


func _slot_at(at: Vector2) -> Control:
	for slot in _slots():
		if slot.visible and slot.get_global_rect().has_point(at): return slot
	return null


func _on_grip(slot: Control, at: Vector2) -> bool:
	var grip := slot.get_node_or_null(^"Line/Grip") as Control
	return grip != null and grip.visible and grip.get_global_rect().has_point(at)


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	for slot in _slots(): (slot.get_node(^"Line/Grip") as Control).queue_redraw()
	if _lifted != null: _lifted.add_theme_stylebox_override(&"panel", GoUi.skin().reorder_lift_box())


## The grip at a row's end: six dots, a 48dp touch area, and Up/Down for the keyboard.
class _Grip extends Control:
	var list: GoReorderList

	func _init() -> void:
		name = "Grip"
		custom_minimum_size = Vector2(GRIP, GRIP)
		size_flags_vertical = Control.SIZE_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		focus_mode = Control.FOCUS_ALL
		# 🔑 A drag that starts on the grip is the grip's — the page never scrolls from it.
		set_meta(GoScroll.OWNS_GESTURE, true)

	func _ready() -> void:
		accessibility_name = GoUi.text(&"reorder")
		tooltip_text = GoUi.text(&"reorder")

	func _draw() -> void:
		var ink := GoUi.skin().reorder_grip_ink()
		var center := size * 0.5
		for row in 3:
			for column in 2:
				draw_circle(center + Vector2((column - 0.5) * 6.0, (row - 1) * 6.0), 1.6, ink, true, -1.0, true)
		if has_focus():
			var ring := get_theme_stylebox(&"focus", &"Button")
			if ring != null: draw_style_box(ring, Rect2(Vector2.ZERO, size))

	func _gui_input(event: InputEvent) -> void:
		if not (event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")): return
		var slot := get_parent().get_parent() as Control
		var at := list._slots().find(slot)
		list.move_row(at, at + (1 if event.is_action_pressed(&"ui_down") else -1))
		accept_event()
		grab_focus.call_deferred()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT: queue_redraw()
