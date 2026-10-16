## 🧪 **Checks for the game's dialog in gohud** — a `GoSurface` under arcade_light measures what Magnet Mayhem's
## `PaintedDialog` + `RibbonHeader` measure (a 400 dp painted card, the ribbon 57 dp high rising 17 over it, the 8 dp
## rows, the magnet in the corner, the red GAME OVER ribbon), a `GoFitBox` and a `SCALE` fit place a card as the game's
## `FitBox` does, an anchored `SCALE` card as the main menu's top-bar cards — and a plain look keeps the window it always
## had.
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
		await _header(look)
		await _sub_viewport(look)
		await _narrow(look)
		await _clip(look)
		await _red_ribbon(look)
		await _overhang(look)
		await _fit_box(look)
		await _fit_surface(look)
		await _popover_card(look)
		await _os_back(look)
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


# ── Android Back ───────────────────────────────────────────────────────

## The OS back gesture closes the top window, unless the game routes Back itself (`close_on_os_back` off) — then the
## gesture is the game's alone and Escape still closes the window.
func _os_back(look: StringName) -> void:
	var surface := _dialog()
	await frames(2)
	var closes := [0]
	surface.close_requested.connect(func() -> void: closes[0] += 1)
	surface.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(1)
	check(closes[0] == 1, "%s: Android Back closes the top window" % look)
	GoUi.config.close_on_os_back = false
	surface.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(1)
	check(closes[0] == 1, "%s: close_on_os_back off leaves Android Back to the game" % look)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	surface._input(esc)
	check(closes[0] == 2, "%s: Escape still closes it with close_on_os_back off" % look)
	GoUi.config.close_on_os_back = true
	var runtime := GoUi.runtime()
	if runtime != null:
		check(runtime.safe_area_changed.get_connections().any(
				func(c: Dictionary) -> bool: return (c.callable as Callable).get_object() == surface),
				"%s: a window follows the safe area through a turn" % look)
	surface.queue_free()
	await frames(1)


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
		check(surface.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"%s window: mipmapped like the game's dialog, so the 3x sprites stay smooth at 1 unit per pixel" % look)
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
		check(surface.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "%s window: the parent's texture filter" % look)
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


# ── GoRibbonHeader: a screen's title ribbon (the game's RibbonHeader) ─

## A card like the pause screen's: the header first in its column, a button under it.
func _screen_card(header: GoRibbonHeader) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = GoUi.skin().window_card_variation()
	card.position = Vector2(400, 200)
	card.custom_minimum_size = Vector2(440, 0)
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(header)
	var button := Button.new()
	button.text = "RESUME"
	column.add_child(button)
	root.add_child(card)
	return card


