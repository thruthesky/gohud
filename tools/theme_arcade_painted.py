"""🎨 **The painted arcade** — the `arcade_painted` shape (`arcade_light` only): Magnet Mayhem's painted look.

The arcade cabinet (`tools/theme_arcade.py`) draws every part first, in this palette's colours; this shape then lays
the game's painted sprites (`assets/arcade_light/painted/*.png`, drawn by `GoStyleBoxSprite`) and its flat pieces over
the variations the game uses, **with exactly the items and values of `UiTheme._build()`** in Magnet Mayhem
(`src/ui/ui_theme.gd`): the same edges (texture px), pixels per unit, tints, padding, colours, outlines and
constants. Parts with no painted art (rows, tabs, bars …) keep the arcade's code-drawn keys.

🔑 **The game builds its theme as `duplicate(arcade_light)` plus aliases** from `tools/arcade_painted_map.json`
   (written here): each mapped variation must carry the game variation's item set and nothing else — so every item
   `build()` or the arcade gave it is dropped first. The game adds its fonts on top; the sizes written here are the
   game's literal ones, or a `Cfg` size at its desktop value (`CFG_SIZES`: the HUD panel's and banner's padding, the
   language chip's font) — the game swaps in its touch value itself.
🛑 Change a value here only together with the game's `UiTheme` — the two must draw the same pixels.
"""
import json
import os

RES = "res://addons/gohud"
SPRITE_SCRIPT = RES + "/widgets/go_stylebox_sprite.gd"
ICON_SCRIPT = RES + "/widgets/go_texture_sprite.gd"
PAINTED = RES + "/assets/arcade_light/painted/"
# The stage-select art (the game's `assets/ui/stage`): a sprite named "stage/<file>" is drawn from here.
STAGE = RES + "/assets/arcade_light/stage/"
# 🔤 The game's font (`UiTheme.get_font()`): Nunito Bold, then the four Noto Sans CJK Bold subsets in the game's
#    `fallback_order("")` — Korean, Japanese, Simplified, Traditional Chinese. The files are the game's own (subset to
#    its strings, with its vertical metrics: `tools/fonts/build_fonts.py` there), so a label is set exactly as in the
#    game. Glyphs outside the subsets come from the system (the files import with `allow_system_fallback`).
FONTS = RES + "/assets/fonts/"
FONT_BASE = ("font_nunito", FONTS + "nunito/Nunito-Bold.ttf")
FONT_FALLBACKS = [("font_noto_%s" % code.lower(), FONTS + "noto_sans_cjk/NotoSans%s-Bold.ttf" % code)
                  for code in ("KR", "JP", "SC", "TC")]
MAP_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "arcade_painted_map.json")

SHAPE = dict(kind="arcade_painted")

# ── The game's constants (`UiTheme`) ──
WHITE = (1.0, 1.0, 1.0, 1.0)
INK = (0.113725, 0.137255, 0.25098, 1.0)                 # #1d2340
CONTROL_BLUE = (0.239216, 0.419608, 1.0, 1.0)            # #3d6bff
GOLD = (1.0, 0.788235, 0.156863, 1.0)                    # #ffc928
NOTIF_OWN = (1.0, 0.952941, 0.811765, 1.0)               # #fff3cf (`NotifPlayer`'s cream)
CHIP = (0.137255, 0.168627, 0.341176, 1.0)               # #232b57 (`LangChip`)
CHIP_PRESSED = (0.090196, 0.113725, 0.258824, 1.0)       # #171d42
CHIP_RIM = (0.435294, 0.584314, 1.0, 1.0)                # #6f95ff
ICON_PRESSED = (0.78, 0.78, 0.86, 1.0)                   # `PauseRound`'s pressed icon
DIFF_BG = (0.933333, 0.945098, 0.984314, 1.0)            # #eef1fb
DIFF_SELECTED = (0.498039, 0.894118, 1.0, 1.0)           # #7fe4ff
SECONDARY = (0.541176, 0.560784, 0.701961, 1.0)          # #8a8fb3
SECONDARY_HOVER = (0.603922, 0.623529, 0.752941, 1.0)    # #9a9fc0 (`BigSecondary`)
SECONDARY_PRESSED = (0.478431, 0.498039, 0.639216, 1.0)  # #7a7fa3
GREEN = (0.243137, 0.811765, 0.352941, 1.0)              # #3ecf5a (`Big`)
GREEN_HOVER = (0.333333, 0.862745, 0.439216, 1.0)        # #55dc70
GREEN_PRESSED = (0.203922, 0.721569, 0.305882, 1.0)      # #34b84e
DIFF_HOVER = (0.964706, 0.972549, 1.0, 1.0)              # #f6f8ff (`Diff`)
SMALL_INK = (0.113725, 0.137255, 0.25098, 0.75)          # `SmallLabel`: Color(INK, 0.75)
CLEAR = (0.0, 0.0, 0.0, 0.0)
PANEL = (1.0, 1.0, 1.0, 0.9)
PRESSED_TINT = (0.8, 0.8, 0.86, 1.0)
DISABLED_TINT = (0.6, 0.6, 0.66, 0.85)
FADED_WHITE = (1.0, 1.0, 1.0, 0.6)
FLAT_SHADOW = (0.0, 0.0, 0.0, 0.25)                      # `UiTheme.box(shadow = true)`
PAINT_PPU = 3.0
RIBBON_PPU = 3.4
KEYCAP_PPU = 5.5
GLOSS_EDGE = (100, 65, 100, 66)
KEY_EDGE = (70, 70, 70, 80)
RIBBON_EDGE = (100, 80, 100, 80)
CARD_EDGE = (100, 100, 100, 140)
INSET_EDGE = (60, 60, 60, 60)
STAGE_RIBBON_PPU = 2.4
STAGE_WELL_PPU = 3.0
STAGE_CARD_PPU = 2.2
WINDOW_EDGE = (70, 70, 70, 70)
STAGE_RIBBON_EDGE = (200, 50, 200, 50)
STAGE_WELL_EDGE = (60, 60, 60, 60)
STAGE_CARD_EDGE = (60, 60, 60, 60)
GLOSS_FONT_SIZE = 22
TITLE_FONT_SIZE = 54
BIG_FONT_SIZE = 24
DIFF_FONT_SIZE = 15
SMALL_FONT_SIZE = 12
BAR_FONT_SIZE = 11
KEYCAP_FONT_SIZE = 16
DROPDOWN_FONT_SIZE = 17
# 🔑 The game's `Cfg` sizes, at their desktop value (`src/client_config.gd`): the HUD panel's and the name banner's
#    clear space (`Cfg.Hud.PANEL_PADDING` / `BANNER_PADDING`; a touch screen uses 4 / 2) and the language chip's font.
HUD_PANEL_PADDING = 8.0
HUD_BANNER_PADDING = 4.0
CHIP_FONT_SIZE = 15
# The slider (`PaintedSlider`): an 80 px tall pill drawn 16 units tall, a 108 px handle drawn 36 units wide.
BAR_EDGE = (48, 38, 48, 38)
BAR_PPU = 5.0
BAR_HEIGHT = 16.0
HANDLE_SIZE = (36, 36)
# The switch (`PaintedSwitch` `SWITCH_SIZE`): the 186 × 71 pills drawn 76 × 29 units.
SWITCH_SIZE = (76, 29)
# The fills `PaintedSlider.use_fill()` offers: blue is HSlider itself, the others a variation each.
SLIDER_FILLS = {"HSlider": "slider_blue.png", "GoSliderGreen": "slider_green.png", "GoSliderCyan": "slider_cyan.png"}

