## 🍞 **스낵바 / 인라인 알림.** 새 메시지가 이전 것을 덮어쓰고, 시간이 지나면 사라진다.
##
## ## 🛑 절대 입력을 가로채지 않는다
## 알림은 **읽는 것**이지 누르는 것이 아니다. 포커스를 훔치지 않고, 게임 입력을 막지 않으며,
## 그 아래의 버튼이 그대로 눌린다. 확인이 필요하면 `GoDialogs`, 선택이 필요하면 `GoPromptCard` 다.
##
## ```gdscript
## var notice := GoNotice.new()
## hud.add_child(notice)
## notice.show_text("저장했습니다", GoTheme.SUCCESS)
## ```
##
## 배치(어느 모서리에 얼마나 크게)는 **소유한 화면**이 정한다 — 이 위젯은 색·여백·수명만 안다.
@tool
class_name GoNotice
extends PanelContainer

## 표시 시간이 끝났다.
signal expired

var label: Label
var _remaining := 0.0
var _key := ""
var _arguments := {}
var _content: Control


func _init() -> void:
	name = "Notice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 알림 안의 **무엇도** 입력·포커스를 받지 않는다 — Godot 4.5+ `*_behavior_recursive` 가 나중에 들어오는
	#    내용(`set_content`)까지 서브트리 전체를 한 번에 막는다. 노드마다 필터를 바꾸던 방식은
	#    나중에 추가된 자식을 빠뜨린다.
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label = GoStyle.label("")
	label.name = "Message"
	add_child(label)
	hide()
	set_process(false)


func _ready() -> void:
	theme = GoUi.theme()
	add_theme_stylebox_override(&"panel", _surface())
	set_process(_remaining > 0.0)


## 그대로 보여 줄 문구. `tone` 은 색 토큰 이름(`GoTheme.SUCCESS` 등).
func set_message(message: String, tone := GoTheme.TEXT) -> void:
	_drop_content()
	_key = ""
	_arguments.clear()
	label.text = message
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.show()
	GoStyle.typography(label, GoTheme.ROLE_BODY, GoUi.color(tone))
	add_theme_stylebox_override(&"panel", _surface(GoUi.color(tone)))


## 문구를 띄우고 `seconds` 뒤에 숨긴다. 음수면 토큰 `notice_duration_ms`.
func show_text(message: String, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	set_message(message, tone)
	_remaining = float(GoUi.metric(GoTheme.NOTICE_DURATION_MS)) / 1000.0 if seconds < 0.0 else seconds
	show()
	set_process(_remaining > 0.0)


## 번역 키로 띄운다. `arguments` 는 `{name}` 같은 자리를 채운다.
## 🛑 `tr()` 만으로는 자리표시자가 치환되지 않는다 — 번역문의 `{name}` 이 화면에 그대로 남는다.
func show_key(key: String, arguments := {}, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	show_text(tr(key).format(arguments), tone, seconds)
	_key = key
	_arguments = arguments.duplicate()


## 글자 대신 복합 내용(아이콘 + 줄 여러 개)을 담는다. 수명은 소유한 화면이 관리한다.
func set_content(content: Control, accent := Color.TRANSPARENT, compact := false) -> void:
	_key = ""
	_arguments.clear()
	_remaining = 0.0
	set_process(false)
	label.hide()
	_drop_content()
	_content = content
	add_child(content)
	var surface := GoStyle.box(GoTheme.BOX_NOTICE, accent)
	if compact: surface.set_content_margin_all(GoUi.metric(GoTheme.PADDING_COMPACT))
	add_theme_stylebox_override(&"panel", surface)
	show()


## 복합 내용의 강조색만 바꾼다 — 표면을 새로 만들지 않는다(다른 알림에 번지지 않게 사본을 고친다).
func set_accent(accent: Color) -> void:
	var surface := get_theme_stylebox(&"panel") as StyleBoxFlat
	if surface != null and accent.a > 0: surface.border_color = Color(accent, 0.55)


## 짧은 문구는 자연 폭, 긴 문구는 `limit` 안에서 줄바꿈한다.
func preferred_width(limit: float) -> float:
	if is_instance_valid(_content):
		return minf(limit, _content.get_combined_minimum_size().x + get_theme_stylebox(&"panel").get_minimum_size().x)
	var font := label.get_theme_font(&"font")
	if font == null: return limit
	var natural := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size(&"font_size")).x
	return minf(limit, natural + get_theme_stylebox(&"panel").get_minimum_size().x)


func _surface(accent := Color.TRANSPARENT) -> StyleBoxFlat:
	var surface := GoStyle.box(GoTheme.BOX_NOTICE, accent)
	surface.set_content_margin_all(GoUi.metric(GoTheme.PADDING_COMPACT))
	return surface


func _drop_content() -> void:
	if not is_instance_valid(_content): return
	remove_child(_content)
	_content.queue_free()
	_content = null


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0: return
	hide()
	set_process(false)
	expired.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and label != null and not _key.is_empty():
		label.text = tr(_key).format(_arguments)
