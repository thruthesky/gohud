# -*- coding: utf-8 -*-
"""The toy box — what `shape.kind = "kids"` draws for `tools/make_theme.py`.

    python3 addons/gohud/tools/make_theme.py kids_light kids_dark

The palettes (`themes/palettes/kids_*.json`) carry the colours; this file carries the **shapes** of a look made for
children: chunky outlines, a solid lip under everything you press (a toy key, a candy button — it sinks when pressed),
a sunken well for text fields, bubble tabs, and bars with a jelly shine. The code-drawn parts (slots, chips, badges,
the joystick, chart colours) are `themes/skins/go_skin_kids.gd`.

🔑 It only **reshapes** what `build()` already made — the same box ids and the same colours the generator chose (so
   every contrast gate still holds); only borders, corners, the lip and the pressed sink change. Nothing here runs for
   the other looks (`check_generated.py`).
🛑 **No size changes.** The lip lives inside the control's rectangle and the content margins keep their sum — a host
   that pins its own sizes (laryen3d's SSOT §9) sees the same minimum sizes. The label moves up by half the lip so it
   sits in the middle of the face, and a press moves the face (and the label) down.
🛑 One `border_color` per StyleBoxFlat: the outline and the lip are one colour — a shade of the face for things you
   press, the panel's own border colour for panels (on the dark look that reads as a rim of light).
"""
import re

# A pressable's lip (dp) — the solid edge under it that makes it a toy key. Small parts get the small lip.
LIP = 5
LIP_SMALL = 3
# How far a pressed face sinks; its lip shrinks to PRESSED_LIP.
PUSH = 3
PRESSED_LIP = 2
# The outline of a toy face.
EDGE = 2
# A panel's lip — a sticker block, not a key.
PANEL_LIP = 4
# Larger than any control — StyleBoxFlat rounds both ends into a pill.
FULL = 999

SHAPE = dict(
    kind="kids",
    controls="kids",
    radius=18,
    radius_small=12,
    radius_large=34,
)


def _mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (a[3],)


def _shade(c, t):
    """Towards black, keeping the alpha — the lip under a face."""
    return _mix(c, (0.0, 0.0, 0.0, 1.0), t)


