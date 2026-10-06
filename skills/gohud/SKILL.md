---
name: gohud
description: >-
  Build Godot 4.7+ game and app UI with gohud (res://addons/gohud): main, pause and settings menus, inventories,
  HUDs (HP/MP bars, quick slots, joystick, summon columns) placed by corner anchors or edge bars (GoTopBar,
  GoBottomBar, side bars, GoGrid), dialogs, sheets, drawers, popovers, forms, snackbars, and app screens with
  Flutter's widgets (scaffold, navigation and app bars, FAB, swipe tabs, lazy lists, pull to refresh, swipe rows,
  date/time pickers) in presets (default, sci-fi, medieval, Material 3 Expressive, kids, comic, arcade), JSON themes, skins and
  1,271 icons — touch-safe, safe-area aware, RTL and translation ready. Use whenever someone writes GDScript UI,
  HUD, menu or GUI code in a Godot project, ports a Flutter screen to Godot, mentions gohud or a Go* class (GoUi,
  GoStyle, GoSurface, GoSheet, GoDialogs, GoForm, GoHudAnchor, GoScaffold, GoChoiceColumn…), wants to install or
  update gohud, or runs /gohud preview, features or update (plugin: /gohud:preview, /gohud:features, /gohud:update).
license: MIT
metadata:
  author: JaeHo Song
  homepage: https://thruthesky.github.io/gohud/
  repository: https://github.com/thruthesky/gohud
---

# gohud — game UI for Godot 4.7+

gohud is a pure-GDScript HUD & UI kit, tested on Godot 4.7 and officially supported on Godot 4.7
and newer. Every class is global once the folder sits at `res://addons/gohud/`;
widgets are made with `.new()` + `add_child()` and styled by one theme, one skin and one icon set.
This skill carries the whole API (`references/`, with an index of every class in `references/catalog.md`), seven
runnable screen templates (`assets/templates/`) and a preview launcher (`scripts/gohud_preview.py`).

Arguments given: `$ARGUMENTS`

## 1. Route the request

| First word of the arguments | Do |
|---|---|
| `preview` | §6 — launch the preview with the remaining arguments |
| `features` | Read `references/features.md` and present it grouped (one line of code per feature). If an area follows (`features theming`), also read that area's reference and go deeper |
| `update` | Read `references/setup.md` §7 and follow `commands/update.md` — update the add-on in the project **and** this skill, then verify the two agree |
| anything else / empty | §2 — build or change UI with gohud |

Reply in the language the user writes in; keep code identifiers as they are.

## 2. Workflow for building UI

1. **Check the project.** `test -f project.godot`, `test -f addons/gohud/plugin.cfg`, `godot --version` (needs 4.7+).
   Note the gohud version (`version=` in `plugin.cfg`) — rules 4, 5 and 7 differ for 1.0.3 and older.
   Missing add-on → install it (`references/setup.md` §1), then `godot --headless --path . --import`.
   🛑 New in the 1.3.0 release (`CHANGELOG.md` → [1.3.0]): the edge bars and `GoGrid`, the app-screen
   parts (`GoNavBar`, `GoAppBar`, `GoFab`, `GoSearchBar`, `GoSplitButton`, `GoProgress`, `GoLoadingIndicator`,
   `GoDatePicker`), the Flutter widgets (`GoScaffold`, `GoListView`, `GoRefresh`, `GoSwipeRow`, `GoTabView`,
   `GoReorderList`, `GoZoomView`, `GoRangeSlider`, `GoTimePicker`, `GoWheelPicker`, `GoStepper`, `GoBanner`),
   `GoChoiceColumn`, the Material, kids, comic and arcade presets, and these members: `GoDialogs.choose()`, `GoStyle.filter_chip()` /
   `input_chip()` / `restyle_filter_chip()` / `toolbar()` / `bottom_app_bar()` / `glow()`, `GoStyle.Tone.OUTLINED`,
   `GoConfig.button_glow`, `GoScroll.SIDEWAYS`, `GoThemePresets.KIDS_*`/`COMIC_*`/`ARCADE_*`. A project on 1.2.1 or older gets `Identifier "…" not declared` for a
   class and `… not found in base …` for a member — update gohud (`/gohud update`, the 1.3.0 release or `main`) or build
   with what it has.
