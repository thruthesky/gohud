## ⏱️ **The optional autoload**. It tracks the window size, the breakpoint and the virtual keyboard in one place.
##
## ## It is not required
## Without it every widget works exactly as before and only these three go missing.
##   · the notice when the breakpoint changes (`breakpoint_changed`)
##   · the dp coordinate space of `GoConfig.scale_enabled`
##   · virtual keyboard height tracking (so an input is not hidden behind the keyboard)
##
## ## How to turn it on
## Enabling the plugin registers it automatically under the name `GoRuntime`. To do it by hand, add
## `res://addons/gohud/core/go_runtime.gd` to Project Settings > Autoload under the name `GoRuntime`.
##
## 🛑 The name **must be `GoRuntime`** — `GoUi.runtime()` looks it up by that name.
@tool
extends Node

## The breakpoint changed. Forms and HUDs pick it up and lay their padding and sizes out again.
signal breakpoint_changed(bp: GoScale.Bp)

## The window size changed (it arrives even when the breakpoint stayed the same).
signal viewport_resized(size: Vector2)

## The virtual keyboard height changed (physical pixels).
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


## The current breakpoint.
func current_bp() -> GoScale.Bp:
	return _bp


func is_mobile() -> bool:
	return _bp == GoScale.Bp.MOBILE


## The short side of the current screen (dp).
func short_dp() -> float:
	return _short_dp


## How many dp one unit is (= the current readability gain).
func dp_per_unit() -> float:
	return GoScale.gain_for(_bp, GoUi.is_handheld_platform(), _last_px.x < _last_px.y)


## The maximum form width of the current breakpoint (dp). 0 is no limit.
func form_max_width() -> int:
	return GoScale.form_width_for(_bp)


## The height the virtual keyboard covers (physical pixels). 0 when there is none.
func keyboard_height() -> int:
	return _keyboard


func _on_size_changed() -> void:
	if _applying: return
	_apply(false)


## 🛑 Do not trust `size_changed` alone — change the window with `DisplayServer.window_set_size()` and there are
##    cases where no signal arrives (measured on a macOS `-s` run). The coordinate space then stays stale.
##    It is two integers compared, so the cost is negligible, and when the values match it ends right there.
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
	# A run with no window, headless and the like — the project's base resolution is used.
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
			# No boundary crossed and the window size unchanged: leave it alone — the font atlas gets re-baked every time.
		if force or changed or px != window.content_scale_size:
			_applying = true
				# Keeping base equal to the window pixels makes the stretch ratio 1, so the shrinking is left to factor alone.
			window.content_scale_size = px
			window.content_scale_factor = factor
			_applying = false

	if resized or force: viewport_resized.emit(window.get_visible_rect().size)
	if changed or force: breakpoint_changed.emit(bp)
