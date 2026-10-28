extends SceneTree

var passed := 0
var failed: Array[String] = []
var chosen := 0
var chosen_count := 0


func _initialize() -> void:
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	check(GoUi.skin().widget_art(&"world_tour_badge_blue") != null, "arcade map has a blue round badge")
	check(GoUi.skin().widget_art(&"world_tour_badge_red") != null, "arcade selected stage has a red round badge")
	check(GoUi.skin().widget_art(&"world_tour_heading_blue") != null, "arcade detail has a blue stage heading")
	check(GoUi.skin().widget_art(&"world_tour_ribbon_pink") != null, "arcade detail has a pink title ribbon")
	check(GoUi.skin().widget_art(&"world_tour_detail_backdrop") != null, "arcade detail has scenic backdrop art")
	check(GoUi.skin().has_method(&"world_tour_picture"), "the skin exposes tour stage pictures")
	var first: Texture2D = GoUi.skin().world_tour_picture(1)
	var last: Texture2D = GoUi.skin().world_tour_picture(9)
	check(first is AtlasTexture and last is AtlasTexture, "arcade stage pictures are atlas regions")
	check(first is AtlasTexture and last is AtlasTexture and (first as AtlasTexture).atlas == (last as AtlasTexture).atlas, "stage pictures share one texture")
	check(GoUi.skin().world_tour_picture(0) == null and GoUi.skin().world_tour_picture(10) == null, "out-of-range stages have no art")
	check(GoUi.skin().world_tour_picture(1) == first, "stage picture resources are cached")
	check(ResourceLoader.exists("res://addons/gohud/widgets/go_world_tour_picture.gd"), "world tour pictures can mask adjacent atlas regions")
	var custom_script := load("res://addons/gohud/widgets/go_world_tour_picture.gd")
	var custom: Control = custom_script.new()
	var custom_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	custom_image.fill(Color.WHITE)
	if "texture_override" in custom:
		custom.texture_override = ImageTexture.create_from_image(custom_image)
		custom.size = Vector2(20, 20)
		check(custom._has_point(Vector2(10, 10)), "ordinary texture overrides are usable and hit-testable")
		var own_atlas := AtlasTexture.new()
		own_atlas.atlas = custom.texture_override
		own_atlas.region = Rect2(0, 0, 4, 4)
		custom.texture_override = own_atlas
		check(not custom._picture_data().masked, "a caller-owned atlas is not clipped by arcade island masks")
		check(custom._has_point(Vector2(10, 10)), "a caller-owned atlas remains hit-testable")
	else:
		check(false, "ordinary texture overrides are supported")
	custom.free()
	var glyph := GoGlyphButton.make("Play", GoIconSet.PLAY)
	check("glyph_share" in glyph, "glyph buttons support a configurable glyph size")
	glyph.size = Vector2(250, 100)
	var original_allowance := glyph.glyph_allowance()
	glyph.glyph_share = 0.4
	check(glyph.glyph_allowance() < original_allowance, "a smaller glyph reserves less room beside the label")
	glyph.free()
	var heading_script := load("res://addons/gohud/widgets/go_world_tour_heading.gd")
	var heading: Control = heading_script.new()
	heading.theme = GoUi.theme()
	root.add_child(heading)
	heading.size = Vector2(250, 100)
	heading.configure("STAGE 9", "Bagarre au bord de la route")
	await process_frame
	var text_width: float = GoStyle.row_width(heading.title_label.get_theme_font(&"font"), PackedStringArray([heading.title_label.text]), heading.title_label.get_theme_font_size(&"font_size"))
	check(text_width <= heading.title_label.size.x + 0.5, "a long translated heading fits its ribbon")
	check(heading.title_label.get_theme_font_size(&"font_size") >= GoStyle.fit_floor(heading.title_base_size), "the heading honors the configured fit floor")
	heading.configure("STAGE 9", "Sakura Smash")
	check(not heading.title_label.text.contains("\n"), "a short stage title stays on one line")
	heading.queue_free()
	var script := load("res://addons/gohud/widgets/go_world_tour.gd")
	if script == null:
		printerr("FAIL world tour widget is missing")
		quit(1)
		return
	var tour: Control = script.new()
	root.add_child(tour)
	tour.size = Vector2(960, 680)
	await process_frame
	check(tour.nodes.size() == 9, "nine stage nodes")
	check(tour.nodes[0] is Button, "a stage is an accessible button")
	tour.stage_selected.connect(func(n: int) -> void: chosen = n; chosen_count += 1)
	tour.configure_stage(2, "MEXICO", false, true)
	check(tour.nodes[1].title == "MEXICO" and tour.nodes[1].selected, "title and selection update")
	var picture_script := load("res://addons/gohud/widgets/go_world_tour_picture.gd")
	var picture: Control = picture_script.new()
	picture.stage = 2
	tour.nodes[1].thumbnail_slot.add_child(picture)
	check(picture.mouse_filter == Control.MOUSE_FILTER_STOP, "island artwork receives pointer events")
	await process_frame
	var outside := Vector2.INF
	for y in range(0, int(picture.size.y), 4):
		for x in range(0, int(picture.size.x), 4):
			var local_point := Vector2(x, y)
			var global_point: Vector2 = picture.get_global_transform() * local_point
			if picture._has_point(local_point) and not tour.nodes[1].get_global_rect().has_point(global_point) and tour.get_global_rect().has_point(global_point):
				outside = global_point
				break
		if outside != Vector2.INF: break
	check(outside != Vector2.INF, "fixture has visible artwork beyond the button bounds")
	if outside != Vector2.INF:
		var move := InputEventMouseMotion.new()
		move.position = outside
		move.global_position = outside
		root.push_input(move, true)
		var down := InputEventMouseButton.new()
		down.position = outside
		down.global_position = outside
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down, true)
		var up := InputEventMouseButton.new()
		up.position = outside
		up.global_position = outside
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		root.push_input(up, true)
		await process_frame
		check(chosen == 2, "a real pointer click on the image outside the button selects its stage")
		chosen = 0
		var before_touch := chosen_count
		var touch_down := InputEventScreenTouch.new()
		touch_down.index = 0
		touch_down.position = outside
		touch_down.pressed = true
		root.push_input(touch_down, true)
		var touch_up := InputEventScreenTouch.new()
		touch_up.index = 0
		touch_up.position = outside
		touch_up.pressed = false
		root.push_input(touch_up, true)
		var emulated_down := InputEventMouseButton.new()
		emulated_down.device = InputEvent.DEVICE_ID_EMULATION
		emulated_down.button_index = MOUSE_BUTTON_LEFT
		emulated_down.position = outside
		emulated_down.global_position = outside
		emulated_down.pressed = true
		root.push_input(emulated_down, true)
		var emulated_up := InputEventMouseButton.new()
		emulated_up.device = InputEvent.DEVICE_ID_EMULATION
		emulated_up.button_index = MOUSE_BUTTON_LEFT
		emulated_up.position = outside
		emulated_up.global_position = outside
		emulated_up.pressed = false
		root.push_input(emulated_up, true)
		await process_frame
		check(chosen == 2, "a real touch on the image outside the button selects its stage")
		check(chosen_count == before_touch + 1, "touch and its emulated mouse click activate only once")
		chosen = 0
	check(picture._glow.visible, "the selected island shows a glow")
	tour.configure_stage(2, "MEXICO", false, false)
	check(not picture._glow.visible, "deselecting removes the island glow")
	tour.nodes[1].grab_focus()
	check(tour.nodes[1]._ring.visible, "keyboard focus is visibly marked")
	tour.nodes[1].release_focus()
	tour.nodes[1].pressed.emit()
	check(chosen == 2, "an open stage emits its number")
	tour.configure_stage(3, "EGYPT", true, false)
	check(tour.nodes[2].disabled, "a locked stage is disabled")
	tour.nodes[2].pressed.emit()
	check(chosen == 2, "a locked stage never emits a selection")
	for node in tour.nodes:
		check(node.thumbnail_slot != null, "each stage exposes an image slot")
		check(node.size.x > 0.0 and node.size.y > 0.0, "each stage is laid out when first shown")
		check(Rect2(Vector2.ZERO, tour.size).encloses(node.get_rect()), "each stage fits its map")
	tour.queue_free()
	await process_frame
	print("gohud world tour tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
