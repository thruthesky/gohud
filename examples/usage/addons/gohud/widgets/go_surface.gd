## 🪟 **떠 있는 창의 껍데기.** 팝업·시트·드롭다운이 전부 이것 하나를 쓴다.
##
## 안전영역·가상 키보드·고정 머리말/바닥·스크롤 본문·가장 위 창 판정·포커스 복원·뒤로가기
## 소유권·끌어서 높이 조절을 한 곳에서 처리한다.
##
## ```gdscript
## var surface := GoSurface.new()
## surface.set_title("설정")
## surface.body.add_child(GoStyle.label("내용"))
## surface.close_requested.connect(surface.queue_free)
## canvas_layer.add_child(surface)
## ```
##
## ## 세 가지 배치
## | `placement` | 모습 | 쓰는 곳 |
## |---|---|---|
## | `CENTER` | 화면 가운데 카드 | 확인창·설정 |
## | `BOTTOM` | 아래에서 올라온 시트 | 목록·관리 페이지 |
## | `ANCHOR` | 지정한 컨트롤 옆에 붙는 카드 | 드롭다운·컨텍스트 메뉴 |
##
## ## 🛑 이 노드는 스스로 사라지지 않는다
## `close_requested` 를 받아 숨기거나 지우는 것은 **소유한 화면**이다. 창이 왜 닫히는지는
## 이 껍데기가 알 수 없기 때문이다(저장하고 닫기 vs 버리고 닫기).
@tool
class_name GoSurface
extends Control

signal close_requested
signal back_requested
signal height_changed(ratio: float)

enum Placement { CENTER, BOTTOM, ANCHOR }

## 지금 열려 있는 표면의 수. 게임 입력을 멈출지 판단할 때 쓴다.
static var _open_count := 0
## 마지막 조작이 키보드·게임패드였는가. 🛑 포인터로 연 창에는 **포커스 링을 띄우지 않는다** —
##    터치로 메뉴를 열었을 뿐인데 닫기 버튼만 빛나면 "여기를 누르라" 는 신호처럼 보인다.
static var _pointer_navigation := true

## 열려 있는 표면이 하나라도 있는가.
static func is_any_open() -> bool:
	return _open_count > 0


# ── 배치 ───────────────────────────────────────────────────────────────

var placement := Placement.CENTER
var max_width := 0.0            ## 0 이면 `GoConfig.surface_max_width`
var max_height := 0.0           ## 0 이면 `GoConfig.surface_max_height`
var height_ratio := 0.0         ## 0 이면 `GoConfig.surface_height_ratio`
## 내용이 짧으면 카드도 짧아진다. 끄면 늘 `height_ratio` 만큼 차지한다.
var fit_content := true
## 좁은 화면에서 여백·글자를 한 단계 줄인다.
var compact := false
## 배경을 눌러 닫을 수 있는가. 기본은 설정값.
var dismiss_on_scrim := false
## 스크림을 투명하게 — 게임 화면 위의 드롭다운처럼 뒤가 보여야 할 때.
var scrim_transparent := false
## 열 때 카드를 페이드인.
var fade_in := false
## 끌어서 높이를 바꿀 수 있는가(시트).
var resizable := false
var show_header := true
var scroll_body := true
var close_enabled := true
## 열었을 때 포커스를 줄 컨트롤. 없으면 포인터 조작일 때 아무 데도 주지 않는다.
var initial_focus: Control

## ANCHOR 배치 — 이 컨트롤 바로 아래(공간이 없으면 위)에 붙는다.
var anchor_control: Control
var anchor_width := 320.0
var anchor_min_width := 210.0
var anchor_max_height := 520.0

# ── 자식 ───────────────────────────────────────────────────────────────

