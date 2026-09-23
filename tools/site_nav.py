# -*- coding: utf-8 -*-
"""머리띠 메뉴와 새 쪽들의 말 — **여기 한 곳**에서 고른다.

`tools/make_site.py` 의 `write_nav()` 가 이 표로 85 장의 `<nav>` 를 다시 써넣는다.

## 왜 생성기로 옮겼나 (2026-09-16 사람 지적 → 실측)

메뉴를 51 장에 손으로 두었더니 **같은 자리가 언어마다 갈라졌다.** 실측:

- `www/ko/widgets.html` 만 메뉴가 **7 칸** — 다른 16 개 언어에 있는 `#messages` 가 통째로 빠졌다.
- `#factory` 를 16 개 언어는 `GoStyle` 로 두었는데 **한국어만 "팩토리"** 였다.
- `#tokens` 를 zh 는 `令牌`, zh-tw 는 `Token` 으로 옮겼다 — 같은 개념을 두 중국어판이 다르게 처리했다.
- 메뉴 구성 자체가 쪽마다 달랐다: `index` 는 앵커 6 + 쪽 2, `theming`·`widgets` 는 쪽 3 + 앵커 5.
  **`index` 에는 자기 자신(Overview)으로 가는 링크조차 없었다.**

`tools/check_site.py` 는 `<section id>` 구성만 견주므로 이 어긋남을 **하나도 잡지 못한다** — 쪽 안에서는
앞뒤가 맞아 끝까지 초록불이다. 그래서 메뉴는 사람이 쓰는 글이 아니라 **생성물**로 옮겼다.

## 메뉴에 무엇을 올리나 — 규칙 넷

- **R1. 머리띠에는 묶음의 표지만 올린다.** 그 아래 쪽들은 **왼쪽 사이드바**가 맡는다
  (`site/toc.js` 가 문서 안의 `<nav class="subnav">` 를 목차 맨 위로 올린다).
  머리띠에 열아홉 칸을 올리면 좁은 화면에서 줄이 넘치고, 지금 어느 묶음을 읽는지도 흐려진다.

  🛑 **2026-09-16, 이 자리에는 "절 단위로 더 쪼개지 않는다" 가 적혀 있었다.** 같은 말이
  `site/toc.js` 에도 있었고, 그 두 줄을 근거로 **"문서를 작게 나눠 달라" 는 사람의 요청이 여러 차례
  '이미 결정된 것' 으로 처리됐다.** 사람의 지시가 규칙 주석을 덮는다 — 쪽은 `tools/split_site.py`
  가 갈랐고(`widgets` 표지+8 · `theming` 표지+6), 목차와 가르기는 **서로를 대신하지 않는다**:
  목차는 한 쪽 안을 안내하고, 가르기는 쪽 자체를 줄인다.
  머리띠가 앵커 링크를 숨기는 규칙(`body.gotoc-on header.top nav a[href^="#"]{display:none}`)은
  그대로 둔다 — 머리띠에 앵커는 여전히 올리지 않는다.
- **R2. 독자가 코드에서 볼 문자열은 번역하지 않는다.** `HUD`·`GoStyle`·`Preset`·`Skin`·`Token`.
  16/17 개 언어가 이미 `GoStyle` 을, 17/17 이 `HUD` 를 그대로 두고 있었다 — 그 관행을 규칙으로 올린다.
- **R3. 제품 범주 이름은 그 언어에 자리 잡은 역어가 있으면 번역한다.** Widget(위젯·ウィジェット·控件),
  Overview, Install, Theming.
- **R4. 소유격·대명사를 메뉴에 쓰지 않는다.** "내 프리셋"(`Your preset`)·`Tu preajuste`·
  `Votre préréglage` 가 전부 같은 이유로 어색했다.

🛑 `Go HUD Skill` (the `ai.html` page — named `AI SKILL` until 2026-09-23, renamed at the owner's request)
stays **in English in all 17 languages**. It is the name of a product feature, and what that page teaches —
the commands (`/gohud:preview`), the folder (`skills/gohud`), the prompt to paste — is all English, so the
menu and the page must use the same words for readers to know they point at the same thing. The file name
stays `ai.html` so links already shared keep working.

## 각 표

`NAV`    Menu labels per language — six since 2026-09-23 (`icons`: the everyday word for "icons" in that language). 🔑 Overview·Install·Widgets·Theming 은 **이미 그 언어판에 있던 번역을
         그대로 옮겨 적은 것**이다 — 새로 지어낸 말이 아니다(ko 의 Theming 만 "생김새"→"테마").
`TITLE`  새 쪽의 `<title>`·`<h1>`·설명. 옛 세 쪽은 제 파일에 있는 것을 그대로 쓴다.
"""
from collections import OrderedDict

