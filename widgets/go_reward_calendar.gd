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
## So this widget deals in **positions in a sequence**, not dates — which is also why a row may wrap early on a narrow screen.
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
##
## ## 📐 The cell is sized by what it holds
## Each cell lays its day number, picture and amount inside padding (`GoStyle.cell_body`) and **grows to fit them** — the
## content can never touch the border or spill past it. Cells stay square and never drop below the touch minimum.
## A row holds at most `columns` cells and wraps sooner when the width runs out, so the calendar never runs off a phone.
@tool
class_name GoRewardCalendar
extends VBoxContainer

## Today's cell was pressed. `day` is 0-based.
signal claimed(day: int)

## Cells per row, **at most** — a narrower screen wraps the row sooner (see `wrap_to_width`).
@export var columns := 7:
	set(value):
		columns = maxi(1, value)
		_rebuild()

## Smallest side of a cell (dp). Negative lets the content decide (never below the touch minimum).
## 🔑 It is a **floor**: a cell whose number, picture and amount need more room grows past it, still square.
## A positive value also sets the picture size (36% of it), as it did before.
@export var cell_size := -1.0:
	set(value):
		cell_size = value
		_rebuild()

## Wrap a row before `columns` when the width runs out. Off keeps exactly `columns` per row — the host then owns the width
## (a row of seven square cells needs about 600dp).
@export var wrap_to_width := true:
	set(value):
		wrap_to_width = value
		_fit_columns.call_deferred()

var _days: Array[Dictionary] = []
var _claimed_until := -1
## Holds the grid. 🔑 A plain `Control` does not take its children's minimum width, so the calendar can be narrowed
## below a full row — the grid then drops to fewer columns instead of pushing the page wider (`_fit_columns`).
var _frame: Control
var _grid: GridContainer


func _init() -> void:
	name = "RewardCalendar"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_grid = GridContainer.new()
	_grid.name = "Days"
	_grid.columns = columns
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(_grid)
	_frame.resized.connect(_fit_columns)
	_grid.minimum_size_changed.connect(_fit_columns, CONNECT_DEFERRED)


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
## | `special` | drawn in the accent color (day 7, day 30) |
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
	var gap := GoUi.metric(GoTheme.GAP_SMALL)
	_grid.add_theme_constant_override(&"h_separation", gap)
	_grid.add_theme_constant_override(&"v_separation", gap)
	# 🛑 Taken out of the grid right away — `queue_free` alone leaves the old cells laid out beside the new ones for a frame.
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var now := today()
	for index in _days.size():
		_grid.add_child(_cell(index, _days[index], now))
	_fit_columns.call_deferred()


## Picks how many cells fit in a row and hands the grid's height back to the frame.
func _fit_columns() -> void:
	if _grid == null or _frame == null: return
	var widest := 0.0
	for child in _grid.get_children():
		widest = maxf(widest, (child as Control).get_combined_minimum_size().x)
	var count := columns
	var total := _grid.get_child_count()
	if wrap_to_width and widest > 0.0 and _frame.size.x > 0.0:
		var gap := float(_grid.get_theme_constant(&"h_separation"))
		count = clampi(floori((_frame.size.x + gap) / (widest + gap)), 1, columns)
		# 🔑 A wrapped row is **evened out** — seven days on a row of six left day 7, the big reward, alone on a second line.
		#    Same number of rows, cells spread across them as evenly as the grid allows (4 + 3).
		if count < columns and count < total:
			count = ceili(float(total) / ceili(float(total) / count))
	if _grid.columns != count: _grid.columns = count
	# The frame never narrows below one cell (wrap) or a full row (no wrap), and always takes the grid's height.
	var floor_width := widest if wrap_to_width else _grid.get_combined_minimum_size().x
	var want := Vector2(floor_width, _grid.get_combined_minimum_size().y)
	if not _frame.custom_minimum_size.is_equal_approx(want): _frame.custom_minimum_size = want


