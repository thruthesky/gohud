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
##
## # A sticker: painted solid, bigger, tilted — the "PLAY!" tag on the stage you play next, the check on a cleared one
## GoBadge.stick(stage_card, "PLAY!", GoUi.color(GoTheme.SUCCESS_FILL), -9.0)
## GoBadge.stick(cleared_card, "", GoUi.color(GoTheme.SUCCESS_FILL), 0.0, GoIconSet.CHECK)
## ```
##
## ## 🏷 Badge or sticker
## A **badge** whispers a count on a faint plate (`badge_box`). A **sticker** (`solid`) is painted in its colour and
## is the loudest thing on its card (`GoSkin.sticker_box` — a small painted key with a lip and a gloss under the arcade
## looks, its words white with an ink outline). Use a sticker for one state the player should act on, not for counts.
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

## An icon name (`GoIconSet.CHECK`, a lock, a star) shown instead of the count or the words — drawn from the icon set
## in force, as tall as the text role's line, in the colour the words would take. Empty: none.
@export var icon := &"":
	set(value):
		icon = value
		_refresh()

## 🏷 Painted solid in `ink`, the words in the colour that reads on it — a sticker (`GoSkin.sticker_box`).
@export var solid := false:
	set(value):
		solid = value
		_refresh()

## Turned this many degrees round its centre — a sticker slapped on (−9 leans it left). Drawing only: the badge keeps
## its box, so nothing around it moves.
@export_range(-45.0, 45.0, 0.5) var tilt := 0.0:
	set(value):
		tilt = value
		_place_tilt()

## The size of the words or icon — a text role (`GoTheme.ROLE_MICRO` for a count; `ROLE_BODY` or larger for a sticker
## that has to read across a card).
@export var text_role := GoTheme.ROLE_MICRO:
	set(value):
		text_role = value
		_refresh()

## Whether it hides itself at 0. 🛑 Leave it off and a badge reading `0` stays on screen.
@export var hide_when_zero := true:
	set(value):
		hide_when_zero = value
		_refresh()

var _count := 0
var _label: Label
## The icon drawn now (`GoUi.icons().node()` — a texture or a glyph), rebuilt when the name, size or colour changes.
var _icon_node: Control
var _icon_key := ""


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
	# 🛑 A count is one token — never wrapped. Inside a `GoForm` it was: a wrapping label is 1dp wide, `NEW` folded letter
	#    by letter, and the badge copied that height into its width — a 65×65 block instead of 33×16 (measured 2026-09-23).
	GoStyle.one_line(_label)
	add_child(_label)
	resized.connect(_place_tilt)


func _ready() -> void:
	theme = GoUi.theme()
	_refresh()


func _enter_tree() -> void:
	# 🔑 Watched on every entry, not once in `_ready` — a widget taken out and put back (`remove_child` + `add_child`)
	#    would otherwise stop following the look; on a re-entry it catches up with a look changed while it was out.
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


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
	var pictured := not icon.is_empty() and not dot
	var words := label_text
	if words.is_empty() and not dot and not pictured:
		words = "%d+" % cap if cap > 0 and _count > cap else str(_count)

	visible = not (hide_when_zero and _count <= 0 and label_text.is_empty() and icon.is_empty())
	_label.visible = not dot and not pictured
	_label.text = "" if dot or pictured else words
	GoStyle.typography(_label, text_role, GoUi.color(GoTheme.ON_ACCENT))
	# A dot is a solid circle of a set diameter — there is no text, so give it a minimum size ourselves.
	var px := maxf(6.0, float(GoUi.metric(GoTheme.GAP_SMALL)))
	var face: StyleBox
	if dot: face = GoUi.skin().dot_box(color, px)
	elif solid: face = GoUi.skin().sticker_box(color)
	else: face = GoUi.skin().badge_box(color)
	if pictured:
		# One icon is a disc, not a pill: the sides pad as much as the top and bottom together share.
		face = face.duplicate()
		var even := (face.get_margin(SIDE_TOP) + face.get_margin(SIDE_BOTTOM)) * 0.5
		face.content_margin_left = even
		face.content_margin_right = even
	add_theme_stylebox_override(&"panel", face)
	if solid and not dot:
		GoUi.skin().dress_sticker(_label, color)
	else:
		_label.remove_theme_color_override(&"font_outline_color")
		_label.remove_theme_constant_override(&"outline_size")
		_label.add_theme_color_override(&"font_color", _on_badge(face, color))
	_show_icon(pictured)

	if dot:
		custom_minimum_size = Vector2(px, px)
	else:
		# Keep a single digit (or an icon) round too — narrower than it is tall and it reads as a squashed pill.
		var box := _icon_node.get_combined_minimum_size() if pictured else _label.get_combined_minimum_size()
		var side := maxf(box.y, box.x)
		custom_minimum_size = Vector2(side, box.y)
		if pictured: _round(face, box.y + face.get_margin(SIDE_TOP) + face.get_margin(SIDE_BOTTOM))
	_place_tilt()

	# ♿ Colour and position alone cannot be read — say in words how many of what there are.
	# 🛑 Using `empty` in dot mode reads as **the exact opposite** — a mark saying "there is something new"
	#    becomes "there is nothing here" (measured 2026-09-16). A dot hides the count; it is not an absence.
	if not words.is_empty(): accessibility_name = words
	elif dot: accessibility_name = GoUi.spoken([str(_count)]) if _count > 0 else ""
	else: accessibility_name = ""


