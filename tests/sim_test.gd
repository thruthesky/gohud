## Integration test for the standalone demo: real input, complete tour, cancellation, replay,
## and the sidebar explore mode (pick one widget, play only that widget, leave a full-screen chapter).
## Run through tools/check_demo.sh, which enforces a timeout and checks engine errors.
extends SceneTree

var sim: Control
var failures: Array[String] = []
var checks := 0
var activity: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: return
	failures.append(description)
	push_error("DEMO TEST: %s" % description)

func _run() -> void:
	var dimensions := OS.get_environment("DEMO_TEST_SIZE").split("x")
	if dimensions.size() == 2: root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	sim = load("res://sim.tscn").instantiate()
	root.add_child(sim)
	sim._set_speed(4.0)
	sim._bot.verify = true
	sim._trace = true
	sim._bot.logged.connect(func(message: String) -> void: activity.append(message))
	await create_timer(0.2).timeout
	check(not sim._running and sim._stage.body.get_child_count() == 0, "Launch waits for Start")
	check(TranslationServer.get_locale() == "en", "Demo forces the English locale")
	var start := sim._cover.find_child("Start", true, false) as Button
	check(root.get_visible_rect().encloses(start.get_global_rect()), "Start button fits the viewport")
	await click(start)
	check(sim._running, "Clicking Start begins the tour")
	await sim.tour_finished
	check(sim._counter.get_line_count() == 1, "Chapter counter stays on one line")
	check(sim._completed == SimActs.list().size(), "All chapters completed")
	check(sim._bot.failures.is_empty(), "All interaction assertions passed")
	check(root.get_visible_rect().encloses(sim._stage.get_global_rect()), "Stage fits the viewport")
	for expected in ["Class: Ranger", "Menu item: 1", "Repeated click: 6", "Prompt card closed",
			"Tour: Complete", "Form submitted: Aria", "HUD position: Bottom left", "Theme: Light",
			"Inventory loaded: 3 rows", "Sheet opened: 20 items", "Popup closed", "Download started"]:
		check(activity.has(expected), "Observed callback: %s" % expected)
	check(not GoSurface.is_any_open(), "No modal surface survives the tour")

	await choose_theme(sim._cover, 1)
	check(find_button(sim._cover, "Replay demo") != null and not sim._running,
		"Changing themes keeps the completion screen")
	await choose_theme(sim._cover, 0)

	# Pause while a text field owns focus, then navigate from the paused state.
	await click(find_button(sim._cover, "Replay demo"))
	while not sim._running or sim._index >= SimActs.list().size(): await process_frame
	while sim._index < 2: await process_frame
	await create_timer(0.6).timeout
	key(KEY_SPACE)
	await process_frame
	check(sim._bot.paused, "Space pauses even when a text field has focus")
	var index: int = sim._index
	var cursor: Vector2 = sim._bot.here()
	await create_timer(0.25).timeout
	check(sim._index == index and sim._bot.here() == cursor, "Paused demo does not advance or move")
	key(KEY_RIGHT)
	await create_timer(0.2).timeout
	check(sim._index == 3 and not sim._bot.paused, "Next skips the paused chapter")
	key(KEY_LEFT)
	await create_timer(0.2).timeout
	check(sim._index == 2, "Previous returns to the preceding chapter")
	key(KEY_ESCAPE)
	await create_timer(0.2).timeout
	check(not sim._running and is_instance_valid(sim._cover), "Escape returns to Start")
	check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "Cancellation releases the pointer")

	# Restart and cancel repeatedly; stale coroutines must never resume or clear the new scene.
	for iteration in 3:
		await click(sim._cover.find_child("Start", true, false) as Button)
		await create_timer(0.05).timeout
		key(KEY_ESCAPE)
		await create_timer(0.15).timeout
		check(not sim._running and sim._stage.body.get_child_count() == 0,
			"Restart/cancel %d leaves no chapter content" % iteration)
	check(not GoSurface.is_any_open(), "Cancelled tour leaves no modal surfaces")

	await _explore_mode()
	await _theme_switching()
	print("DEMO TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Explore mode: the sidebar opens a single widget for hands-on use, without the bot.
func _explore_mode() -> void:
	var entries := SimActs.list()
	var wide: bool = sim.size.x >= sim.NARROW
	# The Start screen offers Explore; it opens the first widget.
	await click(sim._cover.find_child("Explore", true, false) as Button)
	await create_timer(0.1).timeout
	check(not sim._running and sim._explore == 0, "Explore opens the first widget without the bot")
	check(sim._stage.body.get_child_count() > 0, "Explore builds the widget on the stage")
	check(not is_instance_valid(sim._cover), "Explore removes the Start screen")
	check(sim._play_one.visible and not sim._play_one.disabled, "Play this widget is offered")

	# Pick another widget: through the sidebar on wide screens, the top menu otherwise.
	var pick := entries.size() - 1
	if wide:
		check(sim._side_box.visible, "Sidebar is visible on wide screens")
		await click_row(pick)
	else:
		check(sim._picker.visible, "Narrow screens offer the widget menu")
		sim._open_explore(pick)
	await create_timer(0.1).timeout
	check(sim._explore == pick and sim._index == pick, "Sidebar selection switches the explored widget")
	check(sim._stage.body.get_child_count() > 0, "Selected widget is built")
	check(sim._counter.text.begins_with("%02d" % (pick + 1)), "Counter follows the explored widget")

	# Hands-on interaction fires the same callbacks the bot would.
	var dialogs_index := 7
	sim._open_explore(dialogs_index)
	await create_timer(0.1).timeout
	activity.clear()
	await click(find_button(sim._stage, "Show alert"))
	await create_timer(0.3).timeout
	check(GoSurface.is_any_open(), "Manual click opens a dialog in explore mode")
	await click(sim._stage.find_child("Confirm", true, false) as Button)
	await create_timer(0.3).timeout
	check(activity.has("Dialog: confirmed"), "Manual interaction logs the widget callback")
	check(not GoSurface.is_any_open(), "Dialog closes after acknowledging")

	# Play only this widget: the bot drives it, then hands it back rebuilt.
	# Wide screens offer the panel button; narrow ones use the top-bar play button.
	activity.clear()
	await click(sim._play_one if wide else sim._pause_button)
	check(sim._running and sim._explore == dialogs_index, "Play this widget starts the bot on that widget")
	check(sim._play_one.disabled, "Play button is disabled while the bot drives")
	await sim.chapter_finished
	await create_timer(0.1).timeout
	check(not sim._running and sim._explore == dialogs_index, "Single play returns to explore mode")
	check(sim._stage.body.get_child_count() > 0, "Widget is rebuilt after the single play")
	check(activity.has("Popup closed") and activity.has("Sheet closed"), "Single play completed the chapter")
	check(sim._bot.failures.is_empty(), "Single play assertions passed")

	# Keyboard: arrows move between widgets; Space plays; text fields keep their keys.
	key(KEY_RIGHT)
	await create_timer(0.1).timeout
	check(sim._explore == dialogs_index + 1, "Right arrow opens the next widget")
	key(KEY_LEFT)
	await create_timer(0.1).timeout
	check(sim._explore == dialogs_index, "Left arrow opens the previous widget")
	sim._open_explore(2)
	await create_timer(0.1).timeout
	var field: Array = sim._stage.find_children("*", "LineEdit", true, false)
	check(not field.is_empty(), "Inputs widget has a text field")
	if not field.is_empty():
		(field[0] as LineEdit).grab_focus()
		await process_frame
		key(KEY_SPACE)
		await create_timer(0.1).timeout
		check(not sim._running, "Space does not start the bot while typing")
		root.gui_release_focus()
		await process_frame
	key(KEY_SPACE)
	await create_timer(0.1).timeout
	check(sim._running and sim._explore == 2, "Space plays the explored widget")
	key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	check(not sim._running and is_instance_valid(sim._cover), "Escape during a single play returns to Start")

	# Selecting a widget during the tour folds the tour and opens it hands-on.
	await click(sim._cover.find_child("Start", true, false) as Button)
	await create_timer(0.3).timeout
	check(sim._running and sim._explore < 0, "Tour is running")
	sim._open_explore(4)
	await create_timer(0.5).timeout
	check(not sim._running and sim._explore == 4, "Picking a widget mid-tour switches to explore mode")
	check(sim._stage.body.get_child_count() > 0, "Widget picked mid-tour is built")
	check(not GoSurface.is_any_open(), "Folded tour leaves no modal surfaces")

	# Full-screen chapters offer a way back to the sidebar.
	var forms_index := 12
	sim._open_explore(forms_index)
	await create_timer(0.1).timeout
	var back := find_button(sim._stage, "Back to widgets")
	check(back != null, "Full-screen chapter offers Back to widgets")
	await click(back)
	await create_timer(0.1).timeout
	check(sim._explore < 0 and sim._stage.body.get_child_count() == 0 and sim._stage.get_child_count() == 1,
		"Back to widgets clears the full-screen chapter")
	check(not is_instance_valid(sim._cover), "Back to widgets stays on the showcase")
	if wide:
		await click_row(1)
		await create_timer(0.1).timeout
		check(sim._explore == 1, "Sidebar works again after leaving a full-screen chapter")
	else:
		key(KEY_RIGHT)
		await create_timer(0.1).timeout
		check(sim._explore == 0, "Right arrow opens the first widget from an empty stage")
	key(KEY_ESCAPE)
	await create_timer(0.1).timeout
	check(not sim._running and is_instance_valid(sim._cover), "Escape leaves explore mode for Start")
	check(sim._stage.body.get_child_count() == 0, "Start screen has an empty stage")


## Sidebar rows scroll; bring the row into view the way a person would before clicking it.
func click_row(index: int) -> void:
	var row: Button = sim._rows[index]
	sim._side_scroll.ensure_control_visible(row)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(row.get_global_rect()), "Sidebar row %d is on screen" % index)
	await click(row)

