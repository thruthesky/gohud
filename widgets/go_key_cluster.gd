## ⌨️ **Four movement keys in an inverted T** — W above A S D, or the arrow keys — as the controls page of a game
## shows them. Each key is the look's keycap (`GoSkin.key_cluster_box`, the painted keycap in arcade_light); an arrow
## label is drawn as a triangle, any other word is engraved and shrunk to fit the cap.
##
## ```gdscript
## var wasd := GoKeyCluster.make(["W", "A", "S", "D"])
## var arrows := GoKeyCluster.make(GoKeyCluster.ARROWS)
## arrows.picked.connect(func(): settings.hand = RIGHT)      # a click picks this layout
## ```
##
## 🛑 The labels go up, left, down, right — the order of the T, not the keyboard row.
## 🛑 Key names are never translated: they must read as engraved on the keyboard.
@tool
class_name GoKeyCluster
extends Control

## Clicked — the player picks this layout.
signal picked

## The arrow keys. A label that is one of these (or `Up` / `Left` / `Down` / `Right`) is drawn as a triangle.
const ARROWS: PackedStringArray = ["↑", "←", "↓", "→"]
const WASD: PackedStringArray = ["W", "A", "S", "D"]

## The four labels: up, left, down, right.
@export var labels: PackedStringArray = WASD:
	set(value):
		labels = value
		_sync_name()
		queue_redraw()

## The side of one key (dp).
@export var key_size := 34.0:
	set(value):
		key_size = maxf(1.0, value)
		_resize()

## The space between keys (dp).
@export var gap := 4.0:
	set(value):
		gap = maxf(0.0, value)
		_resize()

## The word's size before it shrinks to fit the cap.
@export var label_size := 18:
	set(value):
		label_size = maxi(1, value)
		queue_redraw()

## How far the word sits above the key's centre — the cap's top face stands over its thick bottom edge.
@export var face_lift := 2.0:
	set(value):
		face_lift = value
		queue_redraw()

## Half the length of an arrow triangle (dp).
@export var arrow_half := 7.0:
	set(value):
		arrow_half = maxf(1.0, value)
		queue_redraw()

var _cap: StyleBox = null
var _ink := Color.BLACK


func _init() -> void:
	name = "KeyCluster"
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_resize()
	_sync_name()


## 🔑 Watched on every entry, not once in `_ready` — `reparent()` takes the node out and back, and a watch set only in
##    `_ready` was dropped by the first `_exit_tree` for good. Back in the tree, it catches up with the look.
func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _ready() -> void:
	_dress()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


static func make(words: PackedStringArray = WASD) -> GoKeyCluster:
	var node := GoKeyCluster.new()
	node.labels = words
	return node


## Each key's rect inside the cluster, in label order: up, left, down, right.
func key_rects() -> Array[Rect2]:
	var step := key_size + gap
	var side := Vector2(key_size, key_size)
	return [Rect2(Vector2(step, 0.0), side), Rect2(Vector2(0.0, step), side),
		Rect2(Vector2(step, step), side), Rect2(Vector2(2.0 * step, step), side)]


## The label at [param index], or "" past the end.
func label_at(index: int) -> String:
	return labels[index] if index >= 0 and index < labels.size() else ""


## The way an arrow label points, or `Vector2.ZERO` for any other word.
static func arrow_direction(word: String) -> Vector2:
	match word.strip_edges().to_lower():
		"↑", "up": return Vector2.UP
		"↓", "down": return Vector2.DOWN
		"←", "left": return Vector2.LEFT
		"→", "right": return Vector2.RIGHT
	return Vector2.ZERO


## The size a word is engraved at: [member label_size], shrunk until it fits the cap.
func word_size(word: String) -> int:
	return GoStyle.fit_font_size(PackedStringArray([word]), label_size, key_size - 10.0, _font())


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		picked.emit()
		accept_event()


## 🛑 Never dresses here: `_dress` queues a redraw, so a look with no cap would redraw every frame. The caps are
##    dressed on entering the tree and whenever the look changes.
func _draw() -> void:
	var font := _font()
	var rects := key_rects()
	for index in rects.size():
		var rect: Rect2 = rects[index]
		if _cap != null: _cap.draw(get_canvas_item(), rect)
		var word := label_at(index)
		var face := rect.get_center() + Vector2(0.0, -face_lift)
		var way := arrow_direction(word)
		if way != Vector2.ZERO:
			_draw_arrow(face, way)
		elif not word.is_empty() and font != null:
			var px := word_size(word)
			var wide := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			draw_string(font, face + Vector2(-wide * 0.5, float(px) * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
					_ink)


func _draw_arrow(center: Vector2, way: Vector2) -> void:
	var side := Vector2(-way.y, way.x)
	var tip := center + way * arrow_half
	var base := center - way * arrow_half * 0.7
	draw_colored_polygon(PackedVector2Array([tip, base + side * arrow_half, base - side * arrow_half]), _ink)


func _font() -> Font:
	var look := GoUi.theme()
	if look != null and look.default_font != null: return look.default_font
	return get_theme_default_font() if is_inside_tree() else ThemeDB.fallback_font


func _resize() -> void:
	custom_minimum_size = Vector2(3.0 * key_size + 2.0 * gap, 2.0 * key_size + gap)
	queue_redraw()


func _sync_name() -> void:
	accessibility_name = " ".join(labels)


func _dress() -> void:
	_cap = GoUi.skin().key_cluster_box()
	_ink = GoUi.skin().kbd_ink()
	queue_redraw()


func _on_ui_changed() -> void:
	_dress()
