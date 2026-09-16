# -*- coding: utf-8 -*-
"""문서에 적힌 gohud API 가 **실제로 있는가** 를 본다.

    python3 addons/gohud/tools/check_docs_api.py           # 문서 전부
    python3 addons/gohud/tools/check_docs_api.py --list     # 어떤 클래스의 무엇을 아는지 보여만 준다

## 왜 필요한가 (2026-09-16 실측)

새 위젯 열여덟을 문서에 적으면서, **코드를 열어 보지 않고 기억으로 쓴 호출이 아홉 군데 틀렸다.**

| 문서에 적힌 것 | 실제 |
|---|---|
| `coupon.shake()` | 그런 것은 없다 — `set_error(message)` |
| `GoTable.make(cols, rows, 1, false)` | 셋째 인자는 `selectable` — 정렬은 `sort_by()` |
| `GoPagination.Mode.MORE` | 그런 enum 은 없다 — `GoPagination.more(action)` |
| `calendar.claim_requested` | 신호 이름은 `claimed` |
| `console.register(name, action, help)` | 인자 차례가 `(command, help, action)` |
| `field.control()` | 메서드가 아니라 **속성** `field.control` |

문서는 사람이 **그대로 베껴 쓰는 것**이라 틀린 한 줄이 곧 남의 파싱 오류가 된다. 게다가 이런 것은
검사도 사람도 잘 못 잡는다 — 코드가 아니라 글이기 때문이다. 그래서 글에서 호출을 뽑아 코드와 맞춰 본다.

## 어떻게 보나

1. `core/`·`widgets/`·`services/`·`themes/` 에서 클래스마다 **제 멤버**를 거둔다(함수·신호·상수·enum·변수).
2. `extends` 를 따라 올라가며 gohud 조상의 멤버를 더한다. 엔진 클래스에 닿으면 거기서 멈추고,
   그 클래스의 멤버는 Godot 에게 물어 본다(`ClassDB` — 없으면 그 검사만 건너뛴다).
3. 문서의 코드 덩이에서 두 가지를 뽑는다.
   - `GoTable.make(…)` 처럼 **클래스 이름으로 바로** 부르는 것
   - `var board := GoTable.make(…)` · `var t: GoTable` 로 **타입이 드러난 지역 변수**의 `board.sort_by(…)`
4. 어느 쪽에도 없는 이름을 적는다.

🛑 **모르는 것을 틀렸다고 하지 않는다.** 타입을 모르는 변수, 엔진 멤버 목록을 못 얻은 경우는 건너뛴다 —
거짓 경고가 쌓이면 이 검사는 아무도 안 보게 된다.
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
# 엔진 멤버를 물어 볼 클래스 — gohud 가 상속하는 것들. 못 물어 보면 그 클래스 밑은 검사하지 않는다.
CACHE = os.path.join(HERE, "__pycache__", "engine_members.json")

# GDScript·엔진의 낱말 — 멤버가 아니지만 글에서 코드처럼 적는다.
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
	"""소스에 적힌 **이름 문자열**을 거둔다.

	🔑 토큰(`&"gap_tiny"`)·문구 키(`&"bar_percent"`)·입력 액션(`&"ui_open"`)은 상수의 **값**이라
	   멤버 이름으로는 잡히지 않는다. 문서는 그 값을 그대로 쓰므로 함께 알아야 한다.
	🔑 `class_name` 이 없는 스크립트(`core/go_runtime.gd`)의 멤버도 여기서 거둔다 — 그런 파일의
	   신호 이름(`breakpoint_changed`)을 문서가 가리킨다.
	"""
	# 🔑 파이썬 도구와 JSON 도 본다 — 팔레트·스킨 다이얼의 키(`cut_ratio`)는 거기에만 있다.
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
			# 🔑 **이름: 타입** 을 전부 거둔다 — 함수의 매개변수가 여기 든다(`tooltip_key: StringName`).
			#    여러 줄로 이어진 시그니처가 흔하므로 줄 단위로 `func` 를 찾지 않는다. 지역 변수까지
			#    섞여 관대해지지만, 이 검사의 목적은 **없는 이름을 잡는 것**이지 이름을 세는 것이 아니다.
			names.update(re.findall(r"\b([a-z][a-z0-9_]*)\s*:\s*[A-Z]", text))
			for line in text.splitlines():
				match = MEMBER.match(line)
				if match:
					names.update(part for part in match.groups() if part)

	return names


# 🛑 `@export var`·`static var`·`@onready var` 를 빠뜨리면 **있는 속성을 없다고 한다** — 처음 돌렸을 때
#    `GoBar.ink`·`GoHudAnchor.spot` 이 그래서 거짓 경고로 나왔다(411 건 중 대부분).
MEMBER = re.compile(
	r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"          # @export · @export_range(…) · @onready …
	r"(?:static\s+)?"                            # static var · static func
	r"(?:func\s+([a-z_][A-Za-z0-9_]*)"
	r"|signal\s+([a-z_][A-Za-z0-9_]*)"
	r"|var\s+([a-z_][A-Za-z0-9_]*)"
	r"|const\s+([A-Za-z_][A-Za-z0-9_]*)"
	r"|enum\s+([A-Z][A-Za-z0-9_]*)"
	r"|class\s+([A-Z][A-Za-z0-9_]*))")

# 🔑 어느 클래스에나 있는 것 — `ClassDB` 는 생성자를 멤버로 내놓지 않는다.
ALWAYS = {"new"}


RETURNS = re.compile(r"^\s*(?:static\s+)?func\s+([a-z_][A-Za-z0-9_]*)\s*\(.*?\)\s*->\s*([A-Za-z_][A-Za-z0-9_]*)", re.S)


def scan_sources():
	"""클래스 → (제 멤버, 부모 이름, 메서드의 반환형).

	🛑 반환형이 있어야 `var column := GoStyle.column()` 의 타입을 안다 — 그것을 `GoStyle` 로 보면
	   뒤따르는 `column.add_child(…)` 가 죄다 거짓 경고가 된다(처음 돌렸을 때 21 건이 그랬다).
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
			# enum 안의 값은 `GoDrawer.Side.LEFT` 로 쓰이므로 함께 거둔다.
			for value in re.findall(r"^\t([A-Z][A-Z0-9_]*)\s*(?:,|=|##|$)", line):
				names.add(value)
		own[name] = names
		for line in text.splitlines():
			back = RETURNS.match(line)
			if back:
				returns[(name, back.group(1))] = back.group(2)
	return own, parent, returns


