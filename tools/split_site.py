# -*- coding: utf-8 -*-
"""큰 쪽을 **절 단위로 가른다** — `widgets` 와 `theming` 을 표지 + 하위 쪽들로.

    python3 addons/gohud/tools/split_site.py            # 17 개 언어를 한 번에
    python3 addons/gohud/tools/split_site.py --check     # 가르지 않고 무엇이 갈릴지만 본다

## 왜 가르나 (2026-09-16 사람 지시 — 여러 번)

`widgets.html` 은 595 줄(40 KB), `theming.html` 은 644 줄(44 KB)이었다. 한 쪽에 위젯 32 개가
들어 있으면 **찾는 것 하나를 보려고 나머지 서른하나를 스크롤해야 한다.** 링크를 주고받을 때도
`#gotable` 같은 조각 주소뿐이라, 받은 사람은 그 긴 쪽의 어디쯤인지 모른 채 열게 된다.

🛑 **이 파일이 생기기 전에는 반대로 적혀 있었다.** `site/toc.js` 와 `tools/site_nav.py` 에
"절 단위로 더 쪼개지 않는다 — 그 자리는 왼쪽 목차가 맡는다" 가 규칙으로 못 박혀 있었고,
그것을 근거로 여러 차례의 요청이 "이미 결정된 것" 으로 처리됐다. 사람의 지시가 그 판단을 덮는다.
목차와 가르기는 **서로를 대신하지 않는다** — 목차는 한 쪽 안을 안내하고, 가르기는 쪽 자체를 줄인다.

## 어떻게 가르나 — 번역을 새로 짓지 않는다

17 개 언어판은 `<section id>` 이 **같다**(영어 기준 id 를 `make_site.py` 가 박아 둔다).
그래서 언어마다 같은 id 를 집어 옮기면, 그 언어의 번역문이 그대로 따라온다. 새 쪽의 제목도
그 언어판의 `<h2>` 를 그대로 쓴다 — 이 스크립트는 **한 글자도 번역하지 않는다.**

| 무엇 | 어디서 |
|---|---|
| 새 쪽의 `<h1>`·표지 카드 제목 | 그 절의 `<h2>` |
| 새 쪽의 `<meta description>`·카드 설명 | 그 절의 첫 `<p>` |
| 머리띠로 돌아가는 말 | `tools/site_nav.py` 의 `NAV` |

## 가른 뒤에 무엇이 따라오나

1. `tools/site_langs.py` 의 `PAGES` 에 새 이름을 더한다 → hreflang·언어 고르개·검사가 따라온다.
2. `python3 tools/make_site.py` → 머리띠(`nav`)·언어 블록·쪽 스크립트가 새 쪽에도 들어간다.
3. `python3 tools/make_search.py` → 검색 색인이 새 쪽을 싣는다.

🛑 **표지 이름(`widgets.html`·`theming.html`)은 그대로 둔다.** 이미 배포된 ZIP 1.0.2·1.0.3 의
README 가 그 주소를 절대 주소로 박아 두었다(`tools/site_langs.py`). 쪽은 더하기만 한다.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ADDON = os.path.normpath(os.path.join(HERE, ".."))
WWW = os.environ.get("GOHUD_SITE_OUTPUT", os.path.join(ADDON, "www"))

import site_langs
import site_nav

# ── 무엇을 어떻게 가르나 ───────────────────────────────────────────────
# (새 파일, [옮길 section id …]) — 순서가 곧 사이드바와 앞뒤 링크의 차례다.
# 🔑 절 하나가 한 쪽이지만, **짝이 되는 절은 함께 둔다**(`hud`+`hud-widgets` 는 "무엇을 왜" 와
#    "그래서 이 위젯들" 이라 떼면 둘 다 반쪽이 된다).
GROUPS = {
	"widgets.html": [
		("widgets-surfaces.html", ["surfaces"]),
		("widgets-messages.html", ["messages"]),
		("widgets-hud.html", ["hud", "hud-widgets"]),
		("widgets-feedback.html", ["feedback"]),
		("widgets-forms.html", ["forms-lists"]),
		("widgets-shapes.html", ["game-shapes"]),
		("widgets-overlays.html", ["overlays"]),
		("widgets-style.html", ["factory", "hooks"]),
	],
	"theming.html": [
		("theming-presets.html", ["layers", "pick", "medieval"]),
		("theming-tokens.html", ["tokens"]),
		("theming-opacity.html", ["opacity"]),
		("theming-skins.html", ["skin"]),
		("theming-own.html", ["own"]),
		("theming-contrast.html", ["contrast"]),
	],
}

# 표지에서 머리띠 메뉴의 어느 칸에 해당하나 — 되돌아가는 말을 그 언어로 쓰기 위해.
NAV_KEY = {"widgets.html": "widgets", "theming.html": "theming"}

MAIN_OPEN = '<main class="wrap">'
MAIN_CLOSE = "</main>"
HERO_OPEN = '<div class="hero">'


def read(path):
	with open(path, encoding="utf-8") as handle:
		return handle.read()


def write(path, text):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w", encoding="utf-8") as handle:
		handle.write(text)


def strip_tags(html):
	"""태그를 걷어낸 알맹이. 카드 설명·`<meta description>` 에 쓴다."""
	text = re.sub(r"<[^>]+>", "", html)
	return re.sub(r"\s+", " ", text).strip()


def first_sentence(text, limit=150):
	"""첫 문장. 🛑 마침표로만 자르지 않는다 — 태국어·중국어에는 그 마침표가 없다."""
	for end in (". ", "。", "· ", "! ", "? "):
		at = text.find(end)
		if 0 < at <= limit:
			return text[: at + (1 if end[0] in ".。!?" else 0)].strip()
	if len(text) <= limit:
		return text
	cut = text.rfind(" ", 0, limit)
	return (text[:cut] if cut > 40 else text[:limit]).rstrip(" ,;:") + "…"


def parts(html):
	"""문서를 넷으로 — 머리(head+머리띠), 표지 머리말, 본문 속, 꼬리."""
	head, rest = html.split(MAIN_OPEN, 1)
	body, tail = rest.split(MAIN_CLOSE, 1)
	hero_at = head.index(HERO_OPEN)
	return head[:hero_at], head[hero_at:], body, tail


def sections(body):
	"""`<section id=…>` 을 **원문 그대로** 집어낸다(들여쓰기·주석까지)."""
	found = {}
	for match in re.finditer(r'<section id="([^"]+)">.*?</section>', body, re.S):
		found[match.group(1)] = match.group(0)
	return found


def swap_in_block(html, begin, end, old, new):
	"""표식 사이에서만 바꾼다 — 본문의 같은 낱말은 건드리지 않는다."""
	if begin not in html or end not in html:
		return html
	start = html.index(begin)
	stop = html.index(end) + len(end)
	return html[:start] + html[start:stop].replace(old, new) + html[stop:]


def retarget(head, cover, page):
	"""머리의 주소들을 이 쪽 것으로. 🔑 정본은 `make_site.py` 가 다시 쓴다 — 여기서는
	가른 직후에도 문서가 혼자 말이 되도록 표식 사이만 맞춰 둔다."""
	for begin, end in (("<!-- hreflang:begin -->", "<!-- hreflang:end -->"),
			("<!-- langs:begin -->", "<!-- langs:end -->")):
		head = swap_in_block(head, begin, end, cover, page)
	return head


def set_title(head, title):
	return re.sub(r"<title>.*?</title>", "<title>%s</title>" % title, head, count=1, flags=re.S)


def set_description(head, text):
	return re.sub(r'<meta name="description" content="[^"]*">',
		'<meta name="description" content="%s">' % text.replace('"', "&quot;"), head, count=1)


def h2_of(section_html):
	match = re.search(r"<h2[^>]*>(.*?)</h2>", section_html, re.S)
	return match.group(1).strip() if match else ""


def lead_of(section_html):
	"""그 절의 첫 문단 — 표지 카드와 `<meta description>` 에 쓴다."""
	match = re.search(r"<p[^>]*>(.*?)</p>", section_html, re.S)
	return strip_tags(match.group(1)) if match else ""


def drop_first_h2(section_html):
	"""첫 `<h2>` 를 뺀다 — 그 말이 새 쪽의 `<h1>` 이 되었으므로 두 번 적지 않는다."""
	return re.sub(r"[ \t]*<h2[^>]*>.*?</h2>\n?", "", section_html, count=1, flags=re.S)


def subnav(lang, cover, pages, titles, current):
	"""이 묶음의 쪽들. 🔑 `site/toc.js` 가 이것을 왼쪽 목차 맨 위로 옮긴다 —
	자바스크립트가 꺼져 있어도 본문 위에 목록으로 남는다(그래서 `hidden` 이 아니다)."""
	label = site_nav.NAV.get(lang, site_nav.NAV["en"]).get(NAV_KEY[cover], NAV_KEY[cover])
	rows = ['<nav class="subnav" aria-label="%s">' % _escape(label),
		'  <!-- subnav:begin -->',
		'  <a href="%s"%s>%s</a>' % (cover, ' aria-current="page"' if current == cover else "", _escape(label))]
	for name, _ids in pages:
		mark = ' aria-current="page"' if name == current else ""
		rows.append('  <a href="%s"%s>%s</a>' % (name, mark, titles[name]))
	rows.append("  <!-- subnav:end -->")
	rows.append("</nav>")
	return "\n".join(rows)


def _escape(text):
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def neighbours(cover, pages, titles, index, nav_label):
	"""꼬리의 앞뒤 링크 — 같은 묶음 안에서만 오간다."""
	previous = (cover, nav_label) if index == 0 else (pages[index - 1][0], titles[pages[index - 1][0]])
	following = (cover, nav_label) if index == len(pages) - 1 else (pages[index + 1][0], titles[pages[index + 1][0]])
	return ('<p><a href="%s">← %s</a> · <a href="%s">%s →</a></p>'
		% (previous[0], previous[1], following[0], following[1]))


def split_language(lang, cover, pages, dry_run):
	source = os.path.join(WWW, site_langs.rel_path(lang.code, cover))
	if not os.path.exists(source):
		return ["%s 없음" % source]
	html = read(source)
	if MAIN_OPEN not in html:
		return ["%s: <main> 을 못 찾았다" % source]
	head, hero, body, tail = parts(html)
	found = sections(body)
	missing = [sid for _name, ids in pages for sid in ids if sid not in found]
	if missing:
		return ["%s: 절이 없다 — %s" % (source, ", ".join(missing))]

	titles = {name: h2_of(found[ids[0]]) for name, ids in pages}
	leads = {name: lead_of(found[ids[0]]) for name, ids in pages}
	nav_label = _escape(site_nav.NAV.get(lang.code, site_nav.NAV["en"]).get(NAV_KEY[cover], NAV_KEY[cover]))
	notes = []

	for index, (name, ids) in enumerate(pages):
		chunks = []
		for order, sid in enumerate(ids):
			chunks.append(drop_first_h2(found[sid]) if order == 0 else found[sid])
		page_head = set_description(set_title(retarget(head, cover, name),
			"%s — gohud" % strip_tags(titles[name])), first_sentence(leads[name], 160))
		page_hero = ('<div class="hero">\n  <div class="wrap">\n    <h1>%s</h1>\n'
			'    <p class="lead"><a href="%s">← %s</a></p>\n  </div>\n</div>\n\n'
			% (titles[name], cover, nav_label))
		page_tail = re.sub(r"<p><a href=.*?</p>", neighbours(cover, pages, titles, index, nav_label),
			tail, count=1, flags=re.S)
		document = (page_head + page_hero + MAIN_OPEN + "\n\n"
			+ subnav(lang.code, cover, pages, titles, name) + "\n\n"
			+ "\n\n".join(chunk.strip("\n") for chunk in chunks)
			+ "\n\n" + MAIN_CLOSE + page_tail)
		target = os.path.join(WWW, site_langs.rel_path(lang.code, name))
		if not dry_run:
			write(target, document)
		notes.append("  %s ← %s" % (site_langs.rel_path(lang.code, name), ", ".join(ids)))

	# 표지 — 카드 목록만 남긴다. 옮긴 절의 본문은 하위 쪽에 있다.
	cards = ['<section id="pages">', '  <div class="grid">']
	for name, _ids in pages:
		cards.append('    <div class="card">')
		cards.append('      <h3><a href="%s">%s</a></h3>' % (name, titles[name]))
		cards.append("      <p>%s</p>" % _escape(first_sentence(leads[name], 130)))
		cards.append("    </div>")
	cards.append("  </div>")
	cards.append("</section>")
	# 🔑 표지에 남기는 절은 없다 — 옮긴 절은 전부 하위 쪽에 있고, 표지는 그 목록이다.
	cover_document = (head + hero + MAIN_OPEN + "\n\n"
		+ subnav(lang.code, cover, pages, titles, cover) + "\n\n"
		+ "\n".join(cards) + "\n\n" + MAIN_CLOSE + tail)
	if not dry_run:
		write(source, cover_document)
	notes.append("  %s ← 표지(카드 %d)" % (site_langs.rel_path(lang.code, cover), len(pages)))
	return notes


def main():
	dry_run = "--check" in sys.argv
	problems = []
	made = 0
	for cover, pages in GROUPS.items():
		print("── %s → 표지 + %d 쪽" % (cover, len(pages)))
		for lang in site_langs.ACTIVE:
			notes = split_language(lang, cover, pages, dry_run)
			for note in notes:
				if note.startswith("  "):
					made += 1
				else:
					problems.append(note)
			if lang.code == "en":
				print("\n".join(note for note in notes if note.startswith("  ")))
	for problem in problems:
		print("🛑 " + problem)
	print("%s %d 쪽 (%d 개 언어)" % ("갈릴 것" if dry_run else "갈랐다", made, len(site_langs.ACTIVE)))
	return 1 if problems else 0


if __name__ == "__main__":
	raise SystemExit(main())
