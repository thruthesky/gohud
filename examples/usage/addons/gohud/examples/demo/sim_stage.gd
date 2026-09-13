## 🎬 한 번에 **한 가지만** 보여 주는 무대.
##
## 장면이 바뀔 때마다 비우고 다시 짓는다. 폭은 폰 한 대만큼으로 묶어 둔다 — gohud 가 겨냥하는
## 화면이 그것이고, 좁은 폭에서 멀쩡한 것은 넓은 폭에서도 멀쩡하기 때문이다.
class_name SimStage
extends PanelContainer

## 화면 전체를 덮는 장면(폼·앵커)에서 "위젯 목록으로" 를 눌렀다 — 사이드바가 가려져 있어 장면이 대신 알린다.
signal leave_requested

const WIDTH := 560.0

## 장면이 채우는 곳.
var body: VBoxContainer
## 본문 스크롤 — 장면이 직접 굴리기도 한다.
var scroll: GoScroll
## HUD·시트처럼 **무대 위에 떠야 하는** 것이 붙는 자리(스크롤되지 않는다).
var overlay: Control

var _column: VBoxContainer
var _badge: Label
var _title: Label
var _note: Label
var _fade: Tween


func _init() -> void:
	name = "Stage"
	theme = GoUi.theme()
	theme_type_variation = GoTheme.VAR_CARD
	custom_minimum_size.x = WIDTH
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var surface := GoStyle.box(GoTheme.BOX_CARD).duplicate() as StyleBoxFlat
	surface.bg_color = Color("#151f30")
	surface.border_color = Color("#2d435b")
	surface.set_content_margin_all(20)
	surface.set_corner_radius_all(20)
	add_theme_stylebox_override(&"panel", surface)
	_column = GoStyle.column(GoUi.metric(GoTheme.GAP))
	add_child(_column)

	var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var accent := GoUi.color(GoTheme.ACCENT)
	_badge = GoStyle.label("00", GoTheme.ROLE_COMPACT, GoUi.skin().chip_ink(accent))
	GoStyle.natural_width(_badge)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.custom_minimum_size = Vector2(40, 26)
	_badge.add_theme_stylebox_override(&"normal", GoUi.skin().chip_box(accent))
	head.add_child(_badge)
	_title = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	_title.add_theme_font_size_override(&"font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_column.add_child(head)

	_note = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	_column.add_child(_note)
	_column.add_child(GoStyle.divider())

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(content)
	scroll = GoScroll.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scroll)
	body = GoStyle.column(GoUi.metric(GoTheme.GAP))
	scroll.add_child(body)

	# 🛑 떠 있는 것은 스크롤 **밖**이다 — 안에 두면 본문과 함께 밀려 올라간다.
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(overlay)
	overlay.resized.connect(_layout_floats)


## 새 장면을 연다 — 비우고, 머리글을 갈고, 옅게 떠오른다.
func open(number: String, title: String, note: String) -> void:
	clear()
	_badge.text = number
	_badge.visible = not number.is_empty()
	_title.text = title
	_note.text = note
	_note.visible = not note.is_empty()
	scroll.scroll_vertical = 0
	if is_instance_valid(_fade): _fade.kill()
	if GoUi.config.reduce_motion: return
	body.modulate.a = 0.0
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(body, "modulate:a", 1.0, 0.28)


## 장면이 남긴 것을 **전부** 치운다.
##
## 🛑 본문과 떠 있는 것만으로는 모자란다 — 확인창·시트처럼 장면이 무대에 직접 붙인 것은
##    화면 전체를 덮는 제 레이어를 들고 있어서, 남겨 두면 다음 장면을 가린 채로 산다.
func clear() -> void:
	if is_instance_valid(_fade): _fade.kill()
	body.modulate.a = 1.0
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	for child in get_children():
		if child != _column:
			remove_child(child)
			child.queue_free()


## 본문에 넣고 그대로 돌려준다 — `var button := stage.add(GoStyle.button(…))` 처럼 쓴다.
func add(node: Control) -> Control:
	body.add_child(node)
	return node


## 제목 한 줄 + 이어지는 것들을 한 묶음으로.
func group(title: String) -> VBoxContainer:
	body.add_child(GoStyle.section(title, false))
	var box := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	body.add_child(box)
	return box


## 무대 위에 띄운다(HUD 막대·슬롯·알림 카드). `preset` 은 `Control.PRESET_TOP_LEFT` 같은 자리.
##
## 🛑 여기서 `GoHudAnchor` 를 쓰지 않는다 — 그것은 **화면(창) 네 귀퉁이**에 안전 영역까지 지켜
##    붙이는 위젯이라, 창 크기로 잡은 자리가 무대 좌표로 다시 해석되어 화면 밖으로 밀려난다
##    (2026-09-12 실측: 슬롯이 x=2108 로 나갔다). 실제 게임에서는 화면 루트에 `GoHudAnchor` 를
##    쓰는 것이 맞고, 무대 안에서만 이렇게 흉내 낸다.
func float_at(node: Control, preset: int, margin := 10) -> Control:
	node.set_meta(&"sim_float", {"preset": preset, "margin": margin})
	overlay.add_child(node)
	node.minimum_size_changed.connect(_layout_floats.call_deferred)
	_layout_floats.call_deferred()
	return node


func _layout_floats() -> void:
	for node in overlay.get_children():
		if not node is Control or not node.has_meta(&"sim_float"): continue
		var spec: Dictionary = node.get_meta(&"sim_float")
		var align := Vector2.ZERO
		match spec.preset:
			Control.PRESET_BOTTOM_RIGHT: align = Vector2.ONE
			Control.PRESET_CENTER_RIGHT: align = Vector2(1.0, 0.5)
			Control.PRESET_CENTER_TOP: align = Vector2(0.5, 0.0)
		var margin := Vector2.ONE * float(spec.margin)
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.size = node.get_combined_minimum_size()
		node.position = margin + (overlay.size - node.size - margin * 2.0) * align
