## 🍞 **스낵바** — 화면 아래에서 잠깐 올라와 알리고, 되돌릴 버튼을 하나 얹을 수 있다.
##
## ```gdscript
## var snack := GoSnackbar.new()
## add_child(snack)
##
## snack.show_text("저장했습니다", GoTheme.SUCCESS)
## snack.show_text("서버에 연결하지 못했습니다", GoTheme.DANGER)
##
## # 되돌릴 기회를 준다 — 누르면 0, 시간이 지나 사라지면 -1
## if await snack.post({"text": "아이템을 버렸습니다", "actions": ["되돌리기"]}) == 0:
##     restore_item()
## ```
##
## ## 🔑 오토로드로 두면 편하다
## 게임 어디서나 쓰려면 Project Settings > Autoload 에 이 스크립트를 넣는다. 그러면
## `Snackbar.show_text(...)` 로 부를 수 있다. 애드온은 **자동으로 등록하지 않는다** —
## 프로젝트의 오토로드 목록은 프로젝트가 정한다.
##
## ## 🛑 `GoNotice` 와 무엇이 다른가
## | | `GoNotice` | `GoSnackbar` |
## |---|---|---|
## | 자리 | **화면이 정한다** — 어느 칸에 넣을지 호스트가 배치한다 | **스스로 잡는다** — 화면 아래, 안전영역·키보드 위 |
## | 층 | 넣어 준 부모와 같은 층 | 자기 `CanvasLayer`(HUD 위) |
## | 입력 | 🛑 **절대 안 받는다**(`focus_behavior_recursive` 가 꺼져 있다) | 버튼을 **누를 수 있다** |
## | 겹칠 때 | 새 메시지가 앞의 것을 덮어쓴다 | **차례로 줄을 선다** |
## | 쓰는 곳 | HUD 한 귀퉁이에 붙박이로 두는 알림 칸 | 조작에 대한 답 — 저장·삭제·오류·되돌리기 |
##
## 그래서 되돌릴 버튼이 필요하면 이쪽이다. `GoNotice` 는 버튼을 **구조적으로** 담을 수 없다.
##
## ## 🛑 확인을 받는 자리가 아니다
## 스낵바는 **스스로 사라진다** — 사용자가 못 볼 수도 있다는 뜻이다. 되돌릴 수 없는 조작의 승인,
## 반드시 읽어야 하는 오류는 `GoDialogs.confirm()`·`alert()` 로 묻는다. 여기 얹는 버튼은
## "안 눌러도 그만" 인 것만(되돌리기·자세히·다시 시도).
@tool
class_name GoSnackbar
extends Node

## 하나가 사라졌다. `index` 는 눌린 버튼(-1 = 시간이 다 됐거나 닫혔다).
signal closed(index: int)

## 어디에 뜰 것인가.
enum Placement {
	BOTTOM,  ## 화면 아래(기본) — 엄지가 닿는 자리라 되돌리기 버튼을 누르기 쉽다.
	TOP,     ## 화면 위 — 아래쪽이 조이스틱·퀵슬롯으로 꽉 찬 HUD 에서.
}

## 이 층에 뜬다. HUD 보다 위, 대화상자(`GoDialogs` 기본 100)보다 아래가 자연스럽다.
## 🛑 대화상자보다 위에 두면 확인 창을 스낵바가 가린다.
@export var layer_index := 90

## 카드의 최대 폭(dp). 넓은 화면에서 한 줄이 끝까지 늘어나면 눈이 글자를 따라가지 못한다.
@export var max_width := 560.0

## 화면 가장자리에서 띄우는 거리(dp). 음수면 `screen_margin` 토큰.
@export var margin := -1.0

## 위·아래 어디에 뜰 것인가.
@export var placement := Placement.BOTTOM

