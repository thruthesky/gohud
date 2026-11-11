## 🧲 **Magnet dial** — a round gauge with two actions on it: a ring that shows how much power is left, a left half for
## the held action (ATTRACT) and a right half for the fired one (REPULSE) that greys out and refills while it cools
## down. Each half names its key at its foot — a key cap, or a painted mouse when the bind is a mouse button.
##
## ```gdscript
## var dial := GoMagnetDial.make(176.0)
## dial.ring_ink = Color("#1fb5f0")                 # the game's gauge colour (a value with gameplay meaning)
## dial.ring_ink_end = Color("#6ff0ff")
## dial.set_mouse(GoMagnetDial.Half.ATTRACT, MOUSE_BUTTON_LEFT)
## dial.set_key(GoMagnetDial.Half.REPULSE, "E")     # or set_action(side, &"repulse") — reads InputMap
## hud.add_child(dial)
##
## dial.set_power(0.64)                 # the ring eases there; a drop shows a bright head on the arc
## dial.set_attracting(true)            # the left half lights, arrows flow to the centre, the ring glows
## dial.set_cooldown(1.4, 2.0)          # 1.4 s of 2 left: the right half is grey, red rises from the bottom, "1.4"
## dial.deny()                          # pressed while cooling: the right half shakes its head
## dial.set_super(true)                 # a gold rim round the ring
## dial.set_powered(false)              # eliminated: grey, a little smaller
## dial.enter(0.1)                      # the HUD came on: pop in after 0.1 s
## ```
##
## ## 🎞 Every change has a motion — and a still fallback
## | call | what moves |
## |---|---|
## | `set_attracting(true)` | the left half lights and grows a touch, arrows flow toward the centre, the ring glows |
## | `set_attracting(false)` | the arrows stop and the half eases back |
## | `set_cooldown()` from 0 to more | **fired**: the right half kicks outward, a shock ring leaves the dial, the half drops to grey |
## | `set_cooldown()` while cooling | the red refill rises smoothly between the values it is given, the seconds count down |
## | `set_cooldown()` back to 0 | **ready**: a white flash and a pop on the right half, a pulse round the ring |
## | `deny()` | a short sideways shake of the right half (only while cooling) |
## | `set_power()` | the ring eases to the value; while it drops, a bright head rides the end of the arc |
## | power at or under `low_ratio` | the ring pulses in the look's alert ink (`GoSkin.hud_alert_ink()`) |
## | power 0 | the ring flashes once and the dial stays dim until power returns |
## | `set_super(true)` | a second, gold rim glows round the ring |
## | `enter()` | one pop with an overshoot |
## | `set_powered(false)` | the dial turns grey and shrinks a little |
##
## 🛑 Under `GoConfig.reduce_motion` only the state changes: no movement, no flashing, the refill steps with its values.
## 🛑 Display only: it shows what it is given and decides nothing.
## 🔑 It redraws only while something moves or after a value changed; `advance()` is its clock (a test steps it by hand).
@tool
class_name GoMagnetDial
extends Control

enum Half { ATTRACT, REPULSE }

## The dial's diameter (dp). The ring, the halves, the glyphs and the text all scale with it.
@export_range(64.0, 512.0, 1.0) var diameter := 176.0:
	set(value):
		diameter = value
		_fit()

## The ring's colour where it starts. Transparent: the theme's `accent`.
@export var ring_ink := Color.TRANSPARENT:
	set(value):
		ring_ink = value
		queue_redraw()

## The colour the ring runs to at its far end. Transparent: `ring_ink` all the way.
@export var ring_ink_end := Color.TRANSPARENT:
	set(value):
		ring_ink_end = value
		queue_redraw()

## At or under this share of power the ring warns (pulses in the alert ink). 0: never.
@export_range(0.0, 1.0, 0.01) var low_ratio := 0.2:
	set(value):
		low_ratio = value
		_sync_low()

## A word over the dial ("MAGNET"). Empty: none, and the dial takes no room for it.
@export var caption := "":
	set(value):
		if caption == value: return
		caption = value
		_caption_size = 0
		_fit()

## Decimals of the seconds shown on the cooling half.
@export_range(0, 2) var cooldown_decimals := 1

