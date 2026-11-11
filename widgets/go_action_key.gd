## ⌨️ **Action key** — one key cap with the action's word beside it ("Space JUMP"), for a desktop HUD's secondary
## actions. The cap goes down while the key is held, and shows a wait: used, it dims and a sweep uncovers it as the
## wait runs out, then it pops.
##
## ```gdscript
## var jump := GoActionKey.make("JUMP", "Space")     # or jump.set_action(&"jump") — reads InputMap
## var sprint := GoActionKey.make("SPRINT", "Shift")
## row.add_child(jump); row.add_child(sprint)
##
## sprint.set_held(true)                 # the cap stays down and lit while the key is held
## jump.set_cooldown(1.6, 2.0)           # used: the cap presses, dims, and the sweep uncovers it
## jump.set_cooldown(0.0, 2.0)           # ready: it pops
## ```
##
## 🛑 Key names are shown as given, never translated; the word goes through `tr()`.
## 🛑 Under `GoConfig.reduce_motion` only the state changes: the cap is down or up, dim or not — no sweep motion, no pop.
## 🛑 Display only: it shows what it is given and decides nothing.
@tool
class_name GoActionKey
extends Control

## The action's word beside the cap. Empty: the cap alone.
@export var word := "":
	set(value):
		if word == value: return
		word = value
		_fit()

## The cap's height (dp); the key's name and the word scale with it.
@export_range(14.0, 96.0, 1.0) var cap_height := 26.0:
	set(value):
		cap_height = value
		_fit()

## The widest the word may run (dp) before it shrinks (`GoStyle.fit_font_size`). 0: as wide as it needs.
@export_range(0.0, 400.0, 1.0) var word_room := 0.0:
	set(value):
		word_room = value
		_fit()

const PRESS_SECONDS := 0.16
const READY_SECONDS := 0.34
const ENTER_SECONDS := 0.3
const PRESS_DROP := 0.12
const READY_POP := 0.22

## The motion clock (`GoMotion`): `press`, `ready`, `enter`.
var motion := GoMotion.new()

var _key := ""
var _held := false
var _cool_left := 0.0
var _cool_total := 1.0
var _cool_shown := 0.0
var _key_size := 0
var _word_size := 0
var _cap_width := 0.0
var _word_width := 0.0
var _box: StyleBox


func _init() -> void:
	name = "ActionKey"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_process(false)


## A cap for [param key_name] with [param action_word] beside it.
static func make(action_word: String, key_name := "") -> GoActionKey:
	var node := GoActionKey.new()
	node.word = action_word
	node.set_key(key_name)
	return node


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	_on_ui_changed()
	_wake()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	_box = null
	if GoUi.config.reduce_motion:
		motion.stop_all()
		_cool_shown = _cool_left
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _fit()


func _process(delta: float) -> void:
	advance(delta)


## The key's name on the cap ("Space"). Empty hides the whole part (an action with no key has no hint).
func set_key(text: String) -> void:
	if _key == text: return
	_key = text
	visible = not text.is_empty()
	_fit()


## Reads the key **actually bound** to [param action] in `InputMap` (`GoKbd.action_keys`).
func set_action(action: StringName) -> void:
	set_key(" + ".join(PackedStringArray(GoKbd.action_keys(action))))


func key_text() -> String:
	return _key


## Whether the key is held: the cap stays down and lit.
func set_held(on: bool) -> void:
	if on == _held: return
	_held = on
	if on: motion.play(&"press", PRESS_SECONDS)
	else: motion.stop(&"press")
	_wake()


func held() -> bool:
	return _held


## The action's wait: [param left] seconds of [param total]. From 0 to more is "used" — the cap presses and dims; the
## sweep uncovers it as the wait runs out; back to 0 it pops.
func set_cooldown(left: float, total: float) -> void:
	var now := maxf(0.0, left)
	# Exact, not approximate: the last sliver of a wait and 0 are different states.
	if now == _cool_left and is_equal_approx(total, _cool_total): return
	var was := _cool_left > 0.0
	_cool_left = now
	_cool_total = maxf(total, 0.001)
	if now > 0.0 and not was:
		_cool_shown = now
		motion.stop(&"ready")
		motion.play(&"press", PRESS_SECONDS)
	elif was and now <= 0.0:
		_cool_shown = 0.0
		motion.play(&"ready", READY_SECONDS)
	elif GoUi.config.reduce_motion or not is_inside_tree() or absf(_cool_shown - now) > 0.25:
		_cool_shown = now
	_wake()


func cooling() -> bool:
	return _cool_left > 0.0


## The share of the cap still covered by the wait, 0~1.
func cover() -> float:
	return clampf(_cool_shown / _cool_total, 0.0, 1.0)


