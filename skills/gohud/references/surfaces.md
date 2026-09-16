# Surfaces — GoSurface, GoSheet, GoDialogs, GoForm, GoScroll

Source: `widgets/go_surface.gd`, `widgets/go_sheet.gd`, `services/go_dialogs.gd`, `widgets/go_form.gd`,
`widgets/go_scroll.gd`. Web: https://thruthesky.github.io/gohud/widgets-surfaces.html#surfaces

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
| opacity | `alpha` — the **card face's** opacity, ratio 0.0–1.0, negative = theme/config value (**80%** by default). Text, buttons and the border stay sharp; the scrim behind is separate (`scrim_transparent`, `GoTheme.SCRIM`). `theming.md` §4 |
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
| `open(title)` / `open_key(key)` | Shows the sheet, clears `body`, hides back button, **frees toolbar children and `add_footer()` nodes**, hides toolbar and footer |
| `set_title(text)` | Title only — for list → detail inside one sheet |
| `toolbar()` / `footer()` | Sticky rows under the header / at the bottom. Set `.visible = true` after adding |
| `add_footer(node) -> Node` | Adds to **this page's** footer and shows it; the next `open()` removes it (gohud newer than 1.0.3) |
| `set_back(callable)` · `clear()` · `close()` | `close()` hides (does not free) and emits `closed` |

🛑 `open()` only **hides** `footer()`: children added with `footer().add_child()` stay across pages — right for a
sheet-wide snackbar, wrong for a Close button added on every open (they stack). Add per-page buttons with
`add_footer()`; the next `open()` removes them. gohud 1.0.3 and older have no `add_footer()` — there, remove the old
footer children first (`remove_child` then `queue_free`, so counts and layout update at once).

```gdscript
func show_inventory(items: Array) -> void:
	sheet.open("Inventory")                          # clears body, toolbar and add_footer() nodes
	sheet.toolbar().add_child(GoStyle.line_edit("Search…"))
	sheet.toolbar().visible = true
	if items.is_empty():
		sheet.body.add_child(GoStyle.empty_state(GoIconSet.BAG, "Your bag is empty", false))
	for item in items:
		sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, item.name, show_item.bind(item),
			Color.TRANSPARENT, item.description, false, GoIconSet.CHEVRON_RIGHT))
	sheet.add_footer(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))   # shows the footer too

func show_item(item) -> void:
	sheet.clear()
	sheet.set_title(item.name)
	sheet.set_back(show_inventory.bind(all_items))
	sheet.body.add_child(GoStyle.label(item.description))
```


**Opacity.** `sheet.alpha = 0.7` (ratio) delegates to the surface — the map under an inventory sheet
stays visible. Default 80%; `theming.md` §4.
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
- 🛑 `{name}` placeholders are filled only through `args` — `tr()` alone leaves `{name}` on screen. The same `args`
  fill the title (after translation for `*_key`); gohud 1.0.3 and older fill only the body — build the title there.

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


**Opacity.** `dialogs.alpha = 0.9` — a ratio like every other `alpha` field, even though it is an `@export`
(negative = theme/config value, 80% by default). Raising it on an irreversible confirm keeps the eye on the
question.
## 4. GoForm

`class_name GoForm extends MarginContainer`. Full-rect; side margins = max(padding, (usable width − cap) / 2)
using `form_max_width_*` per breakpoint; bottom margin grows with the virtual keyboard.

| Member | Notes |
|---|---|
| structure | `GoForm` → `GoScroll` (node **name "Scroll"**, which `GoScroll.new()` already sets) → `VBoxContainer` |
| `scroll` | Found in `_ready`; when the keyboard opens the focused field scrolls into view |
| `@export min_side_margin` (-1 → `padding`) · `min_edge_margin` (-1 → `screen_margin`) | |
| `@export route_back_button` (true) | Android Back presses the node with unique name `%BackButton`, looked up once in `_ready` (hides the keyboard first) |
| `@export avoid_hud` (false) | Keep content clear of visible `GoHudAnchor`s with `reserve_space`, stepping the cheapest direction |

It applies `GoStyle.form()` to every descendant, now and later: labels wrap, buttons get `button_height`
and word-safe wrapping, plain `Button`s get the normal style, `LineEdit`s get `button_height`.

🛑 Build `GoForm → GoScroll → column` **before** the form enters the tree. `_ready` runs inside `add_child`;
a scroll added afterwards is never found, so keyboard follow and the scrollbar gutter are lost (descendants
still get styled).

🛑 `%BackButton` is looked up **once in `_ready`** among the nodes owned by the form or by the form's owner, so a
`.tscn` (whose root owns every node) just works. In code, name the button `BackButton`, add it to the column, then set `back.owner = form` and
`back.unique_name_in_owner = true` before `add_child(form)` — setting them after `add_child` is too late.

gohud 1.0.3 and older cleared that owner: `GoForm._ready` moves the scroll into its edge frame (`use_panel_edge`),
and Godot's `reparent()` keeps only the owners shared with the moved node, so `owner = form` — or a holder owning only
the form and the button — silently switched Back routing off (measured on 4.7.2). Newer versions restore the owners.
A holder that owns the **whole branch** works on every version, which is what this example does:

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
	for node in holder.find_children("*", "", true, false):
		node.owner = holder                         # the whole branch, like a scene root
	back.unique_name_in_owner = true
	add_child(holder)                               # _ready runs here: finds Scroll and %BackButton
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

