## 💬 **A question card that does not stop the game.** There is no scrim, and only the card area takes input.
##
## Use it for questions you can keep playing without answering right now — party invites, trade requests.
## Anything that has to **block** on OK/Cancel is `GoDialogs`; a notice that needs no answer is `GoNotice`.
##
## ```gdscript
## var card := GoPromptCard.new()
## card.set_title("%s invited you to a party" % who)
## card.set_actions([
##     {"text": "Accept", "action": _accept, "primary": true},
##     {"text": "Decline", "action": _decline},
## ])
## card.fit_width(320)
## hud.add_child(card)
## ```
##
## Placement — where, and how big — is up to the **screen that owns it**; this card only knows colors, padding and button sizing.
@tool
class_name GoPromptCard
extends PanelContainer

signal closed

var title_label: Label
var subtitle_label: Label
var icon_slot: Control
var actions: HBoxContainer
var close_button: GoIconButton

## Fades in when shown, so it does not pop out over a combat screen. Size and position are settled immediately.
var fade_in := true

var _column: VBoxContainer
var _head: HBoxContainer
var _title_key := ""
var _title_args := {}
var _subtitle_key := ""
var _subtitle_args := {}
var _action_shape := ""
var _accent := Color.TRANSPARENT
var _fade: Tween
var _boxed_icon := false


## 🪟 **Panel background opacity** (0.0~1.0) — for this one panel only. Negative means whatever the theme/config decided.
## 🛑 Only the background thins out — text and icons stay crisp.
var alpha := -1.0:
	set(value):
		alpha = value
		if is_inside_tree(): add_theme_stylebox_override(&"panel", GoUi.skin().floating_box(GoTheme.BOX_HUD, _accent, value))


func _init() -> void:
	name = "PromptCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_column = GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	_head = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	_head.name = "Head"
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_head)

	icon_slot = Control.new()
	icon_slot.name = "Icon"
	icon_slot.visible = false
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(icon_slot)

	var texts := GoStyle.column(0)
	texts.name = "Texts"
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(texts)

	title_label = GoStyle.label("")
	title_label.name = "Title"
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(title_label)

	subtitle_label = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	subtitle_label.name = "Subtitle"
	# One status line — if it wraps, the card grows taller and covers more of the screen. One line by default.
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle_label.clip_text = true
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_label.visible = false
	texts.add_child(subtitle_label)

	close_button = _make_close_button()
	close_button.icon_name = GoIconSet.CLOSE
	close_button.tooltip_text_name = &"close"
	close_button.visible = false
	close_button.pressed.connect(func() -> void: closed.emit())
	_head.add_child(close_button)

	actions = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	actions.name = "Actions"
	actions.visible = false
	_column.add_child(actions)
	hide()


func _ready() -> void:
	theme = GoUi.theme()
	add_theme_stylebox_override(&"panel", GoUi.skin().floating_box(GoTheme.BOX_HUD, _accent, alpha))
	set_title_lines(2)
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 🎨 The whole look changed — `GoUi.use_preset()` and `GoUi.refresh()` call this.
## 🛑 Without it **the widgets already on screen are the only ones left on the old theme** (measured 2026-09-16).
func _on_ui_changed() -> void:
	theme = GoUi.theme()
	add_theme_stylebox_override(&"panel", GoUi.skin().floating_box(GoTheme.BOX_HUD, _accent, alpha))


## The semantic color of the card's border. Transparent means the default surface.
func set_accent(accent: Color) -> void:
	_accent = accent
	add_theme_stylebox_override(&"panel", GoUi.skin().floating_box(GoTheme.BOX_HUD, accent, alpha))
	if _boxed_icon: _restyle_icon()


func set_title_key(key: String, arguments := {}) -> void:
	_title_key = key
	_title_args = arguments.duplicate()
	title_label.text = tr(key).format(arguments)


## Text that is never translated — a person's name, a server value.
func set_title(value: String) -> void:
	_title_key = ""
	title_label.text = value


func set_subtitle_key(key: String, arguments := {}) -> void:
	_subtitle_key = key
	_subtitle_args = arguments.duplicate()
	subtitle_label.visible = not key.is_empty()
	subtitle_label.text = tr(key).format(arguments) if not key.is_empty() else ""


func set_subtitle(value: String) -> void:
	_subtitle_key = ""
	subtitle_label.visible = not value.is_empty()
	subtitle_label.text = value


## Title line count. 🛑 A wrapping label measures as 0 high before its width is settled and the card collapses —
##    so give it at least one line of height up front.
func set_title_lines(lines: int) -> void:
	_set_lines(title_label, lines)


## Subtitle line count. One line by default, but some cards — **instructions for what to do next** — have to show
## the whole sentence; with one line an important condition gets cut off mid-way.
func set_subtitle_lines(lines: int) -> void:
	_set_lines(subtitle_label, lines)


func _set_lines(node: Label, lines: int) -> void:
	if lines <= 1:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		node.clip_text = true
		node.max_lines_visible = 1
	else:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.clip_text = false
		node.max_lines_visible = lines
	node.custom_minimum_size.y = float(node.get_line_height())


