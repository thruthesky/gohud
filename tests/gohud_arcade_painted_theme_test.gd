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
## A file named "stage/…" is the stage-select art, next to `painted/`.
const ART := "res://addons/gohud/assets/arcade_light/"

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
const PANEL := Color(1.0, 1.0, 1.0, 0.9)
## The stage-select art (`UiTheme` `STAGE_*`).
const STAGE_CARD_EDGE := Vector4(60, 60, 60, 60)
const STAGE_CARD_PPU := 2.2
const STAGE_RIBBON_PPU := 2.4
const STAGE_WELL_EDGE := Vector4(60, 60, 60, 60)
const STAGE_WELL_PPU := 3.0
## `Cfg.Hud.PANEL_PADDING` / `BANNER_PADDING` and `Cfg.Menu.CHIP_FONT` at their desktop value.
const HUD_PANEL_PADDING := 8.0
const HUD_BANNER_PADDING := 4.0
const CHIP_FONT := 15
const SECONDARY := Color("#8a8fb3")
## The loading screen's blocks (`UiTheme` `LOAD_TILE`, `LOAD_TILE_RIM`, `LOAD_TILE_LIT_RIM`).
const LOAD_TILE := Color("#2e3766")
const LOAD_TILE_RIM := Color("#151a38")
const LOAD_TILE_LIT_RIM := Color("#c98a00")
# The slider and the switch (`PaintedSlider`, `PaintedSwitch`).
const BAR_EDGE := Vector4(48, 38, 48, 38)
const HANDLE_SIZE := Vector2(36, 36)
const SWITCH_SIZE := Vector2(76, 29)

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	var light := load(LIGHT) as Theme
	var dark := load(DARK) as Theme
	check(light != null and dark != null, "both arcade themes load")
	if light != null:
		_buttons(light)
		_panels(light)
		_game_parts(light)
		_flat_parts(light)
		_variations(light)
		_inks(light)
		_tokens(light)
		_item_sets(light)
		_engine_bases(light)
		await _scoreboard(light)
		_no_orphans()
		await _slider(light)
		await _range_slider(light)
		_switch(light)
		_field(light)
		_font(light)
		_locale_lead()
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
	var want_path := (ART + file) if file.contains("/") else (PAINTED + file)
	check(texture != null and texture.resource_path == want_path,
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
	# 🔑 The game's main actions (PLAY, CONFIRM — `GlossGreen`) are green, so the primary key is the green pill; the
	#    blue pill (`GlossBlue`) is the info key.
	_gloss(theme, &"GoPrimaryButton", "btn_green.png")
	_gloss(theme, &"GoInfoButton", "btn_blue.png")
	_gloss(theme, &"GoDangerButton", "btn_red.png")
	_gloss(theme, &"GoSuccessButton", "btn_green.png")
	# 🔑 The sign-in keys (gohud's own): the blue pill repainted black (white outlined label, as every pill) and white
	#    (an ink label, no outline). Neither sets an icon colour, so a glyph keeps its own colours (the Google G).
	_gloss(theme, &"GoBlackButton", "btn_black.png")
	for state: StringName in [&"normal", &"hover"]:
		_sprite(theme, state, &"GoWhiteButton", "btn_white.png", GLOSS_EDGE, 3.0, Color.WHITE, [22.0, 3.0, 22.0, 6.0])
	for state: StringName in [&"pressed", &"hover_pressed"]:
		_sprite(theme, state, &"GoWhiteButton", "btn_white.png", GLOSS_EDGE, 3.0, PRESSED_TINT, [22.0, 5.0, 22.0, 4.0])
	_sprite(theme, &"disabled", &"GoWhiteButton", "btn_white.png", GLOSS_EDGE, 3.0, DISABLED_TINT, [22.0, 3.0, 22.0, 6.0])
	check(theme.get_stylebox(&"focus", &"GoWhiteButton") is StyleBoxEmpty, "GoWhiteButton/focus draws nothing")
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color"]:
		check(theme.get_color(slot, &"GoWhiteButton").is_equal_approx(INK), "GoWhiteButton/%s is the ink" % slot)
	check(theme.get_constant(&"outline_size", &"GoWhiteButton") == 0, "GoWhiteButton: no outline on the white key")
	check(theme.get_font_size(&"font_size", &"GoWhiteButton") == 22, "GoWhiteButton: the pills' 22 px label")
	for type: StringName in [&"GoWhiteButton", &"GoBlackButton"]:
		check(not theme.has_color(&"icon_normal_color", type), "%s leaves the icon colour white (a glyph keeps its colours)" % type)
		var face := theme.get_stylebox(&"normal", type).get(&"face_color") as Color
		var text := theme.get_color(&"font_color", type)
		var lum := func(c: Color) -> float: return 0.2126 * c.srgb_to_linear().r + 0.7152 * c.srgb_to_linear().g + 0.0722 * c.srgb_to_linear().b
		var hi := maxf(lum.call(face), lum.call(text))
		var lo := minf(lum.call(face), lum.call(text))
		check((hi + 0.05) / (lo + 0.05) >= 4.5, "%s: its label reads on its face (contrast %.1f)" % [type, (hi + 0.05) / (lo + 0.05)])
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
	# A right-to-left layout draws the mirrored faces: each is the painted box of its left-to-right state.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var ltr := theme.get_stylebox(StringName(state), &"OptionButton")
		var rtl := theme.get_stylebox(StringName(state + "_mirrored"), &"OptionButton")
		check(rtl != null and rtl == ltr, "OptionButton/%s_mirrored: the same painted box as %s (got %s)"
			% [state, state, rtl.resource_path if rtl else "none"])
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
	# The game's dropdown keeps the engine's arrow and the list the engine's radio marks and row padding (its
	# OptionButton items are radio items, so the marks are drawn): gohud sets none of them.
	for item: StringName in [&"arrow", &"arrow_margin"]:
		check(not (theme.has_icon(item, &"OptionButton") or theme.has_constant(item, &"OptionButton")),
			"OptionButton/%s is the engine's, as in the game" % item)
	for item: StringName in [&"radio_checked", &"radio_unchecked", &"checked", &"unchecked", &"radio_checked_disabled",
			&"radio_unchecked_disabled", &"checked_disabled", &"unchecked_disabled"]:
		check(not theme.has_icon(item, &"PopupMenu"), "PopupMenu/%s is the engine's, as in the game" % item)
	for item: StringName in [&"h_separation", &"icon_max_width", &"item_start_padding", &"item_end_padding"]:
		check(not theme.has_constant(item, &"PopupMenu"), "PopupMenu/%s is the engine's, as in the game" % item)


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


## [param box] is `UiTheme.chunky_box(bg, radius, margin_h, margin_v, outline, bottom_edge, rim, outer)` exactly.
func _chunky(theme: Theme, state: StringName, type: StringName, bg: Color, radius: int, margin_h: float, margin_v: float,
		outline: int, bottom_edge: int, rim: Color, outer: bool) -> void:
	var label := "%s/%s" % [type, state]
	var flat := theme.get_stylebox(state, type) as StyleBoxFlat if theme.has_stylebox(state, type) else null
	check(flat != null, "%s is a StyleBoxFlat" % label)
	if flat == null: return
	check(flat.bg_color.is_equal_approx(bg), "%s bg %s (got %s)" % [label, bg.to_html(), flat.bg_color.to_html()])
	check(flat.border_color.is_equal_approx(rim), "%s rim %s (got %s)" % [label, rim.to_html(), flat.border_color.to_html()])
	check(flat.border_width_left == outline and flat.border_width_top == outline and flat.border_width_right == outline
		and flat.border_width_bottom == bottom_edge, "%s border %d, bottom %d (got %d %d %d %d)" % [label, outline, bottom_edge,
		flat.border_width_left, flat.border_width_top, flat.border_width_right, flat.border_width_bottom])
	for corner: Corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT]:
		check(flat.get_corner_radius(corner) == radius, "%s corner %d radius %d" % [label, corner, radius])
	var margins: Array[float] = [margin_h, margin_v + outline, margin_h, margin_v + bottom_edge]
	check(_margins(flat) == margins, "%s padding %s (got %s)" % [label, str(margins), str(_margins(flat))])
	if outer:
		check(flat.shadow_color.is_equal_approx(INK) and flat.shadow_size == 3 and flat.shadow_offset == Vector2(0, 2),
			"%s: the thin navy edge (shadow INK 3 px, offset 0,2)" % label)
	else:
		check(flat.shadow_size == 0, "%s: no shadow (got %d)" % [label, flat.shadow_size])
	check(flat.draw_center and flat.anti_aliasing and flat.expand_margin_top == 0.0, "%s: drawn filled, anti-aliased" % label)


