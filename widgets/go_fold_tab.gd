## 📌 **A fold tab** — the one affordance that folds a HUD panel into a small pill and back, as MIR4, Lineage W and
## Genshin fold their quest, party and chat panels. Unfolded, it is a slim handle on the panel's edge with a chevron
## pointing the way the panel folds; folded, it is a pill that keeps the panel's key reading — a glyph, a short text
## ("3", "82%") and a slim gauge — with the chevron pointing back out.
##
## ```gdscript
## var tab := GoFoldTab.new()
## tab.side = SIDE_LEFT                          # the quest panel sits on the left and folds toward it
## tab.icon_name = GoIconSet.USERS               # what the pill keeps showing while the panel is away
## tab.tooltip_fold_name = &"HUD_PARTY_FOLD"     # your own translation keys (or plain words)
## tab.tooltip_unfold_name = &"HUD_PARTY_UNFOLD"
## hud.add_child(tab)
## tab.fold_changed.connect(func(_folded: bool) -> void: _relayout())
##
## func _relayout() -> void:
## 	party_panel.visible = not tab.folded
## 	if tab.folded:
## 		tab.position = Vector2(8, 120)          # the pill stands where the panel was
## 		tab.size = Vector2(96, 48)              # the touch box — the pill fills its width
## 	else:
## 		tab.position = Vector2(party_panel.get_rect().end.x, 120)
## 		tab.size = Vector2(48, 48)              # the handle hugs the box's left edge, against the panel
## 		GoFoldTab.fade_in(party_panel)          # the panel comes back with the same short fade
## 	tab.pill_text = str(party_size)
## 	tab.meter = leader_hp / leader_max_hp         # the folded pill keeps the panel's key gauge
## ```
##
## 🔑 **The kit owns the affordance, the host owns the layout.** The host places the node and sizes it — the node is the
##    touch box — reads `folded` and lays its HUD out again on `fold_changed`; the tab only draws its face inside the
##    box and answers presses. Keep the positions in your layout data, not here: the same tab works for any panel.
## 🔑 The face is the skin's pill over the world (`GoSkin.overlay_box` — a dark plate and a thin edge, readable on any
##    3D scene) edged in `accent`; only the face shows, never a frame on the whole touch box. Hover and press tint the
##    face toward `accent`; the theme's focus ring shows under keyboard and gamepad control.
## 🛑 Set `folded` from code (a saved layout, a narrow screen) and nothing is emitted — `fold_changed` is only the
##    player's press (or `toggle()`), so a host that relays out on it never loops.
## 🛑 Like every gohud button it is Tab-reachable in the normal looks and a clicked tab **keeps focus** — over gameplay
##    where Space or Enter is a game key, turn that off (`focus_mode = Control.FOCUS_NONE`, or put it under a
##    `GoHudAnchor` with `keyboard_focus = false`), or the next Space folds the panel instead of reaching the game.
## 🛑 Its texts are caller-supplied: the tooltips go through `GoUi.text` (a gohud name, your own key or plain words)
##    and `pill_text` is drawn as is — the kit adds no strings of its own, so your translation table covers every
##    language your game ships.
@tool
class_name GoFoldTab
extends Button

## The player folded or unfolded the panel (a press, or `toggle()`) — never a `folded` set from code.
signal fold_changed(folded: bool)
## A press while `locked`: the panel stays folded. Tell the player why (a toast: "No room on this screen").
signal locked_pressed

## The fade a new face (and `fade_in`) plays — short enough (≤ 150 ms) to read as a response, not as an animation.
const FADE_SECONDS := 0.12
## The meta `fade_in` keeps its running tween under, so a second call restarts it rather than racing it.
const FADE_META := &"_go_fold_fade"
## Hover and press tint the face's fill this far toward `accent`.
const HOVER_TINT := 0.15
const PRESS_TINT := 0.3
## The face's edge in `accent` at this opacity — present, never louder than the glyph.
const EDGE_ALPHA := 0.9
## The chevron on a pill is this share of the glyph — it is the secondary mark.
const CHEVRON_SHARE := 0.8
## The gauge's thickness against the pill face's height, and its least thickness (dp).
const METER_SHARE := 0.1
const METER_MIN := 2.0
## The clear space (dp) between the gauge and the face's bottom edge.
const METER_GAP := 2.0
## The gauge's empty track is its colour at this opacity.
const METER_TRACK_ALPHA := 0.3
## A locked tab's chevron fades to this — the way out is there but closed for now.
const LOCKED_ALPHA := 0.45

