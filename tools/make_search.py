# -*- coding: utf-8 -*-
"""The global search index — one bundle per language, holding all its pages, written to
`www/site/search/<code>.js`.

## Why `.js` and not `.json` (🛑 do not change this)
`tools/site_shots.sh` opens the pages over **`file://`** to photograph them. There, `fetch()` dies
quietly on CORS — the hardest kind of breakage to catch, because it works in a browser and fails
only in the screenshot check. So the index is emitted in a shape `<script src>` can load (a global
variable assignment). That way it opens the same over `file://`, on GitHub Pages, and from an
offline copy.

## How it is sliced
Sliced by **exactly** the rule `site/toc.js` uses to build the table of contents — sections
(`section[id]`) and the subheadings inside them (`h3[id]`, except those inside cards). That way the
place a search result jumps to and the place shown in the contents are the same. Heading ids are
stamped in English by `tools/make_site.py`, so the address stays the same across languages.

## What goes in
Titles, prose and code go in **separately** (`t`, `x`, `c`).
- Words in a title have to score higher, so that a search for `GoSheet` puts the section describing
  that widget at the top and the ones merely mentioning it below.
- A subheading slice carries the index of the section it belongs to (`p`) — one line of a result
  should be enough to tell where the discussion lives.
- Code must be findable but **comes last when shown.** With code and prose in one bag, the snippet
  that came with a result read like `var sheet := GoSheet.new() add_child(sheet)…` and was hard to
  read (screenshot 2026-09-16). What a person needs to read first is the sentence saying what the
  section does.
"""
import html
import json
import os
import re
from html.parser import HTMLParser

import site_langs

# Marks where the language picker starts — past it are language names, not page names.
LANGS_MARK = "<!-- langs:begin -->"

HERE = os.path.dirname(os.path.abspath(__file__))
# 🛑 Reads the same environment variable as `make_site.py` — `check_site.py` rebuilds into a temp
#    folder and compares against the current files. Without this the check overwrites the original and always passes.
WWW = os.environ.get("GOHUD_SITE_OUTPUT", os.path.join(os.path.dirname(HERE), "www"))
OUT = os.path.join(WWW, "site", "search")

# Tags whose text must not be run together — put a space at their boundaries. Inline tags such as
# `<b>` and `<code>` are the opposite, and must be joined (if `Go<b>Surface</b>` splits into "Go Surface" the name is unfindable).
BLOCK = {"p", "div", "section", "li", "ul", "ol", "tr", "td", "th", "table", "thead", "tbody",
         "pre", "h1", "h2", "h3", "h4", "h5", "h6", "figure", "figcaption", "br", "hr", "blockquote"}
DROP = {"script", "style", "svg", "noscript"}


class Cutter(HTMLParser):
    """Walk through `<main>` and slice it by section and subheading."""

    def __init__(self):
        HTMLParser.__init__(self)
        self.inside = False      # are we inside <main>?
        self.drop = 0            # are we inside a tag that is dropped whole?
        self.stack = []          # [(tag, class)] — used to tell apart an h3 inside a card
        self.cuts = []           # the slices
        self.buf = []            # prose of the current slice
        self.code = []           # code of the current slice (inside `<pre>`)
        self.pre = 0             # are we inside a code block?
        self.cap = None          # a list while a title is being collected
        self.sec = None          # id of the current section
        self.sec_open = False    # have we already seen this section's h2?

    # ── slice bookkeeping ──────────────────────────────────
    def _flush(self):
        if self.cuts:
            self.cuts[-1]["x"] = squeeze("".join(self.buf))
            self.cuts[-1]["c"] = squeeze("".join(self.code))
        self.buf, self.code = [], []

    def _begin(self, anchor, sub):
        self._flush()
        # For a subheading, note the index of its section — results then show a path like "Widgets › Layout".
        parent = -1
        if sub:
            for i in range(len(self.cuts) - 1, -1, -1):
                if not self.cuts[i]["s"]:
                    parent = i
                    break
        self.cuts.append({"a": anchor, "t": "", "s": 1 if sub else 0, "x": "", "c": "", "p": parent})
        self.cap = []

    # ── parser callbacks ───────────────────────────────────
    def handle_starttag(self, tag, attrs):
        if tag == "main":
            self.inside = True
            return
        if not self.inside:
            return
        if tag in DROP:
            self.drop += 1
            return
        at = dict(attrs)
        self.stack.append((tag, at.get("class", "")))
        if tag == "pre":
            self.pre += 1
        if tag in BLOCK:
            (self.code if self.pre else self.buf).append(" ")
        if tag == "section" and at.get("id"):
            self.sec, self.sec_open = at["id"], False
        elif tag == "h2" and self.sec and not self.sec_open:
            self.sec_open = True
            self._begin(self.sec, False)
        elif tag == "h3" and at.get("id") and not self._in_card():
            self._begin(at["id"], True)

    def handle_endtag(self, tag):
        if tag == "main":
            self.inside = False
            self._flush()
            return
        if not self.inside:
            return
        if tag in DROP:
            self.drop = max(0, self.drop - 1)
            return
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break
        if tag == "pre":
            self.pre = max(0, self.pre - 1)
        if tag in ("h2", "h3") and self.cap is not None:
            self.cuts[-1]["t"] = squeeze("".join(self.cap))
            self.cap = None
        elif tag in BLOCK:
            (self.code if self.pre else self.buf).append(" ")

    def handle_data(self, data):
        if not self.inside or self.drop:
            return
        if self.cap is not None:
            self.cap.append(data)
        elif self.cuts:
            (self.code if self.pre else self.buf).append(data)

    # ── helpers ────────────────────────────────────────────
    def _in_card(self):
        return any("card" in cls.split() for _, cls in self.stack)