2. **Pick the look first.** `GoUi.use_preset(GoThemePresets.SCIFI_DARK)` (or the project setting) before any widget
   is built — `DEFAULT_*`, `SCIFI_*`, `MEDIEVAL_*` for games, `MATERIAL_LIGHT`/`MATERIAL_DARK` (Material 3 Expressive)
   for app screens, each `_DARK` and `_LIGHT`, and `KIDS_LIGHT`/`KIDS_DARK` for children — the toy box: keys on a
   lip that sink when pressed, crayon colours, candy slots, a rainbow joystick, and
   `COMIC_LIGHT`/`COMIC_DARK` — a bold ink outline and a hard, faint shadow on every part, whose outline width,
   shadow size and shadow on/off are `GoConfig.comic_border_width`/`comic_shadow_size`/`comic_shadow` (one line
   restyles every part; `GoStyle.comic_shadow(node, on)` for one widget — theming.md §1), and
   `ARCADE_LIGHT`/`ARCADE_DARK` — an arcade cabinet: every key painted with a gradient, a gloss and a lip, white
   ink-outlined labels, thick framed boards, a gold title banner (`GoStyle.arcade_paint(node, colour)` paints one key
   its own colour — theming.md §1).
   `GoThemePresets.names()` lists every preset this copy has, including any `themes/presets/<id>.tres` added later. Call it **once at boot** (the main scene or an autoload), not
   in each screen: the preset is global, so a screen that sets it restyles every other screen too. gohud's own widgets
   restyle themselves on a switch, but a node keeps the `theme` it was built with — switching later means rebuilding the
   screen (`recipes.md` §11). The Material presets read Roboto, which has no Korean, Japanese or Chinese — for those
   languages set the project's own font (Project Settings › GUI › Theme › Custom Font); gohud never replaces it.
3. **Choose the widget for the job** — the table below. A class you half remember, or "is there a widget for …?" →
   `references/catalog.md` (every class by name, with an example and where its members are documented).
4. **Start from a template** when one fits (§5): copy it into the project (e.g. `res://ui/`), rename, adjust, wire
   its signals. Otherwise compose with `GoStyle` factories (`references/style.md`).
5. **Follow the rules in §3.** Look up exact signatures in the references before using a member you are not sure
   of — do not guess APIs.
6. **Verify without a window:** `python3 ${CLAUDE_SKILL_DIR}/scripts/gohud_preview.py res://ui/my_screen.tscn --check`
   (or `godot --headless --path . --quit-after 120 res://ui/my_screen.tscn` and scan for `SCRIPT ERROR`,
   `Parse Error`, `ERROR: Failed`). In a test script, `GoStyle.audit_layout(root)` a frame or two after the screen is
   laid out lists every control that is cut, spilled or squeezed (empty = clean). Open a visible window only when the
   user asks to see it (§6).

### Pick the widget

