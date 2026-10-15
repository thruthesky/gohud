## 📐 **Keeps a whole card on the screen** — the card, and what it draws past its edges (a ribbon over the top, the
## magnet out to the side), centred in the safe area and shrunk as one piece when it is too big for it. Magnet Mayhem's
## `FitBox`, for a card screen that is not a `GoSurface` window (a pause or settings card headed by a `GoRibbonHeader`).
##
## ```gdscript
## var fit := GoFitBox.new()                       # full screen, on a CanvasLayer
## layer.add_child(fit)
## fit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
## fit.add_child(card)                             # a PanelContainer whose column starts with a GoRibbonHeader
## ```
##
## ## How it fits
## The room is the safe area (`safe_area`) less `pad` all round. A card bigger than the room shrinks by `scale` —
## never above 1 — until it and its `overhang` fit. A card that would have to shrink below the fit floor
## (`GoConfig.fit_min_scale`) first gives up height from its `flex` list (a ScrollContainer, `new_flex()`), down to
## `GoSkin.window_flex_min_height()`, so a long list scrolls on a landscape phone while its text stays readable. The
## card is centred on its own rect and nudged only when the room is tight, so its overhang stays inside too.
##
## 🔑 The overhang follows the look: with `auto_overhang` on it is `GoRibbonHeader.card_overhang(card)` when the card
##    holds a `GoRibbonHeader`, nothing otherwise — 20 each side and 41 above under arcade_light, the game's numbers.
## 🛑 Its own minimum size is zero: the card never pushes the screen around it. Children are placed by hand
##    (`Container.fit_child_in_rect` would reset their scale), each visible one on its own.
@tool
class_name GoFitBox
extends Container

## How far the card draws past its own rect (left, top, right, bottom, dp at scale 1). Setting it turns
## `auto_overhang` off.
var overhang := Vector4.ZERO:
	set(value):
		overhang = value
		auto_overhang = false
		queue_sort()
## Take the overhang from the look: `GoRibbonHeader.card_overhang(card)` for a card holding a `GoRibbonHeader` (its
## corner art counted while it shows), `Vector4.ZERO` for one without.
var auto_overhang := true:
	set(value):
		auto_overhang = value
		queue_sort()
## The card's list that scrolls rather than shrink the card below the fit floor; its one child is the content. Null:
## the card only shrinks. 🛑 Set it once the content is in — its height is fixed here, so the content's own growth
## (new rows, another tab) asks for a new fit through it.
var flex: ScrollContainer:
	set(value):
		_watch_flex(false)
		flex = value
		_watch_flex(true)
		queue_sort()
## The free room kept off the edge of the room (dp). Negative: the look's (`GoSkin.window_fit_pad()`, 8 in
## arcade_light).
var pad := -1.0:
	set(value):
		pad = value
		queue_sort()
## Fit inside the screen's safe area (and above the on-screen keyboard) as well as this box's own rect. Off: the rect
## alone — for a box already inside a `GoSafeArea`.
var safe_area := true:
	set(value):
		safe_area = value
		queue_sort()
## The scale the card got (1: its own size). Read it after a fit.
var fit_scale := 1.0

var _watched: Control


## A ScrollContainer for `flex`: up and down only, no bar (the wheel and a drag scroll it) and a deadzone of a quarter
## of the touch target, so a slider drag or a tap on a row is not taken for a scroll — the game's `FitBox.new_flex()`.
static func new_flex() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = int(GoUi.metric(GoTheme.TOUCH) * 0.25)
	# Never shown, so it never catches a drag.
	scroll.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	return scroll


## The free room off the edge in force (dp): `pad`, or the look's.
func pad_now() -> float:
	return pad if pad >= 0.0 else look_pad()


## The look's free room off the edge (dp): `GoSkin.window_fit_pad()`, or the theme's `SCREEN_MARGIN`.
static func look_pad() -> float:
	var look := GoUi.skin().window_fit_pad()
	return look if look >= 0.0 else float(GoUi.metric(GoTheme.SCREEN_MARGIN))


## 🔑 The game's fit, shared with `GoSurface`'s `SCALE` fit: [param card] of [param need] (dp at scale 1) is centred
## in [param area] (the parent's coordinates), shrunk until it and [param reach] (its overhang: left, top, right,
## bottom) fit the area less [param margin] all round, never above 1, then nudged so the overhang stays inside.
## Sets the card's scale, size and position and returns the scale.
static func place(card: Control, area: Rect2, need: Vector2, reach: Vector4, margin: float) -> float:
	var room := area.size - Vector2(margin, margin) * 2.0
	var drawn := need + Vector2(reach.x + reach.z, reach.y + reach.w)
	var factor := minf(1.0, minf(room.x / maxf(1.0, drawn.x), room.y / maxf(1.0, drawn.y)))
	card.pivot_offset = Vector2.ZERO
	card.scale = Vector2(factor, factor)
	card.size = need
	# Centred on its own rect, then nudged so the overhang stays inside too (only when the room is tight).
	var at := ((area.size - need * factor) / 2.0).floor()
	at.x = clampf(at.x, margin + reach.x * factor, area.size.x - margin - (need.x + reach.z) * factor)
	at.y = clampf(at.y, margin + reach.y * factor, area.size.y - margin - (need.y + reach.w) * factor)
	card.position = area.position + at
	return factor


