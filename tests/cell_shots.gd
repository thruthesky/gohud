## 📸 **Shoots every cell-shaped widget in all six looks** — the reward calendar, a selectable table, a choice grid,
## carousel dots and a boxed prompt-card icon, each **inside a form** (the way the widget gallery hosts them) and on a
## phone-width strip.
##
##   bash <godot skill>/scripts/xvfb_run.sh --out <folder> --size 720x1600 -s res://addons/gohud/tests/cell_shots.gd
##
## 🔑 Why a separate shot: the preview the user pointed at (2026-09-23) came from the gallery, which wraps everything in
##    `GoStyle.form()` — and a form rewrote the calendar cell's spacing from 0 to 12, pushing the amount out of the cell.
##    `gohud_shot.gd` builds its pages **without** a form, so it showed the same calendar looking almost fine.
## 🛑 `--headless` produces no picture. Container fonts have no Korean — shapes are the point, so write in English.
extends SceneTree

const LOOKS := [
	GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT,
	GoThemePresets.SCIFI_DARK, GoThemePresets.SCIFI_LIGHT,
	GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT,
]
## Width of the phone strip (dp) — a 390 phone minus the page padding.
const PHONE := 350.0

var _dir := ""


func _initialize() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty(): _dir = "/out"
	GoUi.reset()
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false
	for look in LOOKS:
		GoUi.use_preset(look)
		await _shoot(look)
	print("✅ cell shots done — %s" % _dir)
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
	page.add_child(GoStyle.label("Cells — %s" % look, GoTheme.ROLE_TITLE))

	var days: Array = []
	for i in 7:
		days.append({"icon": &"crown" if i == 6 else &"coin", "amount": (i + 1) * 100, "special": i == 6})

	# The gallery's way: everything under a form.
	var form := GoStyle.column()
	page.add_child(form)
	form.add_child(GoStyle.section("Reward calendar in a form", false))
	form.add_child(GoRewardCalendar.make(days, 2))

	form.add_child(GoStyle.section("Phone width — 350dp", false))
	var strip_box := GoStyle.column(0)
	strip_box.custom_minimum_size.x = PHONE
	strip_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var edge := Panel.new()
	edge.custom_minimum_size = Vector2(PHONE, 2)
	edge.add_theme_stylebox_override(&"panel", _bar(GoUi.color(GoTheme.WARNING)))
	strip_box.add_child(edge)
	strip_box.add_child(GoRewardCalendar.make(days, 2))
	form.add_child(strip_box)

	form.add_child(GoStyle.section("Table rows", false))
	form.add_child(GoTable.make([{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}],
		[[1, "Aria", 91240], [2, "Brin", 48210], [3, "Cade", 9124]]))

	form.add_child(GoStyle.section("Choice grid", false))
	form.add_child(GoStyle.choice_grid([{"color": "e5484d", "tooltip": "Red"}, {"icon": GoIconSet.STAR, "text": "Star"},
		"Plain"], 1))

	form.add_child(GoStyle.section("Carousel dots · boxed prompt icon", false))
	var line := GoStyle.row()
	form.add_child(line)
	var carousel := GoCarousel.new()
	carousel.custom_minimum_size = Vector2(200, 90)
	var pages: Array = []
	for i in 3:
		var slide := ColorRect.new()
		slide.color = GoUi.color(GoTheme.SURFACE_HIGH)
		pages.append(slide)
	carousel.set_pages(pages)
	line.add_child(carousel)
	var card := GoPromptCard.new()
	card.set_title("Party invite")
	card.set_icon(GoIconSet.STAR, Color.TRANSPARENT, true)
	card.fade_in = false
	line.add_child(card)
	card.fit_width(260)
	card.show()

	GoStyle.form(form)
	await _save("cells_%s" % look)


func _bar(ink: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ink
	return box


func _save(name: String) -> void:
	for _i in 8: await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	var err := image.save_png(path)
	print("  %s %s (%dx%d)" % ["✅" if err == OK else "🛑", path, image.get_width(), image.get_height()])
