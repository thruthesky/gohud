## 💬 **A small card that opens attached to something** — item details, skill descriptions, stat comparisons.
##
## ```gdscript
## # Press a slot and the description opens beside it
## GoPopover.open(slot, GoStyle.item_card(spec, false))   # unframed — the popover is the frame
##
## # With a title, and not closing on an outside tap
## GoPopover.open(button, body, {"title": "Upgrade odds", "dismissable": false})
##
## # Wait until it closes
## await GoPopover.open(slot, body).close_requested
## ```
##
## ## 🔑 The problem it solves is **assembly**
## `GoSurface` already has `Placement.ANCHOR`. But using it meant writing out the layer, the surface, wiring
## the anchor and cleaning up on close every single time — the most common job in a game UI, and ten lines
## each time. Here it is **one line**.
##
## ## 🛑 It is not a tooltip
## Something that only appears while a mouse rests on it (hover) **does not exist on a touch device.** A phone
## has no "resting on it", so information kept only there is never seen by a mobile player. That is why this
## one **opens on a press and closes on a press.**
##
## ## 🛑 Do not put irreversible actions in here
## An outside tap closes it (by default). Confirming a sale or a salvage is `GoDialogs.confirm()`.
@tool
class_name GoPopover
extends RefCounted

## It opens on this layer. Above the HUD, below the dialogs.
const LAYER := 95

## The one currently open — **one at a time**. Opening a new one closes the previous.
static var _open: CanvasLayer
## The surface inside that layer. Held separately so `close_requested` can be emitted on close.
static var _open_surface: GoSurface


## Open a card holding `content` beside `anchor`. What comes back is that `GoSurface`
## (await its `closed`, or close it with `request_close()`).
##
## | Field | Meaning | Default |
## |---|---|---|
## | `title` | Header text. Empty means no header row | `""` |
## | `translate` | Treat the title as a translation key | `false` |
## | `width` | Card width (dp) | 320 |
## | `max_height` | Maximum card height (dp) | 520 |
## | `dismissable` | An outside tap closes it | `true` |
## | `compact` | Tighter padding — for a one or two line description | `false` |
## | `alpha` | Opacity of the card ground (0.0~1.0). Negative uses the theme and settings value | `-1.0` |
##
## 🛑 **Only one is open at a time.** Press slots in succession and the previous closes as the new one opens —
##    let them stack and the screen fills with cards with no way to tell which belongs to which slot.
static func open(anchor: Control, content: Control, options := {}) -> GoSurface:
	close()
	if not is_instance_valid(anchor) or not anchor.is_inside_tree(): return null

	var layer := CanvasLayer.new()
	layer.name = "PopoverLayer"
	layer.layer = int(options.get("layer", LAYER))

	var surface := GoSurface.new()
	surface.placement = GoSurface.Placement.ANCHOR
	surface.anchor_control = anchor
	surface.anchor_width = float(options.get("width", surface.anchor_width))
	surface.anchor_max_height = float(options.get("max_height", surface.anchor_max_height))
	surface.fit_content = true
	surface.dismiss_on_scrim = bool(options.get("dismissable", true))
	# 🔑 Keep the scrim **transparent** — if a card opened to read some information darkens the game screen,
	#    the very screen being compared against is gone. Leave the scrim only its job of catching outside taps.
	surface.scrim_transparent = true
	surface.compact = bool(options.get("compact", false))
	# 🔑 This card was opened **to compare** information — the screen behind often has to stay visible, so leave it per-popover.
	surface.alpha = float(options.get("alpha", -1.0))
	var title := str(options.get("title", ""))
	surface.show_header = not title.is_empty()

	layer.add_child(surface)
	# 🛑 Add it to **the same tree** as the anchor — in a game with several windows (a separate chat window),
	#    attaching to a different window throws the coordinates off and the card opens in the wrong place.
	anchor.get_tree().root.add_child(layer)
	_open = layer

	if not title.is_empty():
		if bool(options.get("translate", false)): surface.set_title_key(title)
		else: surface.set_title(title)
	if is_instance_valid(content): surface.body.add_child(content)

	_open_surface = surface
	# 🔑 There are two ways in but only one job to do — write it twice and one copy gets fixed while the other does not.
	# 🛑 Hold the layer through a **weak reference**. If one of the two signals frees the layer first, whatever the
	#    lambda captured is already gone when the other fires later and the engine prints `Lambda capture … was freed`
	#    (found in the test logs 2026-09-16 — the checks passed while the errors piled up, which made it hard to trace).
	var held := weakref(layer)
	var dispose := func() -> void:
		var node := held.get_ref() as CanvasLayer
		if is_instance_valid(node): node.queue_free()
		if _open != null and _open == node:
			_open = null
			_open_surface = null
	surface.close_requested.connect(dispose, CONNECT_ONE_SHOT)
	# If the anchor goes (the item was dropped) the card goes with it — no description left for something that no longer exists.
	anchor.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	surface.visible = true
	surface.relayout()
	GoFeedback.opened()
	return surface


## Close it if it is open.
## 🛑 **Emit `close_requested`, then close.** The documentation recommends `await GoPopover.open(...).close_requested`,
##    and simply freeing the layer leaves that `await` hanging forever — and because of the "one at a time" rule,
##    `close()` followed by reopening is **the normal path** (measured 2026-09-16: the signal never arrived).
static func close() -> void:
	var surface := _open_surface
	_open_surface = null
	if is_instance_valid(surface): surface.close_requested.emit()
	if is_instance_valid(_open): _open.queue_free()
	_open = null


static func is_open() -> bool:
	return is_instance_valid(_open)
