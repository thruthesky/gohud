## 👉 **A row you swipe aside** — swipe a mail to archive it, a cart line to remove it (Flutter's `Dismissible`).
## The row slides with the finger over a coloured strip that names the action; past the threshold it acts.
##
## ```gdscript
## var line := GoSwipeRow.wrap(GoStyle.list_row(Button.new(), GoIconSet.USER, "Ann"),
## 	{"icon": GoIconSet.TRASH, "text": "Delete", "tone": GoTheme.DANGER, "action": delete_mail.bind(id)},
## 	{"icon": GoIconSet.CHECK, "text": "Read", "tone": GoTheme.SUCCESS, "action": mark_read.bind(id), "dismiss": false})
## list.add_child(line)
## ```
##
## ## 🔑 Which way does what
## `end_action` is revealed by a swipe toward the start (right to left in a left-to-right language), `start_action` by
## a swipe toward the end. Leave one empty and the row does not move that way. An action with `"dismiss": true` (the
## default) slides the row away and folds its height to nothing, then frees it; with `false` the row springs back.
##
## ## 🔑 It never takes a scroll
## Only a drag that goes sideways first is the row's — an up-and-down swipe that starts on it scrolls the list as
## before, and a tap still presses the row. Once it moves sideways the press on the row is cancelled, so a swipe never
## also opens the mail.
##
## ## ♿ Swiping is not the only way
## A swipe is invisible until tried. Keep the same action reachable from the row's detail screen or a long-press menu
## (`GoContextMenu`); `trigger(direction)` runs one from code.
@tool
class_name GoSwipeRow
extends Container

## An action ran: -1 the end action (swiped toward the start), 1 the start action.
signal swiped(direction: int)
## The row slid away and folded — it frees itself next.
signal dismissed

## The fraction of the row's width a swipe has to pass to act.
@export_range(0.1, 0.9, 0.05) var threshold := 0.4
## Free the row once it has folded away after a dismissing action.
@export var free_on_dismiss := true

## The row inside.
var content: Control
## Revealed by a swipe toward the start — `{"icon", "text", "tone", "action", "dismiss"}`.
var end_action := {}
## Revealed by a swipe toward the end.
var start_action := {}

## Shows the strip only where the row has moved off it — a see-through row (most themes' list rows) would let the
## whole strip show through it otherwise (2026-10-02 screenshots).
var _uncovered: Control
var _back: PanelContainer
var _back_row: HBoxContainer
var _offset := 0.0
var _fold := 1.0
var _from := Vector2.INF
var _claimed := false
var _tween: Tween


func _init() -> void:
	name = "SwipeRow"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_uncovered = Control.new()
	_uncovered.name = "Behind"
	_uncovered.clip_contents = true
	_uncovered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uncovered.visible = false
	add_child(_uncovered)
	_back = PanelContainer.new()
	_back.name = "Strip"
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uncovered.add_child(_back)
	_back_row = HBoxContainer.new()
	_back_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_row.add_theme_constant_override(&"separation", 8)
	_back.add_child(_back_row)


## Wraps [param row] so it can be swiped: [param end] is revealed toward the start, [param start] toward the end.
static func wrap(row: Control, end := {}, start := {}) -> GoSwipeRow:
	var node := GoSwipeRow.new()
	node.content = row
	node.end_action = end
	node.start_action = start
	node.add_child(row)
	return node


## Runs an action as if swiped: -1 the end action, 1 the start action.
func trigger(direction: int) -> void:
	var spec := end_action if direction < 0 else start_action
	if spec.is_empty(): return
	_act(direction, spec)


