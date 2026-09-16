## 🎬 A stage that shows **one thing at a time**.
##
## Every time the scene changes it is emptied and built again. The width is held to about one phone —
## that is the screen gohud aims at, and what holds up in a narrow width holds up in a wide one too.
class_name SimStage
extends PanelContainer

## "Back to the widget list" was pressed in a scene that covers the whole screen (forms, anchors) — the sidebar is hidden, so the scene reports it instead.
signal leave_requested

const WIDTH := 560.0

## Where the scene fills in.
var body: VBoxContainer
## The body scroll — some scenes roll it themselves.
var scroll: GoScroll
## Where things that must **float above the stage** attach — HUDs, sheets (it does not scroll).
var overlay: Control

var _column: VBoxContainer
var _badge: Label
var _title: Label
var _note: Label
var _fade: Tween


func _init() -> void:
	name = "Stage"
	theme = GoUi.theme()
	theme_type_variation = GoTheme.VAR_CARD
	custom_minimum_size.x = WIDTH
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var surface := GoStyle.surface(GoTheme.BOX_CARD)
	if GoUi.config.preset == GoThemePresets.DEFAULT_DARK:
		var flat := surface as StyleBoxFlat
		flat.bg_color = Color("#151f30")
		flat.border_color = Color("#2d435b")
		flat.set_corner_radius_all(20)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: surface.set_content_margin(side, 20)
	add_theme_stylebox_override(&"panel", surface)
	_column = GoStyle.column(GoUi.metric(GoTheme.GAP))
	add_child(_column)

	var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var accent := GoUi.color(GoTheme.ACCENT)
	_badge = GoStyle.label("00", GoTheme.ROLE_COMPACT, GoUi.skin().chip_ink(accent))
	GoStyle.natural_width(_badge)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.custom_minimum_size = Vector2(40, 26)
	_badge.add_theme_stylebox_override(&"normal", GoUi.skin().chip_box(accent))
	head.add_child(_badge)
	_title = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	_title.add_theme_font_size_override(&"font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_column.add_child(head)

	_note = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	_column.add_child(_note)
	_column.add_child(GoStyle.divider())

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(content)
	scroll = GoScroll.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scroll)
	body = GoStyle.column(GoUi.metric(GoTheme.GAP))
	scroll.add_child(body)

	# 🛑 Floating things sit **outside** the scroll — inside, they ride up with the body.
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(overlay)
	overlay.resized.connect(_layout_floats)


## Opens a new scene — clears it, swaps the heading, and fades in.
func open(number: String, title: String, note: String) -> void:
	clear()
	_badge.text = number
	_badge.visible = not number.is_empty()
	_title.text = title
	_note.text = note
	_note.visible = not note.is_empty()
	scroll.scroll_vertical = 0
	if is_instance_valid(_fade): _fade.kill()
	if GoUi.config.reduce_motion: return
	body.modulate.a = 0.0
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(body, "modulate:a", 1.0, 0.28)


## Clears **everything** a scene left behind.
##
## 🛑 The body and the floating layer are not enough — whatever a scene attached to the stage itself,
##    such as a dialog or a sheet, carries its own layer covering the whole screen, and left behind it
##    lives on, hiding the next scene.
func clear() -> void:
	if is_instance_valid(_fade): _fade.kill()
	body.modulate.a = 1.0
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	for child in get_children():
		if child != _column:
			remove_child(child)
			child.queue_free()


## Adds to the body and hands it straight back — used as `var button := stage.add(GoStyle.button(…))`.
func add(node: Control) -> Control:
	body.add_child(node)
	return node


## One heading line plus what follows it, as a single group.
func group(title: String) -> VBoxContainer:
	body.add_child(GoStyle.section(title, false))
	var box := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	body.add_child(box)
	return box


## Floats it above the stage (HUD bars, slots, notice cards). `preset` is a spot such as `Control.PRESET_TOP_LEFT`.
##
## 🛑 Do not use `GoHudAnchor` here — it is a widget that pins to **the four corners of the screen
##    (the window)**, safe area included, so a spot taken from the window size is read again in stage
##    coordinates and pushed off screen (measured 2026-09-12: a slot ended up at x=2108). In a real
##    game `GoHudAnchor` on the screen root is the right thing; only inside this stage do we imitate it.
func float_at(node: Control, preset: int, margin := 10) -> Control:
	node.set_meta(&"sim_float", {"preset": preset, "margin": margin})
	overlay.add_child(node)
	node.minimum_size_changed.connect(_layout_floats.call_deferred)
	_layout_floats.call_deferred()
	return node


func _layout_floats() -> void:
	for node in overlay.get_children():
		if not node is Control or not node.has_meta(&"sim_float"): continue
		var spec: Dictionary = node.get_meta(&"sim_float")
		var align := Vector2.ZERO
		match spec.preset:
			Control.PRESET_BOTTOM_RIGHT: align = Vector2.ONE
			Control.PRESET_CENTER_RIGHT: align = Vector2(1.0, 0.5)
			Control.PRESET_CENTER_TOP: align = Vector2(0.5, 0.0)
		var margin := Vector2.ONE * float(spec.margin)
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.size = node.get_combined_minimum_size()
		node.position = margin + (overlay.size - node.size - margin * 2.0) * align
