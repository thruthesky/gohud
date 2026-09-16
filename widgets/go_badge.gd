## 🔴 **Badge** — the red dot on the mailbox, the NEW on the shop, the friend-request count.
##
## ```gdscript
## # Pin it to the corner of an icon button — it hides itself at 0
## GoBadge.attach(mail_button, unread_count)
## GoBadge.attach(shop_button, 0, "NEW")        # text instead of a number
## GoBadge.attach(friend_button, 3, "", true)   # dot only — hide the count, just say "there is something"
##
## # A badge placed directly in a row
## row.add_child(GoBadge.make(12))
## ```
##
## ## 🔑 Count or dot
## **If the count changes behaviour** it is a number (3 letters and 30 letters get handled differently).
## **If all that matters is "there is something new"** it is a dot (new stock in the shop). A dot where a
## number belongs loses information; a number where a dot belongs makes the screen noisy.
##
## ## 🛑 Fold large numbers
## Without folding to `99+`, "1284" grows wider than the icon and shoves the HUD row along. Change where
## it folds with `cap`.
##
## ## 🛑 Do not signal with colour alone
## Told apart by a single red dot, **nothing has changed at all** for someone who is colour-blind. So a
## badge carries a screen-reader name (`accessibility_name`) and keeps the count readable as text too.
@tool
class_name GoBadge
extends PanelContainer

## Above this number it folds, as in `99+`. 0 never folds.
@export var cap := 99:
	set(value):
		cap = maxi(0, value)
		_refresh()

## Text to show instead of a number (`NEW`, `!`). Empty uses the number.
@export var label_text := "":
	set(value):
		label_text = value
		_refresh()

## Hide the count and show **only a dot**.
@export var dot := false:
	set(value):
		dot = value
		_refresh()

## Badge colour. Empty uses the theme's danger colour (red) — the first place the eye goes.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		_refresh()

## Whether it hides itself at 0. 🛑 Leave it off and a badge reading `0` stays on screen.
@export var hide_when_zero := true:
	set(value):
		hide_when_zero = value
		_refresh()

var _count := 0
var _label: Label


func _init() -> void:
	name = "Badge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 Numbers do not flip left-to-right with the language.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label = Label.new()
	_label.name = "Count"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.text_direction = Control.TEXT_DIRECTION_LTR
	add_child(_label)


func _ready() -> void:
	theme = GoUi.theme()
	_refresh()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## The count to show. At 0 (and with `hide_when_zero`) it hides.
func set_count(value: int) -> void:
	_count = maxi(0, value)
	_refresh()


func count() -> int:
	return _count


func _refresh() -> void:
	if not is_instance_valid(_label): return
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.DANGER)
	var words := label_text
	if words.is_empty() and not dot:
		words = "%d+" % cap if cap > 0 and _count > cap else str(_count)

	visible = not (hide_when_zero and _count <= 0 and label_text.is_empty())
	_label.visible = not dot
	_label.text = "" if dot else words
	GoStyle.typography(_label, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.ON_ACCENT))
	_label.add_theme_color_override(&"font_color", _on_badge(color))
	add_theme_stylebox_override(&"panel", GoUi.skin().badge_box(color))

	# A dot is a circle of a set diameter — there is no text, so give it a minimum size ourselves.
	if dot:
		var px := maxf(6.0, float(GoUi.metric(GoTheme.GAP_SMALL)))
		custom_minimum_size = Vector2(px, px)
	else:
		# Keep a single digit round too — narrower than it is tall and it reads as a squashed pill.
		var box := _label.get_combined_minimum_size()
		var side := maxf(box.y, box.x)
		custom_minimum_size = Vector2(side, box.y)

	# ♿ Colour and position alone cannot be read — say in words how many of what there are.
	# 🛑 Using `empty` in dot mode reads as **the exact opposite** — a mark saying "there is something new"
	#    becomes "there is nothing here" (measured 2026-09-16). A dot hides the count; it is not an absence.
	if not words.is_empty(): accessibility_name = words
	elif dot: accessibility_name = GoUi.spoken([str(_count)]) if _count > 0 else ""
	else: accessibility_name = ""


