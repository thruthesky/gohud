## A nine-stop world-tour map. A winding route sits behind accessible stage buttons; the caller supplies each
## stage's localized name, unlocked state, and picture (or live scene) in `nodes[n - 1].thumbnail_slot`.
@tool
class_name GoWorldTour
extends Control

signal stage_selected(n: int)

## Each island's painted rectangle, normalized to the map and ordered along the route. Together they fill the map
## from its top edge to its bottom, as in the arcade reference.
const ISLANDS := [Rect2(0.011, 0.030, 0.219, 0.230), Rect2(0.270, 0.002, 0.237, 0.227),
		Rect2(0.538, 0.055, 0.224, 0.218), Rect2(0.770, 0.173, 0.232, 0.237), Rect2(0.526, 0.360, 0.301, 0.255),
		Rect2(0.174, 0.276, 0.314, 0.270), Rect2(0.005, 0.565, 0.239, 0.264), Rect2(0.288, 0.640, 0.307, 0.289),
		Rect2(0.640, 0.640, 0.360, 0.318)]
## Normalized badge centres: low on each island, the country pill just under it.
const BADGES := [Vector2(0.079, 0.223), Vector2(0.312, 0.077), Vector2(0.626, 0.235), Vector2(0.911, 0.366),
		Vector2(0.763, 0.534), Vector2(0.239, 0.488), Vector2(0.110, 0.752), Vector2(0.383, 0.854),
		Vector2(0.803, 0.862)]
## Normalized island centres, the route's stops.
static var POSITIONS: Array[Vector2] = _centres()

var nodes: Array[GoWorldTourNode] = []
## Off: the stops show their names only, without numbered badges.
var show_numbers := true:
	set(value):
		show_numbers = value
		for node in nodes: node.show_number = value
var _labels: Control # every stop's badge and caption, drawn after all islands; a sibling, never a z_index


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
	_labels = Control.new()
	_labels.name = "Labels"
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	for node in nodes:
		node.remove_child(node.labels)
		_labels.add_child(node.labels)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## Updates one stage (1-based). A locked stage cannot be selected.
func configure_stage(n: int, title: String, locked: bool, selected: bool) -> void:
	if n < 1 or n > nodes.size(): return
	nodes[n - 1].configure(n, title, locked, selected)


func _on_pressed(n: int) -> void:
	if not nodes[n - 1].disabled: stage_selected.emit(n)


static func _centres() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r: Rect2 in ISLANDS: out.append(r.get_center())
	return out


func _layout() -> void:
	var badge := minf(size.y * 0.10, size.x * 0.072)
	for i in nodes.size():
		var r: Rect2 = ISLANDS[i]
		var rect := Rect2(r.position * size, r.size * size)
		nodes[i].badge_center = BADGES[i] * size - rect.position
		nodes[i].badge_side = badge
		nodes[i].position = rect.position
		nodes[i].size = rect.size
		nodes[i].labels.position = rect.position
		nodes[i].call(&"_layout")
	queue_redraw()


## Each segment is a quadratic curve. Short rounded white dashes outlined in blue remain legible over the sky.
func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	var width := maxf(2.0, size.y * 0.0085)
	var dash := width * 2.0
	var gap := width * 1.25
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
	var edge := width + maxf(2.0, width * 0.35)
	draw_polyline(points, outline, edge, true)
	draw_circle(points[0], edge * 0.5, outline, true, -1.0, true)
	draw_circle(points[-1], edge * 0.5, outline, true, -1.0, true)
	draw_polyline(points, fill, width, true)
	draw_circle(points[0], width * 0.5, fill, true, -1.0, true)
	draw_circle(points[-1], width * 0.5, fill, true, -1.0, true)
