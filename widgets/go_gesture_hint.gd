## 👆 **A gesture hint** — see-through ghost fingertips that play a touch gesture in a loop, for a tutorial that teaches
## one ("pinch to zoom"). Two fingertips appear near the middle, spread apart diagonally (zoom in), pause, pinch back
## together (zoom out), pause and fade — then again. Short trails follow a moving fingertip and small arrows show which
## way it goes.
##
## ```gdscript
## var hint := GoGestureHint.new()
## hud.add_child(hint)
## hint.position = Vector2(size.x * 0.5, 0.0)   # the area to demonstrate in — the right half of the screen, say
## hint.size = Vector2(size.x * 0.5, size.y)
## hint.play()                                  # (re)starts the loop from its beginning
## hint.stop()                                  # the player pinched: hide it
## ```
##
## The gesture centres itself in the node's rect and scales its travel and its fingertips to the rect's short side, so it
## reads the same on a phone and an iPad. 🛑 It never takes input (`MOUSE_FILTER_IGNORE`): the player pinches *through*
## it. Display only — the game decides when the lesson is done and calls `stop()`.
##
## Under `GoConfig.reduce_motion` it holds one still frame: both fingertips apart, with arrows out and in.
## The shapes are the skin's: `GoSkin.draw_gesture_touch()` (a fingertip) and `GoSkin.draw_gesture_arrow()`.
@tool
class_name GoGestureHint
extends Control

## The gestures it can play. Only `PINCH` so far — the room is kept for more (a tap, a swipe).
enum Gesture { PINCH }

## Where each part of the PINCH loop ends, as a fraction of `loop_seconds`: the fingertips fade in close together,
## spread apart, hold apart, pinch back together, hold together, then fade out until the loop ends.
const FADE_IN_END := 0.10
const SPREAD_END := 0.40
const OPEN_END := 0.52
const PINCH_END := 0.82
const CLOSED_END := 0.90

## How far apart the fingertips stand in the still frame under `reduce_motion` (0 together, 1 fully apart).
const STILL_SPREAD := 0.75

## The diagonal the fingertips travel along — the first one up and right, the second down and left (thumb and index).
const AXIS := Vector2(0.70710678, -0.70710678)

## The trail: how many fading copies follow a moving fingertip, and how far apart in time they are (s).
const TRAIL_STEPS := 3
const TRAIL_GAP := 0.07

## The gesture to play.
@export var gesture: Gesture = Gesture.PINCH:
	set(value):
		gesture = value
		queue_redraw()

## How long one full loop takes (s).
@export_range(1.0, 8.0, 0.1) var loop_seconds := 2.6

## How far each fingertip travels from the middle when apart, as a fraction of the rect's short side.
@export_range(0.1, 0.5, 0.01) var reach := 0.34:
	set(value):
		reach = value
		queue_redraw()

## How far each fingertip stands from the middle when together, as a fraction of the rect's short side.
@export_range(0.0, 0.3, 0.01) var near := 0.08:
	set(value):
		near = value
		queue_redraw()

## Colour of the fingertips' rim and the arrows. Transparent uses the theme's `accent`.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## Runs the loop in `_process`. Turn it off to drive it with `advance(delta)`.
@export var auto_advance := true:
	set(value):
		auto_advance = value
		set_process(value)

## True between `play()` and `stop()`. Read it; start and stop with those two.
var playing := false

## How many times the ghost has been painted — a stopped hint paints nothing and adds none.
var paint_count := 0

var _time := 0.0


func _init() -> void:
	name = "GestureHint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GoUi.theme()
	set_process(auto_advance)


func _enter_tree() -> void:
	GoUi.watch(_restyle)
	if is_node_ready(): _restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## Starts the loop — or restarts it — from its beginning and shows the ghost.
func play() -> void:
	playing = true
	_time = 0.0
	queue_redraw()


## Stops the loop and hides the ghost: nothing is drawn until the next `play()`.
func stop() -> void:
	playing = false
	_time = 0.0
	queue_redraw()


## Moves the loop on [param delta] seconds (it wraps round). Does nothing while stopped, and holds the still frame
## under `reduce_motion`.
func advance(delta: float) -> void:
	if not playing or _still(): return
	var length := maxf(loop_seconds, 0.01)
	_time = fposmod(_time + delta, length)
	queue_redraw()


## Where the loop is now, 0 → 1.
func progress() -> float:
	return clampf(_time / maxf(loop_seconds, 0.01), 0.0, 1.0)


## How far apart the fingertips are now: 0 together, 1 fully apart.
func spread() -> float:
	if _still(): return STILL_SPREAD
	return _spread_at(progress())


