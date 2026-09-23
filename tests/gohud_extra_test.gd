## 🧪 **Checks for the widgets that arrived later.** Runs alongside `gohud_test.gd`.
##
##   godot --headless --path <project> -s res://addons/gohud/tests/gohud_extra_test.gd
##
## ## 🔑 Why the file was split
## `gohud_test.gd` is over 2000 lines. If that one file grew with every widget added,
## ① several people would edit the same spot and clash often and ② finding where to look would get hard.
## **A different group gets its own file** — this one holds the later arrivals: snackbar, spinner, badge, table.
##
## ## 🛑 Widgets that move are measured with `reduce_motion`
## Measuring a position mid-animation gives an **in-between value** (measured 2026-09-16: the snackbar looked
## like it was 7dp off screen, when it was really still rising). To see the final position, turn motion off.
extends SceneTree

const ADDON := "res://addons/gohud"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	# 🛑 On a custom skin (cut panels), verdicts that assume corners and StyleBoxFlat lose their meaning. Measure on the default.
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true

	await _snackbar()
	await _dialogs_queue()
	await _spinner()
	await _badge()
	await _field()
	await _input_group()
	await _kbd()
	await _context_menu()
	await _popover()
	await _table()
	await _pagination()
	await _drawer()
	await _combobox()
	await _reward_calendar()
	await _cell_contract()
	await _charts()
	await _code_input()
	await _console()
	await _carousel()
	await _slot_grid()
	await _segmented_icons()
	await _slot_grid_followups()
	await _theme_color_lookup()
	await _segmented_theme_chain()
	await _surface_height_cap()
	await _hud_focus()
	await _tooltip_translation()
	await _item_card()
	await _list_row_selection()
	await _game_icons()
	await _theme_follow()
	await _list_lab()

	print("gohud extra tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func section(name: String) -> void:
	print("  %s %s" % ["ok  " if failed.is_empty() else "....", name])


func frames(count: int) -> void:
	for _i in count: await process_frame


# ── Snackbar ──────────────────────────────────────────────────────────

func _snackbar() -> void:
	var snack := GoSnackbar.new()
	root.add_child(snack)
	await frames(2)
	var card: PanelContainer = snack.get_node(^"SnackbarLayer/SnackbarRoot/Snackbar")
	var area := GoSafeArea.usable_rect(root)
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN))

	snack.show_text("저장했습니다", GoTheme.SUCCESS)
	await frames(4)
	check(card.visible, "snackbar: it appears")
	# 🛑 It **never goes off screen** — inside the safe area, lifted by the margin.
	check(card.position.y + card.size.y <= area.end.y - edge + 1.0,
		"snackbar: stays on screen (%.0f + %.0f ≤ %.0f)" % [card.position.y, card.size.y, area.end.y - edge])
	check(card.position.y > area.size.y * 0.5, "snackbar: appears at the bottom")
	# 🛑 Its height **equals the minimum** — freeze a value measured before the width is known and the card grows fourfold.
	check(is_equal_approx(card.size.y, card.get_combined_minimum_size().y),
		"snackbar: height = minimum height (%.0f · %.0f)" % [card.size.y, card.get_combined_minimum_size().y])
	check(card.size.x <= snack.max_width + 1.0, "snackbar: keeps to the maximum width")
	check(card.mouse_filter != Control.MOUSE_FILTER_IGNORE or not snack.tap_to_dismiss,
		"snackbar: takes input while tap-to-dismiss is on")

	# Placed at the top
	snack.dismiss()
	await frames(3)
	snack.placement = GoSnackbar.Placement.TOP
	snack.show_text("위")
	await frames(4)
	check(is_equal_approx(card.position.y, area.position.y + edge), "snackbar: TOP placement (%.0f)" % card.position.y)
	snack.placement = GoSnackbar.Placement.BOTTOM

	# Buttons — undo
	snack.clear()
	await frames(3)
	var log: Array[String] = []
	var picked := [-99]
	_ask_snack(snack, log, picked)
	await frames(4)
	var buttons: Array[String] = []
	for node in _all(card):
		if node is Button and not (node is GoIconButton): buttons.append((node as Button).text)
	check(buttons == ["되돌리기"], "snackbar: a button attaches (%s)" % str(buttons))
	check(card.mouse_filter == Control.MOUSE_FILTER_STOP, "snackbar: with a button it takes input")
	for node in _all(card):
		if node is Button and (node as Button).text == "되돌리기": (node as Button).pressed.emit()
	await frames(3)
	check(picked[0] == 0, "snackbar: the index of the pressed button comes back (%d)" % picked[0])
	check(log.has("되돌림"), "snackbar: the button's callback is called")
	# 🛑 Undo is the button this widget exists for — even as `Tone.BARE` it must keep the touch minimum.
	for node in _all(card):
		var action := node as Button
		if action != null and action.text == "되돌리기":
			check(action.custom_minimum_size.y >= float(GoUi.metric(GoTheme.TOUCH)) - 0.5,
				"snackbar: the button keeps the touch minimum (%.0f)" % action.custom_minimum_size.y)

	# Queue — post three in a row and one shows while two wait
	snack.clear()
	await frames(3)
	snack.show_text("첫째"); snack.show_text("둘째"); snack.show_text("셋째")
	await frames(2)
	check(snack.is_showing() and snack.pending() == 2, "snackbar: they queue up (waiting %d)" % snack.pending())

	# Identical text counts once — for when a dropped server pours out the same error
	snack.clear()
	await frames(3)
	snack.show_text("연결 실패"); snack.show_text("연결 실패"); snack.show_text("연결 실패")
	await frames(2)
	check(snack.pending() == 0, "snackbar: identical text counts as one (waiting %d)" % snack.pending())

	# A notice with no buttons lets input through — the game must not stall
	snack.clear()
	await frames(3)
	snack.tap_to_dismiss = false
	snack.show_text("통과")
	await frames(4)
	check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "snackbar: a plain notice lets input through")
	check(card.accessibility_name == "통과", "snackbar: screen-reader name (%s)" % card.accessibility_name)
	# 🪟 Changing container alpha **must not lose the tone-coloured border.**
	# 🛑 Drop the colour where the panel is re-applied and a raised danger notice loses its border — on screen that
	#    only looks like "a little paler", which is hard to notice (2026-09-16: the `alpha` setter really did this).
	snack.show_text("Danger", GoTheme.DANGER)
	await frames(2)
	var toned := snack._card.get_theme_stylebox(&"panel")
	var tone_edge: Color = toned.get(&"border_color") if &"border_color" in toned else Color.TRANSPARENT
	snack.alpha = 0.5
	await frames(1)
	var after := snack._card.get_theme_stylebox(&"panel")
	var after_edge: Color = after.get(&"border_color") if &"border_color" in after else Color.TRANSPARENT
	check(absf(GoSkin.box_background(after).a - 0.5) < 0.02,
		"snackbar: alpha reaches the panel (%.2f)" % GoSkin.box_background(after).a)
	check(tone_edge.a <= 0.0 or absf(after_edge.r - tone_edge.r) < 0.02,
		"snackbar: changing alpha leaves the tone border alone")
	snack.alpha = -1.0

	snack.queue_free()
	await frames(1)
	section("snackbar")

func _ask_snack(snack: GoSnackbar, log: Array[String], out: Array) -> void:
	out[0] = await snack.post({"text": "아이템을 버렸습니다", "tone": GoTheme.WARNING, "seconds": 0.0,
		"actions": [{"text": "되돌리기", "action": func() -> void: log.append("되돌림")}]})


# ── Dialog queue ──────────────────────────────────────────────────────

## 🛑 **Notices are never dropped; questions are.** Swap those two and it goes wrong either way —
##    drop a notice and an error message vanishes silently; queue a question and the user presses
##    "yes" without knowing what they are answering.
func _dialogs_queue() -> void:
	var dialogs := GoDialogs.new()
	root.add_child(dialogs)
	await frames(2)

	# An overlapping question returns false at once — the caller learns it "could not ask".
	dialogs._open = true
	var refused: bool = await dialogs.confirm("A", "B")
	check(not refused, "dialog: while one is up, a second confirm returns false at once")
	check(dialogs.pending() == 0, "dialog: a refused question does not queue")
	dialogs._open = false

	# Three notices in a row are all shown.
	var seen: Array[String] = []
	_say(dialogs, "첫", seen); _say(dialogs, "둘", seen); _say(dialogs, "셋", seen)
	await frames(2)
	check(dialogs.is_open() and dialogs.pending() == 2, "dialog: notices queue up (waiting %d)" % dialogs.pending())
	for _i in 3:
		dialogs._finish(true)
		await frames(2)
	check(seen.size() == 3 and seen[0] == "첫" and seen[2] == "셋",
		"dialog: all three notices are shown in turn (%s)" % str(seen))

	# 🛑 Release the code that is waiting when the screen goes away — otherwise it never comes back.
	var stranded: Array[String] = []
	_say(dialogs, "버려짐", stranded)
	await frames(2)
	check(dialogs.is_open(), "dialog: it is up")
	dialogs.queue_free()
	await frames(3)
	check(stranded.size() == 1, "dialog: leaving the tree releases the waiting await")
	section("dialogs queue")


func _say(dialogs: GoDialogs, words: String, log: Array[String]) -> void:
	await dialogs.alert(words, "body")
	log.append(words)


# ── Spinner ───────────────────────────────────────────────────────────

func _spinner() -> void:
	# Check that it only turns while motion is on.
	GoUi.config.reduce_motion = false
	var spinner := GoSpinner.new()
	root.add_child(spinner)
	await frames(2)
	check(spinner.is_processing(), "spinner: it turns")
	spinner.visible = false
	await frames(1)
	# 🛑 It does not turn while out of sight — a hidden spinner redrawing every frame throws that work away.
	check(not spinner.is_processing(), "spinner: hidden, it stops")
	spinner.visible = true
	await frames(1)
	GoUi.config.reduce_motion = true
	GoUi.refresh()
	await frames(1)
	# ♿ For someone who turned rotation off it **does not turn, but does not freeze either** — three dots flow in brightness.
	#    Stopping outright would be indistinguishable from a "dead screen".
	check(spinner.is_processing(), "spinner: the dots still flow under reduce_motion")

	var button := GoStyle.button("구매")
	root.add_child(button)
	await frames(2)
	var before := button.size
	GoSpinner.busy(button, true)
	await frames(2)
	check(GoSpinner.is_busy(button) and button.disabled, "spinner: busy locks the button")
	var busy_spinner := button.get_node_or_null(^"BusySpinner") as Control
	check(busy_spinner != null, "spinner: it turns inside the button")
	# 🛑 **Is it really inside the button.** The anchor is centred, so adding the parent size on top of that flings it
	#    outside and leaves an empty button with the label gone (found in the 2026-09-16 shots).
	if busy_spinner != null:
		var spin_rect := Rect2(busy_spinner.global_position, busy_spinner.size)
		var host_rect2 := Rect2(button.global_position, button.size)
		check(host_rect2.encloses(spin_rect),
			"spinner: it sits inside the button (spinner %s · button %s)" % [str(spin_rect), str(host_rect2)])
	check(button.get_theme_color(&"font_disabled_color").a <= 0.01, "spinner: it hides the label")
	GoSpinner.busy(button, true)   # called twice, still only one
	await frames(1)
	var spinners := 0
	for node in button.get_children():
		if node is GoSpinner: spinners += 1
	check(spinners == 1, "spinner: applied twice, still one (%d)" % spinners)
	GoSpinner.busy(button, false)
	await frames(2)
	check(not GoSpinner.is_busy(button) and not button.disabled, "spinner: clearing busy brings the button back")
	# 🛑 **Erase** the hidden font colour — leave it and a genuinely disabled button later looks like an empty panel.
	check(not button.has_theme_color_override(&"font_disabled_color"), "spinner: it restores the hidden font colour")
	spinner.queue_free(); button.queue_free()
	await frames(1)
	section("spinner")


