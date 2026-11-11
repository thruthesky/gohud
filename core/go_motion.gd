## 🎞 **Named motion tracks** — the clock behind a drawn widget's animations (`GoMagnetDial`, `GoItemBox`,
## `GoActionKey`). Each track is a name with a length; the widget asks how far it has run and draws that.
##
## ```gdscript
## var motion := GoMotion.new()
## motion.play(&"fire", 0.35)             # one shot; under `GoConfig.reduce_motion` it does not start
## motion.loop(&"flow", 0.6)              # runs round and round until `stop()`
## func _process(delta: float) -> void:
##     if not motion.advance(delta): set_process(false)   # nothing left to move: stop redrawing
##     queue_redraw()
## var kick := GoMotion.punch(motion.at(&"fire"))         # 0 → 1 → 0 over the track; 0 while it is not playing
## ```
##
## 🛑 Under `GoConfig.reduce_motion` nothing plays: `play()` and `loop()` answer false and the widget shows the new
##    state at once, without movement or flashing.
## 🔑 `advance()` is the only clock, so a test steps a widget by hand (`widget.advance(0.1)`) and reads the same
##    values a frame would draw.
class_name GoMotion
extends RefCounted

## name → [elapsed, length, loops, delay left]
var _tracks: Dictionary = {}


## Starts (or restarts) the one-shot [param track], [param seconds] long, after [param delay] seconds.
## false: motion is reduced (or the length is 0) and nothing plays.
func play(track: StringName, seconds: float, delay := 0.0) -> bool:
	if GoUi.config.reduce_motion or seconds <= 0.0:
		_tracks.erase(track)
		return false
	_tracks[track] = [0.0, seconds, false, maxf(0.0, delay)]
	return true


## Starts the looping [param track] with a period of [param seconds]; one already looping keeps its phase.
func loop(track: StringName, seconds: float) -> bool:
	if GoUi.config.reduce_motion or seconds <= 0.0:
		_tracks.erase(track)
		return false
	if _tracks.has(track) and _tracks[track][2]:
		_tracks[track][1] = seconds
		return true
	_tracks[track] = [0.0, seconds, true, 0.0]
	return true


func stop(track: StringName) -> void:
	_tracks.erase(track)


func stop_all() -> void:
	_tracks.clear()


## Whether [param track] is running (a delayed one counts: it is waiting to move).
func playing(track: StringName) -> bool:
	return _tracks.has(track)


## Whether anything is running — the widget keeps processing while this is true.
func busy() -> bool:
	return not _tracks.is_empty()


## How far [param track] has run, 0~1 (a loop's phase). 0 while it waits out its delay; [param idle] when it is not
## playing — pass 1.0 for a track whose end state is its rest (an entrance), leave 0.0 for a pulse that returns.
func at(track: StringName, idle := 0.0) -> float:
	if not _tracks.has(track): return idle
	var row: Array = _tracks[track]
	return clampf(row[0] / row[1], 0.0, 1.0)


## Moves every track on by [param delta] seconds and drops the one-shots that ended. true: something still runs.
func advance(delta: float) -> bool:
	if _tracks.is_empty(): return false
	for track: StringName in _tracks.keys():
		var row: Array = _tracks[track]
		var step := delta
		if row[3] > 0.0:
			var wait: float = minf(row[3], step)
			row[3] -= wait
			step -= wait
			if step <= 0.0: continue
		row[0] += step
		if row[0] >= row[1]:
			if row[2]: row[0] = fmod(row[0], row[1])
			else: _tracks.erase(track)
	return not _tracks.is_empty()


## 0 → 1 → 0 over [param t] (a half sine): a scale kick, a flash.
static func punch(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI)


## 0 → 1 with one overshoot (back-out): a pop-in.
static func overshoot(t: float, back := 1.70158) -> float:
	var u := clampf(t, 0.0, 1.0) - 1.0
	return u * u * ((back + 1.0) * u + back) + 1.0


## 0 → 1, fast then settling (cubic-out).
static func ease_out(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


## A side-to-side shake that dies away over [param t]: -1~1, [param turns] swings.
static func shake(t: float, turns := 3.0) -> float:
	var u := clampf(t, 0.0, 1.0)
	return sin(u * TAU * turns) * (1.0 - u)
