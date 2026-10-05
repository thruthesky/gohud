## 🧪 **Checks for the comic look** — `GoStyleBoxComic`, the `comic_*` looks drawn with it, the three project-wide dials
## (`GoConfig.comic_border_width`, `comic_shadow_size`, `comic_shadow`) and the per-widget switches
## (`GoStyle.comic_shadow`, `GoStyle.comic_border`). Its own file, so it never clashes with the widgets other people
## are adding to `gohud_extra_test.gd`.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_comic_test.gd" bash addons/gohud/tools/run_tests.sh
##
## 🔑 The dials are read when a face is drawn — the checks change them on parts already built and expect the new value
##    without a rebuild, and expect no part to change size whatever they are set to.
extends SceneTree

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	# 🛑 The default `--headless` window is 64×64, and `content_scale_size` only moves the screen while stretch is on —
	#    an empty host project (CI) leaves it off. Turn it on with the phone portrait the other checks start from.
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(390, 844)
		await frames(2)
	GoUi.reset()
	GoUi.config.reduce_motion = true
	_box()
	await _comic_theme()
	await _dials()
	await _one_widget()
	await _sizes()
	await _comic_parts()
	await _window_head()
	await _states_and_sizes()
	await _one_widget_holds()
	await _joined_parts()
	await _screen()
	print("gohud comic tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


## Puts the three dials back to their defaults.
func _defaults() -> void:
	GoUi.config.comic_border_width = 3.0
	GoUi.config.comic_shadow_size = 4.0
	GoUi.config.comic_shadow = true


## The face on its own: what it reads from the settings, what it decides for itself, what it reports.
func _box() -> void:
	_defaults()
	var face := GoStyleBoxComic.new()
	check(is_equal_approx(face.border_width, 3.0), "box: the outline follows comic_border_width (%.1f)" % face.border_width)
	check(face.shadow_size == 4 and face.shadow_offset == Vector2(4, 4),
		"box: the shadow follows comic_shadow_size, down and right (%d, %s)" % [face.shadow_size, str(face.shadow_offset)])
	face.outline_scale = 0.5
	face.drop_scale = 0.5
	check(is_equal_approx(face.border_width, 1.5) and face.shadow_size == 2, "box: a small part takes a share of both")
	face.outline = 5.0
	face.drop = 7.0
	check(is_equal_approx(face.border_width, 5.0) and face.shadow_size == 7, "box: its own outline and drop win")
	face.border_width = 2.0
	check(is_equal_approx(face.outline, 2.0), "box: writing border_width sets its own outline (StyleBoxFlat's name)")
	face.shadow_size = 0
	check(face.shadow == GoStyleBoxComic.Shadow.OFF and face.shadow_size == 0, "box: writing shadow_size 0 turns its shadow off")
	var auto := GoStyleBoxComic.new()
	auto.pressed = true
	check(auto.shadow_size == 0 and auto.shows_shadow(), "box: pressed, the shadow goes (the part still has one)")
	auto.pressed = false
	auto.shadow_color = Color(0, 0, 0, 0)
	check(auto.shadow_size == 0, "box: a transparent shadow colour is no shadow")
	var drawn := GoStyleBoxComic.new()
	var rect := Rect2(0, 0, 100, 40)
	check(drawn._get_draw_rect(rect).encloses(Rect2(4, 4, 100, 40)), "box: the draw rect makes room for the shadow")
	GoUi.config.comic_shadow = false
	check(drawn._get_draw_rect(rect) == rect, "box: with shadows off nothing is drawn outside the part")
	_defaults()
	drawn.content_margin_left = 16
	drawn.content_margin_top = 10
	drawn.content_margin_right = 16
	drawn.content_margin_bottom = 10
	check(drawn.get_minimum_size() == Vector2(32, 20), "box: the minimum size is the padding — the outline adds nothing")
	var copy := drawn.duplicate() as GoStyleBoxComic
	check(copy != null and copy.outline < 0.0 and copy.content_margin_left == 16, "box: duplicate() keeps the face and its following")
	var flat := drawn.to_flat()
	check(flat.border_width_left == 3 and flat.shadow_offset == Vector2(4, 4) and flat.content_margin_left == 16,
		"box: to_flat() keeps outline, crisp shadow and padding")
	drawn.sides = GoStyleBoxComic.LEFT | GoStyleBoxComic.TOP | GoStyleBoxComic.RIGHT
	drawn.corners = GoStyleBoxComic.TOP_LEFT | GoStyleBoxComic.TOP_RIGHT
	flat = drawn.to_flat()
	check(flat.border_width_bottom == 0 and flat.border_width_top == 3 and flat.corner_radius_bottom_left == 0
		and flat.corner_radius_top_left > 0, "box: sides and corners choose where the ink and the curve go")
	# A colour check on the face actually painted still works (the readers look `bg_color` up).
	drawn.bg_color = Color("#FFEEAA")
	check(GoSkin.box_background(drawn) == Color("#FFEEAA"), "box: box_background reads a comic face")
	check(GoSkin.fade_box(drawn, 0.5) == drawn and is_equal_approx(drawn.bg_color.a, 0.5), "box: fade_box thins its face")


## The comic themes are drawn with it; the other looks are not.
func _comic_theme() -> void:
	for id: StringName in [&"comic_light", &"comic_dark"]:
		check(GoThemePresets.find(id) != null, "%s: the preset is found" % id)
		GoUi.use_preset(id)
		var theme := GoUi.theme()
		for spot: Array in [[&"Button", &"normal"], [&"GoPrimaryButton", &"normal"], [&"GoListButton", &"normal"],
				[&"LineEdit", &"normal"], [&"ProgressBar", &"fill"], [&"GoPanel", &"panel"], [&"GoCard", &"panel"],
				[&"GoHud", &"hud"], [&"PanelContainer", &"panel"], [&"GoCompactButton", &"normal"]]:
			check(theme.get_stylebox(spot[1], spot[0]) is GoStyleBoxComic, "%s: %s/%s is comic" % [id, spot[0], spot[1]])
		var key := theme.get_stylebox(&"normal", &"Button") as GoStyleBoxComic
		check(key != null and key.outline < 0.0 and key.drop < 0.0 and key.shadow == GoStyleBoxComic.Shadow.FOLLOW,
			"%s: a key leaves its outline and shadow to the settings" % id)
		var down := theme.get_stylebox(&"pressed", &"GoPrimaryButton") as GoStyleBoxComic
		check(down != null and down.pressed, "%s: a pressed key is pushed in" % id)
		var field := theme.get_stylebox(&"normal", &"LineEdit") as GoStyleBoxComic
		check(field != null and field.shadow == GoStyleBoxComic.Shadow.OFF, "%s: a text field sits flat on the page" % id)
		var row := theme.get_stylebox(&"normal", &"GoListButton") as GoStyleBoxComic
		check(row != null and row.outline_scale < 1.0 and row.shadow == GoStyleBoxComic.Shadow.OFF,
			"%s: a list row takes a thinner line and no shadow" % id)
		var ring := theme.get_stylebox(&"focus", &"GoPrimaryButton") as GoStyleBoxComic
		check(ring != null and ring.inner and not ring.draw_center, "%s: a focus ring sits inside the ink, not over it" % id)
		var raised := theme.get_stylebox(&"normal", &"GoPrimaryGlowButton") as GoStyleBoxComic
		check(raised != null and raised.shadow == GoStyleBoxComic.Shadow.ON, "%s: the raised twin keeps its shadow always" % id)
		check(key != null and key.border_color.is_equal_approx(Color(GoUi.color(GoTheme.BORDER), 1.0)),
			"%s: the ink is the theme's border colour" % id)
		check(GoUi.skin() is GoSkinComic, "%s: the skin is the comic skin" % id)
		check(GoUi.surface_alpha(GoTheme.BOX_PANEL) >= 0.999, "%s: comic panels are solid" % id)
	check(GoThemePresets.find(&"comic_dark").dark and not GoThemePresets.find(&"comic_light").dark,
		"presets: comic_dark is the dark one")
	for id: StringName in [&"default_light", &"default_dark", &"scifi_dark", &"medieval_light", &"material_light", &"kids_light"]:
		GoUi.use_preset(id)
		check(not (GoUi.theme().get_stylebox(&"normal", &"Button") is GoStyleBoxComic), "%s: keys are not comic" % id)
		check(not (GoUi.skin() is GoSkinComic), "%s: not the comic skin" % id)
	await frames(1)


## One setting reaches every part — including parts already on screen, with no rebuild.
func _dials() -> void:
	_defaults()
	GoUi.use_preset(&"comic_light")
	var key := GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY)
	var card := GoStyle.card()
	var field := GoStyle.line_edit("name")
	root.add_child(key)
	root.add_child(card)
	root.add_child(field)
	await frames(2)
	var face := key.get_theme_stylebox(&"normal") as GoStyleBoxComic
	var panel := card.get_theme_stylebox(&"panel") as GoStyleBoxComic
	check(face != null and face.shadow_size == 4 and is_equal_approx(face.border_width, 3.0), "dials: a key starts at the defaults")
	check(panel != null and panel.shadow_size > 0, "dials: a card drops its shadow")
	GoUi.config.comic_shadow = false
	check(face != null and face.shadow_size == 0, "dials: comic_shadow off — a key on screen drops none")
	check(panel != null and panel.shadow_size == 0, "dials: comic_shadow off — nor does a card")
	GoUi.config.comic_shadow = true
	GoUi.config.comic_shadow_size = 8.0
	check(face != null and face.shadow_size == 8, "dials: comic_shadow_size reaches a key on screen (%d)" % (face.shadow_size if face else -1))
	GoUi.config.comic_border_width = 1.5
	check(face != null and is_equal_approx(face.border_width, 1.5), "dials: comic_border_width reaches a key on screen")
	var line := field.get_theme_stylebox(&"normal") as GoStyleBoxComic
	check(line != null and is_equal_approx(line.border_width, 1.5) and line.shadow_size == 0,
		"dials: and a text field (which keeps no shadow)")
	_defaults()
	# The other looks do not care.
	GoUi.use_preset(&"default_light")
	var plain := GoStyle.button("Plain")
	root.add_child(plain)
	await frames(1)
	var before := plain.get_theme_stylebox(&"normal") as StyleBoxFlat
	var width := before.border_width_left if before != null else -1
	GoUi.config.comic_border_width = 9.0
	check(before != null and before.border_width_left == width, "dials: another look ignores them")
	_defaults()
	for node: Node in [key, card, field, plain]: node.queue_free()
	await frames(1)


