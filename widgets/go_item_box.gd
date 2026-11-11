## 🎁 **Item box** — the one thing the player holds, in a gold frame: its picture, its name on a gold tab over the box,
## how many are left (`×2`), how long it still runs (an edge that drains, and the seconds), a fuse (tenths, the box
## pulsing with each tick) and the key that uses it under the box. With nothing held it is a faint dashed frame.
##
## ```gdscript
## var box := GoItemBox.make(66.0)
## box.set_key("F")                                  # or set_action(&"use_powerup") — reads InputMap
## box.timer_ink = Color("#8a5cff")                  # the game's colour for a running item
## hud.add_child(box)
##
## box.set_item(GoUi.skin().widget_art(&"powerup_banana"), "BANANA")   # pops in, sparkles, the tab slides up
## box.set_charges(2)                                # "×2"; one fewer later: the picture punches, the badge bumps
## box.set_timer(4.2, 6.0)                           # a running item: the edge drains, "5"; the last 3 s blink faster
## box.set_active(true)                              # the key gives way to the word in `active_text`
## box.set_fuse(1.3, 3.0)                            # a lit fuse: "1.3", a pulse per tick, faster as it runs out
## box.clear()                                       # the picture shrinks out, the frame is dashed again
## ```
##
## 🛑 Under `GoConfig.reduce_motion` only the state changes: no pop, no sparkles, no blinking, no pulse.
## 🛑 Display only: it shows what it is given and decides nothing.
## 🔑 It redraws only while something moves or after a value changed; `advance()` is its clock (a test steps it by hand).
@tool
class_name GoItemBox
extends Control

## The box's side (dp). The tab, the badge, the key and the text scale with it.
@export_range(32.0, 256.0, 1.0) var side := 66.0:
	set(value):
		side = value
		_boxes.clear()
		_fit()

## The colour of a running item's edge and of the box while a fuse burns low. Transparent: the theme's `accent`.
@export var timer_ink := Color.TRANSPARENT:
	set(value):
		timer_ink = value
		queue_redraw()

## The far end of the draining edge. Transparent: `timer_ink` all the way.
@export var timer_ink_end := Color.TRANSPARENT:
	set(value):
		timer_ink_end = value
		queue_redraw()

## The word under the box while the item runs by itself (`set_active(true)`), in place of the key. Translated here.
@export var active_text := "ACTIVE":
	set(value):
		active_text = value
		_text_sizes.clear()
		queue_redraw()

## From this many seconds left a running item blinks faster.
@export_range(0.0, 30.0, 0.1) var hurry_seconds := 3.0

const GAIN_SECONDS := 0.42
const TAB_SECONDS := 0.26
const TAB_DELAY := 0.12
const USE_SECONDS := 0.3
const LEAVE_SECONDS := 0.26
const ENTER_SECONDS := 0.38
## A running item's edge breathes slowly, then blinks fast in its last `hurry_seconds`.
const BLINK_SLOW := 1.1
const BLINK_FAST := 0.32
## A fuse ticks this often with all its time left, and this often at the end.
const TICK_SLOW := 0.6
const TICK_FAST := 0.14
const USE_PUNCH := 0.22
const BADGE_BUMP := 0.35
const TICK_PULSE := 0.1
const SPARKLES := 10
const EDGE_STEPS := 40

## The motion clock (`GoMotion`): `gain`, `tab`, `use`, `leave`, `blink`, `tick`, `enter`.
var motion := GoMotion.new()

var _icon: Texture2D
var _name := ""
var _leaving: Texture2D
var _charges := 0
var _badge := ""
var _timer_left := 0.0
var _timer_total := 0.0
var _timer_shown := 0.0
var _timer_text := ""
var _timer_step := -1
var _fuse_left := 0.0
var _fuse_total := 0.0
var _fuse_text := ""
var _fuse_step := -1
var _key := ""
var _active := false
var _sparkles: CPUParticles2D
var _bursts := 0
var _boxes: Dictionary = {}
var _text_sizes: Dictionary = {}
var _edge := PackedVector2Array()


