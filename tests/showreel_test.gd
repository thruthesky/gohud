## Integration test for the demo's showreel (`examples/demo/showreel.gd`): the reel steps through the
## chapters at the configured pace, every step wears the preset it announces, the three families all
## appear, the bot really presses something inside a step, the reel ends clean, Replay starts it again,
## and tearing the scene down mid-run leaves no error behind.
## Run through tools/check_demo.sh, which enforces a timeout and checks engine errors.
extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: return
	failures.append(description)
	push_error("SHOWREEL TEST: %s" % description)


func _run() -> void:
	var dimensions := OS.get_environment("DEMO_TEST_SIZE").split("x")
	if dimensions.size() == 2: root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	await _cycle()
	await _random()
	await _teardown()
	print("SHOWREEL TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _make(seconds: float, step: float, random_order := false, seed_value := 0) -> Control:
	var reel: Control = load("res://showreel.tscn").instantiate()
	reel.seconds = seconds
	reel.step = step
	reel.random_order = random_order
	reel.seed_value = seed_value
	return reel


## The default order: chapters in sequence, the theme rotating every step.
func _cycle() -> void:
	var reel := _make(4.0, 0.5)
	var steps: Array[Dictionary] = []
	var activity: Array[String] = []
	# 🛑 A lambda copies an int it captures — count in a dictionary, which is shared.
	var tally := {"built": 0, "presets": 0}
	reel.step_started.connect(func(number: int, key: StringName, preset: StringName) -> void:
		steps.append({"number": number, "key": key, "preset": preset})
		if GoUi.config.preset == preset: tally.presets += 1
		var stage: Control = reel._stage
		if stage.body.get_child_count() > 0 or stage.get_child_count() > 1: tally.built += 1)
	root.add_child(reel)
	await process_frame
	reel._bot.logged.connect(func(text: String) -> void: activity.append(text))
	check(reel.plan().size() == 8, "20 s at 0.5 s makes 40 steps; 4 s makes 8")
	var started := Time.get_ticks_msec()
	await reel.finished
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	check(steps.size() == 8, "Every planned step ran (%d)" % steps.size())
	check(tally.built == steps.size(), "Every step built its widget on the stage")
	check(tally.presets == steps.size(), "The active preset is the one each step announces")
	var seen: Array[StringName] = []
	for item in steps:
		if not seen.has(item.preset): seen.append(item.preset)
	check(seen.size() == 3, "All three theme families appear")
	var alternates := true
	for index in range(1, steps.size()):
		if steps[index].preset == steps[index - 1].preset: alternates = false
		if steps[index].key == steps[index - 1].key: alternates = false
	check(alternates, "Consecutive steps change both the theme and the widget")
	var entries := SimActs.list()
	var in_order := true
	for index in steps.size():
		if steps[index].key != entries[index].key: in_order = false
	check(in_order, "Cycle order walks the chapters in sequence")
	check(not activity.is_empty(), "The bot fired at least one widget callback inside a step (%d)" % activity.size())
	check(reel._stage.body.get_child_count() == 0 and reel._stage.get_child_count() == 1, "The stage is empty when the reel ends")
	check(not GoSurface.is_any_open(), "No modal surface survives the reel")
	check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "The bot released the pointer")
	if DisplayServer.get_name() != "headless":
		check(elapsed >= 3.5 and elapsed <= 6.5, "The reel lasts about as long as asked (%.1f s)" % elapsed)
	await process_frame
	var replay := reel.find_child("Replay", true, false) as Button
	check(replay != null, "A Replay button is offered when not recording")
	if replay != null:
		var again := {"count": 0}
		reel.step_started.connect(func(_n: int, _k: StringName, _p: StringName) -> void: again.count += 1)
		replay.pressed.emit()
		await create_timer(0.8).timeout
		check(again.count >= 1 and reel._playing, "Replay starts the reel again")
		check(reel.find_child("Replay", true, false) == null, "Replay removes the end card")
	reel.queue_free()
	await process_frame
	await process_frame


## Random order: every chapter once before any repeats, and never the same theme twice in a row.
func _random() -> void:
	var reel := _make(4.0, 0.5, true, 7)
	root.add_child(reel)
	await process_frame
	var plan: Array[Dictionary] = reel.plan()
	var keys: Array = []
	var alternates := true
	for index in plan.size():
		keys.append(int(plan[index].index))
		if index > 0 and plan[index].preset == plan[index - 1].preset: alternates = false
	var unique := keys.duplicate()
	unique.sort()
	var distinct := true
	for index in range(1, unique.size()):
		if unique[index] == unique[index - 1]: distinct = false
	check(distinct, "Random order does not repeat a chapter within a round")
	check(alternates, "Random order never keeps the same theme for two steps")
	var other := _make(4.0, 0.5, true, 7)
	check(str(other.plan()) == str(plan), "A fixed seed gives the same plan")
	other.free()
	var seeded: Array[Dictionary] = plan
	var plain := _make(4.0, 0.5)
	check(str(seeded) != str(plain.plan()), "Random order differs from the cycle")
	plain.free()
	await create_timer(1.2).timeout
	check(reel._playing, "A random reel plays")
	reel.queue_free()
	await process_frame
	await process_frame


## The home screen hides and frees an open example; a reel freed mid-step must go quietly.
func _teardown() -> void:
	var reel := _make(6.0, 0.5)
	root.add_child(reel)
	await create_timer(0.7).timeout
	check(reel._playing, "Reel is mid-run before teardown")
	reel.hide()
	reel.queue_free()
	for frame in 30: await process_frame
	check(not GoSurface.is_any_open(), "Teardown leaves no modal surface")
	check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "Teardown releases the pointer")
	# The window scale the reel imposed is put back for whoever comes next.
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_IGNORE
		or root.content_scale_size != Vector2i(1280, 720), "Teardown restores the window scale")
