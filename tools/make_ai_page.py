# -*- coding: utf-8 -*-
"""Build all 17 `ai.html` pages — not one of them is written by hand.

    python3 tools/make_ai_page.py

## Where the material comes from
- **Newly written wording** (section titles, notes, the block to paste) — `tools/site_ai_text.py`
- **Older translations** (the preview command text, the command table, "you can just ask in plain
  words") — not what is still left in that language's `install.html`, but the `#ai` section of
  `index.html` from before the split. That piece comes from `www/<code>/ai.html` if it already
  exists, otherwise from **the English skeleton with that language's table laid on top**.
- **Head and tail** (`<head>`, header bar, footer, scripts) — taken as-is from the `index.html` of
  the same language. That way the language picker, hreflang and glossary paths line up by themselves.

🛑 This script rewrites `ai.html` **completely.** Hand edits are lost — the place to edit is
`tools/site_ai_text.py`.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
WWW = os.environ.get("GOHUD_SITE_OUTPUT", os.path.join(ADDON, "www"))

sys.path.insert(0, HERE)
import site_ai_text  # noqa: E402
import site_langs  # noqa: E402
import site_nav  # noqa: E402

# The piece carried over verbatim from the old `#ai` section — the text between these heading ids
# (the ids are the same in every language).
KEEP_FROM = "gohud-preview-the-widget-gallery"   # from this h3
KEEP_TO = None                                   # to the end of the table (`</table>`)


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def head_and_tail(code):
    """The head and tail of that language's `index.html`. The header bar, picker and scripts come along."""
    path = os.path.join(WWW, site_langs.rel_path(code, "index.html"))
    text = open(path, encoding="utf-8").read()
    head = text.split('<div class="hero">', 1)[0]
    tail = text.split("</main>", 1)[1]
    t = site_nav.TITLE.get(code, site_nav.TITLE["en"])
    head = re.sub(r"<title>.*?</title>", "<title>%s — gohud</title>" % t["ai_title"], head, flags=re.S)
    head = re.sub(r'<meta name="description" content="[^"]*">',
                  '<meta name="description" content="%s">' % t["ai_desc"], head)
    return head, tail


def kept_html(code):
    """The preview command text and the command table — that language's translation, used as-is.

    🔑 The material is **the `ai.html` that already exists**. That is, this script reads back the page
    it built and rebuilds it — swapping in the wording from `site_ai_text.py` and leaving the
    translated table alone. Only the very first time does it take the old `#ai` section set aside
    when the front page was split (the folder `GOHUD_AI_SRC` points at).
    """
    src = os.path.join(WWW, site_langs.rel_path(code, "ai.html"))
    if not os.path.isfile(src):
        seed = os.environ.get("GOHUD_AI_SRC")
        src = os.path.join(seed, "%s.html" % code) if seed else ""
    if not src or not os.path.isfile(src):
        return None, None
    text = open(src, encoding="utf-8").read()
    # ① the two preview subheadings + the command table → `#commands`
    start = text.find('<h3 id="%s">' % KEEP_FROM)
    # 🛑 Look for the end of the table **after that subheading**. On a rebuild the `#agents` table comes
    #    first, so searching from the start gives start > end and the piece comes out empty (measured 2026-09-16: 0 h3).
    end = text.find("</table>", start) if start >= 0 else -1
    commands = text[start:end + len("</table>")] if start >= 0 and end > start else ""
    # ② the "you can just ask in plain words" note → `#ask`
    # 🛑 `<div class="note">` also appears in the `#copy` section (on a rebuild). The **last** one is that note.
    note = ""
    found = re.findall(r'<div class="note">(.*?)</div>', text, re.S)
    if found:
        note = found[-1].strip()
    return commands, note


