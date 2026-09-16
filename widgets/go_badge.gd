## 🔴 **배지** — 우편함의 빨간 점, 상점의 NEW, 친구 요청 개수.
##
## ```gdscript
## # 아이콘 버튼 모서리에 붙인다 — 0 이면 저절로 숨는다
## GoBadge.attach(mail_button, unread_count)
## GoBadge.attach(shop_button, 0, "NEW")        # 숫자 대신 글자
## GoBadge.attach(friend_button, 3, "", true)   # 점만 — 개수를 숨기고 "뭔가 있다" 만
##
## # 줄 안에 직접 놓는 배지
## row.add_child(GoBadge.make(12))
## ```
##
## ## 🔑 개수와 점 중 무엇을 쓰나
## **개수가 행동을 바꾸면** 숫자다(편지 3통과 30통은 다르게 움직인다). **"새 것이 있다" 만
## 중요하면** 점이다(상점에 신상품). 숫자를 쓸 데에 점을 쓰면 정보가 사라지고, 점을 쓸 데에
## 숫자를 쓰면 화면이 시끄러워진다.
##
## ## 🛑 큰 수는 접는다
## `99+` 로 접지 않으면 "1284" 가 아이콘보다 넓어져 HUD 줄이 밀린다. 접는 자리는 `cap` 으로 바꾼다.
##
## ## 🛑 색만으로 알리지 않는다
## 빨간 점 하나로만 구별되면 색각 이상인 사람에게는 **아무 변화가 없다.** 그래서 배지는
## 스크린리더 이름을 갖고(`accessibility_name`), 개수를 글자로도 읽을 수 있게 둔다.
@tool
class_name GoBadge
extends PanelContainer

## 이 수를 넘으면 `99+` 처럼 접는다. 0 이면 접지 않는다.
@export var cap := 99:
	set(value):
		cap = maxi(0, value)
		_refresh()

## 숫자 대신 보여 줄 글자(`NEW`·`!`). 비우면 숫자를 쓴다.
@export var label_text := "":
	set(value):
		label_text = value
		_refresh()

## 개수를 숨기고 **점만** 보여 준다.
@export var dot := false:
	set(value):
		dot = value
		_refresh()

## 배지 색. 비우면 테마 위험색(빨강) — 눈이 가장 먼저 가는 자리다.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		_refresh()

## 0 일 때 스스로 숨을 것인가. 🛑 꺼 두면 `0` 이 적힌 배지가 남는다.
@export var hide_when_zero := true:
	set(value):
		hide_when_zero = value
		_refresh()

var _count := 0
var _label: Label


func _init() -> void:
	name = "Badge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 숫자는 언어를 따라 좌우가 뒤집히지 않는다.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label = Label.new()
	_label.name = "Count"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.text_direction = Control.TEXT_DIRECTION_LTR
	add_child(_label)


func _ready() -> void:
	theme = GoUi.theme()
	_refresh()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 보여 줄 개수. 0 이면(그리고 `hide_when_zero` 면) 숨는다.
func set_count(value: int) -> void:
	_count = maxi(0, value)
	_refresh()


func count() -> int:
	return _count


func _refresh() -> void:
	if not is_instance_valid(_label): return
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.DANGER)
	var words := label_text
	if words.is_empty() and not dot:
		words = "%d+" % cap if cap > 0 and _count > cap else str(_count)

	visible = not (hide_when_zero and _count <= 0 and label_text.is_empty())
	_label.visible = not dot
	_label.text = "" if dot else words
	GoStyle.typography(_label, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.ON_ACCENT))
	_label.add_theme_color_override(&"font_color", _on_badge(color))
	add_theme_stylebox_override(&"panel", GoUi.skin().badge_box(color))

	# 점은 지름이 정해진 동그라미다 — 글자가 없으니 최소 크기를 직접 준다.
	if dot:
		var px := maxf(6.0, float(GoUi.metric(GoTheme.GAP_SMALL)))
		custom_minimum_size = Vector2(px, px)
	else:
		# 한 자리 수도 동그랗게 — 폭이 높이보다 작으면 찌그러진 알약으로 보인다.
		var box := _label.get_combined_minimum_size()
		var side := maxf(box.y, box.x)
		custom_minimum_size = Vector2(side, box.y)

	# ♿ 색과 자리만으로는 읽히지 않는다 — 무엇이 몇 개인지 말로도 준다.
	# 🛑 점 모드에서 `empty` 를 쓰면 **뜻이 정반대로** 읽힌다 — "새 것이 있다" 는 표시가
	#    "여기 아무것도 없습니다" 가 된다(2026-09-16 실측). 점은 개수를 감춘 것이지 없는 것이 아니다.
	if not words.is_empty(): accessibility_name = words
	elif dot: accessibility_name = GoUi.spoken([str(_count)]) if _count > 0 else ""
	else: accessibility_name = ""