## 🗺 The game's stage-select art, HUD boxes, chip and frameless key (`UiTheme._build()`), value for value.
func _game_parts(theme: Theme) -> void:
	_sprite(theme, &"panel", &"GoWindowBlue", "stage/window.png", Vector4(70, 70, 70, 70), 3.0, Color.WHITE,
		[24.0, 20.0, 24.0, 22.0])
	_sprite(theme, &"panel", &"GoRibbonWide", "stage/ribbon_title.png", Vector4(200, 50, 200, 50), STAGE_RIBBON_PPU,
		Color.WHITE, [70.0, 6.0, 70.0, 12.0])
	_sprite(theme, &"panel", &"GoWell", "stage/well.png", STAGE_WELL_EDGE, STAGE_WELL_PPU, Color.WHITE, [0.0, 0.0, 0.0, 0.0])
	for pair: Array in [[&"GoLevelCard", "stage/card_cleared.png"], [&"GoLevelCardCurrent", "stage/card_current.png"],
			[&"GoLevelCardLocked", "stage/card_locked.png"]]:
		var zero: Array[float] = [0.0, 0.0, 0.0, 0.0]
		for state: StringName in [&"normal", &"hover", &"disabled"]:
			_sprite(theme, state, pair[0], pair[1], STAGE_CARD_EDGE, STAGE_CARD_PPU, Color.WHITE, zero)
		for state: StringName in [&"pressed", &"hover_pressed"]:
			_sprite(theme, state, pair[0], pair[1], STAGE_CARD_EDGE, STAGE_CARD_PPU, PRESSED_TINT, zero)
		check(theme.get_stylebox(&"focus", pair[0]) is StyleBoxEmpty, "%s/focus draws nothing" % pair[0])
		check(theme.get_stylebox(&"normal", pair[0]) == theme.get_stylebox(&"disabled", pair[0]),
			"%s: disabled is the normal face (the game's)" % pair[0])
	# The HUD's boxes, the player's own notice, the language chip.
	_chunky(theme, &"panel", &"GoHudPanel", PANEL, 18, HUD_PANEL_PADDING + 5.0, HUD_PANEL_PADDING, 5, 8, CONTROL_BLUE, true)
	_chunky(theme, &"panel", &"GoBannerGold", GOLD, 12, HUD_BANNER_PADDING + 3.0, HUD_BANNER_PADDING, 3, 5, INK, false)
	_chunky(theme, &"panel", &"GoNoticeGold", Color("#fff3cf"), 16, 12.0, 2.0, 3, 5, GOLD, true)
	_chunky(theme, &"panel", &"GoNotice", PANEL, 16, 12.0, 2.0, 3, 5, CONTROL_BLUE, true)
	for state: StringName in [&"normal", &"hover"]:
		_chunky(theme, state, &"GoChipDark", Color("#232b57"), 22, 16.0, 0.0, 3, 4, Color("#6f95ff"), true)
	for state: StringName in [&"pressed", &"hover_pressed"]:
		_chunky(theme, state, &"GoChipDark", Color("#171d42"), 22, 16.0, 0.0, 3, 4, Color("#6f95ff"), true)
	check(theme.get_stylebox(&"focus", &"GoChipDark") is StyleBoxEmpty, "GoChipDark/focus draws nothing")
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color"]:
		check(theme.get_color(slot, &"GoChipDark") == Color.WHITE, "GoChipDark/%s is white" % slot)
	check(theme.get_font_size(&"font_size", &"GoChipDark") == CHIP_FONT, "GoChipDark: Cfg.Menu.CHIP_FONT (15)")
	check(theme.get_constant(&"h_separation", &"GoChipDark") == 8, "GoChipDark: 8 px between glyph and word")
	# 🏁 The score rows are glossy arcade plates. A transparent header keeps their column margins.
	var head := theme.get_stylebox(&"panel", &"GoScoreHead") if theme.has_stylebox(&"panel", &"GoScoreHead") else null
	check(head is StyleBoxEmpty, "GoScoreHead/panel draws nothing (got %s)" % head)
	if head != null:
		check(head.content_margin_left == 12.0 and head.content_margin_right == 12.0,
			"GoScoreHead: the rows' 12 px side margins (got %s, %s)" % [head.content_margin_left, head.content_margin_right])
		check(head.content_margin_top < 0.0 and head.content_margin_bottom < 0.0,
			"GoScoreHead: no top or bottom margin of its own, as in the game")
		var row := theme.get_stylebox(&"panel", &"GoScoreRow")
		check(row != null and head.get_margin(SIDE_LEFT) == row.get_margin(SIDE_LEFT)
			and head.get_margin(SIDE_RIGHT) == row.get_margin(SIDE_RIGHT), "GoScoreHead: its labels sit over the rows' columns")
	# 🧱 The loading screen's blocks (`LoadTile`, `LoadTileLit`): navy in a dark rim until lit, then gold in amber.
	_chunky(theme, &"panel", &"GoTile", LOAD_TILE, 9, 0.0, 0.0, 3, 8, LOAD_TILE_RIM, false)
	_chunky(theme, &"panel", &"GoTileLit", GOLD, 9, 0.0, 0.0, 3, 8, LOAD_TILE_LIT_RIM, false)
	# The frameless key: nothing in any state, the icon darker while pressed.
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		check(theme.get_stylebox(state, &"GoIconOnly") is StyleBoxEmpty, "GoIconOnly/%s draws nothing" % state)
	for slot: StringName in [&"icon_pressed_color", &"icon_hover_pressed_color"]:
		check(theme.get_color(slot, &"GoIconOnly").is_equal_approx(Color(0.78, 0.78, 0.86)), "GoIconOnly/%s is the game's" % slot)


## [param flat] is `UiTheme.box(bg, radius, border, INK, shadow, ...)` with [param margins] and a [param bottom] edge.
func _flat(theme: Theme, state: StringName, type: StringName, bg: Color, radius: int, border: int, bottom: int,
		margins: Array[float], shadow: bool, expand_top := 0.0) -> void:
	var label := "%s/%s" % [type, state]
	var flat := theme.get_stylebox(state, type) as StyleBoxFlat if theme.has_stylebox(state, type) else null
	check(flat != null, "%s is a StyleBoxFlat" % label)
	if flat == null: return
	check(flat.bg_color.is_equal_approx(bg), "%s bg %s (got %s)" % [label, bg.to_html(), flat.bg_color.to_html()])
	check(flat.border_color.is_equal_approx(INK), "%s: an ink rim" % label)
	check(flat.border_width_left == border and flat.border_width_top == border and flat.border_width_right == border
		and flat.border_width_bottom == bottom, "%s border %d, bottom %d (got %d %d %d %d)" % [label, border, bottom,
		flat.border_width_left, flat.border_width_top, flat.border_width_right, flat.border_width_bottom])
	for corner: Corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT]:
		check(flat.get_corner_radius(corner) == radius, "%s corner %d radius %d" % [label, corner, radius])
	check(_margins(flat) == margins, "%s padding %s (got %s)" % [label, str(margins), str(_margins(flat))])
	if shadow:
		check(flat.shadow_color.is_equal_approx(Color(0, 0, 0, 0.25)) and flat.shadow_size == 1
			and flat.shadow_offset == Vector2(0, 4), "%s: the soft drop shadow (black 25%%, 1 px, offset 0,4)" % label)
	else:
		check(flat.shadow_size == 0, "%s: no shadow (got %d)" % [label, flat.shadow_size])
	check(flat.expand_margin_top == expand_top, "%s expand_margin_top %s (got %s)" % [label, expand_top, flat.expand_margin_top])
	check(flat.draw_center and flat.anti_aliasing, "%s: drawn filled, anti-aliased" % label)


