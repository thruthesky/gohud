## 🎨 테마 **토큰 이름**과 조회. 색·치수·글자 크기를 부르는 이름이 여기 모여 있다.
##
## ## 왜 이름을 상수로 두나
## `theme.get_color("acent", "GoHud")` 의 오타는 조용히 검정을 돌려준다. 상수로 부르면
## 컴파일이 잡아 준다 — `GoTheme.ACCENT`.
##
## ## 토큰이 사는 곳
## 테마 안의 **`GoHud`** 타입이다 — `GoHud/colors/accent`, `GoHud/constants/touch`.
## 프로젝트가 자기 테마를 넣었는데 이 타입이 없으면 `GoConfig.token_fallback` 이 켜져 있는 한
## gohud 기본 테마에서 채운다. 그래서 **평범한 Theme 를 넣어도 위젯이 깨지지 않는다.**
class_name GoTheme
extends RefCounted

## 토큰이 사는 Theme 타입 이름.
const TYPE := &"GoHud"

# ── 색 ─────────────────────────────────────────────────────────────────
const BACKGROUND := &"background"
const SURFACE := &"surface"
const SURFACE_SOFT := &"surface_soft"
const SURFACE_HIGH := &"surface_high"
const BORDER := &"border"
const TEXT := &"text"
const SECONDARY := &"secondary"
const MUTED := &"muted"
const ACCENT := &"accent"
const ON_ACCENT := &"on_accent"
const SUCCESS := &"success"
const WARNING := &"warning"
const DANGER := &"danger"
const INFO := &"info"
const SCRIM := &"scrim"
const SHADOW := &"shadow"
const TRACK := &"track"

# ── 채움 전용 색 ───────────────────────────────────────────────────────
## 🔑 **같은 뜻인데 쓰임이 반대인 색**이다. `WARNING` 은 글자로 쓰이므로 밝은 바탕에서 읽히려면
## 어두워야 하고, 체력·경험치 **막대의 채움**으로 쓰이면 눈에 띄어야 하므로 밝아야 한다.
## 하나로 버티면 밝은 테마의 경험치 막대가 **갈색**이 된다(2026-09-13 실측).
##
## 🛑 이것은 **선택 토큰**이다 — 테마에 없으면 `_fill` 을 뗀 같은 이름으로 떨어진다.
##    그래서 옛 테마·남의 테마를 그대로 꽂아도 깨지지 않는다.
const SUCCESS_FILL := &"success_fill"
const WARNING_FILL := &"warning_fill"
const DANGER_FILL := &"danger_fill"
const INFO_FILL := &"info_fill"
const ACCENT_FILL := &"accent_fill"

# ── 치수(dp) ───────────────────────────────────────────────────────────
const TOUCH := &"touch"
const BUTTON_HEIGHT := &"button_height"
const GAP_TINY := &"gap_tiny"
const GAP_SMALL := &"gap_small"
const GAP := &"gap"
const GAP_LARGE := &"gap_large"
const PADDING := &"padding"
const PADDING_COMPACT := &"padding_compact"
## 작은 버튼(`GoCompactButton`) 판의 **좌우 · 위아래 여백**. 🛑 `padding_compact`(카드·알림 안쪽 여백)와 다른 값이다 —
##    같이 쓰면 버튼 여백을 바꿀 때 표면 여백까지 흔들린다. 글자가 판 테두리에 붙지 않게 하는 하한이기도 하다
##    (`GoStyle.audit_compact_padding`). 기본 테마 10 · 5.
const COMPACT_PADDING_X := &"compact_padding_x"
const COMPACT_PADDING_Y := &"compact_padding_y"
const RADIUS := &"radius"
const RADIUS_SMALL := &"radius_small"
const RADIUS_LARGE := &"radius_large"
const SCREEN_MARGIN := &"screen_margin"
const SCROLL_DEADZONE := &"scroll_deadzone"
const SCROLL_EDGE := &"scroll_edge"
const SCROLLBAR_WIDTH := &"scrollbar_width"
const LIST_GLYPH := &"list_glyph"
const ICON_SIZE := &"icon_size"
const NOTICE_DURATION_MS := &"notice_duration_ms"

