## Painted arcade skin — the arcade cabinet in hand-painted sprites, the look of Magnet Mayhem's menus. Where the game
## has a painted part, the part is that sprite drawn as a 9-slice (`GoStyleBoxSprite`): a card is the white card with
## its blue halo, a window's title sits on the gold ribbon in white letters with an ink outline, a key hint (`GoKbd`) is
## the painted keycap, a badge is the round green or blue badge. A notice is the game's notification pill (white, a blue
## rim, a deeper bottom edge), a bar is cut into six chunks by 3 px ink lines and a window's scrim is the game's frosted
## glass — the paused match blurred and washed faintly blue.
##
## Everything the game has no painted art for (chips, slots, the FAB, date cells, the joystick, a bar's fill, an
## outlined button) stays `GoSkinArcade`'s code-drawn key, in the theme's colours — so the painted palette paints them.
##
## 🎨 The values are the game's own (`src/ui/ui_theme.gd`: `PaintedCard`, `RibbonTitle`, `KeycapPanel`, `Notif`,
##    `NotifPlayer`, `ArcadePanel`, `INK`; `src/ui/ribbon_header.gd` for the title's outline; `src/ui/blur_backdrop.gd` for the
##    shader; `src/ui/bar_segments.gd` for the ticks). A value that drifts from the game is a bug, not a taste.
## 🛑 The sprites are made at 3× (5.5× the keycap) and drawn at 1 / `pixels_per_unit` of their size: an edge here is in
##    texture pixels, never dp. The art lives in `assets/arcade_light/painted/`.
@tool
class_name GoSkinArcadePainted
extends GoSkinArcade

## Where the painted sprites live.
const PAINTED := "res://addons/gohud/assets/arcade_light/painted/"
## The game's blur shader, copied (`src/ui/blur_backdrop.gd` `SHADER`).
const BLUR_SHADER_PATH := "res://addons/gohud/themes/skins/arcade_painted_blur.gdshader"

## The game's ink, white and paints (`UiTheme` `INK`, `PANEL`, `GOLD`, `GREEN`, `CONTROL_BLUE`).
const INK := Color("#1d2340")
const PANEL := Color(1.0, 1.0, 1.0, 0.9)
const GOLD := Color("#ffc928")
## The slate of the HUD's key-hint caps (`HUD.pause_hint`).
const KEY_HINT_FILL := Color("#6c7aa8")
const GREEN := Color("#3ecf5a")
const CONTROL_BLUE := Color("#3d6bff")
## The player's own notification is a gold rim on this cream (`UiTheme` `NotifPlayer`).
const NOTIF_OWN := Color("#fff3cf")

