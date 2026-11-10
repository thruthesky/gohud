## 🧪 **Checks for `GoReveal`** — items hidden from the moment a step is added, each coming in at its time, a key that
## takes no presses before its step, a count that ends on its final text and holds its width, `finish` (from before
## `play` and from halfway), reduce motion (fades, counts jump), a freed item, and `GoStarRow.star`.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_reveal_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

var passed := 0
var failed: Array[String] = []
var host: Control


func _initialize() -> void:
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	_make_host()
	await _steps_in_turn()
	await _key_waits()
	await _count()
	await _finish_early()
	await _reduced()
	await _freed_item()
	_star_access()
	host.free()
	GoUi.config.reduce_motion = false
	await frames(2)
	print("gohud reveal tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func _make_host() -> void:
	host = VBoxContainer.new()
	host.size = Vector2(400, 300)
	root.add_child(host)


func _box(text := "") -> Label:
	var l := Label.new()
	l.text = text
	host.add_child(l)
	return l


func _steps_in_turn() -> void:
	var a := _box("A")
	var b := _box("B")
	var r := GoReveal.new(host)
	await frames(3) # the first draw of a label loads its font: let that frame pass before timing anything
	r.pop(a, 0.0).fade(b, 0.6)
	check(a.modulate.a == 0.0 and b.modulate.a == 0.0, "an added step hides its item at once")
	check(not r.is_shown(a) and not r.is_playing(), "nothing is shown before play")
	var done := [false]
	r.finished.connect(func() -> void: done[0] = true)
	r.play()
	check(r.is_playing(), "playing after play")
	await wait(0.12)
	check(r.is_shown(a) and not r.is_shown(b), "the first step started, the later one not yet")
	check(a.modulate.a > 0.0 and b.modulate.a == 0.0, "the first item is coming in, the later one still hidden")
	await wait(0.8)
	check(a.modulate.a == 1.0 and b.modulate.a == 1.0, "both items end fully shown")
	check(a.scale == Vector2.ONE, "a pop ends at its own scale")
	check(done[0] and not r.is_playing(), "finished once every step is done")
	a.free()
	b.free()


func _key_waits() -> void:
	var k := Button.new()
	k.text = "RETRY"
	host.add_child(k)
	k.mouse_filter = Control.MOUSE_FILTER_PASS
	var r := GoReveal.new(host)
	var seen: Array[Control] = []
	r.shown.connect(func(item: Control) -> void: seen.append(item))
	r.key(k, 0.2)
	check(k.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a key takes no presses before its step")
	r.play()
	await wait(0.05)
	check(not r.is_shown(k) and k.mouse_filter == Control.MOUSE_FILTER_IGNORE, "still waiting before its time")
	await wait(0.25)
	check(r.is_shown(k) and k.mouse_filter == Control.MOUSE_FILTER_PASS, "the key gets its own mouse_filter back as it shows")
	check(seen.size() == 1 and seen[0] == k, "shown names the key when it starts coming in")
	k.free()


func _count() -> void:
	var l := _box("1:23.45")
	var r := GoReveal.new(host)
	var texts: Array[String] = []
	r.count(l, 7.0, func(v: float) -> String: return str(int(v)), 0.1, 0.3)
	check(l.text == "1:23.45", "a count keeps the label's text until its step")
	r.play()
	await wait(0.15)
	texts.append(l.text)
	var held := l.custom_minimum_size.x
	await wait(0.4)
	check(texts[0] != "7" and int(texts[0]) < 7, "the count is on its way up halfway")
	check(held > 0.0, "the label holds a width while it counts")
	check(l.text == "7", "the count ends on its final text")
	check(l.custom_minimum_size.x == 0.0, "the label gets its own minimum width back")
	l.free()


func _finish_early() -> void:
	var a := _box("A")
	var k := Button.new()
	host.add_child(k)
	var l := _box("x")
	var r := GoReveal.new(host)
	r.pop(a, 0.5).key(k, 0.9).count(l, 12.0, func(v: float) -> String: return "%d" % int(v), 0.5)
	r.finish() # before play: a card closed in the frame it opened
	check(a.modulate.a == 1.0 and r.is_shown(k) and k.mouse_filter == Control.MOUSE_FILTER_STOP and l.text == "12",
			"finish before play shows everything at once")
	var r2 := GoReveal.new(host)
	r2.pop(a, 0.0).key(k, 0.6)
	r2.play()
	await wait(0.1)
	r2.finish()
	check(a.modulate.a == 1.0 and a.scale == Vector2.ONE and k.modulate.a == 1.0 and r2.is_shown(k)
			and not r2.is_playing(), "finish halfway puts every step at its end")
	await wait(0.7)
	check(a.scale == Vector2.ONE and k.modulate.a == 1.0, "a finished reveal changes nothing later")
	var r3 := GoReveal.new(host)
	r3.pop(a, 0.0).key(k, 0.5)
	r3.play()
	r3.settle(k)
	check(r3.is_shown(k) and k.modulate.a == 1.0 and r3.is_playing(), "settle ends one item's steps, the rest play on")
	k.modulate.a = 0.0 # the caller takes it over
	await wait(0.8)
	check(k.modulate.a == 0.0 and a.modulate.a == 1.0 and not r3.is_playing(), "a settled item is left to its caller")
	a.free()
	k.free()
	l.free()


func _reduced() -> void:
	GoUi.config.reduce_motion = true
	var a := _box("A")
	var l := _box("9")
	var r := GoReveal.new(host)
	r.pop(a, 0.0).count(l, 9.0, func(v: float) -> String: return str(int(v)), 0.0)
	r.play()
	await wait(0.06)
	check(a.scale == Vector2.ONE, "reduce motion: a pop never scales")
	check(l.text == "9", "reduce motion: a count shows its final text")
	await wait(0.3)
	check(a.modulate.a == 1.0 and not r.is_playing(), "reduce motion: the pop fades in on its timing")
	GoUi.config.reduce_motion = false
	a.free()
	l.free()


func _freed_item() -> void:
	var a := _box("A")
	var b := _box("B")
	var r := GoReveal.new(host)
	r.pop(a, 0.0).pop(b, 0.1)
	r.play()
	a.free()
	await wait(0.4)
	check(b.modulate.a == 1.0 and not r.is_playing(), "a freed item is skipped; the rest still plays")
	b.free()


func _star_access() -> void:
	var row := GoStarRow.make(2, 3)
	host.add_child(row)
	check(row.star(0) == row.star_nodes[0] and row.star(2) == row.star_nodes[2], "star(i) is the i-th star")
	check(row.star(-1) == null and row.star(3) == null, "star(i) outside the row is null")
	row.free()


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func frames(count: int) -> void:
	for i in count: await process_frame


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
