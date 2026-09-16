## 🧭 A box that pins a HUD element to one of **nine spots on the screen**. It keeps the safe area
## and the edge margin for you.
##
## ## Why it is needed
## Write `set_anchors_preset` plus offsets by hand for every piece of HUD and the health bar ends up
## under the camera cutout on a notched device and the control buttons sit on the gesture bar in
## landscape. This keeps that arithmetic in one place.
##
## ```gdscript
## var corner := GoHudAnchor.new()
## corner.spot = GoHudAnchor.Spot.TOP_LEFT
## corner.add_child(health_bar)
## hud.add_child(corner)
## ```
##
## ## 🔑 To move the spot with the orientation
## Set `landscape_spot` and the box moves there on a landscape screen. That is how controls that sit
## bottom-centre in portrait go to the bottom right in landscape.
@tool
class_name GoHudAnchor
extends Control

enum Spot {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	CENTER_LEFT, CENTER, CENTER_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT,
}

## The group every floating HUD box joins. `GoForm.avoid_hud` walks it to find the occupied spots.
const GROUP := &"gohud_hud_anchor"

## The spot to pin to.
@export var spot := Spot.TOP_LEFT:
	set(value):
		spot = value
		_relayout()

## The spot to use on a landscape screen. `-1` keeps `spot` as it is.
@export var landscape_spot := -1:
	set(value):
		landscape_spot = value
		_relayout()

## Distance to hold off the screen edge (dp). Negative uses the `screen_margin` token.
@export var edge_margin := -1:
	set(value):
		edge_margin = value
		_relayout()

## 🔑 **Whether to step aside from HUD that is already placed.**
##
## Turn it on for things that **appear briefly and go**, such as a snackbar. A notice at the top centre
## overlaps the top-right health bar in width and lands straight on top of it (measured); with this on
## it drops in below the health bar instead.
##
## 🛑 **It only steps aside vertically.** Push it sideways too and a centred notice shows up somewhere
##    different each time it appears.
## 🛑 It only avoids **fixed boxes that have `reserve_space` on**. Transient things (notices, prompts)
##    do not avoid each other — doing that pushed a notice past the prompt card all the way into the
##    middle of the screen (measured in landscape 2026-09-13). The centre row (`CENTER_*`) has nowhere
##    to step aside to and is left alone.
@export var avoid_peers := false:
	set(value):
		avoid_peers = value
		_relayout()

## 🔑 **Whether the body should keep this spot clear** (only meaningful while `GoForm.avoid_hud` is on).
##
## Turn it off and the form pretends this box is not there. That is right for something that is
## **not on screen most of the time**, like a joystick that only appears under a finger — leave it on
## and a box nobody can see eats a whole line of the body.
##
## This value also decides **who** a box with `avoid_peers` on steps aside from — only fixed ones.
@export var reserve_space := true:
	set(value):
		if reserve_space == value: return
		reserve_space = value
		_wake_dodgers()

## Whether to respect the safe area. Turn it off only for things that must fill the screen, like a backdrop.
@export var use_safe_area := true:
	set(value):
		use_safe_area = value
		_relayout()

var _runtime: Node
## The rect last laid out. It exists so the dodging boxes are woken **only when** a fixed box has moved.
var _last_rect := Rect2()
## 🛑 Re-entry guard — `_relayout` changing `size` fires `resized` again. Without it this loops forever.
var _laying_out := false


func _init() -> void:
	name = "HudAnchor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	# 🛑 **It has to be able to announce what it occupies.** Scrolling body text really did run behind this
	#    box and tangle with its text (2026-09-13) — `GoForm.avoid_hud` walks this group to keep clear.
	add_to_group(GROUP)
	_runtime = GoUi.runtime()
	get_viewport().size_changed.connect(_relayout)
	child_entered_tree.connect(_watch_child)
	for child in get_children(): _watch_child(child)
	_relayout.call_deferred()
	GoUi.watch(_relayout)


func _exit_tree() -> void:
	GoUi.unwatch(_relayout)


## 🎨 The whole look changed — `GoUi.use_preset()` and `GoUi.refresh()` call this.
## 🛑 Without it **only the widgets already on screen stay on the old theme** (measured 2026-09-16).


