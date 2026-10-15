## 👆 **A round touch button** — the big thumb buttons of a mobile action game (jump, fire, a skill): a round picture
## with its name under the icon, a cooldown ring while it recharges, a pulse when it is ready again, and — with
## `drag_aim` — a button that is also a small stick: hold it and drag to aim, with a ring and knob under the thumb.
##
## ```gdscript
## var jump := GoTouchButton.make(&"btn_jump", tr("JUMP"), 86.0)
## hud.add_child(jump)
## jump.pressed_down.connect(func() -> void: input.send_jump())     # the game sends the input; the server decides
##
## var skill := GoTouchButton.make(&"btn_repulse", tr("REPULSE"), 92.0)
## skill.cooling = true                         # the server said it is recharging
## skill.cooldown = seconds_left / total        # the share still to run
## skill.text = "%.1f" % seconds_left           # the label can show the wait
##
## var aim := GoTouchButton.make(&"btn_attract", tr("ATTRACT"), 120.0)
## aim.drag_aim = true
## aim.caption = tr("HOLD + DRAG")              # under the label at rest
## aim.held_caption = tr("DRAG TO AIM")         # under the button while held
## aim.aimed.connect(func(pull: Vector2) -> void: input.aim(pull))
## ```
##
## The picture is `GoSkin.widget_art(art_name)` (or `art`); a look without the art draws an `accent` disc. A held
## button shrinks to `press_scale` and darkens by `press_tint`. Labels are white over a `GoSkin.touch_outline_ink()`
## edge and shrink to fit the button (never under `min_font_size`). 🛑 Display and input only: it reports presses and
## the aim, and shows the cooldown it is given.
@tool
class_name GoTouchButton
extends Control

## A finger (or the mouse) came down on it.
signal pressed_down
## The finger lifted — [param canceled] when it was taken away (`cancel()`), not lifted.
signal released(canceled: bool)
## With `drag_aim`: the pull from where the finger came down, length 0~1 (1 at `aim_radius`).
signal aimed(pull: Vector2)

## The picture's name in the skin's art (`GoSkin.widget_art`).
@export var art_name := &"":
	set(value):
		art_name = value
		queue_redraw()

## The picture itself — wins over `art_name`.
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()

## The button's diameter (dp).
@export_range(16, 512) var diameter := 92.0:
	set(value):
		diameter = maxf(16.0, value)
		custom_minimum_size = Vector2.ONE * diameter
		_fits.clear()
		queue_redraw()

## The name under the icon. Empty draws none.
@export var text := "":
	set(value):
		text = value
		queue_redraw()

## The name's size (dp); a long one shrinks to fit the button.
@export_range(6, 64) var font_size := 14:
	set(value):
		font_size = value
		_fits.clear()
		queue_redraw()

## The smallest the name shrinks to (dp).
@export_range(4, 64) var min_font_size := 10

## Room kept between the name and the rim on each side (dp).
@export_range(0, 64) var label_pad := 6.0

## Where the name's baseline sits below the centre, as a share of the radius.
@export_range(0.0, 1.5, 0.01) var label_rise := 0.8:
	set(value):
		label_rise = value
		queue_redraw()

## A small line under the name at rest (a hint such as "HOLD + DRAG"). Empty draws none.
@export var caption := "":
	set(value):
		caption = value
		_caption_sizes = [0, 0]
		queue_redraw()

## The caption while held, under the button. Empty draws none.
@export var held_caption := "":
	set(value):
		held_caption = value
		_caption_sizes = [0, 0]
		queue_redraw()

## The caption's size at rest / while held (dp); both shrink to fit (`GoStyle.fit_font_size`).
@export_range(6, 64) var caption_size := 11
@export_range(6, 64) var held_caption_size := 12

## How far below the rim the caption's baseline sits (dp).
@export_range(0, 128) var caption_drop := 28.0

## Hold and drag to aim: a ring and knob follow the thumb and `aimed` reports the pull.
@export var drag_aim := false

## The aim ring's radius (dp) — the pull is full here.
@export_range(8, 256) var aim_radius := 50.0
## The aim knob's radius (dp).
@export_range(4, 128) var aim_knob_radius := 24.0

