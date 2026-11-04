## 🧪 **Checks for `GoRewardBurst`** — a claim played to COLLECT and flown into its pill in every look, the taps (the lock,
## the skip that never collects, only COLLECT collects), "+N" reading its whole amount from its first frame with its coin
## clear of it, a refused claim and a queued one dropped, two claims in a row (the later one quicker, one dim), reduce
## motion (fades, COLLECT at the tap lock, one count), the heap for a big amount, the band kept clear at the bottom, the
## painted pieces and `GoRewardAmount`; and `GoRewardRow.stamp_claimed`.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_reward_burst_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const LOOKS: Array[StringName] = [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT, GoThemePresets.SCIFI_DARK,
	GoThemePresets.MEDIEVAL_LIGHT, GoThemePresets.MATERIAL_LIGHT, GoThemePresets.ARCADE_DARK,
	GoThemePresets.ARCADE_LIGHT, GoThemePresets.COMIC_LIGHT, GoThemePresets.KIDS_DARK]
const FX_ART: Array[StringName] = [&"coin", &"coin_heap", &"fx_rays", &"fx_rays_thin", &"fx_glow", &"fx_ring",
	&"fx_sparkle", &"fx_glint"]

var passed := 0
var failed: Array[String] = []
var host: Control
var pill: Control
var pill_label: Label


