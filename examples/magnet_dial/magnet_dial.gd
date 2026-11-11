## 🧲 **The magnet dial, played by hand** — a desktop match HUD made of `GoMagnetDial`, `GoItemBox`, two `GoActionKey`s
## and a `GoBar`, with every event on a key so each animation can be watched on its own:
##
## ```
## godot res://addons/gohud/examples/magnet_dial/magnet_dial.tscn
## ```
##
## | Key | Event | What plays |
## |---|---|---|
## | hold `A` | attract held / let go | the blue half lights, arrows flow in, the ring glows; then it settles; power drains |
## | `R` | repulse — fired, cooling, ready; pressed again while cooling: denied | kick + shockwave, the red refill, the flash and pop; the shake |
## | `L` | power low (press again: empty, again: full) | the ring pulses in the alert ink; one flash, then the dial dims |
## | `M` | SUPER MAGNET on / off | the gold rim |
## | `P` | power-up gained (banana ×2 → reflect → bomb → super magnet) | the box pops in, sparkles, the name tab slides up |
## | `U` | power-up used | the punch and the badge bump; a timed one drains its edge; a bomb's fuse ticks; the last one shrinks out |
## | `J` | jump | the cap dips, the cover sweeps for 2 s, the cap pops |
## | hold `S` | sprint | the cap stays down and lit |
## | `H` | stability hit (it goes low under 25) | the bar flashes and shakes by the loss; low, it pulses in the alert ink |
## | `X` | eliminated / back | the dial powers down, and up again |
## | `E` | match start | the dial, the item box and the caps pop in, one after the other |
## | `T` | reduce motion on / off | every event above then only changes state |
##
## 🔑 The scene only feeds values in (`set_power`, `set_cooldown`, `set_item`, …) — the parts start their own motions
##    from the change, which is all a game's HUD has to do each frame.
extends Control

const REPULSE_SECONDS := 2.0
const JUMP_SECONDS := 2.0
const REFLECT_SECONDS := 6.0
const BOMB_SECONDS := 3.0
## The power-ups `P` hands out in turn: art name, shown name, charges.
const ITEMS: Array = [
	[&"powerup_banana", "BANANA", 2],
	[&"powerup_reflect", "REFLECT", 1],
	[&"powerup_bomb", "BOMB", 1],
	[&"powerup_super_magnet", "SUPER MAGNET", 1],
]

var dial: GoMagnetDial
var box: GoItemBox
var jump: GoActionKey
var sprint: GoActionKey
var stability: GoBar
## The last event played, in words — a test and a viewer read the same line.
var last_event := ""

var _log: Label
var _power := 1.0
var _attracting := false
var _repulse_left := 0.0
var _jump_left := 0.0
var _stability := 100.0
var _next_item := 0
var _item := -1
var _charges := 0
var _timer_left := 0.0
var _fuse_left := 0.0
var _alive := true
var _low_step := 0


func _ready() -> void:
	name = "MagnetDial"
	# Keep a look picked elsewhere (the preview launcher's `--preset`); otherwise show the look the art is painted for.
	if GoUi.config.preset.is_empty():
		GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	var background := ColorRect.new()
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_log = GoStyle.label("")
	_log.name = "Log"
	_log.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_log.position = Vector2(20.0, 16.0)
	add_child(_log)

	# Bottom right: the dial, the item box on its upper-left shoulder.
	var corner := HBoxContainer.new()
	corner.name = "Corner"
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.add_theme_constant_override(&"separation", 0)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -20.0
	corner.offset_bottom = -16.0
	add_child(corner)
	box = GoItemBox.make()
	box.name = "ItemBox"
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.set_key("F")
	corner.add_child(box)
	dial = GoMagnetDial.make()
	dial.name = "Dial"
	dial.set_mouse(GoMagnetDial.Half.ATTRACT, MOUSE_BUTTON_LEFT)
	dial.set_mouse(GoMagnetDial.Half.REPULSE, MOUSE_BUTTON_RIGHT)
	corner.add_child(dial)

	# Bottom centre: the two key hints.
	var keys := HBoxContainer.new()
	keys.name = "Keys"
	keys.add_theme_constant_override(&"separation", 22)
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.grow_horizontal = Control.GROW_DIRECTION_BOTH
	keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	keys.offset_bottom = -20.0
	add_child(keys)
	jump = GoActionKey.make("JUMP", "Space")
	jump.name = "Jump"
	keys.add_child(jump)
	sprint = GoActionKey.make("SPRINT", "Shift")
	sprint.name = "Sprint"
	keys.add_child(sprint)

	# Bottom left: stability.
	stability = GoBar.new()
	stability.name = "Stability"
	stability.label_text = "STABILITY"
	stability.icon = GoUi.icons().texture(GoIconSet.SHIELD)
	stability.custom_minimum_size = Vector2(260.0, 0.0)
	stability.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stability.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stability.offset_left = 20.0
	stability.offset_bottom = -22.0
	add_child(stability)
	stability.set_values(_stability, 100.0, false)
	dial.set_power(_power, false)
	_say("E — match start")
	_enter()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo: return
	if key.keycode == KEY_A:
		hold_attract(key.pressed)
	elif key.keycode == KEY_S:
		hold_sprint(key.pressed)
	elif key.pressed:
		play(key.keycode)