## The height a flex list gets (dp): its content's [param full] height, less whatever the card — [param others] high
## without the list — is over [param most]; never below the look's floor (`GoSkin.window_flex_min_height()`) unless
## the content is shorter.
static func flex_height(full: float, others: float, most: float) -> float:
	return clampf(most - others, minf(full, GoUi.skin().window_flex_min_height()), full)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The card inside wears the look (its painted card, the ribbon's), as a `GoSurface`'s does.
	theme = GoUi.theme()


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(queue_sort): view.size_changed.connect(queue_sort)
	queue_sort()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	var view := get_viewport()
	if view != null and view.size_changed.is_connected(queue_sort): view.size_changed.disconnect(queue_sort)


## The look changed: wear its theme and fit again (its pad, overhang and floors may differ).
func _on_ui_changed() -> void:
	if theme != GoUi.theme(): theme = GoUi.theme()
	queue_sort()


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child: Node in get_children():
			var card := child as Control
			if card != null and card.visible and not card.top_level: _place(card)


## The room in this box's coordinates: its rect, inside the safe area when `safe_area` is on.
func room_rect() -> Rect2:
	var rect := Rect2(Vector2.ZERO, size)
	if not safe_area or not is_inside_tree(): return rect
	var usable := GoSafeArea.usable_rect_with_keyboard(get_viewport(), _keyboard_px())
	var local := get_global_transform().affine_inverse() * usable
	return rect.intersection(local)


func _keyboard_px() -> int:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return 0
	return DisplayServer.virtual_keyboard_get_height()


## The overhang in force for [param card]: `overhang`, or the look's for the ribbon it holds.
func overhang_of(card: Control) -> Vector4:
	if not auto_overhang: return overhang
	var header := _header_in(card, 4)
	if header == null: return Vector4.ZERO
	var art := header.corner and (header.corner_art != null or GoUi.skin().window_corner() == &"art")
	return GoRibbonHeader.card_overhang(card, art)


func _header_in(node: Node, depth: int) -> GoRibbonHeader:
	for child in node.get_children():
		if child is GoRibbonHeader and (child as Control).visible: return child
		if depth > 1:
			var found := _header_in(child, depth - 1)
			if found != null: return found
	return null


func _place(card: Control) -> void:
	var margin := pad_now()
	var area := room_rect()
	var room := area.size - Vector2(margin, margin) * 2.0
	if room.x <= 0.0 or room.y <= 0.0: return # not laid out yet
	var reach := overhang_of(card)
	_fit_flex(card, room.y / GoUi.config.fit_min_scale - (reach.y + reach.w))
	fit_scale = place(card, area, card.get_combined_minimum_size(), reach, margin)


## Gives the flex list its content's full height, less whatever the card is over [param most].
func _fit_flex(card: Control, most: float) -> void:
	if flex == null or not flex.is_visible_in_tree() or flex.get_child_count() == 0: return
	var content := flex.get_child(0) as Control
	if content == null: return
	var full := content.get_combined_minimum_size().y
	var others := card.get_combined_minimum_size().y - flex.get_combined_minimum_size().y
	# 🔑 Whole dp: a BoxContainer sums its rows' minimum sizes in whole units, so with a fractional list the card's
	#    other rows read a fraction off on the next pass and the list crept (the game's FitBox does: 368.86 for its
	#    369.29). Floored, the fit is stable and within a unit of the game's.
	var tall := floorf(flex_height(full, others, most))
	if not is_equal_approx(flex.custom_minimum_size.y, tall): flex.custom_minimum_size.y = tall


## 🛑 The flex's own minimum height is fixed here, so the card never reports its content growing: the content's
##    minimum size asks for a new fit instead.
func _watch_flex(on: bool) -> void:
	if not on:
		if is_instance_valid(_watched) and _watched.minimum_size_changed.is_connected(queue_sort):
			_watched.minimum_size_changed.disconnect(queue_sort)
		_watched = null
		return
	if flex == null or flex.get_child_count() == 0: return
	_watched = flex.get_child(0) as Control
	if _watched != null: _watched.minimum_size_changed.connect(queue_sort)