| You need | Use | Read |
|---|---|---|
| **Windows** | | |
| A question that must be answered (delete, quit, buy) | `await dialogs.confirm(…)` — `destructive = true` for irreversible | surfaces.md §3 |
| One of a few options (sort by, share to) | `await dialogs.choose(title, options)` → index or -1 | surfaces.md §3 |
| A list or management page over the game | `GoSheet` (pages with Back, sticky footer) | surfaces.md §2 |
| A window — settings, details | `GoSurface` in a `CanvasLayer` | surfaces.md §1 |
| A side panel on a wide screen, an app's menu | `GoDrawer` | surfaces.md §9 |
| A card about the thing under the finger (item stats by its slot) | `GoPopover.open(slot, card)` | surfaces.md §10 |
| A full-screen menu, login, character creation | root `Control` + `GoForm` → `GoScroll` → column | surfaces.md §4 |
| **Messages and waiting** | | |
| A message with an optional button (Undo, Retry) that goes away by itself | `GoSnackbar` — `await post({…})` → button index | surfaces.md §8 |
| A toast the HUD owns, never takes input | `GoNotice` on a `GoHudAnchor` | hud.md §6 |
| An optional question during play (invite, trade) | `GoPromptCard` | hud.md §7 |
| A message that stays on the page until dealt with | `GoBanner` | flutter.md §2 |
| A wait · known progress | `GoSpinner` (`GoSpinner.busy(button, true)` also blocks the double press), `GoLoadingIndicator` · `GoProgress`, `GoBar` | hud.md §11, §16 |
| A count or a dot on a button | `GoBadge.attach(button, count)` | hud.md §12 |
| A first-run tour that points at real controls | `GoCoachMark` | hud.md §8 |
| **HUD** | | |
| Loose pieces in corners and on edge middles, stepping aside for each other | `GoHudAnchor` (template `game_hud.gd`) | hud.md §1, §19 |
| Rows and columns along the screen's edges, one to three slots each | `GoTopBar` · `GoBottomBar` · `GoLeftSideBar` · `GoRightSideBar`, side bars `clear_of([top, bottom])` (template `edge_bar_hud.gd`) | style.md §1 "Layout classes", hud.md §19 |
| HP / MP / XP | `GoBar` with fill tokens (rule 8) | hud.md §2 |
| Quick slots · an inventory grid | `GoSlot` · `GoSlotGrid` | hud.md §3 |
| A virtual stick | `GoJoystick` | hud.md §4 |
| A short list of actions where one tap acts and several rows can be marked (a summon list) | `GoChoiceColumn` — not `GoWheelPicker`, which settles on one value | hud.md §18 |
| A long-press or right-click menu | `GoContextMenu.attach(node, items)` + a visible `⋯` (`open_at`) | hud.md §9 |
| Stats · a share · banners · daily rewards | `GoRadar` · `GoDonut` · `GoCarousel` · `GoRewardCalendar` | hud.md §13–§15 |
| Key hints on PC · a developer console | `GoKbd.for_action(&"interact")` · `GoConsole` | platform.md §7, hud.md §10 |
| **App screens — Flutter's widgets** | | |
| A whole screen: app bar, page, bottom bar, FAB, drawer | `GoScaffold` (template `app_screen.gd`) | flutter.md §2 |
| Bottom destinations · a rail · the title bar · the main action | `GoNavBar` · `GoNavBar.rail()` · `GoAppBar` · `GoFab` (one per screen) | hud.md §16 |
| Thousands of same-height rows · pull to refresh · swipe a row aside · drag to reorder | `GoListView` · `GoRefresh.attach(list)` · `GoSwipeRow.wrap(row, …)` · `GoReorderList` | flutter.md §2 |
| Tabs whose pages swipe · pinch and pan | `GoTabView` · `GoZoomView` | flutter.md §2 |
| A search field · filters · a main action with variants | `GoSearchBar` · `GoStyle.filter_chip()` · `GoSplitButton` | hud.md §16, style.md §6 |
| A date or a range of dates · a time · a wheel · a price range · steps | `GoDatePicker` · `GoTimePicker` · `GoWheelPicker` · `GoRangeSlider` · `GoStepper` | hud.md §16, flutter.md §3 |
| Any other Flutter widget | the catalogue maps each one to gohud or Godot | flutter.md §4–§5 |
| **Forms, lists and layout** | | |
| A field that can show its own error | `GoField` (`GoStyle.field()` when nothing can go wrong) | style.md §9 |
| An input welded to a button · a searchable picker · a coupon code | `GoInputGroup` · `GoCombobox` · `GoCodeInput` | style.md §9 |
| Sortable, selectable rows · pages | `GoTable` · `GoPagination` | style.md §9 |
| A list the player scans (quests, mail, a shop) | rule 15 below | recipes.md §16 |
| Equal columns · chips that wrap · a card | `GoGrid` · `GoStyle.wrap_row()` · `GoStyle.card()` | style.md §1, §6 |
| Buttons, toggles, sliders, selects, tabs, chips, labels | `GoStyle` factories | style.md §2–§6 |