## The painted card (`UiTheme` `PaintedCard`): its edge, scale and the clear room inside it (dp: sides, top, bottom).
const CARD_EDGE := Vector4(100.0, 100.0, 100.0, 140.0)
const PAINT_PPU := 3.0
const CARD_PAD := Vector3(24.0, 20.0, 22.0)
## The colour the card shows under its text — the centre pixel of `card.png` (243, 248, 253), the generator's
## `FACES["card.png"]`. A board's `face_color` is this times its tint, alpha included, as the generator writes it.
const CARD_FACE := Color(0.952941, 0.972549, 0.992157, 1.0)
## The gold ribbon (`UiTheme` `RibbonTitle`).
const RIBBON_EDGE := Vector4(100.0, 80.0, 100.0, 80.0)
const RIBBON_PPU := 3.4
const RIBBON_PAD := Vector3(22.0, 6.0, 12.0)
## The colour the ribbon shows under the title — the centre pixel of `ribbon_gold.png` (#febc24), the generator's
## `FACES["ribbon_gold.png"]`. 🛑 Not `GOLD` (#ffc928): that is the paint's name, not what the art shows.
const RIBBON_FACE := Color(0.996078, 0.737255, 0.141176, 1.0)
## The keycap (`UiTheme.keycap_box()` / `KeycapPanel`).
const KEYCAP_EDGE := Vector4(70.0, 70.0, 70.0, 80.0)
const KEYCAP_PPU := 5.5
const KEYCAP_PAD := Vector3(9.0, 1.0, 5.0)
## The colour the keycap shows under its word — the centre pixel of `keycap.png` (#eff0f8), the generator's
## `FACES["keycap.png"]`, not plain white.
const KEYCAP_FACE := Color(0.937255, 0.941176, 0.972549, 1.0)
## The round badges (240 px; the game draws them whole, as the 3-2-1 / GO! discs): a 40 px strip is left in the middle
## so a wide count stretches the plate into a pill instead of tearing the disc.
const BADGE_EDGE := Vector4(100.0, 100.0, 100.0, 100.0)
## 🔑 The colour each badge shows under its count — sampled at the middle of the PNG, like the generator's `FACES`
##    (`tools/theme_arcade_painted.py`). `face_color` is never drawn; it is what the count's ink is measured against.
## 🛑 Not `CONTROL_BLUE` / `GREEN`: those are the paints' names, and the blue disc is darker under its count
##    (#1c63f8, 4.6:1 for white) than `CONTROL_BLUE` (4.43:1) — the badge check read the wrong face (2026-10-13).
const BADGE_BLUE_FACE := Color("#1c63f8")
const BADGE_GREEN_FACE := Color("#21d270")
## How far an accent tints the white card (the arcade skin paints a frame in it; a sprite has no frame to paint).
const CARD_ACCENT_TINT := 0.18
## The notification pill (`UiTheme` `Notif`: `chunky_box(PANEL, 16, 12, 2, 3, 5, CONTROL_BLUE, true)`).
const NOTIF_RADIUS := 16
const NOTIF_OUTLINE := 3
const NOTIF_BOTTOM := 5
const NOTIF_PAD := Vector2(12.0, 2.0)
## The HUD panel (`UiTheme.arcade_panel_box(Cfg.Hud.PANEL_PADDING)`: `chunky_box(PANEL, 18, pad + 5, pad, 5, 8,
## CONTROL_BLUE, true)`), at the desktop padding (8; the game's touch screens use 4).
const HUD_RADIUS := 18
const HUD_OUTLINE := 5
const HUD_BOTTOM := 8
const HUD_PAD := 8.0
## The ribbon title's outline (`RibbonHeader` sets `outline_size` 5 over the `Title` label's 6).
const RIBBON_TITLE_OUTLINE := 5
## The game's backdrop at full strength: `arcade_scrim_blur` 3 is the game's blur — the mip level read, and the taps
## spread twice as far (`BlurBackdrop` `blur_lod` 3.0, `spread` 6.0); the wash is its own.
const SCRIM_SPREAD_PER_LOD := 2.0
const SCRIM_WASH := Color(0.12, 0.28, 0.6, 0.22)
## The bar's chunk lines (`BarSegments`: 3 px INK).
const TICK_WIDTH := 3.0
## The HUD bar's groove (`UiTheme.BAR_BG`), its corner and its rim.
const BAR_BG := Color("#d9deef")
const BAR_RADIUS := 9
const BAR_OUTLINE := 3
## The HUD's alert red (`UiTheme.READY_RED`, the look's `alert` token too) and the repulse gauge's board
## (`HUD._repulse_box`).
const READY_RED := Color("#e8332f")
const GAUGE_RADIUS := 14
const GAUGE_OUTLINE := 3
const GAUGE_PAD := Vector2(14.0, 8.0)

static var _textures := {}
static var _world_tour_pictures := {}
static var _world_tour_stage9_detail: AtlasTexture
static var _symbol_font: Font
static var _painted_blur: Shader = null


## A painted 9-slice: [param file] from `PAINTED`, [param edge] in texture px (x left, y top, z right, w bottom), drawn
## at 1 / [param ppu] and multiplied by [param tint]. The caller sets the padding and the `face_color`.
func _sprite(file: String, edge: Vector4, ppu: float, tint := Color.WHITE) -> GoStyleBoxSprite:
	if not _textures.has(file): _textures[file] = load(PAINTED + file)
	var face := GoStyleBoxSprite.new()
	face.texture = _textures[file]
	face.edge = edge
	face.pixels_per_unit = ppu
	face.tint = tint
	return face


## The padding as the game writes it: [param pad] x the sides, y the top, z the bottom.
static func _pad(face: StyleBox, pad: Vector3) -> StyleBox:
	face.content_margin_left = pad.x
	face.content_margin_right = pad.x
	face.content_margin_top = pad.y
	face.content_margin_bottom = pad.z
	return face


# ── Boards ────────────────────────────────────────────────────────────

## Every board is the painted card. An accent tints it faintly (there is no frame to paint); the opacity goes on the
## tint's alpha — the one place it is applied, as `GoSkin.surface_box` asks.
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	if not GoTheme.ALPHA_TOKENS.has(variant): return super(variant, accent, alpha)
	var tint := Color.WHITE
	if accent.a > 0.0: tint = tint.lerp(Color(accent, 1.0), CARD_ACCENT_TINT)
	tint.a = clampf(alpha if alpha >= 0.0 else GoUi.surface_alpha(variant), 0.0, 1.0)
	var face := _sprite("card.png", CARD_EDGE, PAINT_PPU, tint)
	face.face_color = CARD_FACE * tint
	return _pad(face, CARD_PAD)


## A floating board is the same card — its painted halo is the shadow. A HUD board floating over the game is the
## game's HUD panel instead (`hud_panel_box`), as `GoStyle.floating()` draws a status panel.
## 🎮 Intended: under arcade_light **every** `floating_box(BOX_HUD)` — `GoPromptCard`, every `GoStyle.hud_panel()` /
##    `GoStyle.floating()` user, not only the gallery panel — is the game's `ArcadePanel`, not the painted card.
## 🛑 `GoStyle.floating()` takes only a `StyleBoxFlat`: the card sprite here fell back to the plain flat white
##    rectangle in the gallery's HP / MP / XP panel (2026-10-14).
func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBox:
	if variant == GoTheme.BOX_HUD: return hud_panel_box(accent, alpha)
	return surface_box(variant, accent, alpha)


