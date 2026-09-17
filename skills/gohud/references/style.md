# GoStyle — the control factory (every function)

`class_name GoStyle extends RefCounted`, all `static`. Source: `widgets/go_style.gd`.
Rules it enforces: sizes come from tokens (`GoUi.metric`), touch targets ≥ `min_touch_size`, long text wraps
by words (never one letter per line), buttons inside scrolls pass drags to the scroll.

**Text vs key:** `label` / `button` show text as written (`AUTO_TRANSLATE_MODE_DISABLED`); `label_key` /
`button_key` hold a translation key and re-translate on locale change. Functions with a `translate` flag
follow the same idea.

## Contents

1. [Structure](#1-structure)
2. [Text](#2-text)
3. [Buttons](#3-buttons)
4. [Input](#4-input)
5. [Selection and navigation](#5-selection-and-navigation)
6. [Display](#6-display)
7. [Surface styleboxes](#7-surface-styleboxes)
8. [Helpers](#8-helpers)

## 1. Structure

| Signature | Returns | Notes |
|---|---|---|
| `column(spacing := -1)` | `VBoxContainer` | -1 → `gap`; expands horizontally |
| `row(spacing := -1)` | `HBoxContainer` | |
| `wrap_row(spacing := -1, alignment := FlowContainer.ALIGNMENT_BEGIN, last_line := FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN)` | `HFlowContainer` | Children get natural width automatically — chips, tags, button groups |
| `padding(amount := -1)` | `MarginContainer` | -1 → `padding` token on all sides |
| `insets(margin_container, amount := -1)` | void | Same, on an existing node |
| `gap(container, token := GoTheme.GAP)` | void | Sets separation (h/v for Grid/Flow) |
| `spacer(minimum := 0.0)` | `Control` | Expands; pushes siblings apart |
| `divider(vertical := false)` | `Control` | 1 dp line in the skin's divider colour (not `HSeparator`) |
| `responsive_grid(min_cell_width := 160.0, spacing := -1)` | `GridContainer` | Column count = floor(width / cell) on every resize; children forced to expand |
| `aspect(ratio := 1.0)` | `AspectRatioContainer` | Thumbnails, portraits, minimap |
| `foldable(title, folded := false, group: FoldableGroup = null, translate := true)` | `FoldableContainer` | Same `FoldableGroup` = accordion. Add one content child |

## 2. Text

| Signature | Returns | Notes |
|---|---|---|
| `label(text, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT)` | `Label` | Wraps when `autowrap_text`; ignores mouse |
| `label_key(key, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT)` | `Label` | Translated |
| `section(text_or_key, translate := true)` | `Label` | Small muted heading; skin may decorate (`section_box`) |
| `typography(control, role := GoTheme.ROLE_BODY, ink := Color.TRANSPARENT)` | void | Apply a role to any Label/Button/RichTextLabel (via type variation, so it follows theme changes) |

Roles: `ROLE_MICRO` `ROLE_COMPACT` `ROLE_CAPTION` `ROLE_BODY` `ROLE_BUTTON` `ROLE_SUBTITLE` `ROLE_TITLE`.
Ink: pass a colour, usually `GoUi.color(GoTheme.MUTED)` / `SECONDARY` / a status colour.

## 3. Buttons

`enum Tone { NORMAL, PRIMARY, DANGER, BARE, COMPACT, DANGER_SOLID }` — PRIMARY for the main action,
DANGER tinted, DANGER_SOLID filled (irreversible confirm), BARE text-only, COMPACT small pill (touch height).

| Signature | Returns | Notes |
|---|---|---|
| `button(text, action := Callable(), tone := Tone.NORMAL)` | `Button` | Non-compact tones expand horizontally and use `button_height` |
| `button_key(key, action := Callable(), tone := Tone.NORMAL)` | `Button` | |
| `style_button(button, tone := Tone.NORMAL)` | void | Style a Button from a scene |
| `icon_button(icon, action := Callable(), visual := -1, tooltip_key: StringName = &"")` | `GoIconButton` | Always give `tooltip_key` (tooltip + accessible name): a gohud name (`close`), **your own translation key**, or plain words — all go through the translation server. Over gameplay set `keyboard_focus = false` on the result |
| `apply_icon(button, icon, size := -1, ink := Color.TRANSPARENT)` | void | Texture sets use `Button.icon`; font sets add a child label |
| `list_button(icon, key, action := Callable(), ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"")` | `Button` | Menu/settings row: icon, title, optional description line, optional trailing icon (e.g. `CHEVRON_RIGHT`). Whole row is the tap target |
| `list_row(button, icon, key, …same…)` | `Button` | Same, on an existing Button |
| `restyle_list_row(button, selected: bool, accent := Color.TRANSPARENT)` | void | Marks a list row as **the chosen one** (tint + 2 dp border, like a chosen `style_choice_card`) or clears it. Face only — call it again when the pick moves; never call `list_row` twice on one button |

🛑 `list_button(..., translate := true)` treats `key` as a translation key. For literal text pass
`translate = false` (the sixth argument) — otherwise an untranslated key simply shows as typed, but a key that
*does* exist in your tables gets replaced.

## 4. Input

| Signature | Returns | Notes |
|---|---|---|
| `line_edit(placeholder := "", translate_placeholder := false)` | `LineEdit` | `button_height` tall. Set `secret = true` for passwords |
| `textarea(placeholder := "", lines := 4, translate_placeholder := false)` | `TextEdit` | Word wrap, scrolls inside |
| `toggle(key := "", translate := true)` | `CheckButton` | Switch; `button_pressed` to set |
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
| `tabs(names: Array, selected := 0, translate := false)` | `TabBar` | Switch content on `tab_changed(index)` |
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
| `card(accent := Color.TRANSPARENT, border_alpha := -1.0, border_width := -1.0, pad := -1.0, alpha := -1.0)` | `PanelContainer` | Bordered card (`GoCard`); add a padding/column child. With **no arguments it builds no face of its own** — it reads the one the `GoCard` variation draws and multiplies panel opacity into that, so a host theme that redefines `GoCard` keeps its shape (at 100% the override is dropped entirely). `alpha` = face opacity (§7) |
| `chip(text, ink := Color.TRANSPARENT, translate := false)` | `PanelContainer` | Status/tag pill; text contrast is corrected automatically |
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
var tile := GoStyle.card(GoUi.color(GoTheme.ACCENT))
var inner := GoStyle.padding()
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
| `form(node)` | Applies form rules to a subtree (GoForm calls it for you) |
| `fit_words(button)` | Re-run after changing a button's text: one word never wraps, longest word always fits |
| `natural_width(node)` | Keep a control at natural width (used by `wrap_row`) |
| `fit_content_height(control, content)` | Grow a Button/Control to its content's height |
| `fade(canvas_item, previous_tween, shown) -> Tween` | Fade in honouring `reduce_motion` |
| `tooltip_node(text, max_width := 260.0)` | Return from `_make_custom_tooltip()` to avoid one-letter-per-line tooltips |
| `audit_compact_padding(root, include_overrides := false, variations := [GoTheme.VAR_COMPACT_BUTTON]) -> Array[String]` | Lists compact buttons whose padding is below `compact_padding_x` |

## 9. Form and list widgets (classes, not factories)

These are nodes because they hold state a factory cannot — an error, a sort order, a page, a search.

### GoField — a row that can be wrong

```gdscript
var name_field := GoField.make("Character name", GoStyle.line_edit("2-12"), "Cannot be changed later")
form.add_child(name_field)
name_field.set_error("That name is taken")       # server said no
name_field.clear_error()
```

`label` `control` `hint_label` `error_label` · `set_control()` `set_error(msg, translate)` `clear_error()`
`has_error()` `error_text()` · signal `error_changed(message)`.

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

`placeholder` · `search_threshold` 8 · `list_width` · `picked(index)` · `select(i, notify)` `selected()`
`selected_text()` `set_items()`.

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
· signals `completed(code)` `changed(code)` · `set_code()` `code()` `clear()` `is_complete()` `focus()`.

- 🛑 **One hidden `LineEdit` receives the text; the cells are drawn.** Twelve real fields would break pasting
  at the first cell and lose characters to an IME — and a code is pasted from a message far more often than
  it is typed. `ABCD-EFGH-IJKL` loses its dashes on the way in.
- Cells share the leftover width, so twelve of them still fit a 720 dp phone.

### GoTable — sortable, selectable rows

```gdscript
var board := GoTable.make(
    [{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}], rows)
board.row_selected.connect(func(i: int) -> void: open_profile(rows[i]))
board.sort_by(2, false)
```

Column keys: `text` · `width` · `numeric` · `sortable` · `translate`.
`head` `rows_box` · signals `row_selected(index)` `sorted(column, ascending)` · `set_rows()` `set_columns()`
`selected()` `rows()`.

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

`window` 5 · signals `page_changed(page)` `more_requested` · `page()` `total()` `set_page(v, notify)`
`set_total()` `set_busy()` `is_busy()`.

- Numbers are a mouse UI; on a phone `more()` reads better. The current page stays **centred** in the window,
  so pressing next does not reshuffle every number.
- `total = 0` means "unknown" — only the arrows are drawn. Do not invent a page count you were not given.
- `set_busy(true)` locks the buttons while a request is out, so two taps cannot skip a page.
