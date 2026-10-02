## 🔄 **Pull to refresh** — pull a list down past its top and let go to reload it (Flutter's `RefreshIndicator`,
## Cupertino's refresh control). A round indicator follows the finger down from the top of the list, spins while the
## work runs, and slides away when you call `finish()`.
##
## ```gdscript
## var refresh := GoRefresh.attach(feed_scroll)
## refresh.refresh_requested.connect(func() -> void:
## 	await fetch_posts()
## 	refresh.finish())
## ```
## 🛑 Connect after `attach()` returns, as above: a lambda handed to `attach()` itself captures `refresh` before it is
##    assigned, and its `refresh.finish()` would call into null.
##
## ## 🔑 It never fights the list
## It only reacts while the list is already at its top and the finger moves **down**. Any other drag is the list's,
## and nothing is taken from it: the indicator reads the same events the list does and holds none of them back.
##
## ## 🔑 Busy means busy
## While `refreshing` is true a second pull does nothing — no request is fired twice. `finish()` (or `refreshing =
## false`) ends it. The indicator is a `GoProgress` ring on a raised disc; under `reduce_motion` it does not spin.
@tool
class_name GoRefresh
extends Control

## The user pulled far enough and let go — start the work, then call `finish()`.
signal refresh_requested

## How far (dp) the finger has to pull before letting go refreshes.
@export var trigger_dp := 64.0
## The gap between the top of the list and the spinning disc while refreshing (dp).
@export var rest_dp := 16.0

## True while the work runs (set by a pull, cleared by `finish()`).
var refreshing := false:
	set(value):
		refreshing = value
		_ring.indeterminate = value
		# The whole disc shows while it spins, `rest_dp` below the list's top edge.
		_target = DISC + rest_dp if value else 0.0
		if not value: _pull = 0.0

## Side of the indicator disc (dp).
const DISC := 40.0

var _scroll: ScrollContainer
var _action := Callable()
var _disc: PanelContainer
var _ring: GoProgress
## Where a press started (viewport coordinates) and whether the list was at its top then.
var _from := Vector2.INF
var _armed := false
var _pull := 0.0
var _shown := 0.0
var _target := 0.0


func _init() -> void:
	name = "Refresh"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🔑 Out of the parent's layout (a container skips a top-level child) and laid over the list by hand, clipped
	#    to it — the disc comes down from the list's own top edge, never over the app bar above it.
	top_level = true
	clip_contents = true
	_disc = PanelContainer.new()
	_disc.name = "Disc"
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.custom_minimum_size = Vector2.ONE * DISC
	_disc.size = Vector2.ONE * DISC
	add_child(_disc)
	_ring = GoProgress.circular()
	_ring.wavy = false
	_ring.custom_minimum_size = Vector2.ONE * (DISC - 12.0)
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_disc.add_child(_ring)
	visible = false


func _ready() -> void:
	_restyle()
	GoUi.watch(_restyle)


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## Pull to refresh on [param scroll]; [param action] is called on each refresh (call `finish()` when it is done).
## The indicator is added beside the scroll and drawn over it.
static func attach(scroll: ScrollContainer, action := Callable()) -> GoRefresh:
	var node := GoRefresh.new()
	node._scroll = scroll
	node._action = action
	scroll.add_sibling.call_deferred(node)
	return node


## The work is done — the indicator slides away and the list can be pulled again.
func finish() -> void:
	refreshing = false


func _restyle() -> void:
	_disc.add_theme_stylebox_override(&"panel", GoUi.skin().refresh_disc_box())


func _input(event: InputEvent) -> void:
	if refreshing or not is_instance_valid(_scroll) or not _scroll.is_visible_in_tree() or Engine.is_editor_hint(): return
	var press := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (press != null and press.button_index == MOUSE_BUTTON_LEFT) or touch != null:
		var down: bool = press.pressed if press != null else touch.pressed
		var at: Vector2 = press.position if press != null else touch.position
		if down:
			if not _scroll.get_global_rect().has_point(at): return
			_from = at
			_armed = _scroll.scroll_vertical <= 0
			_pull = 0.0
		elif _from.is_finite():
			_from = Vector2.INF
			_armed = false
			if _pull >= trigger_dp: _start()
			else: _pull = 0.0
		return
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	if (motion == null and drag == null) or not _from.is_finite() or not _armed: return
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0: return
	var at: Vector2 = motion.position if motion != null else drag.position
	var down := at.y - _from.y
	# 🔑 The list moved, or the finger went up — this is a scroll, not a pull.
	if _scroll.scroll_vertical > 0 or down < 0.0:
		_armed = _scroll.scroll_vertical <= 0 and down >= 0.0
		_pull = 0.0
		return
	# A pull meets more resistance the further it goes.
	_pull = trigger_dp * 1.6 * (1.0 - exp(-down / (trigger_dp * 1.6)))


func _start() -> void:
	refreshing = true
	GoFeedback.tapped()
	refresh_requested.emit()
	if _action.is_valid(): _action.call()


func _process(delta: float) -> void:
	if not is_instance_valid(_scroll): return
	var goal := _pull if _pull > 0.0 else _target
	_shown = lerpf(_shown, goal, 1.0 - exp(-delta * 18.0)) if not GoUi.config.reduce_motion else goal
	if absf(_shown - goal) < 0.5: _shown = goal
	visible = _shown > 0.5 or refreshing
	if not visible: return
	if not refreshing: _ring.value = clampf(_pull / trigger_dp, 0.0, 1.0)
	var rect := _scroll.get_global_rect()
	global_position = rect.position
	size = rect.size
	_disc.position = Vector2((rect.size.x - DISC) * 0.5, -DISC + _shown)
	_disc.modulate.a = clampf(_shown / (DISC * 0.5), 0.0, 1.0)
