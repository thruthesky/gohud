# -*- coding: utf-8 -*-
"""The comic page — what `shape.kind = "comic"` draws for `tools/make_theme.py`.

    python3 addons/gohud/tools/make_theme.py comic_light comic_dark

The palettes (`themes/palettes/comic_*.json`) carry the colours; this file carries the **shapes** of a look drawn like
a comic panel: a bold ink outline (the palette's `border`) around every part on the surface colour, and a hard, faint
shadow dropped down and to the right of the things that stand off the page — keys, panels, cards, pills. The
code-drawn parts (chips, slots, badges, the joystick) are `themes/skins/go_skin_comic.gd`.

🔑 Every face is a `GoStyleBoxComic` (`widgets/go_stylebox_comic.gd`) that leaves its outline and shadow **unset**, so
   they come from `GoConfig.comic_border_width`, `comic_shadow_size` and `comic_shadow` when the face is drawn — one
   setting restyles every part. A face here only says how much of them it takes (`outline_scale`, `drop_scale`) or
   that it never drops a shadow (`shadow = 2`, a text field, a list row).
🔑 It only **reshapes** what `build()` already made — the same box ids and colours the generator chose (so every
   contrast gate still holds) apart from the outline, which becomes the ink.
🛑 **No size changes.** The outline is drawn inside the control and the shadow outside it, and the content margins
   stay as `build()` wrote them — a host that pins its own sizes sees the same minimum sizes.
"""
import re

# A face takes the whole outline unless it says otherwise; small parts take two thirds, thin tracks half.
SMALL = 0.67
THIN = 0.5
# Panels drop a deeper shadow than keys, small pills a shallower one.
PANEL_DROP = 1.5
SMALL_DROP = 0.5
# `GoStyleBoxComic.Shadow`: 0 follows `GoConfig.comic_shadow`, 1 always, 2 never.
FOLLOW, ON, OFF = 0, 1, 2
# Corner and side bits (`GoStyleBoxComic.TOP_LEFT`…, `LEFT`…).
TL, TR, BR, BL = 1, 2, 4, 8
LEFT, TOP, RIGHT, BOTTOM = 1, 2, 4, 8
# A list row's corner (dp) — small enough for a table row's 4dp padding (the cell audit wants the outline plus
# 0.3 × the corner inside it: 2 + 1.8).
LIST_RADIUS = 6

SHAPE = dict(
    kind="comic",
    controls="comic",
    radius=12,
    radius_small=8,
    radius_large=20,
)


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