def _tint(c, t):
    """Towards white — a shine."""
    return _mix(c, (1.0, 1.0, 1.0, 1.0), t)


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
    """Switch, checkbox, radio, slider handle and arrows as toys: each sits on its own lip, the knob carries a shine.
    🛑 The engine draws these as they are (no tint), so every colour is baked per theme — and the canvas keeps the
    size of the default family's drawings, so nothing that measures them moves."""
    acc, on = pal["accent"], pal["on_accent"]
    mut, hi, sur = pal["muted"], pal["surface_high"], pal["surface"]
    A, ON, M, HI, S = _svg(acc), _svg(on), _svg(mut), _svg(hi), _svg(sur)
    LIPA, LIPM = _svg(_shade(acc, 0.35)), _svg(_shade(mut, 0.25))
    SHINE = _svg(_tint(acc, 0.55))
    sec = _svg(pal["secondary"])

    def wrap(w, h, body, disabled=False):
        group = '<g opacity=".38">%s</g>' % body if disabled else body
        return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % (
            w, h, w, h, group)

    def toggle(state_on, disabled, mirrored):
        knob_x = 28 if state_on != mirrored else 12
        if state_on:
            body = ('<rect x="1" y="2" width="38" height="21" rx="10.5" fill="%s"/>'          # lip
                    '<rect x="1" y="1" width="38" height="20" rx="10" fill="%s"/>'            # track
                    '<circle cx="%d" cy="11.5" r="8" fill="%s"/>'                             # knob lip
                    '<circle cx="%d" cy="10.5" r="7.5" fill="%s"/>'
                    '<ellipse cx="%g" cy="8" rx="3.2" ry="1.8" fill="#FFFFFF" fill-opacity=".7"/>'  # shine
                    ) % (LIPA, A, knob_x, LIPA, knob_x, ON, knob_x - 1.5)
        else:
            body = ('<rect x="1" y="2" width="38" height="21" rx="10.5" fill="%s"/>'
                    '<rect x="1.75" y="1.75" width="36.5" height="18.5" rx="9.25" fill="%s" stroke="%s" stroke-width="1.5"/>'
                    '<circle cx="%d" cy="11.5" r="6.5" fill="%s"/>'
                    '<circle cx="%d" cy="10.5" r="6" fill="%s"/>') % (LIPM, HI, M, knob_x, LIPM, knob_x, M)
        return wrap(40, 24, body, disabled)

    def check(state_on, disabled):
        if state_on:
            body = ('<rect x="1" y="2.5" width="18" height="16.5" rx="5.5" fill="%s"/>'
                    '<rect x="1" y="1" width="18" height="16" rx="5.5" fill="%s"/>'
                    '<path d="M5.2 9.1 8.4 12.2 14.6 5.9" fill="none" stroke="%s" stroke-width="2.4" '
                    'stroke-linecap="round" stroke-linejoin="round"/>') % (LIPA, A, ON)
        else:
            body = ('<rect x="1" y="2.5" width="18" height="16.5" rx="5.5" fill="%s"/>'
                    '<rect x="1.75" y="1.75" width="16.5" height="14.5" rx="4.75" fill="%s" stroke="%s" '
                    'stroke-width="1.5"/>') % (LIPM, S, M)
        return wrap(20, 20, body, disabled)

    def radio(state_on, disabled):
        if state_on:
            body = ('<circle cx="10" cy="10.8" r="9" fill="%s"/>'
                    '<circle cx="10" cy="9.6" r="8.6" fill="%s"/>'
                    '<circle cx="10" cy="9.6" r="3.8" fill="%s"/>') % (LIPA, A, ON)
        else:
            body = ('<circle cx="10" cy="10.8" r="9" fill="%s"/>'
                    '<circle cx="10" cy="9.6" r="7.9" fill="%s" stroke="%s" stroke-width="1.5"/>') % (LIPM, S, M)
        return wrap(20, 20, body, disabled)

    def grabber(r, faded=False, halo=False):
        ink, lip = (M, LIPM) if faded else (A, LIPA)
        body = ""
        if halo:
            body += '<circle cx="10" cy="10" r="10" fill="%s" fill-opacity=".22"/>' % A
        body += ('<circle cx="10" cy="%g" r="%g" fill="%s"/>'
                 '<circle cx="10" cy="%g" r="%g" fill="%s"/>'
                 '<ellipse cx="8.4" cy="%g" rx="%g" ry="%g" fill="#FFFFFF" fill-opacity=".65"/>') % (
            10 + 1.2, r, lip, 10 - 0.4, r - 0.3, ink, 10 - r * 0.45, r * 0.4, r * 0.24)
        return wrap(20, 20, body)

    def arrow(path):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none" '
                'stroke="%s" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>'
                ) % (sec, path)

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
    out["grabber"] = grabber(8)
    out["grabber_highlight"] = grabber(8, halo=True)
    out["grabber_disabled"] = grabber(7, faded=True)
    out["arrow_down"] = arrow("M4 6l4 4 4-4")
    out["arrow_right"] = arrow("M6 4l4 4-4 4")
    out["arrow_left"] = arrow("M10 4 6 8l4 4")
    return out


