## 📂 **옆에서 밀려 들어오는 서랍** — 태블릿·PC 가로 화면의 가방·친구목록·채팅.
##
## ```gdscript
## var bag := GoDrawer.new()
## add_child(bag)
## bag.open("가방")
## bag.body.add_child(inventory_grid)
##
## bag.side = GoDrawer.Side.RIGHT     # 오른쪽에서
## ```
##
## ## 🔑 `GoSheet` 와 무엇이 다른가
## `GoSheet` 는 **아래에서** 올라온다 — 폰 세로 화면에서 엄지에 가깝고, 화면 가로를 다 쓴다.
## 서랍은 **옆에서** 들어온다 — 가로가 넓은 화면에서 게임 화면을 다 가리지 않고 목록을 펼친다.
## 폰 세로에서는 서랍이 화면을 거의 다 덮으므로 그때는 시트를 쓰는 편이 낫다.
##
## ## 🛑 방향은 화면 방향이지 글 방향이 아니다
## `LEFT` 는 아랍어에서도 화면 왼쪽이다. 글 방향을 따르고 싶으면 `follow_text_direction` 을 켠다 —
## 그러면 RTL 에서 좌우가 뒤집힌다(메뉴 서랍처럼 "시작 쪽" 이 뜻이 있는 자리).
##
## ## 🛑 안전영역을 침범하지 않는다
## 노치·둥근 모서리가 있는 기기에서 서랍이 화면 끝까지 가면 모서리에서 내용이 잘린다.
## 배경은 끝까지 채우되 **내용은 안전영역 안**에 둔다.
@tool
class_name GoDrawer
extends CanvasLayer

## 닫혔다.
signal closed
## 열렸다.
signal opened

enum Side {
	LEFT,   ## 화면 왼쪽에서
	RIGHT,  ## 화면 오른쪽에서
}

## 어느 쪽에서 들어오는가.
@export var side := Side.LEFT:
	set(value):
		side = value
		_relayout()

## 글 방향(RTL)을 따라 좌우를 뒤집을 것인가. 🔑 메뉴 서랍처럼 "시작 쪽" 이 뜻이 있을 때 켠다.
@export var follow_text_direction := false:
	set(value):
		follow_text_direction = value
		_relayout()

## 차지할 화면 **가로** 비율. 좁은 화면에서는 `max_width` 가 먼저 걸린다.
@export_range(0.2, 1.0, 0.01) var width_ratio := 0.42:
	set(value):
		width_ratio = value
		_relayout()

## 최대 폭(dp). 넓은 모니터에서 서랍이 끝없이 넓어지지 않게.
@export var max_width := 420.0:
	set(value):
		max_width = value
		_relayout()

## 바깥(가림막)을 눌러 닫을 수 있는가.
@export var dismissable := true

## 미끄러져 들어오는 시간(초). `reduce_motion` 이면 무시한다.
@export var motion_seconds := 0.2

## 본문(스크롤됨).
var body: VBoxContainer
## 머리 줄.
var header: HBoxContainer
## 제목.
var title_label: Label
## 감싸고 있는 판 — 세밀한 조정이 필요하면 직접 만진다.
var panel: PanelContainer

var _scrim: ColorRect
var _root: Control
var _scroll: GoScroll
var _tween: Tween
var _open := false


func _init() -> void:
	layer = 80
	visible = false

	_root = Control.new()
	_root.name = "DrawerRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_scrim_input)
	_root.add_child(_scrim)

	panel = PanelContainer.new()
	panel.name = "Drawer"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var pad := GoStyle.padding()
	panel.add_child(pad)
	var column := GoStyle.column()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(column)

	header = GoStyle.row()
	header.name = "Header"
	column.add_child(header)
	title_label = GoStyle.label("", GoTheme.ROLE_TITLE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button := GoIconButton.new()
	close_button.icon_name = &"close"
	close_button.tooltip_text_name = &"close"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_scroll = GoScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	body = GoStyle.column()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)


func _ready() -> void:
	_restyle()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	# 🛑 뒤로가기 차지를 놓는다 — 서랍이 사라졌는데 뒤로가기를 계속 잡고 있으면 그 화면을 못 빠져나간다.
	if _open: GoBackPolicy.release(get_tree())


## 서랍을 연다. `title` 을 주면 머리 줄에 쓴다. 본문은 **비우지 않는다** — 넣어 둔 것이 남는다.
func open(title := "") -> void:
	if not title.is_empty(): set_title(title)
	if _open: return
	_open = true
	visible = true
	_relayout()
	_animate(true)
	GoBackPolicy.acquire(get_tree())
	GoFeedback.opened()
	opened.emit()


func close() -> void:
	if not _open: return
	_open = false
	_animate(false)
	GoBackPolicy.release(get_tree())
	GoFeedback.closed()
	closed.emit()