## One widget decides for itself — over the project-wide switch, both ways, and for its children with `deep`.
func _one_widget() -> void:
	_defaults()
	GoUi.use_preset(&"comic_light")
	var quiet := GoStyle.button("Skip")
	var loud := GoStyle.button("Go")
	root.add_child(quiet)
	root.add_child(loud)
	await frames(1)
	check(GoStyle.comic_shadow(quiet, false) == quiet, "one: comic_shadow returns the node (it chains)")
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		var face := quiet.get_theme_stylebox(state) as GoStyleBoxComic
		check(face != null and face.shadow == GoStyleBoxComic.Shadow.OFF, "one: %s of the quiet key has no shadow" % state)
	check((loud.get_theme_stylebox(&"normal") as GoStyleBoxComic).shadow_size == 4, "one: the other key keeps its shadow")
	check((GoUi.theme().get_stylebox(&"normal", &"Button") as GoStyleBoxComic).shadow == GoStyleBoxComic.Shadow.FOLLOW,
		"one: the theme's face is untouched (a copy went on the key)")
	GoUi.config.comic_shadow = false
	GoStyle.comic_shadow(loud, true)
	check((loud.get_theme_stylebox(&"normal") as GoStyleBoxComic).shadow_size == 4,
		"one: a key switched on keeps its shadow with the project's off")
	_defaults()
	GoStyle.comic_border(quiet, 1.0)
	check(is_equal_approx((quiet.get_theme_stylebox(&"normal") as GoStyleBoxComic).border_width, 1.0),
		"one: comic_border sets one key's outline")
	GoUi.config.comic_border_width = 6.0
	check(is_equal_approx((quiet.get_theme_stylebox(&"normal") as GoStyleBoxComic).border_width, 1.0)
		and is_equal_approx((loud.get_theme_stylebox(&"normal") as GoStyleBoxComic).border_width, 6.0),
		"one: it keeps it while the others follow the setting")
	GoStyle.comic_border(quiet, -1.0)
	check(is_equal_approx((quiet.get_theme_stylebox(&"normal") as GoStyleBoxComic).border_width, 6.0),
		"one: a negative width hands it back to the setting")
	_defaults()
	var card := GoStyle.card()
	var inside := GoStyle.button("Inside")
	card.add_child(inside)
	root.add_child(card)
	await frames(1)
	GoStyle.comic_shadow(card, false, true)
	check((card.get_theme_stylebox(&"panel") as GoStyleBoxComic).shadow_size == 0
		and (inside.get_theme_stylebox(&"normal") as GoStyleBoxComic).shadow_size == 0, "one: deep reaches the children")
	GoUi.use_preset(&"default_light")
	var flat := GoStyle.button("Flat")
	root.add_child(flat)
	await frames(1)
	GoStyle.comic_shadow(flat, false)
	check(not flat.has_theme_stylebox_override(&"normal"), "one: under another look it does nothing")
	for node: Node in [quiet, loud, card, flat]: node.queue_free()
	await frames(1)


