## 🧪 **Checks for the arcade look** — `GoStyleBoxArcade`, the `arcade_*` looks drawn with it, the arcade skin's parts,
## the window title's outline hook (`GoSkin.dress_title`) and the per-widget paint (`GoStyle.arcade_paint`). Its own
## file, so it never clashes with the widgets other people are adding to `gohud_extra_test.gd`.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_arcade_test.gd" bash addons/gohud/tools/run_tests.sh
##
## 🔑 Every label on a painted key is white with an ink outline — the checks hold every paint to the bar that label
##    clears (`GoStyleBoxArcade.LABEL_NEED`), and the other looks must come through untouched.
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
	await _arcade_theme()
	await _other_looks()
	await _arcade_parts()
	await _window_head()
	await _bar_segments()
	await _one_widget()
	await _own_ink()
	await _screen()
	print("gohud arcade tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func _margins(box: StyleBox) -> Array[float]:
	var out: Array[float] = []
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: out.append(box.get_margin(side))
	return out


## Saturation enough to call a face painted, not grey.
func _painted(colour: Color) -> bool:
	return colour.s >= 0.25


## The face on its own: the three tones, the paint that fits a white outlined label, a key and a board.
func _box() -> void:
	var ink := Color("#1B2146")
	var three := GoStyleBoxArcade.tones(Color("#3570EA"))
	check(three.size() == 3 and three[0].get_luminance() > three[1].get_luminance()
		and three[1].get_luminance() > three[2].get_luminance(), "box: the tones run light top → bottom → deeper lip")
	# Paints from every corner of the wheel, the dead band (where neither white nor ink reads well) among them.
	for hex in ["#4ACB3E", "#3570EA", "#E3343D", "#FFB21E", "#9A97CF", "#2FA84F", "#7A7A7A", "#C04A9A", "#FFFFFF", "#000000"]:
		var fitted := GoStyleBoxArcade.fit(Color(hex), ink)
		check(GoStyleBoxArcade.worst_label(fitted, ink) >= GoStyleBoxArcade.LABEL_NEED,
			"box: fit(%s) gives a paint a white outlined label reads on (%.2f:1)" % [hex,
				GoStyleBoxArcade.worst_label(fitted, ink)])
	var fine := Color("#1B5CD0")
	if GoStyleBoxArcade.worst_label(fine, ink) >= GoStyleBoxArcade.LABEL_NEED:
		check(GoStyleBoxArcade.fit(fine, ink) == fine, "box: a paint that already reads is left as it is")
	check(GoStyleBoxArcade.fit(Color(0.3, 0.5, 0.9, 0.4), ink).a == 1.0, "box: a fitted paint is solid")
	# A key: the paint goes on the body.
	var key := GoStyleBoxArcade.new()
	key.border_color = ink
	key.paint(Color("#4ACB3E"))
	var green := GoStyleBoxArcade.tones(Color("#4ACB3E"))
	check(key.bg_color == green[0] and key.bottom_color == green[1] and key.shade_color == green[2],
		"box: paint() lays the three tones on a key's body")
	check(key.top() == key.bg_color and key.bottom() == key.bottom_color, "box: a key's gradient runs over its body")
	check(key.paint(Color.RED) == key, "box: paint() returns the face (it chains)")
	var auto := GoStyleBoxArcade.new()
	auto.bg_color = Color("#3570EA")
	auto.border_color = ink
	check(auto.bottom().get_luminance() < auto.top().get_luminance(), "box: without a bottom colour, the body a little deeper")
	check(auto.shade().b > auto.shade().r, "box: the lip stays the body's hue, towards the ink — not grey")
	# A board: the paint goes on the frame, the well keeps its colour.
	var board := GoStyleBoxArcade.new()
	board.bg_color = Color("#FFFFFF")
	board.frame = 6.0
	board.paint(Color("#3570EA"))
	check(board.bg_color == Color("#FFFFFF"), "box: on a board, paint() leaves the well alone")
	check(board.frame_color == GoStyleBoxArcade.tones(Color("#3570EA"))[0] and board.top() == board.frame_color,
		"box: on a board, the frame takes the paint")
	check(board.well_bottom().get_luminance() < 1.0, "box: the well has a gradient of its own")
	# The rest is the jelly box it extends: padding kept, the readers that look `bg_color` up.
	var flat := StyleBoxFlat.new()
	flat.content_margin_left = 16
	flat.content_margin_top = 8
	flat.content_margin_right = 16
	flat.content_margin_bottom = 12
	var kept := GoStyleBoxArcade.new().keep_margins(flat)
	check(_margins(kept) == _margins(flat), "box: keep_margins copies every side (%s)" % str(_margins(kept)))
	check(kept is GoStyleBoxJelly, "box: an arcade face is a jelly face — every reader of one reads it")
	check(kept.get_minimum_size() == Vector2(32, 20), "box: the minimum size is the padding — the lip and frame add nothing")
	var copy := board.duplicate() as GoStyleBoxArcade
	check(copy != null and copy.frame == board.frame and copy.frame_color == board.frame_color, "box: duplicate() keeps the face")
	check(GoSkin.box_background(key).a > 0.0, "box: box_background reads an arcade face")
	# The frame never covers the content: a board padded too little for it draws it thinner, one with no room for a
	# frame of MIN_FRAME is drawn as a key cap; one with no padding at all (a window's card pads its content itself)
	# keeps it whole.
	check(board.frame_drawn() == 6.0, "box: a board with no padding draws its whole frame")
	var tight := board.duplicate() as GoStyleBoxArcade
	tight.border_width = 3.0
	tight.lip = 3.0
	tight.set_content_margin_all(12.0)
	check(is_equal_approx(tight.frame_drawn(), 3.0),
		"box: padded 12, the frame gives way to the ink, the lip and the well — 12 − 3 lip − 3 ink − 3 well (%.1f)"
		% tight.frame_drawn())
	tight.content_margin_bottom = 1.0
	check(tight.frame_drawn() == 0.0, "box: padded to nothing, no frame — not a hairline (%.1f)" % tight.frame_drawn())
	check(tight.top() == tight.bg_color, "box: a board with no room for its frame is drawn as a key cap in the well's colour")
	tight.set_content_margin_all(12.5)
	check(tight.frame_drawn() >= GoStyleBoxArcade.MIN_FRAME, "box: a frame is drawn at MIN_FRAME or not at all")
	tight.set_content_margin_all(20.0)
	check(tight.frame_drawn() == 6.0, "box: padded enough, the whole frame")
	# As a flat face (`GoStyle.box()`, `GoStyle.floating()` promise one): a board keeps its frame as the border.
	board.border_width = 3.0
	board.border_color = ink
	var flat_board := board.to_flat()
	check(flat_board.border_width_top == 9 and flat_board.border_color.b > flat_board.border_color.r
		and flat_board.bg_color == board.bg_color, "box: to_flat() turns a board's frame into its border round the well")
	var flat_key := key.to_flat()
	check(flat_key.border_color == ink and flat_key.bg_color == key.bg_color, "box: to_flat() keeps a key's ink round its top")
	# 🍬 The candy gloss is the default; the old single stroke stays one field away.
	check(GoStyleBoxArcade.new().gloss == GoStyleBoxArcade.Gloss.CANDY, "box: a key wears the candy gloss by default")
	# 🎀 A ribbon: the tails are drawn inside the face, cut back on a narrow one, and never add to its size.
	var ribbon := GoStyleBoxArcade.new()
	check(ribbon.ribbon_tails(Rect2(0, 0, 200, 40)) == 0.0, "box: no tails by default — a plain key")
	ribbon.tails = 12.0
	ribbon.pad(32.0, 6.0)
	check(ribbon.ribbon_tails(Rect2(0, 0, 200, 40)) == 12.0, "box: a ribbon folds its tails")
	check(ribbon.ribbon_tails(Rect2(0, 0, 40, 40)) == 10.0, "box: on a narrow face the tails give way — the body keeps half")
	check(ribbon.ribbon_tails(Rect2(0, 0, 200, 8)) == 0.0, "box: a face too thin to fold has no tails")
	check(ribbon.get_minimum_size() == Vector2(64, 12), "box: the tails add nothing to the minimum size — the padding is it")
	ribbon.sunken = true
	check(ribbon.ribbon_tails(Rect2(0, 0, 200, 40)) == 0.0, "box: a field turned in is never a ribbon")


## The arcade themes: every key painted, with a gradient and a white ink-outlined label; boards with a frame.
func _arcade_theme() -> void:
	for id: StringName in [&"arcade_light", &"arcade_dark"]:
		GoUi.use_preset(id)
		var theme := GoUi.theme()
		check(GoUi.skin() is GoSkinArcade, "%s: the skin is the arcade skin" % id)
		var ink := (GoUi.skin() as GoSkinArcade).ink()
		for type: StringName in [&"Button", &"GoPrimaryButton", &"GoDangerButton", &"GoDangerSolidButton", &"GoCompactButton"]:
			var face := theme.get_stylebox(&"normal", type) as GoStyleBoxArcade
			check(face != null, "%s: %s is an arcade key" % [id, type])
			if face == null: continue
			check(_painted(face.bg_color), "%s: %s is painted, not grey (%s)" % [id, type, face.bg_color.to_html(false)])
			check(face.top() != face.bottom(), "%s: %s has a gradient" % [id, type])
			check(face.lip > 0.0 and face.border_width >= 2.0 and face.shine > 0.0,
				"%s: %s has a lip, an ink outline and a gloss" % [id, type])
			for state: StringName in [&"normal", &"hover", &"pressed"]:
				var at := theme.get_stylebox(state, type) as GoStyleBoxArcade
				if at == null: continue
				var worst := INF
				for step in 5: worst = minf(worst, maxf(GoSkin.contrast_ratio(Color.WHITE, at.top().lerp(at.bottom(), step / 4.0)),
					GoSkin.contrast_ratio(at.edge(), at.top().lerp(at.bottom(), step / 4.0))))
				check(worst >= 4.5, "%s: %s/%s carries its white outlined label (%.2f:1)" % [id, type, state, worst])
			check(theme.get_color(&"font_color", type) == Color.WHITE and theme.get_constant(&"outline_size", type) > 0,
				"%s: %s's label is white with an outline" % [id, type])
			check(theme.get_color(&"font_outline_color", type).is_equal_approx(ink), "%s: %s's outline is the ink" % [id, type])
		var hues := {}
		for type: StringName in [&"Button", &"GoPrimaryButton", &"GoDangerSolidButton"]:
			hues[type] = (theme.get_stylebox(&"normal", type) as GoStyleBoxArcade).bg_color.h
		check(absf(hues[&"Button"] - hues[&"GoPrimaryButton"]) > 0.1 and absf(hues[&"GoPrimaryButton"] - hues[&"GoDangerSolidButton"]) > 0.1,
			"%s: the plain, primary and danger keys are different paints" % id)
		var down := theme.get_stylebox(&"pressed", &"GoPrimaryButton") as GoStyleBoxArcade
		check(down != null and down.pressed, "%s: a pressed key sinks" % id)
		# 💊 The keys are pills; the tabs stand apart; the slider's groove is chunky but inside its knob.
		var pill := theme.get_stylebox(&"normal", &"Button") as GoStyleBoxArcade
		check(pill != null and pill.radius >= 20.0, "%s: a key is round as a pill (%.0f)" % [id, pill.radius if pill else 0.0])
		var focus := theme.get_stylebox(&"focus", &"Button") as GoStyleBoxArcade
		check(focus != null and pill != null and is_equal_approx(focus.radius, pill.radius - pill.border_width),
			"%s: the focus ring follows the key's round corner" % id)
		var apart := theme.get_stylebox(&"tab_unselected", &"TabBar") as GoStyleBoxArcade
		check(apart != null and apart.expand_margin_left < 0.0 and apart.expand_margin_right < 0.0,
			"%s: the tabs stand apart in their row" % id)
		var groove := theme.get_stylebox(&"slider", &"HSlider")
		var knob := theme.get_icon(&"grabber", &"HSlider")
		check(groove.get_minimum_size().y >= 10.0 and knob != null and groove.get_minimum_size().y <= knob.get_size().y,
			"%s: a chunky slider groove that still sits inside its knob (%.0f in %.0f)"
			% [id, groove.get_minimum_size().y, knob.get_size().y if knob else 0.0])
		var well := theme.get_stylebox(&"normal", &"LineEdit") as GoStyleBoxArcade
		check(well != null and well.sunken, "%s: a text field is a well" % id)
		for spot: Array in [[&"GoPanel", &"panel"], [&"GoCard", &"panel"], [&"GoHud", &"hud"]]:
			var board := theme.get_stylebox(spot[1], spot[0]) as GoStyleBoxArcade
			check(board != null and board.frame >= 4.0 and board.frame_drawn() == board.frame and _painted(board.frame_color),
				"%s: %s/%s is a thick board with a painted frame, padded to hold it whole" % [id, spot[0], spot[1]])
		var tab := theme.get_stylebox(&"tab_unselected", &"TabBar") as GoStyleBoxArcade
		check(tab != null and tab.draw_center and _painted(tab.bg_color), "%s: an unselected tab is a painted key too" % id)
		check(theme.get_constant(&"outline_size", &"CheckBox") == 0 and theme.get_constant(&"outline_size", &"GoListButton") == 0,
			"%s: text that sits on the page (a check box, a list row) has no outline" % id)
		# 🔑 Not "grey": the night look's dim face is its navy surface. It loses the paint, the gloss and the white label.
		var disabled := theme.get_stylebox(&"disabled", &"Button") as GoStyleBoxArcade
		var live := theme.get_stylebox(&"normal", &"Button") as GoStyleBoxArcade
		check(disabled != null and disabled.bg_color != live.bg_color and disabled.shine == 0.0
			and theme.get_color(&"font_disabled_color", &"Button") != Color.WHITE,
			"%s: a disabled key loses its paint, its gloss and its white label" % id)
		# A key keeps its size from state to state — no jump as it is pressed.
		var key := GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY)
		root.add_child(key)
		await frames(2)
		var heights: Array[float] = []
		for state in [&"normal", &"hover", &"pressed", &"disabled"]:
			heights.append(key.get_theme_stylebox(state).get_minimum_size().y)
		check(heights.max() - heights.min() < 0.01, "%s: a key's face is the same height in every state %s" % [id, str(heights)])
		key.queue_free()
	await frames(1)