## 차례를 기다릴 수 있는 최대 개수. 넘치면 **가장 오래된 것부터** 버린다. 0 이면 무제한.
## 🛑 무제한으로 두지 않는다 — 초당 여러 번 실패하는 네트워크 코드가 몇 분치 알림을 쌓는다.
@export var queue_limit := 4

## 같은 글이 잇따라 오면 **하나로 친다**(끊긴 서버에 계속 붙는 코드가 같은 오류를 쏟아낸다).
## 지금 떠 있는 것과 글이 같으면 시간만 다시 채운다.
@export var merge_repeats := true

## 뜨고 사라지는 데 걸리는 시간(초). `GoConfig.reduce_motion` 이 켜져 있으면 무시하고 즉시 바뀐다.
@export var motion_seconds := 0.18

## 아래(위)에서 밀려 올라오는 거리(dp).
@export var slide_dp := 24.0

## 카드를 눌러서 닫을 수 있는가. 🔑 버튼이 없는 알림을 빨리 치우고 싶을 때.
## 🛑 버튼이 있는 스낵바에서는 눌러도 닫히지 않는다 — 되돌리기를 누르려다 닫아 버리면 안 된다.
@export var tap_to_dismiss := true

var _layer: CanvasLayer
var _root: Control
var _card: PanelContainer
var _row: HBoxContainer
var _glyph: Control
var _lines: VBoxContainer
var _title: Label
var _body: Label
var _actions: Array[Button] = []
var _close: GoIconButton

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _ticket: Ticket
var _remaining := 0.0
var _tween: Tween
var _shown := false


## 요청 하나의 **자기 차례 알림표**. 카드를 돌려 쓰므로 "누구에게 온 답인가" 를 이것으로 가른다.
## 🛑 신호 하나로는 안 된다 — `closed` 를 여럿이 함께 기다리면 모두 같은 답을 받는다.
class Ticket extends RefCounted:
	signal done(index: int)


## 🛑 카드는 `_init` 에서 만든다 — 트리에 붙기 전에 `show_text()` 를 부를 수 있어야 한다.
func _init() -> void:
	name = "Snackbar"
	_layer = CanvasLayer.new()
	_layer.name = "SnackbarLayer"
	_layer.layer = layer_index
	add_child(_layer)

	# 🛑 바탕은 입력을 **통째로 통과시킨다** — 스낵바가 떠 있는 동안 게임이 멈추면 안 된다.
	_root = Control.new()
	_root.name = "SnackbarRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 안전영역은 **물리적 방향**이다 — 아랍어라고 노치가 반대편으로 가지 않는다.
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_layer.add_child(_root)

	_card = PanelContainer.new()
	_card.name = "Snackbar"
	_card.visible = false
	_card.gui_input.connect(_card_input)
	# 🔑 뜬 뒤에 내용이 바뀌어도(언어 교체) 높이를 따라간다. `DEFERRED` 라 배치 도중에 끼어들지 않는다.
	_card.minimum_size_changed.connect(_refit, CONNECT_DEFERRED)
	_root.add_child(_card)

	var pad := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	pad.name = "Pad"
	_card.add_child(pad)

	_row = GoStyle.row()
	_row.name = "Row"
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	pad.add_child(_row)

	# 아이콘 자리 — 비어 있으면 숨는다.
	_glyph = Control.new()
	_glyph.name = "Glyph"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.visible = false
	_row.add_child(_glyph)

	_lines = GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	_lines.name = "Lines"
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_lines)

	_title = GoStyle.label("", GoTheme.ROLE_BUTTON)
	_title.name = "Title"
	_title.visible = false
	_lines.add_child(_title)

	_body = GoStyle.label("", GoTheme.ROLE_BODY)
	_body.name = "Message"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.add_child(_body)


func _ready() -> void:
	_layer.layer = layer_index
	_card.add_theme_stylebox_override(&"panel", _face(Color.TRANSPARENT))
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_on_ui_changed)
	set_process(false)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


