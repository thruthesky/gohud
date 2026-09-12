## 💬 **게임을 멈추지 않는 질문 카드.** 스크림이 없고 카드 영역만 입력을 받는다.
##
## 파티 초대·거래 요청처럼 "지금 답하지 않아도 계속 놀 수 있는" 물음에 쓴다.
## 확인/취소로 **막아야 하는** 것은 `GoDialogs`, 답이 필요 없는 알림은 `GoNotice` 다.
##
## ```gdscript
## var card := GoPromptCard.new()
## card.set_title("%s 님이 파티에 초대했습니다" % who)
## card.set_actions([
##     {"text": "수락", "action": _accept, "primary": true},
##     {"text": "거절", "action": _decline},
## ])
## card.fit_width(320)
## hud.add_child(card)
## ```
##
## 배치(어디에 얼마나 크게)는 **소유한 화면**이 정한다 — 이 카드는 색·여백·버튼 규격만 안다.
@tool
class_name GoPromptCard
extends PanelContainer

signal closed

var title_label: Label
var subtitle_label: Label
var icon_slot: Control
var actions: HBoxContainer
var close_button: GoIconButton

## 보일 때 페이드인 — 전투 화면 위에 툭 튀어나오지 않게. 크기·위치는 즉시 잡힌다.
var fade_in := true

var _column: VBoxContainer
var _head: HBoxContainer
var _title_key := ""
var _title_args := {}
var _subtitle_key := ""
var _subtitle_args := {}
var _action_shape := ""
var _accent := Color.TRANSPARENT
var _fade: Tween
var _boxed_icon := false


func _init() -> void:
	name = "PromptCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_column = GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	_head = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	_head.name = "Head"
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_head)

	icon_slot = Control.new()
	icon_slot.name = "Icon"
	icon_slot.visible = false
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(icon_slot)

	var texts := GoStyle.column(0)
	texts.name = "Texts"
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(texts)

	title_label = GoStyle.label("")
	title_label.name = "Title"
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(title_label)

	subtitle_label = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	subtitle_label.name = "Subtitle"
	# 상태 한 줄 — 줄바꿈되면 카드가 위아래로 커져 화면을 더 가린다. 기본은 한 줄.
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle_label.clip_text = true
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_label.visible = false
	texts.add_child(subtitle_label)

	close_button = _make_close_button()
	close_button.icon_name = GoIconSet.CLOSE
	close_button.tooltip_text_name = &"close"
	close_button.visible = false
	close_button.pressed.connect(func() -> void: closed.emit())
	_head.add_child(close_button)

	actions = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	actions.name = "Actions"
	actions.visible = false
	_column.add_child(actions)
	hide()


func _ready() -> void:
	theme = GoUi.theme()
	add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD, _accent))
	set_title_lines(2)


## 카드 테두리의 의미색. 투명이면 기본 표면.
func set_accent(accent: Color) -> void:
	_accent = accent
	add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD, accent))
	if _boxed_icon: _restyle_icon()


func set_title_key(key: String, arguments := {}) -> void:
	_title_key = key
	_title_args = arguments.duplicate()
	title_label.text = tr(key).format(arguments)


## 사람 이름·서버 값처럼 번역하지 않는 문구.
func set_title(value: String) -> void:
	_title_key = ""
	title_label.text = value


func set_subtitle_key(key: String, arguments := {}) -> void:
	_subtitle_key = key
	_subtitle_args = arguments.duplicate()
	subtitle_label.visible = not key.is_empty()
	subtitle_label.text = tr(key).format(arguments) if not key.is_empty() else ""


func set_subtitle(value: String) -> void:
	_subtitle_key = ""
	subtitle_label.visible = not value.is_empty()
	subtitle_label.text = value


## 제목 줄 수. 🛑 줄바꿈 라벨은 폭이 정해지기 전 높이 0 으로 잡혀 카드가 접힌다 —
##    최소 한 줄 높이를 미리 준다.
func set_title_lines(lines: int) -> void:
	_set_lines(title_label, lines)


## 부제 줄 수. 기본은 한 줄이지만, **다음에 할 일을 적는 안내**처럼 문장을 다 보여 줘야 하는
## 카드도 있다 — 한 줄이면 중요한 조건이 중간에서 잘린다.
func set_subtitle_lines(lines: int) -> void:
	_set_lines(subtitle_label, lines)


func _set_lines(node: Label, lines: int) -> void:
	if lines <= 1:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		node.clip_text = true
		node.max_lines_visible = 1
	else:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.clip_text = false
		node.max_lines_visible = lines
	node.custom_minimum_size.y = float(node.get_line_height())