## The icon in front of the title. An empty name hides it.
## `boxed` puts the icon inside a round badge in the accent color.
func set_icon(icon: StringName, ink := Color.TRANSPARENT, boxed := false) -> void:
	for child in icon_slot.get_children(): child.queue_free()
	icon_slot.visible = not icon.is_empty()
	_boxed_icon = boxed
	if icon.is_empty(): return
	var diameter := float(GoUi.config.min_touch_size) - 4.0
	var glyph_size := roundi(diameter * 0.5) if boxed else GoUi.font_size(GoTheme.ROLE_TITLE)
	var glyph := GoUi.icons().node(icon, glyph_size, ink)
	icon_slot.add_child(glyph)
	# 🛑 Centered at its own size, not stretched over the slot — a texture icon set (`EXPAND_IGNORE_SIZE`) filled the whole
	#    44dp disc instead of the 22dp asked for; a font set hid it because a glyph keeps its font size.
	GoStyle.center_in(glyph)
	icon_slot.custom_minimum_size = Vector2(diameter, diameter) if boxed else Vector2(glyph_size, glyph_size)
	icon_slot.set_meta(&"go_ink", ink)
	if boxed: _restyle_icon()


func _restyle_icon() -> void:
	var accent := _accent if _accent.a > 0 else GoUi.color(GoTheme.ACCENT)
	var diameter := float(GoUi.config.min_touch_size) - 4.0
	var panel := icon_slot.get_node_or_null(^"Disc") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "Disc"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_slot.add_child(panel)
		icon_slot.move_child(panel, 0)
	panel.add_theme_stylebox_override(&"panel", GoUi.skin().disc_box(diameter, accent))


func set_closable(on: bool) -> void:
	close_button.visible = on


## The list of action buttons. An item: `{"key"|"text", "action": Callable, "primary": bool, "disabled": bool, "name": String}`.
##
## 🛑 For the same shape (text, kind, name) the buttons are **not rebuilt** — when a server roster arrives every second
##    and the button under your finger disappears mid-redraw, the tap is lost. Only the action and the disabled state are refreshed.
func set_actions(list: Array) -> void:
	var shape := ""
	for item in list:
		shape += "%s|%s|%s|%s;" % [item.get("key", ""), item.get("text", ""),
			bool(item.get("primary", false)), item.get("name", "")]
	if shape == _action_shape and actions.get_child_count() == list.size():
		for i in list.size():
			var existing := actions.get_child(i) as Button
			if existing == null: continue
			existing.set_meta(&"go_action", list[i].get("action", Callable()))
			existing.disabled = bool(list[i].get("disabled", false))
		return
	_action_shape = shape
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	for item in list:
		var tone := GoStyle.Tone.PRIMARY if bool(item.get("primary", false)) else GoStyle.Tone.NORMAL
		if bool(item.get("danger", false)): tone = GoStyle.Tone.DANGER
		var node: Button
		if item.has("key"): node = GoStyle.button_key(str(item.key), Callable(), tone)
		else: node = GoStyle.button(str(item.get("text", "")), Callable(), tone)
		node.custom_minimum_size.y = GoUi.config.min_touch_size
		node.clip_text = true
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		node.disabled = bool(item.get("disabled", false))
		node.set_meta(&"go_action", item.get("action", Callable()))
		node.pressed.connect(func() -> void:
			var action: Callable = node.get_meta(&"go_action", Callable())
			if action.is_valid(): action.call())
		if item.has("name"): node.name = str(item.name)
		actions.add_child(node)
	actions.visible = not list.is_empty()


## The owning screen sets the width. The height it works out from its content.
##
## 🛑 The real height of a wrapping title only appears **the frame after** the width is settled — if the owning screen
##    lays other things out against the height it measured in between, the card grows one frame later and overlaps them.
##    So the title's natural width is measured with the font, the line count predicted, and folded into the minimum height.
func fit_width(width: float) -> void:
	custom_minimum_size.x = width
	size.x = width
	_predict_height(title_label, width)
	_predict_height(subtitle_label, width)
	reset_size()


func _predict_height(node: Label, width: float) -> void:
	var line := float(node.get_line_height())
	var lines := maxi(1, node.max_lines_visible)
	if node.autowrap_mode == TextServer.AUTOWRAP_OFF or lines <= 1 or not node.visible:
		node.custom_minimum_size.y = line
		return
	var panel := get_theme_stylebox(&"panel")
	var available := width - panel.get_margin(SIDE_LEFT) - panel.get_margin(SIDE_RIGHT)
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL))
	if icon_slot.visible: available -= maxf(icon_slot.custom_minimum_size.x, icon_slot.size.x) + gap
	if close_button.visible: available -= float(GoUi.config.min_touch_size) + gap
	var font := node.get_theme_font(&"font")
	var natural := 0.0
	if font != null:
		natural = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			node.get_theme_font_size(&"font_size")).x
	var needed := clampi(ceili(natural / maxf(1.0, available)), 1, lines)
	node.custom_minimum_size.y = line * needed


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not _title_key.is_empty(): title_label.text = tr(_title_key).format(_title_args)
		if not _subtitle_key.is_empty(): subtitle_label.text = tr(_subtitle_key).format(_subtitle_args)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and fade_in and is_inside_tree():
		_fade = GoStyle.fade(self, _fade, visible)


## Builds the close button. 🔑 A host that wants a `GoIconButton` subclass (its own art and size) overrides this in a subclass.
func _make_close_button() -> GoIconButton:
	return GoIconButton.new()
