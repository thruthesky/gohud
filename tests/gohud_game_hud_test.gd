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
