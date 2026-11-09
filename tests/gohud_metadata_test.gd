## An arcade skin can be used with a host theme that carries no baked font metadata.
extends SceneTree

class ErrorSink extends Logger:
	var metadata_errors := 0
	func _log_error(function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if function == "get_meta" and error_type != Logger.ERROR_TYPE_WARNING:
			metadata_errors += 1

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sink := ErrorSink.new()
	OS.add_logger(sink)
	var theme := Theme.new()
	# Positive control: explicitly passing null is still an error when absent.
	theme.get_meta(&"go_body_font_baked", null)
	check(sink.metadata_errors == 1, "legacy null-default metadata read emits an engine error")
	sink.metadata_errors = 0
	GoUi.config.theme = theme
	var skin := GoSkinArcadePainted.new()
	var fallback := skin.symbol_font()
	check(fallback is Font, "an unannotated host theme uses the bundled symbol font")
	theme.set_meta(&"go_body_font_baked", "invalid")
	check(skin.symbol_font() == fallback, "malformed font metadata keeps the bundled fallback")
	var baked := FontVariation.new()
	theme.set_meta(&"go_body_font_baked", baked)
	check(skin.symbol_font() == fallback, "an empty baked fallback list uses the bundled symbol font")
	baked.fallbacks = [ThemeDB.fallback_font]
	check(skin.symbol_font() == ThemeDB.fallback_font, "a baked fallback font is preserved")
	check(sink.metadata_errors == 0, "symbol fallback emits no metadata errors")
	OS.remove_logger(sink)
	GoUi.reset()
	print("gohud metadata tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
