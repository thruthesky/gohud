## 🧪 **Checks for the leaderboard widgets** — `GoPodium`, `GoScoreTable` and `GoBestBar`. Each runs in arcade_light
## (the game's variations) and in a plain look (the fallbacks: no art, no variations, no errors).
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_leaderboard_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.content_scale_size = Vector2i(1280, 720)
		await frames(2)
	GoUi.reset()
	GoUi.config.reduce_motion = true
	_table_variations()
	for look: StringName in [GoThemePresets.ARCADE_LIGHT, GoThemePresets.DEFAULT_DARK]:
		GoUi.use_preset(look)
		await frames(1)
		await _podium(look)
		await _table(look)
		await _best_bar(look)
	GoUi.reset()
	print("gohud leaderboard tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func _table_variations() -> void:
	check(GoScoreTable.row_variation(1, false) == GoScoreTable.VAR_ROW_GOLD, "rank 1 is the gold row")
	check(GoScoreTable.row_variation(2, false) == GoScoreTable.VAR_ROW, "rank 2 is a plain row")
	check(GoScoreTable.row_variation(4, true) == GoScoreTable.VAR_ROW_OWN, "the own row is the cyan row")
	check(GoScoreTable.row_variation(1, true) == GoScoreTable.VAR_ROW_OWN, "own wins over gold")
	check(GoScoreTable.medal_art(4) == null, "no medal past rank 3")


func _podium(look: StringName) -> void:
	var podium := GoPodium.new()
	root.add_child(podium)
	podium.position = Vector2(100, 40)
	podium.size = GoPodium.DESIGN_SIZE
	podium.set_places([{name = "MagnetQueen", value = "00:31.20"}, {name = "Bolt", value = "00:33.90"},
			{name = "CrateCrusher", value = "00:36.60"}])
	await frames(2)
	for place in 3:
		check(podium.is_place_shown(place), "%s: place %d shown" % [look, place + 1])
		check(podium.name_label(place).visible and podium.value_label(place).visible,
				"%s: place %d labels shown" % [look, place + 1])
	check(podium.name_label(0).text == "MagnetQueen" and podium.value_label(0).text == "00:31.20",
			"%s: 1st place texts" % look)
	check(podium.get_combined_minimum_size().is_equal_approx((GoPodium.DESIGN_SIZE * podium.minimum_scale).ceil()),
			"%s: minimum size from the design canvas" % look)
	# The gold block stands taller than the others.
	check(podium.block_rect(0).position.y < podium.block_rect(1).position.y, "%s: gold block is tallest" % look)
	# Each text fits its plate.
	for place in 3:
		var plate := podium.plate_rect(place)
		var label := podium.name_label(place)
		check(plate.encloses(Rect2(label.position, label.size).grow(-0.5)), "%s: place %d name on its plate" % [look,
				place + 1])
	# A short board hides the missing places.
	podium.set_places([{name = "Solo", value = "3"}])
	await frames(1)
	check(podium.is_place_shown(0) and not podium.is_place_shown(1) and not podium.is_place_shown(2),
			"%s: one entry shows only 1st" % look)
	check(not podium.name_label(1).visible and not podium.value_label(2).visible, "%s: missing places' labels hidden"
			% look)
	podium.set_places([null, {name = "B", value = "2"}, {}])
	await frames(1)
	check(not podium.is_place_shown(0) and podium.is_place_shown(1) and not podium.is_place_shown(2),
			"%s: null and {} hide a place" % look)
	podium.set_places([])
	await frames(1)
	check(not podium.is_place_shown(0) and not podium.is_place_shown(1) and not podium.is_place_shown(2),
			"%s: an empty board shows nothing" % look)
	# A very long name ends in an ellipsis, its font no smaller than the floor.
	podium.set_places([{name = "AnExtremelyLongPlayerNameThatCannotFit", value = "1"}])
	podium.show_decor = false
	await frames(1)
	var long_label := podium.name_label(0)
	var base := long_label.get_theme_font_size(&"font_size")
	check(long_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s: names ellipsize" % look)
	check(base > 0, "%s: the podium name has a font size" % look)
	podium.free()


func _table(look: StringName) -> void:
	var table := GoScoreTable.new()
	root.add_child(table)
	table.position = Vector2(100, 300)
	table.size = Vector2(880, 310)
	table.set_columns("RANK", "PLAYER", "CLEAR TIME")
	check(table.column_title(2) == "CLEAR TIME", "%s: column titles set" % look)
	check(table.scroll is GoScroll and table.rows.get_parent() == table.scroll, "%s: the table owns its scroll" % look)
	var data := [["MagnetQueen", "00:31.20"], ["Bolt", "00:33.90"], ["CrateCrusher", "00:36.60"], ["YOU", "00:39.30"],
			["Spinner", "00:42.00"]]
	var made: Array[Control] = []
	for i in data.size():
		made.append(table.add_row(i + 1, data[i][0], data[i][1], i == 3))
	await frames(2)
	check(table.row_count() == 5, "%s: five rows added" % look)
	check(made[0].theme_type_variation == GoScoreTable.VAR_ROW_GOLD, "%s: row 1 is gold" % look)
	check(made[1].theme_type_variation == GoScoreTable.VAR_ROW, "%s: row 2 is plain" % look)
	check(made[3].theme_type_variation == GoScoreTable.VAR_ROW_OWN, "%s: the own row is cyan" % look)
	var texts := GoScoreTable.row_labels(made[3]).map(func(l: Label) -> String: return l.text)
	check(texts == ["#4", "YOU", "00:39.30"], "%s: row texts (got %s)" % [look, texts])
	check(is_equal_approx(made[0].size.y, table.row_height), "%s: rows are row_height tall (got %s)" % [look,
			made[0].size.y])
	if look == GoThemePresets.ARCADE_LIGHT:
		check(table.scroll.get_v_scroll_bar().max_value <= table.scroll.size.y + 0.5,
				"%s: five rows fit without scrolling" % look)
	table.clear_rows()
	await frames(1)
	check(table.row_count() == 0, "%s: rows cleared" % look)
	table.font_size = 18
	var row := table.add_row(12, "Late", "9")
	await frames(1)
	check(GoScoreTable.row_labels(row)[0].text == "#12", "%s: rank text after clearing" % look)
	table.free()


func _best_bar(look: StringName) -> void:
	var bar := GoBestBar.new()
	root.add_child(bar)
	bar.position = Vector2(60, 600)
	bar.size = Vector2(970, 80)
	await frames(2)
	check(bar.label.text == "YOUR BEST", "%s: the default caption" % look)
	check(bar.is_empty() and Array(bar.entry_texts()) == ["—", "NO RECORD YET", "—"], "%s: empty by default" % look)
	bar.set_empty("NOT RANKED")
	check(bar.is_empty() and Array(bar.entry_texts()) == ["—", "NOT RANKED", "—"], "%s: set_empty draws — text —"
			% look)
	bar.set_entry("#4", "YOU", "00:39.30")
	await frames(1)
	check(not bar.is_empty() and Array(bar.entry_texts()) == ["#4", "YOU", "00:39.30"], "%s: set_entry" % look)
	var sizes := bar.entry_labels().map(func(l: Label) -> int: return l.get_theme_font_size(&"font_size"))
	check(sizes[0] == sizes[1] and sizes[1] == sizes[2], "%s: the pill's texts share one size" % look)
	bar.label_text = "BEST"
	check(bar.label.text == "BEST", "%s: label_text sets the caption" % look)
	check(bar.play_button is GoGlyphButton and bar.play_button.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON,
			"%s: PLAY is the primary glyph button" % look)
	var got := {play = 0, entry = 0}
	bar.play_pressed.connect(func() -> void: got.play += 1)
	bar.entry_pressed.connect(func() -> void: got.entry += 1)
	bar.play_button.pressed.emit()
	bar.entry_button.pressed.emit()
	check(got.play == 1 and got.entry == 1, "%s: play_pressed and entry_pressed fire" % look)
	bar.free()
