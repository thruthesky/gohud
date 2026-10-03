# -*- coding: utf-8 -*-
"""The **All widgets** page — every gohud widget and layout by name, each with an example, in all 17 languages.

    python3 addons/gohud/tools/site_catalog.py     # writes www/widgets-catalog.html and its 16 translations
    python3 addons/gohud/tools/make_site.py        # then: header menu, language picker, hreflang, anchors, search

## Why a generator
The page is a long list in seventeen languages. Kept by hand, one language would miss the widget added last — the
same drift the header menu had before `site_nav.py` (2026-09-16). Here a widget is **one line**: its name, the class it
extends, an example, and its sentence in every language. The example is shared, because code is code in every
language; `tools/check_docs_api.py` checks every call in it against the real classes.

## What it writes
- `widgets-catalog.html` in every language folder, built on that language's `widgets-shapes.html` (so the header,
  footer note and scripts are the ones that language already uses).
- A link to it in the side menu (`subnav`) of every widgets page, right after the cover.
- A card for it at the front of every `widgets.html` cover.
Running it again rewrites the page and leaves the menu and the card as they are.

- The AI skill's index of the same list, in English: `skills/gohud/references/catalog.md` — each entry with a pointer
  to the reference section that has its member table (found in the skill's references, `DETAILS` overrides).

    python3 addons/gohud/tools/site_catalog.py --check    # exit 1 when catalog.md is not what this list makes

🛑 Add a widget here when it ships — the page and the skill both claim to list every one.
"""
import html
import os
import re
import sys

import site_langs
import site_nav

HERE = os.path.dirname(os.path.abspath(__file__))
WWW = os.path.normpath(os.path.join(HERE, "..", "www"))
SKILL_REFS = os.path.normpath(os.path.join(HERE, "..", "skills", "gohud", "references"))
SKILL_CATALOG = os.path.join(SKILL_REFS, "catalog.md")
PAGE = "widgets-catalog.html"
TEMPLATE = "widgets-shapes.html"

# The 17 languages in `site_langs.LANGS` order — every text below lists its translations in this order.
CODES = [lang.code for lang in site_langs.LANGS]


def T(*texts):
	"""One text in every language, given in `CODES` order."""
	assert len(texts) == len(CODES), "%d translations for %d languages: %s" % (len(texts), len(CODES), texts[0])
	return dict(zip(CODES, texts))


TEXT = {
	"label": T("All widgets", "모든 위젯", "すべてのウィジェット", "全部控件", "所有控制項", "Todos los widgets",
		"Todos os widgets", "Все виджеты", "Tous les widgets", "Tüm widget'lar", "Wszystkie widżety", "Tutti i widget",
		"Tất cả widget", "Semua widget", "Усі віджети", "วิดเจ็ตทั้งหมด", "كل الودجات"),
	"lead": T(
		"Every widget and layout gohud has, by name, with an example to paste. Each one takes the active preset's look.",
		"gohud 의 모든 위젯과 레이아웃을 이름과 붙여 넣을 수 있는 예제로 모았다. 모두 지금 고른 프리셋의 모양을 따른다.",
		"gohud のすべてのウィジェットとレイアウトを、名前と貼り付けて使える例で一覧にしました。どれも選んだプリセットの見た目になります。",
		"gohud 的全部控件与布局，按名称列出，并附可直接粘贴的示例。每一个都采用当前预设的外观。",
		"gohud 的所有控制項與版面配置，依名稱列出，並附可直接貼上的範例。每一個都會套用目前預設的外觀。",
		"Todos los widgets y diseños de gohud, por nombre, con un ejemplo para pegar. Cada uno toma el aspecto del preajuste activo.",
		"Todos os widgets e layouts do gohud, por nome, com um exemplo para colar. Cada um assume a aparência do preset ativo.",
		"Все виджеты и компоновки gohud по названиям, с примером, который можно вставить. Каждый принимает вид текущего пресета.",
		"Tous les widgets et mises en page de gohud, par nom, avec un exemple à coller. Chacun prend l'apparence du préréglage actif.",
		"gohud'un tüm widget ve yerleşimleri, adlarıyla ve yapıştırılabilir bir örnekle. Her biri etkin hazır ayarın görünümünü alır.",
		"Wszystkie widżety i układy gohud według nazw, z przykładem do wklejenia. Każdy przyjmuje wygląd aktywnego presetu.",
		"Tutti i widget e i layout di gohud, per nome, con un esempio da incollare. Ognuno prende l'aspetto del preset attivo.",
		"Mọi widget và bố cục của gohud theo tên, kèm ví dụ để dán. Mỗi cái đều theo giao diện của preset đang dùng.",
		"Semua widget dan tata letak gohud menurut nama, dengan contoh siap tempel. Masing-masing mengikuti tampilan preset yang aktif.",
		"Усі віджети й компонування gohud за назвами, з прикладом, який можна вставити. Кожен бере вигляд активного пресету.",
		"วิดเจ็ตและเลย์เอาต์ทั้งหมดของ gohud ตามชื่อ พร้อมตัวอย่างที่วางใช้ได้ทันที ทุกตัวใช้รูปลักษณ์ของพรีเซ็ตที่เลือกอยู่",
		"كل ودجات gohud وتخطيطاته بأسمائها، مع مثال جاهز للصق. يأخذ كل منها مظهر الإعداد المسبق النشط."),
	"desc": T(
		"Every gohud widget and layout by name — layouts, windows, messages, navigation, buttons, inputs, pickers, lists and HUD — each with a GDScript example.",
		"gohud 의 모든 위젯과 레이아웃 — 레이아웃·창·알림·내비게이션·버튼·입력·선택기·목록·HUD — 을 이름과 GDScript 예제로.",
		"gohud のすべてのウィジェットとレイアウト — レイアウト、ウィンドウ、メッセージ、ナビゲーション、ボタン、入力、ピッカー、リスト、HUD — を名前と GDScript の例で。",
		"gohud 的全部控件与布局——布局、窗口、消息、导航、按钮、输入、选择器、列表与 HUD——按名称列出并附 GDScript 示例。",
		"gohud 的所有控制項與版面配置——版面、視窗、訊息、導覽、按鈕、輸入、選擇器、清單與 HUD——依名稱列出並附 GDScript 範例。",
		"Todos los widgets y diseños de gohud por nombre — diseño, ventanas, mensajes, navegación, botones, entradas, selectores, listas y HUD —, cada uno con un ejemplo en GDScript.",
		"Todos os widgets e layouts do gohud por nome — layout, janelas, mensagens, navegação, botões, entradas, seletores, listas e HUD —, cada um com um exemplo em GDScript.",
		"Все виджеты и компоновки gohud по названиям — компоновка, окна, сообщения, навигация, кнопки, ввод, выбор, списки и HUD — с примером на GDScript.",
		"Tous les widgets et mises en page de gohud par nom — mise en page, fenêtres, messages, navigation, boutons, saisie, sélecteurs, listes et HUD —, chacun avec un exemple GDScript.",
		"gohud'un tüm widget ve yerleşimleri adlarıyla — yerleşim, pencereler, mesajlar, gezinti, düğmeler, girişler, seçiciler, listeler ve HUD — her biri GDScript örneğiyle.",
		"Wszystkie widżety i układy gohud według nazw — układ, okna, komunikaty, nawigacja, przyciski, pola, selektory, listy i HUD — każdy z przykładem w GDScript.",
		"Tutti i widget e i layout di gohud per nome — layout, finestre, messaggi, navigazione, pulsanti, input, selettori, elenchi e HUD — ognuno con un esempio GDScript.",
		"Mọi widget và bố cục của gohud theo tên — bố cục, cửa sổ, thông báo, điều hướng, nút, nhập liệu, bộ chọn, danh sách và HUD — mỗi cái kèm ví dụ GDScript.",
		"Semua widget dan tata letak gohud menurut nama — tata letak, jendela, pesan, navigasi, tombol, input, pemilih, daftar, dan HUD — masing-masing dengan contoh GDScript.",
		"Усі віджети й компонування gohud за назвами — компонування, вікна, повідомлення, навігація, кнопки, введення, вибір, списки та HUD — кожен із прикладом на GDScript.",
		"วิดเจ็ตและเลย์เอาต์ทั้งหมดของ gohud ตามชื่อ — เลย์เอาต์ หน้าต่าง ข้อความ การนำทาง ปุ่ม ช่องกรอก ตัวเลือก รายการ และ HUD — พร้อมตัวอย่าง GDScript",
		"كل ودجات gohud وتخطيطاته بأسمائها — التخطيط والنوافذ والرسائل والتنقل والأزرار والإدخال والمنتقيات والقوائم وواجهة HUD — مع مثال GDScript لكل منها."),
	"card": T(
		"Every widget and layout by name, each with an example.",
		"모든 위젯과 레이아웃을 이름과 예제로.",
		"すべてのウィジェットとレイアウトを名前と例で。",
		"全部控件与布局，按名称列出并附示例。",
		"所有控制項與版面配置，依名稱列出並附範例。",
		"Todos los widgets y diseños por nombre, cada uno con un ejemplo.",
		"Todos os widgets e layouts por nome, cada um com um exemplo.",
		"Все виджеты и компоновки по названиям, каждый с примером.",
		"Tous les widgets et mises en page par nom, chacun avec un exemple.",
		"Tüm widget ve yerleşimler adlarıyla, her biri bir örnekle.",
		"Wszystkie widżety i układy według nazw, każdy z przykładem.",
		"Tutti i widget e i layout per nome, ognuno con un esempio.",
		"Mọi widget và bố cục theo tên, mỗi cái kèm ví dụ.",
		"Semua widget dan tata letak menurut nama, masing-masing dengan contoh.",
		"Усі віджети й компонування за назвами, кожен із прикладом.",
		"วิดเจ็ตและเลย์เอาต์ทั้งหมดตามชื่อ พร้อมตัวอย่าง",
		"كل الودجات والتخطيطات بأسمائها، مع مثال لكل منها."),
	"extends": T("extends", "바탕", "継承", "继承", "繼承", "extiende", "estende", "наследует", "étend", "türetildiği",
		"rozszerza", "estende", "kế thừa", "turunan", "успадковує", "สืบทอดจาก", "يرث"),
	# A factory or a method (`GoStyle.button`, `GoDialogs.choose`) belongs to its class — it does not extend it.
	"member": T("a function of", "소속", "所属", "所属", "所屬", "función de", "função de", "функция класса", "fonction de",
		"ait olduğu sınıf", "funkcja klasy", "funzione di", "hàm của", "fungsi dari", "функція класу", "ฟังก์ชันของ",
		"دالة من"),
}

GROUPS = [
	("layout", T("Layout", "레이아웃", "レイアウト", "布局", "版面配置", "Diseño", "Layout", "Компоновка", "Mise en page",
		"Yerleşim", "Układ", "Layout", "Bố cục", "Tata letak", "Компонування", "เลย์เอาต์", "التخطيط")),
	("windows", T("Windows and overlays", "창과 오버레이", "ウィンドウとオーバーレイ", "窗口与浮层", "視窗與浮層",
		"Ventanas y superposiciones", "Janelas e sobreposições", "Окна и оверлеи", "Fenêtres et superpositions",
		"Pencereler ve katmanlar", "Okna i nakładki", "Finestre e sovrapposizioni", "Cửa sổ và lớp phủ", "Jendela dan lapisan",
		"Вікна та оверлеї", "หน้าต่างและโอเวอร์เลย์", "النوافذ والطبقات")),
	("messages", T("Messages and waiting", "알림과 기다림", "メッセージと待機", "消息与等待", "訊息與等待", "Mensajes y espera",
		"Mensagens e espera", "Сообщения и ожидание", "Messages et attente", "Mesajlar ve bekleme", "Komunikaty i oczekiwanie",
		"Messaggi e attesa", "Thông báo và chờ đợi", "Pesan dan menunggu", "Повідомлення й очікування", "ข้อความและการรอ",
		"الرسائل والانتظار")),
	("navigation", T("App navigation", "앱 내비게이션", "アプリのナビゲーション", "应用导航", "App 導覽", "Navegación de la app",
		"Navegação do app", "Навигация в приложении", "Navigation de l'app", "Uygulama gezintisi", "Nawigacja w aplikacji",
		"Navigazione dell'app", "Điều hướng ứng dụng", "Navigasi aplikasi", "Навігація в застосунку", "การนำทางในแอป",
		"التنقل في التطبيق")),
	("buttons", T("Buttons, chips and choices", "버튼·칩·선택", "ボタン・チップ・選択", "按钮、标签与选择", "按鈕、標籤與選擇",
		"Botones, chips y opciones", "Botões, chips e escolhas", "Кнопки, чипы и выбор", "Boutons, puces et choix",
		"Düğmeler, çipler ve seçimler", "Przyciski, chipy i wybór", "Pulsanti, chip e scelte", "Nút, chip và lựa chọn",
		"Tombol, chip, dan pilihan", "Кнопки, чипи та вибір", "ปุ่ม ชิป และตัวเลือก", "الأزرار والرقائق والاختيارات")),
	("inputs", T("Inputs and pickers", "입력과 선택기", "入力とピッカー", "输入与选择器", "輸入與選擇器", "Entradas y selectores",
		"Entradas e seletores", "Ввод и выбор", "Saisie et sélecteurs", "Girişler ve seçiciler", "Pola i selektory",
		"Input e selettori", "Nhập liệu và bộ chọn", "Input dan pemilih", "Введення та вибір", "ช่องกรอกและตัวเลือก",
		"الإدخال والمنتقيات")),
	("lists", T("Lists, cards and data", "목록·카드·데이터", "リスト・カード・データ", "列表、卡片与数据", "清單、卡片與資料",
		"Listas, tarjetas y datos", "Listas, cartões e dados", "Списки, карточки и данные", "Listes, cartes et données",
		"Listeler, kartlar ve veriler", "Listy, karty i dane", "Elenchi, schede e dati", "Danh sách, thẻ và dữ liệu",
		"Daftar, kartu, dan data", "Списки, картки та дані", "รายการ การ์ด และข้อมูล", "القوائم والبطاقات والبيانات")),
	("hud", T("HUD and game shapes", "HUD 와 게임 모양", "HUD とゲームの形", "HUD 与游戏组件", "HUD 與遊戲元件",
		"HUD y formas de juego", "HUD e formas de jogo", "HUD и игровые элементы", "HUD et formes de jeu",
		"HUD ve oyun biçimleri", "HUD i elementy gier", "HUD e forme da gioco", "HUD và thành phần game",
		"HUD dan bentuk game", "HUD та ігрові елементи", "HUD และรูปแบบในเกม", "واجهة HUD وأشكال الألعاب")),
	("look", T("Looks and system", "모양과 시스템", "見た目とシステム", "外观与系统", "外觀與系統", "Apariencia y sistema",
		"Aparência e sistema", "Внешний вид и система", "Apparence et système", "Görünüm ve sistem", "Wygląd i system",
		"Aspetto e sistema", "Giao diện và hệ thống", "Tampilan dan sistem", "Вигляд і система", "รูปลักษณ์และระบบ",
		"المظهر والنظام")),
]