## Folded (the pill) or unfolded (the handle). Setting it restyles only: no signal, no fade.
@export var folded := false:
	set(value):
		if folded == value: return
		folded = value
		_restyle()

## The `Side` the panel folds toward (`SIDE_LEFT`, `SIDE_TOP`, `SIDE_RIGHT`, `SIDE_BOTTOM`). Unfolded, the chevron
## points that way and the handle hugs that edge of the box; folded, the chevron points back out.
@export_enum("Left:0", "Top:1", "Right:2", "Bottom:3") var side: int = SIDE_LEFT:
	set(value):
		if side == value: return
		side = value
		_restyle()

## The host holds the panel folded (no room on screen): a press emits `locked_pressed`, `folded` stays, the chevron dims.
@export var locked := false:
	set(value):
		if locked == value: return
		locked = value
		_restyle()

## The visible handle while unfolded (dp), as is — for a `SIDE_TOP` / `SIDE_BOTTOM` tab give it a flat size such as
## `Vector2(36, 16)`. It hugs the box's `side` edge (the edge against the panel when the tab stands just outside the
## panel's inner edge), centred on the other axis; a box smaller than it clips it to the box.
@export var tab_face := Vector2(16, 36):
	set(value):
		if tab_face == value: return
		tab_face = value.max(Vector2.ZERO)
		_restyle()

## Which edge of the box the unfolded handle hugs: -1 (the default) is the `side` edge — a handle standing just outside
## the panel; a `Side` value hugs that edge instead (`SIDE_RIGHT` for a handle laid inside a left panel's right end).
## Centred on the other axis either way.
@export_enum("Side:-1", "Left:0", "Top:1", "Right:2", "Bottom:3") var tab_align: int = -1:
	set(value):
		if tab_align == value: return
		tab_align = value
		_restyle()

## Centre a standalone handle in its touch box instead of hugging an edge. The fold direction still comes from
## `side`; panel-edge handles keep the default false. Folded pills already centre vertically and are unchanged.
@export var tab_centered := false:
	set(value):
		if tab_centered == value: return
		tab_centered = value
		_restyle()

## The pill face's height while folded (dp). The pill fills the box's width and is centred in its height.
@export var pill_height := 32.0:
	set(value):
		if pill_height == value: return
		pill_height = maxf(0.0, value)
		_restyle()

## The pill's glyph — an icon-set name (`GoIconSet.USERS`, or a name the host registered). Empty: no glyph.
@export var icon_name: StringName = &"":
	set(value):
		if icon_name == value: return
		icon_name = value
		_restyle()

## The pill's short text ("3", "82%"), drawn as is (never translated), one line, left to right, cut with an ellipsis
## to the room the glyph and the chevron leave.
## ⚡ Cheap to set often (a folded HP share ticks several times a second in a fight): a new text only updates the label
## and the names that read it. The full restyle runs only when the face itself changes — a tab with no glyph turns
## between the handle and the pill as its text empties or fills.
@export var pill_text := "":
	set(value):
		if pill_text == value: return
		var had_pill := shows_pill()
		pill_text = value
		if shows_pill() != had_pill: _restyle()
		else: _apply_text()

## 0..1 draws a slim gauge along the inside bottom of the pill (a folded panel keeps its key gauge — HP, a quest's
## progress). Under 0: no gauge. Above 1 counts as full.
@export var meter := -1.0:
	set(value):
		if meter == value: return
		meter = value
		queue_redraw()

## The gauge's colour. Transparent: the theme's success fill (`GoTheme.SUCCESS_FILL`).
@export var meter_color := Color.TRANSPARENT:
	set(value):
		if meter_color == value: return
		meter_color = value
		queue_redraw()

## The ink of the glyph, the chevron and the face's edge. Transparent: the theme's accent.
@export var accent := Color.TRANSPARENT:
	set(value):
		if accent == value: return
		accent = value
		_restyle()

## The tooltip and screen-reader name while unfolded (a press folds), through `GoUi.text`. Empty: none.
@export var tooltip_fold_name: StringName = &"":
	set(value):
		tooltip_fold_name = value
		_refresh_tooltip()

## The tooltip and screen-reader name while folded (a press unfolds). Empty: none.
@export var tooltip_unfold_name: StringName = &"":
	set(value):
		tooltip_unfold_name = value
		_refresh_tooltip()

## The tooltip and screen-reader name while `locked` ("No room to open this here"). Empty: none.
@export var tooltip_locked_name: StringName = &"":
	set(value):
		tooltip_locked_name = value
		_refresh_tooltip()

