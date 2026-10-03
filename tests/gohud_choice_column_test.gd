## 🧪 **Checks for `GoChoiceColumn`** — the column of choices you tap once. Its own file, so it never clashes with the
## widgets other people are adding to `gohud_extra_test.gd`.
##
##   godot --headless --path <project> -s res://addons/gohud/tests/gohud_choice_column_test.gd
##
## Every press is a real mouse event through the viewport (`Input.parse_input_event`), not a signal emitted by hand —
## a tap that the drag logic swallowed would still pass a hand-emitted check.
extends SceneTree

var passed := 0
var failed: Array[String] = []
var pressed: Array[int] = []


func _initialize() -> void:
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_LIGHT)
	GoUi.config.reduce_motion = true
	await _column()
	await _caught_mid_glide()
	await _presets()
	print("gohud choice column tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


## A press and a release at [param point] (global, dp) — moving to [param release_at] in between when given.
func tap(point: Vector2, release_at := Vector2.INF) -> void:
	_mouse(point, true)
	await frames(1)
	if release_at != Vector2.INF:
		var steps := 6
		for i in range(1, steps + 1):
			var motion := InputEventMouseMotion.new()
			var from := point.lerp(release_at, float(i - 1) / steps)
			var to := point.lerp(release_at, float(i) / steps)
			motion.position = to
			motion.global_position = to
			motion.relative = to - from
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(motion.xformed_by(root.get_final_transform()))
			await frames(1)
	_mouse(release_at if release_at != Vector2.INF else point, false)
	await frames(2)


func _mouse(point: Vector2, held: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = held
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if held and button == MOUSE_BUTTON_LEFT else 0
	click.position = point
	click.global_position = point
	Input.parse_input_event(click.xformed_by(root.get_final_transform()))


func _column() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	var names := ["Hen", "Cat", "Dog", "Pig", "Sheep", "Cow"]
	var column := GoChoiceColumn.make(names, 4, func(index: int) -> void: pressed.append(index))
	column.position = Vector2(40, 40)
	host.add_child(column)
	await frames(3)
	var touch := float(GoUi.metric(GoTheme.TOUCH))
	var row := maxf(column.item_height, touch)
	var tall := column.padding * 2.0 + row * 4.0 + column.item_gap * 3.0
	check(is_equal_approx(column.size.y, tall), "column: four rows tall (%.1f, want %.1f)" % [column.size.y, tall])
	check(column.size.x >= touch, "column: never narrower than the touch token (%.1f)" % column.size.x)
	check(column.focus_mode == Control.FOCUS_NONE, "column: no keyboard focus by default — the arrow keys stay with the game")
	check(column.has_meta(GoScroll.OWNS_GESTURE), "column: its drag is its own inside a scrolling page")
	var content := row * 6.0 + column.item_gap * 5.0
	check(is_equal_approx(column.max_scroll(), content - (tall - column.padding * 2.0)),
		"column: scrolls exactly as far as the rows reach (%.1f)" % column.max_scroll())

	# 🔑 One tap acts — on any row, not only one in the middle.
	await tap(column.get_global_rect().position + column.row_rect(2).get_center())
	check(pressed == [2], "column: one tap on the third row presses it at once (%s)" % str(pressed))
	await tap(column.get_global_rect().position + column.row_rect(0).get_center())
	check(pressed == [2, 0], "column: one tap on the first row presses it (%s)" % str(pressed))
	check(column.selected_indices().is_empty(), "column: a tap never marks a row by itself — the app does")
	check(column.get_viewport().gui_get_focus_owner() != column, "column: a tap does not take keyboard focus")

	# 🔑 Any number of rows stand out as chosen; the app clears them.
	column.set_selected(0, true)
	column.set_selected(2, true)
	check(column.selected_indices() == PackedInt32Array([0, 2]), "column: two rows chosen at once (%s)" % str(column.selected_indices()))
	column.set_selected(0, false)
	check(column.selected_indices() == PackedInt32Array([2]) and column.is_selected(2) and not column.is_selected(0),
		"column: clearing one mark leaves the other")
	pressed.clear()
	await tap(column.get_global_rect().position + column.row_rect(2).get_center())
	check(pressed == [2] and column.is_selected(2), "column: a chosen row still presses (the app says what that means)")

	# A gap between rows and the padding press nothing.
	pressed.clear()
	var gap := column.row_rect(0).end + Vector2(-column.row_rect(0).size.x * 0.5, column.item_gap * 0.5)
	check(column.row_at(gap) == -1, "column: the gap between rows is no row")
	await tap(column.get_global_rect().position + gap)
	check(pressed.is_empty(), "column: a tap in a gap presses nothing (%s)" % str(pressed))

	# 🔑 A drag scrolls instead of pressing, and rests on a whole row.
	pressed.clear()
	var start := column.get_global_rect().position + column.row_rect(3).get_center()
	await tap(start, start + Vector2(0, -row * 1.4))
	check(pressed.is_empty(), "column: a drag presses nothing (%s)" % str(pressed))
	var step := row + column.item_gap
	var rest := column.get_scroll()
	check(rest > 0.0, "column: dragging up scrolls the rows (%.1f)" % rest)
	check(is_equal_approx(rest, column.max_scroll()) or is_zero_approx(fmod(rest, step)),
		"column: the rows rest on a whole row (%.1f, step %.1f)" % [rest, step])
	var top := column.row_at(Vector2(column.size.x * 0.5, column.padding + row * 0.5))
	check(top >= 1, "column: after the drag a later row is at the top (%d)" % top)
	await tap(column.get_global_rect().position + Vector2(column.size.x * 0.5, column.padding + row * 0.5))
	check(pressed == [top], "column: a tap after scrolling presses the row now under the finger (%s, want %d)" % [str(pressed), top])

	# The mouse wheel scrolls one row; the ends hold.
	column.scroll_to(0, false)
	await frames(1)
	_mouse(column.get_global_rect().get_center(), true, MOUSE_BUTTON_WHEEL_DOWN)
	_mouse(column.get_global_rect().get_center(), false, MOUSE_BUTTON_WHEEL_DOWN)
	await frames(2)
	check(is_equal_approx(column.get_scroll(), minf(step, column.max_scroll())), "column: the wheel scrolls one row (%.1f)" % column.get_scroll())
	column.scroll_to(5, false)
	await frames(1)
	check(is_equal_approx(column.get_scroll(), column.max_scroll()), "column: scroll_to(last) shows the last row whole")
	check(column.row_rect(5).end.y <= column.size.y - column.padding + 0.5, "column: the last row ends inside the plate")

	# Rows that draw themselves — only the rows in view are asked, with their marks.
	var drawn := {}
	column.item_drawer = func(_canvas: CanvasItem, index: int, _rect: Rect2, chosen: bool, dimmed: bool) -> void:
		drawn[index] = [chosen, dimmed]
	column.set_dimmed(4, true)
	column.scroll_to(0, false)
	await frames(2)
	if DisplayServer.get_name() != "headless":
		check(drawn.has(0) and not drawn.has(5), "column: the drawer draws the rows in view only (%s)" % str(drawn.keys()))
		check(drawn.get(2, [false])[0] == true, "column: the drawer is told a row is chosen")
	check(column.is_dimmed(4) and not column.is_dimmed(3), "column: a row can be greyed")

	# Fewer rows: marks past the end go, the scroll stays in range.
	column.set_selected(5, true)
	column.scroll_to(5, false)
	column.set_items(["Hen", "Cat", "Dog"])
	await frames(1)
	check(column.item_count() == 3 and not column.is_selected(5) and column.is_selected(2), "column: marks past the new end go")
	check(is_zero_approx(column.max_scroll()) and is_zero_approx(column.get_scroll()), "column: three rows in four do not scroll")

	# A short row still keeps the touch height.
	column.item_height = 24.0
	await frames(1)
	check(is_equal_approx(column.row_rect(0).size.y, touch), "column: a row never goes under the touch token (%.1f)" % column.row_rect(0).size.y)
	column.item_height = 48.0

	# The hovered row names itself; the column says the row last pressed and its mark (Dog, chosen above).
	check(column._get_tooltip(column.row_rect(1).get_center()) == "Cat", "column: a row's tooltip is its text")
	check(column.accessibility_name == "Dog ✓", "column: the screen reader hears the last row and its mark (%s)" % column.accessibility_name)
	column.set_selected(2, false)
	check(column.accessibility_name == "Dog", "column: the mark leaves what it says when cleared (%s)" % column.accessibility_name)

	# With focus turned on (a menu), Up/Down move a ring and Enter presses.
	column.focus_mode = Control.FOCUS_ALL
	column.grab_focus()
	pressed.clear()
	for action: StringName in [&"ui_down", &"ui_down", &"ui_accept"]:
		var key := InputEventAction.new()
		key.action = action
		key.pressed = true
		Input.parse_input_event(key)
		await frames(1)
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		await frames(1)
	check(pressed == [2], "column: with focus, Down Down Enter presses the third row (%s)" % str(pressed))
	host.queue_free()
	await frames(2)


## 🔑 Every preset — a part's text has to read on its own face in each look (the gohud rule for every widget): plain
## rows on the HUD plate, a chosen row on its accent wash, and the ring around it against the plate.
## Every preset this copy has — the built-in ones and any `themes/presets/<id>.tres` added since (a project's own, a new
## family), so a new look is checked the day it lands.
func _presets() -> void:
	for preset in GoThemePresets.names():
		GoUi.use_preset(preset)
		var column := GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig", "Cow"], 4)
		column.set_selected(1, true)
		column.set_dimmed(2, true)
		column.position = Vector2(40, 40)
		root.add_child(column)
		await frames(2)
		var page := GoUi.color(GoTheme.BACKGROUND)
		# The face the column really draws: the HUD surface, without the shadow and glow it drops (`_plate`).
		var plate := GoSkin.blend(GoSkin.box_background(GoUi.skin().surface_box(GoTheme.BOX_HUD)), page)
		var accent := GoUi.color(GoTheme.ACCENT)
		var chosen := GoSkin.blend(Color(accent, 0.22), plate)
		var ink := GoUi.color(GoTheme.TEXT)
		check(GoSkin.contrast_ratio(ink, plate) >= 4.5 and GoSkin.contrast_ratio(ink, chosen) >= 4.5,
			"%s: a row's text reads on the plate and on a chosen row (%.2f · %.2f)" % [preset,
				GoSkin.contrast_ratio(ink, plate), GoSkin.contrast_ratio(ink, chosen)])
		check(GoSkin.contrast_ratio(accent, plate) >= 3.0, "%s: a chosen row's ring shows on the plate (%.2f)" % [preset,
			GoSkin.contrast_ratio(accent, plate)])
		var touch := float(GoUi.metric(GoTheme.TOUCH))
		check(column.row_rect(0).size.y >= touch - 0.5 and column.size.x >= touch,
			"%s: rows keep the touch size (%s)" % [preset, column.row_rect(0).size])
		column.queue_free()
		await frames(1)
	GoUi.use_preset(GoThemePresets.DEFAULT_LIGHT)


## 🛑 A finger that lands on rows still gliding stops them — it presses nothing and they rest on a whole row. With
## `reduce_motion` on (the rest of this file) nothing glides, which is how this slipped past the first checks.
func _caught_mid_glide() -> void:
	GoUi.config.reduce_motion = false
	pressed.clear()
	var column := GoChoiceColumn.make(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"], 4,
		func(index: int) -> void: pressed.append(index))
	column.position = Vector2(40, 40)
	root.add_child(column)
	await frames(3)
	column.scroll_to(8, true)                 # an animated glide down the list
	await frames(1)
	var gliding := column.get_scroll()
	check(gliding > 0.0 and gliding < column.max_scroll(), "glide: the rows are moving (%.1f)" % gliding)
	await tap(column.get_global_rect().position + column.row_rect(column.row_at(Vector2(column.size.x * 0.5,
		column.padding + column.item_height * 0.5))).get_center())
	await create_timer(0.6).timeout
	check(pressed.is_empty(), "glide: a tap on moving rows presses nothing (%s)" % str(pressed))
	var step := maxf(column.item_height, float(GoUi.metric(GoTheme.TOUCH))) + column.item_gap
	var rest := column.get_scroll()
	# Within half a pixel of a multiple of the step — `fmod(52.0, 52.0)` came back as 52 from float rounding.
	check(is_equal_approx(rest, column.max_scroll()) or absf(rest - roundf(rest / step) * step) < 0.5,
		"glide: the caught rows rest on a whole row (%.1f, step %.1f)" % [rest, step])
	# The next tap, on rows at rest, acts again.
	var top := column.row_at(Vector2(column.size.x * 0.5, column.padding + step * 0.5))
	await tap(column.get_global_rect().position + column.row_rect(top).get_center())
	check(pressed == [top], "glide: once they rest, a tap presses the row under the finger (%s, want %d)" % [str(pressed), top])
	column.queue_free()
	GoUi.config.reduce_motion = true
	await frames(2)

