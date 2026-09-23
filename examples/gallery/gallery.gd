## 🖼️ **The gohud gallery** — every widget opened on one screen, with no server and no game.
##
## This file is both an example and a **living test**. Change a widget, bring this up, and you see it there and then.
##
## ```
## godot res://addons/gohud/examples/gallery/gallery.tscn
## ```
##
## 🛑 It leans on no autoload, server or account of the project — it must open in an empty project with
##    nothing but the add-on. That is why this example exists.
extends Control

## 🔬 The container-opacity lab — the sim tour and the home screen use this same file.
const OpacityLab := preload("opacity_lab.gd")
const ListLab := preload("list_lab.gd")

var _sheet: GoSheet
var _dialogs: GoDialogs
var _notice: GoNotice
var _prompt: GoPromptCard
var _joystick: GoJoystick
var _hp: GoBar
var _slots: Array[GoSlot] = []
var _log: Label
var _dark := true
var _tour: GoCoachMark
var _snackbar: GoSnackbar
var _drawer: GoDrawer
var _console: GoConsole
var _gallery_field: GoField
var _popover_anchor: Button
var _menu_anchor: Button
## Is the backdrop pattern on? 🔑 `_rebuild()` calls this node's `_ready` again, so this value survives it.
var _busy_background := false


func _ready() -> void:
	name = "Gallery"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()

	var background := ColorRect.new()
	background.name = "Background"
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 🔬 **To see container opacity you need something other than a flat color behind it.** The toggle in
	#    the opacity section turns this on — with it on the whole screen becomes "over the game", and what
	#    every panel lets through is plain at a glance.
	var busy := OpacityLab.Backdrop.new()
	busy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 🛑 **Lay it on faintly.** Inside the preview box it must be crisp, but a crisp pattern across the
	#    whole screen leaves not one readable line of body text outside a panel (measured on the first
	#    capture, 2026-09-16). A real game's background is about this strong too — which is why text with
	#    no panel under it survives.
	busy.intensity = 0.3
	busy.visible = _busy_background
	add_child(busy)

	_build_page()
	_build_hud()

	_dialogs = GoDialogs.new()
	add_child(_dialogs)
	_sheet = GoSheet.new()
	add_child(_sheet)


# ── The scrolling body ─────────────────────────────────────────────────

