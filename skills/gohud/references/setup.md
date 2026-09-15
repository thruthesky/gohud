# Setup — install, plugin, GoConfig, boot order, verification

## Contents

1. [Requirements and install](#1-requirements-and-install)
2. [The optional editor plugin](#2-the-optional-editor-plugin)
3. [GoConfig — every setting](#3-goconfig--every-setting)
4. [Boot order and the root screen](#4-boot-order-and-the-root-screen)
5. [Project settings that matter](#5-project-settings-that-matter)
6. [Verify without opening a window](#6-verify-without-opening-a-window)

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
bash addons/gohud/tools/run_tests.sh                                  # gohud's own 438 checks (git checkout only)
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