# ── Badge ─────────────────────────────────────────────────────────────

func _badge() -> void:
	var badge := GoBadge.make(5)
	root.add_child(badge)
	await frames(2)
	check(badge.visible and _first_label(badge) == "5", "badge: it writes the number")
	badge.set_count(0)
	await frames(1)
	check(not badge.visible, "badge: at 0 it hides")
	badge.set_count(500)
	await frames(1)
	# 🛑 Without folding, "1284" grows wider than the icon and pushes the HUD row over.
	check(_first_label(badge) == "99+", "badge: it folds large numbers (%s)" % _first_label(badge))
	badge.dot = true
	await frames(1)
	check(badge.custom_minimum_size.x > 0 and _first_label(badge) == "", "badge: dot mode")
	# 🛑 A dot means "the count is hidden", not "there is none" — read as `empty` it says the opposite.
	check(not badge.accessibility_name.contains(GoUi.text(&"empty")),
		"badge: the dot does not read as 'empty' ('%s')" % badge.accessibility_name)

	var host := GoStyle.button("우편함")
	root.add_child(host)
	await frames(2)
	var one := GoBadge.attach(host, 3)
	await frames(1)
	check(one != null and one.get_parent() == host, "badge: it attaches")
	check(GoBadge.attach(host, 4) == one, "badge: attaching twice still gives one")
	# 🛑 It **straddles** the top-right corner — fully inside it covers the icon, fully outside it looks detached.
	#    The anchor is already top-right, so adding the parent width on top of that flings it a whole width away (found in the 2026-09-16 shots).
	var badge_rect := Rect2(one.global_position, one.size)
	var host_rect := Rect2(host.global_position, host.size)
	check(host_rect.intersects(badge_rect),
		"badge: it straddles the parent's corner (badge %s · parent %s)" % [str(badge_rect), str(host_rect)])
	check(badge_rect.get_center().x > host_rect.get_center().x and badge_rect.get_center().y < host_rect.get_center().y,
		"badge: it is the top-right corner")
	GoBadge.detach(host)
	await frames(1)
	check(not host.has_meta(&"gohud_badge"), "badge: it detaches")
	badge.queue_free(); host.queue_free()
	await frames(1)
	section("badge")


# ── Form row ──────────────────────────────────────────────────────────

func _field() -> void:
	var edit := GoStyle.line_edit("2~12자")
	var field := GoField.make("캐릭터 이름", edit, "나중에 바꿀 수 없습니다")
	root.add_child(field)
	await frames(2)
	check(field.label.text == "캐릭터 이름" and field.hint_label.visible, "form row: label and hint")
	check(not field.error_label.visible, "form row: no error at first")
	check(edit.accessibility_name.contains("캐릭터 이름"), "form row: the label reaches the screen reader")

	field.set_error("이미 쓰는 이름입니다")
	await frames(1)
	check(field.has_error() and field.error_label.visible, "form row: the error appears")
	# 🔑 Hint and error never fight for the same space — stacked, every field below gets pushed down.
	check(not field.hint_label.visible, "form row: the hint hides once the error appears")
	# ♿ Colour alone is not readable — the error text goes into the screen-reader name as well.
	check(edit.accessibility_name.contains("이미 쓰는"), "form row: the error reaches the screen reader")
	check(edit.has_theme_stylebox_override(&"normal"), "form row: the field border takes the tone too")

	field.clear_error()
	await frames(1)
	check(not field.has_error() and field.hint_label.visible, "form row: clearing the error brings the hint back")
	check(not edit.has_theme_stylebox_override(&"normal"), "form row: the border comes back too")
	field.queue_free()
	await frames(1)
	section("field")


# ── Joined input group ────────────────────────────────────────────────

func _input_group() -> void:
	var input := GoStyle.line_edit("메시지")
	var send := GoStyle.button("보내기")
	var group := GoInputGroup.make(input, {"suffix": send})
	root.add_child(group)
	await frames(3)
	check(group.get_theme_constant(&"separation") == 0, "input group: zero separation")
	var left: StyleBox = input.get_theme_stylebox(&"normal")
	var right: StyleBox = send.get_theme_stylebox(&"normal")
	# 🛑 Only the touching inner corners go square — two pairs of round corners meeting look pinched.
	if &"corner_radius_top_left" in left:
		check(float(left.get(&"corner_radius_top_left")) > 0.0 and float(left.get(&"corner_radius_top_right")) == 0.0,
			"input group: the leading part is round on the outside only")
		check(float(right.get(&"corner_radius_top_right")) > 0.0 and float(right.get(&"corner_radius_top_left")) == 0.0,
			"input group: the trailing part is round on the outside only")
	else:
		# A cut skin has no corner fields — leaving them alone is the correct behaviour.
		check(true, "input group: on a cut skin the corners are left alone")
	var marked := GoInputGroup.make(GoStyle.line_edit("이름"), {"prefix_icon": &"search"})
	root.add_child(marked)
	await frames(2)
	check(marked.prefix != null, "input group: an icon mark attaches")
	group.queue_free(); marked.queue_free()
	await frames(1)
	section("input group")


# ── Key caps ──────────────────────────────────────────────────────────

func _kbd() -> void:
	var keys := GoKbd.make("Ctrl", "S")
	root.add_child(keys)
	await frames(2)
	check(keys.keys().size() == 2, "kbd: two keys in the combo")
	check(keys.get_child_count() == 3, "kbd: cap + joiner + cap")
	check(keys.accessibility_name == "Ctrl + S", "kbd: it reads as one phrase (%s)" % keys.accessibility_name)
	# 🛑 A key name is not a word but the **symbol engraved on the key** — `Ctrl` must not split into `Ctr`/`l`.
	var cap_label := (keys.get_child(0) as Control).get_child(0) as Label
	check(cap_label != null and cap_label.get_line_count() == 1,
		"kbd: the key name stays on one line (%d lines)" % (cap_label.get_line_count() if cap_label else -1))
	# 🛑 A phone has no keyboard — on a handheld it hides itself.
	check(keys.visible != GoUi.is_handheld_platform(), "kbd: it hides on a handheld")
	keys.set_keys([])
	await frames(1)
	check(not keys.visible, "kbd: an empty key hides")
	# An unbound action gives an empty cap — it does not print a word like "none".
	var absent := GoKbd.for_action(&"gohud_probe_missing_action")
	root.add_child(absent)
	await frames(1)
	check(not absent.visible, "kbd: an unbound action hides")
	keys.queue_free(); absent.queue_free()
	await frames(1)
	section("kbd")


# ── Long-press menu ───────────────────────────────────────────────────

func _context_menu() -> void:
	var slot := GoSlot.new()
	root.add_child(slot)
	await frames(2)
	GoContextMenu.attach(slot, [{"text": "사용"}, {"separator": true}, {"text": "버리기", "danger": true}])
	check(slot.has_meta(&"gohud_context_menu"), "context menu: it attaches")
	var popup := GoContextMenu.open_at(slot, [{"text": "귓속말"}, {"text": "차단", "disabled": true}])
	await frames(2)
	check(popup != null and popup.item_count == 2, "context menu: two items")
	check(popup.is_item_disabled(1), "context menu: a disabled item")
	# 🔑 For a list that differs with the situation — it is built as the menu opens.
	var live := GoContextMenu.open_at(slot, func() -> Array: return [{"text": "1"}, {"text": "2"}, {"text": "3"}])
	await frames(2)
	check(live != null and live.item_count == 3, "context menu: the list is built on every open")
	GoContextMenu.detach(slot)
	check(not slot.has_meta(&"gohud_context_menu"), "context menu: it detaches")
	slot.queue_free()
	await frames(1)
	section("context menu")


# ── Card that opens attached ──────────────────────────────────────────

func _popover() -> void:
	var anchor := GoStyle.button("슬롯")
	root.add_child(anchor)
	await frames(2)
	var body := GoStyle.label("불꽃의 검 — 공격력 +12")
	var first := GoPopover.open(anchor, body, {"title": "아이템"})
	await frames(3)
	check(first != null and GoPopover.is_open(), "popover: it opens")
	check(first.placement == GoSurface.Placement.ANCHOR and first.anchor_control == anchor, "popover: it attaches to the anchor")
	check(body.get_parent() == first.body, "popover: the content goes in")
	# 🔑 The scrim is transparent — the game screen being compared must not go dark.
	check(first.scrim_transparent, "popover: the scrim is transparent")
	# 🛑 One at a time — stacked, you cannot tell which slot each belongs to.
	var second := GoPopover.open(anchor, GoStyle.label("둘째"))
	await frames(3)
	check(second != null and not is_instance_valid(first), "popover: only one at a time")
	# 🛑 **All three ways of closing emit `close_requested`.** The docs recommend `await …close_requested`, so if
	#    `close()` or a re-open merely erased the layer without the signal, that `await` would never return (measured 2026-09-16).
	var signalled := [false]
	var watched := GoPopover.open(anchor, GoStyle.label("신호"))
	if watched != null: watched.close_requested.connect(func() -> void: signalled[0] = true)
	await frames(3)
	GoPopover.close()
	await frames(3)
	check(signalled[0], "popover: close() emits close_requested too")
	check(not GoPopover.is_open(), "popover: it closes")
	anchor.queue_free()
	await frames(1)
	section("popover")


# ── Table ─────────────────────────────────────────────────────────────