import site_langs

# 머리띠에 올리는 쪽 — 순서가 곧 화면 순서다. (키, 파일, 표에서 읽을 이름)
NAV_PAGES = (
    ("overview", "index.html"),
    ("install", "install.html"),
    ("ai", "ai.html"),
    ("widgets", "widgets.html"),
    ("theming", "theming.html"),
    ("icons", "icons.html"),
)

GITHUB = "https://github.com/thruthesky/gohud"

# Menu labels per language. 🛑 `ai` is the same "Go HUD Skill" in every language, so it is not in this table (AI_LABEL).
AI_LABEL = "Go HUD Skill"

NAV = {
    "en":    {"overview": "Overview",     "install": "Install",       "widgets": "Widgets",     "theming": "Theming", "icons": "Icons"},
    "ko":    {"overview": "소개",          "install": "설치",           "widgets": "위젯",        "theming": "테마", "icons": "아이콘"},
    "ja":    {"overview": "概要",          "install": "インストール",      "widgets": "ウィジェット",   "theming": "テーマ", "icons": "アイコン"},
    "zh":    {"overview": "概览",          "install": "安装",           "widgets": "控件",        "theming": "主题", "icons": "图标"},
    "zh-tw": {"overview": "總覽",          "install": "安裝",           "widgets": "控制項",      "theming": "佈景主題", "icons": "圖示"},
    "es":    {"overview": "Introducción", "install": "Instalación",   "widgets": "Widgets",     "theming": "Temas", "icons": "Iconos"},
    "pt":    {"overview": "Visão geral",  "install": "Instalação",    "widgets": "Widgets",     "theming": "Temas", "icons": "Ícones"},
    "ru":    {"overview": "Обзор",        "install": "Установка",     "widgets": "Виджеты",     "theming": "Темы", "icons": "Иконки"},
    "fr":    {"overview": "Aperçu",       "install": "Installation",  "widgets": "Widgets",     "theming": "Thématisation", "icons": "Icônes"},
    "tr":    {"overview": "Genel bakış",  "install": "Kurulum",       "widgets": "Widget'lar",  "theming": "Tema", "icons": "Simgeler"},
    "pl":    {"overview": "Przegląd",     "install": "Instalacja",    "widgets": "Widżety",     "theming": "Motywy", "icons": "Ikony"},
    "it":    {"overview": "Panoramica",   "install": "Installazione", "widgets": "Widget",      "theming": "Temi", "icons": "Icone"},
    "vi":    {"overview": "Tổng quan",    "install": "Cài đặt",       "widgets": "Widget",      "theming": "Theme", "icons": "Biểu tượng"},
    "id":    {"overview": "Ringkasan",    "install": "Instalasi",     "widgets": "Widget",      "theming": "Tema", "icons": "Ikon"},
    "uk":    {"overview": "Огляд",        "install": "Встановлення",  "widgets": "Віджети",     "theming": "Оформлення", "icons": "Іконки"},
    "th":    {"overview": "ภาพรวม",        "install": "ติดตั้ง",          "widgets": "วิดเจ็ต",      "theming": "ธีม", "icons": "ไอคอน"},
    "ar":    {"overview": "نظرة عامة",     "install": "التثبيت",        "widgets": "الودجات",      "theming": "السمات", "icons": "الأيقونات"},
}


