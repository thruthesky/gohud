# -*- coding: utf-8 -*-
"""Check that the gohud API written in the docs **really exists**.

    python3 addons/gohud/tools/check_docs_api.py           # every document
    python3 addons/gohud/tools/check_docs_api.py --list     # only show what it knows about which class

## Why it is needed (measured 2026-09-16)

While writing up eighteen new widgets, **nine calls written from memory without opening the code
were wrong.**

| Written in the docs | Reality |
|---|---|
| `coupon.shake()` | no such thing — `set_error(message)` |
| `GoTable.make(cols, rows, 1, false)` | the third argument is `selectable` — sorting is `sort_by()` |
| `GoPagination.Mode.MORE` | no such enum — `GoPagination.more(action)` |
| `calendar.claim_requested` | the signal is named `claimed` |
| `console.register(name, action, help)` | the argument order is `(command, help, action)` |
| `field.control()` | not a method but a **property**, `field.control` |

Docs are **copied verbatim** by people, so one wrong line becomes someone else's parse error. And
this kind of mistake is caught poorly by tests and by people alike — it is prose, not code. So we
pull the calls out of the prose and match them against the code.

## How it looks

1. Collect each class's **own members** from `core/`, `widgets/`, `services/` and `themes/`
   (functions, signals, constants, enums, variables).
2. Walk up `extends` and add the members of gohud ancestors. Stop at an engine class and ask Godot
   for that class's members (`ClassDB` — if that is unavailable, skip only that check).
3. Pull two kinds of things out of the code blocks in the docs.
   - calls made **straight on a class name**, like `GoTable.make(…)`
   - `board.sort_by(…)` on a **local variable whose type is visible** from
     `var board := GoTable.make(…)` or `var t: GoTable`
4. Report any name that is in neither.

🛑 **Never call unknown wrong.** Variables of unknown type, and cases where the engine member list
could not be obtained, are skipped — once false alarms pile up nobody reads this check any more.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
SOURCE_DIRS = ["core", "widgets", "services", "themes/skins", "themes"]
DOC_GLOBS = [
	("skills/gohud", ".md"),
	("", "README.md"),
	("", "README.ko.md"),
	("www", ".html"),
]
# Classes whose engine members we ask for — the ones gohud extends. If we cannot ask, nothing below them is checked.
CACHE = os.path.join(HERE, "__pycache__", "engine_members.json")

# GDScript and engine words — not members, but the prose writes them like code.
KEYWORDS = {"class_name", "canvas_items", "corner_radius", "content_margin", "set_theme",
	"extends", "func_name", "res_path"}


def sources():
	for folder in SOURCE_DIRS:
		root = os.path.join(ADDON, folder)
		if not os.path.isdir(root):
			continue
		for name in sorted(os.listdir(root)):
			if name.endswith(".gd"):
				yield os.path.join(root, name)


def literals():
	"""Collect the **name strings** written in the source.

	🔑 Tokens (`&"gap_tiny"`), phrase keys (`&"bar_percent"`) and input actions (`&"ui_open"`) are the
	   **values** of constants, so they are never caught as member names. The docs quote them verbatim.
	🔑 Members of scripts with no `class_name` (`core/go_runtime.gd`) are collected here too — the docs
	   point at signal names from such files (`breakpoint_changed`).
	"""
	# 🔑 Look at the Python tools and the JSON too — palette and skin dial keys (`cut_ratio`) live only there.
	names = set(KEYWORDS)
	for root, dirs, files in os.walk(ADDON):
		dirs[:] = [d for d in dirs if d not in (".git", ".godot", "builds", "__pycache__", "usage")]
		for name in files:
			if os.path.splitext(name)[1] not in (".gd", ".py", ".json"):
				continue
			try:
				text = open(os.path.join(root, name), encoding="utf-8").read()
			except (UnicodeDecodeError, OSError):
				continue
			names.update(re.findall(r'&?["\']([a-z][a-z0-9]*(?:_[a-z0-9]+)+)["\']', text))
			if not name.endswith(".gd"):
				continue
			# 🔑 Collect every **name: Type** — a function's parameters land here (`tooltip_key: StringName`).
			#    Signatures often wrap across lines, so we do not scan for `func` line by line. Local variables
			#    get mixed in and make it lenient, but this check exists to **catch names that do not exist**, not to count them.
			names.update(re.findall(r"\b([a-z][a-z0-9_]*)\s*:\s*[A-Z]", text))
			for line in text.splitlines():
				match = MEMBER.match(line)
				if match:
					names.update(part for part in match.groups() if part)

	return names


# 🛑 Miss `@export var`, `static var` or `@onready var` and it **calls existing properties missing** — on the
#    first run `GoBar.ink` and `GoHudAnchor.spot` came out as false alarms that way (most of the 411 hits).
MEMBER = re.compile(
	r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"          # @export · @export_range(…) · @onready …
	r"(?:static\s+)?"                            # static var · static func
	r"(?:func\s+([a-z_][A-Za-z0-9_]*)"
	r"|signal\s+([a-z_][A-Za-z0-9_]*)"
	r"|var\s+([a-z_][A-Za-z0-9_]*)"
	r"|const\s+([A-Za-z_][A-Za-z0-9_]*)"
	r"|enum\s+([A-Z][A-Za-z0-9_]*)"
	r"|class\s+([A-Z][A-Za-z0-9_]*))")

# 🔑 Present on every class — `ClassDB` does not list the constructor as a member.
ALWAYS = {"new"}


RETURNS = re.compile(r"^\s*(?:static\s+)?func\s+([a-z_][A-Za-z0-9_]*)\s*\(.*?\)\s*->\s*([A-Za-z_][A-Za-z0-9_]*)", re.S)


def scan_sources():
	"""class -> (own members, parent name, method return types).

	🛑 Return types are what tell us the type of `var column := GoStyle.column()` — read as `GoStyle`,
	   every following `column.add_child(…)` turns into a false alarm (21 of them on the first run).
	"""
	own, parent, returns = {}, {}, {}
	for path in sources():
		text = open(path, encoding="utf-8").read()
		found = re.search(r"^class_name\s+([A-Za-z0-9_]+)", text, re.M)
		if not found:
			continue
		name = found.group(1)
		base = re.search(r"^extends\s+([A-Za-z0-9_]+)", text, re.M)
		parent[name] = base.group(1) if base else ""
		names = set()
		for line in text.splitlines():
			match = MEMBER.match(line)
			if match:
				names.update(part for part in match.groups() if part)
			# Values inside an enum are written as `GoDrawer.Side.LEFT`, so collect them too.
			for value in re.findall(r"^\t([A-Z][A-Z0-9_]*)\s*(?:,|=|##|$)", line):
				names.add(value)
		own[name] = names
		for line in text.splitlines():
			back = RETURNS.match(line)
			if back:
				returns[(name, back.group(1))] = back.group(2)
	return own, parent, returns


def engine_members(classes):
	"""Ask Godot for that engine class's members. If we cannot ask, an empty table — then nothing below it is checked."""
	if os.path.exists(CACHE):
		try:
			cached = json.load(open(CACHE, encoding="utf-8"))
			if set(classes) <= set(cached):
				return cached
		except (ValueError, OSError):
			pass
	godot = os.environ.get("GODOT_BIN") or _which("godot")
	project = _host_project()
	if not godot or not project:
		return {}
	script = os.path.join(project, ".gohud_engine_members.gd")
	with open(script, "w", encoding="utf-8") as handle:
		handle.write('''extends SceneTree
func _initialize() -> void:
	var out := {}
	for name in %s:
		if not ClassDB.class_exists(name): continue
		var names := []
		for row in ClassDB.class_get_method_list(name): names.append(row["name"])
		for row in ClassDB.class_get_property_list(name): names.append(row["name"])
		for row in ClassDB.class_get_signal_list(name): names.append(row["name"])
		out[name] = names
	# 🔑 "*" is the bundle of **every** engine name — to tell whether a name written in prose, such as
	#    `mouse_filter`, is real, we have to be able to ask without knowing which class owns it.
	var every := {}
	for name in ClassDB.get_class_list():
		for row in ClassDB.class_get_method_list(name, true): every[row["name"]] = true
		for row in ClassDB.class_get_property_list(name, true): every[row["name"]] = true
		for row in ClassDB.class_get_signal_list(name, true): every[row["name"]] = true
	out["*"] = every.keys()
	print("GOHUD_MEMBERS " + JSON.stringify(out))
	quit()
''' % json.dumps(sorted(classes)))
	try:
		done = subprocess.run([godot, "--headless", "--path", project, "-s", script],
			capture_output=True, text=True, timeout=180)
		for line in done.stdout.splitlines():
			if line.startswith("GOHUD_MEMBERS "):
				table = json.loads(line[len("GOHUD_MEMBERS "):])
				os.makedirs(os.path.dirname(CACHE), exist_ok=True)
				json.dump(table, open(CACHE, "w", encoding="utf-8"))
				return table
	except (OSError, subprocess.SubprocessError, ValueError):
		pass
	finally:
		if os.path.exists(script):
			os.remove(script)
	return {}


