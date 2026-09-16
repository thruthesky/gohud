# Setup — install, plugin, GoConfig, boot order, verification

## Contents

1. [Requirements and install](#1-requirements-and-install)
2. [The optional editor plugin](#2-the-optional-editor-plugin)
3. [GoConfig — every setting](#3-goconfig--every-setting)
4. [Boot order and the root screen](#4-boot-order-and-the-root-screen)
5. [Project settings that matter](#5-project-settings-that-matter)
6. [Verify without opening a window](#6-verify-without-opening-a-window)
7. [Updating gohud and this skill](#7-updating-gohud-and-this-skill)

## 1. Requirements and install

- **Godot 4.6 or newer** (`GoUi.MIN_ENGINE = [4, 6]`). gohud uses `DPITexture`, `FoldableContainer`,
  `accessibility_name` and `mouse_behavior_recursive`; older engines fail **while parsing**, not at run time.
  Verified on 4.7.2. Check with `godot --version`.
- The add-on must live exactly at `res://addons/gohud/` — every internal path is `res://addons/gohud/...`.

| Way | Command |
|---|---|
| Release ZIP / Asset Store | Extract into the project root so `addons/gohud/plugin.cfg` exists. The ZIP's top folder is `addons/`. |
| Git submodule (develop gohud with the game) | `git submodule add https://github.com/thruthesky/gohud.git addons/gohud && git submodule update --init` · pin: `git -C addons/gohud checkout v1.0.3` |
| Plain copy (no git history) | `git clone --depth 1 https://github.com/thruthesky/gohud.git /tmp/gohud && mkdir -p addons && cp -R /tmp/gohud addons/gohud && rm -rf addons/gohud/.git` |

After installing, import once so `class_name` globals register: `godot --headless --path . --import`.
Until that runs, scripts that mention `GoUi` fail with "Identifier not declared".

When an AI agent installs it, check first: `test -f addons/gohud/plugin.cfg` (already installed?), and
`git -C . rev-parse` (is the project a git repo? prefer submodule only if the user wants it).

## 2. The optional editor plugin

Enable **Project → Project Settings → Plugins → gohud** (or add `res://addons/gohud/plugin.cfg` to
`[editor_plugins] enabled`). It does three things, all optional:

1. Adds project settings `gohud/config/resource` (path to a `GoConfig` .tres) and `gohud/theme/preset`
   (preset id dropdown, includes presets found in `themes/presets/`).
2. Registers the **`GoRuntime`** autoload (`res://addons/gohud/core/go_runtime.gd`, name must be exactly
   `GoRuntime`): signals `breakpoint_changed(bp)`, `viewport_resized(size)`, `keyboard_changed(height_px)`;
   methods `current_bp()`, `is_mobile()`, `short_dp()`, `form_max_width()`, `keyboard_height()`; shrinks body
   text one step on phones; applies dp scaling only when `GoConfig.scale_enabled`.
3. Adds the 21 built-in `.translation` files to `internationalization/locale/translations`.

Without it every widget still works: surfaces and forms poll the keyboard themselves, theme font sizes are
used unchanged. `GoUi.runtime()` returns the autoload or `null`.

## 3. GoConfig — every setting

`GoConfig` is a `Resource`. Empty or default fields keep gohud's behaviour, so fill only what you change.
Register it **before building UI**: `GoUi.config = preload("res://ui/gohud_config.tres")`, or the project
setting above, or just mutate `GoUi.config` (a default instance is created on first access).

```gdscript
var cfg := GoConfig.new()
cfg.preset = GoThemePresets.SCIFI_DARK
cfg.color_overrides = {GoTheme.ACCENT: Color("#ff7a00")}
cfg.metric_overrides = {GoTheme.RADIUS: 4}
cfg.dismiss_on_scrim = true
GoUi.config = cfg                       # setter re-lays out open widgets
# Later, after changing a plain field in code:
GoUi.config.surface_max_width = 560
GoUi.refresh()                          # plain fields do not emit — refresh() re-lays out live widgets
```

| Group | Field (default) | Meaning |
|---|---|---|
| Appearance | `preset` (`&""`) | Preset id; fills only the empty `theme`/`skin`/`icons` below |
| | `theme` (null) · `skin` (null) · `icons` (null) | Explicit overrides — win over the preset |
| | `token_fallback` (true) | Missing `GoHud` tokens come from the default theme |
| | `color_overrides` `Dictionary[StringName, Color]` · `metric_overrides` `Dictionary[StringName, int]` | Per-token overrides |
| | `base_font_size` (0) | Body text size in dp; 0 = theme value |
| | `shrink_type_on_mobile` (true) | One step smaller text on phones (needs `GoRuntime`); touch sizes unchanged |
| Responsive | `scale_enabled` (false) | 1 unit = 1 dp via `content_scale_factor` — affects the whole project, opt in |
| | `mobile_max_dp` (576) · `tablet_max_dp` (991) | Breakpoints by the screen's short side |
| | `read_gain_mobile` (1.10) · `read_gain_tablet` (1.05) · `read_gain_desktop` (1.0) · `desktop_ui_gain` (1.0) | Scale gains when `scale_enabled` |
| | `form_max_width_mobile` (0) · `_tablet` (440) · `_desktop` (480) | `GoForm` content width cap; 0 = none |
| | `respect_safe_area` (true) | Avoid notches on Android/iOS |
| Surface | `surface_max_width` (480) · `surface_max_height` (700) | Card caps in dp |
| | `surface_height_ratio` (0.68) · `surface_max_height_ratio` (0.72) | Share of usable height; the cap keeps windows reading as floating |
| | `surface_width_ratio_portrait` (0.94) · `surface_width_ratio_landscape` (0.72) | Share of width |
| | `dismiss_on_scrim` (false) · `surface_fade_in` (false) · `fade_seconds` (0.14) | Defaults for new surfaces |
| | `close_button_visual` (36) · `suppress_pointer_focus_ring` (true) · `close_on_back` (true) | Header close button, focus ring policy, Escape/Back |
| Feedback | `haptics_enabled` (true) · `haptic_tap_ms` (10) · `haptic_light_ms` (20) · `haptic_medium_ms` (40) + `_amplitude`s | Vibration on handhelds only |
| | `sound_cues` | `opened→ui_open`, `closed→ui_close`, `tapped→ui_click`, `confirmed→ui_confirm`, `canceled→ui_cancel`, `failed→ui_error`, `fanfare→ui_fanfare` |
| Localization | `text_keys` · `text_overrides` · `number_formatter` (Callable) · `load_builtin_translations` (true) | See platform.md §2 |
| Accessibility | `min_touch_size` (48) · `reduce_motion` (false) · `autowrap_text` (true) | Touch floor, fades/pulses off, label wrapping |

`cfg.copy()` deep-copies the dictionaries — use it instead of `duplicate()` for a per-screen variant.

## 4. Boot order and the root screen

1. **Choose the look first.** `GoUi.use_preset(id)` clears explicit `config.theme/skin/icons`, then sets the
   preset. Widgets read the theme when they are built, so already-built nodes keep their old `theme`.
   Switching live = rebuild the screen (free children, build again) — the gallery and medieval examples do this.
2. Give the root Control the theme and paint the background:

```gdscript
extends Control

func _ready() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)     # optional; default_dark when skipped
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()                             # children inherit it
	RenderingServer.set_default_clear_color(GoUi.color(GoTheme.BACKGROUND))
```

3. Put one `GoDialogs` where every screen can reach it. Either `add_child(GoDialogs.new())` per screen, or
   register an autoload of your own that extends it — gohud never auto-registers it:

```gdscript
# res://ui/dialogs.gd  → Project Settings › Autoload › name "Dialogs"
extends GoDialogs
# anywhere: if await Dialogs.confirm("Quit", "Leave the game?"): get_tree().quit()
```

4. Layering: `GoDialogs.layer_index` = 100, `GoSheet` defaults its `CanvasLayer.layer` to 10, put the HUD on
   a lower `CanvasLayer` (e.g. 5). A `GoSurface` you create yourself goes inside your own `CanvasLayer`.
5. While any surface is open, gameplay input should pause: `if GoSurface.is_any_open(): return`.

## 5. Project settings that matter

| Setting | Recommended | Why |
|---|---|---|
| `display/window/stretch/mode` | `canvas_items` | UI scales with the window; gohud measures in UI units |
| `display/window/stretch/aspect` | `expand` | Phones of every ratio get the full screen; gohud handles the safe area |
| `rendering/renderer/rendering_method` | any | Verified on Compatibility; widgets are plain 2D |
| `[gohud] theme/preset` | e.g. `"scifi_dark"` | Choose the look without code (read when `config.preset` is empty) |

## 6. Verify without opening a window

```bash
godot --headless --path . --import                                   # registers class_name globals
godot --headless --path . --quit-after 120 res://ui/main_menu.tscn 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: Failed" && echo FAIL || echo OK
python3 <skill>/scripts/gohud_preview.py res://ui/main_menu.tscn --check   # same, with the error scan built in
bash addons/gohud/tools/run_tests.sh                                  # gohud's own 693 checks (git checkout only)
```

Headless runs cannot take screenshots (the viewport image is null). To *see* a screen, open a window with
`gohud_preview.py <scene>` — only when the user asked for a visual preview.

gohud's own tooling (present in a git checkout, not in the release ZIP):

| Command | Does |
|---|---|
| `bash addons/gohud/tools/check_all.sh` | Every check: tests at 4 screen sizes, contrast, site, generated themes, scaffolding, packaging |
| `python3 addons/gohud/tools/check_contrast.py` | WCAG contrast of every theme |
| `python3 addons/gohud/tools/new_theme.py <id> --from <parent>` · `make_theme.py <id>` | Scaffold and build a theme (theming.md §4) |
| `bash addons/gohud/tools/package.sh` | Release ZIP, bumps patch version (`--increase-minor-version`) |
| `bash addons/gohud/examples/demo/run.sh` | The demo app (`--setup`, `--shot`, `--record`, `-- --explore=<chapter>`) |

## 7. Updating gohud and this skill

`/gohud update` walks this. There are **two separate things** and updating one does not update the other:

| What | Lives at | Why it matters |
|---|---|---|
| **The add-on** | `<project>/addons/gohud/` | The classes your game calls |
| **The skill** | the plugin cache, or `~/.claude/skills/gohud/` | What the agent knows about those classes |

🛑 **If only the skill updates, the agent recommends APIs the project does not have** — and if only the
add-on updates, the agent does not know the new widgets exist. Update both, then verify the versions match.

### 7.1 Which install is this?

```bash
test -f addons/gohud/plugin.cfg && grep -m1 '^version=' addons/gohud/plugin.cfg   # installed version
git -C addons/gohud rev-parse --short HEAD 2>/dev/null && echo "→ git checkout"   # or: not a git repo
git config --file .gitmodules --get-regexp 'addons/gohud' 2>/dev/null             # submodule?
```

### 7.2 Update the add-on

| Install kind | Command | Note |
|---|---|---|
| **Submodule** | `git -C addons/gohud fetch origin && git -C addons/gohud checkout main && git -C addons/gohud pull` | Then commit the pointer in the parent repo: `git add addons/gohud` |
| **Pinned submodule** | `git -C addons/gohud fetch --tags && git -C addons/gohud checkout v<version>` | Pin on purpose; unpinned `main` can carry breaking changes |
| **Plain clone / copy** | `git clone --depth 1 https://github.com/thruthesky/gohud.git /tmp/gohud-new && rm -rf addons/gohud && mv /tmp/gohud-new addons/gohud && rm -rf addons/gohud/.git` | 🛑 **Back up first** if you edited files inside `addons/gohud/` — this replaces everything |
| **Release ZIP / Asset Store** | Download the newest ZIP and extract over the project root (its top folder is `addons/`) | The store's "update" button does the same |

🛑 **Never hand-edit files inside `addons/gohud/`** — an update overwrites them. Everything you would want
to change has a supported seam: `GoConfig`, `color_overrides`, a project-local `GoThemePreset`, a `GoSkin`
subclass, or the subclass hooks in surfaces.md §6. If you already edited the add-on, `git -C addons/gohud
diff` before updating and move those changes into your own project.

After updating, **always**:

```bash
godot --headless --path . --import       # new class_name globals register; without this they are "not declared"
bash addons/gohud/tools/check_all.sh     # git checkout only — confirms the new version is healthy here
```

### 7.3 Update the skill

| Install kind | Command |
|---|---|
| **Claude Code plugin** (`/plugin`) | `/plugin update gohud` — or Claude Code updates it on its own; `/plugin` lists what is installed |
| **Personal skill** (`~/.claude/skills/gohud/`) | `rm -rf ~/.claude/skills/gohud && cp -R addons/gohud/skills/gohud ~/.claude/skills/gohud` |
| **Project skill** (`.claude/skills/gohud/`) | `rm -rf .claude/skills/gohud && cp -R addons/gohud/skills/gohud .claude/skills/gohud` |

The skill's source of truth is `addons/gohud/skills/gohud/` in the repository — the plugin and any copies
are built from it. Editing a copy is lost on the next update; change the repository copy.

### 7.4 Verify the two agree

```bash
grep -m1 '^version=' addons/gohud/plugin.cfg                                    # add-on
grep -m1 'Version described' <skill>/references/features.md                     # skill
```

If the skill names a class the add-on does not have, the skill is ahead:

```bash
godot --headless --path . -s res://addons/gohud/tests/gohud_test.gd | tail -1   # should end "N/N passed"
```

### 7.5 What changed

`addons/gohud/CHANGELOG.md` is the record — read the entries above your previous version. Breaking changes
are called out under **Changed**; everything else is additive. After a major or minor bump, re-run your own
screens headless (§6) before shipping.
