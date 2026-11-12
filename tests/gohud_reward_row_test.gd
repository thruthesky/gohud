## 🧪 **Checks for `GoRewardRow`** — the four states, the height no words can change (in every look), the one line of a
## table and the fallback under it, the painted plates and art, text that fits without going under the fit floor, the
## touch target, `GoBar.set_faces`, and a row reused by a `GoListView`: a press begun on one quest must never claim the
## next. The description: none is the row as it was, one grows the row by its lines only (`extent_for`), in its own
## smaller type, under the title in both layouts, shrunk and wrapped to two lines at most, in a list too.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_reward_row_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const LONG := "Win five online matches without falling off the arena even once in a row today"
## How-to lines as a game writes them: a short one, a German one, one too long for two lines, and one in Japanese
## (no spaces: it wraps between characters).
const HOW := "Hit a rival from 12 m or more"
const HOW_GERMAN := "Triff einen Gegner mit einem Gegenstand aus 12 m oder mehr · Online oder Stages 2–9"
const HOW_ENDLESS := "Hit a rival with a thrown object from twelve metres or more away while standing on one leg and singing, online or in any campaign stage from the second to the ninth"
const HOW_JAPANESE := "12m以上離れた場所から投げた物をライバルに当てる・オンラインまたはステージ2〜9"
## Long German quest names, as real translations run.
const GERMAN: Array[String] = ["Beende 5 Online-Spiele unter den ersten drei Plätzen",
	"Erledige 10 Gegner mit der Magnetabstoßung in Online-Matches",
	"Sammle zwölf Energieverstärker in einem einzigen Wettkampf", "Spiele 3 Spiele"]
