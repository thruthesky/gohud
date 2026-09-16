# -*- coding: utf-8 -*-
"""`www/` 홈페이지가 **깨지지 않았는지** 검사한다.

    python3 addons/gohud/tools/check_site.py

## 왜 필요한가
사이트는 코드가 아니라서 아무도 실행해 보지 않는다. 링크 하나가 깨지거나 용어 사전이 통째로
비어도 **검사는 초록색**이고, GitHub Pages 에 그대로 올라간다. 그 조용한 실패를 막는다.

## 보는 것
| 무엇 | 왜 |
|---|---|
| 로컬 링크·그림 경로 | 파일이 실제로 있는가 — 배포 후에야 404 를 보면 늦다 |
| 용어 사전 | 유효한 JS 인가, 모든 항목에 설명(`d`)과 갈래(`k`)가 있는가 |
| 페이지마다 사전·툴팁 로드 | 한 페이지만 빠뜨리면 그 페이지에서만 조용히 popup 이 죽는다 |
| 사전이 코드와 맞는가 | `make_site.py` 를 다시 돌린 결과와 다르면 **사전이 낡았다** |
| 다이얼 표 | `theming.html` 두 장에 표식이 있고, 다시 만든 표와 같고, 영문 뜻이 빠진 다이얼이 없는가 |
| 문서 언어 표시 | `<html lang>` 이 없으면 화면 낭독기가 엉뚱한 발음으로 읽는다 |
| 배포 입구 | 워크플로가 `tools/build_site.sh` 로 조립한 배포본을 올리는가, `404.html` 이 옛 `docs/www/` 주소를 넘기는가 |
| 공개 주소 | README·스킬·스토어 설명에 적힌 `https://thruthesky.github.io/gohud/…` 과 옛 그림 주소가 배포본에 실제로 있는가 — 그림은 404.html 이 넘겨주지 못한다 |
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

# 🔑 언어 목록은 `tools/site_langs.py` 한 곳 — 검사도 생성기와 **같은 목록**을 본다.
import site_langs

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
# 🛑 사이트는 `www/` 루트가 영문, `www/ko/` 가 한국어다. GitHub Actions(`.github/workflows/pages.yml`)가
#    `tools/build_site.sh` 로 조립해 https://thruthesky.github.io/gohud/ 의 최상위로 올린다(2026-09-15 docs 아래에서 옮김).
WWW = os.path.join(ADDON, "www")
# 🔑 GitHub Pages 가 없는 주소마다 내주는 페이지 — 사전·툴팁 없이 옛 주소를 넘기는 스크립트만 있다.
NOT_FOUND = "404.html"
PUBLIC = "https://thruthesky.github.io/gohud/"
# 🔑 2026-09-15 전의 README(배포된 ZIP 1.0.2·1.0.3 포함)가 절대 주소로 박아 둔 그림 — git 이력 전체에서 뽑았다.
#    이미 설치된 README 는 고칠 수 없고 404.html 은 <img> 요청을 넘기지 못하므로, 배포본의 이 자리에 파일이 있어야 한다.
LEGACY_IMAGES = [
    "docs/www/img/medieval-dark.png",
    "docs/www/img/preset-default-dark.png",
    "docs/www/img/preset-scifi-dark.png",
]
# 🔑 옛 문서 주소 — `tools/build_site.sh` 가 배포본에 **넘겨 주는 페이지를 실물로** 둔다.
#    404.html 의 스크립트도 넘기지만 그 응답은 상태 코드가 404 라, 검색엔진·링크 검사기·채팅 미리보기에는
#    끝까지 깨진 주소로 남는다. 여기 적힌 자리는 200 이어야 한다.
LEGACY_PAGES = ["%s/%s" % (old, page)
                for page in ("index.html", "theming.html", "widgets.html",
                             "ko/index.html", "ko/theming.html", "ko/widgets.html")
                for old in ("docs/www", "docs")]
# 공개 주소를 찾아볼 파일 종류와 건너뛸 폴더 — 빌드 산출물은 고칠 수 없고, `.env` 에는 키가 든다.
URL_SOURCES = (".md", ".html", ".json", ".yml", ".cfg")
SKIP_DIRS = {".git", ".godot", ".env", "builds", ".dist", "__pycache__", ".playwright-mcp", ".cowork"}


def pages():
    """`www/` 아래의 모든 HTML — 🛑 하위 폴더도 본다(한국어판이 `ko/` 에 있다)."""
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
            problems.append("%s: <html> 에 lang 이 없다" % name)
        for attribute in ("href", "src"):
            for target in re.findall(r'%s="([^"]+)"' % attribute, text):
                url = urlsplit(target)
                if url.scheme or url.netloc:
                    continue
                clean = unquote(url.path)
                linked = (Path(here, clean) if clean else Path(path)).resolve()
                if not linked.is_relative_to(Path(WWW).resolve()):
                    problems.append("%s: 배포 폴더 밖을 가리킨다 — %s" % (name, target))
                    continue
                if linked.is_dir():
                    linked = linked / "index.html"
                if not linked.is_file():
                    problems.append("%s: 없는 곳을 가리킨다 — %s" % (name, target))
                elif url.fragment and linked.suffix == ".html":
                    ids = re.findall(r'\bid=["\']([^"\']+)["\']', linked.read_text(encoding="utf-8"))
                    if unquote(url.fragment) not in ids:
                        problems.append("%s: 없는 절을 가리킨다 — %s" % (name, target))
        if name == NOT_FOUND:
            continue
        if "glossary" not in text:
            problems.append("%s: 용어 사전을 불러오지 않는다 — 이 페이지만 popup 이 죽는다" % name)
        if "tooltip.js" not in text:
            problems.append("%s: tooltip.js 를 불러오지 않는다" % name)


def load_glossary(problems, name="glossary.js"):
    path = os.path.join(WWW, "site", name)
    if not os.path.isfile(path):
        problems.append("%s 가 없다 — python3 tools/make_site.py 를 돌린다" % name)
        return {}
    text = open(path, encoding="utf-8").read()
    match = re.search(r"window\.GLOSSARY\s*=\s*(\{.*\})\s*;", text, re.S)
    if not match:
        problems.append("용어 사전의 모양이 낯설다 — window.GLOSSARY 대입을 찾지 못했다")
        return {}
    try:
        return json.loads(match.group(1))
    except ValueError as error:
        problems.append("용어 사전이 올바른 JSON 이 아니다 — %s" % error)
        return {}


def check_glossary(glossary, problems):
    if not glossary:
        return
    for term, entry in sorted(glossary.items()):
        if not isinstance(entry, dict):
            problems.append("용어 %r 의 값이 사전이 아니다" % term)
            continue
        if not entry.get("d"):
            problems.append("용어 %r 에 설명(d)이 없다 — 빈 풍선이 뜬다" % term)
        if not entry.get("k"):
            problems.append("용어 %r 에 갈래(k)가 없다" % term)
        if len(term) < 2:
            problems.append("용어 %r 이 너무 짧다 — 본문 아무 데나 걸린다" % term)
        # 🛑 풍선은 설명을 글자 그대로 넣는다 — 마크다운이 남으면 `**둥근**` 이 그대로 보인다.
        text = entry.get("d", "")
        if "**" in text or "`" in text:
            problems.append("용어 %r 의 설명에 마크다운이 남았다 — 풍선에 기호가 그대로 보인다" % term)


# 🔑 생성기가 쓰는 파일 전부 — 사전 두 장과 다이얼 표가 든 페이지 두 장. 하나라도 빠뜨리면 그 파일은
#    낡아도 초록색이다.
GENERATED = [
    os.path.join("site", "glossary.js"),
    os.path.join("site", "glossary.en.js"),
    NOT_FOUND,
] + [site_langs.rel_path(lang.code, page) for lang in site_langs.ACTIVE for page in site_langs.PAGES] \
  + [os.path.join("site", "search", "%s.js" % (lang.code or "en")) for lang in site_langs.ACTIVE]


def check_fresh(problems):
    """`make_site.py` 를 다시 돌린 결과와 지금 파일이 같은가 — 다르면 생성물이 낡은 것이다."""
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
        problems.append("make_site.py 가 실패했다 — %s" % (result.stderr.strip().splitlines() or [""])[-1])
        return
    for rel in GENERATED:
        if before[rel] != after[rel]:
            problems.append("%s 가 소스와 다르다 — python3 tools/make_site.py 를 실행한다" % rel)


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
        problems.append("site/style.css: CSS 중괄호가 맞지 않는다 — 미디어쿼리 범위를 확인한다")
    # 🛑 다크 촬영(`SITE_DARK=1 tools/site_shots.sh`)은 이 블록을 정규식으로 뽑아 쓴다. 뽑히지 않거나
    #    빈 껍데기가 나오면 다크 그림이 **밝은 판으로 찍히고**, 아무도 그것을 알아채지 못한다.
    sheet = re.sub(r"/\*.*?\*/", "", Path(WWW, "site/style.css").read_text(encoding="utf-8"), flags=re.S)
    dark = re.search(r"@media \(prefers-color-scheme: dark\) \{\s*(:root \{.*?\})", sheet, re.S)
    if not dark or "--bg:" not in dark.group(1):
        problems.append("site/style.css: 어두운 판 :root 블록을 뽑을 수 없다 — 다크 촬영이 밝은 판을 찍는다")


def build_site(problems, temp):
    """`tools/build_site.sh` 로 배포본을 조립한다 — CI 와 같은 스크립트라 여기서 본 것이 곧 올라가는 것이다."""
    out = os.path.join(temp, "site")
    result = subprocess.run(["bash", os.path.join(HERE, "build_site.sh"), out], capture_output=True, text=True)
    if result.returncode != 0:
        problems.append("tools/build_site.sh 가 실패했다 — %s" % (result.stderr.strip().splitlines() or [""])[-1])
        return None
    return out


def check_entry(problems, site):
    """배포 입구 — 배포본의 최상위가 `www/` 이고, 옛 주소가 살아 있는가."""
    workflow = Path(ADDON, ".github", "workflows", "pages.yml")
    text = workflow.read_text(encoding="utf-8") if workflow.is_file() else ""
    if "tools/build_site.sh _site" not in text or not re.search(r"^\s*path:\s*_site/?\s*$", text, re.M):
        problems.append(".github/workflows/pages.yml 이 tools/build_site.sh 로 조립한 _site/ 를 올리지 않는다")
    moved = Path(WWW, NOT_FOUND)
    if not moved.is_file() or "/docs" not in moved.read_text(encoding="utf-8"):
        problems.append("www/404.html 이 옛 주소(…/gohud/docs/www/…)를 새 주소로 넘기지 않는다")
    if site:
        for rel in ["index.html", NOT_FOUND]:
            if not os.path.isfile(os.path.join(site, rel)):
                problems.append("배포본 최상위에 %s 가 없다 — www/ 가 사이트 최상위가 아니다" % rel)
        for rel in LEGACY_IMAGES:
            if not os.path.isfile(os.path.join(site, rel)):
                problems.append("배포본에 옛 그림 %s 가 없다 — 배포된 ZIP 의 README 그림이 깨진다" % rel)
        for rel in LEGACY_PAGES:
            path = os.path.join(site, rel)
            if not os.path.isfile(path):
                problems.append("배포본에 옛 주소 %s 가 없다 — 404 로 남아 넘겨 주지 못한다" % rel)
                continue
            moved = re.search(r'http-equiv="refresh" content="0; url=([^"]+)"', open(path, encoding="utf-8").read())
            if not moved:
                problems.append("%s 가 새 주소로 넘기지 않는다" % rel)
            elif not os.path.isfile(os.path.normpath(os.path.join(os.path.dirname(path), moved.group(1)))):
                problems.append("%s 가 없는 곳으로 넘긴다 — %s" % (rel, moved.group(1)))
    for stale in ("index.html", ".nojekyll"):
        if Path(ADDON, stale).exists():
            problems.append("루트 %s 가 남았다 — 옛 main /(root) 배포용이다. 이제 Pages 는 www/ 만 올린다" % stale)
    if not re.search(r'<html\s+lang="en"', Path(WWW, "index.html").read_text(encoding="utf-8")):
        problems.append("기본 사이트 언어는 영어여야 한다")
    if Path(ADDON, ".git").exists():
        tracked = subprocess.run(["git", "ls-files", "-s", "--", "examples/demo/addons/gohud"],
                                 cwd=ADDON, capture_output=True, text=True, check=True).stdout
        if tracked.startswith("120000"):
            problems.append("데모의 순환 심볼릭 링크가 Git 에 들어 있다 — 저장소를 따라 읽는 도구가 자기 안으로 끝없이 들어간다")


def check_public_urls(problems, site):
    """README·스킬·스토어 설명에 적힌 공개 주소가 배포본에 실제로 있는가. 본 주소 수를 돌려준다."""
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
                    problems.append("%s: 배포본에 없는 공개 주소 — %s" % (where, url.geturl()))
                elif url.fragment and target.suffix == ".html":
                    ids = re.findall(r'\bid=["\']([^"\']+)["\']', target.read_text(encoding="utf-8"))
                    if unquote(url.fragment) not in ids:
                        problems.append("%s: 없는 절을 가리키는 공개 주소 — %s" % (where, url.geturl()))
    return count


def check_dials(problems):
    """다이얼 표 — 표식이 있는가, 영문 뜻이 빠진 다이얼은 없는가."""
    for rel in ("theming.html", os.path.join("ko", "theming.html")):
        path = os.path.join(WWW, rel)
        text = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
        if "<!-- dials:begin -->" not in text or "<!-- dials:end -->" not in text:
            problems.append("%s 에 다이얼 표식(<!-- dials:begin/end -->)이 없다" % rel)
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import make_site
    missing = make_site.missing_english_dials()
    if missing:
        problems.append("영문 뜻이 없는 다이얼 — make_site.DIALS_EN 에 적는다: " + ", ".join(missing))


def check_langs(problems):
    """언어판이 다 있는가, 문서 언어 표시가 목록과 맞는가, 생성기가 채울 표식이 살아 있는가.

    🛑 `site_langs.ACTIVE` 에 오른 언어는 **고르개가 실제로 데려가는 언어**다. 그 페이지가 없으면
    고르개의 그 줄은 404 로 데려가고, hreflang 은 없는 글을 검색엔진에 알린다.
    """
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import make_site
    for lang in site_langs.ACTIVE:
        for page in site_langs.PAGES:
            rel = site_langs.rel_path(lang.code, page)
            path = os.path.join(WWW, rel)
            if not os.path.isfile(path):
                problems.append("%s 가 없다 — 언어 고르개가 404 로 데려간다" % rel)
                continue
            text = open(path, encoding="utf-8").read()
            if not re.search(r'<html[^>]*\blang="%s"' % re.escape(lang.html_lang), text):
                problems.append('%s: <html lang="%s"> 가 아니다 — 화면 낭독기가 엉뚱한 발음으로 읽는다'
                                % (rel, lang.html_lang))
            if lang.direction == "rtl" and not re.search(r'<html[^>]*\bdir="rtl"', text):
                problems.append('%s: 오른쪽에서 왼쪽으로 읽는 언어인데 dir="rtl" 이 없다' % rel)
            for begin in (make_site.LANGS_BEGIN, make_site.HREFLANG_BEGIN):
                if begin not in text:
                    problems.append("%s 에 %s 표식이 없다 — 생성기가 채우지 못한다" % (rel, begin))
            for src in make_site.PAGE_SCRIPTS:
                if src not in text:
                    problems.append("%s 가 %s 를 부르지 않는다 — 그 장만 기능이 빠진다" % (rel, src))
            # 🔑 목차는 제목의 id 로 데려간다 — id 가 없으면 사이드바도 검색도 절 머리에만 닿는다.
            if not re.search(r'<h3 id="', text):
                problems.append("%s 의 소제목에 id 가 없다 — `python3 tools/make_site.py` 를 돌린다" % rel)
            # 🛑 언어판끼리 **절 구성이 갈라지는 것**은 링크 검사로 잡히지 않는다 — 페이지 안에서는 앞뒤가
            #    맞으니 끝까지 초록불이다. 한국어판에만 `#tokens` 가 있고 `#readable` 이 없던 것을 이렇게
            #    놓쳤다(2026-09-16). 영어를 정본으로 삼아 절의 목록과 순서를 그대로 맞춘다.
            if lang.code != "en":
                want = re.findall(r'<section id="([^"]+)"', open(os.path.join(WWW, page), encoding="utf-8").read())
                got = re.findall(r'<section id="([^"]+)"', text)
                if got != want:
                    missing, extra = [s for s in want if s not in got], [s for s in got if s not in want]
                    problems.append("%s: 절 구성이 영어판과 다르다 — 빠진 절 %s · 더 있는 절 %s%s"
                                    % (rel, missing or "없음", extra or "없음",
                                       "" if missing or extra else " (순서가 다르다)"))
    # 옮겨는 놓고 아직 올리지 않은 언어 — 잊고 넘어가지 않게 알려만 준다(문제로 세지는 않는다).
    waiting = [lang.code for lang in site_langs.LANGS if not lang.ready
               and os.path.isfile(os.path.join(WWW, site_langs.rel_path(lang.code, "index.html")))]
    if waiting:
        print("   ℹ 번역해 두고 아직 올리지 않은 언어: %s — site_langs.py 의 ready 를 True 로 바꾸면 고르개에 오른다"
              % ", ".join(waiting))


def check_search(problems):
    """전역 검색 색인 — 언어마다 있는가, 가리키는 자리가 실제로 있는가, 영어판만큼 담았는가.

    🔑 색인이 낡으면 **검색만** 조용히 어긋난다. 페이지는 멀쩡해 보이고 링크 검사도 통과하는데,
       누른 결과가 페이지 머리로 떨어지거나 아무 데도 가지 않는다. 그래서 색인의 앵커를 실제
       페이지와 대조한다.
    🛑 영어판보다 조각이 적은 언어는 **번역이 뒤처졌다는 뜻**이다 — 영어 원문에 절이 늘었는데
       그 언어만 옛 글 그대로인 것을 여기서 잡는다(절 구성 검사는 `<section>` 만 보므로 못 잡는다).
    """
    counts = {}
    for lang in site_langs.ACTIVE:
        code = lang.code or "en"
        path = os.path.join(WWW, "site", "search", "%s.js" % code)
        if not os.path.isfile(path):
            problems.append("site/search/%s.js 가 없다 — 그 언어에서 검색이 빈 채로 열린다" % code)
            continue
        text = open(path, encoding="utf-8").read()
        match = re.search(r"window\.GOHUD_SEARCH\[[^\]]+\]=(\{.*\});", text, re.S)
        if not match:
            problems.append("site/search/%s.js 가 전역 대입 모양이 아니다 — <script> 로 못 읽는다" % code)
            continue
        try:
            body = json.loads(match.group(1))
        except ValueError as err:
            problems.append("site/search/%s.js 를 읽을 수 없다 — %s" % (code, err))
            continue
        counts[code] = len(body["d"])
        # 페이지 이름이 번역되지 않고 파일 이름 그대로 남았는가.
        for i, name in enumerate(body["n"]):
            if name.lower().replace(" ", "") in ("index.html", "theming.html", "widgets.html"):
                problems.append("site/search/%s.js: %d번째 쪽 이름이 번역되지 않았다(%s)" % (code, i + 1, name))
        # 색인이 가리키는 자리가 그 페이지에 실제로 있는가 — 한 언어당 세 쪽을 한 번씩만 읽는다.
        for i, page in enumerate(body["p"]):
            rel = site_langs.rel_path(lang.code, page)
            full = os.path.join(WWW, rel)
            if not os.path.isfile(full):
                continue
            html = open(full, encoding="utf-8").read()
            here = set(re.findall(r'<(?:section|h3|h4) id="([^"]+)"', html))
            missing = sorted({d[1] for d in body["d"] if d[0] == i} - here)
            if missing:
                problems.append("site/search/%s.js 가 %s 에 없는 자리를 가리킨다 — %s"
                                % (code, rel, ", ".join(missing[:4])))
    if "en" in counts:
        thin = ["%s(%d)" % (c, n) for c, n in sorted(counts.items()) if n < counts["en"]]
        if thin:
            problems.append("검색 색인이 영어판(%d조각)보다 얇다 — %s · 그 언어만 옛 글이다"
                            % (counts["en"], ", ".join(thin)))


def main():
    problems = []
    if not os.path.isdir(WWW):
        print("🛑 www/ 가 없다")
        return 1
    # 🛑 페이지가 한 장도 없으면 그것부터 실패다 — 사이트가 다른 폴더로 옮겨졌을 때 옛 폴더에서
    #    HTML 0장을 보고도 "문제 0" 을 냈다(2026-09-13). 빈 것을 통과로 세지 않는다.
    if not pages():
        problems.append("HTML 페이지가 한 장도 없다 — 사이트 폴더가 옮겨졌거나 비었다")
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

    print("언어 %d개 · 페이지 %d장 · 공개 주소 %d곳 · 용어 %d(한국어) · %d(영문)"
          % (len(site_langs.ACTIVE), len(pages()), urls, len(glossary), len(english)))
    for line in problems:
        print("   🛑 %s" % line)
    print("\n%s 문제 %d" % ("🛑" if problems else "✅", len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
