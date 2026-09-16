## 🍞 **Snackbar** — rises briefly from the bottom of the screen to say something, and can carry one undo button.
##
## ```gdscript
## var snack := GoSnackbar.new()
## add_child(snack)
##
## snack.show_text("Saved", GoTheme.SUCCESS)
## snack.show_text("Could not reach the server", GoTheme.DANGER)
##
## # Offer a chance to undo — 0 when pressed, -1 when it times out
## if await snack.post({"text": "Item dropped", "actions": ["Undo"]}) == 0:
##     restore_item()
## ```
##
## ## 🔑 An autoload makes it easy
## To use it anywhere in the game, add this script under Project Settings > Autoload. Then you can call
## `Snackbar.show_text(...)`. The addon **does not register it for you** — the project's autoload list
## belongs to the project.
##
## ## 🛑 How it differs from `GoNotice`
## | | `GoNotice` | `GoSnackbar` |
## |---|---|---|
## | Place | **The screen decides** — the host lays out which slot it goes in | **It places itself** — bottom of the screen, above the safe area and keyboard |
## | Layer | The same layer as the parent it was added to | Its own `CanvasLayer` (above the HUD) |
## | Input | 🛑 **Never takes any** (`focus_behavior_recursive` is off) | Buttons **can be pressed** |
## | On overlap | A new message overwrites the previous one | **They queue up in turn** |
## | Used for | A fixed notice slot in one corner of the HUD | An answer to an action — save, delete, error, undo |
##
## So when an undo button is needed, this is the one. `GoNotice` **structurally** cannot hold a button.
##
## ## 🛑 Not the place to get confirmation
## A snackbar **dismisses itself** — which means the user may never see it. Approval for irreversible actions and
## errors that must be read are asked with `GoDialogs.confirm()`·`alert()`. Buttons put here are only the kind
## that are fine to ignore (undo, details, retry).
@tool
class_name GoSnackbar
extends Node

## One has gone away. `index` is the button that was pressed (-1 = timed out or closed).
signal closed(index: int)

## Where it appears.
enum Placement {
	BOTTOM,  ## Bottom of the screen (default) — within thumb reach, so the undo button is easy to press.
	TOP,     ## Top of the screen — for HUDs whose bottom is full of joystick and quick slots.
}

## Appears on this layer. Above the HUD and below dialogs (`GoDialogs` defaults to 100) is the natural spot.
## 🛑 Put it above dialogs and the snackbar covers the confirmation window.
@export var layer_index := 90

## Maximum card width (dp). On a wide screen a line stretched edge to edge is hard for the eye to follow.
@export var max_width := 560.0

## Distance kept from the screen edge (dp). Negative means the `screen_margin` token.
@export var margin := -1.0

## Whether it appears at the top or the bottom.
@export var placement := Placement.BOTTOM

## How many may wait in the queue. Past that, **the oldest go first**. 0 means unlimited.
## 🛑 Do not leave it unlimited — network code failing several times a second piles up minutes of notices.
@export var queue_limit := 4

## Identical text arriving back to back **counts as one** (code retrying a dead server pours out the same error).
## When the text matches what is showing, only the timer is refilled.
@export var merge_repeats := true

## How long appearing and disappearing takes (seconds). Ignored, and instant, when `GoConfig.reduce_motion` is on.
@export var motion_seconds := 0.18

## How far it slides up from the bottom (or down from the top) (dp).
@export var slide_dp := 24.0

## Can pressing the card close it? 🔑 For clearing a button-less notice quickly.
## 🛑 A snackbar with buttons does not close on tap — reaching for undo must not dismiss it instead.
@export var tap_to_dismiss := true

var _layer: CanvasLayer
var _root: Control
var _card: PanelContainer
var _row: HBoxContainer
var _glyph: Control
var _lines: VBoxContainer
var _title: Label
var _body: Label
var _actions: Array[Button] = []
var _close: GoIconButton

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _ticket: Ticket
var _remaining := 0.0
var _tween: Tween
var _shown := false


## One request's **own ticket**. The card is reused, so this is what tells "whose answer is this".
## 🛑 One signal is not enough — several waiters on `closed` would all receive the same answer.
class Ticket extends RefCounted:
	signal done(index: int)


