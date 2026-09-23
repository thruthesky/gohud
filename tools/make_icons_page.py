# -*- coding: utf-8 -*-
"""Build all 17 `icons.html` pages, the catalog data `www/site/icons.js`, and every icon count on the site.

    python3 tools/make_icons_page.py

## Where the material comes from
- **Wording** — `tools/site_icons_text.py` (17 languages). The code blocks below are English in every language.
- **Head and tail** (`<head>`, header bar, footer, scripts) — the `index.html` of the same language, as
  `make_ai_page.py` does, so the language picker, hreflang and glossary paths line up by themselves.
- **Every count** — the sets themselves: `tools/make_icons.py` (default), `tools/make_game_icons.py` (game),
  `tools/icon_library_data.py` (library), `icons/medieval/` (medieval), `package.json` (version).

## Counts are written, never typed
A `<span data-n="KEY">…</span>` on any page of any language gets its number rewritten here, with that
language's thousands separator. KEY is one of `icons` (every drawing), `core`, `game`, `library`, `medieval`,
`reach` (names the library makes drawable) or `version`. 🛑 The front page advertised "100 icons" in 17
languages while there were 287 (found 2026-09-23) — a number a person types goes stale the day a set grows.

## The catalog
`www/site/icons.js` is one global assignment (`window.GOHUD_ICONS = …`), not JSON — `tools/site_shots.sh` opens
pages from `file://`, where `fetch()` is refused (`tools/make_search.py` does the same for the same reason).
It holds every drawing's inner SVG with white turned into `currentColor`, so the page's text color draws it.
`www/site/icon-catalog.js` (hand-written) renders it 120 at a time — never all 1,287 nodes at once.

🛑 This script rewrites `icons.html` **completely** and owns every `data-n` span. Edit the wording in
`tools/site_icons_text.py`, the structure here.
"""
import html
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
WWW = os.environ.get("GOHUD_SITE_OUTPUT", os.path.join(ADDON, "www"))

sys.path.insert(0, HERE)
import icon_library_data  # noqa: E402
import site_icons_text  # noqa: E402
import site_langs  # noqa: E402

PAGE = "icons.html"
DATA = os.path.join("site", "icons.js")
STROKE_HEAD = 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'

# Thousands separator per language — `Intl.NumberFormat` does the same in the catalog script.
SEPARATOR = {"es": ".", "pt": ".", "it": ".", "id": ".", "tr": ".", "vi": ".",
             "ru": " ", "uk": " ", "pl": " ", "fr": " "}


# ── What the sets hold ────────────────────────────────────────────────

def _default_icons():
    text = open(os.path.join(HERE, "make_icons.py"), encoding="utf-8").read()
    return re.findall(r'^  "([a-z_0-9]+)":', text, re.M)


def _game_rows():
    text = open(os.path.join(HERE, "make_game_icons.py"), encoding="utf-8").read()
    return re.findall(r'^    \("([a-z_0-9]+)",\s+"([a-z0-9:-]+)"', text, re.M)


def _tres_dict(path, field, value=r'PackedStringArray\(([^)]*)\)'):
    """`field = Dictionary[…]({&"key": value, …})` of a `.tres` → {key: raw value}."""
    text = open(path, encoding="utf-8").read()
    line = re.search(r"^%s = .*$" % field, text, re.M)
    if not line:
        return {}
    return dict(re.findall(r'&"([a-z_0-9]+)": %s' % value, line.group(0)))


def _strings(raw):
    return re.findall(r'"([^"]*)"', raw)


def counts():
    game = _game_rows()
    library = sum(len(items) for _k, _t, items in icon_library_data.GROUPS)
    medieval = len([n for n in os.listdir(os.path.join(ADDON, "icons", "medieval")) if n.endswith(".svg")])
    core = len(_default_icons())
    version = json.load(open(os.path.join(ADDON, "package.json"), encoding="utf-8"))["version"]
    tabler = sum(1 for _n, source in game if source.startswith("tabler:"))
    return {"core": core, "game": len(game), "library": library, "medieval": medieval,
            "icons": core + len(game) + library + medieval, "reach": core + len(game) + library,
            "tabler": tabler, "own": len(game) - tabler, "version": version,
            "tabler_version": icon_library_data.TABLER_VERSION}