func _build_page() -> void:
	var form := GoForm.new()
	form.name = "Form"
	add_child(form)
	# 🛑 **Keep clear of the floating HUD.** Left alone, the scrolling content runs behind the quick slots
	#    and the text pokes out through the gaps between them — which is exactly what happened in RTL,
	#    where the field text moves to the right (measured on the Arabic screenshot, 2026-09-13). The form
	#    avoids the spots the `GoHudAnchor`s hold, on its own.
	form.avoid_hud = true

	var scroll := GoScroll.new()
	scroll.name = "Scroll"
	form.add_child(scroll)

	var page := GoStyle.column()
	page.name = "Page"
	scroll.add_child(page)

	page.add_child(GoStyle.label("gohud", GoTheme.ROLE_TITLE))
	page.add_child(GoStyle.label("Customizable HUD & UI kit — every widget below is themeable and icon-swappable.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))

	_log = GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SUCCESS))
	_log.name = "Log"
	page.add_child(_log)

	# Kinds of button
	page.add_child(GoStyle.section("Buttons", false))
	var buttons := GoStyle.wrap_row()
	buttons.add_child(GoStyle.button("Primary", _say.bind("primary"), GoStyle.Tone.PRIMARY))
	buttons.add_child(GoStyle.button("Normal", _say.bind("normal")))
	buttons.add_child(GoStyle.button("Danger", _say.bind("danger"), GoStyle.Tone.DANGER))
	buttons.add_child(GoStyle.button("Compact", _say.bind("compact"), GoStyle.Tone.COMPACT))
	buttons.add_child(GoStyle.button("Bare", _say.bind("bare"), GoStyle.Tone.BARE))
	var disabled := GoStyle.button("Disabled")
	disabled.disabled = true
	buttons.add_child(disabled)
	page.add_child(buttons)

	var icon_row := GoStyle.wrap_row()
	# ♿ **Describe your icon buttons.** With no text, the tooltip is the only description a mouse user gets
	#    and the accessibility name the only one a screen reader gets — both come from the one `tooltip_key`.
	for icon in [GoIconSet.SETTINGS, GoIconSet.SEARCH, GoIconSet.HEART, GoIconSet.BELL, GoIconSet.TRASH]:
		icon_row.add_child(GoStyle.icon_button(icon, _say.bind(String(icon)), -1, StringName(icon)))
	page.add_child(icon_row)

	# List items
	page.add_child(GoStyle.section("List rows", false))
	# Rows sit `GAP_SMALL` apart — more than the 4 dp between a row's own two lines (skill rule 15).
	var list := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	list.add_child(GoStyle.list_button(GoIconSet.USER, "Profile", _say.bind("profile"),
		Color.TRANSPARENT, "Name, avatar and title", false))
	list.add_child(GoStyle.list_button(GoIconSet.VOLUME_HIGH, "Sound", _say.bind("sound"),
		Color.TRANSPARENT, "", false))
	list.add_child(GoStyle.list_button(GoIconSet.DISPLAY, "Display", _say.bind("display"),
		Color.TRANSPARENT, "", false))
	list.add_child(GoStyle.divider())
	list.add_child(GoStyle.list_button(GoIconSet.LOGOUT, "Sign out", _say.bind("sign out"),
		GoUi.color(GoTheme.DANGER), "", false))
	page.add_child(list)
	# 📋 A cramped quest list next to the same list built by the rules — measured, full screen.
	var list_lab := GoStyle.wrap_row()
	var list_lab_button := GoStyle.button("Readable lists — before / after", _open_list_lab, GoStyle.Tone.COMPACT)
	list_lab_button.name = "ListLabButton"
	list_lab.add_child(list_lab_button)
	page.add_child(list_lab)

	# Inputs
	page.add_child(GoStyle.section("Inputs", false))
	page.add_child(GoStyle.line_edit("Type here…"))
	var toggle := GoStyle.toggle("Enable haptics", false)
	toggle.button_pressed = true
	page.add_child(toggle)
	page.add_child(GoStyle.checkbox("Remember me", false))
	var volume := GoStyle.slider(0.0, 1.0, 0.01)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # the factory does not decide the width
	volume.value = 0.7
	page.add_child(volume)
	var picker := GoStyle.picker()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["Low", "Medium", "High"]: picker.add_item(option)
	page.add_child(picker)

	# Surfaces
	page.add_child(GoStyle.section("Surfaces", false))
	var surfaces := GoStyle.wrap_row()
	surfaces.add_child(GoStyle.button("Dialog", _open_dialog, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Alert", _open_alert, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Sheet", _open_sheet, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Popup", _open_popup, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Notice", _show_notice, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Prompt card", _show_prompt, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Coach tour", _start_tour, GoStyle.Tone.COMPACT))
	page.add_child(surfaces)

	# Foldable sections — Godot 4.5+ FoldableContainer. They share one FoldableGroup, so only one opens at a time.
	page.add_child(GoStyle.section("Foldable sections", false))
	var accordion := FoldableGroup.new()
	for title in ["Graphics", "Audio", "Controls"]:
		var fold := GoStyle.foldable(title, title != "Graphics", accordion, false)
		var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
		inner.add_child(GoStyle.label("%s options live here." % title, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
		inner.add_child(GoStyle.toggle("Enable %s tweaks" % title.to_lower(), false))
		fold.add_child(inner)
		page.add_child(fold)

	# Chips and empty states
	page.add_child(GoStyle.section("Chips", false))
	var chips := GoStyle.wrap_row()
	chips.add_child(GoStyle.chip("default"))
	chips.add_child(GoStyle.chip("success", GoUi.color(GoTheme.SUCCESS)))
	chips.add_child(GoStyle.chip("warning", GoUi.color(GoTheme.WARNING)))
	chips.add_child(GoStyle.chip("danger", GoUi.color(GoTheme.DANGER)))
	page.add_child(chips)

	# Responsive grid — narrow the window and the column count drops
	page.add_child(GoStyle.section("Responsive grid (resize the window)", false))
	var grid := GoStyle.responsive_grid(150.0)
	for i in 6:
		var tile := GoStyle.card()
		var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
		inner.add_child(GoStyle.label("Item %d" % (i + 1)))
		inner.add_child(GoStyle.label("subtitle", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
		tile.add_child(inner)
		grid.add_child(tile)
	page.add_child(grid)

	# The icon set, one group at a time. 🛑 Not every name at once — with the library added that is 1,271 nodes, and
	#    drawing a name is what reads its file (`GoIconSet.paths`), so a group costs only its own drawings.
	page.add_child(GoStyle.section("Icon set — swap it in GoConfig.icons", false))
	var set := GoUi.icons()
	var keys := Array(set.group_names())
	var listed := {}
	for key: String in keys:
		for icon in set.names_in_group(StringName(key)): listed[icon] = true
	var loose := Array(set.icon_names()).filter(func(icon: String) -> bool: return not listed.has(icon))
	var titles: Array = []
	for key: String in keys: titles.append("%s (%d)" % [set.group_title(StringName(key)), set.names_in_group(StringName(key)).size()])
	if not loose.is_empty(): titles.append("Other (%d)" % loose.size())
	var group_picker := GoStyle.select(titles)
	var icons := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP))
	var show_group := func(index: int) -> void:
		for child in icons.get_children(): child.queue_free()
		var names: Array = Array(set.names_in_group(StringName(keys[index]))) if index < keys.size() else loose
		for icon: String in names:
			icons.add_child(set.node(StringName(icon), 22, GoUi.color(GoTheme.SECONDARY)))
	group_picker.item_selected.connect(show_group)
	# 🛑 A flow row, not a row — the picker and the button side by side need ~390dp and ran a 320dp phone's whole page
	#    off the screen (`tests/gohud_layout_test.gd`, 2026-09-23).
	var icon_bar := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP))
	icon_bar.add_child(group_picker)
	if not GoUi.config.extra_icons.has(GoIconLibrary.icon_set()):
		icon_bar.add_child(GoStyle.button("Add 1,000 more icons", func() -> void:
			GoUi.add_icons(GoIconLibrary.icon_set())
			_rebuild(), GoStyle.Tone.COMPACT))
	page.add_child(icon_bar)
	page.add_child(icons)
	if not titles.is_empty():
		group_picker.select(0)
		show_group.call(0)

	# Pick a look — not just the colors but the **shapes** change with it (theme + skin).
	page.add_child(GoStyle.section("Theme preset", false))
	var presets := GoThemePresets.all()
	var names: Array = []
	var current := 0
	for index in presets.size():
		names.append(presets[index].label())
		if presets[index].id == GoUi.config.preset: current = index
	var preset_picker := GoStyle.select(names, "", false)
	preset_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_picker.selected = current
	preset_picker.item_selected.connect(_pick_preset)
	page.add_child(preset_picker)
	page.add_child(GoStyle.label(
		"Presets swap the theme (colours, engine controls) and the skin (joystick, slots, coach mark) together.",
		GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)))
	page.add_child(GoStyle.button("Toggle light / dark", _toggle_theme, GoStyle.Tone.COMPACT))

	_build_opacity(page)
	_build_new_widgets(page)

	# A heading of its own — straight under the carousel's dots, the empty state read as part of the carousel.
	page.add_child(GoStyle.section("Empty state", false))
	page.add_child(GoStyle.empty_state(GoIconSet.BOX, "Nothing here yet", false))