def build(code):
    t = site_nav.TITLE.get(code, site_nav.TITLE["en"])
    say = lambda k: site_ai_text.text(code, k)  # noqa: E731
    head, tail = head_and_tail(code)
    commands, note = kept_html(code)
    if commands is None:
        return None

    th = say("agents_th")
    # 🛑 Give a `data-label` — at phone width (640px and under) the table stacks vertically and the
    #    header row is hidden (`thead{display:none}` in `style.css`). Without labels the path and the command run together.
    rows = "\n".join(
        '      <tr><td>%s — %s</td><td data-label="%s"><code>%s</code></td>'
        '<td data-label="%s"><code>%s</code></td></tr>'
        % (who, say(what), th[1], where, th[2], how)
        for who, what, where, how in site_ai_text.AGENT_ROWS)

    body = []
    # ── #copy — comes first. The block before the explanation. ─────
    # 🔑 `id="install-prompt"` is what the hero button copies (`data-copy` in `site/ux.js`).
    steps = "\n".join("    <li>%s</li>" % say(k) for k in ("step1", "step2", "step3"))
    body.append(
        '<section id="copy">\n'
        '  <h2>%s</h2>\n'
        '  <p class="sub">%s</p>\n'
        '  <ol class="steps">\n%s\n  </ol>\n'
        '  <pre id="install-prompt"><code>%s</code></pre>\n'
        '  <div class="note">%s</div>\n'
        '</section>\n' % (say("copy_h2"), say("copy_sub"), steps, esc(site_ai_text.COPY_BLOCK), say("copy_note")))

    # ── #claude-code — the same install without an agent, two commands ──
    # 🛑 No `<div class="note">` and no `<table>` here: `kept_html()` takes the **last** note and the
    #    first table after the `#commands` heading, and this section sits before both.
    body.append(
        '<section id="claude-code">\n'
        '  <h2>%s</h2>\n'
        '  <p class="sub">%s</p>\n'
        '  <pre><code>%s</code></pre>\n'
        '  <p>%s</p>\n'
        '  <pre><code>%s</code></pre>\n'
        '  <p>%s <a href="install.html">%s →</a></p>\n'
        '</section>\n' % (say("cc_h2"), say("cc_sub"), esc(site_ai_text.CLAUDE_TERMINAL), say("cc_inside"),
                          esc(site_ai_text.CLAUDE_INSIDE), say("cc_check"), site_nav.label(code, "install")))

    # ── #agents — where to put it by hand ──────────────────────────
    body.append(
        '<section id="agents">\n'
        '  <h2>%s</h2>\n'
        '  <p class="sub">%s</p>\n'
        '  <table>\n'
        '    <thead><tr><th>%s</th><th>%s</th><th>%s</th></tr></thead>\n'
        '    <tbody>\n%s\n    </tbody>\n'
        '  </table>\n'
        '</section>\n' % (say("agents_h2"), say("agents_sub"), th[0], th[1], th[2], rows))

    # ── #commands — the old translation, verbatim ──────────────────
    body.append(
        '<section id="commands">\n'
        '  <h2>%s</h2>\n'
        '  %s\n'
        '  <p>%s</p>\n'
        '</section>\n' % (say("commands_h2"), commands.strip(), say("need")))

    # ── #ask — the old note, verbatim ──────────────────────────────
    body.append(
        '<section id="ask">\n'
        '  <h2>%s</h2>\n'
        '  <div class="note">%s</div>\n'
        '</section>\n' % (say("ask_h2"), note))

    hero = ('<div class="hero">\n  <div class="wrap">\n    <h1>%s</h1>\n'
            '    <p class="lead">\n      %s\n    </p>\n'
            '    <div class="cta">\n'
            '      <a class="btn primary" href="#copy" data-copy="install-prompt" data-copied="%s">%s</a>\n'
            '      <a class="btn" href="install.html">%s</a>\n'
            '    </div>\n  </div>\n</div>\n\n'
            % (t["ai_title"], t["ai_lead"], say("copied_cta").replace('"', "&quot;"), say("copy_cta"),
               site_nav.label(code, "install")))

    return head + hero + '<main class="wrap">\n\n' + "\n".join(body) + '\n</main>' + tail


def main():
    made, skipped = 0, []
    for lang in site_langs.ACTIVE:
        page = build(lang.code)
        if page is None:
            skipped.append(lang.code)
            continue
        path = os.path.join(WWW, site_langs.rel_path(lang.code, "ai.html"))
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        open(path, "w", encoding="utf-8").write(page)
        made += 1
    print("ai.html — %d pages%s" % (made, " · skipped for lack of material: " + ", ".join(skipped) if skipped else ""))
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main())
