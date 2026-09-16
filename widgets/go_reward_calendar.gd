## 🎁 **Daily reward calendar** — how many days in a row you have shown up, what today gives, what waits tomorrow.
##
## ```gdscript
## var attendance := GoRewardCalendar.make([
##     {"icon": &"coin",  "amount": 100},
##     {"icon": &"potion", "amount": 3},
##     {"icon": &"gem",   "amount": 5, "special": true},   # made to stand out, like day 7
## ], 1)                                                    # claimed through day two
## attendance.claimed.connect(func(day: int) -> void: server.claim_day(day))
## sheet.body.add_child(attendance)
## ```
##
## ## 🔑 This is not a date picker
## A plain date picker is barely ever used in a game — a screen asking for a birthday, at most. Where a calendar shape
## does belong in a game is the **attendance reward**, and what matters there is not "which month and day" but **which day in the streak**.
## So this widget deals in **positions in a sequence**, not dates.
##
## ## 🛑 "What I get today" has to be visible at a glance
## With twenty-eight cells, if you cannot see which one is today, you leave without the reward you could have claimed.
## Today's cell gets an accent border and is pressable; past cells carry a claimed mark; upcoming ones are dimmed.
##
## ## 🛑 Never let someone press what they already claimed
## Letting a press through that you know the server will refuse makes a screen where pressing does nothing. Claimed cells take no presses.
##
## ## ♿ Color and position alone never tell the states apart
## Claimed, today and upcoming each carry a **different mark** (a check glyph · an accent border · dimming), and the word
## for "claimed" goes into the screen-reader name as well.
@tool
class_name GoRewardCalendar
extends VBoxContainer

## Today's cell was pressed. `day` is 0-based.
signal claimed(day: int)

## Cells per row.
@export var columns := 7:
	set(value):
		columns = maxi(1, value)
		_rebuild()

## Side length of a cell (dp). Negative means 1.4× the touch minimum.
@export var cell_size := -1.0:
	set(value):
		cell_size = value
		_rebuild()

var _days: Array[Dictionary] = []
var _claimed_until := -1
var _grid: GridContainer


func _init() -> void:
	name = "RewardCalendar"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	_grid = GridContainer.new()
	_grid.name = "Days"
	_grid.columns = columns
	add_child(_grid)


func _ready() -> void:
	_rebuild()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Builds the calendar from a reward list and the **last day claimed** (0-based; -1 means nothing claimed yet).
##
## The fields of one day:
## | Field | Meaning |
## |---|---|
## | `icon` | reward icon name |
## | `amount` | count (0 writes none) |
## | `label` | text to use instead of an icon |
## | `special` | bigger, in the accent color (day 7, day 30) |
static func make(days: Array, claimed_until := -1) -> GoRewardCalendar:
	var node := GoRewardCalendar.new()
	node.set_days(days, claimed_until)
	return node


func set_days(days: Array, claimed_until := -1) -> void:
	_days.clear()
	for entry in days:
		var row: Dictionary = entry if entry is Dictionary else {"label": str(entry)}
		_days.append({
			"icon": StringName(row.get("icon", &"")),
			"amount": int(row.get("amount", 0)),
			"label": str(row.get("label", "")),
			"special": bool(row.get("special", false)),
		})
	_claimed_until = claimed_until
	_rebuild()


## Changes only the last claimed day (once the server has confirmed the grant).
func set_claimed_until(day: int) -> void:
	_claimed_until = day
	_rebuild()


## Index of the cell claimable today (-1 when everything has been claimed).
func today() -> int:
	var next := _claimed_until + 1
	return next if next < _days.size() else -1


func _rebuild() -> void:
	if _grid == null: return
	_grid.columns = columns
	_grid.add_theme_constant_override(&"h_separation", GoUi.metric(GoTheme.GAP_SMALL))
	_grid.add_theme_constant_override(&"v_separation", GoUi.metric(GoTheme.GAP_SMALL))
	for child in _grid.get_children(): child.queue_free()
	var now := today()
	for index in _days.size():
		_grid.add_child(_cell(index, _days[index], now))


func _cell(index: int, day: Dictionary, now: int) -> Control:
	var taken := index <= _claimed_until
	var is_today := index == now
	var future := index > now and now >= 0

	var button := Button.new()
	button.name = "Day%d" % (index + 1)
	button.theme = GoUi.theme()
	button.theme_type_variation = GoTheme.VAR_BARE_BUTTON
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var side := cell_size if cell_size > 0.0 else float(GoUi.metric(GoTheme.TOUCH)) * 1.4
	button.custom_minimum_size = Vector2(side, side)
	# 🛑 Claimed and upcoming cells **cannot be pressed** — a button where pressing does nothing reads as broken.
	button.disabled = not is_today
	var accent := GoUi.color(GoTheme.ACCENT if day["special"] else GoTheme.BORDER)
	if is_today: accent = GoUi.color(GoTheme.ACCENT)
	button.add_theme_stylebox_override(&"normal", GoUi.skin().slot_box(accent, is_today))
	button.add_theme_stylebox_override(&"disabled", GoUi.skin().slot_box(
		GoUi.color(GoTheme.MUTED) if future else accent, false))

	var column := GoStyle.column(0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	# "Day 1" — the number is never translated.
	var number := GoStyle.label(str(index + 1), GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	number.text_direction = Control.TEXT_DIRECTION_LTR
	column.add_child(number)

	var icon_name: StringName = day["icon"]
	if not icon_name.is_empty() and GoUi.icons().has_icon(icon_name):
		var px := roundi(side * 0.42)
		var glyph := GoUi.icons().node(icon_name, px,
			GoUi.color(GoTheme.ACCENT) if day["special"] else GoUi.color(GoTheme.TEXT))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(glyph)
		column.add_child(center)
	elif not str(day["label"]).is_empty():
		var words := GoStyle.label(str(day["label"]), GoTheme.ROLE_COMPACT)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		column.add_child(words)

	var amount := int(day["amount"])
	if amount > 0:
		var count := GoStyle.label(GoUi.text(&"slot_quantity").format({"count": amount}),
			GoTheme.ROLE_MICRO, GoUi.color(GoTheme.SECONDARY))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		count.text_direction = Control.TEXT_DIRECTION_LTR
		column.add_child(count)

	button.add_child(column)

	# ♿ Dimming and borders on their own distinguish nothing — give the state in words too.
	# 🛑 **What you receive has to be read out as well.** With only the day and the state it says "day 3, claimed", and someone
	#    who cannot see the screen never finds out what is on offer today — they cannot decide whether to claim it.
	var state := GoUi.text(&"done") if taken else (GoUi.text(&"confirm") if is_today else GoUi.text(&"next"))
	var reward := str(day["label"])
	if reward.is_empty() and not icon_name.is_empty(): reward = String(icon_name)
	var many := GoUi.text(&"slot_quantity").format({"count": amount}) if amount > 0 else ""
	button.accessibility_name = GoUi.spoken([str(index + 1), reward, many, state])

	if taken:
		# Claimed cells get a **glyph mark** on top — dimming alone does not tell them apart from upcoming ones.
		button.modulate = Color(1, 1, 1, 0.55)
		if GoUi.icons().has_icon(&"check"):
			var mark := GoUi.icons().node(&"check", roundi(side * 0.34), GoUi.color(GoTheme.SUCCESS))
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.set_anchors_preset(Control.PRESET_CENTER)
			button.add_child(mark)
	elif future:
		button.modulate = Color(1, 1, 1, 0.7)

	if is_today:
		button.pressed.connect(func() -> void:
			GoFeedback.confirmed()
			claimed.emit(index))
	return button


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _rebuild()