## Nothing moves: a part has the same size whatever the outline and the shadow are.
func _sizes() -> void:
	_defaults()
	for id: StringName in [&"comic_light", &"comic_dark"]:
		GoUi.use_preset(id)
		var row := VBoxContainer.new()
		var parts: Array[Control] = [GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY), GoStyle.button("Back"),
			GoStyle.line_edit("name"), GoStyle.card(), GoStyle.chip("Fire", GoUi.color(GoTheme.DANGER))]
		for part in parts: row.add_child(part)
		root.add_child(row)
		await frames(2)
		var start: Array[Vector2] = []
		for part in parts: start.append(part.get_combined_minimum_size())
		var states := [[0.0, 0.0, false], [10.0, 16.0, true], [1.0, 2.0, true]]
		var same := true
		for state: Array in states:
			GoUi.config.comic_border_width = state[0]
			GoUi.config.comic_shadow_size = state[1]
			GoUi.config.comic_shadow = state[2]
			await frames(1)
			for index in parts.size():
				if not parts[index].get_combined_minimum_size().is_equal_approx(start[index]): same = false
		check(same, "%s: no part changes size with the outline or the shadow" % id)
		var key := parts[0] as Button
		var heights: Array[float] = []
		for state in [&"normal", &"hover", &"pressed", &"disabled"]:
			heights.append(key.get_theme_stylebox(state).get_minimum_size().y)
		check(heights.max() - heights.min() < 0.01, "%s: a key's face is the same height in every state %s" % [id, str(heights)])
		_defaults()
		row.queue_free()
	await frames(1)