def controls(pal):
    """Switch, checkbox, radio, slider handle and arrows drawn in ink: a bold outline, a faint block of shadow down and
    to the right. 🛑 The engine draws these as they are (no tint), so every colour is baked per theme — and they keep
    the size of the default family's drawings, so nothing that measures them moves. Their outline does not follow
    `GoConfig.comic_border_width` (an SVG is drawn once, at import)."""
    ink, acc, on = _svg(pal["border"]), _svg(pal["accent"]), _svg(pal["on_accent"])
    sur, hi, mut = _svg(pal["surface"]), _svg(pal["surface_high"]), _svg(pal["muted"])
    shade, shade_a = _svg(pal["shadow"]), max(0.18, min(0.6, pal["shadow"][3]))

    def wrap(w, h, body, disabled=False):
        group = '<g opacity=".38">%s</g>' % body if disabled else body
        return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % (
            w, h, w, h, group)

    def drop(shape):
        """The faint block behind a part, 1.5 down and right."""
        return shape.replace("/>", ' fill="%s" fill-opacity="%.2f" transform="translate(1.5 1.5)"/>' % (shade, shade_a), 1)

    def toggle(state_on, disabled, mirrored):
        knob_x = 27 if state_on != mirrored else 12
        track = '<rect x="1.5" y="3.5" width="35" height="17" rx="8.5"/>'
        body = drop(track)
        body += '<rect x="1.5" y="3.5" width="35" height="17" rx="8.5" fill="%s" stroke="%s" stroke-width="2"/>' % (
            acc if state_on else hi, ink)
        body += '<circle cx="%d" cy="12" r="5.5" fill="%s" stroke="%s" stroke-width="2"/>' % (knob_x, sur, ink)
        return wrap(40, 24, body, disabled)

    def check(state_on, disabled):
        frame = '<rect x="2" y="2" width="15" height="15" rx="3.5"/>'
        body = drop(frame)
        body += '<rect x="2" y="2" width="15" height="15" rx="3.5" fill="%s" stroke="%s" stroke-width="2"/>' % (
            acc if state_on else sur, ink)
        if state_on:
            body += ('<path d="M5.6 9.6 8.4 12.4 13.6 6.8" fill="none" stroke="%s" stroke-width="2.4" '
                     'stroke-linecap="round" stroke-linejoin="round"/>') % on
        return wrap(20, 20, body, disabled)

    def radio(state_on, disabled):
        body = drop('<circle cx="9.5" cy="9.5" r="7.5"/>')
        body += '<circle cx="9.5" cy="9.5" r="7.5" fill="%s" stroke="%s" stroke-width="2"/>' % (sur, ink)
        if state_on:
            body += '<circle cx="9.5" cy="9.5" r="3.6" fill="%s" stroke="%s" stroke-width="1.2"/>' % (acc, ink)
        return wrap(20, 20, body, disabled)

    def grabber(r, faded=False, halo=False):
        body = ""
        if halo:
            body += '<circle cx="10" cy="10" r="10" fill="%s" fill-opacity=".22"/>' % acc
        body += drop('<circle cx="9.5" cy="9.5" r="%g"/>' % r)
        body += '<circle cx="9.5" cy="9.5" r="%g" fill="%s" stroke="%s" stroke-width="2"/>' % (
            r, mut if faded else sur, ink)
        return wrap(20, 20, body)

    def arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>'
                ) % (ink, path)

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
    out["grabber"] = grabber(7)
    out["grabber_highlight"] = grabber(7, halo=True)
    out["grabber_disabled"] = grabber(6, faded=True)
    out["arrow_down"] = arrow("M4 6l4 4 4-4")
    out["arrow_right"] = arrow("M6 4l4 4-4 4")
    out["arrow_left"] = arrow("M10 4 6 8l4 4")
    return out


