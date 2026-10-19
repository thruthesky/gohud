## 🧪 **GoPage checks** — the full-screen page: open/close, tabs, rail vs top tabs, preview, back, Escape and the
## back gesture on stacked pages, back-gesture ownership, safe-area fill, right-to-left mirroring.
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
	await _back_and_stacking()
	await _ownership_after_free()
	await _rtl()

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
	check(page.surface.card.get_global_rect().is_equal_approx(Rect2(area.position.round(), area.size.round())),
		"the card fills the safe area (%s vs %s)" % [page.surface.card.get_global_rect(), area])
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
	page.queue_free()
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
	check(page.surface.card.get_global_rect().size.is_equal_approx(area.size.round()), "landscape: the card still fills the safe area (%s vs %s · min %s)"
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
	check(page.body.get_parent() == page._content_scroll, "set_scrolls(true) puts the scroll back")
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
	TranslationServer.set_locale("ar")
	await frames(4)
	var rail := page._rail_scroll.get_global_rect()
	var content := page._content_holder.get_global_rect()
	check(rail.position.x > content.position.x,
		"right to left: the rail mirrors to the right (rail %.0f · content %.0f)" % [rail.position.x, content.position.x])
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