var card: PanelContainer
var header: HBoxContainer
var title_label: Label
var close_button: GoIconButton
var back_button: Button
var scroll: GoScroll
## 스크롤되는 본문. 대부분의 내용이 여기 들어간다.
var body: VBoxContainer
## 머리말 아래·본문 위의 **고정 줄**(검색칸 등). 기본은 숨김.
## 🛑 목록을 내려도 사라지면 안 되는 것을 여기 둔다 — 본문에 넣으면 시트를 줄였을 때 밖으로 밀린다.
var toolbar: VBoxContainer
## **고정 바닥 줄**(확인·취소). 기본은 숨김. 본문에 넣으면 긴 목록에서 화면 밖으로 나간다.
var footer: VBoxContainer

var _scrim: ColorRect
var _column: VBoxContainer
var _margin: MarginContainer
var _content_padding := 0
var _active := false
var _previous_focus: WeakRef
var _dragging := false
var _touch_index := -1
var _keyboard_px := 0
var _scrim_pressed := false
var _scrim_origin := Vector2.ZERO
var _holds_back := false
var _fade: Tween
var _runtime: Node


func _init() -> void:
	# 이름은 `_init` 에서 정한다 — `_ready` 에서 정하면 `new()` 직후 부르는 쪽이 바꾼 이름을 덮어쓴다.
	name = "Surface"
	# 🛑 설정의 기본값은 **여기서** 받는다 — `_ready` 에서 `dismiss_on_scrim or 설정` 으로 합치면
	#    `new()` 직후 명시한 `false`(거래창처럼 오탭으로 닫히면 안 되는 시트)가 설정의 `true` 에 덮인다.
	dismiss_on_scrim = GoUi.config.dismiss_on_scrim
	fade_in = GoUi.config.surface_fade_in
	_build()


## 🛑 자식은 **`_init` 에서** 만든다 — 트리에 붙이기 *전에* `set_title()` 이나 `body.add_child()` 를
##    부르는 것은 아주 자연스러운 사용법인데, `_ready` 에서 만들면 그때 `title_label` 이 아직
##    `null` 이라 "Invalid assignment … on a base object of type 'Nil'" 로 죽는다(2026-09-12 실측).
func _build() -> void:
	theme = GoUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 자식이 먼저 스크롤한다. 쓰이지 않은 휠 이벤트는 이 창 경계에서 멈춘다 —
	# 목록 끝에서도, 크롬 위에서도, 내용이 짧아 스크롤이 없을 때도 뒤쪽으로 새지 않는다.
	mouse_force_pass_scroll_events = false
	add_to_group(&"go_surfaces")

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = GoUi.color(GoTheme.SCRIM)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_scrim_input)
	add_child(_scrim)

	card = PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = GoTheme.VAR_PANEL
	card.clip_contents = true
	add_child(card)

	_margin = GoStyle.padding()
	card.add_child(_margin)
	_column = GoStyle.column()
	_margin.add_child(_column)

	header = GoStyle.row()
	header.name = "Header"
	_column.add_child(header)

	back_button = GoStyle.button_key(GoUi.text_key(&"back"), func() -> void: back_requested.emit(), GoStyle.Tone.COMPACT)
	back_button.name = "BackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 🛑 줄바꿈을 끈다 — 줄바꿈은 최소 **폭**을 거의 0 으로 만들고, `SHRINK_BEGIN` 에서는
	#    그 최소 폭이 곧 실제 폭이 된다. 그러면 캡슐만 남고 글자가 통째로 잘린다.
	back_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	back_button.set_meta(&"go_no_wrap", true)
	back_button.visible = false
	header.add_child(back_button)

	title_label = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	title_label.name = "Title"
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	close_button = _make_close_button()
	close_button.name = "CloseButton"
	close_button.visual_size = GoUi.config.close_button_visual
	close_button.icon_name = GoIconSet.CLOSE
	close_button.tooltip_text_name = &"close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(request_close)
	header.add_child(close_button)

	toolbar = GoStyle.column()
	toolbar.name = "Toolbar"
	toolbar.visible = false
	_column.add_child(toolbar)

	body = GoStyle.column()
	body.name = "Body"
	_column.add_child(body)

	footer = GoStyle.column()
	footer.name = "Footer"
	footer.visible = false
	_column.add_child(footer)


