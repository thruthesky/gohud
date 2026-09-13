## 🧭 **안내 투어(코치마크).** 실제 화면의 컨트롤을 하나씩 가리키며 무엇인지 알려 준다.
##
## ## 🛑 막지 않는다
## 카드 영역만 입력을 받는다. 게임과 가리킨 컨트롤은 **그대로 쓸 수 있고**, 가리킨 컨트롤을 실제로
## 누르면 다음 단계로 넘어간다 — "여기를 누르세요" 가 말이 아니라 동작이 된다.
##
## ```gdscript
## var tour := GoCoachMark.new()
## add_child(tour)
## tour.finished.connect(func(done: bool) -> void: save_tour_seen())
## tour.start([
##     {"target": bag_button, "title": "가방", "body": "주운 물건이 여기 모입니다."},
##     {"target": map_button, "title": "지도", "body": "눌러서 전체 지도를 엽니다."},
## ])
## ```
##
## 단계 항목:
## | 키 | 뜻 |
## |---|---|
## | `target` | 가리킬 `Control`. 사라지면 그 단계를 건너뛴다 |
## | `title`·`body` | 번역 키여도 되고 그대로 쓸 문구여도 된다(자동 번역 라벨이다) |
## | `signal` | 대상의 이 신호가 오면 다음으로. 기본 `pressed`. 🛑 **인자 없는 신호**만 받는다 |
@tool
class_name GoCoachMark
extends Control

signal finished(completed: bool)
signal step_changed(index: int)

## 카드의 최대 폭(dp).
@export_range(160, 600) var card_max_width := 280.0

## 세로 화면에서 카드가 넘지 않을 **화면 위쪽 비율**(0~1). 0 이면 제한하지 않는다.
## 🛑 게임은 보통 화면 가운데에 캐릭터가 있다 — 안내 카드가 그 위를 덮으면 조작이 가려진다.
@export_range(0.0, 1.0, 0.01) var avoid_center_band := 0.45

## 가리키는 링·화살표의 색. 투명이면 테마의 `accent`.
@export var ink := Color.TRANSPARENT
## 🔑 **카드가 덮으면 안 되는 것들.** 붙박이 HUD(`GoHudAnchor` 의 `reserve_space` 칸)는 알아서 피하지만,
## 화면 머리띠·툴바처럼 앵커가 아닌 것은 여기 넣어 준다 — 카드가 그 위에 얹히면 조작을 막는다
## (2026-09-13 데모 실측: 카드가 헤더의 `→ ×` 를 덮었다).
@export var keep_clear: Array[Control] = []

var card: PanelContainer
var title_label: Label
var body_label: Label
var progress_label: Label
var next_button: Button
var skip_button: Button
var steps: Array[Dictionary] = []
var step := 0

var _target: Control
var _target_action := Callable()
var _target_signal := &""
var _ring: StyleBox
var _phase := 0.0
var _holds_back := false
var _fade: Tween
var _scroll: GoScroll
var _column: VBoxContainer
var _header: HBoxContainer


func _init() -> void:
	name = "CoachMark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## 🛑 자식은 `_init` 에서 만든다 — 트리에 붙기 전에 `start()` 를 부를 수 있어야 한다.
