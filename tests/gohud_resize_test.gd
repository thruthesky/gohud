## Resize batching and viewport lifetime, without host-project classes.
extends SceneTree

var checks := 0
var failures := 0

class Follower extends Node:
	var calls := 0
	var outside := 0
	var last_size := Vector2.ZERO
	func layout() -> void:
		calls += 1
		if not is_inside_tree(): outside += 1
		else: last_size = get_viewport().get_visible_rect().size

class OrderedFollower extends Node:
	var order: Array[String] = []
	var label: String
	func layout() -> void: order.append(label)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", label])

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	await create_timer(0.15).timeout
	await process_frame

func _run() -> void:
	await settle()
	var node := Follower.new()
	root.add_child(node)
	GoSafeArea.follow_view_size(node, node.layout)
	GoSafeArea.follow_view_size(node, node.layout)
	for i in 20:
		root.size_changed.emit()
		GoSafeArea.request_view_size(node, node.layout)
	check(node.calls == 0, "signals and polling fallback never lay out synchronously")
	await settle()
	check(node.calls == 1, "duplicate registration and twenty requests produce one layout")
	root.size_changed.emit()
	root.remove_child(node)
	await settle()
	check(node.calls == 1 and node.outside == 0, "tree exit cancels queued work")
	root.add_child(node)
	await settle()
	check(node.calls == 2, "tree re-entry lays out once")
	root.remove_child(node)
	var view := SubViewport.new()
	view.size = Vector2i(500, 800)
	root.add_child(view)
	view.add_child(node)
	await settle()
	check(node.last_size == Vector2(500, 800), "re-entry follows a different viewport")
	var before := node.calls
	root.size_changed.emit()
	await settle()
	check(node.calls == before, "old viewport is disconnected")
	view.size = Vector2i(800, 500)
	for i in 20: view.size_changed.emit()
	await settle()
	check(node.calls == before + 1 and node.last_size == Vector2(800, 500), "new viewport delivers only its final size")
	view.size_changed.emit()
	before = node.calls
	GoSafeArea.unfollow_view_size(node, node.layout)
	await settle()
	check(node.calls == before and not node.has_meta(GoSafeArea.VIEW_FOLLOWERS), "explicit unsubscribe cancels pending work")
	GoSafeArea.follow_view_size(node, node.layout)
	view.size_changed.emit()
	node.free()
	await settle()
	view.free()
	var order: Array[String] = []
	var consumer := OrderedFollower.new()
	consumer.order = order
	consumer.label = "layout"
	root.add_child(consumer)
	GoSafeArea.follow_view_size(consumer, consumer.layout)
	var transform := OrderedFollower.new()
	transform.order = order
	transform.label = "transform"
	root.add_child(transform)
	GoSafeArea.follow_view_size(transform, transform.layout, -100)
	root.size_changed.emit()
	await create_timer(0.02).timeout
	GoSafeArea.request_view_size(transform, transform.layout, true)
	await settle()
	check(order == ["transform", "layout"], "polling shares one deadline; transforms precede consumers even when registered later")
	consumer.free()
	transform.free()
	print("gohud resize tests: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