## 3. Rules that prevent the real bugs

1. **Sizes and colours come from tokens**, never literals: `GoUi.metric(GoTheme.GAP)`, `GoUi.color(GoTheme.MUTED)`,
   `GoStyle.*` factories. Literals break when the preset, breakpoint or touch size changes.
2. **Text vs keys.** `GoStyle.label()/button()` show text as written; `label_key()/button_key()` hold translation
   keys. `list_button()`, `foldable()`, `section()`, `toggle()`, `checkbox()`, `empty_state()` and `GoStyle.field()`
   translate by default — pass `translate = false` for literal strings (`GoField.make()` is the other way round:
   literal unless you pass `true`). 🛑 `toggle()`, `line_edit()` and `textarea()` given `false` only **inherit** the
   parent's mode — a word that is also a key in your tables still translates; set
   `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED` on them for text that must stay as typed.
3. **Surfaces go in a `CanvasLayer`, and the owner closes them.** `GoSurface` only emits `close_requested`.
   Layers: HUD 5 · `GoSheet` 10 · your popups 50 · `GoDrawer` 80 · `GoSnackbar` 90 · `GoPopover` 95 · `GoDialogs` 100 ·
   `GoConsole` 200.
4. **Per-page sheet buttons go through `sheet.add_footer(button)`** — the next `open()` removes them. `open()` only
   hides `footer()`, so children added with `footer().add_child()` stay (right for a sheet-wide snackbar, wrong for a
   Close button re-added on every open). gohud 1.0.3 and older have no `add_footer()`: remove your footer children first.
5. **Assemble `GoForm → GoScroll → column` before the form enters the tree.** `_ready` runs inside `add_child`; a
   scroll added later is never found (no keyboard follow), and `%BackButton` (Android Back routing) is looked up once
   there. In code: name the button `BackButton`, add it, set `back.owner = form` and `back.unique_name_in_owner = true`,
   then `add_child(form)`. gohud 1.0.3 and older clear that owner when the scroll moves — there, own the whole branch
   from a holder (`owner = holder` on every descendant; the templates do this, and it works on every version).
6. **HUD root: `mouse_filter = MOUSE_FILTER_IGNORE`.** Transient anchors (toasts, prompts, joystick) use
   `reserve_space = false`; toasts at `TOP_CENTER` use `avoid_peers = true`. Put a panel behind HUD text that floats
   over the world — `GoStyle.hud_panel()`, or a `PanelContainer` wearing `GoStyle.floating(GoTheme.BOX_HUD)`; an icon
   button straight on the world wears `GoUi.skin().overlay_box()`. Pressables over gameplay give up keyboard focus
   (`keyboard_focus = false` on `GoIconButton`/`GoSlot`, `focus_mode = FOCUS_NONE` on a plain `Button`) — a clicked
   button keeps focus and Space presses it again. A HUD root sets `layout_direction = LAYOUT_DIRECTION_LTR` so bars
   and anchors keep their physical sides in Arabic.
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
12. **Widgets that draw text inside a non-container parent must not wrap.** A `Label` with autowrap laid
    out at zero width freezes its minimum height at 1 dp and the text disappears while the panel still
    paints — this is why table cells, key caps and code cells set `AUTOWRAP_OFF`. When you place a child by
    anchors, set `offset_*`, not `position`: `Control.position` is parent-space and ignores the anchors.
