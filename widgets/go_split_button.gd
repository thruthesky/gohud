## 🔀 **Split button** — a main action with its close variants one press away: "Send ▾" (send later, send as draft),
## "Post ▾" (post to a group), "Buy now ▾" (buy as a gift). The label half runs the action; the arrow half opens a menu.
##
## ```gdscript
## var send := GoSplitButton.make("Send", send_now, [
## 	{"text": "Send later", "action": schedule},
## 	{"text": "Save as draft", "action": save_draft},
## ], GoStyle.Tone.PRIMARY)
## footer.add_child(send)
## ```
##
## ## 🔑 When it fits
## One action people pick most of the time, plus a few they need now and then. When the choices are equal, a dropdown
## (`GoStyle.dropdown`) or a segmented control says that better.
##
## ## 🔑 The look
## The two halves are the theme's own button faces for [param tone], joined: the outer sides keep the button's corner,
## the inner sides are squared (`GoSkin.split_button_box`). Under Material the inner corner is 4dp, 12dp while pressed,
## and the arrow half turns into a full pill while its menu is open (`_md-comp-split-button-small.scss`).
@tool
class_name GoSplitButton
extends HBoxContainer

## A menu item was picked — its index in the items given to `make()`.
signal chosen(index: int)

## The half with the label — the main action.
var main_button: Button
## The half with the arrow — it opens the menu.
var menu_button: MenuButton

var _tone := 0
var _actions: Array[Callable] = []


func _init() -> void:
	name = "SplitButton"
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# `_md-comp-split-button-small.scss` between-space.
	add_theme_constant_override(&"separation", 2)


func _ready() -> void:
	_restyle()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A split button labelled [param text] running [param action], with [param items] in its menu — each a String or
## `{"text": String, "action": Callable, "disabled": bool}`. [param tone] is a `GoStyle.Tone`.
static func make(text: String, action: Callable, items: Array, tone := GoStyle.Tone.PRIMARY,
		translate := false) -> GoSplitButton:
	var node := GoSplitButton.new()
	node._tone = tone
	node.main_button = GoStyle.button(text, action, tone)
	node.main_button.name = "Main"
	node.main_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate \
		else Node.AUTO_TRANSLATE_MODE_DISABLED
	GoStyle.natural_width(node.main_button)
	node.add_child(node.main_button)
	var arrow := MenuButton.new()
	arrow.name = "Menu"
	arrow.flat = false
	GoStyle.style_button(arrow, tone)
	arrow.custom_minimum_size = Vector2(GoUi.metric(GoTheme.TOUCH), GoUi.metric(GoTheme.BUTTON_HEIGHT))
	arrow.mouse_filter = Control.MOUSE_FILTER_PASS
	arrow.tooltip_text = GoUi.text(&"more")
	arrow.accessibility_name = arrow.tooltip_text
	GoScroll.yield_vertical(arrow)   # it opens on the press — an up-and-down swipe that starts on it scrolls the list
	node.menu_button = arrow
	node.add_child(arrow)
	var popup := arrow.get_popup()
	popup.theme = GoUi.theme()
	for item in items:
		var spec: Dictionary = item if item is Dictionary else {"text": str(item)}
		popup.add_item(str(spec.get("text", "")))
		if bool(spec.get("disabled", false)): popup.set_item_disabled(popup.item_count - 1, true)
		var run: Callable = spec.get("action", Callable())
		node._actions.append(run)
	popup.index_pressed.connect(func(index: int) -> void:
		node.chosen.emit(index)
		if index < node._actions.size() and node._actions[index].is_valid(): node._actions[index].call())
	popup.about_to_popup.connect(node._restyle)
	popup.popup_hide.connect(node._restyle)
	return node


## Puts the joined faces on both halves, and the arrow that points the way the menu is.
func _restyle() -> void:
	if main_button == null or menu_button == null: return
	var skin := GoUi.skin()
	var open := menu_button.get_popup().visible
	for pair in [[main_button, true], [menu_button, false]]:
		var half: Button = pair[0]
		half.theme = GoUi.theme()
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			var face := _face(half.theme_type_variation, state)
			var shown: StringName = &"pressed" if state == &"hover_pressed" else state
			if not pair[1] and open and state == &"normal": shown = &"pressed"
			half.add_theme_stylebox_override(state, skin.split_button_box(face, pair[1], shown, open))
	var old := menu_button.get_node_or_null(^"IconGlyph")
	if old != null:
		menu_button.remove_child(old)
		old.queue_free()
	menu_button.icon = null
	var ink := GoUi.theme_color_of(menu_button, &"font_color", GoUi.color(GoTheme.TEXT))
	GoStyle.apply_icon(menu_button, GoIconSet.CHEVRON_UP if open else GoIconSet.CHEVRON_DOWN, 22, ink)
	menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var glyph := menu_button.get_node_or_null(^"IconGlyph") as Control
	if glyph != null: glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## A copy of the theme's [param state] face for a button of type [param variation] (walking up its base types).
static func _face(variation: StringName, state: StringName) -> StyleBox:
	for look in [GoUi.theme(), GoUi.DEFAULT_THEME]:
		if look == null: continue
		var type := variation if not variation.is_empty() else &"Button"
		while not type.is_empty():
			if look.get_stylebox_list(type).has(state): return look.get_stylebox(state, type).duplicate()
			type = look.get_type_variation_base(type) if type != &"Button" else &""
		if look.get_stylebox_list(&"Button").has(state): return look.get_stylebox(state, &"Button").duplicate()
	return StyleBoxEmpty.new()


func _on_ui_changed() -> void:
	if main_button != null: GoStyle.style_button(main_button, _tone)
	if menu_button != null: GoStyle.style_button(menu_button, _tone)
	_restyle()
