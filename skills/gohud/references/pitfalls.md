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
| A sheet or window stays at 72% of the screen although `height_ratio = 0.9` | The per-surface `height_ratio` is clamped by `max_height_ratio`, which defaults to the global `GoConfig.surface_max_height_ratio` (0.72). A debug build warns once (gohud newer than 1.0.3); older versions cut it silently. (A centered `fit_content` card still grows to 0.94 for long content.) | `sheet.max_height_ratio = 0.9` on the one sheet that needs it (it also lets the player drag it that far), or raise `GoUi.config.surface_max_height_ratio` for every surface and call `GoUi.refresh()` |
| A wide landscape screen shows a narrow 480 dp sheet | `GoConfig.surface_max_width` caps every surface | `sheet.surface.max_width = GoUi.metric(GoTheme.TOUCH) * 15` for the one sheet that needs room (an inventory grid) |
| Icons vanish from a row of buttons | An expanding sibling took the spare width, the buttons shrank to their text and `expand_icon` squeezed the icon to 0 px | Give the sibling `SIZE_SHRINK_BEGIN` and the button row `SIZE_EXPAND_FILL` |
| Sheet list's last row cut off behind the footer | Confirm/Close put in `body` | Sticky actions go in `footer()` (and `toolbar()` for search) with `.visible = true` |
| Custom StyleBox content touches its border | `_get_style_margin()` is not called for GDScript StyleBoxes | Set `content_margin_*` on the StyleBox |
| Card shape turns rounded under sci-fi / medieval | `GoStyle.box()` always returns `StyleBoxFlat` | Use `GoStyle.surface()` to keep the preset's shape |
| A `HSeparator` looks thick | Engine separator carries theme margins | `GoStyle.divider()` |
| A badge sits in the wrong corner, or drifts when the slot moves | `Control.position` is in **parent** coordinates and ignores anchors, so setting it fights the layout | `GoBadge.attach(node, count)` — it anchors to the top-right corner through `offset_*`, so it follows the host on move and resize |
| A spinner appears outside its button, or the button jumps | The spinner was added as a child of the layout rather than put **into** the button | `GoSpinner.busy(button, true)` keeps the button's size and disables it; `false` brings the label back |
| A code input overflows the screen at 12 cells | Fixed cells on a 360 dp phone need more width than there is | The cells wrap to a second line by themselves — do not force a width on `GoCodeInput` |
| Table rows are blank, or one pixel high | A wrapping `Label` inside a cell whose width is still 0 reports a minimum height of 0 | Let `GoTable` build the cells (it sets a minimum height and gives each column its share); pass `Control` cells only when you size them yourself |
| A snackbar card is far taller than its text | Height was measured in the same frame the width was set, so the folded value stuck | `GoSnackbar` waits two frames before placing itself — if you build a card by hand, do the same before reading `size` |
| A list reads as one block — the eye cannot tell where a row ends | The space between rows equals the space inside them (a shipped quest panel used 4 / 4 / 4 dp) | Rows at least `GAP_SMALL` apart, `list_button()`'s padding inside, a row's lines `GAP_TINY` apart — `SKILL.md` rule 15. Compare in the gallery: **List rows → Readable lists** |
| The panel heading is the same size as its rows | A `GoSurface` or `GoSheet` short of height (or `compact`) drops its own title to `body` (16) and its padding to `padding_compact` | Put the heading players read first in the body as `ROLE_SUBTITLE` (22); give the surface room (`max_height_ratio`) or show fewer rows |
| A panel looks like an error screen | A warning colour or icon on most rows — a level gate drawn as a warning | Warnings only where something is wrong; a gate is `GoIconSet.LOCK` with `MUTED` text |
| The spacing you gave a column comes out as 12 | `GoStyle.form()` — run by every `GoForm` on everything added — sets each box's `separation` to `GAP` | `box.set_meta(&"go_own_spacing", true)` on the box you want kept |
| Text inside a pressable cell sits on its top border, or is drawn below the cell | A `Button` is not a container: its face's `content_margin_*` pads only its own text, and it does not grow for a child — a column anchored `FULL_RECT` inside it starts on the border and spills past the fixed size (a reward calendar in the gallery, 2026-09-23) | `GoStyle.cell_body(button)` (or `cell_inset(button, content)`) — padding, a column that keeps its spacing in a form, and a box that grows to fit. Check a screen with `GoStyle.audit_cell_layout(root)` |
| A mark meant for the middle hangs down and to the right | `set_anchors_preset(Control.PRESET_CENTER)` moves only the anchors — the offsets stay 0, so the **corner** lands on the center | `GoStyle.center_in(node)` |
| Rows shrink to their text; titles stop expanding and wrapping | They sit inside a `wrap_row()`, which forces every descendant to natural width with wrapping off | Only chips and buttons in a `wrap_row()`; lay panels out with `column()`, `row()` or a `GridContainer` |
| A number meant for a row's end sits in the middle of it | `GoStyle.label()` expands horizontally by default and splits the width with the title | `SIZE_SHRINK_END` on that label |

## 3. Text and translation