## 🔬 **Container opacity** — drag the slider and the panels thin out on the spot.
##
## 🛑 No value check can confirm this feature — "does the back show through", "is the text still
##    readable" are answered by drawing. So the lab lives inside the gallery, with a toggle that lays a
##    pattern behind it.
func _build_opacity(page: VBoxContainer) -> void:
	var lab := OpacityLab.new()
	# ④ Applying it project-wide rebuilds the screen — widgets already born do not change their clothes.
	lab.applied.connect(func(_alpha: float) -> void: _rebuild())
	lab.backdrop_wanted.connect(_set_busy_background)
	page.add_child(lab)


## Turns the pattern behind the whole screen on and off — the place to see what a panel lets through.
func _set_busy_background(on: bool) -> void:
	_busy_background = on
	var busy := get_node_or_null(^"Backdrop")
	if busy != null: (busy as Control).visible = on


## 🆕 The widgets added later — people only know they exist if **they can press them right here**.
## 🛑 Not a row of pictures. The buttons really work, and what a press did is written in the log line above.
func _build_new_widgets(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("Feedback", false))
	var feedback := GoStyle.wrap_row()
	feedback.add_child(GoStyle.button("Snackbar", _show_snackbar, GoStyle.Tone.COMPACT))
	feedback.add_child(GoStyle.button("Snackbar + Undo", _show_snackbar_undo, GoStyle.Tone.COMPACT))
	feedback.add_child(GoStyle.button("Busy button", _show_busy, GoStyle.Tone.COMPACT))
	page.add_child(feedback)

	var spin_row := GoStyle.row()
	var spinner := GoSpinner.new()
	spinner.custom_minimum_size = Vector2.ONE * 28.0
	spin_row.add_child(spinner)
	spin_row.add_child(GoStyle.label("GoSpinner — an indeterminate wait", GoTheme.ROLE_COMPACT,
		GoUi.color(GoTheme.MUTED)))
	page.add_child(spin_row)

	page.add_child(GoStyle.section("Badges", false))
	var badges := GoStyle.row(GoUi.metric(GoTheme.GAP))
	for pair in [[3, ""], [0, "NEW"], [128, ""]]:
		var host := GoIconButton.new()
		host.icon_name = GoIconSet.BELL
		# Plain words or your own translation key — the tooltip goes through the translation server either way.
		host.tooltip_text_name = &"Notifications"
		host.pressed.connect(_say.bind("badge host"))
		badges.add_child(host)
		GoBadge.attach.call_deferred(host, int(pair[0]), str(pair[1]))
	badges.add_child(GoBadge.make(0, "", true))
	page.add_child(badges)

	page.add_child(GoStyle.section("Fields", false))
	_gallery_field = GoField.make("Guild name", GoStyle.line_edit("2-16 characters"),
		"Everyone in the guild sees this")
	page.add_child(_gallery_field)
	var field_row := GoStyle.wrap_row()
	field_row.add_child(GoStyle.button("Show error", _show_field_error, GoStyle.Tone.COMPACT))
	field_row.add_child(GoStyle.button("Clear error", _clear_field_error, GoStyle.Tone.COMPACT))
	page.add_child(field_row)

	page.add_child(GoInputGroup.make(GoStyle.line_edit("Message"),
		{"suffix": GoStyle.button("Send", _say.bind("send"))}))
	page.add_child(GoInputGroup.make(GoStyle.line_edit("Search by name"), {"prefix_icon": GoIconSet.SEARCH}))

	var coupon := GoCodeInput.make(12, 4)
	coupon.completed.connect(func(code: String) -> void: _say("coupon %s" % code))
	page.add_child(coupon)

	var many: Array = []
	for i in 30: many.append({"text": "Player %d" % i})
	var combo := GoCombobox.make(many, 2, "Find a friend")
	combo.picked.connect(func(index: int) -> void: _say("picked player %d" % index))
	page.add_child(combo)

	page.add_child(GoStyle.section("Lists", false))
	var board := GoTable.make(
		[{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}],
		[[1, "Aria", 91240], [2, "Brin", 48210], [3, "Cade", 9124], [4, "Dane", 500]])
	board.sort_by(2, false)
	board.row_selected.connect(func(index: int) -> void: _say("row %d" % index))
	page.add_child(board)
	var pager := GoPagination.make(1, 12, func(value: int) -> void: _say("page %d" % value))
	page.add_child(pager)

	page.add_child(GoStyle.section("Inventory", false))
	page.add_child(GoStyle.segmented([{"text": "All", "icon": GoIconSet.GRID}, {"icon": GoIconSet.SWORD, "tooltip": "Gear"},
		{"icon": GoIconSet.POTION, "tooltip": "Potions"}], 0, func(index: int) -> void: _say("filter %d" % index), false, true))
	var bag := GoSlotGrid.new()
	bag.slot_count = 10
	bag.cell_size = 60
	var items := [
		{"icon": GoIconSet.SWORD, "ink": Color("c9d1d9"), "tooltip": "Iron sword"},
		{"icon": GoIconSet.POTION, "quantity": 12, "ink": Color("e5484d"), "tooltip": "Health potion"},
		{"icon": GoIconSet.POTION, "quantity": 7, "ink": Color("3e63dd"), "tooltip": "Mana potion"},
		{"icon": GoIconSet.COIN, "quantity": 1250, "ink": Color("ffc53d"), "tooltip": "Gold"},
		{"icon": GoIconSet.GIFT, "quantity": 1, "ink": Color("8e4ec6"), "tooltip": "Sealed gift", "disabled": true},
	]
	bag.set_cells(items)
	page.add_child(bag)
	var detail := GoStyle.column(0)
	page.add_child(detail)
	bag.slot_pressed.connect(func(index: int) -> void:
		bag.selected = index if not bag.cell(index).is_empty() else -1
		for child in detail.get_children(): child.queue_free()
		if bag.selected < 0: return
		var picked := bag.cell(index)
		detail.add_child(GoStyle.item_card({"icon": picked.icon, "ink": picked.ink, "title": picked.tooltip,
			"chips": [{"text": "×%d" % int(picked.quantity), "ink": GoUi.color(GoTheme.INFO)}] if picked.has("quantity") else [],
			"actions": [{"text": "Use", "tone": GoStyle.Tone.PRIMARY, "action": _say.bind("use %s" % picked.tooltip)}]}))
		_say("slot %d" % index))

	page.add_child(GoStyle.section("Over the screen", false))
	var overlays := GoStyle.wrap_row()
	overlays.add_child(GoStyle.button("Drawer", _open_drawer, GoStyle.Tone.COMPACT))
	_popover_anchor = GoStyle.button("Popover", _open_popover, GoStyle.Tone.COMPACT)
	overlays.add_child(_popover_anchor)
	_menu_anchor = GoStyle.button("Long-press me", _say.bind("hold for a menu"), GoStyle.Tone.COMPACT)
	GoContextMenu.attach(_menu_anchor, [
		{"text": "Use", "action": _say.bind("use")},
		{"text": "Equip", "action": _say.bind("equip")},
		{"separator": true},
		{"text": "Drop", "action": _say.bind("drop"), "danger": true},
	])
	overlays.add_child(_menu_anchor)
	overlays.add_child(GoStyle.button("Console", _open_console, GoStyle.Tone.COMPACT))
	page.add_child(overlays)
	var keys := GoKbd.make("Ctrl", "S")
	keys.hide_on_handheld = false
	page.add_child(keys)

	page.add_child(GoStyle.section("Game shapes", false))
	var days: Array = []
	for i in 7:
		days.append({"icon": GoIconSet.CROWN if i == 6 else GoIconSet.COIN,
			"amount": (i + 1) * 100, "special": i == 6})
	var calendar := GoRewardCalendar.make(days, 2)
	calendar.claimed.connect(func(day: int) -> void:
		_say("claimed day %d" % (day + 1))
		calendar.set_claimed_until(day))
	page.add_child(calendar)

	var charts := GoStyle.wrap_row()
	var radar := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45},
		{"STR": 0.6, "AGI": 0.75, "INT": 0.35, "VIT": 0.55, "LUK": 0.45})
	radar.custom_minimum_size = Vector2(170, 170)
	charts.add_child(radar)
	var donut := GoDonut.make([
		{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340}, {"label": "Pierce", "value": 90}])
	donut.center_text = "1050"
	donut.center_hint = "Damage"
	donut.custom_minimum_size = Vector2(150, 150)
	charts.add_child(donut)
	page.add_child(charts)
	page.add_child(donut.legend())

	page.add_child(GoStyle.section("Carousel", false))
	# 🔑 No fixed height — the carousel is as tall as its tallest banner. (A fixed 120 sliced the title in half, 2026-09-23.)
	var carousel := GoCarousel.new()
	page.add_child(carousel)
	var banners: Array[Control] = []
	for pair in [["Spring event", GoTheme.ACCENT], ["Double XP", GoTheme.SUCCESS], ["New skins", GoTheme.WARNING]]:
		# The card's face pads its content — no second `padding()` inside it.
		var banner := GoStyle.card(GoUi.color(pair[1]))
		var words := GoStyle.label(str(pair[0]), GoTheme.ROLE_SUBTITLE, GoUi.color(pair[1]))
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.custom_minimum_size.y = float(GoUi.metric(GoTheme.TOUCH)) * 1.5
		banner.add_child(words)
		banners.append(banner)
	carousel.set_pages(banners)
	carousel.page_changed.connect(func(index: int) -> void: _say("banner %d" % index))


