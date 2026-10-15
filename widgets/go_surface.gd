## 🪟 **The shell of a floating window.** Popups, sheets and dropdowns all use this one node.
##
## Safe area, virtual keyboard, pinned header/footer, scrolling body, topmost-window test, focus restore,
## back-navigation ownership and drag-to-resize are all handled in one place.
##
## ```gdscript
## var surface := GoSurface.new()
## surface.set_title("Settings")
## surface.body.add_child(GoStyle.label("Content"))
## surface.close_requested.connect(surface.queue_free)
## canvas_layer.add_child(surface)
## ```
##
## ## Three placements
## | `placement` | Looks like | Used for |
## |---|---|---|
## | `CENTER` | A card in the middle of the screen | Confirmations, settings |
## | `BOTTOM` | A sheet that rises from the bottom | Lists, management pages |
## | `ANCHOR` | A card attached beside a given control | Dropdowns, context menus |
##
## ## 🛑 This node never dismisses itself
## Taking `close_requested` and hiding or freeing the node is up to the **screen that owns it**. The shell
## cannot know why the window is closing (save and close vs. discard and close).
@tool
class_name GoSurface
extends Control

signal close_requested
signal back_requested
## The resize handle was dragged — once per frame, after the card has the height [param ratio] describes.
signal height_changed(ratio: float)

enum Placement { CENTER, BOTTOM, ANCHOR }
## What the head's corner holds: what the look says (`GoSkin.window_corner()` — the close button, or under arcade_light
## the game's magnet), the close button, a picture (`corner_art`, or the look's), or nothing. Without a close button
## Escape and Back still close the window.
enum HeadCorner { LOOK, CLOSE, ART, NONE }

## How many surfaces are open right now. Used to decide whether to pause game input.
static var _open_count := 0
## Was the last input from a keyboard or gamepad? 🛑 A window opened with a pointer gets **no focus ring** —
##    when a menu was merely opened by touch and only the close button glows, it reads as "press here".
static var _pointer_navigation := true

## Is any surface open at all?
static func is_any_open() -> bool:
	return _open_count > 0


# ── Placement ──────────────────────────────────────────────────────────

## 🔑 Every layout input below is a setter that marks the layout dirty **only when the value really changes** — a
##    `fit_content` surface re-measures on the next frame instead of every frame (see `_process`). Assigning a field
##    directly (`surface.height_ratio = 0.9`) therefore still takes effect without calling `relayout()` by hand.
var placement := Placement.CENTER:
	set(value):
		if placement == value: return
		placement = value
		_layout_dirty = true
var max_width := 0.0:            ## 0 means `GoConfig.surface_max_width`
	set(value):
		if max_width == value: return
		max_width = value
		_layout_dirty = true
var max_height := 0.0:           ## 0 means `GoConfig.surface_max_height`
	set(value):
		if max_height == value: return
		max_height = value
		_layout_dirty = true
var height_ratio := 0.0:         ## 0 means `GoConfig.surface_height_ratio`
	set(value):
		if height_ratio == value: return
		height_ratio = value
		_layout_dirty = true
## 🔑 **This surface's ceiling on `height_ratio`.** 0 means `GoConfig.surface_max_height_ratio` (0.72).
## 🛑 Without it a `height_ratio` above the global ceiling is cut back to it — ask for 0.86 and get 0.72. That ceiling
##    exists so a window still reads as floating over the game; raise it here for the one surface that needs the room
##    (an inventory grid, a long list) instead of for every surface in `GoConfig`. A debug build warns once when a
##    requested ratio is cut.
var max_height_ratio := 0.0:
	set(value):
		if max_height_ratio == value: return
		max_height_ratio = value
		_layout_dirty = true
## Short content makes a short card. Turn it off to always take up `height_ratio`.
var fit_content := true:
	set(value):
		if fit_content == value: return
		fit_content = value
		_layout_dirty = true
## Drops padding and text one step on narrow screens.
var compact := false:
	set(value):
		if compact == value: return
		compact = value
		_layout_dirty = true
## Can pressing the backdrop close it? Defaults to the config value.
var dismiss_on_scrim := false
## Make the scrim transparent — for a dropdown over the game screen, where what is behind must stay visible.
var scrim_transparent := false
## 🎨 Paints the plate behind the title its own colour — the red ribbon of a GAME OVER window, the gold one of a win.
## Transparent: the look's plate as it is. Under the arcade looks (a `GoStyleBoxArcade` plate) the paint is moved until
## the white, ink-outlined title reads on it (`GoStyleBoxArcade.fit`); a look without a painted plate ignores it.
##
## ```gdscript
## surface.title_paint = GoUi.color(GoTheme.DANGER_FILL)   # a red ribbon: you were knocked out
## ```
var title_paint := Color.TRANSPARENT:
	set(value):
		title_paint = value
		if is_instance_valid(title_label) and is_instance_valid(close_button): _dress_chrome()
## 🏷 A glyph left of the title (a trophy, the pause bars) — glyph and title stand centred together on the plate.
## Drawn in the title's colour (white glyphs read as drawn on the arcade ribbon). Null: the title alone.
var title_glyph: Texture2D:
	set(value):
		title_glyph = value
		if is_instance_valid(title_label) and is_instance_valid(close_button): _dress_chrome()
## The glyph's side (dp). 0: in step with the title — 26/34 of its font size, as on the game's ribbon.
var corner := HeadCorner.LOOK:
	set(value):
		corner = value
		if is_inside_tree(): _dress_corner()
## The picture an `ART` corner shows — null: the look's (`GoSkin.window_corner_art()`).
var corner_art: Texture2D:
	set(value):
		corner_art = value
		if is_inside_tree(): _dress_corner()
## Which end of the head the corner art sits on — mirrored on the right, like the game's `RibbonHeader`.
var corner_on_left := true:
	set(value):
		corner_on_left = value
		if is_inside_tree(): _place_corner()
var title_glyph_size := 0:
	set(value):
		title_glyph_size = value
		if is_instance_valid(title_label) and is_instance_valid(close_button): _dress_chrome()
## The space between the glyph and the title (dp).
const TITLE_GLYPH_GAP := 10.0
## 🌤 An **opaque** window: a solid colour (`GoSkin.opaque_backdrop_color` — the game's sky in arcade_light) under it
## instead of the see-through veil — for a window opened where the world behind is not drawn (a menu at boot).
var opaque := false:
	set(value):
		opaque = value
		_dress_scrim()
## 🪟 **Opacity of the card background** (0.0~1.0) — for this one window only. Negative means the value the theme
## and config decide (`GoUi.surface_alpha(GoTheme.BOX_PANEL)` · 80% in the default theme).
##
## ```gdscript
## surface.alpha = 0.6    # 60% for this window only — a confirmation where the fight behind must show
## surface.alpha = 1.0    # fully opaque for this window only — a window for reading long text
## ```
##
## 🛑 **Only the card background** thins out. Title, body, buttons and icons stay crisp — if the content faded too,
##    the window would be unreadable, and that is not a transparent window but a broken one (use `modulate` for that).
## 🛑 The scrim (the veil behind) is separate — it is decided by the theme's `scrim` color and `scrim_transparent`.
var alpha := -1.0:
	set(value):
		alpha = value
		_restyle()
## Fade the card in when it opens.
var fade_in := false
## Can the height be changed by dragging (sheets)?
var resizable := false
var show_header := true
var scroll_body := true
var close_enabled := true
## Control to focus when opened. Without one, pointer input leaves focus nowhere.
var initial_focus: Control

## ANCHOR placement — attaches right below this control (above it when there is no room).
var anchor_control: Control:
	set(value):
		if anchor_control == value: return
		anchor_control = value
		_layout_dirty = true
var anchor_width := 320.0:
	set(value):
		if anchor_width == value: return
		anchor_width = value
		_layout_dirty = true
var anchor_min_width := 210.0:
	set(value):
		if anchor_min_width == value: return
		anchor_min_width = value
		_layout_dirty = true