## 🛑 The card is built in `_init` — `show_text()` must be callable before the node enters the tree.
## 🪟 **Opacity of the panel background** (0.0~1.0) — for this one only. Negative means what the theme and config decide.
## 🛑 Only the background thins out — text and icons stay crisp.
## 🔑 A snackbar sits briefly at the bottom carrying **the one line that must not be missed** — raise the value when what is behind is busy.
var alpha := -1.0:
	set(value):
		alpha = value
		_restyle_card()


func _init() -> void:
	name = "Snackbar"
	_layer = CanvasLayer.new()
	_layer.name = "SnackbarLayer"
	_layer.layer = layer_index
	add_child(_layer)

	# 🛑 The backdrop **passes input straight through** — the game must not stall while a snackbar is up.
	_root = Control.new()
	_root.name = "SnackbarRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The safe area is **physical** — the notch does not move to the other side just because the language is Arabic.
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_layer.add_child(_root)

	_card = PanelContainer.new()
	_card.name = "Snackbar"
	_card.visible = false
	_card.gui_input.connect(_card_input)
	# 🔑 Follows the height even when the content changes after it is up (a language swap). `DEFERRED`, so it never cuts into layout.
	_card.minimum_size_changed.connect(_refit, CONNECT_DEFERRED)
	_root.add_child(_card)

	var pad := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	pad.name = "Pad"
	_card.add_child(pad)

	_row = GoStyle.row()
	_row.name = "Row"
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	pad.add_child(_row)

	# Slot for the icon — hidden when empty.
	_glyph = Control.new()
	_glyph.name = "Glyph"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.visible = false
	_row.add_child(_glyph)

	_lines = GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	_lines.name = "Lines"
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_lines)

	_title = GoStyle.label("", GoTheme.ROLE_BUTTON)
	_title.name = "Title"
	_title.visible = false
	_lines.add_child(_title)

	_body = GoStyle.label("", GoTheme.ROLE_BODY)
	_body.name = "Message"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.add_child(_body)


func _ready() -> void:
	_layer.layer = layer_index
	_card.add_theme_stylebox_override(&"panel", _face(Color.TRANSPARENT))
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_relayout)
	GoUi.watch(_on_ui_changed)
	set_process(false)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	# 🛑 **Releases** the code that was waiting when the scene is torn down — otherwise game logic held by
	#    `await post(...)` never returns (once this node is gone, nobody answers the ticket).
	clear()


# ── Showing ────────────────────────────────────────────────────────────

