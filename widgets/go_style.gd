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


## 안쪽 여백 한 겹. [param vertical] 을 주면 위·아래만 그 값이다(좌우는 [param amount]) —
## 옆은 넉넉하고 위아래는 좁아야 하는 한 줄 목록 칸용이다. 음수면 네 변이 같다.
static func padding(amount := -1, vertical := -1) -> MarginContainer:
	var node := MarginContainer.new()
	insets(node, amount, vertical)
	return node


## 이미 있는 `MarginContainer` 의 네 변 여백을 한 번에. [param vertical] 은 `padding()` 과 같다.
static func insets(node: MarginContainer, amount := -1, vertical := -1) -> void:
	var value := GoUi.metric(GoTheme.PADDING) if amount < 0 else amount
	for side in [&"margin_left", &"margin_right"]:
		node.add_theme_constant_override(side, value)
	var down := value if vertical < 0 else vertical
	for side in [&"margin_top", &"margin_bottom"]:
		node.add_theme_constant_override(side, down)


## **한쪽에 의미색 띠만 세운 카드 판** — 목록에 상태를 표시하되 색면이 줄줄이 쌓이지 않게 한다.
##
## 🔑 카드 배경 전체를 상태색으로 칠하면 목록에서 색면이 겹겹이 쌓여 **무엇이 급한지 알 수 없다.**
##    배경은 공용 카드 그대로 두고 글이 시작하는 쪽 모서리에 띠 하나만 세운다.
## 🛑 판은 글의 방향을 모른다 — RTL(아랍어·우르두)에서는 띠가 **오른쪽**에 서야 하므로,
##    카드를 만드는 쪽이 `Control.is_layout_rtl()` 을 읽어 [param rtl] 로 알려준다.
## [param width] 음수면 작은 간격 토큰.
## [param alpha] 는 판 바탕의 불투명도(음수면 테마·설정이 정한 카드 값).
static func edge_card(accent: Color, rtl := false, width := -1.0, alpha := -1.0) -> StyleBoxFlat:
	var style := box(GoTheme.BOX_CARD, Color.TRANSPARENT, alpha)
	var thick := int(width if width >= 0.0 else float(GoUi.metric(GoTheme.GAP_TINY)))
	style.set_border_width_all(0)
	if rtl: style.border_width_right = thick
	else: style.border_width_left = thick
	style.border_color = Color(accent, 0.9)
	return style


## 위 띠 카드 판을 두른 **컨테이너** — 내용은 부르는 쪽이 채운다(`card()` 의 띠 판 짝).
## [param pad] 는 안쪽 여백(음수면 작은 여백 토큰). 🛑 그 위에 `padding()` 칸을 또 두르지 않는다.
static func edge_card_panel(accent: Color, rtl := false, pad := -1.0, alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "EdgeCard"
	node.theme = GoUi.theme()
	var face := edge_card(accent, rtl, -1.0, alpha)
	face_padding(face, pad if pad >= 0.0 else float(GoUi.metric(GoTheme.PADDING_COMPACT)),
		pad if pad >= 0.0 else float(GoUi.metric(GoTheme.PADDING_COMPACT)))
	node.add_theme_stylebox_override(&"panel", face)
	return node


## 컨테이너의 자식 간격을 토큰으로.
static func gap(node: Container, token := GoTheme.GAP) -> void:
	var value := GoUi.metric(token)
	if node is GridContainer or node is FlowContainer:
		node.add_theme_constant_override(&"h_separation", value)
		node.add_theme_constant_override(&"v_separation", value)
	else:
		node.add_theme_constant_override(&"separation", value)


## 🔑 **간격을 값으로 직접** 준다 — 토큰으로 표현되지 않는 HUD 기하 전용이다.
##
## 🛑 `gap()` 을 쓸 수 없는 자리가 둘 있다. ① **음수 간격** — 터치 상자를 일부러 겹쳐 놓는 줄(퀵슬롯이
##    48 폭인데 중심 간격이 40 이면 −8 이다). ② **0** — 붙여 그려야 이음매가 없는 줄. 토큰에는 그런 값이
##    없고, 있어서도 안 된다(토큰은 읽는 리듬이지 손가락 기하가 아니다).
## [param vertical] 을 주지 않으면 가로와 같은 값이다. 세로 상자는 `separation` 하나만 쓴다.
static func spacing(node: Container, horizontal: int, vertical := -9999) -> void:
	var down := horizontal if vertical == -9999 else vertical
	if node is GridContainer or node is FlowContainer:
		node.add_theme_constant_override(&"h_separation", horizontal)
		node.add_theme_constant_override(&"v_separation", down)
	elif node is VBoxContainer:
		node.add_theme_constant_override(&"separation", down)
	else:
		node.add_theme_constant_override(&"separation", horizontal)


## 🔑 **변마다 다른 여백** — `insets()` 는 네 변을 같은 값으로 두지만, 화면 가장자리에 붙는 HUD 는
## 한두 변만 띄운다(왼쪽·아래만 주는 물약 줄). 음수인 변은 **건드리지 않는다**(`face_padding` 과 같은 약속).
static func edge_insets(node: MarginContainer, left := -1, top := -1, right := -1, bottom := -1) -> void:
	if node == null: return
	var sides := {&"margin_left": left, &"margin_top": top, &"margin_right": right, &"margin_bottom": bottom}
	for side: StringName in sides:
		var value: int = sides[side]
		if value >= 0: node.add_theme_constant_override(side, value)


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
	line.color = GoUi.skin().divider_color()
	var thick := GoUi.skin().divider_thickness()
	if vertical:
		line.custom_minimum_size = Vector2(thick, 0)
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		line.custom_minimum_size = Vector2(0, thick)
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
	# 🛑 칸은 **균등하게 나뉘어야** 한다. `GridContainer` 는 남는 폭을 `SIZE_EXPAND` 가 붙은 자식에게만
	#    주므로, 기본 `SIZE_FILL` 로 두면 카드가 **내용의 최소 폭**으로 쪼그라든다 — 카드 속 라벨은
	#    줄바꿈을 켜 두어 최소 폭이 거의 0 이라, 카드가 25px 로 접히고 글자가 **세로로 한 자씩** 내려간다
	#    (2026-09-13 실측: 창 390~600 어디서나 카드 폭 25px · 라벨 6줄).
	node.child_entered_tree.connect(func(child: Node) -> void:
		if child is Control: (child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL)
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


## 🔑 **글자 크기(와 색)만** 역할 토큰으로 정한다 — `theme_type_variation` 은 건드리지 않는다.
##
## `typography()` 는 변형까지 갈아 끼우므로 **변형이 판을 정하는 노드**(버튼·분절 칸)에는 쓸 수 없다 —
## 거기 쓰면 버튼 판이 통째로 사라진다. 한 칸 안에서 글자를 작은 캡션으로 줄이거나, `glyph_text()` 로
## 아이콘 글꼴을 입혔던 칸을 **본래 글꼴로 되돌릴** 때 쓴다(글꼴 override 를 지운다).
static func font_role(node: Control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.remove_theme_font_override(&"font")
	node.add_theme_font_size_override(&"font_size", GoUi.font_size(role))
	if ink.a > 0: node.add_theme_color_override(&"font_color", ink)


## 🔑 **글자 그림자** — 월드·그림·사진 위에 바로 얹히는 글자가 배경에 묻히지 않게 한 칸 뒤로 그림자를 깐다
## (HUD 의 이름·레벨처럼 판 없이 뜨는 글자). 판 위의 글자에는 쓰지 않는다 — 판이 이미 대비를 만든다.
##
## [param ink] 의 알파가 0 이면 토큰 `shadow`. [param offset_y]·[param offset_x] 는 dp 이고, **음수면 그 축을 건드리지
## 않는다**(테마가 정한 값을 그대로 둔다) — 세로로만 한 칸 내리는 것이 기본이다.
static func text_shadow(node: Control, ink := Color.TRANSPARENT, offset_y := 1, offset_x := -1) -> void:
	if node == null: return
	node.add_theme_color_override(&"font_shadow_color", ink if ink.a > 0 else GoUi.color(GoTheme.SHADOW))
	if offset_y >= 0: node.add_theme_constant_override(&"shadow_offset_y", offset_y)
	if offset_x >= 0: node.add_theme_constant_override(&"shadow_offset_x", offset_x)


## 🔑 **노드의 글자 자체를 아이콘 글리프로** 삼는다 — 글꼴을 아이콘 세트의 글꼴로 바꾸고 `text` 에 글리프를 넣는다.
##
## `apply_icon()` 은 자식 라벨을 더하지만, 이것은 **글자 한 칸이 곧 아이콘**인 자리용이다(지도 위 알약의 글리프 칸,
## 원판 버튼처럼 부르는 쪽이 칸 폭을 글꼴로 재서 배치하는 곳). 아이콘을 둘 이상 주면 한 칸 띄워 잇는다
## (목록 + 꺾쇠 = "펼치는 목록").
## [param size] 음수면 `icon_size` 토큰. 본래 글자로 되돌릴 때는 `font_role()` 을 부른다.
## [param set] 을 주면 그 세트에서 찾는다 — 같은 이름을 **채운 모양**으로 그리는 두 번째 세트처럼, 한 화면이
## 세트를 갈아 쓰는 자리를 위한 것이다. 비우면 설정의 기본 세트다.
## 🛑 텍스처만 있는 아이콘은 글리프가 없어 건너뛴다 — 그런 아이콘은 `apply_icon()`·`icon_button()` 이 맡는다.
static func glyph_text(node: Control, icons: Array, size := -1, ink := Color.TRANSPARENT,
		set: GoIconSet = null) -> void:
	if node == null: return
	var marks := set if set != null else GoUi.icons()
	if marks == null: return
	var parts := PackedStringArray()
	var font: Font = null
	for icon in icons:
		var mark := marks.glyph(icon as StringName)
		if mark.is_empty(): continue
		parts.append(mark)
		if font == null: font = marks.glyph_font(icon as StringName)
	node.theme = GoUi.theme()
	node.set(&"text", " ".join(parts))
	if font != null: node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size)
	if ink.a > 0: node.add_theme_color_override(&"font_color", ink)


## `glyph_text()` 가 그릴 글자의 **폭**(dp). 칸을 접을지 말지를 노드에 되묻지 않고 미리 재는 자리에 쓴다.
##
## 🛑 **버튼에 되묻지 않는다** — 버튼의 최소 폭은 지금 글자인지 글리프인지에 따라 달라, 되물으면 판정이 제
##    결과를 입력으로 받아 두 모양을 오간다. 두 모양을 모두 글꼴로 재서 비교한다.
static func glyph_width(icons: Array, size := -1, set: GoIconSet = null) -> float:
	var marks := set if set != null else GoUi.icons()
	if marks == null: return 0.0
	var parts := PackedStringArray()
	var font: Font = null
	for icon in icons:
		var mark := marks.glyph(icon as StringName)
		if mark.is_empty(): continue
		parts.append(mark)
		if font == null: font = marks.glyph_font(icon as StringName)
	if font == null or parts.is_empty(): return 0.0
	return font.get_string_size(" ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size).x


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
	# 스킨이 머리말에 표식을 붙일 수 있게 한다. 기본 스킨은 빈 판이라 생김새가 그대로다.
	node.add_theme_stylebox_override(&"normal", GoUi.skin().section_box())
	return node


# ── 버튼 ───────────────────────────────────────────────────────────────

## 🛑 값을 **뒤에만** 더한다 — 가운데에 끼우면 씬에 저장된 숫자가 다른 톤을 가리킨다.
enum Tone { NORMAL, PRIMARY, DANGER, BARE, COMPACT, DANGER_SOLID }

## 이미 있는 버튼에 gohud 규격을 입힌다(씬에서 만든 버튼도 받는다).
static func style_button(node: Button, tone := Tone.NORMAL) -> void:
	node.theme = GoUi.theme()
	match tone:
		Tone.PRIMARY: node.theme_type_variation = GoTheme.VAR_PRIMARY_BUTTON
		Tone.DANGER: node.theme_type_variation = GoTheme.VAR_DANGER_BUTTON
		Tone.DANGER_SOLID: node.theme_type_variation = GoTheme.VAR_DANGER_SOLID_BUTTON
		Tone.BARE: node.theme_type_variation = GoTheme.VAR_BARE_BUTTON
		Tone.COMPACT: node.theme_type_variation = GoTheme.VAR_COMPACT_BUTTON
		_: node.theme_type_variation = GoTheme.VAR_BUTTON
	var compact := tone == Tone.COMPACT or tone == Tone.BARE
	# 🛑 `MOUSE_FILTER_PASS` — 스크롤 안의 버튼은 손가락 끌기를 `ScrollContainer` 에 넘겨야 한다.
	#    STOP 이면 목록 위에서 시작한 스크롤이 먹히지 않는다.
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	if GoUi.config.autowrap_text: fit_words(node)
	if tone == Tone.BARE:
		# 씬에서 만든 버튼에 남아 있는 판(override)을 지운다 — 맨 버튼은 테마 변형이 그리는 것이 전부다.
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			node.remove_theme_stylebox_override(state)
		return
	# 🛑 작은 버튼(COMPACT)은 **폭 플래그를 건드리지 않는다** — 부르는 쪽이 SHRINK_BEGIN/END 로 놓는 경우가 많고,
	#    여기서 EXPAND_FILL 을 박으면 먼저 둔 값을 덮어쓴다(2026-09-12, 파생 게임 소비처 5곳). 높이는 터치 하한.
	node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH if compact else GoTheme.BUTTON_HEIGHT)
	if not compact: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## 🔑 **버튼 글자가 글자 단위로 쪼개지지 않게** 줄바꿈을 정한다. 글자를 바꾼 뒤에도 다시 부른다.
##
## 🛑 줄바꿈이 켜진 버튼은 최소 폭에서 **글자 폭을 빼 버린다**(접을 수 있다고 보므로). 그래서 자연 폭
##    버튼이 좁아지면 `Done` 이 `Don`/`e` 로 갈라졌다(2026-09-13 코치마크 실측). 규칙 둘:
##    ① 한 낱말이면 접지 않는다 — 접을 곳이 없다. ② 여러 낱말이면 접되, **가장 긴 낱말**은 한 줄에
##    들어가도록 최소 폭을 보장한다.
static func fit_words(node: Button) -> void:
	if node.has_meta(&"go_no_wrap"): return
	# 🛑 **번역 키가 아니라 화면에 보이는 글자**로 판단한다. `button_key()` 의 `text` 는 키(`confirm`)이고
	#    엔진이 그리기 직전에 번역한다 — 키만 보면 한 낱말이라 접지 않기로 하는데, 번역문은 두 낱말일 수
	#    있다(2026-09-13, I-57). `atr()` 은 그 노드의 자동 번역 설정을 따라 번역한다.
	var shown := node.atr(node.text) if node.is_inside_tree() else node.text
	var words := shown.strip_edges().split(" ", false)
	if words.size() <= 1:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		return
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := node.get_theme_font(&"font")
	var size := node.get_theme_font_size(&"font_size")
	var longest := 0.0
	for word in words:
		longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x)
	var frame := node.get_theme_stylebox(&"normal").get_minimum_size().x
	node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, ceilf(longest + frame + 2.0))


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


