## 🧪 **Checks for the magnet dial and the parts beside it** — `GoMotion` (the motion clock), `GoMagnetDial`, and as
## they land the item box, the action keys and the bar's hit. Every event is fed in and its motion is read back — once
## with motion on (it plays, it ends) and once under `GoConfig.reduce_motion` (the state changes, nothing plays).
## Each runs in arcade_light (the painted art) and in a plain look (the drawn fallbacks: no art, no errors).
## 🛑 These widgets show what they are given and decide nothing — the checks feed them values and read the display.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_magnet_dial_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const HUD := "res://addons/gohud/assets/arcade_light/hud/"
const DIAL_ART := ["dial_attract", "dial_repulse", "dial_off", "dial_arrow", "mouse_left", "mouse_right"]

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	_motion()
	for look: StringName in [GoThemePresets.ARCADE_LIGHT, GoThemePresets.DEFAULT_DARK]:
		GoUi.use_preset(look)
		GoUi.config.reduce_motion = false
		await frames(1)
		await _dial_builds(look)
		await _dial_power(look)
		await _dial_attract(look)
		await _dial_repulse(look)
		await _dial_super_enter_power_down(look)
		await _dial_keys(look)
		await _dial_reduced(look)
		await _dial_idle_costs_nothing(look)
		await _item_box_states(look)
		await _item_box_motion(look)
		await _item_box_reduced(look)
		await _action_key(look)
		await _bar_hit_and_alert(look)
		await _example_plays_every_event(look)
		await _last_sliver_still_ends(look)
	GoUi.reset()
	print("gohud magnet dial tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func _host(node: Control) -> Control:
	var holder := Control.new()
	holder.size = Vector2(400, 400)
	root.add_child(holder)
	holder.add_child(node)
	return holder


func _dial() -> GoMagnetDial:
	var dial := GoMagnetDial.make(176.0)
	dial.ring_ink = Color("#1fb5f0")
	dial.ring_ink_end = Color("#6ff0ff")
	return dial


## Steps a widget's clock for [param seconds] in 1/60 s frames.
func _run(widget: Object, seconds: float) -> void:
	for i in ceili(seconds * 60.0): widget.call(&"advance", 1.0 / 60.0)


# ── GoMotion ──────────────────────────────────────────────────────────

func _motion() -> void:
	GoUi.config.reduce_motion = false
	var m := GoMotion.new()
	check(not m.busy() and m.at(&"x") == 0.0 and m.at(&"x", 1.0) == 1.0, "motion: an idle track answers its idle value")
	check(m.play(&"x", 0.5) and m.playing(&"x") and m.busy(), "motion: play starts a track")
	m.advance(0.25)
	check(is_equal_approx(m.at(&"x"), 0.5), "motion: half the time is half the way")
	check(not m.advance(0.3) and not m.playing(&"x"), "motion: a one-shot ends and is dropped")
	m.play(&"late", 0.2, 0.1)
	m.advance(0.05)
	check(m.playing(&"late") and m.at(&"late") == 0.0, "motion: a delayed track waits at 0")
	m.advance(0.15)
	check(is_equal_approx(m.at(&"late"), 0.5), "motion: after its delay it runs")
	m.stop_all()
	m.loop(&"round", 0.4)
	m.advance(0.5)
	check(m.playing(&"round") and is_equal_approx(m.at(&"round"), 0.25), "motion: a loop wraps round")
	m.loop(&"round", 0.4)
	check(is_equal_approx(m.at(&"round"), 0.25), "motion: looping it again keeps its phase")
	m.stop(&"round")
	check(not m.busy(), "motion: stop ends a loop")
	check(is_zero_approx(GoMotion.punch(0.0)) and is_equal_approx(GoMotion.punch(0.5), 1.0)
		and is_zero_approx(GoMotion.punch(1.0)), "motion: punch goes out and back")
	check(is_equal_approx(GoMotion.overshoot(1.0), 1.0) and GoMotion.overshoot(0.7) > 1.0, "motion: overshoot passes 1 and lands on it")
	check(is_zero_approx(GoMotion.shake(1.0)) and absf(GoMotion.shake(0.1)) > 0.0, "motion: shake dies away")
	GoUi.config.reduce_motion = true
	check(not m.play(&"x", 0.5) and not m.loop(&"y", 0.5) and not m.busy(), "motion: reduce_motion plays nothing")
	GoUi.config.reduce_motion = false


# ── GoMagnetDial ──────────────────────────────────────────────────────

func _dial_builds(look: StringName) -> void:
	var dial := _dial()
	var holder := _host(dial)
	await frames(2)
	check(dial.get_combined_minimum_size().x == 176.0 and dial.get_combined_minimum_size().y >= 176.0,
		"%s dial: it asks for its diameter" % look)
	check(dial.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s dial: it takes no mouse" % look)
	check(dial.layout_direction == Control.LAYOUT_DIRECTION_LTR, "%s dial: its halves never mirror" % look)
	var bare := dial.get_combined_minimum_size().y
	dial.caption = "MAGNET"
	check(dial.get_combined_minimum_size().y > bare, "%s dial: a caption takes room over it" % look)
	if look == GoThemePresets.ARCADE_LIGHT:
		for art: String in DIAL_ART:
			check(GoUi.skin().widget_art(StringName(art)) == load(HUD + art + ".png"), "arcade_light ships the dial's '%s'" % art)
	else:
		check(GoUi.skin().widget_art(&"dial_attract") == null, "%s dial: no art, it draws its own halves" % look)
	dial.set_power(0.5, false)
	dial.set_cooldown(1.0, 2.0)
	dial.set_attracting(true)
	dial.set_super(true)
	await frames(3)
	check(true, "%s dial: every state draws without an error" % look)
	holder.queue_free()
	await frames(1)


func _dial_power(look: StringName) -> void:
	var dial := _dial()
	dial.low_ratio = 0.25
	var holder := _host(dial)
	await frames(1)
	dial.set_process(false)
	dial.set_power(1.0, false)
	check(dial.shown_power() == 1.0 and not dial.moving(), "%s dial: a value set without motion is shown at once" % look)
	# 7 — drains / regens: the ring eases, a drop shows the head.
	dial.set_power(0.6)
	check(dial.shown_power() == 1.0 and dial.moving(), "%s dial: a new power starts the ring moving" % look)
	check(dial._head > 0.0, "%s dial: a drop lights the head on the arc" % look)
	_run(dial, 0.1)
	check(dial.shown_power() < 1.0 and dial.shown_power() > 0.6, "%s dial: the ring is on its way" % look)
	_run(dial, 1.0)
	check(is_equal_approx(dial.shown_power(), 0.6) and dial._head == 0.0 and not dial.moving(),
		"%s dial: the ring arrives, the head goes out and the dial rests" % look)
	dial.set_power(0.8)
	check(dial._head == 0.0, "%s dial: a regen shows no head" % look)
	_run(dial, 1.0)
	# 8 — low: the ring pulses in the alert ink.
	check(not dial.low() and dial.alert_amount() == 0.0, "%s dial: above the threshold the ring does not warn" % look)
	dial.set_power(0.2)
	check(dial.low() and dial.motion.playing(&"low"), "%s dial: at low power the ring's warning pulse runs" % look)
	var seen_low := 0.0
	var seen_high := 0.0
	for i in 60:
		dial.advance(1.0 / 60.0)
		seen_low = minf(seen_low, dial.alert_amount()) if i > 0 else dial.alert_amount()
		seen_high = maxf(seen_high, dial.alert_amount())
	check(seen_high > 0.9 and seen_low < 0.1, "%s dial: the warning pulses between its ink and the alert ink" % look)
	# 9 — empty: one flash, then dim until power returns.
	dial.set_power(0.0)
	check(dial.dimmed() and dial.motion.playing(&"empty") and not dial.low(), "%s dial: out of power it flashes once and dims" % look)
	_run(dial, 0.2)
	check(dial.alert_amount() > 0.5, "%s dial: the flash is in the alert ink" % look)
	_run(dial, 1.0)
	check(dial.dimmed() and not dial.motion.playing(&"empty") and not dial.moving(), "%s dial: the flash ends, the dial stays dim" % look)
	dial.set_power(0.5)
	check(not dial.dimmed(), "%s dial: power back, the dial is lit again" % look)
	dial.low_ratio = 0.0
	dial.set_power(0.05, false)
	check(not dial.low(), "%s dial: low_ratio 0 never warns" % look)
	holder.queue_free()
	await frames(1)


func _dial_attract(look: StringName) -> void:
	var dial := _dial()
	var holder := _host(dial)
	await frames(1)
	dial.set_process(false)
	check(dial.lit_amount() == 0.0 and dial.half_scale(GoMagnetDial.Half.ATTRACT) == 1.0 and not dial.flowing(),
		"%s dial: at rest the ATTRACT half is plain" % look)
	# 1 — attract starts: lights, arrows flow, ring glows.
	dial.set_attracting(true)
	check(dial.attracting() and dial.flowing() and dial.motion.playing(&"light"), "%s dial: holding ATTRACT starts the arrows" % look)
	_run(dial, 0.5)
	check(is_equal_approx(dial.lit_amount(), 1.0) and dial.half_scale(GoMagnetDial.Half.ATTRACT) > 1.0,
		"%s dial: the held half is lit and a touch bigger" % look)
	check(dial.flowing() and dial.moving(), "%s dial: the arrows keep flowing while it is held" % look)
	# 2 — attract ends: arrows stop, the half eases back.
	dial.set_attracting(false)
	check(not dial.flowing() and dial.motion.playing(&"settle"), "%s dial: letting go stops the arrows and starts the settle" % look)
	_run(dial, 0.05)
	check(dial.lit_amount() > 0.0 and dial.lit_amount() < 1.0, "%s dial: the half eases back, it does not snap" % look)
	_run(dial, 0.5)
	check(dial.lit_amount() == 0.0 and not dial.moving(), "%s dial: settled, the dial rests" % look)
	holder.queue_free()
	await frames(1)


func _dial_repulse(look: StringName) -> void:
	var dial := _dial()
	var holder := _host(dial)
	await frames(1)
	dial.set_process(false)
	var side := GoMagnetDial.Half.REPULSE
	check(not dial.cooling() and dial.refill() == 1.0 and dial.cooldown_text() == "", "%s dial: REPULSE starts ready" % look)
	dial.deny()
	check(not dial.motion.playing(&"deny"), "%s dial: a ready REPULSE has nothing to deny" % look)
	# 3 — fired: kick, shock ring, grey.
	dial.set_cooldown(2.0, 2.0)
	check(dial.cooling() and dial.motion.playing(&"fire"), "%s dial: a cooldown that starts is a shot fired" % look)
	check(dial.refill() == 0.0 and dial.cooldown_text() == "2.0", "%s dial: the fired half is empty and reads 2.0" % look)
	_run(dial, 0.2)
	check(dial.half_scale(side) > 1.05, "%s dial: the fired half kicks outward" % look)
	check(dial.shock_radius() > 88.0, "%s dial: a shock ring leaves the dial" % look)
	_run(dial, 0.4)
	check(not dial.motion.playing(&"fire") and dial.half_scale(side) == 1.0 and dial.shock_radius() == 0.0,
		"%s dial: the kick and the ring end" % look)
	# 4 — cooling: the refill rises smoothly between 0.1 s values.
	dial.set_cooldown(1.4, 2.0)
	var before := dial.refill()
	dial.advance(1.0 / 60.0)
	var after := dial.refill()
	check(after > before and after - before < 0.02, "%s dial: the refill moves a frame's worth, not a step" % look)
	_run(dial, 0.5)
	check(dial.refill() <= (2.0 - 1.3) / 2.0 + 0.001, "%s dial: it never runs more than a tenth ahead of its value" % look)
	check(dial.cooldown_text() == "1.4", "%s dial: the seconds are the value it was given" % look)
	dial.set_cooldown(0.31, 2.0)
	check(dial.cooldown_text() == "0.4", "%s dial: the seconds round up, so 0.0 is never shown while it waits" % look)
	check(is_equal_approx(dial.refill(), 1.0 - 0.31 / 2.0), "%s dial: a jump in the value is followed at once" % look)
	# 6 — pressed while cooling: the deny shake.
	dial.deny()
	check(dial.motion.playing(&"deny"), "%s dial: pressing a cooling REPULSE starts the shake" % look)
	var swing := 0.0
	for i in 12:
		dial.advance(1.0 / 60.0)
		swing = maxf(swing, absf(dial.shake_offset()))
	check(swing > 2.0, "%s dial: the half swings sideways" % look)
	_run(dial, 0.3)
	check(dial.shake_offset() == 0.0 and not dial.motion.playing(&"deny"), "%s dial: the shake ends at rest" % look)
	# 5 — ready again: flash, pop, ring pulse.
	dial.set_cooldown(0.0, 2.0)
	check(not dial.cooling() and dial.motion.playing(&"ready"), "%s dial: the cooldown ending is READY" % look)
	check(dial.refill() == 1.0 and dial.cooldown_text() == "", "%s dial: the ready half is full and shows no seconds" % look)
	check(dial.flash_amount() > 0.9, "%s dial: READY starts with a white flash" % look)
	_run(dial, 0.25)
	check(dial.half_scale(side) > 1.05, "%s dial: the ready half pops" % look)
	_run(dial, 0.5)
	check(dial.flash_amount() == 0.0 and dial.half_scale(side) == 1.0 and not dial.moving(), "%s dial: the READY motion ends and the dial rests" % look)
	holder.queue_free()
	await frames(1)


func _dial_super_enter_power_down(look: StringName) -> void:
	var dial := _dial()
	var holder := _host(dial)
	await frames(1)
	dial.set_process(false)
	# 10 — SUPER MAGNET: a gold rim that glows.
	dial.set_super(true)
	check(dial.is_super() and dial.motion.playing(&"super"), "%s dial: the boost's rim glows" % look)
	dial.set_super(false)
	check(not dial.is_super() and not dial.motion.playing(&"super") and not dial.moving(), "%s dial: the boost over, the rim is gone" % look)
	# 20 — match start: the pop, after its delay.
	dial.enter(0.1)
	check(dial.dial_scale() == 0.0, "%s dial: before its turn the entering dial is not shown" % look)
	_run(dial, 0.1 + GoMagnetDial.ENTER_SECONDS * 0.75)
	check(dial.dial_scale() > 1.0, "%s dial: the entrance overshoots" % look)
	_run(dial, 0.3)
	check(dial.dial_scale() == 1.0 and not dial.moving(), "%s dial: it lands at its size" % look)
	# 21 — eliminated: grey and smaller.
	dial.set_powered(false)
	check(not dial.powered() and dial.motion.playing(&"power_down"), "%s dial: powering down plays" % look)
	_run(dial, 0.1)
	check(dial.off_amount() > 0.0 and dial.off_amount() < 1.0, "%s dial: it eases off" % look)
	_run(dial, 0.4)
	check(dial.off_amount() == 1.0 and is_equal_approx(dial.dial_scale(), GoMagnetDial.OFF_SCALE) and not dial.moving(),
		"%s dial: off, it is grey, smaller and still" % look)
	dial.set_powered(true)
	_run(dial, 0.5)
	check(dial.off_amount() == 0.0 and dial.dial_scale() == 1.0, "%s dial: powered again, it is back" % look)
	holder.queue_free()
	await frames(1)


func _dial_keys(look: StringName) -> void:
	var dial := _dial()
	var holder := _host(dial)
	await frames(1)
	var a := GoMagnetDial.Half.ATTRACT
	var r := GoMagnetDial.Half.REPULSE
	dial.set_key(a, "Q")
	check(dial.key_text(a) == "Q" and dial.mouse_button(a) == MOUSE_BUTTON_NONE, "%s dial: a key cap names the key" % look)
	dial.set_mouse(a, MOUSE_BUTTON_LEFT)
	check(dial.mouse_button(a) == MOUSE_BUTTON_LEFT and dial.key_text(a) == "", "%s dial: a mouse glyph replaces the cap" % look)
	var mouse_only := dial.get_combined_minimum_size().y
	dial.set_mouse(a, MOUSE_BUTTON_LEFT, "J")
	check(dial.mouse_button(a) == MOUSE_BUTTON_LEFT and dial.key_text(a) == "J", "%s dial: a mouse names the key that does the same" % look)
	check(dial.get_combined_minimum_size().y > mouse_only, "%s dial: the cap under a mouse takes room at the foot" % look)
	dial.set_key(a, "Q")
	check(dial.mouse_button(a) == MOUSE_BUTTON_NONE and is_equal_approx(dial.get_combined_minimum_size().y, mouse_only),
		"%s dial: a key cap alone gives that room back" % look)
	dial.set_mouse(a, MOUSE_BUTTON_LEFT, "J")
	dial.set_mouse(a, MOUSE_BUTTON_LEFT)
	check(dial.key_text(a) == "" and is_equal_approx(dial.get_combined_minimum_size().y, mouse_only),
		"%s dial: a mouse without a key drops the cap" % look)
	InputMap.add_action(&"_dial_click")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event(&"_dial_click", click)
	InputMap.add_action(&"_dial_key")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	InputMap.action_add_event(&"_dial_key", key)
	InputMap.action_add_event(&"_dial_key", click)
	dial.set_action(r, &"_dial_click")
	check(dial.mouse_button(r) == MOUSE_BUTTON_RIGHT, "%s dial: a mouse bind is read out of InputMap" % look)
	dial.set_action(r, &"_dial_key")
	check(dial.key_text(r) == "E" and dial.mouse_button(r) == MOUSE_BUTTON_NONE, "%s dial: a key bind is read out of InputMap" % look)
	dial.set_action(r, &"_dial_key", true)
	check(dial.mouse_button(r) == MOUSE_BUTTON_RIGHT, "%s dial: prefer_mouse takes the mouse bind of an action with both" % look)
	dial.set_action(r, &"_dial_no_such_action")
	check(dial.key_text(r) == "" and dial.mouse_button(r) == MOUSE_BUTTON_NONE, "%s dial: an unbound action shows no key" % look)
	InputMap.erase_action(&"_dial_click")
	InputMap.erase_action(&"_dial_key")
	await frames(2)
	holder.queue_free()
	await frames(1)


## Under reduce_motion every event changes the state and nothing plays.
func _dial_reduced(look: StringName) -> void:
	GoUi.config.reduce_motion = true
	var dial := _dial()
	var holder := _host(dial)
	await frames(1)
	var r := GoMagnetDial.Half.REPULSE
	dial.set_power(0.5)
	check(dial.shown_power() == 0.5 and dial._head == 0.0, "%s dial (reduced): power is shown at once, no head" % look)
	dial.set_attracting(true)
	check(dial.lit_amount() == 1.0 and not dial.flowing() and dial.half_scale(GoMagnetDial.Half.ATTRACT) > 1.0,
		"%s dial (reduced): the held half is lit, no arrows flow" % look)
	dial.set_attracting(false)
	check(dial.lit_amount() == 0.0, "%s dial (reduced): let go, it is plain at once" % look)
	dial.set_cooldown(2.0, 2.0)
	check(dial.cooling() and dial.half_scale(r) == 1.0 and dial.shock_radius() == 0.0, "%s dial (reduced): fired is grey, no kick, no ring" % look)
	dial.set_cooldown(1.5, 2.0)
	check(is_equal_approx(dial.refill(), 0.25), "%s dial (reduced): the refill steps with its value" % look)
	dial.deny()
	check(dial.shake_offset() == 0.0, "%s dial (reduced): no shake" % look)
	dial.set_cooldown(0.0, 2.0)
	check(not dial.cooling() and dial.flash_amount() == 0.0 and dial.half_scale(r) == 1.0, "%s dial (reduced): ready, no flash, no pop" % look)
	dial.set_power(0.1)
	check(dial.low() and dial.alert_amount() == 1.0 and not dial.motion.busy(), "%s dial (reduced): low power is the alert ink, steady" % look)
	dial.set_power(0.0)
	check(dial.dimmed() and dial.alert_amount() == 0.0, "%s dial (reduced): empty is dim, no flash" % look)
	dial.set_super(true)
	check(dial.is_super() and not dial.motion.busy(), "%s dial (reduced): the gold rim is steady" % look)
	dial.enter(0.2)
	check(dial.dial_scale() == 1.0, "%s dial (reduced): it enters in place" % look)
	dial.set_powered(false)
	check(dial.off_amount() == 1.0 and not dial.moving(), "%s dial (reduced): powered down at once, nothing moves" % look)
	await frames(2)
	check(not dial.is_processing(), "%s dial (reduced): it never processes" % look)
	holder.queue_free()
	await frames(1)
	GoUi.config.reduce_motion = false


## A dial with nothing to move does not process; one that moves does, and stops by itself.
func _dial_idle_costs_nothing(look: StringName) -> void:
	var dial := _dial()
	var holder := _host(dial)
	await frames(2)
	check(not dial.is_processing(), "%s dial: at rest it does not process" % look)
	dial.set_power(0.4)
	check(dial.is_processing(), "%s dial: a change wakes it" % look)
	dial.set_power(0.4)
	for i in 120:
		await process_frame
		if not dial.is_processing(): break
	check(not dial.is_processing() and is_equal_approx(dial.shown_power(), 0.4), "%s dial: it goes back to rest by itself" % look)
	holder.queue_free()
	await frames(1)


# ── GoItemBox ─────────────────────────────────────────────────────────

func _picture() -> Texture2D:
	var art := GoUi.skin().widget_art(&"powerup_banana")
	if art != null: return art
	var stand_in := GradientTexture2D.new()
	stand_in.width = 16
	stand_in.height = 16
	return stand_in


func _item_box_states(look: StringName) -> void:
	GoUi.config.reduce_motion = true
	var box := GoItemBox.make(66.0)
	var holder := _host(box)
	await frames(2)
	check(box.get_combined_minimum_size().x >= 66.0 and box.get_combined_minimum_size().y > 66.0,
		"%s item box: it asks for the box, its tab and its key" % look)
	check(box.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s item box: it takes no mouse" % look)
	check(not box.held() and box.icon_scale() == 0.0 and box.tab_amount() == 0.0, "%s item box: it starts empty" % look)
	if look == GoThemePresets.ARCADE_LIGHT:
		for art: String in ["item_box", "item_box_empty", "powerup_super_magnet"]:
			check(GoUi.skin().widget_art(StringName(art)) == load(HUD + art + ".png"), "arcade_light ships '%s'" % art)
	box.set_key("F")
	check(box.key_text() == "F", "%s item box: the key cap names the key" % look)
	InputMap.add_action(&"_box_use")
	var key := InputEventKey.new()
	key.keycode = KEY_G
	InputMap.action_add_event(&"_box_use", key)
	box.set_action(&"_box_use")
	check(box.key_text() == "G", "%s item box: the key is read out of InputMap" % look)
	InputMap.erase_action(&"_box_use")
	var picture := _picture()
	box.set_item(picture, "BANANA")
	check(box.held() and box.icon() == picture and box.item_name() == "BANANA", "%s item box: it holds what it is given" % look)
	box.set_charges(1)
	check(box.badge_text() == "", "%s item box: one charge shows no count" % look)
	box.set_charges(2)
	check(box.badge_text() == "×2" and box.charges() == 2, "%s item box: two charges read ×2" % look)
	box.set_timer(4.2, 6.0)
	check(box.timed() and box.timer_text() == "5" and is_equal_approx(box.timer_share(), 0.7) and not box.hurrying(),
		"%s item box: a running item shows its share and whole seconds" % look)
	box.set_timer(2.5, 6.0)
	check(box.hurrying() and box.timer_text() == "3", "%s item box: the last seconds hurry" % look)
	box.set_timer(0.0, 6.0)
	check(not box.timed() and box.timer_text() == "", "%s item box: a timer run out is gone" % look)
	box.set_fuse(1.26, 3.0)
	check(box.lit() and box.fuse_text() == "1.3", "%s item box: a lit fuse shows tenths" % look)
	var slow := box.tick_seconds()
	box.set_fuse(0.3, 3.0)
	check(box.tick_seconds() < slow, "%s item box: the fuse ticks faster as it runs out" % look)
	box.set_active(true)
	check(box.active(), "%s item box: a running item wears its ACTIVE word" % look)
	await frames(2)
	box.clear()
	check(not box.held() and box.badge_text() == "" and not box.lit() and not box.timed() and not box.active(),
		"%s item box: cleared, everything about the item is gone" % look)
	await frames(2)
	check(true, "%s item box: every state draws without an error" % look)
	holder.queue_free()
	await frames(1)
	GoUi.config.reduce_motion = false


func _item_box_motion(look: StringName) -> void:
	var box := GoItemBox.make(66.0)
	var holder := _host(box)
	await frames(1)
	box.set_process(false)
	var picture := _picture()
	# 20 — match start: the pop, after its delay.
	box.enter(0.08)
	check(box.box_scale() == 0.0, "%s item box: before its turn it is not shown" % look)
	_run(box, 0.6)
	check(box.box_scale() == 1.0 and not box.moving(), "%s item box: it lands at its size" % look)
	# 11 — gained: pop with an overshoot, sparkles, the tab slides up.
	box.set_item(picture, "BANANA")
	check(box.motion.playing(&"gain") and box.motion.playing(&"tab") and box.bursts() == 1,
		"%s item box: a gained item pops, sparkles and raises its tab" % look)
	check(box.box_scale() < 1.0 and box.tab_amount() == 0.0, "%s item box: the pop starts small, the tab down" % look)
	var peak := 0.0
	for i in 26:
		box.advance(1.0 / 60.0)
		peak = maxf(peak, box.box_scale())
	check(peak > 1.02, "%s item box: the pop overshoots" % look)
	_run(box, 0.3)
	check(box.box_scale() == 1.0 and box.tab_amount() == 1.0 and not box.moving(), "%s item box: popped in, it rests" % look)
	box.set_item(picture, "BANANA")
	check(box.bursts() == 1 and not box.moving(), "%s item box: the same item again plays nothing" % look)
	# 12 — used: the picture punches, the badge bumps.
	box.set_charges(2)
	check(not box.motion.playing(&"use"), "%s item box: charges going up is not a use" % look)
	box.set_charges(1)
	check(box.motion.playing(&"use"), "%s item box: a charge spent plays the use" % look)
	_run(box, GoItemBox.USE_SECONDS * 0.5)
	check(box.icon_scale() > 1.1 and box.badge_scale() > 1.2, "%s item box: the picture punches and the badge bumps" % look)
	_run(box, 0.3)
	check(box.icon_scale() == 1.0 and not box.moving(), "%s item box: the punch ends" % look)
	# 13 — timed: the edge drains smoothly; the last 3 s blink faster.
	box.set_timer(6.0, 6.0)
	check(box.motion.playing(&"blink") and box.timer_share() == 1.0, "%s item box: a running item lights its whole edge" % look)
	var before := box.timer_share()
	box.advance(1.0 / 60.0)
	check(box.timer_share() < before and before - box.timer_share() < 0.01, "%s item box: the edge drains a frame's worth" % look)
	var slow_swing := _blink_swings(box, 1.0)
	box.set_timer(2.0, 6.0)
	var fast_swing := _blink_swings(box, 1.0)
	check(box.hurrying() and fast_swing > slow_swing, "%s item box: in the last seconds the edge blinks faster (%d > %d)" % [look, fast_swing, slow_swing])
	box.set_timer(0.0, 6.0)
	check(not box.motion.playing(&"blink"), "%s item box: the blink stops with the timer" % look)
	# 15 — bomb lit: a pulse per tick, faster as it runs out.
	box.set_fuse(3.0, 3.0)
	check(box.motion.playing(&"tick") and box.tick_amount() > 0.9, "%s item box: a lit fuse starts on a tick" % look)
	var slow_ticks := _ticks(box, 1.2)
	box.set_fuse(0.4, 3.0)
	var fast_ticks := _ticks(box, 1.2)
	check(fast_ticks > slow_ticks, "%s item box: the ticks come faster as the fuse runs out (%d > %d)" % [look, fast_ticks, slow_ticks])
	check(box.fuse_text() == "0.4", "%s item box: the fuse reads its tenths" % look)
	# A different item takes the box over: the old one's count, timer and fuse go with it.
	box.set_charges(3)
	box.set_timer(5.0, 6.0)
	var other := GradientTexture2D.new()
	other.width = 16
	other.height = 16
	box.set_item(other, "TRAP")
	check(box.badge_text() == "" and box.charges() == 0 and not box.timed() and not box.lit() and box.bursts() == 2,
		"%s item box: a new item starts without the old one's count, timer and fuse" % look)
	check(not box.motion.playing(&"blink") and not box.motion.playing(&"tick") and not box.motion.playing(&"use"),
		"%s item box: and without its blink, ticks or punch" % look)
	_run(box, 1.0)
	# 14 — expired / last charge: the picture shrinks out, the frame is empty again.
	box.clear()
	check(not box.held() and box.motion.playing(&"leave") and box.icon_scale() == 1.0, "%s item box: a lost item starts leaving" % look)
	_run(box, GoItemBox.LEAVE_SECONDS * 0.5)
	check(box.icon_scale() > 0.0 and box.icon_scale() < 1.0, "%s item box: the picture shrinks" % look)
	_run(box, 0.3)
	check(box.icon_scale() == 0.0 and box._leaving == null and not box.moving(), "%s item box: gone, the box is empty and still" % look)
	holder.queue_free()
	await frames(1)


## How many times the edge's light turns from falling to rising in [param seconds].
func _blink_swings(box: GoItemBox, seconds: float) -> int:
	var turns := 0
	var last := box.blink_amount()
	var falling := false
	for i in ceili(seconds * 120.0):
		box.advance(1.0 / 120.0)
		var now := box.blink_amount()
		if now > last and falling: turns += 1
		if not is_equal_approx(now, last): falling = now < last
		last = now
	return turns


## How many fuse ticks start in [param seconds].
func _ticks(box: GoItemBox, seconds: float) -> int:
	var count := 0
	var last := box.tick_amount()
	for i in ceili(seconds * 120.0):
		box.advance(1.0 / 120.0)
		var now := box.tick_amount()
		if now > last + 0.5: count += 1
		last = now
	return count


func _item_box_reduced(look: StringName) -> void:
	GoUi.config.reduce_motion = true
	var box := GoItemBox.make(66.0)
	var holder := _host(box)
	await frames(1)
	box.enter(0.2)
	check(box.box_scale() == 1.0, "%s item box (reduced): it enters in place" % look)
	box.set_item(_picture(), "BANANA")
	check(box.held() and box.box_scale() == 1.0 and box.tab_amount() == 1.0 and box.bursts() == 0,
		"%s item box (reduced): a gained item is simply there — no pop, no sparkles" % look)
	box.set_charges(2)
	box.set_charges(1)
	check(box.icon_scale() == 1.0 and box.badge_scale() == 1.0, "%s item box (reduced): a use moves nothing" % look)
	box.set_timer(2.0, 6.0)
	check(box.blink_amount() == 1.0 and is_equal_approx(box.timer_share(), 2.0 / 6.0), "%s item box (reduced): the edge is steady and steps with its value" % look)
	box.set_fuse(1.0, 3.0)
	check(box.lit() and box.tick_amount() == 0.0 and box.fuse_text() == "1.0", "%s item box (reduced): the fuse reads, nothing pulses" % look)
	check(not box.motion.busy(), "%s item box (reduced): no motion runs" % look)
	box.clear()
	check(not box.held() and box.icon_scale() == 0.0 and box._leaving == null, "%s item box (reduced): a lost item is gone at once" % look)
	await frames(2)
	check(not box.is_processing(), "%s item box (reduced): it never processes" % look)
	holder.queue_free()
	await frames(1)
	GoUi.config.reduce_motion = false


# ── GoActionKey ───────────────────────────────────────────────────────

func _action_key(look: StringName) -> void:
	var jump := GoActionKey.make("JUMP", "Space")
	var holder := _host(jump)
	await frames(2)
	jump.set_process(false)
	check(jump.visible and jump.key_text() == "Space", "%s action key: the cap names its key" % look)
	var with_word := jump.get_combined_minimum_size().x
	jump.word = ""
	check(jump.get_combined_minimum_size().x < with_word, "%s action key: the word takes room beside the cap" % look)
	jump.word = "JUMP"
	jump.word_room = 12.0
	check(jump._word_size < roundi(13.0) and jump._word_size >= GoStyle.fit_floor(13), "%s action key: a word too long for its room shrinks, never under the floor" % look)
	jump.word_room = 0.0
	# 16 — jump used / ready: the cap presses, dims with a sweep, pops when ready.
	check(jump.press_amount() == 0.0 and jump.cover() == 0.0 and jump.cap_scale() == 1.0, "%s action key: at rest the cap is up and clear" % look)
	jump.set_cooldown(2.0, 2.0)
	check(jump.cooling() and jump.motion.playing(&"press") and jump.cover() == 1.0, "%s action key: used, the cap presses and is covered" % look)
	_run(jump, GoActionKey.PRESS_SECONDS * 0.5)
	check(jump.press_amount() > 0.8, "%s action key: the cap dips" % look)
	jump.set_cooldown(1.0, 2.0)
	var before := jump.cover()
	jump.advance(1.0 / 60.0)
	check(jump.cover() < before and before - jump.cover() < 0.02, "%s action key: the sweep moves a frame's worth" % look)
	check(jump.press_amount() == 0.0 or jump.motion.playing(&"press"), "%s action key: the dip is over or ending" % look)
	jump.set_cooldown(0.0, 2.0)
	check(not jump.cooling() and jump.cover() == 0.0 and jump.motion.playing(&"ready"), "%s action key: the wait over, the cap pops" % look)
	_run(jump, GoActionKey.READY_SECONDS * 0.5)
	check(jump.cap_scale() > 1.1, "%s action key: the pop is a size up" % look)
	_run(jump, 0.4)
	check(jump.cap_scale() == 1.0 and not jump.moving(), "%s action key: popped, it rests" % look)
	# 17 — sprint held: the cap stays down and lit.
	var sprint := GoActionKey.make("SPRINT", "Shift")
	holder.add_child(sprint)
	await frames(1)
	sprint.set_process(false)
	sprint.set_held(true)
	check(sprint.held() and sprint.motion.playing(&"press"), "%s action key: a held key goes down" % look)
	_run(sprint, 1.0)
	check(sprint.press_amount() == 1.0 and not sprint.moving(), "%s action key: it stays down while held, without processing" % look)
	sprint.set_held(false)
	check(sprint.press_amount() == 0.0, "%s action key: let go, it is up" % look)
	sprint.set_key("")
	check(not sprint.visible, "%s action key: an action with no key shows nothing" % look)
	sprint.enter(0.1)
	check(sprint.cap_scale() == 0.0, "%s action key: an entering key waits its turn" % look)
	_run(sprint, 0.6)
	check(sprint.cap_scale() == 1.0, "%s action key: it lands at its size" % look)
	# Reduced: state only.
	GoUi.config.reduce_motion = true
	jump.set_cooldown(2.0, 2.0)
	check(jump.cover() == 1.0 and jump.press_amount() == 0.0 and not jump.motion.busy(), "%s action key (reduced): used is covered, no dip" % look)
	jump.set_cooldown(0.5, 2.0)
	check(is_equal_approx(jump.cover(), 0.25), "%s action key (reduced): the cover steps with its value" % look)
	jump.set_cooldown(0.0, 2.0)
	check(jump.cap_scale() == 1.0 and not jump.motion.busy(), "%s action key (reduced): ready, no pop" % look)
	jump.set_held(true)
	check(jump.press_amount() == 1.0 and not jump.motion.busy(), "%s action key (reduced): held is down at once" % look)
	GoUi.config.reduce_motion = false
	holder.queue_free()
	await frames(1)


# ── GoBar: the hit and the warning ────────────────────────────────────────

func _bar_hit_and_alert(look: StringName) -> void:
	var bar := GoBar.new()
	bar.ink = Color("#ff7a3d")
	bar.ink_end = Color("#ffd23f")
	var holder := _host(bar)
	await frames(2)
	bar.set_process(false)
	check(not bar.is_processing() and bar.hit_offset() == 0.0 and bar.hit_flash() == 0.0, "%s bar: at rest nothing moves" % look)
	# 18 — stability hit: flash and shake, scaled by the loss.
	bar.hit(0.2)
	check(bar.motion.playing(&"hit"), "%s bar: a hit plays" % look)
	var light := _bar_swing(bar)
	check(bar.hit_offset() == 0.0 and bar._column.position.x == 0.0 and bar._column.modulate == Color.WHITE,
		"%s bar: after the hit the bar is back in place, unlit" % look)
	bar.hit(1.0)
	var flash := bar.hit_flash()
	var heavy := _bar_swing(bar)
	check(light > 0.5 and heavy > light * 1.5, "%s bar: a heavier hit swings further (%.1f > %.1f)" % [look, heavy, light])
	check(flash > 0.9, "%s bar: a full hit flashes bright" % look)
	bar.hit(0.0)
	check(not bar.motion.playing(&"hit"), "%s bar: no loss, no hit" % look)
	# 19 — stability low: the fill pulses toward the alert ink.
	bar.alert = true
	check(bar.motion.playing(&"alert"), "%s bar: the warning pulse runs" % look)
	var low := 1.0
	var high := 0.0
	for i in 60:
		bar.advance(1.0 / 60.0)
		low = minf(low, bar.alert_amount())
		high = maxf(high, bar.alert_amount())
	check(low < 0.1 and high > 0.9, "%s bar: the fill pulses between its ink and the alert ink" % look)
	bar.advance(GoBar.ALERT_SECONDS * 0.5 - fmod(1.0, GoBar.ALERT_SECONDS))
	check(bar._paint_gradient.colors[0].is_equal_approx(Color("#ff7a3d").lerp(GoUi.skin().hud_alert_ink(), bar.alert_amount())),
		"%s bar: the fill's paint follows the pulse" % look)
	bar.alert = false
	check(bar.alert_amount() == 0.0 and not bar.motion.busy() and bar._paint_gradient.colors[0].is_equal_approx(Color("#ff7a3d")),
		"%s bar: the warning over, the fill is its own ink again" % look)
	# Reduced: a steady alert ink, no hit.
	GoUi.config.reduce_motion = true
	bar.hit(1.0)
	check(not bar.motion.busy() and bar.hit_offset() == 0.0, "%s bar (reduced): a hit moves nothing" % look)
	bar.alert = true
	check(bar.alert_amount() == 1.0 and not bar.motion.busy()
		and bar._paint_gradient.colors[0].is_equal_approx(GoUi.skin().hud_alert_ink()), "%s bar (reduced): low is the alert ink, steady" % look)
	bar.alert = false
	GoUi.config.reduce_motion = false
	holder.queue_free()
	await frames(1)


## Runs a bar's hit to its end; answers the furthest it swung (dp).
func _bar_swing(bar: GoBar) -> float:
	var far := 0.0
	for i in 60:
		bar.advance(1.0 / 60.0)
		far = maxf(far, absf(bar._column.position.x))
	return far


# ── examples/magnet_dial: every event on a key ───────────────────────────

func _example_plays_every_event(look: StringName) -> void:
	var scene := (load("res://addons/gohud/examples/magnet_dial/magnet_dial.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await frames(2)
	var dial: GoMagnetDial = scene.dial
	var box: GoItemBox = scene.box
	check(GoUi.config.preset == look, "%s example: it keeps the look already picked" % look)
	check(dial.motion.playing(&"enter") and box.motion.playing(&"enter") and scene.jump.motion.playing(&"enter"),
		"%s example: it opens on the match-start entrance" % look)
	await frames(40)
	scene.hold_attract(true)
	check(dial.attracting() and dial.flowing(), "%s example: A held attracts" % look)
	scene.hold_attract(false)
	check(not dial.attracting() and dial.motion.playing(&"settle"), "%s example: A let go settles" % look)
	check(scene.play(KEY_R) and dial.cooling() and dial.motion.playing(&"fire"), "%s example: R fires the repulse" % look)
	scene.play(KEY_R)
	check(dial.motion.playing(&"deny"), "%s example: R again while cooling is denied" % look)
	scene.play(KEY_L)
	check(dial.low() and dial.motion.playing(&"low"), "%s example: L takes the power low" % look)
	scene.play(KEY_L)
	check(dial.power() == 0.0 and dial.motion.playing(&"empty"), "%s example: L again empties it" % look)
	scene.play(KEY_L)
	scene.play(KEY_M)
	check(dial.is_super(), "%s example: M turns SUPER MAGNET on" % look)
	scene.play(KEY_M)
	scene.play(KEY_P)
	check(box.held() and box.badge_text() == "×2" and box.motion.playing(&"gain"), "%s example: P gains a banana ×2" % look)
	scene.play(KEY_U)
	check(box.charges() == 1 and box.motion.playing(&"use"), "%s example: U spends a charge" % look)
	scene.play(KEY_U)
	check(not box.held() and box.motion.playing(&"leave"), "%s example: U on the last charge empties the box" % look)
	scene.play(KEY_P)
	scene.play(KEY_U)
	check(box.timed() and box.active(), "%s example: a used REFLECT runs its timer" % look)
	scene.play(KEY_P)
	scene.play(KEY_U)
	check(box.lit() and box.motion.playing(&"tick"), "%s example: a used BOMB lights its fuse" % look)
	scene.play(KEY_J)
	check(scene.jump.cooling() and scene.jump.motion.playing(&"press"), "%s example: J presses the JUMP cap" % look)
	scene.hold_sprint(true)
	check(scene.sprint.held(), "%s example: S held keeps the SPRINT cap down" % look)
	scene.hold_sprint(false)
	scene.play(KEY_H)
	check(scene.stability.motion.playing(&"hit"), "%s example: H hits the stability bar" % look)
	scene.play(KEY_H)
	scene.play(KEY_H)
	check(scene.stability.alert and scene.stability.motion.playing(&"alert"), "%s example: low stability pulses" % look)
	scene.play(KEY_X)
	check(not dial.powered() and dial.motion.playing(&"power_down"), "%s example: X powers the dial down" % look)
	scene.play(KEY_X)
	check(dial.powered(), "%s example: X again brings it back" % look)
	scene.play(KEY_T)
	check(GoUi.config.reduce_motion, "%s example: T reduces motion" % look)
	scene.play(KEY_R)
	scene.play(KEY_P)
	check(not box.motion.busy() or box.motion.playing(&"blink") == false, "%s example: reduced, a gain plays nothing" % look)
	scene.play(KEY_T)
	check(not GoUi.config.reduce_motion and not scene.play(KEY_Z), "%s example: T again restores motion; an unbound key does nothing" % look)
	await frames(3)
	scene.queue_free()
	await frames(1)


## A wait that ends through a sliver (2.0 − 120 × 1/60 leaves 1e-7 s, not 0) still ends: the parts once took the
## sliver and 0 for the same value and stayed cooling for ever, reading "0.0".
func _last_sliver_still_ends(look: StringName) -> void:
	var dial := GoMagnetDial.make()
	var box := GoItemBox.make()
	var key := GoActionKey.make("JUMP", "Space")
	var holder := _host(dial)
	holder.add_child(box)
	holder.add_child(key)
	await frames(1)
	dial.set_cooldown(2.0, 2.0)
	dial.set_cooldown(0.0000001, 2.0)
	check(dial.cooling() and dial.cooldown_text() == "0.1", "%s dial: a sliver of a wait reads its smallest step, never 0.0" % look)
	dial.set_cooldown(0.0, 2.0)
	check(not dial.cooling() and dial.cooldown_text() == "" and dial.motion.playing(&"ready"), "%s dial: the sliver over, it is ready" % look)
	box.set_item(_picture(), "BOMB")
	box.set_fuse(0.0000001, 3.0)
	check(box.lit() and box.fuse_text() == "0.1", "%s item box: a sliver of fuse reads 0.1" % look)
	box.set_fuse(0.0, 3.0)
	check(not box.lit() and box.fuse_text() == "", "%s item box: the sliver over, the fuse is out" % look)
	box.set_timer(0.0000001, 6.0)
	check(box.timed() and box.timer_text() == "1", "%s item box: a sliver of a run reads 1" % look)
	box.set_timer(0.0, 6.0)
	check(not box.timed(), "%s item box: the sliver over, the run has ended" % look)
	key.set_cooldown(0.0000001, 2.0)
	key.set_cooldown(0.0, 2.0)
	check(not key.cooling() and key.cover() == 0.0, "%s action key: the sliver over, the cap is clear" % look)
	holder.queue_free()
	await frames(1)