## A table's row at 1280x720, and a phone held upright.
const WIDE := 880.0
const NARROW := 336.0
## A phone held sideways: still under WIDE_WIDTH, with room for a description in a line or two.
const LANDSCAPE := 600.0
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
		await _one_line(look)
		await _described_in(look)
		host.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	_make_host()
	await _arcade_parts()
	await _art_is_registered()
	await _bar_faces()
	await _text_fits()
	await _german_fits()
	await _width_moves_the_bar()
	await _follows_config()
	await _press_once()
	await _stale_press()
	await _setters_again()
	await _no_rebuild()
	await _follows_the_look()
	await _inside_a_form()
	await _description_look()
	await _description_fits()
	await _description_grows_as_needed()
	host.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await _in_a_list()
	await _described_list()
	await frames(2)
	print("gohud reward row tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func _make_host() -> void:
	host = Control.new()
	host.theme = GoUi.theme()
	host.size = Vector2(WIDE, 700)
	root.add_child(host)


func _painted() -> bool:
	return GoUi.theme().has_stylebox(&"panel", GoRewardRow.VAR_ROW)


func _row(text := "Win 3 matches", state := GoRewardRow.State.READY, width := NARROW) -> GoRewardRow:
	var row := GoRewardRow.make(text, GoIconSet.STAR, state)
	row.set_progress(3, 5)
	row.set_reward(50, GoIconSet.COIN)
	row.set_claim_text("CLAIM")
	row.size = Vector2(width, GoRewardRow.extent())
	host.add_child(row)
	row.claim_pressed.connect(func(id: Variant) -> void: claims.append(id))
	return row


func _fixed_height(look: StringName) -> void:
	var tall := GoRewardRow.extent()
	var heights := {}
	for width: float in [NARROW, WIDE]:
		for state: int in GoRewardRow.State.values():
			for text: String in ["Go", LONG]:
				var row := _row(text, state, width)
				row.set_claim_text("BELOHNUNG ABHOLEN")
				row.set_reward(1234567, GoIconSet.COIN)
				row.set_progress(123456, 7654321)
				await frames(2)
				var least := row.get_combined_minimum_size()
				heights[least.y] = true
				check(least.y <= tall, "%s: state %d at %d stays within extent() (%s > %s)" % [look, state, width, least.y,
					tall])
				check(least.x <= width, "%s: state %d fits %d (%s)" % [look, state, width, least.x])
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
		var done: bool = state == GoRewardRow.State.CLAIMED or state == GoRewardRow.State.LOCKED
		var dim := done and not _painted()
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


## The whole row at a table's width: every part on one line, in order, and a stack of rows in columns.
func _one_line(look: StringName) -> void:
	var stack: Array[GoRewardRow] = []
	var texts := ["Go", LONG, GERMAN[0], "Win 2 matches"]
	for state: int in GoRewardRow.State.values():
		var row := _row(texts[state], state, WIDE)
		row.position.y = state * (GoRewardRow.extent() + 6.0)
		stack.append(row)
	await frames(3)
	var ready_row := stack[GoRewardRow.State.READY]
	var well: Control = ready_row.find_child("Well", true, false)
	var parts: Array[Control] = [well, ready_row.title_label, ready_row.bar, ready_row.fraction_label,
		ready_row.reward_row, ready_row.claim_button]
	var middle := ready_row.get_global_rect().get_center().y
	for index in parts.size():
		var part := parts[index]
		check(absf(part.get_global_rect().get_center().y - middle) <= 2.0, "%s: %s stands on the row's line" % [look,
			part.name])
		if index > 0:
			check(part.get_global_rect().position.x >= parts[index - 1].get_global_rect().end.x - 0.5,
				"%s: %s comes after %s" % [look, part.name, parts[index - 1].name])
	for row in stack:
		check(is_equal_approx(row.bar.global_position.x, stack[0].bar.global_position.x),
			"%s: the bars stand in one column (%s, %s)" % [look, row.bar.global_position.x, stack[0].bar.global_position.x])
		check(is_equal_approx(row.bar.size.x, stack[0].bar.size.x), "%s: the bars are one length" % look)
		check(is_equal_approx(row.fraction_label.global_position.x, stack[0].fraction_label.global_position.x),
			"%s: the fractions stand in one column" % look)
		check(is_equal_approx(row.reward_row.global_position.x, stack[0].reward_row.global_position.x),
			"%s: the payments stand in one column" % look)
	for row in stack: row.free()


func _arcade_parts() -> void:
	check(GoRewardRow.extent() >= 66.0 and GoRewardRow.extent() <= 72.0, "the row is 66-72 dp (%s)" % GoRewardRow.extent())
	var row := _row("Win 3 matches", GoRewardRow.State.READY, WIDE)
	await frames(2)
	check(row.claim_button.theme_type_variation == &"GoPillGreen", "arcade_light's pill is GoPillGreen")
	check(row.claim_button.glow, "the pill glows")
	check(row.claim_button.feedback == GoFeedback.CONFIRMED, "a claim sounds confirmed")
	check(row.title_label.theme_type_variation == GoRewardRow.VAR_TEXT, "the title wears the Rankings' lettering")
	check(row.title_label.get_theme_color(&"font_color") == GoUi.theme().get_color(&"font_color", GoRewardRow.VAR_TEXT),
		"in the Rankings' navy")
	var well := row.find_child("Well", true, false) as PanelContainer
	check(well.get_theme_stylebox(&"panel") is StyleBoxEmpty, "no plate behind the picture")
	var coin := row.reward_row.get_child(0).get_child(0) as TextureRect
	check(coin != null and coin.texture == GoUi.skin().widget_art(&"coin"), "the payment wears the painted coin")
	var look := GoUi.theme()
	var plates := {
		GoRewardRow.State.IN_PROGRESS: [GoRewardRow.VAR_ROW, GoRewardRow.VAR_BAR],
		GoRewardRow.State.READY: [GoRewardRow.VAR_ROW_READY, GoRewardRow.VAR_BAR_READY],
		GoRewardRow.State.CLAIMED: [GoRewardRow.VAR_ROW_DONE, GoRewardRow.VAR_BAR],
		GoRewardRow.State.LOCKED: [GoRewardRow.VAR_ROW_DONE, GoRewardRow.VAR_BAR],
	}
	for state: int in plates:
		row.set_state(state)
		row.refresh()
		check(row.theme_type_variation == plates[state][0], "state %d wears %s" % [state, plates[state][0]])
		check(row.get_theme_stylebox(&"panel") == look.get_stylebox(&"panel", plates[state][0]), "state %d's plate" % state)
		check(row.bar.has_faces(), "state %d's bar is painted" % state)
		var fill := row.bar.find_child("ArtFill", true, false) as Panel
		check(fill.get_theme_stylebox(&"panel") == look.get_stylebox(&"fill", plates[state][1]), "state %d's fill" % state)
	row.set_state(GoRewardRow.State.CLAIMED)
	row.refresh()
	var sticker := row.check_host.get_child(0) as TextureRect
	check(sticker != null and sticker.texture == GoUi.skin().widget_art(&"check_green"), "the check is check_green")
	check(not row.check_host.has_meta(&"gohud_badge"), "with no badge behind it")
	row.free()
	var plain := GoRewardRow.make("Plain")
	plain.set_progress(0, 0)
	plain.set_reward(0)
	host.add_child(plain)
	await frames(1)
	check(not plain.find_child("Progress", true, false).visible, "no target shows no bar")
	check(not plain.reward_row.visible, "no amount shows no payment")
	plain.free()


## Every name a game reaches through `GoUi.skin().widget_art()`, and a look without them still answering null.
func _art_is_registered() -> void:
	for art: StringName in [&"row_cyan", &"row_gold", &"row_done", &"bar_track", &"bar_blue", &"bar_green", &"value_pill",
			&"coin", &"gift", &"quest_play", &"quest_medal", &"quest_magnet", &"quest_powerup", &"quest_star",
			&"quest_flame"]:
		check(GoUi.skin().widget_art(art) != null, "%s is registered" % art)
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(1)
	check(GoUi.skin().widget_art(&"coin") == null, "a look without the art has no coin")
	var plain := _row("Plain", GoRewardRow.State.CLAIMED, WIDE)
	await frames(2)
	check(plain.reward_row.get_child(0).get_child_count() == 1, "and keeps the coin glyph")
	check(not plain.bar.has_faces(), "and its own bar")
	check(plain.check_host.has_meta(&"gohud_badge"), "and its check sticker")
	plain.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)