## 🔍 **작은 글자 버튼의 판 여백 계약**을 검사한다. 글자가 있는 작은 버튼의 상태별 판 좌우 여백이
## `compact_padding_x` 토큰보다 작으면 `"노드 경로:상태 …"` 를 돌려준다. 빈 배열이면 통과.
##
## 🔑 **판 여백을 직접 본다** — 최소 폭으로 재면 넓게 늘어난 버튼은 여백 0 판이어도 통과하고,
##    낱말 줄바꿈으로 좁아진 정상 버튼은 실패한다.
## 🛑 글자 없이 아이콘만 있는 버튼은 보지 않는다 — 원형·정사각 아이콘 판은 여백 0 이 맞다.
## 🛑 부르는 쪽이 판을 덮어쓴 상태는 기본으로 건너뛴다(좁힌 탭처럼 의도한 예외가 있다). `include_overrides` 로 함께 본다.
## `variations` — 작은 버튼으로 칠 변형 이름. 호스트가 자기 이름을 base 로 건 경우 그 이름도 넘긴다.
static func audit_compact_padding(root: Node, include_overrides := false,
		variations: Array[StringName] = [GoTheme.VAR_COMPACT_BUTTON]) -> Array[String]:
	var problems: Array[String] = []
	_audit_compact(root, float(GoUi.metric(GoTheme.COMPACT_PADDING_X)), include_overrides, variations, problems)
	return problems


static func _audit_compact(node: Node, need: float, include_overrides: bool, variations: Array[StringName],
		out: Array[String]) -> void:
	var button := node as Button
	if button != null and not button.text.strip_edges().is_empty() and _is_variation(button, variations):
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			if not include_overrides and button.has_theme_stylebox_override(state): continue
			var box := button.get_theme_stylebox(state)
			if box == null: continue
			var left := box.get_margin(SIDE_LEFT)
			var right := box.get_margin(SIDE_RIGHT)
			if left < need - 0.01 or right < need - 0.01:
				var where := String(button.get_path()) if button.is_inside_tree() else String(button.name)
				out.append("%s:%s 좌우 여백 %.0f·%.0f < %.0f" % [where, state, left, right, need])
	for child in node.get_children():
		_audit_compact(child, need, include_overrides, variations, out)


## 노드의 변형이 목록에 있거나, 테마의 base 체인을 따라가다 목록에 닿는가.
static func _is_variation(control: Control, variations: Array[StringName]) -> bool:
	var current := control.theme_type_variation
	var theme := GoUi.theme()
	for _depth in 8:
		if current.is_empty(): return false
		if variations.has(current): return true
		current = theme.get_type_variation_base(current) if theme != null else &""
	return false


## 🔑 **아이콘만 있는 버튼**. 보이는 크기는 `visual`, 터치는 토큰 `touch` 까지 노드 밖으로 넓어진다.
## 세트가 폰트든 텍스처든 같은 호출이다.
##
## ♿ `tooltip_key` 를 **꼭 준다.** 아이콘만 있는 버튼은 마우스 사용자에게 툴팁이, 화면 낭독기에게는
## 접근성 이름이 **유일한 설명**이다. 둘 다 이 한 값에서 나온다.
static func icon_button(icon: StringName, action := Callable(), visual := -1,
		tooltip_key: StringName = &"") -> GoIconButton:
	var node := GoIconButton.new()
	node.visual_size = GoUi.metric(GoTheme.TOUCH) - 12 if visual < 0 else visual
	node.set_icon_name(icon)
	if not tooltip_key.is_empty(): node.tooltip_text_name = tooltip_key
	if action.is_valid(): node.pressed.connect(action)
	return node


## 버튼에 아이콘을 붙인다 — 텍스처 세트면 `Button.icon`, 폰트 세트면 자식 라벨로 간다.
## 🛑 한 버튼에 아이콘 폰트와 본문 폰트를 같이 쓸 방법은 자식 라벨뿐이다(`text` 의 폰트는 하나다).
##
## [param inset] 는 **폰트 세트의 글리프**를 버튼 왼쪽 경계에서 그만큼 안으로 들이고(판 여백 안에 놓이게),
## 글자가 그 위로 오지 않게 좌우 글자 여백을 아이콘 끝 + `gap_small` 까지 넓힌다. 음수면 지금까지처럼
## 경계에 붙이고 판도 건드리지 않는다. 텍스처 세트는 버튼이 아이콘 자리를 따로 잡으므로 해당 없다.
## 🛑 좌우를 **같이** 넓힌다 — 한쪽만 넓히면 가운데 정렬 글자가 아이콘 쪽으로 밀려 오히려 겹친다
##    (2026-09-13 좁은 전폭 버튼 실측: `Log in with email` 이 ✉ 위에 얹혀 "Lg in with email" 로 읽혔다).
static func apply_icon(node: Button, icon: StringName, size := -1, ink := Color.TRANSPARENT,
		inset := -1.0) -> void:
	var px := GoUi.metric(GoTheme.ICON_SIZE) if size < 0 else size
	var found := GoUi.icons().texture(icon)
	if found != null:
		node.icon = found
		node.expand_icon = true
		# 🛑 `icon_max_width` 없이 `expand_icon` 만 켜면 아이콘이 버튼 높이만큼 커진다.
		node.add_theme_constant_override(&"icon_max_width", px)
		if ink.a > 0: node.add_theme_color_override(&"icon_normal_color", ink)
		return
	# 🛑 텍스처가 없어 **자식 라벨**로 떨어지는 경우다. 버튼 테마의 아이콘 색은 자식에게 닿지 않으므로
	#    색을 안 받았으면 여기서 같은 색을 집어 준다 — 안 그러면 흰색으로 그려진다.
	var glyph_ink := ink
	if glyph_ink.a <= 0:
		glyph_ink = node.get_theme_color(&"icon_normal_color") if node.has_theme_color(&"icon_normal_color") \
			else GoUi.color(GoTheme.SECONDARY)
	var glyph := GoUi.icons().node(icon, px, glyph_ink)
	glyph.name = "IconGlyph"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE)
	node.add_child(glyph)
	if inset < 0.0: return
	glyph.offset_left += inset
	glyph.offset_right += inset
	var room := glyph.offset_right + float(GoUi.metric(GoTheme.GAP_SMALL))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var face := node.get_theme_stylebox(state)
		if face == null: continue
		var plate := face.duplicate() as StyleBox
		plate.content_margin_left = maxf(face.content_margin_left, room)
		plate.content_margin_right = maxf(face.content_margin_right, room)
		node.add_theme_stylebox_override(state, plate)