## `UiTheme._button_boxes(variation, bg, hover, pressed_bg, margin_h, margin_v, font_color, font_size, outline)`.
func _flat_button(theme: Theme, type: StringName, bg: Color, hover: Color, pressed: Color, margin_h: float, margin_v: float,
		ink: Color, size: int, outline: int) -> void:
	_flat(theme, &"normal", type, bg, 12, 3, 7, [margin_h, margin_v, margin_h, margin_v], false)
	_flat(theme, &"hover", type, hover, 12, 3, 7, [margin_h, margin_v, margin_h, margin_v], false)
	for state: StringName in [&"pressed", &"hover_pressed"]:
		_flat(theme, state, type, pressed, 12, 3, 4, [margin_h, margin_v + 3.0, margin_h, margin_v], false, -3.0)
	check(theme.get_stylebox(&"focus", type) is StyleBoxEmpty, "%s/focus draws nothing" % type)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color"]:
		check(theme.get_color(slot, type).is_equal_approx(ink), "%s/%s is %s" % [type, slot, ink.to_html()])
	check(theme.get_color(&"font_outline_color", type).is_equal_approx(INK), "%s: an ink outline" % type)
	check(theme.get_font_size(&"font_size", type) == size, "%s: %d px (got %d)" % [type, size, theme.get_font_size(&"font_size", type)])
	check(theme.get_constant(&"outline_size", type) == outline, "%s: a %d px outline" % [type, outline])


## 🧱 The game's flat parts (`UiTheme._build()`), value for value: the white panel and card, the choice key, the big
##    green and grey keys, the small and bar labels.
func _flat_parts(theme: Theme) -> void:
	_flat(theme, &"panel", &"GoPanelFlat", PANEL, 14, 3, 3, [14.0, 8.0, 14.0, 8.0], true)
	_flat(theme, &"panel", &"GoCardFlat", Color.WHITE, 24, 4, 4, [36.0, 26.0, 36.0, 26.0], true)
	_flat_button(theme, &"GoBigButton", GREEN, Color("#55dc70"), Color("#34b84e"), 34.0, 6.0, Color.WHITE, 24, 3)
	_flat_button(theme, &"GoBigSecondaryButton", SECONDARY, Color("#9a9fc0"), Color("#7a7fa3"), 34.0, 6.0, Color.WHITE, 24, 3)
	# The choice key's normal and hover are `_button_boxes`'; its pressed face is the selected one (`.diff.selected`):
	# cyan, a 4 px bottom edge, 9 px over the word, and no step down.
	_flat(theme, &"normal", &"GoChoiceButton", DIFF_BG, 12, 3, 7, [14.0, 6.0, 14.0, 6.0], false)
	_flat(theme, &"hover", &"GoChoiceButton", Color("#f6f8ff"), 12, 3, 7, [14.0, 6.0, 14.0, 6.0], false)
	for state: StringName in [&"pressed", &"hover_pressed"]:
		_flat(theme, state, &"GoChoiceButton", DIFF_SELECTED, 12, 3, 4, [14.0, 9.0, 14.0, 6.0], false)
	check(theme.get_stylebox(&"focus", &"GoChoiceButton") is StyleBoxEmpty, "GoChoiceButton/focus draws nothing")
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color"]:
		check(theme.get_color(slot, &"GoChoiceButton").is_equal_approx(INK), "GoChoiceButton/%s is the ink" % slot)
	check(theme.get_font_size(&"font_size", &"GoChoiceButton") == 15 and theme.get_constant(&"outline_size", &"GoChoiceButton") == 0,
		"GoChoiceButton: 15 px, no outline")
	check(theme.get_font_size(&"font_size", &"GoSmallLabel") == 12
		and theme.get_color(&"font_color", &"GoSmallLabel").is_equal_approx(Color(INK, 0.75)), "GoSmallLabel: 12 px, ink at 75%")
	check(theme.get_font_size(&"font_size", &"GoBarLabel") == 11, "GoBarLabel: 11 px")
	# 🗺️ The map thumbnail's box (`MapPreview._init()`: UiTheme.box(Cfg.StagePreview.BACKGROUND, 6, 1, BORDER, false,
	#    0, 0)) — in the theme, so GoMapPreview reads it instead of building its own.
	var map_box := theme.get_stylebox(&"panel", &"GoMapPreview") as StyleBoxFlat if theme.has_stylebox(&"panel", &"GoMapPreview") else null
	check(map_box != null, "GoMapPreview/panel is a StyleBoxFlat")
	if map_box != null:
		check(map_box.bg_color.is_equal_approx(Color("#18213a")) and map_box.border_color.is_equal_approx(Color("#58627b"))
			and map_box.border_width_left == 1 and map_box.border_width_bottom == 1 and map_box.corner_radius_top_left == 6
			and map_box.corner_radius_bottom_right == 6 and _margins(map_box) == [0.0, 0.0, 0.0, 0.0]
			and map_box.shadow_size == 0 and map_box.anti_aliasing,
			"GoMapPreview/panel: the game's #18213a box, 6 px corners, a 1 px #58627b rim, no padding (got %s %s)"
			% [map_box.bg_color.to_html(), _margins(map_box)])
		var preview := GoMapPreview.new()
		preview.theme = theme
		root.add_child(preview)
		check(preview.background_box() == map_box, "GoMapPreview draws the theme's box")
		preview.free()