# 🔑 The colour each sprite shows under its label — sampled at the middle of the PNG. `face_color` is never drawn;
#    it is what `check_contrast.py` measures text against (tinted like the face it belongs to).
FACES = {
    "btn_grey.png": (0.576471, 0.580392, 0.745098, 1.0),     # #9394be
    "btn_blue.png": (0.227451, 0.47451, 0.988235, 1.0),      # #3a79fc
    "btn_red.png": (0.964706, 0.231373, 0.219608, 1.0),      # #f63b38
    "btn_green.png": (0.262745, 0.843137, 0.356863, 1.0),    # #43d75b
    "card.png": (0.952941, 0.972549, 0.992157, 1.0),         # #f3f8fd
    "inset.png": (0.878431, 0.941176, 0.992157, 1.0),        # #e0f0fd
    "keycap.png": (0.937255, 0.941176, 0.972549, 1.0),       # #eff0f8
    "ribbon_gold.png": (0.996078, 0.737255, 0.141176, 1.0),  # #febc24
    "ribbon_red.png": (0.917647, 0.184314, 0.172549, 1.0),   # #ea2f2c
    "stage/window.png": (0.815686, 0.909804, 0.988235, 1.0),        # #d0e8fc
    "stage/ribbon_title.png": (0.992157, 0.741176, 0.086275, 1.0),  # #fdbd16
    "stage/card_cleared.png": (0.862745, 0.92549, 0.984314, 1.0),   # #dcecfb
    "stage/card_current.png": (0.384314, 0.945098, 0.454902, 1.0),  # #62f174
    "stage/card_locked.png": (0.698039, 0.717647, 0.811765, 1.0),   # #b2b7cf
    "stage/well.png": (0.086275, 0.137255, 0.27451, 1.0),           # #162346
    "slider_track.png": (0.752941, 0.760784, 0.866667, 1.0),  # #c0c2dd
    "slider_blue.png": (0.086275, 0.509804, 0.996078, 1.0),   # #1682fe
    "slider_green.png": (0.129412, 0.862745, 0.466667, 1.0),  # #21dc77
    "slider_cyan.png": (0.156863, 0.831373, 0.968627, 1.0),   # #28d4f7
}

