## 📸 **The website's pictures** — every widget on its own, the popups over a game screen, and one dialog in every look.
##
##   bash <godot skill>/scripts/xvfb_run.sh --path <project> --out <folder> --size 780x1688 \
##     -s res://addons/gohud/tests/site_widget_shots.gd
##   … -e SHOT_SET=widgets       only one set: widgets · popups · looks · presets · skins
##   … -e SHOT_ONLY=gobar,goslot only the shots whose name contains one of these words
##
## Then `python3 addons/gohud/tools/site_images.py <folder>` turns the PNGs into the WebP files under `www/img/`.
##
## 🔑 What it shoots
## | Set | Picture | Lands in |
## |---|---|---|
## | `widgets` | one widget (or a small family of them) cropped to its own rect, in `default_dark` | `www/img/widgets/` |
## | `popups` | a phone screen — a small game with its HUD — with one popup open over it | `www/img/popups/` |
## | `looks` | the same confirmation over the same game, once per built-in look | `www/img/popups/` |
## | `presets` | the widget gallery on a phone, once per built-in look | `www/img/presets/` |
## | `skins` | quick slots, a joystick and a chip — the parts a skin draws — in every family | `www/img/widgets/` |
##
## 🔑 The screen is a 390×844 phone drawn at twice the pixels (window 780×1688), so the pictures stay sharp on a
##    retina screen. The stretch is pinned here, so a host project's own display settings do not matter.
## 🛑 `--headless` draws nothing — run it on the virtual monitor. The container has no CJK font, so every label is
##    English; the pictures are shared by all 17 language editions of the site.
## 🛑 Motion is off (`reduce_motion`, no fade-in) so every run gives the same picture and nothing is mid-animation.
extends SceneTree

## The screen in UI units — a phone held upright.
const SCREEN := Vector2i(390, 844)
## The look of the single-widget pictures.
const WIDGET_LOOK := &"default_dark"
## Space kept around a cropped widget (UI units).
const CROP_MARGIN := 12.0

var _dir := ""
var _set := ""
var _only: PackedStringArray = []
var _shots := 0
var _failed := 0
## Everything one shot added to the tree — freed before the next one.
var _stage: Array[Node] = []


func _initialize() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty(): _dir = "/out"
	_set = OS.get_environment("SHOT_SET")
	var only := OS.get_environment("SHOT_ONLY")
	if not only.is_empty(): _only = only.split(",", false)
	for folder in ["widgets", "popups", "presets"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [_dir, folder])
	create_timer(900.0).timeout.connect(func() -> void:
		printerr("FAIL site shots watchdog")
		quit(2))

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = SCREEN
	GoUi.reset()
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false

	if _wants_set("widgets"): await _widgets()
	if _wants_set("popups"): await _popups()
	if _wants_set("looks"): await _looks()
	if _wants_set("presets"): await _presets()
	if _wants_set("skins"): await _skins()
	print("site shots: %d saved · %d failed → %s" % [_shots, _failed, _dir])
	quit(0 if _failed == 0 else 1)


func _wants_set(name: String) -> bool:
	return _set.is_empty() or _set == name


func _wants(name: String) -> bool:
	if _only.is_empty(): return true
	for word in _only:
		if name.contains(word): return true
	return false


# ── Stage ─────────────────────────────────────────────────────────────

func _use(look: StringName) -> void:
	GoUi.use_preset(look)
	GoUi.config.reduce_motion = true
	GoUi.config.surface_fade_in = false


func _clear() -> void:
	GoPopover.close()
	for node in _stage:
		if is_instance_valid(node): node.queue_free()
	_stage.clear()
	for child in root.get_children():
		if child is Window: child.queue_free()
	await process_frame
	await process_frame


func _keep(node: Node) -> Node:
	_stage.append(node)
	root.add_child(node)
	return node


## A plain page: the theme's backdrop and a padded column at the top.
func _page() -> VBoxContainer:
	var back := ColorRect.new()
	back.color = GoUi.color(GoTheme.BACKGROUND)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(back)
	var pad := GoStyle.padding(16)
	pad.theme = GoUi.theme()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(pad)
	var column := GoStyle.column()
	pad.add_child(column)
	return column


## A small game screen — sky, hills, a road — with the HUD a game keeps on it: health and mana top left, coins top
## right, a joystick bottom left and quick slots bottom right. Popups open over this.
func _game() -> Control:
	var world := Backdrop.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(world)
	var hud := Control.new()
	hud.theme = GoUi.theme()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(hud)

	var top_left := GoHudAnchor.new()
	top_left.spot = GoHudAnchor.Spot.TOP_LEFT
	hud.add_child(top_left)
	var bars := GoStyle.hud_panel()
	top_left.add_child(bars)
	var stack := GoStyle.column(4)
	bars.add_child(stack)
	stack.add_child(_bar("HP", 320, 500, GoUi.color(GoTheme.DANGER)))
	stack.add_child(_bar("MP", 140, 200, GoUi.color(GoTheme.INFO)))

	var top_right := GoHudAnchor.new()
	top_right.spot = GoHudAnchor.Spot.TOP_RIGHT
	hud.add_child(top_right)
	top_right.add_child(GoStyle.chip("1,250", GoUi.color(GoTheme.WARNING), false, GoIconSet.COIN))

	var bottom_left := GoHudAnchor.new()
	bottom_left.spot = GoHudAnchor.Spot.BOTTOM_LEFT
	hud.add_child(bottom_left)
	var pad := GoJoystick.new()
	pad.mode = GoJoystick.Mode.FIXED
	pad.radius = 52.0
	pad.knob_radius = 22.0
	pad.custom_minimum_size = Vector2(124, 124)
	bottom_left.add_child(pad)

	var bottom_right := GoHudAnchor.new()
	bottom_right.spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	hud.add_child(bottom_right)
	var slots := GoStyle.row(8)
	bottom_right.add_child(slots)
	slots.add_child(_slot(GoIconSet.SWORD, -1, "1"))
	slots.add_child(_slot(GoIconSet.POTION, 12, "2"))
	slots.add_child(_slot(GoIconSet.SHIELD, -1, "3"))
	return hud


## A layer above the game for a popup the shot builds itself (dialogs, sheets and drawers bring their own).
func _layer(index := 10) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = index
	_keep(layer)
	return layer


func _bar(text: String, value: float, maximum: float, ink: Color) -> GoBar:
	var bar := GoBar.new()
	bar.label_text = text
	bar.ink = ink
	bar.custom_minimum_size.x = 150
	bar.set_values(value, maximum, false)
	return bar


func _slot(icon: StringName, quantity := -1, shortcut := "") -> GoSlot:
	var slot := GoSlot.new()
	slot.icon_name = icon
	slot.quantity = quantity if quantity >= 0 else GoSlot.NONE
	slot.shortcut_label = shortcut
	return slot


func _rows(parent: Control, count: int) -> void:
	var names := ["Health potion", "Iron sword", "Wooden shield", "Map of the north", "Old key", "Gold ring",
		"Bread", "Torch"]
	var icons := [GoIconSet.POTION, GoIconSet.SWORD, GoIconSet.SHIELD, GoIconSet.MAP, GoIconSet.KEY, GoIconSet.CROWN,
		GoIconSet.GIFT, GoIconSet.BOLT]
	for i in count:
		parent.add_child(GoStyle.list_button(icons[i % icons.size()], names[i % names.size()], Callable(),
			Color.TRANSPARENT, "x%d" % (i + 1), false))


func _settle(frames := 10) -> void:
	for _i in frames: await process_frame


func _image() -> Image:
	RenderingServer.force_draw()
	return root.get_texture().get_image()


## Saves the area of `target` (plus a margin) — or the whole screen when `target` is null.
func _save(name: String, target: Control = null, margin := CROP_MARGIN, frames := 10) -> void:
	await _settle(frames)
	var image := _image()
	var visible := root.get_visible_rect().size
	var k := float(image.get_width()) / visible.x
	if target != null:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			_fail(name, "the target is not on screen")
			return
		var area := target.get_global_rect().grow(margin)
		area = area.intersection(Rect2(Vector2.ZERO, visible))
		var px := Rect2i(Vector2i((area.position * k).round()), Vector2i((area.size * k).round()))
		if px.size.x < 8 or px.size.y < 8:
			_fail(name, "the target has no size")
			return
		image = image.get_region(px)
	var path := "%s/%s.png" % [_dir, name]
	var err := image.save_png(path)
	if err != OK:
		_fail(name, "could not write %s" % path)
		return
	_shots += 1
	print("SHOT %s (%dx%d)" % [path, image.get_width(), image.get_height()])


