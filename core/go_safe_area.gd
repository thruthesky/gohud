## 📐 **안전영역** — 노치·둥근 모서리·제스처 바를 피한 실제로 그릴 수 있는 사각형.
##
## ## 왜 별도로 있나
## `get_visible_rect()` 는 화면 전체다. 폰에서 그 위쪽 40dp 는 카메라 구멍이 가린다.
## 창을 통째로 안으로 밀면 배경까지 줄어들어 검은 띠가 생기므로, **배경은 화면 전체를 채우고
## 내용만 이 사각형 안에 둔다.**
##
## ```gdscript
## var area := GoSafeArea.usable_rect(get_window())
## card.position = area.position + ...
## ```
##
## 🛑 데스크톱에서는 화면 전체를 그대로 돌려준다 — 안전영역이라는 개념이 없다.
## 🛑 `GoConfig.respect_safe_area` 를 끄면 어디서나 화면 전체다.
class_name GoSafeArea
extends Control


func _init() -> void:
	name = "SafeArea"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# 🛑 안전영역 자체는 **물리적 방향**이다 — 아랍어·우르두라고 노치가 반대편으로 가지 않는다.
	#    내용의 좌우 방향은 자식이 각자 정한다.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	get_viewport().size_changed.connect(_layout)
	_layout()


## 이 창에서 실제로 쓸 수 있는 사각형(단위 = UI 좌표계).
static func usable_rect(window: Window) -> Rect2:
	if window == null: return Rect2()
	var area := window.get_visible_rect()
	if not GoUi.config.respect_safe_area: return area
	if not GoUi.is_handheld_platform(): return area
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0: return area
	# 안전영역은 **물리 픽셀**로 온다 — UI 좌표계로 내리려면 스트레치 배율로 나눈다.
	var factor := maxf(1.0, window.content_scale_factor)
	var scaled := Rect2(Vector2(safe.position) / factor, Vector2(safe.size) / factor)
	var result := area.intersection(scaled)
	# 교집합이 비면(배율이 아직 안 잡힌 첫 프레임) 화면 전체로 돌아간다 — 0 크기 카드를 만들지 않는다.
	return result if result.size.x > 1.0 and result.size.y > 1.0 else area


## 가상 키보드가 가린 높이를 뺀 사각형. 키보드가 없으면 위와 같다.
static func usable_rect_with_keyboard(window: Window, keyboard_px: int) -> Rect2:
	var area := usable_rect(window)
	if keyboard_px <= 0 or window == null: return area
	var keyboard := float(keyboard_px) / maxf(1.0, window.content_scale_factor)
	var bottom := window.get_visible_rect().size.y - keyboard
	area.size.y = maxf(0.0, minf(area.end.y, bottom) - area.position.y)
	return area


func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var area := usable_rect(get_window())
	position = area.position
	size = area.size