def label(code, key):
    """한 언어의 메뉴 라벨. 모르는 언어는 영어로 떨어진다."""
    if key == "ai":
        return AI_LABEL
    return NAV.get(code, NAV["en"]).get(key, NAV["en"][key])


def nav_html(code, page, indent="      "):
    """그 언어·그 쪽의 머리띠 메뉴. 지금 보고 있는 쪽은 `aria-current` 로 표시한다.

    🔑 링크는 **같은 폴더 안의 상대 주소**다 — 언어판은 제 폴더 안에서 서로를 부르므로
    `../` 가 필요 없다(언어 고르개만 폴더를 건넌다).
    """
    # 🔑 갈린 쪽(`widgets-forms.html`)에서는 그 **표지 칸**(Widgets)이 켜져야 한다 —
    #    독자가 머리띠만 보고도 지금 어느 묶음 안에 있는지 안다. 표는 `site_langs.COVER_OF`.
    current = site_langs.COVER_OF.get(page, page)
    rows = []
    for key, file in NAV_PAGES:
        href = "./" if file == "index.html" else file
        here = ' aria-current="page"' if file == current else ""
        cls = ' class="nav-ai"' if key == "ai" else ""
        rows.append('%s<a%s href="%s"%s>%s</a>' % (indent, cls, href, here, label(code, key)))
    rows.append('%s<a href="%s">GitHub ↗</a>' % (indent, GITHUB))
    return "\n".join(rows)


