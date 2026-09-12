## 📏 **1 unit = 1dp** 좌표계와 브레이크포인트. 화면의 *짧은 변*이 좁을수록 UI 를 크게 그린다.
##
## ## 무엇을 하는가
## ① 화면의 **짧은 변을 dp 로** 재서 브레이크포인트(모바일·태블릿·데스크톱)를 정하고,
## ② UI 좌표계를 **OS 논리 픽셀(dp)** 과 1:1 로 맞춘 뒤,
## ③ 좁은 화면일수록 가독성 보정을 조금 곱한다.
##
## 그래서 씬과 테마에 적는 숫자가 **그대로 dp** 다 — Material·Apple HIG·웹의 권장 수치를
## 환산 없이 쓸 수 있다. 16 짜리 본문은 폰에서 17.6sp 로 보인다.
##
## ## 🛑 기본은 꺼져 있다
## 이 기능은 창의 `content_scale_factor` 를 바꾼다 — 프로젝트 전체의 좌표계에 영향을 준다.
## 남의 프로젝트에서 말없이 켜면 기존 레이아웃이 통째로 어긋난다. `GoConfig.scale_enabled` 를
## 켜는 쪽이 정한다. **꺼 두어도 브레이크포인트 판정과 아래 순수 함수들은 그대로 쓸 수 있다.**
##
## ## 🛑 하지 않는 것
## - 글자를 화면 크기에 **비례**시키지 않는다. `font_size = base * (width / 1920)` 류는
##   화면이 좁을수록 글자가 작아져 읽을 수 없게 된다.
## - 판정을 **창 픽셀로** 하지 않는다. 폰의 실제 픽셀은 1080~1440 이라 픽셀로 재면 폰이 전부
##   "데스크톱" 으로 판정된다. 반드시 dp 로 잰다.
## - 3D 는 영향을 받지 않는다(`canvas_items` 스트레치는 2D 만 바꾼다).
class_name GoScale
extends RefCounted

enum Bp { MOBILE, TABLET, DESKTOP }

## 이 대각 인치보다 작으면 **손에 드는 기기**로 본다. 논리 픽셀의 기준 dpi 가 갈리기 때문이다.
const HANDHELD_MAX_INCHES := 13.0

## 논리 픽셀의 기준 dpi — 손에 드는 기기는 Android dp(160), 데스크톱은 CSS px(96) 관례.
## 시야 거리가 다르기 때문이며 하나로 합칠 수 없다.
const HANDHELD_BASE_DPI := 160.0
const DESKTOP_BASE_DPI := 96.0


## 짧은 변 dp → 브레이크포인트.
static func breakpoint_for_dp(dp: float) -> Bp:
	var settings := GoUi.config
	if dp <= settings.mobile_max_dp: return Bp.MOBILE
	if dp <= settings.tablet_max_dp: return Bp.TABLET
	return Bp.DESKTOP


## 브레이크포인트의 가독성 보정 배수.
##
## `portrait` 는 세로 화면인가 — 폰 모양으로 좁힌 데스크톱 창에는 데스크톱 확대를 적용하지
## 않는다. 그러면 상단 바가 줄바꿈되고 좁은 화면이 더 좁아진다.
static func gain_for(bp: Bp, handheld: bool, portrait := false) -> float:
	var settings := GoUi.config
	var base := settings.read_gain_desktop
	match bp:
		Bp.MOBILE: base = settings.read_gain_mobile
		Bp.TABLET: base = settings.read_gain_tablet
	var phone_layout := bp == Bp.MOBILE and portrait
	return base * (1.0 if handheld or phone_layout else settings.desktop_ui_gain)


## 브레이크포인트의 폼 최대 폭(dp). 0 이면 제한 없음.
static func form_width_for(bp: Bp) -> int:
	var settings := GoUi.config
	match bp:
		Bp.MOBILE: return settings.form_max_width_mobile
		Bp.TABLET: return settings.form_max_width_tablet
		_: return settings.form_max_width_desktop


# ── 순수 함수 — 창 없이도 검사가 같은 식을 검증할 수 있게 static 으로 둔다 ──

## 화면이 손에 드는 크기인가 — 대각 인치로 본다. `screen_px` 는 창이 아니라 **화면 전체**다.
static func is_handheld_size(screen_px: Vector2i, dpi: int) -> bool:
	if dpi <= 0 or screen_px.x <= 0 or screen_px.y <= 0: return false
	var diagonal := sqrt(float(screen_px.x) ** 2 + float(screen_px.y) ** 2)
	return diagonal / float(dpi) < HANDHELD_MAX_INCHES


## OS 디스플레이 배율 — 물리 픽셀을 논리 픽셀로 나누는 값(웹의 `devicePixelRatio` 자리).
##
## 🛑 **Android 에서 `screen_get_scale()` 을 쓰지 않는다** — UI 배율이 아니다. 엔진의 Android
##    구현은 "지원 가능한 최대 배율" 과 화면 밀도 중 **작은 쪽**을 고르기 때문에, density 300
##    인 폰에서 0.90 이 나온다(기대값 1.875). 그 값을 쓰면 384dp 폰이 800dp 태블릿으로 판정돼
##    본문이 8sp 까지 줄어든다. 그래서 손에 드는 기기는 **DPI 로만** 계산한다.
##
## 🛑 데스크톱에서는 반대로 `screen_get_scale()` 이 정확하다(macOS 레티나 2.0). Windows·X11 은
##    미구현이라 0 이 오므로 그때만 DPI 로 되돌린다.
static func display_scale(raw_scale: float, dpi: int, screen_px := Vector2i.ZERO) -> float:
	if is_handheld_size(screen_px, dpi): return maxf(1.0, float(dpi) / HANDHELD_BASE_DPI)
	if raw_scale > 0.0: return raw_scale
	if dpi > 0: return maxf(1.0, float(dpi) / DESKTOP_BASE_DPI)
	return 1.0


## UI 좌표계를 dp 에 맞추는 배율. `Window.content_scale_factor` 에 그대로 넣는다.
static func scale_factor_for(display_scale_value: float, gain: float) -> float:
	return maxf(0.01, display_scale_value * gain)


## 그 배율에서 논리 뷰포트가 몇 units 가 되는지 — 검사가 창 없이 검증하려고 쓴다.
static func logical_size_for(window_px: Vector2i, display_scale_value: float, gain: float) -> Vector2:
	var factor := scale_factor_for(display_scale_value, gain)
	return Vector2(float(window_px.x) / factor, float(window_px.y) / factor)


## 브레이크포인트 이름 — 로그·검사 출력용.
static func breakpoint_name(bp: Bp) -> String:
	return ["MOBILE", "TABLET", "DESKTOP"][int(bp)]
