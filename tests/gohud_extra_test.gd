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
	await _charts()
	await _code_input()
	await _console()
	await _carousel()
	await _theme_follow()

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
	cal.set_claimed_until(6)
	await frames(2)
	check(cal.today() == -1, "rewards: with everything claimed there is no today")
	cal.queue_free()
	await frames(1)
	section("reward calendar")


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


# ── Does a change of look follow through ──────────────────────────────

## 🛑 **This is the most important check in this file.** `GoUi.use_preset()` promises that "theme, skin and
##    icons move together". Yet before 2026-09-16 **only freshly built widgets** changed —
##    an HP bar or quick slot already on screen kept its old colours, and standing next to the new ones one
##    screen carried two looks at once. It happens because a widget that registers no `GoUi.watch()` is never re-read.
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