## The lengths of the motions (seconds).
const FIRE_SECONDS := 0.42
const READY_SECONDS := 0.5
const DENY_SECONDS := 0.3
const SETTLE_SECONDS := 0.22
const LIGHT_SECONDS := 0.16
const FLOW_SECONDS := 0.7
const LOW_SECONDS := 0.8
const EMPTY_SECONDS := 0.4
const SUPER_SECONDS := 1.2
const ENTER_SECONDS := 0.38
const POWER_SECONDS := 0.3
## How hard the fired half kicks, the ready half pops and the lit half grows (shares of its size).
const FIRE_KICK := 0.16
const READY_POP := 0.12
const LIT_GROW := 0.04
## How far the denied half swings (shares of the diameter) and how small a powered-down dial is.
const DENY_SWING := 0.04
const OFF_SCALE := 0.9
## The ring starts down-left and sweeps clockwise three quarters round; the gap is at the foot, where the keys sit.
const RING_START := PI * 0.75
const RING_SWEEP := PI * 1.5
const RING_STEPS := 48
## How fast the ring follows its value (per second) and how long the head stays after the last drop.
const POWER_FOLLOW := 12.0
const HEAD_SECONDS := 0.4
const HALF_STEPS := 20

## The motion clock (`GoMotion`): `flow`, `light`, `settle`, `fire`, `ready`, `deny`, `low`, `empty`, `super`, `enter`,
## `power_down`, `power_up`. A test reads `motion.playing(&"fire")`.
var motion := GoMotion.new()

var _power := 1.0
var _power_shown := 1.0
var _head := 0.0
var _attracting := false
var _cool_left := 0.0
var _cool_total := 1.0
var _cool_shown := 0.0
var _cool_text := ""
var _cool_step := -1
var _super := false
var _powered := true
var _low := false
var _dim := false
var _keys: Array[String] = ["", ""]
var _mouse: Array[int] = [MOUSE_BUTTON_NONE, MOUSE_BUTTON_NONE]
var _caption_size := 0
var _half_points := PackedVector2Array()
## The transform the half being drawn sits in (its mirror needs it back).
var _half_at := Vector2.ZERO
var _half_grow := 1.0


func _init() -> void:
	name = "MagnetDial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 A physical layout: ATTRACT is the left mouse button's half in every language.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	for i in HALF_STEPS + 1:
		_half_points.append(Vector2.from_angle(-PI * 0.5 + PI * i / HALF_STEPS))
	set_process(false)
	_fit()


## A dial [param size] dp across.
static func make(size := 176.0) -> GoMagnetDial:
	var dial := GoMagnetDial.new()
	dial.diameter = size
	return dial


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()
	_wake()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	_caption_size = 0
	if GoUi.config.reduce_motion:
		motion.stop_all()
		_power_shown = _power
		_cool_shown = _cool_left
		_head = 0.0
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_caption_size = 0
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


# ── State ─────────────────────────────────────────────────────────────

## The share of power left, 0~1. The ring eases to it ([param animate] false: at once).
func set_power(ratio: float, animate := true) -> void:
	var next := clampf(ratio, 0.0, 1.0)
	if is_equal_approx(next, _power): return
	var dropped := next < _power
	var was_empty := _power <= 0.0
	_power = next
	if not animate or GoUi.config.reduce_motion or not is_inside_tree():
		_power_shown = next
	elif dropped:
		_head = HEAD_SECONDS
	if next <= 0.0 and not was_empty:
		_dim = true
		motion.play(&"empty", EMPTY_SECONDS)
	elif next > 0.0:
		_dim = false
	_sync_low()
	_wake()


func power() -> float:
	return _power


## The share the ring shows now (on its way to `power()`).
func shown_power() -> float:
	return _power_shown


## Whether the held action is on: the left half lights and its arrows flow.
func set_attracting(on: bool) -> void:
	if on == _attracting: return
	_attracting = on
	if on:
		motion.stop(&"settle")
		motion.play(&"light", LIGHT_SECONDS)
		motion.loop(&"flow", FLOW_SECONDS)
	else:
		motion.stop(&"flow")
		motion.stop(&"light")
		motion.play(&"settle", SETTLE_SECONDS)
	_wake()


func attracting() -> bool:
	return _attracting