func _variations(theme: Theme) -> void:
	var bases := {
		&"GoButton": &"Button", &"GoPrimaryButton": &"Button", &"GoDangerButton": &"Button",
		&"GoSuccessButton": &"Button", &"GoToggleButton": &"Button", &"GoKeycap": &"Button", &"GoInfoButton": &"Button",
		&"GoWhiteButton": &"Button", &"GoBlackButton": &"Button",
		&"GoCard": &"PanelContainer", &"GoInsetPanel": &"PanelContainer", &"GoKeycapPanel": &"PanelContainer",
		&"GoRibbon": &"PanelContainer", &"GoRibbonRed": &"PanelContainer", &"GoNotice": &"PanelContainer",
		&"GoTitle": &"Label", &"GoOutlineLabel": &"Label", &"GoRibbonWideTitle": &"Label",
		&"GoWindowBlue": &"PanelContainer", &"GoRibbonWide": &"PanelContainer", &"GoWell": &"PanelContainer",
		&"GoLevelCard": &"Button", &"GoLevelCardCurrent": &"Button", &"GoLevelCardLocked": &"Button",
		&"GoHudPanel": &"PanelContainer", &"GoBannerGold": &"PanelContainer", &"GoNoticeGold": &"PanelContainer",
		&"GoChipDark": &"Button", &"GoIconOnly": &"Button",
		&"GoScoreRow": &"PanelContainer", &"GoScoreRowGold": &"PanelContainer", &"GoScoreHead": &"PanelContainer",
		&"GoTile": &"Panel", &"GoTileLit": &"Panel",
		&"GoPanelFlat": &"PanelContainer", &"GoCardFlat": &"PanelContainer", &"GoChoiceButton": &"Button",
		&"GoBigButton": &"Button", &"GoBigSecondaryButton": &"Button", &"GoSmallLabel": &"Label", &"GoBarLabel": &"Label",
		&"GoMapPreview": &"Panel",
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
	var moved := {"StageWindow": "GoWindowBlue", "StageRibbon": "GoRibbonWide", "StageCard": "GoLevelCard",
		"StageCardNext": "GoLevelCardCurrent", "StageCardLocked": "GoLevelCardLocked",
		"ArcadePanel": "GoHudPanel", "HudBanner": "GoBannerGold", "NotifPlayer": "GoNoticeGold", "LangChip": "GoChipDark",
		"PauseRound": "GoIconOnly",
		"ScoreRow": "GoScoreRow", "ScoreRowWin": "GoScoreRowGold", "ScoreHead": "GoScoreHead",
		"LoadTile": "GoTile", "LoadTileLit": "GoTileLit",
		"HudPanel": "GoPanelFlat", "Card": "GoCardFlat", "Diff": "GoChoiceButton", "Big": "GoBigButton",
		"BigSecondary": "GoBigSecondaryButton", "SmallLabel": "GoSmallLabel", "BarLabel": "GoBarLabel"}
	check(map.get("GlossGreen", "") == "GoPrimaryButton" and map.get("GlossBlue", "") == "GoInfoButton",
		"map: the game's green main action is the primary key, its blue pill the info key (got %s, %s)"
		% [map.get("GlossGreen", "nothing"), map.get("GlossBlue", "nothing")])
	for game: String in moved:
		check(map.get(game, "") == moved[game], "map: %s → %s (got %s)" % [game, moved[game], map.get(game, "nothing")])
	check(not map.has("MapWell"), "map: MapWell is no UiTheme variation, so it is not a map key")
	var code_built: Variant = map.get("_code_built", {})
	check(code_built is Dictionary and str((code_built as Dictionary).get("GoWell", "")).begins_with("MapPreview.set_well()")
		and theme.get_type_variation_base(&"GoWell") != &"", "map: GoWell is listed as code-built (MapPreview.set_well())")
	check(code_built is Dictionary and str((code_built as Dictionary).get("GoMapPreview", "")).begins_with("MapPreview._init()"),
		"map: GoMapPreview is listed as code-built (MapPreview._init())")
	# Every variation the game builds is in gohud now, the old flat look too: nothing stays game-only.
	check(map.get("game_only", []) is Array and (map["game_only"] as Array).is_empty(),
		"map: no variation stays in the game (got %s)" % str(map.get("game_only", [])))


func _inks(theme: Theme) -> void:
	check(theme.get_color(&"font_color", &"Label").is_equal_approx(INK), "Label: the ink")
	check(theme.get_color(&"font_outline_color", &"Label").is_equal_approx(INK), "Label: an ink outline when one is asked for")
	check(theme.get_constant(&"outline_size", &"Label") == 0, "Label: no outline of its own")
	check(theme.get_color(&"font_color", &"GoTitle") == Color.WHITE and theme.get_constant(&"outline_size", &"GoTitle") == 6
		and theme.get_constant(&"line_spacing", &"GoTitle") == -6, "GoTitle: white, a 6 px outline, lines drawn together")
	check(theme.get_color(&"font_color", &"GoOutlineLabel") == Color.WHITE and theme.get_constant(&"outline_size", &"GoOutlineLabel") == 6,
		"GoOutlineLabel: white with a 6 px outline")
	check(theme.get_color(&"font_color", &"GoRibbonWideTitle") == Color.WHITE
			and theme.get_constant(&"outline_size", &"GoRibbonWideTitle") == 8
			and theme.get_font_size(&"font_size", &"GoRibbonWideTitle") == theme.get_font_size(&"font_size", &"GoTitle"),
		"GoRibbonWideTitle: the title on a wide ribbon, with the stage ribbons' 8 px outline")
	# A field's hint is a grey that reads, never the typed text's ink; its shut text the engine's pale grey.
	for type_name: StringName in [&"LineEdit", &"TextEdit"]:
		check(theme.get_color(&"font_placeholder_color", type_name).is_equal_approx(Color(0.4, 0.42, 0.53)),
			"%s: a grey hint, not the ink" % type_name)
	check(theme.get_color(&"font_uneditable_color", &"LineEdit").is_equal_approx(Color(0.875, 0.875, 0.875, 0.5))
			and theme.get_color(&"font_readonly_color", &"TextEdit").is_equal_approx(Color(0.875, 0.875, 0.875, 0.5)),
		"a shut field's text: the engine's pale grey, as the game's")


func _tokens(theme: Theme) -> void:
	var want := {
		&"text": INK, &"border": INK, &"surface": Color.WHITE, &"surface_soft": DIFF_BG, &"surface_high": BAR_BG,
		&"track": BAR_BG, &"background": STAGE_SKY, &"scrim": OVERLAY, &"on_accent": Color.WHITE,
		&"accent_vivid": CONTROL_BLUE, &"success_vivid": GREEN, &"danger_vivid": RED, &"warning_vivid": GOLD,
		&"info_vivid": DIFF_SELECTED,
		# The role colours: HUD_NAME (gold titles), READY_RED (the clock's warning), SECONDARY (a muted lavender fill).
		&"heading": Color("#b8860b"), &"alert": Color("#e8332f"), &"muted_fill": SECONDARY,
	}
	for key: StringName in want:
		var got := theme.get_color(key, &"GoHud")
		check(got.is_equal_approx(want[key]) or got.to_html() == (want[key] as Color).to_html(),
			"token %s is the game's %s (got %s)" % [key, (want[key] as Color).to_html(), got.to_html()])
	# 👆 The look's touch floor is the game's Cfg.Touch.MIN_TARGET (44).
	check(theme.get_constant(GoTheme.TOUCH, GoTheme.TYPE) == 44,
		"token touch is the game's Cfg.Touch.MIN_TARGET 44 (got %d)" % theme.get_constant(GoTheme.TOUCH, GoTheme.TYPE))
	GoUi.config.follow_look_touch_size()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	# 🎨 The skin hooks that drew these colours read the tokens now, so they still return the game's.
	var skin := GoUi.skin()
	check(skin.task_title_ink().is_equal_approx(Color("#b8860b")) and skin.task_hint_ink().is_equal_approx(Color("#e8332f"))
		and skin.hud_alert_ink().is_equal_approx(Color("#e8332f")),
		"arcade_light: task_title_ink, task_hint_ink and hud_alert_ink are HUD_NAME and READY_RED (via heading / alert)")
	check(GoUi.color(GoTheme.MUTED_FILL).is_equal_approx(SECONDARY) and GoUi.color(GoTheme.HEADING).is_equal_approx(Color("#b8860b"))
		and GoUi.color(GoTheme.ALERT).is_equal_approx(Color("#e8332f")), "arcade_light: GoUi.color reads the three role tokens")
	check(GoUi.touch_size() == 44.0, "GoUi.touch_size() under arcade_light is 44 (got %s)" % GoUi.touch_size())
	GoUi.config.preset = &""


## 🔑 Each painted variation carries exactly the items the game's variation has (`UiTheme._build()`), no more: the
##    game builds its theme as a duplicate of this one plus aliases, so a stray item would change how it looks.
func _item_sets(theme: Theme) -> void:
	var gloss_colors := ["font_color", "font_disabled_color", "font_focus_color", "font_hover_color",
		"font_hover_pressed_color", "font_outline_color", "font_pressed_color"]
	var gloss := {"styles": ["disabled", "focus", "hover", "hover_pressed", "normal", "pressed"], "colors": gloss_colors,
		"constants": ["h_separation", "outline_size"], "font_sizes": ["font_size"]}
	var panel := {"styles": ["panel"], "colors": [], "constants": [], "font_sizes": []}
	var card := {"styles": ["disabled", "focus", "hover", "hover_pressed", "normal", "pressed"], "colors": [],
		"constants": [], "font_sizes": []}
	# `UiTheme._button_boxes()`: four faces and no focus ring, one label colour, its size and outline.
	var flat_button := {"styles": ["focus", "hover", "hover_pressed", "normal", "pressed"],
		"colors": ["font_color", "font_focus_color", "font_hover_color", "font_hover_pressed_color", "font_outline_color",
			"font_pressed_color"], "constants": ["outline_size"], "font_sizes": ["font_size"]}
	var want := {
		&"GoButton": gloss, &"GoPrimaryButton": gloss, &"GoDangerButton": gloss, &"GoSuccessButton": gloss,
		&"GoInfoButton": gloss, &"GoWhiteButton": gloss, &"GoBlackButton": gloss,
		&"GoToggleButton": gloss,
		&"GoKeycap": {"styles": ["focus", "hover", "hover_pressed", "normal", "pressed"],
			"colors": ["font_color", "font_focus_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color"],
			"constants": [], "font_sizes": ["font_size"]},
		&"GoCard": panel, &"GoInsetPanel": panel, &"GoKeycapPanel": panel, &"GoRibbon": panel, &"GoRibbonRed": panel,
		&"GoNotice": panel,
		&"GoTitle": {"styles": [], "colors": ["font_color"], "constants": ["line_spacing", "outline_size"],
			"font_sizes": ["font_size"]},
		&"GoOutlineLabel": {"styles": [], "colors": ["font_color"], "constants": ["outline_size"], "font_sizes": []},
		&"GoRibbonWideTitle": {"styles": [], "colors": ["font_color"], "constants": ["line_spacing", "outline_size"],
			"font_sizes": ["font_size"]},
		&"GoWindowBlue": panel, &"GoRibbonWide": panel, &"GoWell": panel, &"GoHudPanel": panel, &"GoBannerGold": panel,
		&"GoNoticeGold": panel, &"GoLevelCard": card, &"GoLevelCardCurrent": card, &"GoLevelCardLocked": card,
		&"GoChipDark": {"styles": ["focus", "hover", "hover_pressed", "normal", "pressed"],
			"colors": ["font_color", "font_focus_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color"],
			"constants": ["h_separation"], "font_sizes": ["font_size"]},
		&"GoIconOnly": {"styles": ["disabled", "focus", "hover", "hover_pressed", "normal", "pressed"],
			"colors": ["icon_hover_pressed_color", "icon_pressed_color"], "constants": [], "font_sizes": []},
		&"GoPanelFlat": panel, &"GoCardFlat": panel,
		&"GoScoreRow": panel, &"GoScoreRowGold": panel, &"GoScoreHead": panel, &"GoTile": panel, &"GoTileLit": panel,
		&"GoChoiceButton": flat_button, &"GoBigButton": flat_button, &"GoBigSecondaryButton": flat_button,
		&"GoSmallLabel": {"styles": [], "colors": ["font_color"], "constants": [], "font_sizes": ["font_size"]},
		&"GoBarLabel": {"styles": [], "colors": [], "constants": [], "font_sizes": ["font_size"]},
	}
	for type: StringName in want:
		var got := {"styles": _sorted(theme.get_stylebox_list(type)), "colors": _sorted(theme.get_color_list(type)),
			"constants": _sorted(theme.get_constant_list(type)), "font_sizes": _sorted(theme.get_font_size_list(type))}
		for kind: String in got:
			check(got[kind] == want[type][kind], "%s %s are the game's %s (got %s)" % [type, kind, str(want[type][kind]),
				str(got[kind])])
		check(theme.get_font_list(type).is_empty() and theme.get_icon_list(type).is_empty(),
			"%s: no font and no icon (the game adds its own fonts)" % type)


## The icon is a `GoTextureSprite` of [param file] drawn at [param size] canvas units, multiplied by [param tint].
## 🔑 The game's theme sets no base type but `Label`, `OptionButton` and `PopupMenu` — a plain `Button`, and every item a
##    Button variation leaves unset, is the engine's. A base item here would leak into the variations (an outline on
##    the chip's label, a 4 → 10 gap) and paint plain buttons the game draws flat, so arcade_light sets none either.
func _engine_bases(theme: Theme) -> void:
	# The game's theme sets none of these, and it draws them all: its tooltips (8 `tooltip_text`), the boxes and grids
	# that keep the engine's 4 px gap, and the scroll bars of the controls card and the room list.
	for type: StringName in [&"Button", &"TooltipPanel", &"TooltipLabel", &"BoxContainer", &"HBoxContainer",
			&"VBoxContainer", &"GridContainer", &"HFlowContainer", &"VFlowContainer", &"ScrollContainer"]:
		var items: Array[String] = []
		for kind: int in Theme.DATA_TYPE_MAX:
			for item: StringName in theme.get_theme_item_list(kind, type): items.append(str(item))
		check(items.is_empty(), "%s is left to the engine, as in the game (sets %s)" % [type, items])
	var engine := ThemeDB.get_default_theme()
	var chip := Button.new()
	chip.theme = theme
	chip.theme_type_variation = &"GoChipDark"
	check(chip.get_theme_color(&"font_outline_color") == engine.get_color(&"font_outline_color", &"Button")
		and chip.get_theme_constant(&"outline_size") == 0,
		"GoChipDark's outline falls through to the engine's (none), as the game's LangChip does")
	chip.free()
	check(not theme.has_constant(&"outline_size", &"Button"), "no base outline under the chip's label")


## Real scroll containers inherit painted bars even when the caller never supplies a variation or an override.
func _scoreboard(theme: Theme) -> void:
	var normal_font := theme.default_font as FontVariation
	for type: StringName in [&"GoScoreLabel", &"GoScoreHeadLabel", &"GoScoreTitleLabel", &"GoScoreOutlineLabel",
			&"GoScoreButton", &"GoScorePrimaryButton", &"GoScoreTab", &"GoScoreTabSelected", &"GoScoreGoldButton"]:
		var font := theme.get_font(&"font", type) as FontVariation
		check(font != null and font.variation_embolden >= 1.0 and font.base_font == normal_font,
			"%s: heavy lettering shares the multilingual body's locale order" % type)
		if font != null:
			for character: String in ["한", "日", "中"]:
				check(font.has_char(character.unicode_at(0)), "%s: the heavy face can display %s" % [type, character])
	check(normal_font.variation_embolden == 0.0, "the heavier scoreboard does not change ordinary UI font weight")
	check(theme.get_color(&"font_color", &"GoScoreGoldButton").b < 0.3
		and theme.get_color(&"font_outline_color", &"GoScoreGoldButton") == Color.WHITE,
		"the gold leaderboard menu action uses navy letters with a white outline")
	var skin := load("res://addons/gohud/themes/skins/gohud_skin_arcade_light.tres") as GoSkinArcadePainted
	for name: StringName in [&"medal_gold", &"medal_silver", &"medal_bronze"]:
		var art := skin.widget_art(name)
		check(art != null and art.get_width() > 0 and art.get_height() > art.get_width(),
			"%s: a numbered medal with room below for its ribbon tails" % name)
	for type: StringName in [&"GoScoreRow", &"GoScoreRowGold", &"GoScoreRowOwn", &"GoScorePanel", &"GoStagePanel"]:
		var face := theme.get_stylebox(&"panel", type) as GoStyleBoxArcade
		check(face != null and face.shine > 0.0 and face.bg_color != face.bottom_color,
			"%s: glossy gradient instead of a flat engine panel" % type)
		if face != null:
			check(face.bg_color.a == 1.0 and face.bottom_color.a == 1.0, "%s: opaque readable face" % type)
	var gold := theme.get_stylebox(&"panel", &"GoScoreRowGold") as GoStyleBoxArcade
	check(gold != null and gold.bottom_color.r > 0.95 and gold.bottom_color.b < 0.3,
		"first place has a gold fill as well as a gold rim")
	var ribbon := theme.get_stylebox(&"panel", &"GoScoreRibbon") as GoStyleBoxArcade
	check(ribbon != null and ribbon.radius == 36.0 and ribbon.shine > 0.9,
		"the scoreboard title is a rounded glossy gold capsule")
	check(ribbon != null and ribbon.bg_color.g > 0.9 and ribbon.bottom_color.g <= 0.5
		and ribbon.bottom_color.b < 0.05,
		"the rounded title keeps a distinct glossy gold-to-orange gradient")
	var own := theme.get_stylebox(&"panel", &"GoScoreRowOwn") as GoStyleBoxArcade
	check(own != null and own.border_color.is_equal_approx(CONTROL_BLUE) and own.border_width == 3.0,
		"the player's row has a stronger blue rim")
	var badge := theme.get_stylebox(&"panel", &"GoHardBadge")
	check(_is_sprite(badge) and badge.get_minimum_size().y <= 26.0,
		"the noninteractive red badge fits a compact 26dp status line")
	var arrow := theme.get_stylebox(&"normal", &"GoArrowButton") as GoStyleBoxArcade
	check(arrow != null and arrow.radius == 12.0 and arrow.get_minimum_size().x < 20.0,
		"the navigation key fits a compact square without wide pill padding")
	var gold_button := theme.get_stylebox(&"normal", &"GoGoldButton") as GoStyleBoxArcade
	check(gold_button != null and gold_button.bottom_color.r > 0.95 and gold_button.bottom_color.b < 0.1,
		"the gold menu action matches the gold award and title")
	for horizontal: bool in [false, true]:
		var scroll := ScrollContainer.new()
		scroll.theme = theme
		scroll.custom_minimum_size = Vector2(180, 100)
		var content := Control.new()
		content.custom_minimum_size = Vector2(800, 40) if horizontal else Vector2(40, 800)
		scroll.add_child(content)
		root.add_child(scroll)
		await process_frame
		await process_frame
		var bar := scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
		check(bar.visible, "the overflowing %s list has a visible scrollbar" % ("horizontal" if horizontal else "vertical"))
		for state: StringName in [&"scroll", &"scroll_focus", &"grabber", &"grabber_highlight", &"grabber_pressed"]:
			check(bar.get_theme_stylebox(state) is GoStyleBoxArcade,
				"%s/%s inherits arcade chrome with no engine fallback" % [bar.get_class(), state])
		for state: StringName in [&"increment", &"decrement", &"increment_highlight", &"decrement_highlight",
				&"increment_pressed", &"decrement_pressed"]:
			check(bar.get_theme_icon(state) != null and bar.get_theme_icon(state).get_width() == 18,
				"%s/%s has a compact painted arrow cap" % [bar.get_class(), state])
		check(bar.get_combined_minimum_size().y >= 18.0 if horizontal else bar.get_combined_minimum_size().x >= 18.0,
			"the blue scrollbar has a visible 18dp thickness")
		scroll.queue_free()
		await process_frame


func _icon(theme: Theme, name: StringName, type: StringName, file: String, size: Vector2, tint: Color) -> void:
	var label := "%s/icons/%s" % [type, name]
	var icon := theme.get_icon(name, type) if theme.has_icon(name, type) else null
	var ok := icon != null and icon.get_script() != null and (icon.get_script() as Script).get_global_name() == &"GoTextureSprite"
	check(ok, "%s is a GoTextureSprite (got %s)" % [label, icon])
	if not ok: return
	var art := icon.get(&"texture") as Texture2D
	check(art != null and art.resource_path == PAINTED + file, "%s draws %s (got %s)" % [label, file,
		art.resource_path if art else "nothing"])
	check(icon.get_size() == size, "%s is %s units, the game's size (got %s)" % [label, size, icon.get_size()])
	check((icon.get(&"tint") as Color).is_equal_approx(tint), "%s tint %s (got %s)" % [label, tint, icon.get(&"tint")])


## 🎚 `PaintedSlider`: the pill track 16 units tall, the fill in its colour, the 36-unit round handle.
func _slider(theme: Theme) -> void:
	_sprite(theme, &"slider", &"HSlider", "slider_track.png", BAR_EDGE, 5.0, Color.WHITE, [0.0, 8.0, 0.0, 8.0])
	check(theme.get_stylebox(&"slider", &"HSlider").get_minimum_size().y == 16.0,
		"HSlider: the bar is 16 units tall (BAR_HEIGHT; the engine draws track and fill at its minimum height)")
	for pair: Array in [[&"HSlider", "slider_blue.png"], [&"GoSliderGreen", "slider_green.png"],
			[&"GoSliderCyan", "slider_cyan.png"]]:
		for state: StringName in [&"grabber_area", &"grabber_area_highlight"]:
			_sprite(theme, state, pair[0], pair[1], BAR_EDGE, 5.0, Color.WHITE, [0.0, 0.0, 0.0, 0.0])
		if pair[0] != &"HSlider":
			check(theme.get_type_variation_base(pair[0]) == &"HSlider", "%s is a variation of HSlider" % pair[0])
			check(theme.get_stylebox_list(pair[0]).size() == 2 and theme.get_icon_list(pair[0]).is_empty(),
				"%s sets only its fill; the track and the handle are HSlider's" % pair[0])
	_icon(theme, &"grabber", &"HSlider", "slider_handle.png", HANDLE_SIZE, Color.WHITE)
	_icon(theme, &"grabber_highlight", &"HSlider", "slider_handle.png", HANDLE_SIZE, Color.WHITE)
	_icon(theme, &"grabber_disabled", &"HSlider", "slider_handle.png", HANDLE_SIZE, DISABLED_TINT)
	# A stock HSlider in this theme: as tall as the handle, and the touch floor through GoStyle.slider (GoConfig's
	# min_touch_size is the game's Cfg.Touch.MIN_TARGET).
	var slider := HSlider.new()
	slider.theme = theme
	root.add_child(slider)
	await process_frame
	slider.update_minimum_size()
	check(slider.get_combined_minimum_size().y == HANDLE_SIZE.y, "HSlider: as tall as the handle (got %s)"
		% slider.get_combined_minimum_size())
	slider.free()
	var styled := GoStyle.slider()
	check(styled.custom_minimum_size.y == GoUi.touch_size(),
		"GoStyle.slider: the touch floor is the touch token (got %s)" % styled.custom_minimum_size.y)
	styled.free()


## GoRangeSlider wears the same parts, and a variation's fill when it is given one.
func _range_slider(theme: Theme) -> void:
	var range_slider := GoRangeSlider.make(0.0, 100.0, 20.0, 80.0)
	root.add_child(range_slider)
	await process_frame
	range_slider.theme = theme
	var grab := range_slider._grabber()
	check(grab != null and grab.get_size() == HANDLE_SIZE, "GoRangeSlider: the painted 36-unit handle (got %s)"
		% (grab.get_size() if grab else "none"))
	check(range_slider.get_combined_minimum_size().y >= HANDLE_SIZE.y, "GoRangeSlider: room for the handle")
	range_slider.theme_type_variation = &"GoSliderGreen"
	var fill := range_slider._box(&"grabber_area")
	var art: Variant = fill.get(&"texture") if fill != null else null
	check(art is Texture2D and (art as Texture2D).resource_path == PAINTED + "slider_green.png",
		"GoRangeSlider: theme_type_variation GoSliderGreen paints the green fill")
	check(range_slider._grabber() != null and range_slider._grabber().get_size() == HANDLE_SIZE,
		"GoRangeSlider: a fill variation keeps HSlider's handle")
	var track := range_slider._box(&"slider")
	check(track != null and track.get(&"texture") is Texture2D
		and (track.get(&"texture") as Texture2D).resource_path == PAINTED + "slider_track.png",
		"GoRangeSlider: a fill variation keeps HSlider's track")
	# On a preset with no slider variations, any variation — a fill named for arcade_light, or one that is no
	# slider at all — still draws HSlider's track, fill and handle (a Control never falls back to HSlider by itself).
	var plain := load("res://addons/gohud/themes/gohud_dark.tres") as Theme
	range_slider.theme = plain
	for variation: StringName in [&"GoSliderGreen", &"GoCard"]:
		range_slider.theme_type_variation = variation
		for item: StringName in [&"slider", &"grabber_area", &"grabber_area_highlight"]:
			check(range_slider._box(item) == plain.get_stylebox(item, &"HSlider"),
				"GoRangeSlider on gohud_dark with %s: HSlider's %s (got %s)" % [variation, item, range_slider._box(item)])
		for item: StringName in [&"grabber", &"grabber_highlight"]:
			check(range_slider._grabber(item) == plain.get_icon(item, &"HSlider"),
				"GoRangeSlider on gohud_dark with %s: HSlider's %s icon" % [variation, item])
	range_slider.free()


## 🔘 `PaintedSwitch`: the green pill (knob right) on, the grey one (knob left) off, 76 × 29 units in every direction;
##    the disabled ones fade.
func _switch(theme: Theme) -> void:
	for suffix: String in ["", "_mirrored"]:
		_icon(theme, StringName("checked" + suffix), &"CheckButton", "toggle_on.png", SWITCH_SIZE, Color.WHITE)
		_icon(theme, StringName("unchecked" + suffix), &"CheckButton", "toggle_off.png", SWITCH_SIZE, Color.WHITE)
		_icon(theme, StringName("checked_disabled" + suffix), &"CheckButton", "toggle_on.png", SWITCH_SIZE, DISABLED_TINT)
		_icon(theme, StringName("unchecked_disabled" + suffix), &"CheckButton", "toggle_off.png", SWITCH_SIZE,
			DISABLED_TINT)
	check(theme.get_stylebox(&"focus", &"CheckButton") is StyleBoxEmpty,
		"CheckButton/focus: empty, the game's switch draws no focus ring (got %s)" % theme.get_stylebox(&"focus", &"CheckButton"))
	# The label beside the switch is ink in every state, as the game's labels are: the switch itself says on or off,
	# so the words must not turn blue with it (Button's pressed colours would leak through without these).
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color"]:
		check(theme.get_color(state, &"CheckButton").is_equal_approx(INK),
			"CheckButton/%s: ink, on or off (got %s)" % [state, theme.get_color(state, &"CheckButton")])
	# The sprites keep their own colours (the game's engine default, white), on and off.
	for state: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color",
			&"icon_focus_color"]:
		check(theme.get_color(state, &"CheckButton").is_equal_approx(Color.WHITE),
			"CheckButton/%s: white, the painted pill untinted (got %s)" % [state, theme.get_color(state, &"CheckButton")])
	check(theme.get_constant(&"h_separation", &"CheckButton") == 4,
		"CheckButton/h_separation: the game's 4 between label and switch (got %d)" % theme.get_constant(&"h_separation", &"CheckButton"))
	var switch := CheckButton.new()
	switch.theme = theme
	root.add_child(switch)
	check(switch.get_combined_minimum_size().x >= SWITCH_SIZE.x and switch.get_combined_minimum_size().y >= SWITCH_SIZE.y,
		"CheckButton: room for the 76 × 29 switch (got %s)" % switch.get_combined_minimum_size())
	switch.free()