def number(code, value):
    if isinstance(value, str):
        return value
    sep = SEPARATOR.get(code, ",")
    return "{:,}".format(value).replace(",", sep)


# ── The catalog data ──────────────────────────────────────────────────

def _inner(path):
    """An SVG file's content between the root tags, white → `currentColor`."""
    text = open(path, encoding="utf-8").read()
    inner = text.split(">", 1)[1].rsplit("</svg>", 1)[0]
    # 🛑 White is spelled three ways across the sets (`#ffffff`, `#fff`, `white` — the medieval seal); miss one and
    #    that drawing is white on a white page (the seal was, 2026-09-23).
    return re.sub(r'"(?:#fff|#ffffff|white)"', '"currentColor"', inner, flags=re.I).strip()


def catalog():
    """`window.GOHUD_ICONS` — every drawing, in display order: default, medieval, game, library."""
    icons, groups = [], []
    core = os.path.join(ADDON, "icons", "gohud_icons.tres")
    core_groups = {k: _strings(v) for k, v in _tres_dict(core, "groups").items()}
    core_titles = _tres_dict(core, "group_titles", r'"([^"]*)"')
    core_tags = {k: _strings(v) for k, v in _tres_dict(core, "tags").items()}
    for key, names in core_groups.items():
        groups.append([key, core_titles.get(key, key)])
        for name in names:
            icons.append([name, "default", key, " ".join(core_tags.get(name, [])),
                          _inner(os.path.join(ADDON, "icons", "default", name + ".svg"))])
    groups.append(["engraved", "Engraved"])
    for file in sorted(os.listdir(os.path.join(ADDON, "icons", "medieval"))):
        if file.endswith(".svg"):
            name = file[:-4]
            icons.append([name, "medieval", "engraved", " ".join(core_tags.get(name, [])),
                          _inner(os.path.join(ADDON, "icons", "medieval", file))])
    game = os.path.join(ADDON, "icons", "gohud_icons_game.tres")
    game_titles = _tres_dict(game, "group_titles", r'"([^"]*)"')
    game_tags = {k: _strings(v) for k, v in _tres_dict(game, "tags").items()}
    known = {key for key, _title in groups}
    for key, names in ((k, _strings(v)) for k, v in _tres_dict(game, "groups").items()):
        if key not in known:
            groups.append([key, game_titles.get(key, key)])
            known.add(key)
        for name in names:
            icons.append([name, "game", key, " ".join(game_tags.get(name, [])),
                          _inner(os.path.join(ADDON, "icons", "game", name + ".svg"))])
    for key, title, items in icon_library_data.GROUPS:
        if key not in known:
            groups.append([key, title])
            known.add(key)
        for name, _tabler, tags, _body in items:
            icons.append([name, "library", key, tags, _inner(os.path.join(ADDON, "icons", "library", name + ".svg"))])
    aliases = dict(_tres_dict(game, "aliases", r'&"([a-z_0-9]+)"'))
    aliases.update(icon_library_data.ALIASES)
    body = {"heads": {"default": STROKE_HEAD, "game": STROKE_HEAD, "library": STROKE_HEAD, "medieval": ""},
            "groups": groups, "aliases": dict(sorted(aliases.items())), "icons": icons}
    return ("/* Generated by tools/make_icons_page.py from the icon sets — do not edit. */\n"
            "window.GOHUD_ICONS=%s;\n" % json.dumps(body, ensure_ascii=False, separators=(",", ":")))


# ── The page ──────────────────────────────────────────────────────────

def inline(text, code, n):
    """Escape, fill the counts, and turn `name` into <code>name</code>."""
    for key in ("icons", "core", "game", "library", "medieval", "reach", "tabler", "own"):
        text = text.replace("{%s}" % key, number(code, n[key]))
    text = text.replace("{total}", number(code, n["icons"])).replace("{version}", n["tabler_version"])
    out = html.escape(text, quote=False)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", out)


def pre(code_text):
    return "<pre><code>%s</code></pre>" % html.escape(code_text, quote=False)


CODE_NAMES = """GoStyle.icon_button(GoIconSet.SETTINGS, open_settings)   # a button
slot.icon_name = GoGameIcons.BACKPACK                     # a quick slot
var mark := GoUi.icons().node(&"cloud_rain", 24)          # a bare Control, any size"""

