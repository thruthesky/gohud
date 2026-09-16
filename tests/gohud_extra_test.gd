## 🧪 **뒤에 들인 위젯들의 검사.** `gohud_test.gd` 와 나란히 돈다.
##
##   godot --headless --path <프로젝트> -s res://addons/gohud/tests/gohud_extra_test.gd
##
## ## 🔑 왜 파일을 나눴나
## `gohud_test.gd` 는 2000줄이 넘는다. 위젯을 들일 때마다 그 한 파일이 커지면
## ① 여러 사람이 같은 자리를 고쳐 충돌이 잦고 ② 어디를 보아야 하는지 찾기 어려워진다.
## **묶음이 다르면 파일도 나눈다** — 여기는 스낵바·스피너·배지·표처럼 나중에 들인 것들이다.
##
## ## 🛑 움직임이 있는 위젯은 `reduce_motion` 으로 잰다
## 뜨고 지는 애니메이션 중에 자리를 재면 **중간값**이 나온다(2026-09-16 실측: 스낵바가 화면
## 밖으로 7dp 나간 것처럼 보였는데, 실제로는 올라오는 중이었다). 최종 자리를 보려면 움직임을 끈다.
extends SceneTree

const ADDON := "res://addons/gohud"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	# 🛑 커스텀 스킨(각진 판)에서는 모서리·StyleBoxFlat 을 전제한 판정이 뜻을 잃는다. 기본에서 잰다.
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true

	await _snackbar()
	await _spinner()
	await _badge()
	await _field()
	await _input_group()
	await _kbd()
	await _context_menu()
	await _popover()
	await _table()
	await _pagination()
	await _drawer()
	await _combobox()
	await _reward_calendar()
	await _charts()
	await _code_input()
	await _console()
	await _carousel()
	await _theme_follow()

	print("gohud extra tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func section(name: String) -> void:
	print("  %s %s" % ["ok  " if failed.is_empty() else "....", name])


func frames(count: int) -> void:
	for _i in count: await process_frame


# ── 스낵바 ─────────────────────────────────────────────────────────────

func _snackbar() -> void:
	var snack := GoSnackbar.new()
	root.add_child(snack)
	await frames(2)
	var card: PanelContainer = snack.get_node(^"SnackbarLayer/SnackbarRoot/Snackbar")
	var area := GoSafeArea.usable_rect(root)
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN))

	snack.show_text("저장했습니다", GoTheme.SUCCESS)
	await frames(4)
	check(card.visible, "스낵바: 뜬다")
	# 🛑 화면 **밖으로 나가지 않는다** — 안전영역 안, 여백만큼 띄우고.
	check(card.position.y + card.size.y <= area.end.y - edge + 1.0,
		"스낵바: 화면 안에 있다 (%.0f + %.0f ≤ %.0f)" % [card.position.y, card.size.y, area.end.y - edge])
	check(card.position.y > area.size.y * 0.5, "스낵바: 아래쪽에 뜬다")
	# 🛑 높이가 **최소와 같다** — 폭이 정해지기 전에 잰 값이 굳으면 카드가 네 배로 커진다.
	check(is_equal_approx(card.size.y, card.get_combined_minimum_size().y),
		"스낵바: 높이 = 최소 높이 (%.0f · %.0f)" % [card.size.y, card.get_combined_minimum_size().y])
	check(card.size.x <= snack.max_width + 1.0, "스낵바: 최대 폭을 지킨다")
	check(card.mouse_filter != Control.MOUSE_FILTER_IGNORE or not snack.tap_to_dismiss,
		"스낵바: 눌러 닫기가 켜져 있으면 입력을 받는다")

	# 위쪽 배치
	snack.dismiss()
	await frames(3)
	snack.placement = GoSnackbar.Placement.TOP
	snack.show_text("위")
	await frames(4)
	check(is_equal_approx(card.position.y, area.position.y + edge), "스낵바: TOP 배치 (%.0f)" % card.position.y)
	snack.placement = GoSnackbar.Placement.BOTTOM

	# 버튼 — 되돌리기
	snack.clear()
	await frames(3)
	var log: Array[String] = []
	var picked := [-99]
	_ask_snack(snack, log, picked)
	await frames(4)
	var buttons: Array[String] = []
	for node in _all(card):
		if node is Button and not (node is GoIconButton): buttons.append((node as Button).text)
	check(buttons == ["되돌리기"], "스낵바: 버튼이 붙는다 (%s)" % str(buttons))
	check(card.mouse_filter == Control.MOUSE_FILTER_STOP, "스낵바: 버튼이 있으면 입력을 받는다")
	for node in _all(card):
		if node is Button and (node as Button).text == "되돌리기": (node as Button).pressed.emit()
	await frames(3)
	check(picked[0] == 0, "스낵바: 눌린 버튼 번호가 돌아온다 (%d)" % picked[0])
	check(log.has("되돌림"), "스낵바: 버튼의 콜백이 불린다")

	# 큐 — 셋을 연달아 띄우면 하나만 뜨고 둘이 기다린다
	snack.clear()
	await frames(3)
	snack.show_text("첫째"); snack.show_text("둘째"); snack.show_text("셋째")
	await frames(2)
	check(snack.is_showing() and snack.pending() == 2, "스낵바: 줄을 선다 (대기 %d)" % snack.pending())

	# 같은 글은 하나로 — 끊긴 서버가 같은 오류를 쏟아낼 때
	snack.clear()
	await frames(3)
	snack.show_text("연결 실패"); snack.show_text("연결 실패"); snack.show_text("연결 실패")
	await frames(2)
	check(snack.pending() == 0, "스낵바: 같은 글은 하나로 친다 (대기 %d)" % snack.pending())

	# 버튼 없는 알림은 입력을 통과시킨다 — 게임이 멈추면 안 된다
	snack.clear()
	await frames(3)
	snack.tap_to_dismiss = false
	snack.show_text("통과")
	await frames(4)
	check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "스낵바: 순수 알림은 입력을 통과시킨다")
	check(card.accessibility_name == "통과", "스낵바: 스크린리더 이름 (%s)" % card.accessibility_name)
	snack.queue_free()
	await frames(1)
	section("snackbar")