## The fired action's wait: [param left] seconds of [param total]. Going from 0 to more is "fired", back to 0 is
## "ready again" — each plays its motion. Call it as often as the value changes.
func set_cooldown(left: float, total: float) -> void:
	var now := maxf(0.0, left)
	var was := _cool_left > 0.0
	if is_equal_approx(now, _cool_left) and is_equal_approx(total, _cool_total): return
	_cool_left = now
	_cool_total = maxf(total, 0.001)
	if now > 0.0 and not was:
		_cool_shown = now
		motion.stop(&"ready")
		motion.play(&"fire", FIRE_SECONDS)
	elif was and now <= 0.0:
		_cool_shown = 0.0
		motion.stop(&"deny")
		motion.play(&"ready", READY_SECONDS)
	elif GoUi.config.reduce_motion or not is_inside_tree() or absf(_cool_shown - now) > 0.25:
		_cool_shown = now
	var step := ceili(now * pow(10.0, cooldown_decimals) - 0.0001)
	if step != _cool_step:
		_cool_step = step
		_cool_text = ("%.*f" % [cooldown_decimals, step / pow(10.0, cooldown_decimals)]) if now > 0.0 else ""
	_wake()


## Whether the fired action is waiting.
func cooling() -> bool:
	return _cool_left > 0.0


## How much of the right half is red again, 0~1 (1: ready).
func refill() -> float:
	return 1.0 - clampf(_cool_shown / _cool_total, 0.0, 1.0)


## The seconds written on the cooling half ("1.4"); empty when ready.
func cooldown_text() -> String:
	return _cool_text


## The fired action was pressed while it waits: the right half shakes. Nothing when it is ready.
func deny() -> void:
	if not cooling(): return
	motion.play(&"deny", DENY_SECONDS)
	_wake()


## Whether the boost is on: a gold rim glows round the ring.
func set_super(on: bool) -> void:
	if on == _super: return
	_super = on
	if on: motion.loop(&"super", SUPER_SECONDS)
	else: motion.stop(&"super")
	_wake()


func is_super() -> bool:
	return _super


## false: the dial powers down (grey, a little smaller) — the player is out. true: back on.
func set_powered(on: bool) -> void:
	if on == _powered: return
	_powered = on
	motion.stop(&"power_down")
	motion.stop(&"power_up")
	motion.play(&"power_down" if not on else &"power_up", POWER_SECONDS)
	_wake()


func powered() -> bool:
	return _powered


## The HUD came on: the dial pops in after [param delay] seconds (stagger it with the parts beside it).
func enter(delay := 0.0) -> void:
	motion.play(&"enter", ENTER_SECONDS, delay)
	_wake()


## Whether the ring is warning (power at or under `low_ratio`, and not empty).
func low() -> bool:
	return _low


## Whether the dial is dim because its power ran out.
func dimmed() -> bool:
	return _dim


# ── Keys ──────────────────────────────────────────────────────────────

## The key cap at [param side]'s foot ("E", "Shift"). Empty hides it. Key names are shown as given, never translated.
func set_key(side: Half, text: String) -> void:
	if _keys[side] == text and _mouse[side] == MOUSE_BUTTON_NONE: return
	_keys[side] = text
	_mouse[side] = MOUSE_BUTTON_NONE
	queue_redraw()


## A painted mouse at [param side]'s foot with [param button] marked (`MOUSE_BUTTON_LEFT` or `MOUSE_BUTTON_RIGHT`).
func set_mouse(side: Half, button: MouseButton) -> void:
	if _mouse[side] == button: return
	_mouse[side] = button
	_keys[side] = ""
	queue_redraw()


## Reads what is **actually bound** to [param action] in `InputMap`: a left or right mouse button becomes the painted
## mouse, a key its cap. [param prefer_mouse] takes a mouse bind over a key when the action has both.
func set_action(side: Half, action: StringName, prefer_mouse := false) -> void:
	var button := action_mouse_button(action)
	var keys := GoKbd.action_keys(action)
	if button != MOUSE_BUTTON_NONE and (prefer_mouse or keys.is_empty()):
		set_mouse(side, button)
	else:
		set_key(side, " + ".join(PackedStringArray(keys)))


## The first left or right mouse button bound to [param action]; `MOUSE_BUTTON_NONE` when there is none.
static func action_mouse_button(action: StringName) -> MouseButton:
	if not InputMap.has_action(action): return MOUSE_BUTTON_NONE
	for event in InputMap.action_get_events(action):
		var click := event as InputEventMouseButton
		if click != null and click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return click.button_index
	return MOUSE_BUTTON_NONE


func key_text(side: Half) -> String:
	return _keys[side]


func mouse_button(side: Half) -> MouseButton:
	return _mouse[side] as MouseButton


