## 🎟 **쿠폰·기프트 코드 칸** — 칸이 나뉘어 있고, 붙여넣으면 알아서 흩어진다.
##
## ```gdscript
## var coupon := GoCodeInput.make(12, 4)          # 12자리를 4자씩 끊어
## coupon.completed.connect(func(code: String) -> void: server.redeem(code))
## sheet.body.add_child(coupon)
##
## coupon.set_error("이미 쓴 코드입니다")
## ```
##
## ## 🔑 게임에서 이것이 쓰이는 자리는 2단계 인증이 아니다
## 6자리 OTP 보다 **쿠폰·사전예약·기프트 코드**로 훨씬 자주 쓰인다. 그래서 기본이 12자리이고,
## 영문 대문자와 숫자를 받으며, 소문자를 쳐도 **대문자로 바뀐다** — 코드는 대개 대문자로 인쇄된다.
##
## ## 🛑 붙여넣기가 되어야 한다
## 코드는 손으로 치는 것이 아니라 **카카오톡·메일에서 복사해 오는 것**이다. 한 칸에 한 글자만 받는
## 칸을 만들면 붙여넣기가 첫 칸에서 잘린다 — 여기서는 붙여넣은 글을 칸에 흩뿌린다.
##
## ## 🛑 칸을 여럿 만들지 않는다
## `LineEdit` 을 열두 개 두면 포커스 이동·지우기·붙여넣기를 전부 손으로 다뤄야 하고, 한글 입력기가
## 끼면 칸 사이에서 글자가 사라진다. 여기서는 **보이지 않는 칸 하나**가 글을 받고, 칸은 **그려서**
## 보여 준다 — 입력기 문제가 원천적으로 없다.
@tool
class_name GoCodeInput
extends VBoxContainer

## 코드가 다 찼다.
signal completed(code: String)

## 한 글자라도 바뀌었다.
signal changed(code: String)

## 몇 자리인가.
@export var length := 12:
	set(value):
		length = maxi(1, value)
		_rebuild()

## 몇 자마다 끊어 보일 것인가. 0 이면 안 끊는다.
@export var group := 4:
	set(value):
		group = maxi(0, value)
		_rebuild()

## 받을 글자. 여기 없는 글자는 무시한다.
@export var allowed := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## 소문자를 대문자로 바꿀 것인가.
@export var uppercase := true

## 칸 하나의 최소 폭(dp). 음수면 글자 크기에서 잡는다.
@export var cell_width := -1.0

## 코드를 실제로 담는 **보이지 않는** 칸.
var edit: LineEdit
## 칸들이 그려지는 줄.
var cells_row: HBoxContainer
## 오류 줄.
var error_label: Label

var _cells: Array[PanelContainer] = []
## 칸 줄과 숨은 입력칸을 겹쳐 쌓는 칸(컨테이너가 아니라 `Control` 이라 둘이 같은 자리를 쓴다).
var _stack: Control
var _error := ""


func _init() -> void:
	name = "CodeInput"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))

	# 🛑 칸 줄과 숨은 입력칸을 **겹쳐 쌓는** 칸. `HBoxContainer` 에 직접 넣으면 컨테이너가 입력칸을
	#    한 열로 **밀어내** 칸들 위에 겹치지 못한다 — 그러면 칸을 아무리 눌러도 포커스가 가지 않아
	#    가상 키보드가 뜨지 않는다(2026-09-16 실측: edit 이 x=456 의 마지막 열에 놓였다).
	# 🛑 `Control` 은 자식의 최소 크기를 **물려받지 않는다** — 그대로 두면 이 칸이 0 으로 잡혀
	#    칸 줄과 입력칸이 함께 쪼그라든다. 칸 줄의 높이를 따라가게 묶고, 폭은 부모에서 받는다.
	_stack = Control.new()
	_stack.name = "Stack"
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_stack)

	cells_row = GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	cells_row.name = "Cells"
	cells_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# 🛑 코드는 **물리적 순서**다 — 아랍어에서도 왼쪽부터 찬다.
	cells_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	cells_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(cells_row)
	GoStyle.fit_content_height(_stack, cells_row)

	# 🔑 진짜 입력은 이 칸 하나가 받는다. 보이지는 않지만 **크기는 차지한다** — 그래야 탭으로 닿고
	#    가상 키보드가 뜬다. 칸들 위에 겹쳐 두어 아무 데나 눌러도 여기로 포커스가 온다.
	edit = LineEdit.new()
	edit.name = "Hidden"
	edit.max_length = length
	edit.flat = true
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	edit.add_theme_color_override(&"font_selected_color", Color(0, 0, 0, 0))
	edit.add_theme_color_override(&"caret_color", Color(0, 0, 0, 0))
	edit.text_changed.connect(_on_text)
	# 칸 줄 **위에** 덮는다 — 아무 데나 눌러도 이 칸으로 포커스가 온다.
	edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(edit)

	error_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.DANGER))
	error_label.name = "Error"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.visible = false
	add_child(error_label)


func _ready() -> void:
	_rebuild()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


static func make(digits := 12, group_size := 4) -> GoCodeInput:
	var node := GoCodeInput.new()
	node.length = digits
	node.group = group_size
	return node


## 지금 코드(빈 칸은 빠진 채로).
func code() -> String:
	return edit.text