## The looks that are not arcade come through untouched.
func _other_looks() -> void:
	for id: StringName in [&"default_light", &"default_dark", &"kids_light", &"comic_light", &"material_dark"]:
		GoUi.use_preset(id)
		check(not (GoUi.theme().get_stylebox(&"normal", &"Button") is GoStyleBoxArcade), "%s: keys are not arcade" % id)
		check(GoUi.theme().get_constant(&"outline_size", &"Button") == 0, "%s: a key's label has no outline" % id)
		check(not (GoUi.skin() is GoSkinArcade), "%s: the skin is not the arcade one" % id)
		check(GoUi.skin().bar_ticks() == 0, "%s: a bar is one smooth bar" % id)
		check(GoUi.skin().kbd_ink() == GoUi.color(GoTheme.SECONDARY)
			and GoUi.skin().kbd_box().get_class() == GoUi.skin().chip_box(GoUi.color(GoTheme.BORDER)).get_class(),
			"%s: a key hint is the chip it always was" % id)
	await frames(1)


## The parts the arcade skin draws in code.
func _arcade_parts() -> void:
	for id: StringName in [&"arcade_light", &"arcade_dark"]:
		GoUi.use_preset(id)
		var skin := GoUi.skin() as GoSkinArcade
		var page := GoUi.color(GoTheme.BACKGROUND)
		if id == &"arcade_dark":
			check(skin.ink().get_luminance() < page.get_luminance(), "%s: at night the ink is the page, deeper" % id)
		else:
			check(skin.ink() == Color(GoUi.color(GoTheme.BORDER), 1.0), "%s: by day the ink is the border colour" % id)
		check(skin.vivid(GoUi.color(GoTheme.DANGER)) == Color(GoUi.color(GoTheme.DANGER_FILL), 1.0)
			and skin.vivid(Color("#123456")) == Color("#123456"), "%s: vivid() swaps a status colour for its fill" % id)
		var idle := skin.slot_box(GoUi.color(GoTheme.INFO), false) as GoStyleBoxArcade
		var lit := skin.slot_box(GoUi.color(GoTheme.INFO), true) as GoStyleBoxArcade
		check(idle != null and idle.frame == 0.0 and not idle.pressed, "%s: a quick slot is a key cap" % id)
		check(lit != null and lit.frame > 0.0 and not lit.pressed and lit.frame_color.r > lit.frame_color.b,
			"%s: a lit slot lights a gold rim, not pressed in" % id)
		var none: Array[float] = [0.0, 0.0, 0.0, 0.0]
		check(idle != null and _margins(idle) == none, "%s: a slot face has no padding (the slot lays it out)" % id)
		var chip := skin.chip_box(GoUi.color(GoTheme.SUCCESS)) as GoStyleBoxArcade
		check(chip != null and chip.radius <= 13.0, "%s: a chip has a radius the cell audit can satisfy" % id)
		var badge := skin.badge_box(GoUi.color(GoTheme.DANGER)) as GoStyleBoxArcade
		check(badge != null and badge.bg_color.get_luminance() > 0.4, "%s: a badge is a light plate its count reads on" % id)
		var alert := skin.alert_box(GoUi.color(GoTheme.DANGER)) as GoStyleBoxArcade
		check(alert != null and alert.frame > 0.0 and alert.frame_color.r > alert.frame_color.b,
			"%s: an alert is a small board framed in its colour" % id)
		var fill := skin.progress_fill_box(GoUi.color(GoTheme.SUCCESS)) as GoStyleBoxArcade
		check(fill != null and fill.border_width >= 2.0 and _painted(fill.bg_color), "%s: a bar's fill is a painted tube" % id)
		var chosen := skin.segment_box(1, 3, &"pressed") as GoStyleBoxArcade
		var other := skin.segment_box(0, 3, &"normal") as GoStyleBoxArcade
		check(chosen != null and other != null and chosen.pressed and chosen.bg_color != other.bg_color,
			"%s: a segmented row is keys, the chosen one pressed in another paint" % id)
		var pick := skin.choice_box(&"pressed") as GoStyleBoxArcade
		check(pick != null and pick.frame > 0.0, "%s: a chosen card lights its rim" % id)
		var floating := skin.floating_box(GoTheme.BOX_HUD) as GoStyleBoxArcade
		check(floating != null and floating.shadow_size > 0 and floating.frame > 0.0, "%s: a floating board casts a shadow" % id)
		var framed := skin.surface_box(GoTheme.BOX_CARD, GoUi.color(GoTheme.DANGER)) as GoStyleBoxArcade
		check(framed != null and framed.frame_color.r > framed.frame_color.b, "%s: an accent paints a board's frame" % id)
		check(skin.fab_box(56.0, &"normal") is GoStyleBoxArcade, "%s: a floating action button is a key" % id)
		var hud := GoStyle.floating(GoTheme.BOX_HUD)
		check(hud.border_width_top >= 6 and hud.shadow_size > 0, "%s: GoStyle.floating() keeps the HUD board's thick frame (%d)"
			% [id, hud.border_width_top])
		check(skin.outlined_button_box(GoUi.theme().get_stylebox(&"normal", &"Button"), &"normal") is GoStyleBoxArcade,
			"%s: an outlined button is a key cap" % id)
		var cap := skin.outlined_button_box(GoUi.theme().get_stylebox(&"normal", &"Button"), &"normal") as GoStyleBoxArcade
		var ratio := GoSkin.contrast_ratio(skin.outlined_button_ink(), cap.bg_color) if cap != null else 0.0
		check(ratio >= 4.5, "%s: the outlined button's label reads on its cap (%.1f:1)" % [id, ratio])
		var plate := skin.title_plate_box() as GoStyleBoxArcade
		check(plate != null and plate.bg_color.r > plate.bg_color.b and plate.lip > 0.0, "%s: a window title gets a gold banner" % id)
		check(skin.title_plate_ink() == Color.WHITE, "%s: in white" % id)
		# 🎀 The banner is a ribbon: its tails fit in its padding, and its height stays the plain banner's (6 + 6).
		check(plate != null and plate.tails == float(skin.arcade_ribbon) and plate.tails > 0.0
			and plate.content_margin_left >= plate.tails + 16.0 and plate.content_margin_right >= plate.tails + 16.0,
			"%s: the banner folds swallow tails, padded clear of the title" % id)
		check(plate != null and is_equal_approx(plate.content_margin_top + plate.content_margin_bottom, 12.0)
			and plate.content_margin_top >= 0.0, "%s: the tails cost the banner no height" % id)
		skin.arcade_ribbon = 0.0
		var plain := skin.title_plate_box() as GoStyleBoxArcade
		check(plain != null and plain.tails == 0.0, "%s: arcade_ribbon 0 draws a plain gold key" % id)
		skin.arcade_ribbon = 12.0
		# 💊 Keys in a row stand apart — drawn in from their cells, no size changing.
		check(chosen != null and chosen.expand_margin_left < 0.0 and chosen.expand_margin_right < 0.0
			and chosen.radius == GoSkinArcade.KEY_RADIUS_SMALL, "%s: a segment is a round key standing apart" % id)
		# ⌨ A key hint is a keycap on a lip, the word in a colour that reads on it, the chip's padding kept.
		var kbd := skin.kbd_box() as GoStyleBoxArcade
		var chip_pad := skin.chip_box(GoUi.color(GoTheme.BORDER)).get_minimum_size()
		check(kbd != null and kbd.lip > 0.0 and kbd.get_minimum_size() == chip_pad,
			"%s: a GoKbd cap is a keycap, sized like the chip it replaces" % id)
		var engraved := GoSkin.contrast_ratio(skin.kbd_ink(), kbd.bg_color.lerp(kbd.bottom(), 0.5)) if kbd != null else 0.0
		check(engraved >= 4.5, "%s: the key's word reads on the cap (%.1f:1)" % [id, engraved])
		# 🧱 Bars are split into chunks by the look.
		check(skin.bar_ticks() == 6, "%s: a bar is split into six chunks" % id)
	await frames(1)