## 닫기 버튼을 만든다. 🔑 호스트가 `GoIconButton` 의 서브클래스(자기 그림·크기)를 쓰고 싶으면 자식에서 덮어쓴다 —
## 표면은 `GoIconButton` 의 API 만 쓴다.
func _make_close_button() -> GoIconButton:
	return GoIconButton.new()


## 본문 스크롤을 만든다. 🔑 호스트 프로젝트가 `GoScroll` 의 서브클래스를 쓰고 싶으면(옛 타입 힌트 호환 등) 이 메서드를
## 자식에서 덮어쓴다 — 표면은 `GoScroll` 의 API 만 쓴다.
func _make_scroll() -> GoScroll:
	return GoScroll.new()


func _ready() -> void:
	# `new()` 와 `add_child()` **사이**에 바꿨을 수 있는 옵션을 여기서 반영한다.
	_scrim.color = Color(0, 0, 0, 0) if scrim_transparent else GoUi.color(GoTheme.SCRIM)
	header.visible = show_header
	if resizable: attach_resize_handle(title_label)
	if scroll_body and scroll == null:
		# 🛑 스크롤 칸은 여기서 끼운다 — `use_panel_edge()` 는 부모가 정해진 뒤에야 스크롤바를
		#    카드 여백 자리로 내보낼 수 있다. 본문에 이미 담아 둔 자식은 그대로 따라온다.
		var slot := body.get_index()
		scroll = _make_scroll()
		_column.add_child(scroll)
		_column.move_child(scroll, slot)
		body.reparent(scroll)
		scroll.use_panel_edge(GoUi.metric(GoTheme.PADDING))
	elif not scroll_body:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_runtime = GoUi.runtime()
	if _runtime != null:
		if _runtime.has_signal(&"keyboard_changed"): _runtime.keyboard_changed.connect(_on_keyboard)
		if _runtime.has_signal(&"breakpoint_changed"): _runtime.breakpoint_changed.connect(func(_bp) -> void: relayout())
	get_viewport().size_changed.connect(relayout)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	visibility_changed.connect(_sync_active)
	GoUi.watch(relayout)
	relayout()
	_sync_active()


# ── 제목 ───────────────────────────────────────────────────────────────

## 번역 키를 제목으로 — 언어가 바뀌면 엔진이 다시 그린다.
func set_title_key(key: String) -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	title_label.text = key


## 이미 번역된 문구·사람 이름을 제목으로.
func set_title(value: String) -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.text = value


## 같은 표면 안의 하위 화면이 쓰는 뒤로 버튼. 빈 `Callable` 이면 감춘다.
func set_back(action: Callable) -> void:
	for existing in back_requested.get_connections():
		back_requested.disconnect(existing.callable)
	if action.is_valid(): back_requested.connect(action)
	back_button.visible = action.is_valid()


## 본문을 비운다.
func clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if scroll != null: scroll.scroll_vertical = 0


func request_close() -> void:
	if close_enabled and is_top(): close_requested.emit()


# ── 가장 위 창 판정 ────────────────────────────────────────────────────

## 이 표면이 가장 위인가 — 중첩된 `CanvasLayer` 까지 보고 실제 그려지는 순서로 판단한다.
## 🛑 이것이 없으면 창 두 개가 겹쳤을 때 Escape 한 번이 둘 다 닫는다.
func is_top() -> bool:
	if not is_inside_tree() or not is_visible_in_tree(): return false
	var winner: GoSurface = self
	for node in get_tree().get_nodes_in_group(&"go_surfaces"):
		# 🛑 `node` 를 먼저 `GoSurface` 로 좁힌다 — `for` 변수는 `Node` 라, 그대로 `_layer_order()`
		#    를 부르면 반환 타입을 추론하지 못해 **파싱 단계에서** 스크립트가 통째로 죽는다
		#    (증상은 `GoSurface.new()` 의 "Nonexistent function 'new' in base 'GDScript'" 다).
		var candidate := node as GoSurface
		if candidate == null or not candidate.is_visible_in_tree(): continue
		var mine := winner._layer_order()
		var theirs := candidate._layer_order()
		if theirs > mine or (theirs == mine and candidate.is_greater_than(winner)): winner = candidate
	return winner == self