func _bar_faces() -> void:
	var track: StyleBox = GoUi.theme().get_stylebox(&"background", GoRewardRow.VAR_BAR)
	var fill: StyleBox = GoUi.theme().get_stylebox(&"fill", GoRewardRow.VAR_BAR)
	var bar := GoBar.new()
	bar.readout = GoBar.Readout.NONE
	bar.thickness = 26
	bar.size = Vector2(200, 26)
	host.add_child(bar)
	await frames(1)
	check(not bar.has_faces(), "a bar has no faces of its own")
	check(bar.find_child("ArtFill", true, false) == null, "and carries no extra node")
	bar.set_faces(track, null)
	check(not bar.has_faces(), "half a pair is no faces")
	bar.set_faces(track, fill)
	bar.set_values(1, 2, false)
	await frames(2)
	var art := bar.find_child("ArtFill", true, false) as Panel
	var frame := bar.find_child("Frame", true, false) as Panel
	check(frame.get_theme_stylebox(&"panel") == track, "the track is the frame")
	check(is_equal_approx(art.size.x, frame.size.x * 0.5), "the fill is as wide as the value (%s of %s)" % [art.size.x,
		frame.size.x])
	check(art.global_position == frame.global_position and art.size.y == frame.size.y,
		"at the track's own top-left and height")
	bar.set_values(1, 1000, false)
	await frames(1)
	check(art.visible and art.size.x >= 26.0, "a sliver keeps its round ends (%s)" % art.size.x)
	bar.thickness = 12
	await frames(1)
	check(art.size.x < 26.0, "and follows the bar's thickness (%s)" % art.size.x)
	bar.thickness = 26
	bar.size.x = 10.0
	await frames(2)
	check(art.get_global_rect().end.x <= frame.get_global_rect().end.x + 0.5, "a squeezed track still holds its fill (%s of %s)" % [
		art.size.x, frame.size.x])
	bar.size.x = 200.0
	await frames(2)
	check(art.size.x >= 26.0, "and it comes back with the room (%s)" % art.size.x)
	bar.set_values(0, 1000, false)
	await frames(1)
	check(not art.visible, "0 shows the bare track")
	bar.set_values(5, 10)
	await frames(30)
	check(art.visible and is_equal_approx(art.anchor_right, 0.5), "the fill follows an eased value (%s)" % art.anchor_right)
	bar.set_faces(null, null)
	await frames(1)
	check(not art.visible, "without faces the painted fill goes")
	check(frame.get_theme_stylebox(&"panel") != track, "and the look's frame comes back")
	check(bar.find_child("FillClip", true, false).visible, "with its own fill")
	bar.free()


