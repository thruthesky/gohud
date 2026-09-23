## 🎠 **A strip you swipe through** — shop banners, character select, new-content announcements.
##
## ```gdscript
## var banners := GoCarousel.new()
## banners.custom_minimum_size.y = 160
## sheet.body.add_child(banners)
## banners.set_pages([promo_card, event_card, pack_card])
## banners.autoplay_seconds = 5.0
## banners.page_changed.connect(func(index: int) -> void: track_view(index))
## ```
##
## ## 🛑 Advancing on its own **steals reading time**
## A banner that changes every 3 seconds is gone before the text has been read. By default it **does not advance on its own** (`autoplay_seconds = 0`).
## When you turn it on, give it 5 seconds or more. And it **stops the moment you touch it** — nothing may slide away under a finger that came to read.
##
## ## ♿ Under `reduce_motion` it never advances by itself
## To someone who reduced motion, a screen that moves on its own is the problem itself. With that setting on,
## auto-advance **does not happen** — nothing is lost, since the dots still flip pages by hand.
##
## ## 🔑 The dots say how many pages there are and which one you are on
## Without dots you cannot even tell the strip swipes sideways. The dots are **pressable**, and they keep the touch minimum.
@tool
class_name GoCarousel
extends VBoxContainer

## The visible page changed.
signal page_changed(index: int)

## Seconds between automatic advances. **0 never advances** (the default).
@export var autoplay_seconds := 0.0:
	set(value):
		autoplay_seconds = maxf(0.0, value)
		_sync_timer()

## How long a page change takes (seconds). Instant under `reduce_motion`.
@export var motion_seconds := 0.25

## Whether the end wraps around to the beginning.
@export var loop := true

## Whether to show the dots.
@export var show_dots := true:
	set(value):
		show_dots = value
		if is_instance_valid(_dots): _dots.visible = value and _pages.size() > 1

## Drag this far (dp) to flip a page.
@export var swipe_dp := 48.0

var _viewport: Control
var _strip: Control
var _dots: HBoxContainer
var _pages: Array[Control] = []
var _index := 0
var _tween: Tween
var _drag_from := Vector2.INF
var _elapsed := 0.0


func _init() -> void:
	name = "Carousel"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))

	_viewport = Control.new()
	_viewport.name = "Viewport"
	_viewport.clip_contents = true
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.gui_input.connect(_on_input)
	# 🛑 The swipe direction is **physical** — flipping the order of dots and pages with the text direction is only confusing.
	_viewport.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_viewport)

	_strip = Control.new()
	_strip.name = "Strip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_strip)

	_dots = GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	_dots.name = "Dots"
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_dots)


func _ready() -> void:
	_viewport.resized.connect(_relayout)
	_relayout()
	_sync_timer()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## The pages to show. Each is a `Control`, and this widget sets their width and height.
func set_pages(pages: Array) -> void:
	# 🛑 **Never free the page nodes handed in** — call this twice reusing the same banner and you end up re-parenting a
	#    freed node. Ownership stays with the caller (the same rule as `GoTable`).
	for node in _pages:
		if is_instance_valid(node) and node.get_parent() == _strip: _strip.remove_child(node)
	for child in _strip.get_children(): child.queue_free()
	_pages.clear()
	for page in pages:
		var node := page as Control
		if node == null: continue
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		_pages.append(node)
		_strip.add_child(node)
	_index = clampi(_index, 0, maxi(0, _pages.size() - 1))
	_build_dots()
	_relayout()
	_sync_timer()


func pages() -> Array[Control]:
	return _pages


func index() -> int:
	return _index


## Flips to that page.
func go_to(target: int, animate := true) -> void:
	if _pages.is_empty(): return
	var next := target
	if loop: next = posmod(target, _pages.size())
	else: next = clampi(target, 0, _pages.size() - 1)
	if next == _index and animate: return
	_index = next
	_elapsed = 0.0
	_slide(animate)
	_build_dots()
	page_changed.emit(_index)


func next() -> void:
	go_to(_index + 1)


func previous() -> void:
	go_to(_index - 1)