## 🔑 **바깥 규격이 정해 준 브랜드 버튼** — 플랫폼 제공자의 로그인 버튼(Sign in with Google·Apple 등)처럼
## 판 색·테두리·마크 크기를 **심사 규격이 못 박은** 자리다. gohud 는 자리와 상태만 맡고 값은 부르는 쪽이 준다 —
## 🛑 스킨·팔레트가 이 색을 바꾸면 안 되므로 토큰을 쓰지 않는다. 규격 원문을 옮겨 적는 것은 호스트의 몫이다.
##
## [param fill] 판 바탕 · [param ink] 글자색 · [param edge] 1dp 테두리색.
## [param mark] 는 마크의 `icon_max_width`(음수면 그대로) · [param gap] 은 마크와 글자 사이(음수면 그대로) ·
## [param inset] 은 판 **좌우** 안쪽 여백(음수면 그대로 · 위아래는 0 으로 둔다 — 높이는 부르는 쪽이 정한다).
## [param base] 를 주면 그 판을 복제해 **모양(둥글기)** 을 물려받는다 — 같은 화면의 다른 버튼과 한 묶음으로 보이게.
## [param mark_ink] 는 마크 색이며 기본은 흰색이다 — 여러 색으로 된 공식 마크(Google 의 4색 G)가 테마 색에 물들지 않게.
##
## 올림·눌림은 어두운 판이면 밝히고 밝은 판이면 어둡게 하며(제공자 배포본과 같은 되먹임), 비활성은 회색 쪽으로
## 당기고, 포커스 판은 **속을 비워** 테두리만 남긴다(공용 포커스 링이 그 위에 그려진다).
## 🛑 마크와 글자를 함께 판 가운데 세우려면 폭이 정해진 뒤 [method center_button_content] 를 부른다.
static func style_brand_button(node: Button, fill: Color, ink: Color, edge: Color,
		mark := -1, gap := -1, inset := -1.0, base: StyleBox = null, mark_ink := Color.WHITE) -> void:
	var source := base if base != null else node.get_theme_stylebox(&"normal")
	if source == null: source = surface(GoTheme.BOX_CARD)
	# 🛑 브랜드 색을 **넣을 수 있는 판**이어야 한다. 스킨이 커스텀 판(각진 판 등)을 주는 테마에서는 `bg_color` 를
	#    고쳐도 그 판이 자기 색으로 그리므로 규격 색이 화면에 안 나온다 — 같은 여백·테두리·둥글기의 평판으로 옮긴다.
	#    **규격이 스킨보다 앞서는 유일한 자리다**(다른 함수는 모두 스킨 모양을 그대로 살린다).
	if not (source is StyleBoxFlat): source = _flat_like(source)
	# 🔑 어두운 판인가로 되먹임 방향을 가른다 — 검정 판(Apple)은 밝히고 흰 판(Google)은 어둡게.
	var dark := fill.get_luminance() < 0.5
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var face := source.duplicate() as StyleBox
		var back := fill
		if state == &"hover" or state == &"pressed" or state == &"hover_pressed":
			back = fill.lightened(0.18) if dark else fill.darkened(0.06)
		elif state == &"disabled":
			back = fill.lerp(Color(0.5, 0.5, 0.5), 0.35)
		if &"bg_color" in face: face.set(&"bg_color", back)
		if state == &"focus" and &"draw_center" in face: face.set(&"draw_center", false)
		if &"border_color" in face: face.set(&"border_color", edge)
		if face is StyleBoxFlat: (face as StyleBoxFlat).set_border_width_all(1)
		elif &"border_width" in face: face.set(&"border_width", 1.0)
		if &"shadow_size" in face: face.set(&"shadow_size", 0)
		if inset >= 0.0:
			face.content_margin_left = inset
			face.content_margin_right = inset
			face.content_margin_top = 0.0
			face.content_margin_bottom = 0.0
		node.add_theme_stylebox_override(state, face)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color", &"font_disabled_color"]:
		node.add_theme_color_override(key, ink)
	for key in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color",
			&"icon_focus_color", &"icon_disabled_color"]:
		node.add_theme_color_override(key, mark_ink)
	if mark >= 0: node.add_theme_constant_override(&"icon_max_width", mark)
	if gap >= 0: node.add_theme_constant_override(&"h_separation", gap)
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT


