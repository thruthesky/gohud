## 🎁 **A reward row** — one thing a player earns by progress: a daily quest, an achievement, a season task. One line
## of a table: a picture, a title, a progress bar with its `3 / 5`, what it pays, and at the end the row's state.
##
## ```gdscript
## var quest := GoRewardRow.make("Win 3 matches", &"quest_medal")
## quest.set_progress(1, 3)
## quest.set_reward(50)
## quest.set_claim_text("CLAIM")
## quest.set_state(GoRewardRow.State.READY)
## quest.key = "win_3"
## quest.claim_pressed.connect(func(id: Variant) -> void: server.claim(id))
## ```
##
## | `state` | What it shows | arcade_light |
## |---|---|---|
## | `IN_PROGRESS` | the bar and its fraction | the cyan plate, the blue bar |
## | `READY` | the glowing claim pill (`GoPillGreen`; a look without it uses `GoPrimaryButton`) | the gold plate, the green bar |
## | `CLAIMED` | the check | the done plate, the `check_green` sticker |
## | `LOCKED` | the padlock | the done plate |
##
## ## 🎨 Two ways to draw it
## arcade_light paints the row to stand beside a `GoScoreTable`: the theme types `GoRewardRow`, `GoRewardRowGold`,
## `GoRewardRowDone`, `GoRewardBar` and `GoRewardBarGreen`, the table's own `GoScoreTableLabel` lettering, and full-colour
## pictures with no plate behind them (`coin`, `gift`, `quest_play`, `quest_medal`, `quest_magnet`, `quest_powerup`,
## `quest_star`, `quest_flame`, from `GoSkin.widget_art`). Any other look draws it with its own card, a glyph in a well
## (`GoInsetPanel`), `GoBar` and a dimmed claimed or locked row.
##
## ## 📐 Its width
## From [constant WIDE_WIDTH] up everything stands on one line and the columns of a stack of rows line up. Narrower, the
## bar, its fraction and the payment move under the title.
##
## ## 🔑 In a long list
## Every row is [method extent] tall whatever its words and its width, so it fits `GoListView` as well as a `GoScroll`:
## ```gdscript
## var list := GoListView.recycle(quests.size(), GoRewardRow.extent(),
## 	func() -> Control:
## 		var row := GoRewardRow.make("")
## 		row.claim_pressed.connect(_claim)      # once, here: the row hands back the key it holds now
## 		return row,
## 	func(node: Control, index: int) -> void:
## 		var row := node as GoRewardRow
## 		row.key = quests[index].id             # first, so a press on the old quest is dropped
## 		row.title = quests[index].title
## 		row.set_progress(quests[index].done, quests[index].goal)
## 		row.set_reward(quests[index].coins)
## 		row.set_claim_text("CLAIM")
## 		row.set_state(quests[index].state))
## ```
## 🛑 A row that moves to other data (a new `key` or `title`) forgets a finger already on its pill, so a press begun on
##    one quest can never claim the next. `claim_pressed` carries the `key`, never an index bound when the row was made.
## 🛑 One press, one claim. The pill goes off after a press until the caller answers with `set_state()`, so a double
##    tap sends one request; a refused claim comes back with `set_state(State.READY)`.
## 🛑 The row decides nothing and keeps nothing: the caller says the state, the progress and what is paid, and a press
##    only asks.
## 🔤 The caller gives every word. The title wraps to at most two lines and shrinks (`GoStyle.fit_font_size`, never under
##    `GoConfig.fit_min_scale`); still too long there, it ends in an ellipsis. The claim word shrinks to fit its pill.
## ♿ No state rests on colour: each has its own mark, and `claimed_text` and `locked_text` go into the screen-reader name.
@tool
class_name GoRewardRow
extends PanelContainer

## The claim pill was pressed: [param id] is the row's [member key] at that moment. Never emitted twice for one READY.
signal claim_pressed(id: Variant)

enum State { IN_PROGRESS, READY, CLAIMED, LOCKED }

