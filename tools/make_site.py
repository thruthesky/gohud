# -*- coding: utf-8 -*-
"""Builds the **glossary** for the gohud website (`www/`) by extracting it from the source.

    python3 addons/gohud/tools/make_site.py        # rebuilds www/site/glossary.js

## Why generate it
Written by hand, glossary entries **do not change when the code does.** Add a class and the glossary
has never heard of it; rename a token and the glossary still explains the old name. So everything on
the gohud side (classes, tokens, type variations) is read from the source, and only what a person has
to write (general engine terms, concepts) lives in this file.

## What is extracted
| What | From where |
|---|---|
| gohud classes | `class_name` in `core/`·`widgets/`·`services/`·`themes/skins/` + the first sentence of the `##` block above it |
| Colour, metric and StyleBox tokens | the constants in `core/go_theme.gd` |
| Type variations (`GoCard` and friends) | the `VAR_*` constants in that same file |
| Preset names | `BUILTIN` in `core/go_theme_presets.gd` |
| Skin dials | `@export var` in `core/go_skin.gd`·`themes/skins/go_skin_scifi.gd` + the `##` comment above it — it goes into the glossary and also fills the table in `theming.html` (between `<!-- dials:begin -->`) |

🛑 When the description is empty **the term is left out** — an empty bubble with no meaning in it is
worse than nothing at all.
"""
import json
import os
import re

# 🔑 The language list lives in one place, `tools/site_langs.py` — every page's language picker and
#    hreflang tags are rewritten from that list.
import make_search
import site_langs
import site_nav

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, ".."))
# 🛑 On the site, the `www/` root is English and `www/ko/` is Korean (moved out from under docs to the
#    repository root on 2026-09-15 — GitHub Actions publishes this folder as the Pages root).
#    Both glossaries live in `www/site/` — English pages read `site/`, Korean pages `../site/`.
WWW = os.environ.get("GOHUD_SITE_OUTPUT", os.path.join(ADDON, "www"))
SITE = os.path.join(WWW, "site")

SOURCE_DIRS = ["core", "widgets", "services", "themes/skins"]


# ── What a person has to write ─────────────────────────────────────────
# General engine terms and concepts. The gohud source has no definition for them, so they live here.
# k = kind (the small tag on the bubble), d = description, u = where to read more.

DOCS = "https://docs.godotengine.org/en/stable/classes/class_%s.html"

