# -*- coding: utf-8 -*-
"""Find any `class_name` declared **more than once** in the repository.

    python3 addons/gohud/tools/check_classes.py

## 🛑 Why it is needed (measured 2026-09-16)

`examples/usage/` held **a second copy of the addon** to show "what it looks like installed in a
game project", and that copy had no `.gdignore`. So **35 classes were declared twice**, `GoUi`,
`GoConfig` and `GoStyle` among them.

With two of the same `class_name`, Godot picks one and **a person does not get to decide which.**
What it picks depends on scan order and the `.godot` cache, so it can differ from machine to machine.

🛑 **Getting it wrong raises no error.** The class in the old copy works fine on its own, so if the
old one is picked the screen quietly behaves the old way. Unit tests all pass too — the tests look
at **whichever class was picked**. So this collision stays invisible until a person happens to
notice, and only a check can stop it.

🔑 The release ZIP does not include `examples/usage/` (`tools/check_package.py`). What is at risk is
using the whole repository — the **git submodule** route the README describes.

🔑 A folder with a `.gdignore` is skipped whole by Godot, so it is skipped here too — keeping a copy
is not the problem, **leaving it scannable** is.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
SKIP = {".git", ".godot", "builds", "__pycache__", ".cowork", "node_modules"}
CLASS = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def scan():
	"""`class_name` -> the files that declare it. A folder with a `.gdignore` is skipped whole."""
	found = {}
	for root, dirs, files in os.walk(ADDON):
		if ".gdignore" in files:
			dirs[:] = []            # the same rule as Godot — do not descend below this
			continue
		dirs[:] = [name for name in dirs if name not in SKIP]
		for name in sorted(files):
			if not name.endswith(".gd"):
				continue
			path = os.path.join(root, name)
			try:
				text = open(path, encoding="utf-8").read()
			except (UnicodeDecodeError, OSError):
				continue
			for match in CLASS.finditer(text):
				found.setdefault(match.group(1), []).append(os.path.relpath(path, ADDON))
	return found


def main():
	found = scan()
	clashes = {name: paths for name, paths in found.items() if len(paths) > 1}
	print("%d classes declared by scripts" % len(found))
	if not clashes:
		print("\n✅ no name is declared twice")
		return 0
	for name in sorted(clashes):
		print("   🛑 %s — %s" % (name, " · ".join(clashes[name])))
	print("\n🛑 the same class_name appears more than once — %d of them" % len(clashes))
	print("   If the folder holds a copy, put an empty `.gdignore` in it (Godot skips it whole).")
	return 1


if __name__ == "__main__":
	raise SystemExit(main())
