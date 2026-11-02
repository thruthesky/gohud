## 🎁 **A reward row** — one thing a player earns by progress: a daily quest, an achievement, a season task. A picture,
## a title, a progress bar with its `3 / 5`, what it pays, and at the end the row's state.
##
## ```gdscript
## var quest := GoRewardRow.make("Win 3 matches", GoIconSet.STAR)
## quest.set_progress(1, 3)
## quest.set_reward(50, GoIconSet.COIN)
## quest.set_claim_text("CLAIM")
## quest.set_state(GoRewardRow.State.READY)
## quest.key = "win_3"
## quest.claim_pressed.connect(func(id: Variant) -> void: server.claim(id))
## ```
##
## | `state` | What it shows |
## |---|---|
## | `IN_PROGRESS` | the bar and its fraction |
## | `READY` | the glowing claim pill (`GoPillGreen`; a look without it uses `GoPrimaryButton`) |
## | `CLAIMED` | the check sticker, on a dimmed row |
## | `LOCKED` | the padlock, on a dimmed row |
##
## ## 🔑 In a long list
## Every row is [method extent] tall whatever its words, so it fits `GoListView` as well as a `GoScroll`:
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
## 		row.set_reward(quests[index].coins, GoIconSet.COIN)
## 		row.set_claim_text("CLAIM")
## 		row.set_state(quests[index].state))
## ```
## 🛑 A row that moves to other data (a new `key` or `title`) forgets a finger already on its pill, so a press begun on
##    one quest can never claim the next. `claim_pressed` carries the `key`, never an index bound when the row was made.
## 🛑 One press, one claim. The pill goes off after a press until the caller answers with `set_state()`, so a double
##    tap sends one request; a refused claim comes back with `set_state(State.READY)`.
## 🛑 The row decides nothing and keeps nothing: the caller says the state, the progress and what is paid, and a press
##    only asks.
## 🔤 The caller gives every word. The title wraps and shrinks (`GoStyle.fit_font_size`, never under
##    `GoConfig.fit_min_scale`): two lines at full size, three at the floor; still too long there, it ends in an
##    ellipsis. The claim word shrinks to fit its pill.
## ♿ No state rests on colour: each has its own mark, and `claimed_text` and `locked_text` go into the screen-reader name.
@tool
class_name GoRewardRow
extends PanelContainer

## The claim pill was pressed: [param id] is the row's [member key] at that moment. Never emitted twice for one READY.
signal claim_pressed(id: Variant)

enum State { IN_PROGRESS, READY, CLAIMED, LOCKED }

## The pill's look; a theme without it uses `GoPrimaryButton`.
const VAR_CLAIM := &"GoPillGreen"
## The well the row's picture sits in.
const VAR_WELL := &"GoInsetPanel"
## A claimed or locked row's opacity. Its mark stays at full strength.
const DIM_ALPHA := 0.55
## The title's lines at full size, and at the smallest size it shrinks to.
const TITLE_LINES := 2
const TITLE_LINES_AT_FLOOR := 3
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
## The padlock's holder, and the anchor the check sticker (a `GoBadge`) hangs from.
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
var _text: VBoxContainer
var _progress: HBoxContainer
var _row: HBoxContainer
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

	_text = _box(VBoxContainer.new(), "Text")
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_text)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override(&"line_spacing", 0)
	title_label.resized.connect(_fit_title)
	_text.add_child(title_label)
	_progress = _box(HBoxContainer.new(), "Progress")
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
	# 🛑 As `GoBar`'s own readout: `3 / 5` keeps its order in Arabic too.
	fraction_label.text_direction = Control.TEXT_DIRECTION_LTR
	fraction_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_progress.add_child(fraction_label)

	_slot = _box(VBoxContainer.new(), "Slot")
	_slot.custom_minimum_size.x = SLOT_WIDTH
	_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_slot)
	reward_row = _box(HBoxContainer.new(), "Reward")
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot.add_child(reward_row)
	_reward_art = _holder("Picture", REWARD_ICON_SIZE)
	_reward_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(_reward_art)
	reward_label = GoStyle.one_line(Label.new())
	reward_label.name = "Amount"
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_marks.custom_minimum_size = Vector2(SLOT_WIDTH, MARK_SIZE)
	_slot.add_child(_marks)
	lock_mark = _holder("Lock", MARK_SIZE)
	_marks.add_child(lock_mark)
	lock_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	lock_mark.offset_left = -MARK_SIZE * 0.5
	lock_mark.offset_right = MARK_SIZE * 0.5
	lock_mark.offset_top = -MARK_SIZE * 0.5
	lock_mark.offset_bottom = MARK_SIZE * 0.5
	# 🔑 A sticker's centre sits on its host's top-right corner, so a host of no size centres it in the column.
	check_host = Control.new()
	check_host.name = "Check"
	check_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.add_child(check_host)
	check_host.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	check_host.offset_left = 0.0
	check_host.offset_right = 0.0
	check_host.offset_top = 0.0
	check_host.offset_bottom = 0.0


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


