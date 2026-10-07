# -*- coding: utf-8 -*-
"""The arcade cabinet — what `shape.kind = "arcade"` draws for `tools/make_theme.py`.

    python3 addons/gohud/tools/make_theme.py arcade_light arcade_dark

The palettes (`themes/palettes/arcade_*.json`) carry the colours; this file carries the **shapes** of a look made like
a bright arcade game's menus: every button painted in its own colour with a gradient (light on top, deeper below), a
thick dark ink outline, a deeper lip under the body and a candy gloss (`GoStyleBoxArcade.gloss`); panels are
thick **boards** — a coloured frame round a pale well; labels on a painted key are white with an ink outline. The
code-drawn parts (slots, chips, badges, the joystick, the window's title banner) are `themes/skins/go_skin_arcade.gd`.

🎨 **Every family of buttons has its own paint**, taken from the palette's bright fills so the skin and the theme
   agree: the primary key `go` (green — the success fill), the normal key `blue` (the accent fill), the small keys and
   the tabs not chosen `lavender` (the secondary colour lightened), the danger key `coral`, the solid danger key `red`
   (the danger fill), the window's title and the tooltips `gold` (the warning fill). List rows and fields are pale
   **key caps** with dark text.
🔑 **White text on a light paint reads through its outline.** WCAG's own note on 1.4.3 counts a letter's outline as
   part of the letter, so a painted key's label is measured as the better of its fill and its ink outline against
   every height of the gradient (`tools/check_contrast.py` does the same). `fit()` moves a paint until that holds —
   a light paint lighter (the ink carries it), a deep one deeper (the white carries it) — so a palette edit never
   leaves a key below the bar.
🛑 **No size changes.** The outline, the lip and the frame are drawn inside the control's rectangle and the content
   margins keep their sum (the label moves up by half the lip so it sits in the middle of the body) — a host that pins
   its own sizes sees the same minimum sizes.
🛑 The ink is the palette's `border` on a light page; on a dark page (where `border` has to be light enough to show as a
   line) it is the background, much deeper. Same rule: `GoSkinArcade.ink()`.
"""
import colorsys
import math
import re

# The ink outline of a key or a board, and of the small parts (rows, chips, tracks).
EDGE = 3
EDGE_SMALL = 2
# The lip under a key, a small key and a board; how far a pressed key sinks.
LIP = 4
LIP_SMALL = 3
PANEL_LIP = 4
PUSH = 3
# The strength of the white gloss (`GoStyleBoxArcade.shine` — the candy gloss's sheen, glints and dash).
GLOSS = 0.85
# A window board's frame (dp); a card's, a HUD card's and a menu's are thinner (the board table in `restyle`).
FRAME = 6
# The ink outline round a painted key's label (the engine's `outline_size`), and round a small key's.
TEXT_OUTLINE = 6
TEXT_OUTLINE_SMALL = 4
# The bar a painted label has to clear at every height of its key — the generator's 4.6, a hair over WCAG's 4.5.
NEED = 4.6
# A list row's corner (dp) — small enough for a table row's 4dp padding (the cell audit wants the outline plus 0.3 ×
# the corner inside that).
LIST_RADIUS = 6
# The pale well a board's content keeps round it, inside the frame (dp) — `GoStyleBoxArcade.WELL_ROOM`.
WELL_ROOM = 3
# The least saturation of the small keys' lavender — any less and the key reads grey, and every key is painted.
LAVENDER_SATURATION = 0.5
# 💊 The corner of a key — round enough that a key of a normal height reads as the pill of an arcade menu; and of a
# small key standing in a row (the compact keys, the tabs) — `GoSkinArcade.KEY_RADIUS_SMALL`. Under half a key's
# height, never a full 999: the cell audit reads a 999 corner as "the text needs 300dp of room".
KEY_RADIUS = 24
KEY_RADIUS_SMALL = 16
# The room between two keys standing in a row (dp): each is drawn half of it in from its cell — the tabs read as
# separate keys and no size changes (`GoSkinArcade.ROW_GAP`).
ROW_GAP = 4
# 🎚 A slider's groove and fill: this much padding above and below — a chunky track (10dp) that still sits inside the
# 20dp knob, so the slider's height is the knob's, as before.
SLIDER_PAD = 5

SHAPE = dict(
    kind="arcade",
    controls="arcade",
    radius=16,
    radius_small=10,
    radius_large=24,
)

WHITE = (1.0, 1.0, 1.0, 1.0)
BLACK = (0.0, 0.0, 0.0, 1.0)


def _mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (a[3],)


def _solid(c):
    return tuple(c[:3]) + (1.0,)


def _svg(c):
    return "#%02X%02X%02X" % tuple(int(round(max(0.0, min(1.0, v)) * 255)) for v in c[:3])


