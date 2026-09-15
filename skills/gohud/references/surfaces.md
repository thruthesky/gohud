# Surfaces — GoSurface, GoSheet, GoDialogs, GoForm, GoScroll

Source: `widgets/go_surface.gd`, `widgets/go_sheet.gd`, `services/go_dialogs.gd`, `widgets/go_form.gd`,
`widgets/go_scroll.gd`. Web: https://thruthesky.github.io/gohud/docs/www/widgets.html#surfaces

## Contents

1. [GoSurface — the floating window shell](#1-gosurface)
2. [GoSheet — bottom sheet pages](#2-gosheet)
3. [GoDialogs — await confirm / alert](#3-godialogs)
4. [GoForm — width-capped, keyboard-safe forms](#4-goform)
5. [GoScroll — touch scrolling](#5-goscroll)
6. [Subclass hooks](#6-subclass-hooks)
7. [Which one to use](#7-which-one-to-use)

## 1. GoSurface

`class_name GoSurface extends Control`. Popups, sheets and dropdowns all use it. Children are built in
`_init`, so `set_title()` and `body.add_child()` work **before** the node enters the tree. Options set between
`new()` and `add_child()` are applied in `_ready`.

| Member | Notes |
|---|---|
| signals | `close_requested` · `back_requested` · `height_changed(ratio: float)` |
| `enum Placement { CENTER, BOTTOM, ANCHOR }` | `placement` (CENTER) |
| size | `max_width` / `max_height` / `height_ratio` (0 = GoConfig value) · `fit_content` (true — short content, short card) · `compact` (smaller padding) |
| behaviour | `dismiss_on_scrim` (config default) · `scrim_transparent` · `fade_in` · `resizable` (drag the title) · `show_header` (true) · `scroll_body` (true) · `close_enabled` (true) · `initial_focus: Control` |
| anchor | `anchor_control` · `anchor_width` (320) · `anchor_min_width` (210) · `anchor_max_height` (520) — opens below, or above when there is more room |
| parts | `card` PanelContainer · `header` HBox · `title_label` · `close_button` GoIconButton · `back_button` · `scroll` GoScroll (**created in `_ready`**) · `body` VBox · `toolbar` VBox (hidden) · `footer` VBox (hidden) |
| methods | `set_title(text)` · `set_title_key(key)` · `set_back(callable)` (empty Callable hides) · `clear()` · `request_close()` · `is_top()` · `relayout()` · `content_inset()` · `section_gap()` · `attach_resize_handle(control)` |
| static | `GoSurface.is_any_open() -> bool` — pause gameplay input while true |

🛑 It never frees itself. The owner reacts to `close_requested` (hide, `queue_free`, save first…).
🛑 Put it inside a `CanvasLayer` so it draws above the game and HUD. Escape / Android Back closes only the
topmost visible surface (compares CanvasLayer order, then tree order).

```gdscript
func open_settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var surface := GoSurface.new()
	surface.set_title("Settings")
	surface.dismiss_on_scrim = true
	surface.close_requested.connect(layer.queue_free)          # frees surface too
	surface.body.add_child(GoStyle.toggle("Vibration", false))
	surface.body.add_child(GoStyle.slider(0.0, 1.0, 0.05))
	surface.footer.add_child(GoStyle.button("Done", surface.request_close, GoStyle.Tone.PRIMARY))
	surface.footer.visible = true                              # sticky: never scrolls away
	layer.add_child(surface)
```

Anchored context menu (no header, transparent scrim, closes on outside tap):

```gdscript
func open_menu(anchor: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var menu := GoSurface.new()
	menu.placement = GoSurface.Placement.ANCHOR
	menu.anchor_control = anchor
	menu.show_header = false
	menu.scrim_transparent = true
	menu.dismiss_on_scrim = true
	menu.close_requested.connect(layer.queue_free)
	for spec in [[GoIconSet.EDIT, "Rename"], [GoIconSet.COPY, "Duplicate"], [GoIconSet.TRASH, "Delete"]]:
		menu.body.add_child(GoStyle.list_button(spec[0], spec[1], func() -> void:
			layer.queue_free()
			_on_menu(spec[1]), Color.TRANSPARENT, "", false))
	layer.add_child(menu)
```

Sub-pages inside one surface: `surface.clear()`, rebuild `body`, `surface.set_title(...)`,
`surface.set_back(_show_list)`; call `surface.set_back(Callable())` on the root page.

## 2. GoSheet

`class_name GoSheet extends CanvasLayer` — wraps a `GoSurface` with `placement = BOTTOM`, `fit_content`,
`resizable`. Its layer becomes 10 when left at 1, so it sits above a HUD on a lower layer.

| Member | Notes |
|---|---|
| signals | `closed` · `page_changed` |
| vars | `body` (scrolls) · `surface` · `dismissable` (true — set false for trade/irreversible screens) · `height_ratio` (0.6) |
| `open(title)` / `open_key(key)` | Shows the sheet, clears `body`, hides back button, **frees toolbar children**, hides toolbar and footer |
| `set_title(text)` | Title only — for list → detail inside one sheet |
| `toolbar()` / `footer()` | Sticky rows under the header / at the bottom. Set `.visible = true` after adding |
| `set_back(callable)` · `clear()` · `close()` | `close()` hides (does not free) and emits `closed` |

🛑 `open()` does **not** free `footer()` children — it only hides the footer. Re-opening and adding another
Close button stacks duplicates. Clear it yourself:

```gdscript
func show_inventory(items: Array) -> void:
	sheet.open("Inventory")
	for old in sheet.footer().get_children(): old.queue_free()
	sheet.toolbar().add_child(GoStyle.line_edit("Search…"))
	sheet.toolbar().visible = true
	if items.is_empty():
		sheet.body.add_child(GoStyle.empty_state(GoIconSet.BAG, "Your bag is empty", false))
	for item in items:
		sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, item.name, show_item.bind(item),
			Color.TRANSPARENT, item.description, false, GoIconSet.CHEVRON_RIGHT))
	sheet.footer().add_child(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))
	sheet.footer().visible = true

func show_item(item) -> void:
	sheet.clear()
	sheet.set_title(item.name)
	sheet.set_back(show_inventory.bind(all_items))
	sheet.body.add_child(GoStyle.label(item.description))
```

## 3. GoDialogs

`class_name GoDialogs extends Node`. One reusable window on its own `CanvasLayer` (layer 100).

| Member | Notes |
|---|---|
| `confirm(title, body, ok_text := "", cancel_text := "", extra := "", args := {}, destructive := false) -> bool` | `await` it. Empty texts use the translated built-in "Confirm"/"Cancel" |
| `confirm_key(title_key, body_key, ok_key := "", cancel_key := "", extra := "", args := {}, destructive := false) -> bool` | Translation keys |
| `alert(title, body, ok_text := "", extra := "", args := {})` · `alert_key(...)` | One button; `await` returns when dismissed |
| `@export layer_index` (100) · `max_width` (420) · `action_layout` · `action_gap` (-1 → `gap_small`) · `body_gap` (-1) | Set before `add_child` |
| `enum ActionLayout { VERTICAL, HORIZONTAL, AUTO }` | AUTO = one row only if both labels fit half the card |
| `set_next_action_layout(layout)` · `is_open()` · signal `answered(yes)` | One-shot layout for the next dialog |

- `destructive = true` draws the confirm button as `Tone.DANGER_SOLID` (filled red, legible on light themes).
- A second `confirm()` while one is open returns `false` immediately; `alert()` returns immediately.
- The header X counts as Cancel on `confirm`, as OK on `alert`.
- 🛑 `{name}` placeholders are filled only through `args` — `tr()` alone leaves `{name}` on screen.

```gdscript
@onready var dialogs := GoDialogs.new()

func _ready() -> void:
	dialogs.action_layout = GoDialogs.ActionLayout.AUTO
	add_child(dialogs)

func delete_character(name: String) -> void:
	var yes := await dialogs.confirm("Delete character", "Delete \"{name}\"? This cannot be undone.",
		"Delete", "Keep", "", {"name": name}, true)
	if yes:
		await dialogs.alert("Deleted", "{name} is gone.", "OK", "", {"name": name})
```

## 4. GoForm

`class_name GoForm extends MarginContainer`. Full-rect; side margins = max(padding, (usable width − cap) / 2)
using `form_max_width_*` per breakpoint; bottom margin grows with the virtual keyboard.

| Member | Notes |
|---|---|
| structure | `GoForm` → `GoScroll` (node **name "Scroll"**, which `GoScroll.new()` already sets) → `VBoxContainer` |
| `scroll` | Found in `_ready`; when the keyboard opens the focused field scrolls into view |
| `@export min_side_margin` (-1 → `padding`) · `min_edge_margin` (-1 → `screen_margin`) | |
| `@export route_back_button` (true) | Android Back presses the descendant with unique name `%BackButton` (hides the keyboard first) |
| `@export avoid_hud` (false) | Keep content clear of visible `GoHudAnchor`s with `reserve_space`, stepping the cheapest direction |

It applies `GoStyle.form()` to every descendant, now and later: labels wrap, buttons get `button_height`
and word-safe wrapping, plain `Button`s get the normal style, `LineEdit`s get `button_height`.

🛑 Build `GoForm → GoScroll → column` **before** the form enters the tree. `_ready` runs inside `add_child`;
a scroll added afterwards is never found, so keyboard follow and the scrollbar gutter are lost (descendants
still get styled).

🛑 `%BackButton` must be owned by an **ancestor of the form** — a `.tscn` root does this automatically. In code,
`owner = form` does **not** work: `GoForm._ready` moves the scroll branch into its gutter frame
(`use_panel_edge`) and that reparent clears an owner equal to the form (measured on 4.7.2: owner becomes null,
back routing silently off). Setting the owner after `add_child` is too late — the form looks it up once in `_ready`.
Assemble the screen in a holder that is not in the tree yet and let the holder own the button:

```gdscript
func build_login() -> void:
	var holder := Control.new()                       # owns %BackButton; not in the tree yet
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var form := GoForm.new()
	var scroll := GoScroll.new()
	var column := GoStyle.column()
	holder.add_child(form)
	form.add_child(scroll)
	scroll.add_child(column)
	column.add_child(GoStyle.label("Sign in", GoTheme.ROLE_TITLE))
	var email := GoStyle.line_edit("Email")
	var password := GoStyle.line_edit("Password")
	password.secret = true
	column.add_child(email)
	column.add_child(password)
	column.add_child(GoStyle.checkbox("Remember me", false))
	column.add_child(GoStyle.button("Sign in", _sign_in.bind(email, password), GoStyle.Tone.PRIMARY))
	var back := GoStyle.button("Back", _go_back, GoStyle.Tone.BARE)
	back.name = "BackButton"
	column.add_child(back)
	back.owner = form                   # %BackButton is looked up among nodes the form owns…
	back.unique_name_in_owner = true    # …so set both BEFORE the form enters the tree
	add_child(form)                     # _ready runs here: finds Scroll and %BackButton
```

## 5. GoScroll

`class_name GoScroll extends ScrollContainer`. Vertical by default, `follow_focus`, deadzone from tokens,
buttons inside get `MOUSE_FILTER_PASS` so drags scroll; the rail stays on the physical right in RTL.

| Member | Notes |
|---|---|
| one child | Headers and button rows stay outside |
| `static horizontal() -> GoScroll` · `static as_horizontal(node)` | Chip rows, thumbnail strips |
| `static containing(node) -> GoScroll` | Nearest scrolling ancestor |
| `use_panel_edge(parent_padding)` · `set_panel_padding(p)` | Move the scrollbar into the card padding (GoSurface/GoForm call it) |
| `set_section_visible(v)` | Hide the scroll plus its edge frame |

```gdscript
var strip := GoScroll.horizontal()
var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
for tag in ["All", "Weapons", "Armor", "Potions", "Quest"]:
	row.add_child(GoStyle.button(tag, _filter.bind(tag), GoStyle.Tone.COMPACT))
strip.add_child(row)
```

## 6. Subclass hooks

| Hook | In | Default |
|---|---|---|
| `_make_scroll() -> GoScroll` | `GoSurface`, `GoCoachMark` | `GoScroll.new()` |
| `_make_close_button() -> GoIconButton` | `GoSurface`, `GoPromptCard` | `GoIconButton.new()` |
| `_make_surface() -> GoSurface` | `GoSheet`, `GoDialogs` | `GoSurface.new()` |
| `_should_pause() -> bool` | `GoCoachMark` | `GoSurface.is_any_open()` |

## 7. Which one to use

| Need | Use |
|---|---|
| Must answer before continuing (delete, quit, buy) | `GoDialogs.confirm` |
| Tell something, one button | `GoDialogs.alert` |
| Tell something, no button, game keeps going | `GoNotice` (hud.md §6) |
| Optional question while playing (invite, trade) | `GoPromptCard` (hud.md §7) |
| List / management page over the game | `GoSheet` |
| Settings / details window | `GoSurface` CENTER |
| Dropdown or context menu next to a control | `GoSurface` ANCHOR (or `GoStyle.dropdown`) |
| Full-screen menu / login / character creation | Root Control + `GoForm` |
