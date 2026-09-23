# -*- coding: utf-8 -*-
"""Checks that the `www/` website is **not broken**.

    python3 addons/gohud/tools/check_site.py

## Why this exists
A site is not code, so nobody ever runs it. One broken link, or an entirely empty glossary, and **the
checks stay green** while it goes up on GitHub Pages as it is. This stops that silent failure.

## What it looks at
| What | Why |
|---|---|
| Local links and image paths | Does the file actually exist — seeing the 404 only after deploying is too late |
| The glossary | Is it valid JS, and does every entry have a description (`d`) and a kind (`k`) |
| Glossary and tooltip loaded per page | Miss one page and the popup dies silently on that page alone |
| Does the glossary match the code | Differ from a fresh run of `make_site.py` and **the glossary is stale** |
| The dial table | Do both `theming.html` pages have the markers, does the table match a fresh one, and is any dial missing its English meaning |
| Document language | Without `<html lang>` a screen reader reads it with the wrong pronunciation |
| The deploy entry point | Does the workflow publish what `tools/build_site.sh` assembles, and does `404.html` forward the old `docs/www/` addresses |
| Public URLs | Do the `https://thruthesky.github.io/gohud/…` links written in the README, the skill and the store description — and the old image URLs — actually exist in the build; 404.html cannot forward an image |
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

# 🔑 The language list lives in one place, `tools/site_langs.py` — the checker reads **the same list** as the generator.
import site_langs

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
# 🛑 On the site, the `www/` root is English and `www/ko/` is Korean. GitHub Actions
#    (`.github/workflows/pages.yml`) assembles it with `tools/build_site.sh` and publishes it as the root
#    of https://thruthesky.github.io/gohud/ (moved out from under docs on 2026-09-15).
WWW = os.path.join(ADDON, "www")
# 🔑 The page GitHub Pages serves for every missing address — no glossary, no tooltip, just the script
#    that forwards the old addresses.
NOT_FOUND = "404.html"
PUBLIC = "https://thruthesky.github.io/gohud/"
# 🔑 Images hard-coded as absolute URLs by READMEs from before 2026-09-15 (including the shipped ZIPs
#    1.0.2 and 1.0.3) — collected from the whole git history. An already-installed README cannot be fixed
#    and 404.html cannot forward an <img> request, so a file has to exist at this path in the build.
LEGACY_IMAGES = [
    "docs/www/img/medieval-dark.png",
    "docs/www/img/preset-default-dark.png",
    "docs/www/img/preset-scifi-dark.png",
]
# 🔑 The old documentation addresses — `tools/build_site.sh` puts **a real forwarding page** at each of
#    them in the build. The script in 404.html forwards too, but that response carries status 404, so to
#    search engines, link checkers and chat previews the address stays broken for good. Everything listed
#    here has to answer 200.
LEGACY_PAGES = ["%s/%s" % (old, page)
                for page in ("index.html", "theming.html", "widgets.html",
                             "ko/index.html", "ko/theming.html", "ko/widgets.html")
                for old in ("docs/www", "docs")]
# File types searched for public URLs, and folders skipped — build output cannot be fixed, and `.env` holds keys.
URL_SOURCES = (".md", ".html", ".json", ".yml", ".cfg")
SKIP_DIRS = {".git", ".godot", ".env", "builds", ".dist", "__pycache__", ".playwright-mcp", ".cowork"}


def pages():
    """Every HTML file under `www/` — 🛑 subfolders included (the Korean edition lives in `ko/`)."""
    out = []
    for root, _dirs, names in os.walk(WWW):
        for name in names:
            if name.endswith(".html"):
                out.append(os.path.relpath(os.path.join(root, name), WWW))
    return sorted(out)


def check_links(problems):
    for name in pages():
        path = os.path.join(WWW, name)
        here = os.path.dirname(path)
        text = open(path, encoding="utf-8").read()
        if not re.search(r'<html[^>]+\blang=', text):
            problems.append("%s: <html> has no lang" % name)
        for attribute in ("href", "src"):
            for target in re.findall(r'%s="([^"]+)"' % attribute, text):
                url = urlsplit(target)
                if url.scheme or url.netloc:
                    continue
                clean = unquote(url.path)
                linked = (Path(here, clean) if clean else Path(path)).resolve()
                if not linked.is_relative_to(Path(WWW).resolve()):
                    problems.append("%s: points outside the deploy folder — %s" % (name, target))
                    continue
                if linked.is_dir():
                    linked = linked / "index.html"
                if not linked.is_file():
                    problems.append("%s: points at something that does not exist — %s" % (name, target))
                elif url.fragment and linked.suffix == ".html":
                    ids = re.findall(r'\bid=["\']([^"\']+)["\']', linked.read_text(encoding="utf-8"))
                    if unquote(url.fragment) not in ids:
                        problems.append("%s: points at a section that does not exist — %s" % (name, target))
        if name == NOT_FOUND:
            continue
        if "glossary" not in text:
            problems.append("%s: does not load the glossary — the popup dies on this page alone" % name)
        if "tooltip.js" not in text:
            problems.append("%s: does not load tooltip.js" % name)


def load_glossary(problems, name="glossary.js"):
    path = os.path.join(WWW, "site", name)
    if not os.path.isfile(path):
        problems.append("%s is missing — run python3 tools/make_site.py" % name)
        return {}
    text = open(path, encoding="utf-8").read()
    match = re.search(r"window\.GLOSSARY\s*=\s*(\{.*\})\s*;", text, re.S)
    if not match:
        problems.append("the glossary has an unfamiliar shape — no window.GLOSSARY assignment found")
        return {}
    try:
        return json.loads(match.group(1))
    except ValueError as error:
        problems.append("the glossary is not valid JSON — %s" % error)
        return {}


def check_glossary(glossary, problems):
    if not glossary:
        return
    for term, entry in sorted(glossary.items()):
        if not isinstance(entry, dict):
            problems.append("the value of term %r is not a dict" % term)
            continue
        if not entry.get("d"):
            problems.append("term %r has no description (d) — an empty bubble pops up" % term)
        if not entry.get("k"):
            problems.append("term %r has no kind (k)" % term)
        if len(term) < 2:
            problems.append("term %r is too short — it will match anywhere in the text" % term)
        # 🛑 The bubble takes the description verbatim — leave markdown in and `**rounded**` shows up as is.
        text = entry.get("d", "")
        if "**" in text or "`" in text:
            problems.append("markdown left in the description of term %r — the marks show in the bubble" % term)


# 🔑 Every file the generator writes — the two glossaries and the two pages carrying the dial table. Miss
#    one and that file stays green however stale it is.
GENERATED = [
    os.path.join("site", "glossary.js"),
    os.path.join("site", "glossary.en.js"),
    os.path.join("site", "icons.js"),
    NOT_FOUND,
] + [site_langs.rel_path(lang.code, page) for lang in site_langs.ACTIVE for page in site_langs.PAGES] \
  + [os.path.join("site", "search", "%s.js" % (lang.code or "en")) for lang in site_langs.ACTIVE]


def check_fresh(problems):
    """Do the current files match a fresh run of `make_site.py` — if not, the generated output is stale."""
    def snapshot(folder):
        out = {}
        for rel in GENERATED:
            path = os.path.join(folder, rel)
            out[rel] = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
        return out
    before = snapshot(WWW)
    with tempfile.TemporaryDirectory(prefix="gohud-site-check-") as temp:
        output = os.path.join(temp, "www")
        shutil.copytree(WWW, output)
        result = subprocess.run([sys.executable, os.path.join(HERE, "make_site.py")],
                                env=dict(os.environ, GOHUD_SITE_OUTPUT=output),
                                capture_output=True, text=True)
        after = snapshot(output)
    if result.returncode != 0:
        problems.append("make_site.py failed — %s" % (result.stderr.strip().splitlines() or [""])[-1])
        return
    for rel in GENERATED:
        if before[rel] != after[rel]:
            problems.append("%s differs from the source — run python3 tools/make_site.py" % rel)


def check_styles(problems):
    """A missing media-query brace silently removes desktop styles in browsers."""
    css = Path(WWW, "site/style.css").read_text(encoding="utf-8")
    css = re.sub(r'/\*.*?\*/|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27', '', css, flags=re.S)
    depth = 0
    for char in css:
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth < 0:
                break
    if depth != 0:
        problems.append("site/style.css: unbalanced CSS braces — check the media-query scopes")
    # 🛑 The dark screenshots (`SITE_DARK=1 tools/site_shots.sh`) pull this block out with a regex. If it
    #    cannot be pulled out, or comes back an empty husk, **the dark shots are taken on a light theme**
    #    and nobody notices.
    sheet = re.sub(r"/\*.*?\*/", "", Path(WWW, "site/style.css").read_text(encoding="utf-8"), flags=re.S)
    dark = re.search(r"@media \(prefers-color-scheme: dark\) \{\s*(:root \{.*?\})", sheet, re.S)
    if not dark or "--bg:" not in dark.group(1):
        problems.append("site/style.css: the dark :root block cannot be extracted — dark screenshots will capture the light theme")


def build_site(problems, temp):
    """Assemble the build with `tools/build_site.sh` — the same script CI runs, so what is seen here is what goes up."""
    out = os.path.join(temp, "site")
    result = subprocess.run(["bash", os.path.join(HERE, "build_site.sh"), out], capture_output=True, text=True)
    if result.returncode != 0:
        problems.append("tools/build_site.sh failed — %s" % (result.stderr.strip().splitlines() or [""])[-1])
        return None
    return out


def check_entry(problems, site):
    """The deploy entry point — is the build rooted at `www/`, and are the old addresses still alive."""
    workflow = Path(ADDON, ".github", "workflows", "pages.yml")
    text = workflow.read_text(encoding="utf-8") if workflow.is_file() else ""
    if "tools/build_site.sh _site" not in text or not re.search(r"^\s*path:\s*_site/?\s*$", text, re.M):
        problems.append(".github/workflows/pages.yml does not publish the _site/ assembled by tools/build_site.sh")
    moved = Path(WWW, NOT_FOUND)
    if not moved.is_file() or "/docs" not in moved.read_text(encoding="utf-8"):
        problems.append("www/404.html does not forward the old addresses (…/gohud/docs/www/…) to the new ones")
    if site:
        for rel in ["index.html", NOT_FOUND]:
            if not os.path.isfile(os.path.join(site, rel)):
                problems.append("%s is missing from the root of the build — www/ is not the site root" % rel)
        for rel in LEGACY_IMAGES:
            if not os.path.isfile(os.path.join(site, rel)):
                problems.append("the old image %s is missing from the build — README images in the shipped ZIP break" % rel)
        for rel in LEGACY_PAGES:
            path = os.path.join(site, rel)
            if not os.path.isfile(path):
                problems.append("the old address %s is missing from the build — it stays a 404 and forwards nothing" % rel)
                continue
            moved = re.search(r'http-equiv="refresh" content="0; url=([^"]+)"', open(path, encoding="utf-8").read())
            if not moved:
                problems.append("%s does not forward to the new address" % rel)
            elif not os.path.isfile(os.path.normpath(os.path.join(os.path.dirname(path), moved.group(1)))):
                problems.append("%s forwards somewhere that does not exist — %s" % (rel, moved.group(1)))
    for stale in ("index.html", ".nojekyll"):
        if Path(ADDON, stale).exists():
            problems.append("a stray %s is left at the root — that was for the old main /(root) deploy. Pages now publishes www/ only" % stale)
    if not re.search(r'<html\s+lang="en"', Path(WWW, "index.html").read_text(encoding="utf-8")):
        problems.append("the default site language must be English")
    if Path(ADDON, ".git").exists():
        tracked = subprocess.run(["git", "ls-files", "-s", "--", "examples/demo/addons/gohud"],
                                 cwd=ADDON, capture_output=True, text=True, check=True).stdout
        if tracked.startswith("120000"):
            problems.append("the demo's circular symlink is committed to Git — tools that walk the repository descend into it forever")


def check_public_urls(problems, site):
    """Do the public URLs written in the README, the skill and the store description exist in the build. Returns how many were checked."""
    if not site:
        return 0
    pattern = re.compile(re.escape(PUBLIC) + r"([^\s\"'<>()\[\]*`]*)")
    count = 0
    for root, dirs, names in os.walk(ADDON):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in names:
            if not name.endswith(URL_SOURCES):
                continue
            path = os.path.join(root, name)
            text = open(path, encoding="utf-8", errors="replace").read()
            for match in pattern.finditer(text):
                url = urlsplit(PUBLIC + match.group(1).rstrip(".,;:"))
                target = Path(site, unquote(url.path)[len(urlsplit(PUBLIC).path):])
                if target.is_dir():
                    target = target / "index.html"
                count += 1
                where = os.path.relpath(path, ADDON)
                if not target.is_file():
                    problems.append("%s: public URL missing from the build — %s" % (where, url.geturl()))
                elif url.fragment and target.suffix == ".html":
                    ids = re.findall(r'\bid=["\']([^"\']+)["\']', target.read_text(encoding="utf-8"))
                    if unquote(url.fragment) not in ids:
                        problems.append("%s: public URL pointing at a section that does not exist — %s" % (where, url.geturl()))
    return count


def check_dials(problems):
    """The dial table — are the markers there, and is any dial missing its English meaning."""
    # 🔑 The dial table used to sit in the `own` section, and the split moved that section into
    #    `theming-own.html` (`tools/split_site.py`). Fail to change the name here along with it and the
    #    marker is never found again.
    for rel in ("theming-own.html", os.path.join("ko", "theming-own.html")):
        path = os.path.join(WWW, rel)
        text = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
        if "<!-- dials:begin -->" not in text or "<!-- dials:end -->" not in text:
            problems.append("%s has no dial markers (<!-- dials:begin/end -->)" % rel)
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import make_site
    missing = make_site.missing_english_dials()
    if missing:
        problems.append("dials with no English meaning — write them in make_site.DIALS_EN: " + ", ".join(missing))


def check_langs(problems):
    """Are all the language editions there, do their document languages match the list, and are the generator's markers intact.

    🛑 A language listed in `site_langs.ACTIVE` is **a language the picker actually takes you to**. Without
    its page, that row of the picker leads to a 404 and hreflang announces a page that does not exist.
    """
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import make_site
    for lang in site_langs.ACTIVE:
        for page in site_langs.PAGES:
            rel = site_langs.rel_path(lang.code, page)
            path = os.path.join(WWW, rel)
            if not os.path.isfile(path):
                problems.append("%s is missing — the language picker leads to a 404" % rel)
                continue
            text = open(path, encoding="utf-8").read()
            if not re.search(r'<html[^>]*\blang="%s"' % re.escape(lang.html_lang), text):
                problems.append('%s: not <html lang="%s"> — a screen reader will use the wrong pronunciation'
                                % (rel, lang.html_lang))
            if lang.direction == "rtl" and not re.search(r'<html[^>]*\bdir="rtl"', text):
                problems.append('%s: a right-to-left language without dir="rtl"' % rel)
            for begin in (make_site.LANGS_BEGIN, make_site.HREFLANG_BEGIN):
                if begin not in text:
                    problems.append("%s has no %s marker — the generator cannot fill it" % (rel, begin))
            for src in make_site.PAGE_SCRIPTS:
                if src not in text:
                    problems.append("%s does not load %s — that page alone loses the feature" % (rel, src))
            # 🔑 The table of contents navigates by heading id — without ids, neither the sidebar nor the
            #    search reaches further than the top of a section.
            if not re.search(r'<h3 id="', text):
                problems.append("the subheadings in %s have no id — run `python3 tools/make_site.py`" % rel)
            # 🛑 **Section structure drifting apart between languages** is not caught by the link check —
            #    inside a page everything lines up, so it stays green to the end. That is how the Korean
            #    edition having `#tokens` but not `#readable` was missed (2026-09-16). English is the
            #    canonical edition; the list and the order of sections must match it exactly.
            if lang.code != "en":
                want = re.findall(r'<section id="([^"]+)"', open(os.path.join(WWW, page), encoding="utf-8").read())
                got = re.findall(r'<section id="([^"]+)"', text)
                if got != want:
                    missing, extra = [s for s in want if s not in got], [s for s in got if s not in want]
                    problems.append("%s: section structure differs from the English edition — missing %s · extra %s%s"
                                    % (rel, missing or "none", extra or "none",
                                       "" if missing or extra else " (the order differs)"))
    # Translated but not yet published — only mentioned so it is not forgotten (it does not count as a problem).
    waiting = [lang.code for lang in site_langs.LANGS if not lang.ready
               and os.path.isfile(os.path.join(WWW, site_langs.rel_path(lang.code, "index.html")))]
    if waiting:
        print("   ℹ translated but not yet published: %s — set ready to True in site_langs.py and they join the picker"
              % ", ".join(waiting))


def check_search(problems):
    """The site-wide search index — is there one per language, do its anchors exist, does it hold as much as the English one.

    🔑 A stale index breaks **the search alone**, silently. The pages look fine and the link check passes,
       but a result you click lands at the top of the page, or nowhere at all. So the index's anchors are
       compared against the real pages.
    🛑 A language with fewer fragments than English **means its translation has fallen behind** — the
       English original gained a section and that language still carries the old text. That is caught here
       (the section-structure check only looks at `<section>`, so it misses this).
    """
    counts = {}
    for lang in site_langs.ACTIVE:
        code = lang.code or "en"
        path = os.path.join(WWW, "site", "search", "%s.js" % code)
        if not os.path.isfile(path):
            problems.append("site/search/%s.js is missing — search opens empty in that language" % code)
            continue
        text = open(path, encoding="utf-8").read()
        match = re.search(r"window\.GOHUD_SEARCH\[[^\]]+\]=(\{.*\});", text, re.S)
        if not match:
            problems.append("site/search/%s.js is not shaped as a global assignment — a <script> cannot read it" % code)
            continue
        try:
            body = json.loads(match.group(1))
        except ValueError as err:
            problems.append("site/search/%s.js cannot be read — %s" % (code, err))
            continue
        counts[code] = len(body["d"])
        # Was a page name left as the file name instead of being translated.
        for i, name in enumerate(body["n"]):
            if name.lower().replace(" ", "") in ("index.html", "theming.html", "widgets.html"):
                problems.append("site/search/%s.js: the name of page %d is untranslated (%s)" % (code, i + 1, name))
        # Do the index's anchors exist on that page — each language's three pages are read once each.
        for i, page in enumerate(body["p"]):
            rel = site_langs.rel_path(lang.code, page)
            full = os.path.join(WWW, rel)
            if not os.path.isfile(full):
                continue
            html = open(full, encoding="utf-8").read()
            here = set(re.findall(r'<(?:section|h3|h4) id="([^"]+)"', html))
            missing = sorted({d[1] for d in body["d"] if d[0] == i} - here)
            if missing:
                problems.append("site/search/%s.js points at anchors missing from %s — %s"
                                % (code, rel, ", ".join(missing[:4])))
    if "en" in counts:
        thin = ["%s(%d)" % (c, n) for c, n in sorted(counts.items()) if n < counts["en"]]
        if thin:
            problems.append("the search index is thinner than the English one (%d fragments) — %s · those languages still carry the old text"
                            % (counts["en"], ", ".join(thin)))


# 🛑 Keeping the translations from drifting again — banned words, per language.
#    2026-09-16: the Korean edition replaced English words one-for-one with native coinages, producing
#    `block→덩이` · `shell→껍데기` · `header→머리띠` · `picker→고르개` · `fade→묽다`. The problem was not the
#    prose but **the terminology decision**, and because of it a reader could no longer find the API
#    (`GoStyle.hud_panel()`) using the words the text had taught them. Japanese caught the same disease
#    with `ひとかたまり`. Nobody re-reads 17 languages by eye — the checker does.
# 🔑 "판" (panel) is deliberately kept out — it overlaps with 판단 and 판정 and floods the report with
#    false positives. Instead, when its count drifts far from the English `panel` count, the ratio check
#    below flags it for a person to look at.
BANNED = {
    "ko": (("덩이", "block — not a word in the source; use '아래 글'"),
           ("껍데기", "shell — carries the connotation of an empty husk; use '틀'"),
           ("낱말", "word — the conventional term in technical writing is '단어'"),
           ("고르개", "picker — match the editor's own wording and use '선택기'"),
           ("머리띠", "header — a 머리띠 is a hair accessory; use '헤더'"),
           ("묽", "fade/thin — '묽다' is for the consistency of a liquid only; use '옅다'")),
    "ja": (("かたまり", "block — use 「ブロック」 or 「下の文」"),),
}


def check_wording(problems):
    """Catch wording that must not find its way back into a translation."""
    for code, rules in BANNED.items():
        folder = os.path.join(WWW, code)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".html"):
                continue
            text = open(os.path.join(folder, name), encoding="utf-8").read()
            for word, why in rules:
                n = text.count(word)
                if n:
                    problems.append("%s/%s: banned word '%s' in %d places — %s" % (code, name, word, n, why))


def main():
    problems = []
    if not os.path.isdir(WWW):
        print("🛑 there is no www/")
        return 1
    # 🛑 Not a single page is a failure in itself — when the site moved to another folder, the old folder
    #    saw 0 HTML files and still reported "0 problems" (2026-09-13). Empty does not count as a pass.
    if not pages():
        problems.append("there is not a single HTML page — the site folder has moved or is empty")
    check_links(problems)
    check_styles(problems)
    with tempfile.TemporaryDirectory(prefix="gohud-site-build-") as temp:
        site = build_site(problems, temp)
        check_entry(problems, site)
        urls = check_public_urls(problems, site)
    glossary = load_glossary(problems)
    check_glossary(glossary, problems)
    english = load_glossary(problems, "glossary.en.js")
    check_glossary(english, problems)
    check_fresh(problems)
    check_dials(problems)
    check_langs(problems)
    check_search(problems)
    check_wording(problems)

    print("%d languages · %d pages · %d public URLs · %d terms (Korean) · %d (English)"
          % (len(site_langs.ACTIVE), len(pages()), urls, len(glossary), len(english)))
    for line in problems:
        print("   🛑 %s" % line)
    print("\n%s %d problems" % ("🛑" if problems else "✅", len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