func _text_fits() -> void:
	var base := GoRewardRow._title_size()
	var bottom := GoStyle.fit_floor(base)
	var short := _row("Go", GoRewardRow.State.READY, WIDE)
	var wide := _row("Win five online matches without falling off the arena and never once coming back")
	var huge := _row(LONG + " " + LONG + " " + LONG)
	var pill := _row("Claim", GoRewardRow.State.READY)
	pill.set_claim_text("BELOHNUNG")
	var word := _row("Claim", GoRewardRow.State.READY)
	word.set_claim_text("ABHOLEN UND SOFORT BEHALTEN")
	await frames(3)
	check(short.title_label.get_theme_font_size(&"font_size") == base, "a short title keeps the full size")
	var fitted := wide.title_label.get_theme_font_size(&"font_size")
	check(fitted < base and fitted >= bottom, "a long title shrinks to the floor at most (%d)" % fitted)
	check(huge.title_label.get_theme_font_size(&"font_size") == bottom, "an endless title stops at the floor")
	check(huge.title_label.get_visible_line_count() <= GoRewardRow.TITLE_LINES, "an endless title stays in two lines")
	check(huge.title_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "and ends in an ellipsis")
	var size := pill.claim_button.get_theme_font_size(&"font_size")
	var room := pill.claim_button.size.x - GoRewardRow.PILL_PAD * 2.0
	var font := pill.claim_button.get_theme_font(&"font")
	check(GoStyle.row_width(font, PackedStringArray(["BELOHNUNG"]), size) <= room,
		"a nine-letter word fits the pill (%d px, %s of %s)" % [size,
		GoStyle.row_width(font, PackedStringArray(["BELOHNUNG"]), size), room])
	check(word.claim_button.get_theme_font_size(&"font_size") == GoStyle.fit_floor(GoUi.font_size(GoTheme.ROLE_BODY)),
		"the claim word stops at the floor")
	check(word.claim_button.size.x == GoRewardRow.SLOT_WIDTH, "a long claim word never widens the pill")
	for node: Control in [short, wide, huge, pill, word]: node.free()


## Real German names at a table's width: whole, in two lines at most, no word broken, under the row's height.
func _german_fits() -> void:
	var base := GoRewardRow._title_size()
	var rows: Array[GoRewardRow] = []
	for text in GERMAN: rows.append(_row(text, GoRewardRow.State.READY, WIDE))
	await frames(3)
	check(rows[3].title_label.get_theme_font_size(&"font_size") == base, "a short German title keeps the full size")
	for row in rows:
		var label := row.title_label
		var px := label.get_theme_font_size(&"font_size")
		check(px >= GoStyle.fit_floor(base), "%s stays over the floor (%d)" % [row.title, px])
		check(label.get_line_count() <= GoRewardRow.TITLE_LINES, "%s wraps to two lines (%d)" % [row.title,
			label.get_line_count()])
		check(label.get_visible_line_count() >= label.get_line_count(), "%s shows whole" % row.title)
		check(label.size.y <= GoRewardRow.extent(), "%s stays inside the row" % row.title)
		for word in row.title.replace("-", " ").split(" ", false):
			check(label.get_theme_font(&"font").get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= label.size.x,
				"%s is not broken" % word)
	for row in rows: row.free()