## Plays the event on [param keycode] (the table above); false for a key that has none.
func play(keycode: Key) -> bool:
	match keycode:
		KEY_R: repulse()
		KEY_L: step_power()
		KEY_M: toggle_super()
		KEY_P: gain()
		KEY_U: use()
		KEY_J: do_jump()
		KEY_H: hit()
		KEY_X: toggle_alive()
		KEY_E:
			_say("E — match start")
			_enter()
		KEY_T:
			GoUi.config.reduce_motion = not GoUi.config.reduce_motion
			GoUi.refresh()
			_say("T — reduce motion %s" % ("on" if GoUi.config.reduce_motion else "off"))
		_: return false
	return true


func hold_attract(on: bool) -> void:
	if not _alive or _attracting == on: return
	_attracting = on
	dial.set_attracting(on)
	_say("A — attract %s" % ("held" if on else "let go"))


func hold_sprint(on: bool) -> void:
	sprint.set_held(on)
	_say("S — sprint %s" % ("held" if on else "let go"))


func repulse() -> void:
	if not _alive: return
	if _repulse_left > 0.0:
		dial.deny()
		_say("R — repulse while cooling: denied")
		return
	_repulse_left = REPULSE_SECONDS
	dial.set_cooldown(_repulse_left, REPULSE_SECONDS)
	_say("R — repulse fired")


func step_power() -> void:
	_low_step = (_low_step + 1) % 3
	_power = [1.0, 0.14, 0.0][_low_step]
	dial.set_power(_power)
	_say("L — power %s" % ["full", "low", "empty"][_low_step])


func toggle_super() -> void:
	dial.set_super(not dial.is_super())
	_say("M — SUPER MAGNET %s" % ("on" if dial.is_super() else "off"))


func gain() -> void:
	_item = _next_item
	_next_item = (_next_item + 1) % ITEMS.size()
	var item: Array = ITEMS[_item]
	_charges = item[2]
	_timer_left = 0.0
	_fuse_left = 0.0
	box.set_timer(0.0, 0.0)
	box.set_fuse(0.0, 0.0)
	box.set_active(false)
	# A look without painted power-ups still shows something in the box: an icon of its own set.
	var art := GoUi.skin().widget_art(item[0])
	box.set_item(art if art != null else GoUi.icons().texture(GoIconSet.STAR), item[1])
	box.set_charges(_charges)
	_say("P — gained %s" % item[1])


func use() -> void:
	if _item < 0 or _timer_left > 0.0 or _fuse_left > 0.0: return
	var item: Array = ITEMS[_item]
	match item[0]:
		&"powerup_reflect":
			_timer_left = REFLECT_SECONDS
			box.set_active(true)
			box.set_timer(_timer_left, REFLECT_SECONDS)
			_say("U — REFLECT running")
		&"powerup_bomb":
			_fuse_left = BOMB_SECONDS
			box.set_fuse(_fuse_left, BOMB_SECONDS)
			_say("U — BOMB lit")
		&"powerup_super_magnet":
			dial.set_super(true)
			_drop()
			_say("U — SUPER MAGNET used")
		_:
			_charges -= 1
			if _charges <= 0:
				_drop()
				_say("U — last %s used" % item[1])
			else:
				box.set_charges(_charges)
				_say("U — %s used, %d left" % [item[1], _charges])


func do_jump() -> void:
	if not _alive or _jump_left > 0.0: return
	_jump_left = JUMP_SECONDS
	jump.set_cooldown(_jump_left, JUMP_SECONDS)
	_say("J — jump")


func hit() -> void:
	var before := _stability
	_stability = 100.0 if _stability <= 10.0 else maxf(0.0, _stability - 30.0)
	stability.set_values(_stability, 100.0)
	if _stability < before: stability.hit((before - _stability) / 100.0)
	stability.alert = _stability < 25.0
	_say("H — stability %d" % roundi(_stability))


func toggle_alive() -> void:
	_alive = not _alive
	if not _alive:
		_attracting = false
		dial.set_attracting(false)
	dial.set_powered(_alive)
	_say("X — %s" % ("back in the match" if _alive else "eliminated"))


func _enter() -> void:
	dial.enter(0.0)
	box.enter(0.08)
	jump.enter(0.16)
	sprint.enter(0.22)


func _drop() -> void:
	_item = -1
	_charges = 0
	box.set_active(false)
	box.clear()


func _process(delta: float) -> void:
	if _attracting and _low_step == 0:
		_power = maxf(0.0, _power - delta * 0.25)
		dial.set_power(_power)
	elif _low_step == 0 and _power < 1.0:
		_power = minf(1.0, _power + delta * 0.18)
		dial.set_power(_power)
	if _repulse_left > 0.0:
		_repulse_left = maxf(0.0, _repulse_left - delta)
		dial.set_cooldown(_repulse_left, REPULSE_SECONDS)
	if _jump_left > 0.0:
		_jump_left = maxf(0.0, _jump_left - delta)
		jump.set_cooldown(_jump_left, JUMP_SECONDS)
	if _timer_left > 0.0:
		_timer_left = maxf(0.0, _timer_left - delta)
		box.set_timer(_timer_left, REFLECT_SECONDS)
		if _timer_left <= 0.0: _drop()
	if _fuse_left > 0.0:
		_fuse_left = maxf(0.0, _fuse_left - delta)
		box.set_fuse(_fuse_left, BOMB_SECONDS)
		if _fuse_left <= 0.0: _drop()


func _say(event: String) -> void:
	last_event = event
	_log.text = "hold A attract · R repulse · L power low/empty/full · M super · P gain · U use · J jump · hold S sprint\n" \
		+ "H stability hit · X eliminated · E match start · T reduce motion          last: " + event
