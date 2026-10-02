# Coming from Flutter

Flutter's widget catalogue, widget by widget, with what to use in gohud (or in Godot itself). Read it when you know
the Flutter widget you would reach for and want its gohud name. Each part listed draws through a `GoSkin` hook, so it
takes every preset's own shape and the M3 component's under the Material presets (theming.md §6).

## Contents

1. [The widgets ported from Flutter](#1-the-widgets-ported-from-flutter)
2. [Scaffold, lists and gestures](#2-scaffold-lists-and-gestures)
3. [Pickers and steps](#3-pickers-and-steps)
4. [Catalogue — Material and Cupertino](#4-catalogue--material-and-cupertino)
5. [Catalogue — layout, scrolling, painting, motion](#5-catalogue--layout-scrolling-painting-motion)
6. [Left out on purpose](#6-left-out-on-purpose)

## 1. The widgets ported from Flutter

| Flutter | gohud | One line |
|---|---|---|
| `Scaffold` | `GoScaffold` (Control) | `GoScaffold.make("Inbox", page, true)` — app bar, a scrolling body, bottom bar, FAB, drawer |
| `ListView.builder` | `GoListView` (GoScroll) | `GoListView.make(10000, 56.0, build_row)` — builds only the rows in view |
| `RefreshIndicator` | `GoRefresh` (Control) | `GoRefresh.attach(scroll)` → `refresh_requested` → `finish()` |
| `Dismissible` | `GoSwipeRow` (Container) | `GoSwipeRow.wrap(row, {"icon", "text", "tone", "action"})` |
| `TabBarView` + `DefaultTabController` | `GoTabView` (VBoxContainer) | `GoTabView.make(["Posts", "Photos"], [posts, photos])` — tabs and swipeable pages in step |
| `SimpleDialog`, `CupertinoActionSheet` | `GoDialogs.choose()` | `await dialogs.choose("Sort by", ["Newest", "Price"])` → index or -1 |
| `MaterialBanner` | `GoBanner` (PanelContainer) | `GoBanner.make("You're offline.", [{"text": "Retry", "action": retry}])` |
| `OutlinedButton` | `GoStyle.Tone.OUTLINED` | `GoStyle.button("Details", open, GoStyle.Tone.OUTLINED)` |
| `BottomAppBar` | `GoStyle.bottom_app_bar()` | `GoStyle.bottom_app_bar(items, GoFab.make(GoIconSet.PLUS))` |
| `NavigationDrawer` | `GoNavBar.drawer_list()` | full-width 56 dp destination rows for a `GoDrawer` |
| `SliverAppBar.medium` / `.large` | `GoAppBar.expanded_title()` | the big title scrolls away and the bar's small title fades in |
| `RangeSlider` | `GoRangeSlider` (Control) | `GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0)` |
| `Stepper` | `GoStepper` (VBoxContainer) | `GoStepper.make([{"title", "subtitle", "content"}])` |
| `showTimePicker` | `GoTimePicker` (Container) | `GoTimePicker.make(9, 30, on_time)` — the M3 dial, 12 or 24 hours |
| `showDateRangePicker` | `GoDatePicker.range_mode` | two taps pick a range; `range_picked(start, end)` |
| `ReorderableListView` | `GoReorderList` (Container) | `GoReorderList.make(rows)` → `reordered(from, to)` |
| `InteractiveViewer` | `GoZoomView` (Control) | `GoZoomView.wrap(map, 4.0)` — pinch, wheel, double tap, pan |
| `CupertinoPicker`, `ListWheelScrollView` | `GoWheelPicker` (Control) | `GoWheelPicker.make(["x1", "x5", "x10"], 0, on_amount)` |

## 2. Scaffold, lists and gestures

```gdscript
var page := GoStyle.column()
var screen := GoScaffold.make("Inbox", page, true)          # a menu button that opens the drawer
screen.set_bottom_bar(GoNavBar.make([{"icon": GoIconSet.HOME, "text": "Home"}, {"icon": GoIconSet.USER, "text": "Me"}]))
screen.set_fab(GoFab.make(GoIconSet.EDIT, "", compose))
screen.set_drawer(GoDrawer.new())
add_child(screen)

var feed := GoListView.make(posts.size(), 72.0, func(index: int) -> Control: return post_row(posts[index]))
feed.end_reached.connect(load_more)                          # near the end — fetch the next page, then set_count()
var refresh := GoRefresh.attach(feed)
refresh.refresh_requested.connect(func() -> void:
	await reload()
	refresh.finish())
```

| Class | Members |
|---|---|
| `GoScaffold` (Control) | `make(title, page, menu)` · `set_app_bar(bar)` · `set_body(page, scrolls)` · `set_bottom_bar(bar)` · `set_fab(fab)` · `set_drawer(drawer)` · `open_drawer()` · `snackbar_margin()` · `scroll` · `app_bar` · `body` · `bottom_bar` · `fab` · `drawer` |
| `GoListView` (GoScroll) | `make(rows, extent, build)` · `recycle(rows, extent, create, bind)` · `set_count(rows)` · `refresh()` · `scroll_to_index(i)` · `row(i)` · `built_indexes()` · `item_extent` · `spacing` · `overscan` · `end_threshold` · signals `end_reached` · `row_shown(index)` |
| `GoRefresh` (Control) | `attach(scroll, action)` · `finish()` · `refreshing` · `trigger_dp` · `rest_dp` · signal `refresh_requested` |
| `GoSwipeRow` (Container) | `wrap(row, end, start)` · `trigger(direction)` · `threshold` · `free_on_dismiss` · `content` · signals `swiped(direction)` · `dismissed` — an action is `{"icon", "text", "tone", "action", "dismiss"}` |
| `GoTabView` (VBoxContainer) | `make(names, pages, selected, translate)` · `current()` · `page(i)` · `set_tab(i, animate)` · `tab_bar` (a `GoStyle.tabs` row with `fill` on) · `swipe_slop` · signal `tab_changed(index)` — the pages keep a `GAP` from the tab line |
| `GoReorderList` (Container) | `make(rows, with_grips)` · `add_row(row)` · `remove_row(row)` · `rows()` · `move_row(from, to)` · `is_dragging()` · `grips` · `hold_ms` · `spacing` · signal `reordered(from, to)` |
| `GoZoomView` (Control) | `wrap(content, most)` · `set_content(content)` · `get_zoom()` · `zoom_to(zoom, around, animate)` · `reset(animate)` · `min_zoom` · `max_zoom` · `double_tap_zoom` · `wheel_step` · signal `zoom_changed(zoom)` |
| `GoBanner` (PanelContainer) | `make(message, actions, icon, translate)` · `message()` · `dismiss()` · signal `closed` — an action is `{"text", "action", "keep"}` |
| `GoDialogs.choose` | `await choose(title, options, cancel_text, translate) -> int` — an option is a string or `{"text", "icon", "subtitle", "danger"}`; a bottom sheet on a phone, centred on a desktop |

- 🔑 **`GoListView` rows are one height** (`item_extent`), which is what makes a list of 100 000 cost the same as a list of
  20. A feed whose rows differ in height is a `GoScroll` with a column, paged with `GoPagination`.
- 🔑 **`to` in `reordered(from, to)` is the new index** — `items.insert(to, items.pop_at(from))` keeps the data in step
  (Flutter's `onReorder` needs a `-1` fix; this does not).
- 🔑 Every gesture here leaves the page's scroll alone: a swipe row and a tab page claim only a drag that goes sideways
  first, pull to refresh only a downward pull at the top, a reorder grip and a zoom view only drags that start on them.
- ♿ A swipe and a drag are invisible until tried — keep the same action on the row's menu (`GoContextMenu`). A grip
  takes focus and moves its row with Up and Down; `GoZoomView` zooms with `+` `-` `0` and pans with the arrows.
- 🛑 `GoRefresh.attach()` adds the indicator **beside** the scroll (deferred) — the scroll needs a parent.

## 3. Pickers and steps

```gdscript
var when := GoTimePicker.make(9, 30, func(hour: int, minute: int) -> void: save_alarm(hour, minute))
var stay := GoDatePicker.make()
stay.range_mode = true
stay.range_picked.connect(func(start: Dictionary, end: Dictionary) -> void: book(start, end))
var price := GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0)
price.change_ended.connect(func(low: float, high: float) -> void: refilter(low, high))
var amount := GoWheelPicker.make(["x1", "x5", "x10", "x50"], 0, func(index: int) -> void: set_amount(index))
var steps := GoStepper.make([{"title": "Cart", "content": cart}, {"title": "Pay", "content": pay}])
steps.can_continue = func(index: int) -> bool: return index != 0 or not cart_is_empty()
steps.finished.connect(place_order)
```

| Class | Members |
|---|---|
| `GoTimePicker` (Container) | `make(at_hour, at_minute, action, twenty_four)` · `get_time()` · `set_time(hour, minute)` · `show_part(part)` · `current_part()` · `use_24h` · `hour` · `minute` · signal `picked(hour, minute)` — Up / Down on a focused hour or minute box turn it by one |
| `GoDatePicker` range | `range_mode` · `get_range() -> [start, end]` · `set_range(start, end)` · signal `range_picked(start, end)` |
| `GoRangeSlider` (Control) | `make(minimum, maximum, from, to, snap)` · `set_range(from, to)` · `low` · `high` · `min_value` · `max_value` · `step` · `min_gap` · signals `changed(low, high)` · `change_ended(low, high)` |
| `GoWheelPicker` (Control) | `make(choices, selected, action, as_keys)` · `set_items(choices, selected)` · `select(index, animate)` · `get_selected()` · `get_text()` · `item_height` · `visible_items` · `translate` · signal `changed(index)` |
| `GoStepper` (VBoxContainer) | `make(steps, current, translate)` · `current()` · `set_step(i, force)` · `next()` · `back()` · `set_error(i, wrong)` · `state_of(i)` · `layout` (`Layout.VERTICAL` / `HORIZONTAL` — in a row each marker sits over its title, so three or four steps fit a phone) · `can_continue` · signals `step_changed(index)` · `finished` |

- 🔑 The time picker's dial turns to the minutes by itself once the hour is set, as on Android. A 24-hour dial puts
  13–00 on an inner ring.
- 🔑 Turning `range_mode` on clears the single picked day; `set_range()` shows a range picked before.
- ♿ A range slider is spoken as "40 – 220"; the time boxes as "Hour 9" and "Minute 30"; a step header says its place
  ("2 / 3") with its title; the wheel says the item on its band. The AM/PM marks and the box names follow the game's
  language (`am`, `pm`, `hour`, `minute` in `GoConfig.text_keys`).

## 4. Catalogue — Material and Cupertino

| Flutter | gohud |
|---|---|
| `AppBar` | `GoAppBar` — `follow(scroll)` lifts it; `Size.MEDIUM` / `LARGE` with `expanded_title()` |
| `NavigationBar`, `BottomNavigationBar`, `CupertinoTabBar` | `GoNavBar` |
| `NavigationRail` | `GoNavBar.rail()` |
| `Drawer`, `NavigationDrawer` | `GoDrawer` with `GoNavBar.drawer_list()` inside |
| `FloatingActionButton` (all sizes, extended) | `GoFab` |
| `FilledButton` · `FilledButton.tonal` · `TextButton` · `OutlinedButton` · `ElevatedButton` | `GoStyle.button()` with `Tone.PRIMARY` · `NORMAL` · `BARE` · `OUTLINED` · `PRIMARY` + `GoStyle.glow()` |
| `IconButton` | `GoIconButton`, `GoStyle.icon_button()` |
| `SegmentedButton`, `CupertinoSegmentedControl` | `GoStyle.segmented()` |
| `Chip`, `ActionChip` · `FilterChip` · `InputChip` · `ChoiceChip` | `GoStyle.chip()` · `filter_chip()` · `input_chip()` · `segmented()` / `choice_grid()` |
| `Checkbox` · `Switch`, `CupertinoSwitch` · `Radio` | `GoStyle.checkbox()` · `toggle()` · `radio_group()` |
| `Slider`, `CupertinoSlider` · `RangeSlider` | `GoStyle.slider()` · `GoRangeSlider` |
| `TextField`, `TextFormField`, `Form` | `GoStyle.line_edit()` / `field()`, `GoField` (per-field errors), `GoForm` (keyboard avoidance, width caps) |
| `DropdownButton`, `DropdownMenu`, `Autocomplete` | `GoStyle.dropdown()` / `select()`, `GoCombobox` (searches inside names) |
| `PopupMenuButton`, `MenuAnchor`, `CupertinoContextMenu` | `GoContextMenu` (long press, right click), `GoPopover` |
| `SearchBar` | `GoSearchBar` |
| `AlertDialog`, `CupertinoAlertDialog` · `SimpleDialog`, `CupertinoActionSheet` | `GoDialogs.confirm()` / `alert()` · `GoDialogs.choose()` |
| `showModalBottomSheet`, `BottomSheet` | `GoSheet` (pages with back navigation, sticky footer) |
| `SnackBar` · `MaterialBanner` | `GoSnackbar` · `GoBanner` |
| `Tooltip` | `tooltip_text` (themed), `GoStyle.tooltip_node()` |
| `Badge` | `GoBadge` |
| `Card` · `ListTile` · `Divider` · `CircleAvatar` | `GoStyle.card()` · `list_row()` / `list_button()` · `divider()` · `avatar()` |
| `ExpansionTile`, `ExpansionPanelList` | `GoStyle.foldable()` |
| `TabBar` · `TabBarView` | `GoStyle.tabs()` · `GoTabView` |
| `LinearProgressIndicator`, `CircularProgressIndicator` | `GoProgress` (wavy or flat, indeterminate) |
| `CupertinoActivityIndicator` · M3 Expressive `LoadingIndicator` | `GoSpinner` · `GoLoadingIndicator` |
| `showDatePicker`, `CalendarDatePicker` · `showDateRangePicker` | `GoDatePicker` · `GoDatePicker.range_mode` |
| `showTimePicker` · `CupertinoDatePicker`, `CupertinoPicker` | `GoTimePicker` · `GoWheelPicker` (one wheel per part) |
| `Stepper` | `GoStepper` |
| `DataTable`, `PaginatedDataTable` | `GoTable`, `GoPagination` |
| `Scrollbar`, `CupertinoScrollbar` | built into `GoScroll` |
| `RefreshIndicator`, `CupertinoSliverRefreshControl` | `GoRefresh` |
| `Theme`, `ThemeData`, `ColorScheme` | `GoUi.use_preset()`, `GoThemePresets`, `GoUi.color()` — every M3 colour role under Material (`GoUi.color(&"md_secondary_container")`) |

## 5. Catalogue — layout, scrolling, painting, motion

These are Godot's own building blocks; gohud adds the factories that keep sizes on the theme's tokens.

| Flutter | Godot / gohud |
|---|---|
| `Column` · `Row` | `VBoxContainer` · `HBoxContainer` — `GoStyle.column()` · `row()` with token gaps |
| `Expanded`, `Flexible`, `Spacer` | `size_flags_horizontal = SIZE_EXPAND_FILL` (`size_flags_stretch_ratio` for the flex), `GoStyle.spacer()` |
| `SizedBox` | `custom_minimum_size`, `GoStyle.spacer(minimum)`; the gap between a box's children is `GoStyle.gap(box)` |
| `Padding` · `Center`, `Align` | `MarginContainer`, `GoStyle.padding()` · `CenterContainer`, `GoStyle.center_in()` |
| `Container`, `DecoratedBox` | `PanelContainer` with a skin face — `GoStyle.card()`, `GoStyle.surface()` |
| `Stack`, `Positioned` | a plain `Control` with anchors and offsets |
| `Wrap` · `GridView` | `GoStyle.wrap_row()` · `GoStyle.responsive_grid()`, `GridContainer` |
| `AspectRatio` | `GoStyle.aspect()` |
| `SafeArea`, `MediaQuery` | `GoSafeArea`, `GoScale` (breakpoints and dp) |
| `ListView`, `SingleChildScrollView` · `ListView.builder` | `GoScroll` with a column · `GoListView` |
| `PageView` | `GoCarousel` (never turns on its own), `GoTabView` |
| `CustomScrollView` with `SliverAppBar` | `GoAppBar.expanded_title()` as the page's first row |
| `Text`, `RichText` | `GoStyle.label()` / `label_key()`, `RichTextLabel` |
| `Icon` · `Image` | `GoUi.icons().node(name, size, color)` · `TextureRect`, `GoStyle.art()` |
| `GestureDetector`, `InkWell` | `Button` (`pressed`), `gui_input`; a long press is `GoContextMenu` |
| `Draggable`, `DragTarget` | Godot's `_get_drag_data()` / `_can_drop_data()` / `_drop_data()`; a list in order is `GoReorderList` |
| `Opacity` · `Transform` · `ClipRRect` · `CustomPaint` | `modulate` · `scale`, `rotation`, `pivot_offset` · `clip_contents` · `_draw()` |
| `AnimatedContainer`, `AnimatedOpacity`, `FadeTransition`, `AnimatedSwitcher` | `create_tween()`, `GoStyle.fade()`; respect `GoUi.config.reduce_motion` |
| `Semantics` | `accessibility_name`, `accessibility_description` |
| `Localizations`, `Intl` | `GoUi.text()`, `TranslationServer`, the 21 languages gohud ships |
| `FutureBuilder`, `StreamBuilder` | `await` the call, then fill the widget |

## 6. Left out on purpose

- **`Navigator`, routes, `Hero`** — a Godot game changes scenes or shows and hides screens; inside a window,
  `GoSheet` pages carry their own back navigation. Android Back goes through `GoBackPolicy`.
- **`SearchAnchor`** (a search bar that opens its own suggestion view) — `GoSearchBar` stays the entry point and the
  results belong to the page under it; a fixed list of choices is `GoCombobox`.
- **`AnimatedList`** — rows that slide in and out are a `create_tween()` on the row you add or remove; `GoSwipeRow`
  already folds a dismissed row away.
- **`Cupertino` look-alikes** — the iOS look is a preset question (`references/theming.md`), not a second set of
  widgets: every part here takes its shape from the active skin.
