# Platform — icons, languages, sound & haptics, accessibility, screens, Back

Source: `core/go_icon_set.gd`, `core/go_game_icons.gd`, `core/go_icon_library.gd`, `core/go_ui.gd`, `core/go_feedback.gd`, `core/go_safe_area.gd`,
`core/go_scale.gd`, `core/go_back_policy.gd`, `core/go_runtime.gd`, `i18n/gohud.csv`.

## Contents

1. [Icons](#1-icons)
2. [Localization and RTL](#2-localization-and-rtl)
3. [Sound and haptics](#3-sound-and-haptics)
4. [Accessibility and input](#4-accessibility-and-input)
5. [Safe area, keyboard, breakpoints, dp scale](#5-safe-area-keyboard-breakpoints-dp-scale)
6. [Back button and modality](#6-back-button-and-modality)

## 1. Icons

Widgets ask for icons **by name**; `GoUi.icons()` (a `GoIconSet`) decides what draws. Any name works if the set
defines it — the constants just prevent typos.

The 84 constants on `GoIconSet` (value = lowercase name):

| Group | Names |
|---|---|
| Navigation | `CLOSE` `BACK` `FORWARD` `UP` `DOWN` `CHEVRON_LEFT` `CHEVRON_RIGHT` `CHEVRON_UP` `CHEVRON_DOWN` `MENU` `MORE` `EXTERNAL` `EXPAND` `COLLAPSE` |
| Status | `CHECK` `INFO` `WARNING` `ERROR` `SUCCESS` `HELP` `BELL` `CLOCK` `HOURGLASS` |
| People | `USER` `USERS` `USER_PLUS` `CHAT` `HEART` `STAR` `CROWN` |
| Settings | `SETTINGS` `SLIDERS` `DISPLAY` `MOBILE` `VOLUME_HIGH` `VOLUME_LOW` `VOLUME_OFF` `EYE` `EYE_OFF` `SUN` `MOON` `GLOBE` |
| Actions | `PLUS` `MINUS` `TRASH` `EDIT` `SAVE` `REFRESH` `SEARCH` `FILTER` `SORT` `COPY` `DOWNLOAD` `UPLOAD` `PLAY` `PAUSE` `STOP` `POWER` `LOGOUT` `LOGIN` |
| Security | `LOCK` `UNLOCK` `SHIELD` `SHIELD_CHECK` `KEY` |
| Places & items | `HOME` `MAP` `LOCATION` `BAG` `BOX` `COIN` `GIFT` `BOOK` |
| Layout | `LIST` `GRID` `COLUMNS` `CHART` |
| Game | `SWORD` `BOLT` `TARGET` `FLAG` `POTION` `SKULL` `RUN` |

**Three sets, one lookup.** The default set (84, always on) · the **game set** (187, `GoGameIcons`) · the **icon
library** (1,000, `GoIconLibrary`, 32 groups). The two big ones are **not** on by default — add them with
`GoUi.add_icons()`: that lists them in `GoConfig.extra_icons`, which `use_preset()` keeps, so a preset's own drawings
(the medieval engravings) stay on top and the added set only fills in names the preset lacks. The library falls back
to the game set and that one to the default set — adding the library makes **1,271 names** drawable.

```gdscript
GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)
GoUi.add_icons(GoIconLibrary.icon_set())            # + the game set under it; survives later use_preset() calls
slot.icon_name = GoGameIcons.BACKPACK
GoStyle.list_button(GoIconLibrary.CLOUD_RAIN, "Weather", open_weather)
for icon in GoUi.icons().names_in_group(&"shop"): row.add_child(GoUi.icons().node(StringName(icon), 24))
```

🔑 The old way still works — `GoUi.config.icons = GoGameIcons.icon_set()` **after** `use_preset()` — but it replaces
the preset's set (the medieval engravings are lost). Prefer `add_icons()`.
🛑 **Finding a library name:** grep `core/go_icon_library.gd` (one constant per icon, grouped under comments) or call
`GoIconLibrary.icon_set().search("arrow left")`. Library names are Tabler's names with `_` for `-` (`cloud-rain` →
`cloud_rain`); Tabler names of drawings gohud already had are aliases (`x` → `close`, `map_pin` → `location`).

| Group key | Names (`GoGameIcons.<UPPER_CASE>`) |
|---|---|
| `inventory` — Inventory & storage | `backpack` `chest` `crate` `crates` `barrel` `bucket` `stack` `cube` `warehouse` `hand_grab` |
| `shop` — Shop & trade | `shop` `cart` `cart_add` `shopping_bag` `basket` `tag` `tags` `receipt` `wallet` `cash` `banknote` `coins` `money_bag` `piggy_bank` `gem` `scale` `discount` `percent` `credit_card` `exchange` `delivery` `trolley` `bank` `auction` `gift_card` `ticket` `price_up` `price_down` `credit` |
| `equipment` — Equipment & tools | `helmet` `armor` `boots` `glasses` `mask` `wardrobe` `gloves` `ring` `necklace` `space_helmet` `swords` `axe` `bow` `wand` `hammer` `pickaxe` `shovel` `wrench` `tools` `knife` `fish_hook` `brush` `binoculars` `compass` `magnet` `bomb` |
| `food` — Food & consumables | `apple` `meat` `bread` `bottle` `flask` `flask_round` `pill` `medkit` `bandage` `syringe` `candy` `milk` `egg` `fish` `carrot` `mushroom` `cookie` `cheese` `cake` `pizza` `soup` `salad` `ice_cream` `coffee` `cup` `drink` |
| `resources` — Resources & materials | `wood` `leaf` `seedling` `plant` `flower` `wheat` `seeds` `cactus` `tree` `droplet` `flame` `snowflake` `wind` `bone` `feather` `mountain` `bricks` `ore` `crystal` `ingot` `goo` `shell` `spore` `steel_beam` `floor_panel` |
| `tech` — Tech & space | `atom` `battery` `battery_full` `bulb` `chip` `plug` `engine` `rocket` `planet` `satellite` `ufo` `alien` `solar_panel` `antenna` `telescope` `meteor` `robot` `drone` `radar` `microscope` `dna` `test_tube` `radioactive` `biohazard` `recycle` `fuel` `oxygen_tank` `dome` `power_core` |
| `places` — Buildings & furniture | `factory` `house` `tower` `windmill` `tent` `campfire` `bed` `lamp` `door` `window` `fence` `ladder` `armchair` `car` `tractor` `forklift` `crane` |
| `creatures` — Creatures | `paw` `bug` `ghost` `pig` `horse` |
| `rewards` — Rewards & social | `trophy` `medal` `award` `certificate` `sparkles` `confetti` `balloon` `dice` `puzzle` `anchor` `palette` `notebook` `scroll` `thumb_up` `handshake` `megaphone` `stopwatch` `microphone` `microphone_off` `send` |

171 of them use path data from **Tabler Icons** (MIT, Copyright (c) 2020-2026 Paweł Kuna); 16 were drawn for gohud. The
MIT notice travels in `THIRD_PARTY_NOTICES.md`. Add or change icons in the table of `tools/make_game_icons.py` and
run it — it rewrites `icons/game/*.svg`, `icons/gohud_icons_game.tres` and `core/go_game_icons.gd` (`--check` compares).

**The icon library** — 1,000 Tabler Icons 3.46.0 drawings (MIT), same 24 px grid and 2 px stroke:

| Group key — title | Icons | Typical names (`GoIconLibrary.<UPPER_CASE>`) |
|---|---|---|
| `arrows` — Arrows & directions | 50 | `arrow_big_up` `arrow_narrow_left` `caret_down` `chevrons_right` `rotate` `switch_horizontal` |
| `system` — System & status | 173 | `calendar` `dashboard` `fingerprint` `history` `loader` `toggle_left` `user_check` `zzz` |
| `devices` — Devices & signal | 72 | `device_gamepad` `wifi_off` `battery_charging` `bluetooth` `keyboard` `phone_call` |
| `media` — Media & playback | 37 | `camera` `music` `player_skip_forward` `repeat` `video_off` `volume_2` |
| `communication` — Messages & mail | 20 | `mail` `mail_opened` `message_circle` `messages` `rss` `message_plus` |
| `documents` — Documents & files | 38 | `bookmark` `clipboard_list` `file_text` `folder_open` `notes` `paperclip` |
| `commerce` — Commerce & clothing | 23 | `cash_register` `credit_card_pay` `jacket` `tie` `transfer_in` `truck_loading` |
| `currency` — Currencies | 12 | `currency_won` `currency_ruble` `currency_lira` `currency_real` `currency_baht` `currency_cent` |
| `map` — Map & places | 62 | `gps` `route` `road_sign` `traffic_cone` `zoom_in` `world_latitude` |
| `buildings` — Buildings | 39 | `building_castle` `building_hospital` `building_lighthouse` `smart_home` `bath` `car_garage` |
| `vehicles` — Vehicles | 46 | `plane` `ship` `train` `truck` `helicopter` `submarine` |
| `weather` — Weather & sky | 26 | `cloud_rain` `cloud_storm` `sunrise` `temperature` `tornado` `rainbow` |
| `nature` — Nature | 16 | `acorn` `butterfly` `cherry` `clover` `snowman` `iceberg` |
| `animals` — Animals | 8 | `cat` `dog` `dragon` `deer` `spider` `bat` |
| `food` — Food & drink | 38 | `burger` `beer` `banana` `mug` `teapot` `chef_hat` |
| `health` — Health & body | 40 | `heart_broken` `pills` `stethoscope` `thermometer` `brain` `lungs` |
| `sport` — Sport | 44 | `ball_football` `chess_knight` `golf` `swimming` `yoga` `scoreboard` |
| `games` — Games & luck | 18 | `dice_6` `joker` `poker_chip` `play_card` `roulette` `sword_off` |
| `mood` — Faces & moods | 23 | `mood_happy` `mood_sad` `mood_angry` `mood_wink` `mood_cry` `mood_nerd` |
| `gestures` — Hands & gestures | 11 | `hand_click` `hand_stop` `hand_move` `hand_love_you` `hand_two_fingers` `hand_off` |
| `shapes` — Shapes & marks | 38 | `circle` `hexagon` `square_check` `triangle` `clubs` `spade` |
| `symbols` — Symbols & ratings | 22 | `copyright` `yin_yang` `peace` `rating_18_plus` `trademark` `ankh` |
| `badges` — Badges | 5 | `badge` `badges` `badge_4k` `badge_ad` `badge_cc` |
| `zodiac` — Zodiac | 12 | `zodiac_leo` `zodiac_aries` `zodiac_virgo` `zodiac_pisces` `zodiac_scorpio` `zodiac_libra` |
| `charts` — Charts | 11 | `chart_pie` `chart_line` `chart_donut` `chart_radar` `chart_area` `chart_candle` |
| `math` — Math | 22 | `infinity` `divide` `equal` `sum` `multiplier_2x` `abacus` |
| `data` — Data & tables | 6 | `database` `table` `table_export` `table_import` `relation_one_to_one` `row_insert_top` |
| `computers` — Computers & networks | 4 | `binary` `binary_tree` `network` `topology_star` |
| `development` — Development | 14 | `api` `apps` `sitemap` `prompt` `auth_2fa` `versions` |
| `design` — Design & editing | 48 | `color_picker` `crop` `layers_union` `pencil` `ruler` `scissors` |
| `photography` — Photography | 16 | `aperture` `brightness` `exposure` `focus` `polaroid` `screenshot` |
| `electrical` — Electrical | 6 | `circuit_bulb` `circuit_cell` `circuit_motor` `circuit_diode` `circuit_ground` `circuit_ammeter` |

The table is `tools/icon_library_data.py`; `python3 tools/make_icon_library.py` rebuilds `icons/library/`, the set and
`core/go_icon_library.gd` (`--check` compares, `--import <tabler package>` refreshes drawings and search words).
The whole catalog, searchable, is on the website's Icons page (`www/icons.html`).

The medieval set (`res://addons/gohud/icons/gohud_icons_medieval.tres`) redraws `bag book box coin crown flag heart
key map potion shield star sword user` and adds `&"scroll"` and `&"seal"`; every other name falls back to default.

| API | Notes |
|---|---|
| `node(icon, size: int, ink := Color.TRANSPARENT) -> Control` | `TextureRect` (texture) or `Label` (font glyph), exact square min size. Unknown name → empty box + debug warning |
| `texture(icon) -> Texture2D` · `glyph(icon) -> String` · `glyph_font(icon)` · `has_icon(icon)` · `icon_names()` | `has_icon`/`icon_names` load nothing |
| `search(words, limit := 0) -> PackedStringArray` | best first — whole name, then a name an alias of which is the query, then name words, aliases, `tags` |
| `group_names()` · `names_in_group(key)` · `group_title(key)` · `group_of(icon)` | group keys are shared: `names_in_group(&"food")` gathers every set's food |
| `canonical(icon) -> StringName` | the name that draws it (`gear` → `settings`), `&""` if none |
| `GoIconSet.from_folder(dir, below := null)` | a set of the pictures in a folder, file name = icon name, loaded when first drawn |
| drawing fields | `textures: Dictionary[StringName, Texture2D]` · `paths: Dictionary[StringName, String]` (+ `folder`) · `font` + `codepoints` · `font_size_ratio` · `fallback` · `layers: Array[GoIconSet]` · `tint` |
| finding fields | `aliases: Dictionary[StringName, StringName]` · `groups` · `group_titles` · `tags` — data only, they draw nothing |
| lookup order | **every set's own drawings first** (this set, its `layers`, then their `fallback`s level by level; own = `textures` → `paths` → `codepoints`), then one alias hop, then an empty box |
| `GoUi.icons()` | `config.icons` → preset's set → `DEFAULT_ICONS`, with `config.extra_icons` layered under it (cached; the same object while nothing changes) |
| on buttons | `GoStyle.apply_icon(button, GoIconSet.SAVE)` · `GoStyle.icon_button(...)` |

🛑 `paths` are strings, not dependencies: an export that **picks resources** must include `addons/gohud/icons/`
(the default "export all resources" needs nothing). A path that fails to load warns once in debug builds.

```gdscript
# Your own SVGs over the defaults (draw them white; import as DPITexture so they stay sharp)
var mine := GoIconSet.new()
mine.set_name = "Studio icons"
mine.fallback = GoUi.DEFAULT_ICONS
mine.textures = {GoIconSet.CLOSE: preload("res://ui/icons/close.svg"), &"quest": preload("res://ui/icons/quest.svg")}
GoUi.config.icons = mine

# A folder of your drawings — file name = icon name
GoUi.config.icons = GoIconSet.from_folder("res://ui/icons", GoUi.icons())

# An icon font (keep commercial fonts in your project, not in a gohud fork)
var font_set := GoIconSet.new()
font_set.font = preload("res://ui/fonts/fa-solid-900.otf")
font_set.codepoints = {GoIconSet.CLOSE: 0xf00d, GoIconSet.SETTINGS: 0xf013}
font_set.font_size_ratio = 0.9
font_set.fallback = GoUi.DEFAULT_ICONS
GoUi.config.icons = font_set
```

## 2. Localization and RTL

Widgets never hard-code display text. Text you pass (titles, labels, rows) is yours: literal with `label()` /
`button()`, a translation key with `label_key()` / `button_key()` / `*_key()` methods. gohud's own 16 strings:

| Name | English | Kind |
|---|---|---|
| `close` `back` `next` `done` `skip` `confirm` `cancel` `search` `loading` `empty` `retry` | Close, Back, … | words |
| `bar_fraction` · `bar_percent` · `coach_progress` · `slot_quantity` · `slot_unknown` | `{value} / {max}` · `{percent}%` · `{step} / {total}` · `×{count}` · `…` | formats (`{name}` placeholders) |

```gdscript
GoUi.config.text_overrides = {&"confirm": "Yes", &"cancel": "No"}   # literal, no translation table
GoUi.config.text_keys[&"confirm"] = "MY_DIALOG_YES"                  # or point at your own keys
GoUi.config.number_formatter = func(amount: float) -> String:        # CJK grouping: 만 / 억
	if absf(amount) >= 100_000_000.0: return "%.1f억" % (amount / 100_000_000.0)
	if absf(amount) >= 10_000.0: return "%.1f만" % (amount / 10_000.0)
	return str(roundi(amount))
TranslationServer.set_locale("ko")                                  # widgets re-translate themselves
```

- `GoUi.text(name)` returns translated text (override → `text_keys` key → **the name itself through the translation server**, so a tooltip can take your own key without registering it); `GoUi.text_key(name)` returns the key.
- Built-in translations (21 locales: en ko ja zh zh_TW es pt de fr it nl pl ru uk tr vi id th hi ar he) load
  automatically once the CSV is imported; turn off with `load_builtin_translations = false` if your keys collide.
- 🛑 Placeholders are filled only via `args` (`GoDialogs`, `GoNotice.show_key`, `GoPromptCard.set_title_key`);
  `tr()` alone leaves `{name}` visible.
- RTL (`ar`, `he`): give your root Control `layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE`.
  Numbers, joysticks, scroll rails, the safe area and HUD anchors stay physically left-to-right on purpose.
- 🛑 Fonts: only Cinzel (Latin, medieval headings) ships. CJK, Thai, Arabic, Hebrew, Devanagari need a font with
  those glyphs in your Theme — missing glyphs draw as empty boxes without any error.

## 3. Sound and haptics

gohud ships no audio. `GoFeedback` pairs a sound cue with a vibration (Android/iOS only).

| Call | Cue (`GoConfig.sound_cues`) | Vibration |
|---|---|---|
| `GoFeedback.opened()` | `ui_open` | light |
| `closed()` · `tapped()` · `canceled()` · `toggled()` | `ui_close` · `ui_click` · `ui_cancel` · `ui_click` | tap |
| `confirmed()` · `fanfare()` | `ui_confirm` · `ui_fanfare` | light |
| `failed()` | `ui_error` | medium |
| `play(&"opened")` | by name (`OPENED` `CLOSED` `TAPPED` `CONFIRMED` `CANCELED` `FAILED` `FANFARE`) | |

```gdscript
GoFeedback.sound_handler = func(cue: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://audio/ui/%s.ogg" % cue)
	player.finished.connect(player.queue_free)
	get_tree().root.add_child(player)
	player.play()
GoFeedback.haptic_handler = func(ms: int, amplitude: float) -> void: pass   # optional replacement
```

`GoDialogs` and `GoSheet` call `opened/confirmed/canceled/closed` themselves; call `GoFeedback.tapped()` in your
own button handlers for a consistent feel.

## 4. Accessibility and input

- `min_touch_size` (48 dp) is an input floor, not a visual size: icon buttons and slots look smaller but hit 48 dp.
  Side-by-side icon buttons/slots need `touch_peers` so the nearer centre wins.
- Icon-only buttons: pass a tooltip (`GoStyle.icon_button(icon, action, -1, &"Inventory")`) — it becomes
  `accessibility_name` for screen readers.
- Focus rings show for keyboard/gamepad users only (`suppress_pointer_focus_ring`). Surfaces trap focus while
  open and restore it on close; set `surface.initial_focus` for controller-first screens.
- Quick slots skip Tab by default; `slot.keyboard_focus = true` when a gamepad is the only input.
- `reduce_motion` stops fades, bar easing and coach-mark pulses; `autowrap_text` keeps long strings on screen.
- Irreversible actions: `GoStyle.Tone.DANGER_SOLID` / `dialogs.confirm(..., destructive = true)`.
- Gamepad/keyboard: `ui_cancel` closes the topmost surface, finishes a coach tour.

## 5. Safe area, keyboard, breakpoints, dp scale

| API | Notes |
|---|---|
| `GoSafeArea.usable_rect(window) -> Rect2` | Excludes notch/gesture bar on Android/iOS; full rect on desktop or when `respect_safe_area` is off |
| `GoSafeArea.usable_rect_with_keyboard(window, keyboard_px)` | Also removes the virtual keyboard |
| `GoSafeArea.new()` (a Control) | Positions itself over the safe area — a parent for content that must avoid the notch |
| `enum GoScale.Bp { MOBILE, TABLET, DESKTOP }` | Short side in dp: ≤ `mobile_max_dp` (576) mobile, ≤ `tablet_max_dp` (991) tablet |
| `GoScale.breakpoint_for_dp(dp)` · `form_width_for(bp)` · `gain_for(bp, handheld, portrait)` · `display_scale(raw_scale, dpi, screen_px)` · `breakpoint_name(bp)` | Pure functions |
| `GoRuntime` (plugin autoload) | `breakpoint_changed(bp)` · `viewport_resized(size)` · `keyboard_changed(px)` · `current_bp()` · `is_mobile()` · `short_dp()` |
| `GoUi.is_handheld_platform()` | Android or iOS (not "narrow window") |

`scale_enabled = true` makes 1 UI unit = 1 dp by setting `Window.content_scale_factor` — it changes the whole
project's 2D coordinates, so only turn it on in a project designed for it.

```gdscript
var runtime := GoUi.runtime()
# 🛑 `GoUi.runtime()` is typed `Node`, so `runtime.breakpoint_changed` does not parse — connect by name.
if runtime:
	runtime.connect(&"breakpoint_changed", func(bp: GoScale.Bp) -> void: rebuild_for(bp))
```

## 6. Back button and modality

- `GoBackPolicy.acquire(tree)` / `release(tree)` / `owners()` — counts screens that own Android Back so
  `SceneTree.quit_on_go_back` is restored only when the last one closes. `GoSurface`, `GoForm` (with a
  `%BackButton`) and `GoCoachMark` already use it. Every `acquire` needs a `release`, including in `_exit_tree`.
- Your own screen handling Back:

```gdscript
func _enter_tree() -> void: GoBackPolicy.acquire(get_tree())
func _exit_tree() -> void: GoBackPolicy.release(get_tree())
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not GoSurface.is_any_open():
		go_back()
```

- Pause gameplay input while a window is up: `if GoSurface.is_any_open(): return` in `_unhandled_input`.

## 7. GoKbd — key hints that do not lie

```gdscript
row.add_child(GoKbd.make("F"))
row.add_child(GoKbd.make("Ctrl", "S"))
hint.add_child(GoKbd.for_action(&"interact"))     # reads the real binding
```

`hide_on_handheld` (default on) · `set_keys(array)` `keys()` · `GoKbd.action_keys(action)`.

- 🔑 **`for_action()` reads `InputMap`.** A hard-coded "Press F" keeps saying F after the player rebinds —
  the most common lie in a PC UI. If the action does not exist or is bound to a pad, it returns **empty** and
  the widget hides; "None" would be its own lie.
- Phones have no keyboard, so it hides itself on Android and iOS — no `if OS.has_feature(...)` per screen.
- 🛑 Key names are never translated and never wrap: `Ctrl` is what is printed on the key, and breaking it
  across two lines makes it unfindable. Caps stay in physical order in RTL too.

## 8. Accessibility — what gohud does for you, and what it cannot

| Done for you | Where |
|---|---|
| 48 dp touch behind smaller visuals, nearest-centre resolution | `min_touch_size`, `touch_peers` |
| Focus rings only for keyboard/gamepad, focus trapped and restored | `suppress_pointer_focus_ring`, `GoSurface` |
| `accessibility_name` on icon buttons, badges, bars, slots, tables, charts, code fields | the widgets |
| State told by **shape or text**, not only colour — tick glyphs, dashed comparison lines, ▲▼ sort marks, error text | the widgets |
| `reduce_motion` honoured: no spin, no autoplay, no slide | `GoConfig.reduce_motion` |
| One place to join spoken phrases | `GoUi.spoken([label, error])` |

What it **cannot** do for you: name your own controls, decide which colour means what in your game, or
write the error text. Anything you build with `GoStyle` factories needs its own `accessibility_name` when
the visible label is not enough.

```gdscript
node.accessibility_name = GoUi.spoken([field_label.text, error_label.text])
```

🛑 Do not build `"%s %s"` yourself in each widget — that both scatters the joining rule and leaks past the
check that keeps display strings out of the add-on's code.