func _fail(name: String, why: String) -> void:
	_failed += 1
	printerr("🛑 %s — %s" % [name, why])


# ── Widgets, one at a time ────────────────────────────────────────────
#
# Each entry is `[file name, builder]`. A builder takes the page and returns the control to crop to; `null` means
# "shoot the whole screen" (the screen-level widgets: scaffold, edge bars, overlays).

func _widget_list() -> Array:
	return [
		["goscaffold", _w_scaffold], ["gotopbar", _w_top_bar], ["gobottombar", _w_bottom_bar],
		["goleftsidebar", _w_left_bar], ["gorightsidebar", _w_right_bar], ["gosidebar", _w_side_rail],
		["goedgebar", _w_edge_bar], ["gogrid", _w_grid], ["goform", _w_form], ["goscroll", _w_scroll],
		["gohudanchor", _w_hud_anchor], ["gostyle-column", _w_column], ["gostyle-responsive_grid", _w_responsive],
		["gostyle-padding", _w_padding], ["gostyle-foldable", _w_foldable],
		["gosurface", _w_surface], ["gosheet", _w_sheet], ["godialogs", _w_dialogs], ["godialogs-choose", _w_choose],
		["godrawer", _w_drawer], ["gopopover", _w_popover], ["gocontextmenu", _w_context_menu],
		["gocoachmark", _w_coach_mark], ["goconsole", _w_console],
		["gosnackbar", _w_snackbar], ["gonotice", _w_notice], ["gopromptcard", _w_prompt_card], ["gobanner", _w_banner],
		["gospinner", _w_spinner], ["gobadge", _w_badge], ["goprogress", _w_progress],
		["goloadingindicator", _w_loading], ["gorefresh", _w_refresh], ["gostyle-alert", _w_alert],
		["gostyle-skeleton", _w_skeleton], ["gostyle-tooltip_node", _w_tooltip],
		["goappbar", _w_app_bar], ["gonavbar", _w_nav_bar], ["gonavbar-drawer_list", _w_drawer_list], ["gofab", _w_fab],
		["gosearchbar", _w_search_bar], ["gosplitbutton", _w_split_button], ["gotabview", _w_tab_view],
		["gostyle-tabs", _w_tabs], ["gostyle-bottom_app_bar", _w_bottom_app_bar], ["gostyle-toolbar", _w_toolbar],
		["gostyle-breadcrumb", _w_breadcrumb], ["gopagination", _w_pagination], ["gocarousel", _w_carousel],
		["gostyle-button", _w_buttons], ["gostyle-glow", _w_glow], ["goiconbutton", _w_icon_buttons],
		["gostyle-chip", _w_chips], ["gostyle-filter_chip", _w_filter_chips], ["gostyle-segmented", _w_segmented],
		["gostyle-choice_grid", _w_choice_grid], ["gostyle-radio_group", _w_radio], ["gostyle-toggle", _w_toggles],
		["gostyle-line_edit", _w_inputs], ["gofield", _w_field], ["goinputgroup", _w_input_group],
		["gocombobox", _w_combobox], ["gocodeinput", _w_code_input], ["gostyle-select", _w_select],
		["gostyle-slider", _w_slider], ["gorangeslider", _w_range_slider], ["godatepicker", _w_date_picker],
		["gotimepicker", _w_time_picker], ["gowheelpicker", _w_wheel_picker], ["gostepper", _w_stepper],
		["gostyle-list_row", _w_list_rows], ["golistview", _w_list_view], ["goreorderlist", _w_reorder],
		["goswiperow", _w_swipe_row], ["gotable", _w_table], ["gostyle-card", _w_cards], ["gostyle-avatar", _w_avatars],
		["gostyle-label", _w_labels],
		["gobar", _w_bars], ["goslot", _w_slots], ["goslotgrid", _w_slot_grid], ["gojoystick", _w_joystick],
		["gokbd", _w_kbd], ["gochoicecolumn", _w_choice_column], ["gorewardcalendar", _w_calendar],
		["goradar", _w_radar], ["godonut", _w_donut], ["gozoomview", _w_zoom_view], ["gostyle-hud_panel", _w_hud_panels],
		["goiconset", _w_icons], ["gostyleboxcut", _w_styleboxes],
	]


func _widgets() -> void:
	_use(WIDGET_LOOK)
	for entry in _widget_list():
		var name: String = entry[0]
		if not _wants(name): continue
		await _clear()
		var page := _page()
		var builder: Callable = entry[1]
		var target: Variant = await builder.call(page)
		await _save("widgets/" + name, target as Control)


# Layout

func _w_scaffold(_page_node: VBoxContainer) -> Control:
	await _clear()
	var page := GoStyle.column()
	_rows(page, 7)
	var screen := GoScaffold.make("Inbox", page, true)
	screen.theme = GoUi.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.set_bottom_bar(GoNavBar.make([{"icon": GoIconSet.HOME, "text": "Home"},
		{"icon": GoIconSet.BELL, "text": "Alerts", "badge": 3}, {"icon": GoIconSet.USER, "text": "Me"}], 0))
	screen.set_fab(GoFab.make(GoIconSet.EDIT))
	_keep(screen)
	return null


func _edge_screen(world := false) -> Control:
	await _clear()
	var back: Control = Backdrop.new() if world else ColorRect.new()
	if back is ColorRect: (back as ColorRect).color = GoUi.color(GoTheme.BACKGROUND)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(back)
	var screen := Control.new()
	screen.theme = GoUi.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(screen)
	return screen


func _w_top_bar(_page_node: VBoxContainer) -> Control:
	var screen := await _edge_screen()
	var bar := GoTopBar.make(3)
	bar.add_start(GoStyle.icon_button(GoIconSet.BACK, Callable(), -1, &"back"))
	bar.add_center(GoStyle.label("Stage 3", GoTheme.ROLE_SUBTITLE))
	bar.add_end(GoStyle.chip("1,250", GoUi.color(GoTheme.WARNING), false, GoIconSet.COIN))
	screen.add_child(bar)
	return bar


func _w_bottom_bar(_page_node: VBoxContainer) -> Control:
	var screen := await _edge_screen()
	var bar := GoBottomBar.make(1, GoBottomBar.Justify.SPACE_BETWEEN)
	bar.add_start(GoStyle.button("Attack", Callable(), GoStyle.Tone.PRIMARY))
	bar.add_start(GoStyle.button("Guard"))
	bar.add_start(GoStyle.button("Run"))
	screen.add_child(bar)
	return bar


func _w_left_bar(_page_node: VBoxContainer) -> Control:
	var screen := await _edge_screen(true)
	var tools := GoLeftSideBar.make(3)
	tools.add_start(_plate(GoStyle.icon_button(GoIconSet.MENU, Callable(), -1, &"menu")))
	tools.add_center(_plate(GoStyle.icon_button(GoIconSet.MAP, Callable(), -1, &"map")))
	tools.add_end(_plate(GoStyle.icon_button(GoIconSet.USER, Callable(), -1, &"profile")))
	screen.add_child(tools)
	return null


func _w_right_bar(_page_node: VBoxContainer) -> Control:
	var screen := await _edge_screen(true)
	var tools := GoRightSideBar.make(3)
	tools.add_start(_plate(GoStyle.icon_button(GoIconSet.SETTINGS, Callable(), -1, &"settings")))
	tools.add_center(_plate(GoStyle.icon_button(GoIconSet.SEARCH, Callable(), -1, &"search")))
	tools.add_end(_plate(GoStyle.icon_button(GoIconSet.BAG, Callable(), -1, &"bag")))
	screen.add_child(tools)
	return null


func _w_side_rail(_page_node: VBoxContainer) -> Control:
	var screen := await _edge_screen(true)
	var rail := GoRightSideBar.make(1, GoSideBar.Justify.CENTER)
	var stack := GoStyle.column(4)
	stack.add_child(GoStyle.icon_button(GoIconSet.MAP, Callable(), -1, &"map"))
	stack.add_child(GoStyle.icon_button(GoIconSet.FLAG, Callable(), -1, &"quests"))
	stack.add_child(GoStyle.icon_button(GoIconSet.CHAT, Callable(), -1, &"chat"))
	rail.add_start(_plate(stack))
	screen.add_child(rail)
	return null


