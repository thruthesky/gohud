## 🎬 **A screen that comes in step by step** — a result card springing in, its stars stamping down one by one with a
## burst each, its rows sliding in, its numbers counting up and its keys springing up last, each key taking presses the
## moment it shows.
##
## ```gdscript
## var reveal := GoReveal.new(self)                           # `self` owns the tween
## reveal.fx = GoRevealFx.mount(window)                       # optional: slams burst and jolt the window as they land
## reveal.enter(window, 0.0)                                  # the window springs in
## reveal.slam(stars.star(0), 0.50).slam(stars.star(1), 0.75)  # one by one, each landing with a burst
## reveal.slide(kos_row, 0.80)                                 # from the left
## reveal.count(kos_value, 7, func(v: float) -> String: return str(int(v)), 0.80)
## reveal.key(retry_button, 1.90)                              # ignores presses until 1.9 s
## reveal.play()
## reveal.finish()                                              # skip to the end (a new card, a closed one)
## ```
##
## A step's item goes to its hidden state as soon as the step is added, so call it in the frame the screen opens and
## nothing flashes. Its item keeps its place in the layout throughout: a step moves its `modulate:a`, `scale` and
## `rotation` about its centre, and a slide or a key its `position` from the place its container gives it (followed if
## the container sorts again) and back onto it.
## - `enter`: a `GoSurface`'s card springs in from small, tilted, overshooting and settling (`GoSurface.pose_*`, so a
##   relayout while it plays keeps it), and thumps the window as it reaches full size.
## - `pop`: fades in and grows from `POP_FROM` with a small overshoot over `POP_SECONDS`.
## - `slam`: the emphasis entrance: falls from `SLAM_FROM` (bigger than itself), turning, lands squashed at
##   `SLAM_LAND` of its time — [signal landed]; with `fx` a burst there and a jolt of the window — and springs up onto
##   its place over `SLAM_SECONDS` — an earned star, a best move.
## - `slide`: comes in from `from` dp away with an overshoot, fading in — a stat row.
## - `fade`: fades in over `FADE_SECONDS`.
## - `key`: springs up from below, growing past its size and back, and ignores the mouse until its step starts, then
##   gets its own `mouse_filter` back, so a key works from the moment it appears and never before (`is_shown`).
## - `count`: writes `format.call(value)` into a label from 0 up to `to` over `seconds`. Until its step the label keeps
##   the text it has (the final one: the item around it is hidden), and while it counts the label keeps its final
##   width, so nothing around it moves.
## - `pulse`: an item already shown punches up to `PULSE_TO` and back over `PULSE_SECONDS` — a new best time once its
##   count lands (with `burst` > 0 and `fx`, a burst on it too). It never hides its item and never holds a key.
##
## `settle(item)` ends one item's steps early while the rest play on.
## [signal shown] says when each item starts coming in, [signal landed] when a slam hits (or an entrance reaches its
## size), [signal finished] when the last step is done or `finish` ran.
## ♿ **`GoConfig.reduce_motion`:** an entrance, a pop, a slam, a slide or a key only fades; a count shows its final
##    text; a pulse does nothing; no burst and no jolt ([signal landed] still comes on its beat).
## 🛑 Display only: what a step shows and when it starts is the caller's.
class_name GoReveal
extends RefCounted

## An item's step started: it is coming in now (a `key` takes presses from here).
signal shown(item: Control)
## A slam hit its place (or an entrance reached full size).
signal landed(item: Control)
## Every step is done, or `finish` ran.
signal finished

## How long a pop takes to settle.
const POP_SECONDS := 0.22
## The scale a pop starts from.
const POP_FROM := 0.6
## The share of a pop over which its item fades in (it is fully opaque before it settles).
const POP_FADE_SHARE := 0.5
## How long an entrance takes to spring in and settle.
const ENTER_SECONDS := 0.55
## The scale an entrance starts from, its first tilt (radians) and how hard it overshoots (a back ease's strength).
const ENTER_FROM := 0.4
const ENTER_TURN := -0.09
const ENTER_SPRING := 2.2
## The share of an entrance at which the card first reaches full size: it thumps the window there.
const ENTER_LAND := 0.4
## How long a slam takes to fall, land and settle.
const SLAM_SECONDS := 0.46
## The scale a slam starts from (above 1: it comes down onto its place) and its first turn (radians).
const SLAM_FROM := 2.8
const SLAM_TURN := -0.5
## The share of a slam at which it hits its place, and the scale it squashes to there.
const SLAM_LAND := 0.45
const SLAM_SQUASH := 0.78
## How long a slide takes and how hard it overshoots.
const SLIDE_SECONDS := 0.34
const SLIDE_SPRING := 1.6
## How long a key takes to spring up, how far below it starts (dp), the scale it starts from, how hard it overshoots.
const KEY_SECONDS := 0.4
const KEY_RISE := 46.0
const KEY_FROM := 0.35
const KEY_SPRING := 2.6
## How long a pulse takes, out and back.
const PULSE_SECONDS := 0.36
## The scale a pulse reaches at its peak.
const PULSE_TO := 1.25
## How long a fade takes.
const FADE_SECONDS := 0.18
## A count's default length.
const COUNT_SECONDS := 0.4

