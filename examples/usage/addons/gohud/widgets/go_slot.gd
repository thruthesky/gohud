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
var _quantity_badge: PanelContainer
var _timer: Label
var _timer_badge: PanelContainer
var _shortcut: Label
var _cooldown_left := 0.0
var _cooldown_total := 0.0


## 🔑 **키보드·게임패드로 이 칸에 닿을 수 있게 할 것인가.**
##
## 기본은 꺼져 있다 — 퀵슬롯은 손가락이나 숫자키로 쓰는 것이고, 여덟 칸이 Tab 순회에 끼면 설정
## 화면을 키보드로 돌 때 매번 슬롯을 거쳐야 한다. 키보드만으로 하는 조작이 필요하면 켠다.
@export var keyboard_focus := false:
	set(value):
		keyboard_focus = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE


func _init() -> void:
	name = "Slot"
	# 🛑 기본은 Tab 순회에서 빠진다 — 위 `keyboard_focus` 주석에 이유가 있다.
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

	# 🔑 **아이콘은 가운데에 크게, 글자는 모서리 배지로.** 셋을 세로로 쌓으면 48dp 안에서 아이콘이
	#    작아지고 글자끼리 붙어 비좁았다(2026-09-13 실측). 단축키는 왼쪽 위, 수량은 오른쪽 아래 배지,
	#    남은 시간은 아이콘 **위에 겹쳐** 크게 — 게임 HUD 가 쓰는 배치 그대로다.
	_icon = Control.new()
	_icon.name = "IconSlot"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_icon)
	# 남은 시간은 아이콘 위에 **작은 배지**로 — 배지 없이 겹치면 아이콘과 뒤섞여 안 읽힌다(실측).
	_timer_badge = PanelContainer.new()
	_timer_badge.name = "TimerBadge"
	_timer_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_timer_badge)
	_timer = _line("Timer", GoTheme.ROLE_COMPACT)
	_timer_badge.add_child(_timer)
	_shortcut = _line("Shortcut", GoTheme.ROLE_MICRO)
	_shortcut.add_theme_color_override(&"font_color", GoUi.color(GoTheme.MUTED))
	_face.add_child(_shortcut)
	_quantity_badge = PanelContainer.new()
	_quantity_badge.name = "QuantityBadge"
	_quantity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_quantity_badge)
	_quantity = _line("Quantity", GoTheme.ROLE_MICRO)
	_quantity_badge.add_child(_quantity)

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
	var px := maxi(8, roundi(visual_size * 0.52))   # 배지 배치라 아이콘이 더 크다
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
	_face.position = Vector2((box - visual) * 0.5, (box_y - visual) * 0.5)
	_face.size = Vector2(visual, visual)
	# 아이콘은 판 전체를 쓰고 가운데에 놓인다 — 배지가 모서리에 걸칠 뿐 자리를 뺏지 않는다.
	_icon.position = Vector2.ZERO
	_icon.size = Vector2(visual, visual)
	# 남은 시간은 아이콘 **위에** 가운데로 — 그 동안 아이콘은 흐려진다(`refresh`).
	var timer_size := _timer_badge.get_combined_minimum_size()
	_timer_badge.size = timer_size
	_timer_badge.position = ((Vector2(visual, visual) - timer_size) * 0.5).round()
	# 단축키: 왼쪽 위 모서리, 자연 크기.
	var shortcut_size := _shortcut.get_combined_minimum_size()
	_shortcut.position = Vector2(3.0, 1.0)
	_shortcut.size = shortcut_size
	_shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 수량 배지: 오른쪽 아래 모서리에 걸친다.
	var badge_size := _quantity_badge.get_combined_minimum_size()
	_quantity_badge.size = badge_size
	_quantity_badge.position = Vector2(visual - badge_size.x + 2.0, visual - badge_size.y + 2.0)


