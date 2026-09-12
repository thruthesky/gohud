## 🎒 **퀵슬롯 한 칸** — 아이콘 하나, 수량, 쿨다운, 단축키를 **판 한 장**에 담는다.
##
## ## 🛑 판은 하나다
## 작은 원 위에 수량 배지·키 배지·타이머를 따로 달면, 슬롯마다 실제 폭이 달라져 줄이 흔들리고
## 화면이 복잡해진다. 그래서 요소는 전부 **이 판의 폭 안**에 들어간다.
##
## ```gdscript
## var slot := GoSlot.new()
## slot.icon_name = GoIconSet.POTION
## slot.accent = GoUi.color(GoTheme.DANGER)
## slot.quantity = 12
## slot.shortcut_label = "1"
## slot.set_cooldown(3.0, 8.0)     # 8초 중 3초 남음
## ```
##
## ## 🔑 보이는 크기와 터치 크기가 다르다
## 슬롯을 촘촘히 놓으면 48dp 터치 상자가 이웃과 겹친다. 겹친 자리는 **중심이 더 가까운 슬롯**이
## 가져간다 — `touch_peers` 에 서로를 넣어 주면 된다.
@tool
class_name GoSlot
extends Button

## 수량을 아직 모른다 — `…` 을 보여 준다(서버 응답 대기).
const UNKNOWN := -1
## 이 슬롯에는 수량이라는 개념이 없다 — 수량 줄을 그리지 않는다(스킬·기능 슬롯).
const NONE := -2

## 아이콘 이름.
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_rebuild_icon()

## 이 슬롯의 의미색(테두리·발광).
@export var accent := Color.TRANSPARENT:
	set(value):
		accent = value
		refresh()

## 보유 수량. `UNKNOWN`(-1) 이면 `…`, `NONE`(-2) 이면 수량 줄을 아예 숨긴다(스킬 슬롯 등),
## 0 이면 흐리게.
@export var quantity := UNKNOWN:
	set(value):
		quantity = value
		refresh()

## 남은 시간 문구를 판 위쪽에 띄운다(쿨다운·버프 잔여). 비우면 숨긴다.
@export var timer_text := "":
	set(value):
		timer_text = value
		refresh()

## 단축키 표시(`1`·`Q`). 비우면 숨긴다. 🛑 **표시만** 한다 — 입력은 게임이 처리한다.
@export var shortcut_label := "":
	set(value):
		shortcut_label = value
		refresh()

## 보이는 판의 한 변(dp). 터치는 `GoConfig.min_touch_size` 까지 넓어진다.
@export_range(16, 128) var visual_size := 44:
	set(value):
		visual_size = value
		_fit()

## 겹치는 이웃 슬롯들. 겹친 자리는 중심이 가까운 쪽이 받는다.
var touch_peers: Array[Control] = []

var _face: Panel
var _icon: Control
var _quantity: Label
var _timer: Label
var _shortcut: Label
var _cooldown_left := 0.0
var _cooldown_total := 0.0


func _init() -> void:
	name = "Slot"
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = GoTheme.VAR_BARE_BUTTON
	clip_text = false


func _ready() -> void:
	theme = GoUi.theme()
	var touch := GoUi.config.min_touch_size
	custom_minimum_size = Vector2(touch, touch)

	_face = Panel.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)

	# 위: 남은 시간 · 가운데: 아이콘 · 아래: 수량. 셋 다 판의 폭을 그대로 쓴다.
	_timer = _line("Timer", GoTheme.ROLE_MICRO)
	_face.add_child(_timer)
	_icon = Control.new()
	_icon.name = "IconSlot"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_icon)
	_quantity = _line("Quantity", GoTheme.ROLE_MICRO)
	_face.add_child(_quantity)
	_shortcut = _line("Shortcut", GoTheme.ROLE_MICRO)
	_shortcut.add_theme_color_override(&"font_color", GoUi.color(GoTheme.MUTED))
	_face.add_child(_shortcut)

	_rebuild_icon()
	_fit.call_deferred()
	refresh.call_deferred()
	resized.connect(_fit)


func _line(node_name: String, role: StringName) -> Label:
	var node := GoStyle.label("", role)
	node.name = node_name
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 🛑 숫자·키 표시는 언어를 따라 뒤집히지 않는다.
	node.text_direction = Control.TEXT_DIRECTION_LTR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 쿨다운을 정한다. `left <= 0` 이면 쿨다운 없음.
func set_cooldown(left: float, total: float) -> void:
	_cooldown_left = maxf(0.0, left)
	_cooldown_total = maxf(0.0, total)
	refresh()


func cooldown_ratio() -> float:
	return clampf(_cooldown_left / _cooldown_total, 0.0, 1.0) if _cooldown_total > 0.0 else 0.0