## The text role of `pill_text` (`GoTheme.ROLE_COMPACT` — a HUD count).
@export var role: StringName = GoTheme.ROLE_COMPACT:
	set(value):
		if role == value: return
		role = value
		_restyle()

## Targets whose touch boxes may overlap this tab. Every participant must register the others.
## Raw hit testing stays separate from ownership so arbitration never recurses through `_has_point`.
var touch_peers: Array[Control] = []
## Optional host arbitration `(control, local_point, peers) -> bool`. A host with round or custom faces can
## share its existing ownership rule. Without one, the nearer visible fold face (other controls: their box) wins.
var touch_owner: Callable

## The row laid over the face: the glyph, the text and the chevron.
var row: HBoxContainer
## The pill's text.
var label: Label

var _glyph: Control
var _chevron: Control
## What each icon node was built from ([name, size, ink]) — a restyle with nothing new keeps the node.
var _glyph_key := []
var _chevron_key := []
var _built := false
## The face's StyleBox at rest, made once per restyle (`_face_box`); the hover and press faces are tinted copies.
var _box: StyleBox


func _init() -> void:
	name = "FoldTab"
	theme_type_variation = GoTheme.VAR_ICON_BUTTON
	mouse_filter = Control.MOUSE_FILTER_STOP   # a press never reaches the world under the HUD
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # the tooltip arrives translated (`GoUi.text`)
	clip_text = true
	row = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR   # the order is physical (by `side`), never the language's
	add_child(row)
	label = GoStyle.one_line(Label.new())
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text_direction = Control.TEXT_DIRECTION_LTR   # "82%" reads the same in every language
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_built = true
	GoStyle.press_feel(self)
	GoStyle.skin_focus(self)
	pressed.connect(_on_pressed)


func _ready() -> void:
	_restyle()


func _enter_tree() -> void:
	# Watched on every entry (as `GoIconButton`): a tab taken out and put back catches up with a look changed meanwhile.
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## The look changed (`GoUi.use_preset()`, `GoUi.refresh()`): the theme, the focus mode, the icons and the face follow.
func _on_ui_changed() -> void:
	GoStyle.skin_focus(self)
	_glyph_key = []
	_chevron_key = []
	_restyle()


## What a press does when not locked: flips `folded`, fades the new face in and emits `fold_changed`. A host may call
## it too (a hotkey) — it does not check `locked`; the host that locked the tab decides.
func toggle() -> void:
	folded = not folded
	fade_in(self)
	fold_changed.emit(folded)


func _on_pressed() -> void:
	if locked:
		locked_pressed.emit()
		return
	toggle()


## ✨ Fades [param node] in from transparent over [param seconds] — for the panel a host just showed again, so it
## arrives the way the tab's own face does. Calling it again restarts the fade. Instant (returns null, `modulate.a` = 1)
## under `GoUi.config.reduce_motion`, out of the tree, or for 0 seconds.
static func fade_in(node: CanvasItem, seconds := FADE_SECONDS) -> Tween:
	if node == null: return null
	var previous: Tween = node.get_meta(FADE_META) if node.has_meta(FADE_META) else null
	if previous != null and previous.is_valid(): previous.kill()
	if node.has_meta(FADE_META): node.remove_meta(FADE_META)
	if not node.is_inside_tree() or GoUi.config.reduce_motion or seconds <= 0.0:
		node.modulate.a = 1.0
		return null
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	node.set_meta(FADE_META, tween)
	return tween


## Does the folded face show the pill (a glyph or a text to keep)? Folded with neither, it shows the handle with the
## chevron turned back — a header-only panel (a chat card) folds that way.
func shows_pill() -> bool:
	return folded and (not icon_name.is_empty() or not pill_text.is_empty())


## The icon-set name of the chevron shown now: toward `side` while unfolded (fold that way), away while folded.
func chevron_name() -> StringName:
	var toward := side if not folded else _opposite(side)
	match toward:
		SIDE_TOP: return GoIconSet.CHEVRON_UP
		SIDE_RIGHT: return GoIconSet.CHEVRON_RIGHT
		SIDE_BOTTOM: return GoIconSet.CHEVRON_DOWN
	return GoIconSet.CHEVRON_LEFT