## The HUD came on: the key pops in after [param delay] seconds.
func enter(delay := 0.0) -> void:
	motion.play(&"enter", ENTER_SECONDS, delay)
	_wake()


## How far the cap is pushed down now, 0~1: down while held, a dip when used.
func press_amount() -> float:
	if _held: return GoMotion.ease_out(motion.at(&"press", 1.0))
	return GoMotion.punch(motion.at(&"press"))


## The cap's scale now: the ready pop and the entrance.
func cap_scale() -> float:
	var enter_t := motion.at(&"enter", 1.0)
	if enter_t <= 0.0: return 0.0
	return GoMotion.overshoot(enter_t) * (1.0 + READY_POP * GoMotion.punch(motion.at(&"ready")))


func moving() -> bool:
	return motion.busy() or (_cool_left > 0.0 and not GoUi.config.reduce_motion)


## ⏱ Moves every motion on by [param delta] seconds. `_process` calls it; a test calls it by hand.
func advance(delta: float) -> void:
	motion.advance(delta)
	if _cool_left > 0.0 and not GoUi.config.reduce_motion:
		_cool_shown = maxf(maxf(0.0, _cool_left - 0.1), _cool_shown - delta)
	if not moving(): set_process(false)
	queue_redraw()


func _wake() -> void:
	queue_redraw()
	if is_inside_tree() and moving(): set_process(true)


func _unit() -> float:
	return cap_height / 26.0


func _font() -> Font:
	return get_theme_font(&"font", &"Label")


## The key's and the word's sizes and the room the part asks for. Measured, so it runs again when either text, the
## look or the language changes.
func _fit() -> void:
	var font := _font()
	var u := _unit()
	if font == null: return
	_key_size = roundi(13.0 * u)
	_cap_width = maxf(cap_height, font.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1, _key_size).x + 14.0 * u)
	var said := tr(word) if not word.is_empty() else ""
	var base := roundi(13.0 * u)
	_word_size = GoStyle.fit_font_size(PackedStringArray([said]), base, word_room, font) if word_room > 0.0 else base
	_word_width = font.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, _word_size).x if not said.is_empty() else 0.0
	var gap := 6.0 * u if _word_width > 0.0 else 0.0
	custom_minimum_size = Vector2(ceilf(_cap_width + gap + _word_width + 4.0 * u), ceilf(cap_height + 4.0 * u))
	queue_redraw()


func _draw() -> void:
	if _key.is_empty(): return
	var grow := cap_scale()
	if grow <= 0.0: return
	var skin := GoUi.skin()
	var font := _font()
	var u := _unit()
	var line := skin.touch_outline_ink()
	var down := press_amount()
	var mid := Vector2(_cap_width * 0.5, size.y * 0.5 + cap_height * PRESS_DROP * down)
	draw_set_transform(mid, 0.0, Vector2(grow, grow) * (1.0 - 0.05 * down))
	var rect := Rect2(-_cap_width * 0.5, -cap_height * 0.5, _cap_width, cap_height)
	if _box == null: _box = skin.kbd_box()
	draw_style_box(_box, rect)
	draw_string(font, Vector2(rect.position.x, _key_size * 0.34 - 1.0 * u), _key, HORIZONTAL_ALIGNMENT_CENTER, _cap_width,
		_key_size, skin.kbd_ink())
	var face := rect.grow(-2.0 * u)
	if _held: draw_rect(face, Color(GoUi.color(GoTheme.WARNING_FILL), 0.42 * down))
	var covered := cover()
	if covered > 0.0:
		# The wait covers the cap from the right; the sweep's edge moves right as it runs out.
		var wide := face.size.x * covered
		draw_rect(Rect2(face.end.x - wide, face.position.y, wide, face.size.y), Color(line, 0.55))
	var flash := GoMotion.punch(motion.at(&"ready"))
	if flash > 0.0: draw_rect(face, Color(1.0, 1.0, 1.0, 0.6 * flash))
	draw_set_transform(Vector2.ZERO)
	if _word_width <= 0.0: return
	var said := tr(word)
	var at := Vector2(_cap_width + 6.0 * u, size.y * 0.5 + _word_size * 0.36)
	var ink := GoUi.color(GoTheme.WARNING_FILL).lerp(Color.WHITE, 0.35) if _held else Color.WHITE
	if covered > 0.0: ink = ink.lerp(line, 0.3)
	draw_string_outline(font, at, said, HORIZONTAL_ALIGNMENT_LEFT, -1, _word_size, roundi(5.0 * u), line)
	draw_string(font, at, said, HORIZONTAL_ALIGNMENT_LEFT, -1, _word_size, ink)