func _rebuild_icon() -> void:
	if not is_instance_valid(_icon): return
	for child in _icon.get_children(): child.queue_free()
	if icon_name.is_empty(): return
	var px := maxi(8, roundi(visual_size * 0.44))
	var glyph := GoUi.icons().node(icon_name, px)
	# 🛑 칸 가운데에 **정해진 크기**로 둔다 — FULL_RECT 를 주면 텍스처 세트(TextureRect·EXPAND_IGNORE_SIZE)가 칸을
	#    통째로 채워 판 테두리에 붙는다(폰트 세트는 글자 크기가 고정이라 드러나지 않던 결함 — 2026-09-12 데모에서 발견).
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.size = Vector2(px, px)
	glyph.position = -Vector2(px, px) * 0.5
	_icon.add_child(glyph)


## 판 높이 = 실제 줄 높이의 합. 🛑 줄 높이를 **숫자로 박지 않는다** — 글꼴·배율이 곱해진 실제
##    줄 높이는 글자 크기보다 크고 기기마다 다르다. 박으면 수량이 판 밖으로 삐져나온다.
func _fit() -> void:
	if not is_instance_valid(_face): return
	var touch := float(GoUi.config.min_touch_size)
	var box := maxf(size.x, touch)
	var box_y := maxf(size.y, touch)
	var visual := minf(float(visual_size), minf(box, box_y))
	var timer_h := _timer.get_combined_minimum_size().y if _timer.visible else 0.0
	var quantity_h := _quantity.get_combined_minimum_size().y if _quantity.visible else 0.0
	var shortcut_h := _shortcut.get_combined_minimum_size().y if _shortcut.visible else 0.0
	var top := maxf(timer_h, shortcut_h)
	_face.position = Vector2((box - visual) * 0.5, (box_y - visual) * 0.5)
	_face.size = Vector2(visual, visual)
	_timer.position = Vector2.ZERO
	_timer.size = Vector2(visual, timer_h)
	# 단축키는 시간 표시와 **같은 줄의 반대쪽** — 둘 다 있어도 판이 커지지 않는다.
	_shortcut.position = Vector2(0, 0)
	_shortcut.size = Vector2(visual, shortcut_h)
	_shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _timer.visible else HORIZONTAL_ALIGNMENT_CENTER
	_icon.position = Vector2(0, top)
	_icon.size = Vector2(visual, maxf(0.0, visual - top - quantity_h))
	_quantity.position = Vector2(0, visual - quantity_h)
	_quantity.size = Vector2(visual, quantity_h)


## 색·글자를 지금 상태에 맞춘다.
func refresh() -> void:
	if not is_instance_valid(_face): return
	var color := accent if accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var lit := _cooldown_left > 0.0 or not timer_text.is_empty()
	var empty := quantity == 0

	var style := GoStyle.box(GoTheme.BOX_HUD, color)
	style.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	style.set_content_margin_all(0)
	style.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(color, 0.8), 0.24 if lit else 0.08)
	style.border_color = Color(color, 0.95 if lit else 0.45)
	style.set_border_width_all(2 if lit else 1)
	# 🛑 `shadow_size` 를 쓰지 않는다 — StyleBoxFlat 그림자는 본체와 별개의 사각형을 더 그린다.
	#    슬롯은 화면에 여러 개가 깔리므로 그리기 비용이 그만큼 곱해진다.
	style.shadow_size = 0
	_face.add_theme_stylebox_override(&"panel", style)

	_quantity.visible = quantity != NONE
	if _quantity.visible:
		_quantity.text = "…" if quantity == UNKNOWN else ("×" + GoBar.abbreviate(quantity))
		_quantity.add_theme_color_override(&"font_color",
			GoUi.color(GoTheme.MUTED) if empty else GoUi.color(GoTheme.TEXT))

	var seconds := ""
	if not timer_text.is_empty(): seconds = timer_text
	elif _cooldown_left > 0.0: seconds = "%ds" % ceili(_cooldown_left)
	_timer.visible = not seconds.is_empty()
	_timer.text = seconds
	_timer.add_theme_color_override(&"font_color", color)

	_shortcut.visible = not shortcut_label.is_empty()
	_shortcut.text = shortcut_label

	modulate.a = 0.55 if (empty or disabled) else 1.0
	_fit()


## 이 슬롯 자신의 사각 터치 — 이웃과 나누기 전의 판정이다.
func touch_hit(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(point)


func _has_point(point: Vector2) -> bool:
	if not touch_hit(point): return false
	if touch_peers.is_empty(): return true
	var here := (point + global_position - get_global_rect().get_center()).length()
	for peer in touch_peers:
		if peer == self or not is_instance_valid(peer) or not peer.is_visible_in_tree(): continue
		if (point + global_position - peer.get_global_rect().get_center()).length() < here: return false
	return true


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		set_process(false)
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	refresh()


## 쿨다운을 스스로 세게 한다(게임이 매 프레임 넣어 주지 않아도 되도록).
func start_cooldown(seconds: float) -> void:
	set_cooldown(seconds, seconds)
	set_process(seconds > 0.0)
