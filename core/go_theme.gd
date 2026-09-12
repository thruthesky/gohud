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

# ── 치수(dp) ───────────────────────────────────────────────────────────
const TOUCH := &"touch"
const BUTTON_HEIGHT := &"button_height"
const GAP_TINY := &"gap_tiny"
const GAP_SMALL := &"gap_small"
const GAP := &"gap"
const GAP_LARGE := &"gap_large"
const PADDING := &"padding"
const PADDING_COMPACT := &"padding_compact"
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

# ── 표면 StyleBox ──────────────────────────────────────────────────────
const BOX_PANEL := &"panel"
const BOX_CARD := &"card"
const BOX_HUD := &"hud"
const BOX_NOTICE := &"notice"
const BOX_POPUP := &"popup"
const BOX_EMPTY := &"empty"
const BOX_FOCUS := &"focus"
const BOX_FOCUS_SOFT := &"focus_soft"

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


static func metric_of(theme: Theme, key: StringName, fallback: Theme = null) -> int:
	if theme != null and theme.has_constant(key, TYPE): return theme.get_constant(key, TYPE)
	if fallback != null and fallback.has_constant(key, TYPE): return fallback.get_constant(key, TYPE)
	return 0


static func box_of(theme: Theme, key: StringName, fallback: Theme = null) -> StyleBox:
	if theme != null and theme.has_stylebox(key, TYPE): return theme.get_stylebox(key, TYPE)
	if fallback != null and fallback.has_stylebox(key, TYPE): return fallback.get_stylebox(key, TYPE)
	return StyleBoxEmpty.new()


## 역할의 글자 크기. 역할 이름이 낯설면 본문 크기로 떨어진다.
static func font_size_of(theme: Theme, role: StringName, fallback: Theme = null) -> int:
	var type: StringName = ROLE_TYPES.get(role, &"Label")
	if theme != null and theme.has_font_size(&"font_size", type): return theme.get_font_size(&"font_size", type)
	if fallback != null and fallback.has_font_size(&"font_size", type): return fallback.get_font_size(&"font_size", type)
	return 16


## 숫자 크기 → 가장 가까운 역할. 예전 코드가 `14` 처럼 숫자로 크기를 주던 자리를 이어 준다.
static func role_for_size(size: int) -> StringName:
	if size <= 10: return ROLE_MICRO
	if size <= 12: return ROLE_COMPACT
	if size <= 14: return ROLE_CAPTION
	if size <= 17: return ROLE_BODY
	if size <= 19: return ROLE_BUTTON
	if size <= 24: return ROLE_SUBTITLE
	return ROLE_TITLE