# (group, name, extends, example, sentence in every language)
WIDGETS = [
	# ── Layout
	("layout", "GoScaffold", "Control", """var page := GoStyle.column()
var screen := GoScaffold.make("Inbox", page, true)
screen.set_fab(GoFab.make(GoIconSet.EDIT))
add_child(screen)""", T(
		"An app screen wired together: bar, scrolling page, bottom bar, FAB and drawer.",
		"앱 화면을 한 번에 엮는다 — 바, 스크롤 페이지, 아래 바, FAB, 서랍.",
		"アプリ画面を一度に組み立てる — バー、スクロールするページ、下部バー、FAB、ドロワー。",
		"一次搭好应用界面：顶栏、滚动页面、底栏、FAB 与抽屉。",
		"一次組好 App 畫面：頂欄、捲動頁面、底欄、FAB 與抽屜。",
		"Una pantalla de app ya conectada: barra, página con desplazamiento, barra inferior, FAB y cajón.",
		"Uma tela de app já conectada: barra, página rolável, barra inferior, FAB e gaveta.",
		"Экран приложения целиком: панель, прокручиваемая страница, нижняя панель, FAB и шторка.",
		"Un écran d'app déjà câblé : barre, page qui défile, barre du bas, FAB et tiroir.",
		"Hazır bağlanmış bir uygulama ekranı: çubuk, kayan sayfa, alt çubuk, FAB ve çekmece.",
		"Gotowy ekran aplikacji: pasek, przewijana strona, dolny pasek, FAB i szuflada.",
		"Una schermata d'app già collegata: barra, pagina scorrevole, barra in basso, FAB e cassetto.",
		"Một màn hình ứng dụng nối sẵn: thanh trên, trang cuộn, thanh dưới, FAB và ngăn kéo.",
		"Layar aplikasi yang sudah terhubung: bilah, halaman bergulir, bilah bawah, FAB, dan laci.",
		"Готовий екран застосунку: панель, прокручувана сторінка, нижня панель, FAB і шухляда.",
		"หน้าจอแอปที่ต่อไว้ครบ — แถบบน หน้าเลื่อน แถบล่าง FAB และลิ้นชัก",
		"شاشة تطبيق موصولة جاهزة: شريط وصفحة تمرير وشريط سفلي وزر FAB ودرج.")),
	("layout", "GoTopBar", "GoEdgeBar", """var bar := GoTopBar.make(3)
bar.add_start(GoStyle.icon_button(GoIconSet.BACK, go_back, -1, &"back"))
bar.add_center(GoStyle.label("Stage 3"))
bar.add_end(GoStyle.chip("1,250"))""", T(
		"Items along the top edge in one to three slots; the centre stays centred.",
		"위쪽 가장자리를 따라 칸 1~3개 — 가운데 칸은 늘 가운데.",
		"上端に沿って 1～3 個の枠。中央の枠は常に中央。",
		"沿顶边排列的 1～3 个槽位，中间槽始终居中。",
		"沿頂邊排列的 1～3 個槽位，中間槽始終置中。",
		"Elementos en el borde superior en una a tres ranuras; el centro queda centrado.",
		"Itens na borda superior em uma a três posições; o centro fica centralizado.",
		"Элементы вдоль верхнего края в одном–трёх слотах; центр всегда по центру.",
		"Des éléments le long du bord haut, sur un à trois emplacements ; le centre reste centré.",
		"Üst kenar boyunca bir ila üç yuvada öğeler; orta yuva hep ortada.",
		"Elementy wzdłuż górnej krawędzi w jednym do trzech miejsc; środek zostaje na środku.",
		"Elementi lungo il bordo superiore in uno-tre slot; il centro resta centrato.",
		"Các mục dọc cạnh trên trong một đến ba ô; ô giữa luôn ở giữa.",
		"Item di sepanjang tepi atas dalam satu sampai tiga slot; bagian tengah tetap di tengah.",
		"Елементи вздовж верхнього краю в одному–трьох слотах; центр завжди посередині.",
		"รายการตามขอบบนในหนึ่งถึงสามช่อง ช่องกลางอยู่ตรงกลางเสมอ",
		"عناصر على الحافة العلوية في خانة إلى ثلاث؛ يبقى الأوسط في المنتصف.")),
	("layout", "GoBottomBar", "GoEdgeBar", """var actions := GoBottomBar.make(1, GoBottomBar.Justify.SPACE_BETWEEN)
for name in ["Attack", "Guard", "Run"]: actions.add_start(GoStyle.button(name))
screen.add_child(actions)""", T(
		"Items along the bottom edge, clear of the gesture bar.",
		"아래쪽 가장자리를 따라 — 제스처 바를 피해서.",
		"下端に沿って配置。ジェスチャーバーを避ける。",
		"沿底边排列，避开手势条。",
		"沿底邊排列，避開手勢列。",
		"Elementos en el borde inferior, lejos de la barra de gestos.",
		"Itens na borda inferior, longe da barra de gestos.",
		"Элементы вдоль нижнего края, не заходя на панель жестов.",
		"Des éléments le long du bord bas, à l'écart de la barre de gestes.",
		"Alt kenar boyunca öğeler, hareket çubuğundan uzak.",
		"Elementy wzdłuż dolnej krawędzi, z dala od paska gestów.",
		"Elementi lungo il bordo inferiore, lontano dalla barra dei gesti.",
		"Các mục dọc cạnh dưới, tránh thanh cử chỉ.",
		"Item di sepanjang tepi bawah, menjauhi bilah gestur.",
		"Елементи вздовж нижнього краю, оминаючи панель жестів.",
		"รายการตามขอบล่าง หลบแถบท่าทาง",
		"عناصر على الحافة السفلية بعيدًا عن شريط الإيماءات.")),
	("layout", "GoLeftSideBar", "GoSideBar", """var tools := GoLeftSideBar.make(3)
tools.add_start(GoStyle.icon_button(GoIconSet.MENU, open_menu, -1, &"menu"))
tools.add_end(GoStyle.icon_button(GoIconSet.USER, open_profile, -1, &"profile"))
screen.add_child(tools)""", T(
		"Up to three tiers down the left edge.",
		"왼쪽 가장자리를 따라 최대 세 단.",
		"左端に沿って最大 3 段。",
		"沿左边最多三层。",
		"沿左邊最多三層。",
		"Hasta tres niveles a lo largo del borde izquierdo.",
		"Até três níveis ao longo da borda esquerda.",
		"До трёх ярусов вдоль левого края.",
		"Jusqu'à trois étages le long du bord gauche.",
		"Sol kenar boyunca en fazla üç katman.",
		"Do trzech poziomów wzdłuż lewej krawędzi.",
		"Fino a tre livelli lungo il bordo sinistro.",
		"Tối đa ba tầng dọc cạnh trái.",
		"Hingga tiga tingkat di sepanjang tepi kiri.",
		"До трьох ярусів уздовж лівого краю.",
		"สูงสุดสามชั้นตามขอบซ้าย",
		"حتى ثلاث طبقات على الحافة اليسرى.")),
	("layout", "GoRightSideBar", "GoSideBar", """var tools := GoRightSideBar.make(3)
tools.add_start(GoStyle.icon_button(GoIconSet.SETTINGS, open_settings, -1, &"settings"))
tools.add_center(GoStyle.icon_button(GoIconSet.SEARCH, find, -1, &"search"))
screen.add_child(tools)""", T(
		"Up to three tiers down the right edge.",
		"오른쪽 가장자리를 따라 최대 세 단.",
		"右端に沿って最大 3 段。",
		"沿右边最多三层。",
		"沿右邊最多三層。",
		"Hasta tres niveles a lo largo del borde derecho.",
		"Até três níveis ao longo da borda direita.",
		"До трёх ярусов вдоль правого края.",
		"Jusqu'à trois étages le long du bord droit.",
		"Sağ kenar boyunca en fazla üç katman.",
		"Do trzech poziomów wzdłuż prawej krawędzi.",
		"Fino a tre livelli lungo il bordo destro.",
		"Tối đa ba tầng dọc cạnh phải.",
		"Hingga tiga tingkat di sepanjang tepi kanan.",
		"До трьох ярусів уздовж правого краю.",
		"สูงสุดสามชั้นตามขอบขวา",
		"حتى ثلاث طبقات على الحافة اليمنى.")),
	("layout", "GoSideBar", "GoEdgeBar", """var rail := GoRightSideBar.make(1, GoSideBar.Justify.CENTER)
rail.add_start(GoStyle.icon_button(GoIconSet.MAP, open_map, -1, &"map"))""", T(
		"The side bar both of those are; it keeps its side in right-to-left languages.",
		"위 둘의 바탕이 되는 옆 바 — 오른쪽에서 왼쪽으로 쓰는 언어에서도 제 쪽을 지킨다.",
		"上の二つの元になるサイドバー。右から左の言語でも位置を変えない。",
		"上面两者的基础侧栏；在从右到左的语言中也保持原侧。",
		"上面兩者的基礎側欄；在由右至左的語言中也保持原側。",
		"La barra lateral de ambas; conserva su lado en idiomas de derecha a izquierda.",
		"A barra lateral base das duas; mantém o lado em idiomas da direita para a esquerda.",
		"Боковая панель, на которой построены обе; в языках справа налево остаётся на своей стороне.",
		"La barre latérale commune aux deux ; elle garde son côté dans les langues de droite à gauche.",
		"İkisinin temelindeki yan çubuk; sağdan sola dillerde de tarafını korur.",
		"Pasek boczny, na którym oba się opierają; w językach pisanych od prawej zostaje po swojej stronie.",
		"La barra laterale alla base di entrambe; mantiene il suo lato nelle lingue da destra a sinistra.",
		"Thanh bên làm nền cho cả hai; vẫn giữ phía của nó với ngôn ngữ viết từ phải sang trái.",
		"Bilah samping dasar keduanya; tetap di sisinya pada bahasa kanan-ke-kiri.",
		"Бічна панель, на якій побудовані обидві; у мовах справа наліво лишається на своєму боці.",
		"แถบข้างที่เป็นฐานของทั้งสอง คงด้านเดิมแม้ในภาษาที่เขียนจากขวาไปซ้าย",
		"الشريط الجانبي الذي يقوم عليه الاثنان؛ يبقى في جهته في اللغات من اليمين إلى اليسار.")),
	("layout", "GoEdgeBar", "Container", """var bar := GoTopBar.make(1)
bar.justify = GoEdgeBar.Justify.SPACE_BETWEEN
bar.pin_to_edge = GoEdgeBar.Pin.ALWAYS""", T(
		"The rules every edge bar shares: slots, spreading, pinning to the edge, the safe area.",
		"모든 가장자리 바가 공유하는 규칙 — 칸, 고르게 펼치기, 가장자리에 붙이기, 안전 영역.",
		"すべての端バーに共通の規則 — 枠、均等配置、端への固定、セーフエリア。",
		"所有边栏共享的规则：槽位、均匀分布、贴边与安全区域。",
		"所有邊欄共用的規則：槽位、平均分布、貼邊與安全區域。",
		"Las reglas que comparten todas las barras de borde: ranuras, reparto, anclaje al borde y área segura.",
		"As regras que todas as barras de borda compartilham: posições, distribuição, fixação na borda e área segura.",
		"Общие правила всех краевых панелей: слоты, распределение, прижатие к краю, безопасная зона.",
		"Les règles communes à toutes les barres de bord : emplacements, répartition, ancrage au bord, zone sûre.",
		"Tüm kenar çubuklarının ortak kuralları: yuvalar, yayma, kenara sabitleme, güvenli alan.",
		"Zasady wspólne dla pasków krawędzi: miejsca, rozkład, przypięcie do krawędzi, bezpieczny obszar.",
		"Le regole comuni a tutte le barre di bordo: slot, distribuzione, ancoraggio al bordo, area sicura.",
		"Quy tắc chung của mọi thanh cạnh: ô, dàn đều, gắn vào cạnh, vùng an toàn.",
		"Aturan bersama semua bilah tepi: slot, perataan, menempel ke tepi, area aman.",
		"Спільні правила всіх крайових панелей: слоти, розподіл, притискання до краю, безпечна зона.",
		"กติกาที่แถบขอบทุกแบบใช้ร่วมกัน: ช่อง การกระจาย การยึดขอบ และพื้นที่ปลอดภัย",
		"القواعد المشتركة لكل أشرطة الحواف: الخانات والتوزيع والتثبيت على الحافة والمنطقة الآمنة.")),
	("layout", "GoGrid", "Container", """var cards := GoGrid.make(1, 160.0)
for item in items: cards.add_child(GoStyle.item_card(item))""", T(
		"Columns of exactly equal width — a fixed count, or as many as fit.",
		"폭이 정확히 같은 열 — 정해진 수, 또는 들어가는 만큼.",
		"幅がぴったり等しい列 — 決まった数、または入るだけ。",
		"宽度完全相同的列——固定数量，或能放多少放多少。",
		"寬度完全相同的欄——固定數量，或能放多少放多少。",
		"Columnas de ancho exactamente igual: un número fijo o tantas como quepan.",
		"Colunas de largura exatamente igual: um número fixo ou quantas couberem.",
		"Столбцы строго одинаковой ширины — заданное число или сколько поместится.",
		"Des colonnes de largeur exactement égale : un nombre fixe, ou autant qu'il en tient.",
		"Tam olarak eşit genişlikte sütunlar — sabit sayıda ya da sığdığı kadar.",
		"Kolumny o dokładnie równej szerokości — stała liczba lub tyle, ile się zmieści.",
		"Colonne di larghezza esattamente uguale: un numero fisso o quante ne entrano.",
		"Các cột rộng bằng nhau tuyệt đối — số cố định, hoặc vừa bao nhiêu xếp bấy nhiêu.",
		"Kolom dengan lebar persis sama — jumlah tetap, atau sebanyak yang muat.",
		"Стовпці точно однакової ширини — задана кількість або скільки вміститься.",
		"คอลัมน์กว้างเท่ากันพอดี — จำนวนตายตัว หรือเท่าที่ใส่ได้",
		"أعمدة متساوية العرض تمامًا — عدد ثابت أو بقدر ما يتسع.")),
	("layout", "GoForm", "MarginContainer", """var form := GoForm.new()
form.avoid_hud = true
form.add_child(GoScroll.new())
add_child(form)""", T(
		"A form that caps its width and keeps clear of the keyboard and the HUD.",
		"폭을 제한하고 키보드와 HUD 를 피하는 폼.",
		"幅を抑え、キーボードと HUD を避けるフォーム。",
		"限制宽度并避开键盘与 HUD 的表单。",
		"限制寬度並避開鍵盤與 HUD 的表單。",
		"Un formulario que limita su ancho y se aparta del teclado y del HUD.",
		"Um formulário que limita a largura e se afasta do teclado e do HUD.",
		"Форма, которая ограничивает ширину и обходит клавиатуру и HUD.",
		"Un formulaire qui limite sa largeur et s'écarte du clavier et du HUD.",
		"Genişliğini sınırlayan, klavyeden ve HUD'dan uzak duran form.",
		"Formularz, który ogranicza szerokość i omija klawiaturę oraz HUD.",
		"Un modulo che limita la larghezza e si tiene lontano da tastiera e HUD.",
		"Biểu mẫu giới hạn độ rộng và tránh bàn phím cùng HUD.",
		"Formulir yang membatasi lebarnya dan menjauhi keyboard serta HUD.",
		"Форма, що обмежує ширину й оминає клавіатуру та HUD.",
		"ฟอร์มที่จำกัดความกว้างและหลบคีย์บอร์ดกับ HUD",
		"نموذج يحد عرضه ويبتعد عن لوحة المفاتيح وواجهة HUD.")),
	("layout", "GoScroll", "ScrollContainer", """var list := GoScroll.new()
list.add_child(GoStyle.column())
var strip := GoScroll.horizontal()""", T(
		"Touch scrolling that works from anywhere on the content; right-to-left aware.",
		"내용 어디서 시작해도 되는 터치 스크롤 — 오른쪽에서 왼쪽 언어도 맞춘다.",
		"内容のどこからでも効くタッチスクロール。右から左の言語にも対応。",
		"从内容任意位置都能触控滚动，支持从右到左的语言。",
		"從內容任意位置都能觸控捲動，支援由右至左的語言。",
		"Desplazamiento táctil que funciona desde cualquier parte del contenido; admite idiomas de derecha a izquierda.",
		"Rolagem por toque que funciona em qualquer ponto do conteúdo; suporta idiomas da direita para a esquerda.",
		"Прокрутка касанием с любого места содержимого; учитывает письмо справа налево.",
		"Un défilement tactile qui marche depuis n'importe où dans le contenu ; gère la droite-à-gauche.",
		"İçeriğin her yerinden çalışan dokunmatik kaydırma; sağdan sola dilleri destekler.",
		"Przewijanie dotykiem z dowolnego miejsca treści; obsługuje pismo od prawej do lewej.",
		"Scorrimento al tocco da qualsiasi punto del contenuto; gestisce la scrittura da destra a sinistra.",
		"Cuộn bằng chạm từ bất kỳ đâu trên nội dung; hỗ trợ ngôn ngữ viết từ phải sang trái.",
		"Gulir sentuh yang bekerja dari mana saja di konten; mendukung bahasa kanan-ke-kiri.",
		"Прокручування дотиком з будь-якого місця вмісту; враховує письмо справа наліво.",
		"เลื่อนด้วยการสัมผัสได้จากทุกจุดของเนื้อหา รองรับภาษาที่เขียนจากขวาไปซ้าย",
		"تمرير باللمس يعمل من أي مكان في المحتوى؛ يراعي اللغات من اليمين إلى اليسار.")),
	("layout", "GoHudAnchor", "Control", """var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.TOP_LEFT
corner.add_child(GoStyle.hud_panel())""", T(
		"Pins HUD pieces to one of nine safe-area spots.",
		"HUD 조각을 안전 영역의 아홉 자리 중 하나에 고정한다.",
		"HUD の部品をセーフエリアの 9 か所のどれかに固定する。",
		"把 HUD 部件固定在安全区域的九个位置之一。",
		"把 HUD 元件固定在安全區域的九個位置之一。",
		"Fija piezas del HUD en uno de nueve puntos del área segura.",
		"Fixa peças do HUD em um de nove pontos da área segura.",
		"Закрепляет элементы HUD в одной из девяти точек безопасной зоны.",
		"Épingle des éléments du HUD à l'un des neuf emplacements de la zone sûre.",
		"HUD parçalarını güvenli alanın dokuz noktasından birine sabitler.",
		"Przypina elementy HUD do jednego z dziewięciu miejsc bezpiecznego obszaru.",
		"Fissa i pezzi dell'HUD in uno dei nove punti dell'area sicura.",
		"Gắn các phần HUD vào một trong chín vị trí của vùng an toàn.",
		"Menyematkan bagian HUD ke salah satu dari sembilan titik area aman.",
		"Закріплює елементи HUD в одній із дев'яти точок безпечної зони.",
		"ตรึงชิ้นส่วน HUD ไว้ที่หนึ่งในเก้าตำแหน่งของพื้นที่ปลอดภัย",
		"يثبت أجزاء HUD في إحدى تسع نقاط من المنطقة الآمنة.")),
	("layout", "GoStyle.column · row · wrap_row", "GoStyle", """var page := GoStyle.column()
var line := GoStyle.row()
var chips := GoStyle.wrap_row()""", T(
		"Columns, rows and wrapping rows with gaps from the theme.",
		"테마의 간격을 쓰는 세로줄·가로줄·줄바꿈 줄.",
		"テーマの間隔を使う縦並び・横並び・折り返し行。",
		"使用主题间距的列、行与自动换行的行。",
		"使用主題間距的欄、列與自動換行的列。",
		"Columnas, filas y filas que se ajustan, con espacios del tema.",
		"Colunas, linhas e linhas que quebram, com espaçamentos do tema.",
		"Столбцы, строки и переносимые строки с отступами из темы.",
		"Colonnes, rangées et rangées qui passent à la ligne, avec les espacements du thème.",
		"Temanın boşluklarıyla sütunlar, satırlar ve kaydırmalı satırlar.",
		"Kolumny, wiersze i zawijane wiersze z odstępami z motywu.",
		"Colonne, righe e righe che vanno a capo, con gli spazi del tema.",
		"Cột, hàng và hàng tự xuống dòng với khoảng cách lấy từ theme.",
		"Kolom, baris, dan baris yang membungkus dengan jarak dari tema.",
		"Стовпці, рядки й рядки з перенесенням, з відступами з теми.",
		"คอลัมน์ แถว และแถวที่ขึ้นบรรทัดใหม่ได้ ด้วยระยะห่างจากธีม",
		"أعمدة وصفوف وصفوف ملتفة بفواصل من السمة.")),
	("layout", "GoStyle.responsive_grid · aspect", "GoStyle", """var tiles := GoStyle.responsive_grid(160)
var thumb := GoStyle.aspect(16.0 / 9.0)""", T(
		"A grid that adds columns as it widens; a box that keeps its ratio.",
		"넓어지면 열을 늘리는 격자, 그리고 비율을 지키는 상자.",
		"広がると列が増えるグリッドと、比率を保つ箱。",
		"变宽时增加列的网格，以及保持比例的盒子。",
		"變寬時增加欄的網格，以及保持比例的方塊。",
		"Una cuadrícula que suma columnas al ensancharse y una caja que mantiene su proporción.",
		"Uma grade que ganha colunas ao alargar e uma caixa que mantém a proporção.",
		"Сетка, которая добавляет столбцы при расширении, и блок с постоянными пропорциями.",
		"Une grille qui ajoute des colonnes en s'élargissant, et une boîte qui garde ses proportions.",
		"Genişledikçe sütun ekleyen bir ızgara ve oranını koruyan bir kutu.",
		"Siatka, która dodaje kolumny przy poszerzaniu, i pudełko trzymające proporcje.",
		"Una griglia che aggiunge colonne allargandosi e un riquadro che mantiene le proporzioni.",
		"Lưới thêm cột khi rộng ra, và hộp giữ nguyên tỉ lệ.",
		"Grid yang menambah kolom saat melebar, dan kotak yang menjaga rasionya.",
		"Сітка, що додає стовпці при розширенні, і блок, який тримає пропорції.",
		"กริดที่เพิ่มคอลัมน์เมื่อกว้างขึ้น และกล่องที่รักษาสัดส่วน",
		"شبكة تزيد أعمدتها كلما اتسعت، وصندوق يحفظ نسبته.")),
	("layout", "GoStyle.padding · spacer · divider", "GoStyle", """var pad := GoStyle.padding(16)
line.add_child(GoStyle.spacer())
page.add_child(GoStyle.divider())""", T(
		"Padding, a spacer that takes the room left over, a divider line.",
		"안쪽 여백, 남는 자리를 차지하는 빈칸, 구분선.",
		"内側の余白、余った幅を埋めるスペーサー、区切り線。",
		"内边距、占满剩余空间的间隔与分隔线。",
		"內距、佔滿剩餘空間的間隔與分隔線。",
		"Relleno, un espaciador que ocupa el sitio que sobra y una línea divisoria.",
		"Preenchimento, um espaçador que ocupa o espaço que sobra e uma linha divisória.",
		"Внутренний отступ, распорка на оставшееся место и разделительная линия.",
		"Une marge intérieure, un espaceur qui prend la place restante, une ligne de séparation.",
		"İç boşluk, kalan yeri dolduran ara ve bir ayırıcı çizgi.",
		"Wypełnienie, odstęp zajmujący wolne miejsce i linia podziału.",
		"Spaziatura interna, un distanziatore che occupa lo spazio avanzato, una linea divisoria.",
		"Lề trong, khoảng đệm chiếm chỗ còn trống, và đường phân cách.",
		"Padding, pengisi yang mengambil sisa ruang, dan garis pemisah.",
		"Внутрішній відступ, розпірка на решту місця і роздільна лінія.",
		"ระยะขอบใน ช่องว่างที่กินพื้นที่ที่เหลือ และเส้นคั่น",
		"حشوة، وفاصل يأخذ المساحة المتبقية، وخط فاصل.")),
	("layout", "GoStyle.foldable · section", "GoStyle", """page.add_child(GoStyle.section("Sound", false))
var more := GoStyle.foldable("Advanced", true, null, false)""", T(
		"A section heading, and a section that folds open.",
		"절 제목, 그리고 펼치고 접는 절.",
		"節見出しと、開閉できる節。",
		"分区标题，以及可展开折叠的分区。",
		"區段標題，以及可展開收合的區段。",
		"Un título de sección y una sección que se despliega.",
		"Um título de seção e uma seção que se expande.",
		"Заголовок раздела и раздел, который раскрывается.",
		"Un titre de section, et une section qui se déplie.",
		"Bir bölüm başlığı ve açılıp kapanan bir bölüm.",
		"Nagłówek sekcji i sekcja, która się rozwija.",
		"Un titolo di sezione e una sezione che si apre.",
		"Tiêu đề mục, và mục có thể mở ra gập lại.",
		"Judul bagian, dan bagian yang bisa dibuka-tutup.",
		"Заголовок розділу і розділ, що розгортається.",
		"หัวข้อส่วน และส่วนที่พับเปิดได้",
		"عنوان قسم، وقسم يُطوى ويُفتح.")),
	# ── Windows and overlays
	("windows", "GoSurface", "Control", """var window := GoSurface.new()
window.set_title("Settings")
window.close_requested.connect(window.queue_free)
layer.add_child(window)""", T(
		"A floating window — centred, from the bottom, or anchored to a control.",
		"떠 있는 창 — 가운데, 아래에서, 또는 컨트롤 옆에.",
		"浮かぶウィンドウ — 中央、下から、またはコントロールの横に。",
		"浮动窗口——居中、从底部弹出，或贴靠某个控件。",
		"浮動視窗——置中、從底部彈出，或貼靠某個控制項。",
		"Una ventana flotante: centrada, desde abajo o anclada a un control.",
		"Uma janela flutuante: centralizada, vinda de baixo ou ancorada a um controle.",
		"Плавающее окно — по центру, снизу или привязанное к элементу.",
		"Une fenêtre flottante : centrée, venue du bas, ou ancrée à un contrôle.",
		"Yüzen bir pencere — ortada, alttan ya da bir denetime bağlı.",
		"Pływające okno — na środku, od dołu albo przy kontrolce.",
		"Una finestra fluttuante: centrata, dal basso o ancorata a un controllo.",
		"Cửa sổ nổi — ở giữa, từ dưới lên, hoặc neo vào một điều khiển.",
		"Jendela mengambang — di tengah, dari bawah, atau tertambat pada kontrol.",
		"Плаваюче вікно — по центру, знизу або прив'язане до елемента.",
		"หน้าต่างลอย — กึ่งกลาง จากด้านล่าง หรือยึดกับคอนโทรล",
		"نافذة عائمة — في الوسط أو من الأسفل أو مثبتة على عنصر تحكم.")),
	("windows", "GoSheet", "CanvasLayer", """var sheet := GoSheet.new()
add_child(sheet)
sheet.open("Inventory")
sheet.body.add_child(bag_list)""", T(
		"A bottom sheet with pages, back navigation and a sticky footer.",
		"페이지·뒤로 가기·고정 바닥줄이 있는 아래 시트.",
		"ページ、戻る操作、固定フッターを持つボトムシート。",
		"带分页、返回导航与固定底栏的底部面板。",
		"具分頁、返回導覽與固定底欄的底部面板。",
		"Una hoja inferior con páginas, navegación hacia atrás y pie fijo.",
		"Uma folha inferior com páginas, navegação de voltar e rodapé fixo.",
		"Нижняя панель со страницами, переходом назад и закреплённым низом.",
		"Une feuille du bas avec des pages, le retour arrière et un pied fixe.",
		"Sayfaları, geri gezintisi ve sabit alt kısmı olan bir alt sayfa.",
		"Dolny arkusz ze stronami, cofaniem i przypiętą stopką.",
		"Un foglio dal basso con pagine, navigazione indietro e piè di pagina fisso.",
		"Bảng dưới có trang, nút quay lại và chân cố định.",
		"Lembar bawah dengan halaman, navigasi kembali, dan footer tetap.",
		"Нижня панель зі сторінками, переходом назад і закріпленим низом.",
		"แผ่นล่างที่มีหลายหน้า ปุ่มย้อนกลับ และส่วนท้ายที่ตรึงไว้",
		"لوحة سفلية بصفحات وتنقل للخلف وتذييل ثابت.")),
	("windows", "GoDialogs", "Node", """var dialogs := GoDialogs.new()
add_child(dialogs)
if await dialogs.confirm("Delete save", "This cannot be undone.", "", "", "", {}, true):
	delete_save()""", T(
		"Confirm and alert windows you await; alerts wait their turn.",
		"await 로 기다리는 확인·알림 창 — 알림은 차례를 기다린다.",
		"await で待つ確認・お知らせウィンドウ。お知らせは順番を待つ。",
		"可 await 的确认与提示窗口；提示会排队等候。",
		"可 await 的確認與提示視窗；提示會排隊等候。",
		"Ventanas de confirmación y aviso que se esperan con await; los avisos hacen cola.",
		"Janelas de confirmação e alerta que você aguarda com await; os alertas esperam a vez.",
		"Окна подтверждения и оповещения через await; оповещения ждут своей очереди.",
		"Des fenêtres de confirmation et d'alerte qu'on attend avec await ; les alertes attendent leur tour.",
		"await ile beklenen onay ve uyarı pencereleri; uyarılar sırasını bekler.",
		"Okna potwierdzeń i alertów, na które czekasz przez await; alerty czekają na swoją kolej.",
		"Finestre di conferma e di avviso da attendere con await; gli avvisi aspettano il loro turno.",
		"Cửa sổ xác nhận và cảnh báo chờ bằng await; cảnh báo xếp hàng chờ lượt.",
		"Jendela konfirmasi dan peringatan yang ditunggu dengan await; peringatan menunggu gilirannya.",
		"Вікна підтвердження та сповіщення через await; сповіщення чекають своєї черги.",
		"หน้าต่างยืนยันและแจ้งเตือนที่รอด้วย await การแจ้งเตือนจะรอคิว",
		"نوافذ تأكيد وتنبيه تنتظرها بـ await؛ تنتظر التنبيهات دورها.")),
	("windows", "GoDialogs.choose", "GoDialogs", """var index := await dialogs.choose("Sort by", ["Newest", "Price", "Rating"])
if index >= 0: sort_by(index)""", T(
		"One of a few options — a bottom sheet on a phone, a card on a desktop.",
		"몇 가지 중 하나 — 폰에서는 아래 시트, 데스크톱에서는 카드.",
		"いくつかから一つ — スマホでは下からのシート、デスクトップではカード。",
		"从几项中选一项——手机上是底部面板，桌面上是卡片。",
		"從幾項中選一項——手機上是底部面板，桌面上是卡片。",
		"Una de varias opciones: hoja inferior en el móvil, tarjeta en el escritorio.",
		"Uma entre poucas opções: folha inferior no celular, cartão no desktop.",
		"Один из нескольких вариантов — нижняя панель на телефоне, карточка на компьютере.",
		"Un choix parmi quelques-uns : feuille du bas sur téléphone, carte sur ordinateur.",
		"Birkaç seçenekten biri — telefonda alt sayfa, masaüstünde kart.",
		"Jedna z kilku opcji — dolny arkusz na telefonie, karta na komputerze.",
		"Una tra poche opzioni: foglio dal basso sul telefono, scheda sul desktop.",
		"Một trong vài lựa chọn — bảng dưới trên điện thoại, thẻ trên máy tính.",
		"Satu dari beberapa pilihan — lembar bawah di ponsel, kartu di desktop.",
		"Один із кількох варіантів — нижня панель на телефоні, картка на комп'ютері.",
		"หนึ่งในไม่กี่ตัวเลือก — แผ่นล่างบนมือถือ การ์ดบนเดสก์ท็อป",
		"خيار من بضعة خيارات — لوحة سفلية على الهاتف وبطاقة على سطح المكتب.")),
	("windows", "GoDrawer", "CanvasLayer", """var drawer := GoDrawer.new()
add_child(drawer)
drawer.side = GoDrawer.Side.RIGHT
drawer.open("Bag")""", T(
		"A panel that slides in from the left or the right.",
		"왼쪽이나 오른쪽에서 밀려 들어오는 판.",
		"左または右から滑り込むパネル。",
		"从左侧或右侧滑入的面板。",
		"從左側或右側滑入的面板。",
		"Un panel que entra deslizándose por la izquierda o la derecha.",
		"Um painel que desliza da esquerda ou da direita.",
		"Панель, выезжающая слева или справа.",
		"Un panneau qui glisse depuis la gauche ou la droite.",
		"Soldan ya da sağdan kayarak gelen bir panel.",
		"Panel wysuwany z lewej lub z prawej.",
		"Un pannello che scivola dentro da sinistra o da destra.",
		"Bảng trượt vào từ bên trái hoặc bên phải.",
		"Panel yang meluncur masuk dari kiri atau kanan.",
		"Панель, що виїжджає зліва або справа.",
		"แผงที่เลื่อนเข้ามาจากซ้ายหรือขวา",
		"لوحة تنزلق من اليسار أو اليمين.")),
	("windows", "GoPopover", "RefCounted", """GoPopover.open(slot, GoStyle.item_card(item, false))""", T(
		"An info card beside what was pressed; one at a time.",
		"누른 것 옆의 정보 카드 — 한 번에 하나.",
		"押したものの横に出る情報カード。一度に一つ。",
		"在被点按之处旁边弹出的信息卡，一次一张。",
		"在被點按之處旁邊彈出的資訊卡，一次一張。",
		"Una tarjeta de información junto a lo que se pulsó; una a la vez.",
		"Um cartão de informação ao lado do que foi tocado; um por vez.",
		"Карточка с информацией рядом с нажатым элементом; по одной.",
		"Une carte d'information à côté de ce qui a été touché ; une à la fois.",
		"Basılan şeyin yanında bir bilgi kartı; aynı anda bir tane.",
		"Karta informacji obok tego, co naciśnięto; jedna naraz.",
		"Una scheda informativa accanto a ciò che è stato toccato; una alla volta.",
		"Thẻ thông tin cạnh thứ vừa nhấn; mỗi lúc một thẻ.",
		"Kartu info di samping yang ditekan; satu per satu.",
		"Картка з інформацією біля натиснутого елемента; по одній.",
		"การ์ดข้อมูลข้างสิ่งที่กด ทีละใบ",
		"بطاقة معلومات بجانب ما ضُغط عليه؛ واحدة في كل مرة.")),
	("windows", "GoContextMenu", "RefCounted", """GoContextMenu.attach(slot, [{"text": "Use"}, {"text": "Drop", "danger": true}])""", T(
		"Long press or right click for a menu; a moving finger cancels it.",
		"길게 누르기·오른쪽 클릭 메뉴 — 손가락이 움직이면 취소된다.",
		"長押し・右クリックのメニュー。指が動くと取り消される。",
		"长按或右键弹出菜单；手指一移动就取消。",
		"長按或右鍵彈出選單；手指一移動就取消。",
		"Menú con pulsación larga o clic derecho; un dedo que se mueve lo cancela.",
		"Menu com toque longo ou clique direito; um dedo que se move o cancela.",
		"Меню по долгому нажатию или правому клику; движение пальца его отменяет.",
		"Un menu par appui long ou clic droit ; un doigt qui bouge l'annule.",
		"Uzun basma ya da sağ tıkla menü; hareket eden parmak iptal eder.",
		"Menu po długim naciśnięciu lub prawym kliknięciu; ruch palca je anuluje.",
		"Menu con pressione prolungata o clic destro; un dito che si muove lo annulla.",
		"Menu khi nhấn giữ hoặc nhấp chuột phải; ngón tay di chuyển sẽ hủy.",
		"Menu dengan tekan lama atau klik kanan; jari yang bergerak membatalkannya.",
		"Меню за довгим натисканням або правим кліком; рух пальця його скасовує.",
		"เมนูเมื่อกดค้างหรือคลิกขวา ถ้านิ้วขยับจะยกเลิก",
		"قائمة بالضغط المطول أو النقر الأيمن؛ تُلغى إن تحرك الإصبع.")),
	("windows", "GoCoachMark", "Control", """var tour := GoCoachMark.new()
add_child(tour)
tour.start([{"target": bag_button, "title": "Bag", "body": "Your items live here."}])""", T(
		"A guided tour that points at real controls.",
		"실제 컨트롤을 가리키는 안내 투어.",
		"実際のコントロールを指し示すガイドツアー。",
		"指向真实控件的引导教程。",
		"指向真實控制項的引導教學。",
		"Un recorrido guiado que señala controles reales.",
		"Um tour guiado que aponta para controles reais.",
		"Обучающий тур, указывающий на настоящие элементы.",
		"Une visite guidée qui montre les vrais contrôles.",
		"Gerçek denetimleri gösteren rehberli tur.",
		"Przewodnik wskazujący prawdziwe kontrolki.",
		"Un tour guidato che indica i controlli reali.",
		"Chuyến hướng dẫn chỉ vào các điều khiển thật.",
		"Tur terpandu yang menunjuk kontrol sungguhan.",
		"Навчальний тур, що вказує на справжні елементи.",
		"ทัวร์แนะนำที่ชี้ไปยังคอนโทรลจริง",
		"جولة إرشادية تشير إلى عناصر تحكم حقيقية.")),
	("windows", "GoConsole", "CanvasLayer", """var console := GoConsole.new()
add_child(console)
console.register("give", "Grant an item", give_item)""", T(
		"A developer console with commands and history; off in release builds.",
		"명령과 기록이 있는 개발자 콘솔 — 출시 빌드에서는 꺼진다.",
		"コマンドと履歴を持つ開発者コンソール。リリースビルドでは無効。",
		"带命令与历史记录的开发者控制台；发布版中关闭。",
		"具指令與歷史紀錄的開發者主控台；正式版中關閉。",
		"Una consola de desarrollo con comandos e historial; desactivada en versiones publicadas.",
		"Um console de desenvolvedor com comandos e histórico; desligado nas builds de lançamento.",
		"Консоль разработчика с командами и историей; в релизных сборках выключена.",
		"Une console de développement avec commandes et historique ; désactivée en version publiée.",
		"Komutları ve geçmişi olan geliştirici konsolu; yayın derlemelerinde kapalı.",
		"Konsola deweloperska z poleceniami i historią; wyłączona w wydaniach.",
		"Una console per sviluppatori con comandi e cronologia; spenta nelle build di rilascio.",
		"Bảng điều khiển cho nhà phát triển có lệnh và lịch sử; tắt trong bản phát hành.",
		"Konsol pengembang dengan perintah dan riwayat; mati di build rilis.",
		"Консоль розробника з командами та історією; у релізних збірках вимкнена.",
		"คอนโซลนักพัฒนาที่มีคำสั่งและประวัติ ปิดในบิลด์ที่เผยแพร่",
		"وحدة تحكم للمطورين بأوامر وسجل؛ معطلة في إصدارات النشر.")),
	# ── Messages and waiting
	("messages", "GoSnackbar", "Node", """var snack := GoSnackbar.new()
add_child(snack)
if await snack.post({"text": "Item dropped", "actions": ["Undo"]}) == 0:
	restore_item()""", T(
		"A message at the bottom that queues and can carry buttons.",
		"아래에 뜨는 알림 — 줄을 서고 버튼도 달 수 있다.",
		"下に出るメッセージ。順番待ちし、ボタンも付けられる。",
		"底部消息，可排队，也可带按钮。",
		"底部訊息，可排隊，也可帶按鈕。",
		"Un mensaje abajo que hace cola y puede llevar botones.",
		"Uma mensagem na parte de baixo que entra na fila e pode ter botões.",
		"Сообщение внизу: встаёт в очередь и может нести кнопки.",
		"Un message en bas qui se met en file et peut porter des boutons.",
		"Altta sıraya giren ve düğme taşıyabilen bir mesaj.",
		"Komunikat na dole, który czeka w kolejce i może mieć przyciski.",
		"Un messaggio in basso che si mette in coda e può avere pulsanti.",
		"Thông báo ở dưới, có hàng chờ và có thể kèm nút.",
		"Pesan di bawah yang mengantre dan bisa membawa tombol.",
		"Повідомлення внизу: стає в чергу й може мати кнопки.",
		"ข้อความด้านล่างที่เข้าคิวได้และมีปุ่มได้",
		"رسالة في الأسفل تنتظر دورها ويمكن أن تحمل أزرارًا.")),
	("messages", "GoNotice", "PanelContainer", """var notice := GoNotice.new()
hud.add_child(notice)
notice.show_text("Saved", GoTheme.SUCCESS)""", T(
		"A notice that never takes input or focus.",
		"입력도 초점도 가져가지 않는 알림.",
		"入力もフォーカスも奪わないお知らせ。",
		"绝不抢占输入或焦点的提示。",
		"絕不搶占輸入或焦點的提示。",
		"Un aviso que nunca toma la entrada ni el foco.",
		"Um aviso que nunca toma a entrada nem o foco.",
		"Уведомление, которое не забирает ни ввод, ни фокус.",
		"Un avis qui ne prend jamais la saisie ni le focus.",
		"Asla girdi ya da odak almayan bir bildirim.",
		"Powiadomienie, które nie przejmuje ani wejścia, ani fokusu.",
		"Un avviso che non prende mai input né focus.",
		"Thông báo không bao giờ chiếm thao tác hay tiêu điểm.",
		"Pemberitahuan yang tidak pernah mengambil input atau fokus.",
		"Сповіщення, яке не забирає ні введення, ні фокус.",
		"ประกาศที่ไม่แย่งการป้อนข้อมูลหรือโฟกัส",
		"إشعار لا يأخذ الإدخال ولا التركيز أبدًا.")),
	("messages", "GoPromptCard", "PanelContainer", """var invite := GoPromptCard.new()
invite.set_title("Party invite from Ann")
invite.set_actions([{"text": "Accept", "action": accept, "primary": true}])""", T(
		"A question that does not stop the game — an invite, a trade.",
		"게임을 멈추지 않는 질문 — 초대, 거래.",
		"ゲームを止めない問いかけ — 招待、取引。",
		"不打断游戏的询问——邀请、交易。",
		"不打斷遊戲的詢問——邀請、交易。",
		"Una pregunta que no detiene el juego: una invitación, un intercambio.",
		"Uma pergunta que não para o jogo: um convite, uma troca.",
		"Вопрос, который не останавливает игру, — приглашение, обмен.",
		"Une question qui n'arrête pas le jeu : une invitation, un échange.",
		"Oyunu durdurmayan bir soru — davet, takas.",
		"Pytanie, które nie zatrzymuje gry — zaproszenie, wymiana.",
		"Una domanda che non ferma il gioco: un invito, uno scambio.",
		"Câu hỏi không dừng trò chơi — lời mời, giao dịch.",
		"Pertanyaan yang tidak menghentikan permainan — undangan, pertukaran.",
		"Питання, яке не зупиняє гру, — запрошення, обмін.",
		"คำถามที่ไม่หยุดเกม — คำเชิญ การแลกเปลี่ยน",
		"سؤال لا يوقف اللعبة — دعوة أو مبادلة.")),
	("messages", "GoBanner", "PanelContainer", """var offline := GoBanner.make("You're offline.", [{"text": "Retry", "action": reconnect}], GoIconSet.WARNING)
page.add_child(offline)""", T(
		"A message that stays on the page until it is dealt with.",
		"처리할 때까지 페이지에 남는 알림.",
		"対処されるまでページに残るメッセージ。",
		"一直留在页面上直到被处理的消息。",
		"一直留在頁面上直到被處理的訊息。",
		"Un mensaje que se queda en la página hasta que se atiende.",
		"Uma mensagem que fica na página até ser resolvida.",
		"Сообщение, которое остаётся на странице, пока с ним не разберутся.",
		"Un message qui reste sur la page jusqu'à ce qu'on s'en occupe.",
		"İlgilenilene kadar sayfada kalan bir mesaj.",
		"Komunikat, który zostaje na stronie, dopóki się nim nie zajmiesz.",
		"Un messaggio che resta sulla pagina finché non viene gestito.",
		"Thông báo ở lại trang cho đến khi được xử lý.",
		"Pesan yang tetap di halaman sampai ditangani.",
		"Повідомлення, що лишається на сторінці, доки його не опрацюють.",
		"ข้อความที่อยู่บนหน้าจนกว่าจะได้รับการจัดการ",
		"رسالة تبقى على الصفحة حتى يُتعامل معها.")),
	("messages", "GoSpinner", "Control", """GoSpinner.busy(buy_button, true)
await shop.buy(item)
GoSpinner.busy(buy_button, false)""", T(
		"A wait; turns a button into a spinner in place, so it cannot be pressed twice.",
		"기다림 표시 — 버튼을 그 자리에서 스피너로 바꿔 두 번 눌리지 않게 한다.",
		"待機表示。ボタンをその場でスピナーに変え、二度押しを防ぐ。",
		"等待指示；把按钮原地变成转圈，避免被按两次。",
		"等待指示；把按鈕原地變成轉圈，避免被按兩次。",
		"Una espera; convierte un botón en un indicador en su sitio para que no se pulse dos veces.",
		"Uma espera; transforma um botão em indicador no lugar, para não ser tocado duas vezes.",
		"Ожидание; превращает кнопку в индикатор на месте, чтобы её не нажали дважды.",
		"Une attente ; transforme un bouton en indicateur sur place, pour qu'on ne le touche pas deux fois.",
		"Bekleme; düğmeyi yerinde döner simgeye çevirir, iki kez basılamaz.",
		"Oczekiwanie; zamienia przycisk w miejscu we wskaźnik, by nie dało się go nacisnąć dwa razy.",
		"Un'attesa; trasforma sul posto un pulsante in indicatore, così non si preme due volte.",
		"Chờ đợi; biến nút thành vòng quay ngay tại chỗ để không bị nhấn hai lần.",
		"Menunggu; mengubah tombol menjadi pemutar di tempatnya agar tidak ditekan dua kali.",
		"Очікування; перетворює кнопку на індикатор на місці, щоб її не натиснули двічі.",
		"การรอ เปลี่ยนปุ่มเป็นวงหมุนตรงที่เดิม กดซ้ำไม่ได้",
		"انتظار؛ يحوّل الزر إلى مؤشر في مكانه فلا يُضغط مرتين.")),
	("messages", "GoBadge", "PanelContainer", """GoBadge.attach(mail_button, unread)
GoBadge.attach(shop_button, 0, "NEW")""", T(
		"The unread dot, the NEW tag and 99+, hung on a corner.",
		"안 읽음 점, NEW 표시, 99+ — 모서리에 건다.",
		"未読の点、NEW タグ、99+ を角に付ける。",
		"未读圆点、NEW 标签与 99+，挂在角上。",
		"未讀圓點、NEW 標籤與 99+，掛在角上。",
		"El punto de no leído, la etiqueta NEW y el 99+, colgados de una esquina.",
		"O ponto de não lido, a etiqueta NEW e o 99+, presos num canto.",
		"Точка непрочитанного, метка NEW и 99+ в углу.",
		"Le point non lu, l'étiquette NEW et le 99+, accrochés à un coin.",
		"Okunmamış noktası, NEW etiketi ve 99+, bir köşeye asılı.",
		"Kropka nieprzeczytanych, etykieta NEW i 99+, zawieszone w rogu.",
		"Il punto di non letto, l'etichetta NEW e il 99+, appesi a un angolo.",
		"Chấm chưa đọc, nhãn NEW và 99+, gắn ở góc.",
		"Titik belum dibaca, tag NEW, dan 99+, digantung di sudut.",
		"Крапка непрочитаного, мітка NEW і 99+ у куті.",
		"จุดยังไม่อ่าน ป้าย NEW และ 99+ ติดไว้ที่มุม",
		"نقطة غير المقروء ووسم NEW و+99 معلقة على زاوية.")),
	("messages", "GoProgress", "Control", """var upload := GoProgress.linear()
upload.value = 0.4
var ring := GoProgress.circular(true)""", T(
		"Progress as a line or a ring, wavy or flat; indeterminate while the size is unknown.",
		"선이나 고리로 보이는 진행 — 물결 또는 평평, 크기를 모르면 무한.",
		"線か輪で示す進捗。波形か平坦、量が不明なら不確定表示。",
		"线形或环形进度，波浪或平直；不知总量时为不确定状态。",
		"線形或環形進度，波浪或平直；不知總量時為不確定狀態。",
		"Progreso en línea o anillo, ondulado o plano; indeterminado mientras no se sabe el tamaño.",
		"Progresso em linha ou anel, ondulado ou plano; indeterminado enquanto o tamanho é desconhecido.",
		"Прогресс линией или кольцом, волной или ровно; неопределённый, пока объём неизвестен.",
		"La progression en ligne ou en anneau, ondulée ou plate ; indéterminée tant que la taille est inconnue.",
		"Çizgi ya da halka olarak ilerleme, dalgalı ya da düz; boyut bilinmezken belirsiz.",
		"Postęp jako linia lub pierścień, falisty lub płaski; nieokreślony, dopóki rozmiar jest nieznany.",
		"Avanzamento a linea o ad anello, ondulato o piatto; indeterminato finché la dimensione è ignota.",
		"Tiến độ dạng đường hoặc vòng, gợn sóng hoặc phẳng; không xác định khi chưa biết khối lượng.",
		"Kemajuan berupa garis atau cincin, bergelombang atau datar; tak tentu selama ukurannya belum diketahui.",
		"Поступ лінією чи кільцем, хвилею чи рівно; невизначений, доки обсяг невідомий.",
		"ความคืบหน้าแบบเส้นหรือวง แบบคลื่นหรือแบน แบบไม่ระบุเมื่อยังไม่รู้ขนาด",
		"تقدّم على شكل خط أو حلقة، متموج أو مسطح؛ غير محدد ما دام الحجم مجهولًا.")),
	("messages", "GoLoadingIndicator", "Control", """var wait := GoLoadingIndicator.new()
wait.contained = true
page.add_child(wait)""", T(
		"The Material 3 Expressive wait mark that changes shape; still under reduce_motion.",
		"모양이 바뀌는 Material 3 Expressive 기다림 표시 — reduce_motion 이면 멈춘다.",
		"形が変わる Material 3 Expressive の待機マーク。reduce_motion では止まる。",
		"会变形的 Material 3 Expressive 等待标记；开启 reduce_motion 时静止。",
		"會變形的 Material 3 Expressive 等待標記；開啟 reduce_motion 時靜止。",
		"La marca de espera de Material 3 Expressive que cambia de forma; quieta con reduce_motion.",
		"A marca de espera do Material 3 Expressive que muda de forma; parada com reduce_motion.",
		"Знак ожидания Material 3 Expressive, меняющий форму; неподвижен при reduce_motion.",
		"Le signe d'attente Material 3 Expressive qui change de forme ; immobile avec reduce_motion.",
		"Şekil değiştiren Material 3 Expressive bekleme işareti; reduce_motion açıkken durur.",
		"Znak oczekiwania Material 3 Expressive zmieniający kształt; nieruchomy przy reduce_motion.",
		"Il segno d'attesa Material 3 Expressive che cambia forma; fermo con reduce_motion.",
		"Dấu chờ đổi hình của Material 3 Expressive; đứng yên khi bật reduce_motion.",
		"Tanda tunggu Material 3 Expressive yang berubah bentuk; diam saat reduce_motion.",
		"Знак очікування Material 3 Expressive, що змінює форму; нерухомий при reduce_motion.",
		"เครื่องหมายรอแบบ Material 3 Expressive ที่เปลี่ยนรูปทรง หยุดนิ่งเมื่อเปิด reduce_motion",
		"علامة انتظار Material 3 Expressive التي تغيّر شكلها؛ ثابتة مع reduce_motion.")),
	("messages", "GoRefresh", "Control", """var refresh := GoRefresh.attach(feed)
refresh.refresh_requested.connect(func() -> void:
	await reload_posts()
	refresh.finish())""", T(
		"Pull a list down at its top to reload it.",
		"목록 맨 위에서 아래로 당겨 새로 고친다.",
		"リストの一番上で下に引いて再読み込み。",
		"在列表顶部向下拉即可刷新。",
		"在清單頂端向下拉即可重新整理。",
		"Tira de la lista hacia abajo desde arriba para recargarla.",
		"Puxe a lista para baixo no topo para recarregá-la.",
		"Потяните список вниз в самом верху, чтобы обновить.",
		"Tirez la liste vers le bas depuis le haut pour la recharger.",
		"Listeyi en üstteyken aşağı çekerek yenileyin.",
		"Pociągnij listę w dół na samej górze, by ją odświeżyć.",
		"Tira giù l'elenco dall'alto per ricaricarlo.",
		"Kéo danh sách xuống khi ở đầu để tải lại.",
		"Tarik daftar ke bawah dari atas untuk memuat ulang.",
		"Потягніть список униз на самому верху, щоб оновити.",
		"ดึงรายการลงที่ด้านบนสุดเพื่อโหลดใหม่",
		"اسحب القائمة إلى الأسفل من أعلاها لإعادة تحميلها.")),
	("messages", "GoStyle.alert", "GoStyle", """page.add_child(GoStyle.alert("Maintenance at 3 AM", GoTheme.WARNING))""", T(
		"An inline message in the info, success, warning or danger tone.",
		"정보·성공·주의·위험 톤의 본문 속 알림.",
		"情報・成功・注意・危険の色調のインラインメッセージ。",
		"信息、成功、警告或危险色调的内嵌消息。",
		"資訊、成功、警告或危險色調的內嵌訊息。",
		"Un mensaje en línea en tono de información, éxito, advertencia o peligro.",
		"Uma mensagem em linha no tom de informação, sucesso, aviso ou perigo.",
		"Встроенное сообщение в тоне информации, успеха, предупреждения или опасности.",
		"Un message intégré au ton info, succès, avertissement ou danger.",
		"Bilgi, başarı, uyarı ya da tehlike tonunda satır içi mesaj.",
		"Komunikat w treści w tonie informacji, sukcesu, ostrzeżenia lub zagrożenia.",
		"Un messaggio in linea nel tono informazione, successo, avviso o pericolo.",
		"Thông báo trong dòng với sắc thái thông tin, thành công, cảnh báo hoặc nguy hiểm.",
		"Pesan sebaris dengan nada info, sukses, peringatan, atau bahaya.",
		"Вбудоване повідомлення в тоні інформації, успіху, попередження чи небезпеки.",
		"ข้อความในเนื้อหาโทนข้อมูล สำเร็จ เตือน หรืออันตราย",
		"رسالة ضمن المحتوى بنبرة معلومات أو نجاح أو تحذير أو خطر.")),
	("messages", "GoStyle.skeleton · empty_state", "GoStyle", """page.add_child(GoStyle.skeleton(200))
page.add_child(GoStyle.empty_state(GoIconSet.BOX, "No items yet", false))""", T(
		"A placeholder while loading, and a message for an empty list.",
		"불러오는 동안의 자리 표시, 그리고 빈 목록 안내.",
		"読み込み中のプレースホルダーと、空のリストの案内。",
		"加载时的占位，以及空列表的提示。",
		"載入時的佔位，以及空清單的提示。",
		"Un marcador mientras carga y un mensaje para una lista vacía.",
		"Um marcador enquanto carrega e uma mensagem para uma lista vazia.",
		"Заглушка во время загрузки и сообщение для пустого списка.",
		"Un emplacement pendant le chargement, et un message pour une liste vide.",
		"Yüklenirken bir yer tutucu ve boş liste için bir mesaj.",
		"Zaślepka podczas ładowania i komunikat dla pustej listy.",
		"Un segnaposto durante il caricamento e un messaggio per un elenco vuoto.",
		"Khung giữ chỗ khi đang tải, và thông báo cho danh sách trống.",
		"Penanda tempat saat memuat, dan pesan untuk daftar kosong.",
		"Заглушка під час завантаження і повідомлення для порожнього списку.",
		"ตัวยึดที่ระหว่างโหลด และข้อความสำหรับรายการว่าง",
		"عنصر نائب أثناء التحميل، ورسالة لقائمة فارغة.")),
	("messages", "GoStyle.tooltip_node", "GoStyle", """func _make_custom_tooltip(text: String) -> Object:
	return GoStyle.tooltip_node(text)""", T(
		"A tooltip in the theme's style that never splits its words.",
		"테마 모양의 툴팁 — 단어를 쪼개지 않는다.",
		"テーマの見た目のツールチップ。単語を割らない。",
		"主题样式的工具提示，不会把单词拆开。",
		"主題樣式的工具提示，不會把單字拆開。",
		"Una ayuda emergente con el estilo del tema que nunca parte las palabras.",
		"Uma dica com o estilo do tema que nunca quebra as palavras.",
		"Подсказка в стиле темы, которая не разрывает слова.",
		"Une infobulle au style du thème qui ne coupe jamais les mots.",
		"Temanın stilinde, kelimeleri asla bölmeyen bir ipucu.",
		"Podpowiedź w stylu motywu, która nie dzieli słów.",
		"Un suggerimento nello stile del tema che non spezza mai le parole.",
		"Chú giải theo kiểu của theme, không bao giờ cắt chữ.",
		"Tooltip bergaya tema yang tidak pernah memotong kata.",
		"Підказка в стилі теми, яка не розриває слів.",
		"ทูลทิปตามสไตล์ธีม ไม่ตัดคำกลางคำ",
		"تلميح بنمط السمة لا يقسم الكلمات أبدًا.")),
	# ── App navigation
	("navigation", "GoAppBar", "PanelContainer", """var bar := GoAppBar.make("Inbox", GoIconSet.MENU, open_drawer)
bar.add_action(GoIconSet.SEARCH, &"search", open_search)
bar.follow(list)""", T(
		"The top app bar; lifts when the page scrolls; medium and large titles.",
		"위쪽 앱 바 — 페이지가 스크롤되면 떠오르고, 중간·큰 제목도 된다.",
		"上部のアプリバー。ページがスクロールすると浮き上がり、中・大の見出しも可能。",
		"顶部应用栏；页面滚动时浮起；支持中号与大号标题。",
		"頂部 App 列；頁面捲動時浮起；支援中型與大型標題。",
		"La barra superior de la app; se eleva al desplazar la página; títulos medianos y grandes.",
		"A barra superior do app; se eleva quando a página rola; títulos médios e grandes.",
		"Верхняя панель приложения; приподнимается при прокрутке; средний и крупный заголовки.",
		"La barre d'app du haut ; elle se soulève quand la page défile ; titres moyens et grands.",
		"Üst uygulama çubuğu; sayfa kayınca yükselir; orta ve büyük başlıklar.",
		"Górny pasek aplikacji; unosi się przy przewijaniu; średnie i duże tytuły.",
		"La barra superiore dell'app; si solleva quando la pagina scorre; titoli medi e grandi.",
		"Thanh ứng dụng trên cùng; nổi lên khi trang cuộn; tiêu đề cỡ vừa và lớn.",
		"Bilah aplikasi atas; terangkat saat halaman digulir; judul sedang dan besar.",
		"Верхня панель застосунку; піднімається під час прокручування; середній і великий заголовки.",
		"แถบแอปด้านบน ยกตัวเมื่อหน้าเลื่อน มีหัวเรื่องขนาดกลางและใหญ่",
		"شريط التطبيق العلوي؛ يرتفع عند تمرير الصفحة؛ عناوين متوسطة وكبيرة.")),
	("navigation", "GoNavBar", "PanelContainer", """var nav := GoNavBar.make([{"icon": GoIconSet.HOME, "text": "Home"},
	{"icon": GoIconSet.BELL, "text": "Alerts", "badge": 3}], 0, show_tab)
var rail := GoNavBar.rail([{"icon": GoIconSet.HOME, "text": "Home"}])""", T(
		"Three to five destinations along the bottom; a rail on wide screens.",
		"아래쪽 목적지 3~5개 — 넓은 화면에서는 레일.",
		"下部に 3～5 個の行き先。広い画面ではレール。",
		"底部 3～5 个目的地；宽屏上为侧边导航栏。",
		"底部 3～5 個目的地；寬螢幕上為側邊導覽列。",
		"De tres a cinco destinos abajo; un riel en pantallas anchas.",
		"De três a cinco destinos embaixo; um trilho em telas largas.",
		"От трёх до пяти пунктов внизу; боковая панель на широких экранах.",
		"Trois à cinq destinations en bas ; un rail sur grand écran.",
		"Altta üç ila beş hedef; geniş ekranlarda ray.",
		"Od trzech do pięciu miejsc na dole; szyna na szerokich ekranach.",
		"Da tre a cinque destinazioni in basso; una barra laterale sugli schermi larghi.",
		"Ba đến năm đích đến ở dưới; thanh bên trên màn hình rộng.",
		"Tiga sampai lima tujuan di bawah; rel di layar lebar.",
		"Від трьох до п'яти пунктів унизу; бічна панель на широких екранах.",
		"ปลายทางสามถึงห้าแห่งด้านล่าง เป็นเรลบนจอกว้าง",
		"من ثلاث إلى خمس وجهات في الأسفل؛ شريط جانبي على الشاشات العريضة.")),
	("navigation", "GoNavBar.drawer_list", "GoNavBar", """drawer.body.add_child(GoNavBar.drawer_list([{"icon": GoIconSet.HOME, "text": "Inbox"},
	{"icon": GoIconSet.STAR, "text": "Starred"}], 0, go_to))""", T(
		"Full-width destination rows for a drawer.",
		"서랍에 넣는 전체 폭 목적지 줄.",
		"ドロワー用の全幅の行き先の行。",
		"放在抽屉里的整宽目的地行。",
		"放在抽屜裡的整寬目的地列。",
		"Filas de destinos a todo el ancho para un cajón.",
		"Linhas de destinos de largura total para uma gaveta.",
		"Строки пунктов во всю ширину для шторки.",
		"Des rangées de destinations pleine largeur pour un tiroir.",
		"Çekmece için tam genişlikte hedef satırları.",
		"Wiersze miejsc na całą szerokość do szuflady.",
		"Righe di destinazioni a tutta larghezza per un cassetto.",
		"Các hàng đích đến rộng hết khung cho ngăn kéo.",
		"Baris tujuan selebar penuh untuk laci.",
		"Рядки пунктів на всю ширину для шухляди.",
		"แถวปลายทางเต็มความกว้างสำหรับลิ้นชัก",
		"صفوف وجهات بعرض كامل لدرج.")),
	("navigation", "GoFab", "Button", """var cart := GoFab.make(GoIconSet.PLUS, "Add to cart", add_to_cart)
cart.float_in(self, nav.get_combined_minimum_size().y)""", T(
		"The screen's main action floating in the corner; 40–96dp or extended with a label.",
		"구석에 떠 있는 화면의 주 동작 — 40~96dp, 또는 라벨이 붙은 확장형.",
		"隅に浮かぶ画面の主操作。40～96dp、またはラベル付きの拡張型。",
		"浮在角落的界面主操作；40～96dp，或带文字的扩展型。",
		"浮在角落的畫面主操作；40～96dp，或帶文字的延伸型。",
		"La acción principal flotando en la esquina; 40–96 dp o extendida con texto.",
		"A ação principal flutuando no canto; 40–96 dp ou estendida com rótulo.",
		"Главное действие экрана в углу; 40–96 dp или расширенная с подписью.",
		"L'action principale de l'écran, flottant dans le coin ; 40 à 96 dp ou étendue avec un libellé.",
		"Köşede yüzen ana eylem; 40–96 dp ya da etiketli genişletilmiş.",
		"Główna akcja ekranu w rogu; 40–96 dp lub rozszerzona z etykietą.",
		"L'azione principale fluttuante nell'angolo; 40–96 dp o estesa con etichetta.",
		"Hành động chính nổi ở góc; 40–96 dp hoặc dạng mở rộng có nhãn.",
		"Aksi utama layar yang mengambang di sudut; 40–96 dp atau diperluas dengan label.",
		"Головна дія екрана в куті; 40–96 dp або розширена з підписом.",
		"การกระทำหลักของหน้าจอที่ลอยอยู่ที่มุม 40–96dp หรือแบบขยายพร้อมป้าย",
		"الإجراء الرئيسي للشاشة عائمًا في الزاوية؛ 40–96dp أو موسّعًا مع تسمية.")),
	("navigation", "GoSearchBar", "PanelContainer", """var search := GoSearchBar.make("Search products", find)
search.add_action(GoIconSet.FILTER, &"Filter", open_filters)""", T(
		"The rounded search field with a clear button and trailing actions.",
		"지우기 버튼과 끝 동작이 있는 둥근 검색칸.",
		"クリアボタンと末尾の操作を持つ丸い検索欄。",
		"带清除按钮与尾部操作的圆角搜索框。",
		"具清除按鈕與尾端操作的圓角搜尋框。",
		"El campo de búsqueda redondeado con botón de borrar y acciones al final.",
		"O campo de busca arredondado com botão de limpar e ações no final.",
		"Скруглённое поле поиска с кнопкой очистки и действиями в конце.",
		"Le champ de recherche arrondi avec un bouton effacer et des actions en fin.",
		"Temizle düğmesi ve sonda eylemleri olan yuvarlak arama alanı.",
		"Zaokrąglone pole wyszukiwania z przyciskiem czyszczenia i akcjami na końcu.",
		"Il campo di ricerca arrotondato con pulsante per cancellare e azioni in fondo.",
		"Ô tìm kiếm bo tròn có nút xóa và các hành động ở cuối.",
		"Kolom pencarian membulat dengan tombol hapus dan aksi di ujung.",
		"Заокруглене поле пошуку з кнопкою очищення й діями в кінці.",
		"ช่องค้นหาแบบมน มีปุ่มล้างและการกระทำท้ายช่อง",
		"حقل بحث مستدير بزر مسح وإجراءات في النهاية.")),
	("navigation", "GoSplitButton", "HBoxContainer", """var send := GoSplitButton.make("Send", send_now, ["Send later", "Save as draft"])
send.chosen.connect(func(index: int) -> void: send_variant(index))""", T(
		"A main action with its variants behind an arrow.",
		"주 동작과, 화살표 뒤의 변형들.",
		"主操作と、矢印の奥にあるその変形。",
		"一个主操作，其变体藏在箭头后面。",
		"一個主操作，其變體藏在箭頭後面。",
		"Una acción principal con sus variantes tras una flecha.",
		"Uma ação principal com suas variantes atrás de uma seta.",
		"Главное действие и его варианты за стрелкой.",
		"Une action principale, avec ses variantes derrière une flèche.",
		"Bir ana eylem ve bir okun ardındaki türevleri.",
		"Główna akcja z wariantami ukrytymi za strzałką.",
		"Un'azione principale con le sue varianti dietro una freccia.",
		"Một hành động chính, các biến thể nằm sau mũi tên.",
		"Aksi utama dengan variasinya di balik panah.",
		"Головна дія та її варіанти за стрілкою.",
		"การกระทำหลักพร้อมตัวเลือกอื่นอยู่หลังลูกศร",
		"إجراء رئيسي وتنويعاته خلف سهم.")),
	("navigation", "GoTabView", "VBoxContainer", """var tabs := GoTabView.make(["Posts", "Photos", "Saved"], [posts, photos, saved])
tabs.tab_changed.connect(func(index: int) -> void: track_tab(index))""", T(
		"Tabs across the row over pages you swipe between.",
		"줄 전체에 펼친 탭과, 밀어서 넘기는 페이지.",
		"行いっぱいのタブと、スワイプで移るページ。",
		"铺满整行的标签页，与可滑动切换的页面。",
		"鋪滿整列的分頁標籤，與可滑動切換的頁面。",
		"Pestañas a lo ancho sobre páginas que se deslizan.",
		"Abas ao longo da linha sobre páginas que você desliza.",
		"Вкладки во всю ширину над страницами, которые листаются свайпом.",
		"Des onglets sur toute la largeur, au-dessus de pages qu'on fait glisser.",
		"Satır boyunca sekmeler ve kaydırarak geçilen sayfalar.",
		"Karty na całą szerokość nad stronami przełączanymi przesunięciem.",
		"Schede su tutta la riga sopra pagine da scorrere.",
		"Các tab trải hết hàng trên những trang vuốt để chuyển.",
		"Tab selebar baris di atas halaman yang digeser.",
		"Вкладки на всю ширину над сторінками, які гортаються свайпом.",
		"แท็บเต็มแถวเหนือหน้าที่ปัดเปลี่ยนได้",
		"علامات تبويب بعرض الصف فوق صفحات تتنقل بينها بالسحب.")),
	("navigation", "GoStyle.tabs", "GoStyle", """var row := GoStyle.tabs(["Overview", "Stats", "Gear"], 0, false, true)
row.tab_changed.connect(show_panel)""", T(
		"A tab row, at the start or spread over the row; the line runs the full width.",
		"탭 줄 — 앞에 모으거나 줄 전체에 펼친다. 아래 선은 끝까지 이어진다.",
		"タブ列。先頭に寄せるか行いっぱいに広げる。下線は端まで続く。",
		"标签行，可靠前排列或铺满整行；下划线贯穿全宽。",
		"標籤列，可靠前排列或鋪滿整列；底線貫穿全寬。",
		"Una fila de pestañas, al inicio o repartida; la línea llega de lado a lado.",
		"Uma fileira de abas, no início ou espalhada; a linha vai de ponta a ponta.",
		"Ряд вкладок — в начале или во всю ширину; линия идёт до конца.",
		"Une rangée d'onglets, au début ou répartie ; la ligne va d'un bord à l'autre.",
		"Bir sekme satırı, başta ya da yayılmış; çizgi tüm genişlikte uzanır.",
		"Rząd kart na początku lub rozłożony; linia biegnie na całą szerokość.",
		"Una fila di schede, all'inizio o distribuita; la linea va da un bordo all'altro.",
		"Hàng tab, dồn về đầu hoặc trải đều; đường kẻ chạy hết chiều rộng.",
		"Baris tab, di awal atau tersebar; garisnya membentang penuh.",
		"Ряд вкладок — на початку або на всю ширину; лінія йде до кінця.",
		"แถวแท็บ ชิดต้นแถวหรือกระจายเต็มแถว เส้นใต้ยาวเต็มความกว้าง",
		"صف علامات تبويب في البداية أو موزع؛ يمتد الخط بالعرض كله.")),
	("navigation", "GoStyle.bottom_app_bar", "GoStyle", """screen.set_bottom_bar(GoStyle.bottom_app_bar([{"icon": GoIconSet.SEARCH, "tooltip": &"search"},
	{"icon": GoIconSet.HEART, "tooltip": &"Like"}], GoFab.make(GoIconSet.PLUS)))""", T(
		"The bottom bar with icon actions and a FAB.",
		"아이콘 동작과 FAB 이 있는 아래 바.",
		"アイコン操作と FAB を持つ下部バー。",
		"带图标操作与 FAB 的底栏。",
		"具圖示操作與 FAB 的底欄。",
		"La barra inferior con acciones de icono y un FAB.",
		"A barra inferior com ações de ícone e um FAB.",
		"Нижняя панель с действиями-иконками и FAB.",
		"La barre du bas avec des actions en icône et un FAB.",
		"Simge eylemleri ve bir FAB içeren alt çubuk.",
		"Dolny pasek z akcjami-ikonami i FAB.",
		"La barra in basso con azioni a icona e un FAB.",
		"Thanh dưới có các hành động biểu tượng và một FAB.",
		"Bilah bawah dengan aksi ikon dan sebuah FAB.",
		"Нижня панель із діями-іконками та FAB.",
		"แถบล่างที่มีการกระทำแบบไอคอนและ FAB",
		"الشريط السفلي بإجراءات أيقونات وزر FAB.")),
	("navigation", "GoStyle.toolbar", "GoStyle", """page.add_child(GoStyle.toolbar([{"icon": GoIconSet.EDIT, "tooltip": &"Edit", "action": edit},
	{"icon": GoIconSet.TRASH, "tooltip": &"Delete", "action": delete}]))""", T(
		"A floating pill of icon actions.",
		"아이콘 동작을 담은 떠 있는 알약.",
		"アイコン操作をまとめた浮かぶピル。",
		"装着图标操作的浮动胶囊。",
		"裝著圖示操作的浮動膠囊。",
		"Una píldora flotante con acciones de icono.",
		"Uma pílula flutuante com ações de ícone.",
		"Плавающая капсула с действиями-иконками.",
		"Une pilule flottante d'actions en icône.",
		"Simge eylemlerinden oluşan yüzen bir hap.",
		"Pływająca kapsułka z akcjami-ikonami.",
		"Una pillola fluttuante di azioni a icona.",
		"Viên thuốc nổi chứa các hành động biểu tượng.",
		"Pil mengambang berisi aksi ikon.",
		"Плаваюча капсула з діями-іконками.",
		"แคปซูลลอยที่รวมการกระทำแบบไอคอน",
		"حبة عائمة من إجراءات الأيقونات.")),
	("navigation", "GoStyle.breadcrumb", "GoStyle", """page.add_child(GoStyle.breadcrumb(["Home", "Shop", "Swords"], go_to_level))""", T(
		"Where you are, as a path you can step back along.",
		"지금 있는 곳을, 되짚어 갈 수 있는 경로로.",
		"現在地を、さかのぼれる経路として。",
		"以可逐级返回的路径显示当前位置。",
		"以可逐層返回的路徑顯示目前位置。",
		"Dónde estás, como una ruta por la que volver atrás.",
		"Onde você está, como um caminho para voltar.",
		"Где вы сейчас, в виде пути, по которому можно вернуться.",
		"Où l'on est, sous forme de chemin pour revenir en arrière.",
		"Bulunduğunuz yer, geri dönülebilen bir yol olarak.",
		"Gdzie jesteś, jako ścieżka, którą można się cofnąć.",
		"Dove sei, come un percorso lungo cui tornare indietro.",
		"Vị trí hiện tại, dưới dạng đường dẫn để lùi lại.",
		"Posisi Anda, sebagai jalur untuk kembali.",
		"Де ви зараз — як шлях, яким можна повернутися.",
		"ตำแหน่งปัจจุบัน เป็นเส้นทางที่ย้อนกลับได้",
		"مكانك الحالي على شكل مسار يمكن الرجوع عبره.")),
	("navigation", "GoPagination", "HBoxContainer", """var pages := GoPagination.make(1, 12, load_page)
page.add_child(pages)""", T(
		"Numbered pages that keep the current one centred, or a single Load more row.",
		"현재 쪽을 가운데 두는 번호 쪽, 또는 '더 보기' 한 줄.",
		"現在のページを中央に保つ番号付きページ、または「もっと見る」1 行。",
		"让当前页居中的页码，或一行“加载更多”。",
		"讓目前頁置中的頁碼，或一列「載入更多」。",
		"Páginas numeradas que mantienen la actual en el centro, o una sola fila de Cargar más.",
		"Páginas numeradas que mantêm a atual no centro, ou uma única linha de Carregar mais.",
		"Нумерованные страницы с текущей по центру или одна строка «Загрузить ещё».",
		"Des pages numérotées qui gardent la courante au centre, ou une seule ligne Charger plus.",
		"Geçerli sayfayı ortada tutan numaralı sayfalar ya da tek bir Daha fazla satırı.",
		"Numerowane strony z bieżącą na środku albo jeden wiersz Wczytaj więcej.",
		"Pagine numerate che tengono al centro quella attuale, o una sola riga Carica altro.",
		"Các trang đánh số giữ trang hiện tại ở giữa, hoặc một hàng Tải thêm.",
		"Halaman bernomor yang menjaga halaman aktif di tengah, atau satu baris Muat lagi.",
		"Нумеровані сторінки з поточною посередині або один рядок «Завантажити ще».",
		"หน้าที่มีเลขกำกับโดยหน้าปัจจุบันอยู่กลาง หรือแถวโหลดเพิ่มแถวเดียว",
		"صفحات مرقمة تبقي الحالية في الوسط، أو صف واحد لتحميل المزيد.")),
	("navigation", "GoCarousel", "VBoxContainer", """var banners := GoCarousel.new()
banners.set_pages([promo, event, pack])""", T(
		"Banners and character select that never turn on their own unless asked.",
		"배너와 캐릭터 선택 — 요청하지 않으면 스스로 넘어가지 않는다.",
		"バナーとキャラクター選択。頼まれない限り勝手にめくれない。",
		"横幅广告与角色选择，除非要求否则不会自行翻页。",
		"橫幅與角色選擇，除非要求否則不會自行翻頁。",
		"Banners y selección de personaje que no pasan solos salvo que se pida.",
		"Banners e seleção de personagem que não passam sozinhos, a menos que se peça.",
		"Баннеры и выбор персонажа, которые сами не листаются, если не попросить.",
		"Bannières et choix de personnage qui ne tournent jamais seuls sauf demande.",
		"İstenmedikçe kendiliğinden dönmeyen afişler ve karakter seçimi.",
		"Banery i wybór postaci, które same nie przewijają się, chyba że o to poprosisz.",
		"Banner e selezione del personaggio che non girano da soli se non richiesto.",
		"Banner và chọn nhân vật không tự chuyển trừ khi được yêu cầu.",
		"Banner dan pemilihan karakter yang tidak berganti sendiri kecuali diminta.",
		"Банери та вибір персонажа, які самі не гортаються, якщо не попросити.",
		"แบนเนอร์และการเลือกตัวละครที่ไม่เลื่อนเองเว้นแต่สั่ง",
		"لافتات واختيار شخصيات لا تتقلب وحدها إلا عند الطلب.")),
	# ── Buttons, chips and choices
	("buttons", "GoStyle.button", "GoStyle", """row.add_child(GoStyle.button("Play", play, GoStyle.Tone.PRIMARY))
row.add_child(GoStyle.button("Details", open_details, GoStyle.Tone.OUTLINED))
row.add_child(GoStyle.button("Skip", skip, GoStyle.Tone.BARE))""", T(
		"Buttons in seven tones: normal, primary, outlined, text, compact, danger and filled danger.",
		"일곱 가지 톤의 버튼 — 보통, 주요, 외곽선, 글자, 작은, 위험, 채운 위험.",
		"7 種類の色調のボタン — 通常、主要、アウトライン、テキスト、小型、危険、塗りつぶし危険。",
		"七种色调的按钮：普通、主要、描边、文字、紧凑、危险与实心危险。",
		"七種色調的按鈕：一般、主要、外框、文字、精簡、危險與實心危險。",
		"Botones en siete tonos: normal, principal, contorno, texto, compacto, peligro y peligro relleno.",
		"Botões em sete tons: normal, principal, contorno, texto, compacto, perigo e perigo preenchido.",
		"Кнопки семи тонов: обычная, основная, контурная, текстовая, компактная, опасная и залитая опасная.",
		"Des boutons en sept tons : normal, principal, contour, texte, compact, danger et danger plein.",
		"Yedi tonda düğmeler: normal, birincil, çerçeveli, metin, kompakt, tehlike ve dolu tehlike.",
		"Przyciski w siedmiu tonach: zwykły, główny, obrysowany, tekstowy, kompaktowy, niebezpieczny i pełny niebezpieczny.",
		"Pulsanti in sette toni: normale, principale, contornato, testo, compatto, pericolo e pericolo pieno.",
		"Nút với bảy sắc thái: thường, chính, viền, chữ, gọn, nguy hiểm và nguy hiểm tô đầy.",
		"Tombol dalam tujuh nada: normal, utama, bergaris, teks, ringkas, bahaya, dan bahaya penuh.",
		"Кнопки семи тонів: звичайна, основна, контурна, текстова, компактна, небезпечна й залита небезпечна.",
		"ปุ่มเจ็ดโทน: ปกติ หลัก เส้นขอบ ข้อความ กะทัดรัด อันตราย และอันตรายแบบทึบ",
		"أزرار بسبع نبرات: عادي وأساسي ومحدد ونصي ومضغوط وخطر وخطر مملوء.")),
	("buttons", "GoStyle.glow", "GoStyle", """row.add_child(GoStyle.glow(GoStyle.button("Play", play, GoStyle.Tone.PRIMARY)))""", T(
		"Raises a filled button with a glow.",
		"채운 버튼을 빛으로 띄운다.",
		"塗りつぶしボタンを光で浮かせる。",
		"给实心按钮加光晕，使其浮起。",
		"為實心按鈕加光暈，使其浮起。",
		"Eleva un botón relleno con un brillo.",
		"Eleva um botão preenchido com um brilho.",
		"Приподнимает залитую кнопку свечением.",
		"Soulève un bouton plein avec un halo.",
		"Dolu bir düğmeyi parıltıyla yükseltir.",
		"Unosi wypełniony przycisk poświatą.",
		"Solleva un pulsante pieno con un bagliore.",
		"Làm nút tô đầy nổi lên bằng ánh sáng.",
		"Mengangkat tombol penuh dengan pendaran.",
		"Підносить залиту кнопку сяйвом.",
		"ยกปุ่มทึบให้ลอยด้วยแสงเรือง",
		"يرفع زرًا مملوءًا بتوهج.")),
	("buttons", "GoIconButton", "Button", """row.add_child(GoStyle.icon_button(GoIconSet.CLOSE, close, -1, &"close"))
var bell := GoIconButton.new()
bell.icon_name = GoIconSet.BELL""", T(
		"An icon-only button: small to see, 48dp to touch, named for screen readers.",
		"아이콘만 있는 버튼 — 보이는 건 작게, 누르는 건 48dp, 화면 낭독기용 이름.",
		"アイコンだけのボタン。見た目は小さく、押せる範囲は 48dp、読み上げ用の名前付き。",
		"仅图标的按钮：看起来小，可点区域 48dp，带屏幕阅读器名称。",
		"僅圖示的按鈕：看起來小，可點區域 48dp，帶螢幕閱讀器名稱。",
		"Un botón solo de icono: pequeño a la vista, 48 dp al tacto, con nombre para lectores de pantalla.",
		"Um botão só de ícone: pequeno à vista, 48 dp ao toque, com nome para leitores de tela.",
		"Кнопка-иконка: маленькая на вид, 48 dp для пальца, с именем для экранного диктора.",
		"Un bouton icône seule : petit à l'œil, 48 dp au toucher, nommé pour les lecteurs d'écran.",
		"Yalnızca simgeli düğme: görünüşte küçük, dokunmada 48 dp, ekran okuyucu için adlı.",
		"Przycisk z samą ikoną: mały dla oka, 48 dp dla palca, nazwany dla czytników ekranu.",
		"Un pulsante solo icona: piccolo alla vista, 48 dp al tocco, con nome per i lettori di schermo.",
		"Nút chỉ có biểu tượng: nhìn nhỏ, vùng chạm 48 dp, có tên cho trình đọc màn hình.",
		"Tombol ikon saja: kecil dilihat, 48 dp disentuh, bernama untuk pembaca layar.",
		"Кнопка-іконка: мала на вигляд, 48 dp для пальця, з назвою для читача екрана.",
		"ปุ่มไอคอนอย่างเดียว มองเห็นเล็ก แตะได้ 48dp มีชื่อสำหรับโปรแกรมอ่านหน้าจอ",
		"زر أيقونة فقط: صغير للعين، 48dp للمس، ومسمى لقارئات الشاشة.")),
	("buttons", "GoStyle.chip", "GoStyle", """row.add_child(GoStyle.chip("Rare", GoUi.color(GoTheme.INFO)))""", T(
		"A status or tag pill whose text always reads.",
		"글자가 늘 읽히는 상태·태그 알약.",
		"文字が必ず読める状態・タグのピル。",
		"文字始终清晰可读的状态或标签胶囊。",
		"文字始終清晰可讀的狀態或標籤膠囊。",
		"Una píldora de estado o etiqueta cuyo texto siempre se lee.",
		"Uma pílula de status ou etiqueta cujo texto sempre se lê.",
		"Капсула статуса или метки, текст которой всегда читается.",
		"Une pilule d'état ou d'étiquette dont le texte se lit toujours.",
		"Metni her zaman okunan bir durum ya da etiket hapı.",
		"Kapsułka statusu lub tagu, której tekst zawsze da się przeczytać.",
		"Una pillola di stato o etichetta il cui testo si legge sempre.",
		"Viên trạng thái hoặc nhãn luôn đọc rõ chữ.",
		"Pil status atau tag yang teksnya selalu terbaca.",
		"Капсула статусу чи мітки, текст якої завжди читається.",
		"แคปซูลสถานะหรือแท็กที่อ่านข้อความออกเสมอ",
		"حبة حالة أو وسم يُقرأ نصها دائمًا.")),
	("buttons", "GoStyle.filter_chip · input_chip", "GoStyle", """filters.add_child(GoStyle.filter_chip("In stock", false, refilter))
to.add_child(GoStyle.input_chip("Ann", remove_ann, GoIconSet.USER))""", T(
		"A chip that toggles, and an entered value with a ✕.",
		"켜고 끄는 칩, 그리고 ✕ 가 붙은 입력값.",
		"オン・オフするチップと、✕ 付きの入力値。",
		"可开关的标签，以及带 ✕ 的已输入值。",
		"可開關的標籤，以及帶 ✕ 的已輸入值。",
		"Un chip que se activa y desactiva, y un valor introducido con una ✕.",
		"Um chip que liga e desliga, e um valor digitado com um ✕.",
		"Переключаемый чип и введённое значение с ✕.",
		"Une puce qui s'active et se désactive, et une valeur saisie avec un ✕.",
		"Açılıp kapanan bir çip ve ✕ işaretli girilmiş bir değer.",
		"Przełączany chip i wprowadzona wartość z ✕.",
		"Un chip che si attiva e disattiva, e un valore inserito con una ✕.",
		"Chip bật tắt được, và giá trị đã nhập có dấu ✕.",
		"Chip yang bisa dinyalakan-matikan, dan nilai masukan dengan ✕.",
		"Перемикний чип і введене значення з ✕.",
		"ชิปที่เปิดปิดได้ และค่าที่ป้อนแล้วพร้อมปุ่ม ✕",
		"رقاقة تُبدَّل، وقيمة مُدخلة مع ✕.")),
	("buttons", "GoStyle.segmented", "GoStyle", """page.add_child(GoStyle.segmented(["Day", "Week", "Month"], 0, show_range))""", T(
		"Exactly one of a few options, joined in a row.",
		"몇 가지 중 정확히 하나 — 한 줄로 이어 붙인다.",
		"いくつかからちょうど一つ。一列につなげる。",
		"从几项中恰选一项，连成一行。",
		"從幾項中恰選一項，連成一列。",
		"Exactamente una de pocas opciones, unidas en una fila.",
		"Exatamente uma entre poucas opções, unidas numa linha.",
		"Ровно один из нескольких вариантов, соединённых в ряд.",
		"Exactement une option parmi quelques-unes, jointes en rangée.",
		"Birkaç seçenekten tam olarak biri, bir satırda birleşik.",
		"Dokładnie jedna z kilku opcji, połączonych w rzędzie.",
		"Esattamente una tra poche opzioni, unite in una riga.",
		"Đúng một trong vài lựa chọn, nối thành một hàng.",
		"Tepat satu dari beberapa pilihan, tersambung dalam satu baris.",
		"Рівно один із кількох варіантів, з'єднаних у ряд.",
		"เลือกได้หนึ่งเดียวจากไม่กี่ตัวเลือกที่ต่อกันเป็นแถว",
		"خيار واحد بالضبط من بضعة خيارات متصلة في صف.")),
	("buttons", "GoStyle.choice_grid", "GoStyle", """var skins := GoStyle.choice_grid([{"color": "f6cfae", "tooltip": "Peach"},
	{"color": "8d5a36", "tooltip": "Cocoa"}], 0, pick_skin)""", T(
		"Pick one swatch — a colour, a skin — from a grid.",
		"격자에서 견본 하나 — 색, 스킨 — 를 고른다.",
		"グリッドから見本を一つ — 色、スキン — 選ぶ。",
		"从网格中挑选一个色块——颜色或皮肤。",
		"從網格中挑選一個色塊——顏色或外觀。",
		"Elige una muestra —un color, un aspecto— de una cuadrícula.",
		"Escolha uma amostra — uma cor, uma skin — de uma grade.",
		"Выбор одного образца — цвета, облика — из сетки.",
		"Choisir un échantillon — une couleur, une apparence — dans une grille.",
		"Bir ızgaradan tek bir örnek — renk, görünüm — seçin.",
		"Wybór jednej próbki — koloru, skórki — z siatki.",
		"Scegli un campione — un colore, una skin — da una griglia.",
		"Chọn một mẫu — màu, giao diện — từ lưới.",
		"Pilih satu contoh — warna, skin — dari grid.",
		"Вибір одного зразка — кольору, обрису — із сітки.",
		"เลือกตัวอย่างหนึ่งชิ้น — สีหรือสกิน — จากกริด",
		"اختيار عينة واحدة — لون أو مظهر — من شبكة.")),
	("buttons", "GoStyle.radio_group", "GoStyle", """page.add_child(GoStyle.radio_group(["Easy", "Normal", "Hard"], 1))""", T(
		"Radio buttons, one of which is chosen.",
		"하나만 고르는 라디오 버튼.",
		"一つだけ選ぶラジオボタン。",
		"只能选其一的单选按钮。",
		"只能選其一的選項按鈕。",
		"Botones de opción, de los que se elige uno.",
		"Botões de opção, dos quais um é escolhido.",
		"Радиокнопки, из которых выбрана одна.",
		"Des boutons radio, dont un est choisi.",
		"Biri seçilen radyo düğmeleri.",
		"Przyciski opcji, z których wybrany jest jeden.",
		"Pulsanti di opzione, di cui uno è scelto.",
		"Nút radio, chọn một trong số đó.",
		"Tombol radio, salah satunya dipilih.",
		"Радіокнопки, з яких вибрано одну.",
		"ปุ่มตัวเลือกที่เลือกได้หนึ่งอัน",
		"أزرار اختيار يُختار أحدها.")),
	("buttons", "GoStyle.toggle · checkbox", "GoStyle", """var music := GoStyle.toggle("Music", false)
var terms := GoStyle.checkbox("I agree to the terms", false)""", T(
		"A switch and a check box with their labels.",
		"라벨이 붙은 스위치와 체크 상자.",
		"ラベル付きのスイッチとチェックボックス。",
		"带标签的开关与复选框。",
		"附標籤的開關與核取方塊。",
		"Un interruptor y una casilla con sus etiquetas.",
		"Um interruptor e uma caixa de seleção com rótulos.",
		"Переключатель и флажок с подписями.",
		"Un interrupteur et une case à cocher avec leurs libellés.",
		"Etiketleriyle bir anahtar ve bir onay kutusu.",
		"Przełącznik i pole wyboru z etykietami.",
		"Un interruttore e una casella di spunta con le loro etichette.",
		"Công tắc và ô đánh dấu kèm nhãn.",
		"Sakelar dan kotak centang dengan labelnya.",
		"Перемикач і прапорець із підписами.",
		"สวิตช์และช่องทำเครื่องหมายพร้อมป้ายกำกับ",
		"مفتاح تبديل ومربع اختيار مع تسمياتهما.")),
	# ── Inputs and pickers
	("inputs", "GoStyle.line_edit · textarea", "GoStyle", """var nickname := GoStyle.line_edit("Your name")
var note := GoStyle.textarea("Message", 4)""", T(
		"A one-line and a multi-line text field.",
		"한 줄, 여러 줄 글 입력칸.",
		"一行と複数行のテキスト欄。",
		"单行与多行文本框。",
		"單行與多行文字方塊。",
		"Un campo de texto de una línea y otro de varias.",
		"Um campo de texto de uma linha e outro de várias.",
		"Однострочное и многострочное текстовые поля.",
		"Un champ de texte sur une ligne et un sur plusieurs.",
		"Tek satırlık ve çok satırlı metin alanı.",
		"Jednowierszowe i wielowierszowe pole tekstowe.",
		"Un campo di testo a una riga e uno a più righe.",
		"Ô văn bản một dòng và nhiều dòng.",
		"Kolom teks satu baris dan banyak baris.",
		"Однорядкове та багаторядкове текстові поля.",
		"ช่องข้อความบรรทัดเดียวและหลายบรรทัด",
		"حقل نص بسطر واحد وحقل بعدة أسطر.")),
	("inputs", "GoField", "VBoxContainer", """var field := GoField.make("Nickname", GoStyle.line_edit(), "3–12 letters", false)
field.set_error("That name is taken")""", T(
		"Label, control and hint, with an error under the field that is wrong.",
		"라벨·컨트롤·힌트 — 틀린 칸 아래에 오류를 단다.",
		"ラベル・コントロール・ヒント。誤った欄の下にエラーを出す。",
		"标签、控件与提示，错误显示在出错的字段下方。",
		"標籤、控制項與提示，錯誤顯示在出錯的欄位下方。",
		"Etiqueta, control y pista, con el error bajo el campo equivocado.",
		"Rótulo, controle e dica, com o erro sob o campo errado.",
		"Подпись, элемент и подсказка; ошибка под неверным полем.",
		"Libellé, contrôle et indice, avec l'erreur sous le champ fautif.",
		"Etiket, denetim ve ipucu; hata, yanlış alanın altında.",
		"Etykieta, kontrolka i podpowiedź, z błędem pod złym polem.",
		"Etichetta, controllo e suggerimento, con l'errore sotto il campo sbagliato.",
		"Nhãn, điều khiển và gợi ý, lỗi hiện dưới ô bị sai.",
		"Label, kontrol, dan petunjuk, dengan galat di bawah kolom yang salah.",
		"Підпис, елемент і підказка; помилка під хибним полем.",
		"ป้าย คอนโทรล และคำใบ้ พร้อมข้อผิดพลาดใต้ช่องที่ผิด",
		"تسمية وعنصر تحكم وتلميح، مع خطأ تحت الحقل الخاطئ.")),
	("inputs", "GoInputGroup", "HBoxContainer", """var chat := GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": GoStyle.button("Send", send)})""", T(
		"An input and its buttons welded into one shape.",
		"입력칸과 그 버튼을 한 모양으로 붙인다.",
		"入力欄とそのボタンを一つの形に溶接する。",
		"把输入框与按钮焊接成一个整体。",
		"把輸入框與按鈕焊接成一個整體。",
		"Una entrada y sus botones soldados en una sola forma.",
		"Uma entrada e seus botões soldados em uma só forma.",
		"Поле ввода и его кнопки, сваренные в одну форму.",
		"Une saisie et ses boutons soudés en une seule forme.",
		"Bir giriş ve düğmeleri tek biçimde kaynaştırılmış.",
		"Pole i jego przyciski zespawane w jeden kształt.",
		"Un input e i suoi pulsanti saldati in un'unica forma.",
		"Ô nhập và các nút của nó hàn thành một khối.",
		"Input dan tombolnya dilas menjadi satu bentuk.",
		"Поле введення та його кнопки, зварені в одну форму.",
		"ช่องกรอกและปุ่มที่หลอมเป็นรูปเดียว",
		"حقل إدخال وأزراره ملحومة في شكل واحد.")),
	("inputs", "GoCombobox", "Button", """var friend := GoCombobox.make(friends, -1, "Find a friend")
friend.picked.connect(invite)""", T(
		"A picker that searches inside names, not just from their start.",
		"이름 처음만이 아니라 안쪽까지 찾는 선택기.",
		"名前の先頭だけでなく中まで探す選択欄。",
		"不仅从开头、也能在名称中间搜索的选择器。",
		"不僅從開頭、也能在名稱中間搜尋的選擇器。",
		"Un selector que busca dentro de los nombres, no solo al principio.",
		"Um seletor que busca dentro dos nomes, não só no início.",
		"Выбор с поиском внутри названий, а не только с начала.",
		"Un sélecteur qui cherche à l'intérieur des noms, pas seulement au début.",
		"Yalnızca baştan değil, adların içinde de arayan seçici.",
		"Wybór szukający wewnątrz nazw, nie tylko od początku.",
		"Un selettore che cerca dentro i nomi, non solo all'inizio.",
		"Bộ chọn tìm cả bên trong tên, không chỉ phần đầu.",
		"Pemilih yang mencari di dalam nama, bukan hanya dari awalnya.",
		"Вибір із пошуком усередині назв, а не лише з початку.",
		"ตัวเลือกที่ค้นหาภายในชื่อ ไม่ใช่แค่ต้นชื่อ",
		"منتقٍ يبحث داخل الأسماء لا من بدايتها فقط.")),
	("inputs", "GoCodeInput", "VBoxContainer", """var coupon := GoCodeInput.make(12, 4)
coupon.completed.connect(redeem)""", T(
		"Coupon and gift codes as cells; paste and IME input keep working.",
		"칸으로 보이는 쿠폰·선물 코드 — 붙여 넣기와 IME 입력이 그대로 된다.",
		"マスで表示するクーポン・ギフトコード。貼り付けと IME 入力もそのまま使える。",
		"以格子显示的优惠码与礼品码；粘贴与输入法照常可用。",
		"以格子顯示的優惠碼與禮物碼；貼上與輸入法照常可用。",
		"Códigos de cupón y regalo en celdas; pegar y la escritura con IME siguen funcionando.",
		"Códigos de cupom e presente em células; colar e a digitação por IME continuam funcionando.",
		"Коды купонов и подарков в ячейках; вставка и ввод через IME работают.",
		"Codes promo et cadeaux en cases ; le collage et la saisie IME marchent toujours.",
		"Hücreler halinde kupon ve hediye kodları; yapıştırma ve IME girişi çalışır.",
		"Kody kuponów i prezentów w komórkach; wklejanie i IME działają.",
		"Codici coupon e regalo a celle; incolla e input IME continuano a funzionare.",
		"Mã giảm giá và quà tặng dạng ô; dán và gõ IME vẫn hoạt động.",
		"Kode kupon dan hadiah sebagai sel; tempel dan input IME tetap berfungsi.",
		"Коди купонів і подарунків у клітинках; вставлення та введення через IME працюють.",
		"รหัสคูปองและของขวัญแบบช่อง วางและพิมพ์ผ่าน IME ได้ตามปกติ",
		"رموز القسائم والهدايا في خانات؛ يبقى اللصق والإدخال عبر IME يعملان.")),
	("inputs", "GoStyle.select · dropdown", "GoStyle", """var quality := GoStyle.select(["Low", "Medium", "High"])
var sort := GoStyle.dropdown("Sort", ["Newest", "Price"], sort_by)""", T(
		"A drop-down list, and a button that opens a menu.",
		"펼침 목록, 그리고 메뉴를 여는 버튼.",
		"ドロップダウンリストと、メニューを開くボタン。",
		"下拉列表，以及打开菜单的按钮。",
		"下拉清單，以及開啟選單的按鈕。",
		"Una lista desplegable y un botón que abre un menú.",
		"Uma lista suspensa e um botão que abre um menu.",
		"Выпадающий список и кнопка, открывающая меню.",
		"Une liste déroulante, et un bouton qui ouvre un menu.",
		"Açılır liste ve menü açan bir düğme.",
		"Lista rozwijana i przycisk otwierający menu.",
		"Un elenco a discesa e un pulsante che apre un menu.",
		"Danh sách thả xuống, và nút mở menu.",
		"Daftar tarik-turun, dan tombol yang membuka menu.",
		"Випадний список і кнопка, що відкриває меню.",
		"รายการแบบดรอปดาวน์ และปุ่มที่เปิดเมนู",
		"قائمة منسدلة، وزر يفتح قائمة.")),
	("inputs", "GoStyle.slider", "GoStyle", """var volume := GoStyle.slider(0.0, 1.0, 0.05)
volume.value_changed.connect(set_volume)""", T(
		"A slider in the theme's shape.",
		"테마 모양의 슬라이더.",
		"テーマの形のスライダー。",
		"主题样式的滑块。",
		"主題樣式的滑桿。",
		"Un deslizador con la forma del tema.",
		"Um controle deslizante com o formato do tema.",
		"Ползунок в форме темы.",
		"Un curseur à la forme du thème.",
		"Temanın biçiminde bir kaydırıcı.",
		"Suwak w kształcie motywu.",
		"Un cursore nella forma del tema.",
		"Thanh trượt theo hình dạng của theme.",
		"Penggeser berbentuk tema.",
		"Повзунок у формі теми.",
		"แถบเลื่อนตามรูปทรงของธีม",
		"منزلق بشكل السمة.")),
	("inputs", "GoRangeSlider", "Control", """var price := GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0)
price.change_ended.connect(func(low: float, high: float) -> void: refilter(low, high))""", T(
		"Two handles that never cross — a price or a level range.",
		"서로 넘지 않는 손잡이 두 개 — 가격·레벨 범위.",
		"交差しない 2 つのつまみ — 価格やレベルの範囲。",
		"两个不会交叉的滑钮——价格或等级范围。",
		"兩個不會交叉的滑鈕——價格或等級範圍。",
		"Dos tiradores que nunca se cruzan: un rango de precio o de nivel.",
		"Duas alças que nunca se cruzam: uma faixa de preço ou de nível.",
		"Два ползунка, которые не пересекаются, — диапазон цены или уровня.",
		"Deux poignées qui ne se croisent jamais : une plage de prix ou de niveau.",
		"Asla kesişmeyen iki tutamaç — fiyat ya da seviye aralığı.",
		"Dwa uchwyty, które się nie mijają — zakres ceny lub poziomu.",
		"Due maniglie che non si incrociano mai: una fascia di prezzo o di livello.",
		"Hai núm không bao giờ vượt qua nhau — khoảng giá hoặc cấp độ.",
		"Dua pegangan yang tak pernah bersilangan — rentang harga atau level.",
		"Два повзунки, що ніколи не перетинаються, — діапазон ціни чи рівня.",
		"สองที่จับที่ไม่ข้ามกัน — ช่วงราคาหรือเลเวล",
		"مقبضان لا يتقاطعان أبدًا — نطاق سعر أو مستوى.")),
	("inputs", "GoDatePicker", "Container", """var stay := GoDatePicker.make()
stay.range_mode = true
stay.range_picked.connect(func(start: Dictionary, end: Dictionary) -> void: book(start, end))""", T(
		"A month to tap; a range of days with range_mode.",
		"눌러 고르는 한 달 — range_mode 로 기간도.",
		"タップで選ぶ 1 か月。range_mode で期間も。",
		"点选的月历；开启 range_mode 可选日期范围。",
		"點選的月曆；開啟 range_mode 可選日期範圍。",
		"Un mes para tocar; un rango de días con range_mode.",
		"Um mês para tocar; um intervalo de dias com range_mode.",
		"Месяц для выбора касанием; диапазон дней с range_mode.",
		"Un mois à toucher ; une plage de jours avec range_mode.",
		"Dokunarak seçilen bir ay; range_mode ile gün aralığı.",
		"Miesiąc do stuknięcia; zakres dni z range_mode.",
		"Un mese da toccare; un intervallo di giorni con range_mode.",
		"Một tháng để chạm chọn; khoảng ngày với range_mode.",
		"Satu bulan untuk diketuk; rentang hari dengan range_mode.",
		"Місяць для вибору дотиком; діапазон днів із range_mode.",
		"ปฏิทินเดือนให้แตะเลือก เลือกช่วงวันได้ด้วย range_mode",
		"شهر للنقر عليه؛ ونطاق أيام مع range_mode.")),
	("inputs", "GoTimePicker", "Container", """var alarm := GoTimePicker.make(7, 30, func(hour: int, minute: int) -> void: set_alarm(hour, minute))
alarm.use_24h = true""", T(
		"The clock dial: the hour, then the minutes; 12 or 24 hours; Up and Down on a box.",
		"시계 다이얼 — 시 다음 분, 12·24시간, 칸에서 위·아래 키.",
		"時計の文字盤。時の次に分、12・24 時間、枠で上下キー。",
		"时钟表盘：先选小时再选分钟；12 或 24 小时；方框上可用上下键。",
		"時鐘錶盤：先選小時再選分鐘；12 或 24 小時；方框上可用上下鍵。",
		"La esfera del reloj: la hora y luego los minutos; 12 o 24 horas; Arriba y Abajo en una casilla.",
		"O mostrador do relógio: a hora, depois os minutos; 12 ou 24 horas; Cima e Baixo numa caixa.",
		"Циферблат: сначала час, потом минуты; 12 или 24 часа; стрелки вверх и вниз на поле.",
		"Le cadran : l'heure, puis les minutes ; 12 ou 24 heures ; Haut et Bas sur une case.",
		"Saat kadranı: önce saat, sonra dakika; 12 ya da 24 saat; kutuda Yukarı ve Aşağı.",
		"Tarcza zegara: godzina, potem minuty; 12 lub 24 godziny; strzałki w górę i w dół na polu.",
		"Il quadrante: prima l'ora, poi i minuti; 12 o 24 ore; Su e Giù su una casella.",
		"Mặt đồng hồ: giờ trước, phút sau; 12 hoặc 24 giờ; phím Lên và Xuống trên ô.",
		"Dial jam: jam lalu menit; 12 atau 24 jam; Atas dan Bawah pada kotak.",
		"Циферблат: спершу година, потім хвилини; 12 або 24 години; стрілки вгору й униз на полі.",
		"หน้าปัดนาฬิกา เลือกชั่วโมงก่อนแล้วนาที 12 หรือ 24 ชั่วโมง ใช้ปุ่มขึ้นลงบนช่องได้",
		"قرص الساعة: الساعة ثم الدقائق؛ 12 أو 24 ساعة؛ مفتاحا الأعلى والأسفل على الخانة.")),
	("inputs", "GoWheelPicker", "Control", """var amount := GoWheelPicker.make(["x1", "x5", "x10", "x50"], 0, set_amount)
row.add_child(amount)""", T(
		"A wheel that spins and settles one item on its band.",
		"돌다가 띠 위에 항목 하나를 세우는 휠.",
		"回って帯の上に一項目を止めるホイール。",
		"会转动并把一项停在中间色带上的滚轮。",
		"會轉動並把一項停在中間色帶上的滾輪。",
		"Una rueda que gira y deja un elemento en su banda.",
		"Uma roda que gira e assenta um item na sua faixa.",
		"Барабан, который крутится и останавливает один пункт на полосе.",
		"Une roue qui tourne et pose un élément sur sa bande.",
		"Dönen ve bir öğeyi bandına yerleştiren tekerlek.",
		"Koło, które się kręci i zatrzymuje jedną pozycję na pasku.",
		"Una ruota che gira e posa un elemento sulla sua fascia.",
		"Bánh xe quay rồi dừng một mục trên dải giữa.",
		"Roda yang berputar dan menaruh satu item di pitanya.",
		"Барабан, що крутиться й зупиняє один пункт на смузі.",
		"วงล้อที่หมุนแล้วหยุดรายการหนึ่งบนแถบกลาง",
		"عجلة تدور وتستقر على عنصر واحد في شريطها.")),
	("inputs", "GoStepper", "VBoxContainer", """var checkout := GoStepper.make([{"title": "Cart", "content": cart}, {"title": "Pay", "content": pay}])
checkout.finished.connect(place_order)""", T(
		"Numbered steps with Next and Back, down the page or in a row.",
		"다음·이전이 있는 번호 단계 — 세로로, 또는 한 줄로.",
		"「次へ」「戻る」付きの番号ステップ。縦並びか一列で。",
		"带“下一步/上一步”的编号步骤，纵向或横向排列。",
		"附「下一步／上一步」的編號步驟，縱向或橫向排列。",
		"Pasos numerados con Siguiente y Atrás, en vertical o en fila.",
		"Etapas numeradas com Próximo e Voltar, na vertical ou em linha.",
		"Нумерованные шаги с «Далее» и «Назад», по вертикали или в ряд.",
		"Des étapes numérotées avec Suivant et Retour, en colonne ou en rangée.",
		"İleri ve Geri ile numaralı adımlar, dikey ya da bir satırda.",
		"Numerowane kroki z Dalej i Wstecz, pionowo lub w rzędzie.",
		"Passi numerati con Avanti e Indietro, in colonna o in riga.",
		"Các bước đánh số có Tiếp và Quay lại, theo cột hoặc theo hàng.",
		"Langkah bernomor dengan Berikut dan Kembali, menurun atau berderet.",
		"Нумеровані кроки з «Далі» й «Назад», вертикально або в ряд.",
		"ขั้นตอนมีหมายเลขพร้อมปุ่มถัดไปและย้อนกลับ แนวตั้งหรือเป็นแถว",
		"خطوات مرقمة مع التالي والسابق، عموديًا أو في صف.")),
	# ── Lists, cards and data
	("lists", "GoStyle.list_row · list_button", "GoStyle", """page.add_child(GoStyle.list_button(GoIconSet.SETTINGS, "Settings", open_settings, Color.TRANSPARENT, "", false))""", T(
		"A list row with an icon, a title, a summary and a trailing mark.",
		"아이콘·제목·요약·끝 표시가 있는 목록 줄.",
		"アイコン・タイトル・概要・末尾マークを持つリスト行。",
		"带图标、标题、摘要与尾部标记的列表行。",
		"附圖示、標題、摘要與尾端標記的清單列。",
		"Una fila de lista con icono, título, resumen y marca final.",
		"Uma linha de lista com ícone, título, resumo e marca no fim.",
		"Строка списка с иконкой, заголовком, кратким текстом и меткой в конце.",
		"Une ligne de liste avec icône, titre, résumé et marque de fin.",
		"Simge, başlık, özet ve sonda işaret içeren liste satırı.",
		"Wiersz listy z ikoną, tytułem, opisem i znacznikiem na końcu.",
		"Una riga d'elenco con icona, titolo, riassunto e segno finale.",
		"Hàng danh sách có biểu tượng, tiêu đề, tóm tắt và dấu ở cuối.",
		"Baris daftar dengan ikon, judul, ringkasan, dan tanda di ujung.",
		"Рядок списку з іконкою, заголовком, коротким описом і міткою в кінці.",
		"แถวรายการพร้อมไอคอน หัวเรื่อง สรุป และเครื่องหมายท้าย",
		"صف قائمة بأيقونة وعنوان وملخص وعلامة في النهاية.")),
	("lists", "GoListView", "GoScroll", """var feed := GoListView.make(10000, 72.0, func(index: int) -> Control: return post_row(posts[index]))
feed.end_reached.connect(load_more)""", T(
		"Thousands of rows; only the ones in view are built.",
		"수천 줄 — 보이는 줄만 만든다.",
		"数千行でも、見えている行だけを作る。",
		"成千上万行，只创建可见的行。",
		"成千上萬列，只建立可見的列。",
		"Miles de filas; solo se crean las visibles.",
		"Milhares de linhas; só as visíveis são criadas.",
		"Тысячи строк; создаются только видимые.",
		"Des milliers de lignes ; seules celles visibles sont construites.",
		"Binlerce satır; yalnızca görünenler oluşturulur.",
		"Tysiące wierszy; tworzone są tylko widoczne.",
		"Migliaia di righe; si costruiscono solo quelle visibili.",
		"Hàng nghìn hàng; chỉ tạo những hàng đang thấy.",
		"Ribuan baris; hanya yang terlihat yang dibuat.",
		"Тисячі рядків; створюються лише видимі.",
		"หลายพันแถว สร้างเฉพาะแถวที่มองเห็น",
		"آلاف الصفوف؛ يُبنى منها الظاهر فقط.")),
	("lists", "GoReorderList", "Container", """var queue := GoReorderList.make([intro_row, theme_row, boss_row])
queue.reordered.connect(func(from: int, to: int) -> void: songs.insert(to, songs.pop_at(from)))""", T(
		"Rows you drag into order by a grip or a long press.",
		"손잡이나 길게 누르기로 끌어 순서를 바꾸는 줄.",
		"つまみか長押しでドラッグして並べ替える行。",
		"用拖柄或长按拖动来排序的行。",
		"用拖曳控點或長按拖動來排序的列。",
		"Filas que se reordenan arrastrando por un asa o con pulsación larga.",
		"Linhas que você reordena arrastando por uma alça ou com toque longo.",
		"Строки, которые перетаскивают за ручку или долгим нажатием.",
		"Des lignes qu'on remet en ordre par une poignée ou un appui long.",
		"Tutamaçtan ya da uzun basarak sürükleyip sıralanan satırlar.",
		"Wiersze przeciągane za uchwyt lub długim naciśnięciem.",
		"Righe da riordinare trascinando una maniglia o con pressione prolungata.",
		"Các hàng kéo để sắp xếp bằng tay nắm hoặc nhấn giữ.",
		"Baris yang diurutkan dengan menyeret pegangan atau tekan lama.",
		"Рядки, які перетягують за ручку або довгим натисканням.",
		"แถวที่ลากเรียงลำดับด้วยที่จับหรือการกดค้าง",
		"صفوف تُرتَّب بالسحب من مقبض أو بالضغط المطول.")),
	("lists", "GoSwipeRow", "Container", """inbox.add_child(GoSwipeRow.wrap(mail_row, {"icon": GoIconSet.TRASH, "text": "Delete",
	"tone": GoTheme.DANGER, "action": delete_mail}))""", T(
		"A row you swipe aside to delete or archive; the list still scrolls.",
		"옆으로 밀어 지우거나 보관하는 줄 — 목록 스크롤은 그대로.",
		"横にスワイプして削除・保管する行。リストのスクロールはそのまま。",
		"侧滑即可删除或归档的行；列表照常滚动。",
		"側滑即可刪除或封存的列；清單照常捲動。",
		"Una fila que se desliza a un lado para borrar o archivar; la lista sigue desplazándose.",
		"Uma linha que você desliza para apagar ou arquivar; a lista continua rolando.",
		"Строка, которую смахивают, чтобы удалить или в архив; список по-прежнему прокручивается.",
		"Une ligne qu'on balaie pour supprimer ou archiver ; la liste défile toujours.",
		"Silmek ya da arşivlemek için kenara kaydırılan satır; liste yine kayar.",
		"Wiersz przesuwany w bok, by usunąć lub zarchiwizować; lista dalej się przewija.",
		"Una riga da scorrere di lato per eliminare o archiviare; l'elenco scorre ancora.",
		"Hàng vuốt sang bên để xóa hoặc lưu trữ; danh sách vẫn cuộn được.",
		"Baris yang digeser untuk menghapus atau mengarsipkan; daftar tetap bisa digulir.",
		"Рядок, який змахують, щоб видалити чи заархівувати; список і далі прокручується.",
		"แถวที่ปัดออกด้านข้างเพื่อลบหรือเก็บถาวร รายการยังเลื่อนได้",
		"صف تسحبه جانبًا للحذف أو الأرشفة؛ تبقى القائمة قابلة للتمرير.")),
	("lists", "GoTable", "VBoxContainer", """var board := GoTable.make(["Name", {"text": "Score", "numeric": true}], [["Ann", 9124], ["Ben", 91240]])
board.row_selected.connect(open_profile)""", T(
		"Sortable headers and selectable rows; numbers sort as numbers.",
		"정렬되는 머리와 고를 수 있는 줄 — 숫자는 숫자로 정렬.",
		"並べ替えできる見出しと選べる行。数値は数値として並ぶ。",
		"可排序的表头与可选择的行；数字按数值排序。",
		"可排序的表頭與可選取的列；數字按數值排序。",
		"Cabeceras ordenables y filas seleccionables; los números se ordenan como números.",
		"Cabeçalhos ordenáveis e linhas selecionáveis; números se ordenam como números.",
		"Сортируемые заголовки и выбираемые строки; числа сортируются как числа.",
		"Des en-têtes triables et des lignes sélectionnables ; les nombres se trient comme des nombres.",
		"Sıralanabilir başlıklar ve seçilebilir satırlar; sayılar sayı olarak sıralanır.",
		"Sortowalne nagłówki i wybieralne wiersze; liczby sortują się jak liczby.",
		"Intestazioni ordinabili e righe selezionabili; i numeri si ordinano come numeri.",
		"Tiêu đề sắp xếp được và hàng chọn được; số được sắp như số.",
		"Header yang bisa diurutkan dan baris yang bisa dipilih; angka diurutkan sebagai angka.",
		"Заголовки з сортуванням і рядки з вибором; числа сортуються як числа.",
		"หัวตารางที่เรียงได้และแถวที่เลือกได้ ตัวเลขเรียงแบบตัวเลข",
		"عناوين قابلة للفرز وصفوف قابلة للاختيار؛ تُرتَّب الأرقام كأرقام.")),
	("lists", "GoStyle.card · item_card", "GoStyle", """var card := GoStyle.card()
card.add_child(GoStyle.label("Daily quest"))
popup.add_child(GoStyle.item_card({"title": "Rusty sword", "subtitle": "Common"}))""", T(
		"A card, and the detail card of a picked item.",
		"카드, 그리고 고른 아이템의 상세 카드.",
		"カードと、選んだアイテムの詳細カード。",
		"卡片，以及所选物品的详情卡。",
		"卡片，以及所選物品的詳細卡。",
		"Una tarjeta y la ficha de detalle de un objeto elegido.",
		"Um cartão e o cartão de detalhes de um item escolhido.",
		"Карточка и карточка подробностей выбранного предмета.",
		"Une carte, et la fiche détaillée d'un objet choisi.",
		"Bir kart ve seçilen eşyanın ayrıntı kartı.",
		"Karta i karta szczegółów wybranego przedmiotu.",
		"Una scheda e la scheda di dettaglio di un oggetto scelto.",
		"Thẻ, và thẻ chi tiết của vật phẩm đã chọn.",
		"Kartu, dan kartu detail item yang dipilih.",
		"Картка й картка подробиць обраного предмета.",
		"การ์ด และการ์ดรายละเอียดของไอเท็มที่เลือก",
		"بطاقة، وبطاقة تفاصيل العنصر المختار.")),
	("lists", "GoStyle.avatar", "GoStyle", """row.add_child(GoStyle.avatar("AK", 40))""", T(
		"Initials or a picture in a disc.",
		"원 안의 이니셜이나 사진.",
		"円の中のイニシャルか画像。",
		"圆形中的首字母或图片。",
		"圓形中的首字母或圖片。",
		"Iniciales o una imagen en un disco.",
		"Iniciais ou uma imagem num disco.",
		"Инициалы или картинка в круге.",
		"Des initiales ou une image dans un disque.",
		"Bir daire içinde baş harfler ya da resim.",
		"Inicjały lub obraz w kółku.",
		"Iniziali o un'immagine in un disco.",
		"Chữ viết tắt hoặc ảnh trong hình tròn.",
		"Inisial atau gambar dalam lingkaran.",
		"Ініціали або зображення в колі.",
		"อักษรย่อหรือรูปในวงกลม",
		"أحرف أولى أو صورة داخل قرص.")),
	("lists", "GoStyle.label", "GoStyle", """page.add_child(GoStyle.label("Level 12", GoTheme.ROLE_TITLE))
page.add_child(GoStyle.label("Next level in 340 XP", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))""", T(
		"Text in one of seven type roles, from micro to title.",
		"마이크로부터 제목까지 일곱 가지 글자 역할 중 하나로.",
		"マイクロから見出しまで 7 種類の文字の役割から一つで。",
		"使用从 micro 到 title 的七种文字角色之一的文本。",
		"使用從 micro 到 title 的七種文字角色之一的文字。",
		"Texto en uno de siete papeles tipográficos, de micro a título.",
		"Texto em um de sete papéis tipográficos, de micro a título.",
		"Текст в одной из семи типографских ролей, от micro до title.",
		"Du texte dans l'un des sept rôles typographiques, de micro à titre.",
		"Mikrodan başlığa yedi yazı rolünden birinde metin.",
		"Tekst w jednej z siedmiu ról typograficznych, od micro do title.",
		"Testo in uno dei sette ruoli tipografici, da micro a titolo.",
		"Văn bản theo một trong bảy vai trò chữ, từ micro đến title.",
		"Teks dalam salah satu dari tujuh peran tipografi, dari mikro hingga judul.",
		"Текст в одній із семи типографських ролей, від micro до title.",
		"ข้อความในบทบาทตัวอักษรหนึ่งในเจ็ดแบบ ตั้งแต่ micro ถึง title",
		"نص بأحد سبعة أدوار للخط، من micro إلى title.")),
	# ── HUD and game shapes
	("hud", "GoBar", "Control", """var hp := GoBar.new()
hp.label_text = "HP"
hp.set_values(320, 500)""", T(
		"HP, MP and XP bars with a value, a fraction or a percent.",
		"값·분수·퍼센트를 보여 주는 HP·MP·XP 막대.",
		"値・分数・パーセントを表示する HP・MP・XP バー。",
		"显示数值、分数或百分比的 HP、MP、XP 条。",
		"顯示數值、分數或百分比的 HP、MP、XP 條。",
		"Barras de PV, PM y XP con valor, fracción o porcentaje.",
		"Barras de HP, MP e XP com valor, fração ou porcentagem.",
		"Полосы HP, MP и XP со значением, дробью или процентом.",
		"Des barres de PV, PM et XP avec valeur, fraction ou pourcentage.",
		"Değer, kesir ya da yüzde gösteren HP, MP ve XP çubukları.",
		"Paski HP, MP i XP z wartością, ułamkiem lub procentem.",
		"Barre HP, MP e XP con valore, frazione o percentuale.",
		"Thanh HP, MP và XP hiện giá trị, phân số hoặc phần trăm.",
		"Bilah HP, MP, dan XP dengan nilai, pecahan, atau persen.",
		"Смуги HP, MP та XP зі значенням, дробом або відсотком.",
		"แถบ HP MP และ XP แสดงค่า เศษส่วน หรือเปอร์เซ็นต์",
		"أشرطة HP وMP وXP بقيمة أو كسر أو نسبة مئوية.")),
	("hud", "GoSlot", "Button", """var potion := GoSlot.new()
potion.icon_name = GoIconSet.POTION
potion.quantity = 12
potion.start_cooldown(5.0)""", T(
		"A quick slot: icon, quantity, cooldown and shortcut on one face.",
		"퀵슬롯 — 아이콘·수량·쿨다운·단축키를 한 면에.",
		"クイックスロット。アイコン・数量・クールダウン・ショートカットを一面に。",
		"快捷栏格：图标、数量、冷却与快捷键集于一面。",
		"快捷欄格：圖示、數量、冷卻與快捷鍵集於一面。",
		"Una ranura rápida: icono, cantidad, enfriamiento y atajo en una sola cara.",
		"Um slot rápido: ícone, quantidade, recarga e atalho numa só face.",
		"Быстрый слот: иконка, количество, перезарядка и клавиша на одной грани.",
		"Un emplacement rapide : icône, quantité, recharge et raccourci sur une seule face.",
		"Hızlı yuva: simge, miktar, bekleme süresi ve kısayol tek yüzde.",
		"Szybki slot: ikona, ilość, odnowienie i skrót na jednej ściance.",
		"Uno slot rapido: icona, quantità, ricarica e scorciatoia su un'unica faccia.",
		"Ô nhanh: biểu tượng, số lượng, hồi chiêu và phím tắt trên một mặt.",
		"Slot cepat: ikon, jumlah, jeda, dan pintasan dalam satu muka.",
		"Швидкий слот: іконка, кількість, перезаряджання й клавіша на одній грані.",
		"ช่องด่วน ไอคอน จำนวน คูลดาวน์ และปุ่มลัดบนหน้าเดียว",
		"خانة سريعة: أيقونة وكمية وفترة تهدئة واختصار على وجه واحد.")),
	("hud", "GoSlotGrid", "HFlowContainer", """var bag := GoSlotGrid.new()
bag.set_cell(0, {"icon": GoIconSet.POTION, "quantity": 12})""", T(
		"An inventory grid; items can be dragged between cells.",
		"인벤토리 격자 — 칸 사이로 아이템을 끌어 옮길 수 있다.",
		"インベントリのグリッド。マス間でアイテムをドラッグできる。",
		"背包网格；物品可在格子间拖动。",
		"背包網格；物品可在格子間拖動。",
		"Una cuadrícula de inventario; los objetos se arrastran entre celdas.",
		"Uma grade de inventário; os itens podem ser arrastados entre células.",
		"Сетка инвентаря; предметы можно перетаскивать между ячейками.",
		"Une grille d'inventaire ; on peut glisser les objets d'une case à l'autre.",
		"Envanter ızgarası; eşyalar hücreler arasında sürüklenebilir.",
		"Siatka ekwipunku; przedmioty można przeciągać między komórkami.",
		"Una griglia d'inventario; gli oggetti si trascinano tra le celle.",
		"Lưới túi đồ; vật phẩm có thể kéo giữa các ô.",
		"Grid inventaris; item bisa diseret antarsel.",
		"Сітка інвентарю; предмети можна перетягувати між клітинками.",
		"กริดคลังไอเท็ม ลากไอเท็มระหว่างช่องได้",
		"شبكة مخزون؛ يمكن سحب العناصر بين الخانات.")),
	("hud", "GoJoystick", "Control", """var pad := GoJoystick.new()
pad.mode = GoJoystick.Mode.FOLLOW
pad.moved.connect(func(direction: Vector2) -> void: player.move(direction))""", T(
		"A virtual stick — fixed, following the thumb, or relative.",
		"가상 스틱 — 고정, 엄지 따라가기, 상대.",
		"仮想スティック — 固定、親指に追従、相対。",
		"虚拟摇杆——固定、跟随拇指或相对模式。",
		"虛擬搖桿——固定、跟隨拇指或相對模式。",
		"Un stick virtual: fijo, que sigue al pulgar o relativo.",
		"Um analógico virtual: fixo, seguindo o polegar ou relativo.",
		"Виртуальный стик — фиксированный, следующий за пальцем или относительный.",
		"Un stick virtuel : fixe, qui suit le pouce, ou relatif.",
		"Sanal çubuk — sabit, başparmağı izleyen ya da göreli.",
		"Wirtualna gałka — stała, podążająca za kciukiem lub względna.",
		"Uno stick virtuale: fisso, che segue il pollice o relativo.",
		"Cần ảo — cố định, theo ngón cái, hoặc tương đối.",
		"Stik virtual — tetap, mengikuti jempol, atau relatif.",
		"Віртуальний стік — фіксований, що йде за пальцем, або відносний.",
		"จอยสติกเสมือน แบบคงที่ ตามนิ้วโป้ง หรือแบบสัมพัทธ์",
		"عصا تحكم افتراضية — ثابتة أو تتبع الإبهام أو نسبية.")),
	("hud", "GoKbd", "HBoxContainer", """hint.add_child(GoKbd.for_action(&"interact"))""", T(
		"Key caps that read the real binding, so rebinding never makes the hint lie.",
		"실제 키 설정을 읽는 키캡 — 키를 바꿔도 안내가 거짓이 되지 않는다.",
		"実際の割り当てを読むキーキャップ。割り当てを変えても案内が嘘にならない。",
		"读取真实按键绑定的键帽，改键后提示也不会出错。",
		"讀取真實按鍵綁定的鍵帽，改鍵後提示也不會出錯。",
		"Teclas que leen la asignación real, así cambiarla nunca falsea la pista.",
		"Teclas que leem a atribuição real, então remapear nunca faz a dica mentir.",
		"Клавиши, читающие реальное назначение, — подсказка не врёт после переназначения.",
		"Des touches qui lisent l'affectation réelle : la réaffecter ne fait jamais mentir l'indice.",
		"Gerçek atamayı okuyan tuşlar; yeniden atamak ipucunu yalancı yapmaz.",
		"Klawisze czytające prawdziwe przypisanie, więc zmiana nie okłamie podpowiedzi.",
		"Tasti che leggono l'assegnazione reale, così riassegnarli non rende falso il suggerimento.",
		"Phím đọc cách gán thật, đổi phím cũng không làm gợi ý sai.",
		"Tombol yang membaca pemetaan sebenarnya, jadi memetakan ulang tak membuat petunjuk bohong.",
		"Клавіші, що читають справжнє призначення, — підказка не бреше після перепризначення.",
		"แป้นที่อ่านการกำหนดปุ่มจริง เปลี่ยนปุ่มแล้วคำแนะนำก็ไม่ผิด",
		"أغطية مفاتيح تقرأ الربط الفعلي، فلا يكذب التلميح بعد إعادة الربط.")),
	("hud", "GoChoiceColumn", "Control", """var animals := GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig", "Cow"], 4, summon)
animals.set_selected(2, true)
side_bar.add_center(animals)""", T(
		"A short column of choices tapped once — a summon list; the game marks any number of rows.",
		"한 번 눌러 고르는 짧은 세로 목록 — 소환 목록. 게임이 여러 칸을 표시할 수 있다.",
		"一度タップで選ぶ短い縦リスト — 召喚リスト。ゲームが何行でも印を付けられる。",
		"点一下即可选的短竖列——召唤列表；游戏可标记任意多行。",
		"點一下即可選的短直列——召喚清單；遊戲可標記任意多列。",
		"Una columna corta de opciones que se tocan una vez —una lista de invocación—; el juego marca las filas que quiera.",
		"Uma coluna curta de opções tocadas uma vez — uma lista de invocação; o jogo marca quantas linhas quiser.",
		"Короткий столбец вариантов в одно касание — список призыва; игра отмечает сколько угодно строк.",
		"Une courte colonne de choix qu'on touche une fois — une liste d'invocation ; le jeu marque autant de lignes qu'il veut.",
		"Tek dokunuşla seçilen kısa bir sütun — çağırma listesi; oyun istediği kadar satırı işaretler.",
		"Krótka kolumna wyborów jednym stuknięciem — lista przywołań; gra zaznacza dowolnie wiele wierszy.",
		"Una breve colonna di scelte da toccare una volta — un elenco di evocazioni; il gioco segna quante righe vuole.",
		"Cột lựa chọn ngắn chạm một lần — danh sách triệu hồi; trò chơi đánh dấu bao nhiêu hàng tùy ý.",
		"Kolom pilihan pendek yang diketuk sekali — daftar pemanggilan; game menandai berapa pun baris.",
		"Короткий стовпець варіантів одним дотиком — список виклику; гра позначає скільки завгодно рядків.",
		"คอลัมน์ตัวเลือกสั้นๆ ที่แตะครั้งเดียว — รายการอัญเชิญ เกมทำเครื่องหมายได้หลายแถว",
		"عمود قصير من الخيارات يُنقر مرة واحدة — قائمة استدعاء؛ تحدد اللعبة أي عدد من الصفوف.")),
	("hud", "GoRewardCalendar", "VBoxContainer", """var attendance := GoRewardCalendar.make(days, claimed_until)
attendance.claimed.connect(func(day: int) -> void: server.claim_day(day))""", T(
		"Daily attendance rewards; only today can be pressed.",
		"매일 출석 보상 — 오늘 칸만 누를 수 있다.",
		"毎日の出席報酬。押せるのは今日だけ。",
		"每日签到奖励；只能点今天。",
		"每日簽到獎勵；只能點今天。",
		"Recompensas de asistencia diaria; solo se puede pulsar hoy.",
		"Recompensas de presença diária; só o dia de hoje pode ser tocado.",
		"Ежедневные награды за вход; нажать можно только сегодня.",
		"Récompenses de présence quotidienne ; seul aujourd'hui peut être touché.",
		"Günlük giriş ödülleri; yalnızca bugüne basılabilir.",
		"Codzienne nagrody za obecność; nacisnąć można tylko dzisiejszy dzień.",
		"Premi di presenza giornaliera; si può premere solo oggi.",
		"Phần thưởng điểm danh hằng ngày; chỉ nhấn được hôm nay.",
		"Hadiah kehadiran harian; hanya hari ini yang bisa ditekan.",
		"Щоденні нагороди за відвідування; натиснути можна лише сьогодні.",
		"รางวัลเช็กอินรายวัน กดได้เฉพาะวันนี้",
		"مكافآت حضور يومية؛ لا يُضغط إلا على اليوم.")),
	("hud", "GoRadar", "Control", """var stats := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45})
stats.set_compare(with_new_sword)""", T(
		"The stat pentagon, with a dashed line to compare gear.",
		"능력치 오각형 — 장비 비교는 점선으로.",
		"ステータスの五角形。装備の比較は点線で。",
		"属性五边形，用虚线比较装备。",
		"屬性五邊形，以虛線比較裝備。",
		"El pentágono de atributos, con una línea discontinua para comparar equipo.",
		"O pentágono de atributos, com uma linha tracejada para comparar equipamentos.",
		"Пятиугольник характеристик с пунктиром для сравнения снаряжения.",
		"Le pentagone des statistiques, avec un trait pointillé pour comparer l'équipement.",
		"Ekipmanı karşılaştırmak için kesikli çizgili istatistik beşgeni.",
		"Pięciokąt statystyk z linią przerywaną do porównania ekwipunku.",
		"Il pentagono delle statistiche, con una linea tratteggiata per confrontare l'equipaggiamento.",
		"Ngũ giác chỉ số, có đường nét đứt để so sánh trang bị.",
		"Segi lima statistik, dengan garis putus-putus untuk membandingkan perlengkapan.",
		"П'ятикутник характеристик із пунктиром для порівняння спорядження.",
		"ห้าเหลี่ยมค่าสถานะ มีเส้นประไว้เทียบอุปกรณ์",
		"مخمس الإحصاءات، بخط متقطع لمقارنة العتاد.")),
	("hud", "GoDonut", "Control", """var share := GoDonut.make([{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340}])
card.add_child(share.legend())""", T(
		"Shares as slices, with a legend in words as well as colour.",
		"몫을 조각으로 — 범례는 색만이 아니라 말로도.",
		"割合を扇形で。凡例は色だけでなく言葉でも。",
		"以扇形显示占比，图例不仅有颜色也有文字。",
		"以扇形顯示占比，圖例不僅有顏色也有文字。",
		"Partes como porciones, con leyenda en palabras además de color.",
		"Partes como fatias, com legenda em palavras além de cor.",
		"Доли в виде секторов, с легендой не только цветом, но и словами.",
		"Des parts en portions, avec une légende en mots et pas seulement en couleur.",
		"Payları dilimler halinde, yalnızca renkle değil sözcüklerle de açıklayan bir gösterge.",
		"Udziały jako wycinki, z legendą w słowach, nie tylko kolorem.",
		"Quote come spicchi, con una legenda in parole oltre che a colori.",
		"Tỉ phần dạng miếng, có chú giải bằng chữ chứ không chỉ màu.",
		"Bagian sebagai irisan, dengan legenda berupa kata, bukan hanya warna.",
		"Частки у вигляді секторів, з легендою не лише кольором, а й словами.",
		"สัดส่วนเป็นชิ้น พร้อมคำอธิบายเป็นคำ ไม่ใช่แค่สี",
		"حصص على شكل شرائح، مع وسيلة إيضاح بالكلمات لا باللون فقط.")),
	("hud", "GoZoomView", "Control", """var map := GoZoomView.wrap(world_map, 4.0)
map.custom_minimum_size.y = 320
page.add_child(map)""", T(
		"Pinch, wheel and double tap to zoom a map; pans inside its edges.",
		"지도를 두 손가락·휠·두 번 탭으로 확대 — 가장자리 안에서 이동.",
		"地図をピンチ・ホイール・ダブルタップで拡大。端の内側で移動。",
		"双指、滚轮或双击缩放地图；在边界内平移。",
		"雙指、滾輪或點兩下縮放地圖；在邊界內平移。",
		"Pellizca, usa la rueda o toca dos veces para ampliar un mapa; se desplaza dentro de sus bordes.",
		"Pinça, roda ou toque duplo para ampliar um mapa; desloca-se dentro das bordas.",
		"Масштаб карты щипком, колесом или двойным касанием; сдвиг в пределах краёв.",
		"Pincer, molette ou double toucher pour zoomer une carte ; on la déplace dans ses bords.",
		"Haritayı kıstırarak, tekerlekle ya da çift dokunarak yakınlaştırın; kenarları içinde kaydırılır.",
		"Szczypnięcie, kółko lub podwójne stuknięcie powiększa mapę; przesuwa się w jej granicach.",
		"Pizzica, rotella o doppio tocco per ingrandire una mappa; si sposta entro i bordi.",
		"Chụm, cuộn chuột hoặc chạm hai lần để phóng bản đồ; kéo trong giới hạn của nó.",
		"Cubit, roda, atau ketuk dua kali untuk memperbesar peta; bergeser di dalam tepinya.",
		"Масштаб карти щипком, коліщатком або подвійним дотиком; зсув у межах країв.",
		"ถ่างนิ้ว เลื่อนล้อ หรือแตะสองครั้งเพื่อซูมแผนที่ เลื่อนได้ภายในขอบ",
		"قرّب الخريطة بالقرص أو العجلة أو النقر المزدوج؛ وتتحرك داخل حوافها.")),
	("hud", "GoStyle.hud_panel · overlay_panel", "GoStyle", """var bars := GoStyle.hud_panel()
var pill := GoStyle.overlay_panel()""", T(
		"Panels that float over the game, so text stays readable on any picture.",
		"게임 위에 뜨는 판 — 어떤 그림 위에서도 글자가 읽힌다.",
		"ゲームの上に浮かぶパネル。どんな絵の上でも文字が読める。",
		"浮在游戏画面上的面板，让文字在任何画面上都清晰可读。",
		"浮在遊戲畫面上的面板，讓文字在任何畫面上都清晰可讀。",
		"Paneles que flotan sobre el juego para que el texto se lea sobre cualquier imagen.",
		"Painéis que flutuam sobre o jogo para o texto ficar legível em qualquer imagem.",
		"Панели поверх игры, чтобы текст читался на любой картинке.",
		"Des panneaux qui flottent au-dessus du jeu, pour que le texte reste lisible sur n'importe quelle image.",
		"Oyunun üzerinde yüzen paneller; metin her resim üzerinde okunur kalır.",
		"Panele unoszące się nad grą, by tekst był czytelny na każdym obrazie.",
		"Pannelli che fluttuano sopra il gioco, perché il testo resti leggibile su qualsiasi immagine.",
		"Các bảng nổi trên trò chơi để chữ dễ đọc trên mọi hình.",
		"Panel yang mengambang di atas permainan agar teks tetap terbaca di gambar apa pun.",
		"Панелі над грою, щоб текст читався на будь-якому зображенні.",
		"แผงที่ลอยเหนือเกม ให้อ่านข้อความได้บนทุกภาพ",
		"لوحات تطفو فوق اللعبة ليبقى النص مقروءًا على أي صورة.")),
	# ── Looks and system
	("look", "GoUi · GoThemePresets", "RefCounted", """GoUi.use_preset(GoThemePresets.MATERIAL_LIGHT)
var accent := GoUi.color(GoTheme.ACCENT)
var gap := GoUi.metric(GoTheme.GAP)""", T(
		"Pick one of eight presets; read colours and sizes from the tokens.",
		"여덟 프리셋 중 하나를 고르고, 색과 크기는 토큰에서 읽는다.",
		"8 つのプリセットから選び、色とサイズはトークンから読む。",
		"从八种预设中选择一种；颜色与尺寸从令牌读取。",
		"從八種預設中選擇一種；顏色與尺寸從 Token 讀取。",
		"Elige uno de ocho preajustes; lee colores y tamaños de los tokens.",
		"Escolha um de oito presets; leia cores e tamanhos dos tokens.",
		"Выберите один из восьми пресетов; цвета и размеры берите из токенов.",
		"Choisissez l'un des huit préréglages ; lisez couleurs et tailles dans les jetons.",
		"Sekiz hazır ayardan birini seçin; renk ve boyutları belirteçlerden okuyun.",
		"Wybierz jeden z ośmiu presetów; kolory i rozmiary czytaj z tokenów.",
		"Scegli uno degli otto preset; leggi colori e dimensioni dai token.",
		"Chọn một trong tám preset; đọc màu và kích thước từ token.",
		"Pilih satu dari delapan preset; baca warna dan ukuran dari token.",
		"Оберіть один із восьми пресетів; кольори й розміри беріть із токенів.",
		"เลือกหนึ่งในแปดพรีเซ็ต อ่านสีและขนาดจากโทเคน",
		"اختر أحد ثمانية إعدادات مسبقة؛ واقرأ الألوان والمقاسات من الرموز.")),
	("look", "GoConfig", "Resource", """GoUi.config.reduce_motion = true
GoUi.config.container_alpha = 1.0
GoUi.refresh()""", T(
		"One resource for every setting, which survives add-on updates.",
		"모든 설정을 담는 리소스 하나 — 애드온을 업데이트해도 남는다.",
		"すべての設定を入れる一つのリソース。アドオンを更新しても残る。",
		"一个资源装下所有设置，插件更新后仍保留。",
		"一個資源裝下所有設定，外掛更新後仍保留。",
		"Un recurso para todos los ajustes, que sobrevive a las actualizaciones del complemento.",
		"Um recurso para todas as configurações, que sobrevive às atualizações do complemento.",
		"Один ресурс для всех настроек, который переживает обновления дополнения.",
		"Une seule ressource pour tous les réglages, qui survit aux mises à jour de l'extension.",
		"Eklenti güncellemelerinden sonra da kalan, tüm ayarlar için tek bir kaynak.",
		"Jeden zasób na wszystkie ustawienia, który przetrwa aktualizacje dodatku.",
		"Una sola risorsa per tutte le impostazioni, che sopravvive agli aggiornamenti del componente.",
		"Một tài nguyên cho mọi cài đặt, vẫn còn sau khi cập nhật add-on.",
		"Satu sumber daya untuk semua pengaturan, yang bertahan saat add-on diperbarui.",
		"Один ресурс для всіх налаштувань, що переживає оновлення доповнення.",
		"ทรัพยากรเดียวสำหรับทุกการตั้งค่า ที่อยู่รอดหลังอัปเดตส่วนเสริม",
		"مورد واحد لكل الإعدادات يبقى بعد تحديث الإضافة.")),
	("look", "GoSkin", "Resource", """class_name MySkin
extends GoSkin

func banner_box() -> StyleBox:
	return surface_box(GoTheme.BOX_CARD)""", T(
		"The shapes code draws — chips, slots, the joystick, the new parts — in your own style.",
		"코드가 그리는 모양 — 칩·슬롯·조이스틱·새 부품 — 을 내 방식으로.",
		"コードが描く形 — チップ、スロット、ジョイスティック、新しい部品 — を自分の流儀で。",
		"由代码绘制的形状——标签、槽位、摇杆与新组件——按你的风格。",
		"由程式繪製的形狀——標籤、槽位、搖桿與新元件——依你的風格。",
		"Las formas que dibuja el código —chips, ranuras, joystick, piezas nuevas— a tu estilo.",
		"As formas que o código desenha — chips, slots, analógico, peças novas — no seu estilo.",
		"Формы, которые рисует код, — чипы, слоты, стик, новые части — в вашем стиле.",
		"Les formes dessinées par le code — puces, emplacements, stick, nouvelles pièces — à votre style.",
		"Kodun çizdiği biçimler — çipler, yuvalar, joystick, yeni parçalar — kendi tarzınızda.",
		"Kształty rysowane kodem — chipy, sloty, gałka, nowe części — w twoim stylu.",
		"Le forme disegnate dal codice — chip, slot, stick, parti nuove — nel tuo stile.",
		"Các hình do mã vẽ — chip, ô, cần điều khiển, phần mới — theo phong cách của bạn.",
		"Bentuk yang digambar kode — chip, slot, joystick, bagian baru — dengan gaya Anda.",
		"Форми, які малює код, — чипи, слоти, стік, нові частини — у вашому стилі.",
		"รูปทรงที่โค้ดวาด — ชิป ช่อง จอยสติก ชิ้นส่วนใหม่ — ตามสไตล์ของคุณ",
		"الأشكال التي يرسمها الكود — الرقائق والخانات وعصا التحكم والأجزاء الجديدة — بأسلوبك.")),
	("look", "GoIconSet · GoGameIcons", "Resource · RefCounted", """GoUi.config.icons = GoGameIcons.icon_set()
var gear := GoUi.icons().node(GoIconSet.SETTINGS, 24)""", T(
		"Icons by name: the default set, 187 game icons, or your own SVGs.",
		"이름으로 부르는 아이콘 — 기본 세트, 게임 아이콘 187개, 또는 내 SVG.",
		"名前で呼ぶアイコン — 標準セット、ゲームアイコン 187 個、または自分の SVG。",
		"按名称使用图标：默认集、187 个游戏图标或你自己的 SVG。",
		"依名稱使用圖示：預設集、187 個遊戲圖示或你自己的 SVG。",
		"Iconos por nombre: el conjunto por defecto, 187 iconos de juego o tus propios SVG.",
		"Ícones por nome: o conjunto padrão, 187 ícones de jogo ou seus próprios SVGs.",
		"Иконки по имени: стандартный набор, 187 игровых иконок или ваши SVG.",
		"Des icônes par nom : le jeu par défaut, 187 icônes de jeu ou vos propres SVG.",
		"Ada göre simgeler: varsayılan set, 187 oyun simgesi ya da kendi SVG'leriniz.",
		"Ikony po nazwie: zestaw domyślny, 187 ikon do gier lub własne SVG.",
		"Icone per nome: il set predefinito, 187 icone da gioco o i tuoi SVG.",
		"Biểu tượng theo tên: bộ mặc định, 187 biểu tượng game, hoặc SVG của bạn.",
		"Ikon berdasarkan nama: set bawaan, 187 ikon game, atau SVG Anda sendiri.",
		"Іконки за назвою: стандартний набір, 187 ігрових іконок або ваші SVG.",
		"ไอคอนตามชื่อ: ชุดเริ่มต้น ไอคอนเกม 187 แบบ หรือ SVG ของคุณเอง",
		"أيقونات بالاسم: المجموعة الافتراضية أو 187 أيقونة ألعاب أو ملفات SVG الخاصة بك.")),
	("look", "GoStyleBoxCut · GoStyleBoxBracket · GoStyleBoxMedieval", "StyleBox", """var face := GoStyleBoxCut.new()
face.cut = 8
panel.add_theme_stylebox_override(&"panel", face)""", T(
		"Chamfered, bracketed and forged faces for your own panels.",
		"내 판에 쓰는 모서리 깎인·괄호·단조 면.",
		"自分のパネルに使える面取り・括弧・鍛造の面。",
		"供你的面板使用的切角、括号与锻造外框。",
		"供你的面板使用的切角、括號與鍛造外框。",
		"Caras biseladas, con corchetes y forjadas para tus paneles.",
		"Faces chanfradas, com colchetes e forjadas para seus painéis.",
		"Грани со срезанными углами, скобками и ковкой для ваших панелей.",
		"Des faces chanfreinées, à crochets et forgées pour vos panneaux.",
		"Kendi panelleriniz için pahlı, köşeli ayraçlı ve dövme yüzler.",
		"Ścięte, nawiasowe i kute ścianki do twoich paneli.",
		"Facce smussate, a parentesi e forgiate per i tuoi pannelli.",
		"Mặt vát góc, mặt ngoặc và mặt rèn cho bảng của bạn.",
		"Muka bertakik, berkurung, dan tempa untuk panel Anda.",
		"Грані зі зрізаними кутами, дужками й куванням для ваших панелей.",
		"หน้าแบบลบมุม แบบวงเล็บ และแบบตีเหล็ก สำหรับแผงของคุณ",
		"أوجه مشطوفة وبأقواس ومطروقة للوحاتك.")),
	("look", "GoSafeArea · GoScale", "Control · RefCounted", """var usable := GoSafeArea.usable_rect(get_window())
var size_class := GoScale.breakpoint_for_dp(minf(usable.size.x, usable.size.y))   # by the short side""", T(
		"Notches, the gesture bar and the keyboard; breakpoints in dp.",
		"노치·제스처 바·키보드를 피한 영역, 그리고 dp 기준 구간.",
		"ノッチ・ジェスチャーバー・キーボードを避けた領域と、dp 基準のブレークポイント。",
		"避开刘海、手势条与键盘的区域，以及以 dp 计的断点。",
		"避開瀏海、手勢列與鍵盤的區域，以及以 dp 計的斷點。",
		"Muescas, barra de gestos y teclado; puntos de corte en dp.",
		"Entalhes, barra de gestos e teclado; pontos de quebra em dp.",
		"Вырезы, панель жестов и клавиатура; контрольные точки в dp.",
		"Encoches, barre de gestes et clavier ; points de rupture en dp.",
		"Çentikler, hareket çubuğu ve klavye; dp cinsinden kırılma noktaları.",
		"Wycięcia, pasek gestów i klawiatura; progi w dp.",
		"Notch, barra dei gesti e tastiera; punti di interruzione in dp.",
		"Tai thỏ, thanh cử chỉ và bàn phím; điểm ngắt tính bằng dp.",
		"Takik layar, bilah gestur, dan keyboard; titik henti dalam dp.",
		"Вирізи, панель жестів і клавіатура; контрольні точки в dp.",
		"รอยบาก แถบท่าทาง และคีย์บอร์ด จุดแบ่งขนาดเป็น dp",
		"النتوءات وشريط الإيماءات ولوحة المفاتيح؛ نقاط التوقف بوحدة dp.")),
	("look", "GoFeedback", "RefCounted", """GoFeedback.sound_handler = func(cue: String) -> void: audio.play_cue(cue)
GoFeedback.haptic_handler = func(ms: int, amplitude: float) -> void: Input.vibrate_handheld(ms, amplitude)""", T(
		"Sound cues and haptics routed to your own audio; gohud ships no sound.",
		"소리 신호와 진동을 내 오디오로 보낸다 — gohud 는 소리를 싣지 않는다.",
		"効果音の合図と振動を自分のオーディオへ送る。gohud は音を同梱しない。",
		"把音效提示与触感反馈交给你自己的音频；gohud 不附带声音。",
		"把音效提示與觸覺回饋交給你自己的音訊；gohud 不附帶聲音。",
		"Señales de sonido y vibración enviadas a tu propio audio; gohud no incluye sonidos.",
		"Sinais sonoros e vibração enviados ao seu próprio áudio; o gohud não traz sons.",
		"Звуковые сигналы и вибрация уходят в ваш звук; gohud не содержит звуков.",
		"Les signaux sonores et les vibrations passent par votre propre audio ; gohud n'embarque aucun son.",
		"Ses işaretleri ve titreşim kendi sesinize yönlendirilir; gohud ses içermez.",
		"Sygnały dźwiękowe i wibracje kierowane do twojego audio; gohud nie zawiera dźwięków.",
		"Segnali sonori e vibrazione instradati al tuo audio; gohud non include suoni.",
		"Tín hiệu âm thanh và rung được chuyển tới âm thanh của bạn; gohud không kèm âm thanh.",
		"Isyarat suara dan getaran diarahkan ke audio Anda; gohud tidak menyertakan suara.",
		"Звукові сигнали й вібрація йдуть у ваш звук; gohud не містить звуків.",
		"สัญญาณเสียงและการสั่นส่งไปยังระบบเสียงของคุณ gohud ไม่มีเสียงมาให้",
		"إشارات الصوت والاهتزاز تُوجَّه إلى نظام الصوت لديك؛ لا يتضمن gohud أصواتًا.")),
	("look", "GoBackPolicy", "RefCounted", """GoBackPolicy.acquire(get_tree())""", T(
		"Who owns Android Back and Escape right now, shared across windows.",
		"지금 안드로이드 뒤로·Esc 를 누가 갖는지 — 창들 사이에 나눠 쓴다.",
		"いま Android の戻ると Esc を持つのは誰か。ウィンドウ間で共有する。",
		"当前由谁接管 Android 返回键与 Esc，在窗口之间共享。",
		"目前由誰接管 Android 返回鍵與 Esc，在視窗之間共用。",
		"Quién controla ahora Atrás de Android y Escape, compartido entre ventanas.",
		"Quem controla agora o Voltar do Android e o Esc, compartilhado entre janelas.",
		"Кому сейчас принадлежат «Назад» на Android и Escape — общее для окон.",
		"Qui détient en ce moment Retour Android et Échap, partagé entre fenêtres.",
		"Android Geri ve Escape'in şu an kimde olduğu; pencereler arasında paylaşılır.",
		"Kto teraz obsługuje Wstecz na Androidzie i Escape — wspólne dla okien.",
		"Chi possiede ora Indietro di Android ed Esc, condiviso tra le finestre.",
		"Ai đang giữ nút Quay lại của Android và Escape, dùng chung giữa các cửa sổ.",
		"Siapa yang memegang Kembali Android dan Escape saat ini, dibagi antarjendela.",
		"Кому зараз належать «Назад» на Android і Escape — спільне для вікон.",
		"ตอนนี้ใครถือปุ่มย้อนกลับของ Android และ Escape ใช้ร่วมกันระหว่างหน้าต่าง",
		"من يملك الآن زر الرجوع في Android وزر Escape، مشتركًا بين النوافذ.")),
]