func _ask_snack(snack: GoSnackbar, log: Array[String], out: Array) -> void:
	out[0] = await snack.post({"text": "아이템을 버렸습니다", "tone": GoTheme.WARNING, "seconds": 0.0,
		"actions": [{"text": "되돌리기", "action": func() -> void: log.append("되돌림")}]})


# ── 대화상자 큐 ────────────────────────────────────────────────────────

func _dialogs_queue() -> void:
	pass


# ── 스피너 ─────────────────────────────────────────────────────────────

func _spinner() -> void:
	# 움직임을 켠 채로만 도는지 본다.
	GoUi.config.reduce_motion = false
	var spinner := GoSpinner.new()
	root.add_child(spinner)
	await frames(2)
	check(spinner.is_processing(), "스피너: 돈다")
	spinner.visible = false
	await frames(1)
	# 🛑 안 보이는 동안은 돌지 않는다 — 숨긴 스피너가 매 프레임 다시 그리면 그만큼 공짜로 버린다.
	check(not spinner.is_processing(), "스피너: 숨기면 멈춘다")
	spinner.visible = true
	await frames(1)
	GoUi.config.reduce_motion = true
	GoUi.refresh()
	await frames(1)
	# ♿ 회전을 끈 사람에게는 돌지 않는다.
	check(not spinner.is_processing(), "스피너: reduce_motion 이면 돌지 않는다")

	var button := GoStyle.button("구매")
	root.add_child(button)
	await frames(2)
	var before := button.size
	GoSpinner.busy(button, true)
	await frames(2)
	check(GoSpinner.is_busy(button) and button.disabled, "스피너: busy 는 버튼을 잠근다")
	var busy_spinner := button.get_node_or_null(^"BusySpinner") as Control
	check(busy_spinner != null, "스피너: 버튼 안에서 돈다")
	# 🛑 **버튼 안에 실제로 들어 있는가.** 앵커가 가운데인데 부모 크기를 또 더하면 버튼 밖으로
	#    날아가, 글자만 사라진 빈 버튼이 남는다(2026-09-16 촬영에서 발견).
	if busy_spinner != null:
		var spin_rect := Rect2(busy_spinner.global_position, busy_spinner.size)
		var host_rect2 := Rect2(button.global_position, button.size)
		check(host_rect2.encloses(spin_rect),
			"스피너: 버튼 안에 들어 있다 (스피너 %s · 버튼 %s)" % [str(spin_rect), str(host_rect2)])
	check(button.get_theme_color(&"font_disabled_color").a <= 0.01, "스피너: 글자를 감춘다")
	GoSpinner.busy(button, true)   # 두 번 불러도 하나만
	await frames(1)
	var spinners := 0
	for node in button.get_children():
		if node is GoSpinner: spinners += 1
	check(spinners == 1, "스피너: 두 번 걸어도 하나만 (%d)" % spinners)
	GoSpinner.busy(button, false)
	await frames(2)
	check(not GoSpinner.is_busy(button) and not button.disabled, "스피너: busy 를 풀면 되돌아온다")
	# 🛑 감춰 둔 글자색을 **지운다** — 안 지우면 이후 정말 비활성일 때 빈 판으로 보인다.
	check(not button.has_theme_color_override(&"font_disabled_color"), "스피너: 감춘 글자색을 되돌린다")
	spinner.queue_free(); button.queue_free()
	await frames(1)
	section("spinner")