| Symptom | Cause | Fix |
|---|---|---|
| `gohud_close`, `slot_quantity`, `bar_fraction` visible on screen | The built-in translations were not imported, so the `.translation` pieces do not exist and every key falls through as itself. Common in a **copy** of the project that the editor has never opened — a CI checkout, or the rsynced copy a virtual-display screenshot runs in (2026-09-16: a medieval screenshot came back with `slot_quantity` on every slot) | `godot --headless --path . --import` in that copy; keep `load_builtin_translations` on, or set `GoConfig.text_overrides` |
| `{name}` visible in a dialog or notice | `tr()` does not fill placeholders | Pass `args` (`confirm(..., args)`, `show_key(key, args)`) |
| `{name}` visible in a dialog **title** | gohud 1.0.3 and older format only the body | Newer gohud fills the title from the same `args`; on 1.0.3 and older build it yourself: `"Drop %s?" % item.name` |
| My literal row text changes into another string | `list_button`/`foldable`/`section`/`toggle`/`checkbox` translate by default | Pass `translate = false` for literal text |
| Empty boxes instead of Korean, Japanese, Thai, Arabic… | The theme font lacks the glyphs (no error is raised) | Add a font with those scripts to your Theme |
| `Done` splits into `Don` / `e` after changing a label | Wrap rule computed for the old text | `GoStyle.fit_words(button)` after `button.text = …` |
| A translation key shows up on screen verbatim, with a symbol in front | A glyph was glued onto the key (`"! " + key`) before translating, so the table has no such key | Translate first, then join: `"! " + GoUi.text(key)`. Field errors from a server are **not** keys — `GoField.set_error(text)` leaves them alone |
| Numbers read wrong in Turkish or French screen readers | A percent sign was concatenated in code | Percentages are wording too — `GoUi.text(&"bar_percent").format({"percent": n})`, which `GoRadar` and `GoDonut` already use |

## 4. Input, focus and Back

| Symptom | Cause | Fix |
|---|---|---|
| After clicking a HUD button, Space / Enter presses **it** again instead of reaching the game (attack, jump) — a sheet flickers open and shut | A clicked `Button` keeps keyboard focus and the engine's accept action (Space / Enter) activates the focused button before `_unhandled_key_input` sees the key. `GoSlot` opts out by default (`keyboard_focus`); `GoIconButton`, `GoSlotGrid` cells and `GoStyle.button*` do not | `GoHudAnchor.keyboard_focus = false` on the corner that holds them (every control under it, later ones too — not for a corner with a text input), or `GoIconButton.keyboard_focus = false` / `GoSlotGrid.keyboard_focus = false` one by one, or `button.focus_mode = Control.FOCUS_NONE` on a plain button. Give each a shortcut key |
| The game ignores taps where the HUD is empty | A full-rect `Control` defaults to `MOUSE_FILTER_STOP` | HUD root `mouse_filter = MOUSE_FILTER_IGNORE` |
| A button next to an icon button stops responding | The icon button's touch area grows to 48 dp over it | Set `touch_peers` on side-by-side `GoIconButton`s / `GoSlot`s |
| Dragging a list that starts on a button does not scroll | Button uses `MOUSE_FILTER_STOP` | Build rows with `GoStyle` (PASS) inside `GoScroll` (prepares children) |
| Joystick eats mouse clicks on desktop | Its hit area is its whole rect | Show touch controls on handhelds only (`GoUi.is_handheld_platform()`) |
| Gameplay reacts while a menu is open | Game input does not know about windows | `if GoSurface.is_any_open(): return` in gameplay input |
| Android Back quits with a window open, or never quits again | `quit_on_go_back` toggled without pairing | Use `GoBackPolicy.acquire/release` in pairs (release in `_exit_tree` too) |
| `GoForm` ignores Android Back | When the form entered the tree no node named `BackButton` with `unique_name_in_owner` was owned by the form or by the form's owner; on gohud 1.0.3 and older also `owner = form` or a holder owning only the form and the button (cleared when the scroll moves into its edge frame) | Set `back.owner = form` + `unique_name_in_owner` before `add_child(form)`; on 1.0.3 and older own the whole branch from a holder — surfaces.md §4 |
| Pause menu freezes when the tree is paused | Its layer inherits `PROCESS_MODE_PAUSABLE` | `process_mode = Node.PROCESS_MODE_ALWAYS` on the menu's layer |
| Nobody finds the long-press menu | Touch has no right-click and no hover, so an attached `GoContextMenu` is invisible until someone guesses | Keep every action reachable somewhere visible too (footer button, detail page). The menu is a shortcut, never the only route |
| A list stops scrolling where a context menu is attached | The press was held while the finger moved | Already handled: motion over 12 dp cancels the hold. If you wrote your own hold, cancel on `SLOP_DP` the same way |
| A snackbar swallows taps meant for the game | It was given buttons, so it takes input | A `GoSnackbar` with no actions passes input straight through. Give it buttons only when there is something to press |

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
| `get_meta()` prints an error even though a default was passed | `Object.get_meta(name, default)` still reports a missing key | Ask first: `node.get_meta(key) if node.has_meta(key) else null` — `GoBadge`, `GoSpinner` and `GoContextMenu` all do |
| A whole widget file fails to load with a parse error about `tr` | `tr()` is a `Node` method and cannot be called from a `static func` | `TranslationServer.translate(text)` in static code |
| Copying a recipe gives "Invalid access to property" and the script never runs | A template instance was declared with an ancestor type (`var hud: CanvasLayer`), which hides the template's own members | Leave it untyped, or give your copy of the template a `class_name` and use that |
| A widget ignores a theme change until it is rebuilt | It never registered for the notification | `GoUi.watch(_on_ui_changed)` in `_ready`, `GoUi.unwatch(...)` in `_exit_tree` — every gohud widget that draws does this |

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
| Every headless check passes but the screen is visibly wrong | Headless checks read numbers, not pixels — a label with no width, a badge in the wrong corner and a key cap wrapped onto two lines all pass | Take a screenshot in a real or virtual display and **open it**. Five defects in the 2026-09-16 widgets were found this way, none by the suite |
| A doc example does not compile in the reader's project | The example was written from memory | `python3 tools/check_docs_api.py` compares every `GoX.y` in the docs against the source |