func _table() -> void:
	var rows := [[3, "다다", 9124], [1, "가가", 91240], [2, "나나", 500]]
	var table := GoTable.make([{"text": "순위", "width": 56}, {"text": "이름"}, {"text": "점수", "numeric": true}], rows)
	root.add_child(table)
	await frames(3)
	check(table.rows_box.get_child_count() == 3, "table: three rows")
	table.sort_by(2, false)
	await frames(2)
	var top := table.rows_box.get_child(0) as Button
	# 🛑 Compared as text, "9124" > "91240" — the score ranking flips entirely.
	check(top != null and top.accessibility_name.contains("91240"), "table: a numeric column sorts as numbers")
	var got := [-1]
	table.row_selected.connect(func(i: int) -> void: got[0] = i)
	top.pressed.emit()
	await frames(2)
	# The index of a picked row is its index in the **original data** (not its sorted position).
	check(got[0] == 1, "table: a picked row comes back with its original index (%d)" % got[0])
	table.sort_by(2, true)
	await frames(2)
	var first_asc := table.rows_box.get_child(0) as Button
	check(first_asc != null and first_asc.accessibility_name.contains("500"), "table: the direction flips")
	# 🛑 **Does the text really have a visible height.** Laid out first at width 0 with wrapping on, the minimum
	#    height freezes at 1dp: the screen keeps the panel while the text disappears entirely — with every value check passing.
	var cell_heights: Array[float] = []
	for node in _all(first_asc):
		if node is Label: cell_heights.append((node as Label).size.y)
	check(not cell_heights.is_empty() and cell_heights.min() > 4.0,
		"table: cell text has a visible height (shortest cell %.0f)" % (cell_heights.min() if not cell_heights.is_empty() else -1.0))
	# 🛑 **Never kill a `Control` cell handed in by the host** — rows are rebuilt on every sort and theme swap, and
	#    freeing the borrowed nodes there makes the next rebuild attach a dead node (measured 2026-09-16).
	var borrowed := GoStyle.label("빌려온 칸")
	var lend := GoTable.make([{"text": "A"}, {"text": "B"}], [[1, borrowed], [2, "글자"]])
	root.add_child(lend)
	await frames(3)
	lend.sort_by(0, false)
	await frames(3)
	check(is_instance_valid(borrowed), "table: a handed-in cell survives a sort")
	lend.set_rows([[3, borrowed]])
	await frames(3)
	check(is_instance_valid(borrowed), "table: a handed-in cell survives a row rebuild")
	# 🛑 The header row is pressed, so it must keep the touch minimum (`Tone.BARE` applies none).
	var header := lend.head.get_child(0) as Button
	check(header != null and header.custom_minimum_size.y >= float(GoUi.metric(GoTheme.TOUCH)) - 0.5,
		"table: the header button keeps the touch minimum (%.0f)" % (header.custom_minimum_size.y if header else -1.0))
	lend.queue_free(); borrowed.queue_free()
	table.queue_free()
	await frames(1)
	section("table")


# ── Pagination ────────────────────────────────────────────────────────

func _pagination() -> void:
	var moved := [-1]
	var pager := GoPagination.make(1, 12, func(p: int) -> void: moved[0] = p)
	root.add_child(pager)
	await frames(2)
	pager.set_page(5)
	await frames(2)
	check(pager.page() == 5 and moved[0] == 5, "pagination: it moves page")
	var numbers := pager._numbers()
	# 🔑 The current page sits in the middle and both ends remain — so you never lose where you were.
	check(numbers.has(1) and numbers.has(5) and numbers.has(12), "pagination: it folds to 1 … 5 … 12 (%s)" % str(numbers))
	pager.set_page(99)
	await frames(1)
	check(pager.page() == 12, "pagination: it does not run past the end")
	# 🛑 With an unknown page count it makes no numbers — it does not pretend to know what it does not.
	var endless := GoPagination.make(1, 0)
	root.add_child(endless)
	await frames(2)
	check(endless._numbers().is_empty(), "pagination: no numbers when the total is unknown")
	var more := GoPagination.more()
	root.add_child(more)
	await frames(2)
	check(more.get_child_count() == 1, "pagination: load-more is a single row")
	pager.queue_free(); endless.queue_free(); more.queue_free()
	await frames(1)
	section("pagination")


# ── Drawer ────────────────────────────────────────────────────────────

func _drawer() -> void:
	var drawer := GoDrawer.new()
	drawer.motion_seconds = 0.0
	root.add_child(drawer)
	await frames(2)
	drawer.open("가방")
	await frames(3)
	check(drawer.is_open() and drawer.visible, "drawer: it opens")
	check(drawer.panel.size.x <= drawer.max_width + 1.0, "drawer: width cap (%.0f)" % drawer.panel.size.x)
	check(is_equal_approx(drawer.panel.position.x, 0.0), "drawer: it sticks to the left")
	drawer.side = GoDrawer.Side.RIGHT
	drawer._relayout()
	await frames(2)
	var full := root.get_visible_rect()
	check(absf(drawer.panel.position.x + drawer.panel.size.x - full.size.x) < 2.0,
		"drawer: it sticks to the right (%.0f)" % (drawer.panel.position.x + drawer.panel.size.x))
	# 🛑 The background runs edge to edge while the content stays inside the safe area — nothing clipped at a corner.
	check(is_equal_approx(drawer.panel.size.y, full.size.y), "drawer: the panel runs to the screen edge")
	# 🪟 Container alpha — an `@export`, so it is a **percent**, and it reaches the panel as a **ratio**.
	# 🛑 There is no `near()` in this file — its only helper is `check`, so the difference is measured directly.
	var drawer_themed := GoSkin.box_background(drawer.panel.get_theme_stylebox(&"panel")).a
	check(absf(drawer_themed - GoUi.surface_alpha(GoTheme.BOX_CARD)) < 0.02,
		"drawer: by default it takes the card value theme and config set (%.2f)" % drawer_themed)
	drawer.alpha = 0.40
	await frames(1)
	check(absf(GoSkin.box_background(drawer.panel.get_theme_stylebox(&"panel")).a - 0.40) < 0.02,
		"drawer: ratio 0.40 → panel background 0.40")
	drawer.alpha = -1.0
	await frames(1)
	check(absf(GoSkin.box_background(drawer.panel.get_theme_stylebox(&"panel")).a - drawer_themed) < 0.02,
		"drawer: back to -1 returns the theme value")
	drawer.close()
	await frames(2)
	check(not drawer.is_open(), "drawer: it closes")
	# 🛑 Leaving the tree **puts the state down too** — otherwise re-adding and closing releases the back-button
	#    claim one more time and eats another window's claim with it.
	drawer.open("다시")
	await frames(2)
	var owners_open := GoBackPolicy.owners()
	root.remove_child(drawer)
	await frames(2)
	check(not drawer.is_open(), "drawer: leaving the tree puts the open state down too")
	check(GoBackPolicy.owners() == owners_open - 1, "drawer: it releases the back-button claim exactly once")
	root.add_child(drawer)
	await frames(2)
	drawer.queue_free()
	await frames(1)
	section("drawer")


# ── Search-and-pick field ─────────────────────────────────────────────

func _combobox() -> void:
	var items: Array = []
	for i in 30: items.append({"text": "플레이어%d" % i})
	var combo := GoCombobox.make(items, -1, "친구 찾기")
	root.add_child(combo)
	await frames(2)
	check(combo.text == "친구 찾기", "combobox: placeholder text")
	combo.select(3)
	await frames(1)
	check(combo.selected() == 3 and combo.selected_text() == "플레이어3", "combobox: it picks")
	combo._open()
	await frames(3)
	# With many items a search row appears.
	check(combo._search != null, "combobox: with many items a search row appears")
	combo._search.text = "플레이어1"
	combo._fill()
	await frames(2)
	# "플레이어1", "플레이어10"~"플레이어19" = 11 of them
	check(combo._rows.get_child_count() == 11, "combobox: it matches inside the text too (%d)" % combo._rows.get_child_count())
	combo._search.text = "없는이름"
	combo._fill()
	await frames(2)
	# 🛑 An empty list is not left as it is — it reads as a fault.
	check(combo._empty.visible, "combobox: it says so when there are no results")
	combo._close()
	await frames(1)
	var few := GoCombobox.make(["A", "B", "C"])
	root.add_child(few)
	await frames(2)
	few._open()
	await frames(2)
	check(few._search == null, "combobox: with few items there is no search row")
	few._close()
	combo.queue_free(); few.queue_free()
	await frames(1)
	section("combobox")


# ── Daily reward calendar ─────────────────────────────────────────────

func _reward_calendar() -> void:
	var days: Array = []
	for i in 7: days.append({"icon": &"coin", "amount": (i + 1) * 100, "special": i == 6})
	var cal := GoRewardCalendar.make(days, 1)
	root.add_child(cal)
	await frames(3)
	check(cal._grid.get_child_count() == 7, "rewards: seven cells")
	check(cal.today() == 2, "rewards: today is the third cell (%d)" % cal.today())
	var cells := cal._grid.get_children()
	# 🛑 A button that does nothing when pressed reads as a fault — only today's cell is pressable.
	check(not (cells[2] as Button).disabled, "rewards: today's cell is pressable")
	check((cells[0] as Button).disabled and (cells[6] as Button).disabled, "rewards: claimed and upcoming cells are not pressable")
	# ♿ Dimming alone does not tell a claimed day from one still to come.
	check((cells[0] as Button).accessibility_name != (cells[6] as Button).accessibility_name,
		"rewards: claimed and upcoming are told apart in words")
	var got := [-1]
	cal.claimed.connect(func(d: int) -> void: got[0] = d)
	(cells[2] as Button).pressed.emit()
	await frames(2)
	check(got[0] == 2, "rewards: the claim signal")
	# 🛑 **A real click** — `pressed.emit()` never asks whether the number, picture and amount laid over the cell let the
	#    press through to it, so content that swallowed input would still pass the line above.
	got[0] = -1
	var point := (cells[2] as Control).get_global_rect().get_center()
	for held in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = held
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		click.position = point
		click.global_position = point
		Input.parse_input_event(click.xformed_by(root.get_final_transform()))
		await frames(2)
	check(got[0] == 2, "rewards: a real click on today's cell reaches it through its content (%d)" % got[0])
	# 📐 The content sits inside the cell with room to spare — the preview had the day number on the top edge and the amount below the cell.
	var today_cell := cells[2] as Control
	var number := today_cell.find_children("*", "Label", true, false)[0] as Label
	var amount := today_cell.find_children("*", "Label", true, false)[-1] as Label
	var room := float(GoUi.metric(GoTheme.GAP_TINY))
	check(number.global_position.y - today_cell.global_position.y >= room,
		"rewards: the day number clears the top edge (%.1f)" % (number.global_position.y - today_cell.global_position.y))
	var bottom := today_cell.global_position.y + today_cell.size.y - (amount.global_position.y + amount.size.y)
	check(bottom >= room, "rewards: the amount stays inside the cell (%.1f from the bottom)" % bottom)
	check(is_equal_approx(today_cell.size.x, today_cell.size.y), "rewards: cells stay square (%s)" % today_cell.size)
	# 🛑 Every state keeps its face — only `normal`·`disabled` were set, and pressing today's cell showed the theme's empty face.
	var lit := (cells[2] as Button).get_theme_stylebox(&"normal")
	check((cells[2] as Button).get_theme_stylebox(&"pressed") == lit and (cells[2] as Button).get_theme_stylebox(&"hover") == lit,
		"rewards: today's cell keeps its face while hovered and pressed")
	cal.set_claimed_until(6)
	await frames(2)
	check(cal.today() == -1, "rewards: with everything claimed there is no today")
	cal.queue_free()
	await frames(1)
	section("reward calendar")