# ── 배지 ───────────────────────────────────────────────────────────────

func _badge() -> void:
	var badge := GoBadge.make(5)
	root.add_child(badge)
	await frames(2)
	check(badge.visible and _first_label(badge) == "5", "배지: 숫자를 쓴다")
	badge.set_count(0)
	await frames(1)
	check(not badge.visible, "배지: 0 이면 숨는다")
	badge.set_count(500)
	await frames(1)
	# 🛑 접지 않으면 "1284" 가 아이콘보다 넓어져 HUD 줄이 밀린다.
	check(_first_label(badge) == "99+", "배지: 큰 수를 접는다 (%s)" % _first_label(badge))
	badge.dot = true
	await frames(1)
	check(badge.custom_minimum_size.x > 0 and _first_label(badge) == "", "배지: 점 모드")

	var host := GoStyle.button("우편함")
	root.add_child(host)
	await frames(2)
	var one := GoBadge.attach(host, 3)
	await frames(1)
	check(one != null and one.get_parent() == host, "배지: 붙는다")
	check(GoBadge.attach(host, 4) == one, "배지: 두 번 붙여도 하나")
	# 🛑 오른쪽 위에 **절반만 걸친다** — 안쪽이면 아이콘을 가리고, 완전히 밖이면 동떨어져 보인다.
	#    앵커가 이미 오른쪽 위라 부모 폭을 또 더하면 한 폭만큼 날아간다(2026-09-16 촬영에서 발견).
	var badge_rect := Rect2(one.global_position, one.size)
	var host_rect := Rect2(host.global_position, host.size)
	check(host_rect.intersects(badge_rect),
		"배지: 부모 모서리에 걸친다 (배지 %s · 부모 %s)" % [str(badge_rect), str(host_rect)])
	check(badge_rect.get_center().x > host_rect.get_center().x and badge_rect.get_center().y < host_rect.get_center().y,
		"배지: 오른쪽 위 모서리다")
	GoBadge.detach(host)
	await frames(1)
	check(not host.has_meta(&"gohud_badge"), "배지: 뗀다")
	badge.queue_free(); host.queue_free()
	await frames(1)
	section("badge")


# ── 폼 한 줄 ───────────────────────────────────────────────────────────

func _field() -> void:
	var edit := GoStyle.line_edit("2~12자")
	var field := GoField.make("캐릭터 이름", edit, "나중에 바꿀 수 없습니다")
	root.add_child(field)
	await frames(2)
	check(field.label.text == "캐릭터 이름" and field.hint_label.visible, "폼줄: 라벨·설명")
	check(not field.error_label.visible, "폼줄: 오류는 처음엔 없다")
	check(edit.accessibility_name.contains("캐릭터 이름"), "폼줄: 라벨이 스크린리더로 간다")

	field.set_error("이미 쓰는 이름입니다")
	await frames(1)
	check(field.has_error() and field.error_label.visible, "폼줄: 오류가 뜬다")
	# 🔑 설명과 오류는 자리를 다투지 않는다 — 둘이 쌓이면 아래 칸이 전부 밀린다.
	check(not field.hint_label.visible, "폼줄: 오류가 뜨면 설명이 숨는다")
	# ♿ 색만으로는 읽히지 않는다 — 오류 글이 스크린리더 이름에도 들어간다.
	check(edit.accessibility_name.contains("이미 쓰는"), "폼줄: 오류가 스크린리더로 간다")
	check(edit.has_theme_stylebox_override(&"normal"), "폼줄: 칸 테두리도 물든다")

	field.clear_error()
	await frames(1)
	check(not field.has_error() and field.hint_label.visible, "폼줄: 오류를 지우면 설명이 돌아온다")
	check(not edit.has_theme_stylebox_override(&"normal"), "폼줄: 테두리도 되돌아온다")
	field.queue_free()
	await frames(1)
	section("field")


# ── 붙은 입력 묶음 ─────────────────────────────────────────────────────