## 🔑 **마크와 글자를 함께 판 가운데** 세운다 — 제공자 배포 버튼의 모양이다.
## 🛑 `icon_alignment = CENTER` 를 쓰지 않는다 — 엔진은 마크를 글자 **위에 겹쳐** 그린다(2026-09-14 실측
##    "Sign in w●th Apple"). 대신 글자를 왼쪽에 두고 **왼쪽 여백 = (폭 − 마크 − 간격 − 글자 폭) / 2** 를 판에 넣는다.
## 폭이 바뀔 때(`resized`) · 언어가 바뀔 때 · 마크가 늦게 붙을 때 다시 부른다.
## 🔑 같은 값이면 판을 건드리지 않는다 — 여백을 바꾸면 최소 크기가 바뀌어 `resized` 가 다시 오는 되돌이가 생긴다.
## [param min_inset] 음수면 판이 가진 왼쪽 여백이 하한이다. 돌려주는 값은 넣은 왼쪽 여백(폭이 아직 0 이면 -1).
static func center_button_content(node: Button, min_inset := -1.0) -> float:
	if node == null or not is_instance_valid(node) or node.size.x <= 0.0: return -1.0
	var face := node.get_theme_stylebox(&"normal")
	var lower := min_inset
	if lower < 0.0: lower = face.content_margin_left if face != null else 0.0
	var mark := float(node.get_theme_constant(&"icon_max_width") + node.get_theme_constant(&"h_separation"))
	var text := node.get_theme_font(&"font").get_string_size(node.atr(node.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			node.get_theme_font_size(&"font_size")).x
	var left := maxf(lower, floorf((node.size.x - mark - text) * 0.5))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var plate := node.get_theme_stylebox(state)
		if plate != null and not is_equal_approx(plate.content_margin_left, left):
			plate.content_margin_left = left
	return left


## 🎨 **판 없이 글자·아이콘 색만** 정한다 — 링크 줄·조용한 메뉴처럼 배경을 그리지 않고 색으로만 상태를 말하는 버튼.
## [param ink] 는 평소 색, [param active] 는 올림·눌림·포커스 색이다. 투명인 쪽은 건드리지 않는다 —
## 평소 색을 `typography()` 로 이미 준 버튼에는 [param active] 만 준다.
static func tint_button(node: Button, ink := Color.TRANSPARENT, active := Color.TRANSPARENT) -> void:
	if ink.a > 0:
		node.add_theme_color_override(&"font_color", ink)
		node.add_theme_color_override(&"icon_normal_color", ink)
	if active.a > 0:
		for key in [&"font_hover_color", &"font_pressed_color", &"font_focus_color",
				&"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
			node.add_theme_color_override(key, active)


## 🛑 글자 크기를 **픽셀로 못 박는다** — 규격이 바깥에서 정해진 자리(높이 대비 글자 비율이 지침인 공식 로그인
##    버튼 등)에만 쓴다. 보통은 `typography()` 의 역할을 쓴다 — 역할은 테마 교체·모바일 축소를 따라가고,
##    여기서 박은 값은 따라가지 않는다. `RichTextLabel` 은 네 가지 크기를 함께 박는다.
static func pin_font_size(node: Control, size: int) -> void:
	if node is RichTextLabel:
		for key in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
			node.add_theme_font_size_override(key, size)
		return
	node.add_theme_font_size_override(&"font_size", size)


## 🧾 **고정폭 글 상자** — 진단 코드·로그처럼 글자가 어긋나면 안 되고 골라서 복사할 수 있어야 하는 자리.
## [param font] 은 부르는 쪽이 고른 고정폭 글꼴이다 — 🛑 gohud 는 글꼴을 싣지 않는다(기기에 있는 것을 찾는
## `SystemFont` 를 쓰거나 호스트가 자기 글꼴을 넘긴다).
## [param selection] 은 고른 영역의 바탕색, [param selected_ink] 는 그 위 글자색이다(투명이면 그대로 둔다) —
## 🛑 기본 선택 바탕은 밝은 회색이라 밝은 글자가 묻힌다.
static func style_mono_text(node: RichTextLabel, font: Font, selection := Color.TRANSPARENT,
		selected_ink := Color.TRANSPARENT) -> void:
	if font != null:
		for key in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font"]:
			node.add_theme_font_override(key, font)
	if selection.a > 0: node.add_theme_color_override(&"selection_color", selection)
	if selected_ink.a > 0: node.add_theme_color_override(&"font_selected_color", selected_ink)


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
	# 두 줄 항목의 바깥 여백은 제목·요약 사이보다 넓게 둔다.
	var vertical_padding := GoUi.metric(GoTheme.GAP_TINY if sub_key.is_empty() else GoTheme.GAP_SMALL)
	inset.add_theme_constant_override(&"margin_top", vertical_padding)
	inset.add_theme_constant_override(&"margin_bottom", vertical_padding)
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
		# 행이 늘어나도 두 글줄은 자연 높이를 유지하고 아이콘과 함께 가운데 놓인다.
		stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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

## 🔑 **라벨 + 입력칸을 한 묶음으로.** 폼의 한 줄(필드)을 만든다.
##
## ```gdscript
## body.add_child(GoStyle.field("fieldEmail", GoStyle.line_edit("you@example.com")))
## ```
##
## 🛑 **라벨은 자기 입력칸에 붙어 있어야 한다.** 라벨·칸·라벨·칸을 같은 간격(`gap`)으로 쌓으면
##    어느 라벨이 어느 칸의 것인지 읽는 사람이 매번 판단해야 하고, 칸마다 여덟 픽셀씩 세로를
##    낭비해 마지막 칸이 화면 밖으로 밀린다(2026-09-16 라리엔 계정 연결 폼 실측).
##    묶음 안은 `gap_tiny`, 묶음 사이는 폼의 `gap` 이다.
##
## `key` 가 비면 라벨 없이 컨트롤만 돌려준다. `hint` 를 주면 칸 아래에 작은 설명 줄이 붙는다.
static func field(key: String, control: Control, hint := "", translate := true) -> Control:
	if key.is_empty() and hint.is_empty(): return control
	var group := column(GoUi.metric(GoTheme.GAP_TINY))
	group.name = "Field"
	# 🛑 폼이 자식 상자의 간격을 한꺼번에 `gap` 으로 맞추므로, 이 묶음만은 제 간격을 지킨다고 표시한다.
	group.set_meta(&"go_own_spacing", true)
	if not key.is_empty():
		var caption := label_key(key, GoTheme.ROLE_CAPTION) if translate else label(key, GoTheme.ROLE_CAPTION)
		caption.name = "FieldLabel"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(caption)
	group.add_child(control)
	if not hint.is_empty():
		var note := label_key(hint, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)) if translate \
			else label(hint, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		note.name = "FieldHint"
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(note)
	return group


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
	if GoUi.config.autowrap_text: fit_words(node)   # 버튼과 같은 낱말 규칙
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


## 막대의 채움 색만 바꾼다. 모양은 스킨이 정한다.
static func tint_progress(bar: ProgressBar, ink: Color) -> void:
	bar.add_theme_stylebox_override(&"fill", GoUi.skin().progress_fill_box(ink))


# ── 표면 조각 ──────────────────────────────────────────────────────────

## 🔑 카드·패널의 StyleBox **사본** — **스킨이 정한 모양 그대로**다. 각진 판 같은 커스텀
## StyleBox 도 그대로 온다. 모양까지 바꾸는 테마를 쓰는 곳은 `box()` 대신 이것을 쓴다.
## [param alpha] 는 판 **바탕의 불투명도**(0.0~1.0) — 음수면 테마·설정이 정한 값(`GoUi.surface_alpha`).
static func surface(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	return GoUi.skin().surface_box(variant, accent, alpha)


## 카드·패널의 StyleBox **사본**. `accent` 를 주면 테두리에 그 색을 입힌다.
##
## 🛑 **언제나 `StyleBoxFlat`** 을 돌려준다 — 돌려받아 `bg_color`·`corner_radius` 를 고치는
##    호출부가 이미 많기 때문이다. 스킨이 커스텀 StyleBox 를 주는 테마(sci-fi 등)에서는 그 모양이
##    여기서 살아남지 못한다. 모양을 지켜야 하면 `surface()` 를 쓴다.
## [param alpha] 는 판 바탕의 불투명도(음수면 테마·설정 값 · `surface()` 와 같다).
static func box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBoxFlat:
	var shaped := GoUi.skin().surface_box(variant, accent, alpha)
	var style := shaped as StyleBoxFlat
	if style == null:
		style = _flat_like(shaped)
		# 🛑 0.5 — 이 값은 gohud 가 파생된 게임의 규범이다. 0.55 로 짰다가 위임 대조 검사에서 잡혔다(2026-09-12).
		if accent.a > 0: style.border_color = Color(accent, 0.5)
	return style


## 커스텀 판(각진 판·단조 판)을 **같은 여백·바탕·테두리·반경·그림자**의 평판으로 옮긴다 — 모양만 잃고 자리는 같다.
## 🛑 빈 평판을 돌려주면 여백이 0 이라 옛 `box()` 로 만든 카드의 글자가 테두리에 붙었다(2026-09-15 라리엔 생김새 전환).
static func _flat_like(source: StyleBox) -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = GoUi.color(GoTheme.SURFACE)
	if source == null: return flat
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		flat.set_content_margin(side, source.get_content_margin(side))
	if &"bg_color" in source: flat.bg_color = source.get(&"bg_color")
	if &"draw_center" in source: flat.draw_center = source.get(&"draw_center")
	if &"border_color" in source: flat.border_color = source.get(&"border_color")
	if &"border_width" in source: flat.set_border_width_all(roundi(float(source.get(&"border_width"))))
	if &"radius" in source: flat.set_corner_radius_all(roundi(float(source.get(&"radius"))))
	if &"shadow_color" in source: flat.shadow_color = source.get(&"shadow_color")
	if &"shadow_size" in source: flat.shadow_size = int(source.get(&"shadow_size"))
	if &"shadow_offset" in source: flat.shadow_offset = source.get(&"shadow_offset")
	return flat


## 게임 화면 위에 **떠 있는** 표면 — 같은 카드에 얕은 그림자를 더한다. 위 `box()` 와 같은 약속이다.
## [param opaque] 는 판을 배경색으로 **꽉 채운다** — 월드가 비쳐 글자가 안 읽히는 자리(HUD 위 알림 줄)용이다.
## [param pad] 는 판 안쪽 여백(음수면 스킨 값 그대로 · `face_padding` 과 같다).
## [param alpha] 는 판 바탕의 불투명도(음수면 테마·설정 값). 🛑 [param opaque] 를 켜면 이 값은
## 쓰이지 않는다 — "월드가 비쳐 글자가 안 읽히는 자리" 를 위해 **일부러 꽉 채우는** 것이 그 인자의 뜻이다.
static func floating(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, opaque := false, pad := -1.0,
		alpha := -1.0) -> StyleBoxFlat:
	var style := GoUi.skin().floating_box(variant, accent, alpha) as StyleBoxFlat
	if style == null:
		style = box(variant, accent, alpha)
		style.shadow_color = Color(GoUi.color(GoTheme.SHADOW), 0.35)
		style.shadow_size = GoUi.metric(GoTheme.GAP_SMALL)
		style.shadow_offset = Vector2(0, 2)
	if opaque: style.bg_color = GoUi.color(GoTheme.BACKGROUND)
	face_padding(style, pad, pad)
	return style


## 원형 배지·아바타 테두리 — accent 를 옅게 채우고 같은 색 링을 두른다. 위 `box()` 와 같은 약속이다.
static func disc(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBoxFlat:
	var style := GoUi.skin().disc_box(diameter, accent, fill_alpha, edge_alpha) as StyleBoxFlat
	if style == null:
		style = box(GoTheme.BOX_HUD, accent)
		style.bg_color = Color(accent, fill_alpha)
		style.border_color = Color(accent, edge_alpha)
		style.set_border_width_all(1)
		style.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
		style.corner_detail = 16
		style.set_content_margin_all(0)
		style.shadow_size = 0
	return style


## 테두리가 있는 카드 한 장(내용은 부르는 쪽이 채운다).
##
## [param border_alpha]·[param border_width] 는 강조 테두리의 **진하기와 굵기**다(음수면 스킨 판이 가진 값 그대로) —
## 같은 목록에서 한 장만 도드라지게 할 때 쓴다(마지막에 고른 것·지금 쓰는 것·주의를 끄는 안내 카드).
## [param pad] 는 판 안쪽 여백이다(음수면 스킨 그대로). 🛑 그 위에 `padding()` 칸을 **또** 두르지 말 것 —
## 여백이 두 겹이 되어 좁은 칸의 말줄임 글자가 통째로 사라진다(`hud_panel()` 과 같은 함정).
## 🔑 판은 `surface()` 에서 온다 — 각진 판·중세 판 테마에서도 그 모양 그대로 색·굵기·여백만 바뀐다.
## [param alpha] 는 판 바탕의 불투명도(0.0~1.0) — 음수면 테마·설정이 정한 카드 값(`GoTheme.CARD_ALPHA`).
## 🔑 **이 카드 하나만** 다르게 하고 싶을 때 쓴다(장비 비교 카드처럼 뒤가 보여야 하는 자리).
static func card(accent := Color.TRANSPARENT, border_alpha := -1.0, border_width := -1.0,
		pad := -1.0, alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "Card"
	node.theme = GoUi.theme()
	node.theme_type_variation = GoTheme.VAR_CARD
	# 🛑 불투명도가 테마 값 그대로면(`alpha` 음수) 예전처럼 **판을 덮지 않는다** — 테마 변형이 그리게 둔다.
	#    카드 하나에만 다른 값을 줬을 때만 판을 만든다. 그러지 않으면 `GoCard` 변형을 자기 테마에서
	#    다르게 정의한 프로젝트의 모양이 `GoHud/styles/card` 로 바뀐다.
	if accent.a <= 0 and border_alpha < 0.0 and border_width < 0.0 and pad < 0.0 and alpha < 0.0: return node
	var face := surface(GoTheme.BOX_CARD, accent, alpha)
	_face_border(face, accent if border_alpha >= 0.0 else Color.TRANSPARENT, border_alpha, border_width)
	if pad >= 0.0: face.set_content_margin_all(pad)
	node.add_theme_stylebox_override(&"panel", face)
	return node


## 판의 테두리 색·굵기를 덮는다 — 스킨 판 종류를 가정하지 않는다(평판은 네 변, 커스텀 판은 `border_width` 하나).
## [param ink] 의 알파가 0 이거나 [param alpha] 가 음수면 색을 두지 않고, [param width] 가 음수면 굵기를 두지 않는다.
static func _face_border(face: StyleBox, ink: Color, alpha: float, width: float) -> void:
	if face == null: return
	if ink.a > 0 and alpha >= 0.0 and &"border_color" in face: face.set(&"border_color", Color(ink, alpha))
	if width < 0.0: return
	if face is StyleBoxFlat: (face as StyleBoxFlat).set_border_width_all(roundi(width))
	elif &"border_width" in face: face.set(&"border_width", width)


## 🔑 **바탕 칸 한 장** — 내용을 담지 않고 **뒤에 까는** 판이다(초상화 자리의 틴트 칸, 터치 칸보다 작게 보이는 HUD 표면).
## `card()`·`hud_panel()` 이 자식을 품는 컨테이너라면 이것은 `Panel` 하나라, 부르는 쪽이 앵커·크기로 자리를 잡는다.
##
## 판은 스킨의 [param variant] 에서 오고 **준 값만** 덮는다 — [param fill]·[param edge] 는 알파가 0 이면 스킨 색 그대로,
## [param radius]·[param border] 는 음수면 스킨이 가진 모서리·테두리 그대로다.
## 🛑 내용이 없는 칸이라 판 여백과 그림자는 0 이다 — 겹쳐 까는 판의 그림자는 그 위 글자를 흐린다.
## 🔑 입력을 받지 않는다(`MOUSE_FILTER_IGNORE`) — 바탕이 위에 놓인 버튼의 누름을 가로채면 안 된다.
## [param alpha] 는 판 바탕의 불투명도(음수면 테마·설정 값). 🛑 [param fill] 을 **준 판은 그 색 그대로**다 —
## 알파까지 적어 준 색에 판 불투명도를 또 곱하지 않는다. 둘 다 정하고 싶으면 [param alpha] 를 명시한다.
static func plate(variant := GoTheme.BOX_HUD, fill := Color.TRANSPARENT, edge := Color.TRANSPARENT,
		radius := -1.0, border := -1.0, alpha := -1.0) -> Panel:
	var node := Panel.new()
	node.name = "Plate"
	node.theme = GoUi.theme()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 바탕을 아래에서 덮어쓸 수 있으므로 판을 꽉 찬 채로 받아 **마지막에** 불투명도를 입힌다.
	var face := surface(variant, Color.TRANSPARENT, 1.0)
	var explicit_fill := fill.a > 0
	if explicit_fill and &"bg_color" in face: face.set(&"bg_color", fill)
	_face_border(face, edge, edge.a, border)
	if radius >= 0.0:
		if face is StyleBoxFlat: (face as StyleBoxFlat).set_corner_radius_all(roundi(radius))
		elif &"radius" in face: face.set(&"radius", radius)
	if face is StyleBoxFlat: (face as StyleBoxFlat).shadow_size = 0
	face.set_content_margin_all(0)
	# 🛑 **[param fill] 을 준 판은 그 색 그대로다** — `Color(ink, 0.14)` 처럼 알파까지 적어 준 색에
	#    판 불투명도를 또 곱하면 부르는 쪽의 의도가 두 번 깎인다(0.14 → 0.112). 판 불투명도는
	#    "스킨이 준 바탕" 에만 입힌다. [param alpha] 를 직접 준 경우에는 그것이 이긴다.
	if alpha >= 0.0: GoSkin.fade_box(face, alpha)
	elif not explicit_fill: GoSkin.fade_box(face, GoUi.surface_alpha(variant))
	node.add_theme_stylebox_override(&"panel", face)
	return node


## 🔑 **원판 칸** — `disc()` 판을 두른 컨테이너. 안에 아이콘·글자를 하나 넣으면 가운데 온다(입장 표식 ▶, 아바타 자리).
## 지름만큼의 최소 크기를 갖고 입력은 받지 않는다 — 누를 수 있는 동그란 단추는 `style_disc_button()` 이다.
static func disc_panel(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "Disc"
	node.custom_minimum_size = Vector2(diameter, diameter)
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_disc_panel(node, diameter, accent, fill_alpha, edge_alpha)
	return node


## **이미 만든 판**(`Panel`·`PanelContainer`)에 같은 원판을 입힌다 — 의미색이 바뀔 때마다 노드를 다시 만들지 않는
## 자리(성별을 고르면 테두리 색이 따라가는 미리보기 원판). 인자는 `disc_panel()` 과 같다.
static func style_disc_panel(node: Control, diameter: float, accent: Color, fill_alpha := 0.14,
		edge_alpha := 0.38) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"panel", disc(diameter, accent, fill_alpha, edge_alpha))


## **이미 만든 라벨**에 원판을 입힌다 — 번호 배지처럼 자리를 앵커·offset 으로 못박아 `disc_panel()` 의 컨테이너를
## 쓸 수 없을 때(`style_chip_label()` 의 원형 짝). 글자색은 부르는 쪽이 `typography()` 로 준다 —
## 🛑 짙게 채운 원판(`fill_alpha` 0.9 이상) 위에서는 흰 글자가 흐리다. `on_accent` 를 쓴다.
static func style_disc_label(node: Label, diameter: float, accent: Color, fill_alpha := 0.14,
		edge_alpha := 0.38) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"normal", disc(diameter, accent, fill_alpha, edge_alpha))


## 🔑 **판 위에 겹치는 누름 영역** — 카드 한 장이 통째로 하나의 탭일 때, 그 카드 위에 까는 투명 버튼이다.
## 판은 자기 모양을 그리지 않고(테두리·그림자·여백 0) 올림·누름에만 의미색을 [param fill_alpha] 만큼 옅게 깐다 —
## 🛑 카드의 판이 이미 테두리를 그리므로 여기에 또 두르면 테두리가 두 겹이 된다.
##
## 안쪽 여백이 0 이라 내용은 `card_body()` 같은 안쪽 칸이 대고, 높이는 `fit_content_height()` 가 내용에 맞춘다.
## 🛑 `mouse_filter` 를 건드리지 않는다 — HUD 위 버튼은 STOP 이어야 누름이 월드로 새지 않는다.
static func style_overlay_button(node: Button, accent: Color, fill_alpha := 0.10) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		# 🛑 `BOX_EMPTY` 를 쓰지 않는다 — `StyleBoxEmpty` 에는 바탕색이 없어 올림·누름이 보이지 않는다.
		#    늘 평판인 `box()` 를 받아 모양을 지우고 바탕만 남긴다.
		var face := box(GoTheme.BOX_CARD)
		face.set_border_width_all(0)
		face.shadow_size = 0
		face.set_content_margin_all(0)
		var lit: bool = String(state).contains("hover") or state == &"pressed"
		face.bg_color = Color(accent, fill_alpha if lit else 0.0)
		face.draw_center = lit
		node.add_theme_stylebox_override(state, face)


## 판을 **그리지 않는** 컨테이너 — 자리·쌓임·간격은 그대로 두고 바탕·테두리·그림자·여백만 없앤다.
## 🔑 판 하나를 지우려고 노드를 빼지 않는다 — 노드를 빼면 경로와 검사가 함께 깨진다. 묶음은 남고 상자만 사라진다.
static func bare_panel(node: Control) -> void:
	node.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())


## 🔔 **알림 판을 이미 만든 컨테이너에** 입힌다 — 화면 안에 눌러앉는 오류·경고 상자(새로 만드는 쪽은 `alert()`).
## 판은 스킨의 `notice` 표면이고 테두리에 [param accent] 가 든다. [param tint] 를 주면 바탕을 바탕색에서
## 그 색 쪽으로 그만큼 당긴다(0 이면 스킨 바탕 그대로) — 🛑 새 팔레트를 만들지 않고 의미색 하나로 물들이는 자리다.
## [param padding] 음수면 `padding_compact` 토큰.
## [param alpha] 는 판 바탕의 불투명도(음수면 테마·설정이 정한 알림 값 `GoTheme.NOTICE_ALPHA`).
static func style_notice_panel(node: Control, accent := Color.TRANSPARENT, tint := 0.0, padding := -1,
		alpha := -1.0) -> void:
	# 🛑 틴트가 바탕을 덮어쓰므로 꽉 찬 판으로 받아 **마지막에** 불투명도를 입힌다.
	var face := surface(GoTheme.BOX_NOTICE, accent, 1.0)
	if tint > 0.0:
		# 🛑 바탕을 실제로 물들이려면 색을 넣을 수 있는 판이어야 한다 — 스킨의 커스텀 판은 제 색으로 그리므로
		#    같은 여백·테두리·둥글기의 평판으로 옮긴다(틴트를 안 줬으면 스킨 모양 그대로 둔다).
		if not (face is StyleBoxFlat): face = _flat_like(face)
		if &"bg_color" in face:
			var back: Color = GoUi.color(GoTheme.BACKGROUND)
			face.set(&"bg_color", back.lerp(accent, tint))
	var pad := float(GoUi.metric(GoTheme.PADDING_COMPACT) if padding < 0 else padding)
	face.content_margin_left = pad
	face.content_margin_right = pad
	face.content_margin_top = pad
	face.content_margin_bottom = pad
	GoSkin.fade_box(face, alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_NOTICE))
	node.add_theme_stylebox_override(&"panel", face)


## 게임 화면 위에 **떠 있는 판** 한 장 — HUD 의 도크·상태 바처럼 월드 위에 얹는 자리다(내용은 부르는 쪽이 채운다).
## `card()` 의 HUD 짝이며, 모양은 스킨의 떠 있는 판을 그대로 쓴다(각진 판은 그림자 대신 발광이다).
##
## [param pad_x]·[param pad_y] 는 **판 안쪽 여백**이다(음수면 스킨이 준 여백 그대로). HUD 는 손가락이
## 닿는 기하가 화면마다 정해져 있어 여백을 부르는 쪽이 준다 — 🛑 그때 `padding()` 칸을 **또** 두르지
## 말 것. 판 여백과 겹쳐 내용 폭이 두 배로 깎이고, 좁은 칸의 말줄임 글자가 통째로 사라진다
## (2026-09-16 파티 도크에서 이끌기 칩이 27 → 11 로 접혔다).
## [param variant] 는 어떤 토큰 판을 띄울 것인가다 — HUD 도크는 `BOX_HUD`, 월드 위에 펼치는 시트·카드는
## `BOX_CARD`(같은 카드 모양에 그림자만 얹힌다).
## [param alpha] 는 판 바탕의 불투명도(음수면 테마·설정 값 · HUD 판은 `GoTheme.HUD_ALPHA`).
## 🔑 HUD 는 월드 위에 바로 얹히므로 **그림이 복잡한 게임일수록 값을 올린다** — 글자가 읽히는 것이 먼저다.
static func hud_panel(accent := Color.TRANSPARENT, pad_x := -1.0, pad_y := -1.0,
		variant := GoTheme.BOX_HUD, alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "HudPanel"
	style_hud_panel(node, accent, pad_x, pad_y, variant, alpha)
	return node


## **이미 만든 `PanelContainer`** 에 같은 떠 있는 판을 입힌다 — 의미색이 런타임에 바뀌는 자리(EXP 배지처럼
## 값에 따라 초록·주황·회색이 되는 것)에서 노드를 다시 만들지 않는다. 인자는 `hud_panel()` 과 같다.
static func style_hud_panel(node: PanelContainer, accent := Color.TRANSPARENT, pad_x := -1.0, pad_y := -1.0,
		variant := GoTheme.BOX_HUD, alpha := -1.0) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	var face := GoUi.skin().floating_box(variant, accent, alpha)
	face_padding(face, pad_x, pad_y)
	node.add_theme_stylebox_override(&"panel", face)


## 🔑 **이미 만든 아무 노드에 판 한 장을 입힌다** — 판을 만드는 일은 gohud 가, 그 판을 어디에 입힐지는
## 부르는 쪽이 정한다. 위 `style_hud_panel()` 이 "떠 있는 HUD 판"으로 좁혀진 짝이라면, 이것은 그 원시형이다.
##
## 쓰는 자리 — ① `PanelContainer` 가 아닌 노드(`Panel`·`Button`·`Label`)에 입힐 때 ② 떠 있지 **않은** 판이
## 필요할 때(카드 안에 깔리는 칩은 그림자가 붙으면 떠 보인다) ③ `normal`·`hover`·`pressed` 처럼 **상태별**로
## 다른 판을 줄 때 ④ 스킨이 만든 판(`surface()`·`GoSkin.alert_box()`)을 그대로 입힐 때.
##
## [param face] 는 `surface()`·`box()`·`edge_card()`·`GoUi.skin().*_box()` 가 돌려준 판이다.
## [param state] 는 테마 아이템 이름(패널류는 `panel`, 버튼류는 `normal`·`hover`·`pressed`·`disabled`).
## 🛑 판이 여백을 가지면 그 위에 `padding()` 칸을 또 두르지 않는다(내용 폭이 두 배로 깎인다 · `hud_panel()` 과 같은 이유).
static func style_panel(node: Control, face: StyleBox, state := &"panel") -> void:
	if node == null or face == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(state, face)


## 🪟 **이미 놓여 있는 판 한 장을 반투명하게 만든다** — gohud 가 만들지 않은 컨테이너에 같은 규칙을
## 입히는 길이다(손으로 만든 `PanelContainer`, 씬에 그려 둔 판, 호스트 프로젝트의 제 판).
##
## ```gdscript
## var frame := PanelContainer.new()
## add_child(frame)                       # 🛑 트리에 붙인 **뒤에** 부른다 — 부모에서 물려받은 테마를 읽는다
## GoStyle.fade_panel(frame)              # 테마·설정이 정한 값
## GoStyle.fade_panel(frame, 0.6)         # 이 판만 60%
## GoStyle.fade_panel(frame, 1.0)         # 되돌린다(판 덮기를 걷어낸다)
## ```
##
## ## 🔑 여러 번 불러도 한 번만 묽어진다
## 처음 부를 때 **원래 판을 메타에 적어 두고** 언제나 그것에서 다시 계산한다. 그러지 않으면
## `_notify()` 로 다시 그릴 때마다 판이 한 겹씩 더 묽어져 결국 사라진다 — 알파를 곱셈으로
## 입히는 방식(`GoSkin.fade_box`)의 유일한 함정이고, 그 함정을 여기서 막는다.
##
## [param alpha] 음수면 테마·설정 값(`GoUi.surface_alpha(variant)`), [param state] 는 테마 아이템 이름
## (패널류는 `panel`, 버튼류는 `normal`·`hover` …), [param variant] 는 어느 종류의 값을 따를 것인가다.
static func fade_panel(node: Control, alpha := -1.0, state := &"panel",
		variant := GoTheme.BOX_PANEL) -> void:
	if node == null: return
	var key := StringName("go_solid_face_" + String(state))
	var base: StyleBox = node.get_meta(key) if node.has_meta(key) else null
	if base == null:
		# 🛑 덮어 둔 판을 먼저 걷어낸다 — 안 그러면 이미 묽어진 판을 "원래 판" 으로 적어 둔다.
		node.remove_theme_stylebox_override(state)
		base = node.get_theme_stylebox(state)
		if base == null: return
		node.set_meta(key, base)
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(variant)
	if opacity >= 1.0:
		node.remove_theme_stylebox_override(state)
		return
	node.add_theme_stylebox_override(state, GoSkin.fade_box(base.duplicate(), opacity))


## `fade_panel()` 이 적어 둔 "원래 판" 을 **잊는다** — 테마·생김새 묶음을 갈아 끼운 뒤 다음 `fade_panel()`
## 이 지금 테마에서 판을 다시 잡게 한다. 🛑 이것을 빠뜨리면 새 테마의 창이 **옛 테마의 판**을 쓴다.
static func forget_face(node: Control, state := &"panel") -> void:
	if node == null: return
	var key := StringName("go_solid_face_" + String(state))
	if node.has_meta(key): node.remove_meta(key)


## 🔑 **누르는 자리보다 작은 시각 판** — 버튼 안에 판 한 장을 깔고 버튼 폭을 따라가게 한다.
##
## 손가락이 닿는 칸은 터치 하한(48)을 지켜야 하지만 **보이는 판은 그보다 작아야** 하는 자리가 있다
## (HUD 의 얇은 띠·상태 바). 버튼을 키우면 화면이 답답하고, 판을 키우면 누르기 어렵다 — 둘을 나눈다.
## 판은 입력을 받지 않으므로(IGNORE) 눌리는 자리는 버튼 그대로다.
##
## [param height] 는 보이는 판의 높이(dp), [param face] 를 주면 그 판을, 없으면 떠 있는 HUD 판을 쓴다.
## 돌려받은 `Panel` 에 자식을 얹어 꾸밀 수 있다(자리 배치는 부르는 쪽이 정한다 — `PanelContainer` 가 아니다).
static func touch_face(button: Button, height := 38.0, face: StyleBox = null) -> Panel:
	if button == null: return null
	var node := Panel.new()
	node.name = "Surface"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(node, face if face != null else floating(GoTheme.BOX_HUD))
	button.add_child(node)
	button.resized.connect(func() -> void: node.size = Vector2(button.size.x, height))
	return node


## 🔑 **지도·월드 그림 위에 얹는 알약 판** 한 장 — 뒤 그림이 무엇이든 글자가 읽히게 바탕을 어둡게 깔고 테두리를
## 얇게 두른다(`GoSkin.overlay_box`). `hud_panel()` 이 HUD 도크의 판이라면 이것은 **그림 위의 작은 크롬**이다.
##
## [param pad_x]·[param pad_y] 는 판 안쪽 여백(dp · 음수면 작은 버튼 여백 토큰), [param fill_alpha] 는 바탕의
## 불투명도다(0.0~1.0 · **음수면 테마·설정이 정한 HUD 값** `GoTheme.HUD_ALPHA`). 🛑 여기에 `padding()` 칸을 또 두르지 않는다(`hud_panel()` 과 같은 이유).
## 🛑 **알약 안에 또 알약을 넣지 않는다** — 안에 놓는 버튼은 맨 버튼이나 `segmented()` 칸으로 둔다.
static func overlay_panel(pad_x := -1, pad_y := -1, fill_alpha := -1.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "OverlayPanel"
	style_overlay_panel(node, pad_x, pad_y, fill_alpha)
	return node


## **이미 만든 `PanelContainer`** 에 같은 알약 판을 입힌다. 인자는 `overlay_panel()` 과 같다.
static func style_overlay_panel(node: PanelContainer, pad_x := -1, pad_y := -1, fill_alpha := -1.0) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box(pad_x, pad_y, fill_alpha))


## 판 안쪽 여백을 지정한 값으로 바꾼다 — 음수인 쪽은 판이 가진 값을 그대로 둔다.
## 스킨이 준 커스텀 판에도 `StyleBox` 의 같은 속성이 있으므로 모양(테두리·발광·모서리)은 그대로다.
static func face_padding(face: StyleBox, pad_x := -1.0, pad_y := -1.0) -> void:
	if face == null: return
	if pad_x >= 0.0:
		face.content_margin_left = pad_x
		face.content_margin_right = pad_x
	if pad_y >= 0.0:
		face.content_margin_top = pad_y
		face.content_margin_bottom = pad_y


## 판의 **네 변을 따로** 정한다 — 음수인 변은 그대로 둔다. 좌우가 같아도 되는 자리는 `face_padding()` 이고,
## 이것은 한쪽만 달라야 할 때다(오른쪽 끝이 터치 칸 48 짜리 아이콘 버튼이라 판 여백이 필요 없는 알약 등).
static func face_insets(face: StyleBox, left := -1.0, top := -1.0, right := -1.0, bottom := -1.0) -> void:
	if face == null: return
	if left >= 0.0: face.content_margin_left = left
	if top >= 0.0: face.content_margin_top = top
	if right >= 0.0: face.content_margin_right = right
	if bottom >= 0.0: face.content_margin_bottom = bottom


## 🔑 **HUD 원형 버튼의 원판** — 게임 화면 위에 떠 있는 둥근 아이콘 버튼(조작 패드·유틸리티 줄)의 판이다.
##
## 🛑 모서리 반경은 **보이는 원의 지름**에서 나온다. 테마에 반경을 숫자로 박아 두면 크기가 다른 버튼에서
##    원이 알약이 된다(반경 24 짜리 판이 104×64 버튼에 들어가 그렇게 됐다).
## 🔑 [param fill] 이 투명이면 **속을 그리지 않는다**(`draw_center = false`) — 그림(그라디언트 이미지·보석)을
##    자식이 그리는 버튼이라, 판까지 칠하면 그 위에 색이 한 겹 더 얹힌다. 판은 테두리와 모서리만 맡는다.
## [param edge_width] 0 이면 테두리 없음(맨 판) · [param edge_ink] 테두리 색 ·
## [param detail] 모서리 곡선 분할. 기본 1 은 **모서리마다 삼각형 팬을 만들지 않는다** — 화면에 스무 개씩
## 깔리는 버튼이라 그 비용이 그대로 곱해진다. 큰 원을 매끄럽게 그려야 하면 8·16 을 준다.
static func style_hud_disc(node: Control, diameter: float, edge_width := 0.0,
		edge_ink := Color.TRANSPARENT, fill := Color.TRANSPARENT, detail := 1) -> void:
	if node == null: return
	var face := box(GoTheme.BOX_HUD)
	face.set_content_margin_all(0)
	face.bg_color = fill
	face.draw_center = fill.a > 0.0
	face.set_corner_radius_all(maxi(0, roundi(diameter * 0.5)))
	face.corner_detail = maxi(1, detail)
	var width := maxi(0, roundi(edge_width))
	face.set_border_width_all(width)
	if width > 0 and edge_ink.a > 0.0: face.border_color = edge_ink
	# 🛑 그림자를 그리지 않는다 — `StyleBoxFlat` 의 그림자는 본체와 **별개의 사각형**을 더 그린다.
	face.shadow_size = 0
	node.add_theme_stylebox_override(&"panel", face)


## 🔑 **퀵슬롯 판을 노드에 입힌다** — `GoSlot` 을 쓰지 않고 자기 슬롯을 만든 호스트(칸 안의 줄 구성이 다른
## 게임)도 같은 판을 얻는다. 모양은 스킨의 `slot_box` 가 정하므로 생김새를 갈면 함께 따라온다.
## [param lit] 은 쿨다운·잔여 시간이 도는 중이라는 뜻이다(테두리가 굵고 채움이 짙어진다).
static func style_slot_face(node: Control, accent: Color, lit := false) -> void:
	if node == null: return
	node.add_theme_stylebox_override(&"panel", GoUi.skin().slot_box(accent, lit))


## 🔑 **꽉 채운 배지** — 개수·알림처럼 **눈에 띄어야 하는 수** 한 칸. 판을 [param fill] 로 채우고 글자를
## [param ink] 로 쓴다. `GoSkin.badge_box` 는 표면 위에 얹는 **옅은** 배지라 역할이 다르다.
##
## 🛑 글자 크기는 여기서 정하지 않는다 — `typography(node, GoTheme.ROLE_MICRO, ink)` 로 **역할**을 준다.
##    크기를 override 로 박으면 그 배지만 모바일 축소·테마 교체를 따라오지 못한다.
## [param edge] 는 테두리 색, [param edge_width] 0 이면 테두리 없음. [param radius] 음수면 `radius_small`
## 토큰, [param pad_x] 음수면 판이 가진 좌우 여백 그대로. [param detail] 은 `style_hud_disc` 와 같다.
static func style_count_badge(node: Label, fill: Color, ink := Color.TRANSPARENT,
		edge := Color.TRANSPARENT, edge_width := 0, radius := -1, pad_x := -1.0, detail := 1) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	var face := box(GoTheme.BOX_HUD)
	face.set_content_margin_all(0)
	face.bg_color = fill
	face.draw_center = true
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL) if radius < 0 else radius)
	face.corner_detail = maxi(1, detail)
	var width := maxi(0, edge_width)
	face.set_border_width_all(width)
	if width > 0 and edge.a > 0.0: face.border_color = edge
	face.shadow_size = 0
	if pad_x >= 0.0:
		face.content_margin_left = pad_x
		face.content_margin_right = pad_x
	node.add_theme_stylebox_override(&"normal", face)
	if ink.a > 0.0: node.add_theme_color_override(&"font_color", ink)


## 🔑 **이미 글리프가 든 노드의 크기·색만** 다시 입힌다 — `glyph_text()` 로 한 번 그린 아이콘을
## 상태가 바뀔 때마다(눌림·올림·켜짐) 새로 조회하지 않고 색만 옮기는 자리다.
##
## [param size] 음수면 크기를 건드리지 않는다 — HUD 의 글리프 크기는 터치 지름에 비례하는 기하라
## 부르는 쪽이 정한다(토큰이 아니다).
## 🛑 [param states] 를 끄지 않는 한 버튼은 올림·눌림·포커스 글자색까지 **같은 색**으로 맞춘다.
##    한 상태만 빠뜨리면 마우스를 올린 채 누르는 순간 글리프 색이 테마 기본으로 튄다.
static func glyph_type(node: Control, size := -1, ink := Color.TRANSPARENT, states := true) -> void:
	if node == null: return
	if size >= 0: node.add_theme_font_size_override(&"font_size", size)
	if ink.a <= 0.0: return
	node.add_theme_color_override(&"font_color", ink)
	if not states or not (node is Button): return
	for key in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(key, ink)


## 칩과 **같은 알약 판**에 내용을 채우는 빈 컨테이너 — 한 줄짜리 칩으로는 모자란 자리(이름·레벨·게이지가 함께 드는
## 명단 카드)에 쓴다. [param fill_alpha] 는 `style_chip_button` 과 같다(음수면 스킨 틴트 그대로).
static func chip_panel(accent := Color.TRANSPARENT, fill_alpha := -1.0) -> PanelContainer:
	var color := accent if accent.a > 0 else GoUi.color(GoTheme.SECONDARY)
	var node := PanelContainer.new()
	node.name = "ChipPanel"
	node.theme = GoUi.theme()
	var face := _chip_face(color, false)
	if fill_alpha >= 0.0 and &"bg_color" in face: face.set(&"bg_color", Color(color, fill_alpha))
	node.add_theme_stylebox_override(&"panel", face)
	return node


## 🔑 **고르는 카드.** 버튼 한 장에 상태별 판을 입힌다 — 고른 카드만 의미색 테두리와 옅은 채움을 얻고, 올리면 테두리만 물든다.
## 내용(아이콘·제목·설명)은 부르는 쪽이 안쪽 `MarginContainer` 로 채운다.
##
## 🛑 **판 여백은 모든 상태에서 0** 이다 — 상태마다 판 여백이 다르면 고른 카드만 넓어져 줄이 흔들린다.
## 🔑 판은 스킨의 `surface()` 에서 온다 — 각진 판·단조 판 테마에서도 그 모양 그대로 색만 바뀐다. 포커스 판은 덮지 않는다.
##
## [param selected] — [param toggle] 을 끈 카드에서 이 카드를 고른 것으로 그린다(고를 때마다 목록을 다시 짓는 화면).
## [param toggle] — 켜면 `toggle_mode` 의 눌린 상태가 곧 선택이다. 같은 무리는 부르는 쪽이 `ButtonGroup` 하나로 묶는다.
## [param dim_disabled] — 켜면 비활성 카드를 옅게, 끄면 평소 판을 그대로 쓴다(비활성으로 바뀔 때 색이 튀지 않게).
## [param filter] — 음수면 `mouse_filter` 를 건드리지 않는다. 🛑 스크롤 안의 카드는 `MOUSE_FILTER_PASS` 를 넘긴다 —
##   STOP 이면 카드 위에서 시작한 끌기가 스크롤로 넘어가지 않는다. 함수가 알아서 정하지 않는 이유는 HUD 처럼 월드 위에 뜬
##   버튼은 STOP 이어야 하기 때문이다(PASS 면 누른 이벤트가 월드로 샌다).
static func style_choice_card(node: Button, accent: Color, selected := false, toggle := true,
		dim_disabled := true, filter := -1) -> void:
	node.theme = GoUi.theme()
	node.clip_text = false
	node.text = ""
	if toggle: node.toggle_mode = true
	if filter >= 0: node.mouse_filter = filter as Control.MouseFilter
	var idle := surface(GoTheme.BOX_CARD)
	var hover := surface(GoTheme.BOX_CARD, accent)
	var chosen := _choice_face(accent)
	var picked := selected and not toggle
	var normal := chosen if picked else idle
	var off := normal
	if dim_disabled:
		off = surface(GoTheme.BOX_CARD)
		if &"bg_color" in off:
			var back: Color = off.get(&"bg_color")
			off.set(&"bg_color", Color(back, back.a * 0.6))
	var faces := {&"normal": normal, &"hover": chosen if picked else hover, &"pressed": chosen,
		&"hover_pressed": chosen, &"disabled": off}
	for state: StringName in faces:
		var face: StyleBox = faces[state]
		face.set_content_margin_all(0)
		node.add_theme_stylebox_override(state, face)


## 고른 카드 판 — 평소 판 색을 의미색 쪽으로 16% 물들이고, 테두리를 의미색 0.9 · 두께 2 로. 스킨 판 종류를 가정하지 않는다.
static func _choice_face(accent: Color) -> StyleBox:
	var face := surface(GoTheme.BOX_CARD, accent)
	if &"bg_color" in face:
		var back: Color = face.get(&"bg_color")
		face.set(&"bg_color", back.lerp(Color(accent, back.a), 0.16))
	if &"border_color" in face: face.set(&"border_color", Color(accent, 0.9))
	if face is StyleBoxFlat: (face as StyleBoxFlat).set_border_width_all(2)
	elif &"border_width" in face: face.set(&"border_width", 2.0)
	return face


## 🔑 **카드 안의 내용 칸** — 판 여백이 0 인 카드(`style_choice_card` 로 꾸민 버튼 등)를 채우는 안쪽 여백 한 번 · 세로 줄.
## 카드 높이가 내용(줄바꿈된 글자 포함)을 따라간다(`fit_content_height`).
## 🛑 판에 여백이 있는 `PanelContainer`(`card()`)에 쓰면 여백이 두 겹이 된다 — 그 카드에는 `column()` 을 바로 넣는다.
## 🛑 카드가 버튼이면 내용을 다 채운 뒤 `let_input_through(body)` 를 부른다 — 누르는 것은 카드다.
## [param padding] 음수면 `padding_compact` 토큰(dp), [param spacing] 음수면 `gap_tiny` 토큰(dp).
static func card_body(card: Control, padding := -1, spacing := -1) -> VBoxContainer:
	var inset := MarginContainer.new()
	inset.name = "Inset"
	insets(inset, GoUi.metric(GoTheme.PADDING_COMPACT) if padding < 0 else padding)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inset)
	var body := column(GoUi.metric(GoTheme.GAP_TINY) if spacing < 0 else spacing)
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(body)
	fit_content_height(card, inset)
	return body


