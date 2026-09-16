# Pitfalls — symptom → cause → fix

Each row was met on real screens while building gohud or this skill (dates and measurements are in the gohud
source comments). Check here first when a gohud screen looks or behaves wrong.

## Contents

1. [Install and engine](#1-install-and-engine)
2. [Layout and sizing](#2-layout-and-sizing)
3. [Text and translation](#3-text-and-translation)
4. [Input, focus and Back](#4-input-focus-and-back)
5. [Lifecycle and configuration](#5-lifecycle-and-configuration)
6. [Themes and shapes](#6-themes-and-shapes)
7. [Verification](#7-verification)

## 1. Install and engine

| Symptom | Cause | Fix |
|---|---|---|
| `Identifier "GoUi" not declared` | Classes not registered yet, or the folder is not `res://addons/gohud/` | Put it exactly there, run `godot --headless --path . --import` |
| Parse errors inside gohud (`FoldableContainer`, `DPITexture` unknown) | Godot older than 4.6 | Use Godot 4.6+ (`GoUi.MIN_ENGINE`) |
| "Detected another project.godot" in the editor | A restored `examples/demo/project.godot` inside your project | Run the demo through `gohud_preview.py demo` (sandbox) or keep it as `project.godot.demo` |
| A new JSON theme will not load | Its generated SVGs are not imported | `godot --headless --path . --import` after `make_theme.py` |

## 2. Layout and sizing

| Symptom | Cause | Fix |
|---|---|---|
| Button text split one letter per line (`Pri m ary`) | Wrapping on + a container that sizes cells by minimum width | Make buttons with `GoStyle.button*` and flows with `wrap_row` (natural width); after changing text call `GoStyle.fit_words(button)` |
| Grid cards collapse to ~25 px with vertical letters | `GridContainer` children default to `SIZE_FILL` | `GoStyle.responsive_grid(min_cell)` (forces expand, recomputes columns) |
| Screen clipped left and right on a phone | One long unwrapped label or a fixed `custom_minimum_size.x` | Put screens in `GoForm` (wraps every descendant label, caps width per breakpoint); never hard-code widths |
| Scrolling text slides under HUD text | Content and floating HUD share the screen | `form.avoid_hud = true` + a `GoStyle.floating(GoTheme.BOX_HUD)` panel behind HUD pieces |
| A toast covers the health bar | Nine spots do not prevent collisions | Toast anchor: `avoid_peers = true`, `reserve_space = false` |
| A whole row of content disappears near a hidden joystick | Its anchor still reserves space | `reserve_space = false` on anchors that appear only sometimes |
| `GoBar`s in a column overlap / a bar has no width | `Control` gives no width by itself | `bar.custom_minimum_size.x = 180` or an expanding parent |
| Sheet list's last row cut off behind the footer | Confirm/Close put in `body` | Sticky actions go in `footer()` (and `toolbar()` for search) with `.visible = true` |
| Custom StyleBox content touches its border | `_get_style_margin()` is not called for GDScript StyleBoxes | Set `content_margin_*` on the StyleBox |
| Card shape turns rounded under sci-fi / medieval | `GoStyle.box()` always returns `StyleBoxFlat` | Use `GoStyle.surface()` to keep the preset's shape |
| A `HSeparator` looks thick | Engine separator carries theme margins | `GoStyle.divider()` |

## 3. Text and translation

| Symptom | Cause | Fix |
|---|---|---|
| `gohud_close`, `gohud_confirm` visible | Built-in translations not imported / not loaded | Import the project; keep `load_builtin_translations` on, or set `GoConfig.text_overrides` |
| `{name}` visible in a dialog or notice | `tr()` does not fill placeholders | Pass `args` (`confirm(..., args)`, `show_key(key, args)`) |
| `{name}` visible in a dialog **title** | gohud 1.0.3 and older format only the body | Newer gohud fills the title from the same `args`; on 1.0.3 and older build it yourself: `"Drop %s?" % item.name` |
| My literal row text changes into another string | `list_button`/`foldable`/`section`/`toggle`/`checkbox` translate by default | Pass `translate = false` for literal text |
| Empty boxes instead of Korean, Japanese, Thai, Arabic… | The theme font lacks the glyphs (no error is raised) | Add a font with those scripts to your Theme |
| `Done` splits into `Don` / `e` after changing a label | Wrap rule computed for the old text | `GoStyle.fit_words(button)` after `button.text = …` |

## 4. Input, focus and Back

| Symptom | Cause | Fix |
|---|---|---|
| The game ignores taps where the HUD is empty | A full-rect `Control` defaults to `MOUSE_FILTER_STOP` | HUD root `mouse_filter = MOUSE_FILTER_IGNORE` |
| A button next to an icon button stops responding | The icon button's touch area grows to 48 dp over it | Set `touch_peers` on side-by-side `GoIconButton`s / `GoSlot`s |
| Dragging a list that starts on a button does not scroll | Button uses `MOUSE_FILTER_STOP` | Build rows with `GoStyle` (PASS) inside `GoScroll` (prepares children) |
| Joystick eats mouse clicks on desktop | Its hit area is its whole rect | Show touch controls on handhelds only (`GoUi.is_handheld_platform()`) |
| Gameplay reacts while a menu is open | Game input does not know about windows | `if GoSurface.is_any_open(): return` in gameplay input |
| Android Back quits with a window open, or never quits again | `quit_on_go_back` toggled without pairing | Use `GoBackPolicy.acquire/release` in pairs (release in `_exit_tree` too) |
| `GoForm` ignores Android Back | When the form entered the tree no node named `BackButton` with `unique_name_in_owner` was owned by the form or by the form's owner; on gohud 1.0.3 and older also `owner = form` or a holder owning only the form and the button (cleared when the scroll moves into its edge frame) | Set `back.owner = form` + `unique_name_in_owner` before `add_child(form)`; on 1.0.3 and older own the whole branch from a holder — surfaces.md §4 |
| Pause menu freezes when the tree is paused | Its layer inherits `PROCESS_MODE_PAUSABLE` | `process_mode = Node.PROCESS_MODE_ALWAYS` on the menu's layer |

## 5. Lifecycle and configuration

| Symptom | Cause | Fix |
|---|---|---|
| `GoForm` does not scroll to the focused field when the keyboard opens | The `GoScroll` was added after the form entered the tree | Build form → scroll → content, then `add_child` |
| Sheet footer buttons pile up on every open | `GoSheet.open()` hides the footer but keeps children added with `footer().add_child()` | `sheet.add_footer(button)` — the next `open()` removes it; on gohud 1.0.3 and older remove them yourself (`remove_child` + `queue_free`) |
| Child counts / layout lag one frame after clearing | `queue_free()` alone keeps the node until frame end | `remove_child(child)` then `child.queue_free()` |
| Changing `GoConfig.surface_max_width` in code does nothing | Plain fields do not emit a change | `GoUi.refresh()` after changing them |
| Switching presets leaves old colours on screen | Built nodes keep their `theme` | Rebuild the screen after `GoUi.use_preset()` |
| My custom icon set vanished after switching presets | `use_preset()` clears explicit `theme`/`skin`/`icons` | Assign overrides after `use_preset()` |
| A second `confirm()` returns `false` at once | One dialog at a time per `GoDialogs` | `await` the first before asking again |
| `GoSurface` never goes away | It only emits `close_requested` | The owner hides or frees it (`close_requested.connect(layer.queue_free)`) |

## 6. Themes and shapes

| Symptom | Cause | Fix |
|---|---|---|
| Magenta colour on a widget | A token missing from your Theme with `token_fallback` off | Turn `token_fallback` on or add the token under the `GoHud` type |
| Experience bar looks brown on a light theme | A text colour used as a fill | `GoTheme.WARNING_FILL` (and `*_FILL` tokens) for bars |
| Accent override changed labels but not button faces | Button StyleBoxes are baked into the Theme `.tres` | Edit a copy of the Theme or build a JSON theme |
| Same-hue label on a same-hue tint is unreadable | No lightness contrast | `GoUi.skin().readable_on(ink, background)`; run `check_contrast.py` for themes |
| A panel vanished after setting opacity | A **percent** was written where a ratio is expected — `80` clamps to 1.0, `8` to 1.0, but an integer `0` really is invisible | Every `alpha` field and argument is a ratio `0.0–1.0`. Percentages live only in the theme's constants and `metric_overrides`. theming.md §4 |
| A panel keeps getting fainter each redraw | `GoSkin.fade_box()` **multiplies**, so applying it twice to the same face compounds | Apply opacity in one place only — pass `alpha` down to `surface_box()` instead of fading the result. `GoStyle.fade_panel()` is already idempotent |
| Opacity has no effect on a sci-fi / medieval panel | A `GoSkin` subclass overrode `surface_box`/`floating_box`/`alert_box` without the `alpha` parameter | Add it and forward it to `super(...)` — a mismatched signature is a parse error, a dropped argument is silent |
| Panels stayed opaque after changing the setting from code | Plain `GoConfig` fields emit no signal | `GoUi.refresh()` |
| A translucent popup menu renders black instead of see-through | The engine hosts `PopupMenu` in its own `Window`; the OS does not composite it with the game | Leave `popup_alpha` at 100, or enable `gui_embed_subwindows` |
| Buttons went translucent too | Something faded the whole node (`modulate.a`) instead of the face | Panel opacity touches `bg_color` only; never use `modulate` for it |

## 7. Verification

| Symptom | Cause | Fix |
|---|---|---|
| Godot exits with 0 but the scene never loaded | Load errors are printed, not returned | Scan output for `SCRIPT ERROR`, `Parse Error`, `ERROR: Failed`, `Cannot open file` — `gohud_preview.py … --check` does |
| Screenshot image is null | `--headless` does not render | Capture in a real or virtual display; use headless only for logic and layout numbers |
| Layout checks pass at the wrong size | The headless window is 64×64 and `root.size` does not enlarge it | Size the test viewport the way gohud's suite does (`GOHUD_VIEWPORT`, see `tests/gohud_test.gd`) or check visually with `gohud_preview.py <scene> --phone` |
| A headless run never ends with no output | A parse error stops `_initialize` from running | Put a wall-clock timeout on test runs and read the `SCRIPT ERROR` lines |