func _w_edge_bar(_page_node: VBoxContainer) -> Control:
	var screen := await _edge_screen()
	var bar := GoTopBar.make(1)
	bar.justify = GoEdgeBar.Justify.SPACE_BETWEEN
	bar.add_start(GoStyle.chip("Lv 12", GoUi.color(GoTheme.INFO)))
	bar.add_start(GoStyle.chip("1,250", GoUi.color(GoTheme.WARNING), false, GoIconSet.COIN))
	bar.add_start(GoStyle.icon_button(GoIconSet.SETTINGS, Callable(), -1, &"settings"))
	screen.add_child(bar)
	return bar


func _w_grid(page: VBoxContainer) -> Control:
	var cards := GoGrid.make(1, 100.0)
	for spec in [["Sword", GoIconSet.SWORD], ["Potion", GoIconSet.POTION], ["Shield", GoIconSet.SHIELD],
			["Key", GoIconSet.KEY], ["Map", GoIconSet.MAP], ["Crown", GoIconSet.CROWN]]:
		var tile := GoStyle.card()
		var inside := GoStyle.column(6)
		inside.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := GoUi.icons().node(spec[1], 32)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inside.add_child(icon)
		var text := GoStyle.label(spec[0])
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(text)
		tile.add_child(inside)
		cards.add_child(tile)
	page.add_child(cards)
	return cards


func _w_form(page: VBoxContainer) -> Control:
	var form := GoForm.new()
	page.add_child(form)
	var column := GoStyle.column()
	form.add_child(column)
	column.add_child(GoStyle.section("Profile", false))
	column.add_child(GoField.make("Nickname", GoStyle.line_edit("Your name"), "3–12 letters"))
	column.add_child(GoStyle.toggle("Show me online", false))
	column.add_child(GoStyle.button("Save", Callable(), GoStyle.Tone.PRIMARY))
	return form


func _w_scroll(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var list := GoScroll.new()
	list.custom_minimum_size.y = 220
	var rows := GoStyle.column()
	list.add_child(rows)
	_rows(rows, 8)
	box.add_child(list)
	var strip := GoScroll.horizontal()
	strip.custom_minimum_size.y = 56
	var chips := GoStyle.row()
	strip.add_child(chips)
	for word in ["All", "Weapons", "Armour", "Potions", "Keys", "Quest items", "Junk"]:
		chips.add_child(GoStyle.filter_chip(word, word == "All"))
	box.add_child(strip)
	return box


func _w_hud_anchor(_page_node: VBoxContainer) -> Control:
	await _clear()
	_game()
	return null


func _w_column(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.section("row()", false))
	var line := GoStyle.row()
	line.add_child(GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY))
	line.add_child(GoStyle.button("Shop"))
	line.add_child(GoStyle.button("Quit"))
	box.add_child(line)
	box.add_child(GoStyle.section("wrap_row()", false))
	var chips := GoStyle.wrap_row()
	for word in ["Fire", "Ice", "Poison", "Holy", "Shadow", "Wind", "Earth"]:
		chips.add_child(GoStyle.chip(word))
	box.add_child(chips)
	return box


