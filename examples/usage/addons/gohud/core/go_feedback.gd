## 🔔 Where **sound and haptics are bound into a pair**. A widget names only the occasion; what gets played is known here.
##
## ## Why one place
## Scatter the spots that call sound and haptics and **operations of the same character start responding differently
## from screen to screen.** A confirmation has to be the same sound and the same buzz everywhere.
##
## ## 🛑 gohud ships no audio
## Put sound effects in the addon and they run apart from the project's audio buses, volume settings and cooldowns,
## and a license tags along with them. So **the project is what makes the sound** — one line below is all it takes.
##
## ```gdscript
## # once, somewhere in the game's boot
## GoFeedback.sound_handler = func(cue: String) -> void: Audio.play(cue)
## ```
##
## The `cue` handed over is the name `GoConfig.sound_cues` decided (`ui_open`·`ui_click`… by default).
## If the project's audio names differ, swap them in the config — no code has to change.
##
## ## Haptics
## Godot has no names like `selectionClick`, only **a duration and a strength**. Three steps are used.
##
## | Step | Where it is used | Default |
## |---|---|---|
## | tap | tap·toggle·cancel·close | 10ms · 0.35 |
## | light | confirm·open | 20ms · 0.5 |
## | medium | error·not allowed | 40ms · 0.8 |
##
## 🛑 **It only buzzes on a handheld device.** A desktop has no vibration hardware. `amplitude` is honored by Android
##    alone and ignored by iOS (engine behavior) — what makes the real difference is the duration.
class_name GoFeedback
extends RefCounted

## The project's sound player. A single `func(cue: String) -> void` is enough.
## Left empty, no sound plays and only the haptics work.
static var sound_handler := Callable()

## For swapping the vibrator out yourself (tests·platform plugins). `func(ms: int, amplitude: float) -> void`.
## Left empty, `Input.vibrate_handheld` is used.
static var haptic_handler := Callable()

const OPENED := &"opened"
const CLOSED := &"closed"
const TAPPED := &"tapped"
const CONFIRMED := &"confirmed"
const CANCELED := &"canceled"
const FAILED := &"failed"
const FANFARE := &"fanfare"


## A screen·menu·sheet·dialog **comes up**.
static func opened() -> void:
	_emit(OPENED, GoUi.config.haptic_light_ms, GoUi.config.haptic_light_amplitude)


## **It closes** — the close button, a tap outside and the back gesture are all the same sound.
static func closed() -> void:
	_emit(CLOSED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


## An ordinary tap — most buttons, icons and list items.
static func tapped() -> void:
	_emit(TAPPED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


## Confirm·affirmative action (log in·start·purchase·submit).
static func confirmed() -> void:
	_emit(CONFIRMED, GoUi.config.haptic_light_ms, GoUi.config.haptic_light_amplitude)


## Cancel·undo.
static func canceled() -> void:
	_emit(CANCELED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


## Not allowed·error (bad input·conditions unmet). 🛑 A warning is a "you are blocked" signal too, so it uses the same pair.
static func failed() -> void:
	_emit(FAILED, GoUi.config.haptic_medium_ms, GoUi.config.haptic_medium_amplitude)


## A big achievement (a rare event). The haptic is the same strength as a confirmation — stronger and it startles.
## A toggle·checkbox was switched on or off — the same sound and strength as a tap.
static func toggled() -> void:
	_emit(TAPPED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


static func fanfare() -> void:
	_emit(FANFARE, GoUi.config.haptic_light_ms, GoUi.config.haptic_light_amplitude)


## Call one of the seven above by name.
static func play(signal_name: StringName) -> void:
	match signal_name:
		OPENED: opened()
		CLOSED: closed()
		TAPPED: tapped()
		CONFIRMED: confirmed()
		CANCELED: canceled()
		FAILED: failed()
		FANFARE: fanfare()


static func _emit(signal_name: StringName, duration_ms: int, amplitude: float) -> void:
	var cue: String = GoUi.config.sound_cues.get(signal_name, "")
	if not cue.is_empty() and sound_handler.is_valid(): sound_handler.call(cue)
	_vibrate(duration_ms, amplitude)


static func _vibrate(duration_ms: int, amplitude: float) -> void:
	if not GoUi.config.haptics_enabled or duration_ms <= 0: return
	if haptic_handler.is_valid():
		haptic_handler.call(duration_ms, amplitude)
		return
	# 🛑 Judged by platform — the question is not "is the window narrow" but "is there vibration hardware".
	if not GoUi.is_handheld_platform(): return
	Input.vibrate_handheld(duration_ms, amplitude)