## 🧱 A bar left to the look is split into chunks under the arcade looks and stays smooth under the others; a bar that
## asks for a count gets it everywhere. The ticks are decoration: the bar keeps its size.
func _bar_segments() -> void:
	GoUi.use_preset(&"default_light")
	var bar := GoBar.new()
	bar.label_text = "HP"
	bar.custom_minimum_size.x = 240
	root.add_child(bar)
	bar.set_values(320, 500, false)
	await frames(2)
	var smooth := bar.get_combined_minimum_size()
	check(bar.segment_count() == 0, "bar: under the plain look a bar is smooth")
	GoUi.use_preset(&"arcade_light")
	await frames(2)
	check(bar.segment_count() == 6, "bar: under the arcade look it is split in six")
	check(bar.get_combined_minimum_size() == smooth, "bar: the ticks change no size")
	bar.segments = 0
	check(bar.segment_count() == 0, "bar: segments 0 keeps it smooth under any look")
	bar.segments = 4
	GoUi.use_preset(&"default_light")
	await frames(1)
	check(bar.segment_count() == 4, "bar: a count asked for holds under any look")
	bar.queue_free()
	await frames(1)


func _surface(title: String) -> GoSurface:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var surface := GoSurface.new()
	surface.max_width = 300
	surface.set_title(title)
	layer.add_child(surface)
	return surface


