## 〰️ **Progress indicator** — how far a download, an upload or a sign-up has come, as a line or a ring. With `wavy` on it
## is Material 3 Expressive's wavy indicator: the done part ripples while it runs.
##
## ```gdscript
## var upload := GoProgress.linear()          # a line across its row
## upload.value = 0.35                         # 0.0 … 1.0
## var busy := GoProgress.circular(true)       # a ring that turns until the work's size is known
## busy.wavy = false                           # the flat one
## ```
##
## ## 🔑 Known or not
## Set `indeterminate` while you cannot tell how much is left; the indicator then moves on its own. Switch it off and
## set `value` once you can. A known value is always the better answer — "37%" says when it ends, a spinner does not.
## For a game's health or experience use `GoBar`; for a short wait with no progress at all, `GoLoadingIndicator`.
##
## ## 🔑 The look
## The track and the done part take the theme's `ProgressBar` colours — the same as `GoStyle.progress()` — and keep
## Material's measures on every theme: a 4dp line (8dp `thick`), a 4dp gap between the done part and the track, a 4dp stop
## dot at the end, a 3dp × 40dp wave (`_md-comp-progress-indicator-linear.scss`, `…-circular.scss`).
## With `GoUi.config.reduce_motion` on, the wave stands still and an indeterminate indicator only breathes.
@tool
class_name GoProgress
extends Control

## A line or a ring.
enum Kind {
	LINEAR,    ## A line across the width it is given.
	CIRCULAR,  ## A ring, 48dp (wavy) or 40dp.
}

@export var kind := Kind.LINEAR:
	set(value):
		kind = value
		_resize()

## How far along, 0.0 … 1.0.
@export_range(0.0, 1.0, 0.001) var value := 0.0:
	set(next):
		value = clampf(next, 0.0, 1.0)
		_name_it()
		queue_redraw()

## The work's size is not known yet — the indicator moves on its own.
@export var indeterminate := false:
	set(next):
		indeterminate = next
		_name_it()
		_sync_process()
		queue_redraw()

## The Expressive wave on the done part.
@export var wavy := true:
	set(next):
		wavy = next
		_resize()

## The 8dp line instead of the 4dp one.
@export var thick := false:
	set(next):
		thick = next
		_resize()

## Measures (dp) — `_md-comp-progress-indicator-linear.scss` and `…-circular.scss`.
const GAP := 4.0
const STOP := 4.0
const WAVE_AMPLITUDE := 3.0
const WAVE_LENGTH := 40.0
const RING_WAVE_AMPLITUDE := 1.6
const RING_WAVE_LENGTH := 15.0
## The least a track stands apart from the page — the step `tools/check_contrast.py` asks of one surface over another.
const LAYER := 1.12

var _time := 0.0


func _init() -> void:
	name = "Progress"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _ready() -> void:
	_name_it()
	visibility_changed.connect(_sync_process)
	_sync_process()
	GoUi.watch(queue_redraw)


func _exit_tree() -> void:
	GoUi.unwatch(queue_redraw)


## A line that fills its row.
static func linear(as_indeterminate := false) -> GoProgress:
	var node := GoProgress.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.indeterminate = as_indeterminate
	return node


## A ring.
static func circular(as_indeterminate := false) -> GoProgress:
	var node := GoProgress.new()
	node.kind = Kind.CIRCULAR
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.indeterminate = as_indeterminate
	return node


func _stroke() -> float:
	return 8.0 if thick else 4.0


func _resize() -> void:
	if kind == Kind.CIRCULAR:
		var side := 48.0 if wavy else 40.0
		if thick: side += 4.0
		custom_minimum_size = Vector2(side, side)
	else:
		custom_minimum_size = Vector2(0.0, _stroke() + (WAVE_AMPLITUDE * 2.0 if wavy else 0.0))
	queue_redraw()


func _sync_process() -> void:
	# A wavy line ripples while it is shown, an indeterminate one moves; a flat determinate one needs no frames.
	set_process(is_inside_tree() and is_visible_in_tree() and not Engine.is_editor_hint() and (indeterminate or wavy))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## ♿ The value a screen reader says — a percentage, or "Loading…" while the size is unknown.
func _name_it() -> void:
	if indeterminate:
		accessibility_name = GoUi.text(&"loading")
	else:
		accessibility_name = GoUi.text(&"bar_percent").format({"percent": roundi(value * 100.0)})


## The done part and the track colours — the theme's `ProgressBar` faces, else the accent and track tokens.
func _colors() -> Array[Color]:
	var ink := GoUi.color(GoTheme.ACCENT)
	var track := GoUi.color(GoTheme.TRACK)
	var look := GoUi.theme()
	for pair in [[&"fill", 0], [&"background", 1]]:
		if look == null or not look.has_stylebox(pair[0], &"ProgressBar"): continue
		var face := look.get_stylebox(pair[0], &"ProgressBar")
		if not &"bg_color" in face: continue
		var found: Color = face.get(&"bg_color")
		if found.a <= 0.0: continue
		if pair[1] == 0: ink = found
		else: track = found
	# 🛑 A theme whose bar draws its track as a frame (medieval) gives a ground the colour of the page — the track
	#    vanished. Lift it toward the done colour until it shows (the 1.12:1 layer step `check_contrast.py` asks of surfaces).
	var page := GoUi.color(GoTheme.BACKGROUND)
	var shown := GoSkin.blend(track, page)
	var step := 0.0
	while GoSkin.contrast_ratio(shown, page) < LAYER and step < 0.6:
		step += 0.05
		shown = GoSkin.blend(track, page).lerp(ink, step)
	if step > 0.0: track = shown
	return [ink, track]


