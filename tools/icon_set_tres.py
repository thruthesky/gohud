# -*- coding: utf-8 -*-
"""Writes a `GoIconSet` `.tres` whose drawings are **paths**, loaded when a name is first drawn.

Shared by `tools/make_game_icons.py` and `tools/make_icon_library.py` so the two sets are serialised the same way.

## Why paths and not textures
A `.tres` that lists its drawings as `ExtResource` textures reads every one of them the moment it is opened —
1,000 textures took ≈90 ms on a desktop (Godot 4.7 headless, 2026-09-23). A table of `res://` paths takes ≈5 ms, and
each icon ≈0.2 ms the first time it is drawn. `GoIconSet.paths` is that table.

🛑 A path is a plain string, so an export that picks resources does not see it as a dependency. The default
   "export all resources" is fine; README and `www/icons.html` tell the other kind to include `addons/gohud/icons/`.
"""
import re

# Search words that describe how a drawing is *made* or *sold*, not what it shows — they only add noise to a search.
STOP_TAGS = {"npm", "programming", "software", "coding", "technical", "code", "development", "developer", "app",
             "application", "web", "website", "ui", "ux", "icon", "icons", "interface", "tabler", "content",
             "control", "hardware", "outline", "line", "figures", "various", "other"}


def clean_tags(name, words, limit=6):
    """Lowercase words not already in the name, no numbers, no noise, no repeats — at most `limit`."""
    parts = set(name.split("_"))
    out = []
    for word in words:
        word = str(word).strip().lower()
        if not word or word.isdigit() or word in parts or word in out or word in STOP_TAGS:
            continue
        if not re.fullmatch(r"[a-z0-9][a-z0-9 .'-]*", word):
            continue
        out.append(word)
    return out[:limit]


def _q(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def _strings(values):
    return "PackedStringArray(%s)" % ", ".join(_q(v) for v in values)


def icon_set_tres(set_name, attribution, fallback_path, folder, paths, groups, tags, aliases):
    """The `.tres` text.

    folder   "res://…/icons/game"           — `paths` values are file names inside it
    paths    {name: "name.svg"}             — written sorted by name
    groups   [(key, title, [names…])]        — in display order
    tags     {name: [word…]}                 — names without words are left out
    aliases  {alias: name}                   — written sorted by alias
    """
    lines = ['[gd_resource type="Resource" script_class="GoIconSet" load_steps=3 format=3]', "",
             '[ext_resource type="Script" path="res://addons/gohud/core/go_icon_set.gd" id="script"]',
             '[ext_resource type="Resource" path="%s" id="fallback"]' % fallback_path, "",
             "[resource]", 'script = ExtResource("script")', "set_name = %s" % _q(set_name),
             "attribution = %s" % _q(attribution),
             "textures = Dictionary[StringName, Texture2D]({})"]
    lines.append("paths = Dictionary[StringName, String]({%s})" % ", ".join(
        '&"%s": %s' % (name, _q(paths[name])) for name in sorted(paths)))
    lines.append("folder = %s" % _q(folder))
    lines += ["codepoints = Dictionary[StringName, int]({})", "font_size_ratio = 1.0",
              'fallback = ExtResource("fallback")']
    lines.append("aliases = Dictionary[StringName, StringName]({%s})" % ", ".join(
        '&"%s": &"%s"' % (alias, aliases[alias]) for alias in sorted(aliases)))
    lines.append("groups = Dictionary[StringName, PackedStringArray]({%s})" % ", ".join(
        '&"%s": %s' % (key, _strings(names)) for key, _title, names in groups))
    lines.append("group_titles = Dictionary[StringName, String]({%s})" % ", ".join(
        '&"%s": %s' % (key, _q(title)) for key, title, _names in groups))
    lines.append("tags = Dictionary[StringName, PackedStringArray]({%s})" % ", ".join(
        '&"%s": %s' % (name, _strings(tags[name])) for name in sorted(tags) if tags[name]))
    return "\n".join(lines) + "\n"