CODE_ON = """GoUi.add_icons(GoIconLibrary.icon_set())   # the library — and the game set under it
GoUi.add_icons(GoGameIcons.icon_set())     # or the game set alone"""

CODE_ORDER = """GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)
GoUi.add_icons(GoIconLibrary.icon_set())

GoUi.icons().texture(&"sword")      # the medieval engraving — its own drawing comes first
GoUi.icons().texture(&"rocket")     # from the game set
GoUi.icons().canonical(&"gear")     # &"settings" — an alias"""

CODE_CUSTOM = """# Override a few names — everything else still comes from the set in use
var mine := GoIconSet.new()
mine.fallback = GoUi.icons()
mine.textures = {GoIconSet.CLOSE: preload("res://art/close.svg")}
GoUi.config.icons = mine

# A folder of drawings — file name = icon name, each read when first drawn
GoUi.config.icons = GoIconSet.from_folder("res://art/icons", GoUi.icons())"""

CODE_SEARCH = """var icons := GoUi.icons()
icons.search("arrow left", 5)       # best matches first: back, arrow_bar_left …
icons.search("rain")                # cloud_rain, then drawings tagged "rain\""""

CODE_GROUPS = """icons.group_names()                 # every group key, in lookup order
icons.names_in_group(&"weather")    # one group, in display order — every set's share of it
icons.group_title(&"weather")       # "Weather & sky\""""

CODE_CANONICAL = """icons.canonical(&"gear")            # &"settings"
icons.canonical(&"treasure_chest")  # &"chest" — Tabler's name for a game drawing
icons.has_icon(&"cloud_rain")       # true once the library is added — nothing is loaded to answer"""


def head_and_tail(code, say):
    path = os.path.join(WWW, site_langs.rel_path(code, "index.html"))
    text = open(path, encoding="utf-8").read()
    head = text.split('<div class="hero">', 1)[0]
    tail = text.split("</main>", 1)[1]
    head = re.sub(r"<title>.*?</title>", "<title>%s — gohud</title>" % say("title"), head, flags=re.S)
    head = re.sub(r'<meta name="description" content="[^"]*">',
                  '<meta name="description" content="%s">' % html.escape(say("desc_plain"), quote=True), head)
    up = "../" if site_langs.BY_CODE[code].folder else ""
    scripts = '<script src="%ssite/icons.js"></script>\n<script src="%ssite/icon-catalog.js"></script>\n' % (up, up)
    tail = tail.replace("</body>", scripts + "</body>", 1)
    return head, tail