# ── The HUD floating over the screen ───────────────────────────────────

func _build_hud() -> void:
	var top := GoHudAnchor.new()
	top.name = "TopLeft"
	top.spot = GoHudAnchor.Spot.TOP_RIGHT
	add_child(top)
	# 🛑 **A floating HUD goes on a panel.** With no background behind it the scrolling body passes under
	#    it and the two sets of text tangle until neither can be read — in portrait a field's placeholder
	#    and in landscape a toggle's knob sat straight on the health bar (measured 2026-09-13). The `hud`
	#    panel is 82% of the surface color, so it covers what is behind it.
	var bars_panel := PanelContainer.new()
	bars_panel.name = "Bars"
	bars_panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))
	top.add_child(bars_panel)
	var bars := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	bars.custom_minimum_size.x = 180
	_hp = GoBar.new()
	_hp.label_text = "HP"
	_hp.ink = GoUi.color(GoTheme.DANGER_FILL)
	bars.add_child(_hp)
	var mp := GoBar.new()
	mp.label_text = "MP"
	mp.ink = GoUi.color(GoTheme.INFO_FILL)
	bars.add_child(mp)
	var xp := GoBar.new()
	xp.label_text = "XP"
	xp.readout = GoBar.Readout.PERCENT
	xp.ink = GoUi.color(GoTheme.WARNING_FILL)
	bars.add_child(xp)
	bars_panel.add_child(bars)
	_hp.set_values(320, 500, false)
	mp.set_values(88, 120, false)
	xp.set_values(64, 100, false)

	var slots_anchor := GoHudAnchor.new()
	slots_anchor.name = "Slots"
	slots_anchor.spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	add_child(slots_anchor)
	var slot_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	slot_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	for spec in [
		{"icon": GoIconSet.POTION, "color": GoTheme.DANGER, "count": 12, "key": "1"},
		{"icon": GoIconSet.BOLT, "color": GoTheme.WARNING, "count": 3, "key": "2"},
		{"icon": GoIconSet.SHIELD, "color": GoTheme.INFO, "count": 0, "key": "3"},
		{"icon": GoIconSet.SWORD, "color": GoTheme.SUCCESS, "count": GoSlot.NONE, "key": "4"},
	]:
		var slot := GoSlot.new()
		slot.icon_name = spec.icon
		slot.accent = GoUi.color(spec.color)
		slot.quantity = spec.count
		slot.shortcut_label = spec.key
		slot.pressed.connect(_use_slot.bind(slot))
		slot_row.add_child(slot)
		_slots.append(slot)
	slots_anchor.add_child(slot_row)
	# Tell tightly packed slots to share out their widened touch areas.
	var peers: Array[Control] = []
	for slot in _slots: peers.append(slot)
	for slot in _slots: slot.touch_peers = peers

	var pad := GoHudAnchor.new()
	pad.name = "Joystick"
	pad.spot = GoHudAnchor.Spot.BOTTOM_LEFT
	# 🛑 The joystick only appears while a thumb rests on it — reserving space for it in the body would
	#    carve a whole row off the bottom of the screen for a box nobody can even see.
	pad.reserve_space = false
	add_child(pad)
	_joystick = GoJoystick.new()
	# In the demo it must not cover the body — it appears where the thumb lands.
	_joystick.hide_when_idle = true
	_joystick.moved.connect(func(v: Vector2) -> void:
		if not v.is_zero_approx(): _say("joystick %.2f, %.2f" % [v.x, v.y]))
	pad.add_child(_joystick)

	var notice_anchor := GoHudAnchor.new()
	notice_anchor.name = "NoticeSpot"
	notice_anchor.spot = GoHudAnchor.Spot.TOP_CENTER
	# 🛑 A notice **shows for a moment and goes.** Reserve space for it and the body lurches every time one
	#    appears; give it no room to move and it sits straight on the health bar at the top right (both measured).
	notice_anchor.reserve_space = false
	notice_anchor.avoid_peers = true
	add_child(notice_anchor)
	_notice = GoNotice.new()
	_notice.custom_minimum_size.x = 260
	notice_anchor.add_child(_notice)

	var prompt_anchor := GoHudAnchor.new()
	prompt_anchor.name = "PromptSpot"
	prompt_anchor.spot = GoHudAnchor.Spot.CENTER_RIGHT
	# This one, too, appears only when it is needed — not something the body should keep space for.
	prompt_anchor.reserve_space = false
	add_child(prompt_anchor)
	_prompt = GoPromptCard.new()
	_prompt.set_closable(true)
	_prompt.closed.connect(func() -> void: _prompt.hide())
	prompt_anchor.add_child(_prompt)


