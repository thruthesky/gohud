## 🎬 **A screen that comes in step by step** — a result card's stars popping in one by one, its numbers counting up
## and its keys last, each key taking presses the moment it shows.
##
## ```gdscript
## var reveal := GoReveal.new(self)                           # `self` owns the tween
## reveal.pop(stars.star(0), 0.10).pop(stars.star(1), 0.25)    # one by one
## reveal.pop(kos_row, 0.20)
## reveal.count(kos_value, 7, func(v: float) -> String: return str(int(v)), 0.20)
## reveal.key(retry_button, 0.65)                              # ignores presses until 0.65 s
## reveal.play()
## reveal.finish()                                              # skip to the end (a new card, a closed one)
## ```
##
## A step's item goes to its hidden state as soon as the step is added, so call it in the frame the screen opens and
## nothing flashes. It moves only `modulate:a` and `scale`, about the item's centre, never its position, so a container
## can lay it out as usual; the item keeps its place in the layout throughout.
## - `pop`: fades in and grows from `POP_FROM` with a small overshoot over `POP_SECONDS`.
## - `slam`: the emphasis entrance: fades in fast and stamps down from `SLAM_FROM` (bigger than itself) with a bounce
##   over `SLAM_SECONDS` — an earned star, a best move.
## - `fade`: fades in over `FADE_SECONDS`.
## - `key`: a pop that ignores the mouse until its step starts, then gets its own `mouse_filter` back, so a key works
##   from the moment it appears and never before (`is_shown`).
## - `count`: writes `format.call(value)` into a label from 0 up to `to` over `seconds`. Until its step the label keeps
##   the text it has (the final one: the item around it is hidden), and while it counts the label keeps its final
##   width, so nothing around it moves.
## - `pulse`: an item already shown punches up to `PULSE_TO` and back over `PULSE_SECONDS` — a new best time once its
##   count lands. It never hides its item and never holds a key.
##
## `settle(item)` ends one item's steps early while the rest play on.
## [signal shown] says when each item starts coming in, [signal finished] when the last step is done or `finish` ran.
## ♿ **`GoConfig.reduce_motion`:** a pop, a slam or a key only fades; a count shows its final text; a pulse does
##    nothing.
## 🛑 Display only: what a step shows and when it starts is the caller's.
class_name GoReveal
extends RefCounted

## An item's step started: it is coming in now (a `key` takes presses from here).
signal shown(item: Control)
## Every step is done, or `finish` ran.
signal finished

## How long a pop (and a key) takes to settle.
const POP_SECONDS := 0.22
## The scale a pop starts from.
const POP_FROM := 0.6
## The share of a pop over which its item fades in (it is fully opaque before it settles).
const POP_FADE_SHARE := 0.5
## How long a slam takes to land and settle.
const SLAM_SECONDS := 0.32
## The scale a slam starts from (above 1: it comes down onto its place).
const SLAM_FROM := 2.2
## The share of a slam over which its item fades in.
const SLAM_FADE_SHARE := 0.25
## How long a pulse takes, out and back.
const PULSE_SECONDS := 0.36
## The scale a pulse reaches at its peak.
const PULSE_TO := 1.25
## How long a fade takes.
const FADE_SECONDS := 0.18
## A count's default length.
const COUNT_SECONDS := 0.4

enum Kind { POP, FADE, KEY, COUNT, SLAM, PULSE }

var _host: Node
## One entry per step: item, kind, at, seconds, alpha (the item's own), mouse, pivot, to, format, width, started, done.
var _steps: Array[Dictionary] = []
var _tween: Tween
var _playing := false
var _played := false
var _reduced := false


## `host` owns the reveal's tween (it stops with the host).
func _init(host: Node) -> void:
	_host = host


## `item` pops in at `at` seconds.
func pop(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.POP, at, POP_SECONDS)


## `item` slams in at `at` seconds: it lands from big onto its place (the emphasis entrance).
func slam(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.SLAM, at, SLAM_SECONDS)


## `item`, already shown, punches up and back at `at` seconds (it is not hidden before).
func pulse(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.PULSE, at, PULSE_SECONDS)


## `item` fades in at `at` seconds.
func fade(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.FADE, at, FADE_SECONDS)


## `item` (a key) pops in at `at` seconds and takes no presses before then.
func key(item: Control, at: float) -> GoReveal:
	return _add(item, Kind.KEY, at, POP_SECONDS)


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
			if s.kind == Kind.POP or s.kind == Kind.KEY:
				if not _reduced:
					tweener.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			elif s.kind == Kind.SLAM:
				if not _reduced:
					tweener.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			elif s.kind == Kind.COUNT:
				tweener.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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


func _add(item: Control, kind: Kind, at: float, seconds: float) -> GoReveal:
	if item == null:
		return self
	var s := {item = item, kind = kind, at = maxf(0.0, at), seconds = seconds, alpha = item.modulate.a,
			mouse = item.mouse_filter, pivot = item.pivot_offset, to = 0.0, format = Callable(), width = 0.0,
			started = false, done = false}
	_steps.append(s)
	match kind:
		Kind.POP, Kind.FADE, Kind.SLAM:
			item.modulate.a = 0.0
		Kind.KEY:
			item.modulate.a = 0.0
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


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
	elif s.kind == Kind.COUNT and not _reduced:
		var label := item as Label
		# Hold the final text's width, so a shorter number on the way never moves what is round it.
		s.width = label.custom_minimum_size.x
		label.custom_minimum_size.x = maxf(s.width, label.get_minimum_size().x)
		label.text = s.format.call(0.0)
	shown.emit(item)


func _frame(k: float, i: int) -> void:
	var s: Dictionary = _steps[i]
	if s.done or not is_instance_valid(s.item):
		return
	var item: Control = s.item
	match s.kind:
		Kind.FADE:
			item.modulate.a = s.alpha * clampf(k, 0.0, 1.0)
		Kind.SLAM:
			if _reduced:
				item.modulate.a = s.alpha * clampf(k, 0.0, 1.0)
				return
			item.modulate.a = s.alpha * clampf(k / SLAM_FADE_SHARE, 0.0, 1.0)
			item.pivot_offset = item.size * 0.5
			item.scale = Vector2.ONE * lerpf(SLAM_FROM, 1.0, k)
		Kind.PULSE:
			item.pivot_offset = item.size * 0.5
			item.scale = Vector2.ONE * (1.0 + (PULSE_TO - 1.0) * sin(PI * clampf(k, 0.0, 1.0)))
		Kind.POP, Kind.KEY:
			if _reduced:
				item.modulate.a = s.alpha * clampf(k, 0.0, 1.0)
				return
			item.modulate.a = s.alpha * clampf(k / POP_FADE_SHARE, 0.0, 1.0)
			# The centre stays put; set every frame, as a container's sort puts scale back to 1 and the size can change.
			item.pivot_offset = item.size * 0.5
			item.scale = Vector2.ONE * (POP_FROM + (1.0 - POP_FROM) * k)
		Kind.COUNT:
			if not _reduced:
				(item as Label).text = s.format.call(s.to * clampf(k, 0.0, 1.0))


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
		Kind.POP, Kind.FADE, Kind.KEY, Kind.SLAM:
			item.modulate.a = s.alpha
			item.scale = Vector2.ONE
			item.pivot_offset = s.pivot
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
