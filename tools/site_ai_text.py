# -*- coding: utf-8 -*-
"""`ai.html` 이 쓰는 말 — 17 개 언어를 **여기 한 곳**에 둔다.

`tools/make_ai_page.py` 가 이 표와 옛 `#ai` 절의 번역문을 합쳐 `ai.html` 17 장을 짓는다.

## 🛑 붙여 넣는 블록은 17 개 언어 모두 **영어 그대로** 둔다
그 글은 사람이 읽는 글이 아니라 **에이전트에게 주는 지시문**이다. 모든 코딩 에이전트가 가장 정확히
읽는 말이 영어이고, 블록 안의 명령(`claude plugin …`)·경로(`~/.claude/skills/gohud`)·폴더 이름이
전부 영어라 반만 옮기면 오히려 섞인다. 대신 **블록 바로 아래에** "왜 영어인가, 당신은 아무 말로나
물어도 된다" 를 그 나라 말로 적는다(`copy_note`).

## 🛑 블록 안의 모든 줄은 저장소에 근거가 있어야 한다
없는 경로를 적으면 그것이 곧 깨진 안내다. 근거:
- `claude plugin …` 두 줄 — `.claude-plugin/marketplace.json` 의 등록 정보(`name: gohud`)
- 스킬 폴더 세 곳 — `skills/gohud/commands/preview.md` 가 실제로 찾아보는 자리
- `git submodule add …` — `README.md` 의 설치 절
- `godot --headless --path . --import` — `skills/gohud/SKILL.md` §2
🛑 Cursor·Gemini 의 **전용** 스킬 경로는 저장소에 근거가 없다. 그래서 제품 이름은 들되 경로는 위 세
곳으로 한정한다.
"""

# 에이전트에 붙여 넣는 글 — 전 언어 공통. 🛑 고칠 때는 위 근거 목록을 함께 확인한다.
COPY_BLOCK = """Install gohud for this Godot 4.6+ project, then use it for all game UI
(menus, HUD bars, quick slots, dialogs, bottom sheets, forms, themes).

1. Install the gohud AI skill.
   Claude Code:
     claude plugin marketplace add thruthesky/gohud
     claude plugin install gohud@gohud
   Any other agent (Codex, Cursor, Gemini CLI, ...):
     git clone --depth 1 https://github.com/thruthesky/gohud.git /tmp/gohud
     Copy /tmp/gohud/skills/gohud into whichever of these folders this agent reads:
     ~/.claude/skills/gohud, .claude/skills/gohud, .agents/skills/gohud.

2. Install the add-on itself, if addons/gohud/plugin.cfg is missing here.
   In a git repository:
     git submodule add https://github.com/thruthesky/gohud.git addons/gohud
   Otherwise copy the clone to addons/gohud without its .git folder.
   Then run: godot --headless --path . --import

3. Restart yourself so the skill loads, then tell me what gohud can do
   and how to preview it.

Docs: https://thruthesky.github.io/gohud/"""

# 에이전트별 설치 자리 — (제품 이름, 설명 키, 폴더, 명령 표기).
# 🛑 경로와 명령 표기는 번역하지 않는다(그대로 쳐야 하는 글자다). 제품 이름도 그대로다.
#    번역하는 것은 **설명 한 마디**뿐이고, 그 말은 아래 `TEXT` 의 `row_*` 에 있다.
AGENT_ROWS = [
    ("Claude Code", "row_plugin", "claude plugin install gohud@gohud", "/gohud:preview · /gohud:features"),
    ("Claude Code", "row_skill", "~/.claude/skills/gohud", "/gohud preview · /gohud features"),
    ("Claude Code", "row_project", ".claude/skills/gohud", "/gohud preview"),
    ("Codex · Cursor · Gemini CLI", "row_others", ".agents/skills/gohud", "—"),
]

