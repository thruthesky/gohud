## 🤖 **The hand that works the demo for you.**
##
## It draws a cursor on top of the screen and pushes **real input events** in at that spot. Nothing is
## faked — an event that arrives through `Input.parse_input_event()` is handled by the engine exactly as
## a human hand would be. So a button really goes hover → pressed and emits its `pressed` signal, a
## slider's value changes by how far it was dragged, and a checkbox ticks itself. The demo is not a
## picture that "looks like it works" — it is the working itself.
##
## 🛑 Every wait passes through the single `wait()` — which is why pause, speed and skip are heard everywhere.
## Cursor paths use viewport coordinates; _push converts them to window coordinates for Input.
class_name SimBot
extends CanvasLayer

## What is being done right now — one line at the bottom of the screen.
signal said(text: String)
## What happened — the log on the right. It comes from the callbacks the widgets really fired.
signal logged(text: String)
signal shortcut(event: InputEvent)

const SPEED := 1600.0            ## How fast the cursor moves (px/s)
const HOME := Vector2(-200, -200)

## Playback speed. 1.0 is normal; at 2.0 you watch it twice as fast.
var speed := 1.0
## Is it paused?
var paused := false
## 🔍 Checks that the aimed widget was really hit (`--trace`). A click that misses vanishes silently, so
## when the demo looks as if "nothing happened", this is what tells you first.
var verify := false
var failures: Array[String] = []
var checks := 0

var _ink := Color("#29b8f0")
var _canvas: Control
var _point := HOME
var _down := false
var _ring := 0.0
var _skip := false


func _init() -> void:
	# 🛑 It has to sit above dialogs (100) and sheets (10) for the cursor to show over them.
	layer = 200
	_canvas = Control.new()
	_canvas.name = "Cursor"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the cursor must not swallow its own input
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_cursor)
	add_child(_canvas)


func _ready() -> void:
	if DisplayServer.get_name() == "headless": get_viewport().notify_mouse_entered()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.has_meta(&"simulated"):
		shortcut.emit(event)


func _process(delta: float) -> void:
	if _ring > 0.0:
		_ring = maxf(0.0, _ring - delta * 2.4)
		_canvas.queue_redraw()


func set_ink(value: Color) -> void:
	_ink = value


# ── Flow ───────────────────────────────────────────────────────────────

## Advances one frame. While paused it waits here until released — the only place pause is heard.
func _tick() -> float:
	await get_tree().process_frame
	while paused and not _skip:
		await get_tree().process_frame
	return get_process_delta_time()


## Rests for `seconds` (playback speed applies). While skipping it simply passes through.
func wait(seconds: float) -> void:
	if _skip: return
	var left := seconds / maxf(0.1, speed)
	while left > 0.0 and not _skip:
		left -= await _tick()


## Until the layout settles — a freshly built screen only knows its size on the next frame.
func settle(seconds := 0.5) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await wait(seconds)


## Folds up the current scene. What is left only changes the screen and ends right away.
func skip() -> void:
	_skip = true
	rest()


## Clears the skip flag for the next scene.
func rearm() -> void:
	_skip = false


func skipping() -> bool:
	return _skip


func say(text: String) -> void:
	if _skip: return
	if not text.is_empty(): said.emit(text)


func note(text: String) -> void:
	if not text.is_empty(): logged.emit(text)


# ── Cursor ─────────────────────────────────────────────────────────────

func _draw_cursor() -> void:
	if _point.x < -100.0: return
	if _ring > 0.0:
		var grow := (1.0 - _ring) * 30.0 + 12.0
		_canvas.draw_arc(_point, grow, 0.0, TAU, 40, Color(_ink, _ring * 0.75), 2.5, true)
	var radius := 9.0 if _down else 13.0
	_canvas.draw_circle(_point + Vector2(1.5, 2.0), radius + 2.0, Color(0.0, 0.0, 0.0, 0.35))
	_canvas.draw_circle(_point, radius, Color(1.0, 1.0, 1.0, 0.93))
	_canvas.draw_arc(_point, radius, 0.0, TAU, 32, Color(_ink, 0.95), 2.5, true)
	_canvas.draw_circle(_point, 2.5, Color(_ink, 0.9))