var anchor_max_height := 520.0:
	set(value):
		if anchor_max_height == value: return
		anchor_max_height = value
		_layout_dirty = true

# ── Children ───────────────────────────────────────────────────────────

var card: PanelContainer
var header: HBoxContainer
var title_label: Label
var close_button: GoIconButton
var back_button: Button
var scroll: GoScroll
## The scrolling body. Most content goes in here.
var body: VBoxContainer
## A **pinned row** below the header and above the body (a search field, say). Hidden by default.
## 🛑 Put here what must not scroll away — inside the body it gets pushed out of sight when the sheet shrinks.
var toolbar: VBoxContainer
## A **pinned footer row** (confirm, cancel). Hidden by default. Inside the body it scrolls off screen on long lists.
var footer: VBoxContainer
## A **pinned status row** between the body and the footer — the **one line that must not be missed**, like "Passwords do not match".
## Hidden by default; turn it on with `set_status_*()`.
## 🛑 Do not put this row in the body — when an error in a long form lands outside the scroll, the screen looks as if
##    **nothing happened at all**, and the user waits, wondering "why is it not working" (measured 2026-09-16, Laryen account linking).
var status: VBoxContainer
## The label of the pinned status row. 🛑 **Created on first use** — screens that never use it grow no extra node.
var status_label: Label

var _scrim: ColorRect
var _title_glyph_rect: TextureRect
var _corner_rect: TextureRect
## How far the title plate rises above the card now (0: it sits inside the card) — `GoSkin.title_plate_overhang`.
var _overhang := Vector2.ZERO
var _column: VBoxContainer
var _margin: MarginContainer
var _content_padding := 0
## Are we at dense density right now (a narrow screen, or content that overflows).
var _dense := false
var _active := false
var _previous_focus: WeakRef
var _dragging := false
var _touch_index := -1
var _keyboard_px := 0
var _scrim_pressed := false
var _scrim_origin := Vector2.ZERO
var _holds_back := false
## A cut `height_ratio` has been reported (debug builds) — once per surface, since `relayout` runs again whenever content changes.
var _warned_height_cap := false
## 🔑 Something the layout reads has changed since the last `relayout()` — a section's minimum size or visibility, or a
##    layout field above. A `fit_content` surface re-measures on the next frame **only then**.
## 🛑 It used to re-measure **every frame** while open: 50–220 µs a frame on a desktop CPU for the 23-row Laryen Guide
##    sheet, paid for as long as the sheet stayed open even when nobody touched it (fix/guide-sheet-lag, 2026-10-01).
var _layout_dirty := true
## A handle drag moved `height_ratio` this frame. Applied once in `_process` — a fast finger can deliver several drag
## events in one frame, and each used to run a full `relayout()`.
var _resize_pending := false
## `height_changed` owes a report — sent once per frame **after** the card took the new height, so a listener that reads
## `card.size` sees what is drawn (it used to be sent per drag event, before the resize was applied).
var _height_unreported := false
var _fade: Tween
var _runtime: Node


func _init() -> void:
	# The name is set in `_init` — setting it in `_ready` would overwrite a name the caller changed right after `new()`.
	name = "Surface"
	# 🛑 Config defaults are taken **here** — merging them in `_ready` as `dismiss_on_scrim or config` would let the
	#    config's `true` override an explicit `false` given right after `new()` (a trade sheet that must not close on a mistap).
	dismiss_on_scrim = GoUi.config.dismiss_on_scrim
	fade_in = GoUi.config.surface_fade_in
	_build()


## 🛑 Children are built **in `_init`** — calling `set_title()` or `body.add_child()` *before* the node is added to
##    the tree is perfectly natural usage, and building them in `_ready` leaves `title_label` still `null` at that
##    point, which dies with "Invalid assignment … on a base object of type 'Nil'" (measured 2026-09-12).
func _build() -> void:
	theme = GoUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Children scroll first. Unused wheel events stop at this window's edge — they never leak through to what is
	# behind: not at the end of a list, not over the chrome, not when content is too short to scroll at all.
	mouse_force_pass_scroll_events = false
	add_to_group(&"go_surfaces")

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = GoUi.color(GoTheme.SCRIM)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_scrim_input)
	add_child(_scrim)

	card = PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = GoTheme.VAR_PANEL
	add_child(card)

	# 🛑 The content is clipped **one level in**, not on the card. A clip applies to the clipping item's own drawing
	#    too, so `card.clip_contents` cut the card's shadow off at its rectangle: no shadow outside the card, and a
	#    square dark patch in the four corners the rounded face leaves open (seen in the website shots, 2026-10-04).
	#    The padding fills the card, so the content is clipped where it always was.
	_margin = GoStyle.padding()
	_margin.clip_contents = true
	card.add_child(_margin)
	_column = GoStyle.column()
	_margin.add_child(_column)

	header = GoStyle.row()
	header.name = "Header"
	header.sort_children.connect(_seat_head_buttons)
	_column.add_child(header)

	back_button = GoStyle.button_key(GoUi.text_key(&"back"), func() -> void: back_requested.emit(), GoStyle.Tone.COMPACT)
	back_button.name = "BackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 🛑 Wrapping is turned off — wrapping drops the minimum **width** to nearly 0, and under `SHRINK_BEGIN` that
	#    minimum width becomes the real width. All that is left is the capsule, with the label clipped away entirely.
	back_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	back_button.set_meta(&"go_no_wrap", true)
	back_button.visible = false
	header.add_child(back_button)

	title_label = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	title_label.name = "Title"
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.resized.connect(func() -> void: _fit_title())
	header.add_child(title_label)

	close_button = _make_close_button()
	close_button.name = "CloseButton"
	close_button.visual_size = GoUi.config.close_button_visual
	close_button.icon_name = GoIconSet.CLOSE
	close_button.tooltip_text_name = &"close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(request_close)
	header.add_child(close_button)

	toolbar = GoStyle.column()
	toolbar.name = "Toolbar"
	toolbar.visible = false
	_column.add_child(toolbar)

	body = GoStyle.column()
	body.name = "Body"
	_column.add_child(body)

	status = GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	# 🛑 Not a common name (`Status`) — when a host screen looks its own status row up by name, this one is found
	#    **first** and the wrong node comes back (that is how the Laryen profile screen test broke, 2026-09-16).
	status.name = "StatusLine"
	status.visible = false
	_column.add_child(status)

	footer = GoStyle.column()
	footer.name = "Footer"
	footer.visible = false
	_column.add_child(footer)

	# 🔑 What `_desired_height()` reads. The engine emits `minimum_size_changed` (deferred, and only when the value really
	#    changed) all the way up from a re-wrapped label, a row added or freed, or the scrollbar appearing — so these
	#    two signals per section are the whole list of "the content asks for a different height".
	for section: Control in [header, toolbar, body, status, footer]:
		section.minimum_size_changed.connect(_mark_layout_dirty)
		section.visibility_changed.connect(_mark_layout_dirty)


func _mark_layout_dirty() -> void:
	_layout_dirty = true


## Builds the close button. 🔑 A host that wants a `GoIconButton` subclass (its own art and size) overrides this in a
## subclass — the surface only uses the `GoIconButton` API.
func _make_close_button() -> GoIconButton:
	return GoIconButton.new()


## Builds the body scroll. 🔑 A host project that wants a `GoScroll` subclass (old type-hint compatibility, say) overrides
## this in a subclass — the surface only uses the `GoScroll` API.
func _make_scroll() -> GoScroll:
	return GoScroll.new()


## Clips the body's scroll only while its content overflows it (a scrollbar shows, or would with the bars hidden).
func _sync_body_clip() -> void:
	if scroll == null: return
	var need := body.get_combined_minimum_size()
	var clip := need.y > scroll.size.y + 0.5 or need.x > scroll.size.x + 0.5 \
			or scroll.get_v_scroll_bar().visible or scroll.get_h_scroll_bar().visible
	if scroll.clip_contents != clip: scroll.clip_contents = clip


