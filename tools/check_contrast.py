# -*- coding: utf-8 -*-
"""Measure the **contrast ratio** of every theme and find hard-to-read color pairs.

    python3 addons/gohud/tools/check_contrast.py           # measure every theme
    python3 addons/gohud/tools/check_contrast.py --strict   # count warnings as failures too (for CI)

## Why measure it
"Pretty" is taste, but **"readable" can be measured.** On a light theme, faint gray text
looks fine on the designer's good monitor and disappears on a phone in sunlight. Picking
by eye always ends up there.

## The bar — WCAG 2.2 minimum contrast
| Text | Required ratio |
|---|---|
| Body (under 24px, or under 19px bold) | **4.5 : 1** |
| Large text (24px and up) | **3 : 1** |
| UI component edges and icons | **3 : 1** |

🛑 Colors with alpha are measured **after compositing them onto the surface underneath** —
   measuring a translucent border as-is scores better than it really is. If that surface is
   not opaque either, keep compositing down to `background`.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
THEMES = os.path.join(ADDON, "themes")

# Body 4.5 · large text 3 · component edges 3
BODY, LARGE, UI = 4.5, 3.0, 3.0

# 🛑 Decorative borders are **not** what WCAG's 3:1 rule is about. 1.4.11 applies only to
#    boundaries you cannot use the feature without seeing, and a gohud card is already told
#    apart by its background color — the border is decoration on top of that.
#    Still, an invisible border melts the card into the background, so we keep a separate
#    minimum for the edge being noticeable at all.
DECOR = 2.0


def parse_theme(path):
    """Pull only the `GoHud/colors/*` tokens — those are the colors widgets actually use."""
    colors = {}
    for line in open(path, encoding="utf-8"):
        match = re.match(r"^GoHud/colors/([a-z_]+)\s*=\s*Color\(([^)]+)\)", line.strip())
        if match:
            parts = [float(value) for value in match.group(2).split(",")]
            while len(parts) < 4:
                parts.append(1.0)
            colors[match.group(1)] = tuple(parts[:4])
    return colors


def over(top, bottom):
    """Alpha compositing — the real color of `top` laid over `bottom`."""
    alpha = top[3]
    return tuple(top[i] * alpha + bottom[i] * (1.0 - alpha) for i in range(3)) + (1.0,)


def luminance(color):
    def channel(value):
        value = max(0.0, min(1.0, value))
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(color[i]) for i in range(3))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(front, back):
    a, b = luminance(front), luminance(back)
    high, low = max(a, b), min(a, b)
    return (high + 0.05) / (low + 0.05)


def solid(colors, name, under="background"):
    """Turn one token into the **opaque color actually shown on screen**."""
    base = colors.get(under, (0, 0, 0, 1))
    if base[3] < 1.0:
        base = over(base, (0, 0, 0, 1.0))
    value = colors.get(name)
    if value is None:
        return None
    return over(value, base) if value[3] < 1.0 else value


# (foreground, background, required ratio, where it is used)
def pairs(colors):
    surfaces = ["surface", "surface_soft", "surface_high"]
    out = []
    for back in ["background"] + surfaces:
        out.append(("text", back, BODY, "body text"))
        out.append(("secondary", back, BODY, "secondary text (captions)"))
        out.append(("muted", back, BODY, "muted text (micro labels, disabled)"))
    out.append(("on_accent", "accent", BODY, "text on an accent button"))
    for tone in ["success", "warning", "danger", "info"]:
        out.append((tone, "surface", BODY, "%s status text" % tone))
        out.append((tone, "background", BODY, "%s status text (on the backdrop)" % tone))
    out.append(("accent", "surface", UI, "accent borders and icons"))
    out.append(("accent", "background", UI, "accent borders and icons (on the backdrop)"))
    out.append(("border", "surface", DECOR, "card border (decoration — not a WCAG 3:1 target)"))
    out.append(("border", "background", DECOR, "card border (on the backdrop)"))
    return out


# 🛑 **Surfaces must be told apart from each other too.** Measuring only text contrast misses
#    "the card melts into the background, I cannot tell where the card ends". WCAG gives no bar
#    for this pair (it is neither decoration nor text). We set the minimum where the eye still
#    picks up the edge, from experience — Material's surface elevations use about this much
#    difference too.
LAYER = 1.12

# (upper surface, lower surface, what is being told apart)
LAYER_PAIRS = [
    ("surface", "background", "the panel against the screen backdrop"),
    ("surface_soft", "surface", "the card against the panel"),
    ("surface_high", "surface_soft", "the raised cell against the card"),
    # 🛑 **Cards also sit directly on the backdrop.** Missing this pair let a light theme end up
    #    with a card at 1.00:1 against the backdrop, and the whole plate behind list rows
    #    vanished — only spotted in a screenshot (2026-09-13).
    ("surface_soft", "background", "the card against the screen backdrop"),
    ("surface_high", "background", "the raised cell against the screen backdrop"),
]


def layer_rows(colors):
    rows = []
    for top, bottom, note in LAYER_PAIRS:
        a = solid(colors, top, "background")
        b = solid(colors, bottom, "background")
        if a is None or b is None:
            continue
        rows.append({
            "front": top, "back": bottom, "need": LAYER, "note": note + " stays visible",
            "ratio": ratio(a, b),
        })
    return rows


def parse_boxes(path):
    """Collect `bg_color` from every `[sub_resource ...] id="x"` block.

    🛑 A custom StyleBox (`type="StyleBox"` + script) uses the `bg_color` field too — do not
    filter by type name.
    """
    boxes = {}
    current = None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        head = re.match(r'^\[sub_resource type="[^"]+" id="([^"]+)"\]', line)
        if head:
            current = head.group(1)
            continue
        if line.startswith("["):
            current = None
            continue
        if current:
            match = re.match(r"^bg_color\s*=\s*Color\(([^)]+)\)", line)
            if match:
                parts = [float(v) for v in match.group(1).split(",")]
                while len(parts) < 4:
                    parts.append(1.0)
                boxes[current] = tuple(parts[:4])
            elif re.match(r"^draw_center\s*=\s*false", line):
                boxes[current] = None      # draws no background — the plate below shows through
    return boxes


def parse_theme_map(path):
    """`Type/styles/state = SubResource("id")`, `Type/colors/name = Color(...)`, and `base_type`."""
    styles, fonts, bases = {}, {}, {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        match = re.match(r'^([A-Za-z0-9_]+)/styles/([a-z_]+)\s*=\s*SubResource\("([^"]+)"\)', line)
        if match:
            styles.setdefault(match.group(1), {})[match.group(2)] = match.group(3)
            continue
        match = re.match(r"^([A-Za-z0-9_]+)/colors/([a-z_]+)\s*=\s*Color\(([^)]+)\)", line)
        if match:
            parts = [float(v) for v in match.group(3).split(",")]
            while len(parts) < 4:
                parts.append(1.0)
            fonts.setdefault(match.group(1), {})[match.group(2)] = tuple(parts[:4])
            continue
        match = re.match(r'^([A-Za-z0-9_]+)/base_type\s*=\s*&"([^"]+)"', line)
        if match:
            bases[match.group(1)] = match.group(2)
    return styles, fonts, bases


# state -> the font color slots used in that state (falls back to the earlier one if absent)
STATE_FONTS = {
    "normal": ["font_color"],
    "hover": ["font_hover_color", "font_color"],
    "pressed": ["font_pressed_color", "font_color"],
    "disabled": ["font_disabled_color", "font_color"],
}

# Types to check — only the ones that hold text. Scrollbars and sliders have none.
TEXT_TYPES = [
    "Button", "OptionButton", "GoButton", "GoPrimaryButton", "GoDangerButton", "GoDangerSolidButton",
    "GoCompactButton", "GoListButton", "LineEdit", "TextEdit", "PopupMenu", "TabBar",
    "FoldableContainer",
]


def font_for(fonts, bases, type_name, keys):
    """If the type has no such color, walk up `base_type` — that is how the engine looks it up."""
    seen = 0
    current = type_name
    while current and seen < 8:
        table = fonts.get(current, {})
        for key in keys:
            if key in table:
                return table[key]
        current = bases.get(current)
        seen += 1
    return None


# 🛑 **A floating plate does not know what will be behind it.** HUDs, popups and notices sit on
#    top of the game view — it could be a snowfield, it could be a cave. If the plate is
#    translucent the view behind changes the plate's own color, and the text contrast on it
#    collapses with it. The same thing happened in the gallery as scrolling body content passed
#    behind the HUD (measured 2026-09-13).
#    So we lay **pure white and pure black** underneath and check the body bar still holds —
#    those two are the worst case a game view can give.
FLOATING_STYLES = ["hud", "popup", "notice", "panel", "card", "empty"]
FLOATING_INKS = [("text", BODY), ("secondary", BODY), ("muted", BODY)]
WORST_BACKDROPS = [((1.0, 1.0, 1.0, 1.0), "pure white"), ((0.0, 0.0, 0.0, 1.0), "pure black")]


def parse_box_field(path, *fields):
    """Collect, per `sub_resource` block, **the first of the given color fields** that appears.

    Custom StyleBoxes name their fields differently — the chamfered plate uses `border_color`,
    the aim marker uses `color`.
    """
    found = {}
    current = None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        head = re.match(r'^\[sub_resource type="[^"]+" id="([^"]+)"\]', line)
        if head:
            current = head.group(1)
            continue
        if line.startswith("["):
            current = None
            continue
        if current is None or current in found:
            continue
        for field in fields:
            match = re.match(r"^%s\s*=\s*Color\(([^)]+)\)" % re.escape(field), line)
            if match:
                parts = [float(v) for v in match.group(1).split(",")]
                while len(parts) < 4:
                    parts.append(1.0)
                found[current] = tuple(parts[:4])
                break
    return found


# 🛑 **The focus indicator has to be visible on the plate it is drawn over.** An accent button's
#    plate *is* the accent color, so an accent-colored ring lands on the same color and
#    **disappears** — and with it any sense of "where am I" while moving by keyboard
#    (measured on desktop 2026-09-13: hover and focus were indistinguishable). WCAG 2.4.11
#    requires 3:1 for focus indicators.
FOCUS_TYPES = ["Button", "GoPrimaryButton", "GoDangerButton", "GoDangerSolidButton"]


# 🛑 **A tooltip is split across two types** — the plate is `TooltipPanel`, the text is
#    `TooltipLabel`. A check that pairs plate and text within one type **can never catch this.**
#    And an icon button has no label, so for a mouse user the tooltip is that button's
#    **only** description.
def tooltip_rows(path, colors):
    boxes = parse_boxes(path)
    styles, fonts, _bases = parse_theme_map(path)
    panel_id = styles.get("TooltipPanel", {}).get("panel")
    ink = fonts.get("TooltipLabel", {}).get("font_color")
    if panel_id is None or ink is None or panel_id not in boxes:
        return []
    panel = boxes[panel_id]
    base = solid(colors, "background", "background")
    back = base if panel is None else (over(panel, base) if panel[3] < 1.0 else panel)
    front = over(ink, back) if ink[3] < 1.0 else ink
    return [{
        "front": "tooltip text", "back": "tooltip plate", "need": BODY, "ratio": ratio(front, back),
        "note": "the only description an icon button has",
    }]


def focus_rows(path, colors):
    boxes = parse_boxes(path)
    edges = parse_box_field(path, "border_color", "color")
    styles, _fonts, _bases = parse_theme_map(path)
    rows = []
    base = solid(colors, "background", "background")
    for type_name in FOCUS_TYPES:
        table = styles.get(type_name)
        if not table:
            continue
        focus_id = table.get("focus")
        normal_id = table.get("normal")
        if focus_id is None or focus_id not in edges:
            continue
        ring = edges[focus_id]
        under = base
        if normal_id is not None and boxes.get(normal_id) is not None:
            panel = boxes[normal_id]
            under = over(panel, base) if panel[3] < 1.0 else panel
        front = over(ring, under) if ring[3] < 1.0 else ring
        rows.append({
            "front": "%s focus ring" % type_name, "back": "its own plate",
            "need": UI, "ratio": ratio(front, under),
            "note": "shows where you are after moving by keyboard",
        })
    return rows


def floating_rows(path, colors):
    """Translucent floating plates — is the text on them readable whatever is behind?"""
    boxes = parse_boxes(path)
    styles, _fonts, _bases = parse_theme_map(path)
    hud_styles = styles.get("GoHud", {})
    rows = []
    for style_name in FLOATING_STYLES:
        box_id = hud_styles.get(style_name)
        if box_id is None or box_id not in boxes:
            continue
        box_bg = boxes[box_id]
        if box_bg is None or box_bg[3] >= 1.0:
            continue                      # nothing shows through if it draws no background or is opaque
        for ink_name, need in FLOATING_INKS:
            raw = colors.get(ink_name)
            if raw is None:
                continue
            worst, worst_name = None, ""
            for backdrop, backdrop_name in WORST_BACKDROPS:
                back = over(box_bg, backdrop)
                front = over(raw, back) if raw[3] < 1.0 else raw
                value = ratio(front, back)
                if worst is None or value < worst:
                    worst, worst_name = value, backdrop_name
            rows.append({
                "front": ink_name, "back": "%s plate/%s" % (style_name, worst_name),
                "need": need, "ratio": worst,
                "note": "readable even with the view showing through a floating plate",
            })
    return rows


def surface_rows(path, colors):
    """**Text over StyleBox backgrounds** — measure the combinations the eye actually sees."""
    boxes = parse_boxes(path)
    styles, fonts, bases = parse_theme_map(path)
    under_names = ["background", "surface_soft"]      # buttons sit on the backdrop and inside cards
    rows = []
    for type_name in TEXT_TYPES:
        table = styles.get(type_name)
        if not table:
            continue
        for state, keys in STATE_FONTS.items():
            box_id = table.get(state)
            if box_id is None or box_id not in boxes:
                continue
            box_bg = boxes[box_id]
            ink = font_for(fonts, bases, type_name, keys)
            if ink is None:
                continue
            worst, worst_under = None, ""
            for under in under_names:
                base = solid(colors, under)
                if base is None:
                    continue
                back = base if box_bg is None else (over(box_bg, base) if box_bg[3] < 1.0 else box_bg)
                front = over(ink, back) if ink[3] < 1.0 else ink
                value = ratio(front, back)
                if worst is None or value < worst:
                    worst, worst_under = value, under
                if box_bg is not None and box_bg[3] >= 1.0:
                    break        # an opaque plate looks the same whatever is under it
            if worst is None:
                continue
            rows.append({
                "front": "%s.%s" % (type_name, state), "back": "on the plate (%s)" % worst_under,
                "need": BODY, "ratio": worst, "note": "button and input field text",
            })
    return rows


def measure(path):
    colors = parse_theme(path)
    if not colors:
        return None, []
    rows = []
    for front, back, need, note in pairs(colors):
        back_solid = solid(colors, back) if back != "background" else solid(colors, "background", "background")
        if back_solid is None:
            continue
        raw = colors.get(front)
        if raw is None:
            continue
        front_solid = over(raw, back_solid) if raw[3] < 1.0 else raw
        rows.append({
            "front": front, "back": back, "need": need, "note": note,
            "ratio": ratio(front_solid, back_solid),
        })
    rows += surface_rows(path, colors)
    rows += floating_rows(path, colors)
    rows += focus_rows(path, colors)
    rows += tooltip_rows(path, colors)
    rows += layer_rows(colors)
    return colors, rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="count near misses (under 1.1x the bar) as failures too")
    parser.add_argument("--quiet", action="store_true", help="hide the rows that pass")
    args = parser.parse_args()

    files = sorted(name for name in os.listdir(THEMES) if name.endswith(".tres"))
    failures = 0
    for name in files:
        path = os.path.join(THEMES, name)
        colors, rows = measure(path)
        if not rows:
            continue
        bad = [row for row in rows if row["ratio"] < row["need"]]
        thin = [row for row in rows if row["need"] <= row["ratio"] < row["need"] * 1.1]
        mark = "🛑" if bad else ("⚠️ " if thin else "✅")
        print("\n%s %s — %d pairs · %d below the bar · %d near miss" % (mark, name, len(rows), len(bad), len(thin)))
        for row in sorted(rows, key=lambda r: r["ratio"]):
            failed = row["ratio"] < row["need"]
            close = not failed and row["ratio"] < row["need"] * 1.1
            if args.quiet and not failed and not close:
                continue
            flag = "🛑" if failed else ("⚠️ " if close else "  ")
            print("   %s %-24s on %-20s %5.2f:1  (need %.1f)  %s"
                  % (flag, row["front"], row["back"], row["ratio"], row["need"], row["note"]))
        failures += len(bad) + (len(thin) if args.strict else 0)

    print("\n%s %d below the bar in total" % ("🛑" if failures else "✅", failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
