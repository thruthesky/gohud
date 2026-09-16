## Settings screen built with gohud: foldable sections, a width-capped GoForm, Back with a
## discard check, Reset and Save. Copy to your project (e.g. res://ui/settings_menu.gd) and attach it
## to a full-screen Control, or `add_child(preload("res://ui/settings_menu.gd").new())`.
## Changes are kept in a draft and applied on Save (GoConfig, preset, locale, audio buses, window mode).
extends Control

signal closed(saved: bool)
signal settings_changed(values: Dictionary)

const DEFAULTS := {
	"preset": "default_dark", "quality": 1, "fullscreen": false,
	"master_volume": 0.8, "music_volume": 0.6,
	"vibration": true, "reduce_motion": false, "language": "en",
}
## Locale code and its name written in that language. Non-Latin names need a font with those glyphs.
const LANGUAGES := [["en", "English"], ["es", "Español"], ["de", "Deutsch"], ["fr", "Français"]]

var settings: Dictionary = DEFAULTS.duplicate()
var dialogs: GoDialogs
var _draft: Dictionary = {}


func _ready() -> void:
	if not GoUi.config.preset.is_empty():
		settings.preset = String(GoUi.config.preset)
	_draft = settings.duplicate()
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE
	var background := ColorRect.new()
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var form := GoForm.new()
	var scroll := GoScroll.new()
	var page := GoStyle.column()
	form.add_child(scroll)
	scroll.add_child(page)

	var header := GoStyle.row()
	var back := GoStyle.button("Back", request_back, GoStyle.Tone.COMPACT)
	back.name = "BackButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(back)
	var title := GoStyle.label("Settings", GoTheme.ROLE_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	page.add_child(header)

	var accordion := FoldableGroup.new()       # one section open at a time — short on phones

	var display := _section(page, "Display", false, accordion)
	var presets := GoThemePresets.all()
	var labels: Array = []
	var current := 0
	for index in presets.size():
		labels.append(presets[index].label())
		if String(presets[index].id) == String(_draft.preset):
			current = index
	var picker := GoStyle.select(labels)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.selected = current
	picker.item_selected.connect(_on_preset.bind(presets))
	display.add_child(_field("Look", picker))
	display.add_child(_field("Quality", GoStyle.segmented(["Low", "Mid", "High"], _draft.quality, _on_quality)))
	display.add_child(_toggle("Fullscreen", "fullscreen"))

	var audio := _section(page, "Audio", true, accordion)
	audio.add_child(_volume("Master volume", "master_volume"))
	audio.add_child(_volume("Music", "music_volume"))

	var controls := _section(page, "Controls & accessibility", true, accordion)
	controls.add_child(_toggle("Vibration", "vibration"))
	controls.add_child(_toggle("Reduce motion", "reduce_motion"))

	var language := _section(page, "Language", true, accordion)
	var names: Array = LANGUAGES.map(func(pair: Array) -> String: return pair[1])
	var codes: Array = LANGUAGES.map(func(pair: Array) -> String: return pair[0])
	var radios := GoStyle.radio_group(names, maxi(0, codes.find(_draft.language)))
	(radios.get_meta(&"group") as ButtonGroup).pressed.connect(_on_language.bind(codes))
	language.add_child(radios)

	var actions := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	actions.add_child(GoStyle.button("Reset", reset_to_defaults, GoStyle.Tone.BARE))
	actions.add_child(GoStyle.button("Save", save, GoStyle.Tone.PRIMARY))
	page.add_child(actions)

	# 🛑 GoForm routes Android Back to %BackButton, looked up once in _ready through the form's owner. gohud 1.0.3 and
	#    older cleared `owner = form` (or a holder owning just the form and the button) when _ready moved the scroll into
	#    its edge frame — Godot's reparent() keeps only owners shared with the moved node (measured, 4.7.2). A holder
	#    that owns the WHOLE branch (form, scroll, containers, button), like a .tscn root, works on every version.
	var holder := Control.new()
	holder.name = "Screen"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(form)
	for node in holder.find_children("*", "", true, false):
		node.owner = holder
	back.unique_name_in_owner = true
	add_child(holder)                          # GoForm._ready runs now: finds Scroll and %BackButton
	dialogs = GoDialogs.new()
	add_child(dialogs)


func save() -> void:
	var look_changed := String(_draft.preset) != String(settings.preset)
	settings = _draft.duplicate()
	_apply(settings)
	GoFeedback.confirmed()
	settings_changed.emit(settings.duplicate())
	closed.emit(true)
	if look_changed:
		build()                                # nodes keep the theme they were built with


func request_back() -> void:
	if not _draft.recursive_equal(settings, 2):
		var discard := await dialogs.confirm("Discard changes?", "Your changes have not been saved.",
			"Discard", "Keep editing", "", {}, true)
		if not discard:
			return
		_draft = settings.duplicate()
	closed.emit(false)


func reset_to_defaults() -> void:
	var look: String = _draft.preset
	_draft = DEFAULTS.duplicate()
	_draft.preset = look
	build()                                    # shows the defaults; nothing applies until Save


func _apply(values: Dictionary) -> void:
	GoUi.config.reduce_motion = values.reduce_motion
	GoUi.config.haptics_enabled = values.vibration
	if String(GoUi.config.preset) != String(values.preset):
		GoUi.use_preset(StringName(values.preset))
	GoUi.refresh()
	TranslationServer.set_locale(values.language)
	for bus in [["Master", "master_volume"], ["Music", "music_volume"]]:
		var index := AudioServer.get_bus_index(bus[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(values[bus[1]]), 0.0001)))
	if not GoUi.is_handheld_platform() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)


