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
## The HUD's alert red (`UiTheme.READY_RED`) and the repulse gauge's board (`HUD._repulse_box`).
const READY_RED := Color("#e8332f")
const GAUGE_RADIUS := 14
const GAUGE_OUTLINE := 3
const GAUGE_PAD := Vector2(14.0, 8.0)

static var _textures := {}
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


## The game's HUD bar groove (`UiTheme.box(BAR_BG, 9, 3, INK)`, no padding): the gradient fill is clipped to it.
func bar_frame_box() -> StyleBox:
	var groove := StyleBoxFlat.new()
	groove.bg_color = BAR_BG
	groove.set_corner_radius_all(BAR_RADIUS)
	groove.set_border_width_all(BAR_OUTLINE)
	groove.border_color = INK
	groove.set_content_margin_all(0.0)
	groove.anti_aliasing = true
	return groove


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


## The game's READY_RED: the clock's last seconds and a lit gauge's rim.
func hud_alert_ink() -> Color:
	return READY_RED


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


## …with the ribbon header's ink outline.
func dress_title(label: Label) -> void:
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", RIBBON_TITLE_OUTLINE)


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
## The match HUD's art (avatar_head, bolt, opponents_badge, stopwatch, pause_button) and the touch controls' art
## (btn_attract, btn_repulse, btn_jump, stick_base, stick_knob) — the game's `assets/ui/hud` and `assets/ui/touch`.
const HUD_ART := ART_ROOT + "hud/"
const TOUCH_ART := ART_ROOT + "touch/"
## The folders `widget_art` looks in, in order.
const ART_FOLDERS: Array[String] = [STAGE_ART, HUD_ART, TOUCH_ART]
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
		var path := folder + String(name) + ".png"
		if not _textures.has(path):
			_textures[path] = load(path) if ResourceLoader.exists(path) else null
		if _textures[path] != null: return _textures[path]
	return null


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