func _w_responsive(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var tiles := GoStyle.responsive_grid(150)
	for tone in [GoTheme.INFO, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER]:
		var tile := PanelContainer.new()
		tile.custom_minimum_size.y = 56
		tile.add_theme_stylebox_override(&"panel", _fill(GoUi.color(tone).darkened(0.35)))
		var text := GoStyle.label(String(tone).capitalize(), GoTheme.ROLE_BODY)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(text)
		tiles.add_child(tile)
	box.add_child(tiles)
	var thumb := GoStyle.aspect(16.0 / 9.0)
	thumb.custom_minimum_size = Vector2(200, 112)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var picture := PanelContainer.new()
	picture.add_theme_stylebox_override(&"panel", _fill(GoUi.color(GoTheme.ACCENT).darkened(0.45)))
	var ratio := GoStyle.label("16 : 9")
	ratio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ratio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picture.add_child(ratio)
	thumb.add_child(picture)
	box.add_child(thumb)
	return box


func _w_padding(page: VBoxContainer) -> Control:
	var card := GoStyle.card()
	page.add_child(card)
	var pad := GoStyle.padding(16)
	card.add_child(pad)
	var column := GoStyle.column()
	pad.add_child(column)
	var line := GoStyle.row()
	line.add_child(GoStyle.label("Daily quest", GoTheme.ROLE_SUBTITLE))
	line.add_child(GoStyle.spacer())
	line.add_child(GoStyle.chip("2 / 3", GoUi.color(GoTheme.SUCCESS)))
	column.add_child(line)
	column.add_child(GoStyle.divider())
	column.add_child(GoStyle.label("Defeat three slimes in the meadow.", GoTheme.ROLE_BODY))
	return card


func _w_foldable(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.section("Sound", false))
	box.add_child(GoStyle.toggle("Music", false))
	box.add_child(GoStyle.toggle("Effects", false))
	var more := GoStyle.foldable("Advanced", false, null, false)
	var inside := GoStyle.column()
	inside.add_child(GoStyle.label("Voice volume"))
	inside.add_child(GoStyle.slider(0.0, 1.0, 0.05))
	more.add_child(inside)
	box.add_child(more)
	box.add_child(GoStyle.foldable("Accessibility", true, null, false))
	return box


# Windows and overlays — the catalog shows them on the game screen; the popups set shows more of each.

func _w_surface(_page_node: VBoxContainer) -> Control:
	await _settings_window(GoSurface.Placement.CENTER)
	return null


func _w_sheet(_page_node: VBoxContainer) -> Control:
	await _inventory_sheet()
	return null


func _w_dialogs(_page_node: VBoxContainer) -> Control:
	await _confirm(true)
	return null


func _w_choose(_page_node: VBoxContainer) -> Control:
	await _clear()
	_game()
	var dialogs := GoDialogs.new()
	_keep(dialogs)
	dialogs.choose("Sort by", ["Newest", "Price", "Rating", "Name"])
	return null


func _w_drawer(_page_node: VBoxContainer) -> Control:
	await _drawer(GoDrawer.Side.RIGHT)
	return null


func _w_popover(_page_node: VBoxContainer) -> Control:
	await _popover()
	return null


func _w_context_menu(_page_node: VBoxContainer) -> Control:
	await _context_menu()
	return null


func _w_coach_mark(_page_node: VBoxContainer) -> Control:
	await _coach_mark()
	return null


func _w_console(_page_node: VBoxContainer) -> Control:
	await _console()
	return null


# Messages and waiting

func _w_snackbar(_page_node: VBoxContainer) -> Control:
	await _snackbar()
	return null


func _w_notice(page: VBoxContainer) -> Control:
	var notice := GoNotice.new()
	page.add_child(notice)
	notice.show_text("Game saved", GoTheme.SUCCESS, 0.0)
	return notice


func _w_prompt_card(page: VBoxContainer) -> Control:
	var invite := _invite_card()
	page.add_child(invite)
	invite.fit_width(358)
	invite.show()
	return invite


func _w_banner(page: VBoxContainer) -> Control:
	var offline := GoBanner.make("You're offline. Progress is saved on this phone until you reconnect.",
		[{"text": "Retry", "action": Callable()}, {"text": "Dismiss", "action": Callable()}], GoIconSet.WARNING)
	page.add_child(offline)
	return offline


func _w_spinner(page: VBoxContainer) -> Control:
	var line := GoStyle.row(16)
	page.add_child(line)
	var buy := GoStyle.button("Buy", Callable(), GoStyle.Tone.PRIMARY)
	buy.custom_minimum_size.x = 140
	line.add_child(buy)
	GoSpinner.busy(buy, true)
	var spin := GoSpinner.new()
	spin.custom_minimum_size = Vector2(40, 40)
	line.add_child(spin)
	return line


func _w_badge(page: VBoxContainer) -> Control:
	var line := GoStyle.row(24)
	page.add_child(line)
	var mail := GoStyle.icon_button(GoIconSet.BELL, Callable(), -1, &"alerts")
	line.add_child(mail)
	GoBadge.attach(mail, 3)
	var shop := GoStyle.icon_button(GoIconSet.BAG, Callable(), -1, &"shop")
	line.add_child(shop)
	GoBadge.attach(shop, 0, "NEW")
	var chat := GoStyle.icon_button(GoIconSet.CHAT, Callable(), -1, &"chat")
	line.add_child(chat)
	GoBadge.attach(chat, 0, "", true)
	var gift := GoStyle.icon_button(GoIconSet.GIFT, Callable(), -1, &"gifts")
	line.add_child(gift)
	GoBadge.attach(gift, 120)
	return line


func _w_progress(page: VBoxContainer) -> Control:
	var box := GoStyle.column(16)
	page.add_child(box)
	var upload := GoProgress.linear()
	upload.value = 0.4
	box.add_child(upload)
	var line := GoStyle.row(24)
	box.add_child(line)
	var ring := GoProgress.circular()
	ring.value = 0.7
	line.add_child(ring)
	var wait := GoProgress.circular(true)
	line.add_child(wait)
	return box


func _w_loading(page: VBoxContainer) -> Control:
	var line := GoStyle.row(24)
	page.add_child(line)
	line.add_child(GoLoadingIndicator.new())
	var boxed := GoLoadingIndicator.new()
	boxed.contained = true
	line.add_child(boxed)
	return line


func _w_refresh(page: VBoxContainer) -> Control:
	var feed := GoScroll.new()
	feed.custom_minimum_size.y = 240
	feed.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var rows := GoStyle.column()
	feed.add_child(rows)
	_rows(rows, 6)
	page.add_child(feed)
	var refresh := GoRefresh.attach(feed)
	refresh.refreshing = true
	return feed


func _w_alert(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.alert("Maintenance at 3 AM", GoTheme.WARNING))
	box.add_child(GoStyle.alert("Your order has shipped", GoTheme.SUCCESS))
	box.add_child(GoStyle.alert("Payment failed — try another card", GoTheme.DANGER))
	box.add_child(GoStyle.alert("New event this weekend", GoTheme.INFO))
	return box


func _w_skeleton(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.skeleton(220))
	box.add_child(GoStyle.skeleton(300))
	box.add_child(GoStyle.skeleton(160))
	box.add_child(GoStyle.empty_state(GoIconSet.BOX, "No items yet", false))
	return box


func _w_tooltip(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.icon_button(GoIconSet.SHIELD, Callable(), -1, &"Guard"))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TooltipPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(GoStyle.tooltip_node("Guard — halves the damage of the next hit. Cooldown 8 s."))
	box.add_child(panel)
	return box


# App navigation

func _w_app_bar(page: VBoxContainer) -> Control:
	var bar := GoAppBar.make("Inbox", GoIconSet.MENU)
	bar.add_action(GoIconSet.SEARCH, &"search")
	bar.add_action(GoIconSet.MORE, &"more")
	page.add_child(bar)
	return bar


func _w_nav_bar(page: VBoxContainer) -> Control:
	var nav := GoNavBar.make([{"icon": GoIconSet.HOME, "text": "Home"}, {"icon": GoIconSet.BELL, "text": "Alerts",
		"badge": 3}, {"icon": GoIconSet.BAG, "text": "Shop"}, {"icon": GoIconSet.USER, "text": "Me"}], 0)
	page.add_child(nav)
	return nav


func _w_drawer_list(page: VBoxContainer) -> Control:
	var card := GoStyle.card()
	page.add_child(card)
	card.add_child(GoNavBar.drawer_list([{"icon": GoIconSet.HOME, "text": "Inbox"},
		{"icon": GoIconSet.STAR, "text": "Starred"}, {"icon": GoIconSet.CLOCK, "text": "Snoozed"},
		{"icon": GoIconSet.TRASH, "text": "Trash"}], 0))
	return card


func _w_fab(page: VBoxContainer) -> Control:
	var line := GoStyle.row(16)
	page.add_child(line)
	line.add_child(GoFab.make(GoIconSet.PLUS, "Add to cart"))
	line.add_child(GoFab.make(GoIconSet.EDIT))
	line.add_child(GoFab.make(GoIconSet.CHAT, "", Callable(), GoFab.Size.SMALL))
	return line


func _w_search_bar(page: VBoxContainer) -> Control:
	var search := GoSearchBar.make("Search products")
	search.add_action(GoIconSet.FILTER, &"Filter")
	page.add_child(search)
	return search


func _w_split_button(page: VBoxContainer) -> Control:
	var send := GoSplitButton.make("Send", Callable(), ["Send later", "Save as draft"])
	page.add_child(send)
	return send


func _w_tab_view(page: VBoxContainer) -> Control:
	var pages: Array = []
	for text in ["12 posts", "48 photos", "3 saved"]:
		var body := GoStyle.column()
		_rows(body, 2)
		pages.append(body)
	var tabs := GoTabView.make(["Posts", "Photos", "Saved"], pages)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tabs.custom_minimum_size.y = 200
	page.add_child(tabs)
	return tabs


func _w_tabs(page: VBoxContainer) -> Control:
	var box := GoStyle.column(16)
	page.add_child(box)
	box.add_child(GoStyle.tabs(["Overview", "Stats", "Gear"], 0, false, true))
	box.add_child(GoStyle.tabs(["Daily", "Weekly", "Event", "Season"], 1))
	return box


func _w_bottom_app_bar(page: VBoxContainer) -> Control:
	var bar := GoStyle.bottom_app_bar([{"icon": GoIconSet.SEARCH, "tooltip": &"Search"},
		{"icon": GoIconSet.HEART, "tooltip": &"Like"}, {"icon": GoIconSet.DOWNLOAD, "tooltip": &"Save"}],
		GoFab.make(GoIconSet.PLUS))
	page.add_child(bar)
	return bar


func _w_toolbar(page: VBoxContainer) -> Control:
	var line := GoStyle.row(16)
	page.add_child(line)
	line.add_child(GoStyle.toolbar([{"icon": GoIconSet.EDIT, "tooltip": &"Edit"},
		{"icon": GoIconSet.COPY, "tooltip": &"Copy"}, {"icon": GoIconSet.TRASH, "tooltip": &"Delete"}]))
	line.add_child(GoStyle.toolbar([{"icon": GoIconSet.PLAY, "tooltip": &"Play"},
		{"icon": GoIconSet.PAUSE, "tooltip": &"Pause"}], true))
	return line


func _w_breadcrumb(page: VBoxContainer) -> Control:
	var trail := GoStyle.breadcrumb(["Home", "Shop", "Weapons", "Swords"])
	page.add_child(trail)
	return trail


func _w_pagination(page: VBoxContainer) -> Control:
	var pages := GoPagination.make(3, 12)
	page.add_child(pages)
	return pages


func _w_carousel(page: VBoxContainer) -> Control:
	var banners := GoCarousel.new()
	var slides: Array = []
	for spec in [["Summer event", GoTheme.WARNING], ["New hero", GoTheme.INFO], ["Starter pack", GoTheme.SUCCESS]]:
		var slide := PanelContainer.new()
		slide.custom_minimum_size.y = 120
		slide.add_theme_stylebox_override(&"panel", _fill(GoUi.color(spec[1]).darkened(0.4), 12))
		var text := GoStyle.label(spec[0], GoTheme.ROLE_TITLE)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slide.add_child(text)
		slides.append(slide)
	banners.set_pages(slides)
	page.add_child(banners)
	return banners


# Buttons, chips and choices

func _w_buttons(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var one := GoStyle.row()
	one.add_child(GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY))
	one.add_child(GoStyle.button("Details"))
	one.add_child(GoStyle.button("Outlined", Callable(), GoStyle.Tone.OUTLINED))
	box.add_child(one)
	var two := GoStyle.row()
	two.add_child(GoStyle.button("Delete", Callable(), GoStyle.Tone.DANGER))
	two.add_child(GoStyle.button("Delete forever", Callable(), GoStyle.Tone.DANGER_SOLID))
	box.add_child(two)
	var three := GoStyle.row()
	three.add_child(GoStyle.button("Compact", Callable(), GoStyle.Tone.COMPACT))
	three.add_child(GoStyle.button("Bare", Callable(), GoStyle.Tone.BARE))
	var off := GoStyle.button("Disabled")
	off.disabled = true
	three.add_child(off)
	box.add_child(three)
	return box


func _w_glow(page: VBoxContainer) -> Control:
	var line := GoStyle.row(16)
	page.add_child(line)
	line.add_child(GoStyle.glow(GoStyle.button("Claim reward", Callable(), GoStyle.Tone.PRIMARY)))
	line.add_child(GoStyle.button("Later"))
	return line


func _w_icon_buttons(page: VBoxContainer) -> Control:
	var line := GoStyle.row(8)
	page.add_child(line)
	for icon in [GoIconSet.CLOSE, GoIconSet.SETTINGS, GoIconSet.SEARCH, GoIconSet.HEART, GoIconSet.MORE]:
		line.add_child(GoStyle.icon_button(icon, Callable(), -1, icon))
	var bell := GoIconButton.new()
	bell.icon_name = GoIconSet.BELL
	line.add_child(bell)
	return line


func _w_chips(page: VBoxContainer) -> Control:
	var line := GoStyle.wrap_row()
	page.add_child(line)
	line.add_child(GoStyle.chip("Common"))
	line.add_child(GoStyle.chip("Rare", GoUi.color(GoTheme.INFO)))
	line.add_child(GoStyle.chip("Epic", GoUi.color(GoTheme.ACCENT)))
	line.add_child(GoStyle.chip("Legendary", GoUi.color(GoTheme.WARNING), false, GoIconSet.STAR))
	line.add_child(GoStyle.chip("Cursed", GoUi.color(GoTheme.DANGER), false, GoIconSet.SKULL))
	return line


func _w_filter_chips(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var filters := GoStyle.wrap_row()
	filters.add_child(GoStyle.filter_chip("In stock", true))
	filters.add_child(GoStyle.filter_chip("On sale", false))
	filters.add_child(GoStyle.filter_chip("Free shipping", false))
	box.add_child(filters)
	var to := GoStyle.wrap_row()
	to.add_child(GoStyle.input_chip("Ann", Callable(), GoIconSet.USER))
	to.add_child(GoStyle.input_chip("Ben", Callable(), GoIconSet.USER))
	to.add_child(GoStyle.input_chip("Guild: Dawn", Callable()))
	box.add_child(to)
	return box


func _w_segmented(page: VBoxContainer) -> Control:
	var control := GoStyle.segmented(["Day", "Week", "Month"], 0)
	page.add_child(control)
	return control


func _w_choice_grid(page: VBoxContainer) -> Control:
	var skins := GoStyle.choice_grid([{"color": "f6cfae", "tooltip": "Peach"}, {"color": "d9a066", "tooltip": "Honey"},
		{"color": "8d5a36", "tooltip": "Cocoa"}, {"color": "5b3a29", "tooltip": "Coffee"},
		{"icon": GoIconSet.STAR, "text": "Star"}, "Plain"], 0)
	page.add_child(skins)
	return skins


func _w_radio(page: VBoxContainer) -> Control:
	var group := GoStyle.radio_group(["Easy", "Normal", "Hard"], 1)
	page.add_child(group)
	return group


func _w_toggles(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var music := GoStyle.toggle("Music", false)
	music.button_pressed = true
	box.add_child(music)
	box.add_child(GoStyle.toggle("Vibration", false))
	var terms := GoStyle.checkbox("I agree to the terms", false)
	terms.button_pressed = true
	box.add_child(terms)
	box.add_child(GoStyle.checkbox("Send me news", false))
	return box


# Inputs and pickers

func _w_inputs(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.line_edit("Your name"))
	var filled := GoStyle.line_edit("Guild")
	filled.text = "Dawnbreakers"
	box.add_child(filled)
	box.add_child(GoStyle.textarea("Message to the guild", 3))
	return box


func _w_field(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var name_edit := GoStyle.line_edit()
	name_edit.text = "Aria"
	var field := GoField.make("Nickname", name_edit, "3–12 letters")
	field.set_error("That name is taken")
	box.add_child(field)
	box.add_child(GoField.make("Email", GoStyle.line_edit("you@example.com"), "We never share it"))
	return box


func _w_input_group(page: VBoxContainer) -> Control:
	var chat := GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": GoStyle.button("Send", Callable(),
		GoStyle.Tone.PRIMARY)})
	page.add_child(chat)
	return chat


func _w_combobox(page: VBoxContainer) -> Control:
	var friend := GoCombobox.make(["Ann", "Ben", "Cade", "Dana"], -1, "Find a friend")
	page.add_child(friend)
	return friend


func _w_code_input(page: VBoxContainer) -> Control:
	var coupon := GoCodeInput.make(8, 4)
	page.add_child(coupon)
	return coupon


func _w_select(page: VBoxContainer) -> Control:
	var line := GoStyle.row()
	page.add_child(line)
	var quality := GoStyle.select(["Low", "Medium", "High"])
	quality.select(1)
	line.add_child(quality)
	line.add_child(GoStyle.dropdown("Sort", ["Newest", "Price"]))
	return line


func _w_slider(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.label("Music volume"))
	var volume := GoStyle.slider(0.0, 1.0, 0.05)
	volume.value = 0.7
	box.add_child(volume)
	return box


func _w_range_slider(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(GoStyle.label("Price: 40 – 220"))
	box.add_child(GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0))
	return box


func _w_date_picker(page: VBoxContainer) -> Control:
	var stay := GoDatePicker.make({"year": 2026, "month": 10, "day": 14})
	page.add_child(stay)
	return stay


func _w_time_picker(page: VBoxContainer) -> Control:
	var alarm := GoTimePicker.make(7, 30)
	page.add_child(alarm)
	return alarm


func _w_wheel_picker(page: VBoxContainer) -> Control:
	var amount := GoWheelPicker.make(["x1", "x5", "x10", "x50", "x100"], 2)
	amount.custom_minimum_size = Vector2(160, 0)
	page.add_child(amount)
	return amount


func _w_stepper(page: VBoxContainer) -> Control:
	var steps: Array = []
	for title in ["Cart", "Address", "Pay"]:
		var body := GoStyle.column()
		body.add_child(GoStyle.label("%s details go here." % title))
		steps.append({"title": title, "content": body})
	var checkout := GoStepper.make(steps, 1)
	page.add_child(checkout)
	return checkout


# Lists, cards and data

func _w_list_rows(page: VBoxContainer) -> Control:
	var box := GoStyle.column(0)
	page.add_child(box)
	box.add_child(GoStyle.list_button(GoIconSet.SETTINGS, "Settings", Callable(), Color.TRANSPARENT, "", false))
	box.add_child(GoStyle.list_button(GoIconSet.USER, "Account", Callable(), Color.TRANSPARENT, "Signed in as Aria",
		false))
	box.add_child(GoStyle.list_button(GoIconSet.LOGOUT, "Sign out", Callable(), GoUi.color(GoTheme.DANGER), "", false))
	return box


func _w_list_view(page: VBoxContainer) -> Control:
	var feed := GoListView.make(10000, 64.0, func(index: int) -> Control:
		return GoStyle.list_button(GoIconSet.CHAT, "Message %d" % (index + 1), Callable(), Color.TRANSPARENT,
			"Row %d of 10,000" % (index + 1), false))
	feed.custom_minimum_size.y = 300
	feed.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	page.add_child(feed)
	return feed


func _w_reorder(page: VBoxContainer) -> Control:
	var rows: Array = []
	for title in ["Intro theme", "Town theme", "Boss battle", "Credits"]:
		rows.append(GoStyle.list_button(GoIconSet.PLAY, title, Callable(), Color.TRANSPARENT, "", false))
	var queue := GoReorderList.make(rows)
	page.add_child(queue)
	return queue


func _w_swipe_row(page: VBoxContainer) -> Control:
	var box := GoStyle.column(0)
	page.add_child(box)
	for title in ["Guild invite", "Weekly reward", "Patch notes"]:
		var mail := GoStyle.list_button(GoIconSet.CHAT, title, Callable(), Color.TRANSPARENT, "Tap to open", false)
		box.add_child(GoSwipeRow.wrap(mail, {"icon": GoIconSet.TRASH, "text": "Delete", "tone": GoTheme.DANGER,
			"action": Callable()}))
	return box


func _w_table(page: VBoxContainer) -> Control:
	var board := GoTable.make([{"text": "Rank", "width": 56}, "Name", {"text": "Score", "numeric": true}],
		[[1, "Aria", 91240], [2, "Brin", 48210], [3, "Cade", 9124], [4, "Dana", 812]])
	page.add_child(board)
	return board


func _w_cards(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	var card := GoStyle.card()
	var inside := GoStyle.column()
	inside.add_child(GoStyle.label("Daily quest", GoTheme.ROLE_SUBTITLE))
	inside.add_child(GoStyle.label("Defeat three slimes in the meadow.", GoTheme.ROLE_BODY))
	card.add_child(inside)
	box.add_child(card)
	box.add_child(GoStyle.item_card({"title": "Rusty sword", "subtitle": "Common · ATK +4", "icon": GoIconSet.SWORD}))
	return box


func _w_avatars(page: VBoxContainer) -> Control:
	var line := GoStyle.row(12)
	page.add_child(line)
	line.add_child(GoStyle.avatar("AK", 48))
	line.add_child(GoStyle.avatar("BR", 48, GoUi.color(GoTheme.SUCCESS)))
	line.add_child(GoStyle.avatar("CD", 40, GoUi.color(GoTheme.WARNING)))
	line.add_child(GoStyle.avatar("D", 32, GoUi.color(GoTheme.DANGER)))
	return line


func _w_labels(page: VBoxContainer) -> Control:
	var box := GoStyle.column(6)
	page.add_child(box)
	box.add_child(GoStyle.label("Level 12", GoTheme.ROLE_TITLE))
	box.add_child(GoStyle.label("Knight of the north", GoTheme.ROLE_SUBTITLE))
	box.add_child(GoStyle.label("A body sentence reads at the body size.", GoTheme.ROLE_BODY))
	box.add_child(GoStyle.label("Next level in 340 XP", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	return box


# HUD and game shapes

func _w_bars(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	box.add_child(_bar("HP", 320, 500, GoUi.color(GoTheme.DANGER)))
	box.add_child(_bar("MP", 140, 200, GoUi.color(GoTheme.INFO)))
	box.add_child(_bar("XP", 860, 1000, GoUi.color(GoTheme.SUCCESS)))
	for bar in box.get_children(): (bar as Control).custom_minimum_size.x = 300
	return box


func _w_slots(page: VBoxContainer) -> Control:
	var line := GoStyle.row(10)
	page.add_child(line)
	line.add_child(_slot(GoIconSet.SWORD, -1, "1"))
	line.add_child(_slot(GoIconSet.POTION, 12, "2"))
	var cool := _slot(GoIconSet.BOLT, -1, "3")
	line.add_child(cool)
	cool.set_cooldown(3.0, 8.0)
	var picked := _slot(GoIconSet.SHIELD, -1, "4")
	picked.selected = true
	line.add_child(picked)
	line.add_child(_slot(&"", -1, "5"))
	return line


func _w_slot_grid(page: VBoxContainer) -> Control:
	var bag := GoSlotGrid.new()
	bag.slot_count = 12
	page.add_child(bag)
	bag.set_cell(0, {"icon": GoIconSet.POTION, "quantity": 12})
	bag.set_cell(1, {"icon": GoIconSet.SWORD})
	bag.set_cell(2, {"icon": GoIconSet.SHIELD})
	bag.set_cell(3, {"icon": GoIconSet.KEY, "quantity": 2})
	bag.set_cell(5, {"icon": GoIconSet.COIN, "quantity": 350})
	bag.set_cell(8, {"icon": GoIconSet.MAP})
	return bag


func _w_joystick(page: VBoxContainer) -> Control:
	var pad := GoJoystick.new()
	pad.mode = GoJoystick.Mode.FIXED
	pad.custom_minimum_size = Vector2(180, 180)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(pad)
	return pad


func _w_kbd(page: VBoxContainer) -> Control:
	var box := GoStyle.column()
	page.add_child(box)
	for spec in [["E", "", "Talk"], ["Ctrl", "S", "Save"], ["Shift", "Tab", "Previous tab"]]:
		var line := GoStyle.row()
		var keys := GoKbd.make(spec[0], spec[1])
		keys.hide_on_handheld = false
		line.add_child(keys)
		line.add_child(GoStyle.label(spec[2]))
		box.add_child(line)
	return box


func _w_choice_column(page: VBoxContainer) -> Control:
	var animals := GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig", "Cow"], 4)
	animals.custom_minimum_size.x = 160
	animals.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(animals)
	animals.set_selected(2, true)
	return animals


func _w_calendar(page: VBoxContainer) -> Control:
	var days: Array = []
	for i in 7:
		days.append({"icon": GoIconSet.CROWN if i == 6 else GoIconSet.COIN, "amount": (i + 1) * 100, "special": i == 6})
	var attendance := GoRewardCalendar.make(days, 2)
	page.add_child(attendance)
	return attendance


func _w_radar(page: VBoxContainer) -> Control:
	var stats := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45},
		{"STR": 0.95, "AGI": 0.55, "INT": 0.3, "VIT": 0.6, "LUK": 0.45})
	stats.custom_minimum_size = Vector2(260, 240)
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(stats)
	return stats


func _w_donut(page: VBoxContainer) -> Control:
	var box := GoStyle.row(16)
	page.add_child(box)
	var share := GoDonut.make([{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340},
		{"label": "Poison", "value": 120}])
	share.custom_minimum_size = Vector2(150, 150)
	box.add_child(share)
	box.add_child(share.legend())
	return box


func _w_zoom_view(page: VBoxContainer) -> Control:
	var world_map := MapArt.new()
	world_map.custom_minimum_size = Vector2(358, 260)
	var map := GoZoomView.wrap(world_map, 4.0)
	map.custom_minimum_size.y = 260
	page.add_child(map)
	await _settle(4)
	map.zoom_to(1.8, Vector2(200, 120), false)
	return map


func _w_hud_panels(_page_node: VBoxContainer) -> Control:
	await _clear()
	var world := Backdrop.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_keep(world)
	var pad := GoStyle.padding(16)
	pad.theme = GoUi.theme()
	pad.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_keep(pad)
	var line := GoStyle.column(16)
	pad.add_child(line)
	var bars := GoStyle.hud_panel()
	bars.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var stack := GoStyle.column(4)
	stack.add_child(_bar("HP", 320, 500, GoUi.color(GoTheme.DANGER)))
	stack.add_child(_bar("MP", 140, 200, GoUi.color(GoTheme.INFO)))
	bars.add_child(stack)
	line.add_child(bars)
	var pill := GoStyle.overlay_panel()
	var wave := GoStyle.label("Wave 3 / 10")
	wave.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(wave)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.add_child(pill)
	return line


# Looks and system

func _w_icons(page: VBoxContainer) -> Control:
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 14)
	for icon in [GoIconSet.HOME, GoIconSet.SEARCH, GoIconSet.SETTINGS, GoIconSet.BELL, GoIconSet.USER, GoIconSet.CHAT,
			GoIconSet.HEART, GoIconSet.STAR, GoIconSet.BAG, GoIconSet.COIN, GoIconSet.GIFT, GoIconSet.MAP,
			GoIconSet.SWORD, GoIconSet.SHIELD, GoIconSet.POTION, GoIconSet.KEY, GoIconSet.CROWN, GoIconSet.FLAG,
			GoIconSet.BOLT, GoIconSet.SKULL, GoIconSet.LOCK, GoIconSet.TRASH, GoIconSet.EDIT, GoIconSet.CLOSE]:
		grid.add_child(GoUi.icons().node(icon, 28))
	page.add_child(grid)
	return grid


func _w_styleboxes(page: VBoxContainer) -> Control:
	var line := GoStyle.row(14)
	page.add_child(line)
	var cut := GoStyleBoxCut.new()
	cut.bg_color = Color("1b2a3a")
	cut.cut = 12
	cut.edge_color = Color("3fd2ff")
	var bracket := GoStyleBoxBracket.new()
	var forged := GoStyleBoxMedieval.new()
	for spec in [["Cut", cut], ["Bracket", bracket], ["Medieval", forged]]:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(106, 86)
		panel.add_theme_stylebox_override(&"panel", spec[1])
		var text := GoStyle.label(spec[0])
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(text)
		line.add_child(panel)
	return line


## A HUD plate around a part, so it reads on top of the world.
func _plate(part: Control) -> Control:
	var plate := GoStyle.hud_panel()
	plate.add_child(part)
	return plate


func _fill(color: Color, radius := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


# ── Popups, over the game ─────────────────────────────────────────────

func _popups() -> void:
	_use(WIDGET_LOOK)
	var list := [
		["dialog-confirm", func() -> void: await _confirm(false)],
		["dialog-destructive", func() -> void: await _confirm(true)],
		["dialog-alert", _alert],
		["dialog-choose", _choose],
		["dialog-horizontal", _horizontal],
		["surface-center", func() -> void: await _settings_window(GoSurface.Placement.CENTER)],
		["surface-bottom", func() -> void: await _settings_window(GoSurface.Placement.BOTTOM)],
		["surface-anchor", _anchored],
		["surface-status", _status_window],
		["surface-date", _date_window],
		["sheet", _inventory_sheet],
		["drawer-left", func() -> void: await _drawer(GoDrawer.Side.LEFT)],
		["drawer-right", func() -> void: await _drawer(GoDrawer.Side.RIGHT)],
		["popover", _popover],
		["context-menu", _context_menu],
		["dropdown", _dropdown_open],
		["select", _select_open],
		["combobox", _combobox_open],
		["prompt-card", _prompt_over_game],
		["snackbar", _snackbar],
		["notice", _notice_over_game],
		["coach-mark", _coach_mark],
		["console", _console],
		["tooltip", _tooltip_over_game],
	]
	for entry in list:
		var name: String = entry[0]
		if not _wants("popup-" + name) and not _wants(name): continue
		var build: Callable = entry[1]
		await build.call()
		await _save("popups/" + name, null, CROP_MARGIN, 14)


func _confirm(destructive: bool) -> void:
	await _clear()
	_game()
	var dialogs := GoDialogs.new()
	_keep(dialogs)
	if destructive:
		dialogs.confirm("Delete this save?", "Slot 2 — Aria, level 12. This cannot be undone.", "Delete", "Keep it",
			"", {}, true)
	else:
		dialogs.confirm("Buy the starter pack?", "300 gems for a sword, a shield and 10 potions.", "Buy", "Not now")


func _alert() -> void:
	await _clear()
	_game()
	var dialogs := GoDialogs.new()
	_keep(dialogs)
	dialogs.alert("Level up!", "You reached level 13. Two new skills are ready to learn.", "Great")


func _choose() -> void:
	await _clear()
	_game()
	var dialogs := GoDialogs.new()
	_keep(dialogs)
	dialogs.choose("Sort the bag by", ["Newest first", "Rarity", "Price", "Name"])


func _horizontal() -> void:
	await _clear()
	_game()
	var dialogs := GoDialogs.new()
	dialogs.action_layout = GoDialogs.ActionLayout.HORIZONTAL
	_keep(dialogs)
	dialogs.confirm("Leave the dungeon?", "Your progress on this floor is kept.", "Leave", "Stay")


func _settings_window(placement: GoSurface.Placement) -> void:
	await _clear()
	_game()
	var layer := _layer()
	var window := GoSurface.new()
	window.theme = GoUi.theme()
	window.placement = placement
	window.set_title("Settings")
	window.body.add_child(GoStyle.section("Sound", false))
	var music := GoStyle.toggle("Music", false)
	music.button_pressed = true
	window.body.add_child(music)
	window.body.add_child(GoStyle.toggle("Effects", false))
	window.body.add_child(GoStyle.label("Volume"))
	var volume := GoStyle.slider(0.0, 1.0, 0.05)
	volume.value = 0.6
	window.body.add_child(volume)
	window.body.add_child(GoStyle.section("Game", false))
	window.body.add_child(GoStyle.radio_group(["Easy", "Normal", "Hard"], 1))
	var row := GoStyle.row()
	var cancel := GoStyle.button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save := GoStyle.button("Save", Callable(), GoStyle.Tone.PRIMARY)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(save)
	window.footer.add_child(row)
	window.footer.visible = true
	layer.add_child(window)


func _anchored() -> void:
	await _clear()
	var page := _page()
	page.add_child(GoStyle.label("Shop", GoTheme.ROLE_TITLE))
	var line := GoStyle.row()
	page.add_child(line)
	line.add_child(GoStyle.label("24 items"))
	line.add_child(GoStyle.spacer())
	var sort := GoStyle.button("Sort: Newest")
	sort.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(sort)
	_rows(page, 6)
	await _settle(4)
	var layer := _layer()
	var card := GoSurface.new()
	card.theme = GoUi.theme()
	card.placement = GoSurface.Placement.ANCHOR
	card.anchor_control = sort
	card.anchor_width = 220.0
	card.show_header = false
	card.dismiss_on_scrim = true
	card.scrim_transparent = true
	for text in ["Newest", "Price: low to high", "Price: high to low", "Rating"]:
		card.body.add_child(GoStyle.list_button(GoIconSet.CHECK if text == "Newest" else &"", text, Callable(),
			Color.TRANSPARENT, "", false))
	layer.add_child(card)


func _status_window() -> void:
	await _clear()
	_game()
	var layer := _layer()
	var window := GoSurface.new()
	window.theme = GoUi.theme()
	window.set_title("Create a character")
	window.set_back(func() -> void: pass)
	var name_edit := GoStyle.line_edit()
	name_edit.text = "Ar"
	var field := GoField.make("Name", name_edit, "3–12 letters")
	field.set_error("Too short — 3 letters at least")
	window.body.add_child(field)
	window.body.add_child(GoStyle.label("Class"))
	window.body.add_child(GoStyle.segmented(["Knight", "Mage", "Rogue"], 1))
	window.set_status_text("Name check failed", GoTheme.DANGER)
	var create := GoStyle.button("Create", Callable(), GoStyle.Tone.PRIMARY)
	window.footer.add_child(create)
	window.footer.visible = true
	layer.add_child(window)


func _date_window() -> void:
	await _clear()
	_game()
	var layer := _layer()
	var window := GoSurface.new()
	window.theme = GoUi.theme()
	window.set_title("Pick a date")
	window.body.add_child(GoDatePicker.make({"year": 2026, "month": 10, "day": 14}))
	var row := GoStyle.row()
	var cancel := GoStyle.button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := GoStyle.button("OK", Callable(), GoStyle.Tone.PRIMARY)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(ok)
	window.footer.add_child(row)
	window.footer.visible = true
	layer.add_child(window)


func _inventory_sheet() -> void:
	await _clear()
	_game()
	var sheet := GoSheet.new()
	_keep(sheet)
	await process_frame
	sheet.open("Inventory")
	sheet.toolbar().add_child(GoStyle.line_edit("Search the bag…"))
	sheet.toolbar().visible = true
	_rows(sheet.body, 8)
	sheet.footer().add_child(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))
	sheet.footer().visible = true


func _drawer(side: GoDrawer.Side) -> void:
	await _clear()
	_game()
	var drawer := GoDrawer.new()
	drawer.motion_seconds = 0.0
	drawer.side = side
	_keep(drawer)
	await process_frame
	if side == GoDrawer.Side.LEFT:
		drawer.open("Menu")
		drawer.body.add_child(GoNavBar.drawer_list([{"icon": GoIconSet.HOME, "text": "Town"},
			{"icon": GoIconSet.MAP, "text": "World map"}, {"icon": GoIconSet.FLAG, "text": "Quests"},
			{"icon": GoIconSet.USERS, "text": "Guild"}, {"icon": GoIconSet.SETTINGS, "text": "Settings"}], 0))
	else:
		drawer.open("Bag")
		_rows(drawer.body, 7)


func _popover() -> void:
	await _clear()
	var hud := _game()
	await _settle(6)
	var slot := _first_slot(hud, 1)
	GoPopover.open(slot, GoStyle.item_card({"title": "Health potion", "subtitle": "Heals 50 HP · 12 left",
		"icon": GoIconSet.POTION}, false))


func _context_menu() -> void:
	await _clear()
	var hud := _game()
	await _settle(6)
	var slot := _first_slot(hud, 1)
	var center := slot.get_global_rect().get_center()
	GoContextMenu.open_at(slot, [{"text": "Use", "icon": GoIconSet.CHECK}, {"text": "Move to slot 1"},
		{"separator": true}, {"text": "Drop", "danger": true, "icon": GoIconSet.TRASH}], center)


func _first_slot(hud: Control, index: int) -> GoSlot:
	var found: Array[GoSlot] = []
	for node in hud.find_children("*", "GoSlot", true, false): found.append(node as GoSlot)
	return found[mini(index, found.size() - 1)]


func _dropdown_open() -> void:
	await _clear()
	var page := _page()
	page.add_child(GoStyle.label("Leaderboard", GoTheme.ROLE_TITLE))
	var sort := GoStyle.dropdown("Sort", ["Highest score", "Most wins", "Newest", "Friends only"])
	page.add_child(sort)
	page.add_child(GoTable.make([{"text": "Rank", "width": 56}, "Name", {"text": "Score", "numeric": true}],
		[[1, "Aria", 91240], [2, "Brin", 48210], [3, "Cade", 9124]]))
	await _settle(6)
	sort.show_popup()


func _select_open() -> void:
	await _clear()
	var page := _page()
	page.add_child(GoStyle.label("Graphics", GoTheme.ROLE_TITLE))
	page.add_child(GoStyle.label("Quality"))
	var quality := GoStyle.select(["Low", "Medium", "High", "Ultra"])
	quality.select(1)
	page.add_child(quality)
	page.add_child(GoStyle.toggle("Shadows", false))
	await _settle(6)
	quality.show_popup()


func _combobox_open() -> void:
	await _clear()
	var page := _page()
	page.add_child(GoStyle.label("Invite to party", GoTheme.ROLE_TITLE))
	var names := ["Aria", "Brin", "Cade", "Dana", "Eli", "Fern", "Gale", "Hugo", "Iris", "Jules"]
	var friend := GoCombobox.make(names, -1, "Find a friend")
	page.add_child(friend)
	await _settle(6)
	friend._open()


func _invite_card() -> GoPromptCard:
	var invite := GoPromptCard.new()
	invite.fade_in = false
	invite.set_title("Party invite from Ann")
	invite.set_subtitle("Dragon's Lair · 3 / 4 members")
	invite.set_icon(GoIconSet.USERS, Color.TRANSPARENT, true)
	invite.set_actions([{"text": "Accept", "action": Callable(), "primary": true}, {"text": "Decline",
		"action": Callable()}])
	return invite


func _prompt_over_game() -> void:
	await _clear()
	var hud := _game()
	var spot := GoHudAnchor.new()
	spot.spot = GoHudAnchor.Spot.TOP_CENTER
	spot.reserve_space = false
	spot.avoid_peers = true
	hud.add_child(spot)
	var invite := _invite_card()
	spot.add_child(invite)
	invite.fit_width(340)
	invite.show()


func _snackbar() -> void:
	await _clear()
	_game()
	var snack := GoSnackbar.new()
	_keep(snack)
	await process_frame
	snack.post({"text": "Rusty sword dropped", "tone": GoTheme.WARNING, "seconds": 0.0, "icon": GoIconSet.TRASH,
		"actions": ["Undo"]})


func _notice_over_game() -> void:
	await _clear()
	var hud := _game()
	var spot := GoHudAnchor.new()
	spot.spot = GoHudAnchor.Spot.TOP_CENTER
	spot.reserve_space = false
	spot.avoid_peers = true
	hud.add_child(spot)
	var notice := GoNotice.new()
	spot.add_child(notice)
	notice.show_text("Game saved", GoTheme.SUCCESS, 0.0)
	notice.custom_minimum_size.x = notice.preferred_width(340)


func _coach_mark() -> void:
	await _clear()
	var hud := _game()
	await _settle(6)
	var tour := GoCoachMark.new()
	tour.theme = GoUi.theme()
	_keep(tour)
	tour.start([{"target": _first_slot(hud, 1), "title": "Quick slots",
		"body": "Tap a potion to drink it. Long-press to move it."}, {"target": _first_slot(hud, 0), "title": "Attack",
		"body": "Your main weapon."}])


func _console() -> void:
	await _clear()
	_game()
	var console := GoConsole.new()
	console.debug_only = false
	_keep(console)
	await process_frame
	console.register("give", "Grant an item: give <id> <count>", func(_args: PackedStringArray) -> String: return "ok")
	console.register("heal", "Fill health and mana", func(_args: PackedStringArray) -> String: return "ok")
	console.open()
	console.log_line("> give potion 5")
	console.log_line("Gave 5 × potion", GoTheme.SUCCESS)
	console.input.text = "he"


func _tooltip_over_game() -> void:
	await _clear()
	var hud := _game()
	await _settle(6)
	var slot := _first_slot(hud, 2)
	var tip := PanelContainer.new()
	tip.theme_type_variation = &"TooltipPanel"
	tip.add_child(GoStyle.tooltip_node("Wooden shield — DEF +6. Blocks one arrow in three."))
	var layer := _layer()
	var holder := Control.new()
	holder.theme = GoUi.theme()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	holder.add_child(tip)
	await _settle(3)
	var rect := slot.get_global_rect()
	tip.position = Vector2(clampf(rect.end.x - tip.size.x, 8.0, SCREEN.x - tip.size.x - 8.0),
		rect.position.y - tip.size.y - 10.0)


# ── One confirmation in every look ────────────────────────────────────

func _looks() -> void:
	for look in GoThemePresets.names():
		var name := "look-%s" % look
		if not _wants(name): continue
		_use(look)
		await _confirm(false)
		await _save("popups/" + name, null, CROP_MARGIN, 14)
	_use(WIDGET_LOOK)


# ── The gallery on a phone, in every look ─────────────────────────────

func _presets() -> void:
	var scene: PackedScene = load("res://addons/gohud/examples/gallery/gallery.tscn")
	for look in GoThemePresets.names():
		var name := "gallery-%s" % look
		if not _wants(name): continue
		await _clear()
		_use(look)
		var gallery := scene.instantiate()
		_keep(gallery)
		await _save("presets/" + name, null, CROP_MARGIN, 24)
	_use(WIDGET_LOOK)


# ── What a skin draws, family by family ───────────────────────────────

func _skins() -> void:
	for look in GoThemePresets.names():
		if not String(look).ends_with("_dark"): continue
		var name := "skin-%s" % look
		if not _wants(name): continue
		_use(look)
		await _clear()
		var page := _page()
		var line := GoStyle.row(12)
		page.add_child(line)
		line.add_child(_slot(GoIconSet.SWORD, -1, "1"))
		line.add_child(_slot(GoIconSet.POTION, 12, "2"))
		var pad := GoJoystick.new()
		pad.mode = GoJoystick.Mode.FIXED
		pad.radius = 40.0
		pad.knob_radius = 16.0
		pad.custom_minimum_size = Vector2(96, 96)
		line.add_child(pad)
		var column := GoStyle.column(6)
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var family := String(look).trim_suffix("_dark")
		column.add_child(GoStyle.chip("Sci-fi" if family == "scifi" else family.capitalize(), GoUi.color(GoTheme.ACCENT)))
		line.add_child(column)
		await _save("widgets/" + name, line)
	_use(WIDGET_LOOK)


# ── Drawn parts ───────────────────────────────────────────────────────

## The world behind the HUD — a sky, two hills and a road. Plain shapes, so a popup's scrim and a translucent HUD panel
## have something real to sit on.
class Backdrop extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sky := PackedColorArray([Color("2c5d8f"), Color("2c5d8f"), Color("9fd0f0"), Color("9fd0f0")])
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.62), Vector2(0, h * 0.62)]),
			sky)
		draw_circle(Vector2(w * 0.78, h * 0.2), 34.0, Color("fff3c4"))
		var far := PackedVector2Array([Vector2(0, h * 0.6)])
		var near := PackedVector2Array([Vector2(0, h * 0.7)])
		for i in 33:
			var x := w * float(i) / 32.0
			far.append(Vector2(x, h * 0.5 + sin(float(i) * 0.45) * 26.0))
			near.append(Vector2(x, h * 0.6 + sin(float(i) * 0.3 + 1.7) * 20.0))
		far.append(Vector2(w, h * 0.6))
		far.append(Vector2(w, h))
		far.append(Vector2(0, h))
		near.append(Vector2(w, h * 0.7))
		near.append(Vector2(w, h))
		near.append(Vector2(0, h))
		draw_colored_polygon(far, Color("4d7f4a"))
		draw_colored_polygon(near, Color("3a6b35"))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.46, h * 0.64), Vector2(w * 0.54, h * 0.64),
			Vector2(w * 0.8, h), Vector2(w * 0.2, h)]), Color("b59a6a"))
		for spot in [Vector2(0.14, 0.69), Vector2(0.86, 0.72), Vector2(0.3, 0.8)]:
			var at := Vector2(w * spot.x, h * spot.y)
			draw_rect(Rect2(at + Vector2(-4, 0), Vector2(8, 26)), Color("5b3a29"))
			draw_circle(at + Vector2(0, -10), 22.0, Color("2f5a2a"))


## A small map for the zoom view — land, water and a few roads, so a zoom reads as a zoom.
class MapArt extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2f5f86"))
		draw_colored_polygon(PackedVector2Array([Vector2(30, 40), Vector2(200, 20), Vector2(330, 70),
			Vector2(320, 220), Vector2(160, 240), Vector2(40, 190)]), Color("6f9a5a"))
		draw_colored_polygon(PackedVector2Array([Vector2(150, 90), Vector2(230, 80), Vector2(250, 150),
			Vector2(170, 170)]), Color("8fb36d"))
		draw_polyline(PackedVector2Array([Vector2(60, 170), Vector2(140, 130), Vector2(210, 120), Vector2(300, 90)]),
			Color("e8d9a8"), 3.0)
		for spot in [Vector2(60, 170), Vector2(210, 120), Vector2(300, 90)]:
			draw_circle(spot, 6.0, Color("c0392b"))