## A window's head in the arcade look: a gold banner with an ink-outlined title and a round red close key — and back
## to plain when the look changes.
func _window_head() -> void:
	GoUi.use_preset(&"arcade_light")
	var surface := _surface("Paused")
	await frames(3)
	var title := surface.title_label
	check(title.get_theme_stylebox(&"normal") is GoStyleBoxArcade, "head: the title sits on a banner")
	check(title.get_theme_constant(&"outline_size") == GoSkinArcade.TITLE_OUTLINE, "head: the title is outlined")
	check(title.get_theme_color(&"font_outline_color").is_equal_approx((GoUi.skin() as GoSkinArcade).ink()),
		"head: in the ink")
	var close := surface.close_button.get_theme_stylebox(&"normal") as GoStyleBoxArcade
	check(close != null and close.bg_color.r > close.bg_color.g and close.radius >= 99.0, "head: the close button is a round red key")
	check(surface.close_button.icon_tint == Color.WHITE, "head: with a white cross")
	check(surface.close_button.get_theme_stylebox(&"pressed") is GoStyleBoxArcade
		and (surface.close_button.get_theme_stylebox(&"pressed") as GoStyleBoxArcade).pressed, "head: it sinks when pressed")
	GoUi.use_preset(&"arcade_dark")
	await frames(3)
	check(title.get_theme_color(&"font_outline_color").is_equal_approx((GoUi.skin() as GoSkinArcade).ink()),
		"head: the night look outlines it in its own ink")
	GoUi.use_preset(&"comic_light")
	await frames(3)
	check(not title.has_theme_constant_override(&"outline_size") and not title.has_theme_color_override(&"font_outline_color"),
		"head: another look takes the outline off")
	GoUi.use_preset(&"default_light")
	await frames(3)
	check(not title.has_theme_stylebox_override(&"normal") and not title.has_theme_constant_override(&"outline_size"),
		"head: the plain look has a plain title")
	surface.get_parent().queue_free()
	await frames(1)