# ── 판 불투명도(%) ─────────────────────────────────────────────────────
## 🪟 **판(컨테이너)의 바탕이 얼마나 꽉 찬 색인가.** 100 이면 뒤가 전혀 보이지 않고, 80 이면
## 20% 만큼 뒤 화면이 배어 나온다 — 대화상자 뒤로 전투가 계속되는 것이 보이고, 시트 아래로 지도가
## 비친다. 게임 UI 에서 이것은 장식이 아니라 **맥락을 잃지 않게 하는 장치**다.
##
## 🛑 **글자·아이콘·버튼은 이 값을 따르지 않는다.** 판만 반투명해지고 그 위의 내용은 선명하게
##    남는다 — 내용까지 함께 흐려지면(`modulate.a`) 읽히지 않는 UI 가 되고, 그것은 투명도의
##    문제가 아니라 고장이다.
##
## 🛑 **퍼센트 정수**다(0~100). `Theme` 의 constant 는 정수만 담기 때문이다. 코드에서 비율
##    (0.0~1.0)로 다루는 자리는 `GoUi.surface_alpha()` 이며 그쪽이 100 으로 나눠 준다.
##    테마·설정 칸에 `0.8` 을 적으면 0 으로 잘려 **판이 통째로 사라진다** — 거기에는 `80` 을 적는다.
##
## 🔑 이것도 **선택 토큰**이다 — 테마에 없으면 100(꽉 찬 색)으로 떨어진다. 그래서 이 토큰을
##    모르는 옛 테마·남의 테마를 그대로 꽂아도 화면은 예전과 같다.
const PANEL_ALPHA := &"panel_alpha"
const CARD_ALPHA := &"card_alpha"
const HUD_ALPHA := &"hud_alpha"
const NOTICE_ALPHA := &"notice_alpha"
const POPUP_ALPHA := &"popup_alpha"

# ── 표면 StyleBox ──────────────────────────────────────────────────────
const BOX_PANEL := &"panel"
const BOX_CARD := &"card"
const BOX_HUD := &"hud"
const BOX_NOTICE := &"notice"
const BOX_POPUP := &"popup"
const BOX_EMPTY := &"empty"
const BOX_FOCUS := &"focus"
const BOX_FOCUS_SOFT := &"focus_soft"

## 판 종류(`BOX_*`) → **그 종류의 불투명도 토큰**. 종류마다 따로 정할 수 있어야 하는 이유는
## 요구가 서로 다르기 때문이다 — 대화상자는 뒤가 조금 보여도 좋지만, 게임 화면 위에 바로 얹히는
## HUD 판은 그림이 복잡할수록 더 꽉 차야 글자가 읽힌다.
## 🛑 `focus`·`empty` 는 없다 — 포커스 링은 판이 아니고, 빈 판은 그릴 것이 없다.
const ALPHA_TOKENS := {
	BOX_PANEL: PANEL_ALPHA,
	BOX_CARD: CARD_ALPHA,
	BOX_HUD: HUD_ALPHA,
	BOX_NOTICE: NOTICE_ALPHA,
	BOX_POPUP: POPUP_ALPHA,
}

# ── 글자 역할 ──────────────────────────────────────────────────────────
## 역할 이름 → 그 크기를 들고 있는 Theme 타입.
## 🛑 역할은 **크기의 이름**이지 용도의 이름이 아니다 — "제목" 이 아니라 "가장 큰 글자" 다.
##    그래야 화면마다 다른 뜻으로 쓰여도 크기 체계가 흔들리지 않는다.
const ROLE_TYPES := {
	&"micro": &"GoMicroLabel",
	&"compact": &"GoCompactLabel",
	&"caption": &"GoCaptionLabel",
	&"body": &"Label",
	&"button": &"Button",
	&"subtitle": &"GoSubtitleLabel",
	&"title": &"GoTitleLabel",
}

const ROLE_MICRO := &"micro"
const ROLE_COMPACT := &"compact"
const ROLE_CAPTION := &"caption"
const ROLE_BODY := &"body"
const ROLE_BUTTON := &"button"
const ROLE_SUBTITLE := &"subtitle"
const ROLE_TITLE := &"title"