def engine_members(classes):
	"""Godot 에게 그 엔진 클래스의 멤버를 묻는다. 못 물어 보면 빈 표 — 그러면 그 밑은 검사하지 않는다."""
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
	# 🔑 "*" 는 엔진 **전체**의 이름 묶음이다 — 글 속에 적힌 `mouse_filter` 같은 이름이 실재하는지
	#    보려면 어느 클래스의 것인지 모르는 채로도 물어볼 수 있어야 한다.
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
	"""주석을 걷어낸다.

	🛑 이것이 없으면 **주석에 적은 예시가 진짜 선언으로 읽힌다** — "이렇게 쓰지 말라" 며 적어 둔
	   `var hud: CanvasLayer` 한 줄 때문에 그 블록 전체가 거짓 경고를 냈다(2026-09-16 실측).
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
	# 🔑 문서가 쓰는 반환형이 엔진 클래스면 그 멤버도 물어 봐야 `column.add_child(…)` 를 볼 수 있다.
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
		"""그 클래스의 멤버를 **끝까지** 알 수 있는가 — 모르면 검사하지 않는다."""
		while name in own:
			name = parent.get(name, "")
		return not name or name in engine

	if "--list" in sys.argv:
		for name in sorted(own):
			print("%-20s %s → %d 개%s" % (name, parent.get(name, "?"), len(members(name)),
				"" if known(name) else "  (엔진 멤버를 못 얻어 검사하지 않는다)"))
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
				# 🛑 타입을 모르거나, 그 클래스의 멤버를 끝까지 알 수 없으면 **묻지 않는다.**
				if not target or (target not in own and target not in engine):
					continue
				if not known(target):
					continue
				if member in members(target):
					continue
				problems.append((rel, line_of(path, offset), target, member, head))

	# ── 글 속에 적힌 멤버 이름 ────────────────────────────────────────
	# 🛑 코드 덩이만 보면 **산문에 적은 이름은 그냥 지나간다** — 2026-09-16 에 `hide_on_handheld` 를
	#    세 문서에서 `hide_on_touch` 로 적었고, 위의 검사는 그것을 하나도 잡지 못했다.
	#    밑줄이 든 소문자 이름은 영어 낱말이 아니라 거의 언제나 코드의 이름이다.
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
			print("   🛑 %s:%d — 글에 적힌 `%s` 라는 이름이 어디에도 없다" % (rel, line, member))
			continue
		via = "" if head == target else " (%s 는 %s)" % (head, target)
		print("   🛑 %s:%d — %s 에 `%s` 가 없다%s" % (rel, line, target, member, via))
	print("문서 %d장 · gohud 클래스 %d개 · 엔진 클래스 %d개%s"
		% (len(list(docs())), len(own), len(engine),
		   "" if engine else " 🛑 (Godot 을 못 불러 상속 멤버는 검사하지 않았다)"))
	if seen:
		print("\n🛑 문서가 없는 API 를 가리킨다 — %d 곳" % len(seen))
		return 1
	print("\n✅ 문서의 gohud 호출이 모두 실재한다")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