func _init() -> void:
	name = "ItemBox"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_process(false)
	_fit()


## An empty item box [param size] dp across.
static func make(size := 66.0) -> GoItemBox:
	var box := GoItemBox.new()
	box.side = size
	return box


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()
	_wake()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	_boxes.clear()
	_text_sizes.clear()
	if GoUi.config.reduce_motion:
		motion.stop_all()
		_leaving = null
		_timer_shown = _timer_left
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_text_sizes.clear()
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


# ── State ─────────────────────────────────────────────────────────────

## Holds [param icon] under [param item_name] (already in the player's language, or a key `tr()` knows). A box that
## was empty — or held something else — plays the gain: the pop, the sparkles, the tab sliding up. null clears.
func set_item(icon: Texture2D, item_name := "") -> void:
	if icon == null:
		clear()
		return
	if icon == _icon and item_name == _name: return
	var fresh := icon != _icon
	_icon = icon
	_name = item_name
	_text_sizes.clear()
	if fresh:
		_leaving = null
		motion.stop(&"leave")
		if motion.play(&"gain", GAIN_SECONDS):
			motion.play(&"tab", TAB_SECONDS, TAB_DELAY)
			_burst()
	_wake()


## Nothing is held any more: the picture shrinks out and the frame goes back to dashed. The count, the timer, the fuse
## and `active` go with it.
func clear() -> void:
	if _icon == null: return
	_leaving = _icon
	_icon = null
	_name = ""
	_charges = 0
	_badge = ""
	_timer_left = 0.0
	_timer_total = 0.0
	_timer_text = ""
	_timer_step = -1
	_fuse_left = 0.0
	_fuse_total = 0.0
	_fuse_text = ""
	_fuse_step = -1
	_active = false
	for track: StringName in [&"gain", &"tab", &"use", &"blink", &"tick"]: motion.stop(track)
	if not motion.play(&"leave", LEAVE_SECONDS): _leaving = null
	_wake()


## Whether something is held.
func held() -> bool:
	return _icon != null


func icon() -> Texture2D:
	return _icon


func item_name() -> String:
	return _name


## How many uses are left: 2 or more shows `×N` on the corner. One fewer than before is "used" — the picture punches
## and the badge bumps.
func set_charges(count: int) -> void:
	var next := maxi(0, count)
	if next == _charges: return
	var spent := next < _charges and _icon != null
	_charges = next
	_badge = "×%d" % next if next > 1 else ""
	if spent: motion.play(&"use", USE_SECONDS)
	_wake()


func charges() -> int:
	return _charges


## The count on the corner ("×2"); empty for one or none.
func badge_text() -> String:
	return _badge


## A running item: [param left] seconds of [param total]. The edge drains and the whole seconds are written; in the
## last `hurry_seconds` the edge blinks faster. [param total] 0 or less: not running.
func set_timer(left: float, total: float) -> void:
	var now := maxf(0.0, left) if total > 0.0 else 0.0
	# Exact, not approximate: the last sliver of a run and 0 are different states.
	if now == _timer_left and is_equal_approx(total, _timer_total): return
	var started := _timer_left <= 0.0
	_timer_left = now
	_timer_total = maxf(0.0, total)
	if now <= 0.0:
		_timer_shown = 0.0
		_timer_text = ""
		_timer_step = -1
		motion.stop(&"blink")
	else:
		if started or GoUi.config.reduce_motion or not is_inside_tree() or absf(_timer_shown - now) > 0.25:
			_timer_shown = now
		var step := maxi(1, ceili(now - 0.0001))
		if step != _timer_step:
			_timer_step = step
			_timer_text = str(step)
		motion.loop(&"blink", BLINK_FAST if hurrying() else BLINK_SLOW)
	_wake()


