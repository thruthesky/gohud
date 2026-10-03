## An app screen built with gohud — the frame of a social, news or shopping app, as Flutter builds it from
## `Scaffold`, `TabBarView`, `ListView.builder`, `RefreshIndicator` and `Dismissible`. Copy it to your project
## (e.g. res://ui/app_screen.gd) and make it the root of a screen: `add_child(preload("res://ui/app_screen.gd").new())`.
##
## Top: an app bar — a menu button that opens the drawer, and a search action · middle: two tabs whose pages swipe —
## "Feed", a lazy list that builds only the rows in view, with pull to refresh and "load more" near its end, and
## "Saved", rows the player swipes away with an Undo · bottom: a navigation bar with an unread badge · bottom end: a
## compose button (FAB) floating above the bar · snackbars above the bar.
##
## 🔑 It owns no data: it says what the player did (signals) and shows what you hand it (`set_posts`, `add_posts`,
##    `set_saved`, `set_unread`). A post is `{"title": String, "subtitle": String, "icon": StringName}` (icon optional).
extends Control

signal post_opened(post: Dictionary)
signal compose_requested
signal search_requested
## Pulled down at the top of the feed. Hand the fresh posts to `set_posts()` — that ends the spinner.
signal refresh_requested
## The feed is near its end. Hand the next page to `add_posts()` — an empty page says it was the last.
signal more_requested
## A destination on the navigation bar — 0 Home (this screen), 1 Alerts, 2 Profile. Switching screens is yours.
signal destination_changed(index: int)
## A row in the drawer menu — 0 Settings, 1 Help, 2 Sign out.
signal drawer_chosen(index: int)
## The player swiped a saved post away and did not take it back — remove it on your side (the server, the save).
signal saved_removed(post: Dictionary)

var posts: Array = []
## The saved posts on screen: what `set_saved()` handed over, less the ones swiped away and waiting for their Undo.
var saved: Array = []
var _given: Array = []
var _removed: Array = []

var screen: GoScaffold
var tabs: GoTabView
var feed: GoListView
var saved_page: VBoxContainer
var nav: GoNavBar
var drawer: GoDrawer
var refresh: GoRefresh
## Bottom-of-screen messages with buttons. It makes its own CanvasLayer (90), above the screen.
var snackbar: GoSnackbar
var _unread := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	build()


