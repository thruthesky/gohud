## 📸 갤러리를 여러 화면 크기로 띄워 스크린샷을 남긴다 — 레이아웃이 실제로 어떻게 보이는지 눈으로 확인한다.
##
## ```
## godot --path <빈 검증 프로젝트> -s res://addons/gohud/tests/gallery_shots.gd -- --out=/tmp/gohud_shots
## ```
##
## 🛑 `--headless` 로는 그림이 나오지 않는다(더미 렌더러) — 창을 띄운다.
## 🛑 `frame_post_draw` 를 기다리지 않는다 — 창이 다른 창에 가려지면 영영 오지 않는다.
##    `RenderingServer.force_draw()` 뒤 바로 읽는다.
## 🛑 스크린샷을 찍었으면 **반드시 열어 본다.** 찍기만 하고 안 보면 터진 화면을 놓친다.
extends SceneTree

const SIZES := [
	{"name": "phone_portrait", "size": Vector2i(390, 844)},
	{"name": "phone_landscape", "size": Vector2i(844, 390)},
	{"name": "desktop", "size": Vector2i(1280, 800)},
]

var out_dir := "user://gohud_shots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(180.0).timeout.connect(func() -> void:
		printerr("FAIL shots watchdog")
		quit(2))
	DisplayServer.window_set_position(Vector2i(40, 40))
	var scene: PackedScene = load("res://addons/gohud/examples/gallery.tscn")
	for spec in SIZES:
		var wanted: Vector2i = spec.size
		root.size = wanted
		await _settle(6)
		var gallery := scene.instantiate()
		root.add_child(gallery)
		await _settle(10)
		var label: String = spec.name
		_shot(label + "_1_page")

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
		if tour != null: tour.call("finish", false)
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
		dialogs.call("_apply", "Delete character", "This cannot be undone. Delete \"{name}\"?", "Delete", "", {"name": "Aria"})
		await _settle(6)
		_shot(label + "_5_dialog")
		dialogs.call("_finish", false)
		await _settle(2)

		gallery.call("_open_popup")
		gallery.call("_show_prompt")
		gallery.call("_show_notice")
		await _settle(8)
		_shot(label + "_6_overlays")

		gallery.queue_free()
		await _settle(3)
	print("SHOTS DONE ", out_dir)
	quit(0)


func _settle(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path, " ", image.get_size())