func is_open() -> bool:
	return _open


## 본문을 비운다(페이지를 갈아 끼울 때).
func clear() -> void:
	for child in body.get_children(): child.queue_free()


func set_title(value: String) -> void:
	title_label.text = value
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.visible = not value.is_empty()


func set_title_key(key: String) -> void:
	title_label.text = key
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	header.visible = not key.is_empty()


## 지금 화면에서 서랍이 실제로 붙는 쪽(글 방향을 따를 수도 있으므로 `side` 와 다를 수 있다).
## 🛑 반환 타입은 `GoDrawer.Side` 로 적는다 — 그냥 `Side` 라고 쓰면 GDScript 가 "`GoDrawer.Side`
##    를 `Side` 로 돌려줄 수 없다" 며 **파싱 단계에서** 죽는다(4.7 실측).
func effective_side() -> GoDrawer.Side:
	if not follow_text_direction: return side
	var rtl := TranslationServer.get_tool_locale().begins_with("ar") \
		or TranslationServer.get_tool_locale().begins_with("he") \
		or TranslationServer.get_tool_locale().begins_with("fa") \
		or TranslationServer.get_tool_locale().begins_with("ur")
	if not rtl: return side
	return Side.RIGHT if side == Side.LEFT else Side.LEFT


func _relayout() -> void:
	if panel == null or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	# 🛑 배경(판)은 화면 **끝까지** 가되 내용은 안전영역 안이다 — 판을 안으로 밀면 가장자리에
	#    바탕색 띠가 생겨 서랍이 떠 있는 것처럼 보인다.
	var full := window.get_visible_rect()
	var area := GoSafeArea.usable_rect(window)
	var width := minf(full.size.x * width_ratio, max_width) if max_width > 0.0 else full.size.x * width_ratio
	width = maxf(width, 160.0)
	panel.size = Vector2(width, full.size.y)
	var at_left := effective_side() == Side.LEFT
	panel.position = Vector2(0.0 if at_left else full.size.x - width, 0.0).round()

	# 내용만 안전영역 안으로 — 노치·제스처 바를 피한다.
	var pad := panel.get_child(0) as MarginContainer
	if pad != null:
		var base := GoUi.metric(GoTheme.PADDING)
		pad.add_theme_constant_override(&"margin_top", base + roundi(maxf(0.0, area.position.y - full.position.y)))
		pad.add_theme_constant_override(&"margin_bottom", base + roundi(maxf(0.0, full.end.y - area.end.y)))
		pad.add_theme_constant_override(&"margin_left",
			base + (roundi(maxf(0.0, area.position.x - full.position.x)) if at_left else 0))
		pad.add_theme_constant_override(&"margin_right",
			base + (0 if at_left else roundi(maxf(0.0, full.end.x - area.end.x))))

	if not _open: return
	if is_instance_valid(_tween) and _tween.is_valid(): return
	panel.position.x = 0.0 if at_left else full.size.x - width


func _animate(shown: bool) -> void:
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	var window := get_window()
	var full := window.get_visible_rect() if window != null else Rect2()
	var at_left := effective_side() == Side.LEFT
	var rest := 0.0 if at_left else full.size.x - panel.size.x
	var away := -panel.size.x if at_left else full.size.x

	if GoUi.config.reduce_motion or motion_seconds <= 0.0 or not is_inside_tree():
		panel.position.x = rest if shown else away
		_scrim.color = _scrim_color(shown)
		if not shown: visible = false
		return

	_tween = create_tween().set_parallel(true)
	if shown:
		panel.position.x = away
		_scrim.color = _scrim_color(false)
		_tween.tween_property(panel, "position:x", rest, motion_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_scrim, "color", _scrim_color(true), motion_seconds)
	else:
		_tween.tween_property(panel, "position:x", away, motion_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_scrim, "color", _scrim_color(false), motion_seconds)
		_tween.chain().tween_callback(func() -> void: visible = false)


func _scrim_color(shown: bool) -> Color:
	var base := GoUi.color(GoTheme.SCRIM)
	return base if shown else Color(base, 0.0)


func _scrim_input(event: InputEvent) -> void:
	if not dismissable or not _open: return
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not tapped: return
	_scrim.accept_event()
	close()


func _restyle() -> void:
	panel.add_theme_stylebox_override(&"panel", GoUi.skin().surface_box(GoTheme.BOX_CARD))
	_scrim.color = _scrim_color(_open)


func _on_ui_changed() -> void:
	_restyle()
	_relayout()


func _notification(what: int) -> void:
	# 뒤로가기(Android)·Escape 로 닫힌다 — 서랍은 "빠져나갈 수 있어야 하는" 화면이다.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _open and not GoSurface.is_any_open():
		close.call_deferred()