## 이 노드와 그 아래 모든 컨트롤이 **입력을 받지 않게** 한다 — 카드 버튼 위의 글자·아이콘이 누름과 올림을 가로채지 않게.
## 🔑 컨테이너의 기본은 PASS 라 이벤트를 부모로 넘기기는 하지만, 마우스 진입을 먼저 받아 카드의 올림 판이 켜지지 않는다.
static func let_input_through(node: Node) -> void:
	if node is Control: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): let_input_through(child)


## **한 줄 라벨** — 줄바꿈하지 않고 넘치면 말줄임(…)으로 자른다. 좁은 카드의 이름·수치 줄에 쓴다.
## 🛑 말줄임 라벨의 최소 폭은 거의 0 이다 — 칸이 좁으면 글자가 통째로 사라진 것처럼 보인다. 칸 폭은 부르는 쪽이 확보한다.
static func line(text: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label:
	var node := label(text, role, ink)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.set_meta(&"go_no_wrap", true)
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.clip_text = true
	return node


## 작은 알약형 표식(상태·태그·수량).
## [param icon] 을 주면 아이콘 세트의 그림을 글자 앞에 놓는다 — 글자가 비어 있으면 **아이콘만** 있는 칩이다(HUD 버프 표시 등).
## [param icon_size] 음수면 `list_glyph` 토큰. [param urgent] 는 곧 사라질 것(남은 시간이 얼마 없는 버프)에 경고 테두리를 입힌다.
static func chip(text: String, ink := Color.TRANSPARENT, translate := false, icon: StringName = &"",
		icon_size := -1, urgent := false) -> PanelContainer:
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY)
	var node := PanelContainer.new()
	node.name = "Chip"
	node.theme = GoUi.theme()
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override(&"panel", _chip_face(color, urgent))
	# 🛑 글자는 칩 **판 위에서** 읽혀야 한다 — 같은 색 틴트 배경이라 그대로 쓰면 묻힌다.
	var ink_on_chip := GoUi.skin().chip_ink(color)
	var text_node: Label = null
	if not text.is_empty():
		text_node = label_key(text, GoTheme.ROLE_COMPACT, ink_on_chip) if translate \
			else label(text, GoTheme.ROLE_COMPACT, ink_on_chip)
		text_node.autowrap_mode = TextServer.AUTOWRAP_OFF
		text_node.set_meta(&"go_no_wrap", true)
		text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if icon.is_empty():
		node.add_child(text_node)
		return node
	var glyph := GoUi.icons().node(icon, GoUi.metric(GoTheme.LIST_GLYPH) if icon_size < 0 else icon_size, ink_on_chip)
	if text_node == null:
		# 🔑 아이콘만 있는 칩은 **정사각에 가깝게** — 좌우 여백도 위아래와 같게 줄인다(HUD 버프 줄처럼 같은 칸을 늘어놓는 자리).
		var face := node.get_theme_stylebox(&"panel")
		var tight := float(GoUi.metric(GoTheme.GAP_TINY))
		face.content_margin_left = tight
		face.content_margin_right = tight
		node.add_child(glyph)
		return node
	var line_row := row(GoUi.metric(GoTheme.GAP_TINY))
	line_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line_row.add_child(glyph)
	line_row.add_child(text_node)
	node.add_child(line_row)
	return node