## The press reaches this far past the rim (dp).
@export_range(0, 64) var hit_slop := 8.0

## A held button shrinks to this share.
@export_range(0.5, 1.0, 0.01) var press_scale := 0.93
## A held button is multiplied by this.
@export var press_tint := Color(0.82, 0.82, 0.86)
## A cooling button is multiplied by this.
@export var cooling_tint := Color(0.72, 0.72, 0.8)

## Recharging: the button dims and a ring shows `cooldown`. Turning it off pulses the button once.
@export var cooling := false:
	set(value):
		var was := cooling
		cooling = value
		if not value: cooldown = 0.0
		if was and not value: _ready_pulse()
		queue_redraw()

## The share of the wait still to run (0~1), drawn as an arc round the button while `cooling`.
@export_range(0.0, 1.0, 0.01) var cooldown := 0.0:
	set(value):
		cooldown = clampf(value, 0.0, 1.0)
		queue_redraw()

## The ready pulse's peak scale.
@export_range(1.0, 2.0, 0.01) var pulse_scale := 1.15

const RING_GAP := 7.0
const RING_POINTS := 48

var _finger := -1
var _held := false
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _pulse := 1.0
var _pulse_tween: Tween
var _fits := {}
var _caption_sizes: Array[int] = [0, 0]


## A button showing the skin's [param picture_name] art with [param label] under it, [param size] across.
static func make(picture_name: StringName, label := "", size := 92.0) -> GoTouchButton:
	var node := GoTouchButton.new()
	node.art_name = picture_name
	node.text = label
	node.diameter = size
	return node


func _init() -> void:
	name = "TouchButton"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2.ONE * diameter
	# 🛑 A thumb button is a physical place — it does not mirror for right-to-left languages.
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _enter_tree() -> void:
	# On every entry, so a button that was out of the tree during a look switch comes back on the current look.
	GoUi.watch(_restyle)
	theme = GoUi.theme()


func _ready() -> void:
	size = custom_minimum_size


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)
	# 🛑 A finger still down on a button that leaves the tree will never lift on it: let go now.
	cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED:
		_fits.clear()
		_caption_sizes = [0, 0]
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		# 🛑 Hidden under a finger (a pause menu hides the touch HUD): the lift will not reach it, so let go now —
		# `released(true)`, as `cancel()` says — rather than leave the game seeing it held for ever.
		cancel()


## The picture it draws (null: a plain disc).
func picture() -> Texture2D:
	if art != null: return art
	return GoUi.skin().widget_art(art_name) if not art_name.is_empty() else null


## Whether a finger holds it.
func is_held() -> bool:
	return _held


## With `drag_aim`: the pull now, length 0~1.
func aim() -> Vector2:
	return (_knob - _base) / aim_radius if _held and drag_aim else Vector2.ZERO


## With `drag_aim`: where the knob is drawn (local).
func knob() -> Vector2:
	return _knob


## The radius it is drawn at now (the pulse and the press included).
func radius() -> float:
	return diameter / 2.0 * _pulse * (press_scale if _held else 1.0)


## The ready pulse's scale now (1 at rest).
func pulse() -> float:
	return _pulse


## The tint before the press: `cooling_tint` while cooling, else white.
func tint() -> Color:
	return cooling_tint if cooling else Color.WHITE


## Lets go without a lift (focus lost, the screen changed): `released(true)`.
func cancel() -> void:
	if _held: _release(true)


## The name's size: `font_size`, shrunk until it fits the button less `label_pad` each side, never under `min_font_size`.
func label_font_size() -> int:
	if _fits.has(text): return _fits[text]
	var font := _font()
	var fs := font_size
	var room := diameter - label_pad * 2.0
	while font != null and fs > min_font_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	_fits.clear()   # only the last text is kept: a label that counts down must not grow this every frame
	_fits[text] = fs
	return fs


