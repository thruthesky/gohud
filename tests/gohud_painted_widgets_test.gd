## 🧪 **Checks for the painted widgets** — the generic parts of Magnet Mayhem's painted UI: `GoStyle.fit_font_size`,
## `GoCoverImage`, `GoKeyCluster`, `GoLevelCard`, `GoGlyphButton`, `GoKbd.done` and `GoSurface`'s title glyph,
## overhanging ribbon and opaque backdrop. Each runs in arcade_light (the game's values) and in a plain look (the
## fallbacks: no art, no variations, no errors).
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_painted_widgets_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

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
	_fit()
	_cover()
	for look: StringName in [GoThemePresets.ARCADE_LIGHT, GoThemePresets.DEFAULT_DARK]:
		GoUi.use_preset(look)
		await frames(1)
		_skin_hooks(look)
		await _key_cluster(look)
		await _level_card(look)
		await _glyph_button(look)
		await _kbd_done(look)
		await _surface(look)
		await _defaults(look)
		await _glyph_overrides(look)
	await _reparent()
	for look: StringName in GoThemePresets.ids():
		GoUi.use_preset(look)
		await frames(1)
		_kbd_done_box(look)
	GoUi.reset()
	GoUi.reset()
	print("gohud painted widgets tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


# ── Shrink to fit ──────────────────────────────────────────────────────

func _fit() -> void:
	var font := ThemeDB.fallback_font
	check(GoUi.config.fit_min_scale == 0.7, "fit: the config's floor is the game's 0.7")
	check(GoStyle.fit_floor(22) == 16, "fit: fit_floor(22) = ceil(22 × 0.7) = 16 (got %d)" % GoStyle.fit_floor(22))
	check(GoStyle.fit_floor(22, 0.5) == 11, "fit: a passed min_scale wins")
	check(GoStyle.fit_font_size(PackedStringArray(["OK"]), 22, 1000.0, font) == 22, "fit: a text with room keeps its size")
	var long := "A VERY LONG TRANSLATION OF A STAGE NAME"
	var fitted := GoStyle.fit_font_size(PackedStringArray([long]), 22, 200.0, font)
	check(fitted < 22 and fitted >= 16, "fit: a long text shrinks, never under the floor (got %d)" % fitted)
	check(fitted == 16 or GoStyle.row_width(font, PackedStringArray([long]), fitted) <= 200.0,
		"fit: above the floor the shrunk text fits its room")
	check(GoStyle.fit_font_size(PackedStringArray([long]), 22, 1.0, font) == 16, "fit: no room stops at the floor")
	var one := GoStyle.row_width(font, PackedStringArray(["AB"]), 20)
	var two := GoStyle.row_width(font, PackedStringArray(["AB", "AB"]), 20)
	check(is_equal_approx(two, one * 2.0), "fit: row_width sums the texts on the row")
	check(is_equal_approx(GoStyle.row_width(font, PackedStringArray(["AB\nA"]), 20), one),
		"fit: a text with a line break counts its widest line")
	GoUi.config.fit_min_scale = 0.5
	check(GoStyle.fit_floor(20) == 10, "fit: the floor follows GoConfig.fit_min_scale")
	GoUi.config.fit_min_scale = 0.7
	check(GoStyle.fit_font_size(PackedStringArray(["X"]), 20, 5.0) >= 14, "fit: a null font takes the theme's")


# ── Cover image ────────────────────────────────────────────────────────

func _cover() -> void:
	var wide := GoCoverImage.cover_rect(Vector2(100, 100), Vector2(200, 100))
	check(wide.size == Vector2(200, 100) and wide.position == Vector2(-50, 0),
		"cover: a wide picture is scaled to the height and centred (got %s)" % wide)
	var tall := GoCoverImage.cover_rect(Vector2(100, 50), Vector2(100, 100), Vector2(0.5, 0.0))
	check(tall.size == Vector2(100, 100) and tall.position == Vector2(0, 0), "cover: focus (0.5, 0) keeps the top")
	var low := GoCoverImage.cover_rect(Vector2(100, 50), Vector2(100, 100), Vector2(0.5, 1.0))
	check(low.position == Vector2(0, -50), "cover: focus (0.5, 1) keeps the bottom")
	var image := GoCoverImage.make(null, Vector2(2, -1))
	check(image.focus == Vector2(1, 0), "cover: the focus is clamped to 0..1")
	check(image.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cover: it lets presses through")
	image.free()


# ── Skin hooks ─────────────────────────────────────────────────────────

func _skin_hooks(look: StringName) -> void:
	var skin := GoUi.skin()
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var ring := skin.selection_ring_box() as StyleBoxFlat
	check(ring != null and not ring.draw_center, "%s: the selection ring is an open frame" % look)
	if painted:
		check(ring.border_color == Color("#ffd23f") and ring.border_width_left == 4 and ring.corner_radius_top_left == 26,
			"%s: the game's gold ring (#ffd23f, 4, radius 26)" % look)
		check(skin.title_plate_overhang() == Vector2(14, 17), "%s: the ribbon hangs 17 over, 14 past" % look)
		check(skin.opaque_backdrop_color() == Color(0.36, 0.62, 0.92, 1), "%s: the opaque backdrop is the sky" % look)
		var cap := skin.key_cluster_box() as GoStyleBoxSprite
		check(cap != null and is_equal_approx(cap.pixels_per_unit, 4.2) and cap.content_margin_left == 0.0,
			"%s: the key cluster's keycap is ppu 4.2 with no padding" % look)
		var done := skin.kbd_done_box() as GoStyleBoxSprite
		check(done != null and done.tint == Color("#8ff0a4"), "%s: the done keycap is tinted #8ff0a4" % look)
		for part: StringName in [&"check", &"lock", &"person", &"play_tag", &"pointer"]:
			var path := GoSkinArcadePainted.STAGE_ART + String(part) + ".png"
			check(ResourceLoader.exists(path), "%s: %s ships" % [look, path])
			check(skin.widget_art(part) != null, "%s: widget_art(%s) is the shipped art" % [look, part])
	else:
		check(skin.title_plate_overhang() == Vector2.ZERO, "%s: no overhang by default" % look)
		check(skin.widget_art(&"check") == null, "%s: no art by default" % look)
		check(skin.opaque_backdrop_color().a == 1.0, "%s: the opaque backdrop is solid" % look)
		check(skin.kbd_done_box() != null, "%s: a done cap exists" % look)
	check(skin.widget_art(&"no_such_art") == null, "%s: unknown art is null, no error" % look)


# ── Key cluster ────────────────────────────────────────────────────────

func _key_cluster(look: StringName) -> void:
	var keys := GoKeyCluster.make()
	root.add_child(keys)
	await frames(1)
	check(keys.custom_minimum_size == Vector2(110, 72), "%s cluster: 3 keys + 2 gaps by 2 keys + a gap" % look)
	var rects := keys.key_rects()
	check(rects[0].position == Vector2(38, 0) and rects[1].position == Vector2(0, 38) and rects[2].position == Vector2(38, 38)
		and rects[3].position == Vector2(76, 38), "%s cluster: an inverted T" % look)
	check(keys.label_at(0) == "W" and keys.label_at(3) == "D" and keys.label_at(9) == "", "%s cluster: WASD by default" % look)
	check(GoKeyCluster.arrow_direction("↑") == Vector2.UP and GoKeyCluster.arrow_direction("right") == Vector2.RIGHT
		and GoKeyCluster.arrow_direction("W") == Vector2.ZERO, "%s cluster: arrow labels become triangles" % look)
	check(keys.word_size("W") == 18, "%s cluster: a short word keeps the label size" % look)
	check(keys.word_size("Space") < 18 and keys.word_size("Space") >= 13, "%s cluster: a long word shrinks to the floor" % look)
	var picks := [0]
	keys.picked.connect(func() -> void: picks[0] += 1)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = keys.get_global_rect().get_center()
		click.global_position = click.position
		keys.get_viewport().push_input(click, true)
	check(picks[0] == 1, "%s cluster: a click emits picked once (got %d)" % [look, picks[0]])
	keys.labels = GoKeyCluster.ARROWS
	keys.key_size = 40.0
	check(keys.custom_minimum_size == Vector2(128, 84), "%s cluster: the size follows key_size" % look)
	await frames(1)
	keys.queue_free()
	await frames(1)


# ── Level card ─────────────────────────────────────────────────────────

func _level_card(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var holder := VBoxContainer.new()
	holder.theme = GoUi.theme() # as a screen is: the theme's own VBox gap must not reach the card's lock column
	root.add_child(holder)
	var card := GoLevelCard.make("STAGE 1", "OPPONENTS: 1", GoLevelCard.State.CLEARED)
	holder.add_child(card)
	await frames(2)
	check(card.custom_minimum_size == Vector2(300, 98), "%s card: the game's 300 × 98" % look)
	check(card.check.visible and not card.play_tag.visible and not card.lock.visible, "%s card: cleared shows the check" % look)
	check(card.check.get_child_count() > 0, "%s card: the check has art or a fallback" % look)
	var check_art := card.check.get_child(0) as Control if card.check.get_child_count() > 0 else null
	check(check_art != null and check_art.size.is_equal_approx(card.check.size),
		"%s card: the check's art fills its box (got %s)" % [look, check_art.size if check_art != null else Vector2.ZERO])
	check(is_equal_approx(card.check.offset_right, 46 * 0.28) and is_equal_approx(card.check.offset_top, -46 * 0.28),
		"%s card: the check sits over the top-right corner" % look)
	check(card.summary() == "STAGE 1\nOPPONENTS: 1", "%s card: the summary" % look)
	check(not card.disabled, "%s card: a cleared card takes presses" % look)
	check(card.focus_mode == Control.FOCUS_ALL, "%s card: keyboard and gamepad can reach it" % look)
	card.grab_focus()
	check(card.has_focus() and card.get_theme_stylebox(&"focus") == card.selection_ring.get_theme_stylebox(&"panel"),
		"%s card: the focused card wears the selection ring" % look)
	card.release_focus()
	var has_vars := GoUi.theme().get_type_list().has(GoLevelCard.VAR_CARD)
	check(card.theme_type_variation == (GoLevelCard.VAR_CARD if has_vars else GoTheme.VAR_BUTTON),
		"%s card: the variation, or GoButton without one (got %s)" % [look, card.theme_type_variation])
	if painted:
		# The game (StageCard.show_state): ink #1d2340 with no outline on the blue card.
		check(card.ink().to_html() == "1d2340ff" and card.title_label.get_theme_color(&"font_color").to_html() == "1d2340ff",
			"%s card: the cleared card's ink is the game's #1d2340 (got %s)" % [look, card.ink().to_html()])
		check(card.title_label.get_theme_constant(&"outline_size") == 0
			and card.subtitle_label.get_theme_constant(&"outline_size") == 0, "%s card: dark text has no outline" % look)

	card.state = GoLevelCard.State.CURRENT
	await frames(1)
	check(card.play_tag.visible and not card.check.visible, "%s card: current shows the PLAY! tag" % look)
	check(card.tag_label.text == "PLAY!" and is_equal_approx(card.play_tag.rotation_degrees, -9.0),
		"%s card: the tag says PLAY! tilted -9°" % look)
	check(is_equal_approx(card.play_tag.offset_left, -112.0) and is_equal_approx(card.play_tag.offset_top, -44 * 0.55),
		"%s card: the tag sits at the top-right" % look)
	check(card.theme_type_variation == (GoLevelCard.VAR_CURRENT if GoUi.theme().get_type_list().has(GoLevelCard.VAR_CURRENT)
		else GoTheme.VAR_PRIMARY_BUTTON), "%s card: current wears its variation or GoPrimaryButton" % look)
	if painted:
		# The game: white text outlined 4 (title) and 3 (opponents) on the green card.
		check(card.ink() == Color.WHITE and card.outline_ink().a > 0.0, "%s card: the current card's ink is white" % look)
		check(card.title_label.get_theme_constant(&"outline_size") == 4
			and card.subtitle_label.get_theme_constant(&"outline_size") == 3, "%s card: outlined 4 and 3, as the game" % look)
	card.play_text = "JUGAR!"
	check(card.tag_label.text == "PLAY!", "%s card: a change waits for the end of the frame" % look)
	await frames(1)
	check(card.tag_label.text == "JUGAR!", "%s card: the tag text is a parameter" % look)

	card.state = GoLevelCard.State.LOCKED
	card.locked_text = "VERROUILLÉ"
	await frames(1)
	check(card.disabled and card.lock.visible and card.locked_label.visible, "%s card: locked shows the padlock" % look)
	check(card.summary().ends_with("\nVERROUILLÉ"), "%s card: the locked caption is a parameter" % look)
	check(card.lock.custom_minimum_size.x >= 56.0, "%s card: the lock column is at least 56 wide" % look)
	check(card.thumbnail_slot.clip_contents,
			"%s card: the thumbnail slot clips (the game's MapPreview does), so no half row of the well shows when scaled" % look)
	check(card.lock.get_theme_constant(&"separation") == 4,
			"%s card: the padlock sits 4 px over LOCKED, as the game (not the theme's VBox gap)" % look)
	card.state = GoLevelCard.State.OPEN
	await frames(1)
	check(not card.disabled, "%s card: unlocking takes back the disabled the lock set" % look)
	card.disabled = true
	card.state = GoLevelCard.State.LOCKED
	await frames(1)
	card.state = GoLevelCard.State.OPEN
	await frames(1)
	check(card.disabled, "%s card: a card the caller disabled stays disabled after a lock and unlock" % look)
	card.disabled = false
	card.tooltip_text = "Stage one"
	card.state = GoLevelCard.State.LOCKED
	card.selected = true
	await frames(1)
	check(card.tooltip_text == "Stage one", "%s card: a refresh keeps the caller's tooltip" % look)
	card.selected = false
	check(card.locked_label.get_theme_font_size(&"font_size") >= 8, "%s card: LOCKED never under 8" % look)
	if painted:
		check(card.ink() == Color.WHITE and card.title_label.get_theme_constant(&"outline_size") == 4
			and card.locked_label.get_theme_constant(&"outline_size") == 3,
			"%s card: the locked card is white, outlined 4 and LOCKED 3, as the game" % look)

	card.state = GoLevelCard.State.OPEN
	card.title = "A STAGE WITH A REALLY VERY LONG TRANSLATED NAME"
	await frames(1)
	var title_px := card.title_label.get_theme_font_size(&"font_size")
	check(title_px < 22 and title_px >= 16, "%s card: a long title shrinks to fit (got %d)" % [look, title_px])
	check(not card.check.visible and not card.lock.visible and not card.play_tag.visible, "%s card: open shows no state" % look)
	var words := Translation.new()
	words.locale = TranslationServer.get_locale()
	words.add_message("LVL_KEY", "A STAGE WITH A REALLY VERY LONG TRANSLATED NAME")
	TranslationServer.add_translation(words)
	card.title = "LVL_KEY"
	await frames(1)
	var key_px := card.title_label.get_theme_font_size(&"font_size")
	check(key_px < 22, "%s card: the translation is fitted, not the short key (got %d)" % [look, key_px])
	TranslationServer.remove_translation(words)
	card.title = "A STAGE WITH A REALLY VERY LONG TRANSLATED NAME"
	await frames(1)

	card.selected = true
	await frames(1)
	check(card.selection_ring.visible and card.selection_ring.get_theme_stylebox(&"panel") is StyleBoxFlat,
		"%s card: selected shows the ring" % look)
	var picture := ImageTexture.create_from_image(Image.create(8, 4, false, Image.FORMAT_RGBA8))
	card.thumbnail = picture
	check(card.thumbnail_slot.custom_minimum_size == Vector2(74, 74), "%s card: the thumbnail slot is 74" % look)
	var preview := Control.new()
	card.thumbnail_slot.add_child(preview)
	await frames(1)
	var pad := 12.0 if GoUi.theme().get_type_list().has(GoLevelCard.VAR_WELL) else 0.0
	check(preview.anchor_right == 1.0 and preview.anchor_bottom == 1.0 and is_equal_approx(preview.offset_left, pad)
		and is_equal_approx(preview.offset_bottom, -pad), "%s card: a node put in the slot fills it inside the well (pad %s)" % [look, pad])
	preview.free()
	card.scale_factor = 0.5
	await frames(1)
	check(card.custom_minimum_size.x == 150.0, "%s card: every size follows scale_factor" % look)
	check(card.custom_minimum_size.y >= float(GoUi.config.min_touch_size), "%s card: never under a touch target" % look)
	var own := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	card.state = GoLevelCard.State.CLEARED
	card.check_texture = own
	card.refresh()
	var art := card.check.get_child(0) as TextureRect
	check(art != null and art.texture == own, "%s card: an exported texture wins over the skin's art" % look)
	holder.queue_free()
	await frames(1)


# ── Glyph button ───────────────────────────────────────────────────────

func _glyph_button(look: StringName) -> void:
	var glyph := ImageTexture.create_from_image(Image.create(20, 20, false, Image.FORMAT_RGBA8))
	var button := GoGlyphButton.make("PLAY", &"", GoTheme.VAR_PRIMARY_BUTTON, glyph)
	button.custom_minimum_size = Vector2(240, 60)
	root.add_child(button)
	await frames(2)
	check(is_equal_approx(button.glyph_allowance(), 60.0 * 0.62 + 8.0), "%s glyph: 0.62 of the height + the gap" % look)
	var face := button.get_theme_stylebox(&"normal")
	check(face is GoGlyphButton.ShiftedBox, "%s glyph: the faces shift the label right" % look)
	var rect := button.glyph_rect()
	check(is_equal_approx(rect.size.y, 60.0 * 0.62), "%s glyph: the glyph is 0.62 × the height" % look)
	var font := button.get_theme_font(&"font")
	var text_w := font.get_string_size("PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size(&"font_size")).x
	var group_left := rect.position.x
	var group_right := rect.end.x + GoGlyphButton.GAP + text_w
	var base := (face as GoGlyphButton.ShiftedBox).base
	var middle := (base.get_margin(SIDE_LEFT) + button.size.x - base.get_margin(SIDE_RIGHT)) * 0.5
	check(absf((group_left + group_right) * 0.5 - middle) < 1.5, "%s glyph: glyph + label are centred together (%.1f..%.1f, mid %.1f)" % [look, group_left, group_right, middle])
	check(GoUi._watchers.has(Callable(button, &"_on_ui_changed")), "%s glyph: an icon-set swap measures the shift again" % look)
	if look == GoThemePresets.ARCADE_LIGHT: await _glyph_button_game_margins(glyph)
	var normal_tint := button.glyph_tint()
	button.disabled = true
	check(is_equal_approx(button.glyph_tint().a, normal_tint.a * 0.6), "%s glyph: a disabled glyph is 0.6 opaque" % look)
	button.disabled = false
	button.layout_direction = Control.LAYOUT_DIRECTION_RTL
	await frames(1)
	var flipped := button.glyph_rect()
	var shifted := button.get_theme_stylebox(&"normal")
	check(shifted is GoGlyphButton.ShiftedBox and shifted.get_margin(SIDE_RIGHT) > shifted.get_margin(SIDE_LEFT) - 0.01
		and flipped.position.x > button.size.x * 0.5, "%s glyph: right to left, the glyph stands at the label's right" % look)
	var rtl_left := flipped.position.x - GoGlyphButton.GAP - text_w
	var rtl_mid := (base.get_margin(SIDE_LEFT) + button.size.x - base.get_margin(SIDE_RIGHT)) * 0.5
	check(absf((rtl_left + flipped.end.x) * 0.5 - rtl_mid) < 1.5, "%s glyph: right to left, still centred together" % look)
	button.layout_direction = Control.LAYOUT_DIRECTION_INHERITED
	await frames(1)
	button.glyph = null
	check(not (button.get_theme_stylebox(&"normal") is GoGlyphButton.ShiftedBox), "%s glyph: no glyph, no shift" % look)
	button.glyph_icon = GoIconSet.PLAY
	check((button.glyph_texture() != null) == (GoUi.icons().texture(GoIconSet.PLAY) != null),
		"%s glyph: an icon-set name resolves" % look)
	button.queue_free()
	await frames(1)


## The painted pills place the label as Magnet Mayhem's GlossButton: the shift moves from the right padding to the
## left, the right never under 0 — so a glyph-only square keeps the size it was given.
func _glyph_button_game_margins(glyph: Texture2D) -> void:
	var holder := Control.new()
	holder.theme = GoUi.theme()
	root.add_child(holder)
	var wide := GoGlyphButton.make("PLAY", &"", GoTheme.VAR_PRIMARY_BUTTON, glyph)
	wide.custom_minimum_size = Vector2(0, 62)
	var square := GoGlyphButton.make("", &"", GoTheme.VAR_PRIMARY_BUTTON, glyph)
	square.custom_minimum_size = Vector2(56, 56)
	holder.add_child(wide)
	holder.add_child(square)
	await frames(2)
	for button: GoGlyphButton in [wide, square]:
		var face := button.get_theme_stylebox(&"normal") as GoGlyphButton.ShiftedBox
		var shift := button.glyph_allowance() * 0.5
		var base := face.base
		check(is_equal_approx(face.get_margin(SIDE_LEFT), base.get_margin(SIDE_LEFT) + shift)
			and is_equal_approx(face.get_margin(SIDE_RIGHT), maxf(base.get_margin(SIDE_RIGHT) - shift, 0.0)),
			"glyph: the label's padding moves by the shift, as the game's (%.1f/%.1f over %.1f/%.1f)" % [
				face.get_margin(SIDE_LEFT), face.get_margin(SIDE_RIGHT), base.get_margin(SIDE_LEFT), base.get_margin(SIDE_RIGHT)])
	check(is_equal_approx(square.size.x, 56.0), "glyph: a glyph-only square keeps its 56 px, as the game's (%.1f)" % square.size.x)
	holder.queue_free()
	await frames(1)


# ── Done keycap ────────────────────────────────────────────────────────

func _kbd_done(look: StringName) -> void:
	var kbd := GoKbd.make("W")
	kbd.hide_on_handheld = false
	root.add_child(kbd)
	await frames(1)
	var plain := (kbd.get_child(0) as PanelContainer).get_theme_stylebox(&"panel")
	kbd.done = true
	await frames(1)
	var cap := kbd.get_child(kbd.get_child_count() - 1) as PanelContainer
	var green := cap.get_theme_stylebox(&"panel")
	check(GoSkin.box_background(green) != GoSkin.box_background(plain), "%s kbd: a done cap changes colour" % look)
	if look == GoThemePresets.ARCADE_LIGHT:
		check(green is GoStyleBoxSprite and (green as GoStyleBoxSprite).tint == Color("#8ff0a4"),
			"%s kbd: the painted keycap tinted #8ff0a4" % look)
	kbd.queue_free()
	await frames(1)


## Every bundled look: the done cap shows green where the plain cap is, and its word reads on it.
func _kbd_done_box(look: StringName) -> void:
	var skin := GoUi.skin()
	var page := Color(GoUi.color(GoTheme.BACKGROUND), 1.0)
	var plain := GoSkin.blend(GoSkin.box_background(skin.kbd_box()), page)
	var green_box := skin.kbd_done_box()
	var green := GoSkin.blend(GoSkin.box_background(green_box), page)
	check(GoSkin.box_background(green_box).a > 0.0 and not green.is_equal_approx(plain),
		"%s kbd done: the cap shows a fill of its own (plain %s, done %s)" % [look, plain.to_html(), green.to_html()])
	check(green.g > green.r and green.g > green.b, "%s kbd done: the cap reads green (%s)" % [look, green.to_html()])
	var ink := skin.kbd_done_ink()
	var ratio := GoSkin.contrast_ratio(GoSkin.blend(ink, green), green)
	check(ratio >= 4.5, "%s kbd done: the word reads on the green (%.2f)" % [look, ratio])


# ── Defaults leave the old widgets as they were ───────────────────────

func _defaults(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var kbd := GoKbd.make("W")
	kbd.hide_on_handheld = false
	root.add_child(kbd)
	var surface := GoSurface.new()
	surface.set_title("SETTINGS")
	root.add_child(surface)
	await frames(2)
	check(not kbd.done, "%s defaults: a key cap is not done" % look)
	var cap := (kbd.get_child(0) as PanelContainer).get_theme_stylebox(&"panel")
	check(GoSkin.box_background(cap) == GoSkin.box_background(GoUi.skin().kbd_box()), "%s defaults: the cap is kbd_box" % look)
	check(not surface.opaque and surface.title_glyph == null, "%s defaults: no glyph, not opaque" % look)
	var marks := surface.title_label.get_children(true).filter(func(n): return n is TextureRect)
	check(marks.is_empty(), "%s defaults: no glyph node on the title" % look)
	var scrim := surface.get_node(^"Scrim") as ColorRect
	check(scrim.color == GoUi.color(GoTheme.SCRIM) or scrim.color.a == 0.0, "%s defaults: the scrim is the look's veil" % look)
	if not painted:
		check(not (surface.title_label.get_theme_stylebox(&"normal") is GoSurface.OverhangPlate),
			"%s defaults: a look with no ribbon keeps its plate unwrapped" % look)
		check(surface.title_overhang() == 0.0, "%s defaults: nothing hangs over the card" % look)
	kbd.queue_free()
	surface.queue_free()
	await frames(1)


# ── Glyph button: the caller's face and a glyph too wide for the padding ─

func _glyph_overrides(look: StringName) -> void:
	var own := StyleBoxFlat.new()
	own.bg_color = Color.REBECCA_PURPLE
	own.set_content_margin_all(10.0)
	var button := GoGlyphButton.make("GO", &"", GoTheme.VAR_BUTTON)
	button.add_theme_stylebox_override(&"normal", own)
	root.add_child(button)
	await frames(1)
	button.glyph = ImageTexture.create_from_image(Image.create(20, 20, false, Image.FORMAT_RGBA8))
	var wrapped := button.get_theme_stylebox(&"normal") as GoGlyphButton.ShiftedBox
	check(wrapped != null and wrapped.base == own and wrapped.was_override,
		"%s glyph: the caller's own face is wrapped, not replaced" % look)
	button.glyph = null
	check(button.get_theme_stylebox(&"normal") == own and button.has_theme_stylebox_override(&"normal"),
		"%s glyph: dropping the glyph puts the caller's face back" % look)
	button.remove_theme_stylebox_override(&"normal")

	# A wide glyph on a tall button: half its room is more than the right padding gives.
	var bare := button.get_combined_minimum_size().x
	button.custom_minimum_size = Vector2(0, 80)
	button.glyph = ImageTexture.create_from_image(Image.create(60, 20, false, Image.FORMAT_RGBA8))
	await frames(1)
	var face := button.get_theme_stylebox(&"normal") as GoGlyphButton.ShiftedBox
	var shift := button.glyph_allowance() * 0.5
	check(face != null and shift > face.base.get_margin(SIDE_RIGHT), "%s glyph: the shift is wider than the padding" % look)
	check(button.get_combined_minimum_size().x > bare, "%s glyph: the button grows to hold a wide glyph" % look)
	var rect := button.glyph_rect()
	var font := button.get_theme_font(&"font")
	var text_w := font.get_string_size("GO", HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size(&"font_size")).x
	var middle := (face.base.get_margin(SIDE_LEFT) + button.size.x - face.base.get_margin(SIDE_RIGHT)) * 0.5
	var group := (rect.position.x + rect.end.x + GoGlyphButton.GAP + text_w) * 0.5
	check(rect.position.x >= GoGlyphButton.MIN_EDGE - 0.01 and absf(group - middle) < 1.5,
		"%s glyph: a wide glyph still stands centred with its label (group %.1f, mid %.1f)" % [look, group, middle])
	button.queue_free()
	await frames(1)


# ── Reparent ───────────────────────────────────────────────────────────

func _reparent() -> void:
	var first := Control.new()
	var second := Control.new()
	root.add_child(first)
	root.add_child(second)
	var kbd := GoKbd.make("W")
	var widgets: Array[Node] = [GoLevelCard.make("STAGE 1"), GoKeyCluster.make(), kbd]
	for node in widgets: first.add_child(node)
	await frames(1)
	for node in widgets:
		node.reparent(second)
	await frames(1)
	for node in widgets:
		check(GoUi._watchers.has(Callable(node, &"_on_ui_changed")),
			"%s still follows the look after reparent()" % node.name)
	first.queue_free()
	second.queue_free()
	await frames(1)


# ── Window extras ──────────────────────────────────────────────────────

func _surface(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var surface := GoSurface.new()
	surface.set_title("SETTINGS")
	surface.body.add_child(GoStyle.label("Body", GoTheme.ROLE_BODY))
	root.add_child(surface)
	await frames(3)
	var glyph := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	surface.title_glyph = glyph
	await frames(2)
	var mark := surface.title_label.get_node_or_null(^"TitleGlyph") as TextureRect
	if mark == null:
		for child in surface.title_label.get_children(true):
			if child is TextureRect: mark = child
	check(mark != null and mark.texture == glyph, "%s surface: the title glyph is shown" % look)
	if mark != null:
		var side := surface.title_glyph_side()
		check(is_equal_approx(mark.size.x, side), "%s surface: the glyph follows the title size" % look)
		# A Label centres its words across its whole width, not inside the plate's margins — so the glyph and the words
		# are placed as one group: the glyph, one gap, then the first letter, never overlapping it.
		var first := surface.title_label.get_character_bounds(0)
		var gap := first.position.x - (mark.position.x + side)
		check(first.size.x > 0.0 and gap > 0.0 and absf(gap - GoSurface.TITLE_GLYPH_GAP) <= 1.5,
			"%s surface: one gap between the glyph and the first letter, no overlap (glyph ends %.1f, letter %.1f)"
			% [look, mark.position.x + side, first.position.x])
		if painted:
			# Glyph + gap + words sit centred together on the plate.
			var last := surface.title_label.get_character_bounds(surface.title_label.text.length() - 1)
			var plate := (surface.title_label.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate).base
			var middle := (plate.get_margin(SIDE_LEFT) + surface.title_label.size.x - plate.get_margin(SIDE_RIGHT)) * 0.5
			check(absf((mark.position.x + last.end.x) * 0.5 - middle) <= 3.0,
				"%s surface: glyph and words are centred together" % look)
	if painted:
		check(is_equal_approx(surface.title_overhang(), 17.0), "%s surface: the ribbon rises 17 over the card" % look)
		var head_top := surface.title_label.global_position.y
		var card_top := surface.card.global_position.y
		check(absf(head_top - (card_top - 17.0)) < 1.5,
			"%s surface: the ribbon's top is 17 above the card (head %.1f card %.1f)" % [look, head_top, card_top])
		check(surface.title_label.get_theme_stylebox(&"normal") is GoSurface.OverhangPlate,
			"%s surface: the plate reaches past the sides" % look)
		check(surface.card.global_position.y >= 17.0, "%s surface: the ribbon stays on screen" % look)
	else:
		check(surface.title_overhang() == 0.0, "%s surface: no overhang without a look that asks" % look)
	if painted:
		# Only the plate rises: the close and back buttons stay on the card's padding, and the plate bleeds sideways
		# only where no button sits beside it.
		var inset := surface.card.global_position.y + float(surface.content_inset())
		check(absf(surface.close_button.global_position.y - inset) < 1.5,
			"%s surface: the close button stays on the card's padding (close %.1f, padding %.1f)"
			% [look, surface.close_button.global_position.y, inset])
		var ribbon := surface.title_label.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
		check(ribbon.bleed_right == 0.0 and ribbon.bleed_left == ribbon.bleed and ribbon.bleed > 0.0,
			"%s surface: the plate bleeds only on the side without a button" % look)
		surface.set_back(func() -> void: pass)
		await frames(2)
		inset = surface.card.global_position.y + float(surface.content_inset())
		check(absf(surface.back_button.global_position.y - inset) < 1.5,
			"%s surface: the back button stays on the card's padding (back %.1f, padding %.1f)"
			% [look, surface.back_button.global_position.y, inset])
		check(ribbon.bleed_left == 0.0, "%s surface: no bleed under the back button" % look)
		check(surface.title_label.global_position.y < surface.card.global_position.y - 15.0,
			"%s surface: with buttons the plate still rises over the card" % look)
		surface.set_back(Callable())
		await frames(2)
		check(ribbon.bleed_left == ribbon.bleed, "%s surface: the bleed comes back without the back button" % look)
	if mark != null:
		# A long title shrinks to fit, but the glyph keeps the side its room was reserved for.
		var before := surface.title_glyph_side()
		surface.set_title("A VERY LONG TRANSLATED WINDOW TITLE THAT HAS TO SHRINK")
		await frames(3)
		check(is_equal_approx(surface.title_glyph_side(), before) and is_equal_approx(mark.size.x, before),
			"%s surface: a shrunk title keeps the glyph side" % look)
		if painted:
			var words := surface.title_label.get_character_bounds(0)
			check(absf(words.position.x - (mark.position.x + before) - GoSurface.TITLE_GLYPH_GAP) <= 1.5,
				"%s surface: a shrunk title keeps one gap after the glyph" % look)
		surface.set_title("SETTINGS")
		# Right to left: the glyph goes on the start side (the right), one gap after the words' end.
		surface.layout_direction = Control.LAYOUT_DIRECTION_RTL
		await frames(3)
		var last := surface.title_label.get_character_bounds(surface.title_label.text.length() - 1)
		check(absf(mark.position.x - last.end.x - GoSurface.TITLE_GLYPH_GAP) <= 1.5,
			"%s surface: in RTL the glyph sits one gap after the words, on the right (glyph %.1f, words end %.1f)"
			% [look, mark.position.x, last.end.x])
		surface.layout_direction = Control.LAYOUT_DIRECTION_INHERITED
		await frames(3)
		var first := surface.title_label.get_character_bounds(0)
		check(absf(first.position.x - (mark.position.x + mark.size.x) - GoSurface.TITLE_GLYPH_GAP) <= 1.5,
			"%s surface: back to left to right the glyph is before the words again" % look)
	surface.title_glyph = null
	await frames(1)
	check(surface.title_label.get_children(true).filter(func(n): return n is TextureRect and not n.is_queued_for_deletion()).is_empty(),
		"%s surface: clearing the glyph removes it" % look)
	var scrim := surface.get_node(^"Scrim") as ColorRect
	var veil := scrim.color
	var frost := scrim.material
	surface.opaque = true
	check(scrim.color == GoUi.skin().opaque_backdrop_color() and scrim.material == null,
		"%s surface: opaque puts a solid colour under it" % look)
	surface.opaque = false
	check(scrim.color == veil and (scrim.material != null) == (frost != null),
		"%s surface: opaque off brings the veil and the blur back" % look)
	surface.queue_free()
	await frames(1)