func _ready() -> void:
	# Options that may have changed **between** `new()` and `add_child()` are applied here.
	_dress_scrim()
	header.visible = show_header
	if resizable: attach_resize_handle(title_label)
	if scroll_body and scroll == null:
		# 🛑 The scroll is inserted here — `use_panel_edge()` can only push the scrollbar out into the card padding once
		#    the parent is known. Children already placed in the body come along unchanged.
		var slot := body.get_index()
		scroll = _make_scroll()
		_column.add_child(scroll)
		_column.move_child(scroll, slot)
		body.reparent(scroll)
		scroll.use_panel_edge(GoUi.metric(GoTheme.PADDING))
		# 🔑 The body clips only while it scrolls. A body that fits has nothing to clip, and the clip would cut a
		#    part's antialiased rim on a half pixel (the painted inset's top edge at 1.5x) the game's column never cuts.
		scroll.sort_children.connect(_sync_body_clip)
		_sync_body_clip()
	elif not scroll_body:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_runtime = GoUi.runtime()
	if _runtime != null:
		if _runtime.has_signal(&"keyboard_changed"): _runtime.keyboard_changed.connect(_on_keyboard)
		if _runtime.has_signal(&"breakpoint_changed"): _runtime.breakpoint_changed.connect(func(_bp) -> void: relayout())
	get_viewport().size_changed.connect(relayout)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	visibility_changed.connect(_sync_active)
	_restyle()
	relayout()
	_sync_active()


## Reapplies the card panel — this is where opacity is decided.
## 🛑 **Not called from `relayout`** (which re-runs whenever a fit-content window's content changes). It duplicates the stylebox, so it
##    costs more than a layout pass, and only needs doing on change — a config change, an `alpha` assignment, opening.
func _restyle() -> void:
	if card == null or not is_inside_tree(): return
	# The card the look frames a window with (`GoSkin.window_card_variation`: the painted card under arcade_light).
	var wear := GoUi.skin().window_card_variation()
	# How the look's sprites are sampled across the whole window (mipmapped under arcade_light, like the game's dialog).
	texture_filter = GoUi.skin().window_texture_filter()
	if card.theme_type_variation != wear:
		GoStyle.forget_face(card)
		card.theme_type_variation = wear
	GoStyle.fade_panel(card, alpha, &"panel", GoTheme.BOX_PANEL)
	_fit_scroll_frame()
	_dress_chrome()


## Tells the body scroll how far the card's frame reaches into the padding, so scrolled rows pass **under** the frame.
## The panel's own content margin already keeps the padding off the frame by that much.
func _fit_scroll_frame() -> void:
	if scroll == null or card == null: return
	var box := card.get_theme_stylebox(&"panel")
	var frame := Vector4.ZERO
	# 🔑 A look that pads the window with its card face (`GoSkin.window_padding` ≥ 0, the painted card) puts the content
	#    where the face's padding ends, as the game does — a painted 9-slice's edge is the slice, not the drawn rim, and
	#    clipping there pushed the body 14 dp down off the game's row.
	if box != null and GoUi.skin().window_padding() < 0:
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			frame[side] = maxf(0.0, GoSkin.frame_margin(box, side) - box.get_margin(side))
	scroll.set_panel_frame(frame)


## 🎀 The window's head in the look in force — a plate behind the title and the close button as the look dresses them
## (`GoSkin.title_plate_box`, `dress_close_button`). What an earlier look put on is lifted off first, so a look that
## has neither gets the plain head back. Only what this surface put on is taken off: a host's own title alignment stays.
func _dress_chrome() -> void:
	var skin := GoUi.skin()
	var plate := skin.title_plate_box()
	if plate is GoStyleBoxArcade and title_paint.a > 0.0:
		var painted := plate as GoStyleBoxArcade
		painted.paint(GoStyleBoxArcade.fit(Color(title_paint, 1.0), painted.edge()))
	if plate != null:
		title_label.add_theme_stylebox_override(&"normal", plate)
		if not title_label.has_meta(&"go_plate_align"):
			title_label.set_meta(&"go_plate_align", title_label.horizontal_alignment)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ink := skin.title_plate_ink()
		if ink.a > 0.0: title_label.add_theme_color_override(&"font_color", ink)
		else: title_label.remove_theme_color_override(&"font_color")
	elif title_label.has_meta(&"go_plate_align"):
		title_label.remove_theme_stylebox_override(&"normal")
		title_label.remove_theme_color_override(&"font_color")
		title_label.horizontal_alignment = title_label.get_meta(&"go_plate_align")
		title_label.remove_meta(&"go_plate_align")
	title_label.remove_theme_color_override(&"font_outline_color")
	title_label.remove_theme_constant_override(&"outline_size")
	skin.dress_title(title_label)
	_dress_title_extras(plate)
	_dress_corner()
	_fit_title()
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		close_button.remove_theme_stylebox_override(state)
	close_button.icon_tint = Color.TRANSPARENT
	skin.dress_close_button(close_button)


## On a title plate the title stays on one line: past the plate's room it shrinks, down to
## `GoSkin.title_plate_min_size()`, and only then folds. Without a plate the title keeps the size its role gives it.
func _fit_title() -> void:
	if title_label == null: return
	_fit_title_size()
	_place_title_glyph()
	_place_corner()


func _fit_title_size() -> void:
	var plate := title_label.get_theme_stylebox(&"normal") if title_label.has_meta(&"go_plate_align") else null
	var role_size := GoUi.font_size(title_label.get_meta(&"go_text_role", GoTheme.ROLE_SUBTITLE))
	if plate == null or title_label.size.x <= 0.0 or title_label.text.is_empty():
		if title_label.has_meta(&"go_title_fit"):
			title_label.remove_meta(&"go_title_fit")
			title_label.remove_theme_font_size_override(&"font_size")
		return
	var room := title_label.size.x - plate.get_margin(SIDE_LEFT) - plate.get_margin(SIDE_RIGHT) - 2.0
	var over := plate as OverhangPlate
	if over != null and over.base != null:
		# Its left margin follows the words (see `_place_title_glyph`); the room is the plate's as drawn — past the
		# card's sides by its bleed — less its ends and the glyph's room, the game's ribbon row.
		room = title_label.size.x - _plate_end(over, SIDE_LEFT) - _plate_end(over, SIDE_RIGHT) - over.glyph_room
	var font := title_label.get_theme_font(&"font")
	var natural := _title_natural_size()
	var words := title_label.atr(title_label.text)
	var fitted := natural
	while fitted > GoUi.skin().title_plate_min_size() \
			and font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > room:
		fitted -= 1
	if fitted == role_size:
		if title_label.has_meta(&"go_title_fit"):
			title_label.remove_meta(&"go_title_fit")
			title_label.remove_theme_font_size_override(&"font_size")
	elif not title_label.has_meta(&"go_title_fit") or title_label.get_theme_font_size(&"font_size") != fitted:
		title_label.set_meta(&"go_title_fit", true)
		title_label.add_theme_font_size_override(&"font_size", fitted)
	if over != null: _sink_plate(over, font, fitted)


## The title's size before it shrinks: the look's plate size (`GoSkin.title_plate_font_size`) on a plate, else its role's.
func _title_natural_size() -> int:
	var on_plate := title_label.has_meta(&"go_plate_align")
	var look := GoUi.skin().title_plate_font_size() if on_plate else 0
	return look if look > 0 else GoUi.font_size(title_label.get_meta(&"go_text_role", GoTheme.ROLE_SUBTITLE))


## How far in from the label's [param side] the plate's end ends: its base margin, less the bleed drawn on that side.
func _plate_end(plate: OverhangPlate, side: Side) -> float:
	var margin := plate.base.get_margin(side) if plate.base != null else 0.0
	var bleed := plate.bleed_left if side == SIDE_LEFT else plate.bleed_right
	return maxf(0.0, margin - bleed)


