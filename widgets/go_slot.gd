## 🎒 **One quick slot** — an icon, a quantity, a cooldown and a shortcut key on **a single panel**.
##
## ## 🛑 There is only one panel
## Hanging a quantity badge, a key badge and a timer separately off a small circle gives every slot a different
## real width, so the row wobbles and the screen gets busy. That is why every element stays **within this panel's width**.
##
## ```gdscript
## var slot := GoSlot.new()
## slot.icon_name = GoIconSet.POTION
## slot.accent = GoUi.color(GoTheme.DANGER)
## slot.quantity = 12
## slot.shortcut_label = "1"
## slot.set_cooldown(3.0, 8.0)     # 3 of 8 seconds left
## ```
##
## ## 🔑 The visual size and the touch size differ
## Pack the slots tightly and the 48dp touch boxes overlap their neighbours. The overlap goes to **the slot whose
## center is closer** — just put them in each other's `touch_peers`.
@tool
class_name GoSlot
extends Button

## The quantity is not known yet — shows `…` (waiting on the server).
const UNKNOWN := -1
## This slot has no notion of quantity — the quantity row is not drawn (skill and ability slots).
const NONE := -2
## From this `visual_size` up the quantity badge uses the compact text size instead of the micro one.
const LARGE_CELL := 56

## Icon name.
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_rebuild_icon()

## This slot's semantic color (border and glow).
@export var accent := Color.TRANSPARENT:
	set(value):
		accent = value
		refresh()

## The icon's own color (an item's color in a bag). Transparent = the readable text color, as before.
## 🔑 It is **corrected for contrast against the slot face** (`GoSkin.readable_on`), so a dark blue item on a dark
##    panel is lifted until it reads, and a pale one on a light theme is lowered — the hue survives, the icon never sinks in.
##    An empty (`quantity = 0`) or disabled slot still fades to the muted color: state outranks decoration.
@export var icon_ink := Color.TRANSPARENT:
	set(value):
		icon_ink = value
		refresh()

## The quantity held. `UNKNOWN` (-1) shows `…`, `NONE` (-2) hides the quantity row entirely (skill slots and such),
## and 0 is dimmed.
@export var quantity := UNKNOWN:
	set(value):
		quantity = value
		refresh()

## Shows a remaining-time label over the panel (a cooldown, time left on a buff). Empty hides it.
@export var timer_text := "":
	set(value):
		timer_text = value
		refresh()

## The shortcut label (`1`·`Q`). Empty hides it. 🛑 **Display only** — the game handles the input.
@export var shortcut_label := "":
	set(value):
		shortcut_label = value
		refresh()

## One side of the visible panel (dp). Touch grows out to `GoConfig.min_touch_size`.
## 🔑 A panel **larger** than the touch minimum (an inventory cell at 56–64dp) grows the slot's own box with it —
##    otherwise the face is clamped back to the touch size and every cell of a bag looks like a quick slot.
@export_range(16, 128) var visual_size := 44:
	set(value):
		visual_size = value
		_fit_box()
		_rebuild_icon()
		# 🛑 `refresh()` too — the count's text size is chosen there (`LARGE_CELL`), so a cell resized after entering
		#    the tree kept the old size until something else happened to refresh it.
		refresh()

## This slot is the picked one (an inventory cell whose detail is open, a drop target). It gets the lit border
## **without** the cooldown's dimmed icon — picked means "look here", a cooldown means "not yet".
@export var selected := false:
	set(value):
		selected = value
		refresh()

## Overlapping neighbour slots. The overlap goes to whichever center is closer.
var touch_peers: Array[Control] = []

var _face: Panel
var _icon: Control
var _quantity: Label
var _quantity_badge: PanelContainer
var _timer: Label
var _timer_badge: PanelContainer
var _shortcut: Label
var _cooldown_left := 0.0
var _cooldown_total := 0.0
## The `disabled` value the panel was last painted for — `disabled` belongs to `BaseButton` and has no setter here.
var _painted_disabled := false


## 🔑 **Should this slot be reachable by keyboard and gamepad?**
##
## Off by default — quick slots are for fingers or number keys, and eight of them in the Tab order means walking
## through every slot each time the settings screen is navigated by keyboard. Turn it on for keyboard-only play.
@export var keyboard_focus := false:
	set(value):
		keyboard_focus = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE


