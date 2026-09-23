## 📸 **Shoots the icon sets the way a game sees them** — one drawing from every group of every set, then the lookup
## order made visible: the same four names under the default preset and under the medieval one, with the
## 1,000-icon library added on top — and the buttons example (`examples/icon_buttons`) in each look.
##
##   bash <godot skill>/scripts/xvfb_run.sh --out <folder> --size 720x1600 -s res://addons/gohud/tests/icon_shots.gd
##
## 🔑 What to look for: every cell holds a drawing (an empty cell is a name nothing drew), strokes are crisp at 32dp
##    (a blurry one lost its DPITexture importer), and on the medieval sheet `sword` and `scroll` are the engraved
##    drawings while `backpack` and `cloud_rain` come from the game set and the library.
## 🛑 `--headless` produces no picture. Container fonts have no Korean — the labels are English.
extends SceneTree

const LOOKS := [GoThemePresets.DEFAULT_DARK, GoThemePresets.MEDIEVAL_DARK, GoThemePresets.DEFAULT_LIGHT]
const ORDER_NAMES: Array[StringName] = [&"sword", &"scroll", &"backpack", &"cloud_rain"]

var _dir := ""


func _initialize() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty(): _dir = "/out"
	GoUi.reset()
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false
	for look in LOOKS:
		GoUi.use_preset(look)
		GoUi.add_icons(GoIconLibrary.icon_set())
		await _shoot(look)
		await _shoot_example(look)
	print("✅ icon shots done — %s" % _dir)
	quit(0)


func _shoot(look: StringName) -> void:
	for child in root.get_children():
		if child is Control: child.queue_free()
	await process_frame
	var back := ColorRect.new()
	back.color = GoUi.color(GoTheme.BACKGROUND)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var pad := GoStyle.padding()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pad)
	var page := GoStyle.column()
	pad.add_child(page)
	var icons := GoUi.icons()
	page.add_child(GoStyle.label("Icons — %s · %d names" % [look, icons.icon_names().size()], GoTheme.ROLE_TITLE))

	page.add_child(GoStyle.section("Lookup order: sword · scroll · backpack · cloud_rain", false))
	var order := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP))
	for icon in ORDER_NAMES:
		order.add_child(_cell(icons, icon, 40))
	page.add_child(order)

	page.add_child(GoStyle.section("One drawing per group (%d groups)" % icons.group_names().size(), false))
	var grid := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	for key in icons.group_names():
		var names := icons.names_in_group(StringName(key))
		if names.is_empty(): continue
		grid.add_child(_cell(icons, StringName(names[0]), 32))
	page.add_child(grid)
	await _save("icons_%s" % look)


## The buttons example (`examples/icon_buttons`) as a person opens it — its first screen, then scrolled to the end.
func _shoot_example(look: StringName) -> void:
	for child in root.get_children():
		if child is Control: child.queue_free()
	await process_frame
	var screen := (load("res://addons/gohud/examples/icon_buttons/icon_buttons.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await _save("icon_buttons_%s" % look)
	# The lower half — the segmented choice, a whole group and the search results.
	var scroll := screen.find_child("Scroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _save("icon_buttons_%s_bottom" % look)


## A drawing with its name under it.
func _cell(icons: GoIconSet, icon: StringName, size: int) -> Control:
	var box := GoStyle.column(4)
	box.custom_minimum_size.x = 96
	var mark := icons.node(icon, size, GoUi.color(GoTheme.TEXT))
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(mark)
	var name := GoStyle.label(String(icon), GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.x = 96
	name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(name)
	return box


func _save(name: String) -> void:
	for _i in 8: await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	var err := image.save_png(path)
	print("  %s %s (%dx%d)" % ["✅" if err == OK else "🛑", path, image.get_width(), image.get_height()])