SUBNAV_LINE = '  <a href="%s">%s</a>\n'


def _esc(text):
	return html.escape(text, quote=False)


def _breakable(code):
	"""The example as HTML, with a place to fold after each `(` `[` `{` `,` and before each member name — a card is narrower
	than a long call, and folding mid-word made `Maintenanc|e`. `<wbr>` adds nothing to the copied text."""
	text = _esc(code)
	text = re.sub(r"([(\[{,])", r"\1<wbr>", text)
	return re.sub(r"\.(?=[A-Za-z_])", ".<wbr>", text)


def _slug(name):
	return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def _body(code):
	"""The part of the page between the side menu and `</main>` in one language."""
	rows = []
	for group, titles in GROUPS:
		members = [w for w in WIDGETS if w[0] == group]
		rows.append('<section id="%s" class="catalog">' % group)
		rows.append('  <h2>%s <small>(%d)</small></h2>' % (_esc(titles[code]), len(members)))
		rows.append('  <div class="grid">')
		for _group, name, base, example, words in members:
			rows.append('    <div class="card">')
			rows.append('      <h3><code>%s</code></h3>' % _esc(name))
			rows.append('      <p>%s</p>' % _esc(words[code]))
			label = TEXT["member" if "." in name else "extends"][code]
			rows.append('      <p class="catalog-base">%s <code>%s</code></p>' % (_esc(label), _esc(base)))
			rows.append('      <pre><code>%s</code></pre>' % _breakable(example))
			rows.append('    </div>')
		rows.append('  </div>')
		rows.append('</section>')
		rows.append('')
	return "\n".join(rows)


