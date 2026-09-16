---
name: gohud
description: >-
  Build Godot 4.6+ game UI with gohud (res://addons/gohud): main menus, pause menus, settings screens,
  inventories, HUDs with HP/MP bars, quick slots and a virtual joystick, dialogs, bottom sheets, forms,
  snackbars, prompt cards, coach-mark tours, and looks from presets (default, sci-fi, medieval), JSON
  themes, skins and icon sets — touch-safe, safe-area aware, RTL and translation ready. Use whenever
  someone writes GDScript UI, HUD, menu or GUI code in a Godot project, mentions gohud or any Go* class
  (GoUi, GoStyle, GoSurface, GoSheet, GoDialogs, GoForm, GoHudAnchor, GoBar, GoSlot, GoJoystick, GoNotice,
  GoPromptCard, GoCoachMark, GoTheme, GoSkin, GoIconSet, GoConfig), wants to install gohud, or runs
  /gohud preview, /gohud features (plugin form: /gohud:preview, /gohud:features, /gohud:gohud).
license: MIT
metadata:
  author: JaeHo Song
  homepage: https://thruthesky.github.io/gohud/
  repository: https://github.com/thruthesky/gohud
---

# gohud — game UI for Godot 4.6+

gohud is a pure-GDScript HUD & UI kit. Every class is global once the folder sits at `res://addons/gohud/`;
widgets are made with `.new()` + `add_child()` and styled by one theme, one skin and one icon set.
This skill carries the whole API (`references/`), runnable screen templates (`assets/templates/`) and a
preview launcher (`scripts/gohud_preview.py`).

Arguments given: `$ARGUMENTS`

## 1. Route the request

| First word of the arguments | Do |
|---|---|
| `preview` | §6 — launch the preview with the remaining arguments |
| `features` | Read `references/features.md` and present it grouped (one line of code per feature). If an area follows (`features theming`), also read that area's reference and go deeper |
| anything else / empty | §2 — build or change UI with gohud |

Reply in the language the user writes in; keep code identifiers as they are.

## 2. Workflow for building UI

1. **Check the project.** `test -f project.godot`, `test -f addons/gohud/plugin.cfg`, `godot --version` (needs 4.6+).
   Note the gohud version (`version=` in `plugin.cfg`) — rules 4, 5 and 7 differ for 1.0.3 and older.
   Missing add-on → install it (`references/setup.md` §1), then `godot --headless --path . --import`.
2. **Pick the look first.** `GoUi.use_preset(GoThemePresets.SCIFI_DARK)` (or the project setting) before any widget
   is built. Nodes keep the theme they were built with; switching later means rebuilding the screen.
3. **Choose the widget for the job** — table in `references/surfaces.md` §7: blocking question → `GoDialogs`,
   list over the game → `GoSheet`, window → `GoSurface`, full-screen menu/login/settings → root Control + `GoForm`,
   info that must not block → `GoNotice`, optional question → `GoPromptCard`, HUD pieces → `GoHudAnchor`.
4. **Start from a template** when one fits (§5): copy it into the project (e.g. `res://ui/`), rename, adjust, wire
   its signals. Otherwise compose with `GoStyle` factories (`references/style.md`).
5. **Follow the rules in §3.** Look up exact signatures in the references before using a member you are not sure
   of — do not guess APIs.
6. **Verify without a window:** `python3 ${CLAUDE_SKILL_DIR}/scripts/gohud_preview.py res://ui/my_screen.tscn --check`
   (or `godot --headless --path . --quit-after 120 res://ui/my_screen.tscn` and scan for `SCRIPT ERROR`,
   `Parse Error`, `ERROR: Failed`). Open a visible window only when the user asks to see it (§6).

## 3. Rules that prevent the real bugs

1. **Sizes and colours come from tokens**, never literals: `GoUi.metric(GoTheme.GAP)`, `GoUi.color(GoTheme.MUTED)`,
   `GoStyle.*` factories. Literals break when the preset, breakpoint or touch size changes.
2. **Text vs keys.** `GoStyle.label()/button()` show text as written; `label_key()/button_key()` hold translation
   keys. `list_button()`, `foldable()`, `section()`, `toggle()`, `checkbox()` translate by default — pass
   `translate = false` for literal strings.
3. **Surfaces go in a `CanvasLayer`, and the owner closes them.** `GoSurface` only emits `close_requested`.
   Layers: HUD 5 · `GoSheet` 10 · your popups 50 · `GoDialogs` 100.
4. **Per-page sheet buttons go through `sheet.add_footer(button)`** — the next `open()` removes them. `open()` only
   hides `footer()`, so children added with `footer().add_child()` stay (right for a sheet-wide snackbar, wrong for a
   Close button re-added on every open). gohud 1.0.3 and older have no `add_footer()`: remove your footer children first.
5. **Assemble `GoForm → GoScroll → column` before the form enters the tree.** `_ready` runs inside `add_child`; a
   scroll added later is never found (no keyboard follow), and `%BackButton` (Android Back routing) is looked up once
   there. In code: name the button `BackButton`, add it, set `back.owner = form` and `back.unique_name_in_owner = true`,
   then `add_child(form)`. gohud 1.0.3 and older clear that owner when the scroll moves — there, own the whole branch
   from a holder (`owner = holder` on every descendant; the templates do this, and it works on every version).
6. **HUD root: `mouse_filter = MOUSE_FILTER_IGNORE`.** Transient anchors (toasts, prompts, joystick) use
   `reserve_space = false`; toasts at `TOP_CENTER` use `avoid_peers = true`. Put a `GoStyle.floating()` panel
   behind HUD text that floats over content.
7. **`await` dialogs.** `{placeholders}` in the title and body are filled only from `args` (gohud 1.0.3 and older
   format only the body — build the title string yourself there). Irreversible confirms use `destructive = true`
   (last argument).
8. **Bars use fill tokens** (`GoTheme.DANGER_FILL`, `INFO_FILL`, `WARNING_FILL`, `SUCCESS_FILL`); text colours
   look dull as fills on light themes.
9. **Touch:** icon-only buttons get a tooltip (`GoStyle.icon_button(icon, action, -1, &"Menu")`) — it is also the
   accessible name. Side-by-side `GoIconButton`s / `GoSlot`s need `touch_peers`.
10. **Config:** after changing a plain `GoConfig` field in code call `GoUi.refresh()`; `theme`/`icons` refresh
    themselves. `use_preset()` clears explicit `theme`/`skin`/`icons` — set overrides after it.
11. **Gameplay input pauses while a window is open:** `if GoSurface.is_any_open(): return`.
12. **Never hand-edit gohud's generated themes**; recolour through `color_overrides`, a Theme copy in your project,
    a project-local `GoThemePreset`, or the JSON theme tools (`references/theming.md`).

More traps with their causes: `references/pitfalls.md`.

## 4. Minimal screen

```gdscript
extends Control

var dialogs: GoDialogs

func _ready() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	RenderingServer.set_default_clear_color(GoUi.color(GoTheme.BACKGROUND))
	var form := GoForm.new()
	var scroll := GoScroll.new()
	var column := GoStyle.column()
	form.add_child(scroll)
	scroll.add_child(column)
	column.add_child(GoStyle.label("Hello gohud", GoTheme.ROLE_TITLE))
	column.add_child(GoStyle.button("Open dialog", _on_open, GoStyle.Tone.PRIMARY))
	add_child(form)
	dialogs = GoDialogs.new()
	add_child(dialogs)

func _on_open() -> void:
	if await dialogs.confirm("Delete save", "This cannot be undone.", "Delete", "", "", {}, true):
		print("deleted")
```

## 5. Templates — `assets/templates/`

Each is a complete, headless-tested script with no scene file. Copy, then connect signals.

| File | Extends | Builds | Public API |
|---|---|---|---|
| `main_menu.gd` | Control | Title, Continue / New game / Settings / Quit rows, confirm dialogs | signals `continue_requested` `new_game_requested` `settings_requested` `quit_confirmed` · `build()` |
| `game_hud.gd` | CanvasLayer (5) | HP/MP/XP panel, menu button, 4 quick slots, FOLLOW joystick, toast, prompt card | signals `menu_requested` `slot_used(index)` `move_input(vector)` · `set_health/set_mana/set_experience(v, max)` · `toast(msg, tone)` · `ask(title, subtitle, accept_text, accept, decline_text, decline)` |
| `pause_menu.gd` | CanvasLayer (50) | Centred GoSurface, pauses the tree, Escape opens/closes, quit confirm | signals `resumed` `settings_requested` `quit_to_title_requested` · `open()` `resume()` `toggle()` `is_open()` |
| `inventory_sheet.gd` | Node | GoSheet with search + category filter, detail page with Back, Use / Drop | signals `item_used(item)` `item_dropped(item)` · `items` · `open()` `show_list()` `show_item(item)` |
| `settings_menu.gd` | Control | GoForm, foldable Display/Audio/Controls/Language sections, draft + Save/Reset, discard check | signals `closed(saved)` `settings_changed(values)` · `settings` · `save()` `request_back()` `reset_to_defaults()` |

Wiring them together and more screens (login, shop, quest log, character sheet, dropdown menus, tutorial tour):
`references/recipes.md`.

## 6. Preview — `/gohud preview` (plugin: `/gohud:preview`)

Run from the user's project folder so their `addons/gohud` is used (otherwise the bundled copy or a clone):

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/gohud_preview.py <arguments>      # Windows: python
```

If `${CLAUDE_SKILL_DIR}` is not expanded, use the first existing path of
`${CLAUDE_PLUGIN_ROOT}/skills/gohud/scripts/gohud_preview.py`, `~/.claude/skills/gohud/scripts/gohud_preview.py`,
`.claude/skills/gohud/scripts/gohud_preview.py`.

| Arguments | Opens |
|---|---|
| *(none)* / `gallery` · `--preset scifi_dark` · `--phone` · `--size 1920x1080` | Every widget, preset picker, icon set |
| `medieval` | Character sheet, satchel, quest journal |
| `demo` · `demo --explore hud` | 15-chapter guided tour / one chapter (`list` shows keys) |
| `res://ui/main_menu.tscn` | A scene of the user's project, inside that project |
| `list` · `--check` · `--dry-run` · `--godot PATH` | Keys · headless smoke test · print command · Godot binary |

gohud's examples run in a sandbox project under the user cache, so the user's project is not modified. The script
detaches and prints the process id and log path. Exit 2 = Godot 4.6+ not found or bad arguments; exit 1 = import
or launch error (it prints the error lines). A visible window is what `/gohud preview` is for; for your own checks
use `--check`.

## 7. References — read the one you need

| File | Read when |
|---|---|
| `references/features.md` | `/gohud features`, or "what can gohud do" — catalogue of every feature with one-line code |
| `references/setup.md` | Installing, enabling the plugin, every `GoConfig` field and default, boot order, layers, project settings, headless verification, gohud's tool commands |
| `references/surfaces.md` | `GoSurface` (placements, anchored menus, sub-pages), `GoSheet`, `GoDialogs` (layouts, destructive, args), `GoForm`, `GoScroll`, subclass hooks, which widget to use |
| `references/hud.md` | `GoHudAnchor` spots and avoidance, `GoBar`, `GoSlot`, `GoJoystick`, `GoIconButton`, `GoNotice`, `GoPromptCard`, `GoCoachMark`, composing a HUD |
| `references/style.md` | Every `GoStyle` factory signature: structure, text, buttons and tones, inputs, select/dropdown/segmented/tabs, cards, chips, tables, styleboxes, helpers |
| `references/theming.md` | Presets and resolution order, all tokens, overrides, JSON themes (`new_theme.py`/`make_theme.py`), skins and dials, custom StyleBoxes, project-local presets, contrast |
| `references/platform.md` | The 84 icon names and custom icon sets/fonts, localization and RTL, sound and haptics, accessibility, safe area, breakpoints, dp scale, Android Back |
| `references/recipes.md` | Full screens and wiring: game scene with HUD + pause + inventory, login, shop, quest log, character sheet, context menu, tutorial, theme switcher |
| `references/pitfalls.md` | Symptoms → cause → fix for layout, text, input, theme and lifecycle traps |

Web (same content, with screenshots): overview https://thruthesky.github.io/gohud/ ·
install https://thruthesky.github.io/gohud/install.html · AI skill https://thruthesky.github.io/gohud/ai.html ·
widgets https://thruthesky.github.io/gohud/widgets.html · theming https://thruthesky.github.io/gohud/theming.html