# ── Cell contract — content inside boxes that are not containers ──────

## 🔑 **Every cell-shaped widget, in every look, inside a form and out, on a phone strip and in RTL** — checked by the
## same audit. The preview the user pointed at (2026-09-23) had day numbers glued to the top of each reward cell and
## the amounts drawn below it: the gallery wraps everything in `GoStyle.form()`, which rewrote the cell's spacing to 12,
## and nothing measured where the content really ended up. `GoStyle.audit_cell_layout` measures it.
func _cell_contract() -> void:
	# 🧪 Positive controls first — an audit that catches nothing proves nothing.
	var host := Control.new()
	host.size = Vector2(400, 400)
	root.add_child(host)
	var cell := Button.new()
	cell.theme = GoUi.theme()
	cell.theme_type_variation = GoTheme.VAR_BARE_BUTTON
	cell.add_theme_stylebox_override(&"normal", GoUi.skin().slot_box(GoUi.color(GoTheme.ACCENT), true))
	host.add_child(cell)
	var body := GoStyle.cell_body(cell)
	for words in ["1", "×100"]: body.add_child(GoStyle.label(words, GoTheme.ROLE_MICRO))
	await frames(3)
	check(GoStyle.audit_cell_layout(host).is_empty(), "cells: a cell_body cell passes the audit %s" % str(GoStyle.audit_cell_layout(host)))
	var need := (cell.get_meta(&"go_cell_inset") as Control).get_combined_minimum_size()
	check(cell.size.x + 0.5 >= need.x and cell.size.y + 0.5 >= need.y, "cells: the box grows to its content (%s ≥ %s)" % [cell.size, need])
	# ① content that outgrew its box — checked before the deferred fit catches up, the moment a hand-built cell lives in forever
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(10, 400)
	body.add_child(tall)
	check(GoStyle.audit_cell_layout(host).size() >= 1, "cells: the audit catches content taller than its box")
	await frames(3)
	check(GoStyle.audit_cell_layout(host).is_empty(), "cells: the box grows to the taller content %s" % str(GoStyle.audit_cell_layout(host)))
	tall.queue_free()
	# ② padding thinner than the face needs
	var inset := cell.get_meta(&"go_cell_inset") as MarginContainer
	var top := inset.get_theme_constant(&"margin_top")
	inset.add_theme_constant_override(&"margin_top", 0)
	check(GoStyle.audit_cell_layout(host).size() >= 1, "cells: the audit catches padding thinner than the face")
	# ④ a one-line label folded, and a label cut short
	var folded := GoStyle.label("×100")
	folded.set_meta(&"go_no_wrap", true)
	folded.custom_minimum_size.x = 1
	folded.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(folded)
	await frames(2)
	var caught := GoStyle.audit_cell_layout(host)
	check(caught.any(func(line: String) -> bool: return line.contains("folds")), "cells: the audit catches a folded one-line label %s" % str(caught))
	folded.autowrap_mode = TextServer.AUTOWRAP_OFF
	folded.clip_text = true
	await frames(2)
	caught = GoStyle.audit_cell_layout(host)
	check(caught.any(func(line: String) -> bool: return line.contains("is cut")), "cells: the audit catches a label cut short %s" % str(caught))
	# ⑤ a badge hanging over the edge on purpose is not a problem
	folded.set_meta(&"go_overlay", true)
	inset.add_theme_constant_override(&"margin_top", top)
	await frames(2)
	check(GoStyle.audit_cell_layout(host).is_empty(), "cells: a go_overlay node is left out %s" % str(GoStyle.audit_cell_layout(host)))
	# ③ a mark centered by anchors alone — its top-left corner on the center
	var mark := ColorRect.new()
	mark.custom_minimum_size = Vector2(20, 20)
	var dot_host := Control.new()
	dot_host.size = Vector2(48, 48)
	host.add_child(dot_host)
	dot_host.add_child(mark)
	GoStyle.center_in(mark)
	await frames(2)
	var centered := GoStyle.audit_cell_layout(dot_host).is_empty()
	mark.set_anchors_preset(Control.PRESET_CENTER)
	mark.offset_left = 0; mark.offset_top = 0; mark.offset_right = 20; mark.offset_bottom = 20
	check(centered and GoStyle.audit_cell_layout(dot_host).size() == 1,
		"cells: center_in centers, and the audit catches the anchors-only mistake")
	host.queue_free()
	await frames(1)

	# The real widgets, in all six looks.
	var looks: Array[StringName] = [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT, GoThemePresets.SCIFI_DARK,
		GoThemePresets.SCIFI_LIGHT, GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]
	for look in looks:
		GoUi.use_preset(look)
		for in_form in [false, true]:
			for rtl in [false, true]:
				await _cell_page(look, in_form, rtl)
	# 🔤 An icon-**font** set: its glyphs are `Label`s, and a form turned wrapping on for them — in the gallery the crown
	#    grew from 24 to 51dp and made day 7's whole column and row larger than the rest (2026-09-23).
	var glyphs := GoIconSet.new()
	var points: Dictionary[StringName, int] = {&"coin": 0x25CF, &"crown": 0x265B, &"check": 0x2713, &"star": 0x2605}
	glyphs.codepoints = points
	GoUi.config.icons = glyphs
	await _cell_page(GoThemePresets.SCIFI_DARK, true, false)
	GoUi.config.icons = null
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await _cell_live_changes()
	section("cell contract")


## The same calendar through what happens to it on a live screen: the look swapped, the language swapped, a host's own cell size.
func _cell_live_changes() -> void:
	var days: Array = []
	for i in 7: days.append({"icon": &"coin", "amount": (i + 1) * 100})
	var calendar := GoRewardCalendar.make(days, 2)
	calendar.size = Vector2(700, 0)
	root.add_child(calendar)
	await frames(4)
	GoUi.use_preset(GoThemePresets.MEDIEVAL_LIGHT)
	await frames(4)
	check(GoStyle.audit_cell_layout(calendar).is_empty(), "cells: after a live look swap %s" % str(GoStyle.audit_cell_layout(calendar)))
	calendar.notification(NOTIFICATION_TRANSLATION_CHANGED)
	await frames(4)
	check(GoStyle.audit_cell_layout(calendar).is_empty(), "cells: after a language swap %s" % str(GoStyle.audit_cell_layout(calendar)))
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	for side in [30.0, 120.0]:
		calendar.cell_size = side
		await frames(4)
		var cell := calendar._grid.get_child(0) as Control
		check(GoStyle.audit_cell_layout(calendar).is_empty() and is_equal_approx(cell.size.x, cell.size.y)
			and cell.size.x >= maxf(side, GoUi.metric(GoTheme.TOUCH)) - 0.5,
			"cells: cell_size %d is a floor and the cell stays square (%s) %s" % [side, cell.size, str(GoStyle.audit_cell_layout(calendar))])
	calendar.queue_free()
	await frames(1)


func _cell_page(look: StringName, in_form: bool, rtl: bool) -> void:
	var tag := "%s%s%s" % [look, " · form" if in_form else "", " · rtl" if rtl else ""]
	var page := GoStyle.column()
	page.size = Vector2(700, 1400)
	page.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	root.add_child(page)
	var days: Array = []
	for i in 7: days.append({"icon": &"crown" if i == 6 else &"coin", "amount": (i + 1) * 100, "special": i == 6})
	var calendar := GoRewardCalendar.make(days, 2)
	page.add_child(calendar)
	# 📱 A phone (390 wide, minus the page padding) and a width that holds six cells but not seven.
	var strips: Array[GoRewardCalendar] = []
	for width in [350, 560]:
		var strip := GoStyle.column(0)
		strip.custom_minimum_size.x = width
		strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var fitted := GoRewardCalendar.make(days, 2)
		strip.add_child(fitted)
		page.add_child(strip)
		strips.append(fitted)
	var narrow := strips[0]
	var month: Array = []
	for i in 28: month.append({"icon": &"coin", "amount": 100000 if i == 27 else 50})
	page.add_child(GoRewardCalendar.make(month, 10))
	var table := GoTable.make([{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}],
		[[1, "Aria", 91240], [2, "Brin", 48210]])
	page.add_child(table)
	page.add_child(GoStyle.choice_grid([{"color": "e5484d"}, {"icon": GoIconSet.STAR, "text": "Star"}, "Plain"], 1))
	var carousel := GoCarousel.new()
	carousel.custom_minimum_size = Vector2(200, 80)
	carousel.set_pages([ColorRect.new(), ColorRect.new(), ColorRect.new()])
	page.add_child(carousel)
	var card := GoPromptCard.new()
	card.fade_in = false
	card.set_title("Party invite")
	card.set_icon(GoIconSet.STAR, Color.TRANSPARENT, true)
	page.add_child(card)
	card.show()
	if in_form: GoStyle.form(page)
	await frames(4)

	var problems := GoStyle.audit_cell_layout(page)
	check(problems.is_empty(), "cells [%s]: every cell holds its content inside its padding %s" % [tag, str(problems.slice(0, 3))])
	var audited := page.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node.has_meta(&"go_cell_inset")).size()
	# 7 + 7 + 7 + 28 reward cells and 2 table rows — the audit really looked at them.
	check(audited >= 51, "cells [%s]: the audit covered the cells (%d)" % [tag, audited])

	# 📱 Never wider than its strip: the row wraps sooner instead — and evenly, never one day left alone on a line.
	for fitted in strips:
		var width := (fitted.get_parent() as Control).custom_minimum_size.x
		var row_width := fitted._grid.get_combined_minimum_size().x
		var per_row := fitted._grid.columns
		var last := 7 - (ceili(7.0 / per_row) - 1) * per_row
		check(row_width <= width + 0.5 and last >= ceili(per_row / 2.0),
			"cells [%s]: the calendar fits %ddp in even rows (%.0fdp · %d a row · %d on the last)" % [tag, width, row_width, per_row, last])
	# Width **and** height — a tall glyph on day 7 once grew only its own row and column.
	var sides: Array[float] = []
	for child in narrow._grid.get_children():
		sides.append((child as Control).size.x)
		sides.append((child as Control).size.y)
	check(sides.min() >= GoUi.metric(GoTheme.TOUCH) - 0.5 and sides.max() - sides.min() <= 1.0,
		"cells [%s]: every reward cell is the same square and keeps the touch minimum (%.0f–%.0f)" % [tag, sides.min(), sides.max()])

	# Inside a form, the cell keeps its own spacing and one-line text.
	var first := calendar._grid.get_child(0)
	var cell_body := first.find_child("Body", true, false) as BoxContainer
	check(cell_body != null and cell_body.get_theme_constant(&"separation") == GoUi.metric(GoTheme.GAP_TINY),
		"cells [%s]: a cell keeps its own spacing" % tag)
	for node in first.find_children("*", "Label", true, false):
		var text := node as Label
		check(text.autowrap_mode == TextServer.AUTOWRAP_OFF and text.get_line_count() == 1,
			"cells [%s]: cell text stays on one line (%s)" % [tag, text.text])

	# ♿ Every number and amount reads on its face (4.5:1), in every state — no alpha dimming.
	for index in [0, 3, 5]:
		var day := calendar._grid.get_child(index) as Button
		check(is_equal_approx(day.modulate.a, 1.0), "cells [%s]: day %d is dimmed by color, not alpha" % [tag, index + 1])
		var face := day.get_theme_stylebox(&"disabled" if day.disabled else &"normal")
		var back := GoSkin.blend(GoSkin.box_background(face), GoUi.color(GoTheme.SURFACE_SOFT))
		# Text at 4.5:1. An icon-font glyph is a graphic (3:1) — and a claimed day's picture is dimmed on purpose under its
		# check mark, so there the check mark carries the 3:1.
		var marks: Array[float] = []
		for node in day.find_children("*", "Label", true, false):
			var ink := (node as Label).get_theme_color(&"font_color")
			var ratio := GoSkin.contrast_ratio(GoSkin.blend(ink, back), back)
			if node.has_meta(&"go_icon"):
				marks.append(ratio)
				continue
			check(ratio >= 4.5, "cells [%s]: day %d \"%s\" reads on its face (%.2f:1)" % [tag, index + 1, (node as Label).text, ratio])
		if not marks.is_empty():
			var needed: float = marks.max() if index <= 1 else marks.min()
			check(needed >= 3.0, "cells [%s]: day %d's glyphs stand out from the face (%.2f:1)" % [tag, index + 1, needed])
	page.queue_free()
	await frames(1)


