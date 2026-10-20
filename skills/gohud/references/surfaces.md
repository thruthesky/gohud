# Surfaces — GoSurface, GoSheet, GoDialogs, GoForm, GoScroll, GoSnackbar, GoDrawer, GoPopover, GoPage

Source: `widgets/go_surface.gd`, `widgets/go_sheet.gd`, `services/go_dialogs.gd`, `widgets/go_form.gd`,
`widgets/go_scroll.gd`, `services/go_snackbar.gd`, `widgets/go_drawer.gd`, `widgets/go_popover.gd`, `widgets/go_page.gd`. Web: https://thruthesky.github.io/gohud/widgets-surfaces.html#surfaces

## Contents

1. [GoSurface — the floating window shell](#1-gosurface)
2. [GoSheet — bottom sheet pages](#2-gosheet)
3. [GoDialogs — await confirm / alert](#3-godialogs)
4. [GoForm — width-capped, keyboard-safe forms](#4-goform)
5. [GoScroll — touch scrolling](#5-goscroll)
6. [Subclass hooks](#6-subclass-hooks)
7. [Which one to use](#7-which-one-to-use)
8. [GoSnackbar — the message that places itself](#8-gosnackbar--the-message-that-places-itself)
9. [GoDrawer — the side panel](#9-godrawer--the-side-panel)
10. [GoPopover — the anchored card](#10-gopopover--the-anchored-card)
11. [Dialogs that queue](#11-dialogs-that-queue)
12. [GoRibbonHeader — a screen's title ribbon](#12-goribbonheader--a-screens-title-ribbon)
13. [GoFitBox — the whole card on the screen](#13-gofitbox--the-whole-card-on-the-screen)
14. [GoPage — the full-screen page](#14-gopage--the-full-screen-page)

## 1. GoSurface

`class_name GoSurface extends Control`. Popups, sheets and dropdowns all use it. Children are built in
`_init`, so `set_title()` and `body.add_child()` work **before** the node enters the tree. Options set between
`new()` and `add_child()` are applied in `_ready`.

| Member | Notes |
|---|---|
| signals | `close_requested` · `back_requested` · `height_changed(ratio: float)` (handle drag — once per frame, after the card has that height) |
| `enum Placement { CENTER, BOTTOM, ANCHOR }` | `placement` (CENTER) |
| size | `max_width` / `max_height` / `height_ratio` / `max_height_ratio` (0 = GoConfig value) · `fit_content` (true — short content, short card) · `compact` (smaller padding) · `height_ratio_cap()`. 🛑 With `compact` on, a viewport under 420 high or content that overflows, the surface goes **dense**: padding drops to `padding_compact` and the **title drops to `body`** (16), re-applied on every relayout — a list under it loses its top step. Put the heading players read first in the body (`SKILL.md` rule 15) |
| ceiling | 🛑 `height_ratio` above `max_height_ratio` (default `GoConfig.surface_max_height_ratio`, 0.72) is cut — raise `max_height_ratio` on the one surface that needs it; a debug build warns once. A centered `fit_content` card still grows to `surface_fit_max_height_ratio` (0.94) for long content. Drag-resize stops at the same ceiling |
| behaviour | `dismiss_on_scrim` (config default) · `scrim_transparent` (also drops the look's frosted blur, `GoSkin.scrim_material()`) · `fade_in` · `resizable` (drag the title) · `show_header` (true) · `scroll_body` (true) · `close_enabled` (true) · `initial_focus: Control` |
| opacity | `alpha` — the **card face's** opacity, ratio 0.0–1.0, negative = theme/config value (**80%** by default). Text, buttons and the border stay sharp; the scrim behind is separate (`scrim_transparent`, `GoTheme.SCRIM`). `theming.md` §4 |
| anchor | `anchor_control` · `anchor_width` (320; **0** = its content's width, no narrower than `anchor_min_width` — `anchor_width_now()`) · `anchor_min_width` (210) · `anchor_max_height` (520) · `anchor_align: AnchorAlign` (`AUTO` — beside it on the roomier side; `START` / `END` — that edge on the anchor's, mirrored in RTL) · `anchor_gap` (7) · `anchor_edge` (8, off the safe area) — opens below, or above when there is more room |
| taps through | `pass_anchor_taps` (false) — a tap on the anchor goes through the outside-tap layer to it, so the key that opened the card closes it (the anchor keeps the focus the tap gives it) · `tap_through: Array[Control]` — more controls whose taps go through (the rest of a top bar). Off: the layer covers everything and any tap outside the card closes it |
| fit | `fit_mode: FitMode` — `SCROLL` (default: the card is cut to the screen, the body scrolls) · `SCALE`: Magnet Mayhem's `FitBox` — a centred window keeps the look's width and its content's height and shrinks **as a whole** (`scale`, never above 1) until it and its overhang (`fit_overhang()`, `GoRibbonHeader.card_overhang()`: the ribbon and the magnet) fit the safe area less `GoSkin.window_fit_pad()`; below `GoConfig.fit_min_scale` the list gives up height first (`fit_flex: ScrollContainer` — a `GoFitBox.new_flex()` in the body — or, null, the body's own scroll), down to `window_flex_min_height()`. An `ANCHOR` card under `SCALE` is the game's top-bar card: natural size, shrunk to the safe area (never below the fit floor), never opening upward — moved up. `fit_scale` — the scale it got. A `BOTTOM` sheet ignores it |
| frame | The look frames a centred window (`GoSkin.window_card_variation()` / `window_padding()` / `window_gap()` / `window_width()`): `arcade_light` puts it on the painted card (`GoCard`), 400 dp wide with no screen margin (`window_screen_margin()` 0, so a 407-wide phone still gets 400), mipmapped (`window_texture_filter()`), padded by the card face alone, its head, body rows and footer 8 dp apart — the game's `PaintedDialog`. Centred rounded down, like a `CenterContainer` |
| parts | `add_inset(parent = null) -> VBoxContainer` (an inset in the look's face, `GoSkin.window_inset_variation()`, rows 4 apart) · `add_line(text, font_size = 0, parent = null, wrap = true) -> Label` (centred; SMART wrap; a one-line stat passes `wrap = false`) · `add_row(parent = null) -> HBoxContainer` (`window_button_gap()`) · `add_gloss(variation, icon, text, parent = null, texture = null) -> GoGlyphButton` (`window_button_height()`; shares a row's width). `parent` defaults to the body. `arcade_light`: the game's `PaintedDialog.add_inset` / `add_line` / `add_gloss` — `GoInsetPanel`, buttons 46 high and 10 apart |
| corner | `corner: HeadCorner` — `LOOK` (default: `GoSkin.window_corner()`; a centred window only, sheets and popovers keep the close button) · `CLOSE` · `ART` (`corner_art`, or `GoSkin.window_corner_art()`, placed by `window_corner_rect()` from the drawn plate's top-left) · `NONE` · `corner_on_left` (true; mirrored on the right) · `corner_now()`. Without the close button Escape / Back still emit `close_requested`. `arcade_light`: the game's red magnet, no close button. A close button the host hid itself stays hidden |
| title | `title_variation: StringName` — the theme variation the title plate wears instead of the look's (`&"GoRibbonRed"`: `arcade_light`'s red GAME OVER ribbon, the game's `RibbonRed`, with the gold one's height, rise, bleed and magnet; empty or undefined = the look's plate) · `title_paint` — a paint for a **code-drawn** plate (`arcade`, `arcade_dark`: a red ribbon moved until the white title reads; transparent = the look's own). 🛑 `arcade_light`'s ribbon is a painted sprite: `title_paint` does nothing there — use `title_variation` |
| title extras | `title_glyph: Texture2D` · `title_glyph_size` (0 = in step with the title) — a glyph left of the title, in its colour · `title_overhang()` · `title_glyph_side()` — a look whose plate hangs over the card's top edge (`GoSkin.title_plate_overhang()`, the painted ribbon in `arcade_light`) lifts the head; the body keeps its own clip, and clips only while its content overflows (a fitting body draws its parts' rims whole). The look may fix the title's size and the plate's height (`GoSkin.title_plate_font_size()` / `title_plate_height()`: 34 on 57 in `arcade_light`); a long title shrinks to the plate's room as drawn, past the card's sides, down to `title_plate_min_size()` — and past that folds, or under `fit_mode = SCALE` widens the card (the fit then shrinks the whole window). On a plate the glyph's cell is its side wide and the title's line tall, kept to its aspect |
| opaque | `opaque` — a solid colour (`GoSkin.opaque_backdrop_color()`, the game's sky in `arcade_light`) under the window instead of the see-through veil, for a window opened where the world behind is not drawn (a menu at boot) |
| parts | `card` PanelContainer · `header` HBox · `title_label` · `close_button` GoIconButton · `back_button` · `scroll` GoScroll (**created in `_ready`**) · `body` VBox · `toolbar` VBox (hidden) · `footer` VBox (hidden) |
| methods | `set_title(text)` · `set_title_key(key)` · `set_back(callable)` (empty Callable hides) · `clear()` · `request_close()` · `is_top()` · `relayout()` · `content_inset()` · `section_gap()` · `attach_resize_handle(control)` |
| status line | `set_status_text(text, tone := StringName())` · `set_status_key(key, tone)` · `clear_status()` — one pinned line between the body and the footer ("Passwords do not match"), in a colour token's tone. 🛑 Not in the body: an error that lands below a long form's fold looks as if nothing happened. `status` (VBox) · `status_label` (created on first use) |
| layout pass | Runs **when something changes**, not every frame: a size field above set to a new value, a section's minimum size or visibility, the window, the keyboard, the config. Assign a field and it applies next frame — no `relayout()` call needed. An `ANCHOR` popover follows its anchor every frame. A subclass may replace `relayout()` outright (no `super()`) and still gets these calls |
| static | `GoSurface.is_any_open() -> bool` — pause gameplay input while true (counts an open `GoDrawer` too) · `is_any_surface_open()` (surfaces only) · `open_surface_count()` (how many surfaces are open) · `is_any_held_open()` (held windows only — an open `GoDrawer`) · `hold_open(on)` (a non-surface window takes / gives back its place in `is_any_open`) |

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
	surface.body.add_child(GoStyle.toggle("Vibration"))
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
| vars | `body` (scrolls) · `surface` · `dismissable` (true — set false for trade/irreversible screens) · `height_ratio` (0.6) · `max_height_ratio` (0 = config 0.72 — set it with a taller `height_ratio`) |
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
| `choose(title, options, cancel_text := "", translate := false) -> int` | `await` it — the picked option's index, `-1` for Cancel, the X or Back (Flutter's `SimpleDialog`, an action sheet). An option is a string or `{"text", "icon", "subtitle", "danger"}`. A bottom sheet on a phone, centred on a desktop |

- `destructive = true` draws the confirm button as `Tone.DANGER_SOLID` (filled red, legible on light themes).
- A second `confirm()` while one is open returns `false` immediately (unless `queue_when_busy`); `alert()` waits its
  turn — it is queued (§11); `choose()` returns `-1`. `@export queue_limit` (8): past it the oldest waiting request is
  answered `false`.
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
| `@export route_back_button` (true) | Android Back presses the node with unique name `%BackButton`, looked up once in `_ready`. While the keyboard is up, Back only hides it (the button is not pressed); while any `GoSurface` is open, Back is the surface's |
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

`class_name GoScroll extends ScrollContainer`. Vertical by default, deadzone from tokens; the rail stays on the
physical right in RTL. **A finger swipe that starts on anything inside scrolls it**: the touch policy turns every
`MOUSE_FILTER_STOP` descendant (cards, panels, `ColorRect`, plain `RichTextLabel` bodies, buttons) into PASS, when it
enters and once more a frame later, so nobody passes a filter by hand. Controls whose own drag means something keep
STOP — text fields, selectable text, sliders and spin boxes, `OptionButton`, `ItemList`/`Tree`/`GraphEdit`, and
anything marked `set_meta(GoScroll.OWNS_GESTURE, true)` (a pannable map). Outside a scroll nothing changes, so a HUD
panel over the world keeps STOP.
**An up-and-down swipe still scrolls when it starts on a control whose own gesture is sideways or a tap**
(`yields_vertical`): a single-line field, a horizontal slider, a `TextEdit` whose text fits, a dropdown and a tab row.
The scroll holds the press (touch and the mouse made from it) until the finger has moved past the deadzone: up or down
hands it to the list, sideways or a lift hands it to the control — a slider still drags, a tap still places the caret,
opens the dropdown, switches the tab. Spin boxes, vertical sliders, a `TextEdit` that scrolls and `OWNS_GESTURE`
controls keep the whole gesture. Touch only; a mouse press goes straight to the control.
In the engine's plain `ScrollContainer` the gohud parts do the same on their own: tab rows, progress bars, cards,
panels, chips, alerts and icon buttons pass the swipe through (`scroll_through`), and `GoStyle` fields, sliders and
dropdowns carry the arbiter with them (`yield_vertical`).
Follows keyboard/gamepad focus only (`follow_keyboard_focus`; the engine's `follow_focus` is off — it also fired on
the focus a finger press hands out). While a finger drag runs, the rows drop that focus and ignore the mouse, so no
highlight rides along with the finger.

| Member | Notes |
|---|---|
| one child | Headers and button rows stay outside |
| `static horizontal() -> GoScroll` · `static as_horizontal(node)` | Chip rows, thumbnail strips. PASS while another scroll holds it (an up-and-down swipe on the row scrolls the sheet), STOP standing alone — a strip in a HUD never hands a press to the world. Set `mouse_filter` yourself after `horizontal()` and it stays yours |
| `static containing(node) -> GoScroll` | Nearest scrolling ancestor |
| `use_panel_edge(parent_padding)` · `set_panel_padding(p)` | Move the scrollbar into the card padding (GoSurface/GoForm call it) |
| `set_section_visible(v)` | Hide the scroll plus its edge frame |
| `OWNS_GESTURE` · `static owns_gesture(control)` | Meta key a control sets to keep its own drag · the policy's verdict |
| `SIDEWAYS` | Meta key for a control whose own drag is sideways (a range slider): it keeps the press inside a scroll, while an up-and-down swipe from it still scrolls the list |
| `reveal(control)` | Scrolls `control` into view after two frames (once its size is known) — for a field you just added or an error row |
| `static yields_vertical(control) -> bool` | Whether an up-and-down swipe that starts on this gesture owner scrolls the list (above) |
| `static scroll_through(control) -> Control` | PASS while the control sits under any `ScrollContainer`, its own filter elsewhere; only a STOP filter is changed and put back when it leaves. `GoStyle` panels, tabs, progress bars, chips and `GoIconButton` call it |
| `static yield_vertical(control) -> Control` | Gives a field, slider or dropdown the press arbiter inside a plain `ScrollContainer` (inside a `GoScroll` the scroll already holds it). `GoStyle.line_edit/slider/select/textarea/tabs/dropdown` call it |
| `static control_at(node, point) -> Control` | The control a press at a viewport point reaches under `node` (topmost visible, not IGNORE, clipped by containers) |
| `static audit_touch(root) -> Array[String]` | For screen tests: STOP controls inside a scroll and plain `ScrollContainer`s under `root` (empty = clean) |

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
| Pick one of a few options (sort by, share to) | `GoDialogs.choose` |
| A message that stays on the page until dealt with ("You're offline — Retry") | `GoBanner` (flutter.md §2) |
| Tell something, no button, game keeps going | `GoNotice` (hud.md §6) |
| Optional question while playing (invite, trade) | `GoPromptCard` (hud.md §7) |
| List / management page over the game | `GoSheet` |
| A menu that owns the whole screen (settings, bag, character, mail) with a category rail | `GoPage` (§14) |
| Settings / details window | `GoSurface` CENTER |
| A card that must stay whole on a small screen (a pause or settings card, a result card) | `GoFitBox` (§13), or a `GoSurface` with `fit_mode = SCALE` |
| Dropdown or context menu next to a control | `GoSurface` ANCHOR (or `GoStyle.dropdown`) · long press / right click → `GoContextMenu` (hud.md §9) |
| A card about the thing under the finger (an item's stats next to its slot) | `GoPopover` (§10) |
| A message with an optional button (Undo, Retry) that goes away by itself | `GoSnackbar` (§8) |
| A list beside the game on a wide screen (bag, friends, chat), or an app's menu | `GoDrawer` (§9) |
| Full-screen menu / login / character creation | Root Control + `GoForm` |
| A whole app screen (bar, page, bottom bar, FAB, drawer) | `GoScaffold` (flutter.md §2, `assets/templates/app_screen.gd`) |

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
  stacks four minutes of alerts). Input: by default (`tap_to_dismiss` on) the card itself catches a tap to close —
  only the area outside the card passes to the game; a snackbar with no button, no × and `tap_to_dismiss = false`
  lets every press through.
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

A `CanvasLayer` on layer 80 (above the HUD and sheets, below snackbars at 90). `side` · `follow_text_direction` ·
`width_ratio` 0.42 · `min_width` 320 · `max_width` 420 · `alpha` · `dismissable` · `motion_seconds` · `close_when_surface_opens` (false) · `body` `header`
`title_label` `panel` · signals `opened` `closed` · `open(title := "")` (the body is **not** emptied) · `close()` ·
`clear()` · `is_open()` · `set_title()` · `set_title_key()` · `effective_side()`. In a `GoScaffold`, `set_drawer(drawer)`
makes the app bar's menu button open it.

- 🔑 `GoSheet` comes from the **bottom** — right for a phone held upright. A drawer comes from the **side** —
  right for a tablet or desktop, where a bottom sheet would cover the game. On a narrow phone the drawer
  covers nearly everything, so prefer the sheet there.
- `LEFT` means screen-left even in Arabic; turn on `follow_text_direction` when "the start side" is the point
  (a menu drawer), and it flips in RTL.
- The panel reaches the screen edge but the **content stays inside the safe area** — otherwise a rounded
  corner clips the first list row.
- It takes the Back/Escape ownership while open and releases it on close, including in `_exit_tree`. Escape
  (`ui_cancel`) closes it in `_input`, so a game's own `_unhandled_input` Esc (a pause menu) never fires under it; a
  surface opened over the drawer closes first.
- While open it counts in `GoSurface.is_any_open()` (`hold_open`): gameplay input pauses and a `GoCoachMark` waits.
- An "all menus" drawer: `GoStyle.section()` headers, each over a `GoGrid` of `GoStyle.menu_tile()` tiles.
- 🚪 A launcher drawer (an "all menus" list) sets `close_when_surface_opens`: a surface that opens while it is up — from
  a tile, a hotkey, a voice command or a prompt from the game — closes it, so the window is never left UNDER the drawer
  (layer 80), where the first Escape / back would close it unseen. A surface already open when the drawer opened does
  not count (`GoSurface.open_surface_count()`).
- 🚪 `hand_over(action)` — what a tile press runs: the window the action opens comes up while the drawer is still there,
  and the drawer **steps aside in that same frame** (no slide-out, nothing left under the window); when that window and
  anything it opened in turn have closed, the drawer is back as it was (`is_handing_over()`). Back from the window
  retraces the path to the drawer. An action that opens nothing within `HAND_OVER_FRAMES` (it acts on the screen behind)
  closes the drawer so its effect shows. `close()` while it stands aside only gives up the way back.


**Opacity.** `drawer.alpha = 0.7` — a ratio (negative = theme/config value).
## 10. GoPopover — the anchored card

```gdscript
GoPopover.open(slot, item_card(item))
GoPopover.open(button, body, {"title": "Upgrade odds", "dismissable": false, "width": 280})
await GoPopover.open(slot, body).close_requested
GoPopover.close()
```

Options: `title` · `translate` · `width` 320 (0: its content's) · `min_width` 210 · `max_height` 520 · `dismissable` · `compact` · `layer` 95 ·
`alpha` · `align` (`&"auto"`, `&"start"`, `&"end"`) · `gap` 7 · `edge` 8 · `fit` (false — shrink to the safe area instead of cutting) ·
`pass_anchor_taps` (false) · `tap_through` (`Array`) — the matching `GoSurface` fields (§1).
`GoPopover.is_open()` · `GoPopover.close()`. 🛑 `open()` returns `null` when the anchor is not in the tree — check it
before `await GoPopover.open(...).close_requested`.

- This is `GoSurface`'s `ANCHOR` placement with the layer, the surface, the anchor and the teardown already
  wired — the thing every game writes ten lines of, over and over.
- 🛑 **One at a time.** Pressing slot after slot closes the previous card; stacked cards bury the screen and
  nobody can tell which card belongs to which slot.
- The scrim is **transparent**: a card you opened to compare gear must not darken the gear.
- 🛑 It is not a hover tooltip — touch has no hover, so put nothing here that only a mouse could reveal.
- When the anchor leaves the tree (the item was dropped) the card goes with it.
- 🎮 **A top-bar card** (Magnet Mayhem's language list and volume card): its content's width, its right edge on the
  key's, 10 under it, shrunk to the safe area, and a second tap on the key closes it. Under `arcade_light` the card is
  the game's painted card (`GoCard`):

```gdscript
func toggle_volume() -> void:
	if GoPopover.is_open(): return GoPopover.close()                 # the key's second tap reaches the key
	GoPopover.open(sound_key, volume_column, {"width": 0, "min_width": 300, "align": &"end", "gap": 10, "edge": 0,
		"fit": true, "pass_anchor_taps": true, "tap_through": [top_bar]})
```


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

## 12. GoRibbonHeader — a screen's title ribbon

`class_name GoRibbonHeader extends Control`. The title plate of a screen built on a card (a pause or settings card)
rather than a `GoSurface`: the look's plate with a glyph and the title on it, hanging over the card's top edge, and the
look's art in one corner — Magnet Mayhem's `RibbonHeader`. Put it first in the card's column.

```gdscript
var header := GoRibbonHeader.make("PAUSED", GoIconSet.PAUSE)   # make(text, icon = &"", on_left = true)
card_column.add_child(header)
header.ribbon_variation = &"GoRibbonRed"                       # the red ribbon (arcade_light)
```

| Member | |
|---|---|
| `title` | One line (a line break is dropped); shrinks to fit the ribbon less its ends and the glyph, no lower than `GoStyle.fit_floor` |
| `glyph: Texture2D` · `glyph_icon: StringName` | Left of the words, 10 dp apart, centred together; the texture wins; neither: the words alone |
| `ribbon_variation` | A theme variation for the plate (`GoRibbonRed`); empty: `GoSkin.title_plate_box()` |
| `corner` (true) · `corner_on_left` (true) · `corner_art` | The corner art: `corner_art`, else `GoSkin.window_corner_art()` when `window_corner()` is `&"art"`; placed by `window_corner_rect()` from the plate's top-left, mirrored on the right |
| `ribbon` · `title_label` · `glyph_rect` · `corner_rect` | The parts, to read |
| `refresh()` | Dress and lay out now (the setters batch to the end of the frame) |

- 🔑 The look sets the shape with the `GoSurface` title hooks: `title_plate_height()`, `title_plate_font_size()`,
  `title_plate_overhang()`, `title_plate_ink()`, `dress_title()`. `arcade_light`: 57 dp high, 34 dp words, 17 dp above
  the card and 14 past each side, the red magnet 58 × 56 at 30 out and 24 up — pixel for pixel the game's.
- 🔑 It holds only the part of the ribbon inside the card in its column (height − overhang − the card's top margin);
  the rest draws upward. The card is the nearest `PanelContainer` above it.
- A look with no plate and no overhang gets a plain title row in the column.
- 📐 `GoRibbonHeader.card_overhang(card = null, corner = true) -> Vector4` (static) — how far a card headed by the
  look's ribbon draws past its rect (left, top, right, bottom): the plate's bleed and rise, and the corner art past the
  plate when `corner` is on and the look has art. Both sides reserve the art. `arcade_light`: `(20, 41, 20, 0)` on the
  painted card — the game's `RibbonHeader.card_overhang()`. `card` null: the look's window card. What `GoFitBox`
  reserves.

## 13. GoFitBox — the whole card on the screen

`class_name GoFitBox extends Container`. Magnet Mayhem's `FitBox` for a card screen that is not a `GoSurface` window
(the pause and settings cards): it centres its card in the safe area and, when the card is too big, shrinks it **as a
whole** — the ribbon and the magnet over its edges included — so nothing is cut and nothing scrolls off.

```gdscript
var fit := GoFitBox.new()                         # wears GoUi.theme(); its own minimum size is zero
layer.add_child(fit)
fit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
fit.add_child(card)                               # a PanelContainer card, a GoRibbonHeader first in its column
var pages := GoFitBox.new_flex()                  # a long list in the card…
pages.add_child(page_column)
column.add_child(pages)
fit.flex = pages                                  # …scrolls rather than shrink the card below the fit floor
```

| Member | |
|---|---|
| `overhang: Vector4` · `auto_overhang` (true) | How far the card draws past its rect (left, top, right, bottom). Auto: `GoRibbonHeader.card_overhang(card)` for a card holding a `GoRibbonHeader` (its corner counted while on), zero for one without; setting `overhang` turns auto off. `overhang_of(card)` reads the one in force |
| `flex: ScrollContainer` | The list that gives up height before the card goes below `GoConfig.fit_min_scale`, down to `GoSkin.window_flex_min_height()` (whole dp). Set it once its one child (the content) is in: the content's own growth refits |
| `pad` (-1) · `pad_now()` · `look_pad()` (static) | Room kept off the edge (dp). -1: the look's `window_fit_pad()` (8 in `arcade_light`), else `SCREEN_MARGIN` |
| `safe_area` (true) · `room_rect()` | Fit inside the safe area (and above the keyboard) as well as its own rect. Off: the rect alone (inside a `GoSafeArea`) |
| `fit_scale` | The scale the card got (1 = its own size) |
| `new_flex() -> ScrollContainer` (static) | Up and down only, no bar, a deadzone of a quarter of the touch target (11 at 44) — the game's |
| `place(card, area, need, reach, margin) -> float` · `flex_height(full, others, most) -> float` (static) | The fit itself, shared with `GoSurface`'s `SCALE` fit |

- 🔑 The fit, as the game's: room = safe area − 2 × pad; `scale = min(1, room / (card + overhang))`; centred on the
  card's own rect (rounded down) and nudged only when tight, so the overhang stays inside too. A card that would go
  below the fit floor first shortens `flex` to `most − the rest`, where `most = room.y / fit_min_scale − overhang`, so a
  settings card with a long list on a landscape phone stays readable and its list scrolls.
- 🛑 Children are placed by hand — `Container.fit_child_in_rect` would reset their scale. Each visible child is one
  card; its minimum size is what it needs.
- A `GoSurface` window does the same with `fit_mode = GoSurface.FitMode.SCALE` (§1).

## 14. GoPage — the full-screen page

`class_name GoPage extends CanvasLayer` — a sibling of `GoSheet` for menus that own the whole screen: a title with
back and close, a category rail (**left in landscape, tabs along the top in portrait**), an optional preview beside
the content (left in landscape, a band above it in portrait), and the content area. Its layer becomes 10 when left
at 1. The chrome is a `GoSurface` whose card fills `GoSafeArea.usable_rect` while the ground fills the whole screen,
so back-gesture ownership (`GoBackPolicy`), Escape / Android back closing **only the topmost** window, and focus
restore all come from `GoSurface`.

| Member | Notes |
|---|---|
| signals | `closed` · `tab_changed(id: StringName)` · `depth_changed(depth: int)` |
| vars | `body` (the content column; scrolls unless `set_scrolls(false)`) · `surface` · `opaque` (true: opaque panel and ground — a host may stop drawing what is behind) · `rail_ratio` / `rail_min_width` / `rail_max_width` · `preview_ratio_landscape` / `preview_ratio_portrait` |
| `open(title)` / `open_key(key)` | Shows the page, resets the back button. **Keeps** tabs, preview and `body` (call `clear()` for a fresh tab) |
| `set_tabs(tabs: Array[Dictionary], selected := &"")` | `{id, label, icon, badge}` (+ `alert = true` for a dot); `label` is translated text or a key; fires `tab_changed` for the shown tab; an empty list hides the rail |
| `select_tab(id)` · `current_tab()` · `tab_button(id)` | `select_tab` fires `tab_changed` only for a different, known tab |
| `set_tab_badge(id, badge := "", alert := false)` | Changes one tab's count (`""` removes it) and red dot in place — no rebuild, so the shown tab, its body and the focus stay |
| `set_preview(node)` | `null` hides it. The page never frees a preview it was handed — replacing it only detaches it |
| `set_back(callable)` · `set_title(text)` · `set_title_key(key)` · `clear()` · `close()` · `is_open()` | As `GoSheet`. `set_back` is the page's own level's back; `close()` closes from any depth and pops every sub-page |
| `push(title, build := Callable())` / `push_key(key, build)` → `VBoxContainer` | A **sub-page inside the page**: hides the shown level, shows a new one with its title, the header's back button and a scrolling body (returned, and passed to `build` — run **on push**) |
| `pop()` → `bool` · `pop_to(depth)` · `depth()` | `pop` frees the top level and shows the one under it (title, back, focus on the control that pushed); `false` at depth 0. `pop_to` is quiet (no focus move) |
| `sub_body()` · `sub_footer()` | The shown level's body, and its pinned row (shows once it has a child) — `body` / `footer()` at depth 0 |
| `set_status_text(text, tone)` · `set_status_key(key, tone)` · `clear_status()` | The shown level's pinned status row (between its body and its pinned row) — the surface's own at depth 0 |
| `set_page_title(text)` · `set_page_title_key(key)` | The page's own title from any depth — under a sub-page, what the last pop shows (`set_title` re-titles the level shown) |
| `hold(on)` · `is_held()` | The top sub-page can't be left while held (a form mid-send): back, Escape, the gesture and the ✕ do nothing; a code `pop()` / `close()` still works, and `close_enabled` comes back as it was |
| `confirm(title, body, ok := "", cancel := "", extra := "", args := {}, destructive := false)` / `confirm_key(…)` | `await` a yes/no **inside the page** — a pushed sub-page with [cancel] [confirm] in its pinned row. Back, Escape, the back gesture or closing the page answer `false`. The same shape as `GoDialogs.confirm` |
| `hand_over(action)` · `is_handing_over()` | Runs a row whose window the page cannot hold: when a window opens (now or within `HAND_OVER_FRAMES`) the page steps aside in that frame, and comes back — same tab, sub-page and row focused — when that window (and anything it opened) closes. A drawer opening meanwhile = the player moved on: the page closes |
| `toolbar()` / `footer()` | The pinned rows under the header / at the bottom (the surface's own) |
| `set_scrolls(on)` · `is_landscape()` | Turn the content scroll off for content with its own scroll (a grid, a list view) |

```gdscript
var page := GoPage.new()
add_child(page)
page.tab_changed.connect(func(id: StringName) -> void:
	page.clear()
	if id == &"sound": page.body.add_child(GoStyle.toggle("Music", false)))
page.open("Settings")
page.set_tabs([
	{id = &"sound", label = "Sound", icon = GoIconSet.VOLUME_HIGH, badge = ""},
	{id = &"bag", label = "Bag", icon = GoIconSet.BAG, badge = "12"},
])
page.set_preview(character_view)   # a SubViewportContainer, say
```

🔑 Build each tab on `tab_changed`, or build them all up front into `body` and toggle their visibility there — the
page never builds content itself. 🛑 Nested vertical scrolls fight over the finger: a tab whose content scrolls by
itself (a slot grid in its own `GoScroll`) calls `set_scrolls(false)` first.

🔑 Layout rules the page keeps for you: the card snaps to whole pixels **inside** the usable area (a fractional logical
window never rounds its last row off screen) and fits again whenever its content's minimum drops; the content scroll
takes the shared panel edge (`GoScroll.use_panel_edge` — the scrollbar in the card's right padding) wherever its column
meets the card's right edge, i.e. always left to right and in portrait — in a right-to-left landscape page the rail is
there instead; a tab's glyph icon never wraps with the rail's labels.

### Sub-pages — no second window over a page

A row with more to show (an About screen, a form, a confirmation) **pushes a sub-page inside the page** instead of
opening a dialog over it or closing the page for another window. A toggle changes in place in the tab itself.

```gdscript
about_row.pressed.connect(func() -> void:
	page.push_key("about_title", func(box: VBoxContainer) -> void:
		box.add_child(GoStyle.label("Version %s" % version))))
if await page.confirm_key("logout_title", "logout_body", "logout", "", "", {}, true):
	log_out()
```

- **Back retraces the path.** The page's surface has `back_before_close` on: Escape, the Android back gesture, the
  header's back button and `GoSurface.request_back()` (a voice "close") pop **one level**; only at depth 0 do they close
  the page. The close button (✕) closes the whole page from any depth. The back-gesture owner count does not change
  with the depth — the page holds it once, as before.
- While a sub-page is up the **rail and the root's pinned footer step away** (a deeper level is not a tab; the root's
  actions belong to the root's content); the toolbar, the preview and everything below the level stay as they were.
  The sub-page body scrolls with the same panel edge as a tab body and mirrors in a right-to-left language; the back
  button sits on the header's leading edge (the right in Arabic or Urdu).
- 🛑 Build a sub-page **on push** (`build`), never up front: a popped level is freed, so nothing of it stays in memory.
- Focus: by keyboard / gamepad focus moves into the new level (its first control, else the back button); on `pop()` it
  returns to the control that pushed — without the ring when the player taps.
- `select_tab()`, `set_tabs()` and `open()` pop back to the page's own level first.

### Handing the screen to a window the page cannot hold

`page.hand_over(func() -> void: shop.open())` — the page steps aside in the frame the window opens (it is hidden, not
closed: tab, body, sub-pages and scroll stay) and comes back on the same row when that window closes. `GoDrawer` has the
same `hand_over` for its tiles. Both wait on `GoSurface.path_count()` (open surfaces + surfaces standing aside), so a
chain — drawer → page → shop — unwinds one window at a time in the order it came.
