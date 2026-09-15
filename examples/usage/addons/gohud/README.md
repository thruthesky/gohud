# gohud

**Documentation:** [English website](https://thruthesky.github.io/gohud/) · [한국어](https://thruthesky.github.io/gohud/ko/) · [Publishing guide](docs/README.md)

**A customizable HUD & UI kit for Godot 4.** Floating surfaces, bottom sheets, dialogs, forms,
snackbars, prompt cards, coach marks, HUD bars, quick slots and a virtual joystick — driven by one
theme and one swappable icon set, and aware of safe areas, virtual keyboards, RTL languages and touch.

> Drop it in and it works. Enabling the editor plugin only adds conveniences.

- **Swap the icons, keep the code.** Widgets ask for icons by name (`GoIconSet.CLOSE`). Point
  `GoConfig.icons` at your own SVG set or icon font and every widget follows — or override just a few.
- **One settings resource.** Theme, icons, sizes, breakpoints, surface behaviour, haptics, sound cues
  and strings live in a single `GoConfig` resource that survives add-on updates.
- **Mobile first, desktop ready.** 48 dp touch targets behind smaller visuals, safe-area and keyboard
  avoidance, portrait/landscape sizing, Android Back handling, focus rings only for keyboard users.
- **Uses current Godot features.** `DPITexture` icons stay sharp at any UI scale, `FoldableContainer`
  sections, `accessibility_name` for screen readers, `mouse_behavior_recursive` for input-transparent
  notices, `last_wrap_alignment` for flowing rows.
- **Godot 4.6 or newer.** Verified against 4.6 stable and 4.7 — the full test suite passes on both.
- **Pure GDScript.** No autoload required, no engine module, no GDExtension.
- **MIT**, including the 84 bundled icons.

## Requirements

Godot **4.6 or newer**. gohud relies on APIs introduced in 4.5 (`DPITexture`, `FoldableContainer`,
accessibility properties), and 4.6 is the supported floor: the full test suite is run against
**4.6 stable** and **4.7.2** on every change, and the gallery is screenshot-compared on both.

## Installation

### From the Asset Store or a release ZIP

Extract into your project root so that you get `res://addons/gohud/`. That is all you need.
Optionally enable **Project → Project Settings → Plugins → gohud** (see [Plugin](#plugin)).

### As a git submodule (to develop gohud alongside your game)

The repository root **is** the add-on folder, so it lands exactly where Godot expects it:

```bash
git submodule add <gohud-repository-url> addons/gohud
git submodule update --init
```

Edit files in place, commit and push **inside** `addons/gohud`, then commit the updated submodule
pointer in your game. Pin a tag (`git -C addons/gohud checkout v1.0.0`) for reproducible builds.

## Quick start

```gdscript
extends Node

func _ready() -> void:
	var dialogs := GoDialogs.new()
	add_child(dialogs)
	if await dialogs.confirm("Delete save", "This cannot be undone."):
		print("deleted")
```

A bottom sheet with a sticky search field and footer:

```gdscript
var sheet := GoSheet.new()
add_child(sheet)
sheet.open("Inventory")
sheet.toolbar().add_child(GoStyle.line_edit("Search…"))
sheet.toolbar().visible = true
for item in items:
	sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, item.name, _use.bind(item),
		Color.TRANSPARENT, item.description, false))
sheet.footer().add_child(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))
sheet.footer().visible = true
```

A HUD corner:

```gdscript
var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.TOP_LEFT
corner.landscape_spot = GoHudAnchor.Spot.TOP_RIGHT
add_child(corner)

var hp := GoBar.new()
hp.label_text = "HP"
hp.ink = GoUi.color(GoTheme.DANGER)
hp.custom_minimum_size.x = 180
corner.add_child(hp)
hp.set_values(320, 500)
```

If a scrolling screen shares the display with that HUD, tell the form to keep clear of it — otherwise the
content slides underneath and the two sets of text overlap:

```gdscript
form.avoid_hud = true                 # keeps clear of every visible GoHudAnchor
joystick_anchor.reserve_space = false # …except ones that only appear under a finger
```

Each HUD rectangle is avoided in whichever direction costs the least area, so a bar in the top-right
corner is stepped around **downwards** on a portrait phone and **sideways** in landscape.

The nine spots divide the screen but do not guarantee the pieces miss each other: a wide snackbar at
`TOP_CENTER` lands squarely on a health bar at `TOP_RIGHT`. Tell the transient one to step aside:

```gdscript
notice_anchor.avoid_peers = true      # settles below the fixed HUD, keeping its horizontal alignment
notice_anchor.reserve_space = false   # and does not push the page around while it is up
```

## Configuration

Create a **GoConfig** resource (FileSystem dock → *New Resource…* → `GoConfig`) and register it in
one of two ways:

- **Project Settings → gohud → Config → Resource** (the field appears once the plugin is enabled), or
- in code, before building UI: `GoUi.config = preload("res://ui/gohud_config.tres")`.

Leave a field empty or at its default to keep gohud's behaviour. Nothing needs to be filled in.

| Group | Fields |
|---|---|
| Appearance | `theme`, `icons`, `color_overrides`, `metric_overrides`, `base_font_size`, `shrink_type_on_mobile`, `token_fallback` |
| Responsive | `scale_enabled` (1 unit = 1 dp, **off by default**), `mobile_max_dp`, `tablet_max_dp`, `read_gain_*`, `desktop_ui_gain`, `form_max_width_*`, `respect_safe_area` |
| Surface | `surface_max_width`, `surface_max_height`, `surface_height_ratio`, `surface_max_height_ratio`, `surface_width_ratio_portrait/landscape`, `dismiss_on_scrim`, `surface_fade_in`, `fade_seconds`, `close_button_visual`, `suppress_pointer_focus_ring`, `close_on_back` |
| Feedback | `haptics_enabled`, `haptic_tap/light/medium_ms` and amplitudes, `sound_cues` |
| Localization | `text_keys`, `text_overrides`, `load_builtin_translations` |
| Accessibility | `min_touch_size`, `reduce_motion`, `autowrap_text` |

Assigning `theme` or `icons` re-lays out open widgets automatically. After changing any other field
from code, call `GoUi.refresh()`.

## Icons

### Using icons

```gdscript
# A ready-to-add Control: TextureRect for texture sets, Label for icon-font sets.
var mark := GoUi.icons().node(GoIconSet.SETTINGS, 20, GoUi.color(GoTheme.SECONDARY))

# Put an icon on any Button (texture sets use Button.icon, font sets add a child label).
GoStyle.apply_icon(save_button, GoIconSet.SAVE)

# Icon-only button: 36 dp visual, 48 dp hit area.
var close := GoStyle.icon_button(GoIconSet.CLOSE, _on_close)
```

The names you can rely on are the 84 constants on `GoIconSet`. Any other name works too, as long as
your set defines it.

### Replacing the whole set with your own SVGs

```gdscript
var mine := GoIconSet.new()
mine.set_name = "In-house icons"
mine.attribution = "Drawn by our art team"
mine.textures = {
	GoIconSet.CLOSE: preload("res://ui/icons/close.svg"),
	GoIconSet.SETTINGS: preload("res://ui/icons/gear.svg"),
}
GoUi.config.icons = mine
```

Draw icons in white and let gohud tint them. Import SVGs as **DPITexture** (Import dock →
*Import As* → DPITexture) so they re-rasterize crisply when the UI is scaled.

### Using an icon font

```gdscript
var font_icons := GoIconSet.new()
font_icons.font = preload("res://ui/fonts/my_icon_font.otf")
font_icons.codepoints = {GoIconSet.CLOSE: 0xf00d, GoIconSet.SETTINGS: 0xf013}
font_icons.font_size_ratio = 0.9
font_icons.fallback = GoUi.DEFAULT_ICONS   # names you did not map still draw
GoUi.config.icons = font_icons
```

### Overriding only a few icons

Set `fallback` to `GoUi.DEFAULT_ICONS` and define only the names you want to change. Lookups go
textures → codepoints → fallback.

> Commercial icon fonts are usually licensed for use inside your game, not for redistribution. Keep
> them in your project, not in a published fork of gohud. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Theming

All tokens live in the **`GoHud`** theme type.

| Kind | Tokens |
|---|---|
| Colors | `background`, `surface`, `surface_soft`, `surface_high`, `border`, `text`, `secondary`, `muted`, `accent`, `on_accent`, `success`, `warning`, `danger`, `info`, `scrim`, `shadow`, `track` |
| Constants (dp) | `touch`, `button_height`, `gap_tiny`, `gap_small`, `gap`, `gap_large`, `padding`, `padding_compact`, `radius_small`, `radius`, `radius_large`, `screen_margin`, `scroll_deadzone`, `scroll_edge`, `scrollbar_width`, `list_glyph`, `icon_size`, `notice_duration_ms` |
| Styles | `panel`, `card`, `hud`, `notice`, `popup`, `empty`, `focus`, `focus_soft` |

Type variations: `GoPanel`, `GoCard`, `GoButton`, `GoPrimaryButton`, `GoDangerButton`,
`GoBareButton`, `GoCompactButton`, `GoIconButton`, `GoListButton`, `GoTitleLabel`,
`GoSubtitleLabel`, `GoCaptionLabel`, `GoCompactLabel`, `GoMicroLabel`.

A theme that lacks the `GoHud` tokens still works — missing tokens are filled from the default theme
while `token_fallback` is on.

Read tokens in code with `GoUi.color(GoTheme.ACCENT)`, `GoUi.metric(GoTheme.GAP)` and
`GoUi.font_size(GoTheme.ROLE_CAPTION)`.

### Presets — swap colours *and* shape

A `Theme` can only restyle what the engine draws. Rounded corners are the only corners
`StyleBoxFlat` has, and the joystick, quick slots and coach mark are drawn by code, so a theme alone
can never change their shape. gohud therefore ships **presets**: a theme *and* a skin *and* an icon
set, picked as one unit.

| Preset | Look |
|---|---|
| `default_dark` | The original gohud: rounded corners, soft blue accent |
| `default_light` | The same shapes on a light palette |
| `scifi_dark` | Chamfered corners, cyan neon edges and glow, hexagonal joystick, targeting brackets |
| `scifi_light` | The same angular shapes in a bright blueprint palette |

```gdscript
GoUi.use_preset(GoThemePresets.SCIFI_DARK)     # one line — theme, skin and icons together
```

**Adding a theme is one file.** Inherit a built-in theme and write only what changes:

```bash
python3 addons/gohud/tools/new_theme.py neon --from scifi_dark --title "Neon"
python3 addons/gohud/tools/make_theme.py neon      # theme .tres + control artwork
godot --headless --path . --import                  # import the new artwork once
```

`themes/palettes/neon.json` spells out every inherited value, so it doubles as the list of what you can
change. `themes/presets/` is scanned, so the new preset appears in the picker with no code change. Skin numbers (slot border, badge padding, joystick ring, sci-fi chamfers) are dials in the JSON's `skin.dials` — no skin code is touched; every dial with its default and meaning is listed on the site's [theming page](docs/www/theming.html), generated from the scripts. Text,
borders and the accent are pushed to readable positions by the builder, so a colour-only change still
passes the contrast checks (`tools/check_scaffold.sh` guards this).

```gdscript
```

Or set **Project Settings → Gohud → Theme → Preset**, or fill `preset` on your `GoConfig`. Explicit
`theme`, `skin` and `icons` fields still win over the preset, so you can take a preset and override
just one of them.

`GoSkin` owns the shapes a theme cannot reach — the joystick, quick slot faces, the coach-mark ring,
chips, skeletons, alerts and segmented controls. Subclass it and override only what you want to
change; everything you leave alone keeps the default look.

```gdscript
class_name MySkin extends GoSkin

func slot_box(accent: Color, lit: bool) -> StyleBox:
    var box := GoStyleBoxCut.new()
    box.bg_color = accent
    return box
```

Two custom `StyleBox` classes are available for shapes `StyleBoxFlat` cannot make:
`GoStyleBoxCut` (chamfered corners, an accent edge, outer glow) and `GoStyleBoxBracket`
(corner marks only). Both serialise into a `Theme` resource like any other StyleBox.

`GoStyle.surface()` returns whatever shape the skin produced. `GoStyle.box()`, `floating()` and
`disc()` keep their promise of returning a `StyleBoxFlat`, so existing calling code that tweaks
`bg_color` or `corner_radius` still compiles — but a custom shape cannot survive that path.

### Making your own

Add a palette and a shape to `tools/make_theme.py`, run it to generate the `.tres` and the
per-theme control SVGs, then point a `GoThemePreset` resource at the result and register it:

```gdscript
GoThemePresets.register(preload("res://ui/my_preset.tres"))
```

🛑 After generating new SVGs run `godot --headless --path . --import` once — until then the new
theme cannot be loaded.

## Widgets

| Class | Base | Purpose |
|---|---|---|
| `GoSurface` | Control | Floating card shell with `CENTER`, `BOTTOM` and `ANCHOR` placement; fixed header, toolbar and footer; scrolling body; Escape/Back closes only the topmost surface; focus restore; drag-to-resize |
| `GoSheet` | CanvasLayer | Bottom-sheet pages with back navigation, sticky toolbar and footer |
| `GoDialogs` | Node | `await confirm()` and `await alert()`, with plain-text and translation-key variants |
| `GoForm` | MarginContainer | Forms that cap their width per breakpoint, avoid the virtual keyboard and guarantee label wrapping |
| `GoScroll` | ScrollContainer | Touch-friendly scrolling; the scrollbar tucks into the card padding; RTL-aware |
| `GoNotice` | PanelContainer | Snackbar that never takes input or focus |
| `GoPromptCard` | PanelContainer | Non-blocking question card; keeps pressed buttons alive across refreshes |
| `GoCoachMark` | Control | Guided tour that points at real controls; pressing the target advances |
| `GoHudAnchor` | Control | Pins HUD pieces to one of nine safe-area spots, with an optional landscape spot |
| `GoBar` | Control | HP/MP/XP bars with value, fraction or percent readouts and eased changes |
| `GoSlot` | Button | Quick slot with icon, quantity, cooldown and shortcut on a single face; shared hit areas in tight rows |
| `GoJoystick` | Control | Virtual joystick in fixed, follow or relative mode, with dead zone |
| `GoIconButton` | Button | Icon-only button: small visual, full-size hit area, accessible name |
| `GoStyle` | factory | Buttons, labels, list rows, inputs, chips, cards, wrap rows, responsive grids, foldable sections, empty states |
| `GoUi` | static | Current config, theme, icons, colors, metrics and strings |
| `GoSafeArea` | Control / static | Usable rectangle excluding notches, rounded corners and the keyboard |
| `GoScale` | static | Breakpoint and dp math |
| `GoFeedback` | static | Sound and haptic routing |
| `GoBackPolicy` | static | Shared ownership of Android Back |

### Subclass hooks

Every widget that builds child widgets does so through an overridable method, so a host that
subclasses gohud types (its own type hints, its own close glyph, its own modal system) gets those
subclasses *inside* the widgets without copying code:

| Hook | Widget | Default |
|---|---|---|
| `_make_scroll()` | `GoCoachMark`, `GoSurface` | `GoScroll.new()` |
| `_make_close_button()` | `GoPromptCard`, `GoSurface` | `GoIconButton.new()` |
| `_make_surface()` | `GoSheet` (`GoDialogs` next) | `GoSurface.new()` |
| `_should_pause()` | `GoCoachMark` | `GoSurface.is_any_open()` — hide the card while a modal is open |
| `GoScroll.as_horizontal(node)` | static | the configuration step of `horizontal()`, for `static func horizontal() -> MyScroll` |

`GoIconButton.native_texture_size = true` draws a texture icon at its own pixel size instead of
scaling it to 58 % of `visual_size`.

## Plugin

Enabling the plugin does three things, all optional:

1. adds the **gohud → Config → Resource** project setting;
2. registers the **`GoRuntime`** autoload, which emits `breakpoint_changed`, `viewport_resized` and
   `keyboard_changed`, shrinks body text one step on phones, and — only when `scale_enabled` is on —
   sets `content_scale_factor` so one UI unit equals one dp;
3. adds the built-in translations to the project's translation list.

Without the plugin every widget still works; they poll the keyboard themselves and use the theme's
font sizes unchanged.

## Responsive behaviour

- Breakpoints use the screen's **short side in dp**: up to 576 is mobile, up to 991 is tablet,
  anything larger is desktop. Both limits are configurable.
- Surfaces cap their height at 72 % of the usable area by default, so a floating window always
  reads as floating; in landscape they use a narrower share of the width.
- Every widget measures against `GoSafeArea.usable_rect()`, which excludes notches and gesture bars
  on Android and iOS.
- `GoStyle.responsive_grid(min_cell_width)` recomputes its column count whenever its width changes.

## Localization

gohud's own 16 strings ship in **21 languages** (`i18n/gohud.csv`): English, Korean, Japanese,
Chinese (Simplified `zh` and Traditional `zh_TW`), Spanish, Portuguese, German, French, Italian,
Dutch, Polish, Russian, Ukrainian, Turkish, Vietnamese, Indonesian, Thai, Hindi, Arabic and Hebrew.
They load automatically; disable that with `load_builtin_translations`. Numbers, joysticks and scroll
rails stay left-to-right in RTL languages (`ar`, `he`) while content follows the application locale.

**Every glyph on screen is yours to change.** Widgets never hard-code display text — there is not a
single `label.text = "Retry"` anywhere in `widgets/`, `core/` or `services/`, and a test fails the
build if one appears. Text reaches the screen through exactly two doors:

| Where it comes from | How you change it |
|---|---|
| You pass it in — dialog titles and bodies, button labels, form fields, list rows, empty states | Just pass your own string or translation key |
| gohud supplies it — the 16 named strings below | `text_overrides` (literal) or `text_keys` (your own translation keys) |

```gdscript
# Your wording, no translation table involved
GoUi.config.text_overrides = {&"confirm": "Yes", &"cancel": "No"}

# Or point the names at keys your project already has
GoUi.config.text_keys[&"confirm"] = "MY_DIALOG_YES"
```

The 16 names: `close` `back` `next` `done` `skip` `confirm` `cancel` `search` `loading` `empty`
`retry`, plus five **format strings** — `bar_fraction` (`{value} / {max}`), `bar_percent`
(`{percent}%`), `coach_progress` (`{step} / {total}`), `slot_quantity` (`×{count}`) and
`slot_unknown` (`…`).

Formats are translatable because punctuation is not universal: Turkish puts the percent sign in
*front* (`%50`), French separates it (`50 %`). Placeholders use `{name}`, so a translation that
drops one still renders instead of crashing.

Digit grouping is a hook rather than a format string, because Korean, Japanese and Chinese break at
10,000 and 100,000,000 rather than at thousands — the arithmetic differs, not just the text:

```gdscript
GoUi.config.number_formatter = func(amount: float) -> String:
    if absf(amount) >= 10_000.0: return "%.1f만" % (amount / 10_000.0)
    return str(roundi(amount))
```

> **gohud ships no font.** Thai, Arabic, Hebrew, Hindi and CJK need glyph coverage from your own
> theme font — a Latin-only font draws them as empty boxes and raises no error. Traditional Chinese
> needs its own coverage too: a Simplified subset does not contain those forms.

## Sound and haptics

gohud ships no audio. Route its cues to your audio system once:

```gdscript
GoFeedback.sound_handler = func(cue: String) -> void: $Audio.play(cue)
```

The cue names come from `GoConfig.sound_cues` (`ui_open`, `ui_click`, …) so you can match your own
sound files without touching code. Vibration runs only on Android and iOS, in three strengths.

## Accessibility

- Hit areas never drop below `min_touch_size` (48 dp), even when the visible control is smaller.
- Icon-only buttons expose their tooltip text through `accessibility_name`.
- `reduce_motion` turns off fades and pulsing highlights.
- Focus rings appear for keyboard and gamepad users, not after a tap or click.

## Verified

On **Godot 4.7.2** (macOS, Apple Silicon, Compatibility renderer):

| Check | Result |
|---|---|
| Headless suite (147 checks) inside a host project | pass |
| Same suite in an **empty project**, no autoloads | pass |
| Same suite with the `GoRuntime` autoload enabled | pass |
| The release ZIP unpacked into an empty project and tested | pass |
| Web export of that empty project | pass |
| Gallery rendered and inspected at 390×844, 844×390 and 1280×800 | pass |

**Not verified yet:** physical Android or iOS devices, the Forward+ and Mobile renderers, and Godot
versions other than 4.7.2. The safe-area and haptics code paths only activate on handheld platforms,
so they are exercised by the test suite but not on real hardware.

## Demo

Run `examples/demo/project.godot`. **Start demo** plays a guided tour: a visible cursor demonstrates
15 chapters using real input — buttons, fields, menus, scrolling, HUDs, dialogs, forms and more.
**Explore widgets**, or any row in the sidebar, opens a single widget for you to try by hand, with
a **Play this widget** button that lets the bot demonstrate just that one.
All demo text is English. Large desktop windows enlarge the UI along with the canvas.

```bash
bash examples/demo/run.sh
bash examples/demo/run.sh --record /tmp/gohud-demo.avi # 1080p / 60 fps, complete tour
bash examples/demo/run.sh --shot /tmp/gohud-start.png
bash examples/demo/run.sh -- --explore=surfaces                 # open the app on one widget
```

**C** toggles Cinema mode, **F11** toggles fullscreen, **Space** pauses, arrows change chapters,
and **Escape** returns to Start. While exploring, the arrows move between widgets and Space plays the
current one. Cinema mode hides the side panels and offers a countdown.
See [the demo guide](examples/demo/README.md) for recording, testing and ZIP setup.

## Gallery

Open `res://addons/gohud/examples/gallery/gallery.tscn` and run it (F6). It needs no server, autoload or
project setup, and shows every widget, both themes and the full icon set.

## Development

```bash
bash addons/gohud/tools/run_tests.sh             # headless checks inside the current project
bash addons/gohud/tools/new_project_check.sh     # install into an empty project, test, optionally --export
bash addons/gohud/tools/package.sh              # patch +1; builds/<version>/gohud-<version>.zip
bash addons/gohud/tools/package.sh --increase-minor-version # minor +1, patch resets to 0
python3 addons/gohud/tools/check_package.py     # packaging regression checks in temporary copies
python3 addons/gohud/tools/make_theme.py         # regenerate both themes from the palette
python3 addons/gohud/tools/make_icons.py         # regenerate the default icon SVGs
```

`package.sh` requires Python 3 and automatically increments the patch version on each successful
run (for example, `1.2.9` → `1.2.10`). `--increase-minor-version` instead produces `1.3.0`.
`--out DIR` changes the output folder and still increments the version. Versions must use the
stable `major.minor.patch` format.

The script updates `plugin.cfg`, `GoUi.VERSION` and `CHANGELOG.md` together. Pending `Unreleased`
notes move into a dated entry for the new version, leaving an empty `Unreleased` section.
Version files remain unchanged if packaging fails, and existing release ZIPs are never overwritten.
Version mismatches, missing documents and references outside `addons/gohud/` still fail validation.
Packaging checks in `check_all.sh` use temporary copies and do not increment your working version.

## License

MIT — see [LICENSE](LICENSE). The bundled icons were drawn for gohud and are MIT as well; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
