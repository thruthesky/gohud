## Synthetic layout tests use logical units, independent of the host window's scale.
extends RefCounted

static func configure(tree: SceneTree, wanted: Vector2i) -> void:
	var window := tree.root
	# The first pass lets host autoloads finish their initial canvas setup. The second
	# establishes the test canvas after those deferred resize notifications settle.
	for _pass in 2:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		window.content_scale_factor = 1.0
		window.content_scale_size = wanted
		for _frame in 2:
			await tree.process_frame
	assert(is_equal_approx(window.content_scale_factor, 1.0), "test canvas must use unit scale")
	assert(window.get_visible_rect().size.distance_to(Vector2(wanted)) < 0.75,
		"test canvas must reach the requested logical size")
