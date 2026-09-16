## 📝 **The container that fits a form's width to the screen.** For tall screens: login, settings, character creation.
##
## ## Why it is needed
## Hard-code a fixed width such as `custom_minimum_size = Vector2(800, 0)` in the scene and on a 720dp phone that form
## **runs off the screen.** The container fills the width; only the side margins are computed here.
##
## > side margin = max(minimum margin, (usable width − the breakpoint's maximum form width) / 2)
##
## ## How to use it
## Put this under the screen root and place a `GoScroll` + `VBoxContainer` inside it.
## Name the scroll node `Scroll` and keyboard avoidance is wired up automatically.
##
## ```
## GoForm
##  └ GoScroll (name: "Scroll")
##     └ VBoxContainer   ← stack the fields and buttons in here
## ```
##
## ## 🛑 This container **guarantees** that descendant labels wrap
## Without it a single long sentence stretches into one line, and its minimum width pushes the whole form off screen —
## both sides get clipped until you cannot even tell which screen it is. Turning it on by hand per scene always gets forgotten.
@tool
class_name GoForm
extends MarginContainer

## The scroll inside (the child named `Scroll`). When the keyboard comes up it scrolls to follow the focus.
var scroll: GoScroll

## At least this much from the screen edge (dp). Negative means the `padding` token.
@export var min_side_margin := -1:
	set(value):
		min_side_margin = value
		_relayout()

## Minimum top and bottom margin (dp). Negative means the `screen_margin` token.
@export var min_edge_margin := -1:
	set(value):
		min_edge_margin = value
		_relayout()

## Should the Android back gesture be routed to this button? It looks for a child with the unique name `%BackButton`.
## 🔑 When assembling in code, put the button inside the form, set `back.owner = form` · `back.unique_name_in_owner = true`,
##    then add the form to the tree (it is looked up once in `_ready`). Moving the scroll into an edge container keeps the owner intact.
@export var route_back_button := true

## 🔑 **Should room be left for the floating HUDs?** Turn it on and the body avoids the rectangles taken by a
## `GoHudAnchor` on the same screen, so it **never flows behind them**.
##
## Off (the default) the form uses the whole screen — the behaviour as it has always been. The usual case, a HUD
## floating over the game screen, does not need it; turn it on **when a HUD and a scrolling body share one screen**.
##
## 🛑 The direction to move is chosen by **whichever loses the least area**. A health bar at the top right is avoided
##    upward in portrait (13% of the height lost) and to the right in landscape (21% of the width) — avoiding only
##    vertically in landscape costs the body 27% of the screen.
@export var avoid_hud := false:
	set(value):
		avoid_hud = value
		_relayout()

var _runtime: Node
var _keyboard_px := 0
var _back_button: Button
var _holds_back := false
## The HUD insets last applied (left, top, right, bottom). HUD sizes settle later, so they are compared every frame.
var _hud_pad := Vector4.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_runtime = GoUi.runtime()
	if _runtime != null:
		if _runtime.has_signal(&"breakpoint_changed"):
			_runtime.breakpoint_changed.connect(func(_bp) -> void: _relayout())
		if _runtime.has_signal(&"keyboard_changed"):
			_runtime.keyboard_changed.connect(_on_keyboard)
	get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_relayout)
	if not Engine.is_editor_hint():
		scroll = get_node_or_null(^"Scroll") as GoScroll
		if scroll != null: scroll.use_panel_edge(_side_margin())
		GoStyle.form(self)
		_watch_children(self)
		if route_back_button:
			_back_button = get_node_or_null(^"%BackButton") as Button
			visibility_changed.connect(_sync_back)
			_sync_back()
	_relayout()


func _side_margin() -> int:
	return GoUi.metric(GoTheme.PADDING) if min_side_margin < 0 else min_side_margin


func _edge_margin() -> int:
	return GoUi.metric(GoTheme.SCREEN_MARGIN) if min_edge_margin < 0 else min_edge_margin


## The breakpoint's maximum form width (dp). Without the autoload it is decided from the screen width directly.
func _max_width() -> int:
	if _runtime != null and _runtime.has_method(&"form_max_width"): return _runtime.form_max_width()
	var view := get_viewport_rect().size
	return GoScale.form_width_for(GoScale.breakpoint_for_dp(minf(view.x, view.y)))


func _relayout() -> void:
	if not is_inside_tree(): return
	var view := get_viewport_rect().size
	if view.x <= 0.0: return
	var area := GoSafeArea.usable_rect(get_window())
	var side := float(_side_margin())
	var cap := _max_width()
	if cap > 0 and area.size.x > float(cap): side = maxf(side, (area.size.x - float(cap)) * 0.5)
	var keyboard := float(_keyboard_px) / maxf(1.0, get_window().content_scale_factor)
	# 🛑 **Overlap is judged where the form will actually sit.** Measured against the whole safe area, a form that is
	#    already pulled to the center on a wide screen by the width cap — nowhere near the HUD — gets **pushed aside**
	#    again and its centering breaks (the body drifted 214dp to the left on a 1280 screen — measured 2026-09-13 on desktop).
	_hud_pad = _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)) if avoid_hud else Vector4.ZERO
	add_theme_constant_override(&"margin_left", roundi(area.position.x + side + _hud_pad.x))
	add_theme_constant_override(&"margin_right", roundi(view.x - area.end.x + side + _hud_pad.z))
	add_theme_constant_override(&"margin_top", roundi(area.position.y + _hud_pad.y) + _edge_margin())
	add_theme_constant_override(&"margin_bottom",
		roundi(maxf(view.y - area.end.y + _hud_pad.w, keyboard)) + _edge_margin())