# ── 띄우기 ─────────────────────────────────────────────────────────────

## 그대로 보여 줄 문구. `tone` 은 색 토큰 이름(`GoTheme.SUCCESS` 등).
## 음수 `seconds` 는 `notice_duration_ms` 토큰.
func show_text(message: String, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	await post({"text": message, "tone": tone, "seconds": seconds})


## 번역 키로 띄운다. `args` 는 `{name}` 같은 자리를 채운다.
## 🛑 `tr()` 만으로는 자리표시자가 치환되지 않는다 — 번역문의 `{name}` 이 화면에 그대로 남는다.
func show_key(key: String, args := {}, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	await post({"text": key, "translate": true, "args": args, "tone": tone, "seconds": seconds})


## 스낵바 하나를 띄우고, **눌린 버튼의 번호**를 돌려준다(-1 = 시간이 다 됐거나 닫혔다).
##
## | 칸 | 뜻 | 기본 |
## |---|---|---|
## | `text` | 본문. `translate` 면 번역 키 | `""` |
## | `title` | 굵은 첫 줄. 비우면 한 줄짜리 | `""` |
## | `tone` | 색 토큰(`GoTheme.DANGER` 등) | `GoTheme.TEXT` |
## | `icon` | 아이콘 세트의 이름 | 없음 |
## | `actions` | 버튼들 — 글자(`String`)나 `{"text":…, "action": Callable}` | 없음 |
## | `closable` | 닫기(×) 버튼을 붙인다 | `false` |
## | `seconds` | 수명. 음수면 토큰, `0` 이면 **안 사라진다**(버튼을 눌러야 닫힌다) | `-1` |
## | `translate` | `text`·`title`·버튼 글자를 번역 키로 본다 | `false` |
## | `args` | 자리표시자 값 | `{}` |
##
## 🛑 `seconds: 0` 은 **버튼이 있을 때만** 쓴다 — 닫을 방법이 없으면 화면에 영원히 남는다.
func post(options: Dictionary) -> int:
	var item := _normalize(options)
	# 같은 글이 잇따르면 하나로 친다 — 시간만 다시 채우고 새로 줄 세우지 않는다.
	if merge_repeats and _shown and not _current.is_empty() \
			and _current.get("text", "") == item["text"] and _current.get("title", "") == item["title"]:
		_remaining = float(item["seconds"])
		set_process(_remaining > 0.0)
		return -1
	var ticket: Ticket = item["ticket"]
	if not _shown:
		_present(item)
		return await ticket.done
	_queue.append(item)
	# 🛑 넘치면 **가장 오래된 것**을 버린다 — 방금 일어난 일이 대개 더 중요하다.
	while queue_limit > 0 and _queue.size() > queue_limit:
		var dropped: Dictionary = _queue.pop_front()
		(dropped["ticket"] as Ticket).done.emit(-1)
	return await ticket.done


## 지금 떠 있는 것을 곧바로 치운다. 기다리는 것이 있으면 다음이 올라온다.
func dismiss() -> void:
	if _shown: _finish(-1)


## 떠 있는 것과 기다리는 것을 **전부** 치운다. 화면을 떠날 때(로그아웃·씬 전환) 부른다.
## 🛑 `await` 로 붙잡힌 코드는 이것을 부르지 않으면 영영 돌아오지 않는다.
func clear() -> void:
	var waiting := _queue
	_queue = []
	for item in waiting: (item["ticket"] as Ticket).done.emit(-1)
	dismiss()


func is_showing() -> bool:
	return _shown


## 차례를 기다리는 개수(지금 떠 있는 것은 빼고).
func pending() -> int:
	return _queue.size()


# ── 조립 ───────────────────────────────────────────────────────────────

## 넘어온 칸을 채워 **빠진 것이 없는** 한 벌로 만든다.
func _normalize(options: Dictionary) -> Dictionary:
	var seconds := float(options.get("seconds", -1.0))
	if seconds < 0.0: seconds = float(GoUi.metric(GoTheme.NOTICE_DURATION_MS)) / 1000.0
	var actions: Array = []
	for entry in options.get("actions", []):
		if entry is String or entry is StringName: actions.append({"text": String(entry), "action": Callable()})
		elif entry is Dictionary: actions.append({"text": str(entry.get("text", "")), "action": entry.get("action", Callable())})
	return {
		"text": str(options.get("text", "")),
		"title": str(options.get("title", "")),
		"tone": options.get("tone", GoTheme.TEXT),
		"icon": StringName(options.get("icon", &"")),
		"actions": actions,
		"closable": bool(options.get("closable", false)),
		"seconds": seconds,
		"translate": bool(options.get("translate", false)),
		"args": (options.get("args", {}) as Dictionary).duplicate(),
		"ticket": Ticket.new(),
	}


## 한 벌을 실제 카드에 입히고 올린다.
func _present(item: Dictionary) -> void:
	_current = item
	_ticket = item["ticket"]
	_shown = true

	var ink := GoUi.color(item["tone"])
	_card.add_theme_stylebox_override(&"panel", _face(ink if item["tone"] != GoTheme.TEXT else Color.TRANSPARENT))
	_retranslate()

	# 아이콘 — 세트가 그 이름을 모르면 조용히 자리를 비운다(자홍색 네모를 띄우지 않는다).
	for child in _glyph.get_children(): child.queue_free()
	var icon_name: StringName = item["icon"]
	# 🛑 `node()` 는 모르는 이름에도 **빈 칸**을 돌려준다(null 이 아니다) — 그대로 넣으면 아이콘
	#    없는 스낵바에 빈 자리만 생긴다. 세트가 아는 이름일 때만 자리를 만든다.
	_glyph.visible = not icon_name.is_empty() and GoUi.icons().has_icon(icon_name)
	if _glyph.visible:
		var px := GoUi.metric(GoTheme.ICON_SIZE)
		var node := GoUi.icons().node(icon_name, px, ink)
		_glyph.custom_minimum_size = Vector2(px, px)
		_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.add_child(node)

	_build_actions(item)

	# 🔑 버튼이 없는 순수 알림은 **입력을 통과시킨다** — 스낵바가 떠 있다고 그 아래 조작이 막히면 안 된다.
	var interactive: bool = not _actions.is_empty() or item["closable"] or tap_to_dismiss
	_card.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

	# ♿ 스크린리더는 카드 하나를 한 덩어리로 읽는다 — 제목과 본문을 이어 붙여 이름으로 준다.
	var spoken_title: String = item["title"]
	var spoken_body: String = item["text"]
	_card.accessibility_name = ("%s %s" % [spoken_title, spoken_body]).strip_edges()

	_remaining = float(item["seconds"])
	# 🛑 **한 프레임 숨긴 채로** 띄운다. 줄바꿈하는 본문의 최소 높이는 폭이 정해진 **다음**
	#    프레임에야 맞는 값이 된다 — 같은 프레임에 재면 처음 폭(0)으로 글자가 한 자씩 접힌
	#    높이가 나와 카드가 네 배로 커진다(2026-09-16 실측: 55 여야 할 카드가 211 이었다).
	_card.modulate.a = 0.0
	_card.visible = true
	_relayout()
	set_process(_remaining > 0.0)
	_settle()
	GoFeedback.opened()


## 폭이 자식에게 퍼지기를 **실제로 기다렸다가** 자리를 잡고, 그제서야 올린다.
##
## 🛑 `call_deferred` 로는 모자란다 — 그것은 같은 프레임 끝에 불리고, 그때 최소 높이는 아직
##    **처음 폭(0)으로 접힌 값**이다(2026-09-16 실측: 그 순간 `min=(33, 211)`, 참값은 55).
##    `size.y = 0` 을 줘도 엔진이 그 211 로 끌어올리므로 큰 카드가 그대로 굳는다.
##    프레임을 실제로 넘겨 최소 높이가 새 폭으로 다시 계산된 뒤에 재야 한다.
## 🔑 기다리는 동안 카드는 `modulate.a = 0` 이라 **잘못된 크기가 화면에 보이지 않는다.**
func _settle() -> void:
	var tree := get_tree()
	if tree == null:
		_animate(true)
		return
	await tree.process_frame
	await tree.process_frame
	if not _shown or not is_instance_valid(_card): return
	_relayout()
	_animate(true)


## 버튼 줄을 다시 짓는다. 🛑 **돌려 쓰지 않는다** — 앞 스낵바의 콜백이 남으면 엉뚱한 것이 되돌려진다.
func _build_actions(item: Dictionary) -> void:
	for node in _actions: node.queue_free()
	_actions.clear()
	if is_instance_valid(_close):
		_close.queue_free()
		_close = null

	var entries: Array = item["actions"]
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var picked := index
		var node := GoStyle.button(str(entry["text"]), func() -> void:
			var action: Callable = entry["action"]
			if action.is_valid(): action.call()
			_finish(picked), GoStyle.Tone.BARE)
		node.name = "Action%d" % index
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# 되돌리기 글자는 tone 색으로 — 본문과 구별되어 "누를 수 있는 것" 으로 읽힌다.
		node.add_theme_color_override(&"font_color", GoUi.color(GoTheme.ACCENT))
		_actions.append(node)
		_row.add_child(node)

	if item["closable"]:
		_close = GoIconButton.new()
		_close.name = "Close"
		_close.icon_name = &"close"
		_close.tooltip_text_name = &"close"
		_close.pressed.connect(func() -> void: _finish(-1))
		_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(_close)


## 지금 글자를 다시 채운다(언어가 바뀌어도 같은 길로 온다).
func _retranslate() -> void:
	if _current.is_empty(): return
	var translate: bool = _current["translate"]
	var args: Dictionary = _current["args"]
	var title: String = _current["title"]
	_title.visible = not title.is_empty()
	if _title.visible:
		_title.text = tr(title).format(args) if translate else (title.format(args) if not args.is_empty() else title)
		_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var body: String = _current["text"]
	_body.text = tr(body).format(args) if translate else (body.format(args) if not args.is_empty() else body)
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var ink := GoUi.color(_current["tone"])
	GoStyle.typography(_body, GoTheme.ROLE_BODY, ink)
	if _title.visible: GoStyle.typography(_title, GoTheme.ROLE_BUTTON, ink)
	# 버튼 글자도 번역 키일 수 있다.
	var entries: Array = _current["actions"]
	for index in mini(_actions.size(), entries.size()):
		var text := str((entries[index] as Dictionary)["text"])
		_actions[index].text = tr(text) if translate else text


# ── 자리 잡기 ──────────────────────────────────────────────────────────

## 안전영역·가상 키보드 위로, 정해진 폭 안에서 가운데에 놓는다.
func _relayout() -> void:
	if _card == null or not _card.visible or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	var runtime := GoUi.runtime()
	var keyboard: int = runtime.keyboard_height() if runtime != null and runtime.has_method(&"keyboard_height") else 0
	var area := GoSafeArea.usable_rect_with_keyboard(window, keyboard)
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN)) if margin < 0.0 else margin

	var limit := maxf(0.0, area.size.x - edge * 2.0)
	var width := minf(limit, max_width) if max_width > 0.0 else limit
	# 🛑 높이는 **재지 않고 0 을 준다** — 엔진이 그 자리에서 최소 높이로 끌어올린다.
	#    직접 잰 값을 넣으면 그때 폭이 아직 0 이라 글자가 한 자씩 접힌 높이가 박히고, 폭이
	#    자리 잡아 최소 높이가 줄어든 뒤에도 **그 큰 값이 그대로 남는다**(`size` 는 최소보다
	#    크면 유지된다 — 2026-09-16 실측: 55 여야 할 카드가 여덟 프레임 내내 211 이었다).
	_card.size.x = width
	_card.size.y = 0.0

	var x := area.position.x + (area.size.x - width) * 0.5
	var y := area.end.y - edge - _card.size.y if placement == Placement.BOTTOM else area.position.y + edge
	# 🛑 정수 — 소수 위치는 카드 크기를 183.99997 로 만들어 본문 칸 1px 를 잃는다.
	_card.position = Vector2(x, y).round()