def _parse_color(text):
    nums = [float(x) for x in re.findall(r"-?[0-9]*\.?[0-9]+(?:e-?[0-9]+)?", text)]
    return tuple(nums + [1.0] * (4 - len(nums)))[:4]


def _fields(lines):
    out = {}
    for line in lines:
        key, _, value = line.partition(" = ")
        out[key] = value
    return out


def _luminance(c):
    def channel(v):
        v = max(0.0, min(1.0, v))
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * channel(c[0]) + 0.7152 * channel(c[1]) + 0.0722 * channel(c[2])


def _ratio(a, b):
    x, y = sorted((_luminance(a), _luminance(b)))
    return (y + 0.05) / (x + 0.05)


def night(pal):
    back = pal["background"]
    return (back[0] + back[1] + back[2]) / 3.0 < 0.5


def ink(pal):
    """The ink outline of every part — `GoSkinArcade.ink()` is the same rule."""
    if night(pal):
        return _solid(_mix(pal["background"], BLACK, 0.55))
    return _solid(pal["border"])


def tones(colour):
    """The light top, the bottom the gradient runs to and the lip of a key painted `colour` —
    `GoStyleBoxArcade.tones()` is the same rule."""
    solid = _solid(colour)
    return _mix(solid, WHITE, 0.18), _mix(solid, BLACK, 0.06), _mix(solid, BLACK, 0.3)


def label_ratio(back, line, label=WHITE):
    """How well a white label with an ink outline reads on `back`: the better of the two (WCAG 1.4.3's note)."""
    return max(_ratio(label, back), _ratio(line, back))


def worst_label(top, bottom, line, label=WHITE):
    """The weakest reading of the label anywhere down a gradient from `top` to `bottom`."""
    return min(label_ratio(_mix(top, bottom, t / 4.0), line, label) for t in range(5))


def fit(colour, line, label=WHITE):
    """`tones(colour)`, moved until a white, ink-outlined label clears NEED at every height. A paint the ink reads on
    better goes lighter; one the white reads on better goes deeper."""
    top, bottom, lip = tones(colour)
    if worst_label(top, bottom, line, label) >= NEED:
        return top, bottom, lip
    middle = _mix(top, bottom, 0.5)
    towards = WHITE if _ratio(line, middle) >= _ratio(label, middle) else BLACK
    for step in range(1, 40):
        t = step * 0.025
        top2, bottom2 = _mix(top, towards, t), _mix(bottom, towards, t)
        if worst_label(top2, bottom2, line, label) >= NEED:
            return top2, bottom2, _mix(lip, towards, t * 0.5)
    return top, bottom, lip


def _fill(T, key):
    """A fill colour the generator already wrote (`GoHud/colors/<key>_fill`) — the one the skin reads at run time."""
    for line in T:
        name, _, value = line.partition(" = ")
        if name == "GoHud/colors/%s" % key:
            return _parse_color(value)
    return None


def lavender_of(pal):
    """The lavender of the small keys and the tabs not chosen: the secondary colour lightened by day; at night (where
    the secondary colour is already pale) leaned towards the page; saturated to at least `LAVENDER_SATURATION` —
    `GoSkinArcade.lavender()` is the same rule."""
    if night(pal):
        mixed = _mix(_solid(pal["secondary"]), _solid(pal["background"]), 0.3)
    else:
        mixed = _mix(_solid(pal["secondary"]), WHITE, 0.42)
    h, s, v = colorsys.rgb_to_hsv(*mixed[:3])
    return colorsys.hsv_to_rgb(h, max(s, LAVENDER_SATURATION), v) + (1.0,)


def paints(pal, T):
    """The paint of each family of keys, from the palette's bright fills (see the module notes)."""
    surface = _solid(pal["surface"])
    go = _fill(T, "success_fill") or pal["success"]
    blue = _fill(T, "accent_fill") or pal["accent"]
    red = _fill(T, "danger_fill") or pal["danger"]
    gold = _fill(T, "warning_fill") or pal["warning"]
    lavender = lavender_of(pal)
    coral = _mix(_solid(red), WHITE, 0.32)
    return dict(go=_solid(go), blue=_solid(blue), red=_solid(red), gold=_solid(gold), lavender=lavender, coral=coral,
                cap=surface)


