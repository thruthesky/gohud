## ⚙️ gohud 의 **설정 한 장**. 테마·아이콘·치수·동작·피드백·번역을 전부 여기서 정한다.
##
## ## 왜 리소스인가
## 설정이 코드 상수면 쓰는 쪽이 포크를 떠야 바꿀 수 있다. `.tres` 한 장으로 빼 두면
## **애드온을 업데이트해도 프로젝트 설정이 살아남는다** — 이것이 애셋으로서 가장 중요한 성질이다.
##
## ## 붙이는 법 — 셋 중 하나
## ```gdscript
## # ① 프로젝트 설정(권장) — 에디터의 Project Settings > General > Gohud > Config 에 경로를 넣는다.
## #    플러그인을 켜면 그 칸이 생기고, gohud 는 첫 위젯을 만들 때 자동으로 읽는다.
##
## # ② 코드에서 직접 — 오토로드·플러그인 없이도 된다.
## GoUi.config = preload("res://ui/my_gohud.tres")
##
## # ③ 아무것도 안 한다 — 기본값으로 동작한다. 설치 직후 바로 쓸 수 있다는 뜻이다.
## ```
##
## ## 🛑 비워 두는 칸이 "기본값" 이다
## `theme` 를 비우면 gohud 기본 테마, `icons` 를 비우면 gohud 기본 아이콘 세트를 쓴다.
## 그래서 **바꾸고 싶은 칸만 채우면 된다** — 전부 채울 필요가 없다.
@tool
class_name GoConfig
extends Resource

## 값이 바뀌면 알린다. `GoUi` 가 받아 열려 있는 위젯을 다시 그린다.
signal changed_settings


# ── 겉모습 ─────────────────────────────────────────────────────────────

@export_group("Appearance")

## 위젯이 쓸 `Theme`. 비우면 gohud 기본(어두운) 테마.
##
## 🔑 **전부 갈아 끼울 필요가 없다** — 기본 테마를 복제해 색만 바꾸거나, 아예 다른 테마를 넣고
##    빠진 토큰은 기본 테마에서 가져오게 둘 수도 있다(`token_fallback`).
@export var theme: Theme:
	set(value):
		theme = value
		emit_changed()
		changed_settings.emit()

## 위 `theme` 에 gohud 토큰(`GoHud/colors/...`)이 없을 때 기본 테마에서 채울 것인가.
## 🛑 끄면 없는 토큰이 검정·0 으로 나온다. 자기 테마를 처음부터 끝까지 채운 경우에만 끈다.
@export var token_fallback := true

## 아이콘 세트. 비우면 gohud 기본 세트(직접 그린 84종 · MIT).
@export var icons: GoIconSet:
	set(value):
		icons = value
		emit_changed()
		changed_settings.emit()

## 개별 색 덮어쓰기 — 테마를 통째로 만들지 않고 `accent` 하나만 바꾸고 싶을 때.
## 키는 `GoTheme.ACCENT` 같은 토큰 이름이다.
@export var color_overrides: Dictionary[StringName, Color] = {}

## 개별 치수 덮어쓰기 — `touch`·`padding`·`radius` 등. 위 `color_overrides` 와 같은 방식이다.
@export var metric_overrides: Dictionary[StringName, int] = {}

## 본문 글자 크기(dp). 0 이면 테마 값 그대로.
@export_range(0, 48) var base_font_size := 0

## 좁은 화면에서 글자만 한 단계 줄인다(터치 영역은 그대로).
## 🛑 터치 크기까지 줄이지 않는다 — 손가락은 화면이 좁아졌다고 작아지지 않는다.
@export var shrink_type_on_mobile := true


# ── 화면 적응 ───────────────────────────────────────────────────────────

@export_group("Responsive")

## `GoScale` 로 **1 unit = 1dp 좌표계**를 잡을 것인가.
##
## 🛑 기본은 **꺼짐**. 이 기능은 창의 `content_scale_factor` 를 바꾸므로 프로젝트 전체의
##    좌표계에 영향을 준다 — 남의 프로젝트에서 말없이 켜면 안 된다. 켜는 쪽이 정한다.
@export var scale_enabled := false