# ── Radar · donut ─────────────────────────────────────────────────────

func _charts() -> void:
	var radar := GoRadar.make({"힘": 0.8, "민첩": 0.5, "지능": 0.3, "체력": 0.7, "행운": 0.4})
	root.add_child(radar)
	await frames(2)
	# ♿ A picture alone is not readable.
	check(radar.accessibility_name.contains("힘 80%"), "radar: the values go into words (%s)" % radar.accessibility_name)
	radar.set_values({"힘": 0.1})
	await frames(1)
	check(radar.accessibility_name.contains("10%"), "radar: changing a value follows through")

	var donut := GoDonut.make([{"label": "물리", "value": 620}, {"label": "마법", "value": 340}, {"label": "관통", "value": 90}])
	root.add_child(donut)
	await frames(2)
	check(is_equal_approx(donut.total(), 1050.0), "donut: total (%.0f)" % donut.total())
	check(donut.accessibility_name.contains("물리 59%"), "donut: the ratios go into words (%s)" % donut.accessibility_name)
	check(donut.legend().get_child_count() == 3, "donut: a three-row legend")
	# 🔑 Past five slices the rest are folded together — thread-thin slices cannot be read.
	var many: Array = []
	for i in 9: many.append({"label": "조각%d" % i, "value": 100 - i * 8})
	donut.set_slices(many)
	await frames(1)
	check(donut.visible_slices().size() == 5, "donut: it folds down to five (%d)" % donut.visible_slices().size())
	radar.queue_free(); donut.queue_free()
	await frames(1)
	section("radar · donut")


# ── Coupon code ───────────────────────────────────────────────────────

func _code_input() -> void:
	var coupon := GoCodeInput.make(12, 4)
	root.add_child(coupon)
	await frames(3)
	check(coupon._cells.size() == 12, "coupon: twelve cells")
	# 🛑 **The hidden input must cover the cells** so that tapping anywhere brings up the keyboard. Put straight
	#    into an `HBoxContainer` it is pushed out into its own column and tapping a cell never gives it focus (measured 2026-09-16).
	var cell_rect := Rect2(coupon._cells[0].global_position, coupon._cells[0].size)
	check(Rect2(coupon.edit.global_position, coupon.edit.size).encloses(cell_rect),
		"coupon: the hidden input covers the cells (edit %s · first cell %s)" % [str(coupon.edit.size), str(cell_rect)])
	# 🛑 Changing the digit count does not pile up the empty cells at the break positions.
	var children_before := coupon.cells_row.get_child_count()
	coupon.length = 8
	await frames(2)
	coupon.length = 12
	await frames(2)
	check(coupon.cells_row.get_child_count() == children_before,
		"coupon: changing the digit count does not pile up nodes (%d → %d)" % [children_before, coupon.cells_row.get_child_count()])
	# 🛑 **It fits a phone's width.** Holding 12 cells at a fixed width clipped them off a 720dp screen
	#    (2026-09-16 shots). When it is narrow, the cells have to narrow with it.
	var need := coupon.cells_row.get_combined_minimum_size().x + float(GoUi.metric(GoTheme.SCREEN_MARGIN)) * 2.0
	check(need <= 720.0, "coupon: it fits a 720dp phone width (%.0f)" % need)
	var done := [""]
	coupon.completed.connect(func(c: String) -> void: done[0] = c)
	# 🛑 A code is pasted, not typed by hand — hyphens and spaces fall away and it is upper-cased.
	coupon.edit.text = "abcd-efgh ijkl"
	coupon._on_text("abcd-efgh ijkl")
	await frames(2)
	check(coupon.code() == "ABCDEFGHIJKL", "coupon: it tidies up a paste (%s)" % coupon.code())
	check(done[0] == "ABCDEFGHIJKL", "coupon: it reports once full")
	check(coupon.is_complete(), "coupon: it is full")
	coupon.set_error("이미 쓴 코드입니다")
	await frames(2)
	check(coupon.has_error() and coupon.error_label.visible, "coupon: the error appears")
	coupon.clear()
	await frames(1)
	check(coupon.code().is_empty(), "coupon: it clears")
	# Characters it cannot take never get in.
	coupon._on_text("한글!@#AB")
	await frames(1)
	check(coupon.code() == "AB", "coupon: only acceptable characters are kept (%s)" % coupon.code())
	coupon.queue_free()
	await frames(1)
	section("code input")


# ── Developer console ─────────────────────────────────────────────────

func _console() -> void:
	var console := GoConsole.new()
	root.add_child(console)
	await frames(2)
	console.register("give", "아이템 지급", func(a: PackedStringArray) -> String: return "지급 %s" % " ".join(a))
	check(console.commands().has("give"), "console: a command registers")
	check(console.commands().has("help") and console.commands().has("clear"), "console: the built-in commands are there")
	check(console.run("give sword 3") == "지급 sword 3", "console: it runs a command")
	# 🔑 The built-in strings are English — the common tongue of dev tools, and the add-on code pins no single language.
	check(console.run("no_such_command").contains("unknown"), "console: it reports an unknown command")
	# 🛑 Blocking `open()` alone is useless — code can call `run()` directly.
	check(console.debug_only and OS.is_debug_build(), "console: this check runs in a debug build")
	console.unregister("give")
	check(not console.commands().has("give"), "console: a command unregisters")
	# 🛑 It does not open in a release build — cheats must not reach a player's hands.
	check(console.debug_only, "console: debug builds only by default")
	console.queue_free()
	await frames(1)
	section("console")


# ── Swipeable strip ───────────────────────────────────────────────────

func _carousel() -> void:
	var carousel := GoCarousel.new()
	carousel.custom_minimum_size = Vector2(300, 120)
	root.add_child(carousel)
	await frames(2)
	carousel.set_pages([GoStyle.card(), GoStyle.card(), GoStyle.card()])
	await frames(3)
	check(carousel.pages().size() == 3, "carousel: three pages")
	check(carousel._dots.get_child_count() == 3, "carousel: three dots")
	# 🛑 The dot may look small, but the place you press is the touch minimum.
	var dot := carousel._dots.get_child(0) as Control
	check(dot.custom_minimum_size.x >= float(GoUi.metric(GoTheme.TOUCH)) * 0.55, "carousel: the dot's press area is generous")
	carousel.next()
	await frames(2)
	check(carousel.index() == 1, "carousel: next")
	carousel.go_to(0)
	await frames(1)
	carousel.previous()
	await frames(2)
	check(carousel.index() == 2, "carousel: previous from the first wraps to the end (%d)" % carousel.index())
	# 🛑 Advancing by itself steals reading time — off by default.
	check(not carousel.is_processing(), "carousel: auto-advance is off by default")
	carousel.autoplay_seconds = 5.0
	await frames(1)
	# ♿ For someone who reduced motion it never moves on its own (reduce_motion is on right now).
	check(not carousel.is_processing(), "carousel: under reduce_motion it does not auto-advance")
	# 🛑 The press area stays at the touch minimum — a dot that looks small is no reason to shave it.
	# 🛑 The dots are **rebuilt** whenever the page changes — reading one grabbed earlier touches an already
	#    freed node and raises `previously freed` (the verdict still passes, only errors pile up). Fetch it again at use.
	var live_dot := carousel._dots.get_child(0) as Control
	check(live_dot != null and live_dot.custom_minimum_size.x >= float(GoUi.metric(GoTheme.TOUCH)) - 0.5,
		"carousel: the dot's press area keeps the touch minimum (%.1f)" % (live_dot.custom_minimum_size.x if live_dot else -1.0))
	# 🛑 Out of sight it does not turn — a covered banner must not burn battery.
	GoUi.config.reduce_motion = false
	carousel.autoplay_seconds = 5.0
	await frames(1)
	check(carousel.is_processing(), "carousel: visible with auto-advance on, it runs")
	carousel.visible = false
	await frames(1)
	check(not carousel.is_processing(), "carousel: hidden, auto-advance stops")
	carousel.visible = true
	GoUi.config.reduce_motion = true
	carousel.queue_free()
	await frames(1)
	section("carousel")


# ── Inventory grid ────────────────────────────────────────────────────