func _layer_order() -> int:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CanvasLayer: return ancestor.layer
		ancestor = ancestor.get_parent()
	return 0


# ── 수명·포커스 ────────────────────────────────────────────────────────

func _sync_active() -> void:
	var next := is_visible_in_tree()
	if next == _active: return
	_active = next
	_dragging = false
	_touch_index = -1
	_scrim_pressed = false
	if next:
		if not _holds_back:
			GoBackPolicy.acquire(get_tree())
			_open_count += 1
			_holds_back = true
		var focus := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus) if focus != null and not is_ancestor_of(focus) else null
		if scroll != null: scroll.scroll_vertical = 0
		relayout()
		if fade_in: _fade = GoStyle.fade(card, _fade, true)
		_focus_default.call_deferred()
	else:
		_release_back()
		_restore_focus()


func _release_back() -> void:
	if not _holds_back: return
	_holds_back = false
	_open_count = maxi(0, _open_count - 1)
	GoBackPolicy.release(get_tree())


func _focus_default() -> void:
	if not is_top(): return
	if is_instance_valid(initial_focus) and initial_focus.is_visible_in_tree():
		initial_focus.grab_focus()
		return
	if GoUi.config.suppress_pointer_focus_ring and _pointer_navigation:
		# 포인터로 열었다 — 링을 띄우지 않는다. Tab 을 누르면 그때 포커스가 들어온다.
		# 🛑 뒤쪽 화면에 남은 포커스는 놓게 한다 — 그대로 두면 창이 떠 있는데 Enter 가
		#    뒤 버튼을 누른다. 닫을 때 `_restore_focus` 가 원래 자리로 되돌린다.
		var outside := get_viewport().gui_get_focus_owner()
		if outside != null and not is_ancestor_of(outside): outside.release_focus()
		return
	if close_button.visible and not close_button.disabled:
		close_button.grab_focus()
		return
	var target := find_next_valid_focus()
	if target != null and is_ancestor_of(target): target.grab_focus()


func _focus_changed(target: Control) -> void:
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return
	# 창 밖에 포커스를 남기지 않는다 — Enter 가 뒤쪽 화면의 버튼을 누르면 안 된다.
	if GoUi.config.suppress_pointer_focus_ring and _pointer_navigation and not is_instance_valid(initial_focus):
		target.release_focus.call_deferred()
	else:
		_focus_default.call_deferred()


func _restore_focus() -> void:
	if _previous_focus == null: return
	var previous := _previous_focus.get_ref() as Control
	_previous_focus = null
	if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
		previous.grab_focus.call_deferred()


func _exit_tree() -> void:
	GoUi.unwatch(relayout)
	_release_back()
	_restore_focus()


# ── 배치 계산 ──────────────────────────────────────────────────────────