## A plate of a fixed height (`GoSkin.title_plate_height`) holds a taller title by growing down over the gap below:
## the words keep the plate's top margin and the plate is drawn down to fit them, while the head keeps its height.
func _sink_plate(plate: OverhangPlate, font: Font, size: int) -> void:
	var tall := GoUi.skin().title_plate_height()
	var sink := 0.0
	if tall > 0.0 and plate.base != null and font != null:
		sink = maxf(0.0, plate.base.get_margin(SIDE_TOP) + plate.base.get_margin(SIDE_BOTTOM) + font.get_height(size) - tall)
	if not is_equal_approx(plate.sink, sink):
		plate.sink = sink
		plate.content_margin_bottom = (plate.base.get_margin(SIDE_BOTTOM) if plate.base != null else 0.0) - sink
		title_label.update_minimum_size()
		title_label.queue_redraw()


## Config or theme changed. 🛑 **Forget** the remembered "original panel" and take it again — swapping the look
##    changes the panel itself, so putting the new opacity on the old panel leaves a card from the old theme.
func _on_ui_changed() -> void:
	GoStyle.forget_face(card)
	_restyle()
	_dress_scrim()
	relayout()


## The veil behind: the scrim colour (clear for `scrim_transparent`) and whatever the look lays over it — a frosted
## blur under the arcade looks with `arcade_scrim_blur` on (`GoSkin.scrim_material`). A clear scrim stays plain.
func _dress_scrim() -> void:
	if not is_instance_valid(_scrim): return
	if opaque:
		# 🛑 Opaque wins over a blur: there is nothing behind worth frosting.
		_scrim.color = GoUi.skin().opaque_backdrop_color()
		_scrim.material = null
		return
	_scrim.color = Color(0, 0, 0, 0) if scrim_transparent else GoUi.color(GoTheme.SCRIM)
	_scrim.material = null if scrim_transparent else GoUi.skin().scrim_material_now()


# ── The parts a window is built of (Magnet Mayhem's PaintedDialog) ─────

## A pale inset with a column inside, its rows 4 dp apart; returns the column. It goes in the body, or in [param parent].
## The look picks its face (`GoSkin.window_inset_variation()`: the game's `GoInsetPanel` in `arcade_light`).
func add_inset(parent: Control = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = GoUi.skin().window_inset_variation()
	(parent if parent != null else body).add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)
	return column


## A centred line of [param text] at [param font_size] (0: the theme's). [param wrap] is for sentences (SMART, so
## ja/zh wrap in an export too); a short one-line stat must not wrap — a wrapping label keeps the tall minimum of its
## first, narrow layout.
func add_line(text := "", font_size := 0, parent: Control = null, wrap := true) -> Label:
	var line := Label.new()
	line.text = text
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap: line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0: line.add_theme_font_size_override(&"font_size", font_size)
	(parent if parent != null else body).add_child(line)
	return line