## 📏 Every row's height under the current look and `GoConfig` — the extent to give `GoListView`. It has room for the
## two title lines over the bar, and for the amount over a touch-sized pill, so no words can change it.
static func extent() -> float:
	var card := _face(GoTheme.VAR_CARD, &"panel")
	var rim := 0.0
	if card != null:
		rim = minf(card.get_margin(SIDE_TOP), CARD_PAD) + minf(card.get_margin(SIDE_BOTTOM), CARD_PAD)
	return ceilf(rim + maxf(WELL_SIZE, maxf(_text_height(), _slot_height())))


## The look's card with its padding held to [constant CARD_PAD]: a copy, faces are shared.
static func _card_face() -> StyleBox:
	var card := _face(GoTheme.VAR_CARD, &"panel")
	if card == null: return null
	var own := card.duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		own.set_content_margin(side, minf(card.get_margin(side), CARD_PAD))
	return own


static func _line_height(role: StringName) -> float:
	return GoStyle._fit_font().get_height(GoUi.font_size(role))


## The title's box: the taller of its lines at full size and at the fit floor.
static func _title_height() -> float:
	var floor_size := GoStyle.fit_floor(GoUi.font_size(GoTheme.ROLE_BODY))
	return ceilf(maxf(_line_height(GoTheme.ROLE_BODY) * TITLE_LINES,
		GoStyle._fit_font().get_height(floor_size) * TITLE_LINES_AT_FLOOR))


static func _text_height() -> float:
	return _title_height() + GoUi.metric(GoTheme.GAP_TINY) + maxf(_line_height(GoTheme.ROLE_COMPACT), BAR_THICKNESS)


