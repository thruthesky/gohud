# -*- coding: utf-8 -*-
"""The gohud **icon library** — 1,000 more icons, in 32 groups, on top of the default and game sets.

    python3 addons/gohud/tools/make_icon_library.py              # rewrite everything below from the table
    python3 addons/gohud/tools/make_icon_library.py --check      # exit 1 if a generated file differs from the table
    python3 addons/gohud/tools/make_icon_library.py --import DIR # refresh drawings and search words from a Tabler package

The table is `tools/icon_library_data.py` — one row per icon: (name, Tabler name, search words, SVG body).
From it this writes:

  icons/library/<name>.svg          one 24x24 white stroke icon per row (+ a DPITexture `.import` stub when missing)
  icons/gohud_icons_library.tres    the `GoIconSet` — drawings as `paths` (read when a name is first drawn), groups,
                                    search words, aliases. Fallback = the game set → the default set, so plugging this
                                    one set in makes all 1,271 names drawable.
  core/go_icon_library.gd           `GoIconLibrary` — a name constant per icon, the groups, and `icon_set()`

## Where the drawings come from
Every row is path data from **Tabler Icons 3.46.0** (https://tabler.io/icons), MIT License, Copyright (c) 2020-2026
Paweł Kuna — the same source, the same 24x24 grid and the same 2px round stroke as 171 of the game icons, so the
three sets sit side by side. The data is kept in the table, so the set rebuilds offline and byte for byte; only
`--import` reads a Tabler package (`npm pack @tabler/icons@3.46.0`, then point `DIR` at the unpacked `package/`).

## What was chosen (2026-09-23)
From Tabler's 5,130 outline icons: no brand logos (trademarks), no letters, numbers or text-formatting marks, none
the game set already uses, no numbered look-alikes (`arrow-left-2`) and no `-off` twins except for real toggles
(`wifi_off`, `bell_off` …). A drawing that repeats a default icon became an **alias** of it instead (`x` → `close`,
`map_pin` → `location`). The rest was picked per Tabler category with a cap per family, so `arrow_*` or `file_*`
cannot crowd out weather or sport. The table is the list — add, remove or regroup rows by hand.

## Rules the script enforces
- names are lower_snake_case and **new** — not in the default set, the game set (or its aliases) or the medieval set
- an alias is not a real name anywhere, and what it points at exists
- 🛑 `stroke="#ffffff"`, never `currentColor` — Godot's SVG rasteriser paints `currentColor` black and gohud colours
  icons by `modulate`, which can only darken. `--import` rewrites Tabler's `currentColor` fills to white.
- 🛑 Keep `THIRD_PARTY_NOTICES.md` in step — the Tabler MIT notice must travel with these files.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import icon_library_data as data  # noqa: E402
import icon_set_tres  # noqa: E402

DATA_FILE = os.path.join(HERE, "icon_library_data.py")
HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
        'fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">')
TAIL = "</svg>"
SET_NAME = "gohud icon library"
SET_PATH = "res://addons/gohud/icons/gohud_icons_library.tres"
ATTRIBUTION = ("gohud icon library, MIT. {count} icons use path data from Tabler Icons %s (https://tabler.io/icons), "
               "MIT License, Copyright (c) 2020-2026 Pawel Kuna. See THIRD_PARTY_NOTICES.md.")

IMPORT_STUB = """[remap]

importer="svg"
type="DPITexture"

[deps]

source_file="%s"

[params]

