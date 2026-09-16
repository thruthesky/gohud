## 🧭 **A guided tour (coach mark).** It points at the real controls on screen one by one and says what they are.
##
## ## 🛑 It does not block
## Only the card area takes input. The game and the highlighted control **stay usable**, and actually pressing
## the highlighted control moves to the next step — "tap here" becomes an action, not a sentence.
##
## ```gdscript
## var tour := GoCoachMark.new()
## add_child(tour)
## tour.finished.connect(func(done: bool) -> void: save_tour_seen())
## tour.start([
##     {"target": bag_button, "title": "Bag", "body": "Everything you pick up gathers here."},
##     {"target": map_button, "title": "Map", "body": "Tap to open the full map."},
## ])
## ```
##
## Step entries:
## | Key | Meaning |
## |---|---|
## | `target` | The `Control` to point at. If it disappears the step is skipped |
## | `title`·`body` | Either a translation key or literal text (these are auto-translating labels) |
## | `signal` | This signal on the target moves to the next step. Default `pressed`. 🛑 **Argument-less signals** only |
@tool
class_name GoCoachMark
extends Control

signal finished(completed: bool)
signal step_changed(index: int)

## Maximum width of the card (dp).
@export_range(160, 600) var card_max_width := 280.0

## The **fraction of the screen from the top** (0~1) the card must stay within in portrait. 0 means no limit.
## 🛑 A game usually has the character in the middle of the screen — a guide card over it hides the controls.
@export_range(0.0, 1.0, 0.01) var avoid_center_band := 0.45

## Colour of the ring and the pointer. Transparent uses the theme's `accent`.
@export var ink := Color.TRANSPARENT
## 🔑 **Things the card must not cover.** Fixed HUD (a `GoHudAnchor` box with `reserve_space`) is avoided
## automatically, but put non-anchor things such as a screen header or toolbar in here — a card lying on top
## of them blocks the controls (measured in the demo 2026-09-13: the card covered the header's `→ ×`).
@export var keep_clear: Array[Control] = []

var card: PanelContainer
var title_label: Label
var body_label: Label
var progress_label: Label
var next_button: Button
var skip_button: Button
var steps: Array[Dictionary] = []
var step := 0

var _target: Control
var _target_action := Callable()
var _target_signal := &""
var _ring: StyleBox
var _phase := 0.0
var _holds_back := false
var _fade: Tween
var _scroll: GoScroll
var _column: VBoxContainer
var _header: HBoxContainer


## 🪟 **Opacity of the panel ground** (0.0~1.0) — for making this one thing differ. Negative uses whatever the theme and settings decide.
## 🛑 Only the ground thins out — text and icons stay crisp.
var alpha := -1.0:
	set(value):
		alpha = value
		if card != null: _apply_accent()


func _init() -> void:
	name = "CoachMark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## 🛑 The children are built in `_init` — `start()` has to be callable before this enters the tree.
