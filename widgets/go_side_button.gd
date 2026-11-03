## 🧭 **A side menu key** — a big painted picture, a short outlined word under it and a count on the picture's corner:
## the DAILY QUESTS and ACHIEVEMENTS keys standing down the side of a game's main menu, a shop key, an event key.
##
## ```gdscript
## var daily := GoSideButton.make("DAILY", GoUi.skin().widget_art(&"menu_daily"))
## daily.picture_size = 76            # the picture's square (dp)
## daily.label_width = 120            # the word shrinks to this width, never under the fit floor
## daily.pressed.connect(open_quests.bind("daily"))
## menu.add_child(daily)
## daily.set_badge(3)                  # a GoBadge on the art's top-right corner; 0 hides it, a new count pops
## ```
##
## No plate: the picture is the key. It darkens to `GoSkin.picture_press_tint()` while held and pops with the look's
## press feel (`GoStyle.press_feel`); a disabled key fades. The word is the look's outlined HUD text (`GoOutlineLabel`
## in arcade_light), so it reads on a busy backdrop; a look without it takes the name plate's ink and edge.
## The whole node takes the press, picture and word, and is never smaller than `GoUi.touch_size()` either way.
## 🔤 The word shrinks to `label_width` (`GoStyle.fit_font_size`, never under `GoConfig.fit_min_scale`) and never wraps:
##    give it the room the longest language needs at the floor.
## 🛑 Display only: the key reports `pressed`, and the count is the caller's (a server's number of rewards to claim).
## 🔑 Under arcade_light it stays out of the focus order, as the look's other keys do (`GoStyle.skin_focus`); a look
##    that keeps focus draws its `Button` focus ring round the whole key.
@tool
class_name GoSideButton
extends BaseButton

## The room between the picture and the word (dp).
const GAP := 2.0
## A disabled key's opacity.
const DISABLED_ALPHA := 0.5
## How far the count's centre sits in from the picture's top-right corner, as a share of `picture_size` (each way): a
## painted picture rarely fills its square's corner, so a badge straddling the very corner floated beside the art (a
## calendar's rounded top, a trophy's handle). Here it sits on the art's corner and hangs about a third past it.
const BADGE_INSET := 0.12

## The word under the picture (already translated: the key shows it as it is, and says it to a screen reader).
@export var text := "":
	set(value):
		text = value
		_queue_layout()

## The picture that is the key (a skin's `widget_art`, the game's own art). It keeps its aspect inside the square.
@export var art: Texture2D = null:
	set(value):
		art = value
		if is_instance_valid(picture): picture.texture = value

## The side of the picture's square (dp).
@export_range(16, 512) var picture_size := 72:
	set(value):
		picture_size = value
		_queue_layout()

## The width the word shrinks into (dp). 0: one and a half pictures wide.
@export_range(0.0, 1024.0) var label_width := 0.0:
	set(value):
		label_width = maxf(0.0, value)
		_queue_layout()

## The word's size before it shrinks (dp). 0: the look's `button` role.
@export_range(0, 128) var font_size := 0:
	set(value):
		font_size = value
		_queue_layout()

## The text role of the count on the picture's corner: bigger than a list's badge, as the key is — a bold count about
## as big as the word, as a mobile game's event key wears it.
@export var badge_role := GoTheme.ROLE_SUBTITLE:
	set(value):
		badge_role = value
		_dress_badge(badge())

## 🔔 What the player's press says through `GoFeedback`. Empty: silent.
@export var feedback: StringName = GoFeedback.TAPPED

## The picture (`art`, kept in aspect in a `picture_size` square). The count's `GoBadge` hangs on its corner.
var picture: TextureRect
## The word.
var label: Label
var _fitted := 0
var _layout_queued := false


## A key showing [param picture_art] with [param words] under it.
static func make(words: String, picture_art: Texture2D = null) -> GoSideButton:
	var node := GoSideButton.new()
	node.text = words
	node.art = picture_art
	return node


func _init() -> void:
	name = "SideButton"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(picture)
	label = Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED # the caller hands in the words it means
	GoStyle.one_line(label)
	add_child(label)
	GoStyle.press_feel(self)
	GoStyle.skin_focus(self)
	pressed.connect(func() -> void:
		if not Engine.is_editor_hint(): GoFeedback.play(feedback))
	resized.connect(_place)


func _ready() -> void:
	_restyle()


func _enter_tree() -> void:
	# 🔑 Watched on every entry, not once in `_ready`: a key taken out and put back catches up with the look.
	GoUi.watch(_restyle)
	if is_node_ready(): _restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_queue_layout()