## The text colour that stays legible on the badge panel.
## 🛑 Do not just take `ON_ACCENT` — white text on a yellow warning badge does not even reach 2:1.
##    Pick **whichever has the greater contrast**. The skin decides how the panel is painted, so no colour can be hard-coded.
func _on_badge(background: Color) -> Color:
	var light := GoUi.color(GoTheme.ON_ACCENT)
	var dark := GoUi.color(GoTheme.BACKGROUND)
	return light if GoSkin.contrast_ratio(light, background) >= GoSkin.contrast_ratio(dark, background) else dark


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh()


# ── Making and attaching ───────────────────────────────────────────────

## A single badge placed straight into a row.
static func make(count := 0, words := "", as_dot := false, color := Color.TRANSPARENT) -> GoBadge:
	var node := GoBadge.new()
	node.label_text = words
	node.dot = as_dot
	node.ink = color
	node.set_count(count)
	return node


## The badge attached to a host is found under this meta name — so two never stack on the same button.
const _ATTACHED := &"gohud_badge"


## Attach a badge **to the corner of an existing control** (call it twice and only one is attached).
##
## ```gdscript
## GoBadge.attach(mail_button, unread)     # it disappears by itself once the count reaches 0
## GoBadge.attach(shop_button, 0, "NEW")
## ```
##
## 🛑 **It straddles the top right corner** — placed inside it covers the icon, placed fully outside it
##    widens the row spacing. Overlapping by half avoids both problems.
## 🔑 The host only has to be a `Control` — it attaches to a button, an icon, a slot, a tab, anything.
static func attach(host: Control, count := 0, words := "", as_dot := false,
		color := Color.TRANSPARENT) -> GoBadge:
	if not is_instance_valid(host): return null
	# 🛑 `get_meta(key, default)` **prints an error** when the key is missing (measured on Godot 4) — even
	#    with a default given. Ask `has_meta` first.
	var node: GoBadge = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if not is_instance_valid(node):
		node = GoBadge.new()
		node.name = "Badge"
		# 🛑 **Do not let a container parent dictate the position** — nail it to the top right with anchors.
		#    With all four anchors on that corner it follows even when the parent is sized later.
		node.anchor_left = 1.0
		node.anchor_top = 0.0
		node.anchor_right = 1.0
		node.anchor_bottom = 0.0
		host.add_child(node)
		host.set_meta(_ATTACHED, node)
		node.tree_exited.connect(func() -> void:
			if not is_instance_valid(host) or not host.has_meta(_ATTACHED): return
			if host.get_meta(_ATTACHED) == node: host.remove_meta(_ATTACHED))
	node.label_text = words
	node.dot = as_dot
	node.ink = color
	node.set_count(count)
	node.reset_size()
	# Overlap by half — put the top right corner at the **centre** of the badge.
	#
	# 🛑 With anchors it is `offset_*`, not `position`. `Control.position` is in **parent coordinates**, so it
	#    ignores the anchors and simply goes to that value — measured 2026-09-16: with the anchor on the right
	#    (1.0), `position = (-8, -8)` took effect as written and put the badge **outside the parent's top left**.
	#    (Before that, adding the parent width to `position` flung it one width off the other way.)
	var half := node.size * 0.5
	node.offset_left = -half.x
	node.offset_top = -half.y
	node.offset_right = half.x
	node.offset_bottom = half.y
	return node


## Detach the attached badge. Does nothing if there is none.
static func detach(host: Control) -> void:
	if not is_instance_valid(host): return
	var node: GoBadge = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if is_instance_valid(node): node.queue_free()
	if host.has_meta(_ATTACHED): host.remove_meta(_ATTACHED)