## Whether an item is running.
func timed() -> bool:
	return _timer_left > 0.0


## Whether the running item is in its last `hurry_seconds`.
func hurrying() -> bool:
	return _timer_left > 0.0 and _timer_left <= hurry_seconds


## The share of the edge still lit, 0~1.
func timer_share() -> float:
	return clampf(_timer_shown / _timer_total, 0.0, 1.0) if _timer_total > 0.0 else 0.0


## The seconds written in the box ("5"); empty when nothing runs.
func timer_text() -> String:
	return _timer_text


## A lit fuse: [param left] seconds of [param total]. The tenths are written and the box pulses with each tick — the
## ticks come faster as the fuse runs out. [param total] 0 or less: no fuse.
func set_fuse(left: float, total: float) -> void:
	var now := maxf(0.0, left) if total > 0.0 else 0.0
	if now == _fuse_left and is_equal_approx(total, _fuse_total): return
	_fuse_left = now
	_fuse_total = maxf(0.0, total)
	if now <= 0.0:
		_fuse_text = ""
		_fuse_step = -1
		motion.stop(&"tick")
	else:
		var step := maxi(1, ceili(now * 10.0 - 0.0001))
		if step != _fuse_step:
			_fuse_step = step
			_fuse_text = "%.1f" % (step / 10.0)
		motion.loop(&"tick", tick_seconds())
	_wake()


## Whether a fuse burns.
func lit() -> bool:
	return _fuse_left > 0.0


## The time between two ticks of the fuse now.
func tick_seconds() -> float:
	return lerpf(TICK_FAST, TICK_SLOW, clampf(_fuse_left / _fuse_total, 0.0, 1.0)) if _fuse_total > 0.0 else TICK_SLOW


## The tenths written in the box ("1.3"); empty without a fuse.
func fuse_text() -> String:
	return _fuse_text


## The key cap under the box ("F"). Empty hides it. Shown as given, never translated.
func set_key(text: String) -> void:
	if _key == text: return
	_key = text
	_text_sizes.clear()
	queue_redraw()


## Reads the key **actually bound** to [param action] in `InputMap` (`GoKbd.action_keys`).
func set_action(action: StringName) -> void:
	set_key(" + ".join(PackedStringArray(GoKbd.action_keys(action))))


func key_text() -> String:
	return _key


## true: the item runs by itself — `active_text` stands under the box in place of the key.
func set_active(on: bool) -> void:
	if on == _active: return
	_active = on
	queue_redraw()


func active() -> bool:
	return _active


## The HUD came on: the box pops in after [param delay] seconds.
func enter(delay := 0.0) -> void:
	motion.play(&"enter", ENTER_SECONDS, delay)
	_wake()


# ── What a frame draws (a test reads these) ─────────────────────────────

## The whole box's scale now: the entrance, the gain's pop and the fuse's pulse.
func box_scale() -> float:
	var enter_t := motion.at(&"enter", 1.0)
	if enter_t <= 0.0: return 0.0
	var pop := GoMotion.overshoot(motion.at(&"gain", 1.0), 2.6) if motion.playing(&"gain") else 1.0
	return GoMotion.overshoot(enter_t) * lerpf(0.6, 1.0, pop) * (1.0 + TICK_PULSE * tick_amount())


## The picture's scale now: the use's punch; shrinking to nothing as it leaves.
func icon_scale() -> float:
	if _icon == null:
		return 1.0 - GoMotion.ease_out(motion.at(&"leave")) if motion.playing(&"leave") else 0.0
	return 1.0 + USE_PUNCH * GoMotion.punch(motion.at(&"use"))


## The count badge's scale now.
func badge_scale() -> float:
	return 1.0 + BADGE_BUMP * GoMotion.punch(motion.at(&"use"))


## How far the name tab has slid up into place, 0~1.
func tab_amount() -> float:
	if _icon == null: return 0.0
	return GoMotion.ease_out(motion.at(&"tab", 1.0))


