## 🕸 **The stat hexagon** — a character's strength, agility, intelligence, vitality and luck in one picture.
##
## ```gdscript
## var stats := GoRadar.make({"STR": 0.8, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.4})
## card.add_child(stats)
##
## # Overlay what it would look like with different gear
## stats.set_compare({"STR": 0.9, "AGI": 0.4, "INT": 0.3, "VIT": 0.7, "LUK": 0.4})
## ```
##
## ## 🔑 It is not a general-purpose chart
## A radar shape in a game is used for exactly one thing: **comparing characters and gear**. Pull in a charting
## library with axis ticks, legends and tooltips and most of it goes unused. What is here is axis names, 0~1 values,
## and **overlaying one on another** — nothing more.
##
## ## 🛑 Normalize the values to 0~1 before passing them in
## Draw strength 120 and intelligence 45 as they are and every axis has its own scale, so the shape lies. What counts
## as 1 is for the game to decide (the cap for that class? the server's number one?) — a widget cannot make that call for you.
##
## ## ♿ A picture on its own reads as nothing
## The values go into the screen-reader name along with the axis names. For people with a color vision deficiency the
## comparison outline is told apart by **more than color — it is dashed** as well.
@tool
class_name GoRadar
extends Control

## Axis name → value (0~1).
var values: Dictionary = {}
## The values to overlay (a gear comparison). Nothing is drawn while it is empty.
var compare: Dictionary = {}

## The fill color of the area. Empty means the theme's accent color.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## The color of the comparison outline. Empty means the theme's warning color.
@export var compare_ink := Color.TRANSPARENT:
	set(value):
		compare_ink = value
		queue_redraw()

## Whether to draw the axis names. 🛑 In a small cell (under 60dp) the text overlaps, so turn it off.
@export var show_labels := true:
	set(value):
		show_labels = value
		queue_redraw()

## How many rings of web to draw inside.
@export var rings := 3:
	set(value):
		rings = maxi(1, value)
		queue_redraw()


func _init() -> void:
	name = "Radar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 160)


func _ready() -> void:
	GoUi.watch(_on_ui_changed)
	_sync_accessibility()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


static func make(stats: Dictionary, compare_with := {}) -> GoRadar:
	var node := GoRadar.new()
	node.values = stats.duplicate()
	node.compare = compare_with.duplicate()
	return node


func set_values(stats: Dictionary) -> void:
	values = stats.duplicate()
	_sync_accessibility()
	queue_redraw()


func set_compare(stats: Dictionary) -> void:
	compare = stats.duplicate()
	_sync_accessibility()
	queue_redraw()


func _draw() -> void:
	var axes := values.keys()
	# 🛑 With fewer than three axes there is no area — we don't draw a single line or dot and call it a "graph".
	if axes.size() < 3: return
	var box := minf(size.x, size.y)
	var pad := float(GoUi.font_size(GoTheme.ROLE_MICRO)) * 2.2 if show_labels else 4.0
	var radius := box * 0.5 - pad
	if radius <= 4.0: return
	var center := size * 0.5
	var web := Color(GoUi.color(GoTheme.BORDER), 0.55)

	# The web — the grid that lets you eyeball the values.
	for ring in range(1, rings + 1):
		var r := radius * float(ring) / float(rings)
		var points := PackedVector2Array()
		for i in axes.size(): points.append(center + _spoke(i, axes.size()) * r)
		points.append(points[0])
		draw_polyline(points, web, 1.0, true)
	for i in axes.size():
		draw_line(center, center + _spoke(i, axes.size()) * radius, web, 1.0, true)

	# The value area
	var fill := ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)
	_draw_shape(center, radius, axes, values, fill, true, false)

	# The comparison outline — 🔑 drawn **dashed**. Differ only in color and the two outlines look like one to someone with a color vision deficiency.
	if not compare.is_empty():
		var other := compare_ink if compare_ink.a > 0 else GoUi.color(GoTheme.WARNING)
		_draw_shape(center, radius, axes, compare, other, false, true)

	if not show_labels: return
	var font := get_theme_font(&"font")
	if font == null: return
	var font_size := GoUi.font_size(GoTheme.ROLE_MICRO)
	var text_ink := GoUi.color(GoTheme.SECONDARY)
	for i in axes.size():
		var name := str(axes[i])
		var dir := _spoke(i, axes.size())
		var at := center + dir * (radius + font_size * 0.9)
		var measured := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		# Pull the text in depending on which way the axis points — without this the left-hand axis names overlap the drawing.
		at.x -= measured.x * (0.5 + dir.x * 0.5)
		at.y += measured.y * 0.35
		draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_ink)


## Draws one set of values as an area (or an outline).
func _draw_shape(center: Vector2, radius: float, axes: Array, source: Dictionary,
		color: Color, filled: bool, dashed: bool) -> void:
	var points := PackedVector2Array()
	for i in axes.size():
		var value := clampf(float(source.get(axes[i], 0.0)), 0.0, 1.0)
		points.append(center + _spoke(i, axes.size()) * radius * value)
	if points.size() < 3: return
	if filled:
		var face := PackedColorArray()
		for _i in points.size(): face.append(Color(color, 0.22))
		draw_polygon(points, face)
	var outline := points.duplicate()
	outline.append(points[0])
	if not dashed:
		draw_polyline(outline, color, 2.0, true)
		return
	# Dashes — each edge is cut into pieces and drawn with a gap between them.
	for i in outline.size() - 1:
		var from := outline[i]
		var to := outline[i + 1]
		var length := from.distance_to(to)
		var step := maxf(4.0, length / 8.0)
		var walked := 0.0
		while walked < length:
			var a := from.lerp(to, walked / length)
			var b := from.lerp(to, minf(1.0, (walked + step * 0.55) / length))
			draw_line(a, b, color, 2.0, true)
			walked += step


## The direction axis `index` points in. 🔑 The first axis points **up** — otherwise the whole shape looks tilted.
func _spoke(index: int, total: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / float(total)
	return Vector2(cos(angle), sin(angle))


## ♿ Gives the values in words to someone who cannot see the picture.
func _sync_accessibility() -> void:
	# 🛑 **A percent format is text too** — Turkish puts the sign in front (%50) and French puts a space before it.
	#    That is why `GoConfig.text_keys` has `bar_percent`, and it is used here as well.
	var parts: Array[String] = []
	for key in values:
		var share := GoUi.text(&"bar_percent").format({"percent": roundi(float(values[key]) * 100.0)})
		parts.append(GoUi.spoken([str(key), share]))
	accessibility_name = GoUi.spoken(parts)


func _on_ui_changed() -> void:
	queue_redraw()
