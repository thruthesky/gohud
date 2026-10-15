## 🧪 **Checks for the match-HUD widgets** — the generic parts of Magnet Mayhem's in-match screen: the painted bar
## (`GoBar`'s frame), and the HUD's cards, touch keys, name plates, feed, spotlight, readout and scaling as they land.
## Each runs in arcade_light (the game's values) and in a plain look (the fallbacks: no art, no frame, no errors).
## 🛑 These widgets show what they are given and decide nothing — the checks feed them values and read the display.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_game_hud_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const INK := Color("#1d2340")
const BAR_BG := Color("#d9deef")

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(390, 844)
		await frames(2)
	GoUi.reset()
	GoUi.config.reduce_motion = true
	for look: StringName in [GoThemePresets.ARCADE_LIGHT, GoThemePresets.DEFAULT_DARK]:
		GoUi.use_preset(look)
		await frames(1)
		await _bar_frame(look)
		await _hud_card(look)
		await _countdown(look)
		await _art_button(look)
		await _hud_button(look)
		await _nameplate(look)
		await _notice_feed(look)
		await _touch_button(look)
		await _joystick_art(look)
		await _task_card(look)
		await _spotlight(look)
		await _perf_readout(look)
		await _slot_touch(look)
		await _icon_focus(look)
	_per_inch_scale()
	GoUi.reset()
	print("gohud game hud tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func _host(node: Control, width := 300.0) -> Control:
	var holder := Control.new()
	holder.size = Vector2(width, 400)
	root.add_child(holder)
	holder.add_child(node)
	return holder


# ── The painted bar ────────────────────────────────────────────────────

func _bar_frame(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var frame_box := GoUi.skin().bar_frame_box()
	if painted:
		var flat := frame_box as StyleBoxFlat
		check(flat != null, "bar: arcade_light's bar_frame_box is a StyleBoxFlat")
		if flat != null:
			check(flat.bg_color.is_equal_approx(BAR_BG), "bar: the frame is the game's BAR_BG")
			check(flat.border_color.is_equal_approx(INK) and flat.border_width_left == 3 and flat.border_width_bottom == 3,
				"bar: the frame has a 3 px ink rim")
			check(flat.corner_radius_top_left == 9 and flat.corner_radius_bottom_right == 9, "bar: the frame's corners are 9")
			check(flat.get_minimum_size() == Vector2.ZERO, "bar: the frame has no content margin of its own")
	else:
		check(frame_box == null, "bar: %s has no painted frame (the ProgressBar stays)" % look)

	var bar := GoBar.new()
	bar.label_text = "POWER"
	bar.readout = GoBar.Readout.NONE
	bar.ink = Color("#1fb5f0")
	bar.ink_end = Color("#6ff0ff")
	bar.thickness = 14
	bar.label_size = 11
	bar.label_gap = 0
	bar.lead = 2.0
	bar.icon = GoUi.icons().texture(GoIconSet.STAR)
	bar.icon_size = 16.0
	bar.icon_gap = 3
	var holder := _host(bar, 200.0)
	await frames(2)
	bar.set_values(62.0, 100.0, false)
	await frames(1)
	check(bar.frame_mode() == painted, "bar: %s frame_mode is %s" % [look, painted])
	var frame := bar.find_child("Frame", true, false) as Panel
	var progress := bar.find_child("Fill", true, false) as ProgressBar
	check(frame != null and progress != null, "bar: both the frame and the ProgressBar are built")
	if frame != null and progress != null:
		check(frame.visible == painted and progress.visible != painted, "bar: %s shows the %s" % [look,
			"frame" if painted else "ProgressBar"])
		var shown := frame if painted else progress as Control
		check(is_equal_approx(shown.size.y, 14.0), "bar: thickness 14 sets the shown bar's height (got %s)" % shown.size.y)
		check(frame.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "bar: the frame clips its fill to its shape")
		var fill := frame.find_child("Gradient", true, false) as TextureRect
		check(fill != null, "bar: the frame holds a gradient fill")
		if fill != null:
			check(is_equal_approx(fill.anchor_right, 0.62), "bar: the fill's right anchor is the shown share (got %s)" % fill.anchor_right)
			var gradient := (fill.texture as GradientTexture2D).gradient if fill.texture is GradientTexture2D else null
			check(gradient != null and gradient.colors[0].is_equal_approx(Color("#1fb5f0"))
				and gradient.colors[1].is_equal_approx(Color("#6ff0ff")), "bar: the gradient runs from ink to ink_end")
		check(is_equal_approx(progress.value, 0.62), "bar: the ProgressBar keeps the value too")
	var name_label := bar.find_child("Name", true, false) as Label
	check(name_label != null and name_label.get_theme_font_size(&"font_size") == 11, "bar: label_size sets the name's size")
	var icon := bar.find_child("Icon", true, false) as TextureRect
	check(icon != null and icon.visible and icon.custom_minimum_size == Vector2(16, 16), "bar: the icon shows at icon_size")
	var title := bar.find_child("Title", true, false) as HBoxContainer
	check(title != null and title.get_theme_constant(&"separation") == 3, "bar: icon_gap spaces the icon from the name")
	var lead := bar.find_child("Lead", true, false) as Control
	check(lead != null and lead.custom_minimum_size.y == 2.0, "bar: lead leaves room above the name")
	var column := bar.find_child("Column", true, false) as VBoxContainer
	check(column != null and column.get_theme_constant(&"separation") == 0, "bar: label_gap 0 sets the column's gap")
	bar.icon = null
	check(icon != null and not icon.visible, "bar: no icon hides the icon")
	# One paint: the gradient runs ink to ink.
	bar.ink_end = Color.TRANSPARENT
	await frames(1)
	var fill2 := bar.find_child("Gradient", true, false) as TextureRect
	if fill2 != null and fill2.texture is GradientTexture2D:
		var g := (fill2.texture as GradientTexture2D).gradient
		check(g.colors[0].is_equal_approx(g.colors[1]), "bar: no ink_end is one paint")
	holder.queue_free()
	await frames(1)


# ── The HUD card ───────────────────────────────────────────────────────

func _hud_card(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	# The player card: avatar, gold banner, two bars.
	var player := GoHudCard.make(skin.widget_art(&"avatar_head"), 56.0)
	player.gap = 10
	player.banner_text = "YOU"
	var stability := player.add_bar("STABILITY", Color("#ff7a3d"), Color("#ffd23f"))
	var power := player.add_bar("POWER", Color("#1fb5f0"), Color("#6ff0ff"), skin.widget_art(&"bolt"))
	var holder := _host(player, 300.0)
	await frames(2)
	check(player.theme_type_variation == GoHudCard.VAR_PANEL, "card: the board is GoHudPanel")
	var icon := player.find_child("Icon", true, false) as TextureRect
	check(icon != null and icon.custom_minimum_size == Vector2(56, 56), "card: the icon shows at icon_size")
	check(icon != null and icon.visible == (icon.texture != null), "card: the icon hides with no art (%s)" % look)
	if painted: check(icon != null and icon.texture != null, "card: arcade_light has the avatar art")
	var banner := player.find_child("Banner", true, false) as PanelContainer
	check(banner != null and banner.visible and banner.theme_type_variation == GoHudCard.VAR_BANNER,
		"card: the banner is GoBannerGold")
	var banner_label := player.find_child("BannerLabel", true, false) as Label
	check(banner_label != null and banner_label.text == "YOU" and banner_label.get_theme_font_size(&"font_size") == 16,
		"card: the banner reads its text at 16")
	check(player.bars().size() == 2 and player.bars()[0] == stability and player.bars()[1] == power, "card: bars() lists the bars in order")
	check(stability.thickness == 14 and stability.label_size == 11 and stability.lead == 2.0 and stability.label_gap == 0,
		"card: add_bar lays the bar out as a HUD's")
	check(stability.readout == GoBar.Readout.NONE, "card: a HUD bar has no readout")
	check(power.icon != null or not painted, "card: the power bar keeps its icon")
	var row := player.find_child("Row", true, false) as HBoxContainer
	check(row != null and row.get_theme_constant(&"separation") == 10, "card: gap spaces the row")
	# Padding: margins are padding + border per side.
	var before := player.get_theme_stylebox(&"panel")
	player.padding = 4.0
	var after := player.get_theme_stylebox(&"panel") as StyleBoxFlat
	if painted:
		check(after != null and after.content_margin_left == 9.0 and after.content_margin_top == 9.0
			and after.content_margin_bottom == 12.0, "card: padding 4 is 4 inside the rim (9 · 9 · 12)")
	player.padding = -1.0
	check(player.get_theme_stylebox(&"panel") == before, "card: padding -1 gives the theme's board back")
	player.banner_padding = 2.0
	var banner_box := banner.get_theme_stylebox(&"panel") as StyleBoxFlat
	if painted:
		check(banner_box != null and banner_box.content_margin_left == 5.0 and banner_box.content_margin_bottom == 7.0,
			"card: banner_padding 2 is 2 inside the banner's rim")
	holder.queue_free()

	# The opponents card: inline title and count.
	var foes := GoHudCard.make(skin.widget_art(&"opponents_badge"))
	foes.layout = GoHudCard.Layout.INLINE
	foes.title = "OPPONENTS"
	foes.value = "7"
	holder = _host(foes)
	await frames(2)
	var title := foes.find_child("Title", true, false) as Label
	var value := foes.find_child("Value", true, false) as Label
	check(title != null and title.get_parent() == foes.find_child("Row", true, false), "card: inline puts the title in the row")
	check(title != null and title.get_theme_font_size(&"font_size") == 19 and value.get_theme_font_size(&"font_size") == 19,
		"card: inline reads at 19")
	check(not (foes.find_child("Body", true, false) as Control).visible, "card: an inline card with no banner hides its column")
	foes.layout = GoHudCard.Layout.STACKED
	check(title.get_parent() == foes.find_child("Body", true, false), "card: stacked puts the title in the column")
	check(title.get_theme_font_size(&"font_size") == 12 and value.get_theme_font_size(&"font_size") == 24,
		"card: stacked reads 12 over 24")
	var ink := foes.get_theme_color(&"font_color", &"Label")
	check(title.get_theme_color(&"font_color").is_equal_approx(Color(ink, ink.a * 0.75)), "card: the caption is the label ink at 75 %")
	check(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "card: a stacked caption is centred")
	holder.queue_free()

	# The clock.
	check(GoHudCard.format_clock(83.7) == "01:23" and GoHudCard.format_clock(-4) == "00:00"
		and GoHudCard.format_clock(600) == "10:00", "card: format_clock is MM:SS")
	var clock := GoHudCard.make(skin.widget_art(&"stopwatch"))
	clock.title = "TIME"
	holder = _host(clock)
	clock.set_clock(125.0)
	await frames(1)
	value = clock.find_child("Value", true, false) as Label
	check(value.text == "02:05" and not clock.is_warning(), "card: set_clock writes the time")
	check(not value.has_theme_color_override(&"font_color"), "card: a calm clock keeps the label ink")
	# 🔁 A clock set every frame rebuilds nothing until its text or its warning changes.
	clock.padding = 6.0
	var clock_box := clock.get_theme_stylebox(&"panel")
	var rebuilds := [0]
	var count_rebuild := func() -> void: rebuilds[0] += 1
	clock.theme_changed.connect(count_rebuild)
	clock.set_clock(125.4)
	check(clock.get_theme_stylebox(&"panel") == clock_box and rebuilds[0] == 0,
		"card: a clock whose text did not change rebuilds nothing")
	clock.value = "02:05"
	clock.title = "TIME"
	check(clock.get_theme_stylebox(&"panel") == clock_box and rebuilds[0] == 0,
		"card: setting the same value or title rebuilds nothing")
	clock.set_clock(125.4, true)
	check(clock.is_warning() and value.get_theme_color(&"font_color").is_equal_approx(skin.hud_alert_ink()),
		"card: a warning with the same text still repaints")
	clock.set_clock(124.0, true)
	check(value.text == "02:04" and clock.get_theme_stylebox(&"panel") == clock_box,
		"card: a new time keeps the same padded board")
	clock.theme_changed.disconnect(count_rebuild)
	var other_look := Theme.new()
	var other_board := StyleBoxFlat.new()
	other_board.bg_color = Color("#123456")
	other_board.set_border_width_all(2)
	other_look.set_type_variation(GoHudCard.VAR_PANEL, &"PanelContainer")
	other_look.set_stylebox(&"panel", GoHudCard.VAR_PANEL, other_board)
	clock.theme = other_look
	clock.set_clock(123.0, true)
	var repadded := clock.get_theme_stylebox(&"panel") as StyleBoxFlat
	check(repadded != null and repadded != clock_box and repadded.bg_color == other_board.bg_color
		and repadded.content_margin_left == 8.0, "card: a theme change pads the new theme's board")
	clock.theme = GoUi.theme()
	clock.padding = -1.0
	clock.set_clock(125.0)
	clock.set_clock(12.0, true)
	check(value.get_theme_color(&"font_color").is_equal_approx(skin.hud_alert_ink()), "card: a warning clock reads in hud_alert_ink")
	if painted: check(skin.hud_alert_ink().is_equal_approx(Color("#e8332f")), "card: arcade_light warns in READY_RED")
	clock.set_clock(11.0, false)
	check(not value.has_theme_color_override(&"font_color"), "card: the warning clears")
	holder.queue_free()

	# The gauge.
	var gauge := GoHudCard.new()
	gauge.gauge = true
	gauge.title = "REPULSE"
	gauge.value = "READY"
	holder = _host(gauge)
	await frames(1)
	check(gauge.is_lit() and is_equal_approx(gauge.modulate.a, 1.0), "card: a gauge starts lit")
	var lit_box := gauge.get_theme_stylebox(&"panel")
	if painted:
		var flat := lit_box as StyleBoxFlat
		check(flat != null and flat.border_color.is_equal_approx(Color("#e8332f")) and flat.border_width_left == 3
			and flat.corner_radius_top_left == 14 and flat.content_margin_left == 14.0 and flat.content_margin_top == 8.0,
			"card: arcade_light's lit gauge is the game's repulse panel")
	gauge.set_lit(false)
	check(not gauge.is_lit() and is_equal_approx(gauge.modulate.a, GoHudCard.DIM_ALPHA), "card: an unlit gauge dims")
	if painted:
		var flat := gauge.get_theme_stylebox(&"panel") as StyleBoxFlat
		check(flat != null and flat.border_color.is_equal_approx(INK), "card: an unlit gauge has an ink rim")
	gauge.set_lit(true)
	check(gauge.scale == Vector2.ONE, "card: reduce_motion skips the pop")
	GoUi.config.reduce_motion = false
	gauge.set_lit(false)
	gauge.set_lit(true)
	await frames(3)
	check(gauge.scale.x > 1.0, "card: lighting pops the gauge")
	GoUi.config.reduce_motion = true
	gauge.set_lit(true)
	check(gauge.scale == Vector2.ONE, "card: set_lit settles the scale")
	holder.queue_free()
	await frames(1)


# ── The countdown ──────────────────────────────────────────────────────

func _countdown(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var count := GoCountdown.new()
	var holder := _host(count, 390.0)
	await frames(1)
	check(not count.visible, "countdown: hidden until a step shows")
	check(count.mouse_filter == Control.MOUSE_FILTER_IGNORE, "countdown: input-transparent")
	count.show_step("3")
	await frames(1)
	check(count.visible and count.text == "3" and not count.is_final(), "countdown: show_step shows the step")
	check(count.get_theme_font_size(&"font_size") == 110, "countdown: a step reads at 110")
	check(count.get_theme_constant(&"outline_size") == 14, "countdown: a 14 dp outline")
	check(count.get_theme_constant(&"shadow_offset_y") == 8, "countdown: the shadow drops 8 dp")
	check(count.custom_minimum_size == Vector2(300, 200), "countdown: 300 x 200 at least")
	check(count.get_theme_color(&"font_color") == GoUi.skin().countdown_ink(), "countdown: the ink is the skin's")
	var disc := count.find_child("Disc", true, false) as TextureRect
	var round_disc := count.find_child("Round", true, false) as Panel
	check(disc != null and round_disc != null and disc.show_behind_parent, "countdown: the disc sits behind the text")
	check(disc != null and disc.size == Vector2(200, 200), "countdown: the disc is disc_size")
	if painted:
		check(GoUi.skin().countdown_ink() == Color("#ffc928"), "countdown: arcade_light paints it GOLD")
		check(disc.visible and disc.texture != null and disc.texture.resource_path.ends_with("badge_blue.png"),
			"countdown: a step sits on the blue badge")
	else:
		check(round_disc.visible and not disc.visible, "countdown: no art draws a round disc (%s)" % look)
	count.show_step("GO!", true)
	await frames(1)
	check(count.is_final() and count.get_theme_font_size(&"font_size") == 80, "countdown: the last step reads at 80")
	if painted:
		check(disc.texture.resource_path.ends_with("badge_green.png"), "countdown: the last step sits on the green badge")
	check(count.scale == Vector2.ONE and count.modulate.a == 1.0, "countdown: no pop under reduce_motion")
	GoUi.config.reduce_motion = false
	count.show_step("2")
	check(count.scale == Vector2.ONE * 1.6 and is_equal_approx(count.modulate.a, 0.6), "countdown: a step pops in")
	await create_timer(0.5).timeout
	check(count.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(count.modulate.a, 1.0), "countdown: the pop settles")
	GoUi.config.reduce_motion = true
	count.ink = Color.RED
	check(count.get_theme_color(&"font_color") == Color.RED, "countdown: ink overrides the skin's")
	count.hide_step()
	check(not count.visible and count.scale == Vector2.ONE, "countdown: hide_step takes it off")
	holder.queue_free()
	await frames(1)


# ── A picture that is the whole button (GoIconButton.art) ──────────────

func _art_button(look: StringName) -> void:
	var picture := GoUi.skin().widget_art(&"pause_button")
	if picture == null: picture = PlaceholderTexture2D.new()
	var button := GoIconButton.new()
	button.visual_size = 52
	button.art = picture
	var holder := _host(button)
	await frames(1)
	check(button.icon == picture and button.expand_icon, "art: the picture is the icon, filling the button")
	check(button.size == Vector2(52, 52), "art: the button is visual_size")
	check(not button.has_theme_constant_override(&"icon_max_width"), "art: no glyph-size cap")
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		check(button.get_theme_stylebox(state) is StyleBoxEmpty, "art: no frame when %s (%s)" % [state, look])
	check(button.get_theme_color(&"icon_normal_color") == Color.WHITE, "art: the picture shows as drawn")
	check(button.get_theme_color(&"icon_pressed_color") == GoUi.skin().picture_press_tint(), "art: pressed darkens it")
	if look == GoThemePresets.ARCADE_LIGHT:
		check(GoUi.skin().picture_press_tint() == Color(0.78, 0.78, 0.86), "art: arcade_light's press tint is the game's")
	button.art = null
	check(button.icon == null and not button.has_theme_stylebox_override(&"normal"), "art: clearing it restores the frame")
	holder.queue_free()
	await frames(1)


# ── The look's touch floor and focus order ────────────────────────────

func _slot_touch(look: StringName) -> void:
	var slot := GoSlot.new()
	slot.visual_size = 30
	var holder := _host(slot)
	await frames(1)
	var floor := GoUi.touch_size()
	check(slot.custom_minimum_size == Vector2(floor, floor), "slot: the box is the look's touch floor (%s)" % look)
	# A look with its own floor below the config's default: the slot keeps to the look's, not to min_touch_size.
	GoUi.config.metric_overrides[GoTheme.TOUCH] = 40
	GoUi.refresh()
	await frames(1)
	check(slot.custom_minimum_size == Vector2(40, 40), "slot: follows GoUi.touch_size(), not min_touch_size (%s)" % look)
	check(slot.touch_hit(Vector2(-1, 20)) == false and slot.touch_hit(Vector2(1, 20)), "slot: no reach past its 40 box")
	GoUi.config.metric_overrides.erase(GoTheme.TOUCH)
	GoUi.config.min_touch_size = 60
	GoUi.refresh()
	await frames(1)
	check(slot.custom_minimum_size == Vector2(60, 60), "slot: a floor the project chose wins (%s)" % look)
	GoUi.config.follow_look_touch_size()
	GoUi.refresh()
	holder.queue_free()
	await frames(1)


func _icon_focus(look: StringName) -> void:
	var arcade := look == GoThemePresets.ARCADE_LIGHT
	var plain := GoIconButton.new()
	var holder := _host(plain)
	await frames(1)
	check(plain.focus_mode == (Control.FOCUS_NONE if arcade else Control.FOCUS_ALL),
		"icon focus: the look's focus mode (%s)" % look)
	var chosen := GoIconButton.new()
	chosen.keyboard_focus = true
	holder.add_child(chosen)
	var off := GoIconButton.new()
	off.keyboard_focus = false
	holder.add_child(off)
	await frames(1)
	check(chosen.focus_mode == Control.FOCUS_ALL, "icon focus: keyboard_focus = true set by the project stays (%s)" % look)
	check(off.focus_mode == Control.FOCUS_NONE, "icon focus: keyboard_focus = false stays (%s)" % look)
	var other := GoThemePresets.DEFAULT_DARK if arcade else GoThemePresets.ARCADE_LIGHT
	GoUi.use_preset(other)
	await frames(1)
	check(plain.focus_mode == (Control.FOCUS_ALL if arcade else Control.FOCUS_NONE), "icon focus: follows a look change")
	check(chosen.focus_mode == Control.FOCUS_ALL and off.focus_mode == Control.FOCUS_NONE,
		"icon focus: the project's choice survives a look change")
	GoUi.use_preset(look)
	await frames(1)
	holder.queue_free()
	await frames(1)


# ── A HUD picture button with a key hint (GoHudButton) ─────────────────

func _hud_button(look: StringName) -> void:
	var skin := GoUi.skin()
	var corner := GoHudButton.make(skin.widget_art(&"pause_button"), 52.0, "Esc")
	var holder := _host(corner)
	var hits := [0]
	corner.pressed.connect(func() -> void: hits[0] += 1)
	await frames(1)
	check(corner.button is GoIconButton and corner.button.art == skin.widget_art(&"pause_button"),
		"hud button: the button is a GoIconButton picture")
	check(corner.button.visual_size == 52 and corner.button.focus_mode == Control.FOCUS_NONE,
		"hud button: 52 dp and never keeps focus over gameplay")
	check(corner.get_theme_constant(&"separation") == 8, "hud button: 8 dp between the hint and the button")
	var hint := corner.find_child("Hint", true, false) as Label
	check(hint != null and hint.visible and hint.text == "Esc" and hint.get_index() == 0, "hud button: the hint comes first")
	check(hint.get_theme_font_size(&"font_size") == 14, "hud button: the hint reads at 14")
	check(hint.get_theme_color(&"font_color") == skin.hud_key_hint_ink(), "hud button: the hint ink is the skin's")
	check(hint.get_theme_stylebox(&"normal") != null, "hud button: the hint sits on a key cap (%s)" % look)
	check(hint.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "hud button: a key name is never translated")
	if look == GoThemePresets.ARCADE_LIGHT:
		var cap := hint.get_theme_stylebox(&"normal") as StyleBoxFlat
		check(cap != null and cap.bg_color == Color("#6c7aa8") and cap.border_width_bottom == 5
			and cap.border_width_left == 3 and cap.corner_radius_top_left == 8, "hud button: arcade_light's key cap")
		check(cap.content_margin_left == 6 and cap.content_margin_top == 4 and cap.content_margin_bottom == 6,
			"hud button: the cap's margins are the game's")
		check(skin.hud_key_hint_ink() == Color.WHITE, "hud button: arcade_light's hint is white")
	corner.show_hint = false
	check(not hint.visible, "hud button: show_hint false hides the hint (touch)")
	corner.hint_text = ""
	corner.show_hint = true
	check(not hint.visible, "hud button: no text, no hint")
	corner.button.pressed.emit()
	check(hits[0] == 1, "hud button: pressed passes the press on (the caller decides what it does)")
	holder.queue_free()
	await frames(1)


# ── The name plate ─────────────────────────────────────────────────────

func _nameplate(look: StringName) -> void:
	var skin := GoUi.skin()
	var red := Color(0.86, 0.24, 0.24)
	var bot := GoNameplate.make("BOT RED", red)
	var own := GoNameplate.make("KIM HANA", Color.TRANSPARENT, true)
	own.base_width = 86
	var holder := _host(bot)
	holder.add_child(own)
	await frames(1)
	var label := bot.find_child("Name", true, false) as Label
	check(label != null and label.text == "BOT RED", "nameplate: the label shows the text")
	check(label.clip_text and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "nameplate: centred, clipped")
	check(bot.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"nameplate: never catches the mouse")
	check(bot.size.y == 24 and bot.custom_minimum_size.y == 24, "nameplate: 24 dp tall")
	check(bot.size.x >= 64 and bot.size.x <= 100, "nameplate: width between base and max (%s)" % bot.size.x)
	check(own.size.x >= 86, "nameplate: base_width widens the own plate")
	var box := bot.get_theme_stylebox(&"panel")
	check(box != null, "nameplate: a box from the skin (%s)" % look)
	check(label.get_theme_color(&"font_color") == skin.nameplate_ink(false), "nameplate: other's ink is the skin's")
	var own_label := own.find_child("Name", true, false) as Label
	check(own_label.get_theme_color(&"font_color") == skin.nameplate_ink(true), "nameplate: own ink is the skin's")
	bot.text = "A VERY LONG NAME INDEED FOR A PLATE"
	await frames(1)
	check(bot.size.x == 100, "nameplate: a long name stops at max_width (%s)" % bot.size.x)
	bot.text = "AI"
	await frames(1)
	check(bot.size.x == 64, "nameplate: a short name keeps base_width (%s)" % bot.size.x)
	bot.place_at(Vector2(200, 100))
	check(bot.position == Vector2(200, 100) - bot.size / 2.0, "nameplate: place_at centres on the point")
	var camera := Camera3D.new()
	root.add_child(camera)
	await frames(1)
	check(bot.follow(camera, Vector3(0, 0, -5)) and bot.visible, "nameplate: follow shows a point in front of the camera")
	check(bot.position.is_equal_approx(camera.unproject_position(Vector3(0, 0, -5)) - bot.size / 2.0),
		"nameplate: follow centres on the projected point")
	check(not bot.follow(camera, Vector3(0, 0, 5)) and not bot.visible, "nameplate: follow hides a point behind the camera")
	check(not bot.follow(null, Vector3.ZERO) and not bot.visible, "nameplate: no camera, no plate")
	camera.queue_free()
	if look == GoThemePresets.ARCADE_LIGHT:
		var flat := box as StyleBoxFlat
		check(flat != null and flat.bg_color == Color(red, 0.92) and flat.corner_radius_top_left == 8
			and flat.border_width_left == 2 and flat.border_color == INK, "nameplate: arcade_light's plate")
		check(flat.content_margin_left == 2 and flat.content_margin_top == 0, "nameplate: the plate's margins are the game's")
		var own_box := own.get_theme_stylebox(&"panel") as StyleBoxFlat
		check(own_box.bg_color == Color(Color("#ffc928"), 0.92), "nameplate: own plate is gold")
		check(own_label.get_theme_color(&"font_color") == INK and own_label.get_theme_constant(&"outline_size") == 0,
			"nameplate: own name is ink, no outline")
		check(label.get_theme_color(&"font_color") == Color.WHITE and label.get_theme_constant(&"outline_size") == 3
			and label.get_theme_color(&"font_outline_color") == INK, "nameplate: other names are white with an ink outline")
		check(label.get_theme_font_size(&"font_size") == 14, "nameplate: 14 dp text")
	holder.queue_free()
	await frames(1)


# ── The notice feed ────────────────────────────────────────────────────

func _notice_feed(look: StringName) -> void:
	var feed := GoNoticeFeed.new()
	feed.auto_advance = false
	var holder := _host(feed)
	await frames(1)
	check(feed.mouse_filter == Control.MOUSE_FILTER_IGNORE, "feed: never catches the mouse")
	check(feed.get_theme_constant(&"separation") == 6, "feed: 6 dp between rows")
	check(feed.count == 0 and feed.get_child_count() == 4, "feed: max_items rows pooled up front, all hidden")
	feed.push("RED knocked out BLUE")
	feed.push("YOU knocked out GREEN", true)
	check(feed.count == 2, "feed: two rows showing")
	var rows := feed.rows()
	check(rows.size() == 2 and rows[0].visible and rows[1].visible, "feed: rows() lists the showing rows, oldest first")
	var first := rows[0] as PanelContainer
	var label := first.find_child("Text", true, false) as Label
	var icon := first.find_child("Icon", true, false) as TextureRect
	check(label != null and label.text == "RED knocked out BLUE", "feed: the row shows the text")
	check(label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "feed: the text is shown as given")
	check(icon != null and icon.texture != null and icon.custom_minimum_size == Vector2(22, 22), "feed: a 22 dp skull")
	check((first.get_child(0) as HBoxContainer).get_theme_constant(&"separation") == 8, "feed: 8 dp between icon and text")
	check(first.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "feed: rows shrink to their text, centred")
	check(rows[1].get_index() > rows[0].get_index(), "feed: newest at the bottom")
	check(first.get_theme_stylebox(&"panel") != rows[1].get_theme_stylebox(&"panel"), "feed: the own row looks different (%s)" % look)
	check(first.modulate.a == 1.0, "feed: reduce_motion shows a row at once")
	GoUi.config.reduce_motion = false
	feed.push("C")
	check(feed.rows()[2].modulate.a == 0.0, "feed: a new row starts clear")
	feed.advance(0.1)
	check(is_equal_approx(feed.rows()[2].modulate.a, 0.5), "feed: and fades in over fade_in")
	GoUi.config.reduce_motion = true
	feed.push("D")
	feed.push("E")
	check(feed.count == 4 and (feed.rows()[3].find_child("Text", true, false) as Label).text == "E",
		"feed: a fifth push reuses the oldest row")
	check((feed.rows()[0].find_child("Text", true, false) as Label).text == "YOU knocked out GREEN", "feed: the oldest went")
	feed.advance(1.95)
	check(feed.count == 2, "feed: rows go after seconds (%d left)" % feed.count)
	feed.advance(0.2)
	check(feed.count == 0, "feed: all gone")
	feed.push("F")
	feed.clear()
	check(feed.count == 0 and feed.get_child_count() == 4, "feed: clear hides every row, keeps the pool")
	var early := GoNoticeFeed.new()
	GoUi.config.reduce_motion = false
	early.push("before the tree")
	GoUi.config.reduce_motion = true
	holder.add_child(early)
	await frames(1)
	check(early.count == 1 and early.rows()[0].visible and early.rows()[0].modulate.a == 1.0,
		"feed: a row pushed before the feed is in the tree survives and shows")
	if look == GoThemePresets.ARCADE_LIGHT:
		feed.push("G")
		feed.push("H", true)
		check(feed.rows()[0].theme_type_variation == &"GoNotice" and feed.rows()[1].theme_type_variation == &"GoNoticeGold",
			"feed: arcade_light rows use GoNotice / GoNoticeGold")
	holder.queue_free()
	await frames(1)


# ── A touch button (GoTouchButton) and the painted stick ───────────────

func _press(button: Control, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	button._gui_input(event)


func _move(button: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	button._gui_input(event)


func _touch_button(look: StringName) -> void:
	var skin := GoUi.skin()
	var repulse := GoTouchButton.make(&"btn_repulse", "REPULSE", 92.0)
	var holder := _host(repulse)
	await frames(1)
	check(repulse.size == Vector2(92, 92) and repulse.custom_minimum_size == Vector2(92, 92), "touch: diameter square")
	check(repulse.picture() == skin.widget_art(&"btn_repulse"), "touch: the picture is the skin's art (%s)" % look)
	if look == GoThemePresets.ARCADE_LIGHT:
		check(repulse.picture() != null, "touch: arcade_light ships the button art")
		check(skin.touch_shadow_ink() == INK and skin.touch_outline_ink() == INK, "touch: arcade_light's ink shadow and edge")
		check(skin.touch_cooldown_ink() == Color("#ff7a74"), "touch: arcade_light's cooldown arc")
	else:
		check(repulse.picture() == null, "touch: no art, a plain disc")
	check(repulse.label_font_size() == 14, "touch: the label reads at 14")
	repulse.text = "UNE TRES LONGUE ETIQUETTE"
	check(repulse.label_font_size() == 10, "touch: a long label shrinks, never under 10 (%d)" % repulse.label_font_size())
	repulse.text = "REPULSE"
	var events: Array[String] = []
	repulse.pressed_down.connect(func() -> void: events.append("down"))
	repulse.released.connect(func(canceled: bool) -> void: events.append("up%s" % canceled))
	check(repulse._has_point(Vector2(46, 46 - 46 - 7)) and not repulse._has_point(Vector2(46, -20)),
		"touch: the press reaches hit_slop past the rim")
	_press(repulse, Vector2(46, 46), true)
	check(repulse.is_held() and events == ["down"], "touch: a press holds it and says so")
	check(repulse.radius() == 46.0 * 0.93, "touch: a held button shrinks to 0.93")
	_press(repulse, Vector2(46, 46), false)
	check(not repulse.is_held() and events == ["down", "upfalse"], "touch: lifting releases it")
	repulse.cooling = true
	repulse.cooldown = 0.5
	check(repulse.cooldown == 0.5 and repulse.tint() == Color(0.72, 0.72, 0.8), "touch: cooling dims it")
	repulse.cooldown = 3.0
	check(repulse.cooldown == 1.0, "touch: the cooldown share stays within 0..1")
	repulse.cooling = false
	check(repulse.cooldown == 0.0 and repulse.tint() == Color.WHITE, "touch: ready clears the ring")
	check(repulse.pulse() == 1.0, "touch: reduce_motion keeps it still when ready")
	holder.queue_free()
	var attract := GoTouchButton.make(&"btn_attract", "ATTRACT", 120.0)
	attract.drag_aim = true
	attract.font_size = 16
	attract.label_rise = 0.62
	attract.caption = "HOLD + DRAG"
	attract.held_caption = "DRAG TO AIM"
	holder = _host(attract)
	await frames(1)
	check(attract.caption_font_size(false) == 11 and attract.caption_font_size(true) == 12, "touch: captions at 11 / 12")
	var aims: Array[Vector2] = []
	attract.aimed.connect(func(v: Vector2) -> void: aims.append(v))
	_press(attract, Vector2(60, 60), true)
	_move(attract, Vector2(160, 60))
	check(attract.aim() == Vector2(1, 0) and attract.knob() == Vector2(110, 60), "touch: drag-to-aim stops at aim_radius")
	check(aims.size() == 1 and aims[0] == Vector2(1, 0), "touch: aimed reports the pull")
	_move(attract, Vector2(60, 85))
	check(attract.aim().is_equal_approx(Vector2(0, 0.5)), "touch: a half pull is half")
	_press(attract, Vector2(60, 85), false)
	check(attract.aim() == Vector2.ZERO and not attract.is_held(), "touch: lifting clears the aim")
	attract.cancel()
	check(not attract.is_held(), "touch: cancel lets go")
	holder.queue_free()
	await frames(1)


func _joystick_art(look: StringName) -> void:
	var skin := GoUi.skin()
	if look == GoThemePresets.ARCADE_LIGHT:
		check(skin.joystick_art(false) == skin.widget_art(&"stick_base") and skin.joystick_art(false) != null,
			"stick: arcade_light's painted dish")
		check(skin.joystick_art(true) == skin.widget_art(&"stick_knob") and skin.joystick_art(true) != null,
			"stick: arcade_light's painted knob")
	else:
		check(skin.joystick_art(false) == null and skin.joystick_art(true) == null, "stick: a plain look draws circles")
	check(skin.joystick_idle_alpha == 0.55 and skin.joystick_active_alpha == 0.9, "stick: idle and active alpha")
	var stick := GoJoystick.new()
	stick.mode = GoJoystick.Mode.FIXED
	stick.radius = 70
	stick.knob_radius = 32
	var holder := _host(stick)
	await frames(2)
	check(stick.size == Vector2(140, 140), "stick: sized by its radius")
	holder.queue_free()
	await frames(1)


# ── A task card (GoTaskCard) and a spotlight (GoSpotlight) ─────────────

func _task_card(look: StringName) -> void:
	var skin := GoUi.skin()
	var card := GoTaskCard.new()
	card.caption = "TRAINING · STEP 1/12"
	card.title = "MOVE"
	card.short_caption = "1/12"
	card.body = "Knock both dummies out.\nMove with W A S D."
	card.footer = "Esc · pause"
	card.set_parts(PackedStringArray(["W", "A", "S", "D"]), [true, false, false, false])
	var holder := _host(card, 600.0)
	card.custom_minimum_size.x = 440.0
	await frames(2)
	check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "task card: never takes input")
	check(card.caption_label.text == "TRAINING · STEP 1/12" and card.title_label.text == "MOVE", "task card: caption and title")
	check(card.body_label.text.begins_with("Knock"), "task card: body")
	check(card.chips().size() == 4, "task card: one chip per part")
	check(card.chip_text(0) == "✓ W" and card.chip_text(1) == "A", "task card: a done part reads ✓")
	# The ✓ is not in most text fonts: a look that names a symbol font draws it from there, as the game's
	# Nunito falls back to Noto Sans KR; a look that names none leaves the theme's font alone.
	var word := card.chips()[0].get_child(0) as Label
	var symbols: Font = skin.symbol_font()
	if look == GoThemePresets.ARCADE_LIGHT:
		check(symbols != null and symbols.has_char(0x2713), "task card: arcade_light names a symbol font that has ✓")
		var drawn: Font = word.get_theme_font(&"font")
		check(drawn is FontVariation and (drawn as FontVariation).fallbacks.has(symbols),
			"task card: a chip's word falls back to the symbol font")
		check((drawn as FontVariation).base_font == card.get_theme_font(&"font", &"Label"),
			"task card: over the theme's own text font")
		check(drawn.has_char(0x2713) and drawn.has_char(0x57), "task card: the chip font draws ✓ and W")
	else:
		check(symbols == null, "task card: a plain look names no symbol font (%s)" % look)
		check(not word.has_theme_font_override(&"font"), "task card: no font override without a symbol font (%s)" % look)
	check(card.chips()[0].get_theme_stylebox(&"panel") != card.chips()[1].get_theme_stylebox(&"panel"),
		"task card: a done chip looks different (%s)" % look)
	check(not card.hint_label.visible, "task card: no hint, no hint row")
	card.hint = "Push them out!"
	check(card.hint_label.visible and card.hint_label.text == "Push them out!", "task card: a hint shows")
	check(card.hint_label.get_theme_color(&"font_color") == skin.task_hint_ink(), "task card: hint in task_hint_ink")
	check(card.title_label.get_theme_color(&"font_color") == skin.task_title_ink(), "task card: title in task_title_ink")
	check(card.title_label.get_theme_font_size(&"font_size") == 22, "task card: a short title at title_size")
	card.title = "A VERY LONG TITLE THAT NEVER FITS ON ONE LINE OF THIS CARD AT ALL"
	await frames(1)
	var fitted := card.title_label.get_theme_font_size(&"font_size")
	check(fitted < 22 and fitted >= GoStyle.fit_floor(22), "task card: a long title shrinks to fit (%d)" % fitted)
	card.mark_part(1, true)
	check(card.chip_text(1) == "✓ A", "task card: mark_part ticks a part")
	check(card.part_done(1) and not card.part_done(2), "task card: part_done reads it back")
	card.compact = true
	await frames(1)
	check(not card.title_label.visible and not card.body_label.visible and card.strip_label.visible,
		"task card: compact shows the strip only")
	check(card.strip_label.text == card.short_caption + "  " + card.title, "task card: the strip reads short caption + title")
	check(card.chips()[0].get_parent().get_parent() == card.strip_row, "task card: the chips move into the strip")
	card.compact = false
	await frames(1)
	check(card.title_label.visible and card.chips()[0].get_parent().get_parent() == card.chip_row, "task card: back to full")
	card.set_parts(PackedStringArray(["JUMP"]), [false])
	check(card.chips().size() == 1 and card.chip_text(0) == "JUMP", "task card: set_parts rebuilds the chips")
	if look == GoThemePresets.ARCADE_LIGHT:
		check(card.get_theme_stylebox(&"panel").content_margin_left == 25.0, "task card: arcade_light: padding 20 inside the 5 dp rim")
		check(skin.task_title_ink() == Color("#b8860b") and skin.task_hint_ink() == Color("#e8332f"),
			"task card: arcade_light: the game's title gold and hint red")
	holder.queue_free()
	await frames(1)


func _spotlight(look: StringName) -> void:
	var skin := GoUi.skin()
	var spot := GoSpotlight.new()
	spot.auto_advance = false
	var holder := _host(spot, 460.0)
	spot.size = Vector2(460, 320)
	await frames(1)
	check(spot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "spotlight: never takes input")
	check(spot.hole == Rect2(), "spotlight: nothing lit at first")
	spot.light(Rect2(150, 110, 160, 100))
	check(spot.hole == Rect2(150, 110, 160, 100), "spotlight: light() sets the hole")
	var dims := spot.dim_rects()
	check(dims.size() == 4, "spotlight: four dims")
	check(dims[0] == Rect2(0, 0, 460, 110) and dims[1] == Rect2(0, 210, 460, 110), "spotlight: dims above and below")
	check(dims[2] == Rect2(0, 110, 150, 100) and dims[3] == Rect2(310, 110, 150, 100), "spotlight: dims left and right")
	check(spot.dim_alpha() == 1.0, "spotlight: dim at full at first")
	spot.advance(2.2)
	check(is_equal_approx(spot.dim_alpha(), 0.5), "spotlight: the dim fades after dim_seconds (%f)" % spot.dim_alpha())
	spot.advance(1.0)
	check(spot.dim_alpha() == 0.0, "spotlight: then only the ring stays")
	spot.light(Rect2(10, 10, 20, 20))
	check(spot.dim_alpha() == 0.0, "spotlight: moving the hole keeps the age")
	spot.light(Rect2(10, 10, 20, 20), true)
	check(spot.dim_alpha() == 1.0, "spotlight: a fresh light dims again")
	var target := Control.new()
	holder.add_child(target)
	target.position = Vector2(40, 50)
	target.size = Vector2(30, 20)
	spot.follow(target)
	spot.advance(0.0)
	check(spot.hole == Rect2(32, 42, 46, 36), "spotlight: follow() lights a control grown by pad (%s)" % spot.hole)
	target.visible = false
	spot.advance(0.0)
	check(spot.hole == Rect2(), "spotlight: a hidden target lights nothing")
	spot.clear()
	check(spot.hole == Rect2() and spot.dim_rects().is_empty(), "spotlight: clear")
	check(skin.spotlight_dim().a > 0.0 and skin.spotlight_ring_box() != null, "spotlight: the skin gives a dim and a ring")
	if look == GoThemePresets.ARCADE_LIGHT:
		var ring := skin.spotlight_ring_box() as StyleBoxFlat
		check(ring != null and ring.border_width_left == 4 and ring.border_color == Color("#ffc928")
			and ring.corner_radius_top_left == 12 and not ring.draw_center, "spotlight: arcade_light: the 4 dp gold ring")
		check(skin.spotlight_dim() == Color(0.04, 0.06, 0.14, 0.55), "spotlight: arcade_light: the game's navy dim")
	holder.queue_free()
	await frames(1)


# ── A performance readout (GoPerfReadout) ──────────────────────────────

func _perf_stats(fps: float) -> Dictionary:
	return {&"fps": fps, &"ms": 1000.0 / fps, &"worst_ms": 31.25, &"triangles": 84321, &"draws": 212,
		&"nodes": 1234567, &"ram": 512 * 1048576, &"vram": 300 * 1048576}


func _perf_readout(look: StringName) -> void:
	var skin := GoUi.skin()
	var perf := GoPerfReadout.new()
	perf.sampling = false
	var holder := _host(perf, 600.0)
	await frames(1)
	check(perf.mouse_filter == Control.MOUSE_FILTER_IGNORE and perf.label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"perf: never takes input")
	check(perf.label.text == "FPS --\nTRI --  DRAW --  NODES --\nRAM --  VRAM --", "perf: placeholder before a reading")
	check(GoPerfReadout.format_count(999) == "999" and GoPerfReadout.format_count(84321) == "84.3k"
		and GoPerfReadout.format_count(1234567) == "1.23M", "perf: counts read 999 / 84.3k / 1.23M")
	check(GoPerfReadout.format_megabytes(512 * 1048576) == "512 MB", "perf: bytes read as MB")
	perf.show_stats(_perf_stats(60.0))
	check(perf.label.text == "FPS 60  16.7 ms  (worst 31.2)\nTRI 84.3k  DRAW 212  NODES 1.23M\nRAM 512 MB  VRAM 300 MB",
		"perf: three lines (%s)" % perf.label.text.c_escape())
	check(perf.write_count == 1, "perf: one write")
	perf.show_stats(_perf_stats(60.0))
	check(perf.write_count == 1, "perf: the same text is not written again")
	check(perf.label.get_theme_color(&"font_color") == skin.perf_ink(0), "perf: 60 fps in the good ink")
	perf.show_stats(_perf_stats(40.0))
	check(perf.label.get_theme_color(&"font_color") == skin.perf_ink(1), "perf: 40 fps in the warning ink")
	perf.show_stats(_perf_stats(20.0))
	check(perf.label.get_theme_color(&"font_color") == skin.perf_ink(2), "perf: 20 fps in the bad ink")
	check(perf.fps_level(55.0) == 0 and perf.fps_level(30.0) == 1 and perf.fps_level(29.9) == 2, "perf: levels at 55 / 30")
	perf.tier_text = "LOW (auto)"
	check(perf.label.text.ends_with("VRAM 300 MB  Q LOW (auto)"), "perf: the tier ends the last line")
	perf.one_line = true
	check(perf.label.text.count("\n") == 0 and perf.label.text.begins_with("FPS 20  50.0 ms"), "perf: one_line joins the lines")
	var box := perf.get_theme_stylebox(&"panel")
	check(box != null and box.content_margin_top == 2.0 and box.content_margin_left == 6.0, "perf: one_line is a slim band")
	perf.one_line = false
	box = perf.get_theme_stylebox(&"panel")
	check(box.content_margin_top == 6.0, "perf: full padding back")
	perf.sampling = true
	perf.restart()
	perf.advance(0.1)
	check(is_equal_approx(perf.stats()[&"fps"], 10.0), "perf: a restart reads at the next frame")
	perf.advance(0.1)
	perf.advance(0.2)
	check(is_equal_approx(perf.stats()[&"fps"], 1.0 / 0.15), "perf: then every interval, averaging the frames (%s)" % perf.stats().get(&"fps"))
	check(is_equal_approx(perf.stats()[&"worst_ms"], 200.0), "perf: and keeps the worst")
	perf.sampling = false
	check(not perf.is_processing(), "perf: sampling off stops the clock")
	check(perf.label.get_theme_constant(&"outline_size") == 2, "perf: a 2 dp outline")
	if look == GoThemePresets.ARCADE_LIGHT:
		check(skin.perf_ink(0) == Color("#3ecf5a") and skin.perf_ink(1) == Color("#ffc928") and skin.perf_ink(2) == Color("#ff4d4d"),
			"perf: arcade_light: the game's green / gold / red")
		check(perf.label.get_theme_font(&"font") == ThemeDB.fallback_font, "perf: arcade_light: the engine's font, as the game")
		var flat := skin.perf_box() as StyleBoxFlat
		check(flat != null and flat.bg_color == Color(0, 0, 0, 0.55) and flat.corner_radius_top_left == 4,
			"perf: arcade_light: the game's dark band")
	holder.queue_free()
	await frames(1)


# ── The per-inch scale profile (GoScale) ───────────────────────────────

func _per_inch_scale() -> void:
	var base := Vector2(1280, 720)
	check(is_equal_approx(GoScale.per_inch_factor(Vector2(2556, 1179), 460.0, base), 720.0 / 440.0),
		"scale: a small phone is held at min_height")
	check(is_equal_approx(GoScale.per_inch_factor(Vector2(1920, 1080), 300.0, base), 1.25), "scale: 160 units per inch")
	check(GoScale.per_inch_factor(Vector2(2360, 1640), 264.0, base) == 1.0, "scale: a tablet is never shrunk below 1")
	check(is_equal_approx(GoScale.per_inch_factor(Vector2(2266, 1488), 326.0, base), (1280.0 * 1488.0 / 2266.0) / (1488.0 / 326.0 * 160.0)),
		"scale: a 4:3-ish tablet's base height grows with its aspect")
	check(GoScale.per_inch_canvas(Vector2(1920, 1080), base, 1.25).is_equal_approx(Vector2(1024, 576)), "scale: the canvas size")
	check(GoScale.per_inch_factor(Vector2(1920, 1080), 300.0, base, 160.0, 440.0, false) == 1.0, "scale: off a handheld, 1")
	check(GoScale.web_dpi(192.0) == 320.0, "scale: a phone browser's dpi from devicePixelRatio")
	check(GoScale.cap_sides(Vector4(48, 20, 30, 10), 12.0) == Vector4(12, 20, 12, 10), "scale: cap_sides caps left and right")
	check(GoUi.config.scale_profile == GoScale.Profile.DP, "scale: the dp profile is the default")