func _header(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var header := GoRibbonHeader.make("PAUSED", GoIconSet.PAUSE)
	var card := _screen_card(header)
	await frames(3)
	var column := header.get_parent() as Control
	var ribbon := header.ribbon
	var face := card.get_theme_stylebox(&"panel")
	var card_top := face.get_margin(SIDE_TOP)
	check(header.title_label.text == "PAUSED", "%s header: the title" % look)
	if not painted:
		check(is_equal_approx(ribbon.global_position.y, header.global_position.y)
				and is_equal_approx(ribbon.size.x, header.size.x) and is_equal_approx(header.size.y, ribbon.size.y),
			"%s header: a plain look's title sits in the column (ribbon %s header %s)"
			% [look, ribbon.get_global_rect(), header.get_global_rect()])
		check(header.corner_rect == null or not header.corner_rect.visible, "%s header: no corner art" % look)
		card.queue_free()
		await frames(1)
		return
	# The game's RibbonHeader: 57 high, rising 17 over the card, 14 past the column on each side, holding only the
	# part of it inside the card in the column.
	# A title taller than the ribbon's room grows it down (a PanelContainer never draws under its minimum), as the game's.
	check(absf(ribbon.global_position.y - (card.global_position.y - 17.0)) < 1.0
			and is_equal_approx(ribbon.size.y, maxf(57.0, ribbon.get_combined_minimum_size().y)),
		"%s header: the ribbon is 57 high and rises 17 over the card (ribbon %s card %s)"
		% [look, ribbon.get_global_rect(), card.get_global_rect()])
	check(absf(ribbon.global_position.x - (column.global_position.x - 14.0)) < 1.0
			and absf(ribbon.size.x - (column.size.x + 28.0)) < 1.0, "%s header: 14 past the column each side" % look)
	check(absf(header.size.y - (57.0 - 17.0 - card_top)) < 1.0,
		"%s header: it holds 57 - 17 - the card's top in the column (got %.1f)" % [look, header.size.y])
	var label := header.title_label
	check(label.get_theme_font_size(&"font_size") == 34, "%s header: the title is 34 dp" % look)
	check(label.get_theme_color(&"font_color").is_equal_approx(skin.title_plate_ink()), "%s header: in the plate's ink" % look)
	check(header.glyph_rect != null and header.glyph_rect.visible and is_equal_approx(header.glyph_rect.size.x, 26.0)
			and header.glyph_rect.size.y >= 26.0, "%s header: the 26 dp glyph" % look)
	check(absf(header.glyph_rect.get_global_rect().end.x + 10.0 - label.global_position.x) < 1.0,
		"%s header: 10 between the glyph and the words" % look)
	check(absf(label.size.x - label.get_combined_minimum_size().x) < 1.0, "%s header: the words keep their own width" % look)
	var middle := (header.glyph_rect.global_position.x + label.get_global_rect().end.x) * 0.5
	check(absf(middle - ribbon.get_global_rect().get_center().x) < 1.5, "%s header: glyph and words centred on the ribbon" % look)
	# The magnet: 58 x 56, 30 past the ribbon's end and 24 above it, on the left by default.
	var magnet := header.corner_rect
	check(magnet != null and magnet.visible and magnet.texture != null and is_equal_approx(magnet.size.x, 58.0)
			and is_equal_approx(magnet.size.y, 56.0), "%s header: the magnet in the corner" % look)
	check(absf(magnet.global_position.x - (ribbon.global_position.x - 30.0)) < 1.0
			and absf(magnet.global_position.y - (ribbon.global_position.y - 24.0)) < 1.0 and not magnet.flip_h,
		"%s header: 30 out and 24 up on the left (magnet %s ribbon %s)" % [look, magnet.get_global_rect(), ribbon.get_global_rect()])
	header.corner_on_left = false
	await frames(2)
	check(absf(magnet.get_global_rect().end.x - (ribbon.get_global_rect().end.x + 30.0)) < 1.0 and magnet.flip_h,
		"%s header: mirrored on the right" % look)
	# The red ribbon (the game's RibbonRed) and no glyph.
	header.ribbon_variation = &"GoRibbonRed"
	header.glyph_icon = &""
	await frames(2)
	check(ribbon.theme_type_variation == &"GoRibbonRed" and not ribbon.has_theme_stylebox_override(&"panel"),
		"%s header: the red ribbon" % look)
	check(not header.glyph_rect.visible, "%s header: no glyph" % look)
	check(absf(label.get_global_rect().get_center().x - ribbon.get_global_rect().get_center().x) < 1.5,
		"%s header: the words alone centred" % look)
	# A long title shrinks to the ribbon's room, no lower than 24.
	header.glyph_icon = GoIconSet.PAUSE
	header.title = "A VERY LONG TRANSLATED PAUSE TITLE"
	await frames(3)
	var size := label.get_theme_font_size(&"font_size")
	var room := ribbon.size.x - ribbon.get_theme_stylebox(&"panel").get_minimum_size().x - 36.0
	var font := label.get_theme_font(&"font")
	check(size < 34 and size >= 24 and (size == 24 or font.get_string_size(header.title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room),
		"%s header: a long title shrinks to the ribbon (got %d, room %.1f)" % [look, size, room])
	header.corner = false
	await frames(1)
	check(not magnet.visible, "%s header: corner = false hides the magnet" % look)
	card.queue_free()
	await frames(1)


# ── In a SubViewport: the window lays out in the viewport it is in ─────

## A window inside a SubViewport (a preview, a render-to-texture, the parity harness) fits and centres in that
## viewport — not in the main window, which is bigger and would push the card off the viewport's middle.
func _sub_viewport(look: StringName) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(900, 500)
	root.add_child(view)
	var surface := GoSurface.new()
	surface.set_title("ROOM")
	var block := Control.new()
	block.custom_minimum_size = Vector2(10, 100)
	surface.body.add_child(block)
	view.add_child(surface)
	await frames(3)
	check(GoSafeArea.usable_rect(view) == Rect2(0, 0, 900, 500),
		"%s viewport: the usable rect is the SubViewport's (got %s)" % [look, GoSafeArea.usable_rect(view)])
	var card := surface.card.get_rect()
	check(absf(card.get_center().x - 450.0) < 1.0 and card.end.x <= 900.0 and card.end.y <= 500.0,
		"%s viewport: the card is centred in the 900 x 500 viewport (card %s)" % [look, card])
	view.queue_free()
	await frames(1)


## A phone in portrait (407 x 880 units, the game's phone): the painted window keeps the game's 400 width with no
## screen margin, centred like a CenterContainer; other looks keep their margin off the edge.
func _narrow(look: StringName) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(407, 880)
	root.add_child(view)
	var surface := GoSurface.new()
	surface.set_title("ROOM")
	var block := Control.new()
	block.custom_minimum_size = Vector2(10, 100)
	surface.body.add_child(block)
	view.add_child(surface)
	await frames(3)
	var card := surface.card.get_rect()
	if look == GoThemePresets.ARCADE_LIGHT:
		check(card.size.x == 400.0 and card.position.x == 3.0,
			"%s narrow: the game's 400-wide card, no screen margin, at x 3 (card %s)" % [look, card])
		view.size = Vector2i(360, 700)
		await frames(3)
		card = surface.card.get_rect()
		check(card.size.x == 360.0 and card.position.x == 0.0,
			"%s narrow: a screen under 400 wide narrows it to the screen (card %s)" % [look, card])
	else:
		var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN))
		check(card.position.x >= edge - 0.5 and card.end.x <= 407.0 - edge + 0.5,
			"%s narrow: the card keeps the screen margin (card %s)" % [look, card])
	view.queue_free()
	await frames(1)


