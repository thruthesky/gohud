# -*- coding: utf-8 -*-
"""The words the `ai.html` page (menu name: **Go HUD Skill**) uses — all 17 languages **in this one place**.

`tools/make_ai_page.py` combines this table with the translated text of the old `#ai` section and
builds the 17 `ai.html` pages.

## 🛑 The block to paste stays **in English** in all 17 languages
It is not prose for a person; it is **an instruction for an agent**. English is what every coding agent
reads most accurately, and every command (`claude plugin …`), path (`~/.claude/skills/gohud`) and folder
name in it is English — translating half of it only mixes the two. Instead, **right under the block**, the
reader's own language says why it is English and that they may ask in any language (`copy_note`).

## 🛑 Every line in the block must have a source in this repository
A path that does not exist is a broken instruction. Sources:
- the two `claude plugin …` lines — `.claude-plugin/marketplace.json` (`name: gohud`) and the
  `claude plugin install <plugin>@<marketplace>` form of Claude Code's CLI (`claude plugin install --help`)
- the three skill folders — the places `skills/gohud/commands/preview.md` actually looks
- `git submodule add …` — the install section of `README.md`
- `godot --headless --path . --import` and the `SCRIPT ERROR` / `Parse Error` lines — `skills/gohud/SKILL.md` §2
- "restart" — `claude plugin update --help` says a restart is required to apply a plugin
🛑 Cursor's and Gemini's **own** skill paths have no source in this repository, so the products are named
but the paths are limited to the three above.

## The hero button copies the block
`<a data-copy="install-prompt">` (handled in `site/ux.js`) copies the block in one click and says
`copied_cta`; without script it is a link to `#copy`. `step2` names the Copy button on the block itself, so
its word must match that language's label in `SAY` of `site/ux.js`.
"""

# The text pasted into an agent — the same in every language. 🛑 Check the source list above when editing.
COPY_BLOCK = """Install gohud for this Godot 4.6+ project, then use it for all game UI
(menus, HUD bars, quick slots, dialogs, bottom sheets, forms, themes).

1. Install the gohud AI skill.
   Claude Code - run these two commands in a shell:
     claude plugin marketplace add thruthesky/gohud
     claude plugin install gohud@gohud
   Any other agent (Codex, Cursor, Gemini CLI, ...):
     git clone --depth 1 https://github.com/thruthesky/gohud.git /tmp/gohud
     Copy /tmp/gohud/skills/gohud into whichever of these folders this agent reads:
     ~/.claude/skills/gohud, .claude/skills/gohud, .agents/skills/gohud.

2. Install the add-on itself, unless addons/gohud/plugin.cfg already exists here.
   In a git repository:
     git submodule add https://github.com/thruthesky/gohud.git addons/gohud
   Otherwise copy the clone to addons/gohud without its .git folder.
   Then run: godot --headless --path . --import
   (If godot is not on PATH, ask me where Godot 4.6+ is.)

3. Check the result: addons/gohud/plugin.cfg exists and the import printed
   no "SCRIPT ERROR" or "Parse Error" lines.

4. A new skill loads when the agent starts. Tell me if I have to restart you,
   then tell me what gohud can do and how to preview it.

Docs: https://thruthesky.github.io/gohud/"""

# The two commands of the Claude Code section — typed in a terminal, and the same inside Claude Code.
CLAUDE_TERMINAL = """claude plugin marketplace add thruthesky/gohud
claude plugin install gohud@gohud"""
CLAUDE_INSIDE = """/plugin marketplace add thruthesky/gohud
/plugin install gohud@gohud"""