## 짧은 변이 이 dp 이하면 모바일 브레이크포인트.
@export_range(240, 1200) var mobile_max_dp := 576.0

## 짧은 변이 이 dp 이하면 태블릿.
@export_range(480, 2000) var tablet_max_dp := 991.0

## 브레이크포인트별 가독성 보정 — 좁을수록 조금 키운다. 1.0 은 순수 dp.
@export_range(1.0, 1.5, 0.01) var read_gain_mobile := 1.10
@export_range(1.0, 1.5, 0.01) var read_gain_tablet := 1.05
@export_range(1.0, 1.5, 0.01) var read_gain_desktop := 1.00

## 데스크톱에서 UI 를 추가로 키우는 배수(먼 시야 거리 보정). 1.0 이면 없음.
@export_range(1.0, 1.6, 0.01) var desktop_ui_gain := 1.0

## 폼(로그인·설정 같은 세로 목록)의 최대 콘텐츠 폭(dp). 0 은 제한 없음.
@export_range(0, 1200) var form_max_width_mobile := 0
@export_range(0, 1200) var form_max_width_tablet := 440
@export_range(0, 1200) var form_max_width_desktop := 480

## 기기의 안전영역(노치·둥근 모서리)을 피할 것인가. 모바일에서만 실제 효과가 있다.
@export var respect_safe_area := true


# ── 표면(팝업·시트·다이얼로그) ──────────────────────────────────────────

@export_group("Surface")

## 카드의 최대 폭(dp).
@export_range(200, 1600) var surface_max_width := 480.0

## 카드의 최대 높이(dp).
@export_range(200, 2000) var surface_max_height := 700.0

## 카드가 쓰는 화면 높이 비율의 기본값.
@export_range(0.2, 1.0, 0.01) var surface_height_ratio := 0.68

## 🛑 카드가 차지할 수 있는 화면 높이의 **상한**. 위아래로 바깥 화면이 보여야 "떠 있는 창"
##    으로 읽힌다 — 1.0 으로 두면 전체 화면 페이지처럼 보인다.
@export_range(0.4, 1.0, 0.01) var surface_max_height_ratio := 0.72

## 세로 화면에서 카드가 쓰는 폭의 비율.
@export_range(0.5, 1.0, 0.01) var surface_width_ratio_portrait := 0.94

## 가로 화면에서 카드가 쓰는 폭의 비율(좌우가 남으므로 더 좁게).
@export_range(0.3, 1.0, 0.01) var surface_width_ratio_landscape := 0.72

## 배경(스크림)을 눌러 닫을 수 있는가의 기본값. 표면마다 따로 정할 수 있다.
@export var dismiss_on_scrim := false

## 표면을 열 때 카드를 페이드인할 것인가.
@export var surface_fade_in := false

## 페이드 시간(초).
@export_range(0.0, 1.0, 0.01) var fade_seconds := 0.14

## 닫기 버튼의 **보이는** 크기(dp). 터치 영역은 아래 `touch` 토큰까지 노드 밖으로 넓어진다.
@export_range(16, 96) var close_button_visual := 36

## 포인터(마우스·손가락)로 연 창에 포커스 링을 띄우지 않는다.
## 🛑 터치로 메뉴를 열었을 뿐인데 닫기 버튼만 빛나면 "여기를 누르라" 는 신호로 읽힌다.
@export var suppress_pointer_focus_ring := true

## Escape / Android 뒤로가기로 가장 위 표면을 닫는다.
@export var close_on_back := true


# ── 피드백(소리·진동) ──────────────────────────────────────────────────

@export_group("Feedback")

## 진동을 쓸 것인가(Android·iOS 에서만 실제로 떤다).
@export var haptics_enabled := true

## 세 단계 진동의 지속 시간(ms)과 세기. 짧을수록 가볍게 느껴진다.
@export_range(0, 200) var haptic_tap_ms := 10
@export_range(0.0, 1.0, 0.01) var haptic_tap_amplitude := 0.35
@export_range(0, 200) var haptic_light_ms := 20
@export_range(0.0, 1.0, 0.01) var haptic_light_amplitude := 0.5
@export_range(0, 400) var haptic_medium_ms := 40
@export_range(0.0, 1.0, 0.01) var haptic_medium_amplitude := 0.8

