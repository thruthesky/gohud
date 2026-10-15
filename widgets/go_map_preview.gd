## 🗺️ **A small map of a level** — areas (rectangles, circles, free polygons) with an outline, the links between them,
## the start dots, fitted and centred in a dark box or the theme's well. A locked level shows a grey silhouette with
## no starts. This is how Magnet Mayhem's MapPreview draws a stage on its card and in the lobby.
##
## The game hands in only data. Coordinates are its own world units, +X right and +Y down; the map is scaled to fit
## the box less [member padding] and centred on the areas' bounds. Links do not count in the bounds.
##
## ```gdscript
## var map := GoMapPreview.new()
## map.add_rect(Vector2(0, 0), Vector2(6, 4), Color("#f2b84b"))      # centre, half size, fill
## map.add_circle(Vector2(18, 0), 5.0, Color("#6fc3ff"))
## map.add_link(Vector2(0, 0), Vector2(18, 0), 2.0, Color("#c9a26b"))  # from centre to centre, drawn under the areas
## map.set_starts(PackedVector2Array([Vector2(-3, 0), Vector2(20, 0)]))
## map.set_well()                                                      # the painted well instead of the flat box
## level_card.set_thumbnail(map)
## ```
##
## 🛑 It clips to its box, as the game's MapPreview does: on a scaled canvas the background's last fractional row
##    would otherwise show. It ignores the mouse, so a card under it still takes the press.
@tool
class_name GoMapPreview
extends Control

## The room kept round the map in the flat box.
const PADDING := 4.0
## The room kept round the map in the well, whose painted rim is wider.
const WELL_PADDING := 12.0
## The flat box: fill, rim, rim width and corner radius.
const BACKGROUND := Color("#18213a")
const BORDER := Color("#58627b")
const BORDER_WIDTH := 1
const CORNER_RADIUS := 6
## The outline round every area, and its width.
const EDGE := Color("#0d1324")
const EDGE_WIDTH := 0.6
## A start dot: its fill and radius (the outline adds EDGE_WIDTH round it).
const DOT := Color("#ffffff")
const DOT_RADIUS := 0.8
## The silhouette of a locked level.
const LOCKED_AREA := Color("#8d95a6")
const LOCKED_LINK := Color("#667083")
## The segments of a circle's outline.
const CIRCLE_SEGMENTS := 32
## The theme type whose `panel` box replaces the flat box, when the theme has it.
const VAR_BACKGROUND := &"GoMapPreview"
## The theme type of the well.
const VAR_WELL := &"GoWell"

enum Shape { RECT, CIRCLE, POLYGON }

## A locked level: the grey silhouette, no starts.
@export var locked := false:
	set(value):
		locked = value
		queue_redraw()
## The room kept round the map.
@export var padding := PADDING:
	set(value):
		padding = value
		_rebuild()
## Draw the box behind the map. Off inside a card that draws its own well round the thumbnail.
@export var show_background := true:
	set(value):
		show_background = value
		queue_redraw()
## A box of your own behind the map; empty, the theme's (see [method background_box]).
@export var background: StyleBox:
	set(value):
		background = value
		queue_redraw()

var _well := false
## Each area: {shape, points (world), center, half, radius, color}.
var _areas: Array[Dictionary] = []
## Each link: {from, to, width, color}.
var _links: Array[Dictionary] = []
var _starts := PackedVector2Array()
var _scale := 0.0
var _origin := Vector2.ZERO
var _area_canvas: Array = []
var _link_canvas: Array[PackedVector2Array] = []
var _start_canvas := PackedVector2Array()


func _init() -> void:
	name = "MapPreview"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_rebuild)


func _ready() -> void:
	# Offsets may have set the size before it entered the tree, without a resized signal.
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED: queue_redraw()


# ── Data ───────────────────────────────────────────────────────────────

## Empties the map.
func clear() -> void:
	_areas.clear()
	_links.clear()
	_starts.clear()
	_rebuild()


## A rectangle centred on [param center], [param half] its half width and half height.
func add_rect(center: Vector2, half: Vector2, color: Color) -> void:
	_areas.append({shape = Shape.RECT, center = center, half = half.abs(), color = color})
	_rebuild()


## A circle.
func add_circle(center: Vector2, radius: float, color: Color) -> void:
	_areas.append({shape = Shape.CIRCLE, center = center, half = Vector2.ONE * absf(radius), color = color})
	_rebuild()


## A free polygon, its points in order.
func add_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3: return
	var box := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points: box = box.expand(p)
	_areas.append({shape = Shape.POLYGON, points = points, center = box.get_center(), half = box.size * 0.5, color = color})
	_rebuild()