func _cell(index: int, day: Dictionary, now: int) -> Control:
	var taken := index <= _claimed_until
	var is_today := index == now
	var special: bool = day["special"]

	var button := Button.new()
	button.name = "Day%d" % (index + 1)
	button.theme = GoUi.theme()
	button.theme_type_variation = GoTheme.VAR_BARE_BUTTON
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# 🛑 Claimed and upcoming cells **cannot be pressed** — a button where pressing does nothing reads as broken.
	button.disabled = not is_today

	# One face for every state. 🛑 Override only `normal` and `disabled` and the theme's empty `hover`·`pressed` show through:
	#    the cell's face vanished the moment today's cell was pressed.
	var edge := GoUi.color(GoTheme.ACCENT) if (is_today or special) else GoUi.color(GoTheme.BORDER)
	if taken: edge = GoUi.color(GoTheme.MUTED)
	var face := GoUi.skin().slot_box(edge, is_today)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		button.add_theme_stylebox_override(state, face)
	var back := GoSkin.blend(GoSkin.box_background(face), GoUi.color(GoTheme.SURFACE_SOFT))

	# 🛑 States are told apart by **color moved toward the dim end**, never by `modulate` alpha — fading the text along with
	#    the face made a claimed day's amount unreadable (`GoTheme.PANEL_ALPHA`, and GoSlot learned the same).
	#    Every text color is pushed until it reads on this face (`readable_on`).
	#    Today reads brightest, days to come one step dimmer, claimed days dimmest under their check mark.
	var number_ink := GoUi.color(GoTheme.ACCENT) if is_today else GoUi.color(GoTheme.MUTED)
	var amount_ink := GoUi.color(GoTheme.TEXT) if is_today else GoUi.color(GoTheme.MUTED if taken else GoTheme.SECONDARY)
	var glyph_ink := GoUi.color(GoTheme.TEXT) if is_today else GoUi.color(GoTheme.SECONDARY)
	if special: glyph_ink = GoUi.color(GoTheme.ACCENT)
	if taken: glyph_ink = back.lerp(GoUi.color(GoTheme.MUTED), 0.55)

	var touch := float(GoUi.metric(GoTheme.TOUCH))
	var floor_side := maxf(touch, cell_size)
	button.custom_minimum_size = Vector2(floor_side, floor_side)
	# 🔑 The picture's size comes from a token, **not from the cell** — sized from the cell, a bigger cell made a bigger picture
	#    that needed a bigger cell again, and the three rows never fitted.
	var glyph_px := roundi(cell_size * 0.36) if cell_size > 0.0 else roundi(touch * 0.5)
	var body := GoStyle.cell_body(button, GoUi.metric(GoTheme.GAP_TINY), GoUi.metric(GoTheme.GAP_TINY),
		GoUi.metric(GoTheme.GAP_SMALL), true)

	# "Day 1" — the number is never translated.
	var number := _text(str(index + 1), GoTheme.ROLE_MICRO, GoSkin.readable_on(number_ink, back))
	number.text_direction = Control.TEXT_DIRECTION_LTR
	body.add_child(number)

	var icon_name: StringName = day["icon"]
	var shows_icon := not icon_name.is_empty() and GoUi.icons().has_icon(icon_name)
	var check_ink := GoSkin.readable_on(GoUi.color(GoTheme.SUCCESS), back, 3.0)
	if shows_icon:
		# The picture and the claimed mark share one slot, so the mark lands on the picture by construction.
		var slot := _picture(glyph_px)
		_place(slot, GoUi.icons().node(icon_name, glyph_px, GoSkin.readable_on(glyph_ink, back, 3.0) if not taken else glyph_ink))
		if taken and GoUi.icons().has_icon(&"check"): _place(slot, GoUi.icons().node(&"check", glyph_px, check_ink))
		body.add_child(slot)
	elif not str(day["label"]).is_empty():
		body.add_child(_text(str(day["label"]), GoTheme.ROLE_COMPACT, GoSkin.readable_on(amount_ink, back)))

	var amount := int(day["amount"])
	if amount > 0:
		# 🔑 The amount is what you get, so it reads a step larger than the day number.
		var count := _text(GoUi.text(&"slot_quantity").format({"count": amount}), GoTheme.ROLE_COMPACT,
			GoSkin.readable_on(amount_ink, back))
		count.text_direction = Control.TEXT_DIRECTION_LTR
		body.add_child(count)
	if taken and not shows_icon and GoUi.icons().has_icon(&"check"):
		var mark := _picture(GoUi.metric(GoTheme.ICON_SIZE))
		_place(mark, GoUi.icons().node(&"check", GoUi.metric(GoTheme.ICON_SIZE), check_ink))
		body.add_child(mark)
	GoStyle.let_input_through(body)

	# ♿ Dimming and borders on their own distinguish nothing — give the state in words too.
	# 🛑 **What you receive has to be read out as well.** With only the day and the state it says "day 3, claimed", and someone
	#    who cannot see the screen never finds out what is on offer today — they cannot decide whether to claim it.
	var state := GoUi.text(&"done") if taken else (GoUi.text(&"confirm") if is_today else GoUi.text(&"next"))
	var reward := str(day["label"])
	if reward.is_empty() and not icon_name.is_empty(): reward = String(icon_name)
	var many := GoUi.text(&"slot_quantity").format({"count": amount}) if amount > 0 else ""
	button.accessibility_name = GoUi.spoken([str(index + 1), reward, many, state])

	if is_today:
		button.pressed.connect(func() -> void:
			GoFeedback.confirmed()
			claimed.emit(index))
	return button


## A fixed square for a picture. 🛑 Not a container that takes the glyph's own size — an icon-font glyph is a `Label`
## whose line is taller than the picture (a 24dp crown stood 33dp), and one tall glyph made its whole row and column larger.
func _picture(px: int) -> Control:
	var slot := Control.new()
	slot.name = "Picture"
	slot.custom_minimum_size = Vector2(px, px)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


## Centers a glyph on the picture square by its own size (a taller glyph line overhangs evenly, its picture stays centered).
func _place(slot: Control, glyph: Control) -> void:
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(glyph)
	GoStyle.center_in(glyph)


## One line of cell text. 🛑 Wrapping is switched **off and kept off** — `GoStyle.label` turns it on, and inside a form
## `GoStyle.form()` would turn it on again unless `go_no_wrap` says not to; a folded "×100" stacks one character per line.
func _text(words: String, role: StringName, ink: Color) -> Label:
	var node := GoStyle.label(words, role, ink)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.set_meta(&"go_no_wrap", true)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return node


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _rebuild()