## The game's HUD panel (`UiTheme` `ArcadePanel`, the theme's `GoHudPanel`): white at 90 %, a 5 px blue rim with an
## 8 px bottom edge, a thin ink line round it, `HUD_PAD` clear inside the border. An accent paints the rim; the
## opacity multiplies the white's own 0.9 (`fade_box`): [param alpha] when given, else what the project's `GoConfig`
## chose (`_config_alpha`).
func hud_panel_box(accent := Color.TRANSPARENT, alpha := -1.0) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = PANEL
	face.set_corner_radius_all(HUD_RADIUS)
	face.set_border_width_all(HUD_OUTLINE)
	face.border_width_bottom = HUD_BOTTOM
	face.border_color = CONTROL_BLUE if accent.a <= 0.0 else Color(accent, 1.0)
	face.anti_aliasing = true
	face.shadow_color = INK
	face.shadow_size = 3
	face.shadow_offset = Vector2(0.0, 2.0)
	face.content_margin_left = HUD_PAD + HUD_OUTLINE
	face.content_margin_right = HUD_PAD + HUD_OUTLINE
	face.content_margin_top = HUD_PAD + HUD_OUTLINE
	face.content_margin_bottom = HUD_PAD + HUD_BOTTOM
	return fade_box(face, alpha if alpha >= 0.0 else _config_alpha(GoTheme.BOX_HUD)) as StyleBoxFlat


## The opacity the project's `GoConfig` chose for [param variant] — `container_alpha_overrides`, a `metric_overrides`
## alpha token or `container_alpha`, in `GoUi.surface_alpha`'s order — or -1 when it chose none.
## 🛑 Not the theme's `<variant>_alpha`: the game's HUD panel and notification pill carry their own white at 0.9,
##    and the theme constant (`hud_alpha` 94) would thin that a second time.
static func _config_alpha(variant: StringName) -> float:
	var settings := GoUi.config
	if settings == null: return -1.0
	if settings.container_alpha_overrides.get(variant, -1.0) >= 0.0 \
			or settings.metric_overrides.has(GoTheme.alpha_token(variant)) or settings.container_alpha >= 0.0:
		return GoUi.surface_alpha(variant)
	return -1.0


## A notice is the game's notification pill: white, a blue rim and a deeper bottom edge, a thin ink line round it. An
## accent paints the rim; gold (the player's own news) also lays it on cream, as the game's `NotifPlayer` does. The pill
## is already compact, so `compact` changes nothing.
func notice_box(accent: Color, _compact: bool, alpha := -1.0) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = PANEL
	face.set_corner_radius_all(NOTIF_RADIUS)
	face.set_border_width_all(NOTIF_OUTLINE)
	face.border_width_bottom = NOTIF_BOTTOM
	face.border_color = CONTROL_BLUE
	face.anti_aliasing = true
	face.shadow_color = INK
	face.shadow_size = 3
	face.shadow_offset = Vector2(0.0, 2.0)
	face.content_margin_left = NOTIF_PAD.x
	face.content_margin_right = NOTIF_PAD.x
	face.content_margin_top = NOTIF_PAD.y + NOTIF_OUTLINE
	face.content_margin_bottom = NOTIF_PAD.y + NOTIF_BOTTOM
	tint_notice(face, accent)
	return fade_box(face, alpha if alpha >= 0.0 else _config_alpha(GoTheme.BOX_NOTICE))


## The accent paints the rim (gold lays it on cream); no accent leaves the pill as it is.
func tint_notice(box: StyleBox, accent: Color) -> void:
	var face := box as StyleBoxFlat
	if face == null:
		super(box, accent)
		return
	if accent.a <= 0.0: return
	face.border_color = Color(accent, 1.0)
	if _near(accent, GOLD) or _near(accent, gold()):
		# The cream is solid where the white is 0.9 — a pill already faded keeps its share of that.
		face.bg_color = Color(NOTIF_OWN, minf(1.0, face.bg_color.a / PANEL.a))


## Two colours the same to the eye (alpha aside).
static func _near(a: Color, b: Color) -> bool:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.02


# ── Badges ────────────────────────────────────────────────────────────

## A badge is a round painted badge: green when its colour is a green (success, GO!), blue for every other colour
## (the countdown's) — the game has those two.
func badge_box(ink_color: Color) -> StyleBox:
	var green := ink_color.s >= 0.25 and ink_color.h >= 0.2 and ink_color.h <= 0.45
	var face := _sprite("badge_green.png" if green else "badge_blue.png", BADGE_EDGE, PAINT_PPU)
	face.face_color = BADGE_GREEN_FACE if green else BADGE_BLUE_FACE
	face.content_margin_left = badge_pad_x
	face.content_margin_right = badge_pad_x
	face.content_margin_top = badge_pad_y
	face.content_margin_bottom = badge_pad_y
	return face


