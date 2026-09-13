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

## 🔑 **떠 있는 HUD 자리를 비울 것인가.** 켜면 같은 화면의 `GoHudAnchor` 가 차지한 사각형을
## 피해서 본문이 그 **뒤로 흐르지 않는다**.
##
## 끄면(기본) 폼은 화면 전체를 쓴다 — 지금까지의 동작 그대로다. 게임 화면 위에 HUD 만 띄우는
## 보통의 경우에는 필요 없고, **HUD 와 스크롤되는 본문이 한 화면에 같이 있을 때** 켠다.
##
## 🛑 피하는 방향은 **잃는 면적이 가장 작은 쪽**으로 고른다. 오른쪽 위의 체력바는 세로 화면에서는
##    위로(높이 13% 손실), 가로 화면에서는 오른쪽으로(폭 21% 손실) 피한다 — 가로에서 세로로만
##    피하면 본문이 화면의 27% 를 잃는다.
@export var avoid_hud := false:
	set(value):
		avoid_hud = value
		_relayout()

var _runtime: Node
var _keyboard_px := 0
var _back_button: Button
var _holds_back := false
## 마지막으로 적용한 HUD 여백(좌·상·우·하). HUD 는 나중에 크기가 정해지므로 매 프레임 견준다.
var _hud_pad := Vector4.ZERO


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
	# 🛑 **겹침은 폼이 실제로 차지할 자리에서 본다.** 안전영역 전체로 재면, 넓은 화면에서 폭 제한
	#    때문에 이미 가운데로 몰려 HUD 근처에도 없는 폼이 **또 옆으로 밀려** 가운데 정렬이 깨진다
	#    (1280 화면에서 본문이 왼쪽으로 214dp 치우쳤다 — 2026-09-13 데스크톱 실측).
	_hud_pad = _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)) if avoid_hud else Vector4.ZERO
	add_theme_constant_override(&"margin_left", roundi(area.position.x + side + _hud_pad.x))
	add_theme_constant_override(&"margin_right", roundi(view.x - area.end.x + side + _hud_pad.z))
	add_theme_constant_override(&"margin_top", roundi(area.position.y + _hud_pad.y) + _edge_margin())
	add_theme_constant_override(&"margin_bottom",
		roundi(maxf(view.y - area.end.y + _hud_pad.w, keyboard)) + _edge_margin())


## 떠 있는 HUD 들을 피하는 데 필요한 여백(좌·상·우·하 dp).
##
## 🛑 **한 칸마다 한 방향으로만 피한다.** 네 변을 다 밀면 오른쪽 위 모서리의 체력바 하나가 위와
##    오른쪽을 동시에 깎아 본문이 두 번 줄어든다. 겹치는 칸마다 **가장 싼 한 방향**을 골라 민다.
func _hud_insets(area: Rect2) -> Vector4:
	var here := get_viewport()
	var rects: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(GoHudAnchor.GROUP):
		var hud := node as GoHudAnchor
		if hud == null or not hud.reserve_space: continue
		if not hud.is_visible_in_tree() or hud.get_viewport() != here: continue
		# 내 안에 든 HUD 는 피할 대상이 아니다 — 그건 본문의 일부다.
		if hud == self or is_ancestor_of(hud) or hud.is_ancestor_of(self): continue
		var rect := Rect2(hud.global_position, hud.size)
		if rect.size.x > 0.0 and rect.size.y > 0.0 and area.intersects(rect): rects.append(rect)
	# 🛑 **크게 파고든 것부터** 처리한다. 순서에 따라 결과가 달라지므로 기준을 못박아 둔다 —
	#    안 그러면 같은 화면이 노드 차례가 바뀌었다는 이유만으로 다르게 배치된다.
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.intersection(area).get_area() > b.intersection(area).get_area())

	var remain := area
	for rect in rects:
		# 🛑 **이미 물러난 만큼을 빼고 다시 본다.** 오른쪽 위 체력바를 피해 오른쪽으로 물러났다면
		#    오른쪽 아래 슬롯은 그것만으로 이미 비껴 있다 — 따로 세면 아래를 또 깎는다.
		if not remain.intersects(rect): continue
		# 각 방향으로 피할 때 **잃는 면적**. 적은 쪽이 이긴다.
		var options := [
			[rect.end.x - remain.position.x, remain.size.y, 0],      # 왼쪽에서 민다
			[rect.end.y - remain.position.y, remain.size.x, 1],      # 위에서 민다
			[remain.end.x - rect.position.x, remain.size.y, 2],      # 오른쪽에서 민다
			[remain.end.y - rect.position.y, remain.size.x, 3],      # 아래에서 민다
		]
		var best: Array = []
		for option in options:
			if option[0] <= 0.0: continue
			if best.is_empty() or option[0] * option[1] < best[0] * best[1]: best = option
		if best.is_empty(): continue
		var depth: float = best[0]
		match int(best[2]):
			0: remain.position.x += depth; remain.size.x -= depth
			1: remain.position.y += depth; remain.size.y -= depth
			2: remain.size.x -= depth
			_: remain.size.y -= depth
		# 다 깎여 남는 것이 없으면 **피하기를 포기한다** — 빈 화면보다 겹친 화면이 낫다.
		if remain.size.x <= 0.0 or remain.size.y <= 0.0: return Vector4.ZERO
	return Vector4(remain.position.x - area.position.x, remain.position.y - area.position.y,
		area.end.x - remain.end.x, area.end.y - remain.end.y)


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
	# 🛑 HUD 는 **나중에** 크기가 정해진다(자식의 최소 크기를 deferred 로 잰다). 한 번만 계산하면
	#    첫 프레임의 0×0 을 믿고 끝난다 — 값이 달라졌을 때만 다시 배치한다.
	if avoid_hud and is_inside_tree():
		var area := GoSafeArea.usable_rect(get_window())
		var side := float(_side_margin())
		var cap := _max_width()
		if cap > 0 and area.size.x > float(cap): side = maxf(side, (area.size.x - float(cap)) * 0.5)
		if not _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)).is_equal_approx(_hud_pad):
			_relayout()
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
	# 🛑 언어가 바뀌면 버튼의 **보이는 글자**가 바뀐다 — 한 낱말이던 것이 두 낱말이 되기도 한다.
	#    낱말 줄바꿈 규칙을 자손 전부에 다시 입힌다(멱등이라 몇 번 불러도 같다).
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and not Engine.is_editor_hint():
		GoStyle.form(self)
		return
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
