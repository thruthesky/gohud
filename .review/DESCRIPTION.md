**gohud** is a HUD and UI kit for Godot 4 that you can bend to your game instead of bending your
game to it. Drop it into `res://addons/gohud/` and it works — enabling the editor plugin only adds
conveniences.

📖 **Tutorials & docs → https://thruthesky.github.io/gohud/**

* 🧱 [Widgets guide](https://thruthesky.github.io/gohud/docs/www/widgets.html) — dialogs, sheets, forms, HUD and more
* 🎨 [Theming guide](https://thruthesky.github.io/gohud/docs/www/theming.html) — presets, JSON themes, shapes and icons

### 🤖 Let your AI coding agent install and use it

Copy the text below and paste it into Claude Code (or any coding agent that can run shell commands) inside your
Godot project. It installs the **gohud skill** — the full API, templates and recipes — and the add-on itself.

```text
Install gohud for this Godot 4.6+ project, then use it for all game UI (menus, HUD, dialogs, forms, themes).
1. Install the gohud AI skill.
   Claude Code: claude plugin marketplace add thruthesky/gohud && claude plugin install gohud@gohud
   Other agents: git clone --depth 1 https://github.com/thruthesky/gohud.git /tmp/gohud
   and copy /tmp/gohud/skills/gohud into your skills folder (for example ~/.claude/skills/gohud).
2. If project.godot is here and addons/gohud/plugin.cfg is missing, install the add-on:
   git submodule add https://github.com/thruthesky/gohud.git addons/gohud (when this is a git repo),
   otherwise copy the clone to addons/gohud without its .git folder.
   Then run: godot --headless --path . --import
3. Tell me to restart the agent, then show me what gohud can do and how to preview it.
```

After a restart: **`/gohud:features`** explains every feature, **`/gohud:preview`** opens the widget gallery
(`/gohud:preview demo` for the guided tour, `/gohud:preview gallery --preset medieval_dark --phone` for a look
and size). Installed as a plain skill in `~/.claude/skills/gohud`, the same commands are `/gohud features` and
`/gohud preview`. Then just ask, for example: *"Build a pause menu with gohud"* or *"Add HP bars and quick slots
to my HUD in the sci-fi preset"*.

### 🧩 Widgets

| | |
|---|---|
| `GoSurface` | Draggable, resizable modal window with scrim, header and optional scrolling body |
| `GoSheet` | Bottom sheet with sticky toolbar and footer, drag-to-dismiss |
| `GoDialogs` | `await` alert / confirm / prompt / choice |
| `GoForm` | Labelled rows that become a single column on narrow screens |
| `GoNotice` | Snackbars and toasts that never swallow input |
| `GoPromptCard` · `GoCoachMark` | Inline prompts and spotlight tutorials |
| `GoHudAnchor` · `GoBar` · `GoSlot` · `GoJoystick` | HUD corners, resource bars, quick slots, virtual stick |
| `GoStyle` | One-line factories for buttons, chips, list rows, flowing rows and foldable sections |

### 🎭 Six presets, one line

`GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)` swaps theme, skin and icons together.

| Preset | Look |
|---|---|
| `default_dark` · `default_light` | Rounded, clean panels |
| `scifi_dark` · `scifi_light` | Chamfered panels with neon glow |
| `medieval_dark` · `medieval_light` | Iron and leather or parchment, antique-gold frames, engraved icons, Cinzel headings |

Need your own look? Write a palette JSON — themes can inherit other themes.

### ⚙️ Everything is an option

All settings live in **one `GoConfig` resource** that survives add-on updates: preset, theme and accent,
icon set, base font size, corner radius, spacing scale, breakpoints, surface behaviour, haptics,
sound cues, strings and accessibility. Change a field, call `GoUi.refresh()`, and every live widget
updates.

### 🔄 Swap the icons, keep the code

Widgets ask for icons **by name** (`GoIconSet.CLOSE`), never by path. Point `GoConfig.icons` at:

* your own SVG set, or
* an **icon font** (`font` + `codepoints`) such as Font Awesome or Material Symbols, or
* a partial set with `fallback` pointing at the bundled one — override just the few you care about.

The 100 bundled icons (84 default + 16 engraved medieval) are original, MIT, and imported as
`DPITexture`, so they stay sharp at any UI scale.

### 📱 Mobile first, desktop ready

48 dp touch targets behind smaller visuals, safe-area insets, virtual-keyboard avoidance,
portrait/landscape layouts, Android Back handling, focus rings only for keyboard users,
`accessibility_name` on every interactive control, and RTL via
`LAYOUT_DIRECTION_APPLICATION_LOCALE`. Ships with strings in 21 languages.

### 🛠️ Requirements

Godot **4.6 or newer** — gohud uses `DPITexture`, `FoldableContainer`, the accessibility
properties and `mouse_behavior_recursive`. Developed and verified on **4.7.2**.

### 📦 What's included

Pure GDScript (no GDExtension, no engine module) · 32 scripts · six presets · 100 icons ·
Cinzel heading font · strings in 21 languages · gallery and medieval example scenes ·
438 headless tests you can run yourself with `addons/gohud/tools/run_tests.sh`.

### 📜 License

MIT, icons included. Use it in commercial games, modify it, redistribute it. The bundled Cinzel
heading font is under the SIL Open Font License 1.1.