func _build() -> void:
	theme = GoUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent := _accent()
	_ring = GoUi.skin().coach_ring_box(accent)

	card = PanelContainer.new()
	card.name = "GuideCard"
	var face := GoUi.skin().floating_box(GoTheme.BOX_CARD, accent, alpha)
	face.set_content_margin_all(0)
	card.add_theme_stylebox_override(&"panel", face)
	add_child(card)

	var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	card.add_child(inset)
	_column = GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	inset.add_child(_column)

	_header = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	_header.name = "Header"
	_column.add_child(_header)
	progress_label = GoStyle.label("", GoTheme.ROLE_CAPTION, accent)
	progress_label.name = "Progress"
	progress_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.text_direction = Control.TEXT_DIRECTION_LTR
	_header.add_child(progress_label)
	title_label = GoStyle.label_key("", GoTheme.ROLE_BODY)
	title_label.name = "Title"
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header.add_child(title_label)

	_scroll = _make_scroll()
	_column.add_child(_scroll)
	body_label = GoStyle.label_key("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	body_label.name = "Body"
	_scroll.add_child(body_label)

	var actions := GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	actions.name = "Actions"
	_column.add_child(actions)
	skip_button = GoStyle.button_key(GoUi.text_key(&"skip"), finish.bind(false), GoStyle.Tone.BARE)
	skip_button.name = "Skip"
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skip_button.custom_minimum_size.x = 72
	GoStyle.typography(skip_button, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	actions.add_child(skip_button)
	actions.add_child(GoStyle.spacer())
	next_button = GoStyle.button_key(GoUi.text_key(&"next"), advance, GoStyle.Tone.PRIMARY)
	next_button.name = "Next"
	next_button.custom_minimum_size = Vector2(72, GoUi.config.min_touch_size)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.add_child(next_button)
	hide()
	set_process(false)


func _ready() -> void:
	# `ink` may have been changed after `new()` — re-apply the colour.
	_apply_accent()
	# 🎨 When the whole look changes (`GoUi.use_preset()`), re-tint the ring, the panel and the progress text.
	# 🛑 The ring is a cache `_draw()` reads (`_ring`) — rebuild it or the old skin's shape stays on screen.
	GoUi.watch(_on_ui_changed)


func _apply_accent() -> void:
	var accent := _accent()
	_ring = GoUi.skin().coach_ring_box(accent)
	var face := GoUi.skin().floating_box(GoTheme.BOX_CARD, accent, alpha)
	face.set_content_margin_all(0)
	card.add_theme_stylebox_override(&"panel", face)
	progress_label.add_theme_color_override(&"font_color", accent)


## Start the tour. For the entry format see the table at the top of this file.
func start(value: Array) -> void:
	_disconnect_target()
	steps.assign(value)
	step = 0
	if steps.is_empty(): return
	if not _holds_back:
		GoBackPolicy.acquire(get_tree())
		_holds_back = true
	show()
	set_process(true)
	_show_step()


func advance() -> void:
	if not visible: return
	step += 1
	_show_step()


func finish(completed: bool) -> void:
	_disconnect_target()
	_release_back()
	hide()
	set_process(false)
	queue_redraw()
	finished.emit(completed)


func _show_step() -> void:
	_disconnect_target()
	if step >= steps.size():
		finish(true)
		return
	var data := steps[step]
	_target = data.get("target") as Control
	# The target disappears when a responsive rail collapses or the screen changes — skip that step.
	if not is_instance_valid(_target):
		advance()
		return
	var wanted := StringName(str(data.get("signal", "pressed")))
	if _target.has_signal(wanted):
		_target_signal = wanted
		_target_action = advance.call_deferred
		_target.connect(_target_signal, _target_action)
	title_label.text = str(data.get("title", ""))
	body_label.text = str(data.get("body", ""))
	progress_label.text = GoUi.text(&"coach_progress").format({"step": step + 1, "total": steps.size()})
	next_button.text = GoUi.text_key(&"done") if step == steps.size() - 1 else GoUi.text_key(&"next")
	# 🛑 Once the text changed, redo the wrapping too — otherwise `Done` breaks into `Don`/`e` (measured).
	GoStyle.fit_words(next_button)
	_fade = GoStyle.fade(card, _fade, true)
	_layout()
	step_changed.emit(step)


func _disconnect_target() -> void:
	if is_instance_valid(_target) and not _target_signal.is_empty() and _target_action.is_valid() \
			and _target.is_connected(_target_signal, _target_action):
		_target.disconnect(_target_signal, _target_action)
	_target_action = Callable()
	_target_signal = &""


func _release_back() -> void:
	if not _holds_back: return
	_holds_back = false
	GoBackPolicy.release(get_tree())


func _exit_tree() -> void:
	_disconnect_target()
	_release_back()
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	_apply_accent()
	queue_redraw()


func _process(delta: float) -> void:
	if not GoUi.config.reduce_motion: _phase += delta
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		advance()
		return
	# Hide the card while a real menu is open — it picks up where it left off once that closes.
	card.visible = not _should_pause()
	if card.visible: _layout()
	queue_redraw()


## Should the card be hidden for now — the default is "any gohud surface is open". 🔑 If the host has a modal system
## of its own, override this in a subclass to take that into account too (it resumes at the same step on close).
func _should_pause() -> bool:
	return GoSurface.is_any_open()


func _accent() -> Color:
	return ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)


## Global rect → this node's coordinates. 🛑 When this node does not sit at the origin (a margin inside a
##    `CanvasLayer`, say), drawing global coordinates as they are puts the ring in the wrong place.
func _to_local(rect: Rect2) -> Rect2:
	return Rect2(get_global_transform().affine_inverse() * rect.position, rect.size)


func _layout() -> void:
	if not is_instance_valid(_target): return
	var area := GoSafeArea.usable_rect(get_window()).grow(-GoUi.metric(GoTheme.GAP_SMALL))
	var landscape := area.size.x > area.size.y
	var width := minf(card_max_width, area.size.x * (0.44 if landscape else 0.82))
	card.size.x = width
	var chrome := float(GoUi.metric(GoTheme.PADDING_COMPACT) * 2 + _column.get_theme_constant(&"separation") * 2)
	var desired := chrome + _header.get_combined_minimum_size().y + body_label.get_minimum_size().y + GoUi.config.min_touch_size
	card.size.y = minf(maxf(116.0, desired), area.size.y * (0.52 if landscape else 0.32))
	var target := _target.get_global_rect()
	var gap := float(GoUi.metric(GoTheme.GAP))
	# Beside the target in landscape, above or below it in portrait. Stay off the centre when an edge will do.
	var x := clampf(target.get_center().x - width * 0.5, area.position.x, area.end.x - width)
	var y := target.end.y + gap
	if target.get_center().y > area.get_center().y: y = target.position.y - gap - card.size.y
	if landscape:
		x = target.position.x - gap - width if target.get_center().x > area.get_center().x else target.end.x + gap
		# 🛑 Do not send it to the very top or bottom of the screen — fixed HUD and headers live in those bands.
		#    The card covered the header's buttons (measured in the demo 2026-09-13). Sit it **level with the target**.
		y = target.position.y
	elif avoid_center_band > 0.0:
		y = minf(y, area.position.y + area.size.y * avoid_center_band - card.size.y)
	var global := Vector2(
		clampf(x, area.position.x, maxf(area.position.x, area.end.x - card.size.x)),
		clampf(y, area.position.y, maxf(area.position.y, area.end.y - card.size.y)))
	global = _dodge_fixtures(Rect2(global, card.size), area, target).position
	card.position = get_global_transform().affine_inverse() * global


## Move the card clear of the fixed HUD and of `keep_clear` — in whichever of the four directions moves it **least**,
## and never onto the target. 🛑 If it cannot clear everything (a narrow screen) leave it — overlapping beats vanishing.
func _dodge_fixtures(rect: Rect2, area: Rect2, target: Rect2) -> Rect2:
	var blocks: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(GoHudAnchor.GROUP):
		var hud := node as GoHudAnchor
		if hud == null or not hud.reserve_space or not hud.is_visible_in_tree(): continue
		if hud.get_viewport() != get_viewport(): continue
		var r := Rect2(hud.global_position, hud.size)
		if r.get_area() > 0.0: blocks.append(r)
	for control in keep_clear:
		if is_instance_valid(control) and control.is_visible_in_tree(): blocks.append(control.get_global_rect())
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL))
	for i in 4:                       # Several fixtures in turn — a spot moved to can overlap another one
		var hit := Rect2()
		var found := false
		for block in blocks:
			if rect.intersects(block):
				hit = block; found = true; break
		if not found: return rect
		var options := [
			Vector2(0.0, hit.end.y + gap - rect.position.y),          # down
			Vector2(0.0, hit.position.y - gap - rect.end.y),          # up
			Vector2(hit.end.x + gap - rect.position.x, 0.0),          # right
			Vector2(hit.position.x - gap - rect.end.x, 0.0),          # left
		]
		var best := Vector2.INF
		for move in options:
			var moved := Rect2(rect.position + move, rect.size)
			if not area.encloses(moved): continue
			if moved.intersects(target): continue               # Cover the target and it is not a coach mark
			if move.length() < best.length(): best = move
		if best == Vector2.INF: return rect
		rect.position += best
	return rect


