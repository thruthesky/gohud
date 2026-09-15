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
| `icon_button(icon, action := Callable(), visual := -1, tooltip_key: StringName = &"")` | `GoIconButton` | Always give `tooltip_key` (tooltip + accessible name) |
| `apply_icon(button, icon, size := -1, ink := Color.TRANSPARENT)` | void | Texture sets use `Button.icon`; font sets add a child label |
| `list_button(icon, key, action := Callable(), ink := Color.TRANSPARENT, sub_key := "", translate := true, trailing: StringName = &"")` | `Button` | Menu/settings row: icon, title, optional description line, optional trailing icon (e.g. `CHEVRON_RIGHT`). Whole row is the tap target |
| `list_row(button, icon, key, …same…)` | `Button` | Same, on an existing Button |

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
| `segmented(options: Array, selected := 0, action := Callable(), translate := false, compact := false)` | `HBoxContainer` | One pressed at a time; `action.call(index)`. `compact` for tight pills over a map (put it inside a `GoSkin.overlay_box()` panel) |
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
| `card(accent := Color.TRANSPARENT)` | `PanelContainer` | Bordered card (`GoCard`); add a padding/column child |
| `chip(text, ink := Color.TRANSPARENT, translate := false)` | `PanelContainer` | Status/tag pill; text contrast is corrected automatically |
| `avatar(text := "", size := 40, accent := Color.TRANSPARENT, texture: Texture2D = null)` | `Control` | Initials (max 2) or picture in a disc |
| `skeleton(width := 0.0, height := 14.0)` | `Control` | Pulsing placeholder; width 0 fills |
| `alert(message, tone := GoTheme.INFO, icon: StringName = &"", translate := false)` | `PanelContainer` | Inline, persistent (unlike `GoNotice`); tone `INFO`/`SUCCESS`/`WARNING`/`DANGER` |
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
| `surface(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT)` | `StyleBox` | **Keeps the preset's shape** (chamfer, forged frame). Prefer this |
| `box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT)` | `StyleBoxFlat` | Always flat — for code that edits `bg_color`/`corner_radius`; loses custom shapes |
| `floating(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT)` | `StyleBoxFlat` | Card + shadow for HUD panels |
| `disc(diameter, accent, fill_alpha := 0.14, edge_alpha := 0.38)` | `StyleBoxFlat` | Round badge |

Variants: `BOX_PANEL` `BOX_CARD` `BOX_HUD` `BOX_NOTICE` `BOX_POPUP` `BOX_EMPTY` `BOX_FOCUS` `BOX_FOCUS_SOFT`.
Skin-level faces: `GoUi.skin().overlay_box(h_margin := -1, v_margin := -1, fill_alpha := 0.82)` (pill over the
game), `alert_box(ink)`, `chip_box(color)`, `badge_box(ink)`.

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