def restyle(pal, consts, boxes, T, flat, C, contrast):
    """Turn the boxes `build()` made into comic faces. `flat`, `C` and `contrast` are the generator's StyleBoxFlat
    writer, colour formatter and WCAG ratio (`C` is the one used here)."""
    ink = pal["border"][:3] + (1.0,)
    shadow = pal["shadow"]

    def field(bid):
        return _fields(boxes[bid][1]) if bid in boxes and boxes[bid][0] == "StyleBoxFlat" else None

    def comic(bid, edge=None, paint=None, radius=None, scale=1.0, drop_scale=1.0, shade=FOLLOW, pressed=False,
              corners=None, sides=None, inner=False):
        """Reshape box `bid` into a comic face: an outline in `edge` (the ink unless given) taking `scale` of the
        project's width, a shadow taking `drop_scale` of the project's size (`shade` ON/OFF overrides the project's
        switch), `pressed` pushes it in, `inner` draws it just inside the ink of the face under it (a focus ring).
        Colours, padding and the hollow centre stay as `build()` wrote them."""
        f = field(bid)
        if f is None:
            return
        lines = ['script = ExtResource("comic")']
        for side in ("left", "top", "right", "bottom"):
            key = "content_margin_%s" % side
            if key in f:
                lines.append("%s = %s" % (key, f[key]))
        if paint is not None:
            lines.append("bg_color = %s" % C(paint))
        elif "bg_color" in f:
            lines.append("bg_color = %s" % f["bg_color"])
        lines.append("border_color = %s" % C(edge if edge is not None else ink))
        if scale != 1.0:
            lines.append("outline_scale = %g" % scale)
        corner = radius if radius is not None else int(f.get("corner_radius_top_left", consts["radius"]))
        lines.append("radius = %g" % corner)
        if corners is not None:
            lines.append("corners = %d" % corners)
        if sides is not None:
            lines.append("sides = %d" % sides)
        if f.get("draw_center") == "false":
            lines.append("draw_center = false")
        if shade != FOLLOW:
            lines.append("shadow = %d" % shade)
        lines.append("shadow_color = %s" % C(shadow))
        if drop_scale != 1.0:
            lines.append("drop_scale = %g" % drop_scale)
        if pressed:
            lines.append("pressed = true")
        if inner:
            lines.append("inner = true")
        boxes[bid] = ("StyleBox", lines)

    accent, surface = pal["accent"], pal["surface"]
    R, RS = consts["radius"], consts["radius_small"]
    faint = ink[:3] + (0.4,)

    # ── Keys — ink round the plate, a shadow under it that goes when pressed. The filled keys keep their colour. ──
    for bid in ("btn_normal", "btn_hover", "btn_primary", "btn_primary_hover", "btn_danger", "btn_danger_hover",
                "btn_danger_solid", "btn_danger_solid_hover"):
        comic(bid)
    for bid in ("btn_pressed", "btn_primary_pressed", "btn_danger_solid_pressed"):
        comic(bid, pressed=True)
    # The raised twins (`GoConfig.button_glow`, `GoStyle.glow()`) keep their shadow even with the project's off.
    for bid in ("btn_primary_glow", "btn_primary_glow_hover", "btn_danger_solid_glow", "btn_danger_solid_glow_hover"):
        comic(bid, shade=ON, drop_scale=1.25)
    for bid in ("btn_primary_glow_pressed", "btn_danger_solid_glow_pressed"):
        comic(bid, shade=ON, drop_scale=1.25, pressed=True)
    comic("btn_disabled", edge=faint, shade=OFF)
    # The focus rings — the accent (or the label colour on a filled key) just inside the ink, so the key keeps its
    # outline (a ring over it turned a focused filled key's ink white).
    comic("btn_focus", edge=accent, scale=SMALL, shade=OFF, inner=True)
    comic("btn_focus_on_fill", edge=pal["on_accent"], scale=SMALL, shade=OFF, inner=True)
    comic("focus_soft", edge=accent, scale=SMALL, shade=OFF)
    # The small pill buttons.
    comic("compact_normal", scale=SMALL, drop_scale=SMALL_DROP)
    comic("compact_hover", scale=SMALL, drop_scale=SMALL_DROP)
    # List rows stack — no shadow to fall on the next row, a thinner line and a small corner.
    for bid in ("list_normal", "list_hover"):
        comic(bid, scale=SMALL, shade=OFF, radius=LIST_RADIUS)

    # ── Panels — a comic panel: the ink frame and a deeper shadow. Opacity and padding stay. ──
    for bid in ("panel", "popup"):
        comic(bid, drop_scale=PANEL_DROP, radius=consts["radius_large"] if bid == "panel" else R)
    for bid in ("panel_solid", "card", "hud", "notice"):
        comic(bid)
    # 🛑 A tooltip is its own popup window — a shadow outside it would be cut at the window's edge.
    comic("tooltip", scale=SMALL, shade=OFF)

    # ── Text fields — an inked box on the surface, flat on the page. ──
    comic("edit_normal", paint=surface, shade=OFF, radius=RS)
    comic("edit_focus", paint=surface, edge=accent, shade=OFF, radius=RS)

    # ── Tabs — the chosen one is a panel tab inked on three sides, open at the bottom. ──
    comic("tab_selected", sides=LEFT | TOP | RIGHT, corners=TL | TR, shade=OFF)

    # ── Folding sections — the title and its body read as one inked panel. ──
    for bid in ("fold_title", "fold_title_hover"):
        comic(bid, sides=LEFT | TOP | RIGHT, corners=TL | TR, shade=OFF)
    for bid in ("fold_title_collapsed", "fold_title_collapsed_hover"):
        comic(bid, shade=OFF)
    comic("fold_panel", sides=LEFT | RIGHT | BOTTOM, corners=BR | BL, shade=OFF)

    # ── Bars and sliders — inked tubes. 🛑 A small corner, not a 999 pill: the cell audit reads the radius as room. ──
    for bid in ("bar_bg", "bar_fill"):
        comic(bid, scale=SMALL, shade=OFF, radius=RS)
    for bid in ("slider_track", "slider_grab", "slider_grab_hover"):
        comic(bid, scale=THIN, shade=OFF, radius=3)