## A row for buttons side by side, their gap the look's (`GoSkin.window_button_gap()`: 10 in `arcade_light`).
func add_row(parent: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var gap := GoUi.skin().window_button_gap()
	row.add_theme_constant_override(&"separation", gap if gap >= 0 else GoUi.metric(GoTheme.GAP))
	(parent if parent != null else body).add_child(row)
	return row


## A glyph button — [param variation], the icon set's [param icon], [param text] — at the look's window button height
## (`GoSkin.window_button_height()`: 46 in `arcade_light`). In a row it shares the row's width.
func add_gloss(variation: StringName, icon: StringName, text := "", parent: Control = null,
		texture: Texture2D = null) -> GoGlyphButton:
	var button := GoGlyphButton.make(text, icon, variation, texture)
	var high := GoUi.skin().window_button_height()
	if high > 0.0: button.custom_minimum_size.y = high
	var to := parent if parent != null else body
	if to is HBoxContainer: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to.add_child(button)
	return button


# ── Title glyph and the overhanging plate ─────────────────────────────

## A plate that draws its base grown sideways by `bleed` — the ribbon reaching past the card's sides.
class OverhangPlate:
	extends StyleBox

	var base: StyleBox
	var bleed := 0.0
	## The bleed drawn on each side now — 0 where a back or close button sits beside the plate.
	var bleed_left := 0.0
	var bleed_right := 0.0
	## The room kept for the title glyph and its gap (dp).
	var glyph_room := 0.0
	## How far the plate is drawn below the label (dp) — a title taller than a fixed-height plate.
	var sink := 0.0

	func _init(from: StyleBox = null, side := 0.0, extra_left := 0.0) -> void:
		base = from
		bleed = side
		bleed_left = side
		bleed_right = side
		glyph_room = extra_left
		if from == null: return
		content_margin_left = from.get_margin(SIDE_LEFT) + extra_left
		content_margin_right = from.get_margin(SIDE_RIGHT)
		content_margin_top = from.get_margin(SIDE_TOP)
		content_margin_bottom = from.get_margin(SIDE_BOTTOM)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if base != null: base.draw(to_canvas_item, rect.grow_individual(bleed_left, 0.0, bleed_right, sink))


## The side of the title glyph (dp): `title_glyph_size`, or the game's 26 dp beside a 34 dp title scaled to the title's
## role size. 🛑 Taken from the role size, never the size now — a long title shrinks to fit (`_fit_title_size`) after
##    the room for the glyph was reserved, and a glyph read from the shrunk size left too wide a gap beside it.
func title_glyph_side() -> float:
	if title_glyph_size > 0: return float(title_glyph_size)
	return roundf(float(_title_natural_size()) * 26.0 / 34.0)


## Room for the glyph on the title's face, and the plate hanging over the card's top edge when the look says so.
## 🔑 Only what this surface put on is taken off again — a look without either gets the plain head back.
func _dress_title_extras(plate: StyleBox) -> void:
	var on_plate := plate != null and title_label.has_meta(&"go_plate_align")
	_overhang = GoUi.skin().title_plate_overhang() if on_plate and show_header else Vector2.ZERO
	var extra := title_glyph_side() + TITLE_GLYPH_GAP if title_glyph != null else 0.0
	# The plate's height the look fixes (`GoSkin.title_plate_height`, the game's 57 dp ribbon) — the head's height.
	var tall := GoUi.skin().title_plate_height() if on_plate else 0.0
	if tall > 0.0:
		title_label.custom_minimum_size.y = tall
		title_label.set_meta(&"go_plate_height", true)
	elif title_label.has_meta(&"go_plate_height"):
		title_label.remove_meta(&"go_plate_height")
		title_label.custom_minimum_size.y = 0.0
	if on_plate and (extra > 0.0 or _overhang.x > 0.0 or tall > 0.0):
		title_label.add_theme_stylebox_override(&"normal", OverhangPlate.new(plate, _overhang.x, extra))
	elif not on_plate:
		if extra > 0.0:
			var room := StyleBoxEmpty.new()
			room.content_margin_left = extra
			title_label.add_theme_stylebox_override(&"normal", room)
			title_label.set_meta(&"go_glyph_room", true)
		elif title_label.has_meta(&"go_glyph_room"):
			title_label.remove_theme_stylebox_override(&"normal")
			title_label.remove_meta(&"go_glyph_room")
	if title_glyph == null:
		if is_instance_valid(_title_glyph_rect): _title_glyph_rect.queue_free()
		_title_glyph_rect = null
	else:
		if not is_instance_valid(_title_glyph_rect):
			_title_glyph_rect = TextureRect.new()
			_title_glyph_rect.name = "TitleGlyph"
			_title_glyph_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_title_glyph_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_title_glyph_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			title_label.add_child(_title_glyph_rect, false, Node.INTERNAL_MODE_FRONT)
		_title_glyph_rect.texture = title_glyph
	# A new plate bleeds on both sides; the row's next pass trims it beside the buttons (`_seat_head_buttons`).
	header.queue_sort()
	_apply_overhang()


## Lifts the head so the plate rises `_overhang.y` above the card's top edge (the padding's top margin goes negative)
## and lets it show past the padding's clip. 🛑 The body keeps its own clip (`GoScroll`); only the head reaches out.
func _apply_overhang() -> void:
	if _margin == null: return
	if _overhang.y > 0.0:
		_margin.clip_contents = false
		_margin.add_theme_constant_override(&"margin_top", -roundi(_card_top() + _overhang.y))
		_margin.set_meta(&"go_overhang", true)
	elif _margin.has_meta(&"go_overhang"):
		_margin.remove_meta(&"go_overhang")
		_margin.clip_contents = true
		_margin.add_theme_constant_override(&"margin_top", _content_padding)
	else:
		return
	_mark_layout_dirty()


## Under an overhanging plate only the plate rises (the game's ribbon): the head row is lifted, so after it lays its
## children out the back and close buttons are put back where the card's padding starts, and the plate bleeds sideways
## only where no button sits beside it. 🔑 `sort_children` is emitted after the row placed its children.
func _seat_head_buttons() -> void:
	var lift := float(_content_padding) + _card_top() + _overhang.y if _overhang.y > 0.0 else 0.0
	var need := 0.0
	var beside_left := false
	var beside_right := false
	for button: Control in [back_button, close_button]:
		if not button.visible: continue
		if button.position.x + button.size.x * 0.5 < title_label.position.x + title_label.size.x * 0.5:
			beside_left = true
		else:
			beside_right = true
		if lift <= 0.0: continue
		var tall := button.get_combined_minimum_size().y
		button.position.y = lift
		button.size.y = tall
		need = maxf(need, lift + tall)
	if not is_equal_approx(header.custom_minimum_size.y, need): header.custom_minimum_size.y = need
	# A button taller than the plate below the lift makes the row taller: the plate stays at its top, rising as far.
	if lift > 0.0: title_label.position.y = 0.0
	var plate := title_label.get_theme_stylebox(&"normal") as OverhangPlate
	if plate == null: return
	_place_corner.call_deferred()
	var left := 0.0 if beside_left else plate.bleed
	var right := 0.0 if beside_right else plate.bleed
	if not is_equal_approx(plate.bleed_left, left) or not is_equal_approx(plate.bleed_right, right):
		plate.bleed_left = left
		plate.bleed_right = right
		title_label.queue_redraw()
		# The plate's ends moved: the words' room and their centre with them.
		_fit_title.call_deferred()


## The card face's top padding (dp) — where the head would start without an overhang.
func _card_top() -> float:
	var face := card.get_theme_stylebox(&"panel") if card != null else null
	return face.get_margin(SIDE_TOP) if face != null else 0.0


## How far the title plate rises above the card's top edge now (0 when it sits inside).
func title_overhang() -> float:
	return _overhang.y


## The title's words at their size now (dp).
func _title_words_width() -> float:
	var font := title_label.get_theme_font(&"font")
	if font == null: return 0.0
	return font.get_string_size(title_label.atr(title_label.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			title_label.get_theme_font_size(&"font_size")).x


## Puts the glyph just before the title's words, on the start side (the right in a right-to-left layout) — centred
## with them on a plate, at the start otherwise. 🔑 A Label's LEFT alignment lays the words from the right edge in RTL,
## and a stylebox's margins do not mirror, so the room for the glyph is moved to the start side here.
func _place_title_glyph() -> void:
	if not is_instance_valid(_title_glyph_rect) or title_label == null: return
	var side := title_glyph_side()
	var rtl := title_label.is_inside_tree() and title_label.is_layout_rtl()
	var face := title_label.get_theme_stylebox(&"normal")
	if title_label.has_meta(&"go_glyph_room") and face is StyleBoxEmpty:
		var room := face as StyleBoxEmpty
		var reserve := side + TITLE_GLYPH_GAP
		room.content_margin_left = 0.0 if rtl else reserve
		room.content_margin_right = reserve if rtl else 0.0
	var left := face.get_margin(SIDE_LEFT) if face != null else 0.0
	var right := face.get_margin(SIDE_RIGHT) if face != null else 0.0
	var top := face.get_margin(SIDE_TOP) if face != null else 0.0
	var bottom := face.get_margin(SIDE_BOTTOM) if face != null else 0.0
	var width := title_label.size.x
	var x := (width - right + TITLE_GLYPH_GAP) if rtl else (left - TITLE_GLYPH_GAP - side)
	if face is OverhangPlate and title_label.has_meta(&"go_plate_align"):
		# 🛑 A centred Label centres its words over its whole width and ignores the face's side margins, so the room
		#    made for the glyph would not move them and the glyph would sit on the first letter. On a plate the words
		#    are laid from the start side instead, where glyph + gap + words sit centred together (the game's ribbon row).
		var plate := face as OverhangPlate
		# The plate's ends as drawn — past the card's sides by the bleed — so the row centres on the plate one sees.
		var base_left := _plate_end(plate, SIDE_LEFT)
		var base_right := _plate_end(plate, SIDE_RIGHT)
		var group := side + TITLE_GLYPH_GAP + _title_words_width()
		var start := floorf((base_right if rtl else base_left) \
				+ maxf(0.0, (width - base_left - base_right - group) * 0.5) + side + TITLE_GLYPH_GAP)
		var want_left := base_left if rtl else start
		var want_right := start if rtl else base_right
		if not is_equal_approx(plate.content_margin_left, want_left): plate.content_margin_left = want_left
		if not is_equal_approx(plate.content_margin_right, want_right): plate.content_margin_right = want_right
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		x = (width - start + TITLE_GLYPH_GAP) if rtl else (start - TITLE_GLYPH_GAP - side)
	elif title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		var wide := minf(_title_words_width(), maxf(0.0, width - left - right))
		var middle := (left + width - right) * 0.5
		x = (middle + wide * 0.5 + TITLE_GLYPH_GAP) if rtl else (middle - wide * 0.5 - TITLE_GLYPH_GAP - side)
	# On a plate the glyph's cell is `side` wide and as tall as the title's line, the art kept to its aspect — the
	# game's ribbon row, where a tall glyph (the lock) fills the line rather than a side x side square.
	var row := title_label.size.y - top - bottom
	var high := side
	if face is OverhangPlate:
		var font := title_label.get_theme_font(&"font")
		if font != null:
			high = maxf(side, minf(row, font.get_height(title_label.get_theme_font_size(&"font_size"))))
	var y := top + (row - high) * 0.5
	_title_glyph_rect.position = Vector2(roundf(x), roundf(y))
	_title_glyph_rect.size = Vector2(side, high)
	var ink := title_label.get_theme_color(&"font_color") if title_label.is_inside_tree() \
			else GoUi.skin().title_plate_ink()
	_title_glyph_rect.self_modulate = ink if ink.a > 0.0 else Color.WHITE


# ── The corner ─────────────────────────────────────────────────────────

## What the corner holds now — `corner`, or for `LOOK` the look's choice on a centred window (a sheet or a popover
## keeps its close button).
func corner_now() -> HeadCorner:
	if corner != HeadCorner.LOOK: return corner
	if placement != Placement.CENTER: return HeadCorner.CLOSE
	match GoUi.skin().window_corner():
		&"art": return HeadCorner.ART if _corner_texture() != null else HeadCorner.CLOSE
		&"none": return HeadCorner.NONE
	return HeadCorner.CLOSE


func _corner_texture() -> Texture2D:
	return corner_art if corner_art != null else GoUi.skin().window_corner_art()


## Shows the close button or the corner art. 🔑 Only a close button this surface hid is shown again — one the host
## hid itself stays hidden.
func _dress_corner() -> void:
	if close_button == null: return
	var now := corner_now()
	if now == HeadCorner.CLOSE:
		if close_button.has_meta(&"go_corner_hid"):
			close_button.remove_meta(&"go_corner_hid")
			close_button.visible = true
	elif close_button.visible:
		close_button.set_meta(&"go_corner_hid", true)
		close_button.visible = false
	var art := _corner_texture() if now == HeadCorner.ART and show_header else null
	if art == null:
		if is_instance_valid(_corner_rect): _corner_rect.visible = false
		return
	if not is_instance_valid(_corner_rect):
		_corner_rect = TextureRect.new()
		_corner_rect.name = "CornerArt"
		_corner_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_corner_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_corner_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_child(_corner_rect, false, Node.INTERNAL_MODE_BACK)
	_corner_rect.texture = art
	_corner_rect.visible = true
	_place_corner()


## Puts the corner art on the plate's corner as drawn (past its bleed), mirrored on the right.
func _place_corner() -> void:
	if not is_instance_valid(_corner_rect) or not _corner_rect.visible: return
	var spot := GoUi.skin().window_corner_rect()
	if spot.size == Vector2.ZERO and _corner_rect.texture != null: spot.size = _corner_rect.texture.get_size()
	var plate := title_label.get_theme_stylebox(&"normal") as OverhangPlate
	var left := plate.bleed_left if plate != null else 0.0
	var right := plate.bleed_right if plate != null else 0.0
	var x := -left + spot.position.x if corner_on_left \
			else title_label.size.x + right - spot.position.x - spot.size.x
	_corner_rect.flip_h = not corner_on_left
	_corner_rect.position = Vector2(x, spot.position.y)
	_corner_rect.size = spot.size


# ── Title ──────────────────────────────────────────────────────────────

## A translation key as the title — the engine redraws it when the language changes.
func set_title_key(key: String) -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	title_label.text = key
	_fit_title.call_deferred()


## An already-translated phrase or a person's name as the title.
func set_title(value: String) -> void:
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.text = value
	_fit_title.call_deferred()


## The back button used by sub-screens inside the same surface. An empty `Callable` hides it.
func set_back(action: Callable) -> void:
	for existing in back_requested.get_connections():
		back_requested.disconnect(existing.callable)
	if action.is_valid(): back_requested.connect(action)
	back_button.visible = action.is_valid()


# ── Pinned status row ──────────────────────────────────────────────────

## Pins an already-translated line above the footer row. An empty string hides the row.
## `tone` is a color token (`GoTheme.DANGER`·`WARNING`·`SUCCESS`·`MUTED` …) — leave it out for the body color.
func set_status_text(text: String, tone := StringName()) -> void:
	_set_status(text, tone, false)


## By translation key — the engine redraws it when the language changes.
func set_status_key(key: String, tone := StringName()) -> void:
	_set_status(key, tone, true)


## Hides the status row.
func clear_status() -> void:
	_set_status("", StringName(), false)


func _set_status(text: String, tone: StringName, translate: bool) -> void:
	if text.is_empty():
		if status_label != null: status_label.text = ""
		status.visible = false
		return
	if status_label == null:
		status_label = GoStyle.label("", GoTheme.ROLE_CAPTION)
		status_label.name = "StatusLineText"
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_child(status_label)
	status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	status_label.text = text
	GoStyle.typography(status_label, GoTheme.ROLE_CAPTION,
		GoUi.color(tone) if tone != StringName() else Color.TRANSPARENT)
	status.visible = true


## Empties the body.
func clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if scroll != null: scroll.scroll_vertical = 0


func request_close() -> void:
	if close_enabled and is_top(): close_requested.emit()


# ── Topmost test ───────────────────────────────────────────────────────

## Is this surface the topmost one — decided by the real draw order, nested `CanvasLayer`s included.
## 🛑 Without this, one Escape closes both windows when two of them overlap.
func is_top() -> bool:
	if not is_inside_tree() or not is_visible_in_tree(): return false
	var winner: GoSurface = self
	for node in get_tree().get_nodes_in_group(&"go_surfaces"):
		# 🛑 Narrow `node` to `GoSurface` first — the `for` variable is a `Node`, and calling `_layer_order()` on it
		#    directly leaves the return type un-inferable, which kills the whole script **at parse time**
		#    (the symptom is "Nonexistent function 'new' in base 'GDScript'" on `GoSurface.new()`).
		var candidate := node as GoSurface
		if candidate == null or not candidate.is_visible_in_tree(): continue
		var mine := winner._layer_order()
		var theirs := candidate._layer_order()
		if theirs > mine or (theirs == mine and candidate.is_greater_than(winner)): winner = candidate
	return winner == self


func _layer_order() -> int:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CanvasLayer: return ancestor.layer
		ancestor = ancestor.get_parent()
	return 0


# ── Lifetime and focus ─────────────────────────────────────────────────

func _sync_active() -> void:
	var next := is_visible_in_tree()
	if next == _active: return
	_active = next
	_dragging = false
	_touch_index = -1
	_scrim_pressed = false
	if next:
		if not _holds_back:
			GoBackPolicy.acquire(get_tree())
			_open_count += 1
			_holds_back = true
		var focus := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus) if focus != null and not is_ancestor_of(focus) else null
		if scroll != null: scroll.scroll_vertical = 0
		relayout()
		if fade_in: _fade = GoStyle.fade(card, _fade, true)
		_focus_default.call_deferred()
	else:
		# Closed in the frame of a drag — the last height still reaches a host that keeps it for the next open.
		_report_height()
		_release_back()
		_restore_focus()


func _release_back() -> void:
	if not _holds_back: return
	_holds_back = false
	_open_count = maxi(0, _open_count - 1)
	GoBackPolicy.release(get_tree())


func _focus_default() -> void:
	if not is_top(): return
	if is_instance_valid(initial_focus) and initial_focus.is_visible_in_tree():
		initial_focus.grab_focus()
		return
	if GoUi.config.suppress_pointer_focus_ring and _pointer_navigation:
		# Opened with a pointer — no ring. Focus arrives the moment Tab is pressed.
		# 🛑 Make the screen behind drop its focus — left alone, Enter presses a button back there while the
		#    window is up. `_restore_focus` puts it back where it was on close.
		var outside := get_viewport().gui_get_focus_owner()
		if outside != null and not is_ancestor_of(outside): outside.release_focus()
		return
	# 🔑 Under arcade_light the close button is out of the focus order (`GoSkin.control_focus_mode`): grabbing it would
	#    only fail with an engine warning and leave focus where it was.
	if close_button.visible and not close_button.disabled and close_button.focus_mode != Control.FOCUS_NONE:
		close_button.grab_focus()
		return
	var target := find_next_valid_focus()
	if target != null and is_ancestor_of(target):
		target.grab_focus()
		return
	# Nothing inside can take focus — the screen behind lets go of it, or Enter presses the opener again behind the window.
	var outside := get_viewport().gui_get_focus_owner()
	if outside != null and not is_ancestor_of(outside): get_viewport().gui_release_focus()


func _focus_changed(target: Control) -> void:
	if not (_active and is_top() and target != null and not is_ancestor_of(target)): return
	# Never leave focus outside the window — Enter must not press a button on the screen behind.
	if GoUi.config.suppress_pointer_focus_ring and _pointer_navigation and not is_instance_valid(initial_focus):
		target.release_focus.call_deferred()
	else:
		_focus_default.call_deferred()


func _restore_focus() -> void:
	if _previous_focus == null: return
	var previous := _previous_focus.get_ref() as Control
	_previous_focus = null
	if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
		previous.grab_focus.call_deferred()


func _enter_tree() -> void:
	# 🔑 Watched on every entry, not once in `_ready` — a widget taken out and put back (`remove_child` + `add_child`)
	#    would otherwise stop following the look; on a re-entry it catches up with a look changed while it was out.
	# 🛑 Register `_on_ui_changed`, not the layout pass — when the config changes, **the panel opacity** has to be
	#    reapplied too. Relaying out alone leaves a window whose theme was swapped still wearing the old panel.
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	_release_back()
	_restore_focus()


# ── Layout math ────────────────────────────────────────────────────────

## The ceiling on `height_ratio` in force for this surface — its own `max_height_ratio`, or the config's.
func height_ratio_cap() -> float:
	return max_height_ratio if max_height_ratio > 0.0 else GoUi.config.surface_max_height_ratio


## 🛑 A ratio that is silently cut costs an afternoon ("I asked for 0.86 and got 0.72") — say so once, in debug builds.
func _warn_height_cap(ratio: float, ratio_cap: float) -> void:
	if _warned_height_cap or not OS.is_debug_build() or Engine.is_editor_hint(): return
	_warned_height_cap = true
	push_warning("gohud: %s asks for height_ratio %.2f but is capped at %.2f — set max_height_ratio on this surface (or GoConfig.surface_max_height_ratio for all)."
		% [String(get_path()) if is_inside_tree() else String(name), ratio, ratio_cap])


func relayout() -> void:
	# Cleared first — a value set from here on (an override that sets `max_height` before `super()`, say) is already in.
	_layout_dirty = false
	_resize_pending = false
	if card == null or not is_inside_tree(): return
	var settings := GoUi.config
	var area := GoSafeArea.usable_rect_with_keyboard(get_viewport(), _keyboard_px)
	if placement == Placement.ANCHOR and is_instance_valid(anchor_control) and anchor_control.is_inside_tree():
		_update_density()
		_relayout_anchor(area)
		return
	# Keeps at least this much off the screen edge — on very narrow screens it shrinks proportionally.
	var look_width := GoUi.skin().window_width() if placement == Placement.CENTER else 0.0
	var look_margin := GoUi.skin().window_screen_margin() if placement == Placement.CENTER else -1.0
	var edge := float(GoUi.metric(GoTheme.SCREEN_MARGIN)) if look_margin < 0.0 else look_margin
	area = area.grow(-minf(edge, minf(area.size.x, area.size.y) * 0.1))
	var landscape := area.size.x > area.size.y
	var width_ratio := settings.surface_width_ratio_landscape if landscape else settings.surface_width_ratio_portrait
	# A look's fixed width with no screen margin is the game's CenterContainer: the width, or the whole screen.
	if look_margin >= 0.0 and look_width > 0.0 and max_width <= 0.0: width_ratio = 1.0
	var cap_width := max_width if max_width > 0.0 else (look_width if look_width > 0.0 else settings.surface_max_width)
	var cap_height := max_height if max_height > 0.0 else settings.surface_max_height
	var ratio := height_ratio if height_ratio > 0.0 else settings.surface_height_ratio
	var ratio_cap := height_ratio_cap()
	if ratio > ratio_cap + 0.001: _warn_height_cap(ratio, ratio_cap)
	var width := maxf(1.0, minf(cap_width, area.size.x * width_ratio))
	var height := maxf(1.0, minf(cap_height, area.size.y * minf(ratio, ratio_cap)))
	if fit_content:
		# 🔑 Short content shrinks it, and **long content grows it as far as the screen allows.** Scrolling while screen
		#    space is left over makes users who never noticed the scroll submit with unseen fields empty (`surface_fit_max_height_ratio`).
		#    🛑 Drag-resizable sheets and bottom sheets are not grown — their height is the user's own choice.
		var room := height
		if placement == Placement.CENTER and not resizable:
			room = maxf(room, minf(cap_height, area.size.y * settings.surface_fit_max_height_ratio))
		# If it looks like overflowing, try one step less padding and gap — then measure again.
		_update_density(room, width)
		height = clampf(_desired_height(), 1.0, room)
	else:
		_update_density()
	# 🛑 Size and position are given as integers — at a fractional position (centered · logical width 349.09) the size is
	#    stored as "position + size" and 184 becomes 183.99997, the card's inner padding (MarginContainer) floors child
	#    sizes to integers, and the body came out 1px short — a scrollbar appeared beside the one-line body of the first
	#    confirmation (measured 2026-09-15 on a Laryen phone in portrait · does not reproduce at headless logical sizes).
	card.size = Vector2(width, height).round()
	# Centred the way a `CenterContainer` centres (rounded down), so a window sits on the pixel the game's dialog does.
	var y := area.position.y + (area.size.y - card.size.y) * (1.0 if placement == Placement.BOTTOM else 0.5)
	# A plate hanging over the card's top edge must stay on screen too: the card comes down only when it would not.
	if _overhang.y > 0.0: y = maxf(y, area.position.y + _overhang.y)
	card.position = Vector2(area.position.x + (area.size.x - card.size.x) * 0.5, y).floor()


## Drops padding and title size one step when space runs short — making room for content on small screens.
##
## Pass `room` (greater than 0) to drop a step **when the content overflows that height** as well — a form with the
## virtual keyboard covering half the screen, say: not much room, yet everything has to be visible.
## Pass `width` (greater than 0) — the card width this relayout is about to apply — and the content is measured **at that
## width, after the layout has been sorted** (`_sort_now`).
## 🛑 Measuring before the sort reads the *previous* width and density: a wrapping row (`HFlowContainer` of reward cards)
##    that fits two per line in one step wraps to one per line in the other, so the card flipped between the two
##    every frame — title size, column count, scrollbar and height all jumping (Laryen supply crate, 2026-10-03).
## 🔑 Both steps are measured, each at its own settled layout, and the roomier one is kept **only if it fits** — a pure
##    function of (width, room, content). The old slack rule (return to normal density only below 0.85·room) could not stop this: dense
##    content ≤ 0.85·room while roomy content > room alternates forever.
func _update_density(room := 0.0, width := 0.0) -> void:
	var small := compact or get_viewport_rect().size.y < 420
	if not small and room > 0.0:
		_apply_density(false, width)
		small = _desired_height() > room
	_apply_density(small, width)


func _apply_density(small: bool, width: float) -> void:
	_dense = small
	# The look may frame the window itself (`GoSkin.window_padding` / `window_gap`): the game's card pads with its
	# own face and keeps its rows 8 apart on every screen.
	var skin := GoUi.skin()
	var next := skin.window_padding()
	if next < 0: next = GoUi.metric(GoTheme.PADDING_COMPACT if small else GoTheme.PADDING)
	var rows := skin.window_gap()
	var spacing := rows if rows >= 0 else GoUi.metric(GoTheme.GAP_SMALL if small else GoTheme.GAP)
	# 🛑 Compared with what is applied, not remembered — a look that pads 0 would match the first value and never dress.
	if _content_padding != next or _margin.get_theme_constant(&"margin_left") != next:
		_content_padding = next
		GoStyle.insets(_margin, next)
		if _overhang.y > 0.0: _apply_overhang()
		if scroll != null: scroll.set_panel_padding(next)
	if _column.get_theme_constant(&"separation") != spacing:
		_column.add_theme_constant_override(&"separation", spacing)
	# The body's rows take the look's gap too — and only what this surface set is put back: a host's own gap stays.
	if rows >= 0:
		if not body.has_meta(&"go_look_gap") or body.get_theme_constant(&"separation") != rows:
			body.set_meta(&"go_look_gap", true)
			body.add_theme_constant_override(&"separation", rows)
	elif body.has_meta(&"go_look_gap"):
		body.remove_meta(&"go_look_gap")
		body.add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP))
	var role := GoTheme.ROLE_BODY if small else GoTheme.ROLE_SUBTITLE
	if title_label.get_meta(&"go_text_role", &"") != role:
		GoStyle.typography(title_label, role)
		# typography() lifts the size override — a title on a plate measures itself again at its new role.
		title_label.remove_meta(&"go_title_fit")
		_fit_title()
	if width > 0.0: _sort_now(width)