## The light, ink-rimmed country pill under a world-tour badge.
func world_tour_caption_box() -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = Color("#f4fbff")
	face.border_color = INK
	face.set_border_width_all(2)
	face.border_width_bottom = 3
	face.set_corner_radius_all(22)
	face.anti_aliasing = true
	return face


func world_tour_backdrop_color() -> Color:
	return Color("#4bb6f4")


## The nine islands share one imported atlas, keeping the mobile texture footprint independent of image count.
## Atlas order follows the route (1-based); callers may replace the pictures with their own stage art.
func world_tour_picture(stage: int) -> Texture2D:
	var regions: Array[Rect2] = [Rect2(80, 45, 365, 280), Rect2(450, 12, 340, 280), Rect2(850, 80, 385, 275),
			Rect2(1235, 235, 410, 305), Rect2(740, 355, 494, 305), Rect2(240, 285, 480, 300),
			Rect2(40, 550, 385, 285), Rect2(420, 625, 495, 305), Rect2(1105, 635, 510, 300)]
	if stage < 1 or stage > regions.size(): return null
	if _world_tour_pictures.has(stage): return _world_tour_pictures[stage]
	var source := widget_art(&"world_tour_islands")
	if source == null: return null
	var picture := AtlasTexture.new()
	picture.atlas = source
	picture.region = regions[stage - 1]
	_world_tour_pictures[stage] = picture
	return picture


func world_tour_detail_picture(stage: int) -> Texture2D:
	if stage != 9: return null
	if _world_tour_stage9_detail == null:
		_world_tour_stage9_detail = AtlasTexture.new()
		_world_tour_stage9_detail.atlas = load("res://addons/gohud/assets/arcade_light/stage/world_tour_reference.png")
		# A clean crop of the original artwork: no baked ribbon, title, stars or other interactive chrome.
		_world_tour_stage9_detail.region = Rect2(1209, 318, 420, 337)
	return _world_tour_stage9_detail


# ── Bars and the outlined button ──────────────────────────────────────

## A bar's fill is the arcade tube in the bright fill of its colour — the theme's fill is a sprite now, and the plain
## look would only recolour its middle.
func progress_fill_box(ink_color: Color) -> StyleBox:
	var tube := key(vivid(Color(ink_color, 1.0)), GoUi.metric(GoTheme.RADIUS_SMALL), 0, 2)
	tube.bottom_color = Color(0, 0, 0, 0)
	tube.shade_color = Color(0, 0, 0, 0)
	tube.border_color = INK
	return tube


## An outlined button is the arcade's white key cap (its label is `outlined_button_ink`, read on this cap) — the theme's
## buttons are sprites, which `GoSkinArcade` would hand back to the plain wash.
func outlined_button_box(face: StyleBox, state: StringName) -> StyleBox:
	if state == &"focus": return face
	var key_cap := cap(KEY_RADIUS_SMALL, Color.TRANSPARENT, 0.0, arcade_lip, arcade_edge)
	key_cap.keep_margins(face)
	if state == &"hover": key_cap.bg_color = key_cap.bg_color.lerp(GoUi.color(GoTheme.SURFACE_HIGH), 0.5)
	elif state == &"disabled":
		key_cap.bg_color = Color(key_cap.bg_color, 0.55)
		key_cap.shine = 0.0
	key_cap.pressed = state == &"pressed" or state == &"hover_pressed"
	return key_cap


## The HUD bar's groove. Its content margins reserve the ink rim for the fill's separate rounded mask.
func bar_frame_box() -> StyleBox:
	var groove := StyleBoxFlat.new()
	groove.bg_color = BAR_BG
	groove.set_corner_radius_all(BAR_RADIUS)
	groove.set_border_width_all(BAR_OUTLINE)
	groove.border_color = INK
	groove.set_content_margin_all(BAR_OUTLINE)
	groove.anti_aliasing = true
	return groove


func bar_fill_clip_box() -> StyleBox:
	var inside := StyleBoxFlat.new()
	inside.bg_color = Color.WHITE
	inside.set_corner_radius_all(BAR_RADIUS - BAR_OUTLINE)
	inside.set_content_margin_all(0.0)
	inside.anti_aliasing = true
	return inside


## The game's repulse panel (`HUD._repulse_box`: `UiTheme.box(PANEL, 14, 3, rim, shadow, 14, 8)`) — a READY_RED rim
## when lit, an ink one while cooling.
func hud_gauge_box(lit: bool) -> StyleBox:
	var face := StyleBoxFlat.new()
	face.bg_color = PANEL
	face.set_corner_radius_all(GAUGE_RADIUS)
	face.set_border_width_all(GAUGE_OUTLINE)
	face.border_color = READY_RED if lit else INK
	face.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	face.shadow_size = 1
	face.shadow_offset = Vector2(0.0, 4.0)
	face.content_margin_left = GAUGE_PAD.x
	face.content_margin_right = GAUGE_PAD.x
	face.content_margin_top = GAUGE_PAD.y
	face.content_margin_bottom = GAUGE_PAD.y
	face.anti_aliasing = true
	return face