## 색·글자를 지금 상태에 맞춘다.
func refresh() -> void:
	if not is_instance_valid(_face): return
	var color := accent if accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var lit := _cooldown_left > 0.0 or not timer_text.is_empty()
	var empty := quantity == 0
	var faded := empty or disabled

	# 🛑 흐리게 만들 때 **알파를 곱하지 않는다**(`modulate.a = 0.55` 였다) — 밝은 테마에서는 이미 옅은
	#    색에 곱해져 칸이 통째로 **사라진다**(2026-09-13 라이트 갤러리 실측: 빈 슬롯이 안 보였다).
	#    대신 색을 흐린 쪽으로 **옮긴다**. 어느 테마에서도 "흐리지만 보인다" 가 된다.
	var face_ink := GoUi.color(GoTheme.MUTED) if faded else color
	var style := GoUi.skin().slot_box(face_ink, lit)
	_face.add_theme_stylebox_override(&"panel", style)

	# 🛑 글자는 **이 판 위에서** 읽혀야 한다. 판을 어떻게 칠할지는 스킨이 정하므로 — 호스트가 자기
	#    스킨에서 강조색으로 꽉 채울 수도 있다 — 글자색을 고정해 두면 그 순간 사라진다
	#    (2026-09-13 실측: 문서대로 만든 커스텀 스킨에서 수량이 1.70:1, 빈 칸이 1.29:1 이었다).
	#    쿨다운이 도는 기본 슬롯에서도 빈 칸 수량이 3.97:1 로 이미 기준 아래였다.
	var on_face := GoSkin.blend(GoSkin.box_background(style), GoUi.color(GoTheme.SURFACE_SOFT))

	# 🛑 **아이콘도 글자와 같은 요구를 받는다.** `Color.WHITE` 로 고정되어 있어 밝은 테마에서는
	#    흰 물약이 흰 판에 통째로 묻혔다(2026-09-13 라이트 갤러리 실측 — 네 칸 중 셋이 윤곽만 남았다).
	#    다만 아이콘 세트가 자기 색(`tint`)을 정해 두었다면 그 뜻을 존중한다 — 색이 있는 그림을
	#    덧칠해 망치지 않는다.
	#    🛑 흰색 `tint` 는 곱셈의 항등원이라 **색을 정하지 않은 것과 결과가 같다** — 정한 것으로 보면
	#       기본 세트가 통째로 이 분기에 걸린다(실제로 걸렸다: 기본 `.tres` 에 흰색이 박혀 있었다).
	var icons := GoUi.icons()
	if icons != null and icons.tint.a > 0 and not icons.tint.is_equal_approx(Color.WHITE):
		_icon.modulate = Color.WHITE
	else:
		_icon.modulate = GoUi.skin().readable_on(
			GoUi.color(GoTheme.MUTED) if faded else GoUi.color(GoTheme.TEXT), on_face)
		# 🛑 쿨다운 중에는 아이콘을 **판 색 쪽으로 물린다** — 그 위에 얹힌 남은 시간이 주인공이다.
		#    알파를 곱하지 않고 색을 섞는다(밝은 테마에서 알파는 칸을 통째로 지운다).
		if lit: _icon.modulate = on_face.lerp(_icon.modulate, 0.45)

	_quantity_badge.visible = quantity != NONE
	if _quantity_badge.visible:
		_quantity.text = GoUi.text(&"slot_unknown") if quantity == UNKNOWN \
			else GoUi.text(&"slot_quantity").format({"count": GoBar.format_amount(quantity)})
		var badge := GoUi.skin().badge_box(face_ink)
		_quantity_badge.add_theme_stylebox_override(&"panel", badge)
		# 글자는 **배지 판 위에서** 읽혀야 한다 — 슬롯 판이 아니라.
		var on_badge := GoSkin.blend(GoSkin.box_background(badge), on_face)
		_quantity.add_theme_color_override(&"font_color", GoUi.skin().readable_on(
			GoUi.color(GoTheme.MUTED) if empty else GoUi.color(GoTheme.TEXT), on_badge))
		_fit()

	var seconds := ""
	if not timer_text.is_empty(): seconds = timer_text
	elif _cooldown_left > 0.0: seconds = "%ds" % ceili(_cooldown_left)
	_timer_badge.visible = not seconds.is_empty()
	_timer.text = seconds
	if _timer_badge.visible:
		var timer_badge := GoUi.skin().badge_box(color)
		_timer_badge.add_theme_stylebox_override(&"panel", timer_badge)
		var on_timer := GoSkin.blend(GoSkin.box_background(timer_badge), on_face)
		_timer.add_theme_color_override(&"font_color", GoUi.skin().readable_on(color, on_timer))
		_fit()

	_shortcut.visible = not shortcut_label.is_empty()
	_shortcut.text = shortcut_label
	_shortcut.add_theme_color_override(&"font_color",
		GoUi.skin().readable_on(GoUi.color(GoTheme.MUTED), on_face))

	_fit()


## 이 슬롯 자신의 사각 터치 — 이웃과 나누기 전의 판정이다.
## 🛑 수량 표시("×3")도 번역 키를 거친다 — 언어가 바뀌면 다시 만든다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()


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
