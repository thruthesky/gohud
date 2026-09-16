## 📸 Opens the gallery at several screen sizes and saves screenshots — see with your own eyes how the layout really looks.
##
## ```
## godot --path <empty verification project> -s res://addons/gohud/tests/gallery_shots.gd -- --out=/tmp/gohud_shots
## ```
##
## 🛑 `--headless` produces no pictures (dummy renderer) — open a window.
## 🛑 Do not wait on `frame_post_draw` — if another window covers this one it never comes.
##    Read straight after `RenderingServer.force_draw()`.
## 🛑 Once a screenshot is taken, **open it.** Shooting without looking misses a broken screen.
extends SceneTree

const SIZES := [
	{"name": "phone_portrait", "size": Vector2i(390, 844)},
	{"name": "phone_landscape", "size": Vector2i(844, 390)},
	{"name": "desktop", "size": Vector2i(1280, 800)},
]

var out_dir := "user://gohud_shots"
## Look preset (`--preset=scifi_dark`). Empty means the default.
var preset: StringName = &""
## Shoot with motion off (`--still`) — pulses and fades stop, so **every run gives the same picture**.
## 🛑 You need this to prove in pixels that "the shape did not change" after editing a theme.
var still := false
## Which language to shoot in (`--locale=ar`). 🛑 RTL languages **mirror** the layout —
## text spilling out of a box or overlapping is invisible to checks and shows only in a picture.
var locale := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		elif arg.begins_with("--preset="): preset = StringName(arg.substr(9))
		elif arg == "--still": still = true
		elif arg.begins_with("--locale="): locale = arg.substr(9)
	if not preset.is_empty(): GoUi.use_preset(preset)
	if not locale.is_empty(): TranslationServer.set_locale(locale)
	if still:
		GoUi.config.reduce_motion = true
		GoUi.config.surface_fade_in = false
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(180.0).timeout.connect(func() -> void:
		printerr("FAIL shots watchdog")
		quit(2))
	DisplayServer.window_set_position(Vector2i(40, 40))
	var scene: PackedScene = load("res://addons/gohud/examples/gallery/gallery.tscn")
	for spec in SIZES:
		var wanted: Vector2i = spec.size
		root.size = wanted
		await _settle(6)
		var gallery := scene.instantiate()
		root.add_child(gallery)
		await _settle(10)
		var label: String = spec.name
		_shot(label + "_1_page")

		# 🖥 **States that appear only on a screen with a mouse and a keyboard.** Hover and the focus ring never
		#    show up under a finger, so until now they had never been captured in a picture (2026-09-13).
		# 🛑 Shoot **before** an overlay opens — a raised popup puts hover on its button (measured).
		# 🛑 Called without `await`, the coroutine returns parked at its first `await` and not a single picture is saved.
		await _shot_pointer_states(gallery, label)

		var scroll := gallery.find_child("Scroll", true, false) as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = 760
			await _settle(4)
			_shot(label + "_2_page_scrolled")
			scroll.scroll_vertical = 0
			await _settle(2)

		gallery.call("_start_tour")
		await _settle(6)
		_shot(label + "_3_tour")
		var tour: Object = gallery.get("_tour")
		# 🛑 **Go all the way to the last step** — the `Done` button appears only there, and that is the one that split
		#    across two lines (2026-09-13 user report). Shooting the first step alone never shows it.
		if tour != null:
			for i in 8:
				if tour.get("step") >= (tour.get("steps") as Array).size() - 1: break
				tour.call("advance")
				await _settle(3)
			await _settle(4)
			_shot(label + "_3b_tour_last")
			tour.call("finish", false)
		await _settle(2)

		# ⏱ A slot on cooldown — is the remaining time readable on top of the icon (2026-09-13 user report).
		var slots: Array = gallery.get("_slots")
		if slots != null and slots.size() > 0:
			(slots[0] as Object).call("set_cooldown", 5.0, 8.0)
			await _settle(4)
			_shot(label + "_3c_slot_cooldown")
			(slots[0] as Object).call("set_cooldown", 0.0, 8.0)
			await _settle(2)

		gallery.call("_open_sheet")
		await _settle(8)
		_shot(label + "_4_sheet")
		(gallery.get("_sheet") as Object).call("close")
		await _settle(2)

		var dialogs: Object = gallery.get("_dialogs")
		dialogs.set("_translate", false)
		dialogs.set("_cancel_key", "Cancel")
		(dialogs.get("_cancel") as Button).visible = true
		# 🛑 The confirm button of a dangerous action is in the **danger colour** — the picture must carry that too.
		dialogs.call("_tone", true)
		dialogs.call("_apply", "Delete character", "This cannot be undone. Delete \"{name}\"?", "Delete", "", {"name": "Aria"})
		await _settle(6)
		_shot(label + "_5_dialog")
		dialogs.call("_finish", false)
		await _settle(2)

		# 🔽 Shoot the dropdown **open** — the menu panel, hover and radio marks are visible only when it is (2026-09-13 user report).
		var picker: OptionButton = null
		for node in gallery.find_children("*", "OptionButton", true, false):
			if (node as Control).is_visible_in_tree(): picker = node; break
		if picker != null and scroll != null:
			scroll.ensure_control_visible(picker)
			await _settle(3)
			picker.show_popup()
			await _settle(6)
			# Put the mouse over the second item so the **hover panel** is shot as well.
			var menu := picker.get_popup()
			if menu.item_count >= 2:
				var onto := InputEventMouseMotion.new()
				onto.position = Vector2(menu.position) + Vector2(menu.size) * 0.5   # a Window's position and size are Vector2i
				onto.global_position = onto.position
				Input.parse_input_event(onto)
				await _settle(4)
			_shot(label + "_5b_dropdown")
			picker.get_popup().hide()
			await _settle(2)
			scroll.scroll_vertical = 0
			await _settle(2)

		# 🔬 **Container alpha** — the one feature value checks cannot confirm. "Does the back show through" and
		#    "is the text still readable" are answered by a picture alone. Three shots: the theme value, a value pushed too low,
		#    and a pattern laid behind the whole screen (how it sits over a real game).
		var lab: Node = gallery.find_child("OpacityLab", true, false)
		if lab != null and scroll != null:
			scroll.ensure_control_visible(lab as Control)
			await _settle(5)
			_shot(label + "_6_opacity")
			var dial := lab.call("dial") as Range
			dial.value = 0.35
			await _settle(3)
			_shot(label + "_6b_opacity_low")
			gallery.call("_set_busy_background", true)
			dial.value = 0.72
			await _settle(4)
			_shot(label + "_6c_opacity_over_world")
			gallery.call("_set_busy_background", false)
			dial.value = GoUi.surface_alpha(GoTheme.BOX_CARD)
			await _settle(2)
			scroll.scroll_vertical = 0
			await _settle(2)

		gallery.call("_open_popup")
		gallery.call("_show_prompt")
		gallery.call("_show_notice")
		await _settle(8)
		_shot(label + "_7_overlays")


		gallery.queue_free()
		await _settle(3)
	print("SHOTS DONE ", out_dir)
	quit(0)