func _init() -> void:
	name = "Slot"
	# 🛑 Out of the Tab order by default — the reason is in the `keyboard_focus` comment above.
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = GoTheme.VAR_BARE_BUTTON
	clip_text = false


func _ready() -> void:
	_adopt_theme()

	_face = Panel.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)

	# 🔑 **The icon big in the middle, the text as corner badges.** Stacking the three vertically shrank the icon
	#    inside 48dp and crowded the labels together (measured 2026-09-13). The shortcut goes top-left, the quantity
	#    in a bottom-right badge, and the time left large, **overlaid on** the icon — exactly how game HUDs lay it out.
	_icon = Control.new()
	_icon.name = "IconSlot"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_icon)
	# The time left sits over the icon as **a small badge** — overlaid without a badge it blends into the icon and cannot be read (measured).
	_timer_badge = PanelContainer.new()
	_timer_badge.name = "TimerBadge"
	_timer_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_timer_badge)
	_timer = _line("Timer", GoTheme.ROLE_COMPACT)
	_timer_badge.add_child(_timer)
	_shortcut = _line("Shortcut", GoTheme.ROLE_MICRO)
	_shortcut.add_theme_color_override(&"font_color", GoUi.color(GoTheme.MUTED))
	_face.add_child(_shortcut)
	_quantity_badge = PanelContainer.new()
	_quantity_badge.name = "QuantityBadge"
	_quantity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_quantity_badge)
	_quantity = _line("Quantity", GoTheme.ROLE_MICRO)
	_quantity_badge.add_child(_quantity)

	_rebuild_icon()
	_fit.call_deferred()
	refresh.call_deferred()
	resized.connect(_fit)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Puts the current theme and touch minimum on this slot. 🛑 Pulled out because **the same thing** has to be redone when the look changes.
func _adopt_theme() -> void:
	theme = GoUi.theme()
	_fit_box()


## The slot's own box: the touch minimum, or the visible panel when that is larger.
func _fit_box() -> void:
	var side := maxi(GoUi.config.min_touch_size, visual_size)
	custom_minimum_size = Vector2(side, side)


## 🎨 The whole look changed — called by `GoUi.use_preset()`·`GoUi.refresh()`.
## 🛑 Without this, **only the quick slots already on screen keep the old theme** (measured 2026-09-16: switching the
##    preset to sci-fi left the panel color unchanged, and next to a freshly made slot one row carried two looks).
## 🛑 Nodes are **not rebuilt** — the `Face` and badges `_ready` built stay put; only colors and art are swapped.
func _on_ui_changed() -> void:
	_adopt_theme()
	# The icon **set** may have been swapped wholesale — the same name becomes a different picture.
	_rebuild_icon()
	refresh()


func _line(node_name: String, role: StringName) -> Label:
	var node := GoStyle.label("", role)
	node.name = node_name
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 🛑 A form (`GoForm`, `GoStyle.form`) turns wrapping on for every label below it — a count badge sized to its text
	#    then folds one character per line ("×", "1", "2" stacked; a bag grid in the widget gallery, 2026-09-18).
	node.set_meta(&"go_no_wrap", true)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 🛑 Numbers and key labels do not flip with the language.
	node.text_direction = Control.TEXT_DIRECTION_LTR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Sets the cooldown. `left <= 0` means no cooldown.
func set_cooldown(left: float, total: float) -> void:
	_cooldown_left = maxf(0.0, left)
	_cooldown_total = maxf(0.0, total)
	refresh()


func cooldown_ratio() -> float:
	return clampf(_cooldown_left / _cooldown_total, 0.0, 1.0) if _cooldown_total > 0.0 else 0.0


func _rebuild_icon() -> void:
	if not is_instance_valid(_icon): return
	for child in _icon.get_children(): child.queue_free()
	if icon_name.is_empty(): return
	var px := maxi(8, roundi(visual_size * 0.52))   # badge layout, so the icon is bigger
	var glyph := GoUi.icons().node(icon_name, px)
	# 🛑 Placed at **a fixed size** in the middle of the slot — with FULL_RECT a texture set (TextureRect · EXPAND_IGNORE_SIZE)
	#    fills the whole slot and runs into the panel border (a flaw hidden by font sets, whose glyph size is fixed — found in the demo 2026-09-12).
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.size = Vector2(px, px)
	glyph.position = -Vector2(px, px) * 0.5
	_icon.add_child(glyph)