static func _slot_height() -> float:
	var pill := _face(claim_variation(), &"normal")
	var tall := maxf(GoUi.touch_size(), pill.get_minimum_size().y if pill != null else 0.0)
	var line := maxf(REWARD_ICON_SIZE, _line_height(GoTheme.ROLE_BODY))
	return line + GoUi.metric(GoTheme.GAP_TINY) + maxf(tall, MARK_SIZE)


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
	_progress.visible = target > 0.0
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
	var card := _card_face()
	if card != null: add_theme_stylebox_override(&"panel", card)
	var variation := claim_variation()
	claim_button.theme_type_variation = variation
	for part: StringName in GoGlyphButton.TEXT_STATES:
		var face := _face(variation, part)
		if face == null: continue
		var own := face.duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_RIGHT]: own.set_content_margin(side, minf(face.get_margin(side), PILL_PAD))
		claim_button.add_theme_stylebox_override(part, own)
	claim_button.fit_padding = PILL_PAD * 2.0


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
	_dress_faces()
	custom_minimum_size.y = extent()
	var gap := GoUi.metric(GoTheme.GAP_SMALL)
	var tiny := GoUi.metric(GoTheme.GAP_TINY)
	_row.add_theme_constant_override(&"separation", gap)
	_text.add_theme_constant_override(&"separation", tiny)
	_slot.add_theme_constant_override(&"separation", tiny)
	reward_row.add_theme_constant_override(&"separation", tiny)
	_progress.add_theme_constant_override(&"separation", tiny)

	var ink := GoUi.color(GoTheme.TEXT)
	if _has_type(VAR_WELL): _well.theme_type_variation = VAR_WELL
	else: GoStyle.bare_panel(_well)
	_show(_well_art, icon_texture, icon, ICON_SIZE, ink)

	title_label.text = title
	GoStyle.typography(title_label, GoTheme.ROLE_BODY, ink)
	title_label.custom_minimum_size.y = _title_height()
	bar.ink = GoUi.color(GoTheme.SUCCESS_FILL) if ready_now or claimed else Color.TRANSPARENT
	fraction_label.text = GoUi.text(&"bar_fraction").format({
		"value": GoBar.format_amount(bar.value()), "max": GoBar.format_amount(bar.maximum())})
	GoStyle.typography(fraction_label, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED))
	_fit_title()

	reward_row.visible = _reward_amount > 0.0
	reward_label.text = GoBar.format_amount(_reward_amount)
	GoStyle.typography(reward_label, GoTheme.ROLE_BODY, ink)
	_show(_reward_art, _reward_texture, _reward_icon, REWARD_ICON_SIZE, ink)
	_fit_reward()

	claim_button.visible = ready_now
	claim_button.text = claim_text
	claim_button.fit_base_size = GoUi.font_size(GoTheme.ROLE_BODY)
	claim_button.custom_minimum_size = Vector2(SLOT_WIDTH, GoUi.touch_size())
	claim_button.disabled = _claim_sent

	_marks.visible = claimed or locked
	lock_mark.visible = locked
	check_host.visible = claimed
	if locked: _show(lock_mark, null, &"lock", MARK_SIZE, ink, GoIconSet.LOCK)
	if claimed and not check_host.has_meta(&"gohud_badge"):
		GoBadge.stick(check_host, "", GoUi.color(GoTheme.SUCCESS_FILL), 0.0, GoIconSet.CHECK)

	var alpha := DIM_ALPHA if claimed or locked else 1.0
	for part: Control in [_well, _text, reward_row]: part.modulate.a = alpha

	var said := [title]
	if _progress.visible: said.append(fraction_label.text)
	if ready_now: said.append(claim_text)
	elif claimed: said.append(claimed_text)
	elif locked: said.append(locked_text)
	accessibility_name = GoUi.spoken(said)


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


## The title's size: the biggest from the body role down to the fit floor at which it wraps into its box.
func _fit_title() -> void:
	var room := title_label.size.x
	if room <= 0.0 or not title_label.is_inside_tree(): return
	var shown := atr(title)
	var font := title_label.get_theme_font(&"font")
	var base := GoUi.font_size(GoTheme.ROLE_BODY)
	# Laid end to end it must fit two lines' width — then measured wrapped: a wrap leaves room at each line's end.
	var px := GoStyle.fit_font_size(PackedStringArray([shown]), base, room * TITLE_LINES, font)
	var bottom := GoStyle.fit_floor(base)
	var box := title_label.custom_minimum_size.y
	while px > bottom and _wrapped_lines(shown, font, px, room) > _lines_held(box, font, px): px -= 1
	title_label.add_theme_font_size_override(&"font_size", px)
	title_label.max_lines_visible = _lines_held(box, font, px)


## How many lines at [param px] stand in a box [param box] tall.
func _lines_held(box: float, font: Font, px: int) -> int:
	return clampi(floori(box / font.get_height(px)), 1, TITLE_LINES_AT_FLOOR)


func _wrapped_lines(words: String, font: Font, px: int, room: float) -> int:
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var tall := font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, room, px, -1, flags).y
	return roundi(tall / font.get_height(px))


func _fit_reward() -> void:
	var room := SLOT_WIDTH - REWARD_ICON_SIZE - GoUi.metric(GoTheme.GAP_TINY)
	var font := reward_label.get_theme_font(&"font") if reward_label.is_inside_tree() else null
	reward_label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(
		PackedStringArray([reward_label.text]), GoUi.font_size(GoTheme.ROLE_BODY), room, font))