def _page(lang, template):
	code = lang.code
	text = template
	title = TEXT["label"][code]
	text = re.sub(r"<title>.*?</title>", "<title>%s — gohud</title>" % _esc(title), text, count=1, flags=re.S)
	text = re.sub(r'<meta name="description" content="[^"]*">',
		'<meta name="description" content="%s">' % html.escape(TEXT["desc"][code], quote=True), text, count=1)
	widgets = site_nav.label(code, "widgets")
	text = re.sub(r'<div class="hero">.*?</div>\n</div>', '<div class="hero">\n  <div class="wrap">\n    <h1>%s</h1>\n'
		'    <p class="lead">%s <a href="widgets.html">← %s</a></p>\n  </div>\n</div>' % (_esc(title),
			_esc(TEXT["lead"][code]), _esc(widgets)), text, count=1, flags=re.S)
	# The side menu as the template has it, with this page marked as the current one.
	nav = re.search(r'<nav class="subnav".*?</nav>', text, flags=re.S).group(0)
	nav = nav.replace(' aria-current="page"', "")
	nav = _with_catalog_link(nav, code).replace('href="%s"' % PAGE, 'href="%s" aria-current="page"' % PAGE)
	start = text.index('<nav class="subnav"')
	end = text.index("</main>")
	text = text[:start] + nav + "\n\n" + _body(code) + "\n" + text[end:]
	# Footer: back to the cover, on to the first topic page.
	first = re.search(r'<a href="widgets-surfaces.html">([^<]*)</a>', nav)
	text = re.sub(r'(<footer class="bottom">\s*<div class="wrap">\s*)<p>.*?</p>',
		lambda m: m.group(1) + '<p><a href="widgets.html">← %s</a> · <a href="widgets-surfaces.html">%s →</a></p>' % (
			_esc(widgets), first.group(1) if first else "→"), text, count=1, flags=re.S)
	return text


