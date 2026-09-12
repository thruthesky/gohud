## 🔔 **소리와 진동을 한 쌍으로** 묶는 곳. 위젯은 상황 이름만 부르고, 무엇을 재생할지는 여기가 안다.
##
## ## 왜 한 곳인가
## 소리와 진동을 부르는 자리가 흩어지면 **같은 성격의 조작이 화면마다 다르게 반응한다.**
## 확인은 어디서나 같은 소리·같은 진동이어야 한다.
##
## ## 🛑 gohud 는 음원을 담지 않는다
## 애드온에 효과음을 넣으면 프로젝트의 오디오 버스·볼륨 설정·쿨다운과 따로 놀고, 라이선스도
## 따라붙는다. 그래서 **소리를 내는 것은 프로젝트다** — 아래 한 줄만 연결하면 된다.
##
## ```gdscript
## # 게임 부팅 어딘가에서 한 번
## GoFeedback.sound_handler = func(cue: String) -> void: Audio.play(cue)
## ```
##
## 넘어오는 `cue` 는 `GoConfig.sound_cues` 가 정한 이름이다(기본 `ui_open`·`ui_click`…).
## 프로젝트의 음원 이름이 다르면 설정에서 바꿔 끼운다 — 코드를 고칠 필요가 없다.
##
## ## 진동
## Godot 에는 `selectionClick` 같은 이름이 없고 **지속 시간과 세기**만 있다. 세 단계를 쓴다.
##
## | 단계 | 쓰는 곳 | 기본값 |
## |---|---|---|
## | tap | 탭·토글·취소·닫힘 | 10ms · 0.35 |
## | light | 확인·열림 | 20ms · 0.5 |
## | medium | 오류·불가 | 40ms · 0.8 |
##
## 🛑 **손에 드는 기기에서만 떤다.** 데스크톱에는 진동 장치가 없다. `amplitude` 는 Android 만
##    반영하고 iOS 는 무시한다(엔진 동작) — 실제 차이를 만드는 것은 지속 시간이다.
class_name GoFeedback
extends RefCounted

## 프로젝트의 효과음 재생기. `func(cue: String) -> void` 하나면 된다.
## 비워 두면 소리는 나지 않고 진동만 동작한다.
static var sound_handler := Callable()

## 진동기를 직접 갈아 끼우고 싶을 때(테스트·플랫폼 플러그인). `func(ms: int, amplitude: float) -> void`.
## 비워 두면 `Input.vibrate_handheld` 를 쓴다.
static var haptic_handler := Callable()

const OPENED := &"opened"
const CLOSED := &"closed"
const TAPPED := &"tapped"
const CONFIRMED := &"confirmed"
const CANCELED := &"canceled"
const FAILED := &"failed"
const FANFARE := &"fanfare"


## 화면·메뉴·시트·다이얼로그가 **뜬다**.
static func opened() -> void:
	_emit(OPENED, GoUi.config.haptic_light_ms, GoUi.config.haptic_light_amplitude)


## **닫힌다** — 닫기 버튼·바깥 탭·뒤로가기 전부 같은 소리다.
static func closed() -> void:
	_emit(CLOSED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


## 일반 탭 — 대다수 버튼·아이콘·목록 항목.
static func tapped() -> void:
	_emit(TAPPED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


## 확인·긍정 실행(로그인·시작·구매·제출).
static func confirmed() -> void:
	_emit(CONFIRMED, GoUi.config.haptic_light_ms, GoUi.config.haptic_light_amplitude)


## 취소·되돌리기.
static func canceled() -> void:
	_emit(CANCELED, GoUi.config.haptic_tap_ms, GoUi.config.haptic_tap_amplitude)


## 불가·오류(잘못된 입력·조건 미충족). 🛑 경고도 "막혔다" 는 신호라 같은 쌍을 쓴다.
static func failed() -> void:
	_emit(FAILED, GoUi.config.haptic_medium_ms, GoUi.config.haptic_medium_amplitude)


## 큰 성취(드문 사건). 진동은 확인과 같은 세기 — 더 세게 하면 놀란다.
static func fanfare() -> void:
	_emit(FANFARE, GoUi.config.haptic_light_ms, GoUi.config.haptic_light_amplitude)


## 위 일곱 가지 중 하나를 이름으로 부른다.
static func play(signal_name: StringName) -> void:
	match signal_name:
		OPENED: opened()
		CLOSED: closed()
		TAPPED: tapped()
		CONFIRMED: confirmed()
		CANCELED: canceled()
		FAILED: failed()
		FANFARE: fanfare()


static func _emit(signal_name: StringName, duration_ms: int, amplitude: float) -> void:
	var cue: String = GoUi.config.sound_cues.get(signal_name, "")
	if not cue.is_empty() and sound_handler.is_valid(): sound_handler.call(cue)
	_vibrate(duration_ms, amplitude)


static func _vibrate(duration_ms: int, amplitude: float) -> void:
	if not GoUi.config.haptics_enabled or duration_ms <= 0: return
	if haptic_handler.is_valid():
		haptic_handler.call(duration_ms, amplitude)
		return
	# 🛑 플랫폼으로 판정한다 — "창이 좁은가" 가 아니라 "진동 장치가 있는가" 를 묻는 것이다.
	if not GoUi.is_handheld_platform(): return
	Input.vibrate_handheld(duration_ms, amplitude)
