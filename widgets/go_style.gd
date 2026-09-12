## 🧱 위젯 **공장**. 버튼·라벨·줄·칸·카드를 같은 규격으로 찍어 낸다.
##
## ## 왜 팩토리인가
## `Button.new()` 를 직접 쓰면 화면마다 여백·높이·줄바꿈이 조금씩 달라진다. 그 차이는 코드
## 리뷰로 잡히지 않고 스크린샷으로만 보인다. 그래서 **만드는 자리를 하나로** 모은다.
##
## ```gdscript
## var row := GoStyle.row()
## row.add_child(GoStyle.button("저장", _on_save, true))
## row.add_child(GoStyle.button("취소", _on_cancel))
## ```
##
## ## 🛑 규칙
## - 모든 치수는 **토큰**에서 온다(`GoUi.metric`). 숫자를 직접 쓰지 않는다.
## - 터치 대상은 `min_touch_size`(48dp) 하한을 지킨다 — 보이는 크기는 더 작아도 된다.
## - 긴 문구는 줄바꿈한다. 한 줄로 뻗으면 최소 폭이 화면을 넘긴다.
@tool
class_name GoStyle
extends RefCounted

# ── 기본 뼈대 ──────────────────────────────────────────────────────────

## 세로 줄. `spacing` 이 음수면 토큰 `gap`.
static func column(spacing := -1) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)
	return node


## 가로 줄.
static func row(spacing := -1) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)
	return node


## 🔑 **넘치면 다음 줄로 흐르는** 가로 줄. 칩·필터·태그처럼 개수가 정해지지 않은 것에 쓴다.
## 좁은 화면에서 `row` 는 자식을 찌그러뜨리지만 이것은 줄을 늘린다.
##
## `alignment` 로 줄을 가운데·끝으로 모을 수 있다. 🛑 그때 **마지막 줄**은 따로 정한다
## (`last_wrap_alignment`) — 가운데 정렬 목록의 마지막 한두 개만 가운데 떠 있으면 어색하다.
static func wrap_row(spacing := -1, alignment := FlowContainer.ALIGNMENT_BEGIN,
		last_line := FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN) -> HFlowContainer:
	var node := HFlowContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.alignment = alignment
	node.last_wrap_alignment = last_line
	var value := GoUi.metric(GoTheme.GAP_SMALL) if spacing < 0 else spacing
	node.add_theme_constant_override(&"h_separation", value)
	node.add_theme_constant_override(&"v_separation", value)
	node.child_entered_tree.connect(natural_width)
	return node


