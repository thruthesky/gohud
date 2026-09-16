## 🧪 **스킬이 나눠 주는 템플릿 다섯**이 실제로 서는지 본다.
##
##   godot --headless --path <프로젝트> -s res://addons/gohud/tests/gohud_templates_test.gd
##
## ## 🛑 왜 필요한가 (2026-09-16)
## `skills/gohud/assets/templates/` 의 다섯 파일은 **사람이 제 프로젝트로 복사해 그대로 쓰는 코드**다.
## 그런데 지금까지 이 다섯 장을 여는 검사가 **하나도 없었다** — 문서(`SKILL.md`)에 "headless-tested"
## 라고 적혀 있었을 뿐이다. 파싱 오류 하나가 그대로 배포되면, 받은 사람은 빈 화면과 오류 한 줄을 본다.
##
## ## 무엇을 보나
## ① 다섯 장이 **로드되는가**(파싱 오류가 없는가) ② 트리에 들어가 화면이 **서는가**
## ③ 공개 API 가 부르면 도는가 ④ 새로 엮은 위젯(스낵바·배지·스피너·키 안내·GoField)이 실제로 있는가
##
## 🛑 `await` 로 답을 기다리는 API(`say()`·인벤토리의 Drop)는 **부르지 않는다** — 누를 사람이 없어
##    영영 돌아오지 않는다. 그 자리에는 위젯이 만들어졌는지만 본다.
extends SceneTree

const TEMPLATES := "res://addons/gohud/skills/gohud/assets/templates"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true

	await _loads()
	await _main_menu()
	await _game_hud()
	await _pause_menu()
	await _inventory_sheet()
	await _settings_menu()

	print("gohud template tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for _i in count: await process_frame


func _make(file: String) -> Node:
	var script: Script = load("%s/%s" % [TEMPLATES, file])
	if script == null: return null
	return script.new()


## 트리 안의 모든 자손.
func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all(child))
	return out


## 그 형의 자손이 있는가. 🔑 `is` 로 보므로 자식 클래스도 센다.
func _has(node: Node, kind: Variant) -> bool:
	for child in _all(node):
		if is_instance_of(child, kind): return true
	return false


# ── ① 다섯 장이 열리는가 ───────────────────────────────────────────────

func _loads() -> void:
	for file in ["main_menu.gd", "game_hud.gd", "pause_menu.gd", "inventory_sheet.gd", "settings_menu.gd"]:
		check(load("%s/%s" % [TEMPLATES, file]) != null, "템플릿이 로드된다 — %s" % file)


# ── ② 첫 화면 ──────────────────────────────────────────────────────────

func _main_menu() -> void:
	var menu: Control = _make("main_menu.gd")
	check(menu != null, "main_menu 를 만든다")
	if menu == null: return
	root.add_child(menu)
	await frames(2)
	check(_has(menu, GoForm), "main_menu 에 GoForm 이 선다")
	check(menu.continue_button != null, "main_menu 가 Continue 를 들고 있다")

	# 느린 불러오기 — 버튼이 제자리에서 스피너가 되고, 그동안 눌리지 않는다.
	if menu.continue_button != null:
		# 🛑 템플릿에는 `class_name` 이 없어 그 멤버는 Variant 다 — 타입을 적지 않으면 추론이 안 된다.
		var size_before: Vector2 = menu.continue_button.size
		menu.set_loading(true)
		await frames(2)
		check(GoSpinner.is_busy(menu.continue_button), "set_loading(true) 가 버튼을 스피너로 바꾼다")
		check(menu.continue_button.disabled, "기다리는 동안 버튼이 눌리지 않는다")
		check(menu.continue_button.size.is_equal_approx(size_before),
			"스피너가 버튼 크기를 바꾸지 않는다 — %s → %s" % [size_before, menu.continue_button.size])
		menu.set_loading(false)
		await frames(2)
		check(not GoSpinner.is_busy(menu.continue_button), "set_loading(false) 가 글자를 되돌린다")
	menu.queue_free()
	await frames(1)


# ── ③ HUD ──────────────────────────────────────────────────────────────