## The fallback: below the threshold the bar, its fraction and the payment stand under the title, on one row height.
func _width_moves_the_bar() -> void:
	var row := _row("Win 3 matches", GoRewardRow.State.READY, WIDE)
	await frames(2)
	var text := row.title_label.get_parent() as BoxContainer
	var progress := row.bar.get_parent() as Control
	check(not text.vertical, "at a table's width the bar stands beside the title")
	check(row.reward_row.get_parent() != progress, "and the payment has its own column")
	row.size.x = GoRewardRow.WIDE_WIDTH - 1.0
	await frames(2)
	check(text.vertical, "under the threshold the text stacks")
	check(row.reward_row.get_parent() == progress, "and the payment joins the bar's line")
	check(row.bar.get_global_rect().position.y >= row.title_label.get_global_rect().end.y - 0.5, "the bar stands under the title")
	check(row.bar.get_global_rect().end.y <= row.get_global_rect().end.y, "and inside the row")
	var plain := _row(GERMAN[1], GoRewardRow.State.IN_PROGRESS)
	await frames(3)
	check(plain.title_label.get_visible_line_count() >= plain.title_label.get_line_count()
		or plain.title_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "a long title ends in an ellipsis")
	check(plain.title_label.get_visible_line_count() <= GoRewardRow.TITLE_LINES, "in two lines at most")
	row.size.x = WIDE
	await frames(2)
	check(not text.vertical, "wide again, the bar goes back beside the title")
	check(row.reward_row.get_parent() != progress, "and the payment to its column")
	check(row.key == null and row.title == "Win 3 matches", "moving the parts leaves the row's data alone")
	row.free()
	plain.free()
	var none := _row("Only words", GoRewardRow.State.IN_PROGRESS)
	none.set_progress(0, 0)
	await frames(2)
	check(not none.bar.visible and not none.fraction_label.visible, "no target shows no bar on a narrow row")
	check(none.reward_row.is_visible_in_tree(), "and still shows the payment")
	none.free()


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
	check(row.check_host.get_child_count() == 1, "a state set again stacks no second sticker")
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
	check(row.theme_type_variation == GoTheme.VAR_CARD and not row.bar.has_faces(), "and its card and bar with it")
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(2)
	check(row.claim_button.theme_type_variation == &"GoPillGreen", "and back")
	check(row.theme_type_variation == GoRewardRow.VAR_ROW_READY and row.bar.has_faces(), "the painted row comes back")
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


## Every look: no description is the row it always was; one stands under the title (between the title and the bar on a
## narrow row, under both on a wide one), inside the row, and the row is exactly `extent_for` tall.
func _described_in(look: StringName) -> void:
	for width: float in [NARROW, WIDE]:
		var plain := _row("Win 3 matches", GoRewardRow.State.IN_PROGRESS, width)
		plain.description = "x"
		plain.description = ""
		await frames(2)
		check(not plain.description_label.visible, "%s: no description shows none" % look)
		check(is_equal_approx(plain.custom_minimum_size.y, GoRewardRow.extent()), "%s: and the row keeps extent() (%s)" % [
			look, plain.custom_minimum_size.y])
		check(GoRewardRow.extent_for("Win 3 matches", "", width) == GoRewardRow.extent(), "%s: extent_for without one is extent()" % look)
		plain.free()
		for state: int in GoRewardRow.State.values():
			for how: String in [HOW, HOW_GERMAN, HOW_ENDLESS]:
				var row := _row(GERMAN[1], state, width)
				row.description = how
				await frames(2)
				var tall := GoRewardRow.extent_for(GERMAN[1], how, width, state)
				check(GoRewardRow.extent_for(GERMAN[1], how, width) >= tall, "%s: measured with its end column, never shorter" % look)
				check(tall > GoRewardRow.extent() or width == WIDE, "%s: a description makes a narrow row taller (%s)" % [look, tall])
				check(is_equal_approx(row.custom_minimum_size.y, tall), "%s: the row is extent_for tall (%s, %s)" % [look,
					row.custom_minimum_size.y, tall])
				check(row.get_combined_minimum_size().y <= tall + 0.5, "%s: state %d at %d stays within extent_for (%s > %s)" % [
					look, state, width, row.get_combined_minimum_size().y, tall])
				check(row.get_combined_minimum_size().x <= width, "%s: a described row fits %d" % [look, width])
				row.size = Vector2(width, tall)
				await frames(2)
				var note := row.description_label
				check(note.visible and note.text == how, "%s: the description shows" % look)
				check(note.get_global_rect().position.y >= row.title_label.get_global_rect().end.y - 0.5,
					"%s: state %d at %d: the description stands under the title" % [look, state, width])
				check(row.get_global_rect().encloses(note.get_global_rect().grow(-0.5)), "%s: and inside the row" % look)
				check(note.get_visible_line_count() <= GoRewardRow.NOTE_LINES, "%s: in two lines at most" % look)
				if width == WIDE:
					check(note.get_global_rect().position.y >= row.bar.get_global_rect().end.y - 0.5, "%s: under the bar too" % look)
					check(note.size.x > row.title_label.size.x + row.bar.size.x * 0.5, "%s: across the title and the bar" % look)
				elif row.bar.visible:
					check(row.bar.get_global_rect().position.y >= note.get_global_rect().end.y - 0.5, "%s: over the bar" % look)
				check(row.accessibility_name.contains(how), "%s: the description is spoken" % look)
				row.free()


