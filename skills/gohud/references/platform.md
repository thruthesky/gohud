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
| drawing fields | `textures: Dictionary[StringName, Texture2D]` · `paths: Dictionary[StringName, String]` (+ `folder`) · `font` + `codepoints` · `font_size_ratio` · `fallback` · `layers` (any array of sets — a plain `Array`, see below) · `tint` |
| finding fields | `aliases: Dictionary[StringName, StringName]` · `groups` · `group_titles` · `tags` — data only, they draw nothing |
| lookup order | **every set's own drawings first** (this set, its `layers`, then their `fallback`s level by level; own = `textures` → `paths` → `codepoints`), then one alias hop, then an empty box |
| `GoUi.icons()` | `config.icons` → preset's set → `DEFAULT_ICONS`, with `config.extra_icons` layered under it (cached; the same object while nothing changes) |
| on buttons | `GoStyle.apply_icon(button, GoIconSet.SAVE)` · `GoStyle.icon_button(...)` |

🛑 `paths` are strings, not dependencies: an export that **picks resources** must include `addons/gohud/icons/`
(the default "export all resources" needs nothing). A path that fails to load warns once in debug builds.

🛑 `layers` is a plain `Array` on purpose — its inspector hint still offers only icon sets, any array of sets can be
assigned, and an entry that is not a set is skipped. A list assigned as `[a, b]` stays a plain array — read it into an
`Array[GoIconSet]` variable with `.assign()`. Your own resources have the same trap: an **exported** `Array[X]` or
`Dictionary[K, X]` declared inside `X` itself keeps `X`'s script alive at exit in the editor build, so every
`godot --headless` run ends with `ERROR: 1 resources still in use at exit` (Godot 4.7.2). Type it through the hint:
`@export_custom(PROPERTY_HINT_TYPE_STRING, "%d/%d:X" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE]) var items: Array = []`.

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
`button()`, a translation key with `label_key()` / `button_key()` / `*_key()` methods. gohud's own 46 strings
(`GoConfig.text_keys`, translated in `i18n/gohud.csv`):

