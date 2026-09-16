# -*- coding: utf-8 -*-
"""사이트가 내는 언어 — **여기 한 곳**에서 고른다.

`tools/make_site.py` 가 이 목록으로 페이지마다 언어 고르개와 hreflang 을 다시 써넣고,
`tools/check_site.py` 가 같은 목록으로 빠진 페이지·어긋난 링크를 잡는다. 언어를 더하거나 뺄 때
고치는 파일은 이것 하나다 — 51 장을 손으로 고치면 반드시 한두 장이 어긋난다.

## 왜 이 언어들인가 (2026-09-16 사람 결정)
영어가 기본이고 한국어·일본어·중국어는 필수다. 나머지는 **Godot 사용자가 많으면서 영어를
모국어·제2공용어로 쓰지 않는 나라**의 언어를 골랐다 — 브라질·중남미·러시아·프랑스·튀르키예·
폴란드·이탈리아·베트남·인도네시아·우크라이나·태국·아랍권·대만.
🛑 네덜란드어·힌디어·독일어·히브리어는 gohud 문자열에는 있지만 그 나라의 영어 사용률이 높아 넣지 않는다.

## 각 항목
`code`      배포본 폴더 이름이자 이 사이트 안에서 부르는 이름. 🛑 영어는 빈 문자열 — 최상위가 곧 영어판이다.
`html_lang` `<html lang>` 에 적는 값. 화면 낭독기가 발음을 고르는 근거다.
`hreflang`  검색엔진에 주는 값. 중국어는 지역이 아니라 **문자**로 갈린다(`zh-Hans`·`zh-Hant`).
`name`      고르개에 보일 이름 — 그 언어를 쓰는 사람이 읽는 **제 나라 말**로 적는다.
`direction` 글이 흐르는 방향. 아랍어만 `rtl` 이다.
`ready`     번역이 **끝나** 배포에 올리는 언어인가. 🛑 고르개와 hreflang 에는 `ready` 인 언어만 올린다 —
            아직 없는 언어판을 광고하면 고르개가 404 로 데려가고 검색엔진도 없는 글을 찾아다닌다.
            한 언어를 다 옮겼으면 그 줄의 `True` 로 바꾸고 `python3 tools/make_site.py` 를 돌린다.
"""
from collections import namedtuple

Lang = namedtuple("Lang", "code folder html_lang hreflang name direction ready")

LANGS = [
    Lang("en",    "",      "en",      "en",      "English",          "ltr", True),
    Lang("ko",    "ko",    "ko",      "ko",      "한국어",              "ltr", True),
    Lang("ja",    "ja",    "ja",      "ja",      "日本語",              "ltr", True),
    Lang("zh",    "zh",    "zh-Hans", "zh-Hans", "简体中文",            "ltr", False),
    Lang("zh-tw", "zh-tw", "zh-Hant", "zh-Hant", "繁體中文",            "ltr", False),
    Lang("es",    "es",    "es",      "es",      "Español",          "ltr", False),
    Lang("pt",    "pt",    "pt",      "pt",      "Português",        "ltr", False),
    Lang("ru",    "ru",    "ru",      "ru",      "Русский",          "ltr", False),
    Lang("fr",    "fr",    "fr",      "fr",      "Français",         "ltr", False),
    Lang("tr",    "tr",    "tr",      "tr",      "Türkçe",           "ltr", False),
    Lang("pl",    "pl",    "pl",      "pl",      "Polski",           "ltr", False),
    Lang("it",    "it",    "it",      "it",      "Italiano",         "ltr", False),
    Lang("vi",    "vi",    "vi",      "vi",      "Tiếng Việt",       "ltr", False),
    Lang("id",    "id",    "id",      "id",      "Bahasa Indonesia", "ltr", False),
    Lang("uk",    "uk",    "uk",      "uk",      "Українська",       "ltr", False),
    Lang("th",    "th",    "th",      "th",      "ไทย",               "ltr", False),
    Lang("ar",    "ar",    "ar",      "ar",      "العربية",             "rtl", False),
]

# 지금 배포에 올라가는 언어 — 고르개·hreflang·검사가 모두 이것을 본다.
ACTIVE = [lang for lang in LANGS if lang.ready]

# 언어마다 있어야 하는 페이지. 파일 이름은 언어가 달라도 같다 — 주소를 손으로 고쳐 다른 언어로
# 건너뛸 수 있고, 리다이렉트·검사도 한 규칙으로 끝난다.
PAGES = ("index.html", "theming.html", "widgets.html")

PUBLIC = "https://thruthesky.github.io/gohud/"
BY_CODE = {lang.code: lang for lang in LANGS}
DEFAULT = LANGS[0]


def rel_path(code, page):
    """배포본 안의 자리 — 영어는 `index.html`, 그 밖은 `ja/index.html`."""
    folder = BY_CODE[code].folder
    return "%s/%s" % (folder, page) if folder else page


def public_url(code, page):
    """hreflang 에 적는 절대 주소. 🛑 첫 페이지는 `index.html` 을 떼어 한 주소로 모은다 —
    `…/ja/` 와 `…/ja/index.html` 두 주소가 같은 글을 내면 검색엔진이 둘로 센다."""
    rel = rel_path(code, page)
    if page == "index.html":
        rel = rel[: -len("index.html")]
    return PUBLIC + rel


def link_from(here_code, there_code, page):
    """`here_code` 페이지에서 `there_code` 의 같은 페이지로 가는 **상대** 주소.
    상대 주소라야 `python3 -m http.server` 로 띄운 배포본 미리보기에서도 그대로 눌린다."""
    up = "../" if BY_CODE[here_code].folder else ""
    folder = BY_CODE[there_code].folder
    target = "%s%s/%s" % (up, folder, page) if folder else "%s%s" % (up, page)
    # 같은 폴더 안이면 파일 이름만 남긴다 — `ja/index.html` 에서 `../ja/index.html` 은 돌아가는 길이다.
    if there_code == here_code:
        target = page
    return target
