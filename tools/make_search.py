# -*- coding: utf-8 -*-
"""전역 검색 색인 — 언어마다 세 쪽을 한 덩이로 묶어 `www/site/search/<code>.js` 로 낸다.

## 왜 `.json` 이 아니라 `.js` 인가 (🛑 바꾸지 않는다)
`tools/site_shots.sh` 는 페이지를 **`file://`** 로 열어 촬영한다. 그 자리에서 `fetch()` 는 CORS 로
조용히 죽는다 — 브라우저에서는 되고 촬영 검증에서만 안 되는, 가장 잡기 어려운 종류의 고장이다.
그래서 색인은 `<script src>` 로 불러올 수 있는 모양(전역 변수 대입)으로 낸다. 이러면 `file://`
에서도, GitHub Pages 에서도, 오프라인 사본에서도 똑같이 열린다.

## 어떻게 자르나
`site/toc.js` 가 목차를 만드는 규칙과 **똑같이** 자른다 — 절(`section[id]`)과 그 안의 소제목
(`h3[id]`, 단 카드 안은 뺀다). 그래야 검색 결과를 눌렀을 때 가는 자리와 목차에서 보이는 자리가
같다. 제목의 id 는 `tools/make_site.py` 가 영어 기준으로 박아 두므로 언어를 바꿔도 주소가 같다.

## 무엇을 담나
제목과 본문을 따로 담는다(`t`·`x`). 제목에 든 말은 점수를 높게 쳐야 `GoSheet` 를 찾을 때 그 위젯을
설명하는 절이 맨 위에 오고, 그것을 스쳐 언급한 절이 아래로 간다. 코드 블록도 본문에 넣는다 —
`GoUi.use_preset()` 같은 이름은 문장이 아니라 코드에만 나오는 일이 많다.
"""
import html
import json
import os
import re
from html.parser import HTMLParser

import site_langs

HERE = os.path.dirname(os.path.abspath(__file__))
WWW = os.path.join(os.path.dirname(HERE), "www")
OUT = os.path.join(WWW, "site", "search")

# 글을 붙여 쓰면 안 되는 태그 — 이것들의 경계에는 공백을 넣는다. 반대로 `<b>`·`<code>` 같은 인라인
# 태그는 붙여야 한다(`Go<b>Surface</b>` 가 "Go Surface" 로 쪼개지면 이름으로 못 찾는다).
BLOCK = {"p", "div", "section", "li", "ul", "ol", "tr", "td", "th", "table", "thead", "tbody",
         "pre", "h1", "h2", "h3", "h4", "h5", "h6", "figure", "figcaption", "br", "hr", "blockquote"}
DROP = {"script", "style", "svg", "noscript"}


class Cutter(HTMLParser):
    """`<main>` 안을 훑어 절·소제목 단위로 자른다."""

    def __init__(self):
        HTMLParser.__init__(self)
        self.inside = False      # <main> 안인가
        self.drop = 0            # 통째로 버리는 태그 안인가
        self.stack = []          # [(태그, class)] — 카드 안 h3 을 가려내는 데 쓴다
        self.cuts = []           # 자른 조각들
        self.buf = []            # 지금 조각의 본문
        self.cap = None          # 제목을 모으는 중이면 리스트
        self.sec = None          # 지금 절의 id
        self.sec_open = False    # 이 절의 h2 를 이미 만났는가

    # ── 조각 관리 ──────────────────────────────────────────
    def _flush(self):
        if self.cuts:
            self.cuts[-1]["x"] = squeeze("".join(self.buf))
        self.buf = []

    def _begin(self, anchor, sub):
        self._flush()
        self.cuts.append({"a": anchor, "t": "", "s": 1 if sub else 0, "x": ""})
        self.cap = []

    # ── 파서 콜백 ──────────────────────────────────────────
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
        if tag in BLOCK:
            self.buf.append(" ")
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
        if tag in ("h2", "h3") and self.cap is not None:
            self.cuts[-1]["t"] = squeeze("".join(self.cap))
            self.cap = None
        elif tag in BLOCK:
            self.buf.append(" ")

    def handle_data(self, data):
        if not self.inside or self.drop:
            return
        if self.cap is not None:
            self.cap.append(data)
        elif self.cuts:
            self.buf.append(data)

    # ── 거들기 ─────────────────────────────────────────────
    def _in_card(self):
        return any("card" in cls.split() for _, cls in self.stack)


def squeeze(text):
    """줄바꿈·겹공백을 한 칸으로 줄인다. 색인 크기의 절반은 여기서 빠진다."""
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def cut_page(path):
    cutter = Cutter()
    cutter.feed(open(path, encoding="utf-8").read())
    cutter.close()
    return [c for c in cutter.cuts if c["t"]]


NAV = re.compile(r'<a href="(\./|theming\.html|widgets\.html)"[^>]*>(.*?)</a>', re.S)


def page_names(code):
    """세 쪽의 이름을 그 언어의 말로 얻는다 — 머리띠의 상호 링크에 이미 번역돼 있다.

    🛑 첫 쪽(`index.html`)에는 자기 자신으로 가는 링크가 없다. 그래서 **`theming.html`** 의
    머리띠를 읽는다 — 거기에는 세 쪽이 모두 링크로 있다(`./`·`theming.html`·`widgets.html`).
    """
    path = os.path.join(WWW, site_langs.rel_path(code, "theming.html"))
    names = {}
    if os.path.isfile(path):
        head = open(path, encoding="utf-8").read().split("</header>", 1)[0]
        for href, label in NAV.findall(head):
            text = squeeze(re.sub(r"<[^>]+>", "", label)).rstrip("↗").strip()
            if text:
                names.setdefault({"./": "index.html"}.get(href, href), text)
    return [names.get(page, page.replace(".html", "").title() or "Home")
            for page in site_langs.PAGES]


def build(code):
    """한 언어의 색인 파일을 쓴다. 쪽수·조각수·크기를 돌려준다."""
    docs, pages = [], 0
    for i, page in enumerate(site_langs.PAGES):
        path = os.path.join(WWW, site_langs.rel_path(code, page))
        if not os.path.isfile(path):
            continue
        pages += 1
        for cut in cut_page(path):
            docs.append([i, cut["a"], cut["t"], cut["s"], cut["x"]])
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
            print("🛑 %s — 쪽이 %d/%d 뿐이다" % (lang.code, pages, len(site_langs.PAGES)))
    print("검색 색인 — 언어 %d개 · 합 %.0fKB · 가장 큰 것 %s %.0fKB(한 번에 그 하나만 받는다)"
          % (len(site_langs.ACTIVE), total / 1024, biggest[0], biggest[1] / 1024))
    return total


if __name__ == "__main__":
    write_all()