## The visible face inside the node (local coordinates): the pill (the box's width, `pill_height`, centred) or the
## handle (`tab_face`, against the `tab_align` edge — the `side` edge by default — centred on the other axis). Both
## are held inside the box.
func face_rect() -> Rect2:
	if shows_pill():
		var high := minf(pill_height, size.y)
		return Rect2(0.0, roundf((size.y - high) * 0.5), size.x, high)
	var face := tab_face.min(size)
	var spot := ((size - face) * 0.5).round()
	if tab_centered: return Rect2(spot, face)
	match side if tab_align < 0 else tab_align:
		SIDE_LEFT: spot.x = 0.0
		SIDE_RIGHT: spot.x = size.x - face.x
		SIDE_TOP: spot.y = 0.0
		SIDE_BOTTOM: spot.y = size.y - face.y
	return Rect2(spot, face)


## Where the gauge is drawn (its full track), or an empty rect when there is none: `meter` under 0, unfolded, or a
## folded face without a pill.
func meter_rect() -> Rect2:
	if meter < 0.0 or not shows_pill(): return Rect2()
	var face := face_rect()
	var inset := 0.0
	var edge := 0.0
	if _box != null:
		inset = maxf(_box.get_content_margin(SIDE_LEFT), _box.get_content_margin(SIDE_RIGHT))
		edge = float(_box.get(&"border_width_bottom")) if &"border_width_bottom" in _box else 0.0
	var thick := maxf(METER_MIN, roundf(face.size.y * METER_SHARE))
	var bottom := face.end.y - METER_GAP - edge
	var rect := Rect2(face.position.x + inset, bottom - thick, maxf(0.0, face.size.x - inset * 2.0), thick)
	return rect if rect.size.x > 0.0 else Rect2()


## The glyph's side (dp): the skin's glyph share of `pill_height` (`GoSkin.icon_button_glyph`).
func glyph_size() -> int:
	return GoUi.skin().icon_button_glyph(pill_height)


## The ink of the glyph, the chevron and the edge: `accent`, or the theme's accent.
func ink() -> Color:
	return accent if accent.a > 0.0 else GoUi.color(GoTheme.ACCENT)


func _restyle() -> void:
	if not _built: return
	if not is_inside_tree() and not Engine.is_editor_hint(): return
	theme = GoUi.theme()
	_box = _face_box()
	# Only the face shows — no frame on the whole touch box. `focus` stays the theme's, so the ring still shows.
	var nothing := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		add_theme_stylebox_override(state, nothing)
	var pill := shows_pill()
	var glyph_side := glyph_size()
	var turned := Color(ink(), ink().a * LOCKED_ALPHA) if locked else ink()
	var chevron_side := roundi(glyph_side * CHEVRON_SHARE) if pill else \
		mini(glyph_side, maxi(8, roundi(minf(tab_face.x, tab_face.y))))
	_chevron = _icon(_chevron, _chevron_key, &"Chevron", chevron_name(), chevron_side, turned)
	_glyph = _icon(_glyph, _glyph_key, &"Glyph", icon_name if pill else &"", glyph_side, ink())
	_apply_text()
	GoStyle.typography(label, role, GoUi.color(GoTheme.TEXT))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if side == SIDE_RIGHT else HORIZONTAL_ALIGNMENT_LEFT
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if pill else BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	# Reading order away from `side`: the glyph at the side's end, then the text, the chevron at the far end.
	var order: Array[Control] = [_glyph, label, _chevron]
	if side == SIDE_RIGHT: order.reverse()
	var at := 0
	for part in order:
		if part == null: continue
		row.move_child(part, at)
		at += 1
	_layout()
	queue_redraw()


## The part of the face that `pill_text` alone decides: the label (shown on a pill with a text) and the tooltip and
## screen-reader name, which read the text. The row re-sorts by itself when the label shows, hides or changes width.
func _apply_text() -> void:
	if not _built: return
	label.visible = shows_pill() and not pill_text.is_empty()
	label.text = pill_text
	_refresh_tooltip()


## Builds (or keeps) one icon node in the row. An empty name frees it.
func _icon(node: Control, key: Array, part: StringName, icon_id: StringName, side_dp: int, color: Color) -> Control:
	var wanted := [icon_id, side_dp, color]
	if is_instance_valid(node) and key == wanted: return node
	if is_instance_valid(node):
		row.remove_child(node)
		node.queue_free()
	key.clear()
	if icon_id.is_empty(): return null
	key.append_array(wanted)
	var made := GoUi.icons().node(icon_id, side_dp, color)
	made.name = part
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(made)
	return made