func _input_group() -> void:
	var input := GoStyle.line_edit("메시지")
	var send := GoStyle.button("보내기")
	var group := GoInputGroup.make(input, {"suffix": send})
	root.add_child(group)
	await frames(3)
	check(group.get_theme_constant(&"separation") == 0, "입력묶음: 간격 0")
	var left: StyleBox = input.get_theme_stylebox(&"normal")
	var right: StyleBox = send.get_theme_stylebox(&"normal")
	# 🛑 맞닿는 안쪽만 각지게 — 둥근 모서리 두 쌍이 맞붙으면 잘록해 보인다.
	if &"corner_radius_top_left" in left:
		check(float(left.get(&"corner_radius_top_left")) > 0.0 and float(left.get(&"corner_radius_top_right")) == 0.0,
			"입력묶음: 앞은 바깥쪽만 둥글다")
		check(float(right.get(&"corner_radius_top_right")) > 0.0 and float(right.get(&"corner_radius_top_left")) == 0.0,
			"입력묶음: 뒤는 바깥쪽만 둥글다")
	else:
		# 각진 스킨에는 모서리 칸이 없다 — 손대지 않는 것이 올바른 동작이다.
		check(true, "입력묶음: 각진 스킨에서는 모서리를 건드리지 않는다")
	var marked := GoInputGroup.make(GoStyle.line_edit("이름"), {"prefix_icon": &"search"})
	root.add_child(marked)
	await frames(2)
	check(marked.prefix != null, "입력묶음: 아이콘 표식이 붙는다")
	group.queue_free(); marked.queue_free()
	await frames(1)
	section("input group")


# ── 키 캡 ──────────────────────────────────────────────────────────────

func _kbd() -> void:
	var keys := GoKbd.make("Ctrl", "S")
	root.add_child(keys)
	await frames(2)
	check(keys.keys().size() == 2, "키캡: 조합 두 개")
	check(keys.get_child_count() == 3, "키캡: 캡 + 가운데 + 캡")
	check(keys.accessibility_name == "Ctrl + S", "키캡: 한 마디로 읽힌다 (%s)" % keys.accessibility_name)
	# 🛑 키 이름은 낱말이 아니라 **키에 새겨진 기호**다 — `Ctrl` 이 `Ctr`/`l` 로 쪼개지면 안 된다.
	var cap_label := (keys.get_child(0) as Control).get_child(0) as Label
	check(cap_label != null and cap_label.get_line_count() == 1,
		"키캡: 키 이름이 한 줄이다 (%d줄)" % (cap_label.get_line_count() if cap_label else -1))
	# 🛑 폰에는 키보드가 없다 — 손에 드는 기기에서는 스스로 숨는다.
	check(keys.visible != GoUi.is_handheld_platform(), "키캡: 손에 드는 기기에서는 숨는다")
	keys.set_keys([])
	await frames(1)
	check(not keys.visible, "키캡: 빈 키는 숨는다")
	# 없는 액션은 빈 것을 준다 — "없음" 같은 글자를 띄우지 않는다.
	var absent := GoKbd.for_action(&"gohud_probe_missing_action")
	root.add_child(absent)
	await frames(1)
	check(not absent.visible, "키캡: 묶이지 않은 액션은 숨는다")
	keys.queue_free(); absent.queue_free()
	await frames(1)
	section("kbd")


# ── 길게 눌러 여는 메뉴 ────────────────────────────────────────────────

func _context_menu() -> void:
	var slot := GoSlot.new()
	root.add_child(slot)
	await frames(2)
	GoContextMenu.attach(slot, [{"text": "사용"}, {"separator": true}, {"text": "버리기", "danger": true}])
	check(slot.has_meta(&"gohud_context_menu"), "맥락메뉴: 붙는다")
	var popup := GoContextMenu.open_at(slot, [{"text": "귓속말"}, {"text": "차단", "disabled": true}])
	await frames(2)
	check(popup != null and popup.item_count == 2, "맥락메뉴: 항목 둘")
	check(popup.is_item_disabled(1), "맥락메뉴: 비활성 항목")
	# 🔑 목록이 상황마다 달라지는 자리 — 열릴 때 만든다.
	var live := GoContextMenu.open_at(slot, func() -> Array: return [{"text": "1"}, {"text": "2"}, {"text": "3"}])
	await frames(2)
	check(live != null and live.item_count == 3, "맥락메뉴: 열 때마다 목록을 만든다")
	GoContextMenu.detach(slot)
	check(not slot.has_meta(&"gohud_context_menu"), "맥락메뉴: 뗀다")
	slot.queue_free()
	await frames(1)
	section("context menu")


# ── 붙어서 뜨는 카드 ───────────────────────────────────────────────────

