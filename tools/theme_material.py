# -*- coding: utf-8 -*-
"""Material 3 Expressive for `tools/make_theme.py` — what `shape.kind = "material"` draws.

    python3 addons/gohud/tools/make_theme.py material_light material_dark

The palettes (`themes/palettes/material_*.json`) carry the colours; this file carries the **shapes,
sizes and type** of the M3 components. Every number comes from the M3 token set
(github.com/material-components/material-web, `tokens/versions/latest`, read 2026-10-02) — the token
file is named next to each block so the next person can check it.

🔑 It only **replaces** what `build()` already defined — the same box ids, the same theme keys — so every
   widget reads a Material theme exactly the way it reads the other six. New boxes are added only where
   M3 needs a face gohud does not have (the outlined field, the vertical slider).
🛑 Nothing here runs for the other looks — their output stays exactly as it was (`check_generated.py`).
🛑 Where gohud's own gates overrule the spec, the gate wins and the comment says so: a disabled label
   reads at 4.5:1 (M3 fades it to 38%), and snackbars keep a light plate (their text colour is a token
   the widget picks, so an inverse plate would put dark text on dark).
"""

RES = "res://addons/gohud"
ROBOTO = RES + "/assets/fonts/roboto/Roboto.ttf"

# The `wght` axis tag as Godot stores it in `FontVariation.variation_opentype` (`TextServer.name_to_tag("wght")`).
WGHT = 2003265652

# md.sys.shape.corner.full — larger than any plate, so StyleBoxFlat rounds both ends into a pill.
FULL = 999

# button-small — the plate is 40dp tall inside the 48dp touch target (`touch`).
PLATE = 40
# button-xsmall — the compact button's plate inside the same 48dp target.
PLATE_XS = 32

SHAPE = dict(
    kind="material",
    controls="material",
    radius=12,             # corner.medium — cards
    radius_small=8,        # corner.small — chips, segments, small cells
    radius_large=28,       # corner.extra-large — dialogs and sheets
    button_height=48,      # the touch target; the plate is PLATE tall (see `_inset`)
    padding=24,            # dialog padding
    gap=12,                # button-group-standard between-space
    gap_small=8,
    gap_large=24,
    compact_padding_x=12,  # button-xsmall leading/trailing space
    compact_padding_y=6,
    # Content margins of a button. 🛑 The top and bottom carry the 48dp height on their own — a plain
    #    `Button.new()` never passes through `GoStyle`, and without them its plate would shrink to the text.
    button_padding=(16, 15, 16, 15),
    # 🛑 Roboto for the **title, subtitle and caption** roles only (the buttons get it below, at weight 500).
    #    Body text keeps the host's font — a `body` font would also replace `default_font`, and a project's
    #    own Korean, Japanese or Chinese font would vanish from every gohud widget. Cinzel follows the same rule.
    fonts={"title": ROBOTO, "subtitle": ROBOTO, "caption": ROBOTO},
)

# Filled card content padding (card padding 16dp) — also written out as the `padding_compact` token.
CARD_PADDING = 16

# md.sys.typescale — role → size (sp). The role is the **size name** gohud uses.
FONT_SIZES = dict(
    micro=11,      # label-small
    compact=12,    # label-medium · body-small
    caption=14,    # body-medium · label-large
    body=16,       # body-large
    button=14,     # label-large (button-small)
    subtitle=24,   # headline-small — the dialog headline (`GoSurface` titles use this role)
    title=28,      # headline-medium
)

# md.sys.typescale line heights (dp). Godot adds `line_spacing` to the font's own height, and Roboto's ascent +
# descent is 1.172 em — so the spacing is the line height minus that.
LINE_HEIGHTS = dict(micro=16, compact=16, caption=20, body=24, subtitle=32, title=36)
ROBOTO_EM = 1.172

# md.sys.state — the state-layer opacities.
HOVER, FOCUS, PRESSED, DRAGGED = 0.08, 0.10, 0.10, 0.16

# md.sys.elevation level → a single StyleBoxFlat shadow (alpha factor, blur, drop). M3 draws two layers
# (key + ambient); one layer is the closest a StyleBoxFlat gets.
ELEVATION = {1: (0.15, 2, 1), 2: (0.18, 4, 2), 3: (0.22, 8, 3)}


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t, 6) for i in range(4))


def _alpha(c, a):
    return (c[0], c[1], c[2], round(a, 6))


def _svg(c):
    return "#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c[:3])


