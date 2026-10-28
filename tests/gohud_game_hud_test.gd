## 🧪 **Checks for the match-HUD widgets** — the generic parts of Magnet Mayhem's in-match screen: the painted bar
## (`GoBar`'s frame), and the HUD's cards, touch keys, name plates, feed, spotlight, gesture hint, readout and scaling as they land.
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
		if look == GoThemePresets.ARCADE_LIGHT: await _bar_fill_keeps_its_rim()
		await _bar_ink(look)
		await _hud_card(look)
		await _bare_card(look)
		await _countdown(look)
		await _art_button(look)
		await _hud_button(look)
		await _nameplate(look)
		await _notice_feed(look)
		await _notice_feed_versus(look)
		await _touch_button(look)
		await _joystick_art(look)
		await _touch_lifecycle(look)
		await _touch_driven(look)
		await _joystick_driven(look)
		await _task_card(look)
		await _spotlight(look)
		await _gesture_hint(look)
		await _perf_readout(look)
		await _signal_bars(look)
		await _slot_touch(look)
		await _icon_focus(look)
	await _touch_label_cache()
	await _touch_follows_look()
	await _look_follows()
	_per_inch_scale()
	_device_rules()
	await _profile_applies()
	await _device_simulation()
	_obstructions()
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
			check(flat.get_minimum_size() == Vector2(6, 6), "bar: the frame reserves its 3 px rim on every side")
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
		var clip := frame.find_child("FillClip", true, false) as Panel
		check(frame.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED and clip != null
			and clip.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "bar: the inner track clips the fill without covering the rim")
		if painted and clip != null:
			var mask := clip.get_theme_stylebox(&"panel") as StyleBoxFlat
			check(mask != null and mask.corner_radius_top_left == 6 and mask.border_width_left == 0,
				"bar: the inner clip follows the corner inside the ink rim")
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


func _bar_fill_keeps_its_rim() -> void:
	var bar := GoBar.new()
	bar.readout = GoBar.Readout.NONE
	bar.icon_beside = true
	bar.icon = GoUi.skin().widget_art(&"shield")
	bar.segments = 0
	var holder := _host(bar, 200.0)
	bar.size.x = 200.0
	await frames(2)
	var frame := bar.find_child("Frame", true, false) as Panel
	var fill := bar.find_child("Gradient", true, false) as TextureRect
	for height: int in [14, 24, 48]:
		bar.thickness = height
		for ratio: float in [0.0, 0.01, 0.5, 1.0]:
			bar.set_ratio(ratio, false)
			await frames(2)
			var outer := frame.get_global_rect()
			var paint := fill.get_global_rect()
			check(paint.position.x >= outer.position.x + 3.0 and paint.position.y >= outer.position.y + 3.0,
				"bar: %d dp at %.0f%% keeps the left and top rim" % [height, ratio * 100.0])
			check(paint.end.x <= outer.end.x - 3.0 and paint.end.y <= outer.end.y - 3.0,
				"bar: %d dp at %.0f%% keeps the right and bottom rim" % [height, ratio * 100.0])
			check(is_equal_approx(paint.size.x, (outer.size.x - 6.0) * ratio),
				"bar: %.0f%% measures the inner track" % (ratio * 100.0))
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


# ── A bare card: no board, bars with their icon beside them, a tinted icon ─────────