# ── What a frame draws (a test reads these) ─────────────────────────────

## The whole dial's scale now: the entrance pop times the powered-down shrink.
func dial_scale() -> float:
	var enter_t := motion.at(&"enter", 1.0)
	return GoMotion.overshoot(enter_t) * lerpf(1.0, OFF_SCALE, off_amount()) if enter_t > 0.0 else 0.0


## How far the dial is powered down, 0 (on) ~ 1 (off).
func off_amount() -> float:
	if motion.playing(&"power_down"): return GoMotion.ease_out(motion.at(&"power_down"))
	if motion.playing(&"power_up"): return 1.0 - GoMotion.ease_out(motion.at(&"power_up"))
	return 0.0 if _powered else 1.0


## [param side]'s half scale now: the lit ATTRACT half is a touch bigger, the REPULSE half kicks and pops.
func half_scale(side: Half) -> float:
	if side == Half.ATTRACT: return 1.0 + LIT_GROW * lit_amount()
	return 1.0 + FIRE_KICK * GoMotion.punch(motion.at(&"fire")) + READY_POP * GoMotion.punch(motion.at(&"ready"))


## How lit the ATTRACT half is, 0~1: it eases up when the hold starts and back down when it ends.
func lit_amount() -> float:
	if _attracting: return GoMotion.ease_out(motion.at(&"light", 1.0))
	return 1.0 - GoMotion.ease_out(motion.at(&"settle", 1.0))


## The REPULSE half's sideways offset now (dp): the deny shake.
func shake_offset() -> float:
	return GoMotion.shake(motion.at(&"deny")) * diameter * DENY_SWING if motion.playing(&"deny") else 0.0


## The shock ring's radius now (dp); 0 when none is out.
func shock_radius() -> float:
	return diameter * 0.5 * (1.0 + 0.55 * GoMotion.ease_out(motion.at(&"fire"))) if motion.playing(&"fire") else 0.0


## The white flash over the REPULSE half now, 0~1.
func flash_amount() -> float:
	return (1.0 - motion.at(&"ready")) if motion.playing(&"ready") else 0.0


## Whether the arrows are flowing.
func flowing() -> bool:
	return motion.playing(&"flow")


## The ring's colour mix toward the alert ink now, 0~1: the low-power pulse and the one flash of running out.
func alert_amount() -> float:
	if motion.playing(&"empty"): return GoMotion.punch(motion.at(&"empty"))
	if not _low: return 0.0
	return 0.5 - 0.5 * cos(motion.at(&"low") * TAU) if motion.playing(&"low") else 1.0


## Whether anything is moving (the dial processes and redraws only then).
func moving() -> bool:
	return motion.busy() or not is_equal_approx(_power_shown, _power) or _head > 0.0 \
		or (_cool_left > 0.0 and not GoUi.config.reduce_motion)


## ⏱ Moves every motion on by [param delta] seconds. `_process` calls it; a test calls it by hand.
func advance(delta: float) -> void:
	motion.advance(delta)
	if not is_equal_approx(_power_shown, _power):
		_power_shown = lerpf(_power_shown, _power, minf(1.0, delta * POWER_FOLLOW))
		if absf(_power_shown - _power) < 0.003: _power_shown = _power
	if _head > 0.0: _head = maxf(0.0, _head - delta)
	if _cool_left > 0.0 and not GoUi.config.reduce_motion:
		# The refill runs on between the values it is given, never more than a tenth ahead of the last one.
		_cool_shown = maxf(maxf(0.0, _cool_left - 0.1), _cool_shown - delta)
	if not moving(): set_process(false)
	queue_redraw()


func _wake() -> void:
	queue_redraw()
	if is_inside_tree() and moving(): set_process(true)


func _sync_low() -> void:
	var now := low_ratio > 0.0 and _power > 0.0 and _power <= low_ratio
	if now == _low: return
	_low = now
	if now: motion.loop(&"low", LOW_SECONDS)
	else: motion.stop(&"low")
	_wake()


# ── Layout ────────────────────────────────────────────────────────────

func _unit() -> float:
	return diameter / 176.0


## Room over the dial for the caption, and under it for the key glyphs' overhang.
func _head_room() -> float:
	return 0.0 if caption.is_empty() else 22.0 * _unit()


func _foot_room() -> float:
	return 12.0 * _unit()


