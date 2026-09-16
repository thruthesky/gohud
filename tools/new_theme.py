# -*- coding: utf-8 -*-
"""🎨 **Scaffold a new theme** — lay down the palette JSON and the preset resource, and the
generator does the rest.

    python3 addons/gohud/tools/new_theme.py neon --from scifi_dark --title "Neon"
    python3 addons/gohud/tools/make_theme.py neon          # theme .tres + control artwork
    godot --headless --path . --import                      # import the new SVGs
    GoUi.use_preset(&"neon")                                # done

    python3 addons/gohud/tools/new_theme.py --remove neon   # undo every file it created

## Why it works this way
Adding one theme used to mean editing four places by hand — the generator's palette dict, its shape
dict, the skin, and the preset resource. More themes are coming (requested 2026-09-13). So it was
reduced to **one file** (`themes/palettes/<id>.json`): inherit a built-in theme with `from` and
write down only what differs. This tool writes that file **with every inherited value spelled out**,
so what can be changed is visible at a glance.

🛑 The `id` becomes the file name — lowercase, digits and underscores only.
"""
import argparse
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_theme as mt  # noqa: E402

ADDON = mt.ADDON
THEMES = os.path.join(ADDON, "themes")
PRESETS = os.path.join(THEMES, "presets")
PALETTES = mt.PALETTES_DIR
SKINS = mt.SKIN_SCRIPTS


def color_text(c):
    """Color tuple -> `"#RRGGBB"` or `"#RRGGBB@alpha"` — the form a person can edit easily."""
    body = mt.svg_hex(c).upper()
    return body if abs(c[3] - 1.0) < 1e-6 else "%s@%s" % (body, ("%.2f" % c[3]).rstrip("0").rstrip("."))


def scaffold(tid, base, title, dark, skin, shape_kind, new_skin=False):
    if not re.fullmatch(r"[a-z][a-z0-9_]*", tid):
        raise SystemExit("🛑 the id must start with a lowercase letter and use only lowercase, digits and underscores: %r" % tid)
    registry = mt.all_themes()
    if tid in registry:
        raise SystemExit("🛑 the %r theme already exists" % tid)
    if base not in registry:
        raise SystemExit("🛑 --from must be one of: %s" % ", ".join(registry))
    pal, shape, meta = registry[base]
    if dark is None: dark = meta["dark"] if meta else base in ("dark", "scifi_dark")
    if skin is None:
        inherited = meta["skin"] if meta else "scifi" if base.startswith("scifi") else "default"
        skin = inherited.get("base", "default") if isinstance(inherited, dict) else inherited
    if shape_kind is None: shape_kind = shape["kind"]

    os.makedirs(PALETTES, exist_ok=True)
    palette_path = os.path.join(PALETTES, tid + ".json")
    preset_path = os.path.join(PRESETS, tid + ".tres")
    for path in (palette_path, preset_path):
        if os.path.exists(path):
            raise SystemExit("🛑 already there: %s (remove it with --remove %s)" % (os.path.relpath(path, ADDON), tid))

    # 🔑 **Spell the parent palette out in full** — the editable slots then are the list.
    spec = {
        "_help": "Colors are \"#RRGGBB\" or \"#RRGGBB@alpha\". Delete one and the `from` theme's value is used. "
                 "*_vivid are saturated colors used only for bar fills (so bars stay vivid on a light theme where the text color darkens).",
        "id": tid,
        "title": title or tid.replace("_", " ").title(),
        "dark": bool(dark),
        "from": base,
        "skin": {
            "_help": "base: default | scifi | medieval. dials are numbers you change without touching skin code — delete one and the parent value applies. "
                     "To change the drawing itself, use --new-skin to scaffold a script that extends GoSkin.",
            "base": skin,
            "dials": {**mt.skin_dials()["default"], **mt.skin_dials()[skin],
                      **(meta["skin"].get("dials", {}) if meta and isinstance(meta["skin"], dict)
                         and meta["skin"].get("base") == skin else {})},
        },
        "shape": {
            "_help": "kind: flat (rounded corners) | cut (chamfered corners) | medieval (metal frame). Adding the numbers below overrides CONST — "
                     "radius, radius_small, radius_large, gap, gap_small, gap_large, padding, button_height, "
                     "button_padding[4]. cut only: cut_ratio, cut_max, corners(diagonal|all), glow, edge.",
            "kind": shape_kind,
            **{k: v for k, v in (shape if shape_kind == shape["kind"] else mt.SHAPES[shape_kind]).items()
               if k not in ("kind", "controls")},
        },
        "palette": {key: color_text(pal[key]) for key in pal},
    }
    if meta and meta.get("icons"):
        spec["icons"] = meta["icons"]
    with open(palette_path, "w", encoding="utf-8") as fh:
        json.dump(spec, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    with open(preset_path, "w", encoding="utf-8") as fh:
        fh.write('[gd_resource type="Resource" script_class="GoThemePreset" load_steps=%d format=3]\n\n' % (5 if spec.get("icons") else 4))
        fh.write('[ext_resource type="Script" path="res://addons/gohud/core/go_theme_preset.gd" id="script"]\n')
        fh.write('[ext_resource type="Theme" path="res://addons/gohud/themes/gohud_%s.tres" id="theme"]\n' % tid)
        # 🔑 The skin points at a resource of this theme's own (`gohud_skin_<id>.tres`) — `make_theme.py`
        #    builds that file from `skin.dials` in the JSON. So you edit the dials and just rerun the generator.
        fh.write('[ext_resource type="Resource" path="res://addons/gohud/themes/skins/gohud_skin_%s.tres" id="skin"]\n\n' % tid)
        if spec.get("icons"):
            fh.write('[ext_resource type="Resource" path="%s" id="icons"]\n\n' % spec["icons"])
        fh.write('[resource]\nscript = ExtResource("script")\nid = &"%s"\ntitle = "%s"\ndark = %s\n'
                 'theme = ExtResource("theme")\nskin = ExtResource("skin")\n'
                 % (tid, spec["title"].replace('"', '\\"'), "true" if dark else "false"))
        if spec.get("icons"):
            fh.write('icons = ExtResource("icons")\n')

    if new_skin:
        write_skin_script(tid, skin)
    print("✅ %s\n   %s  ← edit colors, shape and skin dials here\n   %s  ← the bundle that shows in the picker"
          % (tid, os.path.relpath(palette_path, ADDON), os.path.relpath(preset_path, ADDON)))
    print("next:\n   python3 %s %s\n   godot --headless --path . --import\n   GoUi.use_preset(&\"%s\")"
          % (os.path.relpath(os.path.join(HERE, "make_theme.py"), ADDON), tid, tid))


def write_skin_script(tid, base):
    """A **script scaffold** extending `GoSkin` — needed only to change the drawing itself (joystick, ring, badge)."""
    parent = mt.SKIN_SCRIPTS[base][0]
    path = os.path.join(THEMES, "skins", "go_skin_%s.gd" % tid)
    if os.path.exists(path):
        raise SystemExit("🛑 already there: %s" % os.path.relpath(path, ADDON))
    body = f"""## 🎨 Skin for the `{tid}` theme — extends `{parent}` and overrides only what changes.
##
## Only what the theme (.tres) and the shape cannot reach belongs here: the things code draws
## itself — joystick, quick-slot plate, badge, coach-mark ring, chip, divider. To change only
## numbers you do not need this file — `skin.dials` in `themes/palettes/{tid}.json` is enough.
##
## Anything not overridden keeps the parent's look. What can be overridden (all in `GoSkin`):
##   surface_box · floating_box · disc_box · chip_box · chip_ink · slot_box · slot_ink · badge_box
##   skeleton_box · alert_box · segment_box · progress_fill_box · notice_box · tint_notice
##   coach_ring_box · divider_color · divider_thickness · section_box · draw_joystick · draw_coach_pointer
class_name GoSkin{tid.title().replace("_", "")}
extends {parent}


## Example: a different quick-slot plate only.
# func slot_box(accent: Color, lit: bool) -> StyleBox:
# \tvar box := super(accent, lit)
# \treturn box
"""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)
    print("   %s  ← override a method here to change the drawing" % os.path.relpath(path, ADDON))
    # Leave `base` in the palette JSON as it is; the `gohud_skin_<id>.tres` the generator writes
    # still points at the parent script — to use this scaffold, follow the one line printed below.
    print("   → point the script of gohud_skin_%s.tres at this file and it takes effect (better to leave the JSON skin as the string \"%s\" so a regeneration does not overwrite it)" % (tid, tid))