func _place(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if _down else 0
	_point = point
	_push(event)
	_canvas.queue_redraw()


func _push(event: InputEvent) -> void:
	# Input updates button state and routes events to the active embedded popup.
	# Viewport.push_input bypasses both; emitting menu signals hides failed input.
	var view := get_viewport()
	if view == null: return
	event.set_meta(&"simulated", true)
	Input.parse_input_event(event.xformed_by(view.get_final_transform()))


func _button(pressed: bool) -> void:
	# Restore hover before each edge; native pointer movement may arrive between frames.
	_place(_point)
	_down = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _point
	event.global_position = _point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_push(event)
	if pressed: _ring = 1.0
	_canvas.queue_redraw()


## The centre of the target. A target that is gone (freed or hidden) gives `HOME` — the caller skips on that.
static func center_of(node: Control) -> Vector2:
	if not is_instance_valid(node) or not node.is_visible_in_tree(): return HOME
	return node.get_global_rect().get_center()


func here() -> Vector2:
	return _point


# ── Acting ─────────────────────────────────────────────────────────────

## Moves the cursor to that spot (easing in and out).
func move(point: Vector2) -> void:
	if point.x < -100.0: return
	if _skip: return
	var from := _point if _point.x > -100.0 else point + Vector2(0.0, 120.0)
	var span := clampf(from.distance_to(point) / SPEED, 0.14, 0.6) / maxf(0.1, speed)
	var elapsed := 0.0
	while elapsed < span:
		elapsed += await _tick()
		if _skip: break
		_place(from.lerp(point, ease(clampf(elapsed / span, 0.0, 1.0), 0.4)))
	if not _skip: _place(point)


func move_to(node: Control) -> void:
	await reveal(node)
	if not _skip: await move(center_of(node))


## Bring clipped controls into view using the same wheel events as a person.
func reveal(node: Control) -> void:
	if _skip or not is_instance_valid(node): return
	await get_tree().process_frame
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			var scroll := ancestor as ScrollContainer
			var direction := 0
			for attempt in 10:
				if _skip or not is_instance_valid(node): return
				var view := scroll.get_global_rect()
				var target := node.get_global_rect()
				# This is a vertical scroll. Full-width controls must not fail an
				# X-axis containment test and trigger endless up/down corrections.
				var delta := 0.0
				if target.size.y > view.size.y - 4.0:
					if target.get_center().y >= view.position.y and target.get_center().y <= view.end.y: break
					delta = target.get_center().y - view.get_center().y
				elif target.end.y > view.end.y - 2.0:
					delta = target.end.y - view.end.y + 2.0
				elif target.position.y < view.position.y + 2.0:
					delta = target.position.y - view.position.y - 2.0
				if absf(delta) <= 2.0: break
				var wanted := 1 if delta > 0 else -1
				# Never reverse to chase subpixel layout rounding or focus scrolling.
				if direction != 0 and wanted != direction: break
				direction = wanted
				var before := scroll.scroll_vertical
				await move(view.get_center())
				if _skip: return
				_wheel(direction, clampf(absf(delta) / maxf(1.0, view.size.y / 8.0), 0.05, 3.0))
				await wait(0.18)
				if scroll.scroll_vertical == before: break
		ancestor = ancestor.get_parent()


func _wheel(direction: int, factor := 1.0) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if direction > 0 else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.factor = factor
		event.position = _point
		event.global_position = _point
		_push(event)


## Presses once at the current spot.
func tap() -> void:
	if _skip: return
	_button(true)
	await wait(0.11)
	if _skip: return
	_button(false)
	await wait(0.22)


## 🔑 **Presses** a target — move, press, release. The widget takes it as a real click.
func click(node: Control, note_text := "") -> void:
	if _skip: return
	say(note_text)
	if not is_instance_valid(node) or not node.is_visible_in_tree():
		expect(false, "Click target is visible")
		return
	await move_to(node)
	if _skip: return
	_check(node)
	await tap()


## Is what lies under the cursor right now the thing we aimed at?
func _check(node: Control) -> void:
	if not verify: return
	var view := get_viewport()
	if view == null: return
	var under := view.gui_get_hovered_control()
	if under == node or (under != null and node.is_ancestor_of(under)): return
	expect(false, "Click reaches %s (%s) at %s, hovered: %s" % [node.name, node.get_class(), node.get_global_rect(), under])


## Presses one coordinate — for aiming at **a spot inside a node**, such as a tab bar or a foldable's title.
func click_at(point: Vector2, note_text := "") -> void:
	if _skip: return
	say(note_text)
	await move(point)
	await tap()


## Presses and releases a single key.
func _tap_key(code: Key) -> void:
	if _skip: return
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		_push(key)
	await wait(0.02)


## Open and select through real input, including PopupMenu's Window input route.
func open_select(node: OptionButton, note_text := "") -> void:
	await click(node, note_text)
	await wait(0.45)
	if not _skip: expect(node.get_popup().visible, "Select popup opened")


func pick_with_keys(popup: PopupMenu, index: int, note_text := "") -> void:
	if _skip: return
	say(note_text)
	if not is_instance_valid(popup) or not popup.visible:
		expect(false, "Menu is open before selection")
		return
	if index < 0 or index >= popup.item_count or popup.is_item_disabled(index):
		expect(false, "Menu target is selectable")
		return
	# A placeholder starts at -1; an existing selection starts at that item.
	# Observe focus instead of assuming that the first item is already focused.
	for attempt in popup.item_count + 1:
		if _skip: return
		if popup.get_focused_item() == index: break
		await _tap_key(KEY_DOWN)
		await wait(0.18)
	if _skip: return
	if popup.get_focused_item() != index:
		expect(false, "Keyboard reached menu item %d" % index)
		return
	await wait(0.3)
	await _tap_key(KEY_ENTER)
	await wait(0.35)
	if not _skip: expect(not popup.visible, "Menu closed after selection")


func pick_in_menu(popup: PopupMenu, index: int, note_text := "") -> void:
	await pick_with_keys(popup, index, note_text)


## The same target several times (repeat taps, counting up).
func click_times(node: Control, times: int, gap := 0.18, note_text := "") -> void:
	if _skip: return
	say(note_text)
	if not is_instance_valid(node) or not node.is_visible_in_tree(): return
	await move_to(node)
	if _skip: return
	_check(node)
	for i in times:
		if _skip: return
		await tap()
		await wait(gap)


## Several targets, one after another.
func click_each(nodes: Array, gap := 0.35) -> void:
	for node in nodes:
		if node is Control: await click(node)
		await wait(gap)


## 🔑 **Types** — sends key events one character at a time. The focused input writes them down itself.
func type_text(node: Control, text: String, note_text := "") -> void:
	if _skip: return
	say(note_text)
	if not is_instance_valid(node): return
	await click(node)
	if _skip: return
	for index in text.length():
		if _skip or not is_instance_valid(node): return
		var letter := text.substr(index, 1)
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = letter.unicode_at(0)
		_push(key)
		var up := InputEventKey.new()
		up.pressed = false
		up.unicode = letter.unicode_at(0)
		_push(up)
		await wait(0.055)
	await wait(0.3)


## 🔑 **Drags** — passes through several points with the button held. Sliders and joysticks move by this.
func drag(path: Array, hold := 0.06) -> void:
	if _skip or path.is_empty(): return
	await move(path[0])
	if _skip: return
	_button(true)
	await wait(0.12)
	for index in range(1, path.size()):
		var from: Vector2 = path[index - 1]
		var to: Vector2 = path[index]
		var steps := maxi(2, int(from.distance_to(to) / 18.0))
		for step in range(1, steps + 1):
			if _skip: return
			_place(from.lerp(to, float(step) / steps))
			await wait(0.012)
		await wait(hold)
	_button(false)
	await wait(0.2)


## 🔑 Drags a slider to a target value, **taking hold of its knob first**.
func drag_slider(slider: Range, to_value: float, note_text := "") -> void:
	if _skip: return
	say(note_text)
	if not is_instance_valid(slider) or not slider.is_visible_in_tree(): return
	await reveal(slider)
	if _skip: return
	var rect := slider.get_global_rect()
	var span := maxf(0.001, slider.max_value - slider.min_value)
	var inset := 10.0
	var track := maxf(1.0, rect.size.x - inset * 2.0)
	var at := func(value: float) -> Vector2:
		var ratio := clampf((value - slider.min_value) / span, 0.0, 1.0)
		return Vector2(rect.position.x + inset + track * ratio, rect.get_center().y)
	await drag([at.call(slider.value), at.call(to_value)])


## 🔑 **Rolls** a list — a real wheel event. The scroll container follows by itself.
func scroll_by(node: Control, notches: int, note_text := "") -> void:
	if _skip: return
	say(note_text)
	if not is_instance_valid(node) or not node.is_visible_in_tree(): return
	await move(node.get_global_rect().get_center())
	for step in absi(notches):
		if _skip: return
		_wheel(1 if notches > 0 else -1)
		await wait(0.075)
	await wait(0.25)


## Pulls the cursor off screen — before the scene changes.
func rest() -> void:
	_place(HOME)
	if _down: _button(false)


## Assertions inspect actual widget state; they never drive a widget's callback.
func expect(condition: bool, description: String) -> void:
	if _skip or not verify: return
	checks += 1
	if condition: return
	failures.append(description)
	push_error("SIM CHECK FAILED: %s" % description)