base_scale=1.0
saturation=1.0
color_map={}
fix_alpha_border=false
premult_alpha=false
compress=true
"""


def rows():
	return [row for _key, _title, items in data.GROUPS for row in items]


def existing_names():
	"""Every name another bundled set already draws or aliases — read from the sources without running anything."""
	taken = {}
	text = open(os.path.join(HERE, "make_icons.py"), encoding="utf-8").read()
	for name in re.findall(r'^  "([a-z_0-9]+)":', text, re.M):
		taken[name] = "the default set"
	text = open(os.path.join(HERE, "make_game_icons.py"), encoding="utf-8").read()
	for name in re.findall(r'^    \("([a-z_0-9]+)",', text, re.M):
		taken[name] = "the game set"
	game = open(os.path.join(ADDON, "icons", "gohud_icons_game.tres"), encoding="utf-8").read()
	line = re.search(r"^aliases = .*$", game, re.M)
	for alias in re.findall(r'&"([a-z_0-9]+)": &"', line.group(0) if line else ""):
		taken[alias] = "a game-set alias"
	medieval = open(os.path.join(ADDON, "icons", "gohud_icons_medieval.tres"), encoding="utf-8").read()
	for name in re.findall(r'^&"([a-z_0-9]+)": ExtResource', medieval, re.M):
		taken.setdefault(name, "the medieval set")
	return taken


def validate():
	names = [name for name, _tabler, _tags, _body in rows()]
	repeated = sorted({name for name in names if names.count(name) > 1})
	if repeated:
		sys.exit("🛑 a name is listed twice: %s" % " ".join(repeated))
	bad = sorted(name for name in names if not re.fullmatch(r"[a-z][a-z0-9_]*", name))
	if bad:
		sys.exit("🛑 names are lower_snake_case: %s" % " ".join(bad))
	taken = existing_names()
	clash = sorted("%s (%s)" % (name, taken[name]) for name in names if name in taken)
	if clash:
		sys.exit("🛑 already drawn by another set: %s" % ", ".join(clash))
	colour = sorted(name for name, _t, _g, body in rows() if "currentColor" in body or not body.strip())
	if colour:
		sys.exit("🛑 empty or currentColor drawings (run --import): %s" % " ".join(colour))
	drawable = set(names) | set(taken)
	wrong = sorted("%s → %s" % (alias, target) for alias, target in data.ALIASES.items()
		if alias in drawable or target not in drawable or not re.fullmatch(r"[a-z][a-z0-9_]*", alias))
	if wrong:
		sys.exit("🛑 an alias must be a new name that leads to a drawn one: %s" % ", ".join(wrong))
	return names


def outputs():
	"""Relative path -> file contents, for every generated file."""
	names = validate()
	files = {}
	for name, _tabler, _tags, body in rows():
		files["icons/library/%s.svg" % name] = HEAD + body + TAIL + "\n"

	files["icons/gohud_icons_library.tres"] = icon_set_tres.icon_set_tres(
		SET_NAME, ATTRIBUTION.format(count=len(names)), "res://addons/gohud/icons/gohud_icons_game.tres",
		"res://addons/gohud/icons/library", {name: "%s.svg" % name for name in names},
		[(key, title, [row[0] for row in items]) for key, title, items in data.GROUPS],
		{name: tags.split() for name, _tabler, tags, _body in rows()}, data.ALIASES)

	gd = ["## 📚 Names for the **icon library** — %d more icons in %d groups, from arrows and devices to weather," % (len(names), len(data.GROUPS)),
		"## sport, food, faces and the zodiac. The drawings live in `icons/library/`, the set in `icons/gohud_icons_library.tres`.",
		"##",
		"## ```gdscript",
		"## GoUi.add_icons(GoIconLibrary.icon_set())       # every widget can now draw these names (under any preset)",
		"## slot.icon_name = GoIconLibrary.DEVICE_GAMEPAD",
		"## GoStyle.list_button(GoIconLibrary.CLOUD_RAIN, \"Weather\", open_weather)",
		"## GoIconLibrary.icon_set().search(\"arrow left\")  # names by words, best first",
		"## GoIconLibrary.icon_set().names_in_group(&\"weather\")  # every icon of one group, in display order",
		"## ```",
		"##",
		"## 🔑 The set falls back to the game set and that one to the default set, so this one set draws all %d names." % (len(names) + 271),
		"##    Each drawing is read from disk the first time its name is drawn — plugging the set in costs a table of paths.",
		"## 🛑 **Generated** by `tools/make_icon_library.py` from `tools/icon_library_data.py` — edit the table, not this file.",
		"## 🛑 Kept apart from `GoIconSet`: those 84 constants promise \"the default set draws this name\". These names are",
		"##    drawn by **this set only**, so keep it in the lookup (`GoUi.add_icons`) when you use them.",
		"@tool", "class_name GoIconLibrary", "extends RefCounted", "",
		'const SET_PATH := "%s"' % SET_PATH, ""]
	for key, title, items in data.GROUPS:
		gd.append("# ── %s %s" % (title, "─" * max(4, 66 - len(title))))
		for row in items:
			gd.append('const %s := &"%s"' % (row[0].upper(), row[0]))
		gd.append("")
	gd += ["",
		"## The set itself. 🛑 Loaded on first use rather than `preload`ed, and it holds **paths**, not textures —",
		"##    a drawing is read the first time its name is drawn, so asking for the set costs a table of %d paths." % len(names),
		"static func icon_set() -> GoIconSet:",
		"\treturn load(SET_PATH) as GoIconSet", "", "",
		"## Every name of this set (without the game and default sets' names), in display order.",
		"static func names() -> Array[StringName]:",
		"\tvar all: Array[StringName] = []",
		"\tvar own := icon_set()",
		"\tfor key: StringName in own.groups:",
		"\t\tfor icon in own.groups[key]: all.append(StringName(icon))",
		"\treturn all", "", "",
		"## The group keys of this set, in display order — `icon_set().names_in_group(key)` lists one.",
		"static func group_keys() -> Array[StringName]:",
		"\tvar keys: Array[StringName] = []",
		"\tkeys.assign(icon_set().groups.keys())",
		"\treturn keys", ""]
	files["core/go_icon_library.gd"] = "\n".join(gd)
	return files


# ── --import: refresh the drawings and search words from a Tabler package ──

def svg_body(nodes):
	"""Tabler's node list → gohud's body: white instead of `currentColor`, attributes in Tabler's order."""
	parts = []
	for tag, attrs in nodes:
		pairs = []
		for key, value in attrs.items():
			if value == "currentColor": value = "#ffffff"
			pairs.append('%s="%s"' % (key, value))
		parts.append("<%s %s/>" % (tag, " ".join(pairs)))
	return "".join(parts)