## Gives the card `width` and sorts its whole subtree right now, top-down, so that wrapping rows and labels report the
## minimum size they have **at that width** (the engine would only do it at the end of the frame).
func _sort_now(width: float) -> void:
	card.size = Vector2(width, maxf(card.size.y, 1.0)).round()
	_sort_subtree(card)


func _sort_subtree(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	# 🛑 A direct sort emits no `sort_children`, so the head's buttons are seated here too.
	if node == header: _seat_head_buttons()
	for child in node.get_children():
		if child is Control and child.visible: _sort_subtree(child)


## The card's inner padding (dp) — one step smaller on narrow screens. 🔑 Decided after `relayout`.
func content_inset() -> int:
	return _content_padding


## The **actually applied** gap (dp) between header, pinned rows, body and footer — one step smaller on narrow screens.
func section_gap() -> int:
	return _column.get_theme_constant(&"separation")


## The card height the content asks for (padding + header + pinned rows + body + footer).
## 🛑 Leave `toolbar` out and a sheet with its search field on comes up exactly that much shorter, clipping the last row of the list.
## 🛑 Section gaps are counted from the **value actually applied** — hard-coding the `gap` token grew the card by that difference
##    at every section on narrow screens (where the gap is `gap_small`), opening a hole between body and buttons in short confirmations.
func _desired_height() -> float:
	# The card face's own padding (a painted card pads with its face) and the padding inside it.
	var face := card.get_theme_stylebox(&"panel")
	var desired := float(_content_padding * 2)
	if face != null: desired += face.get_margin(SIDE_TOP) + face.get_margin(SIDE_BOTTOM)
	# The head starts above the card's top edge: the padding's top margin is negative by the card's top and the rise.
	if _overhang.y > 0.0: desired -= float(_content_padding) + _card_top() + _overhang.y
	var gap := float(section_gap())
	if header.visible: desired += header.get_combined_minimum_size().y + gap
	if toolbar.visible: desired += toolbar.get_combined_minimum_size().y + gap
	desired += body.get_combined_minimum_size().y
	if status.visible: desired += status.get_combined_minimum_size().y + gap
	if footer.visible: desired += footer.get_combined_minimum_size().y + gap
	return desired


## Attaches beside the given control — to the right if the minimum width fits there, otherwise to the wider side, and if
## neither fits, pulled inside the screen. Opens upward when there is less room below than above.
func _relayout_anchor(area: Rect2) -> void:
	var anchor := anchor_control.get_global_rect()
	var edge := 8.0
	var gap := 7.0
	var space_right := area.end.x - anchor.position.x - edge
	var space_left := anchor.end.x - area.position.x - edge
	var width := anchor_width
	var x := anchor.position.x
	if space_right < anchor_min_width and space_left < anchor_min_width:
		width = clampf(area.size.x - edge * 2, 1, anchor_width)
		x = area.position.x + edge
	elif space_right >= anchor_min_width or space_right >= space_left:
		width = clampf(space_right, anchor_min_width, anchor_width)
	else:
		width = clampf(space_left, anchor_min_width, anchor_width)
		x = anchor.end.x - width
	var below := area.end.y - anchor.end.y - gap - edge
	var above := anchor.position.y - area.position.y - gap - edge
	var opens_up := below < above
	var cap := minf(anchor_max_height, area.size.y * height_ratio_cap())
	var height := clampf(above if opens_up else below, 0, cap)
	if fit_content: height = minf(height, _desired_height())
	card.size = Vector2(maxf(1, width), maxf(1, height)).round()
	# When the pinned header and footer are bigger than the room left, the card grows to its minimum size — then it is pushed inside the screen.
	var y := anchor.position.y - gap - card.size.y if opens_up else anchor.end.y + gap
	y = clampf(y, area.position.y + edge, maxf(area.position.y + edge, area.end.y - edge - card.size.y))
	x = clampf(x, area.position.x + edge, maxf(area.position.x + edge, area.end.x - edge - card.size.x))
	# 🛑 Integers — a fractional position makes the size 183.99997 and the body loses 1px (see the `relayout` comment).
	card.position = Vector2(x, y).round()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_sync_active()
	if not _active: return
	close_button.disabled = not close_enabled
	# Without the autoload the keyboard is polled here (with it, it arrives as a signal).
	if _runtime == null and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_on_keyboard(DisplayServer.virtual_keyboard_get_height())
	# 🔑 Fit to content **only when something it reads changed** (`_layout_dirty`). An anchored popover still follows
	#    its anchor every frame — the anchor can move (a scrolled list) without telling anyone.
	if _resize_pending or (fit_content and (_layout_dirty or placement == Placement.ANCHOR)):
		# 🛑 Cleared here too, not only in `relayout()` — a subclass that replaces `relayout()` without calling `super()`
		#    never clears them, and the surface went back to laying out every frame (and after one drag, forever).
		_layout_dirty = false
		_resize_pending = false
		relayout()
	_report_height()


func _report_height() -> void:
	if not _height_unreported: return
	_height_unreported = false
	height_changed.emit(height_ratio)


func _on_keyboard(height_px: int) -> void:
	if height_px == _keyboard_px: return
	_keyboard_px = height_px
	relayout()
	# 🛑 Out of the tree (a scene change removes it before freeing it) `get_viewport()` is null — see `GoForm._on_keyboard`.
	if scroll == null or not is_inside_tree(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and scroll.is_ancestor_of(focus): scroll.ensure_control_visible.call_deferred(focus)


# ── Input ──────────────────────────────────────────────────────────────

func _scrim_input(event: InputEvent) -> void:
	if not dismiss_on_scrim or not is_top(): return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT): return
	if event.pressed:
		_scrim_pressed = true
		_scrim_origin = event.position
	else:
		# 🛑 Closes **only when the press did not drag** — a drag that started inside the card and ended outside
		#    must not close the window.
		if _scrim_pressed and _scrim_origin.distance_to(event.position) < GoUi.metric(GoTheme.SCROLL_DEADZONE):
			request_close()
		_scrim_pressed = false


func _gui_input(event: InputEvent) -> void:
	# `MOUSE_FILTER_STOP` does not swallow zoom and pan gestures in Godot.
	# Nested controls see them first, so only what is left over is stopped here.
	if event is InputEventGesture: accept_event()


## Drag to resize — grab the sheet's header and move it up or down.
func attach_resize_handle(handle: Control) -> void:
	resizable = true
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	if not handle.gui_input.is_connected(_resize_input): handle.gui_input.connect(_resize_input)
	handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE


func _resize_input(event: InputEvent) -> void:
	if not resizable or not is_top(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_touch_index = event.index if event.pressed else -1


func _input(event: InputEvent) -> void:
	_track_device(event)
	if not is_top():
		_dragging = false
		return
	if GoUi.config.close_on_back and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		request_close()
		get_viewport().set_input_as_handled()
		return
	if not _dragging: return
	var dy := 0.0
	if event is InputEventScreenDrag and event.index == _touch_index: dy = event.relative.y
	elif event is InputEventMouseMotion and _touch_index < 0: dy = event.relative.y
	elif (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		_dragging = false
		_touch_index = -1
	if not is_zero_approx(dy):
		var area := GoSafeArea.usable_rect(get_viewport())
		var current := height_ratio if height_ratio > 0.0 else GoUi.config.surface_height_ratio
		# 🛑 The same ceiling the layout uses — clamped to 0.95 here while the layout stopped at 0.72, a drag past the
		#    ceiling moved nothing, `height_changed` reported a height that was never drawn, and dragging back down did
		#    nothing until the finger had undone the invisible part.
		height_ratio = clampf(current - dy / maxf(1.0, area.size.y), minf(0.3, height_ratio_cap()), height_ratio_cap())
		# 🔑 Applied once per frame in `_process` (input is flushed before it, so the card still moves in the same frame),
		#    and `height_changed` goes out there too, after the card has the height it reports.
		_resize_pending = true
		_height_unreported = true
	get_viewport().set_input_as_handled()


## Records which device is in use. Events arrive while the window is in the tree even when it is hidden, so
## **the input right before the window opened** (a button tap or the Tab key) is what counts.
func _track_device(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_pointer_navigation = true
	elif event is InputEventJoypadButton or (event is InputEventKey and event.pressed and not event.is_echo()):
		_pointer_navigation = false


func _notification(what: int) -> void:
	if (what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED) \
			and title_label != null:
		_fit_title.call_deferred()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and GoUi.config.close_on_back and is_top():
		# Deferred so that one OS notification does not close several stacked windows.
		request_close.call_deferred()
