## 언어 카드만 찍는다 — 21개 언어가 **실제로 그려지는지**(두부 □ 가 아닌지) 눈으로 확인하는 용도.
extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var demo: Control = load("res://demo.tscn").instantiate()
	root.add_child(demo)
	for frame in 10: await process_frame
	# 데모는 페이지 맨 아래에 언어 카드를 둔다 — 스크롤을 끝까지 내린다.
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