## 제목 앞의 아이콘. 빈 이름이면 숨긴다.
## `boxed` 는 아이콘을 accent 색 원형 배지 안에 넣는다.
func set_icon(icon: StringName, ink := Color.TRANSPARENT, boxed := false) -> void:
	for child in icon_slot.get_children(): child.queue_free()
	icon_slot.visible = not icon.is_empty()
	_boxed_icon = boxed
	if icon.is_empty(): return
	var diameter := float(GoUi.config.min_touch_size) - 4.0
	var glyph_size := roundi(diameter * 0.5) if boxed else GoUi.font_size(GoTheme.ROLE_TITLE)
	var glyph := GoUi.icons().node(icon, glyph_size, ink)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_slot.add_child(glyph)
	icon_slot.custom_minimum_size = Vector2(diameter, diameter) if boxed else Vector2(glyph_size, glyph_size)
	icon_slot.set_meta(&"go_ink", ink)
	if boxed: _restyle_icon()


func _restyle_icon() -> void:
	var accent := _accent if _accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var diameter := float(GoUi.config.min_touch_size) - 4.0
	var panel := icon_slot.get_node_or_null(^"Disc") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "Disc"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_slot.add_child(panel)
		icon_slot.move_child(panel, 0)
	panel.add_theme_stylebox_override(&"panel", GoStyle.disc(diameter, accent))


func set_closable(on: bool) -> void:
	close_button.visible = on


## 동작 버튼 목록. 항목: `{"key"|"text", "action": Callable, "primary": bool, "disabled": bool, "name": String}`.
##
## 🛑 같은 구성(문구·종류·이름)이면 버튼을 **다시 만들지 않는다** — 서버 명단이 1초마다 와서
##    카드를 새로 그리는 동안 누르고 있던 버튼이 사라지면 탭이 유실된다. 동작·잠금만 갱신한다.
func set_actions(list: Array) -> void:
	var shape := ""
	for item in list:
		shape += "%s|%s|%s|%s;" % [item.get("key", ""), item.get("text", ""),
			bool(item.get("primary", false)), item.get("name", "")]
	if shape == _action_shape and actions.get_child_count() == list.size():
		for i in list.size():
			var existing := actions.get_child(i) as Button
			if existing == null: continue
			existing.set_meta(&"go_action", list[i].get("action", Callable()))
			existing.disabled = bool(list[i].get("disabled", false))
		return
	_action_shape = shape
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	for item in list:
		var tone := GoStyle.Tone.PRIMARY if bool(item.get("primary", false)) else GoStyle.Tone.NORMAL
		if bool(item.get("danger", false)): tone = GoStyle.Tone.DANGER
		var node: Button
		if item.has("key"): node = GoStyle.button_key(str(item.key), Callable(), tone)
		else: node = GoStyle.button(str(item.get("text", "")), Callable(), tone)
		node.custom_minimum_size.y = GoUi.config.min_touch_size
		node.clip_text = true
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		node.disabled = bool(item.get("disabled", false))
		node.set_meta(&"go_action", item.get("action", Callable()))
		node.pressed.connect(func() -> void:
			var action: Callable = node.get_meta(&"go_action", Callable())
			if action.is_valid(): action.call())
		if item.has("name"): node.name = str(item.name)
		actions.add_child(node)
	actions.visible = not list.is_empty()


## 소유한 화면이 폭을 정한다. 높이는 내용에 맞춰 스스로 잡는다.
##
## 🛑 줄바꿈 제목의 실제 높이는 폭이 정해진 **다음 프레임**에야 나온다 — 그 사이 소유 화면이
##    잰 높이로 다른 것을 배치하면 카드가 한 프레임 뒤 커져 겹친다. 그래서 제목의 자연 폭을
##    폰트로 재서 줄 수를 미리 예측해 최소 높이에 반영한다.
func fit_width(width: float) -> void:
	custom_minimum_size.x = width
	size.x = width
	_predict_height(title_label, width)
	_predict_height(subtitle_label, width)
	reset_size()


func _predict_height(node: Label, width: float) -> void:
	var line := float(node.get_line_height())
	var lines := maxi(1, node.max_lines_visible)
	if node.autowrap_mode == TextServer.AUTOWRAP_OFF or lines <= 1 or not node.visible:
		node.custom_minimum_size.y = line
		return
	var panel := get_theme_stylebox(&"panel")
	var available := width - panel.get_margin(SIDE_LEFT) - panel.get_margin(SIDE_RIGHT)
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL))
	if icon_slot.visible: available -= maxf(icon_slot.custom_minimum_size.x, icon_slot.size.x) + gap
	if close_button.visible: available -= float(GoUi.config.min_touch_size) + gap
	var font := node.get_theme_font(&"font")
	var natural := 0.0
	if font != null:
		natural = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			node.get_theme_font_size(&"font_size")).x
	var needed := clampi(ceili(natural / maxf(1.0, available)), 1, lines)
	node.custom_minimum_size.y = line * needed


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not _title_key.is_empty(): title_label.text = tr(_title_key).format(_title_args)
		if not _subtitle_key.is_empty(): subtitle_label.text = tr(_subtitle_key).format(_subtitle_args)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and fade_in and is_inside_tree():
		_fade = GoStyle.fade(self, _fade, visible)


## 닫기 버튼을 만든다. 🔑 호스트가 `GoIconButton` 의 서브클래스(자기 그림·크기)를 쓰고 싶으면 자식에서 덮어쓴다.
func _make_close_button() -> GoIconButton:
	return GoIconButton.new()
