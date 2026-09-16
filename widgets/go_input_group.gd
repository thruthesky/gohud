## 🔗 **붙은 입력 묶음** — 입력칸과 그 옆 버튼을 **한 덩어리**로 보이게 한다.
##
## ```gdscript
## # 채팅 — 칸 + 보내기
## var chat := GoInputGroup.make(GoStyle.line_edit("메시지"), {"suffix": GoStyle.icon_button(&"send", send)})
##
## # 쿠폰 — 칸 + 확인
## var coupon := GoInputGroup.make(GoStyle.line_edit("코드"), {"suffix": GoStyle.button("확인", redeem)})
##
## # 검색 — 돋보기 + 칸
## var search := GoInputGroup.make(GoStyle.line_edit("이름"), {"prefix_icon": &"search"})
##
## # 수량 — − 칸 +
## var amount := GoInputGroup.make(field, {"prefix": minus_button, "suffix": plus_button})
## ```
##
## ## 🛑 이것이 푸는 문제는 **모서리**다
## 입력칸과 버튼을 `HBoxContainer` 에 그냥 나란히 놓으면 둥근 모서리 두 쌍이 가운데서 맞붙어
## 잘록해 보이고, 사이에 간격까지 벌어져 "따로 노는 두 물건" 이 된다. 여기서는 바깥 모서리만
## 둥글리고 **맞닿는 안쪽은 각지게** 만들어 한 덩어리로 읽히게 한다.
##
## ## 🔑 간격은 0 이다
## 일부러 붙인다. 떨어뜨리려면 이 위젯을 쓰지 말고 그냥 `GoStyle.row()` 에 나란히 둔다.
##
## ## 🛑 각진 스킨에서는 모서리를 건드리지 않는다
## sci-fi·medieval 처럼 **스킨이 직접 그리는 판**(`GoStyleBoxCut`·`GoStyleBoxBracket`)에는
## `corner_radius_*` 라는 칸이 아예 없다 — 둥근 모서리라는 개념이 없기 때문이다. 그때는 모서리를
## 손대지 않고 간격 0 만으로 붙인다. 각진 판끼리는 맞붙어도 잘록해 보이지 않으므로 그것으로 충분하다.
@tool
class_name GoInputGroup
extends HBoxContainer

## 가운데 입력칸.
var control: Control
## 앞(왼쪽)에 붙은 것 — 없으면 `null`.
var prefix: Control
## 뒤(오른쪽)에 붙은 것 — 없으면 `null`.
var suffix: Control


func _init() -> void:
	name = "InputGroup"
	# 🔑 **0 이 핵심이다** — 벌어지면 한 덩어리로 안 보인다.
	add_theme_constant_override(&"separation", 0)


func _ready() -> void:
	_restyle()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 입력칸 하나에 앞뒤를 붙여 묶음을 만든다.
##
## | 칸 | 뜻 |
## |---|---|
## | `prefix` | 왼쪽에 붙일 `Control`(버튼 등) |
## | `suffix` | 오른쪽에 붙일 `Control` |
## | `prefix_icon` | 왼쪽에 붙일 **아이콘만**(누를 수 없는 표식 — 돋보기·자물쇠) |
## | `suffix_icon` | 오른쪽에 붙일 아이콘만 |
static func make(node: Control, parts := {}) -> GoInputGroup:
	var group := GoInputGroup.new()
	var head: Control = parts.get("prefix")
	if head == null and parts.has("prefix_icon"): head = _mark(StringName(parts["prefix_icon"]))
	var tail: Control = parts.get("suffix")
	if tail == null and parts.has("suffix_icon"): tail = _mark(StringName(parts["suffix_icon"]))

	if head != null:
		group.prefix = head
		group.add_child(head)
	group.control = node
	if node != null:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_child(node)
	if tail != null:
		group.suffix = tail
		group.add_child(tail)
	return group


## 누를 수 없는 표식(돋보기·자물쇠) — 입력칸과 같은 판 위에 얹힌 아이콘 한 칸.
static func _mark(icon: StringName) -> Control:
	var box := PanelContainer.new()
	box.name = "Mark"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := GoUi.metric(GoTheme.ICON_SIZE)
	var glyph := GoUi.icons().node(icon, px, GoUi.color(GoTheme.MUTED))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := GoStyle.padding(GoUi.metric(GoTheme.COMPACT_PADDING_X), GoUi.metric(GoTheme.COMPACT_PADDING_Y))
	pad.add_child(glyph)
	box.add_child(pad)
	return box


## 맞닿는 모서리를 편다. 바깥쪽만 둥글고 안쪽은 각진다.
##
## 🛑 **상태마다 해야 한다** — `normal` 만 고치면 누르거나 포커스를 받는 순간 옛 둥근 모서리가
##    돌아와 덩어리가 순간 갈라진다. 버튼은 `normal`·`hover`·`pressed`·`disabled`·`focus` 를 쓴다.
func _restyle() -> void:
	var parts: Array[Control] = []
	for node in [prefix, control, suffix]:
		if is_instance_valid(node): parts.append(node)
	if parts.size() < 2: return
	var radius := float(GoUi.metric(GoTheme.RADIUS))
	for index in parts.size():
		var node := parts[index]
		var round_left := index == 0
		var round_right := index == parts.size() - 1
		for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"panel", &"read_only"]:
			if not node.has_theme_stylebox(state): continue
			var face := node.get_theme_stylebox(state).duplicate()
			if not (&"corner_radius_top_left" in face): continue
			face.set(&"corner_radius_top_left", radius if round_left else 0.0)
			face.set(&"corner_radius_bottom_left", radius if round_left else 0.0)
			face.set(&"corner_radius_top_right", radius if round_right else 0.0)
			face.set(&"corner_radius_bottom_right", radius if round_right else 0.0)
			node.add_theme_stylebox_override(state, face)


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", 0)
	# 테마가 바뀌면 모서리 크기도 바뀐다 — 덮어쓰기를 지우고 새 판으로 다시 편다.
	for node in [prefix, control, suffix]:
		if not is_instance_valid(node): continue
		for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"panel", &"read_only"]:
			node.remove_theme_stylebox_override(state)
	_restyle()
