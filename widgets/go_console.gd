## 🖥 **Developer console** — type cheat and debug commands, watch the log.
##
## ```gdscript
## var console := GoConsole.new()
## add_child(console)
## console.register("give", "Grant an item: give <id> <count>", func(args: PackedStringArray) -> String:
##     return "granted %s" % args)
## console.register("tp", "Teleport to a coordinate: tp <x> <z>", teleport)
##
## # Log from anywhere
## console.log_line("connected to the server")
## ```
##
## ## 🛑 This is **for developers** — keep it from opening in shipping builds
## `debug_only` is on by default, so in a release build (`OS.is_debug_build() == false`) it never opens
## no matter how often you call it. The moment cheat commands reach players, the game economy is over.
## 🔑 To open it in QA builds only, set `debug_only = false` and gate it **yourself**.
##
## ## 🔑 It doubles as a command palette
## Type a name and a filtered list appears — nobody has to memorize commands. Pick with up/down, run with Enter.
##
## ## 🛑 The log is trimmed
## Left to grow forever it eats memory within minutes and scrolling turns heavy. Past `max_lines` (400 by
## default) the oldest lines are dropped first.
@tool
class_name GoConsole
extends CanvasLayer

## A command ran.
signal executed(command: String, args: PackedStringArray, result: String)

## The layer it shows on — it must sit **above everything** (you have to be able to debug on top of a dialog).
@export var layer_index := 200

## Never opens in a release build. 🛑 Think twice before turning this off.
@export var debug_only := true

## How many log lines to keep.
@export var max_lines := 400

## Fraction of the screen height it takes up.
@export_range(0.2, 1.0, 0.01) var height_ratio := 0.55

## The input line.
var input: LineEdit
## The pane the log piles up in.
var output: RichTextLabel

var _panel: PanelContainer
var _root: Control
var _suggest: VBoxContainer
var _commands: Dictionary = {}
var _history: PackedStringArray = []
var _history_at := -1
var _lines := 0
var _open := false


## 🪟 **Panel background opacity** (0.0~1.0) — for this one panel only. Negative means whatever the theme/config decided.
## 🛑 Only the background thins out — text and icons stay crisp.
var alpha := -1.0:
	set(value):
		alpha = value
		if _panel != null: _restyle()


func _init() -> void:
	layer = layer_index
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 🔑 you have to be able to debug while the game is paused

	_root = Control.new()
	_root.name = "ConsoleRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "Console"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	var pad := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	_panel.add_child(pad)
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	pad.add_child(column)

	output = RichTextLabel.new()
	output.name = "Output"
	output.bbcode_enabled = true
	output.scroll_following = true
	output.selection_enabled = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(output)

	_suggest = GoStyle.column(0)
	_suggest.name = "Suggest"
	_suggest.visible = false
	column.add_child(_suggest)

	input = GoStyle.line_edit("")
	input.name = "Input"
	# 🛑 Commands get **no** translation, autocomplete or capitalization fixups — they must go through exactly as typed.
	input.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	input.text_submitted.connect(_submit)
	input.text_changed.connect(_on_typed)
	column.add_child(input)


func _ready() -> void:
	layer = layer_index
	_restyle()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_on_ui_changed)
	# 🛑 Don't hardcode one language's text into addon code — the console is for developers, but **some teams translate it**.
	#    English is the lingua franca of dev tools, so it stays the default; to change it, overwrite the same name with `register()`.
	register("help", "List the commands", func(_a: PackedStringArray) -> String: return _help())
	register("clear", "Clear the log", func(_a: PackedStringArray) -> String:
		output.clear()
		_lines = 0
		return "")


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Registers one command. `action` is `func(args: PackedStringArray) -> String`,
## and whatever it returns is printed to the log (an empty string prints nothing).
func register(command: String, help: String, action: Callable) -> void:
	_commands[command.strip_edges().to_lower()] = {"help": help, "action": action}


func unregister(command: String) -> void:
	_commands.erase(command.strip_edges().to_lower())


func commands() -> Array:
	return _commands.keys()


## Opens the console. 🛑 In a release build with `debug_only` on it **does nothing.**
func open() -> void:
	if debug_only and not OS.is_debug_build(): return
	if _open: return
	_open = true
	visible = true
	_relayout()
	input.grab_focus.call_deferred()