## A phrase to show as it is. `tone` is the name of a color token (`GoTheme.SUCCESS`, …).
## A negative `seconds` means the `notice_duration_ms` token.
func show_text(message: String, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	await post({"text": message, "tone": tone, "seconds": seconds})


## Shows it by translation key. `args` fills placeholders such as `{name}`.
## 🛑 `tr()` alone does not substitute placeholders — the `{name}` in the translation stays on screen as written.
func show_key(key: String, args := {}, tone := GoTheme.TEXT, seconds := -1.0) -> void:
	await post({"text": key, "translate": true, "args": args, "tone": tone, "seconds": seconds})


## Shows one snackbar and returns **the index of the button pressed** (-1 = timed out or closed).
##
## | Key | Meaning | Default |
## |---|---|---|
## | `text` | The body. A translation key when `translate` | `""` |
## | `title` | A bold first line. Leave it empty for a single-line snackbar | `""` |
## | `tone` | Color token (`GoTheme.DANGER`, …) | `GoTheme.TEXT` |
## | `icon` | A name from the icon set | none |
## | `actions` | Buttons — a label (`String`) or `{"text":…, "action": Callable}` | none |
## | `closable` | Adds a close (×) button | `false` |
## | `seconds` | Lifetime. Negative means the token, `0` means **it never goes away** (a button has to close it) | `-1` |
## | `translate` | Treats `text`·`title` and button labels as translation keys | `false` |
## | `args` | Placeholder values | `{}` |
##
## 🛑 Use `seconds: 0` **only when there is a button** — with no way to close it, it stays on screen forever.
func post(options: Dictionary) -> int:
	var item := _normalize(options)
	# Identical text back to back counts as one — only the timer is refilled, nothing new is queued.
	# 🛑 **The standing one's answer is handed down.** Returning `-1` right here would make an `await post(...)`
	#    that was waiting for undo receive "timed out" while the snackbar is still up and take the wrong branch
	#    (pointed out 2026-09-16). A merged request must get **the same answer as the one already showing**.
	if merge_repeats and _shown and not _current.is_empty() \
			and _current.get("text", "") == item["text"] and _current.get("title", "") == item["title"]:
		_remaining = float(item["seconds"])
		set_process(_remaining > 0.0)
		var standing: Ticket = _ticket
		if standing == null: return -1
		return await standing.done
	var ticket: Ticket = item["ticket"]
	if not _shown:
		_present(item)
		return await ticket.done
	_queue.append(item)
	# 🛑 On overflow **the oldest** is dropped — what just happened usually matters more.
	while queue_limit > 0 and _queue.size() > queue_limit:
		var dropped: Dictionary = _queue.pop_front()
		(dropped["ticket"] as Ticket).done.emit(-1)
	return await ticket.done


## Clears what is showing right away. If something is waiting, the next one comes up.
func dismiss() -> void:
	if _shown: _finish(-1)


## Clears **everything**, showing and waiting. Call it when leaving the screen (logout, scene change).
## 🛑 Code held by `await` never returns unless this is called.
func clear() -> void:
	var waiting := _queue
	_queue = []
	for item in waiting: (item["ticket"] as Ticket).done.emit(-1)
	dismiss()


func is_showing() -> bool:
	return _shown


## How many are waiting in the queue (not counting the one showing).
func pending() -> int:
	return _queue.size()


# ── Assembly ───────────────────────────────────────────────────────────

## Fills in the keys that came in to make **a complete** set.
func _normalize(options: Dictionary) -> Dictionary:
	var seconds := float(options.get("seconds", -1.0))
	if seconds < 0.0: seconds = float(GoUi.metric(GoTheme.NOTICE_DURATION_MS)) / 1000.0
	var actions: Array = []
	for entry in options.get("actions", []):
		if entry is String or entry is StringName: actions.append({"text": String(entry), "action": Callable()})
		elif entry is Dictionary: actions.append({"text": str(entry.get("text", "")), "action": entry.get("action", Callable())})
	return {
		"text": str(options.get("text", "")),
		"title": str(options.get("title", "")),
		"tone": options.get("tone", GoTheme.TEXT),
		"icon": StringName(options.get("icon", &"")),
		"actions": actions,
		"closable": bool(options.get("closable", false)),
		"seconds": seconds,
		"translate": bool(options.get("translate", false)),
		"args": (options.get("args", {}) as Dictionary).duplicate(),
		"ticket": Ticket.new(),
	}


## Puts one set on the actual card and raises it.
func _present(item: Dictionary) -> void:
	_current = item
	_ticket = item["ticket"]
	_shown = true

	var ink := GoUi.color(item["tone"])
	_card.add_theme_stylebox_override(&"panel", _face(ink if item["tone"] != GoTheme.TEXT else Color.TRANSPARENT))
	_retranslate()

	# Icon — when the set does not know the name, the slot is quietly left empty (no magenta square).
	for child in _glyph.get_children(): child.queue_free()
	var icon_name: StringName = item["icon"]
	# 🛑 `node()` returns **an empty control** even for names it does not know (not null) — adding it anyway leaves
	#    a blank gap in an icon-less snackbar. The slot is made only for a name the set knows.
	_glyph.visible = not icon_name.is_empty() and GoUi.icons().has_icon(icon_name)
	if _glyph.visible:
		var px := GoUi.metric(GoTheme.ICON_SIZE)
		var node := GoUi.icons().node(icon_name, px, ink)
		_glyph.custom_minimum_size = Vector2(px, px)
		_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.add_child(node)

	_build_actions(item)

	# 🔑 A plain notice with no buttons **passes input through** — a snackbar being up must not block what is under it.
	var interactive: bool = not _actions.is_empty() or item["closable"] or tap_to_dismiss
	_card.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

	# ♿ A screen reader reads the card as one chunk — title and body are joined and handed over as its name.
	_card.accessibility_name = GoUi.spoken([item["title"], item["text"]])

	_remaining = float(item["seconds"])
	# 🛑 Raised **hidden for one frame**. The minimum height of a wrapping body is only right the frame **after**
	#    the width is settled — measured in the same frame it comes out as the height of text folded one character
	#    per line at the initial width (0), making the card four times too tall (measured 2026-09-16: a card that should have been 55 was 211).
	_card.modulate.a = 0.0
	_card.visible = true
	_relayout()
	set_process(_remaining > 0.0)
	_settle()
	GoFeedback.opened()


## **Actually waits** for the width to reach the children, lays out, and only then raises the card.
##
## 🛑 `call_deferred` is not enough — it runs at the end of the same frame, and the minimum height is still
##    **the value folded at the initial width (0)** (measured 2026-09-16: `min=(33, 211)` at that moment, the true value being 55).
##    Even setting `size.y = 0` lets the engine pull it back up to that 211, so the oversized card sets in.
##    The frame has to actually pass so the minimum height is recomputed at the new width.
## 🔑 While waiting, the card is at `modulate.a = 0`, so **the wrong size never shows on screen.**
func _settle() -> void:
	var tree := get_tree()
	if tree == null:
		_animate(true)
		return
	await tree.process_frame
	await tree.process_frame
	if not _shown or not is_instance_valid(_card): return
	_relayout()
	_animate(true)


## Rebuilds the button row. 🛑 **Never reused** — a callback left over from the previous snackbar would undo the wrong thing.
func _build_actions(item: Dictionary) -> void:
	for node in _actions: node.queue_free()
	_actions.clear()
	if is_instance_valid(_close):
		_close.queue_free()
		_close = null

	var entries: Array = item["actions"]
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var picked := index
		var node := GoStyle.button(str(entry["text"]), func() -> void:
			var action: Callable = entry["action"]
			if action.is_valid(): action.call()
			_finish(picked), GoStyle.Tone.BARE)
		node.name = "Action%d" % index
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# 🛑 `Tone.BARE` **sets no minimum height** (`GoStyle.style_button` returns before that).
		#    Undo is the very reason a snackbar exists, so it gets 48dp directly (measured 2026-09-16: the minimum was 0).
		node.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
		# The undo label takes the tone color — set apart from the body, it reads as "something you can press".
		node.add_theme_color_override(&"font_color", GoUi.color(GoTheme.ACCENT))
		_actions.append(node)
		_row.add_child(node)

	if item["closable"]:
		_close = GoIconButton.new()
		_close.name = "Close"
		_close.icon_name = &"close"
		_close.tooltip_text_name = &"close"
		_close.pressed.connect(func() -> void: _finish(-1))
		_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(_close)


## Refills the current text (a language change comes down the same path).
func _retranslate() -> void:
	if _current.is_empty(): return
	var translate: bool = _current["translate"]
	var args: Dictionary = _current["args"]
	var title: String = _current["title"]
	_title.visible = not title.is_empty()
	if _title.visible:
		_title.text = tr(title).format(args) if translate else (title.format(args) if not args.is_empty() else title)
		_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var body: String = _current["text"]
	_body.text = tr(body).format(args) if translate else (body.format(args) if not args.is_empty() else body)
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var ink := GoUi.color(_current["tone"])
	GoStyle.typography(_body, GoTheme.ROLE_BODY, ink)
	if _title.visible: GoStyle.typography(_title, GoTheme.ROLE_BUTTON, ink)
	# Button labels can be translation keys too.
	var entries: Array = _current["actions"]
	for index in mini(_actions.size(), entries.size()):
		var text := str((entries[index] as Dictionary)["text"])
		_actions[index].text = tr(text) if translate else text


# ── Placement ──────────────────────────────────────────────────────────

## Places it centered within the given width, above the safe area and the virtual keyboard.
func _relayout() -> void:
	if _card == null or not _card.visible or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	var runtime := GoUi.runtime()
	var keyboard: int = runtime.keyboard_height() if runtime != null and runtime.has_method(&"keyboard_height") else 0
	var area := GoSafeArea.usable_rect_with_keyboard(window, keyboard)
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN)) if margin < 0.0 else margin

	var limit := maxf(0.0, area.size.x - edge * 2.0)
	var width := minf(limit, max_width) if max_width > 0.0 else limit
	# 🛑 The height is **not measured; 0 is given** — the engine pulls it up to the minimum height on the spot.
	#    A measured value would be taken while the width is still 0, baking in the height of text folded one character
	#    per line, and **that large value stays** even after the width settles and the minimum height shrinks (`size`
	#    is kept when it is larger than the minimum — measured 2026-09-16: a card that should have been 55 was 211 for eight frames straight).
	_card.size.x = width
	_card.size.y = 0.0

	var x := area.position.x + (area.size.x - width) * 0.5
	var y := area.end.y - edge - _card.size.y if placement == Placement.BOTTOM else area.position.y + edge
	# 🛑 Integers — a fractional position makes the card size 183.99997 and the body loses 1px.
	_card.position = Vector2(x, y).round()