def import_tabler(folder):
	nodes = json.load(open(os.path.join(folder, "tabler-nodes-outline.json"), encoding="utf-8"))
	meta = json.load(open(os.path.join(folder, "icons.json"), encoding="utf-8"))
	version = json.load(open(os.path.join(folder, "package.json"), encoding="utf-8"))["version"]
	lines = []
	for key, title, items in data.GROUPS:
		lines.append("  (%r, %r, [" % (key, title))
		for name, tabler, _tags, _body in items:
			if tabler not in nodes:
				sys.exit("🛑 Tabler %s has no outline icon '%s' (row %s)" % (version, tabler, name))
			tags = " ".join(icon_set_tres.clean_tags(name, meta[tabler]["tags"]))
			lines.append("    (%s %s %s '%s')," % (('"%s",' % name).ljust(28), ('"%s",' % tabler).ljust(28),
				('"%s",' % tags), svg_body(nodes[tabler])))
		lines.append("  ]),")
	text = open(DATA_FILE, encoding="utf-8").read()
	head = text.split("GROUPS = [", 1)[0]
	tail = text.split("\n]\n", 1)[1]
	head = re.sub(r'TABLER_VERSION = "[^"]*"', 'TABLER_VERSION = "%s"' % version, head)
	open(DATA_FILE, "w", encoding="utf-8").write(head + "GROUPS = [\n" + "\n".join(lines) + "\n]\n" + tail)
	print("refreshed %d rows from Tabler %s → tools/icon_library_data.py" % (len(rows()), version))


def main():
	args = sys.argv[1:]
	if "--import" in args:
		import_tabler(args[args.index("--import") + 1])
		return 0
	files = outputs()
	if "--check" in args:
		stale = [path for path, text in files.items()
			if not os.path.isfile(os.path.join(ADDON, path))
			or open(os.path.join(ADDON, path), encoding="utf-8").read() != text]
		folder = os.path.join(ADDON, "icons", "library")
		known = {os.path.basename(path) for path in files if path.startswith("icons/library/")}
		stray = sorted(name for name in os.listdir(folder) if name.endswith(".svg") and name not in known) \
			if os.path.isdir(folder) else []
		missing_import = sorted(path for path in known if not os.path.isfile(os.path.join(folder, path + ".import")))
		if stale or stray or missing_import:
			print("🛑 the icon library files differ from the table — run python3 tools/make_icon_library.py")
			for path in stale + ["icons/library/" + name + " (not in the table)" for name in stray] \
					+ ["icons/library/" + name + ".import (missing)" for name in missing_import]:
				print("  " + path)
			return 1
		print("✅ %d generated icon library files match the table (%d icons, %d groups, %d aliases)"
			% (len(files), len(rows()), len(data.GROUPS), len(data.ALIASES)))
		return 0
	for path, text in files.items():
		target = os.path.join(ADDON, path)
		os.makedirs(os.path.dirname(target), exist_ok=True)
		with open(target, "w", encoding="utf-8") as handle:
			handle.write(text)
	# 🛑 Godot's default SVG importer bakes a 24px raster — blurry in a 64dp slot. A stub `.import` that names the
	#    vector importer makes the first import produce a `DPITexture`; Godot then fills in the uid and the cache path.
	#    An existing `.import` is left alone — its uid is referenced.
	for path in files:
		stub = os.path.join(ADDON, path) + ".import"
		if path.endswith(".svg") and not os.path.isfile(stub):
			with open(stub, "w", encoding="utf-8") as handle:
				handle.write(IMPORT_STUB % ("res://addons/gohud/" + path))
	folder = os.path.join(ADDON, "icons", "library")
	known = {os.path.basename(path) for path in files if path.startswith("icons/library/")}
	for name in os.listdir(folder):
		base = name[:-len(".import")] if name.endswith(".import") else name
		if base.endswith(".svg") and base not in known:
			os.remove(os.path.join(folder, name))   # a row that left the table takes its drawing with it
	print("%d library icons in %d groups (%d aliases) → icons/library/, icons/gohud_icons_library.tres, core/go_icon_library.gd"
		% (len(rows()), len(data.GROUPS), len(data.ALIASES)))
	return 0


if __name__ == "__main__":
	sys.exit(main())