## Lays the row over the face: the pill's content box (the face's side padding), or the whole handle.
func _layout() -> void:
	if not _built: return
	var face := face_rect()
	if shows_pill() and _box != null:
		var left := _box.get_content_margin(SIDE_LEFT)
		var right := _box.get_content_margin(SIDE_RIGHT)
		face = Rect2(face.position.x + left, face.position.y, maxf(0.0, face.size.x - left - right), face.size.y)
	row.position = face.position
	row.size = face.size


## The face at rest: the skin's pill over the world (`GoSkin.overlay_box`), edged in `accent`.
func _face_box() -> StyleBox:
	var box := GoUi.skin().overlay_box()
	if &"border_color" in box: box.set(&"border_color", Color(ink(), ink().a * EDGE_ALPHA))
	return box


## The face for a draw state — hover and press tint the fill toward `accent` (its opacity kept); at rest, `_box`.
func _state_box(state: int) -> StyleBox:
	var tint := 0.0
	match state:
		BaseButton.DRAW_HOVER: tint = HOVER_TINT
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED: tint = PRESS_TINT
	if tint <= 0.0 or &"bg_color" not in _box: return _box
	var box := _box.duplicate() as StyleBox
	var fill: Color = box.get(&"bg_color")
	var lit := fill.lerp(ink(), tint)
	lit.a = fill.a
	box.set(&"bg_color", lit)
	return box


func _draw() -> void:
	if _box == null: return
	draw_style_box(_state_box(get_draw_mode()), face_rect())
	var track := meter_rect()
	if track.size.x <= 0.0: return
	var color := meter_color if meter_color.a > 0.0 else GoUi.color(GoTheme.SUCCESS_FILL)
	draw_rect(track, Color(color, color.a * METER_TRACK_ALPHA))
	var fill := track
	fill.size.x = roundf(track.size.x * clampf(meter, 0.0, 1.0))
	if fill.size.x > 0.0: draw_rect(fill, color)


func _refresh_tooltip() -> void:
	var key := tooltip_locked_name if locked else (tooltip_unfold_name if folded else tooltip_fold_name)
	var words := GoUi.text(key) if not key.is_empty() else ""
	tooltip_text = words
	# ♿ The tab has no text of its own — a screen reader hears the action, then what the pill keeps ("Show party 3").
	accessibility_name = GoUi.spoken([words, pill_text if shows_pill() else ""])


## The engine's tooltip can break its text one character per line — the kit's own (`GoStyle.tooltip_node`).
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty(): return null
	return GoStyle.tooltip_node(for_text)


## The raw touch box, before peers divide it. One smaller than the touch floor still reaches `GoUi.touch_size()`.
func touch_hit(point: Vector2) -> bool:
	var reach := maxf(0.0, (GoUi.touch_size() - minf(size.x, size.y)) * 0.5)
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(point)


func _has_point(point: Vector2) -> bool:
	if not touch_hit(point): return false
	if touch_owner.is_valid(): return bool(touch_owner.call(self, point, touch_peers))
	if touch_peers.is_empty(): return true
	var at := get_global_transform() * point
	var mine := _touch_face_distance(self, at)
	for peer: Control in touch_peers:
		if peer == self or not is_instance_valid(peer) or not peer.is_visible_in_tree(): continue
		# Only a peer that holds this point can take it. Asking its raw shape avoids reciprocal recursion.
		var local := peer.get_global_transform().affine_inverse() * at
		var holds := false
		if peer.has_method("touch_hit"):
			holds = bool(peer.call("touch_hit", local))
		else:
			var reach := maxf(0.0, (GoUi.touch_size() - minf(peer.size.x, peer.size.y)) * 0.5)
			holds = Rect2(Vector2.ZERO, peer.size).grow(reach).has_point(local)
		if not holds: continue
		var theirs := _touch_face_distance(peer, at)
		if theirs < mine or (is_equal_approx(theirs, mine) and peer.get_instance_id() < get_instance_id()): return false
	return true


## Signed distance to the shown rectangle: negative inside, positive outside. Fold peers use their actual face.
static func _touch_face_distance(control: Control, at: Vector2) -> float:
	var rect := control.get_global_rect()
	if control is GoFoldTab: rect = control.get_global_transform() * (control as GoFoldTab).face_rect()
	var q := (at - rect.get_center()).abs() - rect.size * 0.5
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
			queue_redraw()
		NOTIFICATION_TRANSLATION_CHANGED:
			_refresh_tooltip()


static func _opposite(edge: int) -> int:
	match edge:
		SIDE_LEFT: return SIDE_RIGHT
		SIDE_RIGHT: return SIDE_LEFT
		SIDE_TOP: return SIDE_BOTTOM
	return SIDE_TOP
