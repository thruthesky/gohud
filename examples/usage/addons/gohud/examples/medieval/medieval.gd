## A runnable medieval UI example. Attach to the Control root in medieval.tscn.
## Uses the same gohud widgets as the regular gallery; only the preset changes.
extends Control

var _dialogs: GoDialogs


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
	page.add_child(GoStyle.label("Shared widgets. Readable text. Decorations kept to the edges.", GoTheme.ROLE_CAPTION))
	_dialogs = GoDialogs.new()
	add_child(_dialogs)


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
	body.add_child(GoStyle.list_button(GoIconSet.COIN, "250 crowns", Callable(), Color.TRANSPARENT, "Gold carried", false))
	body.add_child(GoStyle.button("Inspect equipment", _inspect.bind("Equipment", "Choose an item in the satchel to inspect it."), GoStyle.Tone.PRIMARY))


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


func _choose(preset: StringName) -> void:
	GoUi.use_preset(preset)
	for child in get_children(): child.queue_free()
	_ready.call_deferred()