def roles(pal):
    """The M3 colour roles, read from the palette. gohud's required tokens already are some of them
    (`accent` = primary, `background` = surface …); the rest are the optional `md_*` tokens. A palette
    that inherits from a Material one but leaves an `md_*` key out falls back to a derived colour."""
    def md(name, fallback):
        return pal.get("md_" + name, fallback)
    primary, on_primary = pal["accent"], pal["on_accent"]
    surface, on_surface = pal["background"], pal["text"]
    out = dict(
        primary=primary, on_primary=on_primary,
        surface=surface, on_surface=on_surface, on_surface_variant=pal["secondary"],
        outline=pal["border"], error=pal["danger"],
        secondary=md("secondary", primary),
        on_secondary=md("on_secondary", on_primary),
        secondary_container=md("secondary_container", _mix(surface, primary, 0.18)),
        on_secondary_container=md("on_secondary_container", on_surface),
        error_container=md("error_container", _mix(surface, pal["danger"], 0.16)),
        on_error_container=md("on_error_container", on_surface),
        on_error=md("on_error", on_primary),
        outline_variant=md("outline_variant", _mix(surface, pal["border"], 0.4)),
        inverse_surface=md("inverse_surface", on_surface),
        inverse_on_surface=md("inverse_on_surface", surface),
        surface_container=md("surface_container", pal["surface"]),
        surface_container_low=md("surface_container_low", pal["surface"]),
        surface_container_highest=md("surface_container_highest", pal["surface_high"]),
    )
    return out


# ── Control artwork ─────────────────────────────────────────────────────

