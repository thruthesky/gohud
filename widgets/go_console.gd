## 🖥 **개발자 콘솔** — 치트·디버그 명령을 치고, 로그를 본다.
##
## ```gdscript
## var console := GoConsole.new()
## add_child(console)
## console.register("give", "아이템을 준다: give <id> <수량>", func(args: PackedStringArray) -> String:
##     return "준비됨 %s" % args)
## console.register("tp", "좌표로 옮긴다: tp <x> <z>", teleport)
##
## # 어디서든 로그를 남긴다
## console.log_line("서버에 붙었다")
## ```
##
## ## 🛑 이것은 **개발자용**이다 — 배포 빌드에서 열리지 않게 한다
## 기본값 `debug_only` 가 켜져 있어 릴리스 빌드(`OS.is_debug_build() == false`)에서는 아무리
## 불러도 열리지 않는다. 치트 명령이 플레이어 손에 들어가면 그 순간 게임 경제가 끝난다.
## 🔑 QA 빌드에서만 열고 싶으면 `debug_only = false` 로 두고 **직접** 조건을 건다.
##
## ## 🔑 명령 팔레트로도 쓴다
## 이름을 치면 걸러지는 목록이 뜬다 — 명령을 외우지 않아도 된다. 위/아래로 고르고 Enter 로 실행한다.
##
## ## 🛑 로그는 잘라 낸다
## 무한히 쌓으면 몇 분 만에 메모리를 먹고 스크롤이 무거워진다. `max_lines`(기본 400) 를 넘으면
## 오래된 줄부터 버린다.
@tool
class_name GoConsole
extends CanvasLayer

## 명령을 실행했다.
signal executed(command: String, args: PackedStringArray, result: String)

## 이 층에 뜬다 — **무엇보다 위**여야 한다(대화상자 위에서도 디버깅할 수 있어야 한다).
@export var layer_index := 200

## 릴리스 빌드에서는 열리지 않는다. 🛑 끄기 전에 두 번 생각한다.
@export var debug_only := true

## 로그를 몇 줄까지 들고 있을 것인가.
@export var max_lines := 400

## 차지할 화면 높이 비율.
@export_range(0.2, 1.0, 0.01) var height_ratio := 0.55

## 입력줄.
var input: LineEdit
## 로그가 쌓이는 칸.
var output: RichTextLabel

var _panel: PanelContainer
var _root: Control
var _suggest: VBoxContainer
var _commands: Dictionary = {}
var _history: PackedStringArray = []
var _history_at := -1
var _lines := 0
var _open := false


## 🪟 **판 바탕의 불투명도**(0.0~1.0) — 이것 하나만 다르게. 음수면 테마·설정이 정한 값.
## 🛑 바탕만 묽어진다 — 글자·아이콘은 선명한 채로 남는다.
var alpha := -1.0:
	set(value):
		alpha = value
		if _panel != null: _restyle()


func _init() -> void:
	layer = layer_index
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 🔑 게임을 멈춘 채로도 디버깅할 수 있어야 한다

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
	# 🛑 명령은 번역·자동완성·대문자 보정을 **하지 않는다** — 친 그대로 가야 한다.
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
	# 🛑 애드온 코드에 한 언어의 글자를 박지 않는다 — 콘솔은 개발자용이지만 **번역하는 팀도 있다**.
	#    영어는 개발 도구의 공통어라 기본으로 두고, 바꾸려면 `register()` 로 같은 이름을 덮어쓴다.
	register("help", "List the commands", func(_a: PackedStringArray) -> String: return _help())
	register("clear", "Clear the log", func(_a: PackedStringArray) -> String:
		output.clear()
		_lines = 0
		return "")


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 명령 하나를 등록한다. `action` 은 `func(args: PackedStringArray) -> String` 이고,
## 돌려준 글이 로그에 찍힌다(빈 글이면 안 찍는다).
func register(command: String, help: String, action: Callable) -> void:
	_commands[command.strip_edges().to_lower()] = {"help": help, "action": action}


func unregister(command: String) -> void:
	_commands.erase(command.strip_edges().to_lower())


func commands() -> Array:
	return _commands.keys()


## 콘솔을 연다. 🛑 릴리스 빌드에서는 `debug_only` 가 켜져 있으면 **아무 일도 하지 않는다.**
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


## 로그 한 줄. `tone` 은 색 토큰(`GoTheme.DANGER` 등).
func log_line(message: String, tone := GoTheme.TEXT) -> void:
	if output == null: return
	output.push_color(GoUi.color(tone))
	output.add_text(message)
	output.pop()
	output.newline()
	_lines += 1
	# 🛑 오래된 줄을 버린다 — 안 그러면 긴 세션에서 메모리와 스크롤이 함께 무거워진다.
	if _lines > max_lines:
		var keep := output.get_parsed_text().split("\n")
		var trimmed := keep.slice(maxi(0, keep.size() - max_lines))
		output.clear()
		output.add_text("\n".join(trimmed))
		_lines = trimmed.size()


## 명령 한 줄을 실행한다(콘솔을 열지 않고 코드에서 불러도 된다).
func run(line: String) -> String:
	# 🛑 **`open()` 만 막아서는 소용이 없다.** 콘솔을 열지 않고 코드에서 `run("give …")` 을 부를 수
	#    있으므로, 치트가 릴리스 빌드에 그대로 남는다 — 막는 자리는 여기다.
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


## 치는 동안 이름이 맞는 명령을 보여 준다 — **명령을 외우지 않아도 되게** 하는 것이 핵심이다.
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
	# 위·아래로 지난 명령을 꺼낸다 — 같은 명령을 몇 번씩 치는 것이 디버깅의 대부분이다.
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
	# 🔑 로그는 **고정폭 글꼴**이 읽기 쉽다 — 좌표·수치가 세로로 줄이 맞는다. 테마에 없으면 기본 글꼴.
	output.add_theme_font_size_override(&"normal_font_size", GoUi.font_size(GoTheme.ROLE_COMPACT))
	output.add_theme_color_override(&"default_color", GoUi.color(GoTheme.TEXT))


func _on_ui_changed() -> void:
	_restyle()
	_relayout()