func _slot_grid() -> void:
	var holder := Control.new()
	holder.size = Vector2(360, 600)
	root.add_child(holder)
	var grid := GoSlotGrid.new()
	grid.slot_count = 12
	grid.cell_size = 60
	grid.size = Vector2(360, 0)
	holder.add_child(grid)
	await frames(2)
	var cells: Array = grid.find_children("*", "GoSlot", true, false)
	check(cells.size() == 12, "slot grid: one GoSlot per cell (%d)" % cells.size())
	var first := grid.slot(0)
	check(first.custom_minimum_size.x >= 60.0, "slot grid: a cell larger than the touch minimum grows its box (%s)" % str(first.custom_minimum_size))
	check(first.get_node(^"Face").size.x >= 59.0, "slot grid: the face is the asked size, not clamped to touch (%s)" % str(first.get_node(^"Face").size))
	check(first.mouse_filter == Control.MOUSE_FILTER_PASS, "slot grid: cells hand the finger drag to the scroll")
	check(grid.slot(5).position.y > first.position.y, "slot grid: cells wrap to the width")

	var vacant_face := _face_color(first)
	grid.set_cell(0, {"icon": GoIconSet.POTION, "quantity": 7, "accent": Color("e5484d"), "tooltip": "Potion"})
	await frames(2)
	check(first.icon_name == GoIconSet.POTION and first.quantity == 7, "slot grid: set_cell draws icon and count")
	check(first.tooltip_text == "Potion", "slot grid: the tooltip is the cell's accessible name")
	check(_face_color(first) != vacant_face, "slot grid: a vacant cell is drawn fainter than a filled one")
	check(first.get_node(^"Face/QuantityBadge").visible, "slot grid: a counted cell shows its badge")
	grid.set_cell(1, {"icon": GoIconSet.SWORD})
	await frames(1)
	check(not grid.slot(1).get_node(^"Face/QuantityBadge").visible, "slot grid: a cell without `quantity` hides the badge (equipment)")
	check(grid.cell(0).get("quantity") == 7 and grid.cell(3).is_empty(), "slot grid: cell() reads back what was drawn")

	var pressed: Array[int] = []
	grid.slot_pressed.connect(func(index: int) -> void: pressed.append(index))
	grid.slot(0).pressed.emit()
	grid.slot(3).pressed.emit()
	check(pressed == [0, 3], "slot grid: vacant cells report presses too %s" % str(pressed))
	var idle_face := _face_color(first)
	grid.selected = 0
	await frames(1)
	check(first.selected and not grid.slot(1).selected, "slot grid: one cell picked at a time")
	check(_face_color(first) != idle_face, "slot grid: the picked cell is drawn lit")
	grid.selected = 99
	check(grid.selected == -1 and not first.selected, "slot grid: an out-of-range pick clears the selection")

	# Drag to move — the three forwarded callbacks, called the way the engine calls them.
	var moves: Array = []
	grid.slot_moved.connect(func(from: int, to: int) -> void: moves.append([from, to]))
	check(grid._drag_from(Vector2.ZERO, 0) == null, "slot grid: nothing drags while `draggable` is off")
	grid.draggable = true
	check(grid._drag_from(Vector2.ZERO, 3) == null, "slot grid: a vacant cell cannot be dragged")
	var carried: Variant = grid._drag_from(Vector2.ZERO, 0)
	check(carried is Dictionary and carried.get("index") == 0, "slot grid: a filled cell starts a drag")
	check(grid._can_drop_on(Vector2.ZERO, carried, 4) and not grid._can_drop_on(Vector2.ZERO, carried, 0),
		"slot grid: drops on another cell, never on itself")
	check(not grid._can_drop_on(Vector2.ZERO, {"go_slot_grid": 1, "index": 2}, 4), "slot grid: another grid's drag is refused")
	grid._drop_on(Vector2.ZERO, carried, 4)
	check(moves == [[0, 4]], "slot grid: a drop reports slot_moved and moves nothing itself %s" % str(moves))
	check(grid.cell(4).is_empty(), "slot grid: the game decides what a move means")

	# The icon's own color — kept in hue, corrected for contrast against the face.
	var plain_icon: Color = grid.slot(1).get_node(^"Face/IconSlot").modulate
	grid.set_cell(1, {"icon": GoIconSet.SWORD, "ink": Color("10204a")})
	await frames(1)
	var inked: Color = grid.slot(1).get_node(^"Face/IconSlot").modulate
	var face_back := GoSkin.blend(GoSkin.box_background(grid.slot(1).get_node(^"Face").get_theme_stylebox(&"panel")), GoUi.color(GoTheme.SURFACE_SOFT))
	check(inked != plain_icon and inked.b > inked.r, "slot grid: `ink` colors the icon and keeps its hue (%s)" % str(inked))
	check(GoSkin.contrast_ratio(inked, face_back) >= 4.5, "slot grid: a dark ink is lifted until it reads on the face (%.2f)" % GoSkin.contrast_ratio(inked, face_back))
	grid.set_cell(1, {"icon": GoIconSet.SWORD, "ink": Color("10204a"), "disabled": true})
	await frames(1)
	check(grid.slot(1).get_node(^"Face/IconSlot").modulate != inked, "slot grid: a disabled cell fades even an inked icon")
	grid.set_cell(1, {"icon": GoIconSet.SWORD})
	# A big cell gets a bigger count.
	var small := GoSlot.new()
	small.quantity = 3
	holder.add_child(small)
	await frames(2)
	var big_count: Label = first.get_node(^"Face/QuantityBadge/Quantity")
	var small_count: Label = small.get_node(^"Face/QuantityBadge/Quantity")
	check(big_count.get_theme_font_size(&"font_size") > small_count.get_theme_font_size(&"font_size"),
		"slot grid: a 60dp cell reads its count larger than a 44dp quick slot (%d > %d)"
			% [big_count.get_theme_font_size(&"font_size"), small_count.get_theme_font_size(&"font_size")])
	small.queue_free()

	grid.slot_count = 6
	await frames(2)
	check(grid.find_children("*", "GoSlot", true, false).size() == 6 and grid.cell(0).get("quantity") == 7,
		"slot grid: shrinking keeps what the kept cells drew")
	grid.set_cells([{"icon": GoIconSet.KEY, "quantity": 1}])
	check(grid.slot(0).icon_name == GoIconSet.KEY and grid.cell(1).is_empty(), "slot grid: set_cells vacates the rest")
	holder.queue_free()
	await frames(1)
	section("slot grid")


# ── Segmented with icons ──────────────────────────────────────────────

func _segmented_icons() -> void:
	var picked: Array[int] = []
	var line := GoStyle.segmented([{"text": "All", "icon": GoIconSet.GRID}, "Plain", {"icon": GoIconSet.STAR, "tooltip": "Starred"}],
		0, func(index: int) -> void: picked.append(index))
	root.add_child(line)
	await frames(2)
	var first := line.get_child(0) as Button
	var plain := line.get_child(1) as Button
	var bare := line.get_child(2) as Button
	check(first.text == "All" and first.icon == GoUi.icons().texture(GoIconSet.GRID), "segmented: a {text, icon} option shows both")
	check(plain.text == "Plain" and plain.icon == null, "segmented: a plain string option is unchanged")
	check(bare.text == "" and bare.icon != null and bare.tooltip_text == "Starred", "segmented: an icon-only option carries its name as the tooltip")
	check(first.get_theme_color(&"icon_pressed_color") == GoUi.color(GoTheme.ON_ACCENT)
		and first.get_theme_color(&"icon_normal_color") == first.get_theme_color(&"font_color"),
		"segmented: the icon takes the label's color in every state")
	bare.pressed.emit()
	check(picked == [2], "segmented: the action still gets the index %s" % str(picked))
	line.queue_free()
	await frames(1)
	section("segmented icons")


# ── Slot grid: before the tree, focus, resizing, disabled ─────────────

func _slot_grid_followups() -> void:
	# 🛑 Found 2026-09-17: a grid filled before it is added failed with "Invalid assignment of index" — the
	#    initial `slot_count` never ran its setter, so the data array was still empty.
	var early := GoSlotGrid.new()
	early.set_cell(2, {"icon": GoIconSet.POTION, "quantity": 4})
	early.selected = 2
	check(early.cell(2).get("quantity") == 4, "slot grid: set_cell works before the grid is in the tree")
	check(early.selected == 2, "slot grid: a pick made before the tree is kept (%d)" % early.selected)
	early.keyboard_focus = false
	var holder := Control.new()
	holder.size = Vector2(360, 600)
	root.add_child(holder)
	holder.add_child(early)
	await frames(2)
	check(early.slot(2).icon_name == GoIconSet.POTION and early.slot(2).selected,
		"slot grid: cells drawn on entry show what was set before")
	check(early.slot(0).focus_mode == Control.FOCUS_NONE, "slot grid: keyboard_focus = false keeps the cells out of focus (hotbar)")
	early.keyboard_focus = true
	check(early.slot(0).focus_mode == Control.FOCUS_ALL, "slot grid: keyboard_focus reaches the cells that exist")

	# The count's text size follows a size change made after entering the tree.
	var count: Label = early.slot(2).get_node(^"Face/QuantityBadge/Quantity")
	early.cell_size = 44
	await frames(1)
	var small_size := count.get_theme_font_size(&"font_size")
	early.cell_size = 64
	await frames(1)
	check(count.get_theme_font_size(&"font_size") > small_size,
		"slot grid: growing the cells after entry grows the count (%d > %d)" % [count.get_theme_font_size(&"font_size"), small_size])

	# `disabled` belongs to BaseButton — the slot must still notice it and fade.
	var slot := early.slot(2)
	var lit_face := _face_color(slot)
	slot.selected = false
	await frames(1)
	var resting_face := _face_color(slot)
	slot.disabled = true
	await frames(2)
	check(_face_color(slot) != resting_face, "slot: setting only `disabled` fades the slot (%s)" % _face_color(slot))
	slot.disabled = false
	await frames(2)
	check(_face_color(slot) == resting_face, "slot: clearing `disabled` brings the face back")
	check(lit_face != resting_face, "slot: the picked face differs from the resting one")

	# A disabled cell does not start a drag; a string colour from a data file still paints; null is ignored.
	early.draggable = true
	early.set_cell(3, {"icon": GoIconSet.SWORD, "disabled": true, "ink": "e5484d", "accent": null})
	await frames(1)
	check(early._drag_from(Vector2.ZERO, 3) == null, "slot grid: a disabled cell cannot be dragged")
	check(early.slot(3).icon_ink.is_equal_approx(Color("e5484d")), "slot grid: an `ink` colour string is read")
	check(early.slot(3).accent == Color.TRANSPARENT, "slot grid: a null accent is transparent, not a parse error")

	# A form forces wrapping onto labels below it — the count badge must stay one line.
	GoStyle.form(holder)
	await frames(2)
	var badge_text: Label = early.slot(2).get_node(^"Face/QuantityBadge/Quantity")
	check(badge_text.autowrap_mode == TextServer.AUTOWRAP_OFF and badge_text.get_line_count() == 1,
		"slot: inside a form the count stays on one line")

	# ♿ A cell says its name and its count.
	early.set_cell(2, {"icon": GoIconSet.POTION, "quantity": 4, "tooltip": "Potion"})
	await frames(1)
	check(early.slot(2).accessibility_name.contains("Potion") and early.slot(2).accessibility_name.contains("4"),
		"slot grid: the accessible name carries the tooltip and the count (%s)" % early.slot(2).accessibility_name)
	check(early.slot(2)._make_custom_tooltip("Potion") is Control, "slot: the tooltip is gohud's, not the engine's")

	# The gaps follow a preset change.
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	await frames(1)
	check(early.theme == GoUi.theme(), "slot grid: a preset change reaches the grid itself")
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true
	await frames(1)
	holder.queue_free()
	await frames(1)
	section("slot grid follow-ups")


# ── Theme colors read before the tree ─────────────────────────────────