func _draw() -> void:
	if not visible or card == null or not card.visible or not is_instance_valid(_target): return
	var pulse := 3.0 + (0.0 if GoUi.config.reduce_motion else sin(_phase * 3.0))
	var rect := _to_local(_target.get_global_rect().grow(pulse))
	draw_style_box(_ring, rect)
	var center := rect.get_center()
	var start := Vector2(
		clampf(center.x, card.position.x + 8, card.position.x + card.size.x - 8),
		clampf(center.y, card.position.y + 8, card.position.y + card.size.y - 8))
	var direction := (center - start).normalized()
	if direction.is_zero_approx(): return
	var tip := center - direction * (maxf(rect.size.x, rect.size.y) * 0.5 + 5.0)
	# 🔑 The geometry is worked out here, the shape drawn by the skin — another theme can make it a dashed line or a target reticle.
	GoUi.skin().draw_coach_pointer(self, start, tip, direction, _accent())


func _input(event: InputEvent) -> void:
	if visible and not GoSurface.is_any_open() and event.is_action_pressed(&"ui_cancel"):
		finish(false)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and not GoSurface.is_any_open():
		finish.call_deferred(false)
	# 🛑 The progress text ("1 / 5") is assembled, so the engine's auto-translation never touches it — rebuild it ourselves.
	elif what == NOTIFICATION_TRANSLATION_CHANGED and visible and not steps.is_empty():
		progress_label.text = GoUi.text(&"coach_progress").format({"step": step + 1, "total": steps.size()})


## Build the body scroll. 🔑 If the host wants a `GoScroll` subclass (for old type-hint compatibility, say), override this in a subclass.
func _make_scroll() -> GoScroll:
	return GoScroll.new()
