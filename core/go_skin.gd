## 🖌️ **모양을 정하는 한 장.** 테마가 못 가는 곳 — 코드가 직접 그리는 자리 — 이 여기 모여 있다.
##
## ## 왜 테마만으로는 모자란가
## `Theme` 는 **엔진이 그려 주는 것**의 모양만 바꾼다. 그런데 gohud 에는 코드가 스스로 그리는
## 자리가 있다: 조이스틱의 원, 퀵슬롯의 판, 코치마크의 링과 화살표, 칩·스켈레톤·알림 상자.
## 이것들은 `StyleBoxFlat` 을 코드에서 만들거나 `_draw()` 로 직접 그리므로, `.tres` 를 아무리
## 갈아 끼워도 **둥근 모서리가 각지지 않는다.** 그 결정을 전부 이 리소스로 뺀 것이 스킨이다.
##
## ```gdscript
## # 자기 모양을 만들려면 이것을 상속해 필요한 것만 덮어쓴다.
## class_name MySkin extends GoSkin
## func slot_box(accent: Color, lit: bool) -> StyleBox:
##     var box := GoStyleBoxCut.new()
##     box.bg_color = accent
##     return box
##
## # 꽂는 법 — 셋 중 하나
## GoUi.config.skin = preload("res://ui/my_skin.tres")   # ① 직접
## GoUi.use_preset(GoThemePresets.SCIFI_DARK)            # ② 테마와 한 묶음으로
## # ③ 아무것도 안 한다 — 이 기본 스킨이 gohud 의 원래 모양을 그린다.
## ```
##
## ## 🛑 이 클래스의 본문은 **gohud 의 원래 모양 그 자체**다
## 여기 있는 코드는 예전에 `GoStyle`·`GoSlot`·`GoJoystick`·`GoCoachMark`·`GoNotice` 안에 흩어져
## 있던 것을 **한 줄도 바꾸지 않고** 옮겨 온 것이다. 그래서 스킨을 안 꽂으면 화면은 픽셀 하나까지
## 예전과 같다. 자식 스킨이 덮어쓰지 않은 메서드도 마찬가지다 — 부분 교체가 안전하다.
##
## ## 🛑 이 파일은 위젯을 참조하지 않는다
## `GoUi` 의 토큰 조회(`color`·`metric`·`box`)만 쓴다. 위젯을 참조하면
## `GoUi → GoConfig → GoSkin → 위젯 → GoStyle → GoUi` 로 고리가 닫힌다.
@tool
class_name GoSkin
extends Resource

## 화면에 보이는 이름(에디터·갤러리의 고르개에 쓴다). 비우면 리소스 이름.
@export var skin_name := ""

# ── 다이얼 — 스킨 **리소스(.tres)** 에서 숫자만 바꾼다 ───────────────────
#
# 🔑 코드에 박혀 있던 숫자를 밖으로 냈다(2026-09-13 — 테마마다 자유도를 높여 달라는 요청).
#    `GoSkin` 을 상속하지 않고도 `themes/palettes/<id>.json` 의 `skin.dials` 로 슬롯 테두리 두께나
#    조이스틱 링 투명도를 바꿀 수 있다. 🛑 기본값을 바꾸면 `tools/skin_dials.json` 도 같이 바꾼다 —
#    검사가 둘을 대조한다(스캐폴딩이 그 표로 "바꿀 수 있는 것" 을 풀어 적기 때문이다).
@export_group("Dials")
# 🔑 다이얼마다 `##` 한 줄 — 사이트 생성기(`tools/make_site.py`)가 이 줄을 읽어 다이얼 표와 용어 사전을
#    채운다. 묶어서 쓰면 표에서 `_lit` 와 `_idle` 중 어느 것이 쿨다운 중인지 순서로만 알 수 있다(I-72).
## 칩 판 채움의 투명도.
@export var chip_fill_alpha := 0.16
## 칩 판 테두리의 투명도.
@export var chip_edge_alpha := 0.45
## 알림 상자 판이 상태색 쪽으로 물드는 비율.
@export var alert_tint := 0.10
## 쿨다운 중인 퀵슬롯 판이 강조색 쪽으로 물드는 비율.
@export var slot_tint_lit := 0.24
## 평소 퀵슬롯 판이 강조색 쪽으로 물드는 비율.
@export var slot_tint_idle := 0.08
## 쿨다운 중인 퀵슬롯의 테두리 두께(dp).
@export var slot_border_lit := 2
## 평소 퀵슬롯의 테두리 두께(dp).
@export var slot_border_idle := 1
## 배지(수량·남은 시간) 판의 가로 안쪽 여백(dp).
@export var badge_pad_x := 5
## 배지 판의 세로 안쪽 여백(dp).
@export var badge_pad_y := 1
## 배지 판 테두리의 투명도.
@export var badge_edge_alpha := 0.6
## 떠 있는 카드(코치마크·프롬프트 카드) 그림자의 투명도.
## 🛑 얕으면(8dp·0.35) 정보 패널 위에 얹혔을 때 "떠 있다" 가 안 읽힌다(2026-09-13 데모 실측, I-69).
@export var float_shadow_alpha := 0.45
## 떠 있는 카드 그림자의 번짐(dp).
@export var float_shadow_size := 14
## 떠 있는 카드 그림자가 아래로 밀리는 거리(dp).
@export var float_shadow_lift := 4
## 사선 판(sci-fi)처럼 그림자 대신 **발광**을 쓰는 판이 떠 있을 때의 발광 거리(dp).
@export var float_glow_size := 10.0
## 조이스틱 바탕 원의 투명도.
@export var joystick_base_alpha := 0.42
## 조이스틱 링의 투명도.
@export var joystick_ring_alpha := 0.45
## 조이스틱 링의 두께(dp).
@export var joystick_ring_width := 2.0
@export_group("")


