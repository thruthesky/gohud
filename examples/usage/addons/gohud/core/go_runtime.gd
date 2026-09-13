## ⏱️ **선택 오토로드**. 창 크기·브레이크포인트·가상 키보드를 한 곳에서 추적한다.
##
## ## 없어도 된다
## 이것이 없으면 위젯은 전부 그대로 동작하고, 아래 세 가지만 빠진다.
##   · 브레이크포인트가 바뀔 때 알림(`breakpoint_changed`)
##   · `GoConfig.scale_enabled` 의 dp 좌표계
##   · 가상 키보드 높이 추적(입력칸이 키보드에 가리지 않게)
##
## ## 켜는 법
## 플러그인을 활성화하면 `GoRuntime` 이라는 이름으로 자동 등록된다. 직접 하려면
## Project Settings > Autoload 에 `res://addons/gohud/core/go_runtime.gd` 를 이름 `GoRuntime` 으로 넣는다.
##
## 🛑 이름이 **반드시 `GoRuntime`** 이어야 한다 — `GoUi.runtime()` 이 그 이름으로 찾는다.
@tool
extends Node

## 브레이크포인트가 바뀌었다. 폼·HUD 가 받아 여백과 크기를 다시 잡는다.
signal breakpoint_changed(bp: GoScale.Bp)

## 창 크기가 바뀌었다(브레이크포인트가 그대로여도 온다).
signal viewport_resized(size: Vector2)

## 가상 키보드 높이가 바뀌었다(물리 픽셀).
signal keyboard_changed(height_px: int)

var _bp := GoScale.Bp.DESKTOP
var _short_dp := 0.0
var _keyboard := 0
var _last_px := Vector2i.ZERO
var _applying := false


func _ready() -> void:
	if Engine.is_editor_hint(): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(true)
	get_tree().root.size_changed.connect(_on_size_changed)


## 지금 브레이크포인트.
func current_bp() -> GoScale.Bp:
	return _bp


func is_mobile() -> bool:
	return _bp == GoScale.Bp.MOBILE


## 지금 화면의 짧은 변(dp).
func short_dp() -> float:
	return _short_dp


## 1 unit 이 몇 dp 인가(= 지금 가독성 보정 배수).
func dp_per_unit() -> float:
	return GoScale.gain_for(_bp, GoUi.is_handheld_platform(), _last_px.x < _last_px.y)


## 지금 브레이크포인트의 폼 최대 폭(dp). 0 이면 제한 없음.
func form_max_width() -> int:
	return GoScale.form_width_for(_bp)


## 가상 키보드가 가린 높이(물리 픽셀). 없으면 0.
func keyboard_height() -> int:
	return _keyboard


func _on_size_changed() -> void:
	if _applying: return
	_apply(false)


## 🛑 `size_changed` 만 믿지 않는다 — `DisplayServer.window_set_size()` 로 창을 바꾸면 신호가
##    오지 않는 경우가 있다(macOS `-s` 실행에서 실측). 그러면 좌표계가 낡은 채로 남는다.
##    정수 두 개 비교라 비용은 무시할 수 있고, 값이 같으면 그 자리에서 끝난다.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	var px := DisplayServer.window_get_size()
	if px != _last_px: _apply(false)
	_poll_keyboard()


func _poll_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return
	var height := DisplayServer.virtual_keyboard_get_height()
	if height == _keyboard: return
	_keyboard = height
	keyboard_changed.emit(height)


func _apply(force: bool) -> void:
	var window := get_tree().root
	var px := DisplayServer.window_get_size()
	# 헤드리스 등 창이 없는 실행 — 프로젝트의 기준 해상도를 쓴다.
	if px.x <= 0 or px.y <= 0: px = window.content_scale_size
	if px.x <= 0 or px.y <= 0: px = Vector2i(1152, 648)
	var scale := GoScale.display_scale(
		DisplayServer.screen_get_scale(), DisplayServer.screen_get_dpi(), DisplayServer.screen_get_size())
	var resized := px != _last_px
	_short_dp = float(mini(px.x, px.y)) / scale
	_last_px = px
	var bp := GoScale.breakpoint_for_dp(_short_dp)
	var changed := bp != _bp
	_bp = bp
	GoUi.set_mobile_type(bp == GoScale.Bp.MOBILE)

	if GoUi.config.scale_enabled:
		var gain := GoScale.gain_for(bp, GoUi.is_handheld_platform(), px.x < px.y)
		var factor := GoScale.scale_factor_for(scale, gain)
		# 경계를 넘지 않았고 창 크기도 그대로면 손대지 않는다 — 폰트 아틀라스가 매번 다시 구워진다.
		if force or changed or px != window.content_scale_size:
			_applying = true
			# base 를 창 픽셀과 같게 두어 스트레치 배율을 1 로 만들고, 축소는 factor 하나로만 한다.
			window.content_scale_size = px
			window.content_scale_factor = factor
			_applying = false

	if resized or force: viewport_resized.emit(window.get_visible_rect().size)
	if changed or force: breakpoint_changed.emit(bp)