def _with_catalog_link(nav, code):
	"""The side menu with the link to this page right after the cover's."""
	if 'href="%s"' % PAGE in nav:
		return nav
	cover = re.search(r'  <a href="widgets.html"[^>]*>[^<]*</a>\n', nav)
	if cover is None:
		return nav
	return nav[:cover.end()] + SUBNAV_LINE % (PAGE, _esc(TEXT["label"][code])) + nav[cover.end():]


def _with_card(text, code):
	"""The cover with a card for this page at the front of its grid."""
	if 'href="%s"' % PAGE in text.split('<section id="pages">', 1)[-1]:
		return text
	card = ('    <div class="card">\n      <h3><a href="%s">%s</a></h3>\n      <p>%s</p>\n    </div>\n' % (
		PAGE, _esc(TEXT["label"][code]), _esc(TEXT["card"][code])))
	return re.sub(r'(<section id="pages">\s*<div class="grid">\n)', lambda m: m.group(1) + card, text, count=1)


# Where an entry's member table lives when the first mention in the references is not it (a pointer, a summary).
DETAILS = {
	"GoScaffold": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoListView": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoRefresh": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoSwipeRow": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoTabView": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoReorderList": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoZoomView": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoBanner": ("flutter.md", "2. Scaffold, lists and gestures"),
	"GoDialogs.choose": ("surfaces.md", "3. GoDialogs"),
	"GoUi · GoThemePresets": ("theming.md", "1. Three layers and presets"),
	"GoIconSet · GoGameIcons": ("platform.md", "1. Icons"),
	"GoStyleBoxCut · GoStyleBoxBracket · GoStyleBoxMedieval": ("theming.md", "7. Custom StyleBoxes"),
	"GoSafeArea · GoScale": ("platform.md", "5. Safe area, keyboard, breakpoints, dp scale"),
	"GoNavBar.drawer_list": ("hud.md", "16. App screens — navigation bar, app bar, FAB, search, split button, progress, loading, dates"),
	"GoBackPolicy": ("platform.md", "6. Back button and modality"),
}

