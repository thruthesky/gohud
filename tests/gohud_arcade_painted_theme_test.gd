## 🧪 **Checks for the painted arcade_light theme** — the `.tres` `tools/theme_arcade_painted.py` writes: the painted
## sprite faces (`GoStyleBoxSprite`) with the edges, scales, tints and padding of Magnet Mayhem's `UiTheme`, the
## variations it names (`tools/arcade_painted_map.json`), the label inks and the palette tokens. Its own file, so it never
## clashes with the arcade checks (`gohud_arcade_test.gd`, which keeps `arcade_dark` code-drawn).
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_arcade_painted_theme_test.gd" bash addons/gohud/tools/run_tests.sh
##
## 🔑 The class is looked up by name (`get_global_name()`), not cast: the theme check must read even while the sprite
##    StyleBox is being written, and say what is wrong instead of failing to parse.
extends SceneTree

const LIGHT := "res://addons/gohud/themes/gohud_arcade_light.tres"
const DARK := "res://addons/gohud/themes/gohud_arcade_dark.tres"
const PAINTED := "res://addons/gohud/assets/arcade_light/painted/"

# The game's constants (Magnet Mayhem `src/ui/ui_theme.gd`) — the values the painted look must carry.
const INK := Color("#1d2340")
const GOLD := Color("#ffc928")
const RED := Color("#ff4d4d")
const GREEN := Color("#3ecf5a")
const CONTROL_BLUE := Color("#3d6bff")
const DIFF_BG := Color("#eef1fb")
const DIFF_SELECTED := Color("#7fe4ff")
const BAR_BG := Color("#d9deef")
const STAGE_SKY := Color(0.36, 0.62, 0.92, 1.0)
const OVERLAY := Color(20.0 / 255.0, 40.0 / 255.0, 80.0 / 255.0, 0.25)
const PRESSED_TINT := Color(0.8, 0.8, 0.86)
const DISABLED_TINT := Color(0.6, 0.6, 0.66, 0.85)
const GLOSS_EDGE := Vector4(100, 65, 100, 66)
const KEY_EDGE := Vector4(70, 70, 70, 80)
const RIBBON_EDGE := Vector4(100, 80, 100, 80)

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	var light := load(LIGHT) as Theme
	var dark := load(DARK) as Theme
	check(light != null and dark != null, "both arcade themes load")
	if light != null:
		_buttons(light)
		_panels(light)
		_variations(light)
		_inks(light)
		_tokens(light)
		_item_sets(light)
	if dark != null:
		_dark_stays(dark)
	print("gohud arcade painted theme tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func _is_sprite(box: StyleBox) -> bool:
	return box != null and box.get_script() != null and (box.get_script() as Script).get_global_name() == &"GoStyleBoxSprite"


func _margins(box: StyleBox) -> Array[float]:
	var out: Array[float] = []
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: out.append(box.get_content_margin(side))
	return out


## One painted face: the sprite, its 9-slice edge (texture px), its scale, its tint, its padding (l, t, r, b).
func _sprite(theme: Theme, state: StringName, type: StringName, file: String, edge: Vector4, ppu: float, tint: Color,
		margins: Array[float]) -> void:
	var label := "%s/%s" % [type, state]
	if not theme.has_stylebox(state, type):
		check(false, "%s is set" % label)
		return
	var box := theme.get_stylebox(state, type)
	check(_is_sprite(box), "%s is a GoStyleBoxSprite (got %s)" % [label, box.get_class() if box else "null"])
	if not _is_sprite(box): return
	var texture := box.get(&"texture") as Texture2D
	check(texture != null and texture.resource_path == PAINTED + file,
		"%s draws %s (got %s)" % [label, file, texture.resource_path if texture else "nothing"])
	check(box.get(&"edge") == edge, "%s edge %s (got %s)" % [label, str(edge), str(box.get(&"edge"))])
	check(is_equal_approx(float(box.get(&"pixels_per_unit")), ppu), "%s pixels_per_unit %.1f (got %s)" % [label, ppu,
		str(box.get(&"pixels_per_unit"))])
	check((box.get(&"tint") as Color).is_equal_approx(tint), "%s tint %s (got %s)" % [label, str(tint), str(box.get(&"tint"))])
	check(box.get(&"draw_center") == true, "%s draws its centre" % label)
	check(_margins(box) == margins, "%s padding %s (got %s)" % [label, str(margins), str(_margins(box))])
	var face := box.get(&"face_color") as Color
	check(face.a > 0.0, "%s names the colour of its plate (face_color %s)" % [label, str(face)])


## 💊 The glossy pills: one sprite in every state, darker when pressed (the label two pixels lower), faded when off.
func _gloss(theme: Theme, type: StringName, file: String) -> void:
	_sprite(theme, &"normal", type, file, GLOSS_EDGE, 3.0, Color.WHITE, [22.0, 3.0, 22.0, 6.0])
	_sprite(theme, &"hover", type, file, GLOSS_EDGE, 3.0, Color.WHITE, [22.0, 3.0, 22.0, 6.0])
	_sprite(theme, &"pressed", type, file, GLOSS_EDGE, 3.0, PRESSED_TINT, [22.0, 5.0, 22.0, 4.0])
	_sprite(theme, &"hover_pressed", type, file, GLOSS_EDGE, 3.0, PRESSED_TINT, [22.0, 5.0, 22.0, 4.0])
	_sprite(theme, &"disabled", type, file, GLOSS_EDGE, 3.0, DISABLED_TINT, [22.0, 3.0, 22.0, 6.0])
	check(theme.get_stylebox(&"focus", type) is StyleBoxEmpty, "%s/focus draws nothing (the game's pill has no ring)" % type)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color"]:
		check(theme.get_color(slot, type) == Color.WHITE, "%s/%s is white" % [type, slot])
	check(theme.get_color(&"font_disabled_color", type).is_equal_approx(Color(1, 1, 1, 0.6)), "%s: a faded white when off" % type)
	check(theme.get_constant(&"outline_size", type) == 4, "%s: a 4 px outline (got %d)" % [type, theme.get_constant(&"outline_size", type)])
	check(theme.get_color(&"font_outline_color", type).is_equal_approx(INK), "%s: the outline is the ink" % type)
	check(theme.get_constant(&"h_separation", type) == 10, "%s: 10 px between glyph and word" % type)
	check(theme.get_font_size(&"font_size", type) == 22, "%s: the game's 22 px label (GLOSS_FONT_SIZE, not a Cfg size)" % type)


func _buttons(theme: Theme) -> void:
	_gloss(theme, &"GoButton", "btn_grey.png")
	_gloss(theme, &"GoPrimaryButton", "btn_blue.png")
	_gloss(theme, &"GoDangerButton", "btn_red.png")
	_gloss(theme, &"GoSuccessButton", "btn_green.png")
	# The toggle: the grey pill, blue while it is on.
	_sprite(theme, &"normal", &"GoToggleButton", "btn_grey.png", GLOSS_EDGE, 3.0, Color.WHITE, [22.0, 3.0, 22.0, 6.0])
	_sprite(theme, &"pressed", &"GoToggleButton", "btn_blue.png", GLOSS_EDGE, 3.0, Color.WHITE, [22.0, 3.0, 22.0, 6.0])
	_sprite(theme, &"hover_pressed", &"GoToggleButton", "btn_blue.png", GLOSS_EDGE, 3.0, Color.WHITE, [22.0, 3.0, 22.0, 6.0])
	_sprite(theme, &"disabled", &"GoToggleButton", "btn_grey.png", GLOSS_EDGE, 3.0, DISABLED_TINT, [22.0, 3.0, 22.0, 6.0])
	check(theme.get_color(&"font_pressed_color", &"GoToggleButton") == Color.WHITE, "GoToggleButton: white on blue")
	# ⌨ A keyboard key (the rebind buttons).
	_sprite(theme, &"normal", &"GoKeycap", "keycap.png", KEY_EDGE, 5.5, Color.WHITE, [10.0, 3.0, 10.0, 8.0])
	_sprite(theme, &"pressed", &"GoKeycap", "keycap.png", KEY_EDGE, 5.5, PRESSED_TINT, [10.0, 6.0, 10.0, 5.0])
	check(theme.get_stylebox(&"focus", &"GoKeycap") is StyleBoxEmpty, "GoKeycap/focus draws nothing")
	check(theme.get_color(&"font_color", &"GoKeycap").is_equal_approx(INK), "GoKeycap: the word is the ink")
	check(not theme.has_constant(&"outline_size", &"GoKeycap"), "GoKeycap: no outline of its own (the game sets none)")
	check(theme.get_font_size(&"font_size", &"GoKeycap") == 16, "GoKeycap: the game's 16 px")
	# The dropdown: a white box with a navy rim and a thicker bottom.
	var drop := theme.get_stylebox(&"normal", &"OptionButton") as StyleBoxFlat
	check(drop != null and drop.bg_color == Color.WHITE and drop.border_color.is_equal_approx(INK)
		and drop.border_width_left == 3 and drop.border_width_bottom == 5 and drop.corner_radius_top_left == 10,
		"OptionButton: the game's white dropdown box")
	var down := theme.get_stylebox(&"pressed", &"OptionButton") as StyleBoxFlat
	check(down != null and down.bg_color.is_equal_approx(DIFF_BG), "OptionButton: pressed, the pale blue")
	check(theme.get_color(&"font_color", &"OptionButton").is_equal_approx(INK) and theme.get_constant(&"outline_size", &"OptionButton") == 0,
		"OptionButton: ink text, no outline")
	check(theme.get_font_size(&"font_size", &"OptionButton") == 17 and theme.get_font_size(&"font_size", &"PopupMenu") == 17,
		"OptionButton and PopupMenu: the game's 17 px")
	var list := theme.get_stylebox(&"panel", &"PopupMenu") as StyleBoxFlat
	check(list != null and list.bg_color == Color.WHITE and list.border_color.is_equal_approx(INK) and list.corner_radius_top_left == 12,
		"PopupMenu: the game's white list")
	var lit := theme.get_stylebox(&"hover", &"PopupMenu") as StyleBoxFlat
	check(lit != null and lit.bg_color.is_equal_approx(DIFF_SELECTED), "PopupMenu: a hovered row is the light cyan")
	check(theme.get_constant(&"v_separation", &"PopupMenu") == 10, "PopupMenu: finger-sized rows (10)")


func _panels(theme: Theme) -> void:
	_sprite(theme, &"panel", &"GoCard", "card.png", Vector4(100, 100, 100, 140), 3.0, Color.WHITE, [24.0, 20.0, 24.0, 22.0])
	_sprite(theme, &"panel", &"GoInsetPanel", "inset.png", Vector4(60, 60, 60, 60), 3.0, Color.WHITE, [14.0, 8.0, 14.0, 8.0])
	_sprite(theme, &"panel", &"GoKeycapPanel", "keycap.png", KEY_EDGE, 5.5, Color.WHITE, [9.0, 1.0, 9.0, 5.0])
	_sprite(theme, &"panel", &"GoRibbon", "ribbon_gold.png", RIBBON_EDGE, 3.4, Color.WHITE, [22.0, 6.0, 22.0, 12.0])
	_sprite(theme, &"panel", &"GoRibbonRed", "ribbon_red.png", RIBBON_EDGE, 3.4, Color.WHITE, [22.0, 6.0, 22.0, 12.0])
	# 🔔 The notice is the game's flat white pill with the blue rim (`UiTheme.chunky_box`) — the game draws it in code.
	var notice := theme.get_stylebox(&"panel", &"GoNotice") as StyleBoxFlat
	check(notice != null, "GoNotice/panel is the game's flat pill")
	if notice != null:
		check(notice.bg_color.is_equal_approx(Color(1, 1, 1, 0.9)) and notice.border_color.is_equal_approx(CONTROL_BLUE),
			"GoNotice: white at 90%, a blue rim")
		check(notice.border_width_left == 3 and notice.border_width_top == 3 and notice.border_width_bottom == 5
			and notice.corner_radius_top_left == 16, "GoNotice: a 3 px rim, 5 at the bottom, 16 px corners")
		check(_margins(notice) == [12.0, 5.0, 12.0, 7.0], "GoNotice padding (got %s)" % str(_margins(notice)))
		check(notice.shadow_color.is_equal_approx(INK) and notice.shadow_size == 3 and notice.shadow_offset == Vector2(0, 2),
			"GoNotice: the thin navy edge under it")


func _variations(theme: Theme) -> void:
	var bases := {
		&"GoButton": &"Button", &"GoPrimaryButton": &"Button", &"GoDangerButton": &"Button",
		&"GoSuccessButton": &"Button", &"GoToggleButton": &"Button", &"GoKeycap": &"Button",
		&"GoCard": &"PanelContainer", &"GoInsetPanel": &"PanelContainer", &"GoKeycapPanel": &"PanelContainer",
		&"GoRibbon": &"PanelContainer", &"GoRibbonRed": &"PanelContainer", &"GoNotice": &"PanelContainer",
		&"GoTitle": &"Label", &"GoOutlineLabel": &"Label",
	}
	for type: StringName in bases:
		check(theme.is_type_variation(type, bases[type]), "%s is a variation of %s (got %s)" % [type, bases[type],
			theme.get_type_variation_base(type)])
	# The map the game aliases its old names by names only variations this theme has, and keeps the game's own out.
	var file := FileAccess.open("res://addons/gohud/tools/arcade_painted_map.json", FileAccess.READ)
	check(file != null, "tools/arcade_painted_map.json exists")
	if file == null: return
	var map: Variant = JSON.parse_string(file.get_as_text())
	check(map is Dictionary, "the map is a JSON object")
	if not (map is Dictionary): return
	for game: String in map:
		if game == "game_only" or game.begins_with("_"): continue
		check(theme.get_type_variation_base(StringName(map[game])) != &"", "map: %s → %s is in the theme" % [game, map[game]])
	check(map.get("game_only", []) is Array and (map["game_only"] as Array).has("StageWindow"), "map: the stage art stays in the game")
	for kept: String in map.get("game_only", []):
		check(not map.has(kept), "map: %s is either moved or kept, not both" % kept)


func _inks(theme: Theme) -> void:
	check(theme.get_color(&"font_color", &"Label").is_equal_approx(INK), "Label: the ink")
	check(theme.get_color(&"font_outline_color", &"Label").is_equal_approx(INK), "Label: an ink outline when one is asked for")
	check(theme.get_constant(&"outline_size", &"Label") == 0, "Label: no outline of its own")
	check(theme.get_color(&"font_color", &"GoTitle") == Color.WHITE and theme.get_constant(&"outline_size", &"GoTitle") == 6
		and theme.get_constant(&"line_spacing", &"GoTitle") == -6, "GoTitle: white, a 6 px outline, lines drawn together")
	check(theme.get_color(&"font_color", &"GoOutlineLabel") == Color.WHITE and theme.get_constant(&"outline_size", &"GoOutlineLabel") == 6,
		"GoOutlineLabel: white with a 6 px outline")


func _tokens(theme: Theme) -> void:
	var want := {
		&"text": INK, &"border": INK, &"surface": Color.WHITE, &"surface_soft": DIFF_BG, &"surface_high": BAR_BG,
		&"track": BAR_BG, &"background": STAGE_SKY, &"scrim": OVERLAY, &"on_accent": Color.WHITE,
		&"accent_vivid": CONTROL_BLUE, &"success_vivid": GREEN, &"danger_vivid": RED, &"warning_vivid": GOLD,
		&"info_vivid": DIFF_SELECTED,
	}
	for key: StringName in want:
		var got := theme.get_color(key, &"GoHud")
		check(got.is_equal_approx(want[key]) or got.to_html() == (want[key] as Color).to_html(),
			"token %s is the game's %s (got %s)" % [key, (want[key] as Color).to_html(), got.to_html()])


## 🔑 Each painted variation carries exactly the items the game's variation has (`UiTheme._build()`), no more: the
##    game builds its theme as a duplicate of this one plus aliases, so a stray item would change how it looks.
func _item_sets(theme: Theme) -> void:
	var gloss_colors := ["font_color", "font_disabled_color", "font_focus_color", "font_hover_color",
		"font_hover_pressed_color", "font_outline_color", "font_pressed_color"]
	var gloss := {"styles": ["disabled", "focus", "hover", "hover_pressed", "normal", "pressed"], "colors": gloss_colors,
		"constants": ["h_separation", "outline_size"], "font_sizes": ["font_size"]}
	var panel := {"styles": ["panel"], "colors": [], "constants": [], "font_sizes": []}
	var want := {
		&"GoButton": gloss, &"GoPrimaryButton": gloss, &"GoDangerButton": gloss, &"GoSuccessButton": gloss,
		&"GoToggleButton": gloss,
		&"GoKeycap": {"styles": ["focus", "hover", "hover_pressed", "normal", "pressed"],
			"colors": ["font_color", "font_focus_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color"],
			"constants": [], "font_sizes": ["font_size"]},
		&"GoCard": panel, &"GoInsetPanel": panel, &"GoKeycapPanel": panel, &"GoRibbon": panel, &"GoRibbonRed": panel,
		&"GoNotice": panel,
		&"GoTitle": {"styles": [], "colors": ["font_color"], "constants": ["line_spacing", "outline_size"],
			"font_sizes": ["font_size"]},
		&"GoOutlineLabel": {"styles": [], "colors": ["font_color"], "constants": ["outline_size"], "font_sizes": []},
	}
	for type: StringName in want:
		var got := {"styles": _sorted(theme.get_stylebox_list(type)), "colors": _sorted(theme.get_color_list(type)),
			"constants": _sorted(theme.get_constant_list(type)), "font_sizes": _sorted(theme.get_font_size_list(type))}
		for kind: String in got:
			check(got[kind] == want[type][kind], "%s %s are the game's %s (got %s)" % [type, kind, str(want[type][kind]),
				str(got[kind])])
		check(theme.get_font_list(type).is_empty() and theme.get_icon_list(type).is_empty(),
			"%s: no font and no icon (the game adds its own fonts)" % type)


func _sorted(names: PackedStringArray) -> Array:
	var out: Array = Array(names)
	out.sort()
	return out


## 🌙 arcade_dark keeps its code-drawn keys and boards.
func _dark_stays(theme: Theme) -> void:
	for spot: Array in [[&"normal", &"Button"], [&"normal", &"GoPrimaryButton"], [&"panel", &"GoCard"]]:
		var box := theme.get_stylebox(spot[0], spot[1])
		check(box is GoStyleBoxArcade, "arcade_dark: %s/%s is still a GoStyleBoxArcade" % [spot[1], spot[0]])
		check(not _is_sprite(box), "arcade_dark: %s/%s is not painted art" % [spot[1], spot[0]])
	check(not theme.has_type_variation_list_entry(&"GoSuccessButton") if theme.has_method(&"has_type_variation_list_entry") else
		theme.get_type_variation_base(&"GoSuccessButton") == &"", "arcade_dark: the painted-only variations stay out")
