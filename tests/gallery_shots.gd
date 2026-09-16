## 📸 갤러리를 여러 화면 크기로 띄워 스크린샷을 남긴다 — 레이아웃이 실제로 어떻게 보이는지 눈으로 확인한다.
##
## ```
## godot --path <빈 검증 프로젝트> -s res://addons/gohud/tests/gallery_shots.gd -- --out=/tmp/gohud_shots
## ```
##
## 🛑 `--headless` 로는 그림이 나오지 않는다(더미 렌더러) — 창을 띄운다.
## 🛑 `frame_post_draw` 를 기다리지 않는다 — 창이 다른 창에 가려지면 영영 오지 않는다.
##    `RenderingServer.force_draw()` 뒤 바로 읽는다.
## 🛑 스크린샷을 찍었으면 **반드시 열어 본다.** 찍기만 하고 안 보면 터진 화면을 놓친다.
extends SceneTree

const SIZES := [
	{"name": "phone_portrait", "size": Vector2i(390, 844)},
	{"name": "phone_landscape", "size": Vector2i(844, 390)},
	{"name": "desktop", "size": Vector2i(1280, 800)},
]

var out_dir := "user://gohud_shots"
## 생김새 묶음(`--preset=scifi_dark`). 비우면 기본.
var preset: StringName = &""
## 움직임을 끄고 찍는다(`--still`) — 맥동·페이드가 멈춰 **실행마다 같은 그림**이 나온다.
## 🛑 테마를 고친 뒤 "모양이 안 변했다" 를 픽셀로 증명하려면 이것이 있어야 한다.
var still := false
## 어느 언어로 찍을 것인가(`--locale=ar`). 🛑 RTL 언어는 배치가 **거울처럼 뒤집힌다** —
## 글자가 칸을 넘치거나 겹치는 것은 검사로는 안 보이고 그림으로만 보인다.
var locale := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
		elif arg.begins_with("--preset="): preset = StringName(arg.substr(9))
		elif arg == "--still": still = true
		elif arg.begins_with("--locale="): locale = arg.substr(9)
	if not preset.is_empty(): GoUi.use_preset(preset)
	if not locale.is_empty(): TranslationServer.set_locale(locale)
	if still:
		GoUi.config.reduce_motion = true
		GoUi.config.surface_fade_in = false
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(180.0).timeout.connect(func() -> void:
		printerr("FAIL shots watchdog")
		quit(2))
	DisplayServer.window_set_position(Vector2i(40, 40))
	var scene: PackedScene = load("res://addons/gohud/examples/gallery/gallery.tscn")
	for spec in SIZES:
		var wanted: Vector2i = spec.size
		root.size = wanted
		await _settle(6)
		var gallery := scene.instantiate()
		root.add_child(gallery)
		await _settle(10)
		var label: String = spec.name
		_shot(label + "_1_page")

		# 🖥 **마우스와 키보드가 있는 화면에서만 보이는 상태.** 호버와 포커스 링은 손가락으로는
		#    영영 나타나지 않아, 지금까지 한 번도 그림으로 남은 적이 없다(2026-09-13).
		# 🛑 오버레이가 뜨기 **전에** 찍는다 — 팝업이 떠 있으면 그 버튼에 호버가 걸린다(실측).
		# 🛑 `await` 없이 부르면 코루틴이 첫 `await` 에서 멈춘 채 돌아와, 그림이 한 장도 안 남는다.
		await _shot_pointer_states(gallery, label)

		var scroll := gallery.find_child("Scroll", true, false) as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = 760
			await _settle(4)
			_shot(label + "_2_page_scrolled")
			scroll.scroll_vertical = 0
			await _settle(2)

		gallery.call("_start_tour")
		await _settle(6)
		_shot(label + "_3_tour")
		var tour: Object = gallery.get("_tour")
		# 🛑 **마지막 단계까지 간다** — `Done` 버튼은 거기서만 나오고, 그것이 두 줄로 갈라졌었다
		#    (2026-09-13 사용자 지적). 첫 단계만 찍으면 영영 못 본다.
		if tour != null:
			for i in 8:
				if tour.get("step") >= (tour.get("steps") as Array).size() - 1: break
				tour.call("advance")
				await _settle(3)
			await _settle(4)
			_shot(label + "_3b_tour_last")
			tour.call("finish", false)
		await _settle(2)

		# ⏱ 쿨다운 도는 슬롯 — 남은 시간이 아이콘 위에 겹쳐 읽히는지(2026-09-13 사용자 지적).
		var slots: Array = gallery.get("_slots")
		if slots != null and slots.size() > 0:
			(slots[0] as Object).call("set_cooldown", 5.0, 8.0)
			await _settle(4)
			_shot(label + "_3c_slot_cooldown")
			(slots[0] as Object).call("set_cooldown", 0.0, 8.0)
			await _settle(2)

		gallery.call("_open_sheet")
		await _settle(8)
		_shot(label + "_4_sheet")
		(gallery.get("_sheet") as Object).call("close")
		await _settle(2)

		var dialogs: Object = gallery.get("_dialogs")
		dialogs.set("_translate", false)
		dialogs.set("_cancel_key", "Cancel")
		(dialogs.get("_cancel") as Button).visible = true
		# 🛑 위험 동작의 확인 버튼은 **위험색**이다 — 그림에도 그대로 담긴다.
		dialogs.call("_tone", true)
		dialogs.call("_apply", "Delete character", "This cannot be undone. Delete \"{name}\"?", "Delete", "", {"name": "Aria"})
		await _settle(6)
		_shot(label + "_5_dialog")
		dialogs.call("_finish", false)
		await _settle(2)

		# 🔽 드롭다운을 **연 채로** 찍는다 — 메뉴 판·호버·라디오 표시는 열어야만 보인다(2026-09-13 사용자 지적).
		var picker: OptionButton = null
		for node in gallery.find_children("*", "OptionButton", true, false):
			if (node as Control).is_visible_in_tree(): picker = node; break
		if picker != null and scroll != null:
			scroll.ensure_control_visible(picker)
			await _settle(3)
			picker.show_popup()
			await _settle(6)
			# 마우스를 두 번째 항목 위에 얹어 **호버 판**까지 찍는다.
			var menu := picker.get_popup()
			if menu.item_count >= 2:
				var onto := InputEventMouseMotion.new()
				onto.position = Vector2(menu.position) + Vector2(menu.size) * 0.5   # Window 의 위치·크기는 Vector2i
				onto.global_position = onto.position
				Input.parse_input_event(onto)
				await _settle(4)
			_shot(label + "_5b_dropdown")
			picker.get_popup().hide()
			await _settle(2)
			scroll.scroll_vertical = 0
			await _settle(2)

		# 🔬 **판 불투명도** — 값 검사로는 확인할 수 없는 유일한 기능이다. "뒤가 보이는가" 와
		#    "글자가 아직 읽히는가" 는 그림만이 답한다. 세 장을 찍는다: 테마 값, 너무 낮춘 값,
		#    그리고 화면 전체 뒤에 무늬를 깐 상태(실제 게임 위에 얹힌 모습).
		var lab: Node = gallery.find_child("OpacityLab", true, false)
		if lab != null and scroll != null:
			scroll.ensure_control_visible(lab as Control)
			await _settle(5)
			_shot(label + "_6_opacity")
			var dial := lab.call("dial") as Range
			dial.value = 0.35
			await _settle(3)
			_shot(label + "_6b_opacity_low")
			gallery.call("_set_busy_background", true)
			dial.value = 0.72
			await _settle(4)
			_shot(label + "_6c_opacity_over_world")
			gallery.call("_set_busy_background", false)
			dial.value = GoUi.surface_alpha(GoTheme.BOX_CARD)
			await _settle(2)
			scroll.scroll_vertical = 0
			await _settle(2)

		gallery.call("_open_popup")
		gallery.call("_show_prompt")
		gallery.call("_show_notice")
		await _settle(8)
		_shot(label + "_7_overlays")


		gallery.queue_free()
		await _settle(3)
	print("SHOTS DONE ", out_dir)
	quit(0)