# Game variation → its gohud name. The values are what the game aliases; `GAME_ONLY` stays in the game.
# 🔑 The game's main actions (PLAY, CONFIRM, SAVE) are `GlossGreen`, so the green pill is gohud's primary key; the blue
#    pill (`GlossBlue`, the game's secondary actions) is `GoInfoButton`. `GoSuccessButton` is the green pill as well.
MAP = {
    "GlossGrey": "GoButton", "GlossBlue": "GoInfoButton", "GlossRed": "GoDangerButton",
    "GlossGreen": "GoPrimaryButton", "GlossToggle": "GoToggleButton",
    "PaintedCard": "GoCard", "InsetPanel": "GoInsetPanel", "KeycapPanel": "GoKeycapPanel", "Keycap": "GoKeycap",
    "RibbonTitle": "GoRibbon", "RibbonRed": "GoRibbonRed", "Notif": "GoNotice",
    "Title": "GoTitle", "OutlineLabel": "GoOutlineLabel",
    "StageWindow": "GoWindowBlue", "StageRibbon": "GoRibbonWide", "StageCard": "GoLevelCard",
    "StageCardNext": "GoLevelCardCurrent", "StageCardLocked": "GoLevelCardLocked",
    "ArcadePanel": "GoHudPanel", "HudBanner": "GoBannerGold", "NotifPlayer": "GoNoticeGold", "LangChip": "GoChipDark",
    "PauseRound": "GoIconOnly",
    # The game's flat parts (`UiTheme.box()` / `_button_boxes()`), older than the painted set but still drawn — the
    # difficulty choice, the big result keys, the small labels — so the game can alias every variation it builds.
    "HudPanel": "GoPanelFlat", "Card": "GoCardFlat", "Diff": "GoChoiceButton", "Big": "GoBigButton",
    "BigSecondary": "GoBigSecondaryButton", "SmallLabel": "GoSmallLabel", "BarLabel": "GoBarLabel",
}
# Variations the game draws in code, not as a UiTheme variation — kept out of MAP (whose keys are all UiTheme names):
# gohud variation → where the game builds it. The game can use the gohud one directly.
CODE_BUILT = {"GoWell": "MapPreview.set_well() (a SpriteBox of stage/well.png)"}
# The `Cfg` sizes written at their desktop value (the game swaps the touch value in itself).
CFG_SIZES = {
    "GoHudPanel": "content margins from Cfg.Hud.PANEL_PADDING = %g (touch: Cfg.Hud.PANEL_PADDING_TOUCH)"
                  % HUD_PANEL_PADDING,
    "GoBannerGold": "content margins from Cfg.Hud.BANNER_PADDING = %g (touch: Cfg.Hud.BANNER_PADDING_TOUCH)"
                    % HUD_BANNER_PADDING,
    "GoChipDark": "font_size is Cfg.Menu.CHIP_FONT = %d (no touch value)" % CHIP_FONT_SIZE,
}
# Every variation the game builds has a gohud name now; none stays in the game.
GAME_ONLY = {}
BASES = {
    "GoButton": "Button", "GoPrimaryButton": "Button", "GoDangerButton": "Button", "GoSuccessButton": "Button",
    "GoInfoButton": "Button", "GoToggleButton": "Button", "GoKeycap": "Button",
    "GoCard": "PanelContainer", "GoInsetPanel": "PanelContainer", "GoKeycapPanel": "PanelContainer",
    "GoRibbon": "PanelContainer", "GoRibbonRed": "PanelContainer", "GoNotice": "PanelContainer",
    "GoTitle": "Label", "GoOutlineLabel": "Label",
    "GoWindowBlue": "PanelContainer", "GoRibbonWide": "PanelContainer", "GoWell": "PanelContainer",
    "GoLevelCard": "Button", "GoLevelCardCurrent": "Button", "GoLevelCardLocked": "Button",
    "GoHudPanel": "PanelContainer", "GoBannerGold": "PanelContainer", "GoNoticeGold": "PanelContainer",
    "GoChipDark": "Button", "GoIconOnly": "Button",
    "GoPanelFlat": "PanelContainer", "GoCardFlat": "PanelContainer", "GoChoiceButton": "Button",
    "GoBigButton": "Button", "GoBigSecondaryButton": "Button", "GoSmallLabel": "Label", "GoBarLabel": "Label",
}
FONT_STATES = ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color")


def _times(a, b):
    return tuple(round(a[i] * b[i], 6) for i in range(4))