## 칩 판 — 모양은 스킨이 정하고, 급한 것만 경고 테두리로 바꾼다(스킨 판 종류를 가정하지 않는다).
static func _chip_face(color: Color, urgent: bool) -> StyleBox:
	var face := GoUi.skin().chip_box(color)
	if urgent and &"border_color" in face:
		face.set(&"border_color", Color(GoUi.color(GoTheme.DANGER), 0.9))
	return face


## 이미 만든 칩의 **판만** 다시 입힌다 — 의미색이 바뀌거나(파티장이 바뀐 명단) 남은 시간이 줄어드는 표시처럼
## 자주 갱신되는 곳에서 노드를 다시 만들지 않는다. 글자·아이콘 색은 부르는 쪽이 함께 바꾼다.
static func restyle_chip(node: PanelContainer, ink: Color, urgent := false) -> void:
	if node == null: return
	node.add_theme_stylebox_override(&"panel", _chip_face(ink if ink.a > 0 else GoUi.color(GoTheme.SECONDARY), urgent))


## **이미 만든 라벨**에 칩 판을 입힌다 — 폭을 직접 재서 칸을 잡는 자리(HUD 상태 바의 배지)처럼 `chip()` 의
## 컨테이너를 쓸 수 없을 때. 글자색도 판 위에서 읽히도록 맞춘다.
static func style_chip_label(node: Label, accent: Color, urgent := false) -> void:
	node.theme = GoUi.theme()
	var face := _chip_face(accent, urgent)
	node.add_theme_stylebox_override(&"normal", face)
	node.add_theme_color_override(&"font_color", GoUi.skin().chip_ink(accent))


