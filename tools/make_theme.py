# -*- coding: utf-8 -*-
"""Generator for the gohud built-in themes (.tres) and their per-theme control artwork (SVG).

    python3 addons/gohud/tools/make_theme.py          # rebuilds themes/*.tres and assets/<theme>/*.svg

Written by hand, changing one colour would mean editing dozens of places, so everything is
computed from a palette and exported. The key point is that the dark and the light theme carry
**the same token names** — that is what lets you swap one for the other and have the widget code
keep working untouched.

🛑 Toggles, checkboxes, slider grabbers and dropdown/fold arrows are **drawn separately per theme.**
   The engine does not tint these theme icons; it draws them exactly as they are — share one white
   drawing between both themes and the light theme gets a white toggle on a white ground, invisible
   (found 2026-09-12).
🛑 Every new SVG ships with its DPITexture import settings (.import) — it is re-rasterised when the
   UI scale grows. Existing .import files are left alone (to preserve the uid the editor wrote).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
RES = "res://addons/gohud"


def hexc(h, a=1.0):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (round(r, 6), round(g, 6), round(b, 6), round(a, 6))


def C(c):
    return "Color(%g, %g, %g, %g)" % c


def mix(c1, c2, t):
    return tuple(round(c1[i] + (c2[i] - c1[i]) * t, 6) for i in range(4))


def alpha(c, a):
    return (c[0], c[1], c[2], round(a, 6))


def svg_hex(c):
    return "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c[:3])


# ── Contrast correction ─────────────────────────────────────────────────
#
# 🛑 **Accent-coloured text over a pale tint of that same accent is always hard to read.** A pressed
#    button (accent-tinted panel + accent text) and a danger button (danger tint + danger text) are
#    exactly that — the colour is pretty, but two shades of one hue leave no difference in lightness.
#    Hand-picking a palette walks into this trap every time, so **the ink is pushed away from its
#    background automatically.** That way contrast follows along when only the palette changes.

def _linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(c):
    return 0.2126 * _linear(c[0]) + 0.7152 * _linear(c[1]) + 0.0722 * _linear(c[2])


def contrast(front, back):
    a, b = luminance(front), luminance(back)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def flatten(top, bottom):
    """Composite alpha over the colour underneath to get **the colour actually seen**."""
    a = top[3]
    if a >= 1.0:
        return top
    return tuple(top[i] * a + bottom[i] * (1.0 - a) for i in range(3)) + (1.0,)


def readable_everywhere(ink, backs, need=4.6, rounds=6):
    """Push `ink` past `need` on **every one of the given backgrounds**.

    🛑 Pushing one background at a time satisfies only the last one — a colour brightened for a dark
       surface collapses again on a light one. So **the worst background is found again each round**
       and the push goes that way.
    """
    out = ink
    for _round in range(rounds):
        worst = min(backs, key=lambda b: contrast(flatten(out, b), b))
        if contrast(flatten(out, worst), worst) >= need:
            break
        out = readable(out, worst, need)
    return out


def fill_color(base, track, need=3.0, vivid=None):
    """For bar fills — a vivid colour that stands out **on the bar's track**.

    Unlike text this needs 3:1 rather than 4.5 (it is an area, not writing). In exchange **the
    saturation goes up** so it does not sink into grey — merely brightening a dark colour muddies it.

    🛑 **Some colours cannot be made to meet the ratio by colour alone.** Yellow is inherently bright,
       so it never reaches 3:1 over any grey track, and darkening it to meet the bar turns the
       experience bar **brown** (it really was `#A05000` in the light theme — 2026-09-13). Such themes
       supply a fill-only pure colour through `*_vivid`, and the boundary is carried by the **outline**
       `GoSkin._edge_fill` draws.
    """
    import colorsys
    if vivid is not None:
        h, l, s = colorsys.rgb_to_hls(vivid[0], vivid[1], vivid[2])
        r, g, b = colorsys.hls_to_rgb(h, l, min(1.0, s * 1.1 + 0.04))
        return (round(r, 6), round(g, 6), round(b, 6), 1.0)
    h, l, s = colorsys.rgb_to_hls(base[0], base[1], base[2])
    s = min(1.0, s * 1.25 + 0.06)
    best = None
    for i in range(0, 90):
        nl = min(0.72, l + 0.01 * i)
        r, g, b = colorsys.hls_to_rgb(h, nl, s)
        cand = (round(r, 6), round(g, 6), round(b, 6), 1.0)
        if best is None:
            best = cand
        if contrast(cand, track) >= need:
            return cand
        best = cand
    return best


def readable(ink, back, need=4.5, limit=0.9):
    """Push `ink` until it passes `need` over `back` — keep the hue, move **only the lightness**.

    It darkens over a light background and brightens over a dark one. If it still fails at `limit` it
    stops there (jumping to black or white here would wipe out the character of the palette — readable
    or not, that counts as a failure).
    """
    flat = flatten(ink, back)
    if contrast(flat, back) >= need:
        return ink
    darken = luminance(back) > 0.22
    import colorsys
    h, l, s = colorsys.rgb_to_hls(flat[0], flat[1], flat[2])
    step = -0.01 if darken else 0.01
    for i in range(1, 100):
        nl = min(limit, max(1.0 - limit, l + step * i))
        r, g, b = colorsys.hls_to_rgb(h, nl, s)
        if contrast((r, g, b, 1.0), back) >= need:
            return (round(r, 6), round(g, 6), round(b, 6), 1.0)
    return ink


DARK = dict(
    background=hexc("0E1117"), surface=hexc("1C222D"), surface_soft=hexc("282F3D"),
    surface_high=hexc("313B4C"), border=hexc("4B5A70", 0.85), text=hexc("F2F5F9"),
    secondary=hexc("A8B3C2"), muted=hexc("919BAC"), accent=hexc("56CCF2"),
    on_accent=hexc("0B1016"), success=hexc("5FD9A6"), warning=hexc("F5C563"),
    danger=hexc("F27272"), info=hexc("7EA6FF"), scrim=hexc("000000", 0.32),
    shadow=hexc("000000", 0.80), track=hexc("070B11", 0.90),
)

LIGHT = dict(
    background=hexc("E7ECF3"), surface=hexc("FFFFFF"), surface_soft=hexc("D1DAE6"),
    surface_high=hexc("BDC8DC"), border=hexc("8492A8", 0.85), text=hexc("121721"),
    secondary=hexc("47536A"), muted=hexc("5D687E"), accent=hexc("0D7DB3"),
    on_accent=hexc("FFFFFF"), success=hexc("15764F"), warning=hexc("9A5407"),
    danger=hexc("C02F2F"), info=hexc("2A5BD7"), scrim=hexc("1B2432", 0.28),
    shadow=hexc("10161F", 0.30), track=hexc("D3DAE5", 0.95),
    # Bar fill only — a **pure** colour instead of one darkened to read as text. The outline makes the boundary.
    success_vivid=hexc("10A86B"), warning_vivid=hexc("F2A007"),
    danger_vivid=hexc("DC3545"), info_vivid=hexc("2F6FE0"),
    accent_vivid=hexc("0E9AD8"),
)

CONST = dict(
    touch=48, button_height=52,
    gap_tiny=4, gap_small=8, gap=12, gap_large=20,
    padding=20, padding_compact=12,
    # Horizontal and vertical padding of a small button's panel — kept apart from the surface padding
    # (`padding_compact`). A shape dict may override it.
    compact_padding_x=10, compact_padding_y=5,
    radius=12, radius_small=8, radius_large=18,
    screen_margin=16,
    scroll_deadzone=18, scroll_edge=4, scrollbar_width=6,
    list_glyph=18, icon_size=20,
    notice_duration_ms=3000,
    # 🪟 **Opacity (%)** of a container panel's background — 100 is a solid colour, 80 lets 20% of what
    #    is behind bleed through. Text, icons and buttons do not follow it (see the `PANEL_ALPHA`
    #    comment in `core/go_theme.gd`).
    # 🛑 Only `popup_alpha` is 100 — the engine may put a `PopupMenu` in its own **window**, and then the
    #    OS does not composite it with the game screen, so a translucent panel comes out black instead
    #    of showing what is behind it.
    #    A project that embeds popups in the game (`gui_embed_subwindows`) may lower it in its palette.
    panel_alpha=80, card_alpha=80, hud_alpha=80, notice_alpha=80, popup_alpha=100,
)

FONTS = dict(micro=10, compact=12, caption=13, body=16, button=16, subtitle=22, title=28)

SCIFI_DARK = dict(
    background=hexc("05080E"), surface=hexc("121D2E"), surface_soft=hexc("1A2B42"),
    surface_high=hexc("213754"), border=hexc("3D8FB5", 0.90), text=hexc("D8F4FF"),
    secondary=hexc("7FB4CC"), muted=hexc("6791AD"), accent=hexc("00E5FF"),
    on_accent=hexc("03121A"), success=hexc("3BFFA5"), warning=hexc("FFC53D"),
    danger=hexc("FF4D6D"), info=hexc("5B8CFF"), scrim=hexc("000914", 0.55),
    shadow=hexc("00E5FF", 0.35), track=hexc("04090F", 0.95),
)

# A blueprint feel — cyan lines on a light ground. It uses **the same shape** as the dark sci-fi theme.
SCIFI_LIGHT = dict(
    background=hexc("E0E8EE"), surface=hexc("F7FAFC"), surface_soft=hexc("C8D8E2"),
    surface_high=hexc("AEC8D8"), border=hexc("2F6E8A", 0.90), text=hexc("071A26"),
    secondary=hexc("2E5A70"), muted=hexc("466372"), accent=hexc("007EA9"),
    on_accent=hexc("FFFFFF"), success=hexc("0A7A55"), warning=hexc("96500A"),
    danger=hexc("BE2B43"), info=hexc("2A5BD7"), scrim=hexc("0A1A24", 0.35),
    shadow=hexc("0086B3", 0.28), track=hexc("C6D6DF", 0.95),
    # Bar fill only — sci-fi goes one step further toward fluorescent.
    success_vivid=hexc("00BE7B"), warning_vivid=hexc("FFAE00"),
    danger_vivid=hexc("E82749"), info_vivid=hexc("2F7BFF"),
    accent_vivid=hexc("00AEE0"),
)


# ── Shape — "what it looks like", apart from "what colour it is" ────────
#
# 🛑 `SHAPE_DEFAULT` is the **canonical record** of gohud's original look. Change one number here and
#    both existing themes change shape. A new look is made by **adding a new dict** — never by editing this one.

SHAPE_DEFAULT = dict(
    kind="flat",         # StyleBoxFlat — rounded corners
    controls="rounded",  # family of the toggle / check / radio / grabber artwork
)

SHAPE_CUT = dict(
    kind="cut",          # GoStyleBoxCut — corners cut on the diagonal
    controls="cut",
    cut_ratio=0.85,      # size of the cut = the original radius × this
    cut_max=14,          # never cut more than this, however large the radius
    corners="diagonal",  # cut top-left + bottom-right only — a look that flows one way
    glow=8,              # glow distance put where the shadow used to be
    edge=2,              # thickness of the accent edge drawn heavy on a single side
)

CUT_SCRIPT = RES + "/widgets/go_stylebox_cut.gd"
MEDIEVAL_SCRIPT = RES + "/widgets/go_stylebox_medieval.gd"
BRACKET_SCRIPT = RES + "/widgets/go_stylebox_bracket.gd"

# `corners=(tl, tr, br, bl)` → the bitmask GoStyleBoxCut expects
CUT_TOP_LEFT, CUT_TOP_RIGHT, CUT_BOTTOM_RIGHT, CUT_BOTTOM_LEFT = 1, 2, 4, 8
CUT_DIAGONAL = CUT_TOP_LEFT | CUT_BOTTOM_RIGHT
CUT_ALL = CUT_TOP_LEFT | CUT_TOP_RIGHT | CUT_BOTTOM_RIGHT | CUT_BOTTOM_LEFT


# ── Per-theme control artwork ───────────────────────────────────────────

def control_svgs(pal, shape=SHAPE_DEFAULT):
    acc, on, mut, sec, hi = (svg_hex(pal[k]) for k in ("accent", "on_accent", "muted", "secondary", "surface_high"))

    def wrap(w, h, body, disabled=False):
        group = '<g opacity=".38">%s</g>' % body if disabled else body
        return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % (w, h, w, h, group)

    def toggle(state_on, disabled, mirrored):
        knob_x = 28 if state_on != mirrored else 12
        if state_on:
            # On — filled track + contrasting knob (Material 3's primary / on-primary pair)
            body = ('<rect x="1" y="1" width="38" height="22" rx="11" fill="%s"/>'
                    '<circle cx="%d" cy="12" r="8" fill="%s"/>') % (acc, knob_x, on)
        else:
            # Off — outlined track + a small muted knob. Shaped unlike "on", so it reads without colour.
            body = ('<rect x="1.75" y="1.75" width="36.5" height="20.5" rx="10.25" fill="%s" stroke="%s" stroke-width="1.5"/>'
                    '<circle cx="%d" cy="12" r="6" fill="%s"/>') % (hi, mut, knob_x, mut)
        return wrap(40, 24, body, disabled)

    def check(state_on, disabled):
        if state_on:
            body = ('<rect x="1" y="1" width="18" height="18" rx="5" fill="%s"/>'
                    '<path d="M5.5 10.2 8.6 13.3 14.6 7.2" fill="none" stroke="%s" stroke-width="2" '
                    'stroke-linecap="round" stroke-linejoin="round"/>') % (acc, on)
        else:
            body = '<rect x="1.75" y="1.75" width="16.5" height="16.5" rx="4.5" fill="none" stroke="%s" stroke-width="1.5"/>' % mut
        return wrap(20, 20, body, disabled)

    def radio(state_on, disabled):
        if state_on:
            body = ('<circle cx="10" cy="10" r="9" fill="%s"/>'
                    '<circle cx="10" cy="10" r="3.6" fill="%s"/>') % (acc, on)
        else:
            body = '<circle cx="10" cy="10" r="8.25" fill="none" stroke="%s" stroke-width="1.5"/>' % mut
        return wrap(20, 20, body, disabled)

    def arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>') % (sec, path)

    # ── The angular family ─────────────────────────────────────────────
    # 🛑 Reusing the rounded artwork leaves the panels angular while toggles and checks stay pills and
    #    circles — **two grammars on one screen.** The engine does not even tint these drawings, so
    #    there is nothing for it but to redraw them per theme.

    def points(x, y, w, h, c, every=False):
        if every:
            return [(x + c, y), (x + w - c, y), (x + w, y + c), (x + w, y + h - c),
                    (x + w - c, y + h), (x + c, y + h), (x, y + h - c), (x, y + c)]
        return [(x + c, y), (x + w, y), (x + w, y + h - c), (x + w - c, y + h), (x, y + h), (x, y + c)]

    def poly(pts, fill="none", stroke=None, width=1.5):
        body = '<polygon points="%s" fill="%s"' % (" ".join("%g,%g" % p for p in pts), fill)
        if stroke:
            body += ' stroke="%s" stroke-width="%g" stroke-linejoin="miter"' % (stroke, width)
        return body + "/>"

    def diamond(cx, cy, r):
        return [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]

    def cut_toggle(state_on, disabled, mirrored):
        knob_x = 27 if state_on != mirrored else 13
        if state_on:
            body = (poly(points(1, 1, 38, 22, 6), fill=acc)
                    + poly(points(knob_x - 6, 5, 12, 14, 4), fill=on))
        else:
            body = (poly(points(1.75, 1.75, 36.5, 20.5, 6), fill=hi, stroke=mut)
                    + poly(points(knob_x - 5, 7, 10, 10, 3), fill=mut))
        return wrap(40, 24, body, disabled)

    def cut_check(state_on, disabled):
        if state_on:
            body = (poly(points(1, 1, 18, 18, 5), fill=acc)
                    + '<path d="M5 10 8.8 13.8 15 6.8" fill="none" stroke="%s" stroke-width="2.2" '
                      'stroke-linecap="square" stroke-linejoin="miter"/>' % on)
        else:
            body = poly(points(1.75, 1.75, 16.5, 16.5, 5), stroke=mut)
        return wrap(20, 20, body, disabled)

    def cut_radio(state_on, disabled):
        if state_on:
            body = poly(diamond(10, 10, 9), fill=acc) + poly(diamond(10, 10, 3.6), fill=on)
        else:
            body = poly(diamond(10, 10, 8.25), stroke=mut)
        return wrap(20, 20, body, disabled)

    def hexagon(cx, cy, r):
        return [(cx - r * 0.5, cy - r), (cx + r * 0.5, cy - r), (cx + r, cy),
                (cx + r * 0.5, cy + r), (cx - r * 0.5, cy + r), (cx - r, cy)]

    def cut_arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter"><path d="%s"/></svg>') % (sec, path)

    angular = shape.get("controls") == "cut"
    if angular:
        toggle, check, radio, arrow = cut_toggle, cut_check, cut_radio, cut_arrow

    out = {}
    for state_on in (True, False):
        for disabled in (False, True):
            for mirrored in (False, True):
                name = "toggle_%s%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "", "_mirrored" if mirrored else "")
                out[name] = toggle(state_on, disabled, mirrored)
        for disabled in (False, True):
            out["check_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = check(state_on, disabled)
            out["radio_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = radio(state_on, disabled)
    if angular:
        out["grabber"] = wrap(20, 20, poly(hexagon(10, 10, 8), fill=acc))
        out["grabber_highlight"] = wrap(20, 20, poly(hexagon(10, 10, 10), fill=acc) .replace('fill="%s"' % acc, 'fill="%s" fill-opacity=".22"' % acc) + poly(hexagon(10, 10, 8), fill=acc))
        out["grabber_disabled"] = wrap(20, 20, poly(hexagon(10, 10, 7), fill=mut))
    else:
        out["grabber"] = wrap(20, 20, '<circle cx="10" cy="10" r="8" fill="%s"/>' % acc)
        out["grabber_highlight"] = wrap(20, 20, '<circle cx="10" cy="10" r="10" fill="%s" fill-opacity=".22"/><circle cx="10" cy="10" r="8" fill="%s"/>' % (acc, acc))
        out["grabber_disabled"] = wrap(20, 20, '<circle cx="10" cy="10" r="7" fill="%s"/>' % mut)
    out["arrow_down"] = arrow("M4 6l4 4 4-4")
    out["arrow_right"] = arrow("M6 4l4 4-4 4")
    out["arrow_left"] = arrow("M10 4 6 8l4 4")
    return out


IMPORT_TEMPLATE = ('[remap]\n\nimporter="svg"\ntype="DPITexture"\n\n[deps]\n\nsource_file="%s"\n\n[params]\n\n'
                   'base_scale=1.0\nsaturation=1.0\ncolor_map={}\nfix_alpha_border=false\npremult_alpha=false\ncompress=true\n')


def write_assets(variant, pal, shape):
    folder = os.path.join(ADDON, "assets", variant)
    os.makedirs(folder, exist_ok=True)
    names = []
    for name, svg in control_svgs(pal, shape).items():
        path = os.path.join(folder, name + ".svg")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(svg + "\n")
        importer = path + ".import"
        if not os.path.exists(importer):
            with open(importer, "w", encoding="utf-8") as fh:
                fh.write(IMPORT_TEMPLATE % ("%s/assets/%s/%s.svg" % (RES, variant, name)))
        names.append(name)
    return names


# ── StyleBox ────────────────────────────────────────────────────────────

def flat(bg=None, border=None, bw=0, radius=0, margins=None, shadow=None, shadow_offset=None,
         draw_center=True, corners=None, borders=None):
    out = []
    if margins:
        for side, value in zip(("left", "top", "right", "bottom"), margins):
            out.append("content_margin_%s = %g" % (side, value))
    if not draw_center:
        out.append("draw_center = false")
    if bg is not None:
        out.append("bg_color = %s" % C(bg))
    widths = borders if borders is not None else ((bw,) * 4 if bw else None)
    if widths and any(widths):
        for side, value in zip(("left", "top", "right", "bottom"), widths):
            if value:
                out.append("border_width_%s = %d" % (side, value))
        out.append("border_color = %s" % C(border))
    radii = corners if corners is not None else ((radius,) * 4 if radius else None)
    if radii and any(radii):
        for corner, value in zip(("top_left", "top_right", "bottom_right", "bottom_left"), radii):
            if value:
                out.append("corner_radius_%s = %d" % (corner, value))
        out.append("corner_detail = 8")
    if shadow is not None:
        out.append("shadow_color = %s" % C(shadow[0]))
        out.append("shadow_size = %d" % shadow[1])
        if shadow_offset:
            out.append("shadow_offset = Vector2(%g, %g)" % shadow_offset)
    return out


def cut(shape, bg=None, border=None, bw=0, radius=0, margins=None, shadow=None, shadow_offset=None,
        draw_center=True, corners=None, borders=None, edge=None, glow=None):
    """Take **the same arguments** as `flat()` and translate them into an angular panel (GoStyleBoxCut).

    Taking the same arguments is the whole point — it lets the shape be swapped without touching a
    single box definition inside `build()`. A rounded radius becomes the cut size, a one-sided border
    becomes the accent edge, and the shadow becomes a glow.
    """
    out = ['script = ExtResource("cut")']   # 🛑 First — custom fields are only recognised after this line
    if margins:
        for side, value in zip(("left", "top", "right", "bottom"), margins):
            out.append("content_margin_%s = %g" % (side, value))
    if not draw_center:
        out.append("draw_center = false")
    if bg is not None:
        out.append("bg_color = %s" % C(bg))

    base = max([radius] + list(corners or []))
    out.append("cut = %g" % min(base * shape["cut_ratio"], shape["cut_max"]))
    if corners is not None:
        mask = 0
        for value, bit in zip(corners, (CUT_TOP_LEFT, CUT_TOP_RIGHT, CUT_BOTTOM_RIGHT, CUT_BOTTOM_LEFT)):
            if value:
                mask |= bit
    else:
        mask = CUT_DIAGONAL if shape["corners"] == "diagonal" else CUT_ALL
    out.append("cut_corners = %d" % mask)

    widths = borders if borders is not None else ((bw,) * 4 if bw else None)
    if widths and any(widths):
        # Indices 0·1·2·3 are SIDE_LEFT·TOP·RIGHT·BOTTOM as they stand.
        marked = [index for index, value in enumerate(widths) if value]
        if len(marked) == 1 and edge is None:
            # Drawing a single side (a tab underline) is not a border but an **accent edge**.
            out.append("border_width = 0.0")
            out.append("edge_color = %s" % C(border))
            out.append("edge_width = %g" % widths[marked[0]])
            out.append("edge_side = %d" % marked[0])
            edge = None
        else:
            out.append("border_width = %g" % max(widths))
            out.append("border_color = %s" % C(border))
    else:
        out.append("border_width = 0.0")

    if edge is not None:
        out.append("edge_color = %s" % C(edge))
        out.append("edge_width = %g" % shape["edge"])
        out.append("edge_side = 1")     # top

    # Glow — an explicit `glow` wins; without one it stands in for where the shadow was.
    if glow is not None:
        out.append("glow_color = %s" % C(glow[0]))
        out.append("glow_size = %g" % glow[1])
    elif shadow is not None:
        out.append("glow_color = %s" % C(shadow[0]))
        out.append("glow_size = %g" % min(shadow[1], shape["glow"]))
    return out


def medieval(shape, bid, **kw):
    """Reuse the shared component palette/metrics with an opt-in forged frame."""
    out = ['script = ExtResource("medieval")']
    for side, value in zip(("left", "top", "right", "bottom"), kw.get("margins") or (0, 0, 0, 0)):
        out.append("content_margin_%s = %g" % (side, value))
    for name in ("bg_color", "border_color"):
        source = "bg" if name == "bg_color" else "border"
        if kw.get(source) is not None:
            out.append("%s = %s" % (name, C(kw[source])))
    out.append("border_width = %g" % max(kw.get("borders") or [kw.get("bw", 0)]))
    out.append("radius = %g" % min(shape.get("radius_large", 6), max([kw.get("radius", 0)] + list(kw.get("corners") or []))))
    out.append("draw_center = %s" % ("true" if kw.get("draw_center", True) else "false"))
    ornate = bid in ("panel", "panel_solid", "card", "popup", "fold_panel")
    quiet = bid in ("hud", "bar_bg", "bar_fill", "separator", "menu_separator", "menu_hover") or bid.startswith(("scroll_", "slider_", "list_"))
    out.append("ornament = %d" % (0 if quiet else 2 if ornate else 1))
    out.append("material = %d" % shape.get("material", 1))
    for key, default in (("ornament_scale", 1.0), ("grain_alpha", 0.035), ("bevel_strength", 0.18)):
        out.append("%s = %g" % (key, 0.0 if quiet and key == "grain_alpha" else shape.get(key, default)))
    shadow = kw.get("shadow")
    if shadow is not None:
        out += ["shadow_color = %s" % C(shadow[0]), "shadow_size = %d" % shadow[1]]
        if kw.get("shadow_offset"):
            out.append("shadow_offset = Vector2(%g, %g)" % tuple(kw["shadow_offset"]))
    return out


def build(pal, shape, variant, out_path):
    # 🔑 **Colours used as text are not hand-picked.** Nudging the surface ramp by a single step drops
    #    muted text straight below the bar (2026-09-13: widening the surfaces put `muted` back under the
    #    threshold in all four themes). The value written in the palette is the **starting point**; from
    #    there it is pushed until it reads on every surface it is actually laid on.
    pal = dict(pal)
    # 🛑 **Fills must not start from the value pushed for text.** `settle()` below darkens or brightens a
    #    colour so it reads against the background; a bar fill wants the opposite. Keep the uncorrected
    #    values aside.
    raw = dict(pal)
    _bg = flatten(pal["background"], (0, 0, 0, 1.0))
    _surfaces = [_bg] + [flatten(pal[key], _bg) for key in ("surface", "surface_soft", "surface_high")]
    # 🔑 **Report what was moved and by how much.** Changing it silently leaves whoever supplied their
    #    own palette stuck on "why isn't the colour I wrote coming out". Only what changed is printed
    #    below, one line each.
    moved = []

    def settle(key, backs, need=4.6, why="surface contrast"):
        before = pal[key]
        pal[key] = readable_everywhere(pal[key], backs, need)
        if pal[key][:3] != before[:3]:
            moved.append((key, before, pal[key], why))

    for key in ("secondary", "muted"):
        settle(key, _surfaces)
    # Status colours are laid as text over the background and over panels (never on the inner card surface).
    for key in ("success", "warning", "danger", "info"):
        settle(key, _surfaces[:2])
    # 🛑 A border is **decoration**, not text, so its bar is lower (2:1). Still, one that cannot be seen at
    #    all melts the card into the background, so the floor is kept. Alpha is composited away here —
    #    subtlety has to come from the colour itself.
    settle("border", _surfaces[1:3], 2.12, "card boundary")
    # 🛑 **The accent is not trusted as hand-picked either.** Swapping in a single accent colour through
    #    the scaffolding collapsed the accent border and the focus ring to 2.2:1 and accent button text to
    #    2.7:1 all at once (measured 2026-09-13). The accent is pushed past the component bar (3:1) over
    #    the background and the surfaces, and the text on it past the body bar — that is what keeps the
    #    promise that "changing only the palette still passes the checks".
    settle("accent", _surfaces[:2], 3.1, "accent visibility")
    # 🛑 **Pushing the text is not enough.** Over a light purple accent neither white nor black text
    #    reaches 4.5, and on the pressed panel (mixed toward the text colour, so darker still) it fell to
    #    3.15 (measured). So **the accent itself** is pushed until it reads against the text colour —
    #    contrast is symmetric, so the text then reads on the accent. Built-in themes that already pass
    #    are left alone (`readable` returns a colour unchanged once it passes).
    _on_solid = flatten(pal["on_accent"], _bg)
    _before_accent = pal["accent"]
    pal["accent"] = readable(pal["accent"], _on_solid, 4.5)
    if pal["accent"][:3] != _before_accent[:3]:
        moved.append(("accent", _before_accent, pal["accent"], "so accent button text reads"))
    _accent_solid = flatten(pal["accent"], _bg)
    # 🛑 White text cannot be brightened any further — it stopped at 3.97:1 over a light purple accent
    #    (measured). If the ink colour as written passes, leave it (so built-in themes do not shift);
    #    **only when it cannot** switch to whichever of the dark/light candidates — started from the
    #    background and the body colour — reads best.
    _before_on = pal["on_accent"]
    _first = readable(pal["on_accent"], _accent_solid, 4.6)
    if contrast(_first, _accent_solid) >= 4.5:
        pal["on_accent"] = _first
    else:
        _options = [_first] + [readable(pal[k], _accent_solid, 4.6) for k in ("background", "text")]
        pal["on_accent"] = max(_options, key=lambda c: contrast(c, _accent_solid))
    if pal["on_accent"][:3] != _before_on[:3]:
        moved.append(("on_accent", _before_on, pal["on_accent"], "accent button text"))

    # 🔑 **The shape dict has the first word on the numbers.** Radii, button padding and gaps can be
    #    overridden by the shape, so "sharper corners" and "flatter buttons" happen without touching skin
    #    code (2026-09-13 — a request for more freedom per theme). Anything missing falls back to the
    #    defaults in `CONST`.
    consts = dict(CONST)
    for key in ("radius", "radius_small", "radius_large", "gap", "gap_small", "gap_large", "padding", "button_height",
                "compact_padding_x", "compact_padding_y"):
        if key in shape: consts[key] = shape[key]
    R, G = consts["radius"], consts["radius_small"]
    PAD = tuple(shape.get("button_padding", (16, 10, 16, 10)))
    boxes = {}
    cutting = shape["kind"] == "cut"
    forging = shape["kind"] == "medieval"

    def box(bid, **kw):
        # `edge` (accent edge) and `glow` are decorations the angular shape alone has — the rounded shape
        # drops them quietly.
        accent_edge = kw.pop("edge", None)
        glow = kw.pop("glow", None)
        # 🛑 `flat_shadow` is **for the rounded shape only.** In the angular shape the glow carries the
        #    depth, so turning the shadow on as well stacks two layers on every card and looks dirty.
        flat_shadow = kw.pop("flat_shadow", None)
        if cutting:
            boxes[bid] = ("StyleBox", cut(shape, edge=accent_edge, glow=glow, **kw))
        else:
            if flat_shadow is not None and kw.get("shadow") is None:
                kw["shadow"] = flat_shadow[:2]
                if len(flat_shadow) > 2:
                    kw["shadow_offset"] = flat_shadow[2]
            boxes[bid] = ("StyleBox", medieval(shape, bid, **kw)) if forging else ("StyleBoxFlat", flat(**kw))

    def bracket(bid, color, arm=11, thickness=2.0, inset=0.0, margins=None, bg=None):
        """A marker panel drawing the four corners only. 🛑 Angular shape only — never called for the rounded one."""
        out = ['script = ExtResource("bracket")']
        if margins:
            for side, value in zip(("left", "top", "right", "bottom"), margins):
                out.append("content_margin_%s = %g" % (side, value))
        if bg is not None:
            out.append("bg_color = %s" % C(bg))
        out.append("color = %s" % C(color))
        out.append("arm = %g" % arm)
        out.append("thickness = %g" % thickness)
        out.append("inset = %g" % inset)
        boxes[bid] = ("StyleBox", out)

    hover_bg = mix(pal["surface"], pal["text"], 0.10)
    press_bg = mix(pal["surface"], pal["accent"], 0.22)

    # 🛑 Buttons sit **both on the background and inside cards** — they must read on **whichever is
    #    worse.** Inside a card (`surface_soft`) is usually worse: the card background brightens the
    #    panel's translucent tint. The checker (`tools/check_contrast.py`) measures the same way, so
    #    giving ground here is caught as a failure exactly as it stands.
    under = pal["surface_soft"]

    def ink_on(box_bg, wanted, need=4.65):
        """Push `wanted` until text in that colour reads on a `box_bg` panel.

        🛑 The target sits a little above 4.5 rather than on it — landing exactly on the bar means the
           rounding alone, as the value is written into the `.tres`, drops it below and the check fails
           right after generating.
        """
        return readable(wanted, flatten(box_bg, flatten(under, (0, 0, 0, 1.0))), need)

    danger_bg = alpha(pal["danger"], 0.12)
    danger_bg_hover = alpha(pal["danger"], 0.20)
    danger_ink = ink_on(danger_bg, pal["danger"])
    danger_ink_hover = ink_on(danger_bg_hover, pal["danger"])
    press_ink = ink_on(press_bg, pal["accent"])
    list_press_ink = ink_on(alpha(pal["text"], 0.09), pal["accent"])
    # The primary button while pressed — in the light theme, mixing the accent toward the background
    # **brightens** it and kills the white text. Mix toward the text colour so it always darkens.
    primary_press_bg = mix(pal["accent"], pal["text"], 0.22)

    # Buttons
    box("btn_normal", bg=pal["surface"], border=pal["border"], bw=1, radius=R, margins=PAD)
    box("btn_hover", bg=hover_bg, border=alpha(pal["text"], 0.42), bw=1, radius=R, margins=PAD)
    box("btn_pressed", bg=press_bg, border=alpha(pal["accent"], 0.75), bw=1, radius=R, margins=PAD)
    box("btn_disabled", bg=alpha(pal["surface"], 0.55), border=alpha(pal["border"], 0.35), bw=1, radius=R, margins=PAD)
    if cutting:
        # 🔑 sci-fi's focus is a **targeting bracket**, not a border — it points without covering the content.
        bracket("btn_focus", pal["accent"], arm=12, thickness=2.0, margins=PAD)
        bracket("btn_focus_on_fill", pal["on_accent"], arm=12, thickness=2.0, margins=PAD)
    else:
        box("btn_focus", draw_center=False, border=pal["accent"], bw=2, radius=R, margins=PAD)
        # 🛑 **An accent ring is invisible on a filled panel** — the panel is that very colour. Moving
        #    around with the keyboard, "where am I now" disappears (measured on desktop 2026-09-13:
        #    hover and focus were indistinguishable). Filled buttons get a ring that **contrasts with
        #    the panel**.
        box("btn_focus_on_fill", draw_center=False, border=pal["on_accent"], bw=2, radius=R, margins=PAD)
    box("btn_primary", bg=pal["accent"], border=pal["accent"], bw=1, radius=R, margins=PAD,
        glow=(alpha(pal["accent"], 0.55), 7),
        flat_shadow=(alpha(pal["accent"], 0.34), 8, (0, 3)))
    box("btn_primary_hover", bg=mix(pal["accent"], pal["text"], 0.18), border=pal["accent"], bw=1, radius=R, margins=PAD,
        glow=(alpha(pal["accent"], 0.75), 10),
        flat_shadow=(alpha(pal["accent"], 0.46), 11, (0, 4)))
    box("btn_primary_pressed", bg=primary_press_bg, border=pal["accent"], bw=1, radius=R, margins=PAD,
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.25), 3, (0, 1)))
    box("btn_danger", bg=danger_bg, border=alpha(pal["danger"], 0.85), bw=1, radius=R, margins=PAD)
    box("btn_danger_hover", bg=danger_bg_hover, border=pal["danger"], bw=1, radius=R, margins=PAD)
    # 🛑 **The confirm button of an irreversible action** needs more than a pale panel. A pale panel
    #    forces the text very dark to be readable (`#9B2626` in the light theme), and then it is no
    #    longer "red", just black writing. Filling it and putting white text on raises contrast to
    #    5.7:1 and the danger reads at a glance.
    box("btn_danger_solid", bg=pal["danger"], border=pal["danger"], bw=1, radius=R, margins=PAD,
        flat_shadow=(alpha(pal["danger"], 0.34), 8, (0, 3)))
    box("btn_danger_solid_hover", bg=mix(pal["danger"], pal["text"], 0.18), border=pal["danger"], bw=1,
        radius=R, margins=PAD, flat_shadow=(alpha(pal["danger"], 0.46), 11, (0, 4)))
    # 🛑 The pressed panel mixes **toward the text colour** (the same way the accent button does). Mixing
    #    toward the background brightens the panel in the light theme and white text falls to 3.87:1
    #    (measured 2026-09-13).
    danger_solid_press_bg = mix(pal["danger"], pal["text"], 0.22)
    box("btn_danger_solid_pressed", bg=danger_solid_press_bg, border=pal["danger"],
        bw=1, radius=R, margins=PAD,
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.25), 3, (0, 1)))

    # Slim buttons · icon buttons · list rows
    # 🔑 The padding of a small button's panel comes from the tokens (`compact_padding_x/y`) — panel and
    #    token stay equal even when a shape changes the value.
    #    🛑 Hard-coding numbers here splits the token `GoStyle.audit_compact_padding` reads from the actual panel.
    CPX, CPY = consts["compact_padding_x"], consts["compact_padding_y"]
    box("compact_normal", bg=alpha(pal["surface_soft"], 0.85), border=alpha(pal["border"], 0.55), bw=1, radius=G, margins=(CPX, CPY, CPX, CPY))
    box("compact_hover", bg=hover_bg, border=alpha(pal["text"], 0.36), bw=1, radius=G, margins=(CPX, CPY, CPX, CPY))
    box("icon_hover", bg=alpha(pal["text"], 0.10), radius=G)
    box("list_normal", bg=alpha(pal["surface_soft"], 0.55), radius=G, margins=(0, 0, 0, 0))
    box("list_hover", bg=alpha(pal["text"], 0.09), border=alpha(pal["border"], 0.5), bw=1, radius=G, margins=(0, 0, 0, 0))
    if cutting:
        bracket("focus_soft", alpha(pal["accent"], 0.85), arm=9, thickness=1.5)
    else:
        box("focus_soft", draw_center=False, border=alpha(pal["accent"], 0.7), bw=1, radius=G)

    # Surfaces
    box("panel", bg=pal["surface"], border=pal["border"], bw=1, radius=CONST["radius_large"],
        margins=(0, 0, 0, 0), shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.55), 18), shadow_offset=(0, 6),
        edge=pal["accent"])
    box("panel_solid", bg=pal["surface"], border=pal["border"], bw=1, radius=R, margins=(0, 0, 0, 0))
    gap = consts["gap"]
    box("card", bg=pal["surface_soft"], border=alpha(pal["border"], 0.6), bw=1, radius=R, margins=(gap, gap, gap, gap),
        edge=alpha(pal["accent"], 0.55),
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.30), 6, (0, 2)))
    box("popup", bg=mix(pal["surface"], pal["background"], 0.25), border=pal["border"], bw=1, radius=R, margins=(gap, gap, gap, gap),
        edge=pal["accent"],
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.55), 16, (0, 5)))
    # 🔑 **A dropdown menu is not a button.** Using the button panel (`btn_hover`) for item hover drags
    #    the border and the shadow along and the list judders — items get **a pale accent fill** only
    #    (user report 2026-09-13).
    box("menu_hover", bg=alpha(pal["accent"], 0.16), radius=G, margins=(gap, 6, gap, 6))
    box("menu_separator", bg=alpha(pal["border"], 0.7), margins=(0, CONST["gap_small"], 0, CONST["gap_small"]))
    small = consts["gap_small"]
    # 🛑 **A HUD panel is laid over the game screen** — which may be a snowfield or a cave. A bright
    #    backdrop brightens the whole dark panel and muted text thinned to 3.74:1 (measured 2026-09-13).
    #    Keep the glassy feel, but raise it to where **body text holds 4.5:1 over the worst backdrop
    #    (pure white, pure black)** — 0.88 is the boundary, so it sits at 0.92.
    box("hud", bg=alpha(pal["surface"], 0.92), border=alpha(pal["border"], 0.8), bw=1, radius=R, margins=(small, small, small, small),
        edge=pal["accent"], glow=(alpha(pal["accent"], 0.30), 6))
    box("notice", bg=mix(pal["surface"], pal["background"], 0.15), border=pal["border"], bw=1, radius=R, margins=(gap, gap, gap, gap),
        edge=pal["accent"], glow=(alpha(pal["accent"], 0.30), 6),
        flat_shadow=(alpha(pal["shadow"], pal["shadow"][3] * 0.45), 12, (0, 4)))
    boxes["empty"] = ("StyleBoxEmpty", [])

    # Input fields
    box("edit_normal", bg=alpha(pal["background"], 0.65), border=pal["border"], bw=1, radius=G, margins=(12, 8, 12, 8))
    box("edit_focus", bg=alpha(pal["background"], 0.85), border=pal["accent"], bw=2, radius=G, margins=(12, 8, 12, 8))

    # Scrollbars — thin and pale. The point is not to cover the content.
    sb_w = CONST["scrollbar_width"]
    half = (sb_w / 2.0,) * 4
    box("scroll_track", bg=alpha(pal["muted"], 0.14), radius=sb_w // 2, margins=half)
    box("scroll_grab", bg=alpha(pal["secondary"], 0.50), radius=sb_w // 2, margins=half)
    box("scroll_grab_hover", bg=alpha(pal["secondary"], 0.80), radius=sb_w // 2, margins=half)

    # Sliders — a StyleBox **separate** from the scrollbar's (share one and neither can be changed alone)
    box("slider_track", bg=alpha(pal["track"], 0.9), radius=3, margins=(0, 3, 0, 3))
    box("slider_grab", bg=alpha(pal["accent"], 0.55), radius=3, margins=(0, 3, 0, 3))
    box("slider_grab_hover", bg=pal["accent"], radius=3, margins=(0, 3, 0, 3))

    # Progress bars · separators · tooltips
    # 🛑 **The track has to be visible** for "how much is left" to read. Colour alone cannot guarantee it —
    #    a bar sits on the background, inside a card and on a HUD panel, and those three differ in
    #    brightness (in scifi_dark the track was 1.003:1 against the background, effectively the same
    #    colour — measured 2026-09-13). So the boundary is made with an **outline**.
    box("bar_bg", bg=alpha(pal["track"], 0.85), radius=G,
        border=alpha(pal["border"], 0.65), bw=1)
    # 🛑 The glow colour **follows the fill** — `GoSkin.progress_fill_box()` changes it along with the
    #    fill. Pin it and a red health bar glows cyan.
    box("bar_fill", bg=pal["accent"], radius=G, glow=(alpha(pal["accent"], 0.50), 4))
    box("separator", bg=alpha(pal["border"], 0.8), margins=(0, 0.5, 0, 0.5))
    box("tooltip", bg=mix(pal["surface"], pal["background"], 0.35), border=pal["border"], bw=1, radius=G, margins=(10, 6, 10, 6))

    # Foldable sections (FoldableContainer, 4.5+) — expanded, title panel and body panel read as one card.
    # 🛑 Title panel height = one line of text + 13 padding twice ≈ 48 — the title row is the touch target.
    fold_pad = (14, 13, 14, 13)
    edge = alpha(pal["border"], 0.6)
    edge_hover = alpha(pal["border"], 0.95)
    box("fold_title", bg=pal["surface_soft"], border=edge, borders=(1, 1, 1, 0), corners=(R, R, 0, 0), margins=fold_pad)
    box("fold_title_hover", bg=hover_bg, border=edge_hover, borders=(1, 1, 1, 0), corners=(R, R, 0, 0), margins=fold_pad)
    box("fold_title_collapsed", bg=pal["surface_soft"], border=edge, bw=1, radius=R, margins=fold_pad)
    box("fold_title_collapsed_hover", bg=hover_bg, border=edge_hover, bw=1, radius=R, margins=fold_pad)
    box("fold_panel", bg=alpha(pal["surface_soft"], 0.5), border=edge, borders=(1, 0, 1, 1), corners=(0, 0, R, R), margins=(14, 10, 14, 14))

    assets = write_assets(variant, pal, shape)

    T = []

    def add(key, value):
        T.append("%s = %s" % (key, value))

    def sb(key, bid):
        T.append('%s = SubResource("%s")' % (key, bid))

    def ex(key, rid):
        T.append('%s = ExtResource("%s")' % (key, rid))

    add("default_font_size", FONTS["body"])

    for key in sorted(pal):
        add("GoHud/colors/%s" % key, C(pal[key]))
    # 🔑 **A colour painted over a large area** wants the opposite of an ink colour — text has to be dark
    #    enough not to sink into the background, a bar fill bright enough to catch the eye. Making one
    #    colour serve both in the light theme turns the experience bar brown. It is raised only to where
    #    it passes 3:1 over the `track` (the bar's own background) — any further and it washes out to white.
    track_solid = flatten(pal["track"], flatten(pal["background"], (0, 0, 0, 1.0)))
    for key in ("success", "warning", "danger", "info", "accent"):
        fill = fill_color(raw[key], track_solid, vivid=raw.get(key + "_vivid"))
        # 🛑 **This is a place that degrades silently.** A palette that never heard of `*_vivid` ends up
        #    using the colour darkened for text as its fill, and the bar goes brown. Say so loudly.
        if raw.get(key + "_vivid") is None and max(fill[:3]) < 0.70:
            moved.append((key + "_fill", raw[key], fill,
                          "the bar looks drab — add %s_vivid to the palette" % key))
        add("GoHud/colors/%s_fill" % key, C(fill))
    # Values overridden by the shape go out **as tokens too** — what a widget reads through
    # `GoUi.metric(RADIUS)` has to equal the panel's actual radius.
    for key in sorted(consts):
        add("GoHud/constants/%s" % key, consts[key])
    for key, bid in [("panel", "panel"), ("card", "card"), ("hud", "hud"), ("notice", "notice"), ("popup", "popup"),
                     ("empty", "empty"), ("focus", "btn_focus"), ("focus_soft", "focus_soft")]:
        sb("GoHud/styles/%s" % key, bid)

    states = [("normal", "btn_normal"), ("hover", "btn_hover"), ("pressed", "btn_pressed"),
              ("hover_pressed", "btn_pressed"), ("disabled", "btn_disabled"), ("focus", "btn_focus")]

    add("Button/colors/font_color", C(pal["text"]))
    add("Button/colors/font_hover_color", C(pal["text"]))
    add("Button/colors/font_pressed_color", C(press_ink))
    add("Button/colors/font_focus_color", C(pal["text"]))
    add("Button/colors/font_disabled_color", C(pal["muted"]))
    add("Button/colors/icon_normal_color", C(pal["secondary"]))
    add("Button/colors/icon_hover_color", C(pal["text"]))
    add("Button/colors/icon_pressed_color", C(pal["accent"]))
    add("Button/colors/icon_disabled_color", C(alpha(pal["muted"], 0.5)))
    add("Button/constants/h_separation", CONST["gap_small"])
    add("Button/font_sizes/font_size", FONTS["button"])
    for state, bid in states:
        sb("Button/styles/%s" % state, bid)

    add("Label/colors/font_color", C(pal["text"]))
    add("Label/font_sizes/font_size", FONTS["body"])
    add("RichTextLabel/colors/default_color", C(pal["text"]))
    add("RichTextLabel/font_sizes/normal_font_size", FONTS["body"])

    add("LineEdit/colors/font_color", C(pal["text"]))
    add("LineEdit/colors/font_placeholder_color", C(pal["muted"]))
    add("LineEdit/colors/caret_color", C(pal["accent"]))
    add("LineEdit/colors/selection_color", C(alpha(pal["accent"], 0.35)))
    add("LineEdit/font_sizes/font_size", FONTS["body"])
    sb("LineEdit/styles/normal", "edit_normal")
    sb("LineEdit/styles/focus", "edit_focus")
    sb("LineEdit/styles/read_only", "btn_disabled")
    add("TextEdit/colors/font_color", C(pal["text"]))
    sb("TextEdit/styles/normal", "edit_normal")
    sb("TextEdit/styles/focus", "edit_focus")

    sb("Panel/styles/panel", "panel_solid")
    sb("PanelContainer/styles/panel", "panel_solid")
    sb("TooltipPanel/styles/panel", "tooltip")
    add("TooltipLabel/colors/font_color", C(pal["text"]))
    add("TooltipLabel/font_sizes/font_size", FONTS["caption"])

    add("PopupMenu/colors/font_color", C(pal["text"]))
    add("PopupMenu/colors/font_hover_color", C(pal["text"]))
    add("PopupMenu/colors/font_disabled_color", C(pal["muted"]))
    add("PopupMenu/colors/font_accelerator_color", C(pal["secondary"]))
    add("PopupMenu/colors/font_separator_color", C(pal["secondary"]))
    # 🛑 Item height is the text height plus this value. Left at 4 it is 27dp — impossible to pick with a
    #    finger (measured 2026-09-13). Give it enough to approach the 48 touch floor; it still does not
    #    look sparse on desktop.
    add("PopupMenu/constants/v_separation", CONST["gap_large"])
    add("PopupMenu/constants/h_separation", CONST["gap"])
    add("PopupMenu/constants/item_start_padding", CONST["gap_small"])
    add("PopupMenu/constants/item_end_padding", CONST["gap_small"])
    add("PopupMenu/constants/icon_max_width", CONST["icon_size"])
    add("PopupMenu/font_sizes/font_size", FONTS["body"])
    sb("PopupMenu/styles/panel", "popup")
    sb("PopupMenu/styles/hover", "menu_hover")
    sb("PopupMenu/styles/separator", "menu_separator")
    # 🛑 Leave the radio and check marks to the engine default (a faint grey circle) and you cannot see
    #    which item is picked — reuse the same artwork the checkbox uses. It follows the theme along.
    for key, rid in [("checked", "check_on"), ("unchecked", "check_off"),
                     ("checked_disabled", "check_on_disabled"), ("unchecked_disabled", "check_off_disabled"),
                     ("radio_checked", "radio_on"), ("radio_unchecked", "radio_off"),
                     ("radio_checked_disabled", "radio_on_disabled"), ("radio_unchecked_disabled", "radio_off_disabled")]:
        ex("PopupMenu/icons/%s" % key, rid)

    add("OptionButton/colors/font_color", C(pal["text"]))
    add("OptionButton/font_sizes/font_size", FONTS["body"])
    for state, bid in states:
        sb("OptionButton/styles/%s" % state, bid)
    ex("OptionButton/icons/arrow", "arrow_down")
    # 🛑 Inset the arrow from the right edge **by the button's own padding**. At the engine default (4) its
    #    x lands 12dp off the arrow of a `dropdown()` beside it (MenuButton, icon inside the padding) and
    #    the two read as different parts (measured in the demo 2026-09-13).
    add("OptionButton/constants/arrow_margin", PAD[2])

    empty_states = ["normal", "hover", "pressed", "hover_pressed", "disabled"]
    add("CheckButton/colors/font_color", C(pal["text"]))
    add("CheckButton/colors/font_disabled_color", C(pal["muted"]))
    add("CheckButton/font_sizes/font_size", FONTS["body"])
    add("CheckButton/constants/h_separation", CONST["gap"])
    for state in empty_states:
        sb("CheckButton/styles/%s" % state, "empty")
    sb("CheckButton/styles/focus", "focus_soft")
    for key in ["checked", "unchecked", "checked_disabled", "unchecked_disabled",
                "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
        rid = key.replace("unchecked", "toggle_off").replace("checked", "toggle_on")
        ex("CheckButton/icons/%s" % key, rid)

    add("CheckBox/colors/font_color", C(pal["text"]))
    add("CheckBox/colors/font_disabled_color", C(pal["muted"]))
    add("CheckBox/font_sizes/font_size", FONTS["body"])
    add("CheckBox/constants/h_separation", CONST["gap_small"])
    for state in empty_states:
        sb("CheckBox/styles/%s" % state, "empty")
    sb("CheckBox/styles/focus", "focus_soft")
    for key, rid in [("checked", "check_on"), ("unchecked", "check_off"),
                     ("checked_disabled", "check_on_disabled"), ("unchecked_disabled", "check_off_disabled"),
                     ("radio_checked", "radio_on"), ("radio_unchecked", "radio_off"),
                     ("radio_checked_disabled", "radio_on_disabled"), ("radio_unchecked_disabled", "radio_off_disabled")]:
        ex("CheckBox/icons/%s" % key, rid)

    # The tab row — the selected tab gets an accent underline, the rest a thin baseline. Top corners only are rounded.
    tab_margins = (CONST["padding"], CONST["gap_small"], CONST["padding"], CONST["gap_small"])
    tab_radius = CONST.get("radius_small", 8)
    box("tab_selected", bg=pal["surface_high"], border=pal["accent"], borders=(0, 0, 0, 2),
        corners=(tab_radius, tab_radius, 0, 0), margins=tab_margins, glow=(alpha(pal["accent"], 0.35), 5))
    box("tab_unselected", draw_center=False, border=pal["border"], borders=(0, 0, 0, 1), margins=tab_margins)
    box("tab_hovered", bg=pal["surface_soft"], border=pal["border"], borders=(0, 0, 0, 1),
        corners=(tab_radius, tab_radius, 0, 0), margins=tab_margins)
    for key, bid in [("tab_selected", "tab_selected"), ("tab_unselected", "tab_unselected"),
                     ("tab_hovered", "tab_hovered"), ("tab_disabled", "tab_unselected"), ("tab_focus", "focus_soft")]:
        sb("TabBar/styles/%s" % key, bid)
    add("TabBar/colors/font_selected_color", C(pal["text"]))
    add("TabBar/colors/font_unselected_color", C(pal["secondary"]))
    add("TabBar/colors/font_hovered_color", C(pal["text"]))
    add("TabBar/colors/font_disabled_color", C(pal["muted"]))
    add("TabBar/font_sizes/font_size", FONTS["body"])
    add("TabBar/constants/h_separation", CONST["gap_small"])
    for key, bid in [("tab_selected", "tab_selected"), ("tab_unselected", "tab_unselected"),
                     ("tab_hovered", "tab_hovered"), ("tab_disabled", "tab_unselected"), ("tab_focus", "focus_soft"),
                     ("panel", "card")]:
        sb("TabContainer/styles/%s" % key, bid)
    add("TabContainer/colors/font_selected_color", C(pal["text"]))
    add("TabContainer/colors/font_unselected_color", C(pal["secondary"]))
    add("TabContainer/font_sizes/font_size", FONTS["body"])

    add("FoldableContainer/colors/font_color", C(pal["text"]))
    add("FoldableContainer/colors/hover_font_color", C(pal["text"]))
    add("FoldableContainer/colors/collapsed_font_color", C(pal["secondary"]))
    add("FoldableContainer/constants/h_separation", CONST["gap_small"])
    add("FoldableContainer/font_sizes/font_size", FONTS["body"])
    sb("FoldableContainer/styles/title_panel", "fold_title")
    sb("FoldableContainer/styles/title_hover_panel", "fold_title_hover")
    sb("FoldableContainer/styles/title_collapsed_panel", "fold_title_collapsed")
    sb("FoldableContainer/styles/title_collapsed_hover_panel", "fold_title_collapsed_hover")
    sb("FoldableContainer/styles/panel", "fold_panel")
    sb("FoldableContainer/styles/focus", "focus_soft")
    ex("FoldableContainer/icons/expanded_arrow", "arrow_down")
    ex("FoldableContainer/icons/expanded_arrow_mirrored", "arrow_down")
    ex("FoldableContainer/icons/folded_arrow", "arrow_right")
    ex("FoldableContainer/icons/folded_arrow_mirrored", "arrow_left")

    sb("ProgressBar/styles/background", "bar_bg")
    sb("ProgressBar/styles/fill", "bar_fill")
    add("ProgressBar/colors/font_color", C(pal["text"]))
    add("ProgressBar/font_sizes/font_size", FONTS["compact"])

    add("ScrollContainer/constants/scrollbar_h_separation", CONST["gap_small"])
    add("ScrollContainer/constants/scrollbar_v_separation", CONST["gap_small"])
    for bar in ("VScrollBar", "HScrollBar"):
        sb("%s/styles/scroll" % bar, "scroll_track")
        sb("%s/styles/scroll_focus" % bar, "scroll_track")
        sb("%s/styles/grabber" % bar, "scroll_grab")
        sb("%s/styles/grabber_highlight" % bar, "scroll_grab_hover")
        sb("%s/styles/grabber_pressed" % bar, "scroll_grab_hover")

    for slider in ("HSlider", "VSlider"):
        sb("%s/styles/slider" % slider, "slider_track")
        sb("%s/styles/grabber_area" % slider, "slider_grab")
        sb("%s/styles/grabber_area_highlight" % slider, "slider_grab_hover")
        ex("%s/icons/grabber" % slider, "grabber")
        ex("%s/icons/grabber_highlight" % slider, "grabber_highlight")
        ex("%s/icons/grabber_disabled" % slider, "grabber_disabled")

    sb("HSeparator/styles/separator", "separator")
    sb("VSeparator/styles/separator", "separator")
    for container in ("BoxContainer", "HBoxContainer", "VBoxContainer", "HFlowContainer", "VFlowContainer"):
        add("%s/constants/separation" % container, CONST["gap"])
    add("GridContainer/constants/h_separation", CONST["gap"])
    add("GridContainer/constants/v_separation", CONST["gap"])

    for role, size in [("Title", "title"), ("Subtitle", "subtitle"), ("Caption", "caption"),
                       ("Compact", "compact"), ("Micro", "micro")]:
        add("Go%sLabel/base_type" % role, '&"Label"')
        add("Go%sLabel/font_sizes/font_size" % role, FONTS[size])
    add("GoCaptionLabel/colors/font_color", C(pal["secondary"]))
    add("GoMicroLabel/colors/font_color", C(pal["muted"]))

    add("GoButton/base_type", '&"Button"')

    add("GoPrimaryButton/base_type", '&"Button"')
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color"):
        add("GoPrimaryButton/colors/%s" % key, C(pal["on_accent"]))
    add("GoPrimaryButton/colors/icon_normal_color", C(pal["on_accent"]))
    sb("GoPrimaryButton/styles/normal", "btn_primary")
    sb("GoPrimaryButton/styles/hover", "btn_primary_hover")
    sb("GoPrimaryButton/styles/pressed", "btn_primary_pressed")
    sb("GoPrimaryButton/styles/hover_pressed", "btn_primary_pressed")
    sb("GoPrimaryButton/styles/focus", "btn_focus_on_fill")

    # The filled danger button — its text is the same `on_accent` as the accent button's (the panel is
    # dark enough for white text to read).
    # 🛑 It has to read in **all three states.** The pressed panel is mixed toward the background and
    #    brightens, so matching only the normal panel drops it to 3.87:1 the moment it is pressed
    #    (measured 2026-09-13).
    danger_solid_ink = readable_everywhere(pal["on_accent"], [
        flatten(pal["danger"], _bg),
        flatten(mix(pal["danger"], pal["text"], 0.18), _bg),
        flatten(danger_solid_press_bg, _bg),
    ], 4.6)
    add("GoDangerSolidButton/base_type", '&"Button"')
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color"):
        add("GoDangerSolidButton/colors/%s" % key, C(danger_solid_ink))
    add("GoDangerSolidButton/colors/icon_normal_color", C(danger_solid_ink))
    sb("GoDangerSolidButton/styles/normal", "btn_danger_solid")
    sb("GoDangerSolidButton/styles/hover", "btn_danger_solid_hover")
    sb("GoDangerSolidButton/styles/pressed", "btn_danger_solid_pressed")
    sb("GoDangerSolidButton/styles/hover_pressed", "btn_danger_solid_pressed")
    sb("GoDangerSolidButton/styles/focus", "btn_focus_on_fill")

    add("GoDangerButton/base_type", '&"Button"')
    add("GoDangerButton/colors/font_color", C(danger_ink))
    add("GoDangerButton/colors/font_hover_color", C(danger_ink_hover))
    add("GoDangerButton/colors/font_pressed_color", C(danger_ink_hover))
    sb("GoDangerButton/styles/normal", "btn_danger")
    sb("GoDangerButton/styles/hover", "btn_danger_hover")
    sb("GoDangerButton/styles/pressed", "btn_danger_hover")
    sb("GoDangerButton/styles/hover_pressed", "btn_danger_hover")

    add("GoBareButton/base_type", '&"Button"')
    for state in empty_states:
        sb("GoBareButton/styles/%s" % state, "empty")
    sb("GoBareButton/styles/focus", "focus_soft")

    add("GoCompactButton/base_type", '&"Button"')
    add("GoCompactButton/font_sizes/font_size", FONTS["caption"])
    sb("GoCompactButton/styles/normal", "compact_normal")
    sb("GoCompactButton/styles/hover", "compact_hover")
    sb("GoCompactButton/styles/pressed", "compact_hover")
    sb("GoCompactButton/styles/hover_pressed", "compact_hover")
    sb("GoCompactButton/styles/disabled", "compact_normal")
    sb("GoCompactButton/styles/focus", "focus_soft")

    add("GoIconButton/base_type", '&"Button"')
    add("GoIconButton/colors/icon_normal_color", C(pal["muted"]))
    add("GoIconButton/colors/icon_hover_color", C(pal["text"]))
    add("GoIconButton/colors/icon_pressed_color", C(pal["accent"]))
    add("GoIconButton/colors/icon_focus_color", C(pal["secondary"]))
    add("GoIconButton/colors/icon_disabled_color", C(alpha(pal["muted"], 0.4)))
    sb("GoIconButton/styles/normal", "empty")
    sb("GoIconButton/styles/hover", "icon_hover")
    sb("GoIconButton/styles/pressed", "icon_hover")
    sb("GoIconButton/styles/hover_pressed", "icon_hover")
    sb("GoIconButton/styles/disabled", "empty")
    sb("GoIconButton/styles/focus", "focus_soft")

    add("GoListButton/base_type", '&"Button"')
    sb("GoListButton/styles/normal", "list_normal")
    sb("GoListButton/styles/hover", "list_hover")
    add("GoListButton/colors/font_pressed_color", C(list_press_ink))
    sb("GoListButton/styles/pressed", "list_hover")
    sb("GoListButton/styles/hover_pressed", "list_hover")
    sb("GoListButton/styles/disabled", "list_normal")
    sb("GoListButton/styles/focus", "focus_soft")

    add("GoPanel/base_type", '&"PanelContainer"')
    sb("GoPanel/styles/panel", "panel")
    add("GoCard/base_type", '&"PanelContainer"')
    sb("GoCard/styles/panel", "card")

    # Optional role fonts are scoped to this theme; existing presets keep their exact output.
    fonts = shape.get("fonts", {})
    font_targets = {"title": "GoTitleLabel", "subtitle": "GoSubtitleLabel", "caption": "GoCaptionLabel",
                    "body": "Label", "button": "Button"}
    unknown_fonts = set(fonts) - set(font_targets)
    if unknown_fonts:
        raise SystemExit("Unknown font roles: %s" % sorted(unknown_fonts))
    for role in fonts:
        ex(font_targets[role] + "/fonts/font", "font_" + role)
        if role == "body": ex("default_font", "font_" + role)
    steps = len(boxes) + len(assets) + 1 + (2 if cutting else 0) + int(forging) + len(fonts)
    lines = ['[gd_resource type="Theme" load_steps=%d format=3]' % steps, ""]
    if cutting:
        lines.append('[ext_resource type="Script" path="%s" id="cut"]' % CUT_SCRIPT)
        lines.append('[ext_resource type="Script" path="%s" id="bracket"]' % BRACKET_SCRIPT)
    if forging:
        lines.append('[ext_resource type="Script" path="%s" id="medieval"]' % MEDIEVAL_SCRIPT)
    for role, path in fonts.items():
        if not path.startswith(RES + "/") or not os.path.isfile(os.path.join(ADDON, path[len(RES) + 1:])):
            raise SystemExit("Font must exist inside the addon: %s" % path)
        lines.append('[ext_resource type="FontFile" path="%s" id="font_%s"]' % (path, role))
    for name in assets:
        lines.append('[ext_resource type="Texture2D" path="%s/assets/%s/%s.svg" id="%s"]' % (RES, variant, name, name))
    lines.append("")
    for bid, (btype, body) in boxes.items():
        lines.append('[sub_resource type="%s" id="%s"]' % (btype, bid))
        lines += body
        lines.append("")
    lines.append("[resource]")
    lines += sorted(T, key=lambda s: s.split(" = ")[0])
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("%s — %d entries · %d StyleBoxes · %d drawings" % (os.path.relpath(out_path, ADDON), len(T), len(boxes), len(assets)))
    for key, before, after, why in moved:
        print("   ↳ %-10s %s → %s  (%s)" % (key, svg_hex(before), svg_hex(after), why))


# 🛑 Once a new drawing (SVG) exists, Godot has to **actually import** it before it can be read — the
#    `.import` file alone is not enough. Skip it and a script that preloads the new theme fails to load,
#    leaving a headless check hanging silently (measured 2026-09-12).
IMPORT_HINT = ("Next: run `godot --headless --path . --import` once in the project (to import the new SVGs). "
               "Until then the checks and the demo cannot read the new theme.")

# ── Theme registry ──────────────────────────────────────────────────────
#
# 🔑 **One theme = a palette + a shape.** The four built-ins are written here; everything else comes from
#    `themes/palettes/*.json` — one file adds a theme without touching code (`tools/new_theme.py` writes
#    that file for you).

BUILTIN_THEMES = {
    "dark": (DARK, SHAPE_DEFAULT),
    "light": (LIGHT, SHAPE_DEFAULT),
    "scifi_dark": (SCIFI_DARK, SHAPE_CUT),
    "scifi_light": (SCIFI_LIGHT, SHAPE_CUT),
}
SHAPES = {"flat": SHAPE_DEFAULT, "cut": SHAPE_CUT,
          "medieval": {"kind": "medieval", "controls": "rounded", "radius": 4, "radius_small": 3,
                       "radius_large": 6, "material": 1, "ornament_scale": 1.0,
                       "grain_alpha": 0.035, "bevel_strength": 0.18}}
PALETTES_DIR = os.path.join(ADDON, "themes", "palettes")
# Keys a palette must carry — without them generation dies halfway with a KeyError. Say so up front.
PALETTE_KEYS = ("background", "surface", "surface_soft", "surface_high", "border", "text", "secondary",
                "muted", "accent", "on_accent", "success", "warning", "danger", "info", "scrim", "shadow", "track")


def parse_color(text):
    """`"#RRGGBB"` or `"#RRGGBB@0.35"` (with alpha) → a colour tuple."""
    if isinstance(text, (list, tuple)):
        return tuple(float(v) for v in text) + ((1.0,) if len(text) == 3 else ())
    body, _, alpha = str(text).partition("@")
    return hexc(body.strip(), float(alpha) if alpha else 1.0)


def load_palette_file(path, ancestors=()):
    """One JSON theme → (id, palette, shape, meta). `from` inherits a built-in theme and only what is written overrides it."""
    import json
    path = os.path.abspath(path)
    if path in ancestors:
        raise SystemExit("Palette inheritance cycle: %s" % path)
    with open(path, encoding="utf-8") as fh:
        spec = json.load(fh)
    tid = spec.get("id") or os.path.splitext(os.path.basename(path))[0]
    base = spec.get("from", "dark")
    base_meta = None
    if base in BUILTIN_THEMES:
        base_pal, base_shape = BUILTIN_THEMES[base]
    else:
        base_path = os.path.join(PALETTES_DIR, base + ".json")
        if not os.path.isfile(base_path):
            raise SystemExit("Unknown parent palette: %s" % base)
        _, base_pal, base_shape, base_meta = load_palette_file(base_path, ancestors + (path,))
    pal = dict(base_pal)
    for key, value in spec.get("palette", {}).items():
        if key.startswith("_"): continue
        pal[key] = parse_color(value)
    missing = [k for k in PALETTE_KEYS if k not in pal]
    if missing:
        raise SystemExit("🛑 %s: the palette is missing %s" % (path, ", ".join(missing)))
    shape_spec = spec.get("shape", base_shape)
    if isinstance(shape_spec, str):
        shape = dict(SHAPES[shape_spec])
    else:
        kind = shape_spec.get("kind", base_shape["kind"])
        shape = dict(base_shape if kind == base_shape["kind"] else SHAPES[kind])
        if "fonts" in shape_spec:
            shape_spec = dict(shape_spec, fonts={**shape.get("fonts", {}), **shape_spec["fonts"]})
        shape.update({k: v for k, v in shape_spec.items() if not k.startswith("_")})
    inherited_skin = base_meta["skin"] if base_meta else "scifi" if base.startswith("scifi") else "default"
    skin = spec.get("skin", inherited_skin)
    if isinstance(skin, dict) and isinstance(inherited_skin, dict):
        if skin.get("base", inherited_skin.get("base")) == inherited_skin.get("base"):
            skin = {**inherited_skin, **skin, "dials": {**inherited_skin.get("dials", {}), **skin.get("dials", {})}}
    meta = {"title": spec.get("title", tid),
            "dark": spec.get("dark", base_meta["dark"] if base_meta else base in ("dark", "scifi_dark")),
            "skin": skin,
            "icons": spec.get("icons", base_meta.get("icons", "") if base_meta else ""), "from": base}
    return tid, pal, shape, meta


SKIN_SCRIPTS = {
    "default": ("GoSkin", RES + "/core/go_skin.gd"),
    "scifi": ("GoSkinSciFi", RES + "/themes/skins/go_skin_scifi.gd"),
    "medieval": ("GoSkinMedieval", RES + "/themes/skins/go_skin_medieval.gd"),
}
SKINS_DIR = os.path.join(ADDON, "themes", "skins")


SKIN_SOURCES = {
    "default": os.path.join(ADDON, "core", "go_skin.gd"),
    "scifi": os.path.join(ADDON, "themes", "skins", "go_skin_scifi.gd"),
    "medieval": os.path.join(ADDON, "themes", "skins", "go_skin_medieval.gd"),
}
DIALS_TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "skin_dials.json")


def skin_dials():
    """Skin dial defaults — **GDScript is the only source.** It reads `@export var name := value`.

    🛑 Maintaining the table (`skin_dials.json`) by hand lets the two drift apart (2026-09-13, I-63). The
       parsing happens here; the table is a **generated artefact** left behind for the checks to read
       (`write_skin_dials_table`).
    """
    import re as _re
    out = {}
    pattern = _re.compile(r"^@export var (\w+) := (-?\d+(?:\.\d+)?)\s*$", _re.M)
    for name, path in SKIN_SOURCES.items():
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        table = {}
        for key, raw in pattern.findall(text):
            if key == "skin_name": continue
            table[key] = float(raw) if "." in raw else int(raw)
        out[name] = table
    return out


def write_skin_dials_table():
    """Leave the parsed dials in `tools/skin_dials.json` — the GDScript checks read it to verify the parser."""
    import json
    body = {"_help": "Generated — do not edit by hand. The source is the @export defaults in core/go_skin.gd "
                     "and themes/skins/go_skin_scifi.gd; make_theme.py parses them and writes them here. The "
                     "checks (presets · skins) compare this against the GDScript defaults to guard the parser."}
    body.update(skin_dials())
    with open(DIALS_TABLE, "w", encoding="utf-8") as fh:
        json.dump(body, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def write_skin_resource(tid, skin_spec):
    """When the JSON's `skin` is a dict, write **one skin resource** — `{"base": "scifi", "dials": {...}}`.

    🔑 This is the way to change the numbers without touching skin code: a `.tres` laying dial values over
    the `base` skin's script.
    """
    if not isinstance(skin_spec, dict):
        return None
    base = skin_spec.get("base", "default")
    if base not in SKIN_SCRIPTS:
        raise SystemExit("🛑 skin.base must be one of %s (got %r)" % (sorted(SKIN_SCRIPTS), base))
    script_class, script_path = SKIN_SCRIPTS[base]
    known = dict(skin_dials()["default"])
    known.update(skin_dials()[base])
    dials = {k: v for k, v in skin_spec.get("dials", {}).items() if not k.startswith("_")}
    unknown = sorted(set(dials) - set(known))
    if unknown:
        raise SystemExit("🛑 %s: unknown skin dial %s (available: %s)" % (tid, ", ".join(unknown), ", ".join(sorted(known))))
    os.makedirs(SKINS_DIR, exist_ok=True)
    path = os.path.join(SKINS_DIR, "gohud_skin_%s.tres" % tid)
    lines = ['[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]' % script_class, "",
             '[ext_resource type="Script" path="%s" id="script"]' % script_path, "",
             "[resource]", 'script = ExtResource("script")',
             'skin_name = "%s"' % skin_spec.get("name", tid)]
    for key in sorted(dials):
        value = dials[key]
        # Integer dials as integers, float dials as floats — on a type mismatch the engine drops the value silently.
        lines.append("%s = %s" % (key, int(value) if isinstance(known[key], int) and not isinstance(known[key], bool) else float(value)))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


def all_themes():
    """id → (palette, shape, meta). The four built-ins first, then `themes/palettes/*.json` in name order."""
    out = {tid: (pal, shape, None) for tid, (pal, shape) in BUILTIN_THEMES.items()}
    if os.path.isdir(PALETTES_DIR):
        for name in sorted(os.listdir(PALETTES_DIR)):
            if name.endswith(".json"):
                tid, pal, shape, meta = load_palette_file(os.path.join(PALETTES_DIR, name))
                out[tid] = (pal, shape, meta)
    return out


if __name__ == "__main__":
    import sys
    wanted = set(sys.argv[1:])
    themes = os.path.join(ADDON, "themes")
    write_skin_dials_table()
    registry = all_themes()
    unknown = wanted - set(registry)
    if unknown:
        raise SystemExit("🛑 unknown theme: %s (available: %s)" % (", ".join(sorted(unknown)), ", ".join(registry)))
    for tid, (pal, shape, meta) in registry.items():
        if wanted and tid not in wanted: continue
        build(pal, shape, tid, os.path.join(themes, "gohud_%s.tres" % tid))
        if meta is not None:
            made = write_skin_resource(tid, meta.get("skin"))
            if made: print("   ↳ skin resource %s" % os.path.relpath(made, ADDON))
    print(IMPORT_HINT)