13. **Containers are 80% opaque (100% under the Material presets); things you press are not.** Panels (`GoSurface`/`GoSheet`/`GoDialogs`/cards/
    HUD panels/alerts/snackbars) fade their **face only** — never use `modulate.a` for this, it fades the text too.
    Set a project-wide value at boot (or in your `GoConfig` `.tres`); changed later, `GoUi.refresh()` repaints gohud's
    own windows, but a face you put on a panel yourself (`GoStyle.floating()`, `hud_panel()`) keeps its value until
    the panel is rebuilt. Five layers decide the value, most specific first: the `alpha` argument or field at that call →
    `GoConfig.container_alpha_overrides[GoTheme.BOX_*]` → `metric_overrides[<kind>_alpha]` →
    `GoConfig.container_alpha` → theme `GoHud/constants/<kind>_alpha`. 🔑 **Every one of them is a ratio
    `0.0–1.0`** (negative = not set), including `@export` fields such as `dialogs.alpha` and `drawer.alpha` —
    same units everywhere, so there is nothing to memorise per widget. 🛑 The **two exceptions are the theme's
    constants and `metric_overrides`**, which are percent integers (`80`) because a `Theme` constant cannot hold
    a float. Call `GoUi.refresh()` after changing it from code. Read the resolved value with
    `GoUi.surface_alpha(variant)`; apply it to a panel gohud did not build with `GoStyle.fade_panel(node)` (after
    `add_child`). A `GoSkin` subclass overriding `surface_box`/`floating_box`/`alert_box` **must carry the `alpha`
    parameter** or the script will not parse. 🔑 **Drag it before you argue about the number**: the opacity lab
    (`examples/gallery/opacity_lab.gd`) is hosted by the gallery, the guided tour (chapter 16), the home screen
    and the medieval example — it shows the four ways to set the value on one screen, over a pattern, because a
    value check cannot tell you whether the text is still readable. Details: `references/theming.md` §4.
14. **Never hand-edit gohud's generated themes**; recolour through `color_overrides`, a Theme copy in your project,
    a project-local `GoThemePreset`, or the JSON theme tools (`references/theming.md`).
15. **Lists must scan** — a list the player reads (quests, mail, a shop, a roster) is judged by numbers, not taste.
    ① **Space outside a row > space inside it ≥ space between its lines:** rows at least `GAP_SMALL` (8) apart
    (`GAP` 12 when there is room), a two-line row padded 8 above and below and 12 at the sides, its two lines
    `GAP_TINY` (4) apart — `list_button()` already pads its row this way. A cramped panel that used 4 for all three
    ran its rows together. ② **The heading must be a size above the row titles.** Rows are `ROLE_BODY` (16) with a
    `ROLE_CAPTION` (13) second line in `MUTED`; the heading the player reads first is `ROLE_SUBTITLE` (22) — sizes of
    the default theme (Material: caption 14, subtitle 24); use the roles, not the numbers. A
    `GoSurface` or `GoSheet` short of height (or `compact`) drops **its own** title to `body`, so a list under it
    becomes one size — put that heading in the body instead. ③ Say a thing once: no header line repeating the first
    row. ④ Warning colours and warning icons only on rows where something is wrong; a level gate is a `LOCK` and
    `MUTED` text (never `modulate.a` — rule 13). A badge that repeats on every row carries nothing — drop it; an icon
    that states each row's own state (a lock, a check) may repeat. ⑤ A value at a row's end (`0 / 1`, a price)
    is a label with `SIZE_SHRINK_END` — `GoStyle.label()` expands by default and would split the width with the
    title. `list_button()` has no text slot at the end: build that row yourself and keep its padding and
    `GoStyle.fit_content_height()`. ⑥ Your spacing does not survive everywhere: `GoStyle.form()` (every `GoForm`)
    gives `GAP` to each box whose `separation` is `GAP` or unset — any other value you chose stays, and
    `set_meta(&"go_own_spacing", true)` exempts a box entirely — and a
    `wrap_row()` forces everything inside it — all the way down — to natural width with wrapping off, so never put a
    card or a row with an expanding title in one. **See it before you build it:** the gallery's List rows section
    opens a lab (`examples/gallery/list_lab.gd`) with a cramped quest panel next to the same panel built by this
    rule, each measured from its own nodes. Recipe: `references/recipes.md` §16.

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

Each is a complete script with no scene file, checked headless by `tests/gohud_templates_test.gd` on every
`check_all.sh` run. Copy it into the project (e.g. `res://ui/`), rename, connect its signals, adjust.

