## 🏷 **One form row** — label · input · hint · error bundled into a single unit.
##
## ```gdscript
## var name_field := GoField.make("Character name", GoStyle.line_edit("2~12 characters"), "You cannot change this later")
## form.add_child(name_field)
##
## # The server rejected it
## name_field.set_error("That name is already taken")
## # Fixed
## name_field.clear_error()
## ```
##
## ## 🛑 An error belongs **beside the field it came from**
## A single "please check your input" line at the top of the form leaves you guessing which of five fields is wrong.
## In a signup form that one thing is what makes people quit. So the error appears **right under the offending field**,
## and that field's border turns the danger color with it.
##
## ## ♿ Color alone never carries the message
## To someone with a color vision deficiency a red border alone is **no change at all.** So an error always
## shows **as text too** (`error_label`), and goes into the name a screen reader reads.
##
## ## 🔑 Hint and error never compete for the same space
## When the error appears the hint hides — stacking both suddenly adds two lines and shoves every field below down.
## When the error clears the hint comes back.
@tool
class_name GoField
extends VBoxContainer

## An error appeared or cleared.
signal error_changed(message: String)

## The label row.
var label: Label
## The input it wraps (`line_edit`, `select`, any `Control`).
var control: Control
## The hint row — visible only while there is no error.
var hint_label: Label
## The error row — visible only while there is an error.
var error_label: Label

var _error := ""
var _label_key := ""
var _hint_key := ""
var _error_key := ""
## Whether label and hint are treated as translation keys (`make()` decides).
var _translate := false
## 🛑 The error text is tracked **separately**. If passing a server error code as a translation key once made
##    the label and hint keys too, a raw key like `field_guild_name` would show up on screen from then on.
var _translate_error := false
## The input's border before the error was painted on — restored as-is when it clears.
var _plain_face: StyleBox


func _init() -> void:
	name = "Field"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))

	label = GoStyle.label("", GoTheme.ROLE_CAPTION)
	label.name = "Label"
	add_child(label)

	hint_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	hint_label.name = "Hint"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = false
	add_child(hint_label)

	error_label = GoStyle.label("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.DANGER))
	error_label.name = "Error"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	add_child(error_label)


func _ready() -> void:
	_retranslate()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Builds one row from a label, an input and a hint.
## With `translate` on, all three strings are treated as **translation keys**.
static func make(label_text: String, node: Control, hint := "", translate := false) -> GoField:
	var field := GoField.new()
	field._translate = translate
	field._label_key = label_text
	field._hint_key = hint
	field.set_control(node)
	field._retranslate()
	return field


## Sets the input (replacing one already there). It goes **right under** the label, above the hint.
func set_control(node: Control) -> void:
	if is_instance_valid(control):
		remove_child(control)
		control.queue_free()
	control = node
	_plain_face = null
	if not is_instance_valid(node): return
	add_child(node)
	# Label → input → hint → error, in that order.
	move_child(node, 1)
	# ♿ A screen reader has to know "what does this field take" — a label is not information for the eyes only.
	_sync_accessibility()


## Shows an error. An empty string is the same as `clear_error()`.
## 🔑 With `translate` on it is treated as a **translation key** — you can pass a server code (`err_name_taken`) straight through.
func set_error(message: String, translate := false) -> void:
	_error_key = message
	_translate_error = translate
	_error = message
	# 🛑 **Fill the text first.** `_apply_error()` builds the accessibility name out of this text, so a swapped
	#    order feeds the screen reader the old error (or an empty one) — it looks fine to the eye, so it is easy to miss.
	error_label.text = tr(_error_key) if _translate_error else _error_key
	error_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_apply_error()
	error_changed.emit(message)


func clear_error() -> void:
	set_error("")


func has_error() -> bool:
	return not _error.is_empty()


## The current error text (translated).
func error_text() -> String:
	return error_label.text


func _apply_error() -> void:
	var shown := not _error.is_empty()
	error_label.visible = shown
	# 🔑 Hint and error never compete for space — stacked together they add two lines and shove everything below down.
	hint_label.visible = not shown and not hint_label.text.is_empty()
	_paint_control(shown)
	_sync_accessibility()


## Paints the input's border the danger color, or puts it back.
## 🛑 **Only the color changes** — changing the border width too shifts the field by 1dp and the whole row jitters.
func _paint_control(bad: bool) -> void:
	if not is_instance_valid(control): return
	for state in [&"normal", &"focus"]:
		if not control.has_theme_stylebox(state): continue
		if not bad:
			control.remove_theme_stylebox_override(state)
			continue
		var face := control.get_theme_stylebox(state).duplicate()
		if &"border_color" in face: face.set(&"border_color", GoUi.color(GoTheme.DANGER))
		control.add_theme_stylebox_override(state, face)


## ♿ Joins label, hint and error **into one sentence** on the input. A screen reader reads it on entering the field.
func _sync_accessibility() -> void:
	if not is_instance_valid(control): return
	var parts: Array[String] = [label.text]
	if error_label.visible: parts.append(error_label.text)
	elif hint_label.visible: parts.append(hint_label.text)
	control.accessibility_name = GoUi.spoken(parts)


func _retranslate() -> void:
	label.text = tr(_label_key) if _translate else _label_key
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hint_label.text = tr(_hint_key) if _translate else _hint_key
	hint_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	error_label.text = tr(_error_key) if _translate_error else _error_key
	error_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.visible = not label.text.is_empty()
	_apply_error()


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	GoStyle.typography(label, GoTheme.ROLE_CAPTION)
	GoStyle.typography(hint_label, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	GoStyle.typography(error_label, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.DANGER))
	_apply_error()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _retranslate()