## One widget painted its own colour: every face but the disabled one, the label still reads, a copy on the widget.
func _one_widget() -> void:
	GoUi.use_preset(&"arcade_light")
	var ink := (GoUi.skin() as GoSkinArcade).ink()
	var orange := Color("#FF8A1E")
	var early := GoStyle.arcade_paint(GoStyle.button("Shop"), orange) as Button
	check(early.has_theme_stylebox_override(&"normal"), "one: a key painted before it is in the tree takes the paint")
	var resume := GoStyle.button("Resume", Callable(), GoStyle.Tone.PRIMARY)
	root.add_child(resume)
	root.add_child(early)
	await frames(1)
	check(GoStyle.arcade_paint(resume, orange) == resume, "one: arcade_paint returns the node (it chains)")
	var face := resume.get_theme_stylebox(&"normal") as GoStyleBoxArcade
	var fitted := GoStyleBoxArcade.fit(orange, face.edge()) if face != null else Color.BLACK
	check(face != null and face.bg_color == GoStyleBoxArcade.tones(fitted)[0], "one: the key's top is the paint, fitted")
	check(face != null and GoStyleBoxArcade.worst_label(fitted, ink) >= GoStyleBoxArcade.LABEL_NEED,
		"one: its white outlined label still reads")
	var hover := resume.get_theme_stylebox(&"hover") as GoStyleBoxArcade
	var down := resume.get_theme_stylebox(&"pressed") as GoStyleBoxArcade
	check(hover != null and down != null and hover.bg_color.get_luminance() > down.bg_color.get_luminance() and down.pressed,
		"one: hover is lighter, pressed deeper and still sunk")
	var plain := GoStyle.button("Plain", Callable(), GoStyle.Tone.PRIMARY)
	root.add_child(plain)
	await frames(1)
	var dim := resume.get_theme_stylebox(&"disabled") as GoStyleBoxArcade
	var theirs := plain.get_theme_stylebox(&"disabled") as GoStyleBoxArcade
	check(dim != null and theirs != null and dim.bg_color == theirs.bg_color, "one: the disabled face keeps the theme's dim colour")
	plain.queue_free()
	check((GoUi.theme().get_stylebox(&"normal", &"GoPrimaryButton") as GoStyleBoxArcade).bg_color != face.bg_color,
		"one: the theme's face is untouched (a copy went on the key)")
	var card := GoStyle.card()
	var inside := GoStyle.button("Inside")
	card.add_child(inside)
	root.add_child(card)
	await frames(1)
	GoStyle.arcade_paint(card, orange, true)
	var board := card.get_theme_stylebox(&"panel") as GoStyleBoxArcade
	check(board != null and board.frame_color == GoStyleBoxArcade.tones(orange)[0], "one: a board's frame takes the paint")
	check(inside.has_theme_stylebox_override(&"normal"), "one: deep reaches the children")
	GoUi.use_preset(&"default_light")
	var flat := GoStyle.button("Flat")
	root.add_child(flat)
	await frames(1)
	GoStyle.arcade_paint(flat, orange)
	check(not flat.has_theme_stylebox_override(&"normal"), "one: under another look it does nothing")
	for node: Node in [resume, early, card, flat]: node.queue_free()
	await frames(1)