def _which(name):
	for folder in os.environ.get("PATH", "").split(os.pathsep):
		candidate = os.path.join(folder, name)
		if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
			return candidate
	return None


def _host_project():
	folder = ADDON
	while folder != "/":
		if os.path.isfile(os.path.join(folder, "project.godot")):
			return folder
		folder = os.path.dirname(folder)
	return None


def docs():
	for folder, suffix in DOC_GLOBS:
		root = os.path.join(ADDON, folder) if folder else ADDON
		if suffix.startswith("."):
			for walk_root, dirs, files in os.walk(root):
				dirs[:] = [d for d in dirs if d not in (".git", "site", "img", "__pycache__")]
				for name in sorted(files):
					if name.endswith(suffix):
						yield os.path.join(walk_root, name)
		else:
			path = os.path.join(root, suffix)
			if os.path.isfile(path):
				yield path


CODE_MD = re.compile(r"```(?:gdscript|gd)?\n(.*?)```", re.S)
CODE_HTML = re.compile(r"<pre><code>(.*?)</code></pre>", re.S)


def code_blocks(path):
	text = open(path, encoding="utf-8").read()
	pattern = CODE_HTML if path.endswith(".html") else CODE_MD
	for match in pattern.finditer(text):
		block = match.group(1)
		if path.endswith(".html"):
			block = (block.replace("&lt;", "<").replace("&gt;", ">")
				.replace("&quot;", '"').replace("&amp;", "&"))
			block = re.sub(r"<[^>]+>", "", block)
		yield match.start(), block


