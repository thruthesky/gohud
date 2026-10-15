## 🧪 **Checks for the game's dialog in gohud** — a `GoSurface` under arcade_light measures what Magnet Mayhem's
## `PaintedDialog` + `RibbonHeader` measure (a 400 dp painted card, the ribbon 57 dp high rising 17 over it, the 8 dp
## rows, the magnet in the corner), and a plain look keeps the window it always had.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_dialog_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(1280, 720)
	await frames(2)
	GoUi.reset()
	GoUi.config.reduce_motion = true
	for look: StringName in [GoThemePresets.ARCADE_LIGHT, GoThemePresets.DEFAULT_DARK]:
		GoUi.use_preset(look)
		await frames(1)
		await _window(look)
		await _corner(look)
		await _ribbon(look)
		await _backdrop(look)
		await _helpers(look)
	GoUi.reset()
	print("gohud dialog tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


## A window like the game's secret prompt: a title and one block of content.
func _dialog(tall := 100.0) -> GoSurface:
	var surface := GoSurface.new()
	surface.set_title("ROOM")
	var block := Control.new()
	block.custom_minimum_size = Vector2(10, tall)
	surface.body.add_child(block)
	root.add_child(surface)
	return surface


# ── The window: card, padding, rows, width, centring ───────────────────

func _window(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var surface := _dialog()
	await frames(3)
	var card := surface.card
	if painted:
		check(skin.window_card_variation() == &"GoCard" and card.theme_type_variation == &"GoCard",
			"%s window: the card is the painted card (GoCard)" % look)
		check(surface.content_inset() == 0, "%s window: no padding past the card's own (got %d)" % [look, surface.content_inset()])
		check(surface.section_gap() == 8, "%s window: rows 8 apart, the game's column (got %d)" % [look, surface.section_gap()])
		check(surface.body.get_theme_constant(&"separation") == 8, "%s window: the body's rows 8 apart too" % look)
		check(is_equal_approx(card.size.x, 400.0), "%s window: the card is 400 wide (got %.1f)" % [look, card.size.x])
		var face := card.get_theme_stylebox(&"panel")
		var top := face.get_margin(SIDE_TOP)
		var bottom := face.get_margin(SIDE_BOTTOM)
		check(top == 20.0 and bottom == 22.0, "%s window: the card's face pads 20 / 22" % look)
		var head_end := surface.header.global_position.y + surface.header.size.y
		var head_room := head_end - (card.global_position.y + top)
		var body_top := surface.body.global_position.y
		check(absf(body_top - (head_end + 8.0)) < 1.0,
			"%s window: the body starts one row gap under the head (body %.1f head %.1f)" % [look, body_top, head_end])
		check(absf(card.size.y - (top + head_room + 8.0 + 100.0 + bottom)) < 1.0,
			"%s window: the card fits its content exactly (got %.1f, want %.1f)"
			% [look, card.size.y, top + head_room + 108.0 + bottom])
		var view := root.get_visible_rect().size
		check(card.position.x == floorf((view.x - card.size.x) * 0.5) and card.position.y == floorf((view.y - card.size.y) * 0.5),
			"%s window: centred on the screen like a CenterContainer (at %s, size %s)" % [look, card.position, card.size])
	else:
		check(skin.window_card_variation() == GoTheme.VAR_PANEL and card.theme_type_variation == GoTheme.VAR_PANEL,
			"%s window: the card stays the theme's panel" % look)
		check(surface.content_inset() == GoUi.metric(GoTheme.PADDING), "%s window: the theme's padding" % look)
		check(surface.section_gap() == GoUi.metric(GoTheme.GAP), "%s window: the theme's gap" % look)
		check(is_equal_approx(card.size.x, GoUi.config.surface_max_width),
			"%s window: the config's width (got %.1f)" % [look, card.size.x])
	surface.queue_free()
	await frames(1)
	# A window narrower than the look's width: its own max_width wins.
	surface = _dialog()
	surface.max_width = 320.0
	await frames(3)
	check(is_equal_approx(surface.card.size.x, 320.0), "%s window: max_width still caps it (got %.1f)" % [look, surface.card.size.x])
	surface.queue_free()
	await frames(1)


# ── The corner: the magnet, or the close button ───────────────────────

func _corner_art(surface: GoSurface) -> TextureRect:
	return surface.title_label.get_node_or_null(^"CornerArt") as TextureRect


func _corner(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var surface := _dialog()
	var closed := [0]
	surface.close_requested.connect(func() -> void: closed[0] += 1)
	await frames(3)
	var art := _corner_art(surface)
	if painted:
		check(skin.window_corner() == &"art" and skin.window_corner_art() != null,
			"%s corner: the look puts its art in the corner" % look)
		check(not surface.close_button.visible, "%s corner: no close button, like the game's dialog" % look)
		check(art != null and art.visible and art.texture == skin.window_corner_art(),
			"%s corner: the magnet sits in the corner" % look)
		if art != null:
			var plate := surface.title_label.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
			var want := skin.window_corner_rect()
			check(art.size == want.size, "%s corner: the magnet is 58 × 56 (got %s)" % [look, art.size])
			check(plate != null and art.position == Vector2(-plate.bleed_left, 0.0) + want.position,
				"%s corner: the magnet hangs 30 left of and 24 above the ribbon's corner (at %s)" % [look, art.position])
			check(not art.flip_h, "%s corner: on the left the magnet is not mirrored" % look)
			surface.corner_on_left = false
			await frames(2)
			var right_x := surface.title_label.size.x + plate.bleed_right - want.position.x - want.size.x
			check(art.flip_h and absf(art.position.x - right_x) < 0.5,
				"%s corner: on the right it is mirrored past the ribbon's right end (at %.1f, want %.1f)"
				% [look, art.position.x, right_x])
			surface.corner_on_left = true
		# Escape still closes it: the game's dialogs close on Escape with no button to press.
		var escape := InputEventAction.new()
		escape.action = &"ui_cancel"
		escape.pressed = true
		root.push_input(escape)
		await frames(1)
		check(closed[0] == 1, "%s corner: Escape still asks to close (got %d)" % [look, closed[0]])
		surface.corner = GoSurface.HeadCorner.CLOSE
		await frames(2)
		check(surface.close_button.visible and (_corner_art(surface) == null or not _corner_art(surface).visible),
			"%s corner: CLOSE brings the close button back and takes the art off" % look)
		surface.corner = GoSurface.HeadCorner.NONE
		await frames(2)
		check(not surface.close_button.visible and (_corner_art(surface) == null or not _corner_art(surface).visible),
			"%s corner: NONE leaves the corner empty" % look)
	else:
		check(skin.window_corner() == &"close", "%s corner: the close button by default" % look)
		check(surface.close_button.visible and (art == null or not art.visible), "%s corner: the close button shows" % look)
	# Any look: an explicit art corner shows the given art and hides the close button.
	var mark := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	surface.corner_art = mark
	surface.corner = GoSurface.HeadCorner.ART
	await frames(2)
	art = _corner_art(surface)
	check(art != null and art.visible and art.texture == mark and not surface.close_button.visible,
		"%s corner: ART with corner_art shows that art" % look)
	surface.corner = GoSurface.HeadCorner.LOOK
	surface.corner_art = null
	await frames(2)
	check(surface.close_button.visible == not painted, "%s corner: LOOK gives the look's corner back" % look)
	# A host that hid the close button itself keeps it hidden.
	surface.close_button.visible = false
	GoUi.refresh()
	await frames(2)
	check(not surface.close_button.visible, "%s corner: a close button the host hid stays hidden" % look)
	surface.queue_free()
	await frames(1)
	# A sheet from the bottom keeps its close button in every look.
	var sheet := GoSurface.new()
	sheet.placement = GoSurface.Placement.BOTTOM
	sheet.set_title("SHEET")
	root.add_child(sheet)
	await frames(3)
	check(sheet.close_button.visible, "%s corner: a bottom sheet keeps its close button" % look)
	sheet.queue_free()
	await frames(1)


# ── The ribbon: the game's 34 dp title on a 57 dp ribbon ──────────────

func _ribbon(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var surface := _dialog()
	surface.title_glyph = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	await frames(3)
	var title := surface.title_label
	var size := title.get_theme_font_size(&"font_size")
	if not painted:
		check(skin.title_plate_font_size() == 0 and skin.title_plate_height() == 0.0,
			"%s ribbon: the title keeps its role's size and height" % look)
		check(size == GoUi.font_size(GoTheme.ROLE_SUBTITLE), "%s ribbon: the subtitle size (got %d)" % [look, size])
		surface.queue_free()
		await frames(1)
		return
	check(skin.title_plate_font_size() == 34 and skin.title_plate_height() == 57.0 and skin.title_plate_min_size() == 24,
		"%s ribbon: the game's 34 dp title, 57 dp ribbon, shrinking no lower than 24" % look)
	check(size == 34, "%s ribbon: the title is 34 dp (got %d)" % [look, size])
	check(is_equal_approx(surface.title_glyph_side(), 26.0), "%s ribbon: the glyph is 26 dp (got %.1f)" % [look, surface.title_glyph_side()])
	# The game's glyph sits in a 26-wide cell as tall as the title's line, kept to its aspect and centred with the
	# words — so a tall glyph (the lock) is drawn as large as the line lets it, not squeezed into a 26 x 26 square.
	var face := title.get_theme_stylebox(&"normal")
	var row := title.size.y - face.get_margin(SIDE_TOP) - face.get_margin(SIDE_BOTTOM)
	var line := title.get_theme_font(&"font").get_height(size)
	var glyph := title.get_node_or_null(^"TitleGlyph") as TextureRect
	check(glyph != null and is_equal_approx(glyph.size.x, 26.0) and absf(glyph.size.y - minf(line, row)) < 1.0
			and absf(glyph.position.y + glyph.size.y * 0.5 - (face.get_margin(SIDE_TOP) + row * 0.5)) < 1.0,
		"%s ribbon: the glyph's cell is 26 wide, the line's height, centred on the row (line %.1f row %.1f, got %s)"
		% [look, line, row, str(glyph.get_rect()) if glyph != null else "none"])
	check(is_equal_approx(title.size.y, 57.0) and is_equal_approx(surface.header.size.y, 57.0),
		"%s ribbon: the head is 57 high (title %.1f head %.1f)" % [look, title.size.y, surface.header.size.y])
	var card := surface.card
	var top := card.get_theme_stylebox(&"panel").get_margin(SIDE_TOP)
	var bottom := card.get_theme_stylebox(&"panel").get_margin(SIDE_BOTTOM)
	check(absf(title.global_position.y - (card.global_position.y - 17.0)) < 1.0,
		"%s ribbon: it rises 17 over the card" % look)
	check(absf(surface.body.global_position.y - (card.global_position.y + top + 28.0)) < 1.0,
		"%s ribbon: the body starts 48 under the card's top, as the game's inset does (body %.1f card %.1f)"
		% [look, surface.body.global_position.y, card.global_position.y])
	check(absf(card.size.y - (top + 20.0 + 8.0 + 100.0 + bottom)) < 1.0,
		"%s ribbon: the card is the game's height (got %.1f)" % [look, card.size.y])
	# The ribbon grows down to its words when they are taller than 57 — drawn over the gap, never pushing the rows.
	var plate := title.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
	var base := plate.base
	var font := title.get_theme_font(&"font")
	var want_sink := maxf(0.0, base.get_margin(SIDE_TOP) + base.get_margin(SIDE_BOTTOM) + font.get_height(34) - 57.0)
	check(is_equal_approx(plate.sink, want_sink), "%s ribbon: it sinks %.1f below the head (got %.1f)" % [look, want_sink, plate.sink])
	# A long title shrinks to the ribbon's whole room, past the card's sides: the ribbon less its ends and the glyph.
	surface.set_title("JOIN THE PRIVATE ROOM")
	await frames(3)
	size = title.get_theme_font_size(&"font_size")
	var room := title.size.x + plate.bleed_left + plate.bleed_right - base.get_margin(SIDE_LEFT) - base.get_margin(SIDE_RIGHT) \
			- (surface.title_glyph_side() + GoSurface.TITLE_GLYPH_GAP)
	var words := title.text
	check(size < 34 and size >= 24, "%s ribbon: a long title shrinks (got %d)" % [look, size])
	check(font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room
			and font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size + 1).x > room,
		"%s ribbon: to the largest size that fits the ribbon's room (%d in %.1f)" % [look, size, room])
	check(is_equal_approx(surface.title_glyph_side(), 26.0), "%s ribbon: the glyph keeps 26" % look)
	surface.set_title("AN EVEN LONGER TRANSLATED TITLE THAT CAN NEVER FIT ON THE RIBBON")
	await frames(3)
	check(title.get_theme_font_size(&"font_size") == 24, "%s ribbon: no smaller than 24" % look)
	surface.queue_free()
	await frames(1)


# ── The backdrop: blur, the low tier's dim, the opaque sky ─────────────

func _backdrop(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	check(GoUi.config.scrim_blur, "%s backdrop: the blur is on by default" % look)
	var surface := _dialog()
	var drawer := GoDrawer.new()
	root.add_child(drawer)
	await frames(2)
	var scrim: ColorRect = surface._scrim
	var drawer_scrim: ColorRect = drawer._scrim
	var made := GoStyle.scrim()
	if painted:
		check(scrim.material != null and drawer_scrim.material != null and made.material != null,
			"%s backdrop: the game's blur behind a window, a drawer and a made scrim" % look)
	else:
		check(scrim.material == null, "%s backdrop: a plain look keeps its plain veil" % look)
	# A quality tier that cannot afford the blur (the game's `UiTheme.set_blur(false)`) leaves the flat dim — the scrim
	# colour, which under arcade_light is the game's OVERLAY — on every window already open and every one made after.
	GoUi.config.scrim_blur = false
	await frames(1)
	var dim := GoStyle.scrim()
	check(scrim.material == null and drawer_scrim.material == null and dim.material == null,
		"%s backdrop: scrim_blur off dims instead of blurring, open windows too" % look)
	check(scrim.color == GoUi.color(GoTheme.SCRIM), "%s backdrop: the dim is the scrim colour" % look)
	if painted:
		check(GoUi.color(GoTheme.SCRIM).is_equal_approx(Color(20.0 / 255.0, 40.0 / 255.0, 80.0 / 255.0, 0.25)),
			"%s backdrop: the scrim colour is the game's OVERLAY (got %s)" % [look, GoUi.color(GoTheme.SCRIM)])
	GoUi.config.scrim_blur = true
	await frames(1)
	check((scrim.material != null) == painted, "%s backdrop: scrim_blur on brings the blur back" % look)
	# `opaque`: a solid sky where the world behind is not drawn (the game's `set_opaque`), over the blur and the dim.
	surface.opaque = true
	await frames(1)
	check(scrim.material == null and is_equal_approx(scrim.color.a, 1.0), "%s backdrop: opaque is a solid colour" % look)
	if painted:
		check(scrim.color.is_equal_approx(skin.opaque_backdrop_color()), "%s backdrop: the game's sky" % look)
	made.free()
	dim.free()
	drawer.queue_free()
	surface.queue_free()
	await frames(1)


# ── The parts: add_inset, add_line, add_row, add_gloss (PaintedDialog's) ─

func _helpers(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var surface := GoSurface.new()
	surface.set_title("SECRET CODE")
	root.add_child(surface)
	var inset := surface.add_inset()
	var panel := inset.get_parent() as PanelContainer
	check(panel != null and panel.get_parent() == surface.body, "%s parts: an inset goes in the body" % look)
	check(panel.theme_type_variation == skin.window_inset_variation(), "%s parts: the inset wears the look's inset" % look)
	if painted:
		check(skin.window_inset_variation() == &"GoInsetPanel", "%s parts: the game's InsetPanel" % look)
	check(inset.get_theme_constant(&"separation") == 4, "%s parts: the inset's rows are 4 apart" % look)
	var line := surface.add_line("E2E Room has a secret code. Ask its host.", 16, inset)
	check(line.get_parent() == inset and line.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
			and line.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and line.get_theme_font_size(&"font_size") == 16,
		"%s parts: a line is centred, wraps (SMART) and takes its size" % look)
	var stat := surface.add_line("12 / 20", 20, null, false)
	check(stat.get_parent() == surface.body and stat.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"%s parts: a stat line does not wrap and goes in the body" % look)
	var plain := surface.add_line("x")
	check(not plain.has_theme_font_size_override(&"font_size"), "%s parts: size 0 keeps the theme's" % look)
	var row := surface.add_row()
	var want_gap := skin.window_button_gap() if skin.window_button_gap() >= 0 else GoUi.metric(GoTheme.GAP)
	check(row.get_parent() == surface.body and row.get_theme_constant(&"separation") == want_gap,
		"%s parts: a button row is %d apart (got %d)" % [look, want_gap, row.get_theme_constant(&"separation")])
	if painted:
		check(skin.window_button_gap() == 10, "%s parts: the game's buttons are 10 apart" % look)
	var back := surface.add_gloss(GoTheme.VAR_BUTTON, GoIconSet.BACK, "BACK", row)
	var join := surface.add_gloss(GoTheme.VAR_PRIMARY_BUTTON, GoIconSet.PLAY, "JOIN", row)
	check(back is GoGlyphButton and back.get_parent() == row and back.text == "BACK" and back.glyph_icon == GoIconSet.BACK
			and back.theme_type_variation == GoTheme.VAR_BUTTON, "%s parts: a glyph button in the row" % look)
	check(back.size_flags_horizontal & Control.SIZE_EXPAND != 0 and join.size_flags_horizontal & Control.SIZE_EXPAND != 0,
		"%s parts: the row's buttons share it" % look)
	var bottom := surface.add_gloss(GoTheme.VAR_PRIMARY_BUTTON, GoIconSet.PLAY, "NEXT")
	check(bottom.get_parent() == surface.body, "%s parts: a button goes in the body" % look)
	await frames(3)
	if painted:
		check(skin.window_button_height() == 46.0, "%s parts: the game's dialog buttons are 46 high" % look)
		check(is_equal_approx(back.size.y, 46.0) and is_equal_approx(bottom.size.y, 46.0),
			"%s parts: the buttons are 46 high (got %.1f)" % [look, back.size.y])
	else:
		check(skin.window_button_height() == 0.0 and back.custom_minimum_size.y == 0.0,
			"%s parts: a plain look keeps its button's height" % look)
	surface.queue_free()
	await frames(1)
