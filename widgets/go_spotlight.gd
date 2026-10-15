## 🎯 **A spotlight** — dims the screen round one thing (a button, a gauge, a stick) and rings it, to say "this one".
## The dim fades after a moment so the game stays fully visible while the player acts; the ring stays.
##
## ```gdscript
## var spot := GoSpotlight.new()
## hud.add_child(spot)                   # covers its parent
## spot.follow(jump_button, true)        # a new lesson: dim again round the jump button
## spot.light(Rect2(40, 300, 120, 120))  # or a fixed rect, in the spotlight's own coordinates
## spot.clear()
## ```
##
## Four dims round the hole in `GoSkin.spotlight_dim()` and the edge `GoSkin.spotlight_ring_box()`. It never takes
## input: the game is played through it. Unlike `GoCoachMark` it has no card and no buttons — pair it with a
## `GoTaskCard` for the words. 🛑 Display only: it lights what it is told to.
@tool
class_name GoSpotlight
extends Control

## How much bigger than its target the hole is, on each side (dp).
@export_range(0.0, 64.0) var pad := 8.0

## How long the dim stays at full after a fresh light (s).
@export_range(0.0, 30.0) var dim_seconds := 2.0

## How long the dim then takes to fade out (s). The ring stays.
@export_range(0.0, 10.0) var fade_seconds := 0.4

## Runs the clock in `_process`. Turn it off to drive it with `advance(delta)`.
@export var auto_advance := true:
	set(value):
		auto_advance = value
		set_process(value)

## The lit hole, in this control's coordinates (padded). Empty when nothing is lit.
var hole := Rect2()

var _target: Control
var _age := 0.0
var _ring: StyleBox


func _init() -> void:
	name = "Spotlight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	theme = GoUi.theme()
	_restyle()
	set_process(auto_advance)


func _enter_tree() -> void:
	GoUi.watch(_restyle)
	if is_node_ready(): _restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## Lights [param rect] (this control's coordinates, used as given — no pad). [param fresh] dims the screen again.
func light(rect: Rect2, fresh := false) -> void:
	_target = null
	if fresh: _age = 0.0
	_set_hole(rect)


## Lights [param control] (grown by `pad`), following it as it moves; hidden, it lights nothing. [param fresh] dims
## the screen again.
func follow(control: Control, fresh := false) -> void:
	_target = control
	if fresh: _age = 0.0
	_set_hole(_target_hole())


## Lights nothing.
func clear() -> void:
	_target = null
	_set_hole(Rect2())


## How strong the dim is now: 1 for `dim_seconds`, then down to 0 over `fade_seconds`.
func dim_alpha() -> float:
	if fade_seconds <= 0.0: return 1.0 if _age <= dim_seconds else 0.0
	return 1.0 - clampf((_age - dim_seconds) / fade_seconds, 0.0, 1.0)


## The four dims round the hole — top, bottom, left, right. Empty when nothing is lit.
func dim_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if hole.size == Vector2.ZERO: return out
	var w := size.x
	var h := size.y
	out.append(Rect2(0.0, 0.0, w, maxf(0.0, hole.position.y)))
	out.append(Rect2(0.0, hole.end.y, w, maxf(0.0, h - hole.end.y)))
	out.append(Rect2(0.0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y))
	out.append(Rect2(hole.end.x, hole.position.y, maxf(0.0, w - hole.end.x), hole.size.y))
	return out


## Moves the clock on [param delta] seconds and follows the target.
func advance(delta: float) -> void:
	var was := dim_alpha()
	_age += delta
	if _target != null: _set_hole(_target_hole())
	if dim_alpha() != was: queue_redraw()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint(): advance(delta)


func _target_hole() -> Rect2:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree(): return Rect2()
	var rect := _target.get_global_rect().grow(pad)
	rect.position = get_global_transform().affine_inverse() * rect.position
	return rect


func _set_hole(rect: Rect2) -> void:
	if rect == hole: return
	hole = rect
	queue_redraw()


func _restyle() -> void:
	theme = GoUi.theme()
	_ring = GoUi.skin().spotlight_ring_box()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()


func _draw() -> void:
	if hole.size == Vector2.ZERO: return
	var dim := GoUi.skin().spotlight_dim()
	dim.a *= dim_alpha()
	if dim.a > 0.0:
		for rect in dim_rects(): draw_rect(rect, dim)
	if _ring == null: _ring = GoUi.skin().spotlight_ring_box()
	if _ring != null: draw_style_box(_ring, hole)
