## 데모 화면을 한 장 찍고 끝낸다. 🛑 헤드리스로는 못 찍는다 — 실제로 그려야 픽셀이 나온다.
extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var window := root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(1680, 1400)
	var scene: Node = load("res://demo.tscn").instantiate()
	window.add_child(scene)
	for i in 12:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := window.get_texture().get_image()
	image.save_png(OS.get_environment("SHOT_PATH"))
	quit()