func build() -> void:
	var tab := tabs.current() if is_instance_valid(tabs) else 0
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	# 🔑 One height for every row is what lets the feed hold 100 000 posts at the cost of 20: only the rows in
	#    view exist. A feed whose rows differ in height is a GoScroll with a column instead.
	feed = GoListView.make(posts.size(), _row_height(), _post_row)
	feed.spacing = GoUi.metric(GoTheme.GAP_SMALL)        # rows further apart than the lines inside a row
	feed.end_reached.connect(func() -> void: more_requested.emit())
	var saved_scroll := GoScroll.new()
	# 🔑 The margin goes around the whole column here, not around each row: a swiped row frees itself, and a
	#    holder around it would stay behind as a gap.
	var margin := GoStyle.padding(GoUi.metric(GoTheme.GAP), 0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_scroll.add_child(margin)
	saved_page = GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	saved_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(saved_page)
	tabs = GoTabView.make(["Feed", "Saved"], [feed, saved_scroll], tab)
	# A tab view scrolls itself, so the scaffold places it as it is — no scroll around the tabs.
	screen = GoScaffold.make("Home", tabs, true)
	# `&"search"` is one of gohud's own names: the tooltip and the spoken name come translated (21 languages).
	screen.app_bar.add_action(GoIconSet.SEARCH, &"search", func() -> void: search_requested.emit())
	nav = GoNavBar.make([
		{"icon": GoIconSet.HOME, "text": "Home"},
		{"icon": GoIconSet.BELL, "text": "Alerts", "badge": _unread},
		{"icon": GoIconSet.USER, "text": "Profile"},
	], 0, _on_destination)
	screen.set_bottom_bar(nav)
	var compose := GoFab.make(GoIconSet.EDIT, "", func() -> void: compose_requested.emit())
	compose.tooltip_text_name = &"Compose"               # an icon-only FAB needs its spoken name
	screen.set_fab(compose)
	drawer = GoDrawer.new()
	drawer.follow_text_direction = true                  # a menu drawer opens from the start side, also in Arabic
	drawer.set_title("Menu")
	# Menu rows, not destinations: nothing here stays chosen. (A drawer that switches pages, like the navigation
	# bar, is `GoNavBar.drawer_list()` — its chosen row carries the pill.)
	var rows := [[GoIconSet.SETTINGS, "Settings"], [GoIconSet.HELP, "Help"], [GoIconSet.LOGOUT, "Sign out"]]
	for index in rows.size():
		drawer.body.add_child(GoStyle.list_button(rows[index][0], rows[index][1], _on_drawer.bind(index),
			Color.TRANSPARENT, "", false))
	screen.set_drawer(drawer)                            # the app bar's menu button opens it
	add_child(screen)
	# 🛑 After the feed is in the tree: the indicator is added beside the scroll, so the scroll needs a parent.
	refresh = GoRefresh.attach(feed, func() -> void: refresh_requested.emit())
	_fill_saved()
	if not is_instance_valid(snackbar):
		snackbar = GoSnackbar.new()
		add_child(snackbar)


# ── Public API ───────────────────────────────────────────────────────────

## Replaces the feed (after a refresh, or the first load) and ends the refresh spinner.
func set_posts(list: Array) -> void:
	posts = list.duplicate()
	feed.set_count(posts.size())
	feed.refresh()                                       # rows already on screen show the new posts
	if refresh.refreshing: refresh.finish()


## Appends the next page — the answer to `more_requested`. The view stays where it is. An empty page is the end:
## the list stops asking (setting the same count again would ask once more, and again, forever).
func add_posts(list: Array) -> void:
	if list.is_empty(): return
	posts.append_array(list)
	feed.set_count(posts.size())


func set_saved(list: Array) -> void:
	_given = list.duplicate()
	_removed.clear()
	_shown_saved()
	_fill_saved()


## The unread count on Alerts. 0 hides the badge.
func set_unread(count: int) -> void:
	_unread = maxi(0, count)
	nav.set_badge(1, _unread)


func show_tab(index: int) -> void:
	tabs.set_tab(index)


## A message the player can act on — "Removed / Undo". Returns the index of the button pressed, or -1 when it
## expired. It keeps clear of the navigation bar.
func say(message: String, actions: Array = []) -> int:
	snackbar.margin = screen.snackbar_margin()
	return await snackbar.post({"text": message, "actions": actions})


# ── Pieces ───────────────────────────────────────────────────────────────

## A two-line row is the touch height plus its padding above and below.
func _row_height() -> float:
	return float(GoUi.metric(GoTheme.TOUCH) + GoUi.metric(GoTheme.GAP) * 2)


func _post_row(index: int) -> Control:
	var post: Dictionary = posts[index]
	return _inset(GoStyle.list_button(StringName(post.get("icon", GoIconSet.USER)), str(post.get("title", "")),
		func() -> void: post_opened.emit(post), Color.TRANSPARENT, str(post.get("subtitle", "")), false))


## A feed row kept off the screen's sides. The list itself stays full width, so its scroll bar sits on the edge.
func _inset(row: Control) -> Control:
	var holder := GoStyle.padding(GoUi.metric(GoTheme.GAP), 0)
	holder.add_child(row)
	return holder


func _fill_saved() -> void:
	for child in saved_page.get_children():
		saved_page.remove_child(child)
		child.queue_free()
	if saved.is_empty():
		saved_page.add_child(GoStyle.empty_state(GoIconSet.STAR, "Nothing saved yet", false))
		return
	for post: Dictionary in saved:
		var row := GoStyle.list_button(StringName(post.get("icon", GoIconSet.STAR)), str(post.get("title", "")),
			func() -> void: post_opened.emit(post), Color.TRANSPARENT, str(post.get("subtitle", "")), false)
		# Swiped towards the start, the row slides away; the same action belongs on the post's own screen too —
		# a swipe is invisible until someone tries it.
		saved_page.add_child(GoSwipeRow.wrap(row,
			{"icon": GoIconSet.TRASH, "text": "Remove", "tone": GoTheme.DANGER, "action": _unsave.bind(post)}))


func _shown_saved() -> void:
	saved = _given.filter(func(post: Dictionary) -> bool: return not _removed.has(post))


func _unsave(post: Dictionary) -> void:
	if _removed.has(post): return
	_removed.append(post)
	_shown_saved()                                       # the swiped row frees itself; the data follows
	# 🔑 A cheap, reversible action asks nothing first and offers Undo after — a dialog would stop the player to ask.
	#    The title is in the message: the snackbar merges a line repeated word for word, and one Undo would then
	#    answer for every post swiped away in a row.
	var undo := await say("Removed “%s”" % str(post.get("title", "")), ["Undo"]) == 0
	_removed.erase(post)
	if not undo:
		_given.erase(post)
		saved_removed.emit(post)
	_shown_saved()
	# Taken back — the row returns to its own place in the order given; or the last row went — the empty state.
	if undo or saved.is_empty(): _fill_saved()


func _on_destination(index: int) -> void:
	destination_changed.emit(index)


func _on_drawer(index: int) -> void:
	drawer.close()
	drawer_chosen.emit(index)
