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
