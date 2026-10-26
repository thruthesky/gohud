## 🧪 **GoPage checks** — the full-screen page: open/close, tabs, rail vs top tabs, preview, back, Escape and the
## back gesture on stacked pages, back-gesture ownership, safe-area fill, right-to-left mirroring; sub-pages (push / pop,
## back and Escape one level at a time, focus back on the pusher, built on push and freed on pop), the in-page confirm,
## and the hand-over to another window (a page's and a drawer's).
##
##   godot --headless --path <project> -s res://addons/gohud/tests/gohud_page_test.gd
##
## Its own file (like `gohud_choice_column_test.gd`) so the people adding widgets to the other test files never clash
## with it; `tools/check_all.sh` calls it.
extends SceneTree

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	# The same stretch the other gohud tests turn on (a bare host project leaves it off and every size stays 64×64).
	# 🛑 Orientation is the point here, so the aspect is IGNORE for the run: a host that stretches with `expand` (a game host)
	#    keeps the window's own shape, and asking for 844×390 on a portrait window still came out taller than wide.
	var kept := [root.content_scale_mode, root.content_scale_aspect, root.content_scale_size]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(390, 844)
	await frames(2)
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true
	GoBackPolicy.reset(self)

	await _open_close()
	await _tabs()
	await _orientation_and_preview()
	await _long_tab_labels()
	await _card_follows_content()
	await _back_and_stacking()
	await _ownership_after_free()
	await _rtl()
	await _sub_pages()
	await _sub_page_rtl()
	await _in_page_confirm()
	await _hold()
	await _page_hand_over()
	await _drawer_hand_over()

	root.content_scale_mode = kept[0]
	root.content_scale_aspect = kept[1]
	root.content_scale_size = kept[2]
	print("gohud page tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func section(name: String) -> void:
	print("  %s %s" % ["ok  " if failed.is_empty() else "....", name])


func frames(count: int) -> void:
	for _i in count: await process_frame


## The card covers [param area] to within a pixel on every side and never reaches past it (a fractional logical size
## must not round the card's last row off the screen).
func _fills(card: Rect2, area: Rect2) -> bool:
	return area.grow(0.001).encloses(card) and card.size.x > area.size.x - 1.0 and card.size.y > area.size.y - 1.0


func _size(width: int, height: int) -> void:
	root.content_scale_size = Vector2i(width, height)
	await frames(3)


func _cancel() -> InputEventAction:
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	return cancel


func _tabs_spec() -> Array[Dictionary]:
	return [
		{id = &"one", label = "One", icon = GoIconSet.USER, badge = ""},
		{id = &"two", label = "Two", icon = GoIconSet.SETTINGS, badge = "12"},
		{id = &"three", label = "Three", icon = &"", badge = "", alert = true},
	]


# ── Open, close, open_key ──────────────────────────────────────────────

func _open_close() -> void:
	var page := GoPage.new()
	check(page.body != null and page.surface != null, "body and surface exist before the page enters the tree")
	root.add_child(page)
	await frames(2)
	check(not page.is_open() and not page.visible, "a new page starts closed")
	var closes := [0]
	page.closed.connect(func() -> void: closes[0] += 1)
	page.open("Settings")
	await frames(3)
	check(page.is_open() and page.visible, "open() shows the page")
	check(page.surface.title_label.text == "Settings"
		and page.surface.title_label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED,
		"open() shows the given title as it is")
	check(page.layer == 10, "the page sits on layer 10 like a sheet (%d)" % page.layer)
	check(GoBackPolicy.owners() == 1, "an open page owns the back gesture (%d)" % GoBackPolicy.owners())
	check(not quit_on_go_back, "with a page open the back gesture does not quit")
	# Safe-area fill: the card is the usable rectangle, the ground behind is the whole screen and opaque.
	var area := GoSafeArea.usable_rect(page.surface.get_window())
	check(_fills(page.surface.card.get_global_rect(), area),
		"the card fills the safe area in whole pixels, never past it (%s vs %s)" % [page.surface.card.get_global_rect(), area])
	var ground := page.surface._scrim
	check(ground.get_global_rect().size.is_equal_approx(page.surface.get_viewport_rect().size),
		"the ground fills the whole screen (%s)" % ground.get_global_rect())
	check(is_equal_approx(ground.color.a, 1.0), "an opaque page's ground is opaque (alpha %.2f)" % ground.color.a)
	check(is_equal_approx(page.surface.alpha, 1.0), "an opaque page asks for an opaque panel")
	page.opaque = false
	check(ground.color.a < 1.0, "a see-through page goes back to the scrim (alpha %.2f)" % ground.color.a)
	page.opaque = true
	page.close()
	await frames(2)
	check(not page.is_open() and int(closes[0]) == 1, "close() hides the page and fires closed once")
	page.close()
	check(int(closes[0]) == 1, "closing a closed page fires nothing")
	check(GoBackPolicy.owners() == 0, "after close the back gesture is released (%d)" % GoBackPolicy.owners())
	page.open_key("pageTitleKey")
	await frames(1)
	check(page.surface.title_label.text == "pageTitleKey"
		and page.surface.title_label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_ALWAYS,
		"open_key() puts the key through the engine's translation")
	page.close()
	page.queue_free()
	await frames(2)
	section("open · close · open_key · safe area · opaque ground")


# ── Tabs ───────────────────────────────────────────────────────────────

func _tabs() -> void:
	var page := GoPage.new()
	root.add_child(page)
	var seen: Array[StringName] = []
	page.tab_changed.connect(func(id: StringName) -> void: seen.append(id))
	page.open("Tabs")
	page.set_tabs(_tabs_spec())
	await frames(3)
	check(seen == [&"one"], "set_tabs() shows the first tab and says so (%s)" % str(seen))
	check(page.current_tab() == &"one", "current_tab() is the first tab")
	page.select_tab(&"two")
	check(page.current_tab() == &"two" and seen.back() == &"two", "select_tab() moves to the tab and fires tab_changed")
	page.select_tab(&"two")
	check(seen.size() == 2, "selecting the shown tab again fires nothing")
	page.select_tab(&"nope")
	check(page.current_tab() == &"two" and seen.size() == 2, "an unknown tab id does nothing")
	page.tab_button(&"three").pressed.emit()
	check(page.current_tab() == &"three", "a tap on a rail tab selects it")
	check(bool(page.tab_button(&"three").get_meta(&"go_selected", false))
		and not bool(page.tab_button(&"one").get_meta(&"go_selected", false)), "only the shown tab looks chosen")
	var badge := page.tab_button(&"two").find_child("Badge", true, false) as GoBadge
	check(badge != null and badge.label_text == "12" and badge.visible, "a tab's badge text shows on its tab")
	check(page.tab_button(&"one").find_child("Badge", true, false) == null, "a tab without a badge has none")
	check(page.tab_button(&"three").has_meta(&"gohud_badge"), "alert = true puts a dot on the tab")
	# 🔁 One tab's count and dot change in place — no rebuild, the shown tab stays and fires nothing.
	var shown_before := page.current_tab()
	var fired := seen.size()
	var two_button := page.tab_button(&"two")
	page.set_tab_badge(&"one", "3", true)
	var one_badge := page._row_of(page.tab_button(&"one")).get_node_or_null(^"Badge") as GoBadge
	check(one_badge != null and one_badge.label_text == "3" and page.tab_button(&"one").has_meta(&"gohud_badge"),
		"set_tab_badge() puts a count and a dot on a tab")
	page.set_tab_badge(&"two", "13")
	check(badge.label_text == "13" and page.tab_button(&"two") == two_button, "set_tab_badge() changes a count in place")
	page.set_tab_badge(&"one")
	await frames(1)
	check(page.tab_button(&"one").find_child("Badge", true, false) == null and not page.tab_button(&"one").has_meta(&"gohud_badge"),
		"set_tab_badge() with no badge and no alert removes both")
	page.set_tab_badge(&"missing", "1", true)
	check(page.current_tab() == shown_before and seen.size() == fired, "set_tab_badge() keeps the shown tab and fires nothing")
	page.set_tab_badge(&"two", "12")
	for id in [&"one", &"two", &"three"]:
		check(page.tab_button(id).size.y >= GoUi.metric(GoTheme.TOUCH) - 0.5,
			"tab %s is a full touch target (%.0f)" % [id, page.tab_button(id).size.y])
	seen.clear()
	page.set_tabs(_tabs_spec(), &"three")
	check(seen == [&"three"] and page.current_tab() == &"three", "set_tabs() honours the selected id")
	page.body.add_child(GoStyle.label("kept"))
	page.close()
	page.open("Again")
	check(page.body.get_child_count() == 1 and page.current_tab() == &"three", "body and tab survive a close and open")
	page.clear()
	await frames(1)
	check(page.body.get_child_count() == 0, "clear() empties the content")
	var none: Array[Dictionary] = []
	page.set_tabs(none)
	check(not page._rail_scroll.visible and page.current_tab() == &"", "no tabs → no rail")
	page.close()
	page.queue_free()
	await frames(2)
	section("tabs · select_tab · current_tab · tab_changed · badges")


# ── Long tab labels: no overlap along the top, no spill down the rail ──

func _long_tab_labels() -> void:
	var page := GoPage.new()
	root.add_child(page)
	page.open("Long")
	var tabs: Array[Dictionary] = []
	for i in 6:
		tabs.append({id = StringName("t%d" % i), label = "Category name %d long" % i, icon = &""})
	page.set_tabs(tabs)
	await _size(390, 844)
	await frames(3)
	var overlap := 0
	var spill := 0
	for i in 6:
		var button := page.tab_button(StringName("t%d" % i))
		var words: Label = button.find_children("*", "Label", true, false)[0]
		if not button.get_global_rect().grow(0.5).encloses(words.get_global_rect()) \
				or words.get_minimum_size().x > words.size.x + 0.5: spill += 1
		if i > 0 and page.tab_button(StringName("t%d" % (i - 1))).get_global_rect().end.x > button.get_global_rect().position.x + 0.5:
			overlap += 1
	check(overlap == 0 and spill == 0, "portrait: long one-line tabs never overlap and keep their words inside (%d overlaps · %d spills)" % [overlap, spill])
	check(page._rail.size.x > page._rail_scroll.size.x, "portrait: tabs wider than the screen make the strip scroll sideways (%.0f > %.0f)"
		% [page._rail.size.x, page._rail_scroll.size.x])
	page.select_tab(&"t5")
	await frames(3)
	check(page._rail_scroll.get_global_rect().grow(0.5).encloses(page.tab_button(&"t5").get_global_rect()),
		"portrait: choosing a tab past the edge scrolls it into the strip (%s in %s)"
		% [page.tab_button(&"t5").get_global_rect(), page._rail_scroll.get_global_rect()])
	await _size(844, 390)
	await frames(3)
	spill = 0
	for i in 6:
		var button := page.tab_button(StringName("t%d" % i))
		var words: Label = button.find_children("*", "Label", true, false)[0]
		if not button.get_global_rect().grow(0.5).encloses(words.get_global_rect()): spill += 1
	check(spill == 0, "landscape: a wrapped rail label stays inside its tab (%d spills)" % spill)
	await _icon_rows()
	page.queue_free()
	await frames(2)


## A pinned part taller than the screen for a moment grows the card (the engine's minimum); once it is gone the card
## fits the usable area again by itself, and an idle page does not lay itself out every frame.
func _card_follows_content() -> void:
	# The game's case: a page built and shown for the first time on a narrow portrait screen — before its first layout
	# the tabs stand in the build-time row and ask for a tall card (measured 796 dp at 320×640).
	await _size(320, 640)
	var page := GoPage.new()
	page.open("Fresh")
	var tabs: Array[Dictionary] = []
	for i in 6:
		tabs.append({id = StringName("f%d" % i), label = "Category name %d long" % i, icon = GoIconSet.USER})
	page.set_tabs(tabs)
	for i in 30: page.body.add_child(GoStyle.label("Row %d" % i))
	root.add_child(page)
	await frames(1)
	var first := page.surface.card.size.y
	await frames(4)
	var area := GoSafeArea.usable_rect(page.surface.get_window())
	check(_fills(page.surface.card.get_global_rect(), area),
		"a page first shown in portrait fits the screen once laid out (%.0f → %.0f, area %.0f)"
		% [first, page.surface.card.size.y, area.size.y])
	var laid := 0
	for i in 6:
		await frames(1)
		if page.surface._layout_dirty: laid += 1
	check(laid == 0, "an idle page is not marked for layout frame after frame (%d of 6)" % laid)
	page.queue_free()
	await _size(390, 844)
	await frames(2)


## A glyph icon (a Label marked `go_no_wrap`) never wraps on the rail and sits level with its words, in both orientations.
func _icon_rows() -> void:
	# 🔤 An icon-**font** set — its glyphs are `Label`s (a texture set draws TextureRects, which no label rule touches).
	#    The wide ones (two-cell volume / eye shapes in a host's font) are the ones that wrapped.
	var glyphs := GoIconSet.new()
	var points: Dictionary[StringName, int] = {&"volume": 0x1F50A, &"eye": 0x1F441, &"crown": 0x265B, &"check": 0x2713}
	glyphs.codepoints = points
	GoUi.config.icons = glyphs
	var page := GoPage.new()
	root.add_child(page)
	page.open("Icons")
	var tabs: Array[Dictionary] = []
	var icons: Array[StringName] = [&"volume", &"eye", &"crown", &"check"]
	for i in icons.size():
		tabs.append({id = StringName("i%d" % i), label = "Tab %d" % i, icon = icons[i]})
	page.set_tabs(tabs)
	for shape: Vector2i in [Vector2i(844, 390), Vector2i(390, 844)]:
		await _size(shape.x, shape.y)
		await frames(3)
		var wrapped := 0
		var drawn := 0
		var off := 0.0
		for i in icons.size():
			var button := page.tab_button(StringName("i%d" % i))
			for words in button.find_children("*", "Label", true, false):
				if not words.has_meta(&"go_icon"): continue
				drawn += 1
				if (words as Label).autowrap_mode != TextServer.AUTOWRAP_OFF: wrapped += 1
				var title: Label = null
				for other in button.find_children("*", "Label", true, false):
					if not other.has_meta(&"go_icon"): title = other
				off = maxf(off, absf(words.get_global_rect().get_center().y - title.get_global_rect().get_center().y))
		check(drawn == icons.size() and wrapped == 0 and off <= 1.0,
			"%s: tab glyphs never wrap and sit level with their words (%d glyphs · %d wrapped · %.1f px off)"
			% ["landscape" if shape.x > shape.y else "portrait", drawn, wrapped, off])
	page.queue_free()
	GoUi.config.icons = null
	await frames(2)


# ── Rail in landscape, top tabs in portrait; the preview ───────────────

func _orientation_and_preview() -> void:
	var page := GoPage.new()
	root.add_child(page)
	page.open("Layout")
	page.set_tabs(_tabs_spec())
	page.body.add_child(GoStyle.label("content"))
	var stage := ColorRect.new()
	stage.name = "Stage"
	page.set_preview(stage)
	await _size(390, 844)
	var rail := page._rail_scroll.get_global_rect()
	var preview := page._preview_slot.get_global_rect()
	var content := page._content_holder.get_global_rect()
	check(not page.is_landscape(), "390×844 lays out for portrait")
	check(rail.end.y <= preview.position.y + 0.5 and preview.end.y <= content.position.y + 0.5,
		"portrait: tabs on top, then the preview band, then the content (%s · %s · %s)" % [rail, preview, content])
	check(rail.size.x > rail.size.y, "portrait: the tabs run along the top")
	var one := page.tab_button(&"one").get_global_rect()
	var two := page.tab_button(&"two").get_global_rect()
	check(absf(one.position.y - two.position.y) < 0.5 and two.position.x > one.position.x,
		"portrait: the tabs sit side by side (%s · %s)" % [one, two])
	check(stage.get_parent() == page._preview_slot and stage.is_visible_in_tree(), "the preview is shown in its slot")

	await _size(844, 390)
	rail = page._rail_scroll.get_global_rect()
	preview = page._preview_slot.get_global_rect()
	content = page._content_holder.get_global_rect()
	check(page.is_landscape(), "844×390 lays out for landscape")
	check(rail.end.x <= preview.position.x + 0.5 and preview.end.x <= content.position.x + 0.5,
		"landscape: the rail on the left, the preview beside it, then the content (%s · %s · %s)" % [rail, preview, content])
	one = page.tab_button(&"one").get_global_rect()
	two = page.tab_button(&"two").get_global_rect()
	check(two.position.y > one.position.y and absf(one.position.x - two.position.x) < 0.5,
		"landscape: the tabs stack down the rail (%s · %s)" % [one, two])
	check(rail.size.x >= page.rail_min_width - 0.5 and rail.size.x <= page.rail_max_width + 0.5,
		"landscape: the rail width is within its bounds (%.0f)" % rail.size.x)
	var area := GoSafeArea.usable_rect(page.surface.get_window())
	check(_fills(page.surface.card.get_global_rect(), area), "landscape: the card still fills the safe area (%s vs %s · min %s)"
		% [page.surface.card.size, area.size, page.surface.card.get_combined_minimum_size()])

	page.set_preview(null)
	await frames(2)
	check(not page._preview_slot.visible and stage.get_parent() == null, "set_preview(null) hides the slot and lets go of the node")
	check(page._content_holder.get_global_rect().position.x < content.position.x,
		"without a preview the content takes its room")
	stage.free()
	page.set_scrolls(false)
	await frames(1)
	check(page.body.get_parent() == page._content_holder and not page._content_scroll.visible, "set_scrolls(false) unwraps the body")
	page.set_scrolls(true)
	await frames(1)
	check(GoScroll.containing(page.body) == page._content_scroll and page._content_scroll.visible
		and page._content_scroll._edge_frame.visible, "set_scrolls(true) puts the scroll back")
	page.close()
	page.queue_free()
	await _size(390, 844)
	section("portrait top tabs · landscape rail · preview placement · scrolls")


# ── Sub-page back; Escape and the back gesture close only the top page ─

func _back_and_stacking() -> void:
	var lower := GoPage.new()
	root.add_child(lower)
	var upper := GoPage.new()
	root.add_child(upper)
	lower.open("Lower")
	upper.open("Upper")
	await frames(3)
	check(GoBackPolicy.owners() == 2, "two open pages own the back gesture twice (%d)" % GoBackPolicy.owners())
	var backs := [0]
	upper.set_back(func() -> void: backs[0] += 1)
	check(upper.surface.back_button.visible, "set_back() shows the back button")
	upper.surface.back_button.pressed.emit()
	check(int(backs[0]) == 1 and upper.is_open(), "the back button runs the sub-page's back, the page stays open")
	upper.open("Upper again")
	check(not upper.surface.back_button.visible, "open() resets the back button")

	root.push_input(_cancel())
	await frames(2)
	check(not upper.is_open() and lower.is_open(), "one Escape closes only the top page")
	check(GoBackPolicy.owners() == 1, "the closed page released the back gesture (%d)" % GoBackPolicy.owners())
	upper.open("Upper")
	await frames(2)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(2)
	check(not upper.is_open() and lower.is_open(), "one Android back closes only the top page")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(2)
	check(not lower.is_open(), "the next back closes the page below")
	check(GoBackPolicy.owners() == 0 and quit_on_go_back, "every page closed → back ownership is 0 and quitting is back")
	lower.queue_free()
	upper.queue_free()
	await frames(2)
	section("set_back · Escape and back close only the top page")


func _ownership_after_free() -> void:
	var page := GoPage.new()
	root.add_child(page)
	page.open("Freed while open")
	await frames(2)
	check(GoBackPolicy.owners() == 1, "an open page holds the back gesture")
	page.queue_free()
	await frames(2)
	check(GoBackPolicy.owners() == 0, "a page freed while open gives the back gesture back (%d)" % GoBackPolicy.owners())
	section("ownership after queue_free")


# ── Right to left ──────────────────────────────────────────────────────

func _rtl() -> void:
	var before := TranslationServer.get_locale()
	var page := GoPage.new()
	root.add_child(page)
	page.open("RTL")
	page.set_tabs(_tabs_spec())
	page.body.add_child(GoStyle.label("content"))
	await _size(844, 390)
	var ltr_rail := page._rail_scroll.get_global_rect()
	var ltr_content := page._content_holder.get_global_rect()
	check(ltr_rail.position.x < ltr_content.position.x, "left to right: the rail is on the left")
	# The content scroll takes the shared panel edge where its column meets the card's right edge.
	var gutter := maxi(0, page.surface._content_padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	check(page._content_scroll._edge_frame != null and page._content_scroll._edge_gutter == gutter and gutter > 0,
		"left to right: the content scrollbar borrows the card's right padding (gutter %d of %d)"
		% [page._content_scroll._edge_gutter, gutter])
	TranslationServer.set_locale("ar")
	await frames(4)
	var rail := page._rail_scroll.get_global_rect()
	var content := page._content_holder.get_global_rect()
	check(rail.position.x > content.position.x,
		"right to left: the rail mirrors to the right (rail %.0f · content %.0f)" % [rail.position.x, content.position.x])
	check(page._content_scroll._edge_gutter == 0,
		"right to left landscape: the content column borders the rail — no padding to borrow (gutter %d)"
		% page._content_scroll._edge_gutter)
	await _size(390, 844)
	gutter = maxi(0, page.surface._content_padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	check(page._content_scroll._edge_gutter == gutter and gutter > 0,
		"right to left portrait: one column, the scrollbar borrows the right padding again (gutter %d of %d)"
		% [page._content_scroll._edge_gutter, gutter])
	await _size(844, 390)
	# 🛑 The page's own content mirrors too, not only its rail: the body sits in the content scroll's inset, which the
	#    scroll keeps physically left to right for its rail and margins — the body itself must follow the locale.
	var row := HBoxContainer.new()
	var lead := GoStyle.label("lead")
	var tail := GoStyle.label("tail")
	row.add_child(lead)
	row.add_child(tail)
	page.body.add_child(row)
	await frames(3)
	check(page.body.is_layout_rtl() and lead.get_global_rect().position.x > tail.get_global_rect().position.x,
		"right to left: the page body mirrors — a row's first child is on the right (body rtl %s · lead %.0f · tail %.0f)"
		% [page.body.is_layout_rtl(), lead.get_global_rect().position.x, tail.get_global_rect().position.x])
	var header := page.surface.header
	check(page.surface.close_button.get_global_rect().position.x < page.surface.title_label.get_global_rect().position.x,
		"right to left: the close button mirrors with the header (%s)" % header.get_global_rect())
	TranslationServer.set_locale(before)
	await frames(4)
	check(page._rail_scroll.get_global_rect().position.x < page._content_holder.get_global_rect().position.x,
		"back in left to right the rail returns to the left")
	page.close()
	page.queue_free()
	await _size(390, 844)
	section("right-to-left mirroring")


# ── Sub-pages: push / pop, back and Escape one level at a time ─────────

func _sub_pages() -> void:
	GoBackPolicy.reset(self)
	var page := GoPage.new()
	root.add_child(page)
	page.open("Stack")
	page.set_tabs(_tabs_spec())
	var row := GoStyle.button("About")
	row.name = "AboutRow"
	page.body.add_child(row)
	page.footer().add_child(GoStyle.button("Root action"))
	page.footer().visible = true
	await _size(844, 390)
	var depths: Array[int] = []
	page.depth_changed.connect(func(d: int) -> void: depths.append(d))
	var built := [0]
	var about_body: Array = [null]
	row.grab_focus()
	check(page.depth() == 0 and not page.surface.back_button.visible and page._rail_scroll.visible,
		"depth 0: no back button, the rail shows")
	check(page.surface.back_before_close, "a page's surface goes back before it closes (GoSurface.back_before_close)")
	var box := page.push("About", func(b: VBoxContainer) -> void:
		built[0] += 1
		about_body[0] = b
		b.add_child(GoStyle.label("Version 1")))
	await frames(2)
	check(int(built[0]) == 1 and about_body[0] == box, "push builds the sub-page once, on push, into the body it returns")
	check(page.depth() == 1 and depths == [1], "push → depth 1 and depth_changed(1) (%s)" % [depths])
	check(page.surface.title_label.text == "About" and page.surface.back_button.is_visible_in_tree(),
		"depth 1: the sub-page's title and the header's back button")
	check(not page._rail_scroll.visible and not page._content_scroll._edge_frame.visible and box.is_visible_in_tree(),
		"depth 1: the rail and the tab body step away, the sub-page body shows")
	check(not page.surface.footer.visible, "depth 1: the root's pinned footer steps away")
	check(GoScroll.containing(box) != null and GoScroll.containing(box) != page._content_scroll,
		"the sub-page body scrolls in its own scroll, like a tab body")
	check(GoBackPolicy.owners() == 1, "a push never takes the back gesture a second time (%d)" % GoBackPolicy.owners())
	check(page.sub_body() == box and page.sub_footer() != page.surface.footer, "sub_body / sub_footer are the level's")
	var level_one: Control = page._levels[0].root
	var deeper := page.push_key("deeper_key")
	await frames(2)
	check(page.depth() == 2 and not level_one.visible and deeper.is_visible_in_tree(),
		"push again → depth 2, the level under it hides")
	check(page.surface.title_label.text == "deeper_key"
		and page.surface.title_label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_ALWAYS, "push_key titles by key")
	root.push_input(_cancel())
	await frames(3)
	check(page.depth() == 1 and page.is_open() and page.surface.title_label.text == "About" and level_one.visible,
		"Escape pops one level (depth 2 → 1), the page stays open")
	check(not is_instance_valid(deeper), "a popped sub-page is freed")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	check(page.depth() == 0 and page.is_open() and page.surface.title_label.text == "Stack",
		"the Android back pops the last level, the page's own title is back")
	check(page._rail_scroll.visible and page._content_scroll._edge_frame.visible and page.surface.footer.visible
		and not page.surface.back_button.visible, "depth 0 again: rail, tab body and footer back, no back button")
	check(get_root().gui_get_focus_owner() == row, "focus returns to the control that pushed (%s)" % get_root().gui_get_focus_owner())
	check(depths == [1, 2, 1, 0], "depth_changed traced every level (%s)" % [depths])
	# The header's back button and `request_back` (a voice "close") pop one level too.
	page.push("Again")
	await frames(1)
	page.surface.back_button.pressed.emit()
	await frames(2)
	check(page.depth() == 0 and page.is_open(), "the header's back button pops one level")
	page.push("Again")
	await frames(1)
	page.surface.request_back()
	await frames(2)
	check(page.depth() == 0 and page.is_open(), "request_back() pops one level")
	page.surface.request_back()
	await frames(2)
	check(not page.is_open(), "request_back() at depth 0 closes the page")
	# Closing from a sub-page closes the whole page; it opens on its own level next time.
	page.open("Stack")
	page.push("One")
	page.push("Two")
	await frames(1)
	page.surface.close_button.pressed.emit()
	await frames(2)
	check(not page.is_open() and page.depth() == 0, "the close button at depth 2 closes the whole page and pops every level")
	page.open("Stack")
	await frames(2)
	check(page.depth() == 0 and page._content_scroll._edge_frame.visible, "reopened on its own level")
	page.push("Tab switch")
	page.select_tab(&"two")
	await frames(2)
	check(page.depth() == 0 and page.current_tab() == &"two", "select_tab pops back to the page's level first")
	check(GoBackPolicy.owners() == 1, "still one back-gesture owner (%d)" % GoBackPolicy.owners())
	page.close()
	await frames(2)
	check(GoBackPolicy.owners() == 0, "closed: back-gesture owners 0 (%d)" % GoBackPolicy.owners())
	page.queue_free()
	await _size(390, 844)
	await frames(2)
	section("sub-pages · push / pop · Escape and back one level · focus · close from depth")


## The back button stands on the leading edge — left in left-to-right, right in right-to-left — and the sub-page body
## mirrors like a tab body.
func _sub_page_rtl() -> void:
	var before := TranslationServer.get_locale()
	var page := GoPage.new()
	root.add_child(page)
	page.open("RTL stack")
	page.set_tabs(_tabs_spec())
	await _size(844, 390)
	var box := page.push("Sub")
	var row := HBoxContainer.new()
	var lead := GoStyle.label("lead")
	var tail := GoStyle.label("tail")
	row.add_child(lead)
	row.add_child(tail)
	box.add_child(row)
	await frames(3)
	var back := page.surface.back_button.get_global_rect()
	var title := page.surface.title_label.get_global_rect()
	check(back.position.x < title.position.x, "left to right: back on the left of the title (%.0f · %.0f)" % [back.position.x, title.position.x])
	check(lead.get_global_rect().position.x < tail.get_global_rect().position.x, "left to right: the sub-page body runs left to right")
	TranslationServer.set_locale("ar")
	await frames(4)
	back = page.surface.back_button.get_global_rect()
	title = page.surface.title_label.get_global_rect()
	check(back.position.x > title.position.x, "right to left: back on the right, the leading edge (%.0f · %.0f)" % [back.position.x, title.position.x])
	check(box.is_layout_rtl() and lead.get_global_rect().position.x > tail.get_global_rect().position.x,
		"right to left: the sub-page body mirrors (lead %.0f · tail %.0f)" % [lead.get_global_rect().position.x, tail.get_global_rect().position.x])
	var gutter := maxi(0, page.surface._content_padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	check((page._levels[0].scroll as GoScroll)._edge_gutter == gutter,
		"right to left landscape, rail away: the sub-page's scrollbar borrows the right padding (%d of %d)"
		% [(page._levels[0].scroll as GoScroll)._edge_gutter, gutter])
	TranslationServer.set_locale(before)
	await frames(3)
	page.close()
	page.queue_free()
	await _size(390, 844)
	await frames(2)
	section("sub-pages right to left")


# ── Asking inside the page ─────────────────────────────────────────────

func _ask_into(page: GoPage, out: Array, destructive := false) -> void:
	out[0] = await page.confirm("Log out", "Log out of {who}?", "Log out", "Stay", "", {who = "Ana"}, destructive)


func _in_page_confirm() -> void:
	GoBackPolicy.reset(self)
	var page := GoPage.new()
	root.add_child(page)
	page.open("Account")
	await frames(2)
	var layers_before := root.find_children("*", "CanvasLayer", true, false).size()
	var out: Array = [null]
	_ask_into(page, out, true)
	await frames(2)
	var body_label := page.sub_body().get_node_or_null(^"ConfirmBody") as Label
	var ok := page.sub_footer().find_child("Confirm", true, false) as Button
	var cancel := page.sub_footer().find_child("Cancel", true, false) as Button
	check(page.depth() == 1 and page.surface.title_label.text == "Log out" and body_label != null
		and body_label.text == "Log out of Ana?", "confirm pushes a sub-page with the question, args filled")
	check(ok != null and cancel != null and ok.is_visible_in_tree() and cancel.is_visible_in_tree()
		and ok.text == "Log out" and cancel.text == "Stay", "[cancel] [confirm] in the sub-page's pinned row")
	var level_scroll := page._levels.back().scroll as GoScroll
	var footer_top := page.sub_footer().get_global_rect().position.y
	check(footer_top >= level_scroll.get_global_rect().end.y - 0.5,
		"the sub-page's pinned row sits below its scroll, never over the body's last line (row top %.1f · scroll end %.1f · bleed %d)"
		% [footer_top, level_scroll.get_global_rect().end.y, level_scroll.edge_bleed_bottom()])
	check(root.find_children("*", "CanvasLayer", true, false).size() == layers_before, "no new window (CanvasLayer) for the question")
	check(GoBackPolicy.owners() == 1, "the question takes no second back-gesture owner")
	ok.pressed.emit()
	await frames(2)
	check(out[0] == true and page.depth() == 0 and page.is_open(), "confirm → true, the question pops, the page stays")
	out[0] = null
	_ask_into(page, out)
	await frames(2)
	root.push_input(_cancel())
	await frames(3)
	check(out[0] == false and page.depth() == 0 and page.is_open(), "Escape on the question → false, back on the page")
	out[0] = null
	_ask_into(page, out)
	await frames(2)
	(page.sub_footer().find_child("Cancel", true, false) as Button).pressed.emit()
	await frames(2)
	check(out[0] == false and page.depth() == 0, "cancel → false")
	out[0] = null
	_ask_into(page, out)
	await frames(2)
	page.close()
	await frames(2)
	check(out[0] == false and not page.is_open(), "closing the page answers false")
	page.queue_free()
	await frames(2)
	section("in-page confirm")


func _hold() -> void:
	GoBackPolicy.reset(self)
	var page := GoPage.new()
	root.add_child(page)
	page.open("Settings")
	await frames(2)
	page.set_status_text("Saved settings", &"success")
	page.push("Contact")
	await frames(2)
	page.set_page_title("Settings · Ana")
	check(page.surface.title_label.text == "Contact", "set_page_title under a sub-page leaves the shown title alone")
	page.set_title("Contact us")
	check(page.surface.title_label.text == "Contact us", "set_title re-titles the level shown")
	var level_status := page.find_child("SubPageStatus", true, false) as VBoxContainer
	check(not page.surface.status.visible and level_status != null and not level_status.visible,
		"a sub-page hides the root's status row and starts with its own row hidden")
	page.set_status_text("Sending…")
	var status_text := level_status.get_node_or_null(^"StatusLineText") as Label
	check(level_status.visible and status_text != null and status_text.text == "Sending…"
		and page.surface.status_label.text == "Saved settings", "set_status_text fills the sub-page's own pinned row")
	page.clear_status()
	check(not level_status.visible, "clear_status hides it")
	page.hold(true)
	check(page.is_held() and page.surface.back_button.disabled and not page.surface.close_enabled,
		"hold: the back button and the ✕ are off")
	root.push_input(_cancel())
	await frames(3)
	page.surface.back_requested.emit()
	page.surface.request_close()
	await frames(2)
	check(page.depth() == 1 and page.is_open(), "held: Escape, back and ✕ leave the sub-page up")
	page.hold(false)
	check(not page.is_held() and not page.surface.back_button.disabled and page.surface.close_enabled,
		"hold(false) gives back and ✕ back")
	root.push_input(_cancel())
	await frames(3)
	check(page.depth() == 0 and page.is_open(), "released: Escape pops")
	check(page.surface.title_label.text == "Settings · Ana", "the last pop shows the page title set while it was under")
	check(page.surface.status.visible and page.surface.status_label.text == "Saved settings",
		"the last pop gives the root's status row back")
	page.clear_status()
	page.push("Contact")
	page.hold(true)
	check(page.pop() and page.depth() == 0 and page.surface.close_enabled and not page.surface.back_button.disabled,
		"a code pop of a held level releases the hold")
	page.surface.close_enabled = false
	page.push("Contact")
	page.hold(true)
	page.hold(false)
	check(not page.surface.close_enabled, "the hold restores close_enabled as it was (off stays off)")
	page.surface.close_enabled = true
	page.close()
	page.queue_free()
	await frames(2)
	section("sub-page status row · hold — a sub-page mid-send can't be left")


# ── Handing the screen to another window ───────────────────────────────

func _page_hand_over() -> void:
	GoBackPolicy.reset(self)
	var page := GoPage.new()
	root.add_child(page)
	var shop := GoPage.new()
	shop.layer = 20
	root.add_child(shop)
	page.open("Settings")
	var row := GoStyle.button("Buy")
	page.body.add_child(row)
	await frames(2)
	row.grab_focus()
	var closes := [0]
	page.closed.connect(func() -> void: closes[0] += 1)
	page.hand_over(func() -> void: shop.open("Shop"))
	check(not page.visible and page.is_handing_over() and shop.is_open(),
		"hand_over: the window opens and the page steps aside in the same frame")
	await frames(2)
	check(GoBackPolicy.owners() == 1 and int(closes[0]) == 0, "aside: only the window holds back, the page did not close (%d)"
		% GoBackPolicy.owners())
	check(GoSurface.path_count() == 2, "path: the shop open + the page aside (%d)" % GoSurface.path_count())
	var asked := GoSurface.close_requests()
	shop.surface.request_close()   # the player closes the shop (its ✕)
	await frames(3)
	check(GoSurface.close_requests() == asked + 1, "the ✕ counts as a close the player asked for")
	check(page.is_open() and not page.is_handing_over() and GoBackPolicy.owners() == 1,
		"the player closed the window → the page is back (owners %d)" % GoBackPolicy.owners())
	check(get_root().gui_get_focus_owner() == row, "focus back on the row that handed over")
	# 🔑 Times well above a frame: a software-rendered frame can take 50 ms+, so a wait of a few frames is not "short".
	page.hand_over(func() -> void: pass, 0.6)
	await frames(1)
	check(page.visible and not page.is_handing_over(), "waiting for the window: the page is still up")
	await create_timer(0.8).timeout
	await frames(1)
	check(page.is_open() and not page.is_handing_over(), "an action that opens nothing leaves the page where it is")
	# A window that opens late (a deferred call, a cached load) — the page waits for its open, not a frame count.
	page.hand_over(func() -> void: create_timer(0.6).timeout.connect(func() -> void: shop.open("Shop")), 1.5)
	await frames(1)
	check(page.visible and not page.is_handing_over(), "a late window: the page waits, still up")
	await create_timer(0.9).timeout
	await frames(1)
	check(not page.visible and page.is_handing_over() and shop.is_open(),
		"the late window opened → the page stepped aside then, in one transition")
	# The host's own way back in (its menu key again): `recall` asks the window to close as the player would.
	check(page.recall(), "recall() while aside asks the window to close")
	await frames(3)
	check(not shop.is_open() and page.is_open() and not page.is_handing_over() and int(closes[0]) == 0,
		"recall: the window closed (a player close) → the page is back, never closed")
	check(not page.recall(), "recall() with nothing handed over does nothing")
	# The window closes itself (its job done — no close asked for): the page stays closed, the player stays there.
	page.hand_over(func() -> void: shop.open("Shop"))
	await frames(2)
	shop.close()
	await frames(3)
	check(not page.is_open() and not page.is_handing_over() and int(closes[0]) == 1 and GoSurface.path_count() == 0,
		"a window that closed itself → the page gives up its way back (closed once, path %d)" % GoSurface.path_count())
	page.open("Settings")
	await frames(2)
	# The player moves on: a drawer opens while the page is away → the page closes for good.
	page.hand_over(func() -> void: shop.open("Shop"))
	var drawer := GoDrawer.new()
	root.add_child(drawer)
	drawer.open("Menu")
	await frames(2)
	check(not page.is_open() and int(closes[0]) == 2 and GoSurface.path_count() == 1,
		"a drawer opened while away → the page gives up its way back (closed once more, path %d)" % GoSurface.path_count())
	shop.close()
	drawer.close()
	await frames(3)
	check(not page.is_open() and GoBackPolicy.owners() == 0, "and stays closed (owners %d)" % GoBackPolicy.owners())
	drawer.queue_free()
	page.queue_free()
	shop.queue_free()
	await frames(2)
	section("page hand-over")


func _drawer_hand_over() -> void:
	GoBackPolicy.reset(self)
	var drawer := GoDrawer.new()
	drawer.close_when_surface_opens = true
	root.add_child(drawer)
	var settings := GoPage.new()
	root.add_child(settings)
	var shop := GoPage.new()
	shop.layer = 20
	root.add_child(shop)
	drawer.open("Menu")
	await frames(2)
	var closed := [0]
	drawer.closed.connect(func() -> void: closed[0] += 1)
	drawer.hand_over(func() -> void: settings.open("Settings"))
	check(drawer.is_handing_over() and not drawer.visible and not drawer.is_open() and settings.is_open(),
		"a tile's page opens and the drawer steps aside in the same frame (no slide-out)")
	await frames(2)
	check(GoBackPolicy.owners() == 1 and not GoSurface.is_any_held_open() and int(closed[0]) == 0,
		"aside: the page holds back, the drawer holds nothing and did not close")
	# A chain: the page hands over to a third window — the drawer waits for the whole chain.
	settings.hand_over(func() -> void: shop.open("Shop"))
	await frames(2)
	shop.surface.request_close()
	await frames(3)
	check(settings.is_open() and drawer.is_handing_over(), "the shop closed (✕) → the page is back, the drawer still waits")
	root.push_input(_cancel())
	await frames(3)
	check(not settings.is_open() and drawer.is_open() and drawer.visible and int(closed[0]) == 0,
		"Escape closes the page → the drawer is back where it was")
	check(GoBackPolicy.owners() == 1 and GoSurface.is_any_held_open(), "the drawer holds back again (%d)" % GoBackPolicy.owners())
	drawer.hand_over(func() -> void: pass, 0.0)
	check(not drawer.is_open() and int(closed[0]) == 1,
		"a tile that acts on the screen behind (wait 0) closes the drawer at once (its effect is behind)")
	await frames(2)
	check(GoBackPolicy.owners() == 0, "all closed: owners 0 (%d)" % GoBackPolicy.owners())
	drawer.open("Menu")
	await frames(2)
	drawer.hand_over(func() -> void: settings.open("Settings"))
	drawer.close()
	await frames(1)
	check(not drawer.is_handing_over() and int(closed[0]) == 2, "close() while aside gives up the way back (closed once)")
	settings.close()
	await frames(3)
	check(not drawer.is_open() and GoBackPolicy.owners() == 0, "and the page's close brings nothing back")
	# A window that opens late: the drawer stays up until it opens, then steps aside — one transition, not slide-then-pop.
	drawer.open("Menu")
	await frames(2)
	drawer.hand_over(func() -> void: create_timer(0.6).timeout.connect(func() -> void: settings.open("Settings")), 1.5)
	await frames(1)
	check(drawer.is_open() and drawer.visible and not drawer.is_handing_over(), "a late window: the drawer waits, still up")
	await create_timer(0.9).timeout
	await frames(1)
	check(drawer.is_handing_over() and not drawer.visible and settings.is_open() and int(closed[0]) == 2,
		"the late window opened → the drawer stepped aside then (never closed)")
	settings.surface.request_close()
	await frames(3)
	check(drawer.is_open() and drawer.visible, "the player closed it → the drawer is back")
	# Nothing opens within the wait: the drawer closes when it runs out.
	drawer.hand_over(func() -> void: pass, 0.6)
	await frames(1)
	check(drawer.is_open(), "waiting for a window that never comes: the drawer is still up")
	await create_timer(0.8).timeout
	await frames(1)
	check(not drawer.is_open() and int(closed[0]) == 3, "the wait ran out → the drawer closed (its effect is behind)")
	await frames(2)
	# A window that closes itself (its job done — a teleport made): the drawer does not pop back over the battle screen.
	drawer.open("Menu")
	await frames(2)
	drawer.hand_over(func() -> void: settings.open("Settings"))
	await frames(2)
	settings.close()
	await frames(3)
	check(not drawer.is_open() and not drawer.is_handing_over() and int(closed[0]) == 4 and GoBackPolicy.owners() == 0,
		"the page closed itself (no close asked for) → the drawer closes instead of coming back")
	drawer.queue_free()
	settings.queue_free()
	shop.queue_free()
	await frames(2)
	section("drawer hand-over")