def uncomment(block):
	"""Strip the comments.

	🛑 Without this, **an example written in a comment reads as a real declaration** — a single
	   `var hud: CanvasLayer` line left there to say "do not write it this way" made the whole block false-alarm (measured 2026-09-16).
	"""
	out = []
	for line in block.splitlines():
		quote = None
		for index, letter in enumerate(line):
			if quote:
				if letter == quote and line[index - 1: index] != "\\":
					quote = None
			elif letter in "\"'":
				quote = letter
			elif letter == "#":
				line = line[:index]
				break
		out.append(line)
	return "\n".join(out)


def line_of(path, offset):
	return open(path, encoding="utf-8").read().count("\n", 0, offset) + 1


DECLARE = re.compile(r"\bvar\s+([a-z_][A-Za-z0-9_]*)\s*"
	r"(?::\s*([A-Z][A-Za-z0-9_]*)"
	r"|:?=\s*([A-Z][A-Za-z0-9_]*)\.([a-z_][A-Za-z0-9_]*)\s*\()")
USE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.([a-z_][A-Za-z0-9_]*|[A-Z][A-Za-z0-9_]*)\b")


def main():
	own, parent, returns = scan_sources()
	needed = {base for base in parent.values() if base and base not in own}
	# 🔑 If a return type the docs use is an engine class, we must ask for its members too to see `column.add_child(…)`.
	needed |= {kind for kind in returns.values() if kind not in own and kind[:1].isupper()}
	engine = engine_members(needed)

	def members(name, seen=None):
		seen = seen or set()
		if name in seen:
			return set()
		seen.add(name)
		if name in own:
			return own[name] | members(parent.get(name, ""), seen) | ALWAYS
		return set(engine.get(name, [])) | ALWAYS

	def known(name):
		"""Can we know that class's members **all the way up**? If not, do not check it."""
		while name in own:
			name = parent.get(name, "")
		return not name or name in engine

	if "--list" in sys.argv:
		for name in sorted(own):
			print("%-20s %s → %d members%s" % (name, parent.get(name, "?"), len(members(name)),
				"" if known(name) else "  (engine members unavailable — not checked)"))
		return 0

	problems = []
	for path in docs():
		rel = os.path.relpath(path, ADDON)
		for offset, block in code_blocks(path):
			block = uncomment(block)
			types = {}
			for match in DECLARE.finditer(block):
				if match.group(2):                       # var x: GoTable
					kind = match.group(2)
				else:                                    # var x := GoTable.make(…) / GoTable.new()
					holder, call = match.group(3), match.group(4)
					kind = holder if call == "new" else returns.get((holder, call), "")
				if kind:
					types[match.group(1)] = kind
			for match in USE.finditer(block):
				head, member = match.group(1), match.group(2)
				target = head if head in own else types.get(head)
				# 🛑 If the type is unknown, or that class's members cannot be known all the way up, **do not ask.**
				if not target or (target not in own and target not in engine):
					continue
				if not known(target):
					continue
				if member in members(target):
					continue
				problems.append((rel, line_of(path, offset), target, member, head))

	# ── member names written in the prose ─────────────────────────────
	# 🛑 Looking only at code blocks lets **names written in prose slip straight past** — on 2026-09-16
	#    `hide_on_handheld` was written as `hide_on_touch` in three documents, and the check above caught none of it.
	#    A lowercase name with an underscore is almost never an English word — it is nearly always a name from the code.
	everything = set()
	for names in own.values():
		everything |= names
	everything |= set(engine.get("*", [])) | literals()
	prose = re.compile(r"`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`")
	for path in docs():
		rel = os.path.relpath(path, ADDON)
		text = open(path, encoding="utf-8").read()
		for match in prose.finditer(text):
			name = match.group(1)
			if name in everything or name in ALWAYS:
				continue
			problems.append((rel, text.count("\n", 0, match.start()) + 1, "(prose)", name, "(prose)"))

	seen = set()
	for rel, line, target, member, head in problems:
		key = (rel, target, member)
		if key in seen:
			continue
		seen.add(key)
		if target == "(prose)":
			print("   🛑 %s:%d — the name `%s` written in the prose exists nowhere" % (rel, line, member))
			continue
		via = "" if head == target else " (%s is a %s)" % (head, target)
		print("   🛑 %s:%d — %s has no `%s`%s" % (rel, line, target, member, via))
	print("%d documents · %d gohud classes · %d engine classes%s"
		% (len(list(docs())), len(own), len(engine),
		   "" if engine else " 🛑 (could not run Godot — inherited members were not checked)"))
	if seen:
		print("\n🛑 the docs point at APIs that do not exist — %d places" % len(seen))
		return 1
	print("\n✅ every gohud call in the docs is real")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
