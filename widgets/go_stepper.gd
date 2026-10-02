## 🪜 **Steps** — a checkout, a sign-up, a setup wizard: numbered steps, the current one open, Next and Back under it
## (Flutter's `Stepper`).
##
## ```gdscript
## var checkout := GoStepper.make([
## 	{"title": "Address", "content": address_form},
## 	{"title": "Payment", "subtitle": "Card or wallet", "content": payment_form},
## 	{"title": "Review", "content": summary},
## ])
## checkout.finished.connect(place_order)
## checkout.can_continue = func(index: int) -> bool: return forms[index].is_valid()   # optional gate
## ```
##
## ## 🔑 Two layouts
## `VERTICAL` (default) stacks the steps with the open one's content under its title — it fits a phone at any length.
## `HORIZONTAL` puts the numbered steps in a row with the content below — for three or four short titles on a wider
## screen.
##
## ## 🔑 Going back is free, going forward is checked
## A tap on a finished step's title goes back to it. Next runs `can_continue(index)` first (when set) and stays put
## when it says no — mark the step with `set_error(index, true)` to show what is wrong. The last step's button says
## Done and emits `finished`.
@tool
class_name GoStepper
extends VBoxContainer

## The open step changed.
signal step_changed(index: int)
## Done was pressed on the last step.
signal finished

enum Layout {
	VERTICAL,    ## Steps stacked, the open one's content under its title.
	HORIZONTAL,  ## Steps in a row, the content below.
}

@export var layout := Layout.VERTICAL:
	set(value):
		layout = value
		_rebuild()

## Called with the open step's index before moving on; return `false` to stay. Empty lets every step through.
var can_continue := Callable()

## Side of a step's number disc (dp).
const MARKER := 24.0

var _steps: Array[Dictionary] = []
var _index := 0
var _reached := 0
var _errors := {}


func _init() -> void:
	name = "Stepper"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 0)


func _ready() -> void:
	_rebuild()
	GoUi.watch(_rebuild)


func _exit_tree() -> void:
	GoUi.unwatch(_rebuild)


## Steps from [param steps] — `{"title", "subtitle", "content": Control}` each — with [param current] open.
static func make(steps: Array, current := 0, translate := false) -> GoStepper:
	var node := GoStepper.new()
	for spec: Dictionary in steps:
		var each := spec.duplicate()
		each["translate"] = translate
		node._steps.append(each)
	node._index = clampi(current, 0, maxi(0, steps.size() - 1))
	node._reached = node._index
	return node


## The open step.
func current() -> int:
	return _index


## Opens step [param index] (any step up to the furthest one reached; further only with [param force]).
func set_step(index: int, force := false) -> void:
	index = clampi(index, 0, maxi(0, _steps.size() - 1))
	if index > _reached and not force: return
	if index == _index: return
	_index = index
	_reached = maxi(_reached, index)
	_rebuild()
	step_changed.emit(index)


func _notification(what: int) -> void:
	# The contents of the steps that are not open are out of the tree — they go with the stepper.
	if what == NOTIFICATION_PREDELETE:
		for spec in _steps:
			var content: Control = spec.get("content")
			if is_instance_valid(content) and content.get_parent() == null: content.free()


## Moves on (through `can_continue`), or finishes on the last step.
func next() -> void:
	if can_continue.is_valid() and not bool(can_continue.call(_index)):
		GoFeedback.canceled()
		return
	_errors.erase(_index)
	if _index >= _steps.size() - 1:
		GoFeedback.confirmed()
		finished.emit()
		_rebuild()
		return
	GoFeedback.tapped()
	set_step(_index + 1, true)


## Goes back one step.
func back() -> void:
	if _index > 0: set_step(_index - 1)


## Marks step [param index] as wrong (or clears it) — its number turns into a warning mark.
func set_error(index: int, wrong: bool) -> void:
	if wrong: _errors[index] = true
	else: _errors.erase(index)
	_rebuild()


## Where a step stands: `&"done"`, `&"active"`, `&"todo"` or `&"error"`.
func state_of(index: int) -> StringName:
	if _errors.has(index): return &"error"
	if index == _index: return &"active"
	return &"done" if index < _reached or index < _index else &"todo"


func _rebuild() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# The step contents are the caller's nodes — taken out, never freed.
	for spec in _steps:
		var content: Control = spec.get("content")
		if is_instance_valid(content) and content.get_parent() != null: content.get_parent().remove_child(content)
	if layout == Layout.HORIZONTAL: _build_row()
	else: _build_column()


