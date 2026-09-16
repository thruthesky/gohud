## 🎁 **출석 보상 달력** — 며칠째 들어왔고, 오늘 무엇을 받고, 내일 무엇이 기다리는가.
##
## ```gdscript
## var attendance := GoRewardCalendar.make([
##     {"icon": &"coin",  "amount": 100},
##     {"icon": &"potion", "amount": 3},
##     {"icon": &"gem",   "amount": 5, "special": true},   # 7일차처럼 눈에 띄게
## ], 1)                                                    # 이틀째까지 받았다
## attendance.claimed.connect(func(day: int) -> void: server.claim_day(day))
## sheet.body.add_child(attendance)
## ```
##
## ## 🔑 이것은 날짜 고르개가 아니다
## 일반 달력(Date Picker)은 게임에서 거의 안 쓴다 — 생일을 묻는 화면 정도다. 게임에서 달력 모양이
## 쓰이는 자리는 **출석 보상**이고, 거기서 중요한 것은 "몇 월 며칠" 이 아니라 **몇 일째인가**다.
## 그래서 이 위젯은 날짜가 아니라 **차례**를 다룬다.
##
## ## 🛑 "오늘 받을 것" 이 한눈에 보여야 한다
## 칸이 스물여덟 개인데 어느 것이 오늘인지 안 보이면, 받을 수 있는 보상을 못 받고 나간다.
## 오늘 칸은 강조 테두리 + 누를 수 있는 상태이고, 지난 칸은 받음 표시, 앞으로 올 칸은 흐리다.
##
## ## 🛑 이미 받은 것을 다시 누르게 두지 않는다
## 서버가 거절할 것을 알면서 누르게 두면, 눌러도 아무 일이 없는 화면이 된다. 받은 칸은 눌리지 않는다.
##
## ## ♿ 색과 자리만으로 구별하지 않는다
## 받음·오늘·앞으로는 각각 **다른 표시**(체크 그림 · 강조 테두리 · 흐림)를 갖고, 스크린리더
## 이름에도 "받음" 이 들어간다.
@tool
class_name GoRewardCalendar
extends VBoxContainer

## 오늘 칸을 눌렀다. `day` 는 0부터.
signal claimed(day: int)

## 한 줄에 몇 칸.
@export var columns := 7:
	set(value):
		columns = maxi(1, value)
		_rebuild()

## 칸 한 변의 크기(dp). 음수면 터치 하한의 1.4배.
@export var cell_size := -1.0:
	set(value):
		cell_size = value
		_rebuild()

var _days: Array[Dictionary] = []
var _claimed_until := -1
var _grid: GridContainer


func _init() -> void:
	name = "RewardCalendar"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	_grid = GridContainer.new()
	_grid.name = "Days"
	_grid.columns = columns
	add_child(_grid)


func _ready() -> void:
	_rebuild()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 보상 목록과 **마지막으로 받은 날**(0부터, -1 이면 아직 하나도 안 받음)로 달력을 만든다.
##
## 각 날의 칸:
## | 칸 | 뜻 |
## |---|---|
## | `icon` | 보상 아이콘 이름 |
## | `amount` | 개수(0 이면 안 적는다) |
## | `label` | 아이콘 대신 쓸 글자 |
## | `special` | 크게·강조색으로(7일차·30일차) |
static func make(days: Array, claimed_until := -1) -> GoRewardCalendar:
	var node := GoRewardCalendar.new()
	node.set_days(days, claimed_until)
	return node


func set_days(days: Array, claimed_until := -1) -> void:
	_days.clear()
	for entry in days:
		var row: Dictionary = entry if entry is Dictionary else {"label": str(entry)}
		_days.append({
			"icon": StringName(row.get("icon", &"")),
			"amount": int(row.get("amount", 0)),
			"label": str(row.get("label", "")),
			"special": bool(row.get("special", false)),
		})
	_claimed_until = claimed_until
	_rebuild()


## 마지막으로 받은 날만 바꾼다(서버가 지급을 확인해 준 뒤).
func set_claimed_until(day: int) -> void:
	_claimed_until = day
	_rebuild()


## 오늘 받을 수 있는 칸의 번호(-1 이면 다 받았다).
func today() -> int:
	var next := _claimed_until + 1
	return next if next < _days.size() else -1