## The pill's look; a theme without it uses `GoPrimaryButton`.
const VAR_CLAIM := &"GoPillGreen"
## The well the row's picture sits in, in a look that does not paint the row.
const VAR_WELL := &"GoInsetPanel"
## The painted row's plates, by state. A theme without [constant VAR_ROW] draws the row with its own card.
const VAR_ROW := &"GoRewardRow"
const VAR_ROW_READY := &"GoRewardRowGold"
const VAR_ROW_DONE := &"GoRewardRowDone"
## The painted bar: `background` and `fill` on [constant VAR_BAR], the READY row's `fill` on [constant VAR_BAR_READY].
const VAR_BAR := &"GoRewardBar"
const VAR_BAR_READY := &"GoRewardBarGreen"
## The painted row's lettering: the Rankings table's.
const VAR_TEXT := &"GoScoreTableLabel"
## The width (dp) from which the row stands on one line. Narrower, the bar and the payment go under the title.
const WIDE_WIDTH := 780.0
## A claimed or locked row's opacity in a look that does not paint it. Its mark stays at full strength.
const DIM_ALPHA := 0.55
## The title's lines, at most.
const TITLE_LINES := 2
## The picture's well, the picture in it and the end column's width (dp).
const WELL_SIZE := 44.0
const ICON_SIZE := 30
const SLOT_WIDTH := 96.0
## The padding a row's card keeps at most, and a claim pill's at the sides (dp). A card's and a pill's own padding is
## meant for a dialog and a menu; a phone row needs that width for the title and the claim word.
const CARD_PAD := 12.0
const PILL_PAD := 8.0
## The small picture before the amount, the state mark and the bar's thickness (dp).
const REWARD_ICON_SIZE := 18
const MARK_SIZE := 34
const BAR_THICKNESS := 10
## The painted row's content height, its picture, the coin, the check, the pill and the bar's thickness (dp). Narrower than
## [constant WIDE_WIDTH] the picture and the bar give way, so a title and the bar both stand in that height.
const ART_BODY := 62.0
const ART_ICON_SIZE := 56
const ART_NARROW_ICON_SIZE := 44
const ART_COIN_SIZE := 30
const ART_MARK_SIZE := 50
const ART_PILL_HEIGHT := 48.0
const ART_BAR_THICKNESS := 26
const ART_NARROW_BAR_THICKNESS := 12
## On one line: the columns that keep a stack of rows lined up (dp), and the bar's column against the title's.
const WIDE_SLOT_WIDTH := 122.0
const WIDE_PAY_WIDTH := 84.0
const WIDE_FRACTION_WIDTH := 66.0
const WIDE_PROGRESS_SHARE := 0.85
## The painted numbers against the title's full size.
const ART_NUMBER_SHARE := 0.9

## The row's words, wrapped and shrunk to fit.
@export var title := "":
	set(value):
		if value == title: return
		title = value
		_drop_press()
		_queue_refresh()

## A picture name: the skin's art of that name (`GoSkin.widget_art`), else the icon set's (`GoIconSet.STAR`…).
@export var icon: StringName = &"":
	set(value):
		icon = value
		_queue_refresh()

## The picture itself. Null: [member icon].
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_queue_refresh()

@export var state := State.IN_PROGRESS:
	set(value):
		var moved := value != state
		state = value
		_claim_sent = false
		if moved: _drop_press()
		_queue_refresh()

## The word on the claim pill.
@export var claim_text := "":
	set(value):
		claim_text = value
		_queue_refresh()

## Spoken for a claimed row and a locked one (never drawn: the marks say it). Empty: the state goes unspoken.
@export var claimed_text := "":
	set(value):
		claimed_text = value
		_queue_refresh()
@export var locked_text := "":
	set(value):
		locked_text = value
		_queue_refresh()

## 🔔 What a claim press says through `GoFeedback`.
@export var feedback: StringName = GoFeedback.CONFIRMED:
	set(value):
		feedback = value
		if claim_button != null: claim_button.feedback = value