## The count on the picture's corner (`GoBadge.attach`): [param count] 0 hides it, [param words] shows words instead
## ("NEW"), [param as_dot] only a dot. Returns the badge.
func set_badge(count: int, words := "", as_dot := false) -> GoBadge:
	var shown := GoBadge.attach(picture, count, words, as_dot)
	_dress_badge(shown)
	return shown


## The count's role and its place on the picture's corner (`BADGE_INSET`).
func _dress_badge(shown: GoBadge) -> void:
	if shown == null: return
	shown.text_role = badge_role
	shown.corner_inset = Vector2.ONE * roundf(float(picture_size) * BADGE_INSET)


## The badge on the picture's corner, null before the first `set_badge`.
func badge() -> GoBadge:
	if not is_instance_valid(picture): return null
	for child in picture.get_children():
		if child is GoBadge: return child
	return null


## The size the word is drawn at now (dp), after it shrank to `label_width`.
func fitted_font_size() -> int:
	refresh()
	return _fitted


## The room the word shrinks into (dp).
func label_room() -> float:
	return label_width if label_width > 0.0 else float(picture_size) * 1.5


## Applies pending changes now; the setters batch to the end of the frame.
func refresh() -> void:
	_layout_queued = false
	if not is_instance_valid(label): return
	label.text = text
	label.visible = not text.is_empty()
	accessibility_name = text
	var base := font_size if font_size > 0 else GoUi.font_size(GoTheme.ROLE_BUTTON)
	_fitted = GoStyle.fit_font_size(PackedStringArray([text]), base, label_room(), label.get_theme_font(&"font")) \
		if not text.is_empty() else base
	label.add_theme_font_size_override(&"font_size", _fitted)
	_dress_badge(badge())
	update_minimum_size()
	_place()


func _get_minimum_size() -> Vector2:
	var floor_side := GoUi.touch_size()
	var word := label.get_combined_minimum_size() if is_instance_valid(label) and label.visible else Vector2.ZERO
	var tall := float(picture_size) + (GAP + word.y if word.y > 0.0 else 0.0)
	return Vector2(maxf(floor_side, maxf(float(picture_size), maxf(label_room(), word.x))), maxf(floor_side, tall))


## The picture at the top of the content, the word under it, the pair centred in the node.
func _place() -> void:
	if not is_instance_valid(label): return
	var side := float(picture_size)
	var word := label.get_combined_minimum_size() if label.visible else Vector2.ZERO
	var tall := side + (GAP + word.y if word.y > 0.0 else 0.0)
	var top := floorf((size.y - tall) * 0.5)
	picture.position = Vector2(floorf((size.x - side) * 0.5), top)
	picture.size = Vector2(side, side)
	var wide := maxf(size.x, word.x)
	label.position = Vector2(floorf((size.x - wide) * 0.5), top + side + GAP)
	label.size = Vector2(wide, word.y)


## The look's outlined HUD text, or the name plate's ink and edge where the look has none.
func _restyle() -> void:
	theme = GoUi.theme()
	if not is_instance_valid(label): return
	label.remove_theme_color_override(&"font_color")
	label.remove_theme_color_override(&"font_outline_color")
	label.remove_theme_constant_override(&"outline_size")
	var look := GoUi.theme()
	var outlined := look != null and look.get_type_variation_base(GoSignalBars.VAR_TEXT) == &"Label"
	label.theme_type_variation = GoSignalBars.VAR_TEXT if outlined else &""
	if not outlined:
		var skin := GoUi.skin()
		label.add_theme_color_override(&"font_color", skin.nameplate_ink(false))
		label.add_theme_color_override(&"font_outline_color", skin.nameplate_outline_ink())
		label.add_theme_constant_override(&"outline_size", maxi(2, skin.nameplate_outline(false)))
	GoStyle.skin_focus(self)
	_dress_badge(badge())
	refresh()


func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		if not is_inside_tree() and is_instance_valid(label): label.text = text
		return
	_layout_queued = true
	refresh.call_deferred()


## The tint the picture and the word take now: the look's press tint while held, faded while disabled.
func face_tint() -> Color:
	var mode := get_draw_mode()
	if mode == DRAW_DISABLED: return Color(1.0, 1.0, 1.0, DISABLED_ALPHA)
	if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED: return GoUi.skin().picture_press_tint()
	return Color.WHITE


func _draw() -> void:
	var tint := face_tint()
	picture.self_modulate = tint
	label.self_modulate = tint
	if has_focus() and focus_mode != Control.FOCUS_NONE:
		var ring := get_theme_stylebox(&"focus", &"Button")
		if ring != null: draw_style_box(ring, Rect2(Vector2.ZERO, size))
