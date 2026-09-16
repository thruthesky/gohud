# -*- coding: utf-8 -*-
"""`ai.html` 17 장을 짓는다 — 손으로 쓰는 장은 하나도 없다.

    python3 tools/make_ai_page.py

## 어디서 재료를 가져오나
- **새로 쓰는 말**(절 제목·안내문·붙여 넣을 블록) — `tools/site_ai_text.py`
- **옛 번역문**(미리보기 명령 설명 · 명령 표 · "그냥 말로 부탁해도 된다") — 그 언어의 `install.html`
  안에 아직 남아 있는 것이 아니라, 갈라내기 전 `index.html` 의 `#ai` 절이었다. 그 조각은
  `www/<code>/ai.html` 이 이미 있으면 거기서, 없으면 **영어 뼈대에 그 언어 표를 얹어** 만든다.
- **머리·꼬리**(`<head>`·머리띠·바닥글·스크립트) — 같은 언어의 `index.html` 에서 그대로 가져온다.
  그래야 언어 고르개·hreflang·용어 사전 경로가 저절로 맞는다.

🛑 이 스크립트는 `ai.html` 을 **통째로 다시 쓴다.** 손으로 고친 것은 날아간다 — 고칠 곳은
`tools/site_ai_text.py` 다.
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

# 옛 `#ai` 절에서 그대로 옮겨 오는 조각 — 이 제목 id 사이의 글이다(언어가 달라도 id 는 같다).
KEEP_FROM = "gohud-preview-the-widget-gallery"   # 이 h3 부터
KEEP_TO = None                                   # 표 끝까지 (`</table>`)


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def head_and_tail(code):
    """그 언어 `index.html` 의 머리와 꼬리. 머리띠·고르개·스크립트가 딸려 온다."""
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
    """미리보기 명령 설명과 명령 표 — 그 언어의 번역문을 그대로 쓴다.

    🔑 재료는 **이미 있는 `ai.html`** 이다. 즉 이 스크립트는 제가 지은 쪽을 다시 읽어 다시 짓는다 —
    `site_ai_text.py` 의 말만 갈아 끼우고 번역된 표는 그대로 둔다. 맨 처음 한 번만, 대문을 가를 때
    떼어 둔 옛 `#ai` 절(`GOHUD_AI_SRC` 가 가리키는 폴더)에서 가져온다.
    """
    src = os.path.join(WWW, site_langs.rel_path(code, "ai.html"))
    if not os.path.isfile(src):
        seed = os.environ.get("GOHUD_AI_SRC")
        src = os.path.join(seed, "%s.html" % code) if seed else ""
    if not src or not os.path.isfile(src):
        return None, None
    text = open(src, encoding="utf-8").read()
    # ① 미리보기 두 소제목 + 명령 표 → `#commands`
    start = text.find('<h3 id="%s">' % KEEP_FROM)
    # 🛑 표의 끝은 **그 소제목 뒤에서** 찾는다. 다시 지을 때는 `#agents` 절의 표가 앞에 오므로,
    #    앞에서부터 찾으면 start > end 가 되어 조각이 통째로 빈다(2026-09-16 실측: h3 0개).
    end = text.find("</table>", start) if start >= 0 else -1
    commands = text[start:end + len("</table>")] if start >= 0 and end > start else ""
    # ② "그냥 말로 부탁해도 된다" 안내 → `#ask`
    # 🛑 `<div class="note">` 는 `#copy` 절에도 있다(다시 지을 때). **마지막** 것이 "그냥 말로" 안내다.
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
    # 🛑 `data-label` 을 준다 — 폰 폭(640px 이하)에서는 표가 세로로 쌓이고 머리줄이 숨는다
    #    (`style.css` 의 `thead{display:none}`). 라벨이 없으면 경로와 명령이 구분 없이 붙는다.
    rows = "\n".join(
        '      <tr><td>%s — %s</td><td data-label="%s"><code>%s</code></td>'
        '<td data-label="%s"><code>%s</code></td></tr>'
        % (who, say(what), th[1], where, th[2], how)
        for who, what, where, how in site_ai_text.AGENT_ROWS)

    body = []
    # ── #copy — 가장 먼저 온다. 설명보다 블록이 먼저다. ──────────────
    body.append(
        '<section id="copy">\n'
        '  <h2>%s</h2>\n'
        '  <p class="sub">%s</p>\n'
        '  <pre><code>%s</code></pre>\n'
        '  <div class="note">%s</div>\n'
        '</section>\n' % (say("copy_h2"), say("copy_sub"), esc(site_ai_text.COPY_BLOCK), say("copy_note")))

    # ── #agents — 손으로 넣을 때의 자리 ────────────────────────────
    body.append(
        '<section id="agents">\n'
        '  <h2>%s</h2>\n'
        '  <p class="sub">%s</p>\n'
        '  <table>\n'
        '    <thead><tr><th>%s</th><th>%s</th><th>%s</th></tr></thead>\n'
        '    <tbody>\n%s\n    </tbody>\n'
        '  </table>\n'
        '</section>\n' % (say("agents_h2"), say("agents_sub"), th[0], th[1], th[2], rows))

    # ── #commands — 옛 번역문 그대로 ───────────────────────────────
    body.append(
        '<section id="commands">\n'
        '  <h2>%s</h2>\n'
        '  %s\n'
        '  <p>%s</p>\n'
        '</section>\n' % (say("commands_h2"), commands.strip(), say("need")))

    # ── #ask — 옛 안내문 그대로 ────────────────────────────────────
    body.append(
        '<section id="ask">\n'
        '  <h2>%s</h2>\n'
        '  <div class="note">%s</div>\n'
        '</section>\n' % (say("ask_h2"), note))

    hero = ('<div class="hero">\n  <div class="wrap">\n    <h1>%s</h1>\n'
            '    <p class="lead">\n      %s\n    </p>\n'
            '    <div class="cta">\n'
            '      <a class="btn primary" href="#copy">%s</a>\n'
            '      <a class="btn" href="install.html">%s</a>\n'
            '    </div>\n  </div>\n</div>\n\n'
            % (t["ai_title"], t["ai_lead"], say("copy_cta"), site_nav.label(code, "install")))

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
    print("ai.html — %d장%s" % (made, " · 재료가 없어 건너뛴 언어: " + ", ".join(skipped) if skipped else ""))
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main())