## The game's "Esc" cap beside the pause button (`HUD.pause_hint`: `UiTheme.chunky_box(#6c7aa8, 8, 6, 1, 3, 5)`).
func hud_key_hint_box() -> StyleBox:
	var cap := StyleBoxFlat.new()
	cap.bg_color = KEY_HINT_FILL
	cap.set_corner_radius_all(8)
	cap.set_border_width_all(3)
	cap.border_width_bottom = 5
	cap.border_color = INK
	cap.content_margin_left = 6.0
	cap.content_margin_right = 6.0
	cap.content_margin_top = 4.0
	cap.content_margin_bottom = 6.0
	cap.anti_aliasing = true
	return cap


## White on the slate cap.
func hud_key_hint_ink() -> Color:
	return Color.WHITE


## The game's `PauseRound` press tint.
func picture_press_tint() -> Color:
	return Color(0.78, 0.78, 0.86)


## The game's countdown badges (`Screens._countdown_badge`): blue under a digit, green under GO.
func countdown_disc(final: bool) -> Texture2D:
	var file := "badge_green.png" if final else "badge_blue.png"
	if not _textures.has(file): _textures[file] = load(PAINTED + file)
	return _textures[file]


## The game's countdown digits: GOLD.
func countdown_ink() -> Color:
	return GOLD


## The game's name plates (`Nameplates.add`): a 92% fill, radius 8, a 2 px INK rim, 2 px side margins.
func nameplate_box(fill: Color) -> StyleBox:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill, 0.92)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = INK
	box.content_margin_left = 2.0
	box.content_margin_right = 2.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.anti_aliasing = true
	return box


## The game's own plate: GOLD.
func nameplate_own_fill() -> Color:
	return GOLD


## The game's plate names: INK on the own plate, white on the others.
func nameplate_ink(own: bool) -> Color:
	return INK if own else Color.WHITE


## The game's plate names: no edge on the own plate, 3 px on the others.
func nameplate_outline(own: bool) -> int:
	return 0 if own else 3


## The game's plate name edge: INK.
func nameplate_outline_ink() -> Color:
	return INK


## The game's touch stick (`TouchControls._draw_stick`): the painted dish and knob.
func joystick_art(knob: bool) -> Texture2D:
	return widget_art(&"stick_knob" if knob else &"stick_base")


## The game's touch shadow and label edge: INK.
func touch_shadow_ink() -> Color:
	return INK


func touch_outline_ink() -> Color:
	return INK


## The game's REPULSE cooldown arc.
func touch_cooldown_ink() -> Color:
	return Color("#ff7a74")


## The training spotlight: a navy dim and a 4 px gold ring, 12 round.
func spotlight_dim() -> Color:
	return Color(0.04, 0.06, 0.14, 0.55)


func spotlight_ring_box() -> StyleBox:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(4)
	ring.border_color = GOLD
	ring.set_corner_radius_all(12)
	return ring


# 🎨 The training card's title gold (HUD_NAME) and hint red, and the clock's last seconds (READY_RED), are the
#    look's `heading` and `alert` tokens (`themes/palettes/arcade_light.json`): `GoSkin.task_title_ink()`,
#    `task_hint_ink()` and `hud_alert_ink()` read them.


## The game's fps colours: GREEN, GOLD and RED.
func perf_ink(level: int) -> Color:
	return [GREEN, GOLD, Color("#ff4d4d")][clampi(level, 0, 2)]


## The game draws its readout in the engine's own font (it sits on a layer with no theme).
func perf_font() -> Font:
	return ThemeDB.fallback_font

## The game's text font is Nunito with the Noto Sans CJK fonts as fallbacks, so a mark Nunito lacks (the ✓ on a
## done chip) draws in the first of them — Noto Sans KR Bold, or the current language's own once `GoUi.set_locale()`
## put it first (the same files, shipped beside the art).
func symbol_font() -> Font:
	var look := GoUi.theme()
	var baked: Variant = look.get_meta(&"go_body_font_baked", null) if look != null else null
	if baked is FontVariation and not (baked as FontVariation).fallbacks.is_empty():
		return (baked as FontVariation).fallbacks[0]
	if _symbol_font == null: _symbol_font = load("res://addons/gohud/assets/fonts/noto_sans_cjk/NotoSansKR-Bold.ttf")
	return _symbol_font

## The game's chunk lines: 3 px INK at `BarSegments`' positions, the full height of the bar.
func draw_bar_ticks(canvas: CanvasItem, rect: Rect2, count: int) -> void:
	for index in range(1, count):
		var x := roundf(rect.position.x + rect.size.x * float(index) / float(count))
		canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), INK, TICK_WIDTH)