def build(code, n):
    raw = lambda key: site_icons_text.text(code, key)  # noqa: E731
    say = lambda key: inline(raw(key), code, n)  # noqa: E731
    say_plain = lambda key: re.sub(r"<[^>]+>", "", html.unescape(say(key)))  # noqa: E731
    head, tail = head_and_tail(code, lambda key: say_plain("desc") if key == "desc_plain" else say_plain(key))

    sets = [("", raw("set_all"), n["icons"]), ("default", raw("set_default"), n["core"]),
            ("game", raw("set_game"), n["game"]), ("library", raw("set_library"), n["library"]),
            ("medieval", raw("set_medieval"), n["medieval"])]
    set_buttons = "\n".join(
        '        <button type="button" data-set="%s" data-title="%s" aria-pressed="%s">%s <span>%s</span></button>'
        % (key, html.escape(title, quote=True), "true" if not key else "false", html.escape(title), number(code, count))
        for key, title, count in sets)
    attrs = " ".join('data-%s="%s"' % (name, html.escape(raw(key), quote=True)) for name, key in (
        ("count", "count"), ("empty", "empty"), ("copy", "copy_name"), ("copied", "copied"), ("needs", "needs"),
        ("always", "always"), ("preset", "preset_only"), ("all-groups", "group_all")))

    body = []
    body.append(
        '<section id="names">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  %s\n  <p>%s</p>\n</section>\n'
        % (say("names_h2"), say("names_sub"), pre(CODE_NAMES), say("names_p")))
    body.append(
        '<section id="catalog">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n'
        '  <div class="icat" id="icon-catalog" %s>\n'
        '    <div class="icat-bar">\n'
        '      <label class="icat-search"><span>%s</span><input type="search" id="icat-q" placeholder="%s" autocomplete="off" spellcheck="false"></label>\n'
        '      <label class="icat-group"><span>%s</span><select id="icat-g"><option value="">%s</option></select></label>\n'
        '      <div class="icat-sets" role="group" aria-label="%s">\n%s\n      </div>\n'
        '    </div>\n'
        '    <p class="icat-count" aria-live="polite"></p>\n'
        '    <div class="icat-grid"></div>\n'
        '    <button type="button" class="btn icat-more" hidden>%s</button>\n'
        '    <div class="icat-detail" hidden></div>\n'
        '  </div>\n'
        '  <p class="note">%s</p>\n</section>\n'
        % (say("catalog_h2"), say("catalog_sub"), attrs, say("search_label"), html.escape(raw("search_ph"), quote=True),
           say("group_label"), say("group_all"), html.escape(raw("set_label"), quote=True), set_buttons, say("more"),
           say("catalog_note")))
    rows = [(raw("set_default"), number(code, n["core"]), "<code>GoIconSet</code>", say("on_default")),
            (raw("set_medieval"), say("medieval_names"), "—", "<code>GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)</code>"),
            (raw("set_game"), number(code, n["game"]), "<code>GoGameIcons</code>", "<code>GoUi.add_icons(GoGameIcons.icon_set())</code>"),
            (raw("set_library"), number(code, n["library"]), "<code>GoIconLibrary</code>", "<code>GoUi.add_icons(GoIconLibrary.icon_set())</code>")]
    th = [raw(k) for k in ("th_set", "th_names", "th_class", "th_on")]
    table = "\n".join('      <tr><td>%s</td><td data-label="%s">%s</td><td data-label="%s">%s</td><td data-label="%s">%s</td></tr>'
                      % (html.escape(a), html.escape(th[1], quote=True), b, html.escape(th[2], quote=True), c,
                         html.escape(th[3], quote=True), d) for a, b, c, d in rows)
    body.append(
        '<section id="sets">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  <table>\n'
        '    <thead><tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr></thead>\n    <tbody>\n%s\n    </tbody>\n  </table>\n'
        '  %s\n  <p>%s</p>\n  <div class="note">%s</div>\n</section>\n'
        % (say("sets_h2"), say("sets_sub"), *[html.escape(t) for t in th], table, pre(CODE_ON), say("sets_p"), say("sets_warn")))
    body.append(
        '<section id="resolution">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  <ol class="steps">\n'
        '    <li>%s</li>\n    <li>%s</li>\n    <li>%s</li>\n  </ol>\n  <p>%s</p>\n  %s\n</section>\n'
        % (say("res_h2"), say("res_sub"), say("res_1"), say("res_2"), say("res_3"), say("res_p"), pre(CODE_ORDER)))
    swap = [("GoUi.use_preset(…)", "swap_preset"), ("GoUi.config.icons = my_set", "swap_icons"),
            ("GoUi.add_icons(set)", "swap_extra")]
    tc = [raw("th_call"), raw("th_does")]
    body.append(
        '<section id="swap">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  <table>\n'
        '    <thead><tr><th>%s</th><th>%s</th></tr></thead>\n    <tbody>\n%s\n    </tbody>\n  </table>\n</section>\n'
        % (say("swap_h2"), say("swap_sub"), html.escape(tc[0]), html.escape(tc[1]),
           "\n".join('      <tr><td><code>%s</code></td><td data-label="%s">%s</td></tr>'
                     % (html.escape(call), html.escape(tc[1], quote=True), say(key)) for call, key in swap)))
    body.append(
        '<section id="custom">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  %s\n  <ul>\n'
        '    <li>%s</li>\n    <li>%s</li>\n    <li>%s</li>\n    <li>%s</li>\n  </ul>\n</section>\n'
        % (say("custom_h2"), say("custom_sub"), pre(CODE_CUSTOM), say("custom_1"), say("custom_2"), say("custom_3"),
           say("custom_4")))
    body.append(
        '<section id="naming">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  <ul>\n'
        '    <li>%s</li>\n    <li>%s</li>\n    <li>%s</li>\n    <li>%s</li>\n  </ul>\n'
        '  <h3><code>search()</code></h3>\n  %s\n'
        '  <h3><code>group_names()</code> · <code>names_in_group()</code></h3>\n  %s\n'
        '  <h3><code>canonical()</code> · <code>has_icon()</code></h3>\n  %s\n</section>\n'
        % (say("naming_h2"), say("naming_sub"), say("naming_1"), say("naming_2"), say("naming_3"), say("naming_4"),
           pre(CODE_SEARCH), pre(CODE_GROUPS), pre(CODE_CANONICAL)))
    tl = [raw("th_set"), raw("th_source"), raw("th_license")]
    lic = [(raw("set_default"), say("src_own")), (raw("set_medieval"), say("src_own")),
           (raw("set_game"), say("src_game")), (raw("set_library"), say("src_library"))]
    body.append(
        '<section id="license">\n  <h2>%s</h2>\n  <p class="sub">%s</p>\n  <table>\n'
        '    <thead><tr><th>%s</th><th>%s</th><th>%s</th></tr></thead>\n    <tbody>\n%s\n    </tbody>\n  </table>\n'
        '  <p>%s</p>\n</section>\n'
        % (say("license_h2"), say("license_sub"), *[html.escape(t) for t in tl],
           "\n".join('      <tr><td>%s</td><td data-label="%s">%s</td><td data-label="%s">MIT</td></tr>'
                     % (html.escape(a), html.escape(tl[1], quote=True), b, html.escape(tl[2], quote=True)) for a, b in lic),
           say("license_p")))

    hero = ('<div class="hero">\n  <div class="wrap">\n    <h1>%s</h1>\n'
            '    <p class="lead">\n      %s\n    </p>\n'
            '    <div class="cta">\n'
            '      <a class="btn primary" href="#catalog">%s</a>\n'
            '      <a class="btn" href="#resolution">%s</a>\n'
            '    </div>\n  </div>\n</div>\n\n'
            % (say("title"), say("lead"), say("cta_find"), say("cta_how")))
    return head + hero + '<main class="wrap">\n\n' + "\n".join(body) + '\n</main>' + tail


