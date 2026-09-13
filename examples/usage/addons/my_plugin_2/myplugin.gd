@tool
extends EditorPlugin

var dock: EditorDock


func _enter_tree() -> void:
	dock = EditorDock.new()
	dock.title = "My Plugin 2"
	dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL

	var content = preload(
		"res://addons/my_plugin_2/dock.tscn"
	).instantiate()
	dock.add_child(content)

	add_dock(dock)


func _exit_tree() -> void:
	if is_instance_valid(dock):
		remove_dock(dock)
		dock.queue_free()
		dock = null