## A nine-stop world-tour map. A winding route sits behind accessible stage buttons; the caller supplies each
## stage's localized name, unlocked state, and picture (or live scene) in `nodes[n - 1].thumbnail_slot`.
@tool
class_name GoWorldTour
extends Control

signal stage_selected(n: int)

## Normalized centres in the map, ordered along the route.
const POSITIONS := [Vector2(0.13, 0.17), Vector2(0.37, 0.14), Vector2(0.65, 0.20),
		Vector2(0.87, 0.37), Vector2(0.68, 0.55), Vector2(0.27, 0.52),
		Vector2(0.13, 0.76), Vector2(0.42, 0.84), Vector2(0.76, 0.84)]

var nodes: Array[GoWorldTourNode] = []


func _init() -> void:
	name = "WorldTour"
	mouse_filter = Control.MOUSE_FILTER_PASS
	for i in POSITIONS.size():
		var node := GoWorldTourNode.new()
		node.name = "Stage%d" % (i + 1)
		add_child(node)
		nodes.append(node)
		node.configure(i + 1, "", true, false)
		node.pressed.connect(_on_pressed.bind(i + 1))
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## Updates one stage (1-based). A locked stage cannot be selected.
func configure_stage(n: int, title: String, locked: bool, selected: bool) -> void:
	if n < 1 or n > nodes.size(): return
	nodes[n - 1].configure(n, title, locked, selected)


func _on_pressed(n: int) -> void:
	if not nodes[n - 1].disabled: stage_selected.emit(n)


func _layout() -> void:
	var extent := Vector2(size.x * 0.25, size.y * 0.26)
	for i in nodes.size():
		nodes[i].size = extent
		nodes[i].position = POSITIONS[i] * size - extent * 0.5
	queue_redraw()


## Each segment is a quadratic curve. Short rounded white dashes outlined in blue remain legible over the sky.
func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	var width := maxf(2.0, size.y * 0.0095)
	var dash := width * 2.3
	var gap := width * 1.6
	var travelled := 0.0
	var visible_dash := true
	var chunk := PackedVector2Array()
	for i in POSITIONS.size() - 1:
		var a: Vector2 = POSITIONS[i] * size
		var b: Vector2 = POSITIONS[i + 1] * size
		var delta := b - a
		var bend := delta.orthogonal().normalized() * delta.length() * (0.14 if i % 2 == 0 else -0.14)
		var control := (a + b) * 0.5 + bend
		var last := a
		for j in range(1, 65):
			var t := float(j) / 64.0
			var p := (1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * control + t * t * b
			var from := last
			var remaining := from.distance_to(p)
			while remaining > 0.001:
				var limit := dash if visible_dash else gap
				var step := minf(remaining, limit - travelled)
				var end := from.lerp(p, step / remaining)
				if visible_dash:
					if chunk.is_empty(): chunk.append(from)
					chunk.append(end)
				travelled += step
				if travelled >= limit - 0.001:
					if visible_dash: _draw_dash(chunk, width)
					chunk = PackedVector2Array()
					travelled = 0.0
					visible_dash = not visible_dash
				from = end
				remaining = from.distance_to(p)
			last = p
	if visible_dash: _draw_dash(chunk, width)


func _draw_dash(points: PackedVector2Array, width: float) -> void:
	if points.size() < 2: return
	var outline := GoUi.color(GoTheme.ACCENT)
	var fill := GoUi.color(GoTheme.ON_ACCENT)
	draw_polyline(points, outline, width + 3.0, true)
	draw_circle(points[0], (width + 3.0) * 0.5, outline, true, -1.0, true)
	draw_circle(points[-1], (width + 3.0) * 0.5, outline, true, -1.0, true)
	draw_polyline(points, fill, width, true)
	draw_circle(points[0], width * 0.5, fill, true, -1.0, true)
	draw_circle(points[-1], width * 0.5, fill, true, -1.0, true)