## 내용이 바뀌어 최소 높이가 달라졌다 — 자리를 다시 잡는다.
## 🛑 올라오는 중에는 건드리지 않는다 — `position` 을 tween 이 잡고 있어 서로 밀어낸다.
func _refit() -> void:
	if not _shown or is_instance_valid(_tween) and _tween.is_valid() and _tween.is_running(): return
	_relayout()


func _face(accent: Color) -> StyleBox:
	return GoUi.skin().notice_box(accent, true)


## 올라오고 내려가는 움직임. `reduce_motion` 이면 그 자리에서 나타나고 사라진다.
func _animate(shown: bool) -> void:
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	var rest := _card.position
	if GoUi.config.reduce_motion or motion_seconds <= 0.0 or not is_inside_tree():
		_card.modulate.a = 1.0 if shown else 0.0
		if not shown: _card.visible = false
		return
	var away := rest + Vector2(0.0, slide_dp if placement == Placement.BOTTOM else -slide_dp)
	_tween = create_tween().set_parallel(true)
	if shown:
		_card.position = away
		_card.modulate.a = 0.0
		_tween.tween_property(_card, "position", rest, motion_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_card, "modulate:a", 1.0, motion_seconds)
	else:
		_tween.tween_property(_card, "position", away, motion_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_card, "modulate:a", 0.0, motion_seconds)
		_tween.chain().tween_callback(func() -> void: _card.visible = false)


