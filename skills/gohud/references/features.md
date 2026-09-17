# gohud features — the catalogue

Read this for `/gohud features` or "what can gohud do?". Present it grouped, with one line of code per
feature, and link the matching reference for depth.

**Version described: gohud 1.0.3 + Unreleased (`main`).** This file is the complete list — 48 classes and
98 `GoStyle` factories. When you add a class or a factory, add it here in the same turn; a feature nobody
can find is a feature nobody uses.

## Contents

1. [What gohud is](#1-what-gohud-is)
2. [Surfaces — windows, sheets, drawers, dialogs, forms](#2-surfaces)
3. [HUD and in-game widgets](#3-hud-and-in-game-widgets)
4. [Feedback — waiting, alerts, badges](#4-feedback)
5. [Lists, tables and pickers](#5-lists-tables-and-pickers)
6. [Game-shaped widgets](#6-game-shaped-widgets)
7. [GoStyle — the control factory](#7-gostyle--the-control-factory)
8. [Looks — presets, themes, skins, icons](#8-looks)
9. [Mobile, desktop, accessibility, languages](#9-mobile-desktop-accessibility-languages)
10. [Configuration, tooling and examples](#10-configuration-tooling-and-examples)

## 1. What gohud is

A HUD & UI kit for **Godot 4.6+**, pure GDScript, MIT. Drop the folder at `res://addons/gohud/` and every
class (`GoUi`, `GoStyle`, `GoSurface`, …) is usable at once — no autoload, no scene files, enabling the
editor plugin only adds conveniences. Every widget is built with `.new()` + `add_child()`.

- Homepage: https://thruthesky.github.io/gohud/ · Widgets: https://thruthesky.github.io/gohud/widgets.html
- Theming: https://thruthesky.github.io/gohud/theming.html · Source: https://github.com/thruthesky/gohud
- Update the add-on and this skill: `/gohud update` (see setup.md §7)

## 2. Surfaces

| Feature | One line | Reference |
|---|---|---|
| `GoSurface` floating window — `CENTER`, `BOTTOM` or `ANCHOR` placement, fixed header/toolbar/status/footer, scrolling body, drag-to-resize, safe area and keyboard aware, Escape/Back closes only the topmost | `var s := GoSurface.new(); s.set_title("Settings"); s.close_requested.connect(s.queue_free)` | surfaces.md §1 |
| `GoSheet` bottom sheet on its own `CanvasLayer`, pages with back navigation, sticky search row and footer | `sheet.open("Inventory"); sheet.footer().visible = true` | surfaces.md §2 |
| **`GoDrawer`** panel that slides in from the **left or right** — for tablet and desktop layouts where a bottom sheet covers too much; background reaches the screen edge, content stays inside the safe area | `drawer.side = GoDrawer.Side.RIGHT; drawer.open("Bag")` | surfaces.md §2 |
| `GoDialogs` confirm/alert you `await`; `destructive` confirm button; vertical, horizontal or auto button layout; **alerts queue** instead of vanishing when one is already open | `if await dialogs.confirm("Delete save", "Cannot be undone.", "", "", "", {}, true):` | surfaces.md §3 |
| **`GoPopover`** anchored info card in one line — item tooltips, skill descriptions; one open at a time, transparent scrim so the game stays readable | `GoPopover.open(slot, item_card(item))` | surfaces.md §1 |
| `GoForm` width-capped form that wraps every label, avoids the virtual keyboard and (with `avoid_hud`) the HUD | `form.avoid_hud = true` | surfaces.md §4 |
| `GoScroll` touch scrolling with the scrollbar tucked into card padding, RTL-aware | `var scroll := GoScroll.new()` | surfaces.md §5 |

## 3. HUD and in-game widgets

| Feature | One line | Reference |
|---|---|---|
| `GoHudAnchor` pins pieces to 9 safe-area spots, optional landscape spot, `reserve_space`, `avoid_peers` | `corner.spot = GoHudAnchor.Spot.TOP_LEFT` | hud.md §1 |
| `GoBar` HP/MP/XP bar, eased, value / fraction / percent readout, number abbreviation | `hp.set_values(320, 500)` | hud.md §2 |
| `GoSlot` quick slot: icon, quantity badge, cooldown, shortcut, shared touch areas | `slot.start_cooldown(5.0)` | hud.md §3 |
| **`GoSlotGrid`** inventory grid: *N* wrapping cells, vacant cells drawn faint, one picked cell, drag-to-move for mouse play | `grid.set_cell(0, {"icon": GoGameIcons.APPLE, "quantity": 12})` | hud.md §3 |
| `GoJoystick` virtual stick, `FIXED` / `FOLLOW` / `RELATIVE`, dead zone, normalized vector | `pad.moved.connect(func(v): player.direction = v)` | hud.md §4 |
| `GoIconButton` 36 dp visual, 48 dp touch, tooltip = accessible name | `GoStyle.icon_button(&"close", close, -1, &"close")` | hud.md §5 |
| `GoPromptCard` non-blocking question card (party invite, trade request) | `card.set_actions([{"text": "Accept", "action": ok, "primary": true}])` | hud.md §7 |
| `GoCoachMark` guided tour pointing at real controls; pressing the target advances | `tour.start([{"target": bag, "title": "Bag", "body": "…"}])` | hud.md §8 |
| **`GoContextMenu`** long-press on touch, right-click on desktop — **cancelled the moment the finger moves**, so scrolling a list never pops a menu | `GoContextMenu.attach(slot, [{"text": "Drop", "danger": true}])` | hud.md §9 |
| **`GoConsole`** developer console — cheat/debug commands, command palette with filtering, history; **refuses to open in release builds** | `console.register("give", "Grant an item", give)` | hud.md §10 |

## 4. Feedback

| Feature | One line | Reference |
|---|---|---|
| **`GoSnackbar`** places itself at the bottom (or top), above safe area and keyboard, **queues**, merges repeats, and can carry buttons — `await` returns which one was pressed | `if await snack.post({"text": "Item dropped", "actions": ["Undo"]}) == 0: restore()` | hud.md §6 |
| `GoNotice` inline notice that **never takes input or focus** — the screen that owns it decides where it goes | `notice.show_text("Saved", GoTheme.SUCCESS)` | hud.md §6 |
| **`GoSpinner`** indeterminate wait; `busy()` turns a button into a spinner **in place**, keeps its size, and blocks the double press that duplicates a purchase | `GoSpinner.busy(buy_button, true)` | hud.md §11 |
| **`GoBadge`** unread dot, `NEW` tag, `99+`; `attach()` hangs it on a corner and hides itself at zero | `GoBadge.attach(mail_button, unread)` | hud.md §12 |

🔑 Which one: a button to press → `GoSnackbar`. A fixed notice panel the HUD owns → `GoNotice`.
A question that must be answered → `GoDialogs`. An optional question → `GoPromptCard`.

## 5. Lists, tables and pickers

| Feature | One line | Reference |
|---|---|---|
| **`GoTable`** sortable headers and selectable rows; **numeric columns sort as numbers**, so `9124` never outranks `91240` | `GoTable.make(columns, rows).row_selected.connect(open_profile)` | style.md §8 |
| **`GoPagination`** numbered pages that keep the current one centred, plus a mobile-friendly "more" row and a busy lock | `GoPagination.make(1, 12, load_page)` | style.md §8 |
| **`GoCombobox`** picker with a search line that matches **inside** names, not just their start | `GoCombobox.make(friends, -1, "Find a friend")` | style.md §5 |
| **`GoField`** label + control + hint + **per-field error**, so a form says which box is wrong | `field.set_error("That name is taken")` | style.md §5 |
| **`GoInputGroup`** an input and its button welded into one shape (chat + send, coupon + redeem, − qty +) | `GoInputGroup.make(edit, {"suffix": send})` | style.md §5 |
| **`GoCodeInput`** coupon and gift codes — one hidden field receives the text and the cells are drawn, so pasting `ABCD-EFGH-IJKL` works and IME input cannot lose a character | `GoCodeInput.make(12, 4)` | style.md §5 |

🔑 `GoStyle.field()` vs `GoField`: the factory is a static label+control+hint group with **no error state** —
use it when nothing can go wrong. `GoField` is a node that can show and clear a **per-field error** and tint
the control's border; use it for anything a server can reject.

## 6. Game-shaped widgets

Shapes that web UI kits have, reshaped for what games actually need.

| Feature | One line | Reference |
|---|---|---|
| **`GoRewardCalendar`** daily attendance rewards — what matters is **which day you are on**, not which date; today's cell is the only one you can press | `GoRewardCalendar.make(days, claimed_until)` | hud.md §13 |
| **`GoRadar`** the character stat pentagon, with a **dashed** overlay to compare gear (dashed, not just a second colour, so it survives colour blindness) | `GoRadar.make({"STR": 0.8, "AGI": 0.5})` | hud.md §14 |
| **`GoDonut`** damage share, currency split; collapses past five slices and carries a legend **with words**, not only colour | `GoDonut.make(slices).legend()` | hud.md §14 |
| **`GoCarousel`** store banners and character select; does **not** advance on its own by default, and never when `reduce_motion` is on | `carousel.set_pages([a, b, c])` | hud.md §15 |
| **`GoKbd`** key caps for PC/Steam builds; `for_action()` reads the **real binding** from `InputMap`, so rebinding does not make the hint lie; hides itself on handhelds | `GoKbd.for_action(&"interact")` | platform.md §7 |

## 7. GoStyle — the control factory

Every control made one consistent way, sized from tokens, touch-safe, wrap-safe. Full signatures in style.md.

| Group | Functions |
|---|---|
| Structure | `column` `row` `wrap_row` `padding` `insets` `edge_insets` `gap` `spacing` `spacer` `divider` `line` `responsive_grid` `aspect` `foldable` |
| Text | `label` `label_key` `section` `typography` `font_role` `pin_font_size` `style_mono_text` `text_shadow` `glyph_text` `glyph_type` `glyph_width` |
| Buttons | `button` `button_key` `style_button` `icon_button` `list_button` `list_row` `restyle_list_row` `apply_icon` `fit_words` `center_button_content` `tint_button` `style_brand_button` `style_overlay_button` `style_disc_button` `touch_face` — tones `NORMAL` `PRIMARY` `DANGER` `DANGER_SOLID` `BARE` `COMPACT` |
| Input | `line_edit` `textarea` `toggle` `checkbox` `slider` `picker` `select` `dropdown` `radio_group` `segmented` `choice_grid` `style_choice_card` `field` |
| Display | `card` `card_body` `item_card` `chip` `chip_panel` `restyle_chip` `style_chip_button` `style_chip_label` `avatar` `skeleton` `alert` `table` `tabs` `breadcrumb` `progress` `tint_progress` `empty_state` `style_count_badge` |
| Panels & faces | `surface` `box` `floating` `disc` `plate` `hud_panel` `style_hud_panel` `overlay_panel` `style_overlay_panel` `bare_panel` `style_panel` `style_notice_panel` `disc_panel` `style_disc_panel` `style_disc_label` `style_hud_disc` `edge_card` `edge_card_panel` `face_padding` `face_insets` `style_slot_face` |
| Helpers | `form` `fade` `tooltip_node` `natural_width` `fit_content_height` `let_input_through` `style_popup` `audit_compact_padding` |

## 8. Looks

| Feature | One line | Reference |
|---|---|---|
| Six presets swap theme + skin + icons together: `default_dark/light`, `scifi_dark/light`, `medieval_dark/light` | `GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)` | theming.md §1 |
| **Switching a preset reaches widgets that are already on screen** — bars, slots, joysticks, badges and the rest re-read colours and icons in place | `GoUi.use_preset(GoThemePresets.SCIFI_DARK)` | theming.md §1 |
| Tokens: 17 colours + 5 fill colours, 20 metrics, **5 panel-opacity values**, 8 styleboxes, 7 text roles, 15 type variations | `GoUi.color(GoTheme.ACCENT)` · `GoUi.metric(GoTheme.GAP)` | theming.md §2 |
| Per-project overrides without a new theme | `GoUi.config.color_overrides[GoTheme.ACCENT] = Color("#ff7a00")` | theming.md §3 |
| **Containers are 80% opaque so the game stays visible behind a dialog** — face only; text, buttons, borders and shadows stay sharp. Set it per project, per panel kind, or per window | `surface.alpha = 0.6` · `GoUi.config.container_alpha = 1.0` | theming.md §4 |
| A new theme is one JSON file inheriting a built-in one; builder enforces WCAG contrast | `python3 addons/gohud/tools/new_theme.py kingdom --from medieval_dark` | theming.md §5 |
| Skins own code-drawn shapes (joystick, slots, coach ring, chips, alerts); 32 numeric dials | `class_name MySkin extends GoSkin` | theming.md §6 |
| Custom StyleBoxes: `GoStyleBoxCut` (chamfer, edge, glow), `GoStyleBoxBracket` (corner marks), `GoStyleBoxMedieval` (forged frame) | `var box := GoStyleBoxCut.new()` | theming.md §7 |
| Icons by name: 84 default + 16 engraved medieval (MIT, `DPITexture`); swap to your SVGs or an icon font, or override a few | `GoUi.icons().node(&"settings", 20)` | platform.md §1 |
| **Game icon set** — 187 icons for inventories, shops, equipment, food, resources, tech & space, places and rewards (MIT; 171 from Tabler Icons, 16 drawn for gohud), falls back to the default set | `GoUi.config.icons = GoGameIcons.icon_set()` | platform.md §1 |

## 9. Mobile, desktop, accessibility, languages

| Feature | One line | Reference |
|---|---|---|
| 48 dp touch targets behind smaller visuals; overlapping targets go to the nearer centre (`touch_peers`) | `slot.touch_peers = peers` | platform.md §4 |
| Safe area (notch, gesture bar) and virtual keyboard avoidance | `GoSafeArea.usable_rect(get_window())` | platform.md §5 |
| Breakpoints by short side in dp (mobile ≤ 576, tablet ≤ 991); optional 1 unit = 1 dp scaling | `GoScale.breakpoint_for_dp(dp)` | platform.md §5 |
| Android Back / Escape ownership shared across windows | `GoBackPolicy.acquire(get_tree())` | platform.md §6 |
| Focus rings only for keyboard/gamepad, focus trapped in windows and restored on close | `GoConfig.suppress_pointer_focus_ring` | platform.md §4 |
| 16 built-in strings in 21 languages, RTL (`ar`, `he`), translatable number formats, CJK number hook | `GoUi.config.text_overrides = {&"confirm": "Yes"}` | platform.md §2 |
| Sound cues and haptics routed to your audio system (gohud ships no audio) | `GoFeedback.sound_handler = func(cue): $Audio.play(cue)` | platform.md §3 |
| `reduce_motion`, `autowrap_text`, `min_touch_size`, `accessibility_name` on icon buttons | `GoUi.config.reduce_motion = true` | platform.md §4 |
| **`GoUi.spoken()`** joins the pieces a screen reader should hear as one phrase, in one place | `node.accessibility_name = GoUi.spoken([label.text, error.text])` | platform.md §4 |

## 10. Configuration, tooling and examples

| Feature | One line | Reference |
|---|---|---|
| One `GoConfig` resource (appearance, responsive, surface, feedback, localization, accessibility) that survives add-on updates | `GoUi.config = preload("res://ui/gohud_config.tres")` | setup.md §3 |
| Optional plugin: project settings for config + preset, `GoRuntime` autoload (breakpoints, dp scale, keyboard), translations | Project → Project Settings → Plugins → gohud | setup.md §2 |
| Subclass hooks `_make_scroll`, `_make_close_button`, `_make_surface`, `_should_pause` | `func _make_surface() -> GoSurface: return MySurface.new()` | surfaces.md §6 |
| Gallery, medieval example, 23-chapter demo tour with explore mode | `/gohud:preview demo --explore hud` | SKILL.md §6 |
| **693 headless checks** (`gohud_test.gd` 568 + `gohud_extra_test.gd` 125), WCAG contrast checker, packaging gates, CI on every push | `bash addons/gohud/tools/check_all.sh` | setup.md §6 |
| **Screenshot check on a virtual monitor** — value checks know "how much", not "is it visible"; five layout faults were found this way with every headless check passing | `xvfb_run.sh --out shots -s res://addons/gohud/tests/gohud_shot.gd` | setup.md §6 |
| **`/gohud update`** — update the add-on in your project and this skill to the latest release | `/gohud update` | setup.md §7 |