## 마우스를 버튼 위에 얹고, 키보드 포커스를 옮겨 그 상태를 찍는다.
func _shot_pointer_states(gallery: Node, label: String) -> void:
	var scroll := gallery.find_child("Scroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
		await _settle(3)
	# 첫 번째 버튼 줄을 찾는다 — 갤러리의 `Primary` 버튼이 맨 앞이다.
	var target: Button = null
	for node in gallery.find_children("*", "Button", true, false):
		var button := node as Button
		# 번역이 켜지면 글자가 달라지므로 **텍스트로 찾지 않는다** — 본문의 첫 번째 제대로 된 버튼이면 된다.
		if button != null and button.visible and button.size.x > 40.0 and button.size.y > 20.0:
			target = button
			break
	if target == null: return
	# 🛑 `Input.parse_input_event` 로 **진짜 마우스 이동**을 흘려보낸다 — `mouse_entered` 를 직접
	#    쏘면 엔진의 호버 상태는 바뀌지 않아 그림에는 아무 변화도 남지 않는다.
	var motion := InputEventMouseMotion.new()
	motion.position = target.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _settle(4)
	_shot(label + "_7_hover")

	target.grab_focus()
	await _settle(3)
	_shot(label + "_8_focus")

	# 🛑 **툴팁은 지연 뒤에 뜬다.** 마우스를 얹고 바로 찍으면 영영 안 나온다 — 엔진 설정
	#    `gui/timers/tooltip_delay_sec` 만큼 기다려야 한다. 아이콘 버튼은 글자가 없어
	#    툴팁이 그 버튼의 **유일한 설명**인데, 지금까지 뜨는 모습을 본 적이 없었다(2026-09-13).
	var glyph_button: GoIconButton = null
	for node in gallery.find_children("*", "GoIconButton", true, false):
		var candidate := node as GoIconButton
		if candidate != null and candidate.visible and not candidate.tooltip_text.is_empty():
			glyph_button = candidate
			break
	if glyph_button != null:
		var onto := InputEventMouseMotion.new()
		onto.position = glyph_button.get_global_rect().get_center()
		onto.global_position = onto.position
		Input.parse_input_event(onto)
		var delay: float = ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)
		await create_timer(delay + 0.35).timeout
		await _settle(3)
		_shot(label + "_9_tooltip")
	# 마우스를 멀리 치워 다음 촬영에 호버가 남지 않게 한다.
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-50, -50)
	away.global_position = away.position
	Input.parse_input_event(away)
	await _settle(2)


func _settle(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	image.save_png(path)
	print("SHOT ", path, " ", image.get_size())
