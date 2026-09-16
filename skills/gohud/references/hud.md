# HUD and in-game widgets

GoHudAnchor, GoBar, GoSlot, GoJoystick, GoIconButton, GoNotice, GoPromptCard, GoCoachMark.
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
9. [Composing a full HUD](#9-composing-a-full-hud)

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
| `use_safe_area` | `true` | Off only for full-bleed backgrounds |
| `active_spot()` | | The spot in effect now |

```gdscript
var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.BOTTOM_CENTER
corner.landscape_spot = GoHudAnchor.Spot.BOTTOM_RIGHT   # controls move right in landscape
hud_root.add_child(corner)
```

🛑 A floating HUD over scrolling content needs a panel behind it, or text overlaps text:
`panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))`.

🪟 **HUD faces are 80% opaque by default** (`GoTheme.HUD_ALPHA`), so the world shows through a dock or a
status bar. A HUD sits straight over the game with no scrim in front of it, so **this is the one place where
the default can be too low** — over a bright, busy or high-contrast world, raise it:
`GoUi.config.container_alpha_overrides = {GoTheme.BOX_HUD: 95}` for the project, `GoStyle.hud_panel(…, alpha)`
for one panel, or `GoStyle.floating(…, opaque = true)` where the text must never fight the background.
Quick slots and badges stay solid regardless — they are pressables and markers, not containers.
Full rules: `theming.md` §4.

## 2. GoBar

`class_name GoBar extends Control` · input-transparent.

| Member | Default | Notes |
|---|---|---|
| `label_text` | `""` | Name on the left; empty hides |
| `ink` | transparent → `accent` | Use fill tokens: `GoUi.color(GoTheme.DANGER_FILL)` (`SUCCESS_FILL`, `WARNING_FILL`, `INFO_FILL`, `ACCENT_FILL`) |
| `enum Readout { NONE, VALUE, FRACTION, PERCENT }` · `readout` | `FRACTION` | `320` · `320 / 500` · `64%` (formats are translatable) |
| `thickness` | `8` | dp |
| `ease_seconds` | `0.18` | 0 = instant; `reduce_motion` also makes it instant |
| `set_values(value, maximum, animate := true)` · `set_ratio(ratio, animate := true)` · `value()` · `maximum()` | | Pass `animate = false` for the first fill |
| `static format_amount(amount) -> String` · `static abbreviate(amount)` | | `12.3k`, `4.5m`, or `GoConfig.number_formatter` |

Give it a width: `bar.custom_minimum_size.x = 180` (or put it in an expanding container).

## 3. GoSlot

`class_name GoSlot extends Button` · Tab order off by default · uses `pressed` like any Button.

| Member | Default | Notes |
|---|---|---|
| `icon_name` | `&""` | `GoIconSet.POTION` etc. |
| `accent` | transparent → `accent` | Border / glow colour |
| `quantity` | `GoSlot.UNKNOWN` (-1) | `-1` shows `…`, `GoSlot.NONE` (-2) hides the badge (skills), `0` fades the slot |
| `timer_text` | `""` | Text badge over the icon (buff time) |
| `shortcut_label` | `""` | Top-left key hint — display only, handle input yourself |
| `visual_size` | `44` | Face size; touch area stays ≥ `min_touch_size` |
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
| `tooltip_text_name` | `&""` | Passed through `GoUi.text()` — a built-in name (`close`, `back`…) is translated, anything else is shown as written. Also sets `accessibility_name` |
| `touch_peers` | `[]` | Required when icon buttons sit side by side |

🛑 The widened touch area covers neighbours. Only put it next to non-interactive siblings, or set `touch_peers`.

## 6. GoNotice

`class_name GoNotice extends PanelContainer` · ignores mouse and focus recursively — presses go through it.

| Member | Notes |
|---|---|
| `show_text(message, tone := GoTheme.TEXT, seconds := -1.0)` | `tone` is a colour token name (`GoTheme.SUCCESS`, `DANGER`…); -1 → `notice_duration_ms` token |
| `show_key(key, arguments := {}, tone := GoTheme.TEXT, seconds := -1.0)` | Re-translates on locale change |
| `set_message(message, tone)` | Shows without a timer |
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

## 9. Composing a full HUD

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
dropped) · `height_ratio` 0.55 · `executed(command, args, result)` signal.

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

`seconds_per_turn` 1.1 · `thickness` (−1 = diameter/9) · `ink` (empty = accent) · `show_track`.

- **`busy()` keeps the button's size** — the label is made transparent rather than removed, so the row does
  not jump. It also sets `disabled`, which is the point: a purchase must not fire twice while you `await`.
  `is_busy(button)` asks. Calling it twice adds one spinner, not two, and turning it off restores the exact
  theme overrides it found.
- ♿ With `reduce_motion` on it does not spin — three dots pulse instead. It also stops while hidden.
- 🔑 Progress you can measure is a `GoBar`. A spinner promises nothing about when it ends.

## 12. GoBadge — counts and dots

```gdscript
GoBadge.attach(mail_button, unread_count)      # hides itself at 0
GoBadge.attach(shop_button, 0, "NEW")          # a word instead of a number
GoBadge.attach(friend_button, 3, "", true)     # a dot — "something is there"
row.add_child(GoBadge.make(12))                # standalone, inside a row
GoBadge.detach(mail_button)
```

`cap` 99 (`99+` beyond it) · `label_text` · `dot` · `ink` (empty = danger) · `hide_when_zero`.

- `attach()` pins it to the **top-right corner of the host**, half outside, with anchors — so it follows a
  host whose size is decided later. Attaching twice returns the same badge.
- 🔑 A number when the count changes what the player does; a dot when only "there is something" matters.
- ♿ The badge carries an `accessibility_name`, and its text colour is picked for contrast against whatever
  colour the skin painted the badge — never assumed white.

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

`columns` 7 · `cell_size` (−1 = touch × 1.4) · `today()` returns the claimable index, `-1` when done.

- 🛑 **Only today's cell is pressable.** Claimed and future cells are disabled — a button that does nothing
  when pressed reads as broken.
- ♿ Claimed / today / future differ by **three things**: a tick glyph, an accent border, and dimming — and
  the state is in the accessible name. Dimming alone cannot separate "claimed" from "not yet".

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

- 🛑 **It does not advance on its own unless you ask**, and 5 s is the floor — a banner that changes every
  3 s takes the text away before it is read. Touching it resets the timer.
- ♿ With `reduce_motion` on, autoplay is off entirely; the dots still work, so nothing is lost.
- The dots are pressable at the touch minimum even though the drawn dot is small.