# ── Building blocks ──────────────────────────────────────────────────────

func _section(parent: Control, title: String, folded: bool, group: FoldableGroup) -> VBoxContainer:
	var fold := GoStyle.foldable(title, folded, group, false)
	var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	fold.add_child(inner)
	parent.add_child(fold)
	return inner


## A labelled row. `GoField` is exactly this shape — label, control, optional hint — and it adds the
## one thing a hand-rolled column cannot do: `set_error("…")` marks **this** box, writes the reason
## under it, and makes that reason the control's accessible description.
##
## ```gdscript
## var name_row := _field("Player name", GoStyle.line_edit("2-16 characters"), "Others see this")
## name_row.set_error("That name is taken")      # and clear_error() when it validates
## ```
func _field(caption: String, control: Control, hint := "") -> GoField:
	return GoField.make(caption, control, hint)


func _toggle(text: String, key: String) -> CheckButton:
	var node := GoStyle.toggle(text, false)
	node.button_pressed = _draft[key]
	node.toggled.connect(_change.bind(key))
	return node


func _volume(caption: String, key: String) -> VBoxContainer:
	var line := GoStyle.row()
	line.add_child(GoStyle.label(caption, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	var readout := GoStyle.label("%d%%" % roundi(_draft[key] * 100.0), GoTheme.ROLE_CAPTION)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text_direction = Control.TEXT_DIRECTION_LTR
	line.add_child(readout)
	var slider := GoStyle.slider(0.0, 1.0, 0.05)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = _draft[key]
	slider.value_changed.connect(_on_volume.bind(key, readout))
	var box := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	box.add_child(line)
	box.add_child(slider)
	return box


func _change(value: Variant, key: String) -> void:
	_draft[key] = value


func _on_quality(index: int) -> void:
	_draft.quality = index


func _on_preset(index: int, presets: Array) -> void:
	_draft.preset = String(presets[index].id)


func _on_language(button: BaseButton, codes: Array) -> void:
	_draft.language = codes[button.get_index()]


func _on_volume(value: float, key: String, readout: Label) -> void:
	_draft[key] = value
	readout.text = "%d%%" % roundi(value * 100.0)