| Name | English | Kind |
|---|---|---|
| `close` `back` `next` `done` `skip` `confirm` `cancel` `search` `loading` `empty` `retry` `menu` `more` `clear` `reorder` | Close, Back, … | words (tooltips and spoken names too) |
| `bar_fraction` · `bar_percent` · `coach_progress` · `slot_quantity` · `slot_unknown` | `{value} / {max}` · `{percent}%` · `{step} / {total}` · `×{count}` · `…` | formats (`{name}` placeholders) |
| `previous_month` `next_month` · `date_month_year` · `month_1`…`month_12` · `weekday_0`…`weekday_6` | Previous month · `{month} {year}` · January… · S, M, T… (the calendar's column heads) | `GoDatePicker` |
| `am` `pm` `hour` `minute` | AM, PM, Hour, Minute | `GoTimePicker` |

```gdscript
GoUi.config.text_overrides = {&"confirm": "Yes", &"cancel": "No"}   # literal, no translation table
GoUi.config.text_keys[&"confirm"] = "MY_DIALOG_YES"                  # or point at your own keys
GoUi.config.number_formatter = func(amount: float) -> String:        # CJK grouping: 만 / 억
	if absf(amount) >= 100_000_000.0: return "%.1f억" % (amount / 100_000_000.0)
	if absf(amount) >= 10_000.0: return "%.1f만" % (amount / 10_000.0)
	return str(roundi(amount))
TranslationServer.set_locale("ko")                                  # widgets re-translate themselves
GoUi.set_locale("ja")              # the same, after putting the look's Japanese font first (arcade_light's CJK fallbacks)
```

- `GoUi.text(name)` returns translated text (override → `text_keys` key → **the name itself through the translation server**, so a tooltip can take your own key without registering it); `GoUi.text_key(name)` returns the key.
- Built-in translations (21 locales: en ko ja zh zh_TW es pt de fr it nl pl ru uk tr vi id th hi ar he) load
  automatically once the CSV is imported; turn off with `load_builtin_translations = false` if your keys collide.
- 🛑 Placeholders are filled only via `args` (`GoDialogs`, `GoNotice.show_key`, `GoPromptCard.set_title_key`);
  `tr()` alone leaves `{name}` visible.
- RTL (`ar`, `he`): give your root Control `layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE`.
  Numbers, joysticks, scroll rails, the safe area and HUD anchors stay physically left-to-right on purpose.
- 🛑 Fonts: two ship — Cinzel (Latin, medieval headings) and Roboto (the Material presets' text, used only when the
  project sets no font of its own). CJK, Thai, Arabic, Hebrew, Devanagari need a font with those glyphs in your
  Theme — missing glyphs draw as empty boxes without any error.
- 🔤 **The current language's CJK font first.** Chinese, Japanese and Korean share Han characters but draw them
  differently, so the reader's own font must lead the fallbacks. `GoUi.set_locale(code)` reorders the look's body-font
  fallbacks (`set_font_locale(code)` → `true` when the order changed; it reassigns only then, because a reassignment
  re-shapes all text), then calls `TranslationServer.set_locale(code)` if the locale differs — call it instead of the
  bare `TranslationServer.set_locale`. The table is the theme's `go_locale_fonts` metadata (`GoUi.LOCALE_FONTS_META`,
  `{"ko": Font, "ja": Font, "zh_CN": Font, "zh_TW": Font}`); `arcade_light` carries Magnet Mayhem's Noto Sans KR / JP / SC /
  TC. A code matches exactly, then by language (`ko_KR` → `ko`); Chinese by script or region (`Hans` → `zh_CN`;
  `Hant`, `TW`, `HK`, `MO` → `zh_TW`); any other language keeps the written order (KR, JP, SC, TC).
  `GoUi.use_preset()` applies the current locale. With the `GoRuntime` autoload a bare `TranslationServer.set_locale()`
  is followed too (it reorders on `NOTIFICATION_TRANSLATION_CHANGED`, one frame of text in the old order); without it,
  only `GoUi.set_locale()` reorders.

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
  open and restore it on close; set `surface.initial_focus` for controller-first screens. With nothing focusable
  inside (arcade_light: `FOCUS_NONE` controls, the close button too) the screen behind drops focus instead.
- Quick slots skip Tab by default; `slot.keyboard_focus = true` when a gamepad is the only input.
- `reduce_motion` stops fades, bar easing and coach-mark pulses; `autowrap_text` keeps long strings on screen.
- Irreversible actions: `GoStyle.Tone.DANGER_SOLID` / `dialogs.confirm(..., destructive = true)`.
- Gamepad/keyboard: `ui_cancel` closes the topmost surface, finishes a coach tour.

## 5. Safe area, keyboard, breakpoints, dp scale