enum Kind { POP, FADE, KEY, COUNT, SLAM, PULSE, ENTER, SLIDE }

## The window's celebration (`GoRevealFx.mount`): a slam bursts on its item and jolts the window as it lands, an
## entrance thumps it, a pulse with `burst` bursts. Null: no light, no jolt.
var fx: GoRevealFx

var _host: Node
## One entry per step: item, kind, at, seconds, alpha (the item's own), mouse, pivot, to, format, width, from,
## strength, base (its place), held (base is kept), sorter (its container's sort hook), started, done.
var _steps: Array[Dictionary] = []
var _tween: Tween
var _playing := false
var _played := false
var _reduced := false


## `host` owns the reveal's tween (it stops with the host).
func _init(host: Node) -> void:
	_host = host


## `window`'s card springs in at `at` seconds.
func enter(window: GoSurface, at: float) -> GoReveal:
	return _add(window, Kind.ENTER, at, ENTER_SECONDS)


## `item` pops in at `at` seconds.
func pop(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.POP, at, POP_SECONDS)


## `item` slams in at `at` seconds: it falls from big onto its place and lands with a burst `strength` times a star's
## (with `fx`).
func slam(item: Control, at: float, strength := 1.0) -> GoReveal:
	_add(item, Kind.SLAM, at, SLAM_SECONDS)
	if item != null: _steps[-1].strength = strength
	return self


## `item` slides in at `at` seconds from `from` dp away (left of its place by default).
func slide(item: Control, at: float, from := Vector2(-90.0, 0.0)) -> GoReveal:
	_add(item, Kind.SLIDE, at, SLIDE_SECONDS)
	if item != null: _steps[-1].from = from
	return self


## `item`, already shown, punches up and back at `at` seconds (it is not hidden before); `burst` > 0 lights a burst
## that strong on it (with `fx`).
func pulse(item: Control, at: float, burst := 0.0) -> GoReveal:
	_add(item, Kind.PULSE, at, PULSE_SECONDS)
	if item != null: _steps[-1].strength = burst
	return self


## `item` fades in at `at` seconds.
func fade(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.FADE, at, FADE_SECONDS)


## `item` (a key) springs up at `at` seconds and takes no presses before then.
func key(item: Control, at: float) -> GoReveal:
	_add(item, Kind.KEY, at, KEY_SECONDS)
	if item != null: _steps[-1].from = Vector2(0.0, KEY_RISE)
	return self


## `label` counts from 0 up to `to` from `at` seconds, written by `format` (value → text).
func count(label: Label, to: float, format: Callable, at: float, seconds := COUNT_SECONDS) -> GoReveal:
	_add(label, Kind.COUNT, at, maxf(0.0, seconds))
	_steps[-1].to = to
	_steps[-1].format = format
	return self


## Starts the steps (once). With no steps it finishes at once.
func play() -> void:
	if _played:
		return
	_played = true
	_reduced = GoUi.config.reduce_motion
	_playing = true
	if _steps.is_empty() or _host == null or not _host.is_inside_tree():
		finish()
		return
	_tween = _host.create_tween().set_parallel(true)
	var end := 0.0
	for i in _steps.size():
		var s: Dictionary = _steps[i]
		var seconds: float = s.seconds
		if _reduced and s.kind != Kind.FADE:
			seconds = 0.0 if s.kind == Kind.COUNT or s.kind == Kind.PULSE else FADE_SECONDS
		_tween.tween_callback(_start.bind(i)).set_delay(s.at)
		if seconds > 0.0:
			var tweener := _tween.tween_method(_frame.bind(i), 0.0, 1.0, seconds).set_delay(s.at)
			if s.kind == Kind.COUNT:
				tweener.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		match s.kind: # under reduce motion too: a caller's sound keeps its beat (the light and the jolt stay off)
			Kind.SLAM: _tween.tween_callback(_land.bind(i)).set_delay(s.at + seconds * SLAM_LAND)
			Kind.ENTER: _tween.tween_callback(_land.bind(i)).set_delay(s.at + seconds * ENTER_LAND)
			Kind.PULSE: if s.strength > 0.0: _tween.tween_callback(_land.bind(i)).set_delay(s.at)
		_tween.tween_callback(_end.bind(i)).set_delay(s.at + seconds)
		end = maxf(end, s.at + seconds)
	_tween.tween_callback(_finish_now).set_delay(end)