# The reference files searched, in the order a mention counts.
_REF_ORDER = ["hud.md", "surfaces.md", "style.md", "flutter.md", "theming.md", "platform.md", "setup.md", "recipes.md"]


def _sections(file):
	"""(heading, lines under it) for each `##` / `###` section of a reference, `###` folded into its `##`."""
	out, title, lines = [], "", []
	for line in open(os.path.join(SKILL_REFS, file), encoding="utf-8").read().split("\n"):
		if line.startswith("## "):
			out.append((title, lines))
			title, lines = line[3:].strip(), []
		else:
			lines.append(line)
	out.append((title, lines))
	return [(t, l) for t, l in out if t]


def _details(name):
	"""`file` § `heading` with the entry's member table — an override, a heading or a table row that names it, else the
	first section that mentions it."""
	if name in DETAILS:
		return DETAILS[name]
	first = name.split(" · ")[0]
	key = first.split(".")[-1] if first.startswith("GoStyle.") else first
	call = first.startswith("GoStyle.") or "." in first
	# A factory is looked up in style.md first — `alert(` and `toolbar(` also name members of GoDialogs and GoSheet.
	order = (["style.md"] + [f for f in _REF_ORDER if f != "style.md"]) if first.startswith("GoStyle.") else _REF_ORDER
	files = {f: _sections(f) for f in order if os.path.isfile(os.path.join(SKILL_REFS, f))}
	if not call:
		for file, sections in files.items():
			for title, lines in sections:
				if re.search(r"\b%s\b" % re.escape(key), title):
					return file, title
				for line in lines:
					if re.match(r"^### `?%s\b" % re.escape(key), line):
						return file, title + " › " + line[4:].strip()
	pattern = r"^\| [^|]*`%s\(" % re.escape(key) if call else r"^\| [^|]*`%s`" % re.escape(key)
	for test in (lambda line: re.match(pattern, line), lambda line: ("`%s" % key) in line):
		for file, sections in files.items():
			for title, lines in sections:
				sub = ""
				for line in lines:
					if line.startswith("### "):
						sub = line[4:].strip()
					elif test(line):
						return file, title + (" › " + sub if sub else "")
	return None