func _fit() -> void:
	custom_minimum_size = Vector2(diameter, _head_room() + diameter + _foot_room())
	queue_redraw()


## The dial's centre in its own rect.
func center() -> Vector2:
	return Vector2(size.x * 0.5, _head_room() + diameter * 0.5)


func _font() -> Font:
	return get_theme_font(&"font", &"Label")


# ── Drawing ───────────────────────────────────────────────────────────

func _draw() -> void:
	var skin := GoUi.skin()
	var u := _unit()
	var c := center()
	var scale_now := dial_scale()
	if not caption.is_empty(): _draw_caption(skin, c, u)
	if scale_now <= 0.0: return
	var off := off_amount()
	var radius := diameter * 0.5
	var line := skin.touch_outline_ink()
	draw_set_transform(c, 0.0, Vector2(scale_now, scale_now))
	# The shock ring a fired REPULSE sends out, under everything.
	if motion.playing(&"fire"):
		var t := motion.at(&"fire")
		draw_arc(Vector2.ZERO, shock_radius(), 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.85 * (1.0 - t)),
			maxf(1.0, 7.0 * u * (1.0 - t)), true)
	if motion.playing(&"ready"):
		var t := motion.at(&"ready")
		draw_arc(Vector2.ZERO, radius + 12.0 * u * GoMotion.ease_out(t), 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, 0.7 * (1.0 - t)), maxf(1.0, 5.0 * u * (1.0 - t)), true)
	_draw_ring(skin, radius, u, off, line)
	var inner := radius - 14.0 * u
	_draw_half(skin, Half.ATTRACT, inner, u, off, scale_now, c, line)
	_draw_half(skin, Half.REPULSE, inner, u, off, scale_now, c, line)
	draw_set_transform(c, 0.0, Vector2(scale_now, scale_now))
	_draw_key(skin, Half.ATTRACT, Vector2(-45.0 * u, radius - 12.0 * u), u)
	_draw_key(skin, Half.REPULSE, Vector2(45.0 * u, radius - 12.0 * u), u)
	draw_set_transform(Vector2.ZERO)


func _draw_caption(skin: GoSkin, c: Vector2, u: float) -> void:
	var font := _font()
	var base := roundi(13.0 * u)
	var word := tr(caption)
	if _caption_size <= 0:
		_caption_size = GoStyle.fit_font_size(PackedStringArray([word]), base, diameter, font)
	var at := Vector2(c.x - diameter * 0.5, _head_room() - 7.0 * u)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_CENTER, diameter, _caption_size, roundi(5.0 * u),
		skin.touch_outline_ink())
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_CENTER, diameter, _caption_size, Color.WHITE)


## The ring: a dark track three quarters round, the power's arc on it (`ring_ink` → `ring_ink_end`, toward the alert ink
## while it warns), a bright head while it drops, the boost's gold rim.
func _draw_ring(skin: GoSkin, radius: float, u: float, off: float, line: Color) -> void:
	var mid := radius - 7.0 * u
	var track_end := RING_START + RING_SWEEP
	draw_arc(Vector2.ZERO, mid, RING_START, track_end, RING_STEPS, line, 14.0 * u, true)
	_cap(mid, RING_START, 7.0 * u, line)
	_cap(mid, track_end, 7.0 * u, line)
	draw_arc(Vector2.ZERO, mid, RING_START, track_end, RING_STEPS, line.lerp(Color.WHITE, 0.16), 8.0 * u, true)
	if _super:
		var gold := GoUi.color(GoTheme.WARNING_FILL)
		var glow := 0.5 + 0.5 * cos(motion.at(&"super") * TAU) if motion.playing(&"super") else 1.0
		draw_arc(Vector2.ZERO, radius + 5.0 * u, RING_START, track_end, RING_STEPS, Color(gold, 0.25 + 0.3 * glow),
			(8.0 + 4.0 * glow) * u, true)
		draw_arc(Vector2.ZERO, radius + 2.0 * u, RING_START, track_end, RING_STEPS, gold, 3.5 * u, true)
	var shown := _power_shown * (1.0 - off)
	if shown <= 0.0: return
	var start := ring_ink if ring_ink.a > 0.0 else GoUi.color(GoTheme.ACCENT)
	var finish := ring_ink_end if ring_ink_end.a > 0.0 else start
	var alert := alert_amount()
	if alert > 0.0:
		var warn := skin.hud_alert_ink()
		start = start.lerp(warn, alert)
		finish = finish.lerp(warn, alert)
	var steps := maxi(2, ceili(RING_STEPS * shown))
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in steps + 1:
		var share := shown * i / steps
		points.append(Vector2.from_angle(RING_START + RING_SWEEP * share) * mid)
		colors.append(start.lerp(finish, share))
	if lit_amount() > 0.0:
		var pulse := 0.5 + 0.5 * sin(motion.at(&"flow") * TAU)
		draw_polyline(points, Color(finish, (0.3 + 0.25 * pulse) * lit_amount()), 15.0 * u, true)
	draw_polyline_colors(points, colors, 8.0 * u, true)
	_cap(mid, RING_START, 4.0 * u, start)
	var tip := RING_START + RING_SWEEP * shown
	_cap(mid, tip, 4.0 * u, colors[steps])
	if _head > 0.0:
		var glow := _head / HEAD_SECONDS
		draw_circle(Vector2.from_angle(tip) * mid, 9.0 * u, Color(1.0, 1.0, 1.0, 0.35 * glow))
		draw_circle(Vector2.from_angle(tip) * mid, 5.5 * u, Color(1.0, 1.0, 1.0, glow))