## ✏ The game's field: a white box with a 2 px SECONDARY rim, a 3 px CONTROL_BLUE ring while typing, DIFF_BG read-only.
##    TextEdit wears the same boxes (the game has no multi-line field).
func _field(theme: Theme) -> void:
	var want := {&"normal": [Color.WHITE, 2, SECONDARY], &"focus": [Color(0, 0, 0, 0), 3, CONTROL_BLUE],
		&"read_only": [DIFF_BG, 2, SECONDARY]}
	for type: StringName in [&"LineEdit", &"TextEdit"]:
		for state: StringName in want:
			var box := theme.get_stylebox(state, type) as StyleBoxFlat
			check(box != null, "%s/%s is a StyleBoxFlat" % [type, state])
			if box == null: continue
			check(box.bg_color.is_equal_approx(want[state][0]) and box.border_width_left == want[state][1]
				and box.border_width_bottom == want[state][1] and box.border_color.is_equal_approx(want[state][2])
				and box.corner_radius_top_left == 10 and box.corner_radius_bottom_right == 10,
				"%s/%s: the game's UiTheme.box(%s, 10, %d, …)" % [type, state, (want[state][0] as Color).to_html(),
				want[state][1]])
			check(_margins(box) == [14.0, 8.0, 14.0, 8.0], "%s/%s: box()'s 14 / 8 padding (got %s)" % [type, state,
				_margins(box)])
			if type == &"TextEdit":
				check(box == theme.get_stylebox(state, &"LineEdit"), "TextEdit/%s: the very box LineEdit wears" % state)
		check(theme.get_color(&"font_color", type).is_equal_approx(INK)
			and theme.get_color(&"caret_color", type).is_equal_approx(INK), "%s: ink text and caret" % type)