def skill_catalog():
	"""`skills/gohud/references/catalog.md` — the same entries as the page, in English, with where to read more."""
	out = [
		"# Every widget and layout — by name",
		"",
		"🛑 Generated by `tools/site_catalog.py` from the list behind the website's **All widgets** page",
		"(https://thruthesky.github.io/gohud/widgets-catalog.html). Do not edit it by hand — add the widget there and run",
		"`python3 addons/gohud/tools/site_catalog.py`.",
		"",
		"Read it to answer \"is there a widget for …?\", to find a class you half remember, or to show someone the whole",
		"kit. Each entry says what it extends, what it is for, and one example; **Details** names the reference section",
		"with its full member table — read that before using a member you are not sure of. Every example is checked",
		"against the code (`tools/check_docs_api.py`).",
		"",
		"## Contents",
		"",
	]
	for index, (group, titles) in enumerate(GROUPS, 1):
		count = len([w for w in WIDGETS if w[0] == group])
		heading = titles["en"]
		out.append("%d. [%s](#%s) (%d)" % (index, heading, re.sub(r"[^a-z0-9 -]", "", heading.lower()).replace(" ", "-"), count))
	for group, titles in GROUPS:
		out += ["", "## " + titles["en"], ""]
		for _group, name, base, example, words in [w for w in WIDGETS if w[0] == group]:
			where = _details(name)
			more = ""
			if where:
				number = re.match(r"(\d+)\.\s*(.*)", where[1])
				place = "§%s (%s)" % (number.group(1), " › ".join(part.split(" — ")[0] for part in number.group(2).split(" › "))) \
					if number else where[1]
				more = " Details: `%s` %s." % (where[0], place)
			kind = "A function of `%s`." % base if "." in name else "Extends `%s`." % base
			out += ["### `%s`" % name, "", "%s %s%s" % (kind, words["en"], more), "", "```gdscript", example,
				"```", ""]
	return "\n".join(out).rstrip("\n") + "\n"