MANUAL = {
    "양피지": {'k': '디자인', 'd': '중세 필사본을 떠올리는 밝은 문서 표면. 여기서는 따뜻한 팔레트와 은은한 질감으로 표현한다.', 'u': None},
    "리벳": {'k': '디자인', 'd': '철판을 고정하는 작은 금속 못 머리. 중세 프레임에서는 모서리 장식으로 표현한다.', 'u': None},
    "베벨": {'k': '디자인', 'd': '빛과 그림자로 경사진 가장자리를 표현해 프레임에 입체감을 주는 방식.', 'u': None},
    "각인": {'k': '디자인', 'd': '재료 표면에 새긴 선. 중세 아이콘에서는 실루엣과 내부 선으로 표현한다.', 'u': None},
    "Cinzel": {'k': '디자인', 'd': '함께 제공하는 제목용 세리프 글꼴. 본문은 기존 글꼴을 유지하며 SIL Open Font License를 포함한다.', 'u': None},
    # ── Engine classes ─────────────────────────────────────────────
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

    # ── Files and formats ──────────────────────────────────────────
    ".tres": {"k": "파일", "d": "글자로 된 Godot 리소스 파일. 열어서 읽을 수 있고 git diff 도 된다.", "u": None},
    ".tscn": {"k": "파일", "d": "글자로 된 Godot 씬 파일.", "u": None},
    "SVG": {"k": "형식", "d": "선과 도형으로 된 그림 형식. 확대해도 깨지지 않아 아이콘에 쓴다.", "u": None},

    # ── UI concepts ────────────────────────────────────────────────
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



# ── The English glossary ───────────────────────────────────────────────
#
# 🛑 The Korean glossary is extracted from the **`##` comments in the source**, but there is nowhere to
#    extract English from (those comments are Korean). So the English descriptions are kept here by
#    hand. A term without one is **left out of the English glossary** — a missing term beats an English
#    page popping up a Korean description.

MANUAL_EN = {
    "parchment": {'k': 'design', 'd': 'A warm, pale writing surface inspired by historical manuscripts. Here it is a palette and subtle grain, keeping the text readable.', 'u': None},
    "rivet": {'k': 'design', 'd': 'A small metal fastening head. The medieval frame uses these as restrained corner decorations.', 'u': None},
    "bevel": {'k': 'design', 'd': 'A sloped edge suggested by a highlight and shadow, making the frame look raised.', 'u': None},
    "engraving": {'k': 'design', 'd': 'Fine lines cut into a material; the medieval icons suggest this with silhouettes and etched details.', 'u': None},
    "Cinzel": {'k': 'design', 'd': 'The bundled serif heading font. Body text retains the host font; the font includes its SIL Open Font License.', 'u': None},
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

# One English line per gohud class. 🛑 A class missing here is left out of the English glossary.
CLASS_EN = {
    "GoSkinMedieval": "Iron-bound leather and parchment surfaces, restrained rivets, engraved slots and a compass joystick. Other behaviour comes from GoSkin.",
    "GoStyleBoxMedieval": "A scalable frame with metal relief, rivets, corner engraving and subtle material grain. Decorations stay in the gutters around content.",
    "GoUi": "The single entry point. Config, theme, skin, icons and strings all come from here, and every function is static — no autoload required.",
    "GoConfig": "One settings resource: theme, icons, sizes, surface behaviour, feedback, localization and accessibility. Every field has a working default.",
    "GoTheme": "The names of the theme tokens and how to look them up. Constants instead of strings, so a typo fails to compile rather than returning black.",
    "GoSkin": "The shapes a Theme cannot reach — the joystick, quick-slot faces, the coach-mark ring, chips, dividers. Subclass it and override only what you want to change.",
    "GoSkinSciFi": "The sci-fi shapes: angular panels, a hexagonal joystick, diamond knobs, targeting brackets instead of rings.",
    "GoThemePreset": "A theme, a skin and an icon set bundled as the unit you pick.",
    "GoThemePresets": "The registry mapping preset names to resources, including the six gohud ships.",
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
    """Take **the first sentence** out of the `##` comment block above a `class_name` line."""
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
    # 🛑 Use **the first paragraph only** — below it come subheadings like "## ## Why this way" and code
    #    samples, and joining those in would drop a whole page of documentation into the bubble.
    paragraph = []
    for part in block:
        if not part:
            if paragraph:
                break
            continue
        if part.startswith("#"):        # stop at a subheading (## Why …)
            break
        paragraph.append(part)
    text = " ".join(paragraph)
    if not text:
        return ""
    # Strip bold, emoji and code markers — the bubble shows nothing but the words.
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    text = re.sub(r"\[(.+?)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"^[^\w가-힣]+", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    # Up to two sentences. A single short first sentence often does not stand on its own.
    sentences = re.findall(r".+?[.。](?:\s|$)", text)
    if sentences and len("".join(sentences[:2])) >= 12:
        text = "".join(sentences[:2]).strip()
    if len(text) > 300:
        text = text[:297].rstrip() + "…"
    return text


def scan_classes():
    """Collect every `class_name` and its description from the source."""
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
                    continue        # 🛑 a term without a description is left out
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
    """The token constants of `GoTheme` → glossary terms. Their names alone do not say what they mean."""
    path = os.path.join(ADDON, "core", "go_theme.gd")
    if not os.path.isfile(path):
        return {}
    text = open(path, encoding="utf-8").read()
    out = {}
    kinds = [
        # 🛑 These patterns must track the section rules in `core/go_theme.gd`. When that file's
        #    comments were translated to English (2026-09-16) these still read `# ── 색 ` and all
        #    45 `GoTheme.*` terms silently vanished from the glossary — the check stayed green
        #    because a smaller glossary is still a valid glossary. Change them together.
        (r"# ── Colors ", "색 토큰"),
        (r"# ── Metrics", "치수 토큰"),
        (r"# ── Surface StyleBox", "StyleBox 토큰"),
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


# ── Skin dials ─────────────────────────────────────────────────────────
# 🔑 There are 27 dials, but the site listed only the "kind", so finding out what could be changed meant
#    opening the JSON (2026-09-13, I-70). The values come from `make_theme.skin_dials()` (GDScript is the
#    source) and the meanings from the `##` comment right above each `@export`; together they fill the
#    glossary and the table in `theming.html` — add a dial and the documentation follows.
# 🛑 The English meanings are not in the source, so they live here in `DIALS_EN`. A missing one is caught
#    by `check_site.py` — a row with a name and no meaning is an empty bubble.
# 🛑 Write one line per dial. Combined (`— while on cooldown / at rest`), the table left the order as the
#    only clue to which name was which (I-72). The source comments follow the same rule, and when
#    consecutive dials share one comment the table joins them with a rowspan.

DIALS_EN = {
    "slot_radius": "Corner radius (dp) of the medieval quick-slot frame.",
    "leather_grain_alpha": "Opacity of the subtle leather marks inside quick slots.",
    "ornament_scale": "Scale of the metal decorations at quick-slot corners. Menu frames use shape.ornament_scale.",
    "bevel_strength": "Strength of the metal highlight along quick-slot edges.",
    "slot_rivets": "Show small metal rivets on quick slots: 0 hides them, 1 shows them.",
    "chip_fill_alpha": "Fill opacity of a chip's panel.",
    "chip_edge_alpha": "Edge opacity of a chip's panel.",
    "alert_tint": "How far an alert box's panel is tinted toward its status colour.",
    "slot_tint_lit": "Accent tint of a quick-slot panel while its cooldown runs.",
    "slot_tint_idle": "Accent tint of a quick-slot panel at rest.",
    "slot_border_lit": "Quick-slot border width (dp) while its cooldown runs.",
    "slot_border_idle": "Quick-slot border width (dp) at rest.",
    "badge_pad_x": "Horizontal inner padding (dp) of a badge (quantity, time left).",
    "badge_pad_y": "Vertical inner padding (dp) of a badge.",
    "badge_edge_alpha": "Edge opacity of a badge's panel.",
    "float_shadow_alpha": "Shadow opacity of floating cards (coach mark, prompt card).",
    "float_shadow_size": "Shadow blur (dp) of floating cards.",
    "float_shadow_lift": "Downward offset (dp) of a floating card's shadow.",
    "float_glow_size": "Glow distance (dp) of a floating panel that glows instead of casting a shadow, like the sci-fi chamfered panel.",
    "joystick_base_alpha": "Opacity of the joystick's base disc.",
    "joystick_ring_alpha": "Opacity of the joystick's ring.",
    "joystick_ring_width": "Width (dp) of the joystick's ring.",
    "cut_chip": "Chamfer size (dp) of a chip's panel.",
    "cut_skeleton": "Chamfer size (dp) of a skeleton panel.",
    "cut_alert": "Chamfer size (dp) of an alert box.",
    "cut_segment": "Chamfer size (dp) of a segmented control.",
    "cut_slot": "Chamfer size (dp) of a quick-slot panel.",
    "cut_disc_ratio": "Chamfer of avatars and discs = diameter × this ratio.",
    "slot_glow_alpha": "Glow opacity of a slot whose cooldown is running.",
    "slot_glow_size": "Glow distance (dp) of a slot whose cooldown is running.",
    "bracket_arm": "Arm length (dp) of the coach mark's targeting bracket.",
    "bracket_thickness": "Line thickness (dp) of the coach mark's targeting bracket.",
}

SKIN_TITLES = {
    "medieval": {"ko": "중세 스킨", "en": "Medieval skin"},
    "default": {"ko": "기본 스킨", "en": "Default skin"},
    "scifi": {"ko": "sci-fi 스킨", "en": "Sci-fi skin"},
}


def _make_theme():
    import sys
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import make_theme
    return make_theme


def scan_dials():
    """Skin → list of dial groups. A group = consecutive `@export var`s sharing one `##` comment.

    Returns: {"default": [{"names": [...], "ko": "meaning", "values": {name: value}}], "scifi": [...]}
    🛑 `make_theme.skin_dials()` is the source of the values — keeping a second regex here would let the
       two drift. This only reads the meanings, and skips any name absent from that table, since it is
       not a dial.
    """
    mt = _make_theme()
    values = mt.skin_dials()
    out = {}
    for skin, path in mt.SKIN_SOURCES.items():
        known = values.get(skin, {})
        groups = []
        pending = []
        for raw in open(path, encoding="utf-8").read().splitlines():
            line = raw.strip()
            if line.startswith("## "):
                pending.append(line[3:].strip())
                continue
            match = re.match(r"^@export var (\w+) := ", line)
            if match:
                name = match.group(1)
                if name not in known:
                    pending = []
                    continue
                if pending:
                    text = " ".join(p for p in pending if not p.startswith("🛑"))
                    groups.append({"names": [name], "ko": text, "values": {}})
                    pending = []
                elif groups:
                    groups[-1]["names"].append(name)
                else:
                    groups.append({"names": [name], "ko": "", "values": {}})
                groups[-1]["values"][name] = known[name]
                continue
            if not line.startswith("@export"):
                pending = []
        out[skin] = groups
    return out


def missing_english_dials():
    """Dial names with no meaning in `DIALS_EN` — the checker reports these as problems."""
    names = []
    for groups in scan_dials().values():
        for group in groups:
            names.extend(n for n in group["names"] if not DIALS_EN.get(n))
    return names


def _plain(text):
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    return re.sub(r"`(.+?)`", r"\1", text)


def _html_text(text):
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)


def dial_terms(lang="ko"):
    """Dial name → glossary term. The `<code>` cells inside the table pop up a bubble too."""
    mt = _make_theme()
    out = {}
    for skin, groups in scan_dials().items():
        cls = mt.SKIN_SCRIPTS[skin][0]
        for group in groups:
            for name in group["names"]:
                desc = DIALS_EN.get(name, "") if lang == "en" else group["ko"]
                if not desc:
                    continue      # 🛑 leave it out when the meaning is empty
                tail = (" Default %r, a dial of %s." if lang == "en" else " 기본값 %r, %s 의 다이얼.") % (group["values"][name], cls)
                out[name] = {"k": "skin dial" if lang == "en" else "스킨 다이얼", "d": _plain(desc) + tail}
    return out


def dials_html(lang="ko"):
    mt = _make_theme()
    head = ("<tr><th>Dial</th><th>Default</th><th>What it sets</th></tr>" if lang == "en"
            else "<tr><th>다이얼</th><th>기본값</th><th>뜻</th></tr>")
    parts = ['  <div class="dials">']
    first = True
    for skin, groups in scan_dials().items():
        cls = mt.SKIN_SCRIPTS[skin][0]
        count = sum(len(g["names"]) for g in groups)
        # 🔑 Collapse per skin — all three tables open at once is 32 rows, and on a phone the table stacks
        #    vertically so one row becomes three blocks: 96 blocks, roughly 2,900px, before the next piece
        #    of text (2026-09-16). Only the first skin is left open. Arriving at an anchor inside a
        #    collapsed table, `site/ux.js` opens it.
        parts.append('  <details class="dial-group"%s>' % (" open" if first else ""))
        parts.append("  <summary><h4>%s <code>%s</code> — %d</h4></summary>"
                     % (SKIN_TITLES[skin][lang], cls, count))
        first = False
        parts.append("  <table>")
        parts.append("    <thead>%s</thead>" % head)
        parts.append("    <tbody>")
        for group in groups:
            if lang == "en":
                descs = [DIALS_EN.get(n, "") for n in group["names"]]
                shared = len(set(descs)) == 1
            else:
                descs = [group["ko"]] * len(group["names"])
                shared = True
            for i, name in enumerate(group["names"]):
                value = group["values"][name]
                cell = ""
                if shared and i == 0:
                    cell = '<td rowspan="%d">%s</td>' % (len(group["names"]), _html_text(descs[0]) or "—") if len(group["names"]) > 1 else "<td>%s</td>" % (_html_text(descs[0]) or "—")
                elif not shared:
                    cell = "<td>%s</td>" % (_html_text(descs[i]) or "—")
                # `data-label` — the small label put in front so a bare number is not left stranded when
                # the table stacks vertically at phone width.
                label = "Default" if lang == "en" else "기본값"
                parts.append('      <tr><td><code>%s</code></td><td data-label="%s">%r</td>%s</tr>' % (name, label, value, cell))
        parts.append("    </tbody>")
        parts.append("  </table>")
        parts.append("  </details>")
    parts.append("  </div>")
    return "\n".join(parts)


DIALS_BEGIN = "<!-- dials:begin -->"
DIALS_END = "<!-- dials:end -->"


# 🔑 The dial table used to sit in the `own` section, and the 2026-09-16 split (`tools/split_site.py`)
#    moved that section into `theming-own.html`. 🛑 Fail to change the name here along with it and the
#    marker is never found, so **the old table quietly stays** — add a dial and the documentation does
#    not follow.
DIALS_PAGE = "theming-own.html"


def dials_page(lang="ko"):
    return os.path.join(WWW, site_langs.rel_path(lang, DIALS_PAGE))


def write_dials_section(lang="ko"):
    """Refill between the markers in `theming-own.html`. Without the markers, leave the file alone and return False."""
    path = dials_page(lang)
    if not os.path.isfile(path):
        return False
    text = open(path, encoding="utf-8").read()
    if DIALS_BEGIN not in text or DIALS_END not in text:
        print("🛑 no %s marker in %s — the dial table was not written" % (DIALS_BEGIN, os.path.relpath(path, ADDON)))
        return False
    before, rest = text.split(DIALS_BEGIN, 1)
    _old, after = rest.split(DIALS_END, 1)
    body = before + DIALS_BEGIN + "\n" + dials_html(lang) + "\n  " + DIALS_END + after
    if body != text:
        open(path, "w", encoding="utf-8").write(body)
    print("%s — %d dials in the table" % (os.path.relpath(path, ADDON), sum(len(g["names"]) for gs in scan_dials().values() for g in gs)))
    return True


def build(lang="ko"):
    glossary = {}
    if lang == "en":
        glossary.update(MANUAL_EN)
        glossary.update(scan_tokens(lang))
        glossary.update(scan_presets(lang))
        glossary.update(dial_terms(lang))
        # 🛑 Only classes with an English description go in — better absent than an English page popping up Korean.
        for name, entry in scan_classes().items():
            if name in CLASS_EN:
                out = {"d": CLASS_EN[name], "k": "gohud"}
                if entry.get("c"): out["c"] = entry["c"]
                glossary[name] = out
    else:
        glossary.update(MANUAL)
        glossary.update(scan_tokens())
        glossary.update(scan_presets())
        glossary.update(dial_terms())
        glossary.update(scan_classes())      # the source wins — it overrides anything written by hand
    # Where `u` is None, drop the key entirely (so the tooltip does not draw an empty link).
    for entry in glossary.values():
        if entry.get("u") is None:
            entry.pop("u", None)
        # 🛑 The bubble takes the description **verbatim** (`textContent`) — leave markdown in and
        #    `**rounded**` shows up exactly like that. What was extracted from the source is already
        #    clean; the hand-written glossaries are cleaned here.
        if "d" in entry:
            entry["d"] = re.sub(r"\*\*(.+?)\*\*", r"\1", entry["d"])
            entry["d"] = re.sub(r"`(.+?)`", r"\1", entry["d"])
    os.makedirs(SITE, exist_ok=True)
    path = os.path.join(SITE, "glossary.js" if lang == "ko" else "glossary.%s.js" % lang)
    body = json.dumps(glossary, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("/* gohud glossary — generated by tools/make_site.py. Do not edit by hand. */\n")
        fh.write("window.GLOSSARY=" + body + ";\n")
    print("%s — %d terms" % (os.path.relpath(path, ADDON), len(glossary)))
    return glossary


# ── The language picker and hreflang ──────────────────────────────────
# 🔑 17 languages × 3 pages = 51 files. Putting the picker and the hreflang tags in by hand always leaves
#    a file or two out of step, and **out of step still looks fine on screen** (one link goes to the wrong
#    language, or search engines treat the translations as strangers to each other). So, as with the dial
#    table, the space between the markers is filled here.
LANGS_BEGIN = "<!-- langs:begin -->"
LANGS_END = "<!-- langs:end -->"
HREFLANG_BEGIN = "<!-- hreflang:begin -->"
HREFLANG_END = "<!-- hreflang:end -->"


def replace_marked(text, begin, end, body, tail=""):
    """Swap out what lies between the markers — return None when they are missing (the caller reports it)."""
    if begin not in text or end not in text:
        return None
    before, rest = text.split(begin, 1)
    _old, after = rest.split(end, 1)
    return before + begin + "\n" + body + "\n" + tail + end + after


def langs_html(code, page):
    """A picker showing only the current language until pressed, then all 17 **each in its own language**."""
    rows = ['          <a href="%s" hreflang="%s" lang="%s"%s>%s</a>' % (
        site_langs.link_from(code, lang.code, page), lang.hreflang, lang.html_lang,
        ' aria-current="true"' if lang.code == code else "", lang.name) for lang in site_langs.ACTIVE]
    return ('      <details class="langs">\n'
            '        <summary>%s</summary>\n'
            '        <div class="langs-list">\n%s\n        </div>\n'
            '      </details>' % (site_langs.BY_CODE[code].name, "\n".join(rows)))


def hreflang_html(page):
    """Tell search engines about "other language editions of the same page". The fallback (x-default) is English."""
    rows = ['<link rel="alternate" hreflang="%s" href="%s">' % (lang.hreflang, site_langs.public_url(lang.code, page))
            for lang in site_langs.ACTIVE]
    rows.append('<link rel="alternate" hreflang="x-default" href="%s">' % site_langs.public_url("en", page))
    return "\n".join(rows)


def write_langs():
    """Rewrite the picker and the hreflang tags in every language edition that exists. Untranslated languages are skipped."""
    done, missing = 0, []
    for lang in site_langs.ACTIVE:
        for page in site_langs.PAGES:
            rel = site_langs.rel_path(lang.code, page)
            path = os.path.join(WWW, rel)
            if not os.path.isfile(path):
                missing.append(rel)
                continue
            text = open(path, encoding="utf-8").read()
            body = replace_marked(text, HREFLANG_BEGIN, HREFLANG_END, hreflang_html(page))
            if body is None:
                print("🛑 no %s marker in %s — hreflang was not written" % (HREFLANG_BEGIN, rel))
                continue
            body = replace_marked(body, LANGS_BEGIN, LANGS_END, langs_html(lang.code, page), "      ")
            if body is None:
                print("🛑 no %s marker in %s — the language picker was not written" % (LANGS_BEGIN, rel))
                continue
            if body != text:
                open(path, "w", encoding="utf-8").write(body)
            done += 1
    print("Language picker · hreflang — %d pages%s" % (done, " · %d language editions still missing" % len(missing) if missing else ""))
    return done


# ── Heading anchors ───────────────────────────────────────────────────
# 🔑 Neither the sidebar nor the search can be built without **an address that takes you to the spot**.
#    Not one heading on this site had an id, so entries like `GoSlot` and `GoBar` could not even be
#    pointed at by URL (measured 2026-09-16: zero of them).
# 🛑 The ids are made from **the English headings** and given to the heading at the same position in every
#    language — the address has to stay the same across languages so that switching with the picker keeps
#    your place. Built from the translations, every language would get a different address.
HEADING = re.compile(r'<(h[34])(\s[^>]*?)?>(.*?)</\1>', re.S)


def heading_slug(html, used):
    """Make the name to use as an address out of one heading. Duplicates get a number appended."""
    plain = re.sub(r'&[a-z]+;|&#\d+;', " ", re.sub(r'<[^>]+>', "", html))
    name = re.sub(r'[^a-z0-9]+', "-", plain.lower()).strip("-")[:48].strip("-") or "h"
    base, n = name, 2
    while name in used:
        name, n = "%s-%d" % (base, n), n + 1
    used.add(name)
    return name


def heading_ids(page):
    """The ids taken from the English headings — every language edition of that page uses them in this order."""
    used = set()
    text = open(os.path.join(WWW, page), encoding="utf-8").read()
    return [heading_slug(m.group(3), used) for m in HEADING.finditer(text)]


def write_heading_ids():
    """Stamp the English-derived ids onto the h3·h4 of every language edition. Report any language whose heading count differs."""
    pages, mismatched = 0, []
    for page in site_langs.PAGES:
        ids = heading_ids(page)
        for lang in site_langs.ACTIVE:
            rel = site_langs.rel_path(lang.code, page)
            path = os.path.join(WWW, rel)
            if not os.path.isfile(path):
                continue
            text = open(path, encoding="utf-8").read()
            count = [0]

            def put(m):
                i = count[0]
                count[0] += 1
                if i >= len(ids):
                    return m.group(0)
                # 🛑 Any id already there is removed and reissued — the generator owns this attribute.
                attrs = re.sub(r'\s+id="[^"]*"', "", m.group(2) or "")
                return '<%s id="%s"%s>%s</%s>' % (m.group(1), ids[i], attrs, m.group(3), m.group(1))

            body = HEADING.sub(put, text)
            if count[0] != len(ids):
                mismatched.append("%s(%d≠%d)" % (rel, count[0], len(ids)))
            if body != text:
                open(path, "w", encoding="utf-8").write(body)
            pages += 1
    print("Heading anchors — %d pages%s" % (pages, " · 🛑 heading count differs in: " + ", ".join(mismatched) if mismatched else ""))
    return pages


def write_not_found_langs():
    """The language row in `404.html` — gives whoever landed on a dead address **a way to the docs in their own language**.

    🛑 This page loads neither the glossary nor the tooltip nor style.css (if those 404 too, nothing works
    at all). So it lists plain links rather than the picker.
    """
    path = os.path.join(WWW, "404.html")
    if not os.path.isfile(path):
        return False
    text = open(path, encoding="utf-8").read()
    links = ['    <a href="%s" hreflang="%s" lang="%s">%s</a>' %
             (site_langs.public_url(lang.code, "index.html"), lang.hreflang, lang.html_lang, lang.name)
             for lang in site_langs.ACTIVE]
    body = replace_marked(text, LANGS_BEGIN, LANGS_END, " ·\n".join(links), "    ")
    if body is None:
        print("🛑 no %s marker in 404.html — the language row was not written" % LANGS_BEGIN)
        return False
    if body != text:
        open(path, "w", encoding="utf-8").write(body)
    print("404.html — %d languages" % len(site_langs.ACTIVE))
    return True


# ── The header menu ───────────────────────────────────────────────────
# 🔑 Kept by hand across 85 files, the same spot drifted apart between languages — `www/ko/widgets.html`
#    alone was one entry short (`#messages` missing), and where 16 languages left `#factory` as
#    `GoStyle`, Korean alone had translated it. `check_site.py` only compares `<section id>`, so it
#    catches **none of this.** The menu was therefore moved from prose into generated output. The wording
#    lives in `tools/site_nav.py`.
NAV_BEGIN = "<!-- nav:begin -->"
NAV_END = "<!-- nav:end -->"


def write_nav():
    """Rewrite the header menu in every language edition.

    Without the markers, **once** it replaces everything between `<nav>` and the language picker and
    plants the markers there — and the old menu sitting in that spot (different on every page, with
    section anchors mixed in) disappears at that moment.
    """
    done, seeded = 0, 0
    for lang in site_langs.ACTIVE:
        for page in site_langs.PAGES:
            rel = site_langs.rel_path(lang.code, page)
            path = os.path.join(WWW, rel)
            if not os.path.isfile(path):
                continue
            text = open(path, encoding="utf-8").read()
            body = site_nav.nav_html(lang.code, page)
            if NAV_BEGIN in text and NAV_END in text:
                new = replace_marked(text, NAV_BEGIN, NAV_END, body, "      ")
            else:
                # The first time — everything from after `<nav>` to before the language picker is the old menu.
                head, rest = text.split("<nav>", 1)
                _old, rest = rest.split(LANGS_BEGIN, 1)
                new = "%s<nav>\n      %s\n%s\n      %s\n      %s%s" % (
                    head, NAV_BEGIN, body, NAV_END, LANGS_BEGIN, rest)
                seeded += 1
            if new != text:
                open(path, "w", encoding="utf-8").write(new)
            done += 1
    print("Header menu — %d pages%s" % (done, " · markers planted for the first time in %d" % seeded if seeded else ""))
    return done


# Scripts appended at the end of a page — the order is the execution order.
#   toc.js     the left-hand table of contents, built by reading the page's headings.
#   search.js  site-wide search: puts a search box in the header and answers the TOC's "search all" button.
#   ux.js      the copy-code button and lazy image loading.
# 🛑 All three carry their own translations — the only thing put into the 51 language editions is this
#    one `<script>` line.
PAGE_SCRIPTS = ("site/toc.js", "site/search.js", "site/ux.js")


def write_page_scripts():
    """Put the script lines into every page — already there, they are left alone."""
    added, touched = 0, 0
    for lang in site_langs.ACTIVE:
        for page in site_langs.PAGES:
            rel = site_langs.rel_path(lang.code, page)
            path = os.path.join(WWW, rel)
            if not os.path.isfile(path):
                continue
            text = open(path, encoding="utf-8").read()
            if "</body>" not in text:
                print("🛑 no </body> in %s — the scripts were not written" % rel)
                continue
            up = "../" if site_langs.BY_CODE[lang.code].folder else ""
            body = text
            for src in PAGE_SCRIPTS:
                if src in body:
                    continue
                body = body.replace("</body>", '<script src="%s%s"></script>\n</body>' % (up, src), 1)
                added += 1
            if body != text:
                open(path, "w", encoding="utf-8").write(body)
                touched += 1
    print("Page scripts — %d lines added across %d pages" % (added, touched))
    return added


if __name__ == "__main__":
    # 🛑 The order matters. `make_ai_page` **rewrites `ai.html` wholesale**, so it has to come **before**
    #    the heading anchors — put it after and it wipes the ids just stamped in, and `check_site.py`
    #    reports "differs from the source" (measured 2026-09-16: all 17 pages red).
    import make_ai_page
    make_ai_page.main()
    # 🛑 `icons.html` is rewritten wholesale too — before the heading anchors, for the same reason.
    import make_icons_page
    make_icons_page.main()
    build("ko")
    build("en")
    write_dials_section("ko")
    write_dials_section("en")
    write_nav()
    write_langs()
    write_not_found_langs()
    write_heading_ids()
    write_page_scripts()
    make_search.write_all()