## The caller's name for what this row shows now (a quest's id). `claim_pressed` hands it back. Any value; setting a
## different one means the row now shows other data.
var key: Variant = null:
	set(value):
		var moved: bool = typeof(value) != typeof(key) or value != key
		key = value
		if moved:
			_claim_sent = false
			_drop_press()
			_queue_refresh()

## The parts, for tests and for a game placing something over them.
var title_label: Label
var bar: GoBar
## The `3 / 5` beside the bar.
var fraction_label: Label
var claim_button: GoGlyphButton
var reward_row: HBoxContainer
var reward_label: Label
## The padlock's holder, and the check's: the picture `check_green`, else a `GoBadge` sticker hung from it.
var lock_mark: Control
var check_host: Control

var _reward_amount := 0.0
var _reward_icon: StringName = &""
var _reward_texture: Texture2D
var _well: PanelContainer
var _well_art: Control
var _reward_art: Control
var _slot: VBoxContainer
var _marks: Control
## Side by side on one line, stacked below [constant WIDE_WIDTH]: `vertical` follows the width.
var _text: BoxContainer
var _progress: HBoxContainer
## The payment's column on one line. It stays when a row pays nothing, so the columns of a stack still line up.
var _pay: HBoxContainer
var _row: HBoxContainer
var _wide := false
var _has_target := true
## What each holder shows now (holder → its key), so a row bound again rebuilds no picture that stayed the same.
var _shown := {}
var _claim_sent := false
## The look the row's own faces were cut for.
var _faces_of: Theme
var _queued := false
var _built := false


func _init() -> void:
	name = "RewardRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = GoTheme.VAR_CARD
	_build()
	_built = true
	resized.connect(_on_resized)
	_refresh()


func _build() -> void:
	_row = _box(HBoxContainer.new(), "Row")
	add_child(_row)

	_well = PanelContainer.new()
	_well.name = "Well"
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.custom_minimum_size = Vector2(WELL_SIZE, WELL_SIZE)
	_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_well)
	_well_art = _holder("Picture", ICON_SIZE)
	_well_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_well_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_well.add_child(_well_art)

	_text = _box(BoxContainer.new(), "Text")
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_text)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override(&"line_spacing", 0)
	title_label.resized.connect(_fit_title)
	_text.add_child(title_label)
	_progress = _box(HBoxContainer.new(), "Progress")
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_stretch_ratio = WIDE_PROGRESS_SHARE
	_text.add_child(_progress)
	bar = GoBar.new()
	bar.segments = 0
	bar.thickness = BAR_THICKNESS
	bar.readout = GoBar.Readout.NONE
	bar.icon_beside = true   # no name row: the fraction stands beside the bar, and the title has that line
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.add_child(bar)
	fraction_label = GoStyle.one_line(Label.new())
	fraction_label.name = "Fraction"
	fraction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fraction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fraction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 🛑 As `GoBar`'s own readout: `3 / 5` keeps its order in Arabic too.
	fraction_label.text_direction = Control.TEXT_DIRECTION_LTR
	fraction_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_progress.add_child(fraction_label)

	_pay = _box(HBoxContainer.new(), "Pay")
	_row.add_child(_pay)
	_slot = _box(VBoxContainer.new(), "Slot")
	_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_slot)
	reward_row = _box(HBoxContainer.new(), "Reward")
	_pay.add_child(reward_row)
	_reward_art = _holder("Picture", REWARD_ICON_SIZE)
	_reward_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(_reward_art)
	reward_label = GoStyle.one_line(Label.new())
	reward_label.name = "Amount"
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 🛑 A number reads left to right in every language, and a caller's amount is not a translation key.
	reward_label.text_direction = Control.TEXT_DIRECTION_LTR
	reward_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	reward_row.add_child(reward_label)

	claim_button = GoGlyphButton.make("", &"", GoTheme.VAR_PRIMARY_BUTTON)
	claim_button.name = "Claim"
	claim_button.fit_label = true
	claim_button.glow = true
	claim_button.feedback = feedback
	# 🛑 Without this the words set the pill's least width, and a long translation would push the title off the row.
	claim_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	claim_button.pressed.connect(_on_claim)
	_slot.add_child(claim_button)

	_marks = Control.new()
	_marks.name = "Marks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(_marks)
	lock_mark = _holder("Lock", MARK_SIZE)
	_marks.add_child(lock_mark)
	lock_mark.set_anchors_preset(Control.PRESET_CENTER)
	check_host = _holder("Check", 0)
	_marks.add_child(check_host)
	check_host.set_anchors_preset(Control.PRESET_CENTER)