## The parts the comic skin draws in code — and the dials reach them too.
func _comic_parts() -> void:
	_defaults()
	GoUi.use_preset(&"comic_light")
	var skin := GoUi.skin()
	var idle := skin.slot_box(GoUi.color(GoTheme.INFO), false) as GoStyleBoxComic
	var lit := skin.slot_box(GoUi.color(GoTheme.INFO), true) as GoStyleBoxComic
	check(idle != null and not idle.pressed and idle.shadow_size > 0, "parts: a quick slot is an inked panel with a shadow")
	# 🛑 Not pushed in — the same face marks a code input's current cell and today on a calendar, which stood out of line.
	check(lit != null and not lit.pressed and lit.shadow_size > 0 and not lit.border_color.is_equal_approx(idle.border_color),
		"parts: a lit slot keeps its place and lights its ink")
	var chip := skin.chip_box(GoUi.color(GoTheme.SUCCESS)) as GoStyleBoxComic
	check(chip != null and chip.outline_scale < 1.0 and chip.radius <= 13.0, "parts: a chip is a bubble the cell audit can hold")
	check(GoSkin.contrast_ratio(skin.chip_ink(GoUi.color(GoTheme.SUCCESS)), chip.bg_color) >= 4.5,
		"parts: a chip's label reads on its face")
	var badge := skin.badge_box(GoUi.color(GoTheme.DANGER)) as GoStyleBoxComic
	check(badge != null and badge.shadow_size == 0, "parts: a badge is a flat sticker")
	var ring := skin.coach_ring_box(GoUi.color(GoTheme.ACCENT)) as GoStyleBoxComic
	check(ring != null and ring.border_color.is_equal_approx(GoUi.color(GoTheme.ACCENT)), "parts: the coach ring stays in its colour")
	var first := skin.segment_box(0, 3, &"normal") as GoStyleBoxComic
	var middle := skin.segment_box(1, 3, &"normal") as GoStyleBoxComic
	var chosen := skin.segment_box(1, 3, &"pressed") as GoStyleBoxComic
	check(first != null and middle != null and first.corners & GoStyleBoxComic.TOP_LEFT and middle.corners == 0
		and not (middle.sides & GoStyleBoxComic.LEFT), "parts: a segmented row is one inked block, round at its ends")
	check(first != null and first.shadow_size > 0 and chosen != null and not chosen.pressed and chosen.shadow_size > 0,
		"parts: the row drops one shadow — the chosen cell is not pushed out of it")
	# The strips (a heading's line, the bars) follow the setting as they are drawn, not as they were built.
	var heading := skin.section_box() as GoStyleBoxComic
	var bar := skin.app_bar_box(false) as GoStyleBoxComic
	GoUi.config.comic_border_width = 6.0
	check(heading != null and bar != null and heading.border_width > 3.0 and is_equal_approx(bar.border_width, 6.0),
		"parts: a heading's line and the app bar's follow comic_border_width live")
	_defaults()
	for id: StringName in [&"comic_light", &"comic_dark"]:
		GoUi.use_preset(id)
		# 🛑 At night the accent and the warning are both yellow — a chart's first slices must not be the two.
		var colours := GoUi.skin().chart_colors()
		var apart := true
		for i in 4:
			for j in range(i + 1, 4):
				var a := Vector3(colours[i].r, colours[i].g, colours[i].b)
				if a.distance_to(Vector3(colours[j].r, colours[j].g, colours[j].b)) < 0.25: apart = false
		check(apart, "parts: %s's first four chart colours are told apart" % id)
	GoUi.use_preset(&"comic_light")
	skin = GoUi.skin()
	for id: StringName in [&"comic_light", &"comic_dark"]:
		GoUi.use_preset(id)
		var plate := GoUi.skin().title_plate_box() as GoStyleBoxComic
		check(plate != null and GoSkin.contrast_ratio(plate.border_color, plate.bg_color) >= 3.0,
			"parts: %s's caption box shows its line (%.1f:1)" % [id, GoSkin.contrast_ratio(plate.border_color, plate.bg_color) if plate else 0.0])
	GoUi.use_preset(&"comic_light")
	skin = GoUi.skin()
	check(skin.refresh_disc_box() is GoStyleBoxComic and skin.wheel_band_box() is GoStyleBoxComic
		and skin.time_selector_box(true, &"normal") is GoStyleBoxComic, "parts: the refresh disc, the wheel band and the time boxes are inked")
	var disc := GoStyle.disc(40, GoUi.color(GoTheme.ACCENT))
	check(disc.border_width_left >= 2 and disc.border_color.is_equal_approx(skin.ink()), "parts: GoStyle.disc() keeps the ink")
	var floating_flat := GoStyle.floating()
	check(floating_flat.shadow_size == 1 and floating_flat.shadow_offset.x > 0.0, "parts: GoStyle.floating() keeps a hard shadow, not a blur")
	var floating := skin.floating_box(GoTheme.BOX_HUD) as GoStyleBoxComic
	check(floating != null and floating.shadow_size == 6, "parts: a floating panel drops a deeper shadow (%d)" % (floating.shadow_size if floating else -1))
	var fill := skin.progress_fill_box(GoUi.color(GoTheme.WARNING_FILL)) as GoStyleBoxComic
	check(fill != null and fill.border_color.is_equal_approx(skin.ink()), "parts: a bar fill keeps its ink however pale")
	GoUi.config.comic_shadow = false
	check(idle.shadow_size == 0 and floating.shadow_size == 0, "parts: the shadow switch reaches the skin's parts")
	_defaults()
	var flat := GoStyle.box(GoTheme.BOX_CARD)
	check(flat.border_width_left == 3 and flat.shadow_size == 1 and flat.shadow_offset == Vector2(4, 4),
		"parts: GoStyle.box() keeps the ink and a crisp shadow (%d, %d, %s)" % [flat.border_width_left, flat.shadow_size, str(flat.shadow_offset)])
	await frames(1)