## How lit the draining edge is now, 0~1 (it blinks; steady under reduce_motion).
func blink_amount() -> float:
	if not timed(): return 0.0
	return 0.55 + 0.45 * cos(motion.at(&"blink") * TAU) if motion.playing(&"blink") else 1.0


## The fuse's pulse now, 0~1: full on the tick, gone before the next.
func tick_amount() -> float:
	if not motion.playing(&"tick"): return 0.0
	return maxf(0.0, 1.0 - motion.at(&"tick") * 2.5)


## How many times the sparkles have fired.
func bursts() -> int:
	return _bursts


func moving() -> bool:
	return motion.busy() or (_timer_left > 0.0 and not GoUi.config.reduce_motion)


## ⏱ Moves every motion on by [param delta] seconds. `_process` calls it; a test calls it by hand.
func advance(delta: float) -> void:
	motion.advance(delta)
	if _leaving != null and not motion.playing(&"leave"): _leaving = null
	if _timer_left > 0.0 and not GoUi.config.reduce_motion:
		_timer_shown = maxf(maxf(0.0, _timer_left - 0.1), _timer_shown - delta)
	if not moving(): set_process(false)
	queue_redraw()


func _wake() -> void:
	queue_redraw()
	if is_inside_tree() and moving(): set_process(true)


func _burst() -> void:
	_bursts += 1
	if not is_inside_tree(): return
	if not is_instance_valid(_sparkles):
		_sparkles = GoFx.sparkles(SPARKLES, 0.5, 170.0, _unit())
		# Small glints round a 66 dp box, not the full-size stars of a reward.
		_sparkles.scale_amount_min *= 0.4
		_sparkles.scale_amount_max *= 0.4
		_sparkles.name = "Sparkles"
		add_child(_sparkles)
	_sparkles.position = box_center()
	_sparkles.restart()


# ── Layout ────────────────────────────────────────────────────────────

func _unit() -> float:
	return side / 66.0


func _tab_room() -> float:
	return 16.0 * _unit()


func _key_room() -> float:
	return 28.0 * _unit()


func _fit() -> void:
	custom_minimum_size = Vector2(side * 1.5, _tab_room() + side + _key_room())
	_edge.clear()
	queue_redraw()


## The box's centre in the widget's own rect.
func box_center() -> Vector2:
	return Vector2(size.x * 0.5, _tab_room() + side * 0.5)


func _font() -> Font:
	return get_theme_font(&"font", &"Label")


func _fit_size(word: String, base: int, room: float) -> int:
	var key := "%s|%d" % [word, base]
	if not _text_sizes.has(key):
		_text_sizes[key] = GoStyle.fit_font_size(PackedStringArray([word]), base, room, _font())
	return _text_sizes[key]


# ── Drawing ───────────────────────────────────────────────────────────