## 🔤 The game's font (`UiTheme.get_font()`): a FontVariation of Nunito Bold with the four Noto Sans CJK Bold fonts as
##    fallbacks, Korean, Japanese, Simplified then Traditional Chinese (`fallback_order("")`), at 16 px.
func _font(theme: Theme) -> void:
	const FONTS := "res://addons/gohud/assets/fonts/"
	check(theme.has_default_font() and theme.default_font is FontVariation,
		"arcade_light: the default font is the game's FontVariation (got %s)" % theme.default_font)
	check(theme.default_font_size == 16, "arcade_light: the game's 16 px default size (got %d)" % theme.default_font_size)
	if not (theme.default_font is FontVariation): return
	var font := theme.default_font as FontVariation
	check(font.base_font is FontFile and font.base_font.resource_path == FONTS + "nunito/Nunito-Bold.ttf",
		"the base font is Nunito Bold (got %s)" % (font.base_font.resource_path if font.base_font else "none"))
	var want := ["NotoSansKR-Bold.ttf", "NotoSansJP-Bold.ttf", "NotoSansSC-Bold.ttf", "NotoSansTC-Bold.ttf"]
	var got: Array = []
	for f: Font in font.fallbacks: got.append(f.resource_path.get_file() if f is FontFile else str(f))
	check(got == want, "the fallbacks are the game's Noto Sans CJK, KR JP SC TC (got %s)" % [got])
	for f: Font in font.fallbacks:
		check(f.resource_path.begins_with(FONTS + "noto_sans_cjk/"), "%s ships in assets/fonts/noto_sans_cjk" % f.resource_path)
	# 🔑 Every glyph the game draws: Latin from Nunito, Hangul, kana and Han from the fallbacks.
	for text: String in ["Magnet Mayhem", "한국어", "日本語", "简体中文", "繁體中文"]:
		check(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 0.0 and _covered(font, text),
			"the font draws %s" % text)
	check(theme.get_meta(&"go_body_font_baked", null) == font, "the baked font is named (go_body_font_baked)")
	# Through GoUi the project's own font wins, as with every preset's body font.
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	check(GoUi.theme().default_font == (null if GoUi.project_has_font() else font),
		"GoUi.theme(): the game's font only while the project chose none (project font: %s)" % GoUi.project_has_font())
	# 🔤 Shrink-to-fit with no font measures with that font, CJK fallbacks and all — the game's fit_font_size()
	#    measures with them, so a plain Nunito here would fit Korean, Japanese and Chinese labels differently.
	if not GoUi.project_has_font():
		var cjk := PackedStringArray(["설정 저장하기", "設定を保存", "保存设置"])
		var measured := GoStyle.row_width(null, cjk, 22)
		check(measured > 0.0 and is_equal_approx(measured, GoStyle.row_width(font, cjk, 22)),
			"GoStyle.fit_font_size() under arcade_light measures CJK with the game's font and its fallbacks (%s)" % measured)
		check(GoStyle._fit_font() is FontVariation and (GoStyle._fit_font() as FontVariation).fallbacks.size() == 4,
			"GoStyle's fit font under arcade_light keeps the four CJK fallbacks (got %s)" % GoStyle._fit_font())
	GoUi.config.preset = &""
	for path: String in [FONTS + "nunito/OFL.txt", FONTS + "noto_sans_cjk/OFL.txt"]:
		check(FileAccess.file_exists(path), "%s ships with the font files" % path)