TEXT = {
    "en": {
        "copy_h2": "Copy this into your coding agent",
        "copy_sub": "Open your Godot project in the agent, paste the block, send it. It installs the skill and "
                    "the add-on, then tells you what gohud can do.",
        "copy_note": "The block is written in English on purpose — that is what every agent reads most reliably. "
                     "You can ask your own questions in any language; the skill answers in the language you write in.",
        "agents_h2": "Where each agent keeps skills",
        "agents_sub": "Installing by hand instead? Put the <code>skills/gohud</code> folder in the place your agent "
                      "reads. The first one that exists wins.",
        "agents_th": ("Agent", "Where the folder goes", "How commands look"),
        "commands_h2": "The commands you get",
        "ask_h2": "Or just ask",
        "row_plugin": "plugin",
        "row_skill": "skill only",
        "row_project": "this project only",
        "row_others": "others",
        "copy_cta": "Copy the block",
        "card_h2": "Fastest way — let your AI agent install it",
        "card_body": "One block of text, pasted into Claude Code, Codex, Cursor or Gemini CLI, installs both the skill and the add-on and then explains gohud to you. Nothing below this card is needed if you take that road.",
        "card_cta": "Open the AI SKILL page →",
        "need": "You need Godot 4.6 or newer on your <code>PATH</code> for the preview commands.",
    },
    "ko": {
        "copy_h2": "이 한 덩이를 코딩 에이전트에 붙여 넣는다",
        "copy_sub": "에이전트에서 Godot 프로젝트를 열고, 아래 글을 붙여 넣어 보낸다. 스킬과 애드온을 설치하고 "
                    "gohud 로 무엇을 할 수 있는지까지 알려 준다.",
        "copy_note": "이 글은 일부러 영어로 두었다 — 어떤 에이전트든 가장 정확히 읽는 말이다. 당신이 묻는 말은 "
                     "아무 말이나 괜찮다. 스킬은 당신이 쓴 말로 답한다.",
        "agents_h2": "에이전트마다 스킬을 두는 자리",
        "agents_sub": "손으로 넣겠다면 <code>skills/gohud</code> 폴더를 에이전트가 읽는 자리에 둔다. 먼저 있는 "
                      "자리가 이긴다.",
        "agents_th": ("에이전트", "폴더를 두는 자리", "명령 모양"),
        "commands_h2": "쓸 수 있게 되는 명령",
        "ask_h2": "그냥 말로 부탁해도 된다",
        "row_plugin": "플러그인",
        "row_skill": "스킬만",
        "row_project": "이 프로젝트에만",
        "row_others": "그 밖",
        "copy_cta": "복사할 글 보기",
        "card_h2": "가장 빠른 길 — AI 에게 설치를 맡긴다",
        "card_body": "글 한 덩이를 Claude Code·Codex·Cursor·Gemini CLI 에 붙여 넣으면 스킬과 애드온을 함께 설치하고 gohud 를 설명까지 해 준다. 그 길로 가면 이 카드 아래의 것은 하나도 필요 없다.",
        "card_cta": "AI SKILL 쪽 열기 →",
        "need": "미리보기 명령을 쓰려면 <code>PATH</code> 에 Godot 4.6 이상이 있어야 한다.",
    },
    "ja": {
        "copy_h2": "このひとかたまりをコーディングエージェントに貼る",
        "copy_sub": "エージェントで Godot プロジェクトを開き、下の文を貼って送る。スキルとアドオンを入れ、"
                    "gohud で何ができるかまで教えてくれる。",
        "copy_note": "この文はわざと英語にしてある — どのエージェントもいちばん正確に読む言葉だからだ。"
                     "質問は何語でもいい。スキルはあなたが書いた言葉で答える。",
        "agents_h2": "エージェントごとのスキル置き場",
        "agents_sub": "手で入れるなら <code>skills/gohud</code> フォルダーをエージェントが読む場所に置く。"
                      "先にあるものが使われる。",
        "agents_th": ("エージェント", "フォルダーを置く場所", "コマンドの形"),
        "commands_h2": "使えるようになるコマンド",
        "ask_h2": "ふつうに頼んでもいい",
        "row_plugin": "プラグイン",
        "row_skill": "スキルのみ",
        "row_project": "このプロジェクトだけ",
        "row_others": "その他",
        "copy_cta": "貼る文を見る",
        "card_h2": "いちばん速い道 — AI にインストールを任せる",
        "card_body": "ひとかたまりの文を Claude Code・Codex・Cursor・Gemini CLI に貼れば、スキルとアドオンを一緒に入れ、gohud の説明までしてくれる。その道を行くなら、このカードから下は一つも要らない。",
        "card_cta": "AI SKILL のページを開く →",
        "need": "プレビューのコマンドには <code>PATH</code> に Godot 4.6 以上が要る。",
    },
    "zh": {
        "copy_h2": "把这一段粘贴给你的编码代理",
        "copy_sub": "在代理里打开你的 Godot 项目，粘贴下面这段并发送。它会装好技能和插件，"
                    "再告诉你 gohud 能做什么。",
        "copy_note": "这段特意用英文写 —— 那是所有代理读得最准的语言。你自己提问用什么语言都行，"
                     "技能会用你写的语言回答。",
        "agents_h2": "各代理存放技能的位置",
        "agents_sub": "想手动安装？把 <code>skills/gohud</code> 文件夹放到代理读取的位置。先找到的那个生效。",
        "agents_th": ("代理", "文件夹放在哪", "命令写法"),
        "commands_h2": "你会得到的命令",
        "ask_h2": "直接开口问也行",
        "row_plugin": "插件",
        "row_skill": "仅技能",
        "row_project": "仅本项目",
        "row_others": "其他",
        "copy_cta": "查看要粘贴的内容",
        "card_h2": "最快的路 —— 让 AI 代理替你安装",
        "card_body": "把一段文字粘贴到 Claude Code、Codex、Cursor 或 Gemini CLI，它会同时装好技能和插件，再为你讲解 gohud。走这条路，这张卡片以下的内容一样都不需要。",
        "card_cta": "打开 AI SKILL 页 →",
        "need": "预览命令需要 <code>PATH</code> 中有 Godot 4.6 或更新版本。",
    },
    "zh-tw": {
        "copy_h2": "把這一段貼給你的編碼代理",
        "copy_sub": "在代理裡開啟你的 Godot 專案，貼上下面這段並送出。它會裝好技能與外掛，"
                    "再告訴你 gohud 能做什麼。",
        "copy_note": "這段刻意用英文書寫 —— 那是所有代理讀得最準的語言。你自己發問用什麼語言都行，"
                     "技能會用你寫的語言回答。",
        "agents_h2": "各代理存放技能的位置",
        "agents_sub": "想手動安裝？把 <code>skills/gohud</code> 資料夾放到代理讀取的位置。先找到的那個生效。",
        "agents_th": ("代理", "資料夾放在哪", "指令寫法"),
        "commands_h2": "你會得到的指令",
        "ask_h2": "直接開口問也行",
        "row_plugin": "外掛",
        "row_skill": "僅技能",
        "row_project": "僅本專案",
        "row_others": "其他",
        "copy_cta": "查看要貼上的內容",
        "card_h2": "最快的路 —— 讓 AI 代理替你安裝",
        "card_body": "把一段文字貼到 Claude Code、Codex、Cursor 或 Gemini CLI，它會同時裝好技能與外掛，再為你講解 gohud。走這條路，這張卡片以下的內容一樣都不需要。",
        "card_cta": "開啟 AI SKILL 頁 →",
        "need": "預覽指令需要 <code>PATH</code> 中有 Godot 4.6 或更新版本。",
    },
    "es": {
        "copy_h2": "Pega esto en tu agente de código",
        "copy_sub": "Abre tu proyecto de Godot en el agente, pega el bloque y envíalo. Instala la skill y el "
                    "complemento, y luego te cuenta qué puede hacer gohud.",
        "copy_note": "El bloque está en inglés a propósito: es lo que todo agente lee con más fiabilidad. "
                     "Tus preguntas pueden ir en cualquier idioma; la skill responde en el idioma en que escribes.",
        "agents_h2": "Dónde guarda las skills cada agente",
        "agents_sub": "¿Prefieres instalarlo a mano? Pon la carpeta <code>skills/gohud</code> donde tu agente lee. "
                      "Gana la primera que exista.",
        "agents_th": ("Agente", "Dónde va la carpeta", "Forma de los comandos"),
        "commands_h2": "Los comandos que obtienes",
        "ask_h2": "O simplemente pídelo",
        "row_plugin": "plugin",
        "row_skill": "solo la skill",
        "row_project": "solo este proyecto",
        "row_others": "otros",
        "copy_cta": "Ver el bloque",
        "card_h2": "La vía más rápida: que lo instale tu agente de IA",
        "card_body": "Un bloque de texto, pegado en Claude Code, Codex, Cursor o Gemini CLI, instala la skill y el complemento y luego te explica gohud. Si tomas ese camino, nada de lo que hay debajo de esta tarjeta hace falta.",
        "card_cta": "Abrir la página AI SKILL →",
        "need": "Los comandos de vista previa necesitan Godot 4.6 o superior en tu <code>PATH</code>.",
    },
    "pt": {
        "copy_h2": "Cole isto no seu agente de código",
        "copy_sub": "Abra o seu projeto Godot no agente, cole o bloco e envie. Ele instala a skill e o add-on, "
                    "e depois diz-lhe o que o gohud consegue fazer.",
        "copy_note": "O bloco está em inglês de propósito — é o que todos os agentes leem com mais fiabilidade. "
                     "As suas perguntas podem ser em qualquer língua; a skill responde na língua em que escreve.",
        "agents_h2": "Onde cada agente guarda as skills",
        "agents_sub": "Prefere instalar à mão? Ponha a pasta <code>skills/gohud</code> onde o seu agente lê. "
                      "Vence a primeira que existir.",
        "agents_th": ("Agente", "Onde vai a pasta", "Forma dos comandos"),
        "commands_h2": "Os comandos que ganha",
        "ask_h2": "Ou simplesmente peça",
        "row_plugin": "plugin",
        "row_skill": "só a skill",
        "row_project": "só este projeto",
        "row_others": "outros",
        "copy_cta": "Ver o bloco",
        "card_h2": "O caminho mais rápido: deixe o seu agente de IA instalar",
        "card_body": "Um bloco de texto, colado no Claude Code, Codex, Cursor ou Gemini CLI, instala a skill e o add-on e depois explica-lhe o gohud. Se seguir por aí, nada abaixo deste cartão é preciso.",
        "card_cta": "Abrir a página AI SKILL →",
        "need": "Os comandos de pré-visualização precisam do Godot 4.6 ou mais recente no seu <code>PATH</code>.",
    },
    "ru": {
        "copy_h2": "Вставьте это в свой ИИ-агент",
        "copy_sub": "Откройте проект Godot в агенте, вставьте блок и отправьте. Он установит навык и дополнение, "
                    "а потом расскажет, что умеет gohud.",
        "copy_note": "Блок намеренно написан по-английски — так его точнее всего читает любой агент. "
                     "Свои вопросы задавайте на любом языке: навык отвечает на том языке, на котором вы пишете.",
        "agents_h2": "Где каждый агент хранит навыки",
        "agents_sub": "Хотите поставить вручную? Положите папку <code>skills/gohud</code> туда, откуда читает ваш "
                      "агент. Побеждает первая существующая.",
        "agents_th": ("Агент", "Куда класть папку", "Вид команд"),
        "commands_h2": "Команды, которые вы получите",
        "ask_h2": "Или просто попросите",
        "row_plugin": "плагин",
        "row_skill": "только навык",
        "row_project": "только этот проект",
        "row_others": "другие",
        "copy_cta": "К блоку для вставки",
        "card_h2": "Самый быстрый путь — поручите установку ИИ-агенту",
        "card_body": "Один блок текста, вставленный в Claude Code, Codex, Cursor или Gemini CLI, установит и навык, и дополнение, а потом объяснит вам gohud. На этом пути ничего ниже этой карточки не нужно.",
        "card_cta": "Открыть страницу AI SKILL →",
        "need": "Для команд предпросмотра нужен Godot 4.6 или новее в <code>PATH</code>.",
    },
    "fr": {
        "copy_h2": "Collez ceci dans votre agent de code",
        "copy_sub": "Ouvrez votre projet Godot dans l'agent, collez le bloc et envoyez. Il installe la compétence "
                    "et l'extension, puis vous dit ce que gohud sait faire.",
        "copy_note": "Le bloc est en anglais à dessein : c'est ce que tout agent lit le plus fidèlement. "
                     "Posez vos questions dans la langue que vous voulez ; la compétence répond dans la vôtre.",
        "agents_h2": "Où chaque agent range ses compétences",
        "agents_sub": "Vous préférez installer à la main ? Placez le dossier <code>skills/gohud</code> là où votre "
                      "agent lit. Le premier qui existe l'emporte.",
        "agents_th": ("Agent", "Où va le dossier", "Forme des commandes"),
        "commands_h2": "Les commandes que vous obtenez",
        "ask_h2": "Ou demandez simplement",
        "row_plugin": "plugin",
        "row_skill": "compétence seule",
        "row_project": "ce projet seulement",
        "row_others": "autres",
        "copy_cta": "Voir le bloc",
        "card_h2": "Le chemin le plus rapide : laissez votre agent IA installer",
        "card_body": "Un bloc de texte collé dans Claude Code, Codex, Cursor ou Gemini CLI installe la compétence et l'extension, puis vous explique gohud. Sur cette voie, rien de ce qui suit cette carte n'est nécessaire.",
        "card_cta": "Ouvrir la page AI SKILL →",
        "need": "Les commandes d'aperçu demandent Godot 4.6 ou plus récent dans votre <code>PATH</code>.",
    },
    "tr": {
        "copy_h2": "Bunu kodlama ajanınıza yapıştırın",
        "copy_sub": "Godot projenizi ajanda açın, bloğu yapıştırıp gönderin. Beceriyi ve eklentiyi kurar, "
                    "sonra gohud'un neler yapabildiğini anlatır.",
        "copy_note": "Blok bilerek İngilizce yazıldı — her ajanın en güvenilir okuduğu dil bu. "
                     "Kendi sorularınızı istediğiniz dilde sorun; beceri yazdığınız dilde yanıtlar.",
        "agents_h2": "Her ajan becerileri nerede tutar",
        "agents_sub": "Elle kurmayı mı yeğlersiniz? <code>skills/gohud</code> klasörünü ajanınızın okuduğu yere "
                      "koyun. Var olan ilki kazanır.",
        "agents_th": ("Ajan", "Klasör nereye gider", "Komutların görünüşü"),
        "commands_h2": "Kazandığınız komutlar",
        "ask_h2": "Ya da sadece isteyin",
        "row_plugin": "eklenti",
        "row_skill": "yalnızca beceri",
        "row_project": "yalnızca bu proje",
        "row_others": "diğerleri",
        "copy_cta": "Bloğu gör",
        "card_h2": "En hızlı yol — kurulumu yapay zekâ ajanınıza bırakın",
        "card_body": "Claude Code, Codex, Cursor ya da Gemini CLI'a yapıştırılan tek bir metin bloğu hem beceriyi hem eklentiyi kurar, sonra size gohud'u anlatır. Bu yolu seçerseniz bu kartın altındakilerin hiçbiri gerekmez.",
        "card_cta": "AI SKILL sayfasını aç →",
        "need": "Önizleme komutları için <code>PATH</code> içinde Godot 4.6 veya üstü gerekir.",
    },
    "pl": {
        "copy_h2": "Wklej to do swojego agenta kodu",
        "copy_sub": "Otwórz projekt Godota w agencie, wklej blok i wyślij. Zainstaluje umiejętność i dodatek, "
                    "a potem opowie, co potrafi gohud.",
        "copy_note": "Blok jest po angielsku celowo — to język, który każdy agent czyta najpewniej. "
                     "Własne pytania zadawaj w dowolnym języku; umiejętność odpowie w tym, w którym piszesz.",
        "agents_h2": "Gdzie każdy agent trzyma umiejętności",
        "agents_sub": "Wolisz zainstalować ręcznie? Umieść folder <code>skills/gohud</code> tam, skąd czyta twój "
                      "agent. Wygrywa pierwszy istniejący.",
        "agents_th": ("Agent", "Gdzie trafia folder", "Postać poleceń"),
        "commands_h2": "Polecenia, które dostajesz",
        "ask_h2": "Albo po prostu poproś",
        "row_plugin": "wtyczka",
        "row_skill": "sama umiejętność",
        "row_project": "tylko ten projekt",
        "row_others": "inne",
        "copy_cta": "Zobacz blok",
        "card_h2": "Najszybsza droga — niech zainstaluje to agent AI",
        "card_body": "Jeden blok tekstu wklejony do Claude Code, Codex, Cursora lub Gemini CLI instaluje i umiejętność, i dodatek, a potem objaśnia ci gohud. Na tej drodze nic poniżej tej karty nie jest potrzebne.",
        "card_cta": "Otwórz stronę AI SKILL →",
        "need": "Polecenia podglądu wymagają Godota 4.6 lub nowszego w <code>PATH</code>.",
    },
    "it": {
        "copy_h2": "Incolla questo nel tuo agente di codice",
        "copy_sub": "Apri il progetto Godot nell'agente, incolla il blocco e invialo. Installa la skill e l'add-on, "
                    "poi ti racconta cosa sa fare gohud.",
        "copy_note": "Il blocco è in inglese di proposito: è ciò che ogni agente legge in modo più affidabile. "
                     "Le tue domande puoi farle in qualsiasi lingua; la skill risponde nella lingua in cui scrivi.",
        "agents_h2": "Dove ogni agente tiene le skill",
        "agents_sub": "Preferisci installare a mano? Metti la cartella <code>skills/gohud</code> dove legge il tuo "
                      "agente. Vince la prima che esiste.",
        "agents_th": ("Agente", "Dove va la cartella", "Forma dei comandi"),
        "commands_h2": "I comandi che ottieni",
        "ask_h2": "Oppure chiedi e basta",
        "row_plugin": "plugin",
        "row_skill": "solo la skill",
        "row_project": "solo questo progetto",
        "row_others": "altri",
        "copy_cta": "Vedi il blocco",
        "card_h2": "La via più rapida: lascia installare al tuo agente IA",
        "card_body": "Un blocco di testo, incollato in Claude Code, Codex, Cursor o Gemini CLI, installa sia la skill sia l'add-on e poi ti spiega gohud. Se prendi quella strada, nulla sotto questa scheda serve.",
        "card_cta": "Apri la pagina AI SKILL →",
        "need": "I comandi di anteprima richiedono Godot 4.6 o successivo nel tuo <code>PATH</code>.",
    },
    "vi": {
        "copy_h2": "Dán khối này vào tác nhân lập trình của bạn",
        "copy_sub": "Mở dự án Godot trong tác nhân, dán khối bên dưới rồi gửi. Nó cài skill và add-on, "
                    "sau đó kể cho bạn nghe gohud làm được những gì.",
        "copy_note": "Khối này cố ý viết bằng tiếng Anh — đó là thứ mọi tác nhân đọc chính xác nhất. "
                     "Bạn cứ hỏi bằng ngôn ngữ nào cũng được; skill trả lời bằng đúng ngôn ngữ bạn viết.",
        "agents_h2": "Mỗi tác nhân giữ skill ở đâu",
        "agents_sub": "Muốn tự cài? Đặt thư mục <code>skills/gohud</code> vào nơi tác nhân của bạn đọc. "
                      "Nơi nào có trước thì thắng.",
        "agents_th": ("Tác nhân", "Thư mục đặt ở đâu", "Dạng lệnh"),
        "commands_h2": "Những lệnh bạn có được",
        "ask_h2": "Hoặc cứ hỏi thẳng",
        "row_plugin": "plugin",
        "row_skill": "chỉ skill",
        "row_project": "chỉ dự án này",
        "row_others": "khác",
        "copy_cta": "Xem khối để dán",
        "card_h2": "Cách nhanh nhất — để tác nhân AI cài hộ",
        "card_body": "Một khối văn bản dán vào Claude Code, Codex, Cursor hay Gemini CLI sẽ cài cả skill lẫn add-on, rồi giải thích gohud cho bạn. Đi đường đó thì mọi thứ dưới thẻ này đều không cần.",
        "card_cta": "Mở trang AI SKILL →",
        "need": "Lệnh xem trước cần Godot 4.6 trở lên trong <code>PATH</code>.",
    },
    "id": {
        "copy_h2": "Tempelkan ini ke agen codingmu",
        "copy_sub": "Buka proyek Godot di agen, tempel blok di bawah, lalu kirim. Ia memasang skill dan add-on, "
                    "lalu menceritakan apa saja yang bisa dilakukan gohud.",
        "copy_note": "Blok ini sengaja ditulis dalam bahasa Inggris — itu yang paling andal dibaca setiap agen. "
                     "Pertanyaanmu sendiri boleh bahasa apa pun; skill menjawab dalam bahasa yang kamu pakai.",
        "agents_h2": "Di mana tiap agen menyimpan skill",
        "agents_sub": "Mau pasang manual? Letakkan folder <code>skills/gohud</code> di tempat yang dibaca agenmu. "
                      "Yang ada lebih dulu yang dipakai.",
        "agents_th": ("Agen", "Folder ditaruh di mana", "Bentuk perintah"),
        "commands_h2": "Perintah yang kamu dapat",
        "ask_h2": "Atau tinggal minta saja",
        "row_plugin": "plugin",
        "row_skill": "skill saja",
        "row_project": "proyek ini saja",
        "row_others": "lainnya",
        "copy_cta": "Lihat blok",
        "card_h2": "Jalan tercepat — biarkan agen AI yang memasang",
        "card_body": "Satu blok teks, ditempel ke Claude Code, Codex, Cursor, atau Gemini CLI, memasang skill sekaligus add-on lalu menjelaskan gohud padamu. Lewat jalan itu, tak satu pun di bawah kartu ini diperlukan.",
        "card_cta": "Buka halaman AI SKILL →",
        "need": "Perintah pratinjau butuh Godot 4.6 atau lebih baru di <code>PATH</code>.",
    },
    "uk": {
        "copy_h2": "Вставте це у свій ШІ-агент",
        "copy_sub": "Відкрийте проєкт Godot в агенті, вставте блок і надішліть. Він встановить навичку та "
                    "доповнення, а тоді розповість, що вміє gohud.",
        "copy_note": "Блок навмисно написано англійською — саме її кожен агент читає найточніше. "
                     "Свої запитання ставте будь-якою мовою: навичка відповідає тією, якою ви пишете.",
        "agents_h2": "Де кожен агент тримає навички",
        "agents_sub": "Волієте встановити вручну? Покладіть теку <code>skills/gohud</code> туди, звідки читає ваш "
                      "агент. Перемагає перша наявна.",
        "agents_th": ("Агент", "Куди класти теку", "Вигляд команд"),
        "commands_h2": "Команди, які ви отримаєте",
        "ask_h2": "Або просто попросіть",
        "row_plugin": "плагін",
        "row_skill": "лише навичка",
        "row_project": "лише цей проєкт",
        "row_others": "інші",
        "copy_cta": "До блоку для вставки",
        "card_h2": "Найшвидший шлях — доручіть встановлення ШІ-агенту",
        "card_body": "Один блок тексту, вставлений у Claude Code, Codex, Cursor чи Gemini CLI, встановить і навичку, і доповнення, а тоді пояснить вам gohud. На цьому шляху ніщо нижче цієї картки не потрібне.",
        "card_cta": "Відкрити сторінку AI SKILL →",
        "need": "Команди попереднього перегляду потребують Godot 4.6 або новішого у <code>PATH</code>.",
    },
    "th": {
        "copy_h2": "วางข้อความนี้ลงในเอเจนต์เขียนโค้ดของคุณ",
        "copy_sub": "เปิดโปรเจกต์ Godot ในเอเจนต์ วางบล็อกด้านล่างแล้วส่ง มันจะติดตั้ง skill และแอดออน "
                    "จากนั้นจะบอกคุณว่า gohud ทำอะไรได้บ้าง",
        "copy_note": "บล็อกนี้เขียนเป็นภาษาอังกฤษโดยตั้งใจ — เป็นภาษาที่เอเจนต์ทุกตัวอ่านได้แม่นที่สุด "
                     "คุณถามด้วยภาษาใดก็ได้ skill จะตอบด้วยภาษาที่คุณเขียน",
        "agents_h2": "เอเจนต์แต่ละตัวเก็บ skill ไว้ที่ไหน",
        "agents_sub": "อยากติดตั้งเองหรือ? วางโฟลเดอร์ <code>skills/gohud</code> ไว้ที่เอเจนต์ของคุณอ่าน "
                      "อันที่มีอยู่ก่อนจะถูกใช้",
        "agents_th": ("เอเจนต์", "วางโฟลเดอร์ไว้ที่ไหน", "รูปแบบคำสั่ง"),
        "commands_h2": "คำสั่งที่คุณจะได้",
        "ask_h2": "หรือจะขอตรง ๆ ก็ได้",
        "row_plugin": "ปลั๊กอิน",
        "row_skill": "เฉพาะ skill",
        "row_project": "เฉพาะโปรเจกต์นี้",
        "row_others": "อื่น ๆ",
        "copy_cta": "ดูบล็อกที่จะวาง",
        "card_h2": "ทางที่เร็วที่สุด — ให้เอเจนต์ AI ติดตั้งให้",
        "card_body": "ข้อความบล็อกเดียว วางลงใน Claude Code, Codex, Cursor หรือ Gemini CLI จะติดตั้งทั้ง skill และแอดออน แล้วอธิบาย gohud ให้คุณฟัง ถ้าไปทางนี้ ทุกอย่างใต้การ์ดนี้ไม่จำเป็นเลย",
        "card_cta": "เปิดหน้า AI SKILL →",
        "need": "คำสั่งพรีวิวต้องมี Godot 4.6 ขึ้นไปอยู่ใน <code>PATH</code>",
    },
    "ar": {
        "copy_h2": "الصق هذا في وكيل البرمجة لديك",
        "copy_sub": "افتح مشروع Godot في الوكيل، والصق الكتلة أدناه ثم أرسلها. سيثبّت المهارة والإضافة، "
                    "ثم يخبرك بما يستطيع gohud فعله.",
        "copy_note": "كُتبت الكتلة بالإنجليزية عن قصد — فهي اللغة التي يقرأها كل وكيل بأعلى دقة. "
                     "أما أسئلتك فاطرحها بأي لغة؛ تجيبك المهارة باللغة التي تكتب بها.",
        "agents_h2": "أين يحفظ كل وكيل المهارات",
        "agents_sub": "تفضّل التثبيت يدويًا؟ ضع مجلد <code>skills/gohud</code> في المكان الذي يقرأ منه وكيلك. "
                      "الأسبق وجودًا هو المعتمد.",
        "agents_th": ("الوكيل", "أين يوضع المجلد", "شكل الأوامر"),
        "commands_h2": "الأوامر التي تحصل عليها",
        "ask_h2": "أو اطلب ببساطة",
        "row_plugin": "إضافة",
        "row_skill": "المهارة فقط",
        "row_project": "هذا المشروع فقط",
        "row_others": "غيرها",
        "copy_cta": "انظر الكتلة",
        "card_h2": "أسرع طريق — دع وكيل الذكاء الاصطناعي يثبّته",
        "card_body": "كتلة نصية واحدة، تُلصق في Claude Code أو Codex أو Cursor أو Gemini CLI، تثبّت المهارة والإضافة معًا ثم تشرح لك gohud. إن سلكت هذا الطريق فلا حاجة لأي شيء أسفل هذه البطاقة.",
        "card_cta": "افتح صفحة AI SKILL →",
        "need": "تحتاج أوامر المعاينة إلى Godot 4.6 أو أحدث في <code>PATH</code>.",
    },
}


def text(code, key):
    """한 언어의 말 한 토막. 모르는 언어는 영어로 떨어진다."""
    return TEXT.get(code, TEXT["en"]).get(key, TEXT["en"][key])
