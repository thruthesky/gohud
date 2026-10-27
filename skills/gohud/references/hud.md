# HUD and in-game widgets

GoHudAnchor, GoBar, GoSlot, GoSlotGrid, GoJoystick, GoIconButton, GoNotice, GoPromptCard, GoCoachMark, GoContextMenu,
GoConsole, GoSpinner, GoBadge, GoRewardCalendar, GoRadar, GoDonut, GoCarousel, the app-screen parts (GoNavBar,
GoAppBar, GoFab, GoSearchBar, GoSplitButton, GoProgress, GoLoadingIndicator, GoDatePicker) GoChoiceColumn, GoLevelCard, GoStarRow, GoKeyCluster, GoCoverImage, GoGlyphButton, GoSlider, GoSwitch, GoMapPreview, GoHudCard, GoCountdown, GoHudButton, GoNameplate, GoNoticeFeed, GoTouchButton, GoSpotlight, GoTaskCard, GoPerfReadout and GoSignalBars.
Source: `widgets/`. Web: https://thruthesky.github.io/gohud/widgets-hud.html#hud

## Contents

1. [GoHudAnchor — nine safe-area spots](#1-gohudanchor)
2. [GoBar — HP / MP / XP](#2-gobar)
3. [GoSlot — quick slot](#3-goslot)
4. [GoJoystick — virtual stick](#4-gojoystick)
5. [GoIconButton — small visual, 48 dp touch](#5-goiconbutton)
6. [GoNotice — snackbar](#6-gonotice)
7. [GoPromptCard — non-blocking question](#7-gopromptcard)
8. [GoCoachMark — guided tour](#8-gocoachmark)
9. [GoContextMenu — long-press and right-click](#9-gocontextmenu--long-press-and-right-click)
10. [GoConsole — developer console](#10-goconsole--developer-console)
11. [GoSpinner — waiting](#11-gospinner--waiting)
12. [GoBadge — counts and dots](#12-gobadge--counts-and-dots)
13. [GoRewardCalendar — daily attendance](#13-gorewardcalendar--daily-attendance)
14. [GoRadar and GoDonut — stats at a glance](#14-goradar-and-godonut--stats-at-a-glance)
15. [GoCarousel — banners and character select](#15-gocarousel--banners-and-character-select)
16. [App screens — navigation bar, app bar, FAB, search, split button, progress, loading, dates](#16-app-screens--navigation-bar-app-bar-fab-search-split-button-progress-loading-dates)
17. [From Flutter](#17-from-flutter)
18. [GoChoiceColumn — a column of choices you tap once](#18-gochoicecolumn--a-column-of-choices-you-tap-once)
19. [Composing a full HUD — anchors or edge bars](#19-composing-a-full-hud--anchors-or-edge-bars)
20. [GoLevelCard — a stage-select tile](#20-golevelcard--a-stage-select-tile)
21. [GoKeyCluster — WASD or arrows in a T](#21-gokeycluster--wasd-or-arrows-in-a-t)
22. [GoCoverImage — a picture that covers its box](#22-gocoverimage--a-picture-that-covers-its-box)
23. [GoGlyphButton — a glyph beside the label](#23-goglyphbutton--a-glyph-beside-the-label)
24. [GoSlider — a slider drawn the painted way](#24-goslider--a-slider-drawn-the-painted-way)
25. [GoSwitch — an on/off switch with a caption](#25-goswitch--an-onoff-switch-with-a-caption)
26. [GoMapPreview — a small map of a level](#26-gomappreview--a-small-map-of-a-level)
27. [GoHudCard — a match HUD's top-row board](#27-gohudcard--a-match-huds-top-row-board)
28. [GoCountdown — the match-start count](#28-gocountdown--the-match-start-count)
29. [GoHudButton — a HUD corner button with its key](#29-gohudbutton--a-hud-corner-button-with-its-key)
30. [GoNameplate — a name plate over a character](#30-gonameplate--a-name-plate-over-a-character)
31. [GoNoticeFeed — a feed of one-line notices](#31-gonoticefeed--a-feed-of-one-line-notices)
32. [GoTouchButton — a round thumb button (and the painted stick)](#32-gotouchbutton--a-round-thumb-button-and-the-painted-stick)
33. [GoSpotlight — dim round one thing and ring it](#33-gospotlight--dim-round-one-thing-and-ring-it)
34. [GoTaskCard — a lesson's card](#34-gotaskcard--a-lessons-card)
35. [GoPerfReadout — a performance band](#35-goperfreadout--a-performance-band)
36. [GoSignalBars — a signal meter](#36-gosignalbars--a-signal-meter)

## 1. GoHudAnchor

`class_name GoHudAnchor extends Control` · `mouse_filter = IGNORE` · layout LTR · joins group `GoHudAnchor.GROUP`.
It sizes itself to the largest visible child's minimum size (or `custom_minimum_size`) and stretches every child to
its own rect — give it **one** child (a container or a panel).

| Member | Default | Notes |
|---|---|---|
| `enum Spot` | | `TOP_LEFT TOP_CENTER TOP_RIGHT CENTER_LEFT CENTER CENTER_RIGHT BOTTOM_LEFT BOTTOM_CENTER BOTTOM_RIGHT` |
| `spot` | `TOP_LEFT` | |
| `landscape_spot` | `-1` | Spot used when width > height; -1 keeps `spot` |
| `edge_margin` | `-1` | dp from the safe-area edge; -1 → `screen_margin` token |
| `reserve_space` | `true` | `GoForm.avoid_hud` keeps content clear of it. Turn **off** for pieces that only appear sometimes (joystick, toasts, prompts) |
| `avoid_peers` | `false` | Steps vertically out of the way of fixed anchors (`reserve_space` true). For transient toasts at `TOP_CENTER` |
| `use_safe_area` | `true` | Off only for full-bleed backgrounds. Keeps to `GoSafeArea.hud_rect()`: with `GoConfig.hud_side_inset_max` set (Magnet Mayhem: 12) a landscape notch pushes it in from the left or right by that much at most; the top and bottom insets stay whole. It relayouts on `GoRuntime.safe_area_changed` (a 180° turn, a simulated device) as well as on a resize |
| `keyboard_focus` | `true` | **Off** for a corner of buttons over gameplay: nothing under the anchor takes focus (`focus_behavior_recursive`), later children included, so Space / Enter reach the game. 🛑 Text inputs are blocked too — keep a chat line in its own anchor |
| `active_spot()` | | The spot in effect now |

```gdscript
var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.BOTTOM_CENTER
corner.landscape_spot = GoHudAnchor.Spot.BOTTOM_RIGHT   # controls move right in landscape
hud_root.add_child(corner)
```

🛑 A floating HUD over scrolling content needs a panel behind it, or text overlaps text:
`panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))`.

🪟 **HUD faces are 80% opaque by default** (`GoTheme.HUD_ALPHA`; 100 — fully opaque — under the Material presets),
so the world shows through a dock or a status bar. A HUD sits straight over the game with no scrim in front of it, so **this is the one place where
the default can be too low** — over a bright, busy or high-contrast world, raise it:
`GoUi.config.container_alpha_overrides = {GoTheme.BOX_HUD: 0.95}` for the project (a ratio 0–1 — `95` would be
clamped to 1.0), `GoStyle.hud_panel(Color.TRANSPARENT, -1.0, -1.0, GoTheme.BOX_HUD, 0.95)` for one panel, or
`GoStyle.floating(GoTheme.BOX_HUD, Color.TRANSPARENT, true)` (the third argument is `opaque`) where the text must
never fight the background.
Quick slots and badges stay solid regardless — they are pressables and markers, not containers.
Full rules: `theming.md` §4.

## 2. GoBar

`class_name GoBar extends Control` · input-transparent.

| Member | Default | Notes |
|---|---|---|
| `label_text` | `""` | Name on the left; empty hides |
| `ink` | transparent → `accent` | Use fill tokens: `GoUi.color(GoTheme.DANGER_FILL)` (`SUCCESS_FILL`, `WARNING_FILL`, `INFO_FILL`, `ACCENT_FILL`) |
| `enum Readout { NONE, VALUE, FRACTION, PERCENT }` · `readout` | `FRACTION` | `320` · `320 / 500` · `64%` (formats are translatable) |
| `ink_end` | transparent | A second paint the fill runs across to, left to right (an orange-to-yellow gauge). Arcade looks only (`GoStyleBoxArcade.end_color`); the others keep `ink` |
| `thickness` | `8` | dp |
| `segments` · `segment_count()` | `-1` → the look | Ticks that split the bar into chunks — decoration only, the fill still moves smoothly. `-1` asks the look (`GoSkin.bar_ticks()`: smooth by default, six chunks under the arcade looks), `0` is always smooth, `2`–`24` that many everywhere. The size never changes |
| `ease_seconds` | `0.18` | 0 = instant; `reduce_motion` also makes it instant |
| `icon` · `icon_size` · `icon_gap` | `null` · `16` · `3` | An icon before the name (a HUD's bolt) |
| `icon_beside` | `false` | The icon sits left of the bar instead, centred on it (`Track` › `Icon`, then the fill or the painted frame taking the rest of the width); the name row hides while it has no name and no readout |
| `label_size` · `label_ink` | `-1` · transparent | The name's and readout's size (-1: the compact role's) and colour (transparent: `secondary`) |
| `label_gap` · `lead` | `-1` · `0` | The room between the name row and the bar (-1: `gap_tiny`) · room left above the name |
| `frame_mode()` | | True when the look draws a painted frame (`GoSkin.bar_frame_box()`; `arcade_light`): a rounded groove clipping an `ink` → `ink_end` gradient (`Frame` › `Gradient`, `Ticks`) instead of the `ProgressBar` |
| `set_values(value, maximum, animate := true)` · `set_ratio(ratio, animate := true)` · `value()` · `maximum()` | | Pass `animate = false` for the first fill |
| `static format_amount(amount) -> String` · `static abbreviate(amount)` | | `12.3k`, `4.5m`, or `GoConfig.number_formatter` |

Give it a width: `bar.custom_minimum_size.x = 180` (or put it in an expanding container).

A match HUD's bar (Magnet Mayhem's power gauge, pixel-identical under `arcade_light`):

```gdscript
var power := GoBar.new()
power.label_text = "POWER"
power.readout = GoBar.Readout.NONE
power.icon = GoUi.skin().widget_art(&"bolt")
power.ink = Color("#1fb5f0")
power.ink_end = Color("#6ff0ff")
power.thickness = 14
power.label_size = 11
power.label_gap = 0
power.lead = 2
power.set_values(30, 100, false)
```

## 3. GoSlot

`class_name GoSlot extends Button` · Tab order off by default · uses `pressed` like any Button.

| Member | Default | Notes |
|---|---|---|
| `icon_name` | `&""` | `GoIconSet.POTION` etc. |
| `accent` | transparent → `accent` | Border / glow colour |
| `quantity` | `GoSlot.UNKNOWN` (-1) | `-1` shows `…`, `GoSlot.NONE` (-2) hides the badge (skills), `0` fades the slot |
| `timer_text` | `""` | Text badge over the icon (buff time) |
| `shortcut_label` | `""` | Top-left key hint — display only, handle input yourself |
| `visual_size` | `44` | Face size; touch area stays ≥ `min_touch_size`. Above the touch minimum (an inventory cell at 56–64) the slot's own box grows with it |
| `selected` | `false` | Picked cell — lit border **without** the cooldown's dimmed icon |
| `icon_ink` | transparent → text colour | The icon's own colour (an item's colour). Corrected for contrast against the slot face, so the hue survives and the icon never sinks in; empty / disabled slots still fade |
| `keyboard_focus` | `false` | Opt into Tab / gamepad focus |
| `touch_peers: Array[Control]` | `[]` | Overlapping 48 dp areas go to the nearer centre |
| `set_cooldown(left, total)` · `start_cooldown(seconds)` · `cooldown_ratio()` · `refresh()` | | `start_cooldown` counts down itself |

```gdscript
var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
var slots: Array[Control] = []
for i in 4:
	var slot := GoSlot.new()
	slot.icon_name = [GoIconSet.POTION, GoIconSet.BOLT, GoIconSet.SHIELD, GoIconSet.SWORD][i]
	slot.accent = GoUi.color([GoTheme.DANGER, GoTheme.WARNING, GoTheme.INFO, GoTheme.SUCCESS][i])
	slot.quantity = [12, 3, 0, GoSlot.NONE][i]
	slot.shortcut_label = str(i + 1)
	slot.pressed.connect(func() -> void: slot.start_cooldown(5.0))
	row.add_child(slot)
	slots.append(slot)
for slot in slots: (slot as GoSlot).touch_peers = slots
```

From `visual_size` 56 up (`GoSlot.LARGE_CELL`) the quantity badge uses the compact text size instead of the micro one.
🛑 HUD buttons over gameplay keep keyboard focus after a click, and Space then presses them again instead of reaching the
game — `GoIconButton.keyboard_focus = false`, or `GoHudAnchor.keyboard_focus = false` for the whole corner (`pitfalls.md`).

A slot with **no icon and `quantity = GoSlot.NONE`** is a *vacant cell* and draws faint, so a half-full bag reads as
"items, then room".

### GoSlotGrid — inventory grid

`class_name GoSlotGrid extends HFlowContainer` — *N* `GoSlot` cells that wrap to the width given: a bag, a chest, a shop
shelf. It holds **what to draw**, never item data; the game decides what a press or a move means.

| Member | Default | Notes |
|---|---|---|
| `slot_count` | `20` | Rebuilds cells; kept cells redraw what they held |
| `cell_size` | `56` | Face size of every cell (dp) |
| `draggable` | `false` | Drag a cell onto another → `slot_moved`. 🛑 Inside a scroll the finger drag belongs to the scroll — turn on for mouse play (`not DisplayServer.is_touchscreen_available()`) and keep a tap route (pick → Move → tap target) |
| `selected` | `-1` | The one picked cell; out of range clears it. Kept when set before the grid is in the tree |
| `keyboard_focus` | `true` | Tab / gamepad reach the cells (a bag in a sheet). **Off** for a hotbar over gameplay |
| `set_cell(index, data)` · `set_cells(list)` | | `data`: `{icon, quantity, accent, ink, tooltip, disabled, timer}` — all optional, `{}` = vacant, no `quantity` key = no count badge (equipment) |
| `cell(index) -> Dictionary` · `slot(index) -> GoSlot` | | Read back / reach the slot for cooldowns and shortcut labels |
| icons | | 🛑 Cells draw with the **global** set — `GoGameIcons` names need `GoUi.config.icons = GoGameIcons.icon_set()` first |
| signals | | `slot_pressed(index)` (vacant cells too) · `slot_moved(from, to)` (the grid moves nothing itself) |

```gdscript
var grid := GoSlotGrid.new()
grid.slot_count = 30
grid.cell_size = 60
grid.draggable = not DisplayServer.is_touchscreen_available()
sheet.body.add_child(grid)
for index in bag.size():
	grid.set_cell(index, {"icon": bag[index].icon, "quantity": bag[index].count, "accent": bag[index].color, "tooltip": bag[index].name})
grid.slot_pressed.connect(func(index: int) -> void: grid.selected = index)
grid.slot_moved.connect(func(from: int, to: int) -> void: swap_items(from, to))
```

## 4. GoJoystick

`class_name GoJoystick extends Control` · takes touch and mouse · layout LTR.

| Member | Default | Notes |
|---|---|---|
| signals | | `moved(vector: Vector2)` (length 0–1, emitted with ZERO on release) · `released` · `pressed_down` |
| `enum Mode { FIXED, FOLLOW, RELATIVE }` · `mode` | `FOLLOW` | FIXED: same place · FOLLOW: centre where the thumb lands · RELATIVE: centre drags along |
| `radius` · `knob_radius` | `72` · `28` | dp; `radius` sets `custom_minimum_size` |
| `dead_zone` | `0.12` | Below it `moved` sends `Vector2.ZERO` |
| `ink` · `hide_when_idle` | transparent · `false` | `hide_when_idle` suits FOLLOW/RELATIVE |
| `vector()` · `is_active()` | | Poll instead of the signal if you prefer |
| `center()` · `knob()` | | Where the dish and the knob are drawn now (local) |
| `driven` | `false` | The owner routes the fingers: input ignored (`mouse_filter` IGNORE), and `drive_begin(at)` · `drive_drag(at)` · `drive_end()` move it as a finger of its own would (signals and `vector()` included). `hits(at)` hit-tests its rect. Points are canvas coordinates, as an `_input` event carries them. Hidden, it keeps the drag |

The hit area is the control's rect. For "thumb anywhere on the left half", size the joystick to that area
instead of putting it in an anchor:

```gdscript
var pad := GoJoystick.new()
pad.mode = GoJoystick.Mode.FOLLOW
pad.hide_when_idle = true
pad.anchor_right = 0.5
pad.anchor_bottom = 1.0
pad.anchor_top = 0.35                     # lower-left zone
hud_root.add_child(pad)
func _physics_process(delta: float) -> void:
	player.velocity = Vector3(pad.vector().x, 0, pad.vector().y) * speed
```

## 5. GoIconButton

`class_name GoIconButton extends Button`. Prefer the factory `GoStyle.icon_button(icon, action, visual := -1, tooltip_key := &"")`.

| Member | Default | Notes |
|---|---|---|
| `visual_size` | `36` | Visible square; touch grows to `min_touch_size` beyond the node |
| `icon_name` · `set_icon_name(name)` | | |
| `icon_tint` | transparent → theme colour | |
| `native_texture_size` | `false` | Draw a texture icon at its own pixel size |
| `art` | `null` | A picture that is the whole button (a painted round pause button): it fills `visual_size`, no frame in any state, drawn in its own colours, multiplied by `GoSkin.picture_press_tint()` while pressed. Replaces `icon_name`; null brings the icon and frame back |
| `tooltip_text_name` | `&""` | Passed through `GoUi.text()` — a built-in name (`close`, `back`…) through `text_keys`, anything else (your translation key or plain words) through the translation server. Also sets `accessibility_name` |
| `keyboard_focus` | the look's (`true`; `false` under arcade_light) | **Off** over gameplay — a clicked button would keep focus and Space would press it again. Reads the effective mode (`focus_mode == FOCUS_ALL`); setting it pins the choice through look changes, and only a set value is saved in a scene |
| `touch_peers` | `[]` | Required when icon buttons sit side by side |

🛑 The widened touch area covers neighbours. Only put it next to non-interactive siblings, or set `touch_peers`.

## 6. GoNotice

`class_name GoNotice extends PanelContainer` · ignores mouse and focus recursively — presses go through it.

| Member | Notes |
|---|---|
| `show_text(message, tone := GoTheme.TEXT, seconds := -1.0)` | `tone` is a colour token name (`GoTheme.SUCCESS`, `DANGER`…); -1 → `notice_duration_ms` token |
| `show_key(key, arguments := {}, tone := GoTheme.TEXT, seconds := -1.0)` | Re-translates on locale change |
| `set_message(message, tone)` | Sets the text and tone only — it does not `show()` the notice and does not stop a running timer |
| `set_content(control, accent := transparent, compact := false)` · `set_accent(color)` | Rich content; lifetime is yours |
| `preferred_width(limit) -> float` · signal `expired` | |

```gdscript
var toast_anchor := GoHudAnchor.new()
toast_anchor.spot = GoHudAnchor.Spot.TOP_CENTER
toast_anchor.reserve_space = false      # do not push page content
toast_anchor.avoid_peers = true         # settle below the health bar
hud_root.add_child(toast_anchor)
var notice := GoNotice.new()
notice.custom_minimum_size.x = 260
toast_anchor.add_child(notice)
notice.show_text("Quest updated", GoTheme.SUCCESS)
```

## 7. GoPromptCard

`class_name GoPromptCard extends PanelContainer` · no scrim, only the card takes input · **starts hidden**.

| Member | Notes |
|---|---|
| `set_title(text)` · `set_title_key(key, args := {})` · `set_subtitle(text)` · `set_subtitle_key(key, args := {})` | |
| `set_title_lines(n)` (2) · `set_subtitle_lines(n)` (1) | |
| `set_icon(icon, ink := transparent, boxed := false)` · `set_accent(color)` · `set_closable(on)` | `boxed` puts the icon in an accent disc |
| `set_actions([{"text"|"key": …, "action": Callable, "primary": bool, "danger": bool, "disabled": bool, "name": String}])` | Same shape → buttons are reused (no lost taps on refresh) |
| `fit_width(width)` · `fade_in` (true) · signal `closed` (X pressed — you hide it) | Owner decides placement and width |

```gdscript
prompt.set_icon(GoIconSet.USER_PLUS, GoUi.color(GoTheme.ACCENT), true)
prompt.set_title("Aria invited you to a party")
prompt.set_subtitle("Level 42 · Guardian")
prompt.set_closable(true)
prompt.closed.connect(prompt.hide)
prompt.set_actions([
	{"text": "Accept", "action": _accept, "primary": true},
	{"text": "Decline", "action": prompt.hide},
])
prompt.fit_width(300)
prompt.show()
```

## 8. GoCoachMark

`class_name GoCoachMark extends Control` · full rect, input-transparent except its card.

| Member | Default | Notes |
|---|---|---|
| `start(steps: Array)` · `advance()` · `finish(completed)` | | |
| step dict | | `target: Control` (missing/hidden → skipped) · `title` · `body` (text or translation key) · `signal` (default `"pressed"`, **no-argument signals only**) |
| signals | | `finished(completed: bool)` · `step_changed(index)` |
| `card_max_width` | `280` | |
| `avoid_center_band` | `0.45` | Portrait: keep the card above this share of the screen |
| `ink` · `keep_clear: Array[Control]` | transparent · `[]` | Non-anchor fixtures (header, toolbar) the card must not cover |

Pressing the highlighted control itself advances. The card hides while any `GoSurface` is open. Escape / Back
finishes with `false`. Add it last (or on a top `CanvasLayer`) so it draws above what it points at.

```gdscript
var tour := GoCoachMark.new()
add_child(tour)
tour.keep_clear = [top_bar]
tour.finished.connect(func(done: bool) -> void: save.tutorial_seen = true)
tour.start([
	{"target": bag_button, "title": "Bag", "body": "Everything you pick up lands here."},
	{"target": map_button, "title": "Map", "body": "Press to open the full map."},
])
```

## 9. GoContextMenu — long-press and right-click

```gdscript
GoContextMenu.attach(item_slot, [
	{"text": "Use", "action": use},
	{"text": "Equip", "action": equip},
	{"separator": true},
	{"text": "Drop", "action": drop, "danger": true},
])

# A list that changes per row — build it when it opens
GoContextMenu.attach(player_row, func() -> Array: return menu_for(player))

# A visible "⋯" button opens the same menu without the hold
GoContextMenu.open_at(more_button, items)
GoContextMenu.detach(item_slot)
```

| Item key | Meaning |
|---|---|
| `text` | Row label (a translation key when `translate: true`) |
| `action` | `Callable` to run |
| `icon` | Icon name (texture sets only — `PopupMenu` cannot draw font glyphs) |
| `disabled` · `checked` · `separator` · `danger` | Greyed · tick mark · divider line · destructive colour |
| `translate` | `true` treats `text` as a translation key (default `false`: shown as written) |

- `HOLD_SECONDS = 0.5` matches Android; `SLOP_DP = 12` cancels the hold **the moment the finger moves**, so
  scrolling a list never pops a menu. Right-click opens it immediately on desktop.
- 🛑 **A long press needs a second way in.** Nobody discovers a hidden gesture — pair it with a visible `⋯`
  (`open_at()`), an icon, or a first-run `GoCoachMark`.
- The holder is a `RefCounted` hung on the control's meta, not a node — it does not change the tree shape.

## 10. GoConsole — developer console

```gdscript
var console := GoConsole.new()
add_child(console)
console.register("give", "Grant an item: give <id> <count>", func(args: PackedStringArray) -> String:
	return "granted %s" % " ".join(args))
console.log_line("connected to server", GoTheme.SUCCESS)
console.toggle()          # Escape closes; ↑/↓ walk the history
```

`layer_index` 200 (above everything, so you can debug over a dialog) · `max_lines` 400 (older lines are
dropped) · `height_ratio` 0.55 · `executed(command, args, result)` signal · `open()` `close()` `toggle()` `is_open()` ·
`run(line) -> String` (runs a command as if typed — for tests and autoexec) · `unregister(command)` · `commands()`.

🛑 **`debug_only` is on by default and `open()` does nothing in a release build.** Cheat commands in a
player's hands end a game's economy. Turn it off only for a QA build, and gate it yourself.
🔑 Typing filters the registered commands into a palette — nobody has to memorise them. `help` and `clear`
are registered for you.

## 11. GoSpinner — waiting

```gdscript
var busy := GoSpinner.new()
card.add_child(busy)

GoSpinner.busy(buy_button, true)          # the button becomes a spinner, in place
var ok := await server.purchase(item)
GoSpinner.busy(buy_button, false)
```

`seconds_per_turn` 1.1 · `thickness` (−1 = diameter/9) · `ink` (empty = accent, pushed to 3:1 on every face) · `show_track`.

- **`busy()` keeps the button's size** — the label is made transparent rather than removed, so the row does
  not jump. It also sets `disabled`, which is the point: a purchase must not fire twice while you `await`.
  `is_busy(button)` asks. Calling it twice adds one spinner, not two, and turning it off restores the exact
  theme overrides it found.
- 🔑 **A busy button keeps its normal face**, not the pale disabled one, and the spinner draws in the button's text
  colour (read as it draws, so calling `busy()` before the button is in the tree is fine). On the disabled face a
  primary button's white spinner disappeared in every look.
- ♿ With `reduce_motion` on it does not spin — three dots pulse instead. It also stops while hidden.
- 🔑 Progress you can measure is a `GoBar`. A spinner promises nothing about when it ends.

## 12. GoBadge — counts and dots

```gdscript
GoBadge.attach(mail_button, unread_count)      # hides itself at 0
GoBadge.attach(shop_button, 0, "NEW")          # a word instead of a number
GoBadge.attach(friend_button, 3, "", true)     # a dot — "something is there"
row.add_child(GoBadge.make(12))                # standalone, inside a row
GoBadge.detach(mail_button)
GoBadge.stick(stage_card, "PLAY!", GoUi.color(GoTheme.SUCCESS_FILL), -8.0)   # a sticker: solid, tilted
GoBadge.stick(stage_card, "", Color.TRANSPARENT, 0.0, &"check")               # a round sticker with an icon
```

`cap` 99 (`99+` beyond it) · `label_text` · `dot` · `ink` (empty = danger) · `hide_when_zero` ·
`set_count(value)` / `count()` (change a badge you hold — `attach()` again does the same for an attached one) ·
`GoBadge.make(count, words, as_dot, color)` · `solid` (a sticker — `GoSkin.sticker_box()`, a glossy key under the
arcade looks) · `icon` (a `GoIconSet` name drawn instead of the words; the badge turns round) · `tilt` (−45–45°,
round its centre — layout keeps the upright size) · `text_role` (`ROLE_MICRO`) ·
`GoBadge.stick(host, words, color, degrees, icon)` (attach + solid + `ROLE_BODY`; colour defaults to `SUCCESS_FILL`).

- `attach()` pins it to the **top-right corner of the host**, half outside, with anchors — so it follows a
  host whose size is decided later. Attaching twice returns the same badge.
- 🔑 A number when the count changes what the player does; a dot when only "there is something" matters.
- ♿ The badge carries an `accessibility_name`, and its text colour is its own colour pushed until it reads on the
  face the skin **actually paints** — never assumed white, never measured against a colour that is not drawn.
- It stays one line and re-centres on the corner when its size changes (`3` → `128`). A dot badge is a solid dot.

## 13. GoRewardCalendar — daily attendance

```gdscript
var attendance := GoRewardCalendar.make([
	{"icon": &"coin", "amount": 100},
	{"icon": &"potion", "amount": 3},
	{"icon": &"crown", "amount": 1, "special": true},
], 1)                                          # claimed through day 2
attendance.claimed.connect(func(day: int) -> void: server.claim_day(day))
attendance.set_claimed_until(server_value)     # after the server confirms
```

`columns` 7 (at most per row) · `cell_size` (−1 = the content decides, never below touch; a positive value is a
floor and sets the picture to 36% of it) · `wrap_to_width` (on) · `today()` returns the claimable index, `-1` when done.

- 📐 **A cell is sized by what it holds.** Day number, picture (24 dp) and amount sit inside padding
  (`GoStyle.cell_body`) and the cell grows to fit, square — the content never touches the border or spills past it,
  inside a `GoForm` too. Cells are the same size and at least the touch minimum.
- 📱 **A row never runs off a phone.** When `columns` cells do not fit the width, the row wraps sooner and evenly
  (seven days on a phone: 4 + 3, never 6 + 1). The days are positions in a streak, not weekdays, so wrapping loses
  nothing. `wrap_to_width = false` keeps exactly `columns` per row and leaves the width to you (~600 dp for seven).
- 🛑 **Only today's cell is pressable.** Claimed and future cells are disabled — a button that does nothing
  when pressed reads as broken.
- ♿ Claimed / today / future differ by **three things**: a tick glyph, an accent border, and dimming — and
  the state is in the accessible name. Dimming alone cannot separate "claimed" from "not yet". Dimming moves
  **colours** toward the muted end (never `modulate` alpha), and every number and amount keeps 4.5:1 on its face.

## 14. GoRadar and GoDonut — stats at a glance

```gdscript
var stats := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45})
stats.set_compare(with_new_sword)              # dashed overlay

var share := GoDonut.make([
	{"label": "Physical", "value": 620},
	{"label": "Magic", "value": 340, "color": Color("4a8fe0")},
])
share.center_text = "1050"
share.center_hint = "Damage"
card.add_child(share.legend())
```

- **Radar values are 0–1.** What counts as 1 (the class cap? the server's best?) is a game decision the
  widget cannot make; raw 120 STR next to 45 INT would draw a lie. Needs at least three axes.
- **Donut values are raw** — it divides for you. It collapses past `collapse_to` (5) slices into one, because
  a sixth slice is a thread nobody can read, and `legend()` prints name **and** percent as words.
- ♿ Both expose the numbers through `accessibility_name`, and the radar's comparison line is **dashed** so it
  survives colour blindness.

## 15. GoCarousel — banners and character select

```gdscript
var banners := GoCarousel.new()
banners.custom_minimum_size.y = 160
banners.set_pages([promo, event, pack])
banners.page_changed.connect(track_view)
banners.autoplay_seconds = 5.0                 # off by default
```

`loop` · `show_dots` · `swipe_dp` 48 · `motion_seconds` · `next()` `previous()` `go_to(i)` `index()`.

- 🛑 **It does not advance on its own unless you ask** (`autoplay_seconds` 0). Give it 5 s or more — nothing enforces
  it, but a banner that changes every 3 s takes the text away before it is read. Touching it resets the timer.
- ♿ With `reduce_motion` on, autoplay is off entirely; the dots still work, so nothing is lost.
- 🔑 **It is as tall as its tallest page** — the pages' minimum height is fed up, so a banner is never sliced.
  `custom_minimum_size` is a floor, not the room (a fixed 120 once cut a banner's title in half).
- The dots are **one bar a finger tall**, drawn close together: a press on a dot goes to that page, a press on the open
  bar either side goes one page that way. So the press area is far wider than the touch minimum however small the dots.
  The lit dot is a longer pill — position is not told by colour alone. ←/→ step, and a screen reader hears `2 / 3`.

## 16. App screens — navigation bar, app bar, FAB, search, split button, progress, loading, dates

The parts of a social, news or shopping app screen. Every one draws through a `GoSkin` hook (theming.md §6): each
preset gives it its own shape, and the Material presets give it the M3 component's measures.

```gdscript
var screen := VBoxContainer.new()                      # a full-rect column
var bar := GoAppBar.make("Inbox", GoIconSet.MENU, open_drawer)
bar.add_action(GoIconSet.SEARCH, &"search", open_search)
screen.add_child(bar)
var list := GoScroll.new()
list.size_flags_vertical = Control.SIZE_EXPAND_FILL
screen.add_child(list)
bar.follow(list)                                       # flat at the top, lifted once the page scrolls
var nav := GoNavBar.make([
	{"icon": GoIconSet.HOME, "text": "Home"}, {"icon": GoIconSet.BELL, "text": "Alerts", "badge": 3},
], 0, show_tab)
screen.add_child(nav)
var compose := GoFab.make(GoIconSet.EDIT, "", write)
compose.tooltip_text_name = &"Compose"                 # an icon-only FAB needs its name
compose.float_in(self, nav.get_combined_minimum_size().y)
```

| Class | Members |
|---|---|
| `GoNavBar` (PanelContainer) | `make(items, chosen, action, translate)` · `rail(...)` (a column for a wide screen) · `drawer_list(...)` (full-width rows for a `GoDrawer`; `chosen` is clamped, so one row always carries the pill — menu actions are `GoStyle.list_button` rows instead) · signal `selected(index)` · `selected_index()` · `set_selected(i)` (no signal) · `set_badge(i, count, words, as_dot)` · `cell(i) -> Button` · `vertical` · `safe_area` · items `{"icon", "text", "badge", "dot"}` |
| `GoAppBar` (PanelContainer) | `make(title, leading, action, translate)` · `set_title()` · `set_leading(icon, action)` · `add_action(icon, tooltip, action) -> GoIconButton` · `follow(scroll)` · `expanded_title(bar_size := Size.LARGE) -> Control` (the big title that scrolls away — put it first in the page; `Size.SMALL/MEDIUM/LARGE`) · `scrolled` · `centered` · `safe_area` · signal `navigated` · `title_label` · `leading_button` · `leading_action` · `actions` |
| `GoFab` (Button) | `make(icon, text, action, size)` · `Size.SMALL/REGULAR/MEDIUM/LARGE` (40/56/80/96) · `fab_size` · `icon_name` · `label_text` (extended) · `expanded` · `follow(scroll)` · `float_in(host, above)` · `tooltip_text_name` |
| `GoSearchBar` (PanelContainer) | `make(placeholder, action, translate)` · signals `submitted(query)` · `text_changed(query)` · `add_action(icon, tooltip, action)` · `get_text()` · `set_text()` · `field` · `actions` |
| `GoSplitButton` (HBoxContainer) | `make(text, action, items, tone, translate)` · signal `chosen(index)` · `main_button` · `menu_button` |
| `GoProgress` (Control) | `linear(indeterminate)` · `circular(indeterminate)` · `value` 0–1 · `indeterminate` · `wavy` · `thick` · `kind` |
| `GoLoadingIndicator` (Control) | `contained` — 48 dp, runs while visible |
| `GoDatePicker` (Container) | `make(selected, action)` · signal `picked(date)` · `get_date()` · `set_date()` · `show_month(year, month)` · `shown_month()` · `min_date` · `max_date` · `first_weekday` · static `today()` — dates are `{"year", "month", "day"}` |

- 🔑 **One FAB per screen** — it says "this is what you came here to do". Two say nothing.
- 🔑 **A navigation item switches the page**; an action goes on a FAB or in the app bar. More than five
  destinations do not fit a phone — move the rest into a `GoDrawer`.
- 🛑 `GoFab.float_in(host, …)` needs a host that is **not a container** (a container would lay the FAB out itself).
- ♿ Icon-only parts carry their names: app bar actions and the FAB take a tooltip name, the split button's arrow is
  "More options", the search bar's clear button "Clear", the date arrows "Previous month" / "Next month" — all from
  gohud's translations (`GoConfig.text_keys`), so they follow the game's language.
- ♿ `GoProgress` speaks its percentage (`bar_percent`) or "Loading…"; `GoLoadingIndicator` says "Loading…".
  With `reduce_motion` the wave stands still and the loading shape only breathes.
- 📱 A date picker on a 320 dp phone keeps seven columns: each day narrows to 36 dp but stays 48 dp tall.

## 17. From Flutter

The widgets a Flutter app reaches for — `GoScaffold`, `GoListView`, `GoRefresh`, `GoSwipeRow`, `GoTabView`,
`GoReorderList`, `GoZoomView`, `GoRangeSlider`, `GoTimePicker`, `GoWheelPicker`, `GoStepper`, `GoBanner`,
`GoDialogs.choose()` — have their member tables, examples and the full Flutter → gohud catalogue in
`references/flutter.md`. A whole app screen built from them is `assets/templates/app_screen.gd`.

- 🔑 None of these takes the page's scroll from it: a sideways swipe is the row's or the tab page's, a downward pull at
  the top is the refresh's, a drag that starts on a grip, a zoom view, a wheel or the time dial is theirs — any other
  drag scrolls the page.

## 18. GoChoiceColumn — a column of choices you tap once

A short list on the HUD — the animals a player can call, the friends to summon, the filters that are on. A few rows
show at a time and the column scrolls up and down; **one tap on any row acts at once** (a `GoWheelPicker` settles on
one value instead — wrong for a list of actions). Marks are the game's: the column never chooses by itself.

```gdscript
var animals := GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig", "Cow"], 4, func(index: int) -> void: summon(index))
animals.set_selected(2, true)           # the dog is out — its row stands out
animals.set_dimmed(4, true)             # the cow is resting — greyed, but a tap still says why
side_bar.add_center(animals)
# When the dog goes home:
animals.set_selected(2, false)
```

| Member | Notes |
|---|---|
| `make(choices, rows := 4, action := Callable())` · `set_items(choices)` · `item_count()` | A choice is a text or `{"icon", "text", "tooltip"}`; `set_items` keeps the marks that still fit |
| signal `item_pressed(index)` | A tap that lets go on the same row without moving, or `ui_accept` (Enter, Space) while focused. The `action` given to `make()` is called with the same index, right after the signal |
| `set_selected(i, on)` · `is_selected(i)` · `selected_indices()` · `clear_selected()` | Any number of rows; a plate and a ring in `selection_color` (the accent when transparent) |
| `set_dimmed(i, on)` · `is_dimmed(i)` | Greys a row; it still fires |
| `scroll_to(i, animate)` · `get_scroll()` · `max_scroll()` · `row_rect(i)` · `row_at(pos)` | Rows rest on whole rows after a drag or a flick; the mouse wheel moves one row |
| `item_drawer` | `func(canvas, index, rect, chosen, dimmed)` — draw a face or a swatch inside `rect`; keep a `"text"` for the tooltip and the screen reader |
| `item_height` · `visible_items` · `item_gap` · `padding` · `panel` · `selection_color` · `translate` | `item_height` never goes under the `touch` token |

- 🛑 `focus_mode` is `FOCUS_NONE` by default — over a game the arrow keys keep walking the player. A menu turns it on:
  Up / Down move a ring (keyboard focus only), Enter or Space presses.
- 🔑 A drag that starts on it is its own (`GoScroll.OWNS_GESTURE`); a move under 6 dp is still a tap.
- ♿ The tooltip is the row's `tooltip` or text; the column's spoken name is the focused row and a ✓ when it is chosen.

## 19. Composing a full HUD — anchors or edge bars

Two ways to place a HUD. **Anchors** (`GoHudAnchor`, below) put loose pieces in corners and on edge middles
and step them aside from each other. **Edge bars** (`GoTopBar` · `GoBottomBar` · `GoLeftSideBar` · `GoRightSideBar`,
`style.md` §1 "Layout classes") line pieces up along an edge in one to three slots, keep the centre slot on the
centre, and keep the side bars between the top and bottom bars (`clear_of`). Rows and columns along the edges → bars;
loose pieces → anchors. Both go on a full-rect root that ignores the mouse, in a `CanvasLayer` on layer 5.

### With anchors

```gdscript
func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5                                   # sheets are 10, dialogs 100
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 🛑 never block the game under empty HUD space
	root.theme = GoUi.theme()
	layer.add_child(root)

	var status := GoHudAnchor.new()
	status.spot = GoHudAnchor.Spot.TOP_LEFT
	root.add_child(status)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))
	status.add_child(panel)
	var bars := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	bars.custom_minimum_size.x = 180
	panel.add_child(bars)
	for spec in [["HP", GoTheme.DANGER_FILL, 320, 500], ["MP", GoTheme.INFO_FILL, 88, 120]]:
		var bar := GoBar.new()
		bar.label_text = spec[0]
		bar.ink = GoUi.color(spec[1])
		bars.add_child(bar)
		bar.set_values(spec[2], spec[3], false)

	var menu := GoHudAnchor.new()
	menu.spot = GoHudAnchor.Spot.TOP_RIGHT
	root.add_child(menu)
	menu.add_child(GoStyle.icon_button(GoIconSet.MENU, open_pause_menu, -1, &"Menu"))
```

The complete, runnable version (bars, slots, joystick, toast, prompt, pause button) is
`assets/templates/game_hud.gd`.

### With edge bars

```gdscript
var top := GoTopBar.make(3)
top.add_start(status_plate)                       # HP and MP side by side
top.add_center(stage_plate)                       # on the centre, however wide the sides are
top.add_end(coins_plate)
root.add_child(top)                               # the root is not a container → pinned to the top edge
var bottom := GoBottomBar.make(1, GoBottomBar.Justify.CENTER)
for name in ["Attack", "Guard", "Run"]: bottom.add_start(GoStyle.button(name, act.bind(name)))
root.add_child(bottom)
var left := GoLeftSideBar.make(1, GoLeftSideBar.Justify.CENTER)
left.add_start(GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig"], 3, summon))   # §18
root.add_child(left)
left.clear_of([top, bottom])                      # its items stay between the two bars
```

- 🔑 `clear_of()` moves the side bar's **items** between the other bars; the bar itself still runs the full height
  (`get_global_rect()` of the bar is the whole side — measure an item to see where it sits).
- 📱 Add up the heights: on a landscape phone (390 dp tall) the top bar, the bottom bar and the tallest side bar must
  fit together, or the side bar runs off its edge and warns once (`… needs 438 along its edge but has 390`). Put HP and
  MP side by side, show three rows of a `GoChoiceColumn` instead of four. On a portrait phone two side bars squeeze the
  play field — use anchors there.
- 🔑 A HUD gives its root `layout_direction = LAYOUT_DIRECTION_LTR`: the bars keep their physical sides in Arabic.

The complete, runnable version (status, stage, coins, menu, summon column, quick slots, actions) is
`assets/templates/edge_bar_hud.gd`.

## 20. GoLevelCard — a stage-select tile

`class_name GoLevelCard extends Button`. The thumbnail on the left, the title and a subtitle row ("OPPONENTS: 3" with a
person icon) beside it, and on the right the state: a check on a cleared level, a padlock and LOCKED on a locked one,
a tilted PLAY! tag on the level to play next. A gold ring marks the selected tile. `stars` adds a row of rating stars
under the subtitle.

```gdscript
var card := GoLevelCard.make("STAGE 3", "OPPONENTS: 3", GoLevelCard.State.CURRENT)
card.thumbnail = preload("res://levels/3.png")      # or put your own node in card.thumbnail_slot
card.selected = true
card.stars = 2                                      # 2 of 3 lit — cleared on normal, say
card.pressed.connect(_play.bind(3))
```

| Member | Notes |
|---|---|
| `make(text, sub := "", level_state := State.OPEN)` · `enum State { OPEN, CLEARED, CURRENT, LOCKED }` · `state` | A `LOCKED` tile is `disabled` and takes no press |
| `title` · `subtitle` · `locked_text` ("LOCKED") · `play_text` ("PLAY!") | The texts come from the caller (language); each shrinks to fit with `GoStyle.fit_font_size`. An empty `subtitle` hides the row |
| `thumbnail` · `thumbnail_focus` · `thumbnail_slot` | The picture is drawn through `GoCoverImage`; leave it empty to put your own node in the slot |
| `selected` | The gold ring (`GoSkin.selection_ring_box()`) |
| `stars` (0) · `max_stars` (3) · `star_size` (22, readable on a phone) · `star_gap` (2) · `star_row` | A `GoStarRow` as a third line under the subtitle, lined up with the title: `stars` of `max_stars` lit. 0 shows no row (a card that never sets it is unchanged); a `LOCKED` tile shows none. The corners stay free for the check, the PLAY! tag and the pointer |
| `check_texture` · `lock_texture` · `person_texture` · `play_tag_texture` · `pointer_texture` | Art overrides. Empty: the skin (`GoSkin.widget_art`), else the icon set, else a drawn plate — a look with no art still works |
| `scale_factor` · `card_size` (300×98) | Sizes are multiplied by `scale_factor` |
| `lock_gap` (4) | Pixels between the padlock and LOCKED — set on the column, so a theme's own VBox gap never reaches it |

- 🔑 The face comes from the type variation for the state — `GoLevelCard` (open and cleared), `GoLevelCardCurrent`,
  `GoLevelCardLocked`; a theme without them falls back to `GoButton` (`GoPrimaryButton` for the current level).
- The thumbnail slot clips its contents, as the game's map preview does: on a scaled canvas no half row of the well
  or the picture shows past the slot.

### GoStarRow — rating stars

`class_name GoStarRow extends HBoxContainer`. `stars` of `max_stars` lit, the rest dim — a level's best clear, a result
screen's grade. The same row `GoLevelCard.stars` shows, on its own for a dialog or a victory screen.

```gdscript
var rating := GoStarRow.make(2)           # two of three lit
rating.star_size = 40.0                   # a victory screen's big row
rating.stars = 3
```

| Member | Notes |
|---|---|
| `make(earned_stars := 0, total := 3, side := 18.0)` | |
| `stars` (0) · `max_stars` (3) | More than `max_stars` lights them all; under 0 counts as 0. `earned()` is the clamped count, `is_earned(i)` one star |
| `star_size` (18) · `gap` (2) · `scale_factor` (1) | `star_side()` and `row_size()` give the drawn sizes |
| `earned_texture` · `empty_texture` · `star_nodes` | Art overrides. Empty: the skin (`GoSkin.widget_art` `star` / `star_empty` — arcade_light's painted gold star and grey slot), else the icon set's `GoIconSet.STAR` in `warning_fill`, faded `muted_fill` for an unearned one |

- 🛑 It ignores the mouse and never flips with the language: the first lit star is the left one. A screen reader hears
  "2/3" (`accessibility_name`).
- arcade_light's stars are solid: the earned one gold with the navy rim and a gloss, the unearned one a filled grey star.
  `GoUi.icons().node(GoIconSet.STAR, ...)` in arcade_light is that same gold star (a picture — leave the ink empty).
- 🛑 It changes its stars in place: a card re-dresses its row in its deferred refresh, and freeing and adding a glyph
  in that pass under a `GoScroll` never let the frame end (4.7.2).

## 21. GoKeyCluster — WASD or arrows in a T

`class_name GoKeyCluster extends Control`. Four movement keys in an inverted T, as a controls page of a game shows them.
Each key is the look's keycap (`GoSkin.key_cluster_box()`); an arrow label is drawn as a triangle, any other word is
engraved and shrunk to fit the cap.

```gdscript
var wasd := GoKeyCluster.make(["W", "A", "S", "D"])
var arrows := GoKeyCluster.make(GoKeyCluster.ARROWS)
arrows.picked.connect(func(): settings.hand = RIGHT)      # a click picks this layout
```

`labels` (up, left, down, right — the order of the T, not the keyboard row) · `key_size` (34) · `gap` (4) · `label_size`
· `face_lift` · `arrow_half` · `key_rects()` · `label_at(i)` · `arrow_direction(word)` · `word_size(word)` · signal `picked`.

- 🛑 Key names are never translated: they must read as engraved on the keyboard.

## 22. GoCoverImage — a picture that covers its box

`class_name GoCoverImage extends Control`. CSS `object-fit: cover`: the texture is scaled until it covers the whole rect,
keeping its proportions, and the overflow is cut off.

```gdscript
var shot := GoCoverImage.make(preload("res://art/level_3.png"), Vector2(0.5, 0.3))   # keep the upper middle
shot.custom_minimum_size = Vector2(74, 74)
```

`texture` · `focus` (0..1 on each axis — which part stays in view) · `make(picture, keep)` · static `cover_rect(area,
tex_size, keep) -> Rect2`.

- 🔑 Only the visible part of the texture is sampled, so it needs no `clip_contents` on the parent. It ignores the
  mouse, so a card or button under it still takes the press.

## 23. GoGlyphButton — a glyph beside the label

`class_name GoGlyphButton extends Button`. The glossy pill of an arcade menu: the glyph is `GLYPH_SHARE` (0.62) of the
button's height, and glyph, gap and label stand centred together.

```gdscript
var play := GoGlyphButton.make("Play", GoIconSet.PLAY, GoTheme.VAR_PRIMARY_BUTTON)
var own := GoGlyphButton.make("Shop", &"", GoTheme.VAR_BUTTON, preload("res://ui/cart.png"))
```

`glyph` (a texture) · `glyph_icon` (an icon-set name used when `glyph` is empty) · `glyph_texture()` · `glyph_allowance()` ·
`glyph_rect()` · `fit_label` (`false`) · `fit_base_size` (`0`) · `fitted_font_size()` · `fit_now()`.

```gdscript
var save := GoGlyphButton.make(tr("SAVE"), GoIconSet.CHECK, GoTheme.VAR_PRIMARY_BUTTON)
save.fit_label = true                      # a long translation shrinks to fit beside the glyph
```

- 🛑 `Button.icon` cannot do this: LEFT pins the glyph to the button's edge and CENTER draws it over the text. The label
  stays a plain `text`, so translation and tests work as on any button.
- 🛑 `glyph_icon` needs a texture icon set — a font icon has no texture, and the button then shows its label alone.
- 🔑 `fit_label` shrinks the label (`GoStyle.fit_font_size()`, never under `GoStyle.fit_floor()`) to the button's width
  less its normal face's minimum width and `glyph_allowance()` — the sum each Magnet Mayhem screen did by hand — on
  every resize, text, glyph and look change (deferred to the end of the frame; `fit_now()` at once). It shrinks from
  `fit_base_size`, or the look's `font_size` for the variation (22 on the `arcade_light` pills). Give the button its
  width (`custom_minimum_size`, a container share): a button left at its minimum width measures the room from itself.
- 🔑 The label moves by half the glyph's room: on a face with real padding (at least `MIN_EDGE` on the far side, as the
  painted pills) that much padding goes from the far side to the near one, exactly as Magnet Mayhem's `GlossButton` —
  the button grows only past the far padding, so a 56 × 56 glyph-only pill stays 56 wide. A thinner face keeps the
  group centred and the glyph `MIN_EDGE` off its side.

## 24. GoSlider — a slider drawn the painted way

`class_name GoSlider extends HSlider`. The settings slider of Magnet Mayhem, drawn exactly as the game draws it: the
fill runs `FILL_PAST` (2) past the handle's centre and is never shorter than the track is tall, and a held handle is
drawn `HELD_SCALE` (1.12) larger. Values, steps, signals, keys and touch are the stock HSlider's.

```gdscript
var music := GoSlider.make(0.0, 1.0, 0.01)
music.theme_type_variation = &"GoSliderGreen"      # GoSliderCyan, or none for the blue fill
```

`make(minimum, maximum, snap)` · `part(item)` (the theme part it draws) · `handle_size()` · `handle_center_x()` ·
`bar_rect()` · `fill_rect()` · `handle_rect()`. Its least size is its `custom_minimum_size`, set when it is made (120 wide, `GoTheme.TOUCH` tall) — the engine's Slider would measure the blanks; a screen that sets its own wins.

- 🔑 The parts are the theme's own HSlider parts (`slider`, `grabber_area`, `grabber_area_highlight`, `grabber`,
  `grabber_highlight`, `grabber_disabled`), read again when the theme or the variation changes — every preset draws its
  own look, and a variation gives only the parts it changes.
- 🔑 The engine's drawing is blanked with overrides: a see-through grabber as wide as the handle, so a press still maps
  to the value under the finger. Do not add your own `grabber` or `slider` overrides — put a variation in the theme.
- `GoStyle.slider()` stays a plain HSlider; reach for `GoSlider` where a screen must look like the painted game.

## 25. GoSwitch — an on/off switch with a caption

`class_name GoSwitch extends CheckButton`. The settings switch of Magnet Mayhem, drawn exactly as the game draws it:
with no `text` the pill stands centred in its box on whole pixels, and a caption ("ON" / "OFF") sits in the part of
the pill the knob is not on. Toggling, `toggled` and the touch target are the stock CheckButton's.

```gdscript
var vibration := GoSwitch.make(true)
vibration.set_texts(tr("ON"), tr("OFF"))      # both shrink together so the longer one fits
```

`make(on)` · `on_text` · `off_text` · `set_texts(on, off)` · `part(item)` · `pill_texture()` · `pill_size()` ·
`switch_rect()` · `caption()` · `caption_room()` · `caption_font_size()` · `caption_width()` · `caption_position()`.
Constants `TEXT_SIZE` (12), `KNOB_SHARE` (0.86), `TEXT_EDGE` (9), `TEXT_OUTLINE` (3).

- 🔑 The pills are the theme's CheckButton icons (`checked`, `unchecked`, their `_disabled` and `_mirrored` forms).
  The caption is white with a `TEXT_OUTLINE` rim in the CheckButton's `font_color` (the ink on arcade_light); on a
  look whose text is light, the text colour fills it and the page colour rims it.
- 🔑 With a `text` the label is the engine's and the pill stands where the engine puts the check icon (the far end).
- 🔑 Its least size is its `custom_minimum_size`: `GoTheme.TOUCH` tall from the start, and at least the pill plus
  `SIDE_ROOM` wide once the look is read. A screen that sets its own height wins.
- `GoStyle.toggle()` stays a plain CheckButton; reach for `GoSwitch` where a screen must look like the painted game.

## 26. GoMapPreview — a small map of a level

`class_name GoMapPreview extends Control`. Magnet Mayhem's MapPreview, drawn exactly as the game draws it: areas
(rectangles, circles, free polygons) filled and outlined, the links between them, white start dots, all fitted and
centred in a dark box or the theme's well. Locked, it is a grey silhouette with no starts. The game hands in data only.

```gdscript
var map := GoMapPreview.new()
map.add_rect(Vector2(0, 0), Vector2(6, 4), Color("#f2b84b"))        # centre, half size, fill
map.add_circle(Vector2(18, 0), 5.0, Color("#6fc3ff"))
map.add_link(Vector2(0, 0), Vector2(18, 0), 2.0, Color("#c9a26b"))    # centre to centre, under the areas
map.set_starts(PackedVector2Array([Vector2(-3, 0), Vector2(20, 0)]))
map.set_well()                                                        # the painted well, padding 12
map.locked = not unlocked
```

`clear()` · `add_rect(center, half, color)` · `add_circle(center, radius, color)` · `add_polygon(points, color)` ·
`add_link(from, to, width, color)` · `set_starts(points)` · `set_well()` · `locked` · `padding` · `show_background` ·
`background` · `to_canvas(point)` · `map_scale()` · `background_box()` · `area_count()` · `link_count()` ·
`start_count()` · `area_color(i)` · `link_color(i)` · `starts_shown()`. Constants `PADDING` (4), `WELL_PADDING` (12),
`EDGE` / `EDGE_WIDTH` (0.6), `DOT` / `DOT_RADIUS` (0.8), `LOCKED_AREA`, `LOCKED_LINK`, `CIRCLE_SEGMENTS` (32).

- 🔑 World units, +X right and +Y down. The areas' bounds (not the links) are scaled to fit the box less `padding`
  and centred, so an off-centre map stays centred. Links are drawn first, so a bar from centre to centre is covered
  by the areas at its ends.
- 🔑 The background is `background` if set; else the theme's `GoWell` after `set_well()`; else the theme's
  `GoMapPreview` panel; else the game's flat box (`#18213a`, a 1 px `#58627b` rim, corner 6). `show_background =
  false` draws none, for a card that draws its own well round the thumbnail.
- 🛑 It clips to its box (`clip_contents`), as the game's MapPreview does: on a scaled canvas the background's last
  fractional row would otherwise show. It ignores the mouse.

## 27. GoHudCard — a match HUD's top-row board

`class_name GoHudCard extends PanelContainer` · input-transparent. Under `arcade_light` it draws Magnet Mayhem's HUD
cards pixel for pixel (the player card, the opponents count, the match clock, the repulse gauge).

```gdscript
var player := GoHudCard.make(GoUi.skin().widget_art(&"avatar_head"), 56.0)
player.gap = 10
player.banner_text = "PLAYER"
player.add_bar("STABILITY", Color("#ff7a3d"), Color("#ffd23f")).set_values(80, 100, false)
var foes := GoHudCard.make(GoUi.skin().widget_art(&"opponents_badge"))
foes.layout = GoHudCard.Layout.INLINE
foes.title = "OPPONENTS LEFT:"
foes.value = "7"
var clock := GoHudCard.make(GoUi.skin().widget_art(&"stopwatch"))
clock.title = "MATCH TIME"
clock.set_clock(12.0, true)        # the caller decides the warning
var repulse := GoHudCard.new()
repulse.gauge = true
repulse.title = "REPULSE"
repulse.value = "2.4s"
repulse.set_lit(false)             # dimmed, ink rim; set_lit(true) pops it
var status := GoHudCard.new()      # no board: two bars, each with its picture beside it
status.show_panel = false
for row in [[&"shield", Color("#ff8a3d"), Color("#ffc24a")], [&"bolt", Color("#1fb5f0"), Color("#6ff0ff")]]:
	var bar := status.add_bar("", row[1], row[2], GoUi.skin().widget_art(row[0]))
	bar.icon_beside = true
	bar.icon_size = 28
	bar.segments = 0
var count := GoHudCard.make(GoUi.icons().texture(GoIconSet.USERS), 28.0)
count.icon_ink = GoUi.color(GoTheme.ACCENT)  # a white icon in a token colour
count.layout = GoHudCard.Layout.INLINE
count.value = "7"
```

| Member | Default | Notes |
|---|---|---|
| `icon` · `icon_size` · `icon_snap` | `null` · `36` · `true` | The picture at the start of the row. `icon_snap` false lets it fill the row's height (centred on a half pixel when the row is odd — the game's clock and badge) |
| `icon_ink` | transparent | Tints the picture (`self_modulate`) — a white icon-set icon in a token colour, e.g. `GoUi.icons().texture(GoIconSet.USERS)` in `GoUi.color(GoTheme.ACCENT)`. Transparent: its own colours |
| `gap` | `8` | Room between the icon and what follows |
| `banner_text` · `banner_size` · `banner_padding` | `""` · `16` · `-1` | A gold banner (`GoBannerGold`) at the top of the column |
| `title` · `value` · `layout` (`STACKED`, `INLINE`) | | Stacked: the caption (label ink at 75 %) over the value, centred; inline: both in the row |
| `title_size` · `value_size` · `value_ink` | `-1` · `-1` · transparent | -1: 12 / 24 stacked, 19 / 19 inline |
| `padding` | `-1` | Clear space inside the board's rim on every side (`-1`: the theme's). The margins become padding + border width |
| `show_panel` | `true` | `false`: no board and no margins — the icon, banner, labels and bars sit bare on the scene. A `gauge` keeps its board |
| `add_bar(label, ink, ink_end, icon) -> GoBar` · `bars()` | | A `GoBar` laid out as a HUD's (14 dp, 11 dp name, no readout, 2 dp lead) |
| `set_clock(seconds, warn := false)` · `static format_clock(seconds)` · `is_warning()` · `warn_ink` | | `MM:SS`; `warn` paints it in `warn_ink` (transparent: `GoSkin.hud_alert_ink()`) |
| `gauge` · `set_lit(lit, animate := true)` · `is_lit()` | `false` | The board becomes `GoSkin.hud_gauge_box(lit)`; unlit dims to `DIM_ALPHA` 0.55; lighting pops to 1.15 and back (none under `reduce_motion`) |

- 🛑 Display only: the server's clock, the count and the ready state come from the caller — the card decides nothing.
- 🔑 Skin hooks: `hud_gauge_box(lit)` (default: the HUD board with a `danger` accent when lit; arcade_light: the
  game's repulse panel, READY_RED or ink rim) and `hud_alert_ink()` (default the `alert` token: danger, arcade_light READY_RED).
- 🔎 The game sizes its top-row panels once with the desktop padding and never shrinks them, so its touch-mode player
  card keeps the desktop height; a `GoHudCard` fits its content. Set `custom_minimum_size.y` to keep a fixed height.

## 28. GoCountdown — the match-start count

`class_name GoCountdown extends Label` · input-transparent, hidden until a step shows. Under `arcade_light` it draws
Magnet Mayhem's countdown pixel for pixel (the gold digit on the blue badge, GO! on the green one).

```gdscript
var count := GoCountdown.new()
screen.add_child(count)
count.set_anchors_preset(Control.PRESET_CENTER_TOP)
count.anchor_top = 0.24
count.anchor_bottom = 0.24
count.show_step("3")                       # the server's clock says 3
count.show_step(tr("COUNTDOWN_GO"), true)  # the last step
count.hide_step()
```

| Member | Default | Notes |
|---|---|---|
| `show_step(text, final := false, animate := true)` · `hide_step()` · `is_final()` | | Shows a step and pops it in; an empty text hides it |
| `disc_size` | `200` | The disc behind the text (a centred child drawn behind it, so it pops and fades with it) |
| `step_size` · `final_size` | `110` · `80` | The font size of a step and of the last one |
| `ink` · `outline` | transparent · `14` | Transparent: `GoSkin.countdown_ink()`. The outline is the label's outline ink; the shadow is black at 35 %, 8 dp down |
| `pop_scale` · `pop_alpha` · `pop_seconds` | `1.6` · `0.6` · `0.35` | The pop a step makes (none under `reduce_motion`) |

- 🛑 Display only: the caller (the server's clock online) picks the step and the moment — nothing here counts.
- 🔑 Skin hooks: `countdown_disc(final)` (default null: a round `accent` / `success` disc; arcade_light: the painted
  blue and green badges) and `countdown_ink()` (default `warning`; arcade_light GOLD `#ffc928`).

## 29. GoHudButton — a HUD corner button with its key

`class_name GoHudButton extends HBoxContainer` · the cap first, then the button. Under `arcade_light` it draws Magnet
Mayhem's pause corner pixel for pixel (the slate "Esc" cap and the painted round pause button).

```gdscript
var pause := GoHudButton.make(GoUi.skin().widget_art(&"pause_button"), 52.0, tr("HUD_PAUSE_KEY"))
pause.pressed.connect(open_pause_menu)   # the game decides what a press does
pause.show_hint = not touch_mode
corner.add_child(pause)
```

| Member | Default | Notes |
|---|---|---|
| `static make(picture, side := 52.0, key := "")` | | |
| `button` | | The `GoIconButton` (`art`, `keyboard_focus` off — Space still reaches the game) |
| `art` · `button_size` | `null` · `52` | The picture and its side |
| `hint_text` · `show_hint` · `hint_size` | `""` · `true` · `14` | The key on the cap (never translated; empty hides it) |
| `gap` | `8` | Room between the cap and the button |
| `signal pressed` | | The button was pressed |

- 🛑 Display only: it reports the press; it pauses nothing.
- 🔑 Skin hooks: `hud_key_hint_box()` (default `kbd_box()`; arcade_light: the game's slate `#6c7aa8` cap with an ink
  rim and a 5 dp lip) and `hud_key_hint_ink()` (default `kbd_ink()`; arcade_light white).

## 30. GoNameplate — a name plate over a character

`class_name GoNameplate extends PanelContainer` · a small rounded tag with a name that floats over a character, the
same size on screen at any distance. Under `arcade_light` it draws Magnet Mayhem's name plates pixel for pixel (gold
for the player with ink text, the character's colour with white outlined text for the others).

```gdscript
var plate := GoNameplate.make(character.shown_name(), character.color, character.is_player)
plate.base_width = 86 if character.is_player else 64
overlay.add_child(plate)
# each frame, after the camera has moved:
plate.follow(camera, character.name_anchor.global_position)
```

| Member | Default | Notes |
|---|---|---|
| `static make(name_text, color := TRANSPARENT, is_own := false)` | | |
| `text` | `""` | The name, shown as given (never translated) |
| `tint` · `own` | transparent · `false` | The plate's colour (transparent: `accent`); `own` uses `nameplate_own_fill()` |
| `base_width` · `max_width` · `plate_height` | `64` · `100` · `24` | Widens to the whole name between the two; longer names clip |
| `font_size` | `14` | |
| `place_at(point)` | | Centres the plate on a point in its parent |
| `follow(camera, world_point) -> bool` | | Centres it on the projected point; hidden (false) behind the camera or with no camera |

- 🛑 Display only: it shows the name and the place it is given.
- 🔑 Skin hooks: `nameplate_box(fill)` (a 92% fill, radius 8, 2 dp rim; arcade_light's rim is ink),
  `nameplate_own_fill()` (default `warning`; arcade_light gold), `nameplate_ink(own)` (default black / white;
  arcade_light ink / white), `nameplate_outline(own)` (0 / 3) and `nameplate_outline_ink()` (black; arcade_light ink).

## 31. GoNoticeFeed — a feed of one-line notices

`class_name GoNoticeFeed extends VBoxContainer` · a match's kill feed, pickups or joins: one-line rows with an icon,
newest at the bottom, each fading in and leaving on its own. Under `arcade_light` it draws Magnet Mayhem's elimination
feed pixel for pixel (blue-rimmed rows, the player's own gold-rimmed, a skull glyph).

```gdscript
var feed := GoNoticeFeed.new()
hud.add_child(feed)                              # top centre is usual
feed.push(tr("KO_BY") % [hitter, target])        # the server said who knocked out whom
feed.push(tr("KO_BY") % ["YOU", target], true)   # the player's own line

# A kill feed row: [killer] [picture] [victim], names in team colours, long ones shrunk to fit 320 dp.
feed.max_row_width = 320.0
feed.row_alignment = HORIZONTAL_ALIGNMENT_RIGHT
feed.push_versus(hitter, GoUi.icons().texture(GoIconSet.MAGNET_ARROW), target, false, Color.RED, Color.BLUE)
feed.push_versus("", GoUi.icons().texture(GoIconSet.FALL), target)   # fell on their own: [picture] [name]
```

| Member | Default | Notes |
|---|---|---|
| `push(text, own := false, picture := null)` | | Shows a row at the bottom; when all rows show, the oldest is reused |
| `push_versus(left, picture, right, own := false, left_color, right_color)` | | A `[left] [picture] [right]` row (killer, how, victim); empty `left` hides it; a colour with alpha 0 keeps the theme's; a wide picture keeps its shape at `icon_size` high |
| `font_size` · `max_row_width` · `fit_min_scale` | `0` · `0.0` · `-1.0` | Row text size (0: the theme's) · the widest a row may be (0: no limit) — longer rows shrink both names by one scale, icons keep their size · the floor of that shrink (negative: `GoUi.config.fit_min_scale`) |
| `row_alignment` | `HORIZONTAL_ALIGNMENT_CENTER` | Rows stand left / centred / right (`SIZE_SHRINK_BEGIN` / `CENTER` / `END`) |
| `advance(delta)` · `auto_advance` | · `true` | The clock: `_process` runs it, or turn it off and call `advance` |
| `clear()` · `count` · `rows()` | | Hide all (kept built) · how many show · the showing rows, oldest first |
| `max_items` · `seconds` · `fade_in` | `4` · `2.0` · `0.2` | Rows built up front · how long a row stays · its fade (none under `reduce_motion`) |
| `icon_name` · `icon_size` · `icon_gap` · `gap` | `&"skull"` · `22` · `8` · `6` | The icon from the icon set (empty: none) and the spacing |

- 🛑 Display only: it shows the lines it is given, in the order given — the server decides who knocked out whom.
- Rows are `PanelContainer`s on the theme's `GoNotice` / `GoNoticeGold` (own) variations when the theme has them, else
  `GoSkin.notice_box(accent, true)` with a `warning` accent on the own row. Text is shown as given (not translated).

## 32. GoTouchButton — a round thumb button (and the painted stick)

`class_name GoTouchButton extends Control` · the big thumb buttons of a mobile action game: a round picture with its
name under the icon, a cooldown ring while it recharges, a pulse when it is ready, and with `drag_aim` a button that is
also a small stick. Under `arcade_light` it and `GoJoystick` draw Magnet Mayhem's touch controls pixel for pixel
(ATTRACT with "HOLD + DRAG", REPULSE cooling, JUMP, and the painted stick).

```gdscript
var jump := GoTouchButton.make(&"btn_jump", tr("JUMP"), 86.0)
jump.pressed_down.connect(func() -> void: input.send_jump())   # the game sends the input; the server decides
var skill := GoTouchButton.make(&"btn_repulse", tr("REPULSE"), 92.0)
skill.cooling = true                    # the server said it is recharging
skill.cooldown = seconds_left / total   # the share still to run
var aim := GoTouchButton.make(&"btn_attract", tr("ATTRACT"), 120.0)
aim.drag_aim = true
aim.caption = tr("HOLD + DRAG")
aim.held_caption = tr("DRAG TO AIM")
aim.aimed.connect(func(pull: Vector2) -> void: input.aim(pull))
var drop := GoTouchButton.make(&"btn_banana", tr("USE"), 80.0)   # an item key: arcade_light paints btn_banana, btn_trap
drop.badge = "×%d" % charges_left       # the count on its rim; empty hides it
```

| Member | Default | Notes |
|---|---|---|
| `make(picture_name, label, size)` | | A button on the skin's art `picture_name`, `size` across |
| `art_name` · `art` · `diameter` | · · `92` | The picture (`GoSkin.widget_art`, or a texture; none: an `accent` disc) and its size |
| `text` · `font_size` · `min_font_size` · `label_pad` · `label_rise` | · `14` · `10` · `6` · `0.8` | The name, shrunk to fit the button, its baseline `label_rise` × radius below the centre |
| `caption` · `held_caption` · `caption_size` · `held_caption_size` · `caption_drop` | · · `11` · `12` · `28` | A hint under the button at rest / while held (`GoStyle.fit_font_size`) |
| `cooling` · `cooldown` · `pulse_scale` | `false` · `0` · `1.15` | Dims it and rings the share still to run; ready again it pulses once (not under `reduce_motion`) |
| `drag_aim` · `aim_radius` · `aim_knob_radius` | `false` · `50` · `24` | Hold and drag: a ring and knob under the thumb; `aim()` and `aimed(pull)` give the pull, 0~1 |
| `press_scale` · `press_tint` · `cooling_tint` · `hit_slop` | `0.93` · · · `8` | A held button shrinks and darkens; the press reaches `hit_slop` past the rim |
| `pressed_down` · `released(canceled)` · `cancel()` · `is_held()` | | The press, the lift, and letting go without a lift (focus lost) |
| `driven` · `drive_press(at)` · `drive_drag(at)` · `drive_release(canceled)` | `false` | The owner routes the fingers (below) |
| `hits(at)` · `button_center()` · `hit_radius()` | | For the owner's hit test: a finger within `diameter` / 2 + `hit_slop` of the centre, in canvas coordinates |
| `badge` · `badge_size` · `badge_ink` · `badge_rect()` | `""` · `16` · transparent | A count on the rim, up-right (an item key's charges left, `"×2"`): the skin's `badge_box(badge_ink)` plate (transparent: `accent`), white over the touch edge, moving with the press; no touch area of its own |

🔑 **Driven from outside.** A game that routes every finger itself — one `_input` that binds each finger to a role
(stick, a button, look) when it lands, keys fingers by the event's index as given (a browser's touch id), leaves the
events unconsumed for the rest of the game, and counts the first touch while the controls are still hidden — turns
`driven` on for each button and the stick. They then take no input (`mouse_filter` IGNORE) and show what they are told;
every point is in canvas coordinates, as the `_input` event carries it. Hiding a driven widget keeps its state.

```gdscript
func _input(event: InputEvent) -> void:            # the owner's router; nothing is consumed
	if event is InputEventScreenTouch and event.pressed and jump.hits(event.position):
		_roles[event.index] = JUMP
		jump.drive_press(event.position)            # the press look, as a press of its own
	elif event is InputEventScreenTouch and not event.pressed and _roles.get(event.index) == JUMP:
		jump.drive_release(event.canceled)
```

`drive_press()` with no point holds it at the centre; while held a second `drive_press()` does nothing.
`drive_drag(at)` moves the aim knob of a `drag_aim` button (`aimed` follows). `GoJoystick` has the same with
`drive_begin(at)` / `drive_drag(at)` / `drive_end()` (§4). Turning `driven` on or off lets go of a press in progress.

- 🛑 Display and input only: it reports presses and the aim and shows the cooldown it is given.
- Skin hooks: `draw_touch_sprite()`, `touch_shadow_ink()`, `touch_outline_ink()`, `touch_cooldown_ink()`; and for
  `GoJoystick`, `joystick_art(knob)` with `joystick_idle_alpha` / `joystick_active_alpha` — a skin with the art draws
  the painted dish and knob instead of circles (`draw_joystick_art()`).

## 33. GoSpotlight — dim round one thing and ring it

`class_name GoSpotlight extends Control` · a tutorial played through the game points at one thing — the stick, a button,
a gauge — by dimming everything round it and ringing it. The dim fades after a moment so the game stays fully visible
while the player acts; the ring stays. Unlike `GoCoachMark` (a tour with a card and Next / Skip) it has no card and no
buttons and never takes input: the game is played through it. Under `arcade_light` it draws Magnet Mayhem's training
spotlight pixel for pixel.

```gdscript
var spot := GoSpotlight.new()
hud.add_child(spot)                   # covers its parent
spot.follow(jump_button, true)        # a new lesson: dim again round the jump button
spot.light(Rect2(40, 300, 120, 120))  # or a fixed rect, in the spotlight's own coordinates
spot.clear()
```

| Member | Default | Notes |
|---|---|---|
| `light(rect, fresh)` · `follow(control, fresh)` · `clear()` | | A fixed rect (as given), or a control grown by `pad` and followed as it moves (hidden: nothing lit); `fresh` dims again |
| `pad` · `dim_seconds` · `fade_seconds` | `8` · `2` · `0.4` | The hole's margin round a followed control; how long the dim stays, then fades |
| `hole` · `dim_rects()` · `dim_alpha()` | | The lit rect; the four dims (top, bottom, left, right); the dim's strength now, 1 → 0 |
| `auto_advance` · `advance(delta)` | `true` | Runs the clock in `_process`, or drive it yourself |
| `hold_dim` | `false` | Keeps the dim at full for as long as it is on — a lesson about an area (where to look, where to drag) that stays marked until the step is done. Off again, the dim is where its clock says |

- 🛑 Display only: it lights what it is told to.
- Skin hooks: `spotlight_dim()` (the dim colour) and `spotlight_ring_box()` (the ring, drawn over the hole).

## 34. GoTaskCard — a lesson's card

`class_name GoTaskCard extends PanelContainer` · the card of a tutorial played through the game: which step this is,
the lesson's name, what to do, one chip per part that ticks off as it is done, a hint when the player is stuck and a short
footer. It has no buttons and never takes input. On a phone it folds to one `compact` row once it has been read. Under
`arcade_light` it draws Magnet Mayhem's training card (and its phone strip) pixel for pixel.

```gdscript
var card := GoTaskCard.new()
hud.add_child(card)
card.custom_minimum_size.x = 440
card.caption = tr("STEP_LABEL").format({"n": 1, "total": 12})   # "TRAINING · STEP 1/12"
card.short_caption = "1/12"
card.title = tr("TITLE_MOVE")
card.body = tr("BODY_MOVE")
card.footer = tr("FOOTER_PAUSE")
card.set_parts(["W", "A", "S", "D"])
card.mark_part(0, true)                 # the game said the part is done
card.hint = tr("HINT_RING_OUT")         # "" hides it
```

| Member | Default | Notes |
|---|---|---|
| `caption` · `title` · `body` · `hint` · `footer` | | The step line, the name (one line, shrunk to fit), what to do, a hint ("" hides it), a footer |
| `set_parts(words, done)` · `mark_part(i, done)` · `part_done(i)` · `chips()` · `chip_text(i)` | | One keycap chip per part; a done one is tinted and reads "✓ word" |
| `compact` · `short_caption` | `false` · | One row: `short_caption`, the title and the chips |
| `padding` · `row_gap` | `20` · `4` | Room inside the board's rim and between the rows |
| `title_size` · `body_size` · `hint_size` · `caption_size` · `chip_size` · `strip_size` | `22` · `15` · `14` · `12` · `16` · `13` | Font sizes; the caption and footer are the label ink at 0.75 |

- 🛑 Display only: what is done comes from the caller.
- The board is the theme's `GoHudPanel`; chips are `GoSkin.kbd_box()` / `kbd_done_box()`. Skin hooks:
  `task_title_ink()` (the title and the compact row) and `task_hint_ink()` (the hint). A chip's word falls back to
  `GoSkin.symbol_font()` under the theme's font, so the ✓ draws even when the text font lacks it (`arcade_light`:
  the leading Noto Sans CJK font — Korean, or the language `GoUi.set_locale()` put first — as the game's Nunito falls
  back to it). Pair it with `GoSpotlight`.

## 35. GoPerfReadout — a performance band

`class_name GoPerfReadout extends PanelContainer` · a small always-on band of numbers for tuning a game on a weak
phone: frames per second, the frame time and the worst frame, triangles, draw calls, nodes, RAM and VRAM. Under
`arcade_light` it draws Magnet Mayhem's perf overlay pixel for pixel.

```gdscript
var perf := GoPerfReadout.new()
overlay_layer.add_child(perf)                           # a CanvasLayer above every screen
perf.position = Vector2(14, 146) + safe_area.position    # a corner clear of the HUD
perf.tier_text = "LOW (auto)"                           # "  Q LOW (auto)" ends the last line
perf.one_line = true                                    # one slim line where room is short
```

| Member | Default | Notes |
|---|---|---|
| `sampling` · `interval` | `true` · `0.25` | Reads the engine each frame (two adds, no allocation) and writes every `interval` s, only when the text changed. Off: shows what `show_stats()` gets |
| `show_stats(stats)` · `stats()` · `advance(delta)` · `restart()` | | Keys `fps` `ms` `worst_ms` `triangles` `draws` `nodes` `ram` `vram` (bytes) · the last reading · count a frame by hand · forget the frames so far |
| `good_fps` · `warn_fps` · `fps_level(fps)` | `55` · `30` | 0 good, 1 warning, 2 bad — the ink is `GoSkin.perf_ink(level)` |
| `one_line` · `compact_pad_y` | `false` · `2` | The lines joined into one slim band |
| `tier_text` · `font_size` · `outline_size` | `""` · `14` · `2` | |
| `format_count(n)` · `format_megabytes(bytes)` | static | 84321 → "84.3k", 1234567 → "1.23M" · "512 MB" |
| `write_count` | | Label writes so far: an unchanged reading never adds one |

- Skin hooks: `perf_box()` (the band), `perf_ink(level)` and `perf_font()` (null keeps the theme's).
- Triangles and draw calls come from the RenderingServer, shadow passes included; a headless run reads 0 there.


## 36. GoSignalBars — a signal meter

`class_name GoSignalBars extends PanelContainer`. A phone's signal bars: `max_bars` bars rising left to right, the
first `bars` lit in the reading's tone and the rest dim, with an optional readout beside them — a match HUD's ping.
🛑 Display only: the caller (the server's measured round trip, say) decides the bars, the tone and the text.

```gdscript
var ping := GoSignalBars.make(4, GoSignalBars.Tone.GOOD)
ping.text_width = 56.0                                   # the bars keep still as the number changes
ping.set_reading(2, GoSignalBars.Tone.FAIR, "180 ms")   # one call, one rebuild
```

| Member | Notes |
|---|---|
| `enum Tone { GOOD, FAIR, POOR, NONE }` | GOOD lights `success_fill`, FAIR `warning_fill`, POOR `danger_fill` (the bright fills — the plain `success` / `warning` / `danger` are text colours, too deep for a bar). NONE is no reading yet: every bar dim |
| `make(p_bars := 0, p_tone := Tone.NONE)` · `set_reading(p_bars, p_tone, p_text := "")` | `set_reading` sets all three with one rebuild |
| `bars` (0) · `max_bars` (4, 1–8) | More than `max_bars` lights them all; under 0 counts as 0. `lit()` is the shown count (0 while NONE), `is_lit(i)` one bar |
| `tone` (NONE) · `tone_color()` · `dim_color()` | A dim bar is `muted_fill` at `DIM_ALPHA` (0.55) |
| `text` ("") · `text_size` (20) · `text_width` (0) · `label` | The readout; empty hides it. Over the scene it is the look's outlined HUD text (`GoOutlineLabel` — arcade_light's white text with the ink edge — else the name plate's `nameplate_ink` / `nameplate_outline`). `text_width` > 0 holds that room and shrinks a longer text (`GoStyle.fit_font_size`, never under the floor) |
| `bar_height` (24) · `scale_factor` (1) · `bar_rects()` · `meter_size()` · `meter` | The tallest bar; the shortest is 40 %, a bar 40 % of the height wide |
| `panel` (false) | On: the theme's `GoHudPanel` board behind it (a theme without one: its PanelContainer panel), the readout in the board's label ink |

- The bars are the skin's: `GoSkin.draw_signal_bars(canvas, rects, lit, ink, dim)` — plain rounded bars by default;
  the arcade looks paint each as a small key with the ink outline and gloss.
- 🛑 It ignores the mouse and never flips with the language; it follows a look change (`GoUi.watch`). A screen reader
  hears "3/4 48 ms" (`accessibility_name`).
