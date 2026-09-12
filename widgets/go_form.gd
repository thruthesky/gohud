## 📝 **폼의 폭을 화면에 맞춰 잡는 칸.** 로그인·설정·캐릭터 만들기처럼 세로로 긴 화면에 쓴다.
##
## ## 왜 필요한가
## 씬에 `custom_minimum_size = Vector2(800, 0)` 같은 고정 폭을 박으면, 720dp 폰에서 그 폼은
## **화면 밖으로 나간다.** 폭은 컨테이너가 채우고, 좌우 여백만 여기서 계산한다.
##
## > 좌우 여백 = max(최소 여백, (쓸 수 있는 폭 − 브레이크포인트별 최대 폼 폭) / 2)
##
## ## 쓰는 법
## 화면 루트 아래에 이것을 두고, 안에 `GoScroll` + `VBoxContainer` 를 넣는다.
## 스크롤 노드의 이름을 `Scroll` 로 해 두면 키보드 회피가 자동으로 붙는다.
##
## ```
## GoForm
##  └ GoScroll (이름: "Scroll")
##     └ VBoxContainer   ← 여기에 입력칸·버튼을 쌓는다
## ```
##
## ## 🛑 이 칸은 자손 라벨의 줄바꿈을 **보장한다**
## 없으면 긴 문장 하나가 한 줄로 뻗고, 그 최소 폭이 폼 전체를 화면 밖으로 민다 —
## 좌우가 잘려 무슨 화면인지조차 분간할 수 없게 된다. 씬마다 손으로 켜는 방식은 반드시 빠뜨린다.
@tool
class_name GoForm
extends MarginContainer

## 안의 스크롤(이름이 `Scroll` 인 자식). 키보드가 뜨면 포커스를 따라 스크롤한다.
var scroll: GoScroll

## 화면 가장자리에서 최소한 이만큼(dp). 음수면 토큰 `padding`.
@export var min_side_margin := -1:
	set(value):
		min_side_margin = value
		_relayout()

## 위아래 최소 여백(dp). 음수면 토큰 `screen_margin`.
@export var min_edge_margin := -1:
	set(value):
		min_edge_margin = value
		_relayout()

## Android 뒤로가기를 이 버튼으로 보낼 것인가. `%BackButton` 이라는 고유 이름의 자식을 찾는다.
@export var route_back_button := true

var _runtime: Node
var _keyboard_px := 0
var _back_button: Button
var _holds_back := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_runtime = GoUi.runtime()
	if _runtime != null:
		if _runtime.has_signal(&"breakpoint_changed"):
			_runtime.breakpoint_changed.connect(func(_bp) -> void: _relayout())
		if _runtime.has_signal(&"keyboard_changed"):
			_runtime.keyboard_changed.connect(_on_keyboard)
	get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_relayout)
	if not Engine.is_editor_hint():
		scroll = get_node_or_null(^"Scroll") as GoScroll
		if scroll != null: scroll.use_panel_edge(_side_margin())
		GoStyle.form(self)
		_watch_children(self)
		if route_back_button:
			_back_button = get_node_or_null(^"%BackButton") as Button
			visibility_changed.connect(_sync_back)
			_sync_back()
	_relayout()


func _side_margin() -> int:
	return GoUi.metric(GoTheme.PADDING) if min_side_margin < 0 else min_side_margin


func _edge_margin() -> int:
	return GoUi.metric(GoTheme.SCREEN_MARGIN) if min_edge_margin < 0 else min_edge_margin


## 브레이크포인트별 최대 폼 폭(dp). 오토로드가 없으면 화면 폭으로 직접 판정한다.
func _max_width() -> int:
	if _runtime != null and _runtime.has_method(&"form_max_width"): return _runtime.form_max_width()
	var view := get_viewport_rect().size
	return GoScale.form_width_for(GoScale.breakpoint_for_dp(minf(view.x, view.y)))


func _relayout() -> void:
	if not is_inside_tree(): return
	var view := get_viewport_rect().size
	if view.x <= 0.0: return
	var area := GoSafeArea.usable_rect(get_window())
	var side := float(_side_margin())
	var cap := _max_width()
	if cap > 0 and area.size.x > float(cap): side = maxf(side, (area.size.x - float(cap)) * 0.5)
	var keyboard := float(_keyboard_px) / maxf(1.0, get_window().content_scale_factor)
	add_theme_constant_override(&"margin_left", roundi(area.position.x + side))
	add_theme_constant_override(&"margin_right", roundi(view.x - area.end.x + side))
	add_theme_constant_override(&"margin_top", roundi(area.position.y) + _edge_margin())
	add_theme_constant_override(&"margin_bottom", roundi(maxf(view.y - area.end.y, keyboard)) + _edge_margin())


func _on_keyboard(height_px: int) -> void:
	if height_px == _keyboard_px: return
	_keyboard_px = height_px
	_relayout()
	if scroll == null: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and scroll.is_ancestor_of(focus): scroll.ensure_control_visible.call_deferred(focus)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree(): return
	if route_back_button: _sync_back()
	# 오토로드가 없으면 여기서 직접 키보드를 본다.
	if _runtime == null and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_on_keyboard(DisplayServer.virtual_keyboard_get_height())


## 나중에 추가되는 자식에게도 같은 규격을 입힌다.
func _watch_children(node: Node) -> void:
	if node is ScrollBar: return
	if not node.child_entered_tree.is_connected(_child_added):
		node.child_entered_tree.connect(_child_added)
	for child in node.get_children(): _watch_children(child)


func _child_added(node: Node) -> void:
	GoStyle.form(node)
	_watch_children(node)


func _sync_back() -> void:
	if Engine.is_editor_hint(): return
	var active := is_visible_in_tree() and is_instance_valid(_back_button)
	if active == _holds_back: return
	_holds_back = active
	if active: GoBackPolicy.acquire(get_tree())
	else: GoBackPolicy.release(get_tree())


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST: return
	if not _holds_back or not is_visible_in_tree() or GoSurface.is_any_open(): return
	# 🛑 Android 는 키보드가 **사라지는 애니메이션 중에도** 뒤로가기를 보고한다 —
	#    그때 화면을 나가면 사용자는 "한 번 눌렀는데 두 단계 뒤로 갔다" 고 느낀다.
	if _keyboard_px > 0:
		DisplayServer.virtual_keyboard_hide()
	elif is_instance_valid(_back_button) and not _back_button.disabled:
		_back_button.pressed.emit.call_deferred()


func _exit_tree() -> void:
	GoUi.unwatch(_relayout)
	if _holds_back:
		_holds_back = false
		GoBackPolicy.release(get_tree())