def controls(pal):
    """The switch, checkbox, radio, slider handle and arrows — drawn to the M3 component tokens.

    switch (`_md-comp-switch.scss`): track 52×32 with a 2dp outline, handle 16 off / 24 on.
    checkbox (`_md-comp-checkbox.scss`): 18dp, corner 2, outline 2.
    radio (`_md-comp-radio-button.scss`): 20dp, ring 2, dot 10.
    slider (`_md-comp-slider.scss`): the Expressive handle is a 4×44 bar, not a dot.
    Disabled faces use the disabled roles of each token file (on-surface at 38% or 12%, the switch's handle in
    `surface`) — not the enabled drawing faded, which would leave a selected control tinted primary.
    🛑 The engine draws these as they are — every colour is baked per theme, like the other families.
    """
    r = roles(pal)
    primary, on_primary = _svg(r["primary"]), _svg(r["on_primary"])
    outline, variant = _svg(r["outline"]), _svg(r["on_surface_variant"])
    track_off = _svg(r["surface_container_highest"])
    ink = _svg(r["on_surface"])
    ground = _svg(r["surface"])

    def wrap(w, h, body, disabled=False):
        group = '<g opacity=".38">%s</g>' % body if disabled else body
        return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % (w, h, w, h, group)

    def toggle(state_on, disabled, mirrored):
        if state_on:
            knob = 16 if mirrored else 36
            if disabled:   # track on-surface 12%, handle surface
                body = ('<rect x="0" y="0" width="52" height="32" rx="16" fill="%s" fill-opacity=".12"/>'
                        '<circle cx="%d" cy="16" r="12" fill="%s"/>') % (ink, knob, ground)
            else:
                body = ('<rect x="0" y="0" width="52" height="32" rx="16" fill="%s"/>'
                        '<circle cx="%d" cy="16" r="12" fill="%s"/>') % (primary, knob, on_primary)
        else:
            knob = 36 if mirrored else 16
            if disabled:   # track and outline on-surface 12%, handle on-surface 38%
                body = ('<rect x="1" y="1" width="50" height="30" rx="15" fill="%s" fill-opacity=".12" stroke="%s" '
                        'stroke-opacity=".12" stroke-width="2"/><circle cx="%d" cy="16" r="8" fill="%s" fill-opacity=".38"/>'
                        ) % (track_off, ink, knob, ink)
            else:
                body = ('<rect x="1" y="1" width="50" height="30" rx="15" fill="%s" stroke="%s" stroke-width="2"/>'
                        '<circle cx="%d" cy="16" r="8" fill="%s"/>') % (track_off, outline, knob, outline)
        return wrap(52, 32, body)

    def check(state_on, disabled):
        if state_on:
            box_ink, mark = (ink, ground) if disabled else (primary, on_primary)
            body = ('<rect x="0" y="0" width="18" height="18" rx="2" fill="%s"%s/>'
                    '<path d="M4.2 9.3 7.4 12.5 13.8 6" fill="none" stroke="%s" stroke-width="2" '
                    'stroke-linecap="square" stroke-linejoin="miter"/>') % (box_ink, ' fill-opacity=".38"' if disabled else "", mark)
        else:
            body = '<rect x="1" y="1" width="16" height="16" rx="1" fill="none" stroke="%s"%s stroke-width="2"/>' % (
                ink if disabled else variant, ' stroke-opacity=".38"' if disabled else "")
        return wrap(18, 18, body)

    def radio(state_on, disabled):
        ring = ink if disabled else (primary if state_on else variant)
        fade = ' opacity=".38"' if disabled else ""
        body = '<circle cx="10" cy="10" r="9" fill="none" stroke="%s" stroke-width="2"/>' % ring
        if state_on: body += '<circle cx="10" cy="10" r="5" fill="%s"/>' % ring
        return wrap(20, 20, '<g%s>%s</g>' % (fade, body) if disabled else body)

    out = {}
    for state_on in (True, False):
        for disabled in (False, True):
            for mirrored in (False, True):
                name = "toggle_%s%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "", "_mirrored" if mirrored else "")
                out[name] = toggle(state_on, disabled, mirrored)
        for disabled in (False, True):
            out["check_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = check(state_on, disabled)
            out["radio_%s%s" % ("on" if state_on else "off", "_disabled" if disabled else "")] = radio(state_on, disabled)
    bar = '<rect x="0" y="0" width="%d" height="%d" rx="2" fill="%s"/>'
    out["grabber"] = wrap(4, 44, bar % (4, 44, primary))
    out["grabber_highlight"] = wrap(4, 44, bar % (4, 44, primary))
    out["grabber_disabled"] = wrap(4, 44, bar % (4, 44, ink), True)
    # 🔑 A vertical slider lays the same bar across its track — the engine reads the handle from the
    #    `VSlider` type, so it gets drawings of its own.
    out["grabber_vertical"] = wrap(44, 4, bar % (44, 4, primary))
    out["grabber_vertical_highlight"] = wrap(44, 4, bar % (44, 4, primary))
    out["grabber_vertical_disabled"] = wrap(44, 4, bar % (44, 4, ink), True)
    # The dropdown arrow is M3's filled `arrow_drop_down`; the fold arrows are chevrons.
    out["arrow_down"] = wrap(16, 16, '<path d="M3.5 6h9L8 11z" fill="%s"/>' % variant)
    chevron = ('<path d="%s" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" '
               'stroke-linejoin="round"/>')
    out["arrow_right"] = wrap(16, 16, chevron % ("M6 3.5 10.5 8 6 12.5", variant))
    out["arrow_left"] = wrap(16, 16, chevron % ("M10 3.5 5.5 8 10 12.5", variant))
    return out


# ── Theme ──────────────────────────────────────────────────────────────

def restyle(pal, consts, boxes, T, flat, C, contrast):
    """Turn the boxes and entries `build()` made into the M3 components. `flat`, `C` and `contrast` are
    the generator's StyleBoxFlat writer, colour formatter and WCAG ratio."""
    r = roles(pal)
    shadow = pal["shadow"]

    def put(key, value):
        T[:] = [line for line in T if line.split(" = ")[0] != key]
        T.append("%s = %s" % (key, value))

    def sb(key, bid):
        put(key, 'SubResource("%s")' % bid)

    def lift(level):
        """md.sys.elevation.levelN as one StyleBoxFlat shadow."""
        factor, blur, drop = ELEVATION[level]
        return dict(shadow=(_alpha(shadow, shadow[3] * factor), blur), shadow_offset=(0, drop))

    def box(bid, inset=None, detail=None, **kw):
        lines = flat(**kw)
        if detail is not None:
            lines = ["corner_detail = %d" % detail if line.startswith("corner_detail") else line for line in lines]
        # 🔑 A **negative expand margin** draws the plate smaller than the control — the M3 way of a 40dp
        #    button inside a 48dp touch target (gohud's section headings use the same trick).
        for side, value in zip(("left", "top", "right", "bottom"), inset or (0, 0, 0, 0)):
            if value:
                lines.append("expand_margin_%s = %g" % (side, value))
        boxes[bid] = ("StyleBoxFlat", lines)

    touch = consts["button_height"]
    # How far the plate sits inside the control, top and bottom.
    edge = (touch - PLATE) / 2.0
    edge_xs = (consts["touch"] - PLATE_XS) / 2.0
    plate = (0, -edge, 0, -edge)
    plate_xs = (0, -edge_xs, 0, -edge_xs)
    pad = tuple(SHAPE["button_padding"])
    cpx, cpy = consts["compact_padding_x"], consts["compact_padding_y"]
    cpad = (cpx, cpy, cpx, cpy)

    # ── Buttons (`_md-comp-button-{small,xsmall,filled,tonal,text}.scss`) ──
    # 🔑 gohud's NORMAL tone is M3's **filled tonal** button — the medium-emphasis button that reads on
    #    every surface. PRIMARY is the filled button. The pressed face is the M3 pressed state (a 10% state
    #    layer and the squarer pressed corner — an instant shape change, as much of the Expressive shape morph as
    #    a StyleBox can hold). The engine also draws it for a toggled-on button; a choice that must read as
    #    chosen belongs in `segmented()` or a filter chip (see the 🛑 below).
    tonal, on_tonal = r["secondary_container"], r["on_secondary_container"]
    box("btn_normal", bg=tonal, radius=FULL, margins=pad, inset=plate, detail=16)
    # 🛑 No hover shadow: gohud's buttons sit flat, and M3's raised (elevated) look is the `*_glow` twin below.
    box("btn_hover", bg=_mix(tonal, on_tonal, HOVER), radius=FULL, margins=pad, inset=plate, detail=16)
    # 🔑 A press is the M3 state layer (on-secondary-container at 10%) with the pressed shape (corner.small) — the
    #    Expressive shape change, instant. 🛑 Not the selected colours: the engine shares this face between a press and a
    #    toggled-on button, and a tap that flashed the dark `secondary` read as "now selected" on every plain button.
    press_shape = consts["radius_small"]
    box("btn_pressed", bg=_mix(tonal, on_tonal, PRESSED), radius=press_shape, margins=pad, inset=plate)
    # 🛑 M3 fades a disabled label to 38% — gohud keeps it readable (4.5:1), so only the plate fades.
    box("btn_disabled", bg=_alpha(r["on_surface"], 0.10), radius=FULL, margins=pad, inset=plate, detail=16)
    # md.sys.state.focus-indicator: 3dp in `secondary`, 2dp **outside** the plate (outer-offset).
    ring = edge - 2 - 3
    box("btn_focus", draw_center=False, border=r["secondary"], bw=3, radius=FULL, margins=pad,
        inset=(5, -ring, 5, -ring), detail=16)
    # 🛑 A filled plate takes the ring **inside** its edge (inner-offset) in its own on-colour. gohud measures a
    #    focus ring against the plate (`tools/check_contrast.py`), and `secondary` on a `primary` plate is 1.00:1.
    box("btn_focus_on_fill", draw_center=False, border=r["on_primary"], bw=3, radius=FULL, margins=pad,
        inset=plate, detail=16)
    box("btn_focus_on_error", draw_center=False, border=r["on_error"], bw=3, radius=FULL, margins=pad,
        inset=plate, detail=16)

    filled, on_filled = r["primary"], r["on_primary"]
    box("btn_primary", bg=filled, radius=FULL, margins=pad, inset=plate, detail=16)
    box("btn_primary_hover", bg=_mix(filled, on_filled, HOVER), radius=FULL, margins=pad, inset=plate, detail=16)
    box("btn_primary_pressed", bg=_mix(filled, on_filled, PRESSED), radius=press_shape, margins=pad, inset=plate)

    # M3 has no "danger" button — the faint one is a tonal button in the error container colours,
    # the solid one a filled button in `error`.
    box("btn_danger", bg=r["error_container"], radius=FULL, margins=pad, inset=plate, detail=16)
    box("btn_danger_hover", bg=_mix(r["error_container"], r["on_error_container"], HOVER), radius=FULL,
        margins=pad, inset=plate, detail=16)
    box("btn_danger_solid", bg=r["error"], radius=FULL, margins=pad, inset=plate, detail=16)
    box("btn_danger_solid_hover", bg=_mix(r["error"], r["on_error"], HOVER), radius=FULL, margins=pad,
        inset=plate, detail=16)
    box("btn_danger_solid_pressed", bg=_mix(r["error"], r["on_error"], PRESSED), radius=press_shape,
        margins=pad, inset=plate)
    # 🔑 The raised twins (`*_glow`, when the generator has them) are M3's **elevated** look — the same
    #    plate with a level-2 shadow instead of a glow.
    for bid in [key for key in boxes if "_glow" in key]:
        base = bid.replace("_glow", "")
        if base in boxes and boxes[base][0] == "StyleBoxFlat":
            raised = [line for line in boxes[base][1] if not line.startswith("shadow_")]
            factor, blur, drop = ELEVATION[2]
            raised += ["shadow_color = %s" % C(_alpha(shadow, shadow[3] * factor)), "shadow_size = %d" % blur,
                       "shadow_offset = Vector2(0, %d)" % drop]
            boxes[bid] = ("StyleBoxFlat", raised)

    # Compact (button-xsmall, 32dp plate) and icon buttons (icon-button-small, a 40dp circle).
    box("compact_normal", bg=tonal, radius=FULL, margins=cpad, inset=plate_xs, detail=16)
    box("compact_hover", bg=_mix(tonal, on_tonal, HOVER), radius=FULL, margins=cpad, inset=plate_xs, detail=16)
    box("compact_disabled", bg=_alpha(r["on_surface"], 0.10), radius=FULL, margins=cpad, inset=plate_xs, detail=16)
    box("compact_pressed", bg=_mix(tonal, on_tonal, PRESSED), radius=press_shape, margins=cpad, inset=plate_xs)
    box("compact_focus", draw_center=False, border=r["secondary"], bw=3, radius=FULL, margins=cpad,
        inset=(5, -(edge_xs - 5), 5, -(edge_xs - 5)), detail=16)
    # 🛑 The icon button node is 36dp (`GoIconButton.visual_size`) — its 40dp state circle (icon-button-small) reaches
    #    2dp past it, and the focus ring stands 2dp outside that circle, 3dp thick.
    box("icon_hover", bg=_alpha(r["on_surface_variant"], HOVER), radius=FULL, inset=(2, 2, 2, 2), detail=16)
    box("icon_pressed", bg=_alpha(r["on_surface_variant"], PRESSED), radius=FULL, inset=(2, 2, 2, 2), detail=16)
    box("icon_focus", draw_center=False, border=r["secondary"], bw=3, radius=FULL, inset=(7, 7, 7, 7), detail=16)
    # Text button — gohud's bare button.
    box("text_hover", bg=_alpha(r["primary"], HOVER), radius=FULL, margins=pad, inset=plate, detail=16)
    box("text_pressed", bg=_alpha(r["primary"], PRESSED), radius=FULL, margins=pad, inset=plate, detail=16)

    # List rows (`_md-comp-list.scss`) — no container; the state layer is the only plate.
    box("list_normal", bg=_alpha(r["on_surface"], 0.0), radius=consts["radius"], margins=(0, 0, 0, 0))
    box("list_hover", bg=_alpha(r["on_surface"], HOVER), radius=consts["radius"], margins=(0, 0, 0, 0))
    box("list_pressed", bg=_alpha(r["on_surface"], PRESSED), radius=consts["radius"], margins=(0, 0, 0, 0))
    # The focus ring of the small parts — 3dp `secondary`, drawn inside the edge.
    box("focus_soft", draw_center=False, border=r["secondary"], bw=3, radius=consts["radius_small"])

    # ── Surfaces ──
    # Dialog (`_md-comp-dialog.scss`): surface-container-high, corner.extra-large, level 3.
    box("panel", bg=pal["surface"], radius=consts["radius_large"], margins=(0, 0, 0, 0), detail=16, **lift(3))
    box("panel_solid", bg=pal["surface"], radius=consts["radius"], margins=(0, 0, 0, 0))
    # Filled card (`_md-comp-filled-card.scss`): corner.medium, no outline, no shadow.
    padc = CARD_PADDING
    box("card", bg=pal["surface_soft"], radius=consts["radius"], margins=(padc, padc, padc, padc))
    # Menu (`_md-comp-menus.scss`, `_md-comp-menus-standard.scss`): surface-container-low, corner.large, level 2,
    # 8dp above and below the items; an item's state layer has corner.extra-small, 4dp in from the menu's sides.
    box("popup", bg=r["surface_container_low"], radius=16, margins=(0, 8, 0, 8), detail=12, **lift(2))
    box("menu_hover", bg=_alpha(r["on_surface"], HOVER), radius=4, inset=(-4, 0, -4, 0))
    # Divider (`_md-comp-divider.scss`): 1dp outline-variant with room above and below — a line, not a filled band.
    boxes["menu_separator"] = ("StyleBoxLine", ["content_margin_top = 8", "content_margin_bottom = 8",
                                                "color = %s" % C(r["outline_variant"]), "thickness = 1"])
    # A HUD over an app screen takes the floating toolbar's colour and lift (`_md-comp-toolbar-floating.scss`:
    # surface-container, level 3) — but corner.large, not the toolbar's pill: a HUD panel can hold several rows.
    small = consts["gap_small"]
    box("hud", bg=r["surface_container"], radius=16, margins=(small, small, small, small), detail=12, **lift(3))
    # Snackbar (`_md-comp-snackbar.scss`): corner.extra-small, level 3. 🛑 Not the inverse plate — see the header.
    gap = consts["gap"]
    box("notice", bg=r["surface_container_highest"], radius=4, margins=(gap + 4, gap, gap + 4, gap), **lift(3))

    # Outlined text field (`_md-comp-outlined-text-field.scss`): 56dp, corner.extra-small, 1dp outline → 3dp primary.
    field = (16, 18, 16, 18)
    box("edit_normal", draw_center=False, border=r["outline"], bw=1, radius=4, margins=field)
    box("edit_focus", draw_center=False, border=r["primary"], bw=3, radius=4, margins=field)
    box("edit_read_only", bg=_alpha(r["on_surface"], 0.04), border=_alpha(r["on_surface"], 0.12), bw=1, radius=4, margins=field)
    # The exposed dropdown is the same field — an OptionButton is a menu you open, not a button.
    box("field_hover", bg=_alpha(r["on_surface"], HOVER), border=r["on_surface"], bw=1, radius=4, margins=field)
    box("field_open", draw_center=False, border=r["primary"], bw=3, radius=4, margins=field)
    box("field_focus", draw_center=False, border=r["primary"], bw=3, radius=4)

    # Slider (`_md-comp-slider-xsmall.scss`): 16dp track, inactive secondary-container, active primary.
    track = r["secondary_container"]
    box("slider_track", bg=track, radius=8, margins=(0, 8, 0, 8))
    # The active part rounds only its outer end; where it meets the handle the corner is 2dp (active.track.inner-corner).
    box("slider_grab", bg=r["primary"], corners=(8, 2, 2, 8), margins=(0, 8, 0, 8))
    box("slider_grab_hover", bg=r["primary"], corners=(8, 2, 2, 8), margins=(0, 8, 0, 8))
    box("vslider_track", bg=track, radius=8, margins=(8, 0, 8, 0))
    box("vslider_grab", bg=r["primary"], corners=(2, 2, 8, 8), margins=(8, 0, 8, 0))

    # Linear progress (`_md-comp-progress-indicator.scss`): track secondary-container, indicator primary, corner.full.
    box("bar_bg", bg=pal["track"], radius=FULL, detail=8)
    box("bar_fill", bg=r["primary"], radius=FULL, detail=8)
    # Divider (`_md-comp-divider.scss`): 1dp outline-variant.
    box("separator", bg=r["outline_variant"], margins=(0, 0.5, 0, 0.5))
    # Plain tooltip (`_md-comp-plain-tooltip.scss`): inverse-surface, corner.extra-small.
    box("tooltip", bg=r["inverse_surface"], radius=4, margins=(8, 4, 8, 4))

    # Primary tabs (`_md-comp-primary-navigation-tab.scss`): 48dp, 3dp primary indicator, divider below.
    tab = (16, 15, 16, 16)
    box("tab_selected", bg=_alpha(r["primary"], 0.0), border=r["primary"], borders=(0, 0, 0, 3), margins=tab)
    box("tab_unselected", bg=_alpha(r["primary"], 0.0), border=r["outline_variant"], borders=(0, 0, 0, 1), margins=tab)
    box("tab_hovered", bg=_alpha(r["on_surface"], HOVER), border=r["outline_variant"], borders=(0, 0, 0, 1), margins=tab)

    # Expandable rows read as one filled card, open or shut.
    R = consts["radius"]
    soft = pal["surface_soft"]
    fold = (16, 14, 16, 14)
    box("fold_title", bg=soft, corners=(R, R, 0, 0), margins=fold)
    box("fold_title_hover", bg=_mix(soft, r["on_surface"], HOVER), corners=(R, R, 0, 0), margins=fold)
    box("fold_title_collapsed", bg=soft, radius=R, margins=fold)
    box("fold_title_collapsed_hover", bg=_mix(soft, r["on_surface"], HOVER), radius=R, margins=fold)
    box("fold_panel", bg=soft, corners=(0, 0, R, R), margins=(16, 8, 16, 16))

    # ── Entries ──
    for key, value in (("panel_alpha", 100), ("card_alpha", 100), ("hud_alpha", 100), ("notice_alpha", 100),
                       ("popup_alpha", 100), ("padding_compact", CARD_PADDING), ("icon_size", 24), ("list_glyph", 24),
                       ("notice_duration_ms", 4000)):
        put("GoHud/constants/%s" % key, value)

    # 🔑 M3's progress indicator is `primary` on its track, so the accent fill is the role colour itself.
    #    🛑 The status fills stay the generator's bright `*_vivid` ones — tone 40 is a text colour, and as
    #    a fill it turns the experience bar brown (the very regression `fill_color()` guards against).
    if contrast(pal["accent"], pal["track"]) >= 3.0:
        put("GoHud/colors/accent_fill", C(pal["accent"]))

    # Type sizes (md.sys.typescale).
    put("default_font_size", FONT_SIZES["body"])
    for key, role in (("Button/font_sizes/font_size", "button"), ("Label/font_sizes/font_size", "body"),
                      ("RichTextLabel/font_sizes/normal_font_size", "body"), ("LineEdit/font_sizes/font_size", "body"),
                      ("TooltipLabel/font_sizes/font_size", "compact"), ("PopupMenu/font_sizes/font_size", "button"),
                      ("OptionButton/font_sizes/font_size", "body"), ("CheckButton/font_sizes/font_size", "body"),
                      ("CheckBox/font_sizes/font_size", "body"), ("TabBar/font_sizes/font_size", "caption"),
                      ("TabContainer/font_sizes/font_size", "caption"), ("FoldableContainer/font_sizes/font_size", "body"),
                      ("ProgressBar/font_sizes/font_size", "compact"), ("GoCompactButton/font_sizes/font_size", "button"),
                      ("GoTitleLabel/font_sizes/font_size", "title"), ("GoSubtitleLabel/font_sizes/font_size", "subtitle"),
                      ("GoCaptionLabel/font_sizes/font_size", "caption"), ("GoCompactLabel/font_sizes/font_size", "compact"),
                      ("GoMicroLabel/font_sizes/font_size", "micro")):
        put(key, FONT_SIZES[role])

    # Line heights (md.sys.typescale): the space between lines of a wrapped paragraph — news and feed text reads at
    # 24dp lines in M3, not the engine's tight default.
    def spacing(role):
        return max(0, int(round(LINE_HEIGHTS[role] - ROBOTO_EM * FONT_SIZES[role])))
    for kind, role in (("Label", "body"), ("GoTitleLabel", "title"), ("GoSubtitleLabel", "subtitle"),
                       ("GoCaptionLabel", "caption"), ("GoCompactLabel", "compact"), ("GoMicroLabel", "micro")):
        put("%s/constants/line_spacing" % kind, spacing(role))
    put("RichTextLabel/constants/line_separation", spacing("body"))

    # 🔤 Body text is Roboto **only when the project chose no font of its own** — the theme carries it as metadata and
    #    `GoUi.theme()` applies it at run time. Baked in as `default_font`, it would replace a project's own (Korean,
    #    Japanese, Chinese) font in every gohud widget; left out, a project with no font gets the engine's semi-bold
    #    default as body text, which is not M3's regular 400.
    put("metadata/go_body_font", 'ExtResource("font_title")')

    # Button labels are label-large: Roboto at weight 500 — one variation of the same variable font.
    # 🔑 Set on gohud's button variations, not on `Button`: the engine's other Button subclasses (checkbox,
    #    switch, dropdown) carry body text and keep the host's font.
    boxes["font_medium"] = ("FontVariation", ['base_font = ExtResource("font_title")', "variation_opentype = {%d: 500}" % WGHT])
    for kind in ("GoButton", "GoPrimaryButton", "GoDangerButton", "GoDangerSolidButton", "GoBareButton", "GoCompactButton",
                 "TabBar", "TabContainer"):   # tabs: title-small, 500
        sb("%s/fonts/font" % kind, "font_medium")

    # Tonal button text (NORMAL tone).
    for key in ("font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"):
        put("Button/colors/%s" % key, C(on_tonal))
    put("Button/colors/font_pressed_color", C(on_tonal))
    put("Button/colors/font_hover_pressed_color", C(on_tonal))
    put("Button/colors/icon_normal_color", C(on_tonal))
    put("Button/colors/icon_hover_color", C(on_tonal))
    put("Button/colors/icon_pressed_color", C(on_tonal))
    put("Button/colors/icon_hover_pressed_color", C(on_tonal))
    put("Button/colors/icon_focus_color", C(on_tonal))
    put("Button/colors/icon_disabled_color", C(_alpha(r["on_surface"], 0.38)))
    put("Button/styles/hover_pressed", 'SubResource("btn_pressed")')

    # 🛑 **Everything that inherits from Button inherits the selected ink too** — white on the dark
    #    `secondary` plate. A checked switch or checkbox has no plate at all, so its label vanished (white on
    #    the light page, seen in the gallery). Each one that draws its own background gets its own ink.
    for kind in ("CheckBox", "CheckButton"):
        for key in ("font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
            put("%s/colors/%s" % (kind, key), C(r["on_surface"]))
    list_ink = next((line.split(" = ")[1] for line in T if line.startswith("GoListButton/colors/font_pressed_color")), C(r["on_surface"]))
    put("GoListButton/colors/font_hover_pressed_color", list_ink)
    put("GoPrimaryButton/colors/font_hover_pressed_color", C(r["on_primary"]))

    # The dropdown field.
    put("OptionButton/colors/font_color", C(r["on_surface"]))
    for key in ("font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"):
        put("OptionButton/colors/%s" % key, C(r["on_surface"]))
    for state, bid in (("normal", "edit_normal"), ("hover", "field_hover"), ("pressed", "field_open"),
                       ("hover_pressed", "field_open"), ("disabled", "edit_read_only"), ("focus", "field_focus")):
        sb("OptionButton/styles/%s" % state, bid)
        if state in ("normal", "hover", "pressed", "disabled"):
            sb("OptionButton/styles/%s_mirrored" % state, bid)   # right-to-left: the same symmetric field
    put("OptionButton/constants/arrow_margin", 16)
    sb("LineEdit/styles/read_only", "edit_read_only")
    sb("TextEdit/styles/read_only", "edit_read_only")

    # Error buttons take the error roles' own ink.
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
        put("GoDangerButton/colors/%s" % key, C(r["on_error_container"]))
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
        put("GoDangerSolidButton/colors/%s" % key, C(r["on_error"]))
    for key in ("icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"):
        put("GoDangerSolidButton/colors/%s" % key, C(r["on_error"]))
    sb("GoDangerSolidButton/styles/focus", "btn_focus_on_error")

    # Text button (bare): primary label, a primary state layer.
    for key in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"):
        put("GoBareButton/colors/%s" % key, C(r["primary"]))
    for key in ("icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"):
        put("GoBareButton/colors/%s" % key, C(r["primary"]))
    sb("GoBareButton/styles/hover", "text_hover")
    sb("GoBareButton/styles/pressed", "text_pressed")
    sb("GoBareButton/styles/hover_pressed", "text_pressed")
    sb("GoBareButton/styles/focus", "btn_focus")
    sb("GoCompactButton/styles/pressed", "compact_pressed")
    sb("GoCompactButton/styles/hover_pressed", "compact_pressed")
    sb("GoCompactButton/styles/focus", "compact_focus")
    sb("GoCompactButton/styles/disabled", "compact_disabled")
    sb("GoIconButton/styles/pressed", "icon_pressed")
    sb("GoIconButton/styles/hover_pressed", "icon_pressed")
    sb("GoIconButton/styles/focus", "icon_focus")
    # icon-button-standard: hovered and pressed icons stay on-surface-variant — primary is the selected state.
    for key in ("icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"):
        put("GoIconButton/colors/%s" % key, C(r["on_surface_variant"]))

    # List rows press with a state layer, not the accent.
    sb("GoListButton/styles/pressed", "list_pressed")
    for key in ("font_pressed_color", "font_hover_pressed_color"):
        put("GoListButton/colors/%s" % key, C(r["on_surface"]))
    sb("GoListButton/styles/hover_pressed", "list_pressed")

    # Menus: 48dp items, the label 16dp inside the item's state layer (menu-item leading/trailing space).
    put("PopupMenu/constants/v_separation", 30)
    put("PopupMenu/constants/item_start_padding", 20)
    put("PopupMenu/constants/item_end_padding", 20)
    put("PopupMenu/constants/icon_max_width", 24)

    # Tooltip text on the inverse plate.
    put("TooltipLabel/colors/font_color", C(r["inverse_on_surface"]))

    # Tabs: the selected label is primary, the rest on-surface-variant.
    for kind in ("TabBar", "TabContainer"):
        put("%s/colors/font_selected_color" % kind, C(r["primary"]))
        put("%s/colors/font_unselected_color" % kind, C(r["on_surface_variant"]))
        put("%s/colors/font_hovered_color" % kind, C(r["on_surface"]))

    # Vertical slider: its own track and its own handle.
    sb("VSlider/styles/slider", "vslider_track")
    sb("VSlider/styles/grabber_area", "vslider_grab")
    sb("VSlider/styles/grabber_area_highlight", "vslider_grab")
    for key, rid in (("grabber", "grabber_vertical"), ("grabber_highlight", "grabber_vertical_highlight"),
                     ("grabber_disabled", "grabber_vertical_disabled")):
        put("VSlider/icons/%s" % key, 'ExtResource("%s")' % rid)