func _build() -> void:
	theme = GoUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent := _accent()
	_ring = GoUi.skin().coach_ring_box(accent)

	card = PanelContainer.new()
	card.name = "GuideCard"
	var face := GoUi.skin().floating_box(GoTheme.BOX_CARD, accent)
	face.set_content_margin_all(0)
	card.add_theme_stylebox_override(&"panel", face)
	add_child(card)

	var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	card.add_child(inset)
	_column = GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	inset.add_child(_column)

	_header = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	_header.name = "Header"
	_column.add_child(_header)
	progress_label = GoStyle.label("", GoTheme.ROLE_CAPTION, accent)
	progress_label.name = "Progress"
	progress_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.text_direction = Control.TEXT_DIRECTION_LTR
	_header.add_child(progress_label)
	title_label = GoStyle.label_key("", GoTheme.ROLE_BODY)
	title_label.name = "Title"
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header.add_child(title_label)

	_scroll = _make_scroll()
	_column.add_child(_scroll)
	body_label = GoStyle.label_key("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	body_label.name = "Body"
	_scroll.add_child(body_label)

	var actions := GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	actions.name = "Actions"
	_column.add_child(actions)
	skip_button = GoStyle.button_key(GoUi.text_key(&"skip"), finish.bind(false), GoStyle.Tone.BARE)
	skip_button.name = "Skip"
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skip_button.custom_minimum_size.x = 72
	GoStyle.typography(skip_button, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	actions.add_child(skip_button)
	actions.add_child(GoStyle.spacer())
	next_button = GoStyle.button_key(GoUi.text_key(&"next"), advance, GoStyle.Tone.PRIMARY)
	next_button.name = "Next"
	next_button.custom_minimum_size = Vector2(72, GoUi.config.min_touch_size)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.add_child(next_button)
	hide()
	set_process(false)


func _ready() -> void:
	# `ink` 를 `new()` 뒤에 바꿨을 수 있다 — 색을 다시 입힌다.
	_apply_accent()


func _apply_accent() -> void:
	var accent := _accent()
	_ring = GoUi.skin().coach_ring_box(accent)
	var face := GoUi.skin().floating_box(GoTheme.BOX_CARD, accent)
	face.set_content_margin_all(0)
	card.add_theme_stylebox_override(&"panel", face)
	progress_label.add_theme_color_override(&"font_color", accent)


## 투어를 시작한다. 항목 형식은 파일 머리말의 표를 본다.
func start(value: Array) -> void:
	_disconnect_target()
	steps.assign(value)
	step = 0
	if steps.is_empty(): return
	if not _holds_back:
		GoBackPolicy.acquire(get_tree())
		_holds_back = true
	show()
	set_process(true)
	_show_step()


func advance() -> void:
	if not visible: return
	step += 1
	_show_step()


func finish(completed: bool) -> void:
	_disconnect_target()
	_release_back()
	hide()
	set_process(false)
	queue_redraw()
	finished.emit(completed)


func _show_step() -> void:
	_disconnect_target()
	if step >= steps.size():
		finish(true)
		return
	var data := steps[step]
	_target = data.get("target") as Control
	# 반응형 레일이 접히거나 화면이 바뀌면 대상이 사라진다 — 그 단계는 건너뛴다.
	if not is_instance_valid(_target):
		advance()
		return
	var wanted := StringName(str(data.get("signal", "pressed")))
	if _target.has_signal(wanted):
		_target_signal = wanted
		_target_action = advance.call_deferred
		_target.connect(_target_signal, _target_action)
	title_label.text = str(data.get("title", ""))
	body_label.text = str(data.get("body", ""))
	progress_label.text = GoUi.text(&"coach_progress").format({"step": step + 1, "total": steps.size()})
	next_button.text = GoUi.text_key(&"done") if step == steps.size() - 1 else GoUi.text_key(&"next")
	# 🛑 글자를 바꿨으면 줄바꿈도 다시 정한다 — 안 그러면 `Done` 이 `Don`/`e` 로 갈라진다(실측).
	GoStyle.fit_words(next_button)
	_fade = GoStyle.fade(card, _fade, true)
	_layout()
	step_changed.emit(step)


func _disconnect_target() -> void:
	if is_instance_valid(_target) and not _target_signal.is_empty() and _target_action.is_valid() \
			and _target.is_connected(_target_signal, _target_action):
		_target.disconnect(_target_signal, _target_action)
	_target_action = Callable()
	_target_signal = &""


func _release_back() -> void:
	if not _holds_back: return
	_holds_back = false
	GoBackPolicy.release(get_tree())


func _exit_tree() -> void:
	_disconnect_target()
	_release_back()


func _process(delta: float) -> void:
	if not GoUi.config.reduce_motion: _phase += delta
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		advance()
		return
	# 진짜 메뉴가 열려 있는 동안은 카드를 숨긴다 — 닫히면 그 자리에서 이어진다.
	card.visible = not _should_pause()
	if card.visible: _layout()
	queue_redraw()


## 카드를 잠시 숨겨야 하는가 — 기본은 "gohud 표면이 하나라도 열려 있다". 🔑 호스트가 자기 모달 체계를 따로 가지면
## 자식에서 덮어써 그것도 함께 본다(닫히면 같은 단계에서 이어진다).
func _should_pause() -> bool:
	return GoSurface.is_any_open()


func _accent() -> Color:
	return ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)


## 전역 사각형 → 이 노드의 좌표. 🛑 이 노드가 원점에 있지 않으면(`CanvasLayer` 안의 여백 등)
##    전역 좌표를 그대로 그리면 링이 엇나간다.
func _to_local(rect: Rect2) -> Rect2:
	return Rect2(get_global_transform().affine_inverse() * rect.position, rect.size)


func _layout() -> void:
	if not is_instance_valid(_target): return
	var area := GoSafeArea.usable_rect(get_window()).grow(-GoUi.metric(GoTheme.GAP_SMALL))
	var landscape := area.size.x > area.size.y
	var width := minf(card_max_width, area.size.x * (0.44 if landscape else 0.82))
	card.size.x = width
	var chrome := float(GoUi.metric(GoTheme.PADDING_COMPACT) * 2 + _column.get_theme_constant(&"separation") * 2)
	var desired := chrome + _header.get_combined_minimum_size().y + body_label.get_minimum_size().y + GoUi.config.min_touch_size
	card.size.y = minf(maxf(116.0, desired), area.size.y * (0.52 if landscape else 0.32))
	var target := _target.get_global_rect()
	var gap := float(GoUi.metric(GoTheme.GAP))
	# 가로에서는 대상의 옆, 세로에서는 위나 아래. 가장자리에 둘 수 있으면 가운데를 피한다.
	var x := clampf(target.get_center().x - width * 0.5, area.position.x, area.end.x - width)
	var y := target.end.y + gap
	if target.get_center().y > area.get_center().y: y = target.position.y - gap - card.size.y
	if landscape:
		x = target.position.x - gap - width if target.get_center().x > area.get_center().x else target.end.x + gap
		# 🛑 화면 맨 위/아래 끝으로 보내지 않는다 — 그 띠에는 붙박이 HUD·머리띠가 산다. 카드가 헤더의 조작
		#    버튼을 덮었다(2026-09-13 데모 실측). **대상과 같은 높이**에 나란히 둔다.
		y = target.position.y
	elif avoid_center_band > 0.0:
		y = minf(y, area.position.y + area.size.y * avoid_center_band - card.size.y)
	var global := Vector2(
		clampf(x, area.position.x, maxf(area.position.x, area.end.x - card.size.x)),
		clampf(y, area.position.y, maxf(area.position.y, area.end.y - card.size.y)))
	global = _dodge_fixtures(Rect2(global, card.size), area, target).position
	card.position = get_global_transform().affine_inverse() * global


## 붙박이 HUD 와 `keep_clear` 를 피해 카드를 옮긴다 — 네 방향 중 **가장 적게** 움직이는 쪽으로, 대상 위로는
## 올라가지 않게. 🛑 다 피할 수 없으면(화면이 좁다) 그대로 둔다 — 카드가 사라지는 것보다 겹치는 편이 낫다.
func _dodge_fixtures(rect: Rect2, area: Rect2, target: Rect2) -> Rect2:
	var blocks: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(GoHudAnchor.GROUP):
		var hud := node as GoHudAnchor
		if hud == null or not hud.reserve_space or not hud.is_visible_in_tree(): continue
		if hud.get_viewport() != get_viewport(): continue
		var r := Rect2(hud.global_position, hud.size)
		if r.get_area() > 0.0: blocks.append(r)
	for control in keep_clear:
		if is_instance_valid(control) and control.is_visible_in_tree(): blocks.append(control.get_global_rect())
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL))
	for i in 4:                       # 붙박이 여럿을 차례로 — 한 번 옮긴 자리가 다른 것과 겹칠 수 있다
		var hit := Rect2()
		var found := false
		for block in blocks:
			if rect.intersects(block):
				hit = block; found = true; break
		if not found: return rect
		var options := [
			Vector2(0.0, hit.end.y + gap - rect.position.y),          # 아래로
			Vector2(0.0, hit.position.y - gap - rect.end.y),          # 위로
			Vector2(hit.end.x + gap - rect.position.x, 0.0),          # 오른쪽으로
			Vector2(hit.position.x - gap - rect.end.x, 0.0),          # 왼쪽으로
		]
		var best := Vector2.INF
		for move in options:
			var moved := Rect2(rect.position + move, rect.size)
			if not area.encloses(moved): continue
			if moved.intersects(target): continue               # 대상을 가리면 코치마크가 아니다
			if move.length() < best.length(): best = move
		if best == Vector2.INF: return rect
		rect.position += best
	return rect