func _cap(mid: float, angle: float, r: float, ink: Color) -> void:
	draw_circle(Vector2.from_angle(angle) * mid, r, ink)


## One half of the disc, with its own kick, pop, shake and light, and what stands on it: the arrows, or the seconds.
func _draw_half(skin: GoSkin, side: Half, inner: float, u: float, off: float, scale_now: float, c: Vector2,
		line: Color) -> void:
	var grow := half_scale(side) * scale_now
	var push := Vector2(shake_offset(), 0.0) if side == Half.REPULSE else Vector2.ZERO
	_half_at = c + push * scale_now
	_half_grow = grow
	draw_set_transform(_half_at, 0.0, Vector2(grow, grow))
	var left := side == Half.ATTRACT
	var cooling_now := side == Half.REPULSE and cooling()
	var grey := off >= 0.5 or cooling_now
	var dim := Color(0.62, 0.64, 0.72) if (_dim and not grey) else Color.WHITE
	_paint_half(skin, left, grey, inner, line, dim, 1.0)
	if cooling_now and off < 0.5:
		var fill := refill()
		if fill > 0.0: _paint_half(skin, left, false, inner, line, Color.WHITE, fill)
	var lit := lit_amount() if left else 0.0
	if lit > 0.0 and off < 0.5: _wash(left, inner - 4.0 * u, Color(1.0, 1.0, 1.0, 0.2 * lit))
	var flash := flash_amount() if not left else 0.0
	if flash > 0.0: _wash(left, inner - 4.0 * u, Color(1.0, 1.0, 1.0, 0.85 * flash))
	var dir := -1.0 if left else 1.0
	if cooling_now and off < 0.5 and not _cool_text.is_empty():
		var font := _font()
		var fs := roundi(26.0 * u)
		var room := inner * 0.84
		var at := Vector2(inner * 0.06, fs * 0.36)
		draw_string_outline(font, at, _cool_text, HORIZONTAL_ALIGNMENT_CENTER, room, fs, roundi(6.0 * u), line)
		draw_string(font, at, _cool_text, HORIZONTAL_ALIGNMENT_CENTER, room, fs, Color.WHITE)
		return
	var tint := Color(1.0, 1.0, 1.0, 0.55 if (grey or _dim) else 1.0)
	var side_len := 26.0 * u
	if left and flowing():
		# Three chevrons run from the rim to the centre, fading in and out, a third of the way apart.
		var phase := motion.at(&"flow")
		for i in 3:
			var t := fmod(phase + i / 3.0, 1.0)
			var x := lerpf(inner * 0.86, inner * 0.16, t)
			_arrow(skin, Vector2(-x, 0.0), side_len, false, Color(1.0, 1.0, 1.0, sin(t * PI)), line)
	else:
		for share: float in [0.34, 0.6]:
			_arrow(skin, Vector2(dir * inner * share, 0.0), side_len, false, tint, line)