# ── Key hints ─────────────────────────────────────────────────────────

## A `GoKbd` key is the painted keycap.
func kbd_box() -> StyleBox:
	var face := _sprite("keycap.png", KEYCAP_EDGE, KEYCAP_PPU)
	face.face_color = KEYCAP_FACE
	return _pad(face, KEYCAP_PAD)


## The word on the keycap is the ink.
func kbd_ink() -> Color:
	return INK


# ── Window chrome ─────────────────────────────────────────────────────

## A window's title sits on the gold ribbon.
func title_plate_box() -> StyleBox:
	var face := _sprite("ribbon_gold.png", RIBBON_EDGE, RIBBON_PPU)
	face.face_color = RIBBON_FACE
	return _pad(face, RIBBON_PAD)


## The title on the ribbon is white…
func title_plate_ink() -> Color:
	return Color.WHITE


## The ribbon header's 34 dp title on its 57 dp ribbon (`RibbonHeader.FONT_SIZE`, `RIBBON_HEIGHT`)…
const RIBBON_TITLE_SIZE := 34
const RIBBON_HEIGHT := 57.0


func title_plate_font_size() -> int:
	return RIBBON_TITLE_SIZE


func title_plate_height() -> float:
	return RIBBON_HEIGHT


## …shrinking as the game's `fit_font_size` does: no lower than `fit_min_scale` of it (24).
func title_plate_min_size() -> int:
	return GoStyle.fit_floor(RIBBON_TITLE_SIZE)


## …with the ribbon header's ink outline.
func dress_title(label: Label) -> void:
	var variation := label.theme_type_variation
	var look := GoUi.theme()
	# A caller can select a typography variation while keeping the look's title plate and fit behavior.
	var ink := look.get_color(&"font_outline_color", variation) if look.has_color(&"font_outline_color", variation) else INK
	var outline := look.get_constant(&"outline_size", variation) if look.has_constant(&"outline_size", variation) else RIBBON_TITLE_OUTLINE
	label.add_theme_color_override(&"font_outline_color", ink)
	label.add_theme_constant_override(&"outline_size", outline)


## A scrim is the game's frosted backdrop while `arcade_scrim_blur` is above 0 (it sets the mip level read; 3 is the
## game's), the plain veil at 0. 🛑 The game's shader draws opaque and ignores the scrim's colour — a scrim that fades
## its colour in shows the blur at once.
func scrim_material() -> Material:
	if arcade_scrim_blur <= 0.0: return null
	if _painted_blur == null: _painted_blur = load(BLUR_SHADER_PATH) as Shader
	var material := ShaderMaterial.new()
	material.shader = _painted_blur
	var level := clampf(arcade_scrim_blur, 0.0, 4.0)
	material.set_shader_parameter(&"blur_lod", level)
	material.set_shader_parameter(&"spread", level * SCRIM_SPREAD_PER_LOD)
	material.set_shader_parameter(&"wash", SCRIM_WASH)
	return material


# ── Painted widgets ───────────────────────────────────────────────────

## The look's art folder.
const ART_ROOT := "res://addons/gohud/assets/arcade_light/"
## The stage-select art: check, lock, person, play_tag, pointer. 🛑 A file that is not there reads as no art, and the
## widget falls back to the icon set.
const STAGE_ART := ART_ROOT + "stage/"
## The match HUD's art (avatar_head, bolt, opponents_badge, stopwatch, pause_button; shield, painted for gohud by
## `tools/paint_arcade_shield.gd`) and the touch controls' art
## (btn_attract, btn_repulse, btn_jump, stick_base, stick_knob) — the game's `assets/ui/hud` and `assets/ui/touch`.
## Painted for gohud in the same style: the power-up icons a HUD card shows (`hud/powerup_banana`, `powerup_trap`,
## `powerup_reflect`, `powerup_bomb`) and the item keys a held power-up is dropped with (`touch/btn_banana`, `btn_trap`).
const HUD_ART := ART_ROOT + "hud/"
const TOUCH_ART := ART_ROOT + "touch/"
## Numbered gold, silver and bronze award medals, with ribbon tails and glossy faces.
const SCORE_ART := ART_ROOT + "score/"
## The podium leaderboard's art (category plates and icons, check badges, the stepper plate, the empty-board pictures).
const LEADERBOARD_ART := ART_ROOT + "leaderboard/"
## The folders `widget_art` looks in, in order.
const ART_FOLDERS: Array[String] = [STAGE_ART, HUD_ART, TOUCH_ART, SCORE_ART, LEADERBOARD_ART]
## The sky behind an opaque window, the game's `STAGE_SKY`.
const STAGE_SKY := Color(0.36, 0.62, 0.92, 1.0)
## A selected stage card's gold ring.
const SELECTED_RING := Color("#ffd23f")
const SELECTED_RING_WIDTH := 4
const SELECTED_RING_RADIUS := 26
## The key diagram's keycap scale (the game's `KeyDiagram`).
const KEY_CLUSTER_PPU := 4.2
## The ribbon header: how far it reaches past the card's sides and above its top edge.
const RIBBON_OVERHANG := Vector2(14.0, 17.0)


