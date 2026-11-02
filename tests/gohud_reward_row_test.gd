## 🧪 **Checks for `GoRewardRow`** — the four states, the height no words can change (in every look), text that fits
## without going under the fit floor, the touch target, and a row reused by a `GoListView`: a press begun on one quest
## must never claim the next.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_reward_row_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const LONG := "Win five online matches without falling off the arena even once in a row today"
const LOOKS: Array[StringName] = [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT, GoThemePresets.SCIFI_DARK,
	GoThemePresets.SCIFI_LIGHT, GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT,
	GoThemePresets.MATERIAL_LIGHT, GoThemePresets.MATERIAL_DARK, GoThemePresets.ARCADE_DARK,
	GoThemePresets.ARCADE_LIGHT, GoThemePresets.COMIC_DARK, GoThemePresets.COMIC_LIGHT, GoThemePresets.KIDS_DARK,
	GoThemePresets.KIDS_LIGHT]

var passed := 0
var failed: Array[String] = []
var claims: Array = []
var host: Control


func _initialize() -> void:
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(360, 800)
		await frames(2)
	GoUi.reset()
	GoUi.config.reduce_motion = true
	for look in LOOKS:
		GoUi.use_preset(look)
		await frames(1)
		_make_host()
		await _fixed_height(look)
		await _states(look)
		await _right_to_left(look)
		host.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	_make_host()
	await _arcade_parts()
	await _text_fits()
	await _follows_config()
	await _press_once()
	await _stale_press()
	await _setters_again()
	await _no_rebuild()
	await _follows_the_look()
	await _inside_a_form()
	host.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await _in_a_list()
	await frames(2)
	print("gohud reward row tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func _make_host() -> void:
	host = Control.new()
	host.theme = GoUi.theme()
	host.size = Vector2(336, 700)
	root.add_child(host)


func _row(text := "Win 3 matches", state := GoRewardRow.State.READY) -> GoRewardRow:
	var row := GoRewardRow.make(text, GoIconSet.STAR, state)
	row.set_progress(3, 5)
	row.set_reward(50, GoIconSet.COIN)
	row.set_claim_text("CLAIM")
	row.size = Vector2(336, GoRewardRow.extent())
	host.add_child(row)
	row.claim_pressed.connect(func(id: Variant) -> void: claims.append(id))
	return row


func _fixed_height(look: StringName) -> void:
	var tall := GoRewardRow.extent()
	var heights := {}
	for state: int in GoRewardRow.State.values():
		for text: String in ["Go", LONG]:
			var row := _row(text, state)
			row.set_claim_text("BELOHNUNG ABHOLEN")
			row.set_reward(1234567, GoIconSet.COIN)
			row.set_progress(123456, 7654321)
			await frames(2)
			heights[row.get_combined_minimum_size().y] = true
			check(row.get_combined_minimum_size().y <= tall, "%s: state %d stays within extent() (%s > %s)" % [look, state,
				row.get_combined_minimum_size().y, tall])
			check(row.get_combined_minimum_size().x <= 336.0, "%s: state %d fits a phone (%s)" % [look, state,
				row.get_combined_minimum_size().x])
			if state == GoRewardRow.State.READY:
				check(row.claim_button.size.y >= GoUi.touch_size(), "%s: the pill keeps the touch target" % look)
				check(row.claim_button.size.x >= GoUi.touch_size(), "%s: the pill keeps the touch width" % look)
			row.free()
	check(heights.size() == 1, "%s: no state or word changes the height (%s)" % [look, heights.keys()])


func _states(look: StringName) -> void:
	var row := _row()
	await frames(1)
	var marks := {
		GoRewardRow.State.IN_PROGRESS: [false, false, false],
		GoRewardRow.State.READY: [true, false, false],
		GoRewardRow.State.CLAIMED: [false, true, false],
		GoRewardRow.State.LOCKED: [false, false, true],
	}
	for state: int in marks:
		row.set_state(state)
		row.refresh()
		var want: Array = marks[state]
		check(row.claim_button.visible == want[0], "%s: state %d pill" % [look, state])
		check(row.check_host.visible == want[1], "%s: state %d check" % [look, state])
		check(row.lock_mark.visible == want[2], "%s: state %d lock" % [look, state])
		check(row.fraction_label.text.contains("3") and row.fraction_label.text.contains("5"),
			"%s: state %d keeps its fraction" % [look, state])
		var dim: bool = state == GoRewardRow.State.CLAIMED or state == GoRewardRow.State.LOCKED
		check((row.title_label.get_parent() as Control).modulate.a < 1.0 == dim, "%s: state %d dims or not" % [look, state])
		if want[2]: check(row.lock_mark.get_child_count() == 1, "%s: the lock has a picture" % look)
	row.free()


func _right_to_left(look: StringName) -> void:
	var box := VBoxContainer.new()
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	box.size = Vector2(336, 200)
	host.add_child(box)
	var row := GoRewardRow.make(LONG, GoIconSet.STAR, GoRewardRow.State.READY)
	row.set_claim_text("CLAIM")
	row.set_progress(3, 5)
	box.add_child(row)
	await frames(2)
	var well: Control = row.find_child("Well", true, false)
	check(well.global_position.x > row.claim_button.global_position.x, "%s: right to left the picture leads" % look)
	check(row.fraction_label.text_direction == Control.TEXT_DIRECTION_LTR, "%s: the fraction stays left to right" % look)
	box.free()


func _arcade_parts() -> void:
	var row := _row()
	await frames(2)
	check(row.claim_button.theme_type_variation == &"GoPillGreen", "arcade_light's pill is GoPillGreen")
	check(row.claim_button.glow, "the pill glows")
	check(row.claim_button.feedback == GoFeedback.CONFIRMED, "a claim sounds confirmed")
	row.set_state(GoRewardRow.State.CLAIMED)
	row.refresh()
	var sticker: GoBadge = row.check_host.get_meta(&"gohud_badge")
	check(sticker.solid and sticker.icon == GoIconSet.CHECK, "the check is a GoBadge sticker")
	row.free()
	var plain := GoRewardRow.make("Plain")
	plain.set_progress(0, 0)
	plain.set_reward(0)
	host.add_child(plain)
	await frames(1)
	check(not plain.find_child("Progress", true, false).visible, "no target shows no bar")
	check(not plain.reward_row.visible, "no amount shows no payment")
	plain.free()


func _text_fits() -> void:
	var base := GoUi.font_size(GoTheme.ROLE_BODY)
	var bottom := GoStyle.fit_floor(base)
	var short := _row("Go")
	var wide := _row("Win five online matches without falling off the arena")
	var huge := _row(LONG + " " + LONG + " " + LONG)
	var pill := _row("Claim", GoRewardRow.State.READY)
	pill.set_claim_text("BELOHNUNG")
	var word := _row("Claim", GoRewardRow.State.READY)
	word.set_claim_text("ABHOLEN UND SOFORT BEHALTEN")
	await frames(3)
	check(short.title_label.get_theme_font_size(&"font_size") == base, "a short title keeps the full size")
	var fitted := wide.title_label.get_theme_font_size(&"font_size")
	check(fitted < base and fitted >= bottom, "a long title shrinks to the floor at most (%d)" % fitted)
	check(wide.title_label.get_visible_line_count() >= wide.title_label.get_line_count(), "a 54-letter title shows whole")
	check(huge.title_label.get_theme_font_size(&"font_size") == bottom, "an endless title stops at the floor")
	check(huge.title_label.get_visible_line_count() <= GoRewardRow.TITLE_LINES_AT_FLOOR, "an endless title stays in its box")
	check(huge.title_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "and ends in an ellipsis")
	var size := pill.claim_button.get_theme_font_size(&"font_size")
	var room := pill.claim_button.size.x - GoRewardRow.PILL_PAD * 2.0
	var font := pill.claim_button.get_theme_font(&"font")
	check(GoStyle.row_width(font, PackedStringArray(["BELOHNUNG"]), size) <= room,
		"a nine-letter word fits the pill (%d px, %s of %s)" % [size,
		GoStyle.row_width(font, PackedStringArray(["BELOHNUNG"]), size), room])
	check(word.claim_button.get_theme_font_size(&"font_size") == GoStyle.fit_floor(base), "the claim word stops at the floor")
	check(word.claim_button.size.x == GoRewardRow.SLOT_WIDTH, "a long claim word never widens the pill")
	for node: Control in [short, wide, huge, pill, word]: node.free()


func _follows_config() -> void:
	var was := GoRewardRow.extent()
	GoUi.config.min_touch_size = 80
	check(GoRewardRow.extent() > was, "a bigger touch floor makes the row taller")
	var row := _row()
	await frames(2)
	check(row.claim_button.size.y >= 80.0, "the pill follows GoConfig.min_touch_size")
	check(row.get_combined_minimum_size().y <= GoRewardRow.extent(), "and stays within extent()")
	row.free()
	GoUi.config.follow_look_touch_size()
	GoUi.config.base_font_size = 24
	var big := _row(LONG)
	await frames(2)
	check(big.get_combined_minimum_size().y <= GoRewardRow.extent(), "a bigger base font stays within extent()")
	check(GoRewardRow.extent() > was, "a bigger base font makes the row taller")
	big.free()
	GoUi.config.base_font_size = 0


## A finger going down on (or coming up from) the pill, as the viewport gets it.
func _touch(row: GoRewardRow, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = row.claim_button.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event, true)


func _press(row: GoRewardRow) -> void:
	_touch(row, true)
	await frames(1)
	_touch(row, false)
	await frames(1)


func _press_once() -> void:
	claims.clear()
	var row := _row()
	row.key = "win_3"
	await frames(2)
	await _press(row)
	check(claims == ["win_3"], "a press hands back the key (%s)" % [claims])
	check(row.claim_button.disabled, "the pill goes off after a press")
	await _press(row)
	check(claims.size() == 1, "a double tap is one claim")
	row.set_state(GoRewardRow.State.READY)
	await frames(2)
	check(not row.claim_button.disabled, "a refused claim re-arms with set_state")
	await _press(row)
	check(claims.size() == 2, "and the pill presses again")
	row.claim_button.disabled = false
	row.state = GoRewardRow.State.CLAIMED
	row.claim_button.pressed.emit()
	check(claims.size() == 2, "only a READY row claims")
	row.free()


func _stale_press() -> void:
	claims.clear()
	var row := _row()
	row.key = "same"
	await frames(2)
	_touch(row, true)
	await frames(1)
	row.set_progress(4, 5)
	row.set_reward(60)
	row.set_state(GoRewardRow.State.READY)
	await frames(1)
	_touch(row, false)
	await frames(1)
	check(claims == ["same"], "a refresh of the same data keeps the finger's press (%s)" % [claims])
	row.set_state(GoRewardRow.State.READY)
	await frames(1)

	for change: Callable in [func() -> void: row.key = "next", func() -> void: row.title = "Another quest"]:
		claims.clear()
		await frames(1)
		_touch(row, true)
		await frames(1)
		change.call()
		await frames(1)
		_touch(row, false)
		await frames(1)
		check(claims.is_empty(), "a press begun on old data does not fire (%s)" % [claims])
		check(not row.claim_button.disabled, "and the row is ready for its new data")
	claims.clear()
	await _press(row)
	check(claims == ["next"], "the next press claims the new data (%s)" % [claims])
	row.free()


func _setters_again() -> void:
	var row := _row()
	await frames(1)
	for pass_number in 3:
		row.title = "Quest %d" % pass_number
		row.icon = GoIconSet.GIFT
		row.set_progress(pass_number, 5)
		row.set_reward(pass_number + 1, GoIconSet.COIN)
		row.set_claim_text("CLAIM %d" % pass_number)
		row.set_state(GoRewardRow.State.CLAIMED)
		row.refresh()
		row.set_state(GoRewardRow.State.READY)
		await frames(1)
		check(row.title_label.text == "Quest %d" % pass_number, "the title follows")
		check(row.claim_button.text == "CLAIM %d" % pass_number, "the claim word follows")
		check(row.reward_label.text == str(pass_number + 1), "the amount follows")
		check(row.bar.value() == pass_number, "the bar jumps, it does not slide from the row's last data")
	check(row.check_host.get_children().filter(func(n: Node) -> bool: return n is GoBadge).size() == 1,
		"a state set again stacks no second sticker")
	row.free()


func _no_rebuild() -> void:
	var row := _row()
	await frames(2)
	var well: Control = row.find_child("Well", true, false)
	var art: Node = well.get_child(0).get_child(0)
	row.set_progress(4, 5)
	row.title = "Another"
	row.refresh()
	check(is_instance_valid(art) and art == well.get_child(0).get_child(0), "the same picture is not rebuilt")
	row.free()


func _follows_the_look() -> void:
	var row := _row()
	await frames(2)
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(2)
	check(row.claim_button.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON, "a look without the pill falls back")
	check(row.title_label.get_theme_color(&"font_color").is_equal_approx(GoUi.color(GoTheme.TEXT)), "the ink follows the look")
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(2)
	check(row.claim_button.theme_type_variation == &"GoPillGreen", "and back")
	row.free()


func _inside_a_form() -> void:
	var box := VBoxContainer.new()
	box.size = Vector2(336, 200)
	host.add_child(box)
	var row := GoRewardRow.make(LONG, GoIconSet.STAR, GoRewardRow.State.READY)
	box.add_child(row)
	GoStyle.form(box)
	await frames(2)
	check(row.get_combined_minimum_size().y <= GoRewardRow.extent(), "a form leaves the row its height")
	box.free()


func _in_a_list() -> void:
	claims.clear()
	var quests: Array[Dictionary] = []
	for index in 40:
		quests.append({"id": "q%d" % index, "title": LONG if index % 2 == 0 else "Quest %d" % index, "state": index % 4})
	var made := [0]
	var list := GoListView.recycle(quests.size(), GoRewardRow.extent(),
		func() -> Control:
			made[0] += 1
			var fresh := GoRewardRow.make("")
			fresh.claim_pressed.connect(func(id: Variant) -> void: claims.append(id))
			return fresh,
		func(node: Control, index: int) -> void:
			var row := node as GoRewardRow
			row.key = quests[index].id
			row.title = quests[index].title
			row.set_progress(index % 5, 5)
			row.set_reward(index + 1)
			row.set_claim_text("CLAIM")
			row.set_state(quests[index].state))
	list.theme = GoUi.theme()
	list.size = Vector2(336, 400)
	root.add_child(list)
	await frames(3)
	var at_top: int = made[0]
	var first := list.row(1) as GoRewardRow
	await _press(first)
	check(claims == ["q1"], "a list row claims its own quest (%s)" % [claims])
	list.scroll_vertical = int(GoRewardRow.extent() * 30.0)
	await frames(3)
	check(made[0] <= at_top + list.overscan + 2, "rows are reused while scrolling (%d → %d)" % [at_top, made[0]])
	check(not list.built_indexes().has(1), "row 1 left the view")
	for index in list.built_indexes():
		var row := list.row(index) as GoRewardRow
		check(row.key == quests[index].id, "row %d holds its own key" % index)
		check(is_equal_approx(row.size.y, GoRewardRow.extent()), "row %d is one extent tall (%s)" % [index, row.size.y])
		check(row.get_combined_minimum_size().y <= GoRewardRow.extent(), "row %d stays within extent()" % index)
	claims.clear()
	var ready_index := -1
	for index in list.built_indexes():
		if quests[index].state == GoRewardRow.State.READY and list.row(index).get_global_rect().position.y >= 0.0:
			ready_index = index
			break
	await _press(list.row(ready_index))
	check(claims == [quests[ready_index].id], "a reused row claims its new quest, not its old one (%s)" % [claims])
	list.free()


func frames(count: int) -> void:
	for i in count: await process_frame


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