## 코드를 채운다(딥링크로 받은 코드를 미리 넣을 때).
func set_code(value: String) -> void:
	edit.text = _clean(value)
	_paint()


func clear() -> void:
	edit.text = ""
	_paint()


## 다 찼는가.
func is_complete() -> bool:
	return edit.text.length() >= length


## 오류를 띄운다. 빈 글이면 지운다.
## 🛑 **칸도 함께 물들인다** — 아래 한 줄만 빨개지면 스크롤된 화면에서 안 보인다.
func set_error(message: String) -> void:
	_error = message
	error_label.text = message
	error_label.visible = not message.is_empty()
	_paint()


func has_error() -> bool:
	return not _error.is_empty()


func focus() -> void:
	edit.grab_focus()


func _on_text(raw: String) -> void:
	var cleaned := _clean(raw)
	if cleaned != raw:
		# 🛑 커서를 끝으로 돌려놓는다 — 안 그러면 걸러진 글자 수만큼 커서가 뒤로 밀린다.
		edit.text = cleaned
		edit.caret_column = cleaned.length()
	if not _error.is_empty(): set_error("")
	_paint()
	changed.emit(cleaned)
	if cleaned.length() >= length:
		edit.release_focus()
		GoFeedback.confirmed()
		completed.emit(cleaned)


## 받을 수 있는 글자만 남긴다. 🔑 붙여넣은 `ABCD-EFGH-IJKL` 의 하이픈·공백이 여기서 떨어진다.
func _clean(raw: String) -> String:
	var out := ""
	var source := raw.to_upper() if uppercase else raw
	for index in source.length():
		if out.length() >= length: break
		var glyph := source[index]
		if allowed.is_empty() or allowed.contains(glyph): out += glyph
	return out


func _rebuild() -> void:
	if cells_row == null: return
	# 🛑 `_cells` 만 지우면 끊는 자리의 **빈 칸(gap)** 이 남아 자릿수를 바꿀 때마다 쌓인다
	#    (2026-09-16 실측: 19 → 22 개로 늘었다). 줄을 통째로 비운다.
	for child in cells_row.get_children(): child.queue_free()
	_cells.clear()
	edit.max_length = length
	var side := cell_width if cell_width > 0.0 else float(GoUi.font_size(GoTheme.ROLE_SUBTITLE)) * 1.7
	for index in length:
		# 끊는 자리에 사이를 벌린다 — `ABCD EFGH IJKL` 이 한 덩어리 열두 자보다 훨씬 잘 읽힌다.
		if group > 0 and index > 0 and index % group == 0:
			var gap := Control.new()
			gap.name = "Gap%d" % index
			gap.custom_minimum_size.x = GoUi.metric(GoTheme.GAP_SMALL)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cells_row.add_child(gap)
		var cell := PanelContainer.new()
		cell.name = "Cell%d" % index
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 🛑 **폭은 최소만 잡고 남는 폭을 나눠 갖는다.** 12자리를 고정 폭으로 두면 720dp 폰에서
		#    669dp 가 되어 좌우 여백까지 더하면 칸이 화면 밖으로 잘렸다(2026-09-16 촬영).
		#    좁으면 칸이 함께 좁아지는 편이 잘리는 것보다 낫다.
		cell.custom_minimum_size = Vector2(minf(side, 28.0), side * 1.25)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := GoStyle.label("", GoTheme.ROLE_SUBTITLE)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		glyph.text_direction = Control.TEXT_DIRECTION_LTR
		# 한 글자짜리다 — 줄바꿈할 일이 없고, 켜 두면 좁은 칸에서 높이가 튄다.
		glyph.autowrap_mode = TextServer.AUTOWRAP_OFF
		# 🛑 **글자가 칸 폭을 정하게 두지 않는다.** `clip_text` 를 켜면 라벨의 최소 폭이 0 이 되어,
		#    글자가 든 칸과 빈 칸이 같은 폭으로 남는다(2026-09-16 촬영: 앞 칸만 넓어 들쭉날쭉했다).
		glyph.clip_text = true
		glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(glyph)
		_cells.append(cell)
		cells_row.add_child(cell)
	_paint()


func _paint() -> void:
	var value := edit.text
	for index in _cells.size():
		var cell := _cells[index]
		var glyph := cell.get_child(0) as Label
		if glyph != null: glyph.text = value[index] if index < value.length() else ""
		var filled := index < value.length()
		var here := index == value.length()
		var accent := GoUi.color(GoTheme.DANGER) if has_error() \
			else GoUi.color(GoTheme.ACCENT if here or filled else GoTheme.BORDER)
		cell.add_theme_stylebox_override(&"panel", GoUi.skin().slot_box(accent, here))
	# ♿ "몇 자 중 몇 자" — 칸 그림은 눈으로만 읽는 정보다. 🔑 「n / m」 형식은 이미 문구 키가 있다
	#    (터키어·프랑스어는 이 형식이 다르다 — 코드에 박으면 그 언어에서 어색해진다).
	# 🛑 여기서 `search` 를 쓰면 쿠폰 칸이 "검색 0 / 12" 로 읽힌다 — 무엇을 넣는 칸인지 부르는 쪽이
	#    안다. 라벨은 `GoField` 나 위 줄이 주고, 여기서는 **진행만** 말한다.
	var progress := GoUi.text(&"bar_fraction").format({"value": value.length(), "max": length})
	edit.accessibility_name = GoUi.spoken([_error, progress])


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _paint()
