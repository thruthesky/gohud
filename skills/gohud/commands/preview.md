---
description: Open a gohud preview window — the widget gallery, the medieval example, the demo app (home screen plus the 15-chapter tour), or one of your own scenes
argument-hint: "[gallery|medieval|demo|list|res://scene.tscn] [--preset scifi_dark] [--phone] [--explore hud] [--check]"
allowed-tools: Bash(python3:*), Bash(python:*), Read
---

Open a gohud preview. Arguments: `$ARGUMENTS` (empty means `gallery`).

## 1. Find the bundled script

Use the first path that exists:

```
${CLAUDE_PLUGIN_ROOT}/skills/gohud/scripts/gohud_preview.py
~/.claude/skills/gohud/scripts/gohud_preview.py
.claude/skills/gohud/scripts/gohud_preview.py
.agents/skills/gohud/scripts/gohud_preview.py
```

## 2. Run it from the user's project folder

```bash
python3 <script> $ARGUMENTS        # Windows: python <script> $ARGUMENTS
```

Running from the project folder lets the script use that project's `addons/gohud` (the user's version). Without
one it uses the gohud copy bundled with the plugin, or clones https://github.com/thruthesky/gohud.

| Arguments | Opens |
|---|---|
| *(none)* / `gallery` | Every widget, a preset picker and the full icon set |
| `gallery --preset medieval_dark` · `--phone` · `--size 1920x1080` | Same, with a look / a 390×844 phone window / a size |
| `medieval` | Character sheet, satchel and quest journal in the medieval presets |
| `demo` · `demo --explore surfaces` | The demo app: a home screen opening the gallery, the guided tour, the showcase and the medieval look, plus live widgets and a card per class; `--explore` jumps to one tour chapter |
| `res://ui/main_menu.tscn` | A scene of the user's project, run inside that project |
| `list` | Targets, preset ids and demo chapter keys |
| `... --check` | Headless smoke test, no window — use this when verifying your own work |

The user asked for this window, so opening it is expected. The script returns right away with the process id and
a log path; the window stays open until the user closes it. For AI self-verification without a visible window,
use `--check` instead.

## 3. Report

- Say what opened (target, preset, size) and where the log is.
- Exit code 2 = Godot 4.6+ not found or bad arguments: tell the user to install Godot 4.6+ or pass
  `--godot /path/to/godot` (or set `GODOT_BIN`).
- Exit code 1 = import or launch failed: show the error lines the script printed.
- Reply in the language the user writes in.