def remove(tid):
    """Delete every file it created — palette, preset, generated theme, skin, artwork folder."""
    gone = []
    for path in (os.path.join(PALETTES, tid + ".json"), os.path.join(PRESETS, tid + ".tres"),
                 os.path.join(THEMES, "gohud_%s.tres" % tid),
                 os.path.join(THEMES, "skins", "gohud_skin_%s.tres" % tid),
                 os.path.join(THEMES, "skins", "go_skin_%s.gd" % tid),
                 os.path.join(THEMES, "skins", "go_skin_%s.gd.uid" % tid)):
        if os.path.exists(path):
            os.remove(path); gone.append(path)
    assets = os.path.join(ADDON, "assets", tid)
    if os.path.isdir(assets):
        shutil.rmtree(assets); gone.append(assets)
    for path in gone:
        print("🗑  %s" % os.path.relpath(path, ADDON))
    if not gone:
        print("(nothing to delete: %s)" % tid)


def main():
    parser = argparse.ArgumentParser(description="gohud theme scaffolding")
    parser.add_argument("id", nargs="?", help="name of the new theme (lowercase, digits, underscores)")
    parser.add_argument("--from", dest="base", default="dark", help="theme to inherit from: dark | light | scifi_dark | medieval_dark | ...")
    parser.add_argument("--title", default="", help="name shown in the picker")
    parser.add_argument("--dark", dest="dark", action="store_true", default=None)
    parser.add_argument("--light", dest="dark", action="store_false")
    parser.add_argument("--skin", choices=sorted(SKINS), default=None, help="look of the parts drawn by code")
    parser.add_argument("--shape", choices=sorted(mt.SHAPES), default=None, help="shape family of the plates")
    parser.add_argument("--new-skin", action="store_true", help="also scaffold a script extending GoSkin (when changing the drawing itself)")
    parser.add_argument("--remove", metavar="ID", help="delete every file it created")
    args = parser.parse_args()
    if args.remove:
        remove(args.remove); return
    if not args.id:
        parser.error("give an id (for example: neon)")
    scaffold(args.id, args.base, args.title, args.dark, args.skin, args.shape, args.new_skin)


if __name__ == "__main__":
    main()