| API | Notes |
|---|---|
| `GoSafeArea.usable_rect(view: Viewport) -> Rect2` | Pass `get_viewport()`. Excludes notch/gesture bar on Android/iOS; full rect on desktop, when `respect_safe_area` is off, or for a `SubViewport` (its own rect — a window inside a preview or render-to-texture fits that viewport, not the main window). The OS reports the safe area in screen pixels; it comes into UI units through the window's final transform, so it holds under any stretch (the project's own `canvas_items` base, `GoScale`, letterboxing) |
| `GoSafeArea.usable_rect_with_keyboard(window, keyboard_px)` | Also removes the virtual keyboard |
| `GoSafeArea.clip_to_safe(area, safe_px, to_screen) -> Rect2` · `GoSafeArea.px_to_units(window, px) -> float` | The two conversions above as pure functions — feed a phone's figures to test a layout on the desktop |
| `GoSafeArea.margins(view) -> Vector4` · `GoSafeArea.hud_rect(view, side_max = -1) -> Rect2` | The safe margins (left, top, right, bottom, UI units); the usable rect with the left and right insets capped at the second argument (negative: `GoConfig.hud_side_inset_max`; that negative too, no cap) — what `GoHudAnchor` keeps to |
| `GoSafeArea.inset_rect(area, insets_px, window_px) -> Rect2` | `area` less insets given in window pixels, each scaled by the window's units per pixel — the safe area a simulated device gives, Magnet Mayhem's `UiScale` numbers (`inset × canvas / pixels`) |
| `GoSafeArea.obstructions(view) -> Dictionary` | 📷 What is **physically** in the way, for a HUD that runs edge to edge instead of keeping the whole safe area: `holes` (Array[Rect2] — camera cutouts; Android's `get_display_cutouts`; iOS names none in Godot 4.7, so the notch / Dynamic Island is derived from the insets, `ios_holes`), `corner_radius` (the rounded glass — `GoConfig.corner_radius_ios` pt · `corner_radius_ios_tablet` · `corner_radius_android` dp), `gesture` (the iOS home-indicator strip = the bottom inset: no tap target in it, art may run under), `screen` and `bars` (the insets that stay whole — `bar_insets`: an edge whose inset is no deeper than what explains it, a hole or a landscape iPhone's mirrored island, is released; a status/nav bar, an iPad's status bar and the home strip stay; an edge-to-edge HUD's canvas is the screen less `bars`), all in UI units. 🛑 A landscape iPhone's insets are symmetric and Godot reports no interface orientation, so the island band is on **both** long sides unless a simulated device names `notch_side`. Empty off handhelds / with `respect_safe_area` off. Sheets and forms keep `usable_rect` |
| `GoSafeArea.ios_holes(size_px, insets_px, scale, side = -1)` · `hole_insets(size, holes) -> Vector4` · `bar_insets(insets, explained, tolerance = 1) -> Vector4` · `nearest_edge(rect, size) -> int` | The rules above as pure functions: an iPhone's cutouts from its insets (`GoConfig.ios_cutout_lengths`: a 59-pt inset is a 126-pt island, 44–50 pt a 210-pt notch, under 30 pt — an iPad's status bar — none), the depth the holes reach into each edge (what Android reports as an immersive window's insets) and the `Side` a hole sits on |
| `GoSafeArea.corner_shift(shape, screen, radius, circle = false, along = -1) -> Vector2` · `corner_keep(screen, radius) -> Array[Rect2]` | The rounded corners: how far a shape (a control's visible face; `circle` for a round one) moves inward to sit inside the arc — diagonally (0.29 × r for a box flush on both edges), or along one axis for a row anchored on the other; and the L-shaped bars a floating layout keeps off (a rect touching none of them is inside the arcs) |
| `GoSafeArea.new()` (a Control) | Positions itself over the safe area — a parent for content that must avoid the notch; it moves on a resize and on `GoRuntime.safe_area_changed` |
| `enum GoScale.Bp { MOBILE, TABLET, DESKTOP }` | Short side in dp: ≤ `mobile_max_dp` (576) mobile, ≤ `tablet_max_dp` (991) tablet |
| `GoScale.breakpoint_for_dp(dp)` · `form_width_for(bp)` · `gain_for(bp, handheld, portrait)` · `display_scale(raw_scale, dpi, screen_px)` · `breakpoint_name(bp)` | Pure functions |
| `enum GoScale.Profile { DP, PER_INCH }` · `GoScale.per_inch_factor(window_px, dpi, base, units_per_inch, min_height, handheld)` · `per_inch_canvas(window_px, base, factor)` · `web_dpi(reported)` · `cap_sides(margins, side_max)` | The per-inch profile as pure functions: the `content_scale_factor` that keeps a `canvas_items` base size about 160 units per physical inch on a handheld (never below the minimum height, never below 1), the canvas it gives, a phone browser's real dpi, and safe margins with the sides capped for an edge-hugging HUD |
| `GoScale.is_handheld_screen()` · `handheld_from(has_feature, browsers)` · `screen_dpi()` · `dpi_from(reported, web, fallback)` | What `PER_INCH` and the safe area take as the device: a simulated one, else Android or iOS (with `GoConfig.handheld_browsers` also a phone or tablet browser), and the screen's dpi (a browser's rescaled by `web_dpi()`, `GoConfig.fallback_dpi` when it reports none) — the rules as pure functions over a stand-in `has_feature` and a reported dpi |
| `GoRuntime` (plugin autoload) | `breakpoint_changed(bp)` · `viewport_resized(size)` · `keyboard_changed(px)` · `safe_area_changed(margins)` · `current_bp()` · `is_mobile()` · `short_dp()` · `safe_margins()` |
| `GoRuntime.simulate(device)` · `clear_simulation()` · `simulation()` · `GoScale.simulate(device)` · `GoScale.simulated()` | 🧪 A device stood in for tests and screenshots (below) |
| `GoUi.is_handheld_platform()` | Android or iOS (not "narrow window") — haptics, the virtual keyboard and the real safe area |

`scale_enabled = true` makes 1 UI unit = 1 dp by setting `Window.content_scale_factor` — it changes the whole
project's 2D coordinates, so only turn it on in a project designed for it. With `scale_profile = GoScale.Profile.PER_INCH`
it instead keeps the project's base size (`canvas_items` stretch) and shrinks a handheld so the UI is the same size in
the hand on every phone — Magnet Mayhem's device profile.

```gdscript
var runtime := GoUi.runtime()
# 🛑 `GoUi.runtime()` is typed `Node`, so `runtime.breakpoint_changed` does not parse — connect by name.
if runtime:
	runtime.connect(&"breakpoint_changed", func(bp: GoScale.Bp) -> void: rebuild_for(bp))
	runtime.connect(&"safe_area_changed", func(margins: Vector4) -> void: hud.set_margins(margins))
```

**Magnet Mayhem's profile, set up once at boot** — the canvas about 160 units per inch on a phone and in a phone
browser, never under 440 tall, an unknown dpi read as 160, the in-match HUD pushed in by a landscape notch 12 at most:

```gdscript
GoUi.config.scale_enabled = true
GoUi.config.scale_profile = GoScale.Profile.PER_INCH
GoUi.config.handheld_browsers = true      # web_android / web_ios: the phone profile too (no safe area there)
GoUi.config.fallback_dpi = 160.0          # a screen that reports no dpi
GoUi.config.hud_side_inset_max = 12.0     # GoHudAnchor: the side insets capped, top and bottom whole
```

🛑 **A 180° turn keeps the window size** — in landscape the notch moves to the other side with no resize. On a phone
`GoRuntime` reads the safe area again every `GoConfig.safe_area_poll_seconds` (0.5 s; 0 never) and says
`safe_area_changed(margins)`; `GoHudAnchor` and the `GoSafeArea` node follow it. A browser has no safe area: margins
stay 0 there.

🧪 **A device stood in** — `GoRuntime.simulate({dpi, insets, handheld, size})` (insets: the safe area's left, top,
right and bottom in window pixels; `mobile` reads as `handheld`, so Magnet Mayhem's `DEVICE_PROFILES` pass as they
are). The `PER_INCH` scale, the breakpoint and `GoSafeArea` read it; the window takes `size` (a headless run cannot
resize — the scale is still worked out for it); a key left out reads the real device (no `insets`: none).
`obstructions()` reads `platform` ("android" | "ios"), `cutouts` (window pixels — an Android device given only these
gets them as its insets too), `corner_radius` (pixels; left out: the platform's `GoConfig` default), `screen_scale` (iOS
pixels per point) and `notch_side` (`SIDE_LEFT` | `SIDE_RIGHT`) from the same dictionary.

```gdscript
GoRuntime.simulate({"size": Vector2i(2532, 1170), "dpi": 460.0, "insets": Vector4(141, 0, 141, 63), "handheld": true})
GoRuntime.clear_simulation()              # the real device and the window's own size again
# iPhone 15 Pro, landscape, the Dynamic Island on the left: an edge-to-edge HUD reads GoSafeArea.obstructions()
GoScale.simulate({"handheld": true, "size": Vector2i(2556, 1179), "platform": "ios", "insets": Vector4(177, 0, 177, 63),
	"screen_scale": 3.0, "corner_radius": 165.0, "notch_side": SIDE_LEFT})
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

`hide_on_handheld` (default on) · `done` (a key already pressed: the caps turn green) · `set_keys(array)` `keys()` · `GoKbd.action_keys(action)`.

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