## 8. GoSnackbar — the message that places itself

```gdscript
var snack := GoSnackbar.new()
add_child(snack)                                  # or an autoload, like GoDialogs

snack.show_text("Saved", GoTheme.SUCCESS)
snack.show_key("err_offline", {}, GoTheme.DANGER)

# A chance to undo — 0 is the first button, -1 means it timed out
if await snack.post({"text": "Item dropped", "icon": &"trash", "actions": ["Undo"]}) == 0:
    restore_item()
```

`layer_index` 90 (above the HUD, below `GoDialogs` at 100) · `max_width` 560 · `margin` (−1 = screen margin)
· `placement` `BOTTOM`/`TOP` · `queue_limit` 4 · `merge_repeats` · `motion_seconds` · `slide_dp` ·
`tap_to_dismiss` · signal `closed(index)` · `dismiss()` `clear()` `is_showing()` `pending()`.

| `post()` key | Meaning | Default |
|---|---|---|
| `text` · `title` | Body, and an optional bold first line | `""` |
| `tone` | Colour token (`GoTheme.DANGER` …) | `TEXT` |
| `icon` | Icon name — skipped silently if the set does not know it | none |
| `actions` | Strings, or `{"text":…, "action": Callable}` | none |
| `closable` · `seconds` · `translate` · `args` | × button · lifetime (`0` = until pressed) · keys · placeholders | |

- 🛑 **It is not a place to ask something.** It goes away on its own, so the player may never see it —
  irreversible confirmations belong in `GoDialogs`. Buttons here must be optional (Undo, Details, Retry).
- Messages **queue**; repeats of the same line are merged (a server failing four times a second no longer
  stacks four minutes of alerts); a snackbar with **no** button lets input through so the game keeps running.
- 🔑 `GoNotice` vs `GoSnackbar`: the notice never takes input or focus and the screen decides where it goes —
  it cannot hold a button. The snackbar places itself, queues and can be pressed.


**Opacity.** `snack.alpha = 0.95` (ratio, negative = `notice_alpha`, 80% by default). A snackbar carries the
one line you must not miss; over a busy world raise it — `theming.md` §4 explains the trade.
## 9. GoDrawer — the side panel

```gdscript
var bag := GoDrawer.new()
add_child(bag)
bag.side = GoDrawer.Side.RIGHT
bag.open("Bag")
bag.body.add_child(inventory_grid)
```

`side` · `follow_text_direction` · `width_ratio` 0.42 · `max_width` 420 · `dismissable` · `motion_seconds`
· `body` `header` `title_label` `panel` · signals `opened` `closed` · `clear()` `is_open()` `effective_side()`.

- 🔑 `GoSheet` comes from the **bottom** — right for a phone held upright. A drawer comes from the **side** —
  right for a tablet or desktop, where a bottom sheet would cover the game. On a narrow phone the drawer
  covers nearly everything, so prefer the sheet there.
- `LEFT` means screen-left even in Arabic; turn on `follow_text_direction` when "the start side" is the point
  (a menu drawer), and it flips in RTL.
- The panel reaches the screen edge but the **content stays inside the safe area** — otherwise a rounded
  corner clips the first list row.
- It takes the Back/Escape ownership while open and releases it on close, including in `_exit_tree`.


**Opacity.** `drawer.alpha = 0.7` — a ratio (negative = theme/config value).
## 10. GoPopover — the anchored card

```gdscript
GoPopover.open(slot, item_card(item))
GoPopover.open(button, body, {"title": "Upgrade odds", "dismissable": false, "width": 280})
await GoPopover.open(slot, body).close_requested
GoPopover.close()
```

Options: `title` · `translate` · `width` 320 · `max_height` 520 · `dismissable` · `compact` · `layer` 95.

- This is `GoSurface`'s `ANCHOR` placement with the layer, the surface, the anchor and the teardown already
  wired — the thing every game writes ten lines of, over and over.
- 🛑 **One at a time.** Pressing slot after slot closes the previous card; stacked cards bury the screen and
  nobody can tell which card belongs to which slot.
- The scrim is **transparent**: a card you opened to compare gear must not darken the gear.
- 🛑 It is not a hover tooltip — touch has no hover, so put nothing here that only a mouse could reveal.
- When the anchor leaves the tree (the item was dropped) the card goes with it.


**Opacity.** `{"alpha": 0.9}` in the options. These cards exist to **compare** things, so the value behind them
often matters; the scrim is already transparent for the same reason.
## 11. Dialogs that queue

`GoDialogs.alert()` and `alert_key()` **wait their turn** when a dialog is already open. `confirm()` and
`confirm_key()` still return `false` immediately, and `queue_when_busy` (default off) makes questions queue too.

| | Already open | Why |
|---|---|---|
| `confirm()` | returns `false` at once | A question that arrives late is answered by someone who no longer knows what they are agreeing to. The caller sees the `false` and can react |
| `alert()` | queues | It returns `void` — the caller **cannot** tell it was never shown, so a dropped alert is an error message nobody ever sees |

`pending()` counts what is waiting; `clear_pending()` answers them all with `false` — call it when leaving a
screen, or code parked on `await` never resumes.