func relayout() -> void:
	if card == null or not is_inside_tree(): return
	_update_density()
	var settings := GoUi.config
	var area := GoSafeArea.usable_rect_with_keyboard(get_window(), _keyboard_px)
	if placement == Placement.ANCHOR and is_instance_valid(anchor_control) and anchor_control.is_inside_tree():
		_relayout_anchor(area)
		return
	# 화면 가장자리에서 최소한 이만큼은 떨어진다 — 아주 좁은 화면에서는 비율로 줄인다.
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN))
	area = area.grow(-minf(edge, minf(area.size.x, area.size.y) * 0.1))
	var landscape := area.size.x > area.size.y
	var width_ratio := settings.surface_width_ratio_landscape if landscape else settings.surface_width_ratio_portrait
	var cap_width := max_width if max_width > 0.0 else settings.surface_max_width
	var cap_height := max_height if max_height > 0.0 else settings.surface_max_height
	var ratio := height_ratio if height_ratio > 0.0 else settings.surface_height_ratio
	var width := maxf(1.0, minf(cap_width, area.size.x * width_ratio))
	var height := maxf(1.0, minf(cap_height, area.size.y * minf(ratio, settings.surface_max_height_ratio)))
	if fit_content: height = maxf(1.0, minf(height, _desired_height()))
	card.size = Vector2(width, height)
	var y := area.position.y + (area.size.y - card.size.y) * (1.0 if placement == Placement.BOTTOM else 0.5)
	card.position = Vector2(area.position.x + (area.size.x - card.size.x) * 0.5, y)


## 좁아지면 여백과 제목 크기를 한 단계 줄인다 — 작은 화면에서 내용이 들어갈 자리를 만든다.
func _update_density() -> void:
	var small := compact or get_viewport_rect().size.y < 420
	var token := GoTheme.PADDING_COMPACT if small else GoTheme.PADDING
	var next := GoUi.metric(token)
	if _content_padding != next:
		_content_padding = next
		GoStyle.insets(_margin, next)
		GoStyle.gap(_column, GoTheme.GAP_SMALL if small else GoTheme.GAP)
		if scroll != null: scroll.set_panel_padding(next)
	var role := GoTheme.ROLE_BODY if small else GoTheme.ROLE_SUBTITLE
	if title_label.get_meta(&"go_text_role", &"") != role: GoStyle.typography(title_label, role)


## 내용이 요구하는 카드 높이(여백 + 머리말 + 고정 줄 + 본문 + 바닥).
## 🛑 `toolbar` 를 빠뜨리면 검색칸을 켠 시트가 딱 그만큼 짧아져 목록 마지막 줄이 잘린다.
func _desired_height() -> float:
	var desired := float(_content_padding * 2)
	var gap := float(GoUi.metric(GoTheme.GAP))
	if header.visible: desired += header.get_combined_minimum_size().y + gap
	if toolbar.visible: desired += toolbar.get_combined_minimum_size().y + gap
	desired += body.get_combined_minimum_size().y
	if footer.visible: desired += footer.get_combined_minimum_size().y + gap
	return desired


## 지정한 컨트롤 옆에 붙인다 — 오른쪽에 최소 폭이 나오면 오른쪽, 아니면 넓은 쪽, 둘 다 안 되면
## 화면 안쪽으로 당긴다. 아래가 위보다 좁으면 위로 연다.
func _relayout_anchor(area: Rect2) -> void:
	var anchor := anchor_control.get_global_rect()
	var edge := 8.0
	var gap := 7.0
	var space_right := area.end.x - anchor.position.x - edge
	var space_left := anchor.end.x - area.position.x - edge
	var width := anchor_width
	var x := anchor.position.x
	if space_right < anchor_min_width and space_left < anchor_min_width:
		width = clampf(area.size.x - edge * 2, 1, anchor_width)
		x = area.position.x + edge
	elif space_right >= anchor_min_width or space_right >= space_left:
		width = clampf(space_right, anchor_min_width, anchor_width)
	else:
		width = clampf(space_left, anchor_min_width, anchor_width)
		x = anchor.end.x - width
	var below := area.end.y - anchor.end.y - gap - edge
	var above := anchor.position.y - area.position.y - gap - edge
	var opens_up := below < above
	var cap := minf(anchor_max_height, area.size.y * GoUi.config.surface_max_height_ratio)
	var height := clampf(above if opens_up else below, 0, cap)
	if fit_content: height = minf(height, _desired_height())
	card.size = Vector2(maxf(1, width), maxf(1, height))
	# 고정 머리말·바닥이 남는 공간보다 크면 카드가 최소 크기로 커진다 — 그때는 화면 안으로 민다.
	var y := anchor.position.y - gap - card.size.y if opens_up else anchor.end.y + gap
	y = clampf(y, area.position.y + edge, maxf(area.position.y + edge, area.end.y - edge - card.size.y))
	x = clampf(x, area.position.x + edge, maxf(area.position.x + edge, area.end.x - edge - card.size.x))
	card.position = Vector2(x, y)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_sync_active()
	if not _active: return
	close_button.disabled = not close_enabled
	# 오토로드가 없으면 여기서 직접 키보드를 본다(있으면 신호로 온다).
	if _runtime == null and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_on_keyboard(DisplayServer.virtual_keyboard_get_height())
	if fit_content: relayout()


