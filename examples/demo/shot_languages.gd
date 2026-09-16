## Captures the language card only — to see with your own eyes that all 21 languages really draw (and are not tofu □).
extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var demo: Control = load("res://demo.tscn").instantiate()
	root.add_child(demo)
	for frame in 10: await process_frame
	# The demo puts the language card at the very bottom of the page — scroll all the way down.
	var scroll := _find_scroll(demo)
	if scroll != null:
		scroll.scroll_vertical = 1 << 20
		for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if root.get_texture().get_image().save_png(OS.get_environment("SHOT_PATH")) == OK else 1)

func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer: return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null: return found
	return null