## arcade_light: the description's own lettering — `GoRewardRowNote`, smaller than the title, its own navy.
func _description_look() -> void:
	var row := _row("Win 3 matches", GoRewardRow.State.READY, WIDE)
	row.description = HOW
	await frames(2)
	var note := row.description_label
	check(note.theme_type_variation == GoRewardRow.VAR_NOTE, "the description wears GoRewardRowNote")
	check(GoUi.theme().get_type_variation_base(GoRewardRow.VAR_NOTE) == &"Label", "a Label variation in the theme")
	check(note.get_theme_font_size(&"font_size") == GoUi.theme().get_font_size(&"font_size", GoRewardRow.VAR_NOTE),
		"a short one keeps the note's full size")
	check(note.get_theme_font_size(&"font_size") < row.title_label.get_theme_font_size(&"font_size"),
		"smaller than the title")
	check(note.get_theme_color(&"font_color") == GoUi.theme().get_color(&"font_color", GoRewardRow.VAR_NOTE),
		"in the note's ink")
	check(note.get_theme_color(&"font_color") != row.title_label.get_theme_color(&"font_color"), "softer than the title's")
	check(note.get_line_count() == 1, "a short one is one line on a wide row")
	row.set_state(GoRewardRow.State.CLAIMED)
	row.refresh()
	check(note.modulate.a == 1.0, "a painted claimed row keeps its description at full strength")
	row.free()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(1)
	var plain := _row("Win 3 matches", GoRewardRow.State.CLAIMED, WIDE)
	plain.description = HOW
	await frames(2)
	check(plain.description_label.theme_type_variation == GoTheme.VAR_CAPTION_LABEL, "another look: the caption size")
	check(plain.description_label.get_theme_color(&"font_color").is_equal_approx(GoUi.color(GoTheme.MUTED)), "in the muted ink")
	check(plain.description_label.modulate.a < 1.0, "and a claimed row dims it with its words")
	plain.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)


