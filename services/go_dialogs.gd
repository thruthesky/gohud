## ❓ **Confirmation and alert windows.** One `await` line gets you the answer.
##
## ```gdscript
## var dialogs := GoDialogs.new()
## add_child(dialogs)
##
## if await dialogs.confirm("Delete character", "Really delete? This cannot be undone."):
##     delete_character()
##
## await dialogs.alert("Error", "Could not reach the server.")
## ```
##
## ## 🔑 An autoload makes it easy
## To use it anywhere in the game, add this script under Project Settings > Autoload. Then you can call it as
## `Dialogs.confirm(...)`. The addon **does not register it for you** — the project's autoload list
## belongs to the project.
##
## ## 🔑 Button layout — vertical · one row · auto
## `action_layout` decides how the two buttons are placed. The default `VERTICAL` is safe even for long translations,
## `HORIZONTAL` gives each half a row, and `AUTO` keeps one row **only when both labels fit on one line at half width**, folding to vertical otherwise.
## A short confirmation whose buttons took half the card drops below a third of it in one row.
## For one window only, call `set_next_action_layout()` just before opening — it reverts once that window closes.
##
## ## 🛑 Placeholders like `{name}` are filled with `args`
## `tr()` alone does not substitute them — the `{name}` in the translation stays on screen as written.
## In the confirmation text of an irreversible action this mistake is especially deadly. **Fill title and body with the same `args`.**
@tool
class_name GoDialogs
extends Node

## The window closed and an answer came out. Normally you use `await confirm(...)`.
signal answered(yes: bool)

## How the two buttons are placed.
enum ActionLayout { VERTICAL, HORIZONTAL, AUTO }

## The layer this window appears on. It has to be above the HUD.
@export var layer_index := 100

## Maximum card width (dp).
@export var max_width := 420.0

## 🪟 **Opacity** of the card background (0.0~1.0) — for dialogs only. **Negative means what the theme and config decide** (the default).
## 🔑 A window asking about an irreversible action is better off with a higher value — the less shows through, the more the question holds attention.
## 🛑 The name is kept the same as `GoSheet.alpha`·`GoSurface.alpha` — giving one meaning a different name and a
##    different unit per widget forces callers to memorize each one (`GoUi.surface_alpha()` is separate, a **lookup function**).
@export_range(-1.0, 1.0, 0.01) var alpha := -1.0:
	set(value):
		alpha = value
		if _surface != null: _surface.alpha = value

## Button layout — `VERTICAL` (default) · `HORIZONTAL` (one row) · `AUTO` (one row only when they fit).
@export var action_layout := ActionLayout.VERTICAL

## Gap between the buttons (dp). Negative means the `gap_small` token.
## 🛑 Do not lean on the container default — in some themes it is 0 and the two buttons touch.
@export var action_gap := -1

## **Should `confirm()` queue too** when a window is already up.
##
## 🛑 Off by default — **asking and telling are handled differently.**
##
## | | When a window is up | Why |
## |---|---|---|
## | `confirm()`·`confirm_key()` | **`false` right away** (default) | A question that gets pushed back collects a "yes" from a user who no longer knows what is being answered. Stacked confirmations cause mis-taps — better to treat it as never asked. The caller sees the `false` and knows |
## | `alert()`·`alert_key()` | **Always queues** | It cannot be undone. Being `-> void`, the caller has **no way** to learn "it was never seen", so error messages quietly evaporate (measured 2026-09-16: with two server errors back to back, nobody ever saw the second) |
##
## Turn this on and `confirm()` queues too — only on screens where not one question may be lost.
## 🔑 `alert()` queues **regardless** of this value. There is no option to throw a notice away.
@export var queue_when_busy := false

## How many may wait in the queue. Past that, **the oldest go first** (answered as cancel).
## 🛑 0 means unlimited — code hitting a dead server several times a second could pile up hundreds of windows.
@export var queue_limit := 8

## Gap between the body and the button row (dp). Negative means the surface's section gap as it is.
## 🔑 Wider than the gap between the buttons makes "the question" and "the choice" read as two blocks.
@export var body_gap := -1

var _layer: CanvasLayer
var _surface: GoSurface
var _body: Label
var _ok: Button
var _cancel: Button
## The button row. 🛑 Built **on first open** (`_ensure_actions`) — an autoloaded dialog joins the tree during
##    boot, so every node added here delays startup by that much.
var _actions: BoxContainer
var _actions_margin: MarginContainer
var _next_layout := -1
var _open := false
## Requests waiting their turn. 🛑 **One signal is not enough** — several waiters on `answered` would all receive
##    the same answer. Each request waits on the signal of its own ticket.
var _queue: Array[Dictionary] = []
## The ticket of whoever opened the window that is up.
var _ticket: Ticket