func _rebuild() -> void:
	if _grid == null: return
	_grid.columns = columns
	_grid.add_theme_constant_override(&"h_separation", GoUi.metric(GoTheme.GAP_SMALL))
	_grid.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP_SMALL))
	for child in _grid.get_children(): child.queue_free()
	var now := today()
	for index in _days.size():
		_grid.add_child(_cell(index, _days[index], now))


func _cell(index: int, day: Dictionary, now: int) -> Control:
	var taken := index <= _claimed_until
	var is_today := index == now
	var future := index > now and now >= 0

	var button := Button.new()
	button.name = "Day%d" % (index + 1)
	button.theme = GoUi.theme()
	button.theme_type_variation = GoTheme.VAR_BARE_BUTTON
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var side := cell_size if cell_size > 0.0 else float(GoUi.metric(GoTheme.TOUCH)) * 1.4
	button.custom_minimum_size = Vector2(side, side)
	# 🛑 받은 칸과 앞으로 올 칸은 **누를 수 없다** — 눌러도 아무 일이 없는 버튼은 고장으로 읽힌다.
	button.disabled = not is_today
	var accent := GoUi.color(GoTheme.ACCENT if day["special"] else GoTheme.BORDER)
	if is_today: accent = GoUi.color(GoTheme.ACCENT)
	button.add_theme_stylebox_override(&"normal", GoUi.skin().slot_box(accent, is_today))
	button.add_theme_stylebox_override(&"disabled", GoUi.skin().slot_box(
		GoUi.color(GoTheme.MUTED) if future else accent, false))

	var column := GoStyle.column(0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	# 「1일차」 — 숫자는 번역하지 않는다.
	var number := GoStyle.label(str(index + 1), GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	number.text_direction = Control.TEXT_DIRECTION_LTR
	column.add_child(number)

	var icon_name: StringName = day["icon"]
	if not icon_name.is_empty() and GoUi.icons().has_icon(icon_name):
		var px := roundi(side * 0.42)
		var glyph := GoUi.icons().node(icon_name, px,
			GoUi.color(GoTheme.ACCENT) if day["special"] else GoUi.color(GoTheme.TEXT))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(glyph)
		column.add_child(center)
	elif not str(day["label"]).is_empty():
		var words := GoStyle.label(str(day["label"]), GoTheme.ROLE_COMPACT)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		column.add_child(words)

	var amount := int(day["amount"])
	if amount > 0:
		var count := GoStyle.label(GoUi.text(&"slot_quantity").format({"count": amount}),
			GoTheme.ROLE_MICRO, GoUi.color(GoTheme.SECONDARY))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		count.text_direction = Control.TEXT_DIRECTION_LTR
		column.add_child(count)

	button.add_child(column)

	# ♿ 흐림·테두리만으로는 구별되지 않는다 — 상태를 말로도 준다.
	# 🛑 **무엇을 받는지도 읽혀야 한다.** 날짜와 상태만 주면 "3일차 받음" 뿐이라, 눈으로 못 보는
	#    사람은 오늘 무엇이 걸려 있는지 끝내 알 수 없다 — 받을지 말지를 정할 수가 없다.
	var state := GoUi.text(&"done") if taken else (GoUi.text(&"confirm") if is_today else GoUi.text(&"next"))
	var reward := str(day["label"])
	if reward.is_empty() and not icon_name.is_empty(): reward = String(icon_name)
	var many := GoUi.text(&"slot_quantity").format({"count": amount}) if amount > 0 else ""
	button.accessibility_name = GoUi.spoken([str(index + 1), reward, many, state])

	if taken:
		# 받은 칸에는 **그림 표시**를 얹는다 — 흐리게만 두면 앞으로 올 칸과 구별되지 않는다.
		button.modulate = Color(1, 1, 1, 0.55)
		if GoUi.icons().has_icon(&"check"):
			var mark := GoUi.icons().node(&"check", roundi(side * 0.34), GoUi.color(GoTheme.SUCCESS))
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.set_anchors_preset(Control.PRESET_CENTER)
			button.add_child(mark)
	elif future:
		button.modulate = Color(1, 1, 1, 0.7)

	if is_today:
		button.pressed.connect(func() -> void:
			GoFeedback.confirmed()
			claimed.emit(index))
	return button


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _rebuild()