func _build_column() -> void:
	for at in _steps.size():
		var spec := _steps[at]
		add_child(_header(at, true))
		var body := HBoxContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_theme_constant_override(&"separation", 0)
		add_child(body)
		# The rail: a line under the disc down to the next step.
		var rail := Control.new()
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.custom_minimum_size = Vector2(MARKER + GoUi.metric(GoTheme.GAP) * 2.0, GoUi.metric(GoTheme.GAP))
		var last := at == _steps.size() - 1
		if not last:
			var line := ColorRect.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.color = GoUi.skin().divider_color()
			line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			line.offset_left = GoUi.metric(GoTheme.GAP) + MARKER * 0.5 - 0.5
			line.offset_right = line.offset_left + 1.0
			rail.add_child(line)
		body.add_child(rail)
		if at == _index:
			var holder := VBoxContainer.new()
			holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			holder.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
			var content: Control = spec.get("content")
			if is_instance_valid(content):
				content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				holder.add_child(content)
			holder.add_child(_controls())
			var pad := MarginContainer.new()
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pad.add_theme_constant_override(&"margin_bottom", GoUi.metric(GoTheme.GAP))
			pad.add_theme_constant_override(&"margin_right", GoUi.metric(GoTheme.GAP))
			pad.add_child(holder)
			body.add_child(pad)


func _build_row() -> void:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 0)
	add_child(line)
	for at in _steps.size():
		if at > 0:
			var joint := ColorRect.new()
			joint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			joint.color = GoUi.skin().divider_color()
			joint.custom_minimum_size = Vector2(GoUi.metric(GoTheme.GAP_SMALL), 1.0)
			joint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			joint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(joint)
		var head := _header(at, false)
		head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		line.add_child(head)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_" + side, GoUi.metric(GoTheme.GAP))
	pad.add_child(holder)
	add_child(pad)
	var content: Control = _steps[_index].get("content") if not _steps.is_empty() else null
	if is_instance_valid(content):
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(content)
	holder.add_child(_controls())


## A step's head: the disc with its number (a check when done, a mark when wrong) and the title beside it.
## A finished step's head is pressable — it goes back to that step.
func _header(at: int, wide: bool) -> Button:
	var spec := _steps[at]
	var state := state_of(at)
	var skin := GoUi.skin()
	var head := Button.new()
	head.name = "Step%d" % at
	head.theme = GoUi.theme()
	head.theme_type_variation = GoTheme.VAR_LIST_BUTTON
	head.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH) + 8.0
	head.focus_mode = Control.FOCUS_ALL
	head.disabled = at > _reached
	if wide: head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GoScroll.scroll_through(head)
	head.pressed.connect(set_step.bind(at))
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override(&"margin_left", GoUi.metric(GoTheme.GAP))
	pad.add_theme_constant_override(&"margin_right", GoUi.metric(GoTheme.GAP))
	head.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	pad.add_child(row)
	var disc := PanelContainer.new()
	disc.name = "Marker"
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2.ONE * MARKER
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_theme_stylebox_override(&"panel", skin.step_marker_box(state))
	row.add_child(disc)
	var ink := skin.step_marker_ink(state)
	if state == &"done" or state == &"error":
		var mark := GoUi.icons().node(GoIconSet.CHECK if state == &"done" else GoIconSet.WARNING, 16, ink)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		disc.add_child(mark)
	else:
		var number := GoStyle.label(str(at + 1), GoTheme.ROLE_COMPACT, ink)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.autowrap_mode = TextServer.AUTOWRAP_OFF
		number.set_meta(&"go_no_wrap", true)
		disc.add_child(number)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override(&"separation", 0)
	row.add_child(words)
	var translate := bool(spec.get("translate", false))
	var title_ink := GoUi.color(GoTheme.DANGER) if state == &"error" else \
		(GoUi.color(GoTheme.TEXT) if state != &"todo" else GoUi.color(GoTheme.MUTED))
	var title_text := str(spec.get("title", ""))
	var title := GoStyle.label_key(title_text, GoTheme.ROLE_BUTTON, title_ink) if translate \
		else GoStyle.label(title_text, GoTheme.ROLE_BUTTON, title_ink)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.set_meta(&"go_no_wrap", true)
	words.add_child(title)
	var sub := str(spec.get("subtitle", ""))
	if not sub.is_empty() and wide:
		var note := GoStyle.label_key(sub, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)) if translate \
			else GoStyle.label(sub, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED))
		note.autowrap_mode = TextServer.AUTOWRAP_OFF
		note.set_meta(&"go_no_wrap", true)
		words.add_child(note)
	head.accessibility_name = GoUi.spoken([GoUi.text(&"coach_progress").format({"step": at + 1, "total": _steps.size()}),
		tr(title_text) if translate else title_text])
	return head


## Next (Done on the last step) and Back.
func _controls() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))
	var last := _index >= _steps.size() - 1
	var go := GoStyle.button(GoUi.text(&"done" if last else &"next"), next, GoStyle.Tone.PRIMARY)
	go.name = "Next"
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(go)
	if _index > 0:
		var back_button := GoStyle.button(GoUi.text(&"back"), back, GoStyle.Tone.BARE)
		back_button.name = "Back"
		row.add_child(back_button)
	return row