## 배지 판 위에서 읽히는 글자색.
## 🛑 `ON_ACCENT` 를 그대로 쓰지 않는다 — 노란 경고 배지 위의 흰 글자는 2:1 도 안 나온다.
##    둘 중 **대비가 큰 쪽**을 고른다. 판을 어떻게 칠할지는 스킨이 정하므로 색을 박아 둘 수 없다.
func _on_badge(background: Color) -> Color:
	var light := GoUi.color(GoTheme.ON_ACCENT)
	var dark := GoUi.color(GoTheme.BACKGROUND)
	return light if GoSkin.contrast_ratio(light, background) >= GoSkin.contrast_ratio(dark, background) else dark


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh()


# ── 만들기·붙이기 ──────────────────────────────────────────────────────

## 줄 안에 그대로 놓는 배지 하나.
static func make(count := 0, words := "", as_dot := false, color := Color.TRANSPARENT) -> GoBadge:
	var node := GoBadge.new()
	node.label_text = words
	node.dot = as_dot
	node.ink = color
	node.set_count(count)
	return node


## 이 메타 이름으로 붙인 배지를 찾는다 — 같은 버튼에 두 개가 겹치지 않게.
const _ATTACHED := &"gohud_badge"


## **이미 있는 컨트롤의 모서리에** 배지를 붙인다(두 번 불러도 하나만 붙는다).
##
## ```gdscript
## GoBadge.attach(mail_button, unread)     # 개수가 0 이 되면 저절로 사라진다
## GoBadge.attach(shop_button, 0, "NEW")
## ```
##
## 🛑 **오른쪽 위에 걸쳐 놓는다** — 안쪽에 넣으면 아이콘을 가리고, 완전히 밖에 두면 줄 간격이
##    벌어진다. 절반만 걸치는 것이 두 문제를 모두 피한다.
## 🔑 붙는 쪽이 `Control` 이기만 하면 된다 — 버튼·아이콘·슬롯·탭 무엇에든 붙는다.
static func attach(host: Control, count := 0, words := "", as_dot := false,
		color := Color.TRANSPARENT) -> GoBadge:
	if not is_instance_valid(host): return null
	# 🛑 `get_meta(key, default)` 는 키가 없으면 **오류를 찍는다**(Godot 4 실측) — 기본값을 줘도
	#    그렇다. 먼저 `has_meta` 로 묻는다.
	var node: GoBadge = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if not is_instance_valid(node):
		node = GoBadge.new()
		node.name = "Badge"
		# 🛑 부모가 컨테이너여도 **자리를 강제당하지 않는다** — 앵커로 오른쪽 위에 못 박는다.
		#    네 앵커를 모두 그 모서리에 두면 부모 크기가 나중에 정해져도 따라온다.
		node.anchor_left = 1.0
		node.anchor_top = 0.0
		node.anchor_right = 1.0
		node.anchor_bottom = 0.0
		host.add_child(node)
		host.set_meta(_ATTACHED, node)
		node.tree_exited.connect(func() -> void:
			if not is_instance_valid(host) or not host.has_meta(_ATTACHED): return
			if host.get_meta(_ATTACHED) == node: host.remove_meta(_ATTACHED))
	node.label_text = words
	node.dot = as_dot
	node.ink = color
	node.set_count(count)
	node.reset_size()
	# 절반만 걸친다 — 오른쪽 위 모서리를 배지의 **한가운데**에 둔다.
	#
	# 🛑 앵커를 쓸 때는 `position` 이 아니라 `offset_*` 이다. `Control.position` 은 **부모 좌표**라
	#    앵커를 무시하고 그 값으로 가 버린다 — 2026-09-16 실측: 앵커가 오른쪽(1.0)인데도
	#    `position = (-8, -8)` 이 그대로 먹혀 배지가 부모 **왼쪽 위 바깥**에 붙었다.
	#    (그 전에는 `position` 에 부모 폭을 더해 반대쪽으로 한 폭만큼 날아갔다.)
	var half := node.size * 0.5
	node.offset_left = -half.x
	node.offset_top = -half.y
	node.offset_right = half.x
	node.offset_bottom = half.y
	return node


## 붙여 둔 배지를 뗀다. 없으면 아무 일도 하지 않는다.
static func detach(host: Control) -> void:
	if not is_instance_valid(host): return
	var node: GoBadge = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if is_instance_valid(node): node.queue_free()
	if host.has_meta(_ATTACHED): host.remove_meta(_ATTACHED)