func _box(node: BoxContainer, part: String) -> BoxContainer:
	node.name = part
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_meta(&"go_own_spacing", true)   # a `GoForm`'s wide gap would break the fixed height
	return node


func _holder(part: String, side: int) -> Control:
	var node := Control.new()
	node.name = part
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(side, side)
	return node


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _ready() -> void:
	_refresh()


func _on_resized() -> void:
	if (size.x >= WIDE_WIDTH) != _wide: _queue_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _built: _queue_refresh()


func _on_ui_changed() -> void:
	_shown.clear()
	_queue_refresh()


## A row titled [param text] with the picture [param picture], in [param row_state].
static func make(text: String, picture: StringName = &"", row_state := State.IN_PROGRESS) -> GoRewardRow:
	var node := GoRewardRow.new()
	node.title = text
	node.icon = picture
	node.state = row_state
	return node


## 📏 Every row's height under the current look and `GoConfig` — the extent to give `GoListView`, at any width. It has
## room for two title lines at full size, a touch-sized pill, and below [constant WIDE_WIDTH] two title lines at the fit
## floor over the bar, so no words can change it.
static func extent() -> float:
	return ceilf(_rim_height() + _body_height())


## The look's card with its padding held to [constant CARD_PAD]: a copy, faces are shared.
static func _card_face() -> StyleBox:
	var card := _face(GoTheme.VAR_CARD, &"panel")
	if card == null: return null
	var own := card.duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		own.set_content_margin(side, minf(card.get_margin(side), CARD_PAD))
	return own


## Whether the look paints the row (see the top of this file).
static func _painted() -> bool:
	var look := GoUi.theme()
	return look != null and look.has_stylebox(&"panel", VAR_ROW)


## The height the row's plate or card keeps for itself.
static func _rim_height() -> float:
	var painted := _painted()
	var plate := _face(VAR_ROW if painted else GoTheme.VAR_CARD, &"panel")
	if plate == null: return 0.0
	var top := plate.get_margin(SIDE_TOP)
	var bottom := plate.get_margin(SIDE_BOTTOM)
	return top + bottom if painted else minf(top, CARD_PAD) + minf(bottom, CARD_PAD)


## The height inside the rim.
static func _body_height() -> float:
	var least := ART_BODY if _painted() else WELL_SIZE
	return maxf(least, maxf(_title_height(_title_size()), maxf(_text_height(), _slot_height())))


static func _line_height(px: int) -> float:
	return _text_font().get_height(px)


## The font the row's title and numbers are measured in.
static func _text_font() -> Font:
	var look := GoUi.theme()
	if _painted(): return look.get_font(&"font", VAR_TEXT)
	return GoStyle._fit_font()


## The title's full size.
static func _title_size() -> int:
	if GoUi.config.base_font_size > 0 or not _painted(): return GoUi.font_size(GoTheme.ROLE_BODY)
	return GoUi.theme().get_font_size(&"font_size", VAR_TEXT)


## The height of the title's lines at [param px].
static func _title_height(px: int) -> float:
	return ceilf(_line_height(px) * TITLE_LINES)