## A half disc of the look's art (`dial_attract`, `dial_repulse`, `dial_off`) — or drawn, where the look ships none.
## [param fill] under 1 shows only that share of it, from the bottom (the cooldown's refill).
func _paint_half(skin: GoSkin, left: bool, grey: bool, inner: float, line: Color, tint: Color, fill: float) -> void:
	var art := skin.widget_art(&"dial_off" if grey else (&"dial_attract" if left else &"dial_repulse"))
	var top := -inner + inner * 2.0 * (1.0 - fill)
	if art != null:
		var from := art.get_height() * (1.0 - fill)
		var source := Rect2(0.0, from, art.get_width(), art.get_height() - from)
		# The grey art is painted as a right half: on the left it is drawn through a mirrored transform.
		var mirror := grey and left
		var dest := Rect2(-inner if (left and not mirror) else 0.0, top, inner, inner * 2.0 * fill)
		if mirror: draw_set_transform(_half_at, 0.0, Vector2(-_half_grow, _half_grow))
		draw_texture_rect_region(art, dest, source, tint)
		if mirror: draw_set_transform(_half_at, 0.0, Vector2(_half_grow, _half_grow))
		return
	var paint := GoUi.color(GoTheme.MUTED_FILL) if grey \
		else GoUi.color(GoTheme.ACCENT if left else GoTheme.DANGER_FILL)
	var points := PackedVector2Array()
	for p in _half_points:
		var at := Vector2(-p.x if left else p.x, p.y) * inner
		at.y = maxf(at.y, top)
		points.append(at)
	draw_colored_polygon(points, Color(paint.r * tint.r, paint.g * tint.g, paint.b * tint.b, paint.a))
	if fill >= 1.0:
		points.append(points[0])
		draw_polyline(points, line, maxf(1.0, inner * 0.05), true)


## A flat wash over a half's face: the lit ATTRACT half, the READY flash.
func _wash(left: bool, r: float, ink: Color) -> void:
	var points := PackedVector2Array()
	for p in _half_points: points.append(Vector2(-p.x if left else p.x, p.y) * r)
	draw_colored_polygon(points, ink)


## One chevron centred on [param at], pointing right (both halves push the same way: toward the centre on the left,
## away from it on the right).
func _arrow(skin: GoSkin, at: Vector2, side_len: float, flip: bool, tint: Color, line: Color) -> void:
	var art := skin.widget_art(&"dial_arrow")
	if art != null:
		var rect := Rect2(at - Vector2(side_len, side_len) * 0.5, Vector2(side_len, side_len))
		if flip: rect = Rect2(at + Vector2(side_len, -side_len) * 0.5, Vector2(-side_len, side_len))
		draw_texture_rect(art, rect, false, tint)
		return
	var reach := side_len * 0.3 * (-1.0 if flip else 1.0)
	var shape := PackedVector2Array([at + Vector2(-reach, -side_len * 0.34), at + Vector2(reach, 0.0),
		at + Vector2(-reach, side_len * 0.34)])
	draw_polyline(shape, Color(line, tint.a), side_len * 0.26, true)
	draw_polyline(shape, tint, side_len * 0.14, true)


## The key at a half's foot: the painted mouse, else a key cap (`GoSkin.kbd_box()`) with the key's name.
func _draw_key(skin: GoSkin, side: Half, at: Vector2, u: float) -> void:
	var button := _mouse[side]
	if button != MOUSE_BUTTON_NONE:
		var art := skin.widget_art(&"mouse_left" if button == MOUSE_BUTTON_LEFT else &"mouse_right")
		var tall := 46.0 * u
		if art != null:
			draw_texture_rect(art, Rect2(at - Vector2(tall, tall) * 0.5, Vector2(tall, tall)), false)
			return
		_draw_cap(skin, at, "L" if button == MOUSE_BUTTON_LEFT else "R", u)
		return
	if not _keys[side].is_empty(): _draw_cap(skin, at, _keys[side], u)


func _draw_cap(skin: GoSkin, at: Vector2, word: String, u: float) -> void:
	var font := _font()
	var room := 64.0 * u
	var fs := GoStyle.fit_font_size(PackedStringArray([word]), roundi(13.0 * u), room, font)
	var text := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tall := 24.0 * u
	var wide := maxf(tall, text.x + 12.0 * u)
	var rect := Rect2(at - Vector2(wide, tall) * 0.5, Vector2(wide, tall))
	draw_style_box(skin.kbd_box(), rect)
	draw_string(font, Vector2(rect.position.x, at.y + fs * 0.34 - 1.0 * u), word, HORIZONTAL_ALIGNMENT_CENTER, wide,
		fs, skin.kbd_ink())