# ── Counts everywhere ─────────────────────────────────────────────────

COUNT = re.compile(r'(<span data-n="([a-z]+)">)([^<]*)(</span>)')


def write_counts(n):
    """Rewrite every `<span data-n>` on every page of every language. Returns how many spans were checked."""
    seen, unknown = 0, set()
    for lang in site_langs.ACTIVE:
        for page in site_langs.PAGES:
            path = os.path.join(WWW, site_langs.rel_path(lang.code, page))
            if not os.path.isfile(path):
                continue
            text = open(path, encoding="utf-8").read()

            def put(m):
                nonlocal seen
                seen += 1
                if m.group(2) not in n:
                    unknown.add(m.group(2))
                    return m.group(0)
                return m.group(1) + number(lang.code, n[m.group(2)]) + m.group(4)

            new = COUNT.sub(put, text)
            if new != text:
                open(path, "w", encoding="utf-8").write(new)
    if unknown:
        sys.exit("🛑 data-n keys nobody counts: %s" % " ".join(sorted(unknown)))
    return seen


def main():
    n = counts()
    keys = set(site_icons_text.TEXT["en"])
    for lang in site_langs.ACTIVE:
        missing = keys - set(site_icons_text.TEXT.get(lang.code, {}))
        if missing:
            sys.exit("🛑 site_icons_text.py: %s lacks %s" % (lang.code, " ".join(sorted(missing))))
    data = catalog()
    target = os.path.join(WWW, DATA)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if not os.path.isfile(target) or open(target, encoding="utf-8").read() != data:
        open(target, "w", encoding="utf-8").write(data)
    made = 0
    for lang in site_langs.ACTIVE:
        path = os.path.join(WWW, site_langs.rel_path(lang.code, PAGE))
        page = build(lang.code, n)
        if not os.path.isfile(path) or open(path, encoding="utf-8").read() != page:
            open(path, "w", encoding="utf-8").write(page)
        made += 1
    spans = write_counts(n)
    print("icons.html — %d pages · site/icons.js %d drawings (%.0f KB) · %d counts on the site"
          % (made, n["icons"], len(data.encode("utf-8")) / 1024, spans))
    return 0


if __name__ == "__main__":
    sys.exit(main())