# ── Behaviour ──────────────────────────────────────────────────────────

# ── 🆕 Behaviour of the widgets added later ────────────────────────────

## Services are made **the first time they are used** — no layer that might go unused is attached while the screen comes up.
func _ensure_snackbar() -> GoSnackbar:
	if not is_instance_valid(_snackbar):
		_snackbar = GoSnackbar.new()
		add_child(_snackbar)
	return _snackbar


func _show_snackbar() -> void:
	_ensure_snackbar().show_text("Saved to the cloud", GoTheme.SUCCESS)
	_say("snackbar")


func _show_snackbar_undo() -> void:
	_say("snackbar with an action")
	var picked: int = await _ensure_snackbar().post({
		"text": "Item dropped", "tone": GoTheme.WARNING, "icon": GoIconSet.TRASH,
		"actions": ["Undo"],
	})
	_say("undo pressed" if picked == 0 else "snackbar timed out")


## 🔑 The pressed button turns into a spinner on the spot — its size does not change, and it cannot fire twice.
func _show_busy() -> void:
	var button := _find_button("Busy button")
	if button == null: return
	GoSpinner.busy(button, true)
	_say("waiting for the server…")
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(button): GoSpinner.busy(button, false)
	_say("done")


func _find_button(words: String) -> Button:
	for node in _descendants(self):
		var button := node as Button
		if button != null and button.text == words: return button
	return null