## One request's **own ticket**. The window is reused, so this is what tells "whose answer is this".
class Ticket extends RefCounted:
	signal done(yes: bool)
var _title_key := ""
var _body_key := ""
var _ok_key := ""
var _cancel_key := ""
var _extra := ""
var _args := {}
var _translate := true


## 🛑 The window is built in `_init` — `confirm()` must be callable before the node enters the tree.
func _init() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DialogLayer"
	_layer.layer = layer_index
	add_child(_layer)

	_surface = _make_surface()
	_surface.visible = false
	_surface.max_width = max_width
	_surface.fit_content = true
	# Close (X) counts as "confirm" on an alert that has only a confirm button, and as "cancel" on a question that has one.
	_surface.close_requested.connect(func() -> void: _finish(not _cancel.visible))
	_layer.add_child(_surface)

	_body = GoStyle.label("")
	_body.name = "Body"
	_surface.body.add_child(_body)

	# The two buttons start out in `footer`. Layout (vertical or one row) is handled by the button row built on first open.
	_surface.footer.visible = true
	_cancel = GoStyle.button_key(GoUi.text_key(&"cancel"), func() -> void: _finish(false))
	_cancel.name = "Cancel"
	_surface.footer.add_child(_cancel)
	_ok = GoStyle.button_key(GoUi.text_key(&"confirm"), func() -> void: _finish(true), GoStyle.Tone.PRIMARY)
	_ok.name = "Confirm"
	_surface.footer.add_child(_ok)
	_surface.initial_focus = _ok


func _ready() -> void:
	# Applies values that may have changed after `new()`.
	_layer.layer = layer_index
	_surface.max_width = max_width
	_surface.alpha = alpha
	# Rotating the screen changes the card width — check again whether one row fits.
	if not Engine.is_editor_hint(): get_viewport().size_changed.connect(_on_viewport_resized)


