# gohud

**Homepage:** [https://thruthesky.github.io/gohud/](https://thruthesky.github.io/gohud/)

[Theming guide](https://thruthesky.github.io/gohud/theming.html) ·
[Widget reference](https://thruthesky.github.io/gohud/widgets.html) ·
[한국어 사이트](https://thruthesky.github.io/gohud/ko/) ·
[한국어 README](README.ko.md) ·
[Changelog](CHANGELOG.md) ·
[GitHub](https://github.com/thruthesky/gohud)

**A customizable HUD & UI kit for Godot 4.6+.** Floating surfaces, bottom sheets, dialogs, forms,
snackbars, prompt cards, coach marks, HUD bars, quick slots and a virtual joystick — driven by one
theme and one swappable icon set, and aware of safe areas, virtual keyboards, RTL languages and touch.
Six built-in presets change colours **and** shapes in one line: default, sci-fi and medieval, each in
dark and light.

<p>
  <img src="https://thruthesky.github.io/gohud/img/preset-default-dark.png" alt="The gohud gallery with the default_dark preset" width="250">
  <img src="https://thruthesky.github.io/gohud/img/preset-scifi-dark.png" alt="The same gallery with the scifi_dark preset" width="250">
</p>

> Drop it in and it works. Enabling the editor plugin only adds conveniences.

**Version 1.0.1.** The medieval presets and the balanced list rows are on `main` and listed under
*Unreleased* in the [changelog](CHANGELOG.md); the next `tools/package.sh` run puts them in a release.

- **Six presets, one line.** `GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)` swaps theme, skin and
  icons together — rounded default panels, chamfered sci-fi panels with neon glow, or forged medieval
  frames with engraved icons.
- **Swap the icons, keep the code.** Widgets ask for icons by name (`GoIconSet.CLOSE`). Point
  `GoConfig.icons` at your own SVG set or icon font and every widget follows — or override just a few.
- **Themes are data.** `new_theme.py` writes one JSON file that inherits a built-in theme. The builder
  generates the theme, its control artwork and skin dials, and pushes text, borders and the accent until
  they pass WCAG contrast checks.
- **One settings resource.** Preset, theme, icons, sizes, breakpoints, surface behaviour, haptics, sound
  cues and strings live in a single `GoConfig` resource that survives add-on updates.
- **Mobile first, desktop ready.** 48 dp touch targets behind smaller visuals, safe-area and keyboard
  avoidance, portrait/landscape sizing, Android Back handling, focus rings only for keyboard users.
- **Uses current Godot features.** `DPITexture` icons stay sharp at any UI scale, `FoldableContainer`
  sections, `accessibility_name` for screen readers, `mouse_behavior_recursive` for input-transparent
  notices, `last_wrap_alignment` for flowing rows.
- **Pure GDScript.** No autoload required, no engine module, no GDExtension.
- **MIT** code and artwork, including 84 default icons and 16 engraved medieval icons. The medieval
  headings use the bundled Cinzel font under the SIL Open Font License 1.1.

## Requirements

Godot **4.6 or newer**. gohud relies on APIs introduced in 4.5 (`DPITexture`, `FoldableContainer`,
accessibility properties), so older engines fail while parsing. 4.6 is the supported floor and is
recorded in `GoUi.MIN_ENGINE`. `tools/check_all.sh` runs the suite on 4.7 and — when `GODOT_46`
points at a 4.6 binary — on 4.6 as well.

## Installation

### From the Asset Store or a release ZIP

Extract into your project root so that you get `res://addons/gohud/`. That is all you need.
Optionally enable **Project → Project Settings → Plugins → gohud** (see [Plugin](#plugin)).

### As a git submodule (to develop gohud alongside your game)

The repository root **is** the add-on folder, so it lands exactly where Godot expects it:

```bash
git submodule add https://github.com/thruthesky/gohud.git addons/gohud
git submodule update --init
```

Edit files in place, commit and push **inside** `addons/gohud`, then commit the updated submodule
pointer in your game. For reproducible builds, pin a tag or commit
(`git -C addons/gohud checkout v1.0.0`).

## Quick start

```gdscript
extends Node

func _ready() -> void:
	var dialogs := GoDialogs.new()
	add_child(dialogs)
	if await dialogs.confirm("Delete save", "This cannot be undone."):
		print("deleted")
```

For an irreversible action, pass `destructive = true` (the last argument of `confirm()`) and the
confirm button is drawn as a filled danger button.

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

Rows with a description get equal top and bottom padding, and the title/description pair stays
vertically centred beside the icon even when the row grows taller.

A HUD corner:

```gdscript
var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.TOP_LEFT
corner.landscape_spot = GoHudAnchor.Spot.TOP_RIGHT
add_child(corner)

var hp := GoBar.new()
hp.label_text = "HP"
hp.ink = GoUi.color(GoTheme.DANGER_FILL)   # fill-only token: vivid on light themes too
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

## Presets — colours *and* shape

A `Theme` can only restyle what the engine draws. Rounded corners are the only corners
`StyleBoxFlat` has, and the joystick, quick slots and coach mark are drawn by code, so a theme alone
can never change their shape. gohud therefore ships **presets**: a theme, a skin and an icon set,
picked as one unit.

```gdscript
GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)   # before building UI — theme, skin and icons together
```

| Preset | Look | Skin |
|---|---|---|
| `default_dark` | The original gohud: rounded corners, soft blue accent, graded shadows | `GoSkin` |
| `default_light` | The same shapes on a light palette | `GoSkin` |
| `scifi_dark` | Chamfered corners, cyan neon edges and glow, hexagonal joystick, targeting-bracket focus | `GoSkinSciFi` |
| `scifi_light` | The same angular shapes in a bright blueprint palette | `GoSkinSciFi` |
| `medieval_dark` | Dark iron and leather, antique-gold frames, rivets, engraved icons, Cinzel headings | `GoSkinMedieval` |
| `medieval_light` | Parchment, ink and bronze with the same forged frames | `GoSkinMedieval` |

Pick one from **Project Settings → gohud → Theme → Preset**, or fill `preset` on your `GoConfig`.
Explicit `theme`, `skin` and `icons` fields still win over the preset, so you can take a preset and
override just one of them.

### Medieval

<img src="https://thruthesky.github.io/gohud/img/medieval-dark.png" alt="medieval_dark: a character sheet, satchel and quest journal built from the standard widgets" width="640">

Run [the medieval example](examples/medieval/medieval.tscn) with F6 to explore a character sheet, a
satchel of quick slots and a quest journal, all built from the standard widgets. Its buttons switch
between iron and parchment and open item details in a `GoDialogs` alert.

- Menu panels carry a rivet and a small corner ornament; the always-visible HUD panel keeps a quiet edge.
- Health, mana and stamina read as red, blue and olive fills.
- The engraved icon set redraws `bag`, `book`, `box`, `coin`, `crown`, `flag`, `heart`, `key`, `map`,
  `potion`, `shield`, `star`, `sword` and `user`, and adds `scroll` and `seal`. Every other name, such
  as `close`, falls back to the default set.
- Only titles and subtitles use the bundled Cinzel font; body text keeps your theme's font. Cinzel
  covers Latin script, so localized headings in other scripts need a font of your own (`shape.fonts`).

### Your own theme in one file

Inherit a built-in theme and write only what changes:

```bash
python3 addons/gohud/tools/new_theme.py kingdom --from medieval_dark --title "Kingdom"
python3 addons/gohud/tools/make_theme.py kingdom   # theme .tres, control artwork and skin resource
godot --headless --path . --import                 # import the new artwork once
```

```gdscript
GoUi.use_preset(&"kingdom")   # themes/presets/ is scanned, so it also appears in the preset picker
```

`themes/palettes/kingdom.json` spells out every inherited value, so it doubles as the list of what you
can change. Delete a key to keep the parent's value.

| Block | Controls |
|---|---|
| `from` | The parent: `dark`, `light`, `scifi_dark`, `medieval_dark`, … or another JSON theme. Inheritance cycles fail explicitly. |
| `palette` | Background, three surfaces, border, three text tones, accent, four status colours, scrim, shadow, track, and `*_vivid` fill colours. Text, borders and the accent are pushed to readable contrast by the builder. |
| `shape` | `kind` (`flat`, `cut`, `medieval`) and sizes (`radius`, `radius_small`, `radius_large`, `gap`, `gap_small`, `gap_large`, `padding`, `button_height`, `button_padding`). `cut` adds `cut_ratio`, `cut_max`, `corners`, `glow`, `edge`; `medieval` adds `material` (0 iron, 1 leather, 2 parchment), `grain_alpha`, `ornament_scale`, `bevel_strength` and `fonts` (`title`, `subtitle`, `caption`, `body`, `button` → addon-local `res://` font paths). |
| `skin` | `base` (`default`, `scifi`, `medieval`) and `dials` — 32 numbers such as slot borders, badge padding, joystick rings, chamfers and `slot_rivets`, written to `themes/skins/gohud_skin_<id>.tres` without touching skin code. |
| `icons` | The icon set resource. Kept from a JSON parent when omitted. |
| `dark`, `title` | How the picker lists it. |

Every dial with its default and meaning is listed on the
[theming page](https://thruthesky.github.io/gohud/theming.html#own), generated from the skin
scripts. `tools/check_scaffold.sh` builds a throwaway theme on every run, changes its accent and radius,
and checks generation, token propagation and contrast. Use `new_theme.py --new-skin` only when the
drawings themselves must change, and `new_theme.py --remove kingdom` to delete what it created.

A preset kept in your own project rather than inside the add-on is registered in code:

```gdscript
GoThemePresets.register(preload("res://ui/my_preset.tres"))
```

🛑 After generating new SVGs run `godot --headless --path . --import` once — until then the new
theme cannot be loaded.

## Configuration

Create a **GoConfig** resource (FileSystem dock → *New Resource…* → `GoConfig`) and register it in
one of two ways:

- **Project Settings → gohud → Config → Resource** (the field appears once the plugin is enabled), or
- in code, before building UI: `GoUi.config = preload("res://ui/gohud_config.tres")`.

Leave a field empty or at its default to keep gohud's behaviour. Nothing needs to be filled in.

| Group | Fields |
|---|---|
| Appearance | `preset`, `theme`, `token_fallback`, `skin`, `icons`, `color_overrides`, `metric_overrides`, `base_font_size`, `shrink_type_on_mobile` |
| Responsive | `scale_enabled` (1 unit = 1 dp, **off by default**), `mobile_max_dp`, `tablet_max_dp`, `read_gain_*`, `desktop_ui_gain`, `form_max_width_*`, `respect_safe_area` |
| Surface | `surface_max_width`, `surface_max_height`, `surface_height_ratio`, `surface_max_height_ratio`, `surface_width_ratio_portrait/landscape`, **`container_alpha`**, **`container_alpha_overrides`**, `dismiss_on_scrim`, `surface_fade_in`, `fade_seconds`, `close_button_visual`, `suppress_pointer_focus_ring`, `close_on_back` |
| Feedback | `haptics_enabled`, `haptic_tap/light/medium_ms` and amplitudes, `sound_cues` |
| Localization | `text_keys`, `text_overrides`, `number_formatter`, `load_builtin_translations` |
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

# Icon-only button: 36 dp visual, 48 dp hit area. The tooltip key also becomes the accessible name.
var close := GoStyle.icon_button(GoIconSet.CLOSE, _on_close, -1, "close")
```

The names you can rely on are the 84 constants on `GoIconSet`. Any other name works too, as long as
your set defines it — the medieval set adds `scroll` and `seal` this way.

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
textures → codepoints → fallback. `icons/gohud_icons_medieval.tres` is a working example: 16 textures
over the default set.

> Commercial icon fonts are usually licensed for use inside your game, not for redistribution. Keep
> them in your project, not in a published fork of gohud. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Theming

All tokens live in the **`GoHud`** theme type.

| Kind | Tokens |
|---|---|
| Colors | `background`, `surface`, `surface_soft`, `surface_high`, `border`, `text`, `secondary`, `muted`, `accent`, `on_accent`, `success`, `warning`, `danger`, `info`, `scrim`, `shadow`, `track` |
| Fill colors | `success_fill`, `warning_fill`, `danger_fill`, `info_fill`, `accent_fill` — for bars and other large areas; a theme without them falls back to the base name |
| Constants (dp) | `touch`, `button_height`, `gap_tiny`, `gap_small`, `gap`, `gap_large`, `padding`, `padding_compact`, `compact_padding_x`, `compact_padding_y`, `radius_small`, `radius`, `radius_large`, `screen_margin`, `scroll_deadzone`, `scroll_edge`, `scrollbar_width`, `list_glyph`, `icon_size`, `notice_duration_ms` |
| Panel opacity (%) | `panel_alpha`, `card_alpha`, `hud_alpha`, `notice_alpha`, `popup_alpha` — how solid a container's face is. 80 by default (100 for popup menus); a theme without them falls back to 100 |
| Styles | `panel`, `card`, `hud`, `notice`, `popup`, `empty`, `focus`, `focus_soft` |
| Text roles | `micro`, `compact`, `caption`, `body`, `button`, `subtitle`, `title` |

Type variations: `GoPanel`, `GoCard`, `GoButton`, `GoPrimaryButton`, `GoDangerButton`,
`GoDangerSolidButton`, `GoBareButton`, `GoCompactButton`, `GoIconButton`, `GoListButton`,
`GoTitleLabel`, `GoSubtitleLabel`, `GoCaptionLabel`, `GoCompactLabel`, `GoMicroLabel`.

A theme that lacks the `GoHud` tokens still works — missing tokens are filled from the default theme
while `token_fallback` is on.

Read tokens in code with `GoUi.color(GoTheme.ACCENT)`, `GoUi.metric(GoTheme.GAP)`,
`GoUi.font_size(GoTheme.ROLE_CAPTION)` and `GoUi.surface_alpha(GoTheme.BOX_PANEL)` — the last one
returns a **ratio** (0.0–1.0), not the percentage stored in the theme.

### Panel opacity — the game stays visible behind a container

**Popups, dialogs, sheets, cards and HUD panels are 80% opaque by default.** The remaining 20% lets the
world through: the fight carries on behind a confirm dialog, the map shows under an inventory sheet. In a
game this is not decoration — it is **what keeps the player oriented**. A fully solid panel erases where
they were standing the moment a window opens.

🛑 **Only the face thins out.** Text, icons, buttons, badges and quick slots stay sharp. Fading the content
along with the panel produces UI that cannot be read, and that is not a transparent window — it is a bug.
Borders and shadows are also left alone: a translucent panel reads as glass only while its outline is
crisp, and a faded outline leaves you unable to tell where the panel ends.

#### Five layers — the most specific wins

| Order | Where | Unit | Use it for |
|---|---|---|---|
| ① | the argument or field at that call — `surface.alpha`, `sheet.alpha`, `GoStyle.card(…, alpha)` | ratio `0.0–1.0` | **this one window** |
| ② | `GoConfig.container_alpha_overrides[kind]` | ratio `0.0–1.0` | **one kind** across the project |
| ③ | `GoConfig.metric_overrides[<kind>_alpha]` | **percent** `0–100` | projects that keep every measurement in one place |
| ④ | `GoConfig.container_alpha` | ratio `0.0–1.0` | **every panel** in the project at once |
| ⑤ | the theme's `GoHud/constants/<kind>_alpha` | **percent** `0–100` | what the look itself decides — **the source of truth** |

With none of them set the value is 1.0 (solid) — so a theme that predates these tokens, or someone else's
theme, draws exactly as it did before.

🔑 **Everywhere you handle opacity, it is a ratio (0.0–1.0)** — every widget's `alpha` field (including the
ones exported to the inspector), the `GoStyle` arguments, both `GoConfig` fields and what
`GoUi.surface_alpha()` returns. That matches `Color.a` and `modulate.a`. A negative value means "not set"
and falls through to the layer below.

🛑 **Percentages exist in exactly one layer: the theme's constants**, because a `Theme` constant cannot hold
a float. So the theme's `<kind>_alpha` and **the channel that overrides it** (`metric_overrides` — same
names, same integer type as the theme's measurements) are written as `80`. Everything else is `0.8`.

```gdscript
# ① One window only — a confirm dialog that must not hide the fight behind it
surface.alpha = 0.6
sheet.alpha = 0.7
dialogs.alpha = 0.9
drawer.alpha = 0.7
GoPopover.open(slot, body, {"alpha": 0.9})
var glass := GoStyle.card(Color.TRANSPARENT, -1.0, -1.0, -1.0, 0.5)

# ② Per kind — keep the HUD nearly solid, because its text sits straight over the world
GoUi.config.container_alpha_overrides = {
    GoTheme.BOX_PANEL: 0.7,   # dialogs and sheets can breathe
    GoTheme.BOX_HUD: 0.95,
}
GoUi.refresh()                # 🛑 call this to redraw widgets that are already open

# ③ The whole project — busy worlds want their panels back to solid
GoUi.config.container_alpha = 1.0
GoUi.refresh()

# ④ In the theme (the source of truth) — or in a palette JSON, where the generator
#    carries it down to the token:  GoHud/constants/panel_alpha = 70
```

#### What follows the value, and what does not

| Follows it — containers | Does not — things you press, and markers |
|---|---|
| `GoSurface` (the one shell behind dialogs, sheets and dropdowns) · `GoSheet` · `GoDialogs` · `GoDrawer` · `GoPopover` · `GoNotice` · `GoSnackbar` · `GoPromptCard` · `GoCoachMark` · `GoConsole` | every button · `GoSlot` (quick slots) · `GoBadge` · segmented controls · choice cells · chips · discs and avatars |
| `GoStyle.card()` · `hud_panel()` · `overlay_panel()` · `alert()` · `plate()` · `edge_card_panel()` · `style_notice_panel()` · `floating()` · `box()` · `surface()` | all text and icons |

- **Popup menus (`PopupMenu`) stay solid by default** (`popup_alpha` 100). The engine may put one in its own
  **window**, and there the OS does not composite it with the game — translucency comes out black instead of
  see-through. Projects that embed their subwindows (`gui_embed_subwindows`) can lower it.
- `GoStyle.plate()` keeps a fill colour you pass **exactly as given** — multiplying panel opacity into
  `Color(ink, 0.14)`, which already states its alpha, would cut the caller's intent twice.
- `GoStyle.floating(…, opaque = true)` ignores the value: filling the face solid is the whole point of that
  argument, for places where the world would otherwise show through the text.

#### Panels gohud did not build

```gdscript
var frame := PanelContainer.new()
add_child(frame)                   # 🛑 after it enters the tree — it reads the theme it inherits
GoStyle.fade_panel(frame)          # whatever theme and config decided
GoStyle.fade_panel(frame, 0.6)     # this panel at 60%
GoStyle.fade_panel(frame, 1.0)     # back to solid (the override is removed)
```

Calling it repeatedly fades the panel only once — the original face is recorded in a meta entry and every
call recomputes from that. After swapping themes, drop that memory with `GoStyle.forget_face(node)` so the
next call picks up the new theme's face.

#### Custom StyleBoxes behave the same

Faces drawn by hand — the cut-corner panel (`GoStyleBoxCut`), the forged frame (`GoStyleBoxMedieval`) —
fade their background only. Glow, rivets, corner engraving and bevels keep their strength; the medieval
face's grain and bevel were always proportional to the background alpha, so they thin out with the panel.

### Skins and custom StyleBoxes

`GoSkin` owns the shapes a theme cannot reach — the joystick, quick slot faces, the coach-mark ring,
chips, skeletons, alerts, segmented controls, choice-grid cells and colour swatches, dividers and section headings. `GoSkinSciFi` and
`GoSkinMedieval` ship as subclasses. Subclass one and override only what you want to change;
everything you leave alone keeps its look.

```gdscript
class_name MySkin extends GoSkin

func slot_box(accent: Color, lit: bool) -> StyleBox:
    var box := GoStyleBoxCut.new()
    box.bg_color = accent
    return box
```

Three custom `StyleBox` classes cover shapes `StyleBoxFlat` cannot make. All of them serialise into a
`Theme` resource like any other StyleBox.

| Class | Draws |
|---|---|
| `GoStyleBoxCut` | Chamfered corners, one thickened accent edge, an outer glow |
| `GoStyleBoxBracket` | Corner marks only, leaving the content unenclosed |
| `GoStyleBoxMedieval` | A forged frame with rivets, corner engraving, a bevel highlight and material grain |

`GoStyle.surface()` returns whatever shape the skin produced. `GoStyle.box()`, `floating()` and
`disc()` keep their promise of returning a `StyleBoxFlat`, so existing calling code that tweaks
`bg_color` or `corner_radius` still compiles — but a custom shape cannot survive that path.

### Contrast is measured, not eyeballed

`python3 addons/gohud/tools/check_contrast.py` measures every theme against WCAG: body text 4.5:1,
large text, accent borders, icons and focus rings 3:1, decorative borders 2:1, adjacent surfaces
1.12:1. Button labels are measured on the state panel they sit on, and translucent panels are
composited over pure white and pure black first, since a HUD can land on any scene. Colours a skin
mixes while running (chips, slots) are measured inside Godot by the suite's `skin contrast` section.

## Widgets

| Class | Base | Purpose |
|---|---|---|
| `GoSurface` | Control | Floating card shell with `CENTER`, `BOTTOM` and `ANCHOR` placement; fixed header, toolbar and footer; scrolling body; Escape/Back closes only the topmost surface; focus restore; drag-to-resize |
| `GoSheet` | CanvasLayer | Bottom-sheet pages with back navigation, sticky toolbar and footer |
| `GoDialogs` | Node | `await confirm()` and `await alert()`, with plain-text and translation-key variants; `destructive` draws a filled danger confirm button; `action_layout` stacks the buttons, puts them on one row or picks automatically |
| `GoForm` | MarginContainer | Forms that cap their width per breakpoint, avoid the virtual keyboard (and, with `avoid_hud`, floating HUD pieces) and guarantee label wrapping |
| `GoScroll` | ScrollContainer | Touch-friendly scrolling; the scrollbar tucks into the card padding; RTL-aware |
| `GoNotice` | PanelContainer | Snackbar that never takes input or focus |
| `GoPromptCard` | PanelContainer | Non-blocking question card; keeps pressed buttons alive across refreshes |
| `GoCoachMark` | Control | Guided tour that points at real controls; pressing the target advances; the card steps around HUD anchors and `keep_clear` controls |
| `GoHudAnchor` | Control | Pins HUD pieces to one of nine safe-area spots, with an optional landscape spot, `reserve_space` and `avoid_peers` |
| `GoBar` | Control | HP/MP/XP bars with value, fraction or percent readouts and eased changes |
| `GoSlot` | Button | Quick slot with icon, quantity, cooldown and shortcut on a single face; shared hit areas in tight rows; `keyboard_focus` opts into Tab order |
| `GoJoystick` | Control | Virtual joystick in fixed, follow or relative mode, with dead zone |
| `GoIconButton` | Button | Icon-only button: small visual, full-size hit area, accessible name |
| `GoStyle` | factory | Buttons, labels, list rows, inputs, selects, dropdowns, chips, cards, tables, tabs, wrap rows, responsive grids, foldable sections, empty states |
| `GoUi` | static | Current config, preset, theme, skin, icons, colors, metrics and strings |
| `GoThemePresets` | static | The six built-in presets, presets found in `themes/presets/`, and `register()` for your own |
| `GoSkin` · `GoSkinSciFi` · `GoSkinMedieval` | Resource | The shapes code draws, with numeric dials |
| `GoSafeArea` | Control / static | Usable rectangle excluding notches, rounded corners and the keyboard |
| `GoScale` | static | Breakpoint and dp math |
| `GoFeedback` | static | Sound and haptic routing |
| `GoBackPolicy` | static | Shared ownership of Android Back |

### Waiting, telling, counting

| Class | Base | Purpose |
|---|---|---|
| `GoSnackbar` | Node | A message at the bottom of the screen, on its own layer. It queues, merges a repeat of the same text into a counter, dodges the safe area and the keyboard, and can carry buttons — `await post()` returns the index of the one that was pressed, or `-1` when it expired. With no buttons it takes no input at all |
| `GoSpinner` | Control | An indeterminate wait. `GoSpinner.busy(button, true)` turns a button into a spinner **in place**: same size, disabled, and the label comes back on `false` — so a slow request cannot be fired twice |
| `GoBadge` | PanelContainer | The unread dot, the `NEW` tag and the `99+`. `attach()` hangs it half off the top-right corner of any control through anchors, so it follows when that control moves or resizes; `0` hides it |

### Forms and lists

| Class | Base | Purpose |
|---|---|---|
| `GoField` | VBoxContainer | Label, control, hint — and per-field errors. `set_error()` marks the box, says what is wrong under it, and makes that error the control's accessible description; the label and hint stay translated while the error does not (a server message is not a key) |
| `GoInputGroup` | HBoxContainer | An input and its buttons welded into one shape — search with a leading icon, a message row with Send, a quantity with − and +. The parts share one border and one focus ring |
| `GoCombobox` | Button | A picker that **searches inside** names, not just from their start, so "sword" finds "Rusty sword". Opens a `GoSurface` anchored to itself, keeps the chosen row highlighted, and falls back to a plain list when there are few items |
| `GoCodeInput` | VBoxContainer | Coupon and gift codes as separate cells. One hidden `LineEdit` holds the text so paste, autofill and an IME all keep working — the cells are drawn, not typed into. Cells wrap instead of overflowing on a phone |
| `GoTable` | VBoxContainer | Sortable headers and selectable rows. **Numbers sort as numbers** (a column of `2, 10` does not become `10, 2`), the sorted header shows its direction in a glyph as well as in colour, and rows keep a 48 dp touch height |
| `GoPagination` | HBoxContainer | Numbered pages that keep the current one centred with ellipses at the ends, or — with `mode = MORE` — a single *Load more* row, which is what a phone list actually wants |

### Shapes games actually use

| Class | Base | Purpose |
|---|---|---|
| `GoRewardCalendar` | VBoxContainer | Daily attendance: claimed, today, and still to come. Only today can be pressed, the streak is drawn as a run, and each day's state is spoken, not just coloured |
| `GoRadar` | Control | The stat pentagon — strength, agility, intellect, vitality, luck in one shape. `set_compare()` overlays a **dashed** second line for the gear you are about to equip (dashed, so colour-blind players still see two lines) |
| `GoDonut` | Control | Damage share, currency splits, party contribution. Beyond `collapse_to` slices the rest is merged into one, the centre carries the total, and `legend()` says every slice in words as well as in colour |
| `GoCarousel` | VBoxContainer | Event banners and character select. It **never moves on its own** — an auto-advancing banner steals the tap the player was aiming at; dots are pressable and the page is announced |
| `GoKbd` | HBoxContainer | Key caps for hints. `GoKbd.for_action(&"interact")` reads the real binding from the InputMap, so remapping a key changes the hint too, and `hide_on_touch` keeps it off phones |

### Over the screen

| Class | Base | Purpose |
|---|---|---|
| `GoDrawer` | CanvasLayer | A panel that slides in from either side, for screens wider than a phone. It respects the safe area, closes on Back and on the scrim, and mirrors itself in RTL |
| `GoPopover` | RefCounted | An info card beside the thing you pressed — the item tooltip, the "what is this stat" card. One at a time, flips to the other side when it would go off-screen, and follows its anchor on resize |
| `GoContextMenu` | RefCounted | Long-press (0.5 s) or right-click on any control. A finger that moves more than 12 dp cancels it, so a long list still scrolls |
| `GoConsole` | CanvasLayer | The developer console: registered commands, arguments, history and completion. `allow_in_release` defaults to `false`, so it cannot open in a shipped build |

### Subclass hooks

Every widget that builds child widgets does so through an overridable method, so a host that
subclasses gohud types (its own type hints, its own close glyph, its own modal system) gets those
subclasses *inside* the widgets without copying code:

| Hook | Widget | Default |
|---|---|---|
| `_make_scroll()` | `GoCoachMark`, `GoSurface` | `GoScroll.new()` |
| `_make_close_button()` | `GoPromptCard`, `GoSurface` | `GoIconButton.new()` |
| `_make_surface()` | `GoSheet`, `GoDialogs` | `GoSurface.new()` |
| `_should_pause()` | `GoCoachMark` | `GoSurface.is_any_open()` — hide the card while a modal is open |
| `GoScroll.as_horizontal(node)` | static | the configuration step of `horizontal()`, for `static func horizontal() -> MyScroll` |

`GoIconButton.native_texture_size = true` draws a texture icon at its own pixel size instead of
scaling it to 58 % of `visual_size`.

## Plugin

Enabling the plugin does three things, all optional:

1. adds the **gohud → Config → Resource** and **gohud → Theme → Preset** project settings;
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

> **Bring a font for your languages.** The only bundled font is Cinzel, and only the medieval presets
> assign it — to titles and subtitles. Thai, Arabic, Hebrew, Hindi and CJK need glyph coverage from
> your own theme font; a Latin-only font draws them as empty boxes and raises no error. Traditional
> Chinese needs its own coverage too: a Simplified subset does not contain those forms.

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
- Focus rings appear for keyboard and gamepad users, not after a tap or click. Filled buttons get a
  ring that contrasts with their own panel, and the contrast checker measures it there.
- Focus moves into a window when it opens, stays inside it, and returns where it was when it closes.
- Quick slots stay out of the Tab order by default; `GoSlot.keyboard_focus` opts them in when keyboard
  or gamepad is the only input.
- `GoStyle.Tone.DANGER_SOLID` (and `GoDialogs.confirm(..., destructive = true)`) keeps irreversible
  actions readable as danger on light themes, where a tinted danger label would read as black text.

## Verified

`tools/check_all.sh` is the single entry point. Each part sees something the others cannot:

| Check | What it catches |
|---|---|
| `run_tests.sh` at 390×844, 844×390, 768×1024 and 1280×800 | Widget behaviour and layout, RTL positions, keyboard focus, runtime skin contrast, every preset |
| `new_project_check.sh` (`--with-runtime`, `--zip`, `--export`) | Hidden dependencies on a host project, the release ZIP as shipped, Web export |
| `check_contrast.py` | WCAG contrast of every theme file, including button states and translucent panels |
| `check_generated.py` · `check_scaffold.sh` | Generated themes still match their palettes; a throwaway theme builds and passes contrast |
| `check_package.py` | Version bumps, changelog moves and ZIP contents, exercised in temporary copies |
| `check_site.py` | Website links, anchors, page language, glossary and generated dial tables |
| `check_mutations.sh` (opt-in) | Whether the suite notices when a rule is deliberately broken |

Latest recorded run — **2026-09-13**, Godot 4.7.2 (macOS, Apple Silicon, Compatibility renderer), on
the add-on files of this revision copied into empty projects:

| Check | Result |
|---|---|
| Headless suite in an empty project at 390×844, 844×390, 768×1024 and 1280×800 | 438/438 at each size |
| The same suite with the `GoRuntime` autoload enabled | 438/438 |
| Web export of that empty project | pass (`index.pck` 728 KB) |
| `check_contrast.py` across the six themes | 0 failures |
| `check_generated.py` | 149 generated files match their sources |
| `check_scaffold.sh`, including a medieval parent | pass |
| `check_package.py` | 13 tests pass |

**Not part of this run:** Godot 4.6 (`GODOT_46` was not set), the release ZIP itself (`--zip`), physical
Android or iOS devices, and the Forward+ and Mobile renderers. The safe-area and haptics code paths only
activate on handheld platforms, so they are exercised by the suite but not on real hardware.

## Examples

| Example | Open | Shows |
|---|---|---|
| Gallery | `res://addons/gohud/examples/gallery/gallery.tscn`, F6 | Every widget, a picker for every installed preset, and the full icon set. Needs no server, autoload or project setup. |
| Medieval | `res://addons/gohud/examples/medieval/medieval.tscn`, F6 | A character sheet, satchel and quest journal in `medieval_dark` and `medieval_light`. |
| Demo app | `cd examples/demo && godot` | A home screen that opens the gallery, a guided 15-chapter tour, the showcase screen or the medieval look — plus live widgets and one card per class. |

### Demo app

```bash
cd examples/demo && godot
```

Nothing to set up: if the add-on link or the import cache is missing, the app links, imports and
reopens itself once, then lands on its **home screen**. Four cards open the widget gallery, the
guided tour, the showcase screen and the medieval look inside the same window — press `1`–`4`, or
click. Around them the page is itself a tour of the kit: a live HUD beside the pitch, six cards of
real widgets to press, and all 19 classes grouped by the job they do, each with the one line of
code that uses it. It is built from add-on widgets alone, holds its text to a readable measure,
folds to one column on a phone, and repaints with the preset picker.

**Start demo**, on the tour, plays 15 chapters with a visible cursor using real input — buttons,
fields, menus, scrolling, HUDs, dialogs, forms and more. **Explore widgets**, or any row in the
sidebar, opens a single widget for you to try by hand, with a **Play this widget** button that
lets the bot demonstrate just that one. All demo text is English. Large desktop windows enlarge
the UI along with the canvas.

```bash
bash examples/demo/run.sh                               # the same app, from the add-on root
bash examples/demo/run.sh -- --open=gallery             # skip the home screen
bash examples/demo/run.sh --record /tmp/gohud-demo.avi  # 1080p / 60 fps, complete tour
bash examples/demo/run.sh --shot /tmp/gohud-home.png
bash examples/demo/run.sh -- --explore=surfaces         # open the app on one widget
```

**C** toggles Cinema mode, **F11** toggles fullscreen, **Space** pauses, arrows change chapters,
and **Escape** returns to Start. While exploring, the arrows move between widgets and Space plays the
current one. Cinema mode hides the side panels and offers a countdown.
See [the demo guide](examples/demo/README.md) for recording, testing and ZIP setup.

## Documentation website

The site at **[https://thruthesky.github.io/gohud/](https://thruthesky.github.io/gohud/)** is plain
HTML in [`www/`](www/index.html) — English at the root, sixteen more languages in their own folders —
with definitions that open on hover, tap or keyboard focus. Every language has the same five pages:
overview, [install](www/install.html), [**AI SKILL**](www/ai.html), [widgets](www/widgets.html) and
[theming](www/theming.html). The header menu and the whole AI SKILL page are **generated** from
[`tools/site_nav.py`](tools/site_nav.py) and [`tools/site_ai_text.py`](tools/site_ai_text.py) —
edit those, not the 85 HTML files. A GitHub Actions workflow
([`.github/workflows/pages.yml`](.github/workflows/pages.yml)) publishes `www/` itself as the site root.
Old `docs/www/` addresses keep working: `www/404.html` forwards pages, and images keep a copy at their old
address so the READMEs in released ZIPs still show them.

```bash
python3 addons/gohud/tools/make_site.py            # regenerate the glossary and skin-dial tables from source
python3 addons/gohud/tools/check_site.py           # links, anchors, language, glossary, generated tables
bash addons/gohud/tools/site_shots.sh /tmp/shots   # desktop and phone screenshots of every page
```

See [docs/README.md](docs/README.md) for the publishing details.

## Development

```bash
bash addons/gohud/tools/check_all.sh              # every check in one run
bash addons/gohud/tools/run_tests.sh              # headless checks inside the current project
bash addons/gohud/tools/new_project_check.sh      # install into an empty project, test, optionally --export
python3 addons/gohud/tools/check_contrast.py      # WCAG contrast for every theme
python3 addons/gohud/tools/new_theme.py kingdom --from medieval_dark   # scaffold a theme
python3 addons/gohud/tools/make_theme.py          # regenerate the themes; pass an id to build one
python3 addons/gohud/tools/make_icons.py          # regenerate the default icon SVGs
bash addons/gohud/tools/package.sh                # patch +1; builds/<version>/gohud-<version>.zip
bash addons/gohud/tools/package.sh --increase-minor-version # minor +1, patch resets to 0
python3 addons/gohud/tools/check_package.py       # packaging regression checks in temporary copies
```

`package.sh` requires Python 3 and automatically increments the patch version on each successful
run (for example, `1.2.9` → `1.2.10`). `--increase-minor-version` instead produces `1.3.0`.
`--out DIR` changes the output folder and still increments the version. Versions must use the
stable `major.minor.patch` format.

The script updates `plugin.cfg`, `GoUi.VERSION` and `CHANGELOG.md` together. Pending `Unreleased`
notes move into a dated entry for the new version, leaving an empty `Unreleased` section.
Version files remain unchanged if packaging fails, and existing release ZIPs are never overwritten.
Version mismatches, missing documents and references outside `addons/gohud/` still fail validation.
The ZIP leaves out the website, tests, tools and the standalone `examples/usage` project.
Packaging checks in `check_all.sh` use temporary copies and do not increment your working version.

## License

MIT — see [LICENSE](LICENSE). The code and the bundled artwork (84 default icons, 16 medieval icons
and the generated control artwork) were made for gohud and are MIT as well. The Cinzel font is
distributed unmodified under the SIL Open Font License 1.1 (`assets/fonts/cinzel/OFL.txt`); see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