def restyle(pal, consts, boxes, T, flat, C, contrast):
    """Lay the game's painted variations over the arcade theme `build()` and `theme_arcade.restyle` made."""

    def drop(type_name):
        T[:] = [entry for entry in T if not entry.split(" = ")[0].startswith(type_name + "/")]

    def setT(key, value):
        T[:] = [entry for entry in T if entry.split(" = ")[0] != key]
        T.append("%s = %s" % (key, value))

    def put(key, bid):
        setT(key, 'SubResource("%s")' % bid)

    def sprite(bid, file, edge, ppu, margin_h, margin_top, margin_bottom, tint=WHITE):
        """`UiTheme.sprite_box()` as a `GoStyleBoxSprite` sub-resource."""
        lines = ['script = ExtResource("sprite")',
                 "content_margin_left = %g" % margin_h, "content_margin_top = %g" % margin_top,
                 "content_margin_right = %g" % margin_h, "content_margin_bottom = %g" % margin_bottom,
                 'texture = ExtResource("%s")' % texture_id(file),
                 "edge = Vector4(%g, %g, %g, %g)" % edge,
                 "pixels_per_unit = %r" % float(ppu)]
        if tint != WHITE:
            lines.append("tint = %s" % C(tint))
        lines.append("face_color = %s" % C(_times(FACES[file], tint)))
        boxes[bid] = ("StyleBox", lines)
        return bid

    def icon(bid, file, size, tint=WHITE):
        """The art squeezed into `size` canvas units (`draw_texture_rect` in the game) as a `GoTextureSprite`."""
        lines = ['script = ExtResource("sprite_icon")', 'texture = ExtResource("%s")' % texture_id(file),
                 "draw_size = Vector2(%g, %g)" % size]
        if tint != WHITE:
            lines.append("tint = %s" % C(tint))
        boxes[bid] = ("Texture2D", lines)
        return bid

    def box(bid, bg, radius, border, border_color=INK, shadow=False, margin_h=14.0, margin_v=8.0, bottom=None,
            outer=None, expand_top=0.0):
        """`UiTheme.box()` (and `chunky_box()` through `bottom` / `outer`) as a StyleBoxFlat sub-resource."""
        lines = ["content_margin_left = %g" % margin_h, "content_margin_top = %g" % margin_v[0],
                 "content_margin_right = %g" % margin_h, "content_margin_bottom = %g" % margin_v[1],
                 "bg_color = %s" % C(bg)]
        for side in ("left", "top", "right"):
            lines.append("border_width_%s = %d" % (side, border))
        lines.append("border_width_bottom = %d" % (bottom if bottom is not None else border))
        lines.append("border_color = %s" % C(border_color))
        for corner in ("top_left", "top_right", "bottom_right", "bottom_left"):
            lines.append("corner_radius_%s = %d" % (corner, radius))
        if outer is not None:
            lines += ["shadow_color = %s" % C(outer[0]), "shadow_size = %d" % outer[1],
                      "shadow_offset = Vector2(%g, %g)" % outer[2]]
        elif shadow:
            lines += ["shadow_color = %s" % C(FLAT_SHADOW), "shadow_size = 1", "shadow_offset = Vector2(0, 4)"]
        if expand_top:
            lines.append("expand_margin_top = %g" % expand_top)
        boxes[bid] = ("StyleBoxFlat", lines)
        return bid

    boxes["painted_empty"] = ("StyleBoxEmpty", [])
    # 🔤 One font for every part, as in the game: the theme's default font (every type without a font of its own
    #    falls back to it before the engine's).
    boxes["painted_font"] = ("FontVariation", ['base_font = ExtResource("%s")' % FONT_BASE[0],
                                               "fallbacks = Array[Font]([%s])" % ", ".join(
                                                   'ExtResource("%s")' % rid for rid, _ in FONT_FALLBACKS)])
    setT("default_font", 'SubResource("painted_font")')
    # 🔑 Baked in — a theme loaded straight from disk sets every label as the game does — and named, so `GoUi.theme()`
    #    lifts it when the project chose a font of its own (gohud never replaces a project's font).
    setT("metadata/go_body_font_baked", 'SubResource("painted_font")')
    for type_name, base in BASES.items():
        drop(type_name)
        setT(type_name + "/base_type", '&"%s"' % base)

    # ── 💊 The glossy pills (`_gloss_button`): one sprite in every state, darker pressed, faded off. ──
    def gloss(type_name, file):
        stem = "painted_%s" % type_name
        normal = sprite(stem + "_normal", file, GLOSS_EDGE, PAINT_PPU, 22.0, 3.0, 6.0)
        pressed = sprite(stem + "_pressed", file, GLOSS_EDGE, PAINT_PPU, 22.0, 5.0, 4.0, PRESSED_TINT)
        disabled = sprite(stem + "_disabled", file, GLOSS_EDGE, PAINT_PPU, 22.0, 3.0, 6.0, DISABLED_TINT)
        for state, bid in (("normal", normal), ("hover", normal), ("pressed", pressed), ("hover_pressed", pressed),
                           ("disabled", disabled), ("focus", "painted_empty")):
            put("%s/styles/%s" % (type_name, state), bid)
        for slot in FONT_STATES:
            setT("%s/colors/%s" % (type_name, slot), C(WHITE))
        setT("%s/colors/font_disabled_color" % type_name, C(FADED_WHITE))
        setT("%s/font_sizes/font_size" % type_name, GLOSS_FONT_SIZE)
        setT("%s/constants/outline_size" % type_name, 4)
        setT("%s/colors/font_outline_color" % type_name, C(INK))
        setT("%s/constants/h_separation" % type_name, 10)

    gloss("GoButton", "btn_grey.png")
    gloss("GoPrimaryButton", "btn_green.png")
    gloss("GoInfoButton", "btn_blue.png")
    gloss("GoDangerButton", "btn_red.png")
    gloss("GoSuccessButton", "btn_green.png")
    # The toggle (`_gloss_toggle`): the grey pill, blue while it is on.
    gloss("GoToggleButton", "btn_grey.png")
    on = sprite("painted_GoToggleButton_on", "btn_blue.png", GLOSS_EDGE, PAINT_PPU, 22.0, 3.0, 6.0)
    put("GoToggleButton/styles/pressed", on)
    put("GoToggleButton/styles/hover_pressed", on)
    boxes.pop("painted_GoToggleButton_pressed", None)

    # ── ⌨ A keyboard key (`_keycap`): no disabled face and no outline of its own, as in the game. ──
    normal = sprite("painted_GoKeycap_normal", "keycap.png", KEY_EDGE, KEYCAP_PPU, 10.0, 3.0, 8.0)
    pressed = sprite("painted_GoKeycap_pressed", "keycap.png", KEY_EDGE, KEYCAP_PPU, 10.0, 6.0, 5.0, PRESSED_TINT)
    for state, bid in (("normal", normal), ("hover", normal), ("pressed", pressed), ("hover_pressed", pressed),
                       ("focus", "painted_empty")):
        put("GoKeycap/styles/%s" % state, bid)
    for slot in FONT_STATES:
        setT("GoKeycap/colors/%s" % slot, C(INK))
    setT("GoKeycap/font_sizes/font_size", KEYCAP_FONT_SIZE)

    # ── 🗂 Panels: the painted card, the inset, a label drawn as a key, the gold and red ribbons. ──
    put("GoCard/styles/panel", sprite("painted_GoCard", "card.png", CARD_EDGE, PAINT_PPU, 24.0, 20.0, 22.0))
    put("GoInsetPanel/styles/panel", sprite("painted_GoInsetPanel", "inset.png", INSET_EDGE, PAINT_PPU, 14.0, 8.0, 8.0))
    put("GoKeycapPanel/styles/panel", sprite("painted_GoKeycapPanel", "keycap.png", KEY_EDGE, KEYCAP_PPU, 9.0, 1.0, 5.0))
    put("GoRibbon/styles/panel", sprite("painted_GoRibbon", "ribbon_gold.png", RIBBON_EDGE, RIBBON_PPU, 22.0, 6.0, 12.0))
    put("GoRibbonRed/styles/panel", sprite("painted_GoRibbonRed", "ribbon_red.png", RIBBON_EDGE, RIBBON_PPU, 22.0, 6.0,
                                           12.0))
    # 🔔 The notice: `chunky_box(PANEL, 16, 12, 2, 3, 5, CONTROL_BLUE, true)` — the padding counts the rim.
    put("GoNotice/styles/panel", box("painted_GoNotice", PANEL, 16, 3, CONTROL_BLUE, margin_h=12.0,
                                     margin_v=(2.0 + 3, 2.0 + 5), bottom=5, outer=(INK, 3, (0, 2))))

    # 🔔 The player's own notice (`NotifPlayer`): the same pill, cream inside a gold rim.
    put("GoNoticeGold/styles/panel", box("painted_GoNoticeGold", NOTIF_OWN, 16, 3, GOLD, margin_h=12.0,
                                         margin_v=(2.0 + 3, 2.0 + 5), bottom=5, outer=(INK, 3, (0, 2))))
    # 🎮 The HUD's blue-rimmed panel (`arcade_panel_box(pad)`: `chunky_box(PANEL, 18, pad + 5, pad, 5, 8, CONTROL_BLUE,
    #    true)`) and its gold name banner (`hud_banner_box(pad)`: `chunky_box(GOLD, 12, pad + 3, pad, 3, 5)`).
    pad = HUD_PANEL_PADDING
    put("GoHudPanel/styles/panel", box("painted_GoHudPanel", PANEL, 18, 5, CONTROL_BLUE, margin_h=pad + 5.0,
                                       margin_v=(pad + 5, pad + 8), bottom=8, outer=(INK, 3, (0, 2))))
    pad = HUD_BANNER_PADDING
    put("GoBannerGold/styles/panel", box("painted_GoBannerGold", GOLD, 12, 3, INK, margin_h=pad + 3.0,
                                         margin_v=(pad + 3, pad + 5), bottom=5))

    # ── 🗺 The stage select: the light-blue window, its swallow-tail ribbon (the 200 px tails stay, the plate between
    #    them stretches), the map preview's dark well (`MapPreview.set_well()`). ──
    put("GoWindowBlue/styles/panel", sprite("painted_GoWindowBlue", "stage/window.png", WINDOW_EDGE, PAINT_PPU, 24.0,
                                            20.0, 22.0))
    put("GoRibbonWide/styles/panel", sprite("painted_GoRibbonWide", "stage/ribbon_title.png", STAGE_RIBBON_EDGE,
                                            STAGE_RIBBON_PPU, 70.0, 6.0, 12.0))
    put("GoWell/styles/panel", sprite("painted_GoWell", "stage/well.png", STAGE_WELL_EDGE, STAGE_WELL_PPU, 0.0, 0.0,
                                      0.0))

    # 🃏 A level card (`_stage_card_button`): one sprite in every state (pressed darker), no padding and no label colours
    #    of its own — the card widget lays out its own text.
    def level_card(type_name, file):
        stem = "painted_%s" % type_name
        normal = sprite(stem + "_normal", file, STAGE_CARD_EDGE, STAGE_CARD_PPU, 0.0, 0.0, 0.0)
        pressed = sprite(stem + "_pressed", file, STAGE_CARD_EDGE, STAGE_CARD_PPU, 0.0, 0.0, 0.0, PRESSED_TINT)
        for state, bid in (("normal", normal), ("hover", normal), ("pressed", pressed), ("hover_pressed", pressed),
                           ("disabled", normal), ("focus", "painted_empty")):
            put("%s/styles/%s" % (type_name, state), bid)

    level_card("GoLevelCard", "stage/card_cleared.png")
    level_card("GoLevelCardCurrent", "stage/card_current.png")
    level_card("GoLevelCardLocked", "stage/card_locked.png")

    # 🌐 The language chip (`_lang_chip`): a dark navy pill with a light-blue rim, `chunky_box(bg, 22, 16, 0, 3, 4, rim,
    #    true)`; no disabled face, as in the game.
    chip = box("painted_GoChipDark", CHIP, 22, 3, CHIP_RIM, margin_h=16.0, margin_v=(0.0 + 3, 0.0 + 4), bottom=4,
               outer=(INK, 3, (0, 2)))
    chip_down = box("painted_GoChipDark_pressed", CHIP_PRESSED, 22, 3, CHIP_RIM, margin_h=16.0,
                    margin_v=(0.0 + 3, 0.0 + 4), bottom=4, outer=(INK, 3, (0, 2)))
    for state, bid in (("normal", chip), ("hover", chip), ("pressed", chip_down), ("hover_pressed", chip_down),
                       ("focus", "painted_empty")):
        put("GoChipDark/styles/%s" % state, bid)
    for slot in FONT_STATES:
        setT("GoChipDark/colors/%s" % slot, C(WHITE))
    setT("GoChipDark/font_sizes/font_size", CHIP_FONT_SIZE)
    setT("GoChipDark/constants/h_separation", 8)

    # ⏸ A frameless key whose icon is the button (`PauseRound`): nothing drawn in any state, the icon darker pressed.
    for state in ("normal", "hover", "pressed", "hover_pressed", "focus", "disabled"):
        put("GoIconOnly/styles/%s" % state, "painted_empty")
    setT("GoIconOnly/colors/icon_pressed_color", C(ICON_PRESSED))
    setT("GoIconOnly/colors/icon_hover_pressed_color", C(ICON_PRESSED))

    # ── 🧱 The game's flat parts: the translucent panel and the white card (`box(..., shadow = true)`). ──
    put("GoPanelFlat/styles/panel", box("painted_GoPanelFlat", PANEL, 14, 3, INK, shadow=True, margin_h=14.0,
                                        margin_v=(8.0, 8.0)))
    put("GoCardFlat/styles/panel", box("painted_GoCardFlat", WHITE, 24, 4, INK, shadow=True, margin_h=36.0,
                                       margin_v=(26.0, 26.0)))

    # 🔘 `_button_boxes()`: a flat key with a 7 px bottom edge (the hard shadow); pressed, the edge is 4 px and the key
    #    steps down 3 px (`expand_margin_top = -3`, the word 3 px lower) — the CSS `:active` the game copies.
    def flat_button(type_name, bg, hover, pressed_bg, margin_h, margin_v, ink, size, outline):
        stem = "painted_%s" % type_name
        normal = box(stem + "_normal", bg, 12, 3, INK, margin_h=margin_h, margin_v=(margin_v, margin_v), bottom=7)
        hov = box(stem + "_hover", hover, 12, 3, INK, margin_h=margin_h, margin_v=(margin_v, margin_v), bottom=7)
        down = box(stem + "_pressed", pressed_bg, 12, 3, INK, margin_h=margin_h, margin_v=(margin_v + 3.0, margin_v),
                   bottom=4, expand_top=-3.0)
        for state, bid in (("normal", normal), ("hover", hov), ("pressed", down), ("hover_pressed", down),
                           ("focus", "painted_empty")):
            put("%s/styles/%s" % (type_name, state), bid)
        for slot in FONT_STATES:
            setT("%s/colors/%s" % (type_name, slot), C(ink))
        setT("%s/font_sizes/font_size" % type_name, size)
        setT("%s/constants/outline_size" % type_name, outline)
        setT("%s/colors/font_outline_color" % type_name, C(INK))

    flat_button("GoBigButton", GREEN, GREEN_HOVER, GREEN_PRESSED, 34.0, 6.0, WHITE, BIG_FONT_SIZE, 3)
    flat_button("GoBigSecondaryButton", SECONDARY, SECONDARY_HOVER, SECONDARY_PRESSED, 34.0, 6.0, WHITE, BIG_FONT_SIZE, 3)
    flat_button("GoChoiceButton", DIFF_BG, DIFF_HOVER, DIFF_SELECTED, 14.0, 6.0, INK, DIFF_FONT_SIZE, 0)
    # The chosen one (`.diff.selected`) is not a key going down but a key staying lit: cyan, a 4 px edge, the word 3 px
    # lower, no step — so it replaces `_button_boxes`' pressed face, as the game does.
    selected = box("painted_GoChoiceButton_pressed", DIFF_SELECTED, 12, 3, INK, margin_h=14.0, margin_v=(9.0, 6.0),
                   bottom=4)
    put("GoChoiceButton/styles/pressed", selected)
    put("GoChoiceButton/styles/hover_pressed", selected)

    # ── 🔤 Labels: ink by default; the title and the outlined label white with a 6 px ink outline. ──
    setT("Label/colors/font_color", C(INK))
    setT("Label/colors/font_outline_color", C(INK))
    setT("Label/constants/outline_size", 0)
    setT("GoTitle/font_sizes/font_size", TITLE_FONT_SIZE)
    setT("GoTitle/colors/font_color", C(WHITE))
    setT("GoTitle/constants/outline_size", 6)
    setT("GoTitle/constants/line_spacing", -6)
    setT("GoOutlineLabel/colors/font_color", C(WHITE))
    setT("GoOutlineLabel/constants/outline_size", 6)
    # The small print (12 px, ink at 75%) and a gauge's caption (11 px, the ink it inherits).
    setT("GoSmallLabel/font_sizes/font_size", SMALL_FONT_SIZE)
    setT("GoSmallLabel/colors/font_color", C(SMALL_INK))
    setT("GoBarLabel/font_sizes/font_size", BAR_FONT_SIZE)

    # ── 🔽 The dropdown (`_dropdown`): a white, ink-rimmed box and a matching list. ──
    drop_box = box("painted_dropdown", WHITE, 10, 3, INK, margin_h=12.0, margin_v=(6.0, 6.0), bottom=5)
    down = box("painted_dropdown_pressed", DIFF_BG, 10, 3, INK, margin_h=12.0, margin_v=(6.0, 6.0), bottom=5)
    for state in ("normal", "hover", "focus"):
        put("OptionButton/styles/%s" % state, drop_box)
    put("OptionButton/styles/pressed", down)
    put("OptionButton/styles/hover_pressed", down)
    put("OptionButton/styles/hover_pressed_mirrored", down)
    for slot in FONT_STATES:
        setT("OptionButton/colors/%s" % slot, C(INK))
    setT("OptionButton/font_sizes/font_size", DROPDOWN_FONT_SIZE)
    # The arcade outlined the white label of its painted dropdown; ink on the white box takes no outline. The game
    # leaves the disabled dropdown to the engine: here it is the same white box, its label the muted ink.
    setT("OptionButton/constants/outline_size", 0)
    put("OptionButton/styles/disabled", drop_box)
    setT("OptionButton/colors/font_disabled_color", C(pal["muted"]))
    # 🛑 A right-to-left layout draws the `*_mirrored` faces, which `make_theme.py` points at the arcade's blue keys —
    #    each takes the painted box of its left-to-right state (the boxes are symmetric).
    for state, bid in (("normal", drop_box), ("hover", drop_box), ("pressed", down), ("disabled", drop_box)):
        put("OptionButton/styles/%s_mirrored" % state, bid)
    put("PopupMenu/styles/panel", box("painted_list", WHITE, 12, 3, INK, shadow=True, margin_h=6.0, margin_v=(6.0, 6.0)))
    put("PopupMenu/styles/hover", box("painted_list_hover", DIFF_SELECTED, 8, 0, INK, margin_h=6.0,
                                      margin_v=(4.0, 4.0)))
    setT("PopupMenu/colors/font_color", C(INK))
    setT("PopupMenu/colors/font_hover_color", C(INK))
    setT("PopupMenu/font_sizes/font_size", DROPDOWN_FONT_SIZE)
    setT("PopupMenu/constants/v_separation", 10)
    # The game's settings dropdowns keep the engine's arrow (12 px, 4 from the edge), and their lists the engine's
    # radio marks and row padding: an OptionButton's items are radio items, so the marks are drawn. `make_theme.py`
    # gives both the arcade's own; they go, so the dropdown and its list draw as the game's do.
    # (Its disabled tint stays: the game never disables a dropdown, and gohud gives every key's icon a colour.)
    unset = ["OptionButton/icons/arrow", "OptionButton/constants/arrow_margin"]
    unset += ["PopupMenu/icons/%s" % mark for mark in ("checked", "unchecked", "radio_checked", "radio_unchecked")]
    unset += ["PopupMenu/icons/%s_disabled" % mark for mark in ("checked", "unchecked", "radio_checked", "radio_unchecked")]
    unset += ["PopupMenu/constants/%s" % c for c in ("h_separation", "icon_max_width", "item_start_padding",
                                                      "item_end_padding")]
    T[:] = [entry for entry in T if entry.split(" = ")[0] not in unset]

    # ── ✏ The text field (`join_lobby.gd`, `create_room.gd`, `secret_prompt.gd`): a white box with a grey rim, a blue
    #    ring over it while typing, the pale blue when it cannot be typed in; ink text and caret. The game has no
    #    multi-line field; TextEdit wears the same three boxes so the two never look like two themes. ──
    field = box("painted_field", WHITE, 10, 2, SECONDARY, margin_v=(8.0, 8.0))
    typing = box("painted_field_focus", CLEAR, 10, 3, CONTROL_BLUE, margin_v=(8.0, 8.0))
    fixed = box("painted_field_read_only", DIFF_BG, 10, 2, SECONDARY, margin_v=(8.0, 8.0))
    for type_name in ("LineEdit", "TextEdit"):
        put("%s/styles/normal" % type_name, field)
        put("%s/styles/focus" % type_name, typing)
        put("%s/styles/read_only" % type_name, fixed)
        setT("%s/colors/font_color" % type_name, C(INK))
        setT("%s/colors/caret_color" % type_name, C(INK))

    # ── 🎚 The slider (`PaintedSlider`): the grey pill track, the coloured fill up to the handle, the round handle. ──
    #    The track's 8 + 8 padding is the bar's height: the engine draws the track and the fill as tall as the
    #    track's minimum size, centred, and the fill ends at the handle's centre (the game's ends 2 units past it,
    #    under the handle). The handle is 36 units wide, so the value maps where it is drawn, as in the game.
    half = BAR_HEIGHT / 2.0
    put("HSlider/styles/slider", sprite("painted_slider_track", "slider_track.png", BAR_EDGE, BAR_PPU, 0.0, half, half))
    for type_name, file in SLIDER_FILLS.items():
        if type_name != "HSlider":
            drop(type_name)
            setT(type_name + "/base_type", '&"HSlider"')
        fill = sprite("painted_%s_fill" % type_name, file, BAR_EDGE, BAR_PPU, 0.0, 0.0, 0.0)
        put("%s/styles/grabber_area" % type_name, fill)
        put("%s/styles/grabber_area_highlight" % type_name, fill)
    handle = icon("painted_slider_handle", "slider_handle.png", HANDLE_SIZE)
    put("HSlider/icons/grabber", handle)
    put("HSlider/icons/grabber_highlight", handle)
    # The game has no disabled slider; the handle fades like every painted part that is off.
    put("HSlider/icons/grabber_disabled", icon("painted_slider_handle_disabled", "slider_handle.png", HANDLE_SIZE,
                                               DISABLED_TINT))

    # ── 🔘 The switch (`PaintedSwitch`): the grey pill with the knob left, the green one with the knob right, at the
    #    game's size in every direction (the game draws them unflipped right to left too); off, they fade. The game's
    #    switch draws no focus ring. ──
    put("CheckButton/styles/focus", "painted_empty")
    # The label beside it is ink in every state, as the game's labels are: the pill says on or off, so the words must
    # not turn blue with it (Button's pressed colours would leak through otherwise). The pill keeps its own colours
    # (white, the engine default the game leaves), and it sits the engine's 4 from its label, as the game's does.
    for slot in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
        setT("CheckButton/colors/%s" % slot, C(INK))
    for slot in ("icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color",
                 "icon_focus_color"):
        setT("CheckButton/colors/%s" % slot, C(WHITE))
    setT("CheckButton/constants/h_separation", "4")
    for on, file in ((True, "toggle_on.png"), (False, "toggle_off.png")):
        key = "checked" if on else "unchecked"
        stem = "painted_" + file[:-len(".png")]
        lit = icon(stem, file, SWITCH_SIZE)
        off = icon(stem + "_disabled", file, SWITCH_SIZE, DISABLED_TINT)
        for suffix in ("", "_mirrored"):
            put("CheckButton/icons/%s%s" % (key, suffix), lit)
            put("CheckButton/icons/%s_disabled%s" % (key, suffix), off)

    # 🔘 A plain Button is the engine's, as in the game (whose theme sets no Button item): the arcade's blue pill there
    #    would paint buttons the game draws flat, and leak its outline, gap and disabled face into every Button
    #    variation that leaves those items unset (the chip's label outlined, the keycap's 4 gap at 10).
    drop("Button")

    # 🧹 The arcade faces nothing points at any more go, so the file holds only what it draws.
    used = set()
    for entry in T:
        value = entry.partition(" = ")[2]
        if value.startswith('SubResource("'):
            used.add(value[len('SubResource("'):-2])
    for bid, (_, body) in boxes.items():
        for line in body:
            if 'SubResource("' in line:
                used.add(line.split('SubResource("')[1].split('"')[0])
    for bid in [bid for bid in boxes if bid not in used]:
        del boxes[bid]
    write_map()