func _theme_color_lookup() -> void:
	var look := GoUi.theme()
	var expected := look.get_color(&"font_color", &"Button")
	# 🛑 The engine's lookup before the tree: the default gray, even with the node's own theme set (measured 2026-09-17).
	var loose := Button.new()
	loose.theme = look
	loose.theme_type_variation = GoTheme.VAR_COMPACT_BUTTON
	check(not look.has_color(&"font_color", GoTheme.VAR_COMPACT_BUTTON),
		"theme color: the compact variation defines no font color of its own (the chain matters)")
	check(GoTheme.has_color_in_chain(look, &"font_color", GoTheme.VAR_COMPACT_BUTTON),
		"theme color: the chain finds the color on the variation's base")
	check(GoUi.theme_color(&"font_color", GoTheme.VAR_COMPACT_BUTTON) == expected,
		"theme color: GoUi.theme_color climbs to Button's color")
	check(GoUi.theme_color_of(loose, &"font_color") == expected,
		"theme color: theme_color_of reads the theme for a node not in the tree")
	check(GoUi.theme_color(&"no_such_color", GoTheme.VAR_COMPACT_BUTTON, Color.RED) == Color.RED,
		"theme color: a color nobody defines gives the passed fallback")
	loose.add_theme_color_override(&"font_color", Color.GREEN)
	check(GoUi.theme_color_of(loose, &"font_color") == Color.GREEN, "theme color: an override wins")
	loose.free()
	section("theme color lookup")


# ── Segmented icons under a host theme and a font icon set ────────────

func _segmented_theme_chain() -> void:
	# A host theme whose button text differs from the `text` token — the default themes hide the chain bug
	# because both colors are the same value there.
	var host: Theme = GoUi.theme().duplicate()
	var orange := Color("ff9a3c")
	host.set_color(&"font_color", &"Button", orange)
	GoUi.config.theme = host
	var line := GoStyle.segmented([{"text": "All", "icon": GoIconSet.GRID}, "Plain"], 1)
	root.add_child(line)
	await frames(2)
	var first := line.get_child(0) as Button
	check(first.get_theme_color(&"icon_normal_color") == orange and first.get_theme_color(&"font_color") == orange,
		"segmented: the icon follows a host theme's button text color (%s)" % str(first.get_theme_color(&"icon_normal_color")))
	line.queue_free()
	GoUi.config.theme = null

	# 🛑 A snug (compact) cell sized to its label squeezed an expanding icon to a dot (virtual-monitor shot 2026-09-18).
	# A label long enough to clear the touch-size floor, so the widths compare the content.
	var snug := GoStyle.segmented([{"text": "Potions", "icon": GoIconSet.POTION}, "Potions"], 0, Callable(), false, true)
	root.add_child(snug)
	await frames(2)
	var with_icon := (snug.get_child(0) as Button).get_combined_minimum_size().x
	var text_only := (snug.get_child(1) as Button).get_combined_minimum_size().x
	check(with_icon >= text_only + GoUi.metric(GoTheme.LIST_GLYPH) - 1.0,
		"segmented: a compact cell makes room for its icon beside the text (%.0f ≥ %.0f + %d)" % [with_icon, text_only, GoUi.metric(GoTheme.LIST_GLYPH)])
	snug.queue_free()

	# A font icon set: the glyph is a child label — it must not sit on the text and must repaint when chosen.
	var fonts := GoIconSet.new()
	fonts.font = ThemeDB.fallback_font
	fonts.codepoints = {&"star": 0x2605}
	fonts.fallback = GoUi.DEFAULT_ICONS
	GoUi.config.icons = fonts
	var picked: Array[int] = []
	var font_line := GoStyle.segmented([{"text": "Starred", "icon": &"star"}, "Other"], 1,
		func(index: int) -> void: picked.append(index))
	root.add_child(font_line)
	await frames(3)
	var starred := font_line.get_child(0) as Button
	var glyph := starred.get_node_or_null(^"IconGlyph") as Label
	check(glyph != null, "segmented: a font set puts the glyph on the cell")
	if glyph != null:
		var text_start := starred.get_theme_stylebox(&"normal").content_margin_left
		check(glyph.position.x + glyph.size.x <= text_start + 0.5,
			"segmented: the font glyph ends before the text starts (%.0f ≤ %.0f)" % [glyph.position.x + glyph.size.x, text_start])
		check(glyph.get_theme_color(&"font_color") != GoUi.color(GoTheme.ON_ACCENT), "segmented: an unchosen font glyph uses the label color")
		starred.pressed.emit()
		starred.button_pressed = true
		await frames(1)
		check(glyph.get_theme_color(&"font_color") == GoUi.color(GoTheme.ON_ACCENT),
			"segmented: the chosen cell repaints its font glyph")
	font_line.queue_free()
	GoUi.config.icons = null
	var bare := GoStyle.segmented([{"icon": GoIconSet.STAR, "tooltip": "Starred"}])
	check((bare.get_child(0) as Button).accessibility_name == "Starred", "segmented: an icon-only cell is named by its tooltip")
	bare.free()
	await frames(1)
	section("segmented theme chain")


# ── Per-surface height ceiling ────────────────────────────────────────

func _surface_height_cap() -> void:
	var area := GoSafeArea.usable_rect(root)
	var sheet := GoSheet.new()
	sheet.height_ratio = 0.86
	# The dp ceiling (`surface_max_height`, 700) would stop a tall test window first — lift it to measure the ratio.
	sheet.surface.max_height = 4000.0
	root.add_child(sheet)
	sheet.open("Tall")
	for index in 40: sheet.body.add_child(GoStyle.label("Row %d" % index))
	await frames(4)
	var capped := sheet.surface.card.size.y
	check(capped <= area.size.y * GoUi.config.surface_max_height_ratio + 1.0,
		"height cap: without max_height_ratio 0.86 is still cut to the global ceiling (%.0f)" % capped)
	check(sheet.surface._warned_height_cap == OS.is_debug_build(), "height cap: a debug build reports the cut once")
	sheet.max_height_ratio = 0.9
	sheet.surface.relayout()
	await frames(2)
	check(sheet.surface.card.size.y > capped + 10.0 and sheet.surface.card.size.y <= area.size.y * 0.86 + 1.0,
		"height cap: max_height_ratio lets this sheet reach 0.86 (%.0f > %.0f)" % [sheet.surface.card.size.y, capped])
	# Dragging stops at the ceiling that is drawn, and `height_changed` never reports more.
	sheet.max_height_ratio = 0.0
	var reported: Array[float] = []
	sheet.surface.height_changed.connect(func(ratio: float) -> void: reported.append(ratio))
	sheet.surface._dragging = true
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(0, -area.size.y)
	sheet.surface._input(drag)
	sheet.surface._dragging = false
	check(not reported.is_empty() and reported.back() <= GoUi.config.surface_max_height_ratio + 0.001,
		"height cap: a drag past the ceiling reports the ceiling (%s)" % str(reported))
	sheet.queue_free()
	await frames(2)
	section("surface height cap")


# ── HUD buttons and keyboard focus ────────────────────────────────────

func _hud_focus() -> void:
	var mark := GoStyle.icon_button(GoIconSet.BAG)
	check(mark.focus_mode == Control.FOCUS_ALL, "hud focus: an icon button keeps focus by default (unchanged)")
	mark.keyboard_focus = false
	check(mark.focus_mode == Control.FOCUS_NONE, "hud focus: GoIconButton.keyboard_focus = false leaves the Tab order")
	mark.free()

	var corner := GoHudAnchor.new()
	root.add_child(corner)
	var row := GoStyle.row()
	corner.add_child(row)
	var menu := GoStyle.button("Menu", Callable(), GoStyle.Tone.COMPACT)
	row.add_child(menu)
	var chat := GoStyle.line_edit("Say something")
	row.add_child(chat)
	await frames(2)
	menu.grab_focus()
	check(menu.has_focus(), "hud focus: a button under an anchor takes focus by default")
	root.gui_release_focus()
	corner.keyboard_focus = false
	# A button added later is covered too — no button to forget.
	var later := GoStyle.button("Map", Callable(), GoStyle.Tone.COMPACT)
	row.add_child(later)
	await frames(1)
	check(later.get_focus_mode_with_override() == Control.FOCUS_NONE and menu.get_focus_mode_with_override() == Control.FOCUS_NONE,
		"hud focus: keyboard_focus = false on the anchor blocks focus for every button, later ones too")
	check(chat.get_focus_mode_with_override() == Control.FOCUS_NONE,
		"hud focus: it blocks text inputs too — documented, keep inputs in another anchor")
	corner.keyboard_focus = true
	check(menu.get_focus_mode_with_override() == Control.FOCUS_ALL, "hud focus: turning it back on restores focus")
	corner.queue_free()
	await frames(1)
	section("hud focus")


# ── Tooltip keys that are the host's own ──────────────────────────────

func _tooltip_translation() -> void:
	var table := Translation.new()
	table.locale = TranslationServer.get_locale()
	table.add_message(&"HUD_BAG_TOOLTIP", "Open the bag")
	TranslationServer.add_translation(table)
	var mark := GoStyle.icon_button(GoIconSet.BAG, Callable(), -1, &"HUD_BAG_TOOLTIP")
	root.add_child(mark)
	await frames(1)
	check(mark.tooltip_text == "Open the bag", "tooltip: a host translation key translates without text_keys (%s)" % mark.tooltip_text)
	check(GoUi.text(&"Zoom in") == "Zoom in", "tooltip: plain words with no translation come back as written")
	check(GoUi.text(&"close") == TranslationServer.translate(GoUi.config.text_keys[&"close"]),
		"tooltip: a built-in name still goes through text_keys")
	TranslationServer.remove_translation(table)
	mark.queue_free()
	await frames(1)
	section("tooltip translation")


# ── Item detail card ──────────────────────────────────────────────────