func _popover() -> void:
	var anchor := GoStyle.button("슬롯")
	root.add_child(anchor)
	await frames(2)
	var body := GoStyle.label("불꽃의 검 — 공격력 +12")
	var first := GoPopover.open(anchor, body, {"title": "아이템"})
	await frames(3)
	check(first != null and GoPopover.is_open(), "팝오버: 열린다")
	check(first.placement == GoSurface.Placement.ANCHOR and first.anchor_control == anchor, "팝오버: 앵커에 붙는다")
	check(body.get_parent() == first.body, "팝오버: 내용이 들어간다")
	# 🔑 가림막은 투명하다 — 비교하려던 게임 화면이 어두워지면 안 된다.
	check(first.scrim_transparent, "팝오버: 가림막이 투명하다")
	# 🛑 한 번에 하나 — 쌓이면 어느 것이 어느 슬롯의 것인지 알 수 없다.
	var second := GoPopover.open(anchor, GoStyle.label("둘째"))
	await frames(3)
	check(second != null and not is_instance_valid(first), "팝오버: 한 번에 하나만")
	GoPopover.close()
	await frames(2)
	check(not GoPopover.is_open(), "팝오버: 닫힌다")
	anchor.queue_free()
	await frames(1)
	section("popover")


# ── 표 ─────────────────────────────────────────────────────────────────

func _table() -> void:
	var rows := [[3, "다다", 9124], [1, "가가", 91240], [2, "나나", 500]]
	var table := GoTable.make([{"text": "순위", "width": 56}, {"text": "이름"}, {"text": "점수", "numeric": true}], rows)
	root.add_child(table)
	await frames(3)
	check(table.rows_box.get_child_count() == 3, "표: 줄 셋")
	table.sort_by(2, false)
	await frames(2)
	var top := table.rows_box.get_child(0) as Button
	# 🛑 글자로 견주면 "9124" > "91240" 이다 — 점수 순위가 통째로 뒤집힌다.
	check(top != null and top.accessibility_name.contains("91240"), "표: 숫자 칸은 수로 정렬한다")
	var got := [-1]
	table.row_selected.connect(func(i: int) -> void: got[0] = i)
	top.pressed.emit()
	await frames(2)
	# 고른 줄의 번호는 **원래 데이터**의 번호다(정렬된 자리가 아니라).
	check(got[0] == 1, "표: 고른 줄은 원래 번호로 온다 (%d)" % got[0])
	table.sort_by(2, true)
	await frames(2)
	var first_asc := table.rows_box.get_child(0) as Button
	check(first_asc != null and first_asc.accessibility_name.contains("500"), "표: 방향을 바꾼다")
	# 🛑 **글자가 실제로 보이는 높이를 갖는가.** 줄바꿈이 켜진 채 폭 0 으로 첫 배치되면 최소 높이가
	#    1dp 로 굳어 화면에는 판만 남고 글자가 통째로 사라진다 — 값 검사는 전부 통과하면서.
	var cell_heights: Array[float] = []
	for node in _all(first_asc):
		if node is Label: cell_heights.append((node as Label).size.y)
	check(not cell_heights.is_empty() and cell_heights.min() > 4.0,
		"표: 칸 글자가 보이는 높이를 갖는다 (가장 낮은 칸 %.0f)" % (cell_heights.min() if not cell_heights.is_empty() else -1.0))
	table.queue_free()
	await frames(1)
	section("table")


# ── 쪽 넘기기 ──────────────────────────────────────────────────────────

func _pagination() -> void:
	var moved := [-1]
	var pager := GoPagination.make(1, 12, func(p: int) -> void: moved[0] = p)
	root.add_child(pager)
	await frames(2)
	pager.set_page(5)
	await frames(2)
	check(pager.page() == 5 and moved[0] == 5, "쪽넘김: 쪽을 옮긴다")
	var numbers := pager._numbers()
	# 🔑 지금 쪽이 가운데 오고 양끝이 남는다 — 어디였는지 놓치지 않게.
	check(numbers.has(1) and numbers.has(5) and numbers.has(12), "쪽넘김: 1 … 5 … 12 로 접는다 (%s)" % str(numbers))
	pager.set_page(99)
	await frames(1)
	check(pager.page() == 12, "쪽넘김: 끝을 넘지 않는다")
	# 🛑 쪽 수를 모르면 번호를 만들지 않는다 — 모르는 것을 아는 척하지 않는다.
	var endless := GoPagination.make(1, 0)
	root.add_child(endless)
	await frames(2)
	check(endless._numbers().is_empty(), "쪽넘김: 총 쪽을 모르면 번호가 없다")
	var more := GoPagination.more()
	root.add_child(more)
	await frames(2)
	check(more.get_child_count() == 1, "쪽넘김: 더보기는 한 줄")
	pager.queue_free(); endless.queue_free(); more.queue_free()
	await frames(1)
	section("pagination")


# ── 서랍 ───────────────────────────────────────────────────────────────

