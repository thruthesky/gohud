# -*- coding: utf-8 -*-
"""`docs/` 홈페이지가 **깨지지 않았는지** 검사한다.

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
| 문서 언어 표시 | `<html lang>` 이 없으면 화면 낭독기가 엉뚱한 발음으로 읽는다 |
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
# 🛑 사이트는 `docs/` 루트가 영문, `docs/ko/` 가 한국어다(2026-09-13 GitHub Pages 배포 구조로 재배치).
WWW = os.path.join(ADDON, "docs")


def pages():
    """`docs/` 아래의 모든 HTML — 🛑 하위 폴더도 본다(한국어판이 `ko/` 에 있다)."""
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
                if target.startswith(("http://", "https://", "#", "mailto:", "data:")):
                    continue
                clean = target.split("#")[0].split("?")[0]
                if not clean or clean == "./":
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(here, clean))):
                    problems.append("%s: 없는 곳을 가리킨다 — %s" % (name, target))
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


def check_fresh(problems):
    """`make_site.py` 를 다시 돌린 결과와 지금 파일이 같은가 — 다르면 사전이 낡은 것이다."""
    path = os.path.join(WWW, "site", "glossary.js")
    before = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
    result = subprocess.run([sys.executable, os.path.join(HERE, "make_site.py")],
                            capture_output=True, text=True)
    if result.returncode != 0:
        problems.append("make_site.py 가 실패했다 — %s" % (result.stderr.strip().splitlines() or [""])[-1])
        return
    after = open(path, encoding="utf-8").read()
    if before != after:
        problems.append("용어 사전이 소스와 어긋나 있었다 — 방금 다시 만들었으니 커밋한다")


def main():
    problems = []
    if not os.path.isdir(WWW):
        print("🛑 docs/ 가 없다")
        return 1
    # 🛑 페이지가 한 장도 없으면 그것부터 실패다 — 사이트가 다른 폴더로 옮겨졌을 때 옛 폴더에서
    #    HTML 0장을 보고도 "문제 0" 을 냈다(2026-09-13). 빈 것을 통과로 세지 않는다.
    if not pages():
        problems.append("HTML 페이지가 한 장도 없다 — 사이트 폴더가 옮겨졌거나 비었다")
    check_links(problems)
    glossary = load_glossary(problems)
    check_glossary(glossary, problems)
    english = load_glossary(problems, "glossary.en.js")
    check_glossary(english, problems)
    check_fresh(problems)

    print("페이지 %d개 · 용어 %d(한국어) · %d(영문)" % (len(pages()), len(glossary), len(english)))
    for line in problems:
        print("   🛑 %s" % line)
    print("\n%s 문제 %d" % ("🛑" if problems else "✅", len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
