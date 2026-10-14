"""🎨 **The painted arcade** — the `arcade_painted` shape (`arcade_light` only): Magnet Mayhem's painted look.

The arcade cabinet (`tools/theme_arcade.py`) draws every part first, in this palette's colours; this shape then lays
the game's painted sprites (`assets/arcade_light/painted/*.png`, drawn by `GoStyleBoxSprite`) and its flat pieces over
the variations the game uses, **with exactly the items and values of `UiTheme._build()`** in Magnet Mayhem
(`src/ui/ui_theme.gd`): the same edges (texture px), pixels per unit, tints, padding, colours, outlines and
constants. Parts with no painted art (rows, fields, tabs, bars …) keep the arcade's code-drawn keys.

🔑 **The game builds its theme as `duplicate(arcade_light)` plus aliases** from `tools/arcade_painted_map.json`
   (written here): each mapped variation must carry the game variation's item set and nothing else — so every item
   `build()` or the arcade gave it is dropped first. The game adds its fonts and its `Cfg` sizes on top; the font
   sizes written here are the game's literal ones (none of the mapped variations takes a `Cfg` size).
🛑 Change a value here only together with the game's `UiTheme` — the two must draw the same pixels.
"""
import json
import os

RES = "res://addons/gohud"
SPRITE_SCRIPT = RES + "/widgets/go_stylebox_sprite.gd"
PAINTED = RES + "/assets/arcade_light/painted/"
MAP_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "arcade_painted_map.json")

SHAPE = dict(kind="arcade_painted")

# ── The game's constants (`UiTheme`) ──
WHITE = (1.0, 1.0, 1.0, 1.0)
INK = (0.113725, 0.137255, 0.25098, 1.0)                 # #1d2340
CONTROL_BLUE = (0.239216, 0.419608, 1.0, 1.0)            # #3d6bff
DIFF_BG = (0.933333, 0.945098, 0.984314, 1.0)            # #eef1fb
DIFF_SELECTED = (0.498039, 0.894118, 1.0, 1.0)           # #7fe4ff
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
GLOSS_FONT_SIZE = 22
TITLE_FONT_SIZE = 54
KEYCAP_FONT_SIZE = 16
DROPDOWN_FONT_SIZE = 17

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
}

