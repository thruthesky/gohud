# -*- coding: utf-8 -*-
"""gohud 홈페이지(`docs/`)의 **용어 사전**을 소스에서 뽑아 만든다.

    python3 addons/gohud/tools/make_site.py        # docs/www/site/glossary.js 를 다시 만든다

## 왜 자동인가
용어 설명을 손으로 쓰면 **코드가 바뀔 때 같이 바뀌지 않는다.** 클래스를 하나 더해도 사전에는
없고, 토큰 이름을 고쳐도 사전은 옛 이름을 설명한다. 그래서 gohud 쪽 용어(클래스·토큰·타입 변형)는
전부 소스에서 읽고, 사람이 써야 하는 것(엔진 일반 용어·개념어)만 이 파일 안에 둔다.

## 뽑아 오는 것
| 무엇 | 어디서 |
|---|---|
| gohud 클래스 | `core/`·`widgets/`·`services/`·`themes/skins/` 의 `class_name` + 바로 위 `##` 첫 문장 |
| 색·치수·StyleBox 토큰 | `core/go_theme.gd` 의 상수 |
| 타입 변형(`GoCard` 등) | 같은 파일의 `VAR_*` 상수 |
| 생김새 묶음 이름 | `core/go_theme_presets.gd` 의 `BUILTIN` |

🛑 설명이 비면 **그 용어는 넣지 않는다** — 뜻이 안 적힌 빈 풍선이 뜨는 것이 아무것도 없는 것보다 나쁘다.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
# 🛑 사이트는 `docs/` 루트가 영문, `docs/ko/` 가 한국어다(2026-09-13 에 GitHub Pages 배포 구조로 재배치).
#    사전 두 장은 `docs/site/` 에 둔다 — 영문 페이지는 `site/`, 한국어 페이지는 `../site/` 로 읽는다.
SITE = os.path.join(ADDON, "docs", "site")

SOURCE_DIRS = ["core", "widgets", "services", "themes/skins"]


# ── 사람이 써야 하는 것 ────────────────────────────────────────────────
# 엔진 일반 용어와 개념어. gohud 소스에는 정의가 없으므로 여기 둔다.
# k = 분류(풍선의 작은 딱지), d = 설명, u = 더 읽을 곳.

DOCS = "https://docs.godotengine.org/en/stable/classes/class_%s.html"

MANUAL = {
    # ── 엔진 클래스 ────────────────────────────────────────────────
    "Theme": {"k": "리소스", "d": "색·글꼴·여백·StyleBox 를 한 장에 모아 둔 리소스. 어떤 Control 에 꽂으면 그 아래 자식까지 전부 그 규격으로 그려진다.", "u": DOCS % "theme"},
    "StyleBox": {"k": "리소스", "d": "Control 의 배경 한 겹을 그리는 리소스. 버튼의 판, 카드의 테두리가 전부 이것이다.", "u": DOCS % "stylebox"},
    "StyleBoxFlat": {"k": "리소스", "d": "엔진이 기본으로 주는 StyleBox. 단색 배경·테두리·**둥근** 모서리·그림자를 낸다. 모서리는 둥근 것뿐이라 사선으로 자를 수 없다.", "u": DOCS % "styleboxflat"},
    "StyleBoxEmpty": {"k": "리소스", "d": "아무것도 그리지 않는 StyleBox. 판을 지우고 싶을 때 쓴다.", "u": DOCS % "styleboxempty"},
    "Control": {"k": "노드", "d": "UI 노드의 뿌리. 위치·크기·앵커·포커스·마우스 판정을 다룬다.", "u": DOCS % "control"},
    "Node": {"k": "노드", "d": "Godot 의 모든 것이 이것을 물려받는다. 씬 트리에 붙어 사는 한 덩어리.", "u": DOCS % "node"},
    "Resource": {"k": "클래스", "d": "파일로 저장하고 여러 곳에서 함께 쓰는 데이터 덩어리. `.tres` 가 이것이다.", "u": DOCS % "resource"},
    "CanvasItem": {"k": "클래스", "d": "2D 로 그려지는 것의 공통 조상. `_draw()` 로 직접 선과 도형을 그릴 수 있다.", "u": DOCS % "canvasitem"},
    "PanelContainer": {"k": "노드", "d": "배경 판 한 장을 깔고 그 안에 자식을 넣는 컨테이너. gohud 의 카드가 이것이다.", "u": DOCS % "panelcontainer"},
    "Button": {"k": "노드", "d": "누를 수 있는 컨트롤. 상태(보통·호버·눌림·비활성·포커스)마다 다른 StyleBox 를 쓴다.", "u": DOCS % "button"},
    "ScrollContainer": {"k": "노드", "d": "내용이 넘치면 스크롤시키는 컨테이너.", "u": DOCS % "scrollcontainer"},
    "CanvasLayer": {"k": "노드", "d": "카메라와 무관하게 화면에 고정되는 층. HUD 와 팝업이 여기 산다.", "u": DOCS % "canvaslayer"},
    "FoldableContainer": {"k": "노드", "d": "제목 줄을 눌러 접었다 폈다 하는 컨테이너. Godot 4.5 에 들어왔다.", "u": DOCS % "foldablecontainer"},
    "DPITexture": {"k": "리소스", "d": "SVG 를 화면 배율에 맞춰 **다시 래스터화**하는 텍스처. UI 를 키워도 아이콘이 뭉개지지 않는다. Godot 4.5 에 들어왔다(그 전 이름은 SVGTexture).", "u": DOCS % "dpitexture"},
    "ProgressBar": {"k": "노드", "d": "값을 막대로 보여 주는 컨트롤. 배경과 채움 두 StyleBox 를 쓴다.", "u": DOCS % "progressbar"},
    "RenderingServer": {"k": "서버", "d": "그리기 명령을 직접 넣는 저수준 창구. 커스텀 StyleBox 는 이것으로 다각형과 선을 그린다.", "u": DOCS % "renderingserver"},
    "Tween": {"k": "클래스", "d": "값을 시간에 따라 부드럽게 바꾸는 것. 막대가 뚝 끊기지 않고 흐르게 한다.", "u": DOCS % "tween"},
    "TranslationServer": {"k": "서버", "d": "번역 키를 지금 언어의 문장으로 바꿔 주는 창구.", "u": DOCS % "translationserver"},
    "ProjectSettings": {"k": "클래스", "d": "프로젝트 전역 설정. gohud 는 여기에 설정 리소스 경로와 생김새 묶음 이름 칸을 만든다.", "u": DOCS % "projectsettings"},
    "GDScript": {"k": "언어", "d": "Godot 의 내장 스크립트 언어. gohud 는 전부 이것으로만 되어 있다 — 빌드도 GDExtension 도 필요 없다.", "u": "https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html"},

    # ── 파일·형식 ──────────────────────────────────────────────────
    ".tres": {"k": "파일", "d": "글자로 된 Godot 리소스 파일. 열어서 읽을 수 있고 git diff 도 된다.", "u": None},
    ".tscn": {"k": "파일", "d": "글자로 된 Godot 씬 파일.", "u": None},
    "SVG": {"k": "형식", "d": "선과 도형으로 된 그림 형식. 확대해도 깨지지 않아 아이콘에 쓴다.", "u": None},

    # ── UI 개념 ────────────────────────────────────────────────────
    "타입 변형": {"k": "개념", "d": "Theme 안에서 같은 노드 종류에 다른 옷을 입히는 이름표. `GoCard` 를 단 PanelContainer 는 카드 모양으로, 안 단 것은 기본 판으로 그려진다.", "u": None},
    "theme type variation": {"k": "개념", "d": "「타입 변형」의 원래 이름. Theme 안에서 같은 노드에 다른 스타일을 주는 이름표다.", "u": None},
    "토큰": {"k": "개념", "d": "색·치수를 숫자 대신 **이름**으로 부르는 것. `accent`·`gap` 처럼. 이름으로 부르면 테마를 갈아 끼울 때 전부 따라 바뀐다.", "u": None},
    "프리셋": {"k": "gohud", "d": "테마 + 스킨 + 아이콘 세트를 한 단위로 묶은 것. 한 줄로 생김새를 통째로 갈아 끼운다.", "u": None},
    "스킨": {"k": "gohud", "d": "Theme 가 닿지 못하는 자리 — 코드가 직접 그리는 조이스틱·퀵슬롯·코치마크 — 의 모양을 정하는 리소스.", "u": None},
    "dp": {"k": "단위", "d": "화면 밀도와 무관한 길이 단위. 같은 48dp 버튼이 어떤 기기에서도 손가락만 하게 보인다.", "u": None},
    "안전영역": {"k": "개념", "d": "노치·둥근 모서리·제스처 바를 피한 실제로 쓸 수 있는 화면 범위.", "u": None},
    "safe area": {"k": "개념", "d": "「안전영역」의 원래 이름 — 노치와 제스처 바를 피한 실제 사용 가능 영역.", "u": None},
    "브레이크포인트": {"k": "개념", "d": "폰·태블릿·데스크톱을 가르는 화면 폭의 경계. gohud 는 576dp·991dp 를 쓴다.", "u": None},
    "터치 타깃": {"k": "개념", "d": "손가락으로 누를 수 있는 최소 크기. Material 은 48dp, Apple 은 44pt 를 권한다. **보이는 크기와 다를 수 있다.**", "u": None},
    "스크림": {"k": "개념", "d": "팝업 뒤를 덮는 반투명 막. 뒤쪽이 지금 못 쓰는 상태임을 눈으로 알린다.", "u": None},
    "챔퍼": {"k": "개념", "d": "모서리를 둥글게가 아니라 **사선으로 잘라 낸** 모양. sci-fi 프리셋의 판이 이것이다.", "u": None},
    "명도 대비비": {"k": "접근성", "d": "글자와 배경의 밝기 차이. WCAG 는 본문 4.5:1, 큰 글자 3:1 이상을 요구한다. 낮으면 밝은 곳에서 글이 사라진다.", "u": "https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html"},
    "WCAG": {"k": "접근성", "d": "웹 접근성 지침. 색 대비·글자 크기 같은 것의 국제 기준선이다.", "u": "https://www.w3.org/WAI/standards-guidelines/wcag/"},
    "알파 합성": {"k": "접근성", "d": "반투명한 색을 **뒤에 깔린 색 위에 얹어** 실제로 화면에 나오는 색을 구하는 계산. 대비를 재기 전에 반드시 해야 한다 — 그냥 재면 화면보다 좋게 나온다.", "u": None},
    "떠 있는 판": {"k": "개념", "d": "게임 화면 위에 얹히는 HUD·팝업의 배경판. 뒤에 무엇이 오는지 **알 수 없으므로**, 반투명이면 최악의 뒷배경(순백·순흑)에서도 글자가 읽혀야 한다.", "u": None},
    "RTL": {"k": "개념", "d": "오른쪽에서 왼쪽으로 읽는 언어(아랍어·히브리어). 배치가 통째로 거울처럼 뒤집힌다.", "u": None},
    "햅틱": {"k": "개념", "d": "누른 것이 손에 느껴지도록 하는 짧은 진동.", "u": None},
    "오토로드": {"k": "개념", "d": "게임이 시작될 때 자동으로 하나 만들어져 끝까지 살아 있는 노드. gohud 는 **없어도 동작한다.**", "u": "https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html"},
    "GitHub Pages": {"k": "서비스", "d": "저장소의 파일을 그대로 웹사이트로 띄워 주는 GitHub 기능. 이 문서가 그렇게 올라간다.", "u": "https://pages.github.com/"},
}



# ── 영문판 ─────────────────────────────────────────────────────────────
#
# 🛑 한국어 사전은 **소스의 `##` 주석**에서 뽑지만, 영문은 뽑아 올 곳이 없다(주석이 한국어다).
#    그래서 영문 설명은 여기 손으로 둔다. 설명이 없는 용어는 **영문 사전에 넣지 않는다** —
#    한국어 설명이 뜨는 영문 페이지보다 용어가 없는 편이 낫다.

MANUAL_EN = {
    "Theme": {"k": "resource", "d": "One resource holding colours, fonts, spacing and StyleBoxes. Assign it to a Control and everything below it is drawn to that spec.", "u": DOCS % "theme"},
    "StyleBox": {"k": "resource", "d": "Draws one layer of background for a Control — a button's panel, a card's border.", "u": DOCS % "stylebox"},
    "StyleBoxFlat": {"k": "resource", "d": "The engine's built-in StyleBox: solid fill, border, **rounded** corners, shadow. Rounded is the only corner it has — you cannot cut one diagonally.", "u": DOCS % "styleboxflat"},
    "StyleBoxEmpty": {"k": "resource", "d": "A StyleBox that draws nothing. Used to remove a panel.", "u": DOCS % "styleboxempty"},
    "Control": {"k": "node", "d": "The root of every UI node — position, size, anchors, focus and mouse hit testing.", "u": DOCS % "control"},
    "Node": {"k": "node", "d": "Everything in Godot inherits this. One thing living in the scene tree.", "u": DOCS % "node"},
    "Resource": {"k": "class", "d": "Data saved to a file and shared between places. A `.tres` is one.", "u": DOCS % "resource"},
    "CanvasItem": {"k": "class", "d": "Common ancestor of everything drawn in 2D. `_draw()` lets you put down lines and shapes yourself.", "u": DOCS % "canvasitem"},
    "PanelContainer": {"k": "node", "d": "Lays down one background panel and puts children inside it. gohud's cards are these.", "u": DOCS % "panelcontainer"},
    "Button": {"k": "node", "d": "A pressable control. Each state (normal, hover, pressed, disabled, focus) uses a different StyleBox.", "u": DOCS % "button"},
    "ScrollContainer": {"k": "node", "d": "Scrolls its contents when they overflow.", "u": DOCS % "scrollcontainer"},
    "CanvasLayer": {"k": "node", "d": "A layer pinned to the screen regardless of the camera. HUDs and popups live here.", "u": DOCS % "canvaslayer"},
    "FoldableContainer": {"k": "node", "d": "A container you collapse and expand by its title row. Added in Godot 4.5.", "u": DOCS % "foldablecontainer"},
    "DPITexture": {"k": "resource", "d": "Re-rasterises an SVG to match the screen scale, so icons stay sharp when the UI is enlarged. Added in Godot 4.5 (previously SVGTexture).", "u": DOCS % "dpitexture"},
    "ProgressBar": {"k": "node", "d": "Shows a value as a bar. Uses two StyleBoxes — background and fill.", "u": DOCS % "progressbar"},
    "RenderingServer": {"k": "server", "d": "The low-level drawing interface. Custom StyleBoxes use it to draw polygons and lines.", "u": DOCS % "renderingserver"},
    "GDScript": {"k": "language", "d": "Godot's built-in scripting language. gohud is written entirely in it — no build step, no GDExtension.", "u": "https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html"},
    "ProjectSettings": {"k": "class", "d": "Project-wide settings. gohud adds fields here for its config resource path and preset name.", "u": DOCS % "projectsettings"},
    ".tres": {"k": "file", "d": "A Godot resource saved as text — readable, and it diffs in git."},
    ".tscn": {"k": "file", "d": "A Godot scene saved as text."},
    "SVG": {"k": "format", "d": "A drawing made of lines and shapes, so it stays sharp at any size. Used for icons."},
    "type variation": {"k": "concept", "d": "A name inside a Theme that gives one kind of node a different look. A PanelContainer tagged `GoCard` draws as a card; one without it draws as a plain panel."},
    "token": {"k": "concept", "d": "Calling a colour or a size by **name** instead of a number — `accent`, `gap`. Names follow along when you swap the theme; numbers do not."},
    "preset": {"k": "gohud", "d": "A theme, a skin and an icon set picked as one unit, so one line changes the whole look."},
    "skin": {"k": "gohud", "d": "The resource deciding the shape of things a Theme cannot reach — the joystick, quick slots, the coach mark."},
    "dp": {"k": "unit", "d": "A length independent of screen density, so a 48dp button is finger-sized on any device."},
    "safe area": {"k": "concept", "d": "The part of the screen actually usable, clear of notches, rounded corners and the gesture bar."},
    "breakpoint": {"k": "concept", "d": "The screen widths separating phone, tablet and desktop. gohud uses 576dp and 991dp."},
    "touch target": {"k": "concept", "d": "The smallest area a finger can reliably press — Material asks 48dp, Apple 44pt. **It need not match the visible size.**"},
    "scrim": {"k": "concept", "d": "The translucent veil behind a popup, telling you the layer behind it is not usable right now."},
    "chamfer": {"k": "concept", "d": "A corner cut off **diagonally** rather than rounded. The sci-fi presets' panels use these."},
    "contrast ratio": {"k": "accessibility", "d": "How far apart two colours are in brightness. WCAG asks 4.5:1 for body text, 3:1 for large text. Below that, text disappears in daylight.", "u": "https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html"},
    "WCAG": {"k": "accessibility", "d": "The web accessibility guidelines — the international baseline for things like colour contrast.", "u": "https://www.w3.org/WAI/standards-guidelines/wcag/"},
    "alpha compositing": {"k": "accessibility", "d": "Laying a translucent colour **over what is behind it** to get the colour actually shown on screen. Do this before measuring contrast — measuring the raw colour reports a better ratio than the screen shows."},
    "floating panel": {"k": "concept", "d": "The backing panel of a HUD or popup drawn over the game. You cannot know what will be behind it, so if it is translucent the text on it must stay readable over the worst backdrop — pure white and pure black."},
    "RTL": {"k": "concept", "d": "Languages read right to left (Arabic, Hebrew). The whole layout mirrors."},
    "haptics": {"k": "concept", "d": "A short vibration so a press is felt, not just seen."},
    "autoload": {"k": "concept", "d": "A node created at startup and alive for the whole run. gohud **works without one.**", "u": "https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html"},
    "GitHub Pages": {"k": "service", "d": "GitHub's feature that serves a repository's files as a website. This page is published that way.", "u": "https://pages.github.com/"},
}

# gohud 클래스의 영문 한 줄. 🛑 여기 없는 클래스는 영문 사전에서 빠진다.
CLASS_EN = {
    "GoUi": "The single entry point. Config, theme, skin, icons and strings all come from here, and every function is static — no autoload required.",
    "GoConfig": "One settings resource: theme, icons, sizes, surface behaviour, feedback, localization and accessibility. Every field has a working default.",
    "GoTheme": "The names of the theme tokens and how to look them up. Constants instead of strings, so a typo fails to compile rather than returning black.",
    "GoSkin": "The shapes a Theme cannot reach — the joystick, quick-slot faces, the coach-mark ring, chips, dividers. Subclass it and override only what you want to change.",
    "GoSkinSciFi": "The sci-fi shapes: angular panels, a hexagonal joystick, diamond knobs, targeting brackets instead of rings.",
    "GoThemePreset": "A theme, a skin and an icon set bundled as the unit you pick.",
    "GoThemePresets": "The registry mapping preset names to resources, including the four gohud ships.",
    "GoIconSet": "A swappable icon set. Widgets ask for icons by name, so a set can be a texture pack, an icon font, or a partial override of another set.",
    "GoStyleBoxCut": "A panel with corners cut diagonally, an optional accent edge on one side, and an outer glow — shapes StyleBoxFlat cannot make.",
    "GoStyleBoxBracket": "Marks only the four corners instead of enclosing the content — the targeting bracket of a tactical display.",
    "GoStyle": "The widget factory. Building buttons and rows in one place keeps spacing, height and wrapping identical across screens.",
    "GoSurface": "The shell of a floating window. Popups, sheets and dropdowns all use this one — safe area, virtual keyboard, sticky header and footer, scrolling body, back-button ownership.",
    "GoSheet": "A page that rises from the bottom, on its own CanvasLayer so it sits above the HUD.",
    "GoDialogs": "Confirmations and alerts you receive with `await`.",
    "GoForm": "A form that caps its width per breakpoint, avoids the virtual keyboard and guarantees its labels wrap.",
    "GoScroll": "Touch-friendly scrolling whose scrollbar tucks into the card's existing padding.",
    "GoNotice": "A snackbar that never takes input or focus — a message is read, not pressed.",
    "GoPromptCard": "A question card that does not block the screen; the game keeps running behind it.",
    "GoCoachMark": "A guided tour pointing at real controls. Pressing the highlighted control advances the tour.",
    "GoHudAnchor": "Pins a HUD piece to one of nine spots, respecting the safe area, with an optional different spot in landscape.",
    "GoBar": "A health/mana/experience bar with value, fraction or percent readouts and eased changes.",
    "GoSlot": "One quick slot carrying icon, quantity, cooldown and shortcut on a single face, with hit areas shared between crowded neighbours.",
    "GoJoystick": "A virtual joystick in fixed, follow or relative mode, reporting a direction and strength of length 0–1.",
    "GoIconButton": "An icon-only button that looks small and presses large.",
    "GoFeedback": "Haptics and sound cues. gohud ships no audio — the project supplies the sounds.",
    "GoScale": "The dp coordinate system and the breakpoints.",
    "GoSafeArea": "Works out the usable rectangle, clear of notches and the gesture bar.",
    "GoRuntime": "The optional autoload tracking window size, dp scale and keyboard height. Widgets work without it.",
    "GoBackPolicy": "Decides what Escape and the Android Back button close — the topmost surface only.",
}


def first_doc_sentence(lines, index):
    """`class_name` 줄 위에 붙은 `##` 주석 덩어리에서 **첫 문장**을 뽑는다."""
    block = []
    cursor = index - 1
    while cursor >= 0:
        line = lines[cursor].rstrip()
        if line.startswith("##"):
            block.append(line[2:].strip())
        elif line.startswith("@tool") or line == "":
            pass
        else:
            break
        cursor -= 1
    block.reverse()
    # 🛑 **첫 문단까지만** 쓴다 — 그 아래는 "## ## 왜 이런가" 같은 소제목과 코드 예시라,
    #    그대로 이으면 풍선 안에 문서 한 장이 통째로 들어간다.
    paragraph = []
    for part in block:
        if not part:
            if paragraph:
                break
            continue
        if part.startswith("#"):        # 소제목(## 왜 …)에서 끊는다
            break
        paragraph.append(part)
    text = " ".join(paragraph)
    if not text:
        return ""
    # 굵게·이모지·코드 표시를 걷어 낸다 — 풍선 안에서는 글만 보인다.
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    text = re.sub(r"\[(.+?)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"^[^\w가-힣]+", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    # 너무 길면 두 문장까지. 짧은 첫 문장 하나만으로는 뜻이 서지 않는 것이 많다.
    sentences = re.findall(r".+?[.。](?:\s|$)", text)
    if sentences and len("".join(sentences[:2])) >= 12:
        text = "".join(sentences[:2]).strip()
    if len(text) > 300:
        text = text[:297].rstrip() + "…"
    return text


def scan_classes():
    """소스에서 `class_name` 과 그 설명을 모은다."""
    out = {}
    for folder in SOURCE_DIRS:
        root = os.path.join(ADDON, folder)
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            if not name.endswith(".gd"):
                continue
            path = os.path.join(root, name)
            lines = open(path, encoding="utf-8").read().split("\n")
            for index, line in enumerate(lines):
                match = re.match(r"^class_name\s+([A-Za-z0-9_]+)", line)
                if not match:
                    continue
                described = first_doc_sentence(lines, index)
                if not described:
                    continue        # 🛑 설명 없는 용어는 넣지 않는다
                base = ""
                for follow in lines[index:index + 3]:
                    extends = re.match(r"^extends\s+([A-Za-z0-9_]+)", follow)
                    if extends:
                        base = extends.group(1)
                        break
                entry = {"d": described, "k": "gohud"}
                if base:
                    entry["c"] = base
                out[match.group(1)] = entry
    return out


def scan_tokens(lang="ko"):
    """`GoTheme` 의 토큰 상수 → 용어. 이름만으로는 뜻을 모르는 것들이다."""
    path = os.path.join(ADDON, "core", "go_theme.gd")
    if not os.path.isfile(path):
        return {}
    text = open(path, encoding="utf-8").read()
    out = {}
    kinds = [
        (r"# ── 색 ", "색 토큰"),
        (r"# ── 치수", "치수 토큰"),
        (r"# ── 표면 StyleBox", "StyleBox 토큰"),
    ]
    for pattern, kind in kinds:
        match = re.search(pattern + r".*?\n(.*?)(?=\n# ──|\Z)", text, re.S)
        if not match:
            continue
        for name, value in re.findall(r'^const\s+([A-Z_0-9]+)\s*:=\s*&"([^"]+)"', match.group(1), re.M):
            if lang == "en":
                out["GoTheme." + name] = {"k": "token", "d": 'Theme token "%s", called as GoTheme.%s in code.' % (value, name)}
            else:
                out["GoTheme." + name] = {"k": kind, "d": '테마 토큰 "%s". 코드에서는 GoTheme.%s 로 부른다.' % (value, name)}
    for name, value in re.findall(r'^const\s+(VAR_[A-Z_0-9]+)\s*:=\s*&"([^"]+)"', text, re.M):
        out[value] = {"k": "type variation" if lang == "en" else "타입 변형",
                      "d": "A type variation name inside the Theme; a node tagged with it is drawn to that spec."
                           if lang == "en" else "Theme 안의 타입 변형 이름. 이것을 단 노드는 그 규격으로 그려진다."}
    return out


def scan_presets(lang="ko"):
    path = os.path.join(ADDON, "core", "go_theme_presets.gd")
    if not os.path.isfile(path):
        return {}
    text = open(path, encoding="utf-8").read()
    out = {}
    for name in re.findall(r'^\tDEFAULT_[A-Z]+|^\tSCIFI_[A-Z]+', text, re.M):
        pass
    for key in re.findall(r'^const\s+[A-Z_]+\s*:=\s*&"([a-z_]+)"', text, re.M):
        out[key] = {"k": "preset" if lang == "en" else "프리셋",
                    "d": "One of the presets gohud ships; pass this name to GoUi.use_preset()."
                         if lang == "en" else "gohud 가 담아 보내는 생김새 묶음 이름. GoUi.use_preset() 에 이 이름을 준다."}
    return out


def build(lang="ko"):
    glossary = {}
    if lang == "en":
        glossary.update(MANUAL_EN)
        glossary.update(scan_tokens(lang))
        glossary.update(scan_presets(lang))
        # 🛑 영문 설명이 있는 클래스만 넣는다 — 한국어 설명이 뜨는 영문 페이지보다 없는 편이 낫다.
        for name, entry in scan_classes().items():
            if name in CLASS_EN:
                out = {"d": CLASS_EN[name], "k": "gohud"}
                if entry.get("c"): out["c"] = entry["c"]
                glossary[name] = out
    else:
        glossary.update(MANUAL)
        glossary.update(scan_tokens())
        glossary.update(scan_presets())
        glossary.update(scan_classes())      # 소스가 가장 세다 — 손으로 쓴 것을 덮는다
    # `u` 가 None 인 것은 키 자체를 뺀다(툴팁이 빈 링크를 그리지 않게).
    for entry in glossary.values():
        if entry.get("u") is None:
            entry.pop("u", None)
        # 🛑 풍선은 설명을 **글자 그대로** 넣는다(`textContent`) — 마크다운을 남기면 `**둥근**` 이
        #    그대로 보인다. 소스에서 뽑은 것은 이미 지웠지만, 손으로 쓴 사전은 여기서 지운다.
        if "d" in entry:
            entry["d"] = re.sub(r"\*\*(.+?)\*\*", r"\1", entry["d"])
            entry["d"] = re.sub(r"`(.+?)`", r"\1", entry["d"])
    os.makedirs(SITE, exist_ok=True)
    path = os.path.join(SITE, "glossary.js" if lang == "ko" else "glossary.%s.js" % lang)
    body = json.dumps(glossary, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("/* gohud 용어 사전 — tools/make_site.py 가 만든다. 손으로 고치지 않는다. */\n")
        fh.write("window.GLOSSARY=" + body + ";\n")
    print("%s — 용어 %d개" % (os.path.relpath(path, ADDON), len(glossary)))
    return glossary


if __name__ == "__main__":
    build("ko")
    build("en")