## 효과음 신호 이름 → 프로젝트의 음원 큐 이름.
## 🛑 gohud 는 **음원을 담지 않는다.** 소리를 실제로 내는 것은 프로젝트다 —
##    `GoFeedback.sound_handler` 에 Callable 을 하나 꽂으면 이 이름이 그대로 넘어간다.
@export var sound_cues: Dictionary[StringName, String] = {
	&"opened": "ui_open",
	&"closed": "ui_close",
	&"tapped": "ui_click",
	&"confirmed": "ui_confirm",
	&"canceled": "ui_cancel",
	&"failed": "ui_error",
	&"fanfare": "ui_fanfare",
}


# ── 번역 ───────────────────────────────────────────────────────────────

@export_group("Localization")

## gohud 가 쓰는 문구의 번역 키. 프로젝트에 이미 같은 뜻의 키가 있으면 여기서 바꿔 끼운다.
## 🛑 값이 번역 테이블에 **없으면** `tr()` 이 키를 그대로 돌려주므로 화면에 키가 보인다.
##    그럴 때는 아래 `text_overrides` 로 원문을 직접 넣으면 된다.
@export var text_keys: Dictionary[StringName, String] = {
	&"close": "gohud_close",
	&"back": "gohud_back",
	&"next": "gohud_next",
	&"done": "gohud_done",
	&"skip": "gohud_skip",
	&"confirm": "gohud_confirm",
	&"cancel": "gohud_cancel",
	&"search": "gohud_search",
	&"loading": "gohud_loading",
	&"empty": "gohud_empty",
	&"retry": "gohud_retry",
}

## 번역을 거치지 않고 **그대로 쓸 문구**. 번역 테이블을 쓰지 않는 프로젝트를 위한 탈출구다.
## 여기 있는 이름은 위 `text_keys` 보다 우선한다.
@export var text_overrides: Dictionary[StringName, String] = {}

## gohud 기본 번역(11개 문구 × 7언어)을 `TranslationServer` 에 붙일 것인가.
## 🛑 프로젝트가 같은 키를 이미 갖고 있으면 끈다 — 나중에 붙는 쪽이 이긴다.
@export var load_builtin_translations := true


# ── 접근성 ─────────────────────────────────────────────────────────────

@export_group("Accessibility")

## 터치 대상의 최소 한 변(dp). Material 48 · Apple HIG 44 가 근거다.
## 🛑 시각 크기가 아니라 **입력 판정**의 하한이다 — 위젯은 이보다 작아 보일 수 있어도
##    누를 수 있는 범위는 이 값을 지킨다.
@export_range(24, 96) var min_touch_size := 48

## 움직임을 줄인다 — 페이드·코치마크 맥동을 끈다.
@export var reduce_motion := false

## 긴 문구를 줄바꿈한다. 🛑 끄면 한 줄이 길게 뻗어 최소 폭이 화면을 넘길 수 있다.
@export var autowrap_text := true


func _init() -> void:
	# `emit_changed()` 를 부르는 경로(테마·아이콘 setter 등)를 한 곳에서 받는다.
	# 🛑 **코드에서 평범한 칸을 바꾸면 신호가 오지 않는다** — `config.surface_max_width = 600` 은 값만
	#    조용히 바뀐다. 이미 떠 있는 위젯까지 다시 그리려면 바꾼 뒤 `GoUi.refresh()` 를 부른다.
	if not changed.is_connected(_on_changed): changed.connect(_on_changed)


func _on_changed() -> void:
	changed_settings.emit()


## 이 설정의 사본 — 실행 중 한 화면만 다르게 하고 싶을 때.
## 🛑 `duplicate()` 를 그냥 쓰면 Dictionary 가 **공유**되어 한쪽 수정이 다른 쪽에 번진다.
func copy() -> GoConfig:
	var clone: GoConfig = duplicate(true)
	clone.color_overrides = color_overrides.duplicate(true)
	clone.metric_overrides = metric_overrides.duplicate(true)
	clone.sound_cues = sound_cues.duplicate(true)
	clone.text_keys = text_keys.duplicate(true)
	clone.text_overrides = text_overrides.duplicate(true)
	return clone