# ── 타입 변형 ──────────────────────────────────────────────────────────
const VAR_PANEL := &"GoPanel"
const VAR_CARD := &"GoCard"
const VAR_BUTTON := &"GoButton"
const VAR_PRIMARY_BUTTON := &"GoPrimaryButton"
const VAR_DANGER_BUTTON := &"GoDangerButton"
## 채워진 위험 버튼 — 되돌릴 수 없는 동작의 **확인** 버튼에만 쓴다. 옅은 위험 버튼은 위를 쓴다.
const VAR_DANGER_SOLID_BUTTON := &"GoDangerSolidButton"
const VAR_BARE_BUTTON := &"GoBareButton"
const VAR_COMPACT_BUTTON := &"GoCompactButton"
const VAR_ICON_BUTTON := &"GoIconButton"
const VAR_LIST_BUTTON := &"GoListButton"
const VAR_TITLE_LABEL := &"GoTitleLabel"
const VAR_SUBTITLE_LABEL := &"GoSubtitleLabel"
const VAR_CAPTION_LABEL := &"GoCaptionLabel"
const VAR_COMPACT_LABEL := &"GoCompactLabel"
const VAR_MICRO_LABEL := &"GoMicroLabel"


## 테마에서 색 하나. 없으면 `fallback` 테마에서, 그래도 없으면 자홍색(눈에 띄라고).
static func color_of(theme: Theme, key: StringName, fallback: Theme = null) -> Color:
	if theme != null and theme.has_color(key, TYPE): return theme.get_color(key, TYPE)
	if fallback != null and fallback.has_color(key, TYPE): return fallback.get_color(key, TYPE)
	return Color.MAGENTA


## 테마에서 치수 하나. [param missing] 은 **어느 테마에도 없을 때** 돌려줄 값이다.
## 🛑 치수의 기본은 0 이어도 되지만 **불투명도의 0 은 "판이 안 보인다"** 다 — 그래서 부르는 쪽이
##    빠뜨릴 수 없게 인자로 뺐다(`GoUi.surface_alpha` 는 100 을 준다).
static func metric_of(theme: Theme, key: StringName, fallback: Theme = null, missing := 0) -> int:
	if theme != null and theme.has_constant(key, TYPE): return theme.get_constant(key, TYPE)
	if fallback != null and fallback.has_constant(key, TYPE): return fallback.get_constant(key, TYPE)
	return missing


static func box_of(theme: Theme, key: StringName, fallback: Theme = null) -> StyleBox:
	if theme != null and theme.has_stylebox(key, TYPE): return theme.get_stylebox(key, TYPE)
	if fallback != null and fallback.has_stylebox(key, TYPE): return fallback.get_stylebox(key, TYPE)
	return StyleBoxEmpty.new()


## 역할의 글자 크기. 역할 이름이 낯설면 본문 크기로 떨어진다.
static func font_size_of(theme: Theme, role: StringName, fallback: Theme = null) -> int:
	var type: StringName = ROLE_TYPES.get(role, &"Label")
	for candidate in [theme, fallback]:
		if candidate == null: continue
		var found := _font_size_in_chain(candidate, type)
		if found > 0: return found
	return 16


## 타입에 직접 정의된 글자 크기를 찾되, 없으면 **변형의 base 를 따라 올라간다**(`GoCaptionLabel` → `CaptionLabel` → `Label`).
## 🛑 `Theme.has_font_size()` 는 `default_font_size` 가 있으면 무조건 true 라 못 쓴다 — 직접 정의 목록으로 판정한다.
##    호스트 프로젝트가 자기 변형을 base 로 걸어 정본을 하나로 둘 수 있게 하는 길이다. 0 이면 없음.
static func _font_size_in_chain(theme: Theme, type: StringName) -> int:
	var current := type
	for _depth in 8:
		if current.is_empty(): break
		if theme.get_font_size_list(current).has(&"font_size"): return theme.get_font_size(&"font_size", current)
		current = theme.get_type_variation_base(current)
	if theme.has_default_font_size(): return theme.get_default_font_size()
	return 0


## 판 종류의 **불투명도 토큰 이름**. 낯선 종류는 카드로 본다 — 모르는 판이 갑자기 꽉 차거나
## 사라지는 것보다, 카드와 같은 규칙을 따르는 편이 화면이 한 덩어리로 읽힌다.
static func alpha_token(variant: StringName) -> StringName:
	return ALPHA_TOKENS.get(variant, CARD_ALPHA)


## 숫자 크기 → 가장 가까운 역할. 예전 코드가 `14` 처럼 숫자로 크기를 주던 자리를 이어 준다.
static func role_for_size(size: int) -> StringName:
	if size <= 10: return ROLE_MICRO
	if size <= 12: return ROLE_COMPACT
	if size <= 14: return ROLE_CAPTION
	if size <= 17: return ROLE_BODY
	if size <= 19: return ROLE_BUTTON
	if size <= 24: return ROLE_SUBTITLE
	return ROLE_TITLE
