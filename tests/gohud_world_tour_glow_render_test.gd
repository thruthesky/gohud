extends SceneTree
## Render a cropped picture next to unrelated atlas art: the selection glow must never sample its neighbour.
## Run with a real graphics device (not --headless), e.g. Godot -s res://addons/gohud/tests/gohud_world_tour_glow_render_test.gd.

func _initialize() -> void:
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	root.size = Vector2i(400, 400)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.fill_rect(Rect2i(18, 24, 6, 17), Color.WHITE) # the selected island
	source.fill_rect(Rect2i(59, 24, 5, 17), Color.WHITE) # unrelated art outside its atlas rectangle
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(source)
	atlas.region = Rect2(16, 16, 32, 32)
	var picture := GoWorldTourPicture.new()
	picture.texture_override = atlas
	picture.position = Vector2(64, 64)
	picture.size = Vector2(256, 256)
	root.add_child(picture)
	picture.set_selected(true)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var positive := image.get_pixel(224, 192)
	var unwanted := image.get_pixel(304, 192)
	var glow_visible := positive.r > 0.5 and positive.g > 0.4
	var neighbour_clear := unwanted.r < 0.1 and unwanted.g < 0.1
	if not glow_visible: printerr("FAIL selected island has no visible halo: %s" % positive)
	if not neighbour_clear: printerr("FAIL unrelated neighbouring atlas art creates a yellow patch: %s" % unwanted)
	picture.texture_override = null
	picture.stage = 5
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var stage5_image := root.get_texture().get_image()
	var stage5_clear := true
	for y in range(125, 180):
		for x in range(312, 320):
			var color := stage5_image.get_pixel(x, y)
			if color.r > 0.5 and color.g > 0.4 and color.b < 0.4:
				stage5_clear = false
	if not stage5_clear: printerr("FAIL stage 5 selection illuminates an unrelated atlas fragment")
	picture.set_selected(false)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var unselected := root.get_texture().get_image()
	var stage5_background_clear := unselected.get_pixel(315, 265).r < 0.001
	if not stage5_background_clear: printerr("FAIL stage 5 exposes stray pixels from neighbouring art when unselected")
	print("gohud world tour glow render tests: %d/4 passed" % (int(glow_visible) + int(neighbour_clear) + int(stage5_clear) + int(stage5_background_clear)))
	quit(0 if glow_visible and neighbour_clear and stage5_clear and stage5_background_clear else 1)