## The line under the title below [constant WIDE_WIDTH]: the bar, its fraction and the payment.
static func _progress_height() -> float:
	var bar_side := ART_NARROW_BAR_THICKNESS if _painted() else BAR_THICKNESS
	return maxf(_line_height(GoUi.font_size(GoTheme.ROLE_COMPACT)), maxf(bar_side, _coin_side(false)))


## Below [constant WIDE_WIDTH]: the title at the fit floor over the line under it.
static func _text_height() -> float:
	var gap := 0.0 if _painted() else float(GoUi.metric(GoTheme.GAP_TINY))
	return _title_height(GoStyle.fit_floor(_title_size())) + gap + _progress_height()


static func _slot_height() -> float:
	var pill := _face(claim_variation(), &"normal")
	return maxf(_pill_height(), pill.get_minimum_size().y if pill != null else 0.0)


## The claim pill's height: the touch floor, and on the painted row its own chunkier size.
static func _pill_height() -> float:
	return maxf(GoUi.touch_size(), ART_PILL_HEIGHT if _painted() else 0.0)


## The coin's side: big on the painted row's one line, small on the line under a title.
static func _coin_side(wide: bool) -> int:
	return ART_COIN_SIZE if wide and _painted() else REWARD_ICON_SIZE


## The face [param part] of the theme type [param type], climbing its variation chain. Null when none has it.
static func _face(type: StringName, part: StringName) -> StyleBox:
	var look := GoUi.theme()
	var hop := type
	while look != null and not hop.is_empty():
		if look.has_stylebox(part, hop): return look.get_stylebox(part, hop)
		hop = look.get_type_variation_base(hop)
	return null


static func _has_type(type: StringName) -> bool:
	var look := GoUi.theme()
	if look == null: return false
	return look.get_type_list().has(type) or not String(look.get_type_variation_base(type)).is_empty()


## The theme variation the claim pill wears under the current look.
static func claim_variation() -> StringName:
	return VAR_CLAIM if _has_type(VAR_CLAIM) else GoTheme.VAR_PRIMARY_BUTTON


## The progress: the bar at [param value] of [param target] and its fraction. A [param target] of 0 or less hides them
## (an achievement with no count). Off by default, [param animate]: a row bound to other data must not slide there.
func set_progress(value: float, target: float, animate := false) -> void:
	_has_target = target > 0.0
	bar.set_values(value, target, animate)
	_queue_refresh()


## What the row pays: [param amount] with the picture [param picture] (a name, as [member icon]) or [param texture].
## An [param amount] of 0 or less shows no payment.
func set_reward(amount: float, picture: StringName = GoIconSet.COIN, texture: Texture2D = null) -> void:
	_reward_amount = amount
	_reward_icon = picture
	_reward_texture = texture
	_queue_refresh()


## Says the row's state. 🔑 Call it again with the same state after a refused claim: that re-arms the pill.
func set_state(value: State) -> void:
	state = value


func set_claim_text(text: String) -> void:
	claim_text = text


## Cuts the row's own card and pill for the current look, once per look.
func _dress_faces() -> void:
	var look := GoUi.theme()
	if look == _faces_of: return
	_faces_of = look
	var painted := _painted()
	# 🔑 A plate is the row's own theme type: the row reads it from the look wherever it stands.
	theme = look if painted else null
	var card := _card_face()
	if painted or card == null: remove_theme_stylebox_override(&"panel")
	else: add_theme_stylebox_override(&"panel", card)
	var variation := claim_variation()
	claim_button.theme_type_variation = variation
	for part: StringName in GoGlyphButton.TEXT_STATES:
		var face := _face(variation, part)
		if face == null: continue
		var own := face.duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_RIGHT]: own.set_content_margin(side, minf(face.get_margin(side), PILL_PAD))
		claim_button.add_theme_stylebox_override(part, own)
	claim_button.fit_padding = PILL_PAD * 2.0


