## Capture one screen after layout and rendering have settled.
## SHOT_SCENE picks the scene (default: the home screen); SHOT_PATH is where the PNG goes.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := OS.get_environment("SHOT_SCENE")
	if path.is_empty(): path = "res://home.tscn"
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0 if result == OK else 1)