func _get_minimum_size() -> Vector2:
	var inner := content.get_combined_minimum_size() if is_instance_valid(content) else Vector2.ZERO
	return Vector2(inner.x, inner.y * _fold)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		# The strip spans the whole row; the window onto it is the part the row has moved off.
		var open := Rect2(size.x + _offset, 0.0, -_offset, size.y) if _offset < 0.0 else Rect2(0.0, 0.0, _offset, size.y)
		fit_child_in_rect(_uncovered, open)
		_back.position = -open.position
		_back.size = size
		if is_instance_valid(content):
			var inner := content.get_combined_minimum_size()
			fit_child_in_rect(content, Rect2(Vector2(_offset, 0.0), Vector2(size.x, maxf(size.y, inner.y))))


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree() or (end_action.is_empty() and start_action.is_empty()): return
	var press := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (press != null and press.button_index == MOUSE_BUTTON_LEFT) or touch != null:
		var down: bool = press.pressed if press != null else touch.pressed
		var at: Vector2 = press.position if press != null else touch.position
		if down:
			_from = at if get_global_rect().has_point(at) else Vector2.INF
			_claimed = false
		elif _from.is_finite():
			if _claimed:
				get_viewport().set_input_as_handled()
				_release()
			_from = Vector2.INF
			_claimed = false
		return
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	if (motion == null and drag == null) or not _from.is_finite(): return
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0: return
	var at: Vector2 = motion.position if motion != null else drag.position
	var travel := at - _from
	if not _claimed:
		# 🔑 Sideways first, and past a small dead zone — otherwise it is the list's scroll or a tap.
		if travel.length() < 8.0: return
		if absf(travel.x) <= absf(travel.y) * 1.2:
			_from = Vector2.INF
			return
		_claimed = true
		# The press on the row is cancelled the way a scroll cancels it — the row is not "clicked" by a swipe.
		if is_instance_valid(content): content.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	get_viewport().set_input_as_handled()
	var physical := travel.x
	# Toward the start = left in LTR, right in RTL.
	var toward_start := physical < 0.0 if not is_layout_rtl() else physical > 0.0
	var spec := end_action if toward_start else start_action
	if spec.is_empty():
		physical = 0.0
	_set_offset(physical)


func _set_offset(value: float) -> void:
	_offset = value
	var toward_start := value < 0.0 if not is_layout_rtl() else value > 0.0
	var spec := end_action if toward_start else start_action
	_uncovered.visible = absf(value) > 0.5 and not spec.is_empty()
	if _uncovered.visible: _dress_back(spec, value < 0.0)
	queue_sort()


## The strip behind: the action's colour with its icon and words on the side the row uncovers.
func _dress_back(spec: Dictionary, uncovering_right: bool) -> void:
	var tone: Color = GoUi.color(StringName(spec.get("tone", GoTheme.ACCENT)))
	var face := StyleBoxFlat.new()
	face.bg_color = tone
	face.content_margin_left = GoUi.metric(GoTheme.GAP)
	face.content_margin_right = GoUi.metric(GoTheme.GAP)
	_back.add_theme_stylebox_override(&"panel", face)
	var ink := GoSkin.readable_on(GoUi.color(GoTheme.ON_ACCENT), tone)
	if GoSkin.contrast_ratio(ink, tone) < 4.5: ink = GoSkin.readable_on(GoUi.color(GoTheme.TEXT), tone)
	for child in _back_row.get_children():
		_back_row.remove_child(child)
		child.queue_free()
	_back_row.alignment = BoxContainer.ALIGNMENT_END if uncovering_right else BoxContainer.ALIGNMENT_BEGIN
	var icon := StringName(spec.get("icon", &""))
	if not icon.is_empty():
		var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.ICON_SIZE), ink)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_back_row.add_child(glyph)
	var words := str(spec.get("text", ""))
	if not words.is_empty():
		var label := GoStyle.label(words, GoTheme.ROLE_BUTTON, ink)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.set_meta(&"go_no_wrap", true)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_back_row.add_child(label)


func _release() -> void:
	var toward_start := _offset < 0.0 if not is_layout_rtl() else _offset > 0.0
	var spec := end_action if toward_start else start_action
	if absf(_offset) >= size.x * threshold and not spec.is_empty():
		_act(-1 if toward_start else 1, spec)
	else:
		_slide_to(0.0)


func _act(direction: int, spec: Dictionary) -> void:
	GoFeedback.tapped()
	var action: Callable = spec.get("action", Callable())
	if not bool(spec.get("dismiss", true)):
		_slide_to(0.0)
		swiped.emit(direction)
		if action.is_valid(): action.call()
		return
	var toward_start_physical := -1.0 if not is_layout_rtl() else 1.0
	var away := size.x * (toward_start_physical if direction < 0 else -toward_start_physical)
	_set_offset(_offset if absf(_offset) > 0.5 else away * 0.01)
	if is_instance_valid(_tween): _tween.kill()
	var seconds := 0.0 if GoUi.config.reduce_motion else 0.18
	_tween = create_tween()
	_tween.tween_method(_set_offset, _offset, away, seconds)
	_tween.tween_method(func(value: float) -> void:
		_fold = value
		update_minimum_size(), 1.0, 0.0, seconds)
	_tween.tween_callback(func() -> void:
		swiped.emit(direction)
		if action.is_valid(): action.call()
		dismissed.emit()
		if free_on_dismiss: queue_free())


func _slide_to(value: float) -> void:
	if is_instance_valid(_tween): _tween.kill()
	if GoUi.config.reduce_motion:
		_set_offset(value)
		return
	_tween = create_tween()
	_tween.tween_method(_set_offset, _offset, value, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