func _on_keyboard(height_px: int) -> void:
	if height_px == _keyboard_px: return
	_keyboard_px = height_px
	relayout()
	if scroll == null: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and scroll.is_ancestor_of(focus): scroll.ensure_control_visible.call_deferred(focus)


# ── 입력 ───────────────────────────────────────────────────────────────

func _scrim_input(event: InputEvent) -> void:
	if not dismiss_on_scrim or not is_top(): return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT): return
	if event.pressed:
		_scrim_pressed = true
		_scrim_origin = event.position
	else:
		# 🛑 누른 자리에서 **끌지 않았을 때만** 닫는다 — 카드 안에서 시작해 밖에서 뗀 끌기가
		#    창을 닫으면 안 된다.
		if _scrim_pressed and _scrim_origin.distance_to(event.position) < GoUi.metric(GoTheme.SCROLL_DEADZONE):
			request_close()
		_scrim_pressed = false


func _gui_input(event: InputEvent) -> void:
	# `MOUSE_FILTER_STOP` 은 Godot 에서 확대/이동 제스처를 삼키지 않는다.
	# 중첩된 컨트롤이 먼저 본 뒤에야 여기로 오므로, 남은 것만 여기서 멈춘다.
	if event is InputEventGesture: accept_event()


## 끌어서 높이 조절 — 시트의 머리말을 잡고 위아래로.
func attach_resize_handle(handle: Control) -> void:
	resizable = true
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	if not handle.gui_input.is_connected(_resize_input): handle.gui_input.connect(_resize_input)
	handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE


func _resize_input(event: InputEvent) -> void:
	if not resizable or not is_top(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_touch_index = event.index if event.pressed else -1


func _input(event: InputEvent) -> void:
	_track_device(event)
	if not is_top():
		_dragging = false
		return
	if GoUi.config.close_on_back and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		request_close()
		get_viewport().set_input_as_handled()
		return
	if not _dragging: return
	var dy := 0.0
	if event is InputEventScreenDrag and event.index == _touch_index: dy = event.relative.y
	elif event is InputEventMouseMotion and _touch_index < 0: dy = event.relative.y
	elif (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		_dragging = false
		_touch_index = -1
	if not is_zero_approx(dy):
		var area := GoSafeArea.usable_rect(get_window())
		var current := height_ratio if height_ratio > 0.0 else GoUi.config.surface_height_ratio
		height_ratio = clampf(current - dy / maxf(1.0, area.size.y), 0.3, 0.95)
		relayout()
		height_changed.emit(height_ratio)
	get_viewport().set_input_as_handled()


## 어떤 장치로 조작 중인지 기록한다. 창이 숨어 있어도 트리에 있으면 이벤트가 오므로,
## **창을 열기 직전의 조작**(버튼 탭인지 Tab 키인지)이 그대로 반영된다.
func _track_device(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_pointer_navigation = true
	elif event is InputEventJoypadButton or (event is InputEventKey and event.pressed and not event.is_echo()):
		_pointer_navigation = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and GoUi.config.close_on_back and is_top():
		# 한 번의 OS 알림이 겹친 창 여러 개를 닫지 않도록 미룬다.
		request_close.call_deferred()
