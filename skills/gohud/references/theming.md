# Theming — presets, tokens, overrides, JSON themes, skins, StyleBoxes

Source: `core/go_ui.gd`, `core/go_theme.gd`, `core/go_theme_presets.gd`, `core/go_skin.gd`, `themes/skins/`,
`widgets/go_stylebox_*.gd`, `tools/new_theme.py`, `tools/make_theme.py`.
Web: https://thruthesky.github.io/gohud/theming.html

## Contents

1. [Three layers and presets](#1-three-layers-and-presets)
2. [Tokens](#2-tokens)
3. [Small changes without a new theme](#3-small-changes-without-a-new-theme)
4. [Container opacity](#4-container-opacity)
5. [A new theme from one JSON file](#5-a-new-theme-from-one-json-file)
6. [Skins — shapes drawn by code](#6-skins)
7. [Custom StyleBoxes](#7-custom-styleboxes)
8. [A project-local preset in code](#8-a-project-local-preset-in-code)
9. [Contrast rules](#9-contrast-rules)

## 1. Three layers and presets

| Layer | Decides | Class |
|---|---|---|
| Theme | Colours, sizes, text scale, engine-drawn controls (buttons, inputs, tabs, toggles) | Godot `Theme` with a `GoHud` type |
| Skin | Code-drawn shapes: joystick, slot faces, badges, coach ring/pointer, chips, skeletons, alerts, segments, dividers, section headings | `GoSkin` (`GoSkinSciFi`, `GoSkinMedieval`) |
| Icons | Drawings by name | `GoIconSet` |

A **preset** (`GoThemePreset`: `id`, `title`, `dark`, `theme`, `skin`, `icons`, `label()`) bundles the three.

| Id (`GoThemePresets.*`) | Look | Skin · icons |
|---|---|---|
| `DEFAULT_DARK` · `DEFAULT_LIGHT` | Rounded flat panels, soft blue accent, graded shadows | `GoSkin` · 84 default |
| `SCIFI_DARK` · `SCIFI_LIGHT` | `GoStyleBoxCut` chamfered panels, neon edge + glow, hex joystick, bracket focus | `GoSkinSciFi` · default |
| `MEDIEVAL_DARK` · `MEDIEVAL_LIGHT` | `GoStyleBoxMedieval` iron/leather or parchment frames, rivets, Cinzel headings | `GoSkinMedieval` · 16 engraved over default |

```gdscript
GoUi.use_preset(GoThemePresets.SCIFI_DARK)   # String/StringName id or a GoThemePreset
GoUi.config.icons = my_icons                 # AFTER use_preset: keep the preset, override one layer
```

Resolution order: `GoUi.theme()` = `config.theme` → preset theme → `GoUi.DEFAULT_THEME`; same for `skin()` and
`icons()`. The preset id = `config.preset`, or project setting `gohud/theme/preset` when that is empty.
`use_preset()` **clears** `config.theme/skin/icons`, resets cached font sizes and notifies live widgets — but a
node keeps the `theme` it was built with, so switch looks by rebuilding the screen.

`GoThemePresets`: `names()` (no loading) · `ids()` (loadable) · `all() -> Array[GoThemePreset]` · `find(id)` ·
`register(preset)` · `unregister(id)` · `scan_folder()`. Any `themes/presets/<id>.tres` is discovered.

```gdscript
# A preset picker
var presets := GoThemePresets.all()
var picker := GoStyle.select(presets.map(func(p: GoThemePreset) -> String: return p.label()))
picker.item_selected.connect(func(i: int) -> void:
	GoUi.use_preset(presets[i].id)
	rebuild_ui())
```

## 2. Tokens

All tokens live in the Theme under type **`GoHud`**. Read them through `GoUi` (overrides applied):
`GoUi.color(GoTheme.ACCENT)` · `GoUi.metric(GoTheme.GAP)` (int dp) · `GoUi.box(GoTheme.BOX_CARD)` (a copy) ·
`GoUi.font_size(GoTheme.ROLE_CAPTION)`. A missing colour comes back **magenta**, a missing metric `0`.

| Kind | Constants on `GoTheme` |
|---|---|
| Colours (17) | `BACKGROUND` `SURFACE` `SURFACE_SOFT` `SURFACE_HIGH` `BORDER` `TEXT` `SECONDARY` `MUTED` `ACCENT` `ON_ACCENT` `SUCCESS` `WARNING` `DANGER` `INFO` `SCRIM` `SHADOW` `TRACK` |
| Fill colours (5, optional) | `SUCCESS_FILL` `WARNING_FILL` `DANGER_FILL` `INFO_FILL` `ACCENT_FILL` — bars and large areas; fall back to the base colour |
| Metrics (20, dp) | `TOUCH` `BUTTON_HEIGHT` `GAP_TINY` `GAP_SMALL` `GAP` `GAP_LARGE` `PADDING` `PADDING_COMPACT` `COMPACT_PADDING_X` `COMPACT_PADDING_Y` `RADIUS_SMALL` `RADIUS` `RADIUS_LARGE` `SCREEN_MARGIN` `SCROLL_DEADZONE` `SCROLL_EDGE` `SCROLLBAR_WIDTH` `LIST_GLYPH` `ICON_SIZE` `NOTICE_DURATION_MS` |
| Panel opacity (5, optional, **% in the theme**) | `PANEL_ALPHA` `CARD_ALPHA` `HUD_ALPHA` `NOTICE_ALPHA` `POPUP_ALPHA` — how solid a container face is. **80** by default, `POPUP_ALPHA` 100; a theme without them falls back to 100. Percent only because a `Theme` constant cannot hold a float — read it as a *ratio* with `GoUi.surface_alpha(variant)`, and every other layer is a ratio too; §4 |
| StyleBoxes (8) | `BOX_PANEL` `BOX_CARD` `BOX_HUD` `BOX_NOTICE` `BOX_POPUP` `BOX_EMPTY` `BOX_FOCUS` `BOX_FOCUS_SOFT` |
| Text roles (7) | `ROLE_MICRO` `ROLE_COMPACT` `ROLE_CAPTION` `ROLE_BODY` `ROLE_BUTTON` `ROLE_SUBTITLE` `ROLE_TITLE` — names of sizes, not purposes |
| Type variations (15) | `GoPanel` `GoCard` `GoButton` `GoPrimaryButton` `GoDangerButton` `GoDangerSolidButton` `GoBareButton` `GoCompactButton` `GoIconButton` `GoListButton` `GoTitleLabel` `GoSubtitleLabel` `GoCaptionLabel` `GoCompactLabel` `GoMicroLabel` (constants `VAR_*`) |

`TOUCH` always returns `GoConfig.min_touch_size`. Text colour meaning: `TEXT` body, `SECONDARY` supporting,
`MUTED` dimmed; `ON_ACCENT` is the label colour on an accent fill. Custom controls stay consistent by using tokens:

```gdscript
var badge := Label.new()
GoStyle.typography(badge, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.ON_ACCENT))
var face := StyleBoxFlat.new()
face.bg_color = GoUi.color(GoTheme.ACCENT)
face.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
```

## 3. Small changes without a new theme

```gdscript
GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
GoUi.config.color_overrides[GoTheme.ACCENT] = Color("#ff7a00")
GoUi.config.metric_overrides[GoTheme.RADIUS] = 2
GoUi.config.base_font_size = 18
GoUi.refresh()                                 # before building, or rebuild after
```

`color_overrides` affect widgets that read tokens in code (bars, slots, labels with ink, skins). Engine-drawn
panels already baked into the Theme `.tres` (button faces) keep their colours — for those, edit a Theme copy:
duplicate `res://addons/gohud/themes/gohud_dark.tres` to `res://ui/my_theme.tres`, change the `GoHud` colours and
the button/panel StyleBoxes in the Theme editor, then `GoUi.config.theme = preload("res://ui/my_theme.tres")`.
A plain Theme without `GoHud` tokens also works while `token_fallback` is true.

## 4. Container opacity

Containers draw their face at **80% opacity** by default, so the game stays visible behind a dialog or sheet.
**Only the face thins out** — text, icons, buttons, badges, quick slots, borders and shadows keep full
strength. Never reach for `modulate.a` to get this effect: it fades the content too.

**Five layers, most specific first.** Everything is a **ratio** (0.0–1.0, negative = "not set") except the
theme's constants and the channel that overrides them — a `Theme` constant cannot hold a float, so those two
are **percent integers** (0–100).

| Order | Where | Unit |
|---|---|---|
| ① | the argument or field at that call — `surface.alpha`, `sheet.alpha`, `dialogs.alpha`, `drawer.alpha`, `GoStyle.card(…, alpha)` | ratio |
| ② | `GoConfig.container_alpha_overrides[kind]` (`Dictionary[StringName, float]`, key = `GoTheme.BOX_*`) | ratio |
| ③ | `GoConfig.metric_overrides[<kind>_alpha]` | **%** |
| ④ | `GoConfig.container_alpha` (negative = not set) | ratio |
| ⑤ | theme `GoHud/constants/<kind>_alpha` — the source of truth | **%** |

```gdscript
GoUi.surface_alpha(GoTheme.BOX_PANEL)        # resolved ratio, e.g. 0.8

surface.alpha = 0.6                          # this GoSurface only (dialog/sheet/dropdown shell)
sheet.alpha = 0.7                            # GoSheet delegates to its surface
dialogs.alpha = 0.9                          # GoDialogs · GoDrawer are @export — still ratios
drawer.alpha = 0.7
notice.alpha = 0.95                          # GoNotice · GoSnackbar · GoPromptCard · GoCoachMark · GoConsole
GoPopover.open(slot, body, {"alpha": 0.9})   # option key

GoUi.config.container_alpha_overrides = {GoTheme.BOX_HUD: 0.95}
GoUi.refresh()                               # 🛑 required for widgets already on screen
```

**Which faces follow it**

| Follows — containers | Ignores — pressables and markers |
|---|---|
| `GoSurface` `GoSheet` `GoDialogs` `GoDrawer` `GoPopover` `GoNotice` `GoSnackbar` `GoPromptCard` `GoCoachMark` `GoConsole` | every button, `GoSlot`, `GoBadge`, `segmented()`, `choice_grid()`, `chip()`, `disc()` |
| `GoStyle.card()` `hud_panel()` `overlay_panel()` `alert()` `plate()` `edge_card_panel()` `style_notice_panel()` `floating()` `box()` `surface()` | all text and icons |

Every `GoStyle` factory above takes an `alpha` argument (last parameter; `overlay_panel`'s is `fill_alpha`).
`GoUi.skin().surface_box(variant, accent, alpha)` is the one place the value is multiplied in — subclasses of
`GoSkin` that override `surface_box`, `floating_box` or `alert_box` **must carry the new parameter** or the
script fails to parse.

- 🛑 `POPUP_ALPHA` is 100 on purpose. The engine may host a `PopupMenu` in its own `Window`, where the OS does
  not composite it with the game and translucency renders black. Lower it only with `gui_embed_subwindows` on.
- `GoStyle.plate()` keeps an explicit `fill` colour exactly as passed (its alpha is already the caller's
  decision); opacity applies only when `fill` is omitted, or when `alpha` is given explicitly.
- `GoStyle.floating(…, opaque = true)` ignores the value — filling the face solid is that flag's purpose.
- Panels gohud did not build: `GoStyle.fade_panel(node, alpha := -1.0, state := &"panel", variant := GoTheme.BOX_PANEL)`
  **after** the node is in the tree. It is idempotent (the original face is stored in a meta entry, so repeated
  calls never stack); after a theme swap call `GoStyle.forget_face(node)` first.
- The multiplication is **relative**: the default HUD face is already 0.92 alpha, so `hud_alpha` 80 lands at
  0.736. A theme that deliberately made a face translucent keeps that decision.
- Verify visually, not only by value: `tests/gohud_alpha_shot.gd` draws panels over diagonal stripes on a
  virtual monitor. `bg_color.a == 0.8` is a number; "the world shows through and the text is still legible"
  is the actual requirement.

## 5. A new theme from one JSON file

Run inside a project that has gohud at `addons/gohud` (a git checkout — the tools are not in the release ZIP).
These commands write **into the add-on folder** (`themes/palettes/`, `themes/presets/`, `themes/skins/`,
`assets/<id>/`); in a submodule that is a change to gohud itself.

```bash
python3 addons/gohud/tools/new_theme.py kingdom --from medieval_dark --title "Kingdom"   # --new-skin to scaffold a GoSkin subclass
# edit addons/gohud/themes/palettes/kingdom.json
python3 addons/gohud/tools/make_theme.py kingdom       # theme .tres, control SVGs, skin .tres
godot --headless --path . --import                     # 🛑 required before the theme can load
python3 addons/gohud/tools/check_contrast.py           # WCAG check
python3 addons/gohud/tools/new_theme.py --remove kingdom   # undo everything it created
```

```gdscript
GoUi.use_preset(&"kingdom")
```

| JSON block | Content |
|---|---|
| `id` · `title` · `dark` | Lowercase id (`[a-z][a-z0-9_]*`), picker label, grouping |
| `from` | Parent: `dark`, `light`, `scifi_dark`, `scifi_light`, `medieval_dark`, `medieval_light` or another JSON id. Omitted keys inherit; cycles fail |
| `palette` | `background` `surface` `surface_soft` `surface_high` `border` `text` `secondary` `muted` `accent` `on_accent` `success` `warning` `danger` `info` `scrim` `shadow` `track` + `*_vivid` fills. Format `"#RRGGBB"` or `"#RRGGBB@0.35"`. Text, borders and accent are pushed to readable contrast |
| `shape.kind` | `flat` (rounded) · `cut` (chamfer) · `medieval` (forged) |
| `shape` sizes | `radius` `radius_small` `radius_large` `gap` `gap_small` `gap_large` `padding` `button_height` `button_padding[4]` (+ `compact_padding_x/y`) |
| `shape` for `cut` | `cut_ratio` `cut_max` `corners` (`diagonal`/`all`) `glow` `edge` |
| `shape` for `medieval` | `material` (0 iron · 1 leather · 2 parchment) `grain_alpha` `ornament_scale` `bevel_strength` `fonts` {`title`,`subtitle`,`caption`,`body`,`button`: addon-local `res://` font} |
| `skin` | `base` (`default`/`scifi`/`medieval`), `name`, `dials` {name: number} (table in §5) |
| `icons` | `res://` path to a `GoIconSet` resource |

```json
{
  "id": "kingdom", "title": "Kingdom", "from": "medieval_dark", "dark": true,
  "palette": { "accent": "#c9a227", "danger_vivid": "#b3261e", "scrim": "#000000@0.6" },
  "shape": { "kind": "medieval", "material": 0, "radius": 3 },
  "skin": { "base": "medieval", "dials": { "slot_rivets": 0, "float_shadow_size": 18 } }
}
```

## 6. Skins

Override only what you need; everything else keeps the parent's drawing. Assign with
`GoUi.config.skin = MySkin.new()` (after `use_preset`) or put it in a preset.

| Method | Draws |
|---|---|
| `surface_box(variant := BOX_CARD, accent := transparent) -> StyleBox` · `floating_box(...)` · `overlay_box(h_margin := -1, v_margin := -1, fill_alpha := 0.82)` | Card/panel faces, floating HUD panels, pills over the game |
| `chip_box(color)` · `chip_ink(color) -> Color` | Chip face and legible chip text |
| `slot_box(accent, lit: bool)` · `slot_ink(accent, lit)` · `badge_box(ink)` | Quick slot face (`lit` = cooldown running), text, badges |
| `disc_box(diameter, accent, fill_alpha := 0.14, edge_alpha := 0.38)` | Avatar/icon discs |
| `alert_box(ink)` · `skeleton_box()` · `segment_box(index, count, state)` | Inline alerts, placeholders, segmented control faces |
| `progress_fill_box(ink)` · `notice_box(accent, compact)` · `tint_notice(box, accent)` | Bar fills (outlined when < 3:1), snackbars |
| `coach_ring_box(accent)` · `draw_coach_pointer(canvas, start, tip, direction, ink)` | Coach mark ring and arrow |
| `draw_joystick(canvas, center, knob, radius, knob_radius, ink, base, active)` | Joystick |
| `divider_color()` · `divider_thickness()` · `section_box()` | Dividers, section headings |
| static `luminance(c)` · `contrast_ratio(a, b)` · `blend(top, bottom)` · `readable_on(ink, back, need := 4.5)` · `box_background(box)` | Contrast helpers |

Dials (`@export`, set on a skin resource or JSON `skin.dials`):

| Skin | Dials (default) |
|---|---|
| `GoSkin` (17) | `chip_fill_alpha` 0.16 · `chip_edge_alpha` 0.45 · `alert_tint` 0.1 · `slot_tint_lit` 0.24 · `slot_tint_idle` 0.08 · `slot_border_lit` 2 · `slot_border_idle` 1 · `badge_pad_x` 5 · `badge_pad_y` 1 · `badge_edge_alpha` 0.6 · `float_shadow_alpha` 0.45 · `float_shadow_size` 14 · `float_shadow_lift` 4 · `float_glow_size` 10.0 · `joystick_base_alpha` 0.42 · `joystick_ring_alpha` 0.45 · `joystick_ring_width` 2.0 |
| `GoSkinSciFi` (+10) | `cut_chip` 7 · `cut_skeleton` 5 · `cut_alert` 8 · `cut_segment` 8 · `cut_slot` 6 · `cut_disc_ratio` 0.24 · `slot_glow_alpha` 0.45 · `slot_glow_size` 6 · `bracket_arm` 12 · `bracket_thickness` 2 |
| `GoSkinMedieval` (+5) | `slot_radius` 4.0 · `leather_grain_alpha` 0.035 · `ornament_scale` 1.0 · `bevel_strength` 0.18 · `slot_rivets` 1 |

```gdscript
class_name DiamondSkin extends GoSkin

func slot_box(accent: Color, lit: bool) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = GoUi.color(GoTheme.SURFACE).lerp(accent, 0.3 if lit else 0.1)
	box.border_color = accent
	box.cut = 10.0
	box.cut_corners = GoStyleBoxCut.ALL
	return box

func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	canvas.draw_circle(center, radius, Color(base, 0.4))
	canvas.draw_circle(knob, knob_radius, Color(ink, 0.9 if active else 0.6))
```

## 7. Custom StyleBoxes

All serialise into Theme resources. 🛑 Give padding with `content_margin_*` — `_get_style_margin()` is not called
for GDScript StyleBoxes (measured on 4.7), so leaving them empty puts content against the border.

| Class | Fields |
|---|---|
| `GoStyleBoxCut` | `bg_color` `draw_center` `border_color` `border_width` `cut` `cut_corners` (`TOP_LEFT` 1 `TOP_RIGHT` 2 `BOTTOM_RIGHT` 4 `BOTTOM_LEFT` 8 `DIAGONAL` `ALL`) `edge_color` `edge_width` `edge_side` (0 left 1 top 2 right 3 bottom) `glow_color` `glow_size` |
| `GoStyleBoxBracket` | `color` `arm` `thickness` `inset` `bg_color` `diagonal_only` — corner marks only (focus, targeting) |
| `GoStyleBoxMedieval` | `bg_color` `border_color` `border_width` `draw_center` `radius` `material` (0 iron 1 leather 2 parchment) `ornament` (0 quiet 1 rivets 2 engraved) `ornament_scale` `grain_alpha` `bevel_strength` `shadow_color` `shadow_size` `shadow_offset` |

```gdscript
var box := GoStyleBoxCut.new()
box.bg_color = Color("#0b121c")
box.border_color = Color("#2a6f8f")
box.cut = 10.0
box.edge_color = Color("#00e5ff")      # thick accent edge on top
box.glow_color = Color("#00e5ff", 0.35)
box.glow_size = 8.0
box.set_content_margin_all(12)
panel.add_theme_stylebox_override(&"panel", box)
```

## 8. A project-local preset in code

Keeps the add-on folder untouched (good for submodules and the Asset Store ZIP):

```gdscript
func _ready() -> void:
	var brand := GoThemePreset.new()
	brand.id = &"brand_dark"
	brand.title = "Brand Dark"
	brand.theme = preload("res://ui/brand_theme.tres")   # a copy of gohud_scifi_dark.tres, recoloured
	brand.skin = GoSkinSciFi.new()                        # or your GoSkin subclass
	GoThemePresets.register(brand)
	GoUi.use_preset(brand)
```

## 9. Contrast rules

`python3 addons/gohud/tools/check_contrast.py` measures every theme: body text 4.5:1 · large text, accent
borders, icons, focus rings 3:1 · decorative borders 2:1 · adjacent surfaces 1.12:1. Translucent panels are
measured over pure white and pure black. When you tint things yourself, keep label colours legible with
`GoUi.skin().readable_on(ink, background)` rather than same-hue text on a same-hue tint.