| File | Extends | Builds | Public API |
|---|---|---|---|
| `main_menu.gd` | Control | Title, Continue / New game / Settings / Quit rows, confirm dialogs, a Continue button that becomes a spinner | signals `continue_requested` `new_game_requested` `settings_requested` `quit_confirmed` · `build()` · `set_loading(waiting)` |
| `game_hud.gd` | CanvasLayer (5) | HUD by corner anchors: HP/MP/XP panel, menu button with an unread badge, 4 quick slots, FOLLOW joystick, toast, prompt card, snackbar | signals `menu_requested` `slot_used(index)` `move_input(vector)` · `build()` · `set_health/set_mana/set_experience(v, max)` · `toast(msg, tone)` · `await say(msg, actions, tone)` · `set_unread(count)` · `ask(title, subtitle, accept_text, accept, decline_text, decline)` |
| `edge_bar_hud.gd` | CanvasLayer (5) | HUD by edge bars, for a landscape screen (fits 844×390 dp): HP/MP · stage name on the centre · coins and menu across the top, a `GoChoiceColumn` summon list on the left, quick slots on the right, Attack / Guard / Run along the bottom | signals `menu_requested` `summon_requested(index)` `slot_used(index)` `action_pressed(index)` · `build()` (keeps what it shows) · `set_health/set_mana(v, max)` · `set_stage(title)` · `set_coins(amount)` · `set_summoned(index, out)` · `set_resting(index, resting)` · `set_summons(choices)` (clears the marks) |
| `pause_menu.gd` | CanvasLayer (50) | Centred GoSurface, pauses the tree, Escape opens/closes, a key cap that reads the real binding, quit confirm | signals `resumed` `settings_requested` `quit_to_title_requested` · `open()` `resume()` `toggle()` `is_open()` |
| `inventory_sheet.gd` | Node | GoSheet with search + category filter, long-press menu on each row, detail page with Back, Use / Drop with Undo | signals `item_used(item)` `item_dropped(item)` · `items` · `open()` `close()` `show_list()` `show_item(item)` |
| `settings_menu.gd` | Control | GoForm, foldable Display/Audio/Controls/Language sections built from `GoField` (so a row can show its own error), draft + Save/Reset, discard check | signals `closed(saved)` `settings_changed(values)` · `settings` · `build()` `save()` `request_back()` `reset_to_defaults()` |
| `app_screen.gd` | Control | An app screen (Flutter's `Scaffold`): app bar with a drawer menu and search · tabs over a lazy feed with pull to refresh and load more, and a Saved list you swipe away with Undo · navigation bar with a badge · compose FAB | signals `post_opened(post)` `compose_requested` `search_requested` `refresh_requested` `more_requested` `destination_changed(index)` `drawer_chosen(index)` `saved_removed(post)` (swiped away, no Undo) · `build()` · `set_posts(list)` `add_posts(list)` (an empty page ends "load more") `set_saved(list)` `set_unread(count)` `show_tab(index)` · `await say(msg, actions)` |

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
| *(none)* / `gallery` · `--preset scifi_dark` · `--phone` · `--size 1920x1080` | Every widget, preset picker, icon set; **List rows → Readable lists** opens the before/after list lab |
| `medieval` | Character sheet, satchel, quest journal |
| `icons` | Buttons from the 1,000-icon library: toolbar, text + icon, toggles, menu rows, segmented, a group, live search |
| `demo` · `demo --explore hud` | The demo's home (gallery, guided tour, showcase, medieval) / one chapter of the 31-chapter tour (`list` shows keys) |
| `res://ui/main_menu.tscn` | A scene of the user's project, inside that project |
| `list` · `--check` · `--dry-run` · `--godot PATH` | Keys · headless smoke test · print command · Godot binary |

gohud's examples run in a sandbox project under the user cache, so the user's project is not modified. The script
detaches and prints the process id and log path. Exit 2 = Godot 4.7+ not found or bad arguments; exit 1 = import
or launch error (it prints the error lines). A visible window is what `/gohud preview` is for; for your own checks
use `--check`.

## 7. References — read the one you need

| File | Read when |
|---|---|
| `references/catalog.md` | "Is there a widget for …?", a class you half remember, the whole kit at a glance — every class and factory group by name, what it extends, one example, and the section with its members. Generated from the website's All widgets list |
| `references/features.md` | `/gohud features`, or "what can gohud do" — catalogue of every feature with one-line code |
| `references/setup.md` | Installing, **updating (§7 — add-on and skill, `/gohud update`)**, enabling the plugin, every `GoConfig` field and default, boot order, layers, project settings, headless verification, gohud's tool commands |
| `references/surfaces.md` | `GoSurface` (placements, anchored menus, sub-pages, status line), `GoSheet`, `GoDialogs` (layouts, destructive, args, `choose`, queueing), `GoForm`, `GoScroll`, subclass hooks, which widget to use, `GoSnackbar`, `GoDrawer`, `GoPopover` |
| `references/hud.md` | `GoHudAnchor` spots and avoidance, `GoBar`, `GoSlot`/`GoSlotGrid`, `GoJoystick`, `GoIconButton`, `GoNotice`, `GoPromptCard`, `GoCoachMark`, `GoContextMenu`, `GoConsole`, `GoSpinner`, `GoBadge`, `GoRewardCalendar`, `GoRadar`/`GoDonut`, `GoCarousel`, the app-screen parts (§16: `GoNavBar`, `GoAppBar`, `GoFab`, `GoSearchBar`, `GoSplitButton`, `GoProgress`, `GoLoadingIndicator`, `GoDatePicker`), `GoChoiceColumn` (§18), composing a HUD with anchors or edge bars (§19) |
| `references/style.md` | Every `GoStyle` factory signature: structure and the **layout classes** (`GoTopBar`, `GoBottomBar`, `GoLeftSideBar`, `GoRightSideBar`, `GoGrid`), text, buttons and tones, inputs, select/dropdown/segmented/tabs, cards, chips, tables, styleboxes, helpers, the form and list classes (`GoField`, `GoInputGroup`, `GoCombobox`, `GoCodeInput`, `GoTable`, `GoPagination`) and the lower-level functions |
| `references/theming.md` | The fourteen presets (default, sci-fi, medieval, Material 3 Expressive, kids, comic, arcade — each dark and light — and how a new one is found) and resolution order, all tokens, **container opacity (§4)**, overrides, JSON themes (`new_theme.py`/`make_theme.py`), skins, their hooks and dials, custom StyleBoxes, project-local presets, contrast |
| `references/platform.md` | Icons — the 84 default names, the game set (187) and the icon library (1,000) with `GoUi.add_icons()`, search and groups, custom icon sets/fonts/folders, localization and RTL, sound and haptics, accessibility, safe area, breakpoints, dp scale, Android Back |
| `references/recipes.md` | Full screens and wiring: game scene with HUD + pause + inventory, login, shop, quest log, a quest list that scans (§16), character sheet, context menu, tutorial, loading/empty/error states, controls over a map, theme switcher, attendance, developer console, per-field errors, a side panel |
| `references/pitfalls.md` | Symptoms → cause → fix for layout, text, input, theme and lifecycle traps |
| `references/flutter.md` | Coming from Flutter — every Flutter widget and its gohud (or Godot) counterpart, and the widgets ported from it: `GoScaffold`, `GoListView`, `GoRefresh`, `GoSwipeRow`, `GoTabView`, `GoReorderList`, `GoZoomView`, `GoRangeSlider`, `GoTimePicker`, `GoWheelPicker`, `GoStepper`, `GoBanner` |

Web (same content, with screenshots): overview https://thruthesky.github.io/gohud/ ·
install https://thruthesky.github.io/gohud/install.html · AI skill https://thruthesky.github.io/gohud/ai.html ·
widgets https://thruthesky.github.io/gohud/widgets.html · theming https://thruthesky.github.io/gohud/theming.html
