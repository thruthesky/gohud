## Integration test for the demo app's doorway and home screen: the main scene really reaches
## `home.tscn`, the four rows open their example and come back, number keys do the same, the live
## widgets fire their callbacks, and the top bar appears only while an example is open.
## Run through tools/check_demo.sh, which enforces a timeout and checks engine errors.
extends SceneTree

var home: Control
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: return
	failures.append(description)
	push_error("HOME TEST: %s" % description)


func settle(frames := 8) -> void:
	for frame in frames: await process_frame


func _run() -> void:
	var dimensions := OS.get_environment("DEMO_TEST_SIZE").split("x")
	if dimensions.size() == 2: root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))

	# 🔑 문간부터 시작한다 — 이 데모가 깨졌던 자리가 바로 "메인 씬이 뜨지 않는다" 였다.
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await settle(20)
	check(current_scene != null and current_scene.name == "Home", "The main scene reaches the home screen")
	if current_scene == null or current_scene.name != "Home":
		_finish()
		return
	home = current_scene

	var chrome := home.find_child("Chrome", true, false) as Control
	check(chrome != null and not chrome.visible, "The top bar stays out of the way on the home screen")
	check(home.find_child("HomePage", true, false) != null, "The home screen builds its page")

	await _rows()
	await _keys()
	await _live_widgets()
	_finish()


func _finish() -> void:
	print("HOME TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## 네 줄이 저마다 제 화면을 열고, `Home` 이 다시 홈으로 돌려놓는가.
func _rows() -> void:
	var chrome := home.find_child("Chrome", true, false) as Control
	for item in home.TARGETS:
		var key := String(item["key"])
		home._open(key)
		await settle(14)
		var stage := home.find_child("Stage", true, false) as Control
		var opened: Node = stage.get_child(stage.get_child_count() - 1) if stage.get_child_count() > 0 else null
		check(opened != null and opened.visible, "%s opens on the stage" % key)
		check(chrome.visible, "%s shows the top bar" % key)
		var title := home.find_child("Chrome", true, false).find_child("Inset", true, false)
		check(title != null, "The top bar carries its contents")

		home._show_home()
		await settle(14)
		# medieval 은 프리셋을 바꾸므로 홈이 씬째 다시 지어진다 — 그때는 `current_scene` 을 다시 잡는다.
		if current_scene != null and current_scene != home: home = current_scene
		await settle(6)
		check(home.find_child("HomePage", true, false) != null, "Home returns after %s" % key)
		chrome = home.find_child("Chrome", true, false) as Control
		check(chrome != null and not chrome.visible, "The top bar hides again after %s" % key)


## 손이 키보드에 있는 사람을 위한 길: `1`~`4`.
func _keys() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_2
	event.pressed = true
	home._unhandled_key_input(event)
	await settle(14)
	check(home._open_key == "tour", "Number keys open the matching screen")
	home._show_home()
	await settle(14)
	if current_scene != null and current_scene != home: home = current_scene
	check(home._open_key == "", "Home clears the open screen")


## 카드 안의 것들이 **진짜로 눌리는가** — 기록 줄이 움직이면 콜백이 돈 것이다.
func _live_widgets() -> void:
	var log_line := home._log as Label
	check(log_line != null, "The home screen keeps a callback line")
	if log_line == null: return
	var before := log_line.text

	var pressed := 0
	for button in _buttons(home):
		if button.text in ["Primary", "Notice", "Bottom sheet", "Prompt card"]:
			button.pressed.emit()
			await settle(4)
			pressed += 1
	check(pressed >= 4, "The live card offers its buttons")
	check(log_line.text != before, "Pressing a live widget reports a callback")

	check(home._sheet != null and home._sheet.visible, "The bottom sheet opens from the home screen")
	check(home._prompt != null and home._prompt.visible, "The prompt card opens from the home screen")

	# 화면을 갈면 띄워 둔 것부터 걷힌다 — 남겨 두면 사라진 화면에 포커스를 되돌리려 한다.
	home._open("gallery")
	await settle(14)
	check(not home._sheet.visible, "Opening a screen dismisses the sheet")
	# 프롬프트 카드는 홈 페이지에 속한 손님이라 페이지와 함께 걷힌다(시트는 껍데기가 들고 있다).
	check(home._prompt == null, "The prompt card leaves with the home page")
	home._show_home()
	await settle(14)
	if current_scene != null and current_scene != home: home = current_scene


func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	_collect(node, found)
	return found


func _collect(node: Node, out: Array[Button]) -> void:
	if node is Button: out.append(node as Button)
	for child in node.get_children(): _collect(child, out)
