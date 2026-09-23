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
## Without dots you cannot even tell the strip swipes sideways. The dots are **one bar the height of a finger**: a press
## on a dot goes to that page, and a press on the open bar either side goes one page that way — so the press area is the
## whole width however close the dots sit. The arrow keys step too, and a screen reader hears "2 / 3".
##
## ## 🔑 It is as tall as its tallest page
## The pages' minimum height is fed up to the carousel, so a banner's text is never sliced off. `custom_minimum_size`
## stays a floor — give it for a fixed art height, not to make room.
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
## The page dots — **one bar**, drawn, not a button per dot (see `_build_dots`).
var _dots: Control
var _pages: Array[Control] = []
## The frame a press was last handled on — a touch and the mouse press emulated from it must not step twice.
var _pressed_frame := -1
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
	# The page strip runs past the viewport sideways on purpose — `GoStyle.audit_layout` reads this.
	_viewport.set_meta(&"go_pages", true)
	add_child(_viewport)

	_strip = Control.new()
	_strip.name = "Strip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_strip)

	_dots = Control.new()
	_dots.name = "Dots"
	# 🛑 Physical, like the swipe — the dots run the same way the pages slide.
	_dots.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_dots.mouse_filter = Control.MOUSE_FILTER_STOP
	_dots.focus_mode = Control.FOCUS_ALL
	_dots.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dots.draw.connect(_draw_dots)
	_dots.gui_input.connect(_on_dots_input)
	_dots.focus_entered.connect(_dots.queue_redraw)
	_dots.focus_exited.connect(_dots.queue_redraw)
	_dots.resized.connect(_dots.queue_redraw)
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
		if not is_instance_valid(node): continue
		if node.minimum_size_changed.is_connected(_fit_height): node.minimum_size_changed.disconnect(_fit_height)
		if node.get_parent() == _strip: _strip.remove_child(node)
	for child in _strip.get_children(): child.queue_free()
	_pages.clear()
	for page in pages:
		var node := page as Control
		if node == null: continue
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		_pages.append(node)
		_strip.add_child(node)
		# Deferred — growing the viewport inside the signal that measured the page would re-enter the layout pass.
		node.minimum_size_changed.connect(_fit_height, CONNECT_DEFERRED)
	_index = clampi(_index, 0, maxi(0, _pages.size() - 1))
	_fit_height()
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


## 🔑 **The height is the tallest page's.** The viewport is a plain `Control` (it has to clip the strip), and a plain
##    `Control` does not take its children's minimum size — so the pages' height is fed to it here.
## 🛑 Measured 2026-09-23 on the gallery: a 120dp carousel left the viewport 52dp for a banner that needs 84, and the
##    banner's title was sliced through the middle (user report).
func _fit_height() -> void:
	if _viewport == null: return
	var tallest := 0.0
	for page in _pages:
		if is_instance_valid(page): tallest = maxf(tallest, page.get_combined_minimum_size().y)
	# 🛑 Only when it really changes — setting the same size again fires `minimum_size_changed` forever.
	if not is_equal_approx(_viewport.custom_minimum_size.y, tallest): _viewport.custom_minimum_size.y = tallest


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


## 🔑 **The dots are one bar the height of a finger** — drawn, not a button per dot.
## 🛑 A 48dp button per dot kept the touch minimum but spread three 8dp dots about 60dp apart, and the badge face
##    they borrowed drew them as hollow outlines — specks, not "page 1 of 3" (user report 2026-09-23). Overlapping the
##    buttons at a tight pitch was the other way out, but then the middle dot's real share is only the pitch — the touch
##    minimum broken in fact. One bar keeps the press area wide and lets the dots sit close.
func _build_dots() -> void:
	if _dots == null: return
	_dots.visible = show_dots and _pages.size() > 1
	_dots.custom_minimum_size = Vector2(_dots_width(), float(GoUi.metric(GoTheme.TOUCH)))
	# ♿ "2 / 3" — the drawing on its own reads as nothing. 🔑 The "n / m" form goes through a text key.
	_dots.accessibility_name = GoUi.text(&"bar_fraction").format({"value": _index + 1, "max": maxi(1, _pages.size())})
	_dots.queue_redraw()


