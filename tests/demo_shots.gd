## 📸 **Shoots the demo's (`examples/demo`) widget screens section by section** — it holds layouts the gallery does not.
##
## ```
## bash addons/gohud/tools/demo_shots.sh /tmp/demo_shots      # symlinks and import handled for you
## ```
##
## 🛑 Do not touch the demo code — this only calls `sim.gd`'s `_open_explore(index)` from outside.
##    The pictures the user pointed at (a `Done` split across two lines, a clipped glow, cramped slots, a flat dropdown)
##    all came from the **demo**, while the shots were being taken of the gallery only (2026-09-13, I-56).
## 🛑 `--headless` produces no pictures · do not wait on `frame_post_draw` (same reason as the gallery).
extends SceneTree

const SIZES := [
	{"name": "phone", "size": Vector2i(390, 844)},
	{"name": "desktop", "size": Vector2i(1280, 800)},
]

var out_dir := "user://demo_shots"
## Shoot only these sections (`--only=selection,hud`). Empty means all of them.
var only: PackedStringArray = []
## Shoot only these sizes (`--sizes=desktop`). Empty means all of them.
var sizes: PackedStringArray = []
## 🔑 **Shoot after running the bot as well** (`--play`). Merely opening a section leaves the demo's stage widgets
##    disabled and only grey gets shot (2026-09-13, I-61·65). Run the bot at 4× down the same path as
##    "Play this widget" (`_play_current`) and shoot **the last frame while it is live** — the coach mark's `Done` card and a raised notice show up there.
##    The demo's `_shot_dir` is switched on too, so we also get the pictures it saves right after each scene (`NN-key.png`).
var play := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		elif arg.begins_with("--only="): only = arg.substr(7).split(",", false)
		elif arg.begins_with("--sizes="): sizes = arg.substr(8).split(",", false)
		elif arg == "--play": play = true
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(240.0).timeout.connect(func() -> void:
		printerr("FAIL demo shots watchdog")
		quit(2))
	DisplayServer.window_set_position(Vector2i(40, 40))
	var scene: PackedScene = load("res://sim.tscn")
	var entries: Array = SimActs.list()
	for spec in SIZES:
		if not sizes.is_empty() and not sizes.has(spec.name): continue
		# 🛑 The demo project carries `window_width_override=2560`, so `root.size` alone got the first screen
		#    shot at 2560×1600 (measured). Set **both** the window and the viewport, and wait generously.
		DisplayServer.window_set_size(spec.size)
		await _settle(6)
		_pin_scale(spec.size)
		await _settle(8)
		var sim := scene.instantiate()
		root.add_child(sim)
		# 🛑 The demo's `_scale_window` opens with a `_scaling` guard — leaving it on makes it return at once, so
		#    the scale reset can be blocked without touching demo code (`_pin_scale` alone was overwritten the next frame).
		sim.set("_scaling", true)
		_pin_scale(spec.size)
		if play:
			sim.set("_shot_dir", ProjectSettings.globalize_path(out_dir).path_join(spec.name + "_bot"))
			DirAccess.make_dir_recursive_absolute(sim.get("_shot_dir"))
			sim.call("_set_speed", 4.0)
		await _settle(12)
		_shot("%s_00_start" % spec.name)
		for index in entries.size():
			var key := String((entries[index] as Dictionary).get("key", str(index)))
			if not only.is_empty() and not only.has(key): continue
			sim.call("_open_explore", index)
			await _settle(14)
			_pin_scale(spec.size)
			await _settle(2)
			_shot("%s_%02d_%s" % [spec.name, index + 1, key])
			# 🔽 One more shot with the dropdown **open** — the menu panel and radio marks are only visible when it is.
			for node in sim.find_children("*", "OptionButton", true, false):
				var picker := node as OptionButton
				if picker == null or not picker.is_visible_in_tree() or picker.item_count == 0: continue
				picker.show_popup()
				await _settle(6)
				_shot("%s_%02d_%s_open" % [spec.name, index + 1, key])
				picker.get_popup().hide()
				await _settle(2)
				break
			if play:
				sim.call("_play_current")
				# 🛑 Wait until `_running` goes off — scenes differ in length, so a fixed frame count will not do.
				#    🔑 **The screen after playback ends is useless** — the demo returns to its explore state, rebuilds the stage
				#    and goes grey (measured: reset to `Clicks: 0`). The live pictures are the ones the bot saves right after each
				#    scene at `<size>_bot/NN-key.png`, and **momentary scenes** (coach-mark cards, raised notices, prompts, sheets)
				#    are caught by polling during playback for the first moment the overlay is visible.
				var waited := 0.0
				var seen: Dictionary = {}
				while sim.get("_running") and waited < 90.0:
					await create_timer(0.2).timeout
					waited += 0.2
					for cls in ["GoCoachMark", "GoSurface", "GoNotice", "GoPromptCard"]:
						for node in root.find_children("*", cls, true, false):
							var overlay := node as Control
							if overlay == null or not overlay.is_visible_in_tree() or overlay.get_global_rect().get_area() <= 0.0: continue
							# One shot **per step** of the coach mark — the last step's `Done` is where it split across two lines (user report).
							var tag: String = cls
							if cls == "GoCoachMark" and overlay.get("step") != null: tag = "%s_step%d" % [cls, int(overlay.get("step")) + 1]
							if seen.has(tag): break
							# 🛑 The **first frame** with `visible` on is still at fade-in alpha 0, so the card is missing from the picture
							#    (measured: only the arrow was left). Waiting a fixed time instead lets the 4× bot press `Done` meanwhile (measured).
							#    For coach marks, wait **only until the card's alpha has filled** and shoot straight away.
							if cls == "GoCoachMark":
								var card_node := overlay.get("card") as CanvasItem
								if card_node != null and card_node.modulate.a < 0.9: break
							else:
								await create_timer(0.3).timeout
							seen[tag] = true
							_pin_scale(spec.size)
							_shot("%s_%02d_%s_mid_%s" % [spec.name, index + 1, key, tag])
							break
				await _settle(4)
		sim.queue_free()
		await _settle(3)
	print("DEMO SHOTS DONE ", out_dir)
	quit(0)


## 🛑 The demo's `_scale_window` multiplies the content by the **display scale** (retina 2×) on every window resize —
##    headless checks have no window so the scale is 1 and the phone layout comes out, but in a windowed shot a 390dp
##    window held only 195dp and titles broke inside words (measured `quic`/`k`). Reset the scale to 1 right before shooting.
func _pin_scale(size: Vector2i) -> void:
	root.content_scale_factor = 1.0
	root.content_scale_size = size
	root.size = size


func _settle(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path, " ", image.get_size())