func _bare_card(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var shield := skin.widget_art(&"shield")
	check((shield != null) == painted, "bare: %s %s the shield art" % [look, "ships" if painted else "has no"])
	if painted: check(shield.get_size() == Vector2(64, 64), "bare: the shield is 64 px")
	var status := GoHudCard.new()
	status.custom_minimum_size.x = 220.0
	# A look with no art: any picture will do for the layout.
	var stability := status.add_bar("", Color("#ff8a3d"), Color("#ffc24a"),
		shield if shield != null else GoUi.icons().texture(GoIconSet.STAR))
	var power := status.add_bar("", Color("#1fb5f0"), Color("#6ff0ff"), skin.widget_art(&"bolt"))
	for bar in [stability, power]:
		bar.segments = 0
		bar.icon_size = 28.0
		bar.icon_gap = 5
		bar.icon_beside = true
	var holder := _host(status)
	await frames(2)
	stability.set_values(70.0, 100.0, false)
	check(status.get_theme_stylebox(&"panel").get_minimum_size() != Vector2.ZERO or not painted,
		"bare: the card starts on the theme's board")
	status.show_panel = false
	await frames(1)
	var bare := status.get_theme_stylebox(&"panel")
	check(bare is StyleBoxEmpty and bare.get_minimum_size() == Vector2.ZERO, "bare: show_panel off draws no board, no margins")
	var row := status.find_child("Row", true, false) as Control
	check(row != null and row.position == Vector2.ZERO, "bare: the content starts at the card's corner")
	var track := stability.find_child("Track", true, false) as HBoxContainer
	var icon := stability.find_child("Icon", true, false) as TextureRect
	check(track != null and track.visible and icon != null and icon.get_parent() == track and track.get_child(0) == icon,
		"bare: icon_beside puts the icon first in the bar's track")
	check(track != null and track.get_theme_constant(&"separation") == 5, "bare: icon_gap spaces the icon from the bar")
	var shown := (stability.find_child("Frame", true, false) if painted else stability.find_child("Fill", true, false)) as Control
	check(shown != null and shown.get_parent() == track and shown.visible, "bare: the %s sits in the track" %
		("frame" if painted else "fill"))
	if shown != null and icon != null:
		check(icon.size == Vector2(28, 28), "bare: the icon keeps icon_size (got %s)" % icon.size)
		check(is_equal_approx(shown.size.y, 14.0), "bare: the bar keeps its thickness beside the icon (got %s)" % shown.size.y)
		check(shown.position.x >= icon.size.x + 5.0 - 0.5, "bare: the bar starts right of the icon (%s, %s)" % [shown.position, icon.size])
		check(absf(shown.get_global_rect().get_center().y - icon.get_global_rect().get_center().y) <= 0.5,
			"bare: the icon is centred on the bar (%s, %s)" % [shown.get_global_rect(), icon.get_global_rect()])
		check(shown.get_global_rect().end.x >= stability.get_global_rect().end.x - 0.5, "bare: the bar takes the rest of the width")
	var head := stability.find_child("Head", true, false) as Control
	check(head != null and not head.visible, "bare: an empty name row hides beside the icon")
	stability.label_text = "STABILITY"
	check(head != null and head.visible, "bare: a name brings the name row back")
	stability.label_text = ""
	stability.readout = GoBar.Readout.PERCENT
	check(head != null and head.visible, "bare: a readout brings the name row back")
	stability.readout = GoBar.Readout.NONE
	check(stability.segment_count() == 0, "bare: segments 0 is one smooth bar")
	stability.segments = 4
	await frames(1)
	check(stability.segment_count() == 4, "bare: segments still apply beside the icon")
	stability.icon_beside = false
	await frames(1)
	var title := stability.find_child("Title", true, false) as HBoxContainer
	check(icon != null and icon.get_parent() == title and title.get_child(0) == icon, "bare: icon_beside off puts the icon back before the name")
	check(shown != null and shown.get_parent() == stability.find_child("Column", true, false) and track != null and not track.visible,
		"bare: icon_beside off puts the bar back under the name row")
	check(head != null and head.visible, "bare: icon_beside off shows the name row")
	status.show_panel = true
	await frames(1)
	check(not (status.get_theme_stylebox(&"panel") is StyleBoxEmpty), "bare: show_panel on brings the board back")
	status.padding = 4.0
	status.show_panel = false
	check(status.get_theme_stylebox(&"panel") is StyleBoxEmpty, "bare: show_panel off wins over padding")
	status.show_panel = true
	check(status.get_theme_stylebox(&"panel").get_content_margin(SIDE_LEFT) >= 4.0, "bare: padding pads the board again")
	status.gauge = true
	status.show_panel = false
	check(not (status.get_theme_stylebox(&"panel") is StyleBoxEmpty), "bare: a gauge keeps its board")
	holder.queue_free()

	# A white icon from the icon set, tinted to read on the board.
	var count := GoHudCard.make(GoUi.icons().texture(GoIconSet.USERS), 28.0)
	count.layout = GoHudCard.Layout.INLINE
	count.value = "7"
	holder = _host(count)
	await frames(1)
	var picture := count.find_child("Icon", true, false) as TextureRect
	check(picture != null and picture.self_modulate == Color.WHITE, "bare: icon_ink transparent leaves the picture untinted")
	count.icon_ink = GoUi.color(GoTheme.ACCENT)
	check(picture != null and picture.self_modulate.is_equal_approx(GoUi.color(GoTheme.ACCENT)), "bare: icon_ink tints the picture")
	count.icon_ink = Color.TRANSPARENT
	check(picture != null and picture.self_modulate == Color.WHITE, "bare: icon_ink back to transparent clears the tint")
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
	# mirror: the same picture flipped left to right (a PLAY picture as a "previous" key), made once and shared.
	var arrow := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	arrow.set_pixel(0, 0, Color.RED)
	var arrow_texture := ImageTexture.create_from_image(arrow)
	button.art = arrow_texture
	button.mirror = true
	var flipped := button.icon.get_image()
	check(button.icon != arrow_texture and flipped.get_pixel(3, 0) == Color.RED and flipped.get_pixel(0, 0).a == 0.0,
		"art mirror: the picture is flipped left to right")
	check(GoIconButton.mirrored(arrow_texture) == button.icon, "art mirror: one flipped copy per picture")
	check(button.get_theme_stylebox(&"normal") is StyleBoxEmpty, "art mirror: still no frame")
	button.mirror = false
	check(button.icon == arrow_texture, "art mirror: off draws the picture as it is")
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
	# Read back, keyboard_focus is what the button is — the look's mode until the project chose — not the unset default.
	check(plain.keyboard_focus == (not arcade), "icon focus: keyboard_focus reads the look's mode (%s)" % look)
	check(chosen.keyboard_focus and not off.keyboard_focus, "icon focus: keyboard_focus reads the project's choice (%s)" % look)
	# Only a choice is saved in a scene: an unset button saved under arcade_light must not come back pinned off.
	check(not _stores(plain, &"keyboard_focus") and _stores(chosen, &"keyboard_focus") and _stores(off, &"keyboard_focus"),
		"icon focus: keyboard_focus is stored only once the project set it (%s)" % look)
	var other := GoThemePresets.DEFAULT_DARK if arcade else GoThemePresets.ARCADE_LIGHT
	GoUi.use_preset(other)
	await frames(1)
	check(plain.focus_mode == (Control.FOCUS_ALL if arcade else Control.FOCUS_NONE), "icon focus: follows a look change")
	check(plain.keyboard_focus == arcade, "icon focus: keyboard_focus reads the new look's mode")
	check(chosen.focus_mode == Control.FOCUS_ALL and off.focus_mode == Control.FOCUS_NONE,
		"icon focus: the project's choice survives a look change")
	check(chosen.keyboard_focus and not off.keyboard_focus, "icon focus: keyboard_focus still reads the project's choice")
	GoUi.use_preset(look)
	await frames(1)
	holder.queue_free()
	await frames(1)


## Whether [param node] saves [param property] in a scene.
func _stores(node: Object, property: StringName) -> bool:
	for entry in node.get_property_list():
		if entry.name == property: return entry.usage & PROPERTY_USAGE_STORAGE != 0
	return false


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


func _feed_parts(row: Control) -> Array:
	return [row.find_child("Left", true, false) as Label, row.find_child("Icon", true, false) as TextureRect,
		row.find_child("Text", true, false) as Label]


func _notice_feed_versus(look: StringName) -> void:
	var feed := GoNoticeFeed.new()
	feed.auto_advance = false
	var holder := _host(feed, 600.0)
	await frames(1)
	# Only arcade_light paints magnet_arrow; a plain look shows the skull it is handed instead.
	var magnet := GoUi.icons().texture(GoIconSet.MAGNET_ARROW)
	if magnet == null: magnet = GoUi.icons().texture(GoIconSet.SKULL)
	feed.push_versus("RED", magnet, "BLUE", false, Color.RED, Color.BLUE)
	var parts := _feed_parts(feed.rows()[0])
	var left := parts[0] as Label
	var icon := parts[1] as TextureRect
	var right := parts[2] as Label
	check(left.visible and left.text == "RED" and icon.texture == magnet and right.text == "BLUE",
		"versus: [left] [picture] [right] (%s)" % look)
	check(left.get_index() < icon.get_index() and icon.get_index() < right.get_index(), "versus: left, icon, right in order")
	check(left.get_theme_color(&"font_color") == Color.RED and right.get_theme_color(&"font_color") == Color.BLUE,
		"versus: each name in its own colour")
	check(left.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "versus: the names are shown as given")
	check(icon.custom_minimum_size.y == feed.icon_size, "versus: the picture is icon_size high")
	feed.push_versus("", GoUi.icons().texture(GoIconSet.FALL), "GREEN")
	parts = _feed_parts(feed.rows()[1])
	check(not (parts[0] as Label).visible and (parts[1] as TextureRect).visible and (parts[2] as Label).text == "GREEN",
		"versus: an empty left hides it — [picture] [right]")
	var normal := (parts[2] as Label)
	check(not normal.has_theme_color_override(&"font_color"), "versus: an alpha-0 colour keeps the theme's")
	feed.push("PLAIN")
	parts = _feed_parts(feed.rows()[2])
	check(not (parts[0] as Label).visible and (parts[2] as Label).text == "PLAIN" and (parts[1] as TextureRect).visible
		and (parts[1] as TextureRect).custom_minimum_size == Vector2(22, 22), "versus: a plain push hides Left, icon and text as before")
	check(not (parts[2] as Label).has_theme_color_override(&"font_color"), "versus: a plain push drops a reused row's colour")
	check(not (parts[2] as Label).has_theme_font_size_override(&"font_size"), "versus: no limit, no size set — the theme's")
	feed.push_versus("ME", magnet, "YOU", true)
	if look == GoThemePresets.ARCADE_LIGHT:
		check(feed.rows()[3].theme_type_variation == &"GoNoticeGold", "versus: own rows are gold")
	feed.clear()
	# Reuse: three into a pool of two keeps the two newest.
	feed.max_items = 2
	feed.push_versus("A1", magnet, "B1")
	feed.push_versus("A2", magnet, "B2")
	feed.push_versus("A3", magnet, "B3")
	var texts: Array = feed.rows().map(func(row: Control) -> String: return (_feed_parts(row)[0] as Label).text)
	check(feed.count == 2 and feed.get_child_count() == 2 and texts == ["A2", "A3"], "versus: max_items 2 keeps the two newest %s" % str(texts))
	feed.clear()
	# The width limit: two long names shrink together to fit; a short row keeps its size.
	feed.max_items = 4
	feed.font_size = 18
	feed.max_row_width = 260.0
	feed.fit_min_scale = 0.2
	feed.push_versus("WWWWWWWWWWWWWWW", magnet, "WWWWWWWWWWWWWWW")
	feed.push_versus("AB", magnet, "CD")
	await frames(2)
	var long_row := feed.rows()[0]
	parts = _feed_parts(long_row)
	var shrunk := (parts[0] as Label).get_theme_font_size(&"font_size")
	check(shrunk < 18 and shrunk == (parts[2] as Label).get_theme_font_size(&"font_size"), "versus: both names shrink together (%d)" % shrunk)
	check(long_row.size.x <= 260.0 and long_row.size.x > 200.0, "versus: the long row fits max_row_width (%.1f)" % long_row.size.x)
	check((parts[1] as TextureRect).custom_minimum_size.y == feed.icon_size, "versus: the icon keeps its size")
	var short_row := feed.rows()[1]
	parts = _feed_parts(short_row)
	check((parts[0] as Label).get_theme_font_size(&"font_size") == 18 and short_row.size.x < 200.0,
		"versus: a short row keeps font_size and its own width (%.1f)" % short_row.size.x)
	# The floor: at 0.9 the long names stop at ceil(18 × 0.9) = 17 and run over.
	feed.fit_min_scale = 0.9
	parts = _feed_parts(long_row)
	check((parts[0] as Label).get_theme_font_size(&"font_size") == 17, "versus: fit_min_scale is the floor (%d)" % (parts[0] as Label).get_theme_font_size(&"font_size"))
	# Alignment.
	check(long_row.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "versus: rows centred by default")
	feed.row_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	check(long_row.size_flags_horizontal == Control.SIZE_SHRINK_END, "versus: row_alignment RIGHT sets SHRINK_END")
	feed.row_alignment = HORIZONTAL_ALIGNMENT_LEFT
	check(long_row.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN, "versus: row_alignment LEFT sets SHRINK_BEGIN")
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
	await _touch_item_key(look)


## An item key: the painted banana / trap pictures under arcade_light, and the count badge on its rim.
func _touch_item_key(look: StringName) -> void:
	var skin := GoUi.skin()
	for art: StringName in [&"btn_banana", &"btn_trap"]:
		if look == GoThemePresets.ARCADE_LIGHT:
			check(skin.widget_art(art) != null and skin.widget_art(art).get_size() == Vector2(256, 256),
				"item key: arcade_light paints %s at 256" % art)
		else:
			check(skin.widget_art(art) == null, "item key: a plain look has no %s (an accent disc)" % art)
	var drop := GoTouchButton.make(&"btn_banana", "USE", 80.0)
	var holder := _host(drop)
	await frames(1)
	check(drop.badge.is_empty() and drop.badge_rect() == Rect2(), "item key: no badge by default")
	drop.badge = "×2"
	var plate := drop.badge_rect()
	var rim := Vector2(40, 40) + Vector2(1, -1).normalized() * 40.0
	check(plate.has_area() and plate.get_center().is_equal_approx(rim), "item key: the badge sits on the rim, up-right %s" % plate)
	check(plate.size.x >= plate.size.y and plate.size.y >= 16.0, "item key: the plate holds the count %s" % plate.size)
	check(skin.badge_box(GoUi.color(GoTheme.ACCENT)).get_minimum_size().y >= 0.0, "item key: the skin's badge plate")
	drop.badge = "×22"
	check(drop.badge_rect().size.x > plate.size.x - 0.01, "item key: a longer count widens the plate")
	_press(drop, Vector2(40, 40), true)
	check(drop.badge_rect().get_center().is_equal_approx(Vector2(40, 40) + Vector2(1, -1).normalized() * 40.0 * 0.93),
		"item key: the badge follows the press")
	_press(drop, Vector2(40, 40), false)
	check(not drop.hits(drop.get_global_transform_with_canvas() * (plate.end + Vector2(30, -30))),
		"item key: the badge adds no touch area")
	drop.badge = ""
	check(drop.badge_rect() == Rect2(), "item key: an empty badge draws none")
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

func _touch_down(control: Control, index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	event.position = at
	control._gui_input(event)


func _touch_drag(control: Control, index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	control._gui_input(event)


## A finger down while the button or stick is hidden or removed is let go (a button: `released(true)`), once.
func _touch_lifecycle(look: StringName) -> void:
	# hidden itself
	var button := GoTouchButton.make(&"btn_attract", "ATTRACT", 120.0)
	var holder := _host(button)
	await frames(1)
	var events: Array[String] = []
	button.released.connect(func(canceled: bool) -> void: events.append("up%s" % canceled))
	_touch_down(button, 0, Vector2(60, 60), true)
	check(button.is_held(), "touch hide: a finger holds it (%s)" % look)
	button.hide()
	check(not button.is_held() and events == ["uptrue"], "touch hide: hiding lets go with released(true) once (%s) %s" % [look, events])
	button.show()
	_touch_down(button, 0, Vector2(60, 60), false)
	check(events == ["uptrue"], "touch hide: the old finger lifting later says nothing more (%s)" % look)
	_touch_down(button, 1, Vector2(60, 60), true)
	check(button.is_held(), "touch hide: it takes a new finger after (%s)" % look)
	# a hidden parent
	holder.hide()
	check(not button.is_held() and events == ["uptrue", "uptrue"], "touch hide: a hidden parent lets go too (%s) %s" % [look, events])
	holder.show()
	# a mouse press
	_press(button, Vector2(60, 60), true)
	check(button.is_held(), "touch hide: a mouse press holds it (%s)" % look)
	button.visible = false
	check(not button.is_held() and events.size() == 3, "touch hide: the mouse press is let go as well (%s)" % look)
	button.visible = true
	# not held: hiding says nothing
	button.hide()
	button.show()
	check(events.size() == 3, "touch hide: hiding an idle button says nothing (%s)" % look)
	# removed from the tree
	_touch_down(button, 0, Vector2(60, 60), true)
	holder.remove_child(button)
	check(not button.is_held() and events.size() == 4 and events[3] == "uptrue", "touch exit: leaving the tree lets go (%s)" % look)
	button.free()
	holder.queue_free()
	await frames(1)
	# the joystick
	for stick_mode: int in [GoJoystick.Mode.FIXED, GoJoystick.Mode.FOLLOW]:
		var stick := GoJoystick.new()
		stick.mode = stick_mode
		stick.radius = 70
		holder = _host(stick)
		await frames(2)
		var log: Array[String] = []
		stick.released.connect(func() -> void: log.append("released"))
		stick.moved.connect(func(v: Vector2) -> void: log.append("moved%s" % v))
		_touch_down(stick, 0, Vector2(70, 70), true)
		_touch_drag(stick, 0, Vector2(130, 70))
		check(stick.is_active() and stick.vector().length() > 0.5, "stick hide: a drag moves it (%s)" % look)
		log.clear()
		stick.hide()
		check(not stick.is_active() and stick.vector() == Vector2.ZERO, "stick hide: hiding drops the drag (%s)" % look)
		check(log == ["released", "moved(0.0, 0.0)"], "stick hide: it says released and a zero vector once (%s) %s" % [look, log])
		stick.show()
		_touch_down(stick, 0, Vector2(70, 70), false)
		check(log.size() == 2, "stick hide: the old finger lifting later says nothing more (%s)" % look)
		_touch_down(stick, 1, Vector2(70, 70), true)
		check(stick.is_active(), "stick hide: it takes a new finger after (%s)" % look)
		log.clear()
		holder.remove_child(stick)
		check(not stick.is_active() and log == ["released", "moved(0.0, 0.0)"], "stick exit: leaving the tree drops the drag (%s) %s" % [look, log])
		stick.free()
		holder.queue_free()
		await frames(1)


## Driven from outside: the owner's `_input` routes the fingers (canvas coordinates) and the widgets only show it.
func _touch_driven(look: StringName) -> void:
	var button := GoTouchButton.make(&"btn_repulse", "REPULSE", 92.0)
	check(not button.driven and button.mouse_filter == Control.MOUSE_FILTER_STOP, "touch driven: off by default, takes input")
	var holder := _host(button)
	holder.position = Vector2(30, 40)
	await frames(1)
	button.driven = true
	check(button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "touch driven: input ignored (%s)" % look)
	var events: Array[String] = []
	button.pressed_down.connect(func() -> void: events.append("down"))
	button.released.connect(func(canceled: bool) -> void: events.append("up%s" % canceled))
	_press(button, Vector2(46, 46), true)
	_touch_down(button, 0, Vector2(46, 46), true)
	check(not button.is_held() and events.is_empty(), "touch driven: its own presses do nothing (%s)" % look)
	var centre := button.button_center()
	check(centre.is_equal_approx(Vector2(30 + 46, 40 + 46)), "touch driven: button_center in canvas coordinates (%s)" % centre)
	check(is_equal_approx(button.hit_radius(), 46.0 + 8.0), "touch driven: hit_radius is the rim plus hit_slop")
	check(button.hits(centre + Vector2(53, 0)) and not button.hits(centre + Vector2(55, 0)), "touch driven: hits() as its own press")
	button.drive_press(centre + Vector2(10, 0))
	check(button.is_held() and events == ["down"], "touch driven: drive_press holds it and says so (%s)" % look)
	check(button.radius() == 46.0 * 0.93, "touch driven: the press look, as a press of its own")
	button.drive_press(centre)
	check(events == ["down"], "touch driven: a second press while held does nothing")
	button.hide()
	check(button.is_held() and events == ["down"], "touch driven: hiding keeps the hold — the owner sees the lift")
	button.show()
	button.drive_release()
	check(not button.is_held() and events == ["down", "upfalse"], "touch driven: drive_release lifts it")
	button.drive_release()
	check(events.size() == 2, "touch driven: a release when not held says nothing")
	button.cooling = true
	button.cooldown = 0.4
	check(button.tint() == Color(0.72, 0.72, 0.8) and button.cooldown == 0.4, "touch driven: the cooldown ring as before")
	button.cooling = false
	button.drive_press()
	check(button.is_held(), "touch driven: drive_press() with no point holds it at the centre")
	button.driven = false
	check(not button.is_held() and events.back() == "uptrue" and button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"touch driven: turning it off lets go and takes input again (%s)" % [events])
	holder.queue_free()
	var attract := GoTouchButton.make(&"btn_attract", "ATTRACT", 120.0)
	attract.drag_aim = true
	attract.driven = true
	holder = _host(attract)
	holder.position = Vector2(100, 200)
	await frames(1)
	var aims: Array[Vector2] = []
	attract.aimed.connect(func(v: Vector2) -> void: aims.append(v))
	var at := attract.button_center()
	attract.drive_press(at)
	attract.drive_drag(at + Vector2(100, 0))
	check(attract.aim() == Vector2(1, 0) and attract.knob() == Vector2(110, 60), "touch driven: the aim knob stops at aim_radius (%s)" % attract.knob())
	check(aims.size() == 1 and aims[0] == Vector2(1, 0), "touch driven: aimed reports the pull")
	attract.drive_drag(at + Vector2(0, 25))
	check(attract.aim().is_equal_approx(Vector2(0, 0.5)), "touch driven: a half pull is half")
	attract.drive_release(true)
	check(not attract.is_held() and attract.aim() == Vector2.ZERO, "touch driven: released, no aim")
	holder.queue_free()
	await frames(1)


func _joystick_driven(look: StringName) -> void:
	var stick := GoJoystick.new()
	stick.mode = GoJoystick.Mode.FOLLOW
	stick.radius = 70
	check(not stick.driven and stick.mouse_filter == Control.MOUSE_FILTER_STOP, "stick driven: off by default")
	stick.driven = true
	check(stick.mouse_filter == Control.MOUSE_FILTER_IGNORE, "stick driven: input ignored")
	var holder := _host(stick)
	holder.position = Vector2(20, 300)
	await frames(2)
	var log: Array[String] = []
	stick.pressed_down.connect(func() -> void: log.append("down"))
	stick.released.connect(func() -> void: log.append("released"))
	stick.moved.connect(func(v: Vector2) -> void: log.append("moved%s" % v))
	_touch_down(stick, 0, Vector2(70, 70), true)
	check(not stick.is_active() and log.is_empty(), "stick driven: its own touches do nothing (%s)" % look)
	var land := Vector2(20 + 50, 300 + 60)
	check(stick.hits(land) and not stick.hits(Vector2(10, 300)), "stick driven: hits() is its rect, in canvas coordinates")
	stick.drive_begin(land)
	check(stick.is_active() and log == ["down"] and stick.center() == Vector2(50, 60) and stick.knob() == Vector2(50, 60),
		"stick driven: drive_begin settles the dish where the finger landed (%s)" % stick.center())
	stick.drive_drag(land + Vector2(140, 0))
	check(stick.knob() == Vector2(120, 60) and stick.vector() == Vector2(1, 0), "stick driven: the knob stops at radius")
	stick.drive_drag(land + Vector2(0, 35))
	check(stick.vector().is_equal_approx(Vector2(0, 0.5)), "stick driven: a half drag is half")
	stick.hide()
	check(stick.is_active(), "stick driven: hiding keeps the drag — the owner sees the lift")
	stick.show()
	log.clear()
	stick.drive_end()
	check(not stick.is_active() and log == ["released", "moved(0.0, 0.0)"], "stick driven: drive_end lifts it (%s)" % [log])
	stick.drive_end()
	check(log.size() == 2, "stick driven: idle, drive_end says nothing")
	stick.drive_begin(land)
	stick.driven = false
	check(not stick.is_active() and stick.mouse_filter == Control.MOUSE_FILTER_STOP, "stick driven: turning it off ends the drag")
	holder.queue_free()
	await frames(1)


func _touch_label_cache() -> void:
	var button := GoTouchButton.make(&"btn_repulse", "REPULSE", 92.0)
	var holder := _host(button)
	await frames(1)
	for i in 100:
		button.text = "%.1f" % (i * 0.1)
		button.label_font_size()
	check(button._fits.size() <= 1, "touch fit: a changing label keeps one cached size (%d)" % button._fits.size())
	button.text = "UNE TRES LONGUE ETIQUETTE"
	var shrunk := button.label_font_size()
	check(shrunk == 10 and button.label_font_size() == shrunk, "touch fit: the cached size is still right (%d)" % shrunk)
	button.text = "REPULSE"
	check(button.label_font_size() == 14, "touch fit: and follows the text back")
	holder.queue_free()
	await frames(1)


func _touch_follows_look() -> void:
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	var button := GoTouchButton.make(&"btn_repulse", "REPULSE", 92.0)
	var holder := _host(button)
	await frames(1)
	check(button.theme == GoUi.theme(), "touch look: built on the current look")
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(1)
	check(button.theme == GoUi.theme(), "touch look: follows a look switch")
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	check(button.theme == GoUi.theme(), "touch look: and back")
	# out of the tree during a look switch: back in, it is on the new look
	holder.remove_child(button)
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(1)
	holder.add_child(button)
	check(button.theme == GoUi.theme(), "touch look: back in the tree it takes the look that is current")
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	check(button.theme == GoUi.theme(), "touch look: and is watching again")
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
		check(skin.task_title_ink().is_equal_approx(Color("#b8860b")) and skin.task_hint_ink().is_equal_approx(Color("#e8332f")),
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
	spot.hold_dim = true
	spot.advance(30.0)
	check(spot.dim_alpha() == 1.0 and spot.hold_dim, "spotlight: hold_dim keeps the dim at full past the fade")
	spot.hold_dim = false
	check(spot.dim_alpha() == 0.0, "spotlight: off again, the dim is where its clock says")
	spot.light(Rect2(10, 10, 20, 20), true)
	var plain := GoSpotlight.new()
	check(not plain.hold_dim, "spotlight: hold_dim is off by default")
	plain.free()
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


# ── A gesture hint (GoGestureHint) ─────────────────────────────────────

func _hint_gap(hint: GoGestureHint) -> float:
	var at := hint.finger_positions()
	return at[0].distance_to(at[1]) if at.size() == 2 else -1.0


## Moves [param hint] on to [param u] of its loop (from where it is now, never backwards).
func _hint_to(hint: GoGestureHint, u: float) -> void:
	hint.advance(maxf(0.0, u - hint.progress()) * hint.loop_seconds)


func _gesture_hint(look: StringName) -> void:
	var still := GoUi.config.reduce_motion
	GoUi.config.reduce_motion = false
	var hint := GoGestureHint.new()
	hint.auto_advance = false
	var holder := _host(hint, 400.0)
	hint.size = Vector2(400, 300)
	await frames(1)
	check(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "gesture hint: never takes input")
	check(hint.gesture == GoGestureHint.Gesture.PINCH, "gesture hint: PINCH by default")
	check(not hint.playing and hint.finger_positions().is_empty(), "gesture hint: stopped at first, no fingertips")
	var painted := hint.paint_count
	hint.queue_redraw()
	await frames(2)
	check(hint.paint_count == painted, "gesture hint: draws nothing while stopped")
	hint.advance(1.0)
	check(hint.progress() == 0.0, "gesture hint: advance() does nothing while stopped")
	hint.play()
	check(hint.playing and hint.progress() == 0.0, "gesture hint: play() starts the loop from its beginning")
	_hint_to(hint, 0.05)
	await frames(2)
	check(hint.paint_count > painted, "gesture hint: draws once playing (%d)" % hint.paint_count)
	var at := hint.finger_positions()
	check(at.size() == 2, "gesture hint: two fingertips")
	check(((at[0] + at[1]) * 0.5).is_equal_approx(hint.size * 0.5), "gesture hint: centred in its rect")
	check(hint.ghost_alpha() > 0.0 and hint.ghost_alpha() < 1.0, "gesture hint: fades in (%f)" % hint.ghost_alpha())
	var closed := _hint_gap(hint)
	check(closed > 0.0 and hint.spread() == 0.0, "gesture hint: appears close together (%f)" % closed)
	var last := closed
	var widens := true
	for step in 6:
		_hint_to(hint, 0.10 + 0.05 * (step + 1))
		var now := _hint_gap(hint)
		if now < last - 0.001: widens = false
		last = now
	check(widens, "gesture hint: the fingertips spread apart")
	_hint_to(hint, 0.46)
	var open := _hint_gap(hint)
	at = hint.finger_positions()
	check(hint.spread() == 1.0 and hint.ghost_alpha() == 1.0, "gesture hint: holds apart, fully shown")
	check(open > closed * 2.0, "gesture hint: apart is far wider than together (%f vs %f)" % [open, closed])
	check(at[0].x > at[1].x and at[0].y < at[1].y, "gesture hint: along the diagonal, up-right and down-left")
	var inside := Rect2(Vector2.ZERO, hint.size).grow(-hint.finger_radius())
	check(inside.has_point(at[0]) and inside.has_point(at[1]), "gesture hint: apart, both fingertips stay in the rect")
	last = open
	var narrows := true
	for step in 6:
		_hint_to(hint, 0.52 + 0.05 * (step + 1))
		var now := _hint_gap(hint)
		if now > last + 0.001: narrows = false
		last = now
	check(narrows, "gesture hint: then pinch back together")
	_hint_to(hint, 0.86)
	check(is_equal_approx(_hint_gap(hint), closed) and hint.spread() == 0.0, "gesture hint: together again")
	_hint_to(hint, 0.95)
	check(hint.ghost_alpha() > 0.0 and hint.ghost_alpha() < 1.0, "gesture hint: fades out at the end of the loop")
	hint.advance(hint.loop_seconds * 0.10)
	check(hint.progress() < 0.1 and hint.playing, "gesture hint: loops round (%f)" % hint.progress())
	check(hint.loop_seconds >= 2.0 and hint.loop_seconds <= 3.0, "gesture hint: a loop of 2–3 s")
	_hint_to(hint, 0.46)
	hint.play()
	check(hint.progress() == 0.0, "gesture hint: play() mid-loop restarts it")
	# It scales to its rect: a bigger rect, a wider pinch and bigger fingertips (kept in 14..30 dp).
	_hint_to(hint, 0.46)
	var small_radius := hint.finger_radius()
	hint.size = Vector2(800, 600)
	check(_hint_gap(hint) > open * 1.8, "gesture hint: travel follows the rect's size (%f)" % _hint_gap(hint))
	check(hint.finger_radius() > small_radius and hint.finger_radius() <= 38.0, "gesture hint: fingertips grow, capped")
	hint.size = Vector2(80, 80)
	check(hint.finger_radius() >= 20.0, "gesture hint: fingertips never under 20 dp")
	hint.size = Vector2(400, 300)
	hint.stop()
	check(not hint.playing and hint.finger_positions().is_empty(), "gesture hint: stop() hides the fingertips")
	painted = hint.paint_count
	hint.queue_redraw()
	await frames(2)
	check(hint.paint_count == painted, "gesture hint: draws nothing once stopped")
	# Reduced motion: one still frame, apart, never moving.
	GoUi.config.reduce_motion = true
	hint.play()
	hint.advance(1.3)
	check(hint.progress() == 0.0 and hint.spread() == GoGestureHint.STILL_SPREAD and hint.ghost_alpha() == 1.0,
		"gesture hint: reduce_motion holds a still frame")
	check(_hint_gap(hint) > closed, "gesture hint: the still frame shows the fingertips apart")
	await frames(2)
	check(hint.paint_count > painted, "gesture hint: the still frame is drawn")
	GoUi.config.reduce_motion = false
	check(hint.ink_color() == GoUi.color(GoTheme.ACCENT), "gesture hint: rims in the look's accent")
	hint.ink = Color.RED
	check(hint.ink_color() == Color.RED, "gesture hint: ink overrides it")
	check(hint.theme == GoUi.theme(), "gesture hint: built with the look's theme")
	var skin := GoUi.skin()
	check(skin.has_method(&"draw_gesture_touch") and skin.has_method(&"draw_gesture_arrow"),
		"gesture hint: the skin draws the fingertip and the arrow (%s)" % look)
	hint.stop()
	GoUi.config.reduce_motion = still
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
	var themed := [0]
	perf.label.theme_changed.connect(func() -> void: themed[0] += 1)
	for i in 4: perf.show_stats(_perf_stats(60.0))
	check(themed[0] == 0, "perf: identical samples restyle the label never (%d theme changes)" % themed[0])
	perf.show_stats(_perf_stats(40.0))
	themed[0] = 0
	perf.show_stats(_perf_stats(40.0))
	check(themed[0] == 0, "perf: a repeated level is not restyled")
	perf.show_stats(_perf_stats(20.0))
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


# ── The signal meter ───────────────────────────────────────────────────

func _signal_bars(look: StringName) -> void:
	var arcade := look == GoThemePresets.ARCADE_LIGHT
	var meter := GoSignalBars.make()
	var holder := _host(meter, 400.0)
	await frames(1)
	check(meter.max_bars == 4 and meter.bars == 0 and meter.tone == GoSignalBars.Tone.NONE and meter.text == "",
		"signal: make() defaults — 0 of 4, no reading, no text")
	check(meter.mouse_filter == Control.MOUSE_FILTER_IGNORE and meter.meter.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and meter.label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "signal: never takes input")
	check(meter.layout_direction == Control.LAYOUT_DIRECTION_LTR, "signal: never flips with the language")
	check(not meter.label.visible, "signal: no text, no readout")
	check(meter.label.autowrap_mode == TextServer.AUTOWRAP_OFF and meter.label.has_meta(&"go_no_wrap"),
		"signal: the readout stays on one line (GoStyle.one_line)")
	# Clamping.
	meter.set_reading(9, GoSignalBars.Tone.GOOD)
	check(meter.lit() == 4 and meter.is_lit(3) and not meter.is_lit(4), "signal: more than max_bars lights them all")
	meter.bars = -3
	check(meter.bars == 0 and meter.lit() == 0, "signal: under 0 counts as 0")
	meter.max_bars = 0
	check(meter.max_bars == 1, "signal: max_bars is at least 1")
	meter.max_bars = 5
	meter.bars = 3
	check(meter.lit() == 3 and meter.bar_rects().size() == 5, "signal: 3 of 5")
	meter.tone = GoSignalBars.Tone.NONE
	check(meter.lit() == 0, "signal: NONE shows every bar dim, whatever bars says")
	meter.max_bars = 4
	# Geometry: rising left to right, standing on one line, the tallest bar_height × scale_factor.
	var rects := meter.bar_rects()
	var rising := true
	for i in range(1, rects.size()):
		rising = rising and rects[i].size.y > rects[i - 1].size.y and rects[i].position.x > rects[i - 1].end.x
		rising = rising and is_equal_approx(rects[i].end.y, rects[0].end.y)
	check(rising and rects[-1].size.y == 24.0, "signal: the bars rise left to right on one line, the tallest 24 dp")
	meter.scale_factor = 1.5
	await frames(1)
	check(meter.bar_rects()[-1].size.y == 36.0 and meter.meter.size == meter.meter_size(),
		"signal: scale_factor scales the bars (%s)" % meter.meter.size)
	meter.scale_factor = 1.0
	# Tone colours come from the fill tokens.
	var tones := {GoSignalBars.Tone.GOOD: GoTheme.SUCCESS_FILL, GoSignalBars.Tone.FAIR: GoTheme.WARNING_FILL,
		GoSignalBars.Tone.POOR: GoTheme.DANGER_FILL}
	for t: int in tones:
		meter.tone = t
		check(meter.tone_color() == GoUi.color(tones[t]), "signal: tone %d is %s" % [t, tones[t]])
	meter.tone = GoSignalBars.Tone.NONE
	check(meter.tone_color() == meter.dim_color(), "signal: NONE is the dim colour")
	var muted := GoUi.color(GoTheme.MUTED_FILL)
	check(meter.dim_color().is_equal_approx(Color(muted, muted.a * GoSignalBars.DIM_ALPHA)), "signal: dim is a faded muted_fill")
	# Text visibility and the outlined HUD text.
	meter.set_reading(4, GoSignalBars.Tone.GOOD, "48 ms")
	await frames(1)
	check(meter.label.visible and meter.label.text == "48 ms", "signal: the readout shows its text")
	check(meter.label.get_theme_constant(&"outline_size") > 0, "signal: over the scene the readout is outlined")
	check(meter.accessibility_name == "4/4 48 ms", "signal: a screen reader hears the reading (%s)" % meter.accessibility_name)
	if arcade:
		check(meter.label.theme_type_variation == GoSignalBars.VAR_TEXT
			and meter.label.get_theme_color(&"font_color") == Color.WHITE, "signal: arcade_light: white GoOutlineLabel text")
	else:
		check(meter.label.get_theme_color(&"font_color") == GoUi.skin().nameplate_ink(false),
			"signal: a look with no outlined label takes the name plate's ink")
	meter.text = ""
	check(not meter.label.visible, "signal: empty text hides the readout")
	# A fixed room keeps the bars still and shrinks a long text.
	meter.text_width = 40.0
	meter.text = "1480 ms"
	await frames(1)
	var fitted := meter.label.get_theme_font_size(&"font_size")
	check(meter.label.custom_minimum_size.x == 40.0 and fitted < 20 and fitted >= GoStyle.fit_floor(20),
		"signal: text_width holds the room and shrinks the text (%d)" % fitted)
	meter.text_width = 0.0
	# The board.
	check(meter.get_theme_stylebox(&"panel") is StyleBoxEmpty, "signal: no board by default")
	meter.panel = true
	var board := meter.get_theme_stylebox(&"panel")
	var probe := PanelContainer.new()
	probe.theme = meter.theme
	probe.theme_type_variation = GoSignalBars.VAR_PANEL
	holder.add_child(probe)
	var source_board := probe.get_theme_stylebox(&"panel")
	check(meter.theme_type_variation == GoSignalBars.VAR_PANEL and board.get_class() == source_board.get_class()
		and meter._board[0] == source_board and board != source_board,
		"signal: panel puts a padded copy of its selected GoHudPanel on the meter (variation %s, themes %s/%s, boxes %s/%s)" %
		[meter.theme_type_variation, meter.theme, probe.theme, board.get_class(), source_board.get_class()])
	probe.free()
	check(board.get_content_margin(SIDE_LEFT) >= GoStyle.face_clearance(meter, true) + GoSignalBars.BOARD_ROOM,
		"signal: the board keeps the readout off its rim (%s)" % board.get_content_margin(SIDE_LEFT))
	meter.refresh()
	check(meter.get_theme_stylebox(&"panel") == board, "signal: a refresh keeps the same padded board")
	check(meter.label.get_theme_constant(&"outline_size") == meter.label.get_theme_constant(&"outline_size", &"Label")
		and not meter.label.has_theme_color_override(&"font_color"), "signal: on the board, the board's label ink")
	meter.panel = false
	check(meter.get_theme_stylebox(&"panel") is StyleBoxEmpty, "signal: and off again")
	# Setters skip unchanged values; set_reading rebuilds once.
	var count := meter.get(&"_refreshes") as int
	meter.bars = meter.bars
	meter.max_bars = meter.max_bars
	meter.tone = meter.tone
	meter.text = meter.text
	meter.bar_height = meter.bar_height
	meter.scale_factor = meter.scale_factor
	meter.panel = meter.panel
	meter.set_reading(meter.bars, meter.tone, meter.text)
	check(meter.get(&"_refreshes") == count, "signal: unchanged values rebuild nothing")
	meter.set_reading(2, GoSignalBars.Tone.POOR, "300 ms")
	check(meter.get(&"_refreshes") == count + 1 and meter.lit() == 2 and meter.label.text == "300 ms",
		"signal: set_reading rebuilds once")
	# The skin draws: the hook exists on every look.
	check(GoUi.skin().has_method(&"draw_signal_bars"), "signal: the skin draws the bars")
	check(arcade == (GoUi.skin() is GoSkinArcade), "signal: arcade_light paints them as arcade keys")
	holder.queue_free()
	await frames(1)


# ── The HUD widgets follow a look change and a reparent ───────────────

## What a widget shows that comes from the look: its theme's panel box, its text font, the skin's inks. The widgets
## build in arcade_light, then the look switches to `to` (and back after a reparent) - each must take the new
## theme and repaint, as the established widgets do.
func _look_follows() -> void:
	var from := GoThemePresets.ARCADE_LIGHT
	var to := GoThemePresets.DEFAULT_DARK
	var makers: Dictionary = {
		"task card": func() -> Control:
			var card := GoTaskCard.new()
			card.title = "MOVE"
			card.set_parts(PackedStringArray(["W", "A"]), [true, false])
			return card,
		"countdown": func() -> Control:
			var count := GoCountdown.new()
			count.show_step("3")
			return count,
		"hud button": func() -> Control:
			return GoHudButton.make(GoUi.skin().widget_art(&"pause_button"), 52.0, "Esc"),
		"nameplate": func() -> Control: return GoNameplate.make("BOT RED", Color(0.86, 0.24, 0.24)),
		"notice feed": func() -> Control:
			var feed := GoNoticeFeed.new()
			feed.auto_advance = false
			feed.push("RED knocked out BLUE")
			return feed,
		"spotlight": func() -> Control:
			var spot := GoSpotlight.new()
			spot.auto_advance = false
			spot.light(Rect2(50, 50, 80, 60))
			return spot,
		"gesture hint": func() -> Control:
			var hint := GoGestureHint.new()
			hint.auto_advance = false
			hint.play()
			return hint,
		"signal bars": func() -> Control: return GoSignalBars.make(3, GoSignalBars.Tone.GOOD),
	}
	for key: String in makers:
		GoUi.use_preset(from)
		await frames(1)
		var widget := (makers[key] as Callable).call() as Control
		var holder := _host(widget, 400.0)
		widget.size = Vector2(400, 300)
		await frames(2)
		check(widget.theme == GoUi.theme(), "%s: built with the look's theme" % key)
		if key == "nameplate":
			check(GoUi._watchers.has(Callable(widget, &"_restyle")), "nameplate: live look changes watch its actual paint method")
		var before := _look_sig(key, widget)
		GoUi.use_preset(to)
		await frames(2)
		check(widget.theme == GoUi.theme(), "%s: takes the new look's theme when the look changes" % key)
		var after := _look_sig(key, widget)
		check(after != before, "%s: repaints in the new look (%s)" % [key, after])
		GoUi.use_preset(from)
		await frames(2)
		check(_look_sig(key, widget) == before, "%s: and back again (%s)" % [key, _look_sig(key, widget)])
		# A reparent (exit, enter, no second _ready) keeps it following.
		var other := Control.new()
		other.size = Vector2(400, 400)
		root.add_child(other)
		widget.get_parent().remove_child(widget)
		other.add_child(widget)
		await frames(1)
		GoUi.use_preset(to)
		await frames(2)
		check(widget.theme == GoUi.theme(), "%s: after a reparent it still takes the new theme" % key)
		check(_look_sig(key, widget) == after, "%s: after a reparent it still repaints (%s)" % [key, _look_sig(key, widget)])
		holder.queue_free()
		other.queue_free()
		await frames(1)
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)


## A widget's look-driven values as one string, so two looks compare unequal when it repainted.
func _look_sig(key: String, widget: Control) -> String:
	match key:
		"task card":
			var box := widget.get_theme_stylebox(&"panel")
			return "%s|%s|%s" % [box.get_class(), (widget as GoTaskCard).title_label.get_theme_color(&"font_color"),
				(widget as GoTaskCard).title_label.get_theme_font(&"font").resource_path]
		"countdown":
			var disc := widget.find_child("Disc", true, false) as TextureRect
			return "%s|%s|%s" % [disc.visible, widget.get_theme_color(&"font_color"), widget.get_theme_font(&"font").resource_path]
		"hud button":
			var hint := widget.find_child("Hint", true, false) as Label
			return "%s|%s" % [hint.get_theme_color(&"font_color"), hint.get_theme_font(&"font").resource_path]
		"nameplate":
			var label := widget.find_child("Name", true, false) as Label
			var plate := widget.get_theme_stylebox(&"panel") as StyleBoxFlat
			return "%s|%s|%s|%s|%s|%s|%s|%s" % [label.get_theme_color(&"font_color"), label.get_theme_font(&"font").resource_path,
				label.get_theme_constant(&"outline_size"), label.get_theme_color(&"font_outline_color"),
				plate.bg_color, plate.border_color, plate.border_width_left, plate.corner_radius_top_left]
		"notice feed":
			var row := (widget as GoNoticeFeed).rows()[0] as PanelContainer
			var text := row.find_child("Text", true, false) as Label
			var box := row.get_theme_stylebox(&"panel")
			return "%s|%s|%s" % [box.get_class(), text.get_theme_color(&"font_color"), text.get_theme_font(&"font").resource_path]
		"spotlight":
			var ring := widget.get(&"_ring") as StyleBoxFlat
			return "%s" % (ring.border_color if ring != null else "none")
		"gesture hint":
			return "%s" % (widget as GoGestureHint).ink_color()
		"signal bars":
			var bars := widget as GoSignalBars
			bars.text = "48 ms"
			return "%s|%s|%s|%s" % [bars.tone_color(), bars.dim_color(), bars.label.get_theme_color(&"font_color"),
				bars.label.get_theme_font(&"font").resource_path]
	return ""


# ── The per-inch scale profile (GoScale) ───────────────────────────────

func _per_inch_scale() -> void:
	var base := Vector2(1280, 720)
	check(is_equal_approx(GoScale.per_inch_factor(Vector2(2556, 1179), 460.0, base), 720.0 / 440.0),
		"scale: a small phone is held at min_height")
	check(is_equal_approx(GoScale.per_inch_factor(Vector2(1920, 1080), 300.0, base), 1.25), "scale: 160 units per inch")
	check(GoScale.per_inch_factor(Vector2(2360, 1640), 264.0, base) == 1.0, "scale: a tablet is never shrunk below 1")
	check(GoScale.per_inch_factor(Vector2(2400, 1080), 400.0, Vector2(640, 360)) == 1.0, "scale: a base shorter than min_height is not shrunk below 1")
	check(GoScale.per_inch_factor(Vector2(1920, 1080), 200.0, Vector2(640, 360)) >= 1.0, "scale: a short base never gives a factor below 1")
	check(is_equal_approx(GoScale.per_inch_factor(Vector2(2266, 1488), 326.0, base), (1280.0 * 1488.0 / 2266.0) / (1488.0 / 326.0 * 160.0)),
		"scale: a 4:3-ish tablet's base height grows with its aspect")
	check(GoScale.per_inch_canvas(Vector2(1920, 1080), base, 1.25).is_equal_approx(Vector2(1024, 576)), "scale: the canvas size")
	check(GoScale.per_inch_factor(Vector2(1920, 1080), 300.0, base, 160.0, 440.0, false) == 1.0, "scale: off a handheld, 1")
	check(GoScale.web_dpi(192.0) == 320.0, "scale: a phone browser's dpi from devicePixelRatio")
	check(GoScale.cap_sides(Vector4(48, 20, 30, 10), 12.0) == Vector4(12, 20, 12, 10), "scale: cap_sides caps left and right")
	check(GoUi.config.scale_profile == GoScale.Profile.DP, "scale: the dp profile is the default")


# ── A bar's ink does not rebuild its paint ─────────────────────────────

func _bar_ink(look: StringName) -> void:
	var bar := GoBar.new()
	bar.ink = Color("#1fb5f0")
	bar.ink_end = Color("#6ff0ff")
	var holder := _host(bar, 200.0)
	await frames(2)
	var gradient := bar.find_child("Gradient", true, false) as TextureRect
	var texture := gradient.texture
	var before := (texture as GradientTexture2D).gradient.colors
	bar.ink = Color("#1fb5f0")
	bar.ink_end = Color("#6ff0ff")
	check(gradient.texture == texture, "bar ink (%s): the same ink keeps the same texture" % look)
	bar.ink = Color("#f05030")
	check(gradient.texture == texture, "bar ink (%s): a new ink reuses the texture" % look)
	var after := (gradient.texture as GradientTexture2D).gradient.colors
	check(after[0].is_equal_approx(Color("#f05030")) and after[1].is_equal_approx(Color("#6ff0ff")) and after != before,
		"bar ink (%s): a new ink updates the gradient colours" % look)
	bar.ink_end = Color.TRANSPARENT
	after = (gradient.texture as GradientTexture2D).gradient.colors
	check(after[0].is_equal_approx(Color("#f05030")) and after[1].is_equal_approx(Color("#f05030")),
		"bar ink (%s): no end ink paints one colour" % look)
	holder.queue_free()
	await frames(1)


# ── scale_profile applies at once ──────────────────────────────────────

func _profile_applies() -> void:
	var runtime := Node.new()
	runtime.set_script(load("res://addons/gohud/core/go_runtime.gd"))
	runtime.name = "GoRuntime"
	root.add_child(runtime)
	await frames(1)
	var base := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	var was_enabled := GoUi.config.scale_enabled
	GoUi.config.scale_enabled = true
	GoUi.config.scale_profile = GoScale.Profile.DP
	await frames(1)
	root.content_scale_size = base + Vector2i(7, 7)
	GoUi.config.scale_profile = GoScale.Profile.PER_INCH
	check(root.content_scale_size == base, "scale: switching to per-inch applies at once (%s)" % root.content_scale_size)
	GoUi.config.scale_enabled = was_enabled
	GoUi.config.scale_profile = GoScale.Profile.DP
	runtime.queue_free()
	await frames(1)


# ── The device: phone browsers, a missing dpi, a simulated device (GoRuntime.simulate) ─────

## Magnet Mayhem's `DebugHooks.DEVICE_PROFILES`: window pixels, dpi, safe-area insets in window px (L, T, R, B), mobile.
const DEVICES := {
	"phone": {"size": Vector2i(2532, 1170), "dpi": 460.0, "insets": Vector4(141.0, 0.0, 141.0, 63.0), "mobile": true},
	"phone16x9": {"size": Vector2i(1334, 750), "dpi": 326.0, "insets": Vector4.ZERO, "mobile": true},
	"ipad": {"size": Vector2i(2388, 1668), "dpi": 264.0, "insets": Vector4(0.0, 0.0, 0.0, 40.0), "mobile": true},
	"deck": {"size": Vector2i(1280, 800), "dpi": 205.0, "insets": Vector4.ZERO, "mobile": false},
	"desktop": {"size": Vector2i(1280, 720), "dpi": 96.0, "insets": Vector4.ZERO, "mobile": false},
	"desktop4k": {"size": Vector2i(3840, 2160), "dpi": 163.0, "insets": Vector4.ZERO, "mobile": false},
	"store_phone": {"size": Vector2i(1920, 1080), "dpi": 400.0, "insets": Vector4.ZERO, "mobile": true},
	"phone_mini": {"size": Vector2i(2340, 1080), "dpi": 476.0, "insets": Vector4(150.0, 0.0, 150.0, 63.0), "mobile": true},
	"phone_pro": {"size": Vector2i(2622, 1206), "dpi": 460.0, "insets": Vector4(186.0, 60.0, 186.0, 60.0), "mobile": true},
	"phone_air": {"size": Vector2i(2736, 1260), "dpi": 460.0, "insets": Vector4(204.0, 60.0, 204.0, 87.0), "mobile": true},
	"ipad_mini": {"size": Vector2i(2266, 1488), "dpi": 326.0, "insets": Vector4(0.0, 48.0, 0.0, 40.0), "mobile": true},
	"android_720p": {"size": Vector2i(1600, 720), "dpi": 262.0, "insets": Vector4(48.0, 0.0, 0.0, 0.0), "mobile": true},
	"android_punch": {"size": Vector2i(2424, 1080), "dpi": 420.0, "insets": Vector4(118.0, 0.0, 0.0, 0.0), "mobile": true},
	"android_3button": {"size": Vector2i(2340, 1080), "dpi": 480.0, "insets": Vector4(105.0, 0.0, 144.0, 0.0), "mobile": true},
	"android_21x9": {"size": Vector2i(2520, 1080), "dpi": 449.0, "insets": Vector4.ZERO, "mobile": true},
	"fold_inner": {"size": Vector2i(2160, 1856), "dpi": 374.0, "insets": Vector4.ZERO, "mobile": true},
	"fold_flex": {"size": Vector2i(2160, 928), "dpi": 374.0, "insets": Vector4.ZERO, "mobile": true},
	"fold_cover": {"size": Vector2i(2376, 968), "dpi": 410.0, "insets": Vector4(100.0, 0.0, 0.0, 0.0), "mobile": true},
	"android_tablet": {"size": Vector2i(2560, 1600), "dpi": 274.0, "insets": Vector4.ZERO, "mobile": true},
}
const GAME_BASE := Vector2(1280, 720)


## Magnet Mayhem's `UiScale.scale_factor` (Cfg.Ui: 160 units per inch, never under 440 tall), line for line.
func _game_factor(px: Vector2, dpi: float, mobile: bool) -> float:
	if not mobile: return 1.0
	var h1 := GAME_BASE.y * maxf(1.0, (GAME_BASE.x / GAME_BASE.y) / (px.x / px.y))
	return h1 / clampf(px.y / dpi * 160.0, 440.0, h1)


## Magnet Mayhem's `UiScale` canvas and `safe_margins` (insets × canvas height / pixel height).
func _game_canvas(px: Vector2, f: float) -> Vector2:
	return px / (minf(px.x / GAME_BASE.x, px.y / GAME_BASE.y) * f)


func _device_rules() -> void:
	var features := func(names: Array) -> Callable: return func(name: String) -> bool: return names.has(name)
	check(GoScale.handheld_from(features.call(["android"])) and GoScale.handheld_from(features.call(["ios"])),
		"device: the Android and iOS apps are handheld")
	check(not GoScale.handheld_from(features.call(["web", "web_android"])), "device: a phone browser is not, by default")
	check(GoScale.handheld_from(features.call(["web", "web_android"]), true)
		and GoScale.handheld_from(features.call(["web", "web_ios"]), true), "device: with handheld_browsers it is")
	check(not GoScale.handheld_from(features.call(["web", "web_macos"]), true), "device: a desktop browser never is")
	check(not GoUi.config.handheld_browsers and GoUi.config.fallback_dpi == 0.0, "device: both off by default")
	check(GoScale.dpi_from(0.0, false) == 0.0, "device: no dpi and no fallback stays 0 (factor 1, as before)")
	check(GoScale.dpi_from(-1.0, true, 160.0) == 160.0 and GoScale.dpi_from(0.0, false, 160.0) == 160.0,
		"device: no dpi takes fallback_dpi, not rescaled (UiScale's FALLBACK_DPI)")
	check(GoScale.dpi_from(192.0, true, 160.0) == 320.0 and GoScale.dpi_from(326.0, false, 160.0) == 326.0,
		"device: a browser's dpi is rescaled, an app's kept")
	check(GoUi.config.safe_area_poll_seconds == 0.5 and GoUi.config.hud_side_inset_max < 0.0,
		"device: the safe area is polled every 0.5 s; no side cap by default")
	for name: String in DEVICES:
		var device: Dictionary = DEVICES[name]
		var px := Vector2(device["size"])
		var mobile: bool = device["mobile"]
		var f := _game_factor(px, device["dpi"], mobile)
		var ours := GoScale.per_inch_factor(px, device["dpi"], GAME_BASE, 160.0, 440.0, mobile)
		check(is_equal_approx(ours, f), "device %s: the per-inch factor is the game's (%f vs %f)" % [name, ours, f])
		var canvas := _game_canvas(px, f)
		check(GoScale.per_inch_canvas(px, GAME_BASE, ours).is_equal_approx(canvas), "device %s: the canvas is the game's" % name)
		var insets: Vector4 = device["insets"] if mobile else Vector4.ZERO
		var k := canvas.y / px.y
		var game_margins := insets * k
		var safe := GoSafeArea.inset_rect(Rect2(Vector2.ZERO, canvas), insets, px)
		var margins := Vector4(safe.position.x, safe.position.y, canvas.x - safe.end.x, canvas.y - safe.end.y)
		check(margins.is_equal_approx(game_margins), "device %s: the safe margins are the game's (%s vs %s)" % [name, margins, game_margins])
		var hud := GoScale.cap_sides(margins, 12.0)
		check(hud.is_equal_approx(Vector4(minf(game_margins.x, 12.0), game_margins.y, minf(game_margins.z, 12.0), game_margins.w)),
			"device %s: the HUD margins are the game's" % name)
	check(is_equal_approx(_game_factor(Vector2(2532, 1170), 460.0, true), 720.0 / 440.0), "device: the phone clamps to 440 tall")
	check(is_equal_approx(_game_factor(Vector2(2388, 1668), 264.0, true), 1.0), "device: the 11\" iPad is factor 1")


## `GoRuntime.simulate()` with every game device: the PER_INCH scale, the safe area, a 180° turn, the HUD side cap.
func _device_simulation() -> void:
	# 🛑 A host with the GoRuntime autoload (Magnet Mayhem) already has one: a second one is renamed, and the anchor
	#    would listen to the autoload while the test simulates on its own.
	var runtime := GoUi.runtime()
	var own_runtime := runtime == null
	if own_runtime:
		runtime = Node.new()
		runtime.set_script(load("res://addons/gohud/core/go_runtime.gd"))
		runtime.name = "GoRuntime"
		root.add_child(runtime)
		await frames(1)
	var kept_size := root.content_scale_size
	var kept_factor := root.content_scale_factor
	var kept_aspect := root.content_scale_aspect
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	GoUi.config.scale_enabled = true
	GoUi.config.scale_profile = GoScale.Profile.PER_INCH
	var heard: Array[Vector4] = []
	runtime.connect(&"safe_area_changed", func(margins: Vector4) -> void: heard.append(margins))
	var corner := GoHudAnchor.new()
	corner.edge_margin = 0
	var piece := Control.new()
	piece.custom_minimum_size = Vector2(40, 20)
	corner.add_child(piece)
	root.add_child(corner)
	await frames(2)
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	for name: String in DEVICES:
		var device: Dictionary = DEVICES[name]
		runtime.call(&"simulate", device)
		var px := Vector2(device["size"])
		var mobile: bool = device["mobile"]
		var f := GoScale.per_inch_factor(px, device["dpi"], base, 160.0, 440.0, mobile)
		check(is_equal_approx(root.content_scale_factor, f), "simulate %s: the window takes the per-inch factor (%f vs %f)" % [name, root.content_scale_factor, f])
		if base == GAME_BASE:
			check(is_equal_approx(root.content_scale_factor, _game_factor(px, device["dpi"], mobile)), "simulate %s: the game's factor" % name)
		var view := root.get_visible_rect()
		var want := GoSafeArea.inset_rect(view, device["insets"], px) if mobile else view
		check(GoSafeArea.usable_rect(root).is_equal_approx(want), "simulate %s: usable_rect is the simulated safe area" % name)
		var margins := GoSafeArea.margins(root)
		check((runtime.call(&"safe_margins") as Vector4).is_equal_approx(margins), "simulate %s: safe_margins() follows" % name)
		check(GoScale.is_handheld_screen() == mobile, "simulate %s: handheld as simulated" % name)
	check(not (runtime.call(&"simulation") as Dictionary).is_empty(), "simulate: simulation() reads it back")
	# A 180° turn: the notch moves to the other side and the window size does not change.
	var punch: Dictionary = (DEVICES["android_punch"] as Dictionary).duplicate()
	runtime.call(&"simulate", punch)
	await frames(1)
	var left := GoSafeArea.margins(root)
	check(left.x > 12.0 and left.z == 0.0, "simulate turn: the notch on the left (%s)" % left)
	check(corner.position.is_equal_approx(GoSafeArea.usable_rect(root).position), "simulate turn: the HUD keeps clear of it")
	heard.clear()
	punch["insets"] = Vector4(0.0, 0.0, 118.0, 0.0)
	runtime.call(&"simulate", punch)
	check(heard.size() == 1 and is_equal_approx(heard[0].z, left.x) and heard[0].x == 0.0,
		"simulate turn: safe_area_changed says the notch moved right (%s)" % [heard])
	check(corner.position.x == root.get_visible_rect().position.x, "simulate turn: the HUD moved back to the edge with no resize")
	runtime.call(&"simulate", punch)
	check(heard.size() == 1, "simulate turn: the same safe area says nothing")
	# The HUD's side cap (Magnet Mayhem's HUD_SIDE_INSET_MAX).
	runtime.call(&"simulate", DEVICES["phone"])
	await frames(1)
	var whole := GoSafeArea.margins(root)
	check(GoSafeArea.hud_rect(root).is_equal_approx(GoSafeArea.usable_rect(root)), "hud cap: none by default")
	GoUi.config.hud_side_inset_max = 12.0
	GoUi.refresh()
	await frames(1)
	var hud := GoSafeArea.hud_rect(root)
	var view := root.get_visible_rect()
	check(is_equal_approx(hud.position.x - view.position.x, 12.0) and is_equal_approx(view.end.x - hud.end.x, 12.0)
		and is_equal_approx(hud.position.y - view.position.y, whole.y) and is_equal_approx(view.end.y - hud.end.y, whole.w),
		"hud cap: the sides capped at 12, top and bottom whole (%s of %s)" % [hud, whole])
	check(corner.position.is_equal_approx(hud.position), "hud cap: GoHudAnchor keeps to it (%s)" % corner.position)
	check(GoSafeArea.hud_rect(root, 0.0).position.x == view.position.x, "hud cap: a cap given as an argument wins")
	GoUi.config.hud_side_inset_max = -1.0
	# Back to the real device: a headless run is a desktop, factor 1 and no safe area.
	runtime.call(&"clear_simulation")
	check((runtime.call(&"simulation") as Dictionary).is_empty() and GoScale.simulated().is_empty(), "simulate: cleared")
	check(root.content_scale_factor == 1.0 and GoSafeArea.margins(root) == Vector4.ZERO, "simulate: the real desktop again")
	GoScale.simulate({"handheld": true, "insets": Vector4(10, 0, 0, 0), "size": Vector2i(100, 100)})
	GoUi.reset()
	check(GoScale.simulated().is_empty(), "simulate: GoUi.reset() clears it")
	GoUi.config.reduce_motion = true
	corner.queue_free()
	if own_runtime: runtime.queue_free()
	root.content_scale_size = kept_size
	root.content_scale_factor = kept_factor
	root.content_scale_aspect = kept_aspect
	await frames(1)


## 📷 `GoSafeArea.obstructions()` on simulated phones and the corner geometry — the HUD's edge-to-edge model: an iPhone's
## island derived from its symmetric insets (one side when named, both when not), the home strip, an Android phone's own
## holes, the corner radius in UI units, and `corner_shift` / `corner_keep` keeping shapes inside the rounded glass.
func _obstructions() -> void:
	var view := root.get_visible_rect()
	# iPhone 15 Pro landscape: 2556 × 1179 px @3x — insets 59 / 59 / 21 pt, island 126 pt, corner 55 pt.
	var px := Vector2(2556, 1179)
	var k := view.size / px
	GoScale.simulate({"handheld": true, "size": Vector2i(px), "platform": "ios", "insets": Vector4(177, 0, 177, 63),
		"screen_scale": 3.0, "notch_side": SIDE_LEFT})
	var obs := GoSafeArea.obstructions(root)
	var holes: Array[Rect2] = obs["holes"]
	check(holes.size() == 1, "obstructions ios: one island on the named side (%s)" % [holes])
	if holes.size() == 1:
		var island := holes[0]
		check(is_equal_approx(island.position.x, view.position.x) and is_equal_approx(island.size.x, 177.0 * k.x)
			and is_equal_approx(island.size.y, 378.0 * k.y) and is_equal_approx(island.get_center().y, view.get_center().y),
			"obstructions ios: the island is 126 pt long, the inset deep, centred on the left edge (%s)" % island)
	var strip: Rect2 = obs["gesture"]
	check(is_equal_approx(strip.size.y, 63.0 * k.y) and is_equal_approx(strip.end.y, view.end.y) and is_equal_approx(strip.size.x, view.size.x),
		"obstructions ios: the home strip is the bottom inset (%s)" % strip)
	check(is_equal_approx(float(obs["corner_radius"]), 165.0 * k.x), "obstructions ios: corner 55 pt by default (%s)" % obs["corner_radius"])
	var bars: Vector4 = obs["bars"]
	check(bars.x == 0.0 and bars.y == 0.0 and bars.z == 0.0 and is_equal_approx(bars.w, 63.0 * k.y),
		"obstructions ios: both side insets released (the island and its mirror), the home strip kept (%s)" % bars)
	GoScale.simulate({"handheld": true, "size": Vector2i(px), "platform": "ios", "insets": Vector4(177, 0, 177, 63), "screen_scale": 3.0})
	holes = GoSafeArea.obstructions(root)["holes"]
	check(holes.size() == 2 and holes[0].size.y < view.size.y * 0.5, "obstructions ios: side unknown — the island band on both long sides, not the whole edge (%s)" % [holes])
	# Portrait: the island on the top edge; a notch (47 pt) is the wide 210-pt cutout; an iPad's 24-pt status bar is none.
	check(GoSafeArea.ios_holes(Vector2(1179, 2556), Vector4(0, 177, 0, 102), 3.0) == ([Rect2(400.5, 0, 378, 177)] as Array[Rect2]),
		"ios_holes: portrait island centred on the top edge")
	check(GoSafeArea.ios_holes(Vector2(1170, 2532), Vector4(0, 141, 0, 102), 3.0)[0].size.x == 630.0, "ios_holes: a 47-pt notch is 210 pt wide")
	check(GoSafeArea.ios_holes(Vector2(1668, 2388), Vector4(0, 48, 0, 40), 2.0).is_empty(), "ios_holes: an iPad's status bar is no cutout")
	GoScale.simulate({"handheld": true, "size": Vector2i(2388, 1668), "platform": "ios", "insets": Vector4(0, 48, 0, 40), "screen_scale": 2.0})
	var pad_obs := GoSafeArea.obstructions(root)
	check((pad_obs["holes"] as Array).is_empty() and is_equal_approx(float(pad_obs["corner_radius"]), 36.0 * view.size.x / 2388.0),
		"obstructions iPad: no cutout, the 18-pt tablet corner (%s)" % pad_obs["corner_radius"])
	check(is_equal_approx((pad_obs["bars"] as Vector4).y, 48.0 * view.size.y / 1668.0), "obstructions iPad: its status bar stays a bar")
	# Android: its own holes (and they are its simulated insets), corner from dpi when not given.
	GoScale.simulate({"handheld": true, "size": Vector2i(2400, 1080), "platform": "android", "dpi": 420.0,
		"cutouts": [Rect2(0, 500, 90, 80)]})
	obs = GoSafeArea.obstructions(root)
	var ak := view.size / Vector2(2400, 1080)
	check((obs["holes"] as Array).size() == 1 and (obs["holes"][0] as Rect2).is_equal_approx(Rect2(0, 500 * ak.y, 90 * ak.x, 80 * ak.y)),
		"obstructions android: the platform's hole in UI units (%s)" % [obs["holes"]])
	check((obs["gesture"] as Rect2) == Rect2(), "obstructions android: no gesture strip")
	check((obs["bars"] as Vector4) == Vector4.ZERO, "obstructions android: the hole-only inset is released")
	check(GoSafeArea.bar_insets(Vector4(0, 40, 0, 24), Vector4(0, 22, 0, 0)) == Vector4(0, 40, 0, 24),
		"bar_insets: a 40-unit status bar over a 22-unit hole stays, a bottom bar stays")
	check(GoSafeArea.bar_insets(Vector4(29.09, 0, 0, 0), Vector4(29.09, 0, 0, 0)) == Vector4.ZERO, "bar_insets: the Realme's waterdrop gutter is released")
	check(is_equal_approx(float(obs["corner_radius"]), 32.0 * 420.0 / 160.0 * ak.x), "obstructions android: 32 dp at the device dpi")
	check(is_equal_approx(GoSafeArea.usable_rect(root).position.x - view.position.x, 90.0 * ak.x), "usable_rect android: the holes are its insets")
	check(GoSafeArea.hole_insets(Vector2(2400, 1080), ([Rect2(0, 500, 90, 80), Rect2(1000, 1040, 60, 40)] as Array[Rect2])) == Vector4(90, 0, 0, 40),
		"hole_insets: each hole on its nearest edge")
	GoUi.config.respect_safe_area = false
	check((GoSafeArea.obstructions(root)["holes"] as Array).is_empty(), "obstructions: none with respect_safe_area off")
	GoUi.config.respect_safe_area = true
	GoScale.simulate({})
	check((GoSafeArea.obstructions(root)["holes"] as Array).is_empty() and float(GoSafeArea.obstructions(root)["corner_radius"]) == 0.0,
		"obstructions: none on a desktop")
	# Corners: a box flush in a corner steps diagonally 0.29 r; a round control of radius ≥ r needs nothing.
	var screen := Rect2(0, 0, 800, 400)
	var r := 50.0
	var step := GoSafeArea.corner_shift(Rect2(0, 0, 100, 40), screen, r)
	check(is_equal_approx(step.x, r * (1.0 - sqrt(0.5))) and is_equal_approx(step.y, step.x), "corner_shift: top-left box steps 0.29 r diagonally (%s)" % step)
	var moved := Rect2(Vector2(0, 0) + step, Vector2(100, 40))
	check(GoSafeArea.corner_shift(moved, screen, r) == Vector2.ZERO, "corner_shift: once moved it is clear")
	check(GoSafeArea.corner_shift(Rect2(720, 320, 80, 80), screen, 40.0, true) == Vector2.ZERO, "corner_shift: a round control as big as the corner fits")
	var ball := GoSafeArea.corner_shift(Rect2(720, 320, 80, 80), screen, r, true)
	check(ball.x < 0.0 and ball.y < 0.0 and is_equal_approx(-ball.x, (r - 40.0) * (1.0 - sqrt(0.5))), "corner_shift: a smaller round one steps (r − its r) × 0.29 up-left (%s)" % ball)
	check(GoSafeArea.corner_shift(Rect2(300, 0, 100, 40), screen, r) == Vector2.ZERO, "corner_shift: mid-edge needs nothing")
	var row := GoSafeArea.corner_shift(Rect2(9, 359, 30, 34), screen, r, false, Vector2.AXIS_X)
	check(row.y == 0.0 and is_equal_approx(row.x, 41.0 - sqrt(r * r - 43.0 * 43.0)) and
		GoSafeArea.corner_shift(Rect2(Vector2(9.0 + row.x, 359.0), Vector2(30, 34)), screen, r).is_zero_approx(),
		"corner_shift along x: a bottom row steps right only, just enough (%s)" % row)
	check(GoSafeArea.corner_shift(Rect2(0, 0, 100, 40), screen, 0.0) == Vector2.ZERO, "corner_shift: square glass needs nothing")
	var keep := GoSafeArea.corner_keep(screen, r)
	check(keep.size() == 8, "corner_keep: an L of two bars at each corner")
	var clear_box := Rect2(Vector2.ONE * r * (1.0 - sqrt(0.5)), Vector2(60, 30))
	var touches := false
	for bar: Rect2 in keep: touches = touches or bar.intersects(clear_box)
	check(not touches and GoSafeArea.corner_shift(clear_box, screen, r).is_zero_approx(), "corner_keep: a box clear of the bars is inside the arc")
