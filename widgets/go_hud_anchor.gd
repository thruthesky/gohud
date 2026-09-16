## 🧭 HUD 요소를 **화면 아홉 자리** 중 하나에 붙이는 칸. 안전영역과 가장자리 여백을 알아서 지킨다.
##
## ## 왜 필요한가
## HUD 조각마다 `set_anchors_preset` + 오프셋을 손으로 쓰면, 노치가 있는 기기에서 체력바가
## 카메라 구멍에 가리고 가로 모드에서 조작 버튼이 제스처 바에 걸린다. 그 계산을 한 곳에 둔다.
##
## ```gdscript
## var corner := GoHudAnchor.new()
## corner.spot = GoHudAnchor.Spot.TOP_LEFT
## corner.add_child(health_bar)
## hud.add_child(corner)
## ```
##
## ## 🔑 가로/세로에 따라 자리를 바꾸려면
## `landscape_spot` 을 정하면 가로 화면일 때 그 자리로 옮겨 간다. 세로에서 아래 가운데에 있던
## 조작부를 가로에서는 오른쪽 아래로 보내는 식이다.
@tool
class_name GoHudAnchor
extends Control

enum Spot {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	CENTER_LEFT, CENTER, CENTER_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT,
}

## 떠 있는 HUD 칸이 모두 들어가는 그룹. `GoForm.avoid_hud` 가 이것으로 자리를 찾는다.
const GROUP := &"gohud_hud_anchor"

## 붙일 자리.
@export var spot := Spot.TOP_LEFT:
	set(value):
		spot = value
		_relayout()

## 가로 화면일 때의 자리. `-1` 이면 `spot` 을 그대로 쓴다.
@export var landscape_spot := -1:
	set(value):
		landscape_spot = value
		_relayout()

## 화면 가장자리에서 띄울 거리(dp). 음수면 토큰 `screen_margin`.
@export var edge_margin := -1:
	set(value):
		edge_margin = value
		_relayout()

## 🔑 **이미 자리 잡은 HUD 를 피해 비킬 것인가.**
##
## 스낵바처럼 **잠깐 떴다 사라지는 것**에 켠다. 위쪽 가운데에 뜨는 알림은 오른쪽 위의 체력바와
## 폭이 겹쳐 그 위에 그대로 얹히는데(실측), 켜 두면 체력바 아래로 내려가 앉는다.
##
## 🛑 **세로로만 비킨다.** 좌우로도 밀면 가운데 정렬이던 알림이 뜰 때마다 다른 자리에 나타난다.
## 🛑 피하는 쪽은 **`reserve_space` 가 켜진 붙박이 칸**뿐이다. 잠깐 뜨는 것끼리(알림·프롬프트)는
##    서로 피하지 않는다 — 실제로 그렇게 했더니 알림이 프롬프트 카드까지 피해 화면 한복판까지
##    밀려났다(2026-09-13 가로 실측). 화면 가운데 줄(`CENTER_*`)은 비킬 곳이 없어 그대로 둔다.
@export var avoid_peers := false:
	set(value):
		avoid_peers = value
		_relayout()

## 🔑 **본문에서 이 자리를 비워 줄 것인가**(`GoForm.avoid_hud` 가 켜져 있을 때만 뜻이 있다).
##
## 끄면 폼이 이 칸을 못 본 척한다. 손을 얹은 동안에만 나타나는 조이스틱처럼 **평소에는 화면에
## 없는 것**이 그렇다 — 켜 두면 보이지도 않는 칸이 본문 한 줄을 통째로 깎는다.
##
## 이 값은 `avoid_peers` 가 켜진 칸이 **누구를 피할지**도 정한다 — 붙박이만 피한다.
@export var reserve_space := true:
	set(value):
		if reserve_space == value: return
		reserve_space = value
		_wake_dodgers()

## 안전영역을 지킬 것인가. 배경처럼 화면을 꽉 채워야 하는 것만 끈다.
@export var use_safe_area := true:
	set(value):
		use_safe_area = value
		_relayout()

var _runtime: Node
## 마지막으로 잡은 자리. 붙박이 칸이 **움직였을 때만** 비키는 칸들을 깨우기 위한 것이다.
var _last_rect := Rect2()
## 🛑 재진입 가드 — `_relayout` 이 `size` 를 바꾸면 `resized` 가 다시 날아온다. 없으면 무한히 돈다.
var _laying_out := false


func _init() -> void:
	name = "HudAnchor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	# 🛑 **자기가 어디를 차지하는지 알릴 수 있어야 한다.** 스크롤 본문이 이 칸 뒤로 흘러 글자끼리
	#    뒤섞이는 일이 실제로 있었다(2026-09-13) — `GoForm.avoid_hud` 가 이 그룹을 훑어 피한다.
	add_to_group(GROUP)
	_runtime = GoUi.runtime()
	get_viewport().size_changed.connect(_relayout)
	child_entered_tree.connect(_watch_child)
	for child in get_children(): _watch_child(child)
	_relayout.call_deferred()
	GoUi.watch(_relayout)