# ── 읽히게 만들기 ───────────────────────────────────────────────────────
#
# 🛑 **같은 색 틴트 위에 같은 색 글자**는 예뻐 보이고 안 읽힌다. 칩(`accent` 16% 판 위 `accent` 글자),
#    쿨다운 중인 슬롯의 남은 시간이 그렇다 — 판이 글자 쪽으로 밝아져 명도 차가 사라진다.
#    테마 쪽은 생성기가 미리 계산해 두지만, **스킨이 실행 중에 만드는 색**은 여기서 민다.

## WCAG 상대 명도. 🛑 `Color.get_luminance()` 를 쓰지 않는다 — 그것은 감마를 풀지 않아
## WCAG 값과 다르고, 어두운 색에서 특히 크게 어긋난다.
static func luminance(color: Color) -> float:
	var parts := [color.r, color.g, color.b]
	var linear := []
	for value in parts:
		linear.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


## 두 색의 명도 대비비(1~21).
static func contrast_ratio(front: Color, back: Color) -> float:
	var a := luminance(front)
	var b := luminance(back)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## 반투명한 색을 깔린 색 위에 얹어 **실제로 보이는 색**으로.
static func blend(top: Color, bottom: Color) -> Color:
	if top.a >= 1.0: return top
	return Color(
		top.r * top.a + bottom.r * (1.0 - top.a),
		top.g * top.a + bottom.g * (1.0 - top.a),
		top.b * top.a + bottom.b * (1.0 - top.a), 1.0)


## 🔑 `ink` 를 `back` 위에서 읽히도록 민다 — **색조는 지키고 밝기만** 옮긴다.
##
## 배경이 밝으면 어둡게, 어두우면 밝게 간다. 이미 밝기가 끝까지 간 색(순수 시안 등)은
## 채도를 낮춰 더 밝힌다. 60번 밀어도 못 넘기면 거기서 멈춘다 — 흑백으로 튀면 팔레트의
## 성격이 통째로 사라지고, 그것은 읽히는 것과 별개로 실패다.
static func readable_on(ink: Color, back: Color, need := 4.5) -> Color:
	var flat := blend(ink, back)
	if contrast_ratio(flat, back) >= need: return ink
	var darker := luminance(back) > 0.22
	var out := Color(flat.r, flat.g, flat.b, 1.0)
	for _step in 60:
		if darker:
			out = Color.from_hsv(out.h, out.s, maxf(0.0, out.v - 0.02), 1.0)
		elif out.v >= 0.999:
			out = Color.from_hsv(out.h, maxf(0.0, out.s - 0.035), 1.0, 1.0)
		else:
			out = Color.from_hsv(out.h, out.s, minf(1.0, out.v + 0.02), 1.0)
		if contrast_ratio(out, back) >= need: return out
	return out


