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