def controls(pal):
    """Switch, checkbox, radio, slider handle and arrows as arcade parts: an ink outline, a painted gradient and a
    white gloss. 🛑 The engine draws these as they are (no tint), so every colour is baked per theme — and the canvas
    keeps the size of the default family's drawings, so nothing that measures them moves."""
    line = _svg(ink(pal))
    surface = _solid(pal["surface"])
    go = _solid(pal.get("success_vivid", pal["success"]))
    blue = _solid(pal.get("accent_vivid", pal["accent"]))
    lavender = lavender_of(pal)
    off_track = _mix(lavender, WHITE, 0.25)
    cap_top, cap_bottom = _mix(surface, WHITE, 0.6), _mix(surface, _solid(pal["surface_high"]), 0.7)

    def grad(name, top, bottom):
        return ('<linearGradient id="%s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
                '<stop offset="1" stop-color="%s"/></linearGradient>') % (name, _svg(top), _svg(bottom))

    def wrap(w, h, defs, body, disabled=False):
        group = '<g opacity=".4">%s</g>' % body if disabled else body
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>%s</defs>%s'
                '</svg>') % (w, h, w, h, defs, group)

    def toggle(state_on, disabled, mirrored):
        knob_x = 27 if state_on != mirrored else 13
        paint = go if state_on else off_track
        top, bottom, _ = tones(paint)
        defs = grad("t", top, bottom) + grad("k", cap_top, cap_bottom)
        # A glint round each end of the track (the knob covers the one on its side) — the candy gloss of the keys.
        body = ('<rect x="1.5" y="2.5" width="37" height="19" rx="9.5" fill="url(#t)" stroke="%s" stroke-width="2.4"/>'
                '<path d="M6 7.4 Q7.5 5.2 11 5.2" fill="none" stroke="#FFFFFF" stroke-opacity=".8" stroke-width="1.6"'
                ' stroke-linecap="round"/>'
                '<path d="M34 7.4 Q32.5 5.2 29 5.2" fill="none" stroke="#FFFFFF" stroke-opacity=".8" stroke-width="1.6"'
                ' stroke-linecap="round"/>'
                '<circle cx="%d" cy="12" r="7.2" fill="url(#k)" stroke="%s" stroke-width="2.2"/>'
                '<path d="M%g 9.6 Q%g 8.2 %g 8.2" fill="none" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round"/>'
                ) % (line, knob_x, line, knob_x - 3.6, knob_x - 3.0, knob_x - 1.0)
        return wrap(40, 24, defs, body, disabled)

    def check(state_on, disabled):
        if state_on:
            top, bottom, _ = tones(go)
            defs = grad("c", top, bottom)
            body = ('<rect x="2" y="2" width="16" height="16" rx="4.5" fill="url(#c)" stroke="%s" stroke-width="2.2"/>'
                    '<path d="M5.6 10.2 8.6 13 14.4 6.8" fill="none" stroke="%s" stroke-width="4.2" '
                    'stroke-linecap="round" stroke-linejoin="round"/>'
                    '<path d="M5.6 10.2 8.6 13 14.4 6.8" fill="none" stroke="#FFFFFF" stroke-width="2.2" '
                    'stroke-linecap="round" stroke-linejoin="round"/>') % (line, line)
        else:
            defs = grad("c", cap_top, cap_bottom)
            body = ('<rect x="2" y="2" width="16" height="16" rx="4.5" fill="url(#c)" stroke="%s" stroke-width="2.2"/>'
                    '<path d="M5 6.4 Q5.6 4.8 7.6 4.8" fill="none" stroke="#FFFFFF" stroke-width="1.3" '
                    'stroke-linecap="round"/>') % line
        return wrap(20, 20, defs, body, disabled)

    def radio(state_on, disabled):
        defs = grad("r", cap_top, cap_bottom)
        body = '<circle cx="10" cy="10" r="7.8" fill="url(#r)" stroke="%s" stroke-width="2.2"/>' % line
        if state_on:
            top, bottom, _ = tones(blue)
            defs += grad("d", top, bottom)
            body += '<circle cx="10" cy="10" r="4" fill="url(#d)" stroke="%s" stroke-width="1.4"/>' % line
        return wrap(20, 20, defs, body, disabled)

    def grabber(r, faded=False, lit=False):
        """The knob of an arcade slider: a white cap in a thick painted ring, outlined in ink, a glint on the ring —
        the handle of an arcade game's settings. Held or hovered (`lit`) the ring is a little larger and lighter."""
        ring_top, ring_bottom, _ = tones(_mix(blue, WHITE, 0.15) if lit else blue)
        defs = grad("g", cap_top, cap_bottom) + grad("b", ring_top, ring_bottom)
        inner = r * 0.56
        body = ('<circle cx="10" cy="10" r="%g" fill="url(#b)" stroke="%s" stroke-width="1.8"/>'
                '<circle cx="10" cy="10" r="%g" fill="url(#g)" stroke="%s" stroke-opacity=".55" stroke-width="1"/>'
                '<path d="M%g %g A%g %g 0 0 1 %g %g" fill="none" stroke="#FFFFFF" stroke-opacity=".85" '
                'stroke-width="1.3" stroke-linecap="round"/>'
                ) % (r, line, inner, _svg(ring_bottom), 10 - r * 0.72, 10 - r * 0.2, r * 0.76, r * 0.76,
                     10 - r * 0.2, 10 - r * 0.72)
        return wrap(20, 20, defs, body, faded)

    def arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>'
                ) % (line, path)

    out = {}
    for state_on in (True, False):
        for disabled in (False, True):
            for mirrored in (False, True):
                name = "toggle_%s%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "",
                                          "_mirrored" if mirrored else "")
                out[name] = toggle(state_on, disabled, mirrored)
        for disabled in (False, True):
            out["check_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = check(state_on, disabled)
            out["radio_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = radio(state_on, disabled)
    out["grabber"] = grabber(8.6)
    out["grabber_highlight"] = grabber(9.2, lit=True)
    out["grabber_disabled"] = grabber(7.5, faded=True)
    out["arrow_down"] = arrow("M4 6l4 4 4-4")
    out["arrow_right"] = arrow("M6 4l4 4-4 4")
    out["arrow_left"] = arrow("M10 4 6 8l4 4")
    return out


def _board_pad(margins, frame, lip, corner, edge=EDGE):
    """The least padding of each side of a board (left, top, right, bottom): the ink, the frame and `WELL_ROOM` — and at
    the bottom the lip. A board with no padding (a window's card, which pads its content itself) keeps none.
    🛑 At least the ink and the frame plus 0.3 × the corner, too: as a flat face (`GoStyleBoxArcade.to_flat()`, what
    `GoStyle.floating()` hands a HUD card) the frame is the border, and the layout audit wants the text that far in."""
    if not margins or min(margins) <= 0:
        return None
    side = math.ceil(edge + frame + max(WELL_ROOM, 0.3 * corner))
    return [side, side, side, side + lip]


def restyle(pal, consts, boxes, T, flat, C, contrast):
    """Turn the boxes `build()` made into arcade keys and boards, and the labels on painted keys white with an ink
    outline. `flat`, `C` and `contrast` are the generator's StyleBoxFlat writer, colour formatter and WCAG ratio."""
    line = ink(pal)
    dark = night(pal)
    paint = paints(pal, T)
    surface = _solid(pal["surface"])
    high = _solid(pal["surface_high"])
    soft = _solid(pal["surface_soft"])

    def field(bid):
        return _fields(boxes[bid][1]) if bid in boxes and boxes[bid][0] == "StyleBoxFlat" else None

    def margins(f):
        return [float(f.get("content_margin_%s" % side, "-1")) for side in ("left", "top", "right", "bottom")]

    def key(bid, colours=None, lip=LIP, edge=EDGE, radius=None, pressed=False, sunken=False, shine=GLOSS,
            centre=True, edge_colour=None, glow=None, frame=0, frame_colours=None, well=None, ring=None, solid=False,
            pad=None, apart=False):
        """Reshape box `bid` into an arcade face. `colours` is (top, bottom, lip) — a painted key; `well` (top, bottom)
        is the pale inside of a board whose frame is `frame` wide in `frame_colours`; `sunken` turns it in (a field);
        `ring` makes it an outline only (a focus ring) of that colour, sitting just inside the ink; `glow` a halo of
        that colour round a raised key. `centre` moves the label up by half the lip so it sits in the middle. `solid`
        fills a face `build()` left hollow (a tab not chosen is a painted key here). `pad` (left, top, right, bottom) raises
        each side's padding to at least that much (room for a thick frame). `apart` draws the face `ROW_GAP` / 2 in from
        each side of its cell — a key standing in a row with others (a tab)."""
        f = field(bid)
        if f is None:
            return
        m = margins(f)
        if pad is not None and all(v >= 0 for v in m):
            m = [max(v, least) for v, least in zip(m, pad)]
        corner = radius if radius is not None else int(f.get("corner_radius_top_left", consts["radius"]))
        lines = ['script = ExtResource("arcade")']
        if all(v >= 0 for v in m):
            move = 0.0
            if centre and not sunken and ring is None and frame == 0:
                move = -lip / 2.0
                if pressed:
                    move += min(lip - 1, PUSH)
            top, bottom = m[1] + move, m[3] - move
            if top < 0 or bottom < 0:
                top, bottom = m[1], m[3]
            lines += ["content_margin_left = %g" % m[0], "content_margin_top = %g" % top,
                      "content_margin_right = %g" % m[2], "content_margin_bottom = %g" % bottom]
        else:
            # 🛑 A StyleBoxFlat with no padding of its own pads by its border; a GDScript StyleBox pads by nothing.
            for side in ("left", "top", "right", "bottom"):
                lines.append("content_margin_%s = %s" % (side, f.get("border_width_%s" % side, "0")))
        for side in ("left", "top", "right", "bottom"):
            if apart and side in ("left", "right"):
                lines.append("expand_margin_%s = %g" % (side, -ROW_GAP / 2.0))
            elif "expand_margin_%s" % side in f:
                lines.append("expand_margin_%s = %s" % (side, f["expand_margin_%s" % side]))
        if ring is not None:
            # A ring just inside the ink of the face under it, so the key keeps its outline.
            lines += ["bg_color = %s" % C(ring[:3] + (0.0,)), "draw_center = false", "border_color = %s" % C(ring),
                      "border_width = %g" % edge, "lip = 0", "shine = 0", "radius = %g" % max(0, corner - EDGE)]
            for side in ("left", "top", "right", "bottom"):
                lines.append("expand_margin_%s = %g" % (side, -EDGE))
            boxes[bid] = ("StyleBox", lines)
            return
        body = colours
        if body is None:
            fill = _parse_color(f["bg_color"]) if "bg_color" in f else surface
            body = (fill, None, None)
        alpha = body[0][3] if len(body[0]) > 3 else 1.0
        if well is not None:
            lines.append("bg_color = %s" % C(well[0][:3] + (alpha,)))
            lines.append("bottom_color = %s" % C(_solid(well[1])))
        else:
            lines.append("bg_color = %s" % C(body[0][:3] + (alpha,)))
            if body[1] is not None:
                lines.append("bottom_color = %s" % C(_solid(body[1])))
        if frame and frame_colours is not None:
            lines += ["frame = %g" % frame, "frame_color = %s" % C(_solid(frame_colours[0])),
                      "frame_bottom = %s" % C(_solid(frame_colours[1])),
                      "shade_color = %s" % C(_solid(frame_colours[2])),
                      "inner_line = %s" % C(line), "line_width = 2"]
        elif body[2] is not None:
            lines.append("shade_color = %s" % C(_solid(body[2])))
        lines += ["border_color = %s" % C(edge_colour or line), "border_width = %g" % edge, "band = 0",
                  "shine = %g" % (0 if sunken else shine)]
        if sunken:
            lines += ["lip = 0", "sunken = true"]
        else:
            lines.append("lip = %g" % lip)
            if pressed:
                lines += ["pressed = true", "sink = %g" % PUSH]
        lines.append("radius = %g" % corner)
        if f.get("draw_center") == "false" and not solid:
            lines.append("draw_center = false")
        if glow is not None:
            lines += ["shadow_color = %s" % C(glow), "shadow_size = 4", "shadow_offset = Vector2(0, 0)"]
        elif "shadow_color" in f and "shadow_size" in f:
            lines += ["shadow_color = %s" % f["shadow_color"], "shadow_size = %s" % f["shadow_size"]]
            if "shadow_offset" in f:
                lines.append("shadow_offset = %s" % f["shadow_offset"])
        boxes[bid] = ("StyleBox", lines)

    def twin(source, bid):
        """A copy of box `source` under a new id — a state `build()` shares with another that this look draws apart."""
        if source in boxes:
            boxes[bid] = (boxes[source][0], list(boxes[source][1]))

    def put(key_name, bid):
        T[:] = [entry for entry in T if entry.split(" = ")[0] != key_name]
        T.append('%s = SubResource("%s")' % (key_name, bid))

    def setT(key_name, value):
        T[:] = [entry for entry in T if entry.split(" = ")[0] != key_name]
        T.append("%s = %s" % (key_name, value))

    # 🔑 The paint of each family, fitted so a white label with an ink outline clears the bar at every height.
    fitted = {}
    for name, colour in paint.items():
        if name == "cap":
            continue
        fitted[name] = fit(colour, line)
        fitted[name + "_hover"] = fit(_mix(colour, WHITE, 0.1), line)
        fitted[name + "_down"] = fit(_mix(colour, BLACK, 0.06), line)
    # A key cap — a row, a field, a fold title: pale, dark text on it, no outline round the text.
    # 🛑 At night a cap is the raised surface, not a pale one — the light text of the night look sits on it.
    cap_top = _mix(high, WHITE, 0.06) if dark else _mix(surface, WHITE, 0.5)
    cap_bottom = _mix(surface, high, 0.5) if dark else _mix(surface, high, 0.55)
    cap = (cap_top, cap_bottom, _mix(cap_bottom, line, 0.32))
    lift = WHITE if not dark else _mix(high, WHITE, 0.25)
    cap_hover = (_mix(cap_top, high if not dark else lift, 0.35), _mix(cap_bottom, high if not dark else lift, 0.3), cap[2])
    # Disabled — a grey key, its ink faded.
    grey = _mix(surface, _solid(pal["muted"]), 0.28 if not dark else 0.12)
    disabled = (_mix(grey, WHITE, 0.12 if not dark else 0.04), grey, _mix(grey, line, 0.2))
    faint = line[:3] + (0.45,)
    gold = _solid(paint["gold"])

    # States `build()` draws with another state's face that this look tells apart.
    twin("btn_danger_hover", "btn_danger_pressed")
    twin("compact_hover", "compact_pressed")
    twin("compact_normal", "compact_disabled")
    twin("list_normal", "list_disabled")
    for name in ("GoDangerButton/styles/pressed", "GoDangerButton/styles/hover_pressed"):
        put(name, "btn_danger_pressed")
    for name in ("GoCompactButton/styles/pressed", "GoCompactButton/styles/hover_pressed"):
        put(name, "compact_pressed")
    put("GoCompactButton/styles/disabled", "compact_disabled")
    put("GoListButton/styles/disabled", "list_disabled")

    R, RS = consts["radius"], consts["radius_small"]
    # ── Keys — every family painted, a lip under it; a press sinks it. ──
    families = [("btn", "blue"), ("btn_primary", "go"), ("btn_danger", "coral"), ("btn_danger_solid", "red")]
    for prefix, name in families:
        normal = "btn_normal" if prefix == "btn" else prefix
        key(normal, fitted[name], radius=KEY_RADIUS)
        key(prefix + "_hover", fitted[name + "_hover"], radius=KEY_RADIUS)
        key(prefix + "_pressed", fitted[name + "_down"], pressed=True, radius=KEY_RADIUS)
    # The raised twins (`GoConfig.button_glow`, `GoStyle.glow()`) wear a gold halo — the chosen stage of a level map.
    for prefix, name in (("btn_primary_glow", "go"), ("btn_danger_solid_glow", "red")):
        key(prefix, fitted[name], glow=gold, radius=KEY_RADIUS)
        key(prefix + "_hover", fitted[name + "_hover"], glow=gold, radius=KEY_RADIUS)
        key(prefix + "_pressed", fitted[name + "_down"], pressed=True, glow=gold, radius=KEY_RADIUS)
    key("btn_disabled", disabled, lip=LIP_SMALL, shine=0, edge_colour=faint, radius=KEY_RADIUS)
    # The focus rings — just inside the ink, white on a deep paint and ink on a light one, so the ring stands off
    # the key it is on (3:1). Each painted family gets its own.
    def ring_on(name):
        top = fitted[name][0]
        return WHITE if _ratio(WHITE, top) >= 3.0 else line
    rings = (("btn_focus", "blue"), ("focus_go", "go"), ("focus_red", "red"), ("focus_coral", "coral"))
    for bid, _ in rings:
        if bid != "btn_focus":
            twin("btn_focus", bid)
    for bid, name in rings:
        key(bid, ring=ring_on(name), radius=KEY_RADIUS)
    put("GoPrimaryButton/styles/focus", "focus_go")
    put("GoDangerSolidButton/styles/focus", "focus_red")
    put("GoDangerButton/styles/focus", "focus_coral")
    key("btn_focus_on_fill", ring=ring_on("go"), radius=KEY_RADIUS)
    key("focus_soft", ring=gold if not dark else WHITE, edge=EDGE_SMALL)
    # The small keys — lavender, a smaller lip.
    KS = KEY_RADIUS_SMALL
    key("compact_normal", fitted["lavender"], lip=LIP_SMALL, edge=EDGE_SMALL, radius=KS)
    key("compact_hover", fitted["lavender_hover"], lip=LIP_SMALL, edge=EDGE_SMALL, radius=KS)
    key("compact_pressed", fitted["lavender_down"], lip=LIP_SMALL, edge=EDGE_SMALL, radius=KS, pressed=True)
    key("compact_disabled", disabled, lip=LIP_SMALL, edge=EDGE_SMALL, radius=KS, shine=0, edge_colour=faint)
    # List rows — key caps stacked in a column.
    key("list_normal", cap, lip=LIP_SMALL, edge=EDGE_SMALL, radius=LIST_RADIUS, shine=0.6)
    key("list_hover", cap_hover, lip=LIP_SMALL, edge=EDGE_SMALL, radius=LIST_RADIUS, shine=0.6)
    key("list_disabled", (cap[0], cap[1], cap[2]), lip=LIP_SMALL, edge=EDGE_SMALL, radius=LIST_RADIUS, shine=0,
        edge_colour=faint)
    # The menu's hovered item — a pale sky cap under dark text.
    sky = _mix(paint["blue"], WHITE, 0.72) if not dark else _mix(paint["blue"], surface, 0.62)
    key("menu_hover", (sky, _mix(sky, paint["blue"], 0.12), _mix(sky, line, 0.3)), lip=0, edge=EDGE_SMALL, radius=RS,
        shine=0.5, centre=False)

    # ── Boards — a coloured frame round a pale well, a lip under the frame. Padding stays. ──
    sky_board = (_mix(paint["blue"], WHITE, 0.55), _mix(paint["blue"], WHITE, 0.3), _mix(paint["blue"], line, 0.25))
    blue_board = (_mix(paint["blue"], WHITE, 0.12), paint["blue"], _mix(paint["blue"], line, 0.35))
    if dark:
        sky_board = (_mix(paint["blue"], WHITE, 0.08), _mix(paint["blue"], BLACK, 0.12), _mix(paint["blue"], line, 0.45))
        blue_board = sky_board
    # 🔑 The padding grows to hold the ink, the frame, the lip and a little well round the content — a HUD card's from
    #    8dp to 12 (15 at the bottom), a card's bottom from 12 to 15 — so text never touches the well's ink line.
    for bid, frame_paint, size, lip in (("panel", sky_board, FRAME, PANEL_LIP), ("panel_solid", blue_board, 5, PANEL_LIP),
                                        ("card", blue_board, 4, 3), ("popup", sky_board, 3, 3),
                                        ("hud", blue_board, 4, 3), ("notice", sky_board, 3, 3)):
        g = field(bid)
        if g is None:
            continue
        fill = _parse_color(g["bg_color"]) if "bg_color" in g else surface
        under = _mix(_solid(fill), high, 0.45)
        corner = consts["radius_large"] if bid == "panel" else int(g.get("corner_radius_top_left", consts["radius"]))
        key(bid, (fill, None, None), lip=lip, centre=False, frame=size, frame_colours=frame_paint, well=(fill, under),
            shine=0.7, pad=_board_pad(margins(g), size, lip, corner), radius=corner)
    key("tooltip", (_mix(gold, WHITE, 0.55), _mix(gold, WHITE, 0.35), _mix(gold, line, 0.3)), lip=0, edge=EDGE_SMALL,
        centre=False, shine=0)

    # ── Text fields — a white well turned in, the ink round it; focused, the ink turns the accent. ──
    well_shadow = _mix(surface, line, 0.12)
    key("edit_normal", (surface, _mix(surface, soft, 0.6), well_shadow), sunken=True, radius=RS, edge=EDGE_SMALL + 0.5)
    key("edit_focus", (surface, _mix(surface, soft, 0.6), _mix(surface, paint["blue"], 0.3)), sunken=True, radius=RS,
        edge=EDGE, edge_colour=_solid(pal["accent"]))

    # ── Tabs — separate painted keys standing apart in their row: the chosen one blue, the others lavender. ──
    key("tab_selected", fitted["blue"], lip=LIP_SMALL, edge=EDGE_SMALL + 0.5, radius=KS, apart=True)
    key("tab_unselected", fitted["lavender"], lip=LIP_SMALL, edge=EDGE_SMALL + 0.5, radius=KS, solid=True, apart=True)
    key("tab_hovered", fitted["lavender_hover"], lip=LIP_SMALL, edge=EDGE_SMALL + 0.5, radius=KS, solid=True,
        apart=True)

    # ── Folding sections — the title is a key cap; its body stays the generator's soft panel. ──
    for bid in ("fold_title", "fold_title_collapsed"):
        key(bid, cap, lip=LIP_SMALL, edge=EDGE_SMALL, shine=0.6)
    for bid in ("fold_title_hover", "fold_title_collapsed_hover"):
        key(bid, cap_hover, lip=LIP_SMALL, edge=EDGE_SMALL, shine=0.6)

    # ── Bars and sliders — an ink groove; the fill a painted tube with a gloss. 🛑 No bottom colour on a fill: the
    #    run time tints `bg_color` (`GoSkin.progress_fill_box`) and the gradient follows it. ──
    for bid in ("bar_bg", "slider_track"):
        g = field(bid)
        if g is None or "bg_color" not in g:
            continue
        groove = _parse_color(g["bg_color"])
        key(bid, (groove, _mix(_solid(groove), line, 0.08), _mix(_solid(groove), line, 0.25)), sunken=True,
            edge=EDGE_SMALL, radius=RS if bid == "bar_bg" else SLIDER_PAD, centre=False,
            pad=None if bid == "bar_bg" else [0, SLIDER_PAD, 0, SLIDER_PAD])
    for bid in ("bar_fill", "slider_grab", "slider_grab_hover"):
        g = field(bid)
        if g is None or "bg_color" not in g:
            continue
        colour = _parse_color(g["bg_color"]) if bid == "bar_fill" else paint["blue"]
        # A bar's or a slider's fill is a tube with its own ink line, so where it ends reads at a glance whatever its
        # colour — and the slider's fill lies in its groove instead of over it.
        key(bid, (colour, None, None), lip=0, edge=EDGE_SMALL,
            radius=RS if bid == "bar_fill" else SLIDER_PAD, centre=False, shine=0.75,
            pad=None if bid == "bar_fill" else [0, SLIDER_PAD, 0, SLIDER_PAD])
    for bid in ("scroll_grab", "scroll_grab_hover"):
        if field(bid) is not None:
            key(bid, (fitted["lavender"][0], fitted["lavender"][1], fitted["lavender"][2]), lip=0, edge=EDGE_SMALL - 0.5,
                centre=False, shine=0)

    # ── Labels — white with an ink outline on every painted key; dark text on the key caps. ──
    # 🔑 What `Button` said before it turned white — the parts that inherit it and sit on a cap or the page take it back.
    before = {}
    for entry in T:
        name, _, value = entry.partition(" = ")
        if name.startswith("Button/colors/"):
            before[name[len("Button/colors/"):]] = value
    white = C(WHITE)
    # A disabled label is a pale grey, still outlined — it reads, and it reads as off. 🛑 By day not a mid grey: inside
    #    its ink outline on the grey key it closed up into a blot ("Busy", the disabled keys).
    dim = C(_mix(_solid(pal["muted"]), WHITE, 0.78) if not dark else _mix(_solid(pal["text"]), BLACK, 0.22))
    hex_ink = C(line)
    states = ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color")
    icons = ("icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color",
             "icon_focus_color")
    # A light paint carries its icons in ink, a deep one in white (an icon has no outline to read through).
    painted = [("Button", "blue", TEXT_OUTLINE), ("OptionButton", "blue", TEXT_OUTLINE),
               ("GoPrimaryButton", "go", TEXT_OUTLINE), ("GoDangerButton", "coral", TEXT_OUTLINE),
               ("GoDangerSolidButton", "red", TEXT_OUTLINE), ("GoCompactButton", "lavender", TEXT_OUTLINE_SMALL)]
    for type_name, name, size in painted:
        for slot in states:
            setT("%s/colors/%s" % (type_name, slot), white)
        setT("%s/colors/font_disabled_color" % type_name, dim)
        setT("%s/colors/font_outline_color" % type_name, hex_ink)
        setT("%s/constants/outline_size" % type_name, size)
        middle = _mix(fitted[name][0], fitted[name][1], 0.5)
        icon = white if _ratio(WHITE, middle) >= _ratio(line, middle) else hex_ink
        for slot in icons:
            setT("%s/colors/%s" % (type_name, slot), icon)
        setT("%s/colors/icon_disabled_color" % type_name, C(_mix(surface, WHITE, 0.2)[:3] + (0.8,)))
    # The tabs are painted keys too.
    for kind in ("TabBar", "TabContainer"):
        for slot in ("font_selected_color", "font_unselected_color", "font_hovered_color"):
            setT("%s/colors/%s" % (kind, slot), white)
        setT("%s/colors/font_disabled_color" % kind, dim)
        setT("%s/colors/font_outline_color" % kind, hex_ink)
        setT("%s/constants/outline_size" % kind, TEXT_OUTLINE_SMALL)
        for slot in ("icon_selected_color", "icon_unselected_color", "icon_hovered_color"):
            setT("%s/colors/%s" % (kind, slot), white)
    # 🛑 The parts that inherit `Button` but sit on a key cap, on the page or on nothing take dark text back, and no
    #    outline — `Button`'s white would vanish on them, and an ink outline round ink text only thickens it.
    text, muted, accent = C(pal["text"]), C(pal["muted"]), C(pal["accent"])
    for type_name in ("GoListButton", "GoBareButton", "GoIconButton", "CheckBox", "CheckButton"):
        setT("%s/constants/outline_size" % type_name, 0)
        own = set(entry.split(" = ")[0] for entry in T)
        for slot in states + ("font_disabled_color",) + icons + ("icon_disabled_color",):
            if "%s/colors/%s" % (type_name, slot) not in own and slot in before:
                setT("%s/colors/%s" % (type_name, slot), before[slot])
    # The tooltip is a pale gold note — its text is the ink.
    setT("TooltipLabel/colors/font_color", hex_ink)
    for type_name in ("GoListButton", "GoBareButton", "GoIconButton"):
        for slot in ("font_color", "font_hover_color", "font_focus_color"):
            setT("%s/colors/%s" % (type_name, slot), text)
        setT("%s/colors/font_disabled_color" % type_name, muted)
    for type_name in ("GoBareButton", "GoIconButton"):
        for slot in ("font_pressed_color", "font_hover_pressed_color"):
            setT("%s/colors/%s" % (type_name, slot), accent)
    for slot in ("icon_normal_color", "icon_focus_color"):
        setT("GoListButton/colors/%s" % slot, C(pal["secondary"]))
    for slot in ("icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"):
        setT("GoListButton/colors/%s" % slot, text)
    setT("GoBareButton/colors/icon_normal_color", C(pal["secondary"]))
    setT("GoBareButton/colors/icon_hover_color", text)
    # 🛑 At night a row is a raised dark cap: its pressed and disabled labels are the light text, a little dimmed when
    #    disabled (the accent the generator gave a pressed row was measured for its own flat row, 3.4:1 on the cap).
    if dark:
        for slot in ("font_pressed_color", "font_hover_pressed_color"):
            setT("GoListButton/colors/%s" % slot, text)
        setT("GoListButton/colors/font_disabled_color", C(_mix(_solid(pal["text"]), _solid(pal["muted"]), 0.5)))