def restyle(pal, consts, boxes, T, flat, C, contrast):
    """Turn the boxes `build()` made into toys. `flat`, `C` and `contrast` are the generator's StyleBoxFlat writer,
    colour formatter and WCAG ratio (unused here: no colour a gate reads is changed)."""

    def field(bid):
        return _fields(boxes[bid][1]) if bid in boxes and boxes[bid][0] == "StyleBoxFlat" else None

    def margins(f):
        return [float(f.get("content_margin_%s" % side, "-1")) for side in ("left", "top", "right", "bottom")]

    def toy(bid, lip=LIP, edge=EDGE, radius=None, pressed=False, ink=None, rim=None, well=False, shine=None,
            centre=True, paint=None):
        """Reshape box `bid`: outline `edge`, a lip of `lip` under it in `ink` (a shade of the face unless given),
        the face sunk by PUSH when `pressed`. `rim` uses the panel's own border colour. `well` puts the heavy edge on
        top (a sunken text field). `shine` puts a light edge on top only (a jelly fill). `centre` moves the label up
        by half the lip so it sits in the middle of the face."""
        f = field(bid)
        if f is None:
            return
        face = paint if paint is not None else _parse_color(f["bg_color"]) if "bg_color" in f else None
        old_edge = _parse_color(f["border_color"]) if "border_color" in f else None
        m = margins(f)
        corner = radius if radius is not None else int(f.get("corner_radius_top_left", consts["radius"]))
        if shine is not None:
            colour, widths = shine, (0, max(2, edge), 0, 0)
        elif well:
            colour = ink or old_edge or _shade(face, 0.25)
            widths = (edge, lip, edge, edge)
        else:
            if rim and old_edge is not None:
                colour = old_edge
            elif ink is not None:
                colour = ink
            else:
                colour = _shade(face, 0.32) if face is not None else old_edge
            bottom = PRESSED_LIP if pressed else lip
            widths = (edge, edge, edge, bottom)
        lines = flat(bg=face, border=colour, radius=corner, borders=widths,
                     margins=None, draw_center="draw_center = false" not in boxes[bid][1])
        # The label sits in the middle of the face: up by half the lip, down by the sink when pressed. The two
        # content margins keep their sum, so the control keeps its size.
        if all(v >= 0 for v in m):
            move = 0.0
            if centre and shine is None and not well:
                move = -(widths[3] - widths[1]) / 2.0
                if pressed: move += PUSH / 2.0
            top, bottom = m[1] + move, m[3] - move
            if top < 0 or bottom < 0:
                top, bottom = m[1], m[3]
            lines = ["content_margin_left = %g" % m[0], "content_margin_top = %g" % top,
                     "content_margin_right = %g" % m[2], "content_margin_bottom = %g" % bottom] + lines
        if pressed:
            # 🔑 A **negative expand margin** takes the face's top down without moving the control — it sinks.
            lines.append("expand_margin_top = %g" % -PUSH)
        for key in ("expand_margin_left", "expand_margin_right", "expand_margin_bottom"):
            if key in f:
                lines.append("%s = %s" % (key, f[key]))
        # Everything this does not reshape stays as the generator wrote it — a raised button's glow, anti-aliasing.
        for key, value in f.items():
            if key.startswith("shadow_") or key.startswith("anti_aliasing") or key.startswith("skew"):
                lines.append("%s = %s" % (key, value))
        if corner >= FULL:
            lines = [l.replace("corner_detail = 8", "corner_detail = 16") for l in lines]
        boxes[bid] = ("StyleBoxFlat", lines)

    accent = pal["accent"]
    danger = pal["danger"]
    surface, text = pal["surface"], pal["text"]
    R, RS = consts["radius"], consts["radius_small"]
    night = sum(pal["background"][:3]) / 3.0 < 0.5
    sky = pal.get("info_vivid", pal["info"])
    sun = pal.get("warning_vivid", pal["warning"])
    mint = pal.get("success_vivid", pal["success"])

    def crayon(colour, amount):
        """A crayon laid on the surface: pastel on the day look, deep on the night look."""
        return _mix(surface, colour, amount)

    # 🖍 Each family of controls takes its own crayon, so a screen of them is a box of colours, not one purple:
    #    the primary key grape (the accent), the normal key a sky rim, the small pill buttons sunshine (mint at
    #    night), folding titles mint, tooltips sunshine. The text colour the generator picked stays — every face
    #    below is a light pastel on the day look (dark text) or a deep tone at night (light text), and
    #    `check_contrast.py` reads them.
    normal_rim = _mix(sky, surface, 0.35 if night else 0.2)
    sweet = crayon(mint, 0.24) if night else crayon(sun, 0.42)
    sweet_lip = _shade(crayon(mint, 0.6), 0.2) if night else _shade(sun, 0.22)
    leaf = crayon(mint, 0.26) if night else crayon(mint, 0.3)

    # ── Pressables — a toy key with a lip; a press sinks it. ──
    for bid in ("btn_normal", "btn_hover"):
        toy(bid, ink=normal_rim)
    toy("btn_pressed", ink=normal_rim, pressed=True)
    toy("btn_disabled", lip=PRESSED_LIP, rim=True)
    for bid in ("btn_primary", "btn_primary_hover", "btn_primary_glow", "btn_primary_glow_hover"):
        toy(bid, ink=_shade(accent, 0.38))
    for bid in ("btn_primary_pressed", "btn_primary_glow_pressed"):
        toy(bid, ink=_shade(accent, 0.38), pressed=True)
    for bid in ("btn_danger", "btn_danger_hover"):
        toy(bid, ink=_mix(danger, pal["surface"], 0.25))
    for bid in ("btn_danger_solid", "btn_danger_solid_hover", "btn_danger_solid_glow", "btn_danger_solid_glow_hover"):
        toy(bid, ink=_shade(danger, 0.35))
    for bid in ("btn_danger_solid_pressed", "btn_danger_solid_glow_pressed"):
        toy(bid, ink=_shade(danger, 0.35), pressed=True)
    # The small pill buttons — a sweet, not a key.
    toy("compact_normal", lip=LIP_SMALL, radius=FULL, paint=sweet, ink=sweet_lip)
    # 🛑 The hover face is also the pressed one (the generator maps both), and a pressed label takes the accent —
    #    so at night the hover goes **darker** (towards the backdrop), where the sunny accent still reads 4.5:1.
    hover_to = pal["background"] if night else text
    toy("compact_hover", lip=LIP_SMALL, radius=FULL, paint=_mix(sweet, hover_to, 0.18 if night else 0.06), ink=sweet_lip)
    # List rows — little blocks stacked in a toy box.
    for bid in ("list_normal", "list_hover"):
        toy(bid, lip=LIP_SMALL, rim=True)
    # Folding section titles — leaf-green blocks.
    for bid in ("fold_title", "fold_title_collapsed"):
        toy(bid, lip=LIP_SMALL, paint=leaf, ink=_shade(crayon(mint, 0.7), 0.15))
    for bid in ("fold_title_hover", "fold_title_collapsed_hover"):
        toy(bid, lip=LIP_SMALL, paint=_mix(leaf, text, 0.06), ink=_shade(crayon(mint, 0.7), 0.15))

    # ── Panels — sticker blocks: a rim and a lip in their own border colour. Margins stay as they are. ──
    for bid in ("panel", "panel_solid", "card", "popup", "hud", "notice"):
        toy(bid, lip=PANEL_LIP, rim=True, centre=False)
    toy("tooltip", lip=LIP_SMALL, paint=crayon(sun, 0.3 if night else 0.4), ink=_shade(sun, 0.25), centre=False)

    # ── Text fields — a sunken well: the heavy edge on top. ──
    toy("edit_normal", lip=4, well=True, radius=RS + 2)
    toy("edit_focus", lip=4, well=True, radius=RS + 2, ink=accent)

    # ── Tabs — the chosen one is a bubble on a lip; the others stay quiet. ──
    toy("tab_selected", lip=LIP_SMALL, radius=FULL, centre=True)
    f = field("tab_hovered")
    if f is not None:
        toy("tab_hovered", lip=LIP_SMALL, radius=FULL, rim=True)

    # ── Bars, sliders, scroll grabbers — round jelly with a shine on top; tracks are grooves. ──
    for bid in ("bar_fill", "slider_grab", "slider_grab_hover"):
        g = field(bid)
        if g is not None and "bg_color" in g:
            toy(bid, radius=FULL, shine=_tint(_parse_color(g["bg_color"]), 0.5), centre=False)
    for bid in ("bar_bg", "slider_track"):
        g = field(bid)
        if g is not None and "bg_color" in g:
            toy(bid, radius=FULL, well=True, lip=2, edge=0, ink=_shade(_parse_color(g["bg_color"]), 0.12), centre=False)
    for bid in ("scroll_grab", "scroll_grab_hover"):
        g = field(bid)
        if g is not None:
            toy(bid, radius=FULL, edge=0, lip=0, centre=False)