## The painted art, when the theme ships it: `assets/arcade_light/stage/<name>.png`, then `hud/`, then `touch/`.
func widget_art(name: StringName) -> Texture2D:
	for folder in ART_FOLDERS:
		for suffix: String in [".png", ".svg"]:
			var path := folder + String(name) + suffix
			if not _textures.has(path):
				_textures[path] = load(path) if ResourceLoader.exists(path) else null
			if _textures[path] != null: return _textures[path]
	return null


# ── 🏆 Leaderboard controls ─────────────────────────────────────────────

## The art's height at the reference size (dp): a category plate, the stepper's plate. The art may come at any scale —
## it is drawn at `texture height / these`.
const CATEGORY_ART_HEIGHT := 100.0
const PAGE_PLATE_ART_HEIGHT := 72.0
## Of the art's height, how much of each end is its rounded cap (the 9-slice keeps it) — the middle is flat.
const PLATE_ART_CAP := 0.42
## The page dots: the current page in ink, the others the stepper's light blue.
const PAGE_DOT_LIGHT := Color("#3aa0ff")
## The loading ring's head dash (the game's control blue, deepened).
const LOADING_RING := Color("#1f6fe5")
## The light round the picked difficulty pill.
const BUTTON_GLOW := Color(1.0, 0.98, 0.82, 0.85)


## The category plate (`category_blue` / `category_gold`) as a 9-slice, pressed darker and faded off as the pills are.
func category_button_art(selected: bool, state: StringName) -> StyleBox:
	var art := widget_art(&"category_gold" if selected else &"category_blue")
	if art == null: return null
	return _plate_art(art, CATEGORY_ART_HEIGHT, state)


func page_plate_art() -> StyleBox:
	var art := widget_art(&"stage_plate")
	if art == null: return null
	return _plate_art(art, PAGE_PLATE_ART_HEIGHT, &"normal")


func page_dot_colors() -> PackedColorArray:
	return PackedColorArray([INK, PAGE_DOT_LIGHT])


func loading_ring_color() -> Color:
	return LOADING_RING


func button_glow_color() -> Color:
	return BUTTON_GLOW


## A plate picture [param height] dp tall at the reference size, cut so its rounded ends keep their shape.
func _plate_art(art: Texture2D, height: float, state: StringName) -> GoStyleBoxSprite:
	var cap := art.get_height() * PLATE_ART_CAP
	var face := GoStyleBoxSprite.new()
	face.texture = art
	face.edge = Vector4(cap, cap, cap, cap)
	face.pixels_per_unit = art.get_height() / height
	match state:
		&"pressed", &"hover_pressed": face.tint = Color(0.86, 0.86, 0.9)
		&"disabled": face.tint = Color(0.6, 0.6, 0.66, 0.85)
	return face


## The game's gold ring round the selected stage card.
func selection_ring_box() -> StyleBox:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = SELECTED_RING
	ring.set_border_width_all(SELECTED_RING_WIDTH)
	ring.set_corner_radius_all(SELECTED_RING_RADIUS)
	ring.corner_detail = 8
	ring.anti_aliasing = true
	return ring


## The key diagram's keycap: the painted cap at the diagram's scale, with no padding.
func key_cluster_box() -> StyleBox:
	var face := _sprite("keycap.png", KEYCAP_EDGE, KEY_CLUSTER_PPU)
	var cap := kbd_box()
	face.face_color = (cap as GoStyleBoxSprite).face_color if cap is GoStyleBoxSprite else Color.WHITE
	return _pad(face, Vector3.ZERO)


## The ribbon hangs over the card's top edge and past its sides.
func title_plate_overhang() -> Vector2:
	return RIBBON_OVERHANG


## The game's sky under an opaque dialog.
func opaque_backdrop_color() -> Color:
	return STAGE_SKY


# ── The window frame: the game's PaintedDialog ────────────────────────

## The game's dialog card: 400 dp wide, its rows 8 apart (`PaintedDialog.CARD_WIDTH`, the column's separation).
const WINDOW_WIDTH := 400.0
const WINDOW_GAP := 8


## A window wears the painted card…
func window_card_variation() -> StringName:
	return &"GoCard"


## …whose face carries the padding (24 / 20 / 22), so nothing is added inside it…
func window_padding() -> int:
	return 0


## …with the game's 8 dp between rows…
func window_gap() -> int:
	return WINDOW_GAP


## …and the game's 400 dp width.
func window_width() -> float:
	return WINDOW_WIDTH


