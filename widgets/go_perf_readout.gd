## 📈 **A performance readout** — a small always-on band of numbers for tuning a game on a weak phone: frames per
## second, frame time and the worst frame, triangles, draw calls, nodes, RAM and VRAM. The fps line turns from the
## good ink to the warning and the bad one as the frame rate drops. It never takes input.
##
## ```gdscript
## var perf := GoPerfReadout.new()
## overlay_layer.add_child(perf)                            # a CanvasLayer above every screen
## perf.position = Vector2(14, 146) + safe_area.position     # a corner clear of the HUD
## perf.tier_text = "LOW (auto)"                            # the quality tier, at the end of the last line
## perf.one_line = true                                     # one slim line, where room is short
## ```
##
## It samples the engine itself (`sampling`): each frame adds to a running sum (no allocation), and every `interval`
## seconds the text is built and written, only when it changed. Turn `sampling` off and feed `show_stats()` instead.
## The band is `GoSkin.perf_box()`, the ink `GoSkin.perf_ink(level)` and the font `GoSkin.perf_font()`.
## Triangles and draw calls come from the RenderingServer, shadow passes included; a headless run reads 0 there.
@tool
class_name GoPerfReadout
extends PanelContainer

const PLACEHOLDER := "FPS --\nTRI --  DRAW --  NODES --\nRAM --  VRAM --"

## Reads the engine every frame and writes every `interval`. Off, it only shows what `show_stats()` is given.
@export var sampling := true:
	set(value):
		sampling = value
		set_process(value and is_inside_tree() and not Engine.is_editor_hint())

## Seconds between two readings.
@export_range(0.05, 5.0, 0.05) var interval := 0.25

## At or above: the good ink.
@export var good_fps := 55.0

## At or above (and below `good_fps`): the warning ink. Below: the bad ink.
@export var warn_fps := 30.0

## The lines joined into one, in a slimmer band (`compact_pad_y` above and below).
@export var one_line := false:
	set(value):
		one_line = value
		_restyle()

## The padding above and below a one-line band (dp).
@export_range(0, 32) var compact_pad_y := 2:
	set(value):
		compact_pad_y = value
		_restyle()

## Text at the end of the last line after "Q " (the quality tier). Empty shows none.
@export var tier_text := "":
	set(value):
		tier_text = value
		_rewrite()

@export_range(6, 64) var font_size := 14:
	set(value):
		font_size = value
		_restyle()

## The dark edge round each letter (dp).
@export_range(0, 16) var outline_size := 2:
	set(value):
		outline_size = value
		_restyle()

var label: Label
## How many times the text was written: an unchanged reading must not add to it.
var write_count := 0

var _stats: Dictionary = {}
var _timer := 0.0
var _frames := 0
var _elapsed := 0.0
var _worst := 0.0
var _ink := Color.TRANSPARENT
var _inked := false


## 999 → "999", 84321 → "84.3k", 1234567 → "1.23M".
static func format_count(n: int) -> String:
	if n >= 1000000: return "%.2fM" % (n / 1000000.0)
	if n >= 1000: return "%.1fk" % (n / 1000.0)
	return str(n)


## Bytes → "512 MB".
static func format_megabytes(bytes: int) -> String:
	return "%d MB" % roundi(bytes / 1048576.0)


func _init() -> void:
	name = "PerfReadout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.name = "Readout"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = PLACEHOLDER
	add_child(label)


func _enter_tree() -> void:
	GoUi.watch(_restyle)
	_restyle()


func _ready() -> void:
	set_process(sampling and not Engine.is_editor_hint())


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


func _process(delta: float) -> void:
	advance(delta)


## Counts a frame of [param delta] seconds, and reads the engine once `interval` has passed.
func advance(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	_worst = maxf(_worst, delta)
	_timer -= delta
	if _timer <= 0.0: _sample()


## Drops the frames counted so far (after the readout was hidden, say), so the next reading is fresh.
func restart() -> void:
	_frames = 0
	_elapsed = 0.0
	_worst = 0.0
	_timer = 0.0


## The last reading (empty before the first).
func stats() -> Dictionary:
	return _stats.duplicate()


## 0 good, 1 warning, 2 bad.
func fps_level(fps: float) -> int:
	if fps >= good_fps: return 0
	if fps >= warn_fps: return 1
	return 2


## Shows a reading — keys `fps`, `ms`, `worst_ms`, `triangles`, `draws`, `nodes`, `ram`, `vram` (bytes for the last
## two). The text is written only when it changed.
func show_stats(reading: Dictionary) -> void:
	_stats = reading.duplicate()
	_rewrite()


func _sample() -> void:
	_timer = interval
	if _frames == 0: return
	var average := _elapsed / _frames
	var reading := {
		&"fps": 1.0 / average if average > 0.0 else 0.0,
		&"ms": average * 1000.0,
		&"worst_ms": _worst * 1000.0,
		&"triangles": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		&"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		&"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		&"ram": OS.get_static_memory_usage(),
		&"vram": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
	}
	_frames = 0
	_elapsed = 0.0
	_worst = 0.0
	show_stats(reading)


func _rewrite() -> void:
	if not is_instance_valid(label): return
	var text := PLACEHOLDER
	if not _stats.is_empty():
		var fps: float = _stats.get(&"fps", 0.0)
		text = "FPS %d  %.1f ms  (worst %.1f)\nTRI %s  DRAW %d  NODES %s\nRAM %s  VRAM %s%s" % [
			roundi(fps), _stats.get(&"ms", 0.0), _stats.get(&"worst_ms", 0.0),
			format_count(_stats.get(&"triangles", 0)), _stats.get(&"draws", 0), format_count(_stats.get(&"nodes", 0)),
			format_megabytes(_stats.get(&"ram", 0)), format_megabytes(_stats.get(&"vram", 0)),
			("  Q " + tier_text) if not tier_text.is_empty() else ""]
		if is_inside_tree(): _paint_level(fps_level(fps))
	if one_line: text = text.replace("\n", "  ")
	if text != label.text:
		label.text = text
		if not _stats.is_empty(): write_count += 1


## Sets the ink of [param level] — only when it is not already the label's, as every override sends a theme change.
func _paint_level(level: int) -> void:
	var ink := GoUi.skin().perf_ink(level)
	if _inked and _ink == ink: return
	_inked = true
	_ink = ink
	label.add_theme_color_override(&"font_color", ink)


func _restyle() -> void:
	if not is_instance_valid(label) or not is_inside_tree(): return
	theme = GoUi.theme()
	_inked = false
	var skin := GoUi.skin()
	var box := skin.perf_box().duplicate() as StyleBox
	if one_line:
		box.content_margin_top = compact_pad_y
		box.content_margin_bottom = compact_pad_y
	add_theme_stylebox_override(&"panel", box)
	var font := skin.perf_font()
	if font != null: label.add_theme_font_override(&"font", font)
	else: label.remove_theme_font_override(&"font")
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", outline_size)
	if not _stats.is_empty(): _paint_level(fps_level(_stats.get(&"fps", 0.0)))
	_rewrite()
