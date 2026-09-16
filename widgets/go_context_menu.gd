## 👆 **A long-press menu** — use, equip and drop on an item; whisper, invite and block on a player.
##
## ```gdscript
## GoContextMenu.attach(item_slot, [
##     {"text": "Use", "action": use},
##     {"text": "Equip", "action": equip},
##     {"separator": true},
##     {"text": "Drop", "action": drop, "danger": true},
## ])
##
## # When the list differs every time it is pressed — build it right before it opens
## GoContextMenu.attach(player_row, func() -> Array: return menu_for(player))
## ```
##
## ## 🔑 What this widget is worth is **the gesture**
## `PopupMenu` is already in the engine. What is missing is the handling: "opens on a long press on mobile, opens on
## right-click on desktop, **cancels the moment the finger moves**". Rewritten per screen, every screen judges it differently.
##
## ## 🛑 Dragging and long-pressing are told apart
## When a row inside a list is long-pressed, any movement of the finger means **scrolling**, not a menu.
## Moving past `slop` (12dp by default) cancels it — without this, a menu pops out every time the list is flicked.
##
## ## 🛑 A long press **needs to be taught**
## A feature nobody thinks to press on is a feature that does not exist. Pair it with an icon, a first-run coach mark
## (`GoCoachMark`), or a visible `⋯` button — never make a feature reachable by long press **alone**.
@tool
class_name GoContextMenu
extends RefCounted

## Seconds that count as a long press. 🔑 Matched to the Android default (0.5) — out of step with the device's habits it feels slow.
const HOLD_SECONDS := 0.5

## Move this far (dp) and it counts as a drag and is cancelled.
const SLOP_DP := 12.0

## The meta name that finds the attached handler.
const _ATTACHED := &"gohud_context_menu"


## Attaches a **long-press / right-click menu** to a control (calling it twice still attaches only one).
##
## `items` is an array, or a `Callable` that builds the array **each time it opens**.
## When the list depends on the situation (party leader or not), a `Callable` is required.
##
## | Key | Meaning |
## |---|---|
## | `text` | The item label (with `translate: true` when it is a translation key) |
## | `action` | The `Callable` to call when it is chosen |
## | `icon` | Icon name |
## | `disabled` | Greyed out and unselectable |
## | `danger` | In the danger color (drop, block, delete account) |
## | `separator` | `true` for one separator line |
## | `checked` | An item carrying a check mark |
static func attach(host: Control, items: Variant) -> void:
	if not is_instance_valid(host): return
	# 🛑 `get_meta(key, default)` prints an error when the key is missing — ask `has_meta` first.
	var holder: _Holder = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if holder == null:
		holder = _Holder.new()
		holder.host = host
		host.set_meta(_ATTACHED, holder)
		host.gui_input.connect(holder.on_input)
		# 🛑 The popup is cleared away with the control — left behind, the menu of a vanished item stays on screen.
		host.tree_exiting.connect(holder.dispose)
	holder.items = items


## Detaches the attached menu.
static func detach(host: Control) -> void:
	if not is_instance_valid(host): return
	var holder: _Holder = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if holder != null: holder.dispose()
	if host.has_meta(_ATTACHED): host.remove_meta(_ATTACHED)


## Opens the menu **right away** at that spot (without waiting for a long press). For the `⋯` button.
static func open_at(host: Control, items: Variant, where := Vector2.INF) -> PopupMenu:
	if not is_instance_valid(host) or not host.is_inside_tree(): return null
	var entries := _entries(items)
	if entries.is_empty(): return null
	var popup := _build(entries)
	host.add_child(popup)
	GoStyle.style_popup(popup)
	var spot := where if where.is_finite() else host.get_global_rect().get_center()
	# 🛑 When subwindows are **embedded** (`gui_embed_subwindows`, the Godot 4 default) popup coordinates are relative to the
	#    viewport — adding the OS window position on top flings the popup off screen. It is added only when they are not embedded.
	var window := host.get_window()
	var embedded := window == null or window.gui_embed_subwindows
	var origin := Vector2i.ZERO if embedded else window.position
	popup.position = Vector2i(spot.round()) + origin
	popup.reset_size()
	popup.popup()
	GoFeedback.opened()
	popup.popup_hide.connect(popup.queue_free, CONNECT_ONE_SHOT)
	return popup


## Turns `items` — array or `Callable` — into **the list as it stands right now**.
static func _entries(items: Variant) -> Array:
	if items is Callable:
		var made: Variant = (items as Callable).call()
		return made if made is Array else []
	return items if items is Array else []