## A window's head in the comic look: a caption box behind the title, an inked close button — and plain again after.
func _window_head() -> void:
	GoUi.use_preset(&"comic_dark")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var surface := GoSurface.new()
	surface.max_width = 300
	surface.set_title("Settings")
	layer.add_child(surface)
	await frames(3)
	var plate := surface.title_label.get_theme_stylebox(&"normal") as GoStyleBoxComic
	check(plate != null, "head: the title sits in a caption box")
	# 🛑 7:1, not 4.5 — the night look's light text pushed onto the yellow box passed 4.5 as a dull grey.
	for id: StringName in [&"comic_light", &"comic_dark"]:
		GoUi.use_preset(id)
		var box := GoUi.skin().title_plate_box() as GoStyleBoxComic
		var ratio := GoSkin.contrast_ratio(GoUi.skin().title_plate_ink(), box.bg_color) if box != null else 0.0
		check(ratio >= 7.0, "head: %s's title reads boldly in the caption box (%.1f:1)" % [id, ratio])
	GoUi.use_preset(&"comic_dark")
	await frames(2)
	check(surface.close_button.get_theme_stylebox(&"normal") is GoStyleBoxComic, "head: the close button is inked")
	GoUi.use_preset(&"default_light")
	await frames(3)
	check(not surface.title_label.has_theme_stylebox_override(&"normal"), "head: another look takes the caption off")
	layer.queue_free()
	await frames(1)