## Panel height = the sum of the real line heights. 🛑 Line heights are **never hard-coded** — the real line height,
##    with font and scale multiplied in, is taller than the font size and differs per device. Hard-code it and the quantity spills outside the panel.
func _fit() -> void:
	if not is_instance_valid(_face): return
	var touch := float(GoUi.config.min_touch_size)
	var box := maxf(size.x, touch)
	var box_y := maxf(size.y, touch)
	var visual := minf(float(visual_size), minf(box, box_y))
	_face.position = Vector2((box - visual) * 0.5, (box_y - visual) * 0.5)
	_face.size = Vector2(visual, visual)
	# The icon uses the whole panel and sits in the middle — the badges only hang on the corners, they take no room from it.
	_icon.position = Vector2.ZERO
	_icon.size = Vector2(visual, visual)
	# The time left goes centered **over** the icon — the icon dims while it is there (`refresh`).
	var timer_size := _timer_badge.get_combined_minimum_size()
	_timer_badge.size = timer_size
	_timer_badge.position = ((Vector2(visual, visual) - timer_size) * 0.5).round()
	# Shortcut: top-left corner, natural size.
	var shortcut_size := _shortcut.get_combined_minimum_size()
	_shortcut.position = Vector2(3.0, 1.0)
	_shortcut.size = shortcut_size
	_shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Quantity badge: hangs on the bottom-right corner.
	var badge_size := _quantity_badge.get_combined_minimum_size()
	_quantity_badge.size = badge_size
	_quantity_badge.position = Vector2(visual - badge_size.x + 2.0, visual - badge_size.y + 2.0)


