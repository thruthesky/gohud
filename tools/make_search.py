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
제목·산문·코드를 **따로** 담는다(`t`·`x`·`c`).
- 제목에 든 말은 점수를 높게 쳐야 `GoSheet` 를 찾을 때 그 위젯을 설명하는 절이 맨 위에 오고,
  스쳐 언급한 절이 아래로 간다.
- 소제목 조각은 제가 속한 절의 번호(`p`)를 들고 있다 — 결과 한 줄만 보고도 어디에 있는 이야기인지
  알 수 있어야 한다.
- 코드는 찾기는 해야 하지만 **보여 줄 때는 뒤로 미룬다.** 코드와 산문을 한 자루에 담았더니
  결과에 딸려 나오는 한 줄이 `var sheet := GoSheet.new() add_child(sheet)…` 처럼 읽기 어려웠다
  (2026-09-16 촬영). 사람이 먼저 읽어야 하는 것은 그 절이 무엇을 하는지 적은 문장이다.
"""
import html
import json
import os
import re
from html.parser import HTMLParser

import site_langs

# 언어 고르개가 시작하는 표식 — 그 뒤는 쪽 이름이 아니라 언어 이름이다.
LANGS_MARK = "<!-- langs:begin -->"

HERE = os.path.dirname(os.path.abspath(__file__))
# 🛑 `make_site.py` 와 같은 환경변수를 본다 — `check_site.py` 가 임시 폴더에 다시 만들어 보고
#    지금 파일과 견주기 때문이다. 이것이 없으면 검사가 원본을 덮어써 늘 통과한다.
WWW = os.environ.get("GOHUD_SITE_OUTPUT", os.path.join(os.path.dirname(HERE), "www"))
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
        self.buf = []            # 지금 조각의 산문
        self.code = []           # 지금 조각의 코드(`<pre>` 안)
        self.pre = 0             # 코드 칸 안인가
        self.cap = None          # 제목을 모으는 중이면 리스트
        self.sec = None          # 지금 절의 id
        self.sec_open = False    # 이 절의 h2 를 이미 만났는가

    # ── 조각 관리 ──────────────────────────────────────────
    def _flush(self):
        if self.cuts:
            self.cuts[-1]["x"] = squeeze("".join(self.buf))
            self.cuts[-1]["c"] = squeeze("".join(self.code))
        self.buf, self.code = [], []

    def _begin(self, anchor, sub):
        self._flush()
        # 소제목이면 제가 속한 절의 번호를 적어 둔다 — 결과에 "위젯 › 배치" 처럼 길을 보인다.
        parent = -1
        if sub:
            for i in range(len(self.cuts) - 1, -1, -1):
                if not self.cuts[i]["s"]:
                    parent = i
                    break
        self.cuts.append({"a": anchor, "t": "", "s": 1 if sub else 0, "x": "", "c": "", "p": parent})
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


# 🛑 쪽 이름을 박아 두지 않는다 — `site_langs.PAGES` 에서 만든다. 박아 두었을 때는 쪽을 늘려도
#    검사가 초록불인 채(`check_site.py` 는 옛 세 이름만 본다) 새 쪽의 딱지가 17 개 언어 모두
#    영어로 남았다(2026-09-16).
NAV = re.compile(r'<a (?:class="[^"]*" )?href="(\./|%s)"[^>]*>(.*?)</a>'
                 % "|".join(re.escape(p) for p in site_langs.PAGES if p != "index.html"), re.S)


def page_names(code):
    """쪽 이름을 그 언어의 말로 얻는다 — 머리띠 메뉴에 이미 번역돼 있다.

    🔑 메뉴가 `tools/site_nav.py` 의 생성물이 된 뒤로는 **어느 쪽을 읽어도** 다섯 쪽이 다 있다.
    🛑 `<nav>` 안만 읽는다 — 그 앞의 로고도 `href="./"` 라서, 머리 전체를 읽으면 첫 쪽 이름이
       그 언어의 "소개" 가 아니라 "gohud" 가 된다(2026-09-16 실측).
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
    """한 언어의 색인 파일을 쓴다. 쪽수·조각수·크기를 돌려준다."""
    docs, pages = [], 0
    for i, page in enumerate(site_langs.PAGES):
        path = os.path.join(WWW, site_langs.rel_path(code, page))
        if not os.path.isfile(path):
            continue
        pages += 1
        base = len(docs)
        for cut in cut_page(path):
            # 🛑 `p` 는 **그 페이지 안의** 번호였다 — 세 쪽을 한 자루에 담으므로 여기서 옮겨 적는다.
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
            print("🛑 %s — 쪽이 %d/%d 뿐이다" % (lang.code, pages, len(site_langs.PAGES)))
    print("검색 색인 — 언어 %d개 · 합 %.0fKB · 가장 큰 것 %s %.0fKB(한 번에 그 하나만 받는다)"
          % (len(site_langs.ACTIVE), total / 1024, biggest[0], biggest[1] / 1024))
    return total


if __name__ == "__main__":
    write_all()