# ── 새 쪽의 말 ────────────────────────────────────────────────────────
# `<title>` 은 "제목 — gohud" 로 맞춘다(옛 세 쪽의 관습). `lead` 는 쪽 머리의 한 문단이다.
TITLE = {
    "en": {
        "install_title": "Install gohud",
        "install_lead": "Two ways in. Let your AI agent do it, or drop the folder into your project — "
                        "there is nothing else to set up.",
        "install_desc": "How to install gohud in a Godot 4.6+ project — with an AI coding agent in one paste, "
                        "from a release ZIP, or as a git submodule.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud ships an AI skill: the whole API, runnable templates and a preview launcher. "
                   "Paste one block into your coding agent and it installs gohud and knows how to use it.",
        "ai_desc": "Install the gohud AI skill in Claude Code, Codex, Cursor, Gemini CLI or any coding agent — "
                   "one block to copy and paste.",
        "start_title": "Quick start",
        "start_lead": "Five lines put a themed screen on the display. See the whole walk-through on the install page.",
        "more": "Read the whole page",
    },
    "ko": {
        "install_title": "gohud 설치",
        "install_lead": "길은 둘이다. AI 에게 시키거나, 폴더를 프로젝트에 넣거나 — 그 밖에 설정할 것은 없다.",
        "install_desc": "Godot 4.6+ 프로젝트에 gohud 를 설치하는 법 — AI 코딩 에이전트에 한 번 붙여 넣기, "
                        "릴리스 ZIP, git 서브모듈.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud 에는 AI 스킬이 들어 있다 — API 전부와 바로 돌아가는 템플릿, 미리보기 실행기. "
                   "아래 글을 통째로 코딩 에이전트에 붙여 넣으면 gohud 를 설치하고 쓰는 법까지 익힌다.",
        "ai_desc": "Claude Code·Codex·Cursor·Gemini CLI 등 어떤 코딩 에이전트에도 gohud AI 스킬을 설치한다 — "
                   "복사해서 붙여 넣을 텍스트 하나.",
        "start_title": "빠른 시작",
        "start_lead": "다섯 줄이면 테마가 입혀진 화면이 뜬다. 처음부터 끝까지는 설치 페이지에 있다.",
        "more": "이 페이지 전부 읽기",
    },
    "ja": {
        "install_title": "gohud をインストール",
        "install_lead": "入口は二つ。AI エージェントに任せるか、フォルダーをプロジェクトに入れるか — "
                        "ほかに設定するものはない。",
        "install_desc": "Godot 4.6+ のプロジェクトに gohud を入れる方法 — AI コーディングエージェントに一度貼るだけ、"
                        "リリース ZIP、git サブモジュール。",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud には AI スキルが入っている — API のすべて、すぐ動くテンプレート、プレビュー起動器。"
                   "下の文をまるごとコーディングエージェントに貼れば、gohud を入れて使い方まで覚える。",
        "ai_desc": "Claude Code・Codex・Cursor・Gemini CLI など、どのコーディングエージェントにも gohud の "
                   "AI スキルを入れる — コピーして貼るだけのテキスト。",
        "start_title": "クイックスタート",
        "start_lead": "五行でテーマの当たった画面が出る。最初から最後までは、インストールのページに。",
        "more": "このページを全部読む",
    },
    "zh": {
        "install_title": "安装 gohud",
        "install_lead": "两条路：让 AI 代理替你装，或把文件夹放进项目 —— 此外无需任何配置。",
        "install_desc": "在 Godot 4.6+ 项目中安装 gohud 的方法 —— 向 AI 编码代理粘贴一次、发行版 ZIP、git 子模块。",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud 自带 AI 技能：完整 API、可直接运行的模板和预览启动器。"
                   "把下面这一段粘贴给你的编码代理，它就会装好 gohud 并知道怎么用。",
        "ai_desc": "为 Claude Code、Codex、Cursor、Gemini CLI 等任意编码代理安装 gohud AI 技能 —— 复制粘贴一段即可。",
        "start_title": "快速上手",
        "start_lead": "五行代码就能显示一个带主题的界面。完整流程见安装页。",
        "more": "读完整页",
    },
    "zh-tw": {
        "install_title": "安裝 gohud",
        "install_lead": "兩條路：讓 AI 代理替你裝，或把資料夾放進專案 —— 此外不必設定任何東西。",
        "install_desc": "在 Godot 4.6+ 專案中安裝 gohud 的方法 —— 向 AI 編碼代理貼上一次、發行版 ZIP、git 子模組。",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud 內建 AI 技能：完整 API、可直接執行的範本與預覽啟動器。"
                   "把下面這一段貼給你的編碼代理，它就會裝好 gohud 並知道怎麼用。",
        "ai_desc": "為 Claude Code、Codex、Cursor、Gemini CLI 等任何編碼代理安裝 gohud AI 技能 —— 複製貼上一段即可。",
        "start_title": "快速上手",
        "start_lead": "五行程式碼就能顯示帶佈景主題的畫面。完整流程請見安裝頁。",
        "more": "讀完整頁",
    },
    "es": {
        "install_title": "Instalar gohud",
        "install_lead": "Dos caminos. Que lo haga tu agente de IA, o suelta la carpeta en tu proyecto — "
                        "no hay nada más que configurar.",
        "install_desc": "Cómo instalar gohud en un proyecto de Godot 4.6+ — con un agente de IA en un solo pegado, "
                        "desde un ZIP de la versión o como submódulo de git.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud trae una skill de IA: toda la API, plantillas listas para ejecutar y un lanzador de "
                   "vista previa. Pega un bloque en tu agente y él instala gohud y sabe usarlo.",
        "ai_desc": "Instala la skill de IA de gohud en Claude Code, Codex, Cursor, Gemini CLI o cualquier agente — "
                   "un bloque para copiar y pegar.",
        "start_title": "Inicio rápido",
        "start_lead": "Cinco líneas ponen una pantalla con tema en el display. El recorrido completo está en la página de instalación.",
        "more": "Leer la página entera",
    },
    "pt": {
        "install_title": "Instalar o gohud",
        "install_lead": "Dois caminhos. Deixe o seu agente de IA fazer, ou solte a pasta no seu projeto — "
                        "não há mais nada para configurar.",
        "install_desc": "Como instalar o gohud num projeto Godot 4.6+ — com um agente de IA numa única colagem, "
                        "a partir de um ZIP da versão ou como submódulo git.",
        "ai_title": AI_LABEL,
        "ai_lead": "O gohud traz uma skill de IA: toda a API, modelos prontos a correr e um lançador de "
                   "pré-visualização. Cole um bloco no seu agente e ele instala o gohud e sabe usá-lo.",
        "ai_desc": "Instale a skill de IA do gohud no Claude Code, Codex, Cursor, Gemini CLI ou qualquer agente — "
                   "um bloco para copiar e colar.",
        "start_title": "Início rápido",
        "start_lead": "Cinco linhas colocam um ecrã com tema no visor. O percurso completo está na página de instalação.",
        "more": "Ler a página inteira",
    },
    "ru": {
        "install_title": "Установка gohud",
        "install_lead": "Два пути. Поручите ИИ-агенту или положите папку в проект — больше настраивать нечего.",
        "install_desc": "Как установить gohud в проект Godot 4.6+ — одной вставкой в ИИ-агента, из ZIP-архива "
                        "релиза или как подмодуль git.",
        "ai_title": AI_LABEL,
        "ai_lead": "В gohud входит ИИ-навык: весь API, готовые шаблоны и запуск предпросмотра. "
                   "Вставьте один блок в своего агента — он установит gohud и будет знать, как им пользоваться.",
        "ai_desc": "Установите ИИ-навык gohud в Claude Code, Codex, Cursor, Gemini CLI или любой агент — "
                   "один блок, который нужно скопировать и вставить.",
        "start_title": "Быстрый старт",
        "start_lead": "Пять строк выводят экран с темой. Полное прохождение — на странице установки.",
        "more": "Читать всю страницу",
    },
    "fr": {
        "install_title": "Installer gohud",
        "install_lead": "Deux chemins. Laissez votre agent IA le faire, ou déposez le dossier dans votre projet — "
                        "il n'y a rien d'autre à configurer.",
        "install_desc": "Comment installer gohud dans un projet Godot 4.6+ — avec un agent IA en un seul collage, "
                        "depuis un ZIP de version ou en sous-module git.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud embarque une compétence IA : toute l'API, des modèles exécutables et un lanceur "
                   "d'aperçu. Collez un bloc dans votre agent : il installe gohud et sait s'en servir.",
        "ai_desc": "Installez la compétence IA de gohud dans Claude Code, Codex, Cursor, Gemini CLI ou tout "
                   "agent — un bloc à copier-coller.",
        "start_title": "Démarrage rapide",
        "start_lead": "Cinq lignes affichent un écran thématisé. Le parcours complet est sur la page d'installation.",
        "more": "Lire toute la page",
    },
    "tr": {
        "install_title": "gohud kurulumu",
        "install_lead": "İki yol var. Yapay zekâ ajanınıza yaptırın ya da klasörü projenize bırakın — "
                        "başka ayarlanacak bir şey yok.",
        "install_desc": "gohud'u bir Godot 4.6+ projesine kurma yolları — yapay zekâ ajanına tek yapıştırma, "
                        "sürüm ZIP'i ya da git alt modülü.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud bir yapay zekâ becerisiyle gelir: API'nin tamamı, çalışmaya hazır şablonlar ve "
                   "önizleme başlatıcı. Tek bloğu ajanınıza yapıştırın; gohud'u kurar ve nasıl kullanacağını bilir.",
        "ai_desc": "gohud yapay zekâ becerisini Claude Code, Codex, Cursor, Gemini CLI ya da herhangi bir ajana "
                   "kurun — kopyalayıp yapıştıracağınız tek blok.",
        "start_title": "Hızlı başlangıç",
        "start_lead": "Beş satır, temalı bir ekranı gösterir. Baştan sona anlatım kurulum sayfasında.",
        "more": "Sayfanın tamamını oku",
    },
    "pl": {
        "install_title": "Instalacja gohud",
        "install_lead": "Dwie drogi. Niech zrobi to twój agent AI albo wrzuć folder do projektu — "
                        "nie ma nic więcej do ustawienia.",
        "install_desc": "Jak zainstalować gohud w projekcie Godot 4.6+ — jednym wklejeniem do agenta AI, "
                        "z ZIP-a wydania albo jako submoduł gita.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud zawiera umiejętność AI: całe API, gotowe do uruchomienia szablony i podgląd. "
                   "Wklej jeden blok do swojego agenta — zainstaluje gohud i będzie wiedział, jak go używać.",
        "ai_desc": "Zainstaluj umiejętność AI gohud w Claude Code, Codex, Cursor, Gemini CLI lub dowolnym "
                   "agencie — jeden blok do skopiowania i wklejenia.",
        "start_title": "Szybki start",
        "start_lead": "Pięć linii wyświetla ekran z motywem. Cała droga jest na stronie instalacji.",
        "more": "Przeczytaj całą stronę",
    },
    "it": {
        "install_title": "Installare gohud",
        "install_lead": "Due strade. Falla fare al tuo agente IA, oppure metti la cartella nel progetto — "
                        "non c'è altro da configurare.",
        "install_desc": "Come installare gohud in un progetto Godot 4.6+ — con un agente IA in un solo incolla, "
                        "da uno ZIP della release o come sottomodulo git.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud include una skill IA: tutta l'API, modelli pronti all'uso e un avviatore di anteprima. "
                   "Incolla un blocco nel tuo agente: installa gohud e sa come usarlo.",
        "ai_desc": "Installa la skill IA di gohud in Claude Code, Codex, Cursor, Gemini CLI o in qualsiasi "
                   "agente — un blocco da copiare e incollare.",
        "start_title": "Avvio rapido",
        "start_lead": "Cinque righe mettono a schermo una schermata con il tema. Il percorso completo è nella pagina di installazione.",
        "more": "Leggi tutta la pagina",
    },
    "vi": {
        "install_title": "Cài đặt gohud",
        "install_lead": "Hai lối vào. Để tác nhân AI làm hộ, hoặc thả thư mục vào dự án — không còn gì phải cấu hình.",
        "install_desc": "Cách cài gohud vào dự án Godot 4.6+ — dán một lần cho tác nhân AI, từ ZIP bản phát hành, "
                        "hoặc làm submodule git.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud có sẵn một AI skill: toàn bộ API, mẫu chạy được ngay và trình mở xem trước. "
                   "Dán một khối dưới đây vào tác nhân lập trình của bạn, nó sẽ cài gohud và biết cách dùng.",
        "ai_desc": "Cài AI skill của gohud vào Claude Code, Codex, Cursor, Gemini CLI hay bất kỳ tác nhân nào — "
                   "một khối để chép và dán.",
        "start_title": "Bắt đầu nhanh",
        "start_lead": "Năm dòng là có một màn hình đã gắn theme. Toàn bộ các bước nằm ở trang cài đặt.",
        "more": "Đọc trọn trang",
    },
    "id": {
        "install_title": "Memasang gohud",
        "install_lead": "Dua jalan. Serahkan pada agen AI, atau letakkan foldernya di proyekmu — "
                        "tidak ada lagi yang perlu diatur.",
        "install_desc": "Cara memasang gohud di proyek Godot 4.6+ — sekali tempel ke agen AI, dari ZIP rilis, "
                        "atau sebagai submodul git.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud membawa AI skill: seluruh API, templat siap jalan, dan peluncur pratinjau. "
                   "Tempelkan satu blok ke agen codingmu — ia memasang gohud dan tahu cara memakainya.",
        "ai_desc": "Pasang AI skill gohud di Claude Code, Codex, Cursor, Gemini CLI, atau agen apa pun — "
                   "satu blok untuk disalin dan ditempel.",
        "start_title": "Mulai cepat",
        "start_lead": "Lima baris menampilkan layar bertema. Langkah lengkapnya ada di halaman pemasangan.",
        "more": "Baca seluruh halaman",
    },
    "uk": {
        "install_title": "Встановлення gohud",
        "install_lead": "Два шляхи. Доручіть ШІ-агенту або покладіть теку у свій проєкт — більше нічого налаштовувати.",
        "install_desc": "Як встановити gohud у проєкт Godot 4.6+ — одним вставленням у ШІ-агента, із ZIP-архіву "
                        "випуску або як підмодуль git.",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud має ШІ-навичку: увесь API, готові до запуску шаблони та запуск попереднього перегляду. "
                   "Вставте один блок у свого агента — він встановить gohud і знатиме, як ним користуватися.",
        "ai_desc": "Встановіть ШІ-навичку gohud у Claude Code, Codex, Cursor, Gemini CLI чи будь-який агент — "
                   "один блок, який треба скопіювати та вставити.",
        "start_title": "Швидкий старт",
        "start_lead": "П'ять рядків виводять екран з темою. Повний шлях — на сторінці встановлення.",
        "more": "Читати всю сторінку",
    },
    "th": {
        "install_title": "ติดตั้ง gohud",
        "install_lead": "มีสองทาง ให้เอเจนต์ AI ทำให้ หรือวางโฟลเดอร์ลงในโปรเจกต์ของคุณ — ไม่มีอะไรต้องตั้งค่าเพิ่ม",
        "install_desc": "วิธีติดตั้ง gohud ในโปรเจกต์ Godot 4.6+ — วางครั้งเดียวให้เอเจนต์ AI จาก ZIP ของรุ่น "
                        "หรือเป็น submodule ของ git",
        "ai_title": AI_LABEL,
        "ai_lead": "gohud มี AI skill มาให้ — API ทั้งหมด เทมเพลตที่รันได้ทันที และตัวเปิดพรีวิว "
                   "วางบล็อกเดียวด้านล่างให้เอเจนต์เขียนโค้ดของคุณ แล้วมันจะติดตั้ง gohud และรู้วิธีใช้",
        "ai_desc": "ติดตั้ง AI skill ของ gohud ใน Claude Code, Codex, Cursor, Gemini CLI หรือเอเจนต์ใด ๆ — "
                   "บล็อกเดียวสำหรับคัดลอกและวาง",
        "start_title": "เริ่มใช้งาน",
        "start_lead": "ห้าบรรทัดก็ได้หน้าจอที่ใส่ธีมแล้ว ขั้นตอนทั้งหมดอยู่ในหน้าติดตั้ง",
        "more": "อ่านทั้งหน้า",
    },
    "ar": {
        "install_title": "تثبيت gohud",
        "install_lead": "طريقان. دع وكيل الذكاء الاصطناعي يقوم بذلك، أو ضع المجلد في مشروعك — "
                        "لا شيء آخر يحتاج إلى إعداد.",
        "install_desc": "كيفية تثبيت gohud في مشروع Godot 4.6+ — بلصقة واحدة في وكيل ذكاء اصطناعي، من ملف ZIP "
                        "للإصدار، أو كوحدة git فرعية.",
        "ai_title": AI_LABEL,
        "ai_lead": "يأتي gohud بمهارة ذكاء اصطناعي: واجهة البرمجة كاملة، وقوالب جاهزة للتشغيل، ومشغّل معاينة. "
                   "الصق الكتلة أدناه في وكيل البرمجة لديك فيثبّت gohud ويعرف كيف يستخدمه.",
        "ai_desc": "ثبّت مهارة gohud للذكاء الاصطناعي في Claude Code أو Codex أو Cursor أو Gemini CLI أو أي "
                   "وكيل — كتلة واحدة تنسخها وتلصقها.",
        "start_title": "بداية سريعة",
        "start_lead": "خمسة أسطر تضع شاشة بسمة جاهزة على العرض. الشرح كاملاً في صفحة التثبيت.",
        "more": "اقرأ الصفحة كاملة",
    },
}


def text(code, key):
    """새 쪽의 말 한 토막. 모르는 언어는 영어로 떨어진다."""
    return TITLE.get(code, TITLE["en"]).get(key, TITLE["en"][key])