## How strongly the ghost shows now, 0 → 1: it fades in and out at the ends of the loop (always 1 in the still frame).
func ghost_alpha() -> float:
	if _still(): return 1.0
	var u := progress()
	if u < FADE_IN_END: return _ease(u / FADE_IN_END)
	if u >= CLOSED_END: return 1.0 - _ease((u - CLOSED_END) / (1.0 - CLOSED_END))
	return 1.0


## The fingertips' centres now, in this control's coordinates. Empty while stopped.
func finger_positions() -> PackedVector2Array:
	if not playing: return PackedVector2Array()
	return _fingers_at(spread())


## A fingertip's radius (dp) — a share of the rect's short side, kept between 14 and 30.
func finger_radius() -> float:
	return clampf(_short_side() * 0.075, 14.0, 30.0)


## The rim and arrow colour now: `ink`, or the theme's accent.
func ink_color() -> Color:
	return ink if ink.a > 0.0 else GoUi.color(GoTheme.ACCENT)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint(): advance(delta)


func _still() -> bool:
	return GoUi.config.reduce_motion


func _short_side() -> float:
	return maxf(minf(size.x, size.y), 0.0)


func _closed_offset() -> float:
	return _short_side() * near


func _open_offset() -> float:
	# The arrows reach past a fingertip — keep both inside the rect.
	var room := _short_side() * 0.5 - finger_radius() * 2.3
	return maxf(_closed_offset(), minf(_short_side() * reach, room))


func _fingers_at(amount: float) -> PackedVector2Array:
	var offset := lerpf(_closed_offset(), _open_offset(), amount)
	var middle := size * 0.5
	return PackedVector2Array([middle + AXIS * offset, middle - AXIS * offset])


func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _spread_at(u: float) -> float:
	if u < FADE_IN_END: return 0.0
	if u < SPREAD_END: return _ease((u - FADE_IN_END) / (SPREAD_END - FADE_IN_END))
	if u < OPEN_END: return 1.0
	if u < PINCH_END: return 1.0 - _ease((u - OPEN_END) / (PINCH_END - OPEN_END))
	return 0.0


## Which way the fingertips move at [param u] and how fast: + apart, − together, 0 still.
func _motion_at(u: float) -> float:
	if u >= FADE_IN_END and u < SPREAD_END:
		return sin(PI * (u - FADE_IN_END) / (SPREAD_END - FADE_IN_END))
	if u >= OPEN_END and u < PINCH_END:
		return -sin(PI * (u - OPEN_END) / (PINCH_END - OPEN_END))
	return 0.0


func _restyle() -> void:
	theme = GoUi.theme()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()


func _draw() -> void:
	if not playing or gesture != Gesture.PINCH: return
	var alpha := ghost_alpha()
	if alpha <= 0.0 or _short_side() <= 0.0: return
	paint_count += 1
	var skin := GoUi.skin()
	var radius := finger_radius()
	var colour := ink_color()
	var arrow := radius * 0.7
	var fingers := finger_positions()
	var outward := [AXIS, -AXIS]
	if _still():
		for i in fingers.size():
			var out: Vector2 = outward[i]
			skin.draw_gesture_touch(self, fingers[i], radius, colour, 1.0)
			skin.draw_gesture_arrow(self, fingers[i] + out * radius * 1.8, out, arrow, colour, 1.0)
			skin.draw_gesture_arrow(self, fingers[i] - out * radius * 1.8, -out, arrow, colour, 1.0)
		return
	var u := progress()
	var motion := _motion_at(u)
	if absf(motion) > 0.05:
		# The trail: fading, shrinking copies where the fingertips were a moment ago, oldest first.
		var gap := TRAIL_GAP / maxf(loop_seconds, 0.01)
		for k in range(TRAIL_STEPS, 0, -1):
			var before := _fingers_at(_spread_at(maxf(u - gap * k, 0.0)))
			var fade := alpha * 0.3 * float(TRAIL_STEPS + 1 - k) / float(TRAIL_STEPS + 1)
			for p in before: skin.draw_gesture_touch(self, p, radius * (1.0 - 0.12 * k), colour, fade)
	for p in fingers: skin.draw_gesture_touch(self, p, radius, colour, alpha)
	if absf(motion) > 0.05:
		var way := signf(motion)
		for i in fingers.size():
			var out: Vector2 = outward[i]
			skin.draw_gesture_arrow(self, fingers[i] + out * way * radius * 1.8, out * way, arrow, colour,
				alpha * absf(motion))