func _item_card() -> void:
	var used: Array[String] = []
	var card := GoStyle.item_card({
		"icon": GoIconSet.SWORD, "ink": Color("10204a"), "title": "Iron sword", "subtitle": "One-handed",
		"chips": [{"text": "Rare", "ink": GoUi.color(GoTheme.INFO)}, "Tradable"],
		"body": "A plain blade that holds its edge.",
		"stats": [["Attack", "+12"], ["Weight", "3.5"]],
		"actions": [{"text": "Equip", "action": func() -> void: used.append("equip"), "tone": GoStyle.Tone.PRIMARY},
			{"text": "Drop", "action": func() -> void: used.append("drop")}],
	})
	var holder := VBoxContainer.new()
	holder.size = Vector2(360, 0)
	root.add_child(holder)
	holder.add_child(card)
	await frames(2)
	check(card is PanelContainer and card.find_child("Title", true, false).text == "Iron sword",
		"item card: a framed card with its title")
	check((card.find_child("Chips", true, false) as Control).get_child_count() == 2, "item card: one chip per entry")
	check((card.find_child("Stats", true, false) as GridContainer).get_child_count() == 4, "item card: stat rows are label + value")
	var title_node := card.find_child("Icon", true, false) as Control
	check(title_node.get_global_rect().position.x - card.get_global_rect().position.x >= GoUi.metric(GoTheme.PADDING_COMPACT),
		"item card: a framed card keeps its content off the border")
	var action_row := card.find_child("Actions", true, false) as Control
	check(is_equal_approx((action_row.get_child(0) as Control).size.y, (action_row.get_child(1) as Control).size.y),
		"item card: a primary and a plain action stand the same height")
	var disc := card.find_child("Icon", true, false) as PanelContainer
	var glyph := disc.get_child(0) as Control
	var on_disc := GoSkin.blend(GoSkin.box_background(disc.get_theme_stylebox(&"panel")), GoUi.color(GoTheme.SURFACE))
	check(GoSkin.contrast_ratio(GoSkin.blend(glyph.modulate, on_disc), on_disc) >= 4.4,
		"item card: a dark item color is lifted to read on its disc (%.2f)" % GoSkin.contrast_ratio(glyph.modulate, on_disc))
	var actions := card.find_child("Actions", true, false) as Control
	(actions.get_child(0) as Button).pressed.emit()
	(actions.get_child(1) as Button).pressed.emit()
	check(used == ["equip", "drop"], "item card: actions call back %s" % str(used))
	var bare := GoStyle.item_card({"title": "Bare"}, false)
	check(bare is VBoxContainer and bare.find_child("Icon", true, false) == null and bare.find_child("Actions", true, false) == null,
		"item card: unframed and empty keys build nothing extra")
	bare.free()
	holder.queue_free()
	await frames(1)
	section("item card")


# ── Chosen list row ───────────────────────────────────────────────────

func _list_row_selection() -> void:
	var holder := VBoxContainer.new()
	holder.size = Vector2(320, 0)
	root.add_child(holder)
	var row_a := GoStyle.list_button(GoIconSet.GLOBE, "Asia", Callable(), Color.TRANSPARENT, "", false)
	var row_b := GoStyle.list_button(GoIconSet.GLOBE, "Europe", Callable(), Color.TRANSPARENT, "", false)
	holder.add_child(row_a)
	holder.add_child(row_b)
	await frames(2)
	var height := row_a.size.y
	var resting := row_a.get_theme_stylebox(&"normal")
	GoStyle.restyle_list_row(row_a, true)
	await frames(2)
	var chosen := row_a.get_theme_stylebox(&"normal")
	check(chosen != resting and row_a.has_theme_stylebox_override(&"hover"), "list row: the chosen row gets its own face")
	check(&"border_color" in chosen and (chosen.get(&"border_color") as Color).a > 0.5, "list row: the pick is a border, not a color alone")
	check(is_equal_approx(row_a.size.y, height), "list row: picking does not change the row height (%.0f → %.0f)" % [height, row_a.size.y])
	check(not row_b.has_theme_stylebox_override(&"normal"), "list row: other rows stay as they were")
	GoStyle.restyle_list_row(row_a, false)
	check(not row_a.has_theme_stylebox_override(&"normal") and row_a.get_child_count() == 1,
		"list row: clearing goes back to the theme face without rebuilding the row")
	holder.queue_free()
	await frames(1)
	section("list row selection")


# ── Game icon set ─────────────────────────────────────────────────────

func _game_icons() -> void:
	var game := GoGameIcons.icon_set()
	check(game != null and game.fallback == GoUi.DEFAULT_ICONS, "game icons: the set loads and falls back to the default set")
	var names := GoGameIcons.names()
	check(names.size() == game.textures.size(), "game icons: every texture has a name constant (%d / %d)" % [names.size(), game.textures.size()])
	var blurry: Array = []
	var undrawn: Array = []
	for icon: StringName in names:
		if game.texture(icon) == null: undrawn.append(icon)
		elif not game.texture(icon) is DPITexture: blurry.append(icon)
	check(undrawn.is_empty(), "game icons: every name draws %s" % str(undrawn))
	check(blurry.is_empty(), "game icons: vector textures — sharp in a 64dp inventory cell %s" % str(blurry))
	var constants: Dictionary = (load(ADDON + "/core/go_game_icons.gd") as Script).get_script_constant_map()
	var orphans: Array = []
	for key: String in constants:
		if constants[key] is StringName and not names.has(constants[key]): orphans.append(key)
	check(orphans.is_empty(), "game icons: every constant belongs to a group %s" % str(orphans))
	var clash: Array = []
	for icon: StringName in names:
		if GoUi.DEFAULT_ICONS.textures.has(icon): clash.append(icon)
	check(clash.is_empty(), "game icons: no name redraws a default icon %s" % str(clash))
	check(game.texture(GoIconSet.CLOSE) == GoUi.DEFAULT_ICONS.texture(GoIconSet.CLOSE), "game icons: default names still resolve")
	check(game.attribution.contains("Tabler") and game.attribution.contains("MIT"), "game icons: the set carries its attribution")
	check(GoGameIcons.GROUP_TITLES.keys() == GoGameIcons.GROUPS.keys(), "game icons: every group has a title")

	GoUi.config.icons = game
	var slot := GoSlot.new()
	slot.icon_name = GoGameIcons.BACKPACK
	root.add_child(slot)
	await frames(2)
	var drawn := slot.get_node(^"Face/IconSlot/Icon") as TextureRect
	check(drawn != null and drawn.texture == game.texture(GoGameIcons.BACKPACK), "game icons: a slot draws a game icon once the set is plugged in")
	slot.queue_free()
	GoUi.config.icons = null
	await frames(1)
	section("game icons")


# ── Theme follow ──────────────────────────────────────────────────────

func _theme_follow() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(2)
	var bar := GoBar.new()
	var slot := GoSlot.new()
	var badge := GoBadge.make(3)
	root.add_child(bar); root.add_child(slot); root.add_child(badge)
	await frames(3)

	var before := {
		"bar": _fill_color(bar), "slot": _face_color(slot), "badge": _panel_color(badge),
	}
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	await frames(3)
	check(_fill_color(bar) != before["bar"], "look: an HP bar already on screen follows")
	check(_face_color(slot) != before["slot"], "look: a quick slot already on screen follows")
	check(_panel_color(badge) != before["badge"], "look: a badge already on screen follows")
	# 🛑 Nodes are not rebuilt — lose `Face` and every piece of code referring to that slot breaks.
	check(slot.get_node_or_null(^"Face") != null, "look: nodes are not rebuilt")

	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(2)
	bar.queue_free(); slot.queue_free(); badge.queue_free()
	await frames(1)
	section("theme follows")


# ── Helpers ───────────────────────────────────────────────────────────

func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all(child))
	return out


func _first_label(node: Node) -> String:
	for child in _all(node):
		if child is Label: return (child as Label).text
	return ""


func _fill_color(bar: GoBar) -> String:
	for node in _all(bar):
		if node is ProgressBar:
			var face: StyleBox = (node as ProgressBar).get_theme_stylebox(&"fill")
			if face != null: return "%s %s" % [face.get_class(), str(face.get(&"bg_color"))]
	return ""


func _face_color(slot: GoSlot) -> String:
	var face := slot.get_node_or_null(^"Face") as Panel
	if face == null: return ""
	var box: StyleBox = face.get_theme_stylebox(&"panel")
	return "%s %s" % [box.get_class(), str(box.get(&"bg_color"))] if box != null else ""


func _panel_color(node: PanelContainer) -> String:
	var box: StyleBox = node.get_theme_stylebox(&"panel")
	return "%s %s" % [box.get_class(), str(box.get(&"bg_color"))] if box != null else ""


# ── Readable-list lab (examples/gallery/list_lab.gd) ──────────────────
## The lab's whole claim is a line of numbers read from its own nodes — so check those numbers say what the lab
## says: Before is the cramped screen (rows 4 apart, title the size of a row, a badge and a warning on every row),
## After follows skill rule 15. Then the gallery path: the button opens it **outside the page's `GoForm`**, where
## a form would have turned Before's 4 dp into 12 and made the comparison lie.
func _list_lab() -> void:
	section("list lab")
	var lab: Control = load(ADDON + "/examples/gallery/list_lab.gd").new()
	root.add_child(lab)
	await frames(4)
	lab.call("show_view", 2)
	await frames(4)
	var before: Dictionary = lab.call("measure", 0)
	var after: Dictionary = lab.call("measure", 1)
	var tiny := GoUi.metric(GoTheme.GAP_TINY)
	var small := GoUi.metric(GoTheme.GAP_SMALL)
	check(before.row_gap == tiny, "list lab: Before keeps the shipped 4 dp between rows (%d)" % before.row_gap)
	check(before.row_inset == tiny, "list lab: Before keeps the shipped 4 dp inside a row (%d)" % before.row_inset)
	check(after.row_gap >= small, "list lab: After's rows are at least GAP_SMALL apart (%d)" % after.row_gap)
	check(after.row_inset >= small, "list lab: After's rows keep GAP_SMALL inside (%d)" % after.row_inset)
	check(before.header == before.title, "list lab: Before's panel title is the size of a row title (%d / %d)" % [before.header, before.title])
	check(after.header > after.title and after.title > after.meta,
		"list lab: After steps down header > row title > second line (%d / %d / %d)" % [after.header, after.title, after.meta])
	check(before.badges == before.rows and after.badges == 0,
		"list lab: the repeated badge goes (%d of %d → %d)" % [before.badges, before.rows, after.badges])
	check(before.warnings >= 4 and after.warnings <= 1,
		"list lab: warnings only where something is wrong (%d → %d)" % [before.warnings, after.warnings])
	check(before.rows == 5 and after.rows == before.rows, "list lab: both sides show the same five quests (%d / %d)" % [before.rows, after.rows])
	check(before.height > 0 and after.height > 0, "list lab: both panels are laid out (%d / %d dp)" % [before.height, after.height])
	var asked := [false]
	lab.connect(&"closed", func() -> void: asked[0] = true)
	lab.call("close")
	check(asked[0], "list lab: close() asks the owner to remove it")
	lab.queue_free()
	await frames(2)

	var gallery: Node = (load(ADDON + "/examples/gallery/gallery.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	await frames(4)
	var button := gallery.find_child("ListLabButton", true, false) as Button
	check(button != null, "gallery: the List rows section has the list lab button")
	if button == null:
		gallery.queue_free()
		await frames(2)
		return
	button.pressed.emit()
	await frames(4)
	var opened := gallery.find_child("ListLab", true, false)
	var form := gallery.find_child("Form", true, false)
	check(opened != null and opened.get_parent() is CanvasLayer, "gallery: the button opens the lab on a layer of its own")
	check(opened != null and form != null and not form.is_ancestor_of(opened), "gallery: the lab is outside the page's GoForm")
	if opened != null:
		var inside: Dictionary = opened.call("measure", 0)
		check(inside.row_gap == tiny, "gallery: opened from the gallery, Before still measures 4 dp (%d)" % inside.row_gap)
		opened.call("close")
		await frames(3)
		check(gallery.find_child("ListLab", true, false) == null, "gallery: closing the lab removes it")
	gallery.queue_free()
	await frames(2)