static func _build(entries: Array) -> PopupMenu:
	var popup := PopupMenu.new()
	popup.name = "ContextMenu"
	var actions: Array[Callable] = []
	for entry in entries:
		var row: Dictionary = entry if entry is Dictionary else {"text": str(entry)}
		if bool(row.get("separator", false)):
			popup.add_separator()
			actions.append(Callable())
			continue
		var words := str(row.get("text", ""))
		var index := popup.item_count
		if bool(row.get("checked", false)):
			popup.add_check_item(words, index)
			popup.set_item_checked(index, true)
		else:
			popup.add_item(words, index)
		# 🛑 Translation is decided **per item** — things that must not be translated, such as player names, are mixed in.
		popup.set_item_auto_translate_mode(index,
			Node.AUTO_TRANSLATE_MODE_ALWAYS if bool(row.get("translate", false)) else Node.AUTO_TRANSLATE_MODE_DISABLED)
		if row.has("icon"):
			var texture := GoUi.icons().texture(StringName(row["icon"]))
			if texture != null: popup.set_item_icon(index, texture)
		if bool(row.get("disabled", false)): popup.set_item_disabled(index, true)
		# An irreversible item has to be tellable at a glance, or mis-taps do not go down.
		# 🛑 `add_theme_color_override` applies to **the whole menu** — trying to make one item danger-colored stains
		#    every item. `PopupMenu` offers no per-item text color.
		# 🛑 That said, **do not concatenate a symbol in front of the label** — the label may be a translation key, and
		#    then the engine looks up `"⚠ menu_drop"` whole, fails, and the key shows on screen as it is
		#    (`go_table.gd` hit the same trap with its sort arrows). **Finish the translation first**, then append.
		# ♿ A symbol is a shape rather than a color, so it reads the same for people with color vision deficiency.
		if bool(row.get("danger", false)):
			# 🛑 `tr()` is an **instance** method of `Object` and cannot be called from a `static func` — calling it dies
			#    at parse time, and every screen and test that references this file fails to load at all.
			#    `TranslationServer.translate()` is a singleton and can be called here, and `GoUi.text()` uses
			#    the same thing (2026-09-16: written with `tr()` and carried all the way to a commit, caught by another session).
			var shown := TranslationServer.translate(words) if bool(row.get("translate", false)) else words
			popup.set_item_text(index, "⚠ " + shown)
			popup.set_item_auto_translate_mode(index, Node.AUTO_TRANSLATE_MODE_DISABLED)
			popup.set_item_metadata(index, &"danger")
		actions.append(row.get("action", Callable()))
	popup.id_pressed.connect(func(id: int) -> void:
		if id < 0 or id >= actions.size(): return
		var action := actions[id]
		GoFeedback.tapped()
		if action.is_valid(): action.call())
	return popup


## A small state machine that attaches to one control and times the long press.
## 🛑 It is a `RefCounted` — no node is added. Changing the host's tree shape would shake that screen's layout.
class _Holder extends RefCounted:
	var host: Control
	var items: Variant = []
	var _pressed_at := Vector2.ZERO
	var _timer: SceneTreeTimer
	var _index := -1

	func on_input(event: InputEvent) -> void:
		if not is_instance_valid(host): return
		# Desktop — right-click opens it right there, at once.
		var mouse := event as InputEventMouseButton
		if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
			host.accept_event()
			GoContextMenu.open_at(host, items, host.get_global_mouse_position())
			return
		# Mobile — timed while the press is held.
		var touch := event as InputEventScreenTouch
		if touch != null:
			if touch.pressed and _index < 0:
				_index = touch.index
				_begin(touch.position)
			elif not touch.pressed and touch.index == _index:
				_cancel()
			return
		var drag := event as InputEventScreenDrag
		if drag != null and drag.index == _index:
			# 🛑 The finger moved — this is **scrolling**. Without cancelling here, a menu pops out every time
			#    the list is flicked.
			if drag.position.distance_to(_pressed_at) > GoContextMenu.SLOP_DP: _cancel()
			return
		# Holding the left button on desktop counts the same — it makes testing during development easy.
		if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and _index < 0:
				_index = -2
				_begin(mouse.position)
			elif not mouse.pressed and _index == -2:
				_cancel()

	func _begin(at: Vector2) -> void:
		_pressed_at = at
		var tree := host.get_tree()
		if tree == null: return
		_timer = tree.create_timer(GoContextMenu.HOLD_SECONDS)
		_timer.timeout.connect(_fire.bind(at), CONNECT_ONE_SHOT)

	func _fire(at: Vector2) -> void:
		if _index < 0 and _index != -2: return
		if not is_instance_valid(host) or not host.is_inside_tree(): return
		_index = -1
		# 🔔 A long press **has to be reported through the fingertip** — the screen may not be being watched, and
		#    without knowing "when it opened" there is no telling when to let go.
		GoFeedback.tapped()
		GoContextMenu.open_at(host, items, host.get_global_transform() * at)

	func _cancel() -> void:
		_index = -1
		if _timer != null and _timer.time_left > 0.0:
			# A timer cannot be cancelled — the connection is cut so that firing does nothing.
			for connection in _timer.timeout.get_connections():
				_timer.timeout.disconnect(connection.callable)
		_timer = null

	func dispose() -> void:
		_cancel()
		if not is_instance_valid(host): return
		if host.gui_input.is_connected(on_input): host.gui_input.disconnect(on_input)
		if host.tree_exiting.is_connected(dispose): host.tree_exiting.disconnect(dispose)
		# 🛑 **The meta is removed too.** Left behind, putting that control back in the tree and calling `attach()`
		#    reads as "already attached" and keeps the dead handler, so a long press does nothing.
		if host.has_meta(GoContextMenu._ATTACHED): host.remove_meta(GoContextMenu._ATTACHED)