## Parts that draw their own face in their own ink keep plain letters — the keys' ink outline would blur dark letters.
func _own_ink() -> void:
	GoUi.use_preset(&"arcade_light")
	var outlined := GoStyle.button("Outlined", Callable(), GoStyle.Tone.OUTLINED)
	var chip := GoStyle.filter_chip("On sale")
	var dates := GoDatePicker.new()
	var clock := GoTimePicker.new()
	for part: Control in [outlined, chip, dates, clock]: root.add_child(part)
	await frames(2)
	check(outlined.get_theme_constant(&"outline_size") == 0, "ink: an outlined button's accent label has no outline")
	check(chip.get_theme_constant(&"outline_size") == 0, "ink: a filter chip's label has no outline")
	var blurred := 0
	for part: Control in [dates, clock]:
		for button in part.find_children("*", "Button", true, false):
			var key := button as Button
			if key.has_theme_color_override(&"font_color") and key.get_theme_constant(&"outline_size") > 0: blurred += 1
	check(blurred == 0, "ink: no date cell or time box outlines its own ink (%d do)" % blurred)
	GoStyle.style_button(outlined, GoStyle.Tone.NORMAL)
	check(outlined.get_theme_constant(&"outline_size") > 0, "ink: styled as a normal key again, the label outline comes back")
	# A dark colour asked for on a painted key keeps the white label (a blot otherwise); a placeholder is a faded white.
	var muted := GoUi.color(GoTheme.MUTED)
	var key := GoStyle.button("Key")
	check(GoStyle.label_ink(key, muted).get_luminance() > 0.9, "ink: label_ink keeps a painted key's label white")
	check(is_equal_approx(GoStyle.label_ink(key, muted, true).a, 0.75), "ink: label_ink fades a quiet label")
	check(not key.has_theme_constant_override(&"outline_size"), "ink: on a painted key the outline stays")
	# On a face that is not painted the colour is kept and the outline goes; another call undoes it.
	var plain := GoStyle.button("Plain")
	plain.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	check(GoStyle.label_ink(plain, muted) == muted and plain.get_theme_constant(&"outline_size") == 0,
		"ink: label_ink on an unpainted face keeps the colour and drops the outline")
	GoStyle.label_ink(plain, Color.TRANSPARENT)
	check(not plain.has_theme_constant_override(&"outline_size"), "ink: label_ink undoes its last call")
	check(GoStyle.label_ink(key, Color.WHITE) == Color.WHITE, "ink: a light colour needs nothing")
	var bare := GoStyle.button("Skip", Callable(), GoStyle.Tone.BARE)
	check(GoStyle.label_ink(bare, muted) == muted and not bare.has_theme_constant_override(&"outline_size"),
		"ink: a bare key has no outline to fight — left alone")
	# The segmented control's chosen cell, the coach mark's Skip, the combobox's placeholder.
	var day := GoStyle.segmented(["Day", "Week"], 0)
	var cell := day.get_child(0) as Button
	check(cell.get_theme_color(&"font_pressed_color").get_luminance() > 0.9,
		"ink: the chosen segment's label is white on its painted key")
	var coach := GoCoachMark.new()
	root.add_child(coach)
	await frames(1)
	check(coach.skip_button.theme_type_variation == GoTheme.VAR_BARE_BUTTON, "ink: the coach mark's Skip stays a bare key")
	var combo := GoCombobox.new()
	combo.placeholder = "Find a friend"
	combo.set_items(["Aria", "Brin"])
	root.add_child(combo)
	await frames(1)
	var hint := combo.get_theme_color(&"font_color")
	check(hint.get_luminance() > 0.9 and hint.a < 1.0, "ink: the combobox's placeholder is a faded white on its key")
	# A disabled label by day is a pale grey — a mid grey closed up inside its ink outline.
	check(GoUi.theme_color(&"font_disabled_color", &"Button").get_luminance() > 0.75,
		"ink: by day a disabled key's label is a pale grey")
	for part: Control in [outlined, chip, dates, clock, key, plain, bare, day, coach, combo]: part.queue_free()
	await frames(1)


