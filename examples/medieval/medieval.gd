## A runnable medieval UI example. Attach to the Control root in medieval.tscn.
## Uses the same gohud widgets as the regular gallery; only the preset changes.
extends Control

## The same opacity lab the gallery and the guided tour use. Here it proves the point that matters
## for a custom skin: the medieval face is drawn by GoStyleBoxMedieval, not by a StyleBoxFlat, and it
## still fades — the iron fill thins out while rivets, bevels and grain keep their strength.
const OpacityLab := preload("res://addons/gohud/examples/gallery/opacity_lab.gd")

var _dialogs: GoDialogs
var _snackbar: GoSnackbar


func _ready() -> void:
	if GoUi.config.preset not in [GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]:
		GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	var background := ColorRect.new()
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := GoStyle.padding(24)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var scroll := GoScroll.new()
	margin.add_child(scroll)
	var page := GoStyle.column(20)
	scroll.add_child(page)
	page.add_child(GoStyle.label("GOHUD  /  MEDIEVAL COLLECTION", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	page.add_child(GoStyle.label("Ashen Crown", GoTheme.ROLE_TITLE))
	page.add_child(GoStyle.label("An oath written in iron. A journey kept in ink."))
	var choices := GoStyle.wrap_row()
	page.add_child(choices)
	choices.add_child(GoStyle.button("Iron & leather", _choose.bind(GoThemePresets.MEDIEVAL_DARK)))
	choices.add_child(GoStyle.button("Parchment", _choose.bind(GoThemePresets.MEDIEVAL_LIGHT)))
	var grid := GoStyle.responsive_grid(320.0, 20)
	page.add_child(grid)
	_character(grid)
	_inventory(grid)
	_quest(grid)
	_almanac(grid)
	# Panels are translucent by default (80%), so the world shows through an iron frame as much as
	# through a plain card. Drag the slider to see it on this preset's own face.
	var lab := OpacityLab.new()
	lab.applied.connect(_on_opacity_applied)
	page.add_child(lab)
	page.add_child(GoStyle.label("Shared widgets. Readable text. Decorations kept to the edges.", GoTheme.ROLE_CAPTION))
	_dialogs = GoDialogs.new()
	add_child(_dialogs)
	# A snackbar carries the "you can take that back" actions. It draws on this preset's own face,
	# which is the point of having it here as well as in the gallery.
	_snackbar = GoSnackbar.new()
	add_child(_snackbar)


func _card(parent: Node, title: String, subtitle: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Raw panels use the shared padding helper, just like the gohud surface widgets.
	panel.add_theme_stylebox_override(&"panel", GoStyle.surface(GoTheme.BOX_PANEL))
	parent.add_child(panel)
	var inset := GoStyle.padding(20)
	panel.add_child(inset)
	var body := GoStyle.column(16)
	inset.add_child(body)
	body.add_child(GoStyle.label(title, GoTheme.ROLE_SUBTITLE))
	body.add_child(GoStyle.label(subtitle, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	return body


func _character(parent: Node) -> void:
	var body := _card(parent, "Character", "WARDEN OF THE NORTHERN KEEP")
	var portrait := GoUi.icons().node(GoIconSet.USER, 64, GoUi.color(GoTheme.ACCENT))
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(portrait)
	body.add_child(GoStyle.label("Ser Aldric  /  Level 18"))
	for spec in [
		["Health", GoTheme.DANGER_FILL, 320.0, 500.0],
		["Mana", GoTheme.INFO_FILL, 88.0, 120.0],
		["Stamina", GoTheme.SUCCESS_FILL, 76.0, 100.0],
	]:
		var bar := GoBar.new()
		bar.label_text = spec[0]
		bar.ink = GoUi.color(spec[1])
		body.add_child(bar)
		bar.set_values(spec[2], spec[3], false)
	body.add_child(GoStyle.divider())
	body.add_child(GoStyle.list_button(GoIconSet.SWORD, "Oathkeeper", _inspect.bind("Oathkeeper", "A tempered longsword, sworn to the northern crown."),
		Color.TRANSPARENT, "Longsword  /  Attack 42", false))
	body.add_child(GoStyle.list_button(GoIconSet.SHIELD, "Iron bulwark", _inspect.bind("Iron bulwark", "An iron-bound shield carrying the warden's crest."),
		Color.TRANSPARENT, "Shield  /  Defence 28", false))
	body.add_child(GoStyle.divider())
	# Values are 0–1: the game decides what counts as 1. The dashed overlay is the blade in the
	# satchel — what the warden would become if it were drawn. Dashed, not just a second colour,
	# so the comparison survives colour blindness.
	var stats := GoRadar.make(
		{"MIGHT": 0.86, "GUILE": 0.42, "LORE": 0.31, "VIGOUR": 0.74, "FAITH": 0.55},
		{"MIGHT": 0.93, "GUILE": 0.38, "LORE": 0.31, "VIGOUR": 0.74, "FAITH": 0.55})
	stats.custom_minimum_size = Vector2(0, 168)
	body.add_child(stats)


func _inventory(parent: Node) -> void:
	var body := _card(parent, "Satchel", "IRON-BOUND LEATHER  /  8 ITEMS")
	var slots := GoStyle.responsive_grid(56.0, 12)
	body.add_child(slots)
	var items := [
		[GoIconSet.SWORD, "Oathkeeper", GoSlot.NONE], [GoIconSet.SHIELD, "Iron bulwark", GoSlot.NONE],
		[GoIconSet.POTION, "Crimson draught", 12], [GoIconSet.POTION, "Azure tonic", 6],
		[GoIconSet.KEY, "Tower key", 1], [GoIconSet.BOOK, "Chronicle", 1],
		[GoIconSet.COIN, "Antique crowns", 250], [GoIconSet.MAP, "Northern marches", 1],
	]
	for index in items.size():
		var item: Array = items[index]
		var slot := GoSlot.new()
		slot.icon_name = item[0]
		slot.quantity = item[2]
		slot.accent = GoUi.color(GoTheme.DANGER if index == 2 else GoTheme.INFO if index == 3 else GoTheme.ACCENT)
		slot.tooltip_text = item[1]
		slot.pressed.connect(_inspect.bind(item[1], "A trusted companion on the road to the ruined tower."))
		slots.add_child(slot)
		slot.custom_minimum_size = Vector2(56, 56)
		# Long-press (or right-click) any slot. A finger that moves cancels it, so the grid still scrolls.
		GoContextMenu.attach(slot, [
			{"text": "Inspect", "icon": GoIconSet.SEARCH,
				"action": _inspect.bind(item[1], "A trusted companion on the road to the ruined tower.")},
			{"text": "Equip", "icon": GoIconSet.SWORD, "action": _equip.bind(item[1])},
			{"separator": true},
			{"text": "Drop", "icon": GoIconSet.TRASH, "danger": true, "action": _drop.bind(item[1])},
		])
	# 🛑 A badge anchors to a corner, so it can only find that corner once the slot is laid out.
	if slots.get_child_count() > 0:
		GoBadge.attach.call_deferred(slots.get_child(0), 0, "NEW")
	body.add_child(GoStyle.list_button(GoIconSet.COIN, "250 crowns", Callable(), Color.TRANSPARENT, "Gold carried", false))
	body.add_child(GoStyle.button("Inspect equipment", _inspect.bind("Equipment", "Choose an item in the satchel to inspect it."), GoStyle.Tone.PRIMARY))


## The almanac: what the keep owes you today, and where the crowns went.
## Both shapes are built for games — attendance that only lets you press **today**, and a ring whose
## legend says every slice in words as well as in colour.
func _almanac(parent: Node) -> void:
	var body := _card(parent, "The Almanac", "ATTENDANCE  /  SEVENTH DAY IS SWORN")
	var days := []
	for index in 7:
		days.append({
			"icon": GoIconSet.COIN if index < 6 else GoIconSet.SWORD,
			"amount": 50 * (index + 1),
			"special": index == 6,
		})
	# The second argument is the last day already claimed (0-based; -1 = none yet).
	var calendar := GoRewardCalendar.make(days, 2)
	calendar.claimed.connect(_on_day_claimed.bind(calendar))
	body.add_child(calendar)

	body.add_child(GoStyle.divider())
	body.add_child(GoStyle.label("WHERE THE CROWNS WENT", GoTheme.ROLE_CAPTION,
		GoUi.color(GoTheme.SECONDARY)))
	var spend := GoDonut.make([
		{"label": "Smithing", "value": 420},
		{"label": "Provisions", "value": 260},
		{"label": "Tithes", "value": 140},
		{"label": "Repairs", "value": 80},
	])
	spend.center_text = "900"
	spend.center_hint = "crowns"
	spend.custom_minimum_size = Vector2(0, 150)
	body.add_child(spend)
	body.add_child(spend.legend())


func _on_day_claimed(day: int, calendar: GoRewardCalendar) -> void:
	calendar.set_claimed_until(day)
	_snackbar.post({"text": "Day %d claimed" % (day + 1), "tone": GoTheme.SUCCESS})


func _equip(item_name: String) -> void:
	_snackbar.post({"text": "%s equipped" % item_name})


## Dropping is reversible, so it asks with a button in the snackbar rather than stopping the
## game with a dialog. `post()` returns the index of the button that was pressed, -1 when it expired.
func _drop(item_name: String) -> void:
	if await _snackbar.post({"text": "%s dropped" % item_name, "actions": ["Undo"],
			"tone": GoTheme.WARNING}) == 0:
		_snackbar.post({"text": "%s is back in the satchel" % item_name})


func _quest(parent: Node) -> void:
	var body := _card(parent, "The Lost Sword", "CHRONICLE  /  CHAPTER III")
	var seal := GoUi.icons().node(&"seal", 48, GoUi.color(GoTheme.DANGER))
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(seal)
	body.add_child(GoStyle.label("The blacksmith's blade was taken beyond the forest. Find the ruined tower and bring his sword home."))
	body.add_child(GoStyle.section("OBJECTIVES", false))
	for index in 3:
		var objective := GoStyle.checkbox(["Enter the forest", "Find the ruined tower", "Recover the sword"][index], false)
		objective.button_pressed = index == 0
		body.add_child(objective)
	body.add_child(GoStyle.label("Reward  /  250 gold + a sworn ally", GoTheme.ROLE_CAPTION))
	body.add_child(GoStyle.button("Track quest", _inspect.bind("Quest tracked", "The Lost Sword is now your active quest."), GoStyle.Tone.PRIMARY))


func _inspect(title: String, description: String) -> void:
	await _dialogs.alert(title, description, "Continue")


## The project-wide value changed — rebuild, because widgets are dressed when they are born.
func _on_opacity_applied(_alpha: float) -> void:
	_choose(GoUi.config.preset)


func _choose(preset: StringName) -> void:
	GoUi.use_preset(preset)
	for child in get_children(): child.queue_free()
	_ready.call_deferred()