func _game_hud() -> void:
	var hud: CanvasLayer = _make("game_hud.gd")
	check(hud != null, "game_hud 를 만든다")
	if hud == null: return
	root.add_child(hud)
	await frames(2)
	check(hud.layer == 5, "HUD 가 레이어 5 에 선다 — %d" % hud.layer)
	check(hud.hp != null and hud.slots.size() == 4, "막대와 퀵슬롯 넷이 선다")

	hud.set_health(60.0, 100.0)
	hud.toast("저장했습니다", GoTheme.SUCCESS)
	await frames(2)

	# 🔑 스낵바는 **제 레이어**를 가진다 — HUD 의 Control 트리 안에 있으면 시트가 덮는다.
	check(hud.snackbar != null, "HUD 가 스낵바를 들고 있다")
	if hud.snackbar != null:
		check(hud.snackbar.get_parent() == hud, "스낵바가 HUD 루트가 아니라 HUD 노드에 붙는다")

	# 배지 — 0 이면 숨고, 세면 보인다.
	hud.set_unread(0)
	await frames(2)
	var badge: GoBadge = _find_badge(hud)
	check(badge != null, "메뉴 버튼에 배지가 붙는다")
	if badge != null:
		check(not badge.visible, "안 읽은 것이 없으면 배지가 숨는다")
		hud.set_unread(7)
		await frames(2)
		check(badge.visible, "안 읽은 것이 있으면 배지가 보인다")
		# 🛑 배지는 앵커로 **모서리**에 걸린다 — 부모 왼쪽 위(0,0)에 붙어 있으면 앵커가 안 먹은 것이다.
		check(badge.position.x > 0.0 or badge.position.y != 0.0,
			"배지가 모서리에 걸린다 — %s" % badge.position)
	hud.queue_free()
	await frames(1)


func _find_badge(node: Node) -> GoBadge:
	for child in _all(node):
		if child is GoBadge: return child as GoBadge
	return null


# ── ④ 일시정지 ─────────────────────────────────────────────────────────

func _pause_menu() -> void:
	var pause: CanvasLayer = _make("pause_menu.gd")
	check(pause != null, "pause_menu 를 만든다")
	if pause == null: return
	root.add_child(pause)
	await frames(2)
	pause.open()
	await frames(3)
	check(pause.is_open(), "일시정지가 열린다")
	check(_has(pause, GoKbd), "이어하기 키 안내가 선다")
	pause.resume()
	await frames(2)
	check(not pause.is_open(), "일시정지가 닫힌다")
	# 🛑 트리를 멈춘 채로 두면 **뒤의 검사가 전부 멈춘다.**
	check(not root.get_tree().paused, "닫으면 트리가 다시 돈다")
	pause.queue_free()
	await frames(1)


# ── ⑤ 인벤토리 ─────────────────────────────────────────────────────────

func _inventory_sheet() -> void:
	var bag: Node = _make("inventory_sheet.gd")
	check(bag != null, "inventory_sheet 를 만든다")
	if bag == null: return
	root.add_child(bag)
	await frames(2)
	bag.open()
	await frames(3)
	check(bag.sheet != null, "시트가 선다")
	var rows := 0
	for child in _all(bag):
		if child is Button and child.has_meta(&"gohud_context_menu"): rows += 1
	check(rows > 0, "목록 줄에 길게 누르기 메뉴가 붙는다 — %d 줄" % rows)
	bag.close()
	await frames(2)
	bag.queue_free()
	await frames(1)


# ── ⑥ 설정 ─────────────────────────────────────────────────────────────

func _settings_menu() -> void:
	var settings: Control = _make("settings_menu.gd")
	check(settings != null, "settings_menu 를 만든다")
	if settings == null: return
	root.add_child(settings)
	await frames(3)
	check(_has(settings, GoField), "설정 줄이 GoField 로 선다")
	# 칸별 오류 — 한 줄짜리 "입력을 확인하세요" 가 아니라, 그 칸이 스스로 말한다.
	for child in _all(settings):
		if child is GoField:
			var field := child as GoField
			field.set_error("그 이름은 이미 있습니다")
			await frames(2)
			check(field.has_error(), "GoField 가 오류를 문다")
			check(field.error_text() == "그 이름은 이미 있습니다", "오류 글이 그대로 남는다(번역하지 않는다)")
			field.clear_error()
			await frames(1)
			check(not field.has_error(), "오류를 지운다")
			break
	settings.queue_free()
	await frames(1)