## A whole screen of parts builds and draws under both arcade looks.
func _screen() -> void:
	for id: StringName in [&"arcade_light", &"arcade_dark"]:
		GoUi.use_preset(id)
		var column := VBoxContainer.new()
		column.size = Vector2(360, 800)
		for part: Control in [GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY), GoStyle.button("Delete", Callable(),
				GoStyle.Tone.DANGER_SOLID), GoStyle.button("Outlined", Callable(), GoStyle.Tone.OUTLINED),
				GoStyle.button("Small", Callable(), GoStyle.Tone.COMPACT), GoStyle.line_edit("name"),
				GoStyle.progress(GoUi.color(GoTheme.SUCCESS_FILL)), GoStyle.chip("Ice", GoUi.color(GoTheme.INFO)),
				GoStyle.card(), GoStyle.hud_panel()]:
			column.add_child(part)
		var tick := CheckBox.new()
		tick.text = "Music"
		column.add_child(tick)
		var tabs := TabBar.new()
		tabs.add_tab("Daily")
		tabs.add_tab("Weekly")
		column.add_child(tabs)
		root.add_child(column)
		await frames(3)
		var drawn := true
		for part in column.get_children():
			if (part as Control).size.x <= 0.0 or (part as Control).size.y <= 0.0: drawn = false
		check(drawn, "%s: every part of a screen lays out with a size" % id)
		column.queue_free()
		await frames(1)
	GoUi.use_preset(&"arcade_light")
	var stick := GoJoystick.new()
	stick.size = Vector2(200, 200)
	root.add_child(stick)
	await frames(2)
	check(stick.is_inside_tree(), "screen: the joystick draws in the arcade look")
	stick.queue_free()
	GoUi.use_preset(&"default_light")
	await frames(1)