## A whole screen of parts builds and draws under both comic looks, with shadows on and off.
func _screen() -> void:
	for id: StringName in [&"comic_light", &"comic_dark"]:
		GoUi.use_preset(id)
		for shadows in [true, false]:
			GoUi.config.comic_shadow = shadows
			var column := VBoxContainer.new()
			column.size = Vector2(360, 800)
			for part: Control in [GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY), GoStyle.button("Delete", Callable(),
					GoStyle.Tone.DANGER_SOLID), GoStyle.button("Outlined", Callable(), GoStyle.Tone.OUTLINED), GoStyle.line_edit("name"),
					GoStyle.progress(GoUi.color(GoTheme.SUCCESS_FILL)), GoStyle.chip("Ice", GoUi.color(GoTheme.INFO)),
					GoStyle.card(), GoStyle.hud_panel()]:
				column.add_child(part)
			var tick := CheckBox.new()
			tick.text = "Agree"
			column.add_child(tick)
			var slider := HSlider.new()
			column.add_child(slider)
			root.add_child(column)
			await frames(2)
			check(column.get_child_count() == 10 and column.is_inside_tree(), "%s: a screen builds (shadows %s)" % [id, shadows])
			column.queue_free()
	_defaults()
	await frames(1)


## Every state the comic look tells apart, and every face keeps the padding the default look gives it.
func _states_and_sizes() -> void:
	_defaults()
	for pair: Array in [[&"comic_light", &"default_light"], [&"comic_dark", &"default_dark"]]:
		GoUi.use_preset(pair[1])
		var plain := GoUi.theme()
		GoUi.use_preset(pair[0])
		var theme := GoUi.theme()
		var id: StringName = pair[0]
		# 🛑 Sizes: a face's padding decides its control's minimum size — a 1dp track padded 0 shrank a ProgressBar.
		var moved: Array[String] = []
		for type in plain.get_stylebox_type_list():
			for name in plain.get_stylebox_list(type):
				if not theme.has_stylebox(name, type): continue
				var a := plain.get_stylebox(name, type)
				var b := theme.get_stylebox(name, type)
				for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					if not is_equal_approx(a.get_margin(side), b.get_margin(side)):
						moved.append("%s/%s" % [type, name])
						break
		check(moved.is_empty(), "%s: every face keeps the default look's padding %s" % [id, str(moved)])
		var pushed := theme.get_stylebox(&"pressed", &"GoDangerButton") as GoStyleBoxComic
		check(pushed != null and pushed.pressed, "%s: a danger key is pushed in when pressed" % id)
		var small := theme.get_stylebox(&"pressed", &"GoCompactButton") as GoStyleBoxComic
		check(small != null and small.pressed, "%s: a compact key is pushed in when pressed" % id)
		for type: StringName in [&"GoCompactButton", &"GoListButton", &"Button"]:
			var off := theme.get_stylebox(&"disabled", type) as GoStyleBoxComic
			var on := theme.get_stylebox(&"normal", type) as GoStyleBoxComic
			check(off != null and on != null and off.shadow == GoStyleBoxComic.Shadow.OFF and off.border_color.a < on.border_color.a,
				"%s: a disabled %s sits flat with faint ink" % [id, type])
		for type: StringName in [&"GoCompactButton", &"GoListButton", &"CheckBox", &"TabBar"]:
			var name := &"tab_focus" if type == &"TabBar" else &"focus"
			var ring := theme.get_stylebox(name, type) as GoStyleBoxComic
			check(ring != null and ring.inner and not ring.draw_center, "%s: %s's focus ring sits inside the ink" % [id, type])
		var menu := theme.get_stylebox(&"panel", &"PopupMenu") as GoStyleBoxComic
		check(menu != null and menu.shadow == GoStyleBoxComic.Shadow.OFF, "%s: a popup menu (its own window) drops no shadow to be cut" % id)
		var raised := theme.get_stylebox(&"normal", &"GoPrimaryGlowButton") as GoStyleBoxComic
		var key := theme.get_stylebox(&"normal", &"GoPrimaryButton") as GoStyleBoxComic
		check(raised != null and key != null and raised.shadow_size >= key.shadow_size + 2, "%s: the raised twin clearly stands higher" % id)
		var fill := theme.get_stylebox(&"grabber_area", &"HSlider") as GoStyleBoxComic
		check(fill != null and fill.bg_color.a >= 0.999 and fill.border_width < 1.5, "%s: a slider's fill is solid with a thin line" % id)
		# 🛑 A shadow has to show on the page: a black block on the night page measured 1.1:1.
		var page := GoUi.color(GoTheme.BACKGROUND)
		var shaded := page.blend(key.shadow_color) if key != null else page
		check(GoSkin.contrast_ratio(shaded, page) >= 1.2, "%s: a key's shadow shows on the page (%.2f:1)" % [id, GoSkin.contrast_ratio(shaded, page)])
		var skin_face := GoUi.skin().slot_box(GoUi.color(GoTheme.INFO), false) as GoStyleBoxComic
		check(skin_face != null and key != null and skin_face.shadow_color.is_equal_approx(key.shadow_color),
			"%s: the skin's parts drop the theme's shadow colour" % id)
		var tab := theme.get_stylebox(&"tab_unselected", &"TabBar") as GoStyleBoxComic
		check(tab != null and tab.sides == GoStyleBoxComic.BOTTOM, "%s: the other tabs stand on an ink line" % id)
	await frames(1)