def texture_id(file):
    """"btn_blue.png" → `painted_btn_blue`; "stage/window.png" → `stage_window`."""
    if file.startswith("stage/"):
        return "stage_" + file[len("stage/"):-len(".png")]
    return "painted_" + file[:-len(".png")]


def texture_path(rid):
    if rid.startswith("stage_"):
        return STAGE + rid[len("stage_"):] + ".png"
    return PAINTED + rid[len("painted_"):] + ".png"


def used_assets(assets, boxes, T):
    """The arcade drawings (`ExtResource("<name>")`) the theme still points at, in their order."""
    text = "\n".join(list(T) + [line for _, body in boxes.values() for line in body])
    return [name for name in assets if 'ExtResource("%s")' % name in text]


def ext_resources(boxes):
    """The `[ext_resource]` lines the sprite boxes need — the script, then each texture once, in name order."""
    heads = {body[0] for _, body in boxes.values() if body}
    lines = []
    if 'script = ExtResource("sprite")' in heads:
        lines.append('[ext_resource type="Script" path="%s" id="sprite"]' % SPRITE_SCRIPT)
    if 'script = ExtResource("sprite_icon")' in heads:
        lines.append('[ext_resource type="Script" path="%s" id="sprite_icon"]' % ICON_SCRIPT)
    if any(body[:1] == ['base_font = ExtResource("%s")' % FONT_BASE[0]] for _, body in boxes.values()):
        for rid, path in [FONT_BASE] + FONT_FALLBACKS:
            lines.append('[ext_resource type="FontFile" path="%s" id="%s"]' % (path, rid))
    if not lines:
        return []
    files = sorted({line.split('ExtResource("')[1].split('"')[0] for _, body in boxes.values() for line in body
                    if line.startswith(("texture = ExtResource(\"painted_", "texture = ExtResource(\"stage_"))})
    for rid in files:
        lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (texture_path(rid), rid))
    return lines