func _draw() -> void:
	var grow := box_scale()
	if grow <= 0.0: return
	var skin := GoUi.skin()
	var u := _unit()
	var c := box_center()
	var line := skin.touch_outline_ink()
	var half := side * 0.5
	var rect := Rect2(-half, -half, side, side)
	draw_set_transform(c, 0.0, Vector2(grow, grow))
	var is_held := _icon != null
	var art := skin.widget_art(&"item_box" if is_held else &"item_box_empty")
	if art != null: draw_texture_rect(art, rect, false)
	else: draw_style_box(_frame_box(is_held, line), rect)
	var pulse := tick_amount()
	if pulse > 0.0:
		draw_style_box(_wash_box(Color(skin.hud_alert_ink(), 0.55 * pulse)), rect.grow(-6.0 * u))
	if timed(): _draw_edge(rect.grow(-9.5 * u), u)
	var picture := _icon if is_held else _leaving
	var picture_scale := icon_scale()
	if picture != null and picture_scale > 0.0:
		var reach := (half - 11.0 * u) * picture_scale
		draw_texture_rect(picture, Rect2(-reach, -reach, reach * 2.0, reach * 2.0), false)
	var font := _font()
	var number := _fuse_text if lit() else _timer_text
	if is_held and not number.is_empty():
		var fs := roundi((17.0 if lit() else 15.0) * u)
		var at := Vector2(-half + 6.0 * u, half - 8.0 * u)
		var ink := skin.hud_alert_ink().lerp(Color.WHITE, 0.75) if lit() else Color.WHITE
		draw_string_outline(font, at, number, HORIZONTAL_ALIGNMENT_RIGHT, side - 14.0 * u, fs, roundi(5.0 * u), line)
		draw_string(font, at, number, HORIZONTAL_ALIGNMENT_RIGHT, side - 14.0 * u, fs, ink)
	if is_held and not _badge.is_empty(): _draw_badge(skin, font, Vector2(half - 6.0 * u, -half + 6.0 * u), u, grow, c, line)
	draw_set_transform(c, 0.0, Vector2(grow, grow))
	if is_held and not _name.is_empty(): _draw_tab(font, half, u, line)
	draw_set_transform(Vector2.ZERO)
	_draw_foot(skin, font, c, half, u, line)


## The running item's edge: the share of time left, drawn round the well from the top, clockwise.
func _draw_edge(rect: Rect2, u: float) -> void:
	if _edge.is_empty():
		var bend := rect.size.x * 0.24
		var corners := [rect.position + Vector2(rect.size.x - bend, bend), rect.end - Vector2(bend, bend),
			rect.position + Vector2(bend, rect.size.y - bend), rect.position + Vector2(bend, bend)]
		_edge.append(Vector2(0.0, rect.position.y))
		for corner_index in 4:
			for i in EDGE_STEPS / 4 + 1:
				var a := -PI * 0.5 + PI * 0.5 * corner_index + PI * 0.5 * i / (EDGE_STEPS / 4)
				_edge.append((corners[corner_index] as Vector2) + Vector2.from_angle(a) * bend)
		_edge.append(Vector2(0.0, rect.position.y))
	var share := timer_share()
	var count := mini(_edge.size(), maxi(2, ceili(_edge.size() * share)))
	if share <= 0.0: return
	var start := timer_ink if timer_ink.a > 0.0 else GoUi.color(GoTheme.ACCENT)
	var finish := timer_ink_end if timer_ink_end.a > 0.0 else start
	var points := _edge.slice(0, count)
	var colors := PackedColorArray()
	var glow := blink_amount()
	for i in count: colors.append(Color(start.lerp(finish, float(i) / _edge.size()), glow))
	draw_polyline_colors(points, colors, 4.5 * u, true)