def main():
	if "--check" in sys.argv:
		want = skill_catalog()
		have = open(SKILL_CATALOG, encoding="utf-8").read() if os.path.isfile(SKILL_CATALOG) else ""
		if want != have:
			print("🛑 skills/gohud/references/catalog.md is not what tools/site_catalog.py makes — run it")
			sys.exit(1)
		print("✅ the skill's catalog matches the All widgets list (%d entries)" % len(WIDGETS))
		return
	written = 0
	for lang in site_langs.ACTIVE:
		folder = os.path.join(WWW, lang.folder) if lang.folder else WWW
		template = open(os.path.join(folder, TEMPLATE), encoding="utf-8").read()
		open(os.path.join(folder, PAGE), "w", encoding="utf-8").write(_page(lang, template))
		written += 1
		for page in site_langs.PAGES:
			if not page.startswith("widgets") or page == PAGE:
				continue
			path = os.path.join(folder, page)
			if not os.path.isfile(path):
				continue
			text = open(path, encoding="utf-8").read()
			new = re.sub(r'<nav class="subnav".*?</nav>', lambda m: _with_catalog_link(m.group(0), lang.code), text,
				count=1, flags=re.S)
			if page == "widgets.html":
				new = _with_card(new, lang.code)
			if new != text:
				open(path, "w", encoding="utf-8").write(new)
	open(SKILL_CATALOG, "w", encoding="utf-8").write(skill_catalog())
	missing = [w[1] for w in WIDGETS if _details(w[1]) is None]
	print("All widgets — %d entries in %d groups, %d languages · skill catalog written%s" % (len(WIDGETS), len(GROUPS),
		written, (" — no details found for: " + ", ".join(missing)) if missing else ""))


if __name__ == "__main__":
	main()