func _initialize() -> void:
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(1334, 750)
		await frames(2)
	GoUi.reset()
	for look in LOOKS:
		GoUi.config.reduce_motion = false
		GoUi.use_preset(look)
		await frames(1)
		_make_host()
		await _plays_and_flies(look)
		host.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	_make_host()
	await _taps()
	await _amount_reads_whole()
	await _refused()
	await _queued_refused()
	await _in_a_row()
	await _heap()
	await _bottom_reserve()
	_painted_pieces()
	await _reduced()
	await _row_stamp()
	await _stop()
	host.free()
	GoUi.config.reduce_motion = false
	await frames(2)
	print("gohud reward burst tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func _make_host() -> void:
	host = Control.new()
	host.theme = GoUi.theme()
	host.size = Vector2(1334, 750)
	root.add_child(host)
	pill = Control.new()
	pill.position = Vector2(1100, 30)
	pill.size = Vector2(200, 60)
	host.add_child(pill)
	pill_label = Label.new()
	pill_label.text = "100"
	pill.add_child(pill_label)


func _burst(start := 100) -> GoRewardBurst:
	var burst := GoRewardBurst.new()
	host.add_child(burst)
	burst.collect_text = "COLLECT"
	burst.target = pill
	burst.target_label = pill_label
	burst.balance = start
	pill_label.text = str(start)
	return burst


func _from() -> Rect2:
	return Rect2(Vector2(900, 500), Vector2(120, 48))


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Pushed, answered, skipped to COLLECT, collected: the count lands on the server's balance, the layer goes.
func _plays_and_flies(look: StringName) -> void:
	var burst := _burst()
	var counts: Array[int] = []
	var ends: Array = []
	burst.counted.connect(func(v: int) -> void: counts.append(v))
	burst.finished.connect(func() -> void: ends.append(true))
	burst.push(_from(), "q1", 20)
	check(burst.visible and burst.is_active(), "%s: a push shows the layer at once" % look)
	check(burst.mouse_filter == Control.MOUSE_FILTER_STOP, "%s: the layer takes the screen's taps" % look)
	burst.resolve("q1", 20, 120)
	await wait(0.35)
	check(burst.tap() == "skipped", "%s: a tap after the lock jumps to the reveal" % look)
	await frames(1)
	check(burst.phase() == GoRewardBurst.Phase.SHOWN, "%s: …COLLECT is up (%d)" % [look, burst.phase()])
	check(burst.collect_button.mouse_filter == Control.MOUSE_FILTER_STOP, "%s: …and takes presses" % look)
	check(burst._amount_label.text == "+20", "%s: +20 (%s)" % [look, burst._amount_label.text])
	burst.collect()
	await wait(1.6)
	check(not counts.is_empty() and counts[-1] == 120, "%s: the count lands on the balance (%s)" % [look, counts])
	var rising := true
	for i in range(1, counts.size()): rising = rising and counts[i] >= counts[i - 1]
	check(rising and counts[0] > 100, "%s: it counts up from the old balance (%s)" % [look, counts])
	check(pill_label.text == "120", "%s: the pill's label reads it" % look)
	check(ends.size() == 1 and not burst.visible and not burst.is_active(), "%s: done once, the layer gone" % look)
	burst.free()


## Nothing for the lock; a skip never collects; once up, only COLLECT collects.
func _taps() -> void:
	var burst := _burst()
	var collects := [0]
	burst.collected.connect(func(_id: Variant) -> void: collects[0] += 1)
	burst.push(_from(), "t", 20)
	await frames(2)
	check(burst.tap() == "ignored", "a tap inside the lock is ignored")
	check(burst.collect_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "COLLECT takes nothing while it builds")
	await wait(0.35)
	check(burst.tap() == "skipped", "after the lock a tap skips")
	await frames(1)
	check(burst.phase() == GoRewardBurst.Phase.WAITING, "no answer yet: the build waits in its light")
	check(burst.tap() == "none", "a tap while it waits does nothing")
	burst.resolve("t", 20, 120)
	await frames(1)
	check(burst.phase() == GoRewardBurst.Phase.REVEAL, "the answer stamps \"+N\"")
	check(burst.tap() == "skipped", "a tap during the reveal jumps to COLLECT")
	await frames(1)
	check(burst.phase() == GoRewardBurst.Phase.SHOWN and collects[0] == 0, "…and never collects")
	_click(Vector2(20, 20))
	await frames(2)
	check(burst.phase() == GoRewardBurst.Phase.SHOWN and collects[0] == 0, "a tap off COLLECT does not collect")
	_click(burst.collect_button.get_global_rect().get_center())
	await frames(2)
	check(collects[0] == 1, "COLLECT collects")
	await wait(1.6)
	burst.free()


## "+N" reads the whole amount from the stamp's first frame, and its coin stays clear of it at every scale.
func _amount_reads_whole() -> void:
	var burst := _burst()
	burst.push(_from(), "a", 20)
	burst.resolve("a", 250, 350)
	var seen: Array[String] = []
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until:
		await frames(1)
		if burst._amount_group != null and burst._amount_group.modulate.a > 0.0: seen.append(burst._amount_label.text)
		if burst.phase() == GoRewardBurst.Phase.SHOWN: break
	check(not seen.is_empty() and seen.all(func(t: String) -> bool: return t == "+250"),
		"\"+N\" never reads anything but the amount (%s)" % [seen.slice(0, 3)])
	var coin := burst._amount_coin.get_rect()
	var words := burst._amount_label.get_rect()
	check(coin.end.x <= words.position.x + 0.5, "the coin stands left of the \"+\" (%s, %s)" % [coin, words])
	check(burst._amount_coin.get_parent() == burst._amount_label.get_parent(), "one group: scaled as one")
	burst.free()


func _refused() -> void:
	var burst := _burst()
	var ends: Array = []
	var counts := [0]
	burst.entry_finished.connect(func(id: Variant, got: bool) -> void: ends.append([id, got]))
	burst.counted.connect(func(_v: int) -> void: counts[0] += 1)
	burst.push(_from(), "r", 20)
	await wait(0.4)
	burst.refuse("r")
	burst.resolve("r", 20, 120) # a late answer for a refused entry is ignored
	await wait(0.4)
	check(ends == [["r", false]], "a refused claim ends unpaid (%s)" % [ends])
	check(counts[0] == 0 and pill_label.text == "100", "…counts nothing")
	check(not burst.visible and not burst.is_active(), "…and the layer fades away")
	burst.free()


func _queued_refused() -> void:
	var burst := _burst()
	var ends: Array = []
	burst.entry_finished.connect(func(id: Variant, got: bool) -> void: ends.append([id, got]))
	burst.push(_from(), "a", 20)
	burst.push(_from(), "b", 20)
	burst.refuse("b")
	check(ends == [["b", false]] and burst.current_id() == "a", "a queued claim refused is dropped (%s)" % [ends])
	burst.refuse("a")
	await wait(0.4)
	check(not burst.is_active(), "and the playing one fades")
	burst.free()


## Two in a row: the second waits, plays quicker, the dim stays between them; finished once.
func _in_a_row() -> void:
	var burst := _burst()
	var ends := [0]
	var order: Array = []
	burst.finished.connect(func() -> void: ends[0] += 1)
	burst.entry_finished.connect(func(id: Variant, _got: bool) -> void: order.append(id))
	burst.push(_from(), "a", 20)
	burst.push(_from(), "b", 30)
	burst.resolve("b", 30, 150)
	burst.resolve("a", 20, 120)
	check(burst.current_id() == "a", "the first plays first")
	await wait(0.35)
	burst.skip()
	await frames(1)
	burst.collect()
	var scrim_seen := 1.0
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until:
		await frames(1)
		if burst.current_id() == "b": break
		scrim_seen = minf(scrim_seen, burst._scrim.modulate.a)
	check(burst.current_id() == "b", "the second follows")
	check(scrim_seen > 0.99, "the dim stays between them (%.2f)" % scrim_seen)
	check(burst._beats == GoRewardBurst.QUICK_BEATS, "the later one is quicker")
	await wait(0.35)
	burst.skip()
	await frames(1)
	check(burst._amount_label.text == "+30", "each stamps its own amount")
	burst.collect()
	await wait(1.6)
	check(order == ["a", "b"] and ends[0] == 1, "both end in turn, finished once (%s, %d)" % [order, ends[0]])
	check(pill_label.text == "150", "the pill ends on the last balance")
	burst.free()


func _heap() -> void:
	var burst := _burst()
	burst.push(_from(), "h", 150)
	await frames(1)
	var art := burst._hero_art as TextureRect
	check(art != null and art.texture == GoUi.skin().widget_art(&"coin_heap"), "from heap_from on: the heap")
	burst.refuse("h")
	await wait(0.4)
	burst.push(_from(), "c", 20)
	await frames(1)
	art = burst._hero_art as TextureRect
	check(art != null and art.texture == GoUi.skin().widget_art(&"coin"), "below it: one coin")
	burst.refuse("c")
	await wait(0.4)
	burst.free()


## A band kept clear at the bottom: COLLECT stays above it; too big a band shrinks the group, and says so.
func _bottom_reserve() -> void:
	var burst := _burst()
	burst.bottom_reserve = 160.0
	burst.push(_from(), "b", 20)
	burst.resolve("b", 20, 120)
	await frames(2)
	var keep := burst.size.y - 160.0
	check(burst.collect_rect().end.y <= keep + 0.5, "COLLECT above the band (%s, %.0f)" % [burst.collect_rect(), keep])
	check(burst.fits(), "…at its full size")
	burst.bottom_reserve = 520.0
	await frames(1)
	check(burst.collect_rect().end.y <= burst.size.y - 520.0 + 0.5, "a band too tall: still above it")
	check(not burst.fits() and burst.fit_scale() < 1.0, "…shrunk, and it says so (%.2f)" % burst.fit_scale())
	burst.refuse("b")
	await wait(0.4)
	burst.free()
	# A small unit: the look's key is taller than COLLECT_SIZE × unit, and the band is kept from its real height.
	var small := _burst()
	small.unit = 0.5
	small.bottom_reserve = 200.0
	small.push(_from(), "s", 20)
	small.resolve("s", 20, 120)
	await frames(2)
	check(small.collect_button.size.y > GoRewardBurst.COLLECT_SIZE.y * 0.5, "the look's key is taller here (%s)" % small.collect_button.size)
	check(small.collect_rect().end.y <= small.size.y - 200.0 + 0.5, "…and still above the band (%s)" % small.collect_rect())
	small.refuse("s")
	await wait(0.4)
	small.free()
	# A large unit (a tablet): the word on COLLECT grows with its key.
	var base := _burst()
	base.push(_from(), "u1", 20)
	base.resolve("u1", 20, 120)
	await frames(2)
	var base_px := base.collect_button.get_theme_font_size(&"font_size")
	base.refuse("u1")
	await wait(0.4)
	base.free()
	var big := _burst()
	big.unit = 2.0
	big.push(_from(), "u2", 20)
	big.resolve("u2", 20, 120)
	await frames(2)
	var big_px := big.collect_button.get_theme_font_size(&"font_size")
	check(big_px >= roundi(base_px * 1.8), "a unit of 2 doubles COLLECT's word (%d, was %d)" % [big_px, base_px])
	big.refuse("u2")
	await wait(0.4)
	big.free()


func _painted_pieces() -> void:
	for art in FX_ART:
		check(GoUi.skin().widget_art(art) != null, "arcade_light paints %s" % art)
	check(GoUi.theme().is_type_variation(GoRewardBurst.VAR_AMOUNT, &"Label"), "GoRewardAmount is a Label variation")


func _reduced() -> void:
	GoUi.config.reduce_motion = true
	var burst := _burst()
	var counts: Array[int] = []
	burst.counted.connect(func(v: int) -> void: counts.append(v))
	burst.push(_from(), "m", 20)
	burst.resolve("m", 20, 120)
	await frames(1)
	check(not burst._rays.visible and not burst._rays2.visible, "reduce motion: no rays")
	check(burst._hero.position == Vector2.ZERO, "…no rise")
	await wait(0.45)
	check(burst.phase() == GoRewardBurst.Phase.SHOWN, "…COLLECT takes presses from the tap lock, unskipped")
	burst.collect()
	await wait(0.5)
	check(counts == [120], "…and the balance changes once (%s)" % [counts])
	check(not burst.is_active(), "…then it is gone")
	burst.free()
	GoUi.config.reduce_motion = false


func _row_stamp() -> void:
	var row := GoRewardRow.make("Win 3 matches", &"quest_medal", GoRewardRow.State.READY)
	row.size = Vector2(900, GoRewardRow.extent())
	host.add_child(row)
	await frames(1)
	check(not row.stamp_claimed(), "a READY row has nothing to stamp")
	row.set_state(GoRewardRow.State.CLAIMED)
	var seen := [0.0]
	var watch := func() -> void: seen[0] = maxf(seen[0], row.check_host.scale.x)
	process_frame.connect(watch)
	check(row.stamp_claimed(), "a CLAIMED row stamps its check")
	await frames(2)
	process_frame.disconnect(watch)
	check(seen[0] > 1.14, "…from big (%.2f)" % seen[0])
	await wait(0.45)
	check(row.check_host.scale.is_equal_approx(Vector2.ONE) and row.check_host.modulate.a == 1.0, "…and settles")
	row.free()


## The screen closed: everything ends at once, unpaid unless already collected, and the layer is gone.
func _stop() -> void:
	var burst := _burst()
	var ends: Array = []
	var done := [0]
	burst.entry_finished.connect(func(id: Variant, got: bool) -> void: ends.append([id, got]))
	burst.finished.connect(func() -> void: done[0] += 1)
	burst.push(_from(), "a", 20)
	burst.push(_from(), "b", 20)
	await wait(0.4)
	var behind := burst.get_node_or_null("Behind")
	check(behind is BackBufferCopy and behind.get_index() < burst._scrim.get_index(),
		"the frame behind is copied again before the scrim reads it (a screen's own frost took the first copy)")
	burst.stop()
	check(ends == [["a", false], ["b", false]] and done[0] == 1, "stop ends all, finished once (%s)" % [ends])
	check(not burst.visible and not burst.is_active() and burst.get_node_or_null("Fx") == null, "…and leaves nothing")
	burst.stop()
	check(done[0] == 1, "a second stop does nothing")
	burst.free()


func _click(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		root.push_input(event, true)


func frames(count: int) -> void:
	for i in count: await process_frame


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