func _descendants(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_descendants(child))
	return out


func _show_field_error() -> void:
	if is_instance_valid(_gallery_field): _gallery_field.set_error("That name is taken")
	_say("field error")


func _clear_field_error() -> void:
	if is_instance_valid(_gallery_field): _gallery_field.clear_error()
	_say("field cleared")


func _open_drawer() -> void:
	if not is_instance_valid(_drawer):
		_drawer = GoDrawer.new()
		add_child(_drawer)
		for i in 8:
			_drawer.body.add_child(GoStyle.list_button(GoIconSet.POTION, "Potion %d" % (i + 1),
				_say.bind("potion %d" % (i + 1)), Color.TRANSPARENT, "Restores health", false))
	_drawer.open("Bag")
	_say("drawer")


func _open_popover() -> void:
	if not is_instance_valid(_popover_anchor): return
	var body := GoStyle.column()
	body.add_child(GoStyle.label("Flame sword", GoTheme.ROLE_SUBTITLE))
	body.add_child(GoStyle.label("ATK +12 · burns for 3s", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)))
	body.add_child(GoStyle.button("Equip", func() -> void:
		_say("equipped")
		GoPopover.close()))
	GoPopover.open(_popover_anchor, body, {"title": "Item"})
	_say("popover")


func _open_console() -> void:
	if not is_instance_valid(_console):
		_console = GoConsole.new()
		add_child(_console)
		_console.register("say", "Print a line: say <words>",
			func(args: PackedStringArray) -> String: return " ".join(args))
		_console.register("give", "Grant an item: give <id> <count>",
			func(args: PackedStringArray) -> String: return "granted %s" % " ".join(args))
		_console.log_line("Type help to list the commands.", GoTheme.MUTED)
	_console.toggle()
	_say("console")