func _drawer() -> void:
	var drawer := GoDrawer.new()
	drawer.motion_seconds = 0.0
	root.add_child(drawer)
	await frames(2)
	drawer.open("가방")
	await frames(3)
	check(drawer.is_open() and drawer.visible, "서랍: 열린다")
	check(drawer.panel.size.x <= drawer.max_width + 1.0, "서랍: 폭 상한 (%.0f)" % drawer.panel.size.x)
	check(is_equal_approx(drawer.panel.position.x, 0.0), "서랍: 왼쪽에 붙는다")
	drawer.side = GoDrawer.Side.RIGHT
	drawer._relayout()
	await frames(2)
	var full := root.get_visible_rect()
	check(absf(drawer.panel.position.x + drawer.panel.size.x - full.size.x) < 2.0,
		"서랍: 오른쪽에 붙는다 (%.0f)" % (drawer.panel.position.x + drawer.panel.size.x))
	# 🛑 배경은 끝까지 가되 내용은 안전영역 안 — 모서리에서 잘리지 않게.
	check(is_equal_approx(drawer.panel.size.y, full.size.y), "서랍: 판은 화면 끝까지")
	drawer.close()
	await frames(2)
	check(not drawer.is_open(), "서랍: 닫힌다")
	drawer.queue_free()
	await frames(1)
	section("drawer")


# ── 찾아서 고르는 칸 ───────────────────────────────────────────────────

func _combobox() -> void:
	var items: Array = []
	for i in 30: items.append({"text": "플레이어%d" % i})
	var combo := GoCombobox.make(items, -1, "친구 찾기")
	root.add_child(combo)
	await frames(2)
	check(combo.text == "친구 찾기", "콤보: 안내 글자")
	combo.select(3)
	await frames(1)
	check(combo.selected() == 3 and combo.selected_text() == "플레이어3", "콤보: 고른다")
	combo._open()
	await frames(3)
	# 항목이 많으면 검색줄이 붙는다.
	check(combo._search != null, "콤보: 항목이 많으면 검색줄이 붙는다")
	combo._search.text = "플레이어1"
	combo._fill()
	await frames(2)
	# "플레이어1", "플레이어10"~"플레이어19" = 11개
	check(combo._rows.get_child_count() == 11, "콤보: 가운데 글자도 잡는다 (%d)" % combo._rows.get_child_count())
	combo._search.text = "없는이름"
	combo._fill()
	await frames(2)
	# 🛑 빈 목록을 그냥 두지 않는다 — 고장으로 읽힌다.
	check(combo._empty.visible, "콤보: 결과가 없으면 알려 준다")
	combo._close()
	await frames(1)
	var few := GoCombobox.make(["A", "B", "C"])
	root.add_child(few)
	await frames(2)
	few._open()
	await frames(2)
	check(few._search == null, "콤보: 항목이 적으면 검색줄이 없다")
	few._close()
	combo.queue_free(); few.queue_free()
	await frames(1)
	section("combobox")


# ── 출석 보상 달력 ─────────────────────────────────────────────────────

func _reward_calendar() -> void:
	var days: Array = []
	for i in 7: days.append({"icon": &"coin", "amount": (i + 1) * 100, "special": i == 6})
	var cal := GoRewardCalendar.make(days, 1)
	root.add_child(cal)
	await frames(3)
	check(cal._grid.get_child_count() == 7, "출석: 칸 일곱")
	check(cal.today() == 2, "출석: 오늘은 셋째 칸 (%d)" % cal.today())
	var cells := cal._grid.get_children()
	# 🛑 눌러도 아무 일이 없는 버튼은 고장으로 읽힌다 — 오늘 칸만 눌린다.
	check(not (cells[2] as Button).disabled, "출석: 오늘 칸은 눌린다")
	check((cells[0] as Button).disabled and (cells[6] as Button).disabled, "출석: 받은·앞으로 칸은 안 눌린다")
	# ♿ 흐림만으로는 받은 것과 앞으로 올 것이 구별되지 않는다.
	check((cells[0] as Button).accessibility_name != (cells[6] as Button).accessibility_name,
		"출석: 받음과 앞으로가 말로 구별된다")
	var got := [-1]
	cal.claimed.connect(func(d: int) -> void: got[0] = d)
	(cells[2] as Button).pressed.emit()
	await frames(2)
	check(got[0] == 2, "출석: 받기 신호")
	cal.set_claimed_until(6)
	await frames(2)
	check(cal.today() == -1, "출석: 다 받으면 오늘이 없다")
	cal.queue_free()
	await frames(1)
	section("reward calendar")


# ── 레이더·도넛 ────────────────────────────────────────────────────────