## One line or two, for the row's width: the payment's home and the columns that hold a stack of rows in line.
func _place_columns(gap: int, tiny: int, coin: int) -> void:
	_text.vertical = not _wide
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	var home: Container = _pay if _wide else _progress
	if reward_row.get_parent() != home: reward_row.reparent(home, false)
	_pay.visible = _wide
	_pay.custom_minimum_size.x = WIDE_PAY_WIDTH if _wide else 0.0
	# A painted plate already holds its content off the edge: below [constant WIDE_WIDTH] its parts sit a tiny gap apart, so
	# the row still fits a 320dp phone inside a form.
	_row.add_theme_constant_override(&"separation", gap if _wide or not _painted() else tiny)
	_text.add_theme_constant_override(&"separation", gap if _wide else 0 if _painted() else tiny)
	_slot.add_theme_constant_override(&"separation", tiny)
	reward_row.add_theme_constant_override(&"separation", tiny)
	_progress.add_theme_constant_override(&"separation", gap if _wide else tiny)
	_slot.custom_minimum_size.x = WIDE_SLOT_WIDTH if _wide else SLOT_WIDTH
	fraction_label.custom_minimum_size.x = WIDE_FRACTION_WIDTH if _wide else 0.0
	_reward_art.custom_minimum_size = Vector2(coin, coin)


## The row's plate, or its card and the claimed row's dimming.
func _dress_plate(painted: bool, done: bool) -> void:
	if painted: theme_type_variation = VAR_ROW_DONE if done else VAR_ROW_READY if state == State.READY else VAR_ROW
	else: theme_type_variation = GoTheme.VAR_CARD
	var alpha := DIM_ALPHA if done and not painted else 1.0
	for part: Control in [_well, _text, reward_row]: part.modulate.a = alpha


## The picture's well: a plated hollow in a look that does not paint the row, nothing at all behind a painted picture.
func _dress_well(painted: bool, side: float) -> void:
	var plated := not painted and _has_type(VAR_WELL)
	_well.theme_type_variation = VAR_WELL if plated else &""
	if plated: _well.remove_theme_stylebox_override(&"panel")
	elif not _well.has_theme_stylebox_override(&"panel"): GoStyle.bare_panel(_well)
	_well.custom_minimum_size = Vector2(side, side)


func _dress_bar(painted: bool, ready_now: bool, claimed: bool) -> void:
	bar.visible = _has_target
	if painted:
		bar.ink = Color.TRANSPARENT
		bar.thickness = ART_BAR_THICKNESS if _wide else ART_NARROW_BAR_THICKNESS
		bar.set_faces(_face(VAR_BAR, &"background"), _face(VAR_BAR_READY if ready_now else VAR_BAR, &"fill"))
		return
	bar.set_faces(null, null)
	bar.thickness = BAR_THICKNESS
	bar.ink = GoUi.color(GoTheme.SUCCESS_FILL) if ready_now or claimed else Color.TRANSPARENT


## [param label] in the row's lettering at [param px]: the Rankings' navy, or the look's [param role] in [param ink].
func _letter(label: Label, painted: bool, role: StringName, ink: Color, px: int) -> void:
	if painted:
		label.theme = GoUi.theme()
		label.theme_type_variation = VAR_TEXT
		label.remove_theme_color_override(&"font_color")
	else:
		GoStyle.typography(label, role, ink)
	label.add_theme_font_size_override(&"font_size", px)


## A number's size: the painted row's big numbers on one line, else the small line under the title.
func _number_size(painted: bool, role: StringName) -> int:
	if painted and _wide: return roundi(_title_size() * ART_NUMBER_SHARE)
	return GoUi.font_size(role if _wide else GoTheme.ROLE_COMPACT)


## Applies the pending changes now instead of at the end of the frame.
func refresh() -> void:
	_refresh()


## 🛑 A finger may already be down on the pill: the engine forgets a press when its button is disabled.
func _drop_press() -> void:
	if claim_button == null: return
	claim_button.disabled = true
	claim_button.disabled = _claim_sent