## Shrinks to fit two lines, never under the floor, then ends in an ellipsis; no word broken; Japanese wraps at full
## size between characters.
func _description_fits() -> void:
	var base := GoRewardRow._note_size()
	var bottom := GoStyle.fit_floor(base)
	var rows: Array[GoRewardRow] = []
	for how: String in [HOW, HOW_GERMAN, HOW_ENDLESS, HOW_JAPANESE]:
		var row := _row("Win 3 matches", GoRewardRow.State.READY, LANDSCAPE)
		row.description = how
		rows.append(row)
	await frames(3)
	for row in rows:
		var note := row.description_label
		var px := note.get_theme_font_size(&"font_size")
		check(px >= bottom and px <= base, "%s: between the floor and the full size (%d)" % [row.description, px])
		check(note.get_visible_line_count() <= GoRewardRow.NOTE_LINES, "%s: two lines at most" % row.description)
		for word in GoRewardRow._unbreakable_words(row.description):
			check(note.get_theme_font(&"font").get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= note.size.x,
				"%s is not broken" % word)
	check(rows[0].description_label.get_theme_font_size(&"font_size") == base, "a short one keeps the full size")
	check(rows[2].description_label.get_theme_font_size(&"font_size") == bottom, "an endless one stops at the floor")
	check(rows[2].description_label.get_visible_line_count() < rows[2].description_label.get_line_count(),
		"and is cut to two lines")
	check(rows[2].description_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "with an ellipsis")
	check(rows[3].description_label.get_theme_font_size(&"font_size") == base,
		"Japanese wraps between characters at the full size (%d)" % rows[3].description_label.get_theme_font_size(&"font_size"))
	check(rows[3].description_label.get_line_count() == 2, "in two lines")
	for row in rows: row.free()


## The row grows by the lines its description takes and no more.
func _description_grows_as_needed() -> void:
	var one := GoRewardRow.extent_for("Win 3 matches", HOW, LANDSCAPE)
	var two := GoRewardRow.extent_for("Win 3 matches", HOW_GERMAN, LANDSCAPE)
	var line := GoRewardRow._note_font().get_height(GoRewardRow._note_size())
	check(one > GoRewardRow.extent(), "a one-line description makes a narrow row taller (%s)" % one)
	check(two > one, "two lines make it taller still (%s > %s)" % [two, one])
	check(two - one <= line + 1.0, "by one line (%s)" % (two - one))
	check(one - GoRewardRow.extent() <= line + 1.0, "a one-line description adds one line (%s)" % (one - GoRewardRow.extent()))
	var wide := GoRewardRow.extent_for("Win 3 matches", HOW, WIDE)
	check(wide - GoRewardRow.extent() <= line + 1.0, "a wide row grows by one line at most (%s)" % (wide - GoRewardRow.extent()))
	check(GoRewardRow.extent_for("Win 3 matches", HOW_ENDLESS, LANDSCAPE) == two, "an endless one stays at two lines")
	check(GoRewardRow.extent_for("Win 3 matches", HOW_ENDLESS, NARROW) == GoRewardRow.extent_for("Win 3 matches", HOW_GERMAN,
		NARROW), "shrunk to the floor, it is no shorter than two lines at full size")


## A list of described rows takes the tallest extent_for at its width, and every row stays inside it.
func _described_list() -> void:
	var hows := [HOW, HOW_GERMAN, "", HOW_JAPANESE, HOW_ENDLESS]
	var tallest := GoRewardRow.extent()
	for index in 20: tallest = maxf(tallest, GoRewardRow.extent_for("Quest %d" % index, hows[index % hows.size()], 336.0))
	var list := GoListView.recycle(20, tallest, func() -> Control: return GoRewardRow.make(""),
		func(node: Control, index: int) -> void:
			var row := node as GoRewardRow
			row.key = index
			row.title = "Quest %d" % index
			row.description = hows[index % hows.size()]
			row.set_progress(index % 5, 5)
			row.set_reward(index + 1)
			row.set_claim_text("CLAIM")
			row.set_state(index % 4))
	list.theme = GoUi.theme()
	list.size = Vector2(336, 400)
	root.add_child(list)
	await frames(3)
	for index in list.built_indexes():
		var row := list.row(index) as GoRewardRow
		check(is_equal_approx(row.size.y, tallest), "described row %d is one extent tall (%s)" % [index, row.size.y])
		check(row.get_combined_minimum_size().y <= tallest + 0.5, "described row %d stays within it" % index)
	list.scroll_vertical = int(tallest * 6.0)
	await frames(3)
	for index in list.built_indexes():
		var row := list.row(index) as GoRewardRow
		check(row.description == hows[index % hows.size()], "a reused row shows its new description")
		check(row.description_label.visible == not row.description.is_empty(), "and hides an empty one")
	list.free()


func frames(count: int) -> void:
	for i in count: await process_frame


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