## …centred like the game's `CenterContainer`: no margin off the screen's edge, so a phone (407 wide) still gets 400.
func window_screen_margin() -> float:
	return 0.0


## …and mipmapped like the game's `PaintedDialog`, so the 3x-sized sprites stay smooth where a unit is about a pixel.
func window_texture_filter() -> CanvasItem.TextureFilter:
	return CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## The game's parts inside a dialog: the pale `InsetPanel`, glossy buttons 46 dp high (`PaintedDialog.BUTTON_HEIGHT`)
## and 10 dp apart in a row.
const WINDOW_BUTTON_HEIGHT := 46.0
const WINDOW_BUTTON_GAP := 10


func window_inset_variation() -> StringName:
	return &"GoInsetPanel"


func window_button_height() -> float:
	return WINDOW_BUTTON_HEIGHT


func window_button_gap() -> int:
	return WINDOW_BUTTON_GAP


## The game's `FitBox`: a card fitted to the screen keeps 8 dp off the safe area, ribbon and magnet included
## (`Cfg.Ui.WINDOW_FIT_PAD`), and its list keeps 96 dp before the card shrinks below the fit floor
## (`Cfg.Ui.FLEX_MIN_HEIGHT`).
const WINDOW_FIT_PAD := 8.0
const WINDOW_FLEX_MIN_HEIGHT := 96.0


func window_fit_pad() -> float:
	return WINDOW_FIT_PAD


func window_flex_min_height() -> float:
	return WINDOW_FLEX_MIN_HEIGHT


## The red magnet in the ribbon's corner (`RibbonHeader`: 58 × 56, 30 dp out past the ribbon's end and 24 above it)
## stands where a close button would — the game's dialogs have none.
const CORNER_ART := "res://addons/gohud/icons/arcade_light/magnet.png"
const CORNER_RECT := Rect2(-30.0, -24.0, 58.0, 56.0)


func window_corner() -> StringName:
	return &"art"


func window_corner_art() -> Texture2D:
	if not _textures.has(CORNER_ART):
		_textures[CORNER_ART] = load(CORNER_ART) if ResourceLoader.exists(CORNER_ART) else null
	return _textures[CORNER_ART]


func window_corner_rect() -> Rect2:
	return CORNER_RECT


## The close key (`GoSurface.show_close_key`) mirrors the magnet: a 48 dp round key (a touch target at the window's
## own size) centred where the magnet's centre is, on the ribbon's other end — 25 dp out past it and 20 above.
const CLOSE_KEY_RECT := Rect2(-25.0, -20.0, 48.0, 48.0)
## The red disc (`close_key.png`, 138 x 138: btn_red's red and lip with no white glare, `tools/paint_arcade_close_key.gd`):
## its four 69 px corners and no middle — a key up to 69 dp square at this scale draws only the corners, so it is
## round. The danger button's tints and face.
const CLOSE_KEY_EDGE := Vector4(69.0, 69.0, 69.0, 69.0)
const CLOSE_KEY_PPU := 2.0
## The colour the red disc shows under the cross — the danger button's `face_color` (the centre of `btn_red.png`).
const CLOSE_KEY_FACE := Color(0.964706, 0.231373, 0.219608, 1.0)
## The painted buttons' pressed and disabled tints (`tools/theme_arcade_painted.py`).
const PRESSED_TINT := Color(0.8, 0.8, 0.86, 1.0)
const DISABLED_TINT := Color(0.6, 0.6, 0.66, 0.85)


func window_close_key_rect() -> Rect2:
	return CLOSE_KEY_RECT


## A window's close key is the painted red disc (no glare), with the white cross — pressed it darkens like the danger
## button (and pops, `press_feedback`); disabled it greys.
func dress_close_button(button: GoIconButton) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var tint := Color.WHITE
		if state == &"pressed" or state == &"hover_pressed": tint = PRESSED_TINT
		elif state == &"disabled": tint = DISABLED_TINT
		var face := _sprite("close_key.png", CLOSE_KEY_EDGE, CLOSE_KEY_PPU, tint)
		face.face_color = CLOSE_KEY_FACE * tint
		face.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, face)
	# The theme's icon buttons ink their glyph navy when hovered or pressed: the cross stays white on the red.
	button.icon_tint = Color.WHITE
	var inks: Array[StringName] = [&"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color",
		&"icon_focus_color", &"icon_disabled_color"]
	for ink in inks:
		button.add_theme_color_override(ink, Color.WHITE)
	# The surface lifts these again when the look changes (`GoSkin.undress_close_button`).
	button.set_meta(&"go_dressed_inks", inks)


## The controls stay out of the focus order, as the game's are (`GlossButton`, `PaintedSlider`, `PaintedSwitch`,
## `StageCard` and its pickers all set `FOCUS_NONE`): a touch game shows no focus ring after a tap.
func control_focus_mode(_default_mode := Control.FOCUS_ALL) -> Control.FocusMode:
	return Control.FOCUS_NONE