## Every step to its end now: each item shown, each count on its final text, each key taking presses.
func finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish_now()


## `item`'s steps to their end now (shown, taking presses), the rest playing on: for a caller that takes the item over
## (a key whose action went away while it was still coming in).
func settle(item: Control) -> void:
	for i in _steps.size():
		if _steps[i].item == item:
			_end(i)


## Whether `item` is on screen (its entrance started, or it has none): a key takes presses.
func is_shown(item: Control) -> bool:
	for s in _steps:
		if s.item == item and s.kind != Kind.PULSE and not s.started:
			return false
	return true


## Whether the steps are still coming in.
func is_playing() -> bool:
	return _playing


## The time (s) the last step settles at, from `play`.
func length() -> float:
	var end := 0.0
	for s in _steps:
		end = maxf(end, s.at + s.seconds)
	return end


## The time (s) `item`'s slam lands at, from `play` (-1: it has none) — a caller timing a sound or a light to it.
func landing(item: Control) -> float:
	for s in _steps:
		if s.item == item and s.kind == Kind.SLAM:
			return s.at + s.seconds * SLAM_LAND
	return -1.0


func _add(item: Control, kind: Kind, at: float, seconds: float) -> GoReveal:
	if item == null:
		return self
	var shown_part := _face(item, kind)
	var s := {item = item, kind = kind, at = maxf(0.0, at), seconds = seconds, alpha = shown_part.modulate.a,
			mouse = item.mouse_filter, pivot = item.pivot_offset, to = 0.0, format = Callable(), width = 0.0,
			from = Vector2.ZERO, strength = 0.0, base = Vector2.ZERO, held = false, sorter = Callable(), started = false,
			done = false}
	_steps.append(s)
	match kind:
		Kind.POP, Kind.FADE, Kind.SLAM, Kind.SLIDE, Kind.ENTER:
			shown_part.modulate.a = 0.0
		Kind.KEY:
			item.modulate.a = 0.0
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


## What a step fades: a window's card (an entrance), else the item.
static func _face(item: Control, kind: Kind) -> Control:
	return (item as GoSurface).card if kind == Kind.ENTER else item


func _start(i: int) -> void:
	var s: Dictionary = _steps[i]
	if s.started:
		return
	s.started = true
	if not is_instance_valid(s.item):
		return
	var item: Control = s.item
	if s.kind == Kind.KEY:
		item.mouse_filter = s.mouse
	if (s.kind == Kind.KEY or s.kind == Kind.SLIDE) and not _reduced:
		_hold_place(s)
	elif s.kind == Kind.COUNT and not _reduced:
		var label := item as Label
		# Hold the final text's width, so a shorter number on the way never moves what is round it.
		s.width = label.custom_minimum_size.x
		label.custom_minimum_size.x = maxf(s.width, label.get_minimum_size().x)
		label.text = s.format.call(0.0)
	shown.emit(item)


## A moving step keeps its item's place: where it is now, and again each time its container sorts.
func _hold_place(s: Dictionary) -> void:
	var item: Control = s.item
	s.base = item.position
	s.held = true
	var container := item.get_parent() as Container
	if container != null:
		s.sorter = func() -> void:
			if is_instance_valid(item): s.base = item.position
		container.sort_children.connect(s.sorter)


func _let_place(s: Dictionary) -> void:
	if not s.held:
		return
	s.held = false
	var item: Control = s.item
	var container := item.get_parent() as Container
	if s.sorter.is_valid() and container != null and container.sort_children.is_connected(s.sorter):
		container.sort_children.disconnect(s.sorter)
	s.sorter = Callable()
	item.position = s.base