## The content changed and the minimum height with it — lay out again.
## 🛑 Not touched while it is rising — the tween holds `position`, and the two would push each other around.
func _refit() -> void:
	if not _shown or is_instance_valid(_tween) and _tween.is_valid() and _tween.is_running(): return
	_relayout()


func _face(accent: Color) -> StyleBox:
	return GoUi.skin().notice_box(accent, true, alpha)


## The rise and the fall. Under `reduce_motion` it simply appears and disappears in place.
func _animate(shown: bool) -> void:
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	var rest := _card.position
	if GoUi.config.reduce_motion or motion_seconds <= 0.0 or not is_inside_tree():
		_card.modulate.a = 1.0 if shown else 0.0
		if not shown: _card.visible = false
		return
	var away := rest + Vector2(0.0, slide_dp if placement == Placement.BOTTOM else -slide_dp)
	_tween = create_tween().set_parallel(true)
	if shown:
		_card.position = away
		_card.modulate.a = 0.0
		_tween.tween_property(_card, "position", rest, motion_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_card, "modulate:a", 1.0, motion_seconds)
	else:
		_tween.tween_property(_card, "position", away, motion_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(_card, "modulate:a", 0.0, motion_seconds)
		_tween.chain().tween_callback(func() -> void: _card.visible = false)


# ── Finishing ──────────────────────────────────────────────────────────

func _finish(index: int) -> void:
	if not _shown: return
	_shown = false
	set_process(false)
	_animate(false)
	if index >= 0: GoFeedback.tapped()
	else: GoFeedback.closed()
	var ticket := _ticket
	_ticket = null
	_current = {}
	closed.emit(index)
	if ticket != null: ticket.done.emit(index)
	# Next in line — raised after the fall has finished. Opening in the same frame just looks like the text changed.
	if _queue.is_empty(): return
	var delay := 0.0 if GoUi.config.reduce_motion else motion_seconds
	get_tree().create_timer(delay).timeout.connect(_pump, CONNECT_ONE_SHOT)


## Press the card to close it. 🛑 **Not while there are buttons** — a near miss while reaching for undo would
##    take the chance to undo away. Input the buttons themselves receive never reaches here.
func _card_input(event: InputEvent) -> void:
	if not tap_to_dismiss or not _actions.is_empty(): return
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not tapped: return
	_card.accept_event()
	_finish(-1)


func _pump() -> void:
	if _shown or _queue.is_empty(): return
	_present(_queue.pop_front())


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_remaining -= delta
	if _remaining > 0.0: return
	_finish(-1)


## Reapplies the card panel **in the semantic color of whatever is showing** (no color on an empty card).
##
## 🛑 Calling `_face(Color.TRANSPARENT)` outright where the panel is reapplied is wrong — **the border color of a
##    danger notice that is up would vanish.** The color lives in the `tone` of the item being shown, so it has to be read
##    from there, and that one line is easy to forget, which is why it was gathered here (it really happened in the `alpha` setter, 2026-09-16).
func _restyle_card() -> void:
	if _card == null: return
	var accent := Color.TRANSPARENT
	if not _current.is_empty() and _current["tone"] != GoTheme.TEXT:
		accent = GoUi.color(_current["tone"])
	_card.add_theme_stylebox_override(&"panel", _face(accent))


func _on_ui_changed() -> void:
	_restyle_card()
	if _current.is_empty(): return
	_retranslate()
	_relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()