# Game variation → its gohud name. The values are what the game aliases; `GAME_ONLY` stays in the game.
MAP = {
    "GlossGrey": "GoButton", "GlossBlue": "GoPrimaryButton", "GlossRed": "GoDangerButton",
    "GlossGreen": "GoSuccessButton", "GlossToggle": "GoToggleButton",
    "PaintedCard": "GoCard", "InsetPanel": "GoInsetPanel", "KeycapPanel": "GoKeycapPanel", "Keycap": "GoKeycap",
    "RibbonTitle": "GoRibbon", "RibbonRed": "GoRibbonRed", "Notif": "GoNotice",
    "Title": "GoTitle", "OutlineLabel": "GoOutlineLabel",
}
GAME_ONLY = {
    "StageWindow": "stage-select art (assets/ui/stage)",
    "StageRibbon": "stage-select art (assets/ui/stage)",
    "StageCard": "stage-select art (assets/ui/stage)",
    "StageCardNext": "stage-select art (assets/ui/stage)",
    "StageCardLocked": "stage-select art (assets/ui/stage)",
    "HudBanner": "the HUD's name banner; its padding is a Cfg size",
    "ArcadePanel": "the HUD panel; its padding is a Cfg size",
    "LangChip": "the main menu's language chip; its font size is a Cfg size",
    "PauseRound": "the HUD's round pause key (its icon is the button)",
    "NotifPlayer": "the player's own elimination notice (game content)",
    "HudPanel": "the old flat look, not part of the painted set",
    "Card": "the old flat look, not part of the painted set",
    "Diff": "the old flat look, not part of the painted set",
    "Big": "the old flat look, not part of the painted set",
    "BigSecondary": "the old flat look, not part of the painted set",
    "SmallLabel": "a size-only label (the game's sizes)",
    "BarLabel": "a size-only label (the game's sizes)",
}
BASES = {
    "GoButton": "Button", "GoPrimaryButton": "Button", "GoDangerButton": "Button", "GoSuccessButton": "Button",
    "GoToggleButton": "Button", "GoKeycap": "Button",
    "GoCard": "PanelContainer", "GoInsetPanel": "PanelContainer", "GoKeycapPanel": "PanelContainer",
    "GoRibbon": "PanelContainer", "GoRibbonRed": "PanelContainer", "GoNotice": "PanelContainer",
    "GoTitle": "Label", "GoOutlineLabel": "Label",
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

    def box(bid, bg, radius, border, border_color=INK, shadow=False, margin_h=14.0, margin_v=8.0, bottom=None,
            outer=None):
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
        boxes[bid] = ("StyleBoxFlat", lines)
        return bid

    boxes["painted_empty"] = ("StyleBoxEmpty", [])
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
    gloss("GoPrimaryButton", "btn_blue.png")
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

    # ── 🔽 The dropdown (`_dropdown`): a white, ink-rimmed box and a matching list. ──
    drop_box = box("painted_dropdown", WHITE, 10, 3, INK, margin_h=12.0, margin_v=(6.0, 6.0), bottom=5)
    down = box("painted_dropdown_pressed", DIFF_BG, 10, 3, INK, margin_h=12.0, margin_v=(6.0, 6.0), bottom=5)
    for state in ("normal", "hover", "focus"):
        put("OptionButton/styles/%s" % state, drop_box)
    put("OptionButton/styles/pressed", down)
    put("OptionButton/styles/hover_pressed", down)
    for slot in FONT_STATES:
        setT("OptionButton/colors/%s" % slot, C(INK))
    setT("OptionButton/font_sizes/font_size", DROPDOWN_FONT_SIZE)
    # The arcade outlined the white label of its painted dropdown; ink on the white box takes no outline. The game
    # leaves the disabled dropdown to the engine: here it is the same white box, its label the muted ink.
    setT("OptionButton/constants/outline_size", 0)
    put("OptionButton/styles/disabled", drop_box)
    setT("OptionButton/colors/font_disabled_color", C(pal["muted"]))
    put("PopupMenu/styles/panel", box("painted_list", WHITE, 12, 3, INK, shadow=True, margin_h=6.0, margin_v=(6.0, 6.0)))
    put("PopupMenu/styles/hover", box("painted_list_hover", DIFF_SELECTED, 8, 0, INK, margin_h=6.0,
                                      margin_v=(4.0, 4.0)))
    setT("PopupMenu/colors/font_color", C(INK))
    setT("PopupMenu/colors/font_hover_color", C(INK))
    setT("PopupMenu/font_sizes/font_size", DROPDOWN_FONT_SIZE)
    setT("PopupMenu/constants/v_separation", 10)

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
    return "painted_" + file[:-len(".png")]


def ext_resources(boxes):
    """The `[ext_resource]` lines the sprite boxes need — the script, then each texture once, in name order."""
    if not any(body[:1] == ['script = ExtResource("sprite")'] for _, body in boxes.values()):
        return []
    files = sorted({line.split('ExtResource("')[1].split('"')[0] for _, body in boxes.values() for line in body
                    if line.startswith("texture = ExtResource(\"painted_")})
    lines = ['[ext_resource type="Script" path="%s" id="sprite"]' % SPRITE_SCRIPT]
    for rid in files:
        lines.append('[ext_resource type="Texture2D" path="%s%s.png" id="%s"]' % (PAINTED, rid[len("painted_"):], rid))
    return lines


def write_map():
    """`tools/arcade_painted_map.json` — the game's names for the variations above (generated, do not edit)."""
    sizes = {"GoButton": GLOSS_FONT_SIZE, "GoPrimaryButton": GLOSS_FONT_SIZE, "GoDangerButton": GLOSS_FONT_SIZE,
             "GoSuccessButton": GLOSS_FONT_SIZE, "GoToggleButton": GLOSS_FONT_SIZE, "GoKeycap": KEYCAP_FONT_SIZE,
             "GoTitle": TITLE_FONT_SIZE, "OptionButton": DROPDOWN_FONT_SIZE, "PopupMenu": DROPDOWN_FONT_SIZE}
    body = {"_help": "Generated by tools/theme_arcade_painted.py — do not edit by hand. Magnet Mayhem's UiTheme "
                     "variation name → the gohud_arcade_light variation that carries exactly its items and values. "
                     "The game builds its theme as duplicate(arcade_light) plus these names as aliases. game_only "
                     "lists the game's variations that stay in the game (why in _game_only_why).",
            "_font_sizes": {"_help": "No font is written. The font sizes written are the game's literal ones (no Cfg "
                                     "size); a Cfg-driven size is left to the game.",
                            "written": sizes, "left_to_game": []},
            "_base_types": {"_help": "Base types this shape styles as the game does (the game pins base types itself).",
                            "types": ["Label", "OptionButton", "PopupMenu"]}}
    body.update(MAP)
    body["game_only"] = sorted(GAME_ONLY)
    body["_game_only_why"] = dict(sorted(GAME_ONLY.items()))
    with open(MAP_PATH, "w", encoding="utf-8") as fh:
        json.dump(body, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