## StyleBox 의 배경색(없으면 투명). 커스텀 StyleBox 도 `bg_color` 칸을 쓴다.
static func box_background(box: StyleBox) -> Color:
	if box == null: return Color.TRANSPARENT
	if not (&"bg_color" in box): return Color.TRANSPARENT
	var value = box.get(&"bg_color")
	return value if value is Color else Color.TRANSPARENT


# ── 표면 ───────────────────────────────────────────────────────────────

## 카드·패널의 StyleBox. `accent` 가 있으면 테두리에 그 색을 입힌다.
##
## 🔑 테마가 **커스텀 StyleBox**(각진 판 등)를 줬으면 그대로 돌려준다 — 그것이 모양을 바꾸는 길이다.
## 🛑 `0.5` — 이 값은 gohud 가 파생된 게임의 규범이다. 0.55 로 짰다가 위임 대조 검사에서 잡혔다(2026-09-12).
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT) -> StyleBox:
	var style := GoUi.box(variant)
	var flat := style as StyleBoxFlat
	if flat == null:
		# 테마가 StyleBoxFlat 이 아닌 것을 줬다. 빈 상자면 예전처럼 평판을 새로 만들고,
		# 실제로 그리는 커스텀 상자면 그것을 살린다.
		if style != null and not (style is StyleBoxEmpty):
			if accent.a > 0 and &"border_color" in style: style.set(&"border_color", Color(accent, 0.5))
			return style
		flat = StyleBoxFlat.new()
		flat.bg_color = GoUi.color(GoTheme.SURFACE)
	if accent.a > 0: flat.border_color = Color(accent, 0.5)
	return flat


## 게임 화면 위에 **떠 있는** 표면 — 같은 카드에 얕은 그림자를 더한다.
func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT) -> StyleBox:
	var style := surface_box(variant, accent)
	var flat := style as StyleBoxFlat
	if flat == null:
		# 🛑 사선 판은 그림자를 못 그린다 — 대신 **발광을 키워** 떠 있음을 말한다. 발광이 없는 판(색 0)은 그대로.
		if &"glow_size" in style and &"glow_color" in style and (style.get(&"glow_color") as Color).a > 0.0:
			style.set(&"glow_size", maxf(float(style.get(&"glow_size")), float_glow_size))
		return style
	flat.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha)
	flat.shadow_size = float_shadow_size
	flat.shadow_offset = Vector2(0, float_shadow_lift)
	return flat


## 게임 화면(지도·월드) **위에 얹는 알약 판** — 뒤 그림이 무엇이든 글자가 읽히게 바탕색으로 어둡게 깔고 테두리를 얇게 둔다.
## `h_margin`·`v_margin` 은 판 안쪽 여백(dp) — 음수면 작은 버튼 여백 토큰. `fill_alpha` 는 바탕의 불투명도.
## 🔑 **판 안에 또 판을 넣지 않는다** — 이 알약 안의 버튼은 `GoBareButton` 이나 `segmented()` 칸으로 두어
##    테두리가 두 겹으로 겹쳐 보이지 않게 한다.
func overlay_box(h_margin := -1, v_margin := -1, fill_alpha := 0.82) -> StyleBox:
	var style := surface_box(GoTheme.BOX_HUD)
	var flat := style as StyleBoxFlat
	if flat != null:
		flat.bg_color = Color(GoUi.color(GoTheme.BACKGROUND), fill_alpha)
		flat.border_color = Color(GoUi.color(GoTheme.BORDER), 0.9)
		flat.set_border_width_all(1)
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS))
		flat.shadow_size = 0
	var h := float(GoUi.metric(GoTheme.COMPACT_PADDING_X) if h_margin < 0 else h_margin)
	var v := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y) if v_margin < 0 else v_margin)
	style.content_margin_left = h
	style.content_margin_right = h
	style.content_margin_top = v
	style.content_margin_bottom = v
	return style


## 원형 배지·아바타 테두리 — accent 를 옅게 채우고 같은 색 링을 두른다.
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var style := surface_box(GoTheme.BOX_HUD, accent)
	var flat := style as StyleBoxFlat
	if flat == null: return style
	flat.bg_color = Color(accent, fill_alpha)
	flat.border_color = Color(accent, edge_alpha)
	flat.set_border_width_all(1)
	# 🛑 반지름이 변의 정확히 절반이면(31+31=62) 위아래 모서리가 만나는 자리에 이음매 선이 보인다.
	#    1 만 줄이고 곡선 분할을 올리면 사라진다 — 눈에는 여전히 원이다.
	flat.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
	flat.corner_detail = 16
	flat.set_content_margin_all(0)
	flat.shadow_size = 0
	return flat