func _relayout() -> void:
	if _viewport == null: return
	var box := _viewport.size
	if box.x <= 0.0: return
	_strip.size = Vector2(box.x * maxi(1, _pages.size()), box.y)
	for i in _pages.size():
		_pages[i].position = Vector2(box.x * i, 0.0)
		_pages[i].size = box
	_slide(false)


func _slide(animate: bool) -> void:
	if _viewport == null or _pages.is_empty(): return
	var rest := -_viewport.size.x * _index
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	if not animate or GoUi.config.reduce_motion or motion_seconds <= 0.0 or not is_inside_tree():
		_strip.position.x = rest
		return
	_tween = create_tween()
	_tween.tween_property(_strip, "position:x", rest, motion_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _build_dots() -> void:
	if _dots == null: return
	for child in _dots.get_children(): child.queue_free()
	_dots.visible = show_dots and _pages.size() > 1
	if not _dots.visible: return
	for i in _pages.size():
		var dot := Button.new()
		dot.theme = GoUi.theme()
		dot.theme_type_variation = GoTheme.VAR_BARE_BUTTON
		dot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		# 🛑 The dot may look small, but **the press target stays at the touch minimum**. Multiplying by 0.6 to shrink it to
		#    28.8dp was breaking that minimum ourselves (measured 2026-09-16). If the dots look crowded, shrink the dot,
		#    never the press target.
		var touch := float(GoUi.metric(GoTheme.TOUCH))
		dot.custom_minimum_size = Vector2(touch, touch)
		var lit := i == _index
		# 🛑 A `Panel`, not a `PanelContainer` — the badge face pads 5dp a side, which made the container wider than the
		#    dot and drew an oval. And centered by its own size (`center_in`): anchors alone put its corner on the center.
		var glyph := Panel.new()
		glyph.name = "Dot"
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := float(GoUi.metric(GoTheme.GAP_SMALL)) * (1.0 if lit else 0.7)
		glyph.custom_minimum_size = Vector2(side, side)
		glyph.add_theme_stylebox_override(&"panel", GoUi.skin().badge_box(
			GoUi.color(GoTheme.ACCENT) if lit else GoUi.color(GoTheme.MUTED)))
		dot.add_child(glyph)
		GoStyle.center_in(glyph)
		var target := i
		dot.pressed.connect(func() -> void:
			GoFeedback.tapped()
			go_to(target))
		# ♿ "2 of 3" — the dot graphic on its own reads as nothing.
		dot.accessibility_name = GoUi.text(&"bar_fraction").format({"value": i + 1, "max": _pages.size()})
		_dots.add_child(dot)


func _on_input(event: InputEvent) -> void:
	var down := Vector2.INF
	var up := Vector2.INF
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed: down = touch.position
		else: up = touch.position
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		if mouse.pressed: down = mouse.position
		else: up = mouse.position

	if down.is_finite():
		_drag_from = down
		# 🔑 A touch **stops** the autoplay — nothing may slide away under a finger that came to read.
		_elapsed = 0.0
		return
	if not up.is_finite() or not _drag_from.is_finite(): return
	var moved := up.x - _drag_from.x
	_drag_from = Vector2.INF
	if absf(moved) < swipe_dp: return
	_viewport.accept_event()
	GoFeedback.tapped()
	if moved < 0.0: next()
	else: previous()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pages.size() < 2: return
	_elapsed += delta
	if _elapsed < autoplay_seconds: return
	_elapsed = 0.0
	next()


## Turns `_process` on or off depending on whether the conditions for advancing on its own hold.
## 🛑 Under `reduce_motion` it is **off** — never hand a self-moving screen to someone who reduced motion.
func _sync_timer() -> void:
	# 🛑 **It does not run while hidden** — a banner buried behind a drawer or a sheet that keeps advancing leaves the
	#    wrong page showing when you come back, and burns battery in the meantime.
	set_process(autoplay_seconds > 0.0 and _pages.size() > 1 and is_visible_in_tree()
		and not GoUi.config.reduce_motion and not Engine.is_editor_hint())


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))
	_build_dots()
	_sync_timer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _build_dots()
	elif what == NOTIFICATION_VISIBILITY_CHANGED: _sync_timer()