func _draw() -> void:
	if not visible or card == null or not card.visible or not is_instance_valid(_target): return
	var pulse := 3.0 + (0.0 if GoUi.config.reduce_motion else sin(_phase * 3.0))
	var rect := _to_local(_target.get_global_rect().grow(pulse))
	draw_style_box(_ring, rect)
	var center := rect.get_center()
	var start := Vector2(
		clampf(center.x, card.position.x + 8, card.position.x + card.size.x - 8),
		clampf(center.y, card.position.y + 8, card.position.y + card.size.y - 8))
	var direction := (center - start).normalized()
	if direction.is_zero_approx(): return
	var tip := center - direction * (maxf(rect.size.x, rect.size.y) * 0.5 + 5.0)
	# 🔑 자리 계산은 여기, 그리는 모양은 스킨 — 테마를 바꾸면 점선·타깃 표시가 될 수 있다.
	GoUi.skin().draw_coach_pointer(self, start, tip, direction, _accent())


func _input(event: InputEvent) -> void:
	if visible and not GoSurface.is_any_open() and event.is_action_pressed(&"ui_cancel"):
		finish(false)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and not GoSurface.is_any_open():
		finish.call_deferred(false)
	# 🛑 진행 표시("1 / 5")는 조립 문자열이라 엔진 자동 번역을 타지 않는다 — 직접 다시 만든다.
	elif what == NOTIFICATION_TRANSLATION_CHANGED and visible and not steps.is_empty():
		progress_label.text = GoUi.text(&"coach_progress").format({"step": step + 1, "total": steps.size()})


## 본문 스크롤을 만든다. 🔑 호스트가 `GoScroll` 의 서브클래스를 쓰고 싶으면(옛 타입 힌트 호환 등) 자식에서 덮어쓴다.
func _make_scroll() -> GoScroll:
	return GoScroll.new()