## A widget's own choice outlives a change of the project's dials, and never reaches what is flat on purpose.
func _one_widget_holds() -> void:
	_defaults()
	GoUi.use_preset(&"comic_light")
	# 🛑 Called before the key is in the tree (the documented chain) — it used to find no comic face there.
	var early := GoStyle.comic_shadow(GoStyle.button("Skip"), false) as Button
	check(early.has_theme_stylebox_override(&"normal") and (early.get_theme_stylebox(&"normal") as GoStyleBoxComic).shadow_size == 0,
		"hold: comic_shadow works on a key not yet in the tree")
	var key := GoStyle.button("Go")
	root.add_child(key)
	root.add_child(early)
	await frames(1)
	GoStyle.comic_shadow(key, true)
	var ring := key.get_theme_stylebox(&"focus") as GoStyleBoxComic
	var off := key.get_theme_stylebox(&"disabled") as GoStyleBoxComic
	check(ring != null and ring.shadow_size == 0 and off != null and off.shadow_size == 0,
		"hold: switching a key's shadow on leaves its focus ring and disabled face flat")
	GoStyle.comic_border(key, 8.0)
	ring = key.get_theme_stylebox(&"focus") as GoStyleBoxComic
	check(ring != null and is_equal_approx(ring.inset, 9.0) and ring.border_width < 8.0,
		"hold: a wider ink moves the focus ring in, and the ring keeps its own line")
	GoStyle.comic_border(key, 0.0)
	ring = key.get_theme_stylebox(&"focus") as GoStyleBoxComic
	check(ring != null and ring.border_width > 0.0, "hold: no ink on a key still leaves its focus ring")
	var card := GoStyle.card()
	var field := GoStyle.line_edit("name")
	card.add_child(field)
	root.add_child(card)
	await frames(1)
	GoStyle.comic_shadow(card, true, true)
	check((field.get_theme_stylebox(&"normal") as GoStyleBoxComic).shadow_size == 0,
		"hold: deep leaves a text field inside flat")
	# A watching widget (a window) keeps the choice when the project's dials change.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var surface := GoSurface.new()
	surface.max_width = 300
	surface.set_title("Quiet")
	layer.add_child(surface)
	await frames(2)
	GoStyle.comic_shadow(surface, false, true)
	var refreshed := [false]
	var spy := func() -> void: refreshed[0] = true
	GoUi.watch(spy)
	GoUi.config.comic_shadow = true
	GoUi.config.comic_shadow_size = 9.0
	GoUi.config.comic_border_width = 2.0
	await frames(2)
	GoUi.unwatch(spy)
	check(not refreshed[0], "hold: a comic dial only redraws — it does not re-dress every widget")
	var close_face := surface.close_button.get_theme_stylebox(&"normal") as GoStyleBoxComic
	check(close_face != null and close_face.shadow_size == 0, "hold: a window's own choice outlives the dials changing")
	_defaults()
	for node: Node in [key, early, card, layer]: node.queue_free()
	await frames(1)


