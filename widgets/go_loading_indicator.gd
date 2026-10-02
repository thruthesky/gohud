## 🫧 **Loading indicator** — Material 3 Expressive's wait mark: one shape that keeps turning and morphing into the next
## (a soft burst, a nine-sided cookie, a pentagon, a pill, a sun, a four-sided cookie, an oval). For a wait under about
## five seconds where there is no progress to show — pulling a feed to refresh, opening a product page.
##
## ```gdscript
## var wait := GoLoadingIndicator.new()
## page.add_child(wait)                 # 48dp; it runs while it is visible
## wait.contained = true                # on a round container — over pictures and busy backgrounds
## ```
##
## ## 🔑 Which wait mark
## `GoLoadingIndicator` for a short wait in a page; `GoSpinner` for a small inline wait (a button, a row); `GoProgress`
## when the progress is known (a download, an upload).
##
## ## 🔑 Motion is optional
## With `GoUi.config.reduce_motion` on, the shape stands still and only breathes — no turning, no morphing.
## The colours come from the skin (`GoSkin.loading_colors`): the accent by default; `primary`, or `on-primary-container`
## on a `primary-container` disc when contained, under Material.
@tool
class_name GoLoadingIndicator
extends Control

## Draw the shape on a round container.
@export var contained := false:
	set(value):
		contained = value
		queue_redraw()

## Side of the indicator (dp) and of the shape inside it — `_md-comp-loading-indicator.scss`.
const EXTENT := 48.0
const SHAPE := 38.0
## Time each morph takes (seconds), and one full turn of the steady rotation.
const MORPH := 0.65
const TURN := 4.6
## Points around each shape.
const POINTS := 96

static var _shapes: Array[PackedFloat32Array] = []

var _time := 0.0


func _init() -> void:
	name = "LoadingIndicator"
	custom_minimum_size = Vector2.ONE * EXTENT
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shapes.is_empty(): _shapes = _build_shapes()


func _ready() -> void:
	accessibility_name = GoUi.text(&"loading")
	visibility_changed.connect(_sync_process)
	_sync_process()
	GoUi.watch(queue_redraw)


func _exit_tree() -> void:
	GoUi.unwatch(queue_redraw)


func _sync_process() -> void:
	set_process(is_visible_in_tree() and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var colors := GoUi.skin().loading_colors(contained)
	var scale := minf(size.x, size.y) / EXTENT
	var center := size * 0.5
	if contained and colors[1].a > 0.0:
		draw_circle(center, EXTENT * 0.5 * scale, colors[1], true, -1.0, true)
	var ink: Color = colors[0]
	var radius := SHAPE * 0.5 * scale
	var radii: PackedFloat32Array
	var turn := 0.0
	if GoUi.config.reduce_motion:
		# 🔑 Still, and breathing — the wait still reads without anything moving.
		radii = _shapes[1]
		ink.a *= 0.65 + 0.35 * (0.5 + 0.5 * sin(_time * TAU / 1.6))
	else:
		var step := int(floor(_time / MORPH))
		var within := fmod(_time, MORPH) / MORPH
		var eased := _spring(within)
		var from := _shapes[step % _shapes.size()]
		var to := _shapes[(step + 1) % _shapes.size()]
		radii = PackedFloat32Array()
		radii.resize(POINTS)
		for i in POINTS: radii[i] = lerpf(from[i], to[i], eased)
		# The steady turn, plus a quarter turn that rides each morph.
		turn = _time * TAU / TURN + (float(step) + eased) * PI * 0.5
	var outline := PackedVector2Array()
	outline.resize(POINTS)
	for i in POINTS:
		outline[i] = center + Vector2.from_angle(TAU * float(i) / POINTS + turn) * radii[i] * radius
	draw_colored_polygon(outline, ink)
	# An antialiased rim smooths the polygon's edge.
	outline.append(outline[0])
	draw_polyline(outline, ink, 1.0, true)


## A spring-like ease: it overshoots a touch and settles (Expressive's fast spatial spring, approximated).
static func _spring(x: float) -> float:
	var c1 := 1.0
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## The seven shapes as radii around the centre, the largest radius 1.
static func _build_shapes() -> Array[PackedFloat32Array]:
	var shapes: Array[PackedFloat32Array] = []
	for kind in ["soft_burst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval"]:
		var radii := PackedFloat32Array()
		radii.resize(POINTS)
		var top := 0.0
		for i in POINTS:
			var angle := TAU * float(i) / POINTS
			var r := 1.0
			match kind:
				"soft_burst": r = 1.0 - 0.14 * (1.0 - cos(10.0 * angle)) * 0.5
				"cookie9": r = 1.0 - 0.09 * (1.0 - cos(9.0 * angle)) * 0.5
				"pentagon":
					var side := TAU / 5.0
					var local := fposmod(angle + PI * 0.5, side) - side * 0.5
					r = lerpf(cos(side * 0.5) / cos(local), 0.9, 0.35)
				"pill": r = 1.0 / pow(pow(absf(cos(angle)), 2.6) + pow(absf(sin(angle)) / 0.58, 2.6), 1.0 / 2.6)
				"sunny": r = 0.84 + 0.16 * pow(0.5 + 0.5 * cos(8.0 * angle), 2.0)
				"cookie4": r = 1.0 - 0.16 * (1.0 - cos(4.0 * angle)) * 0.5
				"oval": r = 1.0 / sqrt(pow(cos(angle), 2.0) + pow(sin(angle) / 0.72, 2.0))
			radii[i] = r
			top = maxf(top, r)
		for i in POINTS: radii[i] /= top
		shapes.append(radii)
	return shapes
