## 📸 **Really draws** newly added gohud widgets and saves them as PNGs (virtual monitor only).
##
##   bash <godot skill>/scripts/xvfb_run.sh --out <folder> --size 720x1600 \
##     -s res://addons/gohud/tests/gohud_shot.gd
##
## 🛑 `--headless` produces no screenshot — it does not draw.
##
## ## 🔑 Why this is needed
## On 2026-09-16, with **all 120 headless checks passing**, these shots turned up five defects —
## table rows had no text at all, badges floated outside their icons, and the spinner in a button was invisible.
## Checks that measure values know "how much" but **not "is it visible".** Touch a widget's shape, then shoot and look.
##
## 🛑 The container has no Korean font — Korean renders as tofu (□). Shapes are the point here, so write in English.
extends SceneTree

var _dir := ""


func _initialize() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty(): _dir = "/out"
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true   # shoot the final look, not a mid-animation frame

	await _shot_forms()
	await _shot_data()
	await _shot_game()
	await _shot_overlays()
	print("✅ shots done — %s" % _dir)
	quit(0)


func _page(title: String) -> VBoxContainer:
	for child in root.get_children():
		if child is CanvasLayer or child is Control: child.queue_free()
	await process_frame
	var back := ColorRect.new()
	back.color = GoUi.color(GoTheme.BACKGROUND)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var pad := GoStyle.padding()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pad)
	var column := GoStyle.column()
	pad.add_child(column)
	var head := GoStyle.label(title, GoTheme.ROLE_TITLE)
	column.add_child(head)
	return column


func _save(name: String) -> void:
	for _i in 6: await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	var err := image.save_png(path)
	print("  %s %s (%dx%d)" % ["✅" if err == OK else "🛑", path, image.get_width(), image.get_height()])


# ── Forms ─────────────────────────────────────────────────────────────

func _shot_forms() -> void:
	var page := await _page("Forms & Input")

	var name_field := GoField.make("Character name", GoStyle.line_edit("2-12 chars"), "Cannot be changed later")
	page.add_child(name_field)

	var taken := GoField.make("Guild name", GoStyle.line_edit(""))
	page.add_child(taken)
	taken.set_error("That name is taken")

	page.add_child(GoStyle.label("Input group", GoTheme.ROLE_CAPTION))
	page.add_child(GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": GoStyle.button("Send")}))
	page.add_child(GoInputGroup.make(GoStyle.line_edit("Search by name"), {"prefix_icon": &"search"}))

	page.add_child(GoStyle.label("Coupon code", GoTheme.ROLE_CAPTION))
	var coupon := GoCodeInput.make(12, 4)
	page.add_child(coupon)
	coupon.set_code("ABCD9F")

	page.add_child(GoStyle.label("Combobox & Kbd", GoTheme.ROLE_CAPTION))
	var names: Array = []
	for i in 30: names.append({"text": "Player%d" % i})
	page.add_child(GoCombobox.make(names, 2, "Find a friend"))
	var keys := GoKbd.make("Ctrl", "S")
	keys.hide_on_handheld = false
	page.add_child(keys)

	await _save("01_forms")


# ── Data ──────────────────────────────────────────────────────────────

func _shot_data() -> void:
	var page := await _page("Table & Pagination")

	var rows := [[1, "Aria", 91240], [2, "Brin", 48210], [3, "Cade", 9124], [4, "Dane", 500]]
	var table := GoTable.make(
		[{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}], rows)
	table.sort_by(2, false)
	page.add_child(table)

	page.add_child(GoStyle.divider())
	page.add_child(GoPagination.make(5, 12))
	page.add_child(GoPagination.more())

	page.add_child(GoStyle.label("Waiting", GoTheme.ROLE_CAPTION))
	var busy_row := GoStyle.row()
	page.add_child(busy_row)
	var spinner := GoSpinner.new()
	spinner.custom_minimum_size = Vector2(32, 32)
	busy_row.add_child(spinner)
	var buying := GoStyle.button("Buy now", Callable(), GoStyle.Tone.PRIMARY)
	buying.custom_minimum_size.x = 160
	busy_row.add_child(buying)
	await process_frame
	GoSpinner.busy(buying, true)

	await _save("02_data")


# ── Game ──────────────────────────────────────────────────────────────

func _shot_game() -> void:
	var page := await _page("Rewards & Stats")

	var days: Array = []
	for i in 7:
		days.append({"icon": &"coin" if i < 6 else &"crown", "amount": (i + 1) * 100, "special": i == 6})
	page.add_child(GoRewardCalendar.make(days, 2))

	page.add_child(GoStyle.divider())
	var charts := GoStyle.row(GoUi.metric(GoTheme.GAP))
	page.add_child(charts)
	var radar := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45},
		{"STR": 0.6, "AGI": 0.75, "INT": 0.35, "VIT": 0.55, "LUK": 0.45})
	radar.custom_minimum_size = Vector2(180, 180)
	charts.add_child(radar)
	var donut := GoDonut.make([
		{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340}, {"label": "Pierce", "value": 90}])
	donut.center_text = "1050"
	donut.center_hint = "Damage"
	donut.custom_minimum_size = Vector2(150, 150)
	charts.add_child(donut)
	page.add_child(donut.legend())

	page.add_child(GoStyle.label("Badges", GoTheme.ROLE_CAPTION))
	var badges := GoStyle.row(GoUi.metric(GoTheme.GAP))
	page.add_child(badges)
	for pair in [[3, ""], [0, "NEW"], [128, ""]]:
		var host := GoIconButton.new()
		host.icon_name = &"bag"
		badges.add_child(host)
		await process_frame
		GoBadge.attach(host, int(pair[0]), str(pair[1]))
	badges.add_child(GoBadge.make(0, "", true))

	await _save("03_game")


# ── Overlays ──────────────────────────────────────────────────────────

func _shot_overlays() -> void:
	var page := await _page("Snackbar & Drawer")
	page.add_child(GoStyle.label("A snackbar sits at the bottom", GoTheme.ROLE_BODY))

	var snack := GoSnackbar.new()
	root.add_child(snack)
	await process_frame
	snack.post({"text": "Item dropped", "tone": GoTheme.WARNING, "seconds": 0.0,
		"icon": &"trash", "actions": ["Undo"]})
	await _save("04_snackbar")

	snack.dismiss()
	await process_frame
	var drawer := GoDrawer.new()
	drawer.motion_seconds = 0.0
	drawer.side = GoDrawer.Side.LEFT
	root.add_child(drawer)
	await process_frame
	drawer.open("Bag")
	for i in 8:
		drawer.body.add_child(GoStyle.list_button(&"potion", "Potion %d" % (i + 1), Callable(),
			Color.TRANSPARENT, "Restores health", false))
	await _save("05_drawer")
