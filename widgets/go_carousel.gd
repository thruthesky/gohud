## 🎠 **넘겨 보는 띠** — 상점 배너, 캐릭터 고르기, 신규 콘텐츠 안내.
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
## ## 🛑 저절로 넘어가는 것은 **읽을 시간을 뺏는다**
## 배너가 3초마다 바뀌면 글을 다 읽기 전에 사라진다. 기본은 **저절로 안 넘어간다**(`autoplay_seconds = 0`).
## 켤 때는 5초 이상을 준다. 그리고 **손을 대면 멈춘다** — 읽으려고 손가락을 올렸는데 넘어가면 안 된다.
##
## ## ♿ `reduce_motion` 이면 저절로 넘기지 않는다
## 움직임을 줄인 사람에게 스스로 움직이는 화면은 그 자체가 문제다. 그 설정이 켜져 있으면
## 자동 넘김을 **하지 않는다** — 점을 눌러 직접 넘길 수 있으니 기능이 사라지는 것은 아니다.
##
## ## 🔑 점(indicator)은 몇 장인지·지금 몇 번째인지를 말한다
## 점이 없으면 옆으로 넘길 수 있다는 것조차 모른다. 점은 **누를 수 있고**, 터치 하한을 지킨다.
@tool
class_name GoCarousel
extends VBoxContainer

## 보이는 쪽이 바뀌었다.
signal page_changed(index: int)

## 몇 초마다 저절로 넘길 것인가. **0 이면 안 넘긴다**(기본).
@export var autoplay_seconds := 0.0:
	set(value):
		autoplay_seconds = maxf(0.0, value)
		_sync_timer()

## 넘어가는 데 걸리는 시간(초). `reduce_motion` 이면 즉시.
@export var motion_seconds := 0.25

## 끝에서 다시 처음으로 돌아갈 것인가.
@export var loop := true

## 점을 보여 줄 것인가.
@export var show_dots := true:
	set(value):
		show_dots = value
		if is_instance_valid(_dots): _dots.visible = value and _pages.size() > 1

## 이만큼(dp) 끌면 넘긴다.
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
	# 🛑 넘기는 방향은 **물리적**이다 — 점과 쪽 차례가 글 방향을 따라 뒤집히면 혼란스럽다.
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


## 보여 줄 쪽들. 각 쪽은 `Control` 이고, 폭·높이는 이 위젯이 잡는다.
func set_pages(pages: Array) -> void:
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


## 그 쪽으로 넘긴다.
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
		# 🛑 보이는 점은 작아도 **누르는 자리는 터치 하한**이다 — 6dp 점을 직접 누르게 하지 않는다.
		var touch := float(GoUi.metric(GoTheme.TOUCH)) * 0.6
		dot.custom_minimum_size = Vector2(touch, touch)
		var lit := i == _index
		var glyph := PanelContainer.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := float(GoUi.metric(GoTheme.GAP_SMALL)) * (1.0 if lit else 0.7)
		glyph.custom_minimum_size = Vector2(side, side)
		glyph.set_anchors_preset(Control.PRESET_CENTER)
		glyph.add_theme_stylebox_override(&"panel", GoUi.skin().badge_box(
			GoUi.color(GoTheme.ACCENT) if lit else GoUi.color(GoTheme.MUTED)))
		dot.add_child(glyph)
		var target := i
		dot.pressed.connect(func() -> void:
			GoFeedback.tapped()
			go_to(target))
		# ♿ "3장 중 2번째" — 점 그림만으로는 읽히지 않는다.
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
		# 🔑 손을 대면 자동 넘김을 **멈춘다** — 읽으려고 손을 올렸는데 넘어가면 안 된다.
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


## 저절로 넘길 조건이 되는지 보고 `_process` 를 켜고 끈다.
## 🛑 `reduce_motion` 이면 **끈다** — 움직임을 줄인 사람에게 스스로 움직이는 화면을 주지 않는다.
func _sync_timer() -> void:
	set_process(autoplay_seconds > 0.0 and _pages.size() > 1
		and not GoUi.config.reduce_motion and not Engine.is_editor_hint())


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))
	_build_dots()
	_sync_timer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _build_dots()
