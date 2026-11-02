## ✏️ **An edit frame** — the outline a layout editor draws round each thing the player can move: the "customize
## controls" screen of a mobile shooter, where every thumb button and HUD box wears a frame, a tap selects one (a solid
## frame with corner handles), one that overlaps another turns to warning ink, and one the player hid stays as a ghost
## so it can be found and shown again.
##
## ```gdscript
## var frame := GoEditFrame.new()
## editor.add_child(frame)
## frame.circle = true                             # a round thumb button: a ring, not a box
## frame.position = jump.position                  # the caller sizes it to the thing it frames
## frame.size = jump.size
## frame.state = GoEditFrame.State.SELECTED        # tapped: solid, with handles
## frame.state = GoEditFrame.State.WARNING         # overlaps another control
## frame.state = GoEditFrame.State.GHOST           # hidden by the player: veiled, crossed-out eye
## ```
##
## The frame stands `pad` outside its rect. `IDLE` is a dashed `accent` outline (it says "this can move"), `SELECTED` a
## solid one with a light wash and four handles, `WARNING` the same in `warning` ink, `GHOST` a dashed `muted` outline
## over a `scrim` veil with the icon set's `EYE_OFF` in the middle. Every line rides on a thin `shadow` edge so it reads
## on any scene. The look draws it (`GoSkin.draw_edit_frame()`, its ink `GoSkin.edit_frame_ink()`). 🛑 Display only: it
## never takes input (`MOUSE_FILTER_IGNORE`) — the editor routes the drag and the tap.
@tool
class_name GoEditFrame
extends Control

enum State { IDLE, SELECTED, WARNING, GHOST }

@export var state := State.IDLE:
	set(value):
		if value == state: return
		state = value
		queue_redraw()

## How far the outline stands off the rect (dp).
@export_range(0.0, 64.0) var pad := 6.0:
	set(value):
		pad = value
		queue_redraw()

## A ring round a round thing (a thumb button, a stick) instead of a rounded box.
@export var circle := false:
	set(value):
		circle = value
		queue_redraw()

## The handles of a SELECTED or WARNING frame (off: the outline alone).
@export var handles := true:
	set(value):
		handles = value
		queue_redraw()

## Times the frame was painted (tests).
var paint_count := 0


func _init() -> void:
	name = "EditFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# 🛑 A frame round a physical place does not mirror for right-to-left languages.
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _enter_tree() -> void:
	# On every entry, so a frame that was out of the tree during a look switch comes back on the current look.
	GoUi.watch(_restyle)
	_restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


func _restyle() -> void:
	theme = GoUi.theme()
	queue_redraw()


## The outline's rect (local): the node's rect grown by `pad`.
func frame_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(pad)


## Where the handles are drawn (local): the four corners of `frame_rect()`, or for a `circle` frame the four points of
## the compass on its ring. Empty when the state shows none.
func handle_points() -> PackedVector2Array:
	if not handles or (state != State.SELECTED and state != State.WARNING): return PackedVector2Array()
	var r := frame_rect()
	if circle:
		var c := r.get_center()
		var radius := minf(r.size.x, r.size.y) / 2.0
		return PackedVector2Array([c + Vector2(0, -radius), c + Vector2(radius, 0), c + Vector2(0, radius),
			c + Vector2(-radius, 0)])
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## The ink of the current state (`GoSkin.edit_frame_ink()`).
func ink() -> Color:
	return GoUi.skin().edit_frame_ink(state)


func _draw() -> void:
	paint_count += 1
	GoUi.skin().draw_edit_frame(self, frame_rect(), state, circle, handle_points())