## 🛑 Listen for a child's **minimum size and visibility changes** — this box has to grow along when a
##    notice takes text and swells, or a hidden card appears. Listen to the viewport size alone and the
##    notice stays trapped invisible in a 0×0 box.
func _watch_child(node: Node) -> void:
	if not (node is Control): return
	var control := node as Control
	var relayout := _relayout.call_deferred
	if not control.minimum_size_changed.is_connected(relayout): control.minimum_size_changed.connect(relayout)
	if not control.visibility_changed.is_connected(relayout): control.visibility_changed.connect(relayout)
	_relayout.call_deferred()


## The spot in force right now (with the orientation applied).
func active_spot() -> Spot:
	var view := get_viewport_rect().size
	if landscape_spot >= 0 and view.x > view.y: return landscape_spot as Spot
	return spot


func _relayout() -> void:
	if _laying_out or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	_laying_out = true
	var area := GoSafeArea.usable_rect(window) if use_safe_area else window.get_visible_rect()
	var margin := float(GoUi.metric(GoTheme.SCREEN_MARGIN) if edge_margin < 0 else edge_margin)
	area = area.grow(-margin)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		_laying_out = false
		return

	# The size the children ask for. This is not a container, so measure it ourselves and take it as our size.
	var wanted := Vector2.ZERO
	for child in get_children():
		if child is Control and child.visible:
			wanted = wanted.max(child.get_combined_minimum_size())
	if custom_minimum_size.x > 0.0: wanted.x = maxf(wanted.x, custom_minimum_size.x)
	if custom_minimum_size.y > 0.0: wanted.y = maxf(wanted.y, custom_minimum_size.y)
	wanted = wanted.min(area.size)
	size = wanted

	var here := active_spot()
	var column := int(here) % 3       # 0 left · 1 centre · 2 right
	var line := int(here) / 3         # 0 top · 1 middle · 2 bottom
	position = Vector2(
		area.position.x + (area.size.x - size.x) * (column * 0.5),
		area.position.y + (area.size.y - size.y) * (line * 0.5))
	if avoid_peers: _dodge_peers(area, line)

	for child in get_children():
		if child is Control: child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 🛑 **If a fixed box moved, tell the boxes that dodge it.** A notice has no way of noticing the health
	#    bar resizing, so it stayed in its dodged spot even after the bar hid or shrank (measured 2026-09-13).
	var now := Rect2(position, size)
	if not avoid_peers and now != _last_rect:
		_last_rect = now
		_wake_dodgers()
	_laying_out = false


## Tell the boxes that are dodging me to lay themselves out again.
## 🛑 A dodging box never calls this — wake each other and the two trade relayouts forever.
func _wake_dodgers() -> void:
	if not is_inside_tree(): return
	for node in get_tree().get_nodes_in_group(GROUP):
		var peer := node as GoHudAnchor
		if peer != null and peer != self and peer.avoid_peers: peer._relayout.call_deferred()


## Step aside vertically from the other fixed boxes. A top box moves down, a bottom box moves up.
func _dodge_peers(area: Rect2, line: int) -> void:
	if line == 1: return                      # The centre row — nowhere to step aside to
	var down := line == 0
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL))
	var here := get_viewport()
	var shift := 0.0
	var mine := Rect2(global_position, size)
	for node in get_tree().get_nodes_in_group(GROUP):
		var peer := node as GoHudAnchor
		# Only fixed boxes are avoided — let transient ones dodge each other and both run off somewhere odd.
		if peer == null or peer == self: continue
		if not peer.reserve_space or peer.avoid_peers: continue
		if not peer.is_visible_in_tree() or peer.get_viewport() != here: continue
		var rect := Rect2(peer.global_position, peer.size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
		if not Rect2(mine.position + Vector2(0.0, shift), mine.size).intersects(rect): continue
		shift = (rect.end.y + gap - mine.position.y) if down else (rect.position.y - gap - mine.end.y)
	if is_zero_approx(shift): return
	# 🛑 Step aside off the screen and it is not seen at all — clamp it inside the usable area.
	position.y = clampf(position.y + shift, area.position.y,
		maxf(area.position.y, area.end.y - size.y))