## One dot's side (dp). The lit one is a pill this tall and 2.5× as long — its length says "you are here" without
## leaning on colour alone.
func _dot_side() -> float:
	return float(GoUi.metric(GoTheme.GAP_SMALL))


func _dots_width() -> float:
	var count := _pages.size()
	if count < 2: return 0.0
	var side := _dot_side()
	return side * 2.5 + side * float(count - 1) * 2.0


## Where each dot sits in the bar — centered, left to right.
func dot_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _dots == null: return out
	var side := _dot_side()
	var x := (_dots.size.x - _dots_width()) * 0.5
	var y := (_dots.size.y - side) * 0.5
	for i in _pages.size():
		var length := side * 2.5 if i == _index else side
		out.append(Rect2(Vector2(x, y).round(), Vector2(length, side)))
		x += length + side
	return out


func _draw_dots() -> void:
	var rects := dot_rects()
	if rects.is_empty(): return
	var idle := _idle_ink()
	var lit := GoUi.color(GoTheme.ACCENT)
	for i in rects.size():
		_dots.draw_style_box(GoUi.skin().dot_box(lit if i == _index else idle, rects[i].size.y), rects[i])
	# ⌨ The focus ring goes round the dots, not round the whole bar.
	if _dots.has_focus():
		var ring := _dots.get_theme_stylebox(&"focus", &"Button")
		if ring != null:
			var around := Rect2(rects[0].position, Vector2(rects[-1].end.x - rects[0].position.x, rects[0].size.y))
			_dots.draw_style_box(ring, around.grow(_dot_side()))


## The dots that are not lit — dimmer than the lit one, but still a graphic that must read (3:1 on the page).
func _idle_ink() -> Color:
	return GoSkin.readable_on(GoUi.color(GoTheme.MUTED), GoUi.color(GoTheme.BACKGROUND), 3.0)


func _on_dots_input(event: InputEvent) -> void:
	var at := Vector2.INF
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed: at = touch.position
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed: at = mouse.position
	if at.is_finite():
		_dots.accept_event()
		if _pressed_frame == Engine.get_process_frames(): return
		_pressed_frame = Engine.get_process_frames()
		press_dots_at(at)
		return
	if event.is_action_pressed(&"ui_left"):
		_dots.accept_event()
		_step(-1)
	elif event.is_action_pressed(&"ui_right"):
		_dots.accept_event()
		_step(1)


## A press on the dot bar at [param at] (bar coordinates). On the dots it goes to the dot nearest the press — you land
## on the page you pointed at. On the open bar either side it goes one page that way.
## 🔑 That keeps both promises: the page you pointed at, and a press area far wider than the touch minimum. Split the
##    bar into equal parts instead and the parts no longer sit under the dots — every dot of a centered row of three
##    falls in the middle third.
func press_dots_at(at: Vector2) -> void:
	var rects := dot_rects()
	if _index >= rects.size(): return
	var reach := _dot_side() * 0.5
	if at.x >= rects[0].position.x - reach and at.x <= rects[-1].end.x + reach:
		var nearest := 0
		for i in rects.size():
			if absf(rects[i].get_center().x - at.x) < absf(rects[nearest].get_center().x - at.x): nearest = i
		if nearest != _index:
			GoFeedback.tapped()
			go_to(nearest)
		return
	_step(-1 if at.x < rects[0].position.x else 1)


func _step(direction: int) -> void:
	GoFeedback.tapped()
	go_to(_index + direction)


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
	_fit_height()
	_build_dots()
	_sync_timer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _build_dots()
	elif what == NOTIFICATION_VISIBILITY_CHANGED: _sync_timer()