func _charts() -> void:
	var radar := GoRadar.make({"힘": 0.8, "민첩": 0.5, "지능": 0.3, "체력": 0.7, "행운": 0.4})
	root.add_child(radar)
	await frames(2)
	# ♿ 그림만으로는 읽히지 않는다.
	check(radar.accessibility_name.contains("힘 80%"), "레이더: 값이 말로 간다 (%s)" % radar.accessibility_name)
	radar.set_values({"힘": 0.1})
	await frames(1)
	check(radar.accessibility_name.contains("10%"), "레이더: 값을 바꾸면 따라간다")

	var donut := GoDonut.make([{"label": "물리", "value": 620}, {"label": "마법", "value": 340}, {"label": "관통", "value": 90}])
	root.add_child(donut)
	await frames(2)
	check(is_equal_approx(donut.total(), 1050.0), "도넛: 합계 (%.0f)" % donut.total())
	check(donut.accessibility_name.contains("물리 59%"), "도넛: 비율이 말로 간다 (%s)" % donut.accessibility_name)
	check(donut.legend().get_child_count() == 3, "도넛: 범례 세 줄")
	# 🔑 조각이 다섯을 넘으면 나머지를 묶는다 — 실처럼 가는 조각은 읽을 수 없다.
	var many: Array = []
	for i in 9: many.append({"label": "조각%d" % i, "value": 100 - i * 8})
	donut.set_slices(many)
	await frames(1)
	check(donut.visible_slices().size() == 5, "도넛: 다섯으로 접는다 (%d)" % donut.visible_slices().size())
	radar.queue_free(); donut.queue_free()
	await frames(1)
	section("radar · donut")


# ── 쿠폰 코드 ──────────────────────────────────────────────────────────

func _code_input() -> void:
	var coupon := GoCodeInput.make(12, 4)
	root.add_child(coupon)
	await frames(3)
	check(coupon._cells.size() == 12, "쿠폰: 칸 열둘")
	# 🛑 **폰 폭에 들어간다.** 12칸을 고정 폭으로 두면 720dp 화면에서 칸이 밖으로 잘렸다
	#    (2026-09-16 촬영). 좁으면 칸이 함께 좁아져야 한다.
	var need := coupon.cells_row.get_combined_minimum_size().x + float(GoUi.metric(GoTheme.SCREEN_MARGIN)) * 2.0
	check(need <= 720.0, "쿠폰: 720dp 폰 폭에 들어간다 (%.0f)" % need)
	var done := [""]
	coupon.completed.connect(func(c: String) -> void: done[0] = c)
	# 🛑 코드는 손으로 치는 것이 아니라 붙여넣는 것이다 — 하이픈·공백이 떨어지고 대문자가 된다.
	coupon.edit.text = "abcd-efgh ijkl"
	coupon._on_text("abcd-efgh ijkl")
	await frames(2)
	check(coupon.code() == "ABCDEFGHIJKL", "쿠폰: 붙여넣기를 정리한다 (%s)" % coupon.code())
	check(done[0] == "ABCDEFGHIJKL", "쿠폰: 다 차면 알린다")
	check(coupon.is_complete(), "쿠폰: 다 찼다")
	coupon.set_error("이미 쓴 코드입니다")
	await frames(2)
	check(coupon.has_error() and coupon.error_label.visible, "쿠폰: 오류가 뜬다")
	coupon.clear()
	await frames(1)
	check(coupon.code().is_empty(), "쿠폰: 비운다")
	# 받을 수 없는 글자는 들어오지 않는다.
	coupon._on_text("한글!@#AB")
	await frames(1)
	check(coupon.code() == "AB", "쿠폰: 받을 글자만 남긴다 (%s)" % coupon.code())
	coupon.queue_free()
	await frames(1)
	section("code input")


# ── 개발자 콘솔 ────────────────────────────────────────────────────────

func _console() -> void:
	var console := GoConsole.new()
	root.add_child(console)
	await frames(2)
	console.register("give", "아이템 지급", func(a: PackedStringArray) -> String: return "지급 %s" % " ".join(a))
	check(console.commands().has("give"), "콘솔: 명령을 등록한다")
	check(console.commands().has("help") and console.commands().has("clear"), "콘솔: 기본 명령이 있다")
	check(console.run("give sword 3") == "지급 sword 3", "콘솔: 명령을 실행한다")
	check(console.run("없는명령").contains("알 수 없는"), "콘솔: 모르는 명령을 알린다")
	console.unregister("give")
	check(not console.commands().has("give"), "콘솔: 명령을 뺀다")
	# 🛑 릴리스 빌드에서는 열리지 않는다 — 치트가 플레이어 손에 들어가면 안 된다.
	check(console.debug_only, "콘솔: 기본은 디버그 빌드 전용")
	console.queue_free()
	await frames(1)
	section("console")