def squeeze(text):
    """Collapse newlines and runs of spaces into one space. Half the index size goes away here."""
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def cut_page(path):
    cutter = Cutter()
    cutter.feed(open(path, encoding="utf-8").read())
    cutter.close()
    return [c for c in cutter.cuts if c["t"]]


# 🛑 Do not hard-code the page names — build them from `site_langs.PAGES`. While they were
#    hard-coded, adding a page kept the check green (`check_site.py` only looked at the old three
#    names) while the new page's label stayed English in all 17 languages (2026-09-16).
NAV = re.compile(r'<a (?:class="[^"]*" )?href="(\./|%s)"[^>]*>(.*?)</a>'
                 % "|".join(re.escape(p) for p in site_langs.PAGES if p != "index.html"), re.S)


def page_names(code):
    """Get the page names in that language — the header menu already has them translated.

    🔑 Since the menu became a product of `tools/site_nav.py`, **whichever page you read** has all five.
    🛑 Read only inside `<nav>` — the logo before it is `href="./"` too, so reading the whole header
       makes the first page name "gohud" instead of the word for "Intro" in that language (measured 2026-09-16).
    """
    path = os.path.join(WWW, site_langs.rel_path(code, "theming.html"))
    names = {}
    if os.path.isfile(path):
        head = open(path, encoding="utf-8").read().split("</header>", 1)[0]
        head = head.split("<nav>", 1)[-1].split(LANGS_MARK, 1)[0]
        for href, label in NAV.findall(head):
            text = squeeze(re.sub(r"<[^>]+>", "", label)).rstrip("↗").strip()
            if text:
                names.setdefault({"./": "index.html"}.get(href, href), text)
    return [names.get(page, page.replace(".html", "").title() or "Home")
            for page in site_langs.PAGES]


def build(code):
    """Write one language's index file. Returns page count, slice count and size."""
    docs, pages = [], 0
    for i, page in enumerate(site_langs.PAGES):
        path = os.path.join(WWW, site_langs.rel_path(code, page))
        if not os.path.isfile(path):
            continue
        pages += 1
        base = len(docs)
        for cut in cut_page(path):
            # 🛑 `p` was an index **within that page** — all pages go in one bag, so rebase it here.
            docs.append([i, cut["a"], cut["t"], cut["s"], cut["x"], cut["c"],
                         base + cut["p"] if cut["p"] >= 0 else -1])
    if not docs:
        return 0, 0, 0
    body = {"p": list(site_langs.PAGES), "n": page_names(code), "d": docs}
    text = ("window.GOHUD_SEARCH=window.GOHUD_SEARCH||{};\nwindow.GOHUD_SEARCH[%s]=%s;\n"
            % (json.dumps(code), json.dumps(body, ensure_ascii=False, separators=(",", ":"))))
    os.makedirs(OUT, exist_ok=True)
    target = os.path.join(OUT, "%s.js" % (code or "en"))
    old = open(target, encoding="utf-8").read() if os.path.isfile(target) else None
    if old != text:
        open(target, "w", encoding="utf-8").write(text)
    return pages, len(docs), len(text.encode("utf-8"))


def write_all():
    total, biggest = 0, ("", 0)
    for lang in site_langs.ACTIVE:
        pages, docs, size = build(lang.code)
        total += size
        if size > biggest[1]:
            biggest = (lang.code or "en", size)
        if pages != len(site_langs.PAGES):
            print("🛑 %s — only %d/%d pages" % (lang.code, pages, len(site_langs.PAGES)))
    print("search index — %d languages · %.0fKB total · largest %s %.0fKB (only that one is downloaded at a time)"
          % (len(site_langs.ACTIVE), total / 1024, biggest[0], biggest[1] / 1024))
    return total


if __name__ == "__main__":
    write_all()
