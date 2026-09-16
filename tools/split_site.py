# -*- coding: utf-8 -*-
"""**Split big pages by section** — `widgets` and `theming` become a cover page plus sub-pages.

    python3 addons/gohud/tools/split_site.py            # all 17 languages at once
    python3 addons/gohud/tools/split_site.py --check     # split nothing, only show what would be split

## Why split (human instruction 2026-09-16 — several times)

`widgets.html` was 595 lines (40 KB) and `theming.html` 644 lines (44 KB). With 32 widgets on one
page, **you scroll past thirty-one of them to see the one you came for.** Sharing a link gives only
a fragment address like `#gotable`, so whoever receives it opens that long page with no idea where
in it they are.

🛑 **Before this file existed, the opposite was written down.** `site/toc.js` and
`tools/site_nav.py` nailed down the rule "do not split further by section — the left-hand table of
contents covers that", and on that basis several requests were treated as "already decided". A
human instruction overrides that judgement. Contents and splitting **do not substitute for each
other** — the contents guides you within a page, splitting shrinks the page itself.

## How the split works — no new translation is written

All 17 language editions share **the same** `<section id>` (`make_site.py` stamps the English ids).
So picking the same id per language and moving it brings that language's translated text along. A
new page's title reuses the `<h2>` of that language edition — this script **translates not one
character.**

| What | Comes from |
|---|---|
| the new page's `<h1>` and the cover card title | that section's `<h2>` |
| the new page's `<meta description>` and card text | that section's first `<p>` |
| the wording of the link back to the header | `NAV` in `tools/site_nav.py` |

## What follows a split

1. Add the new names to `PAGES` in `tools/site_langs.py` → hreflang, language picker and checks follow.
2. `python3 tools/make_site.py` → header (`nav`), language block and page scripts go into the new pages.
3. `python3 tools/make_search.py` → the search index picks the new pages up.

🛑 **Leave the cover names (`widgets.html`, `theming.html`) alone.** The README in the already
released ZIPs 1.0.2 and 1.0.3 hard-codes those as absolute addresses (`tools/site_langs.py`). Pages
are only ever added.
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

# ── what gets split and how ───────────────────────────────────────────
# (new file, [section ids to move …]) — the order is also the sidebar and prev/next order.
# 🔑 One section is one page, but **sections that belong together stay together** (`hud` +
#    `hud-widgets` are "what and why" and "so here are the widgets" — split, each is half a page).
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

# Which header menu entry the cover corresponds to — so the link back is worded in that language.
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
	"""The content with tags stripped. Used for card text and `<meta description>`."""
	text = re.sub(r"<[^>]+>", "", html)
	return re.sub(r"\s+", " ", text).strip()


def first_sentence(text, limit=150):
	"""The first sentence. 🛑 Do not cut on a period alone — Thai and Chinese do not have that period."""
	for end in (". ", "。", "· ", "! ", "? "):
		at = text.find(end)
		if 0 < at <= limit:
			return text[: at + (1 if end[0] in ".。!?" else 0)].strip()
	if len(text) <= limit:
		return text
	cut = text.rfind(" ", 0, limit)
	return (text[:cut] if cut > 40 else text[:limit]).rstrip(" ,;:") + "…"


def parts(html):
	"""The document in four — head (head + header bar), hero, body, tail."""
	head, rest = html.split(MAIN_OPEN, 1)
	body, tail = rest.split(MAIN_CLOSE, 1)
	hero_at = head.index(HERO_OPEN)
	return head[:hero_at], head[hero_at:], body, tail


def sections(body):
	"""Pick out `<section id=…>` **verbatim** (indentation and comments included)."""
	found = {}
	for match in re.finditer(r'<section id="([^"]+)">.*?</section>', body, re.S):
		found[match.group(1)] = match.group(0)
	return found


def swap_in_block(html, begin, end, old, new):
	"""Replace only between the markers — the same word in the body is left alone."""
	if begin not in html or end not in html:
		return html
	start = html.index(begin)
	stop = html.index(end) + len(end)
	return html[:start] + html[start:stop].replace(old, new) + html[stop:]


def retarget(head, cover, page):
	"""Point the head's addresses at this page. 🔑 `make_site.py` rewrites the authoritative
	version — here we only fix what is between the markers, so the document makes sense on its
	own right after the split."""
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
	"""That section's first paragraph — used for the cover card and `<meta description>`."""
	match = re.search(r"<p[^>]*>(.*?)</p>", section_html, re.S)
	return strip_tags(match.group(1)) if match else ""


def drop_first_h2(section_html):
	"""Drop the first `<h2>` — those words became the new page's `<h1>`, so do not write them twice."""
	return re.sub(r"[ \t]*<h2[^>]*>.*?</h2>\n?", "", section_html, count=1, flags=re.S)


def subnav(lang, cover, pages, titles, current):
	"""The pages of this group. 🔑 `site/toc.js` moves this to the top of the left-hand contents —
	with JavaScript off it stays as a list above the body (which is why it is not `hidden`)."""
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
	"""The prev/next links in the tail — they only move within the same group."""
	previous = (cover, nav_label) if index == 0 else (pages[index - 1][0], titles[pages[index - 1][0]])
	following = (cover, nav_label) if index == len(pages) - 1 else (pages[index + 1][0], titles[pages[index + 1][0]])
	return ('<p><a href="%s">← %s</a> · <a href="%s">%s →</a></p>'
		% (previous[0], previous[1], following[0], following[1]))


def split_language(lang, cover, pages, dry_run):
	source = os.path.join(WWW, site_langs.rel_path(lang.code, cover))
	if not os.path.exists(source):
		return ["%s does not exist" % source]
	html = read(source)
	if MAIN_OPEN not in html:
		return ["%s: could not find <main>" % source]
	head, hero, body, tail = parts(html)
	found = sections(body)
	missing = [sid for _name, ids in pages for sid in ids if sid not in found]
	if missing:
		return ["%s: sections missing — %s" % (source, ", ".join(missing))]

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

	# The cover — only the card list stays. The moved sections' bodies live on the sub-pages.
	cards = ['<section id="pages">', '  <div class="grid">']
	for name, _ids in pages:
		cards.append('    <div class="card">')
		cards.append('      <h3><a href="%s">%s</a></h3>' % (name, titles[name]))
		cards.append("      <p>%s</p>" % _escape(first_sentence(leads[name], 130)))
		cards.append("    </div>")
	cards.append("  </div>")
	cards.append("</section>")
	# 🔑 No section stays on the cover — every moved section is on a sub-page, and the cover is their list.
	cover_document = (head + hero + MAIN_OPEN + "\n\n"
		+ subnav(lang.code, cover, pages, titles, cover) + "\n\n"
		+ "\n".join(cards) + "\n\n" + MAIN_CLOSE + tail)
	if not dry_run:
		write(source, cover_document)
	notes.append("  %s ← cover (%d cards)" % (site_langs.rel_path(lang.code, cover), len(pages)))
	return notes


def main():
	dry_run = "--check" in sys.argv
	problems = []
	made = 0
	for cover, pages in GROUPS.items():
		print("── %s → cover + %d pages" % (cover, len(pages)))
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
	print("%s %d pages (%d languages)" % ("would split" if dry_run else "split", made, len(site_langs.ACTIVE)))
	return 1 if problems else 0


if __name__ == "__main__":
	raise SystemExit(main())