func _draw() -> void:
	var colors := _colors()
	if kind == Kind.CIRCULAR: _draw_ring(colors[0], colors[1])
	else: _draw_line(colors[0], colors[1])


func _draw_line(ink: Color, track: Color) -> void:
	var stroke := _stroke()
	var half := stroke * 0.5
	var mid := size.y * 0.5
	var width := size.x
	if width <= stroke: return
	var still := GoUi.config.reduce_motion
	if indeterminate:
		if still:
			# Breathing, not moving.
			var breath := 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * TAU / 1.6))
			_segment(half, width - half, mid, Color(ink, ink.a * breath), stroke, 0.0)
			return
		# One done stretch sweeping across, the track on either side of it with a gap.
		var cycle := fmod(_time / 1.8, 1.0)
		var span := width * 0.4
		var start := -span + (width + span) * _ease_in_out(cycle)
		var end := start + span
		var a := clampf(start, half, width - half)
		var b := clampf(end, half, width - half)
		if a - GAP - stroke > half: _segment(half, a - GAP - stroke, mid, track, stroke, 0.0)
		if b + GAP + stroke < width - half: _segment(b + GAP + stroke, width - half, mid, track, stroke, 0.0)
		if b - a > 0.5: _segment(a, b, mid, ink, stroke, WAVE_AMPLITUDE if wavy else 0.0)
		return
	var done := half + (width - stroke) * value
	# The wave flattens toward 0% and 100% (Material's amplitude ramp), so the ends never jump.
	var amplitude := (WAVE_AMPLITUDE if wavy else 0.0) * clampf(minf(value, 1.0 - value) * 10.0, 0.0, 1.0)
	if value > 0.0: _segment(half, done, mid, ink, stroke, amplitude)
	if value < 1.0:
		var rest := done + GAP + stroke
		if rest < width - half: _segment(rest, width - half, mid, track, stroke, 0.0)
		# The stop dot at the end says where 100% is.
		draw_circle(Vector2(width - half, mid), STOP * 0.5, ink, true, -1.0, true)


## One rounded stretch of the line from [param from] to [param to] — rippled when [param amplitude] is above zero.
func _segment(from: float, to: float, mid: float, ink: Color, stroke: float, amplitude: float) -> void:
	if to - from < 0.1:
		draw_circle(Vector2(from, mid), stroke * 0.5, ink, true, -1.0, true)
		return
	if amplitude <= 0.0:
		draw_line(Vector2(from, mid), Vector2(to, mid), ink, stroke, true)
		draw_circle(Vector2(from, mid), stroke * 0.5, ink, true, -1.0, true)
		draw_circle(Vector2(to, mid), stroke * 0.5, ink, true, -1.0, true)
		return
	var phase := 0.0 if GoUi.config.reduce_motion else _time * TAU * 0.8
	var points := PackedVector2Array()
	var steps := maxi(2, ceili((to - from) / 2.0))
	for i in steps + 1:
		var x := lerpf(from, to, float(i) / steps)
		points.append(Vector2(x, mid + sin(x / WAVE_LENGTH * TAU - phase) * amplitude))
	draw_polyline(points, ink, stroke, true)
	draw_circle(points[0], stroke * 0.5, ink, true, -1.0, true)
	draw_circle(points[points.size() - 1], stroke * 0.5, ink, true, -1.0, true)


func _draw_ring(ink: Color, track: Color) -> void:
	var stroke := _stroke()
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - stroke * 0.5 - (RING_WAVE_AMPLITUDE if wavy else 0.0)
	if radius <= 1.0: return
	# The gap between the done arc and the track, as an angle at this radius (the round caps take room too).
	var gap := (GAP + stroke) / radius
	var still := GoUi.config.reduce_motion
	var start := -PI * 0.5
	var sweep := TAU * value
	if indeterminate:
		if still:
			var breath := 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * TAU / 1.6))
			_arc(center, radius, 0.0, TAU, Color(ink, ink.a * breath), stroke, 0.0)
			return
		# A turning arc that grows and shrinks as it goes.
		var cycle := fmod(_time / 1.4, 1.0)
		sweep = TAU * (0.1 + 0.6 * (0.5 - 0.5 * cos(cycle * TAU)))
		start = _time * TAU / 1.6
	var amplitude := RING_WAVE_AMPLITUDE if wavy else 0.0
	if not indeterminate: amplitude *= clampf(minf(value, 1.0 - value) * 10.0, 0.0, 1.0)
	if TAU - sweep > gap * 2.0:
		_arc(center, radius, start + sweep + gap, start + TAU - gap, track, stroke, 0.0)
	if sweep > 0.0: _arc(center, radius, start, start + sweep, ink, stroke, amplitude)


## An arc from [param from] to [param to] (radians, clockwise from the right), rippled when [param amplitude] is above zero.
func _arc(center: Vector2, radius: float, from: float, to: float, ink: Color, stroke: float, amplitude: float) -> void:
	var length := (to - from) * radius
	var steps := maxi(4, ceili(length / 2.0))
	var phase := 0.0 if GoUi.config.reduce_motion else _time * TAU * 0.8
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := lerpf(from, to, float(i) / steps)
		var wobble := sin(angle * radius / RING_WAVE_LENGTH * TAU - phase) * amplitude if amplitude > 0.0 else 0.0
		points.append(center + Vector2.from_angle(angle) * (radius + wobble))
	draw_polyline(points, ink, stroke, true)
	if to - from < TAU - 0.001:
		draw_circle(points[0], stroke * 0.5, ink, true, -1.0, true)
		draw_circle(points[points.size() - 1], stroke * 0.5, ink, true, -1.0, true)


static func _ease_in_out(x: float) -> float:
	return 0.5 - 0.5 * cos(x * PI)