## 🔑 **칩처럼 생긴 버튼** — 틴트 알약 판을 모든 상태에 입힌다. HUD 의 상태 버튼(따라가기·나가기), 알림 배지,
## 목록의 작은 동작 단추처럼 "누를 수 있는 칩" 자리에 쓴다. 글자·아이콘은 부르는 쪽이 넣는다(판만 입힌다).
##
## [param fill_alpha] 가 음수면 스킨 칩 판의 틴트 그대로다. 값을 주면 그만큼 의미색으로 채운다 —
## 0.08 처럼 옅게 주면 조용한 상태 버튼, 0.85 처럼 크게 주면 **강조** 버튼이다(채운 판 위 글자색은 부르는 쪽이
## `typography(node, role, ink)` 로 준다). [param urgent] 는 경고 테두리다.
## 🔑 포커스 판은 덮지 않는다 — 공용 Theme 의 포커스 링이 키보드·게임패드로 조작할 때만 뜬다.
## 🛑 `mouse_filter` 를 건드리지 않는다 — HUD 위 버튼은 STOP 이어야 누른 이벤트가 월드로 새지 않는다.
static func style_chip_button(node: Button, accent: Color, fill_alpha := -1.0, urgent := false) -> void:
	node.theme = GoUi.theme()
	var face_ink := accent
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var face := _chip_face(accent, urgent)
		if fill_alpha >= 0.0 and &"bg_color" in face: face.set(&"bg_color", Color(accent, fill_alpha))
		if state == &"normal": face_ink = GoUi.skin().readable_on(accent, GoSkin.blend(GoSkin.box_background(face), GoUi.color(GoTheme.SURFACE)))
		node.add_theme_stylebox_override(state, face)
	# 🛑 글자는 **칩 판 위에서** 읽혀야 한다 — 같은 색 틴트 위에 같은 색 글자를 얹는 전형적인 자리다(`chip()` 과 같은 규칙).
	#    채운 판에서는 이 값이 어두운 쪽으로 간다.
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(key, face_ink)


## 🔑 **원형 조작 버튼** — 지도의 줌 ＋/－ · 내 위치처럼 그림 위에 뜬 동그란 단추의 상태 판을 입힌다.
## 글자·아이콘은 부르는 쪽이 넣는다(`glyph_text()`·`font_role()`), 여기는 판만 맡는다.
##
## 판 여백은 모든 상태에서 0 이고 모서리 반경은 [param diameter] 의 절반이다 — 보이는 크기는 부르는 쪽이
## `custom_minimum_size` 로 정한 지름 그대로이고, 상태가 바뀌어도 폭이 흔들리지 않는다.
## [param fill] 은 평상시 바탕색(투명이면 `surface` 토큰), [param fill_alpha] 는 평상시 그 색의 불투명도다
## (올렸을 때·비활성은 1.0 — 그림 위에서 더 또렷해진다). 누른 상태는 의미색을 [param press_alpha] 만큼 채운다.
## 🛑 `mouse_filter` 를 건드리지 않는다 — 그림 위 버튼은 STOP 이어야 누름이 지도·월드로 새지 않는다.
## 🛑 판은 `surface()` 가 아니라 `box()` 에서 온다 — **둥근 것이 이 버튼의 뜻**이라, 각진 판·단조 판 스킨의
##    모양을 지키면 원이 사각형이 된다(`style_hud_disc()` 와 같은 판단). 색·여백은 스킨 값을 그대로 옮겨 온다.
static func style_disc_button(node: Button, diameter: float, accent: Color, fill := Color.TRANSPARENT,
		fill_alpha := 0.92, press_alpha := 0.34) -> void:
	if node == null: return
	node.theme = GoUi.theme()
	var back := fill if fill.a > 0 else GoUi.color(GoTheme.SURFACE)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		var face := box(GoTheme.BOX_HUD, accent)
		var pressed: bool = state == &"pressed" or state == &"hover_pressed"
		var focused: bool = state == &"focus"
		face.bg_color = Color(accent, press_alpha) if pressed \
			else Color(back, fill_alpha if state == &"normal" else 1.0)
		face.border_color = Color(accent, 0.7 if focused else 0.42)
		face.set_border_width_all(2 if focused else 1)
		face.set_corner_radius_all(maxi(1, int(diameter * 0.5)))
		face.set_content_margin_all(0)
		node.add_theme_stylebox_override(state, face)


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


## 🔑 **gohud 규격의 툴팁 한 장.** `Control._make_custom_tooltip()` 에서 돌려준다.
##
## 🛑 엔진 기본 툴팁을 그대로 두면 글자가 **한 자씩 세로로** 쪼개진다 — 라벨에 줄바꿈이 걸린 채
##    최대 폭이 1dp 로 계산된 탓이다(2026-09-13 실측: `settings` 가 폭 1 · 높이 186 으로 나왔다).
##    폭을 우리가 정하면 그 계산에 기대지 않는다.
static func tooltip_node(text: String, max_width := 260.0) -> Control:
	# 🛑 **판을 다시 그리지 않는다.** 엔진이 이 노드를 자기 `TooltipPanel` 안에 넣으므로, 여기서
	#    판을 하나 더 만들면 테두리가 **두 겹**으로 보인다(2026-09-13 실측). 글자만 돌려준다.
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # 이미 번역된 문구가 들어온다
	# 🛑 `go_no_wrap` 을 달아 둔다 — 폼이 자손 라벨에 줄바꿈을 강제하는데, 툴팁은 그 대상이 아니다.
	label.set_meta(&"go_no_wrap", true)
	typography(label, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.TEXT))
	# 짧은 문구는 한 줄로 둔다. 길면 그때만 접되, **접을 폭을 우리가 준다.**
	var wide := label.get_theme_font(&"font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x
	if wide > max_width:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = max_width
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## 트리 전체에 폼 규격을 입힌다 — 나중에 추가되는 자식까지 같은 규격이 되게.
##
## 🛑🛑 자손 `Label` 의 줄바꿈을 **보장한다.** 없으면 긴 문장 하나가 한 줄로 뻗고, 그 최소 폭이
##    화면을 넘겨 좌우가 잘린다 — 무슨 화면인지조차 분간할 수 없게 된다.
##    씬마다 손으로 켜는 방식은 **반드시 빠뜨린다.** 그래서 컨테이너가 스스로 보장한다.
static func form(node: Node) -> void:
	# 🛑 제 간격을 쓰는 묶음(`field()` — 라벨이 자기 칸에 붙어야 한다)은 건드리지 않는다.
	if node is BoxContainer and not node.has_meta(&"go_own_spacing"):
		node.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	if node is Button:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, GoUi.metric(GoTheme.BUTTON_HEIGHT))
		# 🛑 자연 폭으로 표시된 것(흐르는 줄의 칸, 「뒤로」처럼 낱말 하나)은 건드리지 않는다.
		if GoUi.config.autowrap_text: fit_words(node)
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
	# 🛑 **`select()`(OptionButton) 와 나란히 놓인다** — 데모에서 둘이 위아래로 붙어 있는데 글자 정렬과
	#    화살표 크기가 달라 다른 부품처럼 보였다(2026-09-13 데모 촬영 실측). 글자는 왼쪽, 화살표는
	#    OptionButton 이 쓰는 그림과 같은 크기로 맞춘다.
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var arrow := GoUi.theme().get_icon(&"arrow", &"OptionButton") if GoUi.theme() != null and GoUi.theme().has_icon(&"arrow", &"OptionButton") else null
	apply_icon(node, GoIconSet.CHEVRON_DOWN, arrow.get_width() if arrow != null else GoUi.metric(GoTheme.LIST_GLYPH))
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