## The caption's size at rest ([param held] false) or while held, shrunk to fit like the name.
func caption_font_size(held: bool) -> int:
	var index := 1 if held else 0
	if _caption_sizes[index] == 0:
		var line := held_caption if held else caption
		var base := held_caption_size if held else caption_size
		_caption_sizes[index] = GoStyle.fit_font_size(PackedStringArray([line]), base, diameter - label_pad * 2.0, _font())
	return _caption_sizes[index]


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= diameter / 2.0 + hit_slop


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger < 0:
			_finger = event.index
			_press(event.position)
			accept_event()
		elif not event.pressed and event.index == _finger:
			_release(false)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger:
		_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# The mouse is taken as well, so it can be tried on the desktop.
		if event.pressed and _finger < 0:
			_finger = -2
			_press(event.position)
			accept_event()
		elif not event.pressed and _finger == -2:
			_release(false)
			accept_event()
	elif event is InputEventMouseMotion and _finger == -2:
		_drag(event.position)
		accept_event()


func _press(point: Vector2) -> void:
	_held = true
	_base = point
	_knob = point
	pressed_down.emit()
	queue_redraw()


func _drag(point: Vector2) -> void:
	if not _held or not drag_aim: return
	_knob = _base + (point - _base).limit_length(aim_radius)
	aimed.emit(aim())
	queue_redraw()


func _release(canceled: bool) -> void:
	_finger = -1
	_held = false
	_knob = _base
	released.emit(canceled)
	queue_redraw()


func _ready_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_pulse = 1.0
	if not is_inside_tree() or GoUi.config.reduce_motion: return
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse, 1.0, pulse_scale, 0.14).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_set_pulse, pulse_scale, 1.0, 0.21).set_ease(Tween.EASE_OUT)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _restyle() -> void:
	theme = GoUi.theme()
	_fits.clear()
	_caption_sizes = [0, 0]
	queue_redraw()


func _font() -> Font:
	return get_theme_font(&"font", &"Label")


func _draw() -> void:
	var skin := GoUi.skin()
	var c := size / 2.0
	var r0 := diameter / 2.0
	if cooling:
		var ring := r0 * _pulse + RING_GAP
		draw_arc(c, ring, 0.0, TAU, RING_POINTS, Color(0.0, 0.0, 0.0, 0.45), 9.0, true)
		if cooldown > 0.0:
			draw_arc(c, ring, -PI / 2.0, -PI / 2.0 + TAU * cooldown, RING_POINTS, skin.touch_cooldown_ink(), 5.0, true)
	var r := radius()
	var shade := tint() * press_tint if _held else tint()
	var face := picture()
	if face != null:
		skin.draw_touch_sprite(self, face, c, r, shade, true)
	else:
		draw_circle(c + Vector2(0.0, 4.0), r, Color(skin.touch_shadow_ink(), 0.35 * shade.a))
		draw_circle(c, r, GoUi.color(GoTheme.ACCENT) * shade, true, -1.0, true)
	if _held and drag_aim:
		draw_circle(_base, aim_radius, Color(1.0, 1.0, 1.0, 0.22))
		draw_arc(_base, aim_radius, 0.0, TAU, RING_POINTS, Color(skin.touch_outline_ink(), 0.9), 3.0, true)
		var cap := skin.joystick_art(true)
		if cap != null:
			skin.draw_touch_sprite(self, cap, _knob, aim_knob_radius, Color.WHITE, true)
		else:
			draw_circle(_knob + Vector2(0.0, 4.0), aim_knob_radius, Color(skin.touch_shadow_ink(), 0.35))
			draw_circle(_knob, aim_knob_radius, Color.WHITE, true, -1.0, true)
		if not held_caption.is_empty():
			_label(held_caption, c + Vector2(-r0, r0 + caption_drop), r0 * 2.0, caption_font_size(true))
		return
	if not text.is_empty():
		_label(text, c + Vector2(-r, r * label_rise), r * 2.0, label_font_size())
	if not caption.is_empty():
		_label(caption, c + Vector2(-r0, r0 + caption_drop), r0 * 2.0, caption_font_size(false))


## White text over the skin's edge, centred in [param width] from [param at] (the baseline's left end).
func _label(line: String, at: Vector2, width: float, fs: int) -> void:
	var font := _font()
	if font == null: return
	draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_CENTER, width, fs, 5, GoUi.skin().touch_outline_ink())
	draw_string(font, at, line, HORIZONTAL_ALIGNMENT_CENTER, width, fs, Color.WHITE)
