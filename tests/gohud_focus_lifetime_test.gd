## Deferred focus restoration must recheck the opener when the callback runs.
## The window may close just before its parent hides or removes the old screen.
extends SceneTree

class ErrorSink extends Logger:
	var focus_errors := 0
	func _log_error(function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if function == "grab_focus" and error_type != Logger.ERROR_TYPE_WARNING:
			focus_errors += 1

var checks := 0
var failures := 0
var sink := ErrorSink.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(sink)
	# Positive control: this was the previous implementation. Removal after the
	# eligibility check must expose the engine error this test is meant to catch.
	var removed := Button.new()
	root.add_child(removed)
	removed.grab_focus.call_deferred()
	root.remove_child(removed)
	await process_frame
	await process_frame
	check(sink.focus_errors > 0, "legacy deferred focus reproduces grab_focus engine error")
	print("  legacy deferred focus errors: %d" % sink.focus_errors)
	removed.free()
	sink.focus_errors = 0
	var surface := GoSurface.new()
	# A saved weak reference is the state held while a window is open.
	for change in ["hide", "remove", "free", "disable", "no_focus", "valid"]:
		var opener := Button.new()
		opener.text = "Open"
		root.add_child(opener)
		surface.set("_previous_focus", weakref(opener))
		surface.call("_restore_focus")
		match change:
			"hide": opener.hide()
			"remove": root.remove_child(opener)
			"free": opener.free()
			"disable": opener.disabled = true
			"no_focus": opener.focus_mode = Control.FOCUS_NONE
		await process_frame
		await process_frame
		if change == "valid":
			check(root.gui_get_focus_owner() == opener, "a usable opener regains focus")
		else:
			check(root.gui_get_focus_owner() == null, "%s opener never regains focus" % change)
		if is_instance_valid(opener): opener.free()
	check(sink.focus_errors == 0, "no grab_focus engine errors after opener changes (%d)" % sink.focus_errors)
	surface.free()
	OS.remove_logger(sink)
	GoUi.reset()
	print("gohud focus lifetime tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