func _say(what: String) -> void:
	GoFeedback.tapped()
	if is_instance_valid(_log): _log.text = "→ %s" % what


func _use_slot(slot: GoSlot) -> void:
	_say("slot %s" % slot.icon_name)
	slot.start_cooldown(5.0)
	if slot.quantity > 0: slot.quantity -= 1
	_hp.set_values(minf(_hp.value() + 60.0, 500.0), 500.0)


func _open_dialog() -> void:
	# The action cannot be undone, so the confirm button wears the **danger color** — the color reads first, the words follow.
	var yes := await _dialogs.confirm("Delete character",
		"This cannot be undone. Delete \"{name}\"?", "", "", "", {"name": "Aria"}, true)
	_say("dialog → %s" % ("confirmed" if yes else "cancelled"))


func _open_alert() -> void:
	await _dialogs.alert("Connection lost", "Could not reach the server. Try again in a moment.")
	_say("alert dismissed")


func _open_sheet() -> void:
	_sheet.open("Inventory")
	var search := GoStyle.line_edit("Search items…")
	_sheet.toolbar().add_child(search)
	_sheet.toolbar().visible = true
	for i in 24:
		_sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, "Item %d" % (i + 1),
			_say.bind("item %d" % (i + 1)), Color.TRANSPARENT, "A description line", false))
	_sheet.add_footer(GoStyle.button("Close", _sheet.close, GoStyle.Tone.PRIMARY))