## Parts that join into one (an input group) or stripe (a table) keep the comic ink.
func _joined_parts() -> void:
	_defaults()
	GoUi.use_preset(&"comic_light")
	var send := GoStyle.button("Send", Callable(), GoStyle.Tone.PRIMARY)
	var group := GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": send})
	root.add_child(group)
	await frames(2)
	var left := group.control.get_theme_stylebox(&"normal") as GoStyleBoxComic
	var right := send.get_theme_stylebox(&"normal") as GoStyleBoxComic
	check(left != null and right != null and not (left.corners & GoStyleBoxComic.TOP_RIGHT)
		and not (right.sides & GoStyleBoxComic.LEFT) and right.corners & GoStyleBoxComic.TOP_RIGHT,
		"joined: an input group is one inked block with one line at the seam")
	var table := GoTable.make([{"text": "Name"}, {"text": "Score", "numeric": true}], [["Aria", 3], ["Brin", 2], ["Cade", 1]])
	root.add_child(table)
	await frames(2)
	var striped := 0
	for row in table.rows_box.get_children():
		var face := (row as Control).get_theme_stylebox(&"normal") if row is Button else null
		if face is GoStyleBoxComic: striped += 1
	check(striped == table.rows_box.get_child_count(), "joined: every table row keeps its ink, striped or not (%d)" % striped)
	for node: Node in [group, table]: node.queue_free()
	await frames(1)