## Asks yes or no. `true` means the user pressed confirm.
##
## Turn `destructive` on and the confirm button is drawn in **the danger color**. For the irreversible — deleting, closing an account.
##
## 🛑 With a window already up it is `false` right away — two confirmations never stack.
func confirm(title: String, body: String, ok_text := "", cancel_text := "", extra := "", args := {},
		destructive := false) -> bool:
	return await _request(false, true, cancel_text if not cancel_text.is_empty() else GoUi.text(&"cancel"),
		destructive, title, body, ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"), extra, args)


## Asks by translation key. `destructive` works as in `confirm()`.
func confirm_key(title_key: String, body_key: String, ok_key := "", cancel_key := "",
		extra := "", args := {}, destructive := false) -> bool:
	return await _request(true, true, cancel_key if not cancel_key.is_empty() else GoUi.text_key(&"cancel"),
		destructive, title_key, body_key, ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"), extra, args)


## Tells the user something (one confirm button).
func alert(title: String, body: String, ok_text := "", extra := "", args := {}) -> void:
	await _request(false, false, "", false, title, body,
		ok_text if not ok_text.is_empty() else GoUi.text(&"confirm"), extra, args, true)


## Tells the user something by translation key.
func alert_key(title_key: String, body_key: String, ok_key := "", extra := "", args := {}) -> void:
	await _request(true, false, "", false, title_key, body_key,
		ok_key if not ok_key.is_empty() else GoUi.text_key(&"confirm"), extra, args, true)


func is_open() -> bool:
	return _open


## How many requests are waiting (not counting the one that is up).
func pending() -> int:
	return _queue.size()


## Answers everything waiting with **cancel** and empties the queue. Call it when leaving the screen (logout, scene change).
## 🛑 Code held by `await` never returns unless this is called.
func clear_pending() -> void:
	var waiting := _queue
	_queue = []
	for item in waiting: (item["ticket"] as Ticket).done.emit(false)


## The **single path** where all four entry points meet. Straight through when no window is up, queued when one is.
## `must_show` means **an alert** — it cannot be thrown away, so it queues regardless of `queue_when_busy`.
func _request(translate: bool, cancel_visible: bool, cancel_key: String, destructive: bool,
		title: String, body: String, ok: String, extra: String, args: Dictionary,
		must_show := false) -> bool:
	var ticket := Ticket.new()
	var item := {
		"translate": translate, "cancel_visible": cancel_visible, "cancel_key": cancel_key,
		"destructive": destructive, "title": title, "body": body, "ok": ok, "extra": extra,
		"args": args.duplicate(), "layout": _next_layout, "ticket": ticket,
	}
	# 🔑 A one-shot layout travels with **that request** — another request must not take it while this one waits in line.
	_next_layout = -1
	if not _open:
		_show(item)
		return await ticket.done
	if not must_show and not queue_when_busy:
		# 🛑 **Questions are dropped.** Stacked confirmations produce "a yes to who knows what".
		#    The caller receives `false` and can tell that it was never asked.
		return false
	_queue.append(item)
	# 🛑 On overflow **the oldest** is dropped. The recent one usually matters more (the last error is closer to the cause),
	#    and dropping the new one would hide what just happened for good.
	while _queue.size() > queue_limit and queue_limit > 0:
		var dropped: Dictionary = _queue.pop_front()
		(dropped["ticket"] as Ticket).done.emit(false)
	return await ticket.done


## Actually shows one queued item.
func _show(item: Dictionary) -> void:
	_translate = item["translate"]
	_cancel.visible = item["cancel_visible"]
	_cancel_key = item["cancel_key"]
	_next_layout = item["layout"]
	_ticket = item["ticket"]
	_tone(item["destructive"])
	_apply(item["title"], item["body"], item["ok"], item["extra"], item["args"])


## The window is free — if something is waiting, open it **on the next frame**.
## 🛑 Reopening in the same frame overlaps the closing animation: the window never blinks, only the text changes.
func _pump() -> void:
	if _open or _queue.is_empty(): return
	_show(_queue.pop_front())


## Changes the button layout for **just the next** window opened. It returns to `action_layout` once that window closes.
## 🔑 For pinning one screen to vertical, as with irreversible actions. Why not another argument — a subclass that
##    overrode `confirm()` would no longer match the argument count and compilation would break.
func set_next_action_layout(layout: ActionLayout) -> void:
	_next_layout = layout


## The confirm button's color. 🛑 **Set every time** — paint it in the danger color once and the next ordinary
##    confirmation comes up red too (one window is being reused).
func _tone(destructive: bool) -> void:
	GoStyle.style_button(_ok, GoStyle.Tone.DANGER_SOLID if destructive else GoStyle.Tone.PRIMARY)


func _apply(title: String, body: String, ok: String, extra: String, args: Dictionary) -> void:
	_title_key = title
	_body_key = body
	_ok_key = ok
	_extra = extra
	_args = args.duplicate()
	_ensure_actions()
	_retranslate()
	_open = true
	_surface.visible = true
	_surface.relayout()
	_place_actions()
	GoFeedback.opened()


func _retranslate() -> void:
	if _surface == null: return
	# 🛑 **The title is filled with `args` too** — filling only the body showed the title `Drop {item}?` literally (confirmed 2026-09-15).
	#    A filled title is already-translated text, so auto translation is turned off (`set_title`). This function refills it when the language changes.
	if _translate:
		if _args.is_empty(): _surface.set_title_key(_title_key)
		else: _surface.set_title(tr(_title_key).format(_args))
		# 🛑 A placeholder missing from `args` **stays in the translation** (`{name}` shows up as text).
		#    Any phrase that uses placeholders must be given those keys in `args`.
		_body.text = tr(_body_key).format(_args)
	else:
		_surface.set_title(_title_key.format(_args) if not _args.is_empty() else _title_key)
		_body.text = _body_key.format(_args) if not _args.is_empty() else _body_key
	if not _extra.is_empty(): _body.text += "\n" + _extra
	_ok.text = _ok_key
	_cancel.text = _cancel_key
	_ok.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if _translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	_cancel.auto_translate_mode = _ok.auto_translate_mode
	# 🛑 The window **is reused**, so the minimum width left by the previous label is cleared first — `fit_words` takes
	#    the larger of the old and new values, which kept the button wide even for a short one-word label after a long one.
	_ok.custom_minimum_size.x = 0.0
	_cancel.custom_minimum_size.x = 0.0
	# Text and translation settings changed, so the word-wrap rule is redone — otherwise it splits as `Don`/`e`.
	GoStyle.fit_words(_ok)
	GoStyle.fit_words(_cancel)
	# A language change while it is open changes the label widths — check again whether one row fits.
	if _open: _place_actions.call_deferred()


## Builds the button row once on first open and moves the two buttons into it.
## 🛑 The type of `footer` is not changed — many screens stack their own buttons in that same `footer`.
## 🛑 Wrapped once in a `MarginContainer` — with two children in `footer`, `footer`'s own separation cuts into the
##    gap after the body and `body_gap` no longer holds.
func _ensure_actions() -> void:
	if _actions != null: return
	_actions_margin = MarginContainer.new()
	_actions_margin.name = "ActionsBox"
	_actions_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.footer.add_child(_actions_margin)
	_actions = BoxContainer.new()
	_actions.name = "ActionsRow"
	_actions.vertical = true
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_margin.add_child(_actions)
	for button in [_cancel, _ok]:
		(button as Node).reparent(_actions)


## Sets the button row's direction and gap, and the gap after the body.
## 🛑 Called **only on open, on translation change and on window resize** — a fit-content surface runs `relayout`
##    every frame, and leaning on that could flip between one row and vertical every frame.
func _place_actions() -> void:
	if _actions == null or not _open: return
	var layout: int = _next_layout if _next_layout >= 0 else action_layout
	var gap := _action_gap()
	var one_row := false
	# With one button (an alert) one row and vertical are the same — it takes the full width.
	if _cancel.visible:
		one_row = layout == ActionLayout.HORIZONTAL or (layout == ActionLayout.AUTO and _fits_one_row(gap))
	_actions.vertical = not one_row
	_actions.add_theme_constant_override(&"separation", gap)
	var top := maxi(0, body_gap - _surface.section_gap()) if body_gap >= 0 else 0
	_actions_margin.add_theme_constant_override(&"margin_top", top)
	_surface.relayout()


## Do both labels fit **on one line at half width**?
## 🔑 The only inputs are the text width and the card's inner width — leaning on how things are laid out right now flips the verdict.
func _fits_one_row(gap: int) -> bool:
	var inner := _surface.card.size.x - float(_surface.content_inset()) * 2.0
	if inner <= 0.0: return false
	var half := (inner - float(gap)) * 0.5
	return _one_line_width(_ok) <= half and _one_line_width(_cancel) <= half


## The width of a button label **on one line** — text width + the stylebox's horizontal padding (the widest of the states).
## 🛑 Not measured with `get_combined_minimum_size()` — `fit_words` has already shrunk a multi-word button's minimum width to its longest word.
func _one_line_width(button: Button) -> float:
	var font := button.get_theme_font(&"font")
	if font == null: return INF
	var shown := button.atr(button.text) if button.is_inside_tree() else button.text
	var frame := 0.0
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		var face := button.get_theme_stylebox(state)
		if face != null: frame = maxf(frame, face.get_minimum_size().x)
	return font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button.get_theme_font_size(&"font_size")).x + frame + 2.0


func _action_gap() -> int:
	return action_gap if action_gap >= 0 else GoUi.metric(GoTheme.GAP_SMALL)


func _on_viewport_resized() -> void:
	# Decide after the surface has placed the card at its new size.
	if _open: _place_actions.call_deferred()


func _finish(yes: bool) -> void:
	if not _open: return
	_open = false
	_next_layout = -1   # the one-shot layout ends with this window
	_surface.visible = false
	# 🔔 Confirm and cancel are **a different sound and a different vibration** — whether an irreversible action was
	#    approved or backed out of has to be knowable without looking at the screen.
	if yes: GoFeedback.confirmed()
	else: GoFeedback.canceled()
	# 🛑 **The caller of this request is answered first.** `answered` is a broadcast that does not know who asked,
	#    so with several waiters it alone mixes the answers up.
	var ticket := _ticket
	_ticket = null
	answered.emit(yes)
	if ticket != null: ticket.done.emit(yes)
	# Next in line. Opening in the same frame overlaps the close and just looks like the text changed.
	if not _queue.is_empty(): _pump.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()
	# 🛑 When this node leaves on a scene change or `queue_free`, **the code that was waiting is released.** Otherwise
	#    logic held by `await dialogs.confirm(...)` never returns — the screen has already moved on while the
	#    previous screen's coroutine lives on, doing nothing.
	elif what == NOTIFICATION_EXIT_TREE:
		var ticket := _ticket
		_ticket = null
		_open = false
		if ticket != null: ticket.done.emit(false)
		clear_pending()


## Builds the dialog surface. 🔑 A host that wants a `GoSurface` subclass (old type-hint compatibility, say) overrides this in a subclass.
func _make_surface() -> GoSurface:
	return GoSurface.new()