## A bar [param width] wide from [param from] to [param to], drawn under the areas (a bridge from centre to centre
## is covered by the areas at its ends).
func add_link(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	if from.is_equal_approx(to): return
	_links.append({from = from, to = to, width = width, color = color})
	_rebuild()


## The start dots.
func set_starts(points: PackedVector2Array) -> void:
	_starts = points.duplicate()
	_rebuild()


## The theme's painted well behind the map, with its wider padding.
func set_well() -> void:
	_well = true
	padding = WELL_PADDING


# ── Reading ────────────────────────────────────────────────────────────

func area_count() -> int: return _areas.size()
func link_count() -> int: return _links.size()
func start_count() -> int: return _starts.size()
## Canvas units per world unit; 0 when there is nothing to fit.
func map_scale() -> float: return _scale
func starts_shown() -> bool: return not locked
func area_color(i: int) -> Color: return LOCKED_AREA if locked else _areas[i].color
func link_color(i: int) -> Color: return LOCKED_LINK if locked else _links[i].color


## A world point on the canvas.
func to_canvas(point: Vector2) -> Vector2:
	return _origin + point * _scale


## The box drawn behind the map: [member background]; else the theme's well after [method set_well]; else the theme's
## `GoMapPreview` panel; else the flat dark box. Null with [member show_background] off.
func background_box() -> StyleBox:
	if not show_background: return null
	if background != null: return background
	if _well and has_theme_stylebox(&"panel", VAR_WELL): return get_theme_stylebox(&"panel", VAR_WELL)
	if has_theme_stylebox(&"panel", VAR_BACKGROUND): return get_theme_stylebox(&"panel", VAR_BACKGROUND)
	return _flat_box()


static func _flat_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BACKGROUND
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.set_border_width_all(BORDER_WIDTH)
	sb.border_color = BORDER
	sb.anti_aliasing = true
	return sb


# ── Fit and draw ───────────────────────────────────────────────────────

func _rebuild() -> void:
	_scale = 0.0
	_area_canvas.clear()
	_link_canvas.clear()
	_start_canvas.clear()
	queue_redraw()
	if _areas.is_empty(): return
	var bounds := Rect2()
	for i: int in _areas.size():
		var a: Dictionary = _areas[i]
		var box := Rect2(a.center - a.half, a.half * 2.0)
		bounds = box if i == 0 else bounds.merge(box)
	var room := size - Vector2.ONE * padding * 2.0
	if room.x <= 0.0 or room.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0: return
	_scale = minf(room.x / bounds.size.x, room.y / bounds.size.y)
	_origin = size / 2.0 - bounds.get_center() * _scale
	for a: Dictionary in _areas:
		if a.shape == Shape.POLYGON:
			var pts := PackedVector2Array()
			for p: Vector2 in a.points: pts.append(to_canvas(p))
			_area_canvas.append(pts)
		else:
			_area_canvas.append(Rect2(to_canvas(a.center - a.half), a.half * 2.0 * _scale))
	for l: Dictionary in _links:
		var axis: Vector2 = (l.to - l.from).normalized()
		var side: Vector2 = Vector2(-axis.y, axis.x) * l.width / 2.0
		_link_canvas.append(PackedVector2Array([to_canvas(l.from - side), to_canvas(l.to - side),
			to_canvas(l.to + side), to_canvas(l.from + side)]))
	for p: Vector2 in _starts: _start_canvas.append(to_canvas(p))


func _draw() -> void:
	var box := background_box()
	if box != null: draw_style_box(box, Rect2(Vector2.ZERO, size))
	for i: int in _link_canvas.size():
		draw_colored_polygon(_link_canvas[i], link_color(i))
	for i: int in _area_canvas.size():
		var color := area_color(i)
		match _areas[i].shape:
			Shape.CIRCLE:
				var r: Rect2 = _area_canvas[i]
				var radius := r.size.x / 2.0
				draw_circle(r.get_center(), radius, color)
				draw_arc(r.get_center(), radius, 0.0, TAU, CIRCLE_SEGMENTS, EDGE, EDGE_WIDTH, true)
			Shape.RECT:
				var r: Rect2 = _area_canvas[i]
				draw_rect(r, color)
				draw_rect(r, EDGE, false, EDGE_WIDTH)
			_:
				var pts: PackedVector2Array = _area_canvas[i]
				draw_colored_polygon(pts, color)
				var ring := pts.duplicate()
				ring.append(pts[0])
				draw_polyline(ring, EDGE, EDGE_WIDTH, true)
	if starts_shown():
		for p: Vector2 in _start_canvas:
			draw_circle(p, DOT_RADIUS + EDGE_WIDTH, EDGE)
			draw_circle(p, DOT_RADIUS, DOT)