## 흐르는 줄에 들어가는 것은 **자연 폭**이어야 한다.
##
## 🛑 줄바꿈을 켠 채 두면 최소 폭이 거의 0 이 되고, 흐르는 줄은 그 최소 폭으로 칸을 잡는다 —
##    버튼 하나가 한 글자 폭으로 쪼그라들어 글자가 **세로로 한 자씩** 내려간다
##    (2026-09-12 폰 세로 스크린샷 실측: `Primary` 가 `Pri m ary` 로 보였다).
##    표식(`go_no_wrap`)을 남겨 `form()` 이 줄바꿈을 도로 켜지 않게 한다.
static func natural_width(node: Node) -> void:
	if not (node is Control): return
	var control := node as Control
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.set_meta(&"go_no_wrap", true)
	if control is Button: (control as Button).autowrap_mode = TextServer.AUTOWRAP_OFF
	elif control is Label: (control as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	for child in control.get_children(): natural_width(child)


## 📂 **접이식 섹션**(Godot 4.5+ `FoldableContainer`). 설정 화면의 "고급" 처럼 늘 펼쳐 둘 필요가
## 없는 묶음에 쓴다. 같은 `FoldableGroup` 을 주면 한 번에 하나만 펼쳐진다(아코디언).
##
## 🛑 긴 설정 목록을 스크롤 하나로 늘어놓지 않는다 — 폰에서 원하는 항목까지 한참 내려가야 한다.
##    제목 줄 **전체**가 탭 영역이라 작은 화살표를 조준할 필요가 없다(엔진 노드의 동작이다).
static func foldable(title: String, folded := false, group: FoldableGroup = null, translate := true) -> FoldableContainer:
	var node := FoldableContainer.new()
	node.name = "Foldable"
	node.theme = GoUi.theme()
	node.title = title
	node.folded = folded
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	if group != null: node.foldable_group = group
	return node


## 안쪽 여백 한 겹.
static func padding(amount := -1) -> MarginContainer:
	var node := MarginContainer.new()
	insets(node, amount)
	return node


## 이미 있는 `MarginContainer` 의 네 변 여백을 한 번에.
static func insets(node: MarginContainer, amount := -1) -> void:
	var value := GoUi.metric(GoTheme.PADDING) if amount < 0 else amount
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		node.add_theme_constant_override(side, value)


## 컨테이너의 자식 간격을 토큰으로.
static func gap(node: Container, token := GoTheme.GAP) -> void:
	var value := GoUi.metric(token)
	if node is GridContainer or node is FlowContainer:
		node.add_theme_constant_override(&"h_separation", value)
		node.add_theme_constant_override(&"v_separation", value)
	else:
		node.add_theme_constant_override(&"separation", value)


## 남는 공간을 먹는 빈 칸 — 줄의 한쪽을 끝으로 밀 때.
static func spacer(minimum := 0.0) -> Control:
	var node := Control.new()
	node.name = "Spacer"
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2(minimum, minimum)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 1dp 구분선. 🛑 `HSeparator` 를 쓰지 않는다 — 기본 테마의 여백까지 딸려 와 줄이 두꺼워진다.
static func divider(vertical := false) -> Control:
	var line := ColorRect.new()
	line.name = "Divider"
	line.color = GoUi.color(GoTheme.BORDER)
	if vertical:
		line.custom_minimum_size = Vector2(1, 0)
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		line.custom_minimum_size = Vector2(0, 1)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## 🔑 **최소 카드 폭을 지키며 열 수를 스스로 정하는** 격자.
##
## 고정 열 수는 반드시 어느 화면에선가 깨진다 — 3열은 폰에서 글자가 뭉개지고, 1열은 데스크톱
## 에서 허전하다. 이 격자는 폭이 바뀔 때마다 `floor(폭 / 최소카드폭)` 로 열을 다시 센다.
##
## ```gdscript
## var grid := GoStyle.responsive_grid(160)   # 카드가 최소 160dp 는 되게
## ```
static func responsive_grid(min_cell_width := 160.0, spacing := -1) -> GridContainer:
	var node := GridContainer.new()
	node.name = "ResponsiveGrid"
	node.columns = 1
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing
	node.add_theme_constant_override(&"h_separation", value)
	node.add_theme_constant_override(&"v_separation", value)
	node.set_meta(&"go_min_cell", min_cell_width)
	var refit := func() -> void:
		if not is_instance_valid(node): return
		var cell: float = node.get_meta(&"go_min_cell", 160.0)
		var separation := float(node.get_theme_constant(&"h_separation"))
		# 열 n 개가 들어가려면 n*cell + (n-1)*separation <= 폭 이어야 한다.
		var columns := int(floor((node.size.x + separation) / maxf(1.0, cell + separation)))
		node.columns = maxi(1, columns)
	node.resized.connect(refit)
	refit.call_deferred()
	return node


## 비율을 지키는 상자(썸네일·미니맵·초상화).
static func aspect(ratio := 1.0) -> AspectRatioContainer:
	var node := AspectRatioContainer.new()
	node.ratio = ratio
	node.stretch_mode = AspectRatioContainer.STRETCH_WIDTH_CONTROLS_HEIGHT
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


# ── 글자 ───────────────────────────────────────────────────────────────

## 글자 역할과 색을 입힌다. `RichTextLabel` 도 받는다.
static func typography(node: Control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> void:
	node.theme = GoUi.theme()
	node.set_meta(&"go_text_role", role)
	if node is RichTextLabel:
		# 변형이 없는 노드 — 크기를 직접 박는다.
		var size := GoUi.font_size(role)
		for key in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
			node.add_theme_font_size_override(key, size)
		if ink.a > 0: node.add_theme_color_override(&"default_color", ink)
		return
	# 🛑 크기는 **변형**으로 입힌다(`GoCaptionLabel` …, 본문은 변형 없음) — override 를 박으면 그 라벨은 테마가
	#    바뀌어도(모바일 축소·테마 교체) 따라오지 않는다(2026-09-12 발견 — `set_mobile_type` 이 라벨을 다시
	#    입히지 않았다). 테마 밖 값(`base_font_size`)을 요구할 때만 override 다.
	var type: StringName = GoTheme.ROLE_TYPES.get(role, &"Label")
	if type == &"Label" or type == &"Button": node.theme_type_variation = &""
	else: node.theme_type_variation = type
	if GoUi.config.base_font_size > 0 and role == GoTheme.ROLE_BODY:
		node.add_theme_font_size_override(&"font_size", GoUi.config.base_font_size)
	else:
		node.remove_theme_font_size_override(&"font_size")
	if ink.a > 0: node.add_theme_color_override(&"font_color", ink)


## **번역 키**를 담는 라벨 — 언어가 바뀌면 엔진이 알아서 다시 그린다.
static func label_key(key: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label:
	var node := Label.new()
	node.theme = GoUi.theme()
	node.text = key
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	if GoUi.config.autowrap_text: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typography(node, role, ink)
	return node


## **그대로 보여 줄 글자** — 사람 이름·서버 값·이미 번역된 문구.
static func label(text: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label:
	var node := label_key(text, role, ink)
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return node


## 섹션 제목 한 줄(작고 흐린 대문자 느낌의 구분 머리말).
static func section(text_or_key: String, translate := true) -> Label:
	var node := label_key(text_or_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
		else label(text_or_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	node.name = "Section"
	return node


# ── 버튼 ───────────────────────────────────────────────────────────────

enum Tone { NORMAL, PRIMARY, DANGER, BARE, COMPACT }

## 이미 있는 버튼에 gohud 규격을 입힌다(씬에서 만든 버튼도 받는다).
static func style_button(node: Button, tone := Tone.NORMAL) -> void:
	node.theme = GoUi.theme()
	match tone:
		Tone.PRIMARY: node.theme_type_variation = GoTheme.VAR_PRIMARY_BUTTON
		Tone.DANGER: node.theme_type_variation = GoTheme.VAR_DANGER_BUTTON
		Tone.BARE: node.theme_type_variation = GoTheme.VAR_BARE_BUTTON
		Tone.COMPACT: node.theme_type_variation = GoTheme.VAR_COMPACT_BUTTON
		_: node.theme_type_variation = GoTheme.VAR_BUTTON
	var compact := tone == Tone.COMPACT or tone == Tone.BARE
	# 🛑 `MOUSE_FILTER_PASS` — 스크롤 안의 버튼은 손가락 끌기를 `ScrollContainer` 에 넘겨야 한다.
	#    STOP 이면 목록 위에서 시작한 스크롤이 먹히지 않는다.
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	if GoUi.config.autowrap_text: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if tone == Tone.BARE:
		# 씬에서 만든 버튼에 남아 있는 판(override)을 지운다 — 맨 버튼은 테마 변형이 그리는 것이 전부다.
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			node.remove_theme_stylebox_override(state)
		return
	# 🛑 작은 버튼(COMPACT)은 **폭 플래그를 건드리지 않는다** — 부르는 쪽이 SHRINK_BEGIN/END 로 놓는 경우가 많고,
	#    여기서 EXPAND_FILL 을 박으면 먼저 둔 값을 덮어쓴다(2026-09-12, 파생 게임 소비처 5곳). 높이는 터치 하한.
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH if compact else GoTheme.BUTTON_HEIGHT)
	if not compact: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## 번역 키를 담는 버튼.
static func button_key(key: String, action := Callable(), tone := Tone.NORMAL) -> Button:
	var node := Button.new()
	node.text = key
	style_button(node, tone)
	if action.is_valid(): node.pressed.connect(action)
	return node


## 그대로 보여 줄 글자의 버튼.
static func button(text: String, action := Callable(), tone := Tone.NORMAL) -> Button:
	var node := button_key(text, action, tone)
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return node


## 🔑 **아이콘만 있는 버튼**. 보이는 크기는 `visual`, 터치는 토큰 `touch` 까지 노드 밖으로 넓어진다.
## 세트가 폰트든 텍스처든 같은 호출이다.
static func icon_button(icon: StringName, action := Callable(), visual := -1) -> GoIconButton:
	var node := GoIconButton.new()
	node.visual_size = GoUi.metric(GoTheme.TOUCH) - 12 if visual < 0 else visual
	node.set_icon_name(icon)
	if action.is_valid(): node.pressed.connect(action)
	return node


## 버튼에 아이콘을 붙인다 — 텍스처 세트면 `Button.icon`, 폰트 세트면 자식 라벨로 간다.
## 🛑 한 버튼에 아이콘 폰트와 본문 폰트를 같이 쓸 방법은 자식 라벨뿐이다(`text` 의 폰트는 하나다).
static func apply_icon(node: Button, icon: StringName, size := -1, ink := Color.TRANSPARENT) -> void:
	var px := GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size
	var found := GoUi.icons().texture(icon)
	if found != null:
		node.icon = found
		node.expand_icon = true
		# 🛑 `icon_max_width` 없이 `expand_icon` 만 켜면 아이콘이 버튼 높이만큼 커진다.
		node.add_theme_constant_override(&"icon_max_width", px)
		if ink.a > 0: node.add_theme_color_override(&"icon_normal_color", ink)
		return
	var glyph := GoUi.icons().node(icon, px, ink)
	glyph.name = "IconGlyph"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE)
	node.add_child(glyph)


## 🔑 **아이콘 한 개 + 글자 한 줄의 목록 항목.** 메뉴·설정처럼 세로로 쌓는 곳에 쓴다.
##
## 2열 격자보다 눈이 덜 흔들리고, 줄마다 아이콘이 있어 글을 읽기 전에 무엇인지 알아본다.
## `sub_key` 를 주면 제목 아래 한 줄 요약이 붙는다(작고 흐린 글씨).
##
## 🛑 줄 **전체**가 탭 영역이다 — 요약도 버튼 안에 있어야 한다.
static func list_button(icon: StringName, key: String, action := Callable(),
		ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"") -> Button:
	return list_row(Button.new(), icon, key, action, ink, sub_key, translate, trailing)


## 이미 있는 버튼을 같은 목록 항목으로 꾸민다 — 노드·이름·연결을 그대로 둔다.
## `trailing` 은 줄 오른쪽 끝의 아이콘(예: `GoIconSet.CHEVRON_RIGHT` — 다음 화면으로 간다는 표시). 글자 줄과
## 세로 가운데가 맞도록 같은 행 안에 둔다(좌표로 놓지 않는다).
static func list_row(node: Button, icon: StringName, key: String, action := Callable(),
		ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"") -> Button:
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_LIST_BUTTON
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = ""            # 글자는 아래 라벨이 그린다 — 씬에서 만든 버튼의 옛 text 를 비운다.
	node.clip_text = false
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inset := padding(GoUi.metric(GoTheme.GAP))
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override(&"margin_top", GoUi.metric(GoTheme.GAP_TINY))
	inset.add_theme_constant_override(&"margin_bottom", GoUi.metric(GoTheme.GAP_TINY))
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(inset)

	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	inset.add_child(line)

	if not icon.is_empty():
		var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.LIST_GLYPH),
			ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY))
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(glyph)

	var title := label_key(key, GoTheme.ROLE_BODY, ink) if translate else label(key, GoTheme.ROLE_BODY, ink)
	# 🛑 버튼의 자동 번역을 껐으므로(글자는 이 라벨이 그린다) 자식이 그것을 물려받지 않게 못박는다 —
	#    INHERIT 로 두면 목록에 번역 키가 그대로 뜬다.
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if sub_key.is_empty():
		title.size_flags_vertical = Control.SIZE_EXPAND_FILL
		line.add_child(title)
	else:
		# 두 줄 항목 — 제목과 요약을 한 칸에 세로로 쌓는다. 요약은 한 단계 물러난 색·크기다.
		var stack := column(GoUi.metric(GoTheme.GAP_TINY))
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		stack.add_child(title)
		var sub := label_key(sub_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
			else label(sub_key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
		stack.add_child(sub)
		line.add_child(stack)

	if not trailing.is_empty():
		var tail := GoUi.icons().node(trailing, GoUi.metric(GoTheme.LIST_GLYPH), GoUi.color(GoTheme.MUTED))
		tail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(tail)

	# 🛑 `line` 이 아니라 **`inset`** 을 잰다 — 내용 높이만 맞추면 위아래 여백이 빠져 글자가
	#    항목 아래로 정확히 그만큼 삐져나온다. 한 줄 항목은 터치 하한보다 작아 이 변화가 안 보인다.
	fit_content_height(node, inset)
	if action.is_valid(): node.pressed.connect(action)
	return node


# ── 입력 ───────────────────────────────────────────────────────────────

static func line_edit(placeholder := "", translate_placeholder := false) -> LineEdit:
	var node := LineEdit.new()
	node.theme = GoUi.theme()
	node.placeholder_text = placeholder
	# 🛑 `translate_placeholder` 가 아니면 번역 모드를 **건드리지 않는다**(부모 상속). DISABLED 를 박으면 부모가
	#    번역 중인 폼 안에서 키 이름이 그대로 뜬다(2026-09-12, 파생 게임의 검색 힌트 3곳).
	if translate_placeholder: node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	return node


static func toggle(key := "", translate := true) -> CheckButton:
	var node := CheckButton.new()
	node.theme = GoUi.theme()
	node.text = key
	if translate: node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS   # 아니면 부모 상속
	# 폼 안에서 입력 칸·버튼과 한 줄 높이가 맞도록 버튼 높이를 쓴다(터치 하한보다 크다).
	node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	if GoUi.config.autowrap_text: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func checkbox(key := "", translate := true) -> CheckBox:
	var node := CheckBox.new()
	node.theme = GoUi.theme()
	node.text = key
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate \
		else Node.AUTO_TRANSLATE_MODE_DISABLED
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	return node


static func slider(minimum := 0.0, maximum := 1.0, step := 0.01) -> HSlider:
	var node := HSlider.new()
	node.theme = GoUi.theme()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	return node


static func picker() -> OptionButton:
	var node := OptionButton.new()
	node.theme = GoUi.theme()
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	return node


static func progress(ink := Color.TRANSPARENT) -> ProgressBar:
	var node := ProgressBar.new()
	node.theme = GoUi.theme()
	node.show_percentage = false
	node.custom_minimum_size.y = GoUi.metric(GoTheme.GAP_SMALL)
	if ink.a > 0: tint_progress(node, ink)
	return node


## 막대의 채움 색만 바꾼다. 🛑 테마의 `ProgressBar/fill` 을 **복제해서** 고친다 — 카드 스타일을
##    빌려 쓰면 그 안쪽 여백(12dp)까지 딸려 와 얇은 막대가 두꺼운 덩어리가 된다.
static func tint_progress(bar: ProgressBar, ink: Color) -> void:
	var source: StyleBox = null
	for candidate in [GoUi.theme(), GoUi.DEFAULT_THEME]:
		if candidate != null and candidate.has_stylebox(&"fill", &"ProgressBar"):
			source = candidate.get_stylebox(&"fill", &"ProgressBar")
			break
	var flat := source.duplicate() as StyleBoxFlat if source != null else null
	if flat == null:
		flat = StyleBoxFlat.new()
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	flat.bg_color = ink
	bar.add_theme_stylebox_override(&"fill", flat)


# ── 표면 조각 ──────────────────────────────────────────────────────────

## 카드·패널의 StyleBox **사본**. `accent` 를 주면 테두리에 그 색을 입힌다.
static func box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := GoUi.box(variant) as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = GoUi.color(GoTheme.SURFACE)
	# 🛑 0.5 — 이 값은 gohud 가 파생된 게임의 규범이다. 0.55 로 짰다가 위임 대조 검사에서 잡혔다(2026-09-12).
	if accent.a > 0: style.border_color = Color(accent, 0.5)
	return style


## 게임 화면 위에 **떠 있는** 표면 — 같은 카드에 얕은 그림자를 더한다.
static func floating(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := box(variant, accent)
	style.shadow_color = Color(GoUi.color(GoTheme.SHADOW), 0.35)
	style.shadow_size = GoUi.metric(GoTheme.GAP_SMALL)
	style.shadow_offset = Vector2(0, 2)
	return style


## 원형 배지·아바타 테두리 — accent 를 옅게 채우고 같은 색 링을 두른다.
static func disc(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBoxFlat:
	var style := box(GoTheme.BOX_HUD, accent)
	style.bg_color = Color(accent, fill_alpha)
	style.border_color = Color(accent, edge_alpha)
	style.set_border_width_all(1)
	# 🛑 반지름이 변의 정확히 절반이면(31+31=62) 위아래 모서리가 만나는 자리에 이음매 선이 보인다.
	#    1 만 줄이고 곡선 분할을 올리면 사라진다 — 눈에는 여전히 원이다.
	style.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
	style.corner_detail = 16
	style.set_content_margin_all(0)
	style.shadow_size = 0
	return style


## 테두리가 있는 카드 한 장(내용은 부르는 쪽이 채운다).
static func card(accent := Color.TRANSPARENT) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "Card"
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_CARD
	if accent.a > 0: node.add_theme_stylebox_override(&"panel", box(GoTheme.BOX_CARD, accent))
	return node


## 작은 알약형 표식(상태·태그·수량).
static func chip(text: String, ink := Color.TRANSPARENT, translate := false) -> PanelContainer:
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY)
	var node := PanelContainer.new()
	node.name = "Chip"
	node.theme = GoUi.theme()
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.16)
	style.border_color = Color(color, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	style.corner_detail = 8
	style.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	style.content_margin_right = GoUi.metric(GoTheme.GAP_SMALL)
	style.content_margin_top = GoUi.metric(GoTheme.GAP_TINY)
	style.content_margin_bottom = GoUi.metric(GoTheme.GAP_TINY)
	node.add_theme_stylebox_override(&"panel", style)
	var text_node := label_key(text, GoTheme.ROLE_COMPACT, color) if translate \
		else label(text, GoTheme.ROLE_COMPACT, color)
	text_node.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_node.set_meta(&"go_no_wrap", true)
	text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.add_child(text_node)
	return node


## 아무것도 없을 때 보여 주는 자리 — 아이콘 + 한 줄 설명.
## 🛑 빈 목록을 **빈 채로** 두지 않는다. 사용자는 그것을 고장으로 읽는다.
static func empty_state(icon: StringName, key: String, translate := true) -> Control:
	var wrap := column(GoUi.metric(GoTheme.GAP))
	wrap.name = "EmptyState"
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.TOUCH), GoUi.color(GoTheme.MUTED))
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(glyph)
	var text := label_key(key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
		else label(key, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(text)
	return wrap


# ── 동작 ───────────────────────────────────────────────────────────────

## 등장 페이드. 직전 트윈은 끊는다. `reduce_motion` 이면 즉시 보인다.
static func fade(node: CanvasItem, previous: Tween, shown: bool) -> Tween:
	if previous != null and previous.is_valid(): previous.kill()
	var seconds := GoUi.config.fade_seconds
	if not shown or not node.is_inside_tree() or GoUi.config.reduce_motion or seconds <= 0.0:
		node.modulate.a = 1.0
		return null
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return tween


## `Button` 처럼 **자식에서 최소 높이를 물려받지 않는** 컨트롤을 내용에 맞춰 키운다.
## 줄바꿈·번역·글꼴이 바뀌어도 내용이 카드 밖으로 나가지 않는다.
static func fit_content_height(control: Control, content: Control) -> void:
	var baseline := control.custom_minimum_size.y
	var update := _fit_height.bind(weakref(control), weakref(content), baseline)
	content.minimum_size_changed.connect(update, CONNECT_DEFERRED)
	update.call_deferred()


static func _fit_height(control_ref: WeakRef, content_ref: WeakRef, baseline: float) -> void:
	var control := control_ref.get_ref() as Control
	var content := content_ref.get_ref() as Control
	if control == null or content == null: return
	var height := maxf(baseline, content.get_combined_minimum_size().y)
	if not is_equal_approx(control.custom_minimum_size.y, height):
		control.custom_minimum_size.y = height


## 트리 전체에 폼 규격을 입힌다 — 나중에 추가되는 자식까지 같은 규격이 되게.
##
## 🛑🛑 자손 `Label` 의 줄바꿈을 **보장한다.** 없으면 긴 문장 하나가 한 줄로 뻗고, 그 최소 폭이
##    화면을 넘겨 좌우가 잘린다 — 무슨 화면인지조차 분간할 수 없게 된다.
##    씬마다 손으로 켜는 방식은 **반드시 빠뜨린다.** 그래서 컨테이너가 스스로 보장한다.
static func form(node: Node) -> void:
	if node is BoxContainer:
		node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	if node is Button:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, GoUi.metric(GoTheme.BUTTON_HEIGHT))
		# 🛑 자연 폭으로 표시된 것(흐르는 줄의 칸, 「뒤로」처럼 낱말 하나)은 건드리지 않는다.
		if GoUi.config.autowrap_text and not node.has_meta(&"go_no_wrap"):
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node.get_class() == "Button" and node.theme_type_variation == &"":
			style_button(node)
	if node is Label:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if GoUi.config.autowrap_text and not node.has_meta(&"go_no_wrap") and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if node is LineEdit:
		node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	for child in node.get_children(): form(child)


# ── 선택·메뉴 ───────────────────────────────────────────────────────────

## 🔑 **드롭다운 선택(Select).** 항목 배열을 받아 `OptionButton` 을 만든다. `placeholder` 는 아무것도 고르지
## 않았을 때 보이는 글(고르면 사라진다). 폭은 부르는 쪽이 정한다.
static func select(options: Array, placeholder := "", translate := false) -> OptionButton:
	var node := picker()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	for option in options: node.add_item(str(option))
	if not placeholder.is_empty():
		# 🛑 `select(-1)` 이 글을 지우므로 **그 뒤에** placeholder 를 쓴다. 고르면 엔진이 항목 글로 바꾼다.
		node.select(-1)
		node.text = placeholder
	return node


## 🔑 **드롭다운 메뉴(Dropdown Menu).** 버튼을 누르면 항목 목록이 아래로 펼쳐진다. 항목은 문자열 또는
## `{"text": …, "icon": StringName, "disabled": bool}` 사전. 고르면 `action.call(index)`.
static func dropdown(text: String, items: Array, action := Callable(), translate := false) -> MenuButton:
	var node := MenuButton.new()
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_BUTTON
	node.text = text
	node.flat = false
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	node.custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	apply_icon(node, GoIconSet.CHEVRON_DOWN, GoUi.metric(GoTheme.LIST_GLYPH))
	node.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var popup := node.get_popup()
	popup.theme = GoUi.theme()
	for item in items:
		if item is Dictionary:
			var found := GoUi.icons().texture(item.get("icon", &""))
			if found != null: popup.add_icon_item(found, str(item.get("text", "")))
			else: popup.add_item(str(item.get("text", "")))
			if item.get("disabled", false): popup.set_item_disabled(popup.item_count - 1, true)
		else:
			popup.add_item(str(item))
	if action.is_valid(): popup.index_pressed.connect(action)
	return node


## 🔑 **라디오 묶음(Radio Group).** 하나만 고른다. 돌려주는 세로줄의 `meta("group")` 이 `ButtonGroup` 이고,
## 고른 항목은 `group.get_pressed_button().get_index()` 로 안다. 터치 하한은 항목마다 지킨다.
static func radio_group(options: Array, selected := 0, translate := false) -> VBoxContainer:
	var column := column(GoUi.metric(GoTheme.GAP_TINY))
	var group := ButtonGroup.new()
	column.set_meta(&"group", group)
	for index in options.size():
		var item := CheckBox.new()
		item.theme = GoUi.theme()
		item.text = str(options[index])
		item.button_group = group   # 묶음이 있으면 CheckBox 는 라디오로 그려진다
		item.button_pressed = index == selected
		item.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
		item.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(item)
	return column


## 🔑 **분절 선택(Segmented / Toggle Group).** 나란한 버튼 중 하나만 눌린 상태로 남는다.
## 고르면 `action.call(index)`. `meta("group")` 은 `ButtonGroup`.
static func segmented(options: Array, selected := 0, action := Callable(), translate := false) -> HBoxContainer:
	var line := row(0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var group := ButtonGroup.new()
	line.set_meta(&"group", group)
	var count := options.size()
	for index in count:
		var item := Button.new()
		item.text = str(options[index])
		item.toggle_mode = true
		item.button_group = group
		item.button_pressed = index == selected
		item.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
		style_button(item, Tone.COMPACT)
		# 🛑 자연 폭 — 줄바꿈을 켠 채 두면 최소 폭이 0 이 되어 글자가 세로로 쪼개진다(2026-09-12 데모: 파란 막대만 보였다).
		natural_width(item)
		item.custom_minimum_size.x = GoUi.metric(GoTheme.TOUCH) * 1.5
		# 양 끝만 둥글고 가운데는 각지게 — 한 덩어리로 읽힌다.
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			var face := box(GoTheme.BOX_CARD)
			if state == &"pressed" or state == &"hover_pressed":
				face.bg_color = GoUi.color(GoTheme.ACCENT)
			elif state == &"hover":
				face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
			var radius := GoUi.metric(GoTheme.RADIUS_SMALL)
			face.corner_radius_top_left = radius if index == 0 else 0
			face.corner_radius_bottom_left = radius if index == 0 else 0
			face.corner_radius_top_right = radius if index == count - 1 else 0
			face.corner_radius_bottom_right = radius if index == count - 1 else 0
			face.border_width_left = 0 if index > 0 else face.border_width_left
			item.add_theme_stylebox_override(state, face)
		item.add_theme_color_override(&"font_pressed_color", GoUi.color(GoTheme.ON_ACCENT))
		item.add_theme_color_override(&"font_hover_pressed_color", GoUi.color(GoTheme.ON_ACCENT))
		if action.is_valid(): item.pressed.connect(action.bind(index))
		line.add_child(item)
	return line


## 🔑 **탭 줄(Tabs).** 이름 배열로 `TabBar` 를 만든다. 내용 전환은 부르는 쪽이 `tab_changed` 로 한다
## (내용까지 묶으려면 엔진의 `TabContainer` 에 이 테마를 주면 된다).
static func tabs(names: Array, selected := 0, translate := false) -> TabBar:
	var bar := TabBar.new()
	bar.theme = GoUi.theme()
	bar.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	for name in names: bar.add_tab(str(name))
	bar.current_tab = clampi(selected, 0, maxi(0, names.size() - 1))
	bar.tab_alignment = TabBar.ALIGNMENT_LEFT
	bar.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


## 🔑 **빵 부스러기(Breadcrumb).** 경로 항목을 `›` 로 잇는다. 마지막은 현재 위치라 누를 수 없다.
## 앞 항목을 누르면 `action.call(index)`.
static func breadcrumb(items: Array, action := Callable(), translate := false) -> HBoxContainer:
	var line := row(GoUi.metric(GoTheme.GAP_TINY))
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var last := items.size() - 1
	for index in items.size():
		if index > 0:
			line.add_child(GoUi.icons().node(GoIconSet.CHEVRON_RIGHT, GoUi.metric(GoTheme.LIST_GLYPH), GoUi.color(GoTheme.MUTED)))
		if index == last:
			var here := label(str(items[index]), GoTheme.ROLE_BODY) if not translate else label_key(str(items[index]))
			here.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			line.add_child(here)
		else:
			var link := button(str(items[index]), action.bind(index) if action.is_valid() else Callable(), Tone.BARE) \
				if not translate else button_key(str(items[index]), action.bind(index) if action.is_valid() else Callable(), Tone.BARE)
			link.add_theme_color_override(&"font_color", GoUi.color(GoTheme.SECONDARY))
			line.add_child(link)
	natural_width(line)   # 🛑 항목마다 자연 폭 — 아니면 "Weapons" 가 W·e·a·p·o·n·s 로 세로 쪼개진다(2026-09-12 데모)
	return line


# ── 글 입력 ─────────────────────────────────────────────────────────────

## 🔑 **여러 줄 입력(Textarea).** `lines` 줄 높이만큼 보이고, 넘치면 안에서 스크롤한다.
static func textarea(placeholder := "", lines := 4, translate_placeholder := false) -> TextEdit:
	var node := TextEdit.new()
	node.theme = GoUi.theme()
	node.placeholder_text = placeholder
	if translate_placeholder: node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	node.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	node.scroll_fit_content_height = false
	node.custom_minimum_size.y = GoUi.font_size(GoTheme.ROLE_BODY) * 1.5 * lines + GoUi.metric(GoTheme.PADDING)
	return node


# ── 표시 ────────────────────────────────────────────────────────────────

## 🔑 **아바타.** 그림이 있으면 둥글게 자른 그림, 없으면 accent 원 위에 이니셜(최대 2글자).
static func avatar(text := "", size := 40, accent := Color.TRANSPARENT, texture: Texture2D = null) -> Control:
	var ink := accent if accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var node := PanelContainer.new()
	node.name = "Avatar"
	node.custom_minimum_size = Vector2(size, size)
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override(&"panel", disc(size, ink, 0.22, 0.6))
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(picture)
		return node
	var initials := ""
	for word in text.split(" ", false):
		initials += word.substr(0, 1).to_upper()
		if initials.length() >= 2: break
	var mark := label(initials, GoTheme.ROLE_BUTTON, ink)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	mark.add_theme_font_size_override(&"font_size", maxi(8, roundi(size * 0.4)))
	node.add_child(mark)
	return node


## 🔑 **스켈레톤(Skeleton).** 아직 오지 않은 내용의 자리를 잡아 두는 옅은 판. 트리에 붙으면 은은하게 숨 쉰다
## (`reduce_motion` 이면 멈춘 채). 폭 0 은 가로로 채운다.
static func skeleton(width := 0.0, height := 14.0) -> Control:
	var node := Panel.new()
	node.name = "Skeleton"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(width, height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width <= 0.0 else Control.SIZE_SHRINK_BEGIN
	var face := StyleBoxFlat.new()
	face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	node.add_theme_stylebox_override(&"panel", face)
	node.tree_entered.connect(func() -> void:
		if GoUi.config.reduce_motion: return
		var pulse := node.create_tween().set_loops()
		pulse.tween_property(node, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(node, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	return node


## 🔑 **알림 상자(Alert).** 화면 안에 붙박이로 두는 안내 — 스낵바(`GoNotice`)와 달리 사라지지 않는다.
## `tone` 은 색 토큰(`GoTheme.INFO`·`SUCCESS`·`WARNING`·`DANGER`). 아이콘을 비우면 톤에 맞는 기본 아이콘.
static func alert(message: String, tone := GoTheme.INFO, icon: StringName = &"", translate := false) -> PanelContainer:
	var ink := GoUi.color(tone)
	var node := PanelContainer.new()
	node.name = "Alert"
	node.theme = GoUi.theme()
	var face := box(GoTheme.BOX_CARD, ink)
	face.bg_color = GoUi.color(GoTheme.SURFACE).lerp(ink, 0.10)
	face.set_border_width_all(1)
	node.add_theme_stylebox_override(&"panel", face)
	var line := row(GoUi.metric(GoTheme.GAP_SMALL))
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	node.add_child(line)
	var default_icons := {GoTheme.INFO: GoIconSet.INFO, GoTheme.SUCCESS: GoIconSet.SUCCESS,
		GoTheme.WARNING: GoIconSet.WARNING, GoTheme.DANGER: GoIconSet.ERROR}
	var glyph := GoUi.icons().node(icon if not icon.is_empty() else default_icons.get(tone, GoIconSet.INFO),
		GoUi.metric(GoTheme.ICON_SIZE), ink)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(glyph)
	var text := label_key(message) if translate else label(message)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	return node


## 🔑 **표(Table).** 머리글 한 줄 + 행들. 셀은 문자열이나 `Control`. 머리글은 흐린 대문자 느낌, 행은 얇은 선으로 나눈다.
static func table(headers: Array, rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Table"
	grid.theme = GoUi.theme()
	grid.columns = maxi(1, headers.size())
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", GoUi.metric(GoTheme.GAP))
	grid.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP_SMALL))
	for header in headers:
		var head := label(str(header), GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		head.uppercase = true
		grid.add_child(head)
	for cells in rows:
		for cell in cells:
			if cell is Control: grid.add_child(cell)
			else:
				var text := label(str(cell))
				grid.add_child(text)
	return grid