## 🔤 The game's `UiTheme.set_locale_font()`: the current language's CJK font leads the fallbacks (`fallback_order`),
##    the others after it in the written order; a language with none keeps KR JP SC TC. Reassigned only on a change.
func _locale_lead() -> void:
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	var look := GoUi.theme()
	var font := look.get_meta(&"go_body_font_baked") as FontVariation
	var fonts: Variant = look.get_meta(GoUi.LOCALE_FONTS_META, null)
	check(fonts is Dictionary and (fonts as Dictionary).size() == 4, "arcade_light names a font per CJK language (got %s)" % [fonts])
	if font == null or not (fonts is Dictionary): return
	var files := {"ko": "KR", "ja": "JP", "zh_CN": "SC", "zh_TW": "TC"}
	for code: String in files:
		var named: Font = (fonts as Dictionary).get(code)
		check(named != null and named.resource_path.ends_with("NotoSans%s-Bold.ttf" % files[code]),
			"go_locale_fonts: %s is Noto Sans %s" % [code, files[code]])
	var changes := [0]
	var count := func() -> void: changes[0] += 1
	font.changed.connect(count)
	var want := {
		"ko": ["KR", "JP", "SC", "TC"], "ja": ["JP", "KR", "SC", "TC"], "zh_CN": ["SC", "KR", "JP", "TC"],
		"zh_TW": ["TC", "KR", "JP", "SC"], "en": ["KR", "JP", "SC", "TC"], "ko_KR": ["KR", "JP", "SC", "TC"],
		"ja_JP": ["JP", "KR", "SC", "TC"], "zh": ["SC", "KR", "JP", "TC"], "zh_HK": ["TC", "KR", "JP", "SC"],
		"zh_Hant": ["TC", "KR", "JP", "SC"], "zh_Hans_HK": ["SC", "KR", "JP", "TC"], "fr": ["KR", "JP", "SC", "TC"],
	}
	for code: String in want:
		GoUi.set_font_locale(code)
		var got: Array = []
		for f: Font in font.fallbacks: got.append(f.resource_path.get_file().trim_prefix("NotoSans").trim_suffix("-Bold.ttf"))
		check(got == want[code], "set_font_locale(%s): fallbacks %s (got %s)" % [code, want[code], got])
	# Only a real change reassigns (every reassignment re-shapes all the text on screen).
	GoUi.set_font_locale("ja")
	changes[0] = 0
	check(not GoUi.set_font_locale("ja") and not GoUi.set_font_locale("ja_JP") and changes[0] == 0,
		"set_font_locale: the same order again changes nothing (changed %d times)" % changes[0])
	check(GoUi.set_font_locale("ko") and changes[0] >= 1, "set_font_locale: a new order is assigned and says so")
	changes[0] = 0
	check(not GoUi.set_font_locale("en") and changes[0] == 0, "set_font_locale: en keeps the written order Korean already has")
	font.changed.disconnect(count)
	# set_locale: the font order, then the translation locale; the symbol font follows the lead.
	GoUi.set_locale("zh_TW")
	check(TranslationServer.get_locale() == "zh_TW" and font.fallbacks[0].resource_path.ends_with("NotoSansTC-Bold.ttf"),
		"set_locale(zh_TW): the locale and Traditional Chinese first")
	check(GoUi.skin().symbol_font() == font.fallbacks[0], "arcade_light's symbol font is the leading CJK font")
	# A look chosen later follows the language already set.
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	check(not GoUi.set_font_locale("ja"), "a look without go_locale_fonts has no lead to change")
	TranslationServer.set_locale("ja")
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	check(font.fallbacks[0].resource_path.ends_with("NotoSansJP-Bold.ttf"), "use_preset: arcade_light picks up the current locale (ja)")
	# The GoRuntime autoload follows a bare TranslationServer.set_locale() (the notification every node hears).
	var runtime: Node = load("res://addons/gohud/core/go_runtime.gd").new()
	TranslationServer.set_locale("zh_CN")
	runtime.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	check(font.fallbacks[0].resource_path.ends_with("NotoSansSC-Bold.ttf"),
		"GoRuntime: a bare set_locale(zh_CN) puts Simplified Chinese first")
	runtime.free()
	GoUi.set_locale("en")
	check(TranslationServer.get_locale() == "en" and font.fallbacks[0].resource_path.ends_with("NotoSansKR-Bold.ttf"),
		"set_locale(en): back to KR JP SC TC")
	GoUi.config.preset = &""