## Brings colors and text in line with the current state.
func refresh() -> void:
	if not is_instance_valid(_face): return
	var color := accent if accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var lit := _cooldown_left > 0.0 or not timer_text.is_empty()
	var empty := quantity == 0
	# 🔑 No icon and no quantity row = **a vacant cell** (an empty inventory space). It is drawn faint like a
	#    spent slot, so a half-full bag reads as "items, then room" rather than a wall of identical frames.
	var vacant := icon_name.is_empty() and quantity == NONE
	_painted_disabled = disabled
	var faded := empty or disabled or vacant

	# 🛑 Dimming **never multiplies alpha** (it used to be `modulate.a = 0.55`) — in a light theme it multiplies into
	#    an already pale color and the slot **disappears** entirely (measured 2026-09-13 in the light gallery: empty slots were invisible).
	#    The color is **moved** toward the dim end instead. In any theme that reads as "faint but still there".
	var face_ink := GoUi.color(GoTheme.MUTED) if faded else color
	var style := GoUi.skin().slot_box(color if selected else face_ink, lit or selected)
	_face.add_theme_stylebox_override(&"panel", style)

	# 🛑 The text has to be readable **on this panel**. How the panel is painted is the skin's call — a host may fill
	#    it with the accent color in its own skin — so a hard-coded text color vanishes the moment it does
	#    (measured 2026-09-13: in a custom skin built exactly as documented, the quantity came out at 1.70:1 and an empty slot at 1.29:1).
	#    Even on the default slot with a cooldown running, an empty slot's quantity was already below the bar at 3.97:1.
	var on_face := GoSkin.blend(GoSkin.box_background(style), GoUi.color(GoTheme.SURFACE_SOFT))

	# 🛑 **The icon is held to the same requirement as the text.** Pinned to `Color.WHITE`, a white potion sank
	#    completely into a white panel in a light theme (measured 2026-09-13 in the light gallery — three of four slots were left as outlines only).
	#    That said, when the icon set has picked its own color (`tint`), that intent is respected — a colored picture
	#    is not ruined by painting over it.
	#    🛑 A white `tint` is the identity of multiplication, so **the result is the same as picking no color at all** —
	#       treat it as picked and the whole default set falls into this branch (and it did: white was baked into the default `.tres`).
	var icons := GoUi.icons()
	if icons != null and icons.tint.a > 0 and not icons.tint.is_equal_approx(Color.WHITE):
		_icon.modulate = Color.WHITE
	else:
		var wanted := icon_ink if icon_ink.a > 0 else GoUi.color(GoTheme.TEXT)
		_icon.modulate = GoUi.skin().readable_on(GoUi.color(GoTheme.MUTED) if faded else wanted, on_face)
		# 🛑 During a cooldown the icon is **pulled back toward the panel color** — the time left on top of it is the star.
		#    Colors are blended rather than alpha multiplied (in a light theme alpha erases the slot entirely).
		if lit: _icon.modulate = on_face.lerp(_icon.modulate, 0.45)

	_quantity_badge.visible = quantity != NONE
	if _quantity_badge.visible:
		# 🔑 A big cell gets a bigger count — the micro size is tuned for a 44dp quick slot and turns into a speck
		#    on a 60dp inventory cell, where the count is the second thing a player looks for (after the icon).
		GoStyle.typography(_quantity, GoTheme.ROLE_COMPACT if visual_size >= LARGE_CELL else GoTheme.ROLE_MICRO)
		_quantity.text = GoUi.text(&"slot_unknown") if quantity == UNKNOWN \
			else GoUi.text(&"slot_quantity").format({"count": GoBar.format_amount(quantity)})
		var badge := GoUi.skin().badge_box(face_ink)
		_quantity_badge.add_theme_stylebox_override(&"panel", badge)
		# The text must be readable **on the badge panel** — not on the slot panel.
		var on_badge := GoSkin.blend(GoSkin.box_background(badge), on_face)
		_quantity.add_theme_color_override(&"font_color", GoUi.skin().readable_on(
			GoUi.color(GoTheme.MUTED) if empty else GoUi.color(GoTheme.TEXT), on_badge))
		_fit()

	var seconds := ""
	if not timer_text.is_empty(): seconds = timer_text
	elif _cooldown_left > 0.0: seconds = "%ds" % ceili(_cooldown_left)
	_timer_badge.visible = not seconds.is_empty()
	_timer.text = seconds
	if _timer_badge.visible:
		var timer_badge := GoUi.skin().badge_box(color)
		_timer_badge.add_theme_stylebox_override(&"panel", timer_badge)
		var on_timer := GoSkin.blend(GoSkin.box_background(timer_badge), on_face)
		_timer.add_theme_color_override(&"font_color", GoUi.skin().readable_on(color, on_timer))
		_fit()

	_shortcut.visible = not shortcut_label.is_empty()
	_shortcut.text = shortcut_label
	_shortcut.add_theme_color_override(&"font_color",
		GoUi.skin().readable_on(GoUi.color(GoTheme.MUTED), on_face))

	# ♿ A slot shows no text of its own — a screen reader gets the name (the tooltip), the count and the time left.
	accessibility_name = GoUi.spoken([tooltip_text, _quantity.text if _quantity_badge.visible else "", seconds])
	_fit()


## 🛑 The engine's default tooltip can break a short name into one character per line — the same gohud tooltip
##    as `GoIconButton` (an inventory cell's tooltip is its item name).
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty(): return null
	return GoStyle.tooltip_node(for_text)


## 🛑 The quantity label ("×3") goes through a translation key too — it is rebuilt when the language changes.
## 🛑 `disabled` is a `BaseButton` property, so no setter here notices it. Changing it redraws the button, so the draw
##    notification is where a slot learns it must fade (or come back).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()
	elif what == NOTIFICATION_DRAW and disabled != _painted_disabled:
		refresh.call_deferred()


## This slot's own rectangular touch area — the test before it is shared out with the neighbours.


func touch_hit(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(point)


func _has_point(point: Vector2) -> bool:
	if not touch_hit(point): return false
	if touch_peers.is_empty(): return true
	var here := (point + global_position - get_global_rect().get_center()).length()
	for peer in touch_peers:
		if peer == self or not is_instance_valid(peer) or not peer.is_visible_in_tree(): continue
		if (point + global_position - peer.get_global_rect().get_center()).length() < here: return false
	return true


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		set_process(false)
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	refresh()


## Lets the slot count the cooldown down itself (so the game need not feed it every frame).
func start_cooldown(seconds: float) -> void:
	set_cooldown(seconds, seconds)
	set_process(seconds > 0.0)