# Where each agent keeps the skill — (product name, description key, folder, how commands look).
# 🛑 Paths and command spellings are not translated (they are typed exactly). Product names stay too.
#    Only the one-word description is translated, and it lives under `row_*` in `TEXT` below.
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
        "copy_cta": "Copy the install prompt",
        "card_h2": "Fastest way — let your AI agent install it",
        "card_body": "One block of text, pasted into Claude Code, Codex, Cursor or Gemini CLI, installs both the skill and the add-on and then explains gohud to you. Nothing below this card is needed if you take that road.",
        "card_cta": "Open the Go HUD Skill page →",
        "need": "You need Godot 4.6 or newer on your <code>PATH</code> for the preview commands.",
        "copied_cta": "Copied — now paste it into your agent",
        "step1": "Open a terminal in your Godot project folder and start your coding agent there — for example <code>claude</code>.",
        "step2": "Press <b>Copy</b> on the block below, paste it into the agent and send it.",
        "step3": "When it is done, restart the agent if it asks you to, then ask it: <i>What can gohud do?</i>",
        "cc_h2": "Or type two commands — Claude Code",
        "cc_sub": "This installs the skill as a Claude Code plugin. In a terminal:",
        "cc_inside": "Already inside Claude Code? Type these instead:",
        "cc_check": "Then restart Claude Code and type <code>/gohud:features</code> — if it lists gohud's features, the skill is in. The add-on itself still goes into <code>addons/gohud</code>:",
    },
    "ko": {
        "copy_h2": "이걸 코딩 에이전트에 붙여 넣는다",
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
        "copy_cta": "설치 프롬프트 복사",
        "card_h2": "가장 빠른 길 — AI 에게 설치를 맡긴다",
        "card_body": "아래 글을 그대로 Claude Code·Codex·Cursor·Gemini CLI 에 붙여 넣으면 스킬과 애드온을 함께 설치하고 gohud 를 설명까지 해 준다. 그 길로 가면 이 카드 아래의 것은 하나도 필요 없다.",
        "card_cta": "Go HUD Skill 페이지 열기 →",
        "need": "미리보기 명령을 쓰려면 <code>PATH</code> 에 Godot 4.6 이상이 있어야 한다.",
        "copied_cta": "복사함 — 이제 에이전트에 붙여 넣는다",
        "step1": "Godot 프로젝트 폴더에서 터미널을 열고 그 자리에서 코딩 에이전트를 실행한다 — 예: <code>claude</code>.",
        "step2": "아래 블록의 <b>복사</b> 버튼을 눌러 에이전트에 붙여 넣고 보낸다.",
        "step3": "끝나면, 에이전트가 다시 시작하라고 할 때 다시 시작하고 이렇게 묻는다: <i>gohud 로 무엇을 할 수 있어?</i>",
        "cc_h2": "또는 명령 두 줄 — Claude Code",
        "cc_sub": "스킬을 Claude Code 플러그인으로 설치한다. 터미널에서:",
        "cc_inside": "이미 Claude Code 안에 있다면 이것을 친다:",
        "cc_check": "그다음 Claude Code 를 다시 시작하고 <code>/gohud:features</code> 를 친다 — gohud 기능 목록이 나오면 스킬이 들어간 것이다. 애드온 자체는 따로 <code>addons/gohud</code> 에 있어야 한다:",
    },
    "ja": {
        "copy_h2": "これをコーディングエージェントに貼り付ける",
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
        "copy_cta": "インストール用プロンプトをコピー",
        "card_h2": "いちばん速い道 — AI にインストールを任せる",
        "card_body": "下の文をそのまま Claude Code・Codex・Cursor・Gemini CLI に貼れば、スキルとアドオンを一緒に入れ、gohud の説明までしてくれる。その道を行くなら、このカードから下は一つも要らない。",
        "card_cta": "Go HUD Skill のページを開く →",
        "need": "プレビューのコマンドには <code>PATH</code> に Godot 4.6 以上が要る。",
        "copied_cta": "コピーしました — エージェントに貼り付ける",
        "step1": "Godot プロジェクトのフォルダーでターミナルを開き、そこでコーディングエージェントを起動する — 例: <code>claude</code>。",
        "step2": "下のブロックの<b>コピー</b>を押し、エージェントに貼って送る。",
        "step3": "終わったら、求められればエージェントを再起動し、こう聞く: <i>gohud で何ができる？</i>",
        "cc_h2": "またはコマンド 2 行 — Claude Code",
        "cc_sub": "スキルを Claude Code のプラグインとして入れる。ターミナルで:",
        "cc_inside": "すでに Claude Code の中なら、こちらを打つ:",
        "cc_check": "それから Claude Code を再起動して <code>/gohud:features</code> と打つ — gohud の機能一覧が出ればスキルは入っている。アドオン本体は別に <code>addons/gohud</code> に要る:",
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
        "copy_cta": "复制安装提示词",
        "card_h2": "最快的路 —— 让 AI 代理替你安装",
        "card_body": "把一段文字粘贴到 Claude Code、Codex、Cursor 或 Gemini CLI，它会同时装好技能和插件，再为你讲解 gohud。走这条路，这张卡片以下的内容一样都不需要。",
        "card_cta": "打开 Go HUD Skill 页 →",
        "need": "预览命令需要 <code>PATH</code> 中有 Godot 4.6 或更新版本。",
        "copied_cta": "已复制 —— 粘贴到你的代理里",
        "step1": "在 Godot 项目文件夹中打开终端，并在那里启动编码代理 —— 例如 <code>claude</code>。",
        "step2": "点击下方代码块上的<b>复制</b>，粘贴到代理中并发送。",
        "step3": "完成后，如果代理要求就重启它，然后问它：<i>gohud 能做什么？</i>",
        "cc_h2": "或者输入两条命令 —— Claude Code",
        "cc_sub": "这会把技能作为 Claude Code 插件安装。在终端中：",
        "cc_inside": "已经在 Claude Code 里了？改为输入：",
        "cc_check": "然后重启 Claude Code 并输入 <code>/gohud:features</code> —— 列出 gohud 的功能就说明技能已装好。gohud 插件本体仍需放在 <code>addons/gohud</code>：",
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
        "copy_cta": "複製安裝提示詞",
        "card_h2": "最快的路 —— 讓 AI 代理替你安裝",
        "card_body": "把一段文字貼到 Claude Code、Codex、Cursor 或 Gemini CLI，它會同時裝好技能與外掛，再為你講解 gohud。走這條路，這張卡片以下的內容一樣都不需要。",
        "card_cta": "開啟 Go HUD Skill 頁 →",
        "need": "預覽指令需要 <code>PATH</code> 中有 Godot 4.6 或更新版本。",
        "copied_cta": "已複製 —— 貼到你的代理裡",
        "step1": "在 Godot 專案資料夾中開啟終端機，並在那裡啟動編碼代理 —— 例如 <code>claude</code>。",
        "step2": "點下方程式碼區塊上的<b>複製</b>，貼到代理中並送出。",
        "step3": "完成後，若代理要求就重新啟動它，然後問它：<i>gohud 能做什麼？</i>",
        "cc_h2": "或者輸入兩行指令 —— Claude Code",
        "cc_sub": "這會把技能以 Claude Code 外掛安裝。在終端機中：",
        "cc_inside": "已經在 Claude Code 裡了？改為輸入：",
        "cc_check": "接著重新啟動 Claude Code 並輸入 <code>/gohud:features</code> —— 列出 gohud 的功能就代表技能已裝好。gohud 外掛本體仍需放在 <code>addons/gohud</code>：",
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
        "copy_cta": "Copiar el prompt de instalación",
        "card_h2": "La vía más rápida: que lo instale tu agente de IA",
        "card_body": "Un bloque de texto, pegado en Claude Code, Codex, Cursor o Gemini CLI, instala la skill y el complemento y luego te explica gohud. Si tomas ese camino, nada de lo que hay debajo de esta tarjeta hace falta.",
        "card_cta": "Abrir la página Go HUD Skill →",
        "need": "Los comandos de vista previa necesitan Godot 4.6 o superior en tu <code>PATH</code>.",
        "copied_cta": "Copiado: ahora pégalo en tu agente",
        "step1": "Abre una terminal en la carpeta de tu proyecto de Godot e inicia allí tu agente de código; por ejemplo, <code>claude</code>.",
        "step2": "Pulsa <b>Copiar</b> en el bloque de abajo, pégalo en el agente y envíalo.",
        "step3": "Cuando termine, reinicia el agente si te lo pide y pregúntale: <i>¿Qué puede hacer gohud?</i>",
        "cc_h2": "O escribe dos comandos: Claude Code",
        "cc_sub": "Esto instala la skill como plugin de Claude Code. En una terminal:",
        "cc_inside": "¿Ya estás dentro de Claude Code? Escribe esto en su lugar:",
        "cc_check": "Después reinicia Claude Code y escribe <code>/gohud:features</code>: si aparece la lista de funciones de gohud, la skill está instalada. El complemento en sí sigue yendo en <code>addons/gohud</code>:",
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
        "copy_cta": "Copiar o prompt de instalação",
        "card_h2": "O caminho mais rápido: deixe o seu agente de IA instalar",
        "card_body": "Um bloco de texto, colado no Claude Code, Codex, Cursor ou Gemini CLI, instala a skill e o add-on e depois explica-lhe o gohud. Se seguir por aí, nada abaixo deste cartão é preciso.",
        "card_cta": "Abrir a página Go HUD Skill →",
        "need": "Os comandos de pré-visualização precisam do Godot 4.6 ou mais recente no seu <code>PATH</code>.",
        "copied_cta": "Copiado — agora cole-o no seu agente",
        "step1": "Abra um terminal na pasta do seu projeto Godot e inicie lá o seu agente de código — por exemplo, <code>claude</code>.",
        "step2": "Clique em <b>Copiar</b> no bloco abaixo, cole-o no agente e envie.",
        "step3": "Quando terminar, reinicie o agente se ele o pedir e pergunte-lhe: <i>O que o gohud consegue fazer?</i>",
        "cc_h2": "Ou escreva dois comandos — Claude Code",
        "cc_sub": "Isto instala a skill como plugin do Claude Code. Num terminal:",
        "cc_inside": "Já está dentro do Claude Code? Escreva antes isto:",
        "cc_check": "Depois reinicie o Claude Code e escreva <code>/gohud:features</code> — se aparecer a lista de funcionalidades do gohud, a skill está instalada. O add-on em si continua a ir para <code>addons/gohud</code>:",
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
        "copy_cta": "Скопировать промпт установки",
        "card_h2": "Самый быстрый путь — поручите установку ИИ-агенту",
        "card_body": "Один блок текста, вставленный в Claude Code, Codex, Cursor или Gemini CLI, установит и навык, и дополнение, а потом объяснит вам gohud. На этом пути ничего ниже этой карточки не нужно.",
        "card_cta": "Открыть страницу Go HUD Skill →",
        "need": "Для команд предпросмотра нужен Godot 4.6 или новее в <code>PATH</code>.",
        "copied_cta": "Скопировано — вставьте в агент",
        "step1": "Откройте терминал в папке проекта Godot и запустите там свой ИИ-агент — например, <code>claude</code>.",
        "step2": "Нажмите <b>Копировать</b> на блоке ниже, вставьте его в агент и отправьте.",
        "step3": "Когда он закончит, перезапустите агент, если он попросит, и спросите: <i>Что умеет gohud?</i>",
        "cc_h2": "Или две команды — Claude Code",
        "cc_sub": "Так навык ставится как плагин Claude Code. В терминале:",
        "cc_inside": "Уже внутри Claude Code? Тогда введите это:",
        "cc_check": "Затем перезапустите Claude Code и введите <code>/gohud:features</code> — если появился список возможностей gohud, навык установлен. Само дополнение по-прежнему должно лежать в <code>addons/gohud</code>:",
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
        "copy_cta": "Copier le prompt d'installation",
        "card_h2": "Le chemin le plus rapide : laissez votre agent IA installer",
        "card_body": "Un bloc de texte collé dans Claude Code, Codex, Cursor ou Gemini CLI installe la compétence et l'extension, puis vous explique gohud. Sur cette voie, rien de ce qui suit cette carte n'est nécessaire.",
        "card_cta": "Ouvrir la page Go HUD Skill →",
        "need": "Les commandes d'aperçu demandent Godot 4.6 ou plus récent dans votre <code>PATH</code>.",
        "copied_cta": "Copié — collez-le dans votre agent",
        "step1": "Ouvrez un terminal dans le dossier de votre projet Godot et lancez-y votre agent de code — par exemple <code>claude</code>.",
        "step2": "Appuyez sur <b>Copier</b> sur le bloc ci-dessous, collez-le dans l'agent et envoyez.",
        "step3": "Quand il a fini, redémarrez l'agent s'il vous le demande, puis demandez-lui : <i>Que sait faire gohud ?</i>",
        "cc_h2": "Ou tapez deux commandes — Claude Code",
        "cc_sub": "Cela installe la compétence comme plugin Claude Code. Dans un terminal :",
        "cc_inside": "Déjà dans Claude Code ? Tapez plutôt ceci :",
        "cc_check": "Redémarrez ensuite Claude Code et tapez <code>/gohud:features</code> — si la liste des fonctionnalités de gohud s'affiche, la compétence est installée. L'extension elle-même doit toujours se trouver dans <code>addons/gohud</code> :",
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
        "copy_cta": "Kurulum istemini kopyala",
        "card_h2": "En hızlı yol — kurulumu yapay zekâ ajanınıza bırakın",
        "card_body": "Claude Code, Codex, Cursor ya da Gemini CLI'a yapıştırılan tek bir metin bloğu hem beceriyi hem eklentiyi kurar, sonra size gohud'u anlatır. Bu yolu seçerseniz bu kartın altındakilerin hiçbiri gerekmez.",
        "card_cta": "Go HUD Skill sayfasını aç →",
        "need": "Önizleme komutları için <code>PATH</code> içinde Godot 4.6 veya üstü gerekir.",
        "copied_cta": "Kopyalandı — şimdi ajanınıza yapıştırın",
        "step1": "Godot proje klasörünüzde bir terminal açın ve kodlama ajanınızı orada başlatın — örneğin <code>claude</code>.",
        "step2": "Aşağıdaki bloktaki <b>Kopyala</b> düğmesine basın, ajana yapıştırıp gönderin.",
        "step3": "İş bitince ajan isterse onu yeniden başlatın, sonra sorun: <i>gohud neler yapabilir?</i>",
        "cc_h2": "Ya da iki komut yazın — Claude Code",
        "cc_sub": "Bu, beceriyi bir Claude Code eklentisi olarak kurar. Bir terminalde:",
        "cc_inside": "Zaten Claude Code içinde misiniz? Bunun yerine şunları yazın:",
        "cc_check": "Ardından Claude Code'u yeniden başlatıp <code>/gohud:features</code> yazın — gohud'un özellik listesi çıkıyorsa beceri kurulmuştur. Eklentinin kendisi yine <code>addons/gohud</code> içinde olmalı:",
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
        "copy_cta": "Kopiuj prompt instalacyjny",
        "card_h2": "Najszybsza droga — niech zainstaluje to agent AI",
        "card_body": "Jeden blok tekstu wklejony do Claude Code, Codex, Cursora lub Gemini CLI instaluje i umiejętność, i dodatek, a potem objaśnia ci gohud. Na tej drodze nic poniżej tej karty nie jest potrzebne.",
        "card_cta": "Otwórz stronę Go HUD Skill →",
        "need": "Polecenia podglądu wymagają Godota 4.6 lub nowszego w <code>PATH</code>.",
        "copied_cta": "Skopiowano — wklej to do agenta",
        "step1": "Otwórz terminal w folderze projektu Godota i uruchom tam swojego agenta kodu — na przykład <code>claude</code>.",
        "step2": "Kliknij <b>Kopiuj</b> na bloku poniżej, wklej go do agenta i wyślij.",
        "step3": "Gdy skończy, uruchom agenta ponownie, jeśli o to poprosi, i zapytaj: <i>Co potrafi gohud?</i>",
        "cc_h2": "Albo wpisz dwa polecenia — Claude Code",
        "cc_sub": "To instaluje umiejętność jako wtyczkę Claude Code. W terminalu:",
        "cc_inside": "Jesteś już w Claude Code? Wpisz zamiast tego:",
        "cc_check": "Potem uruchom ponownie Claude Code i wpisz <code>/gohud:features</code> — jeśli pojawi się lista funkcji gohud, umiejętność jest zainstalowana. Sam dodatek nadal musi trafić do <code>addons/gohud</code>:",
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
        "copy_cta": "Copia il prompt di installazione",
        "card_h2": "La via più rapida: lascia installare al tuo agente IA",
        "card_body": "Un blocco di testo, incollato in Claude Code, Codex, Cursor o Gemini CLI, installa sia la skill sia l'add-on e poi ti spiega gohud. Se prendi quella strada, nulla sotto questa scheda serve.",
        "card_cta": "Apri la pagina Go HUD Skill →",
        "need": "I comandi di anteprima richiedono Godot 4.6 o successivo nel tuo <code>PATH</code>.",
        "copied_cta": "Copiato: ora incollalo nel tuo agente",
        "step1": "Apri un terminale nella cartella del progetto Godot e avvia lì il tuo agente di codice, per esempio <code>claude</code>.",
        "step2": "Premi <b>Copia</b> sul blocco qui sotto, incollalo nell'agente e invialo.",
        "step3": "Quando ha finito, riavvia l'agente se te lo chiede, poi chiedigli: <i>Cosa sa fare gohud?</i>",
        "cc_h2": "Oppure digita due comandi: Claude Code",
        "cc_sub": "Così la skill si installa come plugin di Claude Code. In un terminale:",
        "cc_inside": "Sei già dentro Claude Code? Digita invece questi:",
        "cc_check": "Poi riavvia Claude Code e digita <code>/gohud:features</code>: se compare l'elenco delle funzioni di gohud, la skill è installata. L'add-on vero e proprio va comunque in <code>addons/gohud</code>:",
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
        "copy_cta": "Chép lời nhắc cài đặt",
        "card_h2": "Cách nhanh nhất — để tác nhân AI cài hộ",
        "card_body": "Một khối văn bản dán vào Claude Code, Codex, Cursor hay Gemini CLI sẽ cài cả skill lẫn add-on, rồi giải thích gohud cho bạn. Đi đường đó thì mọi thứ dưới thẻ này đều không cần.",
        "card_cta": "Mở trang Go HUD Skill →",
        "need": "Lệnh xem trước cần Godot 4.6 trở lên trong <code>PATH</code>.",
        "copied_cta": "Đã chép — giờ dán vào tác nhân của bạn",
        "step1": "Mở terminal trong thư mục dự án Godot và khởi động tác nhân lập trình ở đó — ví dụ <code>claude</code>.",
        "step2": "Bấm <b>Chép</b> trên khối bên dưới, dán vào tác nhân rồi gửi.",
        "step3": "Khi xong, khởi động lại tác nhân nếu nó yêu cầu, rồi hỏi: <i>gohud làm được gì?</i>",
        "cc_h2": "Hoặc gõ hai lệnh — Claude Code",
        "cc_sub": "Cách này cài skill dưới dạng plugin của Claude Code. Trong terminal:",
        "cc_inside": "Đang ở trong Claude Code rồi? Hãy gõ những lệnh này:",
        "cc_check": "Sau đó khởi động lại Claude Code và gõ <code>/gohud:features</code> — nếu hiện danh sách tính năng của gohud thì skill đã được cài. Bản thân add-on vẫn phải nằm trong <code>addons/gohud</code>:",
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
        "copy_cta": "Salin prompt instalasi",
        "card_h2": "Jalan tercepat — biarkan agen AI yang memasang",
        "card_body": "Satu blok teks, ditempel ke Claude Code, Codex, Cursor, atau Gemini CLI, memasang skill sekaligus add-on lalu menjelaskan gohud padamu. Lewat jalan itu, tak satu pun di bawah kartu ini diperlukan.",
        "card_cta": "Buka halaman Go HUD Skill →",
        "need": "Perintah pratinjau butuh Godot 4.6 atau lebih baru di <code>PATH</code>.",
        "copied_cta": "Tersalin — sekarang tempel ke agenmu",
        "step1": "Buka terminal di folder proyek Godot-mu dan jalankan agen coding di sana — misalnya <code>claude</code>.",
        "step2": "Tekan <b>Salin</b> pada blok di bawah, tempel ke agen, lalu kirim.",
        "step3": "Setelah selesai, mulai ulang agen jika ia memintanya, lalu tanyakan: <i>Apa saja yang bisa dilakukan gohud?</i>",
        "cc_h2": "Atau ketik dua perintah — Claude Code",
        "cc_sub": "Ini memasang skill sebagai plugin Claude Code. Di terminal:",
        "cc_inside": "Sudah di dalam Claude Code? Ketik ini saja:",
        "cc_check": "Lalu mulai ulang Claude Code dan ketik <code>/gohud:features</code> — kalau muncul daftar fitur gohud, skill sudah terpasang. Add-on-nya sendiri tetap harus ada di <code>addons/gohud</code>:",
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
        "copy_cta": "Скопіювати промпт встановлення",
        "card_h2": "Найшвидший шлях — доручіть встановлення ШІ-агенту",
        "card_body": "Один блок тексту, вставлений у Claude Code, Codex, Cursor чи Gemini CLI, встановить і навичку, і доповнення, а тоді пояснить вам gohud. На цьому шляху ніщо нижче цієї картки не потрібне.",
        "card_cta": "Відкрити сторінку Go HUD Skill →",
        "need": "Команди попереднього перегляду потребують Godot 4.6 або новішого у <code>PATH</code>.",
        "copied_cta": "Скопійовано — вставте в агент",
        "step1": "Відкрийте термінал у теці проєкту Godot і запустіть там свій ШІ-агент — наприклад, <code>claude</code>.",
        "step2": "Натисніть <b>Копіювати</b> на блоці нижче, вставте його в агент і надішліть.",
        "step3": "Коли він закінчить, перезапустіть агент, якщо він попросить, і запитайте: <i>Що вміє gohud?</i>",
        "cc_h2": "Або дві команди — Claude Code",
        "cc_sub": "Так навичка встановлюється як плагін Claude Code. У терміналі:",
        "cc_inside": "Уже всередині Claude Code? Тоді введіть це:",
        "cc_check": "Потім перезапустіть Claude Code і введіть <code>/gohud:features</code> — якщо з'явився список можливостей gohud, навичку встановлено. Саме доповнення все одно має лежати в <code>addons/gohud</code>:",
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
        "copy_cta": "คัดลอกพรอมต์ติดตั้ง",
        "card_h2": "ทางที่เร็วที่สุด — ให้เอเจนต์ AI ติดตั้งให้",
        "card_body": "ข้อความบล็อกเดียว วางลงใน Claude Code, Codex, Cursor หรือ Gemini CLI จะติดตั้งทั้ง skill และแอดออน แล้วอธิบาย gohud ให้คุณฟัง ถ้าไปทางนี้ ทุกอย่างใต้การ์ดนี้ไม่จำเป็นเลย",
        "card_cta": "เปิดหน้า Go HUD Skill →",
        "need": "คำสั่งพรีวิวต้องมี Godot 4.6 ขึ้นไปอยู่ใน <code>PATH</code>",
        "copied_cta": "คัดลอกแล้ว — วางลงในเอเจนต์ได้เลย",
        "step1": "เปิดเทอร์มินัลในโฟลเดอร์โปรเจกต์ Godot แล้วเริ่มเอเจนต์เขียนโค้ดที่นั่น — เช่น <code>claude</code>",
        "step2": "กด <b>คัดลอก</b> ที่บล็อกด้านล่าง วางลงในเอเจนต์แล้วส่ง",
        "step3": "เมื่อเสร็จแล้ว ถ้าเอเจนต์ขอให้รีสตาร์ตก็รีสตาร์ต จากนั้นถามว่า: <i>gohud ทำอะไรได้บ้าง?</i>",
        "cc_h2": "หรือพิมพ์สองคำสั่ง — Claude Code",
        "cc_sub": "วิธีนี้ติดตั้ง skill เป็นปลั๊กอินของ Claude Code ในเทอร์มินัล:",
        "cc_inside": "อยู่ใน Claude Code อยู่แล้วหรือ? พิมพ์คำสั่งเหล่านี้แทน:",
        "cc_check": "จากนั้นรีสตาร์ต Claude Code แล้วพิมพ์ <code>/gohud:features</code> — ถ้าขึ้นรายการฟีเจอร์ของ gohud แปลว่าติดตั้ง skill แล้ว ส่วนตัวแอดออนเองยังต้องอยู่ใน <code>addons/gohud</code>:",
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
        "copy_cta": "انسخ موجّه التثبيت",
        "card_h2": "أسرع طريق — دع وكيل الذكاء الاصطناعي يثبّته",
        "card_body": "كتلة نصية واحدة، تُلصق في Claude Code أو Codex أو Cursor أو Gemini CLI، تثبّت المهارة والإضافة معًا ثم تشرح لك gohud. إن سلكت هذا الطريق فلا حاجة لأي شيء أسفل هذه البطاقة.",
        "card_cta": "افتح صفحة Go HUD Skill →",
        "need": "تحتاج أوامر المعاينة إلى Godot 4.6 أو أحدث في <code>PATH</code>.",
        "copied_cta": "تم النسخ — الصقه الآن في وكيلك",
        "step1": "افتح طرفية في مجلد مشروع Godot وشغّل وكيل البرمجة هناك — مثلًا <code>claude</code>.",
        "step2": "اضغط <b>نسخ</b> على الكتلة أدناه، والصقها في الوكيل ثم أرسلها.",
        "step3": "عند انتهائه، أعد تشغيل الوكيل إن طلب ذلك، ثم اسأله: <i>ماذا يستطيع gohud أن يفعل؟</i>",
        "cc_h2": "أو اكتب أمرين — Claude Code",
        "cc_sub": "يثبّت هذا المهارة كإضافة لـ Claude Code. في الطرفية:",
        "cc_inside": "أنت داخل Claude Code بالفعل؟ اكتب هذه بدلًا من ذلك:",
        "cc_check": "ثم أعد تشغيل Claude Code واكتب <code>/gohud:features</code> — إن ظهرت قائمة ميزات gohud فالمهارة مثبّتة. أما الإضافة نفسها فلا بد أن تكون في <code>addons/gohud</code>:",
    },
}


def text(code, key):
    """One piece of wording in one language. An unknown language or key falls back to English."""
    return TEXT.get(code, TEXT["en"]).get(key, TEXT["en"][key])