func close() -> void:
	if not _open: return
	_open = false
	visible = false
	_suggest.visible = false


func toggle() -> void:
	if _open: close()
	else: open()


func is_open() -> bool:
	return _open


## One log line. `tone` is a color token (`GoTheme.DANGER`, …).
func log_line(message: String, tone := GoTheme.TEXT) -> void:
	if output == null: return
	output.push_color(GoUi.color(tone))
	output.add_text(message)
	output.pop()
	output.newline()
	_lines += 1
	# 🛑 Drop the oldest lines — otherwise memory and scrolling both get heavy over a long session.
	if _lines > max_lines:
		var keep := output.get_parsed_text().split("\n")
		var trimmed := keep.slice(maxi(0, keep.size() - max_lines))
		output.clear()
		output.add_text("\n".join(trimmed))
		_lines = trimmed.size()


## Runs one command line (callable from code without opening the console).
func run(line: String) -> String:
	# 🛑 **Blocking `open()` alone is useless.** Code can call `run("give …")` without ever opening the
	#    console, so the cheats would survive into the release build — this is the place to block them.
	if debug_only and not OS.is_debug_build(): return ""
	var trimmed := line.strip_edges()
	if trimmed.is_empty(): return ""
	var parts := trimmed.split(" ", false)
	var name := parts[0].to_lower()
	var args := PackedStringArray(parts.slice(1))
	log_line("> " + trimmed, GoTheme.MUTED)
	if not _commands.has(name):
		var message := "unknown command: %s" % name
		log_line(message, GoTheme.DANGER)
		return message
	var action: Callable = _commands[name]["action"]
	if not action.is_valid(): return ""
	var result := str(action.call(args))
	if not result.is_empty(): log_line(result)
	executed.emit(name, args, result)
	return result


func _submit(line: String) -> void:
	input.clear()
	_suggest.visible = false
	if line.strip_edges().is_empty(): return
	_history.append(line)
	_history_at = _history.size()
	run(line)


## Shows the commands whose name matches while you type — the whole point is that **nobody has to memorize commands**.
func _on_typed(text: String) -> void:
	for child in _suggest.get_children(): child.queue_free()
	var needle := text.strip_edges().to_lower()
	if needle.is_empty() or needle.contains(" "):
		_suggest.visible = false
		return
	var shown := 0
	for name in _commands:
		if not str(name).begins_with(needle): continue
		if shown >= 6: break
		shown += 1
		var help := str(_commands[name]["help"])
		var button := GoStyle.button("%s — %s" % [name, help], func() -> void:
			input.text = str(name) + " "
			input.caret_column = input.text.length()
			_suggest.visible = false, GoStyle.Tone.BARE)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_suggest.add_child(button)
	_suggest.visible = shown > 0


func _help() -> String:
	var lines: Array[String] = []
	var names := _commands.keys()
	names.sort()
	for name in names: lines.append("%s — %s" % [name, str(_commands[name]["help"])])
	return "\n".join(lines)


func _input(event: InputEvent) -> void:
	if not _open: return
	var key := event as InputEventKey
	if key == null or not key.pressed: return
	# Up/down recalls past commands — typing the same command over and over is most of debugging.
	if key.keycode == KEY_UP and _history.size() > 0:
		_history_at = maxi(0, _history_at - 1)
		input.text = _history[_history_at]
		input.caret_column = input.text.length()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DOWN and _history.size() > 0:
		_history_at = mini(_history.size(), _history_at + 1)
		input.text = "" if _history_at >= _history.size() else _history[_history_at]
		input.caret_column = input.text.length()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _relayout() -> void:
	if _panel == null or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	var area := GoSafeArea.usable_rect(window)
	_panel.position = area.position.round()
	_panel.size = Vector2(area.size.x, area.size.y * height_ratio).round()


func _restyle() -> void:
	_panel.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box(-1, -1, alpha))
	# 🔑 The log reads best in a **monospace font** — coordinates and numbers line up in columns. Falls back to the default font when the theme has none.
	output.add_theme_font_size_override(&"normal_font_size", GoUi.font_size(GoTheme.ROLE_COMPACT))
	output.add_theme_color_override(&"default_color", GoUi.color(GoTheme.TEXT))


func _on_ui_changed() -> void:
	_restyle()
	_relayout()