## The text colour that stays legible on the badge panel — the badge's own colour, pushed until it reads **on the face
## the skin actually paints**. The skin decides how the panel is painted, so no colour can be hard-coded.
## 🛑 Measure against the painted face, not the badge colour. The text used to be picked against red while the skin
##    paints the face in the surface colour: `on_accent` on `surface_high` is 1.69:1 in the default dark theme — the
##    count could not be read (measured 2026-09-23). The slot's quantity badge already reads its face this way.
func _on_badge(face: StyleBox, ink: Color) -> Color:
	var back := GoSkin.blend(GoSkin.box_background(face), GoUi.color(GoTheme.SURFACE))
	return GoSkin.readable_on(ink, back)


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


## 🏷 A **sticker** on the corner of [param host]: a solid badge (`solid`) in [param color] with [param words] or
## [param picture], tilted [param degrees], at body size — one per host, like `attach()` (calling it again restyles the
## same one). An empty [param color] uses the theme's success fill.
static func stick(host: Control, words := "", color := Color.TRANSPARENT, degrees := 0.0,
		picture := &"") -> GoBadge:
	var node := attach(host, 0, words, false, color if color.a > 0.0 else GoUi.color(GoTheme.SUCCESS_FILL))
	if node == null: return null
	node.solid = true
	node.text_role = GoTheme.ROLE_BODY
	node.icon = picture
	node.tilt = degrees
	return node


## An icon badge is a disc: its corners round to half its height (a key face's `radius`, a flat face's corners).
## 🛑 Half the height, not 999 — the layout audit reads a 999 corner as text that needs 300dp of room.
static func _round(face: StyleBox, height: float) -> void:
	var half := ceilf(height * 0.5)
	if face is StyleBoxFlat: (face as StyleBoxFlat).set_corner_radius_all(int(half))
	elif &"radius" in face: face.set(&"radius", half)


## The icon in the words' colour, as tall as the role's line — rebuilt only when that changes (a count ticking up
## never rebuilds it).
func _show_icon(pictured: bool) -> void:
	var colour := _label.get_theme_color(&"font_color")
	var side := roundi(float(GoUi.font_size(text_role)) * 1.25)
	var key := "%s|%d|%s|%s" % [icon, side, colour.to_html(), GoUi.icons().resource_path] if pictured else ""
	if key == _icon_key and (is_instance_valid(_icon_node) or not pictured): return
	_icon_key = key
	if is_instance_valid(_icon_node):
		remove_child(_icon_node)
		_icon_node.queue_free()
	_icon_node = null
	if not pictured: return
	_icon_node = GoUi.icons().node(icon, side, colour)
	add_child(_icon_node)


## Turns it round its own centre (`tilt`). The pivot follows the size, so a badge that grows keeps turning in place.
func _place_tilt() -> void:
	pivot_offset = size * 0.5
	rotation = deg_to_rad(tilt)


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
		# It hangs over the host's corner on purpose — layout checks leave it out (`GoStyle.audit_layout`).
		node.set_meta(&"go_overlay", true)
		# 🔑 The count changes the badge's size (`3` → `128`), and the corner has to stay at its center — re-pinned each time.
		node.minimum_size_changed.connect(node._pin_to_corner, CONNECT_DEFERRED)
		host.add_child(node)
		host.set_meta(_ATTACHED, node)
		node.tree_exited.connect(func() -> void:
			if not is_instance_valid(host) or not host.has_meta(_ATTACHED): return
			if host.get_meta(_ATTACHED) == node: host.remove_meta(_ATTACHED))
	node.label_text = words
	node.dot = as_dot
	node.ink = color
	node.set_count(count)
	node._pin_to_corner()
	return node


## Overlap by half — put the host's top right corner at the **centre** of the badge.
##
## 🛑 With anchors it is `offset_*`, not `position`. `Control.position` is in **parent coordinates**, so it
##    ignores the anchors and simply goes to that value — measured 2026-09-16: with the anchor on the right
##    (1.0), `position = (-8, -8)` took effect as written and put the badge **outside the parent's top left**.
##    (Before that, adding the parent width to `position` flung it one width off the other way.)
## 🛑 From the minimum size, and again whenever it changes — measured once at attach time, the offsets froze and a count
##    that grew from `3` to `128` hung off-center.
func _pin_to_corner() -> void:
	var half := get_combined_minimum_size() * 0.5
	offset_left = -half.x
	offset_top = -half.y
	offset_right = half.x
	offset_bottom = half.y


## Detach the attached badge. Does nothing if there is none.
static func detach(host: Control) -> void:
	if not is_instance_valid(host): return
	var node: GoBadge = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if is_instance_valid(node): node.queue_free()
	if host.has_meta(_ATTACHED): host.remove_meta(_ATTACHED)