func _covered(font: Font, text: String) -> bool:
	for i in text.length():
		var found := font.has_char(text.unicode_at(i))
		for f: Font in font.fallbacks: found = found or f.has_char(text.unicode_at(i))
		if not found: return false
	return true


## 🧹 Every `[ext_resource]` the file declares is pointed at: the painted parts replace arcade drawings (the switch's
##    SVGs), and a drawing nothing uses must not load.
func _no_orphans() -> void:
	var text := FileAccess.get_file_as_string(LIGHT)
	var ids := RegEx.create_from_string('\\[ext_resource [^\\n]* id="([^"]+)"\\]')
	var orphans: Array[String] = []
	for found: RegExMatch in ids.search_all(text):
		if text.find('ExtResource("%s")' % found.get_string(1)) < 0: orphans.append(found.get_string(1))
	check(not ids.search_all(text).is_empty() and orphans.is_empty(), "arcade_light: no ext_resource nothing points at (%s)" % [orphans])


func _sorted(names: PackedStringArray) -> Array:
	var out: Array = Array(names)
	out.sort()
	return out


## 🌙 arcade_dark keeps its code-drawn keys and boards.
func _dark_stays(theme: Theme) -> void:
	for type: StringName in [&"GoScoreRow", &"GoScoreRowGold", &"GoScoreHead", &"GoTile", &"GoTileLit"]:
		check(theme.get_type_variation_base(type) == &"", "arcade_dark: %s is painted-only, it stays out" % type)
	for spot: Array in [[&"normal", &"Button"], [&"normal", &"GoPrimaryButton"], [&"panel", &"GoCard"]]:
		var box := theme.get_stylebox(spot[0], spot[1])
		check(box is GoStyleBoxArcade, "arcade_dark: %s/%s is still a GoStyleBoxArcade" % [spot[1], spot[0]])
		check(not _is_sprite(box), "arcade_dark: %s/%s is not painted art" % [spot[1], spot[0]])
	check(not theme.has_type_variation_list_entry(&"GoSuccessButton") if theme.has_method(&"has_type_variation_list_entry") else
		theme.get_type_variation_base(&"GoSuccessButton") == &"", "arcade_dark: the painted-only variations stay out")