func _draw_badge(skin: GoSkin, font: Font, at: Vector2, u: float, grow: float, c: Vector2, line: Color) -> void:
	var bump := badge_scale()
	draw_set_transform(c + at * grow, 0.0, Vector2(grow * bump, grow * bump))
	var fs := roundi(13.0 * u)
	var wide := maxf(24.0 * u, font.get_string_size(_badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0 * u)
	var rect := Rect2(-wide * 0.5, -12.0 * u, wide, 24.0 * u)
	if not _boxes.has(&"badge"): _boxes[&"badge"] = skin.badge_box(GoUi.color(GoTheme.DANGER_FILL))
	draw_style_box(_boxes[&"badge"], rect)
	var base := Vector2(rect.position.x, fs * 0.36 - 1.0 * u)
	draw_string_outline(font, base, _badge, HORIZONTAL_ALIGNMENT_CENTER, wide, fs, roundi(4.0 * u), line)
	draw_string(font, base, _badge, HORIZONTAL_ALIGNMENT_CENTER, wide, fs, Color.WHITE)


## The name on its gold tab, over the box's top edge; it slides up into place and fades in.
func _draw_tab(font: Font, half: float, u: float, line: Color) -> void:
	var shown := tab_amount()
	if shown <= 0.0: return
	var word := tr(_name)
	var room := side * 1.5 - 16.0 * u
	var fs := _fit_size(word, roundi(11.0 * u), room)
	var wide := minf(side * 1.5, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0 * u)
	var tall := 18.0 * u
	var rect := Rect2(-wide * 0.5, -half - tall + 5.0 * u + 8.0 * u * (1.0 - shown), wide, tall)
	var gold := GoUi.color(GoTheme.WARNING_FILL)
	if not _boxes.has(&"tab"):
		var plate := StyleBoxFlat.new()
		plate.bg_color = gold
		plate.border_color = line
		plate.set_border_width_all(maxi(1, roundi(2.5 * u)))
		plate.set_corner_radius_all(roundi(tall * 0.5))
		plate.anti_aliasing = true
		_boxes[&"tab"] = plate
	draw_style_box(_boxes[&"tab"], rect)
	var ink := GoSkin.readable_on(line, gold)
	draw_string(font, Vector2(rect.position.x, rect.position.y + tall * 0.5 + fs * 0.36), word, HORIZONTAL_ALIGNMENT_CENTER,
		wide, fs, Color(ink, shown))


## Under the box: the key that uses the item, or — while it runs by itself — `active_text`.
func _draw_foot(skin: GoSkin, font: Font, c: Vector2, half: float, u: float, line: Color) -> void:
	var mid := Vector2(c.x, c.y + half + 4.0 * u + 12.0 * u)
	if _active and _icon != null:
		var word := tr(active_text)
		var fs := _fit_size(word, roundi(11.0 * u), side * 1.5)
		var at := Vector2(c.x - side * 0.75, mid.y + fs * 0.36)
		draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_CENTER, side * 1.5, fs, roundi(5.0 * u), line)
		draw_string(font, at, word, HORIZONTAL_ALIGNMENT_CENTER, side * 1.5, fs, Color.WHITE)
		return
	if _key.is_empty(): return
	var fs := _fit_size(_key, roundi(13.0 * u), side * 1.5 - 12.0 * u)
	var tall := 24.0 * u
	var wide := maxf(tall, font.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0 * u)
	var rect := Rect2(mid - Vector2(wide, tall) * 0.5, Vector2(wide, tall))
	if not _boxes.has(&"key"): _boxes[&"key"] = skin.kbd_box()
	var dim := 1.0 if _icon != null else 0.55
	draw_style_box(_boxes[&"key"], rect)
	draw_string(font, Vector2(rect.position.x, mid.y + fs * 0.34 - 1.0 * u), _key, HORIZONTAL_ALIGNMENT_CENTER, wide, fs,
		Color(skin.kbd_ink(), dim))


## A look without the painted box: a gold frame round a dark well — or, empty, a faint outline.
func _frame_box(is_held: bool, line: Color) -> StyleBox:
	var key := &"frame" if is_held else &"empty"
	if not _boxes.has(key):
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(roundi(side * 0.27))
		box.anti_aliasing = true
		if is_held:
			box.bg_color = line.lerp(GoUi.color(GoTheme.ACCENT), 0.25)
			box.border_color = GoUi.color(GoTheme.WARNING_FILL)
			box.set_border_width_all(maxi(2, roundi(side * 0.06)))
		else:
			box.bg_color = Color(line, 0.3)
			box.border_color = Color(1.0, 1.0, 1.0, 0.55)
			box.set_border_width_all(maxi(1, roundi(side * 0.035)))
		_boxes[key] = box
	return _boxes[key]


func _wash_box(ink: Color) -> StyleBox:
	if not _boxes.has(&"wash"):
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(roundi(side * 0.2))
		box.anti_aliasing = true
		_boxes[&"wash"] = box
	(_boxes[&"wash"] as StyleBoxFlat).bg_color = ink
	return _boxes[&"wash"]