func _on_claim() -> void:
	if state != State.READY or _claim_sent: return
	_claim_sent = true
	claim_button.disabled = true
	claim_pressed.emit(key)


func _queue_refresh() -> void:
	if not _built or _queued: return
	_queued = true
	_flush.call_deferred()


func _flush() -> void:
	if _queued: _refresh()


func _refresh() -> void:
	if not _built: return
	_queued = false
	var ready_now := state == State.READY
	var claimed := state == State.CLAIMED
	var locked := state == State.LOCKED
	var painted := _painted()
	_dress_faces()
	var height := extent()
	custom_minimum_size.y = height
	var ink := GoUi.color(GoTheme.TEXT)
	_wide = size.x >= WIDE_WIDTH
	var coin := _coin_side(_wide)
	_place_columns(GoUi.metric(GoTheme.GAP_SMALL), GoUi.metric(GoTheme.GAP_TINY), coin)
	_dress_plate(painted, claimed or locked)

	var picture: int = ICON_SIZE
	var well := WELL_SIZE
	if painted:
		picture = ART_ICON_SIZE if _wide else ART_NARROW_ICON_SIZE
		well = float(picture)
	_dress_well(painted, well)
	_well_art.custom_minimum_size = Vector2(picture, picture)
	_show(_well_art, icon_texture, icon, picture, ink)

	title_label.text = title
	_letter(title_label, painted, GoTheme.ROLE_BODY, ink, _title_size())
	_dress_bar(painted, ready_now, claimed)
	fraction_label.visible = _has_target
	fraction_label.text = GoUi.text(&"bar_fraction").format({
		"value": GoBar.format_amount(bar.value()), "max": GoBar.format_amount(bar.maximum())})
	_letter(fraction_label, painted, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED),
		_number_size(painted, GoTheme.ROLE_COMPACT))
	if _wide: _fit_one_line(fraction_label, WIDE_FRACTION_WIDTH)

	var paying := _reward_amount > 0.0
	reward_row.visible = paying
	reward_label.text = GoBar.format_amount(_reward_amount)
	_letter(reward_label, painted, GoTheme.ROLE_BODY, ink, _number_size(painted, GoTheme.ROLE_BODY))
	_show(_reward_art, _reward_texture, _reward_icon, coin, ink)
	_fit_one_line(reward_label, (WIDE_PAY_WIDTH if _wide else SLOT_WIDTH) - coin - GoUi.metric(GoTheme.GAP_TINY))

	_progress.visible = _has_target or (paying and not _wide)
	title_label.custom_minimum_size.y = _title_box(height)
	_fit_title()

	var slot_width: float = WIDE_SLOT_WIDTH if _wide else SLOT_WIDTH
	var mark: int = ART_MARK_SIZE if painted else MARK_SIZE
	_slot.visible = _wide or ready_now or claimed or locked
	claim_button.visible = ready_now
	claim_button.text = claim_text
	claim_button.fit_base_size = 0 if painted and _wide else GoUi.font_size(GoTheme.ROLE_BODY)
	claim_button.custom_minimum_size = Vector2(slot_width, _pill_height())
	claim_button.disabled = _claim_sent

	_marks.visible = claimed or locked
	_marks.custom_minimum_size = Vector2(slot_width, mark)
	lock_mark.visible = locked
	check_host.visible = claimed
	if locked:
		_center_mark(lock_mark, mark)
		_show(lock_mark, null, &"lock", mark, ink, GoIconSet.LOCK)
	if claimed: _show_check(mark, ink)

	var said := [title]
	if _has_target: said.append(fraction_label.text)
	if ready_now: said.append(claim_text)
	elif claimed: said.append(claimed_text)
	elif locked: said.append(locked_text)
	accessibility_name = GoUi.spoken(said)


## The title's box: the whole height on one line, what the line under it leaves when it stands over that line.
func _title_box(height: float) -> float:
	var room := height - _rim_height()
	if _wide or not _progress.visible: return minf(room, _title_height(_title_size()))
	var gap := 0.0 if _painted() else float(GoUi.metric(GoTheme.GAP_TINY))
	return room - gap - _progress_height()


