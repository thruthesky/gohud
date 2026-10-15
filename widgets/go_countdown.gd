## ⏱️ **The match-start count** — 3 · 2 · 1 · GO! big in the middle of the screen, each step on a painted disc and
## popping in (scaled up and faded, settling over 0.35 s).
##
## ```gdscript
## var count := GoCountdown.new()
## screen.add_child(count)
## count.set_anchors_preset(Control.PRESET_CENTER_TOP)
## count.anchor_top = 0.24
## count.anchor_bottom = 0.24
## count.show_step("3")                     # a blue disc
## count.show_step(tr("COUNTDOWN_GO"), true) # the last step: a green disc, the text a size smaller
## count.hide_step()
## ```
##
## The disc is `GoSkin.countdown_disc(final)` (arcade_light: the game's painted blue and green badges); a look with
## none draws a round `accent` / `success` disc. The text is `GoSkin.countdown_ink()` (arcade_light: GOLD) with a
## thick outline in the label's outline ink and a soft drop shadow.
## 🛑 Display only — the caller (the server's clock online) says which step shows and when; nothing here counts.
@tool
class_name GoCountdown
extends Label

## The disc's size (dp).
@export_range(32.0, 480.0, 1.0) var disc_size := 200.0:
	set(value):
		disc_size = value
		_layout_disc()

## The font size of a step, and of the last ("GO!" is wider than a digit, so it is set smaller to stay on its disc).
@export_range(8, 256) var step_size := 110
@export_range(8, 256) var final_size := 80

## The text's colour. Transparent: `GoSkin.countdown_ink()`.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		_restyle()

## The outline round the text (dp).
@export_range(0, 32) var outline := 14:
	set(value):
		outline = value
		_restyle()

## The pop each step makes: it starts at this scale and opacity and settles over `pop_seconds`.
@export var pop_scale := 1.6
@export var pop_alpha := 0.6
@export_range(0.0, 2.0, 0.01) var pop_seconds := 0.35

var _final := false
var _disc: TextureRect
var _round: Panel
var _pop: Tween


func _init() -> void:
	name = "Countdown"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(300.0, 200.0)
	_round = Panel.new()
	_round.name = "Round"
	_round.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round.show_behind_parent = true
	add_child(_round)
	_disc = TextureRect.new()
	_disc.name = "Disc"
	_disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.show_behind_parent = true
	add_child(_disc)
	_layout_disc()
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func _ready() -> void:
	theme = GoUi.theme()
	GoUi.watch(_restyle)
	_restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## Shows [param text] on the disc — [param final] for the last step (the green disc, `final_size`) — and pops it in
## (not under `reduce_motion`, nor when [param animate] is false).
func show_step(text: String, final := false, animate := true) -> void:
	self.text = text
	_final = final
	visible = not text.is_empty()
	_restyle()
	if is_instance_valid(_pop) and _pop.is_valid(): _pop.kill()
	scale = Vector2.ONE
	modulate.a = 1.0
	if visible and animate and is_inside_tree() and not GoUi.config.reduce_motion and pop_seconds > 0.0:
		scale = Vector2.ONE * pop_scale
		modulate.a = pop_alpha
		_pop = create_tween().set_parallel(true)
		_pop.tween_property(self, "scale", Vector2.ONE, pop_seconds).set_ease(Tween.EASE_OUT)
		_pop.tween_property(self, "modulate:a", 1.0, pop_seconds)


## Takes the count off the screen.
func hide_step() -> void:
	show_step("", false, false)


func is_final() -> bool:
	return _final


func _layout_disc() -> void:
	for node: Control in [_disc, _round]:
		if not is_instance_valid(node): continue
		node.set_anchors_preset(Control.PRESET_CENTER)
		node.offset_left = -disc_size / 2.0
		node.offset_right = disc_size / 2.0
		node.offset_top = -disc_size / 2.0
		node.offset_bottom = disc_size / 2.0
	_restyle()


func _restyle() -> void:
	if not is_instance_valid(_disc): return
	var skin := GoUi.skin()
	var art := skin.countdown_disc(_final)
	_disc.texture = art
	_disc.visible = art != null
	_round.visible = art == null
	if art == null:
		var circle := StyleBoxFlat.new()
		circle.bg_color = GoUi.color(GoTheme.SUCCESS_FILL if _final else GoTheme.ACCENT_FILL)
		circle.set_corner_radius_all(int(disc_size / 2.0))
		circle.anti_aliasing = true
		_round.add_theme_stylebox_override(&"panel", circle)
	add_theme_font_size_override(&"font_size", final_size if _final else step_size)
	add_theme_color_override(&"font_color", ink if ink.a > 0.0 else skin.countdown_ink())
	add_theme_constant_override(&"outline_size", outline)
	add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	add_theme_constant_override(&"shadow_offset_y", 8)