func _frame(k: float, i: int) -> void:
	var s: Dictionary = _steps[i]
	if s.done or not is_instance_valid(s.item):
		return
	var item: Control = s.item
	k = clampf(k, 0.0, 1.0)
	if _reduced and s.kind != Kind.COUNT and s.kind != Kind.PULSE:
		_face(item, s.kind).modulate.a = s.alpha * k
		return
	match s.kind:
		Kind.FADE:
			item.modulate.a = s.alpha * k
		Kind.ENTER:
			var window := item as GoSurface
			window.card.modulate.a = s.alpha * clampf(k / 0.2, 0.0, 1.0)
			window.pose_scale = lerpf(ENTER_FROM, 1.0, back_out(k, ENTER_SPRING))
			window.pose_turn = ENTER_TURN * (1.0 - k) * (1.0 - k) * cos(k * TAU)
		Kind.SLAM:
			item.modulate.a = s.alpha * clampf(k / (SLAM_LAND * 0.5), 0.0, 1.0)
			_centre(item)
			if k < SLAM_LAND:
				var fall := k / SLAM_LAND
				fall *= fall # it speeds up as it falls
				item.scale = Vector2.ONE * lerpf(SLAM_FROM, SLAM_SQUASH, fall)
				item.rotation = SLAM_TURN * (1.0 - fall)
			else:
				var up := (k - SLAM_LAND) / (1.0 - SLAM_LAND)
				var grow := lerpf(SLAM_SQUASH, 1.0, back_out(up, 2.4))
				var squash := 0.22 * pow(1.0 - up, 3.0) # wide and flat at the hit
				item.scale = Vector2(grow * (1.0 + squash), grow * (1.0 - squash))
				item.rotation = 0.0
		Kind.PULSE:
			_centre(item)
			item.scale = Vector2.ONE * (1.0 + (PULSE_TO - 1.0) * sin(PI * k))
		Kind.SLIDE:
			item.modulate.a = s.alpha * clampf(k / 0.35, 0.0, 1.0)
			item.position = s.base + s.from * (1.0 - back_out(k, SLIDE_SPRING))
		Kind.POP:
			item.modulate.a = s.alpha * clampf(k / POP_FADE_SHARE, 0.0, 1.0)
			_centre(item)
			item.scale = Vector2.ONE * lerpf(POP_FROM, 1.0, back_out(k, 1.70158))
		Kind.KEY:
			item.modulate.a = s.alpha * clampf(k / 0.3, 0.0, 1.0)
			_centre(item)
			item.scale = Vector2.ONE * lerpf(KEY_FROM, 1.0, back_out(k, KEY_SPRING))
			var rise := 1.0 - pow(1.0 - k, 3.0)
			item.position = s.base + s.from * (1.0 - rise)
		Kind.COUNT:
			(item as Label).text = s.format.call(s.to * k)


## The centre stays put; set every frame, as a container's sort puts scale back to 1 and the size can change.
static func _centre(item: Control) -> void:
	item.pivot_offset = item.size * 0.5


## A back ease out: 0 → 1, past 1 by an amount `spring` sets, then back.
static func back_out(k: float, spring: float) -> float:
	var t := k - 1.0
	return 1.0 + (spring + 1.0) * t * t * t + spring * t * t


func _land(i: int) -> void:
	var s: Dictionary = _steps[i]
	if s.done or not is_instance_valid(s.item):
		return
	var item: Control = s.item
	landed.emit(item)
	if _reduced or fx == null or not is_instance_valid(fx):
		return
	match s.kind:
		Kind.ENTER:
			fx.shake(0.5)
		Kind.SLAM:
			fx.burst(item, s.strength)
			fx.shake(s.strength)
		Kind.PULSE:
			fx.burst(item, s.strength)


func _end(i: int) -> void:
	var s: Dictionary = _steps[i]
	if s.done:
		return
	_start(i)
	s.done = true
	if not is_instance_valid(s.item):
		return
	var item: Control = s.item
	match s.kind:
		Kind.ENTER:
			var window := item as GoSurface
			window.card.modulate.a = s.alpha
			window.pose_scale = 1.0
			window.pose_turn = 0.0
		Kind.POP, Kind.FADE, Kind.KEY, Kind.SLAM, Kind.SLIDE:
			item.modulate.a = s.alpha
			item.scale = Vector2.ONE
			item.rotation = 0.0
			item.pivot_offset = s.pivot
			_let_place(s)
		Kind.PULSE: # its alpha belongs to its entrance (or to itself)
			item.scale = Vector2.ONE
			item.pivot_offset = s.pivot
		Kind.COUNT:
			var label := item as Label
			label.text = s.format.call(s.to)
			if not _reduced:
				label.custom_minimum_size.x = s.width


func _finish_now() -> void:
	for i in _steps.size():
		_end(i)
	_tween = null
	var was := _playing
	_playing = false
	if was:
		finished.emit()