## [param holder] centred in the marks' column, [param side] square.
func _center_mark(holder: Control, side: float) -> void:
	holder.custom_minimum_size = Vector2(side, side)
	holder.offset_left = -side * 0.5
	holder.offset_right = side * 0.5
	holder.offset_top = -side * 0.5
	holder.offset_bottom = side * 0.5


## The check: the skin's sticker, else a `GoBadge` on a host of no size — a badge's centre sits on its host's top-right
## corner, so that centres it in the column.
func _show_check(side: int, ink: Color) -> void:
	var art := GoUi.skin().widget_art(&"check_green")
	_center_mark(check_host, side if art != null else 0)
	_show(check_host, art, &"", side, ink)
	if art == null and not check_host.has_meta(&"gohud_badge"):
		GoBadge.stick(check_host, "", GoUi.color(GoTheme.SUCCESS_FILL), 0.0, GoIconSet.CHECK)


## Puts a picture in [param holder]: [param given], else the skin's art named [param picture], else the icon set's
## [param fallback] (or that name) in [param ink]. Nothing to show leaves it empty.
func _show(holder: Control, given: Texture2D, picture: StringName, side: int, ink: Color,
		fallback: StringName = &"") -> void:
	var art := given
	if art == null and not picture.is_empty(): art = GoUi.skin().widget_art(picture)
	var glyph := fallback if not fallback.is_empty() else picture
	var wanted := "%s|%s|%s|%d" % [art.get_rid() if art != null else "", glyph, ink.to_html(), side]
	if _shown.get(holder, "") == wanted: return
	_shown[holder] = wanted
	for child in holder.get_children(): child.free()
	if art != null:
		var rect := TextureRect.new()
		rect.texture = art
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif not glyph.is_empty() and GoUi.icons().has_icon(glyph):
		var node := GoUi.icons().node(glyph, side, ink)
		holder.add_child(node)
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The title's size: the biggest from its full size down to the fit floor at which it wraps into its box, no word
## broken.
func _fit_title() -> void:
	var room := title_label.size.x
	if room <= 0.0 or not title_label.is_inside_tree(): return
	var shown := atr(title)
	var font := title_label.get_theme_font(&"font")
	var base := _title_size()
	# Laid end to end it must fit two lines' width — then measured wrapped: a wrap leaves room at each line's end.
	var px := GoStyle.fit_font_size(PackedStringArray([shown]), base, room * TITLE_LINES, font)
	var bottom := GoStyle.fit_floor(base)
	var box := title_label.custom_minimum_size.y
	var words := shown.replace("-", " ").split(" ", false)
	while px > bottom and (_wrapped_lines(shown, font, px, room) > _lines_held(box, font, px)
			or _widest(words, font, px) > room): px -= 1
	title_label.add_theme_font_size_override(&"font_size", px)
	title_label.max_lines_visible = _lines_held(box, font, px)


## How many lines at [param px] stand in a box [param box] tall.
func _lines_held(box: float, font: Font, px: int) -> int:
	return clampi(floori(box / font.get_height(px)), 1, TITLE_LINES)


func _wrapped_lines(words: String, font: Font, px: int, room: float) -> int:
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var tall := font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, room, px, -1, flags).y
	return roundi(tall / font.get_height(px))


func _widest(words: PackedStringArray, font: Font, px: int) -> float:
	var most := 0.0
	for word in words: most = maxf(most, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	return most


## Shrinks a one-line [param label] from the size it wears to fit [param room]. Past the floor it asks for more: a
## number is never cut, its neighbour (the bar) gives way.
func _fit_one_line(label: Label, room: float) -> void:
	if not label.is_inside_tree(): return
	var base := label.get_theme_font_size(&"font_size")
	label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(
		PackedStringArray([label.text]), base, room, label.get_theme_font(&"font")))