## 작은 알약형 표식(상태·태그·수량)의 판.
func chip_box(color: Color) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, chip_fill_alpha)
	style.border_color = Color(color, chip_edge_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	style.corner_detail = 8
	style.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	style.content_margin_right = GoUi.metric(GoTheme.GAP_SMALL)
	style.content_margin_top = GoUi.metric(GoTheme.GAP_TINY)
	style.content_margin_bottom = GoUi.metric(GoTheme.GAP_TINY)
	return style


## 칩 **글자색** — 칩 판 위에서 읽히도록 민 값. 🛑 칩은 같은 색 틴트 위에 같은 색 글자를 얹는
## 전형적인 자리다(밝은 테마에서 3.5:1 까지 떨어졌다 — 2026-09-13 실측).
func chip_ink(color: Color) -> Color:
	var back := blend(box_background(chip_box(color)), GoUi.color(GoTheme.SURFACE_SOFT))
	return readable_on(color, back)


## 퀵슬롯 판 위에 얹는 글자색(남은 시간 등).
func slot_ink(accent: Color, lit: bool) -> Color:
	var back := blend(box_background(slot_box(accent, lit)), GoUi.color(GoTheme.SURFACE_SOFT))
	return readable_on(accent, back)


## 섹션 머리말(`GoStyle.section()`)의 판. 🛑 기본은 **아무것도 그리지 않는다** — 원래 모양은
## 흐린 글자 한 줄이고, 여기서 뭔가를 그리면 그것이 기본 생김새가 바뀌는 것이다.
## 표식을 붙이고 싶은 스킨이 덮어쓴다.
func section_box() -> StyleBox:
	return StyleBoxEmpty.new()


## 구분선 한 줄의 색. 화면의 리듬을 만드는 자리다.
func divider_color() -> Color:
	return GoUi.color(GoTheme.BORDER)


## 구분선의 두께(dp).
func divider_thickness() -> float:
	return 1.0


## 아직 오지 않은 내용의 자리를 잡아 두는 옅은 판.
func skeleton_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	return face


## 화면 안에 붙박이로 두는 안내 상자의 판. `ink` 는 톤 색.
func alert_box(ink: Color) -> StyleBox:
	var style := surface_box(GoTheme.BOX_CARD, ink)
	var flat := style as StyleBoxFlat
	if flat == null: return style
	flat.bg_color = GoUi.color(GoTheme.SURFACE).lerp(ink, alert_tint)
	flat.set_border_width_all(1)
	return flat


## 분절 선택(Segmented)의 한 칸. 양 끝만 둥글고 가운데는 각지게 — 한 덩어리로 읽힌다.
## `state` 는 `&"normal"`·`&"hover"`·`&"pressed"`·`&"hover_pressed"`·`&"focus"`.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var style := surface_box(GoTheme.BOX_CARD)
	var face := style as StyleBoxFlat
	if face == null: return style
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
	return face


## 선택 격자(`GoStyle.choice_grid`) 한 칸의 판. `state` 는 `&"normal"`·`&"hover"`·`&"pressed"`·
## `&"hover_pressed"`·`&"focus"`·`&"disabled"`.
## 🛑 고른 칸은 판을 강조색으로 **채우지 않는다** — 색 견본에 강조색이 섞여 다른 색처럼 보인다. 테두리를 두껍게 두른다.
## 🛑 상태마다 안쪽 여백이 같아야 누를 때 칸이 흔들리지 않는다.
func choice_box(state: StringName) -> StyleBox:
	if state == &"focus":
		var ring := GoUi.box(GoTheme.BOX_FOCUS_SOFT)
		_choice_insets(ring)
		return ring
	var style := surface_box(GoTheme.BOX_CARD)
	_choice_insets(style)
	var face := style as StyleBoxFlat
	if face == null:
		if (state == &"pressed" or state == &"hover_pressed") and &"border_color" in style:
			style.set(&"border_color", GoUi.color(GoTheme.ACCENT))
		return style
	face.shadow_size = 0
	face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	match state:
		&"pressed", &"hover_pressed":
			face.border_color = GoUi.color(GoTheme.ACCENT)
			face.set_border_width_all(CHOICE_RING)
		&"hover":
			face.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
		&"disabled":
			face.bg_color = Color(face.bg_color, face.bg_color.a * 0.5)
	return face


## 선택 격자에서 고른 칸의 테두리 두께(dp). 기본 판 테두리(1)보다 확실히 두꺼워야 한눈에 보인다.
const CHOICE_RING := 3


func _choice_insets(box: StyleBox) -> void:
	if box == null: return
	var inset := float(GoUi.metric(GoTheme.GAP_SMALL))
	box.content_margin_left = inset
	box.content_margin_right = inset
	box.content_margin_top = inset
	box.content_margin_bottom = inset


## 색 견본 원의 판. 게임 데이터의 **실제 색 그대로** 채우고, 어떤 바탕에서도 원의 경계가 보이도록 테두리를 두른다.
func swatch_box(diameter: float, color: Color) -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = color
	flat.border_color = GoUi.color(GoTheme.BORDER)
	flat.set_border_width_all(1)
	# 🛑 반지름을 변의 정확히 절반으로 두면 이음매 선이 보인다(`disc_box` 와 같은 이유).
	flat.set_corner_radius_all(maxi(1, int(diameter * 0.5) - 1))
	flat.corner_detail = 16
	flat.set_content_margin_all(0)
	return flat


## 값 막대의 **채움**. 🛑 테마의 `ProgressBar/fill` 을 복제해서 고친다 — 카드 스타일을
##    빌려 쓰면 그 안쪽 여백(12dp)까지 딸려 와 얇은 막대가 두꺼운 덩어리가 된다.
func progress_fill_box(ink: Color) -> StyleBox:
	var source: StyleBox = null
	for candidate in [GoUi.theme(), GoUi.DEFAULT_THEME]:
		if candidate != null and candidate.has_stylebox(&"fill", &"ProgressBar"):
			source = candidate.get_stylebox(&"fill", &"ProgressBar")
			break
	var copied := source.duplicate() as StyleBox if source != null else null
	var flat := copied as StyleBoxFlat
	if flat == null:
		if copied != null and not (copied is StyleBoxEmpty):
			if &"bg_color" in copied: copied.set(&"bg_color", ink)
			# 🛑 발광이 있으면 **그 색도 채움을 따라간다** — 고정해 두면 빨간 체력 막대가 시안으로 빛난다.
			if &"glow_color" in copied:
				var glow: Color = copied.get(&"glow_color")
				if glow.a > 0.0: copied.set(&"glow_color", Color(ink, glow.a))
			_edge_fill(copied, ink)
			return copied
		flat = StyleBoxFlat.new()
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	flat.bg_color = ink
	_edge_fill(flat, ink)
	return flat


## 🛑 **채움이 바탕에 녹으면 얼마나 찼는지 알 수 없다.** 밝은 테마의 노랑이 그렇다 — 휘도가 본래
##    높아 어떤 회색 바탕 위에서도 3:1 이 나오지 않고, 기준을 맞추려 어둡게 밀면 경험치 막대가
##    **갈색**이 된다(2026-09-13 실측 `#A05000`). 색을 죽이는 대신 **윤곽으로 경계를 만든다** —
##    채움은 선명한 채로 두고, 대비는 테두리가 책임진다.
func _edge_fill(box: StyleBox, ink: Color) -> void:
	if box == null: return
	var track := blend(GoUi.color(GoTheme.TRACK), GoUi.color(GoTheme.SURFACE))
	if contrast_ratio(blend(ink, track), track) >= 3.0: return
	# 바탕보다 어두운 쪽·밝은 쪽 중 **더 벌어지는 쪽**으로, 기준을 넘을 때까지 민다.
	var pick := ink
	for step in range(1, 11):
		var amount := 0.1 * float(step)
		var dark := ink.darkened(amount)
		var light := ink.lightened(amount)
		pick = dark if contrast_ratio(dark, track) >= contrast_ratio(light, track) else light
		if contrast_ratio(pick, track) >= 3.0: break
	if &"border_color" in box: box.set(&"border_color", pick)
	# 🛑 커스텀 StyleBox 는 테두리 두께가 **한 칸**이고, `StyleBoxFlat` 은 네 변이 따로다.
	#    sci-fi 의 채움은 커스텀이라, 이 갈래를 빠뜨렸더니 윤곽이 통째로 안 그려졌다(실측).
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		flat.set_border_width_all(1)
		flat.draw_center = true
	elif &"border_width" in box:
		box.set(&"border_width", maxf(1.0, float(box.get(&"border_width"))))


# ── HUD ────────────────────────────────────────────────────────────────

## 슬롯 모서리에 얹는 **작은 배지**(수량·단축키)의 판. 아이콘과 글자를 세로로 쌓지 않고
## 모서리에 걸쳐 두면 아이콘이 가운데에 크게 남는다(2026-09-13 — 세로로 쌓였을 때 비좁았다).
## 판 모양은 `surface_box` 에서 나오므로 sci-fi 에서는 저절로 각진 배지가 된다.
func badge_box(ink: Color) -> StyleBox:
	var style := surface_box(GoTheme.BOX_HUD, ink)
	style.content_margin_left = badge_pad_x
	style.content_margin_right = badge_pad_x
	style.content_margin_top = badge_pad_y
	style.content_margin_bottom = badge_pad_y
	if &"bg_color" in style: style.set(&"bg_color", GoUi.color(GoTheme.SURFACE_HIGH))
	if &"border_color" in style: style.set(&"border_color", Color(ink, badge_edge_alpha))
	var flat := style as StyleBoxFlat
	if flat != null:
		flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
		flat.set_border_width_all(1)
		flat.shadow_size = 0
	elif &"glow_size" in style:
		style.set(&"glow_size", 0)
	return style


## 퀵슬롯 한 칸의 판. `lit` 은 쿨다운·잔여 시간이 도는 중이라는 뜻이다.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var style := surface_box(GoTheme.BOX_HUD, accent)
	var flat := style as StyleBoxFlat
	if flat == null: return style
	flat.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	flat.set_content_margin_all(0)
	flat.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 0.8), slot_tint_lit if lit else slot_tint_idle)
	flat.border_color = Color(accent, 0.95 if lit else 0.45)
	flat.set_border_width_all(slot_border_lit if lit else slot_border_idle)
	# 🛑 `shadow_size` 를 쓰지 않는다 — StyleBoxFlat 그림자는 본체와 별개의 사각형을 더 그린다.
	#    슬롯은 화면에 여러 개가 깔리므로 그리기 비용이 그만큼 곱해진다.
	flat.shadow_size = 0
	return flat


