## Capture the current main scene after layout and rendering have settled.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(scene)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0 if result == OK else 1)