# ── 끝내기 ─────────────────────────────────────────────────────────────

func _finish(index: int) -> void:
	if not _shown: return
	_shown = false
	set_process(false)
	_animate(false)
	if index >= 0: GoFeedback.tapped()
	else: GoFeedback.closed()
	var ticket := _ticket
	_ticket = null
	_current = {}
	closed.emit(index)
	if ticket != null: ticket.done.emit(index)
	# 다음 차례 — 내려가는 움직임이 끝난 뒤에 올린다. 같은 프레임에 열면 글자만 바뀌어 보인다.
	if _queue.is_empty(): return
	var delay := 0.0 if GoUi.config.reduce_motion else motion_seconds
	get_tree().create_timer(delay).timeout.connect(_pump, CONNECT_ONE_SHOT)


## 카드를 눌러서 닫는다. 🛑 **버튼이 있으면 닫지 않는다** — 되돌리기를 누르려다 빗맞으면
##    되돌릴 기회가 사라진다. 버튼 자신이 받은 입력은 여기까지 오지 않는다.
func _card_input(event: InputEvent) -> void:
	if not tap_to_dismiss or not _actions.is_empty(): return
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not tapped: return
	_card.accept_event()
	_finish(-1)


func _pump() -> void:
	if _shown or _queue.is_empty(): return
	_present(_queue.pop_front())


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_remaining -= delta
	if _remaining > 0.0: return
	_finish(-1)


func _on_ui_changed() -> void:
	if _current.is_empty():
		_card.add_theme_stylebox_override(&"panel", _face(Color.TRANSPARENT))
		return
	var ink := GoUi.color(_current["tone"])
	_card.add_theme_stylebox_override(&"panel", _face(ink if _current["tone"] != GoTheme.TEXT else Color.TRANSPARENT))
	_retranslate()
	_relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()