## 스낵바의 판. `compact` 면 좁은 여백을 준다.
func notice_box(accent: Color, compact: bool) -> StyleBox:
	var surface := surface_box(GoTheme.BOX_NOTICE, accent)
	if compact: surface.set_content_margin_all(GoUi.metric(GoTheme.PADDING_COMPACT))
	return surface


## 이미 붙은 스낵바 판의 **강조색만** 바꾼다 — 표면을 새로 만들지 않는다.
func tint_notice(box: StyleBox, accent: Color) -> void:
	if box == null or accent.a <= 0: return
	if &"border_color" in box: box.set(&"border_color", Color(accent, 0.55))


## 코치마크가 대상 컨트롤에 두르는 링.
func coach_ring_box(accent: Color) -> StyleBox:
	var ring := disc_box(48, accent, 0.0, 1.0)
	if &"border_width_left" in ring:
		ring.set(&"border_width_left", 2)
		ring.set(&"border_width_top", 2)
		ring.set(&"border_width_right", 2)
		ring.set(&"border_width_bottom", 2)
	return ring


# ── 직접 그리기 ─────────────────────────────────────────────────────────

## 가상 조이스틱. 좌표·상태는 위젯이 계산해 넘긴다 — 여기서는 **그리기만** 한다.
## 🛑 같은 종류의 도형끼리 그린다 — 캔버스는 명령 종류가 바뀔 때마다 드로콜을 끊는다.
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	canvas.draw_circle(center, radius, Color(base, joystick_base_alpha))
	canvas.draw_circle(knob, knob_radius, Color(ink, 0.85 if active else 0.55))
	canvas.draw_arc(center, radius, 0, TAU, 48, Color(ink, joystick_ring_alpha), joystick_ring_width, true)


## 코치마크의 카드에서 대상으로 뻗는 화살표.
func draw_coach_pointer(canvas: CanvasItem, start: Vector2, tip: Vector2,
		direction: Vector2, ink: Color) -> void:
	canvas.draw_line(start, tip, ink, 2.0, true)
	var wing := direction.orthogonal() * 4.0
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, tip - direction * 8.0 + wing, tip - direction * 8.0 - wing]), ink)
