## 🗂️ **Tabs with pages you swipe between** — "For you · Following · News" over a page each, where a sideways swipe
## goes to the next tab and a tap on a tab slides to its page (Flutter's `TabBar` + `TabBarView`).
##
## ```gdscript
## var view := GoTabView.make(["For you", "Following", "News"], [for_you_scroll, following_scroll, news_scroll])
## view.tab_changed.connect(func(index: int) -> void: load_tab(index))
## screen.add_child(view)            # give it the room — it fills what it is given
## ```
##
## ## 🔑 Every page keeps its own scroll
## A page is usually a `GoScroll` (or a `GoListView`). An up-and-down swipe scrolls that page; only a swipe that goes
## sideways first turns the page. A press that lands on something that moves sideways itself — a horizontal chip
## strip, a slider, a swipeable row — is left to it.
##
## ## 🔑 It follows the finger
## The pages slide with the finger and settle on the nearer one when it lets go (a quick flick turns the page even when
## short). With `reduce_motion` the page changes without sliding.
@tool
class_name GoTabView
extends VBoxContainer

## The shown tab changed — by a tap on its tab, a swipe, or `set_tab()`.
signal tab_changed(index: int)

## Sideways travel (dp) before a drag is taken as a page turn, not a tap or a scroll.
@export var swipe_slop := 10.0

## The tab row.
var tab_bar: TabBar

var _pager: Control
var _pages: Array[Control] = []
var _index := 0
var _drag := 0.0
var _from := Vector2.INF
var _claimed := false
var _ignored := false
var _started_ms := 0
var _tween: Tween


func _init() -> void:
	name = "TabView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The pages keep a gap from the tab line — flush against it, a page's first line read as part of the tabs.
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))


## Tabs named [param names] over [param pages] (one `Control` per tab), [param selected] shown first.
static func make(names: Array, pages: Array, selected := 0, translate := false) -> GoTabView:
	var node := GoTabView.new()
	# Fixed tabs across the whole row, as Flutter's `TabBar` under a `TabBarView`.
	node.tab_bar = GoStyle.tabs(names, selected, translate, true)
	node.add_child(node.tab_bar)
	node._pager = Control.new()
	node._pager.name = "Pages"
	node._pager.clip_contents = true
	node._pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node._pager.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node._pager.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(node._pager)
	for page in pages:
		var each := page as Control
		if each == null: continue
		node._pages.append(each)
		node._pager.add_child(each)
	node._index = clampi(selected, 0, maxi(0, node._pages.size() - 1))
	node.tab_bar.tab_changed.connect(func(index: int) -> void: node.set_tab(index))
	node._pager.resized.connect(node._place)
	return node


## The shown tab.
func current() -> int:
	return _index


## The page of tab [param index].
func page(index: int) -> Control:
	return _pages[index] if index >= 0 and index < _pages.size() else null


## Shows tab [param index], sliding to it unless [param animate] is false or motion is reduced.
func set_tab(index: int, animate := true) -> void:
	index = clampi(index, 0, maxi(0, _pages.size() - 1))
	var changed := index != _index
	var from_offset := _side() * float(_index - index) * _pager.size.x + _drag
	_index = index
	_drag = 0.0
	if tab_bar.current_tab != index: tab_bar.set_current_tab(index)
	if is_instance_valid(_tween): _tween.kill()
	if animate and not GoUi.config.reduce_motion and absf(from_offset) > 0.5:
		_drag = from_offset
		_tween = create_tween()
		_tween.tween_method(func(value: float) -> void:
			_drag = value
			_place(), from_offset, 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_place()
	if changed: tab_changed.emit(index)


## +1 when the next page lies to the right (left-to-right), -1 in a right-to-left language.
func _side() -> float:
	return -1.0 if is_layout_rtl() else 1.0


## Lays the pages side by side in reading order; the shown one fills the view, moved by the drag.
func _place() -> void:
	if _pager == null: return
	var width := _pager.size.x
	for at in _pages.size():
		var each := _pages[at]
		var x := _side() * float(at - _index) * width + _drag
		each.visible = absf(x) < width - 0.5 or at == _index
		each.position = Vector2(x, 0.0)
		each.size = _pager.size


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree() or _pages.size() < 2 or _pager == null: return
	var press := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (press != null and press.button_index == MOUSE_BUTTON_LEFT) or touch != null:
		var down: bool = press.pressed if press != null else touch.pressed
		var at: Vector2 = press.position if press != null else touch.position
		if down:
			_from = at if _pager.get_global_rect().has_point(at) else Vector2.INF
			_claimed = false
			_ignored = _from.is_finite() and _owned_sideways(at)
			_started_ms = Time.get_ticks_msec()
		elif _from.is_finite():
			if _claimed:
				get_viewport().set_input_as_handled()
				_settle()
			_from = Vector2.INF
			_claimed = false
		return
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	if (motion == null and drag == null) or not _from.is_finite() or _ignored: return
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0: return
	var at: Vector2 = motion.position if motion != null else drag.position
	var travel := at - _from
	if not _claimed:
		if travel.length() < swipe_slop: return
		if absf(travel.x) <= absf(travel.y) * 1.2:
			_from = Vector2.INF
			return
		_claimed = true
		if is_instance_valid(_tween): _tween.kill()
		# The press on the page is cancelled the way a scroll cancels it.
		_pages[_index].propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	get_viewport().set_input_as_handled()
	var push := travel.x
	# 🔑 Past the first or the last page the drag meets resistance instead of showing nothing.
	var forward := push * _side() < 0.0
	if (forward and _index >= _pages.size() - 1) or (not forward and _index <= 0): push *= 0.25
	_drag = push
	_place()


## Turns the page when the drag went far enough (or was a quick flick), else springs back.
func _settle() -> void:
	var width := maxf(1.0, _pager.size.x)
	var quick := Time.get_ticks_msec() - _started_ms < 250 and absf(_drag) > width * 0.08
	var step := 0
	if absf(_drag) > width * 0.5 or quick: step = 1 if _drag * _side() < 0.0 else -1
	var target := clampi(_index + step, 0, _pages.size() - 1)
	if target == _index:
		var back := _drag
		if is_instance_valid(_tween): _tween.kill()
		if GoUi.config.reduce_motion:
			_drag = 0.0
			_place()
			return
		_tween = create_tween()
		_tween.tween_method(func(value: float) -> void:
			_drag = value
			_place(), back, 0.0, 0.15)
		return
	GoFeedback.tapped()
	set_tab(target)


## Does the press at [param at] land on something that moves sideways itself? Then the page does not turn from it.
func _owned_sideways(at: Vector2) -> bool:
	var hit := GoScroll.control_at(_pager, at)
	while hit != null and hit != self:
		if hit is HSlider or hit is GoSwipeRow or hit.has_meta(GoScroll.OWNS_GESTURE) or hit.has_meta(GoScroll.SIDEWAYS):
			return true
		var strip := hit as ScrollContainer
		if strip != null and strip.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
				and strip.get_h_scroll_bar().max_value > strip.size.x + 0.5:
			return true
		hit = hit.get_parent_control()
	return false
