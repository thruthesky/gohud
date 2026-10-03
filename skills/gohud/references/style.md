# GoStyle — the control factory (every function)

`class_name GoStyle extends RefCounted`, all `static`. Source: `widgets/go_style.gd`.
Rules it enforces: sizes come from tokens (`GoUi.metric`), touch targets ≥ `min_touch_size`, long text wraps
by words (never one letter per line), buttons inside scrolls pass drags to the scroll.

**Text vs key:** `label` / `button` show text as written (`AUTO_TRANSLATE_MODE_DISABLED`); `label_key` /
`button_key` hold a translation key and re-translate on locale change. Functions with a `translate` flag
follow the same idea — with one catch: `toggle()`, `line_edit()` and `textarea()` given `false` **inherit** the parent's
translation mode instead of turning it off, so a word that is also a key in your tables still gets translated. For
literal text there, set `node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED` yourself. `checkbox()`,
`select()` and `foldable()` do turn it off.

## Contents

1. [Structure](#1-structure)
2. [Text](#2-text)
3. [Buttons](#3-buttons)
4. [Input](#4-input)
5. [Selection and navigation](#5-selection-and-navigation)
6. [Display](#6-display)
7. [Surface styleboxes](#7-surface-styleboxes)
8. [Helpers](#8-helpers)
9. [Form and list widgets (classes, not factories)](#9-form-and-list-widgets-classes-not-factories)
10. [Lower-level functions](#10-lower-level-functions)

## 1. Structure

| Signature | Returns | Notes |
|---|---|---|
| `column(spacing := -1)` | `VBoxContainer` | -1 → `gap`; expands horizontally |
| `row(spacing := -1)` | `HBoxContainer` | |
| `wrap_row(spacing := -1, alignment := FlowContainer.ALIGNMENT_BEGIN, last_line := FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN)` | `HFlowContainer` | Children get natural width automatically — chips, tags, button groups. 🛑 **Everything inside, all the way down**, is set to `SIZE_SHRINK_BEGIN` with wrapping off (`natural_width`) — never put a card, a panel or a row with an expanding title in one |
| `padding(amount := -1, vertical := -1)` | `MarginContainer` | -1 → `padding` token on all sides. `vertical` ≥ 0 gives the top and bottom that value (sides keep `amount`) — roomy sides, tighter top and bottom for a list cell |
| `insets(margin_container, amount := -1, vertical := -1)` | void | Same, on an existing node |
| `gap(container, token := GoTheme.GAP)` | void | Sets separation (h/v for Grid/Flow) |
| `spacer(minimum := 0.0)` | `Control` | Expands; pushes siblings apart |
| `divider(vertical := false)` | `Control` | 1 dp line in the skin's divider colour (not `HSeparator`) |
| `responsive_grid(min_cell_width := 160.0, spacing := -1)` | `GridContainer` | Column count = floor((width + gap) / (cell + gap)) on every resize; children forced to expand. Equal columns that also keep `SIZE_FILL` children are `GoGrid` (below) |
| `aspect(ratio := 1.0)` | `AspectRatioContainer` | Thumbnails, portraits, minimap |
| `foldable(title, folded := false, group: FoldableGroup = null, translate := true)` | `FoldableContainer` | Same `FoldableGroup` = accordion. Add one content child |

### Layout classes

Containers that **draw nothing** — only the container ignores the mouse (`MOUSE_FILTER_IGNORE`); its items keep their
own filters, focus and size flags. Not `GoAppBar`/`GoNavBar` (faces, a title, destinations — `GoNavBar.rail()` too),
not `GoDrawer` (a panel that slides in), not `GoSlotGrid` (the inventory of `GoSlot`s), and not `responsive_grid()`
(which stays, returning a `GridContainer`).

| Class | Use | API |
|---|---|---|
| `GoTopBar` · `GoBottomBar` · `GoSideBar` → `GoLeftSideBar` · `GoRightSideBar` (all `GoEdgeBar`) | Items along an edge in 1, 2 or 3 slots — the tiers of a side bar | `GoTopBar.make(count := 3)` · `GoBottomBar.make(count := 1, placing := Justify.START)` · `GoLeftSideBar.make(count := 3, placing := Justify.START)` (and `GoRightSideBar`) · `add_start(node)` `add_center(node)` `add_end(node)` (return the node) · `set_slot(node, slot)` `slot_of(node)` `items(slot)` (`slot` is `GoEdgeBar.Slot.START` / `CENTER` / `END`) · `edge` (`GoEdgeBar.Edge`, set by each subclass) · `columns` (`tiers` on a side bar) · `justify` (`START` `CENTER` `END` `SPACE_BETWEEN`, one slot) · `separation` (-1 → `gap`) · `edge_margin` (-1 → `screen_margin`) · `thickness` (0 → as thick as the items) · `safe_area` · `avoid_keyboard` · `pin_to_edge` (`AUTO` `ALWAYS` `NEVER`) · `follow_text_direction` (side bars) · `dock(host)` · `extent()` · `clear_of(bars)` · static `edge_insets(rect, usable, screen, edge)` · metas `GROW` and `KEEP_WRAP` |
| `GoGrid` | Columns of exactly equal width, fixed or responsive | `GoGrid.make(count := 2, min_cell := -1.0, gap := -1)` · `columns` · `min_cell_width` (> 0 → responsive) · `spacing` · `row_spacing` · `columns_in_use()` · cells with `add_child()` |

```gdscript
var bar := GoTopBar.make(3)
bar.add_start(GoStyle.icon_button(GoIconSet.BACK, go_back, -1, &"back"))
bar.add_center(GoStyle.label("Stage 3"))   # on the bar's centre, however wide the sides
bar.add_end(GoStyle.chip("1,250"))
screen.add_child(bar)                      # screen is not a container → pinned to the top edge

var actions := GoBottomBar.make(1, GoBottomBar.Justify.SPACE_BETWEEN)
actions.layout_direction = Control.LAYOUT_DIRECTION_LTR   # a HUD row: physical left and right in every language
for icon in [GoIconSet.EDIT, GoIconSet.HEART, GoIconSet.BELL]: actions.add_start(GoStyle.icon_button(icon, act.bind(icon)))
screen.add_child(actions)

var tools := GoLeftSideBar.make(3)         # top · middle · bottom tiers down the left edge
tools.add_start(GoStyle.icon_button(GoIconSet.MENU, open_menu, -1, &"menu"))
tools.add_center(GoStyle.icon_button(GoIconSet.SEARCH, find, -1, &"search"))
tools.add_end(GoStyle.icon_button(GoIconSet.SETTINGS, open_settings, -1, &"settings"))
screen.add_child(tools)
tools.clear_of([bar, actions])             # between the top and bottom bars, following their height

var tiles := GoGrid.make(1, 160.0)         # as many 160dp-or-wider columns as fit
for item in items: tiles.add_child(GoStyle.item_card(item))
```

- **One rule for every edge**: items line up along the **main axis** — across a top or bottom bar, down a side bar —
  and the bar's size on the other, **cross** axis is its thickness (as thick as its items, never under the `touch`
  token, or `thickness` if larger). `START` is the start of the main axis: the left of a top bar in a left-to-right
  layout, the top of a side bar.

| Slots | Top / bottom bar | Side bar (tiers) |
|---|---|---|
| 1 | one run placed by `justify`: at the start, centre or end, or `SPACE_BETWEEN` — both bars | one tier at the top, middle or bottom (`justify` `START` · `CENTER` · `END`), or spread |
| 2 | start slot at the start, end slot at the far end | top tier at the top, bottom tier at the bottom |
| 3 | + the centre slot on the centre | + the middle tier on the middle |

- **The centre slot** sits on the centre of the area inside the margins and the safe-area padding while
  `max(start, end) + separation <= (length - centre) / 2`. Past that it moves aside only as far as it must not to overlap
  a side (it is not held on the centre); when the slots cannot fit, the bar asks for their total length and cuts
  nothing. Two slots have no centre — centre items follow the start ones, with a debug warning.
- **One slot**: every item in child order. `SPACE_BETWEEN` puts the first and last at the ends with equal gaps between —
  never closer than `separation`; one item stays at the start. An item marked `set_meta(GoEdgeBar.GROW, true)` takes
  the room left — the value is its share, 2.0 for twice another's — (a search field filling a top bar) and `justify`
  is not used; two and three slots keep every item at its own length. 🛑 Size flags never make an item grow along the
  bar: `GoStyle.label()` and `GoStyle.button()` come with `SIZE_EXPAND_FILL` and still keep their own length. Across the bar, an item with `SIZE_EXPAND` fills the
  thickness; any other sits on the bar's middle line at its own size.
- **Pinned or in the flow**: `AUTO` flows under a container and pins under anything else — full width for a top or
  bottom bar, full height for a side bar; `ALWAYS` pins even inside a container (it turns `top_level`); `NEVER`
  leaves the anchors as they are, including those an earlier pin set; `dock(host)` moves it under a non-container
  control and pins it (unless `NEVER`). In the editor a pinned bar writes its anchors too. 🛑 In the flow, a bar stays
  at the bottom only as the sibling of the page that scrolls (the last child of a column whose `GoScroll` expands) —
  inside the scrolling page it scrolls away. A pinned side bar runs the full height, corners included —
  `clear_of([top, bottom])` keeps it between them and follows them (one way only: a bar that already clears this one
  is skipped). `extent()` is how far a pinned bar reaches in from its edge — a reading, not a reservation: keep the
  page that far away yourself. Too long for its edge (three tall tiers on a 390dp landscape screen), a pinned bar runs
  past it — nothing overlaps, nothing is cut — and warns once in a debug build; put a long tier in a `GoScroll`.
- **Safe area**: the bar pads by the part of the notch, status bar or gesture bar its own rectangle covers, pinned or
  in the flow (not inside a scrolling page, where it would grow as it scrolls), so a top bar's items sit below the
  notch and a bar already inside the safe area pads nothing. On its own edge that is the clearance measured from the
  screen's edge. `avoid_keyboard` (off by default, needs the `GoRuntime` autoload) lifts a bottom bar's items above the
  virtual keyboard.
- **Direction**: a top or bottom bar follows the layout direction — `START` is the right in a right-to-left layout and
  items inside a slot reverse with it; a game HUD gives the bar `layout_direction = LTR`. A side bar stays on the
  physical side it names and keeps top-to-bottom order in every language; `follow_text_direction` swaps its side in
  a right-to-left language.
- 🛑 Text keeps one line: labels and buttons that enter have wrapping turned off (`go_no_wrap`), down through the item,
  so no label folds to 1dp, inside a `GoForm` too. A panel of prose is marked `set_meta(GoEdgeBar.KEEP_WRAP, true)`
  before it is added — nothing under it is touched — and given a width (`thickness` on a side bar, `SIZE_EXPAND_FILL`
  across). Side-by-side icon buttons and slots are made each other's `touch_peers` (and let go when one leaves).
- `GoGrid`: the cell rectangles are equal (1px at most between them); a child's size flags act only inside its cell.
  A child wider than `min_cell_width` widens every cell, so fewer columns fit. A responsive grid asks for one cell's
  width, so it narrows back after a wide window. Bars and grids watch the theme from `_enter_tree`, so a move keeps it.

## 2. Text

| Signature | Returns | Notes |
|---|---|---|
| `label(text, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT)` | `Label` | Wraps when `autowrap_text`; ignores mouse |
| `label_key(key, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT)` | `Label` | Translated |
| `section(text_or_key, translate := true)` | `Label` | Small muted heading; skin may decorate (`section_box`) |
| `typography(control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT)` | void | Apply a role to any Label/Button/RichTextLabel (via type variation, so it follows theme changes) |

Roles: `ROLE_MICRO` `ROLE_COMPACT` `ROLE_CAPTION` `ROLE_BODY` `ROLE_BUTTON` `ROLE_SUBTITLE` `ROLE_TITLE`.
Ink: pass a colour, usually `GoUi.color(GoTheme.MUTED)` / `SECONDARY` / a status colour.

| Role | Default size | Use it for |
|---|---|---|
| `ROLE_TITLE` | 28 | The screen's own name — one per screen |
| `ROLE_SUBTITLE` | 22 | A panel or surface heading, the name at the top of a detail card |
| `ROLE_BODY` · `ROLE_BUTTON` | 16 | Row titles, sentences, button text |
| `ROLE_CAPTION` | 13 | A row's second line (in `MUTED`), `section()` headings |
| `ROLE_COMPACT` | 12 | Chips, dense readouts |
| `ROLE_MICRO` | 10 | Badges and counters only — never a sentence |

🔑 **Step down one size per level** — heading 22 → row title 16 → second line 13 — and let colour add the
second cue (`TEXT` → `MUTED`). Two levels at the same size read as one (`SKILL.md` rule 15).
🛑 `label()` and `label_key()` expand horizontally by default. A value at a row's end (`0 / 1`, a price, "Now")
needs `SIZE_SHRINK_END`, or it splits the width with the title and floats in the middle of the row.

## 3. Buttons

`enum Tone { NORMAL, PRIMARY, DANGER, BARE, COMPACT, DANGER_SOLID, OUTLINED }` — PRIMARY for the main action,
DANGER tinted, DANGER_SOLID filled (irreversible confirm), BARE text-only, COMPACT small pill (touch height),
OUTLINED the normal button's shape with an edge and no fill (`GoSkin.outlined_button_box`) — a second action beside a
filled one.
Filled buttons (PRIMARY, DANGER_SOLID) sit **flat** — no shadow — unless you raise them: `GoStyle.glow(button)` for
one, `GoConfig.button_glow = true` for all.

| Signature | Returns | Notes |
|---|---|---|
| `button(text, action := Callable(), tone := Tone.NORMAL)` | `Button` | NORMAL, PRIMARY, DANGER, DANGER_SOLID and OUTLINED expand horizontally and use `button_height`; COMPACT and BARE keep their own width at the `touch` height |
| `button_key(key, action := Callable(), tone := Tone.NORMAL)` | `Button` | |
| `style_button(button, tone := Tone.NORMAL)` | void | Style a Button from a scene |
| `glow(button, on := true)` | `Button` | Raise a filled button with a glow (`GoPrimaryGlowButton` / `GoDangerSolidGlowButton`); `on = false` lays it flat. Other tones, and themes without the variation, are left alone. Chains: `GoStyle.glow(GoStyle.button("Play", play, GoStyle.Tone.PRIMARY))` |
| `icon_button(icon, action := Callable(), visual := -1, tooltip_key: StringName = &"")` | `GoIconButton` | Always give `tooltip_key` (tooltip + accessible name): a gohud name (`close`), **your own translation key**, or plain words — all go through the translation server. Over gameplay set `keyboard_focus = false` on the result |
| `apply_icon(button, icon, size := -1, ink := Color.TRANSPARENT, inset := -1.0)` | void | Texture sets use `Button.icon`; font sets add a child label, moved in by `inset` (the text padding widens to match) |
| `list_button(icon, key, action := Callable(), ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"")` | `Button` | Menu/settings row: icon, title, optional description line, optional trailing icon (e.g. `CHEVRON_RIGHT`). Whole row is the tap target |
| `list_row(button, icon, key, …same…)` | `Button` | Same, on an existing Button |
| `restyle_list_row(button, selected: bool, accent := Color.TRANSPARENT)` | void | Marks a list row as **the chosen one** (tint + 2 dp border, like a chosen `style_choice_card`) or clears it. Face only — call it again when the pick moves; never call `list_row` twice on one button |

🛑 `list_button(..., translate := true)` treats `key` as a translation key. For literal text pass
`translate = false` (the sixth argument) — otherwise an untranslated key simply shows as typed, but a key that
*does* exist in your tables gets replaced.

## 4. Input

| Signature | Returns | Notes |
|---|---|---|
| `line_edit(placeholder := "", translate_placeholder := false)` | `LineEdit` | `button_height` tall. Set `secret = true` for passwords. `false` inherits the parent's translation mode (see the top) |
| `textarea(placeholder := "", lines := 4, translate_placeholder := false)` | `TextEdit` | Word wrap, scrolls inside. Same translation catch |
| `toggle(key := "", translate := true)` | `CheckButton` | Switch; `button_pressed` to set. The second argument is `translate`, **not** the starting value; `false` inherits the parent's translation mode |
| `checkbox(key := "", translate := true)` | `CheckBox` | |
| `slider(minimum := 0.0, maximum := 1.0, step := 0.01)` | `HSlider` | Set `size_flags_horizontal = SIZE_EXPAND_FILL` yourself |
| `picker()` | `OptionButton` | Empty; `add_item()` yourself |
| `progress(ink := Color.TRANSPARENT)` | `ProgressBar` | Thin bar, no percentage text |
| `tint_progress(bar, ink)` | void | Fill colour; shape from skin |

## 5. Selection and navigation

| Signature | Returns | Notes |
|---|---|---|
| `select(options: Array, placeholder := "", translate := false)` | `OptionButton` | `item_selected(index)` signal |
| `dropdown(text, items: Array, action := Callable(), translate := false)` | `MenuButton` | Items: `"text"` or `{"text", "icon": StringName, "disabled": bool}`; `action.call(index)` |
| `radio_group(options: Array, selected := 0, translate := false)` | `VBoxContainer` | `column.get_meta("group")` is the `ButtonGroup`; `group.get_pressed_button().get_index()` |
| `segmented(options: Array, selected := 0, action := Callable(), translate := false, compact := false)` | `HBoxContainer` | One pressed at a time; `action.call(index)`. An option is a label or `{"text", "icon", "tooltip"}` — an icon beside the label (it takes the label's colour in every state), or alone with a tooltip that doubles as its name. `compact` for tight pills over a map (put it inside a `GoSkin.overlay_box()` panel) |
| `choice_grid(items: Array, selected := 0, action := Callable(), translate := false)` | `HFlowContainer` | Pick one **swatch, icon or text card** (character colours, avatars, difficulty). Item: `{color, icon, texture, text, tooltip}` (a plain string = text card). Picked cell gets a thick accent border (the swatch colour is never tinted). `action.call(index)`; `meta("group")` is the `ButtonGroup`. Always give swatches a `tooltip` — it is their name |
| `tabs(names: Array, selected := 0, translate := false, fill := false)` | `TabBar` | Switch content on `tab_changed(index)`. `fill` spreads the tabs over the whole row (Flutter's fixed tabs; the padding shrinks to 8 dp a side when they do not fit); either way the line under the tabs runs the full width |
| `breadcrumb(items: Array, action := Callable(), translate := false)` | `HBoxContainer` | Last item is the current page; `action.call(index)` |

```gdscript
var quality := GoStyle.segmented(["Low", "Mid", "High"], 1, func(i: int) -> void: settings.quality = i)
var language := GoStyle.select(["English", "한국어", "日本語"], "Language")
language.item_selected.connect(func(i: int) -> void: TranslationServer.set_locale(["en", "ko", "ja"][i]))
var more := GoStyle.dropdown("More", [{"text": "Rename", "icon": GoIconSet.EDIT},
	{"text": "Delete", "icon": GoIconSet.TRASH}], func(i: int) -> void: _on_more(i))
var pill := PanelContainer.new()
pill.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box())
pill.add_child(GoStyle.segmented(["Map", "Quests"], 0, _switch_layer, false, true))
```

## 6. Display

| Signature | Returns | Notes |
|---|---|---|
| `card(accent := Color.TRANSPARENT, border_alpha := -1.0, border_width := -1.0, pad := -1.0, alpha := -1.0)` | `PanelContainer` | Bordered card (`GoCard`); put a `column()` straight in — **the face already pads** (`pad` sets it). 🛑 A `padding()` around that column doubles the padding; `card_body()` is for faces with no padding of their own. With **no arguments it builds no face of its own** — it reads the one the `GoCard` variation draws and multiplies panel opacity into that, so a host theme that redefines `GoCard` keeps its shape (at 100% the override is dropped entirely). `alpha` = face opacity (§7) |
| `chip(text, ink := Color.TRANSPARENT, translate := false, icon := &"", icon_size := -1, urgent := false)` | `PanelContainer` | Status/tag pill; text contrast is corrected automatically. The skin sets its icon, label role and height (`chip_glyph_size`, `chip_text_role`, `chip_height` — 18 dp, 14 sp, 32 dp under Material) |
| `filter_chip(text, selected := false, toggled := Callable(), icon := &"", translate := false)` | `Button` | A chip that **toggles** — several can be on at once (for exactly one, `segmented()`). A check mark while on, `icon` while off; `toggled` gets the new state. `restyle_filter_chip(node)` re-dresses one whose state was set from code without the signal |
| `input_chip(text, removed := Callable(), icon := &"", translate := false)` | `PanelContainer` | An entered value (a recipient, a tag) with a ✕ that calls `removed` and frees the chip |
| `toolbar(items: Array, vertical := false)` | `PanelContainer` | A floating pill of icon actions — items `{"icon", "tooltip", "action"}`; spaced so each 48 dp touch area meets the next |
| `bottom_app_bar(items: Array, fab: GoFab = null)` | `PanelContainer` | The 80 dp bar along the bottom with icon actions at the start and the FAB at the end (Flutter's `BottomAppBar`); grows by the gesture-bar inset |
| `item_card(spec: Dictionary, framed := true)` | `Control` | **The picked item's detail card** — `{icon, ink, accent, title, subtitle, chips: [text \| {text, ink, icon}], body, stats: [[label, value]], actions: [{text, action, tone, icon}], translate}`, every key optional. Parts are named `Icon` `Title` `Subtitle` `Chips` `Body` `Stats` `Actions`. `framed = false` inside a `GoPopover`, a sheet or your own card (no double border); in a sheet give the buttons to `add_footer()` instead of `actions` |
| `avatar(text := "", size := 40, accent := Color.TRANSPARENT, texture: Texture2D = null)` | `Control` | Initials (max 2) or picture in a disc |
| `art(texture: Texture2D = null, size := Vector2.ZERO, fit := Fit.CONTAIN)` | `TextureRect` | Picture cell. The addon owns stretch, alignment and mouse pass-through; the caller owns only *what* is shown, because the artwork belongs to the game. `Fit.CONTAIN` fits it whole, `COVER` fills the cell and crops the overflow, `FILL` stretches it |
| `style_art(node, texture = null, fit := Fit.CONTAIN, keep_when_null := true)` | — | Swap the picture in a cell that already exists. A `null` texture is ignored by default, so a slot waiting on a background load is not blanked; pass `keep_when_null = false` where a missing asset must clear the cell instead of leaving the previous picture on screen |
| `scrim(alpha := -1.0, ink := Color.TRANSPARENT)` | `ColorRect` | Full-rect veil that pushes attention to the card or sheet in front. With no arguments it uses the skin's scrim colour; with an alpha it lays the background colour at that weight. `style_scrim(node, alpha, ink)` restyles one in place — useful when a tween animates `color:a`. 🛑 It leaves `mouse_filter` alone: some veils must swallow taps, others must not |
| `mark(size: Vector2, ink: Color)` | `ColorRect` | A block of colour that *is* the meaning — a legend swatch, an online dot, a stripe down the side of a banner. Unlike `plate` it has no corners and no border |
| `skeleton(width := 0.0, height := 14.0)` | `Control` | Pulsing placeholder; width 0 fills |
| `alert(message, tone := GoTheme.INFO, icon: StringName = &"", translate := false, alpha := -1.0)` | `PanelContainer` | Inline, persistent (unlike `GoNotice`); tone `INFO`/`SUCCESS`/`WARNING`/`DANGER`. A container, so it follows panel opacity (§7) |
| `table(headers: Array, rows: Array)` | `GridContainer` | Cells are strings or Controls |
| `empty_state(icon, key, translate := true)` | `Control` | Never leave a list blank |

```gdscript
var stats := GoStyle.table(["Stat", "Base", "Bonus"], [["Attack", "42", "+6"], ["Defence", "28", "+2"]])
var tile := GoStyle.card(GoUi.color(GoTheme.ACCENT))     # the face pads — the column goes straight in
var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
tile.add_child(inner)
inner.add_child(GoStyle.label("Legendary", GoTheme.ROLE_SUBTITLE))
```

## 7. Surface styleboxes

| Signature | Returns | Notes |
|---|---|---|
| `surface(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0)` | `StyleBox` | **Keeps the preset's shape** (chamfer, forged frame). Prefer this |
| `box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT, alpha := -1.0)` | `StyleBoxFlat` | Always flat — for code that edits `bg_color`/`corner_radius`; loses custom shapes |
| `floating(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT, opaque := false, pad := -1.0, alpha := -1.0)` | `StyleBoxFlat` | Card + shadow for HUD panels. `opaque` fills the face solid and ignores `alpha` |
| `disc(diameter, accent, fill_alpha := 0.14, edge_alpha := 0.38)` | `StyleBoxFlat` | Round badge — a marker, so panel opacity does not apply |
| `fade_panel(node, alpha := -1.0, state := &"panel", variant := GoTheme.BOX_PANEL)` | — | Applies panel opacity to a panel gohud did not build. Call **after** `add_child`; idempotent |
| `forget_face(node, state := &"panel")` | — | Drops `fade_panel`'s memory of the original face — after a theme swap |

Variants: `BOX_PANEL` `BOX_CARD` `BOX_HUD` `BOX_NOTICE` `BOX_POPUP` `BOX_EMPTY` `BOX_FOCUS` `BOX_FOCUS_SOFT`.
Skin-level faces: `GoUi.skin().overlay_box(h_margin := -1, v_margin := -1, fill_alpha := -1.0)` (pill over the
game), `alert_box(ink, alpha := -1.0)`, `chip_box(color)`, `badge_box(ink)`,
`notice_box(accent, compact, alpha := -1.0)`, `surface_box(variant, accent, alpha := -1.0)`.

**`alpha` is the panel face's opacity** (ratio 0.0–1.0; negative = whatever the theme and `GoConfig` decided —
80% by default). Only the background thins out: borders, shadows, glow, text and icons keep full strength.
Containers follow it; buttons, quick slots, badges, chips and segmented cells do not. Full rules, the
five-layer precedence and the percent-vs-ratio trap: `references/theming.md` §4.
🔑 **Drag it before picking a number.** `examples/gallery/opacity_lab.gd` shows the value under a slider over
a pattern, with three panels reached by three different routes; the gallery, the guided tour (chapter 16), the
demo home screen and the medieval example all host that one widget.

```gdscript
var panel := PanelContainer.new()
panel.add_theme_stylebox_override(&"panel", GoStyle.surface(GoTheme.BOX_PANEL))
```

## 8. Helpers

| Signature | Notes |
|---|---|
| `form(node)` | Applies form rules to a subtree (GoForm calls it for you). 🔑 It **fills in only what is unspecified**: a box whose `separation` is not `gap`, a button or field with its own `custom_minimum_size.y`, a label marked `go_no_wrap` — each keeps what its widget chose |
| `one_line(label) -> Label` | Keeps a label on one line inside a `GoForm` too (`AUTOWRAP_OFF` + `go_no_wrap`). 🛑 `AUTOWRAP_OFF` alone is turned back on by the form — a count badge ballooned to 65×65 and a `+` went 1dp wide |
| `fit_words(button)` | Re-run after changing a button's text: one word never wraps, longest word always fits |
| `natural_width(node)` | Keep a control at natural width (used by `wrap_row`) |
| `fit_content_height(control, content)` | Grow a Button/Control to its content's height |
| `fade(canvas_item, previous_tween, shown) -> Tween` | Fade in honouring `reduce_motion` |
| `tooltip_node(text, max_width := 260.0)` | Return from `_make_custom_tooltip()` to avoid one-letter-per-line tooltips |
| `audit_compact_padding(root, include_overrides := false, variations := [GoTheme.VAR_COMPACT_BUTTON]) -> Array[String]` | Lists compact buttons whose padding is below `compact_padding_x` |
| `cell_body(cell, padding := -1, spacing := -1, vertical := -1, square := false) -> VBoxContainer` | 🔑 **The way to stack content inside a `Button` (or any box that is not a container).** Padding (`gap_small`, raised to what the face needs) + a centered column (`gap_tiny`, kept inside `GoForm`), and the box **grows to fit** both ways — it never keeps content on its border or draws it past its edge. Fill it, then `let_input_through(body)` |
| `cell_inset(cell, content, padding := -1, vertical := -1, square := false) -> MarginContainer` | The same for content you built yourself (a row of table cells) |
| `center_in(node) -> Control` | Centers a control on its parent **by its own size** and keeps it centered as it resizes. 🛑 `set_anchors_preset(PRESET_CENTER)` alone puts the control's top-left corner on the center |
| `face_clearance(control) -> int` | Room a box's face needs before content: border, a skin's edge line, what a rounded or cut corner takes |
| `press_feel(button)` | Hands the button's press to the look (`GoSkin.press_feedback`, read at the press). `style_button`, `list_row`, `GoSlot` and `GoIconButton` already call it; connected once |
| `audit_layout(root) -> Array[String]` | 🔎 **Measures a laid-out screen** and lists what is cut by a clipping parent, runs past the side of the screen, reaches outside a non-container parent, is squeezed below its minimum, folds inside a word, sits on its face's side, or is too small to press — plus `audit_cell_layout`. `go_overlay` marks an intentional overhang. Run it a frame or two after the screen enters; text drawn with `draw_string` is invisible to it |
| `audit_cell_layout(root) -> Array[String]` | Lists cells (`cell_body`/`cell_inset`) and centered marks (`center_in`) that break the contract: box smaller than content, padding thinner than the face, content past the padding, text cut or folded, a mark off center. `go_overlay` marks an intentional overhang. Empty over a screen with no such boxes means "not looked at" |

## 9. Form and list widgets (classes, not factories)

These are nodes because they hold state a factory cannot — an error, a sort order, a page, a search.

### GoField — a row that can be wrong

```gdscript
var name_field := GoField.make("Character name", GoStyle.line_edit("2-12"), "Cannot be changed later")
form.add_child(name_field)
name_field.set_error("That name is taken")       # server said no
name_field.clear_error()
```

`GoField.make(label_text, node, hint := "", translate := false)` — 🛑 the opposite default of `GoStyle.field()`
(`translate := true`) · `label` `control` `hint_label` `error_label` · `set_control()` `set_error(msg, translate)`
`clear_error()` `has_error()` `error_text()` · signal `error_changed(message)`.

- 🛑 **The error belongs next to the box.** One "check your input" line at the top of a five-field form does
  not say which field — that single thing is what makes people abandon a sign-up.
- The hint hides while an error shows, so the row does not grow by a line and push everything below it.
- ♿ The error text is joined into the control's `accessibility_name` — a red border alone says nothing to
  someone who cannot see red.
- 🔑 `GoStyle.field()` is the **static** version: label + control + hint, no error state. Use it when nothing
  can go wrong; use `GoField` for anything a server can reject.

### GoInputGroup — welded input and button

```gdscript
GoInputGroup.make(GoStyle.line_edit("Message"), {"suffix": GoStyle.icon_button(GoGameIcons.SEND, send)})   # needs GoGameIcons.icon_set() as the icon set
GoInputGroup.make(GoStyle.line_edit("Name"), {"prefix_icon": &"search"})
GoInputGroup.make(qty, {"prefix": minus, "suffix": plus})
```

Keys: `prefix` · `suffix` (any `Control`) · `prefix_icon` · `suffix_icon` (a mark you cannot press).

The problem it solves is **corners**: two rounded shapes meeting in the middle look pinched, and the default
gap makes them read as two objects. Separation is 0 on purpose, outer corners stay round, touching ones go
square — in **every** button state, or the group splits the moment it is pressed. Skins that draw their own
faces (`GoStyleBoxCut`) have no corner fields, so the group leaves them alone; square faces meet cleanly.

### GoCombobox — a picker with search

```gdscript
var picker := GoCombobox.make(server_names, 0, "Choose a server")
picker.picked.connect(func(i: int) -> void: connect_to(servers[i]))
GoCombobox.make([{"text": "Flame sword", "icon": &"sword", "hint": "ATK +12"}])
```

`GoCombobox.make(items, selected := -1, hint := "")` — an entry is a `String` or `{"text", "icon", "hint", "disabled"}` ·
`placeholder` · `search_threshold` 8 · `list_width` · `picked(index)` · `select(i, notify)` `selected()`
`selected_text()` `set_items()` `items()`.

- Under ten entries `GoStyle.select()` is better — one less tap and the whole list is visible. Past thirty,
  scanning is work; that is this widget.
- 🛑 The search matches **inside** names, not just their start: prefix matching finds almost nothing in
  Korean or Japanese lists, where the distinguishing word is rarely first.
- Rows never auto-translate — entries are player names and item names.
- An empty result shows an empty state; a blank panel reads as broken.

### GoCodeInput — coupon and gift codes

```gdscript
var coupon := GoCodeInput.make(12, 4)
coupon.completed.connect(func(code: String) -> void: server.redeem(code))
coupon.set_error("Already used")
```

`length` 12 · `group` 4 · `allowed` · `uppercase` · `cell_width` · `edit` `cells_row` `error_label`
· signals `completed(code)` `changed(code)` · `GoCodeInput.make(digits := 12, group_size := 4)` · `set_code()` `code()`
`clear()` `is_complete()` `focus()` `set_error()` `has_error()`.

- 🛑 **One hidden `LineEdit` receives the text; the cells are drawn.** Twelve real fields would break pasting
  at the first cell and lose characters to an IME — and a code is pasted from a message far more often than
  it is typed. `ABCD-EFGH-IJKL` loses its dashes on the way in.
- 🔑 **The groups fold onto the next line when the row does not fit** — `ABCD EFGH` / `IJKL`, never a group split and never
  a character squeezed. Twelve cells in one row needed 404 dp, past a 390 dp phone's body. `cells_row` is a flow row.

### GoTable — sortable, selectable rows

```gdscript
var board := GoTable.make(
	[{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}], rows)
board.row_selected.connect(func(i: int) -> void: open_profile(rows[i]))
board.sort_by(2, false)
```

Column keys: `text` · `width` · `numeric` · `sortable` · `translate`.
`GoTable.make(columns, rows, selectable := true)` · `sort_by(column, ascending := true)` · `head` `rows_box` · signals
`row_selected(index)` `sorted(column, ascending)` · `set_rows()` `set_columns()` `selected()` `rows()`.

- 🛑 **`numeric: true` or the ranking inverts** — compared as text, `"9124"` beats `"91240"`. Scores, gold
  and damage all have mixed digit counts.
- `row_selected` gives the index in **your original array**, not the sorted position.
- The sort direction is shown with a glyph (▲▼), not only a colour, and whole rows are pressable so nobody
  has to hit one cell. Ties keep their original order, so a leaderboard does not shuffle every frame.
- 🔑 `GoStyle.table()` is the read-only grid. Use it when nothing is pressed or sorted.
- 🛑 Four columns is the practical limit on a phone; beyond that open a row in a `GoSheet` instead.

### GoPagination — pages

```gdscript
var pager := GoPagination.make(1, 12, func(page: int) -> void: load_mail(page))
pager.set_total(server_pages)
pager.set_busy(true)                       # while the request is in flight
var more := GoPagination.more(load_next)   # the mobile-friendly variant
```

`window` 5 (the most) · signals `page_changed(page)` `more_requested` · `page()` `total()` `set_page(v, notify)`
`set_total()` `set_busy()` `is_busy()`.

- 🔑 **It fits the width it is given.** Numbers are 48 dp touch cells, so a narrow row shows fewer (down to 3), and
  when not even three fit it reads `‹ 5 / 12 ›`. Its minimum width is that compact form — it never drags a page wider
  than the screen (a 12-page pager once needed 457 dp and cut a 390 dp phone's whole page).

- Numbers are a mouse UI; on a phone `more()` reads better. The current page stays **centred** in the window,
  so pressing next does not reshuffle every number.
- `total = 0` means "unknown" — only the arrows are drawn. Do not invent a page count you were not given.
- `set_busy(true)` locks the buttons while a request is out, so two taps cannot skip a page.

## 10. Lower-level functions

The functions above build whole controls. These style a node you already have, return a bare face, or handle a
case the factories do not — a sign-in button whose measures a platform's guideline fixes, a label pinned by anchors,
a face whose colour changes at runtime without rebuilding the node. Reach for them when a factory almost fits.

### Text and glyphs

| Signature | Notes |
|---|---|
| `line(text: String, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> Label` | A one-line label — never wraps, and cuts the overflow with an ellipsis (…). |
| `font_role(node: Control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT) -> void` | Sets the font size (and color) only from a role token — `theme_type_variation` is left alone. |
| `text_shadow(node: Control, ink := Color.TRANSPARENT, offset_y := 1, offset_x := -1) -> void` | Text shadow — lays a shadow one step behind text that sits straight on the world, on art or on a photo, so it does not sink into the background (HUD names and levels, text floating with no face). |
| `pin_font_size(node: Control, size: int) -> void` | Pins the font size in pixels — only where the spec comes from outside (an official sign-in button whose guideline is a text-to-height ratio, say). |
| `glyph_text(node: Control, icons: Array, size := -1, ink := Color.TRANSPARENT, set: GoIconSet = null) -> void` | Makes the node's own text the icon glyph — swaps the font for the icon set's and puts the glyph in `text`. |
| `glyph_width(icons: Array, size := -1, set: GoIconSet = null) -> float` | The width (dp) of the text `glyph_text()` would draw. |
| `glyph_type(node: Control, size := -1, ink := Color.TRANSPARENT, states := true) -> void` | Restyles only the size and color of a node that already holds a glyph — for moving the color of an icon drawn once by `glyph_text()` on every state change (pressed, hovered, toggled on) without looking it up again. |
| `style_mono_text(node: RichTextLabel, font: Font, selection := Color.TRANSPARENT, selected_ink := Color.TRANSPARENT) -> void` | A monospace text box — for diagnostics codes and logs, where characters must line up and the reader must be able to select and copy them. |

### Form rows and spacing

| Signature | Notes |
|---|---|
| `field(key: String, control: Control, hint := "", translate := true) -> Control` | A label + its input as one group. Builds one row (a field) of a form. |
| `spacing(node: Container, horizontal: int, vertical := -9999) -> void` | Spacing given directly as a value — only for HUD geometry no token expresses. |

### Panels and plates you place yourself

| Signature | Notes |
|---|---|
| `hud_panel(accent := Color.TRANSPARENT, pad_x := -1.0, pad_y := -1.0, variant := GoTheme.BOX_HUD, alpha := -1.0) -> PanelContainer` | One face floating above the game screen — for things laid over the world like a HUD dock or a status bar (the caller fills the content). |
| `overlay_panel(pad_x := -1, pad_y := -1, fill_alpha := -1.0) -> PanelContainer` | One pill face laid over a map or over world art — it lays a dark background and a thin border so the text is readable whatever the art behind it is (`GoSkin.overlay_box`). |
| `chip_panel(accent := Color.TRANSPARENT, fill_alpha := -1.0) -> PanelContainer` | An empty container filling the same pill face as a chip — for places a one-line chip cannot serve (a roster card carrying a name, a level and a gauge together). |
| `disc_panel(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> PanelContainer` | A disc cell — a container wearing the `disc()` face. |
| `edge_card_panel(accent: Color, rtl := false, pad := -1.0, alpha := -1.0) -> PanelContainer` | A container wearing that stripe card face — the caller fills the content (the stripe counterpart of `card()`). |
| `plate(variant := GoTheme.BOX_HUD, fill := Color.TRANSPARENT, edge := Color.TRANSPARENT, radius := -1.0, border := -1.0, alpha := -1.0) -> Panel` | One backing cell — a face that holds no content and is laid behind things (the tint cell of a portrait slot, a HUD surface that looks smaller than its touch cell). |
| `bare_panel(node: Control) -> void` | A container that draws no face — place, stacking and spacing stay; only background, border, shadow and padding go. |

### Faces as StyleBoxes and face tuning

| Signature | Notes |
|---|---|
| `edge_card(accent: Color, rtl := false, width := -1.0, alpha := -1.0) -> StyleBoxFlat` | A card face with a semantic stripe on one edge only — shows state in a list without stacking blocks of color. |
| `face_padding(face: StyleBox, pad_x := -1.0, pad_y := -1.0) -> void` | Sets a face's inner padding to the given values — a negative side keeps the value the face has. |
| `face_insets(face: StyleBox, left := -1.0, top := -1.0, right := -1.0, bottom := -1.0) -> void` | Sets a face's four sides separately — a negative side is left alone. |
| `style_panel(node: Control, face: StyleBox, state := &"panel") -> void` | Applies one face to any node you already built — gohud makes the face, the caller decides where it goes. |
| `touch_face(button: Button, height := 38.0, face: StyleBox = null) -> Panel` | A visible face smaller than the press area — lays one face inside a button and has it follow the button's width. |

### Restyling a node you already built (no rebuild when its state colour changes)

| Signature | Notes |
|---|---|
| `style_hud_panel(node: PanelContainer, accent := Color.TRANSPARENT, pad_x := -1.0, pad_y := -1.0, variant := GoTheme.BOX_HUD, alpha := -1.0) -> void` | Applies the same floating face to a `PanelContainer` you already built — so places whose semantic color changes at runtime (an EXP badge turning green, orange or gray by its value) never rebuild the node. |
| `style_overlay_panel(node: PanelContainer, pad_x := -1, pad_y := -1, fill_alpha := -1.0) -> void` | Applies the same pill face to a `PanelContainer` you already built. |
| `style_notice_panel(node: Control, accent := Color.TRANSPARENT, tint := 0.0, padding := -1, alpha := -1.0) -> void` | Applies a notice face to a container you already built — the error or warning box that settles into the screen (to build a new one, see `alert()`). |
| `style_disc_panel(node: Control, diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> void` | Applies the same disc to a face you already built (`Panel`, `PanelContainer`) — for places that must not rebuild the node every time the semantic color changes (the preview disc whose border follows the gender you pi |
| `style_disc_label(node: Label, diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> void` | Applies a disc to a label you already built — for when the place is pinned with anchors and offsets, like a number badge, and `disc_panel()`'s container cannot be used (the round counterpart of `style_chip_label()`). |
| `style_hud_disc(node: Control, diameter: float, edge_width := 0.0, edge_ink := Color.TRANSPARENT, fill := Color.TRANSPARENT, detail := 1, accent := Color.TRANSPARENT) -> StyleBox` | The disc face of a HUD round button — the face of the round icon buttons floating over the game screen (control pads, utility rows). |
| `style_slot_face(node: Control, accent: Color, lit := false) -> void` | Applies the quick-slot face to a node — a host that built its own slots instead of using `GoSlot` (a game whose rows inside the cell differ) gets the same face. |
| `style_count_badge(node: Label, fill: Color, ink := Color.TRANSPARENT, edge := Color.TRANSPARENT, edge_width := 0, radius := -1, pad_x := -1.0, detail := 1) -> void` | A solid badge — one cell for a number that must be noticed, like a count or an alert. |
| `restyle_chip(node: PanelContainer, ink: Color, urgent := false) -> void` | Restyles the face only of a chip you already built — so places that refresh often never rebuild the node (a roster whose party leader changed, a mark counting a remaining time down). |
| `style_chip_label(node: Label, accent: Color, urgent := false) -> void` | Applies a chip face to a label you already built — for when `chip()`'s container cannot be used, as where the caller measures the width itself to place the cell (a badge on the HUD status bar). |
| `style_chip_button(node: Button, accent: Color, fill_alpha := -1.0, urgent := false) -> void` | A button shaped like a chip — puts the tinted pill face on every state. |
| `style_disc_button(node: Button, diameter: float, accent: Color, fill := Color.TRANSPARENT, fill_alpha := 0.92, press_alpha := 0.34) -> void` | A round control button — puts the state faces on the round buttons floating over art, like a map's zoom ＋/－ or "my location". |
| `style_overlay_button(node: Button, accent: Color, fill_alpha := 0.10) -> void` | A press area laid over a face — the transparent button laid on a card when the whole card is one tap. |
| `style_choice_card(node: Button, accent: Color, selected := false, toggle := true, dim_disabled := true, filter := -1) -> void` | A choice card. Puts a face per state on one button — only the chosen card gets the semantic border and a faint fill, and hovering stains the border alone. |
| `tint_button(node: Button, ink := Color.TRANSPARENT, active := Color.TRANSPARENT) -> void` | Sets text and icon color only, with no face — buttons that draw no background and say their state in color alone (link rows, quiet menus). |
| `style_popup(popup: PopupMenu, spacing := -1, alpha := -1.0) -> void` | Spreads the rows of a popup menu so its items keep the touch floor — popup text is body size, which makes the rows thinner than a finger. |

### Buttons whose spec comes from outside

| Signature | Notes |
|---|---|
| `style_brand_button(node: Button, fill: Color, ink: Color, edge: Color, mark := -1, gap := -1, inset := -1.0, base: StyleBox = null, mark_ink := Color.WHITE) -> void` | A brand button whose spec comes from outside — a platform provider's sign-in button (Sign in with Google, Apple …), where face color, border and mark size are nailed down by review guidelines. |
| `center_button_content(node: Button, min_inset := -1.0) -> float` | Stands mark and text together in the middle of the face — the shape of the providers' own buttons. |