func _exit_tree() -> void:
	GoUi.unwatch(_relayout)


## 🎨 생김새가 통째로 바뀌었다 — `GoUi.use_preset()`·`GoUi.refresh()` 가 부른다.
## 🛑 이것이 없으면 **이미 떠 있는 위젯만 옛 테마로 남는다**(2026-09-16 실측).


## 🛑 자식의 **최소 크기·보임 변화**를 듣는다 — 알림이 글자를 받아 커지거나, 숨었던 카드가 나타나도
##    이 칸이 따라 커져야 한다. 뷰포트 크기만 들으면 알림이 0×0 칸에 갇혀 보이지 않는다.
func _watch_child(node: Node) -> void:
	if not (node is Control): return
	var control := node as Control
	var relayout := _relayout.call_deferred
	if not control.minimum_size_changed.is_connected(relayout): control.minimum_size_changed.connect(relayout)
	if not control.visibility_changed.is_connected(relayout): control.visibility_changed.connect(relayout)
	_relayout.call_deferred()


## 지금 적용될 자리(가로/세로를 반영한 값).
func active_spot() -> Spot:
	var view := get_viewport_rect().size
	if landscape_spot >= 0 and view.x > view.y: return landscape_spot as Spot
	return spot


func _relayout() -> void:
	if _laying_out or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	_laying_out = true
	var area := GoSafeArea.usable_rect(window) if use_safe_area else window.get_visible_rect()
	var margin := float(GoUi.metric(GoTheme.SCREEN_MARGIN) if edge_margin < 0 else edge_margin)
	area = area.grow(-margin)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		_laying_out = false
		return

	# 자식이 요구하는 크기. 컨테이너가 아니므로 직접 재서 우리 크기로 삼는다.
	var wanted := Vector2.ZERO
	for child in get_children():
		if child is Control and child.visible:
			wanted = wanted.max(child.get_combined_minimum_size())
	if custom_minimum_size.x > 0.0: wanted.x = maxf(wanted.x, custom_minimum_size.x)
	if custom_minimum_size.y > 0.0: wanted.y = maxf(wanted.y, custom_minimum_size.y)
	wanted = wanted.min(area.size)
	size = wanted

	var here := active_spot()
	var column := int(here) % 3       # 0 왼쪽 · 1 가운데 · 2 오른쪽
	var line := int(here) / 3         # 0 위 · 1 가운데 · 2 아래
	position = Vector2(
		area.position.x + (area.size.x - size.x) * (column * 0.5),
		area.position.y + (area.size.y - size.y) * (line * 0.5))
	if avoid_peers: _dodge_peers(area, line)

	for child in get_children():
		if child is Control: child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 🛑 **붙박이가 움직였으면 비키는 칸들에게 알린다.** 알림은 체력바의 크기 변화를 스스로 알 길이
	#    없어, 체력바가 숨거나 줄어들어도 비킨 자리에 그대로 남았다(2026-09-13 실측).
	var now := Rect2(position, size)
	if not avoid_peers and now != _last_rect:
		_last_rect = now
		_wake_dodgers()
	_laying_out = false


## 나를 피하고 있는 칸들에게 자리를 다시 잡으라고 알린다.
## 🛑 비키는 칸은 이것을 부르지 않는다 — 서로 깨우면 두 칸이 영원히 재배치를 주고받는다.
func _wake_dodgers() -> void:
	if not is_inside_tree(): return
	for node in get_tree().get_nodes_in_group(GROUP):
		var peer := node as GoHudAnchor
		if peer != null and peer != self and peer.avoid_peers: peer._relayout.call_deferred()


## 자리가 고정된 다른 칸을 피해 세로로 비킨다. 위쪽 칸은 아래로, 아래쪽 칸은 위로.
func _dodge_peers(area: Rect2, line: int) -> void:
	if line == 1: return                      # 화면 가운데 줄 — 비킬 곳이 없다
	var down := line == 0
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL))
	var here := get_viewport()
	var shift := 0.0
	var mine := Rect2(global_position, size)
	for node in get_tree().get_nodes_in_group(GROUP):
		var peer := node as GoHudAnchor
		# 붙박이 칸만 피한다 — 잠깐 뜨는 것끼리 서로 피하면 둘 다 엉뚱한 자리로 달아난다.
		if peer == null or peer == self: continue
		if not peer.reserve_space or peer.avoid_peers: continue
		if not peer.is_visible_in_tree() or peer.get_viewport() != here: continue
		var rect := Rect2(peer.global_position, peer.size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
		if not Rect2(mine.position + Vector2(0.0, shift), mine.size).intersects(rect): continue
		shift = (rect.end.y + gap - mine.position.y) if down else (rect.position.y - gap - mine.end.y)
	if is_zero_approx(shift): return
	# 🛑 비키다가 화면 밖으로 나가면 아예 안 보인다 — 쓸 수 있는 칸 안에 묶어 둔다.
	position.y = clampf(position.y + shift, area.position.y,
		maxf(area.position.y, area.end.y - size.y))
