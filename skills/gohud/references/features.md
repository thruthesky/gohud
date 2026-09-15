# gohud features — the catalogue

Read this for `/gohud features` or "what can gohud do?". Present it grouped, with one line of code per
feature, and link the matching reference for depth. Version described: gohud 1.0.3 + Unreleased (`main`).

## Contents

1. [What gohud is](#1-what-gohud-is)
2. [Surfaces — windows, sheets, dialogs, forms](#2-surfaces)
3. [HUD and in-game widgets](#3-hud-and-in-game-widgets)
4. [GoStyle — the control factory](#4-gostyle--the-control-factory)
5. [Looks — presets, themes, skins, icons](#5-looks)
6. [Mobile, desktop, accessibility, languages](#6-mobile-desktop-accessibility-languages)
7. [Configuration, tooling and examples](#7-configuration-tooling-and-examples)

## 1. What gohud is

A HUD & UI kit for **Godot 4.6+**, pure GDScript, MIT. Drop the folder at `res://addons/gohud/` and every
class (`GoUi`, `GoStyle`, `GoSurface`, …) is usable at once — no autoload, no scene files, enabling the
editor plugin only adds conveniences. Every widget is built with `.new()` + `add_child()`.

- Homepage: https://thruthesky.github.io/gohud/ · Widgets: https://thruthesky.github.io/gohud/widgets.html
- Theming: https://thruthesky.github.io/gohud/theming.html · Source: https://github.com/thruthesky/gohud

## 2. Surfaces

| Feature | One line | Reference |
|---|---|---|
| `GoSurface` floating window — `CENTER`, `BOTTOM` or `ANCHOR` placement, fixed header/toolbar/footer, scrolling body, drag-to-resize, safe area and keyboard aware, Escape/Back closes only the topmost | `var s := GoSurface.new(); s.set_title("Settings"); s.close_requested.connect(s.queue_free)` | surfaces.md §1 |
| `GoSheet` bottom sheet on its own `CanvasLayer`, pages with back navigation, sticky search row and footer | `sheet.open("Inventory"); sheet.add_footer(GoStyle.button("Close", sheet.close))` | surfaces.md §2 |
| `GoDialogs` confirm/alert you `await`; `destructive` confirm button; vertical, horizontal or auto button layout | `if await dialogs.confirm("Delete save", "Cannot be undone.", "", "", "", {}, true):` | surfaces.md §3 |
| `GoForm` width-capped form that wraps every label, avoids the virtual keyboard and (with `avoid_hud`) the HUD | `form.avoid_hud = true` | surfaces.md §4 |
| `GoScroll` touch scrolling with the scrollbar tucked into card padding, RTL-aware | `var scroll := GoScroll.new()` | surfaces.md §5 |

## 3. HUD and in-game widgets

| Feature | One line | Reference |
|---|---|---|
| `GoHudAnchor` pins pieces to 9 safe-area spots, optional landscape spot, `reserve_space`, `avoid_peers` | `corner.spot = GoHudAnchor.Spot.TOP_LEFT` | hud.md §1 |
| `GoBar` HP/MP/XP bar, eased, value / fraction / percent readout, number abbreviation | `hp.set_values(320, 500)` | hud.md §2 |
| `GoSlot` quick slot: icon, quantity badge, cooldown, shortcut, shared touch areas | `slot.start_cooldown(5.0)` | hud.md §3 |
| `GoJoystick` virtual stick, `FIXED` / `FOLLOW` / `RELATIVE`, dead zone, normalized vector | `pad.moved.connect(func(v): player.direction = v)` | hud.md §4 |
| `GoIconButton` 36 dp visual, 48 dp touch, tooltip = accessible name | `GoStyle.icon_button(GoIconSet.CLOSE, close, -1, &"close")` | hud.md §5 |
| `GoNotice` snackbar that never takes input or focus | `notice.show_text("Saved", GoTheme.SUCCESS)` | hud.md §6 |
| `GoPromptCard` non-blocking question card (party invite, trade request) | `card.set_actions([{"text": "Accept", "action": ok, "primary": true}])` | hud.md §7 |
| `GoCoachMark` guided tour pointing at real controls; pressing the target advances | `tour.start([{"target": bag, "title": "Bag", "body": "…"}])` | hud.md §8 |

## 4. GoStyle — the control factory

Every control made one consistent way, sized from tokens, touch-safe, wrap-safe. Full signatures in style.md.

| Group | Functions |
|---|---|
| Structure | `column` `row` `wrap_row` `padding` `insets` `gap` `spacer` `divider` `responsive_grid` `aspect` `foldable` |
| Text | `label` `label_key` `section` `typography` |
| Buttons | `button` `button_key` `style_button` `icon_button` `list_button` `list_row` `apply_icon` — tones `NORMAL` `PRIMARY` `DANGER` `DANGER_SOLID` `BARE` `COMPACT` |
| Input | `line_edit` `textarea` `toggle` `checkbox` `slider` `picker` `select` `dropdown` `radio_group` `segmented` |
| Display | `card` `chip` `avatar` `skeleton` `alert` `table` `tabs` `breadcrumb` `progress` `tint_progress` `empty_state` |
| Surface pieces | `surface` `box` `floating` `disc` |
| Helpers | `form` `fit_words` `natural_width` `fit_content_height` `fade` `tooltip_node` `audit_compact_padding` |

## 5. Looks

| Feature | One line | Reference |
|---|---|---|
| Six presets swap theme + skin + icons together: `default_dark/light`, `scifi_dark/light`, `medieval_dark/light` | `GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)` | theming.md §1 |
| Tokens: 17 colours + 5 fill colours, 20 metrics, 8 styleboxes, 7 text roles, 15 type variations | `GoUi.color(GoTheme.ACCENT)` · `GoUi.metric(GoTheme.GAP)` | theming.md §2 |
| Per-project overrides without a new theme | `GoUi.config.color_overrides[GoTheme.ACCENT] = Color("#ff7a00")` | theming.md §3 |
| A new theme is one JSON file inheriting a built-in one; builder enforces WCAG contrast | `python3 addons/gohud/tools/new_theme.py kingdom --from medieval_dark` | theming.md §4 |
| Skins own code-drawn shapes (joystick, slots, coach ring, chips, alerts); 32 numeric dials | `class_name MySkin extends GoSkin` | theming.md §5 |
| Custom StyleBoxes: `GoStyleBoxCut` (chamfer, edge, glow), `GoStyleBoxBracket` (corner marks), `GoStyleBoxMedieval` (forged frame) | `var box := GoStyleBoxCut.new()` | theming.md §6 |
| Icons by name: 84 default + 16 engraved medieval (MIT, `DPITexture`); swap to your SVGs or an icon font, or override a few | `GoUi.icons().node(GoIconSet.SETTINGS, 20)` | platform.md §1 |

## 6. Mobile, desktop, accessibility, languages

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

## 7. Configuration, tooling and examples

| Feature | One line | Reference |
|---|---|---|
| One `GoConfig` resource (appearance, responsive, surface, feedback, localization, accessibility) that survives add-on updates | `GoUi.config = preload("res://ui/gohud_config.tres")` | setup.md §3 |
| Optional plugin: project settings for config + preset, `GoRuntime` autoload (breakpoints, dp scale, keyboard), translations | Project → Project Settings → Plugins → gohud | setup.md §2 |
| Subclass hooks `_make_scroll`, `_make_close_button`, `_make_surface`, `_should_pause` | `func _make_surface() -> GoSurface: return MySurface.new()` | surfaces.md §6 |
| Gallery, medieval example, 15-chapter demo tour with explore mode | `/gohud:preview demo --explore hud` | SKILL.md "Preview" |
| 438 headless checks, WCAG contrast checker, packaging gates | `bash addons/gohud/tools/check_all.sh` | setup.md §6 |