## The insets needed to avoid the floating HUDs (left, top, right, bottom, in dp).
##
## 🛑 **Each HUD is avoided in one direction only.** Pushing all four sides lets a single health bar in the top-right
##    corner eat both the top and the right, shrinking the body twice. For each overlapping HUD **the cheapest single direction** is chosen.
func _hud_insets(area: Rect2) -> Vector4:
	var here := get_viewport()
	var rects: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(GoHudAnchor.GROUP):
		var hud := node as GoHudAnchor
		if hud == null or not hud.reserve_space: continue
		if not hud.is_visible_in_tree() or hud.get_viewport() != here: continue
		# A HUD inside me is not something to avoid — it is part of the body.
		if hud == self or is_ancestor_of(hud) or hud.is_ancestor_of(self): continue
		var rect := Rect2(hud.global_position, hud.size)
		if rect.size.x > 0.0 and rect.size.y > 0.0 and area.intersects(rect): rects.append(rect)
	# 🛑 **The deepest intrusion is handled first.** The result depends on the order, so the rule is nailed down —
	#    otherwise the same screen lays out differently just because the node order changed.
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.intersection(area).get_area() > b.intersection(area).get_area())

	var remain := area
	for rect in rects:
		# 🛑 **Look again with what has already been given up subtracted.** Having moved right to avoid the top-right
		#    health bar, the bottom-right slot is already clear of it — counting it separately would eat into the bottom too.
		if not remain.intersects(rect): continue
		# **The area lost** when avoiding in each direction. The smaller one wins.
		var options := [
			[rect.end.x - remain.position.x, remain.size.y, 0],      # push in from the left
			[rect.end.y - remain.position.y, remain.size.x, 1],      # push in from the top
			[remain.end.x - rect.position.x, remain.size.y, 2],      # push in from the right
			[remain.end.y - rect.position.y, remain.size.x, 3],      # push in from the bottom
		]
		var best: Array = []
		for option in options:
			if option[0] <= 0.0: continue
			if best.is_empty() or option[0] * option[1] < best[0] * best[1]: best = option
		if best.is_empty(): continue
		var depth: float = best[0]
		match int(best[2]):
			0: remain.position.x += depth; remain.size.x -= depth
			1: remain.position.y += depth; remain.size.y -= depth
			2: remain.size.x -= depth
			_: remain.size.y -= depth
		# When nothing is left after all the cutting, **avoidance is given up** — an overlapping screen beats an empty one.
		if remain.size.x <= 0.0 or remain.size.y <= 0.0: return Vector4.ZERO
	return Vector4(remain.position.x - area.position.x, remain.position.y - area.position.y,
		area.end.x - remain.end.x, area.end.y - remain.end.y)


func _on_keyboard(height_px: int) -> void:
	if height_px == _keyboard_px: return
	_keyboard_px = height_px
	_relayout()
	if scroll == null: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and scroll.is_ancestor_of(focus): scroll.ensure_control_visible.call_deferred(focus)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree(): return
	if route_back_button: _sync_back()
	# 🛑 HUD sizes settle **later** (children's minimum sizes are measured deferred). Computing once means trusting
	#    the 0×0 of the first frame — so it is laid out again only when the value has changed.
	if avoid_hud and is_inside_tree():
		var area := GoSafeArea.usable_rect(get_window())
		var side := float(_side_margin())
		var cap := _max_width()
		if cap > 0 and area.size.x > float(cap): side = maxf(side, (area.size.x - float(cap)) * 0.5)
		if not _hud_insets(area.grow_individual(-side, 0.0, -side, 0.0)).is_equal_approx(_hud_pad):
			_relayout()
	# Without the autoload the keyboard is polled here.
	if _runtime == null and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_on_keyboard(DisplayServer.virtual_keyboard_get_height())


## Children added later get the same rules.
func _watch_children(node: Node) -> void:
	if node is ScrollBar: return
	if not node.child_entered_tree.is_connected(_child_added):
		node.child_entered_tree.connect(_child_added)
	for child in node.get_children(): _watch_children(child)


func _child_added(node: Node) -> void:
	GoStyle.form(node)
	_watch_children(node)


func _sync_back() -> void:
	if Engine.is_editor_hint(): return
	var active := is_visible_in_tree() and is_instance_valid(_back_button)
	if active == _holds_back: return
	_holds_back = active
	if active: GoBackPolicy.acquire(get_tree())
	else: GoBackPolicy.release(get_tree())


func _notification(what: int) -> void:
	# 🛑 A language change changes a button's **visible text** — what was one word can become two.
	#    The word-wrap rule is reapplied to every descendant (it is idempotent, so calling it repeatedly is the same).
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and not Engine.is_editor_hint():
		GoStyle.form(self)
		return
	if what != NOTIFICATION_WM_GO_BACK_REQUEST: return
	if not _holds_back or not is_visible_in_tree() or GoSurface.is_any_open(): return
	# 🛑 Android reports the back gesture **even during the keyboard's dismiss animation** —
	#    leaving the screen then makes the user feel "I pressed once and went back two steps".
	if _keyboard_px > 0:
		DisplayServer.virtual_keyboard_hide()
	elif is_instance_valid(_back_button) and not _back_button.disabled:
		_back_button.pressed.emit.call_deferred()


func _exit_tree() -> void:
	GoUi.unwatch(_relayout)
	if _holds_back:
		_holds_back = false
		GoBackPolicy.release(get_tree())