func _open_popup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var surface := GoSurface.new()
	surface.dismiss_on_scrim = true
	surface.set_title("Centred popup")
	surface.close_requested.connect(func() -> void:
		layer.queue_free()
		_say("popup closed"))
	layer.add_child(surface)
	surface.body.add_child(GoStyle.label(
		"This is a GoSurface with placement CENTER. It respects the safe area, caps its height, "
		+ "and closes on Escape, Android Back, the X button, or a tap on the scrim."))
	surface.footer.add_child(GoStyle.button("Got it", func() -> void: surface.request_close(), GoStyle.Tone.PRIMARY))
	surface.footer.visible = true


## 📋 Opens the readable-list lab over the whole screen.
## 🛑 On a `CanvasLayer` of its own, not in the page: the page is a `GoForm`, and a form sets every box's spacing to
##    `GAP` — the cramped side's 4 dp would come out as 12. Not in a `GoSurface` either: one short of height drops
##    its title to `body`, which would shrink the readable side's heading. The lab brings its own way out.
func _open_list_lab() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ListLabLayer"
	layer.layer = 50
	add_child(layer)
	var lab := ListLab.new()
	lab.closed.connect(func() -> void:
		layer.queue_free()
		_say("list lab closed"))
	layer.add_child(lab)


func _show_notice() -> void:
	_notice.show_text("Saved successfully", GoTheme.SUCCESS)
	GoFeedback.confirmed()


func _show_prompt() -> void:
	_prompt.set_accent(GoUi.color(GoTheme.ACCENT))
	_prompt.set_icon(GoIconSet.USER_PLUS, GoUi.color(GoTheme.ACCENT), true)
	_prompt.set_title("Aria invited you to a party")
	_prompt.set_subtitle("Level 42 · Guardian")
	_prompt.set_actions([
		{"text": "Accept", "action": _say.bind("accepted"), "primary": true},
		{"text": "Decline", "action": _say.bind("declined")},
	])
	_prompt.fit_width(300)
	_prompt.show()


func _start_tour() -> void:
	if not is_instance_valid(_tour):
		_tour = GoCoachMark.new()
		add_child(_tour)
		_tour.finished.connect(func(done: bool) -> void: _say("tour " + ("completed" if done else "skipped")))
	_tour.start([
		{"target": _hp, "title": "Health bar", "body": "Values ease smoothly and large numbers are abbreviated."},
		{"target": _slots[0], "title": "Quick slot", "body": "Tap the slot itself — the highlighted control stays usable and the tour moves on."},
		{"target": _joystick, "title": "Joystick", "body": "Follow mode: the stick appears wherever your thumb lands."},
	])


## Picks a look — one line changes the theme, the skin and the icons together.
func _pick_preset(index: int) -> void:
	var presets := GoThemePresets.all()
	if index < 0 or index >= presets.size(): return
	GoUi.use_preset(presets[index].id)
	_rebuild()


func _toggle_theme() -> void:
	_dark = not _dark
	var settings := GoUi.config
	settings.theme = GoUi.DEFAULT_THEME if _dark else GoUi.LIGHT_THEME
	_rebuild()


## 🛑 Nodes already built carry their own `theme` — rebuilding the lot is the surest way.
##    A real game usually settles its look once, at boot, so it never pays this cost.
func _rebuild() -> void:
	for child in get_children(): child.queue_free()
	_slots.clear()
	_tour = null
	_ready.call_deferred()