# ── 넘겨 보는 띠 ───────────────────────────────────────────────────────

func _carousel() -> void:
	var carousel := GoCarousel.new()
	carousel.custom_minimum_size = Vector2(300, 120)
	root.add_child(carousel)
	await frames(2)
	carousel.set_pages([GoStyle.card(), GoStyle.card(), GoStyle.card()])
	await frames(3)
	check(carousel.pages().size() == 3, "띠: 쪽 셋")
	check(carousel._dots.get_child_count() == 3, "띠: 점 셋")
	# 🛑 보이는 점은 작아도 누르는 자리는 터치 하한이다.
	var dot := carousel._dots.get_child(0) as Control
	check(dot.custom_minimum_size.x >= float(GoUi.metric(GoTheme.TOUCH)) * 0.55, "띠: 점의 누르는 자리가 넉넉하다")
	carousel.next()
	await frames(2)
	check(carousel.index() == 1, "띠: 다음")
	carousel.go_to(0)
	await frames(1)
	carousel.previous()
	await frames(2)
	check(carousel.index() == 2, "띠: 처음에서 이전이면 끝으로 감긴다 (%d)" % carousel.index())
	# 🛑 저절로 넘어가면 읽을 시간을 뺏는다 — 기본은 꺼짐.
	check(not carousel.is_processing(), "띠: 자동 넘김은 기본 꺼짐")
	carousel.autoplay_seconds = 5.0
	await frames(1)
	# ♿ 움직임을 줄인 사람에게는 스스로 움직이지 않는다(지금 reduce_motion 이 켜져 있다).
	check(not carousel.is_processing(), "띠: reduce_motion 이면 자동 넘김을 하지 않는다")
	carousel.queue_free()
	await frames(1)
	section("carousel")


# ── 생김새를 바꾸면 따라오는가 ─────────────────────────────────────────

## 🛑 **이것이 이 파일에서 가장 중요한 검사다.** `GoUi.use_preset()` 은 "테마·스킨·아이콘이 함께
##    움직인다" 고 약속한다. 그런데 2026-09-16 이전에는 **새로 만든 위젯만** 바뀌었다 —
##    이미 떠 있는 HP 막대·퀵슬롯은 옛 색 그대로였고, 새것과 나란히 놓여 한 화면에 두 생김새가
##    섞였다. 위젯이 `GoUi.watch()` 를 등록하지 않으면 아무도 다시 읽지 않기 때문이다.
func _theme_follow() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(2)
	var bar := GoBar.new()
	var slot := GoSlot.new()
	var badge := GoBadge.make(3)
	root.add_child(bar); root.add_child(slot); root.add_child(badge)
	await frames(3)

	var before := {
		"bar": _fill_color(bar), "slot": _face_color(slot), "badge": _panel_color(badge),
	}
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	await frames(3)
	check(_fill_color(bar) != before["bar"], "생김새: 떠 있는 HP 막대가 따라온다")
	check(_face_color(slot) != before["slot"], "생김새: 떠 있는 퀵슬롯이 따라온다")
	check(_panel_color(badge) != before["badge"], "생김새: 떠 있는 배지가 따라온다")
	# 🛑 노드를 다시 만들지 않는다 — `Face` 가 사라지면 그 슬롯을 참조하던 코드가 전부 깨진다.
	check(slot.get_node_or_null(^"Face") != null, "생김새: 노드를 다시 만들지 않는다")

	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(2)
	bar.queue_free(); slot.queue_free(); badge.queue_free()
	await frames(1)
	section("theme follows")


# ── 거들기 ─────────────────────────────────────────────────────────────

func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all(child))
	return out


func _first_label(node: Node) -> String:
	for child in _all(node):
		if child is Label: return (child as Label).text
	return ""


func _fill_color(bar: GoBar) -> String:
	for node in _all(bar):
		if node is ProgressBar:
			var face: StyleBox = (node as ProgressBar).get_theme_stylebox(&"fill")
			if face != null: return "%s %s" % [face.get_class(), str(face.get(&"bg_color"))]
	return ""


func _face_color(slot: GoSlot) -> String:
	var face := slot.get_node_or_null(^"Face") as Panel
	if face == null: return ""
	var box: StyleBox = face.get_theme_stylebox(&"panel")
	return "%s %s" % [box.get_class(), str(box.get(&"bg_color"))] if box != null else ""


func _panel_color(node: PanelContainer) -> String:
	var box: StyleBox = node.get_theme_stylebox(&"panel")
	return "%s %s" % [box.get_class(), str(box.get(&"bg_color"))] if box != null else ""