## Puts the mouse on a button and moves keyboard focus there, then shoots that state.
func _shot_pointer_states(gallery: Node, label: String) -> void:
	var scroll := gallery.find_child("Scroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
		await _settle(3)
	# Find the first row of buttons — the gallery's `Primary` button comes first.
	var target: Button = null
	for node in gallery.find_children("*", "Button", true, false):
		var button := node as Button
		# Text changes once translation is on, so **do not search by text** — the first real button in the body will do.
		if button != null and button.visible and button.size.x > 40.0 and button.size.y > 20.0:
			target = button
			break
	if target == null: return
	# 🛑 Push a **real mouse move** through `Input.parse_input_event` — firing `mouse_entered` directly
	#    leaves the engine's hover state unchanged, so nothing changes in the picture.
	var motion := InputEventMouseMotion.new()
	motion.position = target.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _settle(4)
	_shot(label + "_7_hover")

	target.grab_focus()
	await _settle(3)
	_shot(label + "_8_focus")

	# 🛑 **Tooltips appear after a delay.** Shooting right after the mouse lands never shows them — you have to wait
	#    out the engine setting `gui/timers/tooltip_delay_sec`. An icon button carries no text, so its tooltip is that
	#    button's **only description**, and until now it had never been seen on screen (2026-09-13).
	var glyph_button: GoIconButton = null
	for node in gallery.find_children("*", "GoIconButton", true, false):
		var candidate := node as GoIconButton
		if candidate != null and candidate.visible and not candidate.tooltip_text.is_empty():
			glyph_button = candidate
			break
	if glyph_button != null:
		var onto := InputEventMouseMotion.new()
		onto.position = glyph_button.get_global_rect().get_center()
		onto.global_position = onto.position
		Input.parse_input_event(onto)
		var delay: float = ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)
		await create_timer(delay + 0.35).timeout
		await _settle(3)
		_shot(label + "_9_tooltip")
	# Move the mouse far away so no hover is left over for the next shot.
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-50, -50)
	away.global_position = away.position
	Input.parse_input_event(away)
	await _settle(2)


func _settle(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path, " ", image.get_size())