## A body that fits draws unclipped, so a part's antialiased rim on a half pixel (the inset's top at 1.5x) is not cut
## off at the scroll's edge, as the game's plain column never cuts it; a body that overflows clips and scrolls.
func _clip(look: StringName) -> void:
	var surface := _dialog()
	await frames(3)
	check(surface.scroll != null and not surface.scroll.clip_contents,
		"%s clip: a body that fits is not clipped" % look)
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(10, 3000)
	surface.body.add_child(tall)
	await frames(4)
	check(surface.scroll.clip_contents, "%s clip: a body that overflows is clipped" % look)
	tall.queue_free()
	await frames(4)
	check(not surface.scroll.clip_contents, "%s clip: …and unclipped again once it fits" % look)
	surface.queue_free()
	await frames(1)


# ── G1: the red ribbon (the game's `set_ribbon(&"RibbonRed", skull)`) ─

func _red_ribbon(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var surface := _dialog()
	surface.title_variation = &"GoRibbonRed"
	surface.title_glyph = GoUi.icons().texture(GoIconSet.SKULL)
	await frames(3)
	var title := surface.title_label
	var plate := title.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
	if not painted:
		# A look whose theme has no such variation keeps its own head.
		check(not title.has_meta(&"go_plate_align") and plate == null,
			"%s red ribbon: a theme without GoRibbonRed keeps the look's head" % look)
		surface.queue_free()
		await frames(1)
		return
	# The game's RibbonRed: `sprite_box(RIBBON_RED, Vector4(100, 80, 100, 80), RIBBON_PPU 3.4, 22, 6, 12)` — the gold
	# ribbon's slices, scale and padding on the red art, so it draws the game's pixels at the gold one's place.
	var base := plate.base as GoStyleBoxSprite if plate != null else null
	check(base != null and base.texture != null
			and base.texture.resource_path == "res://addons/gohud/assets/arcade_light/painted/ribbon_red.png",
		"%s red ribbon: the plate is the red ribbon art (%s)" % [look, base.texture.resource_path if base != null else "none"])
	if base != null:
		check(base.edge == Vector4(100, 80, 100, 80) and is_equal_approx(base.pixels_per_unit, 3.4)
				and base.get_margin(SIDE_LEFT) == 22.0 and base.get_margin(SIDE_TOP) == 6.0
				and base.get_margin(SIDE_RIGHT) == 22.0 and base.get_margin(SIDE_BOTTOM) == 12.0
				and is_equal_approx(base.tint.a, 1.0),
			"%s red ribbon: the game's slices 100/80, 3.4 px a unit, padding 22 / 6 / 12, opaque" % look)
		var theirs := surface.get_theme_stylebox(&"panel", &"GoRibbonRed")
		check(base != theirs, "%s red ribbon: a copy of the theme's, so a paint never reaches the theme" % look)
	var card := surface.card
	check(absf(title.global_position.y - (card.global_position.y - 17.0)) < 1.0 and is_equal_approx(title.size.y, 57.0)
			and plate != null and is_equal_approx(plate.bleed, 14.0),
		"%s red ribbon: 57 high, 17 over the card, 14 past each side — the gold one's place" % look)
	check(title.get_theme_font_size(&"font_size") == 34 and title.get_theme_color(&"font_color") == Color.WHITE
			and title.get_theme_constant(&"outline_size") == 5,
		"%s red ribbon: the white 34 dp title with its ink outline" % look)
	var glyph := title.get_node_or_null(^"TitleGlyph") as TextureRect
	check(glyph != null and glyph.texture == GoUi.icons().texture(GoIconSet.SKULL) and is_equal_approx(glyph.size.x, 26.0),
		"%s red ribbon: the 26 dp skull on it" % look)
	var art := _corner_art(surface)
	check(art != null and art.visible and art.position == Vector2(-plate.bleed_left, 0.0) + GoUi.skin().window_corner_rect().position,
		"%s red ribbon: the magnet on its corner" % look)
	# title_paint does nothing to a painted sprite: the variation is the way to another ribbon here.
	surface.title_paint = Color.RED
	await frames(1)
	plate = title.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
	check(plate != null and plate.base is GoStyleBoxSprite and (plate.base as GoStyleBoxSprite).tint == Color.WHITE,
		"%s red ribbon: title_paint leaves the painted ribbon as drawn" % look)
	surface.title_paint = Color.TRANSPARENT
	# Back to the look's gold ribbon.
	surface.title_variation = &""
	await frames(2)
	plate = title.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
	base = plate.base as GoStyleBoxSprite if plate != null else null
	check(base != null and base.texture.resource_path.ends_with("ribbon_gold.png"),
		"%s red ribbon: an empty variation gives the gold ribbon back" % look)
	# An unknown variation: the look's plate too.
	surface.title_variation = &"NoSuchRibbon"
	await frames(2)
	plate = title.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
	check(plate != null and (plate.base as GoStyleBoxSprite).texture.resource_path.ends_with("ribbon_gold.png"),
		"%s red ribbon: a variation the theme lacks falls back to the look's" % look)
	surface.queue_free()
	await frames(1)


# ── G2: the card's overhang, GoFitBox and the SCALE fit (the game's FitBox) ─

## The game's numbers (`src/client_config.gd` `Cfg.Ui`, `src/ui/ribbon_header.gd`).
const GAME_FIT_PAD := 8.0
const GAME_FIT_MIN := 0.7
const GAME_FLEX_MIN := 96.0
const GAME_SIDE_BLEED := 14.0
const GAME_MAGNET_OUT := 30.0
const GAME_OVERHANG := 17.0
const GAME_MAGNET_RISE := 24.0
## A landscape phone (the game's iPhone 15: 844 × 390), a small one, a portrait phone, an iPad, the desktop.
const FIT_VIEWS: Array[Vector2i] = [Vector2i(844, 390), Vector2i(667, 375), Vector2i(390, 844), Vector2i(1024, 768),
	Vector2i(1180, 820), Vector2i(1280, 720)]


## `RibbonHeader.card_overhang()`, as the game writes it, for a card of [param face].
func _game_overhang(face: StyleBox) -> Vector4:
	var side := maxf(0.0, GAME_SIDE_BLEED + GAME_MAGNET_OUT - minf(face.get_margin(SIDE_LEFT), face.get_margin(SIDE_RIGHT)))
	return Vector4(side, GAME_OVERHANG + GAME_MAGNET_RISE, side, 0.0)


## `FitBox._place`, as the game writes it: [position, scale] of a card that needs [param need] in a FitBox of
## [param box] (the safe area).
func _game_fit(box: Vector2, need: Vector2, ov: Vector4) -> Array:
	var pad := GAME_FIT_PAD
	var room := box - Vector2(pad, pad) * 2.0
	var around := Vector2(ov.x + ov.z, ov.y + ov.w)
	var drawn := need + around
	var s := minf(1.0, minf(room.x / drawn.x, room.y / drawn.y))
	var pos := ((box - need * s) / 2.0).floor()
	pos.x = clampf(pos.x, pad + ov.x * s, box.x - pad - (need.x + ov.z) * s)
	pos.y = clampf(pos.y, pad + ov.y * s, box.y - pad - (need.y + ov.w) * s)
	return [pos, s]


## `FitBox._fit_flex`, as the game writes it: the list's height.
func _game_flex(box: Vector2, ov: Vector4, full: float, others: float) -> float:
	var room := box.y - GAME_FIT_PAD * 2.0
	var most := room / GAME_FIT_MIN - (ov.y + ov.w)
	return clampf(most - others, minf(full, GAME_FLEX_MIN), full)


func _overhang(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var skin := GoUi.skin()
	var card := PanelContainer.new()
	card.theme = GoUi.theme()
	card.theme_type_variation = skin.window_card_variation()
	root.add_child(card)
	await frames(1)
	var got := GoRibbonHeader.card_overhang(card)
	if painted:
		var want := _game_overhang(card.get_theme_stylebox(&"panel"))
		check(want == Vector4(20, 41, 20, 0) and got == want,
			"%s overhang: the game's card_overhang, 20 each side and 41 above (got %s)" % [look, got])
		check(GoRibbonHeader.card_overhang() == want, "%s overhang: no card: the look's window card" % look)
		check(GoRibbonHeader.card_overhang(card, false) == Vector4(0, 17, 0, 0),
			"%s overhang: without the magnet only the ribbon's rise" % look)
		check(skin.window_fit_pad() == GAME_FIT_PAD and skin.window_flex_min_height() == GAME_FLEX_MIN
				and is_equal_approx(GoUi.config.fit_min_scale, GAME_FIT_MIN),
			"%s overhang: the game's pad 8, list floor 96, fit floor 0.7" % look)
	else:
		check(got == Vector4.ZERO, "%s overhang: a look with nothing over the edge has none (got %s)" % [look, got])
		check(skin.window_fit_pad() < 0.0 and GoFitBox.look_pad() == float(GoUi.metric(GoTheme.SCREEN_MARGIN)),
			"%s overhang: the fit pad is the theme's screen margin" % look)
	card.queue_free()
	await frames(1)


## A card like the pause screen's (340 wide: the ribbon, five 46 dp buttons) or, with [param list] rows, the settings
## screen's (a flex list between the ribbon and a button).
func _fit_card(fit: GoFitBox, list := 0) -> Dictionary:
	var card := PanelContainer.new()
	card.theme_type_variation = GoUi.skin().window_card_variation()
	card.custom_minimum_size = Vector2(340, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	card.add_child(column)
	column.add_child(GoRibbonHeader.make("PAUSED", GoIconSet.PAUSE))
	var flex: ScrollContainer = null
	if list > 0:
		flex = GoFitBox.new_flex()
		var rows := Control.new()
		rows.custom_minimum_size = Vector2(300, list)
		flex.add_child(rows)
		column.add_child(flex)
	for i in (1 if list > 0 else 5):
		var button := Control.new()
		button.custom_minimum_size = Vector2(0, 46)
		column.add_child(button)
	fit.add_child(card)
	if flex != null: fit.flex = flex
	return {"card": card, "flex": flex}


func _fit_box(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	for view_size: Vector2i in FIT_VIEWS:
		for list: int in [0, 260, 900]:
			var view := SubViewport.new()
			view.size = view_size
			root.add_child(view)
			var fit := GoFitBox.new()
			view.add_child(fit)
			fit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var parts := _fit_card(fit, list)
			var card: PanelContainer = parts.card
			var flex: ScrollContainer = parts.flex
			await frames(3)
			var box := Vector2(view_size)
			var tag := "%s fit box %dx%d list %d" % [look, view_size.x, view_size.y, list]
			var ov := fit.overhang_of(card)
			if not painted:
				var pad := GoFitBox.look_pad()
				check(ov == Vector4.ZERO and card.scale.x <= 1.0 and card.position.x >= pad - 0.01
						and card.position.y >= pad - 0.01 and card.get_global_rect().end.y <= box.y - pad + 0.01,
					"%s: inside the room with no overhang (card %s scale %.3f)" % [tag, card.get_rect(), card.scale.x])
				view.queue_free()
				await frames(1)
				continue
			var face := card.get_theme_stylebox(&"panel")
			check(ov == _game_overhang(face), "%s: the ribbon and magnet's overhang (got %s)" % [tag, ov])
			var need := card.get_combined_minimum_size()
			if flex != null:
				var full := (flex.get_child(0) as Control).get_combined_minimum_size().y
				# The rest of the card, as the game's engine sums it: the face's padding, the ribbon's 20 in the column,
				# the button and the two gaps (a BoxContainer sums whole units, so it is taken from the parts).
				var others := face.get_margin(SIDE_TOP) + face.get_margin(SIDE_BOTTOM) \
						+ (card.get_child(0).get_child(0) as Control).get_combined_minimum_size().y + 46.0 + 16.0
				var want_h := _game_flex(box, ov, full, others)
				# Whole dp (see `GoFitBox._fit_flex`): within one of the game's.
				check(flex.custom_minimum_size.y == floorf(want_h),
					"%s: the list gets the game's %.2f, floored (got %.2f)" % [tag, want_h, flex.custom_minimum_size.y])
			var want := _game_fit(box, need, ov)
			check(absf(card.scale.x - want[1]) < 0.0005 and card.scale.x == card.scale.y and is_equal_approx(fit.fit_scale, card.scale.x),
				"%s: the game's scale %.4f (got %.4f)" % [tag, want[1], card.scale.x])
			check(card.position.distance_to(want[0]) < 0.01 and card.size.distance_to(need) < 0.01,
				"%s: the game's place %s (got %s, size %s)" % [tag, want[0], card.position, card.size])
			# The card, the ribbon and the magnet are all inside the safe area less the pad.
			var s := card.scale.x
			check(card.position.x - ov.x * s >= GAME_FIT_PAD - 0.01 and card.position.y - ov.y * s >= GAME_FIT_PAD - 0.01
					and card.position.x + (need.x + ov.z) * s <= box.x - GAME_FIT_PAD + 0.01
					and card.position.y + (need.y + ov.w) * s <= box.y - GAME_FIT_PAD + 0.01,
				"%s: all it draws is inside the room" % tag)
			if list == 900:
				check(s >= GAME_FIT_MIN - 0.0005 or flex.custom_minimum_size.y <= GAME_FLEX_MIN + 0.01,
					"%s: a long list scrolls before the card shrinks below 0.7 (scale %.3f)" % [tag, s])
			view.queue_free()
			await frames(1)
	# The content growing (another settings tab) asks for a new fit through the flex.
	var view := SubViewport.new()
	view.size = Vector2i(844, 390)
	root.add_child(view)
	var fit := GoFitBox.new()
	view.add_child(fit)
	fit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := _fit_card(fit, 60)
	await frames(3)
	var flex: ScrollContainer = parts.flex
	check(absf(flex.custom_minimum_size.y - 60.0) < 0.01, "%s fit box: a short list keeps its height" % look)
	(flex.get_child(0) as Control).custom_minimum_size.y = 120.0
	await frames(3)
	check(absf(flex.custom_minimum_size.y - 120.0) < 0.01,
		"%s fit box: the list's content growing refits it (got %.1f)" % [look, flex.custom_minimum_size.y])
	# An explicit overhang turns the look's off; a card with no header has none.
	fit.overhang = Vector4(5, 6, 7, 8)
	check(not fit.auto_overhang and fit.overhang_of(parts.card) == Vector4(5, 6, 7, 8), "%s fit box: an explicit overhang" % look)
	fit.auto_overhang = true
	var bare := PanelContainer.new()
	check(fit.overhang_of(bare) == Vector4.ZERO, "%s fit box: a card without a ribbon header has no overhang" % look)
	bare.free()
	# new_flex: up and down only, no bar, a quarter of the touch target as the deadzone (the game's 11 at 44).
	var made := GoFitBox.new_flex()
	check(made.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and made.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and made.scroll_deadzone == int(GoUi.metric(GoTheme.TOUCH) * 0.25)
			and made.get_v_scroll_bar().mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"%s fit box: new_flex is the game's list" % look)
	if painted: check(made.scroll_deadzone == 11, "%s fit box: the game's 11 dp deadzone" % look)
	made.free()
	check(fit.get_combined_minimum_size() == Vector2.ZERO, "%s fit box: it never pushes the screen" % look)
	view.queue_free()
	await frames(1)


## A centred window under `fit_mode` `SCALE` is the game's `PaintedDialog` in its `FitBox`: 400 wide, its content's
## height (the ribbon holds 20 in the column: 20 + 20 + 8 + content + 22), shrunk with the ribbon and magnet.
func _fit_surface(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	for view_size: Vector2i in FIT_VIEWS:
		for tall: float in [100.0, 300.0, 1000.0]:
			var view := SubViewport.new()
			view.size = view_size
			root.add_child(view)
			var surface := GoSurface.new()
			surface.fit_mode = GoSurface.FitMode.SCALE
			surface.set_title("ROOM")
			var block := Control.new()
			block.custom_minimum_size = Vector2(10, tall)
			surface.body.add_child(block)
			view.add_child(surface)
			await frames(4)
			var box := Vector2(view_size)
			var card := surface.card
			var tag := "%s scale fit %dx%d content %d" % [look, view_size.x, view_size.y, tall]
			if not painted:
				var pad := GoFitBox.look_pad()
				var s0 := card.scale.x
				check(s0 <= 1.0 and card.position.x >= pad - 0.01 and card.position.y >= pad - 0.01
						and card.position.x + card.size.x * s0 <= box.x - pad + 0.01
						and card.position.y + card.size.y * s0 <= box.y - pad + 0.01,
					"%s: inside the room (card %s scale %.3f)" % [tag, card.get_rect(), s0])
				view.queue_free()
				await frames(1)
				continue
			var ov := _game_overhang(card.get_theme_stylebox(&"panel"))
			check(surface.fit_overhang() == ov, "%s: the overhang is the ribbon's and the magnet's" % tag)
			var height := tall + 70.0
			var flex_h := _game_flex(box, ov, tall, 70.0)
			if flex_h < tall: height = 70.0 + flex_h
			var need := Vector2(400.0, height)
			var want := _game_fit(box, need, ov)
			check(absf(card.size.y - need.y) < 0.51 and is_equal_approx(card.size.x, 400.0),
				"%s: the card is %s (got %s)" % [tag, need, card.size])
			check(absf(card.scale.x - want[1]) < 0.002 and is_equal_approx(surface.fit_scale, card.scale.x),
				"%s: the game's scale %.4f (got %.4f)" % [tag, want[1], card.scale.x])
			check(card.position.distance_to(want[0]) < 1.01,
				"%s: the game's place %s (got %s)" % [tag, want[0], card.position])
			if flex_h < tall:
				check(surface.scroll.size.y < tall and card.scale.x >= GAME_FIT_MIN - 0.002,
					"%s: the body scrolls before the card goes below 0.7 (scale %.3f)" % [tag, card.scale.x])
			view.queue_free()
			await frames(1)
	# A list of its own (`fit_flex`) scrolls while the rest of the body stays — the game's result card and its standings.
	var view := SubViewport.new()
	view.size = Vector2i(844, 390)
	root.add_child(view)
	var surface := GoSurface.new()
	surface.fit_mode = GoSurface.FitMode.SCALE
	surface.set_title("RESULT")
	var stats := Control.new()
	stats.custom_minimum_size = Vector2(10, 60)
	surface.body.add_child(stats)
	var standings := GoFitBox.new_flex()
	var rows := Control.new()
	rows.custom_minimum_size = Vector2(300, 800)
	standings.add_child(rows)
	surface.body.add_child(standings)
	surface.add_gloss(GoTheme.VAR_PRIMARY_BUTTON, GoIconSet.PLAY, "MENU")
	surface.fit_flex = standings
	view.add_child(surface)
	await frames(4)
	var box := Vector2(844, 390)
	if painted:
		var ov := _game_overhang(surface.card.get_theme_stylebox(&"panel"))
		# Everything but the list: 70 around the body, the stats, the button and the two gaps.
		var others := 70.0 + 60.0 + 46.0 + 16.0
		var want_h := _game_flex(box, ov, 800.0, others)
		# Whole dp (the card's padding lays its column out on whole units): within one of the game's.
		check(standings.custom_minimum_size.y == floorf(want_h),
			"%s scale fit: fit_flex gets the game's %.2f (got %.2f)" % [look, want_h, standings.custom_minimum_size.y])
		check(not surface.scroll.clip_contents and absf(surface.card.size.y - (others + floorf(want_h))) < 0.01,
			"%s scale fit: the body itself fits, only the list scrolls (card %.1f)" % [look, surface.card.size.y])
		var want := _game_fit(box, Vector2(400.0, others + want_h), ov)
		check(absf(surface.card.scale.x - want[1]) < 0.001, "%s scale fit: the game's scale with a list (%.4f, got %.4f)"
			% [look, want[1], surface.card.scale.x])
		rows.custom_minimum_size.y = 40.0
		await frames(4)
		check(absf(standings.custom_minimum_size.y - 40.0) < 0.01 and is_equal_approx(surface.card.scale.x, 1.0),
			"%s scale fit: a short list refits the card (list %.1f scale %.3f)"
			% [look, standings.custom_minimum_size.y, surface.card.scale.x])
	# A title too long for the ribbon even at its smallest size widens the card instead of folding (the game's ribbon
	# title never wraps), and a short one gives the width back.
	if painted:
		var long := "ENTRENAMIENTO COMPLETADO DEL TODO"
		surface.set_title(long)
		await frames(4)
		var title := surface.title_label
		var font := title.get_theme_font(&"font")
		var at := title.get_theme_font_size(&"font_size")
		var plate := title.get_theme_stylebox(&"normal") as GoSurface.OverhangPlate
		var room := title.size.x - maxf(0.0, plate.base.get_margin(SIDE_LEFT) - plate.bleed_left) \
				- maxf(0.0, plate.base.get_margin(SIDE_RIGHT) - plate.bleed_right) - plate.glyph_room
		var words := font.get_string_size(long, HORIZONTAL_ALIGNMENT_LEFT, -1, at).x
		check(at == GoUi.skin().title_plate_min_size() and words <= room + 0.5 and surface.card.size.x > 400.0,
			"%s scale fit: a long title stays on one line at %d and widens the card (words %.0f room %.0f card %.0f)"
			% [look, at, words, room, surface.card.size.x])
		surface.set_title("RESULT")
		await frames(4)
		check(is_equal_approx(surface.card.size.x, 400.0) and title.custom_minimum_size.x <= title.size.x,
			"%s scale fit: a short title gives the width back (card %.0f)" % [look, surface.card.size.x])
	# Back to SCROLL: the card loses its scale.
	rows.custom_minimum_size.y = 2000.0
	await frames(3)
	surface.fit_mode = GoSurface.FitMode.SCROLL
	await frames(3)
	check(surface.card.scale == Vector2.ONE and is_equal_approx(surface.fit_scale, 1.0) and standings.custom_minimum_size.y == 0.0
			and surface.title_label.custom_minimum_size.x == 0.0,
		"%s scale fit: SCROLL takes the scale (and the title's width) off again" % look)
	view.queue_free()
	await frames(1)
	# The default stays SCROLL: no scale on a window that does not ask.
	var plain := _dialog(1000.0)
	await frames(3)
	check(plain.fit_mode == GoSurface.FitMode.SCROLL and plain.card.scale == Vector2.ONE,
		"%s scale fit: off by default" % look)
	plain.queue_free()
	await frames(1)


# ── G10: the main menu's top-bar cards (an anchored SCALE card) ───────

## `MainMenu._place_card`, as the game writes it: [position, scale].
func _game_card(safe: Rect2, key: Rect2, natural: Vector2) -> Array:
	var s := minf(1.0, minf(safe.size.x / natural.x, safe.size.y / natural.y))
	s = maxf(s, GAME_FIT_MIN)
	var drawn := natural * s
	var x := clampf(key.end.x - drawn.x, safe.position.x, safe.end.x - drawn.x)
	var y := maxf(safe.position.y, minf(key.end.y + 10.0, safe.end.y - drawn.y))
	return [Vector2(x, y), s]


## A top bar's key at the top-right (56 dp, 14 in from the corner) and a card for it.
func _top_card(parent: Node, view: Vector2, content: Vector2) -> Dictionary:
	var key := Button.new()
	key.position = Vector2(view.x - 14.0 - 56.0, 14.0)
	key.size = Vector2(56, 56)
	parent.add_child(key)
	var surface := GoSurface.new()
	surface.placement = GoSurface.Placement.ANCHOR
	surface.anchor_control = key
	surface.show_header = false
	surface.scrim_transparent = true
	surface.dismiss_on_scrim = true
	surface.anchor_width = 0.0
	surface.anchor_min_width = 300.0
	surface.anchor_align = GoSurface.AnchorAlign.END
	surface.anchor_gap = 10.0
	surface.anchor_edge = 0.0
	surface.fit_mode = GoSurface.FitMode.SCALE
	surface.pass_anchor_taps = true
	var block := Control.new()
	block.custom_minimum_size = content
	surface.body.add_child(block)
	var layer := CanvasLayer.new()
	layer.layer = 95
	parent.add_child(layer)
	layer.add_child(surface)
	return {"key": key, "surface": surface, "layer": layer}


func _popover_card(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	for view_size: Vector2i in FIT_VIEWS:
		for content: Vector2 in [Vector2(250, 120), Vector2(250, 500), Vector2(250, 900), Vector2(420, 120)]:
			var view := SubViewport.new()
			view.size = view_size
			root.add_child(view)
			var parts := _top_card(view, Vector2(view_size), content)
			var surface: GoSurface = parts.surface
			var key: Button = parts.key
			await frames(4)
			var card := surface.card
			var face := card.get_theme_stylebox(&"panel")
			var tag := "%s top card %dx%d content %s" % [look, view_size.x, view_size.y, content]
			if painted:
				check(card.theme_type_variation == &"GoCard", "%s: the game's PaintedCard" % tag)
			# The game's card: its content's size in the card's face, no narrower than the volume card's 300.
			var inset := float(surface.content_inset()) * 2.0
			var natural := Vector2(maxf(300.0, content.x + face.get_margin(SIDE_LEFT) + face.get_margin(SIDE_RIGHT) + inset),
					content.y + face.get_margin(SIDE_TOP) + face.get_margin(SIDE_BOTTOM) + inset)
			check(card.size.distance_to(natural) < 0.51, "%s: the card is its content's size %s (got %s)" % [tag, natural, card.size])
			var want := _game_card(Rect2(Vector2.ZERO, Vector2(view_size)), key.get_rect(), card.size)
			check(absf(card.scale.x - want[1]) < 0.0005, "%s: the game's scale %.4f (got %.4f)" % [tag, want[1], card.scale.x])
			check(card.position.distance_to(want[0]) < 0.01, "%s: the game's place %s (got %s)" % [tag, want[0], card.position])
			view.queue_free()
			await frames(1)
	# Taps on the key go through the layer to it; a tap anywhere else closes the card.
	var parts := _top_card(root, root.get_visible_rect().size, Vector2(250, 120))
	var surface: GoSurface = parts.surface
	var key: Button = parts.key
	await frames(4)
	var pressed := [0]
	var closed := [0]
	key.pressed.connect(func() -> void: pressed[0] += 1)
	surface.close_requested.connect(func() -> void: closed[0] += 1)
	var middle := key.get_global_rect().get_center()
	check(not surface._has_point(middle) and not surface._scrim._has_point(middle),
		"%s top card: the layer has a hole where the key is" % look)
	check(surface._has_point(Vector2(20, 400)) and surface._scrim._has_point(Vector2(20, 400)),
		"%s top card: …and only there" % look)
	await _click(middle)
	check(pressed[0] == 1 and closed[0] == 0, "%s top card: a tap on the key reaches the key (pressed %d closed %d)"
		% [look, pressed[0], closed[0]])
	await _click(Vector2(20, 400))
	check(pressed[0] == 1 and closed[0] == 1, "%s top card: a tap outside closes it (pressed %d closed %d)"
		% [look, pressed[0], closed[0]])
	surface.pass_anchor_taps = false
	await _click(middle)
	check(pressed[0] == 1 and closed[0] == 2, "%s top card: without pass_anchor_taps the layer takes the key's tap" % look)
	# tap_through: the rest of a top bar.
	var other := Button.new()
	other.position = Vector2(1000, 14)
	other.size = Vector2(56, 56)
	root.add_child(other)
	var others := [0]
	other.pressed.connect(func() -> void: others[0] += 1)
	surface.tap_through = [other]
	await _click(other.get_global_rect().get_center())
	check(others[0] == 1 and closed[0] == 2, "%s top card: a tap_through control gets its tap" % look)
	other.queue_free()
	parts.layer.queue_free()
	key.queue_free()
	await frames(1)
	# GoPopover takes the same options: the game's top-bar card in one call.
	var anchor := Button.new()
	anchor.position = Vector2(1210, 14)
	anchor.size = Vector2(56, 56)
	root.add_child(anchor)
	var block := Control.new()
	block.custom_minimum_size = Vector2(250, 120)
	var card_surface := GoPopover.open(anchor, block, {"width": 0, "min_width": 300, "align": &"end", "gap": 10,
		"edge": 0, "fit": true, "pass_anchor_taps": true})
	await frames(4)
	check(card_surface.anchor_align == GoSurface.AnchorAlign.END and card_surface.fit_mode == GoSurface.FitMode.SCALE
			and card_surface.anchor_width == 0.0 and card_surface.anchor_gap == 10.0 and card_surface.anchor_edge == 0.0
			and card_surface.pass_anchor_taps and not card_surface.show_header,
		"%s popover: the options reach the surface" % look)
	var drawn := card_surface.card.get_global_rect()
	check(absf(drawn.end.x - anchor.get_global_rect().end.x) < 0.51 and absf(drawn.position.y - 80.0) < 0.51,
		"%s popover: right edge on the key's, 10 under it (card %s)" % [look, drawn])
	GoPopover.close()
	anchor.queue_free()
	await frames(2)
	# The default anchored card is unchanged: 320 wide, 7 under its anchor, unscaled.
	anchor = Button.new()
	anchor.position = Vector2(100, 100)
	anchor.size = Vector2(80, 40)
	root.add_child(anchor)
	block = Control.new()
	block.custom_minimum_size = Vector2(100, 60)
	card_surface = GoPopover.open(anchor, block)
	await frames(4)
	drawn = card_surface.card.get_global_rect()
	check(is_equal_approx(drawn.size.x, 320.0) and absf(drawn.position.y - 147.0) < 0.51
			and absf(drawn.position.x - 100.0) < 0.51 and card_surface.card.scale == Vector2.ONE,
		"%s popover: the default card is as before (card %s)" % [look, drawn])
	GoPopover.close()
	anchor.queue_free()
	await frames(2)


## A tap at [param at] (canvas units), through the engine's input as a real one arrives (gohud_test.gd's way).
func _click(at: Vector2) -> void:
	for held: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = held
		event.position = at
		event.global_position = at
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		Input.parse_input_event(event.xformed_by(root.get_final_transform()))
		Input.flush_buffered_events()
		await frames(1)