def write_map():
    """`tools/arcade_painted_map.json` — the game's names for the variations above (generated, do not edit)."""
    sizes = {"GoButton": GLOSS_FONT_SIZE, "GoPrimaryButton": GLOSS_FONT_SIZE, "GoInfoButton": GLOSS_FONT_SIZE,
             "GoDangerButton": GLOSS_FONT_SIZE,
             "GoSuccessButton": GLOSS_FONT_SIZE, "GoToggleButton": GLOSS_FONT_SIZE, "GoKeycap": KEYCAP_FONT_SIZE,
             "GoTitle": TITLE_FONT_SIZE, "OptionButton": DROPDOWN_FONT_SIZE, "PopupMenu": DROPDOWN_FONT_SIZE,
             "GoChipDark": CHIP_FONT_SIZE, "GoBigButton": BIG_FONT_SIZE, "GoBigSecondaryButton": BIG_FONT_SIZE,
             "GoChoiceButton": DIFF_FONT_SIZE, "GoSmallLabel": SMALL_FONT_SIZE, "GoBarLabel": BAR_FONT_SIZE}
    body = {"_help": "Generated by tools/theme_arcade_painted.py — do not edit by hand. Magnet Mayhem's UiTheme "
                     "variation name → the gohud_arcade_light variation that carries exactly its items and values. "
                     "The game builds its theme as duplicate(arcade_light) plus these names as aliases. game_only "
                     "lists the game's variations that stay in the game (why in _game_only_why).",
            "_font": {"_help": "The theme's default_font is the game's UiTheme.get_font(): a FontVariation of base "
                               "font + fallbacks (the game reorders the fallbacks per language itself).",
                      "base_font": FONT_BASE[1], "fallbacks": [path for _, path in FONT_FALLBACKS]},
            "_font_sizes": {"_help": "Only the default font is written; no variation has a font of its own. The font sizes written are the game's literal ones or a Cfg "
                                     "size's desktop value (named in _cfg_sizes).",
                            "written": sizes, "left_to_game": []},
            "_cfg_sizes": {"_help": "Values that are a Cfg size in the game, written at their desktop value; where "
                                    "Cfg has a touch value (named per entry) the game swaps it in itself.", **CFG_SIZES},
            "_code_built": {"_help": "gohud variations the game builds in code rather than as a UiTheme variation: "
                                     "gohud variation → where the game builds it.", **CODE_BUILT},
            "_base_types": {"_help": "Base types this shape styles as the game does (the game pins base types itself).",
                            "types": ["Label", "OptionButton", "PopupMenu"]}}
    body.update(MAP)
    body["game_only"] = sorted(GAME_ONLY)
    body["_game_only_why"] = dict(sorted(GAME_ONLY.items()))
    with open(MAP_PATH, "w", encoding="utf-8") as fh:
        json.dump(body, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