func click(button: Button) -> void:
	await process_frame
	await process_frame
	check(is_instance_valid(button), "Test button exists")
	if not is_instance_valid(button): return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion.xformed_by(root.get_final_transform()))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event.xformed_by(root.get_final_transform()))
		await process_frame
	await process_frame
	await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text: return child
		var found := find_button(child, text)
		if found != null: return found
	return null


func theme_picker(scope: Node) -> OptionButton:
	return scope.find_child("ThemePicker", true, false) as OptionButton


func choose_theme(scope: Node, index: int) -> void:
	var picker := theme_picker(scope)
	check(picker != null and picker.item_count == 3, "Theme dropdown lists the three families")
	if picker == null: return
	check(root.get_visible_rect().encloses(picker.get_global_rect()), "Theme dropdown fits the viewport")
	await click(picker)
	await process_frame
	check(picker.get_popup().visible, "Click opens the theme dropdown")
	# A mouse-opened PopupMenu starts with no keyboard-highlighted item.
	for step in index + 1:
		key(KEY_DOWN)
		await process_frame
	key(KEY_ENTER)
	await create_timer(0.2).timeout


func _theme_switching() -> void:
	var presets := [GoThemePresets.DEFAULT_DARK, GoThemePresets.SCIFI_DARK, GoThemePresets.MEDIEVAL_DARK]
	# The intro cover must offer the same dropdown as the running showcase.
	await choose_theme(sim._cover, 2)
	check(GoUi.config.preset == GoThemePresets.MEDIEVAL_DARK, "Intro selects medieval")
	check(is_instance_valid(sim._cover) and not sim._running, "Theme change keeps the Start screen")
	check(sim._stage.get_theme_stylebox(&"panel") is GoStyleBoxMedieval, "Stage uses the medieval frame")
	check(GoUi.config.color_overrides.is_empty(), "Original cyan overrides do not leak into medieval")
	sim._open_explore(0)
	await create_timer(0.1).timeout
	await choose_theme(sim, 1)
	check(sim._explore == 0 and not sim._running, "Theme change keeps the explored widget")
	check(sim._stage.get_theme_stylebox(&"panel") is GoStyleBoxCut, "Stage uses the sci-fi frame")
	check(GoUi.icons().texture(GoIconSet.SWORD).resource_path.contains("/icons/default/"),
		"Sci-fi restores the default sword icon")
	# Closing the menu without a selection must resume playback, while switching from a
	# paused chapter must preserve that pause and rebuild only after the old bot unwinds.
	sim._set_speed(0.7)
	sim._play_current()
	await create_timer(0.05).timeout
	await click(theme_picker(sim))
	check(sim._bot.paused, "Opening the theme dropdown pauses the bot")
	key(KEY_ESCAPE)
	await create_timer(0.05).timeout
	check(sim._running and not sim._bot.paused, "Dismissing the dropdown resumes the bot")
	theme_picker(sim).grab_focus()
	key(KEY_SPACE)
	await process_frame
	await process_frame
	check(theme_picker(sim).get_popup().visible and sim._bot.paused,
		"Space opens the focused theme picker without triggering a tour shortcut")
	key(KEY_ESCAPE)
	await create_timer(0.05).timeout
	sim._bot.paused = true
	await choose_theme(sim, 2)
	check(sim._running and sim._bot.paused and sim._explore == 0,
		"Switching a paused single play preserves chapter and pause")
	check(sim._stage.get_theme_stylebox(&"panel") is GoStyleBoxMedieval, "Paused chapter rebuilt with medieval geometry")
	check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "Theme change releases any bot drag")
	sim._stop()
	await create_timer(0.2).timeout
	sim._start()
	await create_timer(0.05).timeout
	var chapter: int = sim._index
	await choose_theme(sim, 1)
	check(sim._running and not sim._bot.paused and sim._explore == -1 and sim._index == chapter,
		"Switching a running tour resumes the current chapter")
	sim._stop()
	await create_timer(0.2).timeout
	await choose_theme(sim._cover, 0)
	check(GoUi.config.preset == GoThemePresets.DEFAULT_DARK, "Default can be restored")
	check(sim._stage.get_theme_stylebox(&"panel") is StyleBoxFlat, "Default stage restores its flat frame")
	sim.queue_free()
	await process_frame
	# demo.tscn is a separate static gallery, with a fixed top toolbar above its scroll.
	var gallery: Control = load("res://demo.tscn").instantiate()
	root.add_child(gallery)
	await create_timer(0.1).timeout
	for index in [1, 2, 0]:
		await choose_theme(gallery, index)
		check(GoUi.config.preset == presets[index], "Gallery switches to %s" % presets[index])
		check(theme_picker(gallery).selected == index, "Gallery dropdown retains its selection after rebuilding")
	gallery.queue_free()
	await process_frame