## 팝업 메뉴의 항목이 **터치 하한**을 지키게 줄 간격을 띄운다 — 팝업 글자는 본문 크기라 줄이 손가락보다 얇다.
## [param spacing] 음수면 `gap` 토큰. 🔑 항목을 지우고 다시 채워도 이 값은 남는다(테마 값이지 항목이 아니다).
## [param alpha] 는 메뉴 판 바탕의 불투명도(0.0~1.0) — 음수면 `GoTheme.POPUP_ALPHA`(기본 테마는 **100**).
##
## 🛑 **팝업 메뉴는 기본이 꽉 찬 색이다.** 다른 판과 달리 `PopupMenu` 는 엔진이 창(`Window`)으로 띄울 수
##    있고, 그때는 OS 가 게임 화면과 합성해 주지 않아 반투명이 **뒤가 보이는 대신 검게** 나온다
##    (`gui_embed_subwindows` 가 꺼진 프로젝트). 게임 안에 박아 띄우는 프로젝트라면 값을 내려도 좋다.
static func style_popup(popup: PopupMenu, spacing := -1, alpha := -1.0) -> void:
	if popup == null: return
	popup.theme = GoUi.theme()
	popup.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP) if spacing < 0 else spacing)
	var opacity := alpha if alpha >= 0.0 else GoUi.surface_alpha(GoTheme.BOX_POPUP)
	if opacity < 1.0:
		popup.add_theme_stylebox_override(&"panel",
			GoSkin.fade_box(GoUi.box(GoTheme.BOX_POPUP), opacity))


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
## `compact` 를 켜면 **좁은 크롬용 작은 칸**이다 — 칸 최소 폭이 터치 하한이고, 칸 판 여백이 작은 버튼 여백 토큰이다.
## 🔑 지도·HUD 위 알약처럼 폭이 빠듯한 곳에 쓴다. 기본 칸(최소 폭 터치 ×1.5 · 카드 여백)은 폼·설정 화면용이다.
static func segmented(options: Array, selected := 0, action := Callable(), translate := false,
		compact := false) -> HBoxContainer:
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
		item.custom_minimum_size.x = GoUi.metric(GoTheme.TOUCH) * (1.0 if compact else 1.5)
		# 양 끝만 둥글고 가운데는 각지게 — 한 덩어리로 읽힌다. 실제 모양은 스킨이 정한다.
		# 🛑 작은 칸은 **모든 상태에 같은 여백**을 준다 — 상태마다 여백이 다르면 누를 때마다 칸 폭이 흔들린다.
		# 🔑 작은 칸은 바깥 알약(`GoSkin.overlay_box`) **안에** 놓인다 — 고르지 않은 칸은 판을 그리지 않아
		#    테두리가 두 겹으로 보이지 않고, 고른 칸만 강조색으로 채워진다.
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			var face := GoUi.skin().segment_box(index, count, state)
			if compact: face = _compact_segment(face, state)
			item.add_theme_stylebox_override(state, face)
		item.add_theme_color_override(&"font_pressed_color", GoUi.color(GoTheme.ON_ACCENT))
		item.add_theme_color_override(&"font_hover_pressed_color", GoUi.color(GoTheme.ON_ACCENT))
		if action.is_valid(): item.pressed.connect(action.bind(index))
		line.add_child(item)
	return line


## 작은 칸 판 — 여백은 작은 버튼 토큰, 고르지 않은 칸은 판을 그리지 않고, 포커스는 옅은 링, 나머지는 테두리 없이 칸마다 둥글게.
## 🔑 스킨이 커스텀 판(사선·중세)을 줘도 규칙은 같다 — 고르지 않은 칸은 빈 판, 고른 칸·올린 칸은 스킨 판에 여백만 맞춘다.
static func _compact_segment(face: StyleBox, state: StringName) -> StyleBox:
	var result := face
	if state == &"focus":
		result = GoUi.box(GoTheme.BOX_FOCUS_SOFT)
	elif state == &"normal":
		result = GoUi.box(GoTheme.BOX_EMPTY)
	else:
		var flat := face as StyleBoxFlat
		if flat != null:
			flat.set_border_width_all(0)
			flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
			flat.shadow_size = 0
	_compact_insets(result)
	return result


## 판 안쪽 여백을 작은 버튼 여백 토큰으로(좌우 · 위아래). 스킨이 준 커스텀 판에도 같은 속성이 있다.
static func _compact_insets(face: StyleBox) -> void:
	if face == null: return
	var x := float(GoUi.metric(GoTheme.COMPACT_PADDING_X))
	var y := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y))
	face.content_margin_left = x
	face.content_margin_right = x
	face.content_margin_top = y
	face.content_margin_bottom = y


## 🔑 **선택 격자(Choice Grid).** 색 견본·아이콘·글자 카드를 늘어놓고, 누른 칸 하나만 선택된 채 남는다.
## 캐릭터 꾸미기(피부색·머리색·옷), 아바타·난이도 고르기처럼 **그림으로 고르는** 곳에 쓴다.
##
## 항목은 사전이다(문자열이면 글자 카드).
##   `color`   색 견본 원 — 실제 색 그대로 그린다(`Color` 또는 `"f6cfae"` 같은 문자열)
##   `icon`    `GoIconSet` 아이콘 이름 · `texture` 그림(`Texture2D`)
##   `text`    아래 이름표. 비우면 견본·그림만 보인다
##   `tooltip` 툴팁 = 접근성 이름. 🛑 글자 없는 견본에는 **꼭 준다** — 색만으로는 무엇인지 알 수 없다
## 고르면 `action.call(index)`. 돌려주는 흐르는 줄의 `meta("group")` 이 `ButtonGroup` 이다.
## 🔑 고른 칸은 판을 칠하지 않고 **두꺼운 강조 테두리**로 표시한다 — 견본의 색이 섞이지 않고,
##    색을 구분하기 어려운 사람도 테두리 두께로 고른 칸을 안다.
##
## ```gdscript
## var skins := GoStyle.choice_grid([{"color": "f6cfae", "tooltip": "Peach"}, {"color": "8d5a36", "tooltip": "Cocoa"}],
## 	0, func(i: int) -> void: look.skin = i)
## ```
static func choice_grid(items: Array, selected := 0, action := Callable(), translate := false) -> HFlowContainer:
	var line := wrap_row()
	line.name = "ChoiceGrid"
	var group := ButtonGroup.new()
	line.set_meta(&"group", group)
	for index in items.size():
		var item: Dictionary = items[index] if items[index] is Dictionary else {"text": str(items[index])}
		var cell := _choice_cell(item, translate)
		cell.button_group = group
		cell.button_pressed = index == selected
		if action.is_valid(): cell.pressed.connect(action.bind(index))
		line.add_child(cell)
	return line


## 선택 격자의 한 칸 — 스킨 판(`choice_box`) 위에 견본·그림·이름표를 세로로 쌓는다.
static func _choice_cell(item: Dictionary, translate: bool) -> Button:
	var cell := Button.new()
	cell.name = "Choice"
	cell.theme = GoUi.theme()
	# 🛑 변형 이름을 둔다 — 비워 두면 `GoForm` 이 일반 버튼으로 다시 칠하고 가로로 늘여 격자가 깨진다(`form()`).
	cell.theme_type_variation = GoTheme.VAR_BUTTON
	cell.toggle_mode = true
	cell.focus_mode = Control.FOCUS_ALL
	# 🛑 스크롤 안에 놓이므로 손가락 끌기를 스크롤에 넘긴다(`style_button` 과 같은 이유).
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	cell.tooltip_text = str(item.get("tooltip", item.get("text", "")))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		cell.add_theme_stylebox_override(state, GoUi.skin().choice_box(state))
	var touch := float(GoUi.metric(GoTheme.TOUCH))
	var inset := float(GoUi.metric(GoTheme.GAP_SMALL))
	var content := column(GoUi.metric(GoTheme.GAP_TINY))
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = inset
	content.offset_top = inset
	content.offset_right = -inset
	content.offset_bottom = -inset
	cell.add_child(content)
	if item.has("color"):
		var diameter := maxf(touch - inset * 2.0, float(GoUi.metric(GoTheme.ICON_SIZE)))
		var swatch := Panel.new()
		swatch.name = "Swatch"
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.custom_minimum_size = Vector2(diameter, diameter)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ink: Variant = item["color"]
		swatch.add_theme_stylebox_override(&"panel", GoUi.skin().swatch_box(diameter, ink if ink is Color else Color(str(ink))))
		content.add_child(swatch)
	elif item.get("texture") is Texture2D:
		var picture := TextureRect.new()
		picture.name = "Picture"
		picture.texture = item["texture"]
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2.ONE * (touch - inset * 2.0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(picture)
	elif item.has("icon"):
		var glyph := GoUi.icons().node(StringName(str(item["icon"])), GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.TEXT))
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(glyph)
	var text := str(item.get("text", ""))
	if text != "":
		var caption := label_key(text, GoTheme.ROLE_COMPACT) if translate else label(text, GoTheme.ROLE_COMPACT)
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.set_meta(&"go_no_wrap", true)
		content.add_child(caption)
	# 칸 크기 = 내용 + 안쪽 여백, 가로·세로 모두 터치 크기 이상. 번역·글꼴이 바뀌면 다시 잰다.
	var fit := func() -> void:
		if not is_instance_valid(cell) or not is_instance_valid(content): return
		var need := content.get_combined_minimum_size() + Vector2(inset, inset) * 2.0
		cell.custom_minimum_size = Vector2(maxf(touch, need.x), maxf(touch, need.y))
	content.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
	fit.call()
	return cell


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
	node.add_theme_stylebox_override(&"panel", GoUi.skin().disc_box(size, ink, 0.22, 0.6))
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
	node.add_theme_stylebox_override(&"panel", GoUi.skin().skeleton_box())
	node.tree_entered.connect(func() -> void:
		if GoUi.config.reduce_motion: return
		var pulse := node.create_tween().set_loops()
		pulse.tween_property(node, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(node, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	return node


## 🔑 **알림 상자(Alert).** 화면 안에 붙박이로 두는 안내 — 스낵바(`GoNotice`)와 달리 사라지지 않는다.
## `tone` 은 색 토큰(`GoTheme.INFO`·`SUCCESS`·`WARNING`·`DANGER`). 아이콘을 비우면 톤에 맞는 기본 아이콘.
static func alert(message: String, tone := GoTheme.INFO, icon: StringName = &"", translate := false,
		alpha := -1.0) -> PanelContainer:
	var ink := GoUi.color(tone)
	var node := PanelContainer.new()
	node.name = "Alert"
	node.theme = GoUi.theme()
	node.add_theme_stylebox_override(&"panel", GoUi.skin().alert_box(ink, alpha))
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
