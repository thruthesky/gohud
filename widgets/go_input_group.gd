## 🔗 **A joined input group** — makes an input and the button beside it look like **one piece**.
##
## ```gdscript
## # Chat — field + send
## var chat := GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": GoStyle.icon_button(&"send", send)})
##
## # Coupon — field + confirm
## var coupon := GoInputGroup.make(GoStyle.line_edit("Code"), {"suffix": GoStyle.button("Confirm", redeem)})
##
## # Search — magnifier + field
## var search := GoInputGroup.make(GoStyle.line_edit("Name"), {"prefix_icon": &"search"})
##
## # Quantity — − field +
## var amount := GoInputGroup.make(field, {"prefix": minus_button, "suffix": plus_button})
## ```
##
## ## 🛑 The problem this solves is the **corners**
## Drop an input and a button side by side in a plain `HBoxContainer` and two pairs of rounded corners meet in the
## middle, pinching the shape, with a gap opening between them on top of that — "two things that don't belong together".
## Here only the outer corners are rounded and **the inner ones that touch are squared off**, so it reads as one piece.
##
## ## 🔑 The separation is 0
## They are joined on purpose. To keep them apart, don't use this widget — just put them side by side in a `GoStyle.row()`.
##
## ## 🛑 On angular skins the corners are left alone
## **Panels the skin draws itself** (`GoStyleBoxCut`, `GoStyleBoxBracket`), as in sci-fi and medieval, have no
## `corner_radius_*` field at all — the notion of a rounded corner does not exist there. In that case the corners are
## left untouched and a separation of 0 joins them. Angular panels never look pinched where they meet, so that is enough.
@tool
class_name GoInputGroup
extends HBoxContainer

## The input in the middle.
var control: Control
## What is attached in front, on the left — `null` when there is none.
var prefix: Control
## What is attached behind, on the right — `null` when there is none.
var suffix: Control


func _init() -> void:
	name = "InputGroup"
	# 🔑 **0 is the whole point** — any gap and it stops looking like one piece.
	add_theme_constant_override(&"separation", 0)


func _ready() -> void:
	_restyle()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Builds a group by attaching things in front of and behind one input.
##
## | Field | Meaning |
## |---|---|
## | `prefix` | the `Control` to attach on the left (a button, …) |
## | `suffix` | the `Control` to attach on the right |
## | `prefix_icon` | **just an icon** on the left (an unpressable mark — magnifier, padlock) |
## | `suffix_icon` | just an icon on the right |
static func make(node: Control, parts := {}) -> GoInputGroup:
	var group := GoInputGroup.new()
	var head: Control = parts.get("prefix")
	if head == null and parts.has("prefix_icon"): head = _mark(StringName(parts["prefix_icon"]))
	var tail: Control = parts.get("suffix")
	if tail == null and parts.has("suffix_icon"): tail = _mark(StringName(parts["suffix_icon"]))

	if head != null:
		group.prefix = head
		group.add_child(head)
	group.control = node
	if node != null:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_child(node)
	if tail != null:
		group.suffix = tail
		group.add_child(tail)
	return group


## An unpressable mark (magnifier, padlock) — one icon cell riding on the same panel as the input.
static func _mark(icon: StringName) -> Control:
	var box := PanelContainer.new()
	box.name = "Mark"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := GoUi.metric(GoTheme.ICON_SIZE)
	var glyph := GoUi.icons().node(icon, px, GoUi.color(GoTheme.MUTED))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := GoStyle.padding(GoUi.metric(GoTheme.COMPACT_PADDING_X), GoUi.metric(GoTheme.COMPACT_PADDING_Y))
	pad.add_child(glyph)
	box.add_child(pad)
	return box


## Flattens the corners where the pieces touch. Only the outer ones stay round; the inner ones go square.
##
## 🛑 **It has to be done for every state** — fix `normal` alone and the old rounded corner is back the moment the piece
##    is pressed or focused, splitting the group for an instant. A button uses `normal`, `hover`, `pressed`, `disabled` and `focus`.
func _restyle() -> void:
	var parts: Array[Control] = []
	for node in [prefix, control, suffix]:
		if is_instance_valid(node): parts.append(node)
	if parts.size() < 2: return
	var radius := float(GoUi.metric(GoTheme.RADIUS))
	for index in parts.size():
		var node := parts[index]
		var round_left := index == 0
		var round_right := index == parts.size() - 1
		for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"panel", &"read_only"]:
			if not node.has_theme_stylebox(state): continue
			var face := node.get_theme_stylebox(state).duplicate()
			if not (&"corner_radius_top_left" in face): continue
			face.set(&"corner_radius_top_left", radius if round_left else 0.0)
			face.set(&"corner_radius_bottom_left", radius if round_left else 0.0)
			face.set(&"corner_radius_top_right", radius if round_right else 0.0)
			face.set(&"corner_radius_bottom_right", radius if round_right else 0.0)
			node.add_theme_stylebox_override(state, face)


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", 0)
	# The corner radius changes with the theme — drop the overrides and flatten again from the new panels.
	for node in [prefix, control, suffix]:
		if not is_instance_valid(node): continue
		for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"panel", &"read_only"]:
			node.remove_theme_stylebox_override(state)
	_restyle()
