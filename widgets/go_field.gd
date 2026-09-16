## 🏷 **폼 한 줄** — 라벨 · 입력칸 · 설명 · 오류를 한 덩어리로 묶는다.
##
## ```gdscript
## var name_field := GoField.make("캐릭터 이름", GoStyle.line_edit("2~12자"), "나중에 바꿀 수 없습니다")
## form.add_child(name_field)
##
## # 서버가 거절했다
## name_field.set_error("이미 쓰고 있는 이름입니다")
## # 고쳐졌다
## name_field.clear_error()
## ```
##
## ## 🛑 오류는 **그 칸 옆에** 붙어야 한다
## 폼 맨 위에 "입력을 확인하세요" 한 줄만 띄우면, 칸이 다섯 개일 때 어느 것이 틀렸는지 알 수 없다.
## 회원가입에서 이 한 가지가 이탈을 만든다. 그래서 오류는 **틀린 칸 바로 아래**에 뜨고,
## 그 칸의 테두리도 함께 위험색이 된다.
##
## ## ♿ 색만으로 알리지 않는다
## 빨간 테두리만으로는 색각 이상인 사람에게 **아무 변화가 없다.** 그래서 오류는 언제나
## **글자로도** 뜨고(`error_label`), 스크린리더가 읽을 이름에도 들어간다.
##
## ## 🔑 설명과 오류는 자리를 다투지 않는다
## 오류가 뜨면 설명은 숨는다 — 둘을 함께 쌓으면 줄이 갑자기 두 줄 늘어 아래 칸이 전부 밀린다.
## 오류가 사라지면 설명이 돌아온다.
@tool
class_name GoField
extends VBoxContainer

## 오류가 생기거나 사라졌다.
signal error_changed(message: String)

## 라벨 줄.
var label: Label
## 감싸고 있는 입력칸(`line_edit`·`select`·무엇이든 `Control`).
var control: Control
## 설명 줄 — 오류가 없을 때만 보인다.
var hint_label: Label
## 오류 줄 — 오류가 있을 때만 보인다.
var error_label: Label

var _error := ""
var _label_key := ""
var _hint_key := ""
var _error_key := ""
var _translate := false
## 오류를 씌우기 전 입력칸의 테두리 — 지울 때 그대로 되돌린다.
var _plain_face: StyleBox


func _init() -> void:
	name = "Field"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))

	label = GoStyle.label("", GoTheme.ROLE_CAPTION)
	label.name = "Label"
	add_child(label)

	hint_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	hint_label.name = "Hint"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = false
	add_child(hint_label)

	error_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.DANGER))
	error_label.name = "Error"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	add_child(error_label)


func _ready() -> void:
	_retranslate()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 라벨 · 입력칸 · 설명으로 한 줄을 만든다.
## `translate` 를 켜면 세 글자를 모두 **번역 키**로 본다.
static func make(label_text: String, node: Control, hint := "", translate := false) -> GoField:
	var field := GoField.new()
	field._translate = translate
	field._label_key = label_text
	field._hint_key = hint
	field.set_control(node)
	field._retranslate()
	return field


## 입력칸을 넣는다(이미 있으면 갈아 끼운다). 라벨 **바로 아래**, 설명 위에 들어간다.
func set_control(node: Control) -> void:
	if is_instance_valid(control):
		remove_child(control)
		control.queue_free()
	control = node
	_plain_face = null
	if not is_instance_valid(node): return
	add_child(node)
	# 라벨 → 입력칸 → 설명 → 오류 차례로.
	move_child(node, 1)
	# ♿ 스크린리더가 "무엇을 입력하는 칸인지" 를 알아야 한다 — 라벨은 눈으로만 읽는 정보가 아니다.
	_sync_accessibility()


## 오류를 띄운다. 빈 글이면 `clear_error()` 와 같다.
## 🔑 `translate` 를 켜면 **번역 키**로 본다 — 서버가 준 코드(`err_name_taken`)를 그대로 넘길 수 있다.
func set_error(message: String, translate := false) -> void:
	_error_key = message
	if not message.is_empty(): _translate = _translate or translate
	_error = message
	# 🛑 **글자를 먼저 채운다.** `_apply_error()` 가 접근성 이름을 이 글에서 만들므로, 순서가
	#    바뀌면 스크린리더에 옛 오류(또는 빈 글)가 실린다 — 눈으로는 멀쩡해 보여 놓치기 쉽다.
	error_label.text = tr(_error_key) if _translate else _error_key
	error_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_apply_error()
	error_changed.emit(message)


func clear_error() -> void:
	set_error("")


func has_error() -> bool:
	return not _error.is_empty()


## 지금 오류 글(번역된 것).
func error_text() -> String:
	return error_label.text


func _apply_error() -> void:
	var shown := not _error.is_empty()
	error_label.visible = shown
	# 🔑 설명과 오류는 자리를 다투지 않는다 — 둘이 함께 쌓이면 줄이 두 칸 늘어 아래가 전부 밀린다.
	hint_label.visible = not shown and not hint_label.text.is_empty()
	_paint_control(shown)
	_sync_accessibility()


## 입력칸 테두리를 위험색으로 물들이거나 되돌린다.
## 🛑 **색만 바꾼다** — 테두리 굵기까지 바꾸면 칸 크기가 1dp 달라져 줄 전체가 흔들린다.
func _paint_control(bad: bool) -> void:
	if not is_instance_valid(control): return
	for state in [&"normal", &"focus"]:
		if not control.has_theme_stylebox(state): continue
		if not bad:
			control.remove_theme_stylebox_override(state)
			continue
		var face := control.get_theme_stylebox(state).duplicate()
		if &"border_color" in face: face.set(&"border_color", GoUi.color(GoTheme.DANGER))
		control.add_theme_stylebox_override(state, face)


## ♿ 라벨·설명·오류를 **한 문장으로 묶어** 입력칸에 준다. 스크린리더는 칸에 들어갈 때 이것을 읽는다.
func _sync_accessibility() -> void:
	if not is_instance_valid(control): return
	var parts: Array[String] = [label.text]
	if error_label.visible: parts.append(error_label.text)
	elif hint_label.visible: parts.append(hint_label.text)
	control.accessibility_name = GoUi.spoken(parts)


func _retranslate() -> void:
	label.text = tr(_label_key) if _translate else _label_key
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hint_label.text = tr(_hint_key) if _translate else _hint_key
	hint_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	error_label.text = tr(_error_key) if _translate else _error_key
	error_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.visible = not label.text.is_empty()
	_apply_error()


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	GoStyle.typography(label, GoTheme.ROLE_CAPTION)
	GoStyle.typography(hint_label, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	GoStyle.typography(error_label, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.DANGER))
	_apply_error()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()
