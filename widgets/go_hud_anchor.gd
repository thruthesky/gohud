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

## 안전영역을 지킬 것인가. 배경처럼 화면을 꽉 채워야 하는 것만 끈다.
@export var use_safe_area := true:
	set(value):
		use_safe_area = value
		_relayout()

var _runtime: Node
## 🛑 재진입 가드 — `_relayout` 이 `size` 를 바꾸면 `resized` 가 다시 날아온다. 없으면 무한히 돈다.
var _laying_out := false


func _init() -> void:
	name = "HudAnchor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	_runtime = GoUi.runtime()
	get_viewport().size_changed.connect(_relayout)
	child_entered_tree.connect(_watch_child)
	for child in get_children(): _watch_child(child)
	_relayout.call_deferred()


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

	for child in get_children():
		if child is Control: child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_laying_out = false
